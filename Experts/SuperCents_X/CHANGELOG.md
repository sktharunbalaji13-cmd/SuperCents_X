# Changelog

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
