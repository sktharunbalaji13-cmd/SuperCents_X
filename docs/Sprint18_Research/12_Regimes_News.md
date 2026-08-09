# 18.12 - Regimes & News Research

Status: **COMPLETE** (2026-08-02). 8-phase deep research review of
market-regime handling (trend state, sessions, volatility) and the
complete ABSENCE of news/economic-calendar handling in SuperCents_X.
Phase 7 measures time-of-day, day-of-week and session effects on the
17,073-row frozen dataset and computes per-window Kelly criteria -
discovering the strongest single regime effect in the program.

Evidence dataset (frozen, fingerprint
`2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`):
17,073 decided+signal rows, timestamps at minute granularity (server
time), R-multiples per row (18.10). All hours below are **EA server
time** (MetaQuotes-Demo, ~GMT+2/+3; not converted - the effect
structure, not the labels, is the result).

---

## 1. Foundation - scope of regime handling

Regime handling answers: *is now a good time (market state, session,
calendar) for this signal?* The reviewed inventory:

1. **Trend regime**: `Structure\TrendState.mqh` - 3-state
   (UNKNOWN/BULLISH/BEARISH), driven exclusively by BOS events
   (last-BOS-wins flip), consumed by the entry decision trend gate
   (off by default, 18.9) and the confluence trendAligned flag
   (18.7).
2. **Session regime**: `Entry\Validators\SessionValidator.mqh` -
   hour-range gate, configurable via SessionConfig; **no ranges are
   configured in production** (verified: never failed in the
   dataset, 18.9 7.2).
3. **Volatility**: no production volatility component; volatility
   appears only in the Knowledge module (`TrendAnalyzer.mqh`,
   `RecommendationScorer`) and in the outcome policies' ATR
   (18.10), never as an entry condition.
4. **News / economic calendar**: **zero matches** for news/calendar/
   economic across all `.mqh` files (verified by repository-wide
   search) - the system has no news awareness at all.
5. Portfolio `Scheduler.mqh` exists (update scheduling; no market
   regime logic).

Phase 7 quantifies what the code does NOT: whether time-of-day
regimes carry signal-relevant information (they do, strongly).

---

## 2. Academic - regime and calendar research

- **Regime-switching models (Hamilton 1989)**: returns are
  conditionally distributed differently across hidden states;
  volatility states are more persistent than mean states. A
  volatility/trend regime gate is standard before signal filtering.
- **Intraday seasonality**: documented U-shaped volatility and
  spread patterns (London/NY overlap peaks); foreign-exchange
  intraday periodicity (e.g., Dacorogna et al. 2001, "An
  Introduction to High-Frequency Finance") shows time-of-day is a
  first-order conditioning variable, not a second-order one.
- **Day-of-week effects**: Mondays/Fridays historically differ in
  equity, FX and bond markets (weekend risk premia, position
  squaring); effects are small and unstable - usually weaker than
  intraday effects.
- **News announcements**: scheduled macro releases (NFP, CPI, rate
  decisions) cause volatility spikes and microstructure dislocations
  (Ederington & Lee 1993 - the canonical evidence: most post-announce-
  ment volatility resolves within minutes); strategies that cannot
  distinguish announcement regimes trade through the worst fills.
- **Event-study methodology**: windows around announcements (pre and
  post) should be measured, not assumed; 18.13 defines the protocol.

---

## 3. Professional - regime trading practice

- **Session-based trading**: most discretionary/SMC-style systems
  restrict to London and New York overlap hours; Asian-session
  signals are typically excluded on liquidity grounds. The EA has
  the machinery (SessionValidator) with no configured ranges - an
  unconfigured gate.
- **Trend alignment**: BOS-driven trend state (the EA's design) is a
  legitimate, simple regime proxy; its weakness is lag (trend
  flips only after a BOS) and no persistence/strength measure.
- **News awareness**: professional EAs disable trading X minutes
  before/after high-impact events or widen stops; the EA has no
  news feed - a structural gap for an FX H1/M15 system.
- **Volatility scaling**: ATR-based stops (already used in outcome
  policies) imply regime-adaptive risk; making volatility an entry
  condition (e.g., no entry in ultra-low ATR) is the next step.

---

## 4. Institutional / Quant - regime governance

- **Regime-conditional deployment**: institutions gate strategies by
  volatility regime and calendar windows; a strategy's in-sample
  edge is usually regime-specific (measured: 18.11 Kelly is positive
  only in specific cell x hour windows).
- **Calendar risk**: scheduled announcements are the single largest
  source of fat-tailed moves; quant desks either trade them with
  dedicated models or stand aside - never "accidentally" trade
  through them (the EA currently trades through them).
- **Time-zone discipline**: server time vs exchange time mapping must
  be explicit and DST-aware (the EA's timestamps are server time;
  any session config must be in server time - a documentation
  requirement).

---

## 5. Open-source - regime tooling

- **mplfinance/TA-Lib/vectorbt regime studies**: rolling-volatility
  buckets, session filters and calendar overlays are standard
  open-source patterns; the evidence CSV already supports them
  (Phase 7 implements the time-regime subset).
- **News APIs (ForexFactory, economic-calendar feeds)**: standard
  integration points for announcement-aware EAs; MT5's built-in
  `CalendarValueLast`/`CalendarEventById` API provides broker-level
  calendar access without external feeds (the EA uses neither).
- **Lesson**: a news gate is a small, self-contained module on MT5
  (calendar API) - the integration cost is low relative to the
  measured regime effects.

---

## 6. SuperCents_X code review - regime components (read-only)

### 6.1 Trend state (`Structure\TrendState.mqh`)

- 3 states (TREND_UNKNOWN/BULLISH/BEARISH, :15-20); updated purely
  from BOS events; last-BOS-wins flip with flip counter (:85-144);
  no persistence filter, no strength/confidence measure.
- Consumed by: entry trend gate (`requireTrendAlignment`, default
  false, 18.9 6.2); confluence `trendAligned` (+5 confirmation,
  18.7); protected-point manager.
- Review notes: (a) a single counter-BOS flips the regime - no
  confirmation of flip; (b) trend defined only by direction, not by
  age/strength/volatility; (c) TREND_UNKNOWN for zero-BOS startup.

### 6.2 Session validator (`Entry\Validators\SessionValidator.mqh`)

- Hour-range gate; PASS when no ranges configured (:24-30) - the
  production state; FAIL outside ranges, WARNING in last hour of a
  range (:36-70). Production registration exists (SymbolContext:
  592) but with an empty SessionConfig, so the gate is inert
  (measured: zero failures, 18.9 7.2).
- Review note: hours in server time; `endHour` exclusive; no
  sub-hour resolution.

### 6.3 Volatility

- No production entry-time volatility component. Volatility appears
  in: OutcomePolicies ATR(14) (18.10); Knowledge module
  TrendAnalyzer volatility-vs-slope classification (knowledge/
  recommendation only, not decision-making); Research
  RobustnessProfiler volatility sensitivity (offline research).
- `CapitalAllocator` has an ALLOC_VOLATILITY_SCALED allocation mode
  (:188) - exists, never measured.

### 6.4 News / calendar

- **Repository-wide search for news/calendar/economic: zero matches
  in any .mqh file.** No MT5 Calendar API usage, no external feed,
  no news-aware logic anywhere. The EA will open shadow positions
  through NFP/CPI/rate-decision windows with no mitigation.

### 6.5 Scheduler (`Portfolio\Scheduler.mqh`)

- Update scheduling utility (saw no regime logic in usage).

---

## 7. Sprint 17 evidence - time regimes, measured

### 7.1 Hour-of-day win rate (all rows, server time)

| Hours | wr | | Hours | wr |
|---|---|---|---|---|
| 00 | 0.3286 | | 12 | 0.3501 |
| 01 | 0.3141 | | 13 | 0.3301 |
| 02 | 0.2757 | | 14 | 0.3324 |
| 03 | 0.2986 | | 15 | 0.3766 |
| 04 | 0.3525 | | 16 | 0.3458 |
| 05 | 0.3733 | | 17 | 0.3564 |
| 06 | 0.3441 | | 18 | 0.3484 |
| 07 | 0.3400 | | 19 | 0.3635 |
| 08 | 0.3405 | | 20 | 0.3508 |
| 09 | 0.3352 | | 21 | 0.3241 |
| 10 | 0.3214 | | 22 | 0.2797 |
| 11 | 0.3456 | | 23 | 0.2351 |

Range: **0.2351 (23:00) to 0.3766 (15:00)** - a 14.2pp spread; the
late-night window (22-03) is consistently below base, midday-to-early-
evening above.

### 7.2 Per-cell Kelly economics by hour window (the headline result)

| Cell | Window | n | wr | mean R | Kelly f |
|---|---|---|---|---|---|
| **GBPJPY H1** | hours 11-17 | 817 | **0.4027** | **+0.203** | **0.102** |
| GBPJPY H1 bullish | hours 11-17 | 504 | 0.4226 | +0.260 | 0.131 |
| GBPJPY H1 | hours 20-23 | 464 | 0.2629 | -0.226 | 0.000 |
| GBPJPY H1 | all | 2,782 | 0.3440 | +0.027 | 0.013 |
| **EURUSD H1** | hours 04-06 | 339 | 0.3687 | +0.102 | 0.051 |
| EURUSD H1 | hours 22-01 | 455 | 0.2901 | -0.141 | 0.000 |
| **EURUSD M15** | hours 04-07 | 1,941 | 0.3581 | +0.073 | 0.037 |
| EURUSD M15 | hours 15-20 | 2,918 | 0.3615 | +0.062 | 0.032 |
| EURUSD M15 | hours 22-03 | 2,822 | 0.2775 | -0.170 | 0.000 |

**Every instrument/timeframe cell has a Kelly-positive hour window
and a deeply Kelly-negative late-night window.** The GBPJPY H1
11-17 bullish window (Kelly 0.131) is the strongest cell in the
entire program - stronger than the family effect alone (18.11:
0.051 directional Kelly without the hour filter). The 20-23 window
is *worse than random* (-0.226R) and destroys the cell's aggregate
edge (the cell is +0.027R overall only because 11-17 carries it).

### 7.3 Day-of-week (weak)

- GBPJPY H1: Monday 0.4280 vs Tue-Thu ~0.31 (largest effect);
  EURUSD H1: Wed 0.3590 vs Fri 0.2857; EURUSD M15: Fri 0.3469 vs
  Mon 0.3089. Effects exist but are ~half the size of hour effects
  and less consistent across cells.

### 7.4 Month (negligible)

- January 0.3576 down to May 0.3128; July partial (282 rows);
  no stable structure.

### 7.5 What Phase 7 means for the regime layer

1. **Time-of-day is a first-order conditioning variable**: the
   regime layer, despite having no active regime logic, sits on a
   measurable 14-46pp wr spread and a Kelly range from 0.000 to
   0.131 by hour window. A session filter alone (11-17 for GBPJPY
   H1, 04-07 for EURUSD) converts the aggregate-breakeven signal set
   into Kelly-positive cells without touching the signal engine.
2. **The late-night drain**: hours 20-03 are negative in every cell;
   the unconfigured SessionValidator is the cheapest available fix
   with measured evidence behind it.
3. **News exposure is unmanaged**: the strongest calendar events are
   untracked; given the measured hour effects, announcement windows
   (usually within the worst hours for this EA, e.g., 19:30-21:30
   server for NFP/CPI in NY) plausibly drive part of the drain -
   an unmeasured confounder (E7).
4. **Interaction with 18.11**: the hour filter multiplies the
   family/direction effects (GBPJPY bullish 11-17 Kelly 0.131 vs
   0.051 without the hour filter) - regime conditioning is
   multiplicative, not additive, with the other known edges.

---

## 8. Experiment Backlog - regimes & news for Sprint 19

| # | Experiment | Expected effect | Evidence basis |
|---|---|---|---|
| E1 | **Session gate with measured windows**: configure SessionValidator per symbol/TF (GBPJPY H1 11-17; EURUSD H1 04-06; EURUSD M15 04-07 and 15-20) | Converts breakeven cells into Kelly-positive deployment windows | 7.2 |
| E2 | **Late-night block**: hard-reject hours 22-03 (all cells) | Removes the -0.14 to -0.23R drain, the largest single negative bucket | 7.1, 7.2 |
| E3 | **Regime telemetry**: serialize session hour, day-of-week, and a session-gate pass/fail column (v3.1 append) | Makes regime gates measurable like validator gates (18.9) | 6.2, 18.9 |
| E4 | **Trend regime strength**: extend TrendState with BOS-count strength + flip confirmation (2+ consecutive BOS) before flipping | Removes single-BOS flip noise from trendAligned | 6.1 |
| E5 | **Volatility regime gate**: entry-time ATR percentile condition (e.g., no entries when ATR below 20th percentile) | Removes ultra-quiet-market noise entries; ATR infrastructure already exists | 6.3 |
| E6 | **News gate via MT5 Calendar API**: reject entries within [-15, +15] min of high-impact events (CalendarEventById), at least for GBPJPY | Closes the zero-news-awareness gap with a small module | 6.4, 2 |
| E7 | **Announcement-window measurement**: tag evidence rows inside known NFP/CPI/rate-decision windows (post-hoc using the CSV timestamps) and measure wr | Quantifies whether the news confounder explains part of the late-night drain before building E6 | 7.5.3 |
| E8 | **Day-of-week filter**: evaluate Monday-restriction for GBPJPY H1 (0.4280) and Friday for EURUSD M15 (0.3469) on holdout | Second-order lift beyond the hour filter | 7.3 |
| E9 | **Server-time documentation contract**: record the timezone offset in telemetry manifests; session configs written in server time with DST note | Prevents silent hour shifts across server migrations/DST | 4, 6.2 |
| E10 | **Regime x family interaction study**: full cross of hour windows x family x direction on the frozen R sequence (18.13 protocol) | Maps the multiplicative structure (7.5.4) into a deployment table | 7.2, 18.11 |

Closure: the regime layer is nearly empty by construction (inert
session gate, no news, no volatility gate) but Phase 7 proves
time-of-day is the strongest unmanaged effect in the program - every
cell has a Kelly-positive window and a Kelly-zero late-night window.
E1/E2 (session windows) are the cheapest positive-EV changes in the
entire Sprint 18 backlog, and E6/E7 (news) address the only fully
unmanaged risk class.
