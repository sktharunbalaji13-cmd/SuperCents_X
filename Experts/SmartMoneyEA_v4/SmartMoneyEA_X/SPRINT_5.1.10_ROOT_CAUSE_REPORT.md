====================================
SPRINT 5.1.10 ROOT CAUSE REPORT
====================================

**Log Analyzed:** `20260701.log` (Agent-127.0.0.1-3000, 01-Jul-2026 18:14)
**Symbol:** EURUSD, M15
**Total BOS Events Replayed:** 333
**Total CHOCH Events:** 2 failing events detected

---

## FAILING CHOCH EVENT #1

### Complete Forensic Report

```
Source BOS ID:        BOS-1
Source Pivot ID:      PIVOT-499
Direction:            BEARISH
CHOCH Index:          -1
pivotTime:            2024.03.13 11:30
bosTime:              2024.03.12 20:00
chochTime:            2024.03.12 20:00
```

**Chronology Check:**
- CHRONOLOGY ERROR: Pivot time > BOS time
- CHRONOLOGY ERROR: Pivot time >= CHOCH time

**Rule Validation:**
- Rule 1 (Pivot <= BOS):   FAIL   (Pivot 2024.03.13 11:30 > BOS 2024.03.12 20:00)
- Rule 2 (BOS <= CHOCH):   PASS   (BOS 2024.03.12 20:00 <= CHOCH 2024.03.12 20:00)
- Rule 3 (Pivot <= CHOCH): FAIL   (Pivot 2024.03.13 11:30 > CHOCH 2024.03.12 20:00)

**Time Differences:**
- Pivot → BOS:   -55800 seconds
- BOS → CHOCH:   0 seconds
- Pivot → CHOCH: -55800 seconds

### First Failing Rule

**Rule 1 (Pivot <= BOS):** FAIL

### Timestamp Divergence Trace

| Stage | Check | Result | Detail |
|-------|-------|--------|--------|
| **Pivot Creation** | `PIVOT-499` Bar=19954 Time=2024.03.13 11:30 | ✅ PASS | Time correctly assigned to bar 19954 |
| **TASK 2 - Assignment Audit** | `bos.pivotTime = latestLow.time` → 2024.03.13 11:30 | ✅ PASS | Source `latestLow.time` = 2024.03.13 11:30 |
| **BOS Creation (InitialScan)** | BOS#1: Pivot Bar=19954, Pivot Time=2024.03.13 11:30; Break Bar=20016, Break Time=2024.03.12 20:00 | ❌ CHRONOLOGY ERROR | Break Bar (20016) > Pivot Bar (19954) BUT Break Time (2024.03.12 20:00) < Pivot Time (2024.03.13 11:30) |
| **TASK 3 - Timestamp Verification** | stored pivot time vs iTime(pivotBarIndex) | ✅ PASS | Both = 2024.03.13 11:30 |
| **TASK 4 - Stored BOS Verification** | stored.pivotTime == bos.pivotTime | ✅ PASS | Consistent storage |
| **TASK 5 - Replay Verification** | Replay pivot time vs Stored pivot time | ✅ PASS | Both = 2024.03.13 11:30 |
| **TASK 6 - Validator Input** | Pivot time vs BOS time chronology | ❌ FAIL | Chronology error detected |

### Earliest Divergence Point

**Stage: BOS Creation (during InitialScan() in BOSDetector.mqh)**

The timestamps first diverge at the moment the BOS structure is populated during InitialScan(). The pivot time (2024.03.13 11:30) comes from `latestLow.time` for bar 19954, while the BOS break time (2024.03.12 20:00) comes from the bar where the price broke the pivot level (bar 20016).

The core anomaly: **Bar index 20016 > bar index 19954, yet timestamp(bar 20016) = 2024.03.12 20:00 < timestamp(bar 19954) = 2024.03.13 11:30.**

This is not a storage/retrieval inconsistency (all TASKs 2-5 PASS). It is a **logical consistency failure** in the BOS creation algorithm — the break bar is assigned a timestamp that precedes the pivot bar's timestamp, producing a chronologically impossible structure.

---

## FAILING CHOCH EVENT #2

### Complete Forensic Report

```
Source BOS ID:        BOS-2
Source Pivot ID:      PIVOT-497
Direction:            BEARISH
CHOCH Index:          0
pivotTime:            2024.03.13 09:15
bosTime:              2024.03.12 19:45
chochTime:            2024.03.12 19:45
```

**Chronology Check:**
- CHRONOLOGY ERROR: Pivot time > BOS time
- CHRONOLOGY ERROR: Pivot time >= CHOCH time

**Rule Validation:**
- Rule 1 (Pivot <= BOS):   FAIL   (Pivot 2024.03.13 09:15 > BOS 2024.03.12 19:45)
- Rule 2 (BOS <= CHOCH):   PASS
- Rule 3 (Pivot <= CHOCH): FAIL

**Time Differences:**
- Pivot → BOS:   identical pattern as Event #1

**Earliest Divergence:** Same root cause as Event #1 — BOS creation assigns contradictory bar index-to-timestamp mappings.

---

====================================
SPRINT 5.1.10 ROOT CAUSE REPORT
====================================

First Failure:
    Task 6 — Validator Input Audit (CHOCHDetector)
    Rule 1 (Pivot <= BOS): FAIL
    Pivot Time (2024.03.13 11:30) > BOS Time (2024.03.12 20:00)

Exact File:
    Structure/BOSDetector.mqh

Exact Function:
    InitialScan()

Exact Line:
    ~602 (where bos.pivotTime is assigned from latestLow.time), and the subsequent BOS break time assignment where the break bar's iTime() produces a timestamp earlier than the pivot's timestamp.

Exact Statement:
    bos.pivotTime = latestLow.time;  (line ~602 — this assignment is correct, the value is consistent)
    Concurrently: the BOS break bar index (20016) resolves via iTime() to 2024.03.12 20:00 while the pivot bar (19954) resolves to 2024.03.13 11:30.

Root Cause Classification:
    CHRONOLOGICAL INVARIANCE VIOLATION — BOS creation algorithm assigns a break-bar timestamp that precedes the pivot-bar timestamp, despite the break-bar index being greater than the pivot-bar index.  This produces a BOS structure where pivotTime > breakTime, which violates the chronological invariant that pivot ≤ BOS ≤ CHOCH.

Evidence:
    - PIVOT-499 created at Bar=19954, Time=2024.03.13 11:30, Price=1.09201 (Line 32486)
    - BOS#1: Pivot Bar=19954, Pivot Time=2024.03.13 11:30; Break Bar=20016, Break Time=2024.03.12 20:00 (Lines 32510-32517)
    - TASK 2 (Assignment): PASS — bos.pivotTime copied correctly from latestLow.time
    - TASK 3 (Timestamp): PASS — iTime(pivotBarIndex) matches stored pivot time
    - TASK 4 (Storage): PASS — stored values match BOS values
    - TASK 5 (Replay): PASS — replayed values match stored values
    - TASK 6 (Validator): FAIL — CHRONOLOGY ERROR: Pivot time > BOS time (Line 43262)
    - CHOCH FORENSIC REPORT: Rule 1 (Pivot <= BOS): FAIL (Line 43297)

Modification Required:
    YES

    The BOS creation logic in InitialScan() must enforce a chronological invariant:
    The break-bar's timestamp must be >= the pivot-bar's timestamp.
    The current algorithm selects break bars via iLowest()/iHighest() and assigns
    their iTime() directly without validating that the resulting timestamp is
    chronologically after the pivot timestamp.

    Potential fix domains:
    1. Validate and discard/reassign BOS events where breakTime < pivotTime
    2. Use appropriate offset logic when computing break bars to ensure
       the break occurs at bars *after* the pivot bar in chronological order
    3. Add a post-creation filter in InitialScan() that discards BOS events
       violating the chronological invariant (pivotTime <= breakTime)

Overall Confidence:
    HIGH

    All forensic instrumentation checks (TASK 2-5) confirm that data is stored,
    retrieved, and replayed with perfect fidelity. The failure is exclusively a
    logical/chronological issue in BOS creation, not a data corruption or
    serialization problem. The two failing CHOCH events (BOS-1/PIVOT-499 and
    BOS-2/PIVOT-497) exhibit the identical pattern of inverted timestamps.

====================================