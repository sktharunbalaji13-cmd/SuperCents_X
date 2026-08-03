# AVP 19.3 — Swing Detection: Deep Research & Verification

Methodology: **AVP v1.0** (frozen — [00], §4.13 Confidence ×
Destination × Outcome Classification applied). Sprint 18 docs cited,
never re-derived. Dataset: frozen Sprint 17 (18,686 rows, fingerprint
`2e74bbae…`). Code facts: `file:line`. No production code modified.

---

## Algorithm Passport

| Field | Value |
|---|---|
| Algorithm | Swing point detection (swing highs / swing lows) |
| Version Reviewed | v3.0-research-baseline (CSwingDetector) |
| Method applied | AVP v1.0 |
| Sprint | AVP 19.3 |
| Research sources reviewed | 30 (academic + practitioner + industry) |
| Industry implementations compared | 7 TradingView + 9 MT5 + 5 Python |
| Code files reviewed | 12 (Structure, Visualization, Confluence, Portfolio, Telemetry) |
| Dataset rows reviewed | 18,686 (decided+signal 17,073) |
| Swing direct telemetry | **NONE — all raw-evidence columns constant 0.00** |
| Verification Score | **67/100** |
| Overall Recommendation | **Improve** (core is sound and forensic-verified; fix dead wiring, parameterization, telemetry; no redesign) |

A reader must understand the outcome from this page alone.

---

## P1 — Deep Research (~80% of program effort)

### 1.1 Definition and why swing detection exists

A swing point is a **confirmed local extremum** of price used as the
atom of market structure. Every structure layer above it (pivot, BOS,
CHOCH, liquidity) decomposes into "price broke the most recent swing
extreme". Schools agree on the *concept* (local extreme, confirmed
with right-side bars, no repaint once confirmed) and disagree on the
*operationalization* (window size, wick vs body, equal-level policy,
significance filter).

- **Classic TA / Dow**: nested movements (major/secondary/minor) — a
  hierarchy of *significance-graded* swings; trend = successive higher
  peaks/troughs [LT-Murphy1999, LT-Rhea1932]. "Swing high" = N-bar
  windowed extreme [prac-Investopedia].
- **Bill Williams fractals**: the 5-bar fractal (middle bar HIGH
  strictly greater than the two highs on each side) — confirmed only
  at the close of the 5th bar; **2-bar right confirmation, zero
  repaint once confirmed** [LT-MetaQuotes, prac-ForexGeek].
  Practitioners reject raw fractals as noise generators on low
  timeframes ("dozens per session, most are random wicks") and
  recommend filtering [prac-Pineify, prac-LuxAlgoBlog].
- **ZigZag family**: depth/deviation/backstep parameters; the final
  leg **repaints** until locked by an opposite move — the classic
  "never trade the last leg" rule. The repaint engine is the backstep
  deletion of candidate extrema [MT5-Fedoseev, MT5-tradecharts,
  TV-ZZHelp].
- **SMC/ICT**: the 3-candle rule (a candle whose high exceeds the
  highs of the candles immediately before and after it, confirmed at
  the third close) [prac-LiquidityScan]; recursive tiers
  STH/ITH/LTH [prac-ICTKillzone]; internal vs swing-degree pivots
  (LuxAlgo: 5-49 vs 50-100 lookback) [TV-LuxDocs]. **Equal
  highs/lows are liquidity, not swings** [prac-LiquidityScan].
- **Academic**: local extrema in noise with a significance parameter
  that has an **optimal, non-monotone value** (El-Yaniv & Faynburd:
  2%-momentum beats both 0.1% and 5-10%) [AcCo-ElYaniv2012]; smoothing
  bandwidth is bounded by the inter-extremum distance
  [AcCo-mSTEM2025]; recursive smoothers outperform two-sided filters
  [AcCo-Grillenzoni2014]; swing-level breakouts strongly supported on
  the Dow 1897-1986 [AcCo-Brock1992] but marginal on 1990s US stocks
  [AcCo-Marshall2007].
- **Institutional**: quant trend systems largely do **not** use
  confirmed swing points (TSMOM/MA filters subsume linear filtering)
  [AcCo-Pedersen2016, AcCo-Sepp2019]; the swing-flavoured instruments
  actually deployed are rolling-window extremes with **zero lag and no
  confirmation** (e.g. new 50-day high entries) [AcCo-Brock1992,
  AcCo-Quantpedia].

Conclusion: the swing layer is the shared atom — every verdict on the
structure stack depends on it.

### 1.2 Historical context

Dow (1930s) → Williams fractals (1995) → MetaTrader ZigZag
commodification → SMC/ICT 3-candle and recursive hierarchies (2016+)
→ modern engines with internal/swing lookup splits. The
**windowed-confirmed-extremum** model has been stable for decades;
what changed is automation, not the definition.

### 1.3 Schools — per-school matrix

| Dimension | Classic | Williams fractal | ZigZag | SMC/ICT | Academic | Institutional |
|---|---|---|---|---|---|---|
| Definition | N-bar windowed extremum | 5-bar (2+2) strict rule | depth/deviation/backstep | 3-candle rule, recursive tiers | smoothed turning point | rolling max/min |
| Right confirmation | per config | 2 bars | opposite move | 1 bar (3rd close) | forward window | none (lag 0) |
| Price basis | wick (high/low) | wick | wick | wick + close confirm | series | wick |
| Equal levels | unspecified | strict, ties excluded | backstep deletes | = liquidity, not swing | strict | n/a |
| Significance filter | heuristic | none (noisy) | deviation | hierarchy tiers | sigma-optimality | none |
| Repaint | no (confirmed) | no | **last leg** | no (confirmed) | n/a | no |

### 1.4 Disagreements (explicit)

1. **Left/right bar counts**: (1,1) ICT 3-candle; (2,2) Williams
   fractal; (2,3) intraday / (5,5) daily; (5,5) smtlab default;
   (10,10) Pineify. The two-sided window is universal; its size is a
   free parameter.
2. **Wick vs body**: classic/fractals use wick high/low; ICT
   confirmation requires a body close beyond the swing. Our swings are
   wick-based (fractal definition) — consistent with the majority.
3. **Equal highs/lows**: strict (ICT, LiquidityScan) vs "left ties
   allowed, right ties invalidate" (TradingView pivothigh) vs
   ATR-tolerance band (LuxAlgo) vs collapse-to-extreme (smtlab). Our
   strict exclusion is the strictest family.
4. **Same-bar double pivots**: ICT allows one candle to be both
   swing high and low; TV ZigZag has `allowZigZagOnOneBar`; classic
   alternates strictly. Our high/low lists are independent.
5. **Confirmed vs provisional**: fractals are confirmed-only; TV
   paints pivot markers retrospectively (visually a repaint,
   informationally pure delay); ZigZag always has a provisional leg.
   We implement confirmed-only, append-only.
6. **Incremental vs whole-history**: ours is incremental; TV
   recomputes each bar.

### 1.5 Conflicting definitions (code-relevant)

- **Significance**: a 5-bar fractal on any timeframe marks bounces
  from random wicks; "only a small fraction of fractals matter" is the
  practitioner consensus — but we have **no significance filter**, so
  any 5-bar wiggle becomes a swing. This is the parent of the
  false-BOS/false-CHoCH problem (F3).
- **Ties excluded**: our strict `<` means an equal successive high
  never becomes a new swing — deterministic, and consistent with the
  practitioner consensus that EQH/EQL are liquidity, not structure.
  The LiquidityDetector handles them separately.

### 1.6 Which definition has the strongest evidence

A symmetric N-bar wick window with **strict comparisons, right-side
confirmation (>= N bars), append-only, never deleted** is the
defensible core [TV-1, PY-1, prac-Pineify]. Academic evidence favors a
moderate significance parameter over none or extreme
[AcCo-ElYaniv2012, AcCo-mSTEM2025]. Our `±2 strict fractal` is a
**valid subset**: correct confirm/locking semantics, missing only the
significance parameter the evidence recommends (18.1 E1 / M37).

### 1.7 Open research problems

1. Optimal lookback as a function of timeframe/volatility — no closed
   form (ours is hardcoded 2).
2. Swing ground truth — no labelled benchmark of "significant" swings;
   the "2-4 relevant swings per session" claim is subjective.
3. Whether STH/ITH/LTH recursion equals a real MTF pivot hierarchy —
   unexamined.
4. Tolerance calibration (strict vs ATR-scaled equal levels) — no
   comparative study.

## P1.5 — Formal Algorithm Specification (before code)

```
Input            : high[], low[], time[] — chronological (oldest first) arrays
Output           : confirmed SwingPoint (id, time, price, barIndex, isHigh)
Preconditions    : rates_total >= 5; center in [4, rates_total-3]
                   (2 left + 2 right bars must exist)
Postconditions   : swing appended once, never revised; id monotonic global;
                   equal highs/lows cannot qualify (strict inequality)
State            : append-only confirmed array; incremental scan cursor
                   m_lastCheckedCenter; id counter (1-based)
Invariants       : never repaints (bar written once, on full window);
                   ids globally unique and monotonic across high+low;
                   strict inequality (ties excluded)
Failure          : reset (rates_total shrink) -> Clear() wipes swings and
                   restarts IDs at 1 (S2); window too small ignored
```

**Complexity**

| Metric | Value |
|---|---|
| Time complexity | O(1) amortized per new bar (each center scanned once) |
| Memory complexity | O(#swings) + O(rates_total) arrays |
| Streaming suitability | YES |
| Incremental update | YES (partial scan via m_lastCheckedCenter) |
| Repaint risk | NONE (append-only, confirmed on full window) |
| Lookahead bias risk | NONE (uses only closed bars <= center+2) |

**State machine (conceptual)**

```
NoData -> Window(bar[c] has c±2) -> [strict extremum?] -> confirm -> append(immutable)
        -> advance windowCenter -> repeat
Reset  -> Clear() (events wiped, ids restart at 1) -> restart window
Note: confirmation ("lock") happens at bar c+2 close (2-bar right lag).
```

---

## P2 — Industry Implementation Survey

### 2.1 TradingView

- [TV-1] `ta.pivothigh/low(source, left, right)` — returns the pivot
  only after `right` bars complete; confirmed-only, retroactively
  painted marker (informationally pure delay). The de-facto standard,
  used in >15k scripts.
- [TV-2] reverse-engineered semantics: pivot = rightmost extremum of
  the 2N+1 window; left ties allowed, right ties invalidate.
- [TV-3] built-in ZigZag: left strict `>`, right `>=` (asymmetric);
  "solid line is not final; removed or redrawn" — repaint admitted.
- [TV-4] LuxAlgo SMC swings: trailing-window state machine; strictly
  retrospective ("not for real-time"); EQH/EQL tolerance `atr * eq`.
- [TV-5/6] ZigZag Pine libraries (DevLucem port, Reflex ZigZagCore):
  MT depth/deviation/backstep ports; staleness forcing.
- Lesson: the safe community default is confirmed strict-window pivots
  (TV-1); anything provisional is a repaint hazard.

### 2.2 MT5

- [MT5-1] `iFractals` (Williams 5-bar); confirm at 5th bar close;
  consumed via CopyBuffer with order offset.
- [MT5-2] same fractal definition; [MT5-3] `iZigZag`
  (Depth/Deviation/Backstep).
- [MT5-4] Fedoseev's canonical **incremental append-only array**
  pattern (counter-decrement, never true delete) — the melody-safe EA
  pattern our design matches.
- [MT5-5/7] ZigZagExtremaOnArray and "Ideal ZigZag" (no suspended
  peaks, history-insertion safe).
- [MT5-6] parameters deep-dive: never trade the provisional last leg;
  H1 depth 12, D1 24-50.
- [MT5-8] ATR swing-strength filter + per-context incremental state —
  production EA pattern.
- [MT5-9] redraw monitor quantifying repaint (defaults 12/5/3).
- Lessons: append-only confirmed structure is the MT5 community norm;
  our design matches it. ATR/prominence filters are standard MT5
  production practice that we lack.

### 2.3 Python

- [PY-1] smtlab `swing_highs_lows(ohlc, swing_length=5)` — symmetric
  window; consecutive same-direction pivots collapse to the more
  extreme.
- [PY-2] vectorbt `local_extrema_apply_nb` — threshold-based extrema
  with the standard "future window may look-ahead" warning.
- [PY-3] label-only recipe: `high == high.rolling(2N+1,
  center=True).max().shift(N).ffill()` — exposes only confirmed
  levels; the lookahead-safe backtest standard.
- [PY-4] scipy `argrelextrema(order=WINDOW)` + KDE level clustering.
- Lesson: backtests must consume **confirmed-only** levels — the same
  discipline our detector enforces by construction.

---

## P3 — SuperCents_X Implementation Review (facts only)

### 3.1 Pipeline position

`Swings(1) -> Pivots(2) -> BOS(3) -> Trend(4) -> Protected(5) ->
CHOCH(6) -> OB(7) -> FVG(8) -> Liquidity(9)` (Sprint 7 forensic spec).
`SymbolContext.mqh`: `m_swingDetector.Update(high, low, time,
rates_total)` :627-628 runs **before** `ArraySetAsSeries(...)` :633-637;
pivot engine :640-641; BOS :647-648; Trend :654-655; CHOCH :673-674;
Liquidity :707-708. Timing recorded under MODULE_SWING_DETECTOR :630
(**pivot timing also logged under the same module** :643); health
:878-880; init :278; shutdown :957-962.

### 3.2 CSwingDetector (`Structure/SwingDetector.mqh`, 305 lines)

- Rule hardcoded 5-bar fractal: `IsSwingHigh` strict `c > neighbor(±2)`
  :204-216 (`<=` early-exit :210-213); `IsSwingLow` mirror :218-230.
- Equal highs/lows = **ties excluded** (strict).
- `Update` requires `rates_total > 5` (:110-111); first center = 4
  (:131-133); `maxCenter = rates_total - 3` (:114).
- Incremental: `startCenter = m_lastCheckedCenter + 1` (:131); scan
  oldest->newest (:149-162); `m_lastCheckedCenter = maxCenter` (:165);
  heartbeat every 500 updates (:137-141).
- Confirmation: a swing is written only when the full ±2 window
  exists — **2-bar right-lag lock** (:114); never deleted or revised
  after write (:232-274).
- Reset: `maxCenter < m_lastCheckedCenter` (:113-119) -> `Clear()`
  wipes all swings, IDs restart at 1 (:181-191) -> **S2 desync with
  the pivot engine**.
- Complexity O(bars) amortized; chunked arrays (+256) (:235-236,
  :257-258); counters (:29-33).
- `IsValidBarIndex` declared (:193-202) but **never called in
  `Update`** — dead helper.

### 3.3 Consumers

- **StructuralPivotEngine** (primary): two-pointer merge of highs and
  lows by global id, smaller id first (:114-149); gate
  `s.id > m_lastProcessedSwingId` (:147). Uses id, isHigh, time,
  price, barIndex.
- **LiquidityDetector**: EQH/EQL via incremental cursors (:26-27),
  3-pip tolerance + 0.5pt epsilon, partner search back 100 swings,
  midpoint level (:154-197). Relies on the same global-id ordering.
- **Confluence Premium/Discount**: `DetectionContext.swingHigh/
  swingLow` (:63-91) read by PremiumDiscountEvaluator (:13-14) — but
  **`BuildDetectionContext` (ConfluenceEngine.mqh:515-526) never sets
  them**. At runtime the evaluator always receives 0.0 -> `InvalidRange`
  score 0. Sprint-14 docs record the switch-away: "with unset swings;
  switched to CLiquidityEvaluator" (`Sprint14_Calibration.md:60`). Only
  unit tests populate the fields (S1).
- **Entry/Exit**: `TARGET_PREVIOUS_SWING`
  (ExecutionPlanTypes.mqh:36) resolves TP to `bos.pivotPrice`
  (TargetResolver.mqh:104-126) — swings reach exits **via pivots**
  (two-hop).

### 3.4 Rendering (`Visualization/SwingRenderer.mqh`, 213 lines)

- Objects `SCX_SWING_HIGH_<id>` / `SCX_SWING_LOW_<id>`; OBJ_ARROW_DOWN
  / OBJ_ARROW_UP at `sp.time`, offset ±50 points (SwingRenderer.mqh:15,
  :180, :203) — anchor at swing bar time, no candle-ownership tracking.
- Colors `COLOR_SWING_HIGH 0xE53935` (red) / `COLOR_SWING_LOW
  0x43A047` (green); `_HIST` dim variants (ChartStyle.mqh:9-10, :39-40).
- Incremental draw from `m_lastRenderedHighCount/LowCount` (:99-140);
  deletes objects older than `SwingRenderHistoryBars = 300` with
  `MaxHistoricalSwings = 50` cap (:61-144; RenderConfig.mqh:18,71).
- Layer order: FVG -> OB -> PP -> BOS -> CHOCH -> Swings -> Pivots
  (spec QA 245-246).

### 3.5 Tests / telemetry

- **Forensic docs APPROVED**: `SWING_DETECTOR_FORENSIC.md` (2,016
  bars, 7,050 swings, 98/100 quality; no repaint; unique IDs 1..7,050;
  ties excluded; no ID reuse; deterministic). `STRUCTURAL_PIVOT_
  FORENSIC.md` (7,050 swings -> 4,032 pivots, 57.19% promotion, strict
  alternation). `SPRINT35_FORENSIC.md` (5,621 pivots, 13.8% replaced).
- **No unit tests** for SwingDetector/Pivot/BOS/Trend/PP
  (TestSuite.mqh: 18 units, none structural).
- **Telemetry: no swing columns.** In the frozen dataset all
  raw-evidence columns are constant 0.00 and `hasProtectedPoint` never
  TRUE (P6) — the swing->pivot evidence path is uninstrumented.

## P3.5 — Algorithm Correctness Verification

### 3.5.1 Checklist vs P1.5 spec

| Item | Result | Basis |
|---|---|---|
| Swing selection correct | PASS | strict 5-bar fractal, closed bars only (center 4..rates-3 guards) |
| Equal highs/lows handled | PASS | strict `<=` excludes ties (:210-213, :224-227), deterministic policy |
| No repaint | PASS | append-only, written once on full window (forensic 98/100) |
| Once-only emission / unique ids | PASS | ids monotonic global, no reuse (forensic tested) |
| Determinism | PASS | pure function of bars + cursor, independent of ticks |
| Incremental correctness | PASS | cursor-based partial scan |
| **Reset/backfill resilience** | **FAIL** | Clear() resets ids to 1 but pivot cursor never resets — stall (S2) |
| **Parameter contract** | **WARN** | 2/2 hardcoded; SWING_STRENGTH/LOOKBACK dead (F4) |
| **Significance filter** | **FAIL** | none — any 5-bar wiggle is a swing (F3) |
| **Unit tests** | **FAIL** | none |
| **Runtime wiring of swing consumers** | **WARN** | Premium/Discount feed never set at runtime (S1) |

### 3.5.2 Findings

**S1 — Premium/Discount evaluator dead in production (Implementation
Defect).** `DetectionContext.swingHigh/swingLow` are only ever set in
tests and benchmarks (TestConfluenceEngine.mqh:71-132,
BenchmarkConfluence.mqh:153). `ConfluenceEngine::BuildDetectionContext`
(:515-526) does not populate them — at runtime `PremiumDiscountEvaluator`
always scores `InvalidRange = 0`. The swing-based premium/discount
component of the confluence score is functionally **off**. No
production code path consumes swing levels for evaluation; swings feed
pivots and liquidity only.

**S2 — Reset desync (shared E11 family, FAIL).** On `rates_total`
shrink, `SwingDetector` logs "rescanning" and calls `Clear()`
(:113-119, :181-191), wiping all swings and restarting IDs at 1
(SwingDetector.mqh:67). The pivot engine's `m_lastProcessedSwingId`
is not reset (StructuralPivotEngine.mqh:70, :147, :272), so every
post-reset swing (id <= lastProcessed) is skipped forever. Structure
stalls silently after any chart reset — the same defect family as BOS
C3 and CHOCH C2, and the "rescanning" log is a false promise.

**S3 — All structural raw-evidence telemetry is constant 0.00
(Measurement Gap / telemetry defect).** Measured on the frozen dataset:
`structureRaw`, `structureContribution`, `structureWeight`, and the
other layer raws (`trendRaw`, `liquidityRaw`, `obRaw`, `fvgRaw`,
`pdRaw`) are `0.00000000` for **all 17,073 decided+signal rows**
(unique values: 1). `hasProtectedPoint` is FALSE in all 18,536 decided
rows ("never true"). The swing->pivot evidence path is nonfunctional
in telemetry (P6). Swing quality is therefore unmeasurable from the
frozen set.

**F3 — No significance filter (Missing Feature).** Any 5-bar local
extremum is a swing — every range bounce qualifies. P1 consensus:
significance/prominence/ATR is the industry norm (MT5-8, LuxAlgo,
AcCo-ElYaniv2012); 18.1 E1 / M37.

**F4 — 2/2 hardcoded; SWING_STRENGTH / SWING_LOOKBACK_BARS are dead
config (Missing Feature).** `Constants.mqh:71-72` defines them but no
code reads them (grep confirmed); the detector hardcodes ±2.
Parameterization exists only in the design-time
`StructureParameters` struct (Sprint-18 Optimization Framework), never
wired.

**F5 — Stale API doc (Low).** `docs/SwingDetector_API.md:73` says
"IDs start at 0"; code and forensic log both start at 1
(SwingDetector.mqh:67, SWING_DETECTOR_FORENSIC:138). Misleading for
Sprint 20.

**F6 — No unit tests (Measurement Gap).** Forensic acceptance is
strong (98/100) but no automated regression covers the swing layer.
The "frozen" contract rests on forensic-only evidence (C6/C1 analog in
BOS/CHOCH docs).

**F7 — Chronological array orientation (Architectural Limitation,
shared with BOS C1).** Swing is fed chronological (index 0 = oldest)
while `docs/Pipeline.md:25-30` documents series convention (index 0 =
newest). Both self-consistent, but a maintainer "fixing" to the
documented convention would silently invert swing barIndex/order.

**F8 — Pivot timing mislabel (Low).** `SymbolContext.mqh:643` records
pivot engine timing under `MODULE_SWING_DETECTOR` — diagnostics
confusing.

### 3.5.3 Failure Catalog (swing-specific)

| # | Failure | Definition | Literature | Industry | Our impl | Evidence | Rec |
|---|---|---|---|---|---|---|---|
| SL-F1 | Noise whipsaw | 5-bar fractal on every range bounce floods swings | prac-Pini, Brooks | ATR/prominence filters | none (F3) | cannot measure (no swing cols) | 18.1 E1 / M37 |
| SL-F2 | Equal highs/lows | EQ-level invisible to structure | SMC: = liquidity | collapse/tolerance | strict-exclude | cannot measure | E9 EQH policy |
| SL-F3 | Repaint | candidate swings flip before lock | ZZ admits | no repaint | append-only, no repair | PASS forensic | none |
| SL-F4 | History insert / reset | reset redraw changes IDs | MT5-7 hazard | safe incremental | Clear-on-shrink (S2) | n/a | reset fix E11 |
| SL-F5 | Trending lag | 2-bar right lag delays trend signal | Brooks | trade the 2-lag | consistent (2-lag) | cannot measure | lag experiment (E) |
| SL-F6 | Same-bar double swing | high and low on one bar | TV allows | per policy | independent lists OK | n/a | none |

---

## P4 — Visualization

### P4a — Logical event

**Verdict: YES — 85/100.** The swing at c with strict comparisons and
a full ±2 confirm window is exactly the de-facto confirmed-extremum
standard; correctness here is the highest-confidence guarantee in the
whole structure stack (forensic 98/100, append-only, no repaint, no
ID reuse). Two event-level notes:
- Without a significance filter (F3), the event *set* is complete but
  noisy: any local extremum qualifies, so every downstream BOS/CHoCH
  inherits range noise. The event semantics are right; the filter is
  the attenuation level.
- Equal-tie exclusion means EQ levels never emit swings — intentional,
  consistent with the "equal = liquidity" doctrine and the separate
  LiquidityDetector.

### P4b — Rendering

**Verdict: 90/100.** Arrows at swing bar time with ±50pt offset,
red/green, id-named objects, incremental draw plus documented deletion
(SwingRenderHistoryBars=300, MaxHistoricalSwings=50) — faithful and
deterministic. No data dependencies, no spec-color drift (unlike BOS /
CHOCH). Cosmetic only: arrows are anchored beside the extreme, with a
60-pt offset; visual clutter cap documented.

---

## P5 — Pipeline Validation + Data Contracts

```
Stage:      SwingDetector
 Input:         high[], low[], time[] (chronological, oldest-first)
 Output:        swing points (append-only, monotonic global id)
 Assumptions:   center±2 exists; chronological order
 Guarantees:    never repaints; no id reuse; ties excluded
 Consumer:      pivot engine (1), liquidity detector (2), renderer,
                (unwired: premium/discount — S1)

Stage:      StructuralPivotEngine
 Input:         swing list (id-ordered)
 Output:        locked pivots (id-stable), isProtected
 Guarantees:    strict alternation; monotonic id cursor
 Consumer:      BOS, protected-point manager, renderers

(Swing-as-price reaches exits indirectly: TP via BOS pivots — 2-hop.)
```

### P: Pipeline questions (explicit answers)

1. **Is ordering correct?** YES — swing runs before pivot/liquidity.
2. **Can a consumer fire without swings?** Pivots: no. But the
   raw-evidence telemetry is never populated (S3), so no structural
   score component actually uses swing data live.
3. **Are state transitions consistent across modules?** NO — the ID
   reset contract is broken: `Clear()` resets one consumer's cursor
   (swing) but not the pivot engine's (S2).
4. **Redundant?** `IsValidBarIndex` dead helper; pivot timing logged
   under MODULE_SWING_DETECTOR.
5. **Missing?** parameterized strength; significance filter; multi-TF
   alarm; swing telemetry.

## P6 — Sprint 17 Evidence Review (measured only)

Reuse of 18.x tables as-is; new measurements marked (new).

### 6.1 Reuse — downstream flags (18.1 §7)

| Family | n | wr |
|---|---|---|
| BOS_OB_BULLISH | 440 | 0.3705 |
| BOS_OB_BEARISH | 417 | 0.3765 |
| LIQUIDITY_BOS_BULLISH | 1,853 | 0.2822 |
| LIQUIDITY_BOS_BEARISH | 1,700 | 0.3124 |
| CHOCH_OB_REVERSAL | 342 | 0.3567 |
| hasBOS TRUE (all) | 4,410 | 0.3116 vs 0.3394 (Δ −0.0278) |

### 6.2 NEW — structural evidence pipeline is inert (critical)

Scanned all decided+signal rows (17,073) for the swing-upstream raw
evidence columns:

| Column | Rows with non-zero | Unique value |
|---|---|---|
| structureRaw | **0** | 0.0 (all rows) |
| structureContribution | **0** | 0.0 |
| structureWeight | **0** | 0.0 |
| trendRaw / liquidityRaw / obRaw / fvgRaw / pdRaw | **0** | 0.0 |
| hasProtectedPoint | **0 TRUE** | FALSE in all 18,536 decided rows |

The entire structural (indeed every-layer) raw-evidence telemetry was
**never populated** in the frozen Sprint 17 run. `structureRaw`
measures nothing; `hasProtectedPoint = TRUE` never occurs even though
BOS/CHOCH require protected points — coherent with a non-wired
telemetry path. No direct swing column exists. **Swing point quality
(significance, size, recency) is unmeasurable from the frozen set**
(18.1 §7.4 already flagged this). This is the dominant evidence
finding: an instrumentation gap, not an algorithmic one.

### 6.3 NEW — layerStructural is the only surviving structural proxy

`layerStructural` (score layer, 0-50) is populated: mean 23.4,
min 15, max 35. Quantile split:

```
layerStructural <= 25 : n=15,873  wr 0.3294
layerStructural > 25  : n=1,200   wr 0.3683    (Δ +3.9 pp)
```

**Stress-test interpretation:** the top-25 subset (n=1,200) is
decomposable exactly into the two known confluence families —
`hasBOS=TRUE` (858) and `hasCHOCH=TRUE` (342) — with
`hasOrderBlock=TRUE` on all 1,200. The Δ therefore reflects BOS_OB +
CHOCH_OB precision, **not** swing quality itself. Swing adds no
measurable increment separable from those families in this run (honest
gap).

### 6.4 NEW — reset correlation with the (only) instrumented layer

No dataset evidence can separate "swing-layer effect" from
"family effect"; the swing stage earns the **weakest evidence score of
the series** — not because it is wrong, but because the frozen data
cannot speak to it. Every positive structural read in the set is
downstream (BOS/CHOCH families) — confirmed again in 6.3.

### 6.5 What the dataset cannot measure (explicit)

1. Swing existence / timestamp / price / barIndex — no column.
2. Swing size vs ATR (significance) — impossible.
3. Swing recency vs signal (how recent the relevant swing is).
4. Swing degree (internal vs swing-order).
5. Multi-TF alignment of swing tiers.
6. Any structural score contribution (structureRaw = 0).
7. Protected-point presence — never true in 18,536 rows.
8. Premium/Discount component — dead at runtime (S1), no data.

---

## P7 — Experiment Backlog (full cards)

| # | Hypothesis | Evidence | Lit | Industry | Expected benefit | Complexity | Overfit risk | Falsification |
|---|---|---|---|---|---|---|---|---|
| E1 | Swing significance / ATR / prominence filter | 18.1 E1 | AcCo-ElYaniv2012 | TV-8, MT5-8 | fewer, more meaningful swings | med | med | **Fals if: filtered-swing-derived wr does not improve over the unfiltered set, or n collapses below k=100** |
| E2 | Parameterize SWING_STRENGTH / SWING_LOOKBACK | 18.1 | — | TV-1, PY-1 | configurable backtest | low | low | **Fals if: 2/2 is already optimal and wider windows do not lift wr** |
| E3 | Wire the Premium/Discount swing feed (S1) | — | — | LuxAlgo | enable the PD component | low | low | **Fals if: once wired, the component still scores InvalidRange=0 or adds no layer value** |
| E4 | Reset / cursor repair (S2) | E11 | — | MT5-3 | restore structure after reset | low | low | **Fals if: after a reset new swings are still skipped forever** |
| E5 | Swing telemetry v4.1 (significance, size/ATR, recency) | 18.1 §7.4 | — | TelemetryTypes | enable any swing-layer measurement | low | med | **Fals if: after instrumenting, structureRaw is still 0.0** |
| E6 | Equal-level policy: strict vs smtlab collapse vs Lux tolerance | 18.1 E9 | — | PY-1, TV-4 | policy research dataset | med | med | **Fals if: an equal-policy variant does not beat strict-exclusion on hold-out** |
| E7 | Multi-TF swing alignment | 18.1 E3 | — | LuxAlgo internal/swing | HTF context precision | med | med | **Fals if: HTF-aligned swings show no wr gain** |

M-card links: E1 → M37 (significance), E7 → 18.1 E3, E3 → M12-M16
(calibration PD), E5 → M41 (telemetry) — per master backlog.

---

## Proof Matrix

| Claim | Literature | Implementation | Telemetry | Unit tests | Conclusion |
|---|---|---|---|---|---|
| "Swing never repaints" | YES | YES | NO | forensic log | proven by forensic impl; no data |
| "Ties strictly excluded" | YES (SMC) | YES | NO | NO | proven by code |
| "IDs monotonic + unique" | — | YES | NO | forensic (7,050) | proven by forensic log |
| "Reset is safe" | — | **FAIL (S2)** | YES | NO | disproved by code |
| "Config parameterizable" | YES | **NO (dead)** | NO | NO | Missing Feature |
| "Raw evidence is captured" | n/a | **NO** | **NO (0.0)** | NO | disproved by dataset (6.2) |
| "PD evaluator works live" | — | **NO** | NO | tests only | **disproved at runtime (S1)** |
| "Swing adds measurable wr" | PARTIAL | n/a | **NO** | NO | **cannot prove** (6.5) |

---

## Traceability Matrix

| Experiment | Literature | Industry | Code | Evidence | Proof strength |
|---|---|---|---|---|---|
| E1 | AcCo-ElYaniv2012 | TV-8, MT5-8, PY-2 | SwingDetector.mqh:204 | 6.1 (flags) | Weak |
| E2 | — | TV-1, PY-1 | Constants.mqh:71-72 | 6.2 (no raw) | Weak |
| E3 PD wiring | — | LuxAlgo | ConfluenceEngine.mqh:515-526 | S1 | Strong (code) |
| E4 reset fix | — | MT5-3 full-reset | SwingDetector.mqh:113, StructuralPivotEngine.mqh:147 | S2 | Strong (code) |
| E5 telemetry | 18.1 §7.4 | — | TelemetryTypes.mqh | 6.2 (all zeros) | Strong (symptom) |
| E6 equal policy | LT-SMC | smtlab | SwingDetector.mqh:210-213 | 6.3 | Weak |
| E7 MTF | 18.1 E3 | LuxAlgo | — | 6.4 | Weak |

---

## Verification Scorecard

| Area | Score | Basis |
|---|---|---|
| Research alignment | 85/100 | confirmed strict window = de-facto standard; subset with a significance gap |
| Algorithm correctness | 74/100 | core strong (forensic 98/100: strict, no reuse, no repaint) but S2 reset defect, no tests, dead param |
| Visualization | 90/100 | arrows faithful; id naming; documented retention model |
| Pipeline | 68/100 | swing wired to pivots+liquidity; PD evaluator dead (S1); cursor desync (S2); timing mislabel |
| Evidence support | 52/100 | **all raw columns 0.0**, hasProtectedPoint never true, no swing columns; only confounded layer (6.3) |
| Maintainability | 56/100 | dead constants, stale API doc, no parameter, no tests, no telemetry |
| **Overall** | **67/100** | verified with significant gaps — the layer that feeds everything is the least instrumented |

Banding: 67 ∈ [60-74] — "verified with significant gaps".

---

## Findings Summary — Confidence × Destination × Classification

| Finding | Confidence | Classification | Destination |
|---|---|---|---|
| S1 — Premium/Discount evaluator dead in production | **Very High** (runtime all-InvalidRange, code line) | Implementation Defect | Sprint 20 wiring fix + test |
| S2 — reset Clear() desyncs pivot cursor | **Very High** (deterministic) | Implementation Defect | Sprint 20 (E11 family) |
| S3 — all raw evidence columns const 0.00, hasProtectedPoint never TRUE | Very High (frozen measurement) | Measurement Gap (instrumentation) | Sprint 20/21 telemetry (E5, M41) |
| F6 — no unit tests | High | Measurement Gap | Sprint 20 scaffold |
| F3 — no significance filter | High (community consensus + partial academic) | Missing Feature | M37 (18.1 E1) |
| F4 — hardcoded 2/2, config dead | High | Missing Feature | Sprint 20 parameterization (E2) |
| SL-F2 — equal highs/lows strict-exclusion policy | High | Research Hypothesis (E9) | Research backlog → M37 |
| F7 — chronological array orientation vs docs | High | Architectural Limitation | tie into BOS C1, Sprint 20 contract |
| F5 — stale API doc (IDs "start at 0") | Low | Implementation Defect | Sprint 20 docs fix |
| P6 — layerStructural>25 == BOS_OB+CHOCH_OB union | High | Research Hypothesis (confounded) | note only; not an edge |

---

## Final Research Verdict

| Field | Value |
|---|---|
| Research Quality | **85** — confirmed strict-window matches the de-facto standard; significance gap acknowledged per literature |
| Implementation Quality | **74** — guarantees are real (forensic 98/100); S2 is a real defect; no unit tests; dead config |
| Architecture Quality | **68** — right feed to pivots+liquidity; PD evaluator and raw telemetry dead; cursor ownership split (S2) |
| Visualization Quality | **90** — faithful, id-stable, no drift |
| Evidence Quality | **52** — swing itself unmeasurable (raw = 0.0, hasProtectedPoint never true); layer>25 is stack of two known confluence families |
| Confidence | **B** — verified guarantees are trustworthy; everything quantified about swing is not |
| Overall Recommendation | **Improve** — fix S1/S2, add F3/E1 significance, then instrument the raw columns; do NOT touch the core 5-bar fractal itself |

Closure: the swing stage is where the shape of the whole stack is
decided, and it is simultaneously the best-correct and least-verified
component: its algorithm is the industry-standard confirmed-fractal
with forensic proof of no-repaint, no-ID-reuse and determinism — but
its consumers are only half-wired (PD feed dead), its reset path is
broken (S2, shared family), it has no significance filter and no
unit tests, and the frozen dataset carries no swing evidence at all
(all raw columns constant zero). Per the Golden Rule the algorithm
stays as-is; the engineering backlog is to repair wiring, add
significance and instrument the evidence path, then re-verify under
Sprint 20/21. **Verdict: Improve, not Redesign.**

