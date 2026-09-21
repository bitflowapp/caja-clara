# Base de datos

## Local

Archivo `caja.sqlite`, SQLite con WAL, `synchronous=FULL`, `busy_timeout=15000`, transacciones de escritura inmediatas y consultas parametrizadas. Migración inicial incrustada en `Core/Persistence/schema.sql`; `application_id=1128481603`, `user_version=1`. Se rechazan versiones futuras y archivos con tablas ajenas.

`records(kind,id,version,body,updated_at)` almacena entidades tipadas como JSON validado. La clave primaria combina tipo e UUID. Índices parciales garantizan código de producto único sin distinguir mayúsculas, código de barras no vacío único y una sola empresa. El modelo JSON no equivale a relaciones SQL con FK entre todas las entidades: las referencias comerciales se validan en servicios y transacciones.

Tablas adicionales: `users`, `idempotency`, `counters`, `outbox`, `remote_receipts`. Los usuarios incluyen hash de contraseña/PIN, bloqueo temporal y rol; no se sincronizan sus hashes al servidor. Los contadores comerciales internos no son numeración fiscal.

`Put` exige `version = expectedVersion + 1` y crea el evento de salida dentro de la misma transacción. Reutilizar el UUID de una solicitud con otro contenido falla. Un reintento idéntico devuelve el resultado previo incluso después de cerrar caja.

## Servidor

Archivo independiente `cloud.sqlite`; `application_id=1128481610`. Tablas: `tenants`, `owners`, `devices`, `pair_codes`, `events`, `projections`, `commands`, `server_audit`. Toda consulta de negocio usa `tenant_id`. El token de equipo se guarda únicamente como hash en el servidor.

## Respaldo

Se utiliza la API de backup de SQLite, no una copia incompleta del archivo principal ignorando el WAL. Cada respaldo tiene un manifiesto con SHA-256, comercio, versión y fecha. El manifiesto detecta corrupción accidental; no es una firma digital contra un atacante capaz de cambiar ambos archivos.

La aplicación conserva siete días y cuatro semanas seleccionadas para respaldos automáticos, y no poda los manuales. El respaldo sigue conteniendo información comercial sensible y hashes de usuarios: guardarlo bajo permisos de usuario y cifrado de disco.

## Restauración

La terminal valida integridad, hash, esquema y comercio; exige confirmación explícita y la aplicación cerrada. Antes del reemplazo crea otro backup y conserva la base desplazada. Las credenciales remotas quedan deshabilitadas. Cerrar también otras terminales que escriban en la base; esta edición no certifica restauración simultánea con procesos escritores externos.

No reconectar ciegamente una base antigua al servidor: el servidor conserva eventos posteriores y detectará conflictos de versión. La conciliación y adopción de un historial restaurado requieren procedimiento de soporte; no se implementó un borrado automático del historial remoto.
