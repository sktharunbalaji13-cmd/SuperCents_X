# SPRINT 7 — CHOCH DETECTOR

## OBJECTIVE

Detect Change of Character (CHOCH) when protected levels are broken.

### Pipeline
```
Swings → Pivots → Replacement → BOS → Trend → Protected → CHOCH → OB → Entries
```

---

## RULES

### Bullish Trend
- Active Protected Low exists
- If Close < Protected Low → Generate **Bearish** CHOCH

### Bearish Trend
- Active Protected High exists
- If Close > Protected High → Generate **Bullish** CHOCH

### CHOCH Rules
1. Evaluate ONLY closed candles (never bar 0)
2. One CHOCH per Protected Point
3. Never duplicate
4. Sequential IDs
5. Chronological storage
6. Immutable after creation
7. No rendering
8. TrendState remains read-only

---

## INPUTS (API Only)

- `ProtectedPointManager` - GetActiveHigh, GetActiveLow
- `TrendState` - GetCurrentTrend
- Current candle close

---

## OUTPUT

```mqh
struct CHOCHEvent
{
    int    id;
    int    protectedPointID;
    bool   bullish;
    datetime time;
    double breakPrice;
    int    barIndex;
};
```

---

## ARCHITECTURE

**Create:** `Structure/CHOCHDetector.mqh`

**Modify:** `Utils/Types.mqh`, `Core/Engine.mqh`

**Do NOT modify:** Any frozen module (SwingDetector, StructuralPivotEngine, BOSDetector, TrendState, ProtectedPointManager)

---

## ACCEPTANCE CRITERIA

| Criterion | Expected |
|-----------|----------|
| Compilation errors | 0 |
| Compilation warnings | 0 |
| No runtime errors | ✅ |
| No access violations | ✅ |
| One CHOCH per Protected Point | ✅ |
| Sequential IDs | ✅ |
| No duplicates | ✅ |

---

## VERSION: v0.7.0