param(
  # For GitHub Pages project sites, use "/<repo>/" (must start and end with "/").
  [string]$BaseHref = "/caja-clara/",

  # Flutter web PWA strategy. "offline-first" enables PWA caching.
  [ValidateSet("offline-first", "none")]
  [string]$PwaStrategy = "offline-first"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not ($BaseHref.StartsWith("/") -and $BaseHref.EndsWith("/"))) {
  throw "BaseHref must start and end with '/'. Example: /caja-clara/"
}

Write-Host "Flutter pub get..."
flutter pub get

Write-Host "Building web (release) with BASE_HREF=$BaseHref and PWA_STRATEGY=$PwaStrategy ..."
flutter build web --release --base-href $BaseHref --pwa-strategy $PwaStrategy

Write-Host "OK: build/web"
