# SmartMoneyEA_X — Project Structure

## Overview

**Project:** SmartMoneyEA_X (Smart Money Concepts Expert Advisor)  
**Platform:** MetaTrader 5 (MQL5)  
**Architecture:** Modular, object-oriented design with separation of concerns  
**Version:** 1.0.0  
**Root Directory:** `c:\Users\k.tharun balaji\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\SmartMoneyEA_v4\SmartMoneyEA_X`

---

## Directory Tree

```
SmartMoneyEA_X/
├── SmartMoneyEA_X.mq5              # Main EA entry point
├── SmartMoneyEA_X.ex5              # Compiled EA (binary)
├── SPRINT_3.2_DELIVERABLES.md      # Sprint 3.2 documentation
├── SPRINT_4.4_INVESTIGATION_REPORT.md  # Sprint 4.4 SPH investigation
│
├── Core/                           # Core engine and orchestration
│   ├── Engine.mqh                  # Main engine (orchestrates all modules)
│   ├── StateMachine.mqh            # Market state machine (BOS/CHOCH/MSS)
│   ├── TradeManager.mqh            # Trade execution and management
│   └── RiskManager.mqh             # Risk calculation and position sizing
│
├── Structure/                      # Market structure detection
│   ├── SwingDetector.mqh           # Swing High/Low detection (SPH/SPL)
│   ├── BOSDetector.mqh             # Break of Structure detection
│   ├── BOSDetector_backup.mqh      # Backup of BOSDetector (pre-v3.2)
│   └── CHOCHDetector.mqh           # Change of Character detection
│
├── Entry/                          # Entry signal generation
│   └── EntryValidator.mqh          # Validates entry conditions
│
├── Exit/                           # Exit signal generation
│   └── ExitManager.mqh             # Manages exit conditions
│
├── Filters/                        # Trade filtering
│   ├── SessionFilter.mqh           # Time-of-day filtering
│   └── SpreadFilter.mqh            # Spread-based filtering
│
├── Liquidity/                      # Liquidity detection
│   └── LiquidityDetector.mqh       # Detects liquidity sweeps/pools
│
├── OrderFlow/                      # Order flow analysis
│   ├── FVGDetector.mqh             # Fair Value Gap detection
│   └── OrderBlockDetector.mqh      # Order Block detection
│
├── Dashboard/                      # Visualization and UI
│   └── Dashboard.mqh               # Chart dashboard and info panel
│
├── Utils/                          # Shared utilities
│   ├── Constants.mqh               # Project-wide constants and defaults
│   ├── Enums.mqh                   # Enumerations (trend states, signal types, etc.)
│   ├── Helpers.mqh                 # Helper functions (formatting, object management)
│   ├── Logger.mqh                  # Centralized logging system
│   └── Structures.mqh              # Data structures (SwingPoint, BOSEvent, etc.)
│
└── Logs/                           # Log file output directory (runtime)
    └── [*.log files generated at runtime]
```

---

## File Descriptions

### Root Level

| File | Type | Description |
|------|------|-------------|
| `SmartMoneyEA_X.mq5` | MQL5 | Main EA entry point with `OnInit()`, `OnDeinit()`, `OnTick()` |
| `SmartMoneyEA_X.ex5` | Binary | Compiled EA for MetaTrader 5 |
| `SPRINT_3.2_DELIVERABLES.md` | Markdown | Sprint 3.2 completion report and deliverables |
| `SPRINT_4.4_INVESTIGATION_REPORT.md` | Markdown | Sprint 4.4 SPH investigation report (added) |

---

### Core/ — Engine and Orchestration

| File | Lines | Description |
|------|-------|-------------|
| `Engine.mqh` | 298 | Main engine class that initializes and coordinates all modules. Handles tick processing, shutdown, and reporting. |
| `StateMachine.mqh` | — | Market state machine tracking BOS, CHOCH, and MSS events |
| `TradeManager.mqh` | — | Trade execution, position management, and order handling |
| `RiskManager.mqh` | — | Risk calculation, position sizing, and margin management |

**Key Responsibilities:**
- `Engine`: Module lifecycle, tick dispatch, shutdown reporting
- `StateMachine`: Market structure state transitions
- `TradeManager`: Order placement, modification, closure
- `RiskManager`: Lot size calculation, stop-loss/take-profit logic

---

### Structure/ — Market Structure Detection

| File | Lines | Description |
|------|-------|-------------|
| `SwingDetector.mqh` | 631 | **Primary investigation target.** Detects Swing Highs/Lows and promotes them to Structural Pivots (SPH/SPL). |
| `BOSDetector.mqh` | 864 | Detects Break of Structure (BOS) events with validation rules and visualization |
| `BOSDetector_backup.mqh` | — | Backup copy of BOSDetector from previous version (pre-v3.2) |
| `CHOCHDetector.mqh` | — | Detects Change of Character (CHOCH) events |

**Key Classes:**
- `SwingDetector`: Swing point detection, quality scoring, structural pivot promotion
- `BOSDetector`: BOS validation, pivot consumption tracking, historical scan
- `CHOCHDetector`: CHOCH event detection and validation

---

### Entry/ — Entry Signal Generation

| File | Description |
|------|-------------|
| `EntryValidator.mqh` | Validates entry conditions based on market structure, liquidity, and order flow |

**Purpose:** Determines when to enter trades based on confluence of multiple factors.

---

### Exit/ — Exit Signal Generation

| File | Description |
|------|-------------|
| `ExitManager.mqh` | Manages exit conditions including stop-loss, take-profit, and trailing stops |

**Purpose:** Handles trade exits and position management.

---

### Filters/ — Trade Filtering

| File | Description |
|------|-------------|
| `SessionFilter.mqh` | Filters trades based on trading session (Asia, London, New York) |
| `SpreadFilter.mqh` | Filters trades based on current spread conditions |

**Purpose:** Prevents trades during unfavorable market conditions.

---

### Liquidity/ — Liquidity Detection

| File | Description |
|------|-------------|
| `LiquidityDetector.mqh` | Detects liquidity sweeps, pools, and grabs |

**Purpose:** Identifies institutional liquidity levels for trade validation.

---

### OrderFlow/ — Order Flow Analysis

| File | Description |
|------|-------------|
| `FVGDetector.mqh` | Detects Fair Value Gaps (imbalances) between candles |
| `OrderBlockDetector.mqh` | Detects institutional order blocks (bullish/bearish) |

**Purpose:** Analyzes order flow and institutional activity.

---

### Dashboard/ — Visualization

| File | Description |
|------|-------------|
| `Dashboard.mqh` | Chart-based dashboard displaying market structure, pivots, BOS events |

**Purpose:** Visual representation of detected structures and events on the chart.

---

### Utils/ — Shared Utilities

| File | Lines | Description |
|------|-------|-------------|
| `Constants.mqh` | 115 | Project-wide constants (magic numbers, thresholds, colors, object prefixes) |
| `Enums.mqh` | — | Enumerations for trend states, signal types, log levels, object types |
| `Helpers.mqh` | — | Utility functions (price formatting, object deletion, safe operations) |
| `Logger.mqh` | 175 | Centralized logging system with file and journal output |
| `Structures.mqh` | 171 | Data structures (SwingPoint, BOSEvent, StructureEvent, TradeSignal, etc.) |

**Key Structures:**
- `SwingPoint`: Swing High/Low with structural pivot extensions
- `BOSEvent`: Break of Structure event data
- `StructureEvent`: Market structure event (BOS, CHOCH, MSS)
- `TradeSignal`: Validated trade entry signal
- `TradeRecord`: Active trade tracking

---

### Logs/ — Runtime Output

| Item | Description |
|------|-------------|
| `*.log` | Log files generated at runtime (timestamped) |

**Purpose:** Persistent logging for debugging and analysis.

---

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        SmartMoneyEA_X.mq5                    │
│                    (OnInit / OnTick / OnDeinit)              │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                          Engine.mqh                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ SwingDetector│  │  BOSDetector │  │   StateMachine    │  │
│  │   (Structure)│  │  (Structure) │  │   (Core)          │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
│         │                  │                     │            │
│         └──────────────────┼─────────────────────┘            │
│                            │                                  │
│  ┌──────────────┐  ┌───────┴──────────┐  ┌───────────────┐  │
│  │TradeManager  │  │   RiskManager    │  │  Entry/Exit    │  │
│  │   (Entry)    │  │    (Risk)        │  │   Validators   │  │
│  └──────────────┘  └──────────────────┘  └───────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Supporting Modules                        │
│  ┌────────────┐  ┌────────────┐  ┌──────────────────────┐  │
│  │  Filters   │  │ Liquidity  │  │     OrderFlow        │  │
│  │ (Session,  │  │ Detector   │  │ (FVG, OrderBlock)    │  │
│  │  Spread)   │  │            │  │                      │  │
│  └────────────┘  └────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Dashboard.mqh                             │
│              (Chart Visualization)                           │
└─────────────────────────────────────────────────────────────┘
```

---

## Module Dependencies

```
SmartMoneyEA_X.mq5
    └── Engine.mqh
            ├── StateMachine.mqh
            │       └── Utils/Logger.mqh
            │       └── Utils/Structures.mqh
            │
            ├── TradeManager.mqh
            │       └── Utils/Logger.mqh
            │       └── Utils/Helpers.mqh
            │
            ├── RiskManager.mqh
            │       └── Utils/Logger.mqh
            │       └── Utils/Helpers.mqh
            │
            ├── SwingDetector.mqh (Structure/)
            │       ├── Utils/Logger.mqh
            │       ├── Utils/Structures.mqh
            │       ├── Utils/Constants.mqh
            │       └── Utils/Helpers.mqh
            │
            ├── BOSDetector.mqh (Structure/)
            │       ├── Utils/Logger.mqh
            │       ├── Utils/Structures.mqh
            │       ├── Utils/Constants.mqh
            │       ├── Utils/Helpers.mqh
            │       └── SwingDetector.mqh
            │
            ├── CHOCHDetector.mqh (Structure/)
            │       └── [similar dependencies]
            │
            ├── EntryValidator.mqh (Entry/)
            │       └── [depends on Structure modules]
            │
            ├── ExitManager.mqh (Exit/)
            │       └── [depends on TradeManager]
            │
            ├── SessionFilter.mqh (Filters/)
            ├── SpreadFilter.mqh (Filters/)
            │
            ├── LiquidityDetector.mqh (Liquidity/)
            │       └── [depends on SwingDetector]
            │
            ├── FVGDetector.mqh (OrderFlow/)
            ├── OrderBlockDetector.mqh (OrderFlow/)
            │
            └── Dashboard.mqh (Dashboard/)
                    └── [depends on all Structure modules]
```

---

## Configuration and Constants

### Key Thresholds (Constants.mqh)

| Constant | Value | Description |
|----------|-------|-------------|
| `SMA_SWING_STRENGTH` | 4 | Fractal strength for swing detection |
| `SMA_MIN_SWING_DISTANCE` | 5.0 points | Minimum same-type swing distance |
| `SMA_MIN_STRUCT_DISTANCE` | 50.0 points | Minimum structural distance |
| `SMA_MIN_IMPULSE_POINTS` | 10.0 points | Minimum impulse for structural pivot |
| `SMA_BOS_BUFFER_POINTS` | 10.0 points | Minimum buffer beyond pivot for BOS |
| `SMA_MAX_BOS_EVENTS` | 500 | Maximum stored BOS events |
| `SMA_MAGIC_NUMBER` | 20240101 | EA magic number for trade identification |

### Object Prefixes

| Prefix | Usage |
|--------|-------|
| `SMX_SW_` | Swing points (SH/SL) |
| `SMX_BOS_` | Break of Structure events |
| `SMX_CH_` | Change of Character events |
| `SMX_MSS_` | Market Structure Shift |
| `SMX_OB_` | Order Blocks |
| `SMX_FVG_` | Fair Value Gaps |
| `SMX_LIQ_` | Liquidity levels |
| `SMX_DB_` | Dashboard elements |

---

## Compilation and Deployment

### Build Process

1. **Source Files:** All `.mqh` (include) and `.mq5` (main) files
2. **Compilation:** MetaEditor compiles `SmartMoneyEA_X.mq5` → `SmartMoneyEA_X.ex5`
3. **Deployment:** Copy `.ex5` to MQL5/Experts/ directory in MT5
4. **Logs:** Generated in MQL5/Logs/ directory at runtime

### Module Loading Order

1. `SmartMoneyEA_X.mq5` (entry point)
2. `Core/Engine.mqh` (orchestrator)
3. `Core/StateMachine.mqh` (state tracking)
4. `Core/TradeManager.mqh` (trade execution)
5. `Core/RiskManager.mqh` (risk management)
6. `Structure/SwingDetector.mqh` (swing detection)
7. `Structure/BOSDetector.mqh` (BOS detection)
8. `Structure/CHOCHDetector.mqh` (CHOCH detection)
9. Supporting modules (Entry, Exit, Filters, Liquidity, OrderFlow, Dashboard)

---

## Sprint History

| Sprint | Focus | Key Deliverables |
|--------|-------|------------------|
| 3.2 | BOS Detection | BOSDetector v3.2, validation rules, pivot consumption |
| 4.3 | Structural Pivot Validation | Pivot ID tracking, duplicate prevention, validation reports |
| 4.4 | SPH Investigation | Diagnostic instrumentation, rejection tracking, root cause analysis |

---

## Current Investigation Status (Sprint 4.4)

**Issue:** Zero Structural Pivot Highs (SPH) created during historical scan  
**Root Cause:** Immutable `impulsePoints` field prevents re-evaluation after first failed promotion  
**Status:** Instrumentation complete, awaiting runtime data  
**Report:** `SPRINT_4.4_INVESTIGATION_REPORT.md`

### Modified Files

1. `SmartMoneyEA_X/Structure/SwingDetector.mqh` — Added diagnostics
2. `SmartMoneyEA_X/Core/Engine.mqh` — Added shutdown report call
3. `SmartMoneyEA_X/SPRINT_4.4_INVESTIGATION_REPORT.md` — Created investigation report

### Unmodified Files (Trading Logic Intact)

- `Core/StateMachine.mqh`
- `Core/TradeManager.mqh`
- `Core/RiskManager.mqh`
- `Structure/BOSDetector.mqh`
- `Structure/CHOCHDetector.mqh`
- `Entry/EntryValidator.mqh`
- `Exit/ExitManager.mqh`
- `Filters/SessionFilter.mqh`
- `Filters/SpreadFilter.mqh`
- `Liquidity/LiquidityDetector.mqh`
- `OrderFlow/FVGDetector.mqh`
- `OrderFlow/OrderBlockDetector.mqh`
- `Dashboard/Dashboard.mqh`
- All `Utils/*.mqh` files

---

## Next Steps

1. **Run EA** on target instrument/timeframe
2. **Review Experts Log** for shutdown report
3. **Analyze rejection breakdown** to identify dominant failure reason
4. **Consider fixes:**
   - Adjust `m_minImpulsePoints` threshold
   - Implement impulse reset logic for re-evaluation
   - Consider sliding window approach for promotion

---

*Document generated: Sprint 4.4 — Project Structure Documentation*