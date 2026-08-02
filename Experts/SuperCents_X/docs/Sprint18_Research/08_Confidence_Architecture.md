# 18.8 - Confidence Architecture Review

Status: **REVIEW COMPLETE** (2026-08-02). This document executes the
official "confidence architecture review" step of the Sprint 17 Schema
v3 sequencing contract (`docs/Sprint17_SchemaV3_Design.md` sections 5,
6 and 8). It answers the six questions section 5 requires the v3 schema
to answer, verifies the architectural claims of section 2 against the
frozen evidence dataset, confirms the section 6 exit criteria are met,
and recommends a concrete confidence architecture for Sprint 19.

Methodology: the locked 8-phase pattern (Foundation, Academic,
Professional, Institutional/Quant, Open-source, SuperCents_X code
review, Sprint 17 evidence, Experiment Backlog). Phases 1-5 never
reference SuperCents_X.

Evidence dataset (frozen, fingerprint
`2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`):
19 merged v3 files, 18,686 rows; decided+signal 17,073; binary
(WIN/LOSS, BE excluded) 17,068; base rate 0.3322.

---

## 1. Foundation - the review contract

### 1.1 What the Schema v3 design promised

The v3 collection phase exists so that the score becomes *explainable*
before it is improved. Section 8 of the design doc fixes the sequence:

    Structural diagnostics -> Confidence architecture review -> Calibration -> Promotion Gate

and section 6 fixes the exit criteria that must hold before this review
may run:

| Exit criterion | Measured (18.1) | Met |
|---|---|---|
| Component coverage > 99% of decided rows (`componentData == 1`) | 100% (17,073/17,073) | YES |
| Zero `MISSING` component rows | 0 | YES |
| `schemaVersion == 3` on every row | 100% | YES |

### 1.2 The six questions section 5 requires this review to answer

| # | Question | Answered in |
|---|---|---|
| Q1 | Which component contributes most to winning trades? | 7.1 |
| Q2 | Does more confluence imply higher win probability? | 7.2 |
| Q3 | Which rule combinations outperform individual rules? | 7.3 |
| Q4 | Why does confidence rarely exceed 0.60? | 7.4 |
| Q5 | Which evaluator contributes least information? | 7.5 |
| Q6 | Is the 16.2 Platt negative slope a real signal? | 7.6 |

### 1.3 What "confidence" means in this architecture

Ground truth from the code (`ScoreCalculator.mqh`,
`ConfluenceEngine.mqh`, `SignalTypes.mqh`), stated once here and reused
by every later section:

- The score is computed for the single best-matched rule
  (`RuleResult { type, score, confidence, evidenceIds, evidenceCount }`).
- `CalculateRuleLayers` produces `ScoreLayer { structural, liquidity,
  confirmation, total }` (ints, 0-100).
- `confidence = layerTotal / 100` - an int-derived value, hence the
  nearly discrete distribution (exactly 6 distinct values observed in
  the whole dataset: 0.35 / 0.40 / 0.45 / 0.50 / 0.55 / 0.60).
- Layer constants (frozen): structural <= 50 (BOS 15, OB 15, FVG 10,
  CHOCH 20), liquidity <= 30 (swept 30), confirmation <= 20 (2 evidence
  +10, 3 evidence +10, trend aligned +5).
- The legacy 6-component weighted model (25/20/15/15/15/10) is a
  SEPARATE model, not computed by v3.0, and its v2 columns are always
  zero in v3 rows.

The v3 collection succeeded: the layer decomposition is reconstructed
from the persisted `layer*` columns and the flags with zero loss
(18.5: confidence == layerTotal/100 on all 17,073 rows, 0 mismatches).

---

## 2. Academic - probability calibration

### 2.1 Foundations of forecast calibration

- **Brier (1950)**: expected squared error between forecast and
  outcome. Decomposes into reliability (calibration) + resolution
  (sharpness) + uncertainty. A forecast that cannot beat the always-
  mean forecast is no better than no forecast; a forecast that *loses*
  to it is actively misleading.
- **DeGroot & Fienberg (1983)**: calibration is not sufficient for a
  forecast to be good - sharpness (resolution) must accompany it. A
  constant forecast of the base rate is perfectly calibrated and
  worthless. Assessment must be joint (calibration + resolution).
- **Naeini, Cooper & Hauskrecht (2015)**: ECE partitions predictions
  into bins, compares mean confidence to empirical frequency per bin,
  and averages weighted by bin size. MCE is the worst bin - used to
  detect localized failure, not average failure. Both are sensitive to
  binning choice; per-value ECE is exact for discrete scores.
- **Guo, Pleiss, Sun & Weinberger (2017)**: neural calibrators are
  overconfident; temperature scaling is a one-parameter fix. Key
  transferable lesson: the calibration *target* is the empirical
  frequency, and it must be measured on held-out data.

### 2.2 Calibration transforms - what the literature actually says

- **Platt (1999)**: logistic mapping of a score to probability. Fails
  when the score is not monotone in the event probability (the negative
  slope failure of Sprint 16.2).
- **Zadrozny & Elkan (2002)**: isotonic regression as non-parametric
  calibration; the correct tool when score order is meaningful but the
  mapping is unknown. Requires monotonicity of the input score - if the
  input is anti-ordered, isotonic regression converges to a constant.
- **Kuleshov, Fenner & Ermon (2018)**: sequential/regression
  calibration; highlights that calibration must be evaluated on the
  distribution the model will actually face (regime-dependent).

### 2.3 Implication for a discrete score architecture

The score is deterministic in a small set of evidence flags. This makes
it a **finite-state score** (6 values). For finite-state scores:

1. The correct calibration object is the per-state empirical frequency,
   estimated on held-out data; ECE over the discrete values is exact.
2. Monotonicity is a *requirement on the architecture* (the state-to-
   probability map must be isotone), not a property of a post-processor.
3. Per-family state frequencies (family x confidence) are the natural
   granularity when states are constructed by family constants.

---

## 3. Professional - confidence in trading systems

### 3.1 How trading systems use confidence

- **Directional use**: confidence as a trade filter (enter only above a
  threshold). This is the SuperCents_X usage (the EA's confidence gate).
  Requires monotone ordering: higher score must mean higher win
  probability, else the filter trades the anti-edges.
- **Sizing use**: confidence as position-size input (fixed-fraction,
  Kelly variants). Requires calibrated probabilities, not just order.
- **Ranking use**: confidence to choose among simultaneous candidates.
  Requires only relative order; but if the candidates come from
  different rule families, ranking inherits the family constants and
  becomes family-vs-family selection (measured: selection between
  families is anti-calibrated, see 7.4).

### 3.2 Professional failure modes

- Composition-inherited bias: hand-tuned additive weights carry the
  designer's prior, which is frequently anti-correlated with measured
  frequency (observed here: the highest-confidence state is the worst).
- Evaluation on live-score distributions without held-out splits
  (calibration must be out-of-sample; 18.13 will fix the protocol).
- Selection-vs-calibration confusion: a system can be well-selected
  (always firing the best family) while being badly calibrated (the
  score values lie); the two must be measured separately.

---

## 4. Institutional / Quant - governance of probability claims

- **Basel-style model risk governance**: any probability estimate that
  feeds capital allocation must pass a documented validation loop:
  independent estimate -> empirical validation on held-out data ->
  remediation. The equivalent here: the confidence must be validated
  per family and per state, with the evidence trail in the docs.
- **Quant practice on discrete event models**: when the model is
  deterministic in its inputs (no sampling noise), the only uncertainty
  is *model error*, so the empirical frequency per state is the
  probability; the confidence should BE that frequency, not a
  constructed constant.
- **Calibration-to-decision contract**: a threshold gate is only
  well-defined on a calibrated score; on an anti-calibrated score a
  "higher threshold = higher quality" policy inverts into a loss
  multiplier (measured in 7.4: every increment of the threshold lowers
  win rate).

---

## 5. Open-source - calibration tooling

- **scikit-learn**: `calibration_curve` (bin per-confidence vs
  frequency), `IsotonicRegression`, `SigmoidCalibration`; the reference
  open implementations of ECE-style reliability diagrams and of the
  Platt/isotonic transforms used in Sprint 16.2.
- **netcal / Mapie / uncertainty-toolbox**: ECE/MCE implementations
  with discrete-value support; the per-value ECE used in section 7.6
  follows this practice.
- **Concrete lesson**: none of these tools fixes an anti-ordered score;
  they document it. The fix is architectural (constants/mapping), not
  a fitted post-processor. This matches the 16.2 conclusion (isotonic,
  Platt, temperature all fail) and re-derives it with the v3 evidence.

---

## 6. SuperCents_X code review - the confidence chain

### 6.1 The full score chain (measured provenance)

    Evidence detectors (BOS/CHOCH/OB/FVG/Liquidity)
      -> ConfluenceRules.mqh: 7 fixed rules, each with a-priori
         ruleScore (70-90) and ruleConfidence (0.75-0.95)
      -> ConfluenceEngine.mqh:322-326: selects bestRule by score;
         hasProtectedPoint hardcoded false (:323)
      -> ScoreCalculator.mqh: CalculateRuleLayers -> layerTotal
      -> confidence = layerTotal / 100
      -> TelemetryRowBuilder.mqh:145-158: confidence, ruleScore,
         ruleConfidence, layer* serialized per row

### 6.2 The layer constants (the thing being reviewed)

| Evidence | Layer | Points | Notes |
|---|---|---|---|
| BOS | structural | 15 | |
| OB | structural | 15 | |
| FVG | structural | 10 | |
| CHOCH | structural | 20 | highest structural weight |
| liquidity swept | liquidity | 30 | one flag = 30 points |
| 2 evidence items | confirmation | 10 | evidenceCount always 2 |
| trendAligned | confirmation | +5 | |

Composition produces exactly the observed 6 states (verified against
the dataset, no other values exist):

| State | Composition | n | measured wr |
|---|---|---|---|
| 0.35 | OB 15 + FVG 10 + 10 (CHOCH/BOS absent) | 3,383 | 0.3521 |
| 0.40 | OB_FVG 25 + 10 + 5 aligned | 9,200 | 0.3350 |
| 0.45 | BOS_OB 30 + 10 + 5 aligned / CHOCH_OB 35 + 10 | 856 | 0.3668 |
| 0.50 | CHOCH_OB 35 + 10 + 5 aligned | 76 | 0.3816 |
| 0.55 | LIQUIDITY 15 + 30 + 10 (not aligned) | 375 | 0.2453 |
| 0.60 | LIQUIDITY 15 + 30 + 10 + 5 aligned | 3,178 | 0.3027 |

### 6.3 Architectural facts relevant to the review

1. **The 0.60 ceiling is a composition ceiling** (design doc section 2
   is confirmed): no rule type combines structural > 30 with liquidity
   30; the family constants fix the maximum reachable state per rule,
   and the global maximum (LIQUIDITY+aligned = 60) is also the family
   with the *lowest* measured win rate (see 7.1). The system cannot
   express a higher-confidence state even with all seven evidence types
   simultaneously true - there is no rule combining e.g. BOS+OB+FVG+
   sweep (15+15+10+30+10+5 = 85).
2. **ruleEvidenceCount == 2 on every row**: every rule is a fixed pair
   of evidence items; the "confluence" dimension has zero variance in
   the dataset. Q2 is therefore unanswerable from current data (7.2).
3. **ruleConfidence (0.75-0.95) and ruleScore (70-90) are a-priori
   constants**, unrelated to measured frequencies; they participate in
   selection only (bestRule = highest score). The decision confidence
   shown to the EA is the layer-derived value, NOT ruleConfidence
   (18.7: the two are disjoint columns; ruleConfidence is the prior,
   confidence is the composition).
4. **Selection vs confidence decoupling**: the EA gates on `confidence`
   but selection happens on `ruleScore`. The two orders disagree
   (7.4), so the EA can be asked to reject exactly the rows selection
   prefers.
5. **The evaluator path is dormant** (18.7): `RegisterEvaluator` is
   only called in benchmarks/unit tests (BenchmarkConfluence.mqh:221,
   290-295; TestConfluenceEngine.mqh:289-324); `BridgeConfluenceToSignal`
   would set `bestRule.type = RULE_NONE`, breaking v3 telemetry. The
   per-evaluator scores (structureRaw etc.) are zero in every v3 row.
   Q5 therefore cannot be answered from the dataset (7.5) - by design,
   v3 captures the rule/layer model, not the legacy evaluator model.
6. **Determinism**: confidence is a pure function of the persisted
   flags; the layer columns are redundant (reconstructible), as the
   design promised. This makes the calibration object unambiguous.

---

## 7. Sprint 17 evidence - the six questions, answered

### 7.1 Q1: Which component contributes most to winning trades?

The "components" of this architecture are the layer values, and each
rule family is a fixed layer configuration (18.5, verified again in
18.8: layerStructural crosstab is exactly {LIQUIDITY 15, OB_FVG 25,
BOS_OB 30, CHOCH_OB 35} with zero mixing). Component attribution
therefore reduces to family attribution:

| Family (layer config) | n | wr | mean conf | structural | liquidity | confirmation |
|---|---|---|---|---|---|---|
| BOS_OB (30) | 858 | 0.3730 | 0.434 | 30 | 0 | 10/15 |
| OB_FVG (25) | 12,320 | 0.3387 | 0.386 | 25 | 0 | 10/15 |
| CHOCH_OB (35) | 342 | 0.3567 | 0.461 | 35 | 0 | 10/15 |
| LIQUIDITY (15) | 3,553 | 0.2967 | 0.594 | 15 | 30 | 10/15 |

Answer: **the liquidity layer is the decisive negative component**.
Its 30 points buy 0.2967 win rate and a 0.594 mean confidence - the
worst rate at the highest confidence in the whole dataset. The
structural layer contributes positively but the constant ordering
within it is also anti-measured: CHOCH (20 points, family wr 0.3567)
is weighted highest yet underperforms BOS (15 points, family wr
0.3730). At the confirmation layer, +5 (trendAligned) is worth
-1.5 pp in aggregate (10 -> 0.3434 n=4,295; 15 -> 0.3283 n=12,778) -
again anti-monotone (composition effect, 18.7).

### 7.2 Q2: Does more confluence imply higher win probability?

**Unanswerable from the dataset - and this is itself a finding.**
`ruleEvidenceCount == 2` on all 17,073 rows. Every rule is a fixed
pair; there is no 1-evidence or 3-evidence variant in production. The
"more confluence" hypothesis requires variance in the evidence count
(or in coexistence of evidence items), which the rule set never
produces. The question is answered negatively only in the sense that
the architecture *cannot* express more confluence than 2 items:
evidence flags are one-hot in the rules (a rule either evaluates an
evidence or not; nothing counts two items of the same type, and no
rule evaluates three types). Coexistence telemetry (18.7 E7) is the
prerequisite to ever answering this question.

### 7.3 Q3: Which rule combinations outperform individual rules?

No individual-rule (single-evidence) signals exist in production - all
rows are the 7 fixed pairs. Within the pairs the ranking is stable
across all 18.1-18.7 analyses:

    0.3730  BOS_OB           (best)
    0.3567  CHOCH_OB
    0.3387  OB_FVG
    0.2967  LIQUIDITY_BOS    (worst)

Answer: BOS_OB outperforms OB_FVG despite doctrine (18.6) treating
OB+FVG as the highest-conviction zone; LIQUIDITY_BOS underperforms
every OB-containing combination. Family-conditioned measurement is
required before any "combination beats single" claim - the question
needs coexistence and single-evidence variants (18.7 E1/E7).

### 7.4 Q4: Why does confidence rarely exceed 0.60?

Confirmed and deepened: **the 0.60 ceiling is a composition ceiling**,
not a cap. The maximum reachable state per rule type:

| Rule family | structural | liquidity | confirmation max | max state |
|---|---|---|---|---|
| LIQUIDITY_BOS | 15 | 30 | 15 | 0.60 |
| BOS_OB | 30 | 0 | 15 | 0.45 |
| CHOCH_OB | 35 | 0 | 15 | 0.50 |
| OB_FVG | 25 | 0 | 15 | 0.40 |

The highest-achievable state belongs to the worst family. The 6-state
distribution of the dataset is exactly the union of these maxima and
their non-aligned variants. The deeper architectural consequence: no
rule combines structural evidence with liquidity evidence beyond the
single LIQUIDITY_BOS pairing, so the layer system cannot express
high-confidence states for the good families, and the good families
can never be gated at high thresholds (they peak at 0.40-0.50).

**Gate behavior (measured, binary outcomes):**

| Threshold | n | wr | lift |
|---|---|---|---|
| >= 0.35 | 17,068 | 0.3322 | 0.0000 |
| >= 0.40 | 13,685 | 0.3273 | -0.0049 |
| >= 0.45 | 4,485 | 0.3115 | -0.0207 |
| >= 0.50 | 3,629 | 0.2984 | -0.0338 |
| >= 0.55 | 3,553 | 0.2967 | -0.0355 |
| >= 0.60 | 3,178 | 0.3027 | -0.0295 |

**Every threshold increment lowers the win rate.** The EA's confidence
gate, if raised, would systematically trade the worst rows. This is
the single most actionable finding of the review.

### 7.5 Q5: Which evaluator contributes least information?

**Unmeasurable**: the evaluator path is dormant in production
(6.3.5); per-evaluator columns are zero in all v3 rows. The v3 schema
by design captures the rule/layer model, so the legacy evaluator
columns carry no information. The honest answer: the *layer* model
has one component that contributes negative information (liquidity,
7.1) and one constant that contributes nothing (confirmation's
+10 for "2 evidence items" is a fixed constant - the count never
varies, so it only shifts all rows uniformly). A definitive evaluator
answer requires activating a telemetry-safe decision path with
match/reject logging (18.7 E3/E7) - already in the backlog.

### 7.6 Q6: Is the 16.2 Platt negative slope a real signal?

**Yes - now measured directly, with the v3 evidence that 16.2 lacked.**

- Spearman (confidence, outcome) = **-0.0317**, Kendall = -0.0296
  (n=17,068 binary rows). The ordering power is negative - the score
  is weakly anti-ordered, not unordered.
- Per-value calibration curve (the 6 discrete states):

| state | n | wr | gap |
|---|---|---|---|
| 0.35 | 3,383 | 0.3521 | +0.002 |
| 0.40 | 9,200 | 0.3350 | +0.065 |
| 0.45 | 856 | 0.3668 | +0.083 |
| 0.50 | 76 | 0.3816 | +0.118 |
| 0.55 | 375 | 0.2453 | +0.305 |
| 0.60 | 3,178 | 0.3027 | +0.297 |

- ECE (6 discrete values) = **0.1022**; MCE = **0.3047**; Brier =
  **0.2425** vs always-mean baseline 0.2218 (the model LOSES to the
  constant forecast). Brier is byte-identical to Sprint 16.1A's 0.2425
  on the previous collection - the architecture's miscalibration is
  reproducible across datasets, ruling out sampling noise.
- The negative slope is structural, and its mechanism is now visible:
  the top states (0.55/0.60) are exclusively the LIQUIDITY family
  (0.2453/0.3027), while the mid states (0.45/0.50) are the decent
  families. The constants (liquidity 30, CHOCH 20) are anti-calibrated
  relative to the measured frequencies.

So: the 16.2 Platt negative slope was not a fitting artifact; it was
the first observation of the anti-calibrated constant structure that
the v3 columns now make fully reproducible.

### 7.7 The verdict for the architecture

1. **The score has no usable ordering power** (Spearman -0.032; gate
   sweep inverted) and is anti-calibrated at exactly the states the
   current constants promote.
2. **Calibration per family is tractable and nearly sufficient**: the
   score is a pure function of family x alignment (10 measured cells,
   two of which dominate: OB_FVG at 0.386 and LIQUIDITY at 0.594).
   Family-conditional recalibration maps each cell to its measured
   frequency, collapsing the anti-monotone order.
3. **Selection and confidence must be re-coupled**: bestRule selection
   uses a-priori ruleScore (70-90) while the gate uses composition
   confidence; the two orders disagree at the top (18.7: score 85
   bucket 0.3746 vs score 90 bucket 0.3029). Both must use the same
   measured ordering.
4. **The composition ceiling must be broken or ignored**: as long as
   no rule can express high structural + liquidity evidence, the
   "confidence" range [0.60, 1.00] is unreachable and the good
   families cannot be gated high. Sprint 19 should either construct
   combined rules or reinterpret confidence per family.
5. **The confirmation layer is a free constant**: +10 for
   evidenceCount == 2 is uniform; trendAligned +5 is anti-measured in
   aggregate and mixed per family (+1.6 pp OB, -5.7 pp sweep, 18.7).
   It should be family-conditional or removed.

---

## 8. Experiment Backlog - confidence architecture for Sprint 19

Priorities reflect the verdict in 7.7. E1-E2 are the highest-leverage;
they make the score usable. E3-E5 are the structural removals of the
anti-calibration. E6-E10 harden measurement and governance.

| # | Experiment | Expected effect | Evidence basis |
|---|---|---|---|
| E1 | **Family-conditional confidence**: replace `layerTotal/100` with the measured per-family win frequency (family x trendAligned cells), monotone in the family ranking, computed on held-out data (18.13 protocol) | Turns the anti-order into order: LIQUIDITY cells collapse from 0.55-0.60 to ~0.30; OB_FVG rises to ~0.34-0.38 | 7.1, 7.4, 7.6 |
| E2 | **Selection by measured rank**: choose bestRule by measured family wr (or ECE-weighted), not by a-priori ruleScore 70-90; fix the 85-vs-90 inversion | Removes the selection/gate disagreement; the EA stops preferring the worst rows | 18.7 7.3; 7.4 |
| E3 | **Single decision path**: activate the evaluator/decision bridge with telemetry preserved (RULE_NONE hazard, 18.7 E3) | Enables Q5-style component attribution and live A/B of confidence models | 6.3.5, 7.5 |
| E4 | **Confirmation layer rework**: make trendAligned +5 family-conditional (keep for OB families, remove for LIQUIDITY) or drop it | Removes the -1.5 pp anti-monotone at confirmation | 7.1, 18.7 |
| E5 | **Composition ceiling removal**: add rule types combining structural + liquidity evidence (e.g., OB + sweep, BOS_OB + sweep) so high-confidence states are reachable by good families | Expands the state space above 0.60 with measured (not constant) quality | 6.3.1, 7.4 |
| E6 | **Monotonicity guard**: regression test asserting gate sweeps are non-decreasing (or ECE per state <= threshold) after any constant change | Prevents recurrence of the inverted gate | 7.4, 7.6 |
| E7 | **Coexistence + single-evidence telemetry**: log which evidence types co-occur and fire single-evidence rule variants | Answers Q2/Q3 properly; gives the +10 constant variance | 7.2, 7.3 |
| E8 | **Calibration pipeline (offline)**: per-family isotonic/empirical mapping on train, evaluated (ECE/MCE/Brier/Spearman) on holdout; promote only on gain | Governance loop per section 4; produces the E1 mapping formally | 2.2, 7.6 |
| E9 | **confidenceModel bump**: when E1 ships, set `confidenceModel = "calibrated-family-v1"` and add the recalibrated confidence column (append-only, schema v3.1) | Keeps raw and calibrated values distinguishable in evidence | 1.3, SchemaV3 3.1 |
| E10 | **Per-family promotion gate**: gate thresholds defined per family on calibrated confidence (e.g., OB_FVG >= 0.36), not globally | The good families become gateable; LIQUIDITY becomes rejectable | 7.4 |

Closure: the Schema v3 review gate is PASSED (exit criteria met, six
questions answered, negative result fully characterized). The next
step in the design's sequence is Calibration; per the sequencing
contract it is now deliberately deferred to Sprint 19 E1/E8 so that
calibration runs on the corrected architecture, not on the
anti-calibrated one.
