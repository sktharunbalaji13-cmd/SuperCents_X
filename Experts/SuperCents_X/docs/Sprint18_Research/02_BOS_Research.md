# Sprint 18.2 - Break of Structure (BOS): Deep Research Review

Status: **complete** (research-only; no production changes)

Program: `docs/Sprint18_Research/00_Program_Overview.md`
Dataset: `Evidence/Sprint17/` frozen, fingerprint `2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90` (18,686 rows)
Method: 8-phase per the locked methodology. Phases 1-5 are literature/industry
survey (no SuperCents_X discussion). Phase 6 is the read-only code review.
Phase 7 is measured evidence only. Phase 8 is the experiment backlog.

---

# Phase 1 - Foundation

## 1.1 What a Break of Structure is

A **Break of Structure (BOS)** is the event where price closes beyond the most
recent significant swing point **in the direction of the prevailing trend**,
confirming that the trend is continuing. It is the mechanism by which a trend
extends itself: in an uptrend (higher highs / higher lows), the market makes a
pullback to a higher low, then closes above the prior swing high — a bullish BOS,
creating a new higher high. In a downtrend the mirror event closes below the
prior swing low, creating a new lower low.

Three components are universal across every school that uses the term:

1. **A reference level** — the most recent confirmed swing high (bullish) or
   swing low (bearish) in the current sequence, i.e. the structural pivot the
   engine currently protects.
2. **A break trigger** — the prevailing convention is a **body/close** beyond the
   level, not a wick touch. A wick beyond a level is treated as a liquidity event
   (sweep of resting stops), not as a structural break.
3. **A direction test** — the break must be *with* the trend. The same price
   action (a close beyond a swing) is a **BOS** when it extends the trend and a
   **CHOCH / market structure shift (MSS)** when it violates the trend. Direction
   relative to the current trend is the only test separating the two (ICT
   formulation; also SMC literature).

BOS is a **diagnostic** event, not a prescriptive entry: it confirms that the
trend narrative is intact and is used as (a) trend confirmation, (b) a structural
reference point update (the newly broken level becomes a support/resistance
candidate, the most recent swing low becomes the "protected low"), and (c) the
anchor for pullback entries in the direction of the break.

## 1.2 Origin and historical evolution

- **Dow Theory (1890s-1902; Hamilton 1922; Rhea 1932)**: the first codification of
  trend continuation logic. The primary trend "is in effect until it gives
  definite signals that it has reversed" — the definite signal being a *secondary
  reaction* that takes out the previous reaction extreme. This is BOS in all but
  name: trend continuation is confirmed by breaking the most recent counter-trend
  extreme, and reversal is only confirmed by breaking the most recent trend
  extreme on the *other* side.
- **Edwards & Magee (1948, "Technical Analysis of Stock Trends")**: systematized
  the breakout vocabulary — piercing vs closing criteria, volume confirmation on
  breakouts, "breakout from a consolidation" vs "penetration of a trendline". The
  book's insistence that **closing price, not the wick, decides a breakout** is
  the direct ancestor of the ICT body-close rule.
- **Donchian / Turtle Trading (1960s-1983)**: the mechanical implementation —
  a breakout of the N-day high/low channel is a signal *and* the trend reference.
  Donchian's "4-week rule" (1960) and the Turtle systems (20-day entry / 10-day
  exit; 55-day entry / 20-day exit) demonstrated that pure breakout logic, applied
  systematically with volatility-based position sizing, could be persistently
  profitable across diversified futures — the institutional proof that
  continuation-break detection is tradeable.
- **Richard Wyckoff (1930s)**: accumulation schematics — the Sign of Strength
  (SOS) is a rally on expanded volume that *exceeds* the prior rally high of the
  trading range; the Last Point of Support (LPS) pullback that holds above the
  range high is the Wyckoff version of "BOS then retest". Wyckoff conditioned the
  break on volume — an early significance filter.
- **Al Brooks (2009-2012)**: "breakout mode vs trading range mode" — a trend is
  defined by persistent breakouts; most breakouts fail and are quickly followed
  by a *failed breakout* trade in the opposite direction; the strength of the
  breakout bar (size, follow-through) determines whether to trade the breakout or
  the pullback.
- **ICT / Smart Money Concepts (2000s- )**: the modern vocabulary. BOS/CHOCH as a
  pair, body-close requirement, displacement (impulsive break bars), internal vs
  external structure, the three-tier swing hierarchy (STH/ITH/LTH, see 18.1
  Phase 1), and the "liquidity BOS" — a sweep of a level that traps breakout
  traders before the real continuation move.
- **Quantitative era (1990s- )**: breakout rules became a standard object of
  academic study (Brock, Lakonishok & LeBaron 1992 — see Phase 2), and the
  underlying phenomenon was studied under "structural breaks" and "change points"
  (Andreou & Ghysels 2009 — see Phase 2).

## 1.3 Mathematical formulation

Given a swing detection function that produces ordered swing points
\(S = (s_1, s_2, \dots)\) with swing highs \(H_k\) and swing lows \(L_k\), and a
trend label \(T \in \{\text{BULL}, \text{BEAR}\}\) derived from the swing
sequence (HH/HL vs LH/LL):

**Bullish BOS** at bar \(t\):
\[
T = \text{BULL} \quad\wedge\quad \text{Close}_t > H^*_{k}
\]
where \(H^*_k\) is the latest swing high in the current sequence (the "protected"
high). **Bearish BOS**:
\[
T = \text{BEAR} \quad\wedge\quad \text{Close}_t < L^*_k
\]

Key design dimensions (every implementation is a choice on each):

| Dimension | Options | Notes |
|---|---|---|
| Break reference | latest protected swing only vs multiple levels (STH/ITH/LTH) | single-level is the simplest, most common; multi-level gives hierarchy |
| Trigger price | bar close vs body (open/close) vs high/low touch | close is standard; body close is the ICT norm; wick = sweep, not BOS |
| Trend context | explicit direction check vs implicit via engine state | the direction test is what separates BOS from CHOCH |
| Significance filter | none, displacement (k×ATR break bar), volume, retest/acceptance | filters false breakouts; most failure comes from skipping this |
| Re-trigger policy | per-level one-shot vs re-arm | most engines break each level once (duplicate prevention) |
| Confirmation | immediate vs N bars beyond vs retest hold | "price should hold" is the acceptance test |

The 18.1 document established the swing detection knobs (confirmation window,
significance filter). BOS adds the **break semantics** — which price (close/body),
which level (latest locked pivot), with what filter (displacement, acceptance),
and under what trend context — plus **post-break reference updates** (the broken
level becomes the new support/resistance; the opposite-type swing becomes the
protected point for invalidation).

## 1.4 Why BOS exists / why it matters

- **Stop clusters create breakout dynamics.** Osler (2000, FRBNY; Phase 2) showed
  with order-flow data that stop-loss orders cluster just beyond round levels and
  prior extremes; once those stops are triggered, their market orders accelerate
  price in the breakout direction. This is the microstructure reason a close
  beyond a swing level *on balance* leads to continuation — and also the reason
  sweeps (liquidity grabs) are common: algorithms hunt those same clustered stops.
- **Trend continuation is asymmetrically profitable.** Continuation moves in an
  established trend are the CTA/turtle domain: low win rate (30-40%) but winners
  far exceed losers. BOS is the entry family of that strategy class.
- **It is the event that updates structure.** Every BOS re-anchors the protected
  level and the invalidation point; downstream concepts (order blocks, FVGs,
  pullback entries, targets) are defined relative to the most recent BOS.
- **False breaks are the cost.** A close beyond a level can be immediately
  reversed (a *false breakout* / *sweep*). The entire engineering effort in BOS
  systems — displacement filters, body-close rules, retest acceptance — exists to
  separate true continuation breaks from sweeps, which are *also* legitimate
  signals (of the opposite move).

---

# Phase 2 - Academic literature

## 2.1 Breakout rules: the direct academic test

- **Brock, Lakonishok & LeBaron (1992), "Simple Technical Trading Rules and the
  Stochastic Properties of Stock Returns", Journal of Finance 47(5):1731-1764.**
  The canonical study of *trading range break (TRB)* rules: buy when price
  penetrates above the local maximum (resistance) of the prior N days, sell when
  it penetrates below the local minimum. Tested on the Dow Jones Industrial
  Average 1897-1986 (25,806 daily observations), with bootstrap inference
  against four null models (random walk, AR(1), GARCH-M, EGARCH).
  Findings relevant to BOS:
  - Buy signals (breaks above resistance) were followed by higher 10-day returns
    (avg 0.55% vs unconditional 0.17%) and *lower* volatility than sell signals;
    the buy-minus-sell 10-day spread averaged 0.86% across six rule variants.
  - The results were inconsistent with all four null models — i.e. continuation
    after resistance breaks was a real property of this 90-year sample, not an
    artifact of volatility clustering.
  - The study explicitly documents the behavioral rationale: sellers park orders
    at the prior peak; once exceeded, that supply pressure is converted into
    demand support — the "resistance becomes support" mechanism (role reversal).
  Caveats: data-snooping bias across many tested rules (see below); the effect
  may not survive modern transaction costs on intraday FX (see Curcio & Goodhart).
- **Sullivan, Timmermann & White (1999), "Data-Snooping, Technical Trading Rule
  Performance, and the Bootstrap", Journal of Finance 54(5):1647-1691.** The
  critical companion: applying White's Reality Check over a large universe of
  trading rules (7,846 rule specifications), the best rules no longer beat the
  benchmark with statistical significance after correcting for the multiplicity
  of tests. **Implication for BOS research: any "BOS works" claim must be
  evaluated with multiple-comparison control and out-of-sample validation.**
- **Curcio & Goodhart (1993), "When Support/Resistance Levels are Broken, Can
  Profits be Made? Evidence from the Foreign Exchange Market".** Tested
  support/resistance break rules on intraday FX data and found **no significant
  profitability** after transaction costs — the strongest counterpoint to Brock
  et al., and directly relevant because SuperCents_X trades intraday FX.
  Synthesis for this program: the balance of evidence is that *index/daily*
  breakout rules carried predictive content (Brock et al. 1992; Lo, Mamaysky &
  Wang 2000) but *intraday FX* breakout profitability is marginal-to-negative —
  which is exactly why the Sprint 17 measured evidence (Phase 7) is the
  deciding input for this project.

## 2.2 Stop clusters and the microstructure of breaks

- **Osler, C. L. (2000), "Support for Resistance: Technical Analysis and
  Intraday Exchange Rates", FRBNY Economic Policy Review 6(2):53-68.** Using
  actual stop-order placement data from a bank, Osler showed that (a) stops and
  limit orders cluster at round numbers and at prior highs/lows — the very levels
  technical analysis marks as resistance/support — and (b) when price reaches a
  cluster, order-flow imbalances at the cluster predict short-run continuation in
  the direction of the break. This is the closest academic mechanism for the BOS
  trade: the level is a *real* resting order, so breaking it is not purely
  statistical noise.

## 2.3 The underlying phenomenon: structural breaks and change points

The academic literature studies "the trend has changed its statistical regime"
under the label **structural breaks / change point detection** (econometrics) —
the continuous version of what discrete swing/BOS logic approximates:

- **Andreou & Ghysels (2009), "Structural Breaks in Financial Time Series",
  Handbook of Financial Time Series, pp. 839-870.** The standard survey:
  historical vs sequential tests; single vs multiple breaks; parametric vs
  non-parametric; implications of ignoring breaks (biased inference, unstable
  forecasts). Key message: regimes genuinely shift, and models that assume
  stability mis-calibrate risk.
- **Aue & Kirch (2024), "The state of cumulative sum sequential changepoint
  testing 70 years after Page", Biometrika 111(2):367-391.** The modern review
  of sequential (online) CUSUM procedures — the closest academic analog to an
  *online* BOS detector that must flag "the regime changed" with bounded
  delay.
- **Killick, Fearnhead & Eckley (2012), PELT**, JASA 107(500):1590-1598 —
  optimal offline segmentation; **Adams & MacKay (2007), BOCPD** — online
  Bayesian run-length inference (see 18.1 Phase 2 for the full change point
  survey). These methods detect mean/variance regime shifts — the phenomenon
  behind a "trend change" — but with **latency**: BOCPD inherently lags the
  true break by the time needed to accumulate posterior evidence.
- **Lo, Mamaysky & Wang (2000), "Foundations of Technical Analysis", Journal of
  Finance 55(4):1705-1765.** Kernel-smoothed pattern recognition on 30 years of
  US equity data: patterns (including breakouts from head-and-shoulders and
  triangles) provided statistically significant incremental information over
  the unconditional distribution. Supports the premise that structural events
  carry predictive content, with the standard caution about conditioning on
  realized patterns.

## 2.4 Academic consensus, disagreements, open questions

**Consensus:**
1. Breaking a prior extreme carries *measurable* predictive content in daily
   index/equity data (Brock et al. 1992; Lo et al. 2000).
2. Stops genuinely cluster at prior extremes, and their triggering mechanically
   accelerates price (Osler 2000) — a real, order-flow-based mechanism.
3. Regime/trend changes are real statistical phenomena that must be detected
   online with bounded delay (Aue & Kirch 2024; BOCPD literature).

**Disagreements / open questions:**
1. Whether the edge survives intraday FX after costs (Curcio & Goodhart: no;
   Brock et al. on daily indices: yes). **Open in the FX-M15/H1 context.
   Phase 7 of this document is the program's own measurement of exactly this.**
2. Whether observed profitability is real or data-snooping residue
   (Sullivan/Timmermann/White 1999). Requires multiple-comparison control.
3. Optimal break semantics: close vs body vs high/low touch; immediate vs
   confirmed vs retest-accepted. Academic work typically uses *close* (Brock
   et al.) or *penetration* (Donchian intraday); the "body close" refinement is
   practitioner folklore (Phase 3) with no direct academic test.
4. Whether displacement/momentum filters (break bar size, volume) add value is
   asserted by practitioners but lacks controlled academic tests on FX.

---

# Phase 3 - Professional trading literature

## 3.1 ICT / Smart Money Concepts — the formal BOS/CHOCH framework

The ICT formulation (as codified in ictkillzone.com 2026, smartmoneytrader 2025,
tradexis, and the SrsBlack ICT knowledge library on GitHub):

- **Definition**: "A BOS is a candle *body close* beyond the most recent swing
  high (bullish) or swing low (bearish), occurring in the *same direction* as
  the prevailing trend." Every word carries a rule: body close (not wick, not
  intrabar touch); most recent swing (not any historical level); same direction
  as prevailing trend (the BOS-vs-CHOCH test).
- **Body-close rule**: a candle that wicks beyond the level but closes inside is
  a **liquidity sweep** (stops taken, price reverses) — not a BOS. The ICT
  "Judas swing" is precisely the wick-beyond-with-close-inside event.
- **BOS vs CHOCH**: the only test is direction. In a downtrend, breaking a swing
  *high* is a CHOCH (against structure); breaking a swing *low* is a BOS (with
  structure). Common beginner error: calling any break a BOS.
- **Three-tier hierarchy**: STH/STL (5m-15m, entry triggers), ITH/ITL (1H-4H,
  primary CHOCH/MSS level), LTH/LTL (daily/weekly, macro bias). A BOS on the
  HTF sets the multi-session bias; LTF BOS is the entry trigger. **"When only
  the LTF shows the structure you want, skip the trade"** — HTF context is
  mandatory.
- **Displacement**: a valid BOS is typically accompanied by an *impulsive*
  (displaced) break candle that also creates the entry FVG; slow overlapping
  breaks are suspect.
- **Retest/acceptance**: the broken level should retest from the other side
  (role reversal) and hold; the pullback to the retest is the entry, not the
  break bar itself.
- **MSS**: an MSS is the "confirmed CHOCH" — a CHOCH followed by a BOS in the
  new direction; used as the confirmation that the reversal has institutional
  backing.

## 3.2 Breakout schools (pre-ICT)

- **Edwards & Magee (1948)**: closing-price penetration is the breakout
  criterion; volume should expand on the breakout bar; the most reliable
  breakouts come after consolidation (narrowing range) *in the direction of the
  larger trend*; failed breakouts signal the opposite move. Introduced the
  vocabulary of "penetration" (wick) vs "breakout" (close).
- **Nial Fuller (Price Action, 2008- )**: the **false breakout** as the central
  concept — "a false break is a deception: amateurs enter the obvious breakout,
  professionals push the market back the other way." False breaks *against* the
  dominant trend are the best trend-resumption signals; false breaks in ranges
  are fade setups. He emphasizes that you can never know a break is false until
  it forms — hence confirmation rules.
- **Al Brooks (2009-2012)**: "In a trend, most breakouts of the swing point lead
  to continuation; in a trading range, most breakouts fail." The context
  question (trend vs range) determines the base rate of breakout success.
  Failed breakouts are themselves the strongest reversal signals (a failed
  breakout of a swing high = high-probability short).
- **Strike.money (2026) taxonomy**: 5 BOS types — Bullish, Bearish, **Internal**
  (LTF break within HTF range), **External** (HTF break — more reliable),
  **Liquidity BOS** (brief break that grabs liquidity, then the real move
  starts after reclaim). Confirmation checklist: correct structural level,
  decisive close, strong momentum, **price holds** (does not immediately
  reverse back inside).
- **PriceActionNinja 5-point confirmation**: (1) volume >= 150% of 20-period
  average; (2) close beyond level (not wick); (3) follow-through — next candle
  closes in the same direction; (4) no immediate reversal back into the range;
  (5) role reversal on retest (old resistance = new support). Time filters:
  1-hour hold rule; daily close for HTF.
- **forexexperts.com (2025) breakout filter rules**: trend regime first
  (trend-following favors breakouts; ranges favor failures); volume >= 1.3x
  10-20 bar average; volatility filter: break-bar move > 0.5x ATR(14); retest
  entries or 1-3 consecutive closes beyond; walk-forward calibration, freeze
  thresholds for forward testing.

## 3.3 Cross-school synthesis: best practices and common mistakes

**Best practices (agreed across schools):**
1. Close/body-based break, never wick-based (ICT, Edwards & Magee, strike.money,
   PriceActionNinja).
2. Direction test against the trend — a break against the trend is NOT a BOS
   (ICT BOS/CHOCH; Dow's "definite signals").
3. Significance/acceptance: displacement (ICT, forexexperts 0.5xATR), volume
   (Fuller, PriceActionNinja, Edwards & Magee), hold/retest (strike.money,
   PriceActionNinja), or at minimum a minimum break margin.
4. HTF context gate (ICT three-tier; Fuller: trend-direction false breaks).
5. One-shot per level (each swing breaks once; avoid re-firing) — universal
   engineering convention.
6. Role reversal: the broken level becomes the reference for invalidation and
   pullback entries (ICT retest, Edwards & Magee, Wyckoff LPS).

**Common mistakes (agreed across schools):**
1. Calling wick touches BOS (sweep vs break confusion) — ICT calls this the
   single most common structural error.
2. Calling counter-trend breaks BOS (missing the direction test).
3. Trading the break bar itself instead of the retest.
4. No significance filter — every micro-break is a signal (chop).
5. Ignoring HTF context — LTF-only structure entries.
6. No hold/acceptance check — immediate reversal back inside the range after
   entry (PriceActionNinja point 4).

---

# Phase 4 - Institutional / quantitative methods

## 4.1 Donchian channels and the Turtle system (the canonical institutional breakout)

- **Richard Donchian (1960s)**: the 4-week rule — buy when price exceeds the
  highest high of the prior 4 weeks; sell when it falls below the lowest low.
  His N-day high/low channel is the mechanical definition of "the trend is
  making new highs" — a pure, parameter-light BOS detector with a rolling
  lookback instead of discrete swing points.
- **Turtle Trading (1983, Richard Dennis & William Eckhardt)**: System 1 —
  enter on 20-day high/low breakout, skip if the previous same-type signal was
  a winner (whipsaw filter); System 2 — 55-day breakout, take all signals.
  Exits: opposite 10-day (System 1) / 20-day (System 2) channel. Position
  sizing: 1 unit = 1% equity / (N x dollars-per-point), N = ATR(20) — every
  trade carries identical dollar risk.
- **Measured profile (well documented across 30+ years of CTA data)**: win rate
  30-40%, winners average 10x+ losers, small frequent losses (2N stops) with
  large occasional wins (50N+). Positive expectancy is delivered by the
  asymmetry, not by hit rate. **This is the institutional baseline that BOS
  systems are compared against** — a BOS continuation system with a >40% hit
  rate at reasonable R:R is already better than the classic baseline.
- **Modern CTA practice**: 10-20% trend exposure allocation; filters added
  (e.g., 200-day MA regime filter; "only take System 1 entries when System 2
  agrees"); 1-3 consecutive closes beyond the channel; volatility-normalized
  levels (ATR-scaled). Backtests show positive expectancy retained on
  diversified futures, with returns ~30-50% of peak Turtle-era levels — the
  edge shrank as the strategy crowded, it did not vanish.
- **Relevance to SuperCents_X**: the turtle framework is the professional-grade
  answer to "what is a BOS worth?" — a single-break signal with weak per-trade
  odds but positive expectancy when (a) sized by volatility, (b) filtered by
  trend context, (c) exited asymmetrically, and (d) diversified. The Sprint 17
  dataset measures the per-signal odds (Phase 7); the risk/portfolio sprint
  (18.11) addresses (a)-(c).

## 4.2 Volume- and volatility-based validation (quant filters)

- **Volume confirmation (industry-reported statistics)**: a CFA Institute
  publication reports breakouts with volume > 150% of the 20-day average had a
  71% follow-through rate; a TradingMarkets study reports low-volume breakouts
  failed to continue more than 58% of the time. These are widely cited
  industry figures, not peer-reviewed — Evidence Strength IV (practitioner
  observations).
- **Volatility filters (quant practice)**: require the break bar to move more
  than 0.5x ATR(14) (forexexperts) or the level to be defined in ATR units —
  normalizes across symbols/timeframes (EURUSD M15 vs GBPJPY H1 have very
  different ATR scales — relevant to SuperCents_X which trades both).
- **Channel-based alternates**: Bollinger-band breakouts (volatility-adaptive
  levels) vs Donchian (absolute extremes) — Donchian preferred by trend
  followers because it is "difficult to over-optimize" (the level is data, not
  a parameter).
- **Change-point overlays**: institutions running regime-aware systems use
  online change point detection (BOCPD; PELT offline for research) to flag
  regime shifts — the continuous-data analog of discrete BOS. Cost: detection
  latency (BOCPD lags the true break); benefit: statistical formalization of
  "when did the regime actually change?" (see 18.12 Regimes & News).

## 4.3 Quantitative implementation notes

- Execution: entries at the close of the breakout bar or the next open (Turtle
  rule); limit entries at the retest have better R:R but higher failure-to-fill
  risk.
- Duplicate prevention: each level fires once; re-arm only on new structure.
- The two biggest documented failure modes of institutional breakout systems:
  (1) ranging regimes — breakouts fail more often than they succeed (Brooks;
  investopedia continuation-pattern guidance); (2) news-time fragmentation —
  breakouts around scheduled releases are fragile once the one-time order burst
  dissipates (tradevae 2026).

---

# Phase 5 - Open-source implementations

## 5.1 Survey of implementations by family

| Implementation | Language | BOS logic | Notable engineering |
|---|---|---|---|
| `VelmoPk/Smart-Money-Concepts-indicator-MT5` | MQL5 | BOS/CHOCH + OB + liquidity sweeps + FVG, real-time | advertises no-repaint; MQL5-native |
| `haza79/MT5-Smart-Money-Concept-Indicator` | MQL5 | structure + price-action signals | older, widely forked |
| `LesleyJJ/SMCIndicator-public` | MQL5 | BoS/ChoCh detection + signals | multi-timeframe, alerts, CSV export; dashboard |
| `RichyMunalula/Smart-Money-Concepts-indicator-MT5` | MQL5 | structure visualization | institutional-style labeling |
| `SrsBlack/ict-knowledge-library` | docs (not code) | **formal criteria**: `bos-bullish := close above prior swing high`; 3-bar swing `H_n > H_{n-1} AND H_n > H_{n+1}`; STH/ITH/LTH hierarchy; EQH = liquidity pool, not swing | the most rigorous public ICT spec; used here as the reference semantics |
| MQL5 article 22249 "Market Structure Sentinel" (2026) | MQL5 | BOS/CHOCH detection + mini dashboard (trend arrows, consolidation state) | explicit discussion of repaint-free detection, structural-break validation, false-signal filtering, consolidation display |
| MQL5 article 22526 "Integrating AI into 3 SMC concepts (OB, BOS, FVG)" (2026) | MQL5 + Python/ONNX | BOS detection + XGBoost gate: "BOS Bear rejected — score: 0.xxx" | ML overlay as a *rejection* gate on raw BOS, per-bar `swing detection with DetectSwingForBar`, 50-bar lookback, `traded` flags preventing re-trigger of the same level |
| SpendDock (2026) | PineScript | BOS/CHOCH/OB/FVG indicators | structured SMC vocabulary in Pine |

## 5.2 Comparative algorithm findings

1. **The reference level is always "the most recent confirmed swing point of the
   opposite type"** — every serious implementation maintains, at minimum, the
   latest protected high and low (exactly the pattern SuperCents_X uses via
   `CStructuralPivotEngine` + `CProtectedPointManager`).
2. **Close-based break is the norm; body-close is the ICT refinement.**
   PineScript implementations often use `ta.pivothigh` + `close > level`
   (close-based); ICT-literate implementations use body (`open/close` of the
   break candle relative to the level).
3. **Repaint-avoidance is a stated first-class requirement** in the MQL5
   articles — the same constraint SuperCents_X already enforces (confirmed
   pivots only, never unconfirmed candidates).
4. **The AI overlay pattern (article 22526) is a rejection gate, not an entry
   generator**: raw BOS fires, then an ML score decides whether the BOS is
   tradeable. This matches the SuperCents_X architecture where BOS is an
   *evidence flag* consumed by the confidence/decision layer rather than an
   entry trigger itself.
5. **Multi-level support (STH/ITH/LTH) is rare in open source**; most
   implementations track only the single latest swing per type (same as
   SuperCents_X). The hierarchy is common in *docs* (SrsBlack library) but
   rare in *code* — an opportunity gap noted for 18.1 experiment E3.
6. **Few open-source implementations apply any significance filter** (no ATR
   displacement, no volume). The MQL5 Sentinel article explicitly calls
   false-signal filtering a "significant challenge" — consistent with the
   practitioner literature's emphasis on filters.

---

# Phase 6 - Current SuperCents_X implementation (facts only)

## 6.1 Architecture (structure layer)

Per 18.1 Phase 6: `CSwingDetector` produces confirmed 5-bar fractal swing
points; `CStructuralPivotEngine` promotes/replaces/locks pivots (the
"institutional replacement model"); `CProtectedPointManager` maintains active
protected points; `CTrendState` maintains the binary trend machine;
`CBOSDetector` consumes only the pivot engine API. BOS events are stored in
memory as `BOSEvent` structs (id, brokenPivotID, bullish, breakTime, breakBar,
pivotPrice, closePrice).

## 6.2 CBOSDetector (`Structure/BOSDetector.mqh`, 362 lines)

- **Reference level**: the *latest locked* pivot of each type — the most recent
  `isProtected` swing high and the most recent `isProtected` swing low are
  scanned from the pivot engine each `Update` (`:154-177`). Only protected
  (locked) pivots qualify; unconfirmed/unlocked pivots are skipped
  (`m_skippedUnlocked`, `:175`).
- **Break trigger**: bar **close** beyond the level — bullish BOS when
  `barClose > latestLockedHighPrice` (`:203`), bearish when
  `barClose < latestLockedLowPrice` (`:251`). This is close-based, matching the
  Brock/Edwards-Magee convention and approximately the ICT body-close rule
  (a long wick at the close can make close and body differ, but for most
  candles they agree).
- **No direction test inside BOSDetector**: there is no trend-context check at
  `:200-294`. A close above the latest locked high fires a "bullish BOS" even
  if the current trend is bearish. The BOS-vs-CHOCH direction test is NOT
  implemented here; it is delegated to `CTrendState` (trend flips on a single
  opposite break per 18.1 review) and the decision layer's `trendAligned`
  telemetry. **This is the single most significant semantic finding of the
  review**: the detector emits *level-break events*, and the labeling of an
  event as "BOS" vs "CHOCH" is implicit in the trend state at decision time,
  not explicit in the detector.
- **No significance filter**: no ATR displacement, no volume, no acceptance
  check, no minimum margin. Any close beyond the level fires (only the
  debug-log gap of 50 points at `:235`/`:283` is hardcoded, cosmetic).
- **One-shot per level**: `IsPivotBroken` (`:354-360`) prevents a second BOS
  against the same pivot; `m_duplicatePrevented` counts the skipped
  re-checks. Contract "never emits duplicates" is honored.
- **Both types tracked simultaneously**: the latest locked high and latest
  locked low coexist, so in the same bar both a bullish and a bearish BOS
  *could* be emitted if close exceeds the high and is below the low — not
  possible simultaneously for one close price, but both references are always
  live.
- **Performance**: `CheckBOS` re-scans all bars `1..rates_total` on every
  `Update` (`:196`) and `IsPivotBroken` is a linear scan over all emitted BOS
  events per bar — O(n*m) per update. Fine at M15/H1 cadences for 6-month
  backtests; noted for scaling.
- **Events are in-memory only**: BOS events are never written to the telemetry
  CSV; the v3 schema carries only the derived `hasBOS` flag (tristate) per
  decision row. The event chain (which pivot was broken, displacement size,
  close-vs-level distance) is not measurable from the frozen dataset.

## 6.3 Relationship to the trend machine (from 18.1 review)

`CTrendState` (`Structure/TrendState.mqh:85-144`) flips the binary
UNKNOWN/BULLISH/BEARISH label on a single break of the opposing structure.
Because BOSDetector does not gate on trend, the sequence is: (1) a close
beyond the latest locked high in a bearish trend fires a "bullish BOS" event;
(2) TrendState sees the opposing break and flips to BULLISH. In ICT terms,
step (1) should be labeled CHOCH (first break against the trend = warning) and
step (2) should be confirmed by a *second* structure event (BOS in the new
direction = MSS). The current design collapses CHOCH and MSS into one step.
This is a documented simplification, not a bug — it is a choice; its measured
cost/benefit is testable only with lifecycle telemetry (Phase 8, E4).

## 6.4 Strengths (observed, factual)

1. Close-based break (matches the dominant literature convention).
2. Breaks only confirmed, protected pivots (no repaint, no candidate breaks).
3. Strict one-shot per level (no duplicate events).
4. Clean API boundary: consumes only the pivot engine (testable, replaceable).
5. Clear separation of *event detection* (BOSDetector) from *decision*
   (confidence/evidence layer) — matches the AI-gate pattern of Phase 5.

## 6.5 Weaknesses / simplifications (observed, factual)

1. **No direction test inside the detector** — BOS vs CHOCH semantics are
   implicit (delegated to TrendState), so "BOS" events in the logs can be
   counter-trend breaks by ICT definition.
2. **No significance/acceptance filter** — no displacement, volume, retest, or
   hold requirement; contradicts the strongest practitioner consensus (3.3).
3. **Single-level reference only** — no STH/ITH/LTH hierarchy, no multi-level
   support (18.1 E3 is the backlog candidate).
4. **No telemetry of the break itself** — displacement size, distance of close
   beyond level, broken-pivot age are not in the v3 schema; only the `hasBOS`
   boolean survives (6.2). Cannot measure filter value from frozen data.
5. **Close vs body ambiguity at extreme candles** — a candle that closes
   outside the level with a long wick inside is counted as a break though the
   ICT body-close rule would reject it.
6. **Full-history rescan per update** — O(n*m) per call; harmless at current
   scale, unbounded as history grows.

---

# Phase 7 - Sprint 17 evidence review (measured only)

Dataset: frozen `Evidence/Sprint17/merged/*.csv` (19 files, UTF-16, 68 cols).
Tristate encoding: `'1'` = FALSE, `'2'` = TRUE, `'0'` = UNKNOWN/absent.
Outcome: `'1'` = WIN, `'2'` = LOSS, `'3'` = BE. All figures below computed
with the read-only scripts in this program; no production code touched.

## 7.1 Fired-rule frequency and win rates (BOS-family rules)

Decided rows: 18,536. Decided + signal rows: 17,073 (rule-0 rows excluded).
All win rates below are (wins / decided n) on decided+signal rows.

| Rule | n | Win | Loss | BE | Win rate | Layer(s) active |
|---|---|---|---|---|---|---|
| BOS_OB_BULLISH | 440 | 163 | 273 | 4 | **0.3705** | structural=30, sweep=1 |
| BOS_OB_BEARISH | 418 | 157 | 257 | 4 | **0.3756** | structural=30, sweep=1 |
| LIQUIDITY_BOS_BULLISH | 1,853 | 523 | 1,312 | 18 | **0.2822** | structural=15, sweep=2 |
| LIQUIDITY_BOS_BEARISH | 1,700 | 531 | 1,162 | 7 | **0.3124** | structural=15, sweep=2 |

Observations:
- **BOS + order block (BOS_OB) materially outperforms sweep + BOS without OB
  (LIQUIDITY_BOS)**: 0.3705/0.3756 vs 0.2822/0.3124 (+~7-9pp). The order block
  is the value-adding conjunction (consistent with the 18.1 finding that
  `hasOrderBlock=TRUE` rows win at 0.3415 vs 0.2967 overall). Raw BOS alone is
  the weak signal; BOS as an *evidence item inside a rule* behaves differently.
- **BOS_OB is the highest-volume entry-level rule pair in the dataset after
  OB_FVG** (440+418 = 858 decisions) — a tradeable sample.
- LIQUIDITY_BOS_BULLISH has a notably asymmetric result vs its bearish twin
  (0.2822 vs 0.3124) — the largest bull/bear gap among BOS rules.

## 7.2 hasBOS flag analysis (all decided rows; n=18,536)

| hasBOS | n | Win rate |
|---|---|---|
| '1' (FALSE) | 14,125 | 0.3367 |
| '2' (TRUE) | 4,411 | 0.3115 |
| '0' (UNKNOWN) | 0 | — |

**A BOS flag TRUE slightly *reduces* the baseline win rate** (-2.5pp). The raw
flag is at best neutral-to-slightly-negative in this dataset — the edge in the
rules comes from the *conjunctions* (7.1), not from BOS presence per se.
Over decided+signal rows the same pattern holds: hasBOS=FALSE 0.3393 (n=12,662)
vs hasBOS=TRUE 0.3115 (n=4,411).

## 7.3 Interaction table (decided+signal rows)

**hasBOS x trendAligned:**

| hasBOS | trendAligned | n | Win rate |
|---|---|---|---|
| FALSE | FALSE | 9,010 | 0.3343 |
| FALSE | TRUE | 3,652 | 0.3516 |
| TRUE | FALSE | 3,768 | 0.3140 |
| TRUE | TRUE | 643 | 0.2970 |

- The best cell is BOS absent + trend-aligned (0.3516); the worst is BOS
  present + trend-aligned (0.2970). **When a BOS event is present AND the
  decision is trend-aligned, win rate drops by ~5.5pp vs the baseline.**
  Interpretation for the confidence model: `trendAligned` gains its value in
  the *no-BOS* context; in the BOS-present context it adds nothing (the BOS
  already implies structural alignment) and may mark late-stage entries.

**hasBOS x hasLiquiditySweep:**

| hasBOS | sweep | n | Win rate |
|---|---|---|---|
| FALSE | FALSE | 12,662 | 0.3393 |
| TRUE | FALSE | 3,553 | 0.2967 |
| TRUE | TRUE | 858 | 0.3730 |

- **BOS + sweep together is the best BOS cell (0.3730)** — a sweep that
  resolves into a structural break in the opposite direction is the strongest
  BOS-context combination, consistent with the ICT liquidity-sweep-then-BOS
  narrative and with the LIQUIDITY_BOS rule family being *sweep-first* rules.
  Note the ordering: BOS present + no sweep = 0.2967; BOS + sweep = 0.3730
  (+7.6pp).

**BOS-rule stats by trendAligned:**

| Rule | trendAligned | n | Win rate |
|---|---|---|---|
| BOS_OB_BULLISH | FALSE | 310 | 0.3677 |
| BOS_OB_BULLISH | TRUE | 130 | 0.3769 |
| BOS_OB_BEARISH | FALSE | 280 | 0.3821 |
| BOS_OB_BEARISH | TRUE | 138 | 0.3623 |
| LIQUIDITY_BOS_BULLISH | FALSE | 1,686 | 0.2924 |
| LIQUIDITY_BOS_BULLISH | TRUE | 167 | 0.1796 |
| LIQUIDITY_BOS_BEARISH | FALSE | 1,492 | 0.3143 |
| LIQUIDITY_BOS_BEARISH | TRUE | 208 | 0.2981 |

- **LIQUIDITY_BOS_BULLISH trend-aligned collapses to 0.1796** (n=167) vs
  0.2924 not-aligned — an 11.3pp negative swing. The `trendAligned` gate, for
  this rule family, is counter-productive (aligned = worse). For BOS_OB rules
  the trend flag is near-neutral (bullish slightly positive, bearish slightly
  negative). This asymmetry is a candidate confidence-model input for 18.8.

**BOS-rule evidence composition:** every BOS-family decision row carries exactly
two evidence IDs (`ruleEvidenceCount=2`), formatted as `(pivotId, evidenceId)`
pairs (e.g., `458,148`): the BOS pivot id and the paired evidence (order block
id for BOS_OB, liquidity sweep id for LIQUIDITY_BOS). No BOS rule ever fired
with a single evidence item, confirming BOS is never used alone in the rule
layer.

## 7.4 What the dataset cannot measure (explicit)

1. **Break quality**: displacement size, close-vs-level distance, break-bar
   range, acceptance/hold — none are in the schema (only the `hasBOS` boolean).
   The practitioner filter recommendations (Phase 3) cannot be validated from
   the frozen dataset; they require new telemetry (E1, E2).
2. **BOS vs CHOCH labeling**: the dataset has `hasBOS` and `hasCHOCH` flags,
   but no record of *which* pivot was broken or whether the break was with or
   against the trend at event time — the exact semantics the review flagged in
   6.3. The `trendAligned` column is a decision-time snapshot, not an
   event-time label.
3. **BOS age/relevance**: distance (bars) between the BOS event and the
   decision row is not recorded.
4. **Counter-trend BOS frequency**: how many `hasBOS=TRUE` rows were actually
   counter-trend breaks (mislabeled "BOS") is unknowable from the CSV.
5. **Event-rate baselines**: the number of BOS events per run (vs decisions)
   is not derivable — BOS events are in-memory only.

---

# Phase 8 - Experiment backlog (no implementation)

Format: Evidence Strength I-V (see program overview), Confidence A-F
(Sprint 19 implements A and B only), Priority P1-P3.

## E1 - BOS displacement / significance filter (ATR-scaled)

- **Literature**: displacement and volatility filters are the strongest
  practitioner consensus for separating true BOS from noise (3.2, 3.3; 0.5xATR
  rule from forexexperts; volume 150% rule from PriceActionNinja/CFA).
- **Implementation survey**: rare in open source; MQL5 Sentinel article calls
  false-signal filtering the main challenge (5.2).
- **SuperCents_X**: no filter exists today (6.5.2); `hasBOS` measured
  slightly-negative alone (7.2) — the filter is the test of whether break
  *quality* carries the edge that raw presence lacks.
- **Sprint 17 evidence**: cannot measure (7.4.1) — requires new telemetry.
- **Experiment**: add `bosDisplacement` (close-vs-level in ATR units) and
  `bosBarRange` to the v3 schema; evaluate win-rate vs displacement quantiles
  in a new data collection; if monotone, gate BOS evidence on
  displacement >= k (calibrated offline).
- **Evidence Strength**: II (multiple independent practitioner sources + one
  industry statistic).
- **Confidence**: **B** — implement in Sprint 19 (telemetry first, gating
  after measurement). Priority: **P1**.

## E2 - Post-break acceptance / retest telemetry

- **Literature**: acceptance (price holds) and retest-role-reversal are
  consensus confirmation steps (strike.money "price should hold";
  PriceActionNinja follow-through + no immediate reversal; Edwards & Magee).
- **SuperCents_X**: no hold/retest check (6.5.2).
- **Experiment**: telemetry columns `barsToRetest`, `retestHeld` (broken level
  retested from other side and held N bars) evaluated against outcome.
- **Evidence Strength**: III (strong practitioner consensus, no direct FX
  academic test).
- **Confidence**: **C** (measure first; rule change depends on E1 result).
  Priority: **P2**.

## E3 - Trend-context gating on BOS evidence (BOS vs CHOCH labeling)

- **Literature**: the direction test is the defining property of BOS (ICT;
  Dow); 7.3 shows `trendAligned` interacts negatively with BOS presence —
  the current implicit labeling may be firing at the wrong time.
- **SuperCents_X**: BOSDetector has no direction test (6.5.1); TrendState
  flips on a single opposing break (6.3) — CHOCH/MSS collapsed into one step.
- **Sprint 17 evidence**: measured negative interaction (BOS+trendAligned
  0.2970 vs baseline 0.3367; LIQUIDITY_BOS_BULLISH aligned 0.1796) — the
  strongest measured hook in this document.
- **Experiment**: relabel events at the detector boundary — emit BOS only
  when the break agrees with the protected trend state; emit CHOCH
  separately; require a second opposing-structure break before trend flip
  (18.1 E6). Measure win rates before/after in fresh data.
- **Evidence Strength**: II (ICT definitional consensus + measured negative
  interaction in this dataset).
- **Confidence**: **A** — the direction test is definitionally correct and
  cheap; implement in Sprint 19 (as a detector-level label + telemetry,
  with the rule-layer decision to follow measurement). Priority: **P1**.

## E4 - BOS lifecycle telemetry (event chain into schema v4)

- **Literature**: none required — measurement prerequisite for E1/E2/E3
  (7.4.1, 7.4.2).
- **SuperCents_X**: BOS events are in-memory only (6.2); the schema carries
  only `hasBOS` (6.5.4).
- **Experiment**: extend the v3 schema (v4 candidate): per decision row,
  record brokenPivotID, event bar offset, close-vs-level distance,
  displacement ATR, break direction vs trend at event time.
- **Evidence Strength**: n/a (instrumentation).
- **Confidence**: **B** — required before any quality-based gating can be
  calibrated. Priority: **P1** (with E1).

## E5 - Multi-level BOS reference (STH/ITH/LTH hierarchy)

- **Literature**: ICT three-tier (3.1); open-source gap (5.2.5); 18.1 E3
  (multi-timeframe alignment) is the related experiment.
- **Experiment**: expose the structural hierarchy — BOS against ITH/LTH vs
  STH-only — and measure whether higher-tier BOS carries higher win rate.
- **Evidence Strength**: III (practitioner hierarchy, no academic test).
- **Confidence**: **C** — structural, expensive; defer until E4 telemetry
  shows a measurable tier effect. Priority: **P2**.

## E6 - Volume confirmation on BOS (order-flow proxy)

- **Literature**: volume filters are universal in breakout schools
  (PriceActionNinja 150% rule; Edwards & Magee; Wyckoff SOS), but the
  intraday-FX volume proxy is unreliable (tick volume) — Evidence Strength IV.
- **Experiment**: telemetry of break-bar tick-volume vs 20-bar average, only
  if tick-volume is shown informative in 18.4 (liquidity sprint) first.
- **Evidence Strength**: IV.
- **Confidence**: **D** — not implemented; revisit after 18.4/18.12.
  Priority: **P3**.

## Backlog summary (18.2 contributions)

| Exp | Title | Evidence | Confidence | Priority |
|---|---|---|---|---|
| E1 | ATR displacement filter on BOS | II | B | P1 |
| E2 | Post-break acceptance/retest telemetry | III | C | P2 |
| E3 | Trend-context gating (BOS vs CHOCH) at detector | II | A | P1 |
| E4 | BOS lifecycle telemetry (schema v4) | n/a | B | P1 |
| E5 | STH/ITH/LTH multi-level BOS reference | III | C | P2 |
| E6 | Volume confirmation | IV | D | P3 |

---

## References (consolidated)

1. Brock, W., Lakonishok, J., LeBaron, B. (1992). "Simple Technical Trading
   Rules and the Stochastic Properties of Stock Returns." Journal of Finance
   47(5):1731-1764.
2. Sullivan, R., Timmermann, A., White, H. (1999). "Data-Snooping, Technical
   Trading Rule Performance, and the Bootstrap." Journal of Finance
   54(5):1647-1691.
3. Curcio, R., Goodhart, C. (1993). "When Support/Resistance Levels are
   Broken, Can Profits be Made? Evidence from the Foreign Exchange Market."
4. Osler, C. L. (2000). "Support for Resistance: Technical Analysis and
   Intraday Exchange Rates." FRBNY Economic Policy Review 6(2):53-68.
5. Andreou, E., Ghysels, E. (2009). "Structural Breaks in Financial Time
   Series." Handbook of Financial Time Series, Springer, 839-870.
6. Aue, A., Kirch, C. (2024). "The state of cumulative sum sequential
   changepoint testing 70 years after Page." Biometrika 111(2):367-391.
7. Killick, R., Fearnhead, P., Eckley, I. (2012). "Optimal Detection of
   Changepoints With a Linear Computational Cost." JASA 107(500):1590-1598.
8. Adams, R., MacKay, D. (2007). "Bayesian Online Changepoint Detection."
9. Lo, A., Mamaysky, H., Wang, J. (2000). "Foundations of Technical
   Analysis." Journal of Finance 55(4):1705-1765.
10. Edwards, R., Magee, J. (1948). Technical Analysis of Stock Trends.
11. Wyckoff, R. (1930s). Studies in Tape Reading / stock market schematics
    literature.
12. Hamilton, W. P. (1922). The Stock Market Barometer. Rhea, R. (1932). The
    Dow Theory.
13. Donchian, R. (1960s). "4-week rule" / channel breakout systems.
14. Dennis, R., Eckhardt, W. (1983). Turtle Trading Rules (public record:
    Curtis Faith, Way of the Turtle, 2007).
15. Brooks, A. (2009-2012). Price Action trading trilogy.
16. Fuller, N. (2008- ). Price Action trading materials (false breakout
    strategy).
17. ICT / Inner Circle Trader materials; ictkillzone.com (2026) BOS/CHOCH
    guides; smartmoneytrader.co (2025); tradexis.ai.
18. strike.money (2026). "Break of Structure (BOS): Meaning, 5 Types...".
19. PriceActionNinja (2026). "False Breakout Strategy for Forex: Stop Hunts
    & Liquidity Traps."
20. forexexperts.com (2025). "Breakouts, False Breaks & Filter Rules."
21. abovethegreenline.com (2025). "False Breakouts in Trading."
22. tradevae.com. "False Breakouts Explained: Structure, Logic, and Risk
    Management."
23. SrsBlack/ict-knowledge-library (GitHub). Formal ICT concept definitions.
24. VelmoPk/Smart-Money-Concepts-indicator-MT5; haza79/MT5-Smart-Money-
    Concept-Indicator; LesleyJJ/SMCIndicator-public; RichyMunalula/SMC
    indicators (GitHub).
25. MQL5 article 22249 (2026). "Building the Market Structure Sentinel
    Indicator in MQL5."
26. MQL5 article 22526 (2026). "Integrating AI into 3 Smart Money Concepts
    (SMC): OB, BOS, and FVG."
27. SpendDock (2026). "Smart Money Concepts (ICT) Trading Strategy: Complete
    Guide with Code."
28. Lumley, W. (2025). "Donchian Channel Explained"; theturtletrader.com
    (2026); takeprofitapp.com (2026) Turtle Trading System guides.
29. Alpha Suite (2026). "Support and Resistance: Do They Actually Work?"
    (survey of the BLL1992 / STW1999 / Osler / Lo-Mamaysky-Wang literature).
30. SuperCents_X: Structure/BOSDetector.mqh, Structure/TrendState.mqh,
    Structure/StructuralPivotEngine.mqh, Utils/Types.mqh (BOSEvent),
    Telemetry/TelemetryTypes.mqh (v3 schema, tristate semantics).
31. Evidence/Sprint17/merged/*.csv (frozen dataset; 18,686 rows; fingerprint
    `2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`).
