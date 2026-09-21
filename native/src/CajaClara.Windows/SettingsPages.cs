using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using CajaClara.Core;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace CajaClara.Windows;

public sealed record RemoteSettings(string Server, string Token);
public static class DeviceSecrets
{
    private static string PathName => Path.Combine(App.DataDirectory, "device.protected");
    private static readonly byte[] Entropy = Encoding.UTF8.GetBytes("LUNA.CajaClara.Native.Device.v1");
    public static RemoteSettings? Load()
    {
        if (!File.Exists(PathName)) return null;
        return Json.Read<RemoteSettings>(Encoding.UTF8.GetString(ProtectedData.Unprotect(File.ReadAllBytes(PathName), Entropy, DataProtectionScope.CurrentUser)));
    }
    public static void Save(RemoteSettings settings)
    {
        var encrypted = ProtectedData.Protect(Encoding.UTF8.GetBytes(Json.Write(settings)), Entropy, DataProtectionScope.CurrentUser);
        File.WriteAllBytes(PathName + ".new", encrypted); File.Move(PathName + ".new", PathName, true);
    }
}
public sealed partial class MainWindow
{
    private CancellationTokenSource? syncCancellation;
    private async Task StartSyncAsync()
    {
        if (syncCancellation is not null)
        {
            syncCancellation.Cancel(); if (syncTask is not null) { try { await syncTask; } catch (OperationCanceledException) { } }
            syncCancellation.Dispose(); syncHttp?.Dispose(); sync = null;
        }
        var settings = DeviceSecrets.Load();
        if (settings is not null)
        {
            var address = new Uri(settings.Server); SyncClient.ValidateServer(address, true);
            syncHttp = new HttpClient(new HttpClientHandler { AllowAutoRedirect = false }) { BaseAddress = address, Timeout = TimeSpan.FromSeconds(25) };
            sync = new SyncClient(vm.Store, syncHttp, settings.Token);
            syncCancellation = CancellationTokenSource.CreateLinkedTokenSource(lifetime.Token);
            syncTask = sync.RunAsync(syncCancellation.Token);
        }
        await Task.Run(() => AutoBackup.Run(vm.Store, Path.Combine(App.DataDirectory, "backups", "automatic")));
    }
    private UIElement BuildSettings()
    {
        var panel = Column(18); var business = vm.Snapshot?.Business ?? throw new BusinessException("Sin comercio.");
        panel.Children.Add(Card(Column(Heading("Tu cuenta", 20), Body(vm.User.Name + " · " + vm.User.Role), Row(Button("Configurar PIN", async () =>
        {
            var pin = new PasswordBox { Header = "PIN de seis dígitos", MaxLength = 6 };
            await FormAsync("Bloqueo rápido", Column(pin, Body("El PIN se guarda protegido por hash. Cinco errores bloquean temporalmente el acceso.")), async () => { var value = pin.Password; await Task.Run(() => vm.Auth.SetPin(vm.User, value)); pin.Password = ""; });
        }), Button("Bloquear", LockAsync), Button("Cerrar sesión", async () =>
        {
            if (vm.Cart.Count > 0 && !await ConfirmAsync("Cerrar sesión", "Se descartará el carrito sin confirmar.", "Cerrar sesión")) return;
            vm.Logout(); timer.Stop(); await EnterAsync();
        })))));
        if (vm.CanManage)
        {
            panel.Children.Add(Card(Column(Heading("Comercio", 20), Body($"{business.Name}\nCUIT: {(business.TaxId.Length == 0 ? "Sin configurar" : business.TaxId)}\n{business.Address}\n{business.TaxCondition}"), Button("Editar datos", async () =>
            {
                var name = Input("Nombre", business.Name); var tax = Input("CUIT", business.TaxId); var address = Input("Domicilio", business.Address); var condition = Input("Condición fiscal", business.TaxCondition);
                if (await FormAsync("Datos del comercio", Column(name, tax, address, condition), async () => { var businessName = name.Text; var taxId = tax.Text; var location = address.Text; var taxCondition = condition.Text; await Task.Run(() => vm.Pos.Configure(vm.User, businessName, taxId, location, taxCondition)); })) await Navigate("settings");
            }))));
            panel.Children.Add(Card(Column(Heading("Panel remoto del dueño", 20), Body(sync is null ? "No vinculado. La caja funciona localmente. El panel requiere un servidor Caja Clara Backend con HTTPS." : $"Estado: {sync.Health.Status}\nÚltima confirmación: {sync.Health.LastSuccess?.ToLocalTime().ToString("g") ?? "Todavía no sincronizado"}"),
                Row(Button("Vincular dispositivo", async () =>
                {
                    var server = Input("URL HTTPS del servidor", DeviceSecrets.Load()?.Server ?? ""); var code = Input("Código de vinculación generado por el dueño");
                    if (await FormAsync("Vincular Caja Clara Control", Column(server, code, Body("El código es de un solo uso. No ingreses contraseñas de Mercado Pago o ARCA aquí.")), async () =>
                    {
                        if (!Uri.TryCreate(server.Text.Trim().TrimEnd('/') + "/", UriKind.Absolute, out var address)) throw new BusinessException("URL inválida.");
                        SyncClient.ValidateServer(address, true);
                        using var http = new HttpClient(new HttpClientHandler { AllowAutoRedirect = false }) { BaseAddress = address, Timeout = TimeSpan.FromSeconds(25) };
                        using var response = await http.PostAsJsonAsync("api/pair", new PairRequest(code.Text.Trim(), business.Id, business.DeviceId, Environment.MachineName), Json.Options);
                        if (!response.IsSuccessStatusCode) throw new BusinessException("No se pudo vincular. Revisá el servidor, el código y su vencimiento.");
                        var paired = await response.Content.ReadFromJsonAsync<PairResponse>(Json.Options) ?? throw new BusinessException("Respuesta de vinculación inválida.");
                        if (paired.DeviceToken.Length < 32) throw new BusinessException("El servidor no entregó una credencial válida.");
                        DeviceSecrets.Save(new(address.AbsoluteUri, paired.DeviceToken));
                    }, "Vincular")) { await StartSyncAsync(); await Navigate("settings"); }
                }), Button("Sincronizar ahora", async () =>
                {
                    if (sync is null) throw new BusinessException("Primero vinculá el panel remoto.");
                    vm.Store.RetrySync(); await vm.RefreshAsync(); UpdateStatus(); Notify("Se habilitaron los eventos pendientes para el próximo ciclo de sincronización.");
                })))));
            panel.Children.Add(Card(Column(Heading("Impresoras y comprobantes", 20), Body("58 mm, 80 mm o A4 mediante el controlador de Windows. El comprobante interno no reemplaza la factura fiscal."), Button("Configurar impresora", async () =>
            {
                var current = PrinterPreferences.Load(); var printers = WindowsPrinter.Names();
                if (printers.Length == 0) throw new BusinessException("Windows no tiene impresoras instaladas.");
                var selected = new ComboBox { Header = "Impresora", ItemsSource = printers, SelectedItem = printers.Contains(current.PrinterName) ? current.PrinterName : printers[0], MinWidth = 320 };
                var width = new ComboBox { Header = "Ancho en milímetros", ItemsSource = new[] { 58, 80, 210 }, SelectedItem = current.WidthMm, MinWidth = 240 };
                await FormAsync("Impresión", Column(selected, width), () => { new PrinterPreferences(selected.SelectedItem?.ToString() ?? "", (int)(width.SelectedItem ?? 80)).Save(); return Task.CompletedTask; });
            }))));
            panel.Children.Add(Card(Column(Heading("Facturación y pagos integrados", 20), Body("Los cobros electrónicos de esta edición son registros manuales. La cola fiscal conserva solicitudes pendientes sin generar CAE ni numeración ficticia. La emisión ARCA y la conciliación Mercado Pago no están habilitadas para producción."),
                Button("Ver documentos pendientes", async () =>
                {
                    var documents = vm.Snapshot?.Invoices ?? [];
                    var detail = documents.Length == 0 ? "No hay solicitudes fiscales pendientes." : string.Join("\n\n", documents.Select(x => $"{x.At.ToLocalTime():g} · {x.State}\nVenta {x.SaleId}\n{x.Detail}"));
                    await FormAsync("Cola fiscal", Column(Body(detail)), () => Task.CompletedTask, "Cerrar");
                }))));
            panel.Children.Add(Card(Column(Heading("Copias de seguridad", 20), Body("Respaldo SQLite consistente, verificación SHA-256 y rotación automática. Los datos están separados de los archivos del programa."),
                Row(Button("Crear respaldo", async () =>
                {
                    var path = await Task.Run(() => vm.Pos.Backup(vm.User, Path.Combine(App.DataDirectory, "backups", "manual")));
                    Notify("Respaldo creado y acompañado por su manifiesto de integridad."); Launch(Path.GetDirectoryName(path) ?? App.DataDirectory);
                }), Button("Validar respaldo", async () =>
                {
                    var path = await OpenPathAsync(".sqlite"); if (path is null) return;
                    var manifest = await Task.Run(() => Store.ValidateBackup(path));
                    Notify($"Respaldo íntegro de {manifest.At.ToLocalTime():g}. La restauración se realiza con la app cerrada desde la terminal.");
                }), Button("Abrir carpeta de datos", () => { Launch(App.DataDirectory); return Task.CompletedTask; })))));
            panel.Children.Add(Card(Column(Heading("Usuarios y permisos", 20), Body("Cada operación se valida también en el núcleo, no solo en los botones."), Button("Administrar usuarios", UsersAsync))));
        }
        panel.Children.Add(Card(Column(Heading("Diagnóstico", 20), Body("Las comprobaciones distinguen componentes instalados de servicios realmente verificados."), Button("Ejecutar comprobaciones", async () =>
        {
            var integrity = await Task.Run(vm.Store.Integrity); var settings = PrinterPreferences.Load(); var names = WindowsPrinter.Names();
            var text = $"Base local: {integrity}\nEventos pendientes: {vm.Snapshot?.PendingSync}\nServidor: {sync?.Health.Status ?? "SIN CONFIGURAR"}\nÚltima sincronización confirmada: {sync?.Health.LastSuccess?.ToLocalTime().ToString("g") ?? "NINGUNA"}\nImpresora: {(names.Contains(settings.PrinterName) ? "CONTROLADOR INSTALADO; SALIDA FÍSICA NO VERIFICADA" : "SIN CONFIGURAR")}\nARCA: NO HABILITADO\nMercado Pago integrado: NO HABILITADO\nDatos: {App.DataDirectory}";
            await FormAsync("Diagnóstico de Caja Clara", Column(Body(text)), () => Task.CompletedTask, "Cerrar");
        }))));
        return panel;
    }
    private async Task UsersAsync()
    {
        var users = await Task.Run(() => vm.Auth.Users(vm.User));
        var list = new ListView { ItemsSource = users.Select(x => $"{x.Name} · {x.Username} · {x.Role} · {(x.Active ? "Activo" : "Desactivado")}").ToArray(), Height = 220 };
        var username = Input("Usuario nuevo"); var name = Input("Nombre");
        var role = new ComboBox { Header = "Rol", ItemsSource = Enum.GetValues<Role>(), SelectedItem = Role.Cashier, MinWidth = 240 };
        var password = new PasswordBox { Header = "Contraseña nueva (12 o más caracteres)", MaxLength = 256 };
        var disable = new CheckBox { Content = "Cambiar estado del usuario seleccionado, en lugar de crear uno" };
        await FormAsync("Usuarios", Column(list, disable, username, name, role, password), async () =>
        {
            if (disable.IsChecked == true)
            {
                if (list.SelectedIndex < 0) throw new BusinessException("Seleccioná un usuario."); var selected = users[list.SelectedIndex];
                await Task.Run(() => vm.Auth.SetActive(vm.User, selected.Id, !selected.Active));
            }
            else
            {
                if (role.SelectedItem is not Role selectedRole) throw new BusinessException("Elegí un rol.");
                var login = username.Text; var displayName = name.Text; var secret = password.Password; await Task.Run(() => vm.Auth.AddUser(vm.User, login, displayName, selectedRole, secret)); password.Password = "";
            }
        });
    }
    private async Task LockAsync()
    {
        if (dialogOpen) return; dialogOpen = true; var actor = vm.User;
        var pin = new PasswordBox { Header = "PIN de seis dígitos", MaxLength = 6 }; var error = Body("Ingresá tu PIN. También podés cerrar sesión y entrar con contraseña.");
        var dialog = new ContentDialog { XamlRoot = root.XamlRoot, Title = "Caja Clara bloqueada", Content = Column(pin, error), PrimaryButtonText = "Desbloquear", SecondaryButtonText = "Cerrar sesión", DefaultButton = ContentDialogButton.Primary };
        var authorized = false;
        dialog.PrimaryButtonClick += async (_, e) =>
        {
            var deferral = e.GetDeferral();
            try { var secret = pin.Password; authorized = await Task.Run(() => vm.Auth.Unlock(actor, secret)); if (!authorized) { e.Cancel = true; error.Text = "PIN inválido, sin configurar o temporalmente bloqueado."; } }
            catch (Exception ex) { e.Cancel = true; error.Text = ex is BusinessException ? ex.Message : "No se pudo validar el PIN."; }
            finally { pin.Password = ""; deferral.Complete(); }
        };
        dialog.Closing += (_, e) => { if (!authorized && e.Result != ContentDialogResult.Secondary) e.Cancel = true; };
        ContentDialogResult result;
        try { result = await dialog.ShowAsync(); } finally { dialogOpen = false; }
        if (result == ContentDialogResult.Secondary) { vm.Logout(); timer.Stop(); await EnterAsync(); }
    }
}
public static class AutoBackup
{
    public static void Run(Store store, string directory)
    {
        Directory.CreateDirectory(directory); var files = new DirectoryInfo(directory).GetFiles("CajaClara-*.sqlite");
        if (files.Any(x => x.CreationTimeUtc.Date == DateTime.UtcNow.Date)) return;
        store.Backup(directory);
        files = new DirectoryInfo(directory).GetFiles("CajaClara-*.sqlite");
        var ordered = files.OrderByDescending(x => x.CreationTimeUtc).ToArray();
        var keep = ordered.GroupBy(x => x.CreationTimeUtc.Date).Take(7).Select(x => x.First().FullName).ToHashSet(StringComparer.OrdinalIgnoreCase);
        foreach (var group in ordered.GroupBy(x => (System.Globalization.ISOWeek.GetYear(x.CreationTimeUtc), System.Globalization.ISOWeek.GetWeekOfYear(x.CreationTimeUtc))).Take(4)) keep.Add(group.First().FullName);
        foreach (var file in ordered.Where(x => !keep.Contains(x.FullName)))
        {
            if (!File.Exists(file.FullName + ".manifest.json")) continue;
            file.Delete(); File.Delete(file.FullName + ".manifest.json");
        }
    }
}
