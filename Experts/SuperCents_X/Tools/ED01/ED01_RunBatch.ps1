# ED01_RunBatch.ps1 - Sprint 20 ED01-A admission-floor grid runner.
# Runs 21 configs (1 B8 control + 20 single-floor deltas) on the three
# frozen Sprint 17 collection grids (EURUSD H1 decision, GBPJPY H1 decision,
# EURUSD M15 evidence-only). NOTE: GBPJPY M15 was never collected in Sprint 17
# (no preset exists); per protocol section 5 the OOS grid follows the actual
# collection files. Each run: headless tester replay 2026.01.05-2026.07.05,
# Model=4, EntryMode=2 (ENTRY_MODE_NEW, mirroring the collection set), archived
# collection weights 25/20/15/15/15/10, one ED01_Floor* input overridden.
# Resumable: a config is skipped when artifacts/<FILE>/<CONFIG>/.done exists.
# Usage: powershell -File ED01_RunBatch.ps1 [-Only EURUSD_H1] [-Configs LIQUIDITY_0.50,CONTROL]

param(
    [string[]]$Only = @(),          # e.g. @("EURUSD_H1","GBPJPY_H1")
    [string[]]$Configs = @(),       # e.g. @("CONTROL","LIQUIDITY_0.50")
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$SC     = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # SuperCents_X dir
$Root   = Split-Path -Parent (Split-Path -Parent $SC)             # MQL5 dir
$DataFolder = Split-Path -Leaf (Split-Path -Parent $Root)
$Common = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\Telemetry"
$Terminal = "C:\Program Files\MetaTrader 5\terminal64.exe"
$AgentDir = Join-Path $env:APPDATA "MetaQuotes\Tester\$DataFolder\Agent-127.0.0.1-3000\logs"
$AgentLog = Join-Path $AgentDir ((Get-Date -Format "yyyyMMdd") + ".log")
$Art     = Join-Path $PSScriptRoot "artifacts"
$IniDir  = Join-Path $PSScriptRoot "ini"
$Log     = Join-Path $PSScriptRoot "run.log"

$Files = [ordered]@{
    "EURUSD_H1"  = @{ Symbol = "EURUSD"; Period = "H1" }
    "GBPJPY_H1"  = @{ Symbol = "GBPJPY"; Period = "H1" }
    "EURUSD_M15" = @{ Symbol = "EURUSD"; Period = "M15" }
}

# 21 registered configs: CONTROL + 4 deltas x 5 decision families.
# (B8 value per family is the shared CONTROL; per the frozen grid this is
#  5 families x 4 deltas = 20 experiment runs + 1 control = 21 per file.)
$Grid = [ordered]@{
    "LIQUIDITY" = @("0.50", "0.55", "0.65", "0.70")
    "BOS"       = @("0.25", "0.30", "0.40", "0.45")
    "CHOCH"     = @("0.25", "0.30", "0.40", "0.45")
    "FVG"       = @("0.25", "0.30", "0.40", "0.45")
    "OB"        = @("0.25", "0.30", "0.40", "0.45")
}
$InputName = @{
    "LIQUIDITY" = "ED01_FloorLiquidity"
    "BOS"       = "ED01_FloorBOS"
    "CHOCH"     = "ED01_FloorCHOCH"
    "FVG"       = "ED01_FloorFVG"
    "OB"        = "ED01_FloorOrderBlock"
}

function Write-ED01Log($msg) { $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  " + $msg; Add-Content -LiteralPath $Log -Value $line -Encoding UTF8; Write-Host $line }

function Get-ConfigList {
    $list = @("CONTROL")
    foreach ($fam in $Grid.Keys) { foreach ($v in $Grid[$fam]) { $list += "$($fam)_$v" } }
    return $list
}

function Get-ED01Override($config) {
    if ($config -eq "CONTROL") { return @() }
    $parts = $config -split "_"
    $fam = $parts[0]; $val = $parts[1]
    return @("$($InputName[$fam])=$val")
}

function Get-RowsWritten {
    #--- stream only the journal tail (the agent log can reach GB scale)
    if (-not (Test-Path -LiteralPath $AgentLog)) { return "-1/-1" }
    $tail = Get-Content -LiteralPath $AgentLog -Tail 30000
    $rows = -1; $faults = -1
    foreach ($line in $tail) {
        if ($line -match "Rows Written\s+(\d+)") { $rows = [int]$Matches[1] }
        if ($line -match "I/O Faults\s+(\d+)") { $faults = [int]$Matches[1] }
    }
    return "$rows/$faults"
}

function Invoke-ED01Run {
    param([string]$FileKey, [string]$Config)
    $dir = Join-Path $Art "$FileKey\$Config"
    $done = Join-Path $dir ".done"
    if (Test-Path -LiteralPath $done) { Write-ED01Log "SKIP   $FileKey/$Config (done)"; return }
    $spec = $Files[$FileKey]
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    New-Item -ItemType Directory -Path $IniDir -Force | Out-Null

    $ini = Join-Path $IniDir "$($FileKey)_$Config.ini"
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("[Tester]")
    [void]$sb.AppendLine("Expert=SuperCents_X\SuperCents_X.ex5")
    [void]$sb.AppendLine("Symbol=$($spec.Symbol)")
    [void]$sb.AppendLine("Period=$($spec.Period)")
    [void]$sb.AppendLine("Optimization=0")
    [void]$sb.AppendLine("Model=4")
    [void]$sb.AppendLine("FromDate=2026.04.05")
    [void]$sb.AppendLine("ToDate=2026.07.05")
    [void]$sb.AppendLine("ForwardMode=0")
    [void]$sb.AppendLine("Deposit=10000")
    [void]$sb.AppendLine("Currency=GBP")
    [void]$sb.AppendLine("ProfitInPips=0")
    [void]$sb.AppendLine("Leverage=200")
    [void]$sb.AppendLine("ExecutionMode=1000")
    [void]$sb.AppendLine("OptimizationCriterion=0")
    [void]$sb.AppendLine("Visual=0")
    [void]$sb.AppendLine("ReplaceReport=1")
    [void]$sb.AppendLine("ShutdownTerminal=1")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("[TesterInputs]")
    [void]$sb.AppendLine("EntryMode=2")
    [void]$sb.AppendLine("WeightStructure=25.0")
    [void]$sb.AppendLine("WeightOrderBlock=20.0")
    [void]$sb.AppendLine("WeightFVG=15.0")
    [void]$sb.AppendLine("WeightLiquidity=15.0")
    [void]$sb.AppendLine("WeightTrend=15.0")
    [void]$sb.AppendLine("WeightPremiumDiscount=10.0")
    foreach ($o in (Get-ED01Override $Config)) { [void]$sb.AppendLine($o) }
    Set-Content -LiteralPath $ini -Value $sb.ToString() -Encoding ASCII

    if ($DryRun) { Write-ED01Log "DRYRUN $FileKey/$Config -> $ini"; return }

    #--- one retry per config: a wedged terminal can abort a run with no capture
    $attempts = 0
    do {
        $attempts++
        $copied = Invoke-ED01Attempt $ini $dir $FileKey $Config
        if ($copied.Count -eq 0 -and $attempts -lt 2) {
            Write-ED01Log "RETRY  $FileKey/$Config (no capture, attempt $attempts/2)"
            Start-Sleep -Seconds 20
        }
    } while ($copied.Count -eq 0 -and $attempts -lt 2)

    $rows = Get-RowsWritten
    if ($copied.Count -gt 0) {
        Set-Content -LiteralPath $done -Value ((Get-Date -Format "yyyy-MM-ddTHH:mm:ss") + " rows=$rows files=$($copied -join ',')") -Encoding ASCII
        Write-ED01Log "DONE   $FileKey/$Config rows=$rows files=$($copied -join ',')"
    } else {
        Write-ED01Log "EMPTY  $FileKey/$Config rows=$rows (no csv captured after $attempts attempt(s) - NOT marked done)"
    }
}

function Invoke-ED01Attempt([string]$ini, [string]$dir, [string]$FileKey, [string]$Config) {
    #--- clear previous run's telemetry files (flush filenames repeat per
    #--- run: telemetry_v4_<lastdate>.csv), then launch headless
    if (Test-Path -LiteralPath $Common) {
        Get-ChildItem -LiteralPath $Common -Filter "telemetry_v4_*.csv" -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
    Write-ED01Log "RUN    $FileKey/$Config start"
    $p = Get-Process terminal64 -ErrorAction SilentlyContinue
    if ($p) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 5 }
    Start-Process -FilePath $Terminal -ArgumentList "/config:`"$ini`"" -WorkingDirectory $Root | Out-Null
    $deadline = (Get-Date).AddMinutes(80)
    do { Start-Sleep -Seconds 5; $p = Get-Process terminal64 -ErrorAction SilentlyContinue }
    while ($p -and (Get-Date) -lt $deadline)
    Start-Sleep -Seconds 3
    if ($p) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3 }

    #--- copy captured files BEFORE the (slow) journal read so a failure
    #--- cannot lose the capture
    $copied = @()
    if (Test-Path -LiteralPath $Common) {
        Get-ChildItem -LiteralPath $Common -Filter "telemetry_v4_*.csv" -ErrorAction SilentlyContinue |
            ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dir $_.Name) -Force
                $copied += $_.Name
            }
    }
    return $copied
}

New-Item -ItemType Directory -Path $Art -Force | Out-Null
Write-ED01Log "=== ED01-A batch start (files: $($Files.Keys -join ', ')) ==="

foreach ($FileKey in $Files.Keys) {
    if ($Only.Count -gt 0 -and $Only -notcontains $FileKey) { continue }
    foreach ($Config in (Get-ConfigList)) {
        if ($Configs.Count -gt 0 -and $Configs -notcontains $Config) { continue }
        Invoke-ED01Run -FileKey $FileKey -Config $Config
    }
}
Write-ED01Log "=== ED01-A batch complete ==="
