# TT01_Validate.ps1 - TT01 Platform Validation Harness (Sprint 20)
# Single command:  powershell -File TT01_Validate.ps1
# Workflow: run TT01 -> all gates PASS -> commit. Answer to "did anything regress?".
#
# Gates: COMPILE (6 targets) | SUITE (unit suite summary) | REPLAY (real run)
#        TELEMETRY-CONTRACT | EVIDENCE-REGRESSION | BEHAVIOR-REGRESSION (vs frozen baseline)
#        PERFORMANCE (record + warn)  -> artifacts\TT01_<runId>\manifest.json
#
# Baseline history (canonical = B6 until the DD05 freeze; B7 after):
#   B4 (2026-08-05, commit aea90c6, original code) - SUPERSEDED. The B4 replay
#   environment proved non-deterministic: the terminal's tick cache drifted
#   between runs (5062 vs 1533 replay updates; pivot re-promotions 20000 vs
#   ~3500; locked-pivot sighting 1602 vs 267) while the OHLC data was
#   byte-identical (first-scan swing counts h=803/804, l=857/856) and no code
#   touched the swing/pivot/PP paths. The drift was environmental (tick-cache
#   refresh), NOT an algorithm change.
#   B5 (2026-08-06, commit 3de40b3, DD02 code, freezeId=B5) - the first
#   canonical TT01 regression baseline. Frozen only from verified green code;
#   verified deterministic (byte-identical reruns).
#   DD03 (2026-08-06) - first intentional algorithm correction: liquidity
#   sweep semantics changed from "forming-bar touch" to "confirmed closed-bar
#   reclaim" (AVP L C9 / doc 04 E1). Differences vs B5 are expected and must
#   be confined to the liquidity evidence whitelist (-AllowDelta) and the row
#   count (-ExpectedRows); everything else remains protected.
#   B6 (2026-08-06, DD03 code, freezeId=B6) - the first doctrinal baseline:
#   frozen after an evidence-backed algorithm improvement, not infrastructure
#   fixes. Transition chain: B4 (environment issue) -> B5 (platform stable)
#   -> DD03 (intentional algorithm correction) -> B6 (first doctrinal baseline).
#   Freeze procedure: run TT01 replay with the new code, copy the run CSV over
#   baseline\telemetry_v4_20260130.csv, then run with -FreezeBaseline -FreezeId B6
#   (freezeId default is B6 in this script).
#   DD04 (2026-08-06) - second intentional algorithm correction (ledger C10):
#   side-class written at CreateLevel + opposing-target resolver fixed. NOT
#   observable via TT01 telemetry: the plan path (CExecutionPlanner ->
#   plan.takeProfit -> live/shadow orders) is outside the replay chain (the
#   outcome sim uses the legacy CEntrySetupBuilder fixed-RR builder), so the
#   DD04 run is byte-identical vs B6 on all 500 rows - expected, no localization
#   or re-freeze. DD04 correctness is carried by unit tests 46-52 (suite gate).
#   DD05 (2026-08-07) - C08 executed: per-family admission floors in
#   ConfluenceValidator (Liquidity 0.60 / FVG 0.40 / OB-BOS-CHOCH 0.35, UNKNOWN
#   -> global 0.60 fallback; GR01 calibrates). Observable via TT01 by design:
#   configFingerprint differs on ALL 500 rows (the 5 floors are recorded in the
#   canonical - expected policy recording; constancy verified by CONTRACT), and
#   validatorResults/newDecision/decisionMatch differ on 208 decisions
#   (qualified 240 -> 442). Two harness evolutions for row-rooted localization:
#   (1) configFingerprint is exempted from the sequence-identity invariant when
#   -AllowDecisionIds is used (identity proven by decisionId/signalTime/symbol/
#   timeframe; the fingerprint change is the policy recording, not a sequence
#   shift); (2) the attribution invariant gains the admission-gate class: all
#   shared validator components must be identical except ConfluenceValidator
#   (which flips), any NEW component appeared only because the pipeline ran past
#   the gate (short-circuit collection on rejection) and a hard reject (2) among
#   them must not contradict the recorded verdict, and changed columns are
#   confined to validatorResults/newDecision/decisionMatch.
#   B7 (2026-08-07, DD05 code, freezeId=B7) - second doctrinal baseline:
#   the entry funnel opens per family for GR01. Freeze procedure as B6 (run TT01
#   replay with the new code, copy the run CSV over baseline\telemetry_v4_20260130.csv,
#   then run with -FreezeBaseline -FreezeId B7).
#
# Switches:
#   -Skip compile,suite,replay : skip those phases (validators still run on captured CSV)
#   -AllowDelta fvgClass,fvgSize : permit these columns/rules to differ from the frozen baseline
#   -ExpectedRows 500 : expected telemetry row count (replaces the baseline count
#        when a Sprint 20 fix intentionally changes the decision population)
#   -AllowDecisionIds 22,45,.. : row-rooted localization (DD03+). Only these
#        decisions may differ; all others must be byte-identical on ALL columns.
#        Enforces three invariants: decision identity (decisionId/signalTime/
#        symbol/timeframe - configFingerprint exempted during localization: it
#        records the routing policy and its constancy is verified by CONTRACT),
#        completeness (changed == allowed), and attribution (each allowed change
#        traces to the liquidity cascade or to the per-family admission gate:
#        ConfluenceValidator flip with identical shared components, new
#        components = pipeline continuation past the gate, verdict-consistent).
#        Pass a list or a file: -AllowDecisionIds (Get-Content allowlist.txt)
#   -FreezeBaseline : regenerate baseline\baseline.manifest.json from the frozen baseline CSV
#   -FreezeId B6 : baseline id stamped into the manifest at freeze time
#   -ArtifactsKeep 3 : number of per-run artifact dirs to retain
# Exit code: 0 = all gates PASS, 1 = any gate FAIL, 2 = environment error.

[CmdletBinding()]
param(
    [string[]]$Skip = @(),
    [string[]]$AllowDelta = @(),
    [int]$ExpectedRows = 500,
    [string[]]$AllowDecisionIds = @(),
    [switch]$FreezeBaseline,
    [string]$FreezeId = "B6",
    [int]$ArtifactsKeep = 3
)

$ErrorActionPreference = "Stop"
$script:TT01_HEADER_V31 = @()  # filled by validators

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root       = (git -C $ScriptDir rev-parse --show-toplevel) -replace "`n", ""
$DataFolder = Split-Path -Leaf (Split-Path -Parent $Root)
# RH01: repo root is now the EA root itself; support both layouts
$SC         = if (Test-Path (Join-Path $Root "Experts\SuperCents_X")) { Join-Path $Root "Experts\SuperCents_X" } else { $Root }
$BaseDir    = Join-Path $ScriptDir "baseline"
$RunDir     = Join-Path $ScriptDir "run"
$ArtDir     = Join-Path $ScriptDir "artifacts"
$BaseCsv    = Join-Path $BaseDir "telemetry_v4_20260130.csv"
$BaseMan    = Join-Path $BaseDir "baseline.manifest.json"
$OutCsv     = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\Telemetry\telemetry_v4_20260130.csv"
$TesterRoot = Join-Path $env:APPDATA "MetaQuotes\Tester"
# RH01: locate the agent dir directly under the Tester root, independent of
# repo depth / MT5 layout (Tester\<id>\Agent-... vs Tester\<id>\Experts\Agent-...)
$AgentDir   = Join-Path ((Get-ChildItem -LiteralPath $TesterRoot -Recurse -Directory -Filter "Agent-127.0.0.1-3000" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName) "logs"
$AgentLog   = Join-Path $AgentDir ((Get-Date -Format "yyyyMMdd") + ".log")
$MetaEditor = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
$Terminal   = "C:\Program Files\MetaTrader 5\terminal64.exe"

. (Join-Path $ScriptDir "TT01_Validators.ps1")

#--- embedded run specs (frozen profiles; identical settings to the Sprint 20 verification runs)
$script:SuiteIni = @'
[Tester]
Expert=SuperCents_X\Tests\TestRunnerEA.ex5
Symbol=EURUSD
Period=H1
Optimization=0
Model=4
FromDate=2026.01.01
ToDate=2026.01.02
ForwardMode=0
Deposit=10000
Currency=GBP
ProfitInPips=0
Leverage=200
ExecutionMode=1000
OptimizationCriterion=0
Visual=0
ReplaceReport=1
ShutdownTerminal=1
'@

$script:ReplayIni = @'
[Tester]
Expert=SuperCents_X\SuperCents_X.ex5
Symbol=EURUSD
Period=H1
Optimization=0
Model=4
FromDate=2026.01.01
ToDate=2026.02.01
ForwardMode=0
Deposit=10000
Currency=GBP
ProfitInPips=0
Leverage=200
ExecutionMode=1000
OptimizationCriterion=0
Visual=0
ReplaceReport=1
ShutdownTerminal=1

[TesterInputs]
'@

$script:CompileTargets = @(
    @{ Label = "SuperCents_X";     Path = Join-Path $SC "SuperCents_X.mq5" },
    @{ Label = "CalibrationRunner";Path = Join-Path $SC "CalibrationRunner.mq5" },
    @{ Label = "TestRunner";       Path = Join-Path $SC "Tests\TestRunner.mq5" },
    @{ Label = "TestRunnerEA";     Path = Join-Path $SC "Tests\TestRunnerEA.mq5" },
    @{ Label = "BenchmarkRunner";  Path = Join-Path $SC "benchmarks\BenchmarkRunner.mq5" },
    @{ Label = "BenchmarkRunnerEA";Path = Join-Path $SC "benchmarks\BenchmarkRunnerEA.mq5" }
)

$script:Results = [System.Collections.Generic.List[object]]::new()
$script:Perf = @{ suiteMs = 0; replayMs = 0; peakMemMB = 0 }

function Write-Step($s) { Write-Host "[TT01] $s" -ForegroundColor DarkCyan }

function New-Gate {
    param([string]$Name, [bool]$Pass, [string[]]$Details = @())
    $script:Results.Add([pscustomobject]@{ Name = $Name; Pass = $Pass; Details = @($Details) })
}

function Stop-TT01Terminal {
    $p = Get-Process terminal64 -ErrorAction SilentlyContinue
    if ($p) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 5 }
}

function Wait-TT01Exit {
    param([int]$TimeoutSec = 720)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    do { Start-Sleep -Seconds 3; $p = Get-Process terminal64 -ErrorAction SilentlyContinue }
    while ($p -and (Get-Date) -lt $deadline)
    return [bool]$p
}

function Start-TT01Headless {
    param([string]$IniPath)
    Stop-TT01Terminal
    Start-Process -FilePath $Terminal -ArgumentList "/config:`"$IniPath`"" -WorkingDirectory $Root | Out-Null
    $running = Wait-TT01Exit
    if ($running) { throw "terminal did not exit within timeout for $IniPath" }
}

function Get-TT01LastJournalRun {
    # Isolates the LAST "GRAND TOTAL" block in the agent journal (suite prints category
    # summary lines immediately before its GRAND TOTAL). Replay facts use last occurrence.
    param()
    if (-not (Test-Path $AgentLog)) { return @() }
    $all = Get-Content -LiteralPath $AgentLog
    $gtLines = @(for ($i = 0; $i -lt $all.Count; $i++) { if ($all[$i] -match "GRAND TOTAL") { $i } })
    if ($gtLines.Count -eq 0) { return @() }
    $start = if ($gtLines.Count -gt 1) { $gtLines[-2] + 1 } else { 0 }
    @($all[$start..$gtLines[-1]] | Where-Object { $_ -match ">>> |GRAND TOTAL" })
}

#--------------------------------------------------------------------- phases
function Invoke-TT01Compile {
    if ($Skip -contains "compile") { New-Gate "COMPILE" $true @("skipped"); return }
    Write-Step "COMPILE: 6 targets"
    $fail = 0
    foreach ($t in $script:CompileTargets) {
        $log = Join-Path $RunDir ("compile_" + $t.Label + ".log")
        Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
        Start-Process -FilePath $MetaEditor -ArgumentList "/compile:`"$($t.Path)`" /log:`"$log`"" -Wait | Out-Null
        Start-Sleep -Seconds 2
        $line = (Get-Content -LiteralPath $log -ErrorAction SilentlyContinue | Select-String "Result:" | Select-Object -Last 1).Line
        if ($line -match "(\d+) errors, (\d+) warnings") {
            $errs = [int]$Matches[1]; $warns = [int]$Matches[2]
            if ($errs -gt 0) { $fail++; New-Gate ("COMPILE-" + $t.Label) $false @($line) }
            else { New-Gate ("COMPILE-" + $t.Label) $true @($line) }
        } else {
            $fail++; New-Gate ("COMPILE-" + $t.Label) $false @("no Result line in $log")
        }
    }
    New-Gate "COMPILE" ($fail -eq 0) @("targets compiled: $($script:CompileTargets.Count)")
}

function Invoke-TT01Suite {
    if ($Skip -contains "suite") { New-Gate "SUITE" $true @("skipped"); return }
    Write-Step "SUITE: headless unit suite"
    $ini = Join-Path $RunDir "TT01_Suite.ini"
    Set-Content -LiteralPath $ini -Value $script:SuiteIni -Encoding ASCII
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Start-TT01Headless $ini
    $sw.Stop(); $script:Perf.suiteMs = $sw.ElapsedMilliseconds
    $block = Get-TT01LastJournalRun
    if ($block.Count -eq 0) { New-Gate "SUITE" $false @("no GRAND TOTAL block found in $AgentLog"); return }
    $grand = $block | Where-Object { $_ -match "GRAND TOTAL" } | Select-Object -Last 1
    if ($grand -match "GRAND TOTAL: (\d+)/(\d+) passed, (\d+) failed") {
        $passed = [int]$Matches[1]; $total = [int]$Matches[2]; $failed = [int]$Matches[3]
        $cats = @($block | Where-Object { $_ -match ">>> " } | ForEach-Object { ($_ -replace "^.*>>> ", "").Trim() })
        New-Gate "SUITE" ($failed -eq 0) @("$passed/$total passed, $failed failed", "categories: $($cats.Count)", ($cats -join " ; "))
    } else {
        New-Gate "SUITE" $false @("unparseable GRAND TOTAL: $grand")
    }
}

function Invoke-TT01Replay {
    if ($Skip -contains "replay") { New-Gate "REPLAY" $true @("skipped; CSV from previous run reused"); return }
    Write-Step "REPLAY: real EURUSD H1 telemetry run"
    Remove-Item -LiteralPath $OutCsv -Force -ErrorAction SilentlyContinue
    $ini = Join-Path $RunDir "TT01_Replay.ini"
    Set-Content -LiteralPath $ini -Value $script:ReplayIni -Encoding ASCII
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $peak = 0L
    $monitor = Start-Job -ScriptBlock {
        param($Name)
        $max = 0L
        while ($true) {
            $p = Get-Process $Name -ErrorAction SilentlyContinue
            if ($p) { foreach ($x in $p) { if ($x.WorkingSet64 -gt $max) { $max = $x.WorkingSet64 } } }
            Write-Output $max
            Start-Sleep -Milliseconds 1500
        }
    } -ArgumentList "terminal64"
    Start-TT01Headless $ini
    Stop-Job $monitor -ErrorAction SilentlyContinue
    $samples = @(Receive-Job $monitor -ErrorAction SilentlyContinue | Where-Object { $_ -is [long] -or $_ -is [double] })
    Remove-Job $monitor -Force -ErrorAction SilentlyContinue
    $peak = if ($samples.Count -gt 0) { $samples[-1] } else { 0L }
    $sw.Stop(); $script:Perf.replayMs = $sw.ElapsedMilliseconds
    $script:Perf.peakMemMB = [math]::Round([double]$peak / 1MB, 1)

    if (-not (Test-Path $AgentLog)) { New-Gate "REPLAY" $false @("agent log missing"); return }
    $all = Get-Content -LiteralPath $AgentLog
    $rows = [int](-1); $faults = [int](-1)
    foreach ($line in $all) {
        if ($line -match "Rows Written\s+(\d+)") { $rows = [int]$Matches[1] }
        if ($line -match "I/O Faults\s+(\d+)") { $faults = [int]$Matches[1] }
    }
    $healthy = @($all | Where-Object { $_ -match "Overall Status\s+(\S+)" } | ForEach-Object { $Matches[1] } | Select-Object -Last 1)
    $crit = @($all | Where-Object { $_ -match "Critical\s+(\d+)" } | ForEach-Object { [int]$Matches[1] } | Select-Object -Last 1)
    $healthVerdict = (($healthy -join ",") -eq "HEALTHY") -and (([int]($crit -join ",")) -eq 0)

    $ok = $false
    $deadline = (Get-Date).AddMinutes(10)
    while (-not $ok -and (Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $OutCsv) {
            $h1 = (Get-FileHash -LiteralPath $OutCsv -ErrorAction SilentlyContinue).Hash
            Start-Sleep -Seconds 2
            $h2 = (Get-FileHash -LiteralPath $OutCsv -ErrorAction SilentlyContinue).Hash
            if ($h1 -eq $h2) { $ok = $true }
        }
        if (-not $ok) { Start-Sleep -Seconds 5 }
    }
    $pass = ($rows -eq $ExpectedRows) -and ($faults -eq 0) -and $healthVerdict -and $ok
    $script:Perf.csvBytes = (Get-Item -LiteralPath $OutCsv -ErrorAction SilentlyContinue).Length
    New-Gate "REPLAY" $pass @("rows=$rows expected=$ExpectedRows faults=$faults health=$healthy critical=$crit csvCaptured=$ok")
}

function Invoke-TT01Contract {
    $res = Test-TT01Contract -Path $OutCsv
    $res | Add-Member -NotePropertyName Name -NotePropertyValue "TELEMETRY-CONTRACT" -Force
    $script:Results.Add($res)
}

function Invoke-TT01Evidence {
    $res = Test-TT01Evidence -Path $OutCsv
    $res | Add-Member -NotePropertyName Name -NotePropertyValue "EVIDENCE-REGRESSION" -Force
    $script:Results.Add($res)
}

function Invoke-TT01Behavior {
    $res = Test-TT01Behavior -RunPath $OutCsv -BasePath $BaseCsv -AllowDelta $AllowDelta -ExpectedRows $ExpectedRows -AllowDecisionIds $AllowDecisionIds
    $script:Results.Add($res)
}

function Invoke-TT01Perf {
    $detail = [System.Collections.Generic.List[string]]::new()
    $detail.Add("replayMs=$($script:Perf.replayMs) suiteMs=$($script:Perf.suiteMs) peakMemMB=$($script:Perf.peakMemMB)")
    if ($script:Perf.csvBytes) { $detail.Add("csvBytes=$($script:Perf.csvBytes) rowsPerSec=$([math]::Round($ExpectedRows / ($script:Perf.replayMs / 1000.0), 1))") }
    $warn = 0
    if (Test-Path -LiteralPath $BaseMan) {
        $base = Get-Content -LiteralPath $BaseMan -Raw | ConvertFrom-Json
        if ($base.perf.replayMs -and $script:Perf.replayMs -gt 2 * $base.perf.replayMs) {
            $warn++; $detail.Add("WARN: replay $($script:Perf.replayMs) ms > 2x baseline $($base.perf.replayMs) ms")
        }
        if ($base.perf.suiteMs -and $script:Perf.suiteMs -gt 2 * $base.perf.suiteMs) {
            $warn++; $detail.Add("WARN: suite $($script:Perf.suiteMs) ms > 2x baseline $($base.perf.suiteMs) ms")
        }
    }
    New-Gate "PERFORMANCE" $true @($detail.ToArray())
}

function Update-TT01BaselinePerf {
    $base = Get-Content -LiteralPath $BaseMan -Raw | ConvertFrom-Json
    if ($base.perf.replayMs) { return }  # already frozen
    $base.perf.replayMs = $script:Perf.replayMs
    $base.perf.suiteMs = $script:Perf.suiteMs
    $base.perf.csvBytes = $script:Perf.csvBytes
    $base.perf.rowsPerSec = [math]::Round($ExpectedRows / ($script:Perf.replayMs / 1000.0), 1)
    $base.perf.peakMemMB = $script:Perf.peakMemMB
    $base | Add-Member -NotePropertyName perfFrozenFromFirstRun -NotePropertyValue $true -Force
    $base | Add-Member -NotePropertyName perfFrozenCommit -NotePropertyValue (git -C $ScriptDir rev-parse --short HEAD) -Force
    $base | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $BaseMan -Encoding UTF8
    Write-Step "baseline perf frozen from this green run (replayMs=$($base.perf.replayMs))"
}

#--------------------------------------------------------------------- main
New-Item -ItemType Directory -Path $RunDir -Force | Out-Null
New-Item -ItemType Directory -Path $ArtDir -Force | Out-Null
if (-not (Test-Path -LiteralPath $BaseCsv)) { Write-Error "frozen baseline CSV missing: $BaseCsv"; exit 2 }

$gitHead = git -C $ScriptDir rev-parse --short HEAD
$runId = "TT01_" + (Get-Date -Format "yyyyMMdd_HHmmss")
$runArt = Join-Path $ArtDir $runId
New-Item -ItemType Directory -Path $runArt -Force | Out-Null

Write-Host "=== TT01 Platform Validation Harness ===" -ForegroundColor Cyan
Write-Host "runId=$runId git=$gitHead skip=$($Skip -join ',') allowDelta=$($AllowDelta -join ',') expectedRows=$ExpectedRows allowDecisionIds=$($AllowDecisionIds.Count)"

if ($FreezeBaseline) {
    Write-Step "FREEZE: regenerating baseline manifest from frozen CSV"
    $counters = Get-TT01Counters $BaseCsv
    $man = [ordered]@{
        freezeId = $FreezeId
        frozenAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        commit = $gitHead
        profile = "Sprint20_TC02_Telemetry.ini (embedded TT01_Replay.ini)"
        symbol = "EURUSD"; period = "H1"
        fromDate = "2026.01.01"; toDate = "2026.02.01"
        rows = $counters.rows
        csvBytes = (Get-Item -LiteralPath $BaseCsv).Length
        csvSha256 = Get-TT01CsvHash $BaseCsv
        headerColumns = 75
        firstSignalTime = $counters.firstSignalTime
        lastSignalTime = $counters.lastSignalTime
        counters = $counters
        perf = @{ replayMs = $null; suiteMs = $null; csvBytes = $null; rowsPerSec = $null; peakMemMB = $null }
        perfFrozenFromFirstRun = $false
        perfFrozenCommit = $null
    }
    $man | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $BaseMan -Encoding UTF8
    Write-Step "baseline manifest written: $BaseMan"
}

if (-not (Test-Path -LiteralPath $BaseMan)) { Write-Error "baseline manifest missing - run with -FreezeBaseline first"; exit 2 }

Invoke-TT01Compile
Invoke-TT01Suite
Invoke-TT01Replay
if (-not (Test-Path -LiteralPath $OutCsv)) {
    New-Gate "TELEMETRY-CONTRACT" $false @("no CSV to validate at $OutCsv")
    New-Gate "EVIDENCE-REGRESSION" $false @("no CSV to validate at $OutCsv")
    New-Gate "BEHAVIOR-REGRESSION" $false @("no CSV to validate at $OutCsv")
} else {
    Invoke-TT01Contract
    Invoke-TT01Evidence
    Invoke-TT01Behavior
    Copy-Item -LiteralPath $OutCsv -Destination (Join-Path $runArt "telemetry_v4_20260130.csv") -Force
}
Invoke-TT01Perf

$allPass = ($script:Results | Where-Object { -not $_.Pass }).Count -eq 0
if ($allPass -and (Test-Path -LiteralPath $BaseMan) -and $script:Perf.replayMs -gt 0) {
    Update-TT01BaselinePerf
}

#--- manifest
$manifest = [ordered]@{
    runId = $runId
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
    gitHead = $gitHead
    overall = if ($allPass) { "PASS" } else { "FAIL" }
    allowDelta = $AllowDelta
    expectedRows = $ExpectedRows
    allowDecisionIds = $AllowDecisionIds.Count
    gates = @($script:Results | ForEach-Object { [ordered]@{ name = $_.Name; pass = $_.Pass; details = @($_.Details) } })
    perf = $script:Perf
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runArt "manifest.json") -Encoding UTF8

#--- summary table
Write-Host ""
Write-Host "=== TT01 summary ($runId) ===" -ForegroundColor Cyan
foreach ($r in $script:Results) {
    $icon = if ($r.Pass) { "PASS" } else { "FAIL" }
    $color = if ($r.Pass) { "Green" } else { "Red" }
    Write-Host ("  [{0,-20}] {1}" -f $r.Name, $icon) -ForegroundColor $color
    foreach ($d in $r.Details) { Write-Host ("      - {0}" -f $d) -ForegroundColor Gray }
}
Write-Host ""
$over = if ($allPass) { "OVERALL: PASS" } else { "OVERALL: FAIL" }
Write-Host $over -ForegroundColor $(if ($allPass) { "Green" } else { "Red" })
Write-Host ("artifacts: {0}" -f $runArt)

#--- cleanup old artifacts (keep newest N)
$old = @(Get-ChildItem -LiteralPath $ArtDir -Directory | Sort-Object Name -Descending | Select-Object -Skip $ArtifactsKeep)
foreach ($d in $old) { Remove-Item -LiteralPath $d.FullName -Recurse -Force -ErrorAction SilentlyContinue }

if ($allPass) { exit 0 } else { exit 1 }
