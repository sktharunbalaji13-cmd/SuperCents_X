# RunSprint9.ps1 - Sprint 9.1 FVG Test Runner
param(
    [string]$MT5 = "C:\Program Files\MetaTrader 5\terminal64.exe",
    [string]$Config = "..\Tests\CI\sprint9.ini",
    [switch]$Wait
)

$configPath = Join-Path $PSScriptRoot $Config
if (!(Test-Path $configPath)) {
    Write-Error "Config not found: $configPath"
    exit 1
}

Write-Host "Running Sprint9 FVG Test..."
Write-Host "  MT5: $MT5"
Write-Host "  Config: $configPath"

if ($Wait) {
    $proc = Start-Process -FilePath $MT5 -ArgumentList "/config:"$configPath"" -Wait -PassThru
    Write-Host "Exit code: $($proc.ExitCode)"
} else {
    Start-Process -FilePath $MT5 -ArgumentList "/config:"$configPath""
    Write-Host "Launched (non-blocking)"
}
