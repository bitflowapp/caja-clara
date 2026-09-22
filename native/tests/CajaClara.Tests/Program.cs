using CajaClara.Core;
using System.Security.Cryptography;
using System.Text.Json;

var results = new List<TestResult>();
var output = Path.GetFullPath(args.FirstOrDefault() ?? "artifacts"); Directory.CreateDirectory(output);
void Test(string name, Action test)
{
    var started = DateTime.UtcNow;
    try { test(); results.Add(new(name, "PASS", "", (DateTime.UtcNow - started).TotalMilliseconds)); Console.WriteLine("PASS " + name); }
    catch (Exception error) { results.Add(new(name, "FAIL", error.ToString(), (DateTime.UtcNow - started).TotalMilliseconds)); Console.WriteLine("FAIL " + name + " " + error.Message); }
}
void Equal<T>(T actual, T expected) { if (!EqualityComparer<T>.Default.Equals(actual, expected)) throw new Exception($"Expected {expected}; got {actual}"); }
void Reject(Action action) { try { action(); } catch (BusinessException) { return; } throw new Exception("Expected BusinessException"); }
Product Product(long stock = 20_000, long price = 12100) => new(Guid.NewGuid(), 1, Guid.NewGuid().ToString("N")[..12], "", "Producto de prueba", "Pruebas", 6000, price, 2100, stock, 2000, "un", true);
CheckoutRequest Request(Product p, long quantity = 1000, long? cash = null) => new(Guid.NewGuid(), null, [new(p.Id, p.Version, quantity)], [new Tender(PaymentMethod.Cash, Money.Extend(p.PriceCents, quantity), cash ?? Money.Extend(p.PriceCents, quantity), "")], "Prueba automatizada");
Test("money_exact_cents", () => Equal(Money.Cents(1234.56m), 123456L));
Test("money_reject_fractional_cent", () => Reject(() => Money.Cents(1.005m)));
Test("money_reject_negative", () => Reject(() => Money.Cents(-1)));
Test("money_quantity_precision", () => Equal(Money.Quantity(1.125m), 1125L));
Test("money_quantity_too_precise", () => Reject(() => Money.Quantity(.0001m)));
Test("money_round_half_away", () => Equal(Money.Extend(101, 500), 51L));
Test("vat_inclusive_reconciles", () => { var p = Product(); var line = SaleMath.Line(p, new(p.Id, 1, 1000), true); Equal(line.NetCents, 10000L); Equal(line.VatCents, 2100L); Equal(line.NetCents + line.VatCents, line.TotalCents); });
Test("discount_permission_enforced", () => { var p = Product(); Reject(() => SaleMath.Line(p, new(p.Id, 1, 1000, 100), false)); });
Test("discount_100_percent_rejected", () => { var p = Product(); Reject(() => SaleMath.Line(p, new(p.Id, 1, 1000, p.PriceCents), true)); });
Test("fractional_unit_rejected", () => { var p = Product(); Reject(() => SaleMath.Line(p, new(p.Id, 1, 500), true)); });
Test("stale_price_rejected", () => { var p = Product(); Reject(() => SaleMath.Line(p, new(p.Id, 2, 1000), true)); });
Test("inactive_product_rejected", () => { var p = Product() with { Active = false }; Reject(() => SaleMath.Line(p, new(p.Id, 1, 1000), true)); });
Test("oversell_rejected", () => { var p = Product(1000); Reject(() => SaleMath.Line(p, new(p.Id, 1, 2000), true)); });
Test("mixed_payments_reconcile", () => Equal(SaleMath.ValidatePayments(100_000, [new(PaymentMethod.Cash, 40000, 50000, ""), new(PaymentMethod.Transfer, 60000, 60000, "REF-1")]), 10000L));
Test("payment_underpaid_rejected", () => Reject(() => SaleMath.ValidatePayments(100, [new(PaymentMethod.Cash, 99, 100, "")])));
Test("electronic_reference_required", () => Reject(() => SaleMath.ValidatePayments(100, [new(PaymentMethod.Credit, 100, 100, "")])));
Test("electronic_never_automatically_verified", () => Equal(new Tender(PaymentMethod.Transfer, 100, 100, "x").Verification, "MANUAL_UNVERIFIED"));
Test("password_salted", () => { var password = "test-" + Guid.NewGuid(); var first = Passwords.Hash(password); var second = Passwords.Hash(password); if (first == second) throw new Exception("Salt reused"); Equal(Passwords.Verify(password, first), true); Equal(Passwords.Verify("incorrect", first), false); });
Test("bootstrap_once", () => { using var f = new Fixture(); Reject(() => f.Auth.Bootstrap("Duplicado", "Dueño", "otro", f.Password)); });
Test("login_roundtrip", () => { using var f = new Fixture(); Equal(f.Auth.Authenticate("owner", f.Password).Id, f.Owner.Id); });
Test("login_lockout_persists", () => { using var f = new Fixture(); for (var i = 0; i < 5; i++) Reject(() => f.Auth.Authenticate("owner", "incorrecta")); Reject(() => new AuthService(new Store(f.Path)).Authenticate("owner", f.Password)); });
Test("pin_lockout", () => { using var f = new Fixture(); f.Auth.SetPin(f.Owner, "684291"); Equal(f.Auth.Unlock(f.Owner, "684291"), true); for (var i = 0; i < 5; i++) Equal(f.Auth.Unlock(f.Owner, "000000"), false); Equal(f.Auth.Unlock(f.Owner, "684291"), false); });
Test("role_cannot_be_forged", () => { using var f = new Fixture(); var cashier = f.Auth.AddUser(f.Owner, "cashier", "Caja", Role.Cashier, f.Password); Reject(() => f.Pos.SaveProduct(new(cashier.Id, "Fake", Role.Owner), Product(), 0)); });
Test("user_revocation_enforced", () => { using var f = new Fixture(); var user = f.Auth.AddUser(f.Owner, "viewer", "Consulta", Role.Viewer, f.Password); f.Auth.SetActive(f.Owner, user.Id, false); Reject(() => f.Pos.Snapshot(new(user.Id, user.Name, user.Role))); });
Test("owner_cannot_disable_self", () => { using var f = new Fixture(); Reject(() => f.Auth.SetActive(f.Owner, f.Owner.Id, false)); });
Test("product_initial_stock_ledger", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); Equal(f.Pos.History<StockMovement>(f.Owner).Single().AfterMilli, p.StockMilli); });
Test("duplicate_code_rejected", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); Reject(() => f.Pos.SaveProduct(f.Owner, Product() with { Code = p.Code.ToLowerInvariant() }, 0)); });
Test("stock_edit_without_movement_rejected", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); Reject(() => f.Pos.SaveProduct(f.Owner, p with { Version = 2, StockMilli = 1000 }, 1)); });
Test("stock_adjustment_audited", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); var next = f.Pos.AdjustStock(f.Owner, new(p.Id, p.Version, -1000, "Merma")); Equal(next.StockMilli, 19000L); Equal(f.Pos.History<StockMovement>(f.Owner).Length, 2); });
Test("duplicate_cash_open_rejected", () => { using var f = new Fixture(); f.Pos.OpenRegister(f.Owner, 10000); Reject(() => f.Pos.OpenRegister(f.Owner, 0)); });
Test("cash_close_difference", () => { using var f = new Fixture(); f.Pos.OpenRegister(f.Owner, 10000); var closed = f.Pos.CloseRegister(f.Owner, 9000, "Diferencia de conteo"); Equal(closed.DifferenceCents, (long?)-1000); Equal(closed.State, CashState.Closed); });
Test("cash_negative_prevented", () => { using var f = new Fixture(); f.Pos.OpenRegister(f.Owner, 10000); Reject(() => f.Pos.RecordCashMovement(f.Owner, 10001, "EXPENSE", "Gasto")); Equal(f.Pos.Snapshot(f.Owner).Cash?.ExpectedCents, (long?)10000); });
Test("sale_requires_open_cash", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); Reject(() => f.Pos.Checkout(f.Owner, Request(p))); });
Test("sale_stock_cash_atomic", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); f.Pos.OpenRegister(f.Owner, 10000); var sale = f.Pos.Checkout(f.Owner, Request(p, cash: 15000)); var state = f.Pos.Snapshot(f.Owner); Equal(state.Products.Single().StockMilli, 19000L); Equal(state.Cash?.ExpectedCents, (long?)22100); Equal(sale.ChangeCents, 2900L); Equal(state.Sales.Length, 1); });
Test("sale_retry_idempotent_after_close", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); f.Pos.OpenRegister(f.Owner, 0); var request = Request(p); var first = f.Pos.Checkout(f.Owner, request); f.Pos.CloseRegister(f.Owner, first.TotalCents, ""); var second = f.Pos.Checkout(f.Owner, request); Equal(first.Id, second.Id); Equal(f.Pos.Snapshot(f.Owner).Sales.Length, 1); });
Test("idempotency_payload_change_rejected", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); f.Pos.OpenRegister(f.Owner, 0); var request = Request(p); f.Pos.Checkout(f.Owner, request); Reject(() => f.Pos.Checkout(f.Owner, request with { Notes = "Changed" })); });
Test("failed_payment_rolls_back_stock", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); f.Pos.OpenRegister(f.Owner, 0); var before = f.Store.PendingEvents(200).Count; Reject(() => f.Pos.Checkout(f.Owner, Request(p) with { Payments = [new(PaymentMethod.Cash, 1, 1, "")] })); Equal(f.Pos.Snapshot(f.Owner).Products.Single().StockMilli, 20000L); Equal(f.Pos.Snapshot(f.Owner).Sales.Length, 0); Equal(f.Store.PendingEvents(200).Count, before); });
Test("reopen_database_preserves_sale", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); f.Pos.OpenRegister(f.Owner, 0); f.Pos.Checkout(f.Owner, Request(p)); var reloaded = new PosService(new Store(f.Path)).Snapshot(f.Owner); Equal(reloaded.Sales.Length, 1); Equal(reloaded.Products.Single().StockMilli, 19000L); });
Test("fiscal_pending_never_has_cae", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); f.Pos.OpenRegister(f.Owner, 0); f.Pos.Checkout(f.Owner, Request(p) with { RequestInvoice = true }); var invoice = f.Pos.Snapshot(f.Owner).Invoices.Single(); Equal(invoice.State, FiscalState.Pending); Equal(invoice.Cae, null); Equal(invoice.VoucherNumber, null); });
Test("refund_compensates_once", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); f.Pos.OpenRegister(f.Owner, 0); var sale = f.Pos.Checkout(f.Owner, Request(p)); var id = Guid.NewGuid(); f.Pos.RefundSale(f.Owner, id, sale.Id, "Devolución"); f.Pos.RefundSale(f.Owner, id, sale.Id, "Devolución"); Equal(f.Pos.Snapshot(f.Owner).Products.Single().StockMilli, 20000L); Equal(f.Pos.Snapshot(f.Owner).Cash?.ExpectedCents, (long?)0); Equal(f.Pos.History<Refund>(f.Owner).Length, 1); Reject(() => f.Pos.RefundSale(f.Owner, Guid.NewGuid(), sale.Id, "Otra")); });
Test("purchase_updates_cost_stock_cash", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); var supplier = f.Pos.SaveContact(f.Owner, new(Guid.NewGuid(), 1, "Proveedor", "", "", "", "", true), 0); f.Pos.OpenRegister(f.Owner, 100000); var purchase = f.Pos.ReceivePurchase(f.Owner, Guid.NewGuid(), supplier.Id, [new(p.Id, 2000, 5000)], 10000, "COMPRA-1"); Equal(purchase.TotalCents, 10000L); var state = f.Pos.Snapshot(f.Owner); Equal(state.Products.Single().StockMilli, 22000L); Equal(state.Products.Single().CostCents, 5000L); Equal(state.Cash?.ExpectedCents, (long?)90000); });
Test("outbox_ack_exact_events", () => { using var f = new Fixture(); var pending = f.Store.PendingEvents().ToArray(); f.Store.Acknowledge([pending[0].EventId]); Equal(f.Store.PendingEvents().Count, pending.Length - 1); });
Test("remote_price_applied_once", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); var command = f.Command("UPDATE_PRODUCT_PRICE", Json.Write(new PriceCommand(p.Id, p.Version, 15000))); var executor = new RemoteExecutor(f.Store); Equal(executor.ExecuteSafely(command).Status, RemoteStatus.Completed); Equal(executor.ExecuteSafely(command).Status, RemoteStatus.Completed); Equal(f.Pos.Snapshot(f.Owner).Products.Single().Version, 2L); });
Test("remote_wrong_device_rejected", () => { using var f = new Fixture(); var command = f.Command("REQUEST_SYNC", "{}") with { TargetDeviceId = Guid.NewGuid() }; Equal(new RemoteExecutor(f.Store).ExecuteSafely(command).Status, RemoteStatus.Rejected); });
Test("remote_expired_not_executed", () => { using var f = new Fixture(); var command = f.Command("REQUEST_SYNC", "{}") with { RequestedAt = DateTimeOffset.UtcNow.AddHours(-1), ExpiresAt = DateTimeOffset.UtcNow.AddMinutes(-1) }; Equal(new RemoteExecutor(f.Store).ExecuteSafely(command).Status, RemoteStatus.Expired); });
Test("remote_arbitrary_command_rejected", () => { using var f = new Fixture(); Equal(new RemoteExecutor(f.Store).ExecuteSafely(f.Command("RUN_SHELL", "{}" )).Status, RemoteStatus.Rejected); });
Test("remote_stale_command_rejected", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); var command = f.Command("UPDATE_PRODUCT_PRICE", Json.Write(new PriceCommand(p.Id, 99, 15000))); Equal(new RemoteExecutor(f.Store).ExecuteSafely(command).Status, RemoteStatus.Rejected); Equal(f.Pos.Snapshot(f.Owner).Products.Single().PriceCents, 12100L); });
Test("remote_closing_does_not_close_cash", () => { using var f = new Fixture(); f.Pos.OpenRegister(f.Owner, 0); Equal(new RemoteExecutor(f.Store).ExecuteSafely(f.Command("REQUEST_CASH_CLOSING", "{}" )).Status, RemoteStatus.Completed); Equal(f.Pos.Snapshot(f.Owner).Cash?.State, CashState.ClosingRequested); });
Test("mp_intent_reserves_stock_before_provider", () =>
{
    using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); f.Pos.OpenRegister(f.Owner, 0);
    var id = Guid.NewGuid(); var request = new CheckoutRequest(id, null, [new(p.Id, p.Version, 1000)], [], "QR", false);
    var intent = f.Pos.BeginMercadoPagoIntent(f.Owner, request);
    Equal(intent.AmountCents, 12100L); Equal(f.Pos.Snapshot(f.Owner).Products.Single().StockMilli, 19000L);
    Equal(f.Pos.History<StockMovement>(f.Owner).Count(x => x.Kind == "PAYMENT_RESERVE"), 1);
});
Test("mp_cancel_releases_reserved_stock_once", () =>
{
    using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); f.Pos.OpenRegister(f.Owner, 0);
    var id = Guid.NewGuid(); var request = new CheckoutRequest(id, null, [new(p.Id, p.Version, 1000)], [], "QR", false);
    var intent = f.Pos.BeginMercadoPagoIntent(f.Owner, request);
    var canceled = f.Pos.CancelMercadoPagoIntent(f.Owner, intent.Id, "Order cancelada sin pago");
    Equal(canceled.StockReleased, true); Equal(f.Pos.Snapshot(f.Owner).Products.Single().StockMilli, 20000L);
    Equal(f.Pos.CancelMercadoPagoIntent(f.Owner, intent.Id, "Segundo intento").Version, canceled.Version);
});
Test("mp_paid_intent_finalizes_snapshot_without_double_stock", () =>
{
    using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); f.Pos.OpenRegister(f.Owner, 0);
    var id = Guid.NewGuid(); var request = new CheckoutRequest(id, null, [new(p.Id, p.Version, 1000)], [], "QR", true);
    var intent = f.Pos.BeginMercadoPagoIntent(f.Owner, request);
    intent = f.Pos.UpdateMercadoPagoIntent(f.Owner, intent.Id, intent.Version, "ORDER-123", "processed", true, "accredited", "qr");
    var sale = f.Pos.FinalizeMercadoPagoSale(f.Owner, intent.Id);
    Equal(sale.Id, id); Equal(sale.TotalCents, 12100L); Equal(sale.Payments.Single().Method, PaymentMethod.MercadoPagoQr);
    Equal(sale.Payments.Single().Verification, "PROVIDER_CONFIRMED");
    Equal(f.Pos.Snapshot(f.Owner).Products.Single().StockMilli, 19000L);
    Equal(f.Pos.Snapshot(f.Owner).Invoices.Single().SaleId, sale.Id);
    Equal(f.Pos.FinalizeMercadoPagoSale(f.Owner, intent.Id).Number, sale.Number);
});
Test("mp_retry_rejects_changed_checkout_snapshot", () =>
{
    using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); f.Pos.OpenRegister(f.Owner, 0);
    var id = Guid.NewGuid(); var request = new CheckoutRequest(id, null, [new(p.Id, p.Version, 1000)], [], "original", false);
    f.Pos.BeginMercadoPagoIntent(f.Owner, request);
    Reject(() => f.Pos.BeginMercadoPagoIntent(f.Owner, request with { Notes = "cambiado" }));
});
Test("backup_integrity_and_manifest", () => { using var f = new Fixture(); var backup = f.Store.Backup(Path.Combine(f.Directory, "backup")); var manifest = Store.ValidateBackup(backup); Equal(manifest.BusinessId, f.Pos.Snapshot(f.Owner).Business?.Id); });
Test("tampered_backup_rejected", () => { using var f = new Fixture(); var backup = f.Store.Backup(Path.Combine(f.Directory, "backup")); File.AppendAllText(backup, "changed"); Reject(() => Store.ValidateBackup(backup)); });
Test("pdf_is_real_and_non_fiscal", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); f.Pos.OpenRegister(f.Owner, 0); var sale = f.Pos.Checkout(f.Owner, Request(p)); var lines = Receipt.Lines(f.Pos.Snapshot(f.Owner).Business!, sale); if (!lines.Any(x => x.Contains("NO FISCAL"))) throw new Exception("Missing disclaimer"); var path = Path.Combine(output, "test-receipt.pdf"); Receipt.Pdf(path, lines); Equal(System.Text.Encoding.ASCII.GetString(File.ReadAllBytes(path)[..8]), "%PDF-1.4"); });
Test("xlsx_export_roundtrip", () => { using var f = new Fixture(); f.Pos.SaveProduct(f.Owner, Product() with { Barcode = "00001234" }, 0); var reports = new Reports(f.Store); var path = Path.Combine(output, "test-products.xlsx"); reports.ExportProducts(f.Owner, path); using var target = new Fixture(); var imported = new Reports(target.Store); var preview = imported.PreviewProducts(target.Owner, path); Equal(preview.Valid, 1); Equal(preview.Errors, 0); imported.ImportProducts(target.Owner, preview); Equal(target.Pos.Snapshot(target.Owner).Products.Single().Barcode, "00001234"); });
Test("report_refund_on_refund_date", () => { using var f = new Fixture(); var p = f.Pos.SaveProduct(f.Owner, Product(), 0); f.Pos.OpenRegister(f.Owner, 0); var sale = f.Pos.Checkout(f.Owner, Request(p)); f.Pos.RefundSale(f.Owner, Guid.NewGuid(), sale.Id, "Test"); var report = new Reports(f.Store).Sales(f.Owner, DateTimeOffset.UtcNow.AddDays(-1), DateTimeOffset.UtcNow.AddDays(1)); Equal(report.NetSalesCents, 0L); Equal(report.EstimatedMarginCents, 0L); });
Test("https_enforced_for_remote", () => Reject(() => SyncClient.ValidateServer(new Uri("http://example.com/"), true)));
Test("sqlite_integrity", () => { using var f = new Fixture(); Equal(f.Store.Integrity(), "ok"); });
File.WriteAllText(Path.Combine(output, "test-results.json"), System.Text.Json.JsonSerializer.Serialize(new { total = results.Count, passed = results.Count(x => x.Status == "PASS"), failed = results.Count(x => x.Status == "FAIL"), results }, new JsonSerializerOptions { WriteIndented = true }));
Console.WriteLine($"TOTAL {results.Count}: {results.Count(x => x.Status == "PASS")} PASS; {results.Count(x => x.Status == "FAIL")} FAIL");
return results.Any(x => x.Status == "FAIL") ? 1 : 0;

sealed record TestResult(string Name, string Status, string Detail, double Milliseconds);
sealed class Fixture : IDisposable
{
    public string Directory { get; } = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "CajaClaraTests", Guid.NewGuid().ToString("N"));
    public string Path => System.IO.Path.Combine(Directory, "test.sqlite");
    public string Password { get; } = Convert.ToHexString(RandomNumberGenerator.GetBytes(20));
    public Store Store { get; }
    public AuthService Auth { get; }
    public PosService Pos { get; }
    public Actor Owner { get; }
    public Fixture() { Store = new(Path); Auth = new(Store); Pos = new(Store); Owner = Auth.Bootstrap("Comercio de prueba", "Dueño", "owner", Password, true); }
    public RemoteCommand Command(string type, string payload)
    {
        var b = Pos.Snapshot(Owner).Business ?? throw new Exception("No business"); var now = DateTimeOffset.UtcNow;
        return new(Guid.NewGuid(), b.Id, b.DeviceId, type, payload, "owner-test", now, now.AddMinutes(10), RemoteStatus.Pending);
    }
    public void Dispose()
    {
        Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools();
        try { System.IO.Directory.Delete(Directory, true); } catch (IOException) { }
    }
}
