# TT01_Validate.ps1 - TT01 Platform Validation Harness (Sprint 20)
# Single command:  powershell -File TT01_Validate.ps1
# Workflow: run TT01 -> all gates PASS -> commit. Answer to "did anything regress?".
#
# Gates: COMPILE (6 targets) | SUITE (unit suite summary) | REPLAY (real run)
#        TELEMETRY-CONTRACT | EVIDENCE-REGRESSION | BEHAVIOR-REGRESSION (vs frozen baseline)
#        ACTIVE-TIER (Sprint 22: second replay with SwingSignificanceTier=1.0,
#        nGatedOut >= 1, ADMIT recording, fingerprint invariance, decision subset,
#        admitted rows byte-identical on shared columns - 11.3c/3b evidence)
#        SETTLEMENT-ISOLATION (Sprint 22 Design A: tiered pair over the
#        DEFECT-FIRING window EURUSD M15 2026-04-05..07-05 - the frozen batch
#        window - replaying tier 0.0 vs 1.0 with the SAME profile; every
#        admitted row must be byte-identical on all shared non-gate columns
#        (the 58 -> 0 acceptance; RED on the unfixed build, GREEN after
#        Design A: SettleDue hoisted to run on GATE-OUT bars too)
#        INTEGRITY-CONTROL (Design A ?8.3: the fresh tier-0 arm vs the frozen
#        CONTROL_RLHYP01 batch artifact, byte-identical - determinism guard,
#        criterion 6)
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
    [int]$ArtifactsKeep = 10,
    [switch]$OnlyIsolation
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
$OutCsv     = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\Telemetry\telemetry_v6_20260130.csv"
# Sprint 22 Design A: the isolation replay window emits MANY dated CSVs
# (the collector rotates by buffer flush; the batch artifacts show the same
# segmenting). The isolation arms capture every telemetry_v*.csv file
# (B25-01: fresh arms record schema v6; the frozen CONTROL dir stays v5).
$TelemetryDir = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\Telemetry"
# Frozen Sprint-22 batch artifact (CONTROL arm, EURUSD M15 2026-04-05..07-05,
# tier 0.0): the INTEGRITY-CONTROL determinism guard compares the fresh
# isolation CONTROL arm against it byte-for-byte.
$IsolationControlDir = Join-Path $Root "Tools\ED01\artifacts\EURUSD_M15\CONTROL_RLHYP01_INTEGRITY"
$TesterRoot = Join-Path $env:APPDATA "MetaQuotes\Tester"
# RH01: locate the agent dir directly under the Tester root, independent of
# repo depth / MT5 layout (Tester\<id>\Agent-... vs Tester\<id>\Experts\Agent-...)
$AgentDir   = Join-Path ((Get-ChildItem -LiteralPath $TesterRoot -Recurse -Directory -Filter "Agent-127.0.0.1-3000" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName) "logs"
$AgentLog   = Join-Path $AgentDir ((Get-Date -Format "yyyyMMdd") + ".log")
$MetaEditor = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
$Terminal   = "C:\Program Files\MetaTrader 5\terminal64.exe"

#--- 25A-RUNTIME-01: build/runtime identity infrastructure
$InstallDir       = Split-Path -Parent $Terminal
$TerminalDataRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal"
$DataFolderId     = Get-ChildItem -LiteralPath $TerminalDataRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.FullName "MQL5\Experts\SuperCents_X") } |
    Select-Object -First 1 -ExpandProperty Name
$DataFolderDir    = Join-Path $TerminalDataRoot $DataFolderId
$OriginFile       = Join-Path $DataFolderDir "origin.txt"
$CanonicalTestRunner = Join-Path $SC "Tests\TestRunnerEA.ex5"

$script:BuildIdentity = @{
    sourceTree = @{ gitHeadFull = $null; gitHeadShort = $null; dirty = $null; dirtyLines = 0 }
    dataFolder = @{ id = $DataFolderId; dir = $DataFolderDir; originBinding = $null; installDir = $InstallDir;
                    terminalVersion = $null; metaeditorVersion = $null; canonicalEx5 = $CanonicalTestRunner }
    artifacts  = @{}
    runtime    = @{ buildLine = $null; suiteStartedLine = $null; grandTotalLine = $null;
                    sliceFile = $null; sliceLines = 0; binaryArchiveDir = $null;
                    prodBuildLine = $null }
    run        = @{ runId = $null; compileFinishedAt = $null; suiteRunAt = $null; suiteRunFinishedAt = $null;
                    prodCompileStartedAt = $null; prodCompileEndedAt = $null }
    telemetry  = @{}
}

function Get-TT01ArtifactState {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        $f = Get-Item -LiteralPath $Path
        [ordered]@{ hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash; size = $f.Length; mtime = $f.LastWriteTime }
    } else {
        [ordered]@{ hash = $null; size = 0; mtime = $null }
    }
}

function Format-TT01BuildTime {
    param([datetime]$Time)
    $Time.ToString("yyyy.MM.dd HH:mm:ss")
}

function Get-TT01SourceClosure {
    # Recursively resolves local #include "..." from a target .mq5; returns
    # sorted relative paths (system includes <...> are platform libs, excluded).
    param([string]$TargetPath)
    $files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $queue = [System.Collections.Generic.Queue[string]]::new()
    $queue.Enqueue($TargetPath)
    while ($queue.Count -gt 0) {
        $cur = $queue.Dequeue()
        if (-not (Test-Path -LiteralPath $cur)) { continue }
        if (-not $files.Add($cur)) { continue }
        $dir = Split-Path -Parent $cur
        foreach ($inc in (Select-String -LiteralPath $cur -Pattern '^\s*#include\s+"([^"]+)"' -ErrorAction SilentlyContinue)) {
            $incPath = Join-Path $dir $inc.Matches[0].Groups[1].Value
            if (Test-Path -LiteralPath $incPath) { $queue.Enqueue($incPath) }
        }
    }
    return @($files | Sort-Object)
}

function Get-TT01SourceClosureHash {
    param([string]$TargetPath)
    $parts = @()
    foreach ($f in (Get-TT01SourceClosure $TargetPath)) {
        $h = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash
        $parts += ("$f`t$h")
    }
    if ($parts.Count -eq 0) { return $null }
    $joined = [System.Text.StringBuilder]::new()
    foreach ($p in $parts) { [void]$joined.Append($p); [void]$joined.Append("|") }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    return ([BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($joined.ToString())))).Replace("-", "")
}

function Invoke-TT01Preflight {
    # E: verify the MT5 install/data-folder binding and detect unexpected
    # duplicate EX5 copies anywhere in the runtime topology.
    $detail = [System.Collections.Generic.List[string]]::new()
    $ok = $true
    if (-not $DataFolderId) { $ok = $false; $detail.Add("terminal data folder for SuperCents_X NOT found under $TerminalDataRoot") }
    else {
        $detail.Add("dataFolder=$DataFolderId")
        if (Test-Path -LiteralPath $OriginFile) {
            $origin = (Get-Content -LiteralPath $OriginFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
            $script:BuildIdentity.dataFolder.originBinding = $origin
            if ($origin -eq $InstallDir) { $detail.Add("originBinding OK: $origin") }
            else { $ok = $false; $detail.Add("originBinding MISMATCH: '$origin' != install '$InstallDir'") }
        } else { $ok = $false; $detail.Add("origin.txt missing in $DataFolderDir - data-folder binding unprovable") }
        $foreign = @()
        foreach ($d in (Get-ChildItem -LiteralPath $TerminalDataRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne $DataFolderId -and $_.Name -notin @("Common", "Community", "Help") })) {
            $foreign += @(Get-ChildItem -LiteralPath $d.FullName -Recurse -Filter "*.ex5" -ErrorAction SilentlyContinue | ForEach-Object { "$($d.Name):$($_.FullName)" })
        }
        if ($foreign.Count -gt 0) { $ok = $false; $detail.Add("unexpected ex5 in foreign data folders: $($foreign -join '; ')") }
        else { $detail.Add("foreign data folders clean (no ex5)") }
        $testerEx5 = @(Get-ChildItem -LiteralPath (Join-Path $env:APPDATA "MetaQuotes\Tester") -Recurse -Filter "*.ex5" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
        if ($testerEx5.Count -gt 0) { $ok = $false; $detail.Add("ex5 found inside tester sandboxes: $($testerEx5 -join '; ')") }
        else { $detail.Add("tester sandbox clean (no ex5 copies)") }
        # exact-name match only (a wildcard filter would also count e.g. the
        # preserved TestRunnerEA.ex5.bak20260812_194614 evidence binary);
        # \Tools\ is the harness's own archive (run artifact binaries), not
        # a foreign/duplicate copy.
        $canon = @(Get-ChildItem -LiteralPath (Join-Path $DataFolderDir "MQL5\Experts") -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq "TestRunnerEA.ex5" -and $_.FullName -notmatch "\\Tools\\" } | Select-Object -ExpandProperty FullName)
        if ($canon.Count -ne 1 -or $canon[0] -ne $CanonicalTestRunner) { $ok = $false; $detail.Add("canonical TestRunnerEA.ex5 count=$($canon.Count) (expected exactly 1 at $CanonicalTestRunner)") }
        else { $detail.Add("canonical binary unique: $CanonicalTestRunner") }
    }
    $script:BuildIdentity.dataFolder.terminalVersion = (Get-Item -LiteralPath $Terminal -ErrorAction SilentlyContinue).VersionInfo.ProductVersion
    $script:BuildIdentity.dataFolder.metaeditorVersion = (Get-Item -LiteralPath $MetaEditor -ErrorAction SilentlyContinue).VersionInfo.ProductVersion
    $detail.Add("terminal=$($script:BuildIdentity.dataFolder.terminalVersion) metaeditor=$($script:BuildIdentity.dataFolder.metaeditorVersion)")
    New-Gate "PREFLIGHT" $ok @($detail.ToArray())
}

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

# Sprint 22 (RL-HYP-01): active-tier replay variant (k = 1.0). Same profile
# as the default replay; only the swing-significance gate tier differs.
# NOTE: a here-string excludes the newline before its closing '@, so the
# appended input needs its own leading newline to stay under [TesterInputs].
$script:ReplayK1Ini = $script:ReplayIni + "`r`nSwingSignificanceTier=1.0`r`n"

# Sprint 22 (RL-HYP-01) Design A: SETTLEMENT-ISOLATION scenario. Frozen batch
# profile for the DEFECT-FIRING window (EURUSD M15 2026-04-05..07-05, the
# 12-run batch window; ED01 INI parity - Model=4 real-tick replay). The
# isolation pair replays this window twice: tier 0.0 (CONTROL arm) and
# tier 1.0 (K1 arm). On the unfixed build the K1 arm's admitted rows defer
# settlement across GATE-OUT boundary bars and diverge from the control arm
# (the 58-row class); Design A makes them byte-identical.
$script:IsolationIni = @'
[Tester]
Expert=SuperCents_X\SuperCents_X.ex5
Symbol=EURUSD
Period=M15
Optimization=0
Model=4
FromDate=2026.04.05
ToDate=2026.07.05
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
EntryMode=2
WeightStructure=25.0
WeightOrderBlock=20.0
WeightFVG=15.0
WeightLiquidity=15.0
WeightTrend=15.0
WeightPremiumDiscount=10.0
'@
$script:IsolationK1Ini = $script:IsolationIni + "`r`nSwingSignificanceTier=1.0`r`n"

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
    $res = [pscustomobject]@{ Name = $Name; Pass = $Pass; Details = @($Details) }
    Add-TT01Result $res
}

function Add-TT01Result {
    param($res)
    $script:Results.Add($res)
    # incremental persistence: every verdict is appended as JSON so the run is
    # abort-resilient (the manifest at finalize is assembled from this too).
    try {
        $line = [ordered]@{ ts = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss"); name = $res.Name; pass = [bool]$res.Pass; details = @($res.Details) } | ConvertTo-Json -Compress
        Add-Content -LiteralPath (Join-Path $RunDir "gates.jsonl") -Value $line -Encoding UTF8
    } catch { }
    $icon = if ($res.Pass) { "PASS" } else { "FAIL" }
    $color = if ($res.Pass) { "Green" } else { "Red" }
    Write-Host ("  [{0,-22}] {1}  {2}" -f $res.Name, $icon, ($res.Details -join " | ")) -ForegroundColor $color
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
    # NOTE: the agent journal grows to multi-GB; ALWAYS read with -Tail (full reads
    # block for minutes).
    param()
    if (-not (Test-Path $AgentLog)) { return @() }
    $all = @(Get-Content -LiteralPath $AgentLog -Tail 4000 -ErrorAction SilentlyContinue)
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
        $ex5Path = $t.Path -replace "\.mq5$", ".ex5"
        #--- 25A-B: capture the pre-compile artifact state; a successful compile
        #    MUST refresh the binary (different hash, newer mtime).
        $pre = Get-TT01ArtifactState $ex5Path
        $t0 = Get-Date
        Start-Process -FilePath $MetaEditor -ArgumentList "/compile:`"$($t.Path)`" /log:`"$log`"" -Wait | Out-Null
        Start-Sleep -Seconds 2
        if ($t.Label -eq "TestRunnerEA") {
            $script:BuildIdentity.run.suiteCompileStartedAt = $t0.ToString("yyyy-MM-ddTHH:mm:ss")
            $script:BuildIdentity.run.suiteCompileEndedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        }
        if ($t.Label -eq "SuperCents_X") {
            #--- B25-01: production compile window (the CONTRACT gate checks
            #    the CSV buildTag against it; the __DATETIME__ tag is captured
            #    at parse time and must fall inside the harness-measured
            #    compile interval).
            $script:BuildIdentity.run.prodCompileStartedAt = $t0.ToString("yyyy-MM-ddTHH:mm:ss")
            $script:BuildIdentity.run.prodCompileEndedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        }
        $line = (Get-Content -LiteralPath $log -ErrorAction SilentlyContinue | Select-String "Result:" | Select-Object -Last 1).Line
        Write-Host ("    compile {0}: {1} ({2} s)" -f $t.Label, ($line -replace ".*Result: ", ""), [math]::Round(((Get-Date) - $t0).TotalSeconds)) -ForegroundColor DarkGray
        $post = Get-TT01ArtifactState $ex5Path
        # a refreshed artifact = a binary actually (re)written during THIS
        # compile window. MetaEditor rebuilds deterministically (identical
        # bytes for unchanged sources), so the hash may NOT change; the mtime
        # is the reliable signal (the compile log is written after the ex5, so
        # it cannot be the mtime reference).
        $hashChanged = ($null -eq $pre.hash) -or ($post.hash -ne $pre.hash)
        $refreshed = ($null -ne $post.mtime) -and ($post.mtime -ge $t0.AddSeconds(-5))
        $script:BuildIdentity.artifacts[$t.Label] = [ordered]@{
            sourceHash = (Get-TT01SourceClosureHash $t.Path)
            compileResult = $line
            refreshed = [bool]$refreshed
            hashChanged = [bool]$hashChanged
            pre = $pre
            post = $post
        }
        if ($line -match "(\d+) errors, (\d+) warnings") {
            $errs = [int]$Matches[1]; $warns = [int]$Matches[2]
            if ($errs -gt 0) { $fail++; New-Gate ("COMPILE-" + $t.Label) $false @($line) }
            elseif (-not $refreshed) {
                $fail++; New-Gate ("COMPILE-" + $t.Label) $false @($line,
                    "artifact NOT rewritten during this compile window (pre=$($pre.hash) post=$($post.hash)) - compiled binary may be stale")
            }
            else { New-Gate ("COMPILE-" + $t.Label) $true @($line, "artifact refreshed: $($post.hash.Substring(0,8))... $($post.size) bytes $($post.mtime.ToString('yyyy-MM-dd HH:mm:ss')) hashChanged=$hashChanged") }
        } else {
            $fail++; New-Gate ("COMPILE-" + $t.Label) $false @("no Result line in $log")
        }
    }
    $script:BuildIdentity.run.compileFinishedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
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
    $script:BuildIdentity.run.suiteRunAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    if (-not (Test-Path -LiteralPath $AgentLog)) {
        New-Gate "SUITE" $false @("agent log missing: $AgentLog")
        $script:BuildIdentity.run.suiteRunFinishedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        return
    }
    $all = @(Get-Content -LiteralPath $AgentLog -Tail 4000 -ErrorAction SilentlyContinue)
    $gtLines = @(for ($i = 0; $i -lt $all.Count; $i++) { if ($all[$i] -match "GRAND TOTAL") { $i } })
    if ($gtLines.Count -eq 0) {
        New-Gate "SUITE" $false @("no GRAND TOTAL block found in $AgentLog")
        $script:BuildIdentity.run.suiteRunFinishedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        return
    }
    $start = if ($gtLines.Count -gt 1) { $gtLines[-2] + 1 } else { 0 }
    $slice = @($all[$start..$gtLines[-1]])
    $block = @($slice | Where-Object { $_ -match ">>> |GRAND TOTAL" })
    #--- 25A-G8: pipeline output in PS 5.1 is PSObject-wrapped; ConvertTo-Json
    #    recursion-hangs on wrapped strings, so every journal line stored into
    #    BuildIdentity MUST be coerced to a native [string] at assignment.
    $grand = [string](@($slice | Where-Object { $_ -match "GRAND TOTAL" } | Select-Object -Last 1) | Select-Object -First 1)
    $startLine = [string](@($slice | Where-Object { $_ -match "testing of " } | Select-Object -Last 1) | Select-Object -First 1)
    #--- 25A-A: the journal tail is dominated by fixture INFO spam (the suite
    #    prints thousands of lines per second), so the BUILD line (printed at
    #    run start) and FAIL lines (printed mid-run) are captured with a full
    #    stream search instead of a line-count tail.
    $streamed = @(Select-String -LiteralPath $AgentLog -Pattern '>>> BUILD 25A-RUNTIME-01|FAIL \[' -ErrorAction SilentlyContinue | Select-Object -Last 500)
    $script:BuildIdentity.runtime.buildLine = [string](@($streamed | Where-Object { $_.Line -match ">>> BUILD " } | Select-Object -Last 1 | ForEach-Object { $_.Line }) | Select-Object -First 1)
    $script:BuildIdentity.runtime.failLines = @($streamed | Where-Object { $_.Line -match "FAIL \[" } | ForEach-Object { [string]$_.Line })
    $script:BuildIdentity.runtime.suiteStartedLine = $startLine
    $script:BuildIdentity.runtime.grandTotalLine = $grand
    $bl = $script:BuildIdentity.runtime.buildLine
    if (-not $bl) { $bl = "<none>" }
    Set-Content -LiteralPath (Join-Path $RunDir "runtime_identity.log") -Value @(
        ("buildLine  = " + $bl)
        ("failLines  = " + $script:BuildIdentity.runtime.failLines.Count)
        $script:BuildIdentity.runtime.failLines
    ) -Encoding UTF8

    $details = [System.Collections.Generic.List[string]]::new()
    if ($grand -match "GRAND TOTAL: (\d+)/(\d+) passed, (\d+) failed") {
        $passed = [int]$Matches[1]; $total = [int]$Matches[2]; $failed = [int]$Matches[3]
        $cats = @($block | Where-Object { $_ -match ">>> " -and $_ -notmatch ">>> BUILD " } | ForEach-Object { ($_ -replace "^.*>>> ", "").Trim() })
        $details.Add("$passed/$total passed, $failed failed")
        $details.Add("categories: $($cats.Count)")
        $details.Add(($cats -join " ; "))
    } else {
        $failed = -1; $total = -1; $passed = -1
        $details.Add("unparseable GRAND TOTAL: $grand")
    }

    #--- 25A-A: runtime identity verification (G1): the executed binary must
    #    self-report a build tag matching the compiled artifact of THIS run.
    $identityOk = $true
    $art = $script:BuildIdentity.artifacts["TestRunnerEA"]
    if (-not $art -or -not $art.post) {
        # compile phase skipped (e.g. -OnlyIsolation): reference = on-disk binary
        $art = [ordered]@{ post = (Get-TT01ArtifactState $CanonicalTestRunner); sourceHash = $null; compileResult = "n/a (compile skipped)"; refreshed = $false }
        $script:BuildIdentity.artifacts["TestRunnerEA"] = $art
        $details.Add("identity reference: on-disk binary (compile skipped)")
    }
    if (-not $script:BuildIdentity.runtime.buildLine) {
        $identityOk = $false
        $details.Add("RUNTIME IDENTITY FAIL: no '>>> BUILD' line in the suite block (binary self-report absent)")
    } else {
        $details.Add(("runtime: " + ($script:BuildIdentity.runtime.buildLine -replace "^.*>>> BUILD ", ">>> BUILD ")))
        if ($script:BuildIdentity.runtime.buildLine -match 'tag="([^"]+)"') {
            $tag = $Matches[1]
            $tagTime = [datetime]::MinValue
            [void][datetime]::TryParseExact($tag, "yyyy.MM.dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$tagTime)
            $w0 = $null; $w1 = $null
            if ($script:BuildIdentity.run.suiteCompileStartedAt) {
                # compile-window check: __DATETIME__ is captured at parse time,
                # the ex5 is written at compile end; both must fall inside the
                # harness-measured compile interval.
                $w0 = [datetime]::ParseExact($script:BuildIdentity.run.suiteCompileStartedAt, "yyyy-MM-ddTHH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture).AddSeconds(-15)
                $w1 = [datetime]::ParseExact($script:BuildIdentity.run.suiteCompileEndedAt, "yyyy-MM-ddTHH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture).AddSeconds(15)
            } elseif ($art.post.mtime) {
                # compile skipped (e.g. -OnlyIsolation): tolerate the on-disk artifact's compile window
                $w0 = $art.post.mtime.AddMinutes(-10)
                $w1 = $art.post.mtime.AddMinutes(1)
            }
            if ($tagTime -eq [datetime]::MinValue) {
                $identityOk = $false
                $details.Add("RUNTIME IDENTITY FAIL: unparseable build tag '$tag'")
            } elseif ($w0 -and ($tagTime -lt $w0 -or $tagTime -gt $w1)) {
                $identityOk = $false
                $details.Add("RUNTIME IDENTITY FAIL: build tag '$tag' outside the compile window [$($w0.ToString('yyyy.MM.dd HH:mm:ss')) .. $($w1.ToString('yyyy.MM.dd HH:mm:ss'))] - stale or foreign binary loaded")
            } else {
                $details.Add("identity OK: runtime tag '$tag' inside the compile window")
            }
        } else {
            $identityOk = $false
            $details.Add("RUNTIME IDENTITY FAIL: build line unparseable: $($script:BuildIdentity.runtime.buildLine)")
        }
        if ($script:BuildIdentity.runtime.buildLine -match "path=(.+)$") {
            $p = $Matches[1].Trim()
            if ($p -ne "SuperCents_X\Tests\TestRunnerEA.ex5" -and $p -notlike "*\SuperCents_X\Tests\TestRunnerEA.ex5") {
                $identityOk = $false
                $details.Add("RUNTIME IDENTITY FAIL: executed path '$p' != canonical 'SuperCents_X\Tests\TestRunnerEA.ex5'")
            } else {
                $details.Add("identity OK: executed path $p")
            }
        }
        $onDisk = Get-TT01ArtifactState $CanonicalTestRunner
        if ($art.post.hash -and $onDisk.hash -ne $art.post.hash) {
            $identityOk = $false
            $details.Add("RUNTIME IDENTITY FAIL: on-disk ex5 hash differs from the compiled artifact (file swapped mid-run?)")
        } else {
            $details.Add("identity OK: on-disk ex5 hash == compiled artifact ($($onDisk.hash.Substring(0,8))...)")
        }
    }

    #--- F: retain the journal slice + the executed binary in the artifact dir
    $sliceFile = Join-Path $runArt "suite_journal_slice.log"
    $slice | Set-Content -LiteralPath $sliceFile -Encoding UTF8
    $script:BuildIdentity.runtime.sliceFile = $sliceFile
    $script:BuildIdentity.runtime.sliceLines = $slice.Count
    $binDir = Join-Path $runArt "binaries"
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    if (Test-Path -LiteralPath $CanonicalTestRunner) {
        Copy-Item -LiteralPath $CanonicalTestRunner -Destination (Join-Path $binDir "TestRunnerEA.ex5") -Force
        $h = (Get-FileHash -LiteralPath (Join-Path $binDir "TestRunnerEA.ex5") -Algorithm SHA256).Hash
        Set-Content -LiteralPath (Join-Path $binDir "TestRunnerEA.ex5.sha256") -Value ("$h  TestRunnerEA.ex5") -Encoding ASCII
    }
    $script:BuildIdentity.runtime.binaryArchiveDir = $binDir
    $script:BuildIdentity.run.suiteRunFinishedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")

    New-Gate "SUITE" (($failed -eq 0) -and $identityOk) @($details.ToArray())
}

function Invoke-TT01Replay {
    if ($Skip -contains "replay") { New-Gate "REPLAY" $true @("skipped; CSV from previous run reused"); return }
    Write-Step "REPLAY: real EURUSD H1 telemetry run"
    #--- B25-02: start from a clean telemetry dir so the post-pass merge
    #    captures ONLY this run's rows (suite rows share the dated names).
    Clear-TT01Telemetry
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

    #--- B25-02: the agent synced the dated files back at session end;
    #    reassemble the full run into $OutCsv before the gates read it.
    if (-not (Merge-TT01Telemetry -TargetPath $OutCsv)) {
        New-Gate "REPLAY" $false @("no telemetry rows merged from $TelemetryDir")
        return
    }
    Write-Host ("    merged " + (Get-ChildItem -LiteralPath $TelemetryDir -Filter "telemetry_v6_*.csv").Count +
                " dated file(s) into $OutCsv") -ForegroundColor DarkGray

    if (-not (Test-Path $AgentLog)) { New-Gate "REPLAY" $false @("agent log missing"); return }
    $all = @(Get-Content -LiteralPath $AgentLog -Tail 2000 -ErrorAction SilentlyContinue)
    $rows = [int](-1); $faults = [int](-1)
    foreach ($line in $all) {
        if ($line -match "Rows Written\s+(\d+)") { $rows = [int]$Matches[1] }
        if ($line -match "I/O Faults\s+(\d+)") { $faults = [int]$Matches[1] }
    }
    $healthy = @($all | Where-Object { $_ -match "Overall Status\s+(\S+)" } | ForEach-Object { $Matches[1] } | Select-Object -Last 1)
    $crit = @($all | Where-Object { $_ -match "Critical\s+(\d+)" } | ForEach-Object { [int]$Matches[1] } | Select-Object -Last 1)
    $healthVerdict = (($healthy -join ",") -eq "HEALTHY") -and (([int]($crit -join ",")) -eq 0)

    #--- B25-01: capture the production EA's self-reported build line (the
    #    OnInit print; the tail above may not reach it, so stream-search the
    #    journal like the suite block does).
    $prodLines = @(Select-String -LiteralPath $AgentLog -Pattern '>>> BUILD 25B-PROD-01' -ErrorAction SilentlyContinue | Select-Object -Last 3)
    $script:BuildIdentity.runtime.prodBuildLine = [string](@($prodLines | Select-Object -Last 1 | ForEach-Object { $_.Line }) | Select-Object -First 1)

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
    $details = @("rows=$rows expected=$ExpectedRows faults=$faults health=$healthy critical=$crit csvCaptured=$ok")
    if ($script:BuildIdentity.runtime.prodBuildLine) {
        $details += ("prod build: " + ($script:BuildIdentity.runtime.prodBuildLine -replace "^.*>>> BUILD ", ">>> BUILD "))
    } else {
        $details += "prod build line NOT found in the journal (OnInit print absent or journal rotated)"
    }
    New-Gate "REPLAY" $pass @($details)
}

function Get-TT01ProdBuildWindow {
    #--- B25-01: the CSV buildTag must fall inside the production compile
    #    window (parse-time capture vs harness-measured compile interval).
    #    Compile skipped -> fall back to the on-disk binary's mtime window.
    #    Replay skipped -> $null (stale CSV from a previous run; the CONTRACT
    #    gate then checks format/constancy only).
    $w0 = $null; $w1 = $null
    if ($Skip -contains "replay") { return @($w0, $w1) }
    if ($script:BuildIdentity.run.prodCompileStartedAt) {
        $w0 = [datetime]::ParseExact($script:BuildIdentity.run.prodCompileStartedAt, "yyyy-MM-ddTHH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture).AddSeconds(-15)
        $w1 = [datetime]::ParseExact($script:BuildIdentity.run.prodCompileEndedAt, "yyyy-MM-ddTHH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture).AddSeconds(15)
    } else {
        $art = Get-TT01ArtifactState (Join-Path $SC "SuperCents_X.ex5")
        if ($art.mtime) { $w0 = $art.mtime.AddMinutes(-10); $w1 = $art.mtime.AddMinutes(1) }
    }
    @($w0, $w1)
}

function Invoke-TT01Contract {
    #--- B25-01: cross-check the CSV provenance against the harness facts
    #    (gitHead from the run_identity.txt the harness wrote; buildTag
    #    against the production compile window) and record the telemetry
    #    identity block into the manifest.
    $res = Test-TT01Contract -Path $OutCsv -ExpectedGitHead $gitHeadFull -ExpectedBuildTagWindow (Get-TT01ProdBuildWindow)
    $script:BuildIdentity.telemetry = [ordered]@{
        expectedGitHead = $gitHeadFull
        compileWindowChecked = -not ($Skip -contains "replay")
    }
    if (Test-Path -LiteralPath $OutCsv) {
        $row0 = Import-Csv -LiteralPath $OutCsv | Select-Object -First 1
        if ($row0) {
            $script:BuildIdentity.telemetry.runId = [string]$row0.runId
            $script:BuildIdentity.telemetry.buildTag = [string]$row0.buildTag
            $script:BuildIdentity.telemetry.gitHead = [string]$row0.gitHead
        }
    }
    $res | Add-Member -NotePropertyName Name -NotePropertyValue "TELEMETRY-CONTRACT" -Force
    Add-TT01Result $res
}

function Invoke-TT01Evidence {
    $res = Test-TT01Evidence -Path $OutCsv
    $res | Add-Member -NotePropertyName Name -NotePropertyValue "EVIDENCE-REGRESSION" -Force
    Add-TT01Result $res
}

function Invoke-TT01Behavior {
    $res = Test-TT01Behavior -RunPath $OutCsv -BasePath $BaseCsv -AllowDelta $AllowDelta -ExpectedRows $ExpectedRows -AllowDecisionIds $AllowDecisionIds
    Add-TT01Result $res
}

function Invoke-TT01ActiveTier {
    param([string]$BasePath)
    if ($Skip -contains "activetier") { New-Gate "ACTIVE-TIER" $true @("skipped"); return }
    Write-Step "ACTIVE-TIER: replay with SwingSignificanceTier=1.0 (RL-HYP-01 11.3c/3b evidence)"
    #--- B25-02: clean dir (drops the default run's dated files AND the
    #    stale 20260130 tail) so the post-pass merge captures only the
    #    tier-1.0 run's rows.
    Clear-TT01Telemetry
    Remove-Item -LiteralPath $OutCsv -Force -ErrorAction SilentlyContinue
    $ini = Join-Path $RunDir "TT01_K1_Replay.ini"
    $k1Content = ($script:ReplayK1Ini -replace "`r?`n", "`r`n")
    Set-Content -LiteralPath $ini -Value $k1Content -Encoding ASCII
    Start-TT01Headless $ini

    if (-not (Test-Path -LiteralPath $AgentLog)) { New-Gate "ACTIVE-TIER" $false @("agent log missing"); return }
    $all = @(Get-Content -LiteralPath $AgentLog -Tail 2000 -ErrorAction SilentlyContinue)
    $rows = [int](-1); $faults = [int](-1)
    foreach ($line in $all) {
        if ($line -match "Rows Written\s+(\d+)") { $rows = [int]$Matches[1] }
        if ($line -match "I/O Faults\s+(\d+)") { $faults = [int]$Matches[1] }
    }
    $healthy = @($all | Where-Object { $_ -match "Overall Status\s+(\S+)" } | ForEach-Object { $Matches[1] } | Select-Object -Last 1)
    $crit = @($all | Where-Object { $_ -match "Critical\s+(\d+)" } | ForEach-Object { [int]$Matches[1] } | Select-Object -Last 1)
    $healthVerdict = (($healthy -join ",") -eq "HEALTHY") -and (([int]($crit -join ",")) -eq 0)

    #--- B25-02: reassemble the tier-1.0 run into $OutCsv (see replay).
    if (-not (Merge-TT01Telemetry -TargetPath $OutCsv)) {
        New-Gate "ACTIVE-TIER" $false @("no telemetry rows merged from $TelemetryDir")
        return
    }
    Write-Host ("    merged " + (Get-ChildItem -LiteralPath $TelemetryDir -Filter "telemetry_v6_*.csv").Count +
                " dated file(s) into $OutCsv") -ForegroundColor DarkGray

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
    if (-not $ok -or $rows -lt 0 -or $faults -ne 0 -or -not $healthVerdict) {
        New-Gate "ACTIVE-TIER" $false @("replay unhealthy: rows=$rows faults=$faults health=$healthy critical=$crit csvCaptured=$ok")
        return
    }
    $k1Csv = Join-Path $runArt "telemetry_v6_k1.csv"
    Copy-Item -LiteralPath $OutCsv -Destination $k1Csv -Force
    $res = Test-TT01ActiveTier -RunPath $k1Csv -BasePath $BasePath
    $res.Details += "K1 replay health: rows=$rows faults=$faults health=$healthy critical=$crit"
    Add-TT01Result $res
}

function Clear-TT01Telemetry {
    #--- B25-01: clear fresh v6 files AND legacy v5 residue so the daily
    #    telemetry dir never accumulates stale files between runs.
    Get-ChildItem -LiteralPath $TelemetryDir -Filter "telemetry_v*.csv" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

function Merge-TT01Telemetry {
    #--- B25-02: checkpoint flushes split one run across the per-day dated
    #    files (BuildFilePath uses TimeCurrent() = simulated tester time),
    #    so the harness's single $OutCsv capture only saw the run's tail
    #    (2026-01-30: 64-row checkpoint + 52-row shutdown = 116 of 500).
    #    Reassemble the run by concatenating every v6 dated file in the
    #    clean telemetry dir (header once + all data rows, files sorted by
    #    name = chronological = the pre-checkpoint single-flush order).
    #    Callers MUST Clear-TT01Telemetry before the pass so the merge only
    #    sees THIS run's rows.  Returns $true when rows were merged.
    param([string]$TargetPath)
    $files = @(Get-ChildItem -LiteralPath $TelemetryDir -Filter "telemetry_v6_*.csv" -ErrorAction SilentlyContinue |
        Sort-Object Name)
    if ($files.Count -eq 0) { return $false }
    $rows = New-Object System.Collections.Generic.List[string]
    $header = $null
    foreach ($f in $files) {
        $lines = @(Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue)
        if ($lines.Count -eq 0) { continue }
        if ($header -eq $null) { $header = $lines[0] }
        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim().Length -gt 0) { $rows.Add($lines[$i]) }
        }
    }
    if ($header -eq $null) { return $false }
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add($header)
    foreach ($l in $rows) { $out.Add($l) }
    [System.IO.File]::WriteAllLines($TargetPath, $out.ToArray(), (New-Object System.Text.UTF8Encoding($false)))
    return $true
}

function Invoke-TT01ReplayArm {
    param([string]$Name, [string]$IniContent, [int]$TimeoutSec = 1500)
    #--- run one replay arm headlessly; returns health facts
    $ini = Join-Path $RunDir "TT01_${Name}.ini"
    Set-Content -LiteralPath $ini -Value ($IniContent -replace "`r?`n", "`r`n") -Encoding ASCII
    Stop-TT01Terminal
    $armStart = Get-Date
    Write-Host ("    arm {0} started {1:HH:mm:ss}" -f $Name, $armStart) -ForegroundColor DarkGray
    Start-Process -FilePath $Terminal -ArgumentList "/config:`"$ini`"" -WorkingDirectory $Root | Out-Null
    $deadline = $armStart.AddSeconds($TimeoutSec)
    do {
        Start-Sleep -Seconds 30
        $p = Get-Process terminal64 -ErrorAction SilentlyContinue
        if ($p) { Write-Host ("    arm {0} still running ({1:HH:mm:ss}, elapsed {2} min)" -f $Name, (Get-Date), [math]::Round(((Get-Date) - $armStart).TotalMinutes, 1)) -ForegroundColor DarkGray }
    }
    while ($p -and (Get-Date) -lt $deadline)
    if ($p) { throw "terminal did not exit within timeout for $Name" }
    Write-Host ("    arm {0} completed {1:HH:mm:ss} (elapsed {2} min)" -f $Name, (Get-Date), [math]::Round(((Get-Date) - $armStart).TotalMinutes, 1)) -ForegroundColor DarkGray

    $all = @(Get-Content -LiteralPath $AgentLog -Tail 2000 -ErrorAction SilentlyContinue)
    $rows = [int](-1); $faults = [int](-1)
    foreach ($line in $all) {
        if ($line -match "Rows Written\s+(\d+)") { $rows = [int]$Matches[1] }
        if ($line -match "I/O Faults\s+(\d+)") { $faults = [int]$Matches[1] }
    }
    $healthy = @($all | Where-Object { $_ -match "Overall Status\s+(\S+)" } | ForEach-Object { $Matches[1] } | Select-Object -Last 1)
    $crit = @($all | Where-Object { $_ -match "Critical\s+(\d+)" } | ForEach-Object { [int]$Matches[1] } | Select-Object -Last 1)
    [pscustomobject]@{ rows = $rows; faults = $faults; healthy = ($healthy -join ","); critical = ([int]($crit -join ",")) }
}

function Invoke-TT01Isolation {
    if ($Skip -contains "isolation") { New-Gate "SETTLEMENT-ISOLATION" $true @("skipped"); New-Gate "INTEGRITY-CONTROL" $true @("skipped"); return }
    Write-Step "SETTLEMENT-ISOLATION: tiered pair EURUSD M15 2026-04-05..07-05 (tier 0.0 vs 1.0; Design A RED->GREEN evidence)"
    Write-Host ("    phase started {0:HH:mm:ss} - each M15 arm takes ~9 min; progress is printed every 30 s" -f (Get-Date)) -ForegroundColor DarkGray

    $ctlDir = Join-Path $runArt "isolation_control"
    New-Item -ItemType Directory -Path $ctlDir -Force | Out-Null
    #--- a reusable control arm must (a) match the frozen segment names,
    #    (b) carry tier-0 OFF sentinels on every row, and (c) match the
    #    frozen row total. Anything else (suite telemetry, a K1-arm
    #    residue - segment names overlap across arms) is rejected.
    $expected = @(Get-ChildItem -LiteralPath $IsolationControlDir -Filter "telemetry_v*.csv" -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $preserved = @(Get-ChildItem -LiteralPath $TelemetryDir -Filter "telemetry_v*.csv" -ErrorAction SilentlyContinue |
        Where-Object { $expected -contains $_.Name })
    $reuseOk = ($OnlyIsolation -and $preserved.Count -gt 0)
    if ($reuseOk) {
        $preservedRows = @($preserved | ForEach-Object { Import-Csv -LiteralPath $_.FullName })
        $sentinelBad = @($preservedRows | Where-Object { $_.gateDecision -ne "OFF" }).Count
        if ($sentinelBad -gt 0 -or $preservedRows.Count -ne (Get-TT01ArmRows -Path $IsolationControlDir).Count) {
            $reuseOk = $false
            Write-Host ("    preserved CSVs rejected for reuse (sentinelBad=$sentinelBad rows=$($preservedRows.Count)) - regenerating the control arm") -ForegroundColor DarkGray
        }
    }
    if ($reuseOk) {
        #--- RED run: reuse the preserved control-arm CSVs (produced by the
        #    aborted full run at a known timestamp on the same build) instead
        #    of regenerating - the RED vs GREEN comparison then isolates the
        #    settlement defect without introducing a replay variable.
        $stamp = ($preserved | Sort-Object LastWriteTime | Select-Object -Last 1).LastWriteTime
        $preserved | Copy-Item -Destination $ctlDir -Force
        $ctlRows = @($preserved | ForEach-Object { Import-Csv -LiteralPath $_.FullName }).Count
        $ctlHealth = [pscustomobject]@{ rows = $ctlRows; faults = 0; healthy = "PRESERVED"; critical = 0 }
        Write-Host ("    control arm REUSED: $($preserved.Count) files ($($ctlRows) rows) from $stamp (same build, NOT regenerated)") -ForegroundColor DarkGray
    } else {
        Clear-TT01Telemetry
        $ctlHealth = Invoke-TT01ReplayArm -Name "IsolationControl" -IniContent $script:IsolationIni
        Write-Host ("    control arm health: rows=$($ctlHealth.rows) faults=$($ctlHealth.faults) health=$($ctlHealth.healthy) critical=$($ctlHealth.critical)") -ForegroundColor DarkGray
        Get-ChildItem -LiteralPath $TelemetryDir -Filter "telemetry_v*.csv" -ErrorAction SilentlyContinue |
            Copy-Item -Destination $ctlDir -Force
    }
    $ctlFiles = @(Get-ChildItem -LiteralPath $ctlDir -Filter "telemetry_v*.csv").Count

    Clear-TT01Telemetry
    $k1Health = Invoke-TT01ReplayArm -Name "IsolationK1" -IniContent $script:IsolationK1Ini
    Write-Host ("    k1 arm health: rows=$($k1Health.rows) faults=$($k1Health.faults) health=$($k1Health.healthy) critical=$($k1Health.critical)") -ForegroundColor DarkGray
    $k1Dir = Join-Path $runArt "isolation_k1"
    New-Item -ItemType Directory -Path $k1Dir -Force | Out-Null
    Get-ChildItem -LiteralPath $TelemetryDir -Filter "telemetry_v*.csv" -ErrorAction SilentlyContinue |
        Copy-Item -Destination $k1Dir -Force
    $k1Files = @(Get-ChildItem -LiteralPath $k1Dir -Filter "telemetry_v*.csv").Count

    if ($ctlFiles -eq 0 -or $k1Files -eq 0) {
        New-Gate "SETTLEMENT-ISOLATION" $false @("replay unhealthy: controlFiles=$ctlFiles k1Files=$k1Files",
            "control health: rows=$($ctlHealth.rows) faults=$($ctlHealth.faults) health=$($ctlHealth.healthy) critical=$($ctlHealth.critical)",
            "k1 health: rows=$($k1Health.rows) faults=$($k1Health.faults) health=$($k1Health.healthy) critical=$($k1Health.critical)")
    } else {
        $res = Test-TT01SettlementIsolation -RunPath $k1Dir -BasePath $ctlDir
        $res.Details += "control arm health: rows=$($ctlHealth.rows) faults=$($ctlHealth.faults) health=$($ctlHealth.healthy) critical=$($ctlHealth.critical) files=$ctlFiles"
        $res.Details += "k1 arm health: rows=$($k1Health.rows) faults=$($k1Health.faults) health=$($k1Health.healthy) critical=$($k1Health.critical) files=$k1Files"
        Add-TT01Result $res
        Write-Host ("    SETTLEMENT-ISOLATION: {0} ({1})" -f $(if ($res.Pass) { "PASS" } else { "RED" }), $($res.Details -join " | ")) -ForegroundColor $(if ($res.Pass) { "Green" } else { "Red" })

        $res2 = Test-TT01IntegrityControl -RunPath $ctlDir -BasePath $IsolationControlDir
        $res2.Details += "fresh control arm vs frozen CONTROL_RLHYP01_INTEGRITY (EURUSD_M15): determinism guard"
        Add-TT01Result $res2
        Write-Host ("    INTEGRITY-CONTROL: {0} ({1})" -f $(if ($res2.Pass) { "PASS" } else { "FAIL" }), $($res2.Details -join " | ")) -ForegroundColor $(if ($res2.Pass) { "Green" } else { "Red" })
    }
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
Remove-Item -LiteralPath (Join-Path $RunDir "gates.jsonl") -Force -ErrorAction SilentlyContinue
if (-not (Test-Path -LiteralPath $BaseCsv)) { Write-Error "frozen baseline CSV missing: $BaseCsv"; exit 2 }

$gitHead = git -C $ScriptDir rev-parse --short HEAD
$gitHeadFull = git -C $ScriptDir rev-parse HEAD
$gitDirtyLines = @(git -C $ScriptDir status --porcelain)
$script:BuildIdentity.sourceTree.gitHeadFull = $gitHeadFull
$script:BuildIdentity.sourceTree.gitHeadShort = $gitHead
$script:BuildIdentity.sourceTree.dirty = ($gitDirtyLines.Count -gt 0)
$script:BuildIdentity.sourceTree.dirtyLines = $gitDirtyLines.Count
$runId = "TT01_" + (Get-Date -Format "yyyyMMdd_HHmmss")
$script:BuildIdentity.run.runId = $runId
$runArt = Join-Path $ArtDir $runId
New-Item -ItemType Directory -Path $runArt -Force | Out-Null

#--- B25-01: publish the repo commit to the production EA.  The tester
#    stages FILE_COMMON in an ephemeral agent sandbox (synced back to the
#    real Common\Files ONLY at session end), so a runtime identity read
#    can never see a pre-seeded file during the run (root-caused on
#    2026-08-15).  The gitHead therefore travels into the binary at
#    COMPILE time: the harness rewrites Telemetry\TelemetryGitHead.mqh
#    here (before ANY target compiles) and restores the default
#    "unknown" state in finalize.  The identity file below remains as
#    the run's audit record (archived into the run artifact; the CONTRACT
#    gate cross-validates CSV gitHead == $gitHeadFull).
$TelemetryIdentityFile = Join-Path $TelemetryDir "run_identity.txt"
New-Item -ItemType Directory -Path $TelemetryDir -Force | Out-Null
Set-Content -LiteralPath $TelemetryIdentityFile -Value ("gitHead=" + $gitHeadFull) -Encoding ASCII
Write-Host ("identity file published: $TelemetryIdentityFile (gitHead=" + $gitHeadFull + ")") -ForegroundColor DarkGray
$script:GitHeadInclude = Join-Path $Root "Telemetry\TelemetryGitHead.mqh"
Set-Content -LiteralPath $script:GitHeadInclude -Value (
    "// generated by TT01 (B25-01): repo commit for the tranche binaries`r`n" +
    "#define TELEMETRY_GIT_HEAD `"$gitHeadFull`"`r`n") -Encoding ASCII
Write-Host ("gitHead include written: $($script:GitHeadInclude) ($gitHeadFull)") -ForegroundColor DarkGray

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

Invoke-TT01Preflight

if ($OnlyIsolation) {
    #--- RED/partial mode (Sprint 22 Design A): suite + settlement-isolation
    #    pair only. The control arm is reused from preserved telemetry CSVs
    #    (same build) so the pair comparison isolates the settlement defect.
    Invoke-TT01Suite
    Invoke-TT01Isolation
} else {
    Invoke-TT01Compile
    Invoke-TT01Suite
    Invoke-TT01Replay
    if (-not (Test-Path -LiteralPath $OutCsv)) {
        New-Gate "TELEMETRY-CONTRACT" $false @("no CSV to validate at $OutCsv")
        New-Gate "EVIDENCE-REGRESSION" $false @("no CSV to validate at $OutCsv")
        New-Gate "BEHAVIOR-REGRESSION" $false @("no CSV to validate at $OutCsv")
        New-Gate "ACTIVE-TIER" $false @("no CSV to validate at $OutCsv")
    } else {
        Invoke-TT01Contract
        Invoke-TT01Evidence
        Invoke-TT01Behavior
        $defaultCsv = Join-Path $runArt "telemetry_v6_default.csv"
        Copy-Item -LiteralPath $OutCsv -Destination $defaultCsv -Force
        Copy-Item -LiteralPath $OutCsv -Destination (Join-Path $runArt "telemetry_v4_20260130.csv") -Force
        Invoke-TT01ActiveTier -BasePath $defaultCsv
        Invoke-TT01Isolation
    }
}
if (-not $OnlyIsolation) { Invoke-TT01Perf }
Write-Step "FINALIZE: perf gate done (replayMs=$($script:Perf.replayMs))"

#--- B25-01: retire the identity file now that every tester phase is done;
#    archive the exact content into the run artifact for the audit trail.
if (Test-Path -LiteralPath $TelemetryIdentityFile) {
    Copy-Item -LiteralPath $TelemetryIdentityFile -Destination (Join-Path $runArt "run_identity.txt") -Force
    Remove-Item -LiteralPath $TelemetryIdentityFile -Force -ErrorAction SilentlyContinue
    Write-Host "identity file retired (archived to $runArt\run_identity.txt)" -ForegroundColor DarkGray
}

#--- B25-01: restore the compile-time gitHead include to its default
#    "unknown" state so the repo is clean for manual/ED01 builds (the
#    binaries themselves keep the embedded commit - correct provenance).
if ($script:GitHeadInclude -and (Test-Path -LiteralPath $script:GitHeadInclude)) {
    $c = @(Get-Content -LiteralPath $script:GitHeadInclude)
    for ($i = 0; $i -lt $c.Count; $i++) {
        if ($c[$i] -match '^\s*#define\s+TELEMETRY_GIT_HEAD') { $c[$i] = '#define TELEMETRY_GIT_HEAD "unknown"' }
    }
    Set-Content -LiteralPath $script:GitHeadInclude -Value $c -Encoding ASCII
    Write-Host "gitHead include restored to default" -ForegroundColor DarkGray
}

#--- 25A-F/G8: the authoritative manifest is persisted IMMEDIATELY once the
#    gate graph is complete (all gates recorded). gates.jsonl is durable at
#    decision time; the manifest must NOT be deferred behind operations it
#    does not depend on (evidence copies, baseline update, binary archive,
#    summary) - a termination in the finalize window would otherwise lose
#    the provenance record while gates.jsonl survives (Run 5,
#    TT01_20260814_235134: 17/17 gates recorded, manifest absent).
$allPass = ($script:Results | Where-Object { -not $_.Pass }).Count -eq 0
Write-Step ("FINALIZE: overall=" + $(if ($allPass) { "PASS" } else { "FAIL" }))
Write-TT01Manifest -RunArt $runArt -RunId $runId -GitHead $gitHead -AllPass $allPass -AllowDelta $AllowDelta -ExpectedRows $ExpectedRows -AllowDecisionIds $AllowDecisionIds

#--- 25A-F: archive the runtime identity evidence into the run artifact
foreach ($evFile in @("runtime_identity.log", "suite_journal_slice.log")) {
    $src = Join-Path $RunDir $evFile
    if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $runArt $evFile) -Force }
}

if ($allPass -and (Test-Path -LiteralPath $BaseMan) -and $script:Perf.replayMs -gt 0) {
    Update-TT01BaselinePerf
}

#--- archive the production replay binary alongside the suite binary (F)
Write-Step "FINALIZE: binaries archived"
$binDir = Join-Path $runArt "binaries"
if (Test-Path -LiteralPath $binDir) {
    $prodEx5 = Join-Path $SC "SuperCents_X.ex5"
    if (Test-Path -LiteralPath $prodEx5) {
        Copy-Item -LiteralPath $prodEx5 -Destination (Join-Path $binDir "SuperCents_X.ex5") -Force
        $ph = (Get-FileHash -LiteralPath (Join-Path $binDir "SuperCents_X.ex5") -Algorithm SHA256).Hash
        Set-Content -LiteralPath (Join-Path $binDir "SuperCents_X.ex5.sha256") -Value ("$ph  SuperCents_X.ex5") -Encoding ASCII
    }
}

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

#--- cleanup old artifacts (keep newest N; NEVER delete RED/FAIL runs - they
#    are the reproduction evidence for a validation failure; never delete the
#    newest dir even if the count policy would)
$keep = $ArtifactsKeep
$old = @(Get-ChildItem -LiteralPath $ArtDir -Directory | Sort-Object Name -Descending | Select-Object -Skip $keep)
$old = @($old | Where-Object {
    $m = Join-Path $_.FullName "manifest.json"
    if (-not (Test-Path -LiteralPath $m)) { return $true }
    $man = Get-Content -LiteralPath $m -Raw | ConvertFrom-Json
    return ($man.overall -ne "FAIL")
})
foreach ($d in $old) { Remove-Item -LiteralPath $d.FullName -Recurse -Force -ErrorAction SilentlyContinue }

Write-Step "FINALIZE: complete - manifest at $runArt\manifest.json"

if ($allPass) { exit 0 } else { exit 1 }

