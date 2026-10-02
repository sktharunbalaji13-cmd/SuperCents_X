#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ME       = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
$Terminal = "C:\Program Files\MetaTrader 5\terminal64.exe"
$TermData = "$env:APPDATA\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"
$Root     = (Get-Location).Path
$SrcEA    = Join-Path $Root "Tests\TestRunnerEA.mq5"
$ArtDir   = Join-Path $Root "Tests\rfa_artifacts"
$AgentLog = "$env:APPDATA\MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-127.0.0.1-3000\logs\$(Get-Date -Format 'yyyyMMdd').log"
$Journal  = Join-Path $TermData "logs\$(Get-Date -Format 'yyyyMMdd').log"

New-Item -ItemType Directory -Path $ArtDir -Force | Out-Null

if (Get-Process terminal64 -ErrorAction SilentlyContinue) {
    Write-Host "REFUSING: terminal64 already running." -ForegroundColor Red; exit 1
}

# Phase 0
$PinnedEx5 = Join-Path $TermData "MQL5\Experts\SuperCents_X\SuperCents_X.ex5"
if (Test-Path -LiteralPath $PinnedEx5) {
    $pinBefore = Get-Item -LiteralPath $PinnedEx5
    Write-Host ("pinned before : {0} bytes  {1}" -f $pinBefore.Length, $pinBefore.LastWriteTime)
} else {
    Write-Host "WARNING: pinned .ex5 not found" -ForegroundColor Yellow
    $pinBefore = $null
}

# Phase 1
Write-Host "`n===== PHASE 1: COMPILE =====" -ForegroundColor Cyan
$CompileLog = Join-Path $ArtDir "compile2.log"
Remove-Item -LiteralPath $CompileLog -ErrorAction SilentlyContinue
$meArgs = '/compile:"{0}" /log:"{1}"' -f $SrcEA, $CompileLog
Write-Host "Compiling: $SrcEA"
$proc = Start-Process -FilePath $ME -ArgumentList $meArgs -Wait -PassThru
Write-Host "MetaEditor exit code: $($proc.ExitCode) (ignored)"
$waited = 0
while (-not (Test-Path -LiteralPath $CompileLog) -and $waited -lt 30) {
    Start-Sleep -Seconds 2; $waited += 2
}
if (-not (Test-Path -LiteralPath $CompileLog)) {
    Write-Host "NO COMPILE LOG WRITTEN" -ForegroundColor Red; exit 1
}
$logTxt  = Get-Content -LiteralPath $CompileLog
$result   = $logTxt | Where-Object { $_ -match "Result:" } | Select-Object -Last 1
$errLines = @($logTxt | Where-Object { $_ -match ": error|: warning" })
Write-Host "compile result: $result"
if ($errLines.Count -gt 0) {
    Write-Host "Errors/warnings:" -ForegroundColor Yellow
    $errLines | Select-Object -First 30 | ForEach-Object { Write-Host "  $_" }
}
if ($result -notmatch "0 error") {
    Write-Host "COMPILE FAILED" -ForegroundColor Red; exit 1
}
Write-Host "COMPILE OK" -ForegroundColor Green

# Phase 2
Write-Host "`n===== PHASE 2: STAGE =====" -ForegroundColor Cyan
$Built  = Join-Path $Root "Tests\TestRunnerEA.ex5"
$Staged = Join-Path $TermData "MQL5\Experts\SuperCents_X\Tests\RFA_TestRunnerEA.ex5"
if (-not (Test-Path -LiteralPath $Built)) {
    Write-Host "BUILT EX5 NOT FOUND: $Built" -ForegroundColor Red; exit 1
}
Copy-Item -LiteralPath $Built -Destination $Staged -Force
$stagedItem = Get-Item -LiteralPath $Staged
Write-Host ("staged: {0} bytes  {1}" -f $stagedItem.Length, $stagedItem.LastWriteTime)

# Phase 3
Write-Host "`n===== PHASE 3: LAUNCH =====" -ForegroundColor Cyan
$iniLines = @(
    "[Tester]",
    "Expert=SuperCents_X\Tests\RFA_TestRunnerEA.ex5",
    "Symbol=EURUSD",
    "Period=H1",
    "Optimization=0",
    "Model=4",
    "FromDate=2026.01.01",
    "ToDate=2026.01.02",
    "ForwardMode=0",
    "Deposit=10000",
    "Currency=GBP",
    "ProfitInPips=0",
    "Leverage=200",
    "ExecutionMode=1000",
    "OptimizationCriterion=0",
    "Visual=0",
    "ReplaceReport=1",
    "ShutdownTerminal=1"
)
$RunDir = Join-Path $env:TEMP "rfa_probe"
New-Item -ItemType Directory -Path $RunDir -Force | Out-Null
$ini = Join-Path $RunDir "suite.ini"
$iniLines | Set-Content -LiteralPath $ini -Encoding ASCII
Write-Host "ini: $ini"
Write-Host "Launching terminal64..."
Start-Process -FilePath $Terminal -ArgumentList ('/config:"{0}"' -f $ini) | Out-Null

# Phase 4
Write-Host "`n===== PHASE 4: CONFIRM TESTER ENGAGEMENT =====" -ForegroundColor Cyan
$preJ = if (Test-Path -LiteralPath $Journal) { @(Get-Content -LiteralPath $Journal).Count } else { 0 }
$sawTester = $false
for ($i = 0; $i -lt 24; $i++) {
    Start-Sleep -Seconds 5
    if (Test-Path -LiteralPath $Journal) {
        $new = @(Get-Content -LiteralPath $Journal | Select-Object -Skip $preJ)
        $testerLines = @($new | Where-Object { $_ -match "`tTester`t" })
        if ($testerLines.Count -gt 0) {
            $testerLines | Select-Object -First 3 | ForEach-Object { Write-Host "  $_" }
            $sawTester = $true; break
        }
    }
    Write-Host "  waiting... ($($i+1)/24)"
}
if (-not $sawTester) {
    Write-Host "TESTER NEVER ENGAGED" -ForegroundColor Red
    $p = Get-Process terminal64 -ErrorAction SilentlyContinue
    if ($p) { Stop-Process -Id $p.Id -Force }
    exit 3
}
Write-Host "TESTER ENGAGED" -ForegroundColor Green

# Wait for completion
Write-Host "`nWaiting for terminal64 to exit..."
$deadline = (Get-Date).AddSeconds(600)
do { Start-Sleep -Seconds 10; $p = Get-Process terminal64 -ErrorAction SilentlyContinue }
while ($p -and (Get-Date) -lt $deadline)
if ($p) {
    Write-Host "TIMEOUT - killing terminal" -ForegroundColor Yellow
    Stop-Process -Id $p.Id -Force
    Start-Sleep -Seconds 3
}
Write-Host "Terminal exited" -ForegroundColor Green

# Phase 5
Write-Host "`n===== PHASE 5: REPORT =====" -ForegroundColor Cyan
if (-not (Test-Path -LiteralPath $AgentLog)) {
    Write-Host "NO AGENT LOG: $AgentLog" -ForegroundColor Red; exit 4
}
$allHits = Select-String -LiteralPath $AgentLog `
    -Pattern 'GRAND TOTAL|FAIL \[|RendererFreezeAnchors|LiquidityLifecycle|PortfolioConcurrency|>>> BUILD' |
    ForEach-Object { $_.Line }
$lastBuild = -1
for ($k = 0; $k -lt $allHits.Count; $k++) {
    if ($allHits[$k] -match '>>> BUILD') { $lastBuild = $k }
}
if ($lastBuild -lt 0) {
    Write-Host "NO RUNTIME IDENTITY LINE" -ForegroundColor Red; exit 5
}
$hits = @($allHits[$lastBuild..($allHits.Count - 1)])
$hits | Set-Content -LiteralPath (Join-Path $ArtDir "suite_hits.log") -Encoding UTF8

Write-Host "`n===== runtime identity ====="
$hits | Where-Object { $_ -match '>>> BUILD' } | Select-Object -First 1

Write-Host "`n===== RendererFreezeAnchors ====="
$rf = @($hits | Where-Object { $_ -match 'RendererFreezeAnchors' })
if ($rf.Count -eq 0) { Write-Host "  SUITE DID NOT RUN" -ForegroundColor Red } else { $rf }

Write-Host "`n===== LiquidityLifecycle ====="
$ll = @($hits | Where-Object { $_ -match 'LiquidityLifecycle' })
if ($ll.Count -eq 0) { Write-Host "  SUITE DID NOT RUN" -ForegroundColor Red } else { $ll }

Write-Host "`n===== PortfolioConcurrency ====="
$pc = @($hits | Where-Object { $_ -match 'PortfolioConcurrency' })
if ($pc.Count -eq 0) { Write-Host "  SUITE DID NOT RUN" -ForegroundColor Red } else { $pc }

Write-Host "`n===== FAIL lines ====="
$fails = @($hits | Where-Object { $_ -match 'FAIL \[' })
if ($fails.Count -eq 0) { Write-Host "  (none)" -ForegroundColor Green } else { $fails | Select-Object -First 40 }

Write-Host "`n===== GRAND TOTAL ====="
$hits | Where-Object { $_ -match 'GRAND TOTAL' } | Select-Object -Last 1

# Phase 6
Write-Host "`n===== PHASE 6: VERIFY PINNED BINARY =====" -ForegroundColor Cyan
if ($pinBefore) {
    $pinAfter = Get-Item -LiteralPath $PinnedEx5
    Write-Host ("pinned after  : {0} bytes  {1}" -f $pinAfter.Length, $pinAfter.LastWriteTime)
    if ($pinAfter.Length -eq $pinBefore.Length -and $pinAfter.LastWriteTime -eq $pinBefore.LastWriteTime) {
        Write-Host "PINNED BINARY UNCHANGED" -ForegroundColor Green
    } else {
        Write-Host "PINNED BINARY CHANGED - INVESTIGATE" -ForegroundColor Red
    }
} else {
    Write-Host "SKIPPED (no pinned .ex5 found at Phase 0)" -ForegroundColor Yellow
}

Write-Host "`n===== RUN COMPLETE =====" -ForegroundColor Cyan
exit 0
