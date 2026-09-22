using System.Net;
using System.Security.Cryptography;
using System.Security.Cryptography.Pkcs;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Text.Json;
using CajaClara.Core;
using CajaClara.Fiscal;

var results = new List<object>();
var output = Path.GetFullPath(args.FirstOrDefault() ?? "artifacts");
Directory.CreateDirectory(output);

async Task Test(string name, Func<Task> action)
{
    try { await action(); results.Add(new { name, status = "PASS" }); Console.WriteLine("PASS " + name); }
    catch (Exception e) { results.Add(new { name, status = "FAIL", error = e.ToString() }); Console.WriteLine("FAIL " + name + " " + e.Message); }
}
void Equal<T>(T actual, T expected) where T : notnull
{
    if (!EqualityComparer<T>.Default.Equals(actual, expected)) throw new Exception($"Expected {expected}; got {actual}");
}
void Contains(string text, string expected)
{
    if (!text.Contains(expected, StringComparison.Ordinal)) throw new Exception("Missing: " + expected + "\n" + text);
}

var settings = new ArcaSettings(20_123_456_789, 7, ArcaEnvironment.Homologacion);
var ticket = new ArcaAccessTicket("TOKEN", "SIGN", DateTimeOffset.UtcNow.AddHours(8));

await Test("fiscal_settings_validate", () => { settings.Validate(); return Task.CompletedTask; });
await Test("tra_targets_wsfe", () =>
{
    var client = new ArcaWsaaClient(new HttpClient(new QueueHandler()));
    var tra = client.BuildTra();
    Contains(tra, "<service>wsfe</service>");
    Contains(tra, "<generationTime>");
    Contains(tra, "<expirationTime>");
    return Task.CompletedTask;
});
await Test("cms_signature_contains_tra", () =>
{
    using var rsa = RSA.Create(2048);
    var request = new CertificateRequest("CN=Caja Clara QA", rsa, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
    using var generated = request.CreateSelfSigned(DateTimeOffset.UtcNow.AddDays(-1), DateTimeOffset.UtcNow.AddDays(30));
    var pfx = generated.Export(X509ContentType.Pkcs12, "qa-secret");
    using var cert = ArcaCertificate.LoadPkcs12(pfx, "qa-secret");
    var tra = new ArcaWsaaClient(new HttpClient(new QueueHandler())).BuildTra();
    var encoded = Convert.FromBase64String(ArcaWsaaClient.SignTra(tra, cert));
    var cms = new SignedCms(); cms.Decode(encoded); cms.CheckSignature(true);
    Contains(Encoding.UTF8.GetString(cms.ContentInfo.Content), "<service>wsfe</service>");
    return Task.CompletedTask;
});
await Test("wsaa_parses_ticket", async () =>
{
    var ta = "<loginTicketResponse><header><expirationTime>" + DateTimeOffset.UtcNow.AddHours(8).ToString("O") + "</expirationTime></header><credentials><token>abc</token><sign>xyz</sign></credentials></loginTicketResponse>";
    var handler = new QueueHandler();
    handler.Enqueue(async (request, _) =>
    {
        Equal(request.RequestUri!.Host, "wsaahomo.afip.gov.ar");
        if (!request.Headers.TryGetValues("SOAPAction", out var actions) || !actions.Contains("urn:LoginCms")) throw new Exception("SOAPAction missing");
        var body = await request.Content!.ReadAsStringAsync();
        Contains(body, "loginCms");
        var escaped = WebUtility.HtmlEncode(ta);
        return Xml("<soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\"><soap:Body><loginCmsResponse xmlns=\"http://wsaa.view.sua.dvadac.desein.afip.gov\"><loginCmsReturn>" + escaped + "</loginCmsReturn></loginCmsResponse></soap:Body></soap:Envelope>");
    });
    using var rsa = RSA.Create(2048);
    var req = new CertificateRequest("CN=Caja Clara QA", rsa, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
    using var cert = req.CreateSelfSigned(DateTimeOffset.UtcNow.AddDays(-1), DateTimeOffset.UtcNow.AddDays(30));
    var result = await new ArcaWsaaClient(new HttpClient(handler)).LoginAsync(settings, cert);
    Equal(result.Token, "abc"); Equal(result.Sign, "xyz");
});
await Test("wsfe_builds_rg5616_request", () =>
{
    var invoice = Invoice();
    var xml = new ArcaWsfeClient(new HttpClient(new QueueHandler())).BuildAuthorization(settings, ticket, invoice, 44).ToString();
    Contains(xml, "<CondicionIVAReceptorId>5</CondicionIVAReceptorId>");
    Contains(xml, "<CbteDesde>44</CbteDesde>");
    Contains(xml, "<Id>5</Id>");
    Contains(xml, "<BaseImp>100.00</BaseImp>");
    Contains(xml, "<Importe>21.00</Importe>");
    return Task.CompletedTask;
});
await Test("voucher_c_rejects_discriminated_vat", () =>
{
    try { (Invoice() with { VoucherType = 11 }).Validate(); }
    catch (BusinessException) { return Task.CompletedTask; }
    throw new Exception("Expected validation failure");
});
await Test("wsfe_authorizes_next_correlative_number", async () =>
{
    var handler = new QueueHandler();
    handler.Enqueue((_, _) => Task.FromResult(Xml(Last(41))));
    handler.Enqueue(async (request, _) =>
    {
        var body = await request.Content!.ReadAsStringAsync();
        Contains(body, "<CbteDesde>42</CbteDesde>");
        Contains(body, "<CondicionIVAReceptorId>5</CondicionIVAReceptorId>");
        return Xml(Authorized(42, "76123456789012", "20261001"));
    });
    var result = await new ArcaWsfeClient(new HttpClient(handler)).AuthorizeAsync(settings, ticket, Invoice());
    Equal(result.State, FiscalState.Authorized); Equal(result.VoucherNumber, 42L); Equal(result.Cae!, "76123456789012");
});
await Test("wsfe_rejects_without_fake_cae", async () =>
{
    var handler = new QueueHandler();
    handler.Enqueue((_, _) => Task.FromResult(Xml(Last(8))));
    handler.Enqueue((_, _) => Task.FromResult(Xml(Rejected(9, "10245", "Condición IVA inválida"))));
    var result = await new ArcaWsfeClient(new HttpClient(handler)).AuthorizeAsync(settings, ticket, Invoice());
    Equal(result.State, FiscalState.Rejected); Equal(result.VoucherNumber, 9L);
    if (result.Cae is not null) throw new Exception("Rejected invoice had CAE");
});
await Test("uncertain_transport_recovers_by_consult", async () =>
{
    var handler = new QueueHandler();
    handler.Enqueue((_, _) => Task.FromResult(Xml(Last(70))));
    handler.Enqueue((_, _) => throw new HttpRequestException("connection lost after send"));
    handler.Enqueue((_, _) => Task.FromResult(Xml(Consulted("A", "76111111111111", "20261010"))));
    var result = await new ArcaWsfeClient(new HttpClient(handler)).AuthorizeAsync(settings, ticket, Invoice());
    Equal(result.State, FiscalState.Authorized); Equal(result.VoucherNumber, 71L); Equal(result.RecoveredAfterUncertainTransport, true);
});

var failed = results.Count(x => JsonSerializer.Serialize(x).Contains("\"FAIL\"", StringComparison.Ordinal));
File.WriteAllText(Path.Combine(output, "fiscal-test-results.json"), JsonSerializer.Serialize(new { total = results.Count, passed = results.Count - failed, failed, tests = results }, new JsonSerializerOptions { WriteIndented = true }));
return failed == 0 ? 0 : 1;

static ArcaInvoiceRequest Invoice() => new(Guid.NewGuid(), 6, 1, 99, 0, 5, DateOnly.FromDateTime(DateTime.UtcNow),
    12100, 0, 10000, 0, [new ArcaVatLine(5, 10000, 2100)], []);

static HttpResponseMessage Xml(string content) => new(HttpStatusCode.OK) { Content = new StringContent(content, Encoding.UTF8, "text/xml") };
static string Last(long number) => $"<soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\"><soap:Body><FECompUltimoAutorizadoResponse xmlns=\"http://ar.gov.afip.dif.FEV1/\"><FECompUltimoAutorizadoResult><CbteNro>{number}</CbteNro></FECompUltimoAutorizadoResult></FECompUltimoAutorizadoResponse></soap:Body></soap:Envelope>";
static string Authorized(long number, string cae, string expiry) => $"<soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\"><soap:Body><FECAESolicitarResponse xmlns=\"http://ar.gov.afip.dif.FEV1/\"><FECAESolicitarResult><FeCabResp><Resultado>A</Resultado></FeCabResp><FeDetResp><FECAEDetResponse><CbteDesde>{number}</CbteDesde><Resultado>A</Resultado><CAE>{cae}</CAE><CAEFchVto>{expiry}</CAEFchVto></FECAEDetResponse></FeDetResp></FECAESolicitarResult></FECAESolicitarResponse></soap:Body></soap:Envelope>";
static string Rejected(long number, string code, string message) => $"<soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\"><soap:Body><FECAESolicitarResponse xmlns=\"http://ar.gov.afip.dif.FEV1/\"><FECAESolicitarResult><FeCabResp><Resultado>R</Resultado></FeCabResp><FeDetResp><FECAEDetResponse><CbteDesde>{number}</CbteDesde><Resultado>R</Resultado><Observaciones><Obs><Code>{code}</Code><Msg>{message}</Msg></Obs></Observaciones></FECAEDetResponse></FeDetResp></FECAESolicitarResult></FECAESolicitarResponse></soap:Body></soap:Envelope>";
static string Consulted(string result, string code, string expiry) => $"<soap:Envelope xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\"><soap:Body><FECompConsultarResponse xmlns=\"http://ar.gov.afip.dif.FEV1/\"><FECompConsultarResult><ResultGet><Resultado>{result}</Resultado><CodAutorizacion>{code}</CodAutorizacion><FchVto>{expiry}</FchVto></ResultGet></FECompConsultarResult></FECompConsultarResponse></soap:Body></soap:Envelope>";

sealed class QueueHandler : HttpMessageHandler
{
    private readonly Queue<Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>>> queue = new();
    public void Enqueue(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> item) => queue.Enqueue(item);
    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        if (queue.Count == 0) throw new InvalidOperationException("Unexpected HTTP request: " + request.RequestUri);
        return queue.Dequeue()(request, cancellationToken);
    }
}
