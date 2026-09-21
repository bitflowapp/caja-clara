# Caja Clara Native

Edición C#/.NET independiente del producto Flutter existente. **En desarrollo; todavía no autorizada para producción.**

La carpeta `native` no cambia los datos, binarios ni activaciones del producto anterior. La base nativa utiliza un directorio distinto y no importa ni borra las bases Hive de Flutter.

## Estado de esta rama

Núcleo local transaccional con SQLite, ventas, caja, productos, stock, compras, usuarios, auditoría, outbox y comandos remotos tipados. La interfaz Windows, el servicio remoto y las integraciones se incorporan en esta misma rama de trabajo.

Los pagos electrónicos registrados manualmente se identifican como `MANUAL_UNVERIFIED`: no equivalen a confirmación de Mercado Pago o del banco. Un documento fiscal pendiente no equivale a una factura autorizada. Nunca se genera un CAE ficticio.

## Validación

La ejecución de `Caja Clara Native` en GitHub Actions compila con el SDK .NET 10.0.401 sobre un runner Windows. Los resultados reales se conservan en el artefacto de evidencia. Un workflow preparado o en ejecución no significa que las pruebas hayan pasado.

## Procedencia

Base Flutter preservada: commit `ed5a5421e15c50bcffad65da3a7f945fd5f03142` del repositorio `bitflowapp/caja-clara`. Esta edición no reescribe ni migra automáticamente ese producto.
