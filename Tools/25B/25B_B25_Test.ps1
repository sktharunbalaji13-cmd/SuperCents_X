# 25B_B25_Test.ps1 - Sprint 25B (B25-01/B25-02) artifact-based targeted test
#   powershell -File Tools\25B\25B_B25_Test.ps1
# Run AFTER the post-implementation TT01 full run. Uses the NEWEST artifact
# dir under Tools\TT01\artifacts\TT01_* and asserts:
#   T1  isolation CONTROL CSV: 81-column v6 header, schemaVersion 6 on every row
#   T2  every row carries a valid runId (RUN-<buildTag>-<tick>), buildTag
#       (19-char timestamp) and gitHead (40-hex or "unknown") - no blanks
#   T3  runId is UNIQUE per arm file (each isolation arm = its own EA process)
#   T4  buildTag/gitHead are IDENTICAL across the 3 isolation arms (same binary,
#       same run_identity.txt)
#   T5  gitHead matches the run manifest AND the archived run_identity.txt
#   T6  buildTag falls inside the recorded production compile window
#       (the SuperCents_X binary's __DATETIME__, cross-checked like CONTRACT)
#   T7  suite journal slice shows GREEN with zero FAIL lines for the B25 tests
#   T8  frozen v5 INTEGRITY artifact + v4 baseline + baseline manifest unchanged
#   T9  run manifest carries buildIdentity.telemetry (runId/buildTag/gitHead)
# Does NOT modify any TT01/ED01 artifact or baseline. Evidence under
# Tools\25B\artifacts\<runId>. Exit 0 = all PASS, 1 = any FAIL.
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root      = (git -C $ScriptDir rev-parse --show-toplevel) -replace "`n", ""
$SC        = if (Test-Path (Join-Path $Root "Experts\SuperCents_X")) { Join-Path $Root "Experts\SuperCents_X" } else { $Root }
$ArtDir     = Join-Path $SC "Tools\TT01\artifacts"
$TestArtDir = Join-Path $SC "Tools\25B\artifacts"

$runId = "25B_B25_Test_" + (Get-Date -Format "yyyyMMdd_HHmmss")
$runArt = Join-Path $TestArtDir $runId
New-Item -ItemType Directory -Path $runArt -Force | Out-Null

$fail = 0
function Check($label, [bool]$ok, [string]$detail) {
    Write-Host ("  [{0}] {1} - {2}" -f $(if ($ok) { "PASS" } else { "FAIL" }), $label, $detail) -ForegroundColor $(if ($ok) { "Green" } else { "Red" })
    if (-not $ok) { $script:fail++ }
}

$runDir = Get-ChildItem -LiteralPath $ArtDir -Directory -Filter "TT01_*" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1
if ($null -eq $runDir) { Write-Error "no TT01 artifact dir found under $ArtDir (run the full TT01 first)"; exit 1 }
Write-Host "=== B25 artifact test on $($runDir.Name) ==="

#--- arm CSVs: CONTROL (tier 0.0), K1 (tier 1.0), preserved (B25-01: the
#    harness copies fresh v6 files; arm names follow the isolation layout)
$armFiles = @(Get-ChildItem -LiteralPath $runDir.FullName -Recurse -File -Filter "telemetry_v6_*.csv" -ErrorAction SilentlyContinue |
    Sort-Object FullName)
Write-Host ("  isolation arm v6 CSVs found: " + $armFiles.Count)
if ($armFiles.Count -lt 3) {
    Check "T3 arm runIds" $false "expected >= 3 v6 arm CSVs (control/preserved/k1), got $($armFiles.Count)"
}

$runIds = @(); $buildTags = @(); $gitHeads = @()
$anyV6Csv = $false
foreach ($f in $armFiles) {
    $lines = @(Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue)
    if ($lines.Count -lt 2) { continue }
    $hdr = $lines[0].Split(",")
    #--- CSV-aware parse (quoted fields contain commas - naive -split would
    #    shift the provenance columns and fail valid files).
    $rows = @(Import-Csv -LiteralPath $f.FullName -ErrorAction SilentlyContinue)
    if ($rows.Count -eq 0) { continue }
    $anyV6Csv = $true
    $badSchema = @($rows | Where-Object { [string]$_.schemaVersion -ne "6" }).Count
    $badRun = @($rows | Where-Object { [string]$_.runId -notmatch '^RUN-\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}-\d+$' }).Count
    $badBuild = @($rows | Where-Object { [string]$_.buildTag -notmatch '^\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}$' }).Count
    $badGit = @($rows | Where-Object { $g = [string]$_.gitHead; $g -ne "unknown" -and $g -notmatch '^[0-9a-f]{40}$' }).Count
    Check "T1/T2 schema+identity ($($f.Name))" ($hdr.Count -eq 81 -and $hdr[80] -eq "gitHead" -and $badSchema -eq 0 -and $badRun -eq 0 -and $badBuild -eq 0 -and $badGit -eq 0) `
        ("cols=$($hdr.Count) rows=$($rows.Count) badSchema=$badSchema badRun=$badRun badBuild=$badBuild badGit=$badGit")
    $runIds += [string]$rows[0].runId
    $buildTags += [string]$rows[0].buildTag
    $gitHeads += [string]$rows[0].gitHead
    Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $runArt ("arm_" + $f.Name)) -Force
}
#--- T3: each isolation arm / replay phase runs in its OWN EA process, so the
#    dated files of one arm share the arm's runId; DIFFERENT arms must differ
#    (default replay, tier-1.0 k1 replay, isolation control, isolation k1).
Check "T3 arm runIds" (($runIds | Select-Object -Unique).Count -ge 3) "distinct runIds: $(($runIds | Select-Object -Unique).Count) of $($runIds.Count) files (expect >= 3 arms)"
Check "T4 buildTag/gitHead constant" (($buildTags | Select-Object -Unique).Count -eq 1 -and ($gitHeads | Select-Object -Unique).Count -eq 1) "buildTags: $(($buildTags | Select-Object -Unique).Count) gitHeads: $(($gitHeads | Select-Object -Unique).Count)"

#--- manifest + archived run_identity.txt
$manifest = Get-Content -LiteralPath (Join-Path $runDir.FullName "manifest.json") -Raw | ConvertFrom-Json
$identTxt = Join-Path $runDir.FullName "run_identity.txt"
$gitFromFile = $null
if (Test-Path -LiteralPath $identTxt) {
    $gitFromFile = (Get-Content -LiteralPath $identTxt -Raw).Trim() -replace "gitHead=", ""
}
$gitFromCsv = @($gitHeads | Select-Object -First 1)
#--- the manifest's top-level gitHead is SHORT; the CSV carries the FULL 40-hex
#    (sourceTree.gitHeadFull / telemetry.gitHead hold the full form).
$gitFromMan = [string]$manifest.buildIdentity.sourceTree.gitHeadFull
if (-not $gitFromMan) { $gitFromMan = [string]$manifest.buildIdentity.telemetry.gitHead }
Check "T5 gitHead = manifest + archived file" ($gitFromCsv -eq $gitFromMan -and ($null -eq $gitFromFile -or $gitFromFile -eq $gitFromMan)) "csv=$gitFromCsv manifest=$gitFromMan file=$gitFromFile"

#--- T6: the isolation arms run the SuperCents_X binary, so their buildTag
#    must fall inside the production compile window recorded in the manifest
#    (the same window the TT01 CONTRACT gate cross-checks, +-15 s tolerance).
$pc0 = [string]$manifest.buildIdentity.run.prodCompileStartedAt
$pc1 = [string]$manifest.buildIdentity.run.prodCompileEndedAt
$csvTag = [datetime]::MinValue
[void][datetime]::TryParseExact($buildTags[0], "yyyy.MM.dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$csvTag)
$win0 = [datetime]::MinValue; $win1 = [datetime]::MinValue
[void][datetime]::TryParseExact($pc0, "yyyy-MM-ddTHH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$win0)
[void][datetime]::TryParseExact($pc1, "yyyy-MM-ddTHH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$win1)
$inWin = ($csvTag -ne [datetime]::MinValue -and $win0 -ne [datetime]::MinValue -and $win1 -ne [datetime]::MinValue -and $csvTag -ge $win0.AddSeconds(-15) -and $csvTag -le $win1.AddSeconds(15))
Check "T6 buildTag in prod compile window" $inWin "csv=$($buildTags[0]) window=[$pc0 .. $pc1]"

#--- suite journal slice: GREEN + no B25 test failures
$slice = Join-Path $runDir.FullName "suite_journal_slice.log"
if (Test-Path -LiteralPath $slice) {
    $grand = [string](@(Get-Content -LiteralPath $slice | Where-Object { $_ -match "GRAND TOTAL" } | Select-Object -Last 1) | Select-Object -First 1)
    $b25Fails = @(Select-String -LiteralPath $slice -Pattern "FAIL \[.*(IdentityStamp|CheckpointFlush|V6Identity|V6ColumnCount|V6IdentityRoundTrip)" -ErrorAction SilentlyContinue)
    Check "T7 suite slice GREEN" ($grand -match "GRAND TOTAL: (\d+)/(\d+) passed, 0 failed" -and $b25Fails.Count -eq 0) "grand=$($grand -replace '^.*GRAND TOTAL', 'GRAND TOTAL') b25Fails=$($b25Fails.Count)"
} else {
    Check "T7 suite slice GREEN" $false "suite_journal_slice.log missing in $($runDir.Name)"
}

#--- manifest buildIdentity.telemetry block (T9)
$tele = $manifest.buildIdentity.telemetry
$t9ok = $false
if ($null -ne $tele) {
    $t9ok = ([string]$tele.runId -match '^RUN-' -and [string]$tele.buildTag -match '^\d{4}\.\d{2}\.\d{2} ' -and (([string]$tele.gitHead) -match '^[0-9a-f]{40}$' -or [string]$tele.gitHead -eq "unknown"))
}
Check "T9 manifest telemetry block" $t9ok "runId=$($tele.runId) buildTag=$($tele.buildTag) gitHead=$($tele.gitHead)"

#--- T8: frozen baselines untouched
$frozen = @(
    @{ n = "ctl"; p = (Join-Path $SC "Tools\ED01\artifacts\EURUSD_M15\CONTROL_RLHYP01_INTEGRITY\telemetry_v5_20260421.csv"); h = "2E3941EAD446C79197624977000ECCF08041B50C66918C59EB0B5B99745DB27B" },
    @{ n = "baseCsv"; p = (Join-Path $SC "Tools\TT01\baseline\telemetry_v4_20260130.csv"); h = "B5AB5FEEAD758A814E903F00A0C62A8DF20AE87B7B63E630CF00408EFA0B2735" },
    @{ n = "baseMan"; p = (Join-Path $SC "Tools\TT01\baseline\baseline.manifest.json"); h = "82924B28339526B00B5F25161CB78A3B56B8D3909E4833E35B15EE99D726E3A9" }
)
foreach ($f in $frozen) {
    $h = (Get-FileHash -LiteralPath $f.p -Algorithm SHA256).Hash
    Check ("T8 frozen " + $f.n + " untouched") ($h -eq $f.h) ($(if ($h -eq $f.h) { "hash identical" } else { "MISMATCH: $h" }))
}

Write-Host ""
if ($fail -eq 0) { Write-Host "25B ARTIFACT TEST: ALL PASS - evidence $runArt" -ForegroundColor Green; exit 0 }
Write-Host "25B ARTIFACT TEST: $fail FAILURES - evidence $runArt" -ForegroundColor Red; exit 1

