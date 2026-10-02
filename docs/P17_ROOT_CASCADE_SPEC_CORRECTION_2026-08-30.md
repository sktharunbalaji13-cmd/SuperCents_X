# P17 — Root-Cascade Proof Specification Correction

Status: **P17 COMPLETE — SPECIFICATION CORRECTION ONLY · NO IMPLEMENTATION · NO TT01 EXECUTION · NO RE-FREEZE · B8 NOT CERTIFIED**
Date: 2026-08-30
Type: Read-only forensic correction of the P16 proof-capability defects against the P15 specification. No production .mq5/.mqh logic, parameters, PromotionGate, TT01 gate definitions, baseline, or existing artifacts modified; no TT01 execution; no holdout/research/M1/DISC-C1/Sprint26 access. Single governance/specification record.
Authorization boundary: P17 per P16 validation results (S1 same-bar insertion semantics, C1 conditional column confinement). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52. Existing artifacts `TT01_20260829_220830` and `TT01_20260831_135145` and P16 proof `Tools/TT01/behavior_root_cascade_proof.py` + `Tools/TT01/artifacts/P16_proof_36c7a73_root_cascade/behavior_root_cascade_proof.jsonl` preserved.

## 0. Governing context

**P15 specification (governing):** 33 root IDs with 4× `LIQUIDITY_BOS_BULLISH` same-bar cluster at `2026.01.02 13:00`, 433-row deterministic cascade in 9 contiguous ranges `(10,16)`, `(36,47)`, `(49,61)`, `(63,71)`, `(78,102)`, `(128,178)`, `(180,233)`, `(237,253)`, `(255,499)` interrupted by 67 unchanged rows, five invariants S1/P1/C1/R1/provenance, negative control, explicit acceptance rule.

**P16 implementation and validation results (evidence):**
- `Tools/TT01/behavior_root_cascade_proof.py` (13,967 B) + `Tools/TT01/artifacts/P16_proof_36c7a73_root_cascade/behavior_root_cascade_proof.jsonl` (285,010 B, 501 lines) correctly bound to `gitHead 36c7a73`, `runId 1484263015/1627422328`, `baseline SHA B5AB5FEE…`, `fresh SHA 100666…`, binary SHA `A166.../1AA4...`, `HEAD 36c7a73`+`23 files +105/-52`.
- `total_changed 433 sig_changed 33` confirmed.
- **Defects demonstrated:**
  1. **S1 same-bar insertion semantics:** P16's universal `fresh[i].signalTime == baseline[i-1].signalTime` fails for the tail of the inserted cluster. Header shows `S1_shift_invariant: FAIL` with `S1_fail_rows [14,15,16,191,192,193,194,195,196,197]` — the strict `i-1` rule cannot represent four consecutive `13:00` fresh rows `10-13` plus same-bar tail `14-16` where all share `baseline[9].signalTime 13:00`, not `baseline[i-1]`.
  2. **C1 unconditional outcome-column allowance:** P16 negative control `entryPrice`-only synthetic at unchanged gap row `20` still passed `C1` (`True`) because `entryPrice` is in `OUTCOME_ALLOWANCE` globally — exposes that unconditional `outcome/settlement` allowance would hide a tick-cache-like defect on an unrelated unchanged row. Correct C1 must be conditional.

Both defects are **specification-implementation mismatches, not cascade defects**, and were correctly surfaced by the proof — they do not hide the cascade.

## 1. P16 failure evidence — why original S1/C1 were insufficient

**S1 insufficient:** Universal `fresh[i].signalTime == baseline[i-1].signalTime` assumes a single-position insertion (one extra decision). The actual C4 insertion is **four decisions at one closed bar** (`fresh 10,11,12,13` all `13:00`) plus **same-bar tail** (`14,15,16` also `13:00` — `Liquidity` detector produced 7 decisions at same bar in the 220830 fresh, 3 more than baseline's 1). For `i=11`, `fresh[11].signalTime 13:00 != baseline[10].signalTime 14:00` — fails strict `i-1` but is correct same-bar membership. A universal `i-1` rule would require `fresh[11]` to be `14:00`, which would be wrong. Whitelisting all 433 rows would hide this nuance.

**C1 insufficient:** Unconditional `OUTCOME_ALLOWANCE` (`outcome, rMultiple, barsHeld, exitReason, exitPrice, entryPrice, timestamp` allowed on any row) makes an `entryPrice`-only synthetic change on **unchanged gap row 20** (where `fresh[20]==baseline[20]` on all detector columns) incorrectly PASS `C1`, because `entryPrice` is globally allowed. This would also make a tick-cache-driven `entryPrice` drift without detector change appear acceptable. Correct C1 must allow outcome/settlement columns **only where the row is demonstrably downstream of an admitted root decision and the outcome difference is supported by the authorized payload/ledger/deferral path**.

## 2. Corrected root-aware sequence semantics — replacing universal S1

**Replace:** `fresh[i].signalTime == baseline[i-1].signalTime` for every claimed propagated row.

**With — formally defined root-aware model with four distinct classes:**

* **Root insertion (4 rows):** `i ∈ {10,11,12,13}` — `fresh[i].signalTime == baseline[9].signalTime` (`2026.01.02 13:00`) **and** `fresh[i].decisionId ∈ root_core {11,12,13,14}`. All four share the *same* baseline bar's signalTime, not `i-1`. This proves the C4 closed-bar insertion (forming-bar `time[0]` excluded).

* **Same-bar members of the inserted cluster (3 rows):** `i ∈ {14,15,16}` — `fresh[i].signalTime == baseline[9].signalTime` (still `13:00`) **and** `fresh[i].decisionId ∈ root_shift \ root_core` (`15,16,17`) and `fresh[i].ruleName == LIQUIDITY_BOS_BULLISH` (or same family). These are not downstream propagation; they are **additional members of the same bar's expanded decision set**. They must satisfy **same `signalTime` as root**, not `i-1`.

* **Downstream one-position propagation (remaining 426 rows in 9 ranges excluding 10-16):** For `i` in `{(36,47),(49,61),(63,71),(78,102),(128,178),(180,233),(237,253),(255,499)}` (the 9 ranges minus the root cluster), require `fresh[i].signalTime == baseline[i-3].signalTime` where `3` is the net extra decisions inserted (`4 fresh at 13:00` vs `1 baseline at 13:00` = +3). For indices where the range is non-contiguous due to unchanged gaps, `i-3` automatically skips the gap because gaps are unchanged rows where `fresh[i]==baseline[i]`. More generally: `fresh[i].signalTime == baseline[i - E(i)].signalTime` where `E(i) = number of extra root decisions before i` (`E=3` for `i≥17` after the cluster, `E=0` for `i<10`). This distinguishes **signalTime shift by 3** from **same-bar membership**.

* **Unchanged-gap boundaries:** For `i` in gaps `17-35, 48, 62, 72-77, 103-127, 179, 234-236, 254` etc. (67 rows), require `fresh[i].signalTime == baseline[i].signalTime` **and** `fresh[i]` byte-identical on all non-exempt columns — proves propagation is *non-contiguous*, not broad percentage.

**Not a whitelist:** The 433 rows are still exactly the 9 ranges above; the corrected S1 does not accept any row outside those ranges, and does not accept `87%` allowlist. Each propagated row must satisfy the *specific* `i-3` shift, not any shift.

## 3. Corrected conditional column-confinement semantics — replacing unconditional outcome allowance

**Replace:** `OUTCOME_ALLOWANCE` globally allowed on any row.

**With — explicit causal condition:**

`outcome, rMultiple, barsHeld, exitReason, exitPrice, entryPrice, timestamp` may differ **iff** **both** hold:

1. **Row is demonstrably downstream of an admitted root decision:** `i` is in the 9 changed ranges (hence `S1` holds as corrected above) **and** `fresh[i]` and `baseline[i]` differ on at least one **C4 detector column** (`structureRaw/Weight/Contribution, obRaw/Weight/Contribution, fvgRaw/Weight/Contribution, trendRaw/Weight/Contribution, liquidityRaw/Weight, hasBOS/hasOrderBlock/hasFVG/hasLiquiditySweep, layer*`, `firedRuleId/ruleName` where rule family is detector-derived) — proving the row's detector state is downstream of root.

2. **Outcome difference is supported by authorized payload/ledger/deferral path:** The specific outcome column diff is among those produced by `3ad7cf2` directional TP validation or `b8b52ae/a0f2720` payload/ledger/deferral hoist (for `timestamp/barsHeld/outcome/rMultiple/exitReason/entryPrice/exitPrice`), **and** its magnitude/direction is consistent with those changes (e.g., `barsHeld 2→27` with `timestamp 12:45→12:30` is deferral hoist, not tick-cache).

**Consequence:** An `entryPrice`-only synthetic change on **unchanged gap row 20** (where `fresh[20]==baseline[20]` on all detector columns, `i=20` in gap `17-35`, not downstream, no detector diff) **must FAIL C1** — correctly exposed by P16 negative control. Previously it incorrectly passed because `entryPrice` was globally allowed; corrected C1 now fails as required, distinguishing authorized downstream outcome from unrelated tick-cache drift.

**Authorized C4 detector/rule set remains frozen** as in P15 §4: `structureRaw, structureWeight, structureContribution, obRaw, obWeight, obContribution, fvgRaw, fvgWeight, fvgContribution, trendRaw, trendWeight, trendContribution, liquidityRaw, liquidityWeight, liquidityContribution, hasBOS, hasOrderBlock, hasFVG, hasLiquiditySweep, hasCHOCH, hasProtectedPoint, trendAligned, layerStructural, layerLiquidity, layerConfirmation, layerTotal, layerOrderBlock, layerFVG, fvgClass, fvgSize, fvgStrength, fvgCreatedTime, firedRuleId, ruleName, ruleScore, ruleConfidence, ruleEvidenceCount, ruleEvidenceIds, confidence, direction, validatorResults, newDecision, decisionMatch, directionMatch, legacyConfidence, newConfidence` — outcome allowance only conditionally as above.

## 4. Preserve P15 invariants — unchanged

* **4 ROOT vs 429 PROPAGATED classification:** `ROOT = {10,11,12,13}` (decisionIds 11-14), `PROPAGATED = 433-4 = 429` (remaining changed rows in 9 ranges). Preserved.
* **Nine observed changed ranges:** `(10,16)`, `(36,47)`, `(49,61)`, `(63,71)`, `(78,102)`, `(128,178)`, `(180,233)`, `(237,253)`, `(255,499)` — preserved.
* **67 unchanged gaps:** `0-9,17-35,48,62,72-77,103-127,179,234-236,254` — preserved.
* **Provenance binding:** `runId 1484263015 / 1627422328, gitHead 36c7a73, buildTag, baseline SHA B5AB5FEE..., fresh SHA 100666..., binary SHA A166.../1AA4..., HEAD 36c7a73+23 files +105/-52, platform 6140` — preserved.
* **Negative-control requirement:** Synthetic unrelated change outside 9 ranges must fail appropriate invariant(s) — preserved, now corrected to fail `C1` for `entryPrice`-only.
* **No 433-row allowlist:** `433/500 = 87%` exotic exemption remains prohibited.

## 5. Corrected acceptance criteria — when proof becomes formally acceptable

The corrected proof is **formally acceptable** (moves from `EXPLAINED / NOT FORMALLY ATTRIBUTED` to `FORMALLY ATTRIBUTED / ACCEPTABLE` **as a proof artifact, not as a gate PASS**) iff **all** invariants pass under corrected definitions, without automatically making `BEHAVIOR-REGRESSION` gate PASS:

1. **Root identification PASS** — 4 root_core and 33 root_shift IDs exactly match P12 census, first divergence index 10 proven via `fresh[10].signalTime == baseline[9].signalTime` (insertion) and `fresh[10-13]` all `13:00`.
2. **Sequence-shift invariant S1 PASS under corrected root-aware model** — `S1` as defined in §2 above: root insertion `fresh[10-13]==baseline[9]`, same-bar members `14-16` same, downstream `fresh[i]==baseline[i-3]` for `i` in later ranges, unchanged gaps `fresh[i]==baseline[i]`. Current P16 universal `i-1` showed `S1 FAIL` on `[14,15,16,191...]` precisely because it was too strict — corrected model must show `S1 PASS` for all 433.
3. **Propagation invariant P1 PASS** — 429 propagated rows classified as `PROPAGATED_*` with deterministic displacement proof (signalTime shift by 3 plus detector diff), 4 as `ROOT`, no `PROPAGATED` without `S1`.
4. **Column-confinement C1 PASS with conditional causal authorization** — every propagated row's diff_cols ⊆ `C4 set` **or** (`C4 set` plus conditionally allowed `OUTCOME_ALLOWANCE` only where `S1` holds and detector diff exists). Unrelated `entryPrice`-only synthetic at gap `20` must **FAIL** C1.
5. **Range-contiguity R1 PASS** — 9 ranges and 67 gaps proven, no percentage allowlist.
6. **Negative control FAILs as expected** — synthetic `firedRuleId` flip at gap `20` fails `R1` (outside 9 ranges) and `S1`; synthetic `entryPrice`-only at gap `20` fails `C1` (conditional).
7. **Provenance complete** — runId/gitHead/binary hashes/baseline SHA match, HEAD `36c7a73`+`23 files`.

**Gate PASS is *not* automatic:** Even when formally acceptable as a *proof artifact*, `BEHAVIOR-REGRESSION` gate remains **FAIL** until doctrine explicitly permits the root-plus-propagation attribution model (P14 O2). The artifact proves *attribution*, not *acceptance* — re-freeze and B8 certification still require separate human disposition per P10 §10 entry criteria (PREFLIGHT GREEN + formal attribution + full ACTIVE/SETTLEMENT/INTEGRITY censuses + duplicate disposition).

**Explicitly preserve:**
```
UNKNOWN = FAIL;
no 433-row exemption (87% allowlist prohibited);
no gate-definition change;
no source/parameter/PromotionGate modification;
no re-freeze;
no B8 certification;
no TT01 execution (specification correction only);
no artifact overwrite (new proof artifact uniquely named, preserve 220830/135145/ P16 proof);
no 2026-H2 access;
BEHAVIOR remains NOT ACCEPTABLE until doctrine permits root-plus-propagation model.
```

## 6. Exact next implementation requirements

**P17 corrects specification only. No implementation, TT01 execution, gate PASS, re-freeze, or B8 certification is authorized.**

Next separately authorized step, if pursued, must:
- Implement corrected S1 root-aware sequence logic (two-tier root + shift-by-3 downstream + gap identity) in `Tools/TT01/behavior_root_cascade_proof.py` (update `S1` function, not trading logic).
- Implement corrected C1 conditional allowance (outcome columns allowed only where `S1` holds and detector diff exists) in same file.
- Re-run **only** `behavior_root_cascade_proof.py` (read-only validation, no `TT01_Validate.ps1` run) to regenerate `Tools/TT01/artifacts/P16_proof_36c7a73_root_cascade/behavior_root_cascade_proof.jsonl` **or** new uniquely named `P17_proof_36c7a73_root_cascade/behavior_root_cascade_proof.jsonl` with same run identity, without overwriting `220830` or `135145`.
- Verify corrected invariants all PASS and negative controls correctly FAIL, without claiming BEHAVIOR gate PASS.

## 7. Repository safety verification

```text
Before P17: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P17 record existed; PREFLIGHT contaminant already removed; TT01_20260829_220830 (35,753 B) + TT01_20260831_135145 (64+42 arm files) + P16 proof 285,010 B intact
After P17:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — parked and untouched (verified)
         PREFLIGHT contaminant .claude/worktrees/.../TestRunnerEA.ex5 — remains absent (verified)
         Tests/TestRunnerEA.ex5 canonical — preserved (2,714,782 B)
         TT01_20260829_220830/manifest.json 35,753 B — intact
         P13 artifact dir 135145 64+42 files — intact
         P16 proof script Tools/TT01/behavior_root_cascade_proof.py 13,967 B — preserved (not modified)
         P16 proof artifact 285,010 B — preserved (not overwritten)
         baseline telemetry_v4_20260130.csv + manifest freezeId B8 — not modified, not re-frozen
         staging/commit — none
         merge/rebase/cherry-pick/revert/reset/clean — none
         TT01/test/gate/harness executed — none in P17 (read-only correction only)
         RFA harness/suites — not registered/removed
         2026-H2 — not inspected
         Prior governance records P5/P6/P7/P8/P9/P10/P11/P12/P13/P14/P15/P16 — unmodified
         New record — exactly one: docs/P17_ROOT_CASCADE_SPEC_CORRECTION_2026-08-30.md
         Equivalent P17 existed before? NO — verified Test-Path False
```

---

*P17 specification correction — P16 defects precisely identified (S1 universal i-1 too strict for 4× same-bar insertion + tail, C1 unconditional outcome allowance hides tick-cache-like defect), corrected root-aware sequence semantics and conditional column-confinement defined, invariants and negative-control expectations fixed, acceptance criteria preserved as proof-only, no implementation/TT01 execution/gate PASS/re-freeze/B8 certification authorized. Implementation requires separate authorization.*

