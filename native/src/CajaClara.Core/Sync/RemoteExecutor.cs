namespace CajaClara.Core;

public sealed class RemoteExecutor(Store store)
{
    public static readonly string[] AllowedTypes = ["UPDATE_PRODUCT_PRICE", "DISABLE_PRODUCT", "ENABLE_PRODUCT", "REQUEST_CASH_CLOSING", "REQUEST_SYNC"];
    public RemoteCommand Execute(RemoteCommand command)
    {
        var requestHash = Json.Hash(Json.Write(command with { Status = RemoteStatus.Pending, Result = "" }));
        return store.Write(tx =>
        {
            using (var query = tx.Command("SELECT request_hash,status,result FROM remote_receipts WHERE command_id=$id", ("$id", command.Id.ToString())))
            using (var reader = query.ExecuteReader())
            {
                if (reader.Read())
                {
                    if (reader.GetString(0) != requestHash) throw new BusinessException("El comando fue reutilizado con otros datos.");
                    return command with { Status = Enum.Parse<RemoteStatus>(reader.GetString(1)), Result = reader.GetString(2) };
                }
            }
            var business = tx.All<Business>().Single();
            string? rejection = command.BusinessId != business.Id || command.TargetDeviceId != business.DeviceId
                ? "El comando no pertenece a este comercio y equipo." : null;
            if (!AllowedTypes.Contains(command.Type) || command.Payload.Length > 4096) rejection = "Tipo o contenido no permitido.";
            if (command.RequestedAt > tx.Now.AddMinutes(5) || command.ExpiresAt <= command.RequestedAt || command.ExpiresAt - command.RequestedAt > TimeSpan.FromDays(1))
                rejection = "Vigencia del comando inválida.";
            var status = command.ExpiresAt <= tx.Now ? RemoteStatus.Expired : rejection is null ? RemoteStatus.Completed : RemoteStatus.Rejected;
            var result = rejection ?? (status == RemoteStatus.Expired ? "La autorización venció sin ejecutarse." : "Aplicado.");
            if (status == RemoteStatus.Completed)
            {
                try
                {
                    var actor = new Actor(Guid.Empty, command.RequestedBy, Role.Owner);
                    switch (command.Type)
                    {
                        case "UPDATE_PRODUCT_PRICE":
                            var price = Json.Read<PriceCommand>(command.Payload); Money.Valid(price.PriceCents, false);
                            var product = tx.Required<Product>(price.ProductId);
                            if (product.Version != price.ExpectedVersion) throw new BusinessException("El producto cambió; solicitá nuevamente el precio.");
                            var updated = product with { Version = product.Version + 1, PriceCents = price.PriceCents };
                            tx.Put(updated, product.Version); tx.Audit(actor, business.DeviceId, "REMOTE_PRICE:" + command.RequestedBy, product.Id, product, updated); break;
                        case "ENABLE_PRODUCT":
                        case "DISABLE_PRODUCT":
                            var active = Json.Read<ActiveCommand>(command.Payload); var old = tx.Required<Product>(active.ProductId);
                            if (old.Version != active.ExpectedVersion || active.Active != (command.Type == "ENABLE_PRODUCT")) throw new BusinessException("Conflicto de versión o estado.");
                            var next = old with { Version = old.Version + 1, Active = active.Active };
                            tx.Put(next, old.Version); tx.Audit(actor, business.DeviceId, "REMOTE_ACTIVE:" + command.RequestedBy, old.Id, old, next); break;
                        case "REQUEST_CASH_CLOSING":
                            var cash = tx.All<CashSession>().SingleOrDefault(x => x.State != CashState.Closed && x.DeviceId == business.DeviceId)
                                ?? throw new BusinessException("La caja ya está cerrada.");
                            tx.Put(cash with { Version = cash.Version + 1, State = CashState.ClosingRequested }, cash.Version);
                            tx.Put(new Notification(Guid.NewGuid(), 1, "El dueño solicitó el cierre de caja", "Contá el efectivo y cerrá el turno desde Caja. No se cerró automáticamente.", tx.Now, false), 0);
                            tx.Audit(actor, business.DeviceId, "REMOTE_CLOSING_REQUEST:" + command.RequestedBy, cash.Id, cash.State, CashState.ClosingRequested);
                            result = "Solicitud recibida; falta conteo y cierre por el cajero."; break;
                        case "REQUEST_SYNC":
                            tx.Execute("UPDATE outbox SET next_attempt_at=NULL WHERE sent_at IS NULL");
                            tx.Audit(actor, business.DeviceId, "REMOTE_SYNC:" + command.RequestedBy, business.Id, null, command.Id); break;
                    }
                }
                catch (Exception e) when (e is BusinessException or System.Text.Json.JsonException or OverflowException)
                { throw new RemoteValidationException(command, requestHash, e is BusinessException ? e.Message : "Contenido de comando inválido."); }
            }
            tx.Execute("INSERT INTO remote_receipts(command_id,request_hash,status,result,processed_at) VALUES($id,$hash,$status,$result,$at)",
                ("$id", command.Id.ToString()), ("$hash", requestHash), ("$status", status.ToString()), ("$result", result), ("$at", tx.Now.ToString("O")));
            return command with { Status = status, Result = result };
        });
    }
    public RemoteCommand ExecuteSafely(RemoteCommand command)
    {
        try { return Execute(command); }
        catch (RemoteValidationException error)
        {
            return store.Write(tx =>
            {
                tx.Execute("INSERT OR IGNORE INTO remote_receipts(command_id,request_hash,status,result,processed_at) VALUES($id,$hash,'Rejected',$result,$at)",
                    ("$id", command.Id.ToString()), ("$hash", error.RequestHash), ("$result", error.Message), ("$at", tx.Now.ToString("O")));
                return command with { Status = RemoteStatus.Rejected, Result = error.Message };
            });
        }
    }
    public void Acknowledge(Guid commandId) => store.Write(tx => tx.Execute("UPDATE remote_receipts SET acknowledged=1 WHERE command_id=$id", ("$id", commandId.ToString())));
    private sealed class RemoteValidationException(RemoteCommand command, string hash, string message) : Exception(message)
    { public RemoteCommand Command { get; } = command; public string RequestHash { get; } = hash; }
}
