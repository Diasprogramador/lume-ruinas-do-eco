"""Add installation assets and a content-versioned offline worker after Godot export."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parent.parent
target = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'build/web'
for required in ('index.html', 'index.js', 'index.wasm', 'index.pck'):
    if not (target / required).is_file():
        raise SystemExit(f'Export Web first: missing {required}')
for name in ('install.js', 'install.css', 'manifest.webmanifest'):
    shutil.copy2(ROOT / 'web' / name, target / name)
shutil.copytree(ROOT / 'web/icons', target / 'icons', dirs_exist_ok=True)
files = sorted(p.relative_to(target).as_posix() for p in target.rglob('*')
               if p.is_file() and p.suffix in ('.html', '.js', '.wasm', '.pck', '.png', '.css', '.webmanifest')
               and p.name != 'sw.js')
digest = hashlib.sha256()
for name in files:
    digest.update(name.encode())
    digest.update((target / name).read_bytes())
template = (ROOT / 'web/sw-template.js').read_text(encoding='utf-8')
digest.update(template.encode())
version = digest.hexdigest()[:20]
worker = template.replace('__VERSION__', json.dumps(version)).replace('__FILES__', json.dumps(files))
(target / 'sw.js').write_text(worker, encoding='utf-8')
print(f'Offline package: {len(files)} files, version {version}')
