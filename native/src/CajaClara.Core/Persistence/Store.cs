using System.Collections.Concurrent;
using System.Reflection;
using Microsoft.Data.Sqlite;

namespace CajaClara.Core;

public sealed class Store
{
    private static readonly ConcurrentDictionary<string, object> Gates = new(StringComparer.OrdinalIgnoreCase);
    public string Path { get; }
    public TimeProvider Clock { get; }
    private object Gate => Gates.GetOrAdd(Path, _ => new object());
    public Store(string path, TimeProvider? clock = null)
    {
        Path = System.IO.Path.GetFullPath(path);
        Clock = clock ?? TimeProvider.System;
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(Path)!);
        lock (Gate)
        {
            using var c = Open();
            using var check = c.CreateCommand();
            check.CommandText = "PRAGMA user_version";
            var version = Convert.ToInt32(check.ExecuteScalar());
            if (version > 1) throw new BusinessException("La base pertenece a una versión más nueva. No se modificó.");
            if (version == 0)
            {
                var assembly = Assembly.GetExecutingAssembly();
                var resource = assembly.GetManifestResourceNames().Single(x => x.EndsWith("schema.sql", StringComparison.Ordinal));
                using var stream = assembly.GetManifestResourceStream(resource)
                    ?? throw new InvalidOperationException("No se encontró la migración.");
                using var reader = new StreamReader(stream);
                using var tx = c.BeginTransaction(deferred: false);
                using var command = c.CreateCommand(); command.Transaction = tx;
                command.CommandText = reader.ReadToEnd(); command.ExecuteNonQuery(); tx.Commit();
            }
            check.CommandText = "PRAGMA application_id";
            if (Convert.ToInt32(check.ExecuteScalar()) != 1128481603)
                throw new BusinessException("El archivo no es una base de Caja Clara Native.");
        }
    }
    internal SqliteConnection Open()
    {
        var c = new SqliteConnection(new SqliteConnectionStringBuilder
        { DataSource = Path, Mode = SqliteOpenMode.ReadWriteCreate, Pooling = true, DefaultTimeout = 15 }.ToString());
        c.Open();
        using var cmd = c.CreateCommand();
        cmd.CommandText = "PRAGMA foreign_keys=ON; PRAGMA busy_timeout=15000; PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL;";
        cmd.ExecuteNonQuery(); return c;
    }
    public T Read<T>(Func<DbTx, T> action)
    {
        using var c = Open(); using var transaction = c.BeginTransaction(deferred: true);
        var result = action(new DbTx(c, transaction, Clock)); transaction.Commit(); return result;
    }
    public T Write<T>(Func<DbTx, T> action)
    {
        lock (Gate)
        {
            using var c = Open(); using var transaction = c.BeginTransaction(deferred: false);
            try { var result = action(new DbTx(c, transaction, Clock)); transaction.Commit(); return result; }
            catch (SqliteException e) when (e.SqliteErrorCode == 19)
            { throw new BusinessException("La operación entra en conflicto con datos existentes. Revisá códigos y reintentá."); }
        }
    }
    public void Write(Action<DbTx> action) => Write(tx => { action(tx); return 0; });
    public string Integrity() => Read(tx => Convert.ToString(tx.Scalar("PRAGMA quick_check")) ?? "unknown");
    public IReadOnlyList<SyncEnvelope> PendingEvents(int count = 100) => Read(tx =>
    {
        using var cmd = tx.Command("SELECT sequence,event_id,kind,entity_id,version,payload,payload_hash,occurred_at FROM outbox WHERE sent_at IS NULL AND (next_attempt_at IS NULL OR next_attempt_at <= $now) ORDER BY sequence LIMIT $count", ("$now", tx.Now.ToString("O")), ("$count", Math.Clamp(count, 1, 200)));
        using var r = cmd.ExecuteReader(); var items = new List<SyncEnvelope>();
        while (r.Read()) items.Add(new(r.GetInt64(0), Guid.Parse(r.GetString(1)), r.GetString(2), Guid.Parse(r.GetString(3)), r.GetInt64(4), r.GetString(5), r.GetString(6), DateTimeOffset.Parse(r.GetString(7))));
        return (IReadOnlyList<SyncEnvelope>)items;
    });
    public void Acknowledge(IEnumerable<Guid> ids) => Write(tx =>
    {
        foreach (var id in ids) tx.Execute("UPDATE outbox SET sent_at=$at,last_error=NULL WHERE event_id=$id AND sent_at IS NULL", ("$at", tx.Now.ToString("O")), ("$id", id.ToString()));
    });
    public void DelayEvents(IEnumerable<Guid> ids, TimeSpan delay, string safeError) => Write(tx =>
    {
        foreach (var id in ids) tx.Execute("UPDATE outbox SET attempts=attempts+1,next_attempt_at=$next,last_error=$error WHERE event_id=$id AND sent_at IS NULL", ("$next", (tx.Now + delay).ToString("O")), ("$error", safeError), ("$id", id.ToString()));
    });
    public void RetrySync() => Write(tx => tx.Execute("UPDATE outbox SET next_attempt_at=NULL WHERE sent_at IS NULL"));
    public string Backup(string directory)
    {
        Directory.CreateDirectory(directory);
        lock (Gate)
        {
            var destination = System.IO.Path.Combine(directory, $"CajaClara-{Clock.GetUtcNow():yyyyMMdd-HHmmss}-{Guid.NewGuid():N}.sqlite");
            using var source = Open();
            using (var target = new SqliteConnection(new SqliteConnectionStringBuilder { DataSource = destination, Pooling = false }.ToString()))
            { target.Open(); source.BackupDatabase(target); }
            var hash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(File.ReadAllBytes(destination)));
            var business = Read(tx => tx.All<Business>().SingleOrDefault());
            File.WriteAllText(destination + ".manifest.json", Json.Write(new BackupManifest(1, business?.Id, hash, Clock.GetUtcNow())));
            return destination;
        }
    }
    public static BackupManifest ValidateBackup(string path)
    {
        var manifest = Json.Read<BackupManifest>(File.ReadAllText(path + ".manifest.json"));
        var hash = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(File.ReadAllBytes(path)));
        if (!System.Security.Cryptography.CryptographicOperations.FixedTimeEquals(Convert.FromHexString(hash), Convert.FromHexString(manifest.Sha256)))
            throw new BusinessException("El respaldo fue modificado o está incompleto.");
        using var c = new SqliteConnection(new SqliteConnectionStringBuilder { DataSource = path, Mode = SqliteOpenMode.ReadOnly, Pooling = false }.ToString());
        c.Open(); using var cmd = c.CreateCommand(); cmd.CommandText = "PRAGMA integrity_check";
        if (!string.Equals(Convert.ToString(cmd.ExecuteScalar()), "ok", StringComparison.OrdinalIgnoreCase))
            throw new BusinessException("El respaldo no supera la verificación de integridad.");
        cmd.CommandText = "PRAGMA application_id";
        if (Convert.ToInt32(cmd.ExecuteScalar()) != 1128481603 || manifest.SchemaVersion != 1)
            throw new BusinessException("Respaldo incompatible.");
        return manifest;
    }
}
public sealed record BackupManifest(int SchemaVersion, Guid? BusinessId, string Sha256, DateTimeOffset At);

public sealed class DbTx
{
    private readonly SqliteConnection connection;
    private readonly SqliteTransaction transaction;
    private readonly TimeProvider clock;
    internal DbTx(SqliteConnection connection, SqliteTransaction transaction, TimeProvider clock)
    { this.connection = connection; this.transaction = transaction; this.clock = clock; }
    public DateTimeOffset Now => clock.GetUtcNow();
    internal SqliteCommand Command(string sql, params (string Key, object? Value)[] args)
    {
        var c = connection.CreateCommand(); c.Transaction = transaction; c.CommandText = sql;
        foreach (var (key, value) in args) c.Parameters.AddWithValue(key, value ?? DBNull.Value);
        return c;
    }
    internal object? Scalar(string sql, params (string Key, object? Value)[] args)
    { using var c = Command(sql, args); return c.ExecuteScalar(); }
    internal int Execute(string sql, params (string Key, object? Value)[] args)
    { using var c = Command(sql, args); return c.ExecuteNonQuery(); }
    public T? Get<T>(Guid id) where T : class, IEntity
    {
        var body = Scalar("SELECT body FROM records WHERE kind=$kind AND id=$id", ("$kind", typeof(T).Name), ("$id", id.ToString()));
        return body is string text ? Json.Read<T>(text) : null;
    }
    public T Required<T>(Guid id) where T : class, IEntity => Get<T>(id) ?? throw new BusinessException("El registro no existe.");
    public T[] All<T>() where T : class, IEntity
    {
        using var command = Command("SELECT body FROM records WHERE kind=$kind ORDER BY updated_at DESC,id", ("$kind", typeof(T).Name));
        using var r = command.ExecuteReader(); var rows = new List<T>();
        while (r.Read()) rows.Add(Json.Read<T>(r.GetString(0))); return rows.ToArray();
    }
    public void Put<T>(T item, long expectedVersion, bool publish = true) where T : class, IEntity
    {
        if (item.Id == Guid.Empty || item.Version != expectedVersion + 1) throw new BusinessException("Versión de registro inválida.");
        var body = Json.Write(item); var kind = typeof(T).Name; int changed;
        if (expectedVersion == 0)
            changed = Execute("INSERT INTO records(kind,id,version,body,updated_at) VALUES($kind,$id,$v,$body,$at)", ("$kind", kind), ("$id", item.Id.ToString()), ("$v", item.Version), ("$body", body), ("$at", Now.ToString("O")));
        else
        {
            if (item is StockMovement or CashMovement or Refund or AuditEntry or Purchase)
                throw new BusinessException("Los movimientos confirmados son inmutables.");
            changed = Execute("UPDATE records SET version=$v,body=$body,updated_at=$at WHERE kind=$kind AND id=$id AND version=$expected", ("$v", item.Version), ("$body", body), ("$at", Now.ToString("O")), ("$kind", kind), ("$id", item.Id.ToString()), ("$expected", expectedVersion));
        }
        if (changed != 1) throw new BusinessException("Otro proceso modificó el registro. Actualizá y reintentá.");
        if (publish) Execute("INSERT INTO outbox(event_id,kind,entity_id,version,payload,payload_hash,occurred_at) VALUES($event,$kind,$id,$v,$body,$hash,$at)",
            ("$event", Guid.NewGuid().ToString()), ("$kind", kind), ("$id", item.Id.ToString()), ("$v", item.Version), ("$body", body), ("$hash", Json.Hash(body)), ("$at", Now.ToString("O")));
    }
    public long NextNumber(string name)
    {
        Execute("INSERT INTO counters(name,value) VALUES($name,1) ON CONFLICT(name) DO UPDATE SET value=value+1", ("$name", name));
        return Convert.ToInt64(Scalar("SELECT value FROM counters WHERE name=$name", ("$name", name)));
    }
    public T? Previous<T>(Guid requestId, string requestHash) where T : class, IEntity
    {
        using var cmd = Command("SELECT request_hash,result_kind,result_id FROM idempotency WHERE request_id=$id", ("$id", requestId.ToString()));
        using var r = cmd.ExecuteReader(); if (!r.Read()) return null;
        if (r.GetString(0) != requestHash || r.GetString(1) != typeof(T).Name)
            throw new BusinessException("El identificador ya se usó para una operación diferente.");
        var resultId = Guid.Parse(r.GetString(2)); r.Close(); return Required<T>(resultId);
    }
    public void Remember<T>(Guid requestId, string requestHash, T result) where T : class, IEntity
        => Execute("INSERT INTO idempotency(request_id,request_hash,result_kind,result_id) VALUES($id,$hash,$kind,$result)", ("$id", requestId.ToString()), ("$hash", requestHash), ("$kind", typeof(T).Name), ("$result", result.Id.ToString()));
    public void Audit(Actor actor, Guid device, string action, Guid entity, object? before, object? after)
        => Put(new AuditEntry(Guid.NewGuid(), 1, actor.Id, device, Now, action, entity.ToString(), Json.Write(before), Json.Write(after)), 0);
}
