import io,urllib.request,zipfile,os
url='https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_export_templates.tpz'
class Remote(io.RawIOBase):
 def __init__(self): self.pos=0;self.size=1249771228
 def seekable(self): return True
 def seek(self,n,w=0):
  self.pos=n if w==0 else self.pos+n if w==1 else self.size+n
  return self.pos
 def tell(self): return self.pos
 def read(self,n=-1):
  if n<0:n=self.size-self.pos
  if n==0:return b''
  end=min(self.size-1,self.pos+n-1)
  req=urllib.request.Request(url+'?range='+str(self.pos),headers={'Range':f'bytes={self.pos}-{end}','User-Agent':'Lume-build'})
  with urllib.request.urlopen(req,timeout=120) as r:
   if r.status!=206:raise RuntimeError('Server did not honor byte ranges')
   data=r.read()
  if len(data)!=end-self.pos+1:raise RuntimeError('Unexpected range length')
  self.pos+=len(data);return data
base=os.environ.get('APPDATA') if os.name=='nt' else os.path.expanduser('~/.local/share')
out=os.path.join(base,'Godot' if os.name=='nt' else 'godot','export_templates','4.6.1.stable');os.makedirs(out,exist_ok=True)
with zipfile.ZipFile(Remote()) as z:
 for name in ['version.txt','web_nothreads_release.zip'] + ([] if '--web-only' in __import__('sys').argv else ['windows_release_x86_64.exe']):
  entry=next(i for i in z.infolist() if i.filename.endswith('/'+name))
  with open(os.path.join(out,name),'wb') as f:f.write(z.read(entry))
  print('Installed',name,flush=True)
