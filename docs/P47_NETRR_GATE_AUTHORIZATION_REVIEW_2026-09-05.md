# P47 — NET-RR COST-MODEL & GATE AUTHORIZATION REVIEW

Date: 2026-09-05
Mode: READ-ONLY authorization review. No implementation/activation/selection/optimization; no state changes (this record excepted).
Question: is a spread-only 1.0 gate defensible as an EXECUTION-RISK GUARD (not a profitability filter)?
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`. Tree unchanged since P46 (verified read-only).

## Disposition

### `P47 RISK-GUARD DEFENSIBLE — NARROW P48 SCOPE SPECIFIED, AUTHORIZATION REQUIRED`

This record recommends; it does not authorize implementation. BE stays OFF and separate; volume dust stays separate; no profitability claim is made or implied.

## 1. The 4 sub-1.0 plans (measured, P46 artifacts)

| Dec | Dir | Stop | Target | Gross | Net | Implied spread | Failure mode |
|---|---|---|---|---|---|---|---|
| 225 | SELL | 244pts | 245pts | 1.00 | 0.9959 | ~1pt | razor-thin gross edge, quiet tick |
| 240 | SELL | 80pts | 82pts | 1.03 | 0.7419 | ~13pts | tight stop eaten by normal spread |
| 759 | BUY | 438pts | 441pts | 1.01 | 0.9932 | ~3pts | razor-thin gross edge |
| 895 | BUY | 149pts | 204pts | 1.37 | 0.8128 | ~46pts | healthy gross, spike-spread regime |

Pattern: the gate binds exactly on margin-of-safety failures — thin edge (225, 759), tight-stop-vs-spread (240), regime spike (895, the poster child: gross-healthy plan admitted into a 46pt-spread moment). No outcome linkage exists (run-local decision IDs cannot join Sprint17 telemetry) — and none is claimed.

## 2. Verdict: defensible as execution-risk guard

1. **Certain-cost coverage**: spread is the only cost known with certainty pre-trade. Net<1.0 means underwater on certain costs alone, before unknown costs (commission/swap/slippage) arrive. Refusing such plans enforces a minimum margin-of-safety invariant — independent of any profitability belief.
2. **Regime-adaptive**: live spread at decision time, not a fixed pip assumption — tightens automatically in news/illiquid regimes, permissive when quiet.
3. **Bounded + reversible**: 4/384 (1.04%) measured; monotone removal-only (net ≤ gross at spread ≥ 0); 2-line rollback; no resolver/ledger changes; gross ladder retained as backstop (defense in depth, not replacement).
4. **Semantic continuity**: preserves the existing gross-1.0 gate's meaning ("no sub-1R plans") under costs — the smallest possible policy step (P45: 1.2/1.5 touch 9.9%/18.5% and are performance hypotheses, not guards).

## 3. Limits (binding on any P48)

1. NOT profitability evidence: n=4, no outcomes, Sprint15 must not justify it.
2. Incomplete costs: passing plans are NOT guaranteed cost-covered (commission/swap/slippage unmodeled) — necessary, not sufficient.
3. Spread-regime dependence: validated on MetaQuotes-Demo spreads; live spreads (wider, spikier) will bind more often — live frequency impact UNKNOWN. The gate adapts via live-spread input, but post-activation rejection-rate monitoring is mandatory before any escalation.
4. Dust band: 2 plans within 1e-4 of 1.0 handled deterministically by strict `<` (P46) — documented, no epsilon invented.

## 4. Specified P48 scope (if authorized; not authorized by this record)

In `BuildPlan` gate ladder, AFTER existing gross `RR Below Minimum` clause (retained): reject with reason `NetRR Below Minimum` (new bucket or reuse bucket 5 — P48 to state) when `hasNetRiskReward && belowNetRRThreshold`. Nothing else changes: resolvers, sizing, BE/TS (stay OFF), caps, survivor/C4, PromotionGate, params. Validation: compiles 0/0, suite 3344/3344, observation-window rerun showing exactly the 4 plans flipping EXECUTABLE→REJECTED with all else identical, enablers zero, rollback procedure from P46 §4. Post-activation: monitor rejection rate and spread regime; no threshold escalation without new evidence.

## 5. Standing state

BE OFF + shadow (1 touch; still blocked) · volume dust deferred-separate · P31/C4/B8/B9/P37/P39/P41-cap/P44/P46 intact · research BLOCKED · deployment NOT AUTHORIZED · profitability NOT established · holdout untouched. STOP after P47.
