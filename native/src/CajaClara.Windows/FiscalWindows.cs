using System.Security.Cryptography;
using System.Text;
using CajaClara.Core;
using CajaClara.Fiscal;

namespace CajaClara.Windows;

public sealed record FiscalDeviceSettings(
    long Cuit,
    int PointOfSale,
    int DefaultVoucherType,
    ArcaEnvironment Environment,
    string CertificateBase64,
    string CertificatePassword)
{
    public void Validate()
    {
        new ArcaSettings(Cuit, PointOfSale, Environment).Validate();
        if (DefaultVoucherType is not (1 or 6 or 11)) throw new BusinessException("Elegí Factura A, B o C.");
        if (string.IsNullOrWhiteSpace(CertificateBase64) || string.IsNullOrEmpty(CertificatePassword))
            throw new BusinessException("Certificado y contraseña ARCA obligatorios.");
        try { _ = Convert.FromBase64String(CertificateBase64); }
        catch (FormatException) { throw new BusinessException("Certificado ARCA inválido."); }
    }
}

public sealed record FiscalConfigurationSummary(long Cuit, int PointOfSale, int VoucherType, ArcaEnvironment Environment);

public static class FiscalSecrets
{
    private static string PathName => Path.Combine(App.DataDirectory, "fiscal.protected");
    private static readonly byte[] Entropy = Encoding.UTF8.GetBytes("LUNA.CajaClara.Native.Fiscal.v1");

    public static FiscalDeviceSettings? Load()
    {
        if (!File.Exists(PathName)) return null;
        try
        {
            var clear = ProtectedData.Unprotect(File.ReadAllBytes(PathName), Entropy, DataProtectionScope.CurrentUser);
            var settings = Json.Read<FiscalDeviceSettings>(Encoding.UTF8.GetString(clear));
            settings.Validate();
            return settings;
        }
        catch (Exception error) when (error is CryptographicException or IOException or System.Text.Json.JsonException or FormatException)
        {
            throw new BusinessException("No se pudo abrir la configuración fiscal protegida. Volvé a importar el certificado.");
        }
    }

    public static FiscalConfigurationSummary? Summary()
    {
        var value = Load();
        return value is null ? null : new(value.Cuit, value.PointOfSale, value.DefaultVoucherType, value.Environment);
    }

    public static void Save(FiscalDeviceSettings settings)
    {
        settings.Validate();
        using var certificate = ArcaCertificate.LoadPkcs12(Convert.FromBase64String(settings.CertificateBase64), settings.CertificatePassword);
        var encrypted = ProtectedData.Protect(Encoding.UTF8.GetBytes(Json.Write(settings)), Entropy, DataProtectionScope.CurrentUser);
        Directory.CreateDirectory(App.DataDirectory);
        var temp = PathName + ".new";
        File.WriteAllBytes(temp, encrypted);
        File.Move(temp, PathName, true);
    }

    public static void Remove()
    {
        if (File.Exists(PathName)) File.Delete(PathName);
    }
}

public sealed class FiscalCoordinator(PosService pos, HttpClient http)
{
    private readonly ArcaFiscalAuthorizationProvider provider = new(http);

    public bool Configured
    {
        get
        {
            try { return FiscalSecrets.Summary() is not null; }
            catch (BusinessException) { return false; }
        }
    }

    public async Task<FiscalDocument?> ProcessOnePendingAsync(Actor actor, CancellationToken cancellationToken = default)
    {
        var snapshot = pos.Snapshot(actor);
        var document = snapshot.Invoices
            .Where(x => x.State is FiscalState.Pending or FiscalState.Unknown)
            .OrderBy(x => x.At)
            .FirstOrDefault();
        return document is null ? null : await ProcessSaleAsync(actor, document.SaleId, cancellationToken);
    }

    public async Task<FiscalDocument> ProcessSaleAsync(Actor actor, Guid saleId, CancellationToken cancellationToken = default)
    {
        var configured = FiscalSecrets.Load() ?? throw new BusinessException("Configurá ARCA antes de emitir comprobantes.");
        configured.Validate();
        var context = pos.FiscalForSale(actor, saleId);
        if (context.Document.State == FiscalState.Authorized) return context.Document;
        VerifyIssuer(context.Business, configured);
        using var certificate = ArcaCertificate.LoadPkcs12(Convert.FromBase64String(configured.CertificateBase64), configured.CertificatePassword);

        if (context.Document.State == FiscalState.Unknown &&
            context.Document.VoucherNumber is > 0 &&
            context.Document.PointOfSale > 0 &&
            context.Document.VoucherType > 0)
        {
            var uncertainSettings = new ArcaSettings(configured.Cuit, context.Document.PointOfSale, ParseEnvironment(context.Document.Environment));
            var recovered = await provider.ConsultAsync(uncertainSettings, certificate, context.Document.VoucherType, context.Document.VoucherNumber.Value, cancellationToken);
            if (recovered is not null)
                return Apply(actor, context.Document, uncertainSettings, context.Document.VoucherType, recovered);

            var originalInvoice = BuildInvoice(context.Sale, context.Document.Id, context.Document.VoucherType);
            var exact = await provider.AuthorizeExactAsync(uncertainSettings, certificate, originalInvoice, context.Document.VoucherNumber.Value, cancellationToken);
            return Apply(actor, pos.FiscalForSale(actor, saleId).Document, uncertainSettings, context.Document.VoucherType, exact);
        }

        var settings = new ArcaSettings(configured.Cuit, configured.PointOfSale, configured.Environment);
        var voucherType = configured.DefaultVoucherType;
        var invoice = BuildInvoice(context.Sale, context.Document.Id, voucherType);
        var nextNumber = await provider.NextNumberAsync(settings, certificate, voucherType, cancellationToken);

        var staged = pos.ApplyFiscalOutcome(actor, context.Document.Id, context.Document.Version,
            new(EnvironmentName(settings.Environment), settings.PointOfSale, voucherType, nextNumber, FiscalState.Unknown, null, null,
                "Número fiscal preparado localmente. Todavía no existe una autorización confirmada de ARCA."));

        ArcaAuthorization authorization;
        try
        {
            authorization = await provider.AuthorizeExactAsync(settings, certificate, invoice, nextNumber, cancellationToken);
        }
        catch
        {
            // El número candidato ya quedó persistido. El próximo intento consultará ARCA antes de retransmitir.
            throw;
        }
        return Apply(actor, staged, settings, voucherType, authorization);
    }

    private FiscalDocument Apply(Actor actor, FiscalDocument document, ArcaSettings settings, int voucherType, ArcaAuthorization result)
    {
        var outcome = new FiscalOutcome(EnvironmentName(settings.Environment), settings.PointOfSale, voucherType, result.VoucherNumber,
            result.State, result.Cae, result.CaeExpiry, result.Detail);
        try { return pos.ApplyFiscalOutcome(actor, document.Id, document.Version, outcome); }
        catch (BusinessException)
        {
            var current = pos.FiscalForSale(actor, document.SaleId).Document;
            if (current.State == FiscalState.Authorized && current.Cae == result.Cae && current.VoucherNumber == result.VoucherNumber) return current;
            if (current.State != FiscalState.Authorized) return pos.ApplyFiscalOutcome(actor, current.Id, current.Version, outcome);
            throw;
        }
    }

    private static ArcaInvoiceRequest BuildInvoice(Sale sale, Guid requestId, int voucherType)
    {
        if (voucherType is not (1 or 6 or 11)) throw new BusinessException("Esta versión emite ventas A, B o C.");
        var document = Digits(sale.Customer?.TaxId);
        var documentType = document.Length == 11 ? 80 : 99;
        var documentNumber = document.Length == 11 && long.TryParse(document, out var parsed) ? parsed : 0L;
        var recipientCondition = sale.Customer?.TaxCondition ?? 5;
        var date = ArgentineDate(sale.At);

        if (ArcaInvoiceRequest.IsVoucherC(voucherType))
            return new(requestId, voucherType, 1, documentType, documentNumber, recipientCondition, date,
                sale.TotalCents, 0, sale.TotalCents, 0, [], []);

        var vat = sale.Lines.GroupBy(x => x.VatBasisPoints)
            .Select(group => new ArcaVatLine(VatId(group.Key), group.Sum(x => x.NetCents), group.Sum(x => x.VatCents)))
            .OrderBy(x => x.Id)
            .ToArray();
        return new(requestId, voucherType, 1, documentType, documentNumber, recipientCondition, date,
            sale.TotalCents, 0, sale.NetCents, 0, vat, []);
    }

    private static int VatId(int basisPoints) => basisPoints switch
    {
        0 => 3,
        250 => 9,
        500 => 8,
        1050 => 4,
        2100 => 5,
        2700 => 6,
        _ => throw new BusinessException("La venta contiene una alícuota no admitida por la configuración fiscal.")
    };

    private static DateOnly ArgentineDate(DateTimeOffset value)
    {
        try
        {
            var zone = TimeZoneInfo.FindSystemTimeZoneById("Argentina Standard Time");
            return DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(value, zone).DateTime);
        }
        catch (TimeZoneNotFoundException) { return DateOnly.FromDateTime(value.ToLocalTime().DateTime); }
    }

    private static string Digits(string? value) => new((value ?? "").Where(char.IsAsciiDigit).ToArray());

    private static void VerifyIssuer(Business business, FiscalDeviceSettings configured)
    {
        var businessCuit = Digits(business.TaxId);
        if (businessCuit.Length != 11 || !long.TryParse(businessCuit, out var parsed) || parsed != configured.Cuit)
            throw new BusinessException("El CUIT fiscal no coincide con el CUIT configurado en el comercio.");
    }

    private static string EnvironmentName(ArcaEnvironment value) => value == ArcaEnvironment.Produccion ? "PRODUCCION" : "HOMOLOGACION";
    private static ArcaEnvironment ParseEnvironment(string value) => value == "PRODUCCION" ? ArcaEnvironment.Produccion : ArcaEnvironment.Homologacion;
}
