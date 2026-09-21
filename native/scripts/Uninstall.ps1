$ErrorActionPreference = 'Stop'
if (Get-Process CajaClara -ErrorAction SilentlyContinue) { throw 'Cerrá Caja Clara antes de desinstalar.' }
$base = Join-Path $env:LOCALAPPDATA 'Programs\LUNA\CajaClaraNative'
if (Test-Path $base) { Remove-Item $base -Recurse -Force }
foreach ($folder in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))) {
    $shortcut = Join-Path $folder 'Caja Clara Native.lnk'
    if (Test-Path $shortcut) { Remove-Item $shortcut -Force }
}
Write-Host 'Programa desinstalado. Ventas, usuarios, configuración y respaldos permanecen en LocalAppData\LUNA\CajaClaraNative.'
