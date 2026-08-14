# G8 finalization-mechanism targeted test (Sprint 25A)
# Proves the PRODUCTION Write-TT01Manifest function persists an authoritative
# manifest from a complete gate graph, using Run 5's REAL recorded evidence
# (TT01_20260814_235134). Does NOT touch run-5 evidence, baselines, or TT01.
$ErrorActionPreference = "Stop"
$Root = "C:\Users\k.tharun balaji\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\SuperCents_X"
. (Join-Path $Root "Tools\TT01\TT01_Validators.ps1")
$script:TT01_HEADER_V31 = @()

$RunId   = "TT01_20260814_235134"
$GitHead = "73e5886"
$RunArt  = Join-Path $Root "Tools\TT01\artifacts\$RunId"
$GatesJ  = Join-Path $Root "Tools\TT01\run\gates.jsonl"
$TestDir = Join-Path $Root "Tools\25A\g8_test"
if (Test-Path -LiteralPath $TestDir) { Remove-Item -LiteralPath $TestDir -Recurse -Force }
New-Item -ItemType Directory -Path $TestDir -Force | Out-Null

$fail = 0
function Check($label, [bool]$ok, [string]$detail) {
    Write-Host ("  [{0}] {1} - {2}" -f $(if ($ok) { "PASS" } else { "FAIL" }), $label, $detail) -ForegroundColor $(if ($ok) { "Green" } else { "Red" })
    if (-not $ok) { $script:fail++ }
}

Write-Host "=== G8 finalization test (run-5 real record) ==="
Write-Host ("source: gates.jsonl ({0} gates), runtime_identity.log, artifact dir" -f @(Get-Content -LiteralPath $GatesJ).Count)

$gatesHashBefore = (Get-FileHash -LiteralPath $GatesJ -Algorithm SHA256).Hash

$script:Results = @()
foreach ($ln in (Get-Content -LiteralPath $GatesJ)) {
    $g = $ln | ConvertFrom-Json
    $script:Results += [pscustomobject]@{ Name = $g.name; Pass = [bool]$g.pass; Details = @($g.details) }
}
Check "gate graph loaded" ($script:Results.Count -eq 17) "17 gates from gates.jsonl"

$perfGate = $script:Results | Where-Object { $_.Name -eq "PERFORMANCE" }
$perfTxt = $perfGate.Details -join " "
$script:Perf = @{ replayMs = 0; suiteMs = 0; peakMemMB = 0; csvBytes = 0 }
if ($perfTxt -match "replayMs=(\d+)") { $script:Perf.replayMs = [int]$Matches[1] }
if ($perfTxt -match "suiteMs=(\d+)") { $script:Perf.suiteMs = [int]$Matches[1] }
if ($perfTxt -match "peakMemMB=([\d.]+)") { $script:Perf.peakMemMB = [double]$Matches[1] }
if ($perfTxt -match "csvBytes=(\d+)") { $script:Perf.csvBytes = [int]$Matches[1] }

$binDir = Join-Path $RunArt "binaries"
$artifacts = [ordered]@{}
Get-ChildItem -LiteralPath $binDir -File -Filter "*.ex5" -ErrorAction SilentlyContinue | ForEach-Object {
    $artifacts[$_.BaseName] = [ordered]@{
        sourceHash = $null; compileResult = "recorded (run 5)"; refreshed = $true; hashChanged = $true
        pre  = [ordered]@{ hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash; size = $_.Length; mtime = $_.LastWriteTime }
        post = [ordered]@{ hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash; size = $_.Length; mtime = $_.LastWriteTime }
    }
}
$bl = (Get-Content -LiteralPath (Join-Path $RunArt "runtime_identity.log") -Raw).Trim()
$slice = Join-Path $RunArt "suite_journal_slice.log"
$sliceLines = if (Test-Path -LiteralPath $slice) { @(Get-Content -LiteralPath $slice).Count } else { 0 }
$grand = if (Test-Path -LiteralPath $slice) { [string](@(Get-Content -LiteralPath $slice | Where-Object { $_ -match "GRAND TOTAL" } | Select-Object -Last 1) | Select-Object -First 1) } else { $null }
$script:BuildIdentity = @{
    sourceTree = @{ gitHeadFull = $null; gitHeadShort = $GitHead; dirty = $true; dirtyLines = 16 }
    dataFolder = @{ id = "D0E8209F77C8CF37AD8BF550E51FF075"; dir = (Join-Path $env:APPDATA "MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"); originBinding = "C:\Program Files\MetaTrader 5"; installDir = "C:\Program Files\MetaTrader 5"; terminalVersion = "5.0.0.6104"; metaeditorVersion = "5.0.0.6104"; canonicalEx5 = Join-Path $Root "Tests\TestRunnerEA.ex5" }
    artifacts  = $artifacts
    runtime    = @{ buildLine = $bl; failLines = @(); suiteStartedLine = $null; grandTotalLine = $grand; sliceFile = $slice; sliceLines = $sliceLines; binaryArchiveDir = $binDir }
    run        = @{ runId = $RunId; compileFinishedAt = $null; suiteRunAt = $null; suiteRunFinishedAt = $null }
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()
Write-TT01Manifest -RunArt $TestDir -RunId $RunId -GitHead $GitHead -AllPass $true -ExpectedRows 500
$sw.Stop()
Check "manifest written" (Test-Path -LiteralPath (Join-Path $TestDir "manifest.json")) "manifest.json exists in $TestDir"
Write-Host ("  manifest persisted in {0} ms via production Write-TT01Manifest" -f $sw.ElapsedMilliseconds)

$m = Get-Content -LiteralPath (Join-Path $TestDir "manifest.json") -Raw | ConvertFrom-Json
Check "manifest parses" ($null -ne $m) "ConvertFrom-Json OK"
Check "overall=PASS" ($m.overall -eq "PASS") "overall=$($m.overall)"
Check "runId matches run 5" ($m.runId -eq $RunId) "runId=$($m.runId)"
Check "gitHead matches" ($m.gitHead -eq $GitHead) "gitHead=$($m.gitHead)"

$mGateNames = @($m.gates | ForEach-Object { $_.name })
$jGateNames = @(Get-Content -LiteralPath $GatesJ | ForEach-Object { ($_ | ConvertFrom-Json).name })
$sameNames = ($mGateNames.Count -eq $jGateNames.Count) -and (@(Compare-Object $mGateNames $jGateNames).Count -eq 0)
Check "gates match gates.jsonl names" $sameNames "$($m.gates.Count) gates, identical order/names"
$passMismatch = @($m.gates | Where-Object { -not $_.pass }).Count
Check "17/17 gates PASS in manifest" ($m.gates.Count -eq 17 -and $passMismatch -eq 0) "passes=$($m.gates.Count - $passMismatch)/17"

Check "buildLine tag present" ($m.buildIdentity.runtime.buildLine -match 'tag="2026\.08\.14 23:54:59"') "tag=2026.08.14 23:54:59"
Check "buildLine term present" ($m.buildIdentity.runtime.buildLine -match "term=6104") "term=6104"
Check "buildLine path present" ($m.buildIdentity.runtime.buildLine -match "Agent-127.0.0.1-3000\\MQL5\\Experts\\SuperCents_X\\Tests\\TestRunnerEA.ex5") "agent-sandbox path"
Check "origin binding present" ($m.buildIdentity.dataFolder.originBinding -eq "C:\Program Files\MetaTrader 5") "originBinding=$($m.buildIdentity.dataFolder.originBinding)"
Check "terminal version present" ($m.buildIdentity.dataFolder.terminalVersion -eq "5.0.0.6104") "terminalVersion=$($m.buildIdentity.dataFolder.terminalVersion)"
$trea = $m.buildIdentity.artifacts.TestRunnerEA
Check "TestRunnerEA hash present" ($trea.post.hash -match "^D1BB10F9") "post.hash=$($trea.post.hash.Substring(0,16))..."
Check "perf present" ($m.perf.replayMs -eq 18701) "replayMs=$($m.perf.replayMs)"

$gatesHashAfter = (Get-FileHash -LiteralPath $GatesJ -Algorithm SHA256).Hash
Check "run-5 gates.jsonl untouched" ($gatesHashAfter -eq $gatesHashBefore) "SHA256 unchanged"

$frozen = @(
    @{ n = "bak"; p = (Join-Path $Root "Tests\TestRunnerEA.ex5.bak20260812_194614"); h = "BB6392F49DE0C7EC3E83BF515FC730A1D4A4DA40076B73B7D207E8C59252370F" },
    @{ n = "baseCsv"; p = (Join-Path $Root "Tools\TT01\baseline\telemetry_v4_20260130.csv"); h = "B5AB5FEEAD758A814E903F00A0C62A8DF20AE87B7B63E630CF00408EFA0B2735" },
    @{ n = "baseMan"; p = (Join-Path $Root "Tools\TT01\baseline\baseline.manifest.json"); h = "82924B28339526B00B5F25161CB78A3B56B8D3909E4833E35B15EE99D726E3A9" },
    @{ n = "ctl"; p = (Join-Path $Root "Tools\ED01\artifacts\EURUSD_M15\CONTROL_RLHYP01_INTEGRITY\telemetry_v5_20260421.csv"); h = "2E3941EAD446C79197624977000ECCF08041B50C66918C59EB0B5B99745DB27B" }
)
foreach ($f in $frozen) {
    $h = (Get-FileHash -LiteralPath $f.p -Algorithm SHA256).Hash
    Check ("frozen " + $f.n + " untouched") ($h -eq $f.h) ($(if ($h -eq $f.h) { "hash identical" } else { "MISMATCH: $h" }))
}

Write-Host ""
if ($fail -eq 0) { Write-Host "G8 TARGETED TEST: ALL PASS" -ForegroundColor Green } else { Write-Host "G8 TARGETED TEST: $fail FAILURES" -ForegroundColor Red; exit 1 }
exit 0