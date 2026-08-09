# Sprint 14 — Calibration & Live Validation

**Status:** Complete. Validation suite 415/415 green, benchmarks refreshed,
v2.9 weight inputs wired into the live EA.

## Deliverables

| Item | Where |
|---|---|
| Offline calibration runner | `CalibrationRunner.mq5`, `Calibration/ExperimentRunner.mqh` |
| Threshold sweep | `Calibration/ThresholdOptimizer.mqh` |
| 3-stage weight search | `Calibration/WeightOptimizer.mqh` |
| Validator attribution | `Calibration/ValidatorAttribution.mqh` |
| Promotion gate (8 criteria) | `Calibration/PromotionGate.mqh` |
| Headless test suite | `Tests/TestSuite.mqh`, `Tests/TestRunnerEA.mq5`, `Tests/Sprint14_TestRunner.ini` |
| Headless benchmarks | `benchmarks/Benchmarks.mqh`, `benchmarks/BenchmarkRunnerEA.mq5` |
| v2.9 weight wiring | `SuperCents_X.mq5`, `Core/Engine.mqh`, `Portfolio/PortfolioManager.mqh`, `Portfolio/SymbolContext.mqh` |

## Validation: 415/415 green

```
WalkForward 68/68   MonteCarlo 16/16   Regression 18/18   ReportComposer 20/20
Validator 51/51     Registry 26/26     Orchestrator 27/27  Integration 30/30
Confluence 73/73    Telemetry 24/24    Simulator 19/19     Calibration 43/43
GRAND TOTAL: 415/415 passed, 0 failed
```

Run headlessly: `Tests/Sprint14_TestRunner.ini` → check
`Tester/logs/<date>.log` for `GRAND TOTAL`.

## Bugs found & fixed during Sprint 14

1. **WeightOptimizer `ScanNeighborhood` produced invalid weights** — stage 2/3
   shifted one weight by delta without rebalancing another, so
   `IsValidWeights` failed and stage 2 scored nothing. Fixed with a
   compensating `ShiftWeight` helper.
2. **WeightOptimizer `InsertRanked` compared against unscored candidates** —
   the slot comparison used a default-constructed candidate (expectancy 0),
   so every candidate beat rank 0 and the "top 5" list was actually the
   *last* 5 processed. `m_ranked` now stores fully-scored
   `WeightCandidate`s.
3. **Threshold scale mismatch (test + production)** — the weight optimizer
   scores `ReplayConfidence` on a 0..100 scale, but the test and
   `ExperimentRunner` passed a 0..1 threshold (0.60). Every row qualified
   at any `wStructure ≥ 10`, capping expectancy at 0.5 and making the
   0.9 assertion impossible. Fixed test to 55.0 (separates 94–97 raw
   winners from 85–88 losers at wS=60) and production to
   `minConfidence * 100`.
4. **Telemetry validator-test inversion** — validators *failing* the gate
   were asserted as passing (and vice versa); added the
   below-threshold `FILTER_PASS → TEST_FALSE` case.
5. **Forward simulator `barsHeld` convention** — the simulator counts the
   entry bar inclusive, so a TP hit on the next bar is `barsHeld == 2`;
   test expected 1.
6. **TrendEvaluator NULL-state mismatch** — production returns no score on
   no-trend data; tests asserted a stale `TrendUnknown(limited)` design.
7. **Confluence score clamp** — raw score is now clamped back into
   `result.components[i].score` (was only in the total).
8. **Confluence engine path test** used an evaluator that can never signal
   with unset swings; switched to `CLiquidityEvaluator`.

## Performance benchmarks (v2.8 → v2.9, 61 benchmarks)

`benchmarks/Sprint14_Benchmark.ini` → `Files/baseline_v2.9.txt`.

- Confluence engine path −52%, rule path −55% (2.1x)
- ReportComposer Large −47%, Regression 11-metrics −83%
- MonteCarlo 1000-trade suites −4 to −7%
- WalkForward mixed (noise-dominated at µs scale); sub-µs validators
  unchanged. Benchmark numbers are noise-sensitive on a shared laptop;
  treat ±30% on sub-100 µs rows as noise.

## v2.9 wiring

`SuperCents_X.mq5` gains `WeightStructure/…/WeightPremiumDiscount` inputs
(validated to sum 100, `INIT_PARAMETERS_INCORRECT` otherwise) which flow
`CEngine → CPortfolioManager → CSymbolContext → CConfluenceEngine::SetWeights`,
with a startup log line and fallback to defaults on invalid input.
EA version bumped to 2.90; shadow-comparison `eaVersion` tag = v2.9.

## Known limitations

- Weight search threshold (0..100) is not yet derived from the live
  ConfluenceValidator normalization — it is an explicit input; verify
  separation on real telemetry before promoting a weight set.
- `CalibrationRunner` reads only the frozen v1 45-column telemetry schema.
- Benchmark EA writes `baseline_v2.9.txt` into the tester agent sandbox
  (`AppData\Roaming\MetaQuotes\Tester\<hash>\Agent-*\MQL5\Files`);
  copy it to `MQL5\Files` manually.
