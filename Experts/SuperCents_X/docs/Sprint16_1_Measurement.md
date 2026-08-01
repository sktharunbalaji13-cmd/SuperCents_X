# Sprint 16.1 — Confidence Measurement Baseline

Status: **FROZEN** (2026-08-01). Reference for every later calibration experiment.

## Scope boundary

This sprint intentionally performs measurement only.

No confidence transforms, rule retuning, weight optimization, score
normalization, or architectural changes were performed. The outputs
below describe the behavior of the **unmodified v3.0 scoring system**
(`confidenceModel: raw`). Any future report whose reliability curve or
ECE/Brier is compared to this document must state its own
`confidenceModel` — a match to the numbers here is only meaningful for
the raw score.

## Artifacts (Common\Files\Calibration\)

| Artifact | Purpose |
|---|---|
| `baseline_calibration_v1.manifest` | Frozen v1 baseline reference (do not edit; regenerate only with an explicit version bump) |
| `calib_calibration_1D1EF3C650D79C3F_20260105_000000.csv` | Reliability histogram + per-bin stats |
| `calib_calibration_1D1EF3C650D79C3F_20260105_000000.summary.txt` | Aggregate metrics + provenance |
| `calib_reportcard_1D1EF3C650D79C3F_20260105_000000.txt` | Research Report Card (§5 of the research plan) |

Archive copy: `Temp\opencode\sprint16\`.

## Dataset

- Config/dataset fingerprint: `1D1EF3C650D79C3F` (EURUSD M15, settled)
- Rows: 13,140 total → 12,130 decided (UNKNOWN excluded from the histogram)
- eaVersion: v3.0, weights 25/20/15/15/15/10, FixedRR 1R/2R, hold ≤ 50 bars
- Binning: `row.confidence`, 0.05 bins, winRate = wins/(wins+losses),
  BE rows count as trades but not in winRate
- **Conservation invariant verified on real data**: Σ bin.trades == 12,130 == decidedRows

## Baseline metrics

| Metric | Value |
|---|---|
| Brier | 0.242516 |
| ECE | 0.126533 |
| MCE | 0.332679 |
| confMin / confMax | 0.3500 / 0.6000 |
| confMean / P50 / P90 | 0.4313 / 0.4000 / 0.6000 |
| Populated bins | 6 of 21 |

## Reliability table

| Bin | Trades | Win% | Expected | Error | Expectancy | PF | MaxDD |
|---|---|---|---|---|---|---|---|
| [0.35, 0.40) | 2,733 | 36.26% | 37.50% | +0.0124 | +0.084 | 1.13 | 99.8 R |
| [0.40, 0.45) | 6,278 | 33.11% | 42.50% | **+0.0939** | −0.013 | 0.98 | 289.2 R |
| [0.45, 0.50) | 559 | 31.66% | 47.50% | +0.1584 | −0.052 | 0.92 | 71.8 R |
| [0.50, 0.55) | 53 | 35.85% | 52.50% | +0.1665 | +0.076 | 1.12 | 12.0 R |
| [0.55, 0.60) | 293 | 24.23% | 57.50% | **+0.3327** | −0.274 | 0.64 | 98.2 R |
| [0.60, 0.65) | 2,214 | 30.13% | 62.50% | **+0.3237** | −0.109 | 0.84 | 300.8 R |

Error = expected − actual win rate; positive error = **overconfident**.

## Findings (measurement only — no remedies applied)

1. **Compression is confirmed and harder than estimated**: confidence spans
   only **[0.35, 0.60]** (P90 = 0.60, max = 0.60). Six of 21 bins are
   populated. Any threshold ≥ 0.65 is structurally empty — the r23 sweep
   finding is explained.
2. **Systematic overconfidence in every populated bin**: the score
   overstates win probability across the whole range (MCE 0.333 in
   [0.55, 0.60): claims 57.5%, delivers 24.2%).
3. **Reliability is essentially flat**: actual win rate stays ~24–36%
   while the claimed probability rises 37.5% → 62.5%. The raw score
   appears to carry little ordering power *within* its observed range.
4. **Cap artifact**: 2,214 rows sit at exactly 0.60 — consistent with a
   scoring cap (`totalConfidence` ceiling), a structural-A2 candidate.
5. **Drawdown signature reproduced**: the largest per-bin drawdowns sit in
   [0.40, 0.45) (289 R) and [0.60, 0.65) (301 R) — the 0.40-threshold
   drawdown spike from Sprint 15 is a property of this score, not an
   artifact of the threshold choice.

## Decision rule (from the research plan) — evidence status

```
Reliable inside observed range  → Branch B (architecture: no transform)
Unreliable inside observed range → Branch A (transform: isotonic/Platt/temp)
```

Observed: win rate does **not** track claimed probability inside
[0.35, 0.60] → the evidence points to **Branch A**, with the caveat that
a transform's headroom depends on the within-range ordering power found
in 16.1B. **No transform has been applied** — this decision belongs to
the review gate.

## Deferred — 16.1B diagnostics (spec'd, NOT implemented)

Pending review of this baseline:

- **CUR table (Confidence Utilization Ratio)**: per component,
  activation% × mean(raw | raw > 0). Answers whether the 0.60 ceiling
  comes from rare component activation rather than low component scores.
- A2 questions, in order: which component saturates / which raw scores
  compress / does normalization clip / can the calculator even exceed 0.64?
- If Branch A: each candidate transform (temperature, Platt, isotonic)
  evaluated on the SAME settled rows, reporting transformed confidence +
  ECE + Brier + gate metrics per variant, with `confidenceModel: <name>_vN`
  recorded in the manifest. Every adopted transform must be invertible
  and reproducible from versioned parameters.

## Reproduction

1. Compile `CalibrationRunner.mq5` (mode `CALIB_MODE_CALIBRATION`).
2. Preset: `Presets\Sprint16_1_CalibrationBaseline.ini` +
   `Profiles\Tester\CalibrationRunner.set` (mode 5, filter M15 fp).
3. Run via `run_long.ps1`; outputs land in `Common\Files\Calibration\`.
4. Baseline suite: `Tests\unit\TestCalibrationReport.mqh`
   (553/553 green project-wide).
