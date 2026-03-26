param()

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$exePath = Join-Path $root "build\\windows\\x64\\runner\\Release\\CajaClara.exe"

Set-Location $root

if (-not (Test-Path $exePath)) {
  Write-Host "No existe build release. Construyendo Caja Clara..."
  powershell -ExecutionPolicy Bypass -File (Join-Path $root "scripts\\build_windows.ps1")
}

if (-not (Test-Path $exePath)) {
  throw "No se encontro el ejecutable en $exePath"
}

Start-Process -FilePath $exePath -WorkingDirectory (Split-Path $exePath)
