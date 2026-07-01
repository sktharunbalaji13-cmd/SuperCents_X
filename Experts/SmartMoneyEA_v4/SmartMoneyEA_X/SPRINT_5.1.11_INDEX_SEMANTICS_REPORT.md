====================================
SPRINT 5.1.11 INDEX SEMANTICS REPORT
====================================

**Log Analyzed:** `20260701.log` (latest run, Agent-127.0.0.1-3000)
**Source Files Examined:** `Structure/BOSDetector.mqh` (1003 lines), `Structure/SwingDetector.mqh` (1152 lines)

---

## TASK 1 — InitialScan Loop Audit

**File:** `Structure/BOSDetector.mqh`
**Lines:** 602-708

```cpp
void InitialScan()
{
    int totalBars = Bars(_Symbol, _Period);
    int scanStart = 4 + 2;                           // = 6
    int scanEnd = totalBars - 4 - 2;                 // = totalBars - 6

    for(int barIndex = scanStart; barIndex <= scanEnd; barIndex++)   // LINE 615
    {
        ...
    }
}
```

| Property | Value |
|----------|-------|
| Loop variable | `barIndex` |
| Loop start | `scanStart` = **6** |
| Loop end | `scanEnd` = `totalBars - 6` |
| Increment direction | **INCREMENTING** (`barIndex++`) |

**Explanation of movement in time:**

In MQL5:
- Bar index **0** = current forming bar (newest, rightmost on chart)
- Bar index **1** = most recent completed bar
- Bar index `totalBars - 1` = oldest bar (leftmost on chart)

An incrementing loop (`barIndex++`) moves from **smaller → larger** indices, which in MQL5 means moving from **NEWEST → OLDEST** bars.

**The loop iterates from bar 6 (relatively new) toward bar totalBars-6 (very old), moving backward in time.**

---

## TASK 2 — Pivot Index Audit

### SwingDetector assignment of `barIndex`

In `SwingDetector::Initialize()` (lines 720-754):
```cpp
for(int i = maxIdx; i >= minIdx; i--)     // Line 728: DECREMENTING
{
    SwingPoint sh;
    sh.barIndex = i;                       // Line 734: MQL5 bar index assigned directly
    ...
    AddSwing(sh);
}
```

The loop `for(int i = maxIdx; i >= minIdx; i--)` starts at the **oldest** bar and moves **newer** (decrementing). Pivots are appended to `m_swingLows[]` in order — oldest first, newest last.

- `m_swingLows[0]` = OLDEST swing low
- `m_swingLows[m_lowCount-1]` = NEWEST swing low

### BOSDetector consumption of `barIndex`

In `InitialScan()` (lines 672-678 for bearish BOS):
```cpp
bos.pivotBarIndex = latestLow.barIndex;   // Line 678: from SwingDetector, NEVER modified
bos.breakBarIndex = barIndex;             // Line 677: the loop variable itself
```

In `FindLatestStructuralPivotAtBar()` (lines 713-741):
```cpp
if(sp.isStructuralPivot && sp.barIndex < upToBar && !IsPivotConsumed(sp.pivotID))
{
    return sp;
}
```

**Verification:** `latestLow.barIndex` is assigned in SwingDetector and **never modified afterward**. The pivot bar index flows from SwingDetector → structural pivot → BOSDetector unchanged.

---

## TASK 3 — Break Bar Calculation

In `InitialScan()` (line 615):
```cpp
for(int barIndex = scanStart; barIndex <= scanEnd; barIndex++)
```

**There is no `iHighest()` or `iLowest()` call.** The break bar IS the loop variable `barIndex` itself.

The break detection is simply:
```cpp
double closePrice = iClose(_Symbol, _Period, barIndex);    // Line 617
// Check if close at this bar breaks the pivot level
bool breaksPivot = (pivot.type == TREND_BEARISH && breakPrice < pivot.price);  // Line 767-768
```

| Property | Value |
|----------|-------|
| Break bar expression | `barIndex` (the loop index itself) |
| Expected meaning | The bar whose close price breaks the pivot |
| Actual MQL5 meaning | An MQL5 bar index; moves from newest → oldest |

In runtime `ScanForBOS()` (line 471):
```cpp
int breakBarIndex = currentBar - 1;   // Bars(_Symbol, _Period) - 1
```
This assigns the **oldest bar index** as the break bar for runtime checks.

---

## TASK 4 — Index Meaning Audit

### pivotBar

```cpp
bos.barsSincePivot = barIndex - latestLow.barIndex;   // Line 684
```

The code assumes **`barIndex > latestLow.barIndex` means "break bar is after pivot bar"**. It computes `barsSincePivot` as a positive number by subtracting the pivot index from the break index.

**Actual MQL5 meaning:** `barIndex > pivotBarIndex` means the break bar is **OLDER** (has a larger index). A positive `barsSincePivot` means the break is at a bar that existed **before** the pivot in chronological time.

### The key comparison in `FindLatestStructuralPivotAtBar()`

```cpp
sp.barIndex < upToBar    // Line 722, 733
```

**What the code likely intends:** Find pivots that occurred **before** the current scanning position.

**What this actually means in MQL5:**
- `sp.barIndex < upToBar`: pivot has a **smaller** index than the scanning bar → pivot is **NEWER** than the scanning bar
- Because in MQL5: smaller index = newer bar

**This comparison finds pivots that are chronologically NEWER than the current scanning bar, and then declares a BOS where the OLDER bar (the scanning bar) breaks the NEWER pivot.** This is chronologically impossible.

### Correct condition for chronological validity

For a valid BOS:
- The pivot must exist **before** the break bar in time
- In MQL5: pivot must have a **larger** index than the break bar (pivot is older)
- The condition should be: `sp.barIndex > upToBar` (pivot is OLDER than current bar)

---

## TASK 5 — Timeline Reconstruction (BOS-1)

| Property | Value | MQL5 Meaning |
|----------|-------|-------------|
| Pivot Bar | **19954** | Relatively NEW bar (close to index 0) |
| Pivot Time | **2024.03.13 11:30** | Later date |
| Break Bar | **20016** | Relatively OLD bar (further from index 0) |
| Break Time | **2024.03.12 20:00** | Earlier date |

**Using correct MQL5 indexing:**
- Bar 19954 < Bar 20016 → Pivot bar is **NEWER** than break bar
- Pivot time (2024.03.13 11:30) > Break time (2024.03.12 20:00) → pivot occurred **after** the break in chronological time

**Does the chronology failure disappear if indices are interpreted using MQL5 indexing rules?**

**YES.** Under correct MQL5 indexing:
- The pivot is at a **newer bar** (smaller index = more recent)
- The break is at an **older bar** (larger index = further in the past)
- pivotTime > breakTime is **expected and correct** for this pair of bars
- But this means the algorithm paired a NEWER pivot with an OLDER break bar — which is **chronologically invalid for a BOS event**

The chronology failure does NOT disappear. The indices are correctly interpreted, but the algorithm selects the wrong pair of bars — it matches a pivot that formed LATER with a bar that broke the level EARLIER.

---

## TASK 6 — Root Cause

**Selected:** **A — Historical scan direction incorrect**

**Detailed justification:**

The `InitialScan()` loop at line 615:
```cpp
for(int barIndex = scanStart; barIndex <= scanEnd; barIndex++)
```

iterates from **newest bars → oldest bars** (incrementing MQL5 index).

For each bar, `FindLatestStructuralPivotAtBar()` at line 722:
```cpp
if(sp.isStructuralPivot && sp.barIndex < upToBar && !IsPivotConsumed(sp.pivotID))
```

returns a pivot whose bar index is **SMALLER** than the current bar — meaning the pivot is **NEWER** than the scanning position.

**The resulting sequence:**
1. At barIndex=20016 (OLDER bar, time=2024.03.12 20:00)
2. Algorithm finds PIVOT-499 at barIndex=19954 (NEWER bar, time=2024.03.13 11:30)
3. Declares a BOS: "older bar 20016 broke newer PIVOT-499"
4. Chronologically: break at 2024.03.12 20:00 < pivot at 2024.03.13 11:30 → IMPOSSIBLE

**Why this is wrong:**
The historical scan should process bars from **oldest → newest** (decrementing `barIndex`) so that pivots are always discovered **before** the bars that could break them. With the current incrementing direction, pivots at smaller indices (newer bars) are matched against bars at larger indices (older bars that precede them in time).

**Supporting evidence from BOS-2:**
- Pivot: PIVOT-497 at barIndex=19963 (newer), time=2024.03.13 09:15
- Break: barIndex=20017 (older), time=2024.03.12 19:45
- Identical pattern: break time precedes pivot time by -55500 seconds

**Evidence that storage/retrieval/replay are not the cause:**
All TASK 2-5 checks PASS. The data is correctly stored, verified, and replayed. The error exists at the moment of BOS creation during InitialScan — the algorithm pairs chronologically impossible bar combinations.

---

## TASK 7 — Final Report

====================================
SPRINT 5.1.11 INDEX SEMANTICS REPORT
====================================

Loop Direction:
    INCREMENTING (newest → oldest) — for(int barIndex = scanStart; barIndex <= scanEnd; barIndex++)
    The loop starts at bar 6 (new bar) and moves toward totalBars-6 (old bar), going backward in time.

Pivot Index Meaning:
    pivotBarIndex = latestLow.barIndex — the MQL5 bar index from SwingDetector. Smaller index = NEWER bar.
    pivotTime = latestHigh.time — calculated by SwingDetector from iTime(_Symbol, _Period, barIndex).

Break Index Meaning:
    breakBarIndex = barIndex — the loop variable itself. Larger index = OLDER bar.
    breakTime = iTime(_Symbol, _Period, barIndex) — calculated from the current loop position.

MQL5 Index Interpretation:
    The code assumes that a positive delta (breakBarIndex - pivotBarIndex > 0) means
    the break bar is AFTER the pivot bar. In MQL5, bar 0 is newest, bar N-1 is oldest.
    Therefore larger barIndex = OLDER bar.
    The positive delta ACTUALLY means the break bar is older than the pivot bar.

First Incorrect Comparison:
    sp.barIndex < upToBar  (BOSDetector.mqh, line 722, 733)
    This filters for pivots whose barIndex is LESS THAN the current scanning position.
    In MQL5, this selects pivots that are NEWER than the current bar.
    The correct condition for chronological validity would be sp.barIndex > upToBar
    (pivot must be older than the break bar).

Exact File:
    Structure/BOSDetector.mqh

Exact Function:
    InitialScan()

Exact Line:
    615 — for(int barIndex = scanStart; barIndex <= scanEnd; barIndex++)
    722 — if(sp.isStructuralPivot && sp.barIndex < upToBar && !IsPivotConsumed(sp.pivotID))

Root Cause:
    HISTORICAL SCAN DIRECTION INCORRECT + WRONG INDEX COMPARISON.
    The incrementing loop (newest→oldest) combined with sp.barIndex < upToBar
    (selecting newer pivots) causes the algorithm to match pivots that form
    CHRONOLOGICALLY AFTER the bars that supposedly break them.
    
    The historical scan must process bars from oldest → newest (decrementing barIndex)
    and find pivots that are OLDER than the current bar (sp.barIndex > upToBar).

Modification Required:
    YES

    The InitialScan() algorithm must be restructured so that:
    1. The loop decrements (oldest → newest chronological order)
    2. Pivot selection requires sp.barIndex > upToBar (pivot older than break bar)
    3. Bars encountered later in the loop (newer bars) are checked against pivots
       discovered earlier (older bars).

Confidence:
    HIGH
    
    Two independent failing CHOCH events (BOS-1 and BOS-2) show the identical
    pattern of inverted timestamps. All data-integrity checks pass perfectly.
    The code analysis reveals the exact mechanism: the incrementing loop scans
    bars from newest to oldest, and the barIndex comparison selects pivots that
    are newer — guaranteeing chronologically impossible BOS pairings whenever
    the scan range spans more than one day of data.

====================================