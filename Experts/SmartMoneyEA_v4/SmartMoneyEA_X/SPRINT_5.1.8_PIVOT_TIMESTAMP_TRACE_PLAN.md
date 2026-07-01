# SPRINT 5.1.8 — Pivot Timestamp Assignment Trace Plan

## Critical Finding from Sprint 5.1.7

The validator change took effect (error message changed from ">=" to ">"), but **16 errors persist**.

**Key Evidence:**
- Error message: "Pivot time > BOS time" (not ">=")
- This means pivotTime is **STRICTLY AFTER** bosTime
- This is NOT a same-bar edge case
- This indicates pivot was created AFTER BOS break

## Root Cause Hypothesis

**The pivot timestamps in the historical data are AFTER the BOS break timestamps.**

This violates the fundamental principle: **pivots must exist before they can be broken.**

## Investigation Plan

### TASK 1 — Trace Swing Creation

Add diagnostics in `SwingDetector.mqh`:

**Location 1:** `Initialize()` function (lines 697-718)
**Location 2:** `Update()` function (lines 731-748)
**Location 3:** `DetectSwingHigh()` function (lines 751-761)
**Location 4:** `DetectSwingLow()` function (lines 763-773)

**Print:**
```
SWING CREATED
Address: <memory address>
Type: HIGH/LOW
Price: <price>
Time: <time>
Bar: <barIndex>
PivotID: <pivotID>
Impulse: <impulsePoints>
Structural: <isStructuralPivot>
```

### TASK 2 — Trace Structural Promotion

Add diagnostics in `SwingDetector.mqh`:

**Location:** `DoPromoteToStructuralPivot()` function (lines 538-576)

**Print BEFORE promotion:**
```
STRUCTURAL PROMOTION - BEFORE
Address: <memory address>
Time: <time>
Bar: <barIndex>
Price: <price>
PivotID: <pivotID>
```

**Print AFTER promotion:**
```
STRUCTURAL PROMOTION - AFTER
Address: <memory address>
Time: <time>
Bar: <barIndex>
Price: <price>
PivotID: <pivotID>
```

**Verify:** Time unchanged, Bar unchanged

### TASK 3 — Trace BOS Selection

Add diagnostics in `BOSDetector.mqh`:

**Location 1:** `ScanForBOS()` function (lines 413, 460)
**Location 2:** `InitialScan()` function (lines 529, 559)

**Print:**
```
BOS SELECTED PIVOT
Pivot Address: <memory address>
PivotID: <pivotID>
Pivot Time: <pivot.time>
Pivot Bar: <pivot.barIndex>
Break Time: <breakTime>
Break Bar: <breakBarIndex>
Difference (bars): <breakBarIndex - pivot.barIndex>
Difference (seconds): <breakTime - pivot.time>
```

### TASK 4 — Trace BOSEvent Construction

Add diagnostics in `BOSDetector.mqh`:

**Location 1:** `ScanForBOS()` function (lines 422-438, 469-485)
**Location 2:** `InitialScan()` function (lines 536-552, 566-582)

**Print BEFORE BOSEvent creation:**
```
SOURCE PIVOT
Address: <memory address>
Time: <latestHigh.time>
Bar: <latestHigh.barIndex>
```

**Print AFTER BOSEvent creation:**
```
BOSEVENT CREATED
Stored Pivot Time: <bos.pivotTime>
Stored Pivot Bar: <bos.pivotBarIndex>
Stored Break Time: <bos.breakTime>
Stored Break Bar: <bos.breakBarIndex>
```

**Verify:** Values unchanged from source pivot

### TASK 5 — Trace Replay

Add diagnostics in `Core/Engine.mqh`:

**Location:** `ReplayHistoricalBOS()` function (lines 260-395)

**Print:**
```
REPLAY BOS
Pivot Time: <bos.pivotTime>
Break Time: <bos.breakTime>
Current Time: <current bar time>
```

**Verify:** Replay does not modify timestamps

### TASK 6 — Trace CHOCH

Add diagnostics in `Structure/CHOCHDetector.mqh`:

**Location:** `Update()` function (lines 280-341)

**Print:**
```
CHOCH INPUT
Pivot Time: <bos.pivotTime>
Break Time: <bos.breakTime>
CHOCH Time: <choch.breakTime>
```

**Verify:** All values identical to BOSEvent

### TASK 7 — Automatic Divergence Detection

Add diagnostics in `Structure/CHOCHDetector.mqh`:

**Location:** `ValidateCHOCHChronology()` function (lines 180-212)

**Add BEFORE validation:**
```cpp
if(pivotTime > bosTime)
{
   m_logger.Error("====================================");
   m_logger.Error("TIMESTAMP DIVERGENCE DETECTED");
   m_logger.Error("====================================");
   m_logger.Error("File: CHOCHDetector.mqh");
   m_logger.Error("Function: ValidateCHOCHChronology");
   m_logger.Error("Line: 188");
   m_logger.Error("Pivot Time: " + TimeToString(pivotTime));
   m_logger.Error("Pivot Bar: " + IntegerToString(/* need bar index */));
   m_logger.Error("BOS Time: " + TimeToString(bosTime));
   m_logger.Error("BOS Bar: " + IntegerToString(/* need bar index */));
   m_logger.Error("Difference Seconds: " + IntegerToString((long)(pivotTime - bosTime)));
   m_logger.Error("Difference Bars: " + IntegerToString(/* need bar index */));
   m_logger.Error("====================================");
}
```

### TASK 8 — Memory Identity Audit

Add diagnostics to track memory addresses:

**In SwingDetector:**
- Print address of SwingPoint when created
- Print address when promoted
- Print address when returned by GetSwingHigh/GetSwingLow

**In BOSDetector:**
- Print address of SwingPoint when selected
- Print address of BOSEvent when created
- Verify if BOSEvent contains copy or reference

**In Engine:**
- Print address of BOSEvent when retrieved from storage
- Print address when passed to CHOCHDetector

**In CHOCHDetector:**
- Print address of BOSEvent when received
- Print address of CHOCHEvent when created

### TASK 9 — Final Timeline

For every failing CHOCH, produce:

```
CHOCH #N TIMELINE
=================
1. Pivot Created: Time=<time> Bar=<bar>
2. Structural Promotion: Time=<time> Bar=<bar>
3. BOS Selected: Time=<time> Bar=<bar>
4. BOSEvent Stored: PivotTime=<time> BreakTime=<time>
5. Replay: PivotTime=<time> BreakTime=<time>
6. CHOCH: PivotTime=<time> BreakTime=<time>
7. Validation: FAIL (PivotTime > BOSTime)
```

### TASK 10 — Final Report

Produce:
```
======================================
SPRINT 5.1.8
PIVOT TIMESTAMP TRACE
======================================

Timestamp Modified: YES / NO

First Wrong Timestamp:
File: <file>
Function: <function>
Line: <line>
Statement: <exact statement>

Object Copied: YES / NO

Replay Modified: YES / NO

Root Cause: <exact cause>

======================================
```

## Implementation Strategy

1. Add temporary diagnostic logging to all 4 files
2. Compile and run backtest
3. Extract log data
4. Identify first point of divergence
5. Remove diagnostics
6. Produce final report

## Files to Modify (Temporary Diagnostics Only)

1. `Structure/SwingDetector.mqh` - Add swing creation and promotion logs
2. `Structure/BOSDetector.mqh` - Add BOS selection and construction logs
3. `Core/Engine.mqh` - Add replay logs
4. `Structure/CHOCHDetector.mqh` - Add divergence detection

## Constraints

- NO modifications to detection algorithms
- NO modifications to validation rules
- NO modifications to replay logic
- ONLY add temporary diagnostic output
- All diagnostics must be removable after investigation