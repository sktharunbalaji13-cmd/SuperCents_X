# Sprint 25B - B25-03B Execution Result Truth - Implementation Status

**Date:** 2026-08-15
**Scope:** Authorized implementation of `Trading/ExecutionTruth.mqh`, `Tests/unit/TestExecutionTruth.mqh`, and surgical integration in `Trading/TradeManager.mqh`.
**Preconditions verified:** HEAD = `67c58d0803308e4936f61aeca57b4f78d8d4b8cd` (B25-03A push), origin/main in sync, ExecutionIdentity.mqh untouched (FROZEN).
**Toolchain:** MetaEditor 5.0.0.6104 / Terminal 5.0.0.6104, EURUSD H1, 2026.01.01-2026.01.02, Model=4, Deposit=10000 GBP, Leverage=200.

---

## 1. P1 - TDD RED (ExecutionTruth.mqh = defect mirror)

The RED scaffold mirrors the CURRENT `TradeManager` truth model (OrderSend-boolean-as-success D5, requested-price-as-filled D1, requested-volume-as-filled D2, deal ticket dropped D3, request_id/retcode_external/bid/ask/comment dropped D6). The test suite was run UNCHANGED against it.

| Metric | Result |
|---|---|
| ExecutionTruth suite | **21/62 passed, 41 failed** |
| Defect anchor assertions present | **11/11** (T1c, T1d, T1f, T1h, T1i, T1j, T1k, T2b, T2d, T3b, T10c) |
| Compile | 0 errors, 0 warnings |
| Run | 2026-08-15 14:33:24, 12 s |
| Artifacts | `Tools/25B/execsim/artifacts/EXSIM_B_20260815143324_Red1/` |

RED demonstrates the expected defect (predicted 41 failures; all defect classes D1/D2/D3/D5/D6 pinned). All other gates PASS (frozen evidence, scope, HEAD).

## 2. P2 - TDD GREEN (truthful module)

`ExecutionTruth.mqh` bodies replaced with the truthful implementation; API (enum, struct, signatures) byte-identical to RED phase; test file never modified.

### GREEN #1

| Metric | Result |
|---|---|
| ExecutionTruth suite | **62/62 passed, 0 failed** |
| GRAND TOTAL | 62/62 passed, 0 failed |
| Compile | 0 errors, 0 warnings |
| Run | 2026-08-15 14:34:36, 12 s |
| Artifacts | `Tools/25B/execsim/artifacts/EXSIM_B_20260815143436_Green1/` |

### GREEN #2 (determinism)

| Metric | Result |
|---|---|
| ExecutionTruth suite | **62/62 passed, 0 failed** |
| GRAND TOTAL | 62/62 passed, 0 failed |
| Determinism | **PASS** - normalized journal identical across runs (12 lines, run-to-run; only the `__DATETIME__` BUILD banner differs, excluded) |
| Run | 2026-08-15 14:37:42, 12 s |
| Artifacts | `Tools/25B/execsim/artifacts/EXSIM_B_20260815143742_Green2/` |

## 3. P3 - Production integration (TradeManager.mqh)

Surgical edit of the OrderSend result block only. Exact diff: `Tools/25B/execsim/artifacts/production_diff_b03b.patch` (16 insertions, 8 deletions; the ONLY tracked change).

- Added `#include "ExecutionTruth.mqh"` (after TradeExecutionResult include).
- `CaptureExecutionTruth(request, tradeResult, planId)` captures the broker-confirmed truth once, immediately after OrderSend.
- `result.ticket` now = broker-confirmed `tradeResult.order` (unchanged semantics for the success path; truth record always carries it).
- `filledPrice`/`filledVolume` come ONLY from `MqlTradeResult` (broker-confirmed) when the outcome is FILLED/PARTIALLY_FILLED; 0 otherwise. The request is NEVER the source of a fill.
- Tally/log semantics: FILLED/PARTIALLY_FILLED -> `m_totalFilledPrice += truth.filledPrice`, `m_totalSucceeded++`, LogOrderSent; ACCEPTED_NO_DEAL -> LogOrderSent ("Order accepted, no deal confirmed"), neither tally; else -> LogOrderFailed + `m_totalFailed++` ("OrderSend failed: retcode=%u %s").
- Journal line formats unchanged (same LogOrderSent/LogOrderFailed strings, `RetcodeToString` untouched).
- NOT touched: request action/volume/price/deviation/SL/TP/magic/comment/entry policy/validation gates, `RecordSubmitted(planId)`, `m_totalSubmitted++`, ExecutionPlanner, SymbolContext, RiskManager, telemetry, ExecutionIdentity.
- Line positions: execution gate `if(!m_executionEnabled) return;` at TradeManager.mqh:121; OrderSend at :180; truth capture at :182.

## 4. Validation

| Check | Result |
|---|---|
| Production compile (SuperCents_X.mq5) | 0 errors, **4 warnings - all pre-existing** (`POSITION_COMMISSION` deprecated in Entry/PositionInfo.mqh:46, Entry/PositionManager.mqh:121/149/177); no new warnings |
| Full suite compile (TestRunnerEA.mq5, unchanged source) | 0 errors, **8 warnings - matches documented baseline** |
| Full suite run (TestRunnerEA, unchanged) | **GRAND TOTAL: 2917/2917 passed, 0 failed** |
| Frozen evidence | PASS - 4 hashes unchanged: TestRunnerEA.ex5.bak20260812_194614 (BB6392F4...), telemetry_v4_20260130.csv (B5AB5FEE...), baseline.manifest.json (82924B28...), ED01 CONTROL telemetry_v5_20260421.csv (2E3941EA...); `Tools/TT01/run/gates.jsonl` intact (17 lines) |
| Dormancy - static | Gate at TradeManager.mqh:121 returns before the OrderSend block (:180) in NEW/SHADOW mode; P3 code unreachable |
| Dormancy - runtime | SuperCents_X EntryMode=2 (NEW) full run: **0 ORDER-SENT / 0 ORDER-FAILED lines** in journal |
| Scope | `git diff` = ONLY `Trading/TradeManager.mqh`; new files = exactly `Trading/ExecutionTruth.mqh` + `Tests/unit/TestExecutionTruth.mqh`; temporary runner `Tests/TestExecutionTruthEA.mq5` and dormancy profile deleted after use |

## 5. Files changed / untouched

**Changed (3, authorized):**
- `Trading/ExecutionTruth.mqh` (NEW) - pure capture/classification module (rules I1-I8: outcome from broker result semantics, never the OrderSend boolean; filled fields only from `MqlTradeResult`; no fabricated fill when deal==0; requested vs confirmed separated; all fields preserved; no retry/reconciliation/ledger/timers/file I/O/callbacks/OrderSend).
- `Tests/unit/TestExecutionTruth.mqh` (NEW) - T1-T13, 62 assertions: full fill, partial fill, REJECT+sent=true (D5 anchor), invalid volume, requote, no money, timeout, connection, placed/no-deal, unknown retcode + retcode_external, explicit requested-vs-filled price/volume differences, deal/order tickets, request_id, bid/ask, comment, no-fabricated-fill-when-deal==0.
- `Trading/TradeManager.mqh` (MODIFIED) - P3 block only (+include).

**Explicitly untouched:** ExecutionIdentity.mqh (FROZEN), TradeRequestBuilder.mqh, SymbolContext.mqh, PositionLifecycleManager.mqh, ActualOutcomeSettler.mqh, Telemetry (TT01/ED01 baselines, telemetry writers), ExecutionPlanner.mqh, RiskManager, TestSuite.mqh, TestRunnerEA.mq5, execsim harness, .gitignore.

## 6. Known limitations (documented, unchanged by design)

- TIMEOUT remains an uncertain outcome (neither fill nor rejection).
- CONNECTION failure is neither fill nor rejection (outcome unknown).
- No retry, no reconciliation, no deduplication, no durable execution ledger, no restart recovery - explicitly out of scope (B25-03C).
- ACCEPTED_NO_DEAL orders are logged as sent but counted in neither success nor failure tally; `m_totalFilledPrice` now sums broker-confirmed fill prices only (never requested prices).
- Note: the B25-03B design document originally annotated `TRADE_RETCODE_TIMEOUT` as 10037; per senior review CORRECTION 1 (2026-08-15) all B25-03B design/status references now state the verified official MQL5 value **10012**. Implementation uses named constants, so behavior is unaffected.

## 7. Architecture boundary (senior review CORRECTION 2)

**B25-03B establishes the canonical in-memory execution-truth primitive. B25-03C will provide durable append-only execution persistence, event history, restart recovery, reconciliation and durable deduplication. B25-03B must not be interpreted as an execution ledger.**

Keeping the existing journal format unchanged is intentional: B25-03B adds no journal lines, no file persistence and no new output format. The `ExecutionTruthRecord` is the primitive that B25-03C will consume.

## 8. B25-03C confirmation

Execution ledger, durable persistence, event history, restart recovery, reconciliation and durable deduplication are **NOT implemented** in this change. They remain a future, separately-authorized phase.

---

```
B25-03B: IMPLEMENTATION COMPLETE
VALIDATION: PASS
COMMIT: NOT AUTHORIZED
PUSH: NOT AUTHORIZED
B25-03C: NOT AUTHORIZED
NEXT SENIOR DECISION: REVIEW B25-03B EVIDENCE
STOP.
```
