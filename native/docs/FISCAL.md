# Facturación argentina: estado real

**Estado de esta entrega: NO IMPLEMENTADA como integración fiscal operativa.**

`FiscalDocument` y `FiscalState` separan venta comercial, solicitud pendiente y autorización. La opción de facturación en el POS crea un registro pendiente con CAE y numeración vacíos. No solicita autorización a ARCA y no transforma el ticket interno en factura. Configuración y comprobantes informan esta limitación.

No hay WSAA/CMS, gestión de certificados fiscales, cliente WSFE, emisión A/B/C, notas de crédito/débito, recuperación de autorización incierta, CAEA ni QR fiscal. No corresponde informar `PENDING_CREDENTIALS` como si bastara ingresar una clave: falta desarrollar y homologar la integración.

## Documentación oficial consultada

- Índice oficial WSFE: https://www.afip.gob.ar/ws/documentacion/ws-factura-electronica.asp
- Manual oficial de comprobantes: https://www.afip.gob.ar/ws/documentacion/manuales/manual-desarrollador-ARCA-COMPG.pdf
- Especificación WSAA: https://www.afip.gob.ar/ws/WSAA/Especificacion_Tecnica_WSAA_1.2.2.pdf
- Especificaciones del QR: https://www.afip.gob.ar/fe/qr/especificaciones.asp

Las reglas, catálogos, campos obligatorios y límites deben verificarse contra la documentación vigente antes de implementar. Este documento no certifica cumplimiento normativo ni habilita emisión fiscal.

## Condiciones de aceptación pendientes

Separar estrictamente homologación/producción y credenciales, reservar numeración por CUIT/punto/tipo, persistir intento antes de transmitir y consultar comprobantes autorizados cuando una respuesta sea incierta. Nunca reemitir a ciegas después de un timeout. Validar configuración del emisor, condición IVA del receptor, moneda, impuestos y asociaciones de notas.

Un comprobante solo puede marcarse autorizado con respuesta validada del organismo. El PDF fiscal debe usar los datos realmente autorizados y el QR oficial correspondiente. La numeración interna `Sale.Number` no sirve como numeración fiscal.

Las ventas comerciales offline y su documentación requieren definir la modalidad fiscal legal del comercio con su profesional contable. Una cola técnica pendiente no reemplaza un régimen de contingencia autorizado. No usar esta entrega como único sistema de facturación del negocio.
