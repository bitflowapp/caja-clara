using System.Text;
using System.Text.Json;
using CajaClara.Core;
using Microsoft.Data.Sqlite;

Console.OutputEncoding = Encoding.UTF8;
if (args.Length == 0 || args.Contains("--help"))
{
    Console.WriteLine("""
Caja Clara Native · terminal 0.2.0

Uso: cajaclara-cli COMANDO [--db RUTA] [--json] [--input ARCHIVO]

Comandos: init, status, products, product-save, stock-adjust, cash-open,
          cash-close, cash-movement, sale, refund, contacts, contact-save,
          purchase, report, report-xlsx, receipt-pdf, backup, backup-validate,
          restore, sync-once.

Sin --json, el usuario y la contraseña se solicitan por consola. --input
contiene únicamente los datos de la operación. Con --json se lee por stdin:
{"username":"...","password":"...","payload":{...}}

No pases contraseñas como argumentos. La salida de éxito es JSON; los errores
van a stderr y producen código de salida distinto de cero. El comando sale
recibe CheckoutRequest y exige un UUID estable para reintentos idempotentes.
La terminal registra cobros manuales; no confirma fondos bancarios ni emite
facturas fiscales. receipt-pdf genera un comprobante interno no fiscal.

La restauración exige cerrar la app, genera una copia previa y desvincula el
panel remoto para evitar sincronizar un historial restaurado sin conciliación.
""");
    return 0;
}
string? Option(string key) { var index = Array.IndexOf(args, key); if (index < 0) return null; if (index + 1 >= args.Length) throw new BusinessException("Falta valor para " + key); return args[index + 1]; }
string ReadValue(string label) { Console.Error.Write(label + ": "); return Console.ReadLine() ?? ""; }
string ReadSecret()
{
    Console.Error.Write("Contraseña: ");
    if (Console.IsInputRedirected) return Console.ReadLine() ?? "";
    var value = new StringBuilder();
    while (true) { var key = Console.ReadKey(true); if (key.Key == ConsoleKey.Enter) break; if (key.Key == ConsoleKey.Backspace) { if (value.Length > 0) value.Length--; } else if (!char.IsControl(key.KeyChar)) value.Append(key.KeyChar); }
    Console.Error.WriteLine(); return value.ToString();
}
try
{
    var command = args[0];
    var db = Path.GetFullPath(Option("--db") ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "LUNA", "CajaClaraNative", "Business", "caja.sqlite"));
    CliRequest input;
    if (args.Contains("--json"))
    {
        var text = Console.In.ReadToEnd(); if (text.Length > 2_000_000) throw new BusinessException("Solicitud demasiado grande.");
        input = Json.Read<CliRequest>(text);
    }
    else
    {
        var payloadFile = Option("--input");
        var payload = payloadFile is null ? JsonDocument.Parse("{}").RootElement.Clone() : JsonDocument.Parse(File.ReadAllText(payloadFile)).RootElement.Clone();
        input = new(ReadValue("Usuario"), ReadSecret(), payload);
    }
    if (input.Username is null || input.Password is null || input.Payload.ValueKind != JsonValueKind.Object) throw new BusinessException("Solicitud incompleta.");
    T Payload<T>() => Json.Read<T>(input.Payload.GetRawText());
    var store = new Store(db); var auth = new AuthService(store); var pos = new PosService(store); var reports = new Reports(store);
    object? result;
    if (command == "init")
    {
        var setup = Payload<Setup>(); result = auth.Bootstrap(setup.BusinessName, setup.OwnerName, input.Username, input.Password, setup.Demo);
    }
    else
    {
        var actor = auth.Authenticate(input.Username, input.Password);
        result = command switch
        {
            "status" => new { database = store.Integrity(), snapshot = pos.Snapshot(actor) },
            "products" => pos.Snapshot(actor).Products,
            "product-save" => SaveProduct(),
            "stock-adjust" => pos.AdjustStock(actor, Payload<StockAdjustment>()),
            "cash-open" => pos.OpenRegister(actor, Payload<CashInput>().AmountCents, Payload<CashInput>().Notes),
            "cash-close" => pos.CloseRegister(actor, Payload<CashInput>().AmountCents, Payload<CashInput>().Notes),
            "cash-movement" => pos.RecordCashMovement(actor, Payload<MovementInput>().AmountCents, Payload<MovementInput>().Kind, Payload<MovementInput>().Reason),
            "sale" => pos.Checkout(actor, Payload<CheckoutRequest>()),
            "refund" => pos.RefundSale(actor, Payload<RefundInput>().Id, Payload<RefundInput>().SaleId, Payload<RefundInput>().Reason),
            "contacts" => pos.Snapshot(actor).Contacts,
            "contact-save" => SaveContact(),
            "purchase" => Purchase(),
            "report" => reports.Sales(actor, Payload<PeriodInput>().From, Payload<PeriodInput>().To),
            "report-xlsx" => ExportReport(),
            "receipt-pdf" => ExportReceipt(),
            "backup" => new { path = pos.Backup(actor, Payload<PathInput>().Path) },
            "backup-validate" => Validate(),
            "restore" => Restore(),
            "sync-once" => await Sync(),
            _ => throw new BusinessException("Comando desconocido. Consultá --help.")
        };
        Product SaveProduct() { var p = Payload<ProductInput>(); return pos.SaveProduct(actor, p.Product, p.ExpectedVersion); }
        Contact SaveContact() { var p = Payload<ContactInput>(); return pos.SaveContact(actor, p.Contact, p.ExpectedVersion); }
        Purchase Purchase() { var p = Payload<PurchaseInput>(); return pos.ReceivePurchase(actor, p.Id, p.SupplierId, p.Lines, p.PaidFromCashCents, p.Reference); }
        object ExportReport() { var p = Payload<ExportInput>(); reports.ExportSales(actor, p.From, p.To, p.Path); return new { path = Path.GetFullPath(p.Path) }; }
        object ExportReceipt()
        {
            var p = Payload<ReceiptInput>(); var state = pos.Snapshot(actor); var sale = state.Sales.SingleOrDefault(x => x.Id == p.SaleId) ?? throw new BusinessException("Venta inexistente.");
            Receipt.Pdf(p.Path, Receipt.Lines(state.Business ?? throw new BusinessException("Comercio inexistente."), sale), p.WidthMm);
            return new { path = Path.GetFullPath(p.Path), fiscal = false };
        }
        BackupManifest Validate() { if (actor.Role is not (Role.Owner or Role.Admin)) throw new BusinessException("Permiso insuficiente."); return Store.ValidateBackup(Payload<PathInput>().Path); }
        object Restore()
        {
            if (actor.Role != Role.Owner) throw new BusinessException("La restauración requiere al dueño.");
            var p = Payload<RestoreInput>(); var backup = Path.GetFullPath(p.Path);
            if (!p.ConfirmReplaceCurrentDatabase) throw new BusinessException("Confirmá expresamente el reemplazo de la base actual.");
            if (backup.Equals(db, StringComparison.OrdinalIgnoreCase)) throw new BusinessException("El respaldo no puede ser la base actual.");
            var manifest = Store.ValidateBackup(backup); var business = pos.Snapshot(actor).Business;
            if (manifest.BusinessId != business?.Id) throw new BusinessException("El respaldo pertenece a otro comercio.");
            var directory = Path.GetDirectoryName(db) ?? throw new BusinessException("Ruta inválida.");
            using var instance = new Mutex(true, "Local\\LunaCajaClaraNative-" + Json.Hash(directory)[..20], out var created);
            if (!created) throw new BusinessException("Cerrá Caja Clara antes de restaurar.");
            var previous = store.Backup(Path.Combine(directory, "backups", "before-restore"));
            var temporary = db + ".restore-" + Guid.NewGuid().ToString("N");
            File.Copy(backup, temporary); SqliteConnection.ClearAllPools();
            using (var exclusive = new SqliteConnection(new SqliteConnectionStringBuilder { DataSource = db, Pooling = false, DefaultTimeout = 1 }.ToString()))
            {
                exclusive.Open(); using var check = exclusive.CreateCommand(); check.CommandText = "PRAGMA busy_timeout=1000; PRAGMA wal_checkpoint(TRUNCATE); PRAGMA locking_mode=EXCLUSIVE; BEGIN EXCLUSIVE; COMMIT;"; check.ExecuteNonQuery();
            }
            var displaced = db + ".before-restore-" + Guid.NewGuid().ToString("N");
            File.Move(db, displaced);
            try { File.Move(temporary, db); }
            catch { File.Move(displaced, db); throw; }
            foreach (var suffix in new[] { "-wal", "-shm" }) if (File.Exists(db + suffix)) File.Delete(db + suffix);
            var deviceSecret = Path.Combine(directory, "device.protected");
            if (File.Exists(deviceSecret)) File.Move(deviceSecret, deviceSecret + ".disabled-" + DateTime.UtcNow.ToString("yyyyMMddHHmmss"));
            return new { restored = db, backupBeforeRestore = previous, preservedDatabase = displaced, remote = "DISABLED_RECONCILIATION_REQUIRED", warning = "La cuenta y contraseña restauradas son las del respaldo. Conciliá el historial remoto antes de volver a vincular." };
        }
        async Task<object> Sync()
        {
            if (actor.Role != Role.Owner) throw new BusinessException("Sincronización manual requiere al dueño.");
            var p = Payload<SyncInput>(); var uri = new Uri(p.Server.TrimEnd('/') + "/"); SyncClient.ValidateServer(uri, true);
            using var http = new HttpClient(new HttpClientHandler { AllowAutoRedirect = false }) { BaseAddress = uri, Timeout = TimeSpan.FromSeconds(25) };
            var sync = new SyncClient(store, http, p.DeviceToken); await sync.OnceAsync(); return sync.Health;
        }
    }
    Console.WriteLine(Json.Write(result)); return 0;
}
catch (Exception e) when (e is BusinessException or IOException or UnauthorizedAccessException or JsonException or FormatException or InvalidOperationException or SqliteException or HttpRequestException)
{
    Console.Error.WriteLine(Json.Write(new { error = e is BusinessException ? e.Message : "La operación no se completó.", type = e.GetType().Name })); return 1;
}
sealed record CliRequest(string Username, string Password, JsonElement Payload);
sealed record Setup(string BusinessName, string OwnerName, bool Demo = false);
sealed record CashInput(long AmountCents, string Notes = "");
sealed record MovementInput(long AmountCents, string Kind, string Reason);
sealed record ProductInput(Product Product, long ExpectedVersion);
sealed record ContactInput(Contact Contact, long ExpectedVersion);
sealed record RefundInput(Guid Id, Guid SaleId, string Reason);
sealed record PurchaseInput(Guid Id, Guid SupplierId, PurchaseLine[] Lines, long PaidFromCashCents, string Reference);
sealed record PeriodInput(DateTimeOffset From, DateTimeOffset To);
sealed record ExportInput(DateTimeOffset From, DateTimeOffset To, string Path);
sealed record PathInput(string Path);
sealed record ReceiptInput(Guid SaleId, string Path, int WidthMm = 80);
sealed record RestoreInput(string Path, bool ConfirmReplaceCurrentDatabase);
sealed record SyncInput(string Server, string DeviceToken);
