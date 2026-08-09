# Sprint 18.5 — Order Blocks Deep Research Review

**Document:** 05_OrderBlocks.md
**Series:** Sprint 18 — Deep Research Program (research only; no production code changes)
**Status:** Complete
**Supersedes / complements:** 01_Swing_Detection.md (pivot source), 02_BOS_Research.md (BOS_OB family), 03_CHOCH_MSS.md (OB trigger chain), 04_Liquidity.md (OB vs sweep pairing asymmetry)
**Methodology:** Mandatory 8-phase structure defined in 00_Program_Overview.md; phases 1-5 never reference SuperCents_X.

---

## 1. Foundation — What an "Order Block" Claims to Be

### 1.1 The core claim

An **order block (OB)** is the last candle (or candle cluster) in the *opposite*
direction before a strong, one-sided impulse move. The SMC claim is that this candle
represents the visible footprint of **institutional limit order placement** — the
zone where a large participant accumulated or distributed before initiating the
impulse leg. Consequently:

1. The OB zone marks where **unfilled institutional orders remain** (the "break-even"
   area of the initiating institution), so price is expected to **return to the zone
   ("mitigate")** before continuing in the impulse direction.
2. Entries are taken at the OB zone (limit-style), with the stop beyond the zone and
   the target at the next liquidity level.

**Canonical definition (ICT lineage):** a bullish OB = the last **bearish** candle
before the **bullish displacement** leg; a bearish OB = the last **bullish** candle
before the **bearish displacement** leg. The candle must be the *immediately preceding*
opposing candle (or one of the final few), and the move after it must be an actual
displacement (wide-range, low-wick, momentum), not merely a small drift.

### 1.2 The vocabulary

| Term | Meaning |
|---|---|
| **Order block** | Last opposite-direction candle (or cluster) before an impulse leg |
| **Displacement leg** | The high-momentum move that follows the OB |
| **Mitigation** | Price trading back INTO the OB zone (the entry event) |
| **Unmitigated OB** | Fresh OB, never touched — the preferred state in doctrine |
| **OB + FVG confluence** | An OB whose zone overlaps a Fair Value Gap of the displacement leg |
| **Multi-candle OB** | Zone spanning several candles rather than a single candle |
| **Volume-weighted OB** | OB confirmed/ranked by volume-at-price (departure from pure SMC) |

### 1.3 The falsifiable core

1. **Do institutional orders concentrate at the last opposite candle before impulses?**
   — Partially testable via microstructure literature (Phase 2): limit-order depth does
   concentrate at technical levels, and informed traders do favor limit orders.
2. **Does price return to the OB zone after the impulse (mitigation) and then
   continue?** — This is the *predictive* claim; the Sprint 17 dataset measures the
   win rate of decisions built on OB evidence (Phase 7).
3. **Does the choice of "first opposite candle within 500 bars" (the current
   implementation, Phase 6) preserve the doctrine's "immediately preceding" condition?**
   — It does not, strictly: the implementation's search has no displacement
   requirement and accepts any opposite candle up to 500 bars back.

---

## 2. Academic Literature — Order Placement, Depth and Informed Trading

The academic literature does not study "order blocks" under that name; it studies the
underlying phenomena: **where limit orders sit, who places them, and how depth at
technical levels behaves.**

### 2.1 Depth concentrates at technical levels

- **Kavajecz & Odders-White (2004), "Technical Analysis and Liquidity Provision,"
  *Review of Financial Studies* 17(1), 65-104** (also used in 18.4):
  - Maps technical-indicator signals (moving averages, support/resistance rules) onto
    the NYSE specialist limit-order book.
  - Technical levels coincide with **concentrations of limit-order depth** — the book
    is thick exactly where the OB doctrine says institutional orders sit.
  - Implication: the *empirical anchor* for the OB claim is the same as for the
    liquidity claim — resting orders cluster at computable levels, so a "zone" that
    technical traders can all identify is where execution flow concentrates.

### 2.2 Who places the orders: informed traders use limit orders

- **Anand, Chakravarty & Martell (2005), "Empirical Evidence on the Evolution of
  Liquidity: Choice of Market versus Limit Orders by Informed and Uninformed
  Traders," *Journal of Financial Markets* 8(3), 289-309:**
  - Informed traders are *more* likely to use **limit orders** than uninformed
    traders (contrary to the naive "informed use market orders" prior), especially
    when they can monitor the book and when time constraints are loose.
  - Implication: the SMC story — a large informed participant places resting limit
    orders in a zone before a directional move — is consistent with this evidence.
- **Biais, Hillion & Spatt (1995), "An Empirical Analysis of the Limit Order Book and
  the Order Flow in the Paris Bourse," *Journal of Finance* 50(5), 1655-1689:**
  - Documents the mechanics of limit-order book evolution and the
    "**momentum effect**" in order placement: traders place orders on the side of
    recent price moves, and depth at a level builds as price approaches it.
  - Implication: depth builds *in front of* price at well-known levels — the
    pre-condition for "price is drawn to the zone where orders rest."

### 2.3 Hidden liquidity and iceberg detection

- The "last opposite candle" is a crude proxy for **hidden/iceberg liquidity**: large
  participants display only a fraction of their size.
- Practice literature on iceberg detection: probing just beyond a visible level and
  reading the speed of replenishment (a re-filled book = hidden size). The OB doctrine
  is a *static, pre-market* proxy for this dynamic behavior.
- Implication for implementation review: an OB zone should be *refreshed* when price
  returns to it — a re-test that fills the book again is economically different from
  a stale one-time zone. The current implementation has no such concept (Phase 6).

### 2.4 The honest summary of the academic layer

| Question | Academic verdict | Strength |
|---|---|---|
| Does depth concentrate at computable technical levels? | Yes (Kavajecz & Odders-White 2004) | II |
| Do informed traders place limit orders in zones? | Yes (Anand et al. 2005) | II |
| Does depth build as price approaches levels? | Yes (Biais et al. 1995) | II |
| Is the *last opposite candle* the actual location of that depth? | **Not tested anywhere** — the specific candle-selection rule is an SMC convention, not an academic finding | V |
| Does price return to such zones before continuing? | Not directly studied (closest: S/R bounce literature; mixed) | IV |

The academic layer supports the *mechanism* (resting institutional orders at levels,
depth building in front of price) but provides **zero support for the specific
single-candle selection rule** — that rule must be validated empirically (Phase 7).

---

## 3. Professional Trading Literature — Practitioner Doctrine

### 3.1 ICT order block doctrine

- **Definition (ICT):** bullish OB = the last bearish candle before a bullish
  displacement move; bearish OB = the last bullish candle before a bearish
  displacement move. The OB is the "footprint" of institutional limit placement.
- **Displacement requirement:** the doctrine insists the move after the OB must be a
  displacement (large range, small wicks, strong close). Without displacement there
  is no OB — merely "a down candle."
- **Mitigation entry:** the canonical entry is a limit at the OB zone when price
  returns to it (often refined with the FVG of the displacement leg, or a
  **OB + FVG overlap** — an OB zone overlapping an unmitigated FVG is considered the
  strongest confluence).
- **Unmitigated-fresh rule:** only *unmitigated* OBs are tradeable; a mitigated OB is
  "used" and typically ignored (some schools allow one re-test).
- **Time staleness:** OBs older than a few candles/legs are considered stale in most
  formulations; the doctrine rarely trades an OB formed many sessions earlier.
- **Key doctrinal divergence (relevant to Phase 6):** most schools require the OB
  candle to be **immediately preceding** the displacement (the last 1-3 candles).
  "Any opposite candle within 500 bars" is *not* a mainstream definition.

### 3.2 The multi-candle / zone dispute

- **Single-candle OBs** (classic ICT): one candle defines the zone [open-close].
- **Multi-candle OBs:** the whole series of opposing candles before the impulse
  becomes the zone. Used by several modern SMC suites to avoid the "wrong candle"
  problem (the displacement can start after a consolidation of several opposite
  candles).
- **Volume-weighted OBs** (order-flow hybrids): the zone is defined by the
  volume-at-price profile of the pre-impulse region (POC of the swing), not by candle
  direction alone. This bridges SMC and classic volume analysis (Wyckoff
  accumulation — the OB as a mini-accumulation range).

### 3.3 The broader institutional footprint literature (Wyckoff lineage)

- **Wyckoff methodology:** before a markup phase, large operators accumulate within a
  trading range; the "spring" (a dip below the range that is quickly recovered)
  corresponds to the SMC *liquidity sweep*; the range edge then acts as the OB-like
  zone. The Wyckoff "spring" is the professional-TA ancestor of the sweep-and-reclaim
  entry at the OB.
- **Volume Spread Analysis (VSA)** (Tom Williams lineage): wide-range bars on high
  volume at range extremes indicate professional involvement; the last such bar
  before a move out of the range is the "effort-to-result" signature the OB doctrine
  renames. VSA provides an independent practitioner check on the "last opposing
  candle" rule: it should be a *wide-spread, high-volume* candle, not any opposite
  candle.

### 3.4 Practitioner checklist (consolidated)

1. OB = last opposing candle(s) before the impulse (all schools; the "last" part is
   universal).
2. Displacement required after the OB (most schools; some accept range expansion).
3. Entry at mitigation (return into zone) — not at the OB's formation (all schools).
4. Freshness matters (most schools; variable window).
5. Volume/range quality of the OB candle (minority, VSA lineage; rising adoption).
6. OB + FVG overlap = strongest confluence (majority of modern SMC content).

---

## 4. Institutional / Quantitative Practice

### 4.1 Execution-algorithm reality

- Institutional execution desks slice large orders over time and *at levels*: the
  volume-weighted average price (VWAP) schedules and technical levels coincide
  because both are computed from the same price history that flow participants
  monitor. The Biais et al. "momentum effect in order placement" (2.2) is the
  quantitative face of this: passive algorithms add liquidity on the side of the
  trend, concentrating resting size near recent extremes — exactly where the OB
  doctrine draws its zones.
- **Implication:** the OB zone is economically real *as a zone of resting passive
  flow*, but the flow is a mix of institutional schedules, HFT market makers and
  other technical participants — it is not necessarily "the initiating institution's
  break-even." The doctrine's narrative over-specifies the mechanism; the
  *concentration* claim survives.

### 4.2 Hidden liquidity practice

- Market makers and HFTs routinely probe for icebergs; a level that "holds" after
  repeated probes is where hidden size rests. The OB candle is the slow, retail-visible
  proxy of the same phenomenon; institutional practice measures it dynamically
  (order-flow tools), not from a single candle.
- **Implication:** the *re-test behavior* (does price return and how does the book
  behave) carries most of the information; the static candle selection is a
  first-order approximation. This favors the "mitigation entry + volume confirmation"
  refinement (3.3) over static OB signals.

### 4.3 Why the static rule persists professionally

- Despite the dynamics above, the single-candle OB remains popular because it is
  **objective, computable and falsifiable** — the same properties that make
  support/resistance persist in professional use (Kavajecz & Odders-White). Its
  persistence is a *convention*, and conventions at levels produce self-reinforcing
  flow (technical levels as coordination points). This is the strongest rational
  basis for keeping an OB concept at all: **coordination**, not institutional
  telepathy.

---

## 5. Open-Source Implementations — Common Design Choices

### 5.1 Survey scope

Representative survey of open-source OB implementations (TradingView indicator corpus,
MQL5 codebase articles, SMC suites seen in 18.2-18.4 surveys). Dominant patterns:

### 5.2 Trigger choice — what mints an OB

| Trigger | Usage in open source | SuperCents_X (Phase 6) |
|---|---|---|
| Last opposite candle before a **displacement** candle (ATR/range-filtered) | Majority in modern SMC suites | **None** — any opposite candle qualifies |
| Last opposite candle before a **structural event** (BOS/CHoCH) | Common (older suites; matches SuperCents_X) | CHOCH-driven (18.3 chain) |
| Range/consolidation breakout with opposite candle | Minority | — |
| Swing low/high anchored (volume profile) | Growing (order-flow hybrids) | — |

### 5.3 Candle selection rules

- **Immediate-predecessor filter:** most suites require the OB candle within the last
  1-3 candles before the impulse (or the structural event's bar range).
- **Backward search window:** when searching (as in SuperCents_X), windows of 5-50
  bars are typical; **500 bars is far beyond the norm** and admits stale, unrelated
  candles.
- **Doji/body filters:** skip candles with negligible bodies (SuperCents_X skips
  dojis, :282-288) — consistent with the corpus.
- **Wick tolerance:** some suites use the candle [high-low] or [open-close] zones
  (SuperCents_X uses [open-close], the body — see Phase 6; the high-low variant is
  common in newer suites for stop placement).

### 5.4 Quality/ranking signals in open source

- Displacement size of the impulse leg (ATR multiples) — the most common ranking.
- OB candle range and volume (VSA-influenced suites).
- Zone overlap with FVG (majority rank "OB+FVG" first).
- Freshness (bars since formation).
- Proximity of current price to the zone (many suites show "distance to OB").

### 5.5 Lifecycle conventions in open source

- **Mitigation = touch into zone** (majority) vs **close inside zone** (minority,
  stricter).
- **Expiry:** most suites expire an OB after N bars (50-100 typical) or after
  mitigation; some keep them until invalidation by structure. SuperCents_X has no
  time expiry (Phase 6) — on the permissive end of the corpus.

---

## 6. Current SuperCents_X Implementation — Read-Only Code Review

### 6.1 Scope of review

- `Structure/OrderBlockDetector.mqh` (383 lines) — the entire OB logic.
- `Utils/Types.mqh` — `struct OrderBlock` (lines 69-83).
- `Portfolio/SymbolContext.mqh` — wiring and update order (lines 326-331, 374, 390,
  418, 674, 692-693, 898-900).
- `Confluence/ConfluenceEngine.mqh` — telemetry flag and signal expiry
  (lines 319-321, 337, 398-419).

### 6.2 Architecture and wiring

- `CSymbolContext::Initialize` creates the detector (SymbolContext.mqh:326-331) and
  `Update` runs it **after** the CHOCH detector
  (SymbolContext.mqh:674 = CHOCH update; :692-693 = OB update) — the OB layer is a
  pure downstream consumer of CHOCH events.
- Consumers: `CVisualizationManager` (:374), `CConfluenceEngine` (:390, forwarded to
  `CTradeCandidateBuilder`), and `CEntrySetupBuilder` (:418, entry-side).
- The OB detector receives the CHOCH detector, the TrendState and the protected-point
  manager on every `Update` (:48-51), but **only uses trendState + close** in
  `UpdateLifecycle`; the protected manager parameter is unused in the whole file.

### 6.3 Detection: the entire OB rule

The complete OB detection logic is:

```
for each NEW CHOCH event:
    scan bars i = choch.barIndex+1 .. choch.barIndex+500   (older bars, series indexing)
        skip doji (open == close)                          (:282-288)
        if bullish CHOCH: first bearish candle  -> OB       (:295-299)
        if bearish CHOCH: first bullish candle  -> OB       (:300-304)
        take it (out = that candle's OHLC, time, index)     (:315-337)
    if none found in 500 bars: OB-SEARCH FAILED             (:341-342)
```

Key characteristics:

1. **CHOCH-driven only.** OBs are minted exclusively from CHOCH events
   (ProcessNewCHOCH, :136-174; incremental via `m_lastProcessedCHOCHIndex`, :112-130).
   There is no displacement-triggered path, no BOS-triggered path. The entire OB layer
   is downstream of the CHOCH detector — which itself is trend-conditional and skips
   `TREND_UNKNOWN` states (18.3 §6). **When TrendState is unknown, no CHOCH, no OB:
   the OB layer is fully dependent on the trend classifier.**
2. **No displacement requirement.** The search accepts *any* opposite candle within
   500 bars before the CHOCH. A 2-pip drift CHOCH mints the same OB as a
   50-pip displacement (5.2/3.1 divergence: doctrine requires displacement).
3. **500-bar window** (:257-258) — far beyond the corpus norm (5.3), admits stale
   unrelated candles. The *closest* opposite candle wins (scan starts at
   choch.barIndex+1), so the window only matters when no opposite candle exists near
   the CHOCH — but a 490-bar-old opposite candle *is* selected when no nearer one
   exists.
4. **Body-only zone.** The zone is `[open, close]` (:317-321, :192-193) — the wick
   range [high-low] is not part of the zone (5.3: newer suites use full range for
   stop placement).
5. **qualityScore always 1.0** (:156) — no grading despite the field existing
   (5.4: ranking signals unused).
6. **No duplicate prevention.** Every CHOCH mints a new OB; two CHOCHs in quick
   succession can create two OBs on the same candle. The rejection counters
   (`rejectedDuplicate`, `rejectedInvalid`, `rejectedCapacity`) are printed in
   Shutdown (:362-364) but **never incremented anywhere** — dead telemetry.
7. **Protected-point manager parameter is passed but never used** (:48-51, :98-101) —
   the signature promises more than the implementation does.
8. **Verbose diagnostic logging in production path:** every search prints
   OB-SEARCH BEGIN/BOUNDS (:229-276), per-candidate logs (:306-313) and a RESULT block
   (:324-335) per OB attempt — a debugging instrument left on; at production log
   levels this is a performance and log-volume concern (log volume analysis belongs
   to 18.13).

### 6.4 Lifecycle

`UpdateLifecycle` (:176-221), run after each new CHOCH batch:

- **Mitigation:** when the *last closed* bar's close (`close[1]`, series indexing)
  enters `[obLow, obHigh]` (:189-202). Close-based, intra-bar touches do not mitigate.
- **Invalidation:** when `TrendState` opposes the OB direction AND the OB is not yet
  mitigated (:205-219). A **mitigated OB is never invalidated** (:205 gate).
- **No time expiry:** an OB remains active indefinitely until mitigated or
  invalidated — a stale OB formed 200 bars ago can anchor a signal today (5.5: corpus
  norm is 50-100 bar expiry).
- Note the asymmetry with the liquidity detector (18.4 §6.7): liquidity invalidation
  is by opposing BOS; OB invalidation is by opposing trend state. The two lifecycle
  definitions are independent conventions.

### 6.5 Confluence / telemetry integration

- `hasOrderBlock` (ConfluenceEngine.mqh:319-321) = rule-family proxy
  (`RULE_BOS_OB_*` OR `RULE_OB_FVG_*` OR `RULE_CHOCH_OB_REVERSAL`) — same proxy
  pattern as `hasLiquiditySweep` (18.4 §6.9). The dataset's OB flag means "an
  OB-paired rule fired," not "an unmitigated OB zone exists."
- `sig.orderBlockId` = first evidence id (`:337`) — the OB zone itself is never
  serialized (no zone distance, no age).
- **Signal expiry** (:398-419): OB-anchored signals expire when the referenced OB is
  mitigated (`EXPIRY_OB_MITIGATED`), invalidated, or no longer found
  (`EXPIRY_OB_INVALIDATED`). This is the only dynamic lifecycle link from the OB
  detector into the decision layer.
- `hasProtectedPoint` is hardcoded `false` (:323) — the PP flag can never be true in
  the dataset (18.1 §7.3 finding explained: it is not computed at all, not merely
  unmeasured).

### 6.6 Phase 6 summary — implementation characteristics

| Aspect | Implementation | Gap vs doctrine / survey |
|---|---|---|
| Trigger | CHOCH events only | no displacement-triggered OBs; full dependency on trend classifier |
| Selection | first opposite candle ≤500 bars before CHOCH | no displacement requirement; 500-bar window far beyond norm (5.3) |
| Zone | [open-close] body | wick range unused (stop placement convention) |
| Quality | qualityScore constant 1.0 | no ranking (5.4) |
| Mitigation | last closed bar's close inside zone | touch-based alternatives exist in corpus |
| Invalidation | opposing TrendState; only if unmitigated | no time expiry; stale OBs persist |
| Telemetry | hasOrderBlock = rule-family proxy; OB id only | zone distance/age/state never in CSV |

---

## 7. Sprint 17 Evidence Review — Measured Only

### 7.1 Scope and method

Same frozen dataset (19 merged CSVs, 18,686 rows, fingerprint
`2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`; provenance in
01_Swing_Detection.md §7.1). Decided+signal rows only (n=17,073). Fresh query script
`sprint18_5_ob.py`; every table below re-verified by hand.

### 7.2 The OB flag overall (proxy caveat: it means "OB-paired rule fired")

| hasOrderBlock | n | Win rate |
|---|---|---|
| '1' (FALSE) | 3,553 | 0.2967 |
| '2' (TRUE) | 13,520 | 0.3414 |

- OB-paired decisions outperform the non-OB family by **4.5pp**. But the FALSE set is
  *exactly* the LIQUIDITY_BOS family (rule x flag cross-tab below) — the comparison
  is family-vs-family, not "OB present vs absent" in a controlled sense.

**Rule x flag cross-tab (exclusivity):**

| ruleName | hasOrderBlock=1 | hasOrderBlock=2 |
|---|---|---|
| BOS_OB_BEARISH | 0 | 418 |
| BOS_OB_BULLISH | 0 | 440 |
| CHOCH_OB_REVERSAL | 0 | 342 |
| OB_FVG_BEARISH | 0 | 5,908 |
| OB_FVG_BULLISH | 0 | 6,412 |
| LIQUIDITY_BOS_* | 3,553 | 0 |

- OB-paired rules never co-occur with liquidity rules (layerLiquidity=0 on every
  OB-family row; confirmed in 18.4 §7.7). The OB and the sweep are **mutually
  exclusive evidence** in the fired-rule layer — the two most important structure
  events are never combined in a single decision.

### 7.3 Cross-tabs with the other flags

**hasOrderBlock x hasBOS:**

| OB | BOS | n | Win rate | Identity |
|---|---|---|---|---|
| TRUE | FALSE | 12,662 | 0.3393 | OB_FVG + CHOCH families |
| TRUE | TRUE | 858 | 0.3730 | **BOS_OB family — best cell in dataset** |
| FALSE | TRUE | 3,553 | 0.2967 | LIQUIDITY_BOS |

**hasOrderBlock x hasCHOCH:**

| OB | CHOCH | n | Win rate |
|---|---|---|---|
| TRUE | FALSE | 13,178 | 0.3410 |
| TRUE | TRUE | 342 | 0.3567 |
| FALSE | FALSE | 3,553 | 0.2967 |

**hasOrderBlock x hasFVG:**

| OB | FVG | n | Win rate | Identity |
|---|---|---|---|---|
| TRUE | TRUE | 12,320 | 0.3388 | OB_FVG family |
| TRUE | FALSE | 1,200 | 0.3683 | BOS_OB (858) + CHOCH_OB (342) |

- **BOS + OB is the strongest structural combination in the dataset (0.3730, n=858)**;
  OB without BOS but with FVG (0.3388) is close to baseline; OB paired with CHOCH
  reversal (0.3567) outperforms OB+FVG. The ordering of OB pairings:
  **OB+BOS (0.3730) > OB+CHOCH (0.3567) > OB+FVG (0.3388) > OB+SWEEP** (never
  combined; sweep *replaces* OB at 0.2967).

**hasOrderBlock x trendAligned:**

| OB | trendAligned | n | Win rate |
|---|---|---|---|
| TRUE | TRUE | 3,920 | 0.3528 |
| TRUE | FALSE | 9,600 | 0.3368 |
| FALSE | TRUE | 375 | 0.2453 |
| FALSE | FALSE | 3,178 | 0.3027 |

- **trendAligned helps the OB family (+1.6pp) and hurts the sweep family (−5.7pp)** —
  the exact inverse of 18.4 §7.5. The trend gate is family-conditional: useful with
  OB evidence, harmful with sweep evidence. (Note the mirror-symmetric n: 3,920/9,600
  vs 375/3,178 — same split as 18.4, as expected from the flag complementarity.)

### 7.4 The layer system — fully decoded (major finding)

`layerStructural` x rule family (all rows, exact):

| ruleName | layerStructural | layerTotal values | confidence values |
|---|---|---|---|
| LIQUIDITY_BOS_* | 15 (BOS only) | 55 / 60 | 0.55 / 0.60 |
| OB_FVG_* | 25 (OB + FVG) | 35 / 40 | 0.35 / 0.40 |
| BOS_OB_* | 30 (BOS + OB) | 40 / 45 | 0.40 / 0.45 |
| CHOCH_OB_REVERSAL | 35 (CHOCH + OB) | 45 / 50 | 0.45 / 0.50 |

Decoded additive layer weights:

- BOS evidence = 15; OB = 15; FVG = 10; CHOCH = 20; liquidity = 30; trendAligned = +5.
- **`confidence ≡ layerTotal / 100` exactly** (0.35↔35, 0.40↔40, 0.45↔45, 0.50↔50,
  0.55↔55, 0.60↔60 — every rule family, every row, verified by raw value counts).
  The confidence reported to the decision layer is a **deterministic transform of the
  layer total with zero independent information**.
- **Consequence for 18.8/18.13:** the entire score/confidence machinery is a linear
  point-add scheme whose output is collinear with the family identity. The measured
  best-performing family (BOS_OB, 0.3730) is assigned the *middle* confidence (0.45);
  the worst family (LIQUIDITY_BOS, 0.2967) is assigned the *highest* (0.60). There is
  no family-conditional calibration anywhere in the pipeline.

### 7.5 OB-family rules by symbol/TF

| Rule | Symbol | TF | n | Win rate |
|---|---|---|---|---|
| BOS_OB_BEARISH | EURUSD | M15 | 285 | 0.3509 |
| BOS_OB_BEARISH | EURUSD | H1 | 80 | 0.4750 |
| BOS_OB_BEARISH | GBPJPY | H1 | 53 | 0.3585 |
| BOS_OB_BULLISH | EURUSD | M15 | 285 | 0.3263 |
| BOS_OB_BULLISH | EURUSD | H1 | 43 | 0.4651 |
| BOS_OB_BULLISH | GBPJPY | H1 | 112 | 0.4464 |
| CHOCH_OB_REVERSAL | EURUSD | M15 | 229 | 0.3100 |
| CHOCH_OB_REVERSAL | EURUSD | H1 | 50 | 0.3400 |
| CHOCH_OB_REVERSAL | GBPJPY | H1 | 63 | 0.5397 |

- **BOS_OB is a higher-timeframe phenomenon:** EURUSD_H1 0.4750/0.4651 and GBPJPY_H1
  0.4464 vs EURUSD_M15 0.3509/0.3263 (+9 to +12pp on H1). The best OB cell is
  CHOCH_OB_REVERSAL GBPJPY_H1 at **0.5397 (n=63)** — the single best cell measured in
  any sprint so far (18.3 §7.4 found the same cell).
- The OB-family H1 advantage mirrors the CHOCH H1 advantage (18.3) — the structure
  layers are systematically stronger on H1, weaker on M15.

### 7.6 Confidence composition per family

| Family | confidence values (raw counts) |
|---|---|
| BOS_OB_BULLISH | 0.45 (310) / 0.40 (130) |
| BOS_OB_BEARISH | 0.45 (280) / 0.40 (138) |
| CHOCH_OB_REVERSAL | 0.45 (266) / 0.50 (76) |
| LIQUIDITY_BOS_* | 0.60 (3,178) / 0.55 (375) |

- Every family has exactly two confidence values separated by 0.05 — the trendAligned
  delta. Confidence grades **nothing about the OB itself** (no zone distance, age,
  quality, or proximity inputs exist).

### 7.7 What the dataset cannot measure (explicit)

1. **Zone distance at decision time:** how far price was from the OB zone when the
   rule fired — the single most important entry variable in OB doctrine (3.1) —
   is not in the schema (only an OB *id*).
2. **OB age:** bars since formation, staleness — not recorded.
3. **OB state:** mitigated vs unmitigated at decision time — not recorded (expiry
   logic exists in-engine, ConfluenceEngine.mqh:398-419, but state is not serialized).
4. **Candle quality:** OB candle range, displacement size of the impulse leg, volume —
   not recorded (detector computes none of these anyway, §6.3).
5. **Zone geometry:** body-only vs full-range usage — not recorded.
6. **The displacement question:** whether the CHOCH that minted the OB was a
   displacement move or a drift — unmeasurable without the CHOCH event's bar data
   (same gap as 18.3 §7.5).

### 7.8 Phase 7 synthesis

1. **OB evidence is the strongest single layer in the dataset when paired with BOS
   (0.3730, n=858) and with CHOCH reversal (0.3567) — and BOS_OB is a H1 story
   (0.47+ on EURUSD_H1).**
2. **OB and sweep are never combined;** the sweep *replaces* the OB and loses 7.6pp
   (18.4). The next experiment set (E1-E3 below) should test OB+sweep coexistence.
3. **trendAligned is family-conditional** (+1.6pp with OB, −5.7pp with sweep) — a
   direct 18.8 input.
4. **Confidence is layerTotal/100 with no independent information and is
   anti-calibrated across families** (worst family → highest confidence) — the
   single most important schema finding for 18.8/18.13.
5. **Unmeasurable entry variables** (zone distance, age, state) mean the current
   dataset cannot test the OB doctrine's core entry claim — the biggest telemetry
   gap in the structure layer.

---

## 8. Experiment Backlog — Sprint 19 Candidates

| ID | Experiment | Evidence | Conf | Priority |
|---|---|---|---|---|
| E1 | **OB+sweep coexistence test:** allow OB evidence alongside the sweep in the same decision (today they are exclusive by construction); measure the combined family vs each alone | II (18.4 §7.3/7.4 measured negative sweep-alone; doctrine 3.1 sweep-then-OB entry) | B | P1 |
| E2 | **Zone distance & age telemetry (schema v4):** serialize OB distance to price, OB age, and mitigated state at decision time — the doctrine's core entry variables (7.7) | n/a (internal instrumentation; extends 18.2 E4) | A | P1 |
| E3 | **Displacement filter on OB minting:** require the CHOCH-triggering leg (or the OB candle) to exceed ATR-based displacement before an OB exists (merges with 18.2 E1 / 18.4 E3) | II (doctrine majority 3.1/5.2) | B | P1 |
| E4 | **Time expiry for OBs:** expire unmitigated OBs after N bars (50-100; corpus norm 5.5) instead of persisting until trend flip | III (corpus 5.5 + code review 6.4) | C | P2 |
| E5 | **OB quality grading:** replace constant qualityScore=1.0 with OB candle range/body ratio + displacement size (VSA lineage 3.3) | III | C | P2 |
| E6 | **Multi-candle OB zones:** test multi-candle zones vs single-candle [open-close] (corpus divergence 5.3) with stop on full range | III | C | P2 |
| E7 | **Confidence decoupling from layerTotal:** confidence must carry family-conditional calibration (BOS_OB 0.45 vs LIQUIDITY_BOS 0.60 is inverted vs measured win rates) — owned by 18.8; tracked here as the OB-family reference case | I (7.4 measured, all families) | A | P1 |
| E8 | **H1 structural-layer study:** why BOS_OB/CHOCH perform at 0.47+/0.54 on H1 vs ~0.33 on M15; session/volatility decomposition (links to 18.12) | III (7.5 measured) | C | P2 |

**Priority recommendation:** E7 (confidence) is the highest-leverage fix in the whole
program so far (mis-assigns risk at every decision). E1-E3 are the OB-specific
Sprint 19 cluster; E2 must precede any further structure-layer experiments because
zone distance/age are unmeasurable today. E4-E6, E8 are research-stage.

---

## References (consolidated)

### Academic
1. Kavajecz, K. & Odders-White, E. (2004). "Technical Analysis and Liquidity
   Provision." *Review of Financial Studies* 17(1), 65-104.
2. Anand, A., Chakravarty, S. & Martell, T. (2005). "Empirical Evidence on the
   Evolution of Liquidity: Choice of Market versus Limit Orders by Informed and
   Uninformed Traders." *Journal of Financial Markets* 8(3), 289-309.
3. Biais, B., Hillion, P. & Spatt, C. (1995). "An Empirical Analysis of the Limit
   Order Book and the Order Flow in the Paris Bourse." *Journal of Finance* 50(5),
   1655-1689.
4. Osler, C. (2002/2005). "Stop-Loss Orders and Price Cascades in Currency Markets."
   FRBNY Staff Report 150; *Journal of International Money and Finance* 24(2), 2005.
5. Bouchaud, J.-P., Farmer, J.D. & Lillo, F. (2009). "How Markets Slowly Digest
   Changes in Supply and Demand." In *Handbook of Financial Markets*, Elsevier
   (limit-order depth and flow mechanics).
6. Harris, L. (2003). *Trading and Exchanges: Market Microstructure for
   Practitioners.* Oxford University Press (hidden/iceberg order mechanics).

### Professional / practitioner
7. ICT (Inner Circle Trader) order block doctrine: last opposing candle before
   displacement, mitigation entry, OB+FVG confluence, freshness (secondary sources
   surveyed in this sprint; SMC corpus).
8. Wyckoff methodology: accumulation ranges and the "spring" as the professional-TA
   ancestor of sweep-and-reclaim at range edges.
9. Volume Spread Analysis (Tom Williams lineage): wide-spread/high-volume bar
   signatures as the professional validation of OB-candle quality.
10. VSA / order-flow practitioner literature on hidden liquidity and iceberg probing
    (mechanism background for 4.2).

### Open-source / implementations
11. Open-source SMC OB implementations (TradingView indicator corpus, MQL5 codebase
    articles, suites surveyed in 18.2-18.4): trigger choice, candle selection windows,
    zone geometry, lifecycle conventions.

### Internal
12. `Structure/OrderBlockDetector.mqh` (383 lines) — Phase 6 code review.
13. `Utils/Types.mqh` — `struct OrderBlock` (lines 69-83).
14. `Portfolio/SymbolContext.mqh` — wiring and update order (lines 326-331, 374, 390,
    418, 674, 692-693, 898-900).
15. `Confluence/ConfluenceEngine.mqh` — hasOrderBlock proxy (lines 319-321), signal
    expiry (lines 398-419).
16. `Confluence/ConfluenceRules.mqh` — OB-paired rule layer (surveyed for trigger
    conditions; detailed in 18.7).
17. `docs/Sprint18_Research/00_Program_Overview.md` — methodology.
18. `docs/Sprint18_Research/01_Swing_Detection.md` — dataset provenance and layer
    observations (§7).
19. `docs/Sprint18_Research/02_BOS_Research.md` — BOS_OB family evidence and the
    corrected BOS x sweep cross-tab (§7).
20. `docs/Sprint18_Research/03_CHOCH_MSS.md` — CHOCH trigger chain and GBPJPY_H1
    differential (§7).
21. `docs/Sprint18_Research/04_Liquidity.md` — sweep family evidence and the OB-vs-
    sweep exclusivity finding (§7).
22. Sprint 17 merged evidence dataset (fingerprint
    `2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`) and query
    script `sprint18_5_ob.py`.
