from pathlib import Path
root = Path(__file__).resolve().parents[1]
p = root / 'src/CajaClara.Windows/App.xaml.cs'
s = p.read_text(encoding='utf-8')
s = s.replace('        InitializeComponent();', '''        SafeLog("APP_CONSTRUCTOR");
        AppDomain.CurrentDomain.UnhandledException += (_, e) => SafeLog("APP_DOMAIN_FATAL", e.ExceptionObject as Exception);
        try { InitializeComponent(); SafeLog("XAML_RESOURCES_LOADED"); }
        catch (Exception error) { SafeLog("XAML_INITIALIZATION_FAILED", error); throw; }''') if 'APP_CONSTRUCTOR' not in s else s
s = s.replace('            Directory.CreateDirectory(DataDirectory);', '            SafeLog("ON_LAUNCHED");\n            Directory.CreateDirectory(DataDirectory);') if 'SafeLog("ON_LAUNCHED")' not in s else s
s = s.replace('            window.Activate();', '            SafeLog("WINDOW_CREATED"); window.Activate(); SafeLog("WINDOW_ACTIVATED");')
p.write_text(s, encoding='utf-8')
p = root / 'tests/ui_smoke.py'
s = p.read_text(encoding='utf-8')
s = s.replace('from pywinauto import Application', 'from pywinauto import Application, Desktop')
s = s.replace('import traceback', 'import traceback\nimport shutil') if 'import shutil' not in s else s
s = s.replace('    if process:\n        process.terminate()', '''    try:
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
        process.terminate()''') if 'windows-startup-diagnostics.json' not in s else s
p.write_text(s, encoding='utf-8')
print('Added startup diagnostics and resource index publish validation.')
