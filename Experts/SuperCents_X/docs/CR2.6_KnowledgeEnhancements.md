# Capability Release 2.6 — Knowledge Enhancements

A Capability Release within the established four-layer architecture. No architectural changes.

---

## Gateway Review

### 1. Ownership

**Layer:** Knowledge Platform

**Responsibility:**
- Compare
- Rank
- Explain
- Recommend

**Not:**
- Execute
- Measure
- Operate

### 2. Contracts

Consume existing immutable artifacts only:

- `TradingEvidence` (v2.3) — structure confidence, OB quality, FVG quality, confluence, entry confidence
- `ResearchEvidence` (v2.4) — benchmark results, robustness profiles, calibration reports
- `OperationalEvidence` (v2.5) — health snapshots, performance profiles, deployment evidence
- `LaboratoryManifest` (v2.2) — experiment metadata
- `StrategyDescriptor`, `ComparisonResult`, `RankingResult`, `RecommendationRecord` (v2.2) — laboratory outputs

Produce only Knowledge artifacts. Never modify Trading, Research, or Production outputs.

### 3. Invariant Impact

**None.**

All architectural invariants (I1–I10) from Architecture.md are preserved:
- No execution logic changes
- No Research algorithm changes
- No Production observation changes
- No ownership changes
- No dependency direction changes
- No automatic strategy activation

### 4. Operational Impact

**Category:** Knowledge

No runtime behavior changes. Knowledge layer remains completely observational.

---

## Architectural Charter

Capability Release 2.6 turns accumulated evidence from Trading, Research, and Production into durable organizational knowledge. Strategy lineage, cross-version comparison, explainable recommendations, and long-term trend analysis validate that the Knowledge layer can synthesize richer artifacts while remaining completely observational.

---

## Design Invariants

| # | Invariant | Description |
|---|-----------|-------------|
| K1 | **Consume immutable artifacts only** | All inputs are read-only structs. Never modify them. |
| K2 | **Never modify Trading, Research, or Production outputs** | Knowledge produces only Knowledge artifacts. |
| K3 | **Recommendations remain evidence-backed** | Every recommendation includes supporting evidence, statistical confidence, operational context, and historical consistency. |
| K4 | **Trend analysis is deterministic** | Long-term pattern identification produces identical results for identical evidence. |
| K5 | **Every recommendation is fully traceable** | Every output references its contributing evidence (which artifacts, metrics, and version context). |
| K6 | **Historical knowledge remains append-only** | Knowledge grows monotonically. Existing lineage and trend data is never overwritten. |
| K7 | **Knowledge never activates or selects strategies** | All outputs are advisory. No strategy activation or deactivation logic. |

---

## Proposed Modules

```
Knowledge/
├── KnowledgeEvidence.mqh       # Shared knowledge evidence types
├── StrategyLineage.mqh         # Strategy evolution tracking
├── TrendAnalyzer.mqh           # Long-term pattern identification
├── RecommendationScorer.mqh    # Evidence-backed recommendation scoring
├── ExplainabilityEngine.mqh    # Explainable recommendation generation
└── KnowledgeReport.mqh         # Structured knowledge report composition
```

### 1. `KnowledgeEvidence.mqh`

**Responsibility:** Shared types for knowledge synthesis, lineage tracking, and evidence-backed observations.

**Owns:**
- `KnowledgeEvidence` struct — atomic evidence unit (source, dimension, value, rationale, artifactRef, versionContext)
- `KnowledgeObservation` struct — single knowledge finding with confidence
- `StrategyVersionNode` struct — version record in strategy lineage
- `LineageEdge` struct — parent-child relationship in evolution tree
- `TrendRecord` struct — longitudinal pattern over multiple observations
- `KnowledgeRecommendation` struct — explainable recommendation with supporting evidence
- `KnowledgeReportSection` struct — composable section for knowledge reports
- Enums for evidence type, lineage relationship, trend direction, recommendation confidence

### 2. `StrategyLineage.mqh`

**Responsibility:** Track how strategies evolve over time, creating historical context rather than isolated reports.

**Inputs:** `StrategyDescriptor`, `ComparisonResult`, `RankingResult`, laboratory reports, version tags.

**Capabilities:**
- Register a new strategy version node with descriptor, version tag, timestamp
- Link parent-child versions (e.g. Strategy A → added OB Qualification → added Confidence Engine)
- Attach performance change deltas to lineage edges
- Query lineage ancestry and descendants for a given strategy version
- Produce structured lineage report with all edges and deltas

**Output:** `StrategyVersionNode[]`, `LineageEdge[]` with performance deltas.

### 3. `TrendAnalyzer.mqh`

**Responsibility:** Identify long-term patterns across releases rather than single reports.

**Inputs:** `StructureConfidence[]`, `RobustnessProfile[]`, `ConfidenceCalibrationReport[]`, `HealthSnapshot[]`, `PerformanceProfile[]`.

**Capabilities:**
- Confidence calibration trend (is calibration improving across releases?)
- Robustness trend (is robustness increasing over time?)
- Deployment reliability trend (is operational health stable or improving?)
- Strategy stability trend (is strategy performance stable across versions?)
- Aggregate trend report with directional scores and supporting evidence

**Constraint:** Trend analysis is deterministic — identical evidence produces identical results.

**Output:** `TrendRecord[]` with per-metric trends, direction, and evidence.

### 4. `RecommendationScorer.mqh`

**Responsibility:** Produce evidence-backed, explainable recommendations that answer "why this strategy?".

**Inputs:** `RankingResult`, `BenchmarkResult[]`, `RobustnessProfile[]`, `ConfidenceCalibrationReport[]`, `TrendRecord[]`, `LineageEdge[]`.

**Capabilities:**
- Score a strategy across multiple weighted dimensions (rank position, benchmark alpha, robustness, calibration accuracy, trend direction)
- Generate `KnowledgeRecommendation` with:
  - overall score (0–100)
  - per-dimension contributions
  - supporting `KnowledgeEvidence` array
  - confidence level derived from evidence quality and quantity
  - historical consistency check against previous recommendations
- Aggregate per-dimension evidence into structured rationale strings

**Output:** `KnowledgeRecommendation` with full traceability to evidence.

### 5. `ExplainabilityEngine.mqh`

**Responsibility:** Produce explanations that answer "Why was this strategy ranked higher? Which evidence contributed? Which metrics mattered? What changed compared to previous releases?"

**Inputs:** `RankingResult`, `KnowledgeRecommendation`, `StrategyVersionNode[]`, `LineageEdge[]`, `TrendRecord[]`.

**Capabilities:**
- Explain rank position: which metrics contributed most to a strategy's rank
- Explain recommendation: which evidence items drove the recommendation status
- Explain change: what changed between two strategy versions (metric deltas, ranking shifts)
- Explain trend: how a metric has evolved across releases with per-version evidence
- Compose structured explanation with dimension-level breakdowns

**Output:** Structured explanation strings with evidence references.

### 6. `KnowledgeReport.mqh`

**Responsibility:** Compose structured knowledge reports from StrategyLineage, TrendAnalyzer, RecommendationScorer, and ExplainabilityEngine.

**Content:**
- Knowledge report header (version, timestamp, artifact references)
- Strategy lineage section (version tree with deltas)
- Trend analysis section (per-metric longitudinal trends)
- Recommendation section (scored recommendations with evidence)
- Explainability section (why answers for top recommendations)
- Evidence index (all evidence consumed, cross-referenced)

**Output:** Structured knowledge report artifact.

---

## Integration Rules

### Permitted
- Consume Trading, Research, Production, and Laboratory artifacts as read-only inputs
- Track strategy version history and evolution
- Identify long-term trends across releases
- Generate evidence-backed, explainable recommendations
- Produce structured knowledge reports

### Prohibited
- Modify Trading decisions or confidence scores
- Invoke or alter Research analysis
- Modify Production observations or diagnostics
- Activate or deactivate trading strategies
- Overwrite existing lineage or trend data (append-only)
- Introduce non-deterministic analysis

---

## Dependency Map

| Module | Depends On |
|--------|-----------|
| `KnowledgeEvidence.mqh` | `Utils/Constants.mqh` |
| `StrategyLineage.mqh` | `KnowledgeEvidence.mqh`, `Core/Logger.mqh`, `Laboratory/LaboratoryTypes.mqh` |
| `TrendAnalyzer.mqh` | `KnowledgeEvidence.mqh`, `Core/Logger.mqh`, `Trading/TradingEvidence.mqh`, `Research/ResearchEvidence.mqh`, `Production/OperationalEvidence.mqh` |
| `RecommendationScorer.mqh` | `KnowledgeEvidence.mqh`, `Core/Logger.mqh`, `Laboratory/LaboratoryTypes.mqh`, `Laboratory/RankingEngine.mqh` |
| `ExplainabilityEngine.mqh` | `KnowledgeEvidence.mqh`, `Core/Logger.mqh`, `Trading/TradingEvidence.mqh`, `Research/ResearchEvidence.mqh`, `Production/OperationalEvidence.mqh` |
| `KnowledgeReport.mqh` | `KnowledgeEvidence.mqh`, `Core/Logger.mqh`, `StrategyLineage.mqh`, `TrendAnalyzer.mqh`, `RecommendationScorer.mqh`, `ExplainabilityEngine.mqh` |

All dependencies consume existing artifacts as immutable read-only inputs. No new dependencies on Production, Research, or Trading that modify behavior.

---

## Lifecycle Integration

| Phase | Action |
|-------|--------|
| `Engine::Init()` | Initialize StrategyLineage, TrendAnalyzer, RecommendationScorer, ExplainabilityEngine. |
| `Engine::OnTick()` | None (knowledge is synthesized on demand or post-session). |
| `Engine::Shutdown()` | Flush pending knowledge reports. |

No changes to Trading, Research, or Production lifecycle.

---

## Acceptance Criteria

| Criteria | Verification |
|----------|-------------|
| Strategy lineage tracking | StrategyLineage produces version trees with performance deltas |
| Long-term trend identification | TrendAnalyzer identifies directional patterns across >=3 observation points |
| Evidence-backed recommendations | RecommendationScorer produces recommendations with full evidence chains |
| Explainable recommendations | ExplainabilityEngine produces "why" answers referencing specific evidence |
| Structured knowledge reports | KnowledgeReport composes lineage + trends + recommendations + explanations |
| Zero dependency violations | `grep -r "Knowledge/" {Trading,Research,Production,Laboratory}/` returns no violations |
| Existing layers unchanged | No modifications to Trading/, Research/, Production/, or Laboratory/ in this release |

---

## Definition of Success

The Knowledge layer demonstrates it can synthesize richer Trading, Research, and Production artifacts into better long-term insight while remaining completely observational. All four layers have now been exercised through capability evolution: Trading (v2.3), Research (v2.4), Production (v2.5), Knowledge (v2.6).

---

## Out of Scope

- Trading logic modifications
- Research analysis or algorithm changes
- Production observation changes
- Strategy activation or selection logic
- Non-deterministic analysis
- Modification of existing Laboratory outputs
- New architectural layers or layer boundary changes

---

*End of specification.*
