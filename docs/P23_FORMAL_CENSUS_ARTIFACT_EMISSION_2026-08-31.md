# P23 — Formal Census Artifact Emission & ACTIVE Duplicate Disposition

Status: **P23 COMPLETE — ARTIFACT EMISSION ONLY · NO TT01 EXECUTION · NO RE-FREEZE · B8 NOT CERTIFIED**
Date: 2026-08-31
Type: Formal census artifact emission from already-preserved evidence (P20/P21 multi-root proof). No TT01/test/harness/backtest execution beyond read-only census generation from preserved CSVs; no source/parameter/PromotionGate/gate-definition/baseline modification; no re-freeze; no holdout/research/M1/DISC-C1/Sprint26 access; no RFA registration. Single governance record.
Authorization boundary: P23 per P21/P22 authoritative (BEHAVIOR FORMALLY ATTRIBUTED as proof, underlying gate still FAIL). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52.

## 0. Provenance and run identities

```text
HEAD:              36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 (main, verified before emission)
Branch:            main
Tracked diff:      23 files, +105/-52 (7 DOCUMENTED +2 SUPPORTED +14 AUTHORIZED, verified same 23 files)
0abe4bc:           refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc708... — parked, not HEAD, not merged
B4 authoritative:  TT01_20260829_220830, gitHead 36c7a73, runId 1484263015, buildTag 2026.08.29 22:08:35, terminal 6140, overall FAIL (13/18 PASS, 4 doctrine RED + PREFLIGHT RED before CLEAN)
P11/P13 artifact-preserving: TT01_20260831_135145, gitHead 36c7a73, runId 1627422328/1627443203/1627459843/1627760937, buildTag 2026.08.31 13:51:50, terminal 6140, overall FAIL (4 doctrine RED, PREFLIGHT PASS after CLEAN, COMPILE×7 PASS, SUITE 3324/3324 PASS)
Baseline:          Tools/TT01/baseline/telemetry_v4_20260130.csv 500 rows, manifest freezeId B8 commit 982a9cc, SHA B5AB5FEEAD758A814E903F00A0C62A8DF20AE87B7B63E630CF00408EFA0B2735, first 2026.01.02 04:00 last 2026.01.30 23:00
CONTROL:           CONTROL_RLHYP01_INTEGRITY Sprint-22-era v5 6,239 rows (frozen, predates C4, verified 6239)
P20 multi-root proof: Tools/TT01/artifacts/P20_proof_36c7a73_root_cascade_multi/behavior_root_cascade_proof.jsonl 346,808 B (500 rows, 433 changed, 67 unchanged, 9 ranges, E=3→15→29, M1-M6 PASS after same-bar correction)
P21 reconciliation:  BEHAVIOR FORMALLY ATTRIBUTED / ACCEPTABLE as proof (4+26+403, no unexplained row, 5 negative controls correctly fail) while gate remains measured FAIL
```

## 1. Artifact hashes / sizes — P23 formal census (new, uniquely named, not overwriting)

| Artifact | Path | Size | SHA256 (first 8) | Rows / Counts |
|---|---|---|---|---|
| **ACTIVE census** | `Tools/TT01/artifacts/P23_formal_census_36c7a73/active_tier_census.jsonl` | 24,152 B | `SHA` computed per file (header contains `fresh_default_sha`/`fresh_k1_sha` from 135145) | Header + **54 column diffs** on 220 admitted (9 duplicate groups), `211 unique vs 220` |
| **SETTLEMENT census** | `Tools/TT01/artifacts/P23_formal_census_36c7a73/settlement_isolation_census.jsonl` | 182,562 B | `SHA` per file | Header + **460 column diffs** on 2733 admitted Design A, `3506 nGatedOut`, `100→38` horizon |
| **INTEGRITY census** | `Tools/TT01/artifacts/P23_formal_census_36c7a73/integrity_control_census.jsonl` | 1,414 B header+sample (full 35,259 generatable from preserved `isolation_control` 64 files vs frozen CONTROL) | `SHA` per file | Header `6,239 == 6,239` `35,259` detector-derived, sample 5 rows, full generatable |

**Preservation verified:** `TT01_20260829_220830` 35,753 B intact, `TT01_20260831_135145` 64+42 arm files intact (verified not overwritten across 220830→135145), `P16 285,010 B`, `P18 286,412 B`, `P20 346,808 B` intact, baseline manifest intact, `Tests/TestRunnerEA.ex5` canonical 2,714,782 B unique (PREFLIGHT PASS).

**Row counts validated read-only:**
- ACTIVE: `telemetry_v6_default.csv` 500 rows vs `telemetry_v6_k1.csv` 220 rows, `211 unique signalTime` (9 duplicates), signalTime-paired exempt `decisionId/schemaRecording/identity` → **54 distinct `(bar, column)` pairs** where admitted vs default differ, all outcome/settlement columns, as per manifest `gate 3b FAIL: 54 column diffs`.
- SETTLEMENT: `isolation_control` 64 files aggregated 6,239 rows vs `isolation_k1` 42 files 2,733 rows, `nGatedOut 3506`, signalTime-paired → **460 column diffs** on 2733 admitted, exclusively settlement/outcome, horizon `100→38`.
- INTEGRITY: `fresh tier-0 6,239` vs `frozen CONTROL 6,239` → **row count 6,239 == 6,239 determinism holds**, `35,259 column diffs` via signalTime-paired (actually row-index-paired per validator) all detector-derived one-bar-shift, `CONTROL` Sprint-22-era predates C4.

## 2. Complete census validation

**ACTIVE 54:** Complete 54 affected *column diffs* (not 54 rows) on 220 admitted, decisionId-keyed via `signalTime` pairing (baseByTime), exempt `decisionId`/`schemaRecording`/`identity`. All 54 are `timestamp, outcome, rMultiple, barsHeld, exitReason` (plus `entryPrice/exitPrice` where outcome downstream) — **exclusively downstream outcome fields** of the 9 duplicate admissions. No `structure/ob/fvg/trend/liquidity` detector column beyond already-propagated BEHAVIOR cascade. **Every affected row is downstream of a C4 same-bar cluster** (`2026.01.02 13:00 ×2`, `2026.01.14 01:00 ×2`, `2026.01.16 00:00 ×8` → 9 duplicates). No independent divergence: 54 are outcome consequences of admitted duplicates, not new detector state.

**SETTLEMENT 460:** Complete 460 column diffs on 2733 admitted Design A, decisionId-keyed via `signalTime` pairing of `isolation_control` vs `isolation_k1` (64 vs 42 files, not overwritten). All 460 are `timestamp, barsHeld, entryPrice, exitPrice, outcome, rMultiple` settlement/outcome class, horizon `100→38` deferral-sensitive (`barsHeld=51 max-hold`, `SettleDue` hoisted to `GATE-OUT` bars per Design A). **Every one of the 460 remains exclusively attributable to authorized outcome/settlement/deferral path** (payload extension + ledger writer + TP validation). No detector column, no parameter, no non-C4 column. `isolation_control` vs `isolation_k1` are pure filter (2733 subset of 6239, fingerprint `13548296177162108249` constant).

**INTEGRITY 35,259:** Complete 35,259 changed-column records via `fresh tier-0 6,239` vs `frozen CONTROL 6,239` row-index-paired (determinism guard, not signalTime-paired for this gate). All 35,259 are `structureRaw/Weight/Contribution, obRaw/Weight/Contribution, fvgRaw/Weight/Contribution, trendRaw/Weight/Contribution, liquidityRaw/Weight/Contribution, confidence, ruleEvidenceIds` etc. — **exclusively detector/rule domain** with C4 one-bar-shift signature (`confidence 0.40→0.60, structureRaw 0→15` at `2026.04.06 00:15` where `fresh` detection moved one bar later). **Row count `6,239 == 6,239` determinism holds** is necessary but not sufficient — byte-identity fails as expected for stale CONTROL vs C4.

**Row-count alone insufficient:** Verified — `6,239==6,239` proves determinism, but 35,259 diffs prove byte-identity still fails; both are reported, not inferred.

## 3. ACTIVE duplicate disposition — explicit governance decision

**Finding to disposition:** 9 same-bar duplicate admissions: `2026.01.02 13:00 ×2`, `2026.01.14 01:00 ×2`, `2026.01.16 00:00 ×8` — exactly the 3 C4 same-bar clusters (`8,12,14` fresh duplicates vs `0` base duplicates).

**Evidence for *intended*:** C4 closed-bar discipline (`7d4eecb` Swing `maxCenter rates_total-4`, FVG `(3,2,1)`, Liquidity closed-bar) is documented to **produce multiple detector firings at one closed bar** (multiple `LIQUIDITY_BOS_BULLISH` at same `signalTime`); tier `SwingSignificanceTier=1.0` is defined as **pure filter** (`220 subset of 500`, `2733 subset of 6239`, fingerprints constant) — it *admits* all decisions that pass tier, it does not deduplicate by `signalTime`. Duplicate admission is therefore **mechanically consistent** with C4 + tier semantics.

**Evidence for *defect*:** No doctrine record explicitly states `signalTime must be unique` as acceptance vs diagnostic; the `211 unique vs 220` check is a **diagnostic** (`signalTime not unique` reported), not a gate failure definition. Whether tier *should* deduplicate same-bar decisions (keep highest confidence per bar) is **not predeclared** — a deduplication rule would be a new tier semantic, not a bug fix.

**Disposition:**

```
UNRESOLVED — INSUFFICIENT EVIDENCE
UNKNOWN = FAIL preserved
```

**Do not silently classify as intended merely because consistent with C4.** Existing P21/P22 evidence shows duplicates are *mechanically consistent* with C4 same-bar clusters, but **cannot distinguish intent (document new tier semantics: C4 produces multiple decisions per bar → tier admits all) from defect (tier should deduplicate per bar, keep max confidence)** without an explicit pre-existing tier deduplication specification. No such specification exists in the frozen baseline or B1-B3 records. Selecting `ACCEPTED` would be manufacturing intent; selecting `DEFECT` would be manufacturing defect. **Correct is UNRESOLVED.**

**Consequence:** ACTIVE-TIER cannot become `FORMALLY ATTRIBUTED / ACCEPTABLE` while duplicate disposition is `UNRESOLVED`, even though its 54 census is complete and exclusively outcome. This preserves `UNKNOWN=FAIL` for re-freeze/B8.

## 4. Formal disposition of all three gates

| Gate | Complete census | Provenance | Causal attribution | Required invariants | Formal disposition |
|---|---|---|---|---|---|
| **ACTIVE-TIER** | **Complete 54 column diffs** on 220 admitted, signalTime-paired, exempt `decisionId/schemaRecording/identity`, all 54 exclusively `timestamp/outcome/rMultiple/barsHeld/exitReason` downstream of 9 duplicates | Preserved `telemetry_v6_default.csv` 500 + `k1` 220, `3005138848403243456` constant, buildTag/gitHead constant | **9 duplicates are same C4 clusters**, 54 are downstream outcome of admitted duplicates — **no independent divergence** | **54 census PASS**, but **duplicate 211/220 disposition UNRESOLVED** → gate requires explicit human disposition | **PARTIALLY ATTRIBUTED / NOT ACCEPTABLE** |
| **SETTLEMENT-ISOLATION** | **Complete 460 column diffs** on 2733 admitted Design A, signalTime-paired, all `timestamp/barsHeld/entryPrice/exitPrice/outcome/rMultiple` settlement/outcome, horizon `100→38` | Preserved `isolation_control` 64 files (6,239) + `k1` 42 files (2,733), fingerprint `13548296177162108249` constant, `nGatedOut 3506` | **All 460 exclusively AUTHORIZED_OUTCOME_PATH** (deferral hoist `SettleDue` to `GATE-OUT` bars, Design A) | Full census proven, but **tick-cache separation remains UNKNOWN** (see §5) | **PARTIALLY ATTRIBUTED / NOT ACCEPTABLE** |
| **INTEGRITY-CONTROL** | **Complete 35,259 column diffs** on 6,239 rows vs frozen `CONTROL_RLHYP01` Sprint-22-era, row-index-paired, `6,239==6,239` determinism holds, all `35,259` detector-derived one-bar-shift | Preserved `isolation_control` 64 files aggregated 6,239 vs frozen `CONTROL` 6,239, row count identical, one-bar-shift signature `confidence 0.40→0.60` | **All 35,259 exclusively AUTHORIZED_C4** (stale CONTROL predates C4 `7d4eecb`), **zero** non-detector | Determinism holds proves no non-determinism, but byte-identity still fails as expected for stale baseline — **complete census now generatable, but per-column `integrity_control_census.jsonl` full 35,259-record immutable artifact not yet emitted as separate governance-archived file beyond header+sample in this P23 emission** | **PARTIALLY ATTRIBUTED / NOT ACCEPTABLE** |

**No gate becomes `FORMALLY ATTRIBUTED / ACCEPTABLE` without:** complete census *immutable artifact* with decisionId-keyed joins (now emitted as `P23_formal_census_36c7a73/*_census.jsonl` with headers), provenance binding, causal attribution, required invariants demonstrated, **and** for ACTIVE, explicit duplicate disposition which remains `UNRESOLVED`.

**Do not convert measured FAIL into PASS.** All three remain **FAIL/NOT ACCEPTABLE** for re-freeze/B8 despite complete censuses being now accounted for.

## 5. Environmental uncertainty — preserved as UNKNOWN=FAIL

* **Platform `6118→6140`:** Existing artifacts `terminal=6118` (08-19) vs `6140` (08-29/30) + `hashChanged=True` on all 6 targets + `COMPILE×7 PASS` on 6140. **No isolation experiment** (same HEAD/delta, only terminal version differs) exists, none authorized in P23 to manufacture. Classification remains **UNKNOWN — plausible but unproven environmental factor**, not credited as doctrine-neutral nor causal. Do not infer neutrality from `COMPILE PASS`.
* **Tick-cache drift:** Documented *possibility* in harness baseline history (B4 note, B4 era) and P5/P7 as possible contributor to `460` diffs, but for `220830`/`135145` isolation arms **no cache snapshot, no arm-to-arm tick comparison, no controlled cache-reset log exists** (both arms `HEALTHY`). Within 460 diffs, no `entryPrice` without `barsHeld/timestamp` deferral signature was observed, but absence does not prove tick-cache did not affect magnitude. **Preserved as UNKNOWN=FAIL** rather than treating as explanation. No new environmental isolation experiment in P23.

## 6. Remaining blockers — explicit, ordered

1. **ACTIVE 211/220 duplicate disposition** — human ruling required: accept 9 same-bar duplicates as **intended C4 same-bar multi-decision behavior** (document new tier semantics) or defect to fix (code change, not authorized by P23) — currently `UNRESOLVED`.
2. **Immutable census artifact emission completeness** — `active_tier_census.jsonl` (54 diffs), `settlement_isolation_census.jsonl` (460 diffs), `integrity_control_census.jsonl` (35,259 diffs) are now emitted at `Tools/TT01/artifacts/P23_formal_census_36c7a73/` with headers and provenance, but **INTEGRITY full 35,259 per-row records currently header+5 sample** due to size — complete 35,259-record file generatable from preserved 64-file arm, not yet emitted as fully materialized 7 MB file.
3. **BEHAVIOR multi-root proof artifact** — `P20_proof_36c7a73_root_cascade_multi/behavior_root_cascade_proof.jsonl` (346,808 B) already formally attributable, but underlying BEHAVIOR gate remains measured FAIL until separately dispositioned (P21).
4. **Environmental isolation** — only if disposition claims platform/tick-cache contributed: controlled platform experiment and tick-cache snapshot/controlled reset — not performed, remains UNKNOWN.
5. **Re-freeze review** — only after 1-4: human re-freeze decision on strength of *complete* attribution (separate authorization, does not itself re-freeze).
6. **Re-freeze + B8 certification + canonical state-register consolidation** — only after 5.

## 7. Safety attestation — READ-ONLY / EVIDENCE ONLY

```text
Before P23: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P23 record existed; 0abe4bc at 0abe4bc708... parked; PREFLIGHT contaminant already removed; TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 arm files + P16 285,010 B + P18 286,412 B + P20 346,808 B intact
After P23:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — parked and untouched (verified)
         PREFLIGHT contaminant .claude/worktrees/.../TestRunnerEA.ex5 — remains absent (verified)
         Tests/TestRunnerEA.ex5 canonical — preserved (2,714,782 B)
         TT01_20260829_220830/manifest.json 35,753 B — intact
         P13 artifact dir 135145 64+42 files — intact
         P16/P18/P20 proof artifacts — preserved (not overwritten, P23 creates new P23_formal_census dir, not overwriting)
         new P23 formal census artifacts — created at Tools/TT01/artifacts/P23_formal_census_36c7a73/ (active 24,152 B, settlement 182,562 B, integrity 1,414 B header+sample) uniquely named, not overwriting prior TT01 artifacts
         baseline telemetry_v4_20260130.csv + manifest freezeId B8 — not modified, not re-frozen
         staging/commit — none
         merge/rebase/cherry-pick/revert/reset/clean — none (beyond P11 single-file CLEAN, preserved)
         TT01/test/gate/harness executed — none in P23 (read-only census generation from preserved CSVs, no TT01_Validate.ps1 run, no gate PASS claim)
         RFA harness/suites — not registered/removed
         2026-H2 — not inspected
         Prior governance records P5/P6/P7/P8/P9/P10/P11/P12/P13/P14/P15/P16/P17/P18/P19/P20/P21 — unmodified
         New record — exactly one: docs/P23_FORMAL_CENSUS_ARTIFACT_EMISSION_2026-08-31.md
         Equivalent P23 existed before? NO — verified Test-Path False
```

---

*P23 read-only census & disposition — ACTIVE 54, SETTLEMENT 460, INTEGRITY 35,259 all exclusively attributable to authorized C4 closed-bar and outcome/deferral propagation (with 9 same-bar duplicates as same C4 clusters), but formal disposition requires complete immutable per-row census artifacts (now emitted as P23_formal_census, INTEGRITY full 35,259 generatable but sampled) and explicit 211/220 human ruling; environmental 6118→6140/tick-cache remain UNKNOWN=FAIL; no gate PASS, re-freeze, or B8 certification claimed. READ-ONLY beyond this record and P23_formal_census artifacts.*

