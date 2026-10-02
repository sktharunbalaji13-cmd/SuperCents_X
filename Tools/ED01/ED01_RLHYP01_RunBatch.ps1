# ED01_RLHYP01_RunBatch.ps1 - Sprint 22 RL-HYP-01 12-run batch.
# Frozen protocol: docs/Sprint22_RL_HYP_01_Protocol.md section 14 (FROZEN
# 2026-08-11; Amendment A2 pairing key ACCEPTED 2026-08-11, section 16.2).
#
# Runs EXACTLY twelve runs, in order:
#   INTEGRITY (SwingSignificanceTier=0.0 audit): EURUSD_H1, GBPJPY_H1, EURUSD_M15
#   K1P0 (tier 1.0): EURUSD_H1, GBPJPY_H1, EURUSD_M15
#   K1P5 (tier 1.5): EURUSD_H1, GBPJPY_H1, EURUSD_M15
#   K2P0 (tier 2.0): EURUSD_H1, GBPJPY_H1, EURUSD_M15
#
# Each run uses the frozen CONTROL profile (identical to
# Tools/ED01/ini/<FILE>_CONTROL.ini): Expert SuperCents_X\SuperCents_X.ex5,
# per-file Symbol/Period, FromDate 2026.04.05, ToDate 2026.07.05, Model=4,
# Deposit 10000 GBP, Leverage 200, ExecutionMode 1000, EntryMode=2,
# B8 weights 25/20/15/15/15/10. The ONLY delta between arms is the
# [TesterInputs] SwingSignificanceTier override (0.0 for integrity, the
# registered tier 1.0/1.5/2.0 for the treatment runs). The gate parameter
# sits OUTSIDE the fingerprint (hardcoded-token precedent, protocol 11
# gate 1); treatment CSVs carry v5 schema (v4's 75 columns + the 3 gate
# telemetry columns swingQualifyingId/swingAmplitude/gateDecision).
#
# Artifacts: Tools/ED01/artifacts/<FILE>/CONTROL_RLHYP01_INTEGRITY|K1P0|
# K1P5|K2P0/ with telemetry_v5_*.csv + .done marker.
#
# Tier manifest: Tools/ED01/ED01_RLHYP01_manifest.json - one entry per
# run: file, kind, tier, status (PENDING/RUNNING/DONE/FAILED), start, end,
# rows, faults, files. Written incrementally so a crash never loses it.
# Pairing key per Amendment A2: canonical {signalTime, configFingerprint,
# symbol, timeframe} (uniqueness + cross-arm identity audited by
# ED01_RLHYP01_Analyze.py --gate; decisionId stays the ungated integrity
# rerun certificate only).
#
# Hard rules (user mandate, ED01-E pattern):
#   - Resumable: a run is skipped when its .done marker exists.
#   - Record start/end time and success/failure for every run.
#   - Never accept an empty artifact silently; never fabricate a .done.
#   - On ANY run failure: STOP the batch, mark FAILED, exit non-zero.
#   - Raw artifacts stay on disk; nothing is committed by this script.
#
# Usage: powershell -File ED01_RLHYP01_RunBatch.ps1  (-DryRun prints the
#        plan and writes INIs/manifest without launching the tester)
#
# NOTE: launching the 12-run batch requires explicit run authorization
# (protocol 15.3 step 7: pre-analysis gate, then run authorization).

param(
    [switch]$DryRun,
    # Sprint 22 fixed-build rerun: write artifacts + manifest under NEW
    # names so the original inadmissible 58-divergence set (default
    # artifacts/ + ED01_RLHYP01_manifest.json) is never overwritten.
    [string]$ArtRoot = "artifacts",
    [string]$ManifestName = "ED01_RLHYP01_manifest.json"
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
$Log     = Join-Path $PSScriptRoot "run_RLHYP01.log"
$Manifest = Join-Path $PSScriptRoot $ManifestName

$Files = [ordered]@{
    "EURUSD_H1"  = @{ Symbol = "EURUSD"; Period = "H1" }
    "GBPJPY_H1"  = @{ Symbol = "GBPJPY"; Period = "H1" }
    "EURUSD_M15" = @{ Symbol = "EURUSD"; Period = "M15" }
}

# The authorized twelve runs (protocol section 14): file, kind, tier.
$Runs = @(
    @{ File = "EURUSD_H1";  Kind = "INTEGRITY"; Tier = 0.0 }
    @{ File = "GBPJPY_H1";  Kind = "INTEGRITY"; Tier = 0.0 }
    @{ File = "EURUSD_M15"; Kind = "INTEGRITY"; Tier = 0.0 }
    @{ File = "EURUSD_H1";  Kind = "K1P0";      Tier = 1.0 }
    @{ File = "EURUSD_H1";  Kind = "K1P5";      Tier = 1.5 }
    @{ File = "EURUSD_H1";  Kind = "K2P0";      Tier = 2.0 }
    @{ File = "GBPJPY_H1";  Kind = "K1P0";      Tier = 1.0 }
    @{ File = "GBPJPY_H1";  Kind = "K1P5";      Tier = 1.5 }
    @{ File = "GBPJPY_H1";  Kind = "K2P0";      Tier = 2.0 }
    @{ File = "EURUSD_M15"; Kind = "K1P0";      Tier = 1.0 }
    @{ File = "EURUSD_M15"; Kind = "K1P5";      Tier = 1.5 }
    @{ File = "EURUSD_M15"; Kind = "K2P0";      Tier = 2.0 }
)

$ArtDirs = @{
    "INTEGRITY" = "CONTROL_RLHYP01_INTEGRITY"
    "K1P0"      = "CONTROL_RLHYP01_K1P0"
    "K1P5"      = "CONTROL_RLHYP01_K1P5"
    "K2P0"      = "CONTROL_RLHYP01_K2P0"
}

function Write-ED01Log($msg) {
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
    foreach ($r in $Runs) {
        $entries += [pscustomobject]@{
            file = $r.File; kind = $r.Kind; tier = $r.Tier
            status = "PENDING"; start = $null; end = $null
            rows = $null; faults = $null; files = @()
        }
    }
    $m = [pscustomobject]@{
        protocol = "docs/Sprint22_RL_HYP_01_Protocol.md section 14 (A1 estimand; A2 pairing key)"
        authorized = "2026-08-11 protocol freeze + Amendment A2 acceptance; batch launch still requires explicit run authorization (protocol 15.3 step 7)"
        pairingKey = "canonical {signalTime, configFingerprint, symbol, timeframe} (Amendment A2)"
        runs = $entries
    }
    Save-Manifest $m
    return $m
}

function Get-Entry($m, $file, $kind) {
    foreach ($e in $m.runs) { if ($e.file -eq $file -and $e.kind -eq $kind) { return $e } }
    return $null
}

function Get-RowsWritten {
    #--- the tester may land on ANY agent (3000/3001/...); scan every
    #--- agent log for the latest Rows Written / I/O Faults (the Common
    #--- Files telemetry dir is cleared before each run, so the last
    #--- values across all agents belong to the current run)
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

function Invoke-RLHYP01Attempt([string]$ini, [string]$dir, [string]$label) {
    #--- clear previous run's telemetry files (filenames repeat per run)
    if (Test-Path -LiteralPath $Common) {
        Get-ChildItem -LiteralPath $Common -Filter "telemetry_v5_*.csv" -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
    Write-ED01Log "RUN    $label start"
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
        Get-ChildItem -LiteralPath $Common -Filter "telemetry_v5_*.csv" -ErrorAction SilentlyContinue |
            ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dir $_.Name) -Force
                $copied += $_.Name
            }
    }
    return $copied
}

function Invoke-RLHYP01Run {
    param([hashtable]$Run)
    $label = "$($Run.File)/$($Run.Kind)"
    $dir = Join-Path $Art "$($Run.File)\$($ArtDirs[$Run.Kind])"
    $done = Join-Path $dir ".done"
    $m = Get-Manifest
    $entry = Get-Entry $m $Run.File $Run.Kind

    if (Test-Path -LiteralPath $done) {
        Write-ED01Log "SKIP   $label (done)"
        $entry.status = "DONE"
        Save-Manifest $m
        return $true
    }
    #--- refuse to reuse a dir that already holds captures from a partial run
    $stale = @(Get-ChildItem -LiteralPath $dir -Filter "telemetry_v5_*.csv" -ErrorAction SilentlyContinue)
    if ($stale.Count -gt 0) {
        Write-ED01Log "ABORT  ${label}: non-empty artifact dir without .done ($($stale.Count) csv) - refusing to mix captures"
        $entry.status = "FAILED"
        Save-Manifest $m
        return $false
    }

    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $spec = $Files[$Run.File]
    $ini = Join-Path $IniDir "$($Run.File)_RLHYP01_$($Run.Kind).ini"
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
    [void]$sb.AppendLine("SwingSignificanceTier=$($Run.Tier)")
    Set-Content -LiteralPath $ini -Value $sb.ToString() -Encoding ASCII

    if ($DryRun) { Write-ED01Log "DRYRUN $label -> $ini (SwingSignificanceTier=$($Run.Tier))"; return $true }

    $entry.status = "RUNNING"
    $entry.start = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    Save-Manifest $m
    Write-ED01Log "CONFIG $label ini=$ini SwingSignificanceTier=$($Run.Tier)"

    #--- one retry per run: a wedged terminal can abort with no capture
    $attempts = 0
    $copied = @()
    do {
        $attempts++
        $copied = Invoke-RLHYP01Attempt $ini $dir $label
        if ($copied.Count -eq 0 -and $attempts -lt 2) {
            Write-ED01Log "RETRY  $label (no capture, attempt $attempts/2)"
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
        Set-Content -LiteralPath $done -Value ((Get-Date -Format "yyyy-MM-ddTHH:mm:ss") + " tier=$($Run.Tier) rows=$rows files=$($copied -join ',')") -Encoding ASCII
        Save-Manifest $m
        Write-ED01Log "DONE   $label tier=$($Run.Tier) rows=$rows files=$($copied -join ',')"
        return $true
    }
    $entry.status = "FAILED"
    Save-Manifest $m
    Write-ED01Log "EMPTY  $label rows=$rows (no csv captured after $attempts attempt(s) - NOT marked done; BATCH STOPPED)"
    return $false
}

New-Item -ItemType Directory -Path $Art -Force | Out-Null
New-Item -ItemType Directory -Path $IniDir -Force | Out-Null

if (-not (Test-Path -LiteralPath $Manifest)) {
    $m = New-EmptyManifest
    Write-ED01Log "=== RL-HYP-01 manifest created with the twelve authorized runs ==="
} else {
    $m = Get-Manifest
    Write-ED01Log "=== RL-HYP-01 batch resume: manifest exists ==="
}
foreach ($r in $m.runs) {
    Write-ED01Log "REGISTERED $($r.file)/$($r.kind) tier=$($r.tier) status=$($r.status)"
}

Write-ED01Log "=== RL-HYP-01 12-run batch start (launch gated on explicit run authorization) ==="
foreach ($run in $Runs) {
    if (-not (Invoke-RLHYP01Run $run)) {
        Write-ED01Log "=== RL-HYP-01 BATCH STOPPED (failure in $($run.File)/$($run.Kind)); manifest reflects FAILED; no further runs ==="
        exit 1
    }
}
Write-ED01Log "=== RL-HYP-01 12-run batch complete ==="
