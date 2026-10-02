# P48 — NET-RR 1.0 RISK-GUARD IMPLEMENTATION & VALIDATION

Date: 2026-09-05
Mode: Authorized policy implementation (human/senior-advisor authorization on P47). No other policy, optimization, or deployment actions.
Authorization: implement ONLY `hasNetRiskReward && belowNetRRThreshold` rejection after the retained gross clause, spread-only 1.0R, observe P46 semantics otherwise.
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`. No reset/stash/commit.

## Disposition

### `P48 COMPLETE — NETRR 1.0 RISK GUARD VALIDATED`

## 1. Implementation (1 clause, `Entry/ExecutionPlanner.mqh::BuildPlan`)

`else if(plan.hasNetRiskReward && plan.belowNetRRThreshold)` → `PLAN_REJECTED`, reason `NetRR Below Minimum`, bucket 5 reused (RR family; no schema/label change — slots 0/1/3 unused but relabeling rejected as larger surface; per-plan reason + Below10 flag give attribution). Strict `<` numerics, no epsilon. Gross ladder, resolvers, sizing, BE/TS (OFF), caps, survivor/C4 untouched. `EvaluateSingleCombo` diagnostic matrix intentionally untouched (non-production per P36 — recorded divergence: matrix stays gross-only).

## 2. Before/after behavior (same window: EURUSD H1 2026.01.01→04.01 Model=1 NEW)

- P46: 384 executable, 4 flagged, all executable. P48: **380 executable** (−4, exactly the flagged set).
- The 4 flips, individually: Dec 225 (1.00→0.9959), 240 (1.03→0.7419), 759 (1.01→0.9932), 895 (1.37→0.8128) — each `EXECUTABLE → REJECTED specifically by NetRR guard` (reason string verified per line). Remaining 380 not touched by the new clause.
- Reject mix: 371/598/13/461 IDENTICAL plus `NetRR Below Minimum: 4` (bucket 5 = 375).
- Boundary both directions: Dec 226 (NetRR "1.0000", flag 0, EXECUTABLE) vs Dec 1603/1660 ("1.0000", flag 1, rejected on other gates) — full-precision numerics decide, formatting never overrides.
- No other Below10=1 plan changed outcome (all others already rejected upstream).

## 3. Validation

EA 0/0 (`compile_p48_ea.log`), runner 0/0, suite 3344/3344 fresh tag 12:47:34 (`Tests/p48_artifacts/p48_unittests_hits.log`). P31/C4/P37/P39 intact (no files touched beyond the clause; enablers zero; cap 30.00; B9/PromotionGate/holdout/params untouched). BE-SHADOW 0 in window (NEW, expected).

## 4. Monitoring evidence (P47 requirement)

Per-candidate plan lines carry timestamp (log prefix), symbol (prefix), direction (derivable SL vs entry), Entry/SL/TP (→ stop/target distances), gross + NetRR@4dp, Below10 flag, status + reason (322,428-line raw: `Tests/p48_artifacts/p48_validate_raw.log`). Per-plan spread not logged separately but algebraically recoverable offline (spreadDist = (target − net×stop)/(1+net)). Live-spread frequency impact remains unmeasured by construction — monitor rejection rate before any escalation (none authorized).

## 5. Rollback

Delete the P48 clause (ladder falls through to `if(valid)` as in P46); flag/log/plumbing remain dormant and harmless. Gross behavior restores exactly.

## 6. Standing state + firewall restated

Execution-risk guard ONLY — no profitability filter claim (n=4, no outcomes). No BE/TS/partials, dust-fix, cap, threshold-escalation, optimization/WFO, research, holdout, B9, deployment actions. STOP after P48.
