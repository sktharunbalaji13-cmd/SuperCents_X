# Capability Release 2.4 — Research Enhancements

A Capability Release within the established four-layer architecture. No architectural changes.

---

## Gateway Review

### 1. Ownership

**Layer:** Research Platform

**Primary responsibility:** Improve the quality, depth, and statistical rigor of strategy evaluation using the richer Trading artifacts introduced in v2.3.

**Other layers remain unchanged:**
- Trading produces richer evidence consumed by Research.
- Production supervises research execution.
- Knowledge consumes richer research outputs.

No ownership changes. No layer boundary modifications.

### 2. Contracts

**New or extended contracts:**
- `BenchmarkResult` — deterministic benchmark comparison output
- `RobustnessProfile` — multi-dimension stability analysis
- `StatisticalSummary` — confidence intervals, effect sizes, distribution metrics
- `ConfidenceCalibrationReport` — mapping of v2.3 confidence scores to observed outcomes
- `ResearchEvidence` — structured evidence accompanying every conclusion
- `ValidationEvidence` — per-validation-step evidence chain

**Backward compatibility:** Existing Research outputs remain unchanged. New modules produce supplementary artifacts.

### 3. Invariant Impact

**None.**

All architectural invariants (I1–I10) from Architecture.md are preserved:
- No dependency direction changes
- No runtime execution changes
- No ownership changes
- No modification of Trading-produced evidence
- No cross-layer dependency introduction

### 4. Operational Impact

**Category:** Measurement

The release improves evaluation and validation only. Trading behavior is unchanged. Production supervision and Knowledge synthesis are unaffected beyond consuming richer artifacts.

---

## Architectural Charter

Capability Release 2.4 strengthens the Research Platform by producing more rigorous, reproducible, and explainable validation of trading behavior while preserving all architectural boundaries.

The release validates that capability can evolve independently within the Research layer while surrounding layers require no structural changes — the same pattern validated in v2.3, applied one layer higher.

---

## Design Invariants

| # | Invariant | Description |
|---|-----------|-------------|
| D1 | **Deterministic analysis** | All benchmark, robustness, and statistical computations are deterministic. Same inputs → same outputs. |
| D2 | **Trading evidence is immutable** | Research consumes v2.3 `DetectionEvidence` and `EntryConfidence` as read-only inputs. Never modifies them. |
| D3 | **Every conclusion references evidence** | Every `RobustnessProfile`, `BenchmarkResult`, and `StatisticalSummary` includes evidence references. |
| D4 | **Calibration is observational** | `ConfidenceCalibrator` evaluates the relationship between confidence scores and outcomes. Never feeds back into runtime confidence generation. |
| D5 | **Benchmark reproducibility** | Same benchmark configuration + same artifacts → identical `BenchmarkResult`. |
| D6 | **Backward-compatible contracts** | Existing consumers of Research outputs continue to function unmodified. |

---

## Proposed Modules

```
Research/
├── ResearchEvidence.mqh          # Shared evidence and report types
├── BenchmarkFramework.mqh        # Deterministic benchmark comparisons
├── RobustnessProfiler.mqh        # Multi-dimension stability analysis
├── StatisticalValidator.mqh      # Confidence intervals, effect sizes, significance
├── ConfidenceCalibrator.mqh      # Maps confidence scores to observed outcomes
└── EnhancedResearchReport.mqh    # Richer report composition
```

### 1. `ResearchEvidence.mqh`

**Responsibility:** Shared types for research evidence and extended reporting.

**Owns:**
- `BenchmarkResult` struct
- `RobustnessProfile` struct
- `ConfidenceCalibrationReport` struct
- `ResearchEvidence` struct
- Enums for benchmark type, stability tier, calibration status

### 2. `BenchmarkFramework.mqh`

**Responsibility:** Deterministic comparison of strategies against baselines.

**Inputs:** `StrategyReport` (existing), v2.3 `EntryConfidence` and `DetectionEvidence`.

**Comparisons:**
- Baseline strategy (fixed reference configuration)
- Previous platform versions (version-to-version delta)
- Parameter variants (within-experiment comparison)
- Market regime comparisons (trending vs. ranging vs. volatile)

**Output:** `BenchmarkResult` with supporting evidence chain.

### 3. `RobustnessProfiler.mqh`

**Responsibility:** Multi-dimension stability analysis beyond simple pass/fail.

**Inputs:** `StrategyReport[]` across windows, regimes, or parameter perturbations.

**Dimensions:**
- Market regime stability (performance consistency across market conditions)
- Volatility sensitivity (correlation between volatility and performance)
- Parameter sensitivity (performance variance under parameter perturbation)
- Temporal consistency (performance stability across time periods)
- Trade distribution stability (consistency of trade-level outcomes)

**Output:** `RobustnessProfile` with dimension-level scores and evidence.

### 4. `StatisticalValidator.mqh`

**Responsibility:** Statistical rigor for research conclusions.

**Inputs:** Performance metric series, trade-level outcomes.

**Computations:**
- Confidence intervals (configurable level: 90%/95%/99%)
- Effect sizes (Cohen's d, Hedges' g for group comparisons)
- Distribution analysis (normality assessment, skewness, kurtosis)
- Significance testing (p-values where methodologically appropriate)
- Stability metrics (coefficient of variation, rolling statistics)

**Output:** `StatisticalSummary` documenting assumptions, method, and result.

### 5. `ConfidenceCalibrator.mqh`

**Responsibility:** Evaluate how well v2.3 confidence scores correspond to observed trade outcomes.

**Inputs:** v2.3 `EntryConfidence` and `DetectionEvidence` paired with realized trade results.

**Analysis:**
- Confidence vs. win rate mapping (does higher confidence predict higher win rate?)
- Confidence vs. risk-adjusted return correlation
- Calibration curve (expected vs. observed performance across confidence tiers)
- Systematic bias detection (overconfidence, underconfidence patterns)

**Constraint:** Calibration is observational only. Never feeds back into runtime confidence generation. Research evaluates confidence — it does not generate or modify it.

**Output:** `ConfidenceCalibrationReport` with evidence chain.

### 6. `EnhancedResearchReport.mqh`

**Responsibility:** Produce richer research artifacts incorporating all new analysis.

**Content:**
- Benchmark summaries (per-comparison results)
- Robustness profiles (dimension-level scores)
- Calibration analysis (confidence-outcome mapping)
- Statistical summaries (confidence intervals, effect sizes)
- Evidence traceability index

**Output:** Structured report artifact consumable by the Knowledge layer.

---

## Integration Rules

### Permitted
- Consume v2.3 `TradingEvidence`, `DetectionEvidence`, and `EntryConfidence` as read-only inputs
- Extend validation outputs with richer evidence structs
- Generate benchmark, robustness, statistical, and calibration artifacts
- Consume existing `StrategyReport` outputs unchanged

### Prohibited
- Modify Trading-produced evidence or confidence scores
- Alter runtime Trading decisions
- Modify Production configuration or state
- Generate Knowledge recommendations
- Invoke runtime execution modules
- Modify existing `StrategyReport` structure
- Feed calibration results back into runtime confidence engines

---

## Dependency Map

| Module | Depends On |
|--------|-----------|
| `ResearchEvidence.mqh` | `Utils/Constants.mqh`, `Optimization/OptimizationTypes.mqh` |
| `BenchmarkFramework.mqh` | `ResearchEvidence.mqh`, `Optimization/StrategyAnalytics.mqh`, `Trading/TradingEvidence.mqh` |
| `RobustnessProfiler.mqh` | `ResearchEvidence.mqh`, `Optimization/OptimizationTypes.mqh` |
| `StatisticalValidator.mqh` | `ResearchEvidence.mqh` |
| `ConfidenceCalibrator.mqh` | `ResearchEvidence.mqh`, `Trading/TradingEvidence.mqh`, `Optimization/OptimizationTypes.mqh` |
| `EnhancedResearchReport.mqh` | `ResearchEvidence.mqh`, `BenchmarkFramework.mqh`, `RobustnessProfiler.mqh`, `StatisticalValidator.mqh`, `ConfidenceCalibrator.mqh` |

No module depends on `Production/` or `Laboratory/`. Trading dependencies are read-only type consumption (not runtime invocation).

---

## Lifecycle Integration

| Phase | Action |
|-------|--------|
| `Engine::Init()` | Initialize benchmark framework, profiler, validator, calibrator. |
| `Engine::OnTick()` | No runtime integration. Research runs on explicit invocation or batch trigger. |
| `Engine::Shutdown()` | Flush pending research artifacts. |

No changes to Trading, Production, or Knowledge lifecycle.

---

## Acceptance Criteria

| Criteria | Verification |
|----------|-------------|
| Enhanced benchmark comparisons | BenchmarkFramework produces deterministic multi-comparison results |
| Deterministic robustness analysis | RobustnessProfiler produces reproducible dimension-level scores |
| Reproducible statistical validation | StatisticalValidator produces identical results for identical inputs |
| Confidence calibration | ConfidenceCalibrator maps v2.3 scores to outcomes without feedback |
| Zero dependency violations | `grep -r "include.*Production\|include.*Laboratory" Research/` returns empty |
| Trading evidence unchanged | No module in Research/ modifies TradingEvidence struct contents |
| Existing Research regressions pass | All prior optimization tests pass |
| Richer artifacts for Knowledge | EnhancedResearchReport produces structured output consumable by Laboratory/ |

---

## Definition of Success

The Research layer becomes more capable by consuming richer Trading outputs while Trading, Production, and Knowledge require **no architectural modification**.

If that holds true, v2.4 validates the same pattern established by v2.3, applied one layer higher: capability evolves independently within its owning layer while the rest of the platform functions through stable contracts.

---

## Out of Scope

- New architectural layers or layer boundary changes
- Trading logic modifications (detection, confidence, execution)
- Production configuration or state changes
- Knowledge recommendation generation
- Runtime execution invocation
- Non-deterministic or probabilistic analysis
- Machine learning model training or inference
- Calibration feedback into runtime systems

---

*End of specification.*
