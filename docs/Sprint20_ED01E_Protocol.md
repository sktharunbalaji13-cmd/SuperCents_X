# Sprint 20 — ED01-E Protocol: Fixed-RR TP Tier Sweep (Exit-Distance Benchmark)

Status: **FROZEN on user approval 2026-08-09 (freeze record §16.1)** — the
protocol is exactly as drafted; no changes at freeze. No code, no runs, no
analysis beyond the approved prerequisite engineering until further
approval. The engineering prerequisite (section 14/§16.1 item 8) is
authorized as the next step, with STOP for review before the 15-run batch.
Date: 2026-08-09
Scope owner: exit/TP research, fifth ED measurement milestone (ED01-E)
Predecessor: ED01-D (`docs/Sprint20_ED01D_Decision.md`) — EVIDENCE FIXED-2R
better: the implemented opposing-liquidity TP loses to fixed-2R, but **2R
optimality was never tested**. ED01-E closes that gap before any alternative
exit policy is compared against 2R as a benchmark.

## 1. Purpose and scope

ED01-D established that the *implemented opposing-liquidity TP resolution*
is materially worse than the *legacy fixed-2R fallback* on the sweep-bearing
LIQUIDITY population (Δ = −0.7210 R, 95% CI [−1.192, −0.262]). It did **not**
establish that 2.0R is a good or optimal TP distance — 2R is an arbitrary
legacy constant, explicitly recorded as "not an optimum" in the ED01-D
hypothesis. ED01-E asks the benchmark question **before** any liquidity-aware
or adaptive exit policy is tested against a possibly-arbitrary comparator:

> **What fixed-RR exit distance (TP = tier × ATR, SL = 1.0 × ATR) provides
> the strongest and most stable out-of-sample conditional expectancy for the
> existing entry population, measured against the frozen B8 CONTROL (2.0R)?**

Scope boundary (anti-overfitting guard): ED01-E is **not** "optimize the TP
until the backtest looks good." It is a pre-registered 4-comparison
experiment with fixed candidate tiers, pre-registered gates, and a
pre-registered selection rule. **"2.0R remains best" is a fully valid
conclusion.** The selected tier becomes the benchmark for the NEXT
experiment (opposing/adaptive exit variants) — no production change from
ED01-E itself.

## 2. Guardrails (non-negotiable)

1. **No production change under any verdict** — no TP distance change, no
   TargetResolver change, no B8 change. A selected tier's adoption (if any)
   is a separate protocol with TDD + TT01 + explicit decision.
2. **Frozen B8 baseline untouched** — tier runs are settle-time outcome
   simulations only; the decision pipeline, fingerprints and B8 artifacts
   are byte-identical to CONTROL.
3. **Paper-first:** this protocol freezes before any prerequisite code.
4. **Pre-registered comparisons only:** exactly 4 comparisons (1.0/1.5/2.5/3.0
   vs 2.0). No post-hoc tier testing, no step-down selection, no
   threshold-tweaking after seeing results.
5. **No re-freeze without amendment:** any change to population, tiers,
   metric, seed or ladder goes through a §16 amendment record like ED01-D
   §16.2 — preserving the original text.
6. **Composition discipline (ED01-B lesson):** the pooled tier comparison
   must pre-register per-family sensitivity; a family-carried conclusion is
   reported as composition-confined, never selected.
7. **Deterministic analysis:** fixed seed, reruns byte-identical (ED01-A/B/C/D
   discipline).
8. **Raw evidence retained locally:** artifacts gitignored; protocol,
   analyzer, manifest, results, decision committed.

## 3. Population (frozen B8, exact definition)

- **Source (all arms):** the frozen ED01-A CONTROL artifacts
  `Tools/ED01/artifacts/<FILE>/CONTROL/telemetry_v4_*.csv` — the B8
  baseline runs. Files: `EURUSD_H1`, `GBPJPY_H1`, `EURUSD_M15`. Per-file
  default-config fingerprints (ED01-B amendment 13.2): EURUSD_H1
  `3005138848403243456`, GBPJPY_H1 `14617585492269479818`, EURUSD_M15
  `13548296177162108249`.
- **Window:** 2026.04.05 → 2026.07.05 (ED01-A amendment 13.1).
- **Row filter (exact):** `newDecision == "1"` only; closed rows with
  `outcome in ("1","2","3")`; censored (`outcome == "0"`) excluded and
  reported as `nOpen`. **All families** (LIQUIDITY, FVG, BOS, UNKNOWN,
  CHOCH) — the TP-distance question applies to every settled row of the
  entry population; the ED01-D LIQUIDITY-only stratum was specific to the
  opposing-TP arm and is NOT reused here.
- **Measured size expectations (frozen constants for the audit, measured
  2026-08-09 from the frozen CONTROL artifacts — read-only sizing, Appendix A):**

| File | Total | Qualified | Closed | Days | FVG | BOS | LIQUIDITY | UNKNOWN | CHOCH |
|---|---|---|---|---|---|---|---|---|---|
| EURUSD_H1 | 1,558 | 1,468 | **1,420** | 63 | 318 | 378 | 607 | 117 | 0 |
| GBPJPY_H1 | 1,560 | 236 | **217** | 41 | 39 | 59 | 96 | 23 | 0 |
| EURUSD_M15 | 6,239 | 5,981 | **5,931** | 65 | 2,092 | 2,095 | 1,694 | 49 | 1 |

- **Baseline (2.0R) closed-row statistics (frozen, informational):**
  meanR EURUSD_H1 −0.0239 / GBPJPY_H1 −0.0599 / EURUSD_M15 −0.0126;
  win rate 0.3254 / 0.3134 / 0.3315; σ(rMultiple) 1.4055 / 1.3916 / 1.3992.

## 4. Hypothesis (pre-registered)

- **H1 (research):** at least one fixed-RR tier in {1.0, 1.5, 2.5, 3.0}
  carries a materially different conditional expectancy than the 2.0R
  baseline on the primary file (EURUSD_H1): |Δ Mean R| ≥ 0.10 (section 7),
  Δ Mean R = Mean R(tier) − Mean R(2.0R), with direction recorded
  (tier-better or 2R-better).
- **H0 (null):** no tier achieves |Δ| ≥ 0.10 with the CI excluding 0 on
  EURUSD_H1 — the TP-distance dimension is expectancy-flat in this range;
  **2.0R remains the benchmark**. (A valid, pre-registered outcome.)
- Two-sided: direction is reported and determines the engineering
  implication, not the verdict mechanism.
- **Anti-goal (explicit):** the experiment must NOT be used to justify
  "tuning" — a tier is selected only through the full pre-registered gate
  stack (section 8), never by point-estimate magnitude alone.

## 5. Primary metric and estimator

- **Primary metric:** Δ Mean R = Mean R(tier) − Mean R(2.0R) on the closed
  rows, per file. Arms are paired by the cross-run decision identity key
  (section 11 gate 3a — decisionId if proven invariant across all tier
  runs, otherwise the canonical stable key `{signalTime, configFingerprint,
  symbol, timeframe}`), so Δ equals the mean of per-row paired differences
  d_r = rMultiple_tier − rMultiple_2R.
- **Bootstrap 95% CI (pre-registered):** paired day-stratified bootstrap,
  10,000 resamples, fixed seed **20260813** (new seed for ED01-E), same
  estimator family as ED01-A/B/C/D:
  - Resample days with replacement from the union of days holding any
    closed row; each sampled day contributes its paired TIER and 2R rows;
    the pooled mean-R difference over the sampled rows is one draw.
  - CI = 2.5/97.5 percentiles.
  - **Auxiliary estimator (reported, not gating):** mean of per-day mean-R
    differences over sampled days. Sign disagreement with a CI excluding 0
    in one estimator and not the other → DEFER (estimator conflict,
    section 8).
  - Require ≥ 10 paired days in BOTH arms, else DEFER (measured:
    63 / 41 / 65 — satisfied, held as a gate).

## 6. Secondary metrics (reported, not decision-gating)

Per arm, per file, on the closed population:

- Sample sizes (qualified, closed, nOpen)
- Win rate, mean R, median R, R quantiles (25/75), R distribution
- Outcome distribution (WIN/LOSS/BREAKEVEN/censored)
- **TP-hit rate (informational, per tier):** share of closed rows exiting at
  the TP target (exitReason TP) — must be monotonically decreasing in the
  tier (mechanism sanity check; a violation is a gate-3c warning, not a
  verdict input)
- **Outcome transition matrix (2R → tier)** per comparison
- **Family strata** (FVG, BOS, LIQUIDITY, UNKNOWN; CHOCH evidence-only):
  identical statistics with per-family CIs — decision-support for the
  composition gates (section 9), never standalone verdicts
- **GBPJPY_H1:** identical statistics, evidence-only (n = 217; hierarchy
  section 12)

## 7. Effect-size criterion (pre-registered)

| Threshold | Value | Rationale |
|---|---|---|
| Minimum meaningful \|Δ Mean R\| | **0.10** | Same practical-effect threshold as ED01-B/C/D (0.10 R = 10% of one unit of risk), informed by the SE scale (section 10). Independently specified for ED01-E. |
| CI requirement | 95% bootstrap CI excludes 0 | Same discipline as ED01-A/B/C/D. |
| Stability | Direction agrees in **2/2 resolvable populations (EURUSD_H1 + EURUSD_M15)** | Same hierarchy adaptation as ED01-C/D §12 (registered pre-analysis). |
| Minimum n | ≥ 50 closed rows per population | Same noise floor as ED01-A §7 (measured: 1,420 / 5,931 — satisfied, held as a gate). |
| Estimator agreement | Pooled and daily-mean estimators must not conflict | Guards against count-asymmetry artifacts. |
| Multiple-comparison handling (4 tests: 1.0/1.5/2.5/3.0 vs 2.0) | Primary gate = the full combination above (CI exclusion + materiality + 2/2 direction + composition); **sensitivity**: Bonferroni-corrected CI (α = 0.05/4 → 98.75%) reported for every comparison, and the conclusion is flagged if no comparison survives the corrected CI — the primary gate is deliberately conservative (2/2 + CI + materiality) and is the pre-registered decision rule; the corrected CI is a disclosed robustness check, never a second ladder. | Controls family-wise error without making selection depend on a post-hoc threshold. |

## 8. Pre-registered decision rules

- **EVIDENCE — TIER SELECTED (≠ 2R):** on the primary file (EURUSD_H1):
  |Δ| ≥ 0.10 AND 95% CI excludes 0 AND n ≥ 50 AND estimators agree AND
  direction agrees with EURUSD_M15 (2/2) AND composition gates (section 9)
  pass AND run-integrity gates (section 11) passed. **Selection rule (one
  tier only):** the tier with the largest |Δ| among those clearing the
  full gate on EURUSD_H1; if more than one clears, the largest-|Δ| winner
  with M15 direction agreement wins; if the largest-|Δ| clearing tier has
  M15 direction DISAGREEMENT → DEFER (instability), even if another tier
  agrees. Verdict consequence: the selected tier is the empirical
  fixed-RR benchmark for the next exit experiment (opposing/adaptive
  variants) and a candidate for a separate production adoption protocol —
  **still no production change from ED01-E itself**.
- **REJECT / "2.0R REMAINS BEST":** no tier clears the full gate on
  EURUSD_H1 (|Δ| < 0.10 OR CI includes 0 on every tier). Verdict
  consequence: the TP-distance dimension is flat in [1.0, 3.0]R on this
  population; 2.0R stays the benchmark; the tier question is closed
  (section 13) — no engineering change.
- **DEFER:** n < 50 on EURUSD_H1, OR < 10 paired days, OR pooled/daily-mean
  estimator conflict, OR a clearing-tier's EURUSD_M15 direction
  disagreement (instability). Verdict consequence: hypothesis stays open;
  the 6-month archive is the designated follow-up (section 13).
- **Run-set rejection (no verdict):** any integrity-gate failure (section
  11) → the run set is invalid; no verdict is emitted; re-run after audit.
- **No production change occurs under ANY verdict.**

## 9. Composition controls (ED01-B discipline, pre-registered)

The primary comparison pools families within the closed population. The
ED01-B gates apply verbatim:

1. **UNKNOWN-exclusion:** the pooled view is recomputed with UNKNOWN rows
   removed; if the selected tier's verdict changes sign or falls below
   0.10 → reported as UNKNOWN-driven, never selected.
2. **Single-family concentration:** removing any one family (FVG, BOS,
   LIQUIDITY) must not flip the selected tier's sign or drop |Δ| below
   0.10; if it does, the conclusion is **composition-confined** (the
   ED01-B minus-FVG collapse lesson) — reported, never selected.
3. **Eligibility integrity check (audit):** closed-family counts reproduce
   section 3 exactly on every arm.

## 10. Power / feasibility (pre-registered, measured constants)

With σ(rMultiple) ≈ 1.40 (measured 2026-08-09) and paired-difference
σ_d = σ√2 ≈ 1.98:

| File | Closed n | SE(Δ) = σ√2/√n | Role |
|---|---|---|---|
| EURUSD_H1 | 1,420 | **0.053** | resolves |Δ| = 0.10 (power > 0.8) |
| EURUSD_M15 | 5,931 | **0.026** | highly powered (stability partner) |
| GBPJPY_H1 | 217 | **0.134** | evidence-only |

- Pre-declared: EVIDENCE requires H1 + M15 direction agreement; a null
  (2R remains best) can be reached from EURUSD_H1 alone when no tier CI
  excludes 0.
- 4 independent tests each at SE ≈ 0.053 on H1: a true tier effect of
  0.10 R is detectable at power ≥ 0.8 per test; the multiple-comparison
  sensitivity (section 7) is disclosed.

## 11. Engineering gates (analysis milestones)

1. **Compile/fingerprint (hard):** the 15 new runs compile from HEAD; every
   new CSV reproduces the frozen per-file configFingerprint (section 3).
   **The tier parameter is a settle-time outcome-simulation input ONLY
   (hardcoded fingerprint token `"FixedRR"/"1"` in
   `TelemetryRowBuilder.mqh:61` — TP parameters are outside the
   fingerprint, verified by unit test, ED01-D precedent);** all arms must
   carry the identical per-file fingerprint — this is what makes decisionId
   pairing valid.
2. **Row-count integrity (hard):** each new run's total/qualified/closed
   counts reproduce the frozen audit constants (1,558/1,468/1,420;
   1,560/236/217; 6,239/5,981/5,931) on every arm.
3. **At-scale distinguishability + decision-identity invariance (hard):**
   a. **Integrity reruns (2.0R tier, new code):** each file's 2.0R rerun is
      **row-for-row byte-identical** to the frozen CONTROL artifacts
      (decisionId + all 75 columns) — proves code-equivalence and
      determinism of the run set. ANY divergence → run set rejected.
      **Pairing-key proof:** decisionId certified if invariant here.
   b. **Decision-identity invariance across tiers:** for every tier run,
      ALL columns are identical to CONTROL **except** the outcome columns
      (outcome, rMultiple, barsHeld, exitPrice, exitReason,
      outcomeSource where the tier changes the exit). Any divergence
      outside those columns → run set rejected (the tier must not perturb
      decisions).
   c. **Distinguishability per tier:** each tier (1.0/1.5/2.5/3.0) has at
      least one closed row with rMultiple differing from CONTROL; zero
      treated rows → run set rejected. **Mechanism sanity (warning):**
      TP-hit rate monotonically decreasing in tier; a violation is
      flagged, not gating.
4. **Determinism (hard):** analyzer seed fixed (20260813); rerun reproduces
   identical CIs and JSON.
5. **Audit:** closed counts and days reproduce section 3 exactly.

## 12. OOS files and hierarchy (registered, pre-analysis)

- **EURUSD_H1 — primary decision file** (closed 1,420, resolvable).
- **EURUSD_M15 — stability partner** (closed 5,931, resolvable). Registered
  rules (same as ED01-D §12): H1 remains the primary decision dataset; M15
  is a stability partner; M15 cannot independently establish a tier; direction
  must agree 2/2 for an affirmative result.
- **GBPJPY_H1 — evidence-only** (n = 217, SE 0.134 — n-constrained).
- M15 and GBPJPY_H1 cannot rescue a failed EURUSD_H1 verdict.

## 13. What closes the hypothesis, what reopens it

- **Permanently closed under the current evidence universe:** REJECT —
  no tier clears the gate — the TP-distance dimension is flat; 2.0R stays
  the benchmark. Reopening requires genuinely new evidence — the reserved
  six-month archive (`Tools/ED01/artifacts_6mo_2026-01-05_07-05/`, 46 runs)
  or a future data/model change — not another re-analysis of this population.
- **EVIDENCE consequence:** the selected tier is the benchmark for the
  exit-policy ladder (opposing/adaptive variants vs the empirically
  selected fixed-RR benchmark); adoption in production is a separate
  protocol with TDD + TT01 + explicit decision — ED01-E itself changes
  nothing.

## 14. Run production and manifest

- **How the arms are produced (frozen choice):** paired simulation runs over
  the same decisions — one run per tier per file. The 2.0R arm = the frozen
  CONTROL artifacts (already collected; integrity reruns below are
  audit-only). Tier runs = new runs with the fixed-RR tier input (EA input
  `FixedRRTier`, settle-time outcome simulation only — ED01-D `OutcomeTpMode`
  precedent, commit 8954332).
- **Profile (frozen, identical to CONTROL):** `Tools/ED01/ini/<FILE>_CONTROL.ini`
  — Expert SuperCents_X.ex5, Symbol/Period per file, FromDate 2026.04.05,
  ToDate 2026.07.05, Model=4, Deposit 10000 GBP, Leverage 200, ExecutionMode
  1000, EntryMode=2, B8 weights 25/20/15/15/15/10. Tier runs add the
  `FixedRRTier` input only.
- **Run set (15 new runs):**

| Run | Config | Tier |
|---|---|---|
| EURUSD_H1/GBPJPY_H1/EURUSD_M15 integrity | CONTROL profile | 2.0R (audit) |
| 4 tiers × 3 files | CONTROL profile + `FixedRRTier` | 1.0 / 1.5 / 2.5 / 3.0 |

- **Artifacts:** `Tools/ED01/artifacts/<FILE>/CONTROL_ED01E_TP1R/`,
  `CONTROL_ED01E_TP1P5R/`, `CONTROL_ED01E_TP2P5R/`, `CONTROL_ED01E_TP3R/`,
  `CONTROL_ED01E_INTEGRITY/` (`.done` markers). Runner: `ED01_E_RunBatch.ps1`
  (ED01-D runner pattern) recording per-run mode/tier/file/start/end/rows/
  faults — the **tier manifest** `Tools/ED01/ED01_E_manifest.json`.
- **Pairing:** decisionId if gate 3a proves it invariant (canonical key
  fallback) — recorded in the analyzer output and manifest before any
  statistic is computed.
- **Prerequisite engineering (authorized AFTER freeze):** EA/engine input
  `FixedRRTier` (double, default 2.0) → `CSymbolContext::SetFixedRRTier`
  → settle-time `CFixedRRPolicy` tpR (OutcomePolicies.mqh:33 default
  2.0). TDD: RED (tier parameter absent) → GREEN; tests: tier resolves
  exit levels at tier×ATR for 1.0/1.5/2.5/3.0, 2.0R default byte-identical
  vs B8, fingerprint invariance under tier change (hardcoded token
  `TelemetryRowBuilder.mqh:61`), settle-row policy selection; TT01 full
  gate PASS with BEHAVIOR-REGRESSION byte-identical under default 2.0
  (no baseline re-freeze — ED01-D precedent).

## 15. Deliverables (execution order — frozen)

1. **Protocol freeze** (this document → FROZEN on user approval; committed;
   pushed to origin).
2. **Prerequisite engineering** — `FixedRRTier` input (TDD + TT01; default
   2.0R byte-identical vs B8).
3. **Analyzer + runner** — `Tools/ED01/ED01_E_Analyze.py` (ED01-D analyzer
   pattern) + `ED01_E_RunBatch.ps1`; outputs `Tools/ED01/results_ED01E.json`.
4. **Analyzer self-check** — audit constants + determinism on the frozen
   CONTROL artifacts.
5. **Run batch** — 15 runs; artifacts + tier manifest.
6. **Pre-analysis gate** — section 11 gates (a)–(c) verified.
7. **Analysis run** — paired analysis per section 5 (seed 20260813).
8. **Decision report** — `docs/Sprint20_ED01E_Decision.md`: verdict +
   evidence (primary, secondary, composition checks, MC sensitivity,
   TP-hit sanity, determinism, gate results).
9. **Plan register** — ED01-E row DONE with evidence.
10. **Commit + push** — dedicated ED01-E commit(s) to origin/main; TT01
    full gate after any production code change (none expected under any
    verdict).

## 16. Amendments

### 16.1 Freeze record (2026-08-09, user approval)

Frozen with the following user-approved decisions and wording safeguards
(protocol exactly as drafted; no changes at freeze):

1. **Tier set approved:** exactly 5 fixed tiers — 1.0 / 1.5 / 2.0 (B8
   CONTROL) / 2.5 / 3.0R — exactly 4 pre-registered comparisons vs 2.0R.
   Edge expansion (if the optimum lies at 1.0 or 3.0) is permitted ONLY
   as a pre-registered second stage via a §16 amendment record — never
   ad-hoc after seeing results.
2. **Population approved:** ALL closed rows of all families per file
   (H1 1,420 / GBPJPY 217 / M15 5,931; days 63/41/65) — the fixed TP
   applies across the entire settled population; the ED01-D LIQUIDITY-only
   stratum is NOT reused. Audited constants measured 2026-08-09 (Appendix A).
3. **Primary metric and estimator approved:** paired Δ Mean R (tier −
   2.0R) per file, paired by the decisionId identity invariant (gate 3a
   certification; canonical key fallback), paired day-stratified
   bootstrap, 10,000 iters, seed **20260813**, ≥ 10 paired days gate,
   auxiliary daily-mean estimator (conflict → DEFER).
4. **Effect-size threshold approved:** |Δ| ≥ 0.10, 95% CI excludes 0,
   n ≥ 50, 2/2 direction (H1 primary + M15 stability partner), GBPJPY_H1
   evidence-only. SE inputs: EURUSD_H1 0.053, GBPJPY_H1 0.134, EURUSD_M15
   0.026 (σ ≈ 1.40 measured).
5. **Multiple-comparison handling approved:** 4 tests; primary gate = the
   full combination (CI exclusion + materiality + 2/2 direction +
   composition); Bonferroni-corrected CIs (α = 0.05/4 → 98.75%) reported
   as disclosed robustness sensitivity only — never a second ladder.
6. **Selection rule approved (explicitly preserved):** select the single
   largest-|Δ| tier ONLY if it clears the full pre-registered gate on
   EURUSD_H1 with M15 direction agreement; if more than one clears, the
   largest-|Δ| with M15 agreement wins; a clearing tier with M15 sign
   disagreement → DEFER. **If NO tier clears the gate, the conclusion is
   "2.0R REMAINS BEST" — not "pick the closest tier."** ED01-E is a
   pre-registered comparison, NOT an optimization exercise.
7. **Composition controls approved:** ED01-B gates verbatim — UNKNOWN-
   exclusion and single-family concentration (FVG, BOS, LIQUIDITY removal
   test); a family-carried conclusion is composition-confined, never
   selected.
8. **Engineering prerequisite approved (and bounded):** `FixedRRTier`
   input → settle-time `CFixedRRPolicy` tpR; default 2.0R; default
   behavior byte-identical to B8; fingerprint contract preserved
   (hardcoded token `"FixedRR"/"1"` — tier input immune); TDD + full
   TT01; NO baseline re-freeze; NO entry-logic changes; NO DD04/
   opposing-liquidity changes; NO experiment runs, analyzer or
   statistics until the prerequisite is approved.
9. **Run production approved (post-prerequisite):** 15 runs = 3
   integrity (2.0R audit, row-for-row byte-identical vs CONTROL) + 12
   tier runs (4 × 3 files); CONTROL profile + `FixedRRTier` input only;
   tier manifest; decision-identity invariance gate (only outcome
   columns may differ across tiers).
10. **Boundaries confirmed:** no production change under any verdict; B8
    untouched; no baseline re-freeze; the selected tier becomes the
    benchmark for the NEXT exit-policy experiment (opposing/adaptive
    variants vs the empirically selected fixed-RR benchmark); adoption in
    production is a separate protocol with TDD + TT01 + explicit
    decision.
11. **Execution order frozen:** protocol freeze (this document) →
    prerequisite engineering (TDD + TT01; STOP for review before runs)
    → analyzer + runner → self-check → 15-run batch + tier manifest →
    pre-analysis gate (section 11 a–c) → analysis → decision doc → plan
    register → dedicated commit(s) + push to origin/main.

## Appendix A — Population measurement provenance

Measured 2026-08-09 from the frozen CONTROL artifacts with a read-only
sizing script (not part of the analysis): per-file totals, qualified,
closed, per-family closed counts, closed-row day counts, closed-row
meanR/win rate/σ(rMultiple) as shown in section 3. SE(Δ) computed as
σ√2/√n per section 10. No new runs were executed; no code was modified.
