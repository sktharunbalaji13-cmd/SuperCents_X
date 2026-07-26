# Sprint 12 — Liquidity Detection & Sweep

**Status**: SPECIFICATION FROZEN (pending implementation)  
**Prerequisite**: Sprint 11 (FVG) — FROZEN ✅

---

## Pipeline Position

```
Swing → Pivot → BOS → Trend → PP → CHOCH → OB → FVG → Liquidity → Confluence → Entry
                                                          ↑
                                                    Sprint 12
```

---

## 1. Data Model

### Struct

```cpp
enum LiquidityType
{
    LIQUIDITY_UNKNOWN = 0,
    LIQUIDITY_EQH,           // Equal Highs
    LIQUIDITY_EQL,           // Equal Lows
    LIQUIDITY_EXTERNAL_HH,   // Higher High beyond swing (buy-side)
    LIQUIDITY_EXTERNAL_LL,   // Lower Low beyond swing (sell-side)
    LIQUIDITY_INTERNAL_HH,   // Higher High within range
    LIQUIDITY_INTERNAL_LL    // Lower Low within range
};

enum LiquidityClass
{
    LIQUIDITY_CLASS_UNKNOWN = 0,
    LIQUIDITY_CLASS_BUY_SIDE,
    LIQUIDITY_CLASS_SELL_SIDE
};

enum LiquidityStatus
{
    LIQUIDITY_STATUS_UNKNOWN = 0,
    LIQUIDITY_STATUS_ACTIVE,     // exists, not yet tested
    LIQUIDITY_STATUS_SWEPT,      // price entered the zone
    LIQUIDITY_STATUS_MITIGATED,  // swept + rejected + returned inside
    LIQUIDITY_STATUS_INVALIDATED // expired / structure invalidated it
};

struct LiquidityLevel
{
    int      id;
    datetime time;          // creation time
    double   price;         // the liquidity price level

    LiquidityType  type;
    LiquidityClass classification;
    LiquidityStatus status;

    int      leftSwingId;   // swing that established the left edge
    int      rightSwingId;  // swing that confirmed the level

    bool     swept;
    bool     mitigated;
    bool     invalidated;

    datetime detectedTime;
    datetime sweptTime;
    datetime mitigatedTime;
    datetime invalidatedTime;
};
```

---

## 2. Detection Rules (Explicit)

### 2.1 Equal Highs (EQH)

| Rule | Value |
|---|---|
| Min swings to qualify | 2 swing highs |
| Price tolerance | `EQH_TOLERANCE_PIPS` = 3 pips (0.0003 for EURUSD) |
| Distance between swings | Must be separated by at least 1 bar |
| Detection trigger | On bar close of the 2nd qualifying swing high |
| Re-evaluation | On each NEW swing high within tolerance, merge into existing EQH |

**Logic**:
```
For each new swing high:
    Search existing swing highs within EQH_TOLERANCE_PIPS
    If found ≥ 1 match:
        Create or extend EQH at average price
    Else:
        No EQH (do nothing)
```

### 2.2 Equal Lows (EQL)

Same as EQH but for swing lows with `EQL_TOLERANCE_PIPS` = 3 pips.

### 2.3 External Buy-Side Liquidity

Triggered when a bullish BOS occurs and the broken high becomes a liquidity target above.

**Logic**:
```
New bullish BOS →
    Take the broken pivot high
    Create EXTERNAL_HH LiquidityLevel at pivotPrice + 1 tick
```

### 2.4 External Sell-Side Liquidity

Mirror of buy-side for bearish BOS.

### 2.5 Internal HH/LL

Swing highs/lows that sit within the current range without being EQH or external. Lower priority — can be derived from existing swing data.

---

## 3. Lifecycle State Machine

```
Created (ACTIVE)
    │
    ├──→ Price sweeps the level → SWEPT
    │       │
    │       ├──→ Price returns inside range → MITIGATED
    │       │
    │       └──→ (stays swept, not yet mitigated)
    │
    └──→ Structure invalidates the level → INVALIDATED
            (e.g., trend flip makes it irrelevant,
             new higher/lower structure supersedes it)
```

### Transitions

| From | To | Trigger |
|---|---|---|
| ACTIVE | SWEPT | `low <= price` (buy-side) or `high >= price` (sell-side) |
| ACTIVE | INVALIDATED | Trend flip / new structure supersedes |
| SWEPT | MITIGATED | Close returns inside prior range |
| SWEPT | INVALIDATED | Expiry / superseded |
| ANY | DELETED | Finalized state, removed from visual array |

---

## 4. Invariants (for validation)

### Detection Invariants
- Every EQH has ≥ 2 qualifying swing highs within tolerance.
- Every EQL has ≥ 2 qualifying swing lows within tolerance.
- No two LiquidityLevels share the same `type` + `price` within tolerance (dedup).

### Lifecycle Invariants
```
Created = Swept + Invalidated + StillActive
```
- A level cannot be swept twice.
- A level cannot be mitigated before being swept.
- An invalidated level cannot be swept.

### Sweep Invariants
- `swept == true` ⇒ `sweptTime > 0`
- `mitigated == true` ⇒ `swept == true` AND `mitigatedTime > sweptTime`
- A single bar can sweep multiple levels.

---

## 5. Instrumentation (from day one)

### Detection

```
LIQUIDITY-CREATED ID=17 TYPE=EQH CLASS=BUY_SIDE PRICE=1.18352 SWINGS=2 SWING_IDS=[12,14] TIME=2026.01.18 08:30
```

### Sweep

```
LIQUIDITY-SWEPT ID=17 TYPE=EQH PRICE=1.18352 SWEEPBAR=102 RETURNED=TRUE TIME=2026.01.18 14:00
```

### Invalidation

```
LIQUIDITY-INVALIDATED ID=17 TYPE=EQH REASON=TrendFlip TIME=2026.01.20 10:00
```

### Summary

```
======================== LIQUIDITY SUMMARY ========================
EQH                      18
EQL                      22
External HH              10
External LL               8
Internal HH               5
Internal LL               3

Buy-side                 24
Sell-side                16

Swept                    31
Mitigated                24
Still Active              9
Invalidated               4

Average Lifetime        14 bars
====================================================================
```

---

## 6. Implementation Milestones

| Sprint | Deliverable |
|---|---|
| **12.1** | Object model + struct + lifecycle state machine |
| **12.2** | Detection (EQH, EQL, External HH/LL) |
| **12.3** | Sweep detection + lifecycle transitions |
| **12.4** | Classification + structured logging + shutdown summary |
| **12.5** | 2-month backtest + invariant validation |

---

## 7. Dependency Map

```
SwingDetector ──→ PivotEngine ──→ BOSDetector ──→ TrendState
                                      │
                                      ↓
                               ProtectedPoints ←── CHOCHDetector
                                      │
                                      ↓
                               LiquidityDetector  ←── NEW (Sprint 12.1–12.2)
                                      │
                                      ↓
                               LiquidityClassifier ←── NEW (Sprint 12.4)
                                      │
                                      ↓
                               FVGDetector (Sprint 11)
```

---

## 8. Validation Strategy

Same as FVG:
1. Run 2-month every-tick backtest with full instrumentation
2. Verify all invariants programmatically from the log
3. Compare detection counts against manual swing analysis
4. Cross-check sweep events against price action

---

## 9. Open Questions

- Tolerance: 3 pips fixed, or ATR-based percentage?
- Expiry: How many bars before a non-swept level is invalidated? (suggested: 50 bars / ~12h on M15)
- Merge policy: If a new swing high is within tolerance of an existing EQH, extend or create new?
- Visual rendering: Same OBJ_RECTANGLE approach as FVG, or different visual?
