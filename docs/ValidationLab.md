# Validation Lab

## Purpose

The Validation Lab is a subsystem for quantitative strategy validation in MetaTrader 5.
It provides walk-forward analysis, Monte Carlo simulation, regression detection between strategy versions, and comprehensive reporting — all within the MQL5 environment.

## Module Overview

| Module | File | Description |
|--------|------|-------------|
| Validation Lab | `Validation/ValidationLab.mqh` | Top-level orchestrator |
| Data Source | `Validation/IValidationDataSource.mqh` | Pluggable data source interface |
| Tester Data Source | `Validation/TesterDataSource.mqh` | MT5 Tester integration |
| Event Bus | `Validation/ValidationEventBus.mqh` | Pub-sub event distribution |
| Behavioral Metrics | `Validation/BehavioralMetricsCollector.mqh` | Trade behavior analysis |
| Walk Forward Scheduler | `Validation/WalkForwardScheduler.mqh` | Window schedule generation |
| Walk Forward Pipeline | `Validation/WalkForwardPipeline.mqh` | Walk-forward execution |
| Monte Carlo Simulator | `Validation/MonteCarloSimulator.mqh` | Statistical simulation |
| Monte Carlo Pipeline | `Validation/MonteCarloPipeline.mqh` | MC orchestration |
| Regression Detector | `Validation/RegressionDetector.mqh` | Cross-version comparison |
| Report Composer | `Validation/ValidationReportComposer.mqh` | Composite report generation |

## Event Flow

1. The EA or Script creates `CValidationLab` and calls `Init()`.
2. `StartRun(ValidationRequest)` begins a validation session.
3. During the MT5 backtest, `CTesterDataSource` captures trade outcomes.
4. On each trade close, `CValidationEventBus` publishes a `ValidationEventData` event.
5. `CBehavioralMetricsCollector` receives events and updates running metrics.
6. `EndRun(ValidationResult)` finalizes the session, returning the core result.
7. Optional phases execute against the `ValidationResult`:
   - **Walk Forward** — schedules and runs windowed backtests
   - **Monte Carlo** — simulates random trade sequences
   - **Regression** — compares against a baseline result
8. `CValidationReportComposer::Compose()` aggregates all phases into a `ValidationReport`.

## Data Sources

The Validation Lab receives trade data through the `IValidationDataSource` interface:

- **`CTesterDataSource`** (default) — hooks into the MT5 Strategy Tester's `OnTester()` and `OnTesterPass()` callbacks to collect trade outcomes. Uses `CStatisticsReporter` for standard metrics and `CBehavioralMetricsCollector` for behavioral analysis.

New data sources can be added by implementing `IValidationDataSource` and registering with `CValidationLab::SetDataSource()`.

## Walk Forward Pipeline

The walk-forward pipeline (`CWalkForwardPipeline`) tests strategy robustness across multiple time windows.

### Scheduling

`CWalkForwardScheduler` generates a set of windows from a `WalkForwardScheduleConfig`:

- **`overallStart` / `overallEnd`** — the total period to cover
- **`windowDays`** — length of each window (train + test)
- **`stepDays`** — gap between successive window starts
- **`trainRatio`** — split of each window into train (first N%) and test (remaining)
- **`minTrainDays` / `minTestDays`** — minimum days required for validity

### Modes

| Mode | Behavior |
|------|----------|
| **Rolling** (`WF_ROLLING`) | Fixed window size. Both train start and test end advance by `stepDays`. |
| **Expanding** (`WF_EXPANDING`) | Train start remains fixed at `overallStart`, test end advances by `stepDays`. |
| **Anchored** (`WF_ANCHORED`) | Train start remains fixed, test end advances — but window size grows. |

### Execution

For each window:
1. The strategy is run on the training period.
2. The resulting parameters are applied to the test (out-of-sample) period.
3. Results are recorded in `WalkForwardWindowResult`.
4. Aggregate counts (`totalWindows`, `validWindows`, `scheduleFailures`, `executionFailures`) are compiled into `WalkForwardSummary`.

## Monte Carlo Pipeline

The Monte Carlo pipeline (`CMonteCarloPipeline`) assesses the statistical significance of a strategy's performance.

### Process

1. Load trade outcomes from a source `ValidationResult`.
2. For each iteration, randomly permute the trade order (perturbation mode: `PERTURB_TRADE_ORDER`).
3. Compute aggregate metrics for each permutation.
4. Compare the simulated distribution against the original strategy profit.
5. Compute `MonteCarloStatistics` (mean, median, std dev, percentiles, probability of loss).

### Statistical Significance

The `probabilityOfLoss` field indicates the fraction of simulated runs that resulted in a net loss. A low probability of loss suggests the strategy's profitability is not merely an artifact of trade ordering.

## Regression Detection

`CRegressionDetector` compares two `ValidationResult` instances across 11 metric dimensions to detect performance regressions between strategy versions.

### Dimensions

Profit Factor, Sharpe Ratio, Sortino Ratio, Calmar Ratio, Net Profit, Max Drawdown, Win Rate, Expectancy, Total Trades, Avg R:R, Recovery Factor.

### Thresholds

Each dimension has configurable `warnPercent` and `failPercent` thresholds, plus a `higherIsBetter` flag. The comparison produces one of four statuses: `PASS`, `WARN`, `FAIL`, or `INSUFFICIENT_DATA`.

### Direction

The `ENUM_CHANGE_DIRECTION` enum captures whether a change is `CHANGE_IMPROVED`, `CHANGE_DEGRADED`, or `CHANGE_UNCHANGED`.

## Report Generation

`CValidationReportComposer` merges all validation phases into a single `ValidationReport` struct with pre-formatted plain-text output (`formattedText`). It supports four overloads of `Compose()`:

1. `Compose(ValidationResult, ValidationReport)` — core only
2. `Compose(ValidationResult, WalkForwardSummary, ValidationReport)` — core + WF
3. `Compose(ValidationResult, WalkForwardSummary, MonteCarloSummary, ValidationReport)` — core + WF + MC
4. `Compose(ValidationResult, WalkForwardSummary, MonteCarloSummary, RegressionSummary, ValidationReport)` — all phases

## Performance Characteristics

Measured by the benchmark suite (`benchmarks/BenchmarkRunner.mq5`). The canonical baseline is recorded in `baseline_v2.7.txt` (MT5 `Files/` directory).

| Benchmark Group | Configurations | Measures |
|----------------|---------------|----------|
| WalkForward Scheduler | 3 modes × 4 window sizes = 12 | Windows/sec |
| Monte Carlo | 5 iterations × 4 trade counts = 20 | Iterations/sec |
| Regression Detector | 4 metric counts | Comparisons/sec |
| Report Composer | 3 text sizes | Reports/sec |

All benchmarks run 1 warm-up + 20 measured iterations. Results include min/avg/max microseconds, standard deviation, relative standard deviation, and throughput.

## Known Limitations

- **Walk Forward**: Windows must fit within the `datetime` range of the MQL5 platform. Very large window counts may hit the scheduler's maximum window limit (200 windows).
- **Monte Carlo**: Currently supports only trade-order perturbation. Additional perturbation modes (e.g., randomized exit prices) are planned.
- **Regression**: Requires two separate validation runs with matching metric dimensions. Insufficient data may occur if trade counts differ significantly.
- **Report Composer**: Output is plain text only. HTML or structured formats (JSON, YAML) are not yet supported.
- **Behavioral Metrics**: Requires the MT5 Strategy Tester. Metrics are not available in live trading or Script context without a data source.

## Future Roadmap

| Area | Planned Work |
|------|-------------|
| **Additional Perturbation Modes** | Randomized entry/exit prices, slippage simulation, commission jitter |
| **Walk Forward Enhancements** | Custom window weights, multi-symbol windows, parallel execution |
| **Report Formats** | HTML output, JSON export, chart image embedding |
| **Live Validation** | Data source for live trading (MT5 `OnTrade()` events) |
| **Multi-Strategy Comparison** | Compare N strategies in a single regression pass |
| **Performance Optimization** | Cached scheduling, incremental Monte Carlo, streaming report composition |

## Files

All Validation Lab files are located under `MQL5/Experts/SuperCents_X/Validation/`.

```
Validation/
├── BehavioralMetricsCollector.mqh
├── IValidationDataSource.mqh
├── MonteCarloPipeline.mqh
├── MonteCarloSimulator.mqh
├── MonteCarloTypes.mqh
├── RegressionDetector.mqh
├── RegressionTypes.mqh
├── ReportTypes.mqh
├── TesterDataSource.mqh
├── ValidationEventBus.mqh
├── ValidationLab.mqh
├── ValidationReportComposer.mqh
├── ValidationTypes.mqh
├── WalkForwardPipeline.mqh
├── WalkForwardSchedule.mqh
├── WalkForwardScheduler.mqh
└── WalkForwardTypes.mqh
```
