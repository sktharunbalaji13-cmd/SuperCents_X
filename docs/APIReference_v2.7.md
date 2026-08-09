# Validation Lab — API Reference v2.7

## Versioning Policy

This document defines the frozen public API of the Validation Lab subsystem.
All types listed here are governed by the following rules:

- **Field renaming** — breaking. Existing field names must not change.
- **Semantic change** — breaking. The meaning of an existing field must not change.
- **Field removal** — breaking. Existing fields must not be removed.
- **Field addition** — compatible. New fields may be appended to structs.
- **Enum reordering** — breaking. Enum values must keep their numeric order.
- **Enum value removal** — breaking. Existing enum values must not be removed.
- **Enum value addition** — compatible. New values may be appended.

These contracts are versioned by the `ValidationLabVersion` number in `ValidationLabVersioning.md`.

---

## 1. `ValidationResult` — `Validation/ValidationTypes.mqh`

Top-level result of a Validation Lab execution run. Aggregates strategy metrics, behavioral data, and execution metadata.

| Field | Type | Description | Invariant |
|-------|------|-------------|-----------|
| `manifest` | `ValidationManifest` | Build and test metadata | Must be fully populated after `Finalize()` |
| `request` | `ValidationRequest` | Original validation request parameters | Read-only after `StartRun()` |
| `strategyReport` | `StrategyReport` | Standard strategy performance metrics | Populated from the Tester framework |
| `behavior` | `BehavioralMetrics` | Behavioral trade analysis metrics | Populated only if `enableBehavioralMetrics == true` |
| `archived` | `bool` | Whether the result was archived to disk | `true` only after successful archive |
| `archivePath` | `string` | Filesystem path of the archive | Valid only when `archived == true` |

### `ValidationManifest`

| Field | Type | Description |
|-------|------|-------------|
| `validationId` | `string` | Unique identifier for this validation run |
| `eaVersion` | `string` | EA version string at compile time |
| `gitCommit` | `string` | Git commit hash at compile time |
| `compileTime` | `datetime` | Binary compile timestamp |
| `parameterHash` | `string` | Hash of active strategy parameters |
| `symbolTested` | `string` | Primary backtest symbol |
| `timeframeTested` | `string` | Primary backtest timeframe |
| `spreadAvg` | `double` | Average spread during the test |
| `broker` | `string` | Broker name |
| `testerBuild` | `string` | Strategy Tester build number |
| `mt5Build` | `string` | MetaTrader 5 build number |

### `ValidationRequest`

| Field | Type | Description |
|-------|------|-------------|
| `experimentLabel` | `string` | Human-readable experiment name |
| `symbols[10]` | `string` | Symbols to validate |
| `symbolCount` | `int` | Number of active symbols |
| `timeframes[5]` | `ENUM_TIMEFRAMES` | Timeframes to validate |
| `timeframeCount` | `int` | Number of active timeframes |
| `testStart` | `datetime` | Backtest start date |
| `testEnd` | `datetime` | Backtest end date |
| `initialDeposit` | `double` | Initial deposit amount |
| `parameterSetId` | `string` | Parameter set identifier |
| `randomSeed` | `int` | Random seed for Monte Carlo |
| `enableBehavioralMetrics` | `bool` | Toggle behavioral tracking |

### `BehavioralMetrics`

Aggregated behavioral analysis. All double fields are `0.0` when no trades are recorded.

| Field | Type | Description |
|-------|------|-------------|
| `symbol` | `string` | Tested symbol |
| `timeframe` | `int` | Tested timeframe (ENUM_TIMEFRAMES) |
| `totalTrades` | `int` | Total number of closed trades |
| `winningTrades` | `int` | Count of winning trades |
| `losingTrades` | `int` | Count of losing trades |
| `winRate` | `double` | `winningTrades / totalTrades` |
| `tradesWithBOS` | `int` | Trades where BOS was present |
| `bosRespectedCount` | `int` | Trades where BOS was respected |
| `bosAccuracy` | `double` | `bosRespectedCount / tradesWithBOS` |
| `tradesWithOB` | `int` | Trades where order block was present |
| `obTouchedCount` | `int` | Trades where OB was touched |
| `obTouchRate` | `double` | `obTouchedCount / tradesWithOB` |
| `tradesWithFVG` | `int` | Trades where FVG was present |
| `fvgFilledCount` | `int` | Trades where FVG was filled |
| `fvgFillRate` | `double` | `fvgFilledCount / tradesWithFVG` |
| `avgEntryConfidence` | `double` | Mean entry confidence across all trades |
| `avgWinConfidence` | `double` | Mean entry confidence of winning trades |
| `avgLossConfidence` | `double` | Mean entry confidence of losing trades |
| `asianTrades` | `int` | Trades during Asian session |
| `asianWinRate` | `double` | Win rate during Asian session |
| `londonTrades` | `int` | Trades during London session |
| `londonWinRate` | `double` | Win rate during London session |
| `nyTrades` | `int` | Trades during New York session |
| `nyWinRate` | `double` | Win rate during New York session |
| `avgDurationSeconds` | `double` | Mean trade duration in seconds |
| `avgWinDurationSeconds` | `double` | Mean winning trade duration |
| `avgLossDurationSeconds` | `double` | Mean losing trade duration |

---

## 2. `WalkForwardSummary` — `Validation/WalkForwardTypes.mqh`

Aggregated result of a walk-forward validation pass.

| Field | Type | Description | Invariant |
|-------|------|-------------|-----------|
| `experimentLabel` | `string` | Label from pipeline execution | Matches the source ValidationResult label |
| `completedSuccessfully` | `bool` | `true` if all windows completed without pipeline error | Does not imply all windows passed |
| `results[]` | `WalkForwardWindowResult` | Per-window execution results | Length equals `totalWindows` |
| `totalWindows` | `int` | Number of windows scheduled | Equals `ArraySize(results)` |
| `validWindows` | `int` | Windows with status `WINDOW_PASS` | `<= totalWindows` |
| `scheduleFailures` | `int` | Windows with status `WINDOW_FAIL_SCHEDULE` | `<= totalWindows` |
| `executionFailures` | `int` | Windows with status `WINDOW_FAIL_EXECUTION` | `<= totalWindows` |
| `started` | `datetime` | Pipeline start timestamp | `<= completed` |
| `completed` | `datetime` | Pipeline completion timestamp | `>= started` |

### `WfExecutionWindow`

| Field | Type | Description |
|-------|------|-------------|
| `windowIndex` | `int` | Zero-based window index |
| `windowId` | `string` | Human-readable window identifier |
| `trainStart` | `datetime` | Training period start |
| `trainEnd` | `datetime` | Training period end |
| `testStart` | `datetime` | Testing (out-of-sample) period start |
| `testEnd` | `datetime` | Testing period end |
| `symbol` | `string` | Symbol for this window |
| `timeframe` | `ENUM_TIMEFRAMES` | Timeframe for this window |
| `parameterSetId` | `string` | Parameter set used for this window |

### `WalkForwardWindowResult`

| Field | Type | Description |
|-------|------|-------------|
| `window` | `WfExecutionWindow` | Window definition |
| `status` | `ENUM_WINDOW_STATUS` | Execution status |
| `failReason` | `string` | Human-readable failure reason |
| `result` | `ValidationResult` | Per-window validation result |
| `execStart` | `datetime` | Window execution start |
| `execEnd` | `datetime` | Window execution end |
| `execDurationMs` | `long` | Execution duration in milliseconds |

### `WalkForwardScheduleConfig`

| Field | Type | Description |
|-------|------|-------------|
| `overallStart` | `datetime` | Global validation period start |
| `overallEnd` | `datetime` | Global validation period end |
| `mode` | `ENUM_WALK_FORWARD_MODE` | Rolling, Expanding, or Anchored |
| `windowDays` | `int` | Duration of each window in days |
| `stepDays` | `int` | Step between window starts in days |
| `trainRatio` | `double` | Fraction of window used for training (remainder is test) |
| `minTrainDays` | `int` | Minimum training days required |
| `minTestDays` | `int` | Minimum testing days required |

### `ENUM_WALK_FORWARD_MODE`

| Value | Description |
|-------|-------------|
| `WF_ROLLING` | Fixed window size, slide by step |
| `WF_EXPANDING` | Growing train start, expanding window |
| `WF_ANCHORED` | Fixed train start, sliding test end |

### `ENUM_WINDOW_STATUS`

| Value | Description |
|-------|-------------|
| `WINDOW_PENDING` | Not yet executed |
| `WINDOW_PASS` | Window completed successfully |
| `WINDOW_FAIL_SCHEDULE` | Window skipped due to scheduling constraints |
| `WINDOW_FAIL_EXECUTION` | Window failed during backtest execution |

---

## 3. `MonteCarloSummary` — `Validation/MonteCarloTypes.mqh`

Aggregated result of a Monte Carlo simulation pass.

| Field | Type | Description | Invariant |
|-------|------|-------------|-----------|
| `experimentLabel` | `string` | Label from pipeline execution | Matches source validation |
| `sourceValidationId` | `string` | Validation ID that provided the trade data | Must refer to a completed ValidationResult |
| `config` | `MonteCarloConfig` | Simulation configuration used | Set before `Execute()` |
| `runs[]` | `MonteCarloRun` | Individual simulation runs | Length equals `completedRuns` |
| `totalRuns` | `int` | Total iterations requested | From `config.iterations` |
| `completedRuns` | `int` | Iterations that completed | `<= totalRuns` |
| `statistics` | `MonteCarloStatistics` | Aggregated statistics | Computed from all completed runs |
| `originalProfit` | `double` | Original strategy profit | From source ValidationResult |
| `started` | `datetime` | Simulation start |
| `completed` | `datetime` | Simulation end |
| `completedSuccessfully` | `bool` | `true` if pipeline completed without error |

### `MonteCarloConfig`

| Field | Type | Description |
|-------|------|-------------|
| `configVersion` | `int` | Schema version (currently 1) |
| `experimentId` | `string` | Experiment identifier |
| `iterations` | `int` | Number of simulation iterations |
| `randomSeed` | `int` | Random seed for reproducibility |
| `modes[4]` | `ENUM_PERTURBATION_MODE` | Active perturbation modes |
| `modeCount` | `int` | Number of active modes |
| `confidenceLevel` | `double` | Confidence level for significance testing |
| `perturbationDescription` | `string` | Description of perturbation applied |
| `perturbationMagnitude` | `double` | Magnitude of perturbation |

### `MonteCarloStatistics`

| Field | Type | Description |
|-------|------|-------------|
| `meanProfit` | `double` | Mean profit across all runs |
| `medianProfit` | `double` | Median profit across all runs |
| `stdDevProfit` | `double` | Standard deviation of profits |
| `p95Profit` | `double` | 95th percentile profit |
| `p99Profit` | `double` | 99th percentile profit |
| `probabilityOfLoss` | `double` | Fraction of runs with negative profit |
| `isSignificant` | `bool` | Whether result is statistically significant |
| `sufficientIterations` | `bool` | Whether enough iterations were run |
| `usedIterations` | `int` | Actual iterations used for statistics |

### `ENUM_PERTURBATION_MODE`

| Value | Description |
|-------|-------------|
| `PERTURB_TRADE_ORDER` | Randomly reorder trade sequence |

### `ENUM_RANDOM_ENGINE`

| Value | Description |
|-------|-------------|
| `RNG_MQL5_DEFAULT` | MQL5 built-in random generator |

---

## 4. `RegressionSummary` — `Validation/RegressionTypes.mqh`

Aggregated result of a regression detection pass comparing two validation runs.

| Field | Type | Description | Invariant |
|-------|------|-------------|-----------|
| `experimentLabel` | `string` | Label from pipeline execution |
| `baselineValidationId` | `string` | Validation ID used as baseline | Must refer to a completed ValidationResult |
| `currentValidationId` | `string` | Validation ID being compared | Must refer to a completed ValidationResult |
| `config` | `RegressionConfig` | Threshold configuration | Determines pass/warn/fail boundaries |
| `findings[]` | `RegressionFinding` | Per-dimension comparison results | Length equals number of dimensions checked |
| `totalChecks` | `int` | Total comparisons performed |
| `passedChecks` | `int` | Comparisons that passed |
| `warnedChecks` | `int` | Comparisons that triggered warning |
| `failedChecks` | `int` | Comparisons that failed |
| `insufficientChecks` | `int` | Comparisons with insufficient data |
| `compared` | `datetime` | Comparison timestamp |
| `completedSuccessfully` | `bool` | `true` if detection completed without error |

### `ENUM_REGRESSION_DIMENSION`

| Value | Description |
|-------|-------------|
| `REG_DIM_PROFIT_FACTOR` | Gross profit / gross loss |
| `REG_DIM_SHARPE_RATIO` | Risk-adjusted return |
| `REG_DIM_SORTINO_RATIO` | Downside-risk-adjusted return |
| `REG_DIM_CALMAR_RATIO` | Return / max drawdown |
| `REG_DIM_NET_PROFIT` | Total net profit |
| `REG_DIM_MAX_DRAWDOWN` | Maximum peak-to-trough decline |
| `REG_DIM_WIN_RATE` | Winning trades / total trades |
| `REG_DIM_EXPECTANCY` | Average profit per trade |
| `REG_DIM_TOTAL_TRADES` | Total number of trades |
| `REG_DIM_AVG_RR` | Average risk-reward ratio |
| `REG_DIM_RECOVERY_FACTOR` | Net profit / max drawdown |

### `ENUM_REGRESSION_STATUS`

| Value | Description |
|-------|-------------|
| `REGRESSION_PASS` | Within acceptable range |
| `REGRESSION_WARN` | Exceeded warning threshold |
| `REGRESSION_FAIL` | Exceeded failure threshold |
| `REGRESSION_INSUFFICIENT_DATA` | Cannot compare (data missing) |

### `ENUM_CHANGE_DIRECTION`

| Value | Description |
|-------|-------------|
| `CHANGE_IMPROVED` | Metric moved in favorable direction |
| `CHANGE_DEGRADED` | Metric moved in unfavorable direction |
| `CHANGE_UNCHANGED` | No meaningful change |

### `RegressionConfig`

| Field | Type | Description |
|-------|------|-------------|
| `configVersion` | `int` | Schema version (currently 1) |
| `thresholds[]` | `RegressionThreshold` | Per-dimension thresholds |
| `thresholdCount` | `int` | Number of active thresholds |

### `RegressionThreshold`

| Field | Type | Description |
|-------|------|-------------|
| `dimension` | `ENUM_REGRESSION_DIMENSION` | Metric dimension |
| `warnPercent` | `double` | Percent change triggering warning |
| `failPercent` | `double` | Percent change triggering failure |
| `higherIsBetter` | `bool` | Whether higher values are favorable |

### `RegressionFinding`

| Field | Type | Description |
|-------|------|-------------|
| `dimension` | `ENUM_REGRESSION_DIMENSION` | Metric dimension compared |
| `status` | `ENUM_REGRESSION_STATUS` | Comparison result status |
| `direction` | `ENUM_CHANGE_DIRECTION` | Direction of change |
| `dimensionLabel` | `string` | Human-readable dimension name |
| `baselineValue` | `double` | Baseline metric value |
| `currentValue` | `double` | Current metric value |
| `delta` | `double` | Absolute difference |
| `deltaPercent` | `double` | Percentage change |
| `warnThreshold` | `double` | Warning threshold used |
| `failThreshold` | `double` | Failure threshold used |
| `pctChangeDefined` | `bool` | Whether percentage change is meaningful |
| `message` | `string` | Human-readable result description |

---

## 5. `ValidationReport` — `Validation/ReportTypes.mqh`

Composite report aggregating all validation phases into a single document.

| Field | Type | Description | Invariant |
|-------|------|-------------|-----------|
| `title` | `string` | Report title |
| `generatedAt` | `datetime` | Report generation timestamp |
| `eaVersion` | `string` | EA version at generation time |
| `gitCommit` | `string` | Git commit at generation time |
| `validation` | `ValidationResult` | Core validation result | Always populated |
| `hasWalkForward` | `bool` | Whether WF data is included |
| `walkForward` | `WalkForwardSummary` | Walk-forward results | Valid only if `hasWalkForward == true` |
| `hasMonteCarlo` | `bool` | Whether MC data is included |
| `monteCarlo` | `MonteCarloSummary` | Monte Carlo results | Valid only if `hasMonteCarlo == true` |
| `hasRegression` | `bool` | Whether regression data is included |
| `regression` | `RegressionSummary` | Regression results | Valid only if `hasRegression == true` |
| `formattedText` | `string` | Pre-formatted plain-text report | Populated by `Compose()` |

---

## Enum Summary

| Enum | File | Frozen Values |
|------|------|---------------|
| `ENUM_WALK_FORWARD_MODE` | `WalkForwardTypes.mqh` | `WF_ROLLING`, `WF_EXPANDING`, `WF_ANCHORED` |
| `ENUM_WINDOW_STATUS` | `WalkForwardTypes.mqh` | `WINDOW_PENDING`, `WINDOW_PASS`, `WINDOW_FAIL_SCHEDULE`, `WINDOW_FAIL_EXECUTION` |
| `ENUM_PERTURBATION_MODE` | `MonteCarloTypes.mqh` | `PERTURB_TRADE_ORDER` |
| `ENUM_RANDOM_ENGINE` | `MonteCarloTypes.mqh` | `RNG_MQL5_DEFAULT` |
| `ENUM_REGRESSION_DIMENSION` | `RegressionTypes.mqh` | 11 metrics (see above) |
| `ENUM_REGRESSION_STATUS` | `RegressionTypes.mqh` | `REGRESSION_PASS`, `REGRESSION_WARN`, `REGRESSION_FAIL`, `REGRESSION_INSUFFICIENT_DATA` |
| `ENUM_CHANGE_DIRECTION` | `RegressionTypes.mqh` | `CHANGE_IMPROVED`, `CHANGE_DEGRADED`, `CHANGE_UNCHANGED` |
| `ENUM_VALIDATION_EVENT_TYPE` | `ValidationTypes.mqh` | `VALIDATION_EVENT_TRADE_CLOSED` |

---

*This document is the canonical API reference for the Validation Lab subsystem v2.7. All changes to the types listed here must follow the versioning policy defined in `ValidationLabVersioning.md`.*
