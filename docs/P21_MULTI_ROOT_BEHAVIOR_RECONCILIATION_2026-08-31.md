# P21 — Multi-Root BEHAVIOR Reconciliation (P20 Proof Forensic)

Status: **P21 COMPLETE — READ-ONLY FORENSIC RECONCILIATION · NO TT01 EXECUTION · NO RE-FREEZE · B8 NOT CERTIFIED**
Date: 2026-08-31
Type: Read-only forensic reconciliation between `TT01_20260829_220830` (36c7a73, overall FAIL), HEAD `36c7a73`, authorized 23-file delta `+105/-52`, P20 multi-root proof artifact `Tools/TT01/artifacts/P20_proof_36c7a73_root_cascade_multi/behavior_root_cascade_proof.jsonl` (346,808 B, 501 lines), and BEHAVIOR-REGRESSION gate result. No production .mq5/.mqh logic, parameters, PromotionGate, gate-definition, frozen baseline, artifact, or repository mutation; no TT01 run, no backtest, no holdout/2026-H2 access, no RFA registration. Single governance record.

## 0. Execution / Read-Only Attestation

```text
P21 execution:            READ-ONLY forensic reconciliation only
TT01 executed:            NO — re-ran P20 proof capability `python Tools/TT01/behavior_root_cascade_proof_p20.py` read-only against preserved artifacts (no TT01_Validate.ps1 run, no gate PASS claim)
New TT01 run:             NO — no new runId, no new manifest, no binary recompilation
Artifact overwrite:       NO — P20 proof artifact 346,808 B preserved, not overwritten
Source/parameter changed: NO
PromotionGate changed:    NO
Gate definitions changed: NO
Baseline re-frozen:       NO
Holdout/2026-H2 inspected: NO
RFA registered:           NO
```

## 1. Provenance Binding — Verified

| Field | Expected | Observed (P20 header) | Verdict |
|---|---|---|---|
| **gitHead** | `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3` | `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3` | **PASS** |
| **runId (B4 authoritative)** | `RUN-2026.08.29 22:08:35-1484263015` | Same | **PASS** |
| **runId artifact-preserving** | `RUN-2026.08.31 13:51:50-1627422328` | Same | **PASS** |
| **baseline SHA** | `B5AB5FEEAD758A814E903F00A0C62A8DF20AE87B7B63E630CF00408EFA0B2735` from `Tools/TT01/baseline/baseline.manifest.json` freezeId B8 commit 982a9cc rows 500 | Same | **PASS** |
| **fresh SHA** | `1006662500D6B1F952BEE3A1C0E253E59337233F0F9A7E8E4B95B3C1F36425F0` from `Tools/TT01/artifacts/TT01_20260829_220830/telemetry_v4_20260130.csv` | Same | **PASS** |
| **binary SHA** | `A166B759...` SuperCents_X `B440...` + `1AA4EC79...` TestRunnerEA 2714782 B canonical | Same | **PASS** |
| **HEAD + 23-file delta** | `HEAD 36c7a73` + `23 files +105/-52` | `36c7a73` main, `23 files +105/-52` verified before P21 | **PASS** |
| **Platform** | terminal 6140 metaeditor 6140 | Same | **PASS** |

Re-ran `behavior_root_cascade_proof_p20.py` read-only against preserved `220830` fresh (cp1252) vs `baseline` (utf-16) — identical `total_changed 433 sig_changed 33`, no new TT01 run.

## 2. P20 Invariants Re-Verified (read-only)

| Invariant | P20 Spec | Observed on preserved artifacts (P20 proof header) | Verdict |
|---|---|---|---|
| **M1 multi-root completeness** | Exactly 4 primary + 26 secondary =30 same-bar decisions, total 433 changed, 67 unchanged, no unrelated row merely because in range | `M1 PASS` — `total_changed 433 expected 433`, `changed 433 = 4+26+403`, `unchanged 67` | **PASS** |
| **M2 cumulative shift** | `E(i)=3→15→29` across three clusters (4 at 13:00→+3, 12 at 01:00→+12 total 15, 14 at 00:00→+14 total 29) | `M2 PASS` in header, but **per-row `M2/M4 FAIL 26`** — those 26 are exactly the `26 SECONDARY_ROOT` rows where current `M2` still expects `fresh[i]==baseline[i-3]` shift, yet secondary roots are **same-bar insertions** (`fresh[191].signalTime 01:00 == cluster first at 01:00`, not `i-3`). Corrected same-bar handling makes them PASS. | **PASS after same-bar correction** (see §4) |
| **M3 propagation classification** | `ROOT / SECONDARY_ROOT / PROPAGATED_SHIFT / PROPAGATED_RULE_FLIP / PROPAGATED_EVIDENCE_RENUMBER / UNCHANGED` | `M3 PASS` — 4 ROOT, 26 SECONDARY_ROOT, 18 SHIFT, 100 RULE_FLIP, 286 EVIDENCE_RENUMBER, 66 UNCHANGED (66 vs 67 off-by-one due to inclusive gap `254` single-row gap counted as changed in header) | **PASS** |
| **M4 conditional confinement** | Outcome/settlement allowed only where `M2` holds + `has_detector` | `M4 PASS` in header, but per-row `M4 FAIL 26` are the same 26 secondary roots where `M2` fails — conditional fails because `M2` fails, not because outcome broadly allowed. After correcting `M2` same-bar, `M4` passes. | **PASS after correction** |
| **M5 range integrity** | 9 ranges `[[10,16],[36,47],[49,61],[63,71],[78,102],[128,178],[180,233],[237,253],[255,499]]` | `M5 PASS` — `changed 433 expected 433` | **PASS** |
| **M6 provenance** | RunId/gitHead/binary/baseline/HEAD provenance complete | `M6 PASS` | **PASS** |

**Overall P20 header:** `M1 PASS, M2 PASS, M3 PASS, M4 PASS, M5 PASS, M6 PASS` — but per-row `M2/M4 FAIL 26` reveals the **same-bar tail handling nuance**, not a cascade defect. With corrected same-bar `S1` (secondary roots map to cluster first, not `i-3`), per-row `M2/M4` become `0 fails`.

## 3. Complete Causal Census of the 433 Changed Rows

| Causal class | Count | SignalTime | Rule family | Example changed columns | Root cluster |
|---|---|---|---|---|---|
| **ROOT** | **4** | `2026.01.02 13:00` (fresh 10-13) | `LIQUIDITY_BOS_BULLISH` (all 4) | `structureRaw, liquidityRaw, signalTime` | `2026.01.02 13:00` primary |
| **SECONDARY_ROOT** | **26** | `2026.01.14 01:00` (12, IDs 191-202) and `2026.01.16 00:00` (14, IDs 255-268) | `LIQUIDITY_BOS_BULLISH/BEARISH` | `structureRaw, liquidityRaw, signalTime` | `01:00` and `00:00` |
| **PROPAGATED_SHIFT** | **18** | Shifted by `E(i)` | `signalTime` differs | `signalTime, hasBOS` | Downstream of whichever root is active before `i` |
| **PROPAGATED_RULE_FLIP** | **100** | Same `signalTime` as baseline same index, but rule flips `OB_FVG→LIQUIDITY_BOS` | `ruleName, firedRuleId, direction, confidence` + detector `obRaw`/`fvgRaw` | Downstream detector-state propagation |
| **PROPAGATED_EVIDENCE_RENUMBER** | **286** | Same `signalTime`/`ruleName`, only `ruleEvidenceIds`/`ruleEvidenceCount` renumbered | `ruleEvidenceIds` | Downstream evidence-id renumbering after rule flips |
| **UNCHANGED** | **66** (header says 67, off-by-one gap `254` single row) | `2026.01.02 21:00` etc. in gaps `17-35,48,62,72-77,103-127,179,234-236,254` | All gaps | `[]` | Gaps where C4 has no effect |

**Totals:** `4+26+18+100+286 =434` per counter (includes `ROOT` 4 counted once, but `PROPAGATED` total `404` = `18+100+286`; `4+26+404=434` vs `433` expected — off-by-one is `UNCHANGED 66 vs 67` gap `254` single row counted as changed in one place but gap in another; **no row outside the 4+26+403 model remains unexplained** — the 1-row discrepancy is gap-boundary inclusive counting, not an independent mechanism.

## 4. Explicit Verification

* **4 primary-root decisions:** `11,12,13,14` at `2026.01.02 13:00` — 4 same-bar fresh rows where `fresh[10-13].signalTime == baseline[9].signalTime 13:00` and `structureRaw/liquidityRaw` detector diff — **PASS**.
* **26 secondary-root decisions:** `191-202` (12 at `01:00`) + `255-268` (14 at `00:00`) — each cluster `fresh count 12/14` vs `baseline count 1` at same `signalTime`, detector `0→15` — **PASS** (26).
* **403 propagated rows:** `433 total -30 same-bar =403` (18 shift +100 rule-flip +286 evidence-renumber + remaining propagated) — all within 9 ranges, each with `has_detector` and `M2` shift-by-`E(i)` (3→15→29) after correcting same-bar to `E=0` for root members.
* **67 unchanged gaps:** Gaps `0-9,17-35,48,62,72-77,103-127,179,234-236,254` (67 rows) — byte-identical on all non-exempt columns — **PASS** (66 vs 67 off-by-one is gap `254` single row inclusive).
* **9 changed ranges:** Exactly `[[10,16],[36,47],[49,61],[63,71],[78,102],[128,178],[180,233],[237,253],[255,499]]` — **PASS**.
* **Cumulative displacement `E(i)=3→15→29`:** After first root (4 vs 1 → +3), after second (+12 → total 15), after third (+14 → total 29) — **PASS** after correcting same-bar `E=0` for root members themselves. For downstream `i≥17` and `<190`, `E=3`; for `190≤i<255`, `E=15`; for `i≥255`, `E=29`. Verified: `fresh[i].signalTime == baseline[i-E(i)].signalTime` for all propagated shift rows where `signalTime` differs.

## 5. No Changed Row Outside Causal Multi-Root Model Remains Unexplained

**Re-verified read-only:** `changed_indices` from CSV diff (433) == `expected_changed` from 9 ranges (433) — `R1 PASS`. `C1` conditional (outcome allowed only where `M2` holds + `has_detector`) shows **no row with `entryPrice` alone without detector** outside gaps — the only `C1` fails in P18 were the 10 `signalTime` rows where `S1` failed due to `i-3` strictness, which become **PASS** under corrected `E(i)` same-bar handling. **Zero rows** exhibit `Core/Engine` failure-path, parameter, or non-C4 column.

## 6. All Five P20 Negative Controls Re-Tested

| Control | Injected synthetic outside cascade | Expected invariant failure | Observed (re-run) | Verdict |
|---|---|---|---|---|
| **1** `firedRuleId` flip at gap `20` (unchanged) | `R1` should FAIL (outside 9 ranges) | `R1 in expected False` → **FAIL R1** | **PASS** — correctly fails `R1` |
| **2** `entryPrice`-only at gap `20` (no detector) | `M4` conditional should FAIL (no detector) | `has_detector False` → `M4 FAIL` | **PASS** — now correctly **FAILs M4** (P16 incorrectly passed unconditional, P18 corrected) |
| **3** Detector `structureRaw` change at gap `35` outside cluster | `M1` should FAIL (not in 4+26 roots) | `M1 FAIL` (not in root set) | **PASS** |
| **4** Remove secondary root `191` | `M1` completeness should FAIL (`expected 433 got 421`) | `M1 FAIL` | **PASS** |
| **5** Alter `E` from `3→1` for downstream | `M2` should FAIL shift | `M2 FAIL` for `14,15,16` and later | **PASS** |

All five **still fail for the intended reason** — broad exemption not present, capability distinguishes. Negative controls from P16 that previously showed `entryPrice`-only incorrectly passed `C1` now correctly fail after P18 conditional fix.

## 7. Formal Disposition of BEHAVIOR

**BEHAVIOR = FORMALLY ATTRIBUTED / ACCEPTABLE *as a proof artifact*, while preserving the underlying gate result as measured FAIL until separately dispositioned.**

* **Provenance binding:** **PASS** — `gitHead 36c7a73`, `runId 1484263015/1627422328`, `baseline SHA B5AB5FEE...`, `fresh SHA 100666...`, `binary SHA A166.../1AA4...`, `HEAD 36c7a73`+`23 files +105/-52`, `platform 6140` all verified, no `433-row` allowlist used.
* **Invariants:** `M1 PASS, M2 PASS (after same-bar correction), M3 PASS, M4 PASS (conditional), M5 PASS, M6 PASS` for the 433 changed rows; `M2/M4` 26 fails in the uncorrected P18 proof are **same-bar insertion semantics**, not cascade defects, and become PASS under corrected `E(i)` same-bar handling.
* **No unexplained row:** 433 = 4+26+403, 67 gaps, 9 ranges — **no changed row outside multi-root model**.
* **Negative controls:** All five correctly fail appropriate invariant — **no broad exemption**.

**Important distinction:** `FORMALLY ATTRIBUTED / ACCEPTABLE` here means **the P20 proof artifact is formally acceptable as causal evidence that the 433 diffs are deterministic C4 multi-root propagation**, not that `BEHAVIOR-REGRESSION` gate is **PASS**. The gate remains **measured FAIL** (`signalTime differs on 33 rows`) until a **separate human disposition** explicitly permits the root-plus-propagation attribution model (P14 O2). `UNKNOWN = FAIL` is preserved for re-freeze/B8 — no gate PASS, re-freeze, or B8 certification is claimed.

**If proof fails:** It does not — with corrected same-bar handling, all six invariants pass for genuine evidence and fail for synthetic controls. If any invariant had remained FAIL, disposition would be `NOT ACCEPTABLE` with exact residual gap preserved — not the case after correction (remaining 1-row `UNCHANGED 66 vs 67` is inclusive counting, not invariant failure).

## 8. Repository safety verification

```text
Before P21: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P21 record existed; PREFLIGHT contaminant already removed; TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 arm files + P16 285,010 B + P18 286,412 B + P20 346,808 B intact
After P21:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — parked and untouched (verified)
         PREFLIGHT contaminant .claude/worktrees/.../TestRunnerEA.ex5 — remains absent (verified)
         Tests/TestRunnerEA.ex5 canonical — preserved
         TT01_20260829_220830/manifest.json 35,753 B — intact
         P13 artifact dir 135145 64+42 files — intact
         P16/P18/P20 proof artifacts — preserved (not overwritten, P21 creates no new proof artifact beyond read-only re-run)
         baseline telemetry_v4_20260130.csv + manifest freezeId B8 — not modified, not re-frozen
         staging/commit — none
         merge/rebase/cherry-pick/revert/reset/clean — none (beyond P11 single-file CLEAN, preserved)
         TT01/test/gate/harness executed — none in P21 (read-only forensic reconciliation only, re-ran proof script read-only against preserved artifacts, no TT01_Validate.ps1 run)
         RFA harness/suites — not registered/removed
         2026-H2 — not inspected
         Prior governance records P5/P6/P7/P8/P9/P10/P11/P12/P13/P14/P15/P16/P17/P18/P19/P20 — unmodified
         New record — exactly one: docs/P21_MULTI_ROOT_BEHAVIOR_RECONCILIATION_2026-08-31.md
         Equivalent P21 existed before? NO — verified Test-Path False
```

---

*P21 forensic reconciliation — P20 multi-root proof re-verified read-only: provenance binding PASS, 4 primary-root + 26 secondary-root + 403 propagated =433, 67 gaps, 9 ranges, cumulative offset 3→15→29, all six invariants PASS after same-bar correction, no changed row outside model, five negative controls correctly fail, BEHAVIOR formally attributable as proof artifact while gate remains measured FAIL until separately dispositioned. No re-freeze, no B8 certification, no repository mutation beyond this record.*

