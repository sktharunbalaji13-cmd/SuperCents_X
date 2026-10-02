# EN03_Phase1_Run.ps1 - EN-03 Phase 1 population-invariance study, 3-arm batch.
# Authorized research (docs/Sprint24_EN03_Assessment.md, Phase 1; user
# authorization 2026-08-13): measurement-only, no production changes, no
# commit, no closure doc. Baseline = frozen TT01 golden
# Tools/TT01/artifacts/TT01_20260813_185122/telemetry_v5_default.csv.
#
# Runs EXACTLY three arms, in order (EURUSD H1, 2026.01.01..2026.02.01,
# Model=4, Deposit 10000 GBP, Leverage 200, ExecutionMode 1000):
#   LEGACY       EN03GateStrategy=0  (must reproduce the golden CSV
#                                     byte-identical - validity gate)
#   OFF          EN03GateStrategy=1  (gate disabled)
#   COORDINATED  EN03GateStrategy=2  (fix option B)
#
# Each run uses the frozen capture profile (identical to the TT01 replay
# profile): EntryMode=2 (isolation CONTROL precedent), B8 weights
# 25/20/15/15/15/10, SwingSignificanceTier=0.0, FixedRR 2.0R. The ONLY
# delta between arms is EN03GateStrategy.
#
# Artifacts: Tools/EN03/artifacts/<ARM>/ with telemetry_v5_*.csv +
# en03_pop_*.csv + .done marker. Manifest:
# Tools/EN03/EN03_Phase1_manifest.json, written incrementally.
#
# Hard rules (ED01-RunBatch pattern): resumable via .done; never accept
# an empty artifact silently; never fabricate a .done; on ANY run
# failure STOP the batch, mark FAILED, exit non-zero; raw artifacts stay
# on disk; nothing is committed by this script.
#
# Usage: powershell -File EN03_Phase1_Run.ps1  (-DryRun prints the plan
#        and writes INIs/manifest without launching the tester)

param(
    [switch]$DryRun,
    [string]$ArtRoot = "artifacts"
)

$ErrorActionPreference = "Stop"
$SC     = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # SuperCents_X dir
$Root   = Split-Path -Parent (Split-Path -Parent $SC)             # MQL5 dir
$DataFolder = Split-Path -Leaf (Split-Path -Parent $Root)
$Common = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\Telemetry"
$Terminal = "C:\Program Files\MetaTrader 5\terminal64.exe"
$TesterRoot = Join-Path $env:APPDATA "MetaQuotes\Tester\$DataFolder"
$Art     = Join-Path $PSScriptRoot $ArtRoot
$IniDir  = Join-Path $PSScriptRoot "ini"
$Log     = Join-Path $PSScriptRoot "run_EN03_Phase1.log"
$Manifest = Join-Path $PSScriptRoot "EN03_Phase1_manifest.json"

# Golden reference for the validity gate (frozen 2026-08-13 run).
$Golden = Join-Path $SC "Tools\TT01\artifacts\TT01_20260813_185122\telemetry_v5_default.csv"

$Arms = @(
    @{ Name = "LEGACY";      Strategy = 0 }
    @{ Name = "OFF";         Strategy = 1 }
    @{ Name = "COORDINATED"; Strategy = 2 }
)

function Write-EN03Log($msg) {
    $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  " + $msg
    Add-Content -LiteralPath $Log -Value $line -Encoding UTF8
    Write-Host $line
}

function Get-Manifest {
    if (Test-Path -LiteralPath $Manifest) {
        try { return (Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json) }
        catch { throw "manifest unreadable: $Manifest" }
    }
    return $null
}

function Save-Manifest($m) {
    $json = $m | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($Manifest, $json,
        (New-Object System.Text.UTF8Encoding($false)))
}

function New-EmptyManifest {
    $entries = @()
    foreach ($a in $Arms) {
        $entries += [pscustomobject]@{
            arm = $a.Name; strategy = $a.Strategy
            status = "PENDING"; start = $null; end = $null
            rows = $null; faults = $null; files = @()
            telemetry = $null; population = $null
        }
    }
    $m = [pscustomobject]@{
        protocol = "docs/Sprint24_EN03_Assessment.md Phase 1 (population-invariance study)"
        authorized = "2026-08-13 user authorization (Q1/Q3 YES; research first; no A/B selection)"
        validityGate = "LEGACY arm telemetry must equal $Golden byte-identical"
        arms = $entries
    }
    Save-Manifest $m
    return $m
}

function Get-Entry($m, $name) {
    foreach ($e in $m.arms) { if ($e.arm -eq $name) { return $e } }
    return $null
}

function Get-RowsWritten {
    #--- the tester may land on ANY agent (3000/3001/...); scan every
    #--- agent log for the latest Rows Written / I/O Faults (the Common
    #--- Files telemetry dir is cleared before each run)
    $rows = -1; $faults = -1
    Get-ChildItem -LiteralPath $TesterRoot -Recurse -Directory -Filter "Agent-*" -ErrorAction SilentlyContinue |
        ForEach-Object {
            $log = Join-Path $_.FullName "logs\$(Get-Date -Format 'yyyyMMdd').log"
            if (-not (Test-Path -LiteralPath $log)) { return }
            $tail = Get-Content -LiteralPath $log -Tail 30000
            foreach ($line in $tail) {
                if ($line -match "Rows Written\s+(\d+)") { $rows = [int]$Matches[1] }
                if ($line -match "I/O Faults\s+(\d+)") { $faults = [int]$Matches[1] }
            }
        }
    return "$rows/$faults"
}

function Invoke-EN03Attempt([string]$ini, [string]$dir, [string]$label) {
    #--- clear previous run's telemetry AND population files (filenames
    #--- repeat per run; mixing arms would poison the analysis)
    if (Test-Path -LiteralPath $Common) {
        Get-ChildItem -LiteralPath $Common -Filter "telemetry_v5_*.csv" -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath $Common -Filter "en03_pop_*.csv" -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
    Write-EN03Log "RUN    $label start"
    $p = Get-Process terminal64 -ErrorAction SilentlyContinue
    if ($p) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 5 }
    Start-Process -FilePath $Terminal -ArgumentList "/config:`"$ini`"" -WorkingDirectory $Root | Out-Null
    $deadline = (Get-Date).AddMinutes(60)
    do { Start-Sleep -Seconds 5; $p = Get-Process terminal64 -ErrorAction SilentlyContinue }
    while ($p -and (Get-Date) -lt $deadline)
    Start-Sleep -Seconds 3
    if ($p) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3 }

    #--- copy captured files BEFORE the (slow) journal read so a failure
    #--- cannot lose the capture
    $copied = @()
    if (Test-Path -LiteralPath $Common) {
        Get-ChildItem -LiteralPath $Common -Filter "telemetry_v5_*.csv" -ErrorAction SilentlyContinue |
            ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dir $_.Name) -Force
                $copied += $_.Name
            }
        Get-ChildItem -LiteralPath $Common -Filter "en03_pop_*.csv" -ErrorAction SilentlyContinue |
            ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dir $_.Name) -Force
                $copied += $_.Name
            }
    }
    return $copied
}

function Invoke-EN03Run {
    param([hashtable]$Arm)
    $label = $Arm.Name
    $dir = Join-Path $Art $label
    $done = Join-Path $dir ".done"
    $m = Get-Manifest
    $entry = Get-Entry $m $label

    if (Test-Path -LiteralPath $done) {
        Write-EN03Log "SKIP   $label (done)"
        $entry.status = "DONE"
        Save-Manifest $m
        return $true
    }
    #--- refuse to reuse a dir that already holds captures from a partial run
    $stale = @(Get-ChildItem -LiteralPath $dir -Filter "*.csv" -ErrorAction SilentlyContinue)
    if ($stale.Count -gt 0) {
        Write-EN03Log "ABORT  ${label}: non-empty artifact dir without .done ($($stale.Count) csv) - refusing to mix captures"
        $entry.status = "FAILED"
        Save-Manifest $m
        return $false
    }

    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $ini = Join-Path $IniDir "EN03_Phase1_$($Arm.Name).ini"
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("[Tester]")
    [void]$sb.AppendLine("Expert=SuperCents_X\Tools\EN03\EN03_GateHarness.ex5")
    [void]$sb.AppendLine("Symbol=EURUSD")
    [void]$sb.AppendLine("Period=H1")
    [void]$sb.AppendLine("Optimization=0")
    [void]$sb.AppendLine("Model=4")
    [void]$sb.AppendLine("FromDate=2026.01.01")
    [void]$sb.AppendLine("ToDate=2026.02.01")
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
    [void]$sb.AppendLine("OutcomeTpMode=0")
    [void]$sb.AppendLine("FixedRRTier=2.0")
    [void]$sb.AppendLine("SwingSignificanceTier=0.0")
    [void]$sb.AppendLine("WeightStructure=25.0")
    [void]$sb.AppendLine("WeightOrderBlock=20.0")
    [void]$sb.AppendLine("WeightFVG=15.0")
    [void]$sb.AppendLine("WeightLiquidity=15.0")
    [void]$sb.AppendLine("WeightTrend=15.0")
    [void]$sb.AppendLine("WeightPremiumDiscount=10.0")
    [void]$sb.AppendLine("EN03GateStrategy=$($Arm.Strategy)")
    Set-Content -LiteralPath $ini -Value $sb.ToString() -Encoding ASCII

    if ($DryRun) { Write-EN03Log "DRYRUN $label -> $ini (EN03GateStrategy=$($Arm.Strategy))"; return $true }

    $entry.status = "RUNNING"
    $entry.start = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    Save-Manifest $m
    Write-EN03Log "CONFIG $label ini=$ini EN03GateStrategy=$($Arm.Strategy)"

    #--- one retry per run: a wedged terminal can abort with no capture
    $attempts = 0
    $copied = @()
    do {
        $attempts++
        $copied = Invoke-EN03Attempt $ini $dir $label
        if ($copied.Count -eq 0 -and $attempts -lt 2) {
            Write-EN03Log "RETRY  $label (no capture, attempt $attempts/2)"
            Start-Sleep -Seconds 20
        }
    } while ($copied.Count -eq 0 -and $attempts -lt 2)

    $rows = Get-RowsWritten
    $entry.end = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    $entry.rows = $rows
    if ($copied.Count -gt 0) {
        $entry.files = @($copied)
        $entry.faults = if ($rows -match "^(\d+)/(\d+)$") { $Matches[2] } else { "-1" }
        $entry.status = "DONE"
        Set-Content -LiteralPath $done -Value ((Get-Date -Format "yyyy-MM-ddTHH:mm:ss") + " strategy=$($Arm.Strategy) rows=$rows files=$($copied -join ',')") -Encoding ASCII
        Save-Manifest $m
        Write-EN03Log "DONE   $label strategy=$($Arm.Strategy) rows=$rows files=$($copied -join ',')"
        return $true
    }
    $entry.status = "FAILED"
    Save-Manifest $m
    Write-EN03Log "EMPTY  $label rows=$rows (no csv captured after $attempts attempt(s) - NOT marked done; BATCH STOPPED)"
    return $false
}

New-Item -ItemType Directory -Path $Art -Force | Out-Null
New-Item -ItemType Directory -Path $IniDir -Force | Out-Null

if (-not (Test-Path -LiteralPath $Manifest)) {
    $m = New-EmptyManifest
    Write-EN03Log "=== EN-03 phase-1 manifest created with the three authorized arms ==="
} else {
    $m = Get-Manifest
    Write-EN03Log "=== EN-03 phase-1 batch resume: manifest exists ==="
}
foreach ($a in $m.arms) {
    Write-EN03Log "REGISTERED $($a.arm) strategy=$($a.strategy) status=$($a.status)"
}

if (-not (Test-Path -LiteralPath $Golden)) {
    Write-EN03Log "ABORT  golden reference missing: $Golden"
    exit 1
}

Write-EN03Log "=== EN-03 phase-1 3-arm batch start (research harness; no production change) ==="
foreach ($arm in $Arms) {
    if (-not (Invoke-EN03Run $arm)) {
        Write-EN03Log "=== EN-03 BATCH STOPPED (failure in $($arm.Name)); manifest reflects FAILED; no further runs ==="
        exit 1
    }
}
Write-EN03Log "=== EN-03 phase-1 3-arm batch complete ==="
