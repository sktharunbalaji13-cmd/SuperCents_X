# 18.15 - Research Synthesis & Experiment Backlog

Status: **COMPLETE** (2026-08-02). Closing document of the Sprint 18
Deep Research Program. Merges the 14 domain reviews (18.1-18.14,
~130 experiment cards) into one deduplicated, prioritized **Master
Experiment Backlog** for Sprint 19, states the program's headline
findings with their measured evidence, and fixes the
`Evidence/Sprint17/README.md` naming instruction (future collections
go to `Sprint19/`, since `Sprint18/` must not be created).

Evidence dataset (frozen, fingerprint
`2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`):
17,073 decided+signal rows, 18,686 total, three cells (EURUSD M15,
EURUSD H1, GBPJPY H1), six months, schema v3. All findings below are
measured (18.8-18.14 Phase 7 runs) unless marked otherwise.

---

## 1. Program headline findings (measured)

### F1 - The aggregate is exactly breakeven; the edge is cell-concentrated

- Whole-set win rate 0.3321 vs 1/3 breakeven: **p = 0.7393** (18.13).
- Mean R -0.0104, profit factor 0.984, Kelly f = 0.000 on the full
  R sequence (18.10, 18.11). The signal engine as deployed has **no
  aggregate edge** - but four stable sub-edges exist (F2-F5).

### F2 - Four claims are statistically real AND time-stable (18.13)

| # | Claim | Key statistics | Status |
|---|---|---|---|
| F2a | **Session windows** (GBPJPY H1 h11-17; EURUSD 04-07/15-20) | wr 0.4027, Wilson CI [0.370, 0.437] excludes 1/3, p<0.0001, halves 0.392/0.413 stable | Significant + stable |
| F2b | **OB_FVG direction asymmetry** (bearish 0.3769 vs bullish 0.3036) | z = -8.59, p<0.0001 (strongest effect in program) | Significant + stable |
| F2c | **Late-night drain** (hours 22-03 all cells) | e.g. EURUSD M15 h22-23 wr 0.2508, CI [0.224, 0.280], p<0.0001 | Significant + stable |
| F2d | **Confidence anti-calibration** | Kendall tau(conf, wr) = -0.467 / -0.333 in both halves; ECE 0.1022 (18.8) | Significant + stable |

### F3 - The confidence map is anti-predictive and fixable

- Raw map: AUC 0.492 (worse than coin flip), Brier 0.2385 = baseline,
  top-decile wr 0.3130 **below** base (18.8, 18.13, 18.14).
- A logistic baseline on existing telemetry (18.14): AUC 0.554,
  Brier 0.2195 (below baseline), ECE 0.036, top-decile wr 0.3958
  (+6.4pp over base). Learned coefficients independently confirm
  F2d (weight on `confidence` = -0.053) and F2b (direction -0.074).
- The fitting machinery already exists and is **disconnected**:
  `Calibration\` (isotonic/Platt/temperature + ExperimentRunner +
  PromotionGate) has zero production references (18.14 6.1).

### F4 - Regimes dominate structure; news is unmanaged

- Regime proxy (hour+direction+ruleScore) AUC 0.546 > confluence
  layers AUC 0.519 (18.14 7.4) - time-of-day is the first-order
  conditioning variable (18.12).
- **Zero news/calendar code** repo-wide; SessionValidator exists but
  is unconfigured/inert; TrendState is a single-BOS-flip 3-state
  (18.12 6). Every cell has a Kelly-positive window AND a
  Kelly-zero late-night window (18.12 7.2).

### F5 - Family rankings do not reproduce out of time

- Split-half Spearman on family win-rate ranking: **rho = 0.071,
  p = 0.879** (18.13 7.4). CHOCH_OB's 0.5397 (n=63) fails k=100
  correction; BOS_OB_BEARISH flips 0.263->0.488 across halves.
  The 18.1-18.7 family tables describe the dataset, not the market -
  no per-family tuning without walk-forward (18.13 E2/E3).

### F6 - The exit layer is a single unexamined policy

- All 17,073 rows: fixed 2R/1R at ATR(14), 50-bar horizon, SL-first
  tie-break; no trailing, no BE, no family/regime awareness
  (18.10). SL hits faster than TP (med 4 vs 6 bars); expectancy is
  -0.0104R. The exit-policy matrix (18.10 E1) is the single most
  levered re-simulation available.

### Meta-findings

- **Schema v4 needs** (dataset cannot measure): order-level behaviors
  (slippage, fill timing - 18.9 E9), sub-minute signal timing (18.9
  E6), family coexistence / multi-evidence (18.8 E7), rule selection
  telemetry (18.7 E7), risk columns (18.11 E2), regime columns
  (18.12 E3), exit-reason columns (18.10 E7).
- **Production correctness defects found** (all read-only review):
  LiquidityEvaluator direction bug (18.4 E4), FVG fillTime bug
  (18.6 E6), freshness dead code `Bars()%20` (18.7 E5), unreachable
  entry gate minConfidence 0.75 (18.9 E8), min-lot clamp trap
  (18.11 E4), 4-week-month weekly reset heuristic (18.11 E5),
  StatisticalAnalyzer 256-sample truncation + approximate t p-value
  (18.13 E6). None were fixed (charter: no production changes).
- **Program discipline**: 15 sub-sprints, 14 domain docs + overview,
  ~1,700 lines of measured evidence, every claim tied to the frozen
  fingerprint; the 18.8 review closes the Sprint 17 SchemaV3 §6/§8
  commitment (confidence architecture reviewed with ECE/MCE/Brier).

---

## 2. Master Experiment Backlog for Sprint 19

Consolidation of ~130 cards across 18.1-18.14. Each line cites its
source card(s); Confidence grades and Evidence Strength per the
locked scales (overview §3). **P0 = gate/meta protocol; P1 = must
have; P2 = strong backlog; P3 = watchlist.** Sprint 19 rule
(locked): implement A and B first; C stays pending evidence; D/F
not implemented.

### 2.1 P0 - The promotion protocol (governs every other card)

| # | Experiment | Source cards | Conf | Basis |
|---|---|---|---|---|
| M01 | **Preregistered replication protocol** (fixed 30% time holdout, n>=300 floor / n>=500 gates, Wilson CI excludes 1/3, Holm-corrected binomial p<0.01 with preregistered k) | 18.13 E1 | A | 18.13 7 |
| M02 | **Promotion decision rule** (Kelly>0, both halves positive, p<0.01 post-correction, walk-forward majority, cost-adjusted - the five-part gate; replaces table-based promotion) | 18.13 E10, 18.11 E9 | A | 18.13 7, 18.11 |
| M03 | **Multiple-comparison ledger** (all tests logged per sprint with k; Holm applied; significance labels post-correction) | 18.13 E4 | A | 18.13 1 |
| M04 | **Cell-level walk-forward** (adapter over `Validation\WalkForward*.mqh`, 365d/90d/70-30 on family x hour x direction cells; promote on >=50% Kelly-positive windows) | 18.13 E2 | B | 18.13 7.4, 6.2 |
| M05 | **Family-rank stability gate** (split-half Spearman; freeze per-family tuning unless rho>=0.5) | 18.13 E3 | B | 18.13 7.4 |

### 2.2 P1 - Regime & news gates (F2a, F2c, F4)

| # | Experiment | Source cards | Conf | Basis |
|---|---|---|---|---|
| M06 | **Session gate with measured windows** (SessionValidator: GBPJPY H1 11-17; EURUSD H1 04-06; EURUSD M15 04-07 and 15-20) | 18.12 E1, 18.14 E9 | A | 18.12 7.2, 18.13 7.1 |
| M07 | **Late-night block** (hard-reject hours 22-03, all cells) | 18.12 E2 | A | 18.12 7.1-7.2 |
| M08 | **News gate via MT5 Calendar API** (reject [-15, +15] min around high-impact events; GBPJPY first) | 18.12 E6 | B | 18.12 6.4 |
| M09 | **Announcement-window measurement** (post-hoc tag of NFP/CPI/rate rows in CSV; quantify confounder before/with M08) | 18.12 E7 | B | 18.12 7.5.3 |
| M10 | **Cell-selective deployment** (GBPJPY_H1-bullish-only portfolio with fractional Kelly 0.1-0.5 on frozen R) | 18.11 E1 | B | 18.11 7, 18.13 7.1 |
| M11 | **Day-of-week filter** (Monday GBPJPY H1 0.4280; Friday EURUSD M15 0.3469 on holdout) | 18.12 E8 | C | 18.12 7.3 |

### 2.3 P1 - Confidence recalibration (F3)

| # | Experiment | Source cards | Conf | Basis |
|---|---|---|---|---|
| M12 | **Offline calibration pipeline** (run ExperimentRunner isotonic/platt/temperature on 70/30 time split; persist model card) | 18.14 E1, 18.8 E8 | A | 18.14 7.1 |
| M13 | **Family-conditional confidence** (replace `layerTotal/100` with measured per-family win frequency x trendAligned; monotone) | 18.8 E1, 18.7 E1, 18.5 E7 | A | 18.8 7, 18.13 7.5 |
| M14 | **Selection by measured rank** (bestRule by measured family wr/ECE, not a-priori ruleScore 70-90; fixes 85-vs-90 inversion) | 18.8 E2, 18.7 E2 | A | 18.8 7.2 |
| M15 | **Per-family promotion gate** (gate thresholds per family on calibrated confidence, e.g. OB_FVG >= 0.36) | 18.8 E10, 18.9 E1 | B | 18.8 7, 18.9 7.2 |
| M16 | **Calibrated-probability entry shadow** (log raw confidence + calibrated p per candidate in shadow; verify selection lift live) | 18.14 E6, 18.9 E7 | B | 18.14 7.3 |
| M17 | **Monotonicity guard** (regression test: gate sweeps non-decreasing / ECE per state <= threshold after constant changes) | 18.8 E6 | B | 18.8 7 |
| M18 | **Confirmation-layer rework** (trendAligned +5 family-conditional: keep for OB, remove for LIQUIDITY) | 18.8 E4, 18.4 E5 | B | 18.8 7.2 |
| M19 | **Composition ceiling removal** (rule types combining structural + liquidity evidence so high-confidence states are achievable) | 18.8 E5 | C | 18.8 7.1 |
| M20 | **Model determinism contract** (serialize fitted params; runtime applies transform only; re-validate per collection via PromotionGate) | 18.14 E7 | B | 18.14 6.1 |
| M21 | **Model retirement rule** (retire on shadow-CI or coefficient-drift violation) | 18.14 E10, 18.13 E9 | B | 18.14 4 |

### 2.4 P1 - Entry & exit layer (F6)

| # | Experiment | Source cards | Conf | Basis |
|---|---|---|---|---|
| M22 | **Exit-policy matrix on frozen signals** (re-simulate 17,073 rows under ATR 1.5/3.0, R-scaled trailing, EntryResolver, BE; gate on expectancy) | 18.10 E1, 18.10 E8 | B | 18.10 7 |
| M23 | **Unreachable-gate fix** (align EntryDecisionEngine minConfidence 0.75 with achievable range or remove; qualifies nothing today) | 18.9 E8 | A | 18.9 7.4 |
| M24 | **Full validator matrix telemetry** (no short-circuit; serialize evaluated/not-evaluated per row) | 18.9 E2 | B | 18.9 7.1 |
| M25 | **Spread warning band -> reject** (11.25-15 pip band wr 0.2444 worst class) | 18.9 E5 | B | 18.9 7.3 |
| M26 | **Distance gate recalibration** (per-symbol maxDistance in pips; 0.0050 = 50 pips EURUSD but ~10 pips GBPJPY) | 18.9 E4 | B | 18.9 7.3 |
| M27 | **R-scaled live trailing** (replace fixed `100*_Point` with ATR/R-scaled; aligns with CTrailingPolicy) | 18.10 E3 | B | 18.10 6 |
| M28 | **Fast-SL investigation** (SL med 4 bars vs TP 6; test wider ATR stops 1.5-2.0 and volatility-scaled) | 18.10 E5 | C | 18.10 7.2 |
| M29 | **SL fill realism** (model adverse fill +0.1-0.3R; re-measure expectancy) | 18.10 E4, 18.13 E7 | C | 18.10 7 |

### 2.5 P1/P2 - Structure detectors (F5 discipline applies: measure, don't trust)

| # | Experiment | Source cards | Conf | Basis |
|---|---|---|---|---|
| M30 | **Unified ATR displacement filter** (BOS/CHOCH/OB minting/sweep/FVG candle B: require ATR-relative displacement impulse) | 18.2 E1, 18.3 E2, 18.4 E3, 18.5 E3, 18.6 E1 | B | 18.1-18.6 7 |
| M31 | **MSS two-stage confirmation** for CHOCH/MSS (shared machinery with M30) | 18.3 E1 | B | 18.3 |
| M32 | **Sweep reclaim requirement** (wick beyond + close back inside within 1-3 bars before sweep counts; re-measure LIQUIDITY_BOS) | 18.4 E1 | B | 18.4 7 |
| M33 | **OB time expiry** (expire unmitigated OBs after 50-100 bars vs persist-until-flip) | 18.5 E4 | C | 18.5 |
| M34 | **FVG direction-conditioned gating** (bearish vs bullish 0.386-0.390 vs 0.267-0.294 EURUSD; separate eligibility by direction x symbol) | 18.6 E3 | B | 18.6 7, 18.13 7.2 |
| M35 | **H1 structural-layer study** (why BOS_OB/CHOCH at 0.47+/0.54 on H1 vs ~0.33 M15; session/volatility decomposition) | 18.5 E8, 18.4 E8, 18.3 E4 | C | 18.5 7.5 |
| M36 | **Recency harmonization + sequence-aware rules** (uniform evidence window; test sweep->BOS->OB ordering) | 18.7 E4, 18.7 E8 | C | 18.7 6 |
| M37 | **Swing significance filter** (ATR/prominence filter on swings; multi-TF alignment P2) | 18.1 E1, 18.1 E3 | B | 18.1 7 |
| M38 | **Trend-flip confirmation** (2+ consecutive BOS before regime flip; TrendState strength) | 18.1 E6, 18.12 E4 | B | 18.12 6.1 |
| M39 | **Time-out vs state-change expiry experiment** (N-bar signal expiry) | 18.7 E9, 18.7 E6 | C | 18.7 |
| M40 | **Volume/participation confirmation** (sweep/BOS bars) | 18.1 E4, 18.2 E6, 18.4 E10 | D | - |

### 2.6 P1/P2 - Risk & portfolio (F1: no aggregate edge -> deploy cells only)

| # | Experiment | Source cards | Conf | Basis |
|---|---|---|---|---|
| M41 | **Risk telemetry v3.1** (riskDecision, lots, dollarRisk, exposure, drawdown snapshot, session hour, day-of-week, ruleId - the single telemetry append covering 18.9/18.11/18.12 needs) | 18.11 E2, 18.12 E3, 18.9 E6 | A | 18.11 6 |
| M42 | **Family-conditional Kelly** (sizing by measured Kelly with fractional cap: 0.30 CHOCH_OB vs 0.00 LIQUIDITY) | 18.11 E3 | C | 18.11 7 |
| M43 | **Bootstrap Kelly CIs** (resample R per cell via MonteCarloSimulator; CI including 0 = not promotable) | 18.13 E5 | B | 18.13 7.1 |
| M44 | **Sequential dependence tests** (runs test / autocorrelation per cell; quantify 5-bar cooldown effect) | 18.11 E8 | C | 18.11 |
| M45 | **Drawdown-adaptive risk** (reduce risk as drawdown approaches limits instead of hard pause at -20%) | 18.11 E6 | C | 18.11 6 |
| M46 | **Correlation measurement** (realized EURUSD/GBPJPY from evidence rows; feed CCorrelationManager) | 18.11 E7 | C | 18.11 |
| M47 | **Allocation engine calibration** (capital split across cells by measured Kelly/meanR with caps) | 18.11 E10 | C | 18.11 7 |

### 2.7 P2/P3 - Telemetry (schema v4) & correctness fixes

| # | Experiment | Source cards | Conf | Basis |
|---|---|---|---|---|
| M48 | **Schema v4 append** (order-level: fill price per policy, expiry reason, evidence coexistence, rule runner-up, OB distance/age, FVG class/size, sweep quality, PP lifecycle, BOS acceptance) | 18.1 E5, 18.2 E2/E4, 18.3 E3, 18.4 E2/E7, 18.5 E2, 18.6 E2, 18.7 E7, 18.8 E7/E9, 18.9 E9, 18.10 E7 | B | 18.15 1 meta |
| M49 | **Correctness fixes** (LiquidityEvaluator direction bug; FVG fillTime split; freshness dead code removal; StatisticalAnalyzer exact binomial/Wilson/Holm + no truncation; min-lot clamp; ISO week) | 18.4 E4, 18.6 E6, 18.7 E5, 18.13 E6, 18.11 E4/E5 | A | cited docs |
| M50 | **Shadow CI monitoring** (running Wilson CI of promoted cells in shadow; alert when lower bound crosses 1/3) | 18.13 E9 | B | 18.13 7 |
| M51 | **Overfitting screening** (CSCV/permutation best-of-k when parameter grids are searched) | 18.13 E8 | C | 18.13 4 |
| M52 | **AIS evaluation** (MathNeuralNetwork vs logistic baseline; adopt only if clearly better - expected no) | 18.14 E8 | D | 18.14 7.1 |
| M53 | **Low-value watchlist** (volume P3; double-sweep D; inversion FVG D; multi-candle OB zones P2) | 18.4 E9/E10, 18.6 E7, 18.5 E6, 18.1 E2, 18.2 E5, 18.3 E5/E6 | D/C | cited docs |

---

## 3. Priority read of the master backlog

- **The first four deliverables are M01-M04** (protocol) + **M06-M07**
  (session gates): together they convert the two strongest measured
  effects (F2a, F2c) into deployable behavior under the 18.13 gate.
- **M12-M16** (calibration pipeline + family-conditional confidence)
  are the second wave: they repair the single worst component (F3)
  with machinery that already exists (18.14 6.1).
- **M22** (exit-policy matrix) is the cheapest high-leverage
  re-simulation: the entire dataset was produced under one fixed
  policy (F6); nothing else changes the economics of every row.
- **M41** (risk telemetry) unblocks every risk/regime/entry card that
  needs columns the frozen schema lacks - it is the data
  prerequisite for M11, M42, M44, M46, M47 and the v4 layer.
- Correctness fixes (M49) are A-graded, small, and independent; they
  should land first within their subsystems.

## 4. Program closure notes

- 15/15 sub-sprints complete; 15 documents committed (one commit
  each, `docs: sprint18.x`); charter honored: **no production code,
  INI, calibration or telemetry changes** - the repo diff outside
  `docs/Sprint18_Research/` is limited to the mandated
  `Evidence/Sprint17/README.md` naming fix.
- The four stable edges (F2a-F2d) are the program's legacy: a
  coherent, statistically audited deployment story for Sprint 19
  that no previous sprint possessed.
- Residual risks for Sprint 19: family-rank instability (F5) means
  M31-M40 structure experiments must be judged by M01-M05 protocol,
  never by in-sample tables; news exposure (F4) remains unmeasured
  until M09 runs; the fitted-model path (M12) must not outrun its
  own validation (M02/M21).
