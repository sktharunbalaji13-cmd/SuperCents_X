# Validation Lab — Architecture v2.7

## High-Level Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CValidationLab (Orchestrator)                       │
│  Init() → StartRun() → [collect events] → EndRun() → Shutdown()            │
└─────────────────────────────────────────────────────────────────────────────┘
         │                    │                      │
         ▼                    ▼                      ▼
┌─────────────────┐  ┌──────────────────┐  ┌──────────────────────┐
│  Data Sources   │  │  Event System    │  │  Validation Phases   │
│                 │  │                  │  │                      │
│ IValidationData │  │ CValidationEvent │  │ CWalkForwardPipeline │
│ Source          │  │ Bus              │  │ CMonteCarloPipeline  │
│                 │  │                  │  │ CRegressionDetector  │
│ CTesterData     │  │ CBehavioral      │  │ CValidationReport    │
│ Source          │  │ MetricsCollector │  │ Composer             │
└─────────────────┘  └──────────────────┘  └──────────────────────┘
```

## Dependency Graph

```
ValidationLab.mqh
├── ValidationTypes.mqh
│   └── OptimizationTypes.mqh (StrategyReport)
├── IValidationDataSource.mqh (interface)
├── TesterDataSource.mqh
│   ├── IValidationDataSource.mqh
│   └── BehavioralMetricsCollector.mqh
│       ├── ValidationEventBus.mqh
│       └── ValidationTypes.mqh
├── WalkForwardPipeline.mqh
│   ├── WalkForwardScheduler.mqh
│   │   └── WalkForwardSchedule.mqh
│   │       └── WalkForwardTypes.mqh
│   │           ├── OptimizationTypes.mqh
│   │           └── ValidationTypes.mqh
│   └── ValidationLab.mqh (for per-window execution)
├── MonteCarloPipeline.mqh
│   ├── MonteCarloSimulator.mqh
│   │   ├── MonteCarloTypes.mqh
│   │   └── OptimizationTypes.mqh
│   └── ValidationTypes.mqh
├── RegressionDetector.mqh
│   ├── RegressionTypes.mqh
│   └── ValidationTypes.mqh
└── ValidationReportComposer.mqh
    ├── ReportTypes.mqh
    ├── WalkForwardTypes.mqh
    ├── MonteCarloTypes.mqh
    └── RegressionTypes.mqh
```

## Data Flow

```
┌──────────────┐     ValidationRequest     ┌──────────────────┐
│  Caller      │ ─────────────────────────► │  CValidationLab  │
│  (EA/Script) │                            │  (Orchestrator)  │
│              │ ◄───────────────────────── │                  │
└──────────────┘     ValidationResult       └───────┬──────────┘
                                                    │
              ┌──────────────────────────────────────┼──────────────────────┐
              │              Execute Phase            │                      │
              ▼                                       ▼                      ▼
┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
│  CTesterDataSource  │  │ CWalkForwardPipeline│  │ CMonteCarloPipeline │
│                     │  │                     │  │                     │
│  Collects trade     │  │ 1. Schedule windows │  │ 1. Load trades      │
│  data from tester   │  │ 2. For each window: │  │ 2. Perturb order    │
│  framework          │  │    Train → Test     │  │ 3. Aggregate stats  │
│                     │  │ 3. Aggregate results│  │ 4. Compare vs orig  │
└─────────────────────┘  └─────────────────────┘  └─────────────────────┘
                                                    ┌─────────────────────┐
                                                    │ CRegressionDetector │
                                                    │                     │
                                                    │ 1. Compare baseline │
                                                    │    vs current       │
                                                    │ 2. Per-dimension    │
                                                    │    pass/warn/fail   │
                                                    └─────────────────────┘

Summarize Phase:
                    ┌─────────────────────────────────────┐
                    │     CValidationReportComposer        │
                    │                                     │
                    │  WalkForwardSummary + MonteCarlo     │
                    │  Summary + RegressionSummary         │
                    │  → ValidationReport (formattedText)  │
                    └─────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| `CValidationLab` | Top-level orchestrator. Manages lifecycle, coordinates data collection, routes execution requests, produces `ValidationResult`. |
| `IValidationDataSource` | Interface for pluggable data sources. `Prepare()`, `Finalize()`, `Shutdown()`. |
| `CTesterDataSource` | Default data source. Reads from MT5 Strategy Tester framework. Integrates behavioral collector. |
| `CValidationEventBus` | Pub-sub event system. Distributes `ValidationEventData` to subscribed handlers. |
| `CBehavioralMetricsCollector` | Subscribes to trade events. Computes win rates, BOS/OB/FVG accuracy, session statistics, duration metrics. |
| `CWalkForwardScheduler` | Generates window schedules from config. Supports Rolling, Expanding, Anchored modes. Validates constraints (min train/test days). |
| `CWalkForwardPipeline` | Executes walk-forward validation. Iterates windows, runs per-window backtests, aggregates results into `WalkForwardSummary`. |
| `CMonteCarloSimulator` | Runs individual Monte Carlo simulations with configurable perturbation modes. |
| `CMonteCarloPipeline` | Orchestrates full Monte Carlo pass. Loads source trades, runs `N` simulations, computes statistics, produces `MonteCarloSummary`. |
| `CRegressionDetector` | Compares two `ValidationResult` instances across 11 metric dimensions. Applies configurable thresholds. Produces `RegressionSummary`. |
| `CValidationReportComposer` | Merges all validation phases into a single `ValidationReport` with formatted plain-text output. |

## Lifecycle: Initialize → Execute → Summarize → Report

```
┌──────────────────────────────────────────────────────────────────────┐
│ INITIALIZE                                                          │
│                                                                      │
│  CValidationLab::Init()                                              │
│    ├── CTesterDataSource::Init()                                     │
│    ├── CValidationEventBus::Init()                                   │
│    └── CBehavioralMetricsCollector::Init(bus)                         │
└──────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│ EXECUTE                                                             │
│                                                                      │
│  1. CValidationLab::StartRun(request)                                │
│      ├── CTesterDataSource::Prepare(request)                         │
│      └── Strategy runs in MT5 Tester                                 │
│                                                                      │
│  2. Trade Events occur → CValidationEventBus::Publish()             │
│      └── CBehavioralMetricsCollector::OnEvent()                      │
│                                                                      │
│  3. CValidationLab::EndRun(result)                                   │
│      └── CTesterDataSource::Finalize(result)                         │
└──────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│ SUMMARIZE                                                           │
│                                                                      │
│  (Optional) WalkForward:                                             │
│    CWalkForwardPipeline::Execute(schedule, summary)                  │
│                                                                      │
│  (Optional) Monte Carlo:                                             │
│    CMonteCarloPipeline::Execute(source, config, summary)             │
│                                                                      │
│  (Optional) Regression:                                              │
│    CRegressionDetector::Execute(baseline, current, summary)          │
└──────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│ REPORT                                                              │
│                                                                      │
│  CValidationReportComposer::Compose(vr, wf, mc, reg, report)        │
│    → report.formattedText contains complete plain-text output       │
└──────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│ SHUTDOWN                                                            │
│                                                                      │
│  CValidationLab::Shutdown()                                          │
│    ├── CBehavioralMetricsCollector::Shutdown()                       │
│    ├── CValidationEventBus::Shutdown()                               │
│    └── CTesterDataSource::Shutdown()                                 │
└──────────────────────────────────────────────────────────────────────┘
```

## Extension Points

The Validation Lab is designed for modular extension. Future validation modules should follow these patterns:

| Extension Point | How to Add |
|----------------|------------|
| New data source | Implement `IValidationDataSource`. Register with `CValidationLab` via `SetDataSource()`. |
| New event type | Add value to `ENUM_VALIDATION_EVENT_TYPE`. Create handler extending `CValidationEventHandler`. Subscribe via `CValidationEventBus::Subscribe()`. |
| New validation phase | Create pipeline class with `Execute(...)` method returning a typed summary struct. Integrate into `ValidationReport` by adding a `has*`/`summary*` pair in `ReportTypes.mqh`. Add composition in `CValidationReportComposer`. |
| New regression dimension | Append value to `ENUM_REGRESSION_DIMENSION`. Add threshold handling in `CRegressionDetector`. |
| New Monte Carlo perturbation | Append value to `ENUM_PERTURBATION_MODE`. Implement perturbation logic in `CMonteCarloSimulator`. |

## Test and Benchmark Integration

```
Tests/TestRunner.mq5           → 152 regression tests (Script)
benchmarks/BenchmarkRunner.mq5  → 39 benchmarks → baseline_v2.7.txt
```

Both are standalone Scripts that exercise the Validation Lab modules directly without requiring the MT5 Strategy Tester.

## Performance Baseline

The canonical baseline `baseline_v2.7.txt` is generated by `BenchmarkRunner.mq5` and written to the MT5 `Files/` directory. It contains timing measurements for:

- WalkForward scheduler (12 configurations)
- Monte Carlo simulation (20 configurations)
- Regression detection (4 configurations)
- Report composition (3 configurations)
