# Caja Clara Control

## Preparación

Desplegar `CajaClara.Backend` en un equipo o servidor estable con HTTPS y almacenamiento persistente. Crear la cuenta del dueño ejecutando `CajaClara.Backend.exe --init` en el host del servidor. La creación no está expuesta en una ruta HTTP pública. Ver DEPLOYMENT.md.

Abrir la URL del servidor en el navegador del teléfono, iniciar sesión y entrar en Equipos. Generar un código. En la PC: Configuración → Panel remoto → Vincular dispositivo. Ingresar la misma URL HTTPS y el código dentro de cinco minutos. La PC almacena su credencial mediante DPAPI; el dueño no necesita conocerla.

El comercio y catálogo se obtienen de la sincronización real. Una pantalla sin ventas después de vincular no se llena con datos de muestra. El estado muestra último contacto de la PC y diferencia conexión del teléfono de actualización de la caja.

## Acciones presentes

`UPDATE_PRODUCT_PRICE`: precio en centavos y versión esperada. `ENABLE_PRODUCT` y `DISABLE_PRODUCT`: disponibilidad y versión esperada. `REQUEST_CASH_CLOSING`: solicita al cajero contar y cerrar, sin inventar efectivo contado. `REQUEST_SYNC`: habilita el reintento de pendientes.

No están implementadas `AUTHORIZE_DISCOUNT` ni `AUTHORIZE_REFUND`. Descuentos y devoluciones locales se autorizan mediante el rol local. El servidor rechaza tipos de comando no admitidos.

Cada solicitud usa UUID, equipo destino, identidad del dueño, fecha y vencimiento de quince minutos. Los reintentos idénticos conservan la identidad y el resultado. No hay pantalla compartida, RDP ni ejecución de comandos del sistema operativo.

## Móvil y operación offline

El frontend es responsive y tiene manifiesto/service worker para instalación web cuando el navegador lo admita. Se probaron viewports móvil y escritorio con Chromium; no se certificó instalación en un iPhone físico ni comportamiento de todas las versiones de Safari.

El service worker conserva únicamente archivos estáticos. No guarda ventas ni datos sensibles en caché offline. Al perder conexión, los datos que siguen visibles están señalados como la última consulta; no se habilitan cambios silenciosos desde una copia obsoleta.

Una caja revocada conserva sus datos y su capacidad local. Su siguiente solicitud de sincronización será rechazada. Revocar el equipo desde el panel no borra la computadora ni elimina ventas.
