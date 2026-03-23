param(
  [switch]$Release = $true
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$buildSha = (git rev-parse HEAD).Trim()
$shortSha = $buildSha.Substring(0, [Math]::Min(7, $buildSha.Length))
$buildBranch = (git rev-parse --abbrev-ref HEAD).Trim()
$buildTimeUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

Write-Host "Flutter pub get..."
flutter pub get

if ($Release) {
  Write-Host "Building Windows (release)..."
  flutter build windows --release `
    --dart-define=CAJA_CLARA_BUILD_SHA=$buildSha `
    --dart-define=CAJA_CLARA_BUILD_SHORT_SHA=$shortSha `
    --dart-define=CAJA_CLARA_BUILD_BRANCH=$buildBranch `
    --dart-define=CAJA_CLARA_BUILD_TIME_UTC=$buildTimeUtc `
    --dart-define=CAJA_CLARA_BUILD_SOURCE=local-script
} else {
  Write-Host "Building Windows (debug)..."
  flutter build windows `
    --dart-define=CAJA_CLARA_BUILD_SHA=$buildSha `
    --dart-define=CAJA_CLARA_BUILD_SHORT_SHA=$shortSha `
    --dart-define=CAJA_CLARA_BUILD_BRANCH=$buildBranch `
    --dart-define=CAJA_CLARA_BUILD_TIME_UTC=$buildTimeUtc `
    --dart-define=CAJA_CLARA_BUILD_SOURCE=local-script
}

Write-Host "OK: build/windows"
