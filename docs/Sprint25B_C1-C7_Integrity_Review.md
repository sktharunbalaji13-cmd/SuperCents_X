# Sprint 25B — C1-C7 Integrity Fixes: Independent Senior Review

- Review ID: SR-25B-C1C7-01
- Commit under review: `7d4eecb0ccce329003ceb8363f67de7155570429` ("fix: resolve C1-C7 integrity defects on live legacy execution path")
- Parent baseline: `e881897e6a12626b2cf9f6cf18992a912cbf7c30` (B25-03C-A, frozen)
- Companion artifact (audited, NOT evidence): `docs/Sprint25B_Integrity_Fixes_Report.md`
- Method: READ-ONLY. `git show 7d4eecb:` + `git diff e881897 7d4eecb` + full source reads. No compilation, no test reruns, no runs, no modifications to production, tests, or the two B25-03C-B documents. No commit, no push.
- Scope: C1 stable magic, C2 risk-based sizing, C3 position gate, C4 closed-bar discipline, C5 confluence lifecycle, C6 directional SL/TP, C7 fill-price, H6 send-failure retryability (mandatory discrepancy review, cases A-G), H7 risk-per-lot formula, test evidence, TT01 population impact, B25-03C-B dependency.
- All file:line citations refer to `7d4eecb` content unless stated otherwise.

---

## 1) Commit scope

27 files, +1068 insertions (per commit stat). Files reviewed in full or by diff:
`Core/Config.mqh`, `Core/Engine.mqh`, `Portfolio/CapitalAllocator.mqh`, `Portfolio/SymbolContext.mqh`, `SuperCents_X.mq5`, `Entry/ExecutionPlanner.mqh`, `Entry/PositionInfo.mqh`, `Entry/PositionManager.mqh`, `Confluence/ConfluenceEngine.mqh`, `Structure/FVGDetector.mqh`, `Structure/SwingDetector.mqh`, `Structure/LiquidityDetector.mqh`, `Trading/TradeManager.mqh`, `Trading/TradeValidation.mqh`, `Tests/unit/TestIntegrityFixes.mqh` (new, 325 lines), `Tests/TestSuite.mqh`, `docs/Sprint25B_Integrity_Fixes_Report.md` (new, 176 lines).

Scope note: the commit also removes the unused `PositionInfo.commission` field (`Entry/PositionInfo.mqh`, `Entry/PositionManager.mqh`). Verified: no remaining readers of the struct field (the `vd.commission` write in `Monitoring/StatisticsReporter.mqh:219` uses a local variable, not the struct). Cosmetic; no functional impact.

---

## 2) Verdict matrix

| Fix | Verdict | Basis |
|-----|---------|-------|
| C1 stable magic | **PASS** | chain verified end-to-end |
| C2 risk-based sizing | **PASS** | wiring verified; one observation |
| C3 position gate | **PASS** | gate verified; one observation |
| C4 closed-bar | **PASS** | all three detectors verified; coverage gap |
| C5 confluence lifecycle | **PASS** | verified; coverage gap |
| C6 directional SL/TP | **PASS** | two layers verified; coverage gap |
| C7 fill-price | **PASS** | verified |
| H6 send-failure retryability | **FAIL** | claim-vs-code DISCREPANCY (see §6) |
| H7 risk-per-lot formula | **PASS** | formula correct; coverage gap |

---

## 3) C1 — stable magic number. PASS

Claim: magic is input-driven and survives Init; no `TimeCurrent()` derivation.

Code chain (verified):
- `Config.mqh:66` — `Init()` no longer assigns `m_magicNumber = (int)TimeCurrent()`; default is 0 (`Config.mqh:65`). `SetMagicNumber` at `Config.mqh:55`.
- `SuperCents_X.mq5:111-117` — input validated to `[1, INT_MAX]`, applied `g_engine.SetMagicNumber` BEFORE `g_engine.Init()` (`SuperCents_X.mq5:140`).
- `Engine.mqh:47-49` — pass-through; `SymbolContext` ctor receives magic from registration; `SymbolContext.mqh:628` — `m_tradeExecutionManager.SetMagicNumber(m_magicNumber)` which propagates to the request builder and the `CTrade` object (`TradeManager.mqh:134`). Also `PositionLifecycleManager.SetMagicNumber` (`SymbolContext.mqh:608`).
- Restart stability: magic is now a function of the input only; the dedup ledger (`m_submittedIds`, `TradeManager.mqh:39`) is memory-only and keyed by plan id, so restarts cannot orphan positions via a changed magic.

Evidence: `Tests/unit/TestIntegrityFixes.mqh:51-70` (C1a-e) covers the Config-level contract (default 0, survives re-Init, pre-Init setter sticks). The EA/Engine/SymbolContext/TradeManager chain is mechanical and verified by source; no unit test exercises it. Residual risk: none found.

## 4) C2 — risk-based position sizing. PASS

Claim: volume is derived from stop distance at the fill price and configured risk % of equity, wired into the live execution path.

Code chain (verified):
- `SymbolContext.mqh:686-696` — `m_positionSizer = new CPositionSizer()`, `SetSymbol`, `Init()` (populates cached symbol props via `RefreshSymbolProperties`, `PositionSizer.mqh:28-37`).
- `SymbolContext.mqh:702-707` — `SetPositionSizer(m_positionSizer)`, `SetRiskPercent(m_riskPercent)`, `SetMaxPositionsPerSymbol(...)`.
- Risk% flows: `SuperCents_X.mq5:120` → `Engine.mqh:50-52` → `Config` → `Engine.mqh:186-192` (forwarded to primary context in Init) → `SymbolContext.mqh:233-243` → TradeManager.
- Execution: `TradeManager.mqh:241-266` — `stopDistancePoints = |fillPrice - stopLoss| / point` at the FILL price; `CalculateCached(riskPercent, stopDistancePoints, ACCOUNT_EQUITY)`; sizing applied only when `valid && lots > 0`; otherwise logged `POSITION-SIZING-FALLBACK` and the fixed `m_lotSize` (0.01) is used (`TradeManager.mqh:88`).
- Sizer correctness (`PositionSizer.mqh:122-193`): validates all inputs; `riskMoney = equity * riskPercent/100`; `riskPerLot = (stopDistPoints * tickValue) / (tickSize / point)`; floor to `volumeStep`, clamp to `[volumeMin, volumeMax]`. All metadata-zero cases return invalid rather than divide-by-zero.
- Pre-existing path (unchanged by the commit, now actually reachable): the sizer was created but never wired before this commit; every order used the 0.01 default. Claim in the commit comment (`SymbolContext.mqh:698-701`) is accurate.

Observation (not a defect): on sizing failure the EA silently degrades to the fixed 0.01-lot default (logged). Risk-based sizing is therefore best-effort, not enforced; a broker property glitch returns the legacy behavior without blocking the trade.

Evidence: `TestIntegrityFixes.mqh:73-113` (C2a-i, H7a) unit-tests the sizer formula/monotonicity/clamps, not the TradeManager wiring. The wiring is verified by source only.

## 5) C3 — position gate. PASS

Claim: once the per-symbol open-position cap is reached (live positions, exact symbol + magic), no further plans execute.

Code (verified):
- `TradeManager.mqh:194-201` — gate `CountOpenPositions() >= m_maxPositionsPerSymbol` → `m_totalBlocked++`, log `ORDER-BLOCKED-POSITION-GATE`, `continue`. Placed BEFORE fill-price resolution, so blocked plans consume no failure counters.
- `CountOpenPositions` (`TradeManager.mqh:138-153`): exact symbol match + `POSITION_MAGIC == m_magicNumber` on the live account — no magic mismatch can gate another EA's positions.
- Cap clamp `MathMax(max, 1)` (`TradeManager.mqh:76`); risk% clamp `fmax(pct, 0.0)` (`TradeManager.mqh:75`).
- C3 vs dedup order (`TradeManager.mqh:184-201`): dedup check runs BEFORE the gate; a plan already submitted is counted as duplicate before the gate can see it — consistent ordering, no double-count of the same plan in both tallies.
- Blocked plans are NOT marked rejected and NOT recorded → they re-enter the scan every tick while a position is open (by design: "only skipped while a position is open").

Observation (metrics semantics): while blocked, each tick increments `m_totalReceived` and `m_totalBlocked` for the same plan — the tallies count scan-events, not unique plans. `m_totalBlocked` will therefore exceed the number of plans gated. Not a correctness defect; an interpretation caveat for any dashboard using these counters.

Evidence: `TestIntegrityFixes.mqh:116-141` (C3a-e) covers Init, clamps, and `GetOpenPositionCount()` against the live account (brittle: requires a fresh magic with zero positions). The gate branch itself is NOT unit-tested.

## 6) H6 — send-failure retryability. **FAIL — DISCREPANCY**

### 6.1 The claim (report §11, `docs/Sprint25B_Integrity_Fixes_Report.md:158-161`)

> "`TradeManager` send failures stay retryable (H6): on `OrderSend` failure the plan is neither marked rejected nor recorded, so the next bar re-attempts it (status stays `PLAN_PENDING`). `m_totalFailed` tracks attempts..."

The same claim is restated in the code comment at `TradeManager.mqh:336-339`:

> "an order is recorded as submitted ONLY after OrderSend was actually attempted. Failed sends stay retryable on the next bar; the same-tick dedup ledger is not polluted by failed attempts."

### 6.2 What the code actually does (`TradeManager.mqh:302-342`)

```
OrderSend(request, tradeResult)      // :302
CaptureExecutionTruth(...)           // :304
outcome branch                       // :316-334  (FILLED/PARTIAL -> succeeded;
                                     //            ACCEPTED_NO_DEAL -> logged;
                                     //            everything else -> m_totalFailed++)
RecordSubmitted(planId)              // :340  <-- UNCONDITIONAL
m_totalSubmitted++                   // :341  <-- UNCONDITIONAL
```

`RecordSubmitted` (`TradeManager.mqh:381-387`) appends to `m_submittedIds` and increments `m_submittedCount` — executed for EVERY plan that reached OrderSend, success or failure. The plan status is left unchanged (stays `PLAN_EXECUTABLE`).

### 6.3 Consequence

On the next bar the same plan hits `IsAlreadySubmitted` (`TradeManager.mqh:184-188`) and is skipped as a duplicate (`m_totalDuplicates++`) forever — until a restart clears the in-memory ledger. So:

- Intra-session: a failed send is NOT retried (contradiction), and the dedup ledger IS polluted (contradiction).
- The only sense in which "retryable" holds is across a restart (ledger is memory-only, `TradeManager.mqh:39-40`); the report does not say this.
- The report's "status stays `PLAN_PENDING`" is stale terminology: the status enum in use is `PLAN_EXECUTABLE`; `PLAN_PENDING` does not exist in the current planner statuses. The plan status is unchanged, true — but that does not make it retryable because dedup pre-empts it.
- The pre-send rejection branches (fill<=0 `:207-217`, ValidateAll `:220-237`, volume `:268-282`, build `:285-299`) are the mirror image: they DO mark the plan `PLAN_REJECTED` (non-retryable) and DO NOT record it (no dedup pollution). Those branches match the report's stated intent; the report conflates them with the post-send branch, which behaves oppositely on both axes.

### 6.4 Case table (A-G), as-implemented

| Case | Code path | Recorded? | Retryable intra-session? | Matches report? |
|------|-----------|-----------|--------------------------|-----------------|
| A OrderSend returns false | else branch `:328-334`, `m_totalFailed++` | YES `:340` | NO (dedup blocks) | NO |
| B Broker rejects retcode | else branch (non-fill retcode) | YES `:340` | NO | NO |
| C Timeout | else branch (no fill confirmed) | YES `:340` | NO | NO |
| D Connection lost | else branch | YES `:340` | NO | NO |
| E Accepted, no deal | `:323-327`, logged, not in failed tally | YES `:340` | NO (correct: broker has it) | n/a (report silent) |
| F Filled | `:316-322`, `m_totalSucceeded++` | YES `:340` | NO (correct) | consistent |
| G Partial fill | `:316-322` (FILLED|PARTIALLY_FILLED) | YES `:340` | NO (correct) | consistent |

Cases A-D contradict the report on both "recorded" and "retryable".

### 6.5 Verdict

`H6 CLAIM-vs-CODE: DISCREPANCY`. The H6 hardening intent is partially realized (pre-send rejections no longer pollute dedup and are marked rejected) but the post-send failure path is the opposite of the claimed behavior: failed sends ARE recorded as submitted and are NOT retried within the session, with no status change. This is the known B6/D5 item from the B25-03C-B assessment; it is documented here as a finding, NOT resolved by this review (no code changes authorized).

## 7) C4 — closed-bar discipline. PASS (with coverage gap)

- FVGDetector (`Structure/FVGDetector.mqh`): `end_i = 3` (newest triple (3,2,1), idxC = last closed bar); `start_i = newBars + 1`; `rates_total < 4` guard that still advances the cursor (`time[1]`); cursor advance to `time[1]` instead of `time[0]`. Forming-bar index 0 never enters the scan. Verified.
- SwingDetector (`Structure/SwingDetector.mqh:119-124`): `maxCenter = rates_total - 4` so the newest fractal is centered on the last closed bar (`center+2 = rates_total-2`). Verified.
- LiquidityDetector `DetectMitigations` (`Structure/LiquidityDetector.mqh:506-521`): `high[1]/low[1]/time[1]`, `rates_total < 2` guard — mirrors the already-closed-bar `DetectSweeps`. Verified.
- Replay/restart handling: the FVG discontinuity path rebuilds/clears the pool before the small-history guard; cursor-advance on `rates_total < 4` prevents stale FVGs. Verified.

Evidence: `TestIntegrityFixes.mqh:148-220` — three synthetic FVG cases (forming-bar gap excluded; closed-triple gap detected with correct `fvg.time` = middle bar; cursor-advance produces no duplicate). Good unit coverage of the FVG change. **Gap**: Swing and Liquidity closed-bar changes have no tests.

Population impact: detection sets change vs the e881897 baseline → see §10.

## 8) C5 — confluence signal lifecycle. PASS (with coverage gap)

- `ConfluenceEngine.mqh:333-339` — `CONFLUENCE_NONE` bars return before signal creation (previously a signal was created on EVERY bar).
- `MAX_SIGNAL_POOL_SIZE 4096` + `PruneExpiredSignals` (`ConfluenceEngine.mqh:536-566`): when the pool exceeds the cap, expired entries are compacted; `m_signalCount`, `ArrayResize`, `m_totalSignalsPruned` accounting. Memory and lifecycle-scan cost stay bounded.
- Shutdown summary corrected: "Signals in Pool" replaces the old `m_signalCount - m_totalSignalsExpired` expression which double-counted (`ConfluenceEngine.mqh:744-748`).

Evidence: `TestIntegrityFixes.mqh:223-240` — bare engine (no detectors), 20 `Update()` calls, asserts zero signals and no latest confluence. **Gaps**: the >4096 prune path is untested; no test exercises NONE-bar behavior with real detectors.

Population impact: NONE bars previously created signals (and any downstream consumers) — behavior change, see §10.

## 9) C6 — directional SL/TP. PASS (two layers)

- Planner layer (`Entry/ExecutionPlanner.mqh:290-301` BuildPlan; `:430-441` EvaluateSingleCombo): BUY requires `SL < entry && TP > entry`; SELL requires `SL > entry && TP < entry`. Rejects reuse the existing "Invalid Prices" bucket (`m_rejectionCounts[4]` / `rejectionDetails[4]`) — counter semantics preserved vs baseline.
- Execution layer (`Trading/TradeValidation.mqh:101-170` AreStopsValid): same directional bracket checked against the LIVE fill price (Ask/Bid), plus finite-price checks and stop-level distance checks vs fill.
- One subtlety verified: the planner brackets against the plan's `entryPrice`; the execution layer brackets against the live fill price. Both layers must agree for an order to be sent; a plan that was valid at plan time can still be rejected at execution time if the market moved — that is the intended two-layer design.

Evidence: `TestIntegrityFixes.mqh:243-288` — 7 cases against live Ask/Bid (BUY SL-above rejected, BUY TP-below rejected, valid BUY, SELL SL-below rejected, SELL TP-above rejected, valid SELL, unsupported type). **Gap**: the planner-layer checks (BuildPlan/EvaluateSingleCombo) are untested.

## 10) C7 — fill-price consistency. PASS

- `TradeValidation.mqh:46-53` GetFillPrice: BUY→ASK, SELL→BID, else 0.0.
- `TradeManager.mqh:207-217` — fill price resolved FIRST; `<= 0` → `PLAN_REJECTED`, `m_totalFailed++`, not recorded (consistent with the H6 pre-send policy).
- Sizing stop distance at fill (`:244-247`), margin via `OrderCalcMargin` at fill (`TradeValidation.mqh:172-200`), stops vs fill (`:101-170`).
- Requested price is independently built from live Ask/Bid at build time (`Trading/TradeRequestBuilder.mqh:58,64`); broker-confirmed price flows back via `CaptureExecutionTruth` (`TradeManager.mqh:304`), preserving the requested ≠ accepted ≠ actual distinction (unchanged, pre-existing).
- The plan's `entryPrice` is no longer used for any risk math at execution time.

Evidence: `TestIntegrityFixes.mqh:291-309` — unit checks on GetFillPrice vs live quotes. End-to-end path untested (no OrderSend in tests).

## 11) H7 — risk-per-lot formula. PASS (with coverage gap)

- `Portfolio/CapitalAllocator.mqh:110-113` — `riskPerLot = (stopDistPoints * tickValue) / (tickSize / _Point)`, replacing the literal `/ 1.0` denominator. Formula now identical to `PositionSizer.mqh:167`; unit-correct (value per point per lot = `tickValue / tickSize * point`).
- Live-path reachability verified: the portfolio gate runs for ALL entry modes (`SymbolContext.mqh:1080-1101` → `PortfolioRiskManager.mqh:245` → `AllocationEngine.mqh:125` → `CapitalAllocator.CalculateSize`); `Engine.mqh:126` creates the PortfolioManager unconditionally; `PortfolioManager.mqh:280` wires the risk manager into each context. So H7 affects live legacy execution math (portfolio-gate lot/exposure decisions), it is not dead code.
- H7 interacts with C2: C2 sizing uses `CPositionSizer` directly at execution; H7 affects the separate portfolio-gate allocation path. Both formulas now agree.

**Gap**: `CapitalAllocator.CalculateSize` has no unit test. The C2g/H7a assertion (`TestIntegrityFixes.mqh:96`) exercises the PositionSizer formula only; it would not catch a regression in CapitalAllocator.

## 12) Test evidence assessment

`Tests/unit/TestIntegrityFixes.mqh` (325 lines, 7 suites) is registered in `Tests/TestSuite.mqh` (+4: include + runner call) and folds into the reported 2796/2796 grand total. All suites are unit-level:

| Suite | Coverage | Nature |
|-------|----------|--------|
| C1 | Config magic contract | unit |
| C2/H7 | PositionSizer formula/monotonicity/clamps | unit (direct call) |
| C3 | Init, clamps, live-account position count | unit/helper (brittle: live account) |
| C4 | FVG closed-bar (3 synthetic scenarios) | unit (good) |
| C5 | Bare engine, no NONE signals | unit (shallow) |
| C6 | AreStopsValid vs live quotes (7 cases) | unit |
| C7 | GetFillPrice | unit |

Coverage gaps that matter for the review verdicts:
1. **No full-path test of `TradeManager.Update`** — dedup/gate/sizing/record semantics. This is precisely the layer where the H6 discrepancy lives; no test catches it. The report's "2796/2796, INTEGRITY FIX COMPLETE" therefore does not certify execution-path behavior.
2. CapitalAllocator (H7) untested.
3. Swing/Liquidity closed-bar (C4) untested.
4. C5 prune path (>4096) untested.
5. Planner-layer C6 checks untested.
6. No determinism/regression comparison against any TT01 baseline (no invariance evidence; none claimed here).

## 13) TT01 population impact

`TT01 POPULATION IMPACT: IMPACT POSSIBLE`.

- C4 (detection set: FVG triples, swing centers, mitigation bars), C5 (no signals on NONE bars; pool bounded), C6 (plans now rejected for inverted brackets) all change what enters the signal/decision/plan/telemetry streams on the live path. Any TT01 baseline populated by the e881897 behavior may shift on rerun.
- C1, C2, C3, C7, H7 are execution/identity-only (no signal-population effect).
- No runs were performed in this review; no invariance claim is made.

## 14) B25-03C-B dependency

`B25-03C-B DEPENDENCY: CONDITIONAL`.

Per fix: C1 SAFE (strengthens identity stability; ledger core untouched). C2 SAFE (execution sizing only). C3 SAFE (execution gating only). C4 CONDITIONAL (population shift affects replay/reconstruction baselines). C5 CONDITIONAL (same). C6 CONDITIONAL (rejection-stream shift). C7 CONDITIONAL (fill-based validation changes which plans execute). H6 CONDITIONAL (failed sends will be recorded as `submitted=true` in any truth/ledger ingest — B25-03C-B ingestion semantics must account for it). H7 CONDITIONAL (portfolio-gate lot math changes exposure decisions in replay).

Nothing is BLOCKED: the B25-03C-A ledger core (`Trading/ExecutionLedger.mqh`), the two B25-03C-B documents, and all frozen baselines are untouched by `7d4eecb`.

## 15) Observations (non-blocking)

1. H6 finding (§6) is the single material defect; the report's own §11 is factually wrong about the code it accompanies, and the code comment at `TradeManager.mqh:336-339` misdescribes the statement below it.
2. C2 fallback to 0.01 lots on sizing failure is silent-but-logged; risk sizing is best-effort.
3. C3 `m_totalBlocked`/`m_totalReceived` count per-tick scan events, not unique plans.
4. `PositionInfo.commission` removal is safe (no readers); bundled into the commit despite being unrelated to C1-C7 — scope hygiene note only.
5. Report terminology: "status stays `PLAN_PENDING`" — no such status exists; actual unchanged status is `PLAN_EXECUTABLE`.

---

## 16) Final report

```
C1-C7 REVIEW: COMPLETE
C1: PASS
C2: PASS
C3: PASS
C4: PASS
C5: PASS
C6: PASS
C7: PASS
H6: FAIL (claim-vs-code discrepancy; see section 6)
H7: PASS
H6 CLAIM-vs-CODE: DISCREPANCY
TT01 POPULATION IMPACT: IMPACT POSSIBLE
B25-03C-B DEPENDENCY: CONDITIONAL
C1-C7 SENIOR ACCEPTANCE: NOT YET AUTHORIZED
IMPLEMENTATION/COMMIT/PUSH: NOT AUTHORIZED
NEXT SENIOR DECISION: REVIEW C1-C7 INTEGRITY REPORT
STOP.
```