param(
    [string]$OutputPath,
    [switch]$Debug,
    [switch]$Headless = $true
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Editor = Join-Path $ProjectDir "editor_steam\godotsteam.47.editor.win64.console.exe"
$Preset = "Windows Desktop"

if (-not $OutputPath) {
    $OutputPath = Join-Path $ProjectDir "exports\VivoSprint.exe"
}

$headlessFlag = if ($Headless) { "--headless" } else { "" }
$modeFlag = if ($Debug) { "--export-debug" } else { "--export-release" }

Write-Host "=== Exporting Vivo Sprint ===" -ForegroundColor Cyan
Write-Host "Preset:   $Preset"
Write-Host "Mode:     $(if ($Debug) { 'Debug' } else { 'Release' })"
Write-Host "Output:   $OutputPath"
Write-Host ""

$args = @($headlessFlag, $modeFlag, $Preset, $OutputPath) | Where-Object { $_ }
& $Editor @args

if ($LASTEXITCODE -ne 0) {
    Write-Host "Export FAILED (exit code: $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Export concluido: $OutputPath" -ForegroundColor Green
