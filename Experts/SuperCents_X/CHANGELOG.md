# Changelog

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
