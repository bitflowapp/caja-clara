using System.Security.Cryptography;
using System.Text.Json;
using CajaClara.Core;
using CajaClara.Backend;

if (args.Length > 0 && args[0] == "--seed-browser")
{
    var directory = Path.GetFullPath(args[1]); Directory.CreateDirectory(directory);
    var cloud = new CloudStore(Path.Combine(directory, "cloud.sqlite"));
    var local = new Store(Path.Combine(directory, "local.sqlite")); var auth = new AuthService(local); var pos = new PosService(local);
    var password = Convert.ToHexString(RandomNumberGenerator.GetBytes(20));
    var owner = cloud.Provision(new("Almacén del Río · QA", "qa.owner", "Dueño de prueba", password));
    var user = auth.Bootstrap("Almacén del Río · QA", "Caja de prueba", "qa.local", password, true);
    var sample = new[] { ("ALM001", "Yerba mate 1 kg", 420000L, 280000L, 18000L), ("ALM002", "Leche entera 1 L", 180000L, 110000L, 2000L), ("ALM003", "Pan de campo", 240000L, 120000L, 10000L) };
    var products = new List<Product>();
    foreach (var (code, name, price, cost, stock) in sample) products.Add(pos.SaveProduct(user, new(Guid.NewGuid(), 1, code, "", name, "Almacén", cost, price, 2100, stock, 3000, "un", true), 0));
    pos.OpenRegister(user, 2000000, "Turno de prueba automatizada");
    foreach (var p in products.Take(2)) pos.Checkout(user, new(Guid.NewGuid(), null, [new(p.Id, p.Version, 1000)], [new(PaymentMethod.Cash, p.PriceCents, p.PriceCents, "")], "Venta creada por prueba automatizada"));
    var business = pos.Snapshot(user).Business!; var paired = cloud.Pair(new(cloud.CreatePairCode(owner), business.Id, business.DeviceId, "PC de pruebas")); var device = cloud.Device(paired.DeviceToken)!;
    var events = local.PendingEvents(200).ToArray(); var accepted = cloud.Accept(device, new(business.Id, business.DeviceId, events)); local.Acknowledge(accepted.Accepted);
    File.WriteAllText(Path.Combine(directory, "browser-credentials.json"), Json.Write(new { cloudLogin = owner.Login, localLogin = "qa.local", password, localDb = local.Path, deviceToken = paired.DeviceToken, businessId = business.Id, deviceId = business.DeviceId, productId = products[0].Id }));
    Console.WriteLine("Created isolated browser test data. Credentials were not printed."); return 0;
}
var output = Path.GetFullPath(args.FirstOrDefault() ?? "artifacts"); Directory.CreateDirectory(output);
var results = new List<TestResult>();
void Test(string name, Action action)
{
    try { action(); results.Add(new(name, "PASS", "")); Console.WriteLine("PASS " + name); }
    catch (Exception e) { results.Add(new(name, "FAIL", e.ToString())); Console.WriteLine("FAIL " + name + " " + e.Message); }
}
void Equal<T>(T actual, T expected) { if (!EqualityComparer<T>.Default.Equals(actual, expected)) throw new Exception($"Expected {expected}; got {actual}"); }
void Reject(Action action) { try { action(); } catch (Exception e) when (e is BusinessException or CloudConflictException or CloudUnauthorizedException) { return; } throw new Exception("Expected rejection"); }
Test("cloud_owner_login", () => { using var f = new Fixture(); Equal(f.Cloud.Authenticate("OWNER", f.Password)?.Id, f.Owner.Id); });
Test("cloud_login_lockout", () => { using var f = new Fixture(); for (var i = 0; i < 5; i++) Equal(f.Cloud.Authenticate("owner", "incorrect"), null); Equal(f.Cloud.Authenticate("owner", f.Password), null); });
Test("pair_code_single_use", () => { using var f = new Fixture(false); var code = f.Cloud.CreatePairCode(f.Owner); f.Cloud.Pair(new(code, f.Business.Id, f.Business.DeviceId, "Equipo")); Reject(() => f.Cloud.Pair(new(code, f.Business.Id, f.Business.DeviceId, "Equipo"))); });
Test("pair_code_rotation_invalidates_old", () => { using var f = new Fixture(false); var first = f.Cloud.CreatePairCode(f.Owner); f.Cloud.CreatePairCode(f.Owner); Reject(() => f.Cloud.Pair(new(first, f.Business.Id, f.Business.DeviceId, "Equipo"))); });
Test("single_primary_cash_register", () => { using var f = new Fixture(); var code = f.Cloud.CreatePairCode(f.Owner); Reject(() => f.Cloud.Pair(new(code, f.Business.Id, Guid.NewGuid(), "Segunda caja"))); });
Test("cross_tenant_pair_device_denied", () => { using var f = new Fixture(); var other = f.Cloud.Provision(new("Otro", "other", "Other", f.Password)); var code = f.Cloud.CreatePairCode(other); Reject(() => f.Cloud.Pair(new(code, Guid.NewGuid(), f.Business.DeviceId, "Equipo ajeno"))); });
Test("revoked_device_cannot_authenticate", () => { using var f = new Fixture(); f.Cloud.Revoke(f.Owner, f.Business.DeviceId); Equal(f.Cloud.Device(f.Token), null); });
Test("device_token_rotation", () => { using var f = new Fixture(); var paired = f.Cloud.Pair(new(f.Cloud.CreatePairCode(f.Owner), f.Business.Id, f.Business.DeviceId, "Mismo equipo")); Equal(f.Cloud.Device(f.Token), null); if (f.Cloud.Device(paired.DeviceToken) is null) throw new Exception("New token invalid"); });
Test("sync_real_sale_visible_on_cloud", () => { using var f = new Fixture(); f.Sale(); f.Sync(); var dashboard = f.Dashboard(); Equal(dashboard.Metrics.Transactions, 1); Equal(dashboard.Metrics.GrossCents, 12100L); Equal(dashboard.Products.Single().StockMilli, 9000L); Equal(dashboard.CashSessions.Single().ExpectedCents, 12100L); });
Test("sync_replayed_batch_idempotent", () => { using var f = new Fixture(); f.Sale(); var events = f.Local.PendingEvents(200).ToArray(); var batch = new EventBatch(f.Business.Id, f.Business.DeviceId, events); f.Cloud.Accept(f.Device, batch); f.Cloud.Accept(f.Device, batch); Equal(f.Dashboard().Metrics.Transactions, 1); });
Test("cross_tenant_dashboard_empty", () => { using var f = new Fixture(); f.Sale(); f.Sync(); var other = f.Cloud.Provision(new("Other", "other", "Other", f.Password)); var dashboard = f.Cloud.Dashboard(other, DateTimeOffset.UtcNow.AddDays(-1), DateTimeOffset.UtcNow.AddDays(1)); Equal(dashboard.RecentSales.Length, 0); Equal(dashboard.Products.Length, 0); Equal(dashboard.Devices.Length, 0); });
Test("cross_device_batch_binding", () => { using var f = new Fixture(); Reject(() => f.Cloud.Accept(f.Device, new(f.Business.Id, Guid.NewGuid(), []))); });
Test("payload_hash_rejected", () => { using var f = new Fixture(); var events = f.Local.PendingEvents(200).ToArray(); events[0] = events[0] with { PayloadHash = "invalid" }; Reject(() => f.Cloud.Accept(f.Device, new(f.Business.Id, f.Business.DeviceId, events))); Equal(f.Dashboard().Products.Length, 0); });
Test("remote_price_roundtrip", () => { using var f = new Fixture(); f.Sync(); var p = f.Dashboard().Products.Single(); var command = f.Price(p, 15000); var requested = f.Cloud.Enqueue(f.Owner, command); var received = f.Cloud.Pending(f.Device).Single(); var applied = new RemoteExecutor(f.Local).ExecuteSafely(received); f.Cloud.Acknowledge(f.Device, new(applied.Id, applied.Status, applied.Result)); f.Sync(); Equal(f.Dashboard().Products.Single().PriceCents, 15000L); Equal(f.Dashboard().Commands.Single().Status, RemoteStatus.Completed); });
Test("remote_command_duplicate_creation", () => { using var f = new Fixture(); f.Sync(); var command = f.Price(f.Dashboard().Products.Single(), 15000); var first = f.Cloud.Enqueue(f.Owner, command); var second = f.Cloud.Enqueue(f.Owner, command); Equal(first.Id, second.Id); Equal(f.Dashboard().Commands.Length, 1); });
Test("remote_command_id_reused_payload_denied", () => { using var f = new Fixture(); f.Sync(); var p = f.Dashboard().Products.Single(); var command = f.Price(p, 15000); f.Cloud.Enqueue(f.Owner, command); Reject(() => f.Cloud.Enqueue(f.Owner, f.Price(p, 16000) with { Id = command.Id })); });
Test("remote_cross_tenant_device_denied", () => { using var f = new Fixture(); f.Sync(); var other = f.Cloud.Provision(new("Other", "other", "Other", f.Password)); Reject(() => f.Cloud.Enqueue(other, f.Price(f.Dashboard().Products.Single(), 15000))); });
Test("remote_stale_projection_price_denied", () => { using var f = new Fixture(); f.Sync(); var p = f.Dashboard().Products.Single(); Reject(() => f.Cloud.Enqueue(f.Owner, f.Price(p with { Version = 99 }, 15000))); });
Test("remote_unknown_command_denied", () => { using var f = new Fixture(); Reject(() => f.Cloud.Enqueue(f.Owner, new(Guid.NewGuid(), f.Business.DeviceId, "RUN_SHELL", JsonDocument.Parse("{}").RootElement))); });
Test("remote_terminal_ack_immutable", () => { using var f = new Fixture(); f.Sync(); var command = f.Cloud.Enqueue(f.Owner, f.Price(f.Dashboard().Products.Single(), 15000)); f.Cloud.Acknowledge(f.Device, new(command.Id, RemoteStatus.Completed, "Aplicado")); Reject(() => f.Cloud.Acknowledge(f.Device, new(command.Id, RemoteStatus.Rejected, "Otro resultado"))); });
Test("remote_delivered_until_ack", () => { using var f = new Fixture(); f.Sync(); f.Cloud.Enqueue(f.Owner, f.Price(f.Dashboard().Products.Single(), 15000)); var first = f.Cloud.Pending(f.Device).Single(); Equal(f.Cloud.Pending(f.Device).Single().Id, first.Id); Equal(first.Status, RemoteStatus.Received); });
Test("cloud_refund_metrics_reconcile", () => { using var f = new Fixture(); var sale = f.Sale(); f.Pos.RefundSale(f.User, Guid.NewGuid(), sale.Id, "Prueba"); f.Sync(); Equal(f.Dashboard().Metrics.NetSalesCents, 0L); Equal(f.Dashboard().Metrics.EstimatedMarginCents, 0L); });
File.WriteAllText(Path.Combine(output, "cloud-test-results.json"), System.Text.Json.JsonSerializer.Serialize(new { total = results.Count, passed = results.Count(x => x.Status == "PASS"), failed = results.Count(x => x.Status == "FAIL"), results }, new JsonSerializerOptions { WriteIndented = true }));
Console.WriteLine($"TOTAL {results.Count}: {results.Count(x => x.Status == "PASS")} PASS"); return results.Any(x => x.Status == "FAIL") ? 1 : 0;
sealed record TestResult(string Name, string Status, string Detail);
sealed class Fixture : IDisposable
{
    private readonly string directory = Path.Combine(Path.GetTempPath(), "CajaClaraCloudTests", Guid.NewGuid().ToString("N"));
    public string Password { get; } = Convert.ToHexString(RandomNumberGenerator.GetBytes(20));
    public CloudStore Cloud { get; }
    public CloudOwner Owner { get; }
    public Store Local { get; }
    public PosService Pos { get; }
    public Actor User { get; }
    public Business Business { get; }
    public Product Product { get; }
    public string Token { get; } = "";
    public CloudDevice Device => Cloud.Device(Token) ?? throw new Exception("No device");
    public Fixture(bool pair = true)
    {
        Directory.CreateDirectory(directory); Cloud = new(Path.Combine(directory, "cloud.sqlite")); Owner = Cloud.Provision(new("Comercio", "owner", "Dueño", Password));
        Local = new(Path.Combine(directory, "local.sqlite")); Pos = new(Local); User = new AuthService(Local).Bootstrap("Comercio", "Dueño local", "owner", Password, true);
        Business = Pos.Snapshot(User).Business!; Product = Pos.SaveProduct(User, new(Guid.NewGuid(), 1, "P1", "", "Producto", "Prueba", 6000, 12100, 2100, 10000, 1000, "un", true), 0);
        if (pair) Token = Cloud.Pair(new(Cloud.CreatePairCode(Owner), Business.Id, Business.DeviceId, "PC prueba")).DeviceToken;
    }
    public Sale Sale()
    {
        if (Pos.Snapshot(User).Cash is null) Pos.OpenRegister(User, 0);
        var p = Pos.Snapshot(User).Products.Single(); return Pos.Checkout(User, new(Guid.NewGuid(), null, [new(p.Id, p.Version, 1000)], [new(PaymentMethod.Cash, p.PriceCents, p.PriceCents, "")], "Test"));
    }
    public void Sync() { var events = Local.PendingEvents(200).ToArray(); var accepted = Cloud.Accept(Device, new(Business.Id, Business.DeviceId, events)); Local.Acknowledge(accepted.Accepted); }
    public OwnerDashboard Dashboard() => Cloud.Dashboard(Owner, DateTimeOffset.UtcNow.AddDays(-1), DateTimeOffset.UtcNow.AddDays(1));
    public CreateCommand Price(Product p, long value) => new(Guid.NewGuid(), Business.DeviceId, "UPDATE_PRODUCT_PRICE", JsonDocument.Parse(Json.Write(new PriceCommand(p.Id, p.Version, value))).RootElement.Clone());
    public void Dispose() { Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools(); try { Directory.Delete(directory, true); } catch (IOException) { } }
}
