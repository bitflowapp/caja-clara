"""Real browser, real API and SQLite. No mocked production data or routes."""
import json
import os
import subprocess
import sys
import time
import traceback
from pathlib import Path
from urllib.request import urlopen
from playwright.sync_api import sync_playwright, expect

root = Path(__file__).resolve().parents[1]
output = root / 'artifacts'
output.mkdir(exist_ok=True)
data = root / '.data/browser-test'
data.mkdir(parents=True, exist_ok=True)
base = 'http://127.0.0.1:5189'
results = []
server = None
credentials = None

def passed(name):
    results.append({'name': name, 'status': 'PASS'})
    print('PASS', name, flush=True)

def cli(command, payload):
    request = {'username': credentials['localLogin'], 'password': credentials['password'], 'payload': payload}
    exe = output / 'package/terminal/cajaclara-cli.exe'
    process = subprocess.run([str(exe), command, '--db', credentials['localDb'], '--json'], input=json.dumps(request), text=True, encoding='utf-8', capture_output=True, timeout=35)
    if process.returncode:
        raise AssertionError('CLI failed: ' + process.stderr)
    return json.loads(process.stdout.lstrip('\ufeff'))

def sync():
    return cli('sync-once', {'server': base, 'deviceToken': credentials['deviceToken']})

log = (output / 'backend-test-server.log').open('w', encoding='utf-8')
try:
    seed = subprocess.run(['dotnet', 'run', '--project', str(root / 'tests/CajaClara.CloudTests/CajaClara.CloudTests.csproj'), '-c', 'Release', '--no-build', '--', '--seed-browser', str(data)], capture_output=True, text=True, timeout=45)
    if seed.returncode:
        raise AssertionError('Browser fixture setup failed: ' + seed.stderr)
    credentials = json.loads((data / 'browser-credentials.json').read_text(encoding='utf-8'))
    env = dict(os.environ, ASPNETCORE_ENVIRONMENT='Development', CAJACLARA_DATA_DIR=str(data))
    server = subprocess.Popen(['dotnet', 'run', '--project', str(root / 'src/CajaClara.Backend/CajaClara.Backend.csproj'), '-c', 'Release', '--no-build', '--', '--urls', base], env=env, stdout=log, stderr=log)
    for attempt in range(60):
        try:
            with urlopen(base + '/health', timeout=1) as response:
                if response.status == 200:
                    break
        except Exception:
            if server.poll() is not None:
                raise AssertionError('Backend stopped before becoming healthy')
            time.sleep(.5)
    else:
        raise AssertionError('Backend did not start')
    passed('backend_http_started')
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        context = browser.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=1, is_mobile=True, has_touch=True, locale='es-AR')
        page = context.new_page()
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.goto(base)
        expect(page.locator('#login-form')).to_be_visible()
        page.screenshot(path=str(output / 'mobile-01-login.png'), full_page=True)
        passed('mobile_login_screen')
        page.locator('#login').fill(credentials['cloudLogin'])
        page.locator('#password').fill(credentials['password'])
        page.get_by_role('button', name='Entrar al panel').click()
        expect(page.locator('#app-view')).to_be_visible(timeout=20000)
        expect(page.locator('#business-name')).to_contain_text('Almacén del Río')
        expect(page.locator('#sales-list .list-row')).to_have_count(2)
        page.screenshot(path=str(output / 'mobile-02-summary.png'), full_page=True)
        passed('mobile_authenticated_real_sales')
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth + 1')
        passed('mobile_no_horizontal_overflow')
        protected = context.request.post(base + '/api/owner/pair-code', data={})
        assert protected.status == 403, protected.status
        passed('http_csrf_required')
        anonymous = pw.request.new_context(base_url=base)
        unauthorized = anonymous.get('/api/owner/dashboard?from=2026-09-21T00:00:00Z&to=2026-09-22T00:00:00Z')
        assert unauthorized.status == 401, unauthorized.status
        passed('http_owner_auth_required')
        products = cli('products', {})
        product = next(p for p in products if p['id'] == credentials['productId'])
        import uuid
        sale = cli('sale', {'id': str(uuid.uuid4()), 'customerId': None, 'items': [{'productId': product['id'], 'productVersion': product['version'], 'quantityMilli': 1000}], 'payments': [{'method': 'Cash', 'appliedCents': product['priceCents'], 'receivedCents': product['priceCents'], 'reference': ''}], 'notes': 'Venta E2E terminal → HTTP → celular'})
        sync()
        page.locator('#refresh').click()
        expect(page.locator('#sales-list .list-row')).to_have_count(3)
        passed('terminal_sale_http_sync_mobile')
        page.get_by_role('button', name='Productos', exact=True).click()
        page.locator('#product-search').fill('Yerba')
        expect(page.locator('#product-list .list-row')).to_have_count(1)
        page.locator('#product-list').get_by_role('button', name='Precio', exact=True).click()
        page.get_by_label('Nuevo precio final', exact=True).fill('4500,00')
        page.get_by_role('button', name='Enviar cambio').click()
        expect(page.locator('#modal')).not_to_be_visible(timeout=15000)
        sync()
        updated = next(p for p in cli('products', {}) if p['id'] == product['id'])
        assert updated['priceCents'] == 450000
        sync()
        page.locator('#refresh').click()
        expect(page.locator('#product-list')).to_contain_text('4.500')
        page.screenshot(path=str(output / 'mobile-03-products.png'), full_page=True)
        passed('mobile_price_command_real_local_effect')
        page.get_by_role('button', name='Actividad', exact=True).click()
        expect(page.locator('#command-list')).to_contain_text('Aplicado')
        page.screenshot(path=str(output / 'mobile-04-activity.png'), full_page=True)
        passed('command_confirmation_visible')
        page.get_by_role('button', name='Resumen', exact=True).click()
        page.get_by_role('button', name='Solicitar cierre de caja', exact=True).click()
        page.locator('#modal-submit').click()
        expect(page.locator('#modal')).not_to_be_visible()
        sync()
        status = cli('status', {})
        assert status['snapshot']['cash']['state'] == 'ClosingRequested'
        passed('mobile_closing_request_not_forced_close')
        desktop = browser.new_context(viewport={'width': 1440, 'height': 1000}, storage_state=context.storage_state(), locale='es-AR')
        desktop_page = desktop.new_page()
        desktop_page.goto(base)
        expect(desktop_page.locator('#app-view')).to_be_visible(timeout=15000)
        desktop_page.screenshot(path=str(output / 'remote-desktop-summary.png'), full_page=True)
        assert desktop_page.evaluate('document.documentElement.scrollWidth <= innerWidth + 1')
        passed('responsive_desktop_dashboard')
        page.get_by_role('button', name='Equipos', exact=True).click()
        page.get_by_role('button', name='Revocar', exact=True).click()
        page.locator('#modal-submit').click()
        expect(page.locator('#modal')).not_to_be_visible()
        denied = context.request.get(base + '/api/device/commands', headers={'Authorization': 'Bearer ' + credentials['deviceToken']})
        assert denied.status == 401
        passed('device_revocation_blocks_remote_access')
        page.locator('#logout').click()
        expect(page.locator('#login-view')).to_be_visible()
        assert page.locator('#sales-list').inner_text() == ''
        passed('logout_clears_business_data')
        assert not errors, errors
        passed('browser_no_javascript_exceptions')
        browser.close()
except Exception as error:
    results.append({'name': 'browser_e2e', 'status': 'FAIL', 'detail': str(error), 'trace': traceback.format_exc()})
    print('FAIL browser_e2e', str(error), flush=True)
    try:
        page.screenshot(path=str(output / 'mobile-failure.png'), full_page=True)
    except Exception:
        pass
finally:
    if server:
        server.terminate()
        try:
            server.wait(timeout=10)
        except subprocess.TimeoutExpired:
            server.kill()
    log.close()
    (output / 'browser-test-results.json').write_text(json.dumps({'total': len(results), 'passed': sum(x['status'] == 'PASS' for x in results), 'failed': sum(x['status'] == 'FAIL' for x in results), 'results': results}, ensure_ascii=False, indent=2), encoding='utf-8')
sys.exit(1 if any(x['status'] == 'FAIL' for x in results) else 0)
