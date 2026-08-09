# SuperCents_X — Architecture v0.8.0-execution

## 1. Overview

SuperCents_X is an MQL5 Expert Advisor that implements Smart Money Concept (SMC)
market structure analysis and systematic trade execution. The architecture is a
strict layered pipeline — each layer depends only on layers below it.

```
Detection
    ↓
Visualization
    ↓
Confluence
    ↓
EntrySetupBuilder
    ↓
EntryValidator
    ↓
EntryEngine (state machine)
    ↓
RiskManager
    ↓
ExecutionManager
    ↓
MT5 Broker (CTrade)
```

## 2. Update Pipeline (per bar)

The engine processes one new bar in this exact order:

```
SwingDetector → StructuralPivotEngine → BOSDetector → TrendState
    → ProtectedPointManager → CHOCHDetector → OrderBlockDetector
    → FVGDetector → VisualizationManager → ConfluenceEngine
    → EntrySetupBuilder → EntryValidator → EntryEngine
    → RiskManager → ExecutionManager
```

Each module reads from its dependencies and produces output consumed by the next
stage. No module reads from a module later in the pipeline.

### 2.1 Profiling

The `UpdateModules()` method in `Core/Engine.mqh` measures each stage with
`GetMicrosecondCount()` and logs `PERF` lines showing per-stage latency.

## 3. Module Responsibilities

### Detection Layer

| Module | File | Responsibility |
|---|---|---|
| SwingDetector | `Structure/SwingDetector.mqh` | Identifies swing highs/lows using fractal lookback |
| StructuralPivotEngine | `Structure/StructuralPivotEngine.mqh` | Filters swings into structural pivots with lock/unlock state |
| BOSDetector | `Structure/BOSDetector.mqh` | Detects Break of Structure (close beyond locked pivot) |
| TrendState | `Structure/TrendState.mqh` | State machine: BULLISH, BEARISH, NEUTRAL transitions |
| ProtectedPointManager | `Structure/ProtectedPointManager.mqh` | Tracks which pivots are protected (not yet broken) |
| CHOCHDetector | `Structure/CHOCHDetector.mqh` | Detects Change of Character (trend reversal signals) |
| OrderBlockDetector | `Structure/OrderBlockDetector.mqh` | Identifies order blocks near CHOCH pivot zones |
| FVGDetector | `Structure/FVGDetector.mqh` | Finds Fair Value Gaps (3-bar imbalance) |

### Visualization Layer

| Module | File | Responsibility |
|---|---|---|
| VisualizationManager | `Visualization/VisualizationManager.mqh` | Orchestrates all renderers |
| BaseRenderer | `Visualization/BaseRenderer.mqh` | Abstract base with incremental update pattern |
| SwingRenderer | `Visualization/SwingRenderer.mqh` | Draws swing high/low labels |
| PivotRenderer | `Visualization/PivotRenderer.mqh` | Draws structural pivot markers |
| BOSRenderer | `Visualization/BOSRenderer.mqh` | Draws BOS confirmation arrows |
| CHOCHRenderer | `Visualization/CHOCHRenderer.mqh` | Draws CHOCH markers |
| ProtectedRenderer | `Visualization/ProtectedRenderer.mqh` | Highlights protected pivots (incremental O(1)) |
| OrderBlockRenderer | `Visualization/OrderBlockRenderer.mqh` | Draws order block rectangles |
| FVGRenderer | `Visualization/FVGRenderer.mqh` | Draws FVG zones |

All renderers use an incremental pattern: they track the last rendered count and
extend only new objects, except when a full redraw is forced.

### Confluence Layer

| Module | File | Responsibility |
|---|---|---|
| ConfluenceEngine | `Confluence/ConfluenceEngine.mqh` | Aggregates detector signals, scores, deduplicates |

### Entry Layer

| Module | File | Responsibility |
|---|---|---|
| EntrySetupBuilder | `Entry/EntrySetupBuilder.mqh` | Consumes ConfluenceSignal, produces EntrySetup via priority (CHOCH→BOS→OB→FVG) |
| EntryValidator | `Entry/EntryValidator.mqh` | Qualifies setups (min score 30, price consistency) |
| EntryEngine | `Entry/EntryEngine.mqh` | State machine: IDLE→ARMED→FILLED/CANCELLED/EXPIRED |
| RiskManager | `Entry/RiskManager.mqh` | Calculates PositionSizing (lots, risk money, stop distance) |
| ExecutionManager | `Entry/ExecutionManager.mqh` | Submits orders via CTrade, validates pre-conditions |

## 4. Data Contracts

### ConfluenceSignal (`Confluence/ConfluenceEngine.mqh`)

```
bullish, bearish         - direction flags
score                    - aggregate confluence score
bosSignal, chochSignal,
obSignal, fvgSignal      - individual detector signal data
bosStrength, chochStrength,
obStrength, fvgStrength  - per-detector contribution
id                       - unique signal ID
```

### EntrySetup (`Entry/EntrySetup.mqh`)

```
valid                    - qualification flag
type                     - SETUP_NONE / BOS_CONTINUATION / CHOCH_REVERSAL /
                           ORDERBLOCK_RETEST / FVG_CONTINUATION
direction                - TREND_BULLISH / TREND_BEARISH
entryPrice               - the calculated entry price
stopLoss                 - the calculated stop loss
takeProfit               - the calculated take profit
confluenceScore          - inherited from signal
riskRewardRatio          - default 2.0
signalTime               - timestamp of originating signal
bosId, chochId, obId,
fvgId, protectedPointId  - detector IDs for deduplication
```

### PositionSizing (`Entry/RiskManager.mqh`)

```
lots                     - calculated lot size (default 0.01)
riskMoney                - monetary risk amount
stopDistance             - entry-to-SL distance in points
```

### ExecutionResult (`Entry/EntrySetup.mqh`)

```
success                  - whether the order was accepted by broker
orderTicket              - MT5 order ticket (0 if rejected)
dealTicket               - MT5 deal ticket (0 if rejected)
status                   - ENUM_EXECUTION_STATUS (see below)
retcode                  - broker return code
description              - human-readable result string
```

### ENUM_EXECUTION_STATUS

```
PENDING                  - default/uninitialized
ACCEPTED                 - order submitted successfully
REJECTED_INVALID_SETUP   - setup.valid == false
REJECTED_OPEN_POSITION   - position exists for this symbol/magic
REJECTED_PENDING_ORDER   - pending order exists for this symbol/magic
REJECTED_TRADING_DISABLED- terminal or expert trading off
REJECTED_VOLUME_INVALID  - lot size outside range or not aligned to step
REJECTED_STOPS_INVALID   - SL/TP distance below broker minimum
REJECTED_MARGIN_INSUFFICIENT - not enough free margin
REJECTED_BROKER          - OrderSend rejected by broker
REJECTED_SYMBOL_INVALID  - symbol not tradeable
ERROR_UNKNOWN            - generic failure (e.g. not initialized)
```

## 5. State Machines

### EntryEngine

```
         Arm(Cancel)
IDLE ──────────────→ ARMED
                       │
          ┌────────────┼────────────────────┐
          ▼            ▼                    ▼
        FILLED    CANCELLED             EXPIRED
       (manual)   (Cancel())        (future use)
```

- `Arm()` is idempotent: duplicates rejected via `EntrySetup::Matches()`.
- `GetState()` returns current state.
- `GetActiveSetup()` returns the armed setup (fails if IDLE).
- Three guard layers: `Matches()` (same setup), `HasOpenPosition()`,
  `HasPendingOrder()`.

### TrendState

```
NEUTRAL ←→ BULLISH ←→ BEARISH
```

Transitions on BOS events: bullish BOS pushes to BULLISH, bearish BOS pushes to
BEARISH. Consecutive same-direction BOS events reinforce the trend.

## 6. Ownership Rules

1. **Only ExecutionManager** may call `CTrade` (or any MT5 trading API).
2. **ExecutionManager** is the sole broker boundary — all order submission flows
   through it.
3. **EntryEngine** never accesses detectors directly; it only reads `EntrySetup`.
4. **EntrySetupBuilder** is the only creator of `EntrySetup` from signals.
5. **Validators** return `ExecutionResult` — no module mixes `bool` returns with
   implicit failure modes.
6. **Modules own their dependencies** — pointer references are set at init time,
   not looked up dynamically.
7. **Global state** — the engine is instantiated once as `g_engine` in
   `SuperCents_X.mq5`. Regression tests instantiate their own module instances.

## 7. Execution Flow (Market Orders)

```
ConfluenceEngine produces ConfluenceSignal
    ↓
EntrySetupBuilder.Build(signal) → EntrySetup
    ↓
EntryValidator.IsValid(setup) → bool
    ↓
EntryEngine.Arm(setup) → bool (idempotent via Matches())
    ↓
RiskManager.Calculate(setup) → PositionSizing
    ↓
ExecutionManager.Execute(setup, lots) → ExecutionResult
    │
    ├── ValidateTradingAllowed()  → ExecutionResult
    ├── ValidateVolume(lots)      → ExecutionResult
    ├── ValidateStops(setup)      → ExecutionResult
    ├── ValidateMargin(setup,lots)→ ExecutionResult
    ├── CTrade.Buy() / Sell()     → broker
    └── Return ExecutionResult
```

For LIMIT setups (OB, FVG), `Execute()` logs the request and returns
`ACCEPTED` without calling `CTrade`. Pending-order dispatch is deferred.

## 8. Execution Style Mapping

| Setup Type | Execution Style | Status |
|---|---|---|
| SETUP_BOS_CONTINUATION | EXEC_MARKET | ✅ BUY/SELL via CTrade |
| SETUP_CHOCH_REVERSAL | EXEC_MARKET | ✅ BUY/SELL via CTrade |
| SETUP_ORDERBLOCK_RETEST | EXEC_LIMIT | 🟡 Logging only |
| SETUP_FVG_CONTINUATION | EXEC_LIMIT | 🟡 Logging only |

## 9. Regression Tests

### Sprint10_VisualRegression (legacy — log file only in `Temp/`)

Validated visualization layer rendering. The original `Sprint10_VisualRegression.mq5`
no longer exists on disk; its log confirms 7 renderers, 0 leaks, 0 duplicates.

### Sprint12_ExecutionRegression (`Tests/Sprint12_ExecutionRegression.mq5`)

Eight test functions covering:

| Test | Scope |
|---|---|
| Test 1 — BuilderValidSetup | Builder produces valid setup from Confluence signal |
| Test 2 — Validator | Score threshold, price consistency, invalid/SETUP_NONE |
| Test 3 — EntryEngine | IDLE→ARMED→Cancel, Matches() dedup, invalid rejection |
| Test 4 — RiskManager | PositionSizing defaults, invalid fallback |
| Test 5 — ExecutionManager | ExecutionResult rejection paths |
| Test 6 — EndToEndPipeline | Full chain: signal → build → validate → arm → size → execute |
| Test 7 — ExecutionStyleMapping | GetExecutionStyle for all 4 types |
| Test 8 — Determinism | Repeatable signal+setup across two pipeline runs |
| Test 9 — ExecutionResultRejections | Every rejection status validated |

## 10. Known Future Work

- **PositionManager** — Position state queries, caching, refresh (Sprint 13.0)
- **TradeManager** — Break-even, trailing stop, partial close, scaling out
- **PendingOrderManager** — Limit/Stop order dispatch for OB/FVG
- **Incremental BOSDetector** — Replace full-history O(N) scan with O(1)
  incremental pattern (matching the 7 renderers)
- **ProtectedRenderer optimization** — Confirmed via static analysis as the
  previous ~190ms hotspot; incremental O(1) fix complete
- **Configurable risk** — Dynamic lot sizing based on account equity
- **Log level routing** — Separate file-per-run logging

## 11. File Layout

```
Core/
    Engine.mqh          - main orchestration loop
    Config.mqh          - configuration
    Logger.mqh          - logging

Structure/
    SwingDetector.mqh
    StructuralPivotEngine.mqh
    BOSDetector.mqh
    TrendState.mqh
    ProtectedPointManager.mqh
    CHOCHDetector.mqh
    OrderBlockDetector.mqh
    FVGDetector.mqh

Visualization/
    VisualizationManager.mqh
    BaseRenderer.mqh
    ChartObjectNames.mqh, ChartStyle.mqh, ChartUtils.mqh, RenderConfig.mqh
    SwingRenderer.mqh, PivotRenderer.mqh, BOSRenderer.mqh
    CHOCHRenderer.mqh, ProtectedRenderer.mqh
    OrderBlockRenderer.mqh, FVGRenderer.mqh

Confluence/
    ConfluenceEngine.mqh

Entry/
    EntrySetup.mqh       - structs, enums, ExecutionResult
    EntrySetupBuilder.mqh
    EntryValidator.mqh
    EntryEngine.mqh
    RiskManager.mqh
    ExecutionManager.mqh

Utils/
    Constants.mqh        - ENUM_MODULE_ID, constants
    Types.mqh            - Trend enum
    Helpers.mqh          - utility functions

Tests/
    Sprint12_ExecutionRegression.mq5

docs/
    ARCHITECTURE_v0.8.0.md

SuperCents_X.mq5        - entry point, global engine instance
```
