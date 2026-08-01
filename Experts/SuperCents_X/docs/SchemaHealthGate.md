# Schema Health Gate (Sprint 17, Step 6)

## Purpose

The Schema Health Gate validates that a telemetry dataset is *structurally
trustworthy* before any downstream analysis consumes it. It answers one
question:

> "Is this telemetry dataset structurally trustworthy enough to use
> downstream?"

It does **not** evaluate strategy quality (expectancy, PF, drawdown).
Those belong to Calibration, Structural Diagnostics, and the Promotion Gate.

## Pipeline Position

```
Telemetry Collection -> Schema Health Gate -> Structural Diagnostics
    -> Architecture Research -> Calibration -> Promotion
```

The gate is the boundary between "we collected data" and "we trust the data".
Running it before the six-month collection (Step 7) is mandatory: it costs
nothing to run, and it catches schema/serialization defects while they are
cheap to fix.

## How It Works

`CTelemetryHealthAnalyzer::Analyze()` performs a single pass over a loaded
`CCalibrationDataset` and produces a `TelemetryHealthReport`:

| Check | Weight | Passes when |
|---|---|---|
| schemaVersion | 15 | 100% of rows are v3 |
| parse success | 15 | no refused lines, no unexpected enum values |
| component coverage | 15 | componentData == 1 on >99% of decided rows |
| missing layers | 10 | zero component rows where a rule FIRED but layerTotal == 0 |
| missing evidence | 10 | zero component rows with all flags EV_UNKNOWN |
| MISSING markers | 10 | zero literal "MISSING" occurrences in string fields |
| round-trip | 15 | serialize -> parse -> serialize -> parse preserves values |
| legacy consistency | 10 | v3 evidence rows carry zero legacy component raws |

Score = weighted sum (max 100). Verdict:

| Score | Verdict |
|---|---|
| >= 95 | PASS |
| 80 .. 94 | WARN |
| < 80 | FAIL |

The round-trip check samples up to 100 rows (configurable) and re-serializes
each through the real CSV pipeline — the same path that caught the unquoted
`ruleEvidenceIds` ("1,4") serialization bug during Sprint 17.

Component coverage, missing layers/evidence, layer distribution and the
round-trip check are **v3-only** metrics: legacy v2 rows are excluded from the
denominators and the round-trip sample (the v3 serializer always emits the
68-column shape, so v2 lines cannot be re-serialized). Mixed v2 + v3
directories are flagged by the `schemaVersion` check alone.

Rule-0 (no-signal) component rows are exempt from the missing-layers check:
`componentData == 1` is stamped on every evaluated bar, but when no rule fires
the score is all-zero, so `layerTotal == 0` is expected there (the sanity-week
run had 109 such rows, 22.8% of the dataset). Only rows where a rule fired but
the layers were never stamped count as missing.

## How To Run

1. Compile `CalibrationRunner.mq5`.
2. Set the tester inputs (`CalibrationRunner.set`, UTF-16):
   ```
   CalibrationMode=8
   TelemetryDirectory=Telemetry
   ReportDirectory=Calibration
   FingerprintFilter=1D1EF3C650D79C3F
   ```
3. Run a 1-day tester pass (the mode is fully offline; it reads the stored
   telemetry files and writes reports — no trading needed).
4. Collect the artifacts in `Common\Files\Calibration\`:
   - `calib_schema_health_<timestamp>.txt` — human-readable card
   - `calib_schema_health_<timestamp>.csv` — all metrics, per-rule rows
   - `schema_health.json` — minimal CI-oriented summary (stable path)
   - `calib_schema_health_<timestamp>.manifest` — run provenance

Notes:

- The gate runs once across the **entire dataset**, not per fingerprint:
  schema health is a property of the dataset, and fingerprint partitioning
  would hide systemic problems. Mixed v2 + v3 directories therefore report
  `schemaVersion` as failing until the v2 files are archived separately.
- To gate only the v3 collection, point `TelemetryDirectory` at a
  subfolder containing just the v3 files (e.g. `TelemetryV3`).

## Schema Health Report (quality summary)

The `.csv` artifact contains everything needed to approve Step 7:

- Total / parsed / refused rows, parse success rate
- Rows with componentData == 1, decided rows, component coverage
- Rows with missing layer values, rows with missing evidence flags
- Per-flag coverage (hasBOS, hasCHOCH, hasOrderBlock, hasFVG,
  hasProtectedPoint, hasLiquiditySweep)
- Distinct evidence combinations observed
- Per-rule frequency and per-rule component coverage
- MISSING marker count, unexpected enum count, round-trip failures
- Layer min/mean/max distribution

## Pass Criteria Before Step 7 (six-month collection)

The gate verdict for the v3-only dataset must be **PASS**, meaning:

- schemaVersion == 3 on every row
- componentData == 1 on every decision row
- layer fields non-zero where a rule fired; no systematic zeros
- evidence ids correctly quoted and parsed (round-trip clean)
- legacy columns populated with unchanged semantics (v2 files untouched)
- zero MISSING markers
- parse round-trip CSV -> dataset -> CSV preserves values

Only then is the six-month collection worth starting: a clean gate today is
the cheapest possible guarantee that the 6-month dataset will be usable.

## Related

- `Telemetry/TelemetryHealthReport.mqh` — analyzer + renderers
- `Calibration/ExperimentRunner.mqh` — `CALIB_MODE_SCHEMA_HEALTH` (mode 8)
- `Tests/unit/TestTelemetryHealth.mqh` — gate contract tests
- `docs/Sprint17_SchemaV3_Design.md` — schema v3 contract that the gate guards
