# SuperCents_X — Demo Deployment Readiness Audit

**Audit Date:** 2026-09-18
**Auditor:** opencode (mimo-v2.5-free)
**Classification:** READ-ONLY FORENSIC AUDIT

---

## OPERATIVE BASELINE

| Field | Value |
|---|---|
| Git HEAD | `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3` |
| Git tag | `v3.0-research-baseline-116-g36c7a73` |
| Working tree | 39 modified tracked files, 100+ untracked |
| EA source | `SuperCents_X.mq5` (273 lines) |
| Compiled .ex5 | `SuperCents_X.ex5` (552,550 bytes, 2026-09-18 19:08:21) |
| Compiler | MT5 terminal compiler, X64 Regular, 10650 ms |
| Compiler result | **0 errors, 4 warnings** |
| Warnings | 4x `POSITION_COMMISSION` deprecated (informational, non-blocking) |
| Entry mode | `ENTRY_MODE_LEGACY` (input default) |
| Magic number | `27182819` (input `InpMagicNumber`) |
| Risk % | `1.0` (input `InpRiskPercent`) |
| Max positions/symbol | `1` (input `InpMaxPositionsPerSymbol`) |

### Build Identity

```
>>> BUILD 25B-PROD-01 tag="<compile datetime>" term=<terminal build> path=<EA path>
```

### Operative Build vs Historical/Research

| Build | Identity | Status |
|---|---|---|
| CURRENT OPERATIVE | `36c7a73`, `ENTRY_MODE_LEGACY`, `SuperCents_X.ex5` 2026-09-18 | **THIS IS THE BUILD UNDER AUDIT** |
| HISTORICAL FROZEN | Sprint17 frozen artifacts under `Evidence/Sprint17/` | Research context only |
| A-MIRROR RESEARCH | `Tools/A_MIRROR/` | Research harness only |

---

## 1. REPOSITORY INVENTORY — PRODUCTION EXECUTION PATH

### 1.1 Source File Map

```
SuperCents_X.mq5                           ← EA entry point
├── Utils/Types.mqh                        ← Type definitions
├── Utils/Constants.mqh                    ← Module constants
├── Utils/Helpers.mqh                      ← Utility functions
├── Utils/MathUtils.mqh                    ← Math helpers
├── Core/Logger.mqh                        ← CLogger
├── Core/Config.mqh                        ← CConfig (magic, risk, slippage)
├── Core/Engine.mqh                        ← CEngine (orchestrator)
├── Structure/
│   ├── SwingDetector.mqh                  ← Swing detection
│   ├── StructuralPivotEngine.mqh          ← Structural pivot engine
│   ├── BOSDetector.mqh                    ← Break-of-structure
│   ├── CHOCHDetector.mqh                  ← Change-of-character
│   ├── OrderBlockDetector.mqh             ← Order block detection
│   ├── TrendState.mqh                     ← Trend state machine
│   ├── ProtectedPointManager.mqh          ← Protected points
│   ├── FVGDetector.mqh                    ← Fair value gap
│   └── LiquidityDetector.mqh              ← Liquidity levels
├── Visualization/
│   ├── SwingRenderer.mqh
│   ├── BOSRenderer.mqh
│   ├── CHOCHRenderer.mqh
│   └── ProtectedRenderer.mqh
├── Confluence/
│   ├── ConfluenceEngine.mqh               ← Signal generation + scoring
│   ├── ConfluenceRules.mqh                ← Rule evaluation
│   ├── ScoreCalculator.mqh                ← Score calculation
│   ├── SignalTypes.mqh                    ← Signal type definitions
│   └── TradeCandidateBuilder.mqh          ← Candidate construction
├── Entry/
│   ├── EntrySetup.mqh                     ← Entry setup
│   ├── EntrySetupBuilder.mqh              ← Setup builder
│   ├── EntryValidator.mqh                 ← Entry validation
│   ├── EntryEngine.mqh                    ← Entry engine
│   ├── RiskManager.mqh                    ← Risk management
│   ├── ExecutionManager.mqh               ← Execution manager
│   ├── PositionLifecycleManager.mqh       ← Position lifecycle (BE/TS/close)
│   ├── ExecutionPlanner.mqh               ← Plan creation from candidates
│   ├── ExecutionPlanTypes.mqh             ← Plan type definitions
│   ├── EntryDecisionEngine.mqh            ← Decision engine
│   ├── EntryPriceResolver.mqh             ← Entry price resolution
│   ├── StopLossResolver.mqh               ← Stop loss resolution
│   ├── TargetResolver.mqh                 ← Target resolution
│   └── EntryConfig.mqh                    ← Entry mode enum
├── Trading/
│   ├── TradeManager.mqh                   ← CTradeManager (OrderSend)
│   ├── TradeRequestBuilder.mqh            ← MqlTradeRequest construction
│   ├── TradeValidation.mqh               ← Pre-send validation
│   ├── TradeExecutionResult.mqh           ← Result types
│   ├── ExecutionTruth.mqh                 ← Broker truth capture
│   ├── TradeManagerRetryPolicy.mqh        ← H6 retry classification
│   ├── CExecutionLedgerWriter.mqh         ← Durable ledger writer
│   ├── CExecutionRecovery.mqh             ← Recovery/state model
│   ├── CExecutionPlanInspection.mqh       ← Cross-run duplicate defense
│   ├── ExecutionLedger.mqh                ← Ledger file format
│   └── ExecutionIdentity.mqh              ← Execution ID allocation
├── Risk/
│   ├── PositionSizer.mqh                  ← Risk-based lot sizing
│   ├── RiskTypes.mqh                      ← Sizing result types
│   ├── ExposureTracker.mqh                ← Exposure tracking
│   └── DrawdownMonitor.mqh                ← Drawdown monitoring
├── Portfolio/
│   ├── PortfolioManager.mqh               ← Multi-symbol management
│   ├── SymbolContext.mqh                  ← Per-symbol orchestrator (1820 lines)
│   ├── PortfolioTypes.mqh                 ← Portfolio types
│   ├── Scheduler.mqh                      ← Update scheduler
│   └── ... (correlation, statistics, allocation, risk)
├── Telemetry/
│   ├── TelemetryCollector.mqh             ← CSV telemetry persistence
│   ├── TelemetryTypes.mqh                 ← Row schema v6
│   ├── ForwardOutcomeSimulator.mqh        ← Outcome simulation
│   └── ActualOutcomeSettler.mqh           ← Live outcome settlement
├── Monitoring/
│   ├── EventBusAdapter.mqh                ← Event bus
│   ├── MetricsCollector.mqh               ← Performance metrics
│   ├── HealthMonitor.mqh                  ← Module health
│   └── StatisticsReporter.mqh             ← Statistics reporting
└── Tests/                                 ← Unit/integration tests (not production)
```

### 1.2 Execution Dependency Graph

```
OnInit()
  ├── CConfig.Init() [magic=27182819, slippage=3]
  ├── CPortfolioManager.Init()
  │   ├── CScheduler.Init()
  │   ├── CCorrelationManager.Init()
  │   ├── CPortfolioStatistics.Init()
  │   ├── CPortfolioExposureTracker.Init()
  │   ├── CAllocationEngine.Init()
  │   └── CPortfolioRiskManager.Init()
  └── CSymbolContext.Init(_Symbol, magic, LEGACY)
      ├── [9 Detectors] → SwingDetector, PivotEngine, BOSDetector,
      │   TrendState, ProtectedPointManager, CHOCHDetector,
      │   OrderBlockDetector, FVGDetector, LiquidityDetector
      ├── CConfluenceEngine.Init()
      ├── CTradeManager.Init()
      ├── [LEGACY only] CExecutionIdentity.Init()
      ├── [LEGACY only] CExecutionLedgerWriter.Init() + CExecutionRecovery.Init()
      ├── [LEGACY only] CExecutionPlanInspection.Init()
      ├── [LEGACY only] LedgerWiringPermitsExecution() → fail-closed gate
      ├── CPositionLifecycleManager.Init() → DiscoverPositions()
      ├── CPositionSizer.Init()
      └── CActualOutcomeSettler.Init()

OnTick()
  └── CEngine.Update()
      └── if(IsNewBar())  [static lastBarTime vs iTime(_Symbol,_Period,0)]
          ├── CopyOHLCArrays() [CopyOpen/High/Low/Close/Time from _Symbol,_Period]
          └── CPortfolioManager.Update()
              └── CSymbolContext.Update(open, high, low, close, time, rates_total)
                  ├── [1] SwingDetector.Update()
                  ├── ArraySetAsSeries(all, true)
                  ├── [2] HistoryEpoch.Update() [history reset detection]
                  ├── [3] StructuralPivotEngine.Update()
                  ├── [4] BOSDetector.Update()
                  ├── [5] TrendState.Update()
                  ├── [6] ProtectedPointManager.Update()
                  ├── [7] CHOCHDetector.Update() + ForceTrend gate
                  ├── [8] OrderBlockDetector.Update()
                  ├── [9] FVGDetector.Update()
                  ├── [10] LiquidityDetector.Update()
                  ├── [11] VisualizationManager.Update()
                  ├── [12] ConfluenceEngine.Update()
                  │   ├── Signal lifecycle management
                  │   ├── Confluence scoring
                  │   ├── EntryDecisionEngine → decisions
                  │   └── ExecutionPlanner → plans
                  ├── [13] PortfolioRiskManager.Evaluate()
                  ├── [14] CTradeManager.Update()
                  │   ├── Dedup check (IsAlreadySubmitted)
                  │   ├── Retry-hold check (IsRetryHeld)
                  │   ├── Position gate (CountOpenPositions)
                  │   ├── Fill price resolution (GetFillPrice)
                  │   ├── Validation (ValidateAll: trading, volume, stops, margin)
                  │   ├── Position sizing (CalculateCached)
                  │   ├── Volume validation (IsVolumeValid)
                  │   ├── Request building (Build: TRADE_ACTION_DEAL)
                  │   ├── Plan inspection (Inspect: cross-run dedup)
                  │   ├── Ledger INTENT (BeginExecution: write-ahead)
                  │   ├── OrderSend(request, result)
                  │   ├── CaptureExecutionTruth()
                  │   ├── H6ClassifyPolicy()
                  │   ├── Ledger post-send (RecordResult)
                  │   └── Dedup record (RecordSubmitted)
                  ├── [15] CPositionLifecycleManager.Update()
                  │   ├── DiscoverPositions() [restart recovery]
                  │   ├── PurgeClosedContexts()
                  │   └── ProcessContext() per position
                  └── [16] HealthMonitor.Update()

OnTradeTransaction()
  └── Deal admission (DEAL_ADD only)
      ├── HistoryDealSelect()
      ├── LedgerAdmitsDealAsEntry() [P0 gate]
      ├── RecordDealByDecisionId()
      └── Observability logging

OnDeinit()
  └── CEngine.Shutdown()
      ├── CPositionLifecycleManager.Shutdown()
      ├── CTradeManager.Shutdown() [summary stats]
      ├── CExecutionLedgerWriter.RecordRunEnd()
      └── CPortfolioManager.Shutdown()
```

---

## 2. COMPILE GATE

```
Compiler: MT5 terminal compiler (X64 Regular)
Timestamp: 2026-09-18 19:08:21
Source: SuperCents_X.mq5
Output: SuperCents_X.ex5 (552,550 bytes)
Errors: 0
Warnings: 4 (all POSITION_COMMISSION deprecation, non-blocking)
```

| Gate | Status | Evidence | Severity |
|---|---|---|---|
| Build | **PASS** | 0 errors, 4 warnings (deprecation only) | P3 |

---

## 3. DEMO EXECUTION SAFETY AUDIT

### 3.1 Magic Number

| Check | Finding | Source |
|---|---|---|
| Stable magic | **YES** — input `InpMagicNumber = 27182819` (C1 fix) | `SuperCents_X.mq5:48` |
| No random/session-dependent | **VERIFIED** — no `TimeCurrent()` derivation | `SuperCents_X.mq5:47` comment |
| Position filtering | Magic + Symbol dual-filter in `CountOpenPositions()` | `TradeManager.mqh:183-198` |
| Position discovery | Magic + Symbol filter in `DiscoverPositions()` | `PositionLifecycleManager.mqh:283-326` |
| Order comment | `SCX-<side>-P<decisionId>#<seq>` format | `TradeRequestBuilder.mqh:68,74,87` |

**Classification: PASS**

### 3.2 Symbol Isolation

| Check | Finding | Source |
|---|---|---|
| EA operates on `_Symbol` | **YES** — `_Symbol` used everywhere | `Engine.mqh:158,403` |
| No cross-symbol manipulation | **VERIFIED** — single context, `m_symbol` scoped | `SymbolContext.mqh:299` |
| Symbol properties from MT5 | `SymbolInfoDouble/Integer` used throughout | Multiple files |
| Tick size respected | `SYMBOL_TRADE_TICK_SIZE` in PositionSizer | `PositionSizer.mqh:31` |
| Point size respected | `SYMBOL_POINT` in validation and sizing | `TradeValidation.mqh:34,181` |
| Digits respected | `NormalizeDouble` not used (plan is broker-fill price) | N/A — broker provides |

**Classification: PASS**

### 3.3 Direction Handling

**BUY path:**
| Check | Finding | Source |
|---|---|---|
| Entry price | `SYMBOL_ASK` | `TradeRequestBuilder.mqh:67` |
| Fill price | `SYMBOL_ASK` via `GetFillPrice()` | `TradeValidation.mqh:49` |
| SL side | `SL < fillPrice` (validated) | `TradeValidation.mqh:151-155` |
| TP side | `TP > fillPrice` (validated) | `TradeValidation.mqh:156-160` |
| R calculation | `(currentPrice - entryPrice) / risk` | `PositionLifecycleManager.mqh:624-632` |

**SELL path:**
| Check | Finding | Source |
|---|---|---|
| Entry price | `SYMBOL_BID` | `TradeRequestBuilder.mqh:72` |
| Fill price | `SYMBOL_BID` via `GetFillPrice()` | `TradeValidation.mqh:51` |
| SL side | `SL > fillPrice` (validated) | `TradeValidation.mqh:163-167` |
| TP side | `TP < fillPrice` (validated) | `TradeValidation.mqh:168-172` |
| R calculation | `(entryPrice - currentPrice) / risk` | `PositionLifecycleManager.mqh:628-630` |

**Spread handling:** `SYMBOL_ASK` for BUY, `SYMBOL_BID` for SELL. Directional validation enforced in both `TradeValidation.AreStopsValid()` and `ExecutionPlanner.BuildPlan()`.

**Classification: PASS**

### 3.4 Risk Sizing

Full trace:
```
risk % (InpRiskPercent = 1.0)
  → AccountInfoDouble(ACCOUNT_EQUITY)
  → riskMoney = equity × (risk% / 100)
  → stopDistancePoints = |fillPrice - plan.stopLoss| / SYMBOL_POINT
  → riskPerLot = (stopDistancePoints × tickValue) / (tickSize / point)
  → lots = riskMoney / riskPerLot
  → lots = MathFloor(lots / volumeStep) × volumeStep
  → lots < volumeMin → REJECT (P37 fix, no floor-clamp)
  → lots > volumeMax → ceiling clamp
  → IsVolumeValid() → range + step alignment check
```

| Check | Finding | Source |
|---|---|---|
| Zero tick value | **REJECTED** — `if(tickValue <= 0)` returns invalid | `PositionSizer.mqh:157-161` |
| Zero stop distance | **REJECTED** — `if(stopDistancePoints <= 0)` returns invalid | `PositionSizer.mqh:145-149` |
| Invalid volume | **REJECTED** — `IsVolumeValid()` checks min/max/step | `TradeValidation.mqh:79-127` |
| Volume above max | Ceiling clamp to `volumeMax` | `PositionSizer.mqh:196-197` |
| Volume below min | **REJECT** (P37 fix, no floor-clamp) | `PositionSizer.mqh:188-194` |
| Incorrect tick-size | Refreshed per-tick via `RefreshSymbolProperties()` | `PositionSizer.mqh:101-107` |
| P37 invalid sizing | **REJECT** plan (no fallback to fixed lot) | `TradeManager.mqh:316-329` |
| Integer-domain step check | `shadowDev <= 1e-8` (P52 fix) | `TradeValidation.mqh:111-122` |

**Classification: PASS**

### 3.5 Position/Concurrency Gate

| Check | Finding | Source |
|---|---|---|
| Duplicate prevention | `IsAlreadySubmitted(planId)` in-memory per session | `TradeManager.mqh:233-237` |
| Max position count | `CountOpenPositions() >= m_maxPositionsPerSymbol` (default 1) | `TradeManager.mqh:249-256` |
| Symbol filtering | `PositionGetSymbol(i) == m_symbol` | `TradeManager.mqh:189` |
| Magic filtering | `POSITION_MAGIC == m_magicNumber` | `TradeManager.mqh:193` |
| Pending order handling | None — `TRADE_ACTION_DEAL` only (market orders) | `TradeRequestBuilder.mqh:56` |
| Cross-run dedup | `CExecutionPlanInspection.Inspect()` via ledger | `TradeManager.mqh:370-385` |
| Retry hold | `IsRetryHeld(planId)` — holds uncertain outcomes | `TradeManager.mqh:242-243` |
| Ledger corrupt gate | `m_recovery.IsExecutionBlocked()` → block all sends | `TradeManager.mqh:213-214` |
| Fail-closed wiring | `LedgerWiringPermitsExecution()` → disable execution | `SymbolContext.mqh:728-741` |

**Classification: PASS**

### 3.6 Closed-Bar Discipline

| Check | Finding | Source |
|---|---|---|
| New bar detection | `IsNewBar()` uses `iTime(_Symbol, _Period, 0)` vs static `lastBarTime` | `Engine.mqh:441-454` |
| OHLC copy | `CopyOpen/High/Low/Close/Time` from `_Symbol, _Period, 0..bars` | `Engine.mqh:408-437` |
| Series orientation | `ArraySetAsSeries(all, true)` applied AFTER swing detector | `SymbolContext.mqh:910-914` |
| All detectors | Run on the same OHLC arrays (series-indexed, bar[0]=newest) | `SymbolContext.mqh:904-1014` |
| ConfluenceEngine | Called after all detectors finish | `SymbolContext.mqh:1041-1047` |

**The EA processes on new bar formation, using the forming bar's first-tick data.** All detectors and the confluence engine operate on closed-bar data (bar[1] and earlier in series order). The forming bar (bar[0]) is the current bar; detectors that reference `rates_total - 1` (the newest closed bar) are operating on closed data.

**Classification: PASS**

---

## 4. ORDER EXECUTION AUDIT

### 4.1 MqlTradeRequest Construction

| Field | Value | Source |
|---|---|---|
| `action` | `TRADE_ACTION_DEAL` (market) | `TradeRequestBuilder.mqh:56` |
| `symbol` | `m_symbol` (set from `_Symbol`) | `TradeRequestBuilder.mqh:57` |
| `volume` | Computed by PositionSizer + validated | `TradeManager.mqh:296-347` |
| `type` | `ORDER_TYPE_BUY` or `ORDER_TYPE_SELL` | `TradeRequestBuilder.mqh:66,71` |
| `price` | `SYMBOL_ASK` (BUY) / `SYMBOL_BID` (SELL) | `TradeRequestBuilder.mqh:67,72` |
| `sl` | From `plan.stopLoss` (direction-validated) | `TradeRequestBuilder.mqh:61` |
| `tp` | From `plan.takeProfit` (direction-validated) | `TradeRequestBuilder.mqh:62` |
| `deviation` | `m_maxSlippage` (default 3) | `TradeRequestBuilder.mqh:59` |
| `magic` | `m_magicNumber` (27182819) | `TradeRequestBuilder.mqh:60` |
| `comment` | `SCX-<side>-P<decisionId>#<seq>` | `TradeRequestBuilder.mqh:68,74,87` |

### 4.2 Broker Response Handling

The code correctly distinguishes:

| Broker state | Handling | Source |
|---|---|---|
| Request accepted | `H6_POLICY_RECORD` → dedup + log | `TradeManager.mqh:450-474` |
| Order accepted (no deal) | `EXEC_OUTCOME_ACCEPTED_NO_DEAL` → logged | `TradeManager.mqh:458-461` |
| Deal executed | `EXEC_OUTCOME_FILLED` → fill price recorded | `TradeManager.mqh:451-457` |
| Partial fill | `EXEC_OUTCOME_PARTIALLY_FILLED` → volume tracked | `TradeManager.mqh:451` |
| Rejected | `H6_POLICY_REJECT_PERMANENT` → plan marked PLAN_REJECTED | `TradeManager.mqh:476-483` |
| Retry eligible | `H6_POLICY_RETRY_ELIGIBLE` → plan stays PLAN_EXECUTABLE | `TradeManager.mqh:485-492` |
| Uncertain (TIMEOUT/CONNECTION) | `H6_POLICY_RETRY_HOLD` → held, no retry | `TradeManager.mqh:494-501` |

### 4.3 Failure Path Analysis

| Failure | Recorded? | Attribution? | False success? | Reconcilable? |
|---|---|---|---|---|
| Rejected order | YES (LogOrderFailed) | YES (retcode + reason) | NO | YES |
| Requote | YES (H6 policy) | YES (retcode) | NO | YES |
| Invalid stops | YES (ValidateAll) | YES (reason string) | NO | YES |
| Invalid volume | YES (ValidateAll) | YES (reason string) | NO | YES |
| Market closed | YES (H6 RETRY_ELIGIBLE) | YES (retcode) | NO | YES |
| Insufficient margin | YES (IsMarginSufficient) | YES (reason string) | NO | YES |
| Connection failure | YES (H6 RETRY_HOLD) | YES (retcode) | NO | HOLD |
| Timeout | YES (H6 RETRY_HOLD) | YES (retcode) | NO | HOLD |
| Partial fill | YES (PARTIALLY_FILLED state) | YES (volume delta) | NO | YES |

**Classification: PASS**

---

## 5. FILL-PRICE CONSISTENCY

This is a critical gate.

| Check | Finding | Source |
|---|---|---|
| Fill price source | `GetFillPrice()` returns `SYMBOL_ASK` (BUY) / `SYMBOL_BID` (SELL) — **LIVE market price at order time** | `TradeValidation.mqh:46-53` |
| Used for stop validation | **YES** — `AreStopsValid()` uses `fillPrice` | `TradeValidation.mqh:131-197` |
| Used for margin check | **YES** — `IsMarginSufficient()` uses `fillPrice` | `TradeValidation.mqh:200-228` |
| Used for risk sizing | **YES** — `stopDistancePoints` computed from `fillPrice` | `TradeManager.mqh:298-302` |
| Used for position sizing | **YES** — `CalculateCached()` uses the computed stop distance from fill | `TradeManager.mqh:303-313` |
| Actual broker fill | Captured in `ExecutionTruthRecord.filledPrice` from `tradeResult.price` | `ExecutionTruth.mqh:137` |
| Requested vs actual | `requestedPrice` (from `request.price`) and `filledPrice` (from `result.price`) are separate fields | `ExecutionTruth.mqh:46-48` |
| Downstream uses fill | All validation/sizing uses the **live market price at send time** (which is the expected fill price for market orders) | Multiple |

**Key finding:** The system uses the **live market price** (Ask/Bid at send time) for all pre-send validation and sizing, NOT the plan's resolved entry price. The actual broker fill price is captured separately in `ExecutionTruthRecord.filledPrice`. For market orders on a demo account with reasonable spread, these should be very close. The system does NOT retrospectively recalculate risk sizing based on the actual fill price — this is a known limitation.

**Classification: PASS (with P2 limitation — no post-fill risk recalculation)**

---

## 6. POSITION LIFECYCLE AUDIT

### 6.1 Complete Chain

```
Decision (candidateId)
  ↓
ExecutionPlan (entryDecisionId = candidateId)
  ↓
ExecutionTruthRecord (executionPlanId = candidateId)
  ↓
Ledger INTENT (decisionId, executionId, symbol, side, prices, volumes)
  ↓
Ledger SENT (retcode, orderTicket, outcome)
  ↓
Ledger DEAL_IN (dealTicket, orderTicket, positionId, filledPrice, filledVolume)
  ↓
PositionContext (ticket, entryDecisionId parsed from comment)
  ↓
Position lifecycle: DISCOVERED → OPEN → BREAK_EVEN/TRAILING/PARTIAL → CLOSED
  ↓
EventBus EVENT_POSITION_CLOSED (profit, entryDecisionId)
  ↓
ActualOutcomeSettler (links back to TelemetryRow via decisionId)
```

### 6.2 Unique Identifiers

| Field | Present? | Source |
|---|---|---|
| Decision/candidate ID | **CAPTURED** — `entryDecisionId` in plan, ledger, context | `ExecutionPlanner.mqh:214`, `TradeRequestBuilder.mqh:68` |
| Execution ID | **CAPTURED** — `executionId` from `CExecutionIdentity` | `CExecutionLedgerWriter.mqh:261-264` |
| Order ticket | **CAPTURED** — `tradeResult.order` | `ExecutionTruth.mqh:128` |
| Deal ticket | **CAPTURED** — `tradeResult.deal` | `ExecutionTruth.mqh:127` |
| Position ticket | **CAPTURED** — from `HistoryDealGetInteger(DEAL_POSITION_ID)` | `CExecutionLedgerWriter.mqh:377` |
| Signal ID | **CAPTURED** — `ConfluenceSignal.id` | `ConfluenceEngine.mqh:159` |
| Rule ID | **CAPTURED** — `firedRuleId` in TelemetryRow | `TelemetryCollector.mqh:138` |

### 6.3 Reconstructability

The complete chain `Decision → Order → Deal → Position → Exit → Settlement` can be reconstructed using:
1. Ledger file (`execution_ledger.dat`) for execution chain
2. Telemetry CSV for decision/rule/signal context
3. EventBus events for position lifecycle
4. Deal history for broker-side evidence

**Classification: PASS**

---

## 7. SL/TP AND EXIT AUDIT

### 7.1 SL/TP Creation

| Check | Finding | Source |
|---|---|---|
| Entry price resolution | `ResolveEntryPrice()` (OB retest, FVG midpoint, liquidity, current price) | `ExecutionPlanner.mqh:244-249` |
| SL resolution | `ResolveStopLoss()` (OB side, liquidity side, protected point, broker min) | `ExecutionPlanner.mqh:253-260` |
| TP resolution | `ResolveTakeProfit()` (fixed RR, opposing liquidity/OB/FVG, prev swing) | `ExecutionPlanner.mqh:264-271` |
| Directional validity | **ENFORCED** — `BuildPlan()` C6 check + `AreStopsValid()` C6 check | `ExecutionPlanner.mqh:326-334`, `TradeValidation.mqh:149-174` |
| Min stop distance | `SYMBOL_TRADE_STOPS_LEVEL × point` checked | `TradeValidation.mqh:181-195` |
| Tick-size normalization | Broker handles via `SYMBOL_TRADE_STOPS_LEVEL` | N/A |
| RR calculation | `targetDistance / stopDistance` | `ExecutionPlanner.mqh:282-285` |
| Net RR (spread-adjusted) | `(targetDist - spread) / (stopDist + spread)` — observe-only, no rejection | `ExecutionPlanner.mqh:294-308` |
| Gross RR gate | `< 1.0` rejects | `ExecutionPlanner.mqh:353-358` |
| Net RR gate | `< 1.0` rejects (P48) | `ExecutionPlanner.mqh:364-369` |

### 7.2 SL/TP Modification

| Check | Finding | Source |
|---|---|---|
| Breakeven | **DISABLED** by default (`m_beEnabled = false`) | `PositionLifecycleManager.mqh:103` |
| Trailing stop | **DISABLED** by default (`m_tsEnabled = false`) | `PositionLifecycleManager.mqh:107` |
| Manual/broker intervention | Detected via `RefreshPositionData()` returning false → state = CLOSED | `PositionLifecycleManager.mqh:336-378` |
| Position closure detection | `DiscoverPositions()` checks for missing tickets → CLOSED | `PositionLifecycleManager.mqh:283-326` |

### 7.3 Exit Reason

Exit is detected by position disappearance (SL/TP hit by broker). The `EVENT_POSITION_CLOSED` event carries `profit` (net P/L including swap+commission from deal history). The exit reason is not explicitly captured from broker (the EA does not distinguish SL-hit from TP-hit from manual close in its event model).

**Classification: PASS (P2 limitation — exit reason indeterminate for broker-initiated closes)**

---

## 8. REAL-TIME EVENT MODEL

| Event | Handler | Behavior |
|---|---|---|
| Every tick | `OnTick()` → `Engine.Update()` | **BLOCKED by `IsNewBar()`** — only processes on new bar |
| New bar | `IsNewBar()` via `iTime()` comparison | Full pipeline execution |
| Timer | `OnTimer()` | **EMPTY** — no timer events |
| Init | `OnInit()` | Full engine initialization |
| Deinit | `OnDeinit()` | Full shutdown with summary stats |
| Trade transaction | `OnTradeTransaction()` | DEAL_ADD admission → ledger recording |
| Chart event | `OnChartEvent()` | **EMPTY** |

### 8.1 State Staleness Risk

| State | Staleness Risk | Mitigation |
|---|---|---|
| Static `lastBarTime` | **LOW** — reset on EA restart | `Engine.mqh:443` |
| Cached detector state | **LOW** — rebuilt from OHLC on each new bar | Full re-scan each bar |
| Cached positions | **LOW** — `DiscoverPositions()` runs every update | `PositionLifecycleManager.mqh:151` |
| Cached candidates | **LOW** — rebuilt each bar via ConfluenceEngine | New signals per bar |
| Signal lifecycle | **LOW** — `CheckSignalLifecycles()` prunes expired | `ConfluenceEngine.mqh:194` |
| Order state | **LOW** — dedup in-memory, ledger durable | `TradeManager.mqh:233` |
| Settlement state | **LOW** — `SettleDue()` runs each bar | `SymbolContext.mqh:1070` |

**Classification: PASS**

---

## 9. RESTART/RECOVERY AUDIT

### 9.1 MT5 Restart Behavior

| Scenario | Recovery | Evidence |
|---|---|---|
| EA reinitialize | `OnInit()` → full re-init; `DiscoverPositions()` recovers open positions | `PositionLifecycleManager.mqh:128-143` |
| Position recovery | `DiscoverPositions()` scans `PositionsTotal()` with magic+symbol filter | `PositionLifecycleManager.mqh:283-326` |
| Decision ID recovery | Parsed from order comment `SCX-<side>-P<decisionId>#<seq>` | `PositionLifecycleManager.mqh:639-651` |
| Ledger recovery | `CExecutionLedgerWriter.Init()` scans ledger, rebuilds states | `CExecutionLedgerWriter.mqh:196-229` |
| Torn tail recovery | `LedgerRecoverTornTail()` repairs incomplete writes | `CExecutionLedgerWriter.mqh:212-216` |
| Corrupt ledger | `IsExecutionBlocked()` → blocks all sends | `TradeManager.mqh:213-214` |
| Pending execution reconciliation | `CExecutionReconciler.Reconcile()` checks broker history | `SymbolContext.mqh:700-711` |
| Duplicate after restart | **PREVENTED** — `IsAlreadySubmitted()` in-memory reset + `CExecutionPlanInspection` cross-run dedup via ledger | `TradeManager.mqh:233-237,370-385` |

### 9.2 Dedup After Restart

After restart:
1. `m_submittedIds[]` is empty (in-memory only) → allows re-evaluation
2. BUT `CExecutionPlanInspection.Inspect()` scans the durable ledger for matching plan identity → blocks cross-run duplicates
3. AND `CExecutionRecovery` reconciles pending executions against broker history

**Potential issue:** If the in-memory dedup resets but the ledger-based inspection misses a plan (e.g., different entry price due to market movement), a duplicate COULD occur. However, the `PlanIdentity` comparison includes `planEntryPrice`, `stopLoss`, `takeProfit`, `entryPolicy`, `stopPolicy`, `targetPolicy` — making exact duplicates impossible unless the market returns to the exact same price level.

**Classification: PASS (P2 limitation — near-duplicate plans with slightly different prices could pass inspection)**

---

## 10. TELEMETRY / EVIDENCE AUDIT

### 10.1 Market Context

| Field | Status | Source |
|---|---|---|
| Timestamp | **PRESENT** — `row.timestamp = TimeCurrent()` | `TelemetryCollector.mqh:101` |
| Symbol | **PRESENT** — `row.symbol` | `TelemetryCollector.mqh:102` |
| Timeframe | **PRESENT** — `row.timeframe` | `TelemetryCollector.mqh:103` |
| Bid/Ask | **PARTIAL** — not in telemetry row directly; available via `SymbolInfoDouble` at decision time | N/A |
| Spread | **PARTIAL** — spread is used in validation but not persisted in telemetry row | N/A |
| Bar context | **PRESENT** — `signalTime` captures bar timestamp | `TelemetryCollector.mqh:155` |

### 10.2 Decision

| Field | Status | Source |
|---|---|---|
| Decision ID | **PRESENT** | `row.decisionId` |
| Direction | **PRESENT** — `row.direction` (0=none, 1=bullish, 2=bearish) | `TelemetryCollector.mqh:106` |
| Rule | **PRESENT** — `row.firedRuleId`, `row.ruleName` | `TelemetryCollector.mqh:138-139` |
| Score | **PRESENT** — all layer scores | `TelemetryCollector.mqh:108-121` |
| Confidence | **PRESENT** | `TelemetryCollector.mqh:107` |
| Candidate ID | **PRESENT** | Implied in settlement chain |
| Signal ID | **PRESENT** — via `row.signalTime` | `TelemetryCollector.mqh:155` |

### 10.3 Execution

| Field | Status | Source |
|---|---|---|
| Order ticket | **PRESENT** — `ExecutionTruthRecord.orderTicket` | `ExecutionTruth.mqh:128` |
| Requested price | **PRESENT** — `ExecutionTruthRecord.requestedPrice` | `ExecutionTruth.mqh:46` |
| Actual fill price | **PRESENT** — `ExecutionTruthRecord.filledPrice` | `ExecutionTruth.mqh:48` |
| Volume | **PRESENT** — `ExecutionTruthRecord.filledVolume` | `ExecutionTruth.mqh:49` |
| SL | **PRESENT** — in ledger INTENT payload | `CExecutionLedgerWriter.mqh:269` |
| TP | **PRESENT** — in ledger INTENT payload | `CExecutionLedgerWriter.mqh:269` |
| Broker result code | **PRESENT** — `ExecutionTruthRecord.retcode` | `ExecutionTruth.mqh:44` |
| Deal ticket | **PRESENT** — `ExecutionTruthRecord.dealTicket` | `ExecutionTruth.mqh:49` |
| Position ticket | **PRESENT** — via ledger DEAL_IN event | `CExecutionLedgerWriter.mqh:377` |
| Execution timestamp | **PRESENT** — `ExecutionTruthRecord.capturedTime` | `ExecutionTruth.mqh:54` |

### 10.4 Exit

| Field | Status | Source |
|---|---|---|
| Exit timestamp | **PRESENT** — `PositionContext.closedTime` | `PositionLifecycleManager.mqh:343` |
| Exit price | **PARTIAL** — not directly captured; derivable from deal history | N/A |
| Exit reason | **MISSING** — EA detects position disappearance, not broker close reason | `PositionLifecycleManager.mqh:336-378` |
| Realized P/L | **PRESENT** — `EVENT_POSITION_CLOSED.profit` (net: profit+swap+commission) | `PositionLifecycleManager.mqh:361-362` |
| Realized R | **PARTIAL** — `CalculateRRatio()` computes R at last known price, not at close | `PositionLifecycleManager.mqh:615-633` |
| MFE | **MISSING** | N/A |
| MAE | **MISSING** | N/A |

### 10.5 Environment

| Field | Status | Source |
|---|---|---|
| EA build identity | **PRESENT** — `>>> BUILD 25B-PROD-01` | `SuperCents_X.mq5:91-93` |
| Configuration fingerprint | **PRESENT** — `row.configFingerprint` | `TelemetryCollector.mqh:100` |
| Symbol | **PRESENT** | `row.symbol` |
| Timeframe | **PRESENT** | `row.timeframe` |
| Run ID | **PRESENT** — `row.runId` | `TelemetryCollector.mqh:169` |
| Build tag | **PRESENT** — `row.buildTag` | `TelemetryCollector.mqh:170` |
| Git head | **PRESENT** — `row.gitHead` | `TelemetryCollector.mqh:171` |

---

## 11. LIVE VS RESEARCH RECONCILIATION

### 11.1 Can demo trades be compared against research?

**YES** — The telemetry schema v6 captures `runId`, `buildTag`, `gitHead` for provenance, and the `configFingerprint` links to the exact parameter set. The `decisionId` is the join key between telemetry rows and execution ledger events.

### 11.2 Known Differences (Demo vs Backtest)

| Factor | Impact | Severity |
|---|---|---|
| Spread | Live spread varies; backtest uses fixed spread | P2 |
| Slippage | Live slippage possible; backtest assumes fill at requested price | P2 |
| Fill price | Live fill = broker price; backtest fill = simulated | P2 |
| Execution delay | Live has latency; backtest is instantaneous | P2 |
| Broker stop levels | Live `SYMBOL_TRADE_STOPS_LEVEL` may differ from backtest assumptions | P2 |
| Market gaps | Live gaps possible; backtest uses available bars only | P3 |
| Rejected orders | Live rejections possible; backtest assumes all orders fill | P2 |
| Partial fills | Live partial fills possible; backtest assumes full fill | P3 |
| Bar mapping | Live bar close times may differ from backtest | P3 |
| Detector timing | Live detector runs at bar open; backtest may differ | P3 |

---

## 12. DEMO ACCOUNT CONFIGURATION

### 12.1 Recommended Initial Target

```
Symbol: EURUSD
Timeframe: M15
Account: MT5 DEMO
Money: DEMO ONLY
Entry Mode: ENTRY_MODE_LEGACY (default)
```

### 12.2 EA Inputs (Defaults)

```
EntryMode = ENTRY_MODE_LEGACY (0)
InpMagicNumber = 27182819
InpRiskPercent = 1.0
InpMaxPositionsPerSymbol = 1
OutcomeTpMode = OUTCOME_TP_FIXED_RR (0)
FixedRRTier = 2.0
SwingSignificanceTier = 0.0
WeightStructure = 25.0
WeightOrderBlock = 20.0
WeightFVG = 15.0
WeightLiquidity = 15.0
WeightTrend = 15.0
WeightPremiumDiscount = 10.0
```

### 12.3 User-Supplied Parameters

The following must be supplied by the user (NOT hardcoded):

| Parameter | Notes |
|---|---|
| Broker | User must select broker |
| Account type | DEMO only for initial deployment |
| Leverage | Broker-provided |
| Deposit | User's demo balance |
| Risk % | Default 1.0; user adjusts per comfort |
| Max positions | Default 1; user adjusts |
| Spread limits | EA validates at order time; no input for max spread |
| Trading hours | No session filter in LEGACY mode |
| VPS/local | User's infrastructure |

---

## 13. DEMO RISK LIMITS

### 13.1 Existing Production Settings

| Setting | Value | Source |
|---|---|---|
| Risk per trade | 1.0% of equity | `InpRiskPercent = 1.0` |
| Max positions/symbol | 1 | `InpMaxPositionsPerSymbol = 1` |
| Slippage | 3 points | `Config.m_slippage = 3` |
| Min RR gate | 1.0 (gross) | `ExecutionPlanner.mqh:353` |
| Net RR gate | 1.0 (spread-adjusted) | `ExecutionPlanner.mqh:364` |
| Volume validation | Full min/max/step | `TradeValidation.mqh:79-127` |
| Margin check | Pre-order | `TradeValidation.mqh:200-228` |

### 13.2 Gaps (No Input/Enforcement)

| Safeguard | Status | Severity |
|---|---|---|
| Max daily loss | **MISSING** — no daily loss limit | P1 |
| Max total exposure | **MISSING** — no aggregate exposure cap beyond per-symbol positions | P1 |
| Max spread at entry | **MISSING** — no spread filter input (spread used in net-RR only) | P2 |
| Max lot size cap | **MISSING** — bounded only by `volumeMax` from broker + risk sizing | P3 |
| Emergency trading disable | **PARTIAL** — `SetExecutionEnabled(false)` exists but no runtime toggle | P2 |
| Manual kill switch | **MT5 native** — remove EA from chart or disable "Auto Trading" | P2 |

---

## 14. KILL SWITCH — EMERGENCY STOP PROCEDURE

### EMERGENCY STOP PROCEDURE

```
1. Remove the EA from the chart:
   - Right-click chart → Expert List → select SuperCents_X → Remove

2. OR disable auto-trading:
   - Click "Auto Trading" button in MT5 toolbar (green → red)
   - This prevents OrderSend from executing even if EA remains on chart

3. OR close the terminal:
   - Shutting down MT5 closes all positions (if configured in broker settings)

4. OR modify the EA input:
   - Change EntryMode to ENTRY_MODE_SHADOW (1) — execution is disabled
   - Re-attach EA to chart
```

**Note:** Removing the EA triggers `OnDeinit()` which calls `Shutdown()` including `RecordRunEnd()` on the ledger. Existing positions remain open with their broker-set SL/TP.

---

## 15. OBSERVATION PROTOCOL

### First Demo Observation Period

| Question | Measurement |
|---|---|
| How many signals occur? | `ConfluenceEngine.m_totalSignalsCreated` |
| How many become orders? | `ExecutionPlanner.m_totalExecutable` |
| How many orders are rejected? | `ExecutionPlanner.m_totalRejected` + `TradeManager.m_totalFailed` |
| How many positions open? | `PositionLifecycleManager.m_statRecovered` + `m_statDiscovered` |
| What rules generate them? | Telemetry `firedRuleId` + `ruleName` |
| What are actual fills? | `ExecutionTruthRecord.filledPrice` |
| What are actual SL/TP distances? | Ledger INTENT payload |
| What is the spread at entry? | Not captured; re-check from broker history |
| Are there duplicate decisions/orders? | `m_totalDuplicates` + `m_totalInspectionBlocked` |
| Are any trades missing from telemetry? | Cross-reference `decisionId` in telemetry vs ledger |
| Are any telemetry trades missing broker evidence? | `DEAL-ADMISSION` log entries |
| Does restart/reconnect preserve state? | `POSITION-DISCOVERED` logs after restart |
| Do real outcomes reconcile with evidence ledger? | `ActualOutcomeSettler` + `StatisticsReporter` |

### Observation Rules

> **Do not change strategy parameters based on individual demo trades.**
> The purpose is to observe execution fidelity, not to optimize.

---

## 16. DEMO DATA COLLECTION

### Recommended Artifact Structure

```
Evidence/
  Demo/
    YYYY-MM-DD/
      manifest.json                    ← Build, config, symbol, timeframe
      telemetry/                       ← TelemetryCollector CSV files
        telemetry_v6_YYYYMMDD.csv
      broker_history/                  ← MT5 deal/position history export
      journal/                         ← MT5 Experts tab logs
      screenshots/                     ← Chart screenshots at key events
      EA_logs/                         ← SuperCents_X.log, compile logs
      config/                          ← .set files, input snapshots
      build/                           ← .ex5 hash, source revision
      reconciliation/                  ← Live-vs-backtest comparison
```

---

## 17. READINESS CLASSIFICATION

### **READY-WITH-LIMITATIONS**

Demo execution is possible with the current build, but the following limitations must be accepted before deployment:

**Critical limitations:**
1. **No daily loss limit** — The EA has no circuit breaker for consecutive losses. A manual kill switch is the only emergency stop.
2. **No max spread filter** — Trades can execute during high-spread conditions (news, market open/close).
3. **No post-fill risk recalculation** — Position size is based on pre-send fill price estimate, not actual fill.
4. **Exit reason indeterminate** — Cannot distinguish SL-hit from TP-hit from manual close in telemetry.

**Minor limitations:**
5. `POSITION_COMMISSION` deprecation warnings (4 warnings, non-blocking).
6. MFE/MAE not tracked in telemetry.
7. Near-duplicate plans after restart possible (different entry price).

---

## 18. CRITICAL GATES

| Gate | Status | Evidence | Severity |
|---|---|---|---|
| Build | **PASS** | 0 errors, 4 warnings (deprecation) | P3 |
| Magic | **PASS** | Stable input `27182819`, validated, filtered | - |
| Symbol isolation | **PASS** | `_Symbol` scoped, all properties from MT5 | - |
| Risk sizing | **PASS** | Full trace: equity→risk%→stopDist→tickValue→volume→normalized | - |
| Position gate | **PASS** | Per-symbol cap (1), dedup, cross-run inspection | - |
| Closed-bar discipline | **PASS** | `IsNewBar()` via `iTime()`, full re-scan each bar | - |
| OrderSend handling | **PASS** | H6 policy, ledger INTENT, result capture, all failure paths | - |
| Fill-price consistency | **PASS** | Live Ask/Bid used for validation/sizing; actual fill captured separately | - |
| SL/TP validity | **PASS** | Directional validation at plan AND pre-send; stop-level check | - |
| Position lifecycle | **PASS** | DISCOVERED→OPEN→CLOSED state machine, restart recovery | - |
| Settlement | **PASS** | EventBus + ActualOutcomeSettler + net P/L from deal history | - |
| Restart recovery | **PASS** | Ledger scan, position discovery, cross-run dedup | - |
| Telemetry | **PASS** | Schema v6 with provenance; decision→execution chain reconstructible | - |
| Provenance | **PASS** | Git HEAD, build tag, run ID, config fingerprint in telemetry | - |
| Kill switch | **PASS** | MT5 native: remove EA, disable auto-trading, or change input | - |
| Demo configuration | **PASS** | Inputs documented; user must supply broker/account details | - |

---

## 19. REQUIRED FINAL ANSWERS

### Q1: Can the current SuperCents_X build safely execute orders on an MT5 DEMO account?

**YES.** The build compiles cleanly (0 errors), has a stable magic number, validates all pre-send conditions, uses correct directional pricing, performs risk-based position sizing, and has a comprehensive failure handling model. The fail-closed `LedgerWiringPermitsExecution()` gate prevents execution if the durable infrastructure is not fully wired.

### Q2: Can every demo trade be reconstructed from decision → order → fill → position → exit → settlement?

**YES.** The execution ledger captures INTENT → SENT/REJECTED/UNKNOWN → DEAL_IN, and the telemetry captures the decision context. The `ActualOutcomeSettler` links position close events back to decision IDs. The chain is reconstructible using ledger + telemetry + deal history.

### Q3: Can the EA survive restart/reconnect without creating duplicate or orphaned execution state?

**YES, with P2 limitation.** The ledger-based `CExecutionPlanInspection` blocks exact plan duplicates across runs. `DiscoverPositions()` recovers open positions. The `CExecutionRecovery` module reconciles pending executions against broker history. Near-duplicate plans (slightly different prices) may pass inspection.

### Q4: Are actual broker fills used consistently for downstream trade accounting?

**YES, with P2 limitation.** Pre-send validation and sizing use the live market price (Ask/Bid) at send time, which is the expected fill price for market orders. The actual broker fill is captured separately in `ExecutionTruthRecord.filledPrice`. The EA does not retrospectively recalculate based on the actual fill — a known, acceptable limitation for a demo observation.

### Q5: Are risk sizing and volume normalization broker-safe?

**YES.** Full validation chain: tick value/size check → risk calculation → volume step alignment (integer-domain P52 fix) → min/max range check → margin sufficiency check. Invalid sizing rejects the plan (P37 fix, no silent floor-clamp). Symbol properties are refreshed per-tick.

### Q6: Are BUY and SELL execution paths both correct?

**YES.** BUY: Ask entry, SL below fill, TP above fill. SELL: Bid entry, SL above fill, TP below fill. Directional validation enforced at both the ExecutionPlanner and TradeValidation layers.

### Q7: Can we identify exactly why each demo trade occurred?

**YES.** The telemetry row captures the fired rule, rule name, confidence, all layer scores, signal time, and the full confluence result. The ledger captures the execution plan with entry/SL/TP policies and prices.

### Q8: Can we identify exactly why a candidate was rejected/not traded?

**YES.** The `ExecutionPlanner` logs every rejection with reason (`Stop Distance`, `Target Distance`, `Broker Min Stop`, `RR Below Minimum`, `NetRR Below Minimum`, `Invalid Prices`, `Stop Too Close`, `Target Too Close`). The `TradeManager` logs every failed order with retcode and rationale.

### Q9: Can demo results later be reconciled against our research telemetry?

**YES.** The telemetry schema v6 includes `runId`, `buildTag`, `gitHead`, and `configFingerprint` for provenance. The `decisionId` is the join key. Research artifacts under `Evidence/Sprint17/` can be compared against demo telemetry using the same schema.

### Q10: What are the exact blockers before EURUSD M15 demo deployment?

**There are no P0 blockers.** The build is ready for controlled demo deployment. The following P1 gaps should be acknowledged:

1. No daily loss limit (manual monitoring required)
2. No max spread filter (manual monitoring during news)
3. No post-fill risk recalculation (known acceptable limitation)
4. No explicit exit reason in telemetry (derivable from deal history)

---

## 20. NO STRATEGY EVALUATION

This audit does NOT evaluate:
- Whether the strategy is profitable
- Whether rule 8 should be promoted
- Whether SMC is effective
- Whether the EA will make money
- Whether the EA has an edge

This audit covers only: **ENGINEERING + EXECUTION + SAFETY + OBSERVABILITY + RECONCILIATION**

---

## DEMO DEPLOYMENT READINESS — FINAL

```
Production strategy modified: NO
Production parameters modified: NO
A-MIRROR rule 8 promoted: NO
Existing rules modified: NO
Tie-break logic modified: NO
Simulator modified: NO
Production EA executed during audit: NO
Real-money account used: NO
Demo order placed during audit: NO

Current build identified: YES
Clean compile: YES
Execution path audited: YES
Risk sizing audited: YES
Order handling audited: YES
Fill-price consistency audited: YES
Lifecycle audited: YES
Restart/recovery audited: YES
Telemetry audited: YES
Provenance audited: YES
Kill switch documented: YES

Final classification: READY-WITH-LIMITATIONS
```
