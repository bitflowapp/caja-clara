using System.Security.Cryptography;
using CajaClara.Core;
using CajaClara.Payments;
using Microsoft.AspNetCore.DataProtection;

namespace CajaClara.Backend;

public sealed record MercadoPagoBackendConfig(MercadoPagoAppOptions? App, string? WebhookSecret)
{
    public bool Configured => App is not null;
    public static MercadoPagoBackendConfig FromEnvironment()
    {
        var client = Environment.GetEnvironmentVariable("CAJACLARA_MP_CLIENT_ID");
        var secret = Environment.GetEnvironmentVariable("CAJACLARA_MP_CLIENT_SECRET");
        var redirect = Environment.GetEnvironmentVariable("CAJACLARA_MP_REDIRECT_URI");
        MercadoPagoAppOptions? app = null;
        if (!string.IsNullOrWhiteSpace(client) && !string.IsNullOrWhiteSpace(secret) &&
            Uri.TryCreate(redirect, UriKind.Absolute, out var redirectUri))
        {
            app = new(client, secret, redirectUri);
            app.Validate();
        }
        return new(app, Environment.GetEnvironmentVariable("CAJACLARA_MP_WEBHOOK_SECRET"));
    }
}

public sealed record MercadoPagoConnectionStatus(bool BackendConfigured, bool Connected, long? ProviderUserId, DateTimeOffset? UpdatedAt, PaymentPosBinding[] PosBindings);
public sealed record MercadoPagoPosBindingRequest(string ExternalPosId);
public sealed record MercadoPagoPaymentRequest(Guid PaymentIntentId, string ExternalReference, long AmountCents, string Description);
public sealed record MercadoPagoPaymentView(Guid PaymentIntentId, string ProviderOrderId, string ExternalReference, long AmountCents, string Status, string StatusDetail, string? QrData, DateTimeOffset UpdatedAt)
{
    public bool Paid => Status.Equals("processed", StringComparison.OrdinalIgnoreCase) &&
        (StatusDetail.Equals("processed", StringComparison.OrdinalIgnoreCase) || StatusDetail.Equals("accredited", StringComparison.OrdinalIgnoreCase));
    public bool Terminal => Paid || Status.Equals("canceled", StringComparison.OrdinalIgnoreCase) ||
        Status.Equals("refunded", StringComparison.OrdinalIgnoreCase) || Status.Equals("expired", StringComparison.OrdinalIgnoreCase) ||
        Status.Equals("failed", StringComparison.OrdinalIgnoreCase);
    public static MercadoPagoPaymentView From(CloudPaymentOrder value) => new(value.Id, value.ProviderOrderId ?? "", value.ExternalReference, value.AmountCents, value.Status, value.StatusDetail, value.QrData, value.UpdatedAt);
}

public sealed class MercadoPagoGateway
{
    private readonly PaymentCloudStore store;
    private readonly MercadoPagoBackendConfig config;
    private readonly IDataProtector tokens;
    private readonly IDataProtector oauthContext;
    private readonly MercadoPagoOAuthClient oauth;
    private readonly MercadoPagoOrdersClient orders;

    public MercadoPagoGateway(PaymentCloudStore store, IDataProtectionProvider protection, HttpClient http)
    {
        this.store = store;
        config = MercadoPagoBackendConfig.FromEnvironment();
        tokens = protection.CreateProtector("LUNA.CajaClara.MercadoPago.Token.v1");
        oauthContext = protection.CreateProtector("LUNA.CajaClara.MercadoPago.OAuth.v1");
        oauth = new(http);
        orders = new(http);
    }

    public MercadoPagoConnectionStatus Status(CloudOwner owner)
    {
        var current = store.Connection(owner.TenantId);
        return new(config.Configured, current is not null, current?.ProviderUserId, current?.UpdatedAt, store.PosBindings(owner.TenantId));
    }

    public Uri Start(CloudOwner owner)
    {
        var app = RequireConfigured();
        var pkce = MercadoPagoOAuthClient.CreatePkce();
        var state = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        store.SaveOauthState(owner, Json.Hash(state), oauthContext.Protect(pkce.Verifier), DateTimeOffset.UtcNow.AddMinutes(10));
        return MercadoPagoOAuthClient.AuthorizationUri(app, state, pkce);
    }

    public async Task<PaymentOauthContext> CompleteAsync(string code, string state, CancellationToken cancellationToken = default)
    {
        var app = RequireConfigured();
        if (string.IsNullOrWhiteSpace(state) || state.Length is < 32 or > 200) throw new CloudUnauthorizedException();
        var context = store.ConsumeOauthState(Json.Hash(state));
        string verifier;
        try { verifier = oauthContext.Unprotect(context.ProtectedVerifier); }
        catch (System.Security.Cryptography.CryptographicException) { throw new CloudUnauthorizedException(); }
        var token = await oauth.ExchangeCodeAsync(app, code, verifier, cancellationToken);
        store.SaveConnection(context.TenantId, context.OwnerId, token.UserId, tokens.Protect(Json.Write(token)));
        return context;
    }

    public void Disconnect(CloudOwner owner) => store.RemoveConnection(owner);

    public PaymentPosBinding BindPos(CloudOwner owner, CloudDevice device, MercadoPagoPosBindingRequest input)
    {
        if (device.TenantId != owner.TenantId) throw new CloudUnauthorizedException();
        return store.SavePosBinding(owner, device.Id, input.ExternalPosId);
    }

    public async Task<MercadoPagoPaymentView> CreateAsync(CloudDevice device, MercadoPagoPaymentRequest input, CancellationToken cancellationToken = default)
    {
        Validate(input);
        var existing = store.OrderByIdempotency(device.TenantId, input.PaymentIntentId);
        if (existing is not null)
        {
            if (existing.DeviceId != device.Id || existing.Id != input.PaymentIntentId || existing.ExternalReference != input.ExternalReference || existing.AmountCents != input.AmountCents)
                throw new CloudConflictException("El intento de pago ya existe con otros datos.");
            return MercadoPagoPaymentView.From(existing);
        }
        var token = await AccessTokenAsync(device.TenantId, device.Id, cancellationToken);
        var provider = await orders.CreateQrAsync(token.AccessToken, new(
            input.PaymentIntentId,
            input.ExternalReference,
            (store.PosBinding(device.TenantId, device.Id) ?? throw new BusinessException("Configurá el external_pos_id de Mercado Pago para esta caja desde Caja Clara Control.")).ExternalPosId,
            input.AmountCents,
            input.Description), cancellationToken);
        var saved = store.SaveOrder(device, input.PaymentIntentId, input.PaymentIntentId, input.ExternalReference, input.AmountCents,
            provider.Id, provider.Status, provider.StatusDetail, provider.QrData);
        return MercadoPagoPaymentView.From(saved);
    }

    public async Task<MercadoPagoPaymentView> RefreshAsync(CloudDevice device, Guid id, CancellationToken cancellationToken = default)
    {
        var existing = RequireOrder(device, id);
        var token = await AccessTokenAsync(device.TenantId, device.Id, cancellationToken);
        var provider = await orders.GetAsync(token.AccessToken, existing.ProviderOrderId!, existing.ExternalReference, existing.AmountCents, cancellationToken);
        return MercadoPagoPaymentView.From(store.UpdateOrder(existing, provider.Status, provider.StatusDetail, provider.QrData, device.Id));
    }

    public async Task<MercadoPagoPaymentView> CancelAsync(CloudDevice device, Guid id, Guid idempotencyKey, CancellationToken cancellationToken = default)
    {
        if (idempotencyKey == Guid.Empty) throw new BusinessException("Idempotency key de cancelación inválida.");
        var existing = RequireOrder(device, id);
        var token = await AccessTokenAsync(device.TenantId, device.Id, cancellationToken);
        var provider = await orders.CancelAsync(token.AccessToken, existing.ProviderOrderId!, idempotencyKey, existing.ExternalReference, existing.AmountCents, cancellationToken);
        return MercadoPagoPaymentView.From(store.UpdateOrder(existing, provider.Status, provider.StatusDetail, provider.QrData, device.Id));
    }

    public async Task<bool> ProcessWebhookAsync(string providerOrderId, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(providerOrderId)) return false;
        var existing = store.OrderByProviderId(providerOrderId);
        if (existing is null) return false;
        var token = await AccessTokenAsync(existing.TenantId, existing.DeviceId, cancellationToken);
        var provider = await orders.GetAsync(token.AccessToken, providerOrderId, existing.ExternalReference, existing.AmountCents, cancellationToken);
        store.UpdateOrder(existing, provider.Status, provider.StatusDetail, provider.QrData, existing.DeviceId);
        return true;
    }

    public bool VerifyWebhook(string signature, string requestId, string providerOrderId)
        => !string.IsNullOrWhiteSpace(config.WebhookSecret) && MercadoPagoWebhook.Verify(signature, requestId, providerOrderId, config.WebhookSecret);

    private CloudPaymentOrder RequireOrder(CloudDevice device, Guid id)
    {
        if (id == Guid.Empty) throw new BusinessException("Intento de pago inválido.");
        var value = store.OrderById(device.TenantId, id) ?? throw new BusinessException("Intento de pago inexistente.");
        if (value.DeviceId != device.Id) throw new CloudUnauthorizedException();
        if (string.IsNullOrWhiteSpace(value.ProviderOrderId)) throw new BusinessException("El intento todavía no tiene una order de Mercado Pago.");
        return value;
    }

    private async Task<MercadoPagoSellerToken> AccessTokenAsync(Guid tenantId, Guid actorId, CancellationToken cancellationToken)
    {
        var app = RequireConfigured();
        var connection = store.Connection(tenantId) ?? throw new BusinessException("Mercado Pago no está vinculado para este comercio.");
        MercadoPagoSellerToken token;
        try { token = Json.Read<MercadoPagoSellerToken>(tokens.Unprotect(connection.ProtectedToken)); }
        catch (Exception error) when (error is System.Security.Cryptography.CryptographicException or System.Text.Json.JsonException)
        { throw new BusinessException("No se pudo abrir la credencial protegida de Mercado Pago."); }
        if (!token.NeedsRefresh(DateTimeOffset.UtcNow)) return token;
        var refreshed = await oauth.RefreshAsync(app, token.RefreshToken, cancellationToken);
        store.SaveConnection(tenantId, actorId, refreshed.UserId, tokens.Protect(Json.Write(refreshed)));
        return refreshed;
    }

    private MercadoPagoAppOptions RequireConfigured()
        => config.App ?? throw new BusinessException("Mercado Pago no está configurado en el servidor. Definí las credenciales de aplicación y Redirect URI.");

    private static void Validate(MercadoPagoPaymentRequest input)
    {
        if (input.PaymentIntentId == Guid.Empty) throw new BusinessException("Intento de pago inválido.");
        Money.Valid(input.AmountCents, false);
        if (input.ExternalReference.Length is < 1 or > 64 ||
            input.ExternalReference.Any(c => !char.IsAsciiLetterOrDigit(c) && c is not '-' and not '_'))
            throw new BusinessException("Referencia externa inválida.");
        if (input.Description.Length is < 1 or > 150) throw new BusinessException("Descripción de pago inválida.");
    }
}
