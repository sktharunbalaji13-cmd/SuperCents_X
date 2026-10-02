# P45 — NET-RR POLICY SELECTION REVIEW & BE SHADOW CONTINUATION

Date: 2026-09-05
Mode: READ-ONLY policy review. No implementation/activation/selection/optimization; no state changes (this record excepted).
Authority: senior-advisor P45 prompt on P44 (`docs/P44_CONTROLLED_DECISION_EVIDENCE_2026-09-05.md`).
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`. Tree unchanged since P44 (verified read-only).

## Disposition

### `P45 DECISION-READY — HUMAN NET-RR CHOICE, BE STILL BLOCKED`

## Required output table

| Decision Area | Evidence | Candidate Options | Blast Radius | Mechanical/Strategy Classification | Additional Evidence | Human Decision Required |
|---|---|---|---|---|---|---|
| Net-RR threshold | 384 executable, net 0.74–14.39 med 2.00; below-threshold counts 3 @1.0 / 38 @1.2 / 71 @1.5; all affected from gross <1.5; dirs balanced (19/19 @1.2; 39/32 @1.5); deterministic across runs; gate still gross | 1.0 semantic parity / 1.2 moderate / 1.5 stronger (candidates, NOT recommendations) | ≤0.8% / ≤9.9% / ≤18.5% of executable; ≥2.0 core (75%) untouched by all; monotone removal-only; 2-line rollback | Threshold = strategy choice; plumbing + measurement = mechanical (done) | None for selection mechanics; expectancy basis required only if claiming performance (P42 package) | YES — threshold value + gate action (observe-only-first recommended, unselected) |
| Net-RR cost-model use | Spread-only deterministic + logged; commission pre-trade unavailable; swap needs duration; slippage realized unknowable; spread-net ≥ true-net always (omitted costs ≥ 0) | A observe-only / B conservative gate / C sufficient gating (UNSELECTED) | A: none. B: bounded by threshold table. C: not attainable (incomplete accounting) | Model limits mechanical fact; use-selection strategy choice | Cost ledger (for C or expected-cost variants) | YES — use selection (A/B/C) |
| BE policy | 1 first-touch/quarter (R=1.60, 0.28 SELL, Mar-23, exit unchanged); zero BE exits in all telemetry; trigger-reach rate ≈1 per position-quarter at current flow | Enabling/trigger/buffer all OPEN (no options eliminated, none selected) | Unmeasurable today (no R-trajectory logging); bounded after contract below is instrumented | Plumbing/routing mechanical (done); all behavior strategy choice | Shadow continuation per §3 + longer/multi-flow observation | YES — everything (policy, trigger, buffer, metric) |
| Volume-step dust | 0.30 rejected vs 0.28 passes live; `MathRound` dust vs `MathMod>1e-10` no-normalization (`TradeValidation.mqh:91-96`); repr-level mechanism proof; IEEE model suggests high latent rate BUT live pass-rate far higher → frequency unmeasured, MQL builtins unverified | None (deferred, separate phase) | Order-fill lottery on dusty values; signal/gate unaffected (384/384 IDs stable) | Confirmed defect class, value-dependent manifestation; fix = numerical policy (NormalizeDouble/step arithmetic) | In-platform tabulation (MQL unit, future phase) | YES — separate authorization to investigate/fix; explicitly NOT merged here |

## 1. Net-RR threshold analysis (candidates, not recommendations)

- **1.0** (3 plans, gross 1.01–1.37): restores semantic parity — passes-gross-but-fails-cost-covered. Minimal selectivity change; nearest to a mechanical correction without being one.
- **1.2** (38; all 35 of gross [1.0,1.2) + 3): first genuinely selective screen; balanced dirs.
- **1.5** (71; all of gross [1.0,1.5)): material filter (18.5%); "safer-sounding" but largest behavior change — advisor's caution recorded verbatim: not automatically better.
- All: removal-only (net ≤ gross at spread ≥ 0), reversible (flag + gross fallback), gross gate interaction purely additive (371 already cut below 1.0 gross, untouched). Net distribution p5/p25/med: 1.07/1.93/2.00.
- Profitability firewall: counts carry zero expectancy information (P44-expanded sample needed for any performance claim; none made).

## 2. Net-RR decision boundary

Ready for human choice among {threshold} × {observe-only-first vs reject} × {use A/B/C} with the P42 package (basis, validation, rollback). Observe-only-first is the low-regret path (structurally ready: flag + log exist). Semantic-vs-performance line: 1.0 = semantic policy; ≥1.2 = performance hypothesis requiring expectancy basis.

## 3. BE decision boundary + shadow continuation contract

BE stays OFF + shadow ON. Minimum contract per event: R trajectory · first crossing (✓ logged) · hypothetical stop (offline-computable once buffer chosen) · buffer (OPEN) · subsequent MAE (GAP: needs extreme tracking) · hypothetical exit (offline-simulable given trigger+buffer+M1) · actual exit R (GAP: close line lacks exit price/R) · R-difference (derivable) · spread at trigger (GAP: not logged) · symbol ✓/direction (inferable, add explicit field) / duration (derivable). Existing instrumentation covers ~4.5/12; gaps closable with logging-only extensions under future measurement authorization. Sample-rate reality: ~1 touch/position-quarter at current flow — longer window or richer flow needed regardless.

## 4. Volume-step anomaly disposition (separate, deferred)

Confirmed defect class + value-dependent manifestation; population frequency unmeasured (model/lab disagree); fix needs numerical-convention authorization; deferred as its own future integrity phase per advisor (not now, not merged).

## 5. Next executable step

Human selects net-RR {threshold × action × use} under §2 boundary (or requests the %.4f precision audit first); BE awaits shadow evidence; volume awaits its own phase. Firewall: P31/C4/B8/B9/P37/P39/P41-cap/P44 PromotionGate/TT01/holdout preserved; no profitability/WFO/research/deployment claims or actions. STOP after P45.
