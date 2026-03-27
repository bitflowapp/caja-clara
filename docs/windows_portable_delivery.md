# Entrega Windows portable

## Camino recomendado

Para probar o entregar Caja Clara en Windows, usa la version portable.

Opciones validas:

- copiar la carpeta `dist/windows-portable/CajaClara/`
- o descomprimir `dist/windows-portable/CajaClara-win64.zip`

Luego abre `CajaClara.exe` desde esa carpeta completa.

## Que debe viajar junto

No copies solo el ejecutable. La carpeta debe conservar:

- `CajaClara.exe`
- `flutter_windows.dll`
- `file_selector_windows_plugin.dll`
- `native_assets.json`
- `data/`

Si falta alguno de esos archivos, la app puede no abrir o quedar incompleta.

## Primer arranque recomendado

1. abrir `CajaClara.exe`
2. esperar a que cargue `Inicio`
3. confirmar que el estado de prueba o licencia quede visible
4. revisar que aparezcan las acciones principales: venta, gasto, scanner y productos

## Checklist manual corta

1. `Inicio` abre sin crash
2. `Productos` o `Agregar producto` responde
3. `Nueva venta` o `Registrar gasto` muestra feedback final
4. el scanner manual o tipo teclado puede enfocar barcode y resolver el flujo
5. `Caja / Resumen` abre y refleja movimientos si ya existen

## Trial y activacion

- la prueba dura 30 dias
- si vence, la app queda en solo lectura
- los datos siguen visibles y exportables
- para operar de nuevo, se activa desde la propia app con el ID de instalacion

## MSIX hoy

El `.msix` queda como opcion adicional, no como camino principal de entrega.

Estado real de esta etapa:

- el paquete se genera bien
- en una PC sin el certificado de desarrollo en confianza, Windows puede bloquear la instalacion
- en la prueba real sobre esta maquina, `Add-AppxPackage` devolvio `0x800B0109`

Por eso, para demo, prueba comercial o entrega rapida, la recomendacion sigue siendo el paquete portable.
