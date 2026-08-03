# Telemetry Schema v3.1 — Versioned Contract (Sprint 20 TC01)

Status: **IMPLEMENTED** (2026-08-03). Schema version: **4**. Row width: **75 columns**.
Task: `TC01` (Sprint 20 Engineering Plan). Scope: **telemetry-only; zero behavioral change**;
all v1/v2/v3 files remain readable (v2 rows were never produced by the v3.0 engine but
remain parseable for legacy diagnostics).

This document is the machine-consumable contract for every producer and consumer of the
telemetry CSV. It follows the frozen contract pattern
(Architecture -> Contract -> Implementation -> Validation) and is append-only:

- Never rename, reorder, or repurpose an existing column.
- New columns are appended at the END and require a `schemaVersion` bump.
- `schemaVersion` is validated against the column count on every row
  (`CalibrationDataset::ParseRow` refuses mismatches).

## 1. Why v3.1 exists (evidence chain)

| Source | Finding |
|---|---|
| Sprint 19.6 FVG doc | `layerStructural` mixes OB (15) and FVG (10) points; the FVG slice of the structural score cannot be measured separately. |
| Sprint 19.6b ledger C16 | FVG classifier (class/size/strength) is dead code — never serialized, never observable. |
| Sprint 19.6b ledger C17 | `UntouchedFVG` rule admits without recency/fill guard; testing the guard requires FVG lifecycle timestamps. |
| Sprint 19.7 synthesis R13 | Funnel inversion (gate reversal) is measurable only if the structural split and FVG lifecycle are observable in the dataset. |
| Sprint 20 plan M1 | Telemetry is the primary failure surface (T01); M1 gates all routing/detector work behind telemetry completeness. |

v3.1 adds the observation layer for these three questions. It changes **no** scoring,
routing, gating, or detector behavior (verified: `CalculateTotalScore` still derives the
same `total` from the same constants; only the split is exposed).

## 2. Schema identity

| Constant | Value |
|---|---|
| `TELEMETRY_SCHEMA_VERSION` | `4` |
| `TELEMETRY_CSV_COLUMNS` (v1/v2) | `45` |
| `TELEMETRY_CSV_COLUMNS_V3` | `68` |
| `TELEMETRY_CSV_COLUMNS_V31` | `75` |
| CSV header constant | `TELEMETRY_CSV_HEADER_V31` |
| EA version | `v3.0` (unchanged — schema bump is not an EA release) |
| Evidence contract | `2026-08` (unchanged) |

## 3. Field list, column order, types, semantics

Columns 1-68 are identical to schema v3 (which was itself append-only over v2).
Columns 69-75 are added in v3.1. `schemaVersion = 4` requires exactly 75 columns;
`3` requires exactly 68; `2` exactly 45; any other version or column count is refused.

### 3.1 Columns 69-75 (added in v3.1)

| # | Column | Type (CSV) | Producer | Consumer | Semantics |
|---|---|---|---|---|---|
| 69 | `layerOrderBlock` | int (0-15) | `ScoreCalculator::CalculateTotalScore` (via `ConfluenceEngine`, rule path & evaluator path) | RowBuilder -> CSV; TC04+ analytics | Order-block slice of `layerStructural`. `SCORE_STRUCTURAL_OB = 15` when `hasOrderBlock`, else 0. Telemetry-only split; `layerStructural` unchanged. |
| 70 | `layerFVG` | int (0-10) | same chain | RowBuilder -> CSV; TC04+ analytics | FVG slice of `layerStructural`. `SCORE_STRUCTURAL_FVG = 10` when `hasFVG`, else 0. |
| 71 | `fvgClass` | string (`REVERSAL` \| `BREAKAWAY` \| `CONTINUATION` \| `UNKNOWN`) | TC04 (currently `"UNKNOWN"`) | TC04+ analytics | FVG class as classified by `FVGDetector` (dead in v3.0; C16). |
| 72 | `fvgSize` | string (`SMALL` \| `MEDIUM` \| `LARGE` \| `UNKNOWN`) | TC04 (currently `"UNKNOWN"`) | TC04+ analytics | `sizeCategory` from `FVG_SIZE_*` thresholds (3.0 / 10.0 pips). |
| 73 | `fvgStrength` | string (`WEAK` \| `NORMAL` \| `STRONG` \| `UNKNOWN`) | TC04 (currently `"UNKNOWN"`) | TC04+ analytics | `strength` from `FVG_STRENGTH_BODY_*` thresholds (5.0 / 15.0 pips). |
| 74 | `fvgCreatedTime` | datetime (`yyyy.MM.dd HH:mm:ss`, `0` when absent) | TC04 (currently `0`) | C17 guard studies | Gap creation time (first bar of the wick-to-wick gap). |
| 75 | `fvgFillTime` | datetime (`yyyy.MM.dd HH:mm:ss`, `0` when absent) | TC04 (currently `0`) | C17 guard studies | Gap fill time (when price trades through the gap). `0` = unfilled at signal. |

### 3.2 Deprecated / reserved columns

None were removed. Reserved by prior contracts (must stay empty until used):

| Column(s) | Note |
|---|---|
| `actualOutcome`, `actualOutcomeSource` | Reserved for future outcome replay; never repurposed. |
| Legacy component raws (`structureRaw`..`pdContribution`) | **TC02 (2026-08-03): populated at decision time.** Rule path: derived from the layer split already computed (`BuildRuleComponents`; `contribution = raw * weight / 100`, configured `ConfluenceWeights`). Evaluator path: scores/weights/contributions from `CConfluenceScoreCalculator`. **Engine-unsettled rows** (signal `score.total == 0`, e.g. shadow-rejected decisions whose latest signal was never scored): the split stays all-`0` — the row must not claim component evidence without a layer result backing it (`BuildWithEvidence` zeroes the split in this case). v3 (pre-wiring) files carry `0`; v4 rows are enforced split-consistent by `LegacyRowConsistent`. |
| `ruleName`/`ruleScore`/`ruleConfidence` on non-evidence rows | `""`/`0`/`0` when `componentData = 0`. |

## 4. Producer / consumer matrix

| Role | File | v3.1 behavior |
|---|---|---|
| Producer | `Telemetry/TelemetryTypes.mqh` | Struct fields + ctor defaults (`fvgClass/Size/Strength = "UNKNOWN"`, times `0`); `TELEMETRY_CSV_HEADER_V31`; version `4`. |
| Producer | `Telemetry/TelemetryRowBuilder.mqh` | `BuildWithEvidence` copies `score.layerOrderBlock/layerFVG`; classifier fields stay `UNKNOWN`/`0` until TC04. |
| Producer | `Telemetry/TelemetryCollector.mqh` | `WriteHeader` emits `TELEMETRY_CSV_HEADER_V31`; `WriteRow` appends the 7 columns. |
| Producer | `Telemetry/TelemetryHealthReport.mqh` | `SerializeRow` mirrors the collector (75 columns). |
| Consumer | `Telemetry/CalibrationDataset.mqh` | `ParseRow` accepts v4/75; v3/68 and v2/45 still parse; version/column mismatch refused. |
| Consumer | `Telemetry/TelemetryHealthReport.mqh` | Schema gate = 100% v3+ (v3 + v4 both count); round-trip audits v4 rows only; v3-only files stay healthy. |
| Consumer | `Calibration/ExperimentRunner.mqh` | `schemaVersion >= 3` gates evidence diagnostics; v4 rows flow through unchanged. |
| Consumer | `SignalTypes.mqh` / `ScoreCalculator.mqh` | `ScoreLayer.layerOrderBlock/layerFVG` (split) + `LayerResult` — additive, no semantic change. |
| Consumer | `Confluence/ConfluenceEngine.mqh` | Copies the split into the signal score (rule path + evaluator path); **TC02**: `m_latestConfluence.components/componentCount` populated at decision time on the rule path (evaluator path preserved). |
| Consumer | `Confluence/ScoreCalculator.mqh` | **TC02**: `BuildRuleComponents` free function derives the 6 legacy component rows from `ScoreLayer` + `ConfluenceWeights`. |
| Consumer | `Telemetry/TelemetryHealthReport.mqh` | **TC02**: `LegacyRowConsistent` enforces split invariants on v4 rows (raw-slice invariant for the rule path; contribution-slice invariant for the evaluator path); v3 rows keep the zero-raws contract. |

## 5. Validation (TC01 acceptance)

| Criterion | Evidence |
|---|---|
| Round-trip: serialize -> parse -> serialize identical | `TestTelemetryHealth` perfect dataset + `RoundTripRow` (v4 only). |
| Schema health gate passes on v4 files, still passes on v3 files | `TestHealth_LegacyV3FileStillLoads`, `TestHealth_MixedV3V4Rows`. |
| v2/v3 files load unchanged | `TestParse_V2BackwardCompatible`, `TestParse_V3EvidenceRoundTrip`. |
| Version/column mismatches refused | `TestParse_RefusesUnknownVersions` (v5 refused, 76/68-col v4 refused, 67-col v3 refused). |
| Header contract | `TestHeader_V31ColumnCount` (75 cols, append-only over v3, trailing `fvgFillTime`). |
| Zero behavioral change | No scoring/gating/detector constant or code-path changed; `TestRegression` (frozen) unchanged. |
| Row builder split | `TestRowBuilder_LayerSplit` (OB 15 + FVG 10 -> `layerStructural` 25). |
| TC02: rule-path components populated at decision time | `BuildRuleComponents` unit tests (BOS+OB, liquidity-sweep, trend-bonus, empty layers) in `TestConfluenceEngine`. |
| TC02: v4 split invariants enforced by the health gate | `TestHealth_ContribInvariant` (evaluator-path contributions), `TestHealth_LegacyInconsistent` (split violation flagged), `TestHealth_LegacyV3FileStillLoads` (v3 zero-raws contract preserved). |

## 6. Follow-ups

- **TC02** (raw evidence wiring), **TC03** (protected-point evidence), **TC04** (populate
  `fvgClass/Size/Strength` + gap timestamps) are required to complete M1 (Telemetry
  Complete); until TC04 the classifier columns carry their defined defaults.
- Historical re-runs (doc 06 numbers) are reproducible after TC04 from the same frozen
  telemetry; v3 files remain the ground truth for pre-TC04 periods.
