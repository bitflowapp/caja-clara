using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using CajaClara.Core;

namespace CajaClara.Payments;

public sealed record MercadoPagoAppOptions(string ClientId, string ClientSecret, Uri RedirectUri)
{
    public void Validate()
    {
        if (string.IsNullOrWhiteSpace(ClientId) || string.IsNullOrWhiteSpace(ClientSecret))
            throw new BusinessException("Faltan credenciales de aplicación de Mercado Pago.");
        if (RedirectUri.Scheme != Uri.UriSchemeHttps && !RedirectUri.IsLoopback)
            throw new BusinessException("La Redirect URI de Mercado Pago debe usar HTTPS.");
    }
}
public sealed record MercadoPagoSellerToken(
    string AccessToken,
    string RefreshToken,
    long UserId,
    int ExpiresIn,
    string Scope,
    bool LiveMode,
    DateTimeOffset ObtainedAt)
{
    public DateTimeOffset ExpiresAt => ObtainedAt.AddSeconds(Math.Max(60, ExpiresIn));
    public bool NeedsRefresh(DateTimeOffset now) => ExpiresAt <= now.AddMinutes(10);
}
public sealed record MercadoPagoPkce(string Verifier, string Challenge);
public sealed record MercadoPagoQrOrder(
    string Id,
    string ExternalReference,
    string Status,
    string StatusDetail,
    string Currency,
    decimal TotalAmount,
    string? QrData,
    string RawJson)
{
    public bool IsPaid => Status.Equals("accredited", StringComparison.OrdinalIgnoreCase) ||
                          Status.Equals("processed", StringComparison.OrdinalIgnoreCase);
    public bool IsTerminal => IsPaid || Status is "canceled" or "refunded" or "expired" or "failed";
}
public sealed record MercadoPagoCreateQr(
    Guid IdempotencyKey,
    string ExternalReference,
    string ExternalPosId,
    long AmountCents,
    string Description,
    TimeSpan? Expiration = null);

public sealed class MercadoPagoOAuthClient(HttpClient http, TimeProvider? clock = null)
{
    private readonly TimeProvider time = clock ?? TimeProvider.System;
    private static readonly Uri TokenEndpoint = new("https://api.mercadopago.com/oauth/token");
    private static readonly Uri AuthorizationEndpoint = new("https://auth.mercadopago.com.ar/authorization");

    public static MercadoPagoPkce CreatePkce()
    {
        var bytes = RandomNumberGenerator.GetBytes(48);
        var verifier = Base64Url(bytes);
        var challenge = Base64Url(SHA256.HashData(Encoding.ASCII.GetBytes(verifier)));
        return new(verifier, challenge);
    }

    public static Uri AuthorizationUri(MercadoPagoAppOptions options, string state, MercadoPagoPkce pkce)
    {
        options.Validate();
        if (state.Length is < 20 or > 200) throw new BusinessException("State OAuth inválido.");
        if (pkce.Verifier.Length is < 43 or > 128) throw new BusinessException("PKCE inválido.");
        var query = new Dictionary<string, string>
        {
            ["response_type"] = "code",
            ["client_id"] = options.ClientId,
            ["redirect_uri"] = options.RedirectUri.ToString(),
            ["state"] = state,
            ["code_challenge"] = pkce.Challenge,
            ["code_challenge_method"] = "S256"
        };
        return new Uri(AuthorizationEndpoint + "?" + string.Join("&", query.Select(x =>
            Uri.EscapeDataString(x.Key) + "=" + Uri.EscapeDataString(x.Value))));
    }

    public Task<MercadoPagoSellerToken> ExchangeCodeAsync(MercadoPagoAppOptions options, string code, string verifier, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(code) || verifier.Length is < 43 or > 128) throw new BusinessException("Código OAuth/PKCE inválido.");
        return TokenAsync(options, new Dictionary<string, object?>
        {
            ["grant_type"] = "authorization_code",
            ["code"] = code,
            ["redirect_uri"] = options.RedirectUri.ToString(),
            ["code_verifier"] = verifier
        }, cancellationToken);
    }

    public Task<MercadoPagoSellerToken> RefreshAsync(MercadoPagoAppOptions options, string refreshToken, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(refreshToken)) throw new BusinessException("Refresh token de Mercado Pago ausente.");
        return TokenAsync(options, new Dictionary<string, object?> { ["grant_type"] = "refresh_token", ["refresh_token"] = refreshToken }, cancellationToken);
    }

    private async Task<MercadoPagoSellerToken> TokenAsync(MercadoPagoAppOptions options, Dictionary<string, object?> body, CancellationToken cancellationToken)
    {
        options.Validate();
        body["client_id"] = options.ClientId; body["client_secret"] = options.ClientSecret;
        using var request = new HttpRequestMessage(HttpMethod.Post, TokenEndpoint)
        { Content = JsonContent.Create(body, options: Json.Options) };
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        using var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        var payload = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode) throw ProviderError("OAuth", response.StatusCode, payload);
        OAuthResponse parsed;
        try { parsed = JsonSerializer.Deserialize<OAuthResponse>(payload, Json.Options) ?? throw new JsonException(); }
        catch (JsonException) { throw new BusinessException("Mercado Pago devolvió una respuesta OAuth inválida."); }
        if (string.IsNullOrWhiteSpace(parsed.AccessToken) || string.IsNullOrWhiteSpace(parsed.RefreshToken) || parsed.UserId <= 0)
            throw new BusinessException("Mercado Pago devolvió credenciales OAuth incompletas.");
        return new(parsed.AccessToken, parsed.RefreshToken, parsed.UserId, parsed.ExpiresIn, parsed.Scope ?? "", parsed.LiveMode, time.GetUtcNow());
    }

    private sealed record OAuthResponse(
        [property: JsonPropertyName("access_token")] string AccessToken,
        [property: JsonPropertyName("refresh_token")] string RefreshToken,
        [property: JsonPropertyName("user_id")] long UserId,
        [property: JsonPropertyName("expires_in")] int ExpiresIn,
        [property: JsonPropertyName("scope")] string? Scope,
        [property: JsonPropertyName("live_mode")] bool LiveMode);

    private static string Base64Url(byte[] bytes) => Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    private static BusinessException ProviderError(string operation, HttpStatusCode status, string payload)
    {
        string? message = null;
        try
        {
            using var doc = JsonDocument.Parse(payload);
            if (doc.RootElement.TryGetProperty("message", out var item)) message = item.GetString();
            else if (doc.RootElement.TryGetProperty("error", out item)) message = item.GetString();
        }
        catch (JsonException) { }
        return new($"Mercado Pago {operation}: HTTP {(int)status}" + (string.IsNullOrWhiteSpace(message) ? "." : " · " + message));
    }
}

public sealed class MercadoPagoOrdersClient(HttpClient http)
{
    private static readonly Uri Orders = new("https://api.mercadopago.com/v1/orders");

    public async Task<MercadoPagoQrOrder> CreateQrAsync(string accessToken, MercadoPagoCreateQr input, CancellationToken cancellationToken = default)
    {
        ValidateToken(accessToken); Validate(input);
        var amount = Amount(input.AmountCents);
        var mode = "dynamic";
        var body = new
        {
            type = "qr",
            total_amount = amount,
            description = input.Description,
            external_reference = input.ExternalReference,
            expiration_time = IsoDuration(input.Expiration ?? TimeSpan.FromMinutes(15)),
            config = new { qr = new { external_pos_id = input.ExternalPosId, mode } },
            transactions = new { payments = new[] { new { amount } } }
        };
        using var request = Authorized(HttpMethod.Post, Orders, accessToken);
        request.Headers.TryAddWithoutValidation("X-Idempotency-Key", input.IdempotencyKey.ToString());
        request.Content = JsonContent.Create(body, options: Json.Options);
        using var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        return await ParseOrder(response, input.ExternalReference, input.AmountCents, cancellationToken);
    }

    public async Task<MercadoPagoQrOrder> GetAsync(string accessToken, string orderId, string expectedReference, long expectedAmountCents, CancellationToken cancellationToken = default)
    {
        ValidateToken(accessToken);
        if (!ValidId(orderId)) throw new BusinessException("ID de order de Mercado Pago inválido.");
        using var response = await http.SendAsync(Authorized(HttpMethod.Get, new Uri(Orders + "/" + Uri.EscapeDataString(orderId)), accessToken),
            HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        return await ParseOrder(response, expectedReference, expectedAmountCents, cancellationToken);
    }

    public async Task<MercadoPagoQrOrder> CancelAsync(string accessToken, string orderId, Guid idempotencyKey, string expectedReference, long expectedAmountCents, CancellationToken cancellationToken = default)
    {
        ValidateToken(accessToken);
        if (!ValidId(orderId)) throw new BusinessException("ID de order de Mercado Pago inválido.");
        using var request = Authorized(HttpMethod.Post, new Uri(Orders + "/" + Uri.EscapeDataString(orderId) + "/cancel"), accessToken);
        request.Headers.TryAddWithoutValidation("X-Idempotency-Key", idempotencyKey.ToString());
        request.Content = JsonContent.Create(new { }, options: Json.Options);
        using var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        return await ParseOrder(response, expectedReference, expectedAmountCents, cancellationToken);
    }

    private static HttpRequestMessage Authorized(HttpMethod method, Uri uri, string token)
    {
        var request = new HttpRequestMessage(method, uri);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        return request;
    }

    private static async Task<MercadoPagoQrOrder> ParseOrder(HttpResponseMessage response, string expectedReference, long expectedAmountCents, CancellationToken cancellationToken)
    {
        var payload = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode) throw Error(response.StatusCode, payload);
        try
        {
            using var doc = JsonDocument.Parse(payload);
            var root = doc.RootElement;
            var id = Text(root, "id"); var reference = Text(root, "external_reference");
            var status = Text(root, "status"); var detail = Text(root, "status_detail");
            var currency = Text(root, "currency"); var total = Decimal(root, "total_amount");
            string? qr = null;
            if (root.TryGetProperty("type_response", out var responseType) && responseType.ValueKind == JsonValueKind.Object &&
                responseType.TryGetProperty("qr_data", out var qrElement)) qr = qrElement.GetString();
            if (string.IsNullOrWhiteSpace(id) || string.IsNullOrWhiteSpace(status)) throw new BusinessException("Order de Mercado Pago incompleta.");
            if (!reference.Equals(expectedReference, StringComparison.Ordinal)) throw new BusinessException("La referencia de Mercado Pago no coincide con la venta.");
            if (currency != "ARS") throw new BusinessException("La order de Mercado Pago no está expresada en ARS.");
            if (Money.Cents(total) != expectedAmountCents) throw new BusinessException("El importe confirmado por Mercado Pago no coincide con la venta.");
            return new(id, reference, status.ToLowerInvariant(), detail, currency, total, qr, payload);
        }
        catch (JsonException) { throw new BusinessException("Mercado Pago devolvió una order inválida."); }
    }

    private static void Validate(MercadoPagoCreateQr input)
    {
        if (input.IdempotencyKey == Guid.Empty) throw new BusinessException("Idempotency key de pago inválida.");
        Money.Valid(input.AmountCents, false);
        if (input.ExternalReference.Length is < 1 or > 64 || input.ExternalReference.Any(c => !char.IsAsciiLetterOrDigit(c) && c is not '-' and not '_'))
            throw new BusinessException("Referencia externa inválida para Mercado Pago.");
        if (input.ExternalPosId.Length is < 1 or > 40) throw new BusinessException("Identificador de caja Mercado Pago inválido.");
        if (input.Description.Length is < 1 or > 150) throw new BusinessException("Descripción de pago inválida.");
        if (input.Expiration is { } duration && (duration < TimeSpan.FromMinutes(1) || duration > TimeSpan.FromDays(1))) throw new BusinessException("Expiración QR inválida.");
    }
    private static void ValidateToken(string token) { if (string.IsNullOrWhiteSpace(token) || token.Length < 20) throw new BusinessException("Access Token de Mercado Pago inválido."); }
    private static bool ValidId(string id) => id.Length is > 3 and <= 100 && id.All(c => char.IsAsciiLetterOrDigit(c) || c is '-' or '_');
    private static string Amount(long cents) => (cents / 100m).ToString("0.00", CultureInfo.InvariantCulture);
    private static string IsoDuration(TimeSpan value) => "PT" + Math.Ceiling(value.TotalMinutes).ToString(CultureInfo.InvariantCulture) + "M";
    private static string Text(JsonElement root, string name) => root.TryGetProperty(name, out var value) ? value.GetString() ?? "" : "";
    private static decimal Decimal(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out var value)) throw new BusinessException("Mercado Pago no devolvió el importe.");
        if (value.ValueKind == JsonValueKind.Number && value.TryGetDecimal(out var number)) return number;
        if (value.ValueKind == JsonValueKind.String && decimal.TryParse(value.GetString(), NumberStyles.Number, CultureInfo.InvariantCulture, out number)) return number;
        throw new BusinessException("Importe inválido en respuesta de Mercado Pago.");
    }
    private static BusinessException Error(HttpStatusCode status, string payload)
    {
        string? detail = null;
        try
        {
            using var doc = JsonDocument.Parse(payload);
            if (doc.RootElement.TryGetProperty("message", out var item)) detail = item.GetString();
            else if (doc.RootElement.TryGetProperty("error", out item)) detail = item.GetString();
        }
        catch (JsonException) { }
        return new($"Mercado Pago Orders: HTTP {(int)status}" + (string.IsNullOrWhiteSpace(detail) ? "." : " · " + detail));
    }
}

public static class MercadoPagoWebhook
{
    public static bool Verify(string xSignature, string xRequestId, string dataId, string secret)
    {
        if (string.IsNullOrWhiteSpace(xSignature) || string.IsNullOrWhiteSpace(xRequestId) ||
            string.IsNullOrWhiteSpace(dataId) || string.IsNullOrWhiteSpace(secret)) return false;
        string? timestamp = null, received = null;
        foreach (var part in xSignature.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var pair = part.Split('=', 2, StringSplitOptions.TrimEntries);
            if (pair.Length != 2) continue;
            if (pair[0] == "ts") timestamp = pair[1];
            else if (pair[0] == "v1") received = pair[1];
        }
        if (string.IsNullOrWhiteSpace(timestamp) || string.IsNullOrWhiteSpace(received)) return false;
        var manifest = $"id:{dataId.ToLowerInvariant()};request-id:{xRequestId};ts:{timestamp};";
        var expected = Convert.ToHexString(HMACSHA256.HashData(Encoding.UTF8.GetBytes(secret), Encoding.UTF8.GetBytes(manifest))).ToLowerInvariant();
        byte[] left, right;
        try { left = Convert.FromHexString(expected); right = Convert.FromHexString(received); }
        catch (FormatException) { return false; }
        return left.Length == right.Length && CryptographicOperations.FixedTimeEquals(left, right);
    }
}
