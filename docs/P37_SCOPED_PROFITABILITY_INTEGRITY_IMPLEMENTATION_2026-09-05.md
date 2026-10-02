# P37 — SCOPED PROFITABILITY INTEGRITY IMPLEMENTATION

Date: 2026-09-05
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`
Authority: P36 split authorization (`docs/P36_PROFITABILITY_ROOT_CAUSE_VERIFICATION_2026-09-05.md` §8–§9). No broadening. No optimization. No TT01. No certification/re-freeze/deployment.

## Required disposition

### `P37 IMPLEMENTATION PARTIAL — SPECIFIC ITEMS REMAIN BLOCKED`

Mechanical integrity complete and validated (compile + full unit suite green). Three sub-items STOPPED at P36/P37 design boundaries as instructed (formula/value/wiring requiring separate authorization). Details in §6.

## 1. P36 authorization basis

- Fix 1: separate net-R admission field authorized; `minRR=1.5` and any cost formula NOT authorized (P36 §2, §8b).
- Fix 2: buffer-capable BE + `SetSymbol` routing correction authorized; enabling BE/TS/partials, 1.5R triggers, 50%-scale-out, ATR/spread trailing NOT authorized (P36 §3, §8c).
- Fix 6: live-path sizing/exposure integrity authorized (`TradeManager` C2/C3 + active portfolio gate); dead `CRiskManager` seven-gate path excluded; no new risk parameters (P36 §4, §8a).

## 2. Clean-tree precondition / result

- `git rev-parse HEAD` = 36c7a73, branch `main`. Pre-P37 tree held 26 modified files. Content inspection (`git diff`): `Portfolio/SymbolContext.mqh` +134 lines = P31 survivor policy (`ActiveTierSurvivorPolicy.mqh` include, seen-arrays, P30 comments); `Tools/TT01/baseline/baseline.m Euchre.manifest.json` + `telemetry_v4_20260130.csv` = P35 B8→B9 re-freeze; remainder = P31-era hardening (OOM guards, renderer/detector guards). Matches P35's "26 files (24 P31 + 2 B9)". Attributable to authorized state, not unrelated work.
- Per P37 §HARD PRECONDITION steps 3–4 (no reset/stash/delete/commit to manufacture cleanliness), the tree could NOT be made clean without additional authorization. Proceeded PARTIAL: all edits confined to 11 files verified CLEAN pre-P37 (`git status` showed no modification to `Entry/`, `Risk/`, `Trading/`, `Portfolio/AllocationEngine|CapitalAllocator|PortfolioRiskManager`, `Tests/unit/TestIntegrityFixes.mqh`). `Portfolio/SymbolContext.mqh` (dirty) deliberately NOT touched — its wiring sub-item is BLOCKED (§6.3).
- Post-P37 `git status`: 37 modified = 26 pre-existing + 11 P37 (diffstat §4). B8/B9/manifest/CSV byte-state untouched by P37 (still exactly the pre-P37 dirty state; P37 added no baseline bytes). No prior governance record modified. No commit/stage performed.

## 3. Exact authorized scope implemented

### Fix 1 — net-R gate field (plumbing only)
- `Entry/ExecutionPlanTypes.mqh`: added `double riskRewardNet; bool hasNetRiskReward;` to `ExecutionPlan` with boundary comment. No threshold, no formula.
- `Entry/ExecutionPlanner.mqh::BuildPlan`: zero-init site + post-computation carry `riskRewardNet = riskReward; hasNetRiskReward = false;`. Gross gate (`riskReward < 1.0`) UNCHANGED. `EvaluateSingleCombo` (shutdown-log-only) intentionally untouched — diagnostic path, no plan struct.

### Fix 2 — mechanical exit integrity
- `Entry/PositionLifecycleManager.mqh`: `m_beBufferDist` (default 0.0) + `SetBreakevenBuffer/GetBreakevenBuffer`; `ApplyBreakeven` places `priceOpen ± buffer` directionally (default 0.0 = legacy exact); `Init` guards `if(m_symbol == "") m_symbol = _Symbol` (respects pre-Init `SetSymbol`, default path identical).
- BE/TS defaults still OFF; zero enabler callsites added (grep `EnableBreakeven(true|EnableTrailingStop(true` over `Entry Trading Portfolio Risk Core` = empty, verified post-change).

### Fix 6 — live-path sizing/exposure integrity
- `Risk/PositionSizer.mqh::Calculate`: sub-`volumeMin` lots return invalid `POSITION-SIZING-REJECTED` (was silent clamp-up); ceiling clamp retained (under-risks only). `Update()` now refreshes cached contract spec when initialized (was empty).
- `Trading/TradeManager.mqh` C2: invalid sizing under an active risk% path → `POSITION-SIZING-REJECTED` log + `SetPlanStatus(i, PLAN_REJECTED)` + `m_totalFailed++` + `continue` (was silent 0.01-lot fallback). Fixed-lot mode (no sizer/risk%) fallback unchanged.
- `Portfolio/CapitalAllocator.mqh`: FIXED_PERCENT round-then-clamp (was clamp-then-round approve-then-reject); EQUAL_RISK gains tickSize divisor + tickSize/point guards + symbol-aware point basis + maxLot clamp (newly bounded; was unbounded above).
- `Portfolio/AllocationEngine.mqh`: symbol-aware point basis + tickSize divisor + `riskPerLot<=0`/invalid-point/tick guards returning `ALLOC_REJECTED` with reasons (was divisor-less, `_Point`-based, unguarded).
- `Portfolio/PortfolioRiskManager.mqh` §4: `vol*price` → `vol*price*contractSize(symbol)`; `stopDist*_Point*100000` → `stopDistance*contractSize(symbol)` per-1-lot risk proxy; unknown contract size falls back to legacy arithmetic (never zero). Cap percentages UNTOUCHED.
- `Risk/ExposureTracker.mqh::Update`: long/short exposure + open-risk legs × per-symbol contract size with legacy fallback. (Live sizing consumer is the dead `CRiskManager` path per P36 §4.10; effect is snapshot/display correctness + future-consumer safety. Caps untouched.)
- `Entry/StopLossResolver.mqh`: new `PipToPriceDistance(pips, point)` (10pts/pip on 3/5-digit, 1pt/pip on 2/4-digit, legacy fallback); buffer + fallback use it (was hardcoded `*10.0*point`); broker-minimum fallback floored at `max(configured, stopsLevel + spread)` from existing market data (was bare minimum → lottery-ticket stops).
- `Entry/ExecutionPlanner.mqh` (2 sites): `minStopDist` via `PipToPriceDistance` (was `*10.0*m_point`).
- `Tests/unit/TestIntegrityFixes.mqh` C2h: contract-change update — `TEST_FALSE(rTiny.valid, "C2h-P37: sub-minimum lots rejected, not floored")` (was floor-clamp assertion pinning the exact defect; updated per authorization, not re-pinned).

## 4. Exact files changed (P37 delta: 11 files, +171/−42)

`Entry/ExecutionPlanTypes.mqh` (+7), `Entry/ExecutionPlanner.mqh` (+12/−4), `Entry/PositionLifecycleManager.mqh` (+25/−5), `Entry/StopLossResolver.mqh` (+31/−5), `Portfolio/AllocationEngine.mqh` (+32/−6), `Portfolio/CapitalAllocator.mqh` (+34/−8), `Portfolio/PortfolioRiskManager.mqh` (+22/−5), `Risk/ExposureTracker.mqh` (+14/−3), `Risk/PositionSizer.mqh` (+17/−2), `Trading/TradeManager.mqh` (+14/−4), `Tests/unit/TestIntegrityFixes.mqh` (+5/−3).
Evidence: `compile_p37_ea.log`, `compile_p37_tests.log`, `Tests/p37_artifacts/p37_suite_hits.log`, helper scripts `Temp/p37_compile.ps1`, `Temp/p37_run_tests.ps1`.

## 5. Prohibited items left untouched (verified)

No `minRR`, no cost formula, no PromotionGate change, no risk% change, no BE/TS/partial enabling, no 1.5R triggers, no ATR/spread trailing, no new strategy parameters (buffer member defaults 0.0, setter unwired — plumbing, not policy), no `CRiskManager` dead-gate edits, no survivor/C4/signal/confluence/entry-frequency logic, no B8/B9/TT01/holdout/research changes. `git status` confirms: `Calibration/PromotionGate.mqh`, `Entry/ActiveTierSurvivorPolicy.mqh`, `Tools/TT01/baseline/*` (beyond pre-existing state), `Risk/RiskManager.mqh`, `Risk/RiskTypes.mqh`, `Portfolio/PortfolioRiskTypes.mqh` unmodified by P37.

## 6. Validation results

- Compile `SuperCents_X.mq5` (MetaEditor64): `Result: 0 errors, 0 warnings` (`compile_p37_ea.log`). First pass caught a P37 editing error (9× `undeclared identifier 'lots'` from a lost declaration); fixed, recompiled clean. No other file errors — cross-file struct/copy call sites (`m_plans[idx] = plan`, `GetPlan` copies, `ValidateAll`, `Build` request path) accept the new fields without change.
- Compile `Tests/TestRunnerEA.mq5`: `Result: 0 errors, 0 warnings` (`compile_p37_tests.log`).
- Tester run (Model=4 math-calc, EURUSD H1 2026.01.01→02, fresh binaries): `>>> BUILD 25A-RUNTIME-01 tag="2026.09.05 11:01:34" term=6140` → **GRAND TOTAL: 3344/3344 passed, 0 failed**; FAIL lines none. Targeted: C2 risk-sizing 16/16 (incl. new reject assertion), C6 directional validation 38/38, C1 resolver `structureResolved` flags 35/35 (covers hardened SL fallback path), C1 payload/identity suites green.
- P37 §Validation.3 checklist: survivor behavior — no survivor file touched + survivor suite inside green grand total; C4 — untouched; no silent over-risk — sizer rejects + C2 rejects + suite C2h asserts invalid; tick math consistency — divisor/point basis unified across sizer/allocator/engine + C2/C7 assertions green; exposure instrument-aware — notional formulas in gate + tracker; BE buffer mechanical — default 0.0 provably identical expression (`priceOpen ± 0.0`), improvement-check unchanged, BE still unwired; SetSymbol — Init guard in clean file, wiring deferred (§6.3); no new params/behavior beyond recorded deltas.

## 7. Compatibility (P31/P32/P34/P35/B9)

- P31 survivor: no ranking/tie-eps/dedup/C4 line touched; admission-boundary code in dirty `SymbolContext.mqh` not edited by P37. Suite green.
- P32/P34: no gate redefinition, no reinterpretation; P32 evidence package untouched.
- P35/B9: manifest + CSV + `B8_rollback` tree untouched by P37; B9 remains current baseline, uncertified, not regenerated. New binaries (`.ex5` rebuilds) are build outputs, not baseline content.
- PromotionGate/TT01 definitions/holdout/research state: unchanged. Research/optimization remains BLOCKED; deployment NOT AUTHORIZED; profitability NOT established (P37 claims no profit improvement — compile/unit validation cannot show edge).

## 8. Unresolved items requiring separate authorization (BLOCKED)

1. **Net-RR formula + threshold**: field plumbed, `hasNetRiskReward=false`. Any spread/commission/slippage/swap deduction arithmetic and any `minRR` value need a design authorization with measured cost ledger.
2. **BE buffer value**: capability exists at default 0.0; any nonzero buffer (spread-based or otherwise) is a strategy parameter needing authorization + validation.
3. **SymbolContext `SetSymbol` per-context wiring**: requires editing dirty `SymbolContext.mqh:639-651` (P31-authorized content); deferred until tree is committable/attributable under separate authorization. Lifecycle-side guard is in place.
4. **Concentration-cap recalibration**: caps (30%/50%) now bind at true notional (previously inert on FX). Percentages deliberately untouched; any retuning is optimization, explicitly out of scope — frequency impact must be observed in a future authorized validation run, not tuned here.
5. **Dirty-tree implementation provenance**: future phases need a committable clean state via authorized commit/stash decision (P37 was forbidden from manufacturing it).

## 9. Repository safety attestation

P37 performed: 11 scoped source edits + 1 test-contract update + 2 compile logs + 1 tester run (read-only execution, Model=4, 1-day window) + this record + Temp helper scripts. No resets/stashes/commits; no baseline/governance-record modifications; no holdout access; no optimization/WFO/MC; no deployment action. STOP after P37: no certification, re-freeze, or profitability work follows.
