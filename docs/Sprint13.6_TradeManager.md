# Sprint 13.6 — TradeManager & Order Execution

**Date**: 2026-07-26
**Parent**: `v1.4.1-policy-tuning` (117e465)

## Objective

Convert an executable `ExecutionPlan` into a real MT5 trade request.

## Architecture

```
Structural Engine (Frozen)
        │
        ▼
Rule Engine (Frozen)
        │
        ▼
Trade Candidate (internal to ConfluenceEngine)
        │
        ▼
Entry Decision (internal to ConfluenceEngine)
        │
        ▼
Execution Plan (internal to ConfluenceEngine)
        │
        ▼
TradeManager  ← new
        │
        ▼
OrderSend()
        │
        ▼
TradeExecutionResult
```

## New Files

| Module | File | Responsibility |
|--------|------|----------------|
| TradeExecutionResult | `Trading/TradeExecutionResult.mqh` | Deterministic result struct for every submission attempt |
| TradeRequestBuilder | `Trading/TradeRequestBuilder.mqh` | Translates `ExecutionPlan` + volume → `MqlTradeRequest`. Business-logic-free. |
| TradeValidation | `Trading/TradeValidation.mqh` | Broker-side pre-checks: trading allowed, volume valid, stop levels, margin |
| TradeManager | `Trading/TradeManager.mqh` | Orchestrator: verify plan, dedup, build request, validate, OrderSend, capture result, log, shutdown summary |

## Renamed File

| Old | New | Reason |
|-----|-----|--------|
| `Entry/TradeManager.mqh` → `CTradeManager` | `Entry/PositionLifecycleManager.mqh` → `CPositionLifecycleManager` | The old module handles break-even/trailing stop on existing positions (lifecycle), not order submission. New module takes the `TradeManager` name. |

## TradeExecutionResult

```cpp
struct TradeExecutionResult {
    ulong    executionPlanId;
    bool     submitted;
    ulong    ticket;
    uint     retcode;
    string   retcodeDescription;
    double   filledPrice;
    double   filledVolume;
    datetime executionTime;
    string   rationale;
};
```

## Idempotency

TradeManager tracks submitted plan IDs in `m_submittedIds[]`. A plan ID that has been submitted or attempted is never submitted again.

The same `ExecutionPlan` never generates multiple live orders.

## Instrumentation

**Success** (logged per order):
```
ORDER-SENT Plan=481 Ticket=123456 Price=1.18234 Volume=0.10 Retcode=DONE(0)
```

**Failure** (logged per attempt):
```
ORDER-FAILED Plan=482 Retcode=INVALID_STOPS(10019) Reason=OrderSend failed: retcode=10019 INVALID_STOPS
```

**Shutdown Summary**:
```
==================== TRADE MANAGER SUMMARY ====================
  Execution Plans Received           3918
  Submitted                           1330
  Succeeded                             0    (or N in live trading)
  Failed                              1330  (or N in live trading)
  Duplicate Prevented                    0
================================================================
```

## Modified Files

| File | Change |
|------|--------|
| `Utils/Constants.mqh` | Added `MODULE_EXECUTION_PLANNER`, `MODULE_TRADING`, `MODULE_TRADE_REQUEST_BUILDER`, `MODULE_TRADE_VALIDATION` |
| `Entry/ExecutionPlanner.mqh` | Fixed logger module constant (was `MODULE_CONFLUENCE_ENGINE`) |
| `Confluence/ConfluenceEngine.mqh` | Added `GetExecutionPlanner()` accessor for internal pipeline planner |
| `Core/Engine.mqh` | Wired `CTradeManager` (order submission) + `CPositionLifecycleManager` (BE/TS). Shutdown order: TradeManager → ConfluenceEngine → detectors |
| `SuperCents_X.mq5` | Updated includes for renamed/located files |

## Pipeline Wiring

The full pipeline is self-contained inside `ConfluenceEngine::Update()`:
1. Rule evaluation → `RuleResult[7]`
2. `m_candidateBuilder.Update(results, 7)` → builds TradeCandidates
3. `m_entryDecisionEngine.Update(m_candidateBuilder)` → creates EntryDecisions
4. `m_executionPlanner.Update(m_entryDecisionEngine, m_candidateBuilder)` → creates ExecutionPlans

The engine then calls:
5. `m_tradeExecutionManager.Update()` → submits executable plans via OrderSend

## Acceptance Criteria

- [x] Every executable ExecutionPlan produces at most one submission attempt
- [x] Duplicate submissions are prevented (idempotency tracking)
- [x] All MT5 return codes are captured and logged as human-readable names
- [x] Every submission produces a `TradeExecutionResult`
- [x] No upstream layer is mutated (all Trading modules consume, don't produce)
- [x] Shutdown summary shows received/submitted/succeeded/failed/duplicate counts
- [ ] Regression confirms deterministic behavior for both successful and failed submissions

## Non-Goals (deferred)

- Trailing stops (exists in PositionLifecycleManager from Sprint 13.1)
- Break-even logic (exists in PositionLifecycleManager from Sprint 13.1)
- Partial closes
- Position scaling
- Multi-symbol portfolio coordination
- Trade recovery after terminal restart
- Volume sizing from RiskManager (uses fixed default: 0.01 lots)
