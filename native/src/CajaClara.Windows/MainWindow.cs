using CajaClara.Core;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using global::Windows.UI.ViewManagement;
using global::Windows.System;
using System.Diagnostics;

namespace CajaClara.Windows;

public sealed partial class MainWindow : Window
{
    private readonly MainViewModel vm;
    private readonly FiscalCoordinator fiscal;
    private readonly MercadoPagoRemoteClient mercadoPago;
    private readonly Grid root = new();
    private readonly NavigationView nav = new() { IsSettingsVisible = false, IsBackButtonVisible = NavigationViewBackButtonVisible.Collapsed, PaneDisplayMode = NavigationViewPaneDisplayMode.Auto, OpenPaneLength = 218 };
    private readonly InfoBar message = new() { IsClosable = true, Margin = new Thickness(20, 8, 20, 8) };
    private readonly ProgressBar progress = new() { IsIndeterminate = true, Height = 3, Visibility = Visibility.Collapsed };
    private readonly TextBlock status = new() { Margin = new Thickness(24, 8, 24, 10), FontSize = 12, TextWrapping = TextWrapping.Wrap };
    private readonly UISettings uiSettings = new();
    private readonly CancellationTokenSource lifetime = new();
    private readonly DispatcherTimer timer = new() { Interval = TimeSpan.FromSeconds(10) };
    private bool busy;
    private bool dialogOpen;
    private bool started;
    private string page = "pos";
    private SyncClient? sync;
    private HttpClient? syncHttp;
    private Task? syncTask;
    private TextBox? searchBox;
    private ListView? cartList;
    private ComboBox? customerBox;
    private TextBox? saleNotes;
    private CheckBox? fiscalPending;
    public MainWindow(MainViewModel vm, FiscalCoordinator fiscal, MercadoPagoRemoteClient mercadoPago)
    {
        this.vm = vm; this.fiscal = fiscal; this.mercadoPago = mercadoPago; Title = "Caja Clara · Tu negocio, claro.";
        var display = Microsoft.UI.Windowing.DisplayArea.GetFromWindowId(AppWindow.Id, Microsoft.UI.Windowing.DisplayAreaFallback.Primary);
        var work = display.WorkArea;
        var width = Math.Min(1360, Math.Max(640, work.Width - 32));
        var height = Math.Min(900, Math.Max(480, work.Height - 32));
        AppWindow.MoveAndResize(new global::Windows.Graphics.RectInt32(work.X + (work.Width - width) / 2, work.Y + (work.Height - height) / 2, width, height));
        if (Microsoft.UI.Composition.SystemBackdrops.MicaController.IsSupported()) SystemBackdrop = new MicaBackdrop();
        root.Language = "es-AR";
        root.RowDefinitions.Add(new() { Height = GridLength.Auto }); root.RowDefinitions.Add(new() { Height = new(1, GridUnitType.Star) }); root.RowDefinitions.Add(new() { Height = GridLength.Auto });
        Grid.SetRow(progress, 0); root.Children.Add(progress); Grid.SetRow(nav, 1); root.Children.Add(nav); Grid.SetRow(status, 2); root.Children.Add(status);
        nav.Header = "CAJA CLARA"; nav.PaneFooter = new TextBlock { Text = "LUNA · Native 0.2.0", Margin = new Thickness(16), Opacity = .65, FontSize = 12 };
        nav.SelectionChanged += async (_, e) => { if (e.SelectedItem is NavigationViewItem { Tag: string tag } && vm.Actor is not null) await Run(() => Navigate(tag)); };
        Content = root;
        root.Loaded += async (_, _) => { if (!started) { started = true; await Run(EnterAsync); } };
        uiSettings.ColorValuesChanged += (_, _) => DispatcherQueue.TryEnqueue(ApplySystemTheme);
        ApplySystemTheme();
        AddKey(VirtualKey.F1, () => { searchBox?.Focus(FocusState.Programmatic); searchBox?.SelectAll(); return Task.CompletedTask; });
        AddKey(VirtualKey.F2, () => { customerBox?.Focus(FocusState.Programmatic); return Task.CompletedTask; });
        AddKey(VirtualKey.F4, PayAsync); AddKey(VirtualKey.F6, EditCartAsync); AddKey(VirtualKey.F7, EditCartAsync);
        AddKey(VirtualKey.F8, NewSaleAsync);
        timer.Tick += async (_, _) =>
        {
            if (busy || dialogOpen || vm.Actor is null) return;
            await Run(async () => { await vm.RefreshAsync(); UpdateStatus(); await Task.Run(() => AutoBackup.Run(vm.Store, Path.Combine(App.DataDirectory, "backups", "automatic"))); });
        };
        Closed += (_, _) => { timer.Stop(); lifetime.Cancel(); syncHttp?.Dispose(); lifetime.Dispose(); };
    }
    private void ApplySystemTheme()
    {
        var background = uiSettings.GetColorValue(UIColorType.Background);
        root.RequestedTheme = background.R + background.G + background.B > 380 ? ElementTheme.Light : ElementTheme.Dark;
        var accent = uiSettings.GetColorValue(UIColorType.Accent);
        AppWindow.TitleBar.BackgroundColor = accent;
        AppWindow.TitleBar.ButtonBackgroundColor = accent;
        var foreground = accent.R * .299 + accent.G * .587 + accent.B * .114 > 150 ? Colors.Black : Colors.White;
        AppWindow.TitleBar.ForegroundColor = foreground; AppWindow.TitleBar.ButtonForegroundColor = foreground;
    }
    private void AddKey(VirtualKey key, Func<Task> action)
    {
        var accelerator = new KeyboardAccelerator { Key = key };
        accelerator.Invoked += async (_, e) => { if (!dialogOpen && vm.Actor is not null && page == "pos") { e.Handled = true; await Run(action); } };
        root.KeyboardAccelerators.Add(accelerator);
    }
    public void ShowError(string text) => Notify(text, InfoBarSeverity.Error);
    private void Notify(string text, InfoBarSeverity severity = InfoBarSeverity.Success)
    { message.Severity = severity; message.Message = text; message.IsOpen = true; }
    private async Task Run(Func<Task> action)
    {
        if (busy) return; busy = true; progress.Visibility = Visibility.Visible;
        try { await action(); }
        catch (BusinessException e) { ShowError(e.Message); }
        catch (OperationCanceledException) when (lifetime.IsCancellationRequested) { }
        catch (Exception e) { App.SafeLog("OPERATION_FAILED", e); ShowError("No se completó la operación. " + (e is IOException ? "Revisá el archivo, espacio libre y permisos." : e.Message)); }
        finally { busy = false; progress.Visibility = Visibility.Collapsed; }
    }
    private async Task EnterAsync()
    {
        nav.MenuItems.Clear(); nav.Content = new StackPanel { Margin = new Thickness(36), Children = { Heading("Tu negocio, claro.", 34), Body("Ventas, caja y stock en tu PC. Tus datos permanecen en este equipo."), message } };
        await LoginAsync(vm.Pos.NeedsSetup);
        if (vm.Actor is null) { Close(); return; }
        BuildMenu(); await StartSyncAsync(); timer.Start(); await Navigate("pos");
    }
    private async Task LoginAsync(bool setup)
    {
        var business = Input("Nombre del comercio"); var name = Input("Tu nombre"); var user = Input("Usuario");
        var password = new PasswordBox { Header = "Contraseña (mínimo 12 caracteres)", MaxLength = 256 };
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetAutomationId(password, "login-password");
        var form = Column(); if (setup) { form.Children.Add(business); form.Children.Add(name); } form.Children.Add(user); form.Children.Add(password);
        form.Children.Add(Body(setup ? "Creá una contraseña propia. No existen usuarios ni contraseñas predeterminadas." : "Ingresá con el usuario de este comercio."));
        await FormAsync(setup ? "Bienvenido a Caja Clara" : "Iniciar sesión", form, async () =>
        {
            if (setup) await vm.BootstrapAsync(business.Text, name.Text, user.Text, password.Password);
            else await vm.LoginAsync(user.Text, password.Password);
            password.Password = "";
        }, setup ? "Crear comercio" : "Entrar");
    }
    private void BuildMenu()
    {
        nav.MenuItems.Clear();
        foreach (var (tag, text, icon) in new (string, string, Symbol)[] {
            ("pos","Vender",Symbol.Shop), ("dashboard","Resumen",Symbol.Home), ("products","Productos y stock",Symbol.List),
            ("cash","Caja",Symbol.Calculator), ("sales","Ventas",Symbol.Document), ("contacts","Clientes y proveedores",Symbol.People),
            ("purchases","Compras",Symbol.Download), ("reports","Reportes",Symbol.AllApps), ("settings","Configuración",Symbol.Setting) })
            nav.MenuItems.Add(new NavigationViewItem { Tag = tag, Content = text, Icon = new SymbolIcon(icon) });
    }
    private async Task Navigate(string target)
    {
        await vm.RefreshAsync(); page = target; message.IsOpen = false;
        if (message.Parent is Panel parent) parent.Children.Remove(message);
        var panel = Column(18); panel.Margin = new Thickness(24, 12, 24, 24); panel.Children.Add(message);
        var content = target switch
        {
            "pos" => BuildPos(), "dashboard" => BuildDashboard(), "products" => BuildProducts(), "cash" => BuildCash(),
            "sales" => BuildSales(), "contacts" => BuildContacts(), "purchases" => BuildPurchases(), "reports" => BuildReports(), _ => BuildSettings()
        };
        panel.Children.Add(content);
        nav.Content = new ScrollViewer { Content = panel, HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        nav.Header = target switch { "pos" => "Vender", "dashboard" => "Tu negocio hoy", "products" => "Productos y stock", "cash" => "Caja", "sales" => "Historial de ventas", "contacts" => "Clientes y proveedores", "purchases" => "Compras y mercadería", "reports" => "Reportes", _ => "Configuración" };
        UpdateStatus();
    }
    private void UpdateStatus()
    {
        var state = vm.Snapshot; if (state is null) return;
        status.Text = $"{state.Business?.Name}  ·  {vm.User.Name} ({Labels.UserRole(vm.User.Role)})  ·  " +
            (state.Cash is null ? "Caja cerrada" : $"Caja abierta · Efectivo {Money.Format(state.Cash.ExpectedCents)}") +
            $"  ·  {state.PendingSync} eventos pendientes  ·  " + (sync?.Health.Status ?? "Solo local; panel remoto sin vincular") +
            (state.Business?.Demo == true ? "  ·  DEMOSTRACIÓN" : "");
    }
    private async Task<bool> FormAsync(string title, StackPanel fields, Func<Task> commit, string primary = "Guardar")
    {
        if (dialogOpen) return false;
        dialogOpen = true; var error = Body(""); error.Foreground = new SolidColorBrush(Colors.IndianRed); fields.Children.Add(error);
        var dialog = new ContentDialog { XamlRoot = root.XamlRoot, Title = title, PrimaryButtonText = primary, CloseButtonText = "Cancelar", DefaultButton = ContentDialogButton.Primary,
            Content = new ScrollViewer { Content = fields, MaxHeight = 560, VerticalScrollBarVisibility = ScrollBarVisibility.Auto } };
        dialog.PrimaryButtonClick += async (_, e) =>
        {
            var deferral = e.GetDeferral(); dialog.IsPrimaryButtonEnabled = false;
            try { await commit(); }
            catch (Exception ex) { e.Cancel = true; error.Text = ex is BusinessException ? ex.Message : "No se pudo guardar: " + ex.Message; App.SafeLog("FORM_REJECTED", ex); }
            finally { dialog.IsPrimaryButtonEnabled = true; deferral.Complete(); }
        };
        try { return await dialog.ShowAsync() == ContentDialogResult.Primary; } finally { dialogOpen = false; }
    }
    private async Task<bool> ConfirmAsync(string title, string detail, string action = "Confirmar")
        => await FormAsync(title, Column(Body(detail)), () => Task.CompletedTask, action);
    private static StackPanel Column(double spacing = 12) => new() { Spacing = spacing };
    private static StackPanel Column(params UIElement[] elements) { var panel = Column(); foreach (var e in elements) panel.Children.Add(e); return panel; }
    private static StackPanel Row(params UIElement[] elements) { var panel = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10 }; foreach (var e in elements) panel.Children.Add(e); return panel; }
    private static TextBlock Heading(string text, double size = 26) => new() { Text = text, FontSize = size, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold, TextWrapping = TextWrapping.Wrap };
    private static TextBlock Body(string text) => new() { Text = text, TextWrapping = TextWrapping.Wrap, FontSize = 14, LineHeight = 21 };
    private static TextBox Input(string label, string value = "")
    {
        var field = new TextBox { Header = label, Text = value, MinWidth = 240, MaxLength = 1000 };
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetAutomationId(field, label);
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(field, label);
        return field;
    }
    private static long Amount(TextBox input, bool zero = true)
    {
        if (!decimal.TryParse(input.Text, System.Globalization.NumberStyles.Number, Money.Culture, out var amount)) throw new BusinessException("Ingresá un importe válido en " + input.Header + ".");
        var cents = Money.Cents(amount); Money.Valid(cents, zero); return cents;
    }
    private static string DecimalText(long cents) => (cents / 100m).ToString("0.00", Money.Culture);
    private Button Button(string label, Func<Task> action, bool accent = false)
    {
        var button = new Button { Content = label, Padding = new Thickness(16, 10, 16, 10) };
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetAutomationId(button, label);
        if (accent) button.Style = (Style)Application.Current.Resources["AccentButtonStyle"];
        button.Click += async (_, _) => await Run(action); return button;
    }
    private static Border Card(UIElement content) => new() { Style = (Style)Application.Current.Resources["Card"], Child = content };
    private static void Launch(string path) => Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
}
