# Changelog

## v2.9.1-calibration-stable — 2026-08-01 — Calibration Framework + housekeeping release

### Added
- Offline calibration runner (`CalibrationRunner.mq5` + `Calibration/ExperimentRunner.mqh`) — threshold sweep, 3-stage weight search, validator ablation, promotion gate
- `CWeightOptimizer` — coarse scan (3,003 evals) → fine scan → hill climb over the 6 confluence weights (0..100 ReplayConfidence scale)
- `CThresholdOptimizer`, `CValidatorAttribution`, `CPromotionGate` (8-criteria CI gate vs locked baseline)
- Headless validation suite: `Tests/TestSuite.mqh` + `Tests/TestRunnerEA.mq5` — **415 tests**, `Sprint14_TestRunner.ini`
- Headless benchmarks: `benchmarks/Benchmarks.mqh` + `BenchmarkRunnerEA.mq5` — 61 benchmarks, frozen `Format=2` baseline with CPU/OS/build env header
- v2.9 weight inputs in `SuperCents_X.mq5` (validated sum=100) → `CEngine` → `CPortfolioManager` → `CSymbolContext` → `CConfluenceEngine::SetWeights`
- Docs: `docs/CalibrationGuide.md`, `docs/Sprint14_Calibration.md`, `docs/Architecture/v2.8-EntryEngine.md`, `docs/EntryValidationPipeline.md`

### Changed
- `ConfluenceScoreCalculator` — raw score clamped back into component results
- `TrendEvaluator` NULL-state semantics (no score on no-trend data)
- `ExperimentRunner::RunWeights` — threshold scaled to 0..100 (`minConfidence * 100`)
- `TelemetryRow` schema frozen (`@frozen v2.9`); benchmark format frozen (`@frozen v2.9.1`)

### Fixed
- Weight optimizer `ScanNeighborhood` produced invalid weights (no rebalance) — stage 2 scored nothing
- Weight optimizer `InsertRanked` compared against unscored candidates — "top 5" was the last 5 processed
- Weight-search threshold-scale mismatch (0..1 vs 0..100) — every row qualified, capping expectancy at 0.5
- 9 test-suite failures across Confluence / Telemetry / ForwardSimulator / Calibration suites → **415/415 green**

### Housekeeping
- Removed stray file, compile logs; `performance_baseline.md` v2.9.1 env record; frozen `Files/baseline_v2.9.txt`

## v2.8-confluence-engine — 2026-07-30 — Confluence Engine Evaluator Architecture

### Added
- Modular evaluator pattern (`Confluence/Evaluators/` — 7 new files)
  - `IConfluenceEvaluator` — pure virtual interface for all evaluators
  - `StructureEvaluator` — structure-type confluence scoring
  - `TrendEvaluator` — trend-type confluence scoring
  - `OrderBlockEvaluator` — order-block confluence scoring
  - `FVGEvaluator` — fair-value gap confluence scoring
  - `LiquidityEvaluator` — liquidity-type confluence scoring
  - `PremiumDiscountEvaluator` — premium/discount zone scoring
- `ConfluenceScoreCalculator` (`Confluence/ConfluenceScoreCalculator.mqh`) — weighted aggregation of component scores
- `ConfluenceLogger` (`Confluence/ConfluenceLogger.mqh`) — structured evaluation logging
- `ConfluenceWeights` (`Confluence/ConfluenceWeights.mqh`) — configurable weight struct (25/20/15/15/15/10 defaults)
- `ConfluenceTypes` (`Confluence/ConfluenceTypes.mqh`) — shared type definitions (DetectionContext, ConfluenceComponentResult, ConfluenceResult)
- Unit tests (`Tests/unit/TestConfluenceEngine.mqh` — 26 tests)
- Performance benchmarks (`benchmarks/BenchmarkConfluence.mqh` — 10 benchmarks)
- Documentation (`docs/ConfluenceEngine_v2.8.md`)

### Changed
- `CConfluenceEngine` refactored to support evaluator registration + dispatch:
  - `RegisterEvaluator(IConfluenceEvaluator*)` — registers an evaluator instance
  - `SetWeights(ConfluenceWeights&)` — sets scoring weights
  - `GetLatestConfluence()` — returns the most recent ConfluenceResult
  - `IsUsingEvaluators()` — queries whether evaluator path is active
  - `BuildDetectionContext()` — builds DetectionContext from current engine state
  - `EvaluateViaEvaluators()` — dispatches to all registered evaluators and aggregates scores
  - `BridgeConfluenceToSignal()` — converts ConfluenceResult + thresholds to ConfluenceSignal
- Legacy rule path fully preserved (no changes to scoring logic)
- `TestRunner.mq5` and `BenchmarkRunner.mq5` updated with new registrations
- All existing 152 tests and 39 benchmarks continue to pass

### Backward Compatibility
- All existing types (`ConfluenceSignal`, `RuleResult`, `TradeCandidate`, `EntrySetup`) unchanged
- Engine lifecycle (`Init()`, `Update()`, `Shutdown()`) unchanged
- No changes to Entry/Exit pipeline interfaces

---

## v2.7-validation-lab — 2026-07-30 — Validation Lab Subsystem

### Added
- Validation Lab subsystem (`Validation/` — 17 files)
  - Walk Forward validation (scheduler + pipeline)
  - Monte Carlo simulation (simulator + pipeline)
  - Regression detection (11 metric dimensions)
  - Validation reporting (composite report generation)
  - Behavioral metrics collection (BOS/OB/FVG accuracy, session analysis)
  - Event bus architecture for trade data distribution
  - Pluggable data source interface
- Regression test suite (`Tests/` — 152 tests)
- Performance benchmark suite (`benchmarks/` — 39 benchmarks)
- Documentation (`docs/` — 5 new files)
  - `APIReference_v2.7.md` — frozen public API specification
  - `ARCHITECTURE_v2.7.md` — architecture and data flow
  - `ValidationLab.md` — module documentation
  - `ValidationLabVersioning.md` — versioning and compatibility policy
  - `ReleaseNotes-v2.7.md` — release notes
- Performance baseline (`Files/baseline_v2.7.txt`)

### Changed
- Validation APIs frozen at v2.7
- `Tests/README.md` updated with regression and benchmark usage

### Fixed
- `WalkForwardScheduler.mqh`: missing `ArrayResize` for schedule windows and warnings arrays
- `RegressionDetector.mqh`: defense-in-depth `ArrayResize` in `Init()`
- Multiple files: `const &` references to struct array elements replaced with value copies (MQL5 compatibility)
- `MonteCarloPipeline.mqh`: NULL check replaced with `tradeCount < 2` for Script context
- `BenchmarkWalkForward.mqh`: integer overflow in `targetWindows * 60 * 86400` for 500-window case
- `BenchmarkReportComposer.mqh`: throughput calculation used text bytes instead of operations count
- `TestMonteCarlo.mqh`: enum value typo corrected; probabilistic seed test replaced with deterministic check

---

## v0.9.0 — 2026-07-15 — Fair Value Gap Detector & Pipeline Finalization

### Added
- Fair Value Gap Detector (`Structure/FVGDetector.mqh`)
- FVG test harness (`Sprint9_FVGTest.mq5`) with 25 tests (T1–T25)
- Diagnostic state dump helpers for determinism verification
- CI configuration (`Tests/CI/sprint9.ini`)
- PowerShell runner (`Scripts/RunSprint9.ps1`)
- State leakage detection (T24) and cycle stress test (T25)

### Changed
- Floating-point tolerance: `const double EPS = _Point * 0.1` in body and gap comparisons

### Fixed
- Body threshold boundary comparison (`body < minBody - EPS` instead of `body < minBody`)
- Gap comparison precision (`gapHigh + EPS < gapLow`, `gapHigh > gapLow + EPS`)
- Infinite recursion in `Report()` function (test harness)

### Validated
- 25/25 tests passed
- 117/117 checks passed
- Determinism verified (T15, T1 == T24)
- No state leakage (T24, T25 all cycles consistent)
- No runtime errors (0 exceptions, crashes, or violations)
- No architecture regressions
- IEEE-754 precision boundary handling (T22 passes)

### Frozen
- `Structure/FVGDetector.mqh`
- All previously frozen modules remain frozen (v0.8.0 list)

---

## v0.8.0 — 2026-07-15 — Market Structure Engine Complete

### Added
- Order Block Detector (`Structure/OrderBlockDetector.mqh`)
- Synthetic validation suite (Python, 7/7 tests)
- Full pipeline validation script (`Scripts/SuperCents_X/Sprint8_OBTest.mq5`)
- `docs/` directory with API documentation

### Changed
- `Core/Engine.mqh`: Added `open[]` array integration and OrderBlockDetector pipeline step
- `Utils/Types.mqh`: Added `OrderBlock` struct
- `Utils/Constants.mqh`: Added `MODULE_ORDER_BLOCK_DETECTOR` enum entry

### Validated
- Architecture: Clean layered design with single-responsibility modules
- Runtime: All modules initialize, update, and shut down without errors
- Determinism: Identical output for identical input data
- Algorithm: Bullish OB, Bearish OB, immediate OB, displaced index, doji skip, empty result, qualityScore
- Full pipeline: MQL5 test harness compiles and runs through all 7 pipeline stages

### Validation Status by Module
| Module | Market Replay | Synthetic | Architecture |
|---|---|---|---|
| SwingDetector | ✅ Extensive (1000s of events) | ✅ | ✅ |
| StructuralPivotEngine | ✅ Extensive | ✅ | ✅ |
| BOSDetector | ✅ Extensive | ✅ | ✅ |
| TrendState | ✅ Extensive | ✅ | ✅ |
| ProtectedPointManager | ✅ Extensive | ✅ | ✅ |
| CHOCHDetector | ⚠ Pending (0 events in test window) | ✅ | ✅ |
| OrderBlockDetector | ⚠ Pending (0 events in test window) | ✅ (7/7) | ✅ |

Note: CHOCH and OB detectors are architecturally and synthetically validated.
Natural market replay validation is pending — the selected EURUSD M15 2026.01.01–2026.01.31
window did not produce qualifying CHOCH events. This is not a detector failure.
Replay validation will be performed when a suitable market window is identified.

### Frozen
- `Utils/Types.mqh`
- `Utils/Constants.mqh`
- `Utils/Helpers.mqh`
- `Utils/MathUtils.mqh`
- `Core/Engine.mqh`
- `Core/Logger.mqh`
- `Core/Config.mqh`
- `Structure/SwingDetector.mqh`
- `Structure/StructuralPivotEngine.mqh`
- `Structure/BOSDetector.mqh`
- `Structure/TrendState.mqh`
- `Structure/ProtectedPointManager.mqh`
- `Structure/CHOCHDetector.mqh`
- `Structure/OrderBlockDetector.mqh`

### Removed
- Deprecated `SmartMoneyEA_v4` project
