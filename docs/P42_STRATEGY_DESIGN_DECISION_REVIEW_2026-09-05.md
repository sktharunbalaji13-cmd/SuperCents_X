# P42 — STRATEGY-DESIGN DECISION REVIEW

Date: 2026-09-05
Mode: READ-ONLY decision review. No code, test, parameter, baseline, holdout, or prior-record modification; no runs, optimization, or deployment actions.
Authority: senior-advisor direction following P41 closure (cap branch closed: mechanically correct, no change).
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`. Tracked modifications: 37 files, same set as P41 close (verified read-only); instrumentation + wiring markers present.

## Disposition

### `P42 DECISION FRAMEWORK COMPLETE — HUMAN DESIGN DECISIONS REQUIRED, NO IMPLEMENTATION AUTHORIZED`

Both remaining items are strategy-design decisions, not hidden mechanical defects. Neither is implementable without explicit human choices specified below. Closed branches (wiring P39, sizing/exposure P37, cap P41) are reaffirmed and NOT reopened.

## 1. Net-RR — facts vs hypotheses

### Mechanical facts (closed, evidence-linked)
- F1: Plan RR is gross (`targetDist/stopDist` on raw prices; `ExecutionPlanner.mqh::BuildPlan`; P36 §2.2).
- F2: Gate is a six-reason ladder; RR clause last, strict `< 1.0`, so 1.0 passes (P36 §2.1). No cost deduction anywhere; `TradeValidation` has no RR re-check (P36 §2.3).
- F3: `riskRewardNet`/`hasNetRiskReward` plumbed, gross carried, flag false, zero consumers (P37; P38 grep-verified).
- F4: Component availability (P40 §1): prices/direction/ticks/spread available pre-trade; **volume unavailable at gate** (sized downstream); commission pre-trade unavailable (history-only); swap cost needs unknowable duration; realized slippage unknowable.
- F5 (refinement): costs expressible in **R-multiples of stopDistance need no volume** (spread_R = spread_price/stopDistance). Per-lot/per-trade money costs (commission, swap accrual) cannot enter an R-denominated gate without a lots assumption — the hard boundary between computable and fabricated.

### Strategy hypotheses (each requires explicit human choice)
- H1 — cost-term set: spread-only (assumes other costs ≡ 0) vs +commission (needs invented rate + lots assumption) vs +slippage model (needs distribution + ledger that doesn't exist) vs conservative bound (bound value is a risk preference) vs expected-cost model (needs cost ledger first).
- H2 — volume treatment for money-denominated terms: assumed lots, per-1-lot normalization, or R-denomination (only the last is assumption-free, and only for price-denominated costs).
- H3 — threshold value: any `minRR` (1.5 or otherwise) is a risk-preference choice; no evidence basis exists (RR gate 1.0 is legacy; confidence thresholds are an unrelated scale).
- H4 — gate action on net-RR failure: reject vs down-weight vs observe-only logging (observe-only is the reversible first step).

### Minimum decision package for future authorization (all required, none optional)
1. Term list with authoritative source per term (API/field name; "estimated" terms flagged with calibration source).
2. Formula in R units, showing volume treatment explicitly.
3. Threshold value + evidence basis (expectancy lift with significance on non-holdout settled data, PromotionGate-grade; convenience is not a basis).
4. Blast-radius statement (gate-only admission vs resolver levels; downstream consumers listed).
5. Validation plan (unit + new TT01 run ID + rejection-mix report + C4/survivor invariance).
6. Rollback (single-flag revert to gross-only).
Carried prohibitions: `minRR=1.5` not assumed; no resolver-level cost baking without separate review (P36 §2.5 high-risk class).

## 2. BE — facts vs hypotheses

### Mechanical facts (closed)
- F1: BE lifecycle — trigger 1.0R, SL = entry ± 0.0 buffer, live-price improvement check, once-only latch, modify-only (`PositionLifecycleManager.mqh`; P36 §3, P37).
- F2: Buffer plumbing + directional placement complete, default 0.0 = legacy-exact (P37).
- F3: Owning-symbol propagation complete via P39 (`DiscoverPositions` filter, BE/TS pricing, stops guard, R-ratio, event attribution all keyed to `m_symbol`).
- F4: BE/TS/partials default-OFF with zero enabler callsites (verified P39, P41). Current settled datasets contain NO BE exits (single-policy 2R/1R) — no BE outcome evidence exists anywhere in-repo.

### Strategy hypotheses (each requires explicit human choice)
- H1 — enabling BE at all: converts stop↔scratch outcomes across the distribution; the dominant decision, not a detail.
- H2 — trigger timing (1.0R current default vs other): interacts with tail capture; unmeasured.
- H3 — buffer value: no invariant defines it (spread-based? fixed? R-fraction?); unconstrained by evidence.
- H4 — exit-suite coherence: BE-alone vs trailing/partial suite (both larger redesigns, prohibited chain — BE-alone must be specified as such, not as a foot in the door).

### Minimum decision package for future authorization
1. Enabling policy (which modes/symbols/conditions; default-OFF preserved elsewhere).
2. Trigger + buffer definitions (units, source, magnitude).
3. Success metric + measurement design: scratch-rate vs tail-capture on non-holdout data. NOTE: current telemetry cannot supply it (no BE exits recorded) — the package must specify either a simulation design over settled rows or a forward shadow-measurement protocol. Specify, don't execute here.
4. Validation plan + rollback (disable-flag revert to current unwired state).
Sequencing constraint: value moot while disabled — authorize policy + value + metric together, never value alone.

## 3. Closed branches (reaffirmed, reopen criteria: new defect evidence only)

- SymbolContext wiring — P39 complete/validated. Concentration cap — P41 class A, no change warranted (325,433 evals, 0 mismatches, clean 28.56/30/192.57 boundary). Sizing/exposure — P37 complete/validated. Profitability desire alone never reopens these.

## 4. Generic minimum-spec template (reusable for any future trading-behavior proposal)

Terms+sources → formula → threshold/value+basis → blast radius → validation → rollback → prohibitions-respected statement. A proposal missing any section is returned, not implemented.

## 5. Standing prohibitions (unchanged)

No threshold/value selection in this record; no optimization/WFO/MC; research BLOCKED; deployment NOT AUTHORIZED; profitability NOT established; B8/B9 uncertified/unregenerated; holdout untouched. STOP after P42 — next movement requires the human design decisions in §§1–2.
