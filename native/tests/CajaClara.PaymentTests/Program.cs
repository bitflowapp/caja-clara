using System.Net;
using System.Text;
using System.Text.Json;
using CajaClara.Core;
using CajaClara.Payments;

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

var options = new MercadoPagoAppOptions("client-123", "secret-456", new Uri("https://example.test/mp/callback"));

await Test("pkce_is_valid_s256", () =>
{
    var pkce = MercadoPagoOAuthClient.CreatePkce();
    if (pkce.Verifier.Length is < 43 or > 128) throw new Exception("Verifier length");
    if (pkce.Challenge.Contains('+') || pkce.Challenge.Contains('/') || pkce.Challenge.Contains('=')) throw new Exception("Challenge is not base64url");
    return Task.CompletedTask;
});
await Test("authorization_url_has_state_pkce_no_secret", () =>
{
    var pkce = MercadoPagoOAuthClient.CreatePkce();
    var uri = MercadoPagoOAuthClient.AuthorizationUri(options, "state-012345678901234567890123456789", pkce).ToString();
    Contains(uri, "response_type=code");
    Contains(uri, "client_id=client-123");
    Contains(uri, "code_challenge_method=S256");
    Contains(uri, Uri.EscapeDataString(pkce.Challenge));
    if (uri.Contains("secret-456", StringComparison.Ordinal)) throw new Exception("Client secret leaked into authorization URL");
    return Task.CompletedTask;
});
await Test("oauth_exchange_parses_rotating_tokens", async () =>
{
    var handler = new QueueHandler();
    handler.Enqueue(async (request, _) =>
    {
        Equal(request.Method, HttpMethod.Post);
        Equal(request.RequestUri!.ToString(), "https://api.mercadopago.com/oauth/token");
        var body = await request.Content!.ReadAsStringAsync();
        Contains(body, "\"grant_type\":\"authorization_code\"");
        Contains(body, "\"code_verifier\":");
        Contains(body, "\"client_secret\":\"secret-456\"");
        return Json(HttpStatusCode.OK, "{\"access_token\":\"APP_USR_access_token_123456789\",\"refresh_token\":\"refresh_token_123456789\",\"user_id\":12345,\"expires_in\":21600,\"scope\":\"offline_access read write\",\"live_mode\":true}");
    });
    var pkce = MercadoPagoOAuthClient.CreatePkce();
    var token = await new MercadoPagoOAuthClient(new HttpClient(handler)).ExchangeCodeAsync(options, "oauth-code", pkce.Verifier);
    Equal(token.UserId, 12345L); Equal(token.LiveMode, true);
    Equal(token.RefreshToken, "refresh_token_123456789");
});
await Test("oauth_refresh_uses_refresh_grant", async () =>
{
    var handler = new QueueHandler();
    handler.Enqueue(async (request, _) =>
    {
        var body = await request.Content!.ReadAsStringAsync();
        Contains(body, "\"grant_type\":\"refresh_token\"");
        Contains(body, "\"refresh_token\":\"old-refresh\"");
        return Json(HttpStatusCode.OK, "{\"access_token\":\"APP_USR_new_access_token_123456789\",\"refresh_token\":\"new-refresh\",\"user_id\":999,\"expires_in\":21600,\"scope\":\"offline_access\",\"live_mode\":true}");
    });
    var token = await new MercadoPagoOAuthClient(new HttpClient(handler)).RefreshAsync(options, "old-refresh");
    Equal(token.RefreshToken, "new-refresh");
});
await Test("qr_create_sends_bearer_and_idempotency", async () =>
{
    var handler = new QueueHandler();
    var idempotency = Guid.NewGuid();
    handler.Enqueue(async (request, _) =>
    {
        Equal(request.Method, HttpMethod.Post);
        Equal(request.RequestUri!.ToString(), "https://api.mercadopago.com/v1/orders");
        Equal(request.Headers.Authorization!.Scheme, "Bearer");
        Equal(request.Headers.Authorization!.Parameter!, "APP_USR_access_token_123456789");
        if (!request.Headers.TryGetValues("X-Idempotency-Key", out var keys) || keys.Single() != idempotency.ToString()) throw new Exception("Idempotency header missing");
        var body = await request.Content!.ReadAsStringAsync();
        Contains(body, "\"type\":\"qr\"");
        Contains(body, "\"external_pos_id\":\"CAJA-1\"");
        Contains(body, "\"mode\":\"dynamic\"");
        Contains(body, "\"external_reference\":\"SALE_000001\"");
        Contains(body, "\"total_amount\":1250");
        return Json(HttpStatusCode.Created, "{\"id\":\"ORD_123\",\"external_reference\":\"SALE_000001\",\"status\":\"created\",\"status_detail\":\"created\",\"currency\":\"ARS\",\"total_amount\":1250.00,\"type_response\":{\"qr_data\":\"000201010212...\"}}");
    });
    var order = await new MercadoPagoOrdersClient(new HttpClient(handler)).CreateQrAsync("APP_USR_access_token_123456789",
        new(idempotency, "SALE_000001", "CAJA-1", 125000, "Venta Caja Clara"));
    Equal(order.Id, "ORD_123"); Equal(order.QrData!, "000201010212...");
});
await Test("qr_response_amount_is_authoritative", async () =>
{
    var handler = new QueueHandler();
    handler.Enqueue((_, _) => Task.FromResult(Json(HttpStatusCode.OK, "{\"id\":\"ORD_124\",\"external_reference\":\"SALE_2\",\"status\":\"processed\",\"status_detail\":\"accredited\",\"currency\":\"ARS\",\"total_amount\":99.00}")));
    try { await new MercadoPagoOrdersClient(new HttpClient(handler)).GetAsync("APP_USR_access_token_123456789", "ORD_124", "SALE_2", 10000); }
    catch (BusinessException) { return; }
    throw new Exception("Expected mismatched amount rejection");
});
await Test("qr_response_currency_is_authoritative", async () =>
{
    var handler = new QueueHandler();
    handler.Enqueue((_, _) => Task.FromResult(Json(HttpStatusCode.OK, "{\"id\":\"ORD_125\",\"external_reference\":\"SALE_3\",\"status\":\"processed\",\"status_detail\":\"accredited\",\"currency\":\"USD\",\"total_amount\":100.00}")));
    try { await new MercadoPagoOrdersClient(new HttpClient(handler)).GetAsync("APP_USR_access_token_123456789", "ORD_125", "SALE_3", 10000); }
    catch (BusinessException) { return; }
    throw new Exception("Expected mismatched currency rejection");
});
await Test("webhook_hmac_valid_and_tamper_rejected", () =>
{
    var secret = "webhook-secret-very-long";
    var dataId = "ABC123";
    var requestId = "request-456";
    var timestamp = "1710000000";
    var manifest = $"id:{dataId.ToLowerInvariant()};request-id:{requestId};ts:{timestamp};";
    using var hmac = new System.Security.Cryptography.HMACSHA256(Encoding.UTF8.GetBytes(secret));
    var signature = Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes(manifest))).ToLowerInvariant();
    if (!MercadoPagoWebhook.Verify($"ts={timestamp},v1={signature}", requestId, dataId, secret)) throw new Exception("Valid webhook rejected");
    if (MercadoPagoWebhook.Verify($"ts={timestamp},v1={signature}", requestId + "x", dataId, secret)) throw new Exception("Tampered request accepted");
    return Task.CompletedTask;
});

var serialized = results.Select(JsonSerializer.Serialize).ToArray();
var failed = serialized.Count(x => x.Contains("\"FAIL\"", StringComparison.Ordinal));
File.WriteAllText(Path.Combine(output, "payment-test-results.json"), JsonSerializer.Serialize(new { total = results.Count, passed = results.Count - failed, failed, tests = results }, new JsonSerializerOptions { WriteIndented = true }));
return failed == 0 ? 0 : 1;

static HttpResponseMessage Json(HttpStatusCode status, string content) => new(status) { Content = new StringContent(content, Encoding.UTF8, "application/json") };

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
