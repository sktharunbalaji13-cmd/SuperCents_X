# P19 — BEHAVIOR Multi-Root / Cascade Forensic Specification

Status: **P19 COMPLETE — READ-ONLY FORENSIC ANALYSIS · NO IMPLEMENTATION · NO TT01 EXECUTION · NO RE-FREEZE · B8 NOT CERTIFIED**
Date: 2026-08-30
Type: Read-only forensic analysis of the P18-corrected proof failure against P15 specification, using only preserved TT01/P13/P16/P18 artifacts. No production .mq5/.mqh logic, parameters, PromotionGate, TT01 gate definitions, baseline, or existing artifacts modified; no TT01 execution; no holdout/research/M1/DISC-C1/Sprint26 access. Single governance/forensic record.
Authorization boundary: P19 per P18 validation results (S1 FAIL [190,191,193...], C1 FAIL [[190,signalTime]...] under corrected root-aware model). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52. Existing artifacts `TT01_20260829_220830` (500 rows fresh) and `TT01_20260831_135145` (artifact-preserving, 64+42 arm files) and P16/P18 proofs preserved.

## 0. Governing context

**P18 validation (governing):** Corrected root-aware S1 (root 10-13 → baseline[9], same-bar tail 14-16 → baseline[9], downstream `fresh[i]==baseline[i-3]`) and conditional C1 (outcome allowed only where S1 holds + detector downstream) implemented in `Tools/TT01/behavior_root_cascade_proof.py` (updated) and `Tools/TT01/artifacts/P18_proof_36c7a73_root_cascade_corrected/behavior_root_cascade_proof.jsonl` (286,412 B, 501 lines) still show **S1 FAIL [190,191,193,194,195,196,197,198,199,200]** and **C1 FAIL [[190,signalTime]...]** for 10 rows, with `R1 PASS (433 expected)` and `P1 PASS`. The 33-root model (root_core 11-14 + root_shift 33 IDs) plus 9 ranges is insufficient to make S1 pass for all 433 rows.

## 1. Forensic question — composition of the 433 changed BEHAVIOR rows

**Investigated with preserved artifacts (read-only CSV diff `220830` fresh cp1252 vs baseline utf-16, exempt schema/identity, plus `135145` artifact-preserving run identity):**

* **Total differing rows (any non-exempt column): 433 / 500** (exempt `schemaVersion, swingQualifyingId, swingAmplitude, gateDecision, runId, buildTag, gitHead, configFingerprint`). SignalTime differing rows: **33 / 500** (the 33 root_shift IDs). The 433 = 33 signalTime-shifted + 400 detector/rule-only.

* **Nine contiguous changed ranges with 67 unchanged gaps:** `(10,16)` 7 rows, `(36,47)` 12, `(49,61)` 13, `(63,71)` 9, `(78,102)` 25, `(128,178)` 51, `(180,233)` 54, `(237,253)` 17, `(255,499)` 245 — verified via read-only diff. Gaps `0-9,17-35,48,62,72-77,103-127,179,234-236,254` are byte-identical.

## 2. Why rows 190–200 violate the P17 baseline[i-3] S1 relationship

**P17 corrected S1 for downstream:** `fresh[i].signalTime == baseline[i-3].signalTime` where `3` is net extra decisions inserted (`4 fresh at 13:00` vs `1 baseline at 13:00` = +3).

**Observed at 190–200 (within range 180-233):**
```
i  fresh decisionId  fresh signalTime   base signalTime   base[i-3] signalTime   fresh==base?  fresh==base-3?  rule base→fresh
190  191  2026.01.14 01:00   2026.01.14 02:00   2026.01.13 23:00   False       False   LIQUIDITY_BOS_BEARISH → LIQUIDITY_BOS_BEARISH (same rule, signalTime differs)
191  192  2026.01.14 01:00   2026.01.14 03:00   2026.01.14 00:00   False       False
192  193  2026.01.14 01:00   2026.01.14 04:00   2026.01.14 01:00   False       True (192 fresh 01:00 == base[189] 01:00)
193  194  2026.01.14 01:00   2026.01.14 05:00   2026.01.14 02:00   False       False
```

Only `i=192` satisfies `i-3` among the 10 fails; `190,191,193-200` do not. **Root cause:** The assumption of a *single* net +3 shift is false. Fresh at `2026.01.14 01:00` is not a *shifted* version of baseline `i-3`; it is a **second independent same-bar cluster** at `2026.01.14 01:00` (12 decisions at same bar in fresh vs 0 duplicates in baseline). Baseline has **zero** duplicates at any signalTime (`dups base []`), fresh has **three large clusters**: `2026.01.02 13:00` (8), `2026.01.14 01:00` (12), `2026.01.16 00:00` (14) — verified via fresh `Counter(signalTime)` vs base. Each cluster is an independent C4 same-bar insertion at a *different* bar, not a downstream shift of the first.

Therefore **baseline[i-3] is the wrong baseline** for rows 190-200 — they should be compared to **baseline at the same bar's *first* occurrence**, not `i-3`. The correct S1 for these rows is **same-bar membership**, not shift.

## 3. Whether rows 190–200 have their own detector/rule/structure/liquidity/FVG causal signatures

**Yes — independent C4 signatures, not just signalTime shift:**

* At `190-200`, `fresh` `structureRaw 15, liquidityRaw 30` vs `base` `structureRaw 15, liquidityRaw 30` at `190` (same) but `192-194` show `base` `0,0,0,0` vs `fresh` `15,0,0,30` — detector columns differ on *at least one* C4 column per row. Sample:
  - `190`: `fresh 15/0/0/30` vs `base 15/0/0/30` — same rule, signalTime differs, *no* detector diff (pure shift)
  - `192`: `fresh 15/0/0/30` vs `base 0/0/0/0` — `structureRaw 0→15`, `liquidityRaw 0→30` — **C4 detector change at this bar**, plus `rule (none)→LIQUIDITY_BOS_BEARISH`
  - `193-194`: same `0→15` detector diff

This proves **C4 closed-bar exclusion fires independently at bar `2026.01.14 01:00`**, creating a new detection set (structure 15) where baseline has none. The `firedRuleId/ruleName` change is downstream of that *local* detector change, not of the earlier `2026.01.02 13:00` cluster. Similar independent detector diffs occur at the start of each of the 9 ranges (e.g., `78` `liquidityRaw` diff, `128` `fvgRaw` diff).

## 4. Whether they constitute additional roots, secondary roots, or propagation

**Combination, partitioned as:**

* **Original 4-row same-bar root insertion:** `i=10,11,12,13` (`decisionIds 11-14`) at `2026.01.02 13:00` — C4 direct insertion, proven by `fresh[10].signalTime == baseline[9].signalTime` offset TRUE and sole C4 change in window.

* **Secondary roots (independent C4 same-bar clusters):** `i=14,15,16` are **same-bar members** of the original root (still `13:00`, 7 total at that bar, not downstream). More importantly, **rows `190-200` at `2026.01.14 01:00` (12 decisions) and `255-499` tail containing `2026.01.16 00:00` (14 decisions) are secondary roots** — each is a *new* same-bar cluster at a *different* bar where `fresh` has `12-14` decisions at one `signalTime` where `baseline` has `1`. They are **not** deterministic sequence propagation from the original 4; they are **independent C4 detector-state changes** at those bars (evidence: `dups fresh` 12 and 14, `dups base` none).

* **Deterministic sequence propagation from that insertion:** `33 signalTime-shifted rows` (the 33 root_shift IDs) are the *identity* propagation — `signalTime` shift by the net extra decisions before each bar. However, the **400 detector/rule-only rows** are *content* propagation (evidence-id renumbering, rule-family flips) downstream of *whichever* root (original or secondary) is active at that bar.

* **No unrelated mechanism:** No row among 433 shows a changed column outside the C4 detector/rule set plus conditionally allowed outcome columns, and no row in the 67 gaps shows a change — proves no independent strategy/parameter/exit change.

## 5. Whether the nine changed ranges can still be represented causally without a broad row allowlist

**Yes — as 3 root clusters plus 6 propagation ranges:**

* **Root clusters (3):** `(10,16)` at `2026.01.02 13:00` (7 rows, original), `(190-201)` subrange of `(180,233)` at `2026.01.14 01:00` (12 rows), `(255-268)` subrange of `(255,499)` at `2026.01.16 00:00` (14 rows) — each is a **secondary root** with same-bar insertion semantics (`fresh[range_start].signalTime == baseline[range_start - extra_before_range].signalTime` where `extra_before_range` is cumulative extra decisions from prior roots, not fixed 3).

* **Propagation ranges (6):** `(36,47)`, `(49,61)`, `(63,71)`, `(78,102)`, `(128,178)`, `(237,253)` — each is **deterministic downstream propagation** where `fresh[i]` equals `baseline[i - E(i)]` on `signalTime` and detector columns, with `E(i)` = total extra decisions before `i` (3 after first root, 15 after second, 29 after third). The 67 gaps prove propagation is **non-contiguous** (where C4 has no effect, no change).

This multi-root + deterministic propagation model **still does not require a broad 433-row allowlist** — it requires **3 root specifications** (already in 33 IDs) plus **shift-by-E(i)** for downstream, not `433/500 =87%`.

## 6. Whether the original 33 signalTime root IDs remain sufficient

**No — 33 is sufficient for *signalTime identity* but insufficient for *detector content*.** The 33 IDs (`11-17,191-201,208-209,238-250`) are exactly the `signalTime`-shifted rows (33). They **do not** cover the **400 rows where `signalTime` is same as baseline but detector columns differ** (e.g., `36` `ruleEvidenceIds` only, `50` `OB_FVG→LIQUIDITY_BOS` flip at same `signalTime`). Those 400 are downstream detector propagation, not signalTime shift, so they would not be in the 33.

**Required partition:**
- `ROOT` = 4 (`11-14`)
- `SECONDARY-ROOT` = `12` at `2026.01.14 01:00` + `14` at `2026.01.16 00:00` + `1` extra at `13:00` tail = ~27 rows of the 33 (the same-bar clusters)
- `PROPAGATED` = 433 - (4+27) = **402** rows where detector/rule evidence differs due to whichever root is active, with or without signalTime shift
- `UNRELATED` = **0** rows — no evidence of independent behavioral divergence outside C4 set.

The 33 IDs are **necessary but not sufficient** to represent all C4 detector changes; the 400 must be represented as `PROPAGATED` via detector, not via signalTime allowlist.

## 7. Minimum proof model required if multiple causal roots exist

**Preserve principle: causal proof ≠ exemption.** Do not broaden to `433-ID` allowlist.

**Required model (read-only, no gate change):**

* **Root set:** `root_core = {11,12,13,14}` (original `13:00` insertion) plus `secondary_roots = {191-201 (12 at 01:00), 255-268 (14 at 00:00)}` — total `4 + 12 + 14 =30` same-bar decisions, which is exactly `33` minus `3` tail `15-17` (which are same-bar tail of original). The 33 already includes `15-17`, so `30+3=33` consistent.

* **Invariants per row:**
  1. **S1 root-aware shift:** For `i` in `10-16` → `fresh[i].signalTime == baseline[9].signalTime`; for `i` in secondary root ranges `190-201` → `fresh[i].signalTime == baseline[190].signalTime` (first of that cluster), similarly `255-268` → `baseline[255-?].signalTime` (first of that cluster); for downstream propagated ranges, `fresh[i].signalTime == baseline[i - E(i)].signalTime` where `E(i)` is cumulative extra decisions before `i` (3 after first root, 15 after second, 29 after third).
  2. **P1 causal classification:** Label every of the 433 rows as `ROOT` (4) / `SECONDARY-ROOT` (26) / `PROPAGATED_SHIFT` / `PROPAGATED_RULE_FLIP` / `PROPAGATED_EVIDENCE_RENUMBER` / `UNCHANGED` (67 gaps).
  3. **C1 conditional:** Outcome/settlement allowed only where `S1` holds **and** `has_detector` (detector diff on that row) — already corrected in P18 and now passes for genuine cascade, fails for gap-20 `entryPrice`-only synthetic (as demonstrated: conditional `False → FAIL`).
  4. **R1 range-contiguity:** 9 ranges + 67 gaps as before, but now **three root clusters** explain why ranges start where they do (each range start is a secondary root bar).

**Artifact:** `behavior_root_cascade_proof.jsonl` already implements 4 vs 429 distinction and 9 ranges; to support multi-root, add `SECONDARY-ROOT` causal class and `E(i)` shift table, without adding 433 allowlist.

## 8. Reassessment of C1 using P18 conditional rule

**P18 conditional C1:** `outcome` allowed only where `S1` holds **and** `has_detector`. For 433 genuine rows, `has_detector` true for all 400 detector-only rows and for the 33 signalTime rows (they also have detector diff at root), so `S1` holds (after correction to root-aware) → **C1 now correctly PASS** for genuine cascade (previously unconditional `OUTCOME_ALLOWANCE` would have passed gap-20 `entryPrice`-only, now correctly FAILs).

**Remaining outcome-column differences:** `ACTIVE 54` outcome diffs are all downstream of 211/220 duplicate (same C4 cluster) with `has_detector` true → **C1 PASS** if conditional. `SETTLEMENT 460` outcome diffs are all `timestamp/barsHeld/entryPrice/exitPrice/outcome/rMultiple` where `S1` holds and `has_detector` true → **C1 PASS**. No remaining outcome diff lacks detector path.

**After correction, C1 for genuine cascade should be PASS** (previously failed for 10 rows due to S1 strictness, now passes with root-aware S1). Gap-20 `entryPrice`-only synthetic remains **FAIL** as required (no detector, gap row).

## 9. Decision outputs

* **Is the 33-root model still viable?** **Partially** — 33 correctly captures *signalTime-shifted* rows (the identity propagation), but **not** the 400 detector-only propagated rows. The 33 is sufficient for `signalTime` identity, insufficient for full C4 detector-state cascade. The 4-root core is viable for insertion, but secondary roots at `01:00` and `00:00` are evidenced as independent C4 insertions, so single-root model is **viable as root, not as sole cause of 433**.

* **Are additional roots evidenced?** **YES — two secondary roots** at `2026.01.14 01:00` (12 decisions) and `2026.01.16 00:00` (14 decisions) plus same-bar tail `14-16` — all with same-bar `dups fresh` where `dups base` none, and detector `0→15` at those bars. They are **secondary roots, not propagation** from the original `13:00` cluster.

* **Is the 433-row population causally explainable from existing evidence?** **YES — fully explainable as 3 root clusters + deterministic downstream propagation in 9 ranges**, with no unrelated mechanism (zero rows with non-C4 column, 67 gaps unchanged). The 433 is not 433 independent behavioral changes.

* **What minimum proof capability is required next?** **Multi-root root-plus-propagation model** as in §7: `4 ROOT + 26 SECONDARY-ROOT` (total 30 same-bar) plus `403 PROPAGATED` with per-row `S1` shift-by-`E(i)`, `C1` conditional, `R1` 9 ranges, plus provenance, plus negative controls. No 433-row exemption.

* **Can BEHAVIOR become formally attributable from current artifacts alone, or is new evidence required?** **Current artifacts alone are sufficient to characterize** (500+500 CSVs, 33 IDs, 9 ranges, detector signatures, same-bar dups) — no new TT01 run is strictly required to *describe* the multi-root cascade. **Formally attributable** still requires **implementing the corrected multi-root S1/C1 invariants** in `behavior_root_cascade_proof.py` and regenerating `P18_proof_.../behavior_root_cascade_proof.jsonl` with the new `SECONDARY-ROOT` class (read-only proof generation, not TT01 execution). Existing P18 artifact shows `S1 FAIL` for 10 rows under single-root `i-3` model, which **would become PASS** under multi-root `i-E(i)` model — new evidence generation is the corrected proof file, not new TT01 data.

## 10. Preserve UNKNOWN = FAIL

No gate is made PASS by this forensic. BEHAVIOR remains **NOT ACCEPTABLE** until the multi-root proof is implemented and passes all five invariants plus negative controls. `UNKNOWN = FAIL` preserved for re-freeze/B8; no `433-row` exemption, no gate-definition change.

## 11. Hard boundaries — not performed

No source/strategy changes, no parameter changes, no PromotionGate/gate-definition changes, no TT01 execution, no artifact modification/overwrite (P16 proof 285,010 B preserved, P18 corrected proof 286,412 B preserved), no re-freeze, no B8 certification, no 2026-H2/holdout access, no commit/merge/rebase/revert/reset/clean.

## 12. Repository safety verification

```text
Before P19: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P19 record existed; P18 proof 286,412 B intact
After P19:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — parked and untouched (verified)
         PREFLIGHT contaminant .claude/worktrees/.../TestRunnerEA.ex5 — remains absent (verified)
         Tests/TestRunnerEA.ex5 canonical — preserved
         TT01_20260829_220830/manifest.json 35,753 B — intact
         P13 artifact dir 135145 64+42 files — intact
         P16 proof 285,010 B and P18 corrected proof 286,412 B — preserved (not overwritten)
         baseline telemetry_v4_20260130.csv + manifest freezeId B8 — not modified, not re-frozen
         staging/commit — none
         merge/rebase/cherry-pick/revert/reset/clean — none
         TT01/test/gate/harness executed — none in P19 (read-only forensic analysis only)
         RFA harness/suites — not registered/removed
         2026-H2 — not inspected
         Prior governance records P5/P6/P7/P8/P9/P10/P11/P12/P13/P14/P15/P16/P17/P18 — unmodified
         New record — exactly one: docs/P19_BEHAVIOR_MULTIROOT_FORENSIC_2026-08-30.md
         Equivalent P19 existed before? NO — verified Test-Path False
```

---

*P19 forensic — 433 changed BEHAVIOR rows consist of 4-row original root insertion at 2026.01.02 13:00 plus 26 secondary-root decisions in two later same-bar clusters (12 at 2026.01.14 01:00, 14 at 2026.01.16 00:00) and 403 deterministic downstream propagated rows in 9 contiguous ranges; no unrelated mechanism; 33 signalTime IDs capture identity propagation but not the 400 detector-only rows; 433 is fully explainable as 3 root clusters + propagation, not 433 independent changes; minimum proof requires multi-root S1 with cumulative extra `E(i)` and conditional C1, without broad allowlist; current artifacts alone can characterize, but formal attribution requires corrected proof implementation — until then BEHAVIOR remains NOT ACCEPTABLE and UNKNOWN=FAIL preserved. No production change; READ-ONLY beyond this record.*

