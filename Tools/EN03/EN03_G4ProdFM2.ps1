# EN03_G4ProdFM2.ps1 - EN-03 Option B G4 hard gate: production-gate FM-2
# adversarial scenario, 2-arm batch (replay determinism).
# Authorized (docs/Sprint24_EN03_OptionB_Plan.md G4; user authorization
# 2026-08-13): production behavior must match the frozen COORDINATED FM-2
# trace incl. the W=23 same-tick suppression, and COORDINATED2 ==
# COORDINATED replay determinism. No commit, no closure doc.
#
# Runs EXACTLY two arms (EURUSD H1, 2026.01.01..2026.02.01 profile):
#   PROD1  EN03ArmLabel=prod1
#   PROD2  EN03ArmLabel=prod2  (replay determinism)
#
# The scenario EA (EN03_FM2ScenarioProd.ex5) drives the PRODUCTION gate
# (Portfolio/SymbolContext.mqh, Option B) with the frozen 33-bar FM-2
# table; the capture is Common\Files\Telemetry\en03_fm2prod_<label>.csv
# (one state row per window W=5..33).
#
# Gates:
#   G4A determinism : PROD2 CSV must equal PROD1 byte-identical
#   G4B trace match : PROD1 7 shared detector/trend columns per window
#                     must equal the frozen COORDINATED arm CSV
#                     (fm2_artifacts/COORDINATED/en03_fm2_coord.csv)
#   G4C suppression : the run journal must contain >= 1 "gate suppressed"
#                     log line (the coordSkip=1 same-tick case), and the
#                     CSV flipCount must stay 1 at W=23 (single BOS flip)
#
# Artifacts: Tools/EN03/g4_artifacts/PROD1/, PROD2/ + .done markers.
# Manifest:  Tools/EN03/EN03_G4_manifest.json.
#
# Usage: powershell -File EN03_G4ProdFM2.ps1  (-DryRun prints the plan)

param(
    [switch]$DryRun,
    [string]$ArtRoot = "g4_artifacts"
)

$ErrorActionPreference = "Stop"
$SC     = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # SuperCents_X dir
$Root   = Split-Path -Parent (Split-Path -Parent $SC)             # MQL5 dir
$DataFolder = Split-Path -Leaf (Split-Path -Parent $Root)
$Common = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\Telemetry"
$Terminal = "C:\Program Files\MetaTrader 5\terminal64.exe"
$MetaEditor = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
$TesterRoot = Join-Path $env:APPDATA "MetaQuotes\Tester\$DataFolder"
$Art     = Join-Path $PSScriptRoot $ArtRoot
$IniDir  = Join-Path $PSScriptRoot "ini"
$Log     = Join-Path $PSScriptRoot "run_EN03_G4.log"
$Manifest = Join-Path $PSScriptRoot "EN03_G4_manifest.json"
$Frozen  = Join-Path $PSScriptRoot "fm2_artifacts\COORDINATED\en03_fm2_coord.csv"

$Arms = @(
    @{ Name = "PROD1"; Label = "prod1" }
    @{ Name = "PROD2"; Label = "prod2" }
)

function Write-G4Log($msg) {
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
    $json = $m | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($Manifest, $json,
        (New-Object System.Text.UTF8Encoding($false)))
}

function New-EmptyManifest {
    $entries = @()
    foreach ($a in $Arms) {
        $entries += [pscustomobject]@{
            arm = $a.Name; label = $a.Label
            status = "PENDING"; start = $null; end = $null
            files = @(); csv = $null
        }
    }
    $m = [pscustomobject]@{
        protocol = "docs/Sprint24_EN03_OptionB_Plan.md G4 (production == frozen COORDINATED trace + replay determinism)"
        authorized = "2026-08-13 user authorization (Option B implementation, G4 hard gate)"
        overall = $null
        gates = @(
            @{ name = "G4A"; desc = "PROD2 CSV byte-identical to PROD1 (replay determinism)"; pass = $null }
            @{ name = "G4B"; desc = "PROD1 7 shared detector/trend columns == frozen COORDINATED per window"; pass = $null }
            @{ name = "G4C"; desc = "gate-suppressed journal line(s) present + flipCount==1 at W=23 (same-tick suppression)"; pass = $null }
        )
        frozen = "fm2_artifacts/COORDINATED/en03_fm2_coord.csv"
        arms = $entries
    }
    Save-Manifest $m
    return $m
}

function Get-Entry($m, $name) {
    foreach ($e in $m.arms) { if ($e.arm -eq $name) { return $e } }
    return $null
}

function Invoke-G4Attempt([string]$ini, [string]$dir, [string]$label) {
    if (Test-Path -LiteralPath $Common) {
        Get-ChildItem -LiteralPath $Common -Filter "en03_fm2prod_*.csv" -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
    Write-G4Log "RUN    $label start"
    $p = Get-Process terminal64 -ErrorAction SilentlyContinue
    if ($p) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 5 }
    Start-Process -FilePath $Terminal -ArgumentList "/config:`"$ini`"" -WorkingDirectory $Root | Out-Null
    $deadline = (Get-Date).AddMinutes(60)
    do { Start-Sleep -Seconds 5; $p = Get-Process terminal64 -ErrorAction SilentlyContinue }
    while ($p -and (Get-Date) -lt $deadline)
    Start-Sleep -Seconds 3
    if ($p) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 3 }

    $copied = @()
    if (Test-Path -LiteralPath $Common) {
        Get-ChildItem -LiteralPath $Common -Filter "en03_fm2prod_*.csv" -ErrorAction SilentlyContinue |
            ForEach-Object {
                Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dir $_.Name) -Force
                $copied += $_.Name
            }
    }
    return $copied
}

function Invoke-G4Run {
    param([hashtable]$Arm)
    $label = $Arm.Name
    $dir = Join-Path $Art $label
    $done = Join-Path $dir ".done"
    $m = Get-Manifest
    $entry = Get-Entry $m $label

    if (Test-Path -LiteralPath $done) {
        Write-G4Log "SKIP   $label (done)"
        $entry.status = "DONE"
        Save-Manifest $m
        return $true
    }
    $stale = @(Get-ChildItem -LiteralPath $dir -Filter "*.csv" -ErrorAction SilentlyContinue)
    if ($stale.Count -gt 0) {
        Write-G4Log "ABORT  ${label}: non-empty artifact dir without .done ($($stale.Count) csv) - refusing to mix captures"
        $entry.status = "FAILED"
        Save-Manifest $m
        return $false
    }

    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $ini = Join-Path $IniDir "EN03_G4_$($Arm.Name).ini"
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("[Tester]")
    [void]$sb.AppendLine("Expert=SuperCents_X\Tools\EN03\EN03_FM2ScenarioProd.ex5")
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
    [void]$sb.AppendLine("EN03ArmLabel=$($Arm.Label)")
    Set-Content -LiteralPath $ini -Value $sb.ToString() -Encoding ASCII

    if ($DryRun) { Write-G4Log "DRYRUN $label -> $ini (label=$($Arm.Label))"; return $true }

    $entry.status = "RUNNING"
    $entry.start = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    Save-Manifest $m
    Write-G4Log "CONFIG $label ini=$ini label=$($Arm.Label)"

    $attempts = 0
    $copied = @()
    do {
        $attempts++
        $copied = Invoke-G4Attempt $ini $dir $label
        if ($copied.Count -eq 0 -and $attempts -lt 2) {
            Write-G4Log "RETRY  $label (no capture, attempt $attempts/2)"
            Start-Sleep -Seconds 20
        }
    } while ($copied.Count -eq 0 -and $attempts -lt 2)

    $entry.end = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    if ($copied.Count -gt 0) {
        $entry.files = @($copied)
        $fm2 = @($copied | Where-Object { $_ -like "en03_fm2prod_*" })
        $entry.csv = if ($fm2.Count -gt 0) { $fm2[0] } else { $null }
        $entry.status = "DONE"
        Set-Content -LiteralPath $done -Value ((Get-Date -Format "yyyy-MM-ddTHH:mm:ss") + " label=$($Arm.Label) files=$($copied -join ',')") -Encoding ASCII
        Save-Manifest $m
        Write-G4Log "DONE   $label label=$($Arm.Label) files=$($copied -join ',')"
        return $true
    }
    $entry.status = "FAILED"
    Save-Manifest $m
    Write-G4Log "EMPTY  $label (no csv captured after $attempts attempt(s) - NOT marked done; BATCH STOPPED)"
    return $false
}

#--- compile the production scenario EA first
$src = Join-Path $SC "Tools\EN03\EN03_FM2ScenarioProd.mq5"
$clog = Join-Path $PSScriptRoot "compile_EN03_FM2ScenarioProd.log"
Remove-Item -LiteralPath $clog -ErrorAction SilentlyContinue
Write-G4Log "COMPILE $src"
if (-not $DryRun) {
    $cp = Start-Process -FilePath $MetaEditor -ArgumentList "/compile:`"$src`"","/log:`"$clog`"" -PassThru
    $cp.WaitForExit(300000) | Out-Null
    Start-Sleep -Seconds 2
    $res = Select-String -LiteralPath $clog -Pattern "Result:" -ErrorAction SilentlyContinue | Select-Object -Last 1
    if (-not $res -or $res.Line -notmatch "Result: 0 errors") {
        Write-G4Log "COMPILE FAILED: $($res.Line)"
        exit 1
    }
    Write-G4Log "COMPILE OK: $($res.Line)"
}

New-Item -ItemType Directory -Path $Art -Force | Out-Null
New-Item -ItemType Directory -Path $IniDir -Force | Out-Null

if (-not (Test-Path -LiteralPath $Manifest)) {
    $m = New-EmptyManifest
    Write-G4Log "=== EN-03 G4 manifest created (2 arms) ==="
} else {
    $m = Get-Manifest
    Write-G4Log "=== EN-03 G4 batch resume: manifest exists ==="
}
foreach ($a in $m.arms) {
    Write-G4Log "REGISTERED $($a.arm) label=$($a.label) status=$($a.status)"
}

Write-G4Log "=== EN-03 G4 2-arm batch start (production gate; no commit) ==="
foreach ($arm in $Arms) {
    if (-not (Invoke-G4Run $arm)) {
        Write-G4Log "=== EN-03 G4 BATCH STOPPED (failure in $($arm.Name)); manifest reflects FAILED; no further runs ==="
        exit 1
    }
}
Write-G4Log "=== EN-03 G4 2-arm batch complete ==="

#--- reload the manifest so the arm states saved by the batch are kept
$m = Get-Manifest

#--- G4A: determinism (PROD2 byte-identical to PROD1)
$csv1 = Join-Path $Art "PROD1\en03_fm2prod_prod1.csv"
$csv2 = Join-Path $Art "PROD2\en03_fm2prod_prod2.csv"
$g4a = $false
if ((Test-Path -LiteralPath $csv1) -and (Test-Path -LiteralPath $csv2)) {
    $b1 = [System.IO.File]::ReadAllBytes($csv1)
    $b2 = [System.IO.File]::ReadAllBytes($csv2)
    $g4a = ($b1.Length -eq $b2.Length) -and ([System.Linq.Enumerable]::SequenceEqual($b1, $b2))
}
Write-G4Log ("G4A determinism PROD2==PROD1: " + $(if ($g4a) { "PASS" } else { "FAIL" }))

#--- G4B: trace match vs frozen COORDINATED (7 shared columns per window)
$g4b = $false
$mismatchRows = @()
if ((Test-Path -LiteralPath $csv1) -and (Test-Path -LiteralPath $Frozen)) {
    function Read-CsvCols($path, $cols) {
        $rows = @{}
        Get-Content -LiteralPath $path | Select-Object -Skip 1 | ForEach-Object {
            $f = $_ -split ","
            $w = [int]$f[0]
            $vals = @()
            foreach ($c in $cols) { $vals += $f[$c] }
            $rows[$w] = $vals
        }
        return $rows
    }
    $prodCols = @{ window = 0; time = 1; trend = 2; bos = 3; choch = 4; pp = 5; ob = 6; fvg = 7; liq = 8; flips = 9 }
    $coordCols = @{ window = 0; time = 1; trend = 2; bos = 3; choch = 4; pp = 5; ob = 6; fvg = 7; liq = 8 }
    $prod = Read-CsvCols $csv1 @(0,2,3,4,5,6,7,8)
    $coord = Read-CsvCols $Frozen @(0,2,3,4,5,6,7,8)
    $g4b = $true
    foreach ($w in 5..33) {
        if (-not $prod.ContainsKey($w) -or -not $coord.ContainsKey($w)) { $g4b = $false; $mismatchRows += "W=$w missing"; continue }
        $p = $prod[$w]; $c = $coord[$w]
        if (($p -join ",") -ne ($c -join ",")) {
            $g4b = $false
            $mismatchRows += "W=$w prod=($($p -join ',')) coord=($($c -join ','))"
        }
    }
}
Write-G4Log ("G4B trace vs frozen COORDINATED: " + $(if ($g4b) { "PASS" } else { "FAIL" }))
foreach ($mr in $mismatchRows) { Write-G4Log "  MISMATCH $mr" }

#--- G4C: suppression journal evidence + flipCount==1 at W=23
$g4c = $false
$suppLines = 0
$flipAtW23 = $null
if (Test-Path -LiteralPath $csv1) {
    $flipAtW23 = (Get-Content -LiteralPath $csv1 | Select-Object -Skip 1 | ForEach-Object {
        $f = $_ -split ","; if ([int]$f[0] -eq 23) { $f[9] } }) | Select-Object -First 1
    $agentDirs = Get-ChildItem -LiteralPath $TesterRoot -Directory -Filter "Agent-127.0.0.1-*" -ErrorAction SilentlyContinue
    $jlog = $null
    foreach ($ad in $agentDirs) {
        $cand = Get-ChildItem -LiteralPath (Join-Path $ad.FullName "logs") -Filter "*.log" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($cand -and ($null -eq $jlog -or $cand.LastWriteTime -gt $jlog.LastWriteTime)) { $jlog = $cand }
    }
    if ($jlog) {
        $suppLines = @(Select-String -LiteralPath $jlog.FullName -Pattern "EN-03 Option B: gate suppressed" -ErrorAction SilentlyContinue).Count
    }
    $g4c = ($suppLines -ge 1) -and ($flipAtW23 -eq "1")
}
Write-G4Log ("G4C suppression: journal gate-suppressed lines=$suppLines flipCount@W23=$flipAtW23 -> " + $(if ($g4c) { "PASS" } else { "FAIL" }))

$m.gates | ForEach-Object {
    $res = switch ($_.name) {
        "G4A" { $g4a }; "G4B" { $g4b }; "G4C" { $g4c }
    }
    $_.pass = $res
}
$m.overall = $g4a -and $g4b -and $g4c
Save-Manifest $m
Write-G4Log ("=== EN-03 G4 overall: " + $(if ($m.overall) { "PASS" } else { "FAIL" }) + " ===")

if (-not $m.overall) { exit 1 }