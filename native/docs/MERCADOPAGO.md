# Pagos y Mercado Pago: estado real

## Implementado

Cobro comercial en efectivo y registro manual de transferencias, débito, crédito y Mercado Pago. Pagos combinados, referencia obligatoria para electrónicos, vuelto solo en efectivo y cierre por medio de pago. La pantalla exige confirmar que el operador verificó externamente el cobro. Los pagos electrónicos conservan `MANUAL_UNVERIFIED`; no se presentan como confirmación del banco o proveedor.

La devolución total registra la compensación comercial y de stock. No ejecuta un reembolso en Mercado Pago ni en una terminal bancaria. El operador debe devolver el dinero externamente y registrar la operación con responsabilidad.

## No implementado

OAuth/PKCE de vendedores, almacenamiento backend de access/refresh tokens, órdenes QR dinámicas, integración Point, webhooks autenticados, conciliación, reembolsos por API y `PaymentProvider` operativo. No basta aportar credenciales para habilitar estas capacidades.

## Referencias oficiales consultadas

- API de órdenes QR: https://www.mercadopago.com.ar/developers/en/reference/in-person-payments/qr-code/orders/create-order/post
- Notificaciones: https://www.mercadopago.com.ar/developers/en/docs/your-integrations/notifications/webhooks

La integración siguiente debe utilizar el producto y contrato vigente para el país y la cuenta del comercio. No mezclar ejemplos de Payments API con estados de Orders API. La autorización comercial, tienda/POS, hardware y webhooks públicos pueden ser requisitos externos.

## Requisitos para aceptar pagos integrados

Estado servidor como autoridad; claves de idempotencia para crear/capturar/devolver; verificación del origen de notificaciones según el producto; consulta autenticada al proveedor; comprobación de vendedor, moneda, monto y referencia antes de confirmar; libro de conciliación y manejo de pagos tardíos, duplicados, parciales o reversados. Ningún cambio de pantalla o parámetro del cliente debe poder declarar un pago aprobado.

No se utilizaron cuentas productivas, no se ejecutaron cobros y no se crearon transacciones financieras externas durante las pruebas de este proyecto.
