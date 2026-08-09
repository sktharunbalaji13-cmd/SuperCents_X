# Sprint 16.1B - Structural Diagnostics

Status: **COMPLETE** (2026-08-01). Companion to 16.1 (measurement baseline)
and input to the 16.2 Branch A review gate.

## Question

The 16.1 baseline showed a flat reliability curve: actual win rate stays
~24-36% while claimed confidence rises 37.5% -> 62.5%. Why does the raw
v3.0 score order outcomes so weakly inside its observed range
[0.35, 0.60]?

Hypotheses on the table:

- H1 reward amount vs quality: the score rewards the NUMBER of fired
  components (legacy `promotionCount` heritage), not the quality of any
  single signal, so increments carry no information.
- H2 compression: component raw scores saturate (CUR table, structural-A2).
- H3 cap artifact: total confidence is capped at 0.60 by construction
  (2,214 rows sit exactly at 0.60).

## Dataset

- Config/dataset fingerprint: `1D1EF3C650D79C3F` (EURUSD M15, settled)
- Rows: 13,140 total, 12,130 decided (WIN/LOSS; BE and UNKNOWN excluded
  from rank correlations)
- eaVersion: v3.0, weights 25/20/15/15/15/10, FixedRR 1R/2R, hold >= 50 bars
- confidenceModel: `raw` (structure analysis, no transforms applied)
- Store-wide scan: 21,627 rows across all 15 telemetry_v2 files checked
  for component data availability

## Artifacts (Common\Files\Calibration\)

| Artifact | Purpose |
|---|---|
| `calib_structural_1D1EF3C650D79C3F_20260105_000000.csv` | Sections A (activation) / B (fired-count) / C (rank correlations) / D (ablation replay) |
| `calib_reportcard_1D1EF3C650D79C3F_20260105_000000.txt` | Research Report Card |

## Findings

### F1. Ordering power: weak at best, possibly zero

| Correlation | r | n |
|---|---|---|
| Spearman(conf, R) | +0.2069 | 12,130 |
| Kendall(conf, R) | -0.0433 | 12,130 |
| Spearman(conf, win/loss) | +0.2118 | 12,125 |
| Kendall(conf, win/loss) | -0.0432 | 12,125 |

- |Spearman| ~ 0.21 is a weak positive monotone association; the Kendall
  values are essentially zero and NEGATIVE in sign.
- The sign disagreement between Spearman and Kendall is a tie artifact of
  a nearly discrete score (confidence concentrates on 0.40 / 0.60; the
  observed distribution is only 6 populated 0.05-bins). Neither metric
  supports a meaningful within-range ordering of outcomes.
- Implication for 16.2: any monotone transform (isotonic/Platt/
  temperature) can only re-express this weak ordering - it cannot create
  headroom that the raw score does not contain. The 16.2 gain table
  (ECE 0.1265 -> 0.0051 with isotonic_v1) is therefore a RECALIBRATION of
  a weakly-ordered score, not the discovery of hidden ordering.

### F2. Component data gap: the archive cannot see the v3.0 engine

- All 21,627 rows across all 15 telemetry_v2 files carry
  `structureRaw = 0` for every component (verified field-by-field, not
  just the header check).
- The v2 telemetry schema records the LEGACY confluence engine's
  component breakdown (legacyConfidence, direction/quality validator
  results); the v3.0 engine's per-component raw/weight/contribution were
  never persisted by the collector.
- Consequences, applied in the report generator:
  - Sections A (activation/marginal), B (fired-count decomposition) and
    D (ablation replay) are written as `data_gap` rows.
  - Per-component Spearman rows are suppressed - with all-zero arrays the
    first run's identical `+0.6639` values were constant-array artifacts,
    not evidence.
  - H1 (reward amount vs quality) and the CUR table of H2 are
    UNTESTABLE on the archive. Validator-level attribution remains
    available via the validator result columns (covered by the 16.1
    ablation experiments).

### F3. Cap artifact is real but its cause is unobservable (for now)

2,214 rows at exactly 0.60 support a scoring ceiling, but without the
component raw scores (F2) the mechanism - saturation of one component vs
a hard cap - cannot be attributed from telemetry alone.

## Decision

- No calibration adopted in 16.2; 16.1B is a root-cause investigation.
- The weak/absent ordering (F1) is the primary evidence: it explains the
  flat reliability curve of 16.1 without any further component-level
  mechanism.
- Section A/B/D conclusions are deferred until telemetry can capture the
  v3.0 component scores.

## Next steps

1. Collector change: persist the v3.0 engine's per-component
   raw/weight/contribution (schemaVersion 3) so structural sections can
   run on future shadow-mode data (schema v2 rows remain data_gap).
2. Re-collect shadow-mode telemetry for a full window under schema v3,
   then re-run MODE_STRUCTURAL to test H1 (fired-count reward) and H2
   (CUR table) directly.
3. 16.5 gate re-anchor on calibrated scores remains deferred.

## Reproduction

1. Compile `CalibrationRunner.mq5` (mode 7 = `CALIB_INPUT_STRUCTURAL`).
2. Preset: `config\Tester\Sprint16_1B_Structural.ini` +
   `Profiles\Tester\CalibrationRunner.set` (mode 7, filter
   `1D1EF3C650D79C3F`).
3. Launch `terminal64.exe /config:...\Sprint16_1B_Structural.ini`
   (tester run, ShutdownTerminal=1); outputs land in
   `Common\Files\Calibration\`.
4. No unit tests changed in 16.1B; the experiment runner is exercised by
   the existing TestCalibrationReport suite.
