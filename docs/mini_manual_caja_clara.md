# Mini manual de Caja Clara

## Que es Caja Clara

Caja Clara es una app simple para comercios chicos que necesitan registrar ventas, gastos, productos y caja desde un solo lugar.

## Para que sirve

Sirve para operar el dia a dia con menos friccion: vender, anotar gastos, controlar stock, revisar caja y exportar la informacion cuando hace falta.

## Que podes hacer con la app

- cargar y editar productos
- registrar ventas con impacto en stock y caja
- registrar gastos con impacto en caja
- usar codigo de barras con camara, scanner o ingreso manual
- ver movimientos recientes y stock bajo
- exportar Excel y guardar backup local

## Paso 1: cargar productos

Abre `Productos` o usa `Agregar producto` desde Inicio.
Completa nombre, stock, stock minimo, costo y precio.
Si ya trabajas con codigo de barras, cargalo ahi mismo para acelerar ventas y reposicion.

## Paso 2: registrar ventas

Toca `Nueva venta`.
Busca el producto, ajusta la cantidad y confirma el medio de pago.
Al guardar, la venta suma a caja, descuenta stock y aparece en movimientos.

## Paso 3: registrar gastos

Toca `Registrar gasto`.
Escribe un concepto corto, el monto y una categoria si te sirve ordenarlo mejor.
Al guardar, el gasto se resta de caja y queda registrado en movimientos.

## Paso 4: usar codigo de barras o ingreso manual

Toca `Escanear producto`.
Si el producto existe, puedes vender o agregar stock desde ahi.
Si no existe, Caja Clara te deja crear el producto con el codigo ya cargado.
En Windows tambien puedes usar scanner tipo teclado o escribir el codigo manualmente.

## Paso 5: exportar la informacion

Desde `Caja / Resumen` puedes exportar Excel con resumen, productos, ventas, gastos y movimientos.
Tambien puedes guardar un backup JSON para resguardar el estado completo de la app.

## Consejos rapidos

- carga bien costo y precio para que el resumen tenga mas sentido
- usa stock minimo para detectar reposicion a tiempo
- exporta Excel o backup con regularidad
- si vendes mucho por scanner, agrega barcode a los productos desde el inicio

## Checklist corta de prueba en Windows

1. Instala con `Instalar Caja Clara.cmd` o, si no quieres instalar, abre Caja Clara desde la carpeta portable completa.
2. Confirma que la pantalla Inicio cargue y que el estado de prueba o licencia sea visible.
3. Entra a `Productos` o usa `Agregar producto` para validar que el catalogo responde.
4. Registra una venta o un gasto de prueba y revisa el mensaje final.
5. Si usas scanner tipo teclado, enfoca el campo de barcode, escanea y confirma que Enter resuelve el flujo.

## Errores comunes y como resolverlos

**No encuentro un producto**
Revisa nombre, categoria o barcode. Si no existe, puedes darlo de alta desde el flujo de barcode o desde Productos.

**No me deja vender**
Suele pasar por stock insuficiente o cantidad invalida. Corrige la cantidad o revisa el stock del producto.

**No se exporta el archivo**
Vuelve a intentar y revisa el mensaje en pantalla. En web la descarga depende del navegador; en Windows puedes elegir la ubicacion del archivo.

**Restaure un backup y cambio el estado**
Es normal: restaurar reemplaza el estado actual por el contenido del archivo elegido.

## Resumen final de valor

Caja Clara sirve para ordenar lo esencial de un comercio chico sin volverse un sistema pesado.
Te ayuda a vender, registrar gastos, entender la caja y llevarte la informacion sin perder tiempo.
