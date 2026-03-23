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

$buildSha = (git rev-parse HEAD).Trim()
$shortSha = $buildSha.Substring(0, [Math]::Min(7, $buildSha.Length))
$buildBranch = (git rev-parse --abbrev-ref HEAD).Trim()
$buildTimeUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

Write-Host "Flutter pub get..."
flutter pub get

Write-Host "Building web (release) with BASE_HREF=$BaseHref and PWA_STRATEGY=$PwaStrategy ..."
flutter build web --release --base-href $BaseHref --pwa-strategy $PwaStrategy `
  --dart-define=CAJA_CLARA_BUILD_SHA=$buildSha `
  --dart-define=CAJA_CLARA_BUILD_SHORT_SHA=$shortSha `
  --dart-define=CAJA_CLARA_BUILD_BRANCH=$buildBranch `
  --dart-define=CAJA_CLARA_BUILD_TIME_UTC=$buildTimeUtc `
  --dart-define=CAJA_CLARA_BUILD_SOURCE=local-script

$version = [ordered]@{
  commitSha = $buildSha
  shortCommitSha = $shortSha
  branch = $buildBranch
  builtAtUtc = $buildTimeUtc
  source = "local-script"
  baseHref = $BaseHref
}

$version | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $root "build/web/version.json") -Encoding UTF8

Write-Host "OK: build/web"
