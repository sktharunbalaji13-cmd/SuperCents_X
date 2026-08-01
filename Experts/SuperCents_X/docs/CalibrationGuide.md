# Calibration Guide (Sprint 14.6 / v2.9.2)

How to run the offline calibration stack, read its outputs, and apply the
results to production.

## 1. Architecture overview

```
Live EA (shadow) ──► TelemetryRow ──► Common\Files\Telemetry\telemetry_v2_*.csv
                                          │
CalibrationRunner.mq5 ──► CExperimentRunner
     │                       ├─ RunThreshold  (CThresholdOptimizer)  0..1 scale
     │                       ├─ RunWeights    (CWeightOptimizer)     0..100 scale
     │                       ├─ RunAblation   (CValidatorAttribution)
     │                       └─ RunPromotion  (CPromotionGate vs locked baseline)
     │
     └─► Files/Calibration/calib_<type>_<hex>_<tag>.csv + .manifest
```

Telemetry rows are written by the live EA (shadow mode), schema v2
(`schemaVersion = 2`; all confidence columns normalized 0-1 — v1 rows
predate collection and are not supported). The calibration runner replays
them offline — no market connection required — and writes CSV reports plus
manifests (fingerprint, date range, sample counts) for auditability.

## 2. Threshold optimizer (0..1 scale)

- Sweeps `Optimize(0.40, 0.80, 0.05, minConfidence, results)` — 9 steps.
- Rows qualify when `row.confidence >= threshold` (confidence is 0..1).
- Score = expectancy of settled trades; results sorted descending.
- Report: `calib_threshold_<hex>_<tag>.csv`.

Read the best row: `threshold`, `expectancy`, `profitFactor`, `winRate`,
`settledTrades`, `significant` (Welch p-value vs baseline).

## 3. Weight optimizer (0..100 scale — IMPORTANT)

- `CWeightOptimizer::Optimize(baselineWeights, threshold, best)` runs three
  stages over the 6 confluence weights (S, OB, FVG, Liq, Trend, PD):
  1. **Coarse scan** — step 10, all compositions summing to 100
     (~3,003 evals), keeps top 5.
  2. **Fine scan** — step 5 around the top 5 (~120 evals), keeps top 3.
  3. **Hill climb** — step 2 on the top 3.
- `threshold` is on the **0..100 ReplayConfidence scale** (`Σ rawᵢ·wᵢ/100`),
  **not** 0..1. `CalibrationRunner` scales `CandidateConfidence * 100`
  automatically. Passing a 0..1 value (e.g. 0.60) makes every row qualify
  and the search degenerates to a tie at the first 0.5-expectancy
  composition.
- Score = expectancy of qualified trades; tie-break by profit factor.
- Report: `calib_weights_<hex>_<tag>.csv` — 6 weights, expectancy, PF,
  win rate, max DD, eval count.

## 4. Ablation & promotion

- `calib_ablation_*` — leave-one-out validator attribution; a validator
  that blocks profitable rows gets `recommendWeaken`.
- `calib_promotion_*` — 8-criterion CI gate vs the locked baseline
  (expectancy, PF, win rate, drawdown, Welch p-value, sample size,
  shadow comparisons). `promoted=true` only when every criterion passes.

## 5. Headless test-suite runs (CI)

The full 415-test validation suite runs as an EA in the Strategy Tester:

```
[Tests/TestRunnerEA.mq5]  →  RunAllSuperCentsTests()  →  prints per-suite
[Tester] FromDate=2026.01.01 ToDate=2026.01.02 Model=4 ShutdownTerminal=1
```

Check `Tester/logs/YYYYMMDD.log` for `GRAND TOTAL: 415/415 passed, 0 failed`.

## 6. Applying results to production (v2.9)

The live EA exposes the calibrated weights as inputs:

```
WeightStructure / WeightOrderBlock / WeightFVG /
WeightLiquidity / WeightTrend / WeightPremiumDiscount   (sum must = 100)
```

`SuperCents_X.mq5 → CEngine::SetWeights → CPortfolioManager → CSymbolContext
→ CConfluenceEngine::SetWeights` (validated + logged at startup; falls back
to defaults on invalid sums).

## 7. Worked example

1. Run the EA in `ENTRY_MODE_SHADOW` for N bars → telemetry rows appear in
   `Files/Telemetry/`.
2. Run `CalibrationRunner.mq5` (script) with `CalibrationMode` = weights.
3. Copy `best.weights[0..5]` into the EA inputs; recompile; verify the
   startup log prints `Confluence weights: W{S=... OB=... ...}`.
4. Re-run the test suite headlessly to confirm 415/415.
5. Run `BenchmarkRunnerEA.mq5` in the tester to refresh
   `Files/baseline_v2.9.txt`.
