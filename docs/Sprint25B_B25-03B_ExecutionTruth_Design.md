# Sprint 25B — B25-03B Execution Result Truth (Design)

- Date: 2026-08-15
- Type: Assessment + Design ONLY. No implementation. No commit. No push.
- Scope: The minimum safe mechanism for capturing the truth returned by `OrderSend(...)` -> `MqlTradeResult`.
- Baseline: `docs/Sprint25B_B25-03_ExecutionTruth_Design.md` (prior 23-section design), `docs/Sprint25B_B25-03A_Identity_Status.md` (B25-03A delivered + committed `67c58d0`).
- Mandate: B25-03B senior directive. Deliverable = this document (20 mandated sections + final status block).

---

## 1. Executive Summary

The EA's single order-send site (`Trading/TradeManager.mqh:179`) treats the **requested** price and volume as if they were the **executed** (filled) values. When `OrderSend` returns true, `TradeExecutionResult.filledPrice` is set to `request.price` and `filledVolume` to `request.volume`, while the broker-confirmed fields of the returned `MqlTradeResult` (`price`, `volume`, `deal`, `request_id`, `retcode_external`, `comment`, `bid`/`ask`) are discarded. This mislabels intent as fact: a market order sent at the live Ask is reported as having filled at that Ask even when the broker fills at a better/worse price (slippage), and `DONE_PARTIAL` fills are reported as full requested volume.

B25-03B designs (a) the **MQL5 truth model** for this call, (b) an **immutable result record** capturing every field the broker returns, (c) an **outcome classifier** that derives the truth state from `retcode` + `deal` + `volume` (never from the boolean return value), and (d) the **surgical integration point** in `TradeManager.mqh` lines 178-207. The change is pure observability: no retry, no reconciliation, no deduplication, no settlement, no telemetry, no strategy/risk changes. Because order execution is gated to `ENTRY_MODE_LEGACY` (`Portfolio/SymbolContext.mqh:603`), capture is **dormant** in TT01 collection runs (NEW mode) — TT01 telemetry baselines are untouched.

Implementation of this design is NOT authorized in this phase; Section 20 requests it explicitly.

## 2. Current OrderSend Path

Single call site (verified by repository-wide grep for `OrderSend` — exactly one hit):

```
TradeManager.Update()                          Trading/TradeManager.mqh:111-209
  ├─ gate: m_executionEnabled                  :120   (set from ENTRY_MODE_LEGACY, SymbolContext.mqh:603)
  ├─ for each plan: GetPlan(i, plan)           :127-131
  ├─ skip if plan.status != PLAN_EXECUTABLE    :133
  ├─ skip if IsAlreadySubmitted(planId)        :140   (in-memory dedup, m_submittedIds[])
  ├─ ValidateAll(plan, m_lotSize, reason)      :147   (TradeValidation: trading allowed/volume/stops/margin)
  ├─ m_requestBuilder.Build(plan, m_lotSize, request) :163
  │     TRADE_ACTION_DEAL, symbol, volume=m_lotSize, deviation, magic, sl, tp
  │     BUY:  request.price = SymbolInfoDouble(symbol, SYMBOL_ASK)   TradeRequestBuilder.mqh:58
  │     SELL: request.price = SymbolInfoDouble(symbol, SYMBOL_BID)   TradeRequestBuilder.mqh:64
  │     comment = "SCX-BUY-P<id>" / "SCX-SELL-P<id>"                 :59 / :65  (legacy; no #seq tail)
  ├─ sent = OrderSend(request, tradeResult)    :179   <-- THE ONLY CALL SITE
  └─ result mapping                            :181-189 (see Section 3)
```

Plan origin: `CExecutionPlanner::BuildPlan` sets `plan.entryPrice` from structure-based `ResolveEntryPrice` (planned price) and `plan.entryDecisionId = candidateId`; `plan.status = PLAN_EXECUTABLE` at `ExecutionPlanner.mqh:317`. The request price is therefore the **live quote at build time**, which may differ from both the planned price and the eventual fill.

Consumers of `TradeExecutionResult`: only `TradeManager` itself — `LogOrderSent` (:254) and `LogOrderFailed` (:265) write journal lines, and `m_totalFilledPrice` (:193) feeds the "Avg Fill Price" shutdown summary (:225). The `#include "TradeExecutionResult.mqh"` in `Portfolio/SymbolContext.mqh:34` is unused. The result struct is **log-only**; no production logic depends on `filledPrice`/`filledVolume`.

## 3. Current Truth Defect

`Trading/TradeManager.mqh:178-189`:

```
MqlTradeResult tradeResult;
bool sent = OrderSend(request, tradeResult);      // :179

TradeExecutionResult result;
result.executionPlanId = planId;
result.submitted        = sent;
result.ticket           = (sent ? tradeResult.order : 0);     // :184  order ticket (ok), NOT deal ticket
result.retcode          = tradeResult.retcode;                // :185  captured
result.retcodeDescription = RetcodeToString(tradeResult.retcode); // :186
result.filledPrice      = (sent ? request.price : 0);         // :187  DEFECT: requested price labeled "filled"
result.filledVolume     = (sent ? request.volume : 0);        // :188  DEFECT: requested volume labeled "filled"
result.executionTime    = TimeCurrent();
```

Verified defects:
1. **D1 — Requested-as-filled (price).** `filledPrice` carries `request.price` (the Ask/Bid read at build time). The broker-confirmed deal price `tradeResult.price` is discarded. Slippage, requotes-at-fill, and market moves between build and fill are invisible.
2. **D2 — Requested-as-filled (volume).** `filledVolume` carries `request.volume` (fixed `m_lotSize`). A partial fill (`TRADE_RETCODE_DONE_PARTIAL`, `tradeResult.volume < request.volume`) is recorded as the full requested volume.
3. **D3 — Deal ticket discarded.** `tradeResult.deal` (the deal ticket, populated for `TRADE_ACTION_DEAL`) is never captured. The truth record cannot point at the deal history entry.
4. **D4 — Aggregator poisoned.** `m_totalFilledPrice += request.price` (:193) makes the shutdown "Avg Fill Price" an average of *requested* prices, not fills.
5. **D5 — Boolean treated as outcome.** `sent == true` is counted as success (:191-196) even when `tradeResult.retcode` is a non-success (e.g. `REQUOTE` 10004, `REJECT` 10006, `PRICE_CHANGED` 10020 — `OrderSend` may return true when the request was merely *accepted into the queue*; the outcome is only in `retcode`).
6. **D6 — Context fields dropped.** `request_id`, `retcode_external`, `comment`, `bid`, `ask` are never captured, so requote context and broker-side error details are lost.

Downstream (already truthful, unaffected by D1-D6): position discovery (`PositionLifecycleManager::AddContext` reads `POSITION_PRICE_OPEN` into `PositionContext.entryPrice`, `PositionLifecycleManager.mqh:223`) and settlement (`GetClosedProfit` sums `DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION` over `DEAL_ENTRY_OUT` deals of the position, :617-635). The live broker truth is already read at settlement; only the **immediate execution result** is mislabeled at send time.

## 4. MQL5 Result Semantics

Researched 2026-08-15 against official MQL5 Reference (`MqlTradeResult`, `OrderSend`, `MqlTradeRequest`, return-code reference; verified also against the official "Sending a trade request" book chapter).

`MqlTradeResult` fields (official):

| Field | Official meaning |
|---|---|
| `retcode` | Trade server return code. **The** outcome indicator. |
| `deal` | Deal ticket, **if a deal has been performed**. Populated for `TRADE_ACTION_DEAL`. |
| `order` | Order ticket, **if an order has been placed** (pending-style operations). |
| `volume` | **Deal volume, confirmed by broker** (depends on order filling type). |
| `price` | **Deal price, confirmed by broker** (depends on `deviation` and/or the operation). |
| `bid` / `ask` | Current market prices at result time (requote context). |
| `comment` | Broker comment (by default the description of the return code). |
| `request_id` | Request ID assigned by the terminal at dispatch (correlates with `OnTradeTransaction`). |
| `retcode_external` | Error code of an external trading system (broker-specific). |

`OrderSend(request, result)` return value: `true` = the request was **accepted / placed into the processing queue**; `false` = failure to dispatch (e.g., request validation, no connection). The boolean is NOT the outcome — `result.retcode` is. This is the canonical MQL5 contract and the direct basis for defect D5.

Retcode families relevant to a market `TRADE_ACTION_DEAL` path (values per official enumeration):

| retcode | Constant | Class |
|---|---|---|
| 10004 | `TRADE_RETCODE_REQUOTE` | REJECTED (requote) |
| 10006 | `TRADE_RETCODE_REJECT` | REJECTED |
| 10008 | `TRADE_RETCODE_PLACED` | ACCEPTED_NO_DEAL (pending semantics; not expected for DEAL action) |
| 10009 | `TRADE_RETCODE_DONE` | FILLED (full) |
| 10010 | `TRADE_RETCODE_DONE_PARTIAL` | FILLED (partial) |
| 10014-10021 | INVALID_VOLUME / INVALID_PRICE / INVALID_STOPS / TRADE_DISABLED / MARKET_CLOSED / NO_MONEY / PRICE_CHANGED / PRICE_OFF | REJECTED |
| 10024 | `TRADE_RETCODE_TOO_MANY_REQUESTS` | REJECTED (transient) |
| 10031 | `TRADE_RETCODE_CONNECTION` | CONNECTION_ERROR |
| 10012 | `TRADE_RETCODE_TIMEOUT` | UNKNOWN (deal may still appear later) |
| anything else | — | BROKER_ERROR / UNKNOWN (raw `retcode` + `retcode_external` preserved) |

For market orders with `TRADE_RETCODE_DONE`, `deal != 0` and `price`/`volume` are the broker-confirmed fill. `volume` may be `< request.volume` for `DONE_PARTIAL`. `price` may differ from `request.price` (slippage within `deviation`). `DONE` with `deal == 0` should not occur on normal brokers but is classified defensively as `ACCEPTED_UNKNOWN` (never fabricated as a fill).

## 5. Immutable Result Contract

A new, self-contained module `Trading/ExecutionTruth.mqh` (design; creation is part of the future authorized implementation):

```mql5
enum ExecutionOutcome
{
    EXEC_OUTCOME_UNKNOWN,          // no determination possible (timeout/unknown retcode)
    EXEC_OUTCOME_REJECTED,         // broker or pre-broker rejection (requote/reject/invalid/money/closed...)
    EXEC_OUTCOME_ACCEPTED_NO_DEAL, // accepted, no deal confirmed synchronously (PLACED / DONE with deal==0)
    EXEC_OUTCOME_FILLED,           // DONE, deal != 0 -> price/volume are broker-confirmed fills
    EXEC_OUTCOME_PARTIALLY_FILLED, // DONE_PARTIAL, deal != 0, volume < requested
    EXEC_OUTCOME_TIMEOUT,          // 10012 / dispatch timeout
    EXEC_OUTCOME_CONNECTION_ERROR, // 10031 / dispatch failure
    EXEC_OUTCOME_BROKER_ERROR      // retcode outside known table (retcode_external preserved)
};

struct ExecutionTruthRecord          // write-once by convention: captured, never mutated
{
    ulong    executionPlanId;        // plan.entryDecisionId (candidateId)
    uint     requestId;              // tradeResult.request_id (terminal-assigned correlation key)
    uint     retcode;                // tradeResult.retcode
    int      retcodeExternal;        // tradeResult.retcode_external (raw, broker-specific)
    ExecutionOutcome outcome;        // derived classification (Section 4 table)

    double   requestedPrice;         // request.price   (what we asked)
    double   requestedVolume;        // request.volume  (what we asked)
    double   filledPrice;            // tradeResult.price  (broker-confirmed) or 0 if no deal
    double   filledVolume;           // tradeResult.volume (broker-confirmed) or 0 if no deal
    ulong    dealTicket;             // tradeResult.deal  or 0
    ulong    orderTicket;            // tradeResult.order or 0
    double   bidAtResult;            // tradeResult.bid   (requote context)
    double   askAtResult;            // tradeResult.ask   (requote context)
    string   brokerComment;          // tradeResult.comment
    datetime capturedTime;           // TimeCurrent() at capture
};

// Pure, testable functions (no trade engine, no state):
ExecutionOutcome ClassifyOutcome(uint retcode, ulong dealTicket, double dealVolume,
                                 double requestedVolume);
ExecutionTruthRecord CaptureExecutionTruth(const MqlTradeRequest &req,
                                           const MqlTradeResult  &res,
                                           ulong executionPlanId);
```

Rules of the contract:
- **R1 (write-once).** A record is fully populated at capture; no field is ever modified after. "Immutable" = structural convention + no mutator API; no new lifecycle code.
- **R2 (broker-truth fields).** `filledPrice`/`filledVolume`/`dealTicket`/`orderTicket` come *only* from `MqlTradeResult`. They are never derived from `request`.
- **R3 (no fabrication).** If no deal is confirmed, filled fields are `0`; the outcome states it explicitly. Never fabricate a fill from the request.
- **R4 (nothing dropped).** Every `MqlTradeResult` field is represented in the record (bid/ask/comment/request_id/retcode_external included).
- **R5 (no policy).** The record observes and classifies. It does not retry, reconcile, deduplicate, or schedule.

## 6. Requested vs Accepted vs Executed

Three distinct facts, kept in separate fields:

| Layer | Meaning | Source |
|---|---|---|
| REQUESTED | What the EA asked for | `request.price` (live Ask/Bid at build), `request.volume` (`m_lotSize`) |
| ACCEPTED | Broker accepted the order (may or may not have filled) | `retcode` in {PLACED, DONE, DONE_PARTIAL}, `order != 0` |
| EXECUTED (FILLED) | Broker confirmed a deal at a price/volume | `retcode` == DONE/DONE_PARTIAL **and** `deal != 0`; `price`/`volume` broker-confirmed |

The current code collapses REQUESTED and EXECUTED into one field pair (`filledPrice`/`filledVolume` = request values). The contract separates them so slippage (`filledPrice != requestedPrice`) and partial fills (`filledVolume < requestedVolume`) are representable and measurable. The outcome classifier (`ClassifyOutcome`) is the only component that decides which layer is true, and it is driven exclusively by `retcode` + `deal` + `volume` (rule R2/I1).

## 7. Deal/Fill Truth

Two-tier truth, both originating from the broker:

1. **Synchronous tier (captured at send):** `tradeResult.deal` / `tradeResult.price` / `tradeResult.volume` — broker-confirmed deal ticket and fill values returned by `OrderSend`. Available immediately; captured by B25-03B.
2. **Durable tier (already implemented at settlement):** the deal history row `HistoryDealGetDouble(deal, DEAL_PRICE)`, `DEAL_VOLUME`, and the position row `POSITION_PRICE_OPEN`/`POSITION_VOLUME` (used at `PositionLifecycleManager.mqh:223`, `GetClosedProfit` :617-635). Survives restarts and matches the existing settlement path.

The two tiers reference the same deal ticket — no conflict resolution is needed. If `deal == 0` synchronously (defensive case), the durable tier remains authoritative at settlement, which is unchanged. B25-03B adds no reconciliation between tiers; reconciliation is explicitly out of scope (Section 13/14).

## 8. Partial-Fill Representation

`TRADE_RETCODE_DONE_PARTIAL` (10010) means the broker filled only part of the requested volume: `tradeResult.volume < request.volume`, `deal != 0`.

Representation in the record:
- `outcome = EXEC_OUTCOME_PARTIALLY_FILLED`
- `filledVolume = tradeResult.volume` (the actual filled amount)
- `requestedVolume = request.volume` (what was asked) — retained so the shortfall `requested - filled` is computable
- `filledPrice = tradeResult.price` (the actual fill price for the filled portion)

The position side already handles this truthfully: `PositionContext.lastVolume` is read from broker `POSITION_VOLUME` (`PositionLifecycleManager.mqh:227`), so downstream state reflects the real volume regardless of the request. No volume assertions exist between request and position volume anywhere in the codebase, so recording a smaller `filledVolume` cannot break downstream logic. (The prior B25-03 design's partial-fill correction, Section 23.1 of the baseline, is honored: partial fills are recorded per-request as one record whose filled fields carry the confirmed partial amounts; the un-filled remainder is never retried — retry is out of scope.)

## 9. Error/Unknown Semantics

| Situation | Outcome | Recorded |
|---|---|---|
| `retcode == DONE`, `deal != 0` | `EXEC_OUTCOME_FILLED` | all broker fields |
| `retcode == DONE_PARTIAL`, `deal != 0` | `EXEC_OUTCOME_PARTIALLY_FILLED` | filled volume/price from result |
| `retcode == DONE`, `deal == 0` (defensive) | `EXEC_OUTCOME_ACCEPTED_NO_DEAL` | order ticket, no fill fields |
| `retcode == PLACED` | `EXEC_OUTCOME_ACCEPTED_NO_DEAL` | order ticket (pending semantics; not expected on DEAL path) |
| `retcode` in {REQUOTE, REJECT, INVALID_*, TRADE_DISABLED, MARKET_CLOSED, NO_MONEY, PRICE_CHANGED, PRICE_OFF, TOO_MANY_REQUESTS, ...} | `EXEC_OUTCOME_REJECTED` | retcode + bid/ask (requote context) |
| `retcode == TIMEOUT` (10012) | `EXEC_OUTCOME_TIMEOUT` | nothing fabricated; a deal may still appear later (future reconciliation, out of scope) |
| `retcode == CONNECTION` (10031), or `OrderSend` returned false | `EXEC_OUTCOME_CONNECTION_ERROR` | retcode, zeroed tickets |
| retcode outside known table | `EXEC_OUTCOME_BROKER_ERROR` | raw retcode + `retcode_external` preserved |
| boolean false with `retcode == 0` | `EXEC_OUTCOME_UNKNOWN` | capturedTime only |

Two hard rules:
- **The boolean return of `OrderSend` never determines the outcome** (I1). A `REJECT` with `sent == true` must classify as REJECTED, exactly the case D5 gets wrong today.
- **Uncertainty is a first-class state.** Timeout/connection/unknown outcomes are recorded as such — no fabricated fill, no assumption of success, and no assumption of failure (a timeout may still have reached the broker). Later reconciliation (P0-02 of the baseline design) remains a future phase; B25-03B only captures the uncertainty honestly.

## 10. ExecutionIdentity Integration

B25-03A delivered `Trading/ExecutionIdentity.mqh` (committed `67c58d0`): `executionId = EX-<runId>-<seq>` with counter protocol (reserve-before-use, read-back verify, checksum), `BuildComment` (`SCX-<BUY|SELL>-P<decisionId>#<seq>`, <=31 chars), `ParseSeqFromComment`, states NOT_INITIALIZED/OK/COUNTER_CORRUPT/BLOCKED_WIDTH, and `SetMonotonicFloor` as the future ledger high-water hook.

B25-03B integration is **by reference only** — `ExecutionIdentity.mqh` is on the no-touch list and is NOT modified:
- The truth record's `executionPlanId` is the same decision id that `ExecutionIdentity` builds comments around.
- The send path today writes the legacy comment `"SCX-BUY-P<id>"` / `"SCX-SELL-P<id>"` (`TradeRequestBuilder.mqh:59/65`) — the `#<seq>` tail from `BuildComment` is **not yet wired into the send path**. Wiring it is a later phase (explicitly NOT B25-03B; it changes the position comment and thus the settlement parse surface).
- The record's `requestId` (`tradeResult.request_id`) is the terminal-side correlation key that will let a future phase connect the synchronous result to `OnTradeTransaction` confirmations without ever touching `ExecutionIdentity.mqh`.

## 11. Multiple-Deal Model

One `OrderSend` call produces exactly one synchronous `MqlTradeResult`, hence exactly one `ExecutionTruthRecord`. Over time one order may produce multiple deals (e.g., sequential partial fills), but on this EA's market-`DEAL` path with one-shot volumes, the synchronous result is the complete picture for the request.

- B25-03B captures the synchronous result only: **one request -> one record**.
- The durable tier (deal history by `deal`/`DEAL_POSITION_ID`; already used at settlement) is the multi-deal source of record.
- Appending additional deals discovered later (`TRADE_TRANSACTION_DEAL_ADD` events / `HistoryDealSelectByTicket`) to a record is a future phase (B25-03C+), designed but not built. The record's write-once rule makes it append-only-safe: new deals attach as new entries keyed by `dealTicket`, never by mutating existing fields.

**Architecture boundary — canonical in-memory truth, not a ledger.** B25-03B establishes the canonical in-memory execution-truth primitive. B25-03C will provide durable append-only execution persistence, event history, restart recovery, reconciliation and durable deduplication. B25-03B must not be interpreted as an execution ledger. Keeping the existing journal format unchanged is intentional — B25-03B adds no journal lines, no file persistence and no new output format; the `ExecutionTruthRecord` is the primitive that B25-03C will consume.

## 12. Test Matrix

Validation specification for the future implementation (unit level, in `Tests/unit/TestExecutionTruth.mqh`, TDD RED -> GREEN, mirroring the B25-03A harness pattern):

| # | Scenario | Inputs (retcode, deal, volume, sent) | Expected outcome | Expected record facts |
|---|---|---|---|---|
| T1 | Full market fill | DONE, deal=123, vol=0.10, sent=true | `FILLED` | filledPrice=res.price, filledVolume=0.10, dealTicket=123 |
| T2 | Partial fill | DONE_PARTIAL, deal=456, vol=0.04, sent=true (req 0.10) | `PARTIALLY_FILLED` | filledVolume=0.04 != requestedVolume=0.10, filledPrice=res.price |
| T3 | REJECT with sent=true | REJECT(10006), deal=0, sent=true | `REJECTED` | filled fields 0; **proves D5 fix** (boolean ignored) |
| T4 | Pre-broker rejection | INVALID_VOLUME(10014), sent=true | `REJECTED` | retcode preserved, no tickets |
| T5 | Requote | REQUOTE(10004), sent=true | `REJECTED` | bidAtResult/askAtResult preserved |
| T6 | No money | NO_MONEY(10019), sent=true | `REJECTED` | brokerComment preserved |
| T7 | Timeout | TIMEOUT(10012), sent=true | `TIMEOUT` | no fill fabricated, tickets 0 |
| T8 | Connection loss | CONNECTION(10031), sent=false | `CONNECTION_ERROR` | no fill fabricated |
| T9 | Placed, no deal | PLACED(10008), deal=0, sent=true | `ACCEPTED_NO_DEAL` | orderTicket preserved, filled fields 0 |
| T10 | Unknown retcode + external | 99999, retcode_external=-7 | `BROKER_ERROR` | retcode+retcodeExternal raw preserved |

Plus integration gates: (a) RED first — the classifier must fail on today's requested-as-filled mapping (regression anchor for D1/D2/D5); (b) determinism — same inputs, same records across runs; (c) dormant proof — LEGACY vs SHADOW mode runs: SHADOW (execution-disabled) emits zero records; LEGACY emits one record per send.

## 13. Research Boundary

This phase proves **EXECUTION OBSERVABILITY**, not **EXECUTION POLICY**:

| In scope (observability) | Out of scope (policy — future phases) |
|---|---|
| Capture every `MqlTradeResult` field | Retry policy / resubmission |
| Classify outcome (Section 4/9 table) | Reconciliation of unknown outcomes (baseline P0-02) |
| Log the truth (additive line) | Durable deduplication across restarts |
| Fix requested-as-filled labeling (D1-D5) | Restart recovery of in-flight orders |
| Keep aggregation honest ("Avg Fill Price") | Order state machine / lifecycle beyond one record |
| Preserve bid/ask/comment/external context | OnTradeTransaction handling |
| — | Settlement, telemetry, strategy, risk changes |

The boundary is enforced structurally: the new module is a pure function of `(MqlTradeRequest, MqlTradeResult, planId)` with no trade engine, no timers, no files, and no callback hooks.

## 14. TT01 Impact

- **Capture is dormant in TT01 collection runs.** Execution is gated to `ENTRY_MODE_LEGACY` only (`SymbolContext.mqh:603`); TT01 collection uses NEW (shadow) mode, so `TradeManager.Update` returns at the gate (`TradeManager.mqh:120`) and `OrderSend` is never reached. Zero capture records, zero new journal lines in TT01 runs.
- **Telemetry schema/CSV: untouched.** The telemetry `entryPrice` column is explicitly simulated (settled from `ForwardOutcomeSimulator` at `SymbolContext.mqh:1492`); B25-03B does not change telemetry semantics.
- **Journal format: unchanged.** Existing `ORDER-SENT`/`ORDER-FAILED` line formats stay byte-identical; only the *values* reported become broker truth in LEGACY runs. TT01 baselines (telemetry_v4/v5 CSV, gates.jsonl) and the frozen evidence hashes (TT01 baseline manifest `82924B28...`, ED01 control `2E3941EA...`, `TestRunnerEA.ex5.bak20260812_194614` = `BB6392F4...`) are unaffected.
- **Settlement: untouched.** `PositionLifecycleManager` / `ActualOutcomeSettler` already read broker truth; B25-03B does not change them.

## 15. Proposed File Changes

For the FUTURE implementation only. Nothing is modified in this phase.

**New files (SAFE INFRASTRUCTURE):**
1. `Trading/ExecutionTruth.mqh` — outcome enum, truth record struct, `ClassifyOutcome` + `CaptureExecutionTruth` (pure, no state). Includes only `Utils/Constants.mqh` style headers; no trade-engine dependencies.
2. `Tests/unit/TestExecutionTruth.mqh` — TDD suite covering matrix T1-T10 + regression anchors for D1/D2/D5.

**Modified files (minimal; REQUIRES SENIOR AUTHORIZATION — currently on the no-touch list):**
3. `Trading/TradeManager.mqh` — **only** lines 178-207 (the OrderSend block): after `OrderSend`, call `CaptureExecutionTruth`; classify outcome; populate `result.filledPrice/filledVolume` from broker-confirmed values when the outcome is FILLED/PARTIALLY_FILLED (never from `request`); keep journal line formats identical; replace `m_totalFilledPrice += request.price` with accumulation of confirmed fills. Diff = ~15 lines, provable via `git diff --stat`.

**Explicitly NOT modified (zero-touch):** `ExecutionIdentity.mqh`, `TradeExecutionResult.mqh` (struct unchanged; TradeManager fills it with truthful values), `TradeRequestBuilder.mqh` (comment format stays legacy — `#seq` wiring is a later phase), `TradeValidation.mqh`, `PositionLifecycleManager.mqh`, `ActualOutcomeSettler.mqh`, `TelemetryCollector.mqh`/`TelemetryRowBuilder.mqh`, `SymbolContext.mqh`, `ExecutionPlanner.mqh`, `Core/Config.mqh`, `SuperCents_X.mq5`, TT01/ED01 tooling and baselines.

## 16. Invariants

- **I1 — Outcome by broker signals, never by boolean.** `ClassifyOutcome` is a pure function of `(retcode, deal, volume, requestedVolume)`. The `OrderSend` return value never influences the outcome.
- **I2 — Fill fields are broker-confirmed or zero.** `filledPrice`/`filledVolume` equal `request.price`/`request.volume` only if the broker-confirmed values happen to equal them. Never assigned from the request.
- **I3 — Write-once records.** A record's fields are set at capture and never mutated; no mutator API.
- **I4 — One record per send.** There is exactly one `OrderSend` call site; capture is co-located and unconditional (covers success and failure paths).
- **I5 — No new send paths.** The implementation adds no `OrderSend` calls, no retries, no resubmission.
- **I6 — Journal format preserved.** Existing log-line templates unchanged; TT01 runs emit no new lines (dormant gate).
- **I7 — No dropped broker fields.** `deal`, `order`, `price`, `volume`, `bid`, `ask`, `comment`, `request_id`, `retcode_external`, `retcode` all represented in the record.
- **I8 — Dormant capture in shadow modes.** With execution disabled (NEW/SHADOW), zero records are produced; telemetry CSV output is byte-identical.

## 17. Risks

| # | Risk | Mitigation |
|---|---|---|
| R1 | Modifying `TradeManager.mqh` (no-touch list) | Surgical 15-line diff reviewed by senior via Section 20 authorization; TDD regression anchors; `git diff` proof. |
| R2 | Broker returns DONE with `deal==0` or `price==0` in exotic modes | Classifier maps to `ACCEPTED_NO_DEAL`; durable tier (deal history) remains authoritative at settlement — no fabrication. |
| R3 | Fill price differs from request (slippage) surprises log readers | Expected and documented; journal values now truthful; no code asserts price equality anywhere. |
| R4 | Dormant-gate regression (execution enabled accidentally in collection runs) | Existing gate `SymbolContext.mqh:603` unchanged; LEGACY-only check is pre-existing, not new. |
| R5 | Log noise: one extra line per order in LEGACY runs | Bounded (1 per send); additive; harmless. |
| R6 | `#seq` comment tail still absent at send | Documented as a later phase; B25-03A identity logic unaffected; settlement parse (legacy `SCX-*-P<id>`) unchanged. |
| R7 | Timeout leaves uncertainty (deal may appear later) | Recorded as `TIMEOUT` honestly; reconciliation is a future phase — B25-03B never guesses. |
| R8 | Compile warning baseline drift | Gate: compile must stay at the current 8-warning baseline (benign); no new warnings. |

## 18. Validation Strategy

1. **TDD RED**: `TestExecutionTruth` written first; the classifier/capture must fail against the current requested-as-filled behavior (anchors D1/D2/D5).
2. **TDD GREEN**: implement `ExecutionTruth.mqh` until T1-T10 pass; determinism check (same inputs -> identical records).
3. **Surgical integration**: apply the authorized `TradeManager.mqh` diff; full suite still GREEN; compile at 8-warning baseline; no new warnings.
4. **Dormancy proof**: strategy-tester pass in SHADOW mode — grep journal for zero `ORDER-SENT` lines and unchanged telemetry CSV hash; LEGACY mode pass — journal shows truthful fills (fill != request when slippage occurs).
5. **Evidence**: run artifacts + journal + `git diff --stat` reviewed before any commit authorization (mirroring the B25-03A evidence protocol).
6. **No TT01/ED01 baseline re-run** (dormant capture; CSVs untouched) unless senior explicitly requests a re-run.

## 19. Implementation Sequence

Ordered sub-phases (each gated; only after Section 20 authorization):

1. **P1 — RED**: `Tests/unit/TestExecutionTruth.mqh` (matrix T1-T10 + D1/D2/D5 anchors). Must fail. Evidence: RED run.
2. **P2 — GREEN**: `Trading/ExecutionTruth.mqh` (enum + struct + pure classifier/capture). Suite GREEN; determinism PASS. Evidence: GREEN run x2.
3. **P3 — Integration (authorized diff)**: `TradeManager.mqh:178-207` only — capture, classify, truth-populate, honest aggregation. Journal formats byte-identical. Evidence: full suite GREEN, compile at 8-warning baseline, `git diff --stat`.
4. **P4 — Dormancy proof**: SHADOW run (zero records, CSV hash unchanged) vs LEGACY run (truthful records). Evidence: journal extracts.
5. **P5 — Report + STOP**: status report; commit/push only on explicit senior authorization (B25-03A protocol: "feat: implement Sprint 25B B25-03B execution result truth").

Not scheduled here: comment `#seq` wiring, deal-append/OnTradeTransaction, reconciliation, dedup, restart recovery (B25-03C+ phases).

## 20. Explicit Authorization Request

This design requests senior authorization for a **follow-up implementation phase (B25-03C)** with the following exact scope:

1. **Create** `Trading/ExecutionTruth.mqh` and `Tests/unit/TestExecutionTruth.mqh` (SAFE INFRASTRUCTURE).
2. **Modify** `Trading/TradeManager.mqh` lines 178-207 only (the `OrderSend` result block), per Section 15 — including removal of the requested-as-filled labeling (D1/D2), deal-ticket capture (D3), honest fill aggregation (D4), and boolean-independent classification (D5).
3. **Not authorized / explicitly excluded:** retry policy, reconciliation, durable deduplication, restart recovery, `OnTradeTransaction` handling, settlement changes, telemetry changes, strategy or risk changes, TT01/ED01 changes, `ExecutionIdentity.mqh` changes, comment-format changes, and any file other than the three listed above.
4. **Gate:** implementation proceeds TDD RED -> GREEN with evidence, then stops for separate commit/push authorization.

If any stop-condition dependency surfaces during implementation (strategy, retry policy, risk, settlement, telemetry semantics, TT01 baseline, historical evidence, or automatic reconciliation), implementation halts and this dependency is reported to senior.

---

## Final Status Block

```
B25-03B DESIGN: COMPLETE
IMPLEMENTATION: NOT AUTHORIZED
COMMIT: NOT AUTHORIZED
PUSH: NOT AUTHORIZED
NEXT SENIOR DECISION: B25-03B implementation authorization OR further design correction
STOP.
```
