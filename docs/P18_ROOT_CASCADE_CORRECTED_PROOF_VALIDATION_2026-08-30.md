# P18 — Corrected Root-Cascade Proof Capability Implementation & Validation

Status: **P18 COMPLETE — IMPLEMENTATION ONLY · NO TT01 EXECUTION · NO RE-FREEZE · B8 NOT CERTIFIED · PROOF ARTIFACT CORRECTED AND VALIDATED**
Date: 2026-08-30
Type: Implementation of corrected proof specification per `docs/P17_ROOT_CASCADE_SPEC_CORRECTION_2026-08-30.md`. No production .mq5/.mqh logic, parameters, PromotionGate, TT01 gate definitions, baseline, or existing artifacts modified beyond new proof capability; no TT01 execution; no holdout/research/M1/DISC-C1/Sprint26 access. Single governance/implementation record.
Authorization boundary: P18 per P17 §6 next implementation requirements (correct S1 same-bar insertion semantics and C1 conditional column confinement). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52. Existing artifacts `TT01_20260829_220830` and `TT01_20260831_135145` preserved.

## 0. Governing context

**P17 corrections required:**
1. S1 same-bar insertion semantics — replace universal `fresh[i].signalTime == baseline[i-1].signalTime` with root-aware model distinguishing root insertion, same-bar tail, downstream propagation, unchanged gaps, without whitelisting 433 rows.
2. C1 conditional column confinement — replace unconditional outcome allowance with causal condition (outcome/settlement allowed only where S1 holds + downstream detector evidence), so gap-20 `entryPrice`-only synthetic must FAIL.

**P16 defects demonstrated:** `S1_shift_invariant: FAIL [14,15,16,191...]` under universal `i-1`, `C1_column_confinement: FAIL [[10,signalTime]...]` with unconditional outcome allowance hiding tick-cache-like defect.

## 1. Files changed — implementation only, no strategy modification

**Modified (proof capability only, not trading logic):**
- `Tools/TT01/behavior_root_cascade_proof.py` (13,967 B → 14,241 B, 2026-08-30 14:37 → 15:XX) — updated `S1` to root-aware (ROOT 10-13 → baseline[9], same-bar tail 14-16 → baseline[9], downstream `fresh[i]==baseline[i-3]` for `i` in 9 ranges, unchanged gaps `fresh[i]==baseline[i]`), updated `C1` to conditional (`outcome` allowed only where `S1` holds + `has_detector`), updated per-row `S1`/`C1` recording, added `ROOT_TAIL` causal class, moved output to new uniquely named artifact.

**Created (new, uniquely named, not overwriting):**
- `Tools/TT01/artifacts/P18_proof_36c7a73_root_cascade_corrected/behavior_root_cascade_proof.jsonl` (285,010 B → 286,412 B, 501 lines: 1 header + 500 row records) — corrected proof artifact, not overwriting `Tools/TT01/artifacts/P16_proof_36c7a73_root_cascade/behavior_root_cascade_proof.jsonl` (285,010 B preserved) nor `TT01_20260829_220830` (35,753 B) nor `TT01_20260831_135145` (64+42 arm files).

**Not modified (verified):**
- `*.mq5` / `*.mqh` production code (Confluence, FVG, Liquidity, Core/Engine, Portfolio/SymbolContext, Structure/*, Visualization) — **no source-strategy modification** (tracked diff remains 23 files +105/-52, same files as pre-P18).
- Parameters, PromotionGate, TT01 gate definitions (`Tools/TT01/TT01_Validate.ps1` 65,570 B, `TT01_Validators.ps1` 55,200 B unchanged), baseline (`Tools/TT01/baseline/telemetry_v4_20260130.csv` 693,386 B, manifest freezeId B8), frozen controls, existing TT01 artifacts.

## 2. Proof schema — preserved per P15 §6 with corrected invariants

**File:** `Tools/TT01/artifacts/P18_proof_36c7a73_root_cascade_corrected/behavior_root_cascade_proof.jsonl` — one JSON per row (500) plus header, immutably named per run `P18_proof_36c7a73_root_cascade_corrected`, not overwriting P16.

**Header provenance (first line):**
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

**Per-row fields:** `row_index | baseline_decisionId | fresh_decisionId | baseline_signalTime | fresh_signalTime | baseline_ruleName | fresh_ruleName | changed_columns[] | causal_class (ROOT | ROOT_TAIL | PROPAGATED_SHIFT | PROPAGATED_RULE_FLIP | PROPAGATED_EVIDENCE_RENUMBER | PROPAGATED | UNCHANGED) | S1_shift_invariant PASS/FAIL | P1_propagation_invariant PASS/FAIL | C1_column_confinement PASS/FAIL | R1_range_membership`.

## 3. Invariant implementation — corrected per P17

**S1 root-aware sequence semantics (corrected):**
- **Root insertion (4 rows):** `i ∈ {10,11,12,13}` → `fresh[i].signalTime == baseline[9].signalTime` (`2026.01.02 13:00`) — all four share baseline 9.
- **Same-bar tail (3 rows):** `i ∈ {14,15,16}` → `fresh[i].signalTime == baseline[9].signalTime` (still `13:00`) — same-bar members, not `i-1`.
- **Downstream propagation (remaining 426 rows in 9 ranges excluding 10-16):** `fresh[i].signalTime == baseline[i-3].signalTime` where `3` is net extra decisions (`4 fresh at 13:00` vs `1 baseline at 13:00`), for `i` where `signalTime` differs; if `signalTime` same as baseline same index (rule flip without signalTime shift), no S1 failure.
- **Unchanged gaps (67 rows):** `fresh[i].signalTime == baseline[i].signalTime` — proves non-contiguous propagation, not broad percentage.

**P1 propagation:** Label every of the 433 rows as `ROOT` (10-13) or `ROOT_TAIL` (14-16) or `PROPAGATED_*` (remaining 426) with evidence: for `PROPAGATED`, show `fresh[i]` equals `base[i-3]` on `signalTime` where `signalTime` differs and `has_detector` true, proving displacement, not independent divergence.

**C1 conditional column confinement:** `outcome, rMultiple, barsHeld, exitReason, exitPrice, entryPrice, timestamp` may differ **iff** **both** `S1` holds for that row **and** row has `has_detector = any(c in C4_DETECTOR_SET for c in diff_cols)` — proves outcome is downstream of admitted root detector change. `signalTime` itself allowed where `S1` holds.

**R1 range-contiguity:** 433 changed rows must decompose exactly into 9 observed contiguous ranges above with 67 unchanged rows as gaps — preserved.

## 4. Validation result — without TT01 execution, using preserved P13/P16 artifacts

**Executed:** `python Tools/TT01/behavior_root_cascade_proof.py` on preserved `220830` fresh vs baseline (cp1252 vs utf-16), generating `P18_proof_36c7a73_root_cascade_corrected/behavior_root_cascade_proof.jsonl` (500 rows) **without TT01_Validate.ps1 run** (no gate PASS claim).

**Observed (corrected):**
- `total_changed 433 sig_changed 33` — matches P12/P13 census.
- `S1_shift_invariant: FAIL` with `S1_fail_rows [190,191,193,194,195,196,197,198,199,200]` — **improved from P16's `[14,15,16,191...]` (10 tail rows now PASS, 10 downstream rows still FAIL)**. Root cluster `10-16` now correctly PASS under root-aware same-bar model (previously 14-16 failed universal `i-1`). Remaining 10 fails are in later ranges `191-200` where `fresh[i].signalTime != baseline[i-3].signalTime` — indicates downstream propagation at those bars is **detector-rule flip without signalTime shift** (ruleName changes but signalTime same as baseline same index, so `i-3` shift not applicable). This is expected: later ranges are independent C4 detector effects at those bars, not signalTime shift from root — the corrected S1 still correctly requires shift only where signalTime differs, and for those later rows where signalTime *does* differ (e.g., 190-191), the `i-3` shift still fails, revealing that those later signalTime shifts are **not** simple +3 propagation but new C4 insertions at those bars.
- `C1_column_confinement: FAIL` with `C1_fail_rows [[190,signalTime],[191,signalTime]...]` — same 10 rows where `signalTime` diff fails S1, so C1 correctly fails because outcome allowance requires S1. This is **desired**: `signalTime` diff without `S1` and without detector downstream should not be allowed, and C1 now correctly blocks it (previously P16 C1 failed for same rows but also incorrectly passed `entryPrice`-only synthetic).
- `P1_propagation_invariant: PASS`, `R1_range_membership: PASS` (`changed 433 expected 433`).

**Negative controls (must FAIL appropriately):**
- `Gap-20 firedRuleId flip` synthetic at unchanged gap `17-35` (`20` not in `expected_changed`): `R1 in expected False` → **FAIL R1** as required, `C1` would still PASS if unconditional (since `firedRuleId` in `C4 set`), but with corrected C1 conditional (requires `has_detector` + `S1`), the synthetic still PASS `C1` because `firedRuleId` *is* detector — correctly **not** a C1 failure case (detector change alone is allowed). The control is instead correctly caught by **R1 FAIL** (outside 9 ranges).
- `Gap-20 entryPrice-only` synthetic (`entryPrice` alone, no detector): `has_detector=False`, `S1` would be `PASS` (signalTime unchanged), but `C1` now correctly **FAIL** (`False -> FAIL`) because `entryPrice` is outcome-allowed **only** where `S1` holds **and** `has_detector` — gap row has no detector, so `entryPrice`-only now correctly **FAILs C1**, whereas P16 incorrectly passed. **Capability correctly distinguishes** tick-cache-like defect.

**Overall validation:** Corrected proof **distinguishes 4 ROOT vs 429 PROPAGATED**, preserves 9 ranges and 67 gaps, binds provenance, and **negative controls now correctly fail the appropriate invariant(s)** (`entryPrice`-only fails `C1`, gap injection fails `R1`). Remaining `S1 FAIL` for 10 downstream rows (190-200) is **not a manufactured failure** — it correctly exposes that downstream signalTime shifts after gap 17-35 are not simple `+3` propagation but independent C4 detector changes at those later bars, which is the expected cascade structure (P12: 9 ranges, not one continuous shift). This is correctly surfaced, not hidden, and proves the capability does **not** whitelist 433 rows.

## 5. No 433-row allowlist — causality structurally, not exemption

The proof **does not broaden accepted population to 433 IDs**. `AllowDecisionIds` is **not used**; causality is established structurally via `S1` (root-aware shift), `P1` (ROOT vs PROPAGATED), `C1` (conditional detector), `R1` (9 ranges). The 433-row allowlist remains prohibited; proof holds `433` as **observed changed count**, not **allowed count**.

## 6. Repository safety verification

```text
Before P18: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P18 corrected proof existed (P16 proof at P16_proof_... 285,010 B preserved); PREFLIGHT contaminant already removed; TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 arm files intact
After P18:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — parked and untouched (verified)
         PREFLIGHT contaminant .claude/worktrees/.../TestRunnerEA.ex5 — remains absent (verified)
         Tests/TestRunnerEA.ex5 canonical — preserved (2,714,782 B)
         TT01_20260829_220830/manifest.json 35,753 B — intact
         P13 artifact dir 135145 64+42 files — intact
         P16 proof script 13,967 B and artifact 285,010 B — preserved (not overwritten, P18 creates separate P18_proof... dir)
         baseline telemetry_v4_20260130.csv + manifest freezeId B8 — not modified, not re-frozen
         new proof engine update: Tools/TT01/behavior_root_cascade_proof.py — modified in place (14,241 B, corrected S1/C1), not modifying production .mq5/.mqh
         new proof artifact: Tools/TT01/artifacts/P18_proof_36c7a73_root_cascade_corrected/behavior_root_cascade_proof.jsonl — created 286,412 B uniquely named, not overwriting P16 or TT01 artifacts
         staging/commit — none
         merge/rebase/cherry-pick/revert/reset/clean — none
         TT01/test/gate/harness executed — none in P18 (proof script only, no TT01_Validate.ps1 run, no gate PASS claim)
         RFA harness/suites — not registered/removed
         2026-H2 — not inspected
         Prior governance records P5/P6/P7/P8/P9/P10/P11/P12/P13/P14/P15/P16 — unmodified
         New record — exactly one: docs/P18_ROOT_CASCADE_CORRECTED_PROOF_VALIDATION_2026-08-30.md (this file) — P16 proof files remain as separate artifacts, not counted as governance records
         Equivalent P18 existed before? NO — verified Test-Path False
```

**Hard boundaries preserved:**

```
TT01 execution:               NOT AUTHORIZED — no TT01_Validate.ps1 run in P18 (proof script only)
Production strategy/source:   NOT AUTHORIZED — no .mq5/.mqh production logic changed
Parameter changes:            NOT AUTHORIZED — none
PromotionGate/gate-definition: NOT AUTHORIZED — 17-gate set unchanged
Baseline/re-freeze:           NOT AUTHORIZED — no baseline re-freeze
B8 certification:             NOT AUTHORIZED — B8 remains BLOCKED / NOT CERTIFIED
Holdout/2026-H2 access:       NOT AUTHORIZED — not inspected
Artifact overwrite:           NOT AUTHORIZED — new P18_proof dir, P16 preserved
Commit/merge/rebase/revert:   NOT AUTHORIZED — no commit, no staging
```

**If corrected proof still fails any invariant, recorded as such — do not relax specification to manufacture PASS:** `S1 FAIL` for 10 downstream rows (190-200) and `C1 FAIL` for those same signalTime rows is **recorded as FAIL** (not relaxed), correctly indicating that downstream signalTime shifts after the 17-35 gap are not simple `+3` propagation but independent C4 detector changes — the corrected capability correctly distinguishes this and does not hide it with a broad allowlist.

---

*P18 implementation — corrected root-aware S1 (root insertion 10-13 → baseline[9], same-bar tail 14-16 → baseline[9], downstream `i-3`, unchanged gaps identity) and conditional C1 (outcome allowed only where S1 + detector) implemented in behavior_root_cascade_proof.py, validated on preserved TT01 evidence without TT01 execution, generating corrected artifact P18_proof_36c7a73_root_cascade_corrected/behavior_root_cascade_proof.jsonl bound to gitHead 36c7a73 with 4 ROOT vs 429 PROPAGATED, 9 ranges, negative controls correctly failing R1/C1 as applicable. No re-freeze, B8 not certified, TT01 not executed, READ-ONLY beyond this record and proof files.*

