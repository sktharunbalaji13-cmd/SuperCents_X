# SPRINT 6 — PROTECTED POINT MANAGER

## OBJECTIVE

Implement a deterministic Protected Point Manager.

### Pipeline
```
StructuralPivotEngine → BOSDetector → TrendState → ProtectedPointManager → CHOCHDetector
```

---

## INPUTS (API Only)

- `CStructuralPivotEngine` - GetPivot, GetPivotCount
- `CBOSDetector` - GetBOS, GetBOSCount  
- `CTrendState` - GetCurrentTrend

---

## OUTPUT

```mqh
struct ProtectedPoint
{
    int    id;
    int    pivotID;
    bool   isHigh;
    datetime time;
    double price;
    int    barIndex;
    bool   active;
};
```

---

## RULES

### Bullish Trend
- Latest valid Structural Low becomes active Protected Low
- Only one active Protected Low

### Bearish Trend
- Latest valid Structural High becomes active Protected High
- Only one active Protected High

### Trend Flip
- Deactivate previous protected point
- Activate new protected point
- Never delete history

---

## ARCHITECTURE

**Create:** `Structure/ProtectedPointManager.mqh`

**Modify:** `Core/Engine.mqh`

**Do NOT modify:** SwingDetector, StructuralPivotEngine, BOSDetector, TrendState

---

## LOGGING

Exactly one message when protection changes:

```
[ProtectedPoint][INFO] Protected Low Activated
ID: 14
Pivot: 267
Price: 1.08241
Time: 2026.01.12 15:30
```

---

## ACCEPTANCE CRITERIA

| Criterion | Expected |
|-----------|----------|
| Compilation errors | 0 |
| Compilation warnings | 0 |
| No rendering | ✅ |
| No ObjectCreate | ✅ |
| Uses only BOS + Trend + Pivot APIs | ✅ |
| Exactly one active Protected High | ✅ |
| Exactly one active Protected Low | ✅ |
| History preserved | ✅ |

---

## VERSION

**v0.6.0 — Protected Point Manager**