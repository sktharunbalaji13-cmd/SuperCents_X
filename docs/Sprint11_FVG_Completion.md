# Sprint 11 — Fair Value Gap: Completion Record

**Status**: FROZEN ✅  
**Date**: 2026-07-22  
**Author**: Forensic audit & optimization

---

## 1. Scope

Complete validation and optimization of the Fair Value Gap (FVG) subsystem:
- Detection (three-candle ICT logic)
- Lifecycle (Created → Filled/Frozen or Invalidated/Deleted)
- Rendering (visual state management)
- Performance (incremental scan)

---

## 2. Original O(n) Scan Issue

`DetectFVG()` re-scanned **all historical bars on every tick**:

```cpp
for(int i = rates_total - 1; i >= 2; i--)  // O(rates_total) per tick
```

In a 2-month M15 backtest (2026.01.01 → 2026.03.01):
- **4,663,618** three-candle windows evaluated
- **223,031** duplicate rejections (same FVGs re-checked on every bar)
- **3.1 GB** log size from rejection instrumentation

---

## 3. Incremental Scan Implementation

**File**: `Structure/FVGDetector.mqh` (lines 86–277)

**Approach**: Track `m_lastProcessedTime` and scan only new windows on each update.

### State machine

```
m_lastProcessedTime == 0    → Full scan (first call)
time[0] < m_lastProcessedTime → Time discontinuity, reset & full scan
time[0] == m_lastProcessedTime → No new bar, skip detection
time[0] > m_lastProcessedTime  → New bar(s): scan only new windows
```

### Boundary fix: `newBars + 2` not `newBars + 1`

The first attempt used `start_i = MathMin(newBars + 1, rates_total - 1)`, which only scanned `i=2` (A=2, B=1, C=0) — the window with the **current forming bar** (body=0). This caused all in-test FVGs to be missed because the window that **just became all-completed** (`i=3`: A=3, B=2, C=1) was skipped.

**Fix**: `start_i = MathMin(newBars + 2, rates_total - 1)`

This ensures both windows are processed on each new bar:
- `i=3` — the window where the previously-forming bar at C is now fully completed
- `i=2` — the new window with the current forming bar

---

## 4. Performance Improvement

| Metric | Before (Full Scan) | After (Incremental) | Improvement |
|---|---|---|---|
| Candidate evaluations | 4,663,618 | 3,638 | **99.92% reduction** |
| Log size | 3.1 GB | 69.7 MB | **~50× smaller** |
| Compile warnings | 4 (pre-existing) | 4 (pre-existing) | Unchanged |

---

## 5. Validation — Behavioral Equivalence

### 5.1 FVG Detection

| Check | Result |
|---|---|
| Historical FVGs (IDs 0–51) | ✅ Identical count, timestamps, gaps |
| In-test FVGs (IDs 52–59) | ✅ All 8 present and correct |
| FVG #54 (bearish, Jan 26 09:30) | ✅ Gap [1.18488, 1.18534] |
| FVG #55 (bullish, Jan 26 11:15) | ✅ Gap [1.18558, 1.18579] |

### 5.2 Lifecycle

| Transition | Count |
|---|---|
| Created | 60 |
| Filled | 5 |
| Frozen | 5 |
| Invalidated | 55 |
| Deleted | 55 |

### 5.3 Conservation Invariants

| Invariant | Check |
|---|---|
| Created = Filled + Invalidated | 60 = 5 + 55 ✅ |
| Filled = Frozen | 5 = 5 ✅ |
| Invalidated = Deleted | 55 = 55 ✅ |
| No duplicate transitions | ✅ |
| No active FVGs at end of test | ✅ |

### 5.4 Rejection Breakdown (3,638 total)

| Reason | Count |
|---|---|
| bodyA too small | ~73% |
| bodyC too small | ~14% |
| duplicate (full-scan legacy) | ~5% |
| same direction | ~4% |
| bearish no-gap | ~2% |
| bullish no-gap | ~2% |

All rejection reasons match the full-scan baseline. No false negatives.

---

## 6. Known Limitations (Deferred)

### 6.1 Renderer `MaxHistoricalFVG` FIFO cleanup
`FVGRenderer` unconditionally deletes visual states when count exceeds `MaxHistoricalFVG (30)`, even for lifecycle-active FVGs. Currently safe because new FVGs are created slowly (< 30 active). If creation rate surges, lifecycle transitions could be silently lost.

**Fix suggested**: Only delete visual states with `status == FROZEN`.

### 6.2 Renderer-detector coupling
`CheckFilled()` in `FVGRenderer` directly syncs `filled`/`invalidated` flags from the detector. Functionally correct but couples the two subsystems. An event/callback pattern would be cleaner but adds complexity that isn't justified yet.

---

## 7. Classification Architecture (Phase 1)

A pure classifier was added as a second stage after detection, keeping the detector itself unchanged:

```
DetectFVG() → Create FVG → ClassifyFVG() → Store + Log
```

### Classification Fields

| Field | Type | Values |
|---|---|---|
| `fvgClass` | FVGClass | UNKNOWN, BREAKAWAY, CONTINUATION, REVERSAL |
| `classEventId` | int | BOS or CHOCH ID that triggered the class |
| `classEventType` | int | 1=BOS, 2=CHOCH |
| `gapSizePips` | double | Gap size in pips |
| `sizeCategory` | FVGSizeCategory | SMALL (<3), MEDIUM (3-10), LARGE (>10) |
| `strength` | FVGStrength | WEAK (<5), NORMAL (5-15), STRONG (>15) |
| `displacementBodyPips` | double | Displacement candle body in pips |

### Classification Priority

1. **REVERSAL** — Recent CHOCH (within 3 bars) with FVG in same direction as the CHOCH
2. **BREAKAWAY** — Recent BOS (within 3 bars) with FVG in same direction as the BOS
3. **CONTINUATION** — No recent event, FVG aligns with current trend
4. **UNKNOWN** — None of the above

### Decision Evidence

Each classification is preceded by a rationale log explaining why:

```
FVG-CLASS ID=54 REVERSAL CHOCH=TRUE(ID=12) BOS=FALSE BarsSinceCHOCH=0 Trend=BEARISH
FVG-CREATED ID=54 TYPE=BEARISH CLASS=REVERSAL SIZE=4.6(MEDIUM) STRENGTH=NORMAL GAP=[1.18488, 1.18534] TIME=2026.01.26 09:30
```

This enables instant verification: if CLASS=BREAKAWAY but BarsSinceBOS=11, the classification is inconsistent.

### Shutdown Summary

```
======================== FVG CLASSIFICATION ========================
Total Created           60

Breakaway               14
Continuation            31
Reversal                15

Small                   18
Medium                  27
Large                   15

Weak                    12
Normal                  29
Strong                  19
====================================================================
```

Useful for sanity-checking distributions — 0 Breakaway or 100% Strong would indicate threshold problems.

---

## 8. Files Changed

| File | Change |
|---|---|
| `Utils/Constants.mqh` | Added classification constants (`FVG_CLASS_LOOKBACK_SECONDS`, size/strength thresholds) |
| `Utils/Types.mqh` | Added `FVGClass`, `FVGSizeCategory`, `FVGStrength` enums + classification fields to `FairValueGap` |
| `Structure/FVGDetector.mqh` | Added `m_lastProcessedTime`, incremental scan logic, `+2` boundary fix, `ClassifyFVG()` with evidence logging, summary counters in `Shutdown()` |
| `Core/Engine.mqh` | Added `SetBOSDetector`/`SetCHOCHDetector` calls to FVGDetector after initialization |

---

## 9. Freeze Decision

The FVG subsystem is **production-ready** within the current architecture. All detection logic, lifecycle management, rendering, classification, and performance are verified against a 2-month every-tick backtest. No regressions.

Future changes to the FVG detector must reproduce the validation evidence above.

---

## 10. Next: Sprint 12 — Liquidity Validation
