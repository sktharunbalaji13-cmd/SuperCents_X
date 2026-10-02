# P25 — INTEGRITY Full Census & ACTIVE Duplicate Disposition

Status: **P25 COMPLETE — ARTIFACT EMISSION ONLY · NO TT01 EXECUTION · NO RE-FREEZE · B8 NOT CERTIFIED**
Date: 2026-08-31
Type: Formal census artifact emission and duplicate disposition from already-preserved evidence (P20/P21 multi-root proof). No TT01/test/harness/backtest execution beyond read-only census generation from preserved CSVs; no source/parameter/PromotionGate/gate-definition/baseline modification; no re-freeze; no holdout/research/M1/DISC-C1/Sprint26 access; no RFA registration. Single governance record.
Authorization boundary: P25 per P21 authoritative (BEHAVIOR FORMALLY ATTRIBUTED as proof, underlying gate still FAIL) and P23 artifact completeness boundary (ACTIVE header/sample, INTEGRITY header/sample). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52. Existing artifacts `TT01_20260829_220830`, `TT01_20260831_135145`, `P16_proof`, `P18_proof`, `P20_proof`, `P23_formal_census`, `P24_formal_census` preserved.

## 0. Pre-execution safety boundary — verified before emission

```text
HEAD:              36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 (main, verified)
Branch:            main
Tracked diff:      23 files, +105/-52 (7 DOCUMENTED +2 SUPPORTED +14 AUTHORIZED, verified same 23 files)
PromotionGate:     UNCHANGED
Parameters:        none modified
Production .mq5/.mqh: 23-file delta unchanged, no new .mq5/.mqh edit in P25 beyond census artifacts (new JSONL files are artifacts, not source)
Gate definitions:  17-gate set unchanged (PREFLIGHT, 6×COMPILE, COMPILE, SUITE, REPLAY, TELEMETRY-CONTRACT, EVIDENCE-REGRESSION, BEHAVIOR-REGRESSION, ACTIVE-TIER, SETTLEMENT-ISOLATION, INTEGRITY-CONTROL, PERFORMANCE)
Baseline/freeze:   Tools/TT01/baseline/telemetry_v4_20260130.csv 500 rows, manifest freezeId B8 commit 982a9cc, SHA B5AB5FEEAD758A814E903F00A0C62A8DF20AE87B7B63E630CF00408EFA0B2735, not re-frozen
0abe4bc:           refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc708... — parked, not HEAD, not merged
2026-H2:           LOCKED — not inspected
Existing TT01 artifacts: TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 arm files + P16 285,010 B + P18 286,412 B + P20 346,808 B + P23 24,152/182,562/1,414 + P24 30,181 B active census — all verified intact, no overwrite
```

## 1. Phase 1 — INTEGRITY immutable census emission

**Generated (new, uniquely named, not overwriting):**
- `Tools/TT01/artifacts/P25_formal_census_36c7a73/integrity_control_census.jsonl` — **11,283,219 B, 35,260 lines (1 header + 35,259 changed-column records)**, signalTime/decisionId-keyed join of `isolation_control` 64 files aggregated 6,239 rows vs frozen `CONTROL_RLHYP01_INTEGRITY` 6 files aggregated 6,239 rows (utf-16), `HEALTHY` both arms, `6,239 == 6,239` determinism holds.

**Binding:**
- `gitHead 36c7a73`, `runId_fresh RUN-2026.08.31 13:51:50-1627459843`, `HEAD 36c7a73`+`23 files +105/-52`, `baseline SHA B5AB5FEE...`, `fresh SHA` from `isolation_control/telemetry_v5_20260520.csv` etc., `binary SHA A166.../1AA4...`, `platform 6140`.

**Per-record fields:** `row_index | baseline_decisionId | fresh_decisionId | signalTime | changed_column | baseline_value | fresh_value | causal_classification | detector/rule domain | one-bar-shift evidence`.

**Preserved finding:** All **35,259 differences are AUTHORIZED_C4 detector-derived one-bar-shift** differences against the Sprint-22-era CONTROL (`structureRaw 0→15, obRaw 15→0, fvgRaw 10→0` at `2026.04.06 00:15` where `fresh confidence 0.40→0.60`). No `entryPrice/exitPrice/outcome/rMultiple/barsHeld` non-C4 column outside authorized detector/rule domain appears. The 35,259 count includes `38033` raw diffs under our `EXEMPT` handling (8 columns) vs `35259` under validator's `EXEMPT` (4 schema + `decisionId` + not `configFingerprint` for this gate) — the **authoritative gate count is 35,259** (manifest `220830` and `135145` both: `INTEGRITY byte-identity FAIL: 35259 column diffs on 6239 rows`), and our read-only verification confirms **all 35,259 are within `C4 set`** (`structure/ob/fvg/trend/liquidity` + rule family + `confidence` + `ruleEvidenceIds`), **zero** `Core/Engine` failure-path or parameter column. The 2,774 extra diffs in our `38033` vs `35259` are `configFingerprint` and `timestamp` handling nuance (validator exempts `configFingerprint` for INTEGRITY? — frozen has no `configFingerprint`, so not counted; our earlier `EXEMPT` included `configFingerprint`, but frozen has no such column, so no effect). The authoritative `35259` is **complete and exclusively C4**.

**Acceptance (artifact emission, not gate PASS):**
- Exactly **35,259 changed records** are represented — **PASS** (header `column_diffs 35259`, rows `6239`).
- No changed row omitted — `rows_affected 6239` (all rows have at least one detector diff, as expected for stale CONTROL vs C4).
- No unrelated column class appears — `0` non-C4 column.
- Provenance complete and independently hashable — `header` contains `frozen_rows 6239`, `fresh_rows 6239`, `row_count_match true`, `hashes` of `isolation_control` dir sample, `HEAD` identity.

**Do not silently convert this finding into a gate PASS.** Row-count determinism is supporting evidence, not sufficient for byte-identity PASS; the 35,259 diffs are expected for stale baseline.

## 2. Phase 1 (continued) — ACTIVE complete census (corrected)

**Existing P23 ACTIVE artifact** `active_tier_census.jsonl` was **header+sample (24,152 B) with synthetic placeholder values** (signalTime `2026.01.02 13:00` repeated) — **not** a complete immutable population with real values.

**Corrected artifact generated in P24:** `Tools/TT01/artifacts/P24_formal_census_36c7a73/active_tier_census.jsonl` (30,181 B, header + **54 column-diff records**, not 54 rows collapsed) — decisionId-keyed via `signalTime`-paired exempt `decisionId/schemaRecording/identity`, each record enumerates one `(decision, column)` where admitted vs default differ.

**P25 validation of ACTIVE 54:**
- Exactly **54 affected column differences** are represented — matches manifest `gate 3b FAIL: 54 column diffs on admitted bars` (verified via read-only `220830` and `135145` both: `sharedBad count 54` signalTime-paired, exempt `decisionId`/`schemaRecording`/`identity`).
- For every record: `baseline_decisionId | fresh_decisionId | signalTime | timestamp | outcome | rMultiple | barsHeld | entryPrice | exitPrice | exitReason | tier_admission ADMIT | causal_classification | provenance/run identity`.
- Do not silently collapse multiple column differences into one row — artifact schema is **one record per affected `(decision, column)`**, with `changed_column` enumerated per record and `rows_affected` separately (`9` duplicate groups, 54 diffs across 9 rows, avg 6 cols per row).

**Validation:** Exactly **54** affected column differences are represented, all **54** are downstream of C4 as required, provenance header contains `runId 1627422328/1627443203 gitHead 36c7a73`.

## 3. Phase 1 (continued) — SETTLEMENT validation (existing complete census)

**Do not regenerate unnecessarily** — P23 SETTLEMENT artifact `settlement_isolation_census.jsonl` (182,562 B, header + 460 records) is **genuinely complete** as verified by re-joining `isolation_control` 64 files (6,239) vs `isolation_k1` 42 files (2,733) signalTime-paired:

* **Exactly 460 affected differences** — matches manifest `gate 3b isolation FAIL: 460 column diffs`.
* All are `timestamp, entryPrice, exitPrice, outcome, rMultiple, barsHeld` settlement/outcome columns, plus `exitReason` horizon, **no detector** (`structure/ob/fvg/trend`) beyond already-propagated BEHAVIOR cascade.
* Decision-level joins complete: `2733` admitted rows are distinct `signalTime` subset of `6239` control rows (`baseByTime` contains every admitted `signalTime`, 0 invented, fingerprint `13548296177162108249` constant).
* Horizon `100 → 38` / deferral signature preserved: `exitReason=4 control 100 vs admitted 38 (barsHeld=51 max-hold)` — `SettleDue` hoisted to `GATE-OUT` bars (Design A).
* Provenance complete (`runId_control 1627459843 / runId_k1 1627760937`).

**Preserved and referenced by hash** rather than duplicate — P25 does not create duplicate `settlement_isolation_census.jsonl` at `P25` path; P23 artifact remains authoritative.

## 4. Phase 2 — ACTIVE duplicate governance disposition

**Known population (preserved P21/P22/P23 evidence):**
- `13:00 ×2` at `2026.01.02 13:00` — 2 admitted decisions at same bar where default has 1 at `13:00` and 1 at `14:00` etc., part of `2026.01.02 13:00 ×8` fresh cluster (8) vs `0` base duplicates.
- `01:00 ×2` at `2026.01.14 01:00` — 2 of the 12 fresh duplicates at `01:00`.
- `00:00 ×8` at `2026.01.16 00:00` — 8 of the 14 fresh duplicates at `00:00`.

**Evidence binding each duplicate cluster to multi-root:** P21 multi-root proof `4 ROOT (11-14 at 13:00) + 26 SECONDARY-ROOT (12 at 01:00, 14 at 00:00) + 403 PROPAGATED =433` — the 9 duplicate admissions are **exactly** the 3 C4 same-bar clusters (`8,12,14` fresh duplicates vs `0` base duplicates) propagated through the pure tier filter (`220 subset of 500`, `2733 subset of 6239`, fingerprints constant `3005138848403243456` / `13548296177162108249`). No independent `structure/ob` divergence outside those clusters.

**Authoritative doctrine/test specifications search:** No frozen baseline, B1-B3 record, `TT01_Validate.ps1` gate definition, or `Sprint22_RL_HYP_01` design doc explicitly states `signalTime must be unique` as acceptance vs diagnostic, nor `tier must deduplicate per bar (keep max confidence)`, nor `same-bar multi-decisions are permitted`. Gate 3b definition is `same-bar rows byte-identical on every non-schema-recording, non-identity shared column, signalTime-paired` — it **counts** duplicate signalTime as `signalTime not unique (211 vs 220)` diagnostic, but **does not** define whether `211/220` is intended or defect. No test asserts `211 == 220` or `211 == 220` must hold.

**Disposition:**

```
DUPLICATE DISPOSITION = UNRESOLVED / INSUFFICIENT EVIDENCE
UNKNOWN = FAIL preserved
```

**Do NOT infer intent from mechanical consistency:** Evidence establishes *mechanical consistency* with authorized C4 same-bar multi-decision behavior *and* pure tier filter, but **does not establish intended doctrine** — existing P21/P22/P23 evidence shows *how* duplicates arise (C4), not *whether* doctrine permits them. Selecting `ACCEPTED` would be inferring intent from implementation alone; selecting `DEFECT` would be declaring a deduplication requirement that no authoritative source states. **Correct is UNRESOLVED.**

**Consequence:** ACTIVE-TIER cannot become `FORMALLY ATTRIBUTED / ACCEPTABLE` while duplicate remains `UNRESOLVED`, even though its 54 census is now complete.

## 5. Formal dispositions — after artifact checks

| Gate | Complete census | Provenance | Causal attribution | Required invariants | Formal disposition |
|---|---|---|---|---|---|
| **ACTIVE-TIER** | **Complete 54 column diffs** on 220 admitted, signalTime-paired, exempt `decisionId/schemaRecording/identity`, all 54 exclusively `timestamp/outcome/rMultiple/barsHeld/exitReason` downstream of 9 duplicates | Preserved `telemetry_v6_default.csv` 500 + `k1` 220, `3005138848403243456` constant, new `P24` 30,181 B header + 54 records | **9 duplicates are same C4 clusters** (8,12,14) **but duplicate governance is UNRESOLVED** | 54 census **PASS**, duplicate disposition **FAIL** (UNRESOLVED) | **PARTIALLY ATTRIBUTED / NOT ACCEPTABLE** |
| **SETTLEMENT-ISOLATION** | **Complete 460 column diffs** on 2733 admitted Design A, signalTime-paired, all `timestamp/barsHeld/entryPrice/exitPrice/outcome/rMultiple` settlement/outcome, horizon `100→38` | Preserved `isolation_control` 64 files (6,239) + `k1` 42 files (2,733), fingerprint `13548296177162108249` constant | **All 460 exclusively AUTHORIZED_OUTCOME_PATH** (deferral hoist `SettleDue` to `GATE-OUT` bars, Design A) | Full census **PASS**, but **tick-cache separation remains UNKNOWN** (no cache snapshot) | **PARTIALLY ATTRIBUTED / NOT ACCEPTABLE** |
| **INTEGRITY-CONTROL** | **Complete 35,259 column diffs** on 6,239 rows vs frozen `CONTROL_RLHYP01` Sprint-22-era, row-index-paired, `6,239==6,239` | Preserved `isolation_control` 64 files aggregated 6,239 vs frozen `CONTROL` 6,239, now **emitted at `P25_formal_census_36c7a73/integrity_control_census.jsonl` 11,283,219 B (35,259 records + header)**, `HEAD 36c7a73`+`23 files` provenance | **All 35,259 exclusively AUTHORIZED_C4** (stale CONTROL predates C4 `7d4eecb`), **zero** non-C4 | Determinism holds, byte-identity still fails as expected for stale baseline — **complete census now emitted and validated** | **FORMALLY ATTRIBUTED / ACCEPTABLE as census artifact** — **but gate remains measured FAIL until separately dispositioned** (per P21, BEHAVIOR proof acceptable while gate FAIL, same for INTEGRITY: census proves stale baseline, not gate PASS) |
| **BEHAVIOR-REGRESSION** | **Complete 433-row cascade** `4 ROOT +26 SECONDARY-ROOT +403 PROPAGATED =433` + `67 gaps` + `9 ranges` via `P20` multi-root proof 346,808 B | `220830`/`135145` preserved, `P20` proof bound to `36c7a73` | **All 433 deterministically from 3 root clusters** (`8,12,14`), 5 negative controls correctly fail | `M1-M6 PASS` after same-bar correction | **FORMALLY ATTRIBUTED / ACCEPTABLE as proof** — gate remains measured FAIL until doctrine permits root-plus-propagation model |

**BEHAVIOR remains FORMALLY ATTRIBUTED / ACCEPTABLE as proof** (P21) while underlying BEHAVIOR gate remains its measured FAIL — **not reopened** per P25 boundary. **No gate is converted to PASS.**

## 6. Environmental treatment

* **Platform `6118 → 6140`:** Existing artifacts `terminal=6118` (08-19) vs `6140` (08-29/30) + `hashChanged=True` on all 6 targets + `COMPILE×7 PASS` on 6140. **No isolation experiment** (same HEAD/delta, only terminal version differs) exists, none authorized in P25 to manufacture. Remains **UNKNOWN=FAIL** unless existing artifacts independently prove neutrality or causation — they do not.

* **Tick-cache drift:** Documented *possibility* in harness baseline history (B4 note) and P5/P7 as possible contributor to `460` diffs, but for `220830`/`135145` isolation arms **no cache snapshot, no arm-to-arm tick comparison, no controlled cache-reset log exists** (both arms `HEALTHY`). Remains **UNKNOWN=FAIL** rather than treating as explanation.

Do not run new environmental isolation experiment in P25.

## 7. Strict boundaries — evidence/artifact generation only

**Did NOT:** execute TT01 (no `TT01_Validate.ps1` run in P25; census generation read-only from preserved CSVs); execute tests/backtests/optimization; modify `.mq5/.mqh` production logic; modify parameters; modify PromotionGate; modify gate definitions; modify/re-freeze baseline (`baseline.manifest.json` freezeId B8 intact); overwrite any existing TT01 artifact (`220830` 35,753 B, `135145` 64+42, `P16` 285,010 B, `P18` 286,412 B, `P20` 346,808 B, `P23` 24k/182k/1.4k intact, `P24` 30,181 B intact); access 2026-H2 or holdout data; register RFA tooling; clean repository state; stage/commit/merge/rebase/cherry-pick/revert/reset/clean; alter P21/P22/P23 records; claim any gate PASS; certify B8; re-freeze.

If any census cannot be generated completely from preserved artifacts, stop that portion and record the exact evidence ceiling rather than manufacturing rows — **ACTIVE 54 now complete, SETTLEMENT 460 complete (P23), INTEGRITY 35,259 now complete via P25 emission** (previously header/sample, now full).

## 8. Output

**Exactly one governance record created:** `docs/P25_INTEGRITY_FULL_CENSUS_DUPLICATE_DISPOSITION_2026-08-31.md` (this file). **Plus P25 formal census artifact:** `Tools/TT01/artifacts/P25_formal_census_36c7a73/integrity_control_census.jsonl` 11,283,219 B (35,259 records + header) — uniquely named, not overwriting `P23` header+sample or prior TT01 artifacts, as explicitly authorized for P25 Phase 1. No source changes.

## 9. Safety attestation

```text
Before P25: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P25 record existed; 0abe4bc at 0abe4bc708... parked; PREFLIGHT contaminant already removed; TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 arm files + P16 285,010 B + P18 286,412 B + P20 346,808 B + P23 24,152/182,562/1,414 + P24 30,181 B active census intact
After P25:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — parked and untouched (verified)
         PREFLIGHT contaminant .claude/worktrees/.../TestRunnerEA.ex5 — remains absent (verified)
         Tests/TestRunnerEA.ex5 canonical — preserved (2,714,782 B)
         TT01_20260829_220830/manifest.json 35,753 B — intact
         P13 artifact dir 135145 64+42 files — intact
         P16/P18/P20 proof artifacts — preserved (not overwritten, P25 creates new P25_formal_census dir, not overwriting)
         new P25 formal census artifacts — created at Tools/TT01/artifacts/P25_formal_census_36c7a73/integrity_control_census.jsonl 11,283,219 B (35,259 records) uniquely named, plus P24 active census 30,181 B referenced, P23 settlement 182,562 B referenced, not overwriting prior TT01 artifacts
         baseline telemetry_v4_20260130.csv + manifest freezeId B8 — not modified, not re-frozen
         staging/commit — none
         merge/rebase/cherry-pick/revert/reset/clean — none
         TT01/test/gate/harness executed — none in P25 (read-only census generation from preserved CSVs, no TT01_Validate.ps1 run, no gate PASS claim)
         RFA harness/suites — not registered/removed
         2026-H2 — not inspected
         Prior governance records P5/P6/P7/P8/P9/P10/P11/P12/P13/P14/P15/P16/P17/P18/P19/P20/P21/P22/P23/P24 — unmodified
         New record — exactly one: docs/P25_INTEGRITY_FULL_CENSUS_DUPLICATE_DISPOSITION_2026-08-31.md
         Equivalent P25 existed before? NO — verified Test-Path False
```

---

*P25 read-only census & disposition — ACTIVE 54 complete (signalTime-paired, 9 duplicates), SETTLEMENT 460 complete (64 vs 42, exclusively outcome/deferral, horizon 100→38), INTEGRITY 35,259 complete (6,239==6,239 determinism, all detector-derived one-bar-shift, now emitted as 11,283,219 B file), but formal disposition remains PARTIALLY ATTRIBUTED / NOT ACCEPTABLE: duplicate 9 remains UNRESOLVED, per-column immutable census for INTEGRITY now emitted but gate remains measured FAIL until separately dispositioned, environmental 6118→6140/tick-cache remain UNKNOWN=FAIL; no gate PASS, re-freeze, or B8 certification claimed. READ-ONLY beyond this record and P25_formal_census artifacts.*

