# 18.9 - Entry Layer Research

Status: **COMPLETE** (2026-08-02). 8-phase deep research review of the
entry layer: candidate construction, decision gates, validator chain,
entry/stop/target policies and plan validation. Phase 7 exploits a
previously unused evidence column (`validatorResults`) to measure the
live gate chain's behavior on all 17,073 signal rows.

Evidence dataset (frozen, fingerprint
`2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`):
19 merged v3 files, 18,686 rows; decided+signal 17,073; binary
(WIN/LOSS) 17,068; base win rate 0.3321.

---

## 1. Foundation - scope of the entry layer

The entry layer is the decision boundary between the confluence engine
(signal) and execution. It answers: *given a confluence signal, when,
at what price, and after which filters do we actually enter?* The
reviewed pipeline (SuperCents_X, read-only):

    Rule match (ConfluenceEngine)
      -> TradeCandidate (one per direction, evidence union, liveness)
      -> EntryDecision (score/confidence/evidence/rule gates + trend)
      -> Validator chain (8 gates: direction, confluence, freshness,
         spread, session, distance, cooldown, risk)
      -> ExecutionPlan (entry/stop/target policies, RR/validity checks)
      -> (execution reserved; shadow mode until promotion gate)

Phase 7 measures the validator chain directly because the evidence
dataset serializes per-validator outcomes (`validatorResults` column).

---

## 2. Academic - entry timing and order choice

- **Bertsimas & Lo (1998)**: dynamic programming formulation of
  optimal execution; the core lesson is that entry is an optimization
  over cost vs. fill certainty, not a point decision.
- **Almgren & Chriss (2000)**: optimal execution with permanent and
  temporary impact; establishes the cost/risk frontier. For a
  small-size retail EA the impact term is negligible, but the framework
  pins the correct question: expected fill price *at decision time*
  is the quantity that matters, not the mid price.
- **Foucault, Kadan & Kandel (2005)**: limit vs. market order choice
  under asymmetric information - limit orders win in quiet conditions
  and lose in information-driven conditions. Implication for zone
  entries (OB retest, FVG midpoint): limit-style entries are cheap
  when the zone is not yet tested, expensive when the move is already
  running.
- **Goettler, Parlour & Rajan (2005)**: informed traders trade when
  the spread is widest; entry filters based on spread (the EA's
  SpreadValidator) are consistent with microstructure evidence.
- **Backtesting fill realism (Pardo 2008; Bailey & Lopez de Prado
  2014)**: backtest entries must assume the fill the trader would
  actually get - limit entries fill only on touch and in queue order,
  market entries pay the crossing spread; lookahead (entering on
  information of the closing bar) is the dominant backtest error
  source.

---

## 3. Professional - entry tactics

- **Zone entries**: retest entries (wait for price to return to an OB /
  liquidity level) improve RR at the cost of fill rate; breakout /
  impulse entries fill immediately at worse price. Doctrine favors
  zone entries after a confluence signal - exactly the EA's policy set
  (ENTRY_OB_RETEST / ENTRY_FVG_MIDPOINT / ENTRY_LIQUIDITY_LEVEL).
- **RR-aware entry selection**: a fixed stop and target make entry
  price the only lever on RR; entry policy should be chosen to
  maximize expected value (wr x RR), not wr alone.
- **Filter stack practice**: professional systems gate entries on
  spread, volatility, session and freshness; the EA's validator chain
  is this stack. The discipline is to measure each gate's lift on
  held-out data (the EA's gates are currently unmeasured - Phase 7).
- **Cooldown / trade frequency control**: prevents overtrading after
  losses; must be calibrated, not arbitrary.

---

## 4. Institutional / Quant - execution quality

- **TCA (Transaction Cost Analysis)**: institutional standard: measure
  implementation shortfall = actual fill vs. decision price. The
  shadow-trading design (Phase 7 rows) is effectively a zero-cost TCA
  harness - every decision and its virtual entry/exit are recorded.
- **Slippage modeling**: for backtests, worst-case fill assumptions
  (buy at ask + slippage, sell at bid - slippage) are standard; the
  plan validator's spread-derived checks (`stopDistance < spread * 2`)
  are the retail analogue.
- **Gate promotion discipline**: execution must be enabled only after
  gates are validated on evidence - the EA enforces this structurally
  (ENTRY_MODE_NEW forces shadow mode; promotion gate pending).

---

## 5. Open-source - backtest fill engines

- **vectorbt / backtrader / zipline**: standard fill models are next-
  bar-open, close-of-bar (with lookahead caveats) and limit-touch
  fills; limit fill simulation assumes the order executed if any tick
  crossed the limit within the bar.
- **Lesson for this layer**: no open-source engine models zone-retest
  fills with queue position; the conservative assumption for the
  policies under review is *entry only if the zone was touched after
  the signal*, and fill at the zone price (the EA's EntryPriceResolver
  already resolves zone prices - the missing piece is telemetry that
  the touch actually happened, i.e. policyUsed + distance, Phase 8).
- **Walk-forward validation**: entry-policy choice should be
  validated in-sample/out-of-sample (18.13 defines the protocol).

---

## 6. SuperCents_X code review - the entry chain (read-only)

### 6.1 Candidate construction (`Confluence\TradeCandidateBuilder.mqh`)

- One candidate per direction per update, aggregating all matched
  rules (`Update`: bullish/bearish split, :145-167).
- Score aggregation: `score = min(bestRuleScore + (evidenceCount-1)*5,
  100)` (:208, :264) - the +5/extra-evidence bonus is unmeasured
  (CSV evidenceCount==2 everywhere in practice; bonus inert).
- Confidence aggregation: `confidence = min(bestConf + (ruleCount>1 ?
  0.05 : 0), 0.99)` (:209, :265) - the +0.05 multi-rule bonus likewise
  never observed in the dataset.
- `PopulateEvidenceFlags` (:105-143): maps matched rule types to the
  five evidence flags; IDs assigned from evidenceIds by type.
- **Liveness re-check every tick** (:309-349): candidate expires when
  NO supporting evidence remains valid (`CheckBOStillValid` etc.,
  :352-415: BOS/CHOCH membership, OB `!mitigated && !invalidated`,
  FVG `!filled`, liquidity `!invalidated`). This is a correct
  price-localized expiry - unlike the detectors' state-only expiry.
- Counter state: created/expired/bullish/bearish, max evidence/rule
  sets; logged at Shutdown only.

### 6.2 Decision engine (`Entry\EntryDecisionEngine.mqh`)

- Four gates + optional trend gate (`EvaluateCandidate` :146-184):
  `minDecisionScore 70`, `minConfidence 0.75`, `minEvidenceSources 2`,
  `minRuleMatches 1`, `requireTrendAlignment false` (defaults in
  `EntryDecisionTypes.mqh:24-30`).
- **Unreachable-gate finding (measured)**: `candidate.confidence` is
  the layer-derived confidence (max 0.60, 18.5/18.7); the 0.75 default
  can never pass. The score gate uses the a-priori ruleScore (70-90)
  and *does* pass; the two orders disagree systematically (the same
  split-brain as 18.7/18.8). `SetConfig` is never called in
  production, so the engine runs with defaults: **every candidate is
  rejected on the confidence gate; the engine qualifies nothing**.
- Decision lifecycle (:278-319): qualified decisions expire when their
  candidate leaves the active set (`DECISION_REJECTED` +
  `m_totalExpired`).
- Shadow-comparison hooks (`GetLastDecision`) documented as decision-
  level like-for-like with the legacy side.

### 6.3 Validator chain (`Entry\EntryOrchestrator.mqh` + `Validators\`)

- Production path (`Portfolio\SymbolContext.mqh:582-608`): when
  `entryMode != LEGACY`, the orchestrator registers the 8 validators
  (direction, confluence, freshness, spread, session, distance,
  cooldown, risk); ENTRY_MODE_NEW forces **shadow mode** (:600-604:
  "execution reserved until promotion gate passes"). **No live entries
  have ever been taken**; all dataset rows are shadow decisions.
- Chain evaluation (`EntryOrchestrator.Evaluate` :144-170): validators
  run in registration order; **first failure breaks the chain**
  (`break` :169) - later validators are never evaluated. This
  short-circuit is serialized into `validatorResults` (missing
  validators appear absent), which Phase 7 parses.
- `EntryOrchestrator` operates on the legacy `ConfluenceResult`
  (`decisionScore = totalConfidence`, :107-113) - it is the legacy
  decision path; the v3 candidate path (6.2) is parallel and dormant.
- Validator defaults (`Validators\ValidatorConfig.mqh`):
  ConfluenceConfig minConfidence 0.60; FreshnessConfig maxAgeBars 3;
  SpreadConfig maxSpreadPips 15.0; DistanceConfig maxDistance 0.0050;
  CooldownConfig minBarsSinceLastTrade 5; Risk min/max lots 0.01/10.
- ConfluenceValidator (:29-46): fail if confidence < 0.60; warning band
  (0.60, 0.66); the v2-style normalized `totalConfidence/100` gate.
- FreshnessValidator: fail if `barsSinceSignal > 3`; warning band
  > 75% of 3 bars (2 bars).
- SpreadValidator: fail if spread > 15 pips; warning > 11.25.
- DistanceValidator: fail if |mid - candidateEntryPrice| > 0.0050
  (50 pips EURUSD, ~9.5 pips GBPJPY - a symbol-dependent severity);
  warning > 0.00375.
- CooldownValidator: fail if < 5 bars since last trade; requires
  ITradeStateProvider.
- SessionValidator: configured ranges only (never failed in dataset);
  RiskValidator: lot-range check (never failed in dataset).

### 6.4 Plan construction (`Entry\ExecutionPlanner.mqh`)

- `BuildPlan` (:211-352): resolves entry price (6.5), stop (6.6),
  target (6.7), then validates: invalid prices, `stopDistance <
  spread*2`, `stopDistance < minStopDistancePips*10*point` (default
  5 pips in config, 10 pips in the shutdown policy matrix),
  `targetDistance < spread`, `riskReward < 1.0`.
- `EvaluatePolicyCombos` (:459-559): shutdown-only matrix sweep of
  20 entry/stop/target/buffer/minStop combos, logged (never
  persisted to the evidence dataset - a telemetry gap).
- Rejection counters tracked in-memory only (8 categories, :54-57).

### 6.5 Entry price policies (`Entry\EntryPriceResolver.mqh`)

- ENTRY_OB_RETEST: entry at OB low (bull) / OB high (bear) - zone
  retest (:17-33).
- ENTRY_FVG_MIDPOINT: entry at FVG midpoint (:35-48).
- ENTRY_LIQUIDITY_LEVEL: entry at the liquidity level price (:50-63).
- ENTRY_CURRENT_PRICE: market entry at bid (:65-67).
- Fallback to current price on missing evidence. No slippage/buffer
  handling in entry resolution.

### 6.6 Stop policies (`Entry\StopLossResolver.mqh`)

- STOP_OB_SIDE: below OB low / above OB high + stopBufferPips (default
  3.0) (:24-40).
- STOP_LIQUIDITY_SIDE: below/above liquidity level + buffer (:42-58).
- STOP_PROTECTED_POINT: below active protected low / above protected
  high + buffer (:60-75).
- STOP_BROKER_MINIMUM: entry +/- minStopDistancePips (:77-83).
- `ProtectedPointManager` may return no active point (bearish path
  requires GetActiveHigh) -> falls through to broker-minimum stop.

### 6.7 Target policies (`Entry\TargetResolver.mqh`)

- TARGET_OPPOSING_LIQUIDITY: opposing liquidity level (buy-side/swept
  for longs, :32-54).
- TARGET_OPPOSING_OB: nearest opposing OB, scans newest first, skips
  the candidate's own OB (:56-78).
- TARGET_OPPOSING_FVG: nearest opposing unfilled FVG (:80-102).
- TARGET_PREVIOUS_SWING: opposing BOS pivot (:104-126).
- TARGET_FIXED_RR: `entry +/- stopDist * targetRR` (:10-18, :128-130).

---

## 7. Sprint 17 evidence - the gate chain, measured

### 7.1 The `validatorResults` column is fully populated

17,073/17,073 signal rows carry a per-validator outcome string
(`Name=0|Name=1|Name=2`, 0=PASS, 1=WARNING, 2=FAIL; absent = not
evaluated due to chain short-circuit). This makes the *entire live
gate chain observable* - the entry layer is no longer a black box.

### 7.2 Gate composition of the dataset

| Gate (chain order) | PASS n (wr) | WARN n (wr) | FAIL n (wr) | not-evaluated |
|---|---|---|---|---|
| DirectionValidator | 17,073 (0.3321) | - | 0 | 0 |
| ConfluenceValidator | 3,178 (0.3027) | 0 | 13,895 (0.3388) | 0 |
| FreshnessValidator | 3,178 (0.3027) | 0 | 0 | 13,895 |
| SpreadValidator | 2,656 (0.3065) | 135 (0.2444) | 387 (0.2972) | 13,895 |
| SessionValidator | 2,791 (0.3035) | 0 | 0 | 14,282 |
| DistanceValidator | 2,565 (0.2994) | 38 (0.3947) | 188 (0.3404) | 14,282 |
| CooldownValidator | 2,603 (0.3008) | 0 | 0 | 14,470 |
| RiskValidator | 2,603 (0.3008) | 0 | 0 | 14,470 |

### 7.3 Headline findings

1. **The live confidence gate admits ONLY the worst family.**
   ConfluenceValidator (min 0.60) passes exactly the 3,178
   LIQUIDITY_BOS rows at confidence 0.60 (crosstab: every OB_FVG,
   BOS_OB and CHOCH_OB row FAILS; every 0.55 LIQUIDITY row FAILS).
   Passed wr 0.3027 < failed wr 0.3388: **the gate inverts by 3.6pp
   at dataset scale** - it filters out the entire OB-containing
   universe and admits the anti-calibrated liquidity family (18.8
   E1/E10 validated at execution level).
2. **The chain short-circuits on the first gate.** 13,895 rows (81.4%)
   die at ConfluenceValidator; the other six gates never evaluate on
   them, and this is what the telemetry records. Only 2,603 rows
   (15.2%) are fully evaluated by all 8 validators.
3. **Distance gate is anti-calibrated.** Failed rows (188) have wr
   0.3404 > passed rows (2,565) 0.2994; the warning band (38) is the
   best class at 0.3947. The 0.0050 threshold rejects the better
   entries.
4. **Spread gate mildly correct.** Failed 0.2972 < passed 0.3065, but
   the warning band (11.25-15 pips, 135 rows) is the worst class at
   0.2444 - spread-warning rows should be rejected, not warned.
5. **Freshness, session, cooldown, risk gates never fired.**
   `signalTime == timestamp` on 99.85% of rows (gap 0.00 min; 25 rows
   with gaps 1-17 min, wr 0.25-1.00, negligible samples): decisions
   are recorded in the same minute the signal fires, so the 3-bar
   freshness gate (and the 5-bar cooldown) are structurally inert in
   this dataset. Session and Risk configured but never failed.

### 7.4 The shadow-execution reality

ENTRY_MODE_NEW forces shadow mode (6.3): the dataset is a complete
shadow ledger - every signal row carries `entryPrice`, `exitPrice`
(all 17,073 rows) and the validator chain outcomes. entryPrice is
per-symbol real (EURUSD ~1.15-1.22, GBPJPY ~180-216 - the p90
"outliers" are GBPJPY, not corruption). No live position was ever
opened, so **the "win rate" of Phase 7 is the shadow-fill outcome,
not executed P&L** - it measures signal quality under the gate chain,
not execution quality.

### 7.5 What Phase 7 means for the entry layer

- The gate stack, as configured (Confluence 0.60 first), makes the
  entry layer a LIQUIDITY-BOS-only funnel with a 15.2% pass-through,
  on the dataset's worst-performing family (0.3027 vs 0.3388 base).
- The 18.8 recommendation (family-conditional confidence, E1) applies
  directly to the gate: a measured per-family threshold would admit
  OB_FVG/BOS_OB (~0.35-0.45 confidence) and reject or lower-admit
  LIQUIDITY, flipping the funnel's selectivity.
- Validator short-circuiting destroys information: the 81.4% failed
  population never reports spread/distance/session conditions, so the
  later gates' calibration is estimated on a LIQUIDITY-only sample
  (2,603-3,178 rows) - the anti-calibrated Distance result (7.3.3)
  may be family-confounded.

---

## 8. Experiment Backlog - entry layer for Sprint 19

| # | Experiment | Expected effect | Evidence basis |
|---|---|---|---|
| E1 | **Per-family gate thresholds** (from 18.8 E1/E10): configure ConfluenceValidator min confidence per family (e.g., OB_FVG >= 0.35, BOS_OB >= 0.40, LIQUIDITY >= 0.60 or reject) | Flips the funnel selectivity; admits the 0.3388 population, gates the 0.3027 population | 7.3.1, 18.8 7.4/8 E1 |
| E2 | **Full validator matrix telemetry**: evaluate ALL validators on every row (no short-circuit); serialize evaluated/not-evaluated explicitly | Removes the 81.4% information loss; enables per-gate calibration on the full population | 7.2, 6.3 |
| E3 | **Gate-lift measurement protocol**: report each gate's wr(pass) - wr(fail) and lift vs base on holdout, per family | Quantifies which gates help (spread 4) and which invert (confluence, distance) | 7.3 |
| E4 | **Distance gate recalibration**: per-symbol maxDistance (e.g., in pips, 0.0050 is 50 pips EURUSD but ~10 pips GBPJPY); re-estimate the 0.00375-0.0050 band | Removes the anti-calibrated reject of wr 0.3404 rows | 7.3.3, 6.3 |
| E5 | **Spread warning band**: treat the 11.25-15 pip band (0.2444) as reject, not warn | Removes the worst 135-row class from execution | 7.3.4 |
| E6 | **Sub-minute signalTime**: serialize signal time with seconds; record barsSinceSignal at decision | Makes freshness/cooldown gates measurable (currently gap==0) | 7.3.5 |
| E7 | **Entry policy telemetry**: persist policyUsed + entry distance per row (policy matrix is currently shutdown-log-only) | Enables OB-retest vs FVG-midpoint vs liquidity vs market entry measurement - the core entry-price question | 6.4, 6.5 |
| E8 | **Unreachable-gate fix**: align EntryDecisionEngine minConfidence default (0.75) with the achievable confidence range, or remove the gate (it qualifies nothing) | Removes a dead gate that would block all candidates if the decision path is ever activated | 6.2 |
| E9 | **Shadow-fill realism**: record assumed fill price per policy (zone touch required; current-price fallback) so Phase 7 wr is executable, not theoretical | Separates signal quality from entry-policy quality | 7.4, 5 |
| E10 | **Candidate aggregation validation**: telemetry for candidate-level score/confidence bonuses (+5/evidence, +0.05/rule) with evidenceCount > 2 variants | The aggregation bonuses are currently unmeasured and inert; multi-rule candidates would answer 18.7 Q2/Q3 at entry level | 6.1 |

Closure: the entry layer is a well-instrumented shadow funnel whose
gate configuration is anti-calibrated at the confluence gate (the
biggest single action: E1), structurally blind after the first gate
(E2), and inert at freshness/cooldown (E6). All findings consistent
with 18.7/18.8 (anti-calibrated confidence + a-priori selection);
no new contradictions.
