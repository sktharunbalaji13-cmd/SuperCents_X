# Sprint 18.3 - Change of Character (CHOCH) & Market Structure Shift (MSS): Deep Research Review

Status: **complete** (research-only; no production changes)

Program: `docs/Sprint18_Research/00_Program_Overview.md`
Dataset: `Evidence/Sprint17/` frozen, fingerprint `2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90` (18,686 rows)
Method: 8-phase per the locked methodology. Phases 1-5 are literature/industry
survey (no SuperCents_X discussion). Phase 6 is the read-only code review.
Phase 7 is measured evidence only. Phase 8 is the experiment backlog.

---

# Phase 1 - Foundation

## 1.1 What a Change of Character is

A **Change of Character (CHOCH)** is the *first* break of a swing point
**against** the prevailing trend. In an uptrend (higher highs / higher lows),
the higher lows hold the trend in place; when price closes below the most
recent higher low, the character of the market has changed. In a downtrend,
the lower highs hold the bearish structure; a close above the most recent
lower high is the bullish CHOCH.

Three properties are definitional:

1. **It is a counter-trend break.** The same physical price action — a close
   beyond a swing level — is a BOS when it extends the trend and a CHOCH when
   it violates the trend. Direction relative to the trend is the only test
   (this is the mirror of 18.2 Phase 1).
2. **It is an internal event, not yet a confirmed reversal.** The CHOCH breaks
   the *last line of defense* of the trend (the HL in an uptrend, the LH in a
   downtrend) but does not prove the new direction. It is a **warning**:
   "stop looking for continuation trades in the old direction."
3. **It is the first stage of a two-stage reversal sequence.** CHOCH (first
   counter-trend break = warning) → **MSS** (confirmed structural change in
   the new direction = confirmation). Terminology varies by school (see 1.2),
   but the two-stage logic is universal.

**Market Structure Shift (MSS)** is the stronger second-stage event. The two
dominant definitions in the ICT ecosystem:

- **Definition A (ictkillzone / fairvaluehub / smartinggoods):** MSS = the
  *confirmed* version of the CHOCH — after the CHOCH, price breaks the next
  relevant level *in the new direction* (creates a higher high after the
  bullish CHOCH). CHOCH = warning; MSS = confirmation.
- **Definition B (backtrex / innercircletrader.net):** MSS = the counter-trend
  break itself when it is *decisive* — a displacement candle that breaks a
  major swing, ideally after a **preceding liquidity sweep** (institutions
  absorbed available liquidity before reversing). MSS = early reversal signal
  ("yes, we are reversing"); CHOCH = softer internal warning ("are we
  reversing?").

Under both definitions the practical sequence is the same: a warning break
against the trend, then a confirmation break with the new trend — and the
tradeable entry belongs *after* the confirmation (often at the retest /
CISD — see 3.1), not at the first warning.

## 1.2 Origin and historical evolution

- **Dow Theory (1890s-1902; Hamilton 1922; Rhea 1932)**: the reversal
  confirmation doctrine. "The primary trend is in effect until it gives
  definite signals that it has reversed" — the definite signal being a
  secondary reaction that breaks the previous reaction extreme. This is the
  two-stage CHOCH→MSS logic in 19th-century dress: a penetration of the
  last secondary low/high is the *warning*, and the subsequent failure of the
  old trend to resume (price breaking a new extreme in the new direction) is
  the *confirmation*.
- **Wyckoff (1930s)**: distribution schematics — the market ends an uptrend
  with an Upthrust (UT) beyond the rally peak that fails to hold; the
  Breaking of the Lower Support (Spring failure) or the decline through the
  LPS is the "first break against character". The whole accumulation/
  distribution vocabulary is a CHOCH/MSS sequence told with volume.
- **Edwards & Magee (1948)**: "failed breakout" — a breakout that reverses is
  the highest-probability reversal signal. The failed breakout *is* a CHOCH
  when it happens against the trend: e.g., a failed upside breakout in an
  uptrend that closes back below the level and then takes out the last higher
  low.
- **Al Brooks (2009-2012)**: "failed breakouts are the strongest reversal
  signals" — the failed breakout of a swing high is a high-probability short;
  the trend is "in transition" (a two-legged sequence of failed breakouts
  before the new trend asserts). Brooks' "barbed wire"/ranging transitions
  map to the CHOCH-then-MSS gap.
- **ICT / SMC (2000s- )**: the modern vocabulary — CHOCH/MSS/BOS as a
  classified triplet; CISD (Change in State of Delivery) as the final
  confirmation layer (smartmoneytrader 2025); displacement candles as the
  distinguishing feature of MSS (vs plain CHOCH); the liquidity-sweep
  prerequisite for the strongest MSS (backtrex).
- **Quantitative era (2000s- )**: the underlying phenomenon is *regime/turning
  point detection*: CUSUM turning-point methods (Blondell et al. 2002),
  change point detection (PELT, BOCPD — 18.2 Phase 2), market-profile +
  deep-learning reversal identification (Ju & Chen 2022), and
  momentum-with-regime-detection hybrids (Wood et al. 2021, "Slow Momentum
  with Fast Reversion").

## 1.3 Mathematical formulation

Given a trend label \(T \in \{\text{BULL}, \text{BEAR}\}\) and the protected
swing points of the trend (the higher low \(L^*\) in an uptrend, the lower
high \(H^*\) in a downtrend):

**Bearish CHOCH** at bar \(t\) (uptrend violated):
\[
T = \text{BULL} \quad\wedge\quad \text{Close}_t < L^*
\]
**Bullish CHOCH** at bar \(t\) (downtrend violated):
\[
T = \text{BEAR} \quad\wedge\quad \text{Close}_t > H^*
\]

**MSS (Definition A — confirmation):** a subsequent break in the new
direction: after the bullish CHOCH, price breaks above the prior lower high
sequence's next level, i.e. the first bullish BOS after the CHOCH:
\[
T' = \text{BULL} \quad\wedge\quad \text{Close}_{t+k} > \max(H^*_{\text{prior leg}})
\]

**MSS (Definition B — decisive displacement):** the counter-trend break
itself, conditional on displacement:
\[
T = \text{BULL} \quad\wedge\quad \text{Close}_t < L^* \quad\wedge\quad
\text{Displacement}_t \geq d \quad\wedge\quad (\text{Sweep of } L^* \text{ in last } w \text{ bars})
\]
where \(\text{Displacement}_t\) is a break-bar strength measure (body size vs
ATR) and the sweep clause records whether liquidity was taken just beyond
\(L^*\) immediately before the reversal — the institutional signature.

Design dimensions:

| Dimension | Options | Notes |
|---|---|---|
| Reference level | most recent HL (uptrend) / LH (downtrend) — always the counter-trend structure | internal structure vs major swing distinguishes CHoCH from MSS in Definition A |
| Trigger | close vs body close vs wick | ICT: body close; some implementations (TradingFinder) accept wicks for CHOCH — a documented minority disagreement |
| Displacement filter | none / k×ATR body / consecutive strong candles | separates MSS (decisive) from CHoCH (soft) in Definition B |
| Sweep prerequisite | none / sweep-before-break within w bars | backtrex: mandatory for valid MSS |
| Confirmation stage | none / first BOS in new direction | Definition A's MSS = confirmation beat |
| Re-trigger policy | one-shot per protected point | universal (each PP fires once) |
| Guard time | min age of the protected point before it can be broken | prevents "instant CHOCH" on freshly formed pivots |

## 1.4 Why CHOCH/MSS exist / why it matters

- **Reversals are where the majority of retail losses happen** (counter-trend
  entries, "picking bottoms/tops" — Fuller's false-breakout doctrine, 18.2
  Phase 3). The CHOCH is the objective, rule-based marker of "the old trend
  is no longer to be trusted".
- **The two-stage design exists because single breaks fail.** A first
  counter-trend break frequently resolves back into the old trend (the MSS
  "stop-hunt trap" of innercircletrader.net; "trading CHOCH alone has a high
  failure rate" — smartmoneytrader). Waiting for the confirmation stage
  filters exactly those traps — at the cost of entering later (worse R:R).
- **MSS/changepoint logic is the discrete analog of regime detection.** The
  institutional/quant view (Phase 2, 4) frames the same phenomenon as a
  regime change in the data-generating process; CHOCH→MSS is the retail-
  readable, non-repainting approximation of that inference, with the same
  latency trade-off (BOCPD lags; MSS confirms late by design).
- **It is the event that legitimizes the new direction.** In SuperCents_X and
  every SMC framework, entries in the new trend are only taken *after* the
  shift is confirmed — CHOCH/MSS is the gate between "old trend" and "new
  trend" trade regimes.

---

# Phase 2 - Academic literature

## 2.1 Turning point detection (the academic formulation)

The academic literature studies "the trend is ending" under **turning point /
structural break** names, not "CHOCH":

- **Blondell, Hoang, Powell & Shi (2002), "Detection of financial time series
  turning points: a new CUSUM approach applied to IPO cycles", Review of
  Quantitative Finance and Accounting 18(3):293-315.** A CUSUM procedure
  designed for cyclical mean-level *and* volatility regime shifts, applied to
  detect "hot issue" turning points in IPO markets. Demonstrates that
  sequential (online) turning-point detection is feasible and meaningful in
  financial data — the statistical ancestor of an online MSS detector.
- **Aue & Kirch (2024), Biometrika 111(2):367-391** (from 18.2): the modern
  survey of sequential CUSUM — the formal treatment of "when has the process
  changed?" with bounded detection delay. The academic answer to "when is a
  break real?" is a likelihood-ratio/statistic test with controlled error
  rates — something the discretionary CHOCH/MSS never formalizes, and a
  candidate statistical validation layer for 18.13.
- **Andreou & Ghysels (2009)** (from 18.2): structural breaks alter the
  data-generating process; models that ignore them mis-estimate risk. Same
  message in the reversal context: after a regime change, old-trend signal
  distributions no longer apply.

## 2.2 Reversal identification with price structure (ML)

- **Ju & Chen (2022), "Identifying Financial Market Trend Reversal Behavior
  With Structures of Price Activities Based on Deep Learning Methods", IEEE
  Access 10:12854-12877.** Converts market-profile data (POC, value area,
  tails — Steidlmayer) into structure images and trains CNNs (vs LSTM
  baselines) to classify trend-reversal behavior; market-profile structure
  indicators showed better trend-predicting ability in long-term horizons,
  and combining short- and long-term structure changes improved forecasting.
  Relevance: **price structure itself (not just returns) carries reversal
  signal** — the academic support for structure-based reversal events over
  raw momentum.
- **Wood, Roberts & Zohren (2021), "Slow Momentum with Fast Reversion: A
  Trading Strategy Using Deep Learning and Changepoint Detection"**
  (Journal of Financial Data Science 4(1):111-129; GitHub
  slow-momentum-fast-reversion). A quant strategy that uses **change point
  detection to detect regime transitions** and switches between momentum and
  reversion behavior accordingly. Relevance: the institutional pattern of
  *regime-detect-then-switch* — exactly the CHOCH→MSS→new-trend-trades
  sequence, formalized.

## 2.3 Reversal/momentum evidence (context)

- **Brock, Lakonishok & LeBaron (1992)** (from 18.2): buy signals (trend-
  continuation breaks) showed *less* post-signal volatility than sell
  signals — asymmetry consistent with the practitioner claim that reversal
  breaks are noisier than continuation breaks (which is why CHOCH needs a
  confirmation stage).
- **Short-term reversal literature (Jegadeesh 1990; monthly horizon)** and
  **long-horizon reversal (De Bondt & Thaler 1985)**: reversal predictability
  exists but is weak at intraday horizons and fragile to transaction costs.
  No strong academic support for *immediate* reversal entries on a single
  structure break in intraday FX — consistent with the professional
  consensus "do not trade the CHOCH alone".

## 2.4 Academic consensus, disagreements, open questions

**Consensus:**
1. Regime/turning-point detection is statistically well-founded (CUSUM
   lineage 1960s-2024) and relevant to financial data (Blondell et al. 2002;
   Andreou & Ghysels 2009).
2. Price *structure* carries reversal information beyond raw returns
   (Ju & Chen 2022; Lo, Mamaysky & Wang 2000 pattern literature).
3. Regime-change detection inherently lags the true break (BOCPD latency;
   CUSUM power trade-offs) — the "confirmed late" cost is unavoidable in any
   detector, discrete or continuous.

**Disagreements / open questions:**
1. **What exactly is "confirmation"?** The academic formulation (a test
   statistic crossing a threshold) has no analogue in the retail
   CHOCH/MSS rules; the practitioner two-stage sequence is untested
   academically on intraday FX. Open for the program's own measurement
   (Phase 7; 18.13).
2. Whether the second-stage confirmation (Definition A) adds value over the
   first break (Definition B) is asserted by practitioners, not measured.
3. Displacement and sweep filters are practitioner folklore; no controlled
   academic test on FX data (mirror of 18.2's open question 3).

---

# Phase 3 - Professional trading literature

## 3.1 The ICT framework (CHOCH / MSS / CISD)

- **CHOCH is the first internal break against the trend** (smartmoneytrader
  2025): in a downtrend it is the close above the most recent lower high; in
  an uptrend the close below the most recent higher low. It is "the first
  internal structure shift... the earliest warning that a reversal could be
  developing".
- **CHOCH alone has a high failure rate** (smartmoneytrader 2025): "price
  frequently breaks a minor high or low (CHoCH), then continues in the
  original trend direction anyway." It is a *watch* signal, not an entry.
- **CISD (Change in State of Delivery)** (smartmoneytrader 2025): the
  progression is BOS confirms trend → CHoCH warns of reversal → MSS confirms
  structural shift → **CISD confirms delivery** (LTF structural level broken
  post-displacement). "The entry belongs at the CISD, not before." This is
  the most advanced statement of the confirmation chain; each step adds
  evidence and reduces entry count.
- **MSS definitions in the wild** (documented, conflicting):
  - ictkillzone.com (2026): "An MSS is the confirmed version of a CHOCH" —
    Definition A; CHOCH breaks the opposing structure, MSS is the
    confirmation beat that breaks the next level in the new direction.
  - backtrex.com: MSS requires a **preceding liquidity sweep** — "An MSS
    without a preceding sweep is not a valid MSS in ICT methodology" —
    Definition B with the sweep prerequisite.
  - innercircletrader.net (2026): MSS = "the moment when price, after
    sweeping liquidity on a key level, closes with a significant candle body
    beyond the dominant market structure"; MSS is *earlier* than CHOCH
    ("MSS is faster and earlier than CHoCH"), reversing the ictkillzone
    ordering. Also: "MSS can happen and resolve back into the prior trend
    without ever producing a CHOCH — that is exactly when MSS becomes a
    stop-hunt trap."
  - **The ecosystem does not agree on the exact CHOCH/MSS relationship.**
    The program must therefore treat "CHOCH" as: first counter-trend break of
    the protected structure (universal), and "MSS" as: the decisive/
    confirmed second stage (definition varies). SuperCents_X's own naming
    (see Phase 6) uses neither variant — it uses a single CHOCH event and a
    binary trend flip; the document will flag this explicitly.
- **Displacement**: MSS-quality breaks are displacement candles (large body,
  minimal wick, leaves an FVG); a slow grind is noise, not a shift
  (ictkillzone; innercircletrader).
- **Body-close rule**: the strongest MSS is a *body close* beyond the swing
  (innercircletrader Q&A: "a simple 3-bar fractal is enough to mark a swing,
  but for it to qualify as a valid MSS trigger, I look for a body close
  beyond that swing rather than just a wick poke").
- **MTF rule**: CHOCH sets the HTF bias (daily/4H); MSS is the LTF trigger
  (5m/15m) inside the bias-aligned zone (innercircletrader; ictkillzone:
  "when only the LTF shows the structure you want, skip the trade").
- **Stop placement**: beyond the swept extreme (below the sweep low for
  bullish MSS entries) with a small buffer (innercircletrader; fintorro:
  never inside the retest zone).

## 3.2 The broader reversal schools

- **Wyckoff**: the Upthrust (UT) after a rally fails; the decline through the
  last point of support. Distribution schematics condition the reversal on
  volume (no volume = no real distribution).
- **Edwards & Magee (1948)**: failed-breakout reversal doctrine — the
  reversal *is* the failed breakout of the last line of defense; the
  subsequent trend is traded only after the "line" is decisively lost
  (equivalent to Definition A confirmation).
- **Al Brooks**: failed breakouts are the strongest signals; transitions are
  typically two-legged; "trend in transition" (choppy) conditions are when
  most reversal trades lose — do not force reversals in transitions.
- **Fuller (Price Action)**: the false breakout *against* the dominant trend
  is the best resumption signal; the false breakout *at* a top/bottom is the
  reversal start. Never knowable in advance — hence confirmation.
- **fintorro (2026)**: beginner synthesis — CHoCH is stronger with liquidity
  sweeps, displacement, and order blocks; "beginners fail by entering
  immediately instead of waiting for a retest"; HTF bias filters weak CHoCH
  setups; CHoCH "as of 2026-02-13 definitions vary — confirm your own rules".

## 3.3 Cross-school synthesis: best practices and common mistakes

**Best practices:**
1. Two-stage design: never trade the first counter-trend break alone
   (universal); require confirmation (MSS/CISD/failed-again) before entering
   the new direction.
2. Displacement/body-close for the decisive break (ICT, innercircletrader,
   smartmoneytrader).
3. Sweep-before-break as the quality filter for the strongest MSS (backtrex,
   innercircletrader — the "institutional signature").
4. HTF bias + LTF trigger (bias from CHOCH-stage events; entry from
   MSS/CISD-stage events).
5. Stop beyond the swept extreme, not inside the retest zone.
6. One-shot per protected level; guard time on freshly formed pivots.

**Common mistakes:**
1. Trading the CHOCH alone ("high failure rate" — smartmoneytrader).
2. Confusing BOS with CHOCH (both are breaks; direction decides).
3. Wick-based CHOCH/MSS (minority implementations accept it — TradingFinder;
   ICT majority requires close/body).
4. Ignoring the sweep prerequisite (MSS without sweep is a weaker signal).
5. Entering immediately instead of waiting for the retest.
6. No HTF bias filter (LTF-only reversal entries).

---

# Phase 4 - Institutional / quantitative methods

## 4.1 Regime detection and reversal switching (quant practice)

- **Changepoint-driven regime switching**: Wood et al. (2021) "Slow Momentum
  with Fast Reversion" — use change point detection to switch between
  momentum and mean-reversion allocations. This is the institutional
  equivalent of "CHOCH → stop old-trend trades; MSS → trade new-trend
  entries": a *detector of regime change* gates the strategy family.
- **CUSUM/EWMA monitoring in risk systems**: banks and risk departments use
  sequential monitoring (Shewhart/EWMA/CUSUM; Aue & Kirch 2024 survey) to
  detect parameter instability in VaR/market-risk models — the practical
  acknowledgement that "the current regime's parameters are stale" is a
  first-class risk signal. Same content as CHOCH, formalized.
- **Market profile / structure-based reversal research** (Ju & Chen 2022):
  structure images (POC/VA/tails) beat raw-price baselines for reversal
  classification — institutional research that validates the *structure-based*
  (not indicator-based) approach to reversal events that SMC frameworks use.

## 4.2 Displacement and sweep as institutional signatures

- The "displacement = institutional aggression" concept (large-bodied
  candles, FVG creation) is the practitioner's proxy for order-flow
  imbalance (institutional participation), analogous to the quant's volume-
  imbalance or order-flow surprise measures.
- The sweep-before-MSS requirement is the microstructure argument: institutions
  *need* liquidity to reverse large positions; the sweep (stops just beyond
  the level) is the liquidity source; the MSS follows once the sweep is
  absorbed (backtrex; innercircletrader). This is consistent with Osler
  (2000) — stop clusters just beyond levels are the fuel for exactly these
  moves (18.2 Phase 2).

## 4.3 Systematic reversal strategy evidence (industry backtests)

- MSS-based strategies backtested across 64 futures symbols
  (pinescriptforge 2026): win rates 39.8%-51.0% (NQ 45.3%, ES 42.1% with PF
  1.44 and Sharpe 1.74, RTY 51.0%, CL 50.7% PF 2.36) — reversal-shift
  strategies as standalone systems show *modestly positive* expectancy on
  equity-index and commodity futures with 1-3R targets. Evidence Strength IV
  (industry, not peer-reviewed), but notable: a structure-shift system with
  ~45% win rate at 1-3R is consistent with the BOS/CHOCH asymmetry view —
  reversals trade less often and need bigger R:R than continuations.

---

# Phase 5 - Open-source implementations

## 5.1 Survey of implementations by family

| Implementation | Language | CHOCH/MSS logic | Notable engineering |
|---|---|---|---|
| TradingView "MSS" by Xcelerate Trade team | Pine v6 | Trend state (Bullish/Bearish/Neutral); every confirmed break classified: **CHoCH = first break that reverses the trend (flips trend, starts fresh leg)**; **MSS = first qualifying break in the new direction after CHoCH**; then BOS | the most rigorous public MSS formalization; break validation modes: Close / High-Low wick / Close-beyond-buffer (ticks or %) — parameterized strictness; MSS definition modes: "First break after CHoCH" vs "First break >= pre-CHoCH level"; Williams vs Simple fractals; wait-for-close option |
| "Market Structures + ZigZag [TradingFinder]" | Pine v5 | CHOCH = break of prior high/low; **their variant: wick sufficient for CHOCH, close required for BOS**; wait for a BOS in the new direction to confirm the trend | documented minority disagreement on wick-vs-close for CHOCH |
| "CHoCH Multi-Timeframe" (TradingView) | Pine | CHOCH labeled with originating timeframe (e.g. "15m CHoCH"); bullish = close above most recent LH in bearish sequence; "not based on a single candle" | MTF CHOCH event timeline — directly relevant to 18.1 E3 / 18.3 E3 |
| "SmartFlow SMC" (TradingView) | Pine | Bullish MSS = close > last fractal swing high; OB defined from the MSS candle; daily reset | MSS as the anchor event for the whole decision chain (OB from MSS) |
| `VelmoPk/Smart-Money-Concepts-indicator-MT5` | MQL5 | BOS/CHOCH detection in real time, no-repaint claim | same family as 18.2 survey |
| MQL5 article 22249 "Market Structure Sentinel" (2026) | MQL5 | BOS + CHOCH detection with mini dashboard incl. **consolidation state** (both arrows) | consolidation display — the missing "ranging" state in binary trend machines |
| `SrsBlack/ict-knowledge-library` | docs | **`choch-bullish` = first close above a swing high after a bearish leg**; `bos-bullish` = close above prior swing high; MSS not separately defined (library uses choch for the reversal event) | formal machine-readable criteria; CHOCH = "first close" formulation |
| `LesleyJJ/SMCIndicator-public` | MQL5 | BoS/ChoCh + signals, MTF, alerts | mature MQL5 suite |

## 5.2 Comparative algorithm findings

1. **The Xcelerate "MSS" script is the reference implementation for the
   confirmation-stage model** (Definition A): trend state flips on the CHoCH
   itself, and MSS = the first new-direction break after the flip. This is
   exactly the semantic SuperCents_X *does not* have: SuperCents_X flips
   trend on the single break (18.1 review) and has no MSS stage — the
   Xcelerate script is the design pattern for 18.3 E1/E2.
2. **Break-validation strictness is a first-class, user-facing parameter**
   (Close / wick / buffer-ticks / buffer-%) — the ecosystem has converged on
   *making the choice explicit* rather than hardcoding it. SuperCents_X
   hardcodes close-based (Phase 6).
3. **Wick-vs-close for CHOCH is a genuine documented disagreement**
   (TradingFinder accepts wicks for CHOCH; ICT majority requires close/body).
   Close-based is the safer, majority choice; SuperCents_X is close-based.
4. **Consolidation/neutral trend state is implemented** (Sentinel article,
   Xcelerate "Neutral") — SuperCents_X has no ranging state (18.1 review;
   E6 backlog). A CHOCH/MSS system without a neutral state must still *have*
   one for the "no trend" context; SuperCents_X handles it as
   TREND_UNKNOWN + trendUnknown reject counter (Phase 6).
5. **MTF CHOCH timelines exist in open source** (CHoCH Multi-Timeframe) —
   evidence the hierarchy is implementable; supports 18.1 E3.
6. **MSS-as-anchor**: SmartFlow builds the entire OB+entry chain from the MSS
   candle — the institutional pattern "shift first, then trade the
   consequences" is the dominant SMC code architecture.

---

# Phase 6 - Current SuperCents_X implementation (facts only)

## 6.1 Architecture (structure layer)

Per 18.1 Phase 6: `CSwingDetector` → `CStructuralPivotEngine` (promote/
replace/lock) → `CProtectedPointManager` (active protected points on trend
change) → `CTrendState` (binary trend machine) → `CCHOCHDetector` (this
review) and `CBOSDetector` (18.2 review). `CCHOCHDetector` consumes
`CTrendState` + `CProtectedPointManager` + `CPPTelemetryCollector` (log-only).

## 6.2 CCHOCHDetector (`Structure/CHOCHDetector.mqh`, 361 lines)

- **Trend-conditional by design** (`:131-136`): if `TREND_UNKNOWN`, the check
  is skipped (`m_stats.trendUnknown`). CHOCH events only exist inside an
  established trend — matching the ICT definition (CHOCH is a break *of* the
  trend's structure; there is no trend, no CHOCH).
- **Reference level — the opposite-type active protected point**: in a
  BULLISH trend, the *active LOW* (the protected higher low) is the
  reference (`:150-181`); in a BEARISH trend, the active HIGH (`:183-215`).
  This is ICT-correct: CHOCH = break of the trend's last line of defense.
- **Break trigger — close-based**: bearish CHOCH when `currentClose <
  activePoint.price` (`:171`); bullish when `currentClose > activePoint.price`
  (`:204`). Same close convention as BOSDetector.
- **Guard time** (`:166-170`, `:199-203`): if `currentBarTime <
  activationTime`, the event is rejected with reason `guard_time`. A
  protected point that was just activated cannot be "broken" instantly —
  prevents immediate CHOCH on fresh pivots.
- **Reject taxonomy** (`CHOCHRejectStats`, `:19-42`): trendUnknown,
  no_active_pp (per direction), guard_time, price_not_broken, duplicate —
  all counted and logged at shutdown. `price_not_broken` counts bars where
  close did not reach the level (the detector's *no-signal* mass).
- **Duplicate prevention — one-shot per protected point** (`:270-282`): each
  PP can produce at most one CHOCH event (bullishDuplicate/bearishDuplicate
  counters).
- **Incremental processing**: only the last closed bar (series bar 1) is
  checked per Update, gated by `m_lastProcessedBar` (`:142-143`, `:217`) —
  O(1) per bar, no full-history rescan (contrast BOSDetector's O(n) scan,
  18.2 §6.2).
- **Event record**: `CHOCHEvent` (id, protectedPointID, bullish, time,
  breakPrice, barIndex=1 fixed at `:178`/`:211`). In-memory only; not in the
  v3 CSV schema (the CSV carries only the derived `hasCHOCH` tristate flag).
- **PP telemetry is log-only**: every acceptance/rejection logs a "PP
  Sample" block with distance (points), PP age (bars), activation time, and
  reason (`:220-262`) — rich diagnostics that never reach the v3 dataset
  (same finding as 18.1 §6.6).

## 6.3 Semantic relationship to BOSDetector and TrendState

- **Complementary design**: BOSDetector (18.2) is trend-agnostic and breaks
  *latest locked* pivots of both types; CHOCHDetector is trend-conditional
  and breaks only the *active opposite-type* PP. In an established uptrend:
  BOSDetector fires bullish BOS (close > locked high) and *also* "bearish
  BOS" (close < locked low) — while CHOCHDetector fires bearish CHOCH for
  the very same close < active low condition. **Code review therefore
  predicts double-labeling: one counter-trend bar could produce both a
  bearish "BOS" event and a bearish CHOCH event.**
- **Measured resolution (Phase 7)**: in the frozen CSV, `hasBOS` and
  `hasCHOCH` are **mutually exclusive** (BOS=TRUE & CHOCH=TRUE → n=0 of
  17,073 signal rows). The double-labeling does *not* appear in the
  telemetry — so the exclusivity is enforced somewhere outside both
  detectors (decision or telemetry layer), and the mechanism is not
  documented in the code under review. **Open question to resolve in
  Sprint 19 instrumenting (Phase 8 E3).**
- **No MSS concept**: there is no MSS/CISD stage anywhere in the structure
  layer. The two-stage reversal sequence is collapsed: CHOCH event fires →
  TrendState flips on the same single break (18.1 review:
  `TrendState.mqh:85-144`). The detector never emits "MSS" and the engine
  never waits for a confirmation break.
- **No displacement filter**: any close beyond the active PP (after guard
  time) is a CHOCH — no body-size/ATR requirement, no sweep prerequisite
  (both required by Definition B practitioners, Phase 3).
- **No neutral/consolidation state**: TREND_UNKNOWN only exists before the
  first trend is established; ranging markets force flips via single breaks
  (18.1 E6 backlog).

## 6.4 Strengths (observed, factual)

1. ICT-correct reference semantics (opposite-type protected point).
2. Trend-conditional: CHOCH cannot fire in an unknown trend (definitionally
   correct).
3. Guard time on freshly activated protected points (sweep-protection).
4. One-shot per protected point (no duplicate CHOCH).
5. Incremental O(1)-per-bar processing (efficient).
6. Rich rejection taxonomy and log diagnostics (guard_time,
   price_not_broken, no_active_pp, duplicate).

## 6.5 Weaknesses / simplifications (observed, factual)

1. **No MSS/confirmation stage** — the two-stage reversal design (the
   strongest professional consensus, Phase 3) is absent; the trend flips on
   the first break, which Phase 7 data suggests is premature for this rule
   family (0.297-0.38 ranges are close to base rate; 18.2 E3 / 18.3 E1).
2. **No displacement filter** — MSS-quality and noise breaks are treated
   identically (contradicts ICT displacement doctrine, Phase 3.1).
3. **No sweep prerequisite** — the strongest-MSS filter (backtrex,
   innercircletrader) is unmeasurable in the current schema (hasLiquiditySweep
   is a *decision-row* flag, not a break-time flag).
4. **No wick/body distinction** — close-based only (acceptable: majority
   convention; but body-close is the ICT norm for MSS-strength breaks).
5. **Double-labeling risk with BOSDetector** unresolved at detector level
   (6.3) — resolved invisibly downstream (measured exclusivity, Phase 7).
6. **PP telemetry not in the v3 dataset** — the diagnostic richness
   (PP age, distance) never reaches the CSV (6.2).

---

# Phase 7 - Sprint 17 evidence review (measured only)

Dataset: frozen `Evidence/Sprint17/merged/*.csv`. Tristate: `'1'`=FALSE,
`'2'`=TRUE. Outcome: `'1'`=WIN, `'2'`=LOSS, `'3'`=BE. Read-only scripts;
no production code touched.

## 7.1 hasCHOCH flag (decided+signal rows, n=17,073)

| hasCHOCH | n | Win rate |
|---|---|---|
| '1' (FALSE) | 16,731 | 0.3316 |
| '2' (TRUE) | 342 | 0.3567 |
| '0' (UNKNOWN) | 0 | — |

Over all decided rows (n=18,536): FALSE 0.3302 (n=18,194) vs TRUE 0.3567
(n=342). **A CHOCH flag TRUE is +2.5pp *better* than baseline — the mirror
image of hasBOS (18.2 §7.2: -2.5pp).** The CHOCH event is the only structure
flag whose raw presence helps. Caveat: n=342 is small (2.0% of signal rows).

## 7.2 hasCHOCH x trendAligned (decided+signal)

| hasCHOCH | trendAligned | n | Win rate |
|---|---|---|---|
| FALSE | FALSE | 12,702 | 0.3280 |
| FALSE | TRUE | 4,029 | 0.3430 |
| TRUE | FALSE | 76 | 0.3816 |
| TRUE | TRUE | 266 | 0.3496 |

- CHOCH present + **not** trend-aligned is the best cell (0.3816, n=76) —
  consistent with the reversal nature of the rule (a CHOCH fires *against*
  the old trend, so "not aligned with the decision-time trend snapshot" is
  the expected state for the reversal trade; the aligned subset (n=266,
  0.3496) reflects post-flip alignment). The flag semantics at decision time
  are a snapshot, not an event-time label (18.2 §7.4.2) — interpret with
  care.

## 7.3 hasBOS x hasCHOCH overlap (double-labeling check)

| hasBOS | hasCHOCH | n | Win rate |
|---|---|---|---|
| FALSE | FALSE | 12,320 | 0.3388 |
| FALSE | TRUE | 342 | 0.3567 |
| TRUE | FALSE | 4,411 | 0.3115 |
| TRUE | TRUE | **0** | — |

**Zero overlap.** The two flags never co-occur in the frozen dataset —
resolving the code-review concern (6.3) *as measured*: whatever mechanism
enforces exclusivity, it worked across all 17,073 rows. This also implies
`hasBOS` cannot be the raw BOSDetector output (which breaks both types
unconditionally); the exclusivity filter must live in the telemetry/decision
layer. **The mechanism is undocumented — flagged for Sprint 19
instrumentation (E3).**

## 7.4 CHOCH_OB_REVERSAL rule deep dive (the only CHOCH-family rule)

| Metric | Value |
|---|---|
| n | 342 |
| Win rate | 0.3567 |
| rMultiple mean | (see json) |
| Confidence mean / median | 0.4611 / 0.45 |
| layerStructural | 35 (all rows) |
| hasLiquiditySweep | '1' (FALSE) on ALL 342 rows |
| ruleEvidenceCount | 2 (all rows) |

**By trendAligned:** aligned 0.3496 (n=266) vs not-aligned 0.3816 (n=76).
**By symbol/timeframe:**

| Symbol/TF | n | Win rate |
|---|---|---|
| EURUSD M15 | 229 | 0.3100 |
| EURUSD H1 | 50 | 0.3400 |
| GBPJPY H1 | 63 | **0.5397** |

Observations:
1. **GBPJPY_H1 CHOCH_OB_REVERSAL wins at 0.5397 (n=63)** — the highest
   measured win rate of any rule cell in this program so far (vs 0.3100
   EURUSD M15, 0.3400 EURUSD H1). Sample is small (63), but the magnitude
   (+22pp vs the EURUSD M15 cell) is worth a formal look in 18.13 — a
   plausible symbol/timeframe interaction (volatility/trend behavior of
   GBPJPY H1).
2. **Confidence 0.46 is the lowest rule-family mean measured** — the CHOCH
   rule fires at low confidence relative to other rules, yet achieves the
   best raw win rate. Two readings: (a) confidence miscalibration for this
   rule family (18.8 input); (b) the rule self-selects rare, high-quality
   conditions (n=342 over 6 months is ~1 decision/day across 3 symbols).
3. **No liquidity sweep on any CHOCH row** (hasLiquiditySweep=FALSE
   everywhere) — consistent with the absence of the sweep-prerequisite
   filter (6.5.3); the strongest-MSS condition (sweep-then-break) has *never*
   been observed in the CHOCH rule's decisions. The measured vacuum is a
   direct argument for 18.2 E3/E4-style event-level telemetry before judging
   the sweep filter.
4. layerStructural=35 and evidenceCount=2 for all rows: the rule always
   fires with exactly two evidence items (CHOCH event + order block), never
   more — no confluence stacking within this rule.

## 7.5 What the dataset cannot measure (explicit)

1. **Event-level quality**: displacement size, break-bar body ratio,
   distance beyond the level, PP age at break — absent from the schema
   (only the `hasCHOCH` boolean survives).
2. **The two-stage sequence**: whether a confirmed BOS in the new direction
   followed each CHOCH (MSS stage) is unknowable — the confirmation stage is
   not modeled in code (6.5.1) and not in the CSV.
3. **Sweep-before-break at event time**: `hasLiquiditySweep` is a
   decision-row flag; its temporal relationship to the CHOCH break is not
   recorded.
4. **Which PP was broken**: no protectedPointID in the CSV; the "which HL
   was violated" hierarchy (STH vs ITH vs LTH) is unmeasurable.
5. **CHOCH outcome asymmetry**: win rates are close to base rate for
   EURUSD (0.31-0.34); the rule's edge appears concentrated in GBPJPY_H1 —
   whether that is regime, sample size, or volatility is open.

---

# Phase 8 - Experiment backlog (no implementation)

Format: Evidence Strength I-V; Confidence A-F (Sprint 19 implements A and B
only); Priority P1-P3.

## E1 - MSS confirmation stage (two-stage reversal design)

- **Literature**: the two-stage sequence (warning break → confirmed new-
  direction break) is the strongest professional consensus in this sprint
  (3.1, 3.3): CHOCH alone fails; the entry belongs after MSS/CISD
  (smartmoneytrader, ictkillzone, fairvaluehub). The Xcelerate TradingView
  script (5.1) is the reference implementation pattern.
- **SuperCents_X**: no MSS concept (6.5.1); trend flips on a single break
  (6.3). 18.1 E6 (trend-flip confirmation) is the sibling experiment.
- **Sprint 17 evidence**: cannot measure (7.5.2) — the CSV has no
  confirmation-stage marker. Measurable proxy: none available; requires
  event-level telemetry (E3).
- **Experiment**: add an explicit MSS stage to the structure layer: CHOCH
  event (warning) does NOT flip trend; trend flips only on the first
  new-direction break after a CHOCH (MSS), with displacement filter (E2).
  Evaluate in fresh data vs the current single-flip behavior.
- **Evidence Strength**: II (overwhelming practitioner consensus + phase-7
  measured flatness of single-break behavior for EURUSD cells).
- **Confidence**: **A** — definitionally correct per the dominant framework;
  implement in Sprint 19 with E3 telemetry first (measure before rule-layer
  gating). Priority: **P1**.

## E2 - Displacement filter on CHOCH/MSS breaks

- **Literature**: displacement is the defining property of the decisive
  break (ictkillzone "a slow grind through a swing level is not a BOS —
  it's noise"; innercircletrader body-close requirement; smartmoneytrader
  CISD "post-displacement").
- **SuperCents_X**: no displacement measure anywhere (6.5.2); 18.2 E1 is the
  same filter for BOS — unify as a single `breakDisplacement` telemetry item
  (ATR-scaled body/close distance) used by both detectors.
- **Sprint 17 evidence**: unmeasurable (7.5.1).
- **Experiment**: telemetry `breakDisplacement` + `breakBarBodyRatio`;
  evaluate win-rate vs displacement quantiles; gate CHOCH/MSS evidence on
  the calibrated threshold.
- **Evidence Strength**: III (practitioner consensus, no academic FX test).
- **Confidence**: **B** — telemetry in Sprint 19; gating after measurement
  (same pattern as 18.2 E1). Priority: **P1**.

## E3 - Event-level CHOCH/MSS telemetry + exclusivity mechanism resolution

- **Literature**: none required (instrumentation). The phase-7 finding
  (7.3: zero BOS×CHOCH overlap despite detector-level overlap risk) must be
  made *understandable* before any structural change.
- **SuperCents_X**: detectors may double-label the same counter-trend break
  (6.3); the exclusivity is enforced invisibly downstream (7.3).
- **Experiment**: schema v4 candidate — per decision row: eventType
  (BOS/CHOCH/MSS), brokenProtectedPointId, eventBarOffset, breakDirection,
  breakDisplacement; and a log of the exclusivity decision point. Resolves
  the documented open question and unblocks E1/E2 calibration.
- **Evidence Strength**: n/a (instrumentation).
- **Confidence**: **A** — required prerequisite; implement in Sprint 19.
  Priority: **P1**.

## E4 - GBPJPY_H1 CHOCH differential investigation

- **Literature**: none specific (measured anomaly).
- **Sprint 17 evidence**: CHOCH_OB_REVERSAL on GBPJPY_H1 wins at 0.5397
  (n=63) vs EURUSD_M15 0.3100 (n=229) — 7.4. The largest symbol/TF
  differential measured in this program.
- **Experiment**: expand the evidence collection to more GBPJPY_H1 runs
  (and GBPJPY other TFs) to determine if the edge is real (volatility
  regime), an artifact of small n, or a confidence-calibration effect
  (rule fires at 0.46 confidence; 18.8 review input).
- **Evidence Strength**: II (measured in frozen data; requires confirmation
  in new data).
- **Confidence**: **B** — new data collection is cheap and the finding is
  concrete; implement in Sprint 19 (extended runs). Priority: **P2**.

## E5 - Sweep-prerequisite filter for MSS-strength events

- **Literature**: the sweep-before-shift is the "institutional signature"
  (backtrex; innercircletrader "The most reliable MSS prints AFTER price
  has first swept liquidity"; fintorro).
- **SuperCents_X**: no sweep check at break time (6.5.3); measured: no
  CHOCH decision row ever carried hasLiquiditySweep=TRUE (7.4) — the
  condition is untestable today.
- **Experiment**: after E3 telemetry, condition the MSS-strength label on
  a sweep within w bars before the break; measure the differential.
- **Evidence Strength**: III (practitioner consensus; no academic FX test).
- **Confidence**: **C** — depends on E3; defer gating until telemetry
  exists. Priority: **P2**.

## E6 - Neutral/consolidation trend state for reversal logic

- **Literature**: consolidation states are implemented in open source
  (Sentinel dashboard, Xcelerate Neutral, 5.1) and are central to Brooks'
  "trend vs trading range" context question (18.2 Phase 3).
- **SuperCents_X**: binary trend machine, no ranging state (6.3; 18.1 E6).
- **Experiment**: three-state trend (BULL/BEAR/RANGE via opposing-structure
  failure or channel metrics); CHOCH semantics inside RANGE are
  suppressed/redefined (ICT: CHOCH exists only in trends).
- **Evidence Strength**: II (Brooks + ICT consensus; open-source precedent).
- **Confidence**: **C** — architectural, bundle with 18.1 E6; defer to
  post-E1 measurement. Priority: **P2**.

## Backlog summary (18.3 contributions)

| Exp | Title | Evidence | Confidence | Priority |
|---|---|---|---|---|
| E1 | MSS confirmation stage (two-stage reversal) | II | A | P1 |
| E2 | Displacement filter on CHOCH/MSS (shared with 18.2 E1) | III | B | P1 |
| E3 | Event-level CHOCH/MSS telemetry + exclusivity resolution | n/a | A | P1 |
| E4 | GBPJPY_H1 CHOCH differential investigation | II | B | P2 |
| E5 | Sweep-prerequisite filter for MSS-strength | III | C | P2 |
| E6 | Neutral/consolidation trend state | II | C | P2 |

---

## References (consolidated)

1. Blondell, D., Hoang, P., Powell, J. G., Shi, J. (2002). "Detection of
   financial time series turning points: a new CUSUM approach applied to IPO
   cycles." Review of Quantitative Finance and Accounting 18(3):293-315.
2. Aue, A., Kirch, C. (2024). "The state of cumulative sum sequential
   changepoint testing 70 years after Page." Biometrika 111(2):367-391.
3. Andreou, E., Ghysels, E. (2009). "Structural Breaks in Financial Time
   Series." Handbook of Financial Time Series, Springer, 839-870.
4. Ju, C.-B., Chen, A.-P. (2022). "Identifying Financial Market Trend
   Reversal Behavior With Structures of Price Activities Based on Deep
   Learning Methods." IEEE Access 10:12854-12877.
5. Wood, K., Roberts, S., Zohren, S. (2021). "Slow Momentum with Fast
   Reversion: A Trading Strategy Using Deep Learning and Changepoint
   Detection." Journal of Financial Data Science 4(1):111-129.
6. Jegadeesh, N. (1990). "Evidence of Predictable Behavior of Security
   Returns." Journal of Finance 45(3):881-898. De Bondt, W., Thaler, R.
   (1985). "Does the Stock Market Overreact?" Journal of Finance 40(3).
7. Brock, W., Lakonishok, J., LeBaron, B. (1992). Journal of Finance
   47(5):1731-1764. (see 18.2 refs)
8. Hamilton, W. P. (1922). The Stock Market Barometer. Rhea, R. (1932).
   The Dow Theory.
9. Wyckoff, R. (1930s). Studies in Tape Reading / schematics literature.
10. Edwards, R., Magee, J. (1948). Technical Analysis of Stock Trends.
11. Brooks, A. (2009-2012). Price Action trading trilogy.
12. Fuller, N. (2008- ). Price Action materials (false breakout doctrine).
13. ICT materials; ictkillzone.com (2026) BOS/CHOCH/MSS guides;
    fairvaluehub.de (2026); smartinggoods.com (2026).
14. smartmoneytrader.co (2025). "What Is CHoCH in ICT Trading?" (CHoCH vs
    BOS vs MSS vs CISD table).
15. backtrex.com (2026). "ICT Market Structure Shift (MSS): Complete Guide"
    (sweep prerequisite).
16. innercircletrader.net (2026). "ICT Market Structure Shift" tutorials;
    "MSS vs CHOCH — Smart Money Differences & Combined Trade Flow."
17. fintorro.com (2026). "Change of Character (CHoCH) for Beginners."
18. Xcelerate Trade team, "MSS" indicator (TradingView, Pine v6) — break
    validation modes, MSS definitions, trend state.
19. TradingFinder, "Market Structures + ZigZag CHoCH/BOS - MSS/MSB"
    (TradingView, Pine v5).
20. "CHoCH Multi-Timeframe" (TradingView, Pine).
21. SmartFlow SMC (TradingView, Pine) — MSS-anchored OB chain.
22. MQL5 article 22249 (2026). "Building the Market Structure Sentinel
    Indicator in MQL5."
23. SrsBlack/ict-knowledge-library (GitHub). `choch-bullish` formal
    criteria.
24. pinescriptforge.com (2026). "Market Structure Shift (MSS) Strategy"
    backtests on 64 futures symbols.
25. VelmoPk/Smart-Money-Concepts-indicator-MT5; LesleyJJ/SMCIndicator-public
    (GitHub).
26. SuperCents_X: Structure/CHOCHDetector.mqh, Structure/BOSDetector.mqh,
    Structure/TrendState.mqh, Structure/ProtectedPointManager.mqh,
    Structure/PPTelemetry.mqh, Utils/Types.mqh (CHOCHEvent),
    Telemetry/TelemetryTypes.mqh (v3 schema).
27. Evidence/Sprint17/merged/*.csv (frozen; 18,686 rows; fingerprint
    `2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`).
