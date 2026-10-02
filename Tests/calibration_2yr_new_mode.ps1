#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ME       = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
$Terminal = "C:\Program Files\MetaTrader 5\terminal64.exe"
$TermData = "$env:APPDATA\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"
$Root     = (Get-Location).Path
$SrcEA    = Join-Path $Root "SuperCents_X.mq5"
$ArtifactDir = Join-Path $Root "Tests\calibration_artifacts"
$PresetFile = Join-Path $Root "Validation\Sprint17\manifest\SuperCents_X.set"

New-Item -ItemType Directory -Path $ArtifactDir -Force | Out-Null

if (Get-Process terminal64 -ErrorAction SilentlyContinue) {
    Write-Host "REFUSING: terminal64 already running." -ForegroundColor Red; exit 1
}

Write-Host "`n===== 2-YEAR CALIBRATION RUN (ENTRY_MODE_NEW) =====" -ForegroundColor Cyan
Write-Host "Window: 2024.01.01 to 2026.01.01 (2 years EURUSD M15)"
Write-Host "Mode: ENTRY_MODE_NEW (shadow, no real execution)"
Write-Host ""

# Phase 1: COMPILE
Write-Host "===== PHASE 1: COMPILE =====" -ForegroundColor Cyan
$CompileLog = Join-Path $ArtifactDir "compile_cal.log"
Remove-Item -LiteralPath $CompileLog -ErrorAction SilentlyContinue
$meArgs = '/compile:"{0}" /log:"{1}"' -f $SrcEA, $CompileLog
$proc = Start-Process -FilePath $ME -ArgumentList $meArgs -Wait -PassThru
$waited = 0
while (-not (Test-Path -LiteralPath $CompileLog) -and $waited -lt 30) {
    Start-Sleep -Seconds 2; $waited += 2
}
$logTxt  = Get-Content -LiteralPath $CompileLog
$result   = $logTxt | Where-Object { $_ -match "Result:" } | Select-Object -Last 1
Write-Host "compile result: $result"
if ($result -notmatch "0 error") {
    Write-Host "COMPILE FAILED" -ForegroundColor Red; exit 1
}
Write-Host "COMPILE OK" -ForegroundColor Green

# Phase 2: VERIFY BINARY + PRESET
Write-Host "`n===== PHASE 2: VERIFY =====" -ForegroundColor Cyan
$BuiltEx5 = Join-Path $Root "SuperCents_X.ex5"
if (-not (Test-Path -LiteralPath $BuiltEx5)) {
    Write-Host "EX5 NOT FOUND" -ForegroundColor Red; exit 1
}
$stagedItem = Get-Item -LiteralPath $BuiltEx5
Write-Host ("binary: {0} bytes  {1}" -f $stagedItem.Length, $stagedItem.LastWriteTime)

if (-not (Test-Path -LiteralPath $PresetFile)) {
    Write-Host "PRESET NOT FOUND: $PresetFile" -ForegroundColor Red; exit 1
}
$presetContent = Get-Content -LiteralPath $PresetFile -Encoding Unicode -ErrorAction SilentlyContinue
$emLine = $presetContent | Where-Object { $_ -match "^EntryMode=" }
if ($emLine -notmatch "^EntryMode=2") {
    Write-Host "PRESET EntryMode != 2" -ForegroundColor Red; exit 1
}
Write-Host "Preset: EntryMode=2 (ENTRY_MODE_NEW)" -ForegroundColor Green

# Phase 3: INSTALL .SET FILE
Write-Host "`n===== PHASE 3: INSTALL .SET =====" -ForegroundColor Cyan
$TesterDir = Join-Path $TermData "MQL5\Profiles\Tester"
New-Item -ItemType Directory -Path $TesterDir -Force | Out-Null
$DestSet = Join-Path $TesterDir "SuperCents_X.set"
Copy-Item -LiteralPath $PresetFile -Destination $DestSet -Force
Write-Host "Installed: $DestSet"

# Phase 4: CLEAR OLD TELEMETRY
Write-Host "`n===== PHASE 4: CLEAR TELEMETRY =====" -ForegroundColor Cyan
$TelDir = Join-Path (Split-Path $TermData -Parent) "Terminal\Common\Files\Telemetry"
if (Test-Path -LiteralPath $TelDir) {
    $oldFiles = @(Get-ChildItem -LiteralPath $TelDir -Filter "telemetry_v6_*.csv" -ErrorAction SilentlyContinue)
    Write-Host "Found $($oldFiles.Count) existing telemetry files - clearing"
    Remove-Item -LiteralPath "$TelDir\telemetry_v6_*.csv" -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "No Telemetry directory (clean start)"
}

# Phase 5: LAUNCH TESTER (2-year window)
Write-Host "`n===== PHASE 5: LAUNCH 2-YEAR CALIBRATION =====" -ForegroundColor Cyan
$iniLines = @(
    "[Tester]",
    "Expert=SuperCents_X\SuperCents_X.ex5",
    "Symbol=EURUSD",
    "Period=M15",
    "Optimization=0",
    "Model=4",
    "FromDate=2024.01.01",
    "ToDate=2026.01.01",
    "ForwardMode=0",
    "Deposit=10000",
    "Currency=GBP",
    "Leverage=200",
    "ExecutionMode=1000",
    "OptimizationCriterion=0",
    "Visual=0",
    "ReplaceReport=1",
    "ShutdownTerminal=1",
    "ExpertParameters=SuperCents_X.set"
)
$RunDir = Join-Path $env:TEMP "calibration_2yr"
New-Item -ItemType Directory -Path $RunDir -Force | Out-Null
$ini = Join-Path $RunDir "cal_2yr.ini"
$iniLines | Set-Content -LiteralPath $ini -Encoding ASCII
Write-Host "ini: $ini"
Write-Host "Launching terminal64..."
$startTime = Get-Date
Start-Process -FilePath $Terminal -ArgumentList ('/config:"{0}"' -f $ini) | Out-Null

# Phase 6: CONFIRM TESTER ENGAGEMENT
Write-Host "`n===== PHASE 6: CONFIRM ENGAGEMENT =====" -ForegroundColor Cyan
$Journal = Join-Path $TermData "logs\$(Get-Date -Format 'yyyyMMdd').log"
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

# Phase 7: WAIT FOR COMPLETION (generous timeout for 2-year real-tick run)
Write-Host "`n===== PHASE 7: WAIT (timeout 2h) =====" -ForegroundColor Cyan
$deadline = (Get-Date).AddSeconds(7200)
do {
    Start-Sleep -Seconds 30
    $p = Get-Process terminal64 -ErrorAction SilentlyContinue
    if ($p) {
        $elapsed = (Get-Date) - $startTime
        Write-Host ("  elapsed: {0:hh\:mm\:ss}" -f $elapsed)
    }
} while ($p -and (Get-Date) -lt $deadline)
if ($p) {
    Write-Host "TIMEOUT - killing terminal" -ForegroundColor Yellow
    Stop-Process -Id $p.Id -Force
    Start-Sleep -Seconds 5
}
$elapsed = (Get-Date) - $startTime
Write-Host ("Terminal exited. Total time: {0:hh\:mm\:ss}" -f $elapsed) -ForegroundColor Green

# Phase 8: INSPECT TELEMETRY
Write-Host "`n===== PHASE 8: INSPECT TELEMETRY =====" -ForegroundColor Cyan

# Check both possible locations
$TelDir1 = Join-Path (Split-Path $TermData -Parent) "Terminal\Common\Files\Telemetry"
$TelDir2 = Join-Path $TermData "Common\Files\Telemetry"
$TelDir = $null
if (Test-Path -LiteralPath $TelDir1) { $TelDir = $TelDir1 }
elseif (Test-Path -LiteralPath $TelDir2) { $TelDir = $TelDir2 }
else {
    Write-Host "FAIL: No Telemetry directory found" -ForegroundColor Red
    exit 10
}
Write-Host "Telemetry dir: $TelDir"

$csvFiles = @(Get-ChildItem -LiteralPath $TelDir -Filter "telemetry_v6_*.csv" -ErrorAction SilentlyContinue)
if ($csvFiles.Count -eq 0) {
    Write-Host "FAIL: No telemetry CSV files" -ForegroundColor Red
    exit 11
}
Write-Host "Found $($csvFiles.Count) telemetry file(s)" -ForegroundColor Green

$totalRows = 0; $totalSettled = 0; $totalWins = 0; $totalLosses = 0; $totalBE = 0
$totalUnknown = 0; $totalQualified = 0; $totalRPop = 0; $totalBarsPop = 0; $totalExitPop = 0

foreach ($f in $csvFiles) {
    Write-Host "`n--- $($f.Name) ---"
    Write-Host "  Size: $($f.Length) bytes | LastWrite: $($f.LastWriteTime)"

    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    $headerLine = $lines[0]
    $headers = $headerLine -split ","
    $dataLines = @($lines | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne "" })
    $totalRows += $dataLines.Count

    # Find column indices
    $outcomeIdx = -1; $rMultIdx = -1; $barsIdx = -1; $exitIdx = -1; $confIdx = -1
    for ($h = 0; $h -lt $headers.Count; $h++) {
        switch ($headers[$h].Trim()) {
            "outcome"    { $outcomeIdx = $h }
            "rMultiple"  { $rMultIdx = $h }
            "barsHeld"   { $barsIdx = $h }
            "exitReason" { $exitIdx = $h }
            "confidence" { $confIdx = $h }
        }
    }

    $wins = 0; $losses = 0; $be = 0; $unknown = 0; $qualified = 0
    $rPop = 0; $barsPop = 0; $exitPop = 0

    foreach ($line in $dataLines) {
        $cols = $line -split ","
        if ($outcomeIdx -ge 0 -and $cols.Count -gt $outcomeIdx) {
            $oval = [int]$cols[$outcomeIdx]
            switch ($oval) { 0 { $unknown++ } 1 { $wins++ } 2 { $losses++ } 3 { $be++ } }
        }
        if ($rMultIdx -ge 0 -and $cols.Count -gt $rMultIdx) {
            if ([double]$cols[$rMultIdx] -ne 0.0) { $rPop++ }
        }
        if ($barsIdx -ge 0 -and $cols.Count -gt $barsIdx) {
            if ([int]$cols[$barsIdx] -gt 0) { $barsPop++ }
        }
        if ($exitIdx -ge 0 -and $cols.Count -gt $exitIdx) {
            if ([int]$cols[$exitIdx] -gt 0) { $exitPop++ }
        }
        if ($confIdx -ge 0 -and $cols.Count -gt $confIdx) {
            if ([double]$cols[$confIdx] -ge 0.6) { $qualified++ }
        }
    }

    $settled = $wins + $losses + $be
    Write-Host "  Rows: $($dataLines.Count) | Settled: $settled | Unknown: $unknown"
    Write-Host "  WIN=$wins LOSS=$losses BE=$be | Qualified(conf>=0.6)=$qualified"

    $totalSettled += $settled; $totalWins += $wins; $totalLosses += $losses
    $totalBE += $be; $totalUnknown += $unknown; $totalQualified += $qualified
    $totalRPop += $rPop; $totalBarsPop += $barsPop; $totalExitPop += $exitPop
}

Write-Host "`n===== CALIBRATION SUMMARY =====" -ForegroundColor Cyan
Write-Host "Total telemetry rows:    $totalRows"
Write-Host "Total settled (W/L/BE):  $totalSettled ($totalWins / $totalLosses / $totalBE)"
Write-Host "Total unknown:           $totalUnknown"
Write-Host "Total qualified (c>=.6): $totalQualified"
Write-Host "rMultiple populated:     $totalRPop"
Write-Host "barsHeld populated:      $totalBarsPop"
Write-Host "exitReason populated:    $totalExitPop"
Write-Host ""

# PromotionGate check
Write-Host "===== PROMOTIONGATE READINESS =====" -ForegroundColor Cyan
$pgPass = $true
$checks = @(
    @{ Name = "Shadow comparisons >= 10000"; Value = $totalRows; Target = 10000 },
    @{ Name = "Qualified signals >= 500";    Value = $totalQualified; Target = 500 },
    @{ Name = "Settled trades >= 300";       Value = $totalSettled; Target = 300 }
)
foreach ($c in $checks) {
    $ok = $c.Value -ge $c.Target
    $color = if ($ok) { "Green" } else { "Yellow" }
    $status = if ($ok) { "PASS" } else { "FAIL" }
    Write-Host ("  {0}: {1} / {2}  [{3}]" -f $c.Name, $c.Value, $c.Target, $status) -ForegroundColor $color
    if (-not $ok) { $pgPass = $false }
}

# Check agent log for errors
Write-Host "`n===== AGENT LOG CHECK =====" -ForegroundColor Cyan
$agentLog = "$env:APPDATA\MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-127.0.0.1-3000\logs\$(Get-Date -Format 'yyyyMMdd').log"
if (Test-Path -LiteralPath $agentLog) {
    $logContent = Get-Content -LiteralPath $agentLog
    $ioFaults = @($logContent | Where-Object { $_ -match "I/O Fault" })
    $errors = @($logContent | Where-Object { $_ -match "error|ERROR|crash" })
    $execAttempts = @($logContent | Where-Object { $_ -match "OrderSend|trade opened|position opened" })
    Write-Host "  I/O faults: $($ioFaults.Count)"
    Write-Host "  Error lines: $($errors.Count)"
    Write-Host "  Execution attempts: $($execAttempts.Count)"
    if ($ioFaults.Count -gt 0) { $ioFaults | Select-Object -First 5 | ForEach-Object { Write-Host "    $_" } }
    if ($errors.Count -gt 0) { $errors | Select-Object -First 5 | ForEach-Object { Write-Host "    $_" } }
    if ($execAttempts.Count -gt 0) { $execAttempts | Select-Object -First 5 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red } }

    # Get shadow mode summary
    $shadowLines = @($logContent | Where-Object { $_ -match "\[ShadowMode\]" })
    Write-Host "`n  Shadow mode summary:"
    $shadowLines | ForEach-Object { Write-Host "    $_" }
} else {
    Write-Host "  Agent log not found" -ForegroundColor Yellow
}

# Copy telemetry to artifacts for preservation
Write-Host "`n===== PRESERVE ARTIFACTS =====" -ForegroundColor Cyan
foreach ($f in $csvFiles) {
    $dest = Join-Path $ArtifactDir $f.Name
    Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    Write-Host "  Copied: $($f.Name) -> $ArtifactDir"
}

Write-Host "`n===== CALIBRATION COMPLETE =====" -ForegroundColor Cyan
Write-Host ("Total elapsed: {0:hh\:mm\:ss}" -f $elapsed)
exit 0
