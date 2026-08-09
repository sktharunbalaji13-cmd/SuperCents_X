# SuperCents_X — Visual Specification v2.0

**Version:** 2.0  
**Author:** SMC Architecture Team  
**Status:** Single Source of Truth (Architecture Freeze)  

---

## 0. GENERAL DRAWING RULES

Every object follows these invariants unless explicitly overridden by its type section.

| Rule | Implementation |
|---|---|
| No infinite rays | `OBJPROP_RAY_RIGHT = false` on all trend lines |
| Finite start and end | `ObjectCreate(name, type, 0, time1, price1, time2, price2)` always provides both anchor points |
| Active extends until freeze | On each `Update()`, the Centralized Visual State Engine calls `ObjectMove(point_2)` to advance the right anchor |
| No repaint | `CreateObjectIfMissing()` → `ObjectFind()` guard — object created once, never re-created |
| No jump | End point always advances monotonically forward in time; never shrinks |
| Labels near break event | Label time = `breakTime + PeriodSeconds(_Period) / 2` (for level-based objects, label stays near the event, not the start of the line) |
| Labels avoid other labels | `ResolveLabelPrice()` with 20-point step, 10-iteration max, 2-hour time window |
| Three-tier opacity | Active = 100% (`STYLE_SOLID`, full color), Frozen = 60% (`STYLE_DASH`, dimmed color), Historical = 35% (`STYLE_DASHDOT`, further dimmed) |
| Premium palette | All colors defined in §12. Single definition per conceptual type |
| Layer order | Defined in §11 — candles at bottom, labels at top |
| `ChartRedraw(0)` | Called once per `Update()` by VisualizationManager after all renderers run |

### Opacity Simulation (MT5 Limitation)

MT5 has no native object alpha. Opacity is simulated by blending the base color toward the chart background color (`clrBlack` for dark themes):

```
DimColor(color, factor):
  r = GetR(color) * factor
  g = GetG(color) * factor
  b = GetB(color) * factor
  return ColorFromARGB(r, g, b)
```

| Tier | Factor | Line Style | Width |
|---|---|---|---|
| Active (100%) | 1.0 | `STYLE_SOLID` | 2 (lines), 1 (rect borders) |
| Frozen (60%) | 0.6 | `STYLE_DASH` | 1 |
| Historical (35%) | 0.35 | `STYLE_DASHDOT` | 1 |

---

## 1. UNIVERSAL VISUAL LIFECYCLE

Every visual object on the chart passes through a strict lifecycle. Each type may skip phases that do not apply, but the sequence is invariant.

```
        ┌──────────┐
        │ Detected │  Algorithm confirms the structure in data
        └────┬─────┘
             │
        ┌────▼─────┐
        │   Draw   │  ObjectCreate() called once; both anchors set
        └────┬─────┘
             │
        ┌────▼─────┐
        │  Active  │  Object is the current/relevant instance of its type
        └────┬─────┘
             │
        ┌────▼──────┐
        │  Extend*  │  (Optional) Right anchor advances to currentTime each bar
        └────┬──────┘
             │
        ┌────▼──────┐
        │  Freeze   │  Superseded/mitigated/filled; right anchor locks; opacity → 60%
        └────┬──────┘
             │
        ┌────▼─────────┐
        │  Historical  │  Not the immediate predecessor; opacity → 35%
        └────┬─────────┘
             │
        ┌────▼────┐
        │  Delete │  ObjectRemove() called; removed from chart
        └─────────┘
```

*\*Extend phase only exists for types whose right anchor advances each bar.*

### Lifecycle Table Per Type

| Type | Draw | Active → Extend | Freeze Trigger | Historical Trigger | Delete Trigger |
|---|---|---|---|---|---|
| Swing High | Yes | Never extends (static arrow) | N/A | N/A | Count > `MaxHistoricalSwings` |
| Swing Low | Yes | Never extends (static arrow) | N/A | N/A | Count > `MaxHistoricalSwings` |
| Pivot | Yes | Never extends (static marker) | N/A | N/A | Count > `MaxHistoricalPivots` |
| **BOS** | Yes | **Extends** each bar | New BOS detected | Superseded by next BOS | Count > `MaxHistoricalBOS` |
| **CHOCH** | Yes | **Extends** from PP to break candle (then freeze)* | Break candle confirmed | New CHOCH detected | Count > `MaxHistoricalCHOCH` |
| **Protected High** | Yes | **Extends** each bar | New PH activated | Superseded by next PH | Count > `MaxHistoricalPP` |
| **Protected Low** | Yes | **Extends** each bar | New PL activated | Superseded by next PL | Count > `MaxHistoricalPP` |
| **Order Block** | Yes | **Extends** each bar | Mitigated (price enters OB zone) | N/A (skips Historical) | Engine marks invalidated, OR count > `MaxHistoricalOB` |
| **FVG** | Yes | **Extends** each bar | Filled (price trades through gap) | Oldest frozen FVG | Count > `MaxHistoricalFVG` |

*\*CHOCH Extend phase is one-shot: the line extends from the protected point start to the break candle time in a single Update cycle, then enters Freeze immediately. It does not advance past the break candle.*

### State Transition Rules

1. **Detected → Draw**: Guaranteed to happen in the same `Update()` cycle. No visual is ever "pending".
2. **Active → Extend**: Only for types with `Extends each bar` = Yes. The Centralized Visual State Engine calls `ObjectMove()` on the right anchor.
3. **Freeze**: The right anchor point 2 is set to the freeze time and never moved again. Opacity drops to 60%. Line style changes to `STYLE_DASH`.
4. **Historical**: Opacity drops to 35%. Line style changes to `STYLE_DASHDOT`. Only applies to the second-oldest object (not the most recent frozen one).
5. **Delete**: Objects are deleted in FIFO order when their type exceeds the max historical count.

---

## 2. CENTRALIZED VISUAL STATE ENGINE

All extension, freeze, historical, and deletion logic lives in a single engine rather than being duplicated across seven renderers.

### Interface

```
VisualStateEngine:
  ─────────────────────────────────────────────────────
  Extend(name, type, time2, price2)
    → Moves point 2 of OBJ_TREND or OBJ_RECTANGLE to (time2, price2)
    → Skips if object not found (ObjectFind check)
    → Skips if already frozen (checked via internal state)

  Freeze(name, type, freezeTime, price)
    → Locks point 2 at (freezeTime, price)
    → Sets STYLE_DASH
    → Dims color to 60%
    → Marks internal state as frozen

  PromoteToHistorical(name)
    → Dims color to 35%
    → Sets STYLE_DASHDOT
    → Marks internal state as historical

  Delete(prefix, maxCount, currentCount)
    → While currentCount > maxCount:
        DeleteObjectsByPrefix(prefix + "_" + oldestId)
        Shift array left, decrement count

  DeleteSingle(name)
    → ObjectFind check, then ObjectDelete(line/rect + text)

  GetState(name) → {active, frozen, historical}
```

### Internal State Tracking

The engine maintains a parallel array of `{name, type, state, freezeTime, freezePrice}` for each managed object. This allows stateless renderers — they delegate all visual mutation to the engine.

### Renderer Contract

Each renderer's `Update()` becomes:

```
Update():
  1. Query detector for new events since lastRenderCount
  2. For each new event: call VSE.Draw() via CreateObjectIfMissing
  3. If a new event supersedes the previous active:
     call VSE.Freeze(previousActive)
  4. If current active is still active and should extend:
     call VSE.Extend(currentActive)
  5. Call VSE.PromoteToHistorical() for objects that are 2+ generations old
  6. Call VSE.Delete() to enforce max historical limit
```

No renderer directly calls `ObjectMove()`, `ObjectSetInteger()`, or `ObjectSetDouble()` for visual state changes. All visual mutations go through the engine.

---

## 3. SWING HIGH

| Property | Value |
|---|---|
| Detection condition | 5-bar fractal: `H[center] > H[center-2] && H[center] > H[center-1] && H[center] > H[center+1] && H[center] > H[center+2]` |
| Object type | `OBJ_ARROW_DOWN` |
| Object name | `SCX_SWING_HIGH_<id>` |
| Start point (time) | `sp.time` (pivot candle open time) |
| Start point (price) | `sp.price + 50 * _Point` (offset above candle) |
| Lifecycle | Detected → Draw → Active → Historical → Delete |
| Extend phase | Never extends. Single-point arrow. |
| Freeze phase | N/A. Never frozen. |
| Historical | Opacity 35% when count > `MaxHistoricalSwings` - window only, not supersession-based. |
| Delete trigger | Count > `MaxHistoricalSwings` (default 50) |
| Color | `#E53935` |
| Style | Native `OBJ_ARROW_DOWN` |
| Width | Default (2) |
| Label | No label — the arrow IS the marker |

---

## 4. SWING LOW

| Property | Value |
|---|---|
| Detection condition | 5-bar fractal: `L[center] < L[center-2] && L[center] < L[center-1] && L[center] < L[center+1] && L[center] < L[center+2]` |
| Object type | `OBJ_ARROW_UP` |
| Object name | `SCX_SWING_LOW_<id>` |
| Start point (time) | `sp.time` |
| Start point (price) | `sp.price - 50 * _Point` (offset below candle) |
| Lifecycle | Detected → Draw → Active → Historical → Delete |
| Extend phase | Never extends. Single-point arrow. |
| Freeze phase | N/A. |
| Historical | Opacity 35% when count exceeds limit. |
| Delete trigger | Count > `MaxHistoricalSwings` (default 50) |
| Color | `#43A047` |
| Style | Native `OBJ_ARROW_UP` |
| Width | Default |
| Label | No label. |

---

## 5. PIVOT

| Property | Value |
|---|---|
| Detection condition | Structural pivot promoted by `CStructuralPivotEngine::Promote()` |
| Object type | `OBJ_ARROW` |
| Object name | `SCX_PIVOT_<id>` |
| Arrow code | 159 (white circle) |
| Start point (time) | `p.time` |
| Start point (price) | `p.price ± 50 * _Point` (above if `isHigh`, below if `!isHigh`) |
| Lifecycle | Detected → Draw → Active → Historical → Delete |
| Extend phase | Never extends. Static marker. |
| Freeze phase | N/A. |
| Color (unprotected) | `#9E9E9E` |
| Color (protected high)** | `#42A5F5` |
| Color (protected low)** | `#FB8C00` |
| Label | No separate label — the Pivot marker IS the label for protected points. |

*\*\*Pivot color changes when the pivot is promoted to a protected point. This is not a lifecycle state change in the VisualStateEngine; it's a direct color update on the existing arrow.*

---

## 6. BREAK OF STRUCTURE (BOS)

### Visual Semantics

The BOS line represents: **"THIS LEVEL was broken."**

It is a horizontal level line at the broken pivot's price. The line starts at the pivot time (when the level was established) and extends forward to remind the trader the level is broken. The label marks the break event.

```
PH ●═══════════════════════════════
   ↑ Pivot Time              ↑ Break Candle
   (line start)         (label "BOS" here)
```

### Specification

| Property | Value |
|---|---|
| Detection condition | Bullish: `close[bar] > latestLockedHighPrice`. Bearish: `close[bar] < latestLockedLowPrice`. Bar index 1+ (closed bars only). |
| Object type | `OBJ_TREND` (horizontal level line) + `OBJ_TEXT` (label) |
| Object names | Line: `SCX_BOS_LINE_<id>`, Text: `SCX_BOS_TEXT_<id>` |
| **Start point (time)** | **`e.pivotTime`** — the time of the pivot that was broken (NOT the break candle) |
| Start point (price) | `e.pivotPrice` — the broken pivot's price level |
| End point (initial) | `e.breakTime` — set at creation to extend just past the break candle |
| End point (active) | `iTime(_Symbol, _Period, 0)` — extended every bar while Active |
| Lifecycle | Detected → Draw → Active → **Extend** → Freeze → Historical → Delete |
| Extend phase | Centralized VSE extends point 2 to `currentTime` each bar. Only the newest active BOS extends. |
| Freeze trigger | New BOS detected. The previously active BOS freezes at the new BOS's `breakTime`. `ObjectMove(point_2, freezeTime, price)`. Opacity → 60%, `STYLE_DASH`. |
| Historical trigger | When a third BOS exists, the oldest frozen BOS (not the immediate predecessor) drops to 35%, `STYLE_DASHDOT`. |
| Delete trigger | Count > `MaxHistoricalBOS` (default 30) |
| Color (bullish) | `#00C853` |
| Color (bearish) | `#D32F2F` |
| Style (active) | `STYLE_SOLID`, width 2 |
| Style (frozen) | `STYLE_DASH`, width 1, dimmed to 60% |
| Style (historical) | `STYLE_DASHDOT`, width 1, dimmed to 35% |
| Label text | `"BOS"` |
| Label time | `e.breakTime + PeriodSeconds(_Period) / 2` — always at the break event, not the pivot |
| Label price | Bullish: `e.pivotPrice + 20 * _Point`, Bearish: `e.pivotPrice - 20 * _Point`. Then `ResolveLabelPrice` if `CompactLabels == true`. |
| Label color | Bullish: `#00C853`, Bearish: `#D32F2F` — matches line color |
| Label font size | 8 |
| Label visibility | Label is created alongside the line. When the line freezes, the label stays (same opacity tier). When the line is deleted, the label is deleted too. |

### ASCII Diagrams

**Bullish BOS (uptrend continuation):**

```
PH ●═══════════════════════════════
   ├──────────────────────┬───────
   ↑ Pivot               ↑ Break
   (time)          (label "BOS" here)
```

**Bearish BOS (downtrend continuation):**

```
PL ●═══════════════════════════════
   ├──────────────────────┬───────
   ↑ Pivot               ↑ Break
                     (label "BOS" here)
```

---

## 7. CHANGE OF CHARACTER (CHOCH)

### Visual Semantics

The CHOCH line represents: **"Where the market respected structure until where it failed."**

It is a finite segment from the protected point (structure) to the break candle (failure). Unlike BOS, this is not an extending level — it is a captured moment of structural failure.

```
         ● ← Protected Point (start)
        /
       /
      /
     /
    ● ← Break Candle (end)
```

### Specification

| Property | Value |
|---|---|
| Detection condition | Trend reversal: Bearish trend + close above protected high, or Bullish trend + close below protected low. |
| Object type | `OBJ_TREND` (diagonal segment) + `OBJ_TEXT` (label) |
| Object names | Line: `SCX_CHOCH_LINE_<id>`, Text: `SCX_CHOCH_TEXT_<id>` |
| **Start point (time)** | **`e.ppTime`** — the protected point's pivot time (NOT the break candle) |
| Start point (price) | `e.ppPrice` — the protected point's price level |
| **End point (time)** | **`e.time`** — the break candle time (fixed; does NOT extend past it) |
| End point (price) | `e.breakPrice` — the close price that broke structure |
| Lifecycle | Detected → Draw → Active → Extend* → Freeze → Historical → Delete |
| Extend phase | **One-shot extend**: The line is first drawn with its right anchor at startTime + 1, then in the same `Update()` it is extended to the break candle time. After that, it never extends again. |
| Freeze trigger | The break candle is the freeze point. CHOCH enters Freeze state immediately after the one-shot extend completes. Opacity → 60%, `STYLE_DASH`. |
| Historical trigger | New CHOCH detected. The previous CHOCH drops to 35%, `STYLE_DASHDOT`. |
| Delete trigger | Count > `MaxHistoricalCHOCH` (default 30) |
| Color | `#FFB300` (same for bullish and bearish) |
| Style (active) | `STYLE_SOLID`, width 2 |
| Style (frozen) | `STYLE_DASH`, width 1, dimmed to 60% |
| Style (historical) | `STYLE_DASHDOT`, width 1, dimmed to 35% |
| Label text | `"CHOCH"` |
| Label time | `e.time + PeriodSeconds(_Period) / 2` — at the break candle |
| Label price | Bullish: `e.breakPrice + 10 * _Point`, Bearish: `e.breakPrice - 10 * _Point`. Then `ResolveLabelPrice`. |
| Label color | `#FFB300` |
| Label font size | 8 |

### Diagram

```
                     ● ← PP
                    /|
                   / |
                  /  |
                 /   |
                ● ← Break Candle
                ↑
           (label "CHOCH")
```

---

## 8. PROTECTED POINT (PP)

### Visual Semantics

The Protected Point line represents: **"This price level is the current structural invalidation point."**

It is a horizontal level line starting at the pivot formation time, extending forward to show that the level is active.

```
PH ●═══════════════════════════════
   ↑ Pivot Time           (extends to current bar)
```

### Specification

| Property | Value |
|---|---|
| Detection condition | When trend flips (bullish ↔ bearish), the latest locked pivot of the opposite type becomes protected. |
| Object type | `OBJ_TREND` (horizontal level line) + `OBJ_TEXT` (label) |
| Object names | Line: `SCX_PP_LINE_<id>`, Text: `SCX_PP_TEXT_<id>` |
| **Start point (time)** | **`p.time`** — always the pivot formation time (NOT activation time) |
| Start point (price) | `p.price` — the pivot's price level |
| End point (initial) | `p.time + 1` |
| End point (active) | `iTime(_Symbol, _Period, 0)` — extended every bar while Active |
| Lifecycle | Detected → Draw → Active → **Extend** → Freeze → Historical → Delete |
| Extend phase | Both active high and active low extend independently each bar via Centralized VSE. |
| Freeze trigger | New PH/PL of the same type is activated. The old PP freezes at `currentTime`. Opacity → 60%, `STYLE_DASH`. If `!ShowInactiveProtectedPoints`, both line and text are deleted immediately instead of freezing. |
| Historical trigger | When a third PP of the same type exists, the oldest frozen PP (not the immediate predecessor) drops to 35%, `STYLE_DASHDOT`. |
| Delete trigger | Count > `MaxHistoricalPP` (default 20) |
| Color (protected high) | `#42A5F5` |
| Color (protected low) | `#FB8C00` |
| Style (active) | `STYLE_SOLID`, width 1 |
| Style (frozen) | `STYLE_DASH`, width 1, dimmed to 60% |
| Style (historical) | `STYLE_DASHDOT`, width 1, dimmed to 35% |
| Label text | `"PH"` for protected high, `"PL"` for protected low |
| Label time | `p.time + PeriodSeconds(_Period) / 2` — at the pivot |
| Label price | PH: `p.price + 20 * _Point`, PL: `p.price - 20 * _Point`. Then `ResolveLabelPrice`. |
| Label color (active) | Same as line color. |
| Label color (frozen/historical) | Dimmed to corresponding tier. |
| Label font size | 8 |

---

## 9. ORDER BLOCK (OB)

### Visual Semantics

The Order Block rectangle represents: **"This candle's range is a high-probability mitigation zone."**

Unlike the v1.0 spec (30-day static rectangle), the OB is now an active object. Its right edge extends to the current bar until the price mitigates (enters) the zone. Once mitigated, it freezes. If the engine invalidates it (e.g., trend context changes), it is deleted.

```
┌──────────────────────┐
│ OB Zone              │ ← extends to current bar
│ (high ─ low)         │
└──────────────────────┘
↑ OB Candle
```

### Specification

| Property | Value |
|---|---|
| Detection condition | Originating candle immediately before the displacement candle that triggered the CHOCH. Bullish CHOCH → last bearish candle. Bearish CHOCH → last bullish candle. Search limited to 500 bars back. |
| Object type | `OBJ_RECTANGLE` + `OBJ_TEXT` |
| Object names | Rect: `SCX_OB_RECT_<id>`, Text: `SCX_OB_TEXT_<id>` |
| Left (time) | `ob.time` — OB candle open time |
| Right (time) | **`iTime(_Symbol, _Period, 0)`** — extends every bar while Active (NOT fixed 30 days) |
| Top (price) | `ob.high` |
| Bottom (price) | `ob.low` |
| Lifecycle | Detected → Draw → Active → **Extend** → Freeze → Delete |
| Extend phase | Right edge of rectangle extended to `currentTime` each bar via Centralized VSE. |
| Freeze trigger | **Mitigated**: price touches or enters the `[low, high]` zone. Right edge locks at the bar of mitigation. Opacity → 60%, border `STYLE_DASH`. |
| Historical phase | **Skipped.** OB does not have a Historical tier. It goes from Freeze directly to Delete. |
| Delete trigger | (a) Engine marks the OB as **invalidated** (e.g., new trend context makes it irrelevant), OR (b) count > `MaxHistoricalOB` (default 20). On invalidation: immediate delete. On count excess: FIFO delete of oldest frozen OB. |
| Color | `#1976D2` (same for bullish and bearish — OB color is directional-neutral) |
| Style (active) | `OBJPROP_FILL = true`, border width 1, border = `#1976D2` |
| Style (frozen) | `OBJPROP_FILL = false` (or fill dimmed to 60%), border `STYLE_DASH`, width 1, dimmed to 60% |
| `OBJPROP_BACK` | `false` — renders in front of candles, behind lines and labels |
| Label text | `"OB"` |
| Label time | `ob.time + PeriodSeconds(_Period) / 2` — near the OB candle |
| Label price | `(ob.high + ob.low) / 2.0`. Then `ResolveLabelPrice`. |
| Label color | `#1976D2` (active), dimmed (frozen) |
| Label font size | 8 |

---

## 10. FAIR VALUE GAP (FVG)

### Visual Semantics

The FVG rectangle represents: **"This price gap between three candles is an imbalance that tends to get filled."**

Like OB, the FVG is now an active object. Its right edge extends to the current bar until the gap is filled (price trades through the entire gap). Once filled, it freezes. The oldest frozen FVGs are deleted when the count exceeds the limit.

```
┌──────────────────────┐
│ FVG Gap              │ ← extends to current bar
│ (upper ─ lower)      │
└──────────────────────┘
↑ Displacement Candle
```

### Specification

| Property | Value |
|---|---|
| Detection condition | Three-candle imbalance. Bullish: bearish candle A → bullish candle C with gap between `low[A]` and `high[C]`. Bearish: bullish candle A → bearish candle C with gap between `high[A]` and `low[C]`. Middle candle (B) is the displacement candle. |
| Object type | `OBJ_RECTANGLE` + `OBJ_TEXT` |
| Object names | Rect: `SCX_FVG_RECT_<id>`, Text: `SCX_FVG_TEXT_<id>` |
| Left (time) | `fvg.time` — displacement (middle) candle time |
| Right (time) | **`iTime(_Symbol, _Period, 0)`** — extends every bar while Active (NOT fixed 30 days) |
| Top (price) | `fvg.upper` |
| Bottom (price) | `fvg.lower` |
| Lifecycle | Detected → Draw → Active → **Extend** → Freeze → Historical → Delete |
| Extend phase | Right edge extended to `currentTime` each bar via Centralized VSE. |
| Freeze trigger | **Filled**: price trades through the entire gap (close enters the `[lower, upper]` zone, or a candle body fully overlaps). Right edge locks at the fill bar. Opacity → 60%, border `STYLE_DASH`. |
| Historical trigger | When a third FVG exists and the second-oldest frozen FVG has been frozen for ≥20 bars, or when a new FVG supersedes it, drop to 35%, `STYLE_DASHDOT`. |
| Delete trigger | Count > `MaxHistoricalFVG` (default 30). FIFO deletion of oldest. |
| Color | `#FFD54F` |
| Style (active) | `OBJPROP_FILL = true`, border width 1, border = `#FFD54F` |
| Style (frozen) | `OBJPROP_FILL = false`, border `STYLE_DASH`, width 1, dimmed to 60% |
| Style (historical) | `OBJPROP_FILL = false`, border `STYLE_DASHDOT`, width 1, dimmed to 35% |
| `OBJPROP_BACK` | `false` |
| Label text | `"FVG"` |
| Label time | `fvg.time + PeriodSeconds(_Period) / 2` — near the displacement candle |
| Label price | `(fvg.upper + fvg.lower) / 2.0`. Then `ResolveLabelPrice`. |
| Label color | `#FFD54F` (active), dimmed (frozen/historical) |
| Label font size | 8 |

---

## 11. LAYER ORDER (Z-ORDER)

Creation order in `VisualizationManager::Update()` determines z-order on chart (first created = lowest = furthest back). This order ensures lines are never hidden behind rectangles.

| Order | Renderer | Objects | Z-level |
|---|---|---|---|
| (chart base) | — | Candles | Lowest (chart default) |
| **1** | **FVGRenderer** | `OBJ_RECTANGLE` | Low (rectangles behind all lines) |
| **2** | **OrderBlockRenderer** | `OBJ_RECTANGLE` | Low (rectangles behind all lines) |
| **3** | **ProtectedRenderer** | `OBJ_TREND` | Mid-low |
| **4** | **BOSRenderer** | `OBJ_TREND` | Mid |
| **5** | **CHOCHRenderer** | `OBJ_TREND` | Mid-high |
| **6** | **SwingRenderer** | `OBJ_ARROW_DOWN`, `OBJ_ARROW_UP` | High (arrows above lines) |
| **7** | **PivotRenderer** | `OBJ_ARROW` (code 159) | High (circles above lines) |
| **8** (implicit) | All renderers | `OBJ_TEXT` | Highest (labels always on top) |

**Key invariant:** `OBJPROP_BACK = false` for all objects.

**Rationale:**
- Rectangles (FVG, OB) are drawn first so they sit behind trend lines — lines must never disappear under rectangles.
- Trend lines (PP, BOS, CHOCH) are drawn in the middle — they are the primary structural markers.
- Arrows (Swings, Pivots) are drawn last among chart objects so they sit above lines.
- Labels (`OBJ_TEXT`) are created after their parent structure, so they render on top of everything.

---

## 12. COLOR TABLE

| Concept | Constant | Color | Hex | RGB |
|---|---|---|---|---|
| Swing High | `COLOR_SWING_HIGH` | Red (premium) | `#E53935` | (229, 57, 53) |
| Swing Low | `COLOR_SWING_LOW` | Green (premium) | `#43A047` | (67, 160, 71) |
| Pivot (unprotected) | `COLOR_PIVOT` | Gray | `#9E9E9E` | (158, 158, 158) |
| Pivot (protected high) | `COLOR_PIVOT_PROTECTED_HIGH` | Blue (premium) | `#42A5F5` | (66, 165, 245) |
| Pivot (protected low) | `COLOR_PIVOT_PROTECTED_LOW` | Orange (premium) | `#FB8C00` | (251, 140, 0) |
| BOS (bullish) | `COLOR_BOS_BULLISH` | Green (vivid) | `#00C853` | (0, 200, 83) |
| BOS (bearish) | `COLOR_BOS_BEARISH` | Red (vivid) | `#D32F2F` | (211, 47, 47) |
| CHOCH | `COLOR_CHOCH` | Amber (premium) | `#FFB300` | (255, 179, 0) |
| Order Block | `COLOR_OB` | Blue (deep) | `#1976D2` | (25, 118, 210) |
| Fair Value Gap | `COLOR_FVG` | Gold (light) | `#FFD54F` | (255, 213, 79) |
| Protected High | `COLOR_PROTECTED_HIGH` | Blue (premium) | `#42A5F5` | (66, 165, 245) |
| Protected Low | `COLOR_PROTECTED_LOW` | Orange (premium) | `#FB8C00` | (251, 140, 0) |

### Dimmed Color Calculation

For Frozen (60%) and Historical (35%) tiers, colors are dimmed by blending toward `clrBlack`:

| Full Color | Frozen (60%) | Historical (35%) |
|---|---|---|
| `#00C853` | `#007832` | `#00461D` |
| `#D32F2F` | `#7E1C1C` | `#4A1010` |
| `#FFB300` | `#996B00` | `#593E00` |
| `#42A5F5` | `#276393` | `#173A56` |
| `#FB8C00` | `#965400` | `#573100` |
| `#1976D2` | `#0F467E` | `#09294A` |
| `#FFD54F` | `#99802F` | `#594A1C` |
| `#E53935` | `#892220` | `#501413` |
| `#43A047` | `#28602A` | `#173818` |
| `#9E9E9E` | `#5F5F5F` | `#373737` |

---

## 13. OBJECT NAMING CONVENTION

All objects on chart follow the pattern `SCX_<STRUCTURE>_<TYPE>_<ID>`:

| Structure | Line/Object Name | Text Name |
|---|---|---|
| Swing High | `SCX_SWING_HIGH_<id>` | — |
| Swing Low | `SCX_SWING_LOW_<id>` | — |
| Pivot | `SCX_PIVOT_<id>` | — |
| BOS | `SCX_BOS_LINE_<id>` | `SCX_BOS_TEXT_<id>` |
| CHOCH | `SCX_CHOCH_LINE_<id>` | `SCX_CHOCH_TEXT_<id>` |
| Protected Point | `SCX_PP_LINE_<id>` | `SCX_PP_TEXT_<id>` |
| Order Block | `SCX_OB_RECT_<id>` | `SCX_OB_TEXT_<id>` |
| Fair Value Gap | `SCX_FVG_RECT_<id>` | `SCX_FVG_TEXT_<id>` |

`DeleteObjectsByPrefix("SCX_<STRUCTURE>_")` deletes all objects of a given type during `Clear()`.

IDs are sequential integers unique per structure type, incremented on each detection.

---

## 14. UPDATE RULES — MANAGER & RENDERER CONTRACT

### VisualizationManager::Update() (Orchestrator)

```
1. For each renderer in layer order (FVG → OB → PP → BOS → CHOCH → Swings → Pivots):
     renderer.Update()
2. Centralized VSE.EnforceHistoricalLimits()  // batch delete oldest exceeding per-type max
3. ChartRedraw(0)
```

### Renderer::Update() (Contract)

```
Update() — every renderer follows this exact pattern:

  1. Guard: if not initialized or no detector → return
  2. count = detector.GetCount()

  3. FREEZE PREVIOUS:
     if count > m_lastRenderedCount:
       previousActive = GetLastActiveVisualState()
       if previousActive exists:
         VSE.Freeze(previousActive.name, freezeTime, freezePrice)
         if type has historical tier:
           previousHistorical = GetSecondLastVisualState()
           if previousHistorical exists:
             VSE.PromoteToHistorical(previousHistorical.name)

  4. DRAW NEW:
     for i = m_lastRenderedCount to count - 1:
       VSE.Draw(event)  // CreateObjectIfMissing for line/rect + text
       visualStateArray.Append({name, event, state=Active})

  5. m_lastRenderedCount = count

  6. EXTEND ACTIVE:
     lastState = visualStateArray.GetLast()
     if lastState.state == Active && type has Extend phase:
       VSE.Extend(lastState.name, currentTime, lastState.price)
```

No renderer calls `ObjectMove()`, `ObjectSetInteger()`, `ObjectSetDouble()`, `ObjectDelete()`, or `ChartRedraw()` directly. All visual mutations go through the Centralized Visual State Engine.

---

## 15. FROZEN & HISTORICAL OBJECT BEHAVIOR SUMMARY

| Aspect | Active | Frozen | Historical |
|---|---|---|---|
| Right anchor | Extends each bar | Locked at freeze time | Locked at freeze time |
| Line style | `STYLE_SOLID` | `STYLE_DASH` | `STYLE_DASHDOT` |
| Width | 2 (lines), 1 (rect borders) | 1 | 1 |
| Color | Full color | Dimmed to 60% | Dimmed to 35% |
| Filled (rectangles) | `OBJPROP_FILL = true` | `OBJPROP_FILL = false` | `OBJPROP_FILL = false` |
| Label | Full color | Dimmed to 60% | Dimmed to 35% |
| `ShowInactiveProtectedPoints` | Always shown | Hidden if `false` | Hidden if `false` |
| Deletable by count limit | No | Yes (FIFO) | Yes (FIFO) |
| Deletable by engine | No | Yes (invalidation) | Yes (invalidation) |

---

## 16. RENDER CONFIG (INPUTS)

| Input | Type | Default | Description |
|---|---|---|---|
| `ShowSwings` | bool | `true` | Toggle swing high/low arrows |
| `ShowPivots` | bool | `true` | Toggle pivot markers |
| `ShowBOS` | bool | `true` | Toggle BOS lines + labels |
| `ShowCHOCH` | bool | `true` | Toggle CHOCH lines + labels |
| `ShowProtectedPoints` | bool | `true` | Toggle PP lines + labels |
| `ShowOrderBlocks` | bool | `true` | Toggle OB rectangles + labels |
| `ShowFVG` | bool | `true` | Toggle FVG rectangles + labels |
| `MaxHistoricalSwings` | int | `50` | Max swing arrows kept |
| `MaxHistoricalPivots` | int | `50` | Max pivot markers kept |
| `MaxHistoricalBOS` | int | `30` | Max BOS lines kept |
| `MaxHistoricalCHOCH` | int | `30` | Max CHOCH lines kept |
| `MaxHistoricalPP` | int | `20` | Max PP lines kept |
| `MaxHistoricalOB` | int | `20` | Max OB rectangles kept |
| `MaxHistoricalFVG` | int | `30` | Max FVG rectangles kept |
| `ShowInactiveProtectedPoints` | bool | `false` | Show/hide frozen PP lines |
| `CompactLabels` | bool | `true` | Enable label collision avoidance |
| `ColorTheme` | ENUM_THEME | `DARK` | Chart background for dimming calculations |

---

## 17. IMPLEMENTATION REQUIREMENTS PER RENDERER

Each renderer MUST implement:

```
void Init()          — set initialized = true; reset m_lastRenderedCount to 0; clear visualStateArray
void Update()        — follow the Update contract (§14)
void Shutdown()      — Clear() + set initialized = false
void Clear()         — DeleteObjectsByPrefix() + reset counters + empty visualStateArray
void SetDetector()   — store detector pointer
```

Each renderer MUST NOT:
- Call `ChartRedraw()` (handled once by manager)
- Call `ObjectCreate()` for existing objects (guarded by `CreateObjectIfMissing`)
- Call `ObjectMove()`, `ObjectSetInteger()`, `ObjectSetDouble()`, or `ObjectDelete()` directly (use VSE)
- Delete objects that are still Active
- Modify objects after freeze (except through VSE for tier transitions)

---

## 18. CENTRALIZED VISUAL STATE ENGINE — DETAILED INTERFACE

```
class CVisualStateEngine
{
public:
  void Init();                          // clear all internal state
  void Shutdown();                      // clear and release

  // Lifecycle transitions
  void Draw(string name, ENUM_OBJECT type, datetime time1, double price1,
            datetime time2, double price2, color lineColor);
      // Creates line/rect + associated label via CreateObjectIfMissing

  void Extend(string name, datetime newTime2, double newPrice2);
      // ObjectMove(point_2) — only if state == Active

  void Freeze(string name, datetime freezeTime, double freezePrice);
      // Locks point 2, sets STYLE_DASH, dims color to 60%, sets state = Frozen

  void PromoteToHistorical(string name);
      // Sets STYLE_DASHDOT, dims color to 35%, sets state = Historical

  void Delete(string name);
      // ObjectDelete(line/rect + text), removes from internal state

  // Batch operations
  void EnforceHistoricalLimit(string prefix, int maxCount, int& currentCount);
      // FIFO delete oldest exceeding maxCount

  // Queries
  EVisualState GetState(string name);
  bool IsActive(string name);
  bool IsFrozen(string name);
  bool IsHistorical(string name);

  // Internal
  void SetColorDim(string name, double factor);
      // Computes DimColor(baseColor, factor) and applies via ObjectSetInteger(OBJPROP_COLOR)
};
```

### Internal State Record

```
struct VisualStateRecord
{
  string     objName;         // e.g., "SCX_BOS_LINE_5"
  string     textName;        // e.g., "SCX_BOS_TEXT_5"
  EVisualState   state;       // Active / Frozen / Historical
  datetime   freezeTime;      // 0 if Active
  double     freezePrice;     // 0 if Active
  color      baseColor;       // full-intensity color
  ENUM_OBJECT objType;        // OBJ_TREND or OBJ_RECTANGLE
};
```

### EVisualState Enum

```
enum EVisualState
{
   VISUAL_STATE_ACTIVE,        // 100% opacity, SOLID
   VISUAL_STATE_FROZEN,        // 60% opacity, DASH
   VISUAL_STATE_HISTORICAL     // 35% opacity, DASHDOT
};
```

---

## 19. LABEL COLLISION AVOIDANCE

### Algorithm

```
ResolveLabelPrice(targetTime, basePrice, direction):
  1. candidatePrice = basePrice
  2. For iteration = 0 to MaxIterations (10):
     a. Check for existing OBJ_TEXT objects within a 2-hour time window
        centered on targetTime whose price is within 20 points of candidatePrice
     b. If no collision → return candidatePrice
     c. If collision → candidatePrice += direction * 20 * _Point * (iteration + 1)
  3. Return last candidatePrice (fallback)
```

### Direction Convention

| Object | Direction |
|---|---|
| BOS (bullish) | + (above line) |
| BOS (bearish) | - (below line) |
| CHOCH (bullish) | + |
| CHOCH (bearish) | - |
| PH | + |
| PL | - |
| OB | 0 → tries + then - |
| FVG | 0 → tries + then - |

---

## 20. COMPLETE UPDATE TICK FLOW

Every bar `OnTick()` / `IsNewBar()`:

```
1. CopyOHLCArrays()                      → full history copy
2. SwapBuffers()                         → flip read/write arrays
3. SwingDetector::Update()               → detect new swings
4. StructuralPivotEngine::Update()        → promote/replace pivots
5. BOSDetector::Update()                 → detect new BOS
6. TrendState::Update()                  → update trend from BOS
7. ProtectedPointManager::Update()       → update PP on trend flip
8. CHOCHDetector::Update()               → detect new CHOCH
9. OrderBlockDetector::Update()          → create OB from new CHOCH
10. FVGDetector::Update()                → detect new FVG
11. VisualizationManager::Update():
    a. FVGRenderer.Update()              → draw/extend/freeze/delete FVG
    b. OrderBlockRenderer.Update()        → draw/extend/freeze/delete OB
    c. ProtectedRenderer.Update()        → draw/extend/freeze/delete PP
    d. BOSRenderer.Update()              → draw/extend/freeze/delete BOS
    e. CHOCHRenderer.Update()            → draw/freeze/delete CHOCH
    f. SwingRenderer.Update()            → draw/delete swings
    g. PivotRenderer.Update()            → draw/delete pivots
    h. VSE.EnforceHistoricalLimits()     → batch FIFO deletes
    i. ChartRedraw(0)                    → single repaint
```

---

## 21. SUMMARY OF CHANGES FROM V1.0 → V2.0

| Change | v1.0 Spec | v2.0 Spec | Rationale |
|---|---|---|---|
| **BOS start time** | Break candle time | Pivot time | Line should mark "THIS LEVEL was broken" not "this candle broke" |
| **CHOCH start time** | Break candle time | Protected point time | Shows where structure was respected until failure |
| **CHOCH end behavior** | Extended to current bar | Fixed at break candle | CHOCH is a finite segment, not an extending level |
| **PP start time** | activationTime or p.time | Always p.time | Protected points are price levels, not activation events |
| **OB extension** | 30-day fixed rectangle | Extends each bar until mitigated | Matches institutional ICT usage |
| **FVG extension** | 30-day fixed rectangle | Extends each bar until filled | Matches TradingView-style gap tracking |
| **OB/FVG freeze** | None | On mitigated/filled | Visual distinction between active and spent zones |
| **OB/FVG delete** | Count limit only | Count limit + invalidation | Cleaner chart state management |
| **Opacity tiers** | 2 tiers (active + delete) | 3 tiers (100%, 60%, 35%) | Gradual visual decay aids readability |
| **Layer order** | Swing → Pivot → BOS → CHOCH → PP → OB → FVG | Candles → FVG → OB → PP → BOS → CHOCH → Swings → Labels | Lines above rectangles, labels topmost |
| **Colors** | clrLime, clrRed, clrOrange, clrBlue, clrGold | Premium palette (#00C853, #D32F2F, #FFB300, #42A5F5, #FB8C00, #1976D2, #FFD54F) | Modern, professional appearance |
| **Extension engine** | Per-renderer duplication | Centralized CVisualStateEngine | Single implementation, seven consumers |
| **Visual lifecycle** | Implicit per type | Explicit universal lifecycle (Detected → Draw → Active → Extend → Freeze → Historical → Delete) | Consistent object state model across all types |
| **Bearish BOS color** | Same as bullish (clrLime) | #D32F2F (red) | Directionally distinct BOS colors |
| **OBJPROP_BACK** | true on FVG/OB rects | false on all objects | Objects must render in front of candles per layer order |
| **Historical tier for OB** | N/A | Skipped (Freeze → Delete directly) | Invalidation is the primary delete path for OB |

---

*End of Visual Specification v2.0. No code below this line.*
