# 18.11 - Risk & Portfolio Research

Status: **COMPLETE** (2026-08-02). 8-phase deep research review of the
risk layer (per-trade risk chain and portfolio risk chain) and of the
risk economics of the frozen signal set. Phase 7 computes the Kelly
criterion and fixed-fraction simulations directly on the dataset's
17,073 R-multiples - the first time the risk layer is quantified
against measured data.

Evidence dataset (frozen, fingerprint
`2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`):
17,073 decided+signal rows, R-multiple sequence in chronological
order; mean R = -0.0104, win rate 0.3321 (18.10).

---

## 1. Foundation - scope of the risk layer

Two parallel risk chains exist in SuperCents_X:

1. **Per-trade risk** (`Risk\`): CRiskManager (7-step approval chain)
   -> CPositionSizer (fixed-fraction sizing) -> CExposureTracker
   (portfolio exposure snapshot) -> CDrawdownMonitor (daily/weekly/
   equity stops with trading pause).
2. **Portfolio risk** (`Portfolio\`): CPortfolioRiskManager ->
   CPortfolioExposureTracker, CAllocationEngine, CCorrelationManager;
   plus the entry-chain RiskValidator (lot-range gate, 18.9).

Both are execution-time systems. Shadow mode (18.9) means neither has
ever evaluated a real order; the evidence dataset carries **zero risk
columns** (no lots, risk%, exposure, margin, drawdown - verified in
Phase 7). The risk layer is therefore the least-observed component of
the program.

---

## 2. Academic - risk sizing theory

- **Kelly criterion (1956) / Thorp (1997)**: for a per-trade R
  distribution, full-Kelly fraction f* maximizes E[log(1+fR)]; any
  f > f* reduces long-run growth to zero; f* <= 0 means no positive
  growth rate exists AT ANY bet size - **sizing cannot rescue a
  non-positive-expectancy signal set**.
- **Fractional Kelly (MacLean, Thorp & Ziemba 2011)**: 0.1-0.5 Kelly
  reduces drawdown variance substantially for a small growth cost;
  the standard professional compromise.
- **Fixed-fractional sizing (Vince 1992, optimal f)**: constant
  fraction of equity risked per trade; geometric compounding makes
  sequence order matter (equity-curve dependence).
- **Drawdown control**: daily loss limits, equity stops and trading
  pauses (the EA's design) are standard risk governance; the
  literature (e.g., Ralph Vince; CFA risk readings) emphasizes they
  protect capital AFTER expectancy is established, not instead of it.
- **Diversification**: multi-asset portfolios reduce variance only
  when instruments are uncorrelated; correlation management (the
  EA's CCorrelationManager) is the correct instrument-level tool.

---

## 3. Professional - risk practice

- **1-2% risk per trade** is the retail/CTA doctrine; the EA default
  (2.0%, RiskTypes.mqh:22) sits at the top of the band.
- **Limits stack**: daily -5%, weekly -10%, equity stop -20%,
  max 5 concurrent positions, 50% portfolio exposure, 80% leverage
  utilization (RiskTypes.mqh:23-30) - a conventional, defensible
  profile IF the signal set has positive expectancy.
- **Trading pause on limit breach** (DrawdownMonitor) with manual
  resume: prevents cascading losses after limit hits; the auto-resume
  question (new day/week) is delegated to the operator.
- **Risk gate ordering**: the entry chain's RiskValidator (lot
  bounds 0.01-10) is a coarse gate; the full CRiskManager chain is
  the real approval path.

---

## 4. Institutional / Quant - portfolio risk

- **Limit-based portfolio control**: the PortfolioRiskManager's
  limits (allocation caps, correlation bounds, exposure ceilings)
  mirror institutional risk limits (VaR-style caps per instrument/
  sector).
- **Capital allocation**: CAllocationEngine + AllocationEngine
  distribute risk budget across symbols; allocation quality is only
  as good as the per-symbol expectancy estimates - which the frozen
  dataset now provides (Phase 7) and the allocation engine has never
  consumed.
- **TCA/risk reporting**: no risk metrics (CAGR, max DD, Sharpe,
  Kelly) are produced from evidence; 18.13 will define the reporting
  contract.

---

## 5. Open-source - risk tooling

- **vectorbt / backtrader**: risk metrics (max drawdown, Sharpe,
  Sortino, profit factor, Kelly-style optimal f) are standard
  post-trade analytics; the frozen dataset supports all of them
  (Phase 7 implements the core subset).
- **PyPortfolioOpt / riskfolio**: allocation and correlation-based
  portfolio construction; the EA's allocation engine has the same
  conceptual scope, unmeasured.
- **Lesson**: risk analysis belongs in the offline pipeline FIRST
  (cheap, fast, exhaustive), then in the live gates. The live risk
  chain is doctrine-sound but has never been calibrated by the
  offline analysis.

---

## 6. SuperCents_X code review - the risk chains (read-only)

### 6.1 Position sizing (`Risk\PositionSizer.mqh`)

- Formula (:165-187): `riskMoney = equity x risk%/100`;
  `riskPerLot = stopDistancePoints x tickValue / (tickSize/point)`;
  `lots = floor(riskMoney / riskPerLot, volumeStep)`, clamped to
  [volumeMin, volumeMax]. Correct fixed-fractional construction.
- **Min-lot clamp finding**: when the floor result < volumeMin, lots
  are clamped UP to volumeMin, which can raise actual risk above the
  configured percent for small accounts; `dollarRisk` is recomputed
  from the clamped lots (:187) and the RiskManager catches the breach
  only AFTERWARD (6.2.4) - the system rejects instead of reducing.
- Symbol properties refreshed from broker (tick value/size, volume
  step, contract size) (:28-37) - currency-aware sizing.

### 6.2 Approval chain (`Risk\RiskManager.mqh`)

Ordered checks in `Evaluate` (:150-301):
1. initialization + dependency guard;
2. stop-distance computability (:173-181);
3. drawdown limits via `CDrawdownMonitor.CheckLimits` (:184-192);
4. max concurrent positions (default 5) (:195-204);
5. position sizing (:209-223);
6. **max risk per trade** - rejects if `sizing.dollarRisk >
   equity x risk%/100` (:224-234) - the min-lot clamp trap (6.1);
7. min/max lot size (:236-255);
8. portfolio exposure: `totalExposure + lots x entryPrice >
   equity x 50%` (:257-270);
9. leverage utilization: `(marginUsed + margin)/equity > 80%`
   (:272-286).
Rejection reasons are explicit per gate (10 distinct
ENUM_RISK_DECISION codes, RiskTypes.mqh:34-47) - good telemetry
design that is, however, logged only (never persisted).

### 6.3 Drawdown monitor (`Risk\DrawdownMonitor.mqh`)

- Daily reset at midnight, weekly reset via a **week-number
  heuristic** (`dt.year*100 + dt.mon*4 + dt.day/7`, :58) - a 4-week-
  month approximation; boundary weeks will drift from calendar weeks
  (review finding: should use ISO week number).
- Pause triggers: daily P/L <= -5% x day-start equity, weekly <= -10%
  x week-start, current drawdown >= 20% (:214-261); pause count
  tracked; manual resume only (:204-212).
- Note: the equity stop uses current drawdown vs peak, correct;
  `Update()` (which refreshes peak) must run continuously for the
  pause to engage - the RiskManager.Update() is empty (:104-106), so
  drawdown monitoring depends on the context-level Update loop
  (SymbolContext calls it; risk chain otherwise static).

### 6.4 Exposure tracking (`Risk\ExposureTracker.mqh`)

- Rebuilds per-symbol long/short volume, exposure and margin from
  broker positions on every Update (:91-100+); snapshot exposes
  totalOpenRisk, net long/short exposure, total portfolio exposure,
  margin used/free, position count.

### 6.5 Portfolio risk (`Portfolio\PortfolioRiskManager.mqh`)

- Own chain: PortfolioExposureTracker (portfolio-level exposure),
  AllocationEngine (allocation limits per symbol), CorrelationManager
  (correlation gates) + PortfolioLimits; approval counters only
  (approved/rejected), never persisted.
- Entry-chain RiskValidator (18.9): min/max lots 0.01/10 - never
  failed in the dataset (18.9 7.2).

### 6.6 What is NOT observed

No risk decision, sizing result, exposure snapshot or drawdown state
is serialized into the telemetry schema. The evidence dataset has
zero risk columns (verified Phase 7). Risk behavior is invisible in
the 18.1-18.10 analyses; this document's Phase 7 is the first
quantification.

---

## 7. Sprint 17 evidence - risk economics, measured

### 7.1 Kelly criterion on the frozen R sequence

| Segment | n | mean R | Kelly f | max growth |
|---|---|---|---|---|
| **All rows** | 17,073 | -0.0104 | **0.000** | 0.0/trade |
| EURUSD M15 | 11,519 | -0.0173 | 0.000 | 0.0 |
| EURUSD H1 | 2,772 | -0.0190 | 0.000 | 0.0 |
| **GBPJPY H1** | 2,782 | **+0.0268** | **0.013** | +0.018%/trade |

**Full-Kelly on the complete signal set is exactly zero**: no positive
bet size exists for the dataset as a whole. This is the rigorous
statement of the program's central result - the signals are at
breakeven, so every risk configuration loses or, at best, does not
grow. Fixed-fractional sizing at any fraction on the full set
compounds the -0.0104R drift toward zero (the 2% simulation decays
to 0 equity).

### 7.2 The profitable cell - GBPJPY H1 (measured)

| Family (GBPJPY H1) | n | wr | mean R | Kelly f |
|---|---|---|---|---|
| CHOCH_OB_REVERSAL | 63 | **0.5397** | **+0.579** | **0.299** |
| BOS_OB_BULLISH | 112 | 0.4464 | +0.339 | 0.170 |
| OB_FVG_BULLISH | 1,180 | 0.3653 | +0.087 | 0.044 |
| LIQUIDITY_BOS_BULLISH | 345 | 0.3304 | -0.012 | 0.000 |
| LIQUIDITY_BOS_BEARISH | 259 | 0.3089 | -0.073 | 0.000 |
| OB_FVG_BEARISH | 770 | 0.2974 | -0.108 | 0.000 |
| BOS_OB_BEARISH | 53 | 0.3585 | +0.076 | 0.038 |

Direction split: **bullish +0.1014R (Kelly 0.051), bearish -0.0906R
(Kelly 0.000)**.

The single Kelly-positive segment of the entire program is
GBPJPY_H1 bullish with OB-containing families - the same cell 18.3
(CHOCH 0.5397) and 18.6 (direction asymmetry) flagged independently.
The risk layer's measured answer to "what is worth trading": this
cell, at a fractional Kelly (e.g., 0.25-0.5 of the 0.05-0.30 range),
not the full signal set.

### 7.3 Portfolio-level implications

- **Diversification is currently negative**: the two EURUSD cells
  (Kelly 0) dominate the row count (83.7%), dragging the portfolio
  below breakeven. A portfolio that allocated by measured expectancy
  would exclude or shrink EURUSD and concentrate on GBPJPY_H1
  bullish - the allocation engine exists but has never consumed this
  evidence.
- **Risk limits are uncalibrated**: 2%/trade, -5% daily, -20% equity
  stop are doctrine defaults; against the measured GBPJPY cell
  (per-trade std 1.44R) the 2% risk produces a daily-loss-limit
  breach probability that is computable but currently not computed
  (18.13).
- **Sequence dependence**: 17,073 trades in ~7 months is
  ~120 trades/day across three cells; position clustering (cooldown
  5 bars) and same-signal overlap effects are untested (E8).

### 7.4 Data gaps

- No risk columns in the CSV (6.6): sizing, exposure, margin,
  drawdown and risk decisions are unobservable.
- The risk chains never executed a real trade (shadow mode, 18.9).

---

## 8. Experiment Backlog - risk & portfolio for Sprint 19

| # | Experiment | Expected effect | Evidence basis |
|---|---|---|---|
| E1 | **Cell-selective deployment study**: evaluate a GBPJPY_H1-bullish-only portfolio (OB families) with fractional Kelly (0.1-0.5) on the frozen R sequence - expected positive CAGR | Converts the only Kelly-positive cell into a deployable portfolio | 7.2 |
| E2 | **Risk telemetry (schema v3.1)**: add riskDecision, lots, dollarRisk, exposure, drawdown snapshot columns (append-only) | Ends the risk-layer blindness; enables gate-lift measurement for risk gates | 6.6, 7.4 |
| E3 | **Family-conditional Kelly**: per-family sizing factors from measured Kelly (0.30 CHOCH_OB vs 0.00 LIQUIDITY) with fractional-Kelly cap | Sizes by measured expectancy instead of uniform 2% | 7.2 |
| E4 | **Min-lot clamp fix**: if clamped lots breach risk%, either reject with the measured actual risk logged, or size down (scale-out) | Removes the post-hoc rejection trap for small accounts | 6.1, 6.2.6 |
| E5 | **Weekly-reset fix**: replace the 4-week-month heuristic with ISO week numbers | Correct daily/weekly loss accounting | 6.3 |
| E6 | **Drawdown-adaptive risk**: reduce risk% as drawdown approaches limits instead of hard pause at -20% | Smoother risk response; keeps the cell deployed through adverse runs | 6.3 |
| E7 | **Correlation measurement**: compute realized EURUSD/GBPJPY correlation from the evidence rows and feed CCorrelationManager | Justifies (or kills) portfolio diversification claims | 7.3 |
| E8 | **Sequential dependence tests**: runs test / autocorrelation of the R sequence per cell; test cooldown gate effect | Quantifies clustering and the 5-bar cooldown's value | 7.3.3 |
| E9 | **Risk-adjusted promotion gate**: promote execution on expectancy/PF/Kelly per cell (not aggregate wr) | Aligns the 18.15 promotion gate with economic reality | 7.1-7.2 |
| E10 | **Allocation engine calibration**: allocate capital across the three cells by measured Kelly/meanR with caps | First evidence-driven capital allocation | 7.3.1, 4 |

Closure: the risk layer is doctrine-correct but evidence-blind:
Kelly on the full frozen set is zero (no sizing saves it), while one
measured cell - GBPJPY_H1 bullish OB - is genuinely positive
(CHOCH_OB_REVERSAL Kelly 0.30). The risk backlog is built around
selective deployment (E1/E9/E10), risk telemetry (E2), and
calibration of the live chains (E3-E7).
