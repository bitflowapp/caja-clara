from pathlib import Path
root = Path(__file__).resolve().parents[1]
p = root / 'src/CajaClara.Windows/MainWindow.cs'
s = p.read_text(encoding='utf-8')
s = s.replace('private static TextBox Input(string label, string value = "") => new() { Header = label, Text = value, MinWidth = 240, MaxLength = 1000 };', '''private static TextBox Input(string label, string value = "")
    {
        var field = new TextBox { Header = label, Text = value, MinWidth = 240, MaxLength = 1000 };
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetAutomationId(field, label);
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(field, label);
        return field;
    }''')
s = s.replace('var form = Column(); if (setup)', 'Microsoft.UI.Xaml.Automation.AutomationProperties.SetAutomationId(password, "login-password");\n        var form = Column(); if (setup)')
s = s.replace('if (accent) button.Style', 'Microsoft.UI.Xaml.Automation.AutomationProperties.SetAutomationId(button, label);\n        if (accent) button.Style') if 'SetAutomationId(button, label)' not in s else s
s = s.replace('await Run(async () => { await vm.RefreshAsync(); UpdateStatus(); });', 'await Run(async () => { await vm.RefreshAsync(); UpdateStatus(); await Task.Run(() => AutoBackup.Run(vm.Store, Path.Combine(App.DataDirectory, "backups", "automatic"))); });')
p.write_text(s, encoding='utf-8')
p = root / 'src/CajaClara.Windows/PosPages.cs'
s = p.read_text(encoding='utf-8')
s = s.replace('void Filter()\n        {', 'Microsoft.UI.Xaml.Automation.AutomationProperties.SetAutomationId(products, "pos-products");\n        void Filter()\n        {') if 'SetAutomationId(products, "pos-products")' not in s else s
s = s.replace('var total = Heading(vm.TotalText, 36);', 'Microsoft.UI.Xaml.Automation.AutomationProperties.SetAutomationId(cartList, "pos-cart");\n        var total = Heading(vm.TotalText, 36);') if 'SetAutomationId(cartList, "pos-cart")' not in s else s
p.write_text(s, encoding='utf-8')
p = root / 'src/CajaClara.Windows/SettingsPages.cs'
s = p.read_text(encoding='utf-8')
s = s.replace('var settings = DeviceSecrets.Load();\n        if (settings is not null)', '''RemoteSettings? settings;
        try { settings = DeviceSecrets.Load(); }
        catch (Exception error) when (error is CryptographicException or IOException or System.Text.Json.JsonException)
        { App.SafeLog("DEVICE_CREDENTIALS_UNREADABLE", error); settings = null; }
        if (settings is not null)''')
p.write_text(s, encoding='utf-8')
print('Applied automation identifiers and resilient daily backups.')
