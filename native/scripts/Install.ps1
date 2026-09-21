param([switch]$NoLaunch)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'app'
if (-not (Test-Path (Join-Path $source 'CajaClara.exe'))) { throw 'Falta la carpeta app completa. Descomprimí el paquete antes de instalar.' }
$version = '0.2.0'
$base = Join-Path $env:LOCALAPPDATA 'Programs\LUNA\CajaClaraNative'
$destination = Join-Path $base $version
if (Get-Process CajaClara -ErrorAction SilentlyContinue) { throw 'Cerrá Caja Clara antes de instalar o actualizar.' }
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Copy-Item (Join-Path $source '*') $destination -Recurse -Force
$shell = New-Object -ComObject WScript.Shell
foreach ($folder in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))) {
    $shortcut = $shell.CreateShortcut((Join-Path $folder 'Caja Clara Native.lnk'))
    $shortcut.TargetPath = Join-Path $destination 'CajaClara.exe'
    $shortcut.WorkingDirectory = $destination
    $shortcut.Description = 'Caja Clara - Tu negocio, claro.'
    $shortcut.Save()
}
Write-Host "Caja Clara instalada en $destination"
Write-Host 'Los datos y la versión Flutter anterior no fueron modificados.'
if (-not $NoLaunch) { Start-Process (Join-Path $destination 'CajaClara.exe') }
