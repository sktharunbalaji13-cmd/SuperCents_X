# Sprint 13.5 — Entry Execution Planner

**Frozen**: 2026-07-26
**Tag**: `v1.4-execution-planner`
**Parent**: `v1.3-entry-decision` (d9840c3)

## Architecture

```
EntryDecisions (immutable)
        │
        ▼
ExecutionPlanner
  ├─ EntryPriceResolver   (OB retest, FVG midpoint, liquidity level, current price)
  ├─ StopLossResolver     (OB side, liquidity side, protected point, broker minimum)
  ├─ TargetResolver       (opposing liquidity/OB/FVG, fixed RR, previous swing)
  └─ Validation           (min stop distance, spread, RR, invalid prices)
        │
        ▼
ExecutionPlan { entry, stop, target, RR, executable, rationale }
```

**No MT5 orders are sent.** Plans are created but not executed.

## New Files

```
Entry/
├── ExecutionPlanTypes.mqh      (ExecutionPlan, ExecutionPlanConfig, enums)
├── EntryPriceResolver.mqh      (ResolveEntryPrice — 4 policies)
├── StopLossResolver.mqh        (ResolveStopLoss — 4 policies)
├── TargetResolver.mqh          (ResolveTakeProfit — 5 policies)
├── ExecutionPlanner.mqh        (CExecutionPlanner — orchestrator)
```

## Modified Files

```
Confluence/ConfluenceEngine.mqh  (wired m_executionPlanner after entry decisions)
```

## Key Design Decisions

- **No orders sent** — deferred to Sprint 13.6
- **Resolvers are stateless functions** — deterministic output from same inputs
- **Three independent resolvers** — entry, stop, target each have their own policies
- **Configurable** via `ExecutionPlanConfig` struct (policies, buffer, min distances)
- **Validation separates planning from rejection** — all plans are created; only valid ones marked EXECUTABLE
- **Shutdown summary** with avg RR, avg stop/target in pips, rejection breakdown

## Regression Results (2-month M15)

### Execution Plan Summary
| Metric | Value |
|--------|-------|
| Plans Created | 3,918 |
| Executable | 0 |
| Rejected | 3,918 |

All rejected due to policy interaction: default `ENTRY_OB_RETEST` + `STOP_OB_SIDE` produces 3-pip stops, below 10-pip minimum. The validation logic is working correctly.

### Invariants (unchanged from v1.3)
- Confluence signals: 3,935 created, 3,517 expired ✅
- Trade candidates: 3,918 created, 4 expired ✅
- Entry decisions: 3,918 qualified, 4 expired ✅
- All upstream layers intact ✅

### Log Samples
```
EXECUTION-PLAN Decision=3918 Status=REJECTED Entry=1.18001 SL=1.17971 TP=1.18061 RR=2.00
  StopPolicy=Below OB + buffer TargetPolicy=Fixed RR 2.0 Reason=Broker Min Stop
```

## Acceptance Criteria

- [x] Every EntryDecision produces zero or one ExecutionPlan
- [x] No MT5 orders sent
- [x] All execution parameters fully explainable (policy names, rationale, rejection reason)
- [x] Broker validation is deterministic (spread, min stop, RR)
- [x] RR calculations are correct
- [x] Two-month regression produces deterministic execution plans (3918 created)
- [x] Structural, rule, candidate, and decision layers remain unchanged
