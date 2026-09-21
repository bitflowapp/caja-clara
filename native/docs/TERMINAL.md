# Terminal de Caja Clara

El paquete contiene `terminal/cajaclara-cli.exe`. Comparte reglas, permisos y base local con la interfaz Windows. No utiliza un motor de ventas distinto.

```powershell
.\cajaclara-cli.exe --help
.\cajaclara-cli.exe status
.\cajaclara-cli.exe products
```

Estos comandos solicitan usuario y contraseña; esta última no se muestra. La base predeterminada es la del comercio real en LocalAppData. Usar `--db` para otra base.

## Automatización

`--json` lee por entrada estándar un objeto con `username`, `password` y `payload`. No pasar secretos en argumentos, URLs o archivos de ejemplo versionados. El proceso devuelve JSON por stdout; errores seguros por stderr y código de salida distinto de cero. Para uso interactivo, `--input ruta.json` contiene solo el payload, sin contraseña.

Importes siempre en **centavos** y cantidades en **milésimas**. UUID de solicitud estable para reintentos de una venta, devolución o compra. No generar un UUID nuevo después de un timeout si se está reintentando la misma operación.

## Contratos de payload

`init`: `businessName`, `ownerName`, `demo` opcional. Crea la cuenta indicada por username/password solo si la base está vacía.

`product-save`: `product` con el registro completo y `expectedVersion`. Para crear, `expectedVersion=0`, UUID nuevo, `version=1`, stock inicial válido y `unit` entre `un/kg/l/m`. `products` devuelve los registros y sus versiones reales.

`stock-adjust`: `productId`, `productVersion`, `deltaMilli`, `reason`. Nunca usar product-save para alterar silenciosamente el stock de un producto existente.

`cash-open` / `cash-close`: `amountCents`, `notes`. `cash-movement`: `amountCents`, `kind` entre `INCOME/EXPENSE/WITHDRAWAL`, `reason`.

`sale`: `id`, `customerId` opcional, `items`, `payments`, `notes`, `requestInvoice` opcional. Cada item contiene `productId`, `productVersion`, `quantityMilli`, `discountCents` opcional y `overridePriceCents` opcional. Cada pago tiene `method`, `appliedCents`, `receivedCents`, `reference`.

Métodos: `Cash`, `Transfer`, `Debit`, `Credit`, `MercadoPagoManual`. Los electrónicos son registros manuales, requieren referencia y recibido igual a aplicado. Efectivo permite recibido mayor a aplicado para vuelto. La suma aplicada debe coincidir exactamente con el total.

`refund`: `id`, `saleId`, `reason`. Solo devolución total, con autorización de administración, caja abierta y devolución bancaria realizada fuera del programa.

`contact-save`: `contact` completo y `expectedVersion`. El contacto incluye nombre, documento/CUIT, teléfono, email, domicilio, `supplier` y `taxCondition`. `contacts` lista los datos existentes.

`purchase`: `id`, `supplierId`, `lines`, `paidFromCashCents`, `reference`. Cada línea: `productId`, `quantityMilli`, `unitCostCents`. Aumenta stock y actualiza costos; los pagos de efectivo afectan la caja.

`report`: `from` y `to` como fechas ISO con offset; límite inferior inclusivo y superior exclusivo. `report-xlsx` agrega `path`. `receipt-pdf`: `saleId`, `path`, `widthMm` (58/80/210). Es un comprobante interno, no una factura fiscal.

`backup` / `backup-validate`: `path` (directorio para backup; archivo para validar). El manifiesto se conserva junto al respaldo.

`restore`: `path`, `confirmReplaceCurrentDatabase=true`. Solo dueño, cerrar aplicación y otras terminales. Se crea un respaldo previo y se deshabilita el vínculo remoto. No usar sin leer DATABASE.md.

`sync-once`: `server`, `deviceToken`. La credencial de dispositivo es secreta: entregarla solo por stdin seguro. La interfaz Windows la conserva cifrada con DPAPI; no se agrega un comando que la imprima.

## Facturación automática

Esta edición no implementa un comando de emisión ARCA. `requestInvoice=true` registra una solicitud pendiente, no una factura autorizada. No programar tareas que consideren la creación de esa solicitud como emisión fiscal exitosa.
