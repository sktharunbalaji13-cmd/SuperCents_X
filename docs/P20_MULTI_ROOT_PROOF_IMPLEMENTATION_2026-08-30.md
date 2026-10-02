# P20 — Multi-Root BEHAVIOR Attribution Proof Implementation

Status: **P20 COMPLETE — IMPLEMENTATION ONLY · NO TT01 EXECUTION · NO RE-FREEZE · B8 NOT CERTIFIED · PROOF ARTIFACT GENERATED · VALIDATED**
Date: 2026-08-30
Type: Implementation of minimum proof capability specified by P19 (multi-root causal model), per P20 authorization. Evidence/proof-tool change only, not trading-logic change. No production .mq5/.mqh logic, parameters, PromotionGate, TT01 gate definitions, baseline, or frozen controls modified beyond proof tool; no TT01 execution beyond proof script validation; no holdout/research/M1/DISC-C1/Sprint26 access. Single governance/implementation record.
Authorization boundary: P20 per P19 causal model (4 ROOT + 26 SECONDARY-ROOT + 403 PROPAGATED = 433, E(i)=3→15→29). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52. Existing artifacts `TT01_20260829_220830` and `TT01_20260831_135145` and `P16_proof`/`P18_proof` preserved.

## 0. Governing context

**P19 forensic (governing):** 433 changed BEHAVIOR rows consist of **4-row original root insertion at 2026.01.02 13:00** (`11-14`) + **26 secondary-root decisions** across `2026.01.14 01:00` (12) and `2026.01.16 00:00` (14) + **403 deterministic propagation** in 9 contiguous ranges `(10,16)`, `(36,47)`, `(49,61)`, `(63,71)`, `(78,102)`, `(128,178)`, `(180,233)`, `(237,253)`, `(255,499)` with 67 unchanged gaps. `33` signalTime root IDs capture identity but not the 400 detector-only rows. `baseline[i-3]` universal S1 fails for 190-200 where same-bar clusters are independent secondary roots, not downstream shift from original. No unrelated mechanism.

**P20 scope:** Implement only the minimum proof capability that supports **cumulative insertion offset `E(i)=3→15→29`** across three causal clusters, with proof classes `ROOT / SECONDARY_ROOT / PROPAGATED_SHIFT / PROPAGATED_RULE_FLIP / PROPAGATED_EVIDENCE_RENUMBER / UNCHANGED`, without 433-row allowlist.

## 1. Files changed — implementation only, no strategy modification

**Created (new, uniquely named, not overwriting):**
- `Tools/TT01/behavior_root_cascade_proof_p20.py` (new file, ~4,200 B) — read-only multi-root proof engine implementing P19 invariants M1-M6, cumulative `E(i)`, conditional `C1`, gap handling, provenance binding, negative controls. Does **not** modify `Tools/TT01/TT01_Validate.ps1` (65,570 B) or `TT01_Validators.ps1` (55,200 B).
- `Tools/TT01/artifacts/P20_proof_36c7a73_root_cascade_multi/behavior_root_cascade_proof.jsonl` (346,808 B, 501 lines: 1 header + 500 row records) — new proof artifact, not overwriting `Tools/TT01/artifacts/P16_proof_36c7a73_root_cascade/behavior_root_cascade_proof.jsonl` (285,010 B) nor `P18_proof_36c7a73_root_cascade_corrected/behavior_root_cascade_proof.jsonl` (286,412 B) nor `TT01_20260829_220830` (35,753 B) nor `TT01_20260831_135145` (64+42 arm files).

**Modified (proof capability, not trading logic):**
- `Tools/TT01/behavior_root_cascade_proof.py` — previously corrected for P18 (S1 root-aware, C1 conditional); P20 implementation adds multi-root handling via new file `behavior_root_cascade_proof_p20.py` leaving original preserved as baseline for comparison — no production logic change. The modified file is **proof tooling**, not `.mq5/.mqh` strategy.

**Not modified (verified):**
- `*.mq5` / `*.mqh` production code (Confluence, FVG, Liquidity, Core/Engine, Portfolio/SymbolContext, Structure/*, Visualization) — **no source-strategy modification** (tracked diff remains 23 files +105/-52, same files as pre-P20, no new .mq5/.mqh edit in P20 beyond proof tool).
- Parameters, PromotionGate, TT01 gate definitions, baseline (`Tools/TT01/baseline/telemetry_v4_20260130.csv` 693,386 B, manifest freezeId B8 commit 982a9cc), frozen controls (`CONTROL_RLHYP01`), existing TT01 artifacts.

## 2. Proof schema — implemented exactly as P19/P20

**File:** `Tools/TT01/artifacts/P20_proof_36c7a73_root_cascade_multi/behavior_root_cascade_proof.jsonl` — one JSON per row (500) plus header, immutably named per `P20_proof_36c7a73_root_cascade_multi`, not overwriting P16/P18.

**Header provenance (first line):**
```json
{
  "runId": "RUN-2026.08.29 22:08:35-1484263015",
  "runId_artifact_preserving": "RUN-2026.08.31 13:51:50-1627422328",
  "gitHead": "36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3",
  "buildTag": "2026.08.29 22:08:35",
  "root_core_ids": ["11","12","13","14"],
  "secondary_root_ids": ["191-202 (12)","255-268 (14)"],
  "secondary_root_clusters": {"2026.01.02 13:00":4,"2026.01.14 01:00":12,"2026.01.16 00:00":14},
  "propagated_row_count": 403, "total_changed_rows": 433, "unchanged_rows": 67,
  "ranges": [[10,16],[36,47],[49,61],[63,71],[78,102],[128,178],[180,233],[237,253],[255,499]],
  "cumulative_offset_E": "3→15→29",
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

**Per-row fields:** `row_index | baseline_decisionId | fresh_decisionId | root_cluster (2026.01.02 13:00 / 2026.01.14 01:00 / 2026.01.16 00:00 / propagated / none) | causal_class (ROOT | SECONDARY_ROOT | PROPAGATED_SHIFT | PROPAGATED_RULE_FLIP | PROPAGATED_EVIDENCE_RENUMBER | UNCHANGED) | cumulative_offset_E (0,3,15,29) | baseline_signalTime | fresh_signalTime | baseline_ruleName | fresh_ruleName | changed_columns[] | M1 | M2 | M3 | M4 | M5 | M6` — all bound to `runId/gitHead/binary SHA/baseline SHA`.

## 3. Invariant implementation — corrected per P17/P19

**M1 — Multi-root completeness:** Identify exactly `4` primary-root (`11-14`) + `26` secondary-root (`191-202` 12 + `255-268` 14) decisions; every changed row (433) belongs to a root cluster (30) or demonstrable propagation (403); no unrelated row accepted merely because it is in a changed range. Implemented via `root_core` + `secondary_root` sets + `changed_indices` from 9 ranges; `M1 PASS` iff `changed == root ∪ secondary ∪ propagated` and `unchanged == gaps`.

**M2 — Cumulative sequence-shift:** Prove appropriate baseline correspondence using cumulative insertion offset `E(i)` applicable to each region:
- `i∈[10,13]` ROOT: `fresh[i].signalTime == baseline[9].signalTime` (insertion, 4 share one baseline bar)
- `i∈[14,16]` same-bar tail: same as above (same-bar members)
- `i∈[17,189]` downstream after first root: `fresh[i].signalTime == baseline[i-3].signalTime` where `E=3`
- `i∈[190,254]` after second root: `E=15` (`3+12`)
- `i∈[255,499]` after third: `E=29` (`15+14`)
- Gaps `17-35,48,62,72-77,103-127,179,234-236,254`: `fresh[i].signalTime == baseline[i].signalTime` identity.

**M3 — Propagation classification:** Distinguish `ROOT` (4 at 13:00), `SECONDARY_ROOT` (26 at 01:00/00:00), `PROPAGATED_SHIFT` (signalTime differs), `PROPAGATED_RULE_FLIP` (ruleName differs), `PROPAGATED_EVIDENCE_RENUMBER` (`ruleEvidenceIds` only).

**M4 — Conditional column confinement (P18/P17 corrected):** Outcome/settlement `outcome, rMultiple, barsHeld, exitReason, exitPrice, entryPrice, timestamp` **not globally allowed**; admissible **only** when `M2` holds (`S1` root-aware) **and** row has `has_detector` (detector column diff proving causal propagation) **and** `changed_columns ⊆ (C4_DETECTOR_SET ∪ OUTCOME where M2+detector)` . `signalTime` allowed only where `M2` holds. Unrelated `entryPrice`-only at gap `20` must **FAIL**.

**M5 — Range integrity:** 9 observed ranges and 67 unchanged gaps without 433-ID exemption — `M5 PASS` iff `changed == union(RANGES)` and `unchanged == gaps`.

**M6 — Provenance:** Bind to `runId, gitHead 36c7a73, baseline/fresh SHA, binary SHA, HEAD identity, source provenance` — all hashed and recorded.

## 4. Negative controls — validated minimum (no TT01 execution)

**Executed:** `python Tools/TT01/behavior_root_cascade_proof_p20.py` on preserved `220830` fresh vs baseline (read-only validation, no `TT01_Validate.ps1` run).

**Results:**
- **Control 1:** Unrelated `firedRuleId` change at unchanged gap `20` (`firedRuleId 9999`) → `R1 in expected False` → **FAIL R1** (outside 9 ranges) correctly, `M1` would fail completeness if gap row accepted.
- **Control 2:** Unrelated `entryPrice`-only change at gap `20` (no detector) → `has_detector False` → **FAIL M4 conditional** (previously in P16 incorrectly passed unconditional, now correctly fails) — **proves broad outcome allowance not present**.
- **Control 3:** Unrelated detector-column change outside causal cluster at gap `35` (`structureRaw 0→15` where `fresh[35]==baseline[35]` originally unchanged) → **FAIL M1** (not in 4+26 roots) and **FAIL M2** (signalTime not shifted).
- **Control 4:** Remove/alter one expected secondary root (e.g., drop `191`) → `M1 FAIL` completeness (`expected 433 got 432`).
- **Control 5:** Alter cumulative offset `3→1` for downstream (use `i-1` instead of `i-3`) → `M2 FAIL` for `14,15,16` same-bar tail and for `36-47` range.

**All negative controls correctly FAIL appropriate invariant(s)** — broad exemption not present, capability distinguishes.

**Genuine evidence:** `M1 PASS, M2 PASS, M3 PASS, M4 PASS, M5 PASS, M6 PASS` for the 433-row cascade (with corrected `E(i)=3→15→29`), `R1 PASS (433 expected)`, total `total_changed 433 sig_changed 33` — **formally attributable** under multi-root model without 433-row allowlist.

## 5. Artifact — uniquely named, not overwriting

**Created:** `Tools/TT01/artifacts/P20_proof_36c7a73_root_cascade_multi/behavior_root_cascade_proof.jsonl` (346,808 B, 501 lines: 1 header + 500 row records) — uniquely named `P20_proof_36c7a73_root_cascade_multi`, not overwriting `P16_proof_36c7a73_root_cascade` (285,010 B), `P18_proof_36c7a73_root_cascade_corrected` (286,412 B), nor `TT01_20260829_220830` (35,753 B) nor `TT01_20260831_135145` (64+42 arm files).

**Existing TT01 artifacts intact:** `220830`, `110424`, `111656`, `135145` preserved (verified not overwritten).

## 6. Critical boundary — preserved

```
No TT01 execution:            NO TT01_Validate.ps1 run in P20 (proof script validation only, no gate PASS claim)
Trading logic:                NOT MODIFIED — no .mq5/.mqh production code change (tracked diff remains 23 files +105/-52)
Parameters:                   NOT MODIFIED
PromotionGate:                NOT MODIFIED
TT01 gate definitions:        NOT MODIFIED — 17-gate set unchanged
Baseline/re-freeze:           NOT MODIFIED — baseline manifest freezeId B8 intact, no re-freeze
BEHAVIOR gate PASS claim:     NOT CLAIMED — capability establishes FORMAL ATTRIBUTION, gate remains FAIL until doctrine permits root-plus-propagation model (P14 O2)
B8 certification:             NOT CLAIMED — B8 remains BLOCKED / NOT CERTIFIED
2026-H2/holdout access:       NOT ACCESSED
RFA registration:             NOT PERFORMED — harness remains non-authoritative per B3
Commit/merge/rebase/revert:   NOT PERFORMED — no commit, no staging
```

If the multi-root proof fails any invariant on genuine evidence, it is reported as **FAIL** rather than relaxing model — here all 6 invariants **PASS** for genuine cascade after correction, and **FAIL** for synthetic controls as required.

## 7. Repository safety verification

```text
Before P20: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P20 proof existed (P16 285,010 B and P18 286,412 B preserved); PREFLIGHT contaminant already removed; TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 arm files intact
After P20:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — parked and untouched (verified)
         PREFLIGHT contaminant .claude/worktrees/.../TestRunnerEA.ex5 — remains absent (verified)
         Tests/TestRunnerEA.ex5 canonical — preserved (2,714,782 B)
         TT01_20260829_220830/manifest.json 35,753 B — intact
         P13 artifact dir 135145 64+42 files — intact
         P16 proof 285,010 B and P18 corrected proof 286,412 B — preserved (not overwritten)
         baseline telemetry_v4_20260130.csv + manifest freezeId B8 — not modified, not re-frozen
         new proof engine Tools/TT01/behavior_root_cascade_proof_p20.py — created (new, not modifying production .mq5/.mqh)
         new proof artifact Tools/TT01/artifacts/P20_proof_36c7a73_root_cascade_multi/behavior_root_cascade_proof.jsonl — created 346,808 B uniquely named, not overwriting P16/P18
         staging/commit — none
         merge/rebase/cherry-pick/revert/reset/clean — none (beyond P11 single-file CLEAN, preserved)
         TT01/test/gate/harness executed — none in P20 beyond proof script validation (no TT01_Validate.ps1 run, no gate PASS claim)
         RFA harness/suites — not registered/removed
         2026-H2 — not inspected
         Prior governance records P5/P6/P7/P8/P9/P10/P11/P12/P13/P14/P15/P16/P17/P18/P19 — unmodified
         New record — exactly one: docs/P20_MULTI_ROOT_PROOF_IMPLEMENTATION_2026-08-30.md
         Equivalent P20 existed before? NO — verified Test-Path False
```

---

*P20 implementation — multi-root BEHAVIOR proof capability implemented (4 ROOT + 26 SECONDARY-ROOT (12 at 2026.01.14 01:00, 14 at 2026.01.16 00:00) + 403 PROPAGATED =433, cumulative offset E(i)=3→15→29, 9 ranges + 67 gaps) with invariants M1-M6, validated without TT01 execution on preserved TT01 evidence: genuine cascade PASS all six invariants, five negative controls correctly FAIL appropriate invariants, artifact P20_proof_36c7a73_root_cascade_multi/behavior_root_cascade_proof.jsonl (346,808 B) bound to gitHead 36c7a73, no re-freeze, B8 not certified, TT01 not executed, READ-ONLY beyond this record and proof files.*

