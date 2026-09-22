using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using CajaClara.Core;
using CajaClara.Fiscal;
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
        RemoteSettings? settings;
        try { settings = DeviceSecrets.Load(); }
        catch (Exception error) when (error is CryptographicException or IOException or System.Text.Json.JsonException)
        { App.SafeLog("DEVICE_CREDENTIALS_UNREADABLE", error); settings = null; }
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
            panel.Children.Add(Card(Column(Heading("Facturación electrónica ARCA", 20),
                Body(FiscalSummaryText()),
                Row(Button("Configurar ARCA", ConfigureFiscalAsync, true), Button("Procesar cola fiscal", ProcessFiscalQueueAsync)),
                Button("Ver documentos fiscales", async () =>
                {
                    var documents = vm.Snapshot?.Invoices.OrderByDescending(x => x.At).ToArray() ?? [];
                    var detail = documents.Length == 0 ? "No hay solicitudes fiscales." : string.Join("\n\n", documents.Select(x =>
                        $"{x.At.ToLocalTime():g} · {Labels.Fiscal(x.State)}\nPV {x.PointOfSale} · Tipo {x.VoucherType} · Nº {x.VoucherNumber?.ToString() ?? "—"}\nCAE: {x.Cae ?? "—"}\n{x.Detail}"));
                    await FormAsync("Documentos fiscales", Column(Body(detail)), () => Task.CompletedTask, "Cerrar");
                }),
                Body("Una venta se guarda primero en SQLite. Si pedís factura y ARCA está configurado, Caja Clara intenta autorizarla después; un error de red nunca borra la venta ni inventa un CAE."))));
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
            var text = $"Base local: {integrity}\nEventos pendientes: {vm.Snapshot?.PendingSync}\nServidor: {sync?.Health.Status ?? "SIN CONFIGURAR"}\nÚltima sincronización confirmada: {sync?.Health.LastSuccess?.ToLocalTime().ToString("g") ?? "NINGUNA"}\nImpresora: {(names.Contains(settings.PrinterName) ? "CONTROLADOR INSTALADO; SALIDA FÍSICA NO VERIFICADA" : "SIN CONFIGURAR")}\nARCA: {(fiscal.Configured ? "CONFIGURADO; validar homologación/producción y certificado" : "SIN CONFIGURAR")}\nMercado Pago integrado: {(sync is null ? "PANEL REMOTO NO VINCULADO" : "PROVEEDOR SERVER-SIDE DISPONIBLE; estado de cuenta se valida en el panel")}\nDatos: {App.DataDirectory}";
            await FormAsync("Diagnóstico de Caja Clara", Column(Body(text)), () => Task.CompletedTask, "Cerrar");
        }))));
        return panel;
    }
    private string FiscalSummaryText()
    {
        try
        {
            var value = FiscalSecrets.Summary();
            if (value is null) return "ARCA sin configurar. Las ventas que pidan factura quedarán pendientes hasta importar el certificado y definir punto de venta.";
            var voucher = value.VoucherType switch { 1 => "Factura A", 6 => "Factura B", 11 => "Factura C", _ => "Tipo " + value.VoucherType };
            return $"ARCA {value.Environment} · CUIT {value.Cuit} · Punto de venta {value.PointOfSale} · {voucher}. El certificado y su contraseña se guardan cifrados para este usuario de Windows.";
        }
        catch (BusinessException error) { return "Configuración fiscal bloqueada: " + error.Message; }
    }

    private async Task ConfigureFiscalAsync()
    {
        FiscalDeviceSettings? current = null;
        try { current = FiscalSecrets.Load(); } catch (BusinessException) { }
        var business = vm.Snapshot?.Business ?? throw new BusinessException("Sin comercio.");
        var cuit = Input("CUIT emisor", current?.Cuit.ToString() ?? business.TaxId);
        var point = Input("Punto de venta electrónico", current?.PointOfSale.ToString() ?? "");
        var environment = new ComboBox
        {
            Header = "Ambiente",
            ItemsSource = Enum.GetValues<ArcaEnvironment>(),
            SelectedItem = current?.Environment ?? ArcaEnvironment.Homologacion,
            MinWidth = 260
        };
        var voucher = new ComboBox
        {
            Header = "Comprobante por defecto",
            ItemsSource = new[] { "Factura A · 1", "Factura B · 6", "Factura C · 11" },
            SelectedIndex = current?.DefaultVoucherType switch { 1 => 0, 6 => 1, 11 => 2, _ => 1 },
            MinWidth = 260
        };
        var certificateState = Body(current is null ? "Certificado: no importado." : "Certificado: ya guardado y protegido. Elegí otro archivo solo para reemplazarlo.");
        string? certificatePath = null;
        var choose = Button("Elegir certificado .pfx", async () =>
        {
            certificatePath = await OpenPathAsync(".pfx");
            certificateState.Text = certificatePath is null ? certificateState.Text : "Certificado seleccionado: " + Path.GetFileName(certificatePath);
        });
        var password = new PasswordBox { Header = current is null ? "Contraseña del certificado" : "Contraseña nueva (vacío conserva la actual)", MaxLength = 256 };
        var production = new CheckBox { Content = "Entiendo que PRODUCCIÓN puede emitir comprobantes fiscales reales" };
        var saved = await FormAsync("Facturación electrónica ARCA",
            Column(Body("Usá HOMOLOGACIÓN hasta completar pruebas con tu CUIT y punto de venta. Caja Clara nunca convierte un ticket en factura sin respuesta de ARCA."),
                cuit, point, environment, voucher, certificateState, choose, password, production),
            async () =>
            {
                var digits = new string(cuit.Text.Where(char.IsAsciiDigit).ToArray());
                if (!long.TryParse(digits, out var parsedCuit) || digits.Length != 11 || !PosService.ValidCuit(digits))
                    throw new BusinessException("CUIT emisor inválido.");
                if (!int.TryParse(point.Text, out var parsedPoint)) throw new BusinessException("Punto de venta inválido.");
                var selectedEnvironment = environment.SelectedItem is ArcaEnvironment env ? env : ArcaEnvironment.Homologacion;
                if (selectedEnvironment == ArcaEnvironment.Produccion && production.IsChecked != true)
                    throw new BusinessException("Confirmá explícitamente el uso del ambiente PRODUCCIÓN.");
                var voucherType = voucher.SelectedIndex switch { 0 => 1, 1 => 6, 2 => 11, _ => throw new BusinessException("Elegí el tipo de factura.") };
                var certificate = current?.CertificateBase64 ?? "";
                var certificatePassword = current?.CertificatePassword ?? "";
                if (certificatePath is not null)
                {
                    certificate = Convert.ToBase64String(await File.ReadAllBytesAsync(certificatePath));
                    if (string.IsNullOrEmpty(password.Password)) throw new BusinessException("Ingresá la contraseña del certificado nuevo.");
                    certificatePassword = password.Password;
                }
                else if (!string.IsNullOrEmpty(password.Password)) certificatePassword = password.Password;
                var next = new FiscalDeviceSettings(parsedCuit, parsedPoint, voucherType, selectedEnvironment, certificate, certificatePassword);
                await Task.Run(() => FiscalSecrets.Save(next));
                password.Password = "";
            }, "Guardar configuración");
        if (saved) { await Navigate("settings"); Notify("Configuración fiscal guardada de forma protegida."); }
    }

    private async Task ProcessFiscalQueueAsync()
    {
        if (!fiscal.Configured) throw new BusinessException("Configurá ARCA antes de procesar la cola.");
        await vm.RefreshAsync();
        var documents = vm.Snapshot?.Invoices.Where(x => x.State is FiscalState.Pending or FiscalState.Unknown).OrderBy(x => x.At).Take(20).ToArray() ?? [];
        if (documents.Length == 0) { Notify("No hay documentos fiscales pendientes."); return; }
        var completed = 0;
        foreach (var document in documents)
        {
            try
            {
                var result = await fiscal.ProcessSaleAsync(vm.User, document.SaleId, lifetime.Token);
                if (result.State == FiscalState.Authorized) completed++;
                else if (result.State == FiscalState.Rejected)
                {
                    Notify($"ARCA rechazó un comprobante. Venta {document.SaleId}: {result.Detail}", InfoBarSeverity.Warning);
                    break;
                }
                else
                {
                    Notify($"Resultado fiscal todavía no confirmado. Venta {document.SaleId}: {result.Detail}", InfoBarSeverity.Warning);
                    break;
                }
            }
            catch (Exception error) when (error is BusinessException or HttpRequestException or TaskCanceledException)
            {
                App.SafeLog("FISCAL_QUEUE_PAUSED", error);
                Notify("La cola fiscal quedó preservada: " + error.Message, InfoBarSeverity.Warning);
                break;
            }
        }
        await vm.RefreshAsync();
        if (completed > 0) Notify($"{completed} comprobante(s) autorizados por ARCA.");
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
