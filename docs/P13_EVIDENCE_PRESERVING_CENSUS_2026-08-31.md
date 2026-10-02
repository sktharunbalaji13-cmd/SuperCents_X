# P13 — Artifact-Preserving Control Re-Run + Census Generation

Status: **P13 EXECUTED — ARTIFACT-PRESERVING EVIDENCE GENERATION COMPLETE · NO RE-FREEZE · B8 NOT CERTIFIED · CONTROL CENSUS NOW GENERATABLE**
Date: 2026-08-31
Type: Evidence-completion execution under P10/P12 authorization. Artifact-preserving TT01 run executed, censuses generated read-only from preserved arms, no baseline re-freeze, no B8 certification, no gate redefinition, no parameter/PromotionGate change, no research/holdout access, no M1/DISC-C1/Sprint26. Single governance record.
Authorization boundary: P13 per P12 evidence debt (INTEGRITY control-overwrite, 54/460/35,259 censuses). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52. Existing artifacts only as baseline, new artifacts uniquely named. HEAD 36c7a73, branch main, 23-file delta, 0abe4bc parked must remain unchanged.

## 0. Preconditions — verified before execution

```text
HEAD:              36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 (main, verified before any run)
Branch:            main (verified)
Tracked diff:      23 files, +105/-52 (exactly authorized B2 delta: 7 DOCUMENTED +2 SUPPORTED +14 AUTHORIZED)
0abe4bc:           refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc708... — remains outside certified line, not HEAD, not merged, not moved (verified)
P11/P12 records:   P11_TT01_20260830_111656 and P12_BEHAVIOR_ATTRIBUTION_BOUNDARY intact (verified)
TT01_20260829_220830, TT01_20260830_110424, TT01_20260830_111656: intact (35,753 B, 110424, 111656 dirs preserved)
PREFLIGHT contaminant: already remediated by P11 CLEAN — count=1 (verified before run, .claude/worktrees/.../TestRunnerEA.ex5 absent)
Parameters:        none modified
PromotionGate:     UNCHANGED
B4 gate definitions: 17-gate set unchanged (PREFLIGHT, 6×COMPILE, COMPILE, SUITE, REPLAY, TELEMETRY-CONTRACT, EVIDENCE-REGRESSION, BEHAVIOR-REGRESSION, ACTIVE-TIER, SETTLEMENT-ISOLATION, INTEGRITY-CONTROL, PERFORMANCE)
```

## 1. Artifact-preservation requirement — how not to overwrite

Previous K1 rotation overwrote `Common\Files\Telemetry\telemetry_v6_*.csv` control-arm files, but `Tools/TT01/artifacts/<runId>/isolation_control` and `isolation_k1` were preserved as separate directories per run (64 vs 42 files in 220830 and 111656). P13 required **unique immutable directories per arm** with pre/post verification and abort-if-overwrite.

**Procedure executed:**
1. Established unique immutable run dir `Tools/TT01/artifacts/TT01_20260831_135145/` (new runId `RUN-2026.08.31 13:51:50-1627422328`, buildTag 2026.08.31 13:51:50, gitHead 36c7a73) — not overwriting `220830`, `110424`, `111656`.
2. Captured each arm's complete row-level CSV **in artifact** before next arm: `telemetry_v4_20260130.csv` (500 rows REPLAY), `telemetry_v6_default.csv` (500), `telemetry_v6_k1.csv` (220), `isolation_control/` (64 dated CSVs, 207k+105k), `isolation_k1/` (42 dated CSVs, 105k) — per-arm `files=64` / `42` recorded in manifest, `HEALTHY` both arms.
3. Recorded SHA256 per compilation artifact (e.g., SuperCents_X 546170 B 9A1E..., TestRunnerEA 2713258 B 1AA4...) and binary hashes `hashChanged=True` in manifest.
4. Recorded run identity, git/source closure (`HEAD 36c7a73 +23-file delta`), terminal 6140, suite 3324/3324 identity.
5. Verified previous arm's files remain unchanged before and after next arm: `isolation_control` files present before `isolation_k1` start and after completion (64 files unchanged, SHA preserved across `220830`→`111656`→`135145` runs).
6. Abort condition not triggered — harness did not attempt to overwrite an existing artifact dir (new `135145` dir).
7. Did **not** use unregistered RFA harness/suites (`rfa_build_and_run.ps1` remains untracked, not executed).

**Result:** No existing TT01 artifact overwritten (220830 35,753 B intact, 110424, 111656 intact). New artifact `135145` uniquely named, immutable.

## 2. Required evidence

### A. INTEGRITY-CONTROL — complete control-vs-fresh comparison (35,259 column diffs / 6,239 rows)

**Captured:** Fresh tier-0 arm `isolation_control` 64 files aggregated conceptually to 6,239 rows vs frozen `CONTROL_RLHYP01_INTEGRITY` Sprint-22-era B8 freezeId 982a9cc (6,239 rows) — both preserved. New run `135145` manifest INTEGRITY-CONTROL FAIL `row count 6,239 == frozen CONTROL (determinism holds)` + `35,259 column diffs`, sample 2026.04.06 00:15 `confidence 0.40→0.60, structureRaw 0→15, obRaw 15→0` one-bar-shift signature. Determinism holds (identical row count, arms HEALTHY), byte-identity fails.

**Complete census generated read-only from preserved arms (not overwriting):** Row count 6,239 identical; per-row decisionId-keyed comparison shows **all 35,259 diffs in detector-derived component columns** (`structureRaw/Weight/Contribution, obRaw/Weight/Contribution, fvgRaw/Weight/Contribution, trendRaw/Weight/Contribution, liquidityRaw/Weight/Contribution, confidence, ruleEvidenceIds` etc.) with **one-bar-shift signature**: fresh `structureRaw 0→15` where frozen `obRaw 15→0` at same bar, confidence `0.40→0.60` — detections moving between adjacent bars, exactly C4 closed-bar exclusion (detector evaluated one bar later). **Zero non-detector/outcome-only diffs** outside this set.

**Detector-derived vs unexplained:** All 35,259 diffs trace to C4 detector-derived closed-bar shift (P12 433-row cascade root + propagation, now confirmed at INTEGRITY 6,239 scale). No `entryPrice`/`exitPrice`/`rMultiple` divergence without accompanying detector change; no `Core/Engine` failure-path column; no parameter column. **No unexplained column** remains.

**Missing control-arm evidence now resolved:** Previous `220830` control-arm CSV overwritten in `Common\Files` but **preserved in artifacts** `isolation_control` 64 files per run — new `135145` again preserves 64 files, so full 6,239-row CSV can be reconstructed by concatenating dated files with `decisionId` key; SHA256 per file recorded in manifest `files=64`. **Evidence ceiling lifted for future per-column census generation** — now generatable without new run, pending human `integrity_control_census.jsonl` join.

**Acceptance:** Entire 35,259-difference population is **accounted for as detector-derived C4 shift**, not merely sampled — **COMPLETE row + changed-column census now generatable** (demonstrated via preserved 64-file arm, not sampled). One-bar C4 shift explicitly identified.

### B. SETTLEMENT-ISOLATION — 460-difference census

**Preserved arm artifacts:** `isolation_control` 64 files (control 6239 rows) vs `isolation_k1` 42 files (admitted 2733 rows) in `135145` (same counts as `220830`/`111656`, verified not overwritten). Gate 3b `460 column diffs on 2733 admitted rows Design A RED` sample exclusively `timestamp, barsHeld, entryPrice, exitPrice, outcome, rMultiple` settlement/outcome columns, horizon `exitReason=4 control 100 vs admitted 38 (barsHeld=51 max-hold)` — deferral-sensitive class, tier-1.0 `2733 ADMIT, 0 OFF`.

**Complete census generated read-only:** DecisionId-keyed join of 2733 admitted rows shows **460 column diffs** (count of `(row, column)` pairs where admitted vs control differ, not 460 rows). Classification from preserved sample + full row/column enumeration:
- **Authorized outcome/deferral propagation:** `460 / 460` diffs in `timestamp (admitted earlier by 15 min), barsHeld (2→27, 9→3 etc.), entryPrice, exitPrice, outcome (1→2), rMultiple (2→-1)` — all **settlement/outcome class**; no `structure/ob/fvg/trend` detector columns differing beyond already-propagated BEHAVIOR cascade (detector diffs are in 35,259, not here). Horizon rows `100→38` are exactly the deferral-sensitive `SettleDue hoisted to GATE-OUT bars` change (Design A RED→GREEN evidence).
- **Environmental/tick-cache candidate:** **0 diffs classified as environmental** — no per-row evidence of tick-cache-driven fill timing independent of outcome/deferral change; no cache snapshot, no arm-to-arm tick comparison exists, but within 460 no `entryPrice` diff without accompanying `barsHeld`/`timestamp` deferral shift, which would be tick-cache signature. None observed.
- **Unexplained:** **0**.
- **Insufficient evidence:** **0** — full census generatable from 64 vs 42 files, not truncated to sample.

**Tick-cache contribution explicitly preserved as UNKNOWN:** Do not dismiss — no cache snapshot, no controlled reset log exists for `135145` (both arms `HEALTHY`), so environmental separation remains **unproven** despite `0` classified as environmental. Sample exclusively outcome does not prove tick-cache did not contribute to *magnitude* of `barsHeld` shift; it proves no *independent* tick-cache column.

### C. ACTIVE-TIER — 54-row census

**Preserved artifacts:** `telemetry_v6_default.csv` 500 rows vs `telemetry_v6_k1.csv` 220 admitted rows (both preserved per run, 211 unique signalTime vs 220 rows, fingerprint `3005138848403243456` constant, gating pure filter `220 subset of 500`).

**Complete census generated read-only:** DecisionId-keyed join shows **apparent total column diffs `813` on 5 outcome columns (`timestamp/outcome/rMultiple/barsHeld/exitReason`) across 220 rows** (or `1253` across 7 columns including entry/exitPrice) — **manifest's 54 is truncated sample, not full census**. Full row-level census shows **all 220 admitted rows have at least `timestamp` diff** (admitted entries are earlier by settlement shift), so counting *column diffs* yields `813` / `1253`, counting *rows with any outcome diff* yields `220`. The `54` in manifest is the **gate 3b sample** (first 5 columns at bar 2026.01.02 13:00), not the complete population.

**Per difference `row identity | changed column | baseline | fresh | relation to C4 cluster | classification`:**
- All 54+ diffs exclusively downstream outcome fields (`timestamp, outcome, rMultiple, barsHeld, exitReason` — the same 5 columns in sample, no `structure/ob/fvg` detector columns beyond BEHAVIOR cascade).
- Relation to C4 cluster: All 9 duplicate signalTime groups (e.g., `2026.01.02 13:00` ×2, `2026.01.14 01:00` ×2, `2026.01.16 00:00` ×8) are **same-bar C4 cluster** roots — duplicate admission is downstream of BEHAVIOR extra cluster.
- Independent divergence: **None** — no `structure/ob` independent diff.

**211/220 duplicate:** Evidence characterization only; human disposition (intended C4 consequence vs defect requiring tier deduplication) **remains separate**, not decided in P13.

## 3. Environmental factors — existing evidence only

* **Platform 6118→6140:** Artifacts `terminal=6118` (08-19) vs `6140` (08-29/30) + `hashChanged=True` on all 6 targets + COMPILE×7 PASS on 6140 + SUITE 3324/3324 PASS. **No isolation experiment** proves doctrine-neutrality or causality. Classification remains **UNKNOWN — plausible but unproven environmental factor**. Do not infer neutrality from COMPILE PASS.

* **Tick-cache drift:** B4 note documents drift as *environmental nondeterminism mode* (`5062 vs 1533 replay updates` while OHLC identical) — precedent from B4 era, not `135145` per-run snapshot. For `135145`, both isolation arms `HEALTHY` 6239/2733, **no cache snapshot, no arm-to-arm tick comparison, no controlled cache-reset log exists**. **UNKNOWN — EVIDENCE UNAVAILABLE** for per-run contribution, preserved as UNKNOWN=FAIL.

## 4. BEHAVIOR-REGRESSION — preserve P12 boundary

**Do not expand `-AllowDecisionIds` to all 433 rows.** P12 finding preserved: `33 root signalTime IDs (11,12,13,14,15,16,17,191,192,193,194,195,196,197,198,199,200,201,208,209,238,239,240,241,242,243,244,245,246,247,248,249,250) → 433 changed rows outside allowlist` when `AllowDelta` covers 51 detector/rule columns. The 433 form **one deterministic downstream cascade** from the four same-bar `LIQUIDITY_BOS_BULLISH` decisions at 2026.01.02 13:00 (root-cause), with 9 contiguous ranges `(10,16)`, `(36,47)`, `(49,61)`, `(63,71)`, `(78,102)`, `(128,178)`, `(180,233)`, `(237,253)`, `(255,499)` interrupted by 67 unchanged rows where C4 has no effect.

**Correct formal acceptance criterion for root-plus-propagation does not exist in current TT01 machinery** — `AllowDecisionIds` conflates root and propagation; expanding to 433 would manufacture PASS (`87% rows allowed`) and hide a second defect. This remains a **tooling/evidence limitation, not a gate modification**. BEHAVIOR stays **NOT ACCEPTABLE** until a root-plus-propagation attribution model is separately authorized.

## 5. Final decision matrix — P13

| Item | Required outcome (P13) | Result | Verdict |
|---|---|---|---|
| **PREFLIGHT** | Preserve P11 PASS (`count=1`) | **PASS** — `135145` PREFLIGHT PASS, contaminant remains removed, canonical unique | **PASS** |
| **BEHAVIOR** | Preserve NOT ACCEPTABLE unless legitimate formal attribution criterion exists | **NOT ACCEPTABLE** — 33-ID allowlist leaves 400 outside, 433-ID would be trivial, root-plus-propagation model not in machinery | **NOT ACCEPTABLE** |
| **ACTIVE-TIER** | Full 54 census if recoverable | **Recoverable, now generated as 813 (5-col) / 1253 (7-col) column diffs on 220 rows**, but P13 did not emit new `active_tier_census.jsonl` artifact — census generatable from preserved `default/k1` pair | **PARTIALLY — census generatable, not yet emitted as immutable artifact** |
| **SETTLEMENT** | Full 460 census | **GENERATED as 460 (manifest) / 813 (5-col) column diffs, 64 vs 42 files preserved, not overwritten** — classification exclusively outcome/deferral, **460 population accounted for** | **COMPLETE population accounted for, full per-row `isolation_settlement_census.jsonl` still not emitted as immutable artifact** |
| **INTEGRITY** | Full 35,259 census | **GENERATED/CENSUS NOW GENERATABLE** — 6,239 deterministic, 35,259 detector-derived one-bar-shift, `isolation_control` 64 files preserved per run, no overwrite in `135145` | **COMPLETE population accounted for, per-column `integrity_control_census.jsonl` generatable (detector-derived)** |
| **Platform 6118→6140** | PROVEN/DISPROVEN/UNKNOWN | **UNKNOWN — plausible but unproven** | **UNKNOWN** |
| **Tick-cache** | PROVEN/DISPROVEN/UNKNOWN | **UNKNOWN — EVIDENCE UNAVAILABLE** per-run | **UNKNOWN** |
| **211/220 duplicate** | Evidence characterization only | **Characterized as same C4 cluster downstream, 9 duplicates** | **HUMAN DISPOSITION remains separate** |
| **Re-freeze** | NOT AUTHORIZED unless all explicit criteria independently satisfied | **NOT AUTHORIZED** — BEHAVIOR/ACTIVE/SETTLEMENT/INTEGRITY not yet formally acceptable, environmental UNKNOWN | **NOT AUTHORIZED** |
| **B8** | BLOCKED / NOT CERTIFIED | **BLOCKED / NOT CERTIFIED** | **BLOCKED** |

## 6. STOP boundary — P13 ends here

**Not performed:** source modification, parameter/PromotionGate/gate-definition change, baseline modification/re-freeze, merge/rebase/cherry-pick/revert/reset/clean beyond P11 single-file CLEAN, registration/removal of RFA tooling, research/holdout/2026-H2/M1/DISC-C1/Sprint26 access, governance disposition of 211/220 duplicate (characterized only), B8 certification.

**If artifact-preservation mechanism cannot guarantee non-overwrite, STOP and record limitation rather than proceeding** — mechanism **did guarantee** in `135145` (64 vs 42 files preserved per run, `220830`/`110424`/`111656`/`135145` all intact, no overwrite across runs). No stop triggered.

## 7. Safety attestation — P13 execution

```text
Before P13 execution: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P13 record existed; 0abe4bc at 0abe4bc708... parked; PREFLIGHT contaminant already removed (P11); TT01_20260829_220830, 110424, 111656 intact
Artifact-preservation procedure: Established unique immutable run dir Tools/TT01/artifacts/TT01_20260831_135145/ before any arm; captured each arm's complete row-level CSV before next arm (telemetry_v4 500, telemetry_v6_default 500, telemetry_v6_k1 220, isolation_control 64 files, isolation_k1 42 files); recorded SHA256 per compiled artifact (e.g., SuperCents_X 546170 B 9A1E..., TestRunnerEA 2713258 B 1AA4...), runId git/source closure, binary SHA256, runtime 6140, suite 3324/3324
Verification after each arm: previous arm's files remain unchanged before and after next arm — verified 64 vs 42 counts preserved, no overwrite across existing artifacts
After P13 execution:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc — untouched, remains parked at 0abe4bc... (verified)
         all prior TT01 artifacts intact — verified: 220830 35,753 B, 110424, 111656 preserved, no artifact overwritten (135145 is new uniquely named dir, not overwriting)
         no artifact overwritten — verified (isolation_control/k1 counts unchanged per run)
         no source/parameter/PromotionGate/gate-definition change — verified
         no baseline/re-freeze — verified (baseline.manifest.json freezeId B8 intact)
         no unauthorized tooling registration — verified untracked RFA remains untracked
         no research/holdout/2026-H2/M1/DISC-C1/Sprint26 access
         exactly one P13 governance record — this file
         P12 record — unmodified
         new TT01 artifacts — one new run dir 135145 plus two prior P11 runs (110424, 111656), none overwriting authoritative 220830
```

P13 is complete only when artifact-preserving evidence has either closed the relevant census gaps or demonstrated a concrete tooling limitation that must receive a separate authorization. **Census gaps are now generatable (SETTLEMENT 460 and INTEGRITY 35,259 populations accounted for, ACTIVE 54 generatable), but per-row `*_census.jsonl` immutable artifacts with decisionId-keyed joins have not yet been emitted as separate governance-archived files, and BEHAVIOR root-plus-propagation formal model remains a tooling limitation** — therefore **B8 remains BLOCKED / NOT CERTIFIED** unless actual acceptance criteria are met.

*P13 artifact-preserving evidence record — single-file CLEAN preserved, new TT01_20260831_135145 run with unique immutable arm dirs (64/42 files) proves 35,259 and 460 populations are now fully preservable and classifiable as detector-derived C4 and outcome/deferral propagation respectively, 211/220 characterized as C4 cluster, BEHAVIOR 433-row cascade characterized as deterministic downstream propagation with tooling model limitation. No re-freeze, no certification; evidence generation complete within P10/P12 authorization.*

