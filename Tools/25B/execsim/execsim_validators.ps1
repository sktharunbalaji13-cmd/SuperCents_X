# execsim_validators.ps1 - B25-03A validation helpers (dot-sourced by execsim_identity.ps1)
# Copyright 2026, SuperCents_X - Sprint 25B B25-03A. Doc-only + harness scope.

#--- frozen evidence reference hashes (verified byte-identical through commit
#   3c2f02a and the B25-02 push; prefixes match the B25-02 recorded values).
$script:ExsimFrozenEvidence = @(
    @{ Label = "TestRunnerEA.ex5.bak20260812_194614"; Path = "Tests\TestRunnerEA.ex5.bak20260812_194614";
       Hash = "BB6392F49DE0C7EC3E83BF515FC730A1D4A4DA40076B73B7D207E8C59252370F" },
    @{ Label = "telemetry_v4_20260130.csv"; Path = "Tools\TT01\baseline\telemetry_v4_20260130.csv";
       Hash = "B5AB5FEEAD758A814E903F00A0C62A8DF20AE87B7B63E630CF00408EFA0B2735" },
    @{ Label = "baseline.manifest.json"; Path = "Tools\TT01\baseline\baseline.manifest.json";
       Hash = "82924B28339526B00B5F25161CB78A3B56B8D3909E4833E35B15EE99D726E3A9" },
    @{ Label = "telemetry_v5_20260421.csv (ED01 CONTROL)"; Path = "Tools\ED01\artifacts\EURUSD_M15\CONTROL_RLHYP01_INTEGRITY\telemetry_v5_20260421.csv";
       Hash = "2E3941EAD446C79197624977000ECCF08041B50C66918C59EB0B5B99745DB27B" }
)

#--- B25-03A authorized change set (exact files this phase may create/modify).
$script:ExsimAuthorizedTracked = @( "Tests\TestSuite.mqh" )
$script:ExsimAuthorizedNew = @(
    "Trading\ExecutionIdentity.mqh",
    "Tests\unit\TestExecutionIdentity.mqh",
    "Tools\25B\execsim\execsim_identity.ps1",
    "Tools\25B\execsim\execsim_validators.ps1",
    "Tools\25B\execsim\profiles\identity.ini",
    "docs\Sprint25B_B25-03A_Identity_Status.md"
)

#--- pre-existing untracked files that must remain untouched (skills side-work,
#   evidence, prior docs, 25A leftovers) - nothing in this set may change.
$script:ExsimPreexistingUntracked = @(
    ".agents", ".claude", ".opencode", "skills-lock.json",
    "Tests\TestRunnerEA.ex5.bak20260812_194614",
    "Tools\25A\g2_backup", "Tools\25A\g8_test", "Tools\25A\tt01_run_25A.txt",
    "Tools\ED01\ED01_RLHYP01_RunBatch.ps1", "Tools\ED01\ED01_RLHYP01_manifest.json",
    "Tools\ED01\ED01_RLHYP01_manifest_FIX.json", "Tools\ED01\gate_FIX_transcript.txt",
    "Tools\ED01\results_RLHYP01_FIX.json", "Tools\ED01\results_RLHYP01_selfcheck.json",
    "Tools\EN03", "Tools\SprintRoadmap",
    "docs\Sprint25B_Architecture_Readiness_Assessment.md",
    "docs\Sprint25B_B25-03_ExecutionTruth_Assessment.md",
    "docs\Sprint25B_B25-03_ExecutionTruth_Design.md"
)

function Get-ExsimJournalBlock {
    # Extracts the LAST tester run from the agent journal: from its run-start
    # banner (">>> BUILD ") to the end of the file. The journal accumulates
    # all tester activity of the day, so a fixed-size tail window is unsafe;
    # anchoring on the run-start banner is exact.
    param([string]$AgentLog)
    if (-not (Test-Path -LiteralPath $AgentLog)) { return @() }
    $all = @(Get-Content -LiteralPath $AgentLog)
    $bannerIdx = -1
    for ($i = $all.Count - 1; $i -ge 0; $i--) {
        if ($all[$i] -match ">>> BUILD ") { $bannerIdx = $i; break }
    }
    if ($bannerIdx -lt 0) { return @() }
    @($all[$bannerIdx..($all.Count - 1)])
}

function Test-ExsimCommentCompatStatic {
    # Static comment-budget / format proofs (MQL5-side semantic proofs run in
    # the unit suite: SCX-BUY-P123#456 -> 123, legacy unchanged, round-trips).
    $fail = 0; $detail = [System.Collections.Generic.List[string]]::new()
    $worst = "SCX-SELL-P2147483647#99999999"
    if ($worst.Length -gt 31) { $fail++; $detail.Add("worst-case comment length $($worst.Length) > 31") }
    else { $detail.Add("worst-case comment length $($worst.Length) <= 31: $worst") }
    if ($worst -notmatch '^SCX-(BUY|SELL)-P\d+#\d+$') { $fail++; $detail.Add("new-format regex mismatch") }
    else { $detail.Add("new-format regex OK: ^SCX-(BUY|SELL)-P\d+#\d+$") }
    if ("SCX-BUY-P123" -notmatch '^SCX-(BUY|SELL)-P\d+$') { $fail++; $detail.Add("legacy-format regex mismatch") }
    else { $detail.Add("legacy-format regex OK: ^SCX-(BUY|SELL)-P\d+$ (unchanged)") }
    if ("SCX-BUY-P123#456" -notmatch '^SCX-(BUY|SELL)-P\d+#\d+$') { $fail++; $detail.Add("new-format sample mismatch") }
    else { $detail.Add("sample OK: SCX-BUY-P123#456") }
    return @{ pass = ($fail -eq 0); details = $detail.ToArray() }
}

function Test-ExsimFrozenEvidence {
    $fail = 0; $detail = [System.Collections.Generic.List[string]]::new()
    foreach ($e in $script:ExsimFrozenEvidence) {
        $p = Join-Path $script:ExsimRoot $e.Path
        if (-not (Test-Path -LiteralPath $p)) { $fail++; $detail.Add("MISSING: $($e.Path)"); continue }
        $h = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash
        if ($h -ne $e.Hash) { $fail++; $detail.Add("HASH CHANGED: $($e.Path) $($h.Substring(0,8))... (expected $($e.Hash.Substring(0,8))...)") }
        else { $detail.Add("frozen OK: $($e.Label) $($h.Substring(0,8))...") }
    }
    $gj = Join-Path $script:ExsimRoot "Tools\TT01\run\gates.jsonl"
    if (Test-Path -LiteralPath $gj) {
        $lines = @(Get-Content -LiteralPath $gj -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne "" })
        if ($lines.Count -ne 17) { $fail++; $detail.Add("gates.jsonl line count $($lines.Count) != 17") }
        else { $detail.Add("gates.jsonl intact: $($lines.Count) lines") }
    } else { $fail++; $detail.Add("gates.jsonl missing") }
    return @{ pass = ($fail -eq 0); details = $detail.ToArray() }
}

function Test-ExsimScope {
    # Exact-files-changed proof: tracked diffs, untracked additions, HEAD.
    # git emits forward slashes; the authorized/preexisting lists are stored
    # with backslashes - normalize everything to forward slashes. Untracked
    # directories are allowed when they contain only authorized files
    # (prefix rule) or are pre-existing.
    $fail = 0; $detail = [System.Collections.Generic.List[string]]::new()
    $head = (git -C $script:ExsimRoot rev-parse HEAD) -replace "`n",""
    if ($head -ne "3c2f02a200da1eaf57e5b689068782997d9dbc0c") {
        $fail++; $detail.Add("HEAD changed: $head (expected 3c2f02a...)")
    } else { $detail.Add("HEAD unchanged: $head") }
    $trackedDiff = @(git -C $script:ExsimRoot diff --name-only | ForEach-Object { $_ -replace '\\','/' })
    $authTracked = @($script:ExsimAuthorizedTracked | ForEach-Object { $_ -replace '\\','/' })
    $unexpectedTracked = @($trackedDiff | Where-Object { $_ -notin $authTracked })
    if ($unexpectedTracked.Count -gt 0) { $fail++; $detail.Add("UNEXPECTED TRACKED CHANGES: $($unexpectedTracked -join '; ')") }
    else { $detail.Add("tracked diff: $($trackedDiff -join ', ') (authorized: $($authTracked -join ', '))") }
    $authNew = @($script:ExsimAuthorizedNew | ForEach-Object { $_ -replace '\\','/' })
    $preExisting = @($script:ExsimPreexistingUntracked | ForEach-Object { $_ -replace '\\','/' })
    $untracked = @(git -C $script:ExsimRoot status --porcelain | Where-Object { $_ -match '^\?\?' } |
        ForEach-Object { $_.Substring(3) } | ForEach-Object { $_.TrimEnd('/') -replace '\\','/' })
    $unexpectedNew = @($untracked | ForEach-Object {
        $entry = $_
        $ok = ($entry -in $authNew) -or ($entry -in $preExisting) -or
              (@($authNew | Where-Object { $_.StartsWith($entry + "/") }).Count -gt 0)
        if (-not $ok) { $entry }
    })
    if ($unexpectedNew.Count -gt 0) { $fail++; $detail.Add("UNEXPECTED UNTRACKED: $($unexpectedNew -join '; ')") }
    else { $detail.Add("untracked set: authorized-new + pre-existing only ($($untracked.Count) entries)") }
    return @{ pass = ($fail -eq 0); details = $detail.ToArray() }
}
