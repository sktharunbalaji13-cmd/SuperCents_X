# P46 — NET-RR 1.0 OBSERVE-ONLY IMPLEMENTATION & VALIDATION

Date: 2026-09-05
Mode: Observe-only implementation. No rejection, activation, selection beyond the authorized 1.0 observe policy, optimization, or deployment actions.
Strategic decision (senior advisor on P45): spread-only terms · threshold 1.0R (lowest-blast-radius semantic candidate, NOT tuned optimum) · OBSERVE-ONLY · no profitability claim.
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`. No reset/stash/commit.

## Disposition

### `P46 COMPLETE — NETRR 1.0 OBSERVE-ONLY VALIDATED`

## 1. Code changes (3 points, 2 files)

- `Entry/ExecutionPlanTypes.mqh`: `bool belowNetRRThreshold` (+ comment: informational, gate uses gross).
- `Entry/ExecutionPlanner.mqh::BuildPlan`: function-local `const double netRR_ObserveThreshold = 1.0` (decision cited inline); `plan.belowNetRRThreshold = (hasNet && riskRewardNet < 1.0)` with **strict `<`, no epsilon** — exact comparison is well-defined; inventing an epsilon was prohibited and none was needed. Zero-init site resets the flag.
- Same function log line: `NetRR=%.4f Below10=%d` appended AFTER `RR=%.2f` (existing gross-first harvest patterns unaffected — verified); flag logged from numerics, never the formatted string.
- Gross gate (`riskReward < 1.0` ladder), resolvers, sizing, BE/TS wiring, caps, survivor/C4: untouched.

## 2. Precision policy

%.4f for observation; flag from full-precision numerics. No epsilon convention introduced. Justification observed live (see §4 dust band).

## 3. Validation

- EA compile 0/0 (`compile_p46_ea.log`); runner 0/0 (`compile_p46_tests.log`); suite on fresh tag 12:34:28: **3344/3344, 0 FAIL** (`Tests/p46_artifacts/p46_unittests_hits.log`) — baseline unchanged. One editing error self-caught (duplicated log call during replacement — repaired, verified, clean compile).
- Observation window (NEW, EURUSD H1 2026.01.01→04.01 Model=1, wall 12:38, same config as P44 run-A): all 1827 plan lines in new format, 0 unparsed; 384 executable (identical set to P44).
- Flag correctness: 4 executable Below10=1 (Dec 225/240/759/895: nets 0.9959/0.7419/0.9932/0.8128) — **all remain EXECUTABLE** (no selection change). Reject mix identical to P44 (371/598/13/461) — gross gate unchanged. 384 rejected plans also carry flags (observe covers all plans). BE-SHADOW 0 in window (no positions in NEW mode — expected); enablers still zero.
- **P44 reference refinement**: P44 reported 3 sub-1.0 on %.2f logs; numeric flag finds 4 (Dec 225 net 0.9959 rounded to "1.00"). Mechanism = formatting precision, not behavior change. Plus 2 dust-band cases (Dec 1603/1660: 4dp "1.0000", flag=1 from full precision) — proves the flag-from-numerics design: formatted-string comparison would misclassify both directions.

## 4. Rollback procedure

Set `plan.belowNetRRThreshold=false` unconditionally + revert log line to P44 form (or keep logging with flag forced false); gross gate never read the flag, so behavior is identical either way. Two-hunk surface (`ExecutionPlanner.mqh` computation + log; struct field may remain dormant).

## 5. Standing state

No rejection activated · BE/TS/partials untouched · cap 30.00 untouched · params/survivor/C4/B8/B9/PromotionGate/TT01/holdout untouched · research BLOCKED · profitability NOT established. Artifacts: `Tests/p46_artifacts/` (hits + 326,669-line observe raw), `compile_p46_*.log`, `%TEMP%\p44_probe\p44_observe.ini`, `Temp/p46_unittests.ps1`. STOP after P46 — rejection, BE, dust-fix, optimization, deployment all remain unauthoritized.
