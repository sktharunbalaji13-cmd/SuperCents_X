# Sprint 18.7 — Confluence & Decision Layer Deep Research Review

**Document:** 07_Confluence.md
**Series:** Sprint 18 — Deep Research Program (research only; no production code changes)
**Status:** Complete
**Supersedes / complements:** 02_BOS_Research.md, 03_CHOCH_MSS.md, 04_Liquidity.md, 05_OrderBlocks.md, 06_FVG.md (all evidence-layer sprints feed this decision-layer review)
**Methodology:** Mandatory 8-phase structure defined in 00_Program_Overview.md; phases 1-5 never reference SuperCents_X. This sprint covers the rule layer, the score/layer system, the signal lifecycle, and the (dormant) evaluator path.

---

## 1. Foundation — What "Confluence" Means

### 1.1 The core claim

**Confluence** is the idea that decisions improve when multiple *independent*
confirmations point the same way: the more evidence agrees (structure, order blocks,
FVG, liquidity, trend), the higher the probability of success. The design pattern is
universal in trading systems: a **rule/evidence layer** (detect conditions), a
**scoring layer** (combine evidence into a score), a **confidence layer** (map score
to a probability-like quantity), a **gating layer** (qualify/disqualify decisions),
and a **lifecycle layer** (when a signal dies).

### 1.2 Design questions this sprint answers for SuperCents_X

1. Are the evidence signals *independent*, or correlated proxies of the same events?
2. Is the score monotone in outcome probability (higher score → better decisions)?
3. Is the confidence *calibrated* (0.60 means 60% in fact)?
4. Does the selection policy pick the best decision (highest a-priori score vs
   highest measured win rate)?
5. Is the evidence freshness/recency policy consistent across evidence types?
6. Are the scoring and telemetry paths identical (does the CSV measure what the
   engine decides)?

### 1.3 The falsifiable core

Every confluence system can be tested as: *does the rank ordering of decisions by
score/confidence match the rank ordering of their empirical win rates?* The Sprint 17
dataset measures this directly (Phase 7). The academic literature (Phase 2) is
explicit that uncalibrated heuristics and non-independent evidence degrade
decision quality.

---

## 2. Academic Literature — Combining Evidence and Calibrating Scores

### 2.1 Evidence combination and dependence

- **Decision-theoretic basis:** combining *independent* noisy signals reduces
  variance (Condorcet jury theorem lineage: with independent signals, majority
  accuracy exceeds individual accuracy). The theorem's *critical* assumption is
  independence — correlated signals do not improve accuracy the same way.
- **Tettock-style aggregation literature** (Bates & Granger 1969 "The Combination of
  Forecasts"; Timmermann 2006 "Forecast Combinations" in *Handbook of Economic
  Forecasting*): forecast combination helps when component forecasts are
  uncorrelated; gains shrink toward zero as correlation rises.
- **Implication for the review:** the six evidence flags (hasBOS, hasCHOCH,
  hasOrderBlock, hasFVG, hasLiquiditySweep, hasProtectedPoint) are *rule-family
  proxies* (Phase 6) — they are one-hot by construction and never combine
  (measured: ruleEvidenceCount=2 always, families are mutually exclusive). The
  "confluence" the engine computes is therefore **never more than two fixed
  evidence items per decision**, and the six flags add no information beyond the
  rule family identity (18.5 §7.4).

### 2.2 Calibration literature

- **Calibration in prediction** (e.g., Murphy 1973 decomposition; DeGroot &
  Fienberg 1983 "The Comparison and Evaluation of Forecasters"): a forecaster is
  calibrated if, among predictions of probability p, the outcome frequency equals p.
- **Overconfidence in finance** (Barberis & Thaler survey; Daniel, Hirshleifer &
  Subrahmanyam 1998): agents systematically over-weight their information; systems
  that hand-assign high confidence to low-evidence decisions reproduce the human
  bias.
- **Implication:** confidence values assigned *a priori* (rule constants, 0.75-0.95)
  must be tested against realized frequencies. Phase 7 does exactly this and finds
  the assignment inverted at the top of the range (0.90 bucket → 0.2276 win rate).

### 2.3 Ranking / score monotonicity

- The relevant quantity for a gating system is **rank monotonicity**: if a decision
  with score s is accepted and one with s' > s rejected, expected outcome quality
  must not decrease. Violations (score buckets whose win rate drops as score rises)
  imply misallocation of capital (18.11 domain).
- Literature basis: value-at-risk backtests and forecast-evaluation concordance
  statistics (e.g., Somers' D / rank correlation between predicted and realized
  outcome). No such statistic is computed in the pipeline today (18.13 domain).

### 2.4 The honest summary of the academic layer

| Question | Academic verdict | Strength |
|---|---|---|
| Do independent signals combine well? | Yes (combination literature) | I |
| Do correlated/proxy signals still add value? | No — gains vanish (Bates-Granger, Timmermann) | I |
| Must confidence be calibrated to realized frequency? | Yes (forecast evaluation, Murphy/DeGroot-Fienberg) | I |
| Is a priori overconfidence a known failure mode? | Yes (behavioral finance) | II |

---

## 3. Professional Trading Literature — Practitioner Doctrine

### 3.1 The confluence checklist in SMC practice

- Practitioner SMC content is unanimous that "more confluence = higher probability"
  and that the strongest setups combine: liquidity sweep + displacement + MSS +
  OB/FVG zone + trend direction. **The distinguishing feature: the doctrine's
  strongest setup is a *sequence of events in time* (sweep → displacement → MSS →
  entry zone), not a static stack of simultaneous flags.** SuperCents_X's rules
  capture *pairs* of events with recency windows (10 bars) — a static, short-window
  approximation of the sequential doctrine.
- **Timing matters:** doctrine emphasizes *when* evidence occurred relative to the
  decision (freshness), and the sequence (sweep must precede MSS which must precede
  entry). The current implementation checks each evidence's recency independently
  (Phase 6) but never their *order*.

### 3.2 The "three independent confirmations" rule of thumb

- A widely-taught heuristic (across SMC and general price-action practice): require
  at least two *structurally independent* confirmations, ideally three. In
  SuperCents_X terms: every rule has exactly two evidence items — at the bottom of
  this heuristic, with the pairs being *fixed* per rule (no dynamic stacking).
- **Freshness weighting** (practitioner consensus): recent evidence is worth more;
  the implementation's helpers (ComputeFreshness/EstimateEvidenceAge) exist but are
  **not called by any rule** (Phase 6) — the freshness concept is dead code.

### 3.3 Practitioner checklist (consolidated)

1. Evidence independence is what makes confluence work (universal).
2. Sequential confirmation (sweep→structure→entry zone) is the strongest form
   (SMC).
3. Freshness and order of evidence matter (universal).
4. Score rank must match quality rank, or the gate misfires (implicit universal).

---

## 4. Institutional / Quantitative Practice

### 4.1 Signal combination in quant systems

- Professional multi-signal systems (statistical arbitrage, CTA overlays, factor
  models) combine signals with **estimated covariance** and **cross-validation**,
  never fixed additive points. The additive point scheme (15/20/15/10 per evidence)
  is a first-order approximation whose weights are *assumptions*, not estimates.
- **Ranking discipline:** institutional order managers rank candidate signals by
  measured alpha/odds, not by a priori design scores; score → size mapping is
  monotone only after calibration (18.11).
- **Lifecycle discipline:** signals carry explicit decay (half-lives) and expiry
  (time-out) policies. The implementation expires signals on *structure state
  changes* only (FVG filled / OB mitigated / liquidity mitigated / trend reversal) —
  no time-out exists (Phase 6).

### 4.2 The independence audit an institutional desk would run

1. Cross-correlation matrix of the evidence flags → in this system the flags are
   one-hot (never co-occur), so the matrix is diagonal by construction: "independence"
   is *enforced*, not demonstrated.
2. Calibration table (predicted confidence vs realized frequency) → Phase 7 shows
   the table is inverted at the top.
3. Rank concordance of the gate (does acceptance threshold select better rows?) →
   Phase 7 shows score buckets misordered.

---

## 5. Open-Source Implementations — Common Design Choices

### 5.1 Survey scope

Survey of open-source SMC confluence/decision engines (TradingView strategy scripts,
MQL5 expert advisors, SMC suites from 18.2-18.6 surveys). Dominant patterns:

| Aspect | Dominant pattern | SuperCents_X (Phase 6) |
|---|---|---|
| Evidence combination | additive points or AND-of-conditions | additive points (fixed constants) |
| Rules | fixed templates per event pair | 7 fixed rules, pairs hardcoded |
| Confidence | linear map of score, rarely calibrated | rule constant + trend delta (0.75-0.95); CSV confidence = layerTotal/100 |
| Gating | threshold on confidence/score | entry decision engine threshold (18.9) |
| Expiry | time-out N bars OR state change | state change only, no time-out |
| Recency | uniform window per evidence type | 10 bars for BOS/CHOCH/sweep; **unlimited for OB/FVG** |
| Freshness weighting | common (age decay multipliers) | helper exists, **never called** |

### 5.2 Notable anti-patterns in the open-source corpus (all present here)

1. **Proxy flags** (flag = "a rule fired," not detector state) — silently removes the
   possibility of combining evidence across types.
2. **Fixed pair rules** (each rule = exactly two hardcoded evidence types) — no
   dynamic stacking, no sequence validation.
3. **Uncalibrated confidence** (hand-assigned constants) — no backfit to realized
   frequencies.
4. **Inconsistent recency** — some evidence types time-boxed, others immortal.

---

## 6. Current SuperCents_X Implementation — Read-Only Code Review

### 6.1 Scope of review

- `Confluence/ConfluenceEngine.mqh` (733 lines) — update loop, rule path, evaluator
  path, signal assembly, lifecycle/expiry.
- `Confluence/ConfluenceRules.mqh` (458 lines) — the 7 production rules and evidence
  helpers.
- `Confluence/ScoreCalculator.mqh` (140 lines) — the layer/score system.
- `Confluence/ConfluenceTypes.mqh`, `ConfluenceWeights.mqh`,
  `ConfluenceScoreCalculator.mqh`, `ConfluenceLogger.mqh` — evaluator-path types.
- `Confluence/Evaluators/*` (6 evaluators) — dormant evaluator path.
- `Confluence/SignalTypes.mqh` — signal/rule result types.
- `Telemetry/TelemetryRowBuilder.mqh`, `Telemetry/TelemetryTypes.mqh` — CSV
  serialization mapping (lines 137-169, 99-107).
- `Portfolio/SymbolContext.mqh`, `SuperCents_X.mq5` — production wiring.

### 6.2 Two decision paths — one dormant (major architecture finding)

`CConfluenceEngine::Update` (ConfluenceEngine.mqh:176-291) branches:

- **Path A — evaluator path** (`m_evaluatorCount > 0`, :207-239): builds a
  `DetectionContext` (:515-526), evaluates both directions via all registered
  evaluators (:528-559), picks the direction by higher `totalConfidence` (:216-217),
  then `BridgeConfluenceToSignal` (:561-600) converts the weighted-sum result into a
  `RuleResult` with **`bestRule.type = RULE_NONE`** (:566) and evidence ids set to
  component *types* (:574-578).
- **Path B — rule path** (else branch, :240-291): evaluates the 7 hardcoded rules
  (:242-248), picks the highest rule score (:250-272), computes layers via
  `CalculateRuleLayers` (:279-289).

**Production uses Path B exclusively.** `RegisterEvaluator` is called only in
benchmarks (`benchmarks/BenchmarkConfluence.mqh:221,290-295`) and unit tests
(`Tests/unit/TestConfluenceEngine.mqh:289-324`); no production wiring registers
evaluators (`SuperCents_X.mq5` calls only `SetWeights`, :81). The Sprint 17 dataset
is therefore entirely Path B output (rule names in CSV prove it).

**Consequence:** the v2.8 evaluator architecture (docs/ConfluenceEngine_v2.8.md) is
dormant; if it were ever activated, `bestRule.type = RULE_NONE` would make every
telemetry flag FALSE (`hasBOS` etc. all false), `ruleName` = "NONE", and the
evidence ids would be component-type integers — the v3 evidence contract would be
silently broken. **Activating the evaluator path without a telemetry bridge would
destroy dataset validity** (E3).

### 6.3 The rule layer (ConfluenceRules.mqh)

**The seven rules** (each: evidence pair + fixed base score + fixed confidence):

| Rule | Evidence A | Evidence B | Base score | Base conf | Modifiers |
|---|---|---|---|---|---|
| BOS_OB_BULLISH | RecentBOS(bull) :45-71 | ActiveOB(bull) :101-123 | 70 | 0.85 | +15/+0.10 trend |
| BOS_OB_BEARISH | RecentBOS(bear) | ActiveOB(bear) | 70 | 0.85 | +15/+0.10 trend |
| OB_FVG_BULLISH | ActiveOB(bull) | UntouchedFVG(bull) :125-147 | 70 | 0.80 | none |
| OB_FVG_BEARISH | ActiveOB(bear) | UntouchedFVG(bear) | 70 | 0.80 | none |
| LIQUIDITY_BOS_BULLISH | RecentLiquiditySweep(bull) :149-184 | RecentBOS(bull) | 70 | 0.80 | +10/+0.10 fresh (unmitigated); +10/+0.05 trend |
| LIQUIDITY_BOS_BEARISH | RecentLiquiditySweep(bear) | RecentBOS(bear) | 70 | 0.80 | same |
| CHOCH_OB_REVERSAL | RecentCHOCH(bull) :73-99 | ActiveOB(**bear**) :437-456 | 75 | 0.75 | none |

Key observations:

1. **Recency policy is inconsistent by evidence type**:
   - `RecentBOS`/`RecentCHOCH`/`RecentLiquiditySweep`: `CONFLUENCE_RECENT_BARS = 10`
     bars (ConfluenceRules.mqh:15,63-64,91-92,168-169).
   - `ActiveOB` (:101-123) and `UntouchedFVG` (:125-147): **no recency filter** —
     an OB or FVG of any age counts as evidence so long as its state is
     active/unfilled. An OB formed 500 bars ago (18.5 §6.4: no expiry) can fire a
     rule today; an FVG of any age can too (18.6 §6.5).
   - Practical effect: OB/FVG evidence is immortal, BOS/CHOCH/sweep evidence is
     time-boxed to 10 bars. The sweep-then-BOS pair can only fire on a 10-bar
     window; the OB+FVG pair can fire on a multi-month-old zone.
2. **CHOCH_OB_REVERSAL is asymmetric by design**: bullish CHOCH + *bearish* OB
   (reversal semantics, :445-446) — the only cross-direction rule. (18.3 §7.4
   measured it at 0.3567.)
3. **Freshness helpers are dead code**: `ComputeFreshness` (:186-195) and
   `EstimateEvidenceAge` (:197-200) are defined but **called by no rule**.
   `EstimateEvidenceAge` computes `Bars() % 20` — not an age at all; it is a
   pseudo-random value. The freshness concept exists but is never applied.
4. **Confidence caps at 0.99** (:267, :300, :382, :424); rule confidence values in
   production are 0.75-0.95 (Phase 7 confirms the realized distribution).
5. **Selection by a-priori score**: the engine picks the highest rule `score`
   (:250-272); ties resolve to the first rule evaluated (BOS_OB_BULLISH has
   priority in ties by array order :242-248). The score is the *design constant*
   (70-90), never a measured quantity (Phase 7 shows the top score bucket is the
   worst performer).

### 6.4 The layer/score system (ScoreCalculator.mqh)

`CalculateRuleLayers` (:75-138) rebuilds the layer decomposition from the *rule
type* (not from detector state):

- `SCORE_STRUCTURAL_BOS = 15`, `CHOCH = 20`, `OB = 15`, `FVG = 10`, `PP = 10`, cap 50
  (:7-12, :103-107).
- `SCORE_LIQUIDITY_SWEPT = 30` (only when the rule is a liquidity rule, :109-110;
  `CalculateLiquidityScore` :32-39 additionally exists for the evaluator path).
- `SCORE_CONFIRMATION_MAX = 20`: +10 if ≥2 evidence types, +10 if ≥3, +5 if trend
  aligned (:119-131).
- `total = structural + liquidity + confirmation`, cap 100 (:135).

This is exactly the decoded layer system from 18.5 §7.4:

| Family | structural | liquidity | confirmation | total |
|---|---|---|---|---|
| LIQUIDITY_BOS | 15 | 30 | 10 or 15 | 55 / 60 |
| OB_FVG | 25 | 0 | 10 or 15 | 35 / 40 |
| BOS_OB | 30 | 0 | 10 or 15 | 40 / 45 |
| CHOCH_OB | 35 | 0 | 10 or 15 | 45 / 50 |

Note `CalculateTotalScore`/`CalculateStructuralScore` (:20-64) are the *evaluator*
path variants; the rule path uses only `CalculateRuleLayers`.

### 6.5 The confidence chain — three different "confidences"

1. **rule.confidence** (rule constants 0.75-0.95) — serialized as `ruleConfidence`
   (TelemetryRowBuilder.mqh:148).
2. **score.total** (layer total 35-60) — serialized as `layerTotal` (:158) and also
   broadcast as `m_latestConfluence.totalConfidence` (ConfluenceEngine.mqh:298).
3. **decision confidence** — the CSV `confidence` column (v2 schema, header
   TelemetryTypes.mqh:94 area) = `newDecision.confidence` (TelemetryRowBuilder.mqh:75).

**Phase 7 measured: `confidence ≡ layerTotal/100` for every one of the 17,073 rows
(max abs diff 0.000000).** The decision confidence is therefore a deterministic
transform of the layer total — and the layer total is a deterministic function of
the rule family. **No quantity in the chain carries information beyond the rule
family and the trend flag.** The rule's own 0.75-0.95 confidence is serialized but
does not enter the decision confidence (18.9/18.11 use which one? — 18.9 review
domain; telemetry records both, Phase 7 measures both against outcomes).

### 6.6 Signal assembly and the telemetry proxies

`SignalAssembly` (ConfluenceEngine.mqh:306-362):

- `hasBOS/hasCHOCH/hasOrderBlock/hasFVG/hasLiquiditySweep` are **rule-family
  booleans** (:316-324) — the proxy pattern established in 18.4 §6.9 / 18.5 §6.5 /
  18.6 §6.6, now confirmed for all five flags at once.
- `hasProtectedPoint = false` hardcoded (:323) — the flag can never be true
  (explains the dataset-wide '1' on hasProtectedPoint, 18.1 §7.3).
- Evidence ids: `bosId` = evidenceIds[0] for BOS rules (:327); then first id
  assigned to orderBlockId/fvgId/liquidityLevelId by rule type (:334-340). For
  BOS_OB, evidenceIds[0] = bosId and orderBlockId = evidenceIds[1] (via the loop
  :337). For LIQUIDITY_BOS, evidenceIds[0] = levelId (sweep id) — note: the BOS id
  ends up as `bosId = evidenceIds[0]` (:327) which is actually the *level id* —
  **the bosId field is mis-assigned for LIQUIDITY_BOS** (evidenceIds[0] is the
  level id per BuildMatched call order, ConfluenceRules.mqh:390-392: `(levelId,
  bosId, -1)`) — a latent field-mapping inconsistency (the CSV does not expose
  bosId, so it is not measurable; noted for 18.8).

### 6.7 Signal lifecycle (`CheckSignalLifecycles`, :364-461)

Expiry checks, in priority order (first hit wins):

1. FVG-anchored signals: FVG found filled → `EXPIRY_FVG_FILLED`; FVG not found at
   all → also `EXPIRY_FVG_FILLED` (:374-396) — **two distinct states share one
   reason code** (18.6 E6).
2. OB-anchored signals: mitigated → `EXPIRY_OB_MITIGATED`; invalidated or not found
   → `EXPIRY_OB_INVALIDATED` (:398-419).
3. Liquidity-anchored signals: mitigated → `EXPIRY_LIQUIDITY_MITIGATED`;
   invalidated or not found → `EXPIRY_LIQUIDITY_INVALIDATED` (:422-444).
4. **Catch-all trend check**: any active signal whose direction opposes the current
   `TrendState` → `EXPIRY_TREND_REVERSAL` (:446-453). This is the *only* time-based
   behavior in the lifecycle, and it is a state change, not a time-out.

**No time-out expiry exists** — a signal with stable structure state and no trend
flip lives indefinitely (corpus norm is N-bar time-outs, 5.1). The expiry counts
are summarized at Shutdown (:641-648) but never serialized to the CSV (18.13 gap).

### 6.8 The dormant evaluator path (files reviewed for completeness)

- `Evaluators/` contains 6 evaluators: StructureEvaluator (0-100 via 35/30/20/15/10
  additive scheme, StructureEvaluator.mqh:73-104), TrendEvaluator (0/10/80±20*strength),
  OrderBlockEvaluator (50 base + 20/10/15/8 modifiers), FVGEvaluator (50 base +
  20/10/15/7), LiquidityEvaluator (15 baseline / 60 base + 20 fresh + 20 PP; note
  the EXTERNAL_HH direction bug from 18.4 §6.8, LiquidityEvaluator.mqh:29),
  PremiumDiscountEvaluator (0-100 positional).
- `ConfluenceWeights` defaults: S25/OB20/FVG15/L15/T15/PD10 (ConfluenceWeights.mqh:
  18-25); `CConfluenceScoreCalculator::Calculate` (ConfluenceScoreCalculator.mqh:
  22-61) = weighted sum capped 100; `result.valid = validCount>0 && total>0`.
- Default weights are validated to sum 100 and logged at startup
  (SuperCents_X.mq5:81; docs/CalibrationGuide.md:167-168).
- The evaluator path's `BridgeConfluenceToSignal` (ConfluenceEngine.mqh:561-600)
  would set `bestRule.type = RULE_NONE` and use component *types* as evidence ids —
  breaking the v3 telemetry contract if ever activated (6.2).

### 6.9 Phase 6 summary — implementation characteristics

| Aspect | Implementation | Gap vs doctrine / survey |
|---|---|---|
| Decision path | rule path in production; evaluator path dormant | dual-path drift; dormant path would break telemetry |
| Rules | 7 fixed pair rules, hardcoded bases | no dynamic stacking; pairs never combine ≥3 evidences |
| Evidence independence | enforced one-hot (proxy flags) | "independence" by construction, not measurement |
| Recency | 10 bars (BOS/CHOCH/sweep); unlimited (OB/FVG) | inconsistent; stale zones can fire rules |
| Freshness | helpers exist, never called; EstimateEvidenceAge = Bars()%20 | dead code with pseudo-random "age" |
| Selection | highest a-priori rule score | design constants, never measured (Phase 7: inverted) |
| Confidence chain | rule conf (0.75-0.95) → layerTotal (35-60) → conf = layerTotal/100 | deterministic transform; no calibration |
| Lifecycle | state-change expiry only, no time-out; FVG not-found conflated | no time decay; conflation bug |

---

## 7. Sprint 17 Evidence Review — Measured Only

### 7.1 Scope and method

Same frozen dataset (19 merged CSVs, 18,686 rows, fingerprint
`2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`). Decided+signal
rows only (n=17,073). Fresh query script `sprint18_7_confluence.py`; all numbers
re-verified by hand.

### 7.2 The confidence chain — verification at dataset scale

- `confidence ≡ layerTotal/100`: **0 mismatches in 17,073 rows; max abs diff
  0.000000.** The decision-level confidence carries zero information beyond the
  layer total (which is itself a pure rule-family function, 18.5 §7.4).
- The CSV also serializes `ruleConfidence` (the rule constants 0.75-0.95) — a
  *separate* quantity never analyzed before this sprint.

### 7.3 ruleConfidence — the rule constants measured

| ruleConfidence | n | Win rate | Composition |
|---|---|---|---|
| 0.75 | 342 | 0.3567 | CHOCH_OB_REVERSAL (all) |
| 0.80 | 12,405 | 0.3386 | OB_FVG (12,320) + LIQUIDITY mitigated-not-aligned (85) |
| 0.85 | 528 | 0.3352 | BOS_OB not-aligned (268) + LIQUIDITY mitigated-aligned (260) |
| 0.90 | 290 | **0.2276** | LIQUIDITY fresh-not-aligned (290) |
| 0.95 | 3,508 | 0.3150 | LIQUIDITY fresh-aligned (2,918) + BOS_OB aligned (590) |

- **The rule constants are anti-calibrated at the top: the 0.90 bucket (fresh sweep,
  not trend-aligned) is the worst-performing decision class in the dataset
  (0.2276, n=290).** The 0.75 bucket (CHOCH reversal) is the best (0.3567).
- Decomposition (LIQUIDITY, from Phase 6 constants): 0.80 = mitigated + not aligned
  (85); 0.85 = mitigated + aligned (260); 0.90 = fresh + not aligned (290); 0.95 =
  fresh + aligned (2,918). The "fresh" bonus (+0.10) *increases* confidence for
  exactly the rows that lose most.

### 7.4 ruleScore — the selection variable measured

| ruleScore | n | Win rate | Composition |
|---|---|---|---|
| 70 | 12,673 | 0.3392 | OB_FVG (12,320) + BOS_OB not-aligned (268) + LIQUIDITY mitigated-not-aligned (85) |
| 75 | 342 | 0.3567 | CHOCH_OB_REVERSAL |
| 80 | 550 | **0.2618** | LIQUIDITY mitigated-aligned (260) + fresh-not-aligned (290) |
| 85 | 590 | **0.3746** | BOS_OB aligned (590) — best bucket |
| 90 | 2,918 | 0.3029 | LIQUIDITY fresh-aligned (2,918) |

- The engine selects the highest score (:250-272). **The top score bucket (90,
  0.3029) is 7.2pp worse than the 85 bucket (0.3746) and 3.6pp worse than the 70
  bucket (0.3392).** A-priori score ranking is inverted at the top: the selection
  policy systematically prefers the worst decision class whenever a LIQUIDITY
  fresh-aligned signal coexists with any other match.
- The best bucket (85) is never preferred over 90 when both match — the selection
  policy *guarantees* suboptimal picks in the coexistence case.

### 7.5 Evidence counts — confluence is always exactly two

- `ruleEvidenceCount = 2` for **all 17,073 rows**. No rule ever fired with 1 or 3+
  evidence items. The "confluence" in this system is structurally capped at two
  fixed items per decision (6.3) — the flags are one-hot (18.4-18.6 cross-tabs), so
  no decision has ever combined sweep+OB, BOS+FVG, or any other non-fixed pair.

### 7.6 The aggregate trendAligned result (correcting the naive reading)

| trendAligned | n | Win rate |
|---|---|---|
| '1' (FALSE) | 4,295 | 0.3434 |
| '2' (TRUE) | 12,778 | 0.3283 |

- At the aggregate, trend-aligned rows win *less* (−1.5pp) — but this is a
  composition effect: the aligned set is dominated by LIQUIDITY rows (3,178 of
  12,778 at 0.3027). Per family, the trend gate is: OB families +1.6 to +1.8pp
  (18.5/18.6), FVG direction-conditional (18.6 §7.4), LIQUIDITY −5.7pp (18.4 §7.5).
  **Any use of `trendAligned` as a uniform bonus (as in ScoreCalculator
  :122-132) is wrong for the liquidity family** — the +5 confirmation bonus is
  family-agnostic while the measured effect is family-conditional.

### 7.7 The decision-confidence bins (the gate's calibration table)

| confidence bin | n | Win rate | Composition |
|---|---|---|---|
| [0.35, 0.40) | 3,386 | 0.3517 | OB_FVG aligned |
| [0.40, 0.45) | 9,202 | 0.3349 | OB_FVG not-aligned + BOS_OB not-aligned |
| [0.45, 0.50) | 856 | 0.3668 | BOS_OB aligned + CHOCH not-aligned |
| [0.50, 0.55) | 76 | **0.3816** | CHOCH aligned — best bin |
| [0.55, 0.60) | 375 | **0.2453** | LIQUIDITY not-aligned — worst bin |
| [0.60, 1.00] | 3,178 | 0.3027 | LIQUIDITY aligned |

- **Monotonicity fails at both ends of the accepted range**: the highest-confidence
  bins (0.55-0.60, 0.60+) are the worst performers, and the best bins sit mid-range
  (0.45-0.55). A threshold gate on this confidence (any level) cannot separate
  quality — the calibration is inverted exactly where the gate would accept.
- This is the definitive quantitative statement of the 18.8 problem: **the
  confidence used for gating is anti-calibrated because it encodes rule family
  identity, and the rule families have the wrong relative constants.**

### 7.8 What the dataset cannot measure (explicit)

1. **Match-vs-reject base rates:** how often each rule matched and rejected
  (`m_ruleMatchCounts`/`m_ruleRejectCounts` are only in Shutdown logs, never in
  CSV) — the conditional P(win | rule fired) exists, but the rule *frequency* and
  the *unmatched* states are not serialized.
2. **Evidence order/sequence:** whether the sweep preceded the BOS, etc. — no
  timing columns beyond `signalTime`.
3. **Signal lifetime and expiry reason:** `expiryReason` is not serialized — the
  EXPIRY_* distribution (Phase 6 counters) is unmeasurable from CSV.
4. **Coexistence outcomes:** when multiple rules matched simultaneously, which rule
  won and what the runner-up was — not recorded (selection-policy behavior
  untestable directly; the bucket inversion in 7.4 is the indirect evidence).
5. **The evaluator path:** no CSV rows exist from Path A (dormant) — its behavior is
  untested in production conditions.

### 7.9 Phase 7 synthesis

1. **The confidence chain is deterministic and uncalibrated:** decision confidence
  = layerTotal/100 = f(rule family, trend flag). Verified to machine precision on
  all 17,073 rows.
2. **The selection policy is anti-calibrated at the top:** score 90 bucket 0.3029
  vs score 85 bucket 0.3746; the engine prefers 90 whenever both match.
3. **The rule constants are inverted for the liquidity family:** "fresh" adds
  confidence (+0.10) to the 0.2276 bucket (n=290) and the 0.95 bucket (0.3150)
  underperforms the 0.75 bucket (0.3567).
4. **Confluence is structurally capped at two evidence items** (ruleEvidenceCount
  = 2 on every row; one-hot flags) — the system cannot represent the doctrine's
  sweep→displacement→MSS→zone sequencing.
5. **trendAligned as a uniform bonus is wrong** (family-conditional effects,
  negative for liquidity).
6. **Recency policy is inconsistent** (10-bar vs unlimited), and the freshness
  helpers are dead code with a pseudo-random age function.

---

## 8. Experiment Backlog — Sprint 19 Candidates

| ID | Experiment | Evidence | Conf | Priority |
|---|---|---|---|---|
| E1 | **Family-conditional confidence calibration:** replace the rule constants / layerTotal transform with per-family fitted confidence (BOS_OB aligned ≈ 0.37, LIQUIDITY fresh ≈ 0.23, CHOCH ≈ 0.36, etc.); the definitive 18.8 deliverable | I (7.3/7.4/7.7 measured, all families) | A | P1 |
| E2 | **Selection by measured rank, not a-priori score:** pick the rule with the highest *estimated* win rate (or gate out score-90 liquidity rows); fix the coexistence inversion | I (7.4) | A | P1 |
| E3 | **Single decision path:** remove or properly bridge the dormant evaluator path (`bestRule.type = RULE_NONE` breaks telemetry if activated); document the decision in 18.8 | n/a (architecture correctness) | A | P1 |
| E4 | **Recency harmonization:** apply one uniform window (or per-evidence windows) to OB/FVG evidence; re-measure the OB+FVG family which can currently fire on multi-month zones | III (5.1 corpus + 6.3 review) | B | P1 |
| E5 | **Replace/remove the freshness dead code** (`EstimateEvidenceAge` = `Bars()%20` is pseudo-random; `ComputeFreshness` never called) with a real age function used by the rules | n/a (dead code) | A | P1 |
| E6 | **Signal lifecycle telemetry:** serialize expiry reason and signal lifetime (time-out vs state-change expiry experiment) | III (4.1 practice; 6.7 review) | B | P2 |
| E7 | **Rule match/reject + coexistence telemetry:** log all matches per update, the selected rule, and the runner-up (schema v4) — enables selection-policy experiments | n/a | B | P2 |
| E8 | **Sequence-aware rules:** test sweep→BOS→OB ordering within the recency window (doctrine 3.1) once E7/E4 provide the columns | III | C | P2 |
| E9 | **time-out expiry experiment:** N-bar signal expiry vs state-change expiry | III (4.1/5.1) | C | P2 |

**Priority recommendation:** E1+E2 are the highest-leverage fixes in the entire
program (they correct the gate and the selection simultaneously and are directly
supported by measured tables); E3-E5 are correctness/architecture fixes with no
behavioral risk; E6-E9 are measurement and research-stage items that require the E7
schema additions first.

---

## References (consolidated)

### Academic
1. Bates, J. & Granger, C. (1969). "The Combination of Forecasts." *Operational
   Research Quarterly* 20(4), 451-468.
2. Timmermann, A. (2006). "Forecast Combinations." In *Handbook of Economic
   Forecasting*, Vol. 1, Elsevier.
3. DeGroot, M. & Fienberg, S. (1983). "The Comparison and Evaluation of
   Forecasters." *Journal of the Royal Statistical Society D* 32(1-2), 12-22.
4. Murphy, A. (1973). "A New Vector Partition of the Probability Score." *Journal of
   Applied Meteorology* 12, 595-600.
5. Daniel, K., Hirshleifer, D. & Subrahmanyam, A. (1998). "Investor Psychology and
   Security Market Under- and Overreactions." *Journal of Finance* 53(6),
   1839-1885 (overconfidence mechanisms).
6. Condorcet jury theorem (independence assumption) — classic decision-theory
   foundation, e.g., Ladha (1992) "The Condorcet Jury Theorem, Free Speech, and
   Correlated Votes." *American Journal of Political Science* 36(3).

### Professional / practitioner
7. SMC confluence doctrine (surveyed corpus across 18.2-18.6): strongest setups are
   *sequential* event chains (sweep → displacement → MSS → zone), freshness and
   order of evidence, "two-to-three independent confirmations" heuristic.

### Open-source / implementations
8. Open-source SMC decision/strategy engines (TradingView strategies, MQL5 EAs,
   suites from 18.2-18.6 surveys): additive scoring, fixed templates, time-out
   expiry norms, freshness weighting, calibration practices (anti-patterns in 5.2).

### Internal
9. `Confluence/ConfluenceEngine.mqh` (733 lines) — Phase 6 code review.
10. `Confluence/ConfluenceRules.mqh` (458 lines) — the 7 rules and helpers.
11. `Confluence/ScoreCalculator.mqh` (140 lines) — the layer system.
12. `Confluence/ConfluenceTypes.mqh`, `ConfluenceWeights.mqh`,
    `ConfluenceScoreCalculator.mqh`, `ConfluenceLogger.mqh` — evaluator path.
13. `Confluence/Evaluators/*` (6 files) — dormant evaluator implementations.
14. `Confluence/SignalTypes.mqh` — signal/rule result types.
15. `Telemetry/TelemetryRowBuilder.mqh` (185 lines) — CSV mapping (lines 137-169).
16. `Telemetry/TelemetryTypes.mqh` — v3 header (lines 99-107).
17. `Portfolio/SymbolContext.mqh`, `SuperCents_X.mq5` — production wiring (no
    RegisterEvaluator calls; SetWeights at SuperCents_X.mq5:81).
18. `benchmarks/BenchmarkConfluence.mqh`, `Tests/unit/TestConfluenceEngine.mqh` —
    the only evaluator-path users.
19. `docs/Sprint18_Research/00_Program_Overview.md` — methodology.
20. `docs/Sprint18_Research/02_BOS_Research.md` … `06_FVG.md` — the five evidence
    sprints feeding this review (family win rates, layer decoding, proxy flags).
21. Sprint 17 merged evidence dataset (fingerprint
    `2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`) and query
    script `sprint18_7_confluence.py`.
