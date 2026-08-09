# Sprint 20 — Strategy Laboratory

## Theme

The Strategy Laboratory establishes the platform's **knowledge layer**. It consumes immutable artifacts produced by the Trading, Research, and Production platforms to compare, rank, and explain strategy performance. The Laboratory is observational and analytical — it never executes trades, modifies optimization results, changes production state, or influences runtime decisions.

Sprint 20 deliberately marks the transition from **building capabilities** to **building organizational knowledge**.

---

## Architectural Charter

### Domain Positioning

```
Trading     (decides)
    ↓
Research    (measures)
    ↓
Production  (supervises)
    ↓
Laboratory  (synthesizes evidence)
```

One-way dependencies. No upward dependency from any lower layer to the Laboratory.

### Frozen Platform

The following directories remain behaviorally frozen during Sprint 20:

- `Trading/`
- `Portfolio/`
- `Optimization/`
- `Production/`

No modifications to execution behavior. No changes to existing decision logic.

---

## Design Invariants (8)

### I1 — Frozen Platform
Trading, Portfolio, Optimization, and Production are behaviorally frozen. No modifications to execution behavior.

### I2 — Artifact-Only Inputs
Laboratory modules consume only persisted artifacts: experiment manifests, parameter bundles, strategy reports, production reports, event archives, performance metrics. No direct access to runtime-owned state.

### I3 — Deterministic Analysis
Given the same artifact set and laboratory version, every comparison, ranking, and report must be identical.

### I4 — Immutable Evidence
The Laboratory never edits historical experiments or reports. New findings produce new artifacts.

### I5 — Append-Only Knowledge
Knowledge artifacts are append-only. Existing laboratory reports shall never be modified; revisions produce new versioned artifacts.

### I6 — Statistical Transparency
Every derived metric must document: source artifacts, calculation method, assumptions. No opaque scoring.

### I7 — Removability
Deleting the entire `Laboratory/` directory must not affect trading, optimization, production, or runtime behavior. Only analytical capabilities disappear.

### I8 — One-Way Dependencies
Trading → Research → Production → Laboratory. No upward dependencies.

---

## Directory Structure

```
Laboratory/
├── LaboratoryTypes.mqh       # Shared types, enums, structs
├── StrategyCatalog.mqh        # Registry of known strategies
├── ArtifactRepository.mqh     # Immutable artifact lookup
├── ExperimentComparator.mqh   # Pairwise and group comparisons
├── RankingEngine.mqh          # Deterministic ordering
├── RobustnessAnalyzer.mqh     # Stability across regimes
├── StatisticalAnalyzer.mqh     # Confidence intervals, significance tests
├── BenchmarkEngine.mqh        # Compare against baselines
├── KnowledgeGraph.mqh         # Relationships between experiments, strategies, outcomes
├── RecommendationEngine.mqh   # Generate evidence-backed recommendations
├── ReportComposer.mqh         # Human-readable and machine-readable reports
├── LaboratoryReport.mqh       # Structured report output
└── LaboratoryManifest.mqh     # Pipeline manifest and versioning
```

---

## Shared Types (`LaboratoryTypes.mqh`)

### Enums

```cpp
enum ENUM_COMPARISON_TYPE
{
    COMPARISON_PAIRWISE = 0,
    COMPARISON_GROUP,
    COMPARISON_VS_BENCHMARK
};

enum ENUM_RANKING_METHOD
{
    RANKING_SHARPE = 0,
    RANKING_SORTINO,
    RANKING_CALMAR,
    RANKING_PROFIT_FACTOR,
    RANKING_RECOVERY_FACTOR,
    RANKING_ROBUSTNESS_SCORE,
    RANKING_COMPOSITE
};

enum ENUM_CONFIDENCE_LEVEL
{
    CONFIDENCE_NONE = 0,
    CONFIDENCE_LOW,
    CONFIDENCE_MODERATE,
    CONFIDENCE_HIGH,
    CONFIDENCE_VERY_HIGH
};

enum ENUM_BENCHMARK_CLASS
{
    BENCHMARK_BUY_AND_HOLD = 0,
    BENCHMARK_MARKET_INDEX,
    BENCHMARK_RISK_FREE_RATE,
    BENCHMARK_STRATEGY_AVERAGE,
    BENCHMARK_CUSTOM
};

enum ENUM_RECOMMENDATION_STATUS
{
    RECOMMENDATION_STRONG_BUY = 0,
    RECOMMENDATION_BUY,
    RECOMMENDATION_NEUTRAL,
    RECOMMENDATION_AVOID,
    RECOMMENDATION_STRONG_AVOID,
    RECOMMENDATION_INSUFFICIENT_DATA
};
```

### Structs

```cpp
struct LaboratoryManifest
{
    string              laboratoryRunId;
    string              laboratoryVersion;
    int                 knowledgeSchemaVersion;
    string              inputArtifactSetId;
    string              comparisonConfigurationId;
    datetime            analysisTimestamp;
    string              outputReportId;

    LaboratoryManifest(void)
        : laboratoryRunId(""), laboratoryVersion(""),
          knowledgeSchemaVersion(1), inputArtifactSetId(""),
          comparisonConfigurationId(""), analysisTimestamp(0),
          outputReportId("")
    {}
};

struct StrategyDescriptor
{
    string              strategyId;
    string              strategyName;
    string              version;
    string              description;
    ENUM_BENCHMARK_CLASS benchmarkClass;

    StrategyDescriptor(void)
        : strategyId(""), strategyName(""), version(""),
          description(""), benchmarkClass(BENCHMARK_BUY_AND_HOLD)
    {}
};

struct ExperimentReference
{
    string              experimentId;
    string              manifestPath;
    string              reportPath;
    string              parameterBundleId;
    datetime            experimentDate;

    ExperimentReference(void)
        : experimentId(""), manifestPath(""), reportPath(""),
          parameterBundleId(""), experimentDate(0)
    {}
};

struct ComparisonResult
{
    string              leftId;
    string              rightId;
    ENUM_COMPARISON_TYPE type;
    double              score;
    string              metricUsed;
    string              conclusion;

    ComparisonResult(void)
        : leftId(""), rightId(""), type(COMPARISON_PAIRWISE),
          score(0.0), metricUsed(""), conclusion("")
    {}
};

struct RankingEntry
{
    int                 rank;
    string              strategyId;
    double              score;
    ENUM_RANKING_METHOD method;
    ENUM_CONFIDENCE_LEVEL confidence;

    RankingEntry(void)
        : rank(0), strategyId(""), score(0.0),
          method(RANKING_COMPOSITE), confidence(CONFIDENCE_NONE)
    {}
};

struct RankingResult
{
    RankingEntry        entries[];
    int                 entryCount;
    ENUM_RANKING_METHOD method;
    string              description;

    RankingResult(void)
        : entryCount(0), method(RANKING_COMPOSITE), description("")
    {}
};

struct BenchmarkResult
{
    string              strategyId;
    ENUM_BENCHMARK_CLASS benchmarkClass;
    double              strategyScore;
    double              benchmarkScore;
    double              alpha;
    double              beta;
    ENUM_CONFIDENCE_LEVEL confidence;

    BenchmarkResult(void)
        : strategyId(""), benchmarkClass(BENCHMARK_BUY_AND_HOLD),
          strategyScore(0.0), benchmarkScore(0.0),
          alpha(0.0), beta(0.0), confidence(CONFIDENCE_NONE)
    {}
};

struct StatisticalSummary
{
    string              analysisId;
    string              metricName;
    double              mean;
    double              median;
    double              stdDev;
    double              min;
    double              max;
    int                 sampleCount;
    double              confidenceIntervalLower;
    double              confidenceIntervalUpper;
    ENUM_CONFIDENCE_LEVEL confidence;

    StatisticalSummary(void)
        : analysisId(""), metricName(""),
          mean(0.0), median(0.0), stdDev(0.0),
          min(0.0), max(0.0), sampleCount(0),
          confidenceIntervalLower(0.0), confidenceIntervalUpper(0.0),
          confidence(CONFIDENCE_NONE)
    {}
};

struct KnowledgeEdge
{
    string              fromId;
    string              toId;
    string              relationship;
    double              weight;

    KnowledgeEdge(void)
        : fromId(""), toId(""), relationship(""), weight(0.0)
    {}
};

struct RecommendationRecord
{
    string                      strategyId;
    ENUM_RECOMMENDATION_STATUS  status;
    string                      rationale;
    string                      evidenceRefs[];
    int                         evidenceCount;
    ENUM_CONFIDENCE_LEVEL       confidence;

    RecommendationRecord(void)
        : strategyId(""), status(RECOMMENDATION_INSUFFICIENT_DATA),
          rationale(""), evidenceCount(0), confidence(CONFIDENCE_NONE)
    {}
};
```

---

## Module Responsibilities

### 1. `LaboratoryManifest.mqh`

**Responsibility:** Pipeline manifest and versioning.

- Declares laboratory version, analysis date, artifact set digest
- Validates manifest integrity before pipeline execution
- Serialized with every output artifact for traceability

**Owns:** `LaboratoryManifest`, pipeline identity

### 2. `StrategyCatalog.mqh`

**Responsibility:** Registry of known strategies.

- Register strategies with descriptors (id, name, version, description)
- Lookup strategies by id or name
- Enumerate all registered strategies

**Owns:** `StrategyDescriptor[]`, strategy registry

### 3. `ArtifactRepository.mqh`

**Responsibility:** Immutable artifact lookup.

- Discover experiment manifests from `Optimization/` output paths
- Discover production reports from `Production/` output paths
- Load and cache artifacts by reference
- Verify artifact integrity (digest matching)
- Provide deterministic iteration over artifact sets

**Owns:** Artifact discovery, caching, integrity verification

### 4. `ExperimentComparator.mqh`

**Responsibility:** Pairwise and group comparisons.

- Compare two experiments on a specified metric
- Compare a strategy against a group (average, best, worst)
- Compute improvement/regression ratios
- Document source artifacts and calculation method for each comparison

**Owns:** `ComparisonResult[]`, comparison algorithms

### 5. `RankingEngine.mqh`

**Responsibility:** Deterministic ordering.

- Rank strategies by a specified method (Sharpe, Sortino, Calmar, Profit Factor, Recovery Factor, Robustness Score, Composite)
- Support configurable weightings for composite ranking
- Produce reproducible rankings (same input → same order)
- Attach confidence levels to each ranking entry

**Owns:** `RankingResult`, ranking algorithms

### 6. `RobustnessAnalyzer.mqh`

**Responsibility:** Stability across regimes.

- Evaluate strategy performance across different market regimes (trending, ranging, volatile)
- Compute robustness scores based on performance consistency
- Identify regime-specific strengths and weaknesses
- Compare robustness across multiple strategies

**Owns:** Robustness metrics, regime analysis

### 7. `StatisticalAnalyzer.mqh`

**Responsibility:** Confidence intervals and significance tests.

- Compute mean, median, standard deviation for any metric series
- Calculate confidence intervals at configurable levels
- Perform significance tests (e.g., whether strategy A outperforms strategy B with statistical significance)
- Document assumptions (distribution shape, sample independence, etc.)

**Owns:** `StatisticalSummary[]`, significance tests

### 8. `BenchmarkEngine.mqh`

**Responsibility:** Compare strategies against baselines.

- Define benchmark classes (buy-and-hold, market index, risk-free rate, strategy average, custom)
- Compute alpha (excess return over benchmark)
- Compute beta (correlation with benchmark)
- Support multiple benchmarks per analysis run

**Owns:** `BenchmarkResult[]`, benchmark definitions

### 9. `KnowledgeGraph.mqh`

**Responsibility:** Relationships between experiments, strategies, and outcomes.

- Build a directed graph of relationships: strategy → experiment → outcome
- Link related experiments (same strategy, different parameters)
- Link strategies to benchmarks
- Provide query methods (find all experiments for strategy X, find all comparisons involving Y)

**Owns:** `KnowledgeEdge[]`, graph traversal

### 10. `RecommendationEngine.mqh`

**Responsibility:** Generate evidence-backed recommendations.

- Accept ranking results, comparison results, benchmark results, and statistical analysis
- Produce recommendation records with rationale
- Every recommendation must reference its supporting evidence
- NEVER automatically select or activate a strategy — only recommend
- Insufficient data defaults to `RECOMMENDATION_INSUFFICIENT_DATA`

**Owns:** `RecommendationRecord[]`, recommendation logic

### 11. `ReportComposer.mqh`

**Responsibility:** Assemble structured reports from analytical outputs.

- Aggregate comparison results, rankings, benchmark results, statistical summaries, and recommendations into a coherent report
- Support human-readable (text) and machine-readable (structured data) output formats
- Include laboratory manifest in every report for traceability

**Owns:** Report assembly, output formatting

### 12. `LaboratoryReport.mqh`

**Responsibility:** Structured report output.

- Define the report data model (report header, body sections, footer)
- Serialize to file
- Load archived reports for re-analysis
- Report immutability (never modify an existing report)

**Owns:** Report serialization, archival

---

## Pipeline Lifecycle

```
                         ┌──────────────────┐
                         │  Discover         │
                         │  Artifacts        │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │  Validate         │
                         │  Manifest         │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │  Load             │
                         │  Evidence         │
                         └────────┬─────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
                    ▼             ▼             ▼
             ┌──────────┐  ┌──────────┐  ┌──────────┐
             │ Compare  │  │  Rank    │  │Analyze   │
             └────┬─────┘  └────┬─────┘  └────┬─────┘
                  │             │             │
                    └─────────────┼─────────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │  Generate         │
                         │  Knowledge Report │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │  Archive          │
                         │  Results          │
                         └──────────────────┘
```

### Phase Details

1. **Discover Artifacts** — Scan configured paths for experiment manifests, production reports, and other persisted artifacts. Build a catalog of available evidence.
2. **Validate Manifest** — Verify artifact integrity. Check that required artifacts are present and match expected schemas.
3. **Load Evidence** — Load artifacts into memory for analysis. Cache for the duration of the pipeline run.
4. **Compare** — Execute pairwise and group comparisons based on configured metrics.
5. **Rank** — Apply ranking methods to produce ordered lists.
6. **Analyze** — Compute statistical summaries. Run robustness analysis. Compare against benchmarks.
7. **Generate Knowledge Report** — Assemble all results into a structured report with full traceability.
8. **Archive Results** — Persist the report and all derived artifacts. Never overwrite previous archives.

---

## Integration Rules

### Permitted
- Read persisted artifact files (experiment manifests, reports, parameter bundles)
- Write new report files to designated output directories
- Read laboratory configuration for analysis parameters

### Explicitly Prohibited
- No runtime event subscriptions
- No trading callbacks
- No configuration modification (production, trading, optimization)
- No production supervision
- No optimization execution
- No broker interaction
- No portfolio mutation
- No runtime state queries
- No automatic strategy selection or activation
- No locks or synchronization primitives that can block runtime execution

---

## Lifecycle Integration (ProductionInit / Shutdown)

The Laboratory does **not** run during normal platform execution. It is invoked explicitly by a user or scheduled batch process.

- `Init()` — Validate laboratory configuration. Prepare artifact discovery paths.
- `Shutdown()` — Release cached artifacts. Flush pending reports.
- `ExecutePipeline()` — Run the full analysis pipeline (discover → validate → load → compare → rank → analyze → report → archive).

No integration into `Engine::OnTick()` or any runtime loop.

---

## Acceptance Criteria

| Criteria | Verification |
|----------|-------------|
| Deterministic rankings | Same artifact set + same lab version = identical ranking output |
| Reproducible comparisons | Same inputs produce identical `ComparisonResult[]` |
| Immutable historical evidence | No function modifies an existing experiment or report |
| Benchmark reproducibility | Same benchmark config + same artifacts = identical `BenchmarkResult[]` |
| Statistically documented conclusions | Every `StatisticalSummary` includes assumptions and confidence level |
| Manifest validation | Pipeline rejects malformed or incomplete artifact sets |
| Successful archival | Pipeline outputs persist without overwriting previous archives |
| Zero impact on execution | Remove `Laboratory/` directory → platform unchanged |

---

## Freeze Criteria

The Laboratory is considered frozen when:

1. All comparison algorithms are deterministic.
2. Recommendation generation is fully traceable (every recommendation links back to immutable artifacts).
3. Every conclusion links back to immutable artifacts via a complete provenance chain.
4. No locks or synchronization primitives exist that can block runtime execution.
5. Removing `Laboratory/` leaves the remaining platform unchanged.

---

## Evidence Traceability

Every recommendation must maintain a complete provenance chain:

```
Recommendation
    ↑
    references
    ↑
RankingResult ─── ComparisonResult ─── StatisticalSummary ─── BenchmarkResult
    ↑                  ↑                      ↑                     ↑
    └──────────────────┼──────────────────────┼─────────────────────┘
                       │
              ExperimentReference
                       │
              Immutable Artifact (file on disk)
```

### Traceability Rule

Each `RecommendationRecord` must reference:
- Source artifacts (experiment manifests, reports, parameter bundles)
- Statistical analysis (`StatisticalSummary`) that supports the conclusion
- Comparison results (`ComparisonResult`) that demonstrate relative performance
- Ranking results (`RankingResult`) that show position

### Verification

For any recommendation, it must be possible to walk the provenance chain back to the original immutable artifact files on disk. A recommendation with a broken or missing link in the provenance chain is considered invalid.

---

## Explicit Out of Scope

- New trading logic
- Optimization algorithm changes
- Production management
- Runtime monitoring
- Broker connectivity
- Machine learning model training
- Autonomous strategy selection (Laboratory recommends, never selects/activates)

---

## Dependency Summary

| Module | Depends On |
|--------|-----------|
| `LaboratoryTypes.mqh` | `Utils/Constants.mqh` |
| `StrategyCatalog.mqh` | `LaboratoryTypes.mqh` |
| `ArtifactRepository.mqh` | `LaboratoryTypes.mqh`, `Optimization/OptimizationTypes.mqh`, `Production/ProductionTypes.mqh` |
| `ExperimentComparator.mqh` | `LaboratoryTypes.mqh`, `ArtifactRepository.mqh` |
| `RankingEngine.mqh` | `LaboratoryTypes.mqh` |
| `RobustnessAnalyzer.mqh` | `LaboratoryTypes.mqh`, `ArtifactRepository.mqh` |
| `StatisticalAnalyzer.mqh` | `LaboratoryTypes.mqh` |
| `BenchmarkEngine.mqh` | `LaboratoryTypes.mqh`, `ArtifactRepository.mqh` |
| `KnowledgeGraph.mqh` | `LaboratoryTypes.mqh` |
| `RecommendationEngine.mqh` | `LaboratoryTypes.mqh`, `RankingEngine.mqh`, `StatisticalAnalyzer.mqh` |
| `ReportComposer.mqh` | `LaboratoryTypes.mqh`, `LaboratoryManifest.mqh`, `BenchmarkEngine.mqh`, `StatisticalAnalyzer.mqh`, `RecommendationEngine.mqh` |
| `LaboratoryReport.mqh` | `LaboratoryTypes.mqh` |
| `LaboratoryManifest.mqh` | `LaboratoryTypes.mqh` |

No module depends on any Trading, Portfolio, or runtime module.

---

## Review Checklist

### Pass 1 — Architecture
- [ ] Responsibilities are singly assigned
- [ ] Dependency direction is one-way (no upward)
- [ ] Invariants I1–I8 are enforceable
- [ ] Removability is structurally guaranteed
- [ ] Append-only knowledge artifacts (I5) are enforced

### Pass 2 — Contracts
- [ ] All shared types are defined in `LaboratoryTypes.mqh`
- [ ] Enums cover comparison types, ranking methods, confidence levels, benchmark classes, recommendation statuses
- [ ] Structs include constructors with default values
- [ ] No trading or runtime types leak into laboratory contracts
- [ ] `LaboratoryManifest` includes `knowledgeSchemaVersion` independent of `laboratoryVersion`

### Pass 3 — Integration
- [ ] Artifact flow is unidirectional (read-only from lower layers)
- [ ] No runtime event subscriptions or callbacks
- [ ] Pipeline lifecycle is explicit (discover → validate → load → compare → rank → analyze → report → archive)
- [ ] No integration into `OnTick` or runtime loops
- [ ] No locks or synchronization primitives that can block runtime execution
- [ ] Non-blocking rule is enforced in all modules

### Pass 4 — Knowledge Integrity
- [ ] All comparisons are deterministic
- [ ] Statistical summaries document assumptions and methods
- [ ] Recommendations reference immutable evidence with complete provenance chain
- [ ] Rankings are reproducible given same inputs
- [ ] No opaque scoring — every metric is traceable
- [ ] Evidence traceability rule is satisfied (every recommendation walks back to artifacts)
- [ ] Laboratory Principles (Appendix A) are verifiable

---

## Appendix A — Laboratory Principles

The Knowledge layer is governed by the following principles:

| # | Principle | Description |
|---|-----------|-------------|
| 1 | **Evidence-Based** | Knowledge derives only from immutable evidence. No analysis without artifact traceability. |
| 2 | **Reproducible** | Every comparison is reproducible. Same inputs → same outputs, unconditionally. |
| 3 | **Deterministic** | Rankings are deterministic. No randomness, no hidden state, no order dependence. |
| 4 | **Transparent** | Recommendations are evidence-backed. Every conclusion references its supporting data and calculation method. |
| 5 | **Append-Only** | Historical knowledge is append-only. Reports are never modified; revisions produce new versioned artifacts. |
| 6 | **Traceable** | Every conclusion is traceable. The provenance chain from recommendation → analysis → comparison → artifact must be walkable. |
| 7 | **Non-Interfering** | Laboratory execution never affects runtime behavior. No locks, no callbacks, no state mutation. |
| 8 | **Independently Versioned** | Knowledge schemas are versioned independently of laboratory code. Schema evolution does not imply platform version change. |
| 9 | **Removable** | Laboratory artifacts are removable without affecting lower layers. Deleting `Laboratory/` leaves Trading, Research, and Production unchanged. |
| 10 | **Recommends, Never Decides** | The Laboratory may recommend, but must never select or activate a strategy automatically. The decision remains with the operator. |

---

*End of specification.*
