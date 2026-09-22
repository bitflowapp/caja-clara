using System.Net;
using System.Security.Claims;
using System.Threading.RateLimiting;
using CajaClara.Backend;
using CajaClara.Core;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;

var management = args.Contains("--init") || args.Contains("--provision-json");
var builder = WebApplication.CreateBuilder(args.Where(x => x is not ("--init" or "--provision-json")).ToArray());
var data = Path.GetFullPath(Environment.GetEnvironmentVariable("CAJACLARA_DATA_DIR") ?? Path.Combine(builder.Environment.ContentRootPath, ".data"));
Directory.CreateDirectory(data);
var store = new CloudStore(Path.Combine(data, "cloud.sqlite"));
if (management)
{
    try
    {
        ProvisionRequest input;
        if (args.Contains("--provision-json")) input = Json.Read<ProvisionRequest>(Console.In.ReadToEnd());
        else
        {
            Console.Write("Nombre del comercio: "); var business = Console.ReadLine() ?? "";
            Console.Write("Usuario del dueño: "); var login = Console.ReadLine() ?? "";
            Console.Write("Nombre del dueño: "); var name = Console.ReadLine() ?? "";
            Console.Write("Contraseña nueva (12 o más caracteres): "); var secret = new System.Text.StringBuilder();
            while (true) { var key = Console.ReadKey(true); if (key.Key == ConsoleKey.Enter) break; if (key.Key == ConsoleKey.Backspace) { if (secret.Length > 0) secret.Length--; } else if (!char.IsControl(key.KeyChar)) secret.Append(key.KeyChar); }
            Console.WriteLine(); input = new(business, login, name, secret.ToString());
        }
        var owner = store.Provision(input); Console.WriteLine(Json.Write(new { owner.Id, owner.TenantId, owner.Login })); return 0;
    }
    catch (Exception e) when (e is BusinessException or CloudConflictException or System.Text.Json.JsonException)
    { Console.Error.WriteLine(e.Message); return 1; }
}
var development = builder.Environment.IsDevelopment();
builder.WebHost.ConfigureKestrel(options => options.Limits.MaxRequestBodySize = 4_000_000);
builder.Services.AddSingleton(store);
builder.Services.AddSingleton(new PaymentCloudStore(Path.Combine(data, "payments.sqlite")));
builder.Services.AddSingleton(new HttpClient(new SocketsHttpHandler
{
    AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate,
    AllowAutoRedirect = false,
    PooledConnectionLifetime = TimeSpan.FromMinutes(10)
}) { Timeout = TimeSpan.FromSeconds(30) });
builder.Services.AddSingleton<MercadoPagoGateway>();
builder.Services.ConfigureHttpJsonOptions(options => { foreach (var converter in Json.Options.Converters) options.SerializerOptions.Converters.Add(converter); });
var protection = builder.Services.AddDataProtection().SetApplicationName("LUNA.CajaClara.Cloud.v1").PersistKeysToFileSystem(new DirectoryInfo(Path.Combine(data, "keys")));
if (OperatingSystem.IsWindows()) protection.ProtectKeysWithDpapi();
builder.Services.AddAntiforgery(options =>
{
    options.HeaderName = "X-CSRF-TOKEN"; options.Cookie.Name = development ? "CajaClara.Anti.Dev" : "__Host-CajaClara.Anti";
    options.Cookie.HttpOnly = true; options.Cookie.SameSite = SameSiteMode.Strict; options.Cookie.Path = "/";
    options.Cookie.SecurePolicy = development ? CookieSecurePolicy.SameAsRequest : CookieSecurePolicy.Always;
});
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme).AddCookie(options =>
{
    options.Cookie.Name = development ? "CajaClara.Session.Dev" : "__Host-CajaClara.Session";
    options.Cookie.HttpOnly = true; options.Cookie.Path = "/"; options.Cookie.SameSite = SameSiteMode.Strict;
    options.Cookie.SecurePolicy = development ? CookieSecurePolicy.SameAsRequest : CookieSecurePolicy.Always;
    options.ExpireTimeSpan = TimeSpan.FromHours(8); options.SlidingExpiration = false;
    options.Events.OnRedirectToLogin = context => { context.Response.StatusCode = 401; return Task.CompletedTask; };
    options.Events.OnRedirectToAccessDenied = context => { context.Response.StatusCode = 403; return Task.CompletedTask; };
    options.Events.OnValidatePrincipal = context =>
    {
        var id = context.Principal?.FindFirstValue(ClaimTypes.NameIdentifier); var version = context.Principal?.FindFirstValue("session_version");
        if (!Guid.TryParse(id, out var parsed) || store.Owner(parsed) is not CloudOwner owner || owner.SessionVersion.ToString() != version) context.RejectPrincipal();
        return Task.CompletedTask;
    };
});
builder.Services.AddAuthorization();
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = 429;
    options.AddPolicy("credentials", context => RateLimitPartition.GetFixedWindowLimiter(context.Connection.RemoteIpAddress?.ToString() ?? "unknown", _ => new FixedWindowRateLimiterOptions { PermitLimit = 20, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
    options.AddPolicy("device", context => RateLimitPartition.GetFixedWindowLimiter(context.Connection.RemoteIpAddress?.ToString() ?? "unknown", _ => new FixedWindowRateLimiterOptions { PermitLimit = 240, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
});
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    var trusted = Environment.GetEnvironmentVariable("CAJACLARA_TRUSTED_PROXY");
    if (!string.IsNullOrWhiteSpace(trusted) && IPAddress.TryParse(trusted, out var address)) options.KnownProxies.Add(address);
});
var app = builder.Build();
var mercadoPago = app.Services.GetRequiredService<MercadoPagoGateway>();
app.UseForwardedHeaders();
if (!development) app.UseHsts();
app.Use(async (context, next) =>
{
    context.Response.Headers.XContentTypeOptions = "nosniff";
    context.Response.Headers["Referrer-Policy"] = "no-referrer";
    context.Response.Headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
    context.Response.Headers.ContentSecurityPolicy = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'";
    if (context.Request.Path.StartsWithSegments("/api")) context.Response.Headers.CacheControl = "no-store";
    if (!development && !context.Request.IsHttps && context.Request.Path != "/health")
    { context.Response.StatusCode = 426; await context.Response.WriteAsJsonAsync(new { error = "HTTPS obligatorio. Configurá TLS y el proxy de confianza." }); return; }
    try { await next(); }
    catch (Exception e) when (e is BusinessException or CloudConflictException or CloudUnauthorizedException or AntiforgeryValidationException or System.Text.Json.JsonException)
    {
        if (context.Response.HasStarted) throw;
        context.Response.StatusCode = e is CloudUnauthorizedException ? 401 : e is CloudConflictException ? 409 : e is AntiforgeryValidationException ? 403 : 400;
        await context.Response.WriteAsJsonAsync(new { error = e is BusinessException or CloudConflictException ? e.Message : "Solicitud no autorizada o inválida." });
    }
    catch (Exception e)
    {
        app.Logger.LogError("Request failed. Type={Type} Trace={Trace}", e.GetType().Name, context.TraceIdentifier);
        if (context.Response.HasStarted) throw;
        context.Response.StatusCode = 500; await context.Response.WriteAsJsonAsync(new { error = "La operación no se completó. No se confirmaron cambios.", trace = context.TraceIdentifier });
    }
});
app.UseDefaultFiles(); app.UseStaticFiles(); app.UseRouting(); app.UseRateLimiter(); app.UseAuthentication(); app.UseAuthorization();
app.Use(async (context, next) =>
{
    if (context.Request.Method is not ("GET" or "HEAD" or "OPTIONS") && (context.Request.Path.StartsWithSegments("/api/owner") || context.Request.Path.StartsWithSegments("/api/auth")))
        await context.RequestServices.GetRequiredService<IAntiforgery>().ValidateRequestAsync(context);
    await next();
});
CloudOwner Owner(HttpContext context)
{
    if (!Guid.TryParse(context.User.FindFirstValue(ClaimTypes.NameIdentifier), out var id)) throw new CloudUnauthorizedException();
    return store.Owner(id) ?? throw new CloudUnauthorizedException();
}
CloudDevice Device(HttpContext context)
{
    var header = context.Request.Headers.Authorization.ToString();
    return header.StartsWith("Bearer ", StringComparison.Ordinal) ? store.Device(header[7..]) ?? throw new CloudUnauthorizedException() : throw new CloudUnauthorizedException();
}
app.MapGet("/health", () => Results.Ok(new { status = "up", version = "0.2.0" }));
app.MapGet("/api/auth/csrf", (HttpContext context, IAntiforgery antiforgery) => Results.Ok(new { token = antiforgery.GetAndStoreTokens(context).RequestToken }));
app.MapPost("/api/auth/login", async (HttpContext context, OwnerLogin input) =>
{
    var owner = await Task.Run(() => store.Authenticate(input.Login, input.Password));
    if (owner is null) return Results.Json(new { error = "Credenciales inválidas o cuenta temporalmente bloqueada." }, statusCode: 401);
    var claims = new[] { new Claim(ClaimTypes.NameIdentifier, owner.Id.ToString()), new Claim(ClaimTypes.Name, owner.Name), new Claim(ClaimTypes.Role, owner.Role.ToString()), new Claim("tenant", owner.TenantId.ToString()), new Claim("session_version", owner.SessionVersion.ToString()) };
    await context.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, new ClaimsPrincipal(new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme)), new AuthenticationProperties { IsPersistent = false, ExpiresUtc = DateTimeOffset.UtcNow.AddHours(8) });
    return Results.Ok(new { owner.Name, owner.Role });
}).RequireRateLimiting("credentials");
app.MapPost("/api/auth/logout", async (HttpContext context) => { await context.SignOutAsync(); return Results.NoContent(); }).RequireAuthorization();
app.MapGet("/api/auth/me", (HttpContext context) => { var owner = Owner(context); return Results.Ok(new { owner.Name, owner.Role }); }).RequireAuthorization();
app.MapPost("/api/pair", (PairRequest input) => Results.Ok(store.Pair(input))).RequireRateLimiting("credentials");
var devices = app.MapGroup("/api/device").RequireRateLimiting("device");
devices.MapPost("/events", (HttpContext context, EventBatch input) => Results.Ok(store.Accept(Device(context), input)));
devices.MapGet("/commands", (HttpContext context) => Results.Ok(store.Pending(Device(context))));
devices.MapPost("/commands/result", (HttpContext context, CommandResult input) => { store.Acknowledge(Device(context), input); return Results.NoContent(); });
devices.MapPost("/payments/mercadopago/orders", async (HttpContext context, MercadoPagoPaymentRequest input, CancellationToken cancellationToken)
    => Results.Ok(await mercadoPago.CreateAsync(Device(context), input, cancellationToken)));
devices.MapGet("/payments/mercadopago/orders/{id:guid}", async (HttpContext context, Guid id, CancellationToken cancellationToken)
    => Results.Ok(await mercadoPago.RefreshAsync(Device(context), id, cancellationToken)));
devices.MapPost("/payments/mercadopago/orders/{id:guid}/cancel/{idempotencyKey:guid}", async (HttpContext context, Guid id, Guid idempotencyKey, CancellationToken cancellationToken)
    => Results.Ok(await mercadoPago.CancelAsync(Device(context), id, idempotencyKey, cancellationToken)));

app.MapGet("/api/integrations/mercadopago/callback", async (string? code, string? state, string? error, CancellationToken cancellationToken) =>
{
    if (!string.IsNullOrWhiteSpace(error)) return Results.Redirect("/?mercadopago=denied");
    if (string.IsNullOrWhiteSpace(code) || string.IsNullOrWhiteSpace(state)) return Results.Redirect("/?mercadopago=invalid");
    await mercadoPago.CompleteAsync(code, state, cancellationToken);
    return Results.Redirect("/?mercadopago=connected");
});
app.MapPost("/api/integrations/mercadopago/webhook", async (HttpContext context, CancellationToken cancellationToken) =>
{
    var signature = context.Request.Headers["x-signature"].ToString();
    var requestId = context.Request.Headers["x-request-id"].ToString();
    var providerId = context.Request.Query["data.id"].ToString();
    if (string.IsNullOrWhiteSpace(providerId) && context.Request.ContentLength is > 0 and <= 100000)
    {
        using var document = await System.Text.Json.JsonDocument.ParseAsync(context.Request.Body, cancellationToken: cancellationToken);
        if (document.RootElement.TryGetProperty("data", out var payload) && payload.ValueKind == System.Text.Json.JsonValueKind.Object &&
            payload.TryGetProperty("id", out var id)) providerId = id.ValueKind == System.Text.Json.JsonValueKind.String ? id.GetString() ?? "" : id.GetRawText();
    }
    if (!mercadoPago.VerifyWebhook(signature, requestId, providerId)) return Results.Unauthorized();
    await mercadoPago.ProcessWebhookAsync(providerId, cancellationToken);
    return Results.NoContent();
}).RequireRateLimiting("device");

var ownerApi = app.MapGroup("/api/owner").RequireAuthorization();
ownerApi.MapGet("/dashboard", (HttpContext context, DateTimeOffset from, DateTimeOffset to) => Results.Ok(store.Dashboard(Owner(context), from, to)));
ownerApi.MapGet("/integrations/mercadopago", (HttpContext context) => Results.Ok(mercadoPago.Status(Owner(context))));
ownerApi.MapPost("/integrations/mercadopago/connect", (HttpContext context) =>
    Results.Ok(new { authorizationUrl = mercadoPago.Start(Owner(context)).ToString() }));
ownerApi.MapDelete("/integrations/mercadopago", (HttpContext context) => { mercadoPago.Disconnect(Owner(context)); return Results.NoContent(); });
ownerApi.MapPost("/pair-code", (HttpContext context) => Results.Ok(new { code = store.CreatePairCode(Owner(context)), expiresInSeconds = 300 }));
ownerApi.MapPost("/commands", (HttpContext context, CreateCommand command) => Results.Ok(store.Enqueue(Owner(context), command)));
ownerApi.MapPost("/devices/{id:guid}/revoke", (HttpContext context, Guid id) => { store.Revoke(Owner(context), id); return Results.NoContent(); });
app.MapFallbackToFile("index.html");
await app.RunAsync();
return 0;
