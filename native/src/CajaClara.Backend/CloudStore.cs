using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using CajaClara.Core;
using Microsoft.Data.Sqlite;

namespace CajaClara.Backend;

public sealed record CloudOwner(Guid Id, Guid TenantId, string Login, string Name, Role Role, int SessionVersion);
public sealed record CloudDevice(Guid Id, Guid TenantId, Guid BusinessId, string Name, bool Active, DateTimeOffset ExpiresAt, DateTimeOffset? LastSeen);
public sealed record ProvisionRequest(string BusinessName, string Login, string Name, string Password);
public sealed record OwnerLogin(string Login, string Password);
public sealed record CreateCommand(Guid Id, Guid TargetDeviceId, string Type, JsonElement Payload);
public sealed record CloudMetrics(int Transactions, long GrossCents, long RefundsCents, long NetSalesCents, long AuthorizedCents, long EstimatedMarginCents, Dictionary<string, long> Payments);
public sealed record OwnerDashboard(string BusinessName, Guid? BusinessId, DateTimeOffset AsOf, CloudMetrics Metrics, Product[] Products, bool ProductsTruncated,
    CashSession[] CashSessions, Sale[] RecentSales, AuditEntry[] Activity, Notification[] Notifications, CloudDevice[] Devices, RemoteCommand[] Commands);
public sealed class CloudUnauthorizedException : Exception;
public sealed class CloudConflictException(string message) : Exception(message);

public sealed class CloudStore
{
    private readonly object gate = new();
    private readonly string path;
    private static readonly string DummyHash = Passwords.Hash(Convert.ToHexString(RandomNumberGenerator.GetBytes(20)));
    private static readonly HashSet<string> Kinds = [nameof(Business), nameof(Product), nameof(Contact), nameof(CashSession), nameof(CashMovement), nameof(StockMovement), nameof(Sale), nameof(Refund), nameof(Purchase), nameof(AuditEntry), nameof(Notification), nameof(FiscalDocument), nameof(PaymentIntent)];
    public CloudStore(string path)
    {
        this.path = Path.GetFullPath(path); Directory.CreateDirectory(Path.GetDirectoryName(this.path)!);
        using var connection = Open(); using var command = connection.CreateCommand(); command.CommandText = "PRAGMA user_version";
        var version = Convert.ToInt32(command.ExecuteScalar());
        if (version > 1) throw new BusinessException("Base remota de una versión más nueva.");
        if (version == 0)
        {
            command.CommandText = "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'";
            if (Convert.ToInt32(command.ExecuteScalar()) != 0) throw new BusinessException("La base remota no pertenece a Caja Clara.");
            using var transaction = connection.BeginTransaction(deferred: false); command.Transaction = transaction;
            var assembly = Assembly.GetExecutingAssembly(); using var stream = assembly.GetManifestResourceStream(assembly.GetManifestResourceNames().Single(x => x.EndsWith("schema.sql", StringComparison.Ordinal)))!;
            using var reader = new StreamReader(stream); command.CommandText = reader.ReadToEnd(); command.ExecuteNonQuery(); transaction.Commit(); command.Transaction = null;
        }
        command.CommandText = "PRAGMA application_id";
        if (Convert.ToInt32(command.ExecuteScalar()) != 1128481610) throw new BusinessException("Base remota incompatible.");
    }
    private SqliteConnection Open()
    {
        var connection = new SqliteConnection(new SqliteConnectionStringBuilder { DataSource = path, Pooling = true, DefaultTimeout = 15 }.ToString()); connection.Open();
        using var command = connection.CreateCommand(); command.CommandText = "PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=15000;"; command.ExecuteNonQuery(); return connection;
    }
    private T Tx<T>(Func<SqliteConnection, SqliteTransaction, T> action)
    {
        lock (gate)
        {
            using var connection = Open(); using var transaction = connection.BeginTransaction(deferred: false);
            try { var result = action(connection, transaction); transaction.Commit(); return result; }
            catch (SqliteException e) when (e.SqliteErrorCode == 19) { throw new CloudConflictException("Conflicto de datos. La operación no se aplicó."); }
        }
    }
    private static SqliteCommand Command(SqliteConnection connection, SqliteTransaction transaction, string sql, params (string, object?)[] parameters)
    {
        var command = connection.CreateCommand(); command.Transaction = transaction; command.CommandText = sql;
        foreach (var (key, value) in parameters) command.Parameters.AddWithValue(key, value ?? DBNull.Value); return command;
    }
    private static object? Scalar(SqliteConnection c, SqliteTransaction t, string sql, params (string, object?)[] args)
    { using var command = Command(c, t, sql, args); return command.ExecuteScalar(); }
    private static int Execute(SqliteConnection c, SqliteTransaction t, string sql, params (string, object?)[] args)
    { using var command = Command(c, t, sql, args); return command.ExecuteNonQuery(); }
    private static void Audit(SqliteConnection c, SqliteTransaction t, Guid tenant, Guid actor, string action, Guid subject)
        => Execute(c, t, "INSERT INTO server_audit(id,tenant_id,actor_id,action,subject_id,at) VALUES($id,$tenant,$actor,$action,$subject,$at)",
            ("$id", Guid.NewGuid().ToString()), ("$tenant", tenant.ToString()), ("$actor", actor.ToString()), ("$action", action), ("$subject", subject.ToString()), ("$at", DateTimeOffset.UtcNow.ToString("O")));
    public CloudOwner Provision(ProvisionRequest input)
    {
        if (string.IsNullOrWhiteSpace(input.BusinessName) || input.BusinessName.Length > 160 || string.IsNullOrWhiteSpace(input.Login) || input.Login.Length > 100 ||
            input.Login.Any(c => !char.IsAsciiLetterOrDigit(c) && c is not ('@' or '.' or '_' or '-')) || string.IsNullOrWhiteSpace(input.Name) || input.Name.Length > 120)
            throw new BusinessException("Datos de cuenta inválidos.");
        Passwords.Validate(input.Password); var hash = Passwords.Hash(input.Password);
        return Tx((c, t) =>
        {
            var owner = new CloudOwner(Guid.NewGuid(), Guid.NewGuid(), input.Login.Trim().ToLowerInvariant(), input.Name.Trim(), Role.Owner, 1);
            Execute(c, t, "INSERT INTO tenants(id,name,created_at) VALUES($id,$name,$at)", ("$id", owner.TenantId.ToString()), ("$name", input.BusinessName.Trim()), ("$at", DateTimeOffset.UtcNow.ToString("O")));
            Execute(c, t, "INSERT INTO owners(id,tenant_id,login,name,password_hash,role) VALUES($id,$tenant,$login,$name,$hash,'Owner')", ("$id", owner.Id.ToString()), ("$tenant", owner.TenantId.ToString()), ("$login", owner.Login), ("$name", owner.Name), ("$hash", hash));
            Audit(c, t, owner.TenantId, owner.Id, "OWNER_PROVISIONED", owner.Id); return owner;
        });
    }
    public CloudOwner? Authenticate(string? login, string? password)
    {
        if (login is null || password is null || login.Length > 100 || password.Length > 256) return null;
        return Tx<CloudOwner?>((c, t) =>
        {
            using var command = Command(c, t, "SELECT id,tenant_id,login,name,role,session_version,password_hash,failed,locked_until,active FROM owners WHERE login=$login", ("$login", login.Trim().ToLowerInvariant()));
            using var reader = command.ExecuteReader();
            if (!reader.Read()) { reader.Close(); Passwords.Verify(password, DummyHash); return null; }
            var owner = new CloudOwner(Guid.Parse(reader.GetString(0)), Guid.Parse(reader.GetString(1)), reader.GetString(2), reader.GetString(3), Enum.Parse<Role>(reader.GetString(4)), reader.GetInt32(5));
            var hash = reader.GetString(6); var failed = reader.GetInt32(7); var locked = reader.IsDBNull(8) ? (DateTimeOffset?)null : DateTimeOffset.Parse(reader.GetString(8)); var active = reader.GetInt32(9) == 1; reader.Close();
            if (!active || locked > DateTimeOffset.UtcNow) return null;
            if (!Passwords.Verify(password, hash))
            {
                failed++; Execute(c, t, "UPDATE owners SET failed=$failed,locked_until=$locked WHERE id=$id", ("$failed", failed), ("$locked", failed >= 5 ? DateTimeOffset.UtcNow.AddMinutes(15).ToString("O") : null), ("$id", owner.Id.ToString())); return null;
            }
            Execute(c, t, "UPDATE owners SET failed=0,locked_until=NULL WHERE id=$id", ("$id", owner.Id.ToString())); return owner;
        });
    }
    public CloudOwner? Owner(Guid id) => Tx<CloudOwner?>((c, t) =>
    {
        using var command = Command(c, t, "SELECT tenant_id,login,name,role,session_version FROM owners WHERE id=$id AND active=1", ("$id", id.ToString()));
        using var reader = command.ExecuteReader();
        return reader.Read() ? new CloudOwner(id, Guid.Parse(reader.GetString(0)), reader.GetString(1), reader.GetString(2), Enum.Parse<Role>(reader.GetString(3)), reader.GetInt32(4)) : null;
    });
    public string CreatePairCode(CloudOwner owner)
    {
        RequireOwner(owner); var code = Convert.ToHexString(RandomNumberGenerator.GetBytes(16));
        return Tx((c, t) =>
        {
            Execute(c, t, "DELETE FROM pair_codes WHERE tenant_id=$tenant OR expires_at<$at", ("$tenant", owner.TenantId.ToString()), ("$at", DateTimeOffset.UtcNow.ToString("O")));
            Execute(c, t, "INSERT INTO pair_codes(code_hash,tenant_id,expires_at) VALUES($hash,$tenant,$expires)", ("$hash", Json.Hash(code)), ("$tenant", owner.TenantId.ToString()), ("$expires", DateTimeOffset.UtcNow.AddMinutes(5).ToString("O")));
            Audit(c, t, owner.TenantId, owner.Id, "PAIR_CODE_CREATED", owner.TenantId); return code;
        });
    }
    public PairResponse Pair(PairRequest request)
    {
        if (request.Code is null || request.Code.Length != 32 || request.BusinessId == Guid.Empty || request.DeviceId == Guid.Empty || string.IsNullOrWhiteSpace(request.DeviceName) || request.DeviceName.Length > 100)
            throw new BusinessException("Solicitud de vinculación inválida.");
        return Tx((c, t) =>
        {
            var tenantText = Scalar(c, t, "SELECT tenant_id FROM pair_codes WHERE code_hash=$hash AND used_at IS NULL AND expires_at>$at", ("$hash", Json.Hash(request.Code.ToUpperInvariant())), ("$at", DateTimeOffset.UtcNow.ToString("O"))) as string;
            if (tenantText is null) throw new BusinessException("Código inválido, usado o vencido."); var tenant = Guid.Parse(tenantText);
            var business = Scalar(c, t, "SELECT business_id FROM tenants WHERE id=$id", ("$id", tenantText));
            if (business is string existing && existing != request.BusinessId.ToString()) throw new BusinessException("La cuenta ya pertenece a otro comercio local.");
            if (Convert.ToInt32(Scalar(c, t, "SELECT COUNT(*) FROM devices WHERE tenant_id=$tenant AND active=1 AND id<>$id", ("$tenant", tenantText), ("$id", request.DeviceId.ToString()))) > 0)
                throw new BusinessException("Esta edición permite una caja primaria por comercio. Revocá el otro equipo antes de reemplazarlo.");
            var previousTenant = Scalar(c, t, "SELECT tenant_id FROM devices WHERE id=$id", ("$id", request.DeviceId.ToString())) as string;
            if (previousTenant is not null && previousTenant != tenantText) throw new BusinessException("El equipo pertenece a otra cuenta.");
            var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
            Execute(c, t, "UPDATE tenants SET business_id=$business WHERE id=$tenant", ("$business", request.BusinessId.ToString()), ("$tenant", tenantText));
            Execute(c, t, "INSERT INTO devices(id,tenant_id,business_id,name,token_hash,active,expires_at) VALUES($id,$tenant,$business,$name,$hash,1,$expires) ON CONFLICT(id) DO UPDATE SET token_hash=excluded.token_hash,active=1,expires_at=excluded.expires_at,name=excluded.name",
                ("$id", request.DeviceId.ToString()), ("$tenant", tenantText), ("$business", request.BusinessId.ToString()), ("$name", request.DeviceName), ("$hash", Json.Hash(token)), ("$expires", DateTimeOffset.UtcNow.AddDays(90).ToString("O")));
            Execute(c, t, "UPDATE pair_codes SET used_at=$at WHERE code_hash=$hash", ("$at", DateTimeOffset.UtcNow.ToString("O")), ("$hash", Json.Hash(request.Code.ToUpperInvariant())));
            Audit(c, t, tenant, request.DeviceId, "DEVICE_PAIRED", request.DeviceId); return new PairResponse(token);
        });
    }
    public CloudDevice? Device(string? token)
    {
        if (token is null || token.Length != 64) return null;
        return Tx<CloudDevice?>((c, t) =>
        {
            using var command = Command(c, t, "SELECT id,tenant_id,business_id,name,active,expires_at,last_seen FROM devices WHERE token_hash=$hash AND active=1 AND expires_at>$at", ("$hash", Json.Hash(token)), ("$at", DateTimeOffset.UtcNow.ToString("O")));
            using var reader = command.ExecuteReader(); return reader.Read() ? DeviceRow(reader) : null;
        });
    }
    private static CloudDevice DeviceRow(SqliteDataReader reader) => new(Guid.Parse(reader.GetString(0)), Guid.Parse(reader.GetString(1)), Guid.Parse(reader.GetString(2)), reader.GetString(3), reader.GetInt32(4) == 1, DateTimeOffset.Parse(reader.GetString(5)), reader.IsDBNull(6) ? null : DateTimeOffset.Parse(reader.GetString(6)));
    private static CloudDevice[] Devices(SqliteConnection c, SqliteTransaction t, Guid tenant)
    {
        using var command = Command(c, t, "SELECT id,tenant_id,business_id,name,active,expires_at,last_seen FROM devices WHERE tenant_id=$tenant ORDER BY name", ("$tenant", tenant.ToString()));
        using var reader = command.ExecuteReader(); var result = new List<CloudDevice>(); while (reader.Read()) result.Add(DeviceRow(reader)); return result.ToArray();
    }
    public CloudDevice DeviceForOwner(CloudOwner owner, Guid deviceId)
    {
        RequireOwner(owner);
        return Tx((c, t) =>
        {
            using var command = Command(c, t,
                "SELECT id,tenant_id,business_id,name,active,expires_at,last_seen FROM devices WHERE tenant_id=$tenant AND id=$id",
                ("$tenant", owner.TenantId.ToString()), ("$id", deviceId.ToString()));
            using var reader = command.ExecuteReader();
            if (!reader.Read()) throw new BusinessException("Equipo inexistente.");
            var device = DeviceRow(reader);
            if (!device.Active || device.ExpiresAt <= DateTimeOffset.UtcNow) throw new BusinessException("El equipo no está autorizado.");
            return device;
        });
    }

    public void Revoke(CloudOwner owner, Guid deviceId)
    {
        RequireOwner(owner); Tx((c, t) =>
        {
            if (Execute(c, t, "UPDATE devices SET active=0 WHERE id=$id AND tenant_id=$tenant", ("$id", deviceId.ToString()), ("$tenant", owner.TenantId.ToString())) != 1) throw new BusinessException("Equipo inexistente.");
            Audit(c, t, owner.TenantId, owner.Id, "DEVICE_REVOKED", deviceId); return 0;
        });
    }
    public EventAcceptance Accept(CloudDevice device, EventBatch batch)
    {
        if (device.Id != batch.DeviceId || device.BusinessId != batch.BusinessId || batch.Events is null || batch.Events.Length > 200) throw new CloudUnauthorizedException();
        return Tx((c, t) =>
        {
            var accepted = new List<Guid>();
            foreach (var item in batch.Events.OrderBy(x => x.Sequence))
            {
                if (item.EventId == Guid.Empty || item.EntityId == Guid.Empty || item.Sequence <= 0 || item.Version <= 0 || !Kinds.Contains(item.Kind) || item.Payload is null || item.Payload.Length > 1_000_000 || Json.Hash(item.Payload) != item.PayloadHash)
                    throw new BusinessException("Evento inválido.");
                using var document = JsonDocument.Parse(item.Payload); var body = document.RootElement;
                if (!body.TryGetProperty("id", out var id) || !id.TryGetGuid(out var entity) || entity != item.EntityId || !body.TryGetProperty("version", out var version) || version.GetInt64() != item.Version)
                    throw new BusinessException("Identidad o versión de evento inválida.");
                if (item.Kind == nameof(Business) && item.EntityId != device.BusinessId) throw new CloudUnauthorizedException();
                if (body.TryGetProperty("deviceId", out var sourceDevice) && sourceDevice.GetGuid() != device.Id) throw new CloudUnauthorizedException();
                var previous = Scalar(c, t, "SELECT payload_hash FROM events WHERE tenant_id=$tenant AND event_id=$id", ("$tenant", device.TenantId.ToString()), ("$id", item.EventId.ToString())) as string;
                if (previous is not null)
                {
                    if (previous != item.PayloadHash) throw new CloudConflictException("Un evento ya confirmado tiene otro contenido."); accepted.Add(item.EventId); continue;
                }
                long currentVersion = 0; string? currentHash = null;
                using (var command = Command(c, t, "SELECT version,payload_hash FROM projections WHERE tenant_id=$tenant AND kind=$kind AND entity_id=$id", ("$tenant", device.TenantId.ToString()), ("$kind", item.Kind), ("$id", item.EntityId.ToString())))
                using (var reader = command.ExecuteReader()) if (reader.Read()) { currentVersion = reader.GetInt64(0); currentHash = reader.GetString(1); }
                if (currentVersion == item.Version && currentHash != item.PayloadHash) throw new CloudConflictException("Conflicto de versión en un registro.");
                if (item.Version > currentVersion + 1) throw new CloudConflictException("Faltan versiones anteriores. Se conservaron los eventos locales.");
                if (item.Version > currentVersion)
                    Execute(c, t, "INSERT INTO projections(tenant_id,kind,entity_id,version,body,payload_hash,updated_at) VALUES($tenant,$kind,$id,$version,$body,$hash,$at) ON CONFLICT(tenant_id,kind,entity_id) DO UPDATE SET version=excluded.version,body=excluded.body,payload_hash=excluded.payload_hash,updated_at=excluded.updated_at",
                        ("$tenant", device.TenantId.ToString()), ("$kind", item.Kind), ("$id", item.EntityId.ToString()), ("$version", item.Version), ("$body", item.Payload), ("$hash", item.PayloadHash), ("$at", DateTimeOffset.UtcNow.ToString("O")));
                Execute(c, t, "INSERT INTO events(tenant_id,device_id,event_id,sequence,kind,entity_id,version,payload_hash,received_at) VALUES($tenant,$device,$event,$sequence,$kind,$entity,$version,$hash,$at)",
                    ("$tenant", device.TenantId.ToString()), ("$device", device.Id.ToString()), ("$event", item.EventId.ToString()), ("$sequence", item.Sequence), ("$kind", item.Kind), ("$entity", item.EntityId.ToString()), ("$version", item.Version), ("$hash", item.PayloadHash), ("$at", DateTimeOffset.UtcNow.ToString("O")));
                accepted.Add(item.EventId);
            }
            Execute(c, t, "UPDATE devices SET last_seen=$at WHERE id=$id AND active=1", ("$at", DateTimeOffset.UtcNow.ToString("O")), ("$id", device.Id.ToString()));
            return new EventAcceptance(accepted.ToArray());
        });
    }
    public RemoteCommand Enqueue(CloudOwner owner, CreateCommand input)
    {
        RequireOwner(owner);
        if (input.Id == Guid.Empty || input.TargetDeviceId == Guid.Empty || !RemoteExecutor.AllowedTypes.Contains(input.Type) || input.Payload.ValueKind != JsonValueKind.Object || input.Payload.GetRawText().Length > 4096)
            throw new BusinessException("Comando no permitido.");
        return Tx((c, t) =>
        {
            var devices = Devices(c, t, owner.TenantId); var device = devices.SingleOrDefault(x => x.Id == input.TargetDeviceId && x.Active && x.ExpiresAt > DateTimeOffset.UtcNow) ?? throw new BusinessException("Equipo no autorizado.");
            var hash = Json.Hash(Json.Write(new { owner.Id, input }));
            using (var query = Command(c, t, "SELECT request_hash,body FROM commands WHERE id=$id AND tenant_id=$tenant", ("$id", input.Id.ToString()), ("$tenant", owner.TenantId.ToString())))
            using (var reader = query.ExecuteReader())
                if (reader.Read()) { if (reader.GetString(0) != hash) throw new CloudConflictException("El identificador de comando ya se usó para otra acción."); return Json.Read<RemoteCommand>(reader.GetString(1)); }
            if (input.Type == "UPDATE_PRODUCT_PRICE")
            {
                var price = Json.Read<PriceCommand>(input.Payload.GetRawText()); Money.Valid(price.PriceCents, false);
                var product = Projection<Product>(c, t, owner.TenantId, price.ProductId);
                if (product.Version != price.ExpectedVersion) throw new CloudConflictException("El producto cambió. Actualizá antes de enviar el precio.");
            }
            if (input.Type is "ENABLE_PRODUCT" or "DISABLE_PRODUCT")
            {
                var active = Json.Read<ActiveCommand>(input.Payload.GetRawText()); var product = Projection<Product>(c, t, owner.TenantId, active.ProductId);
                if (product.Version != active.ExpectedVersion || active.Active != (input.Type == "ENABLE_PRODUCT")) throw new CloudConflictException("Versión o estado no coincidente.");
            }
            var now = DateTimeOffset.UtcNow;
            var command = new RemoteCommand(input.Id, device.BusinessId, device.Id, input.Type, input.Payload.GetRawText(), owner.Login, now, now.AddMinutes(15), RemoteStatus.Pending);
            Execute(c, t, "INSERT INTO commands(id,tenant_id,device_id,request_hash,body,status,requested_at,expires_at) VALUES($id,$tenant,$device,$hash,$body,$status,$at,$expires)",
                ("$id", command.Id.ToString()), ("$tenant", owner.TenantId.ToString()), ("$device", device.Id.ToString()), ("$hash", hash), ("$body", Json.Write(command)), ("$status", command.Status.ToString()), ("$at", now.ToString("O")), ("$expires", command.ExpiresAt.ToString("O")));
            Audit(c, t, owner.TenantId, owner.Id, "COMMAND_REQUESTED:" + command.Type, command.Id); return command;
        });
    }
    public RemoteCommand[] Pending(CloudDevice device) => Tx((c, t) =>
    {
        using var query = Command(c, t, "SELECT body FROM commands WHERE tenant_id=$tenant AND device_id=$device AND status IN ('Pending','Received','Executing') ORDER BY requested_at LIMIT 50", ("$tenant", device.TenantId.ToString()), ("$device", device.Id.ToString()));
        using var reader = query.ExecuteReader(); var commands = new List<RemoteCommand>(); while (reader.Read()) commands.Add(Json.Read<RemoteCommand>(reader.GetString(0))); reader.Close();
        var delivery = new List<RemoteCommand>();
        foreach (var command in commands)
        {
            var next = command with { Status = command.ExpiresAt <= DateTimeOffset.UtcNow ? RemoteStatus.Expired : RemoteStatus.Received };
            Execute(c, t, "UPDATE commands SET status=$status,body=$body WHERE id=$id AND tenant_id=$tenant", ("$status", next.Status.ToString()), ("$body", Json.Write(next)), ("$id", next.Id.ToString()), ("$tenant", device.TenantId.ToString()));
            if (next.Status != RemoteStatus.Expired) delivery.Add(next);
        }
        return delivery.ToArray();
    });
    public void Acknowledge(CloudDevice device, CommandResult result)
    {
        if (result.Status is not (RemoteStatus.Completed or RemoteStatus.Rejected or RemoteStatus.Failed or RemoteStatus.Expired) || result.Result is null || result.Result.Length > 1000) throw new BusinessException("Resultado de comando inválido.");
        Tx((c, t) =>
        {
            var body = Scalar(c, t, "SELECT body FROM commands WHERE id=$id AND tenant_id=$tenant AND device_id=$device", ("$id", result.CommandId.ToString()), ("$tenant", device.TenantId.ToString()), ("$device", device.Id.ToString())) as string ?? throw new CloudUnauthorizedException();
            var old = Json.Read<RemoteCommand>(body);
            if (old.Status is RemoteStatus.Completed or RemoteStatus.Rejected or RemoteStatus.Failed)
            { if (old.Status != result.Status || old.Result != result.Result) throw new CloudConflictException("El comando ya tiene otro resultado final."); return 0; }
            var next = old with { Status = result.Status, Result = result.Result };
            Execute(c, t, "UPDATE commands SET status=$status,body=$body WHERE id=$id AND tenant_id=$tenant", ("$status", next.Status.ToString()), ("$body", Json.Write(next)), ("$id", next.Id.ToString()), ("$tenant", device.TenantId.ToString()));
            Audit(c, t, device.TenantId, device.Id, "COMMAND_RESULT:" + next.Status, next.Id); return 0;
        });
    }
    private static T Projection<T>(SqliteConnection c, SqliteTransaction t, Guid tenant, Guid id) where T : class, IEntity
    {
        var body = Scalar(c, t, "SELECT body FROM projections WHERE tenant_id=$tenant AND kind=$kind AND entity_id=$id", ("$tenant", tenant.ToString()), ("$kind", typeof(T).Name), ("$id", id.ToString())) as string ?? throw new BusinessException("Registro no encontrado en este comercio.");
        return Json.Read<T>(body);
    }
    private static T[] Rows<T>(SqliteConnection c, SqliteTransaction t, Guid tenant, int limit = 10000) where T : class, IEntity
    {
        using var command = Command(c, t, "SELECT body FROM projections WHERE tenant_id=$tenant AND kind=$kind ORDER BY updated_at DESC LIMIT $limit", ("$tenant", tenant.ToString()), ("$kind", typeof(T).Name), ("$limit", limit));
        using var reader = command.ExecuteReader(); var rows = new List<T>(); while (reader.Read()) rows.Add(Json.Read<T>(reader.GetString(0))); return rows.ToArray();
    }
    public OwnerDashboard Dashboard(CloudOwner owner, DateTimeOffset from, DateTimeOffset to)
    {
        if (from >= to || to - from > TimeSpan.FromDays(32)) throw new BusinessException("El panel admite hasta 31 días por consulta.");
        return Tx((c, t) =>
        {
            var businessName = Convert.ToString(Scalar(c, t, "SELECT name FROM tenants WHERE id=$tenant", ("$tenant", owner.TenantId.ToString()))) ?? "Comercio";
            var businessId = Scalar(c, t, "SELECT business_id FROM tenants WHERE id=$tenant", ("$tenant", owner.TenantId.ToString())) as string;
            var sales = new List<Sale>();
            using (var query = Command(c, t, "SELECT body FROM projections WHERE tenant_id=$tenant AND kind='Sale' AND julianday(json_extract(body,'$.at'))>=julianday($from) AND julianday(json_extract(body,'$.at'))<julianday($to)", ("$tenant", owner.TenantId.ToString()), ("$from", from.ToUniversalTime().ToString("O")), ("$to", to.ToUniversalTime().ToString("O"))))
            using (var reader = query.ExecuteReader()) while (reader.Read()) sales.Add(Json.Read<Sale>(reader.GetString(0)));
            var refunds = new List<Refund>();
            using (var query = Command(c, t, "SELECT body FROM projections WHERE tenant_id=$tenant AND kind='Refund' AND julianday(json_extract(body,'$.at'))>=julianday($from) AND julianday(json_extract(body,'$.at'))<julianday($to)", ("$tenant", owner.TenantId.ToString()), ("$from", from.ToUniversalTime().ToString("O")), ("$to", to.ToUniversalTime().ToString("O"))))
            using (var reader = query.ExecuteReader()) while (reader.Read()) refunds.Add(Json.Read<Refund>(reader.GetString(0)));
            var gross = sales.Sum(x => x.TotalCents); var returned = refunds.Sum(x => x.TotalCents);
            var margin = sales.Sum(x => x.Lines.Sum(l => l.TotalCents - Money.Extend(l.CostCents, l.QuantityMilli)));
            foreach (var refund in refunds) { var sale = Projection<Sale>(c, t, owner.TenantId, refund.SaleId); margin -= sale.Lines.Sum(l => l.TotalCents - Money.Extend(l.CostCents, l.QuantityMilli)); }
            var methods = Enum.GetValues<PaymentMethod>().ToDictionary(x => x.ToString(), x => sales.Sum(s => s.Payments.Where(p => p.Method == x).Sum(p => p.AppliedCents)) - refunds.Sum(r => r.Payments.Where(p => p.Method == x).Sum(p => p.AppliedCents)));
            var metrics = new CloudMetrics(sales.Count, gross, returned, gross - returned, sales.Where(x => x.FiscalState == FiscalState.Authorized).Sum(x => x.TotalCents), margin, methods);
            var products = Rows<Product>(c, t, owner.TenantId, 10001);
            var commands = new List<RemoteCommand>();
            using (var query = Command(c, t, "SELECT body FROM commands WHERE tenant_id=$tenant ORDER BY requested_at DESC LIMIT 50", ("$tenant", owner.TenantId.ToString())))
            using (var reader = query.ExecuteReader()) while (reader.Read()) commands.Add(Json.Read<RemoteCommand>(reader.GetString(0)));
            return new OwnerDashboard(businessName, businessId is null ? null : Guid.Parse(businessId), DateTimeOffset.UtcNow, metrics, products.Take(10000).ToArray(), products.Length > 10000,
                Rows<CashSession>(c, t, owner.TenantId).Where(x => x.State != CashState.Closed).ToArray(), sales.OrderByDescending(x => x.At).Take(50).ToArray(),
                Rows<AuditEntry>(c, t, owner.TenantId, 50), Rows<Notification>(c, t, owner.TenantId, 50), Devices(c, t, owner.TenantId), commands.ToArray());
        });
    }
    private static void RequireOwner(CloudOwner owner) { if (owner.Role != Role.Owner) throw new CloudUnauthorizedException(); }
}
