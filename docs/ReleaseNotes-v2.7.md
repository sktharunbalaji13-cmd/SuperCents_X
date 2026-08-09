# Release Notes — v2.7-validation-lab

**Date:** 2026-07-30
**Tag:** `v2.7-validation-lab`
**Binary:** `SuperCents_X.ex5`

## Overview

This release introduces the **Validation Lab** subsystem — a comprehensive quantitative strategy validation framework for MetaTrader 5. It marks the transition from active feature development to a stable, documented, and benchmarked release.

## New Subsystem: Validation Lab

The Validation Lab provides four validation phases, each accessible individually or composed into a single report:

| Phase | Description |
|-------|-------------|
| **Walk Forward** | Tests strategy robustness across rolling, expanding, and anchored time windows |
| **Monte Carlo** | Assesses statistical significance through trade-order permutation |
| **Regression Detection** | Compares strategy versions across 11 metric dimensions |
| **Report Composition** | Merges all phases into a unified plain-text report |

### New Files

**Validation Core (17 files):**
- `Validation/ValidationLab.mqh` — Orchestrator
- `Validation/ValidationTypes.mqh` — Core types, `ValidationResult`, `ValidationRequest`, `BehavioralMetrics`
- `Validation/IValidationDataSource.mqh` — Pluggable data source interface
- `Validation/TesterDataSource.mqh` — MT5 Tester integration
- `Validation/ValidationEventBus.mqh` — Pub-sub event system
- `Validation/BehavioralMetricsCollector.mqh` — Trade behavior analysis
- `Validation/WalkForwardTypes.mqh` — WF types and enums
- `Validation/WalkForwardSchedule.mqh` — Schedule struct
- `Validation/WalkForwardScheduler.mqh` — Window schedule generator
- `Validation/WalkForwardPipeline.mqh` — WF execution orchestrator
- `Validation/MonteCarloTypes.mqh` — MC types and enums
- `Validation/MonteCarloSimulator.mqh` — Statistical simulator
- `Validation/MonteCarloPipeline.mqh` — MC execution orchestrator
- `Validation/RegressionTypes.mqh` — Regression types and enums
- `Validation/RegressionDetector.mqh` — Cross-version comparison
- `Validation/ReportTypes.mqh` — Report container struct
- `Validation/ValidationReportComposer.mqh` — Report generation

**Test Framework (6 files):**
- `Tests/TestRunner.mq5` — Script entry point
- `Tests/unit/TestAssert.mqh` — Custom assertion macros
- `Tests/unit/TestWalkForward.mqh` — WF test cases
- `Tests/unit/TestMonteCarlo.mqh` — MC test cases
- `Tests/unit/TestRegression.mqh` — Regression test cases
- `Tests/unit/TestReportComposer.mqh` — Report composer test cases

**Benchmark Suite (6 files):**
- `benchmarks/BenchmarkRunner.mq5` — Script entry point
- `benchmarks/BenchmarkTypes.mqh` — Benchmark result types and output
- `benchmarks/BenchmarkWalkForward.mqh` — 12 WF scheduler benchmarks
- `benchmarks/BenchmarkMonteCarlo.mqh` — 20 MC simulation benchmarks
- `benchmarks/BenchmarkRegression.mqh` — 4 regression detector benchmarks
- `benchmarks/BenchmarkReportComposer.mqh` — 3 composer benchmarks

**Documentation (5 new files):**
- `docs/APIReference_v2.7.md` — Frozen public API specification
- `docs/ARCHITECTURE_v2.7.md` — Architecture and data flow
- `docs/ValidationLab.md` — Module documentation and usage
- `docs/ValidationLabVersioning.md` — Versioning and compatibility policy
- `docs/ReleaseNotes-v2.7.md` — This document

## Test Coverage

- **Regression Test Suite:** 152 tests, all passing
- **Benchmark Suite:** 39 benchmarks, all executing with canonical baseline

## Bug Fixes from Stabilization

| Bug | File | Description |
|-----|------|-------------|
| ArrayResize missing for schedule windows | `WalkForwardScheduler.mqh` | `schedule.windows[]` and `schedule.warnings[]` were not resized before assignment, causing runtime errors |
| ArrayResize missing for regression thresholds | `RegressionDetector.mqh` | Defense-in-depth `ArrayResize` in `Init()` to prevent out-of-bounds |
| `const &` references to array elements | Multiple files | MQL5 does not support `const &` references to struct array elements; replaced with value copies across 7 files |
| NULL check incompatibility in Script context | `MonteCarloPipeline.mqh` | `trades == NULL` check replaced with `tradeCount < 2` for Script compatibility |
| WalkForward integer overflow | `BenchmarkWalkForward.mqh` | `targetWindows * 60 * 86400` overflowed `int` at 500 windows |
| ReportComposer throughput calculation | `BenchmarkReportComposer.mqh` | `inputSize` was set to text bytes instead of operations count, producing `0.0 reports/sec` |
| Enum value typo in Monte Carlo test | `TestMonteCarlo.mqh` | `MC_PERTURB_TRADE_ORDER` → `PERTURB_TRADE_ORDER` |
| Probabilistic seed test replaced | `TestMonteCarlo.mqh` | Monte Carlo result depends on random seed; test changed from checking probability distribution to deterministic seed recording |

## API Freeze

The following public contracts are frozen at v2.7:

- `ValidationResult` (including `ValidationManifest`, `ValidationRequest`, `BehavioralMetrics`)
- `WalkForwardSummary` (including walk forward types and enums)
- `MonteCarloSummary` (including Monte Carlo types and enums)
- `RegressionSummary` (including regression types and enums)
- `ValidationReport`

All public enums are versioned contracts. See `docs/APIReference_v2.7.md` for the complete specification and `docs/ValidationLabVersioning.md` for the compatibility policy.

## Performance Baseline

The canonical performance baseline `baseline_v2.7.txt` is generated by `BenchmarkRunner.mq5` and stored in the MT5 `Files/` directory. It should be used for future regression comparisons.

## Known Limitations

See `docs/ValidationLab.md` → "Known Limitations" section for current constraints.

## Upgrading

This release is additive. No breaking changes to existing modules are introduced. Existing `SuperCents_X` EA code compiles and runs without modification.

## Future Directions

See `docs/ValidationLab.md` → "Future Roadmap" for planned enhancements.
