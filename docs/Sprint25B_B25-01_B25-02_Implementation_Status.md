# Sprint 25B — B25-01 + B25-02 Implementation Status

**Date:** 2026-08-15 · **Run ID:** `TT01_20260815_112350` · **Verdict: OVERALL PASS (17/17 gates) · Sprint NOT CLOSED — await senior review. No commit, no push.**

## 1. Scope (authorized tranche)

- **B25-01 build identity in telemetry** — schemaVersion 6, append-only over v5: three identity columns `runId`, `buildTag`, `gitHead` appended at the END of the 78-column v5 schema (81 columns total; header positions 78/79/80 confirmed in artifact headers). Telemetry-only; no decision-generation, execution, or settlement semantics touched.
- **B25-02 durable flush checkpoint** — flush telemetry to disk every `TELEMETRY_CHECKPOINT_ROWS = 64` rows (existing design, previously disabled because gitHead was unreadable; re-enabled and suite-verified). No schema change.
- Forbidden scope honored: no DecisionRecord/event-ledger/ticket/settlement/restart-idempotency/MAFE/MAE/execution-quality/RiskManager/walk-forward/Monte-Carlo/MQL5-stats changes; no STOP condition was hit.

## 2. Exact run ID and harness

- `TT01_20260815_112350` — complete post-fix TT01 pipeline execution (COMPILE → SUITE → REPLAY → ACTIVE-TIER → SETTLEMENT-ISOLATION → INTEGRITY-CONTROL → PERFORMANCE → FINALIZE).
- Harness: `Tools\TT01\TT01_Validate.ps1` — EDITED this sprint (see §7).
- Previous scratch run `TT01_20260815_104758` (38-min accidental full run from a comma-joined `-Skip`; PowerShell `-File` does not split comma-joined arrays) — evidence only, gates purged by this run's reset + gates.jsonl restore (§10).

## 3. Source / build identity

- git head: `1e6aa5f` = `1e6aa5fd4af7c99f45dc59420e18b4bec92835c7` (`fix: close Sprint 25A runtime identity`).
- Working tree dirty with exactly the intended tranche edits (see §16) + sprint evidence.
- Compile-time identity now: `Telemetry\TelemetryGitHead.mqh` defines `TELEMETRY_GIT_HEAD "unknown"` by default; the harness rewrites it to the real 40-hex commit before compiling any target and restores `"unknown"` at finalize. The tranche binaries therefore embed the real commit; default-compiled binaries still carry `unknown` (safe default, no stale-commit lies).
- buildTag (telemetry): `2026.08.15 11:23:52` — inside the compile window (verified by TELEMETRY-CONTRACT + B25 test T6).

## 4. Root cause A — gitHead `unknown` in tester runs (RESOLVED)

**Finding (proven):** the strategy tester's `FILE_COMMON` is staged in the ephemeral tester-agent sandbox (`%APPDATA%\MetaQuotes\Tester\<id>\Agent-127.0.0.1-3000\...`, wiped when the terminal stops). Tester writes sync BACK to real `Common\Files` only at session end; a pre-existing real-Common file is INVISIBLE to `FileIsExist()/FileOpen()` during the run.

Evidence: file published to real Common before run → EA still read `unknown` (`25B_SuiteCheck_20260815_103414`); in-process write→read works (suite parse tests); no sandbox mirror found while the terminal was stopped.

**Fix:** runtime gitHead is unattainable in-tester → made it a compile-time constant via `TelemetryGitHead.mqh` (harness-injected). `ReadGitHead()` + `IsHexString()` removed from `TelemetryCollector.mqh` (dead code).

## 5. Root cause B — 116 rows vs 500 (RESOLVED)

**Finding:** checkpoint flushes rotate the telemetry file per simulated day (`BuildFilePath()` uses simulated `TimeCurrent()`), so a run's records span multiple dated files; the harness's single `$OutCsv` capture saw only the run's tail (64+52 = 116 rows). v5 was single-file (flush only at Shutdown).

**Fix:** per-phase **clear + merge** in `TT01_Validate.ps1`:
- New `Merge-TT01Telemetry -TargetPath`: concatenates ALL `telemetry_v6_*.csv` in the telemetry dir (header once + data rows, files sorted by name = chronological = pre-checkpoint order), UTF8-no-BOM.
- Replay phase: `Clear-TT01Telemetry` before the pass; merge after the headless session ends (files synced by then).
- Active-tier phase: same clear (drops the default run's dated files) + merge into `$OutCsv` before the `$k1Csv` copy.
- Isolation phase: unchanged (already clears + captures all).
- Merge logs observed: `merged 7 dated file(s)` (replay), `merged 4 dated file(s)` (k1).

## 6. Schema and collector changes

- `Telemetry\TelemetryCollector.mqh`: includes `TelemetryGitHead.mqh`; `m_gitHead = TELEMETRY_GIT_HEAD;`; B25-02 `TELEMETRY_CHECKPOINT_ROWS=64` flush logic intact; header comments updated. `schemaVersion=6`; v6 = v5's 78 columns + `runId,buildTag,gitHead` (append-only, backward compatible; v5 readers still parse the first 78 fields).
- `runId` = `RUN-<buildTag>-<GetTickCount>`; `buildTag` = compile parse time; `gitHead` = compile-time 40-hex (see §4).
- No change to any behavior column, configFingerprint definition, decisionId sequence, or pairing-key semantics.

## 7. Harness changes

- `Tools\TT01\TT01_Validate.ps1`: `Merge-TT01Telemetry` helper; clear+merge in replay and active-tier phases; gitHead include write (run-start, before any compile) + restore (finalize); run_identity identity-file lifecycle (retired + archived in run artifact).
- `Tools\25B\25B_SuiteCheck.ps1`: include write before its compile loop + restore after.

## 8. Suite check (B25 scoped) — ALL PASS

`25B_SuiteCheck_20260815_111746`: 6/6 compiles 0 errors; S1 GRAND TOTAL 2860/2860; S2/S3 B25 tests present + green; S4 81 cols, badSchema=0, badRunId=0, badBuild=0, badGit=0; S5 checkpoint=64. Suite CSV rows=14, gitHead = `1e6aa5fd4af7c99f45dc59420e18b4bec92835c7` (real 40-hex).

## 9. Full TT01 results — OVERALL PASS 17/17

Pipeline-recorded gates (all PASS):

PREFLIGHT · COMPILE-SuperCents_X · COMPILE-CalibrationRunner · COMPILE-TestRunner · COMPILE-TestRunnerEA · COMPILE-BenchmarkRunner · COMPILE-BenchmarkRunnerEA · COMPILE · SUITE (identity OK) · REPLAY (500 rows, HEALTHY) · TELEMETRY-CONTRACT (gitHead = real 40-hex, buildTag in window) · EVIDENCE-REGRESSION · BEHAVIOR-REGRESSION (500 rows, 71 behavior columns byte-identical) · ACTIVE-TIER (500 → 273, nGatedOut=227, k1 health rows=273) · SETTLEMENT-ISOLATION · INTEGRITY-CONTROL · PERFORMANCE (replayMs=15564, peakMemMB=765.3, suiteMs=9099)

## 10. gates.jsonl integrity

Restored byte-identical to the Run-5 record after the scratch run polluted it: SHA256 `2E221E7FE86D75D7C296827292AB45CDA6279EE34F48E3B98462A27D93E9277F`, 17 lines, from backup `%TEMP%\opencode\gates.jsonl.bak25B`. Correct path: `Tools\TT01\run\gates.jsonl` (a stray `Tools\TT01\gates.jsonl` was mistakenly created and deleted).

## 11. Post-run targeted test — 25B_B25_Test ALL PASS

`Tools\25B\25B_B25_Test.ps1` on `TT01_20260815_112350` evidence (T1–T9): 117 isolation-arm CSVs, all valid 81-col v6 with identity on every row; 4 distinct runIds (default/k1/isolation-control/isolation-k1); 1 buildTag + 1 gitHead across all arms; CSV identity == manifest (full form) == archived run_identity.txt; buildTag inside prod compile window; suite slice GREEN with 0 B25 fails; all frozen artifacts unchanged; manifest telemetry block present.

**Test-parsing fix (in-sprint):** T1/T2 now CSV-aware via `Import-Csv` (the original naive `-split ","` broke on quoted packed fields like ruleEvidenceIds); T3 = distinct runIds >= 3 arms (one arm legitimately shares a runId across its dated files); T5 compares the CSV full 40-hex vs `manifest.buildIdentity.sourceTree.gitHeadFull` (+ archived run_identity.txt). The pre-fix RED was a test bug, not a data defect.

## 12. ED01 compatibility — PASS (one analyzer fix)

- `ED01_RLHYP01_Analyze.py --mode selfcheck`: PASS (deterministic; CONTROL reproduces frozen audit constants).
- `--mode gate` on the ADMISSIBLE fixed set (`Tools\ED01\artifacts_FIX` + `ED01_RLHYP01_manifest_FIX.json`): **GATE PASS** — gate2 (9 arms), gate3a decisionId-invariant (3 files), gate3b admission-only 0 diverging rows, gate3c distinguishability, identity provenance gate **skips v5 arms** ("no identity columns (historical v5 artifacts) - skipped") as designed.
- **Analyzer fix (in-sprint):** the B25-01 identity-column exemption in gate3a was unconditional; frozen v5 INTEGRITY arms (78 cols) were then compared against an expected 81. Exemption is now conditional on the arm actually carrying the identity columns (`if c not in a and c in b`) — v5 arms compare 75+3, v6 arms 75+3+3. Re-run: GATE PASS.
- Note: the DEFAULT `Tools\ED01\artifacts` tree is the preserved INADMISSIBLE original 58-divergence set (tier-arm CSVs differ from `artifacts_FIX`); the gate correctly FAILS there. That is pre-existing data, untouched — the admissible set is `artifacts_FIX`.

## 13. Frozen baselines — untouched (hash-verified post-run)

- `Tests\TestRunnerEA.ex5.bak20260812_194614` — `BB6392F49DE0C7EC3E83BF515FC730A1D4A4DA40076B73B7D207E8C59252370F` ✓
- `Tools\TT01\baseline\telemetry_v4_20260130.csv` — `B5AB5FEEAD758A814E903F00A0C62A8DF20AE87B7B63E630CF00408EFA0B2735` ✓
- `Tools\TT01\baseline\baseline.manifest.json` — `82924B28339526B00B5F25161CB78A3B56B8D3909E4833E35B15EE99D726E3A9` ✓
- `Tools\ED01\artifacts\EURUSD_M15\CONTROL_RLHYP01_INTEGRITY\telemetry_v5_20260421.csv` — `2E3941EAD446C79197624977000ECCF08041B50C66918C59EB0B5B99745DB27B` ✓
- Run-5 evidence dir `Tools\TT01\artifacts\TT01_20260814_235134\` — all 20 files hash-verified unchanged (e.g. `SuperCents_X.ex5` `59C414AA…`, `TestRunnerEA.ex5` `D1BB10F9…`, isolation `telemetry_v5_20260421.csv` `2E3941EA…` = frozen CONTROL; last write 2026-08-15 00:21:16, all pre-tranche). Manifest stays absent (25A record).

## 14. Performance

Perf gate PASS: replayMs=15564 (vs run-5 18701), peakMemMB=765.3 (vs 767.2), suiteMs=9099, csvBytes=402761. Checkpoint flushing + merge impose no material regression.

## 15. Known limitations / follow-ups (documented, NOT defects in scope)

- Tester sandbox staging of `FILE_COMMON` remains a platform fact; compile-time gitHead is the correct attribution for tester runs. A future "runtime provenance" item would need the manifest binding (out of scope).
- `Tools\ED01\ED01_RLHYP01_Analyze.py` DEFAULT artifacts path still points at the inadmissible original tree; the admissible set must be passed explicitly (`--artifacts artifacts_FIX --manifest manifest_FIX.json`). Pre-existing; documented here.
- EN-03 frozen `telemetry_v5_*.csv` filters — pre-existing finding, unchanged (documented follow-up).
- `Tools\TT01\launcher.ps1` `-Skip` passes: repeated `-Skip x` pairs required (comma-joined single arg does not split under `-File`).

## 16. Files changed (uncommitted — NO commit, NO push)

`SuperCents_X.mq5`, `Telemetry\CalibrationDataset.mqh`, `Telemetry\TelemetryCollector.mqh`, `Telemetry\TelemetryGitHead.mqh` (NEW), `Telemetry\TelemetryHealthReport.mqh`, `Telemetry\TelemetryTypes.mqh`, `Tests\unit\TestCalibrationDataset.mqh`, `Tests\unit\TestTelemetry.mqh`, `Tests\unit\TestTelemetryHealth.mqh`, `Tools\TT01\TT01_Validate.ps1`, `Tools\TT01\TT01_Validators.ps1`, `Tools\25B\*` (suite check, B25 test, artifacts), `Tools\ED01\ED01_RLHYP01_Analyze.py` (untracked, gate3a conditional exemption). gates.jsonl restored byte-identical; frozen baselines untouched; git history untouched.

## 17. Final recommendation

- **B25-01 + B25-02 = IMPLEMENTED + VALIDATED** — 17/17 TT01 gates PASS; suite check ALL PASS; 25B_B25_Test ALL PASS; ED01 gate PASS on the admissible set; frozen baselines + Run-5 evidence hash-verified unchanged; perf in line with 25A.
- **Sprint 25B is NOT CLOSED.** No commit, no push, no further backlog item (B25-03…) started. Await senior review of this report and explicit commit/push authorization.

STOP — tranche complete; no commit, no push.
