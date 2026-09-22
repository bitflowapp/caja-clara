using CajaClara.Core;
using Microsoft.Data.Sqlite;

namespace CajaClara.Backend;

public sealed record PaymentOauthContext(Guid TenantId, Guid OwnerId, string ProtectedVerifier, DateTimeOffset ExpiresAt);
public sealed record PaymentProviderConnection(Guid TenantId, long ProviderUserId, string ProtectedToken, DateTimeOffset UpdatedAt);
public sealed record PaymentPosBinding(Guid TenantId, Guid DeviceId, string ExternalPosId, DateTimeOffset UpdatedAt);
public sealed record CloudPaymentOrder(
    Guid Id,
    Guid TenantId,
    Guid DeviceId,
    Guid IdempotencyKey,
    string ExternalReference,
    long AmountCents,
    string? ProviderOrderId,
    string Status,
    string StatusDetail,
    string? QrData,
    DateTimeOffset UpdatedAt);

public sealed class PaymentCloudStore
{
    private readonly object gate = new();
    private readonly string path;

    public PaymentCloudStore(string path)
    {
        this.path = Path.GetFullPath(path);
        Directory.CreateDirectory(Path.GetDirectoryName(this.path)!);
        lock (gate)
        {
            using var connection = Open();
            using var command = connection.CreateCommand();
            command.CommandText = "PRAGMA user_version";
            var version = Convert.ToInt32(command.ExecuteScalar());
            if (version > 2) throw new BusinessException("Base de pagos pertenece a una versión más nueva.");
            if (version == 0)
            {
                command.CommandText = "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'";
                if (Convert.ToInt32(command.ExecuteScalar()) != 0) throw new BusinessException("La base de pagos existente no pertenece a Caja Clara.");
                using var transaction = connection.BeginTransaction(deferred: false);
                command.Transaction = transaction;
                command.CommandText = Schema;
                command.ExecuteNonQuery();
                transaction.Commit();
                command.Transaction = null;
                version = 2;
            }
            command.CommandText = "PRAGMA application_id";
            if (Convert.ToInt32(command.ExecuteScalar()) != 1128481611) throw new BusinessException("Base de pagos incompatible.");
            if (version == 1)
            {
                using var transaction = connection.BeginTransaction(deferred: false);
                command.Transaction = transaction;
                command.CommandText = """
CREATE TABLE payment_pos_bindings(
    tenant_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    external_pos_id TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY(tenant_id,device_id),
    UNIQUE(tenant_id,external_pos_id)
);
PRAGMA user_version=2;
""";
                command.ExecuteNonQuery();
                transaction.Commit();
                command.Transaction = null;
            }
        }
    }

    private SqliteConnection Open()
    {
        var connection = new SqliteConnection(new SqliteConnectionStringBuilder
        {
            DataSource = path,
            Pooling = true,
            DefaultTimeout = 15
        }.ToString());
        connection.Open();
        using var command = connection.CreateCommand();
        command.CommandText = "PRAGMA foreign_keys=ON; PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=15000;";
        command.ExecuteNonQuery();
        return connection;
    }

    private T Tx<T>(Func<SqliteConnection, SqliteTransaction, T> action)
    {
        lock (gate)
        {
            using var connection = Open();
            using var transaction = connection.BeginTransaction(deferred: false);
            try
            {
                var result = action(connection, transaction);
                transaction.Commit();
                return result;
            }
            catch (SqliteException error) when (error.SqliteErrorCode == 19)
            {
                throw new CloudConflictException("Conflicto de datos de pagos. La operación no se aplicó.");
            }
        }
    }

    private static SqliteCommand Command(SqliteConnection connection, SqliteTransaction transaction, string sql, params (string, object?)[] parameters)
    {
        var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = sql;
        foreach (var (key, value) in parameters) command.Parameters.AddWithValue(key, value ?? DBNull.Value);
        return command;
    }

    private static int Execute(SqliteConnection connection, SqliteTransaction transaction, string sql, params (string, object?)[] parameters)
    {
        using var command = Command(connection, transaction, sql, parameters);
        return command.ExecuteNonQuery();
    }

    private static void Audit(SqliteConnection connection, SqliteTransaction transaction, Guid tenant, Guid actor, string action, string subject)
        => Execute(connection, transaction,
            "INSERT INTO payment_audit(id,tenant_id,actor_id,action,subject,at) VALUES($id,$tenant,$actor,$action,$subject,$at)",
            ("$id", Guid.NewGuid().ToString()), ("$tenant", tenant.ToString()), ("$actor", actor.ToString()),
            ("$action", action), ("$subject", subject), ("$at", DateTimeOffset.UtcNow.ToString("O")));

    public void SaveOauthState(CloudOwner owner, string stateHash, string protectedVerifier, DateTimeOffset expiresAt)
    {
        if (stateHash.Length != 64 || protectedVerifier.Length < 20 || expiresAt <= DateTimeOffset.UtcNow) throw new BusinessException("Contexto OAuth inválido.");
        Tx((connection, transaction) =>
        {
            Execute(connection, transaction, "DELETE FROM payment_oauth_states WHERE expires_at<$now", ("$now", DateTimeOffset.UtcNow.ToString("O")));
            Execute(connection, transaction,
                "INSERT INTO payment_oauth_states(state_hash,tenant_id,owner_id,protected_verifier,expires_at) VALUES($state,$tenant,$owner,$verifier,$expires)",
                ("$state", stateHash), ("$tenant", owner.TenantId.ToString()), ("$owner", owner.Id.ToString()), ("$verifier", protectedVerifier), ("$expires", expiresAt.ToString("O")));
            Audit(connection, transaction, owner.TenantId, owner.Id, "MP_OAUTH_STARTED", stateHash[..16]);
            return 0;
        });
    }

    public PaymentOauthContext ConsumeOauthState(string stateHash)
    {
        if (stateHash.Length != 64) throw new CloudUnauthorizedException();
        return Tx((connection, transaction) =>
        {
            using var command = Command(connection, transaction,
                "SELECT tenant_id,owner_id,protected_verifier,expires_at FROM payment_oauth_states WHERE state_hash=$state",
                ("$state", stateHash));
            using var reader = command.ExecuteReader();
            if (!reader.Read()) throw new CloudUnauthorizedException();
            var value = new PaymentOauthContext(Guid.Parse(reader.GetString(0)), Guid.Parse(reader.GetString(1)), reader.GetString(2), DateTimeOffset.Parse(reader.GetString(3)));
            reader.Close();
            Execute(connection, transaction, "DELETE FROM payment_oauth_states WHERE state_hash=$state", ("$state", stateHash));
            if (value.ExpiresAt <= DateTimeOffset.UtcNow) throw new CloudUnauthorizedException();
            Audit(connection, transaction, value.TenantId, value.OwnerId, "MP_OAUTH_CALLBACK", stateHash[..16]);
            return value;
        });
    }

    public void SaveConnection(Guid tenantId, Guid ownerId, long providerUserId, string protectedToken)
    {
        if (tenantId == Guid.Empty || ownerId == Guid.Empty || providerUserId <= 0 || protectedToken.Length < 20) throw new BusinessException("Conexión de Mercado Pago inválida.");
        Tx((connection, transaction) =>
        {
            Execute(connection, transaction,
                "INSERT INTO payment_connections(tenant_id,provider_user_id,protected_token,updated_at) VALUES($tenant,$user,$token,$at) " +
                "ON CONFLICT(tenant_id) DO UPDATE SET provider_user_id=excluded.provider_user_id,protected_token=excluded.protected_token,updated_at=excluded.updated_at",
                ("$tenant", tenantId.ToString()), ("$user", providerUserId), ("$token", protectedToken), ("$at", DateTimeOffset.UtcNow.ToString("O")));
            Audit(connection, transaction, tenantId, ownerId, "MP_CONNECTED", providerUserId.ToString());
            return 0;
        });
    }

    public PaymentProviderConnection? Connection(Guid tenantId) => Tx<PaymentProviderConnection?>((connection, transaction) =>
    {
        using var command = Command(connection, transaction,
            "SELECT provider_user_id,protected_token,updated_at FROM payment_connections WHERE tenant_id=$tenant",
            ("$tenant", tenantId.ToString()));
        using var reader = command.ExecuteReader();
        return reader.Read() ? new(tenantId, reader.GetInt64(0), reader.GetString(1), DateTimeOffset.Parse(reader.GetString(2))) : null;
    });

    public PaymentPosBinding SavePosBinding(CloudOwner owner, Guid deviceId, string externalPosId)
    {
        if (deviceId == Guid.Empty) throw new BusinessException("Equipo inválido.");
        externalPosId = externalPosId.Trim();
        if (externalPosId.Length is < 1 or > 40 ||
            externalPosId.Any(ch => !char.IsAsciiLetterOrDigit(ch) && ch is not '-' and not '_'))
            throw new BusinessException("external_pos_id inválido. Usá el identificador exacto del POS creado en Mercado Pago.");
        return Tx((connection, transaction) =>
        {
            var at = DateTimeOffset.UtcNow;
            Execute(connection, transaction,
                "INSERT INTO payment_pos_bindings(tenant_id,device_id,external_pos_id,updated_at) VALUES($tenant,$device,$external,$at) " +
                "ON CONFLICT(tenant_id,device_id) DO UPDATE SET external_pos_id=excluded.external_pos_id,updated_at=excluded.updated_at",
                ("$tenant", owner.TenantId.ToString()), ("$device", deviceId.ToString()), ("$external", externalPosId), ("$at", at.ToString("O")));
            Audit(connection, transaction, owner.TenantId, owner.Id, "MP_POS_BOUND", deviceId + ":" + externalPosId);
            return new PaymentPosBinding(owner.TenantId, deviceId, externalPosId, at);
        });
    }

    public PaymentPosBinding? PosBinding(Guid tenantId, Guid deviceId) => Tx<PaymentPosBinding?>((connection, transaction) =>
    {
        using var command = Command(connection, transaction,
            "SELECT external_pos_id,updated_at FROM payment_pos_bindings WHERE tenant_id=$tenant AND device_id=$device",
            ("$tenant", tenantId.ToString()), ("$device", deviceId.ToString()));
        using var reader = command.ExecuteReader();
        return reader.Read() ? new(tenantId, deviceId, reader.GetString(0), DateTimeOffset.Parse(reader.GetString(1))) : null;
    });

    public PaymentPosBinding[] PosBindings(Guid tenantId) => Tx((connection, transaction) =>
    {
        using var command = Command(connection, transaction,
            "SELECT device_id,external_pos_id,updated_at FROM payment_pos_bindings WHERE tenant_id=$tenant ORDER BY updated_at DESC",
            ("$tenant", tenantId.ToString()));
        using var reader = command.ExecuteReader();
        var values = new List<PaymentPosBinding>();
        while (reader.Read()) values.Add(new(tenantId, Guid.Parse(reader.GetString(0)), reader.GetString(1), DateTimeOffset.Parse(reader.GetString(2))));
        return values.ToArray();
    });

    public void RemoveConnection(CloudOwner owner)
    {
        Tx((connection, transaction) =>
        {
            Execute(connection, transaction, "DELETE FROM payment_connections WHERE tenant_id=$tenant", ("$tenant", owner.TenantId.ToString()));
            Audit(connection, transaction, owner.TenantId, owner.Id, "MP_DISCONNECTED", owner.TenantId.ToString());
            return 0;
        });
    }

    public CloudPaymentOrder? OrderByIdempotency(Guid tenantId, Guid idempotencyKey) => Tx<CloudPaymentOrder?>((connection, transaction) =>
    {
        using var command = Command(connection, transaction,
            "SELECT id,tenant_id,device_id,idempotency_key,external_reference,amount_cents,provider_order_id,status,status_detail,qr_data,updated_at " +
            "FROM payment_orders WHERE tenant_id=$tenant AND idempotency_key=$key",
            ("$tenant", tenantId.ToString()), ("$key", idempotencyKey.ToString()));
        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadOrder(reader) : null;
    });

    public CloudPaymentOrder? OrderById(Guid tenantId, Guid id) => Tx<CloudPaymentOrder?>((connection, transaction) =>
    {
        using var command = Command(connection, transaction,
            "SELECT id,tenant_id,device_id,idempotency_key,external_reference,amount_cents,provider_order_id,status,status_detail,qr_data,updated_at " +
            "FROM payment_orders WHERE tenant_id=$tenant AND id=$id",
            ("$tenant", tenantId.ToString()), ("$id", id.ToString()));
        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadOrder(reader) : null;
    });

    public CloudPaymentOrder? OrderByProviderId(string providerOrderId) => Tx<CloudPaymentOrder?>((connection, transaction) =>
    {
        using var command = Command(connection, transaction,
            "SELECT id,tenant_id,device_id,idempotency_key,external_reference,amount_cents,provider_order_id,status,status_detail,qr_data,updated_at " +
            "FROM payment_orders WHERE provider_order_id=$provider",
            ("$provider", providerOrderId));
        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadOrder(reader) : null;
    });

    public CloudPaymentOrder SaveOrder(CloudDevice device, Guid localId, Guid idempotencyKey, string externalReference, long amountCents,
        string providerOrderId, string status, string statusDetail, string? qrData)
    {
        if (localId == Guid.Empty || idempotencyKey == Guid.Empty || providerOrderId.Length < 3 || externalReference.Length < 1) throw new BusinessException("Order de pago inválida.");
        Money.Valid(amountCents, false);
        return Tx((connection, transaction) =>
        {
            using (var existingCommand = Command(connection, transaction,
                "SELECT id,tenant_id,device_id,idempotency_key,external_reference,amount_cents,provider_order_id,status,status_detail,qr_data,updated_at " +
                "FROM payment_orders WHERE tenant_id=$tenant AND idempotency_key=$key",
                ("$tenant", device.TenantId.ToString()), ("$key", idempotencyKey.ToString())))
            using (var reader = existingCommand.ExecuteReader())
            {
                if (reader.Read())
                {
                    var existing = ReadOrder(reader);
                    if (existing.DeviceId != device.Id || existing.Id != localId || existing.ExternalReference != externalReference || existing.AmountCents != amountCents)
                        throw new CloudConflictException("La clave de idempotencia ya pertenece a otro intento de pago.");
                    if (!string.IsNullOrWhiteSpace(existing.ProviderOrderId) && existing.ProviderOrderId != providerOrderId)
                        throw new CloudConflictException("Mercado Pago devolvió otra order para la misma clave idempotente.");
                }
            }
            var at = DateTimeOffset.UtcNow;
            Execute(connection, transaction,
                "INSERT INTO payment_orders(id,tenant_id,device_id,idempotency_key,external_reference,amount_cents,provider_order_id,status,status_detail,qr_data,updated_at) " +
                "VALUES($id,$tenant,$device,$key,$reference,$amount,$provider,$status,$detail,$qr,$at) " +
                "ON CONFLICT(tenant_id,idempotency_key) DO UPDATE SET provider_order_id=excluded.provider_order_id,status=excluded.status,status_detail=excluded.status_detail,qr_data=excluded.qr_data,updated_at=excluded.updated_at",
                ("$id", localId.ToString()), ("$tenant", device.TenantId.ToString()), ("$device", device.Id.ToString()), ("$key", idempotencyKey.ToString()),
                ("$reference", externalReference), ("$amount", amountCents), ("$provider", providerOrderId), ("$status", status), ("$detail", statusDetail), ("$qr", qrData), ("$at", at.ToString("O")));
            Audit(connection, transaction, device.TenantId, device.Id, "MP_ORDER_STATE", providerOrderId + ":" + status);
            return new(localId, device.TenantId, device.Id, idempotencyKey, externalReference, amountCents, providerOrderId, status, statusDetail, qrData, at);
        });
    }

    public CloudPaymentOrder UpdateOrder(CloudPaymentOrder existing, string status, string statusDetail, string? qrData, Guid actor)
    {
        if (existing.ProviderOrderId is null) throw new BusinessException("Order sin identificador de proveedor.");
        return Tx((connection, transaction) =>
        {
            var at = DateTimeOffset.UtcNow;
            Execute(connection, transaction,
                "UPDATE payment_orders SET status=$status,status_detail=$detail,qr_data=COALESCE($qr,qr_data),updated_at=$at WHERE tenant_id=$tenant AND id=$id",
                ("$status", status), ("$detail", statusDetail), ("$qr", qrData), ("$at", at.ToString("O")),
                ("$tenant", existing.TenantId.ToString()), ("$id", existing.Id.ToString()));
            Audit(connection, transaction, existing.TenantId, actor, "MP_ORDER_STATE", existing.ProviderOrderId + ":" + status);
            return existing with { Status = status, StatusDetail = statusDetail, QrData = qrData ?? existing.QrData, UpdatedAt = at };
        });
    }

    private static CloudPaymentOrder ReadOrder(SqliteDataReader reader) => new(
        Guid.Parse(reader.GetString(0)), Guid.Parse(reader.GetString(1)), Guid.Parse(reader.GetString(2)), Guid.Parse(reader.GetString(3)),
        reader.GetString(4), reader.GetInt64(5), reader.IsDBNull(6) ? null : reader.GetString(6), reader.GetString(7), reader.GetString(8),
        reader.IsDBNull(9) ? null : reader.GetString(9), DateTimeOffset.Parse(reader.GetString(10)));

    private const string Schema = """
CREATE TABLE payment_oauth_states(
    state_hash TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    owner_id TEXT NOT NULL,
    protected_verifier TEXT NOT NULL,
    expires_at TEXT NOT NULL
);
CREATE TABLE payment_connections(
    tenant_id TEXT PRIMARY KEY,
    provider_user_id INTEGER NOT NULL,
    protected_token TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE TABLE payment_pos_bindings(
    tenant_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    external_pos_id TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY(tenant_id,device_id),
    UNIQUE(tenant_id,external_pos_id)
);
CREATE TABLE payment_orders(
    id TEXT NOT NULL,
    tenant_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    idempotency_key TEXT NOT NULL,
    external_reference TEXT NOT NULL,
    amount_cents INTEGER NOT NULL CHECK(amount_cents>0),
    provider_order_id TEXT UNIQUE,
    status TEXT NOT NULL,
    status_detail TEXT NOT NULL,
    qr_data TEXT,
    updated_at TEXT NOT NULL,
    PRIMARY KEY(tenant_id,id),
    UNIQUE(tenant_id,idempotency_key)
);
CREATE INDEX payment_orders_provider ON payment_orders(provider_order_id);
CREATE TABLE payment_audit(
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    actor_id TEXT NOT NULL,
    action TEXT NOT NULL,
    subject TEXT NOT NULL,
    at TEXT NOT NULL
);
PRAGMA application_id=1128481611;
PRAGMA user_version=2;
""";
}
