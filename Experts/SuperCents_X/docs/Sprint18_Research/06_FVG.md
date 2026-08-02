# Sprint 18.6 — Fair Value Gaps Deep Research Review

**Document:** 06_FVG.md
**Series:** Sprint 18 — Deep Research Program (research only; no production code changes)
**Status:** Complete
**Supersedes / complements:** 02_BOS_Research.md (BOS pairing), 03_CHOCH_MSS.md (CHOCH pairing), 05_OrderBlocks.md (OB+FVG pairing and layer decoding)
**Methodology:** Mandatory 8-phase structure defined in 00_Program_Overview.md; phases 1-5 never reference SuperCents_X.

---

## 1. Foundation — What a "Fair Value Gap" Claims to Be

### 1.1 The core claim

A **Fair Value Gap (FVG)** is a three-candle pattern: candle A and candle C move in the
same direction (both bullish for a bullish FVG), while candle B (the "displacement"
candle) overlaps neither — leaving a **gap between A's extreme and C's extreme** that
price "skipped over." In SMC doctrine:

1. The gap represents an **imbalance between supply and demand** — institutional order
   flow was so one-sided that price jumped the zone; the skipped prices never traded
   (in candle terms).
2. Price is therefore expected to **return to the gap** ("fill," "rebalance") because
   unfilled orders and missed participation sit there.
3. The FVG is used as an **entry zone** (limit at the gap), a **continuation anchor**
   in trends, and a **target** (opposite-direction FVGs act as magnets).

**Canonical detection rule:** bullish FVG = `low(C) > high(A)` with A bearish and C
bullish (or wick-based: gap between A's low and C's high); bearish FVG = `high(C) <
low(A)` with A bullish and C bearish. Most implementations use the **wick extremes**
(low/high), some use the **bodies** (close/open).

### 1.2 The vocabulary

| Term | Meaning |
|---|---|
| **FVG / imbalance** | 3-candle gap zone (A and C same direction, B displacement) |
| **Fill / mitigation** | Price trading back into the gap |
| **Unfilled FVG** | Gap not yet touched — the preferred entry state |
| **Displacement candle** | The middle candle (B); its body is used for strength grading |
| **Breakaway FVG** | Gap formed at a BOS (momentum out of a range) |
| **Reversal FVG** | Gap formed at a CHoCH/MSS (turn) |
| **Continuation FVG** | Gap in the direction of the prevailing trend |
| **Balanced price range (BPR)** | The zone swept by price between two opposing FVGs (newer ICT refinement) |
| **Displaced FVG (DFVG)** | A conventional FVG shifted in price — a later ICT refinement |

### 1.3 The falsifiable core

1. **Do one-bar price gaps carry return predictability?** — The academic order-flow
   imbalance literature says yes in the *short term* (Phase 2), but for *order flow
   imbalance*, not for chart-gaps per se.
2. **Does price return to fill these zones, and do decisions anchored on them win?** —
   Directly measurable in the Sprint 17 dataset (Phase 7).
3. **Is the middle candle really a displacement?** — The current detector (Phase 6)
   applies **no minimum to candle B's body**; any three-candle arrangement with a
   wick-gap qualifies. The doctrine insists the middle leg be a genuine displacement.

---

## 2. Academic Literature — Imbalance, Gaps and Order Flow

The academic literature studies *price gaps* and *order-flow imbalance* (OFI) — the
two phenomena the FVG concept maps onto.

### 2.1 Order flow imbalance predicts short-term returns

- **Cont, Kukanov & Stoikov (2014), "The Price Impact of Order Book Events,"
  *Journal of Financial Markets* 26, 47-69:**
  - Defines **order flow imbalance** (OFI) from the sequence of order-book events
    (market orders, cancellations, limit-order arrivals) and shows OFI is the primary
    driver of high-frequency price changes — a linear relation holding across stocks.
  - Implication: *imbalance → price move* is an empirically documented mechanism.
    The FVG's 3-candle pattern is a *very slow, candle-level proxy* of the same
    imbalance. The academic finding supports the *directional* claim (one-sided flow
    moves price through the zone) but says nothing about the zone being refilled.
- **Biais, Hillion & Spatt (1995)** (also used in 18.5): order placement exhibits a
  "momentum effect" — participants add liquidity on the side of the move, deepening
  the book in the direction of travel. The zone skipped by an imbalance (the FVG)
  is then surrounded by *more* passive depth on the continuation side — supportive of
  continuation behavior after an imbalance gap, at least intraday.

### 2.2 The price-gap literature — the honest counterpoint

- The empirical gap literature (equity markets, overnight/weekend gaps) finds gaps are
  **often filled** but with **no reliable, exploitable edge** after controlling for
  volume and news (the "fill the gap" heuristic is one of the oldest and least
  robust market maxims; reviews in practitioner-TA literature are consistently
  skeptical).
- The chart-gap literature measures *overnight information gaps*; an intraday
  ertan 3-candle imbalance is a different animal, but the *caution* transfers: a gap
  zone's fill probability is context-dependent (news, volume, time), not a fixed
  property.
- **Implication:** the FVG's predictive power, if any, should be strongest *immediately*
  after formation and decay with age — a testable hypothesis that the current schema
  cannot measure (FVG age is not serialized; Phase 7).

### 2.3 Hidden-liquidity and book-dynamics context

- Bouchaud, Farmer & Lillo (2009) (18.4/18.5 citations): limit-order books rebuild
  depth after a fast move on a time scale of seconds-to-minutes; "liquidity takes
  time to replenish." The FVG zone is precisely the region where replenishment is
  incomplete for a while — the window in which reversion to the zone is most
  plausible. This gives a *mechanistic reason* for the "fresh FVG" rule (the edge
  decays as the book heals).

### 2.4 The honest summary of the academic layer

| Question | Academic verdict | Strength |
|---|---|---|
| Does order-flow imbalance predict short-term moves? | Yes (Cont et al. 2014; OFI literature) | I |
| Do participants add depth on the move side? | Yes (Biais et al. 1995) | II |
| Are chart gaps reliably filled with an exploitable edge? | No — the gap literature is skeptical (equity overnight gaps) | II |
| Does the FVG zone specifically act as an entry/TP magnet? | Not studied under this name; mechanism support only | V |
| Is the "fresh FVG" edge decay plausible? | Yes (book replenishment time scales, Bouchaud et al.) | II |

The academic layer validates *imbalance-driven moves* but is explicitly skeptical of
"gaps get filled" as a standalone rule — the fill claim needs context (freshness,
volume, structure), which the current implementation grades only cosmetically
(Phase 6).

---

## 3. Professional Trading Literature — Practitioner Doctrine

### 3.1 ICT fair value gap doctrine

- **Definition:** the imbalance zone left by the displacement leg; price is expected
  to revisit it ("fill") before continuing. Entries at the FVG (limit), targets at
  the next liquidity.
- **FVG + OB confluence:** the strongest ICT entry setups pair the FVG with the order
  block zone of the same leg (an overlapping OB+FVG is the canonical "high probability"
  zone). This matches the OB_FVG rule family (Phase 6/7).
- **Inversion FVG:** when price sweeps *through* an FVG and closes beyond, the zone
  "inverts" — what was a bullish imbalance becomes a bearish one (resistance turns
  support and vice versa). No inversion concept exists in the implementation.
- **Balanced Price Range (BPR):** newer ICT formulations define the price range swept
  between two opposing FVGs as a magnet zone; the FVG itself is presented as a
  *component* of liquidity, not a standalone signal.
- **Freshness:** the doctrine strongly prefers **unfilled, fresh** FVGs; a filled FVG
  is a "used" zone and the rule for most practitioners.

### 3.2 The displacement requirement

- Across surveyed SMC content, the middle candle (B) is taught to be a **displacement
  candle**: wide range, small wick, strong close — not just "any candle." The FVG is
  the *footprint of the displacement*, so a weak middle candle undermines the
  pattern's premise.
- Implementation gap (Phase 6): the detector requires minimum bodies on candles A and
  C (5 pips) but **no minimum on B** — a pattern the doctrine would reject as a
  non-displacement FVG is accepted.

### 3.3 Fill semantics — close vs wick (the recurring fork)

- **Close-based fill** (current implementation): the gap is filled when a candle
  *closes* inside it. Conservative; a wick through the zone does not fill it.
- **Wick-based fill** (common in older indicators): any touch fills the gap.
- Practitioner usage is split; the close-based variant is the stricter and more
  common in recent SMC content (a wick is "a test," a close is "participation").

### 3.4 Practitioner checklist (consolidated)

1. A and C opposite-direction bodies with a wick-gap (universal).
2. B must be a displacement (most schools; **not implemented**).
3. Fresh, unfilled FVGs only (universal).
4. Entry at the zone on the first return (universal).
5. OB+FVG overlap = highest-conviction zone (majority of modern content).
6. Inversion handling when price closes through (newer content; **not implemented**).

---

## 4. Institutional / Quantitative Practice

### 4.1 Spread and latency mechanics behind gaps

- The 3-candle gap is, mechanically, a period where the **best bid/offer jumped**
  without trading the intermediate prices: market-making inventory shocks, news
  prints, or large marketable orders exhausting the book. In OFI terms the gap
  records a *large negative/positive OFI print*.
- Institutional practice does not trade "FVG zones" — it trades the *replenishment*
  (Phase 2.3): after the jump, market makers re-offer around the skipped zone with
  wider spreads and less depth; the reversion to the zone is the market's way of
  re-pricing the skipped range. The FVG is a retail-visible label for this dynamic.

### 4.2 Why the pattern persists professionally

- Same coordination argument as OBs (18.5 §4.3): the pattern is objective, computable,
  and widely published — it is a *coordination point* that generates its own flow.
- **Caveat with institutional weight:** flow-concentration arguments cut both ways —
  a widely-known entry zone is also where stop placement concentrates (Osler 2002,
  18.4), i.e., where *counter-entries* and sweeps are manufactured. The measured data
  (Phase 7) is the only way to arbitrate.

---

## 5. Open-Source Implementations — Common Design Choices

### 5.1 Survey scope

FVG indicators are among the most common SMC tools on TradingView and MQL5. Dominant
patterns:

### 5.2 Detection variants

| Variant | Usage in open source | SuperCents_X (Phase 6) |
|---|---|---|
| Wick-to-wick gap (low/high extremes) | Majority | Yes (:207-241) |
| Body-to-body gap (close/open) | Minority | — |
| Min gap size filter | Common (0.5-5 pips typical) | Gap only needs `> EPS` (0.1 pt); no minimum size |
| Min A/C body size | Common | 5 pips (:179) |
| Min B (displacement) body | Common in newer suites | **None** |
| Consecutive-candle FVG / DVG | Growing minority | — |

### 5.3 Fill and lifecycle conventions

- **Fill = close inside** (majority of newer content) vs **wick inside** (older).
- **Expiry:** unfilled FVGs expire after N bars (50-100) or on structure
  invalidation; some suites keep them until filled (matches SuperCents_X).
- **Inversion:** a minority of suites re-label an FVG when price closes through it.

### 5.4 Classification in open source

- **Breakaway / continuation / reversal** labels (as in SuperCents_X's enum) appear
  in several suites, usually assigned by the surrounding structure event
  (BOS = breakaway, CHoCH = reversal, trend = continuation) — the same heuristic as
  the implementation's `ClassifyFVG`. No suite was found that validates these labels
  statistically; they are descriptive.

---

## 6. Current SuperCents_X Implementation — Read-Only Code Review

### 6.1 Scope of review

- `Structure/FVGDetector.mqh` (541 lines) — detection, classification, lifecycle.
- `Utils/Constants.mqh` — FVG thresholds (lines 81-88).
- `Utils/Types.mqh` — `struct FairValueGap` (lines 111-133) and the FVG enums
  (lines 85-108).
- `Confluence/ConfluenceEngine.mqh` — telemetry flag (line 322) and fill-based expiry
  (lines 374-396).
- `Confluence/ConfluenceRules.mqh` — `FindUnfilledFVG` rule helper (lines 140-147).

### 6.2 Architecture and wiring

- `CFVGDetector` is fed by `CSymbolContext` (SymbolContext.mqh:343 wires the shared
  BOS detector; the CHOCH detector is injected via `SetCHOCHDetector`). `Update`
  (:338-351) runs `DetectFVG` then `UpdateLifecycle`.
- It receives `CTrendState` per update for classification and lifecycle
  (:341-346). Classification therefore depends on the same trend classifier that
  gates CHOCH/OB (18.3/18.5) — a shared upstream dependency across the whole
  structure layer.

### 6.3 Detection (`DetectFVG`, :125-336)

- **Pattern:** classic 3-candle wick-gap (:204-241):
  - Bearish FVG: A bullish, C bearish, `high(C) + EPS < low(A)` — gap = [high(C), low(A)].
  - Bullish FVG: A bearish, C bullish, `low(C) > high(A) + EPS` — gap = [high(A), low(C)].
  - `EPS = 0.1 * Point` (:133) — the gap needs no minimum *size* beyond the epsilon;
    a 0.2-point gap is an FVG.
- **Body filters:** `bodyA` and `bodyC` must be at least `FVG_MIN_BODY_SIZE_PIPS = 5`
  pips (:179, Constants:81). Doji A or C rejects the pattern.
- **Middle candle B is unfiltered** (:176-178 computes `bodyB` but nothing rejects on
  it) — the displacement requirement (3.2) is not implemented.
- **Incremental processing** with `m_lastProcessedTime` (:138-168): new-bar delta
  processing, full-history rescan on time discontinuity (with FVG reset, :144-151).
  This is the most robust incremental scheme among the detectors reviewed so far
  (OB/CHOCH use event-index gating).
- **Duplicate rejection** by middle-candle time (:274-293) — the triple (i, i-1, i-2)
  is unique per B, so this is exact.
- **Zone geometry:** wick-to-wick (upper/lower = candle extremes, :207-214,
  :227-234) — the majority variant (5.2).
- **candleIndex/time** = middle candle B (:271-272) — the FVG is *dated to the
  displacement candle*.

### 6.4 Classification (`ClassifyFVG`, :401-539)

- **Size:** gap pips buckets — SMALL < 3, MEDIUM < 10, LARGE ≥ 10
  (Constants:85-86).
- **Strength:** B's body — WEAK < 5, NORMAL < 15, STRONG ≥ 15 pips
  (Constants:87-88).
- **Class** (precedence REVERSAL > BREAKAWAY > CONTINUATION > UNKNOWN):
  - REVERSAL: direction-matching CHOCH within `FVG_CLASS_LOOKBACK_SECONDS = 2700`
    (3 * 900, Constants:84) before the FVG (:480-492).
  - BREAKAWAY: direction-matching BOS within the same lookback (:493-505).
  - CONTINUATION: FVG direction == current trend (:506-519).
  - UNKNOWN otherwise (:520-531).
- **Hardcoded M15 bar length:** `SECS_PER_BAR = 900` (:403) — `barsSinceCHOCH/BOS`
  are computed as `secs/900` regardless of the actual timeframe. On H1, "bars since"
  is undercounted by 4x (cosmetic; classification itself is gated in *seconds* and
  remains TF-correct).
- **Classification is descriptive only** — class/size/strength are logged
  (:328-332, :485-533) and counted in Shutdown summaries (:95-110) but **never reach
  the decision layer or the telemetry CSV** (gap: E2 backlog).
- Note the class precedence: a REVERSAL FVG (CHOCH-anchored) is never also used as
  breakaway evidence; the *same* CHOCH can mint both a CHOCH_OB rule decision (18.5)
  and label a later FVG as reversal — the labeling is single-assignment per FVG.

### 6.5 Lifecycle (`UpdateLifecycle`, :353-399)

- **Fill:** when the *last closed* bar's close (`close[1]`) enters the gap
  (:368-379) — close-based, the stricter variant (3.3).
- **Bug:** `fvg.fillTime = 0` on fill (:375) — the fill timestamp is zeroed, not
  set to the fill bar's time (the field exists for exactly this purpose).
- **Invalidation:** when TrendState opposes the FVG direction AND the FVG is not yet
  filled (:383-396). **Filled FVGs are never invalidated**; no time expiry exists —
  an unfilled FVG persists until trend flip (5.3: matches a permissive minority).
- Same lifecycle asymmetry as the OB layer (18.5 §6.4): structure-state-based
  invalidation, no staleness decay.

### 6.6 Rule-layer and telemetry integration

- **Rule helper `FindUnfilledFVG`** (ConfluenceRules.mqh:140-147): scans FVGs
  newest-first, skips `filled`, returns the id — the OB_FVG rule pairs this with the
  OB evidence. Fill state therefore gates the rule; gap size/class/strength do not.
- **Telemetry proxy:** `hasFVG = (bestRule.type == RULE_OB_FVG_BULLISH ||
  RULE_OB_FVG_BEARISH)` (ConfluenceEngine.mqh:322) — the same family-proxy pattern as
  hasOrderBlock/hasLiquiditySweep (18.5 §6.5, 18.4 §6.9).
- **Signal expiry:** FVG-anchored signals expire with `EXPIRY_FVG_FILLED` when the
  FVG is found filled **or not found at all** (:374-396) — two distinct states share
  one reason code (conflation; minor correctness note for 18.10 expiry review).
- `qualityScore` is constant 1.0 (:306) — dead grading field (same as OB, 18.5 §6.3).

### 6.7 Logging hygiene

- FVG rejections are logged **only inside a hardcoded debug window**
  `D'2026.01.12'..D'2026.02.06'` (:258) — leftover investigation instrumentation in
  the production path. Every creation and classification prints full-context logs
  (:328-332, :485-533). Log-volume analysis belongs to 18.13.

### 6.8 Phase 6 summary — implementation characteristics

| Aspect | Implementation | Gap vs doctrine / survey |
|---|---|---|
| Pattern | classic wick-to-wick 3-candle, min A/C bodies 5 pips | no min gap size; no min B body (displacement) |
| Incremental | time-gated with discontinuity rescan | best-in-class among detectors reviewed |
| Classification | size/strength/class computed (lookback 2700s) | never serialized; H1 "bars since" undercounted |
| Fill | last closed bar close inside gap | fillTime bug; strict-vs-wick untested |
| Invalidation | opposing trend, only if unfilled | no time expiry; filled never invalidated |
| Telemetry | hasFVG = rule-family proxy; id only | class/size/strength/age/fill-state absent |

---

## 7. Sprint 17 Evidence Review — Measured Only

### 7.1 Scope and method

Same frozen dataset (19 merged CSVs, 18,686 rows, fingerprint
`2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`; provenance in
01_Swing_Detection.md §7.1). Decided+signal rows only (n=17,073). Fresh query script
`sprint18_6_fvg.py`; all numbers re-verified by hand.

### 7.2 The FVG flag overall (proxy caveat: it means "OB_FVG rule fired")

| hasFVG | n | Win rate | Identity |
|---|---|---|---|
| '1' (FALSE) | 4,753 | 0.3147 | LIQUIDITY_BOS (3,553) + BOS_OB (858) + CHOCH (342) |
| '2' (TRUE) | 12,320 | 0.3388 | OB_FVG family |

- The TRUE set is exactly the OB_FVG family (12,320 rows); the FALSE set is a mix of
  the worst family (LIQUIDITY_BOS) and the two best OB pairings (BOS_OB 0.3730,
  CHOCH 0.3567) — so the raw flag comparison is family-confounded, exactly as
  established for hasOrderBlock (18.5 §7.2).

### 7.3 The controlled comparison: OB-present, FVG vs no-FVG

Within the OB-present rows (from 18.5 §7.3):

| OB | FVG | n | Win rate | Identity |
|---|---|---|---|---|
| TRUE | FALSE | 1,200 | 0.3683 | BOS_OB + CHOCH_OB |
| TRUE | TRUE | 12,320 | 0.3388 | OB_FVG family |

- **Pairing an FVG with the OB instead of a BOS or CHOCH costs 3.0pp** (0.3683 vs
  0.3388). The OB+FVG combo — the doctrine's "highest-conviction zone" (3.1) — is the
  *weakest OB pairing* in the measured data. The ranking of OB pairings stands:
  **OB+BOS (0.3730) > OB+CHOCH (0.3567) > OB+FVG (0.3388) > sweep-without-OB
  (0.2967)**.
- **Directional asymmetry — the largest in the dataset:**

| Rule | Symbol | TF | n | Win rate |
|---|---|---|---|---|
| OB_FVG_BEARISH | EURUSD | M15 | 4,096 | 0.3896 |
| OB_FVG_BEARISH | EURUSD | H1 | 1,042 | 0.3858 |
| OB_FVG_BEARISH | GBPJPY | H1 | 770 | 0.2974 |
| OB_FVG_BULLISH | EURUSD | M15 | 4,368 | 0.2942 |
| OB_FVG_BULLISH | EURUSD | H1 | 864 | 0.2674 |
| OB_FVG_BULLISH | GBPJPY | H1 | 1,180 | 0.3653 |

  - Overall: bearish 0.3769 (n=5,908) vs bullish 0.3036 (n=6,412) — a **7.3pp
    directional gap**, the largest measured anywhere in the program.
  - Best cell: **EURUSD_M15 bearish 0.3896 (n=4,096 — the largest sample of any
    cell in the dataset)**; worst: **EURUSD_H1 bullish 0.2674 (n=864)** — a 12.2pp
    spread.
  - The EURUSD direction story is stark: bearish EURUSD ~0.386-0.390, bullish
    EURUSD ~0.267-0.294. GBPJPY inverts it: bullish 0.3653 beats bearish 0.2974.
  - EURUSD total 0.3389 (n=10,370) vs GBPJPY 0.3385 (n=1,950); M15 0.3404 (8,464)
    vs H1 0.3353 (3,856) — the family is symbol/TF-neutral on aggregate, with all
    the signal hidden in the direction split.

### 7.4 hasFVG x trendAligned

| hasFVG | trendAligned | n | Win rate |
|---|---|---|---|
| TRUE | TRUE | 3,386 | 0.3517 |
| TRUE | FALSE | 8,934 | 0.3339 |
| FALSE | TRUE | 909 | 0.3124 |
| FALSE | FALSE | 3,844 | 0.3153 |

- trendAligned adds **+1.8pp** for the FVG family — consistent with the OB-family
  result (18.5 §7.3) and opposite to the sweep family (18.4 §7.5). Within-family
  directional x alignment details:

| Rule | trendAligned | n | Win rate |
|---|---|---|---|
| OB_FVG_BEARISH | TRUE | 1,797 | 0.3951 |
| OB_FVG_BEARISH | FALSE | 4,111 | 0.3689 |
| OB_FVG_BULLISH | TRUE | 1,589 | 0.3027 |
| OB_FVG_BULLISH | FALSE | 4,823 | 0.3039 |

- Trend alignment helps the *bearish* FVG (0.3951, +2.6pp) and is neutral for the
  bullish FVG — the trend gate's value is itself direction-conditional.

### 7.5 Layer composition (confirms the 18.5 decoding)

| Rule family | layerStructural | layerTotal | confidence |
|---|---|---|---|
| OB_FVG_* | 25 (OB 15 + FVG 10) | 35 / 40 | 0.35 / 0.40 (raw counts: 3,386 / 8,934) |

- `confidence ≡ layerTotal/100` again (0.35↔35, 0.40↔40) — no independent
  information (18.5 §7.4 finding extended).
- The best-behaved OB_FVG cell (EURUSD bearish, 0.386-0.390) carries the same
  0.35/0.40 confidence as the worst (EURUSD bullish, 0.267) — the confidence never
  differentiates direction, symbol, or timeframe.

### 7.6 What the dataset cannot measure (explicit)

1. **FVG freshness at decision time:** bars since formation — not serialized
   (edge-decay hypothesis, 2.2, untestable).
2. **Fill state at decision time:** the rule requires unfilled FVGs
   (ConfluenceRules.mqh:140-147), but the decision row does not record which FVG was
   used or its state.
3. **FVG class/size/strength:** computed in-engine (6.4) but never serialized — the
   continuation-vs-reversal-vs-breakaway distinction is untestable in the dataset.
4. **Gap geometry:** gap size in pips, zone width, displacement candle body — absent.
5. **Inversion events:** no concept exists (3.1).
6. **The close-vs-wick fill question:** unmeasurable (only rule-level outcome).

### 7.7 Phase 7 synthesis

1. **OB+FVG is the weakest OB pairing** (0.3388 vs OB+BOS 0.3730 / OB+CHOCH 0.3567)
   — the doctrine's "highest-conviction zone" is the *lowest-performing* measured
   combination. This is the most doctrine-opposite result of the program so far.
2. **The direction asymmetry dominates the family** (bearish +7.3pp overall;
   EURUSD bearish 0.390 vs EURUSD bullish 0.267) — the single strongest
   direction-conditioned signal in the dataset; a candidate 18.8 input and 18.12
   regime study.
3. **trendAligned is direction-conditional for FVG** (+2.6pp bearish, ~0 bullish).
4. **FVG class/size/strength exist in-engine and are thrown away** — the cheapest
   telemetry win available in the whole structure layer (E2).
5. **The displacement requirement is absent** in the detector (middle candle
   unfiltered) — every measured FVG row may include non-displacement gaps.

---

## 8. Experiment Backlog — Sprint 19 Candidates

| ID | Experiment | Evidence | Conf | Priority |
|---|---|---|---|---|
| E1 | **Displacement requirement on candle B:** min body (e.g., ≥ 5-10 pips or ATR-relative) before an FVG is accepted; re-measure OB_FVG | II (doctrine majority 3.2) | B | P1 |
| E2 | **FVG classification telemetry (schema v4):** serialize class/size/strength, gap size, displacement body, fill state and age at decision time — the cheapest, highest-value telemetry add in the structure layer | n/a (extend 18.2 E4 / 18.5 E2) | A | P1 |
| E3 | **Direction-conditioned gating study:** EURUSD bullish FVG (0.267-0.294) vs bearish (0.386-0.390) — separate confidence/eligibility by direction and symbol | II (7.3/7.4 measured) | B | P1 |
| E4 | **FVG age decay test:** win rate by bars-since-formation (requires E2) vs doctrine's freshness rule | II (2.2/2.3 mechanism + practitioner rule) | B | P2 |
| E5 | **Fill semantics test:** close-based vs wick-based fill in the rule layer (requires fill-state telemetry) | III (3.3 split) | C | P2 |
| E6 | **Fix fillTime bug and split EXPIRY_FVG_FILLED / EXPIRY_FVG_NOT_FOUND** (ConfluenceEngine.mqh:374-396 conflation) | n/a (correctness) | A | P1 |
| E7 | **Inversion FVG support:** re-label a closed-through FVG and measure | IV | D | P3 |
| E8 | **Min gap size filter:** 1-3 pips minimum vs current 0.1-pt epsilon | III (5.2 corpus norm) | C | P2 |

**Priority recommendation:** E2 first (it unlocks E3, E4, E5 measurement), then E1
(displacement) and E3 (direction gating) as the behavioral experiments; E6 is a
free correctness fix. E7/E8 are research-stage.

---

## References (consolidated)

### Academic
1. Cont, R., Kukanov, A. & Stoikov, S. (2014). "The Price Impact of Order Book
   Events." *Journal of Financial Markets* 26, 47-69.
2. Biais, B., Hillion, P. & Spatt, C. (1995). "An Empirical Analysis of the Limit
   Order Book and the Order Flow in the Paris Bourse." *Journal of Finance* 50(5),
   1655-1689.
3. Bouchaud, J.-P., Farmer, J.D. & Lillo, F. (2009). "How Markets Slowly Digest
   Changes in Supply and Demand." In *Handbook of Financial Markets*, Elsevier.
4. Osler, C. (2002/2005). "Stop-Loss Orders and Price Cascades in Currency Markets."
   FRBNY Staff Report 150; *Journal of International Money and Finance* 24(2), 2005.
5. Price-gap literature (equity overnight/weekend gaps; "gaps get filled" heuristics
   and the skeptical evidence on exploitable gap edges) — survey position; primary
   sources vary by market and era.

### Professional / practitioner
6. ICT (Inner Circle Trader) FVG doctrine: imbalance zones, fill expectations, FVG+OB
   confluence, inversion FVG, Balanced Price Range (secondary sources surveyed in
   this sprint; SMC corpus).
7. SMC content corpus (18.2-18.5 sources): displacement requirements, close-vs-wick
   fill forks, freshness rules.

### Open-source / implementations
8. Open-source FVG indicators (TradingView indicator corpus, MQL5 codebase articles):
   wick-vs-body variants, min-size filters, fill semantics, expiry conventions,
   breakaway/continuation/reversal labeling.

### Internal
9. `Structure/FVGDetector.mqh` (541 lines) — Phase 6 code review.
10. `Utils/Constants.mqh` — FVG thresholds (lines 81-88).
11. `Utils/Types.mqh` — `struct FairValueGap` (lines 111-133) and enums (lines
    85-108).
12. `Confluence/ConfluenceEngine.mqh` — hasFVG proxy (line 322), expiry (lines
    374-396).
13. `Confluence/ConfluenceRules.mqh` — `FindUnfilledFVG` (lines 140-147).
14. `Portfolio/SymbolContext.mqh` — wiring (line 343).
15. `docs/Sprint18_Research/00_Program_Overview.md` — methodology.
16. `docs/Sprint18_Research/02_BOS_Research.md`, `03_CHOCH_MSS.md`,
    `05_OrderBlocks.md` — pairing evidence and layer decoding.
17. Sprint 17 merged evidence dataset (fingerprint
    `2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`) and query
    script `sprint18_6_fvg.py`.
