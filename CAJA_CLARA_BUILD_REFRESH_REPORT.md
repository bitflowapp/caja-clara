# Caja Clara Build Refresh Report

Date: 2026-05-22

## Result

The Luna UI redesign is present in the source code and appears in the newly generated Windows release build.

The app that still looks old is being opened from a stale installed Windows executable, not from the freshly built Flutter release executable.

## Luna UI Source Check

Found Luna UI colors in source:

- `#3B82F6`
- `#F6F8FB`
- `#2563EB`
- `#EAF1FE`

Primary source file:

- `lib/app/theme/bpc_colors.dart`

Additional match:

- `lib/app/widgets/commerce_components.dart`

## Commands Run

From:

`D:\bit flow hoy actualizado 12.2\caja-clara`

Commands:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

## Verification Output

- `flutter clean`: completed successfully.
- `flutter pub get`: completed successfully.
- `flutter analyze`: no issues found.
- `flutter test`: all tests passed.
- `flutter build windows --release`: completed successfully.

Generated release executable:

`D:\bit flow hoy actualizado 12.2\caja-clara\build\windows\x64\runner\Release\b_plus_commerce.exe`

Build timestamp:

`2026-05-22 15:11:36`

SHA256:

`273798A225BB3C3D226927A46362A6713AF921E7F979381AB98E3C11E73D9C4E`

## Visual Confirmation

I launched the generated release executable directly:

`D:\bit flow hoy actualizado 12.2\caja-clara\build\windows\x64\runner\Release\b_plus_commerce.exe`

The running app showed the new Luna UI:

- Light background.
- White rounded cards.
- Blue primary actions.
- `Luna Systems` branding.
- New left navigation.
- Modern blue/light dashboard layout.

## Stale Executables / Shortcuts Found

### Stale Start Menu Shortcut

Shortcut:

`C:\Users\marco\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Caja Clara.lnk`

Target:

`C:\Users\marco\AppData\Local\CajaClara\CajaClara.exe`

Working directory:

`C:\Users\marco\AppData\Local\CajaClara`

Shortcut timestamp:

`2026-03-28 14:26:13`

### Stale Installed Executable

Installed executable:

`C:\Users\marco\AppData\Local\CajaClara\CajaClara.exe`

Timestamp:

`2026-03-28 01:47:43`

SHA256:

`FA7D3F177DEE00979D23C3C7A6E58A046A97C78DFDE61754A9FEFBA4D19E4131`

This is not the same executable as the newly built release binary.

### Older Portable Build Also Found

Portable executable:

`D:\bit flow hoy actualizado 12.2\caja-clara\dist\windows-portable\b_plus_commerce.exe`

Timestamp:

`2026-05-16 04:14:27`

SHA256:

`3FB96CF51C5ECB9A8EA75D6BE37125E551B2571DF0EB1AE151002B422BBAA667`

This is also older than the fresh release build and has a different hash.

## Conclusion

The source code and fresh Windows release build contain the Luna redesign.

The stale app path is:

`C:\Users\marco\AppData\Local\CajaClara\CajaClara.exe`

The stale shortcut is:

`C:\Users\marco\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Caja Clara.lnk`

To open the current Luna build, run:

`D:\bit flow hoy actualizado 12.2\caja-clara\build\windows\x64\runner\Release\b_plus_commerce.exe`
