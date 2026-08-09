# Calibration Guide (Sprint 15 / v3.0)

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

## 1a. Entry modes & providers (v3.0)

The entry mode selects which trade-state/risk providers are bound into the
validator pipeline. Providers are bound **at `CSymbolContext` construction**
(validators capture their pointers in their own constructors); the mode is
set via the `EntryMode` input.

| Mode | Providers | New engine executes | Legacy trades | Shadow compare |
|------|-----------|---------------------|---------------|----------------|
| LEGACY (0) | none (legacy path) | no | yes | no |
| SHADOW (1) | ShadowTradeState / ShadowRisk (permissive) | no | yes | yes |
| NEW (2) | ProductionTradeState / ProductionRisk (real account/market state) | **reserved** | yes | yes |
| LIVE (*) | Production | yes — post-promotion, Sprint 16+ | retired | yes |

Contract (`@frozen v3.0-provider-contract`, `Entry/Validators/`):

- Providers retrieve state only; validators hold all business rules;
  validators never touch MT5 APIs.
- `ITradeStateProvider` — `GetBarsSinceLastTrade()` in `PERIOD_CURRENT`
  bars (`INT_MAX` = never traded), `HasOpenPosition()` symbol+magic scoped,
  `GetLastTradeTime()` (0 = none).
- `IRiskEvaluator::Evaluate(confidence) → RiskEvaluation` — one atomic
  result: allowed / recommendedLots / reason / margin context /
  `ENUM_RISK_REJECTION_REASON`. Shadow evaluator is always-permissive;
  production evaluator applies trade-mode, volume, price, `OrderCalcMargin`
  and free-margin-buffer (1.25) checks and logs
  `ProductionRisk: allowed (maxLots %.2f)`.

NEW-mode runs therefore exercise the real margin/cooldown gates without
executing, and their telemetry rows are directly comparable with SHADOW
rows for promotion decisions.

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

The full 451-test validation suite runs as an EA in the Strategy Tester:

```
[Tests/TestRunnerEA.mq5]  →  RunAllSuperCentsTests()  →  prints per-suite
[Tester] FromDate=2026.01.01 ToDate=2026.01.02 Model=4 ShutdownTerminal=1
```

Check `Tester/logs/YYYYMMDD.log` for `GRAND TOTAL: 451/451 passed, 0 failed`.

Build recipe (see `docs/DeveloperGuide.md` for pitfalls): compile with
`Start-Process metaeditor64 -Wait -PassThru`, confirm the log tail says
`0 errors` **and** the `.ex5` timestamp advanced, then launch the tester
with `/config:"<ini>"`.

## 5b. Outcome settlement (v3.0 — Sprint 15.3)

Telemetry rows only become usable for calibration once their forward outcomes
are **settled**. Settlement runs inside the live/new-mode EA (`CSymbolContext`):

- `SettleDue()` — per decision tick, settles rows whose horizon has elapsed
  (gate: `iBarShift(..., false) >= TELEMETRY_SETTLE_MAX_HOLD_BARS` (50)).
- `SettleRow()` — replays the forward outcome with `CForwardOutcomeSimulator`
  + the outcome policy (FixedRR 1R/2R, ATR-14 SL spacing, SL/TP intrabar
  tie-break → SL wins, trailing ratchet, horizon exit at close of the 50th
  scanned bar; `OUTCOME_CLASSIFY_EPS 0.05`).
- `SettleRemaining()` — at `OnDeinit`, rows still open are recorded as
  `UNKNOWN` (run-tail horizon, expected).

**Critical MQL5 caveat**: the time-range `Copy*(symbol, tf, start, stop, array)`
overload returns bars in **ascending chronological order** (oldest first),
but the simulator expects **as-series (index 0 = newest)**. `SettleRow`
therefore `ArrayReverse()`s every copied series and locates the entry bar by
exact timestamp (`times[i] == entryBarTime`). Guards: `entryBarIndex >= 50`
(forward coverage) and `entryBarIndex + 20 < n` (ATR warmup). The settlement
window is `[entry − (3 days + 20 bars), entry + (51 + 2 days of bars + 50 bars)]`
so Monday entries clear the weekend session gap.

CSV outcome columns (0-based): 36 = outcomeSource (1 = scheduled),
37 = outcome (1 WIN / 2 LOSS / 3 BREAKEVEN / 0 UNKNOWN), 38 = rMultiple,
39 = barsHeld, 40 = exitReason (1 TP / 2 SL / 3 BE / 4 HORIZON),
41 = entryPrice, 42 = exitPrice. Files are shared per date-chunk across
runs/symbols — archive telemetry between runs to keep artifacts clean
(parsing is by symbol + timeframe anyway).

## 5c. Promotion gate flow (v3.0 — Sprint 15.3)

The gate compares **candidate vs locked baseline** on settled outcomes only:

1. Run threshold sweep (`CalibrationMode=0`) → `calib_threshold_<hex>_*.csv`
   (9 steps, 0.40–0.80; rows with `significant=1` clear the Welch test vs the
   0.60 baseline).
2. Run promotion (`CalibrationMode=3`, `FingerprintFilter=<hex>`,
   `CandidateConfidence=<calibrated threshold>`) →
   `calib_promotion_<hex>_*.csv`. Sample gates: ≥ 10,000 shadow comparisons,
   ≥ 500 qualified signals, ≥ 300 settled trades; statistical criteria:
   expectancy improvement (p < 0.05), PF, win rate, drawdown, recovery.
   `promoted=true` only when **every** criterion passes.

Using `CandidateConfidence = 0.60` (the default) makes candidate == baseline
by construction — the sweep step is mandatory to obtain the calibrated
threshold first. See `docs/Sprint15_3_CalibrationResults.md` for the Sprint
15.3 evidence and verdicts.

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
4. Re-run the test suite headlessly to confirm 451/451.
5. Run `BenchmarkRunnerEA.mq5` in the tester to refresh
   `Files/baseline_v2.9.txt`.
