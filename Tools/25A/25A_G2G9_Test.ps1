# 25A_G2G9_Test.ps1 - Sprint 25A-RUNTIME-01 gates G2 (stale-binary detection)
# and G9 (no-weakening: exp=99 got=0 must remain a genuine RED on the pre-fix
# binary). Run AFTER the implementation compile so the canonical ex5 is the
# fresh 25A build:
#   powershell -File Tools\25A\25A_G2G9_Test.ps1
# The script NEVER modifies the frozen .bak evidence and restores the canonical
# binary at the end (byte-verified). Exit 0 = G2+G9 PASS (detection worked and
# the genuine failure was preserved), 1 = any check failed.
$ErrorActionPreference = "Stop"

$Root       = (git rev-parse --show-toplevel) -replace "`n", ""
$SC         = if (Test-Path (Join-Path $Root "Experts\SuperCents_X")) { Join-Path $Root "Experts\SuperCents_X" } else { $Root }
$Terminal   = "C:\Program Files\MetaTrader 5\terminal64.exe"
$AgentLog   = Join-Path $env:APPDATA "MetaQuotes\Tester\D0E8209F77C8CF37AD8BF550E51FF075\Agent-127.0.0.1-3000\logs\$((Get-Date -Format 'yyyyMMdd')).log"
$Canonical = Join-Path $SC "Tests\TestRunnerEA.ex5"
$StaleBak  = Join-Path $SC "Tests\TestRunnerEA.ex5.bak20260812_194614"
$G2Dir     = Join-Path $SC "Tools\25A"
$BackupDir = Join-Path $G2Dir "g2_backup"
$ArtDir    = Join-Path $G2Dir "artifacts"

$SuiteIni = @'
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

function Get-State([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        $f = Get-Item -LiteralPath $Path
        [ordered]@{ hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash; size = $f.Length; mtime = $f.LastWriteTime }
    } else { [ordered]@{ hash = $null; size = 0; mtime = $null } }
}

function Format-BuildTime([datetime]$Time) { $Time.ToString("yyyy.MM.dd HH:mm:ss") }

if (-not (Test-Path -LiteralPath $Canonical)) { Write-Error "canonical ex5 missing: $Canonical (compile first)"; exit 1 }
if (-not (Test-Path -LiteralPath $StaleBak))  { Write-Error "stale pre-fix binary missing: $StaleBak"; exit 1 }

$expected = Get-State $Canonical
Write-Host "expected (fresh) binary: $($expected.hash.Substring(0,8))... $($expected.size) bytes @ $($expected.mtime.ToString('yyyy-MM-dd HH:mm:ss'))"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
New-Item -ItemType Directory -Path $ArtDir -Force | Out-Null
$runId = "25A_G2G9_" + (Get-Date -Format "yyyyMMdd_HHmmss")
$runArt = Join-Path $ArtDir $runId
New-Item -ItemType Directory -Path $runArt -Force | Out-Null

#--- preserve the fresh binary, install the stale pre-fix binary
Copy-Item -LiteralPath $Canonical -Destination (Join-Path $BackupDir "TestRunnerEA.ex5.current") -Force
Copy-Item -LiteralPath $StaleBak -Destination $Canonical -Force
$staleOnDisk = Get-State $Canonical
Write-Host "stale binary installed: $($staleOnDisk.hash.Substring(0,8))... $($staleOnDisk.size) bytes @ $($staleOnDisk.mtime.ToString('yyyy-MM-dd HH:mm:ss'))"

try {
    #--- run the suite headless against the stale binary
    $ini = Join-Path $G2Dir "g2_suite.ini"
    Set-Content -LiteralPath $ini -Value $SuiteIni -Encoding ASCII
    $p = Get-Process terminal64 -ErrorAction SilentlyContinue
    if ($p) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 5 }
    Start-Process -FilePath $Terminal -ArgumentList "/config:`"$ini`"" -WorkingDirectory $Root | Out-Null
    $deadline = (Get-Date).AddSeconds(240)
    do { Start-Sleep -Seconds 3; $p = Get-Process terminal64 -ErrorAction SilentlyContinue } while ($p -and (Get-Date) -lt $deadline)
    if ($p) { throw "terminal did not exit within timeout" }

    #--- extract the last suite block from the journal; the tail is dominated
    #    by fixture INFO spam, so FAIL/BUILD lines come from a full stream pass
    $all = @(Get-Content -LiteralPath $AgentLog -Tail 4000 -ErrorAction SilentlyContinue)
    $gtLines = @(for ($i = 0; $i -lt $all.Count; $i++) { if ($all[$i] -match "GRAND TOTAL") { $i } })
    if ($gtLines.Count -eq 0) { throw "no GRAND TOTAL block found in journal" }
    $start = if ($gtLines.Count -gt 1) { $gtLines[-2] + 1 } else { 0 }
    $slice = @($all[$start..$gtLines[-1]])
    $slice | Set-Content -LiteralPath (Join-Path $runArt "suite_journal_slice.log") -Encoding UTF8
    $streamed = @(Select-String -LiteralPath $AgentLog -Pattern '>>> BUILD 25A-RUNTIME-01|FAIL \[' -ErrorAction SilentlyContinue | Select-Object -Last 500)
    $buildLine = @($streamed | Where-Object { $_.Line -match ">>> BUILD " } | Select-Object -Last 1 | ForEach-Object { $_.Line }) | Select-Object -First 1
    $grand = $slice | Where-Object { $_ -match "GRAND TOTAL" } | Select-Object -Last 1
    $fails = @($streamed | Where-Object { $_.Line -match "FAIL \[" } | ForEach-Object { $_.Line })
    $epochFails = @($fails | Where-Object { $_ -match "exp=99 got=0" })

    Write-Host ""
    Write-Host "=== journal evidence ==="
    if ($buildLine) { Write-Host ($buildLine -replace "^.*>>> BUILD ", ">>> BUILD ") }
    if ($grand)     { Write-Host ($grand -replace "^.*GRAND TOTAL", "GRAND TOTAL") }
    foreach ($f in $fails) { Write-Host ($f -replace "^.*FAIL", "FAIL") }

    #--- assertions
    $checks = [ordered]@{}
    # G9: the genuine failure must remain RED (exp=99 got=0 on the pre-fix binary)
    $checks.G9_noWeakening = [ordered]@{
        pass = ($epochFails.Count -ge 2)
        detail = "exp=99 got=0 FAIL lines preserved: $($epochFails.Count) (expected >= 2: swing + low-swing)"
    }
    # G2a: runtime build tag must fall OUTSIDE the expected (fresh) binary's
    # compile window -> the executed binary self-reports as a foreign/stale build
    $tag = if ($buildLine -match 'tag="([^"]+)"') { $Matches[1] } else { $null }
    $tagTime = [datetime]::MinValue
    [void][datetime]::TryParseExact($tag, "yyyy.MM.dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$tagTime)
    $w0 = $expected.mtime.AddMinutes(-10)
    $w1 = $expected.mtime.AddMinutes(1)
    $inWindow = ($tagTime -ne [datetime]::MinValue -and $tagTime -ge $w0 -and $tagTime -le $w1)
    $checks.G2a_tagMismatch = [ordered]@{
        pass = (-not $inWindow)
        detail = "runtime tag '$tag' outside fresh-build window [$($w0.ToString('yyyy.MM.dd HH:mm:ss')) .. $($w1.ToString('yyyy.MM.dd HH:mm:ss'))] -> stale binary self-identified"
    }
    # G2b: on-disk artifact hash must differ from the expected binary hash
    $checks.G2b_artifactMismatch = [ordered]@{
        pass = ($staleOnDisk.hash -ne $expected.hash)
        detail = "on-disk $($staleOnDisk.hash.Substring(0,8))... != expected $($expected.hash.Substring(0,8))... -> swapped artifact detected"
    }
    # G2c: the suite itself must report failures (RED, not converted to PASS)
    $failed = if ($grand -match "GRAND TOTAL: (\d+)/(\d+) passed, (\d+) failed") { [int]$Matches[3] } else { -1 }
    $checks.G2c_suiteRed = [ordered]@{
        pass = ($failed -gt 0)
        detail = "suite failures: $failed (must be > 0)"
    }
    $allPass = @($checks.Keys | ForEach-Object { $checks[$_].pass }) -notcontains $false
    $checks | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $runArt "result.json") -Encoding UTF8

    Write-Host ""
    foreach ($k in $checks.Keys) {
        $c = $checks[$k]
        Write-Host ("  [{0}] {1}: {2}" -f $(if ($c.pass) { "PASS" } else { "FAIL" }), $k, $c.detail) -ForegroundColor $(if ($c.pass) { "Green" } else { "Red" })
    }
}
finally {
    #--- restore the correct (fresh) binary, byte-verified
    if (Test-Path -LiteralPath (Join-Path $BackupDir "TestRunnerEA.ex5.current")) {
        Copy-Item -LiteralPath (Join-Path $BackupDir "TestRunnerEA.ex5.current") -Destination $Canonical -Force
        $restored = Get-State $Canonical
        if ($restored.hash -eq $expected.hash) {
            Write-Host "restored canonical binary: hash matches expected ($($restored.hash.Substring(0,8))...)" -ForegroundColor Green
        } else {
            Write-Host "RESTORE MISMATCH: canonical hash $($restored.hash.Substring(0,8))... != expected $($expected.hash.Substring(0,8))..." -ForegroundColor Red
            $env:25A_G2G9_RESTORE_FAILED = "1"
        }
    }
}
if ($env:25A_G2G9_RESTORE_FAILED) { Write-Error "restore failed"; exit 1 }
if (-not $allPass) { Write-Error "G2/G9 checks FAILED - see $runArt"; exit 1 }
Write-Host "G2 + G9 PASS: stale binary detected, genuine RED preserved, canonical binary restored. Evidence: $runArt" -ForegroundColor Green
exit 0