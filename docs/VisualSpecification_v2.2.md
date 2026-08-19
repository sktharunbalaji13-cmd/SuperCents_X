# SuperCents_X — Visual Specification v2.2

**Version:** 2.2  
**Author:** SMC Architecture Team  
**Status:** Single Source of Truth (Architecture Freeze)  
**v2.2 delta:** VF01 (Sprint 20) — EQH/EQL liquidity levels promoted from §26 (reserved) to a fully specified structure (§14A) with renderer foundation `LiquidityRenderer`. Sweep/invalidation visuals remain reserved (§26, VF02+).

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
| Labels avoid other labels | `ResolveLabelPlacement()` (VSE registry) with 20-point step, 10-iteration max, 2-hour time window |
| Three-tier opacity | Active = 100% (`STYLE_SOLID`, full color), Frozen = 60% (`STYLE_DASH`, dimmed color), Historical = 35% (`STYLE_DASHDOT`, further dimmed) |
| Premium palette | All colors defined in §16. Single definition per conceptual type |
| Layer order | Defined in §15 — candles at bottom, labels at top |
| `ChartRedraw(0)` | Called once per `Update()` by VisualizationManager after all renderers run |
| Visual mutations through commands | All renderers build `VisualCommand` structs and pass them to the VSE; no renderer directly calls `ObjectMove`, `ObjectSetInteger`, or `ObjectDelete` |

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
          ┌──────────┴──────────┐
          │  New Structure?     │  Has a newer event of the same type appeared?
          └──────────┬──────────┘
                    / \
                 No/   \Yes
                 /       \
         ┌──────▼──┐  ┌──▼────────┐
         │ Extend* │  │  Freeze   │  Right anchor locks; opacity → 60%
         │  (or    │  └─────┬─────┘
         │ Finalize│        │
         │ for     │  ┌─────▼──────────┐
         │ CHOCH)  │  │   Historical   │  Not the immediate predecessor; opacity → 35%
         └─────┬───┘  └─────┬──────────┘
               │            │
               └──────┬─────┘
                      │
                ┌─────▼─────┐
                │   Delete  │  ObjectRemove() called; removed from chart
                └───────────┘
```

*\*Extend phase is continuous (advances right anchor each bar) for BOS, PP, OB, FVG. CHOCH uses a one-shot **Finalize** instead: the right anchor is set to the break candle time once and never advanced again.*

### Lifecycle Table Per Type

| Type | Phase After Active | Freeze Trigger | Historical Trigger | Delete Trigger |
|---|---|---|---|---|
| Swing High | — (static arrow) | N/A | N/A | Count > `MaxHistoricalSwings` |
| Swing Low | — (static arrow) | N/A | N/A | Count > `MaxHistoricalSwings` |
| Pivot | — (static marker) | N/A | N/A | Count > `MaxHistoricalPivots` |
| **BOS** | **Extend** (continuous) | New BOS detected | Superseded by next BOS | Count > `MaxHistoricalBOS` |
| **CHOCH** | **Finalize** (one-shot) | Immediately after Finalize | New CHOCH detected | Count > `MaxHistoricalCHOCH` |
| **Protected High** | **Extend** (continuous) | New PH activated | Superseded by next PH | Count > `MaxHistoricalPP` |
| **Protected Low** | **Extend** (continuous) | New PL activated | Superseded by next PL | Count > `MaxHistoricalPP` |
| **Order Block** | **Extend** (continuous) | Mitigated (price enters OB zone) | N/A (skips Historical) | Engine marks invalidated, OR count > `MaxHistoricalOB` |
| **FVG** | **Extend** (continuous) | Filled (candle body closes gap) | Oldest frozen FVG | Count > `MaxHistoricalFVG` |
| **EQH** | — (static line, no extend) | N/A (freeze deferred to VF02+) | N/A | Count > `MaxHistoricalLiquidity`, OR outside render window |
| **EQL** | — (static line, no extend) | N/A (freeze deferred to VF02+) | N/A | Count > `MaxHistoricalLiquidity`, OR outside render window |

### State Transition Rules

1. **Detected → Draw**: Guaranteed to happen in the same `Update()` cycle. No visual is ever "pending".
2. **Active → Extend/Finalize**: Only for types whose right anchor advances. Continuous types call `ObjectMove()` each bar. CHOCH sets the right anchor once and stops.
3. **Freeze**: The right anchor point 2 is set to the freeze time and never moved again. Opacity drops to 60%. Line style changes to `STYLE_DASH`.
4. **Historical**: Opacity drops to 35%. Line style changes to `STYLE_DASHDOT`. Only applies to the second-oldest object (not the most recent frozen one).
5. **Delete**: Objects are deleted in FIFO order when their type exceeds the max historical count.

---

## 2. OBJECT OWNERSHIP

Every layer in the pipeline owns one responsibility and does not cross boundaries.

| Layer | Owns | Does NOT own |
|---|---|---|
| **Detector** (e.g., `CBOSDetector`) | Market structure detection and storage. Maintains a read-only event buffer. Decides *what* exists. | Drawing, visual lifecycle, object naming, anchor point management. |
| **Renderer** (e.g., `CBOSRenderer`) | Drawing coordination. Maps detector events to visual objects. Decides *when* to create, extend, freeze, or delete. Tracks `m_lastRenderedCount` and maintains the event-to-visual mapping array. | Direct object mutations, market structure logic, visual lifecycle state transitions. |
| **VisualStateEngine** (`CVisualStateEngine`) | Visual lifecycle exclusively. Draws objects, extends anchors, freezes state, promotes to historical, deletes. Manages all `ObjectCreate`, `ObjectMove`, `ObjectSetInteger`, `ObjectSetDouble`, `ObjectDelete` calls. | Detector internals, market structure, rendering coordination, event-to-visual mapping. |

**Ownership invariant:** A detector never imports a renderer. A renderer never calls `ObjectMove`. The VSE never reads detector data. Each layer communicates through well-defined interfaces only.

---

## 3. COORDINATE CONTRACT

Every structure defines four values that determine where it sits on the chart. "Left" is time anchor 1. "Right" is time anchor 2. "Price Anchor" is the invariant price level. "Time Anchor" is the invariant time origin.

| Structure | Time Anchor | Price Anchor | Left Edge | Right Edge |
|---|---|---|---|---|
| Swing High | `sp.time` | `sp.price` | N/A (arrow) | N/A (arrow) |
| Swing Low | `sp.time` | `sp.price` | N/A (arrow) | N/A (arrow) |
| Pivot | `p.time` | `p.price` | N/A (marker) | N/A (marker) |
| **BOS** | `e.pivotTime` | `e.pivotPrice` | Pivot Time | Current Time (while Active) → New BOS breakTime (when Frozen) |
| **CHOCH** | `e.ppTime` | `e.ppPrice` | PP Time | Break Time (fixed at creation — never moves) |
| **Protected High** | `p.time` | `p.price` | Pivot Time | Current Time (while Active) → currentTime (when Frozen) |
| **Protected Low** | `p.time` | `p.price` | Pivot Time | Current Time (while Active) → currentTime (when Frozen) |
| **Order Block** | `ob.time` | `[ob.high, ob.low]` | OB Candle Time | Current Time (while Active) → Mitigation Time (when Frozen) |
| **FVG** | `fvg.time` | `[fvg.upper, fvg.lower]` | Displacement Candle Time | Current Time (while Active) → Fill Time (when Frozen) |
| **EQH** | `swing(leftSwingId).time` | `level.averagePrice` | Left member swing time | Right member swing time (fixed at draw — static) |
| **EQL** | `swing(leftSwingId).time` | `level.averagePrice` | Left member swing time | Right member swing time (fixed at draw — static) |

### Anchor Invariants

- **Time Anchor**: Never changes after creation. This is the structural origin.
- **Price Anchor**: Never changes after creation. For rectangles (OB, FVG) the price anchor is the full `[low, high]` or `[upper, lower]` range.
- **Left Edge**: Always equals Time Anchor at creation. Never moves.
- **Right Edge**: Moves forward monotonically (or is fixed for static/CHOCH types). Never shrinks.
- **Freeze**: Sets Right Edge to the freeze time permanently. The right edge then becomes the "end" of the object's visual life.

All ObjectCreate and ObjectMove calls derive directly from these four values. If a coordinate changes, only one place needs updating.

---

## 4. RENDERER RESPONSIBILITY MATRIX

| Renderer | Creates | Extends / Finalizes | Freezes | Deletes |
|---|---|---|---|---|
| **SwingRenderer** | `OBJ_ARROW_DOWN` / `OBJ_ARROW_UP` | Never | Never | Count limit |
| **PivotRenderer** | `OBJ_ARROW` (code 159) | Never | Never | Count limit |
| **BOSRenderer** | `OBJ_TREND` + `OBJ_TEXT` | **Extends** point 2 → currentTime each bar | New BOS detected | Count limit |
| **CHOCHRenderer** | `OBJ_TREND` + `OBJ_TEXT` | **Finalizes** point 2 → breakTime (one-shot) | Immediately after Finalize | Count limit |
| **ProtectedRenderer** | `OBJ_TREND` + `OBJ_TEXT` | **Extends** point 2 → currentTime each bar | New PH/PL activated | Count limit + `!ShowInactiveProtectedPoints` |
| **OrderBlockRenderer** | `OBJ_RECTANGLE` + `OBJ_TEXT` | **Extends** right edge → currentTime each bar | Mitigated (price enters zone) | Invalidation + Count limit |
| **FVGRenderer** | `OBJ_RECTANGLE` + `OBJ_TEXT` | **Extends** right edge → currentTime each bar | Filled (candle body closes gap) | Count limit |
| **LiquidityRenderer** | `OBJ_TREND` + `OBJ_TEXT` (EQH/EQL only) | **Never** (static — no extend, no finalize) | Never (freeze deferred to VF02+) | Count limit (`MaxHistoricalLiquidity`) + outside render window |

### Renderer Lifecycle Invariants

- "Creates" is a one-time call via `CreateObjectIfMissing` — never re-creates existing objects.
- "Extends" only applies to the single active object of each type. Previous objects are Frozen.
- "Finalizes" (CHOCH) is a one-shot anchor set, distinct from continuous Extend.
- "Freezes" locks the right edge, changes style to `STYLE_DASH`, dims color to 60%.
- "Deletes" removes both the primary object and its associated label.
- "Count limit" deletes the oldest of the type (FIFO) when `count > MaxHistorical<Type>`.

---

## 5. DETECTOR → RENDERER FLOW

This is the complete execution pipeline from data to chart. Arrows represent sequential data handoff within a single `OnTick()` / `IsNewBar()` cycle.

```
SwingDetector
    │  detects 5-bar fractal swings
    ▼
StructuralPivotEngine
    │  promotes swing points to structural pivots
    ▼
BOSDetector
    │  detects breaks of locked high/low pivots
    ▼
TrendState
    │  determines bullish/bearish trend from BOS
    ▼
ProtectedPointManager
    │  activates/deactivates PH/PL on trend flip
    ▼
CHOCHDetector
    │  detects trend-reversal breaks of protected points
    ▼
OrderBlockDetector
    │  creates OB from the candle before CHOCH displacement
    ▼
FVGDetector
    │  detects three-candle imbalances
    ▼
LiquidityDetector
    │  clusters equal swing highs (EQH) / lows (EQL); level = cluster
    ▼
VisualizationManager
    │  orchestrates renderers in layer order
    ├── FVGRenderer
    ├── OrderBlockRenderer
    ├── ProtectedRenderer
    ├── BOSRenderer
    ├── CHOCHRenderer
    ├── LiquidityRenderer
    ├── SwingRenderer
    └── PivotRenderer
    │  each renderer builds VisualCommand[] arrays
    ▼
Centralized VisualStateEngine
    │  executes commands (Draw / Extend / Finalize / Freeze / Promote / Delete)
    │  calls ObjectCreate, ObjectMove, ObjectSetInteger, ObjectDelete
    ▼
Chart
    │  ChartRedraw(0) — single repaint after all commands executed
```

**Data ownership boundaries:**
- Detectors → Renderers: Renderers query `detector.GetCount()` and `detector.GetEvent(i)`.
- Renderers → VSE: Renderers build `VisualCommand[]` arrays and call `VSE.ExecuteBatch()`.
- VSE → Chart: VSE calls MT5 API functions directly. No other component touches chart objects.

---

## 6. CENTRALIZED VISUAL STATE ENGINE

All extension, freeze, historical, and deletion logic lives in a single engine. Renderers do not call MT5 API functions directly — they build `VisualCommand` structs and pass them to the engine for execution.

### VisualCommand Struct

```
struct VisualCommand
{
   EVisualCommandType   type;         // DRAW, EXTEND, FREEZE,
                                      // PROMOTE_TO_HISTORICAL, DELETE, FINALIZE
   string               objName;      // primary object name (line/rect/arrow)
   string               textName;     // associated label name (empty if none)
   ENUM_OBJECT          objType;      // OBJ_TREND, OBJ_RECTANGLE, OBJ_ARROW, etc.
   datetime             time1;        // anchor 1 time
   double               price1;       // anchor 1 price
   datetime             time2;        // anchor 2 time
   double               price2;       // anchor 2 price
   color                lineColor;    // full-intensity color
   color                textColor;    // label color
   string               labelText;    // e.g., "BOS", "PH"
   int                  fontSize;     // 8
   bool                 isFill;       // OBJPROP_FILL for rectangles
   int                  width;        // line width
};

enum EVisualCommandType
{
   CMD_DRAW,                // ObjectCreate + label Create
   CMD_EXTEND,              // ObjectMove(point_2) — continuous
   CMD_FINALIZE,            // ObjectMove(point_2) — one-shot (CHOCH)
   CMD_FREEZE,              // lock point 2, STYLE_DASH, color 60%
   CMD_PROMOTE_HISTORICAL,  // STYLE_DASHDOT, color 35%
   CMD_DELETE               // ObjectDelete for both obj and text
};
```

### Engine Interface

```
class CVisualStateEngine
{
public:
   void Init();
   void Shutdown();

   // Primary entry point — renderers call this exclusively
   void ExecuteBatch(VisualCommand& cmds[], int count);

   // Convenience: build and execute a single command
   void Execute(VisualCommand& cmd);

   // Batch operations
   void EnforceHistoricalLimit(string prefix, int maxCount, int& currentCount);

   // Queries
   EVisualState GetState(string name);
   bool IsActive(string name);
   bool IsFrozen(string name);
   bool IsHistorical(string name);
};
```

### Command Execution

Each command type maps to a specific set of MT5 API calls:

| Command | API Calls |
|---|---|
| `CMD_DRAW` | `ObjectCreate()` for primary + label; set all properties |
| `CMD_EXTEND` | `ObjectMove(point_2, time2, price2)` — only if state is Active |
| `CMD_FINALIZE` | `ObjectMove(point_2, time2, price2)` — set once, never again |
| `CMD_FREEZE` | `ObjectSetInteger(STYLE_DASH)`; `SetColorDim(60%)`; set internal state to Frozen; record freezeTime/price |
| `CMD_PROMOTE_HISTORICAL` | `ObjectSetInteger(STYLE_DASHDOT)`; `SetColorDim(35%)`; set state to Historical |
| `CMD_DELETE` | `ObjectDelete()` for primary + text; remove from internal state array |

### Renderer Contract (Command-Based)

Each renderer's `Update()` follows this pattern:

```
Update():
  1. Guard: if not initialized or no detector → return
  2. count = detector.GetCount()
  3. VisualCommand cmdArray[]  // local, cleared each Update()

  4. FREEZE PREVIOUS + PROMOTE HISTORICAL:
     if count > m_lastRenderedCount:
       previousActive = GetLastActiveVisualState()
       if previousActive exists:
         cmdArray.Append({
           type: CMD_FREEZE,
           objName: previousActive.name,
           time2: freezeTime,
           price2: freezePrice
         })
         if type has historical tier:
           previousHistorical = GetSecondLastVisualState()
           if previousHistorical exists:
             cmdArray.Append({
               type: CMD_PROMOTE_HISTORICAL,
               objName: previousHistorical.name
             })

  5. DRAW NEW:
     for i = m_lastRenderedCount to count - 1:
       event = detector.GetEvent(i)
       cmdArray.Append({
         type: CMD_DRAW,
         objName: SCX_...,
         time1: ..., price1: ..., time2: ..., price2: ...,
         lineColor: ..., textColor: ..., labelText: ...
       })
       visualStateArray.Append({name, event, state=Active})

  6. m_lastRenderedCount = count

  7. EXTEND / FINALIZE ACTIVE:
     lastState = visualStateArray.GetLast()
     if lastState.state == Active && type has Extend phase:
       cmdArray.Append({
         type: CMD_EXTEND,
         objName: lastState.name,
         time2: currentTime,
         price2: lastState.price
       })
     if type == CHOCH && lastState.state == Active:
       cmdArray.Append({
         type: CMD_FINALIZE,
         objName: lastState.name,
         time2: breakTime,
         price2: breakPrice
       })

  8. ExecuteBatch(cmdArray, ArraySize(cmdArray))
```

No renderer calls `ObjectMove()`, `ObjectSetInteger()`, `ObjectSetDouble()`, or `ObjectDelete()` directly. All visual mutations go through commands executed by the VSE.

### Internal State Tracking

The engine maintains a parallel array of `VisualStateRecord` for each managed object:

```
struct VisualStateRecord
{
   string        objName;         // e.g., "SCX_BOS_LINE_5"
   string        textName;        // e.g., "SCX_BOS_TEXT_5"
   EVisualState  state;           // Active / Frozen / Historical
   datetime      freezeTime;      // 0 if Active
   double        freezePrice;     // 0 if Active
   color         baseColor;       // full-intensity color
   ENUM_OBJECT   objType;         // OBJ_TREND, OBJ_RECTANGLE, OBJ_ARROW
};
```

---

## 7. SWING HIGH

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
| Historical | Opacity 35% when count > `MaxHistoricalSwings` — window only, not supersession-based. |
| Delete trigger | Count > `MaxHistoricalSwings` (default 50) |
| Color | `#E53935` |
| Style | Native `OBJ_ARROW_DOWN` |
| Width | Default (2) |
| Label | No label — the arrow IS the marker |

---

## 8. SWING LOW

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

## 9. PIVOT

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
| Color (protected high) | `#42A5F5` |
| Color (protected low) | `#FB8C00` |
| Label | No separate label — the Pivot marker IS the label for protected points. Pivot color updates directly when promoted to protected point. |

---

## 10. BREAK OF STRUCTURE (BOS)

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
| Start point (time) | `e.pivotTime` — the time of the pivot that was broken (NOT the break candle) |
| Start point (price) | `e.pivotPrice` — the broken pivot's price level |
| End point (initial) | `e.breakTime` — set at creation to extend just past the break candle |
| End point (active) | `iTime(_Symbol, _Period, 0)` — extended every bar while Active |
| Lifecycle | Detected → Draw → Active → **Extend** → Freeze → Historical → Delete |
| Extend phase | Centralized VSE extends point 2 to `currentTime` each bar. Only the newest active BOS extends. |
| Freeze trigger | New BOS detected. The previously active BOS freezes at the new BOS's `breakTime`. Opacity → 60%, `STYLE_DASH`. |
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

## 11. CHANGE OF CHARACTER (CHOCH)

### Visual Semantics

The CHOCH line represents: **"Where the market respected structure until where it failed."**

It is a finite segment from the protected point (structure) to the break candle (failure). Unlike BOS, this is not an extending level — it is a captured moment of structural failure. The line is created, finalized (one-shot anchor to break candle), and immediately frozen.

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
| Start point (time) | `e.ppTime` — the protected point's pivot time (NOT the break candle) |
| Start point (price) | `e.ppPrice` — the protected point's price level |
| End point (time) | `e.time` — the break candle time (fixed; does NOT extend past it) |
| End point (price) | `e.breakPrice` — the close price that broke structure |
| Lifecycle | Detected → Draw → Active → **Finalize** (one-shot) → Freeze → Historical → Delete |
| Finalize phase | The line is first drawn with its right anchor at `startTime + 1`, then in the same `Update()` a `CMD_FINALIZE` command sets point 2 to the break candle time. After that, it never moves again. "Finalize" is distinct from "Extend" because it is a one-shot anchor set, not a continuous per-bar operation. |
| Freeze trigger | Immediately after Finalize completes. Opacity → 60%, `STYLE_DASH`. |
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

## 12. PROTECTED POINT (PP)

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
| Start point (time) | `p.time` — always the pivot formation time (NOT activation time) |
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

## 13. ORDER BLOCK (OB)

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
| Right (time) | `iTime(_Symbol, _Period, 0)` — extends every bar while Active (NOT fixed 30 days) |
| Top (price) | `ob.high` |
| Bottom (price) | `ob.low` |
| Lifecycle | Detected → Draw → Active → **Extend** → Freeze → Delete |
| Extend phase | Right edge of rectangle extended to `currentTime` each bar via Centralized VSE. |
| Freeze trigger | **Mitigated** (see exact criteria below). Right edge locks at the bar of mitigation. Opacity → 60%, border `STYLE_DASH`, fill removed. |
| Historical phase | **Skipped.** OB does not have a Historical tier. It goes from Freeze directly to Delete. |
| Delete trigger | (a) Engine marks the OB as **invalidated** (e.g., new trend context makes it irrelevant), OR (b) count > `MaxHistoricalOB` (default 20). On invalidation: immediate `CMD_DELETE`. On count excess: FIFO delete of oldest frozen OB. |
| Color | `#1976D2` (same for bullish and bearish — OB color is directional-neutral) |
| Style (active) | `OBJPROP_FILL = true`, border width 1, border = `#1976D2` |
| Style (frozen) | `OBJPROP_FILL = false`, border `STYLE_DASH`, width 1, dimmed to 60% |
| `OBJPROP_BACK` | `false` — renders in front of candles, behind lines and labels |
| Label text | `"OB"` |
| Label time | `ob.time + PeriodSeconds(_Period) / 2` — near the OB candle |
| Label price | `(ob.high + ob.low) / 2.0`. Then `ResolveLabelPrice`. |
| Label color | `#1976D2` (active), dimmed to 60% (frozen) |
| Label font size | 8 |

### Mitigation Criteria (Exact)

Mitigation is checked on each completed bar close, on every active (non-frozen) OB.

| OB Direction | Mitigation Condition | Rationale |
|---|---|---|
| **Bullish OB** (formed in bullish context, OB candle is bearish) | `low[i] <= ob.high` | Price has entered the zone from below. The low touching or crossing the OB high means the zone is being mitigated. |
| **Bearish OB** (formed in bearish context, OB candle is bullish) | `high[i] >= ob.low` | Price has entered the zone from above. The high touching or crossing the OB low means the zone is being mitigated. |

A single tick touching the zone boundary qualifies as mitigation. Partial fills are not distinguished — the moment any part of a candle's range overlaps the `[ob.low, ob.high]` interval, the OB is frozen.

---

## 14. FAIR VALUE GAP (FVG)

### Visual Semantics

The FVG rectangle represents: **"This price gap between three candles is an imbalance that tends to get filled."**

Like OB, the FVG is now an active object. Its right edge extends to the current bar until the gap is filled (candle body closes through the gap). Once filled, it freezes. The oldest frozen FVGs are deleted when the count exceeds the limit.

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
| Right (time) | `iTime(_Symbol, _Period, 0)` — extends every bar while Active (NOT fixed 30 days) |
| Top (price) | `fvg.upper` |
| Bottom (price) | `fvg.lower` |
| Lifecycle | Detected → Draw → Active → **Extend** → Freeze → Historical → Delete |
| Extend phase | Right edge extended to `currentTime` each bar via Centralized VSE. |
| Freeze trigger | **Filled** (see exact criteria below). Right edge locks at the fill bar. Opacity → 60%, border `STYLE_DASH`, fill removed. |
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

### Fill Criteria (Exact)

Fill is checked on each completed bar close, on every active (non-frozen) FVG.

| FVG Direction | Fill Condition | Rationale |
|---|---|---|
| **Bullish FVG** (gap between `low[A]` and `high[C]`) | `close[i] <= fvg.lower` | The candle body closes at or below the bottom of the gap. A wick touch does NOT constitute fill — only a body close across the gap boundary. |
| **Bearish FVG** (gap between `high[A]` and `low[C]`) | `close[i] >= fvg.upper` | The candle body closes at or above the top of the gap. Same rule: body only, wick touches are ignored. |

"Body close" is defined as the official `close[i]` of a completed bar. Intraday ticks that momentarily cross the gap do NOT trigger fill. The gap is considered filled when the market has made a definitive commitment through a full candle close.

---

## 14A. LIQUIDITY LEVELS — EQUAL HIGHS / EQUAL LOWS (EQH / EQL)

> **VF01 (Sprint 20):** promoted from §26 (reserved) to a fully specified structure. Scope of VF01 is the **renderer foundation only**. The detector semantics referenced below (clustering, sweep, mitigation, invalidation) are defined and owned by `LiquidityDetector` (Sprint 12 / DD03 / DD04) and are **not re-implemented** by the renderer — see §2 ownership.

### Visual Semantics

An EQH/EQL level represents: **"Resting liquidity sits at this price — a cluster of equal (or near-equal) swing points that price may be drawn toward before continuing."**

```
                EQH line (static)
  ══════════════════════════════════  ← averagePrice (cluster mean)
      ↑ left member swing    ↑ right member swing (formation)
```

- **EQH** = buy-side liquidity pool above price (cluster of ≥ 2 equal swing highs).
- **EQL** = sell-side liquidity pool below price (cluster of ≥ 2 equal swing lows).
- The line is **static**: both anchors are fixed at draw time. It never extends, never finalizes, never freezes (VF01). Sweep → freeze/invalidation visuals are deferred (see §26).

### Formal Definitions

| Property | Equal Highs (EQH) | Equal Lows (EQL) |
|---|---|---|
| **Source detector** | `CLiquidityDetector` (level type `LIQUIDITY_EQH`) | `CLiquidityDetector` (level type `LIQUIDITY_EQL`) |
| **Source level / ID** | `LiquidityLevel.id` — the detector level id; unique per level. Visual object is keyed to it. | same (EQL levels share the id space with EQH) |
| **Level price** | `LiquidityLevel.averagePrice` — running cluster mean of member swing prices. Never re-read from chart. | same |
| **Cluster definition** | ≥ 2 swing highs whose prices are within `LIQUIDITY_EQH_TOLERANCE_PIPS` (3 pips) of each other | ≥ 2 swing lows within `LIQUIDITY_EQL_TOLERANCE_PIPS` (3 pips) |
| **Member swings** | `LiquidityLevel.leftSwingId` (oldest member), `LiquidityLevel.rightSwingId` (newest member), `LiquidityLevel.memberIdStr` (full member list) | same |
| **Formation time** | Time of the **right member swing** (`swing(rightSwingId).time`) — the moment the second member confirmed the level | same |
| **Formation bar** | The detector records the left member's bar (`detectedBar`); the renderer never uses chart cursors for formation | same |
| **Lifecycle** | Detected → Draw → Active (static) → Delete. **No** `CMD_EXTEND`, `CMD_FINALIZE`, `CMD_FREEZE` in VF01 | same |
| **Invalidation / freeze behavior** | **Deferred.** A swept/mitigated/invalidated level is simply not drawn by VF01; freeze-on-sweep and invalidation styling are reserved (§26). VF01 deletes only by count limit and render window | same |
| **Object type** | `OBJ_TREND` + `OBJ_TEXT` | same |
| **Object names** | Line: `SCX_LIQ_LINE_<id>`, Text: `SCX_LIQ_TEXT_<id>` | same |
| **Palette** | `COLOR_LIQUIDITY_EQH` = `#FFA726` (amber) | `COLOR_LIQUIDITY_EQL` = `#26C6DA` (cyan) |
| **Label rules** | See "Label Rules" below; label side = above level | label side = below level |

### Specification

| Property | Value |
|---|---|
| Object type | `OBJ_TREND` + `OBJ_TEXT` |
| Object names | Line: `SCX_LIQ_LINE_<id>`, Text: `SCX_LIQ_TEXT_<id>` |
| Left (time) | `swing(leftSwingId).time` — time of the oldest cluster member |
| Right (time) | `swing(rightSwingId).time` — time of the newest cluster member (formation time). **Fixed at draw; never moves.** |
| Price (both anchors) | `level.averagePrice` |
| Lifecycle | Detected → Draw → Active (static) → Delete |
| Extend phase | **None.** The right anchor is never advanced. |
| Freeze trigger | **None in VF01** (deferred to VF02+). |
| Delete trigger | Count > `MaxHistoricalLiquidity` (default 30), FIFO of oldest drawn; OR outside `LiquidityRenderHistoryBars` render window |
| Color | `#FFA726` (EQH) / `#26C6DA` (EQL) |
| Style (active) | `STYLE_SOLID`, width 2, `OBJPROP_RAY_RIGHT = false` |
| `OBJPROP_BACK` | `false` |
| Label text | Per `LiquidityLabelMode` — see Label Rules |
| Label time | Formation time (`swing(rightSwingId).time`) |
| Label price | `averagePrice + 15 * _Point` (EQH) / `averagePrice - 15 * _Point` (EQL); then `ResolveLabelPrice` |
| Label color | Same as line color |
| Label font size | 8 |

### Label Rules

`LiquidityLabelMode` (input, default `DIRECTION`) — mirrors the BOS label-mode convention:

| Mode | EQH label | EQL label |
|---|---|---|
| `LIQUIDITY_LABEL_NONE` | (no label object) | (no label object) |
| `LIQUIDITY_LABEL_SIMPLE` | `EQH` | `EQL` |
| `LIQUIDITY_LABEL_DIRECTION` | `BUY EQH` | `SELL EQL` |
| `LIQUIDITY_LABEL_DEBUG` | `BUY EQH #<id>` | `SELL EQL #<id>` |

The label side encodes the liquidity side (buy-side above / sell-side below); `CompactLabels` collision avoidance applies exactly as for BOS.

### Renderer Contract

`CLiquidityRenderer` (new, VF01):

- Consumes **only** `CLiquidityDetector` levels of type `LIQUIDITY_EQH` / `LIQUIDITY_EQL` with status `ACTIVE` via `GetLevelCount()` / `GetLevel(i)`.
- Resolves swing times through the injected `CSwingDetector` by level `leftSwingId` / `rightSwingId` (query-only; **no** detection logic).
- Exposes `bool BuildLevelCommand(const LiquidityLevel &level, VisualCommand &cmd)` — a **pure** command builder with zero MT5 API calls (unit-testable headless).
- `Update()` filters by render window, calls `BuildLevelCommand`, and executes via `VSE.ExecuteBatch()`. It never calls `ObjectMove` / `ObjectSetInteger` / `ObjectDelete` directly.
- Draws **ACTIVE** levels only. Levels in any other status are ignored (no visual re-decision in VF01; see §26).

---

## 15. LAYER ORDER (Z-ORDER)

Creation order in `VisualizationManager::Update()` determines z-order on chart (first created = lowest = furthest back). This order ensures lines are never hidden behind rectangles.

| Order | Renderer | Objects | Z-level |
|---|---|---|---|
| (chart base) | — | Candles | Lowest (chart default) |
| **1** | **FVGRenderer** | `OBJ_RECTANGLE` | Low (rectangles behind all lines) |
| **2** | **OrderBlockRenderer** | `OBJ_RECTANGLE` | Low (rectangles behind all lines) |
| **3** | **ProtectedRenderer** | `OBJ_TREND` | Mid-low |
| **4** | **BOSRenderer** | `OBJ_TREND` | Mid |
| **5** | **CHOCHRenderer** | `OBJ_TREND` | Mid-high |
| **6** | **LiquidityRenderer** | `OBJ_TREND` (EQH/EQL lines) | Mid-high (above CHOCH, below arrows) |
| **7** | **SwingRenderer** | `OBJ_ARROW_DOWN`, `OBJ_ARROW_UP` | High (arrows above lines) |
| **8** | **PivotRenderer** | `OBJ_ARROW` (code 159) | High (circles above lines) |
| **9** (implicit) | All renderers | `OBJ_TEXT` | Highest (labels always on top) |

**Key invariant:** `OBJPROP_BACK = false` for all objects.

**Rationale:**
- Rectangles (FVG, OB) are drawn first so they sit behind trend lines — lines must never disappear under rectangles.
- Trend lines (PP, BOS, CHOCH) are drawn in the middle — they are the primary structural markers.
- Arrows (Swings, Pivots) are drawn last among chart objects so they sit above lines.
- Labels (`OBJ_TEXT`) are created after their parent structure, so they render on top of everything.

---

## 16. COLOR TABLE

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
| Equal Highs (liquidity) | `COLOR_LIQUIDITY_EQH` | Amber (vivid) | `#FFA726` | (255, 167, 38) |
| Equal Lows (liquidity) | `COLOR_LIQUIDITY_EQL` | Cyan (vivid) | `#26C6DA` | (38, 198, 218) |

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

## 17. OBJECT NAMING CONVENTION

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
| Equal Highs / Equal Lows | `SCX_LIQ_LINE_<id>` | `SCX_LIQ_TEXT_<id>` |

`DeleteObjectsByPrefix("SCX_<STRUCTURE>_")` deletes all objects of a given type during `Clear()`.

IDs are sequential integers unique per structure type, incremented on each detection.

---

## 18. UPDATE RULES — MANAGER & RENDERER CONTRACT

### VisualizationManager::Update() (Orchestrator)

```
1. For each renderer in layer order (FVG → OB → PP → BOS → CHOCH → Swings → Pivots):
     renderer.Update()
2. Centralized VSE.EnforceHistoricalLimits()  // batch delete oldest exceeding per-type max
3. ChartRedraw(0)
```

### Renderer::Update() (Command-Based Contract)

```
Update() — every renderer follows this exact pattern:

  1. Guard: if not initialized or no detector → return
  2. count = detector.GetCount()
  3. VisualCommand cmdArray[]  // local array, cleared each cycle

  4. FREEZE PREVIOUS + PROMOTE HISTORICAL:
     if count > m_lastRenderedCount:
       previousActive = GetLastActiveVisualState()
       if previousActive exists:
         cmdArray += CMD_FREEZE(previousActive.name, freezeTime, freezePrice)
         if type has historical tier:
           previousHistorical = GetSecondLastVisualState()
           if previousHistorical exists:
             cmdArray += CMD_PROMOTE_HISTORICAL(previousHistorical.name)

  5. DRAW NEW:
     for i = m_lastRenderedCount to count - 1:
       event = detector.GetEvent(i)
       cmdArray += CMD_DRAW(name, time1, price1, time2, price2, color, label...)
       visualStateArray.Append({name, event, state=Active})

  6. m_lastRenderedCount = count

  7. EXTEND / FINALIZE ACTIVE:
     lastState = visualStateArray.GetLast()
     if lastState.state == Active:
       if type has continuous Extend:
         cmdArray += CMD_EXTEND(lastState.name, currentTime, price)
       if type is CHOCH:
         cmdArray += CMD_FINALIZE(lastState.name, breakTime, breakPrice)

  8. VSE.ExecuteBatch(cmdArray, ArraySize(cmdArray))
```

No renderer calls `ObjectMove()`, `ObjectSetInteger()`, `ObjectSetDouble()`, `ObjectDelete()`, or `ChartRedraw()` directly. All visual mutations go through `VisualCommand` structs executed by the VisualStateEngine.

---

## 19. FROZEN & HISTORICAL OBJECT BEHAVIOR SUMMARY

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

## 20. RENDER CONFIG (INPUTS)

| Input | Type | Default | Description |
|---|---|---|---|
| `ShowSwings` | bool | `true` | Toggle swing high/low arrows |
| `ShowPivots` | bool | `true` | Toggle pivot markers |
| `ShowBOS` | bool | `true` | Toggle BOS lines + labels |
| `ShowCHOCH` | bool | `true` | Toggle CHOCH lines + labels |
| `ShowProtectedPoints` | bool | `true` | Toggle PP lines + labels |
| `ShowOrderBlocks` | bool | `true` | Toggle OB rectangles + labels |
| `ShowFVG` | bool | `true` | Toggle FVG rectangles + labels |
| `ShowLiquidity` | bool | `true` | Toggle EQH/EQL lines + labels |
| `MaxHistoricalSwings` | int | `50` | Max swing arrows kept |
| `MaxHistoricalPivots` | int | `50` | Max pivot markers kept |
| `MaxHistoricalBOS` | int | `30` | Max BOS lines kept |
| `MaxHistoricalCHOCH` | int | `30` | Max CHOCH lines kept |
| `MaxHistoricalPP` | int | `20` | Max PP lines kept |
| `MaxHistoricalOB` | int | `20` | Max OB rectangles kept |
| `MaxHistoricalFVG` | int | `30` | Max FVG rectangles kept |
| `MaxHistoricalLiquidity` | int | `30` | Max EQH/EQL lines kept (FIFO) |
| `LiquidityLabelMode` | ENUM_LIQUIDITY_LABEL_MODE | `DIRECTION` | EQH/EQL label text mode (`NONE` / `SIMPLE` / `DIRECTION` / `DEBUG`) |
| `LiquidityRenderHistoryBars` | int | `300` | Only render EQH/EQL levels formed within this many bars of the current bar |
| `ShowInactiveProtectedPoints` | bool | `false` | Show/hide frozen PP lines |
| `CompactLabels` | bool | `true` | Enable label collision avoidance |
| `ColorTheme` | ENUM_THEME | `DARK` | Chart background for dimming calculations |

---

## 21. IMPLEMENTATION REQUIREMENTS PER RENDERER

Each renderer MUST implement:

```
void Init()          — set initialized = true; reset m_lastRenderedCount to 0; clear visualStateArray
void Update()        — follow the command-based Update contract (§18)
void Shutdown()      — Clear() + set initialized = false
void Clear()         — DeleteObjectsByPrefix() + reset counters + empty visualStateArray
void SetDetector()   — store detector pointer
```

Each renderer MUST include a local `VisualCommand cmdArray[]` that is cleared and rebuilt each `Update()` cycle.

Each renderer MUST NOT:
- Call `ChartRedraw()` (handled once by manager)
- Call `ObjectCreate()` for existing objects (guarded by `CreateObjectIfMissing`)
- Call `ObjectMove()`, `ObjectSetInteger()`, `ObjectSetDouble()`, or `ObjectDelete()` directly (use `VisualCommand` + `VSE.ExecuteBatch`)
- Delete objects that are still Active
- Modify objects after freeze (except through `CMD_PROMOTE_HISTORICAL` via VSE)

---

## 22. CENTRALIZED VISUAL STATE ENGINE — DETAILED INTERFACE

```
class CVisualStateEngine
{
public:
   void Init();                          // clear all internal state
   void Shutdown();                      // clear and release

   // Primary entry point
   void ExecuteBatch(VisualCommand& cmds[], int count);
       // Iterates over command array, dispatches each to the appropriate handler
       // Commands are executed in order — Freeze before Draw in the same batch is valid

   void Execute(VisualCommand& cmd);
       // Single command convenience wrapper

   // Batch operations
   void EnforceHistoricalLimit(string prefix, int maxCount, int& currentCount);
       // FIFO delete oldest exceeding maxCount

   // Queries
   EVisualState GetState(string name);
   bool IsActive(string name);
   bool IsFrozen(string name);
   bool IsHistorical(string name);

private:
   // Command handlers (called by ExecuteBatch)
   void HandleDraw(VisualCommand& cmd);
   void HandleExtend(VisualCommand& cmd);
   void HandleFinalize(VisualCommand& cmd);
   void HandleFreeze(VisualCommand& cmd);
   void HandlePromoteHistorical(VisualCommand& cmd);
   void HandleDelete(VisualCommand& cmd);

   // Internal utilities
   void SetColorDim(string name, double factor);
       // Computes DimColor(baseColor, factor) and applies via ObjectSetInteger(OBJPROP_COLOR)

   void SetLineStyle(string name, ENUM_LINE_STYLE style, int width);
       // ObjectSetInteger for OBJPROP_STYLE and OBJPROP_WIDTH

   void SetRectFill(string name, bool fill);
       // ObjectSetInteger for OBJPROP_FILL

   // State array
   VisualStateRecord stateRecords[];
};
```

### Internal State Record

```
struct VisualStateRecord
{
   string        objName;         // e.g., "SCX_BOS_LINE_5"
   string        textName;        // e.g., "SCX_BOS_TEXT_5"
   EVisualState  state;           // Active / Frozen / Historical
   datetime      freezeTime;      // 0 if Active
   double        freezePrice;     // 0 if Active
   color         baseColor;       // full-intensity color
   ENUM_OBJECT   objType;         // OBJ_TREND or OBJ_RECTANGLE
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

### VisualCommand Struct (Full Definition)

```
struct VisualCommand
{
   EVisualCommandType   type;
   string               objName;
   string               textName;
   ENUM_OBJECT          objType;
   datetime             time1;
   double               price1;
   datetime             time2;
   double               price2;
   color                lineColor;
   color                textColor;
   string               labelText;
   int                  fontSize;
   bool                 isFill;
   int                  width;
};

enum EVisualCommandType
{
   CMD_DRAW,
   CMD_EXTEND,
   CMD_FINALIZE,
   CMD_FREEZE,
   CMD_PROMOTE_HISTORICAL,
   CMD_DELETE
};
```

---

## 23. LABEL COLLISION AVOIDANCE

### Algorithm

```
ResolveLabelPlacement(targetTime, basePrice, direction):   // Track 3
  1. candidatePrice = basePrice
  2. For iteration = 0 to MaxIterations (10):
     a. Check the VSE in-memory label registry (engine-owned OBJ_TEXT
        labels, synced at the single VSE choke point) within a 2-hour
        time window centered on targetTime whose price is within 20
        points of candidatePrice
     b. If no collision → return candidatePrice
     c. If collision → candidatePrice += direction * 20 * _Point * (iteration + 1)
  3. Return last candidatePrice (fallback)
```

Track 3 note: the collision domain is the label registry (exactly the
engine-drawn labels, mirrored on every create/move/delete through the
VSE) instead of a full-chart `ObjectsTotal()` scan. Algorithm, window,
step, direction and iteration cap are unchanged; a live draw-bar cost
of 95-128 ms (label collision scans) drops to microseconds.

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

## 24. COMPLETE UPDATE TICK FLOW

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
10. FVGDetector::Update()                 → detect new FVG
11. VisualizationManager::Update():
     a. FVGRenderer.Update()              → build VisualCommand[] for FVG
     b. OrderBlockRenderer.Update()        → build VisualCommand[] for OB
     c. ProtectedRenderer.Update()        → build VisualCommand[] for PP
     d. BOSRenderer.Update()              → build VisualCommand[] for BOS
     e. CHOCHRenderer.Update()            → build VisualCommand[] for CHOCH
     f. SwingRenderer.Update()            → build VisualCommand[] for swings
     g. PivotRenderer.Update()            → build VisualCommand[] for pivots
     h. VSE.EnforceHistoricalLimits()     → batch FIFO deletes
     i. ChartRedraw(0)                    → single repaint
```

Each renderer's `Update()` builds a local `VisualCommand[]` array and calls `VSE.ExecuteBatch()`. The VSE processes all commands immediately, calling the MT5 API for each.

---

## 25. SUMMARY OF CHANGES FROM V2.0 → V2.1

| Change | v2.0 Spec | v2.1 Spec | Rationale |
|---|---|---|---|
| **Object Ownership** | Implicit | Explicit §2 with Detector / Renderer / VSE ownership | Eliminates future bugs caused by layer boundary violations |
| **Coordinate Contract** | Implicit per type | Explicit §3 table with Time Anchor, Price Anchor, Left Edge, Right Edge | Single source of truth for every object's position |
| **Renderer Responsibility Matrix** | Implicit | Explicit §4 table with Create / Extend / Freeze / Delete per renderer | Makes renderer boundaries crystal clear |
| **Detector → Renderer Flow** | Listed in §20 (Update Tick Flow) | Explicit §5 pipeline diagram with ownership boundaries | Full architectural overview in one place |
| **Visual Command Pipeline** | Direct VSE method calls | `VisualCommand` struct + `VSE.ExecuteBatch()` (§6, §18, §22) | Enables replay, logging, unit testing, regression testing |
| **CHOCH phase name** | "Extend" (one-shot) | "Finalize" — distinct from continuous Extend | Semantic clarity: one-shot vs continuous |
| **OB Mitigation criteria** | "Price enters the zone" (ambiguous) | Exact: `low[i] <= ob.high` (bullish) / `high[i] >= ob.low` (bearish) | Unambiguous implementation |
| **FVG Fill criteria** | "Price trades through gap" (ambiguous) | Exact: `close[i] <= fvg.lower` (bullish) / `close[i] >= fvg.upper` (bearish), body-only, no wick | Unambiguous, matches ICT standard |
| **State machine diagram** | Linear flow | Branching: Active → New Structure? → No=Extend / Yes=Freeze | Accurate representation of the decision point |
| **Future Structures** | Not present | §26 reserves Liquidity Sweep, Equal High/Low, Premium/Discount, Breaker Block, Mitigation Block, IFVG, Liquidity Void | Architecture is extensible without core changes |
| **Equal Highs / Equal Lows** (v2.2, VF01) | Reserved only (§26) | Fully specified §14A: formal definitions (source level/ID, cluster price, formation time, lifecycle, naming, palette, label rules) + `LiquidityRenderer` foundation | Promotes EQH/EQL from reserved to implemented; static lines only; sweep/freeze visuals deferred (VF02+) |

---

## 26. FUTURE STRUCTURES (RESERVED)

The following SMC/ICT structures are reserved for future implementation. When added, each MUST follow the same:
- Universal Visual Lifecycle (§1)
- Object Ownership model (§2)
- Coordinate Contract (§3)
- Renderer Responsibility pattern (§4)
- Visual Command Pipeline (§6, §22)

| Structure | Likely Object Type | Lifecycle | Notes |
|---|---|---|---|
| **Liquidity Sweep** | `OBJ_TREND` + `OBJ_TEXT` | Extend → Freeze → Historical → Delete | Marks where price swept above/below a level before reversing. **VF02+**: includes freeze-on-sweep / invalidation styling for EQH/EQL levels (VF01 draws ACTIVE levels only) |
| **Equal Highs** | `OBJ_TREND` | Static (no extend) | **IMPLEMENTED — VF01 (§14A, `LiquidityRenderer`)** |
| **Equal Lows** | `OBJ_TREND` | Static (no extend) | **IMPLEMENTED — VF01 (§14A, `LiquidityRenderer`)** |
| **Premium / Discount Array** | `OBJ_TREND` + `OBJ_TEXT` | Extend → Freeze → Delete | Midline, premium, and discount levels for the current range |
| **Breaker Block** | `OBJ_RECTANGLE` + `OBJ_TEXT` | Extend → Freeze → Delete | Similar to OB but forms after a failed breakout |
| **Mitigation Block** | `OBJ_RECTANGLE` + `OBJ_TEXT` | Extend → Freeze → Delete | Second OB that forms after the first is mitigated |
| **IFVG (Inverse FVG)** | `OBJ_RECTANGLE` + `OBJ_TEXT` | Extend → Freeze → Historical → Delete | FVG that forms in the opposite direction of the prevailing trend |
| **Liquidity Void** | `OBJ_RECTANGLE` + `OBJ_TEXT` | Extend → Freeze → Delete | Large one-candle imbalance, wider than a standard FVG |

These reserved structures are placeholders. No implementation work is required until explicitly specified.

---

*End of Visual Specification v2.1. No code below this line.*
