#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ME       = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
$Terminal = "C:\Program Files\MetaTrader 5\terminal64.exe"
$TermData = "$env:APPDATA\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"
$Root     = (Get-Location).Path
$SrcEA    = Join-Path $Root "SuperCents_X.mq5"
$ArtifactDir = Join-Path $Root "Tests\smoke_artifacts"
$PresetFile = Join-Path $Root "Validation\Sprint17\manifest\SuperCents_X.set"

New-Item -ItemType Directory -Path $ArtifactDir -Force | Out-Null

# Verify no terminal already running
if (Get-Process terminal64 -ErrorAction SilentlyContinue) {
    Write-Host "REFUSING: terminal64 already running." -ForegroundColor Red; exit 1
}

# Phase 1: COMPILE
Write-Host "`n===== PHASE 1: COMPILE SuperCents_X =====" -ForegroundColor Cyan
$CompileLog = Join-Path $ArtifactDir "compile_smoke.log"
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

# Phase 2: VERIFY BINARY
Write-Host "`n===== PHASE 2: VERIFY BINARY =====" -ForegroundColor Cyan
$BuiltEx5 = Join-Path $Root "SuperCents_X.ex5"
if (-not (Test-Path -LiteralPath $BuiltEx5)) {
    Write-Host "BUILT EX5 NOT FOUND: $BuiltEx5" -ForegroundColor Red; exit 1
}
$stagedItem = Get-Item -LiteralPath $BuiltEx5
Write-Host ("binary: {0} bytes  {1}" -f $stagedItem.Length, $stagedItem.LastWriteTime)

# Verify preset has EntryMode=2
Write-Host "`nVerifying preset file: $PresetFile"
if (-not (Test-Path -LiteralPath $PresetFile)) {
    Write-Host "PRESET NOT FOUND" -ForegroundColor Red; exit 1
}
$presetContent = Get-Content -LiteralPath $PresetFile -Encoding Unicode -ErrorAction SilentlyContinue
$emLine = $presetContent | Where-Object { $_ -match "^EntryMode=" }
Write-Host "  $emLine"
if ($emLine -notmatch "^EntryMode=2") {
    Write-Host "PRESET EntryMode != 2" -ForegroundColor Red; exit 1
}
Write-Host "Preset confirmed: EntryMode=2 (ENTRY_MODE_NEW)" -ForegroundColor Green

# Phase 3: CLEAR OLD TELEMETRY (fresh start)
Write-Host "`n===== PHASE 3: CLEAR OLD TELEMETRY =====" -ForegroundColor Cyan
$TelDir = Join-Path $TermData "Common\Files\Telemetry"
if (Test-Path -LiteralPath $TelDir) {
    $oldFiles = @(Get-ChildItem -LiteralPath $TelDir -Filter "telemetry_v6_*.csv" -ErrorAction SilentlyContinue)
    Write-Host "Found $($oldFiles.Count) existing telemetry files - clearing"
    Remove-Item -LiteralPath "$TelDir\telemetry_v6_*.csv" -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "No Telemetry directory (clean start)"
}

# Phase 4: INSTALL .SET FILE AND LAUNCH TESTER
Write-Host "`n===== PHASE 4: LAUNCH TESTER (ENTRY_MODE_NEW, 3-month smoke) =====" -ForegroundColor Cyan
$TesterDir = Join-Path $TermData "MQL5\Profiles\Tester"
New-Item -ItemType Directory -Path $TesterDir -Force | Out-Null
$DestSet = Join-Path $TesterDir "SuperCents_X.set"
Copy-Item -LiteralPath $PresetFile -Destination $DestSet -Force
Write-Host "Installed .set to: $DestSet"

$iniLines = @(
    "[Tester]",
    "Expert=SuperCents_X\SuperCents_X.ex5",
    "Symbol=EURUSD",
    "Period=M15",
    "Optimization=0",
    "Model=4",
    "FromDate=2026.01.01",
    "ToDate=2026.04.01",
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
$RunDir = Join-Path $env:TEMP "smoke_new_mode"
New-Item -ItemType Directory -Path $RunDir -Force | Out-Null
$ini = Join-Path $RunDir "smoke.ini"
$iniLines | Set-Content -LiteralPath $ini -Encoding ASCII
Write-Host "ini: $ini"
Write-Host "Launching terminal64..."
Start-Process -FilePath $Terminal -ArgumentList ('/config:"{0}"' -f $ini) | Out-Null

# Phase 5: CONFIRM TESTER ENGAGEMENT
Write-Host "`n===== PHASE 5: CONFIRM TESTER ENGAGEMENT =====" -ForegroundColor Cyan
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

# Phase 6: WAIT FOR COMPLETION
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

# Phase 7: INSPECT TELEMETRY OUTPUT
Write-Host "`n===== PHASE 7: INSPECT TELEMETRY =====" -ForegroundColor Cyan
# FILE_COMMON resolves to Terminal\Common\Files, not per-terminal Common\Files
$TelDir = Join-Path (Split-Path $TermData -Parent) "Terminal\Common\Files\Telemetry"
if (-not (Test-Path -LiteralPath $TelDir)) {
    # Fallback: try per-terminal
    $TelDir = Join-Path $TermData "Common\Files\Telemetry"
}
if (-not (Test-Path -LiteralPath $TelDir)) {
    Write-Host "FAIL: Telemetry directory does not exist in either location" -ForegroundColor Red
    Write-Host "  Tried: Terminal\Common\Files\Telemetry" -ForegroundColor Red
    Write-Host "  Tried: $TermData\Common\Files\Telemetry" -ForegroundColor Red
    exit 10
}

$csvFiles = @(Get-ChildItem -LiteralPath $TelDir -Filter "telemetry_v6_*.csv" -ErrorAction SilentlyContinue)
if ($csvFiles.Count -eq 0) {
    Write-Host "FAIL: No telemetry_v6_*.csv files found" -ForegroundColor Red
    exit 11
}

Write-Host "SUCCESS: Found $($csvFiles.Count) telemetry file(s)" -ForegroundColor Green
foreach ($f in $csvFiles) {
    Write-Host "`n--- $($f.Name) ---"
    Write-Host "  Size: $($f.Length) bytes"
    Write-Host "  LastWrite: $($f.LastWriteTime)"

    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    $headerLine = $lines[0]
    $dataLines = @($lines | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne "" })
    Write-Host "  Total rows (excl header): $($dataLines.Count)"

    if ($dataLines.Count -gt 0) {
        # Parse CSV - find outcome column index from header
        $headers = $headerLine -split ","
        $outcomeIdx = -1
        $rMultIdx = -1
        $barsIdx = -1
        $exitIdx = -1
        $confIdx = -1
        $dirIdx = -1
        $entryPriceIdx = -1
        $exitPriceIdx = -1
        for ($h = 0; $h -lt $headers.Count; $h++) {
            switch ($headers[$h].Trim()) {
                "outcome"       { $outcomeIdx = $h }
                "rMultiple"     { $rMultIdx = $h }
                "barsHeld"      { $barsIdx = $h }
                "exitReason"    { $exitIdx = $h }
                "confidence"    { $confIdx = $h }
                "direction"     { $dirIdx = $h }
                "entryPrice"    { $entryPriceIdx = $h }
                "exitPrice"     { $exitPriceIdx = $h }
            }
        }
        Write-Host "  outcome col: $outcomeIdx | rMultiple: $rMultIdx | barsHeld: $barsIdx | exitReason: $exitIdx"

        $unknown = 0; $wins = 0; $losses = 0; $be = 0
        $rPopulated = 0; $barsPopulated = 0; $exitPopulated = 0
        $qualified = 0
        $sampleEntry = ""
        $sampleSettled = ""

        foreach ($line in $dataLines) {
            # Simple CSV parse (no quoted commas expected in numeric fields)
            $cols = $line -split ","
            if ($outcomeIdx -ge 0 -and $cols.Count -gt $outcomeIdx) {
                $oval = [int]$cols[$outcomeIdx]
                switch ($oval) {
                    0 { $unknown++ }
                    1 { $wins++ }
                    2 { $losses++ }
                    3 { $be++ }
                }
            }
            if ($rMultIdx -ge 0 -and $cols.Count -gt $rMultIdx) {
                $rv = [double]$cols[$rMultIdx]
                if ($rv -ne 0.0) { $rPopulated++ }
            }
            if ($barsIdx -ge 0 -and $cols.Count -gt $barsIdx) {
                $bv = [int]$cols[$barsIdx]
                if ($bv -gt 0) { $barsPopulated++ }
            }
            if ($exitIdx -ge 0 -and $cols.Count -gt $exitIdx) {
                $ev = [int]$cols[$exitIdx]
                if ($ev -gt 0) { $exitPopulated++ }
            }
            # Check confidence (newDecision qualified)
            if ($confIdx -ge 0 -and $cols.Count -gt $confIdx) {
                $cv = [double]$cols[$confIdx]
                if ($cv -ge 0.60) { $qualified++ }
            }
            # Capture a sample row
            if ($sampleSettled -eq "" -and $outcomeIdx -ge 0 -and $cols.Count -gt $outcomeIdx) {
                $oval = [int]$cols[$outcomeIdx]
                if ($oval -ne 0) { $sampleSettled = $line }
            }
            if ($sampleEntry -eq "") { $sampleEntry = $line }
        }

        Write-Host "`n  === OUTCOME BREAKDOWN ==="
        Write-Host "  UNKNOWN (unsettled):    $unknown"
        Write-Host "  WIN (outcome=1):        $wins"
        Write-Host "  LOSS (outcome=2):       $losses"
        Write-Host "  BREAKEVEN (outcome=3):  $be"
        $settled = $wins + $losses + $be
        Write-Host "  ---- TOTAL SETTLED:     $settled ----" -ForegroundColor $(if ($settled -ge 300) { "Green" } else { "Yellow" })

        Write-Host "`n  === POPULATED FIELDS ==="
        Write-Host "  rMultiple != 0:         $rPopulated"
        Write-Host "  barsHeld > 0:            $barsPopulated"
        Write-Host "  exitReason > 0:          $exitPopulated"
        Write-Host "  qualified (conf >= 0.6): $qualified"

        if ($sampleSettled -ne "") {
            Write-Host "`n  === SAMPLE SETTLED ROW ==="
            Write-Host "  $sampleSettled"
        }

        Write-Host "`n  === PROMOTIONGATE CONTRACT ==="
        if ($settled -ge 300) {
            Write-Host "  settledTrades >= 300:    PASS ($settled)" -ForegroundColor Green
        } else {
            Write-Host "  settledTrades >= 300:    FAIL ($settled)" -ForegroundColor Yellow
        }
        if ($qualified -ge 500) {
            Write-Host "  qualifiedSignals >= 500: PASS ($qualified)" -ForegroundColor Green
        } else {
            Write-Host "  qualifiedSignals >= 500: FAIL ($qualified)" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n===== SMOKE TEST COMPLETE =====" -ForegroundColor Cyan
exit 0
