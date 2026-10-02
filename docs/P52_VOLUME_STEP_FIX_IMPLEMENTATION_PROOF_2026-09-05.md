# P52 — CONTROLLED VOLUME-STEP FIX IMPLEMENTATION & PROOF

Date: 2026-09-05
Mode: Authorized implementation under P51 contract (int-domain, tol 1e-8). No redesign, no opportunistic cleanup, no other policy/optimization actions.
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`. Not committed (attributable dirty tree preserved; no commit authorized). Rollback reference: pre-P52 state = current tracked diffs minus the P52 hunk in `Trading/TradeValidation.mqh` (delete the stepOk block; MathMod decision falls through).

## Disposition

### `P52 IMPLEMENTATION PROOF PASS`

## 1. Exact production change (1 file, 1 decision block)

`Trading/TradeValidation.mqh::IsVolumeValid` — P50 shadow k/dev lines retained verbatim; the `remainder > 1e-10` decision replaced by: `stepOk = (shadowDev <= 1e-8)` for `volStep>0`, legacy `!(remainder > 1e-10)` frozen for `volStep<=0`. Range check, reason strings, signature, callers, producers, broker policies untouched. No `NormalizeDouble`. VOL-MEASURE diagnostics retained (per P51).

## 2. Validation results

- Compiles: EA 0/0 (`compile_p52_ea.log`), runner 0/0 (`compile_p52_tests.log`).
- Full suite: **3359/3359, 0 FAIL** (3344 baseline + 15 new P52 tests, `Tests/p52_artifacts/p52_unittests_hits.log`, tag 13:30:39; P52 suite line `15/15 passed, 0 failed` — exact min/max, producer dust forms 0.30/0.18/0.50, grid k=1..50, floor-form, half-step/0.015 rejected, ±1e-7 rejected, +1e-9 band accepted, range unchanged, 6 corpus spot volumes accepted).
- **3,717-pair replay (offline, exact arithmetic)**: new rule PASS 3717/3717; 317 dust rejects rescued; 0 old passes flipped; 0 incorrect.
- **P48 preservation (NEW rerun, wall 13:36)**: 1827 plans → 380 executable, exactly 4 NetRR rejects with ids {225,240,759,895} — byte-for-byte P48 behavior.
- **LEGACY fill-recovery run** (wall 13:36:53, ~15 min Model=1): 183,939 volume validations, **0 REJECT-STEP** (pre-fix: 24.19% would fail — 44,494 rescued in-window); **volume-step ORDER-FAILED: 0** (pre-fix: ≥2 incl. verbatim 0.30/0.18 rejects); **first fill is the P44-blocked volume: `ORDER-SENT Volume=0.30 Retcode=DONE` (deal #2 0.3 sold, closed at 0.3)** — the anomaly's signature volume now executes. Plans identical (380 EXE, NetRR ids match); signals/gates unchanged, only admissibility recovered. BE-SHADOW 0 (single-position flow, consistent).
- Unrelated gates: C2/C6/C1 suites green in-run; sizing formulas, allocator, broker policies untouched (diff = validator decision only).

## 3. Governance checks

No PromotionGate/TT01/B8/B9/holdout/strategy-parameter/research change; BE/TS/partials still OFF (0 shadows; enablers zero); concentration cap 30.00; P31/C4/P37/P39/P41/P48 intact. Not committed (tree dirty by governance). Rollback: revert the single decision block to pre-P52 (`remainder > 1e-10` comparison, P46-era logic) — 1 file, 1 hunk.

## 4. Notes (honest, non-blocking)

- LEGACY event count (183,939 vs P50's 3,717) is attempt-level multiplicity from plan re-evaluation across ticks (183939/384 ≈ 479 attempts/plan) — not a regression; pre-fix equivalent rate would have been ~44.5k false rejects in-window.
- Rounding-path residue: the legacy `rem > 1e-10` frozen branch is unreachable on live symbols (step always > 0); retained verbatim per contract.
- Instrumentation retention: VOL-MEASURE prints remain (P51-specified until validation); future cleanup phase may remove.

Artifacts: `Tests/p52_artifacts/` (hits + legacy raw + new-unit suite), `compile_p52_*.log`, inis reused (p44_observe/p41_conc). STOP after P52 — no re-freeze, no B9 certification, no profitability optimization; baseline/re-freeze decision is a separate future authorization.
