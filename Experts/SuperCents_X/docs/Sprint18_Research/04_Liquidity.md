# Sprint 18.4 — Liquidity Deep Research Review

**Document:** 04_Liquidity.md
**Series:** Sprint 18 — Deep Research Program (research only; no production code changes)
**Status:** Complete
**Supersedes / complements:** 01_Swing_Detection.md (pivot source), 02_BOS_Research.md (external-level source and BOS x sweep interaction), 03_CHOCH_MSS.md (sweep prerequisite question)
**Methodology:** Mandatory 8-phase structure defined in 00_Program_Overview.md; phases 1-5 never reference SuperCents_X.

---

## 1. Foundation — What "Liquidity" Means in Smart Money Concepts

### 1.1 The core claim

Smart Money Concepts (SMC) rests on a simple microstructure proposition: **the market is
an order-flow auction where the largest participants place resting orders in identifiable
locations, and price is deliberately driven through those locations to trigger the
stop-loss orders that rest beyond them.** The locations are called *liquidity pools*
(or "liquidity clusters"), and the act of driving price through them to trigger the
resting stop orders is called a *liquidity sweep* (often "stop hunt" in classic
terminology).

The institutional narrative:

1. Retail traders place stop-loss orders at predictable locations: **beyond swing
   highs/lows** (conservative stop placement), **at equal highs/lows** (range edges),
   and **at round numbers**.
2. Large participants (banks, funds, prop desks) know where those stops rest because
   the locations are technical and therefore statistically concentrated.
3. Price is pushed into those stops to:
   - obtain the *fill side* of the triggered orders (the stops become a source of
     orders that execute against the initiator), and
   - secure better average entry prices for the initiator's own accumulated position.
4. Once the sweep is complete, the price *returns* to the origin zone ("reclaim",
   "mitigation", "displacement follow-through") and the real directional move begins.

### 1.2 The vocabulary (important: definitions vary across schools)

| Term | Most common SMC meaning | Notes / variants |
|---|---|---|
| **Liquidity pool** | A price zone where resting stop orders are statistically concentrated | equal highs/lows, external (old) highs/lows, trendline junctions, round numbers |
| **Buyside liquidity (BSL)** | Stops resting ABOVE price (buy stops of shorts, buy stops entered as breakouts) | typically: equal highs, external highs, recent highs |
| **Sellside liquidity (SSL)** | Stops resting BELOW price | equal lows, external lows, recent lows |
| **Sweep** | Price wicks through a level to trigger the resting stops, then reverses | many schools additionally require a **close back inside** the level, a **displacement** impulse, or a subsequent **MSS/CHoCH** to validate the sweep as a reversal signal |
| **Grab** | A minor probe through a level with **no** follow-through (no displacement, no MSS) | per liquidityscan.io: a grab is noise; a sweep is a *confirmed* reversal event |
| **Mitigation / reclaim** | Price trades back INTO the swept zone after the sweep | some schools distinguish "reclaim" (close back inside) from "mitigation" (any touch back inside) |
| **Displacement** | A high-momentum, wide-range, low-wick impulse candle | the mechanism by which a sweep "escapes" the swept zone |
| **External vs internal** | External = levels outside the current dealing range (old highs/lows); internal = levels inside it | differs from the equal-high/low split |

### 1.3 The falsifiable core

The SMC liquidity narrative is falsifiable in two independent directions:

1. **Do stops actually cluster at technical levels?** — This is a *measurable
   microstructure* question answered by order-flow research (Phase 2: Osler 2002).
2. **Does sweeping those levels predict reversal (or continuation)?** — This is a
   *backtestable* question, partially answered by the Sprint 17 dataset (Phase 7).

The SuperCents_X implementation's sweep semantics are defined in Phase 6 and their
measured performance in Phase 7. The central finding of this review: **the detector
implements the weakest possible sweep definition (any touch beyond a level, evaluated
on the forming bar, with no reclaim, no displacement, no time window), and the Sprint 17
evidence shows that decisions built on that sweep definition underperform every other
rule family.**

---

## 2. Academic Literature — The Underlying Phenomenon Under Different Terminology

### 2.1 Osler (2002/2005): stop-loss orders and price cascades

The single most relevant academic anchor is **Carol Osler's study of foreign-exchange
stop-loss orders**:

- **Source:** "Stop-Loss Orders and Price Cascades in Currency Markets" — Federal
  Reserve Bank of New York Staff Report No. 150 (2002); journal version in *Journal of
  International Money and Finance* 24(2), 2005.
- **Data:** a unique dataset of **9,655 customer orders with a face value of about
  $55 billion** placed through the Royal Bank of Scotland's foreign-exchange trading
  desk between August 1999 and April 2000.
- **Key findings (as reported in the paper):**
  - Stop-loss orders make up a large share of the order flow: **about 43% of customer
    orders by volume were stop-loss orders**.
  - **Stops cluster at technical price levels**, most prominently at round numbers
    (roughly 10% of stop-loss orders sit at prices ending in "00"); clustering is also
    visible at recent extremes and technical indicators.
  - **Stop-loss clustering produces price cascades**: when price reaches a cluster of
    stops, the triggered orders accelerate price through the level — the paper documents
    statistically significant rapid-trend episodes of hours' duration that coincide with
    stop-loss clusters.
  - The market lore of "running the stops" is supported: dealers know where stops sit
    and price moves toward them; stops *propagate* trends rather than merely truncating
    them.
  - **Asymmetry:** the price response at stop-loss clusters is larger and longer-lived
    than at take-profit clusters.

Implications for the sweep hypothesis:

- The premise (stops rest at technical levels) is **empirically confirmed** on real
  dealer order flow. This is the strongest support the sweep idea has.
- The *outcome* of a stop run is a **cascade through the level**, i.e., Osler documents
  the mechanism that produces sweeps and breakouts. Whether price subsequently *reclaims*
  the level (reversal) or *continues* (breakout) is the branch that SMC doctrine
  privileges and that the Sprint 17 dataset measures.

### 2.2 Kavajecz & Odders-White (2004): technical levels attract limit-order depth

- **Source:** Kavajecz, K. & Odders-White, E. (2004), "Technical Analysis and Liquidity
  Provision," *Review of Financial Studies* 17(1), 65-104.
- **Method:** maps technical analysis signals (moving-average and support/resistance
  rules) onto the limit-order book of NYSE specialist firms.
- **Finding:** the price levels identified by technical indicators coincide with
  **concentrations of limit-order depth** — liquidity provision accumulates at
  technical levels.
- **Implication:** support/resistance and swing-extreme levels are where the book is
  deepest; sweeping through those levels engages the largest standing supply/demand.
  This provides the *continuation* mechanism for the "run through liquidity" half of the
  doctrine (as opposed to the reversal half).

### 2.3 Stop-loss rules in academic portfolio work: Kaminski & Lo (2014)

- **Source:** Kaminski, K. & Lo, A. (2014), "When Do Stop-Loss Rules Stop Losses?,"
  *Journal of Financial Markets* 23, 1-31 (working paper 2007).
- **Question:** do stop-loss rules improve returns *in general*, or only in specific
  return regimes?
- **Finding:** stop-loss rules are **not universally beneficial**; they help in regimes
  with positive serial correlation / momentum (where the stop truncates drawdowns that
  would otherwise persist) and hurt in mean-reverting regimes (where stops lock in
  losses at the worst point). Related work by Lei & Li (2009) shows stop-loss rules
  combined with momentum strategies produce the documented improvement.
- **Implication for sweep detection:** a "stop-run then reversal" model implicitly bets
  on *reversion after the sweep*; a "stop-run then continuation" model bets on
  *momentum*. The measured data (Phase 7) can distinguish which regime the sweep-first
  rule family operated in.

### 2.4 Market-microstructure foundations (order flow)

- **Bouchaud, Farmer & Lillo (2002-2009), "How Markets Slowly Digest Changes in Supply
  and Demand"** (chapter in *Handbook of Financial Markets*, Elsevier, 2009): order
  flow is strongly autocorrelated; price impact is concave and persistent; the
  meta-order decomposition shows large orders are executed by slicing through the book —
  the mechanism by which a large participant's accumulation becomes visible as repeated
  probes of a level.
- Implication: persistent order flow autocorrelation is what makes "testing" a level
  with repeated touches (sweep/grab behavior) a natural signature of large-participant
  activity — but also makes *false* sweeps (grabs) common, since any large order sliced
  across many ticks probes nearby levels.

### 2.5 The honest summary of the academic layer

| Question | Academic verdict | Strength |
|---|---|---|
| Do stops cluster at technical levels? | Yes (Osler 2002, dealer order flow) | I |
| Do stop clusters create rapid price cascades? | Yes, hours-long, statistically significant (Osler 2002) | I |
| Do sweeps predict reversal? | Not directly studied; indirect evidence mixed (Kaminski & Lo: regime-dependent) | II-III |
| Do technical levels attract book depth? | Yes (Kavajecz & Odders-White 2004) | II |
| Is a "touch beyond" a reliable signal? | No — false probes are common (order-flow slicing) | II |

The academic layer validates the *phenomenon* (stop runs are real) and is **silent or
cautious on the reversal claim** that SMC attaches to it.

---

## 3. Professional Trading Literature — Practitioner Doctrine

### 3.1 ICT and the sweep doctrine

The liquidity sweep is central to ICT (Inner Circle Trader, Michael Huddleston):

- **Draw on liquidity:** price is described as moving "to draw on" liquidity above
  (buyside) and below (sellside) before reversing. The draw typically precedes
  displacement and the subsequent market structure shift.
- **Sweep composition:** a valid sweep usually = wick through the level + **close back
  inside** the level + displacement in the opposite direction + a subsequent
  **MSS/CHoCH** confirmation. The order of events is taught as:
  `sweep → displacement → market structure shift → entry at retracement`.
- **Equal highs/lows:** clustered equal swing points are presented as the most
  reliable pool types because stop placement beyond the cluster edge is uniform.
- **External vs internal liquidity:** old highs/lows outside the current range are
  described as "external" liquidity; the doctrine says price often sweeps *both*
  external and internal liquidity on the way to a reversal.
- **Multiple-sweep / liquidity-raid language:** some versions of the doctrine describe
  the same level being swept more than once before the "real" reversal (double sweep,
  "wicked wick").

Key doctrinal point for Phase 6 comparison: **ICT's canonical sweep requires the
close-back-inside (reclaim); a wick beyond the level without reclaim is a "grab" or
noise.** The SuperCents_X detector implements the touch-only variant (Phase 6).

### 3.2 The sweep-vs-grab distinction (liquidityscan.io doctrine)

- **Source:** liquidityscan.io (2026) distinguishes:
  - **Grab:** price briefly pokes beyond a level and immediately resumes the prior
    direction. No displacement, no MSS follow-through. Interpretation: noise or a
    small-participant stop-out, NOT institutional order flow.
  - **Sweep:** price exceeds the level AND the move is confirmed by displacement and a
    market structure shift (MSS) in the opposite direction. Only then is the pool
    considered "taken."
- The practical test taught: *"did displacement and MSS follow the wick?"* — if yes,
  the pool was taken; if no, the pool is still live and the wick is noise.
- **Implication:** the *consequence* of the sweep (structure shift) is part of the
  definition, not a separate confirmation. This is the strongest practitioner
  counterweight to touch-only detectors.

### 3.3 Mitigation and the return-to-origin

- **Mitigation (also called "reclaim," "return to origin," "back to the sweep zone"):**
  after the sweep, price trading back INTO the swept zone is where the institutional
  entry is taught to occur (with the order block behind the level or the FVG of the
  displacement leg as the refined entry zone).
- **Disagreement between schools** (parallel to the 18.3 CHoCH/MSS ordering issue):
  - strict schools require a **candle close** back inside the zone;
  - looser schools accept any touch back inside;
  - some require mitigation to occur within 1-3 candles of the sweep, others impose no
    time limit.
- **Time window matters:** practitioner literature overwhelmingly treats a pool as
  "old" after a few candles; a sweep that is only mitigated many bars later is not a
  fresh reversal event. The SuperCents_X detector imposes **no time window** (Phase 6).

### 3.4 The breakout counter-doctrine

- Classic breakout trading (Donchian/Turtle lineage, per 18.2 Phase 3) treats the same
  event — price through the level — as a *continuation* signal, not a reversal signal.
- SMC's reversal reading of sweeps is therefore a specific *interpretation* of the
  event, not a consensus one; both interpretations are traded professionally and
  neither can be privileged without measurement. The Phase 7 data measures the SMC
  interpretation as implemented.

### 3.5 Practitioner checklist (consolidated validation criteria for a "real" sweep)

Across surveyed doctrine (ICT-aligned sources; liquidityscan.io; 18.3 sources), a
validated sweep typically requires, in decreasing order of agreement:

1. Wick beyond the level (all schools).
2. Close back inside the level / reclaim (most schools; strict).
3. Displacement in the opposite direction (most schools).
4. MSS/CHoCH within a few bars (most schools; 18.3 E1).
5. Time window for the whole event (common but variable).
6. Volume/participation confirmation (minority).

---

## 4. Institutional / Quantitative Practice

### 4.1 Stop-running as institutional practice

- Osler's dealer-order-flow work (2.1) documents that **professionals know where stops
  sit and trade toward them**. Her dataset shows clustered stop placement at round
  numbers and technical levels — the *raw material* for sweep behavior.
- The FX dealer interviews in the Osler studies describe the "running stops" strategy
  as routine: dealers infer stop clusters from the book and client flow, and price is
  deliberately pushed toward them.
- **Caveat from the same literature:** the direction of the resulting cascade is not
  predetermined. The stop-run either exhausts the cluster (reversal) or attracts new
  momentum participation (breakout). The decision between the two readings is where
  SMC doctrine and classic breakout doctrine split (3.4).

### 4.2 Predatory trading literature

- **Brunnermeier & Pedersen (2005), "Predatory Trading," Journal of Finance 60(4):**
  when a large trader must liquidate, informed traders front-run the liquidation by
  selling ahead of it; the price is pushed through the level and the predator profits
  from the forced flow. This is the academic formalization of "hunting" resting orders.
- Implication: sweeps are *predation events* — the victim is the crowd resting stops;
  the predator needs the crowd to be at predictable levels (technical levels per
  Osler/Kavajecz-Odders-White) and needs the pool to be *large enough* to matter.
  Pool size (cluster member count, distance of external level) is therefore a
  candidate quality signal.

### 4.3 HFT and liquidity-detection algorithms

- Modern market making and HFT firms run **liquidity-detection logic**: probing just
  beyond visible levels to observe whether hidden liquidity exists there (the
  "iceberg detection" family). These probes create exactly the "wick through the
  level" pattern the detector keys on — and they are *intentionally not* reversal
  signals.
- Implication: a pure touch-detector will classify HFT probe behavior as "sweeps."
  Displacement and structure confirmation (Phase 3 checklist) exist precisely to filter
  this class of noise.

### 4.4 Kill zones and time-dependence in professional FX flow

- Institutional FX flow is concentrated in London/NY overlap sessions (8-12 ET) and the
  Asia open; dealer desks report that stop runs concentrate in these windows.
- Implication: sweep *timing* (session, and distance since level formation) is a
  candidate quality feature that neither the detector nor the schema currently records
  (Phase 6/7; 18.12 Regimes & News).

---

## 5. Open-Source Implementations — Common Design Choices

### 5.1 Survey scope

Representative survey of open-source SMC liquidity implementations (TradingView
indicators, MQL5 codebase articles, GitHub SMC suites seen in 18.2/18.3 survey). The
patterns below reflect the *dominant* choices, not an exhaustive census.

### 5.2 Level construction

| Design choice | Dominant pattern in open source | SuperCents_X (Phase 6) |
|---|---|---|
| Level types | equal highs/lows; external old highs/lows; internal recent highs/lows; trendline/structural junctions | EQH/EQL (3-pip tolerance) + EXTERNAL_HH/LL from BOS pivots; INTERNAL never created |
| Clustering | tolerance-based clustering of swing points, often with minimum 2 members | 2+ swing points within 3 pips, running average price |
| Level price | average of members, or the extreme member price, or the boundary | running average of members |
| Max levels | bounded (30-500 typical) | 256 |

### 5.3 Sweep definition — the big fork

Two dominant implementations exist in open source:

- **A. Touch-only** (minority; simpler): any wick beyond the level = sweep. Same bar
  close direction irrelevant. Common in early-generation indicators.
- **B. Reclaim-required** (majority; SMC-aligned): wick beyond + **close back inside**
  within N bars (N commonly 1-3; some use the same bar, others allow a few bars). Only
  then is the pool marked swept.

Additional filters seen in the majority camp:

- **Displacement requirement** (e.g., the wick bar or the reversal bar exceeds ATR*1.5
  or the FVG of the impulse leg): implemented in several MQL5 sweep detectors.
- **Time window** from level detection to sweep (commonly 50-100 bars) — a pool older
  than the window is discarded or downgraded.
- **MSS/CHoCH gate** after the sweep (18.3 E1 aligns with this camp).
- **Session/kill-zone filter** (minority; e.g., only NY/Asia windows).

### 5.4 Mitigation / reclaim semantics in open source

- Majority: mitigation = price trading back INTO the swept zone (touch), commonly with
  a **time limit** (within 1-5 bars of the sweep).
- Minority: mitigation requires a candle **close** inside the zone.
- The difference matters: touch-based mitigation fires on intra-bar wicks that close
  outside the zone — the same noise source identified in 5.3A.

### 5.5 Quality signals used in open source

- Distance penetrated beyond the level (in pips or ATR) — deeper = more meaningful
  in several implementations; others treat any penetration equally.
- Cluster member count (pool size) — used by several SMC suites to rank pools.
- Freshness: time since level detection or last touch.
- Multiple sweeps of the same pool (double-sweep setups) — some suites *require* or
  *discourage* them; no consensus.

---

## 6. Current SuperCents_X Implementation — Read-Only Code Review

### 6.1 Scope of review

Files reviewed for this sprint (read-only; no changes made):

- `Structure/LiquidityDetector.mqh` (866 lines) — level construction, sweep,
  mitigation, invalidation state machine.
- `Utils/Constants.mqh` — liquidity constants (`LIQUIDITY_EQH_TOLERANCE_PIPS` 3,
  `LIQUIDITY_EQL_TOLERANCE_PIPS` 3, `LIQUIDITY_MAX_LEVELS` 256; lines 91-93).
- `Confluence/Evaluators/LiquidityEvaluator.mqh` (120 lines) — score component.
- `Confluence/ConfluenceRules.mqh` — `RecentLiquiditySweep` rule-side helper
  (lines 149-184) and `CONFLUENCE_RECENT_BARS 10` / `EVIDENCE_FRESHNESS_THRESHOLD 20`
  (lines 15-17).
- `Confluence/ConfluenceEngine.mqh` — signal assembly and the telemetry flag
  (line 324).
- `Portfolio/SymbolContext.mqh` — wiring (lines 343-357, 388-393) and series-indexed
  buffer copies (lines 633-637).

### 6.2 Architecture and wiring

- `CSymbolContext::Initialize` (SymbolContext.mqh:347-357) creates `CLiquidityDetector`
  and injects `CSwingDetector` and `CBOSDetector` (the BOS detector is shared with
  FVGDetector:343). The confluence engine receives the detector
  (SymbolContext.mqh:388-393), which forwards it to `CTradeCandidateBuilder`,
  `CExecutionPlanner`, and the evaluator (ConfluenceEngine.mqh:675-712).
- The engine exposes it via `CEngine::GetLiquidityDetector` (Core/Engine.mqh:56,
  264-268).
- Bar arrays passed to `Update` are the context's series-indexed copies
  (SymbolContext.mqh:633-637), so `high[0]`/`low[0]` inside the detector is the
  **current forming bar**. This is the series-indexing assumption the detector relies
  on (LiquidityDetector.mqh:410-412).

### 6.3 Level construction

**Equal-high/equal-low clusters** (`DetectEQH`, LiquidityDetector.mqh:145-250;
`DetectEQL`, :252-354):

- Tolerance = 3 pips (`LIQUIDITY_EQH_TOLERANCE_PIPS`/`_EQL_TOLERANCE_PIPS`, Constants
  :91-92) plus half a point epsilon (:154-155).
- A new swing point first tries to **extend an existing ACTIVE cluster** within
  tolerance (:166-183) — the cluster price is a running average weighted by member
  count (:171-173); then looks back **up to 100 swing points** for the first partner
  within tolerance (:187-219) and creates a new level at the midpoint of the two
  swing prices (:196-198).
- `FindMatchingEQH`/`FindMatchingEQL` (LiquidityDetector.mqh:706-736) only extend
  ACTIVE clusters (:714), so swept/mitigated/invalidated clusters are never extended.
- Max 256 levels (Constants:93).

**External levels** (`DetectExternal`, LiquidityDetector.mqh:356-402):

- Every bullish BOS event creates an `EXTERNAL_HH` level at the pivot price
  (:371-383); every bearish BOS creates `EXTERNAL_LL` (:385-397).
- Because the BOS detector breaks *both* swing types unconditionally (18.2 §6), the
  external levels inherit the BOS semantic ambiguity (with-trend vs counter-trend
  breaks both mint levels).
- **No dedup:** a second BOS at the same pivot price creates a duplicate external
  level (no price-proximity check against existing levels).

**Internal levels — dead code:** `LIQUIDITY_INTERNAL_HH/LL` exist in the type enum and
are classified as buy/sell-side in sweep and mitigation detection
(LiquidityDetector.mqh:421-426, 501-506), but **no creation path exists** — `CreateLevel`
is only ever called with EQH, EQL, EXTERNAL_HH, EXTERNAL_LL (:196, :301, :374, :388).
The internal branches and the Shutdown internal counters (:616-617) are unreachable.

**Classification field — dead weight:** every level is created with
`classification = LIQUIDITY_CLASS_UNKNOWN` (:753) and never updated; buy/sell side is
recomputed on the fly in each detect method (:421-426, :501-506, :573-576). The
classification counters in Shutdown (:626-627) always read zero.

### 6.4 Sweep detection semantics (`DetectSweeps`, :404-483)

- Evaluated on the **current forming bar** (`curHigh = high[0]`, `curLow = low[0]`,
  :410-412) — sweeps are recorded intra-bar, before the candle closes.
- **Sweep = any touch beyond the level price:** buy-side (EQH/EXTERNAL_HH/INTERNAL_HH)
  swept when `curHigh >= averagePrice` (:428); sell-side when `curLow <= averagePrice`
  (:433).
- **No reclaim requirement** (no close-back-inside check).
- **No displacement / volume / time-window requirement.**
- **No minimum penetration distance** — penetration depth is logged
  (`DISTANCE=%.1f`, :457-461) but does not affect the state transition.
- **One-shot:** `SweepLevel` only transitions ACTIVE -> SWEPT (:780-805); a repeated
  touch of an already-swept level is rejected and logged (:786-794). There is no
  double-sweep support.
- Sweep delay (bars from detection bar to sweep bar) is tracked (:441-447, summary
  :674-675).

**Semantic deviation vs doctrine:** the detector implements the *weakest* definition in
the survey (5.3A): touch-only, forming-bar, no reclaim, no displacement, no time
window. Per 3.1-3.3 and 5.3B, the majority and the SMC-canonical definition require
reclaim (close back inside) and usually displacement. **Consequence: a genuine
breakout (price staying beyond the level) is also labeled SWEPT** and stays SWEPT
until an opposing BOS invalidates it — the state machine cannot represent an
"accepted break."

### 6.5 Mitigation semantics (`DetectMitigations`, :485-539)

- Applies to SWEPT levels only (:497).
- Buy-side swept level mitigates when `curLow <= averagePrice` (price trades back INTO
  the level from above, :509-512); sell-side when `curHigh >= averagePrice` (:514-517).
- **Intra-bar touch, no close requirement, no time window** — a swept level can be
  mitigated many bars (or days) later.
- Because `DetectSweeps` runs before `DetectMitigations` in `Update` (:131-142), a
  single forming bar that wicks both sides can sweep AND mitigate a level in the same
  bar (swept at :428, then mitigated at :509 on the same high/low).
- The evaluator scores `mitigated` state as +5 (vs +20 for fresh) —
  LiquidityEvaluator.mqh:76-85.

### 6.6 Invalidation semantics (`DetectInvalidations`, :541-592)

- Only **SWEPT** levels can be invalidated (:570).
- **Seed guard:** on the very first `Update`, all BOS events existing at that moment
  are marked as seen without processing (:554-559). Only BOS events occurring *after*
  the detector's first update can invalidate levels — a correctness-preserving
  choice (avoids invalidating with pre-existing BOS), but it also means any opposing
  BOS that happened between the level's sweep and the detector's first update is
  ignored.
- **Global, not price-localized:** a bearish BOS invalidates *every* swept buy-side
  level regardless of where the BOS pivot price sits relative to the level
  (:581-587) — any bearish BOS anywhere on the chart kills all swept buy-side pools.
- **Internal levels are excluded** from invalidation (:573-576) — consistent with
  their never being created.
- Invalidation reason is fixed to `"OpposingBOS"` (:585).

### 6.7 Lifecycle summary

```
ACTIVE ──touch beyond──▶ SWEPT ──retrace into level──▶ MITIGATED
                         │
                         └──any opposing BOS──▶ INVALIDATED
```

- One-way transitions enforced by status guards in `SweepLevel`/`MitigateLevel`/
  `InvalidateLevel` (:780-864) with rejection logging.
- `Shutdown` prints a conservation check `active+swept+mitigated+invalidated ==
  levelCount` (:663-666) — good engineering hygiene.
- Timestamps/bars recorded for each transition (:797-800, :824-828, :853-858) —
  telemetry-ready, but only logged (6.9).

### 6.8 Confluence / rule-layer consumers

**`CLiquidityEvaluator`** (LiquidityEvaluator.mqh, score component):

- `FindRecentSweep` (:13-37): sweeps with `sweptTime >= iTime(_Symbol,_Period,10)`
  (10-bar recency, `LIQ_RECENT_BARS` :8); iterates newest levels first.
- Scoring: no recent sweep -> baseline **15** (:59-63); recent sweep -> base **60**
  (:73), +20 if **not mitigated** (fresh, :76-80), +20 if an **active protected point**
  exists in the same direction (`HasActivePP`, :39-47, :87-92); capped at 100 (:94).
- **Direction classification bug (evaluator):** `levelBullish` includes only
  `EQH` and `INTERNAL_HH` (:29) — **`EXTERNAL_HH` is missing**. A swept external HH
  level is therefore classified as *bearish* and would be scored as a bearish sweep.
  Compare `ConfluenceRules.mqh:172-174` (rule layer), which correctly includes
  `EXTERNAL_HH` — the two consumers disagree on direction classification.
- Given INTERNAL levels are never created (6.3), the evaluator effectively only ever
  matches EQH/EQL sweeps for the correct direction, and misfiles EXTERNAL_HH sweeps
  as bearish.

**Rule layer** (`RecentLiquiditySweep`, ConfluenceRules.mqh:149-184): same 10-bar
recency via `CONFLUENCE_RECENT_BARS` (:15, :168), correct EXTERNAL_HH handling (:172-174),
returns level id + mitigated state.

**Entry/exit consumers** (reviewed for completeness; detailed in 18.9/18.11):
`EntryPriceResolver`, `TargetResolver`, `StopLossResolver`, `ExecutionPlanner` all
receive the detector (Entry/*.mqh:6-13, ExecutionPlanner.mqh:10-11, :80-82) and can
reference swept levels for entries/targets/stops.

### 6.9 Telemetry gap — the flag is a rule-family proxy

- The CSV column `hasLiquiditySweep` is set in `ConfluenceEngine.mqh:324`:

  ```cpp
  sig.hasLiquiditySweep = (bestRule.type == RULE_LIQUIDITY_BOS_BULLISH ||
                           bestRule.type == RULE_LIQUIDITY_BOS_BEARISH);
  ```

- **The dataset's sweep flag therefore measures "the best rule was a LIQUIDITY_BOS
  rule," not "a sweep occurred."** Detector state (level id, sweep time, distance,
  delay, level type, pool size) never reaches the telemetry row; only the logged
  `LIQUIDITY-SWEEP`/`LIQUIDITY-MITIGATION` lines carry it (in-memory/log only, like
  18.2 E4 for BOS).
- Consequences for Phase 7: all sweep-related conclusions are *rule-family*
  conclusions; sweep-quality variables (distance, age, type, member count) are
  unmeasurable in the dataset. This is the single most important schema-level finding
  of this sprint (backlog E2).

### 6.10 Phase 6 summary — implementation characteristics

| Aspect | Implementation | Gap vs doctrine / survey |
|---|---|---|
| Sweep definition | touch beyond level, forming bar, one-shot | no reclaim, no displacement, no time window (5.3A weakest variant) |
| Level types | EQH/EQL 3-pip clusters; EXTERNAL_HH/LL from BOS | no INTERNAL levels (dead code); external duplicates possible |
| Mitigation | intra-bar retrace into level, no time limit | can fire weeks later; same-bar sweep+mitigate |
| Invalidation | any opposing BOS, global scope | not price-localized; seed guard hides early BOS |
| Recency | 10-bar filter in consumers | consumer-level only; detector stores no staleness |
| Direction classification | evaluator omits EXTERNAL_HH; rule layer includes it | consumer inconsistency (evaluator bug) |
| Telemetry | hasLiquiditySweep = rule-family proxy | detector state never in CSV (18.2 E4 same root cause) |
| Quality signals | none (penetration logged only) | pool size, distance, age, session all unused |

---

## 7. Sprint 17 Evidence Review — Measured Only

### 7.1 Scope and method

Same frozen dataset as 18.1-18.3: 19 merged CSVs, UTF-16, 68 columns, 18,686 rows,
fingerprint `2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`
(full provenance in 01_Swing_Detection.md §7.1). Tristate semantics: `'1'`=FALSE,
`'2'`=TRUE, `'0'`=UNKNOWN. All tables below use **decided+signal rows** (n=17,073):
outcome `'1'`=WIN, `'2'`=LOSS, `'3'`=BE. Win rate = WIN/(WIN+LOSS). Fresh query script
`sprint18_4_liquidity.py` / `sprint18_4_liquidity2.py` (outputs
`sprint18_4_liquidity.json`); numbers below re-verified by hand.

### 7.2 The sweep flag overall (reminder of the proxy caveat)

| hasLiquiditySweep | n | Win rate |
|---|---|---|
| '1' (FALSE) | 13,520 | 0.3414 |
| '2' (TRUE) | 3,553 | 0.2967 |

- Sweep-present decisions underperform the no-sweep baseline by **4.5pp**
  (confirms 01_Swing_Detection.md §7.3, −0.0448). Note this is the *rule-family*
  reading (6.9): the 3,553 TRUE rows are exactly the LIQUIDITY_BOS family (below).

### 7.3 Rule-family comparison — the sweep family is the worst performer

| Rule family | n | Win rate | BE rate | confidence mean / median |
|---|---|---|---|---|
| **LIQUIDITY_BOS (sweep-first)** | **3,553** | **0.2967** | 0.0000 | **0.595 / 0.600** |
| BOS_OB (break-first) | 858 | 0.3730 | 0.0012 | 0.434 / 0.450 |
| OB_FVG (baseline) | 12,320 | 0.3388 | 0.0003 | 0.386 / 0.400 |
| CHOCH_OB_REVERSAL | 342 | 0.3567 | 0.0000 | 0.461 / 0.450 |

- The sweep-first family is the **worst-performing family by 3.4pp** (vs OB_FVG) and
  **7.6pp** (vs BOS_OB) — yet it carries the **highest confidence values in the entire
  dataset** (0.55-0.60; the only family with a 0.60 mode). The confidence/layerTotal
  machinery is **mis-calibrated for this family**: layerTotal is 55 or 60 on every
  row while win rate is the lowest. This is a decisive input for 18.8 (confidence
  architecture) and 18.13 (calibration).
- Confidence composition (raw value counts): 0.60 on 3,178 rows, 0.55 on 375 rows —
  a **binary confidence**, i.e., no grading of the sweep itself.
- Layer composition (raw): `layerStructural=15` on all 3,553 rows (BOS evidence
  present, not OB), `layerLiquidity=30` on all rows, `layerTotal` 60 = 55+5 when
  `trendAligned` (3,178 rows) vs 55 when not (375 rows). Sweep rules *never* carry an
  order block (structural 15, not 30/35) — the sweep substitutes for the OB.
- No BE rows in the family: 1,054 WIN / 2,499 LOSS.

### 7.4 The corrected hasBOS x hasLiquiditySweep cross-tab

Re-verified with the fresh query; this **corrects** the cells originally published in
02_BOS_Research.md §7.3 (fix committed in `24bbace`):

| hasBOS | hasLiquiditySweep | n | Win rate | Identity |
|---|---|---|---|---|
| FALSE | FALSE | 12,662 | 0.3393 | OB_FVG + CHOCH_OB_REVERSAL rows |
| TRUE | FALSE | 858 | 0.3730 | BOS_OB family (440+418) |
| TRUE | TRUE | 3,553 | 0.2967 | LIQUIDITY_BOS family (1,853+1,700) |
| FALSE | TRUE | 0 | — | sweep never co-occurs with OB/FVG/CHOCH rules |

- **The best BOS context is BOS without a sweep (0.3730 = BOS_OB); the worst is BOS
  with a sweep (0.2967 = LIQUIDITY_BOS).** As implemented, replacing the OB with a
  sweep as the paired evidence *degrades* the decision by 7.6pp.
- Sweep TRUE rows occur **only** on LIQUIDITY_BOS rules: the sweep is never combined
  with an order block, an FVG, or a CHOCH in the fired-rule layer (rule exclusivity,
  same finding class as 18.3's BOS/CHOCH zero-overlap).
- The ICT "sweep-then-BOS" narrative is therefore **not supported** by the measured
  data under the current (touch-only) sweep semantics — consistent with the Phase 6
  finding that the detector labels any touch as a sweep.

### 7.5 Sweep flag x trendAligned — the gate is counter-productive for this family

| hasLiquiditySweep | trendAligned | n | Win rate |
|---|---|---|---|
| FALSE | TRUE | 3,920 | 0.3528 |
| FALSE | FALSE | 9,600 | 0.3368 |
| TRUE | TRUE | 375 | 0.2453 |
| TRUE | FALSE | 3,178 | 0.3027 |

- For the no-sweep rows, trend alignment adds ~1.6pp (as in 18.2's no-BOS cells).
- For the sweep rows, trend alignment **removes 5.7pp** (0.2453 vs 0.3027) — the same
  inversion measured for LIQUIDITY_BOS in 18.2 §7.2 (0.1796 at n=167 for
  LIQUIDITY_BOS_BULLISH aligned; refreshed numbers below). The `trendAligned` gate is
  an *anti-predictor* for the sweep family.

### 7.6 LIQUIDITY_BOS by rule, symbol and timeframe

| Rule | Symbol | TF | n | Win rate |
|---|---|---|---|---|
| LIQUIDITY_BOS_BULLISH | EURUSD | M15 | 1,124 | 0.2687 |
| LIQUIDITY_BOS_BULLISH | EURUSD | H1 | 384 | 0.2786 |
| LIQUIDITY_BOS_BULLISH | GBPJPY | H1 | 345 | 0.3304 |
| LIQUIDITY_BOS_BEARISH | EURUSD | M15 | 1,132 | 0.3136 |
| LIQUIDITY_BOS_BEARISH | EURUSD | H1 | 309 | 0.3107 |
| LIQUIDITY_BOS_BEARISH | GBPJPY | H1 | 259 | 0.3089 |

- Best cell: **GBPJPY_H1 bullish 0.3304 (n=345)**; worst: **EURUSD_M15 bullish
  0.2687 (n=1,124)** — a 6.2pp spread.
- **Directional asymmetry:** all three bearish cells sit at 0.309-0.314 while the two
  EURUSD bullish cells collapse to ~0.27. The bullish sweep story is only alive on
  GBPJPY_H1. (Compare 18.3's GBPJPY_H1 CHOCH differential — GBPJPY_H1 is the
  standout symbol/TF across both structure families.)
- Symbol/TF x trendAligned detail:

| Symbol | TF | trendAligned | n | Win rate |
|---|---|---|---|---|
| EURUSD | M15 | TRUE | 215 | 0.2558 |
| EURUSD | M15 | FALSE | 2,041 | 0.2950 |
| EURUSD | H1 | TRUE | 85 | 0.2000 |
| EURUSD | H1 | FALSE | 608 | 0.3059 |
| GBPJPY | H1 | TRUE | 75 | 0.2667 |
| GBPJPY | H1 | FALSE | 529 | 0.3289 |

- Every single trend-aligned cell is *worse* than its not-aligned counterpart, with
  EURUSD_H1 aligned at exactly 0.2000 (n=85).

### 7.7 layerLiquidity — binary and perfectly collinear with the rule family

| layerLiquidity | n | Win rate |
|---|---|---|
| 0 | 13,520 | 0.3414 |
| 30 | 3,553 | 0.2967 |

- `layerLiquidity` takes exactly two values (0/30) and is perfectly collinear with
  `hasLiquiditySweep` and the LIQUIDITY_BOS family (every 30-row is a LIQUIDITY_BOS
  decision). As a schema feature it carries **no information beyond the rule family
  itself**; this is the schema-level expression of the proxy problem (6.9).

### 7.8 hasProtectedPoint interaction — unmeasurable

- `hasProtectedPoint` is FALSE ('1') on **all** rows (n=17,073; same finding as
  18.1 §7.3). The evaluator's +20 "active PP" bonus
  (LiquidityEvaluator.mqh:87-92) can never be credited in the dataset; the PP/sweep
  interaction remains untested (18.1 backlog E3 remains open).

### 7.9 What the dataset cannot measure (explicit)

1. **Sweep quality:** penetration distance, displacement size, reclaim presence —
   none in schema; `hasLiquiditySweep` is a rule-family proxy (6.9).
2. **Sweep age/timing:** delay between level detection and sweep, time since sweep at
   decision, session/kill-zone — not recorded (detector logs only).
3. **Level attributes:** type (EQH vs external), cluster member count, mitigation
   window, invalidation timing — logged in `LIQUIDITY-*` lines, never in CSV.
4. **The grab-vs-sweep distinction** (3.2) is structurally unmeasurable: the dataset
   has no wick-plus-reclaim fields.
5. **Double-sweep behavior:** unsupported by the state machine (6.4), unmeasurable.
6. **Direction-confusion frequency:** how often EXTERNAL_HH levels were misfiled by
   the evaluator bug (6.8) is not countable from the CSV.

### 7.10 Phase 7 synthesis

1. **The sweep-family rule is the weakest family in the dataset** (0.2967, n=3,553)
   and its only differentiator from the baseline — the sweep event — is measured
   *negatively*.
2. **BOS + sweep is worse than BOS + OB by 7.6pp** (0.2967 vs 0.3730); sweep
   substitutes for the OB and the substitution loses.
3. **Trend alignment inverts** for the sweep family (−5.7pp overall; EURUSD_H1
   aligned 0.2000).
4. **Directional/symbol asymmetry:** bullish EURUSD sweep cells ~0.27 vs GBPJPY_H1
   bullish 0.3304; bearish cells uniformly ~0.31.
5. **Confidence is anti-calibrated:** the worst family carries the highest
   confidence (0.55-0.60) — a direct 18.8/18.13 input.
6. All of this must be read under the touch-only semantics caveat (6.4): the data
   does not measure the SMC-canonical sweep (reclaim+displacement), it measures a
   touch detector.

---

## 8. Experiment Backlog — Sprint 19 Candidates

Backlog items are prioritized for Sprint 19; Evidence Strength I-V and Confidence A-F
per 00_Program_Overview.md (A/B implementable; C stays backlog; D/F not implemented).

| ID | Experiment | Evidence | Conf | Priority |
|---|---|---|---|---|
| E1 | **Reclaim requirement in sweep definition:** sweep requires wick beyond + close back inside within N bars (N=1-3 configurable); re-measure LIQUIDITY_BOS family win rate | II (Osler 2002 cascades + majority open-source doctrine 5.3B) | B | P1 |
| E2 | **Telemetry decoupling:** replace the rule-family proxy (ConfluenceEngine.mqh:324) with detector-state fields (swept level id/type, penetration distance, sweep age, delay); add schema v4 columns | n/a (internal instrumentation) | A | P1 |
| E3 | **Displacement gate:** require ATR-based displacement impulse (or 18.2 E1 filter) on the sweep/reversal bar before the sweep counts (merges with 18.2 E1) | III (open-source majority; 18.2 E1 literature) | B | P1 |
| E4 | **Fix evaluator direction bug:** include `LIQUIDITY_EXTERNAL_HH` in `LiquidityEvaluator.mqh:29` levelBullish to match `ConfluenceRules.mqh:172-174` | n/a (correctness) | A | P1 |
| E5 | **Remove trendAligned bonus for sweep family** (measured −5.7pp; EURUSD_H1 0.2000) or gate it by displacement instead | II (Phase 7.5/7.6 measured) | B | P1 |
| E6 | **Mitigation time window + invalidation localization:** cap mitigation window (e.g., 5 bars) and scope invalidation to BOS pivots within proximity of the level (LiquidityDetector.mqh:583 is global today) | III (doctrine 3.3 + code review 6.5/6.6) | C | P2 |
| E7 | **Sweep quality telemetry in v4 schema:** penetration depth (pips/ATR), pool member count, level type (EQH/external), session at sweep — prerequisites for 18.13 calibration | n/a (extends E2) | B | P2 |
| E8 | **GBPJPY_H1 bullish differential study:** why 0.3304 vs EURUSD_M15 0.2687; session/volatility decomposition (links to 18.12) | III (Phase 7.6 measured asymmetry) | C | P2 |
| E9 | **Double-sweep support:** sweep-state version counter to allow a re-sweep before reversal (doctrine minority) | IV | D | P3 |
| E10 | **Volume/participation confirmation on sweep bars** (merges with 18.2 E6) | IV | D | P3 |

**Priority recommendation:** E1-E5 are the Sprint 19 cluster — E1+E3+E5 together
restore the sweep to its canonical definition and re-measure; E2+E4 are pure
instrumentation/correctness fixes with no behavioral risk. E6-E10 are research-stage
items.

---

## References (consolidated)

### Academic
1. Osler, C. (2002). "Stop-Loss Orders and Price Cascades in Currency Markets." FRBNY
   Staff Report No. 150. Journal version: *Journal of International Money and
   Finance* 24(2), 2005.
2. Kavajecz, K. & Odders-White, E. (2004). "Technical Analysis and Liquidity
   Provision." *Review of Financial Studies* 17(1), 65-104.
3. Kaminski, K. & Lo, A. (2014). "When Do Stop-Loss Rules Stop Losses?" *Journal of
   Financial Markets* 23, 1-31 (2007 working paper).
4. Lei, A. & Li, H. (2009). "The Value of Stop-Loss Strategies for the Hedged
   Portfolio." *Financial Review* 44(4), 623-644.
5. Brunnermeier, M. & Pedersen, L. (2005). "Predatory Trading." *Journal of Finance*
   60(4), 1825-1863.
6. Bouchaud, J.-P., Farmer, J.D. & Lillo, F. (2009). "How Markets Slowly Digest
   Changes in Supply and Demand." In *Handbook of Financial Markets: Dynamics and
   Evolution*, Elsevier.
7. Curcio, R. & Goodhart, C. (1993). "Chartism: A Controlled Experiment." *Journal of
   International Financial Markets, Institutions and Money* 3(3-4) — intraday FX
   ambiguity counterpoint (also cited in 18.2).

### Professional / practitioner
8. ICT (Inner Circle Trader) liquidity doctrine: draw on liquidity, sweep composition
   (wick + reclaim + displacement + MSS), equal highs/lows, external vs internal
   liquidity (secondary sources surveyed in this sprint; SMC corpus).
9. liquidityscan.io (2026). Liquidity sweep vs grab — "did displacement and MSS
   follow?" doctrine.
10. indicatoredge.io (2026). Market microstructure survey: stop clustering at
    technical levels, stop-run mechanics.
11. SMC-aligned stop placement doctrine (secondary sources; consistent across the
    18.2/18.3 source corpus).

### Open-source / implementations
12. Open-source SMC liquidity sweep implementations (TradingView indicator corpus and
    MQL5 codebase articles, as surveyed in 18.2/18.3): level clustering, sweep
    definitions (touch-only vs reclaim), displacement filters, kill-zone filters.
13. SrsBlack, ict-knowledge-library (GitHub, surveyed in 18.3) — ICT vocabulary and
    formal criteria for sweeps/mitigation.

### Internal
14. `Structure/LiquidityDetector.mqh` (866 lines) — Phase 6 code review.
15. `Confluence/Evaluators/LiquidityEvaluator.mqh` (120 lines) — Phase 6 code review.
16. `Confluence/ConfluenceRules.mqh` (458 lines) — rule-layer sweep helper.
17. `Confluence/ConfluenceEngine.mqh` — telemetry flag origin (line 324).
18. `Utils/Constants.mqh` — liquidity constants (lines 91-93).
19. `Portfolio/SymbolContext.mqh` — detector wiring (lines 343-357, 388-393, 633-637).
20. `Core/Engine.mqh` — engine accessor (lines 56, 264-268).
21. `docs/Sprint18_Research/00_Program_Overview.md` — methodology.
22. `docs/Sprint18_Research/01_Swing_Detection.md` — pivot source and dataset
    provenance (§7).
23. `docs/Sprint18_Research/02_BOS_Research.md` — BOS semantics and corrected BOS x
    sweep table (§7.3; fix commit `24bbace`).
24. `docs/Sprint18_Research/03_CHOCH_MSS.md` — CHOCH semantics and sweep-prerequisite
    question (§7.4).
25. Sprint 17 merged evidence dataset (fingerprint
    `2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`) and query
    scripts `sprint18_4_liquidity.py` / `sprint18_4_liquidity2.py`.
