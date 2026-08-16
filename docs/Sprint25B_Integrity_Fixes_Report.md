# Sprint 25B - C1..C7 Integrity Fix Report (Live ENTRY_MODE_LEGACY Execution Path)

**Status: INTEGRITY FIX COMPLETE**
Scope: seven critical integrity defects (C1-C7) plus H6/H7 hardening on the live
`ENTRY_MODE_LEGACY` execution path, plus their acceptance tests.
No strategy changes, no parameter tuning, no SMC/rule changes, no commits, no push.

Date: 2026-08-16

---

## 1) Files Modified

Production (14):

| File | Change |
|---|---|
| `SuperCents_X.mq5` | New inputs `InpMagicNumber` (27182819), `InpRiskPercent` (1.0), `InpMaxPositionsPerSymbol` (1); OnInit range-check + wiring BEFORE `g_engine.Init()` |
| `Core/Config.mqh` | `SetMagicNumber()`; removed `(int)TimeCurrent()` derivation from Init; risk%/cap members + getters/setters |
| `Core/Engine.mqh` | `SetMagicNumber`/`SetRiskPercent`/`SetMaxPositionsPerSymbol` pass-throughs; forward to primary symbol in Init |
| `Trading/TradeManager.mqh` | Position gate, sizing-at-fill, fill-price validation, retryable sends (see C2/C3/C6/C7/H6) |
| `Trading/TradeValidation.mqh` | `GetFillPrice()`, directional stop checks vs fill, margin vs fill price (C6/C7) |
| `Entry/ExecutionPlanner.mqh` | Directional bracket checks in `BuildPlan` + `EvaluateSingleCombo` (C6) |
| `Structure/SwingDetector.mqh` | Closed-bar maxCenter (C4) |
| `Structure/FVGDetector.mqh` | Closed-bar scan window + cursor (C4) |
| `Structure/LiquidityDetector.mqh` | Closed-bar mitigation scans (C4) |
| `Confluence/ConfluenceEngine.mqh` | NONE-direction guard + bounded signal pool (C5) |
| `Portfolio/CapitalAllocator.mqh` | Correct risk-per-lot formula (H7) |
| `Portfolio/SymbolContext.mqh` | Risk%/cap wiring into TradeManager |
| `Entry/PositionInfo.mqh` | Removed deprecated `POSITION_COMMISSION` read |
| `Entry/PositionManager.mqh` | Removed deprecated `POSITION_COMMISSION` reads (3 sites) |

Tests (4):

| File | Change |
|---|---|
| `Tests/unit/TestIntegrityFixes.mqh` | NEW - C1..C7 acceptance tests |
| `Tests/TestSuite.mqh` | Registered `RunIntegrityFixTests()` |
| `Tests/unit/TestTelemetry.mqh` | `configFingerprint` (ulong) compared via `TEST_TRUE` instead of `TEST_STR_EQ` (warning 94 fix) |
| `Tests/unit/TestExecutionIdentity.mqh` | `ulong s1 = 0;` / `ulong s = 0;` initializers (warning 60 fix) |

## 2) C1 - Stable Magic Number

**Defect:** `CConfig::Init()` derived `m_magicNumber = (int)TimeCurrent()` - the
magic changed on every restart, corrupting order identity across sessions.

**Fix:** `Config.mqh` now carries an explicit magic; `SuperCents_X.mq5` sets
`InpMagicNumber` (default 27182819, validated in `[1, INT_MAX]`) via
`g_engine.SetMagicNumber()` BEFORE `Init()`. `Init()` no longer overwrites it.

**Validation:** `TestC1StableMagic` - default magic is 0 (no derivation); explicit
magic survives `Init()` re-entry; `SetMagicNumber` before Init sticks.

## 3) C2 - Real Position Sizing

**Defect:** `TradeManager` always traded the fixed `m_lotSize` (0.01); the
risk-based `CPositionSizer` was never wired, so risk sizing was a no-op.

**Fix:** `SymbolContext` now creates the position sizer and forwards
`SetPositionSizer`/`SetRiskPercent`/`SetMaxPositionsPerSymbol` to the TradeManager.
`TradeManager::Update` sizes at the fill price:
`m_positionSizer.CalculateCached(m_riskPercent, stopDistancePoints, ACCOUNT_EQUITY)`
with `stopDistancePoints = |fillPrice - stopLoss| / point`, falling back to
`m_lotSize` only if sizing fails. `IsVolumeValid` guards the result.

**Validation:** `TestC2RiskMonotonicAndClamp` - lots increase with risk%
(0.5% < 1.0% < 2.0%, with >1.5x margins); wider stop at fill -> smaller lots;
volume min/max clamps hold; H7 formula sanity (1% @ 500 pts -> ~0.20 lots).

## 4) C3 - Position Gate

**Defect:** `TradeManager::Update` never checked how many positions were open -
the EA would stack unlimited entries on one symbol.

**Fix:** `CountOpenPositions()` (symbol + magic match) + `GetOpenPositionCount()`;
`Update` skips (with `m_totalBlocked` accounting) when
`CountOpenPositions() >= m_maxPositionsPerSymbol`. Cap clamped to >= 1.

**Validation:** `TestC3PositionGate` - fresh magic has 0 open positions; cap
clamped to >= 1; risk clamped to >= 0; values round-trip.

## 5) C4 - Closed-Bar Discipline (removes forming-candle lookahead)

| Detector | Old indexing | New indexing | Reason | Validation |
|---|---|---|---|---|
| `SwingDetector` | `maxCenter = rates_total - 3` (could use forming swing) | `maxCenter = rates_total - 4` | Swing needs closed bars only | existing suite green (2796/2796) |
| `FVGDetector` | `end_i = 2`, cursor `time[0]` - forming bar entered triple (2,1,0) and re-scanned on close | `end_i = 3`, `rates_total < 4` guard, `start_i = MathMin(newBars + 1, rates_total - 1)`, cursor `time[1]` | Newest triple (3,2,1) is fully closed; each new closed bar yields exactly one new triple; no re-scan | `TestC4FVGClosedBarOnly` - gap in forming triple (2,1,0) => 0 FVGs (old code: 1); gap in closed triple (3,2,1) => 1 FVG with `time == middle bar`; cursor advance re-scan => no duplicate |
| `LiquidityDetector` | `DetectMitigations` used `high[0]/low[0]/time[0]` (forming bar) | `high[1]/low[1]/time[1]` + `rates_total < 2` guard | Mitigation detection is closed-bar only (sweeps were already closed-bar) | existing suite green (2796/2796) |

## 6) C5 - Signal Lifecycle (no NONE signals, bounded pool)

**Defect:** `ConfluenceEngine::Update` created a `CONFLUENCE_NONE` signal on EVERY
bar with no confluence - unbounded pool growth and meaningless signal churn.

**Fix:** after rule evaluation and counters, `if(dir == CONFLUENCE_NONE) return;`
(no signal creation / no downstream candidate/decision/planner work on
direction-less bars). Pool bounded by `MAX_SIGNAL_POOL_SIZE 4096` +
`PruneExpiredSignals()` (in-place compaction) called from `CheckSignalLifecycles`;
`m_totalSignalsPruned` counted and reported in Shutdown.

**Validation:** `TestC5NoNoneSignals` - bare `CConfluenceEngine` (no detectors),
Init + 20x Update -> `GetSignalCount() == 0`, `GetLatestConfluence() == false`.

## 7) C6 - Directional SL/TP Validation

**Defect:** `AreStopsValid` checked only absolute stop-level distances - a BUY
with SL above / TP below the fill price (inverted bracket) passed validation and
the broker rejected the order.

**Fix:** `TradeValidation::AreStopsValid` now resolves the fill price
(`GetFillPrice`: ASK for BUY, BID for SELL), requires finite numbers, rejects
inverted brackets (BUY: SL >= fill or TP <= fill; SELL: SL <= fill or TP >= fill),
then checks stop-level distances vs fill. `ExecutionPlanner::BuildPlan` +
`EvaluateSingleCombo` reject inverted combos at plan time with the existing
"Invalid Prices" rejection label.

**Validation:** `TestC6DirectionalStops` - BUY SL-above / TP-below rejected;
valid BUY bracket accepted; SELL mirror; unsupported order type rejected.

## 8) C7 - Execution-Price Consistency

**Defect:** validation and sizing used the stale `plan.entryPrice` while the
order was submitted at live `SYMBOL_ASK`/`SYMBOL_BID`.

**Fix:** `GetFillPrice(ENUM_ORDER_TYPE)` (ASK for BUY, BID for SELL, 0 otherwise);
`AreStopsValid` and `IsMarginSufficient` use the fill price; `TradeManager`
validates, sizes and sends all against the same fill price.

**Validation:** `TestC7FillPrice` - BUY fill == ASK (>= BID); SELL fill == BID;
unknown type -> 0; plus sizing-at-fill checks in TestC2.

## 9) Compilation

```
SuperCents_X.mq5 : Result: 0 errors, 0 warnings, 10908 ms elapsed
TestRunnerEA.mq5 : Result: 0 errors, 0 warnings, 161258 ms elapsed
```

(Baseline before the fixes: 8 warnings in the runner - 4 deprecated
`POSITION_COMMISSION` reads + 4 pre-existing test-file warnings; the EA had the
same 4 commission warnings. All eliminated.)

## 10) Tests

```
SUITE Runner FINISH passed=2796 total=2796 failed=0
```

Full Validation Lab suite (36 suites incl. the new C1..C7 suite) - **2796/2796
passed, 0 failed**, executed in the MT5 strategy tester
(`Tests/Sprint14_TestRunner.ini`, EURUSD H1). The terminal's "some error after
pass finished" line is the normal result string for this OnInit-based runner
(it calls `ExpertRemove()` immediately); artifact writes - telemetry CSVs,
`ExecutionTest/t_a4.seq` - confirm suite execution on every run.

## 11) Remaining Issues

- `TradeManager` send failures stay retryable (H6): on `OrderSend` failure the
  plan is neither marked rejected nor recorded, so the next bar re-attempts it
  (status stays `PLAN_PENDING`). `m_totalFailed` tracks attempts and Shutdown
  reports them - no silent infinite retry loop.
- `ExecutionManager::Execute`, `RiskManager::Calculate`, `EntryEngine::Arm` and
  `EntryValidator` remain dead code (not wired) - not touched per scope.
- The `C2i` volume-ceiling check is conditional (only asserted when sizing is
  valid) to stay robust to broker-side lot rules.

## 12) Final Integrity Verdict

**INTEGRITY FIX COMPLETE**

- All seven critical defects (C1-C7) and the two hardening items (H6/H7) are
  fixed on the live `ENTRY_MODE_LEGACY` execution path.
- Production EA and test runner compile with **0 errors / 0 warnings**.
- Full validation suite: **2796/2796 passed, 0 failed**.
- No strategy behavior, SMC rules, or parameters were changed; no commits or
  pushes were made.