using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;

namespace CajaClara.Core;

public sealed record PairRequest(string Code, Guid BusinessId, Guid DeviceId, string DeviceName);
public sealed record PairResponse(string DeviceToken);
public sealed record EventBatch(Guid BusinessId, Guid DeviceId, SyncEnvelope[] Events);
public sealed record EventAcceptance(Guid[] Accepted);
public sealed record CommandResult(Guid CommandId, RemoteStatus Status, string Result);
public sealed record SyncHealth(string Status, DateTimeOffset? LastSuccess, string Detail);
public sealed class SyncClient(Store store, HttpClient client, string token)
{
    public SyncHealth Health { get; private set; } = new("NOT_STARTED", null, "Sin sincronización todavía.");
    public static void ValidateServer(Uri uri, bool allowLoopback = false)
    {
        if (uri.UserInfo.Length != 0 || uri.Query.Length != 0 || uri.Fragment.Length != 0 ||
            (uri.Scheme != Uri.UriSchemeHttps && !(allowLoopback && uri.IsLoopback && uri.Scheme == Uri.UriSchemeHttp)))
            throw new BusinessException("El servidor debe usar HTTPS. HTTP se permite solo en localhost de desarrollo.");
    }
    public async Task RunAsync(CancellationToken cancellationToken)
    {
        var failures = 0;
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                await OnceAsync(cancellationToken); failures = 0;
                await Task.Delay(TimeSpan.FromSeconds(8), cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { return; }
            catch (Exception e) when (e is HttpRequestException or TaskCanceledException or BusinessException or System.Text.Json.JsonException)
            {
                failures = Math.Min(failures + 1, 8);
                Health = Health with { Status = "OFFLINE_OR_ERROR", Detail = e is BusinessException ? e.Message : "No se pudo confirmar la sincronización. Las ventas locales siguen guardadas." };
                var delay = TimeSpan.FromSeconds(Math.Min(300, Math.Pow(2, failures) + Random.Shared.NextDouble() * 3));
                try { await Task.Delay(delay, cancellationToken); } catch (OperationCanceledException) { return; }
            }
        }
    }
    public async Task OnceAsync(CancellationToken cancellationToken = default)
    {
        var business = store.Read(tx => tx.All<Business>().Single());
        var events = store.PendingEvents().ToArray();
        using var request = Request(HttpMethod.Post, "api/device/events");
        request.Content = JsonContent.Create(new EventBatch(business.Id, business.DeviceId, events), options: Json.Options);
        using var response = await client.SendAsync(request, cancellationToken);
        await Ensure(response, cancellationToken);
        var accepted = await response.Content.ReadFromJsonAsync<EventAcceptance>(Json.Options, cancellationToken)
            ?? throw new BusinessException("El servidor no confirmó los eventos.");
        if (accepted.Accepted.Any(id => events.All(x => x.EventId != id))) throw new BusinessException("Respuesta de sincronización inválida.");
        store.Acknowledge(accepted.Accepted);
        using var commandsRequest = Request(HttpMethod.Get, "api/device/commands");
        using var commandsResponse = await client.SendAsync(commandsRequest, cancellationToken);
        await Ensure(commandsResponse, cancellationToken);
        var commands = await commandsResponse.Content.ReadFromJsonAsync<RemoteCommand[]>(Json.Options, cancellationToken) ?? [];
        var executor = new RemoteExecutor(store);
        foreach (var command in commands)
        {
            var completed = executor.ExecuteSafely(command);
            using var ack = Request(HttpMethod.Post, "api/device/commands/result");
            ack.Content = JsonContent.Create(new CommandResult(completed.Id, completed.Status, completed.Result), options: Json.Options);
            using var ackResponse = await client.SendAsync(ack, cancellationToken);
            await Ensure(ackResponse, cancellationToken); executor.Acknowledge(command.Id);
        }
        Health = new("SYNCED", store.Clock.GetUtcNow(), $"{accepted.Accepted.Length} eventos confirmados.");
    }
    private HttpRequestMessage Request(HttpMethod method, string path)
    {
        var request = new HttpRequestMessage(method, path);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token); return request;
    }
    private static async Task Ensure(HttpResponseMessage response, CancellationToken cancellationToken)
    {
        if (response.StatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
            throw new BusinessException("El dispositivo no está autorizado o fue revocado. Volvé a vincularlo.");
        if (response.StatusCode == HttpStatusCode.Conflict) throw new BusinessException("Hay un conflicto de sincronización. Se conservaron todos los eventos locales.");
        if (!response.IsSuccessStatusCode) { await response.Content.LoadIntoBufferAsync(cancellationToken); response.EnsureSuccessStatusCode(); }
    }
}
