# Changelog

## v3.0-production-providers — 2026-08-01 — Settlement wiring + promotion gate on settled outcomes (Sprint 15.3–15.4)

### Added
- `CSymbolContext::QueueForSettlement` / `SettleRow` / `SettleDue` / `SettleRemaining` — forward-outcome settlement pipeline wired into the decision tick (`SettleDue` before queueing each row) and `OnDeinit` (`SettleRemaining` records run-tail rows as UNKNOWN)
- `CForwardOutcomeSimulator` + outcome policy now drive the outcome columns (36 outcomeSource, 37 outcome, 38 rMultiple, 39 barsHeld, 40 exitReason, 41 entryPrice, 42 exitPrice)
- `CalibrationDataset::ParseUnsigned` — public static chunked parser for full-range ulong fingerprints
- `Tests/unit/TestCalibrationDataset.mqh` (10 tests), `Tests/unit/TestProductionProviders.mqh` (38 tests), presets `Sprint15_3_LongRun_EURUSD_M15.ini` / `Sprint15_3_LongRun_EURUSD_H1.ini` / `Sprint15_3_LongRun_GBPJPY_H1.ini` / `Sprint15_3_PromotionGate.ini`
- Docs: `docs/Sprint15_3_CalibrationResults.md`; `docs/CalibrationGuide.md` §5b (settlement), §5c (gate flow)

### Fixed
- **Simulated-settlement ordering bug**: MQL5 time-range `Copy*` overloads return bars oldest-first, but the simulator expects as-series (index 0 = newest) — settled rows were computed from bars *before* the entry (corrupt win rate 19% vs 38% verified). `SettleRow` now `ArrayReverse()`s copied series, locates the entry bar by exact timestamp, and guards `entryBarIndex >= 50` / `entryBarIndex + 20 < n`; window `[entry − 3d − 20 bars, entry + (51 + 2d bars + 50 bars)]`
- Promotion gate now receives settled trades — baseline r7 gate ran all-INCONCLUSIVE with 0 settled trades; r22+ gates pass the sample criteria (1,419 / 8,602 settled trades) and produce real verdicts

### Verified
- **499/499** headless tests green (was 451); clean compiles (0 errors, 4 pre-existing `POSITION_COMMISSION` warnings)
- Regenerated datasets (NEW mode, 2026-01-05→06-30): EURUSD M15 12,130/12,180 settled (99.6%), EURUSD H1 2,992/3,042 (98.4%), GBPJPY H1 2,995/3,045 (98.4%); UNKNOWN = exactly 50 run-tail rows per symbol/timeframe; TP rMultiples exactly 2.00000000 / SL exactly −1.00000000; horizon rows barsHeld=51 → BREAKEVEN
- Threshold sweep (M15): best expectancy at 0.40 (−0.0369, PF 0.9453, win 32.35%, 8,602 trades) — not significant vs 0.60 baseline (p = 0.1613); no threshold clears the Welch test
- **Promotion gate: NOT PROMOTED** for EURUSD M15 at calibrated 0.40 (expectancy INCONCLUSIVE p=0.16, max drawdown FAIL 567.6 vs 207.7 R) and at 0.60 (candidate==baseline by construction); H1 and legacy fingerprints INCONCLUSIVE (insufficient samples)
- Tainted pre-fix telemetry (r13–r15, r16–r17) archived and excluded from all reports

## v3.0-provider-contract — 2026-08-01 — Production Providers wired via DI (Sprint 15.1–15.2)

### Added
- `IRiskEvaluator` migrated to atomic `RiskEvaluation` struct: `Evaluate(double confidence)` returns allowed / recommendedLots / reason / margin context (`marginRequired`, `freeMarginAfterTrade`) / typed `ENUM_RISK_REJECTION_REASON` (`RR_TRADING_DISABLED`, `RR_INVALID_VOLUME`, `RR_NO_PRICE`, `RR_MARGIN_CALC_FAILED`, `RR_INSUFFICIENT_MARGIN`, `RR_UNKNOWN`); `riskPercent` reserved for Sprint 16+ risk policy
- Provider contracts frozen `@frozen v3.0-provider-contract` on `IRiskEvaluator` / `ITradeStateProvider` (+ per-declaration markers) — future changes MUST be additive
- `CProductionRiskEvaluator` full implementation: trade-mode → broker volume limits → price availability → `OrderCalcMargin` minimum-lot check → free-margin buffer (factor 1.25) → clamp to `SYMBOL_VOLUME_MAX`; logs `ProductionRisk: allowed (maxLots %.2f)`
- `CProductionTradeStateProvider` (previously orphaned) wired in: `INT_MAX` = never traded, `PERIOD_CURRENT` bars, symbol+magic-scoped positions/deals
- DI in `CSymbolContext`: providers bound **at construction** (validators capture pointers in their own ctors); `SetProvider()` / `SetRiskEvaluator()` for explicit rebinding; `ENTRY_MODE_NEW` = production providers + shadow comparison, execution reserved until promotion gate
- Mode matrix documented in `EntryConfig.mqh` (LEGACY / SHADOW / NEW / LIVE(*) future)
- `TestRiskValidator_StructFlow` — 4 assertions on struct-flow (approval + margin-exhausted rejection path)
- `Presets/Sprint15_1_ProdProviders_EURUSD_M15.ini` (ENTRY_MODE_NEW), `docs/DeveloperGuide.md` (MetaEditor GUI-process compile workflow, headless tester recipes, parity-check method)

### Changed
- `CRiskValidator` consumes `RiskEvaluation` (allowed/reason/recommendedLots); `CShadowRiskEvaluator` returns permissive struct (allowed, 1.0 lots, RR_NONE)
- `SuperCents_X.mq5` / `CalibrationRunner.mq5` — `#property version "3.00"` (release identity v3.0)
- Validator MT5-API audit: no `Position*`/`HistoryDeal`/`AccountInfo`/`OrderCalc*`/`iBarShift`/`TimeCurrent` calls in `Entry\Validators` (contract compliance)

### Fixed
- Provider-capture DI bug: validators previously bound NULL providers when pointers were re-pointed in `Init()` (parity agreements dropped 60→0); binding moved to the constructor
- MQL5 ternary `?:` is unsupported (`error 252`) — provider selection done via if/else in ctor body

### Verified
- **451/451** headless tests green (was 447); clean compiles (EA 0 errors / 4 pre-existing `POSITION_COMMISSION` warnings; TestRunnerEA 0 errors / 0 warnings)
- **SHADOW parity vs v2.9.2 is byte-identical**: 480 bars, 60/480 agreements (12.5%), 0 differing bars across `newConfidence` / `decisionMatch` / `legacyConfidence` / `validatorResults`
- NEW-mode run: `Production providers active — TradeState(symbol=EURUSD magic=… tf=PERIOD_M15) Risk(name=ProductionRisk)`; `ProductionRisk: allowed (maxLots 17.99–18.02)` (real margin math, not the stub 1.0); shadow comparison active (51/480, 10.6%); full validator chain incl. `CooldownValidator=0|RiskValidator=0` on qualified bars; **new engine placed zero orders** (legacy engine trades unchanged, pre-existing behavior)

## v2.9.2-telemetry-stable — 2026-08-01 — Telemetry pipeline verified end-to-end (Sprint 14.5 maintenance)

### Fixed
- A-01 Shadow comparison semantics — shadow mode now compares the legacy **decision** (`EntryDecisionEngine`) against the new-engine decision instead of plan existence (previously a trivial 100% match); `decisionMatch` / `directionMatch` flags per bar (`ShadowComparison.formatVersion = 2`)
- A-02 Confidence scale — all telemetry confidence columns normalized to the 0–1 scale (`legacyConfidence` now carries the decision confidence, not the 0–100 raw score); schema bumped to v2 (`TELEMETRY_SCHEMA_VERSION = 2`, `TELEMETRY_EA_VERSION = "v2.9.2"`, 45-column header layout preserved)
- A-03 Telemetry collection — collector wired through `CEngine` → `CPortfolioManager` → `CSymbolContext`; per-bar rows via new `CTelemetryRowBuilder` (components, validator filters, decision flags, config fingerprint, 0–1 confidences); collector fixes: `FileIsExist` now matches `FILE_COMMON` open mode, `Record()` buffer resize guard, schema-v2 header

### Added
- `Telemetry/TelemetryRowBuilder.mqh` — static row builder mapping `ConfluenceResult` + legacy/new decisions to v2 telemetry rows
- Audit reports: `docs/Sprint14_5_StabilityAudit_Executive.md`, `docs/Sprint14_5_StabilityAudit_Technical.md` (findings A-01..A-10)
- Regression preset: `Presets/Sprint14_6_Verify_EURUSD_M15.ini`
- 32 new telemetry unit tests (header v2, schema version, normalized-confidence row builder, mismatch flags)

### Changed
- `SuperCents_X.mq5` / `CalibrationRunner.mq5` — `#property version "2.92"` (release identity v2.9.2)
- Telemetry output: `Common\Files\Telemetry\telemetry_v2_YYYYMMDD.csv` (schema v2)

### Verified
- **447/447** headless tests green (was 415); clean compile (0 errors; 4 pre-existing `POSITION_COMMISSION` deprecation warnings)
- 1-week EURUSD M15 SHADOW regression: 480 bars, 275,405 ticks, `Test passed`; shadow log `fmt=2` decision-level lines; telemetry artifact `telemetry_v2_20251107.csv` — 480 rows + header, both confidence scales 0–1, `legacyDecision=QUALIFIED` vs `newDecision=REJECTED` with threshold 0.60 recorded per row

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
