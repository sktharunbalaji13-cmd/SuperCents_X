# Sprint 20 — ED01-C Protocol: Confidence-Granularity — Within-Family Discrete Level Expectancy

Status: FROZEN 2026-08-09 (execution amendments recorded in section 16)
Scope owner: entry-decision research, third measurement milestone (ED01-C)
Predecessors: ED01-A (frozen 2026-08-09, all floor deltas KEEP), ED01-B
(frozen 2026-08-09, REJECT / NO DISTINCT LIQUIDITY EDGE)

## 1. Purpose and scope

ED01-C asks the one entry-decision question that ED01-A and ED01-B left
unmeasured:

> **Within a rule family, do decisions qualified at the higher discrete
> confidence level carry a materially different conditional expectancy than
> decisions qualified at the lower level?**

The two completed experiments narrowed the search space to exactly this:

- **ED01-A (floors are switches):** confidence is discrete — LIQUIDITY always
  0.60, FVG ∈ {0.35, 0.40}, BOS ∈ {0.40, 0.45} — so floor deltas act as
  switches, not filters, and only two admission boundaries exist per family.
  ED01-A measured the switch POSITIONS (floor deltas) and found them inert or
  within noise. It could not measure whether the LEVELS THEMSELVES carry
  expectancy.
- **ED01-B (pooled comparisons are composition-driven):** liquidity vs pooled
  non-liquidity showed no distinct edge, and the decomposition proved the
  pooled gap was carried by one sub-family (minus-FVG collapses −0.1164 →
  −0.0300). The next comparison must therefore be **within-family**, where
  family composition cannot confound by construction.
- **Frozen constraint (plan register fc72cbb):** no further liquidity-floor
  tuning; any pooled-family comparison must pre-register composition
  sensitivity. ED01-C complies structurally: its primary comparison pools no
  families.

ED01-C is analysis-only on the frozen B8 CONTROL artifacts:

- **In scope:** within-family discrete-level conditional expectancy on the
  frozen population; statistical evidence; verdict.
- **Out of scope:** floor tuning (all floors stay B8), detector logic,
  rendering, execution, telemetry schema, liquidity treatment (closed by
  ED01-B), score-continuity engineering (no code), TP/exit logic (blocked —
  see section 14).
- **Outcome caveat (declared, unchanged from ED01-A/B):** outcomes are the
  legacy fixed-RR simulation; `rMultiple` reflects fixed-RR 2:1 outcomes; the
  DD04 opposing-liquidity TP path is outside the sim. ED01-C measures level
  expectancy under fixed-RR outcomes only.
- **Data:** the frozen ED01-A CONTROL artifacts are the complete dataset. No
  new terminal runs are required or permitted.

## 2. Guardrails (non-negotiable)

1. **B8 remains canonical.** No floor, weight, validator, detector, or
   production change of any kind.
2. **Analysis-only.** The verdict guides the ED01 sequence; any engineering
   change it motivates goes through its own protocol + TDD + TT01 + decision.
3. **One hypothesis per experiment.** The primary comparison is fixed:
   within-family higher-level vs lower-level expectancy. No fishing across
   families or levels.
4. **Pre-registration.** Population, estimator, effect-size threshold, and
   decision rules are fixed in this document before analysis; results do not
   move the goalposts. Thresholds are re-derived here, not inherited from
   ED01-A or ED01-B (section 7).
5. **Composition discipline (frozen constraint).** The primary comparison
   pools no families. Any secondary pooled view must pass the ED01-B
   composition gates (section 9).

## 3. Population (frozen B8, exact definition)

- **Source:** `Tools/ED01/artifacts/<FILE>/CONTROL/telemetry_v4_*.csv`
  (frozen ED01-A CONTROL runs). Files: `EURUSD_H1`, `GBPJPY_H1`,
  `EURUSD_M15`. Per-file default-config fingerprints (ED01-B amendment 13.2):
  EURUSD_H1 `3005138848403243456` (= TT01 B8 baseline), GBPJPY_H1
  `14617585492269479818`, EURUSD_M15 `13548296177162108249` — each verified
  identical across the 3-month and 6-month CONTROL batches.
- **Window:** 2026.04.05 → 2026.07.05 (ED01-A amendment 13.1).
- **Row filter (exact):**
  - `newDecision == "1"` only (NEW-mode qualified decisions).
  - Family via the frozen GR01 `RULE_FAMILY` map (`family_of`).
  - Level = the deciding-family confidence as recorded in `newConfidence`.
    For the two non-degenerate families this takes the discrete values
    FVG {0.35, 0.40}, BOS {0.40, 0.45} (verified in ED01-A).
  - Realized metrics on settled `rMultiple` with `outcome in ("1","2","3")`;
    censored (`outcome == "0"`) excluded and reported as `nOpen`.
- **Level groups (fixed, pre-registered):**
  - **FVG-HIGH** = FVG rows at `newConfidence == 0.40`; **FVG-LOW** = FVG rows
    at 0.35.
  - **BOS-HIGH** = BOS rows at 0.45; **BOS-LOW** = BOS rows at 0.40.
- **Structurally excluded families (pre-registered, not data-driven):**
  - **LIQUIDITY** — constant 0.60; a level split does not exist. The family
    is closed by ED01-B; no comparison is possible or attempted.
  - **UNKNOWN** — no deciding rule fires; there is no deciding-rule
    confidence level. The no-signal question is outside ED01-C.
  - **CHOCH / ORDER_BLOCK** — never fire (0 rows on H1; 1 row M15).
- **Measured size expectations (frozen constants for the audit, from the
  frozen ED01-A grid runs — floor deltas on the same population admit exactly
  the higher-level subset):**

| File | FVG closed | FVG-HIGH (0.40) | FVG-LOW (0.35) | BOS closed | BOS-HIGH (0.45) | BOS-LOW (0.40) |
|---|---|---|---|---|---|---|
| EURUSD_H1 | 318 | ≈143 | ≈175 | 378 | ≈14 | ≈364 |
| GBPJPY_H1 | 39 | <50 total | <50 total | 59 | <50 | <50 |
| EURUSD_M15 | 2,092 | ≈1,159 | ≈933 | 2,095 | ≈39 | ≈2,056 |

## 4. Hypothesis (pre-registered)

- **H1 (research):** within the FVG family, the higher discrete confidence
  level carries materially different conditional expectancy:
  |Δ Mean R| ≥ 0.10 (section 7), where Δ = Mean R(FVG-HIGH) −
  Mean R(FVG-LOW).
- **H0 (null):** |Δ Mean R| < 0.10 — the discrete levels are admission
  switches only; they carry no distinct conditional expectancy.
- The hypothesis is **two-sided**: direction is reported and determines the
  engineering implication (which level to prefer), not the verdict. This is
  pre-registered because prior evidence is mixed across populations (GR01
  Sprint-17 showed the 0.35 tail slightly better; ED01-A H1 showed the 0.40
  subset better).

## 5. Primary metric and estimator

- **Primary metric:** Δ Mean R = Mean R(FVG-HIGH) − Mean R(FVG-LOW), per
  file.
- **Bootstrap 95% CI on Δ (pre-registered):** paired day-stratified
  bootstrap, 10,000 resamples, fixed seed **20260810** (new seed for ED01-C),
  same estimator family as ED01-A/B:
  - Resample days with replacement from the union of days holding either
    level's rows; each sampled day contributes its HIGH and LOW rows; the
    pooled mean-R difference over the sampled rows is one draw.
  - CI = 2.5/97.5 percentiles.
  - **Auxiliary estimator (reported, not gating):** mean of per-day mean-R
    differences over sampled days where BOTH levels have rows. Sign
    disagreement with a CI excluding 0 in one estimator and not the other →
    DEFER (estimator conflict, section 8).
  - Require ≥ 10 paired days with rows in BOTH levels, else DEFER.

## 6. Secondary metrics (reported, not decision-gating)

Per group (HIGH / LOW), per file:

- Sample sizes (qualified, closed, nOpen)
- Win rate (WIN / (WIN + LOSS), BE excluded — GR02 convention)
- Mean R, median R, R quantiles (25/75), R distribution
- Outcome distribution, confidence distribution
- Drawdown proxy (max DD of cumulative R, informational)
- **BOS level split:** identical statistics, evidence-only (n-constrained:
  BOS-HIGH ≈ 14 on EURUSD_H1, ≈ 39 on M15 — below the 50 noise floor).
- **GBPJPY_H1:** identical statistics, evidence-only for ED01-C (FVG total
  39 closed rows measured in the frozen artifacts — cannot resolve a level
  split at n ≥ 50 per side).
- **TT01 baseline replay** (500 rows, 2026-01): informational cross-check of
  the FVG split if it permits n ≥ 50 per side (measured total FVG ≈ 87 →
  expected level n < 50 → report counts only).
- Pooled-level exploratory view (FVG-HIGH + BOS-HIGH vs FVG-LOW + BOS-LOW)
  only if the composition gates in section 9 are applied.

## 7. Effect-size criterion (pre-registered, re-derived — not inherited)

| Threshold | Value | Rationale |
|---|---|---|
| Minimum meaningful \|Δ Mean R\| | **0.10** | 0.10 R is a pre-registered practical-effect threshold informed by the observed standard-error scale (SE(Δ) ≈ 0.16 on EURUSD_H1, ≈ 0.063 on EURUSD_M15, measured from the frozen level sizes) and the economic interpretation of 0.10 R as 10% of one unit of risk. It is independently specified for ED01-C and is not inherited from ED01-A or ED01-B. |
| CI requirement | 95% bootstrap CI excludes 0 | Same discipline as ED01-A/B. |
| Stability | Direction agrees in **2/2 resolvable populations (EURUSD_H1 + EURUSD_M15)** | Hierarchy adaptation, registered pre-analysis in section 12: ED01-C has only one resolvable H1 file (GBPJPY_H1 is n-constrained, measured 39 FVG rows), so the stability gate is the two resolvable populations. |
| Minimum n | ≥ 50 closed rows per level per stability population | Same noise floor as ED01-A §7. |
| Estimator agreement | Pooled and daily-mean estimators must not conflict | Guards against count-asymmetry artifacts (ED01-A §7 discipline). |

## 8. Pre-registered decision rules

- **EVIDENCE FOR CONFIDENCE LEVELS (distinct level expectancy):** on the
  primary file (EURUSD_H1): |Δ| ≥ 0.10 AND 95% CI excludes 0 AND n ≥ 50 per
  level AND estimators agree AND direction agrees with EURUSD_M15 (2/2).
  Direction is recorded (HIGH-better or LOW-better). Verdict consequence:
  level-aware admission is a real lever — a follow-up experiment (ED01-D,
  level-aware admission) may be designed; still no production change from
  ED01-C itself.
- **REJECT / NO DISTINCT LEVEL EXPECTANCY:** |Δ| < 0.10 on EURUSD_H1, OR CI
  includes 0. When EURUSD_H1 is null, EURUSD_M15 direction is moot (the null
  already decides). Direction disagreement between the resolvable populations
  when EURUSD_H1 IS meaningful is instability → DEFER (freeze clarification,
  amendment 16.1). Verdict consequence: the discrete levels are admission
  switches only; the confidence-granularity hypothesis is **closed under the
  current evidence universe and model formulation** (section 13) — no
  engineering change, score-continuity work deprioritized.
- **DEFER:** n < 50 per level on EURUSD_H1, OR < 10 paired days, OR
  pooled/daily-mean estimator conflict, OR a meaningful EURUSD_H1 result
  (|Δ| ≥ 0.10, CI excluding 0) with opposite sign on EURUSD_M15
  (instability). Verdict consequence: hypothesis stays open; the 6-month
  archive is the designated follow-up (section 13).
- **No production change occurs under ANY verdict.** The verdict only guides
  which ED01-D design (if any) is worth engineering.

## 9. Composition controls (frozen constraint compliance)

1. **Primary comparison pools no families** — ED01-C is within-family by
   construction, so family composition cannot confound it. This is the
   structural answer to the ED01-B artifact (the pooled gap was FVG-carried;
   ED01-C cannot suffer that artifact).
2. **If any pooled-family view is produced (secondary/exploratory only), the
   ED01-B gates apply verbatim:**
   - **UNKNOWN-exclusion:** the pooled view is recomputed with UNKNOWN rows
     removed; if the verdict changes sign or falls below 0.10 → that view is
     reported as UNKNOWN-driven, never gating.
   - **Single-subfamily concentration:** removing any one family must not
     flip the pooled view's sign or drop |Δ| below 0.10, else the view is
     reported as composition-confined.
3. **Level-split integrity check (audit):** within FVG, HIGH+LOW counts must
   equal the total FVG closed count per file, and the HIGH count must match
   the frozen ED01-A FVG_0.40 grid run's admitted count (same population,
   floor admits exactly the higher-level subset).

## 10. Power / feasibility (pre-registered, measured constants)

With σ(rMultiple) ≈ 1.42 (fixed-RR), the measured level sizes give:

- EURUSD_H1 FVG (143 vs 175): SE(Δ) ≈ **0.16** — H1 alone cannot resolve a
  0.10 effect.
- EURUSD_M15 FVG (1,159 vs 933): SE(Δ) ≈ **0.063** — M15 can resolve it.
- Consequence, pre-declared: an EVIDENCE verdict requires H1 and M15 to
  agree; a null (REJECT) can be reached from EURUSD_H1 alone when the CI
  includes 0. DEFER on 3-month evidence is a possible and honest outcome —
  the 6-month archive is the designated follow-up, not a failure.

## 11. Engineering gates (analysis milestone)

1. **No compile step:** no production or test code changes.
2. **Data integrity (hard):** per-file fingerprints reproduce the frozen
   values (amendment 13.2); qualified + per-family closed counts reproduce
   the frozen ED01-A analysis (EURUSD_H1 1,468/1,420; GBPJPY_H1 236/217;
   EURUSD_M15 5,981/5,931); FVG level counts match section 3 expectations.
3. **Determinism:** analyzer seed fixed (20260810); rerun reproduces
   identical CIs and JSON.
4. **Audit:** group assignment reproduces the ED01-B per-family CONTROL
   counts (reuse of the ED01-B audit constants).

## 12. OOS files and H1/M15 hierarchy (registered, pre-analysis)

- **EURUSD_H1 — primary decision file** (FVG split resolvable: 143/175).
- **EURUSD_M15 — stability partner for ED01-C** (FVG split resolvable:
  1,159/933). Hierarchy adaptation registered here, before analysis:
  ED01-A/B used 2/2 H1 because two resolvable H1 files existed; ED01-C has
  one (GBPJPY_H1 FVG total closed = 39, measured in the frozen artifacts,
  < 50 per side → unresolvable). Registered rules (frozen, 2026-08-09):
  1. **H1 remains the primary decision dataset.**
  2. **M15 becomes a stability partner because GBPJPY H1 has insufficient
     FVG observations.**
  3. **M15 cannot independently establish a positive entry edge.**
  4. **Direction must agree across both resolvable populations (2/2) for an
     affirmative result.**
- **GBPJPY_H1 — evidence-only for ED01-C** (n-constrained).
- M15 and GBPJPY_H1 cannot rescue a failed EURUSD_H1 verdict; the 2/2 gate
  is the sole stability requirement.

## 13. What closes the hypothesis, what reopens it

- **Permanently closed under the current evidence universe and model
  formulation:** REJECT where BOTH resolvable populations show |Δ| < 0.10
  with CIs including 0 and no estimator supports an effect. The discrete
  confidence levels are then admission switches only. Reopening requires
  genuinely new evidence — such as the reserved six-month archive
  (`Tools/ED01/artifacts_6mo_2026-01-05_07-05/`, 46 runs) or a future
  data/model change — not another re-analysis of the same B8 population.
- **Engineering change is justified only by EVIDENCE FOR**, and even then
  the change (e.g., level-aware admission policy or score-continuity work)
  proceeds as a separate protocol with TDD + TT01 + explicit decision —
  ED01-C itself changes nothing.

## 14. Sequence note: ED01-C re-scope (TP → ED01-D)

The ED01 protocol §11 and the ED01-A decision doc listed ED01-C as "TP
target logic, once the outcome sim reflects the DD04 opposing-liquidity
path". That experiment remains a candidate but is **blocked**: the replay
outcome sim is the legacy fixed-RR builder and the DD04 path is not in it —
measuring TP expectancy without the sim is meaningless. It is re-registered
as **ED01-D** (exit-side, after the outcome-sim engineering prerequisite).
ED01-C is the entry-decision question the A/B evidence actually points to
(section 1). This re-scope is recorded here, pre-analysis.

## 15. Deliverables (execution order)

1. **Protocol freeze** (this document → FROZEN on user approval; committed).
2. **Analyzer** — `Tools/ED01/ED01_C_Analyze.py`, written after freeze only;
   reuses the ED01-B loader/audit patterns; outputs
   `Tools/ED01/results_ED01C.json`.
3. **Analysis run** — pure CSV re-analysis; no tester runs.
4. **Decision report** — `docs/Sprint20_ED01C_Decision.md`: verdict +
   evidence (primary, secondary, composition checks, determinism).
5. **Plan register** — ED01-C row DONE with evidence; ED01-D row registered
   (blocked on outcome sim).

## 16. Amendments

### 16.1 Freeze record (2026-08-09, user approval)

Frozen with the following user-approved decisions and wording safeguards:

1. **Hierarchy adaptation approved:** stability gate = 2/2 over EURUSD_H1 +
   EURUSD_M15 with the four registered rules (section 12): H1 primary; M15
   stability partner because GBPJPY_H1 FVG observations are insufficient
   (39 total closed, measured); M15 cannot independently establish a positive
   entry edge; direction must agree across both resolvable populations for an
   affirmative result.
2. **Effect-size criterion approved:** |Δ Mean R| ≥ 0.10, worded as a
   pre-registered practical-effect threshold informed by the observed
   standard-error scale and the economic interpretation of 0.10 R as 10% of
   one unit of risk — independently specified for ED01-C, not inherited from
   ED01-A or ED01-B (section 7).
3. **Closing rule approved with qualification:** "permanently" means closed
   under the current evidence universe and model formulation; reopening
   requires genuinely new evidence (six-month archive, or a future
   data/model change), not another re-analysis of the same B8 population
   (section 13).
4. **Clarification (freeze-time):** REJECT's direction-disagreement clause
   resolves to — when EURUSD_H1 is null, EURUSD_M15 direction is moot
   (REJECT via the null); when EURUSD_H1 is meaningful, opposite sign on
   EURUSD_M15 is instability → DEFER (section 8).
5. **Execution order frozen:** protocol freeze → analyzer build
   (`Tools/ED01/ED01_C_Analyze.py`) → analyzer self-check (audit +
   determinism) → analysis run → decision doc
   (`docs/Sprint20_ED01C_Decision.md`). No production code change at any
   step; no tester runs.
