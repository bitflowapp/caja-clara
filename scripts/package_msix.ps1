param(
  [string]$CertificateSubject = "CN=Caja Clara Dev",
  [string]$CertificatePassword = "CajaClara123!",
  [switch]$SkipBuild,
  [switch]$InstallAfterCreate
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$certsDir = Join-Path $root "certs"
$pfxPath = Join-Path $certsDir "caja-clara-dev.pfx"
$cerPath = Join-Path $certsDir "caja-clara-dev.cer"
$msixPath = Join-Path $root "dist\\msix\\CajaClara.msix"

Set-Location $root

if (-not (Test-Path $certsDir)) {
  New-Item -ItemType Directory -Path $certsDir | Out-Null
}

$password = ConvertTo-SecureString -String $CertificatePassword -AsPlainText -Force
$cert = Get-ChildItem Cert:\CurrentUser\My |
  Where-Object { $_.Subject -eq $CertificateSubject } |
  Select-Object -First 1

if (-not $cert) {
  Write-Host "Creating local signing certificate..."
  $cert = New-SelfSignedCertificate `
    -Type CodeSigningCert `
    -Subject $CertificateSubject `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -HashAlgorithm SHA256
}

Write-Host "Exporting signing certificate..."
Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $password | Out-Null
Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null

Write-Host "Trusting certificate for current user..."
Import-Certificate -FilePath $cerPath -CertStoreLocation "Cert:\CurrentUser\TrustedPeople" | Out-Null

if (-not $SkipBuild) {
  Write-Host "Building Windows release..."
  powershell -ExecutionPolicy Bypass -File (Join-Path $root "scripts\\build_windows.ps1")
}

Write-Host "Creating signed MSIX package..."
dart run msix:create `
  --certificate-path "$pfxPath" `
  --certificate-password "$CertificatePassword" `
  --publisher "$CertificateSubject" `
  --install-certificate false

if (-not (Test-Path $msixPath)) {
  throw "MSIX package not found at $msixPath"
}

if ($InstallAfterCreate) {
  Write-Host "Installing MSIX package..."
  Add-AppxPackage -Path $msixPath -ForceApplicationShutdown
}

Write-Host "MSIX package: $msixPath"
Write-Host "Certificate (.cer): $cerPath"
if (-not $InstallAfterCreate) {
  Write-Host "Installation skipped. To install later, trust the certificate if needed and run Add-AppxPackage over the MSIX."
}
