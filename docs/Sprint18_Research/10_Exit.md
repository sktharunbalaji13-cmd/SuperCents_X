# 18.10 - Exit Layer Research

Status: **COMPLETE** (2026-08-02). 8-phase deep research review of the
exit layer: the forward-outcome simulation (which produced every
outcome in the evidence dataset), the live position-management
lifecycle (breakeven/trailing), and the exit-level policies. Phase 7
measures the realized R-multiples, exit reasons and holding times of
all 17,073 signal rows.

Evidence dataset (frozen, fingerprint
`2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`):
19 merged v3 files; decided+signal 17,073 rows; WIN 5,670 / LOSS
11,398 / BE 5; base win rate 0.3321.

---

## 1. Foundation - scope of the exit layer

The exit layer converts a signal into a realized R-multiple. Two
distinct mechanisms exist in SuperCents_X:

1. **Forward outcome simulation** (`Telemetry\ForwardOutcomeSimulator.mqh`
   + `OutcomePolicies.mqh`): produced EVERY outcome in the evidence
   dataset (virtual trades entered at next-bar open, exits at
   SL/TP/horizon). This is the dataset's outcome engine.
2. **Live position lifecycle** (`Entry\PositionLifecycleManager.mqh`):
   manages real broker positions (breakeven, trailing stop,
   partial-close detection, restart recovery). Shadow mode means it
   has never managed a real trade (18.9).

Phase 7 exploits the `rMultiple`, `barsHeld`, `exitReason` columns to
measure the exit behavior of the whole dataset.

---

## 2. Academic - exit research

- **Exit timing and R-multiples**: exits are the dominant lever on
  expectancy; for a fixed-entry system, expectancy = wr x avgWinR -
  (1-wr) x avgLossR, so exit policy sets the R distribution.
- **Tie-breaking**: when SL and TP are both touched in one bar,
  conservative (SL-first) tie-breaking is standard in backtesting
  (Kestner 2003; Pardo 2008); the simulator implements it correctly
  (SL checked before TP per bar, `ForwardOutcomeSimulator.mqh:129-162`).
- **Trailing stop research**: trailing exits improve payoff shape
  (positive skew, lower max drawdown) but reduce win rate and
  expectancy in ranging markets; the optimal trail distance is
  volatility-scaled (ATR-based), not fixed-point.
- **Horizon/time exits**: capping holding time prevents capital lockup
  and truncates adverse excursions; but a fixed-bar horizon exits
  winners early in trending regimes and holds losers in ranging ones -
  the measured horizon results (Phase 7) quantify this asymmetry.
- **Breakeven stops**: move SL to entry after 1R profit - reduces
  win-rate volatility at the cost of truncating some winners; doctrine
  uses R-based triggers (the EA's 1R default).

---

## 3. Professional - exit tactics

- **Fixed RR**: simplest, measurable, doctrinaire (2R target / 1R
  stop); requires wr > 1/(1+RR) to break even (33.33% at 2R).
- **Structure-based targets** (opposing OB/FVG/liquidity, previous
  swing): align exits with the same structure that produced the entry;
  the EA's TargetResolver implements all five variants (18.9 6.7).
- **Trailing**: activation at 1-2R, distance 0.25-0.5R; converts
  runners into trend exits; the EA defaults to 2R activation, 100
  points distance (a fixed price distance, not R-scaled - a review
  finding).
- **Break-even management**: 1R trigger default; the EA implements
  it with a correctness guard (improvement-only SL move, live bid/ask
  checks, broker stops-level check).
- **Exit discipline**: exit policies must be fixed per experiment;
  the evidence dataset's single-policy design (FixedRR 2R/1R, Phase 7)
  is the correct scientific choice for signal measurement.

---

## 4. Institutional / Quant - exit execution

- **TCA for exits**: exit fills (SL as stop-market, TP as limit)
  differ; the simulator's assumption that SL fills at the exact level
  is optimistic (slippage, gaps) - worst-case modeling would fill SL
  beyond the level.
- **Risk-adjusted exit metrics**: expectancy in R, profit factor,
  payoff ratio (avg win R / avg loss R) and max adverse excursion
  (MAE) are the standard exit diagnostics; Phase 7 reports the first
  three.
- **Position management automation**: breakeven/trailing via broker
  orders (not EA-loop) is preferred for reliability; the lifecycle
  manager modifies broker SL/TP and re-discovers positions on restart
  (recovery-capable - good practice).

---

## 5. Open-source - exit simulation conventions

- **vectorbt / backtrader / zipline**: standard conventions are
  next-bar-open entry, SL/TP order book simulation with
  conservative tie-break, and optional trailing via order objects.
  The EA simulator's conventions (entry at `open[entryBarIndex]`,
  SL-before-TP, trailing ratchet before bar check) match the
  mainstream; its horizon exit at `close[minBar]` is a defensible
  choice (evaluate at last scanned close).
- **Lookahead discipline**: SL/TP levels are resolved from bar
  `entryBarIndex` data only (ATR at entry bar); no future bars inform
  the levels - correct (verified in `OutcomePolicies.mqh`).
- **Missing convention**: limit-entry fill realism (zone retest) is
  not modeled in the outcome engine (entry always at next open) -
  the 18.9 E9 gap.

---

## 6. SuperCents_X code review - the exit chain (read-only)

### 6.1 Forward outcome simulator (`Telemetry\ForwardOutcomeSimulator.mqh`)

- Entry at `open[entryBarIndex]` (:83) - no lookahead on the entry
  bar; bars scanned from `entryBarIndex-1` downward up to
  `maxHoldBars` (default 50) (:98-106).
- Trailing ratchets the stop BEFORE the bar is checked
  (:108-127) - correct order, never moves back (extreme-based).
- Conservative tie-break: SL tested before TP within each bar
  (:129-162) - versioned policy assumption, documented in the header.
- Horizon exit at `close[minBar]` (:170-176); R classified with
  BREAKEVEN epsilon 0.05R (`OUTCOME_CLASSIFY_EPS`, :26) and explicit
  EXIT_REASON_BREAKEVEN.
- Outcome classes: WIN if R > +0.05, LOSS if R < -0.05, BREAKEVEN in
  between (:34-51).

### 6.2 Outcome policies (`Telemetry\OutcomePolicies.mqh`)

- CFixedRRPolicy: SL = 1.0 x ATR(14), TP = 2.0 x ATR(14), no trailing
  (:23-68). **This is the policy that produced the evidence dataset**
  (verified: every TP exit at exactly +2.0R, every SL at -1.0R, 7.1).
- CATRPolicy: independent SL/TP ATR multiples (1.5/3.0 defaults) (:70).
- CTrailingPolicy: FixedRR + trailing after trailActivationR (1.0)
  with trailDistanceR (0.5) (:113).
- CEntryResolverPolicy: live-entry-pipeline SL/TP when a setup can be
  built, else FixedRR fallback (:169-236) - the bridge to the live
  planner policies (18.9 6.6/6.7); note it reads the LAST signal only
  (getSignal(count-1)).

### 6.3 Live lifecycle (`Entry\PositionLifecycleManager.mqh`)

- Contexts per broker position; restart recovery via comment tag
  `-P<decisionId>` (ParseEntryDecisionId :591-603); position discovery
  each Update (:271-314).
- State machine DISCOVERED -> OPEN -> BREAK_EVEN / TRAILING / PARTIAL
  -> EXIT_PENDING / CLOSED (:371-434).
- Breakeven: trigger at 1.0R default (`m_beTriggerR`, :100), SL ->
  entry price, improvement-only + live-price sanity (:474-505);
  applied once (`breakEvenApplied`).
- Trailing: trigger at 2.0R default, distance `m_tsDistance = 100 *
  _Point` (:103) - a **fixed price distance (10 pips EURUSD), not
  R- or ATR-scaled** (inconsistent with the simulator's R-based
  trailing); ratchet improvement-only, stops-level guard (:511-561).
- Partial-close detection (:451-468); closed-position event publishing
  via event bus (EVENT_POSITION_CLOSED, :332-347); lifetime stats.
- Guards: RR ratio uses initialStop vs live bid/ask (:567-585).

### 6.4 Exit-level telemetry

- CSV columns: `rMultiple`, `barsHeld`, `exitReason` (1=TP, 2=SL,
  3=BREAKEVEN, 4=HORIZON per TelemetryTypes.mqh:124-131), `entryPrice`,
  `exitPrice`, `actualOutcome`, `actualOutcomeSource`.
- `actualOutcome == 0` on ALL 17,073 rows: the actual-vs-simulated
  comparison columns were never populated (no live trades; 18.9
  confirmed shadow-only operation).

---

## 7. Sprint 17 evidence - exits, measured

### 7.1 The dataset is a single-policy 2R/1R experiment

rMultiple is exactly bimodal for 99% of rows: TP = +2.000 (n=5,540),
SL = -1.000 (n=11,341), HORIZON (n=192, mean +0.437R, median +0.479R).
No BREAKEVEN exits exist (no trailing, no BE in FixedRR). Every
row was simulated with CFixedRRPolicy(1.0, 2.0), ATR(14) risk
distance, maxHoldBars=50, next-bar-open entry, SL-first tie-break.

### 7.2 Expectancy and profit factor

| Metric | Value |
|---|---|
| Base win rate | 0.3321 (breakeven at 2R = 0.3333) |
| Mean R per trade | **-0.0104 R** |
| Profit factor (sum winR / sum lossR) | **0.984** |
| Avg win R | +1.973 |
| Avg loss R | -0.997 |
| Payoff ratio | 1.98 |

The signal system is **marginally negative at the 2R/1R policy**:
win rate is 0.12pp below the 2R breakeven rate, and the payoff
asymmetry (horizon exits) cannot rescue it. This is the quantitative
form of the 18.1-18.8 "flat reliability" finding: even the win rate
is honest, the policy is at breakeven, so no gate on this score
creates value (consistent with 18.8's gate sweep being flat-to-
negative).

### 7.3 Exit reasons and holding times

| Exit | n | % | mean R | med bars M15 | med bars H1 |
|---|---|---|---|---|---|
| TP (1) | 5,540 | 32.4% | +2.000 | 6 | 6 |
| SL (2) | 11,341 | 66.4% | -1.000 | 4 | 4 |
| HORIZON (4) | 192 | 1.1% | +0.437 | 51 | 51 |

- **SL resolves faster than TP (median 4 vs 6 bars)** - adverse
  excursions arrive sooner than favorable ones; consistent with
  spread/volatility costs and momentum characteristics of the
  entries.
- Horizon exits always run the full 50-bar window (barsHeld=51) -
  the horizon exit only fires when neither level is touched; its mean
  +0.437R shows the time exit captures value that the fixed levels
  miss (it converts would-be losers into small winners 67.7% of the
  time).

### 7.4 Horizon behavior is family-dependent (measured)

| Family | HORIZON n | mean R | win rate |
|---|---|---|---|
| OB_FVG_BEARISH | 59 | **+0.707** | 0.847 |
| LIQUIDITY_BOS_BEARISH | 37 | +0.578 | 0.784 |
| CHOCH_OB_REVERSAL | 23 | +0.439 | 0.739 |
| OB_FVG_BULLISH | 53 | +0.309 | 0.642 |
| LIQUIDITY_BOS_BULLISH | 44 | +0.236 | 0.568 |
| BOS_OB_BEARISH | 10 | -0.230 | 0.500 |
| BOS_OB_BULLISH | 8 | -0.416 | 0.375 |

The 50-bar time exit is a **positive filter for OB_FVG/LIQUIDITY
bearish and a negative one for BOS_OB**: bearish entries that do not
hit either level drift favorably, bullish BOS_OB entries drift
adversely. The horizon policy is not family-neutral.

### 7.5 What Phase 7 means for the exit layer

1. **The exit policy is the dataset's single biggest structural
   assumption**: all 18.1-18.9 conclusions are conditional on 2R/1R
   FixedRR with 50-bar horizon. Exit-policy variation (trailing, ATR
   multiples, entry-resolved levels) has never been measured against
   signals - the exit layer is the least-explored variable in the
   program.
2. **Breakeven expectancy**: PF 0.984 means the gate/selection fixes
   of 18.7-18.9 must produce > 0.12pp wr lift just to reach parity,
   and > 1-2pp to be economically meaningful at 2R.
3. **Time exits interact with family**: a family-aware horizon
   (e.g., 50 bars for OB_FVG_BEARISH, shorter for BOS_OB) is a
   testable, evidence-backed intervention.
4. **Live management parity gap**: the live lifecycle trails at fixed
   100 points and break-evens at 1R, while the evidence was collected
   without trailing - a live deployment would exit differently from
   the measured dataset.

---

## 8. Experiment Backlog - exit layer for Sprint 19

| # | Experiment | Expected effect | Evidence basis |
|---|---|---|---|
| E1 | **Exit-policy matrix on frozen signals**: re-simulate the 17,073 rows under ATR (1.5/3.0), Trailing (1R activation/0.5R), EntryResolver (live-level) and horizon {10, 20, 50} - same entries, different exits | Maps expectancy/PF across exit policies; identifies the best policy per family | 7.2, 7.4 |
| E2 | **Family-aware horizon**: per-family maxHoldBars (e.g., BOS_OB shorter) from measured horizon R | Removes the family-asymmetric horizon drag (BOS_OB -0.42R) | 7.4 |
| E3 | **R-scaled live trailing**: replace `m_tsDistance = 100*_Point` with ATR- or R-scaled distance (align with CTrailingPolicy semantics) | Removes the fixed-price/trailing-in-price mismatch; makes live exits comparable to measured | 6.3 |
| E4 | **SL fill realism**: model SL slippage/gap (fill beyond level, e.g., +0.1-0.3R adverse) and re-measure expectancy | Quantifies how much of the -0.0104R is fill-optimism | 4, 6.1 |
| E5 | **Fast-SL investigation**: SL median 4 bars vs TP 6 bars - test wider ATR stops (SL 1.5-2.0 ATR) and volatility-scaled stops | Addresses the adverse-excursion asymmetry at its source | 7.3 |
| E6 | **Breakeven in simulation**: add EXIT_REASON_BREAKEVEN path (1R trigger) to the outcome engine and re-measure | The dataset has zero BE exits; live doctrine uses BE - parity needed | 7.1, 6.3 |
| E7 | **Exit-reason telemetry for live shadow**: populate `actualOutcome`/`actualOutcomeSource` once live executions begin; record real exit reason per position | Closes the simulated-vs-actual gap (currently 0 on all rows) | 6.4 |
| E8 | **Per-family payoff doctrine**: report wr/meanR/PF per family x exit policy; gate on expectancy, not wr | Replaces single-policy breakeven with family-level economics | 7.2, 7.4 |
| E9 | **EntryResolver parity test**: measure how often the live entry pipeline produces a valid setup vs FixedRR fallback (CEntryResolverPolicy) and the resulting R distribution | Quantifies the bridge between simulated and live exit levels | 6.2 |
| E10 | **Tie-break sensitivity**: flip to TP-first tie-break on a subset and measure expectancy delta | Documents the conservative-bias cost (SL-first) of the dataset | 6.1 |

Closure: the exit layer is a single-policy, correctly-implemented
simulation (no lookahead, conservative tie-break) that has been the
frozen outcome engine for the entire program. Its headline numbers
(PF 0.984, -0.0104R, fast-SL asymmetry, family-dependent horizon)
make the exit policy the second-highest-leverage variable after the
confidence architecture (18.8) - E1 (policy matrix) is the natural
next study and needs no new data, only re-simulation of frozen
signals.
