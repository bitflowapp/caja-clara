using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace CajaClara.Core;

public interface IEntity { Guid Id { get; } long Version { get; } }
public enum Role { Owner, Admin, Cashier, Employee, Viewer }
public enum PaymentMethod { Cash, Transfer, Debit, Credit, MercadoPagoManual }
public enum FiscalState { NotIssued, Pending, Authorized, Rejected, Unknown }
public enum CashState { Open, ClosingRequested, Closed }
public enum RemoteStatus { Pending, Received, Executing, Completed, Failed, Expired, Rejected }
public sealed record Actor(Guid Id, string Name, Role Role);
public sealed record Business(Guid Id, long Version, string Name, string TaxId, string Address,
    string TaxCondition, Guid DeviceId, bool Demo) : IEntity;
public sealed record Product(Guid Id, long Version, string Code, string Barcode, string Name,
    string Category, long CostCents, long PriceCents, int VatBasisPoints, long StockMilli,
    long MinStockMilli, string Unit, bool Active, Guid? SupplierId = null) : IEntity
{
    public string PriceText => Money.Format(PriceCents);
    public string CostText => Money.Format(CostCents);
    public string StockText => (StockMilli / 1000m).ToString("0.###", Money.Culture) + " " + Unit;
    public string Display => $"{Code} · {Name}   {PriceText}   Stock: {StockText}";
    public bool LowStock => Active && StockMilli <= MinStockMilli;
}
public sealed record Contact(Guid Id, long Version, string Name, string TaxId, string Phone,
    string Email, string Address, bool Supplier, int TaxCondition = 5) : IEntity
{ public string Display => $"{Name} · {TaxId} · {Phone}"; }
public sealed record CashSession(Guid Id, long Version, Guid DeviceId, Guid UserId,
    DateTimeOffset OpenedAt, DateTimeOffset? ClosedAt, long OpeningCents, long ExpectedCents,
    long? CountedCents, CashState State, string Notes) : IEntity
{
    public long? DifferenceCents => CountedCents - ExpectedCents;
    public string Display => $"{OpenedAt.ToLocalTime():dd/MM HH:mm} · {State} · {Money.Format(ExpectedCents)}";
}
public sealed record CashMovement(Guid Id, long Version, Guid SessionId, Guid UserId,
    long AmountCents, string Kind, string Reason, Guid? SaleId, DateTimeOffset At) : IEntity;
public sealed record StockMovement(Guid Id, long Version, Guid ProductId, Guid UserId,
    long BeforeMilli, long DeltaMilli, long AfterMilli, string Kind, string Reason,
    Guid? DocumentId, DateTimeOffset At) : IEntity;
public sealed record SaleLine(Guid ProductId, string Code, string Name, long QuantityMilli,
    long UnitPriceCents, long CostCents, int VatBasisPoints, long DiscountCents,
    long TotalCents, long NetCents, long VatCents);
public sealed record Tender(PaymentMethod Method, long AppliedCents, long ReceivedCents, string Reference)
{
    public long ChangeCents => Method == PaymentMethod.Cash ? ReceivedCents - AppliedCents : 0;
    public string Verification => Method == PaymentMethod.Cash ? "CASH_RECEIVED" : "MANUAL_UNVERIFIED";
}
public sealed record Sale(Guid Id, long Version, long Number, Guid SessionId, Guid DeviceId,
    Guid UserId, string UserName, Contact? Customer, DateTimeOffset At, SaleLine[] Lines,
    Tender[] Payments, long TotalCents, long RefundedCents, FiscalState FiscalState,
    string Notes) : IEntity
{
    public long NetCents => Lines.Sum(x => x.NetCents);
    public long VatCents => Lines.Sum(x => x.VatCents);
    public long ChangeCents => Payments.Sum(x => x.ChangeCents);
    public string Display => $"#{Number:000000} · {At.ToLocalTime():dd/MM HH:mm} · {Money.Format(TotalCents)} · {UserName}";
}
public sealed record Refund(Guid Id, long Version, Guid SaleId, Guid SessionId, Guid UserId,
    long TotalCents, string Reason, DateTimeOffset At, Tender[] Payments) : IEntity;
public sealed record PurchaseLine(Guid ProductId, long QuantityMilli, long UnitCostCents);
public sealed record Purchase(Guid Id, long Version, Guid SupplierId, Guid UserId,
    DateTimeOffset At, PurchaseLine[] Lines, long TotalCents, long PaidCents,
    string Reference) : IEntity;
public sealed record AuditEntry(Guid Id, long Version, Guid UserId, Guid DeviceId,
    DateTimeOffset At, string Action, string EntityId, string Before, string After) : IEntity;
public sealed record Notification(Guid Id, long Version, string Title, string Detail,
    DateTimeOffset At, bool Read) : IEntity;
public sealed record FiscalDocument(Guid Id, long Version, Guid SaleId, string Environment,
    int PointOfSale, int VoucherType, long? VoucherNumber, FiscalState State, string? Cae,
    string? CaeExpiry, string Detail, DateTimeOffset At) : IEntity;
public sealed record SaleInput(Guid ProductId, long ProductVersion, long QuantityMilli,
    long DiscountCents = 0, long? OverridePriceCents = null);
public sealed record CheckoutRequest(Guid Id, Guid? CustomerId, SaleInput[] Items,
    Tender[] Payments, string Notes, bool RequestInvoice = false);
public sealed record StockAdjustment(Guid ProductId, long ProductVersion, long DeltaMilli, string Reason);
public sealed record RemoteCommand(Guid Id, Guid BusinessId, Guid TargetDeviceId, string Type,
    string Payload, string RequestedBy, DateTimeOffset RequestedAt, DateTimeOffset ExpiresAt,
    RemoteStatus Status, string Result = "");
public sealed record PriceCommand(Guid ProductId, long ExpectedVersion, long PriceCents);
public sealed record ActiveCommand(Guid ProductId, long ExpectedVersion, bool Active);
public sealed record SyncEnvelope(long Sequence, Guid EventId, string Kind, Guid EntityId,
    long Version, string Payload, string PayloadHash, DateTimeOffset At);
public sealed record Snapshot(Business? Business, Product[] Products, CashSession? Cash,
    Sale[] Sales, Contact[] Contacts, Notification[] Notifications, FiscalDocument[] Invoices,
    int PendingSync, string Integrity);

public sealed class BusinessException(string message) : Exception(message);
public static class Json
{
    public static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web)
    { Converters = { new JsonStringEnumConverter() } };
    public static string Write<T>(T value) => JsonSerializer.Serialize(value, Options);
    public static T Read<T>(string value) => JsonSerializer.Deserialize<T>(value, Options)
        ?? throw new BusinessException("Datos incompletos o incompatibles.");
    public static string Hash(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
}
public static class Money
{
    public static readonly CultureInfo Culture = CultureInfo.GetCultureInfo("es-AR");
    public const long MaxCents = 100_000_000_000L;
    public static long Cents(decimal amount)
    {
        if (amount < 0 || amount > MaxCents / 100m) throw new BusinessException("Importe fuera de rango.");
        if (decimal.Round(amount, 2) != amount) throw new BusinessException("El importe admite hasta dos decimales.");
        return checked((long)(amount * 100m));
    }
    public static long Quantity(decimal quantity)
    {
        if (quantity <= 0 || quantity > 1_000_000 || decimal.Round(quantity, 3) != quantity)
            throw new BusinessException("Cantidad inválida: hasta tres decimales.");
        return checked((long)(quantity * 1000m));
    }
    public static long Extend(long cents, long quantityMilli) => checked((long)
        decimal.Round(cents * (decimal)quantityMilli / 1000m, 0, MidpointRounding.AwayFromZero));
    public static string Format(long cents) => (cents / 100m).ToString("C2", Culture);
    public static void Valid(long cents, bool allowZero = true)
    {
        if (cents < 0 || cents > MaxCents || (!allowZero && cents == 0))
            throw new BusinessException("Importe fuera de rango.");
    }
}
public static class SaleMath
{
    public static SaleLine Line(Product product, SaleInput input, bool canDiscount)
    {
        if (!product.Active) throw new BusinessException($"{product.Name} está pausado.");
        if (product.Version != input.ProductVersion) throw new BusinessException($"Cambió {product.Name}; actualizá el carrito.");
        if (input.QuantityMilli <= 0 || input.QuantityMilli > 1_000_000_000)
            throw new BusinessException("Cantidad inválida.");
        if (product.Unit == "un" && input.QuantityMilli % 1000 != 0)
            throw new BusinessException("Este producto se vende por unidades enteras.");
        if (input.QuantityMilli > product.StockMilli) throw new BusinessException($"Stock insuficiente: {product.Name}.");
        if ((input.DiscountCents != 0 || input.OverridePriceCents is not null) && !canDiscount)
            throw new BusinessException("No tenés permiso para descuentos o cambios de precio.");
        var price = input.OverridePriceCents ?? product.PriceCents;
        Money.Valid(price, false);
        var gross = Money.Extend(price, input.QuantityMilli);
        if (input.DiscountCents < 0 || input.DiscountCents >= gross)
            throw new BusinessException("El descuento debe ser menor al subtotal.");
        var total = gross - input.DiscountCents;
        Money.Valid(total, false);
        var net = (long)decimal.Round(total * 10000m / (10000 + product.VatBasisPoints), 0, MidpointRounding.AwayFromZero);
        return new(product.Id, product.Code, product.Name, input.QuantityMilli, price,
            product.CostCents, product.VatBasisPoints, input.DiscountCents, total, net, total - net);
    }
    public static long ValidatePayments(long total, IReadOnlyList<Tender> payments)
    {
        Money.Valid(total, false);
        if (payments.Count is < 1 or > 8) throw new BusinessException("Ingresá entre uno y ocho medios de pago.");
        foreach (var p in payments)
        {
            if (!Enum.IsDefined(p.Method)) throw new BusinessException("Medio de pago no permitido.");
            Money.Valid(p.AppliedCents, false); Money.Valid(p.ReceivedCents, false);
            if (p.Method == PaymentMethod.Cash && p.ReceivedCents < p.AppliedCents)
                throw new BusinessException("El efectivo recibido no alcanza.");
            if (p.Method != PaymentMethod.Cash && (p.ReceivedCents != p.AppliedCents || string.IsNullOrWhiteSpace(p.Reference)))
                throw new BusinessException("El cobro electrónico manual requiere referencia y monto exacto.");
            if (p.Reference.Length > 160) throw new BusinessException("Referencia demasiado larga.");
        }
        if (payments.Sum(x => x.AppliedCents) != total) throw new BusinessException("La suma de los cobros debe coincidir con el total.");
        return payments.Sum(x => x.ChangeCents);
    }
}
