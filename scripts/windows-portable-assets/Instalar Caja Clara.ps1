param(
  [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$appName = "Caja Clara"
$appFolderName = "CajaClara"
$exeName = "CajaClara.exe"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$installDir = Join-Path $env:LocalAppData $appFolderName
$sourceExePath = Join-Path $scriptDir $exeName
$installedExePath = Join-Path $installDir $exeName
$desktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "$appName.lnk"
$startMenuProgramsDir = [Environment]::GetFolderPath("Programs")
$startMenuShortcutPath = Join-Path $startMenuProgramsDir "$appName.lnk"
$uninstallShortcutPath = Join-Path $startMenuProgramsDir "Quitar $appName.lnk"
$installedUninstallCmdPath = Join-Path $installDir "Quitar Caja Clara.cmd"
$appIconLocation = "$installedExePath,0"
$uninstallIconLocation = "$env:SystemRoot\\System32\\shell32.dll,131"

function Write-Step {
  param([string]$Message)

  Write-Host "[Caja Clara] $Message"
}

function Get-NormalizedPath {
  param([string]$Path)

  return [System.IO.Path]::GetFullPath($Path).TrimEnd("\\")
}

function Test-SamePath {
  param(
    [string]$Left,
    [string]$Right
  )

  return (Get-NormalizedPath $Left) -ieq (Get-NormalizedPath $Right)
}

function Assert-AppNotRunning {
  $runningInstances = Get-Process -Name "CajaClara" -ErrorAction SilentlyContinue
  if ($runningInstances) {
    throw "Caja Clara ya esta abierta. Cierrala y vuelve a ejecutar la instalacion para evitar archivos bloqueados."
  }
}

function Sync-Directory {
  param(
    [string]$Source,
    [string]$Destination
  )

  New-Item -ItemType Directory -Path $Destination -Force | Out-Null
  & robocopy $Source $Destination /MIR /R:2 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
  $robocopyExitCode = $LASTEXITCODE
  if ($robocopyExitCode -gt 7) {
    throw "No se pudo copiar Caja Clara a $Destination. Codigo de robocopy: $robocopyExitCode"
  }
}

function New-Shortcut {
  param(
    [string]$ShortcutPath,
    [string]$TargetPath,
    [string]$WorkingDirectory,
    [string]$Description,
    [string]$IconLocation
  )

  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($ShortcutPath)
  $shortcut.TargetPath = $TargetPath
  $shortcut.WorkingDirectory = $WorkingDirectory
  $shortcut.Description = $Description
  $shortcut.IconLocation = $IconLocation
  $shortcut.Save()
}

Write-Step "Preparando instalacion simple..."

if (-not (Test-Path $sourceExePath)) {
  throw "No se encontro $exeName junto al instalador. Descomprime primero el paquete portable completo."
}

Assert-AppNotRunning

if (Test-SamePath $scriptDir $installDir) {
  Write-Step "Caja Clara ya esta instalada en $installDir. Se van a refrescar los accesos directos."
} else {
  Write-Step "Copiando Caja Clara a $installDir..."
  Sync-Directory -Source $scriptDir -Destination $installDir
}

if (-not (Test-Path $installedExePath)) {
  throw "La instalacion quedo incompleta. No se encontro $installedExePath"
}

if (-not (Test-Path $installedUninstallCmdPath)) {
  throw "La instalacion quedo incompleta. No se encontro $installedUninstallCmdPath"
}

Write-Step "Creando acceso directo en el Escritorio..."
New-Shortcut `
  -ShortcutPath $desktopShortcutPath `
  -TargetPath $installedExePath `
  -WorkingDirectory $installDir `
  -Description "Abrir Caja Clara" `
  -IconLocation $appIconLocation

Write-Step "Creando accesos directos en Inicio..."
New-Shortcut `
  -ShortcutPath $startMenuShortcutPath `
  -TargetPath $installedExePath `
  -WorkingDirectory $installDir `
  -Description "Abrir Caja Clara" `
  -IconLocation $appIconLocation

New-Shortcut `
  -ShortcutPath $uninstallShortcutPath `
  -TargetPath $installedUninstallCmdPath `
  -WorkingDirectory $installDir `
  -Description "Quitar Caja Clara" `
  -IconLocation $uninstallIconLocation

Write-Host ""
Write-Host "Instalacion lista."
Write-Host "Ruta local: $installDir"
Write-Host "Escritorio: $desktopShortcutPath"
Write-Host "Inicio: $startMenuShortcutPath"
Write-Host "Quitar: $uninstallShortcutPath"

if (-not $NoLaunch) {
  Write-Step "Abriendo Caja Clara..."
  Start-Process -FilePath $installedExePath -WorkingDirectory $installDir
}
