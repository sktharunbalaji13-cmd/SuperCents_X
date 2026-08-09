# ED01_D_RunBatch.ps1 - Sprint 20 ED01-D six-run batch (authorized 2026-08-09).
# Frozen protocol: docs/Sprint20_ED01D_Protocol.md section 14.
#
# Runs EXACTLY six runs, in order:
#   INTEGRITY (FIXED_RR, OutcomeTpMode=0): EURUSD_H1, GBPJPY_H1, EURUSD_M15
#   OPPOSING (OPPOSING_LIQUIDITY, OutcomeTpMode=1): EURUSD_H1, GBPJPY_H1, EURUSD_M15
#
# Each run uses the frozen CONTROL profile (identical to Tools/ED01/ini/
# <FILE>_CONTROL.ini): Expert SuperCents_X\SuperCents_X.ex5, per-file
# Symbol/Period, FromDate 2026.04.05, ToDate 2026.07.05, Model=4,
# Deposit 10000 GBP, Leverage 200, ExecutionMode 1000, EntryMode=2,
# B8 weights 25/20/15/15/15/10. The ONLY delta between arms is the
# [TesterInputs] OutcomeTpMode override (0 = integrity, 1 = opposing).
#
# Artifacts: Tools/ED01/artifacts/<FILE>/CONTROL_ED01D_INTEGRITY|OPPOSING/
# with telemetry_v4_*.csv + .done marker (like the ED01-A runner).
#
# Two-arm manifest: Tools/ED01/ED01_D_manifest.json - one entry per run:
# file, kind, mode, status (PENDING/RUNNING/DONE/FAILED), start, end,
# rows, faults, files. Written incrementally so a crash never loses it.
#
# Hard rules (user mandate):
#   - Resumable: a run is skipped when its .done marker exists.
#   - Record start/end time and success/failure for every run.
#   - Never accept an empty artifact silently; never fabricate a .done.
#   - On ANY run failure: STOP the batch, mark FAILED, exit non-zero.
#   - Raw artifacts stay on disk; nothing is committed by this script.
#
# Usage: powershell -File ED01_D_RunBatch.ps1

param(
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
$Log     = Join-Path $PSScriptRoot "run_ED01D.log"
$Manifest = Join-Path $PSScriptRoot "ED01_D_manifest.json"

$Files = [ordered]@{
    "EURUSD_H1"  = @{ Symbol = "EURUSD"; Period = "H1" }
    "GBPJPY_H1"  = @{ Symbol = "GBPJPY"; Period = "H1" }
    "EURUSD_M15" = @{ Symbol = "EURUSD"; Period = "M15" }
}

# The authorized six runs (protocol section 14): file, kind, mode, TP input.
$Runs = @(
    @{ File = "EURUSD_H1";  Kind = "INTEGRITY"; Mode = "FIXED_RR";           Tp = 0 }
    @{ File = "GBPJPY_H1";  Kind = "INTEGRITY"; Mode = "FIXED_RR";           Tp = 0 }
    @{ File = "EURUSD_M15"; Kind = "INTEGRITY"; Mode = "FIXED_RR";           Tp = 0 }
    @{ File = "EURUSD_H1";  Kind = "OPPOSING";  Mode = "OPPOSING_LIQUIDITY"; Tp = 1 }
    @{ File = "GBPJPY_H1";  Kind = "OPPOSING";  Mode = "OPPOSING_LIQUIDITY"; Tp = 1 }
    @{ File = "EURUSD_M15"; Kind = "OPPOSING";  Mode = "OPPOSING_LIQUIDITY"; Tp = 1 }
)

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
            file = $r.File; kind = $r.Kind; mode = $r.Mode
            status = "PENDING"; start = $null; end = $null
            rows = $null; faults = $null; files = @()
        }
    }
    $m = [pscustomobject]@{
        protocol = "docs/Sprint20_ED01D_Protocol.md section 14"
        authorized = "2026-08-09 user authorization (six-run batch)"
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

function Invoke-ED01DAttempt([string]$ini, [string]$dir, [string]$label) {
    #--- clear previous run's telemetry files (filenames repeat per run)
    if (Test-Path -LiteralPath $Common) {
        Get-ChildItem -LiteralPath $Common -Filter "telemetry_v4_*.csv" -ErrorAction SilentlyContinue |
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
        Get-ChildItem -LiteralPath $Common -Filter "telemetry_v4_*.csv" -ErrorAction SilentlyContinue |
            ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dir $_.Name) -Force
                $copied += $_.Name
            }
    }
    return $copied
}

function Invoke-ED01DRun {
    param([hashtable]$Run)
    $label = "$($Run.File)/$($Run.Kind)"
    $dir = Join-Path $Art "$($Run.File)\$(if ($Run.Kind -eq 'INTEGRITY') { 'CONTROL_ED01D_INTEGRITY' } else { 'CONTROL_ED01D_OPPOSING' })"
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
    $stale = @(Get-ChildItem -LiteralPath $dir -Filter "telemetry_v4_*.csv" -ErrorAction SilentlyContinue)
    if ($stale.Count -gt 0) {
        Write-ED01Log "ABORT  ${label}: non-empty artifact dir without .done ($($stale.Count) csv) - refusing to mix captures"
        $entry.status = "FAILED"
        Save-Manifest $m
        return $false
    }

    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $spec = $Files[$Run.File]
    $ini = Join-Path $IniDir "$($Run.File)_ED01D_$($Run.Kind).ini"
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
    [void]$sb.AppendLine("OutcomeTpMode=$($Run.Tp)")
    Set-Content -LiteralPath $ini -Value $sb.ToString() -Encoding ASCII

    if ($DryRun) { Write-ED01Log "DRYRUN $label -> $ini (OutcomeTpMode=$($Run.Tp))"; return $true }

    $entry.status = "RUNNING"
    $entry.start = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    Save-Manifest $m
    Write-ED01Log "CONFIG $label ini=$ini OutcomeTpMode=$($Run.Tp)"

    #--- one retry per run: a wedged terminal can abort with no capture
    $attempts = 0
    $copied = @()
    do {
        $attempts++
        $copied = Invoke-ED01DAttempt $ini $dir $label
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
        Set-Content -LiteralPath $done -Value ((Get-Date -Format "yyyy-MM-ddTHH:mm:ss") + " rows=$rows files=$($copied -join ',')") -Encoding ASCII
        Save-Manifest $m
        Write-ED01Log "DONE   $label rows=$rows files=$($copied -join ',')"
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
    Write-ED01Log "=== ED01-D manifest created with the six authorized runs ==="
} else {
    $m = Get-Manifest
    Write-ED01Log "=== ED01-D batch resume: manifest exists ==="
}
foreach ($r in $m.runs) {
    Write-ED01Log "REGISTERED $($r.file)/$($r.kind) $($r.mode) status=$($r.status)"
}

Write-ED01Log "=== ED01-D six-run batch start ==="
foreach ($run in $Runs) {
    if (-not (Invoke-ED01DRun $run)) {
        Write-ED01Log "=== ED01-D BATCH STOPPED (failure in $($run.File)/$($run.Kind)); manifest reflects FAILED; no further runs ==="
        exit 1
    }
}
Write-ED01Log "=== ED01-D six-run batch complete ==="
