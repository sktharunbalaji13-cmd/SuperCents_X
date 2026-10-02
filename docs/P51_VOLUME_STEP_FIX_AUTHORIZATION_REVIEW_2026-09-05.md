# P51 — VOLUME-STEP FIX DESIGN & IMPLEMENTATION AUTHORIZATION REVIEW

Date: 2026-09-05
Mode: READ-ONLY design review. No code/test/parameter/baseline/holdout modification; no fix selected-for-implementation by this record beyond the authorization verdict below (implementation itself is a future phase).
Authority: senior-advisor P51 prompt on P50 (`docs/P50_VOLUME_STEP_MEASUREMENT_2026-09-05.md`: frequency measured, fix design ready).
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`. Tree unchanged since P50 (verified read-only).

## Disposition

### `P51 IMPLEMENTATION AUTHORIZED`

Narrow contract below. BE stays OFF; no optimization/deployment; no profitability claim.

## 1. Remedy comparison (both rescue 317/317 with 0 flips at tol=1e-8 on measured pairs)

- **A step-epsilon** (`rem < tol || step−rem < tol`): smallest diff; keeps remainder-space reasoning with its two-sided/fmod-sign subtleties.
- **B int-domain** (`k=round((v−vmin)/step)`; accept iff `|v−(vmin+k·step)| ≤ tol`): explicit auditable grid index; single symmetric comparison; independent of fmod edge semantics; shadow k/dev ALREADY computed+logged in production (P50) — the fix promotes measured diagnostics to decision basis. Smallest conceptual delta from the validated state.
- **Selected: B.** Tolerance **1e-8**, justified by measured margins: observed dust ≤ 6e-16 (2e7× below tol); step/2 = 0.005 (5e5× above tol); pass-side max 4e-16. Genuinely off-grid remainders live ≥ ~1e-9 in practice — 7-order separation. Theoretical residual (±1e-9 adversarial band) unreachable from grid-intended producers (floor/round/clamp/fixed-lot); recorded, not blocking.

## 2. Exact minimal contract (future implementation phase must follow verbatim)

In `CTradeValidation::IsVolumeValid`, AFTER the unchanged range check: if `volStep > 0`, compute `k`/`dev` (P50 shadow lines, already present) and accept iff `dev <= 1e-8` (replacing the `MathMod > 1e-10` comparison; keep the reason string, appending measured dev for audit). If `volStep <= 0`, preserve legacy path exactly (degenerate-case behavior freeze). Range check, signature, callers, producers, dead duplicate (`ExecutionManager::ValidateVolume` — align only if ever revived), `NormalizeDouble` (not used), broker min/max/step policy: all unchanged. P50 VOL-MEASURE prints retained through validation, removable after.

## 3. Callers/downstream (fix is local)

Single live gate: `TradeManager` C2-check (`:333`) via `ValidateAll` (`:224`). No coordinated changes: producers already emit grid intents; the fix aligns the gate to intent. Effect direction: previously-dusted valid volumes start sending (fill recovery on identical signals/sizing); passing set unaffected; no sizing/lot value changes anywhere.

## 4. Boundary cases (contract covers)

Min (dev 0 ✓) · max (range-then-grid ✓) · exact multiples ✓ · just-off-grid ±1e-7 (reject ✓) · ±1e-9 band (accepted as dust — documented residual) · non-grid 0.015/0.105 (reject ✓, measured pattern) · steps 0.01/0.1/1.0 (grid rates 58%/48%/0% inform, don't alter, the single tol: 1e-8 ≪ every step/2).

## 5. False-acceptance proof basis

0 observed in 3,400 passes (dev>1e-6 hunt); mechanism requires ≤1e-8 dev for off-grid (7-order gap from practice); post-fix proof replays all 3,717 P50 pairs expecting 3717 PASS-side-correct (3400 still pass + 317 newly pass, 0 incorrect).

## 6. Compatibility

P48 (planner-level flips orthogonal; fills only recover), P37 sizing/tick math (values untouched), P39, P41 cap, P31/C4, B8/B9, PromotionGate/TT01/holdout, BE-OFF, research BLOCKED — all preserved. Risk sizing, lot calculation, broker policies unchanged (admissibility only).

## 7. Post-fix proof matrix (implementation phase must demonstrate)

Compile 0/0 both binaries · suite 3344/3344 · NEW unit tests: on-grid accepts (0.30/0.18/0.50 forms), off-grid rejects (0.015/0.105), ±1e-7 reject documentation, min/max exact, steps 0.01/0.1/1.0, full 3,717-pair replay (expect 3717 pass-as-intended, 0 incorrect) · P48 rerun (380 executable + 4 NetRR rejects preserved; ORDER-FAILED-volume rate → ~0; fills delta quantified with signals identical) · behavior-delta report · enablers zero · B9/holdout untouched.

## 8. Standing state

No fix applied in P51 (this record is the authorization). STOP after P51 — implementation awaits a P52-style execution phase under this contract.
