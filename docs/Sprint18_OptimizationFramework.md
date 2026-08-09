# Sprint 18.0 — Optimization & Validation Framework

**Target Version:** v2.0-optimization-framework

---

## Architectural Charter

The Optimization Framework is a passive research layer.

It consumes immutable outputs from the frozen trading platform and produces reproducible evidence.

It shall never create, modify, suppress, reorder, or influence any trading decision.

If the entire `Optimization/` directory is removed from the project, the trading platform shall produce identical decisions.

**Sprint 18 measures the platform. It does not change the platform.**

---

## Design Invariants

### Invariant 1 — Direction of Control

```
Trading Platform
        |
        v
Runtime Events
        |
        v
Optimization
        |
        v
Reports
```

Never the reverse.

### Invariant 2 — Frozen Trading Platform

The Optimization Framework targets a specific frozen platform version.
The baseline is **v1.9-portfolio-risk**. Future engine revisions require explicit re-validation.
No optimization result may claim validity against an untested platform version.

The following directories are **read-only** during Sprint 18:

| Directory | Role |
|-----------|------|
| `Structure/` | Market structure detectors |
| `Confluence/` | Signal aggregation & scoring |
| `Entry/` | Decision, planning, risk, position lifecycle |
| `Trading/` | Order execution & validation |
| `Risk/` | Per-symbol risk management |
| `Portfolio/` | Multi-symbol orchestration & portfolio risk |
| `Monitoring/` | Event bus, metrics, health |

No behavioral modifications. Only observation.

### Invariant 3 — Reproducibility

Running the same experiment twice with:

- identical data
- identical parameters
- identical platform version

must produce identical reports.

### Invariant 4 — Removability

Deleting the entire `Optimization/` directory must not change:

- compiled trading behavior
- execution path
- portfolio decisions
- runtime state transitions

Only research capabilities disappear.

---

## System Overview

The optimization layer wraps the frozen trading platform in a validation harness.

```
+-----------------------------------------------------+
|                  Experiment Runner                   |
|  +-----------+  +----------+  +------------------+  |
|  | Parameter  |  | Walk-    |  | Strategy         |  |
|  | Manager    |  | Forward  |  | Analytics        |  |
|  |            |  | Runner   |  |                  |  |
|  +-----------+  +----------+  +------------------+  |
|  +------------------+  +-------------------------+  |
|  | Robustness       |  | Experiment Manifest     |  |
|  | Validator        |  | & Report Generator      |  |
|  +------------------+  +-------------------------+  |
+-----------------------------------------------------+
        |            |            |            |
        |   reads    |   reads    |   reads    |
        v            v            v            v
+-----------------------------------------------------+
|            Frozen v1.9 Trading Platform              |
|  (Engine, Portfolio, Entry, Trading, Risk, etc.)     |
+-----------------------------------------------------+
        |
        v
  Runtime Events (EventBus)
        |
        v
  Optimization Consumers
```

Every arrow is read-only. No arrow points upward.

---

## Optimization Directory Layout

```
Optimization/
    OptimizationTypes.mqh         # All shared type definitions
    ParameterManager.mqh          # Immutable parameter bundles
    WalkForwardRunner.mqh         # Walk-forward experiment executor
    StrategyAnalytics.mqh         # Performance metric calculator
    MonteCarloValidator.mqh       # Trade-sequence reshuffling
    RobustnessTester.mqh          # Sensitivity & stress tests
    ExperimentManifest.mqh        # Experiment identity & provenance
    ReportGenerator.mqh           # Deterministic report assembly
```

No subdirectories. Every module is a single `*.mqh` header (included by an optimizer harness or test script).

---

## Shared Types — `OptimizationTypes.mqh`

### ExperimentManifest

```cpp
struct ExperimentManifest
{
    string          experimentId;           // GUID-style unique ID
    string          platformVersion;        // e.g. "v1.9-portfolio-risk"
    string          parameterSetId;         // hash or name of parameter bundle
    string          datasetId;              // data source identifier
    int             walkForwardWindows;     // number of windows
    int             randomSeed;             // 0 = deterministic default
    datetime        startTimestamp;
    datetime        endTimestamp;
    string          notes;                  // optional human-readable annotation
};
```

### Parameter Bundles

```cpp
struct StructureParameters
{
    int     swingStrength;
    int     swingLookbackBars;
    int     bosLookbackBars;
    int     chochLookbackBars;
    double  fvgMinBodySizePips;
    double  liquidityEqhTolerancePips;
    double  liquidityEqlTolerancePips;
};

struct ConfluenceParameters
{
    double  confluenceThreshold;
    double  weightTrend;
    double  weightStructure;
    double  weightMomentum;
    double  weightLiquidity;
};

struct RiskParameters
{
    double  maxRiskPerTradePercent;
    double  maxDailyRiskPercent;
    double  maxPositionSizePercent;
    double  stopBufferPips;
    double  minStopDistancePips;
};

struct PortfolioParameters
{
    double  maxPortfolioRiskPercent;
    int     maxConcurrentPositions;
    double  maxCorrelationThreshold;
    double  maxSymbolConcentrationPercent;
    double  maxCapitalUtilizationPercent;
    double  maxDailyLossPercent;
};
```

### ParameterSet (master bundle)

```cpp
struct ParameterSet
{
    string                  id;
    string                  label;
    StructureParameters     structure;
    ConfluenceParameters    confluence;
    RiskParameters          risk;
    PortfolioParameters     portfolio;
};
```

### WindowConfiguration

```cpp
struct WindowConfiguration
{
    int     totalBars;
    double  trainPercent;       // e.g. 0.70
    int     minTrainBars;
    int     minTestBars;
};
```

### WalkForwardWindow

```cpp
struct WalkForwardWindow
{
    int         windowIndex;
    datetime    trainStart;
    datetime    trainEnd;
    datetime    testStart;
    datetime    testEnd;
    int         trainBars;
    int         testBars;
};
```

### StrategyReport

```cpp
struct StrategyReport
{
    ExperimentManifest   manifest;
    WalkForwardWindow    window;

    // Core metrics
    double  totalNetProfit;
    double  grossProfit;
    double  grossLoss;
    int     totalTrades;
    int     winningTrades;
    int     losingTrades;
    double  winRate;

    // Risk-adjusted metrics
    double  expectancy;
    double  profitFactor;
    double  sharpeRatio;
    double  sortinoRatio;
    double  calmarRatio;
    double  recoveryFactor;

    // Drawdown
    double  maxDrawdownPercent;
    double  maxDrawdownValue;
    double  avgDrawdownPercent;

    // Position metrics
    double  avgHoldingTimeSeconds;
    double  avgRRAchieved;
    double  avgStopPips;
    double  avgTargetPips;

    // Exposure & utilization
    double  avgExposurePercent;
    double  maxExposurePercent;
    double  avgMarginUtilization;

    // Symbol contribution
    string  symbolContributions[];     // "SYM:profitFactor:winRate:count"

    // Robustness indicators
    double  monteCarloConfidence95;    // 95th percentile worst-case
    double  spreadSensitivitySlope;    // profit change per spread unit
    double  slippageSensitivitySlope;
};
```

---

## Module Specifications

### 1. ParameterManager — `ParameterManager.mqh`

**Purpose:** Canonical source of every configurable value. Enables versioned, labeled parameter sets.

**Interface:**

```cpp
class CParameterManager
{
public:
    bool Init(void);

    // Register a named parameter set
    bool RegisterSet(const ParameterSet &set);

    // Retrieve by ID or label
    bool GetSet(const string id, ParameterSet &out) const;
    bool GetSetByLabel(const string label, ParameterSet &out) const;

    // Number of registered sets
    int GetSetCount(void) const;

    // Default set (current platform defaults)
    ParameterSet GetDefaults(void) const;

    // Serialize/deserialize for reproducibility
    bool SaveToFile(const string filepath) const;
    bool LoadFromFile(const string filepath);
};
```

**Constraints:**
- Read-only after registration.
- No trading module references `CParameterManager`.
- Parameter sets are immutable snapshots, not live configuration.

### 2. WalkForwardRunner — `WalkForwardRunner.mqh`

**Purpose:** Execute a parameter set across rolling train/test windows.

**Interface:**

```cpp
class CWalkForwardRunner
{
public:
    bool Init(const WindowConfiguration &config);

    // Generate window partitions from total bar count
    bool GenerateWindows(int totalBars, WalkForwardWindow &windows[]);

    // Run a single window with a parameter set
    // Returns the report for that window
    bool RunWindow(const WalkForwardWindow &window,
                   const ParameterSet &params,
                   StrategyReport &outReport);

    // Run all windows for one parameter set
    bool RunAll(const ParameterSet &params,
                StrategyReport &results[]);
};
```

**Constraints:**
- Operates entirely outside the trading engine.
- Each window runs a full forward test with frozen parameters.
- Results are aggregated into `StrategyReport` arrays — no trading decisions emerge.

### 3. StrategyAnalytics — `StrategyAnalytics.mqh`

**Purpose:** Derive higher-level metrics from existing runtime events. Pure consumer — never produces events.

**Interface:**

```cpp
class CStrategyAnalytics
{
public:
    bool Init(void);

    // Ingest a completed trade record (from EventBus telemetry)
    bool RecordTrade(const TradeResultEvent &event);

    // Ingest a position lifecycle event
    bool RecordPosition(const PositionEvent &event);

    // Ingest portfolio snapshots
    bool RecordPortfolioSnapshot(const PortfolioExposure &snapshot);

    // Compute report from all recorded data
    bool GenerateReport(const ExperimentManifest &manifest,
                        StrategyReport &outReport);

    // Reset for a new experiment window
    void Reset(void);
};
```

**Constraints:**
- Never publishes events.
- Never reads trading module state directly — only consumes published telemetry.
- Deterministic: identical input sequence → identical report.

### 4. MonteCarloValidator — `MonteCarloValidator.mqh`

**Purpose:** Reshuffle trade sequences to assess result stability.

**Interface:**

```cpp
class CMonteCarloValidator
{
public:
    bool Init(int seed = 0);

    // Given a set of trade results, generate reshuffled sequences
    bool Reshuffle(const TradeResultEvent &trades[],
                   int iterations,
                   double &outPercentile95,
                   double &outPercentile99,
                   double &outMedian);

    // Assess whether original results exceed reshuffled confidence bounds
    bool IsSignificant(const TradeResultEvent &trades[],
                       int iterations,
                       double confidenceLevel,
                       bool &outSignificant);
};
```

**Constraints:**
- Modifies only in-memory trade sequences.
- Never touches trading state.
- Seeded for reproducibility.

### 5. RobustnessTester — `RobustnessTester.mqh`

**Purpose:** Assess platform stability under adverse conditions.

**Scenarios:**

| Test | Description |
|------|-------------|
| SpreadSensitivity | Vary spread by multiplier (1x, 2x, 5x) and measure profit impact |
| SlippageSensitivity | Vary slippage assumptions and measure fill impact |
| ParameterSensitivity | Perturb each parameter ±10% and measure profit variance |
| RestartRecovery | Simulate mid-run restart; verify state consistency |
| LongDuration | Execute extended run; monitor drift |

**Interface:**

```cpp
class CRobustnessTester
{
public:
    bool Init(void);

    struct SensitivityResult
    {
        string  parameter;
        double  baselineValue;
        double  perturbedValue;
        double  profitChangePercent;
        double  metricScore;
    };

    bool TestSpreadSensitivity(double multipliers[], SensitivityResult &results[]);
    bool TestSlippageSensitivity(double multipliers[], SensitivityResult &results[]);
    bool TestParameterSensitivity(const ParameterSet &baseline,
                                  double perturbationPercent,
                                  SensitivityResult &results[]);
};
```

**Constraints:**
- All tests are simulations — no real trades.
- Results are comparative, not prescriptive.
- No feedback loop into trading parameters.

### 6. ExperimentManifest — `ExperimentManifest.mqh`

**Purpose:** Uniquely identify every optimization run.

**Interface:**

```cpp
class CExperimentManifest
{
public:
    // Create a new manifest with auto-generated ID
    static ExperimentManifest Create(const string platformVersion,
                                      const string parameterSetId,
                                      const string datasetId,
                                      int walkForwardWindows,
                                      int randomSeed,
                                      const string notes = "");

    // Serialize/deserialize for archival
    static bool ToFile(const ExperimentManifest &manifest, const string filepath);
    static bool FromFile(const string filepath, ExperimentManifest &out);
};
```

**Constraints:**
- `experimentId` is a deterministic hash of all other fields (for duplicate detection).
- Every report references exactly one manifest.

### 7. ReportGenerator — `ReportGenerator.mqh`

**Purpose:** Assemble deterministic reports from experiment results.

**Interface:**

```cpp
class CReportGenerator
{
public:
    // Generate a human-readable report string
    static string FormatReport(const StrategyReport &report);

    // Generate CSV row for batch analysis
    static string ToCSV(const StrategyReport &report);

    // Generate JSON for programmatic consumption
    static bool ToJSON(const StrategyReport &report, string &outJson);

    // Aggregate multiple window reports into a cross-window summary
    static bool Aggregate(StrategyReport &windowReports[],
                          StrategyReport &outSummary);
};
```

**Constraints:**
- Pure formatting — no computation.
- All metric computation is done by `CStrategyAnalytics` before formatting.

---

## Integration Contracts

### Observability Reuse

The existing `EventBusAdapter` and `CEventBus` are the sole integration points.

| Event | Consumer | Metrics Derived |
|-------|----------|-----------------|
| `EVENT_POSITION_CLOSED` | `CStrategyAnalytics` | P&L, holding time, RR achieved, win/loss |
| `EVENT_TRADE_EXECUTED` | `CStrategyAnalytics` | fills, slippage, execution quality |
| Portfolio snapshot (polled) | `CStrategyAnalytics` | exposure, utilization, drawdown |

### Ownership Rule for Event Consumers

Optimization modules may subscribe to events but shall never retain mutable references to runtime-owned objects.

### What Optimization Does NOT Integrate With

| Module | Reason |
|--------|--------|
| `Engine.mqh` | Never touches execution lifecycle |
| `PortfolioManager.mqh` | Never reads portfolio decisions |
| `PortfolioRiskManager.mqh` | Never evaluates or overrides risk decisions |
| `TradeManager.mqh` | Never observes or modifies order flow |
| `ConfluenceEngine.mqh` | Never reads signal state |

---

## Data Flow

```
1. Experiment begins
        |
2. ExperimentManifest created
        |
3. ParameterSet loaded from ParameterManager
        |
4. WalkForwardRunner generates windows
        |
   for each window:
        |
5.   Platform runs with frozen parameters
        |
6.   Events flow through EventBus
        |
7.   StrategyAnalytics records events
        |
8.   End-of-window: GenerateReport()
        |
9. WalkForwardRunner collects window reports
        |
10. ReportGenerator formats output
        |
11. Experiment archived (manifest + reports)

Every report shall be reproducible from:
- **Experiment Manifest** (experiment ID, platform version, dataset ID, configuration IDs)
- **Parameter Bundle** (the exact `ParameterSet` used)
- **Runtime Event Archive** (the sequence of `EventBus` events from the run)
- **Platform Version** (the frozen trading platform binary)

No external state — no database connection, no live market data, no unversioned configuration —
shall be required to reconstruct a report.
```

---

## Reporting Model

### Per-Window Report

Generated at the end of each walk-forward test window.

Contains: manifest, window identity, all metrics from `StrategyReport`.

### Cross-Window Summary

Generated after all windows complete.

Contains: manifest, metric averages, metric variance, best/worst window.

### Robustness Annex

Generated by `CRobustnessTester` if robustness tests are enabled.

Contains: sensitivity slopes, confidence intervals, stability scores.

---

## Acceptance Criteria

Sprint 18 is accepted when:

1. **Determinism:** Identical inputs always produce identical `StrategyReport` output.

2. **Removability:** Deleting `Optimization/` directory produces zero behavioral change in the trading platform. Verified by:
   - Compiling with and without the directory
   - Comparing execution paths
   - Confirming identical `StateMachine` transitions

3. **Event consumption only:** `CStrategyAnalytics` and all optimization modules consume only published events — they never poll trading module state.

4. **Parameter immutability:** `CParameterManager` parameter sets cannot be modified after registration. Any attempted modification produces a compile error or runtime assertion.

5. **Experiment provenance:** Every report has a valid `ExperimentManifest` that uniquely identifies inputs, platform version, and configuration.

6. **Zero new warnings:** Compilation adds no warnings beyond the 4 pre-existing `POSITION_COMMISSION` deprecation.

---

## Regression Strategy

| Test | How |
|------|-----|
| Compilation | 0 errors, ≤4 warnings both with and without `Optimization/` |
| Single-symbol baseline | Run with default parameters; compare trade list to v1.9 baseline |
| Portfolio baseline | Run multi-symbol; compare portfolio snapshot to v1.9 baseline |
| Event flow integrity | Verify `CStrategyAnalytics` receives same events as v1.9 `CEventBus` subscribers |
| Manifest reproducibility | Generate two manifests with same inputs; verify identical `experimentId` |

---

## Freeze Criteria

The release is frozen when:

- [ ] 0 compilation errors, ≤4 warnings (both with and without `Optimization/`)
- [ ] All 4 design invariants verified in writing
- [ ] `CParameterManager` can register and retrieve parameter sets
- [ ] `CWalkForwardRunner` can generate windows and execute at least one parameter set
- [ ] `CStrategyAnalytics` can produce a `StrategyReport` from recorded events
- [ ] `CMonteCarloValidator` can reshuffle trade sequences with seeded reproducibility
- [ ] `CRobustnessTester` can run at least spread and parameter sensitivity
- [ ] `CExperimentManifest` produces deterministic IDs
- [ ] `CReportGenerator` can produce text, CSV, and JSON output
- [ ] Removal of `Optimization/` directory verified to produce identical trading behavior
- [ ] `git tag v2.0-optimization-framework` created and pushed

---

---

## Research Principles

The following principles govern the design and evolution of the Optimization Framework.
They are not implementation guidance — they are engineering philosophy.

1. **Every experiment is immutable.** Once executed, an experiment's inputs, parameters, and configuration are never modified. A new experiment is created for any change.

2. **Every report is reproducible.** Given the same manifest, parameter bundle, event archive, and platform version, the same report must be produced. Determinism is a non-negotiable property.

3. **Every metric is derived from runtime evidence.** No metric is estimated, extrapolated, or guessed. All values are computed from observed events emitted by the trading platform.

4. **Every parameter bundle is versioned.** A parameter set without an identifier and version is not a parameter set. Unversioned configuration produces unreproducible results.

5. **Every optimization result is traceable to a frozen platform version.** A report that does not reference its platform version is not a valid report. Platform upgrades invalidate previous optimization claims until re-validated.

6. **No optimization module may influence runtime decisions.** The framework observes. The runtime executes. The platform decides. This direction must never reverse.

7. **Historical experiments remain reproducible after future platform releases.** The framework preserves the ability to re-run past experiments against the platform version they were originally validated against.

---

## Out of Scope

The following are explicitly excluded from Sprint 18:

1. **No new trading features.** No new entry logic, exit logic, risk rules, portfolio rules, or signal types.

2. **No parameter tuning.** The framework evaluates parameter sets. It does not search for optimal ones. Hyperparameter optimization (grid search, genetic algorithms) is reserved for a future sprint.

3. **No machine learning.** No neural networks, regression models, or predictive algorithms.

4. **No real-time optimization.** All optimization runs are historical/simulated. The runtime engine never reads optimization output during live execution.

5. **No dashboard or UI.** Reports are text/CSV/JSON files. Visualization is out of scope.

6. **No data pipeline.** Historical data ingestion, cleaning, and management are assumed to exist externally.

7. **No changes to the frozen directories.** `Structure/`, `Confluence/`, `Entry/`, `Trading/`, `Risk/`, `Portfolio/`, `Monitoring/` are read-only.
