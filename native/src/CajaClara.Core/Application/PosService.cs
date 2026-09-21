namespace CajaClara.Core;

public sealed class PosService(Store store)
{
    private static readonly Role[] Operators = [Role.Owner, Role.Admin, Role.Cashier];
    private static readonly Role[] Managers = [Role.Owner, Role.Admin];
    private static Business BusinessOf(DbTx tx) => tx.All<Business>().SingleOrDefault()
        ?? throw new BusinessException("Configurá el comercio antes de operar.");
    private static CashSession OpenCash(DbTx tx, Business business) => tx.All<CashSession>()
        .SingleOrDefault(x => x.DeviceId == business.DeviceId && x.State != CashState.Closed)
        ?? throw new BusinessException("Primero abrí la caja.");
    public bool NeedsSetup => store.Read(tx => tx.All<Business>().Length == 0);
    public Snapshot Snapshot(Actor actor) => store.Read(tx =>
    {
        AuthService.Require(tx, actor);
        var business = BusinessOf(tx);
        return new Snapshot(business, tx.All<Product>(),
            tx.All<CashSession>().SingleOrDefault(x => x.DeviceId == business.DeviceId && x.State != CashState.Closed),
            tx.All<Sale>(), tx.All<Contact>(), tx.All<Notification>(), tx.All<FiscalDocument>(),
            Convert.ToInt32(tx.Scalar("SELECT COUNT(*) FROM outbox WHERE sent_at IS NULL")), "ok");
    });
    public Business Configure(Actor actor, string name, string taxId, string address, string condition) => store.Write(tx =>
    {
        var user = AuthService.Require(tx, actor, Managers); var old = BusinessOf(tx);
        if (string.IsNullOrWhiteSpace(name) || name.Length > 160 || address.Length > 240 || condition.Length > 100)
            throw new BusinessException("Datos del comercio inválidos.");
        taxId = new string(taxId.Where(char.IsAsciiDigit).ToArray());
        if (taxId.Length != 0 && !ValidCuit(taxId)) throw new BusinessException("CUIT inválida.");
        var next = old with { Version = old.Version + 1, Name = name.Trim(), TaxId = taxId, Address = address.Trim(), TaxCondition = condition.Trim() };
        tx.Put(next, old.Version); tx.Audit(user, old.DeviceId, "BUSINESS_UPDATED", old.Id, old, next); return next;
    });
    public static bool ValidCuit(string cuit)
    {
        if (cuit.Length != 11 || cuit.Any(c => !char.IsAsciiDigit(c))) return false;
        int[] weights = [5,4,3,2,7,6,5,4,3,2];
        var check = 11 - Enumerable.Range(0,10).Sum(i => (cuit[i]-'0')*weights[i]) % 11;
        if (check == 11) check = 0; if (check == 10) check = 9;
        return check == cuit[10] - '0';
    }
    public Product SaveProduct(Actor actor, Product product, long expectedVersion) => store.Write(tx =>
    {
        var user = AuthService.Require(tx, actor, Managers); var business = BusinessOf(tx);
        if (string.IsNullOrWhiteSpace(product.Name) || product.Name.Length > 160 || string.IsNullOrWhiteSpace(product.Code) || product.Code.Length > 40 || product.Barcode.Length > 64 || product.Category.Length > 80)
            throw new BusinessException("Revisá nombre, código y categoría del producto.");
        Money.Valid(product.PriceCents, false); Money.Valid(product.CostCents);
        if (product.StockMilli < 0 || product.StockMilli > 1_000_000_000 || product.MinStockMilli < 0 || product.MinStockMilli > 1_000_000_000)
            throw new BusinessException("Stock fuera de rango.");
        if (product.Unit is not ("un" or "kg" or "l" or "m")) throw new BusinessException("Unidad no admitida.");
        if (product.Unit == "un" && (product.StockMilli % 1000 != 0 || product.MinStockMilli % 1000 != 0))
            throw new BusinessException("El stock por unidad debe ser entero.");
        if (product.VatBasisPoints is not (0 or 250 or 500 or 1050 or 2100 or 2700))
            throw new BusinessException("Alícuota no admitida.");
        var old = tx.Get<Product>(product.Id);
        if ((old?.Version ?? 0) != expectedVersion) throw new BusinessException("El producto cambió; actualizá los datos.");
        if (old is not null && old.StockMilli != product.StockMilli)
            throw new BusinessException("El stock se modifica con un movimiento, no editando el producto.");
        if (old is not null && old.Unit != product.Unit && old.StockMilli != 0)
            throw new BusinessException("No se puede cambiar la unidad mientras exista stock.");
        var next = product with { Version = expectedVersion + 1, Name = product.Name.Trim(), Code = product.Code.Trim().ToUpperInvariant(), Barcode = product.Barcode.Trim(), Category = product.Category.Trim() };
        tx.Put(next, expectedVersion);
        if (old is null && next.StockMilli > 0)
            tx.Put(new StockMovement(Guid.NewGuid(), 1, next.Id, user.Id, 0, next.StockMilli, next.StockMilli, "INITIAL", "Stock inicial", null, tx.Now), 0);
        tx.Audit(user, business.DeviceId, "PRODUCT_SAVED", next.Id, old, next); return next;
    });
    public Product AdjustStock(Actor actor, StockAdjustment adjustment) => store.Write(tx =>
    {
        var user = AuthService.Require(tx, actor, Managers); var business = BusinessOf(tx);
        var old = tx.Required<Product>(adjustment.ProductId);
        if (old.Version != adjustment.ProductVersion) throw new BusinessException("El producto cambió; actualizá y reintentá.");
        if (adjustment.DeltaMilli == 0 || string.IsNullOrWhiteSpace(adjustment.Reason) || adjustment.Reason.Length > 240)
            throw new BusinessException("Indicá cantidad y motivo del ajuste.");
        if (old.Unit == "un" && adjustment.DeltaMilli % 1000 != 0) throw new BusinessException("La cantidad debe ser entera.");
        var stock = checked(old.StockMilli + adjustment.DeltaMilli);
        if (stock < 0 || stock > 1_000_000_000) throw new BusinessException("El ajuste deja un stock inválido.");
        var next = old with { Version = old.Version + 1, StockMilli = stock };
        tx.Put(next, old.Version);
        tx.Put(new StockMovement(Guid.NewGuid(), 1, old.Id, user.Id, old.StockMilli, adjustment.DeltaMilli, stock,
            adjustment.DeltaMilli > 0 ? "MANUAL_IN" : "MANUAL_OUT", adjustment.Reason.Trim(), null, tx.Now), 0);
        tx.Audit(user, business.DeviceId, "STOCK_ADJUSTED", old.Id, old.StockMilli, stock); return next;
    });
    public Contact SaveContact(Actor actor, Contact contact, long expectedVersion) => store.Write(tx =>
    {
        var user = AuthService.Require(tx, actor, Operators); var business = BusinessOf(tx);
        if (string.IsNullOrWhiteSpace(contact.Name) || contact.Name.Length > 160 || contact.TaxId.Length > 30 || contact.Email.Length > 160 || contact.Phone.Length > 60 || contact.Address.Length > 240 || contact.TaxCondition < 1)
            throw new BusinessException("Datos de contacto inválidos.");
        var old = tx.Get<Contact>(contact.Id);
        var next = contact with { Version = expectedVersion + 1, Name = contact.Name.Trim() };
        tx.Put(next, expectedVersion); tx.Audit(user, business.DeviceId, "CONTACT_SAVED", next.Id, old, next); return next;
    });
    public CashSession OpenRegister(Actor actor, long openingCents, string notes = "") => store.Write(tx =>
    {
        var user = AuthService.Require(tx, actor, Operators); var business = BusinessOf(tx); Money.Valid(openingCents);
        if (tx.All<CashSession>().Any(x => x.DeviceId == business.DeviceId && x.State != CashState.Closed))
            throw new BusinessException("Ya hay una caja abierta.");
        if (notes.Length > 500) throw new BusinessException("Observación demasiado larga.");
        var cash = new CashSession(Guid.NewGuid(), 1, business.DeviceId, user.Id, tx.Now, null, openingCents, openingCents, null, CashState.Open, notes.Trim());
        tx.Put(cash, 0); tx.Audit(user, business.DeviceId, "CASH_OPENED", cash.Id, null, cash); return cash;
    });
    public CashSession CloseRegister(Actor actor, long countedCents, string notes) => store.Write(tx =>
    {
        var user = AuthService.Require(tx, actor, Operators); var business = BusinessOf(tx); var old = OpenCash(tx, business);
        Money.Valid(countedCents); if (notes.Length > 500) throw new BusinessException("Observación demasiado larga.");
        if (user.Role == Role.Cashier && user.Id != old.UserId) throw new BusinessException("Solo el responsable de turno o un administrador puede cerrar esta caja.");
        var closed = old with { Version = old.Version + 1, State = CashState.Closed, CountedCents = countedCents, ClosedAt = tx.Now, Notes = notes.Trim() };
        tx.Put(closed, old.Version); tx.Audit(user, business.DeviceId, "CASH_CLOSED", old.Id, old, closed); return closed;
    });
    private static CashSession CashDelta(DbTx tx, CashSession cash, Actor user, long delta, string kind, string reason, Guid? saleId)
    {
        var expected = checked(cash.ExpectedCents + delta);
        if (expected < 0 || expected > Money.MaxCents) throw new BusinessException("El movimiento deja un efectivo esperado inválido.");
        var next = cash with { Version = cash.Version + 1, ExpectedCents = expected };
        tx.Put(next, cash.Version);
        tx.Put(new CashMovement(Guid.NewGuid(), 1, cash.Id, user.Id, delta, kind, reason, saleId, tx.Now), 0); return next;
    }
    public CashSession RecordCashMovement(Actor actor, long amountCents, string kind, string reason) => store.Write(tx =>
    {
        var user = AuthService.Require(tx, actor, Operators); var business = BusinessOf(tx);
        if (kind is not ("INCOME" or "EXPENSE" or "WITHDRAWAL") || string.IsNullOrWhiteSpace(reason) || reason.Length > 240)
            throw new BusinessException("Indicá tipo y motivo del movimiento.");
        Money.Valid(amountCents, false);
        if (kind == "WITHDRAWAL" && user.Role == Role.Cashier) throw new BusinessException("El retiro requiere un administrador.");
        var cash = OpenCash(tx, business);
        var next = CashDelta(tx, cash, user, kind == "INCOME" ? amountCents : -amountCents, kind, reason.Trim(), null);
        tx.Audit(user, business.DeviceId, kind, cash.Id, cash.ExpectedCents, next.ExpectedCents); return next;
    });
    public Sale Checkout(Actor actor, CheckoutRequest request) => store.Write(tx =>
    {
        var user = AuthService.Require(tx, actor, Operators); var business = BusinessOf(tx);
        if (request.Id == Guid.Empty || request.Items.Length is < 1 or > 200 || request.Notes.Length > 1000)
            throw new BusinessException("La venta tiene datos inválidos.");
        var hash = Json.Hash(Json.Write(new { user.Id, request }));
        var previous = tx.Previous<Sale>(request.Id, hash); if (previous is not null) return previous;
        var cash = OpenCash(tx, business);
        if (request.Items.GroupBy(x => x.ProductId).Any(g => g.Count() > 1)) throw new BusinessException("Unificá las cantidades del mismo producto.");
        var lines = request.Items.Select(item => SaleMath.Line(tx.Required<Product>(item.ProductId), item, user.Role is Role.Owner or Role.Admin)).ToArray();
        var total = lines.Sum(x => x.TotalCents); SaleMath.ValidatePayments(total, request.Payments);
        Contact? customer = request.CustomerId is Guid id ? tx.Required<Contact>(id) : null;
        if (customer?.Supplier == true) throw new BusinessException("Seleccioná un cliente, no un proveedor.");
        var sale = new Sale(request.Id, 1, tx.NextNumber("sale"), cash.Id, business.DeviceId, user.Id, user.Name, customer,
            tx.Now, lines, request.Payments, total, 0, request.RequestInvoice ? FiscalState.Pending : FiscalState.NotIssued, request.Notes.Trim());
        foreach (var line in lines)
        {
            var product = tx.Required<Product>(line.ProductId); var stock = product.StockMilli - line.QuantityMilli;
            tx.Put(product with { Version = product.Version + 1, StockMilli = stock }, product.Version);
            tx.Put(new StockMovement(Guid.NewGuid(), 1, product.Id, user.Id, product.StockMilli, -line.QuantityMilli, stock, "SALE", $"Venta {sale.Number}", sale.Id, tx.Now), 0);
        }
        var cashApplied = request.Payments.Where(x => x.Method == PaymentMethod.Cash).Sum(x => x.AppliedCents);
        if (cashApplied > 0) CashDelta(tx, cash, user, cashApplied, "SALE", $"Venta {sale.Number}", sale.Id);
        tx.Put(sale, 0);
        if (request.RequestInvoice)
            tx.Put(new FiscalDocument(Guid.NewGuid(), 1, sale.Id, "HOMOLOGACION", 0, 0, null, FiscalState.Pending, null, null,
                "Pendiente de configuración y autorización fiscal. No constituye factura.", tx.Now), 0);
        tx.Audit(user, business.DeviceId, "SALE_CONFIRMED", sale.Id, null, new { sale.Number, sale.TotalCents, sale.ChangeCents });
        tx.Remember(request.Id, hash, sale); return sale;
    });
    public Refund RefundSale(Actor actor, Guid requestId, Guid saleId, string reason) => store.Write(tx =>
    {
        var user = AuthService.Require(tx, actor, Managers); var business = BusinessOf(tx);
        if (requestId == Guid.Empty || string.IsNullOrWhiteSpace(reason) || reason.Length > 240)
            throw new BusinessException("Indicá un motivo para la devolución.");
        var hash = Json.Hash(Json.Write(new { requestId, saleId, user.Id, reason }));
        var previous = tx.Previous<Refund>(requestId, hash); if (previous is not null) return previous;
        var sale = tx.Required<Sale>(saleId); var cash = OpenCash(tx, business);
        if (sale.RefundedCents != 0) throw new BusinessException("Esta venta ya tiene una devolución.");
        var cashAmount = sale.Payments.Where(x => x.Method == PaymentMethod.Cash).Sum(x => x.AppliedCents);
        if (cashAmount > 0) CashDelta(tx, cash, user, -cashAmount, "REFUND", reason.Trim(), saleId);
        foreach (var line in sale.Lines)
        {
            var product = tx.Required<Product>(line.ProductId); var nextStock = checked(product.StockMilli + line.QuantityMilli);
            if (nextStock > 1_000_000_000) throw new BusinessException("La devolución excede el stock permitido.");
            tx.Put(product with { Version = product.Version + 1, StockMilli = nextStock }, product.Version);
            tx.Put(new StockMovement(Guid.NewGuid(), 1, product.Id, user.Id, product.StockMilli, line.QuantityMilli, nextStock, "REFUND", reason.Trim(), saleId, tx.Now), 0);
        }
        var refund = new Refund(requestId, 1, sale.Id, cash.Id, user.Id, sale.TotalCents, reason.Trim(), tx.Now, sale.Payments);
        tx.Put(refund, 0); tx.Put(sale with { Version = sale.Version + 1, RefundedCents = sale.TotalCents }, sale.Version);
        if (sale.FiscalState != FiscalState.NotIssued)
            tx.Put(new Notification(Guid.NewGuid(), 1, "Devolución con tratamiento fiscal pendiente", $"Venta {sale.Number}: revisar comprobante y emitir nota de crédito cuando corresponda. El comprobante original no fue anulado.", tx.Now, false), 0);
        tx.Audit(user, business.DeviceId, "SALE_REFUNDED", saleId, new { sale.RefundedCents }, refund);
        tx.Remember(requestId, hash, refund); return refund;
    });
    public Purchase ReceivePurchase(Actor actor, Guid requestId, Guid supplierId, PurchaseLine[] lines, long paidFromCashCents, string reference) => store.Write(tx =>
    {
        var user = AuthService.Require(tx, actor, Managers); var business = BusinessOf(tx);
        var hash = Json.Hash(Json.Write(new { requestId, supplierId, lines, paidFromCashCents, reference, user.Id }));
        var previous = tx.Previous<Purchase>(requestId, hash); if (previous is not null) return previous;
        if (requestId == Guid.Empty || lines.Length is < 1 or > 200 || reference.Length > 160 || lines.GroupBy(x => x.ProductId).Any(x => x.Count() > 1))
            throw new BusinessException("Compra inválida.");
        if (!tx.Required<Contact>(supplierId).Supplier) throw new BusinessException("Seleccioná un proveedor.");
        long total = 0;
        foreach (var line in lines)
        {
            Money.Valid(line.UnitCostCents, false); var product = tx.Required<Product>(line.ProductId);
            if (line.QuantityMilli <= 0 || line.QuantityMilli > 1_000_000_000 || (product.Unit == "un" && line.QuantityMilli % 1000 != 0))
                throw new BusinessException("Cantidad de compra inválida.");
            var stock = checked(product.StockMilli + line.QuantityMilli);
            if (stock > 1_000_000_000) throw new BusinessException("Stock máximo excedido.");
            total = checked(total + Money.Extend(line.UnitCostCents, line.QuantityMilli));
            tx.Put(product with { Version = product.Version + 1, StockMilli = stock, CostCents = line.UnitCostCents, SupplierId = supplierId }, product.Version);
            tx.Put(new StockMovement(Guid.NewGuid(), 1, product.Id, user.Id, product.StockMilli, line.QuantityMilli, stock, "PURCHASE", reference, requestId, tx.Now), 0);
        }
        Money.Valid(total, false); Money.Valid(paidFromCashCents);
        if (paidFromCashCents > total) throw new BusinessException("El pago supera el total de la compra.");
        if (paidFromCashCents > 0) CashDelta(tx, OpenCash(tx, business), user, -paidFromCashCents, "PURCHASE", reference, null);
        var purchase = new Purchase(requestId, 1, supplierId, user.Id, tx.Now, lines, total, paidFromCashCents, reference.Trim());
        tx.Put(purchase, 0); tx.Audit(user, business.DeviceId, "PURCHASE_RECEIVED", purchase.Id, null, purchase);
        tx.Remember(requestId, hash, purchase); return purchase;
    });
    public void MarkNotificationRead(Actor actor, Guid id) => store.Write(tx =>
    {
        AuthService.Require(tx, actor); var old = tx.Required<Notification>(id);
        if (!old.Read) tx.Put(old with { Version = old.Version + 1, Read = true }, old.Version);
    });
    public T[] History<T>(Actor actor) where T : class, IEntity => store.Read(tx => { AuthService.Require(tx, actor, Managers); return tx.All<T>(); });
    public string Backup(Actor actor, string directory)
    { store.Read(tx => AuthService.Require(tx, actor, Managers)); return store.Backup(directory); }
}
