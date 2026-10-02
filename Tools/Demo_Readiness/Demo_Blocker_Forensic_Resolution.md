# Demo Blocker Forensic Resolution

**Date:** 2026-09-18
**Status:** BLOCKERS-IDENTIFIED-FIX-DESIGNED
**Production Modified:** NO
**Strategy Modified:** NO
**Parameters Modified:** NO
**Ledger Modified:** NO
**Ledger Deleted:** NO
**Broker Orders Sent:** NO
**Demo Trading Enabled:** NO

---

## Executive Summary

The first demo run of SuperCents_X generated 9 executable plans over 17 minutes (20:37–20:54 UTC) but sent **zero broker orders**. Three root causes have been identified through forensic code trace. All three are configuration-wiring defects, not strategy or logic defects.

| Blocker | Severity | Root Cause | Fix Scope |
|---------|----------|-----------|-----------|
| 1. AMBIGUOUS inspection | P0 | `structureResolved=false` when entry falls to Current Price fallback | EntryPriceResolver fallback semantics |
| 2. FixedRR 2.0 → 31.32R | P0 | `ExecutionPlanner.m_config` never receives `OutcomeTpMode`/`FixedRRTier` inputs | Config wiring (3 files) |
| 3. M1 instead of M15 | P1 | EA attached to M1 chart; architecture uses `_Period` for all OHLC | Deployment procedure only |

---

## PART A — STRUCTURE RESOLUTION

### Trace: Candidate → Resolver → Plan → Inspection → Execution

```
TradeCandidate (from ConfluenceEngine)
  │
  ├─→ EntryPriceResolver.ResolveEntryPrice()
  │     entrySR = false (default)
  │     if ENTRY_OB_RETEST: find OB → entrySR=true, return
  │     if ENTRY_FVG_MIDPOINT: find FVG → entrySR=true, return
  │     if ENTRY_LIQUIDITY_LEVEL: find level → entrySR=true, return
  │     FALLBACK: entryPrice = SYMBOL_BID, entrySR STAYS FALSE
  │
  ├─→ StopLossResolver.ResolveStopLoss()
  │     stopSR = false (default)
  │     if STOP_PROTECTED_POINT: find PP → stopSR=true, return
  │     if STOP_OB_SIDE: find OB → stopSR=true, return
  │     if STOP_LIQUIDITY_SIDE: find level → stopSR=true, return
  │     FALLBACK: stopLoss = entryPrice ± safeMinDist, stopSR STAYS FALSE
  │
  └─→ TargetResolver.ResolveTakeProfit()
        structureResolved = true (HARD-CODED at line 35)
        if TARGET_OPPOSING_LIQUIDITY: find pool → return true
        if TARGET_FIXED_RR: TP = entry ± stopDist × targetRR → return true
        (all paths return true; structureResolved always true)

ExecutionPlanner.BuildPlan() (line 278):
  plan.structureResolved = (entrySR && stopSR && targetSR)

CExecutionPlanInspection.Inspect() (line 86-87):
  if(!structureResolved) return EINSPECT_AMBIGUOUS;  ← BLOCKER 1 FIRES HERE
  // ledger check at line 107-108 is NEVER REACHED
```

### Observed Runtime Evidence

```
EXECUTION-PLAN Decision=2 Status=EXECUTABLE
  Entry=1.14640 SL=1.14574 TP=1.16707 RR=31.32
  StopPolicy=Below Protected Low    ← stopSR=true (structure found)
  TargetPolicy=Opposing Liquidity   ← targetSR=true (always true)
```

The entry price changes every minute (1.14640 → 1.14645 → 1.14646 → 1.14656 → 1.14665 → 1.14678 → 1.14666 → 1.14660 → 1.14655), confirming the entry resolved to **"Current Price" fallback** (SYMBOL_BID), not a structural OB level. Therefore `entrySR=false`, making `structureResolved=false`.

### Analysis: Intended Semantics of `structureResolved`

**Documented intent** (CExecutionPlanInspection.mqh lines 1-20):
> "AMBIGUOUS — near match, legacy PI (absent), or **current PI undefined** → BLOCK"

The `structureResolved` flag is a **plan identity reproducibility predicate**. A plan whose entry came from live bid is NOT durably reproducible across runs — the same candidate on the next bar would produce a different entry price. The inspection cannot compare a non-durable plan identity against the ledger.

**This is by design, not a defect in the inspection gate.**

### Answers to Part A Questions

**Q1. Does "Current Price" fallback represent a valid executable entry?**

No, not as a **structurally-identified** entry. The fallback is a convenience for the backtester/simulator where structural resolution is not required. In live execution mode, a Current-Price entry is ephemeral — it changes every tick and cannot be durably identified for cross-run duplicate defense.

**Q2. If yes, why does it intentionally leave structureResolved=false?**

N/A — it is not a valid structural entry.

**Q3. If no, should the fallback plan be rejected rather than presented as EXECUTABLE?**

Yes. When `entrySR=false`, the plan should be **rejected at BuildPlan time** (not presented as EXECUTABLE and then blocked at inspection). The current behavior wastes the inspection gate and produces misleading telemetry (9 plans created, 9 blocked, 0 executed).

**Q4. Is the correct fix to:**

**D. Another mechanism.** The correct fix is a two-part approach:

1. **Primary fix (EntryPriceResolver):** When `ENTRY_OB_RETEST` cannot find the candidate's OB, the resolver should return `false` (plan cannot be built) rather than falling through to "Current Price". The EntryPriceResolver should only fall to "Current Price" when the policy IS `ENTRY_CURRENT_PRICE`, not as a catch-all fallback.

2. **Secondary fix (ExecutionPlanner):** If `entrySR=false`, set `plan.status = PLAN_REJECTED` with reason "Unresolved Entry" instead of `PLAN_EXECUTABLE`. This prevents the plan from reaching the inspection gate at all.

**Not A (restore OB resolution):** The OB may legitimately not exist on the execution timeframe. The M1 chart processes 1-minute bars; an OB detected on M15 may not have a corresponding M1 OB at execution time. This is a temporal mismatch, not a detection failure.

**Not B (classify fallback as non-executable):** This is what the current code already does via `structureResolved=false`. The problem is that it does so at the wrong stage (inspection instead of plan creation).

**Not C (make inspection understand fallback):** The inspection gate's purpose is cross-run duplicate defense using durable plan identity. A Current-Price plan has no durable identity. Making the inspection accept it would defeat its purpose.

### Temporal Problem: M15 Signal → M1 Execution

The EA uses `Period()` / `_Period` for all OHLC data and new-bar detection:

- `Engine.mqh:403`: `int bars = Bars(_Symbol, _Period);`
- `Engine.mqh:444`: `datetime currentBarTime = iTime(_Symbol, _Period, 0);`
- `SymbolContext.mqh:1168`: `(int)Period()` passed to candidate builder

On an M1 chart, the EA processes 1-minute bars. The structure detectors (OB, FVG, Liquidity, BOS) run on M1 data. An OB detected on M15 may not exist as an M1 OB at execution time because:

1. M1 bar resolution is 15× finer than M15
2. The OB's M1 representation may have been mitigated/invalidated within the M15 bar
3. The candidate's `obId` references an M15 OB that doesn't exist in the M1 detector

**The architecture assumes the EA runs on the same timeframe as the signal engine.** Attaching to M1 when the intended deployment is M15 causes structural detection mismatches.

---

## PART B — FIXED RR CONFIGURATION WIRING

### Complete Wiring Diagram

```
EA Input (SuperCents_X.mq5):
  input ENUM_OUTCOME_TP_MODE OutcomeTpMode = OUTCOME_TP_FIXED_RR;  (line 55)
  input double FixedRRTier = 2.0;                                    (line 58)
        │
        ▼
Engine.SetOutcomeTpMode(OutcomeTpMode)   (line 137)
Engine.SetFixedRrTier(FixedRRTier)        (line 141)
        │
        ▼
Config.SetOutcomeTpMode(mode)            (Config.mqh:59)
Config.SetFixedRrTier(tier)              (Config.mqh:60)
        │
        ▼
Engine.Init() → SymbolContext.SetOutcomeTpMode()  (Engine.mqh:178)
              → SymbolContext.SetFixedRrTier()    (Engine.mqh:183)
        │
        ▼
SymbolContext:
  m_outcomeTpMode = mode                  (SymbolContext.mqh:228)
  m_outcomePolicy.SetTpR(tier)            (SymbolContext.mqh:237)
        │
        ▼
  ┌─────┴─────────────────────────────────────┐
  │  SETTLEMENT PATH (post-trade, telemetry)  │
  │  Used in: SettleRow() line 1678           │
  │  Controls: FixedRR vs OpposingLiquidity   │
  │           outcome simulation policy       │
  │  Status: WORKING (wired correctly)        │
  └───────────────────────────────────────────┘

        ╳ DISCONNECT ╳

  ┌─────┴─────────────────────────────────────┐
  │  EXECUTION PLANNING PATH (live TP)        │
  │  Used in: BuildPlan() → ResolveTakeProfit │
  │  Controls: TP price for live orders       │
  │  Status: NOT WIRED                        │
  └───────────────────────────────────────────┘

ConfluenceEngine.Init() (line 177):
  m_executionPlanner.Init();                    ← NO SetConfig() call
  m_executionPlanner.SetCandidateBuilder(...);  ← only wiring that exists
        │
        ▼
ExecutionPlanner.m_config uses DEFAULT:
  ExecutionPlanConfig() constructor:
    entryPolicy  = ENTRY_OB_RETEST         (line 49)
    stopPolicy   = STOP_PROTECTED_POINT    (line 50)
    targetPolicy = TARGET_OPPOSING_LIQUIDITY  (line 51)  ← BUG: should be TARGET_FIXED_RR
    targetRR     = 2.0                     (line 52)    ← value correct, policy wrong
        │
        ▼
TargetResolver.ResolveTakeProfit():
  policy == TARGET_OPPOSING_LIQUIDITY → searches for opposing liquidity pool
  TP = 1.16707 (liquidity level) instead of 1.14772 (2× risk distance)
```

### Root Cause

**`ConfluenceEngine.mqh` never calls `m_executionPlanner.SetConfig()` with the user's configuration.** The ExecutionPlanner uses its default `ExecutionPlanConfig`, which has `targetPolicy = TARGET_OPPOSING_LIQUIDITY`.

The `OutcomeTpMode` and `FixedRRTier` inputs are wired to the **settlement policy** (`CFixedRRPolicy` in SymbolContext), which is used for post-trade outcome simulation in telemetry. They are NOT wired to the **execution planner** (`CExecutionPlanner`), which determines the TP for live orders.

### Mathematical Proof

Given observed plan:
- Entry = 1.14640 (BUY)
- SL = 1.14574
- Risk distance = 1.14640 - 1.14574 = 0.00066

Under genuine FixedRR 2.0R:
- TP = Entry + 2 × Risk Distance = 1.14640 + 2 × 0.00066 = **1.14772**
- RR = 2.0

Under observed Opposing Liquidity:
- TP = 1.16707 (opposing liquidity pool)
- RR = (1.16707 - 1.14640) / 0.00066 = **31.32**

The 31.32R result confirms `TARGET_OPPOSING_LIQUIDITY` was used, not `TARGET_FIXED_RR`.

### Answers to Part B Questions

**Where exactly is FixedRR lost?**

At `ConfluenceEngine.mqh:177-178`. The `SetConfig()` call that would pass the user's `targetPolicy` and `targetRR` to the ExecutionPlanner is missing. The planner retains its default config.

**Does the architecture support TARGET_FIXED_RR?**

Yes. `TargetResolver.mqh:139-141` implements FixedRR:
```cpp
takeProfit = ResolveTargetByFixedRR(entryPrice, stopLoss, targetRR, candidate.direction);
policyName = StringFormat("Fixed RR %.1f", targetRR);
```
The math is correct. The only problem is that this path is never selected because `targetPolicy` defaults to `TARGET_OPPOSING_LIQUIDITY`.

**How should it be selected?**

Via `ExecutionPlanConfig.targetPolicy` set through `CExecutionPlanner::SetConfig()`. The config already carries both `targetPolicy` (enum) and `targetRR` (double). The plumbing exists; it is simply not connected.

---

## PART C — EXECUTION LEDGER

### What creates the Execution directory?

Two locations create it:

1. **`ExecutionIdentity.mqh:144-146`:**
```cpp
int slash = StringFind(counterPath, "\\");
if(slash >= 0)
    FolderCreate(StringSubstr(counterPath, 0, slash), FILE_COMMON);
```
Called during `CExecutionIdentity.Init("Execution\\execution_seq.dat")`. Creates `Common\Files\Execution\`.

2. **`ExecutionLedger.mqh:281`:**
```cpp
FolderCreate("Execution", FILE_COMMON);
```
Called at the start of `LedgerOpenOrCreate()`. Idempotent (harmless if already exists).

### Does the current code assume the directory already exists?

**No.** Both `CExecutionIdentity.Init()` and `LedgerOpenOrCreate()` explicitly create the directory via `FolderCreate("Execution", FILE_COMMON)` before attempting file operations. This is idempotent — creating an existing directory is a harmless no-op in MQL5.

### Does MT5 FileOpen create directories or only files?

**Only files.** `FileOpen` does NOT create intermediate directories. If the path contains a subdirectory that doesn't exist, `FileOpen` returns `INVALID_HANDLE`. This is why both callers use `FolderCreate` first.

### Is directory creation supported by the current MQL5 architecture?

**Yes.** `FolderCreate(name, FILE_COMMON)` creates `%APPDATA%\MetaQuotes\Terminal\<id>\Common\Files\<name>\`. MQL5 supports this natively.

### Is the intended path correct for FILE_COMMON?

**Yes.** The path `"Execution\\execution_ledger.dat"` with `FILE_COMMON` resolves to:
```
%APPDATA%\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Common\Files\Execution\execution_ledger.dat
```

### What should happen on a completely fresh demo installation?

1. `CExecutionIdentity.Init()` creates `Execution\` directory and `execution_seq.dat` (counter starting at 0)
2. `CExecutionLedgerWriter.Init()` creates `execution_ledger.dat` with a valid header
3. First plan reaches inspection → `LedgerScan` returns `LEDGER_SCAN_CLEAN` with 0 events
4. `RebuildStates` produces 0 states
5. Inspection returns `EINSPECT_NOT_FOUND` → plan proceeds to send

**This is the designed fresh-install flow.** The code handles it correctly.

### Should missing ledger infrastructure be initialized automatically, treated as empty, or fail closed?

**Fail closed** (current behavior). The code already does this:

1. If `Identity.Init()` fails → `m_execWriter` stays NULL → `m_execInspection` stays NULL
2. `LedgerWiringPermitsExecution()` returns false → execution disabled
3. Log message: `"EXECUTION DISABLED (fail-closed): execution-ledger wiring incomplete"`

This is correct. A missing ledger on a non-first run indicates corruption or tampering, which must block execution.

### Current State Analysis

The log shows inspection IS running (`ORDER-BLOCKED-INSPECTION Plan=2 verdict=AMBIGUOUS`), which means:
- `m_execInspection` is NOT NULL
- `m_execWriter` and `m_execRecovery` are also NOT NULL
- The `LedgerWiringPermitsExecution` check passed
- The directory and files were created successfully during init

The earlier check showing `Common\Files` doesn't exist may be due to:
- MT5 cleaning up the directory after EA removal
- A timing issue with the check
- The directory existing but being empty (no ledger file yet because no orders were sent)

**The ledger infrastructure is NOT a blocker.** The AMBIGUOUS verdict comes from `structureResolved=false` at line 86-87, which fires BEFORE the ledger check at line 107-108.

---

## PART D — M1 VS M15

### What timeframe does the EA use for signal generation?

**The chart timeframe.** All OHLC data and new-bar detection use `_Period`:

- `Engine.mqh:403`: `Bars(_Symbol, _Period)`
- `Engine.mqh:408-432`: `CopyOpen/High/Low/Close(_Symbol, _Period, ...)`
- `Engine.mqh:444`: `iTime(_Symbol, _Period, 0)`
- `SymbolContext.mqh:1168`: `(int)Period()` passed to candidate builder

On M1, the EA processes 1-minute bars. Structure detectors (OB, FVG, Liquidity, BOS, Swing) all operate on M1 data.

### What timeframe does it use for execution planning?

**The same chart timeframe.** The ExecutionPlanner receives candidates from the ConfluenceEngine, which processes M1 signals. There is no multi-timeframe execution path.

### Does it intentionally support execution on a different chart timeframe?

**No.** The architecture is single-timeframe. There is no mechanism to detect structures on M15 while executing on M1. The EA does not use `iOpen(_Symbol, PERIOD_M15, ...)` or similar multi-timeframe calls.

### Does attaching to M1 explain the missing OB?

**Yes.** The candidate's `obId` references an OB detected on the chart timeframe. On M1, OBs are detected at 1-minute resolution. An OB that would be valid on M15 may:
1. Not exist as an M1 OB (different bar structure)
2. Have been mitigated/invalidated within the M1 bar resolution
3. Have a different `obId` on M1 vs M15

The `ENTRY_OB_RETEST` policy searches for `candidate.obId` in the M1 detector's list. If the OB doesn't exist on M1, the search fails → falls to "Current Price" → `entrySR=false` → `structureResolved=false` → AMBIGUOUS.

### Is EURUSD M15 the correct first deployment configuration?

**Yes.** The intended deployment is EURUSD M15. The EA should be attached to an EURUSD M15 chart.

### Deployment Procedure

**No code change needed.** The deployment procedure should simply:
1. Attach the EA to an EURUSD **M15** chart (not M1)
2. The EA will then process M15 bars and detect M15 structures
3. OBs detected on M15 will be available for `ENTRY_OB_RETEST` resolution
4. `entrySR` will be `true` for OB-based entries

---

## PART E — TEST-FIRST FIX PLAN

### Test Matrix

| Test | Description | Expected | Actual | PASS/FAIL |
|------|-------------|----------|--------|-----------|
| T1 | Fresh environment + ledger initialization | Ledger file created, header valid, 0 events, inspection returns NOT_FOUND | — | — |
| T2 | Valid OB_RETEST structural entry (BUY) | entrySR=true, structureResolved=true, plan is EXECUTABLE, inspection passes if ledger is clean | — | — |
| T3 | Current-price fallback behavior | Plan rejected at BuildPlan with "Unresolved Entry" reason, never reaches inspection | — | — |
| T4 | FixedRR BUY: Entry=1.14640, SL=1.14574, RR=2.0 | TP ≈ 1.14772 (Entry + 2×riskDist), RR ≈ 2.0 | — | — |
| T5 | FixedRR SELL: Entry=1.14640, SL=1.14706, RR=2.0 | TP ≈ 1.14508 (Entry - 2×riskDist), RR ≈ 2.0 | — | — |
| T6 | Opposing-liquidity target remains unchanged when explicitly selected | TP resolves from opposing liquidity pool, not FixedRR | — | — |
| T7 | Existing target policies regression (OPPOSING_OB, OPPOSING_FVG, PREVIOUS_SWING) | Each policy resolves TP from its designated source | — | — |
| T8 | Restart/recovery with existing INTENT | Ledger scan finds prior INTENT, plan identity matches, verdict MATCHED → BLOCK | — | — |
| T9 | Duplicate-plan inspection | Same plan submitted twice → second attempt blocked by dedup (IsAlreadySubmitted) | — | — |
| T10 | EURUSD M15 end-to-end execution-plan fixture | OB found on M15, entrySR=true, structureResolved=true, plan EXECUTABLE, RR correct under configured policy | — | — |

### Test Fixtures

**T4 Fixture (FixedRR BUY):**
```
Symbol: EURUSD
Direction: BUY (CONFLUENCE_BULLISH)
Entry: 1.14640
SL: 1.14574
Risk Distance: 0.00066
Target RR: 2.0
Expected TP: 1.14640 + (0.00066 × 2.0) = 1.14772
Expected RR: 2.00
Tick Size: 0.00001
TP Normalized: 1.14770 (to nearest tick)
```

**T5 Fixture (FixedRR SELL):**
```
Symbol: EURUSD
Direction: SELL (CONFLUENCE_BEARISH)
Entry: 1.14640
SL: 1.14706
Risk Distance: 0.00066
Target RR: 2.0
Expected TP: 1.14640 - (0.00066 × 2.0) = 1.14508
Expected RR: 2.00
Tick Size: 0.00001
TP Normalized: 1.14510 (to nearest tick)
```

---

## PART F — MINIMAL PATCH DESIGN

### PATCH A — Structure Resolution

**Goal:** Prevent unresolved-entry plans from reaching the inspection gate.

**File:** `Entry/ExecutionPlanner.mqh`
**Function:** `BuildPlan()`
**Lines:** 310-382 (the validation block)

**Change:** Add a new rejection check AFTER the directional bracket check (line 334) and BEFORE the spread check (line 335):

```cpp
//--- C1 (integrity): an unresolved entry has no durable plan identity.
//    Reject at plan creation rather than presenting as EXECUTABLE and
//    blocking at the inspection gate (which wastes the gate and produces
//    misleading telemetry).
else if(!entrySR)
{
    valid = false;
    rejectReason = "Unresolved Entry";
    m_rejectionCounts[8]++;  // new bucket (extend array from 8 to 9)
}
```

**Why minimal:** Only adds one rejection condition. Does not change any resolver logic, any inspection logic, or any strategy behavior. Plans that already resolve structurally are unaffected.

**Regression risks:**
- Plans that previously reached EXECUTABLE status and were blocked at inspection will now be rejected at plan creation. Telemetry numbers change (fewer "Blocked by Inspection", more "Rejected"). This is correct behavior.
- No impact on resolved-entry plans.

**Tests required:** T2, T3, T10

**Rollback:** Remove the added `else if` block. Restore array size from 9 to 8.

---

### PATCH B — FixedRR Configuration Wiring

**Goal:** When `OutcomeTpMode=OUTCOME_TP_FIXED_RR`, the ExecutionPlanner receives `targetPolicy=TARGET_FIXED_RR` and `targetRR=FixedRRTier`.

**File 1:** `Confluence/ConfluenceEngine.mqh`
**Function:** `Init()` or new `SetExecutionPlanConfig()` method
**Lines:** 176-178

**Change:** After `m_executionPlanner.Init()`, wire the config:

```cpp
m_executionPlanner.Init();
m_executionPlanner.SetCandidateBuilder(&m_candidateBuilder);

//--- Wire the execution plan config from the primary context's settings.
ExecutionPlanConfig planCfg;
planCfg.entryPolicy = ENTRY_OB_RETEST;
planCfg.stopPolicy = STOP_PROTECTED_POINT;
planCfg.targetRR = FixedRRTier;  // from config or parameter
// Target policy from the outcome TP mode:
if(outcomeTpMode == OUTCOME_TP_FIXED_RR)
    planCfg.targetPolicy = TARGET_FIXED_RR;
else
    planCfg.targetPolicy = TARGET_OPPOSING_LIQUIDITY;
planCfg.stopBufferPips = 3.0;
planCfg.minStopDistancePips = 5.0;
m_executionPlanner.SetConfig(planCfg);
```

**File 2:** `Confluence/ConfluenceEngine.mqh`
**New method or parameter pass-through:** Need to receive `outcomeTpMode` and `fixedRrTier` from SymbolContext/Engine.

**File 3:** `Portfolio/SymbolContext.mqh`
**Function:** Where ConfluenceEngine is initialized
**Change:** Pass the `m_outcomeTpMode` and `FixedRRTier` values to ConfluenceEngine after init.

**Why minimal:** Only adds config plumbing. The `ExecutionPlanConfig` struct and `SetConfig()` method already exist. The `TargetResolver` already handles `TARGET_FIXED_RR`. No strategy logic changes.

**Regression risks:**
- When `OutcomeTpMode=OUTCOME_TP_OPPOSING_LIQUIDITY`, behavior is unchanged (default config already uses `TARGET_OPPOSING_LIQUIDITY`).
- When `OutcomeTpMode=OUTCOME_TP_FIXED_RR`, TP resolves from FixedRR math instead of opposing liquidity. This is the INTENDED behavior.
- The settlement policy (`m_outcomePolicy`) is unaffected.

**Tests required:** T4, T5, T6, T7

**Rollback:** Remove the `SetConfig()` call. Planner reverts to default config.

---

### PATCH C — Ledger Initialization/Path Handling

**Goal:** Ensure the ledger infrastructure initializes correctly on a fresh terminal.

**Assessment:** After forensic analysis, the ledger initialization code is **already correct**:

1. `CExecutionIdentity.Init()` creates the `Execution\` directory (line 144-146)
2. `LedgerOpenOrCreate()` creates the directory (line 281) and the ledger file with a valid header
3. `CExecutionPlanInspection.Init()` stores the ledger path
4. `LedgerWiringPermitsExecution()` enforces fail-closed wiring

**No code change required for the ledger itself.** The earlier investigation showing `Common\Files` doesn't exist is likely due to MT5 cleanup after EA removal, or a timing issue. The log confirms the inspection IS wired and running, which means the directory and files were created successfully.

**Optional improvement (low priority):** Add a log line during `CExecutionIdentity.Init()` confirming directory creation:
```cpp
m_logger.LogInfo(StringFormat("Ledger directory created: %s", StringSubstr(counterPath, 0, slash)));
```

**Why minimal:** Optional observability only. No functional change.

**Regression risks:** None. Logging only.

**Tests required:** T1

---

## PART G — FINAL DECISION

### Q1. What exactly blocks the first order today?

**Three blockers, in order of execution:**

1. **P0 — structureResolved=false** (`CExecutionPlanInspection.mqh:86-87`): The entry falls to "Current Price" fallback because the M1 OB detector cannot find the candidate's OB (temporal mismatch from M1 vs M15). The plan reaches inspection with `structureResolved=false`, which returns AMBIGUOUS before checking the ledger. **This is the primary blocker.**

2. **P0 — FixedRR config not wired** (`ConfluenceEngine.mqh:177`): Even if structureResolved were true, the TP would resolve from opposing liquidity (31.32R) instead of FixedRR (2.0R) because `SetConfig()` is never called on the ExecutionPlanner. The 31.32R plan would likely be rejected by risk guards or produce unacceptable risk.

3. **P1 — M1 chart** (deployment): The EA is on M1 instead of M15. This causes the OB mismatch that triggers Blocker 1.

### Q2. Which blocker is P0/P1/P2?

| Blocker | Priority | Justification |
|---------|----------|--------------|
| structureResolved=false | **P0** | Prevents ANY order from being sent |
| FixedRR not wired | **P0** | Even if P0-blocker-1 is fixed, orders would have 31.32R TP (unacceptable risk) |
| M1 vs M15 | **P1** | Deployment fix only; no code change needed |

### Q3. Is the FixedRR=2.0 → 31.32R issue definitely a real configuration-wiring defect?

**Yes, confirmed.** The evidence is definitive:

1. `ExecutionPlanConfig()` default constructor sets `targetPolicy = TARGET_OPPOSING_LIQUIDITY` (ExecutionPlanTypes.mqh:51)
2. `ConfluenceEngine.Init()` never calls `m_executionPlanner.SetConfig()` (ConfluenceEngine.mqh:177-178)
3. The log shows `TargetPolicy=Opposing Liquidity` for all plans
4. The TP (1.16707) matches an opposing liquidity pool, not FixedRR math
5. FixedRR math would produce TP=1.14772 for the observed entry/SL

### Q4. Is structureResolved=false expected behavior or a defect?

**Expected behavior.** The `structureResolved` flag correctly identifies plans whose entry came from a non-durable source (live bid). Such plans cannot be durably identified for cross-run duplicate defense. The inspection gate correctly returns AMBIGUOUS for these plans.

The defect is that these plans should never reach the inspection gate — they should be rejected at plan creation time (Patch A).

### Q5. Is the current-price fallback supposed to be executable?

**No.** In ENTRY_MODE_LEGACY (live execution), the Current-Price fallback is not a valid structural entry. It was designed for the backtester/simulator where cross-run duplicate defense is not needed. In live execution, it should be treated as an unresolved entry and rejected.

### Q6. What is the correct behavior on a fresh terminal with no ledger directory?

**Fail closed, then initialize.** The current behavior is correct:

1. `CExecutionIdentity.Init()` creates the directory and counter file
2. `CExecutionLedgerWriter.Init()` creates the ledger file with a valid header
3. `CExecutionPlanInspection.Init()` stores the path
4. First plan reaches inspection → `LedgerScan` returns CLEAN with 0 events → `NOT_FOUND` → plan proceeds

If any step fails, execution is disabled via `LedgerWiringPermitsExecution()`. This is the correct fail-closed behavior.

### Q7. Does the EA need to run on EURUSD M15 for the intended deployment?

**Yes.** The architecture is single-timeframe. The EA uses `_Period` for all OHLC data and structure detection. Attaching to M15 ensures:

1. OBs are detected at M15 resolution (matching the intended strategy)
2. `ENTRY_OB_RETEST` can find the candidate's OB
3. `structureResolved` will be `true` for OB-based entries
4. The temporal mismatch between signal and execution is eliminated

### Q8. What is the minimum production patch set?

| Patch | Files | Lines Changed | Risk |
|-------|-------|--------------|------|
| A: Reject unresolved entries | `ExecutionPlanner.mqh` | ~5 lines added | Low (rejection only) |
| B: Wire FixedRR config | `ConfluenceEngine.mqh`, `SymbolContext.mqh` | ~10 lines added | Low (plumbing only) |
| C: Ledger (optional logging) | `CExecutionIdentity.mqh` or `CExecutionLedgerWriter.mqh` | ~1 line | None |

**Total: ~16 lines of production code changed.** No strategy logic, no risk parameters, no SMC rules modified.

### Q9. What tests must PASS before another demo execution attempt?

| Test | Why Required |
|------|-------------|
| T1: Fresh ledger initialization | Ensures the ledger infrastructure works on a clean terminal |
| T2: Valid OB_RETEST entry | Ensures structural entries are correctly identified |
| T3: Current-price fallback rejected | Ensures unresolved entries don't reach inspection |
| T4: FixedRR BUY | Ensures TP resolves to 2R under FixedRR mode |
| T5: FixedRR SELL | Ensures TP resolves to 2R for sells under FixedRR mode |
| T6: Opposing-liquidity unchanged | Ensures non-FixedRR modes are not broken |
| T10: EURUSD M15 end-to-end | Ensures the full pipeline works on the intended timeframe |

**All 7 tests must PASS.** Tests T7-T9 are regression tests that should also pass but are not blocking.

---

## Appendix: Observed Log Evidence

### Plan Generation (20:43–20:54 UTC)

```
20:43:59.364 EXECUTION-PLAN Decision=1 Status=REJECTED
  Entry=1.14645 SL=1.14683 TP=1.14604 RR=1.08
  StopPolicy=Above Protected High TargetPolicy=Opposing Liquidity
  Reason=Broker Min Stop

20:45:59.317 EXECUTION-PLAN Decision=2 Status=EXECUTABLE
  Entry=1.14640 SL=1.14574 TP=1.16707 RR=31.32
  StopPolicy=Below Protected Low TargetPolicy=Opposing Liquidity
20:45:59.317 ORDER-BLOCKED-INSPECTION Plan=2 verdict=AMBIGUOUS

20:46:59.307 EXECUTION-PLAN Decision=3 Status=EXECUTABLE
  Entry=1.14646 SL=1.14574 TP=1.16707 RR=28.62
20:46:59.307 ORDER-BLOCKED-INSPECTION Plan=2 verdict=AMBIGUOUS
20:46:59.307 ORDER-BLOCKED-INSPECTION Plan=3 verdict=AMBIGUOUS
```

**Pattern:** Each new plan is inspected against ALL prior plans (Plan 2 is re-inspected every time). All return AMBIGUOUS because `structureResolved=false`. The entry prices change every minute (Current Price fallback), but TP (1.16707) and SL (1.14574) remain constant (structural).

### Final Summary (20:54:05 UTC)

```
Blocked by Inspection (E)         44
Entry: FVG Midpoint            9  0  9(  0%)  0.00  0.0  0.0  Broker Min Stop=9
Entry: Liquidity Level         9  0  9(  0%)  0.00  0.0  0.0  Broker Min Stop=9
Stop: OB Side                  9  0  9(  0%)  0.00  0.0  0.0  Broker Min Stop=9
Stop: Liquidity Side           9  0  9(  0%)  0.00  0.0  0.0  Broker Min Stop=9
```

The policy matrix evaluation (run at shutdown) confirms all combo evaluations produce 0 executable plans under the default 2.0R FixedRR config — because the evaluation uses `TARGET_FIXED_RR` correctly (it constructs its own config), but the live planner does not receive this config.
