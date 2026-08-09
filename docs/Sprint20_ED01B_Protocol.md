# Sprint 20 — ED01-B Protocol: Liquidity vs Non-Liquidity Conditional Expectancy

Status: FROZEN 2026-08-09 (execution amendments recorded in section 13)
Scope owner: entry-decision research, second measurement milestone (ED01-B)
Predecessor: ED01-A (frozen 2026-08-09, all floor deltas KEEP — B8 retained)

## 1. Purpose and scope

ED01-B asks a direct question about the signal space that ED01-A exposed:

> **Do decisions produced by the LIQUIDITY rule family carry a materially
> different conditional expectancy than decisions produced by the other rule
> families, after conditioning on the same entry funnel?**

This is an analysis-only milestone:

- **In scope:** conditional-expectancy comparison on the frozen B8 population;
  statistical evidence; verdict. No production behavior change, no floor
  change, no new rules.
- **Out of scope:** floor tuning (ED01-A showed confidence is discrete — floor
  deltas are switches; ED01-B does not re-litigate them), detector logic,
  rendering, execution, telemetry schema.
- **Explicitly NOT a floor experiment:** the +0.05 meaningful-delta threshold
  registered in ED01-A applies to floor sensitivity and is NOT inherited here
  (see section 7 for the ED01-B effect-size criterion).
- **Outcome caveat (declared, unchanged from ED01-A):** the replay outcome
  simulation uses the legacy fixed-RR builder (DD04 note). `rMultiple` reflects
  fixed-RR outcomes; the DD04 opposing-liquidity TP path is not in the sim.
  ED01-B measures conditional expectancy under fixed-RR outcomes only.
- **Data:** the frozen ED01-A CONTROL artifacts are the complete dataset. No
  new terminal runs are required or permitted.

## 2. Guardrails (non-negotiable)

1. **B8 remains canonical.** ED01-B uses the B8 configuration verbatim (no
   `ED01_Floor*` overrides, EntryMode=2, weights 25/20/15/15/15/10).
2. **Analysis-only.** No production code change, no input change, no baseline
   transition, no re-freeze. Any verdict that later warrants an implementation
   goes through the normal TDD + TT01 + decision path in a later milestone.
3. **One question per experiment.** The primary comparison is fixed
   (LIQUIDITY vs pooled NON-LIQUIDITY). Per-family decomposition is for
   explanation, not for fishing for a winner.
4. **Pre-registration.** Population, estimator, effect-size threshold, and
   KEEP/REJECT/DEFER criteria are fixed in this document before analysis;
   results do not move the goalposts.
5. **No threshold reuse by habit.** The ED01-B effect-size criterion is defined
   explicitly in section 7 with its own rationale.

## 3. Population (frozen B8, exact definition)

- **Source:** `Tools/ED01/artifacts/<FILE>/CONTROL/telemetry_v4_*.csv`
  (frozen ED01-A CONTROL runs; `configFingerprint` =
  `3005138848403243456` — the B8 baseline fingerprint, already verified).
  Files: `EURUSD_H1`, `GBPJPY_H1` (decision files), `EURUSD_M15`
  (evidence-only).
- **Window:** 2026.04.05 → 2026.07.05 (ED01-A screening window, amendment
  13.1).
- **Row filter (exact):**
  - `newDecision == "1"` only (NEW-mode qualified decisions). Legacy-only
    rows (`newDecision == "0"`) are excluded entirely.
  - Family assignment: `ruleName` → family via the frozen GR01 `RULE_FAMILY`
    map (LIQUIDITY_BOS_* → LIQUIDITY; OB_FVG_* → FVG; BOS_OB_* → BOS;
    CHOCH_OB_REVERSAL → CHOCH; anything else, including empty `ruleName` →
    UNKNOWN).
  - Realized-outcome metrics use settled `rMultiple` on rows with
    `outcome in ("1","2","3")`. Censored rows (`outcome == "0"`, open at
    window end) are excluded from R statistics and reported as `nOpen`.
- **Grouping (fixed):**
  - **LIQUIDITY** = all qualified decisions with family LIQUIDITY.
  - **NON-LIQUIDITY (pooled)** = BOS + FVG + CHOCH + ORDER_BLOCK + UNKNOWN.
    Pool membership is pre-registered and fixed; it does not change based on
    observed sample sizes (a family with zero rows still belongs to the pool).
    Families with n < 50 in a file are reported separately (noise floor,
    consistent with ED01-A) but their rows remain in the pooled group.
- **No new runs.** All inputs already exist; ED01-B is a pure CSV analysis.

## 4. Hypothesis (pre-registered)

- **H1 (research):** LIQUIDITY decisions have materially different conditional
  expectancy than NON-LIQUIDITY decisions: |Δ Mean R| ≥ 0.10 (section 7).
- **H0 (null):** |Δ Mean R| < 0.10 — no material difference; liquidity carries
  no distinct conditional edge under the frozen funnel.

## 5. Primary metric and estimator

- **Primary metric:** Δ Mean R = Mean R(LIQUIDITY) − Mean R(NON-LIQUIDITY),
  computed per file.
- **Bootstrap 95% CI on Δ (pre-registered):** paired day-stratified bootstrap,
  10,000 resamples, fixed seed (20260809), on the SAME estimator family as
  ED01-A:
  - Resample decision-days with replacement (day = date part of `timestamp`).
  - Each sampled day contributes its LIQUIDITY rows and its NON-LIQUIDITY rows;
    the pooled mean-R difference over the sampled rows is one bootstrap draw.
  - CI = 2.5/97.5 percentiles.
  - **Auxiliary estimator (reported, not gating):** mean of per-day mean-R
    differences (daily-mean view), same resampling. If the two estimators
    disagree on sign with the CI excluding 0 in one and not the other, the
    verdict is DEFER (instability, section 8).
  - Days with rows in only one group are included (unpaired days contribute
    their single group's rows — the bootstrap pools per sampled day);
    require ≥ 10 paired days with rows in BOTH groups, else DEFER.

## 6. Secondary metrics (reported, not decision-gating)

Per group (LIQUIDITY / NON-LIQUIDITY / each family), per file:

- Sample size (qualified n, closed n, nOpen censored)
- Win rate (WIN / (WIN + LOSS), BE excluded — GR02 convention)
- Mean R, median R, R quantiles (25/75), R distribution summary
- Outcome distribution (WIN/LOSS/BREAKEVEN counts)
- Confidence distribution (newConfidence per group/family)
- Drawdown proxy: max drawdown of the cumulative R sequence (informational)
- M15: identical statistics, reported as evidence only
- Informational cross-check: the TT01 B8 baseline replay (500 rows, 2026-01)
  with the same grouping, if sample sizes permit per-family n ≥ 50

## 7. Effect-size criterion (pre-registered, not inherited)

| Threshold | Value | Rationale |
|---|---|---|
| Minimum meaningful \|Δ Mean R\| | **0.10** | 0.10 R is the pre-registered minimum practical effect considered large enough to justify prioritizing liquidity-specific entry research. It represents 10% of one unit of risk per trade and is deliberately larger than the ED01-A +0.05 floor-sensitivity threshold, which was found to be within the experiment's noise discipline. A claim of "materially different" expectancy must clear the noise floor by a margin — this criterion does, by construction (pre-registered before any ED01-B result existed). |
| CI requirement | 95% bootstrap CI excludes 0 | Same discipline as ED01-A. |
| Stability | Direction agrees in **2/2 H1 files** (EURUSD_H1, GBPJPY_H1) | Same hierarchy as ED01-A §12.1; M15 cannot rescue or veto. |
| Minimum n | ≥ 50 closed rows per group per decision file | Same noise floor as ED01-A §7; below this the file is report-only. |
| Estimator agreement | Pooled and daily-mean estimators must not conflict (section 5) | Guards against count-asymmetry artifacts. |

## 8. Pre-registered decision rules

- **EVIDENCE FOR LIQUIDITY (distinct positive edge):** Δ ≥ +0.10 on the
  primary file (EURUSD_H1), CI excludes 0, 2/2 H1 direction agreement, n ≥ 50
  per side in both decision files, estimators agree, AND the conclusion holds
  with UNKNOWN excluded from the NON-LIQUIDITY pool (robustness variant,
  section 9). Verdict records: evidence for liquidity-specific entry
  experiments in a later milestone.
- **EVIDENCE AGAINST LIQUIDITY (distinct negative edge):** Δ ≤ −0.10 with CI
  excluding 0 and 2/2 H1 agreement, same robustness rule. Verdict records:
  liquidity receives no special treatment.
- **REJECT / NO DISTINCT LIQUIDITY EDGE:** |Δ| < 0.10 on EURUSD_H1, OR CI
  includes 0, OR direction disagrees across the two H1 files.
- **DEFER:** n < 50 per side in a decision file, OR fewer than 10 paired days,
  OR pooled/daily-mean estimator conflict, OR the verdict flips when UNKNOWN
  is excluded (difference is UNKNOWN-driven, not liquidity-driven), OR the
  difference is confined to one sub-family (see decomposition, section 9).
- No production change occurs under ANY verdict in this milestone. The verdict
  only guides the ED01 sequence (which liquidity-specific entry experiments
  are worth designing).

## 9. Decomposition (explains the pooled result, does not gate alone)

- Per-family table: LIQUIDITY vs BOS / FVG / CHOCH / ORDER_BLOCK / UNKNOWN —
  Δ Mean R and 95% CI each (informational).
- **UNKNOWN-excluded robustness (gating):** the primary comparison is
  recomputed with UNKNOWN rows removed from NON-LIQUIDITY. If the verdict
  changes sign or falls below 0.10, the verdict is DEFER with the reason
  "difference is UNKNOWN-driven" (UNKNOWN's known poor expectancy must not
  manufacture a liquidity edge).
- **Sub-family concentration check (gating):** if removing any single
  NON-LIQUIDITY family flips the verdict, the difference is confined to one
  sub-family → DEFER.

## 10. Engineering gates (analysis milestone)

1. **No compile step:** no production or test code changes.
2. **Data integrity:** every CONTROL artifact must carry the B8 fingerprint
   (`3005138848403243456`) and a single fingerprint per run (constancy);
   row-level sanity: CONTROL total rows match the frozen ED01-A analysis
   (EURUSD_H1 1,558; GBPJPY_H1; EURUSD_M15 6,239 — verified in ED01-A).
3. **Determinism:** analyzer seed fixed; rerun reproduces identical CIs.
4. **Audit:** the analyzer's group assignment must reproduce the ED01-A
   per-family counts for CONTROL (family_of mapping is the frozen GR01 map).

## 11. Deliverables

- `Tools/ED01/ED01_B_Analyze.py` — pre-registered analyzer (population
  filter, group assignment, pooled + daily-mean day-stratified bootstrap,
  decomposition, robustness variants, decision rules).
- `Tools/ED01/results_ED01B.json` — per-file statistics and verdict inputs.
- `docs/Sprint20_ED01B_Decision.md` — verdict table with evidence, after
  analysis (mirrors ED01-A decision doc).
- Ledger/plan registration only if a later milestone implements something.

## 12. Sequence

1. Freeze this protocol (status → FROZEN, section 13 records amendments).
2. Implement `ED01_B_Analyze.py` (analysis tooling only; no production
   impact) and self-check it against the frozen ED01-A CONTROL counts.
3. Run the analysis on the frozen artifacts.
4. Produce `docs/Sprint20_ED01B_Decision.md` with the verdict.
5. No code change; ED01 sequence continues with the verdict as input.

## 13. Amendments

### 13.1 Audit-count precision (2026-08-09, pre-analysis documentation fix)

Section 10 cited decided-row totals (EURUSD_H1 1,558; EURUSD_M15 6,239)
inherited from the ED01-A decision doc, where they were used for the OB
inertness check. The ED01-B analyzer audits the **qualified-population and
per-family closed counts** from the frozen ED01-A analysis
(`Tools/ED01/results_3mo.json`), reproduced exactly:

| File | Qualified (nPop) | Closed per family (LIQ/FVG/BOS/CHOCH/UNKNOWN) | Closed total |
|---|---|---|---|
| EURUSD_H1 | 1,468 | 607 / 318 / 378 / 0 / 117 | 1,420 |
| GBPJPY_H1 | 236 | 96 / 39 / 59 / 0 / 23 | 217 |
| EURUSD_M15 | 5,981 | 1,694 / 2,092 / 2,095 / 1 / 49 | 5,931 |

No population, metric, threshold, or decision rule changed; this amendment
only pins the exact audit constants used by the analyzer's self-check.

### 13.2 Fingerprint gate correction (2026-08-09, pre-analysis audit fix)

Section 10's "every CONTROL artifact must carry the B8 fingerprint
(3005138848403243456)" assumed one fingerprint across files. The fingerprint
canonical string includes `symbol` and `timeframe`
(`Telemetry/ConfigFingerprint.mqh:91-92`), so each file has its own
default-config (B8-equivalent) fingerprint, verified identical across the
3-month and 6-month CONTROL batches:

| File | CONTROL fingerprint (frozen) | B8 identity evidence |
|---|---|---|
| EURUSD_H1 | `3005138848403243456` | equals the TT01-verified B8 baseline |
| GBPJPY_H1 | `14617585492269479818` | same value in 3-month and 6-month CONTROL runs |
| EURUSD_M15 | `13548296177162108249` | same value in 3-month and 6-month CONTROL runs |

Audit gate (hard): single fingerprint per run; EURUSD_H1 must equal the B8
baseline; GBPJPY_H1 and EURUSD_M15 must equal the per-file values above AND
match the 6-month archive CONTROL runs (config determinism across batches).
No metric, threshold, or decision rule changed.
