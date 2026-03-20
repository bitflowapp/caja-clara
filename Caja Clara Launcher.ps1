param()

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$exePath = Join-Path $root "build\\windows\\x64\\runner\\Release\\b_plus_commerce.exe"

Set-Location $root

if (-not (Test-Path $exePath)) {
  Write-Host "No existe build release. Construyendo Caja Clara..."
  flutter pub get
  flutter build windows --release
}

if (-not (Test-Path $exePath)) {
  throw "No se encontro el ejecutable en $exePath"
}

Start-Process -FilePath $exePath -WorkingDirectory (Split-Path $exePath)
