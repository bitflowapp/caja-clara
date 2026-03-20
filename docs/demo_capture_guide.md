# Demo Capture Guide

![Caja Clara](../assets/branding/caja_clara_logo.png)

Guia corta para mostrar Caja Clara como producto inicial real, claro y listo para demo.

## Objetivo de la captura

La demo tiene que dejar ver tres cosas en pocos minutos:

- operacion diaria simple
- control real de caja y stock
- lookup rapido por barcode
- funciones de resguardo y export listas para usar

## Orden exacto de screenshots

1. Home desktop
2. Home mobile web
3. Productos
4. Barcode encontrado
5. Barcode no encontrado
6. Crear producto con barcode precargado
7. Nueva venta desde barcode
8. Agregar stock desde barcode
9. Registrar gasto
10. Resumen / caja
11. Exportacion Excel
12. Backup / restore

## Estado seed recomendado

Usar el estado inicial de la app y sumar solo estas acciones antes de capturar:

1. Registrar una venta simple con un producto visible.
2. Registrar un gasto simple con categoria clara.
3. Probar una busqueda por barcode de un producto existente.
4. Probar un barcode que no exista para mostrar alta nueva.
5. Abrir el alta con barcode precargado.
6. Probar una venta desde barcode encontrado.
7. Probar agregar stock desde barcode encontrado.
8. Registrar apertura de caja del dia.
9. Ejecutar exportacion Excel.
10. Ejecutar exportacion de backup.

Eso deja la app en un estado bueno para demo:

- productos visibles
- barcode visible en al menos un producto
- un producto existente con barcode conocido
- un codigo de prueba no encontrado
- stock bajo visible
- movimientos recientes reales
- caja con actividad
- resumen con apertura y caja esperada
- acciones de export y backup listas para mostrar

## Viewports recomendados

### Desktop

- Windows app maximizada
- alternativa: ventana `1440 x 900`
- zoom del sistema `100%`

### Mobile web

- Chrome con Device Toolbar
- viewport `390 x 844`
- zoom `100%`

## Pantallas a capturar

### 1. Home desktop

- tab `Inicio`
- header visible
- CTA `Nueva venta`
- CTA secundaria `Exportar Excel`
- inicio de `Ultimos movimientos`

### 2. Home mobile web

- tab `Inicio`
- viewport `390 x 844`
- header compacto
- CTA `Nueva venta`
- inicio de movimientos si entra en pantalla

### 3. Productos

- tab `Productos`
- busqueda vacia
- filtro `Solo bajo stock` apagado
- 3 a 5 productos visibles

### 4. Barcode encontrado

- abrir `Escanear producto`
- mostrar producto encontrado
- dejar visibles `Registrar venta` y `Agregar stock`
- nombre grande, barcode secundario
- precio y stock legibles

### 5. Barcode no encontrado

- abrir `Escanear producto`
- ingresar un codigo que no exista
- mostrar `No esta en catalogo`
- dejar visible `Crear producto`

### 6. Crear producto con barcode precargado

- desde `Barcode no encontrado`
- abrir `Crear producto`
- dejar visible el campo `Codigo de barras` ya completo
- no completar guardado si solo quieres la captura

### 7. Nueva venta desde barcode

- abrir desde `Barcode encontrado`
- producto ya resuelto
- cantidad `2`
- medio de pago `Efectivo`
- resumen visible

### 8. Agregar stock desde barcode

- abrir desde `Barcode encontrado`
- mostrar dialogo `Agregar stock`
- dejar visible el nombre del producto
- cantidad corta, por ejemplo `6`

### 9. Registrar gasto

- abrir desde `Registrar gasto`
- concepto corto, por ejemplo `Reposicion rapida`
- categoria `Insumos`
- monto visible
- bloque de fecha y hora visible

### 10. Resumen / caja

- tab `Caja`
- botones operativos visibles
- apertura del dia
- caja esperada
- cierre registrado si ya existe
- inicio de movimientos

### 11. Exportacion Excel

- tab `Caja`
- boton `Exportar Excel` visible
- si haces captura de accion, tomarla con snackbar de exito en desktop o con descarga iniciada en web

### 12. Backup / restore

- tab `Caja`
- botones `Exportar backup` y `Restaurar backup`
- si haces captura de accion, tomarla con snackbar de exito o con dialogo de confirmacion

## Flujo sugerido de demo en vivo

1. Mostrar home desktop.
2. Abrir productos y senalar stock bajo.
3. Probar barcode con un producto existente.
4. Mostrar un barcode no encontrado y el alta precargada.
5. Registrar una venta desde barcode.
6. Mostrar agregar stock desde barcode.
7. Registrar un gasto.
8. Abrir resumen y mostrar impacto en caja y movimientos.
9. Registrar apertura de caja.
10. Mostrar exportacion Excel.
11. Mostrar backup JSON.
12. Mostrar restore y undo como hardening operativo.
13. Cerrar con home mobile web.

## Captura desde Windows app

1. Ejecutar `flutter run --profile -d windows`.
2. Ajustar ventana a `1440 x 900`.
3. Usar `Win + Shift + S`.
4. Guardar en este orden:
   - `01-home-desktop.png`
   - `02-home-mobile-web.png`
   - `03-productos.png`
   - `04-barcode-encontrado.png`
   - `05-barcode-no-encontrado.png`
   - `06-crear-producto-barcode.png`
   - `07-nueva-venta-barcode.png`
   - `08-agregar-stock-barcode.png`
   - `09-registrar-gasto.png`
   - `10-caja-resumen.png`
   - `11-exportar-excel.png`
   - `12-backup-restore.png`

## Captura desde web mobile

1. Ejecutar `flutter run --profile -d chrome`.
2. Abrir DevTools.
3. Activar Device Toolbar.
4. Elegir `390 x 844`.
5. Capturar desde DevTools o desde el sistema operativo.

## Checklist visual antes de mostrar

- no hay snackbars viejos tapando contenido
- no hay cursores activos en campos
- no hay dropdowns abiertos salvo que la toma lo requiera
- los importes entran completos
- la home se entiende en pocos segundos
- `Nueva venta` se ve primero
- `Escanear producto` se ve facil de encontrar
- `Producto encontrado` se entiende sin leer demasiado
- `No esta en catalogo` se ve util, no como error feo
- la caja en resumen muestra datos consistentes
- Excel, backup y restore se ven como acciones reales
- no aparece el badge `DEBUG`

## Checklist exacta para screenshots de barcode

- usar un barcode existente del seed, por ejemplo `7791234500011`
- usar un barcode no encontrado, por ejemplo `7799999999999`
- para `Barcode encontrado`, dejar visible nombre, precio, stock y acciones
- para `Barcode no encontrado`, dejar visible `Crear producto`
- para `Crear producto con barcode precargado`, abrir el modal sin guardar
- para `Nueva venta desde barcode`, entrar desde el flujo barcode y dejar el producto ya resuelto
- para `Agregar stock desde barcode`, dejar visible el dialogo de cantidad
- en desktop, si usas scanner tipo teclado, hacer foco en `Ingresar codigo` antes de disparar la lectura
