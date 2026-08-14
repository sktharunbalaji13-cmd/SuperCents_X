# Sprint 25A-RUNTIME-01 — Final Validation Report (G7)

**Date:** 2026-08-14/15 · **Run ID:** `TT01_20260814_235134` · **Status: G7 = PASS · Sprint NOT CLOSED — await senior review**

## 1. Exact run ID

- `TT01_20260814_235134` (complete post-fix TT01 pipeline execution)
- Harness: `Tools\TT01\TT01_Validate.ps1` (no parameters; authoritative pipeline, unmodified)
- Launched 23:51:34, phases: COMPILE → SUITE → REPLAY → ACTIVE-TIER → SETTLEMENT-ISOLATION → INTEGRITY-CONTROL → PERFORMANCE → FINALIZE

## 2. Source / build identity

- git head: `73e5886` (`fix: close EN-03 coordinated trend-flip gate`)
- Working tree: dirty (16 entries) — the uncommitted Sprint 25A changes are exactly: `M Tests\TestRunnerEA.mq5`, `M Tools\TT01\TT01_Validate.ps1`, plus untracked sprint evidence (`Tools\25A\`, `docs\Sprint25A_*`, `.opencode\`, the preserved `Tests\TestRunnerEA.ex5.bak20260812_194614`, `Tools\ED01\`/`Tools\EN03\`/`Tools\SprintRoadmap\`)
- Build tag contract (25A-RUNTIME-01): `>>> BUILD 25A-RUNTIME-01 tag="yyyy.MM.dd HH:mm:ss" term=<build> path=<MQL_PROGRAM_PATH>`
- Compile: 6 targets, 0 errors; warning counts 4/0/6/6/0/0 = golden (no warnings added)

## 3. Compiled EX5 hashes (run-5 compile, on-disk verified)

| Target | Size (B) | SHA256 (prefix) | Refreshed |
|---|---|---|---|
| SuperCents_X.ex5 | 454,168 | 59C414AA2DF3A887… | yes (hashChanged=True) |
| CalibrationRunner.ex5 | 183,208 | E12F9076… | yes |
| TestRunner.ex5 | 2,119,494 | 98FB5543CC2CF420… | yes |
| TestRunnerEA.ex5 | 2,119,262 | D1BB10F992AC8E68… | yes |
| BenchmarkRunner.ex5 | 200,694 | 30C7FBAB… | yes |
| BenchmarkRunnerEA.ex5 | 200,730 | 7F58BF26… | yes |

## 4. Runtime-loaded identity (G1/G6 — SUITE gate, pipeline-verified)

- buildLine: `>>> BUILD 25A-RUNTIME-01 tag="2026.08.14 23:54:59" term=6104 path=…Agent-127.0.0.1-3000\MQL5\Experts\SuperCents_X\Tests\TestRunnerEA.ex5`
- Identity checks (all PASS): runtime tag inside the compile window `[suiteCompileStartedAt−15s .. suiteCompileEndedAt+15s]`; executed path is the tester agent sandbox (`…MetaQuotes\Tester\D0E8…\Agent-127.0.0.1-3000\…\Tests\TestRunnerEA.ex5`, suffix-matches the canonical project tree); on-disk ex5 hash == compiled artifact `D1BB10F9…`
- Run attribution: `runtime_identity.log` archived into the run artifact; executed binary path = agent sandbox staging (cleanup verified — 0 ex5 leftovers)

## 5. Stale-binary test result (G2/G9 — preserved pre-fix binary)

Evidence: `Tools\25A\artifacts\25A_G2G9_20260814_205620\result.json` (authoritative G2/G9 script; state unchanged since, frozen `.bak` hash re-verified today):

- G2a tagMismatch PASS — stale binary emits no build tag inside the fresh-build window → self-identified as stale
- G2b artifactMismatch PASS — on-disk `BB6392F4…` != expected `C8C85B60…` → swapped artifact detected
- G2c suiteRed PASS — suite failures: 2 (must be > 0)
- G9 noWeakening PASS — **`exp=99 got=0` FAIL lines preserved: 4 (expected ≥ 2: swing + low-swing)** — the failing assertion remains a genuine RED on the preserved pre-fix binary

## 6. Run attribution result

- Terminal 5.0.0.6104 / MetaEditor 5.0.0.6104, data folder `D0E8209F77C8CF37AD8BF550E51FF075`, origin.txt = `C:\Program Files\MetaTrader 5` (binding OK)
- The executed binary is the one this run compiled (tag/hash/path triple verified in-gate); attribution = run-5 compile → agent sandbox load

## 7. Complete TT01 results (all gates, pipeline-recorded)

17/17 gates **PASS** — verified from the pipeline's own durable ledger `Tools\TT01\run\gates.jsonl` (17 records, 17 pass, 0 fail):

PREFLIGHT · COMPILE-SuperCents_X · COMPILE-CalibrationRunner · COMPILE-TestRunner · COMPILE-TestRunnerEA · COMPILE-BenchmarkRunner · COMPILE-BenchmarkRunnerEA · COMPILE · SUITE (2738/2738, identity OK) · REPLAY (500 rows, HEALTHY) · TELEMETRY-CONTRACT · EVIDENCE-REGRESSION · BEHAVIOR-REGRESSION · ACTIVE-TIER (273/500 admitted, gate 3b clean) · SETTLEMENT-ISOLATION (3327/6239 admitted, Design A 58→0) · INTEGRITY-CONTROL (6239 rows == frozen CONTROL) · PERFORMANCE (replayMs=18701, peakMemMB=767.2)

Note: the harness arm-health summary printed `rows=-1` for both isolation arms in run 5 (a health-reporting display anomaly; the gate verdicts are computed independently by the validators, which measured 6239/3327 rows and PASSED; INTEGRITY-CONTROL independently corroborates 6239 rows == frozen CONTROL). Non-gate observation, no assertion weakened.

## 8. G1–G9 verdict table

| Gate | Verdict | Evidence |
|---|---|---|
| G1 RUN-BINARY SELF-ID | PASS | buildLine tag `2026.08.14 23:54:59` inside compile window; path = agent sandbox canonical tree |
| G2 STALE-DETECTION | PASS | 25A_G2G9: tag absent on stale `.bak`, artifact hash mismatch detected, suite RED |
| G3 ARTIFACT-IDENTITY | PASS | on-disk TestRunnerEA.ex5 hash == compiled artifact `D1BB10F9…`; COMPILE gates 6/6 refreshed |
| G4 NO-DUPLICATE | PASS | PREFLIGHT: canonical binary unique (excludes harness's own `\Tools\` archive) |
| G5 DATA-FOLDER BINDING | PASS | PREFLIGHT: origin.txt binding OK; foreign folders + tester sandbox clean |
| G6 RUN ATTRIBUTION | PASS | runtime_identity.log + executed-path triple in SUITE gate; sandbox cleanup verified |
| G7 FULL TT01 REGRESSION | **PASS** | 17/17 gates PASS (pipeline-recorded) — see §7 |
| G8 REPRODUCIBILITY | **PARTIAL / LIMITATION** | deterministic gates re-passed (INTEGRITY-CONTROL, ACTIVE-TIER, BEHAVIOR); provenance manifest absent (see §10) |
| G9 NO-WEAKENING | PASS | 4 genuine `exp=99 got=0` FAIL lines preserved on the pre-fix binary; 2594/2596 RED intact |

## 9. Artifact locations

- `Tools\TT01\artifacts\TT01_20260814_235134\` — run-5 artifact dir: `runtime_identity.log`, `suite_journal_slice.log`, `telemetry_v5_default.csv`, `telemetry_v5_k1.csv`, isolation arm CSVs (`isolation_control\`, `isolation_k1\`), `binaries\` (+sha256)
- `Tools\TT01\run\gates.jsonl` — 17-gate durable ledger (PASS×17)
- `Tools\TT01\run\runtime_identity.log` — run-5 buildLine
- `Tools\25A\artifacts\25A_G2G9_20260814_205620\` — G2/G9 evidence (`result.json`, `suite_journal_slice.log`)
- `Tools\TT01\artifacts\TT01_20260814_144247\manifest.json` — golden PASS manifest reference
- `Tools\TT01\artifacts\TT01_20260814_230323\` — substantive run-4 evidence (pre-PREFLIGHT-fix gates)
- `Tools\TT01\artifacts\TT01_20260814_234346\` — harness/finalization test artifact (NOT a validation run)
- `docs\Sprint25A_RuntimeIdentity_Assessment.md`, `docs\Sprint25A_RuntimeIdentity_Validation_Status.md`

## 10. Frozen baselines — untouched (hash-verified pre- and post-run)

- `Tests\TestRunnerEA.ex5.bak20260812_194614` — `BB6392F49DE0C7EC3E83BF515FC730A1D4A4DA40076B73B7D207E8C59252370F` (unchanged)
- `Tools\TT01\baseline\telemetry_v4_20260130.csv` — `B5AB5FEEAD758A814E903F00A0C62A8DF20AE87B7B63E630CF00408EFA0B2735` (unchanged)
- `Tools\TT01\baseline\baseline.manifest.json` — `82924B28339526B00B5F25161CB78A3B56B8D3909E4833E35B15EE99D726E3A9` (unchanged)
- `Tools\ED01\artifacts\EURUSD_M15\CONTROL_RLHYP01_INTEGRITY\telemetry_v5_20260421.csv` — `2E3941EAD446C79197624977000ECCF08041B50C66918C59EB0B5B99745DB27B` (unchanged)

## 11. Evidence-package limitation (NOT a failed gate)

`manifest.json` was **not written** for run 5 because the harness was externally aborted during the final ~5-second finalize window (verified: process exited, no `manifest.json`, no `manifest_ERROR.json`). This is an evidence-package completeness limitation, not a TT01 gate failure. Finalize/manifest serialization has been proven to complete in ~5 seconds when allowed to finish:

- Harness finalize test (`TT01_20260814_234346`): `manifest.json written`, clean exit, ~5 s total
- Full 17-gate graph serialization (real pipeline records): `ConvertTo-Json -Depth 10` = **6 ms**, 18,272 chars
- No replacement manifest was created or labeled pipeline-generated

## Final recommendation

- **G7 = PASS** — based on the complete 17/17 pipeline-recorded gate graph of run `TT01_20260814_235134`, including the corrected PREFLIGHT.
- **G8 / provenance completeness = PARTIAL / LIMITATION** — the pipeline-written `manifest.json` is absent (external abort in the finalize window); all gate-level evidence is pipeline-recorded and preserved.
- **Sprint 25A-RUNTIME-01 is NOT marked CLOSED.** No commit, no push, no Sprint 25B/25C. Await senior review of this report.
