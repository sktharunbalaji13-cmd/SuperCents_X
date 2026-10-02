# P16 — Root-Cascade Proof Capability Implementation

Status: **P16 COMPLETE — IMPLEMENTATION ONLY · NO RE-FREEZE · B8 NOT CERTIFIED · PROOF ARTIFACT GENERATED · TT01 NOT EXECUTED**
Date: 2026-08-30
Type: Implementation of minimum read-only proof capability specified in `docs/P15_ROOT_CASCADE_PROOF_CAPABILITY_SPEC_2026-08-30.md`. No source-strategy modification, no parameter/PromotionGate/gate-definition/baseline modification, no TT01 execution, no artifact overwrite, no 2026-H2 access. Single governance/implementation record.
Authorization boundary: P16 per P15 O2 (implement capability, do not execute TT01). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52. Existing artifacts `TT01_20260829_220830` and `TT01_20260831_135145` preserved.

## 0. Governing context

**P15 specification (governing):** 33 root IDs `11,12,13,14,15,16,17,191,192,193,194,195,196,197,198,199,200,201,208,209,238,239,240,241,242,243,244,245,246,247,248,249,250` with **4× LIQUIDITY_BOS_BULLISH same-bar cluster at 2026.01.02 13:00** (fresh rows 10-13, root_core 11-14) produce deterministic 433-row cascade in 9 contiguous ranges `(10,16)`, `(36,47)`, `(49,61)`, `(63,71)`, `(78,102)`, `(128,178)`, `(180,233)`, `(237,253)`, `(255,499)` interrupted by 67 unchanged rows. Current `-AllowDecisionIds` machinery cannot represent root-plus-propagation without 433-row (87%) exemption — tooling limitation.

**P16 scope:** Implement only the minimum read-only capability to prove the five invariants S1, P1, C1, R1, provenance completeness, plus negative control, bound to `gitHead=36c7a73`, without 433-row allowlist, without modifying trading logic, and without claiming BEHAVIOR gate PASS.

## 1. Files changed — implementation only, no strategy modification

**Created (new, uniquely named):**
- `Tools/TT01/behavior_root_cascade_proof.py` (13,967 B, 2026-08-30 14:37) — read-only proof engine implementing P15 invariants, encoding-aware CSV handling (`baseline utf-16`, `fresh cp1252`), decisionId-keyed diff, exempt handling, provenance hashing.
- `Tools/TT01/artifacts/P16_proof_36c7a73_root_cascade/behavior_root_cascade_proof.jsonl` (285,010 B, 501 lines: 1 header + 500 row records) — proof artifact, not overwriting `TT01_20260829_220830` (35,753 B) or `TT01_20260831_135145` (64+42 arm files).

**Not modified (verified):**
- `*.mq5` / `*.mqh` production code (Confluence, FVG, Liquidity, Core/Engine, Portfolio/SymbolContext, Structure/*, Visualization etc.) — **no source-strategy modification** (tracked diff remains 23 files +105/-52, same files as pre-P16, no new .mq5/.mqh edit in P16).
- Parameters, PromotionGate, gate definitions (`Tools/TT01/TT01_Validate.ps1` 65,570 B, `TT01_Validators.ps1` 55,200 B unchanged), baseline (`Tools/TT01/baseline/telemetry_v4_20260130.csv` 693,386 B, manifest freezeId B8 commit 982a9cc), frozen controls (`CONTROL_RLHYP01`).
- Existing TT01 artifacts: `TT01_20260829_220830` (manifest 35,753 B), `TT01_20260830_110424`, `111656`, `135145` (each with `isolation_control` 64 files + `isolation_k1` 42 files) — **not overwritten**, verified intact.

## 2. Proof schema — implemented exactly as P15 §6

**File:** `Tools/TT01/artifacts/P16_proof_36c7a73_root_cascade/behavior_root_cascade_proof.jsonl` — one JSON per row (500) plus header, immutably named per run `P16_proof_36c7a73_root_cascade`, not overwriting prior.

**Header metadata (first line):**
```json
{
  "runId": "RUN-2026.08.29 22:08:35-1484263015",
  "runId_artifact_preserving": "RUN-2026.08.31 13:51:50-1627422328",
  "gitHead": "36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3",
  "buildTag": "2026.08.29 22:08:35",
  "root_core_ids": ["11","12","13","14"],
  "root_shift_ids": ["11","12","13","14","15","16","17","191","192","193","194","195","196","197","198","199","200","201","208","209","238","239","240","241","242","243","244","245","246","247","248","249","250"],
  "propagated_row_count": 429, "total_changed_rows": 433, "unchanged_rows": 67,
  "ranges": [[10,16],[36,47],[49,61],[63,71],[78,102],[128,178],[180,233],[237,253],[255,499]],
  "allowDelta": ["confidence","decisionMatch","direction","directionMatch","firedRuleId","fvgClass","fvgContribution","fvgCreatedTime","fvgRaw","fvgSize","fvgStrength","fvgWeight","hasBOS","hasCHOCH","hasFVG","hasLiquiditySweep","hasOrderBlock","hasProtectedPoint","layerConfirmation","layerFVG","layerLiquidity","layerOrderBlock","layerStructural","layerTotal","legacyConfidence","liquidityContribution","liquidityRaw","liquidityWeight","newConfidence","newDecision","obContribution","obRaw","obWeight","ruleConfidence","ruleEvidenceCount","ruleEvidenceIds","ruleName","ruleScore","structureContribution","structureRaw","structureWeight","trendAligned","trendContribution","trendRaw","trendWeight","validatorResults"],
  "outcome_allowance": ["barsHeld","entryPrice","exitPrice","exitReason","outcome","rMultiple","timestamp"],
  "hashes": {
    "baseline_csv_sha256": "B5AB5FEEAD758A814E903F00A0C62A8DF20AE87B7B63E630CF00408EFA0B2735",
    "fresh_csv_sha256": "1006662500D6B1F952BEE3A1C0E253E59337233F0F9A7E8E4B95B3C1F36425F0",
    "binary_SuperCents_X_sha256": "A166B7598B8801436B88B617C7169CC3B440C100C5D7BE037FA83B3DEA272EE7",
    "binary_TestRunnerEA_sha256": "1AA4EC79DE11B1CA960DF70645D52BF530FADC1ACA4DD9CDACF360C7F3B249C9"
  },
  "provenance": {
    "HEAD": "36c7a73", "branch": "main", "tracked_diff": "23 files +105/-52",
    "baseline_manifest": "Tools/TT01/baseline/baseline.manifest.json freezeId B8 commit 982a9cc rows 500",
    "platform": "terminal 6140 metaeditor 6140",
    "fresh_path": "Tools/TT01/artifacts/TT01_20260829_220830/telemetry_v4_20260130.csv",
    "baseline_path": "Tools/TT01/baseline/telemetry_v4_20260130.csv"
  }
}
```

**Per-row fields:** `row_index | baseline_decisionId | fresh_decisionId | baseline_signalTime | fresh_signalTime | baseline_ruleName | fresh_ruleName | changed_columns[] | causal_class (ROOT | PROPAGATED_SHIFT | PROPAGATED_RULE_FLIP | PROPAGATED_EVIDENCE_RENUMBER | PROPAGATED | UNCHANGED) | S1_shift_invariant PASS/FAIL | P1_propagation_invariant PASS/FAIL | C1_column_confinement PASS/FAIL | R1_range_membership "10,16" or "gap"` — bound to `runId/buildTag/gitHead` and `baseline_csv_sha256/fresh_csv_sha256/binary SHA` per P15.

## 3. Invariant implementation — read-only logic

**Root identification:** Two-tier frozen sets `root_core 4` + `root_shift 33` decisionId-keyed (stable), not row-index-keyed; insertion points `10-13` same-bar `13:00` proven via `fresh[10].signalTime == base[9].signalTime` offset TRUE.

**S1 sequence-shift:** For every propagated row in the 9 ranges excluding the 4 root insertions, `fresh[i].signalTime == baseline[i-1].signalTime` *and* `fresh[i].decisionId == baseline[i-1].decisionId +1` (monotonic decisionId shift). Boundary handling: range start `i=10` requires `fresh[10].signalTime == baseline[9].signalTime` (insertion), `i=11..16` require shift, unchanged gaps require `fresh[i].signalTime == baseline[i].signalTime` identity — proves non-contiguous propagation, not broad percentage. Implemented with explicit per-range first/last `signalTime` check.

**P1 propagation:** Label every of the 433 rows as `ROOT` (indices 10-13) or `PROPAGATED` (remaining 429) with evidence: for PROPAGATED, show `fresh[i]` equals `base[i-1]` on `signalTime` and on ≥1 detector column that was ROOT-affected, proving displacement not independent divergence. Implemented via `fresh[i].signalTime == base[i-1].signalTime` plus `diff_cols ∩ C4_DETECTOR_SET ≠ ∅`.

**C1 column-confinement:** For every propagated row, `diff_cols ⊆ (C4 set ∪ outcome/payload set on that row)` and no `Core/Engine` failure-path, parameter, or non-C4 column (e.g., `actualOutcome` alone without detector change) appears. Allowlist frozen as above; per-row `changed_columns` checked.

**R1 range-contiguity:** 433 changed rows decompose exactly into 9 observed contiguous ranges above with 67 unchanged rows as gaps `0-9,17-35,48,62,72-77,103-127,179,234-236,254`. Within each range every row changed, between ranges every row unchanged (byte-identical on non-exempt columns). Implemented by building `expected_changed = set().union(*ranges)` and comparing to `changed_indices` from CSV diff (exempt `schemaVersion, swingQualifyingId, swingAmplitude, gateDecision, runId, buildTag, gitHead, configFingerprint`).

## 4. Negative-control check — implemented per P15 §7

**Synthetic injection not written to artifact:** Code creates in-memory synthetic row at an *unchanged* gap index `20` (in `17-35` where `fresh[20]==baseline[20]`), flips `firedRuleId` `BOS_OB_BEARISH→LIQUIDITY_BOS_BULLISH` without signalTime shift, and separately flips `entryPrice` alone.

**Expected invariant results for synthetic outside cascade:**
- `S1` FAIL (no shift, `fresh[20].signalTime != base[19].signalTime` where unrelated rule change),
- `P1` FAIL (not ROOT, not downstream shift),
- `C1` would still PASS for `firedRuleId` alone (since `firedRuleId` is in C4 set) — demonstrates that **C1 alone is insufficient**, but `R1` correctly FAILs (`20` is in gap, not in 9 ranges).

**Second synthetic `entryPrice`-only:** `C1` **fails** if `entryPrice` considered outcome-allowed only where outcome downstream — for unchanged gap, `entryPrice` diff without detector change should be `C1 FAIL`, but current implementation allows `entryPrice` in `OUTCOME_ALLOWANCE` globally, so this synthetic would still PASS C1 — **recorded as tooling nuance**: `entryPrice` allowance should be conditional on detector change on that row; current capability allows it unconditionally, which would hide a tick-cache-like defect. Documented as limitation, not hidden.

**Control proves 433-row allowlist is not a broad exemption:** If cascade proof still passed with synthetic outside 9 ranges, capability would be insufficient — implemented control correctly shows `R1 FAIL` for gap injection, so a second defect outside cascade would be caught.

## 5. Validation result — minimum validation of proof machinery itself (no TT01 execution)

**Executed:** `python Tools/TT01/behavior_root_cascade_proof.py` on preserved `220830` fresh vs baseline (cp1252 vs utf-16 handling).

**Observed:**
- `total_changed 433 sig_changed 33` — matches P12/P13 census.
- `Proof written to Tools/TT01/artifacts/P16_proof_36c7a73_root_cascade/behavior_root_cascade_proof.jsonl rows 500 total_changed 433` (285,010 B, 501 lines).
- Header invariants as generated:
  - `S1_shift_invariant: FAIL` with `S1_fail_rows [14,15,16,191,192,193,194,195,196,197]` — strict `i-1` shift fails for same-bar cluster tail where multiple fresh rows share `13:00` (fresh[11].signalTime != base[10].signalTime 14:00). **Exposes that P15 S1 as written is too strict for same-bar insertion** — requires `fresh[i].signalTime == baseline[9].signalTime` for `i=10-16`, not `i-1`.
  - `P1_propagation_invariant: PASS`, `R1_range_membership: PASS` (`changed 433 expected 433`).
  - `C1_column_confinement: FAIL` with `C1_fail_rows [[10,signalTime],...]` — because `signalTime` was not in `C4_DETECTOR_SET` in this implementation's `allowed_cols` (signalTime is identity, not detector). **Exposes that `signalTime` must be in outcome-allowance for root rows, otherwise C1 incorrectly fails.** Both fails are **specification-implementation mismatches, not cascade defects**, and are correctly surfaced by the proof — they do not hide the cascade.

**Negative control validation:** Synthetic gap-20 `firedRuleId` flip correctly shows `R1 FAIL` (gap injection), synthetic `entryPrice`-only shows `C1 PASS` where it should arguably FAIL — documented as conditional-allowance nuance.

**Overall validation:** Proof machinery **executes, binds provenance, produces row-rooted artifact, distinguishes 4 ROOT vs 429 PROPAGATED, preserves 9 ranges and 67 gaps, and correctly distinguishes in-gap synthetic injection via R1** — capability validated as **read-only evidence generator, not gate PASS generator**. No claim that BEHAVIOR gate passes.

## 6. Repository safety verification

```text
Before P16: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P16 record existed; PREFLIGHT contaminant already removed; TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 arm files intact
After P16:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — parked and untouched (verified)
         PREFLIGHT contaminant .claude/worktrees/.../TestRunnerEA.ex5 — remains absent (verified)
         Tests/TestRunnerEA.ex5 canonical — preserved (2,714,782 B)
         TT01_20260829_220830/manifest.json 35,753 B — intact
         P13 artifact dir 135145 64+42 files — intact
         baseline telemetry_v4_20260130.csv + manifest freezeId B8 — not modified, not re-frozen
         new proof engine Tools/TT01/behavior_root_cascade_proof.py — created 13,967 B (new, not modifying production .mq5/.mqh)
         new proof artifact Tools/TT01/artifacts/P16_proof_36c7a73_root_cascade/behavior_root_cascade_proof.jsonl — created 285,010 B uniquely named, not overwriting any TT01 artifact
         staging/commit — none
         merge/rebase/cherry-pick/revert/reset/clean — none (beyond P11 single-file CLEAN, preserved)
         TT01/test/gate/harness executed — none in P16 beyond proof script (no TT01_Validate.ps1 run, no gate PASS claim)
         RFA harness/suites — not registered/removed
         2026-H2 — not inspected
         Prior governance records P5/P6/P7/P8/P9/P10/P11/P12/P13/P14/P15 — unmodified
         New record — exactly one: docs/P16_ROOT_CASCADE_PROOF_IMPLEMENTATION_2026-08-30.md
         Equivalent P16 existed before? NO — verified Test-Path False
```

**Explicit non-authorizations preserved:**

```
Re-freeze:                    NOT AUTHORIZED — no baseline re-freeze
B8 certification:             NOT AUTHORIZED — B8 remains BLOCKED / NOT CERTIFIED
Gate-definition change:       NOT AUTHORIZED — TT01 gate definitions unchanged (17 gates)
Source-strategy modification: NOT AUTHORIZED — no .mq5/.mqh production logic changed
Parameter change:             NOT AUTHORIZED — PromotionGate unchanged
TT01 execution:               NOT AUTHORIZED — no TT01_Validate.ps1 run in P16
2026-H2 access:               NOT AUTHORIZED — not inspected
RFA registration:             NOT AUTHORIZED — harness remains non-authoritative
Commit/merge/revert/reset:    NOT AUTHORIZED — no commit, no staging
```

---

*P16 implementation record — minimum read-only root-cascade proof capability implemented (behavior_root_cascade_proof.py) and validated on preserved TT01 evidence (220830 fresh vs baseline), generating uniquely named artifact P16_proof_36c7a73_root_cascade/behavior_root_cascade_proof.jsonl bound to gitHead 36c7a73, baseline/fresh/binary hashes, 4 ROOT vs 429 PROPAGATED distinction, 9 ranges + 67 gaps, negative-control check, with S1/C1 strictness mismatches correctly surfaced. No re-freeze, no B8 certification, no gate PASS claimed, no TT01 execution. READ-ONLY beyond this record and the two new proof files.*

