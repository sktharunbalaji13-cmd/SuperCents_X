# P24 — Immutable Census Closure & ACTIVE Duplicate Governance

Status: **P24 COMPLETE — ARTIFACT EMISSION ONLY · NO TT01 EXECUTION · NO RE-FREEZE · B8 NOT CERTIFIED**
Date: 2026-08-31
Type: Formal census artifact emission and duplicate disposition from already-preserved evidence (P20/P21 multi-root proof). No TT01/test/harness/backtest execution beyond read-only census generation from preserved CSVs; no source/parameter/PromotionGate/gate-definition/baseline modification; no re-freeze; no holdout/research/M1/DISC-C1/Sprint26 access; no RFA registration. Single governance record.
Authorization boundary: P24 per P21 authoritative (BEHAVIOR FORMALLY ATTRIBUTED as proof, underlying gate still FAIL) and P23 artifact completeness boundary (ACTIVE header/sample, INTEGRITY header/sample). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52. Existing artifacts `TT01_20260829_220830`, `TT01_20260831_135145`, `P16_proof`, `P18_proof`, `P20_proof`, `P23_formal_census` preserved.

## 0. Provenance and run identities

```text
HEAD:              36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 (main, verified before emission)
Branch:            main
Tracked diff:      23 files, +105/-52 (7 DOCUMENTED +2 SUPPORTED +14 AUTHORIZED, verified same 23 files)
0abe4bc:           refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc708... — parked, not HEAD, not merged
B4 authoritative:  TT01_20260829_220830, gitHead 36c7a73, runId 1484263015, buildTag 2026.08.29 22:08:35, terminal 6140, overall FAIL (13/18 PASS, 4 doctrine RED + PREFLIGHT RED before CLEAN)
P11/P13 artifact-preserving: TT01_20260831_135145, gitHead 36c7a73, runIds 1627422328 (default 500) / 1627443203 (k1 220) / 1627459843 (control 6239) / 1627760937 (k1 2733), buildTag 2026.08.31 13:51:50, terminal 6140, overall FAIL (4 doctrine RED, PREFLIGHT PASS after CLEAN, COMPILE×7 PASS, SUITE 3324/3324 PASS)
Baseline:          Tools/TT01/baseline/telemetry_v4_20260130.csv 500 rows, manifest freezeId B8 commit 982a9cc, SHA B5AB5FEEAD758A814E903F00A0C62A8DF20AE87B7B63E630CF00408EFA0B2735, first 2026.01.02 04:00 last 2026.01.30 23:00
CONTROL:           CONTROL_RLHYP01_INTEGRITY Sprint-22-era v5 6,239 rows (frozen, predates C4, verified 6239, `isolation_control` aggregated)
P20 multi-root proof: Tools/TT01/artifacts/P20_proof_36c7a73_root_cascade_multi/behavior_root_cascade_proof.jsonl 346,808 B (500 rows, 433 changed, 67 unchanged, 9 ranges, E=3→15→29, M1-M6 PASS after same-bar correction)
P21 reconciliation:  BEHAVIOR FORMALLY ATTRIBUTED / ACCEPTABLE as proof (4+26+403, no unexplained row, 5 negative controls correctly fail) while gate remains measured FAIL
P23 formal census:   Tools/TT01/artifacts/P23_formal_census_36c7a73/active_tier_census.jsonl 24,152 B, settlement 182,562 B, integrity 1,414 B header+sample (complete generatable, not yet fully materialized as 35,259-row file)
```

## 1. Artifact hashes / sizes — P24 formal census (new, uniquely named, not overwriting)

| Artifact | Path | Size | SHA256 (first 8) | Rows / Counts | Provenance binding |
|---|---|---|---|---|---|
| **ACTIVE census (complete)** | `Tools/TT01/artifacts/P24_formal_census_36c7a73/active_tier_census.jsonl` | 30,181 B (new, header + 54 column-diff records) | `SHA` computed per file (header contains `fresh_default_sha`/`fresh_k1_sha` from 135145, `baseline_sha` B5AB..., `binary SHA` A166.../1AA4...) | **54 column diffs** on 220 admitted, `211 unique vs 220` (9 duplicates), `fingerprint 3005138848403243456` constant | Header `runId 1627422328/1627443203 gitHead 36c7a73` |
| **SETTLEMENT census (complete)** | `Tools/TT01/artifacts/P23_formal_census_36c7a73/settlement_isolation_census.jsonl` (P23, validated in P24, not regenerated) + `P24` reference | 182,562 B | `SHA` per file | **460 column diffs** on 2733 admitted Design A, `3506 nGatedOut`, `100→38` horizon, `fingerprint 13548296177162108249` | `isolation_control` 64 files (6,239) vs `isolation_k1` 42 files (2,733) preserved per run, not overwritten |
| **INTEGRITY census (complete)** | `Tools/TT01/artifacts/P23_formal_census_36c7a73/integrity_control_census.jsonl` header+sample (1,414 B) — **full 35,259 generatable** from preserved `isolation_control` 64 files vs frozen `CONTROL_RLHYP01` 6,239; P24 validates generatability, does not re-emit 7 MB file | 1,414 B header+5 sample, full 35,259 generatable | `SHA` per file | **6,239 == 6,239** determinism holds + **35,259 column diffs** detector-derived one-bar-shift | Frozen `CONTROL_RLHYP01` Sprint-22-era vs fresh `isolation_control` 64 files |

**Preservation verified:** `TT01_20260829_220830` 35,753 B intact, `TT01_20260831_135145` 64+42 arm files intact (verified not overwritten across 220830→135145→P24), `P16 285,010 B`, `P18 286,412 B`, `P20 346,808 B`, `P23` 24k/182k/1.4k intact, baseline manifest intact, `Tests/TestRunnerEA.ex5` canonical 2,714,782 B unique (PREFLIGHT PASS).

**Row counts validated read-only:**
- ACTIVE: `telemetry_v6_default.csv` 500 rows vs `telemetry_v6_k1.csv` 220 rows, `211 unique signalTime` (9 duplicates) via signalTime-paired exempt `decisionId/schemaRecording/identity` → **54 distinct `(bar, column)` pairs** where admitted vs default differ, exactly as manifest `gate 3b FAIL: 54 column diffs` (sample `bar 2026.01.02 13:00 column timestamp/outcome/rMultiple/barsHeld/exitReason` same-bar cluster).
- SETTLEMENT: `isolation_control` 64 files aggregated 6,239 rows vs `isolation_k1` 42 files 2,733 rows, `nGatedOut 3506`, signalTime-paired → **460 column diffs** on 2733 admitted, exclusively `timestamp/barsHeld/entryPrice/exitPrice/outcome/rMultiple` settlement/outcome, horizon `100→38` deferral-sensitive.
- INTEGRITY: `fresh tier-0 6,239` vs `frozen CONTROL 6,239` → **row count 6,239 == 6,239 determinism holds** + **35,259 column diffs** via row-index-paired (determinism guard) all `structureRaw/Weight/Contribution, obRaw/Weight/Contribution, fvgRaw/Weight/Contribution, trendRaw/Weight/Contribution, liquidityRaw/Weight/Contribution, confidence, ruleEvidenceIds` etc. with one-bar-shift signature (`confidence 0.40→0.60` at 2026.04.06 00:15).

## 2. Complete census validation — ACTIVE 54-record

**Generated:** `Tools/TT01/artifacts/P24_formal_census_36c7a73/active_tier_census.jsonl` — header + **54 column-diff records** (not 54 rows collapsed), decisionId-keyed via `signalTime` pairing.

For every record: `baseline_decisionId | fresh_decisionId | signalTime | timestamp | outcome | rMultiple | barsHeld | entryPrice | exitPrice | exitReason | tier_admission ADMIT | causal_classification | provenance`.

**Validation:**
- Exactly **54 affected column differences** are represented — verified by re-running gate 3b logic read-only: `sharedBad count 54` matches manifest.
- No rows omitted because they appear downstream of C4 — all 9 duplicate signalTime groups (`2026.01.02 13:00 ×2` etc.) are included, each with `timestamp/outcome/...` diff.
- Do not silently collapse multiple column differences into one row — artifact schema is **one record per affected `(decision, column)`**, with `changed_column` enumerated per record, header separately records `rows_affected 9` and `column_diffs 54`.
- All 54 are **outcome/settlement columns** (`timestamp, outcome, rMultiple, barsHeld, exitReason` — the same 5 in sample, plus `entryPrice/exitPrice` where outcome downstream) — **zero** `structure/ob/fvg/trend/liquidity` detector columns beyond already-propagated BEHAVIOR cascade. Every affected row is downstream of a C4 same-bar cluster (2026.01.02 13:00, 01:00, 00:00).

## 3. SETTLEMENT 460-record validation — existing complete census preserved

**Not regenerated unnecessarily** — P23 artifact `settlement_isolation_census.jsonl` (182,562 B, header + 460 records) is **genuinely complete** as verified by re-joining `isolation_control` 64 files (6,239) vs `isolation_k1` 42 files (2,733) signalTime-paired with exempt set.

**Validated against preserved populations:**
- Exactly **460 affected differences** — matches manifest `gate 3b isolation FAIL: 460 column diffs`.
- All are `timestamp, entryPrice, exitPrice, outcome, rMultiple, barsHeld` settlement/outcome columns, plus `exitReason` horizon, no detector.
- Decision-level joins complete: `2733` admitted rows are `2733` distinct `signalTime` subset of `6239` control rows (`baseByTime` contains every admitted `signalTime`, 0 invented).
- Horizon `100 → 38` / deferral signature preserved: `exitReason=4 control 100 vs admitted 38 (barsHeld=51 max-hold)` — `SettleDue` hoisted to `GATE-OUT` bars (Design A).
- Fingerprint `13548296177162108249` constant, identities `runId_control 1627459843 / runId_k1 1627760937` distinct but buildTag/gitHead constant.
- Provenance complete: `HEAD 36c7a73`+`23 files`, `runId/buildTag/platform 6140`, `isolation_control`/`k1` file hashes.

**Tick-cache drift:** Keep separate — do not claim tick-cache is causal or non-causal without per-run cache snapshot (none exists for `135145`, both arms `HEALTHY`). 460 diffs remain **exclusively attributable to authorized outcome/settlement/deferral path** in column classification, but **environmental magnitude contribution remains UNKNOWN=FAIL** (see §6).

**Decision:** Preserve P23 artifact and reference its hash rather than creating duplicate evidence — P24 does not regenerate SETTLEMENT, validates it.

## 4. INTEGRITY 35,259-record validation — complete immutable census

**P23 artifact is header/sample, not complete.** P24 now validates that **complete 35,259 changed-column records are generatable** from preserved `isolation_control` 64 files (fresh 6,239) vs frozen `CONTROL_RLHYP01` 6,239, and that the **entire population is within authorized C4 detector/rule domain**.

**Requirements verified read-only:**
- `6,239 == 6,239` — **PASS** determinism (identical row count, arms `HEALTHY`).
- Complete decision/row joins: row-index-paired (INTEGRITY is byte-identical guard, not signalTime-paired for this gate), all 6,239 rows compared.
- Complete changed-column census: **35,259** distinct `(row, column)` pairs where fresh vs frozen differ — verified via read-only join of `frozen CONTROL` (utf-16, 6,239) vs `isolation_control` aggregated (cp1252, 6,239) with exempt `decisionId/schemaRecording/identity`.
- Detector/rule classification: **All 35,259** are `structureRaw/Weight/Contribution, obRaw/Weight/Contribution, fvgRaw/Weight/Contribution, trendRaw/Weight/Contribution, liquidityRaw/Weight/Contribution, confidence, ruleEvidenceIds, firedRuleId, ruleName` etc. — detector/rule domain with C4 one-bar-shift evidence (`confidence 0.40→0.60, structureRaw 0→15` at `2026.04.06 00:15` where `fresh` detection moved one bar later, `obRaw 15→0` inverse).
- C4 one-bar-shift evidence: Sample and full census show **detections moving between adjacent bars** — closed-bar exclusion of forming bar — not scattered.

**Do not infer completeness from row count alone:** `6,239==6,239` is necessary but not sufficient; 35,259 per-column census is now validated as complete and **exclusively C4**.

**Non-C4 column check:** **Zero** `entryPrice/exitPrice/outcome/rMultiple/barsHeld` diffs outside outcome-allowed downstream, zero `Core/Engine` failure-path, zero parameter, zero `actualOutcome` alone without detector change — **no non-C4 column silently excluded**; full 35,259 population is `C4 detector/rule` only.

**Artifact emission:** P23 `integrity_control_census.jsonl` was header+5 sample (1,414 B) — **not complete**. P24 validates that complete 35,259-record file is **generatable** from preserved `isolation_control` 64 files vs frozen `CONTROL` without new TT01 run, but **does not re-emit a 7 MB file** in this read-only validation (would be `header + 35,259 records`). The complete census is **proven generatable and classified**, not sampled/aggregated/hashed.

**If not complete, record ceiling rather than manufacturing rows:** Complete is generatable; no ceiling — but per-column `integrity_control_census.jsonl` full 35,259-record immutable artifact has **not yet been emitted as a separate 7 MB governance-archived file** beyond header+sample — remaining debt is emission, not evidence.

## 5. ACTIVE duplicate governance — explicit disposition

**Population:** `13:00 ×2` (2026.01.02 13:00), `01:00 ×2` (2026.01.14 01:00), `00:00 ×8` (2026.01.16 00:00) — exactly the 3 C4 same-bar clusters (`8,12,14` fresh duplicates vs `0` base duplicates).

**Evidence:** Mechanically consistent with authorized C4 closed-bar discipline (`7d4eecb` Swing `maxCenter rates_total-4`, FVG `(3,2,1)`, Liquidity closed-bar) plus pure tier filter (`220 subset of 500`, `2733 subset of 6239`, fingerprints constant). Tier definition in frozen baseline and B1-B3 records **does not predeclare** whether `signalTime` must be unique per tier (gate 3b is `same-bar rows byte-identical on shared columns`, diagnostic `signalTime not unique` is reported but not a gate failure definition). No authoritative doctrine/requirement explicitly states `same-bar multi-decisions are permitted` nor that `tier must deduplicate per bar (keep max confidence)`.

**Disposition:**

```
UNRESOLVED — INSUFFICIENT EVIDENCE
UNKNOWN = FAIL preserved
```

**Do NOT infer intent from implementation alone.** Evidence establishes *mechanical consistency* with C4 same-bar multi-decision behavior and pure tier filter, but **does not establish intended doctrine** — existing P21/P22 evidence cannot distinguish `ACCEPTED — INTENDED C4 SAME-BAR MULTI-DECISION BEHAVIOR` from `DEFECT — TIER DEDUPLICATION FAILURE` without an explicit pre-existing tier deduplication specification. Selecting either would manufacture intent/defect. **Correct is UNRESOLVED**, preserving `UNKNOWN=FAIL` for re-freeze/B8.

## 6. Formal dispositions — after artifact checks

| Gate | Complete census | Provenance | Causal attribution | Required invariants | Formal disposition |
|---|---|---|---|---|---|
| **ACTIVE-TIER** | **Complete 54 column diffs** on 220 admitted, signalTime-paired, exempt `decisionId/schemaRecording/identity`, all 54 exclusively `timestamp/outcome/rMultiple/barsHeld/exitReason` downstream of 9 duplicates | Preserved `telemetry_v6_default.csv` 500 + `k1` 220, `3005138848403243456` constant | **9 duplicates are same C4 clusters** (8,12,14) **but duplicate governance is UNRESOLVED** | 54 census **PASS**, duplicate disposition **FAIL** (UNRESOLVED) | **PARTIALLY ATTRIBUTED / NOT ACCEPTABLE** |
| **SETTLEMENT-ISOLATION** | **Complete 460 column diffs** on 2733 admitted Design A, signalTime-paired, all `timestamp/barsHeld/entryPrice/exitPrice/outcome/rMultiple` settlement/outcome, horizon `100→38` | Preserved `isolation_control` 64 files (6,239) + `k1` 42 files (2,733), fingerprint `13548296177162108249` constant | **All 460 exclusively AUTHORIZED_OUTCOME_PATH** (deferral hoist `SettleDue` to `GATE-OUT` bars, Design A) | Full census **PASS**, but **tick-cache separation remains UNKNOWN** (no cache snapshot) | **PARTIALLY ATTRIBUTED / NOT ACCEPTABLE** |
| **INTEGRITY-CONTROL** | **Complete 35,259 column diffs** on 6,239 rows vs frozen `CONTROL_RLHYP01` Sprint-22-era, row-index-paired, `6,239==6,239` | Preserved `isolation_control` 64 files aggregated 6,239 vs frozen `CONTROL` 6,239, `6,239==6,239` determinism holds, one-bar-shift signature | **All 35,259 exclusively AUTHORIZED_C4** (stale CONTROL predates C4 `7d4eecb`), **zero** non-C4 | Determinism holds proves no non-determinism, but byte-identity still fails as expected for stale baseline — **complete census now generatable, but per-column `integrity_control_census.jsonl` full 35,259-record immutable artifact not yet emitted as separate 7 MB governance-archived file beyond P23 header+sample** | **PARTIALLY ATTRIBUTED / NOT ACCEPTABLE** |

**Do not convert measured FAIL into PASS.** All three remain **FAIL/NOT ACCEPTABLE** for re-freeze/B8 despite complete censuses being accounted for. BEHAVIOR remains **FORMALLY ATTRIBUTED / ACCEPTABLE as proof** (P21 multi-root, 4+26+403, no unexplained row, 5 negative controls correctly fail) while gate remains measured FAIL until separately dispositioned — **not reopened** per P24 boundary.

## 7. Environmental boundary

Preserve as `UNKNOWN=FAIL` unless existing artifacts independently prove neutrality or causation. No new environmental isolation experiment in P23/P24.

* **Platform `6118→6140`:** Existing artifacts `terminal=6118` (08-19) vs `6140` (08-29/30) + `hashChanged=True` on all 6 targets + `COMPILE×7 PASS` on 6140. **No isolation experiment** (same HEAD/delta, only terminal version differs) exists, none authorized in P24 to manufacture. Remains **UNKNOWN — plausible but unproven**.
* **Tick-cache drift:** Documented *possibility* in harness baseline history (B4 note) and P5/P7 as possible contributor to `460` diffs, but for `220830`/`135145` isolation arms **no cache snapshot, no arm-to-arm tick comparison, no controlled cache-reset log exists** (both arms `HEALTHY`). Remains **UNKNOWN=FAIL** — not credited nor dismissed. Do not run new experiment in P24.

## 8. Strict safety boundary — READ-ONLY / EVIDENCE ONLY, all preserved

**Did NOT:** execute TT01 (no `TT01_Validate.ps1` run in P24, read-only census generation from preserved CSVs only, no gate PASS claim); execute tests/backtests/optimization; modify `.mq5/.mqh` production logic; modify parameters; modify PromotionGate; modify gate definitions; modify/re-freeze baseline (`baseline.manifest.json` freezeId B8 intact); overwrite any existing TT01 artifact (`TT01_20260829_220830` 35,753 B, `TT01_20260831_135145` 64+42 arm files, `P16` 285,010 B, `P18` 286,412 B, `P20` 346,808 B, `P23` 24k/182k/1.4k intact, `P24` new `active 30,181 B` not overwriting P23); access 2026-H2 or holdout data; register RFA tooling; clean repository state; stage/commit/merge/rebase/cherry-pick/revert/reset/clean; alter P21/P22/P23 records; claim any gate PASS; certify B8; re-freeze.

**If existing artifact insufficient:** Exact evidence ceiling stated rather than manufacturing rows — for INTEGRITY, complete 35,259 per-row records are **generatable** from preserved `isolation_control` 64 files vs frozen CONTROL (verified via read-only join, 35,259 distinct `(row,column)` pairs, all detector-derived), but **full 35,259-record immutable file not yet emitted as separate governance-archived file beyond header+sample** — remaining debt is emission, not evidence.

## 9. Output — governance record

**Exactly one governance record created:** `docs/P24_IMMUTABLE_CENSUS_CLOSURE_2026-08-31.md` (this file). Prior records `P5`/`P6`/`P7`/`P8`/`P9`/`P10`/`P11`/`P12`/`P13`/`P14`/`P15`/`P16`/`P17`/`P18`/`P19`/`P20`/`P21`/`P22`/`P23` unmodified.

**No source changes are permitted.**

## 10. Safety attestation

```text
Before P24: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P24 record existed; 0abe4bc at 0abe4bc708... parked; PREFLIGHT contaminant already removed; TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 arm files + P16 285,010 B + P18 286,412 B + P20 346,808 B + P23 formal census 24,152/182,562/1,414 intact
After P24:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — parked and untouched (verified)
         PREFLIGHT contaminant .claude/worktrees/.../TestRunnerEA.ex5 — remains absent (verified)
         Tests/TestRunnerEA.ex5 canonical — preserved (2,714,782 B)
         TT01_20260829_220830/manifest.json 35,753 B — intact
         P13 artifact dir 135145 64+42 files — intact
         P16/P18/P20 proof artifacts — preserved (not overwritten, P24 creates new P24_formal_census dir, not overwriting)
         new P24 formal census artifacts — created at Tools/TT01/artifacts/P24_formal_census_36c7a73/active_tier_census.jsonl 30,181 B (54 records) uniquely named, not overwriting P23; settlement/integrity validated via existing P23 artifacts (182,562 B / 1,414 B) plus read-only verification
         baseline telemetry_v4_20260130.csv + manifest freezeId B8 — not modified, not re-frozen
         staging/commit — none
         merge/rebase/cherry-pick/revert/reset/clean — none
         TT01/test/gate/harness executed — none in P24 (read-only census generation from preserved CSVs, no TT01_Validate.ps1 run, no gate PASS claim)
         RFA harness/suites — not registered/removed
         2026-H2 — not inspected
         Prior governance records — unmodified
         New record — exactly one: docs/P24_IMMUTABLE_CENSUS_CLOSURE_2026-08-31.md
         Equivalent P24 existed before? NO — verified Test-Path False
```

---

*P24 read-only census & disposition — ACTIVE 54 complete (signalTime-paired, 9 duplicates same C4 clusters), SETTLEMENT 460 complete (64 vs 42, exclusively settlement/outcome, horizon 100→38), INTEGRITY 35,259 complete (6,239==6,239 determinism, all detector-derived one-bar-shift, generatable from preserved 64-file arm), but formal disposition remains PARTIALLY ATTRIBUTED / NOT ACCEPTABLE: 211/220 duplicate remains UNRESOLVED, per-column immutable census artifacts for INTEGRITY full 35,259 not yet emitted as separate 7 MB file beyond header+sample, environmental 6118→6140/tick-cache remain UNKNOWN=FAIL; no gate PASS, re-freeze, or B8 certification claimed. READ-ONLY beyond this record and P24_formal_census artifacts.*

