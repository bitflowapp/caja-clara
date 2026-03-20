# Caja Clara

![Caja Clara](assets/branding/caja_clara_logo.png)

Caja Clara es una app Flutter para comercios chicos y pymes que necesitan operar ventas, gastos, productos, caja, stock y barcode desde una base local, simple y offline.

Este repo esta preparado para dos salidas reales:

- Windows desktop
- Web/PWA publicada en GitHub Pages para uso desde el telefono

URL final esperada en Pages:

```text
https://TU-USUARIO.github.io/caja-clara/
```

## Features reales

- ventas con impacto en stock y caja
- gastos con impacto en caja
- productos con barcode opcional
- stock bajo
- caja y resumen operativo
- exportacion Excel
- backup y restore JSON
- undo del ultimo movimiento
- apertura y cierre de caja
- flujo de barcode con camara o ingreso manual

## Estructura

```text
caja-clara/
|- lib/
|- assets/
|- docs/
|- scripts/
|- test/
|- web/
`- windows/
```

## Abrir la app en Windows

Desde la raiz del repo:

```powershell
flutter pub get
flutter run -d windows
```

## Launcher facil de clickear

Archivos:

- [`Caja Clara Launcher.ps1`](D:/bit%20flow%20hoy%20actualizado%2012.2/caja-clara/Caja%20Clara%20Launcher.ps1)
- [`Caja Clara Launcher.bat`](D:/bit%20flow%20hoy%20actualizado%2012.2/caja-clara/Caja%20Clara%20Launcher.bat)

Comportamiento:

- si existe el build release, abre el `.exe`
- si no existe, construye `flutter build windows --release`
- luego abre Caja Clara

Tambien queda un acceso directo de escritorio:

- [`Caja Clara.lnk`](C:/Users/marco/Desktop/Caja%20Clara.lnk)

## Build Windows

Comando exacto:

```powershell
flutter build windows --release
```

Atajo:

```powershell
.\scripts\build_windows.ps1
```

Salida esperada:

```text
build/windows/x64/runner/Release/b_plus_commerce.exe
```

## Version portable usable ahora

Carpeta portable:

- [`dist/windows-portable/`](D:/bit%20flow%20hoy%20actualizado%2012.2/caja-clara/dist/windows-portable)

Para usarla:

1. abrir la carpeta portable
2. ejecutar `b_plus_commerce.exe`

## Instalable Windows

Script de empaquetado:

- [`scripts/package_msix.ps1`](D:/bit%20flow%20hoy%20actualizado%2012.2/caja-clara/scripts/package_msix.ps1)

Comando:

```powershell
.\scripts\package_msix.ps1
```

Paquete generado:

- [`dist/msix/CajaClara.msix`](D:/bit%20flow%20hoy%20actualizado%2012.2/caja-clara/dist/msix/CajaClara.msix)

Estado real hoy:

- el `.msix` queda generado y firmado con certificado local de desarrollo
- la instalacion automatica quedo bloqueada por confianza del certificado raiz en este perfil de Windows
- la opcion portable queda lista y usable ahora

Paso faltante si quieres cerrar la instalacion en esta maquina:

1. abrir PowerShell como administrador
2. importar `certs/caja-clara-dev.cer` a `Trusted Root Certification Authorities`
3. instalar `dist/msix/CajaClara.msix`

## Build Web / PWA

Comando exacto:

```powershell
flutter build web --release --base-href "/caja-clara/" --pwa-strategy offline-first
```

Atajo:

```powershell
.\scripts\build_web.ps1 -BaseHref "/caja-clara/"
```

Salida esperada:

```text
build/web/
```

## GitHub Pages

Workflow activo:

- [`.github/workflows/pages.yml`](D:/bit%20flow%20hoy%20actualizado%2012.2/caja-clara/.github/workflows/pages.yml)

Configuracion actual:

- app en la raiz del repo
- `BASE_HREF = /caja-clara/`
- `flutter analyze`
- `flutter test`
- `flutter build web --release --base-href "/caja-clara/" --pwa-strategy offline-first`
- publicacion de `build/web`

### Pasos exactos para publicar

1. crear el repo GitHub `caja-clara`
2. subir este contenido a la raiz del repo
3. en GitHub, abrir `Settings -> Pages`
4. elegir `GitHub Actions` como source
5. hacer push a `main`
6. esperar el workflow `Caja Clara Pages`

### URL final esperada

```text
https://TU-USUARIO.github.io/caja-clara/
```

## Git y push

Si el repo remoto ya existe:

```powershell
git remote add origin https://github.com/TU-USUARIO/caja-clara.git
git push -u origin main
```

## Checks de release

```powershell
flutter analyze
flutter test
flutter build windows --release
flutter build web --release --base-href "/caja-clara/" --pwa-strategy offline-first
```

## Limitaciones reales

- el nombre tecnico del paquete y del exe sigue siendo `b_plus_commerce.exe`
- no toque la logica de negocio
- el `.msix` ya se genera, pero la instalacion final puede requerir importar el certificado con permisos mas altos
