# 18.14 - AI/ML Research

Status: **COMPLETE** (2026-08-02). 8-phase deep research review of the
role of machine learning in SuperCents_X: what ML-adjacent machinery
already exists (a complete offline calibration harness from Sprint
14-16 that is **not wired into production**), what a minimal ML
baseline actually achieves on the frozen evidence, and what Sprint
19 should build. Phase 7 fits a logistic-regression baseline on the
17,073-row dataset (70/30 time split) and compares it against the
hand-authored confidence map on out-of-time data.

Evidence dataset (frozen, fingerprint
`2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`):
17,073 decided+signal rows; binary win rate 0.3321; features:
confidence, ruleScore, ruleConfidence, layerStructural/Liquidity/
Confirmation/Total, direction, hour, symbol, timeframe. All Phase 7
metrics are **test-set only** (last 30% by timestamp, n=5,124),
never trained on.

---

## 1. Foundation - what ML could do here

The production decision pipeline is entirely hand-authored:
confluence layer weights (18.7) -> confidence map (18.8) ->
validator chain (18.9) -> fixed 2R/1R outcome policy (18.10). The
reviewed questions:

1. **Probability calibration**: the confidence map is demonstrably
   anti-calibrated (18.8: ECE 0.102, tau<0; confirmed 18.13 in both
   time halves). Can a fitted model produce a *better-ranked,
   better-calibrated* win probability from the same telemetry?
2. **Feature value**: which of the 68 telemetry columns actually
   carry predictive information? (ruleScore? hour? direction?)
3. **Selection**: can the model rank candidates so that the top
   quantile materially exceeds the base rate - the thing the raw
   map fails at (top-decile wr 0.3130 < base 0.3321, 18.8)?
4. **Deployment constraint**: MQL5 production must stay
   **deterministic and frozen** - any fitted model must be fit
   offline, serialized as parameters, and only *applied* at runtime
   (the same discipline as the existing calibration harness).

The measured answer to Q1-Q3 (7.x): yes to all three, but the edge
is modest (AUC 0.554) and concentrated in regime/family cells
(18.12/18.13) - ML's realistic role is recalibration + cell
selection, not "the model trades for us".

---

## 2. Academic - ML calibration and ranking literature

- **Probability calibration (Niculescu-Mizil & Caruana 2005)**:
   model outputs are systematically miscalibrated; isotonic
   regression and Platt scaling are the standard post-hoc fixes -
   exactly the three transforms already implemented in the EA's
   Calibration module (6.1).
- **Brier score decomposition (Murphy 1973)**: Brier = reliability +
   resolution + uncertainty; an anti-calibrated map (18.8) fails on
   the reliability term - the decomposition explains *why* the raw
   map loses to always-mean Brier.
- **Logistic regression as baseline**: the correct first ML model -
   linear in log-odds, monotone, deterministic, trivially
   serializable; nonlinearity buys little at n=17k with 11 features
   unless interactions are real (family x hour, 18.12 7.5).
- **Leakage and data snooping (18.13 2)**: any fitted model must
   train on a time-prefix and test on the suffix; feature selection
   on the full set is itself snooping. Phase 7 respects the 70/30
   split but 18.13 E1 applies stricter discipline from Sprint 19.
- **Determinism**: for an EA, a frozen lookup/transform applied to a
   rule output is safer than any online learner; the academic
   literature on calibration transferability (temporal stability of
   fitted transforms) is thin - which is why 18.13 E9 (shadow CI
   monitoring) must accompany any deployed model.

---

## 3. Professional - ML in trading practice

- **Ranking before predicting**: practitioners use models for
   relative ranking (which candidate is better), not absolute
   probability; the selection-power metric (7.4) is the one that
   matters for the entry decision.
- **Keep the first model boring**: logistic / penalized logistic on
   curated features beats gradient boosting at n=17k in most EA
   settings; ensembles add variance and serialization complexity for
   ~0.01 AUC.
- **Offline fit, frozen deploy**: retrain per evidence collection,
   validate on the next collection, promote via a gate (the EA's
   PromotionGate pattern, 6.2) - never online learning, never
   intra-bar adaptation.
- **Costs and regime shifts**: model edges decay (18.13: OB_FVG
   bearish decayed -0.036 across halves); a fitted model must be
   re-validated per collection and retired by the same gate that
   promoted it (18.13 E10).

---

## 4. Institutional / Quant - ML governance

- **Model risk management**: institutions treat fitted models as
   financial instruments with documentation, validation on unseen
   data, and retirement criteria. The EA's Calibration/Experiment-
   Runner already produces model cards (params, gates, ablations) -
   a production-grade pattern (6.2).
- **Backtest overfitting (18.13 4)**: with weights/thresholds being
   the "parameters", ML adds a second level of selection; the CSCV/
   PBO discipline from 18.13 E8 applies to any fitted model before
   promotion.
- **Feature hygiene**: hour (server time), symbol, and family are
   regime features (18.12), not signal features; a model that fits
   them must be re-validated when server/timezone or instrument set
   changes (18.12 E9).
- **Explainability**: linear coefficients are auditable; the
   anti-calibration finding (negative coefficient on confidence,
   7.3) is exactly the kind of insight governance wants - opaque
   models would have hidden it.

---

## 5. Open-source - ML tooling

- **scikit-learn**: LogisticRegression, isotonic calibration
   (CalibratedClassifierCV), ROC/Brier metrics - everything Phase 7
   used; the results script is a template for the E1 pipeline.
- **statsmodels**: logistic/GLM with standard errors and tests -
   useful for the coefficient audit (7.3).
- **MT5 native**: MQL5 ships the AIS library (`MathNeuralNetwork`),
   sufficient for offline training; the constraint is not capability
   but the offline-fit/frozen-deploy discipline (3) - and the
   Calibration harness already implements the disciplined path in
   pure MQL5 without AIS.
- **Lesson**: no new runtime dependency is needed; the fitted model
   is a small vector of weights/params applied by a deterministic
   transform (CalibrationTransforms.Apply pattern, 6.1).

---

## 6. SuperCents_X code review - ML-adjacent components (read-only)

### 6.1 Calibration harness (`Calibration\*.mqh`) - EXISTS, DISCONNECTED

- `CalibrationTransforms.mqh`: **PAV isotonic regression** (:183),
   **Platt scaling** (sigmoid(a·conf+b), IRLS fit, :389) and
   **temperature scaling** (GD fit, :446) - the three standard
   calibration families, implemented in pure MQL5 with a `Transform`
   apply function and serializable params (:44-56, :510-541).
- `ExperimentRunner.mqh`: runs raw/isotonic/platt/temperature models
   with **ablations and PromotionGate replays at 0.60 vs raw
   baseline** (:523-525, :619, :771) - a complete offline model-card
   harness.
- `PromotionGate.mqh`, `ThresholdOptimizer.mqh`, `WeightOptimizer.mqh`,
   `ValidatorAttribution.mqh`, `CalibrationMetrics.mqh`,
   `CalibrationStructural.mqh` (rank-correlation machinery, :77):
   threshold/weight search + gate criteria + metrics.
- **Verified: zero production references** (grep: no
   CalibrationModel/ApplyCalibration usage outside Calibration/ and
   its unit tests). The harness from Sprint 14-16 was never wired to
   the confidence pipeline - consistent with 18.8 Q5 ("evaluator
   path dormant"). Production `confidence` = hand-authored weights
   only (18.7/18.8).

### 6.2 Confluence evaluators (`Confluence\Evaluators\*.mqh`)

- CFVGEvaluator, CLiquidityEvaluator, COrderBlockEvaluator,
   CTrendEvaluator, CStructureEvaluator, CPremiumDiscountEvaluator:
   rule-based per-concept scorers feeding the confluence layer
   (18.7) - these are *rule features*, not ML models; their outputs
   are the natural feature set for an offline model (E2).

### 6.3 Risk evaluators (`Entry\CShadowRiskEvaluator.mqh`,
`Providers\ProductionRiskEvaluator.mqh`, `IRiskEvaluator`)

- Risk scoring interfaces exist in shadow and production variants;
   deterministic policy logic (18.11), no fitted components.

### 6.4 Knowledge module (Knowledge\)

- TrendAnalyzer/RecommendationScorer: heuristic scoring for
   knowledge display - advisory only, no decision-path usage
   (verified 18.4/18.7); an example of the "ML-looking but
   advisory" pattern to avoid expanding.

Review conclusion: the EA has the **complete offline model
infrastructure but zero runtime model path**. Sprint 19 does not
need to build ML - it needs to run ExperimentRunner on the frozen
evidence and wire the winner into shadow mode.

---

## 7. Sprint 17 evidence - ML baseline, measured

Logistic regression (standardized, C=1.0) on 11 features; 70/30
time split (train n=11,949, test n=5,124). **All numbers test-set.**

### 7.1 Headline comparison: fitted model vs hand-authored map

| Metric (test) | Raw confidence map | Logistic (11 features) | Always-mean baseline |
|---|---|---|---|
| Brier | 0.2385 | **0.2195** | 0.2208 |
| AUC | 0.4917 | **0.5538** | 0.5000 |
| ECE (discrete/deciles) | 0.0980 | **0.0359** | - |
| Spearman(p, y) | -0.0149 | **+0.0875** | 0.0000 |

The raw map is *worse than a coin flip* at ranking (AUC 0.492) and
*no better than always-mean* at Brier. The fitted model fixes both:
Brier below baseline, ECE ~3x better, positive rank correlation.

### 7.2 Learned coefficients - the model confirms 18.8

| Feature | coef | reading |
|---|---|---|
| ruleScore | **+0.212** | strongest signal feature |
| ruleConfidence | -0.112 | second-strongest is *negative* |
| direction | -0.074 | bearish bias (consistent with OB_FVG asymmetry) |
| confidence | -0.053 | **the map's own output is anti-predictive** |
| layerLiquidity | -0.058 | LIQUIDITY families underperform (18.1) |
| hour | +0.028 | hour carries residual information after the rest |

The regression independently rediscovers 18.8's structural finding
(negative weight on confidence and ruleConfidence) and 18.1/18.5's
family findings - a strong cross-validation of the review's story.

### 7.3 Selection power - the metric that matters for entry

| Selection rule (test) | n | wr |
|---|---|---|
| Top-decile predicted p (logistic) | 518 | **0.3958** |
| Top-decile raw confidence (>=0.60) | 821 | 0.3130 |

The fitted model's top decile beats the raw map's top decile by
**+8.3pp** and exceeds the base rate by +6.4pp - the raw map's top
decile is *below* base (0.3130 < 0.3321, the 18.8 gate inversion
again). Note 18.9's entry decision with `minConfidence 0.75` would
still select nothing; a fitted model makes "select the best
candidates" actually possible.

### 7.4 Feature-subset diagnostic (test AUC)

| Feature set | AUC |
|---|---|
| confidence only | 0.5083 |
| confluence layers only | 0.5188 |
| hour + direction + symbol + ruleScore (regime proxy) | **0.5456** |
| all 11 features | 0.5538 |

**The regime proxy (hour/direction/ruleScore) alone beats the
entire confluence layer** - the same hierarchy 18.12/18.13 found:
time-of-day and direction carry more signal than the structural
scoring. This reorders the Sprint 19 feature priority: regime
columns first, structural columns second.

### 7.5 What Phase 7 means for the ML layer

1. **The map is fixable in-sample/out-of-time with existing
   machinery**: a linear model + isotonic calibration on telemetry
   already available in the CSV reaches AUC 0.554, Brier 0.2195,
   ECE 0.036 and a selection lift of +6.4pp over base. No new
   features, no AIS, no online learning - just ExperimentRunner run
   on the evidence.
2. **Absolute skill is modest**: AUC 0.554 is a weak ranking -
   consistent with 18.13: the edge is cell-concentrated, not
   globally rankable. ML does not create edge; it re-ranks and
   re-calibrates the existing edge and must be combined with the
   regime windows (18.12 E1/E2).
3. **The regression is an audit tool**: negative coefficients on
   confidence/ruleConfidence are the 18.8 anti-calibration in
   coefficient form - a fitted model makes the review's claims
   falsifiable per collection (E2).
4. **Family-conditional models are NOT yet justified**: 18.13 7.4
   found family rankings unstable across halves; per-family logits
   would fit that instability. A global model with family/regime
   features is the correct first step; per-family models wait for
   walk-forward evidence (E5).

---

## 8. Experiment Backlog - AI/ML for Sprint 19

| # | Experiment | Expected effect | Evidence basis |
|---|---|---|---|
| E1 | **Run the offline calibration pipeline on frozen evidence**: ExperimentRunner (isotonic/platt/temperature) on 70/30 time split; persist the winning transform + params as a model card | Reproduces 7.1 in the EA's own harness; produces the deployable artifact | 6.1, 7.1 |
| E2 | **Feature audit per collection**: re-fit logistic per collection; publish coefficient table + AUC/Brier deltas (the "model card" telemetry) | Detects regime drift in the *weights* before it shows in wr (18.13 E9 complements) | 7.2, 7.4 |
| E3 | **Regime-feature priority**: add hour, day-of-week and ruleId columns to telemetry v3.1 (18.12 E3) and retest the feature subsets | Quantifies how much of the regime-proxy AUC (0.5456) is hour vs ruleScore | 7.4, 18.12 |
| E4 | **ruleScore deep-dive**: ruleScore has the strongest coefficient (+0.212) yet 18.2/18.7 found its 90-bucket below the 85-bucket - interaction with family and count; decide if ruleScore is redeemable or noise | Resolves the single most contradictory feature in the program | 7.2, 18.7 |
| E5 | **Global vs family-conditional logits**: compare global model vs per-family fits under 18.13 walk-forward; promote per-family only if rank stability (18.13 E3) passes | Prevents fitting 18.13's unstable family rankings | 7.5.4, 18.13 |
| E6 | **Calibrated-probability entry shadow**: in shadow mode (18.9 E7/E8), log both the raw confidence and the calibrated p per candidate; measure selection-lift live | Verifies 7.3 in production conditions (fill realism, 18.10 E4) | 7.3, 18.9 |
| E7 | **Model determinism contract**: serialize fitted params via the CalibrationParams pattern; document fit-date/collection; runtime applies transform only; re-validation required per collection (PromotionGate) | Keeps production deterministic while enabling the model path | 6.1, 3, 4 |
| E8 | **AIS evaluation**: benchmark MT5's MathNeuralNetwork against the logistic baseline (same splits/metrics); adopt only if clearly better | Evidence-based answer to "should we use neural nets" - expected no | 5, 7.1 |
| E9 | **Combined regime+ML gate**: apply 18.12 session windows first, then calibrated-p ranking within windows (the "cell-select then rank" pipeline) | Compound of the two strongest measured effects (18.12 0.131 Kelly x 7.3 +6.4pp) | 7.4, 18.12 |
| E10 | **Model retirement rule**: a promoted model is retired when shadow CI (18.13 E9) or coefficient drift (E2) violates the 18.13 E10 gate | Prevents silent decay of the fitted edge | 4, 18.13 |

Closure: the ML layer of SuperCents_X is a **complete harness with
no runtime path** - the calibration transforms, experiment runner
and promotion gate from Sprint 14-16 are unused in production.
Phase 7 proves the fitted path is strictly better than the
hand-authored map on every measured axis (AUC +0.062, Brier below
baseline, ECE/3, selection +6.4pp over base) and that the model's
coefficients independently confirm the review's two structural
findings (confidence anti-calibration; regime > structure). Sprint
19 should wire the existing harness into shadow mode (E1/E6) rather
than build new ML - and must keep 18.13's protocol, not AUC, as the
arbiter of promotion.
