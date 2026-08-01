# Sprint 16.2 — Calibration Transform Comparison (Branch A)

Status: COMPLETE (in-sample experiment, gate re-anchoring deferred to 16.5)
Date: 2026-08-01
Scope: `CALIB_MODE_TRANSFORMS` (mode 6) on settled M15, fp `1D1EF3C650D79C3F`

## Context

Branch A (approved in review): after measuring the raw confidence baseline in
16.1A (ECE 0.1265, Brier 0.2425, MCE 0.3327, conf range [0.35, 0.60]), the next
step is to test whether the raw score can be *calibrated* — i.e. whether a
monotone/probabilistic transform yields real Calibration Gain (user-mandated
metric: `Model | ECE | ΔECE | Brier | ΔBrier`), before any structural
diagnostics (16.1B) or optimization.

## Method

- Dataset: settled telemetry rows for fp `1D1EF3C650D79C3F` (13,140 rows,
  12,130 decided win/loss), identical to the frozen 16.1A baseline.
- Fits are **in-sample** (same rows used to fit and evaluate); adoption is gated
  by the 16.5 out-of-sample gate before any use.
- Models (implemented in `Calibration\CalibrationTransforms.mqh`):
  - `isotonic_v1` — PAV monotone step function (tie-pooled groups).
  - `platt_v1` — Platt scaling via IRLS on logit scale.
  - `temperature_v1` — single-parameter temperature on logit scale
    (GD 3000 iters, lr 0.1*0.998^k).
- Every model is serialized to `calib_transform_<model>_<hex>_<tag>.params`
  (reproducible, invertible), then replayed through the PromotionGate at 0.60
  on transformed confidence copies (all downstream tools unchanged).

## Calibration Gain table (raw reference ECE 0.126533, Brier 0.242516)

| model          | ECE     | ΔECE    | Brier   | ΔBrier  | MCE     | trades@0.60 | promoted |
|----------------|---------|---------|---------|---------|---------|-------------|----------|
| raw            | 0.12653 | 0       | 0.24252 | 0       | 0.33268 | 1,419       | 0        |
| isotonic_v1    | 0.00506 | +0.1215 | 0.22112 | +0.0214 | 0.00506 | 0           | 0        |
| platt_v1       | 0.01419 | +0.1123 | 0.22071 | +0.0218 | 0.02627 | 0           | 0        |
| temperature_v1 | 0.19494 | −0.0684 | 0.25000 | −0.0075 | 0.19494 | 0           | 0        |

Δ = raw − model (positive = gain). `trades@0.60` = trades surviving the
PromotionGate on the transformed score; `promoted` = PromotionGate verdict.

## Findings

1. **Isotonic collapses to the constant base rate (0.3301).** The fitted model
   has a single knot (nodesX 0.35, nodesY 0.33006). PAV found **no monotone
   structure** in the reliability curve: per-bin win rates are non-monotone
   (36.3%, 33.1%, 31.7%, 35.9%, 24.2%, 30.1% across claims 37.5%–62.5%), so
   every block is pooled into one flat block. ECE 0.0051 is achieved only by
   predicting the base rate everywhere — Brier 0.2211 is the irreducible
   outcome variance. Calibration gain here is degenerate: it removes
   miscalibration but also removes all discrimination.
2. **Platt fits a *negative* slope (a = −1.0704, b = −0.2474).** IRLS found
   that higher claimed confidence correlates with *lower* win rate (the
   0.55–0.60 bin wins 24.2%), producing an inverted mapping (conf 0.35 → 0.60,
   conf 0.60 → 0.336). ECE 0.0142 and MCE 0.0263 are small for the same
   degenerate reason.
3. **Temperature scaling diverged (b = −117.4, t = 721.5).** e^t overflows
   double precision, the GD landed on a pathological flat-0.5 constant, and ECE
   (0.1949) / Brier (0.2500) are **worse than raw**. Temperature alone cannot
   fix a non-sigmoid miscalibration; on this population the fit is numerically
   unstable. Flagged: fit should be re-examined before reuse (bound t,
   early-stop, or reject).
4. **Every calibrated model empties the 0.60 gate (trades@0.60 = 0).** All
   transformed scores sit at ≈ 0.33–0.5; the raw population only lives in
   [0.35, 0.60]. A 0.60 threshold on calibrated scores selects nothing. The
   gate threshold must be **re-anchored to the calibrated distribution** (e.g.
   pick the threshold that recovers the baseline trade count) — deferred to
   16.5.

## Interpretation (Branch A evidence)

- The raw v3.0 score is **uncalibrated but also unstructured**: no monotone
  relationship exists between claimed confidence and win rate on the settled
  population. Calibration can buy ECE (trivially, via the base rate) but
  cannot recover discrimination, and it destroys trade selection at the
  current gate.
- Consistent with 16.1A: this is a flat-reliability profile, not a
  compression artifact — a monotone transform has nothing to amplify.
- **Selection**: isotonic_v1 has the best Calibration Gain (ΔECE +0.1215,
  ΔBrier +0.0214) but is the constant model; platt_v1 is a close second with
  an inverted (i.e. signal-free) slope. Neither is adoptable as-is.

## Decision / next steps

- **16.1B structural diagnostics** (deferred from 16.1A) become the active
  work: the score cannot rank trades (flat, non-monotone, slightly negative
  reliability) — root-cause the score's discrimination before any calibration
  or optimization. CUR spec, A2 questions.
- **16.5 gate re-anchor**: re-run the PromotionGate on calibrated scores with
  a calibrated-relative threshold; confirm selection out-of-sample before
  adoption (in-sample fits are NOT adoptable).
- Temperature fit instability to be fixed or removed if temperature scaling is
  ever revisited.

## Artifacts

- `Common\Files\Calibration\calib_transforms_1D1EF3C650D79C3F_20260105_000000.csv`
- `Common\Files\Calibration\calib_transform_{isotonic_v1,platt_v1,temperature_v1}_1D1EF3C650D79C3F_20260105_000000.params`
- `Common\Files\Calibration\calib_reportcard_1D1EF3C650D79C3F_20260105_000000.txt`
- Tester log: `s16_2_transforms.log.txt` (archived `Temp\opencode\sprint16\`)
- Unit suite (587/587 green, incl. 9 transforms tests): `s16_2_unit_tests3.log.txt`

## Reproduction

```
CalibrationRunner.set: CalibrationMode=6||0||0||7||N
Presets\Sprint16_1_CalibrationBaseline.ini (tester base, ExpertParameters=CalibrationRunner.set)
run_long.ps1 -Ini <preset> -RunName s16_2_transforms
```
