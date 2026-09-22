namespace CajaClara.Core;

public static class Labels
{
    public static string Payment(PaymentMethod value) => value switch
    {
        PaymentMethod.Cash => "Efectivo", PaymentMethod.Transfer => "Transferencia",
        PaymentMethod.Debit => "Débito", PaymentMethod.Credit => "Crédito",
        PaymentMethod.MercadoPagoManual => "Mercado Pago (manual)",
        PaymentMethod.MercadoPagoQr => "Mercado Pago QR integrado", _ => "No reconocido"
    };
    public static string Fiscal(FiscalState value) => value switch
    {
        FiscalState.NotIssued => "Sin factura emitida", FiscalState.Pending => "Pendiente de autorización",
        FiscalState.Authorized => "Autorizado", FiscalState.Rejected => "Rechazado",
        FiscalState.Unknown => "Resultado sin confirmar", _ => "No reconocido"
    };
    public static string Cash(CashState value) => value switch
    { CashState.Open => "Abierta", CashState.ClosingRequested => "Cierre solicitado", CashState.Closed => "Cerrada", _ => "No reconocido" };
    public static string UserRole(Role value) => value switch
    { Role.Owner => "Dueño", Role.Admin => "Administrador", Role.Cashier => "Cajero", Role.Employee => "Empleado", Role.Viewer => "Consulta", _ => "No reconocido" };
}
public sealed record PaymentChoice(PaymentMethod Value, string Label)
{
    public static PaymentChoice[] All => Enum.GetValues<PaymentMethod>().Select(x => new PaymentChoice(x, Labels.Payment(x))).ToArray();
}
