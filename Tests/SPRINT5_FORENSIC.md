# SPRINT 5 — TREND STATE MACHINE

## OBJECTIVE

Consume BOSEvents and maintain market trend state.

**API:**
- Consumes: `CBOSDetector` (GetBOS, GetBOSCount)
- Outputs: `enum Trend` (UNKNOWN, BULLISH, BEARISH)

---

## TREND LOGIC

| Scenario | Trend State |
|----------|-------------|
| First BOS | Bullish → BULLISH / Bearish → BEARISH |
| Same BOS type | Trend unchanged (strengthens) |
| Opposite BOS | Trend flips (candidate for CHOCH later) |

---

## RULES

1. First BOS sets trend
2. Bullish BOS → Trend = BULLISH
3. Bearish BOS → Trend = BEARISH
4. Opposite BOS → Trend flips (record as CHOCH candidate)
5. Do NOT emit CHOCH yet - just record state

---

## TREND ENUM

```mqh
enum Trend
{
    TREND_UNKNOWN = 0,
    TREND_BULLISH = 1,
    TREND_BEARISH = -1
};
```

---

## FILES

- **Create:** `Structure/TrendState.mqh`
- **Modify:** `Core/Engine.mqh`
- **Do NOT modify:** BOSDetector, SwingDetector, StructuralPivotEngine

---

## ACCEPTANCE CRITERIA

| Check | Expected |
|-------|----------|
| Compilation | 0 errors, 0 warnings |
| First BOS sets trend | ✅ |
| Trend flips on opposite BOS | ✅ |
| No CHOCH emission | ✅ |
| Trend immutable after BOS | ✅ |

---

## NEXT STEP

After validation, proceed to Protected Point Manager (Sprint 6).