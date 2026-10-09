"""Browser integration: installation guidance, failed download/retry, and real offline boot.

Run against an exported build served over HTTP: python tests/web_install.py URL
Requires Playwright and its Chromium browser. Does not change player profiles.
"""
import sys
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

url = sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:8765/web/'
screens = Path('build/qa')
screens.mkdir(parents=True, exist_ok=True)

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, args=[
        '--enable-webgl', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'])
    context = browser.new_context(viewport={'width': 844, 'height': 390},
                                  is_mobile=True, has_touch=True)
    page = context.new_page()
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.goto(url)
    page.wait_for_load_state('networkidle')
    manifest = context.new_cdp_session(page).send('Page.getAppManifest')
    assert not manifest.get('errors'), manifest
    assert 'standalone' in manifest['data']
    page.get_by_role('button', name='Instalar no Android', exact=True).click()
    expect(page.locator('#install-help')).to_contain_text('Chrome')
    context.set_offline(True)
    page.locator('#download-offline').click()
    expect(page.locator('#offline-status')).to_contain_text('não terminou', timeout=30000)
    context.set_offline(False)
    page.locator('#download-offline').click()
    expect(page.locator('#offline-status')).to_contain_text('Download concluído', timeout=180000)
    expect(page.locator('#download-offline')).to_be_enabled()
    # Storage eviction must be recoverable without asking the player to clear all site data.
    page.evaluate('async () => { for (const key of await caches.keys()) await caches.delete(key); }')
    page.locator('#download-offline').click()
    expect(page.locator('#offline-status')).to_contain_text('Download concluído', timeout=180000)
    expect(page.locator('#download-offline')).to_be_enabled()
    page.screenshot(path=str(screens / 'android-install.png'))
    page.get_by_role('button', name='Fechar instruções').click()
    page.reload()
    page.wait_for_function('!!navigator.serviceWorker.controller')
    # A fresh page offline proves the executable, content, shell and audio worklets are cached.
    page.close()
    context.set_offline(True)
    page = context.new_page()
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
    page.goto(url + '?offline-test=1')
    page.get_by_role('button', name='Entrar nas ruínas').click()
    page.wait_for_function("document.body.classList.contains('running')", timeout=90000)
    page.wait_for_timeout(2500)
    page.screenshot(path=str(screens / 'offline-game.png'))
    assert not errors, errors
    print('PASS: Android guidance, manifest, failure/retry, complete download and offline Godot boot')
    context.close()

    ios = browser.new_context(viewport={'width': 375, 'height': 667}, is_mobile=True,
                              has_touch=True, user_agent='Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1')
    page = ios.new_page()
    page.goto(url)
    page.wait_for_load_state('networkidle')
    page.get_by_role('button', name='Instalar no iPhone / iPad', exact=True).click()
    expect(page.locator('#install-help')).to_contain_text('Safari')
    expect(page.locator('#install-help')).to_contain_text('Adicionar à Tela de Início')
    expect(page.locator('#install-native')).to_be_hidden()
    assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
    page.screenshot(path=str(screens / 'ios-install.png'))
    page.get_by_role('button', name='Fechar instruções').click()
    expect(page.locator('#install-dialog')).not_to_be_visible()
    print('PASS: iPhone guidance, dialog close and 375px layout (emulation, not physical iOS)')
    ios.close()
    browser.close()
