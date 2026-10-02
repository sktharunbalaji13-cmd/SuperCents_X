# EN03_FM2_Run.ps1 - EN-03 Phase 2 targeted FM-2 adversarial scenario,
# 4-arm batch.
# Authorized research (docs/Sprint24_EN03_Assessment.md, Phase 2; user
# authorization 2026-08-13): validate the coordinated gate on a synthetic
# same-tick BOS-flip + opposite-CHOCH construction. No production change,
# no commit, no closure doc.
#
# Runs EXACTLY four arms, in order (EURUSD H1, 2026.01.01..2026.02.01 -
# the Phase-1 profile with cached history; the scenario EA is fully
# synthetic - the market data only needs to deliver at least one tick -
# Model=4, Deposit 10000 GBP, Leverage 200, ExecutionMode 1000):
#   LEGACY       EN03GateStrategy=0 EN03ArmLabel=legacy  (production behavior)
#   OFF          EN03GateStrategy=1 EN03ArmLabel=off     (gate disabled)
#   COORDINATED  EN03GateStrategy=2 EN03ArmLabel=coord   (fix option B)
#   COORDINATED2 EN03GateStrategy=2 EN03ArmLabel=coord2  (replay determinism)
#
# The scenario EA replays a fixed 33-bar synthetic table; the capture is
# Tools/Common/Files/Telemetry/en03_fm2_<label>.csv (one state row per
# window W=5..33). The ONLY deltas between arms are EN03GateStrategy and
# the arm label.
#
# Artifacts: Tools/EN03/fm2_artifacts/<ARM>/ with en03_fm2_*.csv +
# telemetry + population + .done marker. Manifest:
# Tools/EN03/EN03_FM2_manifest.json, written incrementally.
#
# Hard rules (EN03_Phase1_Run.ps1 pattern): resumable via .done; never
# accept an empty artifact silently; never fabricate a .done; on ANY run
# failure STOP the batch, mark FAILED, exit non-zero; raw artifacts stay
# on disk; nothing is committed by this script.
#
# Usage: powershell -File EN03_FM2_Run.ps1  (-DryRun prints the plan
#        and writes INIs/manifest without launching the tester)

param(
    [switch]$DryRun,
    [string]$ArtRoot = "fm2_artifacts"
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
$Log     = Join-Path $PSScriptRoot "run_EN03_FM2.log"
$Manifest = Join-Path $PSScriptRoot "EN03_FM2_manifest.json"

$Arms = @(
    @{ Name = "LEGACY";      Strategy = 0; Label = "legacy" }
    @{ Name = "OFF";         Strategy = 1; Label = "off" }
    @{ Name = "COORDINATED"; Strategy = 2; Label = "coord" }
    @{ Name = "COORDINATED2"; Strategy = 2; Label = "coord2" }
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
            arm = $a.Name; strategy = $a.Strategy; label = $a.Label
            status = "PENDING"; start = $null; end = $null
            faults = $null; files = @(); fm2 = $null
        }
    }
    $m = [pscustomobject]@{
        protocol = "docs/Sprint24_EN03_Assessment.md Phase 2 (targeted FM-2 adversarial validation)"
        authorized = "2026-08-13 user authorization (Q1/Q3 YES; research first; no A/B selection)"
        validityGate = "COORDINATED2 fm2 CSV must equal COORDINATED byte-identical (replay determinism)"
        arms = $entries
    }
    Save-Manifest $m
    return $m
}

function Get-Entry($m, $name) {
    foreach ($e in $m.arms) { if ($e.arm -eq $name) { return $e } }
    return $null
}

function Invoke-FM2Attempt([string]$ini, [string]$dir, [string]$label) {
    #--- clear previous run's fm2/pop/telemetry files (filenames repeat
    #--- per run; mixing arms would poison the analysis)
    if (Test-Path -LiteralPath $Common) {
        Get-ChildItem -LiteralPath $Common -Filter "en03_fm2_*.csv" -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath $Common -Filter "en03_pop_*.csv" -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath $Common -Filter "telemetry_v5_*.csv" -ErrorAction SilentlyContinue |
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

    #--- copy captured files BEFORE anything else so a failure cannot
    #--- lose the capture
    $copied = @()
    if (Test-Path -LiteralPath $Common) {
        Get-ChildItem -LiteralPath $Common -Filter "en03_fm2_*.csv" -ErrorAction SilentlyContinue |
            ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dir $_.Name) -Force
                $copied += $_.Name
            }
        Get-ChildItem -LiteralPath $Common -Filter "en03_pop_*.csv" -ErrorAction SilentlyContinue |
            ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dir $_.Name) -Force
                $copied += $_.Name
            }
        Get-ChildItem -LiteralPath $Common -Filter "telemetry_v5_*.csv" -ErrorAction SilentlyContinue |
            ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dir $_.Name) -Force
                $copied += $_.Name
            }
    }
    return $copied
}

function Invoke-FM2Run {
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
    $ini = Join-Path $IniDir "EN03_FM2_$($Arm.Name).ini"
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("[Tester]")
    [void]$sb.AppendLine("Expert=SuperCents_X\Tools\EN03\EN03_FM2Scenario.ex5")
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
    [void]$sb.AppendLine("EN03ArmLabel=$($Arm.Label)")
    Set-Content -LiteralPath $ini -Value $sb.ToString() -Encoding ASCII

    if ($DryRun) { Write-EN03Log "DRYRUN $label -> $ini (strategy=$($Arm.Strategy) label=$($Arm.Label))"; return $true }

    $entry.status = "RUNNING"
    $entry.start = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    Save-Manifest $m
    Write-EN03Log "CONFIG $label ini=$ini strategy=$($Arm.Strategy) label=$($Arm.Label)"

    #--- one retry per run: a wedged terminal can abort with no capture
    $attempts = 0
    $copied = @()
    do {
        $attempts++
        $copied = Invoke-FM2Attempt $ini $dir $label
        if ($copied.Count -eq 0 -and $attempts -lt 2) {
            Write-EN03Log "RETRY  $label (no capture, attempt $attempts/2)"
            Start-Sleep -Seconds 20
        }
    } while ($copied.Count -eq 0 -and $attempts -lt 2)

    $entry.end = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    if ($copied.Count -gt 0) {
        $entry.files = @($copied)
        $fm2 = @($copied | Where-Object { $_ -like "en03_fm2_*" })
        $entry.fm2 = if ($fm2.Count -gt 0) { $fm2[0] } else { $null }
        $entry.status = "DONE"
        Set-Content -LiteralPath $done -Value ((Get-Date -Format "yyyy-MM-ddTHH:mm:ss") + " strategy=$($Arm.Strategy) files=$($copied -join ',')") -Encoding ASCII
        Save-Manifest $m
        Write-EN03Log "DONE   $label strategy=$($Arm.Strategy) files=$($copied -join ',')"
        return $true
    }
    $entry.status = "FAILED"
    Save-Manifest $m
    Write-EN03Log "EMPTY  $label (no csv captured after $attempts attempt(s) - NOT marked done; BATCH STOPPED)"
    return $false
}

New-Item -ItemType Directory -Path $Art -Force | Out-Null
New-Item -ItemType Directory -Path $IniDir -Force | Out-Null

if (-not (Test-Path -LiteralPath $Manifest)) {
    $m = New-EmptyManifest
    Write-EN03Log "=== EN-03 FM2 manifest created with the four authorized arms ==="
} else {
    $m = Get-Manifest
    Write-EN03Log "=== EN-03 FM2 batch resume: manifest exists ==="
}
foreach ($a in $m.arms) {
    Write-EN03Log "REGISTERED $($a.arm) strategy=$($a.strategy) label=$($a.label) status=$($a.status)"
}

Write-EN03Log "=== EN-03 FM2 4-arm batch start (research harness; no production change) ==="
foreach ($arm in $Arms) {
    if (-not (Invoke-FM2Run $arm)) {
        Write-EN03Log "=== EN-03 FM2 BATCH STOPPED (failure in $($arm.Name)); manifest reflects FAILED; no further runs ==="
        exit 1
    }
}
Write-EN03Log "=== EN-03 FM2 4-arm batch complete ==="
