# Sprint 17 - Evidence Capture: Telemetry Schema v3 Design

Status: **DRAFT - ARCHITECTURAL CONTRACT** (2026-08-01). No code changes
until this document is reviewed. Applies the frozen contract pattern:
Architecture -> Contract -> Implementation -> Validation.

Supersedes the original "Confidence Architecture" plan for Sprint 17:
the objective is no longer to improve the score, it is to make the score
explainable. Renamed: **Evidence Capture**.

## 1. Why v3 exists (evidence chain)

Three successive, frozen findings make the current schema insufficient:

1. **Sprint 16.1A** (measurement): raw v3.0 confidence is compressed to
   [0.35, 0.60] (6 of 21 bins populated, P90 = 0.60) and reliability is
   flat; ECE 0.1265, Brier 0.2425, MCE 0.3327.
2. **Sprint 16.2** (transforms): isotonic, Platt and temperature all
   fail for fundamentally different reasons (isotonic: unanchored
   endpoints and zero trades at 0.60; Platt: negative slope; temperature:
   no effect on a flat score). Conclusion: the problem is not
   post-processing.
3. **Sprint 16.1B** (structural): ordering power is weak at best
   (Spearman +0.207 / Kendall -0.043 on 12,130 decided rows), and all
   21,627 rows across all 15 telemetry files carry zero component scores.

The decisive finding is #3's second half: **the evidence needed to
explain the score was never captured.** The v2 schema records the LEGACY
6-component weighted model (structure/OB/FVG/liquidity/trend/PD), but the
v3.0 engine scores with a different architecture (rule + layer model).
The legacy columns are always zero in v3.0 rows.

The research loop today is Entry -> Confidence -> Outcome. v3 exists to
insert the missing observation layer:

    Entry -> Component scores -> Confidence -> Outcome

Until that middle layer exists, questions like "which evaluator
dominates?", "which combinations are predictive?" and "why does
confidence cap at 0.60?" are unanswerable from the dataset, and any
architecture decision would be based on missing evidence.

## 2. The v3.0 scoring architecture (ground truth for the contract)

The design must capture observations of the REAL architecture, not the
schema's current assumption. Facts from the code (`ScoreCalculator.mqh`,
`SignalTypes.mqh`, `ConfluenceEngine.mqh`):

- The v3.0 score is computed for the single best-matched rule
  (`RuleResult`: type, score, confidence, evidenceIds, evidenceCount).
- `CalculateRuleLayers` produces `ScoreLayer { structural, liquidity,
  confirmation, total }` (ints, 0-100) from rule type + evidence flags +
  trend alignment.
- `confidence = score.total / 100` - an int-derived value, which is why
  the observed confidence distribution is nearly discrete.
- Layer constants: structural <= 50 (BOS 15, OB 15, FVG 10, CHOCH 20),
  liquidity <= 30 (swept 30), confirmation <= 20 (2 evidence +10, 3
  evidence +10, trend aligned +5).
- **The 0.60 ceiling is a composition ceiling of these constants** (e.g.
  Liquidity+BOS with trend = 15 + 30 + 10 + 5 = 60), NOT an `fmin` cap
  at 60. The cap is hard to reach because every rule type combines at
  most a subset of the evidence.
- The score is **deterministic in the evidence**: persisted flags
  (hasBOS, hasCHOCH, hasOrderBlock, hasFVG, hasProtectedPoint,
  hasLiquiditySweep) + trendAligned reconstruct the full layer
  decomposition offline. No per-row confidence recomputation is needed.
- The legacy 6-component weighted model (weights 25/20/15/15/15/10) is a
  SEPARATE model that v3.0 does not compute; its columns must not be
  conflated with v3.0 components.

## 3. New telemetry contract (schemaVersion = 3)

Append-only migration: all 45 v2 columns stay at their positions;
new columns are appended. Column order is frozen once collection starts.

### 3.1 Metadata (new columns)

| Field | Type | Values | Purpose |
|---|---|---|---|
| scoreArchitecture | string | "v3.0" | scoring model; NOT changed by this sprint |
| componentData | int | 0/1 | 1 = this row carries component/rule evidence |
| telemetryArchitecture | string | "rule-layer" | decomposition model of componentData |

`schemaVersion = 3` is written in the existing first column. The score
itself is untouched (v3.0); only the observation layer changes.

### 3.2 Rule-level evidence (new columns)

| Field | Type | Purpose |
|---|---|---|
| firedRuleId | int | RuleType of the best matched rule (7 rules) |
| ruleScore | int (0-100) | rule score BEFORE any weighting |
| ruleConfidence | double (0-1) | rule confidence before weighting |
| ruleEvidenceCount | int | number of evidence items in the rule |
| ruleEvidenceIds | string | packed "id1,id2,..." (evidence identifiers) |
| trendAligned | int | 0/1 - trend alignment bonus flag |

### 3.3 Layer-level components (new columns)

The v3.0 decomposition (the "components" of this architecture):

| Field | Type | Purpose |
|---|---|---|
| structuralRaw | int (0-50) | layer score before normalization |
| liquidityRaw | int (0-30) | layer score before normalization |
| confirmationRaw | int (0-20) | layer score before normalization |
| layerTotal | int (0-100) | raw total (= 100 * confidence) |

Active component count and per-layer contribution are DERIVED from these
(do not store derived metrics). Note: there is no per-layer weighting in
this model - contribution == raw; weights exist only in the legacy model
(already captured in the v2 columns).

### 3.4 Evidence flags (new columns)

hasBOS, hasCHOCH, hasOrderBlock, hasFVG, hasProtectedPoint,
hasLiquiditySweep (int 0/1 each). These are the raw inputs to the layer
score and make the decomposition reproducible offline.

### 3.5 Legacy columns (existing, unchanged semantics)

The 18 legacy component columns (structureRaw/Weight/Contribution etc.)
remain at their positions. They are observations of the LEGACY model
and must continue to be populated only when the legacy engine runs.
Downstream component analysis must key off `telemetryArchitecture`, not
column names.

### 3.6 Observations, not derivations

Every new field is an observation recorded at decision time. Anything
computable from the persisted fields (layer decomposition, active
counts, contributions) is reconstructed by the analysis layer.

## 4. Compatibility rules (must not be violated)

1. **v2 datasets cannot perform component attribution.** Schema v2 rows
   carry no rule/layer evidence; any component analysis on them is
   invalid (16.1B proved this empirically - all raws zero).
2. **Structural diagnostics must refuse schemaVersion < 3.**
   `CalibrationStructural` and the 16.1B report sections A/B/D must
   require `schemaVersion == 3 && componentData == 1` for all rows in
   the dataset; otherwise emit `data_gap` (mechanism already exists
   from 16.1B).
3. **Calibration reports continue to work on v2.** Threshold sweeps,
   transforms and the calibration baseline consume only confidence +
   outcome columns; they are unaffected by v3 columns.
4. **PromotionGate remains schema-agnostic.** The gate consumes only
   settled confidence/outcome stats; it must not read component columns.
5. **Report manifests must record `telemetryArchitecture`** so any
   downstream report can refuse to perform component analysis on the
   wrong schema without relying on file naming.

## 5. Questions schema v3 must be able to answer

Field filter: a proposed field only belongs in the schema if it helps
answer at least one question below.

| Question | Answerable with |
|---|---|
| Which component contributes most to winning trades? | layer raws (3.3) + outcome |
| Does more confluence imply higher win probability? | ruleEvidenceCount + confidence + outcome |
| Which rule combinations outperform individual rules? | firedRuleId + ruleEvidenceIds + outcome |
| Why does confidence rarely exceed 0.60? | layer raws distribution per rule type (composition ceiling verification) |
| Which evaluator contributes least information? | layer raws + evidence flags + outcome |
| Is the 16.2 Platt negative slope a real signal? | rule-level confidences pre/post weighting + outcome |

If a field does not feed any row above, it is out of scope for v3.

## 6. Collection plan and exit criteria

Minimum evidence required before revisiting confidence architecture:

| Window | Instrument | Timeframe |
|---|---|---|
| 6 months | EURUSD | M15 |
| 6 months | EURUSD | H1 |
| 6 months | GBPJPY | H1 |

Exit criteria for the collection phase:

- Component coverage > 99% of decided rows (`componentData == 1`).
- Zero `MISSING` component rows (report card field from 16.1B must read
  `components: present`).
- schemaVersion == 3 on every row.

Only then rerun, in order: structural diagnostics -> confidence
architecture review -> calibration -> promotion gate. Calibration moves
later in the sequence because the dataset now supports the structural
analysis that must precede it.

## 7. Versioning discipline

- Every row carries `schemaVersion`, `componentData`, `confidenceModel`
  (raw for all v3 rows), `scoreArchitecture` (v3.0).
- Manifests carry the same metadata plus dataset fingerprint and the
  collection window (pattern established in 16.1).
- Any future schema change is append-only with a schemaVersion bump; the
  reader (`CalibrationDataset::ParseRow`) refuses unknown versions
  explicitly (today it refuses anything != 2).
- schemaVersion and eaVersion move independently: the score stays v3.0
  while the EA version that collects it may become v3.1.

## 8. Sequencing (evidence trail)

```
Sprint 16.1B (complete: data gap proven)
   |
   v
Schema v3 design (THIS DOCUMENT)       <- review gate
   |
   v
Schema v3 implementation (collector + types + dataset reader + refusal)
   |
   v
6-month collection (exit criteria in section 6)
   |
   v
Structural diagnostics (v3-aware report)
   |
   v
Confidence architecture review
   |
   v
Calibration
   |
   v
Promotion Gate
```

## 9. Out of scope for this document

- The score itself (unchanged: confidenceModel raw, scoreArchitecture
  v3.0).
- Any transform or calibration change (16.2 evidence rejected them).
- The collector implementation details (separate contract follows
  review of this document).
