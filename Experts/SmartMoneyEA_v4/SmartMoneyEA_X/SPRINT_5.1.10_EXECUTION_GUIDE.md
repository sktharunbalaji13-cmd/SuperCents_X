# SPRINT 5.1.10 - Execution Guide

## IMPORTANT: Manual Steps Required

**I (the AI assistant) cannot directly:**
- Execute MetaTrader 5
- Compile MQL5 code
- Run the EA on a chart
- Access the trading terminal

**You (the user) must:**
1. Open MetaTrader 5
2. Compile the EA
3. Run it on a chart
4. Collect the logs
5. Provide the logs to me for analysis

---

## Step-by-Step Execution Instructions

### STEP 1: Delete Previous Logs (REQUIRED)

**Location:** `C:\Users\k.tharun balaji\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\SmartMoneyEA_v4\SmartMoneyEA_X\Logs\`

**Action:** Delete all files in the Logs folder to start fresh.

**OR** Delete the specific log file:
```
../../../../../../Tester/D0E8209F77C8CF37AD8BF550E51FF075/Agent-127.0.0.1-3000/logs/20260701.log
```

---

### STEP 2: Compile the EA

1. **Open MetaTrader 5**
2. **Press F4** to open MetaEditor
3. **Navigate to:** `SmartMoneyEA_X.mq5`
4. **Press F7** to compile
5. **Verify:** No compilation errors

**Expected Output:**
```
0 errors, 0 warnings
```

---

### STEP 3: Configure EA Inputs

1. **Return to MetaTrader 5**
2. **Attach EA to chart** (any symbol with historical data)
3. **In Inputs tab, set:**
   ```
   InpLogLevel = LOG_ERROR  (or LOG_INFO for more detail)
   ```
4. **Click OK**

---

### STEP 4: Run and Collect Logs

1. **Wait for initialization** (10-30 seconds)
2. **Check Experts log:**
   - View → Experts Logs
   - Or: Terminal → Experts tab
3. **Copy ALL log content**
4. **Save to file:** `forensic_log.txt`

---

### STEP 5: Provide Logs for Analysis

**Option A: Copy-Paste**
- Paste the log content directly into chat
- I will analyze it immediately

**Option B: Save File**
- Save log as `forensic_log.txt` in project directory
- Tell me: "Log file ready for analysis"
- I will read and analyze it

---

## What to Look For in Logs

### Critical Evidence Markers:

```
[TASK 1] CHOCH FORENSIC REPORT
  → Only appears on chronology failures
  → Contains detailed failure analysis

[TASK 2] ASSIGNMENT AUDIT
  → Should appear for every BOS event
  → Shows: bos.pivotTime = latestHigh.time

[TASK 3] TIMESTAMP VERIFICATION
  → Should appear for every BOS event
  → Verifies: pivot.time == iTime(Symbol(), Period(), pivotBarIndex)

[TASK 4] STORED BOS VERIFICATION
  → Should appear for every BOS event
  → Verifies: stored.pivotTime == bos.pivotTime

[TASK 5] REPLAY VERIFICATION
  → Should appear for every BOS during replay
  → Verifies: Replay data matches stored data

[TASK 6] VALIDATOR INPUT AUDIT
  → Should appear for every CHOCH validation
  → Shows: pivotTime, bosTime, chochTime

[CHRONOLOGY ERROR]
  → Indicates failing CHOCH events
  → Shows which rule failed
```

---

## Expected Log Volume

**For a typical chart with 1000 bars:**
- ~50-200 BOS events
- ~5-50 CHOCH events
- **Total log lines:** 500-2000 lines

**Log level LOG_ERROR:** ~100-500 lines (only errors and critical info)
**Log level LOG_INFO:** ~500-2000 lines (all verification points)

---

## Automated Analysis (After You Provide Logs)

Once you provide the log file, I will:

1. **Parse all TASK markers**
2. **Identify all FAILures**
3. **Extract forensic reports**
4. **Classify root cause** (A-G)
5. **Generate final report** with:
   - Exact file/function/line of failure
   - Root cause classification
   - Evidence trail
   - Modification requirement (YES/NO)

---

## Troubleshooting

### No logs generated?
- Check: EA is attached to chart
- Check: Log level is not LOG_NONE
- Check: Experts tab is visible

### Compilation errors?
- Share error messages
- I will fix them

### No CHOCH events detected?
- Need market structure reversal in data
- Try different symbol/timeframe
- Check: Structural pivots are being created

---

## Quick Start Command

After you run the EA and collect logs, simply say:

**"Log file ready for analysis"**

OR

**"Here are the logs: [paste logs]"**

I will immediately:
1. Analyze all evidence
2. Classify root cause
3. Produce final report

---

## Current Status

✅ **Instrumentation:** COMPLETE
✅ **Log Analyzer:** READY (`analyze_forensic_logs.py`)
⏳ **Compilation:** PENDING (you must do this)
⏳ **Execution:** PENDING (you must do this)
⏳ **Log Collection:** PENDING (you must do this)
⏳ **Analysis:** READY (I will do this after you provide logs)

---

*Next Action: Compile and run the EA in MetaTrader 5, then provide the logs.*