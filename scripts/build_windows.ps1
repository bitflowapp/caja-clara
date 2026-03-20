param(
  [switch]$Release = $true
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "Flutter pub get..."
flutter pub get

if ($Release) {
  Write-Host "Building Windows (release)..."
  flutter build windows --release
} else {
  Write-Host "Building Windows (debug)..."
  flutter build windows
}

Write-Host "OK: build/windows"

