# Entrega Windows portable

## Camino recomendado

Para probar o entregar Caja Clara en Windows, usa la version portable.

Opciones validas:

- copiar la carpeta `dist/windows-portable/CajaClara/`
- o descomprimir `dist/windows-portable/CajaClara-win64.zip`

Luego ejecuta `Instalar Caja Clara.cmd`.

Ese flujo:

- copia Caja Clara a `%LocalAppData%\CajaClara`
- crea `Caja Clara.lnk` en Escritorio
- crea `Caja Clara.lnk` en Inicio
- agrega `Quitar Caja Clara` en Inicio
- abre la app al terminar

Si no quieres instalar, todavia puedes abrir `CajaClara.exe` desde la carpeta portable completa. No copies solo el ejecutable.

## Instalacion simple

1. descomprimir el zip completo
2. hacer doble clic en `Instalar Caja Clara.cmd`
3. esperar a que aparezcan los accesos directos
4. abrir Caja Clara desde Escritorio o Inicio

## Como abrir despues

- Escritorio: `Caja Clara`
- Inicio: `Caja Clara`

Ruta local usada por el instalador:

```text
%LocalAppData%\CajaClara
```

## Como desinstalar

Opciones simples:

- abrir `Quitar Caja Clara` desde Inicio
- o ejecutar `Quitar Caja Clara.cmd`

El script:

- elimina los accesos directos de Escritorio e Inicio
- puede eliminar la carpeta instalada solo con confirmacion explicita
- no borra automaticamente datos, backups ni exportaciones del usuario

## Que debe viajar junto

No copies solo el ejecutable. La carpeta debe conservar:

- `Instalar Caja Clara.cmd`
- `Instalar Caja Clara.ps1`
- `Quitar Caja Clara.cmd`
- `Quitar Caja Clara.ps1`
- `LEEME - Windows.txt`
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

Para entrega normal, ese primer arranque conviene hacerlo desde el acceso directo creado por `Instalar Caja Clara.cmd`, no buscando el `.exe` dentro de carpetas tecnicas.

## Checklist manual corta

1. `Instalar Caja Clara.cmd` termina sin error
2. el acceso directo del Escritorio aparece y apunta a `%LocalAppData%\CajaClara\CajaClara.exe`
3. el acceso directo de Inicio aparece y apunta a `%LocalAppData%\CajaClara\CajaClara.exe`
4. `Inicio` abre sin crash desde un acceso directo
5. `Productos` o `Agregar producto` responde
6. `Nueva venta` o `Registrar gasto` muestra feedback final
7. el scanner manual o tipo teclado puede enfocar barcode y resolver el flujo
8. `Caja / Resumen` abre y refleja movimientos si ya existen

## Trial y activacion

- la prueba dura 30 dias
- si vence, la app queda en solo lectura
- los datos siguen visibles y exportables
- para operar de nuevo, se activa desde la propia app con el ID de instalacion

## MSIX hoy

El `.msix` queda como opcion adicional, no como camino principal de entrega.

Estado real de esta etapa:

- el paquete se genera bien
- la experiencia simple principal queda cubierta por el portable con instalacion liviana
- en una PC sin el certificado de desarrollo en confianza, Windows puede bloquear la instalacion
- en la prueba real sobre esta maquina, `Add-AppxPackage` devolvio `0x800B0109`

Por eso, para demo, prueba comercial o entrega rapida, la recomendacion sigue siendo el paquete portable.
