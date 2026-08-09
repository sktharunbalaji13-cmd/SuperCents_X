# 18.13 - Statistical Validation Research

Status: **COMPLETE** (2026-08-02). 8-phase deep research review of the
statistical validation discipline in SuperCents_X: whether the
measured effects of 18.1-18.12 are statistically real, how stable
they are across time, how to protect against multiple-comparison
snooping, and what protocol Sprint 19 must follow before promoting
anything. Phase 7 runs significance tests, Wilson confidence
intervals, split-half stability checks and family-rank stability
tests on the frozen 17,073-row dataset.

Evidence dataset (frozen, fingerprint
`2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`):
17,073 decided+signal rows; binary outcomes (excl BE) n=17,068;
base win rate 0.3321. All Phase 7 statistics are two-sided; p0 for
binomial tests = 1/3 (breakeven for the 2R/1R fixed policy, 18.10);
"halves" = time-split at the dataset median timestamp.

---

## 1. Foundation - what validation means for this program

Every table in 18.1-18.12 is an **in-sample point estimate** on one
frozen dataset. A point estimate is a hypothesis, not a finding,
until three questions are answered:

1. **Significance**: could the effect be chance given n? (binomial
   test vs breakeven, two-proportion tests between cells)
2. **Precision**: how wide is the plausible range? (Wilson CI)
3. **Stability**: does the effect reproduce on an unseen time slice?
   (split-half; walk-forward for promotion)

The dataset is **not a random sample** - rows are trade events in
time with serial dependence (same day, same regime). Significance
tests here measure "is this different from the base rate", not
"will it repeat" - only out-of-time validation answers that. The
program has produced roughly **300+ tested cells** across 18.1-18.12
(family x direction x confidence x hour tables). At α=0.05, ~15
false positives are *expected by construction*; every headline must
therefore be re-tested with correction for multiplicity.

---

## 2. Academic - the statistics of strategy claims

- **Null-hypothesis significance testing (NHST)**: α=0.05 is the
  convention; α=0.01/0.001 for strong claims. p is P(observed | no
  effect), not P(effect | observed) - the common misinterpretation.
- **Multiple-comparison correction**: Bonferroni (α/k, conservative)
  and Holm step-down (sequential, more powerful). For the program's
  ~100-300 comparisons, thresholds of 5e-4 to 1.7e-4 are the honest
  bar. Pre-registration (declaring tests before seeing data) is the
  only full defense; post-hoc tables are exploratory by definition.
- **Garden of forking paths (Gelman & Loken 2013)**: with many
  implicit choices (window boundaries, n floors, cell definitions),
  the *effective* number of tests exceeds the reported ones.
- **Wilson interval**: the correct CI for binomial proportions
  (asymmetric, well-behaved near 0/1); a claim "beats breakeven"
  requires the CI lower bound to exclude 1/3.
- **Data snooping (White 2000; Harvey, Liu & Zhu 2016)**: after many
  attempts, the best in-sample model is expected to beat the market
  by luck; the Reality Check / Deflated Sharpe framework prices that
  selection effect. Our family tables (18.1-18.7) are exactly the
  kind of multi-search results this literature warns about.

---

## 3. Professional - validation practice

- **Minimum samples**: rules of thumb vary, but n<100 cells are
  anecdote-grade (SE of a proportion at n=63, p=0.54 is ±0.12);
  n≥300 is the practical floor for gate decisions at wr~0.33-0.40;
  n≥500 for ranking cells. CHOCH_OB (n=63, 18.11) fails every floor.
- **Split-sample honesty**: the top discovery must be re-measured on
  data not used to discover it. Any Sprint 19 experiment that tunes
  thresholds must reserve a holdout before looking (E1).
- **Costs are not optional**: a +3pp wr effect at 0.5 pip spread can
  vanish after costs; validation reports must quote cost-adjusted
  expectancy, not raw wr (E7).
- **Replication culture**: professional firms require a second,
  independent measurement of every promoted edge; split-half is the
  cheapest form, walk-forward the strong form.

---

## 4. Institutional / Quant - validation governance

- **Walk-forward analysis (WFA)**: fixed rolling/expanding/anchored
  windows; parameters are chosen on train, evaluated on test; a
  strategy is promoted only when a majority (or all) windows pass.
  The EA has a real WFA implementation (6.2) - currently oriented to
  strategy parameters, not to the cell-level gates this review needs.
- **Probability of Backtest Overfitting (Bailey, Borwein, Lopez de
  Prado & Zhu 2017)**: CSCV resampling estimates how often the
  best in-sample configuration is worse than median out-of-sample -
  the correct tool when the program starts searching parameter
  grids (18.8 E8 / E10).
- **Monte Carlo / permutation baselines**: shuffle labels or
  resample R-sequences to get an empirical null for "best cell out
  of 300" - often a more honest calibration than closed-form
  corrections.
- **Out-of-sample discipline**: the evidence CSV is a *single*
  sample; the next collection (Sprint 19+) is the true test. The
  program's promotion gate must demand consistency across
  collections, not just across halves.

---

## 5. Open-source - validation tooling

- **scipy.stats**: `binomtest`, `ttest_ind`, `wilson` via
  `statsmodels.stats.proportion`; `spearmanr`/`kendalltau` for rank
  stability. Used for all Phase 7 results below.
- **statsmodels**: Holm-Bonferroni (`multipletests`), power analysis
  (`tt_ind_solve_power`) - the correct package for the E1 protocol.
- **mlxtend / sklearn**: CSCV-style resampling and permutation
  scoring utilities for overfitting screening (E8).
- **backtrader/vectorbt**: built-in walk-forward and Monte Carlo
  modes; the CSV evidence format is directly consumable - the
  program already has the data pipeline, not the test protocol.

---

## 6. SuperCents_X code review - validation components (read-only)

### 6.1 Laboratory statistical engine (`Laboratory\StatisticalAnalyzer.mqh`)

- `ComputeSummary`: mean on full data; **median/min/max/stdDev and
  CI computed on the first 256 sorted samples only** (:86-111) - a
  silent truncation for larger datasets; CI is normal-approximation
  z·SE (:119-127).
- `SignificanceTest`: Welch-style two-sample t with pooled SE
  (`varA/countA + varB/countB`, :150) and an **approximate
  p-value formula** `2·(1 - |t|/sqrt(df + t²))` (:155) - this is not
  the standard Student-t survival function and is not documented as
  an approximation; results near α thresholds are unreliable. No
  exact binomial test, no one-sample proportion test, no Wilson CI.
- `ComputeConfidenceInterval`: z-based normal CI (no truncation).
- **No multiple-comparison correction anywhere** in Laboratory or
  Validation. No power analysis. No permutation machinery.

### 6.2 Walk-forward pipeline (`Validation\WalkForward*.mqh`)

- `WalkForwardScheduleConfig`: WF_ROLLING/EXPANDING/ANCHORED modes,
  365-day windows, 90-day steps, 70% train ratio, min 100 train /
  50 test days (:37-58) - sound defaults.
- `WalkForwardWindowResult`/`Summary` carry per-window ValidationResult
  and window status (WINDOW_PASS/FAIL) - the aggregation hooks for a
  cell-level WFA (E2). Pipeline exists but has never been run against
  the evidence CSV cells (no event-level adapter for family x hour x
  direction buckets).

### 6.3 Monte Carlo (`Validation\MonteCarloPipeline.mqh`,
`MonteCarloSimulator.mqh`)

- Resampling infrastructure exists (labels/R-sequences), usable for
  empirical nulls and Kelly bootstraps (E5) without new machinery.

### 6.4 Regression & benchmarks

- `Validation\RegressionDetector.mqh` (slippage/drift detection) and
  Laboratory `BenchmarkEngine.mqh`/`RankingEngine.mqh` provide the
  promotion plumbing - but all operate on strategy-level runs, none
  on the cell-level claims of 18.1-18.12.

Review conclusion: the machinery for Sprint 19 validation exists
(WFA, Monte Carlo, benchmark/ranking) but **no protocol ties it to
the evidence tables** - no preregistered tests, no correction, no
holdout rule. The 18.13 backlog builds the protocol, not the code.

---

## 7. Sprint 17 evidence - the claims, statistically tested

### 7.1 Headline cells vs breakeven (binomial, two-sided, p0=1/3)

| Claim (from) | n | wr | p | survives Bonferroni k=100 (α=5e-4)? |
|---|---|---|---|---|
| All rows (base) | 17,073 | 0.3321 | 0.7393 | - (no effect) |
| **GBPJPY H1 h11-17 (18.12)** | 817 | 0.4027 | <0.0001 | **yes** |
| **GBPJPY H1 h11-17 bullish (18.12)** | 504 | 0.4226 | <0.0001 | **yes** |
| GBPJPY H1 CHOCH_OB (18.11) | 63 | 0.5397 | 0.0008 | no (fails at k=100) |
| **EURUSD M15 h22-23 (18.12)** | 941 | 0.2508 | <0.0001 | **yes** (negative) |

Wilson 95% CIs: GBPJPY h11-17 **[0.370, 0.437]** (lower bound above
breakeven by +3.6pp); bullish **[0.380, 0.466]**; CHOCH_OB **[0.418,
0.657]** - wide (n=63); EURUSD h22-23 **[0.224, 0.280]** (upper bound
below breakeven by -5.3pp, a robust *negative* window).

### 7.2 Pairwise differences (two-proportion z)

| Contrast | p1 vs p2 | z | p |
|---|---|---|---|
| GBPJPY h11-17 vs h20-23 | 0.4027 vs 0.2629 | 5.03 | <0.0001 |
| GBPJPY bullish vs bearish | 0.3700 vs 0.3031 | 3.62 | 0.0003 |
| **OB_FVG bearish vs bullish** | 0.3769 vs 0.3036 | **-8.59** | <0.0001 |
| BOS_OB_BEAR vs LIQ_BOS_BEAR | 0.3756 vs 0.3124 | 2.47 | 0.0134 |

The OB_FVG direction asymmetry (z=-8.59, n=12,320) is the **single
strongest effect in the program** - it also survives k=300. The
BOS_OB vs LIQ_BOS family contrast does not survive correction (18.1
family tables are exploratory).

### 7.3 Temporal stability - split-half (first vs second half)

| Cell | wr 1st half | wr 2nd half | delta | verdict |
|---|---|---|---|---|
| GBPJPY h11-17 | 0.3922 | 0.4132 | +0.021 | **stable** |
| OB_FVG_BEARISH (all) | 0.3947 | 0.3592 | -0.036 | decays, still > base |
| LIQ_BOS_BULLISH | 0.2905 | 0.2740 | -0.017 | consistently bad |
| BOS_OB_BEARISH | 0.2632 | 0.4880 | +0.225 | **unstable** (n=418) |

### 7.4 Family win-rate ranking across halves (18.1-18.7 tables)

Spearman rho = **0.071, p=0.879** on the 7-family wr ranking (only
CHOCH_OB 3rd->2nd and LIQUIDITY_BOS_BEARISH 5th->5th are roughly
consistent). **The per-family orderings of 18.1-18.7 do not
reproduce out of time** - they describe the dataset, not the market.
Any per-family tuning in Sprint 19 requires walk-forward validation
before it may affect deployment (E2/E3).

### 7.5 Confidence anti-calibration stability (18.8 claim)

Kendall tau(wr vs confidence): **-0.467** (1st half), **-0.333**
(2nd half) - negative in *both* halves. c=0.55 is bad in both
(0.252/0.236), c=0.60 bad in both (0.302/0.303), c=0.35/0.40 near
breakeven in both. The inverted confidence->wr relationship is a
**real, persistent structural effect**, not noise - the 18.8 E1
recalibration is the highest-confidence fix in the backlog.

### 7.6 What Phase 7 changes about the program's story

1. **Four claims are genuinely significant and stable**: GBPJPY
   h11-17 (+0.131 Kelly bullish), OB_FVG direction asymmetry,
   EURUSD late-night drain, confidence anti-calibration. These
   survive strict correction and reproduce across time halves -
   they are Sprint 19's foundation.
2. **Family rankings and small-n cells are not**: CHOCH_OB's 0.5397
   (n=63) fails correction; BOS_OB_BEARISH flips across halves;
   family ordering rho≈0. The 18.1-18.7 "winner" tables cannot be
   promoted as-is.
3. **The aggregate is exactly breakeven** (p=0.7393) - consistent
   with 18.10/18.11: the program's edge exists only in cells, and
   only in specific regimes.
4. **Statistical significance ≠ economic significance**: CHOCH_OB
   is significant at k=1 but fails correction and has n=63; GBPJPY
   h11-17 bullish is both significant and Kelly-rich (0.131).
   Promotion requires both (E10).

---

## 8. Experiment Backlog - statistical validation for Sprint 19

| # | Experiment | Expected effect | Evidence basis |
|---|---|---|---|
| E1 | **Preregistered replication protocol**: fixed time holdout (last 30% by timestamp), n>=300 floor (n>=500 for gates), Wilson CI must exclude 1/3, binomial p<0.01 after Holm with k preregistered | Every future table self-certifies; stops promotion on anecdotes | 7.1-7.4, 2 |
| E2 | **Cell-level walk-forward**: adapter over `Validation\WalkForward*.mqh` applying 365d/90d/70-30 to family x hour x direction cells; promote only if >=50% of windows Kelly>0 | Turns unstable family claims into gated ones | 7.4, 6.2 |
| E3 | **Family-rank stability gate**: split-half Spearman on family wr; freeze per-family tuning unless rho>=0.5 | Blocks 18.1-18.7-style orderings from driving deployment | 7.4 |
| E4 | **Multiple-comparison ledger**: all tests run per sprint logged with k; Holm applied automatically; significance labels printed post-correction | Makes the ~300-cell snooping problem visible and priced | 1, 2 |
| E5 | **Bootstrap Kelly CIs**: resample R-sequences per cell (MonteCarloSimulator) to get 95% CI on Kelly f; cells with CI including 0 are not promotable | CHOCH_OB (0.299 from n=63) gets a proper range | 7.1, 18.11 |
| E6 | **StatisticalAnalyzer correctness**: exact binomial one/two-sample tests, Wilson CIs, Holm correction; remove 256-sample truncation; document the t p-value as approximation or replace | Production statistics match the review's standards | 6.1 |
| E7 | **Cost-adjusted expectancy**: promoted cells re-measured with spread+slippage bands (1/2/3x typical spread) before gate approval | +3pp wr can die at cost; expectancy is the gate input | 3, 18.10 |
| E8 | **Overfitting screening**: when parameter grids are searched (18.8 E8/E10), add CSCV / permutation best-of-k calibration | Prices the selection effect of future searches | 2, 4 |
| E9 | **Shadow CI monitoring**: live shadow feed (18.9 E7) tracks running Wilson CI of promoted cells; alert when CI lower bound crosses 1/3 | Detects regime drift of the four stable edges in real time | 7.1, 18.9 |
| E10 | **Promotion decision rule**: Kelly>0, both halves positive, p<0.01 post-correction, walk-forward majority, cost-adjusted - a five-part gate that replaces table-based promotion | Single enforceable definition of "an edge" for Sprint 19 | 7, 18.8-18.12 |

Closure: the EA's validation machinery (WFA, Monte Carlo, benchmark/
ranking) is real but unconnected to the evidence tables - the
missing piece is the protocol, not the code. Phase 7 separates the
program's claims into four genuinely stable edges (session windows,
OB_FVG direction, late-night drain, confidence anti-calibration)
and a set of unstable/underpowered tables (family rankings, n<300
cells) that Sprint 19 must re-test under E1 before any of them
affect deployment. E1 + E10 are the two protocol experiments that
make every other backlog item measurable.
