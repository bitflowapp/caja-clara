# Sincronización

## Salida de la PC

Todo cambio publica un evento `SyncEnvelope` en la misma transacción local. Incluye secuencia local, UUID de evento, tipo, UUID de entidad, versión, JSON, hash SHA-256 y fecha UTC. Las ventas y movimientos no dependen de que se pueda transmitirlo.

`SyncClient` transmite lotes de hasta 100 eventos cada ocho segundos en condiciones normales. Solo marca como enviados los UUID confirmados por el servidor y valida que pertenezcan al lote. Un error conserva los eventos. El bucle reintenta con backoff exponencial y jitter hasta cinco minutos; la configuración incluye reintento manual.

El servidor vincula bearer token, comercio y equipo. Valida identidad, versión y hash del contenido y aplica eventos/proyecciones en una transacción. Repetir un evento idéntico no duplica una venta. Un UUID con contenido diferente o una versión incompatible produce conflicto, no sobrescritura silenciosa.

## Entrada a la PC

La PC consulta comandos por HTTPS saliente. La aplicación del cambio y el recibo local del comando comparten transacción. Una caída después de aplicar el cambio pero antes del ACK permite reenviar el resultado sin aplicar el efecto otra vez.

Los estados finales se registran localmente y en el servidor. El celular muestra Pendiente/Recibido/Aplicado/Rechazado/Vencido, sin confundir una solicitud enviada con una acción ejecutada.

## Límites

No existe sincronización de usuarios locales ni sus hashes al cloud. No existe política multi-master de stock entre dos cajas: el servidor permite una caja primaria. Los precios remotos requieren `expectedVersion` para evitar pisar cambios locales.

Una restauración local antigua puede reintroducir versiones ya superadas en el servidor. Por eso se deshabilita el vínculo durante la restauración; falta una herramienta de conciliación asistida de historiales. No eliminar eventos ni editar SQLite manualmente para ocultar un conflicto.

Para que una venta nueva aparezca en el celular deben estar ejecutándose la aplicación/cliente de sincronización y el servidor. Con la PC apagada, el panel conserva lo último confirmado; no puede ejecutar cambios locales hasta que vuelva a conectarse.
