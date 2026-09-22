using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using CajaClara.Core;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Imaging;
using QRCoder;
using Windows.Storage.Streams;

namespace CajaClara.Windows;

public sealed record RemoteMercadoPagoPayment(Guid PaymentIntentId, string ProviderOrderId, string ExternalReference,
    long AmountCents, string Status, string StatusDetail, string? QrData, DateTimeOffset UpdatedAt)
{
    public bool Paid => Status.Equals("processed", StringComparison.OrdinalIgnoreCase) &&
        (StatusDetail.Equals("processed", StringComparison.OrdinalIgnoreCase) ||
         StatusDetail.Equals("accredited", StringComparison.OrdinalIgnoreCase));
    public bool Terminal => Paid ||
        Status.Equals("canceled", StringComparison.OrdinalIgnoreCase) ||
        Status.Equals("refunded", StringComparison.OrdinalIgnoreCase) ||
        Status.Equals("expired", StringComparison.OrdinalIgnoreCase) ||
        Status.Equals("failed", StringComparison.OrdinalIgnoreCase);
}

public sealed class MercadoPagoRemoteClient(PosService pos)
{
    public bool DeviceLinked
    {
        get
        {
            try { return DeviceSecrets.Load() is not null; }
            catch { return false; }
        }
    }

    public async Task<PaymentIntent> CreateAsync(Actor actor, PaymentIntent intent, CancellationToken cancellationToken = default)
    {
        var remote = await SendAsync<RemoteMercadoPagoPayment>(HttpMethod.Post, "api/device/payments/mercadopago/orders",
            new { paymentIntentId = intent.Id, externalReference = intent.ExternalReference, amountCents = intent.AmountCents, description = "Venta Caja Clara" },
            cancellationToken);
        return Apply(actor, intent, remote);
    }

    public async Task<PaymentIntent> RefreshAsync(Actor actor, PaymentIntent intent, CancellationToken cancellationToken = default)
    {
        var remote = await SendAsync<RemoteMercadoPagoPayment>(HttpMethod.Get,
            "api/device/payments/mercadopago/orders/" + intent.Id, null, cancellationToken);
        return Apply(actor, intent, remote);
    }

    public async Task<PaymentIntent> CancelAsync(Actor actor, PaymentIntent intent, Guid idempotencyKey, CancellationToken cancellationToken = default)
    {
        var remote = await SendAsync<RemoteMercadoPagoPayment>(HttpMethod.Post,
            $"api/device/payments/mercadopago/orders/{intent.Id}/cancel/{idempotencyKey}", new { }, cancellationToken);
        return Apply(actor, intent, remote);
    }

    private PaymentIntent Apply(Actor actor, PaymentIntent local, RemoteMercadoPagoPayment remote)
    {
        if (remote.PaymentIntentId != local.Id || remote.ExternalReference != local.ExternalReference || remote.AmountCents != local.AmountCents)
            throw new BusinessException("La respuesta de Mercado Pago no coincide con el intento local.");
        if (string.IsNullOrWhiteSpace(remote.ProviderOrderId)) throw new BusinessException("Mercado Pago no devolvió el identificador de la order.");
        return pos.UpdateMercadoPagoIntent(actor, local.Id, local.Version, remote.ProviderOrderId, remote.Status,
            remote.Paid, $"Mercado Pago: {remote.Status} · {remote.StatusDetail}", remote.QrData);
    }

    private static async Task<T> SendAsync<T>(HttpMethod method, string relative, object? body, CancellationToken cancellationToken)
    {
        var settings = DeviceSecrets.Load() ?? throw new BusinessException("Vinculá esta caja con Caja Clara Control antes de usar Mercado Pago integrado.");
        if (!Uri.TryCreate(settings.Server, UriKind.Absolute, out var address)) throw new BusinessException("Servidor remoto inválido.");
        SyncClient.ValidateServer(address, true);
        using var http = new HttpClient(new HttpClientHandler { AllowAutoRedirect = false })
        {
            BaseAddress = address,
            Timeout = TimeSpan.FromSeconds(35)
        };
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", settings.Token);
        using var request = new HttpRequestMessage(method, relative);
        if (body is not null) request.Content = JsonContent.Create(body, options: Json.Options);
        using var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        var payload = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            string? detail = null;
            try
            {
                using var document = JsonDocument.Parse(payload);
                if (document.RootElement.TryGetProperty("error", out var item)) detail = item.GetString();
            }
            catch (JsonException) { }
            throw new BusinessException("Mercado Pago remoto: HTTP " + (int)response.StatusCode +
                (string.IsNullOrWhiteSpace(detail) ? "." : " · " + detail));
        }
        try { return Json.Read<T>(payload); }
        catch (Exception error) when (error is BusinessException or JsonException)
        { throw new BusinessException("El servidor devolvió una respuesta de pago inválida."); }
    }
}

public static class MercadoPagoQrImage
{
    public static async Task<Image> BuildAsync(string qrData)
    {
        if (string.IsNullOrWhiteSpace(qrData) || qrData.Length > 10000) throw new BusinessException("Mercado Pago no devolvió un QR válido.");
        using var generator = new QRCodeGenerator();
        using var data = generator.CreateQrCode(qrData, QRCodeGenerator.ECCLevel.M);
        using var png = new PngByteQRCode(data);
        var bytes = png.GetGraphic(8);
        using var stream = new InMemoryRandomAccessStream();
        using (var writer = new DataWriter(stream))
        {
            writer.WriteBytes(bytes);
            await writer.StoreAsync();
            await writer.FlushAsync();
        }
        stream.Seek(0);
        var bitmap = new BitmapImage();
        await bitmap.SetSourceAsync(stream);
        return new Image { Source = bitmap, Width = 280, Height = 280, Stretch = Microsoft.UI.Xaml.Media.Stretch.Uniform };
    }
}
