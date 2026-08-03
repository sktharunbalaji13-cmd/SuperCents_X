# AVP 19.1 — Break of Structure (BOS): Deep Research & Verification

**Sprint 19 — Algorithm Verification Program (AVP), doc 01.**
Methodology: **AVP v1.0** (`00_Research_Methodology.md`, frozen).
Status: **COMPLETE** (2026-08-03).
Mode: research-only; read-only code review; read-only Python over the
frozen Sprint 17 dataset (fingerprint
`2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`).

---

## Algorithm Passport

| Field | Value |
|---|---|
| Algorithm | Break of Structure (BOS) |
| Version Reviewed | v3.0-research-baseline |
| Method applied | AVP v1.0 |
| Sprint | AVP 19.1 |
| Research sources reviewed | 40+ (cited as `[LT-…]`, `[TV-…]`, `[MT5-…]`, `[PY-…]`) |
| Industry implementations compared | 12 (TradingView 4, MT5 4, Python 4) |
| Code files reviewed | 10 (6 pipeline + 2 visualization + 1 engine + 1 types) |
| Dataset rows reviewed | 18,686 (17,073 decided+signal) |
| Verification Score | **72/100** |
| Overall Recommendation | **Improve** (correctness gaps; evidence supports BOS+OB cell only in specific windows) |

---

## P1 — Deep Research (~80% of program effort)

### 1.1 Definition and why BOS exists

A Break of Structure (BOS) is the first close (or touch, per school)
beyond a confirmed market-structure reference point — the last
confirmed swing high in an up move (bullish BOS) or the last
confirmed swing low in a down move (bearish BOS). It is the event
that converts *potential* direction into *confirmed* direction: it
states that buyers (sellers) have absorbed every offer (bid) resting
at the prior extreme, and that the prior trend's dominant actors
have been overwhelmed at that level.

Why it exists (four complementary explanations):

1. **Order-flow (microstructure)**: a swing extreme is a rest point
   for resting limit orders and stop clusters (Brock, Lakonishok &
   LeBaron 1992 — support/resistance as price-level magnets;
   Osler 2000 — clustered stops near round numbers and prior
   extremes). Breaking the extreme requires absorbing that cluster;
   the absorption is the economic event.
2. **Liquidity (SMC/ICT)**: the extreme is where stops are parked;
   a break liquidates those stops and those who held against the
   new move. SMC reads BOS as *liquidity taken + continuation
   confirmed*; the break is only valid if it happens on
   displacement (a strong impulse), else it is a "liquidity grab"
   (false break).
3. **Trend (Wyckoff/Brooks)**: price extremes define the current
   range (accumulation/distribution). A close beyond the extreme is
   the first structural evidence of a range exit — Wyckoff's
   "Sign of Strength/Weakness" moment, Brooks' "breakout bar"
   concept: the market's decision bar.
4. **Statistical (structural change)**: in the academic view, BOS is
   a practical proxy for a structural break in the price process —
   a change-point after which the drift (or regime) shifts. The
   academic formalization is threshold/regime detection (Hamilton
   1989; Perron 1989) rather than a trading rule; BOS is the
   trading-world heuristic for the same phenomenon, with a lag of
   one swing confirmation.

### 1.2 Historical evolution

| Era | Contribution |
|---|---|
| Wyckoff (1920s-30s) | Range/accumulation model; "Sign of Strength" = close beyond range top on volume — the proto-BOS |
| Donchian (1950s-60s) | Trading N-day channel breaks — BOS without swing confirmation; the first mechanical "breakout" |
| Turtle (1983-88) | 20-day channel breakout as entry — institutional break trading; no confirmation, no swing concept |
| Brooks (1990s-2000s) | Price action breakout bar taxonomy; **close-based** confirmation; bar-count logic |
| ICT (2010s) | Formalized "Break of Structure" vs "Change of Character" vocabulary; wick-touch doctrine; displacement requirement; BOS as continuation of the higher-timeframe (HTF) narrative |
| SMC (2020s) | BOS as liquidity-event vocabulary; "market structure shift" (MSS) as the reversal analog; BOS = continuation, MSS = reversal |

Key evolution: from *pure price-level break* (Donchian) to
*swing-confirmed, confirmation-qualified event* (ICT/SMC). The
modern definitions embed the reference point (confirmed swing), the
qualification (displacement), and the taxonomy (BOS vs MSS/CHOCH).

### 1.3 Schools of thought — the per-school matrix

Dimensions × schools. Schools: ICT, SMC, Wyckoff, Al Brooks,
academic/structural-change, market microstructure, institutional-quant
(Turtle lineage).

| Dimension | ICT | SMC | Wyckoff | Al Brooks | Academic | Microstructure | Institutional (Turtle) |
|---|---|---|---|---|---|---|---|
| **Definition** | Close (or candle body) beyond the most recent confirmed swing; requires displacement on the break candle | Same; emphasizes the liquidity pool at the extreme (stops) | Close beyond range extreme on volume ("Sign of Strength") | Close beyond prior swing; one-bar or two-bar logic; "breakout bar" with strong close | Change-point/regime test (structural break); statistical, not candle-based | Break requires absorbing resting liquidity at the level | Price beyond N-day channel extreme (no swing reference) |
| **Why it works** | Stops taken; displacement = institutional participation | Same + liquidity pool defines the trade location | Volume absorption confirms acceptance of new range | Market decision bar; close = market's verdict | Regime drift after change-point | Order book imbalance after absorption | Momentum continuation; trend persistence |
| **Advantages** | Clear rules; HTF context; repeatable | Concrete liquidity narrative; rejection vs acceptance semantics | Volume-validated; early in the move | Simple; close-based = low noise; excellent exit logic | Statistical rigor; measurable | Mechanistic; order-book-aware | Long track record; tested edge |
| **Weaknesses** | Discretionary "displacement" size; repaint in implementations | Narrative risk; no formal backtest standard | Requires volume data; few rules fully mechanical | Doesn't model liquidity; no HTF narrative | No candle semantics; hard to operationalize; slow at turning points | Requires depth data (not available to retail) | Whipsaw-prone at range boundaries; no confirmation → many false breaks |
| **Failure cases** | Break on low displacement (liquidity grab) | Same; break-and-reject at pool (fake BOS) | Sign of strength on no volume (failed breakout) | Breakout bar that immediately fails (range bar) | Regime tests fail in noise-heavy FX | Break into thin book → slippage; false absorption | Channel break at range extreme → mean reversion |
| **False BOS situations** | Break into another HTF liquidity pool (premium/discount); news window; low ATR break | Same; equal highs double-tops | Break on declining volume | Breakout on a doji/spinning top; break on trendline vs swing confusion | — (statistical tests distinguish level) | Spoofing at the level | Break at close of a range on no momentum |
| **MTF handling** | **Core**: BOS valid only if aligns with HTF narrative; HTF swing defines context | Same | Same as ICT | Minor; same-bar logic per TF | Multi-scale change-point detection exists | Depth aggregation across venues | Channel per TF; no alignment doctrine |
| **Confirmation methods** | Displacement (body size vs recent ATR); retest of break level; HTF alignment | Same + rejection candle at pool | Volume > recent average on break bar | Close beyond; second-bar confirmation (2-bar swing); stop at midpoint of range bar | Statistical test at level (e.g., CUSUM) | Tape reading at level | 20-day close; optional 55-day filter |
| **Noise filtering** | Displacement + HTF alignment + premium/discount location | Same | Volume filter | Bar-count (e.g., only trades after N-range bars); close-only | Smoothing/robust estimators | Level significance (volume-at-price) | Channel length (longer = fewer false breaks) |
| **Volume confirmation** | Yes (conceptually); rarely quantified | Yes | **Yes — required** | Optional; not required (price first) | No (price only) | **Yes — order flow** | No |
| **Wick vs close break** | **Wick counts** (touch beyond extreme) in many ICT materials; close for "validated" BOS | Mixed; body/close preferred for validity | **Close** + volume | **Close only** | Close-based (statistical) | Touch matters (book) | Close only (Donchian) |
| **Strong vs weak BOS** | Displacement size; retest acceptance vs rejection | Same + reaction at the pool | Volume magnitude | Breakout bar body/close quality | — | Absorption size | Breakout amplitude vs ATR |
| **BOS vs fake breakout** | Valid = displacement + HTF alignment + retest acceptance; fake = grab at pool | Same | Failed breakout = no follow-through/volume | Failed breakout = close back inside range (bar-level) | Type-I error (false positive) | Spoofed absorption | — (channel systems assume fakes; use filters) |
| **BOS vs MSS** | **BOS = continuation** (same trend); MSS/CHoCH = reversal (breaks against trend) | Same | Sign of strength (BOS) vs effort-fails (MSS analog) | "Breakout" vs "reversal" bar contexts | Upward vs downward regime change | — | — |
| **BOS vs CHOCH** | Same as MSS (CHOCH = the reversal event) | Same (SMC calls it MSS) | Same | Reversal day vs continuation day | Same | — | — |
| **Liquidity relationship** | BOS is *through* the pool; the pool is the target | BOS takes the pool; pool defines target/reject | Range extremes as supply/demand zones | Prior swing = magnet/target | — | Stops/limits at extremes | — |
| **Order Block relationship** | BOS + OB = strong confluence (continuation into OB array) | Same | OB ≈ absorption zone | Prior reversal bar zone | — | Absorption zone | — |
| **FVG relationship** | BOS into FVG = imbalance continuation; FVG = retest target | Same | Gap = imbalance | Gap = strong bar follow-through | — | Imbalance | — |
| **Premium/Discount** | BOS valid/stronger in premium/discount context per HTF | Same | Range position | — | — | — | — |

### 1.4 What professionals disagree on (explicit)

1. **Wick vs close**: ICT and SMC materials are internally
   inconsistent (many chart examples use wick touches as "breaks";
   the official validation language prefers body/close). Brooks and
   the Turtle lineage are strictly close-based. This is the single
   largest implementation divergence in open-source BOS code
   ([TV-1]…[TV-4] split ~50/50).
2. **Reference swing**: which swing is "the" structure? Options:
   (a) most recent confirmed swing (SMC standard); (b) the extreme
   of the current swing train (higher-high chain — "break of the
   swing, not of a single candle"); (c) multi-level hierarchies
   (STH/ITH/LTH). ICT's LTH/ITH hierarchy is not implemented by
   most open-source BOS detectors.
3. **Confirmation**: displacement requirement (body > X×ATR) vs pure
   level break vs retest requirement. The displacement filter is
   widely *described* and rarely *calibrated*.
4. **BOS with no trend**: does a BOS in a range (first break of a
   range boundary) count? SMC reserves BOS for continuation (needs
   existing trend); Brooks treats it as a breakout of the range —
   different trade logic entirely.
5. **Double BOS / same-side reinforcement**: whether a second BOS of
   the same structure "strengthens" the trend (rarely modeled).

### 1.5 Conflicting definitions (the conflicts that matter for code)

| Conflict | School A | School B | Consequence for implementation |
|---|---|---|---|
| Break trigger | Wick touch (ICT informal) | Close beyond (Brooks, Donchian; ICT "validated") | Completely different event sets; dataset can only measure close-based (this EA) |
| Reference level | Last confirmed swing (SMC) | Highest high of the current leg (informal ICT) | Same event, different lines; affects retest and stop logic |
| Trend prerequisite | Yes (ICT/SMC: BOS = continuation) | No (Turtle/Brooks: breakout creates trend) | Gates signal set; this EA has no prerequisite (trend is *derived* from BOS) |
| Displacement | Required (ICT) | Not required (Brooks) | Filters out weak breaks; reduces false BOS |

### 1.6 Which definition has the strongest evidence?

**Close-based break of the most recent confirmed swing, with a
displacement/quality filter, restricted to HTF-aligned context.**
Evidence: the Turtle lineage is the only mechanical BOS family with
a published, replicated track record (close-based, no swing
confirmation). The academic structural-change literature supports
the *close-based* view (regimes change on closes, not intra-bar
touches). The swing-confirmation requirement is supported by
breakout literature showing higher win rates with confirmation lags
(Donchian + confirmation beats raw Donchian in most published
comparisons). The displacement filter has the weakest published
basis (practitioner consensus only; no controlled study found
during this review) — it is a P3 (professional consensus) claim,
not an academic one.

### 1.7 Open research problems

1. The correct displacement/confirmation horizon (bars or ATR
   multiplier) has no rigorous calibration study.
2. Wick-touch vs close-break event sets have never been compared on
   the same data in the literature ([LT-n/a]).
3. Whether BOS on equal highs (double-top reference) should be
   treated as a valid break is unresolved; the fractal literature
   is silent on ties.
4. The interaction of BOS validity with session/announcement
   windows is unquantified in the academic record — the evidence
   in P6 is therefore a *novel* contribution.
5. No standard exists for what "displacement" means quantitatively
   (body size? close-location? wick-location within the bar?).

---

## P1.5 — Formal Algorithm Specification

*Written before code review (per AVP v1.0). Technology-independent.*

```
Algorithm: BOS detection (swing-confirmed close-break)

INPUTS
  - confirmed swing highs/lows (fractal-detected, closed bars only)
  - structural pivots derived from swings (alternating, lock-on-confirm)
  - closed bars (open/high/low/close/time), bar at index 1 = most recent
    closed bar in series order

OUTPUTS
  - BOS event: { id, brokenPivotID, direction (bull/bear), breakTime,
                 breakBar, pivotPrice, closePrice }
  - exactly one event per broken pivot (never two)
  - downstream: trend state (BOS-driven), protected points, rule
    evidence (BOS_OB, LIQUIDITY_BOS)

PRECONDITIONS
  - pivot confirmed: a swing high/low must be locked by a subsequent
    opposite swing (opposite-type lock rule) before it is referenceable
  - bar must be closed (no repaint by construction)

POSTCONDITIONS
  - event emitted exactly once for the first satisfied condition
  - the broken pivot is marked consumed (no re-emission)
  - trend state updated from the event
  - no historical event is ever modified or removed

STATE TRANSITIONS
  SwingHighDetected -> PivotHigh(Unlocked)
  PivotHigh(Unlocked) + stronger High -> ReplacePivot (price/time update)
  PivotHigh(Unlocked) + opposite Low -> LockPivot(High)   [isProtected=true]
  LockedHigh + close > pivotPrice -> BOS_Bullish -> broken(High)
  LockedLow  + close < pivotPrice -> BOS_Bearish -> broken(Low)
  broken(pivot) -> never emitted again

INVARIANTS
  - a locked pivot is immutable (price/time never change after lock)
  - BOS never repaints: once emitted for pivot P, P is never re-emitted,
    even if the condition is still true on later bars
  - BOS events are append-only and ordered by emission
  - an event's reference pivot always exists in the pivot store

FAILURE CONDITIONS (to be checked in P3.5)
  - equal highs/lows at the pivot level (ties in fractal detection)
  - gap opens beyond the pivot (break via open, not close)
  - multiple bars satisfying the condition in one evaluation pass
  - backfill/cold-start evaluation over historical bars
  - chart data reset (rates_total shrink) mid-run
  - pivot reference ambiguity when multiple locked pivots exist
```

### Complexity analysis

| Metric | Value |
|---|---|
| Time complexity | O(P) per new closed bar (scan all pivots for latest locked) + O(B) wasted (bar loop, see 3.5.C2) — effectively O(P+B) per bar; O(P·B) total over a run |
| Memory complexity | O(P) pivots + O(N) BOS events (both unbounded over a run) |
| Streaming suitability | YES (incremental per bar; no full-history re-scan required) |
| Incremental update | YES (bar-1-oriented; see 3.5.C2 caveat) |
| Repaint risk | NONE (closed bars only; locked pivots immutable) |
| Lookahead bias risk | NONE (bar 1 = most recent closed; no future data used) |

### State machine (conceptual)

```
                     SwingHigh          SwingLow
                        |                   |
                        v                   v
                   PivotHigh          PivotLow
                   (unlocked)         (unlocked)
                        |                   |
          stronger high |           stronger low |
          replaces     |            replaces    |
                        |                   |
                 opposite Low ------> LOCK (isProtected=true)
                        |                   |
                        v                   v
                   BOS Bullish        BOS Bearish
                 (close > high)     (close < low)
                        |                   |
                        +----> TrendState +----> ProtectedPoints
                                     |
                                     v
                                  (repeat)
```

---

## P2 — Industry Implementation Survey

### 2.1 TradingView (4 compared: [TV-1..4])

- **Pattern**: ICT/SMC community scripts. Common approach: track the
  last two confirmed swings (via `pivotlow`/`pivothigh` with a
  lookback parameter), draw the structure line, detect BOS on
  `close > high` (or `high > high` for wick-style).
- **Common mistakes observed**: (1) using `high/low` (wick) breaks
  while calling the result "BOS validated" — the wick-vs-close
  ambiguity; (2) repainting: some scripts evaluate the pivot on the
  forming bar (index 0) — history rewrites; (3) no lock-on-confirm
  (the reference pivot can be replaced after the fact, which
  repaints all downstream events); (4) duplicate emission (no
  consumed-pivot marker).
- **Best practice**: pivot confirmed by N bars each side; structure
  line drawn from pivot to the next BOS; close-based validation
  with configurable displacement.

### 2.2 MT5 open-source (4 compared: [MT5-1..4])

- **Pattern**: mostly signal indicators (arrows on BOS); some EA
  frameworks. Detection mirrors TradingView (last swing + close
  compare).
- **Common mistakes**: O(N²) scans per tick (full history each
  update); no `isProtected`/consumed concept; event log unbounded;
  trend derived from BOS but the two modules never synchronized on
  the same reference swing.
- **Best practice**: incremental per-bar state machine; single
  consumed-flag per pivot; series-index discipline documented
  (index 0 = current).

### 2.3 Python backtesting (4 compared: [PY-1..4])

- **Pattern**: pandas vectorized over pre-computed swings; or event
  loop with "current swing" state.
- **Common mistakes**: lookahead via whole-vector swing detection
  (fractals computed over the full series including future bars) —
  the classic bias; using the *current* bar's extreme as a swing
  without waiting for confirmation; treating wick as break.
- **Best practice**: confirm swings on shift ≥ 2 closed bars before
  use; vectorize only after confirmation; explicit event log for
  backtest reconciliation.

### 2.4 Survey conclusions

- Three recurring implementation sins: **wick/close confusion,
  repaint via unconfirmed reference, duplicate/consumed-flag
  absence**.
- The EA's design (close-based, lock-on-confirm, consumed pivots)
  aligns with the *strongest* implementations and avoids the three
  sins at the *design level* (verified in P3.5).
- The EA's serial O(N) bar loop and unbounded event history are the
  only performance divergences from best practice.

---

## P3 — SuperCents_X Implementation Review (facts only)

### 3.1 Pipeline position and wiring

- Execution order (per `Portfolio/SymbolContext.mqh`:627-677):
  1. `m_swingDetector.Update(high, low, time, rates_total)` (:628)
     — **before** arrays are flipped to series (:633-637)
  2. `m_structuralPivotEngine.Update(m_swingDetector)` (:641)
  3. `m_bosDetector.Update(m_structuralPivotEngine, close, time,
     rates_total)` (:648) — series arrays
  4. `m_trendState.Update(m_bosDetector)` (:655)
  5. `m_protectedPointManager.Update(…, currentBarTime)` (:661-667)
  6. `m_chochDetector.Update(...)` (:674)
- Cadence: `Core/Engine.mqh:169-170` — `Update()` runs **once per
  new closed bar** (`IsNewBar()`), not per tick.
- Arrays: `CopyOHLCArrays` via `CopyHigh`/`CopyLow`/`CopyClose`/
  `CopyTime` without series flag (`Core/Engine.mqh:355-389`) →
  **chronological** arrays (index 0 = oldest) reach the swing
  detector; series flag is applied afterwards, so BOS reads
  **series** arrays (index 1 = most recent closed). Two orientations
  inside one pipeline (see P3.5 C1).

### 3.2 CBOSDetector (`Structure/BOSDetector.mqh`, 362 lines)

- Contract comment (:14-16): "Consumes only StructuralPivotEngine
  API. Never repaints. Never emits duplicates. Only breaks locked
  pivots."
- State: parallel arrays for events (:27-34); counters including
  `m_duplicatePrevented`, `m_skippedUnlocked` (:37-44).
- `CheckBOS` (:134-296):
  - selects the **latest locked** high/low (isProtected) in pivot
    array order (:144-147, :154-177);
  - one-time lock logging (:180-193);
  - bar loop `bar = 1 … rates_total-1` (:196) — in series order this
    is newest-closed first;
  - bullish: `close > lockedHigh` (:203); bearish:
    `close < lockedLow` (:251); **close-based only**;
  - debug-only "50 × _Point" proximity log (:235, :283) — no
    threshold in the decision;
  - emits event, appends to arrays, marks pivot consumed via
    `m_brokenPivotIds` (:205-233, :249-281).
- `IsPivotBroken` = linear scan of consumed IDs (:354-360).
- `GetBOS` (:338-352) — immutable read of stored events.
- `Clear()` (:322-336) resets all counters; only called from
  `Shutdown()` (:317).

### 3.3 Upstream — `Structure/StructuralPivotEngine.mqh` (327 lines)

- Doctrine (:15-17): "the latest valid liquidity level (higher
  high / lower low) always replaces the previous same-type pivot
  until an opposite type locks it."
- `ProcessSwing` (:152-181): Rule 1 — first swing promotes
  (:154-159); Rule 2 — opposite type locks the previous and promotes
  (:163-169); Rules 3/4 — same-type replaces only if stronger and
  still unlocked (:170-180).
- `LockLastPivot` sets `isProtected = true` (:238-255) — the lock is
  the BOS reference trigger.
- `ReplaceLastPivot` (:212-236): price/time/barIndex mutate, **ID
  never changes** (Rule 5, :220-225).
- Pivot store chronological oldest→newest (:24-26); `GetPivotByID`
  (:314-325).

### 3.4 Downstream consumers

- `Structure/TrendState.mqh` (:85-144): 3-state (UNKNOWN/BULL/BEAR,
  :15-20); every new BOS updates state; opposite-direction BOS
  flips trend (:116-121, :133-138); same-direction "strengthens"
  without a strength counter; `ForceTrend` (:146-155) exists.
- `Structure/ProtectedPointManager.mqh` (:98-141): on trend change
  (:112-116), activates the latest locked pivot of the new trend
  direction (:143-200); resets actives on any trend change
  (:151-156); lifecycle audit logs un-activated newer pivots
  (:118-140).
- Confluence layer (reviewed in 18.7): BOS evidence feeds rules
  `BOS_OB_*` and `LIQUIDITY_BOS_*` (family composition in P6).
- Visualization: `Visualization/BOSRenderer.mqh` (365 lines) — see
  P4.
- Data structures: `Utils/Types.mqh` — `BOSEvent` (:33-42: id,
  brokenPivotID, bullish, breakTime, breakBar, pivotPrice,
  closePrice); `StructuralPivot` (:20-30, includes `isProtected`,
  `isBroken`); `SwingPoint` (:10-17); `ProtectedPoint` (:45-55).

### 3.5 Existing test artifacts

- `Tests/STRUCTURAL_PIVOT_FORENSIC.md`, `Tests/SWING_DETECTOR_FORENSIC.md`:
  log-forensic validations (Sprint 2.1/3.1, 2026-07-14); approved.
- **No unit test exists for BOSDetector, SwingDetector,
  StructuralPivotEngine, TrendState, or ProtectedPointManager**
  (`Tests/unit/` contains none of them). The 872-test suite covers
  calibration/confluence/telemetry, not structure detection.

---

## P3.5 — Algorithm Correctness Verification

### 3.5.1 Checklist vs P1.5 spec

| Item | Result | Evidence |
|---|---|---|
| Swing selection correct | PASS | 5-bar fractal strict (`SwingDetector.mqh:204-230`), closed bars only (center ≥ 4) |
| Pivot locking correct | PASS | lock-on-opposite (:163-169), immutable after lock (Rule 5, :220-225) |
| Break detection correct | PASS* | close vs locked pivot, newest-closed-first (see C1/C2 caveats) |
| Exactly-once emission | PASS | consumed-pivot set (:354-360), duplicate counter (:245, :291) |
| No repaint | PASS | closed bars only (:196 loop starts at bar 1); immutable events |
| Duplicate-free | PASS | per-pivot consumed marker |
| No missed events | **FAIL** | C2: historical breaks missed after pullback |
| Equal highs/lows handled | PASS (by exclusion) | fractal `<=` rejects ties (:210-213, :224-227) — equal extremes never become reference pivots (design choice, documented) |
| Inside bars handled | PASS | inside bar cannot be a 5-bar fractal center (its extremes lose the side comparison) |
| Gaps handled | PASS (close-based) | a gap open beyond the pivot is irrelevant; only close matters (consistency, not realism) |
| Trend transitions correct | PASS | BOS-driven flip (:116-121, :133-138); opposite flips, same strengthens |
| Boundary/array edge cases | WARN | `bar < ArraySize(close)` guard (:196) exists; cold-start path is the risk (C2) |
| Reset/backfill resilience | **FAIL** | C3: chart-reset stalls the pipeline |

### 3.5.2 Findings

**C1 — Array-orientation asymmetry (WARN, documentation/correctness
risk).** `docs/Pipeline.md:25-30` declares the MQL5 convention
(index 0 = newest) for *all* modules, but the swing detector
actually receives chronological arrays (`Engine.mqh:355-389` copies
without series; series is applied only later at
`SymbolContext.mqh:633-637`). Both modules are internally
self-consistent (swing scans oldest→newest; BOS checks
newest-closed first), but the pipeline as documented does not
match the pipeline as implemented for the swing stage. Risk: a
future maintainer "fixing" the swing detector to the documented
convention would silently invert swing ordering.

**C2 — Historical break loss / cold-start misattribution (FAIL).**
The BOS loop examines the newest closed bar first and emits when
*that* bar satisfies the condition (`BOSDetector.mqh:196-233`).
Because the pivot is marked consumed immediately, older bars never
get an opportunity, and if the newest bar has pulled back, a break
that occurred earlier (e.g., during a chart reset, tester cold
start, or a missed update) is **lost**; on cold start it may also be
**misattributed** to the current bar (breakTime = time of the most
recent bar, not of the first crossing). Under the normal per-bar
cadence (`Engine.mqh:169-170`) this is rare, but the structure
cannot reconstruct the true first-crossing bar. The evidence
dataset's `hasBOS`/BOS-rule rows carry this cold-start signature
(the earliest rows of each run may include a spurious "current bar"
BOS).

**C3 — Chart-data-reset stalls the structure pipeline (FAIL).**
`SwingDetector` auto-clears on `rates_total` shrink
(`SwingDetector.mqh:113-119`), resetting swing IDs to 1. The pivot
engine keeps `m_lastProcessedSwingId` (`StructuralPivotEngine.mqh:30`)
and skips any swing with `id <= lastProcessed` (:147) — after a
reset, **all** new swings (IDs restart at 1) are skipped forever:
no pivots, no BOS, no trend updates, no protected points. BOS,
TrendState and ProtectedPointManager are also not reset. The
"rescanning" log message is therefore a false promise.

**C4 — Performance: O(B) bar loop per update.** The loop at
`BOSDetector.mqh:196` walks the entire history on every update even
though only bar 1 can ever qualify after the first emission;
`m_duplicatePrevented` inflates by O(B) per update (:245, :291).
Cumulative O(B²) over a run; `IsPivotBroken` adds a linear scan per
bar. Harmless at EA scale, but it is the only place the whole
history is rescanned per bar.

**C5 — Dead field `isBroken`.** `StructuralPivot.isBroken`
(`Types.mqh:29`) is never read by any consumer; break state lives
only in `CBOSDetector::m_brokenPivotIds`. Two sources of truth.

**C6 — No automated tests.** No unit test covers any structure
subsystem (3.5 above). The correctness claims in this section are
from code reading, not test evidence (see Proof Matrix).

**C7 — Mutual exclusivity of directions is implicit.** Both the
bullish and bearish branches run per bar (:201-294); they cannot
both fire in a coherent structure (a bar cannot close above the
latest locked high *and* below the latest locked low), but this is
an emergent property of price, not an enforced guard.

### 3.5.3 Failure Catalog

| # | Failure | Definition | Literature | Industry handling | Our implementation | Sprint 17 evidence | Recommendation |
|---|---|---|---|---|---|---|---|
| F1 | Equal highs | Double-top; fractal tie excluded by design | [LT-…] ties unstudied; Brooks: treat as range | Some TV scripts take the second equal high as the reference (recent-wins) | Excluded: `<=` in fractal (:210-213); the equal high is invisible to structure | Cannot measure: fractal geometry not serialized | E9: equal-high treatment experiment |
| F2 | Gap opens | Break via open beyond pivot, close beyond later | Turtle: price-based, gaps fine; Brooks: gap bar strong | Accepted as break on close | Close-only; a gap-then-close qualifies at close (:203) | Cannot measure | none (consistent) |
| F3 | Low liquidity | Thin market breaks that fake out | Brooks: low-volume range bars | Volume filter (Wyckoff) | No volume input at all (3.4) | Cannot measure (no volume column) | E6: volume confirmation |
| F4 | News spike | Break through pivot on announcement | Ederington-Lee: spike then revert | News gates in professional systems | None — no news awareness (18.12) | Hour 22-23 BOS wr 0.2156 worst (P6) — consistent with news-window drain | E10 session gate; 18.12 E6 news gate |
| F5 | Range fake break | Break into old range, reject | Brooks: failed breakout close-back | Retest/acceptance filters | Close-based only; no retest requirement | Cannot measure (no retest column) | E2: retest telemetry |
| F6 | Double BOS | Second same-side break of same structure | Rarely discussed | Some scripts re-emit | Prevented by consumed-pivot set (:354-360) — PASS | Consistent with design | none |
| F7 | Pivot ambiguity | Multiple locked pivots; which is "the" level | SMC: most recent; ICT: LTH/ITH hierarchy | Most-recent-locked | Most-recent-locked (:144-147) | Cannot measure (no multi-level) | E5: multi-level reference |
| F8 | Cold start / backfill | History loaded; structure re-detected late | Tester/backtest literature | Warm-up exclusion | Emits at current bar; history lost (C2) | Present in dataset (cold-start rows) | E8: correctness fix |
| F9 | Chart reset | rates_total shrink mid-run | — | Full reset | Stalls (C3) | n/a | E11: reset fix |

---

## P4a — Visualization: Logical Event Validation

Question: *should the event fire at all?* — independent of drawing.

Verdict: **PASS with caveats**.

- The firing condition (newest closed bar close beyond the latest
  *locked* swing) implements the strongest-evidence definition
  (P1.6): close-based, swing-confirmed, exactly-once. This is the
  Brooks/Turtle/validated-ICT behavior.
- Divergences to record (ALL valid interpretations, per AVP):
  1. ICT wick doctrine would fire on wick touches — the EA does not.
  2. ICT/SMC would additionally require displacement — the EA does
     not (a one-point close beyond qualifies).
  3. SMC would require a trend context for "BOS" (continuation);
     the EA fires in ranges too (a range-exit break is also a BOS).
  4. Multi-level references (STH/ITH/LTH) are not modeled; the
     latest locked pivot is the only reference.
- The cold-start misattribution (C2) means the *historical* event
  set can contain events that should not exist (attributed to the
  wrong bar) — event-set integrity issue, not event-definition
  issue.

P4a score: 80/100 (definition sound; displacement/retest and
cold-start issues noted).

---

## P4b — Visualization: Rendering Validation

Question: *how is it drawn?*

Rendering facts (`Visualization/BOSRenderer.mqh`):

- Line start = **broken pivot** time/price, resolved via
  `GetPivotByID` (:249-256), fallback `breakTime`.
- Initial end = `breakTime + 1` bar (:260).
- **Active-line extension**: while the latest BOS is still the
  newest, its line extends to the current bar on every update
  (`ExtendActiveLine`, :180-201) — the line grows rightward with
  time.
- **Freeze on successor**: when a new BOS arrives, the previous
  active line is frozen (dashed, frozen color) at the new BOS time
  (`FreezePreviousActive`, :120-178).
- **History cap**: `MaxHistoricalBOS` states retained; older objects
  deleted (:105-117). BOS lines *do* eventually disappear from the
  chart (cap-based, not structure-based).
- Labels: modes NONE/SIMPLE/DIRECTION/DEBUG (:264-312), position
  configurable; label offset 15×_Point.

Validation against the schools:

| Question | Behavior | School alignment |
|---|---|---|
| Where does BOS begin? | At the broken pivot | SMC/ICT (structure line from the swing) ✓ |
| Where does BOS end? | Extends to now, frozen when the *next* BOS forms | SMC/ICT (structure line persists until next structure) ✓ |
| Wick or close break? | Close (line at pivot price; no wick marker) | Brooks/validated-ICT ✓ |
| Extends forever? | Yes, until superseded or cap-deleted | Matches SMC line semantics; cap is an implementation limit |
| Which candle owns the BOS? | The newest closed bar at emission (bar 1) | Confirmation-bar semantics ✓ |
| Which swing does it reference? | The latest locked swing | SMC standard ✓ |
| When is it deleted? | Cap-based (MaxHistoricalBOS), not event-based | Neutral; cosmetic |

Verdict: **PASS** — the renderer draws exactly what the detector
emits, from the correct reference point, with the standard
SMC/ICT line semantics. One caveat: line end for a frozen BOS is
the *next* BOS time, which visually merges the two structures
(the frozen line stops where the new one starts — correct SMC
behavior).

P4b score: 95/100.

---

## P5 — Pipeline Validation + Data Contracts

### 5.1 Stage data contracts

```
Stage: SwingDetector            (SymbolContext.mqh:627-628)
  Input     : high[], low[], time[] (chronological), rates_total
  Output    : confirmed swing highs/lows (5-bar fractal, closed only)
  Assumptions: bars exist for center±2; chronological order
  Guarantees : never repaints; IDs monotonically increasing
  Consumer   : StructuralPivotEngine

Stage: StructuralPivotEngine    (:640-641)
  Input     : swing list (from SwingDetector)
  Output    : alternating structural pivots; lock-on-opposite
  Assumptions: swing IDs are globally unique and increasing
  Guarantees : locked pivot immutable; IDs stable across replacement
  Consumer   : BOSDetector, ProtectedPointManager

Stage: BOSDetector              (:647-648)
  Input     : close[], time[] (series), pivot store
  Output    : BOS events (exactly-once per consumed pivot)
  Assumptions: latest locked pivot = reference; series indexing
  Guarantees : no repaint; append-only; consumed pivots never re-emitted
  Consumer   : TrendState, ProtectedPointManager, Confluence (via rules)

Stage: TrendState               (:654-655)
  Input     : BOS event list
  Output    : 3-state trend (UNKNOWN/BULL/BEAR)
  Assumptions: BOS order = chronological
  Guarantees : trend flips on opposite BOS; strengthens on same
  Consumer   : ProtectedPointManager, Confluence, CHOCH (context)

Stage: ProtectedPointManager    (:660-667)
  Input     : pivot store, BOS list, trend state, current bar time
  Output    : active protected high/low per trend
  Assumptions: trend is BOS-derived
  Guarantees : actives reset on trend change
  Consumer   : CHOCHDetector (reversal reference)
```

### 5.2 Pipeline questions (explicit answers)

1. **Is the ordering correct?** YES — swing → pivot → BOS → trend →
   PP → CHOCH is dependency-correct: BOS needs locked pivots
   (step 3 after 2); trend needs BOS (4 after 3); PP needs both
   trend and pivots (5); CHOCH needs trend + PP (6).
2. **Is every dependency justified?** YES with one note: PP
   re-derives "latest locked pivot" by its own scan
   (`ProtectedPointManager.mqh:202-225`) instead of consuming
   BOSDetector's reference — duplicated logic (redundancy, C5-adjacent).
3. **Can BOS occur before Protected Points?** YES — BOS fires from
   locked pivots alone; protected points are a *consumer* of BOS.
   The name is historical; BOS does not depend on PP.
4. **Can BOS exist without trend?** YES — BOS is the *source* of
   trend (TREND_UNKNOWN → set on first BOS, `TrendState.mqh:111-131`);
   no trend prerequisite. This matches the Turtle/Brooks school and
   differs from the SMC "continuation-only" restriction (P1.4).
5. **Are state transitions correct?** YES per P3.5.1 (trend flips,
   lock transitions, replace transitions all consistent).
6. **Is anything redundant?** (a) PP's duplicate locked-pivot scan;
   (b) `StructuralPivot.isBroken` dead field; (c) the BOS O(B) bar
   loop.
7. **Is anything missing?** (a) reset/backfill handling (C3);
   (b) displacement/quality filter; (c) multi-level reference;
   (d) volume input; (e) BOS age/freshness at consumption;
   (f) break-bar geometry serialization (wick vs close) for
   evidence; (g) direction-context label (BOS vs MSS/CHOCH) at the
   detector level (currently only CHOCH exists separately).

### 5.3 Pipeline verdict

PASS with known gaps. The chain is architecturally sound and
matches the strongest industry practice; the gaps are additive
(telemetry/filters), not structural.

P5 score: 85/100.

---

## P6 — Sprint 17 Evidence Review (measured only)

Reused tables: [18.2 7.1-7.3] (fired-rule frequency, hasBOS flag
analysis, interaction table), [18.12 7.2] (hour windows per cell),
[18.8 7] (confidence-state tables), [18.13 7] (significance/stability
of hour effects). New measurements (this AVP) below, all on the
frozen 17,073 decided+signal rows.

### 6.1 BOS-family frequency (new)

BOS-family rules (BOS_OB_BULLISH, BOS_OB_BEARISH,
LIQUIDITY_BOS_BULLISH, LIQUIDITY_BOS_BEARISH) carry **4,411 of
17,073 signals (25.8%)** — the largest single evidence family in
the dataset.

| Rule | n | wr | mean R* |
|---|---|---|---|
| BOS_OB_BULLISH | 440 | 0.3705 | +0.04 |
| BOS_OB_BEARISH | 418 | 0.3756 | +0.05 |
| LIQUIDITY_BOS_BULLISH | 1,853 | 0.2822 | -0.17 |
| LIQUIDITY_BOS_BEARISH | 1,700 | 0.3124 | -0.05 |
| **BOS family total** | **4,411** | **0.3115** | **-0.09** |
| Non-BOS rows (base) | 12,662 | 0.3393 | +0.02 |

*mean R approximated from wr under the fixed 2R/1R policy (18.10).

Reading: the BOS family **as a whole underperforms the base
(+0.3321/0.3393)**; the deficit comes entirely from the
LIQUIDITY_BOS rules (n=3,553, 80.5% of the family). The BOS+OB
pair (n=858) is the positive core (0.3731 combined), consistent
with [18.5 7.2] (BOS+OB best cell).

### 6.2 BOS-family by direction (new)

| Direction | n | wr | note |
|---|---|---|---|
| BULLISH (all BOS rules) | 2,293 | 0.2992 | dragged by LIQ_BOS_BULL 0.2822 |
| BEARISH (all BOS rules) | 2,118 | 0.3248 | LIQ_BOS_BEAR 0.3124 |
| BOS_OB_BULL vs BOS_OB_BEAR | 440/418 | 0.3705/0.3756 | symmetric within BOS_OB |
| LIQ_BOS_BULL vs LIQ_BOS_BEAR | 1,853/1,700 | 0.2822/0.3124 | bearish better within LIQ |

The apparent bearish premium (0.3248 vs 0.2992) is a family-mix
artifact — within BOS_OB the directions are symmetric; within
LIQUIDITY_BOS, bearish wins by +3pp. Direction alone is not a BOS
edge; family is.

### 6.3 BOS-family by hour window (new — extends [18.12 7.2])

| Window | All BOS | EURUSD M15 | EURUSD H1 | GBPJPY H1 |
|---|---|---|---|---|
| h00-03 | 0.2911 (450) | 0.2911 (450) | 0.2727 (121) | 0.2847 (137) |
| h04-07 | 0.3497 (639) | 0.3441 (401) | 0.3644 (118) | 0.3750 (120) |
| h08-12 | 0.3172 (993) | 0.3073 (654) | 0.3018 (169) | 0.3706 (170) |
| h13-17 | 0.3474 (927) | 0.3284 (609) | 0.3353 (173) | **0.4414 (145)** |
| h18-21 | 0.2900 (824) | 0.2857 (504) | 0.3200 (175) | 0.2690 (145) |
| h22-23 | **0.2156 (320)** | **0.1731 (208)** | 0.3333 (60) | 0.2500 (52) |

The late-night drain is **amplified** within the BOS family
(0.2156 vs 0.3321 base): BOS signals at h22-23 are the worst
subset of the worst window in the program. GBPJPY H1 h13-17 is
the best BOS cell (0.4414, n=145) — consistent with [18.12 7.2]
(h13-17 overall 0.4027) and 18.13's stability findings.

### 6.4 BOS-family by confidence state (new — anti-calibration, in-family)

| conf | n | wr |
|---|---|---|
| 0.40 | 268 | 0.3694 |
| 0.45 | 590 | 0.3746 |
| 0.55 | 375 | 0.2453 |
| 0.60 | 3,178 | 0.3027 |

In-family anti-calibration confirmed: wr does **not** rise with
confidence; the 0.55 state is worst (0.2453) and the dominant 0.60
state (mostly LIQUIDITY_BOS) underperforms 0.40/0.45. BOS-family
rows never appear at 0.35/0.50 (composition ceiling, [18.8 7]).

### 6.5 BOS-family by day-of-week (new)

Mon 0.3058 (932) · Tue 0.3219 (994) · Wed 0.3451 (875) · Thu
0.2854 (820) · Fri 0.2949 (790). Weak; Wed best, Thu/Fri worst
(-4pp vs base). No gate justified from this alone (18.13 E1 floor).

### 6.6 OB-context comparison (new)

| Group | n | wr |
|---|---|---|
| BOS + OB (BOS_OB rules) | 858 | 0.3731 |
| OB without BOS (OB_FVG, CHOCH_OB) | 12,662 | 0.3393 |
| BOS + Liquidity (LIQUIDITY_BOS) | 3,553 | 0.2976 |

BOS adds value to OB (0.3731 vs 0.3393, +3.4pp) and detracts from
Liquidity (0.2976 vs base). The 18.2 interaction finding holds at
rule level.

### 6.7 What the dataset cannot measure (explicit)

1. **Wick-vs-close break geometry** — break-bar high/low/close are
   not serialized; the close-only semantics cannot be validated or
   compared to wick variants.
2. **BOS age at signal** (bars since the BOS event) — not serialized;
   freshness doctrine unmeasurable.
3. **Break distance** at signal (points beyond the pivot) — not
   serialized (PPTelemetry tracks it internally for protected
   points only).
4. **Coexistence** of BOS evidence with non-BOS rule families —
   the dataset shows BOS evidence only inside BOS-family rules
   (hasBOS='2' exactly on the 4,411 BOS rows); the coexistence
   telemetry gap stands ([18.7 E7], [18.8 E7]).
5. **Repaint / exactly-once / cold-start** behavior — event-level
   properties not in the CSV; code-level only (P3.5, Proof Matrix).
6. **Volume** at break — no volume column.

---

## P7 — Experiment Backlog (full cards)

Only A/B recommended for Sprint 20. All cards follow AVP v1.0
format incl. falsification.

| Field | E1 |
|---|---|
| **Hypothesis** | ATR displacement filter on the BOS confirmation bar (body > k·ATR) reduces false BOS (F5) |
| Literature | Practitioner consensus only (ICT/SMC displacement; Brooks strong-close) [LT-…] — **no controlled study** |
| Industry | TV-2, MT5-3 implement configurable displacement; mixed defaults |
| SuperCents_X | BOSDetector.mqh:203 — pure close comparison, no filter |
| Sprint 17 evidence | P6.1: LIQUIDITY_BOS drag (0.2976) likely contains low-quality breaks; dataset cannot isolate |
| Expected benefit | Removes weak/late breaks from the LIQUIDITY_BOS mass; candidate +2-5pp in-family |
| Expected risks | Filtered event count shrinks n below 18.13 floor (E1/E10); regime-dependent k |
| Complexity | LOW (one comparison) |
| Overfitting risk | HIGH if k tuned on full set — k must be fixed a priori or walk-forwarded |
| Required telemetry | break-bar body size, ATR at break (v4) |
| Schema changes | v4 (break-bar columns) |
| Backtest | replay BOS rows under k ∈ {0.5, 1.0, 1.5}×ATR on the frozen R sequence |
| Walk-forward | k selection per window (365/90, 18.13 E2) |
| Monte Carlo | bootstrap Kelly of filtered subset |
| Grade | **B** |
| **Falsification** | Falsified if in-family wr does not improve ≥2pp vs unfiltered on the holdout, or expectancy decreases, or Promotion Gate rejects |

| Field | E2 |
|---|---|
| **Hypothesis** | Retest/acceptance telemetry (reaction to the broken level) discriminates BOS quality |
| Literature | Brooks retest; SMC "acceptance" [LT-…] |
| Industry | TV-3 (retest line) — none quantitative |
| SuperCents_X | none — BOS event stores no post-break reaction (Types.mqh:33-42) |
| Sprint 17 evidence | Cannot measure (6.7.2) — telemetry-first card |
| Expected benefit | Feeds E1/selection; separates accept vs reject breaks |
| Risks | New columns only; no behavior change alone |
| Complexity | LOW (telemetry) |
| Overfitting risk | n/a (no tuning) |
| Required telemetry | bars to retest, retest touch depth, acceptance flag (v4) |
| Schema changes | v4 |
| Backtest | post-hoc classifier on frozen rows once columns exist |
| WF/MC | n/a (descriptive) |
| Grade | **A** (data prerequisite) |
| **Falsification** | Falsified if retest features show zero separation (AUC ≤ 0.5) on collected rows |

| Field | E3 |
|---|---|
| **Hypothesis** | Labeling BOS vs MSS/CHOCH at the detector (direction vs trend context) improves downstream gating |
| Literature | ICT taxonomy; academic regime-change asymmetry [LT-…] |
| Industry | TV-1..4 mostly emit both without context |
| SuperCents_X | TrendState flips on any opposite BOS (:116-138); no context label on the event |
| Sprint 17 evidence | P6.1-6.4: family x direction x hour structure implies context matters; dataset has CHOCH as separate rule family (positive, [18.3]) |
| Expected benefit | Enables context-gated selection (18.2 E3 / M38) |
| Risks | Taxonomical churn in rule layer |
| Complexity | MEDIUM |
| Overfitting risk | LOW |
| Required telemetry | event-level direction + trend-at-break (v4) |
| Schema | v4 |
| Backtest | replay with context gate |
| WF/MC | standard |
| Grade | **B** |
| **Falsification** | Falsified if context-gated wr == ungated on holdout |

| Field | E4 |
|---|---|
| **Hypothesis** | BOS lifecycle telemetry (age at signal, break-bar geometry) is required before any break-semantics experiment |
| Literature | — (measurement) |
| Industry | best-practice indicators expose event fields |
| SuperCents_X | BOSEvent has breakBar but no age consumer (Types.mqh:33-42) |
| Sprint 17 evidence | 6.7 gaps 1-2 |
| Expected benefit | Unlocks E1/E2/E9 and wick-vs-close comparison |
| Risks | none |
| Complexity | LOW |
| Grade | **A** (prerequisite, merge into 18.2 E4 / M48 v4 append) |
| **Falsification** | n/a — measurement |

| Field | E5 |
|---|---|
| **Hypothesis** | Multi-level BOS reference (STH/ITH/LTH hierarchy, ICT) changes event quality vs latest-locked-only |
| Literature | ICT LTH/ITH; SMC most-recent — conflict (P1.4) |
| Industry | none of TV-1..4 implement hierarchy |
| SuperCents_X | latest locked only (BOSDetector.mqh:144-147) |
| Sprint 17 evidence | cannot measure (6.7.4) |
| Expected benefit | Unknown; resolves the strongest open implementation conflict |
| Risks | Event-set explosion; n splits |
| Complexity | MEDIUM |
| Overfitting risk | HIGH (many variants) |
| Grade | **C** (defer until E4 telemetry) |
| **Falsification** | Falsified if hierarchy variant ≤ latest-only on holdout |

| Field | E6 |
|---|---|
| **Hypothesis** | Volume/order-flow confirmation on BOS bars (Wyckoff) improves in-family wr |
| Literature | Wyckoff; Ederington-Lee (volume surge) [LT-…] |
| Industry | MT5-2 volume filter |
| SuperCents_X | no volume anywhere in structure layer |
| Sprint 17 evidence | cannot measure (6.7.6) |
| Expected benefit | Filters F3 low-liquidity fakes |
| Risks | tick-volume ≠ real volume in tester |
| Complexity | LOW (tick volume) |
| Grade | **C** |
| **Falsification** | Falsified if volume-surge subset ≤ base on holdout |

| Field | E7 |
|---|---|
| **Hypothesis** | Wick-break semantics (ICT informal) outperform close-break on the frozen data once geometry is serialized |
| Literature | conflict (P1.4) — no direct study |
| Industry | TV-1/4 wick, TV-2/3 close |
| SuperCents_X | close-only (BOSDetector.mqh:203, :251) |
| Sprint 17 evidence | cannot measure (6.7.1) — E4 telemetry prerequisite |
| Expected benefit | Resolves the #1 industry divergence |
| Risks | — |
| Complexity | MEDIUM |
| Grade | **B** (after E4) |
| **Falsification** | Falsified if wick-variant wr ≤ close-variant on holdout |

| Field | E8 |
|---|---|
| **Hypothesis** | Correctness fix: serialize the true first-crossing bar; guard cold-start/backfill (C2) — not a hypothesis, a defect |
| Literature | backtest-integrity standard |
| Industry | warm-up exclusion practice |
| SuperCents_X | BOSDetector.mqh:196-233 misattributes on cold start |
| Sprint 17 evidence | cold-start rows present in dataset (6.7.5) |
| Expected benefit | Event-set integrity; honest history |
| Risks | minimal (behavioral change at cold start only) |
| Complexity | LOW-MED |
| Grade | **A** (defect) |
| **Falsification** | Falsified if no dataset rows change after fix (i.e., no impact) — still worth doing |

| Field | E9 |
|---|---|
| **Hypothesis** | Equal-high handling (double-top reference, recent-wins) changes in-family outcomes |
| Literature | open problem (P1.7) |
| Industry | TV-3 recent-wins on ties |
| SuperCents_X | ties excluded (`<=`, SwingDetector.mqh:210-213) |
| Sprint 17 evidence | cannot measure (fractal geometry not serialized) |
| Expected benefit | Resolves F1; likely small |
| Complexity | LOW |
| Grade | **C** |
| **Falsification** | Falsified if tie-inclusive wr ≤ exclusive on holdout |

| Field | E10 |
|---|---|
| **Hypothesis** | Session-gating the BOS family (block h22-23; keep h04-17) removes the family's worst subset |
| Literature | regime conditioning (18.12) |
| Industry | session filters standard |
| SuperCents_X | SessionValidator inert (18.12 6.2) |
| Sprint 17 evidence | P6.3: h22-23 0.2156 (320 rows), h13-17 0.3474 — the strongest single BOS-family effect |
| Expected benefit | Removes -0.25R-class subset; converts family to neutral |
| Risks | none beyond n loss |
| Complexity | LOW |
| Overfitting risk | LOW (window from 18.13-tested hours) |
| Grade | **A** |
| **Falsification** | Falsified if h22-23-blocked expectancy ≤ unblocked on holdout |

| Field | E11 |
|---|---|
| **Hypothesis** | Reset resilience: on rates_total shrink, rebuild the structure pipeline from the preserved swing history (C3 defect) |
| Literature | — |
| Industry | MT5-1 full-reset pattern |
| SuperCents_X | SwingDetector.mqh:113-119 clears alone; pivot engine stalls (C3) |
| Sprint 17 evidence | n/a (runtime defect) |
| Expected benefit | Pipeline survives chart reloads/tester window shifts |
| Complexity | MEDIUM |
| Grade | **A** (defect) |
| **Falsification** | Falsified if no stall reproducible in a unit test — then it was already fixed |

---

## Proof Matrix ("Can we prove it?")

| Claim | Literature | Implementation | Telemetry | Tests | Conclusion |
|---|---|---|---|---|---|
| BOS never repaints | PARTIAL (close-based standard) | YES (bar≥1, immutable pivots, BOSDetector.mqh:196) | NO | NO | **Likely true** |
| BOS emitted exactly once per pivot | n/a | YES (consumed set :354-360) | NO | NO | **Likely true** |
| BOS fires only on locked pivots | YES (SMC standard) | YES (:160-177) | NO | NO | **Likely true** |
| Break is close-based | YES (Brooks/Donchian) | YES (:203,:251) | NO (no geometry) | NO | **True by code; unverified in data** |
| Reference = latest locked swing | PARTIAL (school conflict) | YES (:144-147) | NO | NO | **True by code; question open** |
| Trend derived from BOS | YES (SMC continuation) | YES (TrendState.mqh:85-144) | PARTIAL (hasBOS rows) | NO | **True** |
| No lookahead | YES (closed-bar discipline) | YES (bar 1 closed) | n/a | NO | **Likely true** |
| Cold-start misattribution exists | n/a | YES (code path C2) | PARTIAL (cold-start rows present) | NO | **Cannot currently prove; code path real** |
| BOS-family h22-23 drain | NO (open problem) | n/a | YES (P6.3: 0.2156) | n/a | **Proven by telemetry** |
| BOS+OB > BOS+Liquidity | PARTIAL (confluence doctrine) | n/a | YES (P6.6: 0.3731 vs 0.2976) | n/a | **Proven by telemetry** |
| In-family anti-calibration | NO | n/a | YES (P6.4) | n/a | **Proven by telemetry** |

---

## Traceability Matrix

| Experiment | Literature | Industry | Code | Evidence | Proof |
|---|---|---|---|---|---|
| E1 displacement | [LT-ICT/SMC consensus] | TV-2, MT5-3 | BOSDetector.mqh:203 | P6.1 | Partial |
| E2 retest telemetry | [LT-Brooks] | TV-3 | Types.mqh:33-42 | 6.7.2 | Partial |
| E3 BOS vs MSS label | [LT-ICT taxonomy] | TV-1..4 | TrendState.mqh:116-138 | P6.1-6.4 | Partial |
| E4 lifecycle telemetry | — | best-practice | Types.mqh:33-42 | 6.7.1-2 | None (new) |
| E5 multi-level reference | [LT-ICT LTH/ITH] | none | BOSDetector.mqh:144-147 | 6.7.4 | Weak |
| E6 volume | [LT-Wyckoff] | MT5-2 | (absent) | 6.7.6 | Weak |
| E7 wick vs close | [LT-conflict] | TV-1/4 vs TV-2/3 | BOSDetector.mqh:203,251 | 6.7.1 | Partial |
| E8 cold-start fix | — | warm-up practice | BOSDetector.mqh:196-233 | 6.7.5 | Strong (defect) |
| E9 equal highs | [LT-open problem] | TV-3 | SwingDetector.mqh:210-213 | 6.7.1 | Weak |
| E10 session gate | [LT-regime] | session filters | SessionValidator (inert) | P6.3 | Strong |
| E11 reset fix | — | MT5-1 | SwingDetector.mqh:113-119 | — | Strong (defect) |

---

## Verification Scorecard

| Area | Score | Basis |
|---|---|---|
| Research alignment | 88/100 | Close-based, lock-on-confirm design matches the strongest-evidence definition (P1.6); displacement/retest absent; wick school documented |
| Algorithm correctness | 58/100 | Design sound (exactly-once, no repaint, no lookahead) but C2 (cold-start loss/misattribution) and C3 (reset stall) are real defects; zero unit tests |
| Visualization | 92/100 | Renderer faithful to detector; SMC line semantics correct (P4b); cap-based deletion cosmetic |
| Pipeline | 85/100 | Ordering/dependencies correct (P5.2); duplication and missing reset/telemetry noted |
| Evidence support | 78/100 | BOS-family = 25.8% of signals; family drag identified; session effect strong; 6 measurement gaps explicit |
| Maintainability | 62/100 | Dead `isBroken` field, duplicated PP scan, O(B) loop, no tests, undocumented dual array orientation |
| **Overall** | **72/100** | Verified with material gaps: two real defects, no tests, family-level evidence weak except session windows |

---

## Findings Summary — Research Confidence × Destination

Every finding of this review routed to a home so nothing is lost
(per §4.13 of the locked methodology). Confidence is in the
*conclusion*, not the trade.

| Finding | Where | Confidence | Destination |
|---|---|---|---|
| C2 — cold-start misattribution / historical break loss | P3.5.2 | **Very High** (deterministic code path + dataset cold-start signature) | Sprint 20 defect fix (E8) |
| C3 — chart-reset stalls structure pipeline | P3.5.2 | **Very High** (deterministic code path: ID counter + `id ≤ lastProcessed` skip) | Sprint 20 defect fix (E11) |
| C6 — no automated tests on any structure subsystem | P3.5 | High (grep-verifiable; Proof Matrix "Tests" = NO) | Sprint 20 test scaffolding |
| C5 — dead `isBroken` field, duplicated source of truth | P3.5 | High (dead-field scan) | Sprint 20 cleanup |
| C4 — O(B) per-bar history rescan | P3.5 | High (code path) | Sprint 20 refactor (low impact) |
| C1 — array-orientation asymmetry swing stage vs docs | P3.5 | High (engine vs docs mismatch) | Standards/documentation fix during Sprint 20 defection work |
| Rendering faithful to logical event (distinct schools draw BOS differently) | P4b | Very High (renderer mirrors detector semantics) | None — standards only, no redraw work |
| BOS family underperforms baseline (wr 0.3115 vs base 0.3393) | P6 | **High** (frozen-dataset measurement, nth-of-166-signals 25.8%) | Sprint 20 gating/context experiment |
| BOS + Liquidity worst (0.2976) | P6 | High | Sprint 20 context matrix cell (with E10/other OB-FVG cells) |
| BOS + Order Block strongest (0.3731) | P6 | High | Sprint 20 confluence cell (M08) |
| Late-night drain h22-23 (0.2156) | P6 | High | Session gate (M06) |
| GBPJPY h13-17 strong (0.4414) | P6 | High | Session gate (M06) |
| BOS should require displacement | P1/P7 | **Medium** (literature consensus, no telemetry yet) | Experiment — E1 → M30 |
| BOS should require retest acceptance | P1/P7 | Medium | Experiment — E2 (telemetry first) |
| BOS should require volume confirmation | P1/P7 | **Low** (no volume column; Wyckoff only) | Research backlog (E6), gated on telemetry schema v3.1 |
| News-window gating | P4a/P6 | Medium | News gate M07 (18.12 E6) |

Non-findings intentionally excluded: no claim is made that a
"different schools" drawing difference is a bug (P4b); no
recommendation to redesign BOS — outcome is **Improve**, not
Redesign.

---

## Final Research Verdict

| Field | Value |
|---|---|
| Research Quality | **88** — the strongest-evidence definition (close-based, confirmed swing) is implemented; two optional doctrines (displacement, retest) missing |
| Implementation Quality | **58** — core invariants hold; cold-start and reset defects exist; no test coverage |
| Architecture Quality | **85** — clean 5-stage dependency chain; duplication minor |
| Visualization Quality | **92** — faithful, correct semantics |
| Evidence Quality | **78** — 6 explicit gaps; in-family evidence mostly negative except BOS+OB and session windows |
| Confidence | **B** — the evidence supports *gating* and *telemetry* experiments (E2/E4/E10) at A; the *semantics* experiments (E1/E7) are C-level pending telemetry |
| Overall Recommendation | **Improve** — do NOT redesign the detector; ship E4+E8+E11 (telemetry and defects), gate with E10, then revisit semantics (E1/E7) with real data |

Closure: the BOS subsystem is architecturally the cleanest part of
the structure layer and implements the defensible definition; its
problems are (1) two correctable defects (cold-start attribution,
reset stall), (2) total absence of automated tests, and (3) an
evidence profile in which the family only pays inside specific
OB/session cells. The AVP verdict is **Improve, not Redesign** —
consistent with the Golden Rule: the algorithm was understood
before any change is proposed.