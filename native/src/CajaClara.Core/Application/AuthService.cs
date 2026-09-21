using System.Security.Cryptography;

namespace CajaClara.Core;

public sealed record UserSummary(Guid Id, string Username, string Name, Role Role, bool Active);
internal sealed record UserSecret(UserSummary User, string PasswordHash, int FailedAttempts, DateTimeOffset? LockedUntil, string? PinHash);
public static class Passwords
{
    private const int Iterations = 600_000;
    public static string Hash(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(16);
        var hash = Rfc2898DeriveBytes.Pbkdf2(password, salt, Iterations, HashAlgorithmName.SHA256, 32);
        return $"{Iterations}${Convert.ToBase64String(salt)}${Convert.ToBase64String(hash)}";
    }
    public static bool Verify(string password, string encoded)
    {
        try
        {
            var parts = encoded.Split('$');
            if (parts.Length != 3 || !int.TryParse(parts[0], out var iterations) || iterations is < 100_000 or > 2_000_000) return false;
            var expected = Convert.FromBase64String(parts[2]);
            var actual = Rfc2898DeriveBytes.Pbkdf2(password, Convert.FromBase64String(parts[1]), iterations, HashAlgorithmName.SHA256, expected.Length);
            return CryptographicOperations.FixedTimeEquals(expected, actual);
        }
        catch (FormatException) { return false; }
    }
    public static void Validate(string password)
    { if (password.Length is < 12 or > 256) throw new BusinessException("La contraseña debe tener entre 12 y 256 caracteres."); }
}
public sealed class AuthService(Store store)
{
    private static readonly string DummyHash = Passwords.Hash(Convert.ToHexString(RandomNumberGenerator.GetBytes(24)));
    internal static UserSecret? Find(DbTx tx, string username)
    {
        using var cmd = tx.Command("SELECT id,username,name,role,active,password_hash,failed_attempts,locked_until,pin_hash FROM users WHERE username=$username", ("$username", username));
        using var r = cmd.ExecuteReader(); if (!r.Read()) return null;
        return new(new(Guid.Parse(r.GetString(0)), r.GetString(1), r.GetString(2), Enum.Parse<Role>(r.GetString(3)), r.GetInt32(4) == 1),
            r.GetString(5), r.GetInt32(6), r.IsDBNull(7) ? null : DateTimeOffset.Parse(r.GetString(7)), r.IsDBNull(8) ? null : r.GetString(8));
    }
    internal static Actor Require(DbTx tx, Actor actor, params Role[] roles)
    {
        using var cmd = tx.Command("SELECT name,role,active FROM users WHERE id=$id", ("$id", actor.Id.ToString()));
        using var r = cmd.ExecuteReader();
        if (!r.Read() || r.GetInt32(2) != 1) throw new BusinessException("La sesión no está autorizada.");
        var actual = new Actor(actor.Id, r.GetString(0), Enum.Parse<Role>(r.GetString(1)));
        if (roles.Length > 0 && !roles.Contains(actual.Role)) throw new BusinessException("No tenés permiso para esta operación.");
        return actual;
    }
    public Actor Authenticate(string username, string password)
    {
        if (username.Length > 80 || password.Length > 256) throw new BusinessException("Credenciales inválidas.");
        var actor = store.Write(tx =>
        {
            var secret = Find(tx, username.Trim());
            if (secret is null) { Passwords.Verify(password, DummyHash); return null; }
            if (secret.LockedUntil > tx.Now || !secret.User.Active) return null;
            if (!Passwords.Verify(password, secret.PasswordHash))
            {
                var attempts = secret.FailedAttempts + 1;
                tx.Execute("UPDATE users SET failed_attempts=$n,locked_until=$until WHERE id=$id", ("$n", attempts),
                    ("$until", attempts >= 5 ? (tx.Now + TimeSpan.FromMinutes(15)).ToString("O") : null), ("$id", secret.User.Id.ToString()));
                return null;
            }
            tx.Execute("UPDATE users SET failed_attempts=0,locked_until=NULL WHERE id=$id", ("$id", secret.User.Id.ToString()));
            return new Actor(secret.User.Id, secret.User.Name, secret.User.Role);
        });
        return actor ?? throw new BusinessException("Credenciales inválidas o acceso temporalmente bloqueado.");
    }
    public Actor Bootstrap(string businessName, string ownerName, string username, string password, bool demo = false)
    {
        Passwords.Validate(password);
        if (string.IsNullOrWhiteSpace(businessName) || string.IsNullOrWhiteSpace(ownerName) || string.IsNullOrWhiteSpace(username))
            throw new BusinessException("Completá comercio, nombre y usuario.");
        if (businessName.Length > 160 || ownerName.Length > 100 || username.Length > 80)
            throw new BusinessException("Nombre demasiado largo.");
        var hash = Passwords.Hash(password);
        return store.Write(tx =>
        {
            if (tx.All<Business>().Length != 0 || Convert.ToInt32(tx.Scalar("SELECT COUNT(*) FROM users")) != 0)
                throw new BusinessException("Este comercio ya está configurado.");
            var actor = new Actor(Guid.NewGuid(), ownerName.Trim(), Role.Owner);
            tx.Execute("INSERT INTO users(id,username,name,password_hash,role,active,updated_at) VALUES($id,$username,$name,$hash,'Owner',1,$at)",
                ("$id", actor.Id.ToString()), ("$username", username.Trim()), ("$name", actor.Name), ("$hash", hash), ("$at", tx.Now.ToString("O")));
            var business = new Business(Guid.NewGuid(), 1, businessName.Trim(), "", "", "Sin configurar", Guid.NewGuid(), demo);
            tx.Put(business, 0); tx.Audit(actor, business.DeviceId, "BUSINESS_CREATED", business.Id, null, business);
            return actor;
        });
    }
    public UserSummary[] Users(Actor actor) => store.Read(tx =>
    {
        Require(tx, actor, Role.Owner, Role.Admin);
        using var cmd = tx.Command("SELECT id,username,name,role,active FROM users ORDER BY name");
        using var r = cmd.ExecuteReader(); var result = new List<UserSummary>();
        while (r.Read()) result.Add(new(Guid.Parse(r.GetString(0)), r.GetString(1), r.GetString(2), Enum.Parse<Role>(r.GetString(3)), r.GetInt32(4) == 1));
        return result.ToArray();
    });
    public UserSummary AddUser(Actor actor, string username, string name, Role role, string password)
    {
        Passwords.Validate(password);
        if (string.IsNullOrWhiteSpace(username) || username.Length > 80 || string.IsNullOrWhiteSpace(name) || name.Length > 100 || !Enum.IsDefined(role))
            throw new BusinessException("Datos de usuario inválidos.");
        var hash = Passwords.Hash(password);
        return store.Write(tx =>
        {
            var current = Require(tx, actor, Role.Owner, Role.Admin);
            if (current.Role != Role.Owner && role is Role.Owner or Role.Admin) throw new BusinessException("Solo el dueño puede crear administradores.");
            var result = new UserSummary(Guid.NewGuid(), username.Trim(), name.Trim(), role, true);
            tx.Execute("INSERT INTO users(id,username,name,password_hash,role,active,updated_at) VALUES($id,$username,$name,$hash,$role,1,$at)",
                ("$id", result.Id.ToString()), ("$username", result.Username), ("$name", result.Name), ("$hash", hash), ("$role", role.ToString()), ("$at", tx.Now.ToString("O")));
            tx.Audit(current, tx.All<Business>().Single().DeviceId, "USER_CREATED", result.Id, null, result);
            return result;
        });
    }
    public void SetActive(Actor actor, Guid userId, bool active) => store.Write(tx =>
    {
        var current = Require(tx, actor, Role.Owner);
        if (actor.Id == userId && !active) throw new BusinessException("No podés desactivar tu propia sesión.");
        if (tx.Execute("UPDATE users SET active=$active,updated_at=$at WHERE id=$id", ("$active", active ? 1 : 0), ("$at", tx.Now.ToString("O")), ("$id", userId.ToString())) != 1)
            throw new BusinessException("Usuario inexistente.");
        tx.Audit(current, tx.All<Business>().Single().DeviceId, "USER_ACTIVE_CHANGED", userId, null, new { active });
    });
    public void SetPin(Actor actor, string pin)
    {
        if (pin.Length != 6 || pin.Any(c => !char.IsAsciiDigit(c))) throw new BusinessException("El PIN debe tener seis dígitos.");
        var hash = Passwords.Hash(pin);
        store.Write(tx => { Require(tx, actor); tx.Execute("UPDATE users SET pin_hash=$hash WHERE id=$id", ("$hash", hash), ("$id", actor.Id.ToString())); });
    }
    public bool Unlock(Actor actor, string pin) => store.Write(tx =>
    {
        Require(tx, actor);
        using var cmd = tx.Command("SELECT pin_hash,failed_attempts,locked_until FROM users WHERE id=$id", ("$id", actor.Id.ToString()));
        using var r = cmd.ExecuteReader(); if (!r.Read() || r.IsDBNull(0)) return false;
        var hash = r.GetString(0); var failed = r.GetInt32(1); var locked = r.IsDBNull(2) ? (DateTimeOffset?)null : DateTimeOffset.Parse(r.GetString(2)); r.Close();
        if (locked > tx.Now) return false;
        var valid = pin.Length <= 256 && Passwords.Verify(pin, hash);
        tx.Execute("UPDATE users SET failed_attempts=$n,locked_until=$until WHERE id=$id", ("$n", valid ? 0 : failed + 1),
            ("$until", !valid && failed + 1 >= 5 ? (tx.Now + TimeSpan.FromMinutes(15)).ToString("O") : null), ("$id", actor.Id.ToString()));
        return valid;
    });
}
