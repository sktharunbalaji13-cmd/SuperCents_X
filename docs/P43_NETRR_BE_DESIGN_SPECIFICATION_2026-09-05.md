# P43 — NET-RR & BE HUMAN DESIGN SPECIFICATION REVIEW

Date: 2026-09-05
Mode: READ-ONLY specification review. No code, test, parameter, baseline, holdout, or prior-record modification; no runs, optimization, or deployment actions. No threshold/value selected; all choice fields explicitly OPEN.
Authority: senior-advisor direction on P42 (strategy choices require explicit specification; profitability must not justify selections).
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`. Tree: 37 tracked files, P41 state (verified read-only).

## Disposition

### `P43 SPECIFICATION COMPLETE — HUMAN DECISIONS REQUIRED, NO IMPLEMENTATION AUTHORIZED`

## Firewall (binding on any future selection)

Sprint15 negative expectancy/PF and weak score calibration MUST NOT justify any net-RR threshold or BE setting. Packages below stand on execution semantics only. Profitability proof remains a later OOS/WFO/robustness stage. Tuning behavior against the evidence that indicted the strategy is prohibited.

## 1. Net-RR decision package (draft — choice fields OPEN)

1. **Terms**: spread INCLUDED. Commission EXCLUDED (no pre-trade API; history-only). Swap EXCLUDED (duration unknowable pre-trade). Realized slippage EXCLUDED (unknowable). Tolerance EXCLUDED (bound, not cost). Commission/swap variants deferred — each needs a stated assumption (rate source + lots treatment) to become reviewable.
2. **Sources**: `SYMBOL_SPREAD × point` read at gate time (same tick as existing floor reads); `stopDistance`/`targetDistance` (plan fields).
3. **R-units**: `netRR = (targetDistance − spreadDist) / (stopDistance + spreadDist)`; guard denominator > 0 else 0; set `hasNetRiskReward=true` when computed. Convention (ratifiable): symmetric round-trip spread application. Worked illustration (NOT evidence): stop 100pts, target 110, spread 20 → net 90/120 = 0.75 vs gross 1.10.
4. **Volume**: not entering (R-denominated; per P42-F5). Any money-denominated variant must declare its lots assumption.
5. **Threshold**: OPEN. Options: (a) 1.0 semantic parity — "target covers stop + round-trip spread", preserves the current gross-1.0 gate's meaning under costs; (b) higher value — requires expectancy-lift evidence on non-holdout settled data per P42. No selection made.
6. **Gate action**: observe-only FIRST (log netRR + would-reject flag, admission unchanged) for one validation window; rejection only after audit. Reversible by construction.
7. **Blast radius (measured, P41 artifacts, both runs identical)**: 384 executable plans — min RR 1.00, p10 1.24, median 2.00, p90 3.18, max 14.50. Worst-case additional cuts: net-1.0 ≤ 35/384 (9.1%, the [1.0,1.2) bucket); net-1.5 ≤ 71/384 (18.5%, +[1.2,1.5)); 289/384 (75.3%) sit ≥ 2.0, untouched by any sane threshold. Gross gate already cuts 371 sub-1.0 plans (unchanged). Bounds for the human's choice, not a recommendation.
8. **Validation**: unit formula vectors (incl. zero-guard) + new TT01 run ID + rejection-mix report + C4/survivor invariance + observe-only log audit before any rejection.
9. **Rollback**: `hasNetRiskReward=false` revert; gate reads gross again (2-line change surface).

## 2. BE decision package (draft — choice fields OPEN)

1. **Enablement policy**: OPEN (default-OFF preserved). Options: per-symbol/mode rollout; precondition: metric protocol (§6) in place BEFORE any enabling.
2. **Trigger**: current default 1.0R specified as candidate; alternatives require tail-capture rationale. Unmeasured either way.
3. **Buffer**: OPEN. Options: 0.0 (current; semantically lossy — scratch fills −spread−commission−swap per P36 BE-4); 1×spread (makes the stop level literally breakeven on spread; commission/swap still leak — honest bound); R-fraction/fixed-points (require justification). No selection.
4. **Directional behavior**: specified (P37 as built: BUY entry+buffer, SELL entry−buffer; live bid/ask improvement-check unchanged).
5. **SL/TS interaction**: specified — BE once-latch precedes TS evaluation; TS unchanged default-OFF; no partials (prohibited chain); BE-alone scoped explicitly, not a foot in the door.
6. **Metric source**: zero BE exits exist in telemetry — options: (a) forward shadow protocol with BE enabled in reserved execution + simulated fills, measuring scratch-rate vs tail capture; (b) replay simulation over M1 paths of settled rows (M1-history availability is a stated requirement). Specify-only here; no execution.
7. **Pre-live gate**: no live BE without a measured scratch-vs-tail result from §6. Mandatory.
8. **Blast radius**: UNMEASURABLE from current logs (no R-trajectory logging; lifecycle R unlogged). Bounded only after §6 measures trigger-reach frequency. Optional prerequisite: R-reached logging line (CONC-MEASURE pattern, logging-only) under separate measurement authorization.
9. **Rollback**: `EnableBreakeven(false)` + buffer 0.0 (already the defaults).

## 3. Closed branches (not revisited)

Wiring P39 · sizing/exposure P37 · cap P41-class-A (no change). Reopen on defect evidence only.

## 4. Standing state

Research BLOCKED · deployment NOT AUTHORIZED · profitability NOT established · B8/B9 uncertified · holdout untouched · no code/state changed in P43 (this record excepted). STOP after P43 — next movement is human completion of the OPEN fields above, then implementation authorization against the P42 minimum-spec template.
