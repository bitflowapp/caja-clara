"""Runs the real WinUI executable in an isolated --demo workspace."""
import json
import os
import secrets
import sqlite3
import subprocess
import sys
import time
import traceback
import shutil
from pathlib import Path
from pywinauto import Application, Desktop, Desktop
from PIL import ImageGrab

root = Path(__file__).resolve().parents[1]
output = root / 'artifacts'
output.mkdir(exist_ok=True)
exe = Path(os.environ.get('CAJACLARA_UI_EXE', str(output / 'package/app/CajaClara.exe')))
results = []
process = None
window = None
password = secrets.token_hex(20)
data = Path(os.environ['LOCALAPPDATA']) / 'LUNA/CajaClaraNative/Demo'

def passed(name):
    results.append({'name': name, 'status': 'PASS'})
    print('PASS', name, flush=True)

def capture(name):
    if window is not None and window.exists():
        window.wrapper_object().capture_as_image().save(output / name)
    else:
        if window is not None and window.exists():
        window.wrapper_object().capture_as_image().save(output / name)
    else:
        ImageGrab.grab(all_screens=True).save(output / name)

def edit(identifier, value):
    control = window.child_window(auto_id=identifier, control_type='Edit')
    control.wait('exists enabled', timeout=20)
    control.wrapper_object().set_edit_text(value)

def click(text):
    control = window.child_window(title=text, control_type='Button')
    control.wait('exists enabled', timeout=20)
    control.wrapper_object().invoke()
    time.sleep(.8)

def nav(text):
    matches = [x for x in window.descendants() if x.element_info.name == text and x.element_info.control_type in ('ListItem', 'TreeItem', 'TabItem')]
    if not matches:
        matches = [x for x in window.descendants() if x.element_info.name == text and x.element_info.control_type not in ('Text', 'Edit')]
    if not matches:
        raise AssertionError('Navigation item not found: ' + text)
    item = matches[0]
    try:
        item.iface_invoke.Invoke()
    except Exception:
        item.click_input()
    time.sleep(1)

def rows(kind):
    with sqlite3.connect(data / 'caja.sqlite') as db:
        return [json.loads(x[0]) for x in db.execute('SELECT body FROM records WHERE kind=?', (kind,))]

try:
    if not exe.exists():
        raise AssertionError('Native executable was not published')
    if (data / 'caja.sqlite').exists():
        raise AssertionError('UI test refuses to overwrite an existing demo workspace')
    process = subprocess.Popen([str(exe), '--demo'], cwd=exe.parent)
    app = Application(backend='uia').connect(process=process.pid, timeout=30)
    window = app.window(title_re='Caja Clara.*')
    window.wait('exists visible', timeout=30)
    window.wrapper_object().maximize()
    window.wrapper_object().maximize()
    time.sleep(3)
    capture('windows-01-onboarding.png')
    passed('native_executable_started')
    edit('Nombre del comercio', 'Almacén de prueba UI')
    edit('Tu nombre', 'Caja de prueba')
    edit('Usuario', 'qa.ui')
    edit('login-password', password)
    click('Crear comercio')
    time.sleep(3)
    assert rows('Business')[0]['name'] == 'Almacén de prueba UI'
    passed('native_onboarding_persists')
    nav('Productos y stock')
    click('Nuevo producto')
    edit('Código interno', 'UI001')
    edit('Código de barras', '7791234567890')
    edit('Producto', 'Producto de prueba UI')
    edit('Categoría', 'Almacén')
    edit('Costo en pesos', '50,00')
    edit('Precio final en pesos', '100,00')
    edit('Stock inicial', '10')
    edit('Stock mínimo', '2')
    click('Guardar')
    assert rows('Product')[0]['stockMilli'] == 10000
    passed('native_product_creation')
    nav('Caja')
    click('Abrir caja')
    edit('Efectivo inicial', '1000,00')
    click('Guardar')
    assert rows('CashSession')[0]['state'] == 'Open'
    passed('native_cash_open')
    nav('Vender')
    search = window.child_window(auto_id='Buscar por nombre, código o lector de barras', control_type='Edit')
    search.wrapper_object().set_edit_text('7791234567890')
    search.wrapper_object().type_keys('{ENTER}')
    time.sleep(1)
    capture('windows-02-pos.png')
    click('Cobrar · F4')
    click('Agregar medio de pago')
    click('Confirmar venta')
    time.sleep(2)
    assert len(rows('Sale')) == 1
    assert rows('Sale')[0]['totalCents'] == 10000
    assert rows('Product')[0]['stockMilli'] == 9000
    assert rows('CashSession')[0]['expectedCents'] == 110000
    passed('native_scan_pay_stock_cash')
    nav('Ventas')
    capture('windows-03-sales.png')
    passed('native_sales_screen')
    nav('Caja')
    click('Cerrar turno')
    edit('Efectivo contado', '1100,00')
    click('Cerrar caja')
    assert rows('CashSession')[0]['state'] == 'Closed'
    assert rows('CashSession')[0]['countedCents'] == 110000
    passed('native_cash_close')
    nav('Resumen')
    capture('windows-04-summary.png')
    passed('native_summary_screen')
except Exception as error:
    results.append({'name': 'native_ui_flow', 'status': 'FAIL', 'detail': str(error), 'trace': traceback.format_exc()})
    print('FAIL native_ui_flow', str(error), flush=True)
    try:
        capture('windows-failure.png')
        if window:
            tree = [{'type': x.element_info.control_type, 'name': x.element_info.name, 'id': x.element_info.automation_id} for x in window.descendants()]
            (output / 'windows-ui-tree.json').write_text(json.dumps(tree, ensure_ascii=False, indent=2), encoding='utf-8')
    except Exception:
        pass
finally:
    try:
        diagnostics = {'process_id': process.pid if process else None, 'exit_code': process.poll() if process else None,
                       'files': [p.name for p in exe.parent.glob('*.pri')],
                       'windows': [{'title': x.window_text(), 'pid': x.process_id(), 'visible': x.is_visible()} for x in Desktop(backend='uia').windows()]}
        (output / 'windows-startup-diagnostics.json').write_text(json.dumps(diagnostics, ensure_ascii=False, indent=2), encoding='utf-8')
        logs = data / 'logs'
        if logs.exists():
            for source in logs.glob('*.jsonl'):
                shutil.copy2(source, output / ('windows-app-' + source.name))
        events = subprocess.run(['powershell', '-NoProfile', '-Command', "Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=(Get-Date).AddMinutes(-8)} -ErrorAction SilentlyContinue | Where-Object {$_.ProviderName -match 'Application Error|.NET Runtime|Windows App Runtime'} | Select-Object TimeCreated,ProviderName,Id,Message | ConvertTo-Json -Depth 4"], capture_output=True, text=True, timeout=20)
        (output / 'windows-event-log.json').write_text(events.stdout, encoding='utf-8')
    except Exception as diagnostic_error:
        print('Diagnostic collection:', str(diagnostic_error), flush=True)
    if process:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
    (output / 'ui-test-results.json').write_text(json.dumps({'total': len(results), 'passed': sum(x['status'] == 'PASS' for x in results), 'failed': sum(x['status'] == 'FAIL' for x in results), 'results': results}, ensure_ascii=False, indent=2), encoding='utf-8')
sys.exit(1 if any(x['status'] == 'FAIL' for x in results) else 0)
