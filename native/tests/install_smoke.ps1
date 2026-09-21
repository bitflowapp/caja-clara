param([ValidateSet('Install','Uninstall')][string]$Phase = 'Install')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$output = Join-Path $root 'artifacts'
$package = Join-Path $output 'package'
$installed = Join-Path $env:LOCALAPPDATA 'Programs\LUNA\CajaClaraNative\0.2.0'
$data = Join-Path $env:LOCALAPPDATA 'LUNA\CajaClaraNative\Business'
$marker = Join-Path $data 'qa-preserve-sentinel.txt'
$resultsPath = Join-Path $output 'installer-test-results.json'
$results = @()
if (Test-Path $resultsPath) { $results = @((Get-Content $resultsPath -Raw | ConvertFrom-Json).results) }
try {
    if ($Phase -eq 'Install') {
        New-Item -ItemType Directory -Force $data | Out-Null
        'Fixture created by installer test; not business data.' | Set-Content $marker
        & (Join-Path $package 'Install.ps1') -NoLaunch
        if (-not (Test-Path (Join-Path $installed 'CajaClara.exe'))) { throw 'Installed executable missing.' }
        if (-not (Get-ChildItem $installed -Filter '*.pri')) { throw 'Published resource index missing.' }
        if (-not (Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Caja Clara Native.lnk'))) { throw 'Desktop shortcut missing.' }
        if (-not (Test-Path $marker)) { throw 'Installer removed existing data.' }
        $results += @{ name='installer_copies_app_resources_and_shortcut'; status='PASS' }
        $results += @{ name='installer_preserves_existing_data'; status='PASS' }
        "CAJACLARA_UI_EXE=$(Join-Path $installed 'CajaClara.exe')" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
    } else {
        & (Join-Path $package 'Uninstall.ps1')
        if (Test-Path (Join-Path $installed 'CajaClara.exe')) { throw 'Uninstaller did not remove program.' }
        if (-not (Test-Path $marker)) { throw 'Uninstaller removed existing data.' }
        $results += @{ name='uninstaller_removes_program_only'; status='PASS' }
        $results += @{ name='uninstaller_preserves_business_data'; status='PASS' }
    }
} catch {
    $results += @{ name="installer_$Phase"; status='FAIL'; detail=$_.Exception.Message }
    throw
} finally {
    @{ total=$results.Count; passed=@($results | Where-Object {$_.status -eq 'PASS'}).Count; failed=@($results | Where-Object {$_.status -eq 'FAIL'}).Count; results=$results } | ConvertTo-Json -Depth 6 | Set-Content $resultsPath -Encoding utf8
}
