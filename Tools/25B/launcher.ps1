# launcher.ps1 - Sprint 25B: Start-Process wrapper for TT01_Validate.ps1
#   powershell -File Tools\25B\launcher.ps1 [-Skip compile,suite] [-OnlyIsolation]
# Child process inherits the working directory; exit code is forwarded.
# This is the ONLY sanctioned way to run TT01 with -Skip arrays (a direct
# invocation in this session must not hang the interactive shell).
param(
    [string[]]$Skip = @(),
    [switch]$OnlyIsolation
)
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root      = (git -C $ScriptDir rev-parse --show-toplevel) -replace "`n", ""
$SC        = if (Test-Path (Join-Path $Root "Experts\SuperCents_X")) { Join-Path $Root "Experts\SuperCents_X" } else { $Root }
$Script   = Join-Path $SC "Tools\TT01\TT01_Validate.ps1"

$argsList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$Script`"")
foreach ($s in $Skip) { $argsList += ("-Skip"); $argsList += $s }
if ($OnlyIsolation) { $argsList += "-OnlyIsolation" }

Write-Host ("[launcher] starting TT01_Validate.ps1 (skip=$($Skip -join ',')) - child console streams to this window") -ForegroundColor DarkCyan
$p = Start-Process -FilePath "powershell.exe" -ArgumentList $argsList -WorkingDirectory $Root -PassThru -NoNewWindow
$p.WaitForExit()
Write-Host ("[launcher] TT01 exit code: " + $p.ExitCode) -ForegroundColor DarkCyan
exit $p.ExitCode

