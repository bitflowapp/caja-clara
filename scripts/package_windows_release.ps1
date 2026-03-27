param(
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$releaseDir = Join-Path $root "build\\windows\\x64\\runner\\Release"
$portableRoot = Join-Path $root "dist\\windows-portable"
$portableDir = Join-Path $portableRoot "CajaClara"
$portableAssetsDir = Join-Path $root "scripts\\windows-portable-assets"
$zipPath = Join-Path $portableRoot "CajaClara-win64.zip"
$exePath = Join-Path $releaseDir "CajaClara.exe"

Set-Location $root

if (-not $SkipBuild) {
  Write-Host "Building Windows release..."
  powershell -ExecutionPolicy Bypass -File (Join-Path $root "scripts\\build_windows.ps1")
}

if (-not (Test-Path $exePath)) {
  throw "No se encontro el ejecutable de release en $exePath"
}

if (Test-Path $portableDir) {
  Remove-Item -Recurse -Force $portableDir
}

if (-not (Test-Path $portableRoot)) {
  New-Item -ItemType Directory -Path $portableRoot | Out-Null
}

Write-Host "Copying portable release..."
New-Item -ItemType Directory -Path $portableDir | Out-Null
Copy-Item -Path (Join-Path $releaseDir "*") -Destination $portableDir -Recurse

if (Test-Path $portableAssetsDir) {
  Write-Host "Adding portable install scripts..."
  Copy-Item -Path (Join-Path $portableAssetsDir "*") -Destination $portableDir -Recurse
}

if (Test-Path $zipPath) {
  Remove-Item -Force $zipPath
}

Write-Host "Creating portable zip..."
Compress-Archive -Path $portableDir -DestinationPath $zipPath

Write-Host "Portable folder: $portableDir"
Write-Host "Portable zip: $zipPath"
