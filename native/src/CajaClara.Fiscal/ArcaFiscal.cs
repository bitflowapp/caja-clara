using System.Globalization;
using System.Net;
using System.Security.Cryptography.Pkcs;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Xml.Linq;
using CajaClara.Core;

namespace CajaClara.Fiscal;

public enum ArcaEnvironment { Homologacion, Produccion }

public sealed record ArcaSettings(long Cuit, int PointOfSale, ArcaEnvironment Environment)
{
    public Uri WsaaEndpoint => new(Environment == ArcaEnvironment.Homologacion
        ? "https://wsaahomo.afip.gov.ar/ws/services/LoginCms"
        : "https://wsaa.afip.gov.ar/ws/services/LoginCms");
    public Uri WsfeEndpoint => new(Environment == ArcaEnvironment.Homologacion
        ? "https://wswhomo.afip.gov.ar/wsfev1/service.asmx"
        : "https://servicios1.afip.gov.ar/wsfev1/service.asmx");

    public void Validate()
    {
        if (Cuit is < 20_000_000_000 or > 99_999_999_999) throw new BusinessException("CUIT emisor inválido.");
        if (PointOfSale is < 1 or > 99998) throw new BusinessException("Punto de venta ARCA inválido.");
    }
}

public sealed record ArcaAccessTicket(string Token, string Sign, DateTimeOffset ExpiresAt);
public sealed record ArcaVatLine(int Id, long TaxableBaseCents, long VatCents);
public sealed record ArcaAssociatedVoucher(int Type, int PointOfSale, long Number, long? Cuit = null, DateOnly? Date = null);

public sealed record ArcaInvoiceRequest(
    Guid RequestId,
    int VoucherType,
    int Concept,
    int DocumentType,
    long DocumentNumber,
    int RecipientVatConditionId,
    DateOnly Date,
    long TotalCents,
    long NonTaxedCents,
    long TaxableCents,
    long ExemptCents,
    ArcaVatLine[] Vat,
    ArcaAssociatedVoucher[] Associated,
    string CurrencyId = "PES",
    decimal CurrencyQuote = 1m)
{
    public long VatCents => Vat.Sum(x => x.VatCents);

    public void Validate()
    {
        if (RequestId == Guid.Empty) throw new BusinessException("Identificador fiscal inválido.");
        if (VoucherType <= 0 || Concept is < 1 or > 3) throw new BusinessException("Tipo de comprobante o concepto inválido.");
        if (DocumentType < 0 || DocumentNumber < 0) throw new BusinessException("Documento receptor inválido.");
        if (RecipientVatConditionId <= 0) throw new BusinessException("Condición frente al IVA del receptor obligatoria.");
        Money.Valid(TotalCents, false); Money.Valid(NonTaxedCents); Money.Valid(TaxableCents); Money.Valid(ExemptCents);
        foreach (var item in Vat)
        {
            if (item.Id <= 0) throw new BusinessException("Alícuota IVA inválida.");
            Money.Valid(item.TaxableBaseCents); Money.Valid(item.VatCents);
        }
        if (NonTaxedCents + TaxableCents + ExemptCents + VatCents != TotalCents)
            throw new BusinessException("Los importes fiscales no reconcilian con el total.");
        if (CurrencyId.Length is < 1 or > 3 || CurrencyQuote <= 0) throw new BusinessException("Moneda fiscal inválida.");
        if (IsVoucherC(VoucherType) && Vat.Length != 0) throw new BusinessException("Los comprobantes C no deben discriminar IVA.");
        foreach (var associated in Associated)
            if (associated.Type <= 0 || associated.PointOfSale is < 1 or > 99998 || associated.Number <= 0)
                throw new BusinessException("Comprobante asociado inválido.");
    }

    public static bool IsVoucherC(int type) => type is 11 or 12 or 13 or 15;
}

public sealed record ArcaAuthorization(
    FiscalState State,
    long VoucherNumber,
    string? Cae,
    string? CaeExpiry,
    string Detail,
    bool RecoveredAfterUncertainTransport = false);

public static class ArcaCertificate
{
    public static X509Certificate2 LoadPkcs12(byte[] pkcs12, string password)
    {
        if (pkcs12.Length == 0) throw new BusinessException("El certificado ARCA está vacío.");
        var certificate = X509CertificateLoader.LoadPkcs12(pkcs12, password,
            X509KeyStorageFlags.EphemeralKeySet | X509KeyStorageFlags.Exportable);
        if (!certificate.HasPrivateKey) { certificate.Dispose(); throw new BusinessException("El certificado ARCA no contiene clave privada."); }
        var now = DateTime.UtcNow;
        if (certificate.NotBefore.ToUniversalTime() > now || certificate.NotAfter.ToUniversalTime() <= now)
        { certificate.Dispose(); throw new BusinessException("El certificado ARCA está fuera de vigencia."); }
        return certificate;
    }
}

public sealed class ArcaWsaaClient(HttpClient http, TimeProvider? clock = null)
{
    private static readonly XNamespace Soap = "http://schemas.xmlsoap.org/soap/envelope/";
    private static readonly XNamespace Wsaa = "http://wsaa.view.sua.dvadac.desein.afip.gov";
    private readonly TimeProvider time = clock ?? TimeProvider.System;

    public string BuildTra()
    {
        var now = time.GetUtcNow();
        return new XDocument(new XDeclaration("1.0", "UTF-8", null),
            new XElement("loginTicketRequest",
                new XAttribute("version", "1.0"),
                new XElement("header",
                    new XElement("uniqueId", now.ToUnixTimeSeconds().ToString(CultureInfo.InvariantCulture)),
                    new XElement("generationTime", now.AddMinutes(-5).ToString("yyyy-MM-dd'T'HH:mm:ss.fffK", CultureInfo.InvariantCulture)),
                    new XElement("expirationTime", now.AddHours(10).ToString("yyyy-MM-dd'T'HH:mm:ss.fffK", CultureInfo.InvariantCulture))),
                new XElement("service", "wsfe"))).ToString(SaveOptions.DisableFormatting);
    }

    public static string SignTra(string tra, X509Certificate2 certificate)
    {
        if (!certificate.HasPrivateKey) throw new BusinessException("El certificado ARCA no tiene clave privada.");
        var cms = new SignedCms(new ContentInfo(Encoding.UTF8.GetBytes(tra)), detached: false);
        var signer = new CmsSigner(SubjectIdentifierType.IssuerAndSerialNumber, certificate)
        { IncludeOption = X509IncludeOption.EndCertOnly };
        cms.ComputeSignature(signer);
        return Convert.ToBase64String(cms.Encode());
    }

    public async Task<ArcaAccessTicket> LoginAsync(ArcaSettings settings, X509Certificate2 certificate, CancellationToken cancellationToken = default)
    {
        settings.Validate();
        var signed = SignTra(BuildTra(), certificate);
        var envelope = new XDocument(new XElement(Soap + "Envelope",
            new XAttribute(XNamespace.Xmlns + "soapenv", Soap),
            new XAttribute(XNamespace.Xmlns + "wsaa", Wsaa),
            new XElement(Soap + "Header"),
            new XElement(Soap + "Body",
                new XElement(Wsaa + "loginCms", new XElement(Wsaa + "in0", signed)))));
        using var request = new HttpRequestMessage(HttpMethod.Post, settings.WsaaEndpoint)
        { Content = new StringContent(envelope.ToString(SaveOptions.DisableFormatting), Encoding.UTF8, "text/xml") };
        request.Headers.TryAddWithoutValidation("SOAPAction", "urn:LoginCms");
        using var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode) throw new BusinessException($"WSAA respondió HTTP {(int)response.StatusCode}.");
        var soap = ParseSoap(body);
        var returned = soap.Descendants().FirstOrDefault(x => x.Name.LocalName == "loginCmsReturn")?.Value;
        if (string.IsNullOrWhiteSpace(returned)) throw SoapError(soap, "WSAA no devolvió Ticket de Acceso.");
        var ta = XDocument.Parse(WebUtility.HtmlDecode(returned));
        var token = ta.Descendants().FirstOrDefault(x => x.Name.LocalName == "token")?.Value;
        var sign = ta.Descendants().FirstOrDefault(x => x.Name.LocalName == "sign")?.Value;
        var expires = ta.Descendants().FirstOrDefault(x => x.Name.LocalName == "expirationTime")?.Value;
        if (string.IsNullOrWhiteSpace(token) || string.IsNullOrWhiteSpace(sign) ||
            !DateTimeOffset.TryParse(expires, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var expiration))
            throw new BusinessException("Ticket de Acceso WSAA incompleto.");
        if (expiration <= time.GetUtcNow().AddMinutes(2)) throw new BusinessException("WSAA devolvió un Ticket de Acceso vencido o demasiado próximo a vencer.");
        return new(token, sign, expiration);
    }

    private static XDocument ParseSoap(string xml)
    {
        try { var doc = XDocument.Parse(xml); if (doc.Descendants().Any(x => x.Name.LocalName == "Fault")) throw SoapError(doc, "Error SOAP de ARCA."); return doc; }
        catch (System.Xml.XmlException) { throw new BusinessException("ARCA devolvió XML inválido."); }
    }

    private static BusinessException SoapError(XDocument doc, string fallback)
    {
        var fault = doc.Descendants().FirstOrDefault(x => x.Name.LocalName is "faultstring" or "Text")?.Value?.Trim();
        return new BusinessException(string.IsNullOrWhiteSpace(fault) ? fallback : "ARCA: " + fault);
    }
}

public sealed class ArcaWsfeClient(HttpClient http)
{
    private static readonly XNamespace Soap = "http://schemas.xmlsoap.org/soap/envelope/";
    private static readonly XNamespace Fe = "http://ar.gov.afip.dif.FEV1/";

    public async Task<long> LastAuthorizedAsync(ArcaSettings settings, ArcaAccessTicket ticket, int voucherType, CancellationToken cancellationToken = default)
    {
        var operation = new XElement(Fe + "FECompUltimoAutorizado", Auth(settings, ticket),
            new XElement(Fe + "PtoVta", settings.PointOfSale),
            new XElement(Fe + "CbteTipo", voucherType));
        var doc = await SendAsync(settings, "FECompUltimoAutorizado", operation, cancellationToken);
        ThrowErrors(doc);
        var value = doc.Descendants().FirstOrDefault(x => x.Name.LocalName == "CbteNro")?.Value;
        return long.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var number)
            ? number : throw new BusinessException("ARCA no devolvió el último comprobante autorizado.");
    }

    public async Task<ArcaAuthorization> AuthorizeAsync(ArcaSettings settings, ArcaAccessTicket ticket, ArcaInvoiceRequest invoice, CancellationToken cancellationToken = default)
    {
        settings.Validate(); invoice.Validate();
        var number = checked(await LastAuthorizedAsync(settings, ticket, invoice.VoucherType, cancellationToken) + 1);
        var operation = BuildAuthorization(settings, ticket, invoice, number);
        XDocument doc;
        try { doc = await SendAsync(settings, "FECAESolicitar", operation, cancellationToken); }
        catch (Exception error) when (error is HttpRequestException or TaskCanceledException)
        {
            var recovered = await ConsultAsync(settings, ticket, invoice.VoucherType, number, cancellationToken);
            return recovered is null
                ? new(FiscalState.Unknown, number, null, null, "No se confirmó el resultado de ARCA. Consultar el comprobante antes de reintentar.", true)
                : recovered with { RecoveredAfterUncertainTransport = true };
        }
        ThrowErrors(doc);
        var detail = doc.Descendants().FirstOrDefault(x => x.Name.LocalName == "FECAEDetResponse")
            ?? throw new BusinessException("ARCA no devolvió el detalle de autorización.");
        var result = Value(detail, "Resultado");
        var cae = Value(detail, "CAE");
        var expiry = Value(detail, "CAEFchVto");
        var observations = Messages(detail, "Obs");
        if (result == "A" && !string.IsNullOrWhiteSpace(cae))
            return new(FiscalState.Authorized, number, cae, expiry, Join("Autorizado por ARCA.", observations));
        if (result == "R") return new(FiscalState.Rejected, number, null, null, Join("Comprobante rechazado por ARCA.", observations));
        return new(FiscalState.Unknown, number, string.IsNullOrWhiteSpace(cae) ? null : cae, expiry, Join("Respuesta fiscal no concluyente.", observations));
    }

    public async Task<ArcaAuthorization?> ConsultAsync(ArcaSettings settings, ArcaAccessTicket ticket, int voucherType, long number, CancellationToken cancellationToken = default)
    {
        var request = new XElement(Fe + "FECompConsultar", Auth(settings, ticket),
            new XElement(Fe + "FeCompConsReq",
                new XElement(Fe + "CbteTipo", voucherType),
                new XElement(Fe + "CbteNro", number),
                new XElement(Fe + "PtoVta", settings.PointOfSale)));
        var doc = await SendAsync(settings, "FECompConsultar", request, cancellationToken);
        var result = doc.Descendants().FirstOrDefault(x => x.Name.LocalName == "ResultGet");
        if (result is null) return null;
        var state = Value(result, "Resultado") == "A" ? FiscalState.Authorized : FiscalState.Rejected;
        var code = Value(result, "CodAutorizacion");
        var expiry = Value(result, "FchVto");
        return new(state, number, string.IsNullOrWhiteSpace(code) ? null : code, expiry, Join("Resultado recuperado mediante FECompConsultar.", Messages(result, "Obs")));
    }

    public XElement BuildAuthorization(ArcaSettings settings, ArcaAccessTicket ticket, ArcaInvoiceRequest invoice, long number)
    {
        var detail = new XElement(Fe + "FECAEDetRequest",
            new XElement(Fe + "Concepto", invoice.Concept),
            new XElement(Fe + "DocTipo", invoice.DocumentType),
            new XElement(Fe + "DocNro", invoice.DocumentNumber),
            new XElement(Fe + "CbteDesde", number),
            new XElement(Fe + "CbteHasta", number),
            new XElement(Fe + "CbteFch", invoice.Date.ToString("yyyyMMdd", CultureInfo.InvariantCulture)),
            new XElement(Fe + "ImpTotal", Amount(invoice.TotalCents)),
            new XElement(Fe + "ImpTotConc", Amount(invoice.NonTaxedCents)),
            new XElement(Fe + "ImpNeto", Amount(invoice.TaxableCents)),
            new XElement(Fe + "ImpOpEx", Amount(invoice.ExemptCents)),
            new XElement(Fe + "ImpTrib", "0.00"),
            new XElement(Fe + "ImpIVA", Amount(invoice.VatCents)),
            new XElement(Fe + "MonId", invoice.CurrencyId),
            new XElement(Fe + "MonCotiz", invoice.CurrencyQuote.ToString("0.000000", CultureInfo.InvariantCulture)),
            new XElement(Fe + "CondicionIVAReceptorId", invoice.RecipientVatConditionId));

        if (invoice.Concept is 2 or 3)
        {
            var date = invoice.Date.ToString("yyyyMMdd", CultureInfo.InvariantCulture);
            detail.Add(new XElement(Fe + "FchServDesde", date), new XElement(Fe + "FchServHasta", date), new XElement(Fe + "FchVtoPago", date));
        }
        if (invoice.Associated.Length > 0)
            detail.Add(new XElement(Fe + "CbtesAsoc", invoice.Associated.Select(x =>
                new XElement(Fe + "CbteAsoc",
                    new XElement(Fe + "Tipo", x.Type),
                    new XElement(Fe + "PtoVta", x.PointOfSale),
                    new XElement(Fe + "Nro", x.Number),
                    x.Cuit is long cuit ? new XElement(Fe + "Cuit", cuit) : null,
                    x.Date is DateOnly date ? new XElement(Fe + "CbteFch", date.ToString("yyyyMMdd", CultureInfo.InvariantCulture)) : null))));
        if (invoice.Vat.Length > 0)
            detail.Add(new XElement(Fe + "Iva", invoice.Vat.Select(x =>
                new XElement(Fe + "AlicIva",
                    new XElement(Fe + "Id", x.Id),
                    new XElement(Fe + "BaseImp", Amount(x.TaxableBaseCents)),
                    new XElement(Fe + "Importe", Amount(x.VatCents))))));

        return new XElement(Fe + "FECAESolicitar", Auth(settings, ticket),
            new XElement(Fe + "FeCAEReq",
                new XElement(Fe + "FeCabReq",
                    new XElement(Fe + "CantReg", 1),
                    new XElement(Fe + "PtoVta", settings.PointOfSale),
                    new XElement(Fe + "CbteTipo", invoice.VoucherType)),
                new XElement(Fe + "FeDetReq", detail)));
    }

    private async Task<XDocument> SendAsync(ArcaSettings settings, string operationName, XElement operation, CancellationToken cancellationToken)
    {
        var envelope = new XDocument(new XElement(Soap + "Envelope",
            new XAttribute(XNamespace.Xmlns + "soap", Soap),
            new XElement(Soap + "Body", operation)));
        using var request = new HttpRequestMessage(HttpMethod.Post, settings.WsfeEndpoint)
        { Content = new StringContent(envelope.ToString(SaveOptions.DisableFormatting), Encoding.UTF8, "text/xml") };
        request.Headers.TryAddWithoutValidation("SOAPAction", $""http://ar.gov.afip.dif.FEV1/{operationName}"");
        using var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode) throw new HttpRequestException($"WSFE respondió HTTP {(int)response.StatusCode}.", null, response.StatusCode);
        XDocument doc;
        try { doc = XDocument.Parse(body); } catch (System.Xml.XmlException) { throw new BusinessException("ARCA devolvió XML inválido."); }
        var fault = doc.Descendants().FirstOrDefault(x => x.Name.LocalName is "faultstring" or "Text")?.Value;
        if (!string.IsNullOrWhiteSpace(fault)) throw new BusinessException("ARCA: " + fault.Trim());
        return doc;
    }

    private static XElement Auth(ArcaSettings settings, ArcaAccessTicket ticket) =>
        new(Fe + "Auth", new XElement(Fe + "Token", ticket.Token), new XElement(Fe + "Sign", ticket.Sign), new XElement(Fe + "Cuit", settings.Cuit));

    private static string Amount(long cents) => (cents / 100m).ToString("0.00", CultureInfo.InvariantCulture);
    private static string Value(XElement parent, string name) => parent.Descendants().FirstOrDefault(x => x.Name.LocalName == name)?.Value?.Trim() ?? "";
    private static string[] Messages(XContainer parent, string localName) => parent.Descendants().Where(x => x.Name.LocalName == localName)
        .Select(x => string.Join(" ", x.Elements().Where(y => y.Name.LocalName is "Code" or "Msg").Select(y => y.Value.Trim())).Trim())
        .Where(x => x.Length > 0).ToArray();
    private static string Join(string prefix, IEnumerable<string> messages) => string.Join(" ", new[] { prefix }.Concat(messages).Where(x => !string.IsNullOrWhiteSpace(x)));

    private static void ThrowErrors(XDocument doc)
    {
        var errors = doc.Descendants().Where(x => x.Name.LocalName == "Err").Select(x =>
            string.Join(" ", x.Elements().Where(y => y.Name.LocalName is "Code" or "Msg").Select(y => y.Value.Trim())).Trim()).Where(x => x.Length > 0).ToArray();
        if (errors.Length > 0) throw new BusinessException("ARCA: " + string.Join(" | ", errors));
    }
}

public sealed class ArcaFiscalAuthorizationProvider(HttpClient http, TimeProvider? clock = null)
{
    private readonly ArcaWsaaClient wsaa = new(http, clock);
    private readonly ArcaWsfeClient wsfe = new(http);
    private ArcaAccessTicket? cached;
    private string? cachedCertificate;
    private ArcaEnvironment? cachedEnvironment;

    public async Task<ArcaAuthorization> AuthorizeAsync(ArcaSettings settings, X509Certificate2 certificate, ArcaInvoiceRequest invoice, CancellationToken cancellationToken = default)
    {
        var now = (clock ?? TimeProvider.System).GetUtcNow();
        if (cached is null || cached.ExpiresAt <= now.AddMinutes(5) || cachedCertificate != certificate.Thumbprint || cachedEnvironment != settings.Environment)
        {
            cached = await wsaa.LoginAsync(settings, certificate, cancellationToken);
            cachedCertificate = certificate.Thumbprint;
            cachedEnvironment = settings.Environment;
        }
        return await wsfe.AuthorizeAsync(settings, cached, invoice, cancellationToken);
    }
}
