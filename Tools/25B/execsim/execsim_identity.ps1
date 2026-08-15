# execsim_identity.ps1 - B25-03A Execution Identity validation harness
# Copyright 2026, SuperCents_X - Sprint 25B B25-03A (SENIOR-AUTHORIZED).
#
# Single command:
#   powershell -File execsim_identity.ps1 -Mode Red
#   powershell -File execsim_identity.ps1 -Mode Green -Run 1
#   powershell -File execsim_identity.ps1 -Mode Green -Run 2
#
# Phases:
#   Red   : builds TestRunnerEA with the TDD RED stub, runs the suite, and
#           REQUIRES the ExecutionIdentity category to FAIL (RED evidence).
#   Green : builds TestRunnerEA with the real implementation, runs the suite,
#           requires category + GRAND TOTAL green; -Run 2 additionally proves
#           determinism against -Run 1.
#
# Gates: PREFLIGHT | COMPILE | SUITE-EXECUTION-IDENTITY | GRAND-SUITE |
#        TDD-RED (Red) / DETERMINISM (Green run 2) | COMMENT-COMPAT-STATIC |
#        FROZEN-EVIDENCE | SCOPE-PROOF
#
# The harness compiles ONLY Tests\TestRunnerEA.mq5 (test binary; *.ex5 is
# gitignored). The production EA, telemetry, TT01, ED01 and settlement are
# never compiled, touched, or invoked. Exit code: 0 = all gates PASS.

[CmdletBinding()]
param(
    [ValidateSet("Red", "Green")]
    [string]$Mode = "Green",
    [ValidateRange(1, 2)]
    [int]$Run = 1
)

$ErrorActionPreference = "Stop"

$script:ExsimRoot   = (git rev-parse --show-toplevel) -replace "`n", ""
$script:ExsimSC     = $script:ExsimRoot
$script:ExsimDir    = Join-Path $script:ExsimRoot "Tools\25B\execsim"
$script:ExsimArtDir = Join-Path $script:ExsimDir "artifacts"
$RunId = "EXSIM_A_" + (Get-Date -Format "yyyyMMddHHmmss") + "_" + $Mode + $Run
$RunDir = Join-Path $script:ExsimArtDir $RunId

$MetaEditor = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
$Terminal   = "C:\Program Files\MetaTrader 5\terminal64.exe"
$TestRunner = Join-Path $script:ExsimSC "Tests\TestRunnerEA.mq5"
$TesterRoot = Join-Path $env:APPDATA "MetaQuotes\Tester"
$AgentDir   = Join-Path ((Get-ChildItem -LiteralPath $TesterRoot -Recurse -Directory -Filter "Agent-127.0.0.1-3000" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName) "logs"
$AgentLog   = Join-Path $AgentDir ((Get-Date -Format "yyyyMMdd") + ".log")

. (Join-Path $script:ExsimDir "execsim_validators.ps1")

New-Item -ItemType Directory -Path $RunDir -Force | Out-Null

$script:Results = [System.Collections.Generic.List[object]]::new()

function Write-Step($s) { Write-Host "[EXSIM] $s" -ForegroundColor DarkCyan }

function New-ExsimGate {
    param([string]$Name, [bool]$Pass, [string[]]$Details = @())
    $res = [pscustomobject]@{ Name = $Name; Pass = $Pass; Details = @($Details) }
    $script:Results.Add($res)
    try {
        $line = [ordered]@{ ts = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss"); mode = $Mode; run = $Run; name = $res.Name; pass = [bool]$res.Pass; details = @($res.Details) } | ConvertTo-Json -Compress
        Add-Content -LiteralPath (Join-Path $RunDir "gates.jsonl") -Value $line -Encoding UTF8
    } catch { }
    $icon = if ($res.Pass) { "PASS" } else { "FAIL" }
    $color = if ($res.Pass) { "Green" } else { "Red" }
    Write-Host ("  [{0,-28}] {1}  {2}" -f $res.Name, $icon, ($res.Details -join " | ")) -ForegroundColor $color
}

#--- frozen tester profile (byte-identical to the TT01 suite profile).
$ProfileIni = @'
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

$ProfilePath = Join-Path $script:ExsimDir "profiles\identity.ini"
New-Item -ItemType Directory -Path (Split-Path -Parent $ProfilePath) -Force | Out-Null
Set-Content -LiteralPath $ProfilePath -Value $ProfileIni -Encoding ASCII

#--------------------------------------------------------------------- preflight
$detail = [System.Collections.Generic.List[string]]::new()
$ok = $true
foreach ($p in @(@{ N = "MetaEditor"; P = $MetaEditor }, @{ N = "Terminal"; P = $Terminal })) {
    if (Test-Path -LiteralPath $p.P) { $detail.Add("$($p.N): $( (Get-Item -LiteralPath $p.P).VersionInfo.ProductVersion )") }
    else { $ok = $false; $detail.Add("$($p.N) MISSING: $($p.P)") }
}
if (-not $AgentDir -or -not (Test-Path -LiteralPath $AgentDir)) { $ok = $false; $detail.Add("tester agent log dir not found") }
else { $detail.Add("agent log: $AgentLog") }
$detail.Add("mode=$Mode run=$Run runId=$RunId")
New-ExsimGate "PREFLIGHT" $ok $detail.ToArray()

#--------------------------------------------------------------------- compile
$detail = [System.Collections.Generic.List[string]]::new()
$log = Join-Path $RunDir "compile.log"
$ex5 = $TestRunner -replace "\.mq5$", ".ex5"
$pre = Get-Item -LiteralPath $ex5 -ErrorAction SilentlyContinue
$preHash = if ($pre) { (Get-FileHash -LiteralPath $ex5 -Algorithm SHA256).Hash } else { $null }
Start-Process -FilePath $MetaEditor -ArgumentList "/compile:`"$TestRunner`" /log:`"$log`"" -Wait | Out-Null
Start-Sleep -Seconds 2
$line = (Get-Content -LiteralPath $log -ErrorAction SilentlyContinue | Select-String "Result:" | Select-Object -Last 1).Line
$post = Get-Item -LiteralPath $ex5 -ErrorAction SilentlyContinue
$compiled = $false
if ($line -match "(\d+) errors, (\d+) warnings") {
    $errs = [int]$Matches[1]; $warns = [int]$Matches[2]
    $compiled = ($errs -eq 0)
    $detail.Add("compile: $line")
    $detail.Add("binary: $($post.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) $($post.Length) bytes")
    if ($pre) { $detail.Add("hash(pre)=$($preHash.Substring(0,8))... hash(post)=$((Get-FileHash -LiteralPath $ex5 -Algorithm SHA256).Hash.Substring(0,8))...") }
    else { $detail.Add("no pre-existing binary (fresh build)") }
} else {
    $detail.Add("no Result line in compile log")
}
New-ExsimGate "COMPILE" $compiled $detail.ToArray()
if (-not $compiled) { Write-Host "compile failed - abort" -ForegroundColor Red; exit 1 }

#--------------------------------------------------------------------- run suite
$p = Get-Process terminal64 -ErrorAction SilentlyContinue
if ($p) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 5 }
$iniPath = Join-Path $RunDir "identity.ini"
Set-Content -LiteralPath $iniPath -Value $ProfileIni -Encoding ASCII
$t0 = Get-Date
Start-Process -FilePath $Terminal -ArgumentList "/config:`"$iniPath`"" -WorkingDirectory $script:ExsimRoot | Out-Null
$deadline = (Get-Date).AddSeconds(720)
do { Start-Sleep -Seconds 3; $p = Get-Process terminal64 -ErrorAction SilentlyContinue }
while ($p -and (Get-Date) -lt $deadline)
$elapsed = [math]::Round(((Get-Date) - $t0).TotalSeconds)
if ($p) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
$detail = [System.Collections.Generic.List[string]]::new()
$detail.Add("suite run took $elapsed s")
New-ExsimGate "SUITE-RUN" ($elapsed -lt 600) $detail.ToArray()

#--------------------------------------------------------------------- parse journal
$block = @(Get-ExsimJournalBlock $AgentLog)
$block | Set-Content -LiteralPath (Join-Path $RunDir "suite_journal_slice.log") -Encoding UTF8
$buildBanner = @($block | Where-Object { $_ -match ">>> BUILD " } | Select-Object -First 1)
$catLine = @($block | Where-Object { $_ -match ">>> ExecutionIdentity:" })
$grandLine = @($block | Where-Object { $_ -match "GRAND TOTAL" } | Select-Object -Last 1)

$catPass = $false; $catTotal = -1; $catFailed = -1
if ($catLine.Count -gt 0) {
    if ($catLine[-1] -match ">>> ExecutionIdentity: (\d+)/(\d+) passed, (\d+) failed") {
        $catPass = [int]$Matches[1]; $catTotal = [int]$Matches[2]; $catFailed = [int]$Matches[3]
    }
}
$grandPass = $false; $grandFailed = -1; $grandTotal = -1
if ($grandLine) {
    if ($grandLine -match "GRAND TOTAL: (\d+)/(\d+) passed, (\d+) failed") {
        $grandPass = ([int]$Matches[1] -eq [int]$Matches[2] -and [int]$Matches[3] -eq 0)
        $grandTotal = [int]$Matches[2]; $grandFailed = [int]$Matches[3]
    }
}
$script:RunBuildBanner = if ($buildBanner) { $buildBanner } else { "" }

#--------------------------------------------------------------------- gates
$detail = [System.Collections.Generic.List[string]]::new()
if ($catLine.Count -eq 0) { $detail.Add("category line NOT FOUND in journal slice") }
else { $detail.Add($catLine[-1]) }
if ($Mode -eq "Red") {
    # TDD RED: the stub MUST fail the category assertions, and the ONLY
    # failures in the whole suite must be ours (no collateral regression).
    $redObserved = ($catFailed -gt 0)
    New-ExsimGate "SUITE-EXECUTION-IDENTITY" $redObserved $detail.ToArray()
    $detail2 = [System.Collections.Generic.List[string]]::new()
    $detail2.Add("RED observed: $catPass/$catTotal passed, $catFailed failed (expected failed > 0 with the stub)")
    $detail2.Add(("journal: " + $AgentLog))
    New-ExsimGate "TDD-RED" $redObserved $detail2.ToArray()
    $collateralOnly = ($grandFailed -eq $catFailed)
    $d3 = [System.Collections.Generic.List[string]]::new()
    $d3.Add("$grandLine")
    if (-not $collateralOnly) { $d3.Add("failures outside the ExecutionIdentity category detected (collateral!)") }
    else { $d3.Add("no collateral failures: grandFailed($grandFailed) == categoryFailed($catFailed)") }
    New-ExsimGate "GRAND-SUITE" $collateralOnly $d3.ToArray()
} else {
    # GREEN: category must be fully green; the whole suite must stay green.
    $catGreen = ($catPass -eq $catTotal -and $catFailed -eq 0 -and $catTotal -gt 0)
    New-ExsimGate "SUITE-EXECUTION-IDENTITY" $catGreen $detail.ToArray()
    $detail2 = [System.Collections.Generic.List[string]]::new()
    $detail2.Add("$grandLine")
    New-ExsimGate "GRAND-SUITE" $grandPass $detail2.ToArray()
    if ($Run -eq 2) {
        $prev = Get-ChildItem -LiteralPath $script:ExsimArtDir -Directory -Filter "*_Green1" | Sort-Object Name | Select-Object -Last 1
        $det = $false; $d = [System.Collections.Generic.List[string]]::new()
        if (-not $prev) { $d.Add("previous Green run 1 artifact dir NOT FOUND") }
        else {
            # Journal lines carry a timestamp prefix that differs per run;
            # normalize each line to its content (from the ">>> " marker
            # or the "GRAND TOTAL" token) before comparing.
            $norm = {
                param($l)
                $m = [regex]::Match($l, ">>> |GRAND TOTAL")
                if ($m.Success) { $l.Substring($m.Index) } else { $l }
            }
            $slice1 = Get-Content -LiteralPath (Join-Path $prev.FullName "suite_journal_slice.log") -ErrorAction SilentlyContinue
            $slice2 = Get-Content -LiteralPath (Join-Path $RunDir "suite_journal_slice.log")
            $cat1 = @($slice1 | Where-Object { $_ -match ">>> ExecutionIdentity:" } | ForEach-Object { & $norm $_ })
            $cat2 = @($slice2 | Where-Object { $_ -match ">>> ExecutionIdentity:" } | ForEach-Object { & $norm $_ })
            $g1 = @($slice1 | Where-Object { $_ -match "GRAND TOTAL" } | Select-Object -Last 1 | ForEach-Object { & $norm $_ })
            $g2 = @($slice2 | Where-Object { $_ -match "GRAND TOTAL" } | Select-Object -Last 1 | ForEach-Object { & $norm $_ })
            $det = ($cat1.Count -gt 0 -and $cat1[-1] -eq $cat2[-1] -and $g1 -eq $g2)
            $d.Add("category run1: $($cat1[-1])")
            $d.Add("category run2: $($cat2[-1])")
            $d.Add("grand run1: $g1")
            $d.Add("grand run2: $g2")
            $failLines1 = @($slice1 | Where-Object { $_ -match "  FAIL \[" } | ForEach-Object { & $norm $_ })
            $failLines2 = @($slice2 | Where-Object { $_ -match "  FAIL \[" } | ForEach-Object { & $norm $_ })
            $sameFails = ($failLines1.Count -eq $failLines2.Count)
            if ($sameFails -and $failLines1.Count -gt 0) {
                for ($i = 0; $i -lt $failLines1.Count; $i++) { if ($failLines1[$i] -ne $failLines2[$i]) { $sameFails = $false; break } }
            }
            $det = $det -and $sameFails
            $d.Add("FAIL lines: run1=$($failLines1.Count) run2=$($failLines2.Count) (normalized match: $sameFails)")
        }
        New-ExsimGate "DETERMINISM" $det $d.ToArray()
    }
}

#--------------------------------------------------------------------- static + scope gates
$r = Test-ExsimCommentCompatStatic
New-ExsimGate "COMMENT-COMPAT-STATIC" $r.pass $r.details
$r = Test-ExsimFrozenEvidence
New-ExsimGate "FROZEN-EVIDENCE" $r.pass $r.details
$r = Test-ExsimScope
New-ExsimGate "SCOPE-PROOF" $r.pass $r.details

#--------------------------------------------------------------------- manifest
$allPass = @($script:Results | Where-Object { -not $_.Pass }).Count -eq 0
$manifest = [ordered]@{
    runId = $RunId
    mode = $Mode
    run = $Run
    gitHead = ((git -C $script:ExsimRoot rev-parse HEAD) -replace "`n","")
    buildBanner = $script:RunBuildBanner
    startedAt = $null
    finishedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
    gates = $script:Results
} | ConvertTo-Json -Depth 6
Set-Content -LiteralPath (Join-Path $RunDir "manifest.json") -Value $manifest -Encoding UTF8

Write-Host ""
Write-Host "[EXSIM] $Mode run ${Run}: " + $(if ($allPass) { "ALL GATES PASS" } else { "GATES FAILED" }) -ForegroundColor $(if ($allPass) { "Green" } else { "Red" })
Write-Host "[EXSIM] artifacts: $RunDir" -ForegroundColor DarkGray
exit $(if ($allPass) { 0 } else { 1 })
