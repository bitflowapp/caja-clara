param(
  [switch]$RemoveInstalledFiles
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$appName = "Caja Clara"
$appFolderName = "CajaClara"
$installDir = Join-Path $env:LocalAppData $appFolderName
$desktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "$appName.lnk"
$startMenuProgramsDir = [Environment]::GetFolderPath("Programs")
$startMenuShortcutPath = Join-Path $startMenuProgramsDir "$appName.lnk"
$uninstallShortcutPath = Join-Path $startMenuProgramsDir "Quitar $appName.lnk"
$legacyStartMenuFolder = Join-Path $startMenuProgramsDir $appName
$scriptPath = $MyInvocation.MyCommand.Path

function Write-Step {
  param([string]$Message)

  Write-Host "[Caja Clara] $Message"
}

function Get-NormalizedPath {
  param([string]$Path)

  return [System.IO.Path]::GetFullPath($Path).TrimEnd("\\")
}

function Test-PathInside {
  param(
    [string]$CandidatePath,
    [string]$ParentPath
  )

  $candidate = (Get-NormalizedPath $CandidatePath).ToLowerInvariant()
  $parent = (Get-NormalizedPath $ParentPath).ToLowerInvariant()
  return $candidate -eq $parent -or $candidate.StartsWith("$parent\\")
}

function Assert-AppNotRunning {
  $runningInstances = Get-Process -Name "CajaClara" -ErrorAction SilentlyContinue
  if ($runningInstances) {
    throw "Caja Clara ya esta abierta. Cierrala y vuelve a ejecutar Quitar Caja Clara."
  }
}

function Remove-IfExists {
  param([string]$Path)

  if (Test-Path $Path) {
    Remove-Item -Path $Path -Force
  }
}

function Confirm-RemoveInstalledFiles {
  while ($true) {
    $answer = (Read-Host "Eliminar tambien la carpeta instalada en '$installDir'? Escribe S para si o N para no. Tus datos, backups y exportaciones no se borran automaticamente").Trim().ToUpperInvariant()
    switch ($answer) {
      "S" { return $true }
      "N" { return $false }
      default {
        Write-Host "Respuesta invalida. Escribe S o N."
      }
    }
  }
}

function Remove-InstalledFolder {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    Write-Step "La carpeta instalada ya no existe."
    return
  }

  if (Test-PathInside $scriptPath $Path) {
    $deleteCommand = "/c timeout /t 2 /nobreak >nul & rmdir /s /q `"$Path`""
    Start-Process -FilePath "cmd.exe" -ArgumentList $deleteCommand -WorkingDirectory $env:TEMP -WindowStyle Hidden
    Write-Step "La carpeta instalada se quitara automaticamente en unos segundos: $Path"
    return
  }

  Remove-Item -Path $Path -Recurse -Force
  Write-Step "Carpeta instalada eliminada: $Path"
}

Write-Step "Quitando accesos directos..."
Assert-AppNotRunning

Remove-IfExists -Path $desktopShortcutPath
Remove-IfExists -Path $startMenuShortcutPath
Remove-IfExists -Path $uninstallShortcutPath

if ((Test-Path $legacyStartMenuFolder) -and -not (Get-ChildItem -Force $legacyStartMenuFolder)) {
  Remove-Item -Path $legacyStartMenuFolder -Force
}

$installDirExists = Test-Path $installDir
$shouldRemoveInstalledFiles = $RemoveInstalledFiles.IsPresent
if (-not $shouldRemoveInstalledFiles -and (Test-Path $installDir)) {
  $shouldRemoveInstalledFiles = Confirm-RemoveInstalledFiles
}

if ($shouldRemoveInstalledFiles) {
  Write-Step "Quitando carpeta instalada..."
  Remove-InstalledFolder -Path $installDir
} elseif ($installDirExists) {
  Write-Step "Los archivos instalados se dejaron intactos en $installDir"
} else {
  Write-Step "No habia carpeta instalada en $installDir"
}

Write-Host ""
Write-Host "Caja Clara quedo quitada del Escritorio y del menu Inicio."
if (-not $shouldRemoveInstalledFiles -and $installDirExists) {
  Write-Host "La carpeta instalada sigue disponible en: $installDir"
}
Write-Host "Tus datos, backups y exportaciones no se borraron automaticamente."
