# Changelog

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
