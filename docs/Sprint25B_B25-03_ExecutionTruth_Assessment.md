# Sprint 25B — B25-03 Execution Truth & Decision→Fill Linkage Assessment

| | |
|---|---|
| Status | **ASSESSMENT COMPLETE / IMPLEMENTATION NOT AUTHORIZED** |
| Date | 2026-08-15 |
| Repo HEAD | `3c2f02a200da1eaf57e5b689068782997d9dbc0c` (B25-01 + B25-02, pushed) |
| Parent | `1e6aa5f` (Sprint 25A CLOSED) |
| Method | Read-only source audit. No file modified, nothing staged/committed. |
| Scope | Decision → execution intent → order → deal/fill → position → settlement |

---

## 1. Executive Summary

The EA has **two** execution pipelines:

1. **LEGACY** (`EntryMode=0`, default production mode): `CTradeManager::Update` is the **only** code path that ever calls `OrderSend()` in the current wiring (`Trading/TradeManager.mqh:179`). It is disabled in every TT01/harness run (`Tools/TT01/TT01_Validate.ps1:327` sets `EntryMode=2`; `Portfolio/SymbolContext.mqh:603` enables execution only in LEGACY mode). **No order has ever been sent in any validated harness run.**
2. **NEW/SHADOW** (`EntryMode=1/2`): `CExecutionManager::ExecuteMarket` (`Entry/ExecutionManager.mqh:152`) contains a second, richer OrderSend path (captures `ResultOrder()`/`ResultDeal()`), but **nothing calls `Execute()`** — it is dead code in the current wiring. The NEW pipeline is shadow-only (`Entry/EntryOrchestrator.mqh` shadow comparisons).

The core finding is that **execution truth does not exist today**: the `MqlTradeResult` fields that establish fill truth (`price`, `volume`, `deal`) are read and discarded in the LEGACY path (`Trading/TradeManager.mqh:181-189`); the only broker-visible decision identity is the candidate id embedded in the order comment (`SCX-*-P<id>`, `Trading/TradeRequestBuilder.mqh:59,65`), and that id is a **session-scoped counter that resets on every restart** (`Confluence/TradeCandidateBuilder.mqh:20,67,435`). The telemetry decisionId is a **second, independent id space** (`Telemetry/TelemetryCollector.mqh:308`) linked to the candidate id only through an in-memory map (`Telemetry/ActualOutcomeSettler.mqh:45-96`) that dies with the process.

There is therefore **no canonical trade-decision identity** that survives restart, links to a broker order and deal, and links back to a telemetry row. This is the single architectural gap that B25-03 must close before execution truth can be established.

Minimum architecture to establish trustworthy execution truth (assessment; NOT implemented):

- A **durable canonical decision identity** (run-scoped, `runId`-prefixed) that travels in the order comment and is recorded in the telemetry row.
- **Full capture** of `MqlTradeResult` (requested price, broker-confirmed fill price/volume, order ticket, deal ticket, retcode) into a **separate durable execution ledger** — leaving the frozen telemetry schema v6 and TT01 untouched.
- A **restart-safe dedup/idempotency key** (replacing the in-memory `m_submittedIds[]`, `Trading/TradeManager.mqh:28-29,236-252`).
- Optionally later: `OnTradeTransaction()` as **execution-observability infrastructure** (event notification only; broker history remains the source of truth).

No strategy-sensitive decision is required to enable execution truth. Adding execution observability changes **no entry logic, no order policy, no risk behavior, no settlement semantics, and no telemetry schema**.

---

## 2. Current Execution Architecture

Trace of the actual production path (LEGACY mode; all references verified against HEAD `3c2f02a`):

```
OnTick → CEngine::Update (SuperCents_X.mq5:134; Core/Engine.mqh:190, bar-gated)
  → CPortfolioManager::Update → CSymbolContext::Update (Portfolio/SymbolContext.mqh:737)
    1. structure detectors (swing/BOS/CHOCH/OB/FVG/liquidity/trend)          :761-877
    2. CConfluenceEngine::Update                                             :890
       - CTradeCandidateBuilder: TradeCandidate.id = m_nextId++ (in-memory)  Confluence/ConfluenceEngine.mqh:422
         Confluence/TradeCandidateBuilder.mqh:175,231 (m_nextId=1 at :67, reset :435)
       - CEntryDecisionEngine: EntryDecision.candidateId = candidate.id      Entry/EntryDecisionEngine.mqh:186
       - CExecutionPlanner: ExecutionPlan.entryDecisionId = candidate.id     Entry/ExecutionPlanner.mqh:214
         plan status: PLAN_CREATED/EXECUTABLE/REJECTED                        Entry/ExecutionPlanTypes.mqh:6-12
    3. telemetry decision gate + row build + QueueForSettlement              SymbolContext.mqh:902-1043
    4. portfolio risk gate: PLAN_EXECUTABLE → PLAN_REJECTED_PORTFOLIO        SymbolContext.mqh:1049-1070
    5. CTradeManager::Update (the ONLY OrderSend path)                       SymbolContext.mqh:1072-1078
    6. CPositionLifecycleManager::Update                                     SymbolContext.mqh:1080-1086

CTradeManager::Update (Trading/TradeManager.mqh:111-209)
  - plan.status != PLAN_EXECUTABLE → skip                                      :133
  - planId = plan.entryDecisionId                                              :136
  - IsAlreadySubmitted(planId) → duplicate skip (in-memory only)               :140-144,236-252
  - CTradeValidation::ValidateAll (terminal/symbol/volume/stops/margin)        :147, TradeValidation.mqh:128-143
  - CTradeRequestBuilder::Build (market, ASK/BID, comment SCX-*-P<id>, magic)  :163, TradeRequestBuilder.mqh:43-73
  - OrderSend(request, tradeResult)                                            :179
  - result capture → TradeExecutionResult (requested price/volume only)        :181-189
  - RecordSubmitted(planId) — id blocked regardless of outcome                 :206

Position / settlement side (CPositionLifecycleManager, Entry/PositionLifecycleManager.mqh)
  - DiscoverPositions: PositionsTotal() filtered by magic + symbol             :272-315
  - AddContext: ticket + parsed comment "P<id>" → entryDecisionId             :209-242, ParseEntryDecisionId :597-609
  - in-memory state machine DISCOVERED→OPEN→BREAK_EVEN/TRAILING/PARTIAL→CLOSED :377-441
  - close detection: position gone → EVENT_POSITION_CLOSED (EventData,
    Monitoring/MonitoringTypes.mqh:143-180) with entryDecisionId + net P/L     :321-367
    (GetClosedProfit from HistoryDealGet, PositionLifecycleManager.mqh:617-638)
  - consumers: CActualOutcomeSettler (Telemetry/ActualOutcomeSettler.mqh:100-130)
               CStatisticsReporter (Monitoring/StatisticsReporter.mqh:72, 34-61)

Telemetry side
  - row built by CTelemetryRowBuilder::Build / BuildWithEvidence             Telemetry/TelemetryRowBuilder.mqh:65,131
    (NO candidateId/decisionId/order/deal fields in the row)
  - collector assigns decisionId = ++m_runId (run-local, resets per Init)     Telemetry/TelemetryCollector.mqh:307-308
  - B25-01 provenance stamped per row: runId/buildTag/gitHead                TelemetryCollector.mqh:310-313
  - buffer 1024 rows, B25-02 checkpoint flush every 64 rows                   TelemetryCollector.mqh:40,43,329-333
  - simulated forward outcome settlement (FixedRR 2.0R, 50-bar hold)          SymbolContext.mqh:1497-1554;
    Telemetry/ForwardOutcomeSimulator.mqh
  - actual outcome stamp only while row still buffered (GR02A boundary)      TelemetryCollector.mqh:344-361
```

### Ownership of each state

| State / identity | Owned by | Durable? |
|---|---|---|
| TradeCandidate.id | `CTradeCandidateBuilder` (in-memory) | No — resets to 1 per run |
| EntryDecision.candidateId | `CEntryDecisionEngine` (in-memory) | No |
| ExecutionPlan.entryDecisionId | `CExecutionPlanner` (in-memory array) | No |
| plan status | `CExecutionPlanner::m_plans[]` | No |
| submitted-set | `CTradeManager::m_submittedIds[]` | No |
| order ticket | `TradeExecutionResult.ticket` (struct, only logged) | No |
| deal ticket | never captured in LEGACY path | — |
| PositionContext | `CPositionLifecycleManager::m_contexts[]` | Rebuilt from broker on restart (comment id only) |
| telemetry decisionId | `CTelemetryCollector` (in-memory counter) | No — but persists in the CSV row |
| candidateId→decisionId map | `CActualOutcomeSettler` (in-memory) | No |
| telemetry row (identity+gate+simulated outcome) | CSV file (checkpoint + shutdown flush) | Yes |
| broker order/deal/position | broker server + terminal history | Yes (HistoryOrder*/HistoryDeal*/Positions*) |

### Where identities are lost

- candidateId → not in telemetry row (only in order comment; rows have no candidate column).
- order ticket → only in a log line (`ORDER-SENT`, TradeManager.mqh:254-263).
- deal ticket → never read (`tradeResult.deal` is not referenced anywhere in the LEGACY path).
- actual fill price/volume → never read (`tradeResult.price`, `tradeResult.volume` unused).
- decision↔position link → survives restart **only** through the comment; the richer linkage (candidateId, telemetry decisionId, runId) does not.

### What survives

| Event | Survives |
|---|---|
| restart (clean) | broker positions (comment → entryDecisionId), telemetry CSVs (runId/buildTag/gitHead, decisionIds), broker history |
| crash | broker positions, broker history; telemetry CSV up to last checkpoint flush (≤64 rows lost) |
| broker reconciliation | positions, orders, deals — but only net P/L aggregation is ever read (GetClosedProfit) |

---

## 3. Decision Identity Audit

Every representation of the same logical trade decision, in order of creation:

| # | Representation | Where created | Value | Survives restart? |
|---|---|---|---|---|
| 1 | `TradeCandidate.id` | TradeCandidateBuilder.mqh:175 | `int`, session counter `m_nextId++` | No (resets) |
| 2 | `EntryDecision.candidateId` | EntryDecisionEngine.mqh:186 | = (1) | No |
| 3 | `ExecutionPlan.entryDecisionId` | ExecutionPlanner.mqh:214 | = (1) | No |
| 4 | `TradeExecutionResult.executionPlanId` | TradeManager.mqh:150,182 | = (1) | No |
| 5 | broker order comment `SCX-BUY-P<id>` / `SCX-SELL-P<id>` | TradeRequestBuilder.mqh:59,65 | = (1) | Partial — id reused after restart (collision) |
| 6 | `PositionContext.entryDecisionId` (parsed from comment) | PositionLifecycleManager.mqh:236-238 | = (1) | Yes (but ambiguous: no run disambiguation) |
| 7 | `PositionContext.candidateId` / `executionPlanId` | PositionLifecycleManager.mqh:219-220 | always 0 | No (never populated) |
| 8 | telemetry `decisionId` | TelemetryCollector.mqh:308 | `int`, run-local counter, separate id space | No (resets); value persists in CSV row |
| 9 | B25-01 `runId` | TelemetryCollector.mqh:277 | `RUN-<buildTag>-<tick>`, per EA process | Persists in CSV row; not in comment/order |

There is **no canonical decision identity**. Two independent id spaces (candidate counter vs telemetry decisionId counter) are bridged only by `CActualOutcomeSettler::Register/LookupDecisionId` (in-memory, `Telemetry/ActualOutcomeSettler.mqh:45-96`).

### Explicit answers (Phase 2 questions)

1. **Authoritative decision ID?** None. De-facto it is `candidate.id`, but it is session-scoped and duplicated by the telemetry counter.
2. **Survive restart?** No. Both counters reset; the comment `P<id>` becomes ambiguous (a new run's candidate #12 is indistinguishable from an old run's candidate #12).
3. **Linkable to a broker order?** Partially. The comment carries `P<id>`; the order ticket is captured in `TradeExecutionResult.ticket` but only logged, and the order object itself is never queried (no `HistoryOrderGet` anywhere).
4. **Linkable to a deal?** No. `MqlTradeResult.deal` is never read in the LEGACY path; no deal-ticket column exists.
5. **Linkable to a final outcome?** Partially, and only in-session: `EVENT_POSITION_CLOSED` carries `entryDecisionId` (from comment) and the settler stamps `actualOutcome` on the still-buffered telemetry row. After a flush or restart the linkage is gone (documented GR02A boundary, TelemetryCollector.mqh:341-343).
6. **Link back to the telemetry row?** Only through the in-memory settler map. The CSV row itself contains no candidateId, order ticket, or deal ticket, so an offline analysis cannot join decision → order → deal → outcome.

---

## 4. Order / Deal / Fill Audit

### What the LEGACY path records (`Trading/TradeManager.mqh:181-189`)

| MqlTradeRequest/Result item | Recorded as | Location |
|---|---|---|
| request (action/symbol/volume/type/price/sl/tp/deviation/magic/comment) | built, sent | TradeRequestBuilder.mqh:43-73 |
| request.price (requested) | `result.filledPrice` | TradeManager.mqh:187 |
| request.volume (requested) | `result.filledVolume` | TradeManager.mqh:188 |
| `tradeResult.retcode` | `result.retcode` + mapped string | TradeManager.mqh:185-186, 274-311 |
| `tradeResult.order` (order ticket) | `result.ticket` (only when `sent==true`) | TradeManager.mqh:184 |
| `tradeResult.price` (**actual fill price**) | **DISCARDED** | — |
| `tradeResult.volume` (**actual filled volume**) | **DISCARDED** | — |
| `tradeResult.deal` (**deal ticket**) | **DISCARDED** | — |
| `tradeResult.bid` / `ask` (requote prices) | **DISCARDED** | — |
| `tradeResult.comment`, `request_id`, `retcode_external` | **DISCARDED** | — |
| OrderCheck result | not used | — |
| type_filling | not set (broker default) | TradeRequestBuilder.mqh:47-53 |

### Requested ≠ actual fill price

**Not preserved.** `TradeManager.mqh:187` stores `request.price` into `filledPrice` — the price the EA *asked for* (current ASK/BID with `deviation` slippage allowance), not the price the broker *confirmed*. The broker-confirmed price arrives in `tradeResult.price` (per MQL5 docs: "Deal price, confirmed by broker... depends on the deviation field"). Every order that slips by even one point records a fill price that is factually wrong, and no research artifact can later correct it — the truth is never persisted anywhere.

### Where the broker result is discarded

- The `MqlTradeResult` struct is local to `Update()` (TradeManager.mqh:178) and its non-retcode fields die with the function.
- No execution record is written to any file (the only file I/O in Trading/Entry/Telemetry is the telemetry CSV — `TelemetryCollector.mqh:79,172,182` and `CalibrationDataset.mqh:291`).
- No `HistoryOrderGet`/`HistoryDealGet` verification of the result is performed. Deal history is read only (a) at close for net P/L (`PositionLifecycleManager.mqh:617-638`) and (b) by `CStatisticsReporter` for exit stats (`Monitoring/StatisticsReporter.mqh:34-61`).
- Rejections/timeouts: logged via `LogOrderFailed` (TradeManager.mqh:265-272), then `RecordSubmitted(planId)` blocks the id — **no retry, no reconciliation**. A `TRADE_RETCODE_TIMEOUT` may have succeeded server-side; the EA will never know (the position may later appear and be managed, but no telemetry linkage exists).

### Notable observations

- `tradeResult.order` is used as the "ticket" for a `TRADE_ACTION_DEAL`; for market orders the meaningful identifier is `tradeResult.deal` (per docs: `order` is available for pending-type operations; for DEAL actions the deal ticket is the performed transaction). The current `ticket` capture is therefore also semantically misplaced for market orders.
- The NEW-path `CExecutionManager::ExecuteMarket` captures `ResultOrder()/ResultDeal()` correctly (ExecutionManager.mqh:194-195) — but it is dead code.
- `TRADE_RETCODE_DONE_PARTIAL` is mapped to a string (TradeManager.mqh:283) but never branched on; entry-side partial fills are invisible (only position-volume reduction is detected later, PositionLifecycleManager.mqh:457-474).

---

## 5. Execution State Machine

Current states by layer:

| Phase | Existing states | Implicit? | Missing |
|---|---|---|---|
| Decision | DECISION_CREATED/QUALIFIED/REJECTED (EntryDecisionTypes.mqh:9-14) | — | — |
| Plan | PLAN_CREATED/EXECUTABLE/REJECTED/REJECTED_PORTFOLIO (ExecutionPlanTypes.mqh:6-12) | — | no SUBMITTED/FILLED/FAILED |
| Order | — | SUBMITTED = in-memory `m_submittedIds` (TradeManager.mqh:236-252); ACCEPTED = `sent==true`; REJECTED = retcode (logged only) | no durable SUBMITTED; no CANCELLED; no TIMEOUT-unknown state |
| Deal/Fill | — | FILLED = position later discovered (PositionLifecycleManager.mqh:272) | no entry partial-fill state (DONE_PARTIAL never handled) |
| Position | DISCOVERED/OPEN/BREAK_EVEN/TRAILING/PARTIAL/EXIT_PENDING/CLOSED (PositionLifecycleTypes.mqh:4-13) | CLOSED = position-gone detected by polling | — |
| Settlement | telemetry row: simulated outcome settled (SymbolContext.mqh:1497-1554); actualOutcome stamped only in-buffer | — | no durable SETTLED marker per decision |

Assessment:

- **Reconstructible from broker history:** order (existence, state, price, volume via `HistoryOrderGet`), deal (ticket, fill price/volume, position id via `HistoryDealGet`), position open/close (PositionsTotal / history). These can rebuild ACCEPTED → FILLED → CLOSED without EA-owned state — but they cannot rebuild INTENT unless the comment carries a durable decision identity.
- **Requires EA-owned durable state:** INTENT → SUBMITTED (the dedup key) and the decision→order→deal mapping. Everything after a real order exists can be reconstructed from broker history given the comment identity.
- **A formal explicit state machine is not required to start** (the position layer already has a workable one), but the INTENT/SUBMITTED boundary must become durable and the retcode/unknown-outcome handling must be explicit before any demo run. INTENT → SUBMITTED → ACCEPTED → FILLED → PARTIALLY_FILLED → REJECTED → CANCELLED → CLOSED → SETTLED is the correct target model; today only a subset is implicit or absent.

---

## 6. Restart / Crash Analysis

Notation: **BROKER** = server/terminal truth; **EA** = in-memory state; **TEL** = telemetry CSV rows; **HIST** = terminal order/deal history.

| # | Scenario | State before | Broker state | EA state | Telemetry state | Reconstructable | Lost | Duplicate risk | Required invariant |
|---|---|---|---|---|---|---|---|---|---|
| A | Clean EA restart | plan executable | nothing | plans/decisions/counters/submitted-set all reset | rows flushed at shutdown (B25-02/Shutdown flush) | decisions rebuilt from fresh structure scan; position contexts re-discovered (comment id) | decision↔telemetry linkage for pre-restart decisions; actual-outcome stamps for rows flushed before close | No (no order was sent) | — |
| B | Terminal restart (same as A for the EA) | — | positions persist | same as A | same as A | same as A | same as A | Same as A | — |
| C | Crash before OrderSend | plan PLAN_EXECUTABLE, id recorded submitted? No — recorded only after send attempt (TradeManager.mqh:206) | nothing | lost | row may already be queued/recorded (decision row exists even though order never sent — the gate row records the DECISION, not the execution) | nothing to reconstruct (no order) | the fact that an intent existed is only in the telemetry row; no execution marker | Low (no order sent; a regenerated candidate re-executes → that is *expected* legacy behavior) | decision rows must not claim execution |
| D | Crash after OrderSend, before return handling | — | **order may exist (retcode DONE/TIMEOUT)** | submitted-id lost; result never captured | no execution record | order/deal/position via broker history; position re-discovered by lifecycle manager (comment id) | fill truth (price/volume/deal), execution retcode | **HIGH if id not deduped durably and the same decision regenerates while no position gate blocks it** | durable SUBMITTED key or order-exists check (by magic+symbol+comment) before send |
| E | Crash after order accepted, before deal handling | — | order filled, position may exist | same as D | same as D | same as D | same as D | HIGH (see D) | same as D |
| F | Crash after partial fill | — | partial deal(s), position with reduced volume | contexts lost | actual-outcome stamp lost if not applied | partial fills via deal history (DEAL_ENTRY in/out) | per-deal fill price/volume (never captured) | LOW-MEDIUM (position exists → portfolio gate usually blocks re-entry; maxConcurrentPositions=10 does not block a second position) | per-deal ledger if partial fills must be tracked |
| G | Crash before settlement | position open | position open | contexts lost | row queued; simulated settlement never runs for the remaining rows (SettleRemaining runs at Shutdown only, SymbolContext.mqh:1161-1164) | position via broker; outcome via deal history (out-deal) | simulated settlement for unheld rows; actual stamp | LOW | ledger replay must settle from broker history |
| H | Reconnect with existing position | — | position open | DiscoverPositions at Init (PositionLifecycleManager.mqh:129) rebuilds context; entryDecisionId from comment | no row linkage unless id matches an in-memory decision (post-restart id space may collide with pre-restart ids — **ambiguous**) | position + comment id | candidateId (always 0 after restart); run disambiguation | MEDIUM (a new run's candidate with the same int id can be stamped onto the wrong pre-restart position close via the settler map) | comment must carry run-scoped identity |
| I | Duplicate decision after restart | decision executed pre-restart, position closed | closed deal history | counters reset; a structurally identical candidate may be regenerated with the same id | new row | dedup via broker history: an order/deal with the same comment identity already exists | — | **HIGH: same logical decision executed twice** | durable decision id + broker-history idempotency check |

**Summary:** the dangerous scenarios are D/E/I (crash after send / duplicate after restart) and F (partial fills). Their common root cause is that the only dedup mechanism (`m_submittedIds[]`) and the only decision↔telemetry bridge (setter map) are in-memory.

---

## 7. OnTradeTransaction Assessment

### What it provides (per MQL5 docs, verified)

`void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)`:
- `TRADE_TRANSACTION_ORDER_ADD/UPDATE/DELETE` — order lifecycle + `order_state` (e.g., ORDER_STATE_FILLED/PARTIAL/REJECTED/CANCELED), with `trans.price/volume/price_sl/price_tp/position`.
- `TRADE_TRANSACTION_DEAL_ADD/UPDATE/DELETE` — deal ticket, order ticket it came from, `price`, `volume`, `position` — the authoritative per-deal fill truth.
- `TRADE_TRANSACTION_POSITION` — position SL/TP/volume changes **not** caused by deals (broker-side stop modifications, server-side changes).
- `TRADE_TRANSACTION_REQUEST` — request + result correlation via `result.request_id` (works with `OrderSend`/`OrderSendAsync`).

### Which current gaps it would close

| Gap | Closed by OTT? |
|---|---|
| fill truth (price/volume/deal) | Yes — DEAL_ADD delivers broker-confirmed price/volume/deal/position per deal |
| broker-side SL/TP modification tracking | Yes — POSITION transaction (currently invisible; lifecycle manager only polls `PositionGetDouble(POSITION_SL)` on ticks) |
| partial fills | Yes — one DEAL_ADD per partial fill |
| order lifecycle for pending orders | Yes — ORDER_ADD/UPDATE/DELETE (pending orders are unused today) |
| async/timeout correlation | Yes — TRADE_TRANSACTION_REQUEST with `request_id` |
| close detection | No new capability — `DiscoverPositions` polling already detects a gone position on the next tick |

### Journal/history polling sufficiency

- History polling (`HistoryOrderGet`/`HistoryDealGet`/`PositionsTotal`) is **sufficient to reconstruct truth** for any deal/order/position state, and it is restart-safe. It is also the only restart-safe source of truth.
- What polling cannot do: (a) give you the *request* side (requested price vs fill) — that requires capturing at send time; (b) detect intra-tick event ordering (which of two modifications happened first) without timestamps — the docs note event arrival order is not guaranteed; (c) see broker-side SL/TP changes that were later overwritten — `POSITION_UPDATE` events capture the sequence that history polling collapses to the final state.
- **Both are required, in different roles**: the send-site capture (synchronous, at `OrderSend`) is the *intent/fill baseline*; history is the *reconstruction source*; OTT is the *event notification* that keeps the ledger fresh and captures broker-side mutations that polling would collapse. This is the standard "event + reconciliation" pattern.

### Determinism / tester / live implications

- OTT is supported in the Strategy Tester; transactions are delivered deterministically relative to the tick stream in tester mode, and asynchronously in live/demo. Any *logic* that consumes OTT must therefore be written to be idempotent and tolerant of delivery order.
- Adding an OTT handler that only **records** (writes to the execution ledger) does not alter strategy behavior — classification: **execution-observability infrastructure**.
- Adding OTT that **gates** order sending, retries, or changes position policy would be **strategy-bound** and is explicitly out of scope here.
- Caution: OTT is delivered per terminal-account event; in tester the "account" is simulated, so the handler must be active in all modes (tester/live) with the same recording discipline to keep evidence comparable.

**Conclusion:** OnTradeTransaction is *recommended but not required* for the minimum architecture; the minimum (send-site capture + history reconstruction) works without it. If adopted later, adopt it strictly as observability infrastructure, never as an execution gate.

---

## 8. Canonical ExecutionRecord Design (assessment only)

Candidate conceptual model (NOT implemented):

```
ExecutionRecord
{
    decisionId      // canonical, durable, run-scoped (B25-03)
    runId           // B25-01 run identity (RUN-<buildTag>-<tick>)
    buildIdentity   // buildTag + gitHead (compile-time constants, B25-01)
    executionIntent // request snapshot: action, type, requested price/volume, sl, tp, deviation, magic
    orderTicket     // broker order ticket (MqlTradeResult.order / HistoryOrderGet)
    dealTicket      // broker deal ticket (MqlTradeResult.deal / HistoryDealGet)
    requestedPrice  // request.price
    fillPrice       // result.price (broker-confirmed)
    requestedVolume // request.volume
    filledVolume    // result.volume (broker-confirmed)
    retcode         // + retcodeExternal, request_id
    executionState  // INTENT/SUBMITTED/ACCEPTED/FILLED/PARTIALLY_FILLED/REJECTED/CANCELLED/CLOSED/SETTLED
    timestamps      // intent, send, result, first-deal, close
    positionTicket  // position id linked to the deal(s)
    outcomeId       // telemetry decisionId (link back to the CSV row)
}
```

Assessment of each concern:

| Concern | Assessment |
|---|---|
| Required fields | The 16 above are the minimum to answer "what was intended, what happened, where is it now". `request_id` and `retcodeExternal` are cheap and useful for support. |
| Ownership | A new `ExecutionRecorder` component owned by the execution layer (wired by `CSymbolContext` like the other managers); it must NOT live inside `CTelemetryCollector` (separation of concerns; telemetry stays frozen). |
| Lifecycle | Created at plan acceptance; updated at OrderSend return; updated again on deal/position events (or on history reconciliation); terminal state CLOSED/SETTLED with close deal ids. |
| Persistence | Append-only ledger file (CSV or line-oriented), one record per event transition (or one record updated via new event lines + a compaction index). |
| Backward compatibility | The record is new data — no existing artifact changes. Telemetry schema v6 untouched; TT01 untouched; baselines untouched. |
| Telemetry relationship | `outcomeId` = telemetry decisionId; optional later: a telemetry *reference* column is NOT allowed (schema frozen) — the join lives in the ledger, not the CSV. |
| Broker relationship | Order/deal/position tickets make every record reconcilable against terminal history at any time (HistoryOrderGet/HistoryDealGet). |
| Restart relationship | The ledger is the durable reconstruction input; on restart the EA replays open/unsettled records against broker truth before trading. |

---

## 9. Durable Execution Ledger Options

| Option | Append-only | Crash resilience | Idempotency | Ordering | Duplicate prevention | Restart reconstruction | Research usability | Demo readiness | TT01 compatibility |
|---|---|---|---|---|---|---|---|---|---|
| A. Extend telemetry CSV | Yes (but schema frozen — **violates v6 contract**, breaks TT01 byte-identity gates and all frozen evidence) | Yes (checkpoint flush) | Partial | Yes | No | Partial | Yes | No (schema break) | **BREAKS TT01** |
| B. Separate execution ledger (new file, e.g. `execution_v1_<runId>.csv` in the telemetry dir or a sibling) | Yes | Yes (own flush discipline) | Idempotent by decisionId key | Yes (append order) | Dedup key = decisionId (durable) | Full replay | Yes (research can join decision↔order↔deal) | Yes (reconciliation input) | None — telemetry untouched |
| C. Canonical ExecutionRecord + telemetry reference | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | None |
| D. Other (broker-history-only, no EA-owned ledger) | n/a | n/a | n/a | n/a | no (nothing to dedup against) | Full (orders/deals/positions) but **no intent, no decision link** | Partial (no decision join) | Partial | None |

**Preferred future architecture (not implemented): B — a separate execution ledger as the durable execution-truth file**, with the canonical `ExecutionRecord` (section 8) as its row schema; telemetry keeps its frozen v6 contract; the ledger joins decision↔order↔deal↔outcome offline. Option C is the same thing stated as a named component — the practical difference is only whether the CSV row carries an outcome reference (not allowed in v6) or the ledger carries the telemetry decisionId (chosen). Broker history remains the ultimate source of truth and the reconciliation target; the ledger is the EA's durable projection of it.

Evaluation of the requested criteria: the ledger is append-only, checkpoint-flushed like the telemetry collector (proven B25-02 pattern), keyed by a durable decisionId (idempotent writes), ordered by append, restart-reconstructable by replaying open records against broker history, and fully TT01-compatible because no frozen artifact changes.

---

## 10. Research-Boundary Analysis

### Facts

- **No validated run has ever sent an order.** TT01 runs `EntryMode=2` (NEW mode; `Tools/TT01/TT01_Validate.ps1:327`), and `CTradeManager` sends only in `ENTRY_MODE_LEGACY` (`Portfolio/SymbolContext.mqh:603`). All 17 TT01 gates, T1–T9, ED01, and the Sprint 22 evidence were collected **without execution**.
- Telemetry rows record **decisions and simulated outcomes**; execution is currently orthogonal to every validated artifact.
- The schema v6 CSV is byte-frozen (identity columns constant per run, gate sentinels, deterministic rows); TT01 gates enforce it.

### Separation: EXECUTION OBSERVABILITY vs EXECUTION POLICY

| Change | Classification |
|---|---|
| Capture `MqlTradeResult` fully into a new ledger | Observability — no behavior change |
| Durable decision identity in the order comment | Observability — comment content only (broker-visible; no behavior change in EA logic) |
| Durable dedup key replacing `m_submittedIds[]` | **Observability-adjacent but behavior-relevant**: it *blocks* duplicate sends, i.e., it changes order-send behavior. Must be classified as a policy-adjacent change and validated as pure duplicate-prevention (no change to *when* the EA sends, only preventing *re-sending the same decision*). |
| `OnTradeTransaction` recorder (record-only) | Observability |
| Retry logic, requote handling, slippage policy, order routing, type_filling choice | **Strategy-sensitive — NOT ordinary engineering; out of scope for B25-03** |
| Any change to entry logic, execution enablement, risk sizing, stop policy, settlement semantics | **Strategy-sensitive — forbidden without separate authorization** |

### Impact on existing evidence

- Historical populations (ED01, Sprint 22, B8 baselines, frozen CONTROL): **no impact** — execution observability does not touch decision rows, gate columns, or settlement simulation.
- Telemetry semantics: **no impact** — schema v6 stays byte-identical; the ledger is a new, separate artifact.
- Behavior regression: **zero-risk surface** if implemented as planned — the ONLY behavioral delta is the duplicate-prevention key, which is strictly safety-increasing.

---

## 11. Demo Readiness

Assessment of the current architecture for a *controlled demo* (no recommendation to go live; gap list only):

| Concern | Current state | Gap |
|---|---|---|
| Duplicate-order prevention | In-memory `m_submittedIds[]` (TradeManager.mqh:28-29,236-252) | **P0 — not restart-safe; crash-after-send can double-execute a regenerated decision** |
| Broker reconciliation | None (no order/deal verification; only close-time P/L aggregation) | **P0 — no check that a send actually filled; timeout/unknown outcomes untracked** |
| Fill truth | Requested price/volume stored as "filled" (TradeManager.mqh:187-188) | **P0 for research truth — actual fill price/volume/deal never captured** |
| Partial fill handling | Entry-side: none; position-side: volume reduction detection only | **P1 — DONE_PARTIAL ignored; per-deal fill record absent** |
| Restart behavior | Position contexts rebuilt (comment id); counters reset | **P1 — decision identity ambiguous across runs (id collision)** |
| Execution ledger | None | **P1 — no durable execution truth** |
| Settlement recovery | Simulated settlement at shutdown only; actual stamps only in-buffer | **P1 — settled-only-while-running; post-restart closes never reach telemetry** |
| Broker rejection | Logged; id blocked; no retry/review | **P1 — rejections are invisible to research** |
| Connection loss | OrderSend retcode mapped (TRADE_RETCODE_CONNECTION) | **P2 — no reconnect reconciliation pass** |

Not demo-ready today. The two P0 gaps (durable dedup, broker reconciliation of unknown outcomes) are the gates to a controlled demo.

---

## 12. Invariants

Invariants that any B25-03 implementation must preserve (assessment-level, for the future implementation contract):

1. **Telemetry schema v6 is byte-frozen.** No column added/removed/reordered; identity columns constant per run; gate sentinels unchanged. (B25-01/02 + TT01 gates.)
2. **Decision rows are execution-independent.** A telemetry row records the decision and its simulated outcome; it never claims an execution that did not happen.
3. **One decision → at most one order.** The dedup key must be durable and survive restart; re-sending a decision is a violation.
4. **Every send has a record.** INTENT → at least one ledger row before OrderSend is allowed to fire.
5. **Fill truth comes from the broker.** `fillPrice/filledVolume/deal` come only from `MqlTradeResult` (or history), never from the request.
6. **Broker history is the final arbiter.** The ledger is reconcilable to `HistoryOrderGet`/`HistoryDealGet`/`PositionsTotal` at any time; mismatches are reported, never silently overwritten.
7. **runId disambiguates runs.** The comment-carried decision identity must be run-scoped so a post-restart id can never be mistaken for a pre-restart id.
8. **No strategy behavior change.** Entry logic, enablement, retries, order policy, risk sizing, stop policy, settlement semantics are untouched by observability work.

---

## 13. Risk Register

| ID | Risk | Likelihood | Impact | Current mitigation | Gap |
|---|---|---|---|---|---|
| R1 | Duplicate order after crash/restart (same decision re-sent) | Medium | High (financial) | in-memory submitted-set + portfolio position gate (maxConcurrentPositions=10 default, PortfolioRiskTypes.mqh:33) | no durable dedup; gate allows 10 positions |
| R2 | Fill-price/volume recorded wrong (request vs actual) | Certain (any slippage) | High (research truth) | none | `tradeResult.price/volume` discarded |
| R3 | Unknown outcome after TIMEOUT/CONNECTION rejection | Medium | High | id blocked after failure (no retry) | no reconciliation of unknown sends |
| R4 | Decision↔telemetry linkage lost after restart/flush | High (any restart) | High | settler in-memory map; GR02A documented boundary | no durable link |
| R5 | Post-restart candidate id collides with pre-restart id in comments/positions | High | Medium | none | run-scoped identity missing |
| R6 | Entry partial fills invisible | Low (FOK/IOC broker-dependent) | Medium | none | DONE_PARTIAL ignored |
| R7 | Broker-side SL/TP changes invisible | Medium | Low-Medium | polling `POSITION_SL` on ticks | no POSITION transaction capture |
| R8 | Settlement of rows never runs if EA crashes mid-run | Medium | Medium | Shutdown-only SettleRemaining; B25-02 checkpoint flush | no execution-time settle trigger |
| R9 | NEW-path `ExecutionManager` dead code could diverge from LEGACY behavior if ever wired | Low | Medium | not wired | two execution paths exist (documented, not activated) |

---

## 14. Priority Matrix

Classification per the mandate (P0 = safety blocker for demo/live; P1 = required for trustworthy execution research; P2 = important architecture; P3 = future).

| ID | Finding | Class |
|---|---|---|
| P-01 | Durable dedup/idempotency key replacing in-memory `m_submittedIds[]` (R1) | **P0** |
| P-02 | Reconciliation of unknown outcomes (TIMEOUT/CONNECTION sends checked against broker history; R3) | **P0** |
| P-03 | Canonical, run-scoped decision identity in the order comment + telemetry linkage (R4, R5) | **P1** |
| P-04 | Full `MqlTradeResult` capture (fill price/volume/deal/order, requested vs actual; R2) | **P1** |
| P-05 | Durable execution ledger (B, section 9) | **P1** |
| P-06 | Entry partial-fill recording (DONE_PARTIAL + per-deal rows; R6) | **P1** |
| P-07 | `OnTradeTransaction` record-only handler (broker-side SL/TP, deal events; R7) | **P2** |
| P-08 | Execution state machine formalization (INTENT→…→SETTLED) | **P2** |
| P-09 | Settlement recovery from broker history on restart (R8) | **P2** |
| P-10 | Reconnect reconciliation pass | **P2** |
| P-11 | Unify/remove the dead `CExecutionManager` order path (R9) | **P3** |
| P-12 | Retry/requote policy, type_filling policy | **P3 — strategy-sensitive, separate authorization** |

---

## 15. Recommended Architecture

Minimum architecture to establish trustworthy execution truth **without redesigning the EA**:

1. **Durable canonical decision identity (P-03).** A run-scoped decision id = `RUN-<buildTag>-<tick>:<candidateId>` (or a dedicated counter), assigned at candidate-build time, stamped onto: the order comment (replacing `SCX-*-P<id>`), the telemetry row's in-buffer record (via a parallel collector-side map — **no schema change**), and the ledger. This makes decision↔order↔deal↔telemetry joinable and restart-safe.
2. **Send-site capture (P-04).** In `CTradeManager::Update`, persist the full request + `MqlTradeResult` (requested price/volume, fill price/volume, order, deal, retcode, retcodeExternal, request_id, timestamps) into the ledger. One local change; no strategy logic touched.
3. **Durable dedup (P-01).** Replace `m_submittedIds[]` with a ledger-backed idempotency check (decisionId exists → already submitted) + a broker-history check (order/deal with the comment identity exists → already executed). Strictly prevents re-sends; does not change when the EA sends.
4. **Unknown-outcome reconciliation (P-02).** On send failure with ambiguous retcode (TIMEOUT, CONNECTION), record the INTENT as UNRESOLVED and reconcile against broker history on the next tick/restart before allowing any further sends for that decision.
5. **Separate execution ledger (P-05, section 9-B).** New file `execution_v1_<runId>.csv` (or equivalent), append-only, checkpoint-flushed with the proven B25-02 pattern. Telemetry v6 and TT01 untouched.
6. **Later (P2):** `OnTradeTransaction` record-only handler + formal state machine + restart settlement recovery.

This is a ~3-5 file change set: `Trading/TradeManager.mqh` (capture + dedup source), a new `Trading/ExecutionRecorder.mqh`, `Confluence/TradeCandidateBuilder.mqh` or `Entry/ExecutionPlanner.mqh` (identity assignment), `Trading/TradeRequestBuilder.mqh` (comment format), and `Portfolio/SymbolContext.mqh` (wiring). No changes to Telemetry*, EntryDecisionEngine, PositionLifecycle*, Risk*, Confluence*, or the frozen artifacts.

---

## 16. No-Change Recommendations

Items that must remain **exactly as-is** during B25-03 implementation (and are not recommended for change in this assessment):

- Telemetry schema v6, `TelemetryTypes.mqh`, `TelemetryCollector.mqh` — frozen contract (B25-01/02).
- TT01 harness and its gates — any new validation is a NEW gate (or a new Tool), never a modification of existing gates/baselines.
- Frozen baselines, CONTROL artifacts, ED01 artifacts, Sprint 22 evidence — untouched.
- Settlement semantics (`SettleDue`/`SettleRemaining`, `ForwardOutcomeSimulator`, outcome policies) — untouched.
- `OrderSend` call site behavior (no retries, no requote handling, no slippage changes) — strategy-sensitive.
- Entry logic, RiskManager, position sizing, stop/target resolution — untouched.
- `CExecutionManager` (dead NEW path) — do not wire it during B25-03 (P3 only).
- Demo/live approval — not requested, not recommended at this point.

---

## 17. Implementation Dependencies

For the future (authorized) implementation:

| Dependency | Purpose | Where it lives |
|---|---|---|
| B25-01 `runId`/`buildTag`/`gitHead` | run-scoped identity prefix + provenance | `Telemetry/TelemetryTypes.mqh` (read-only reuse) |
| B25-02 checkpoint-flush pattern | ledger flush discipline | `Telemetry/TelemetryCollector.mqh:329-333` (pattern, not code reuse into frozen file) |
| Broker history APIs | reconciliation + reconstruction | `HistoryOrderGet*` / `HistoryDealGet*` / `PositionsTotal` |
| MqlTradeResult full fields | fill truth | terminal trade API (docs verified) |
| Order comment budget | decision identity carrier | broker order comment (MT5 comment string; current format `SCX-BUY-P<id>` is short) |
| Test infra | TDD pins before wiring | `Tests/unit/` (new test file), `Tools/25B/` scripts, optional new TT01 gate (new, additive) |

---

## 18. Validation Strategy

For the future (authorized) implementation — the assessment's required validation:

1. **Unit (TDD, deterministic):** ledger record schema/append/idempotency; dedup key generation and restart-replay of an open dedup set; comment format encode/parse round-trip incl. run-scoped identity; result-capture mapping (requested vs fill fields); unknown-outcome state transitions; state machine transitions (INTENT→SUBMITTED→ACCEPTED→FILLED→…→SETTLED). Modeled on `Tests/unit/TestLifecycleContract.mqh` / `TestSettlementIsolation.mqh` conventions.
2. **Integration (tester):** a new **additive** TT01-style gate (new script/gate id, existing gates untouched) running LEGACY mode over a replay window that (a) verifies ledger rows exist for every sent order, (b) verifies fill price/volume/deal equality against deal history, (c) verifies no duplicate ledger entries for the same decisionId, (d) verifies telemetry v6 byte-identity is unchanged by the execution work (CONTRACT + B8 gates re-run on the same artifacts).
3. **Crash/restart tests:** checkpoint-flush → kill → restart → reconcile; assert (a) ledger loss window ≤ one checkpoint interval, (b) no duplicate send for an already-executed decisionId, (c) telemetry CSVs unmodified.
4. **Regression:** full TT01 (17/17) on the SAME binaries scope as B25-02 verification, plus frozen-hash checks of all four frozen artifacts; T1–T9 for the identity guarantees.
5. **Research usability check:** offline join of ledger ↔ telemetry CSV by decisionId/runId on a replay run; assert 100% join coverage for sent decisions.

---

## 19. No-Touch List

Explicitly frozen during B25-03 (assessment and any future implementation):

- `Telemetry/` — all files (schema v6, collector, types, row builder, settler, simulator, policies, health report).
- `Tools/TT01/` — harness, validators, baselines, run dirs, gates.jsonl, manifests.
- `Tools/25B/` — test scripts and artifacts (evidence).
- `Tools/ED01/` — analyzer, manifests, transcripts, results, artifacts dirs.
- Frozen evidence: `Tests/TestRunnerEA.ex5.bak20260812_194614`, `Tools/TT01/baseline/*`, CONTROL v5 CSVs, run-5 artifacts, `gates.jsonl`.
- `docs/` — existing Sprint docs and the B25-01/02 status doc (no edits; new docs only).
- Strategy layer: `Entry/` (decision, validator, risk, plan resolution), `Confluence/`, `Risk/`, `Portfolio/` (risk/position policy), `Structure/`.
- Settlement semantics: `SettleDue`/`SettleRemaining`, outcome policies, telemetry settlement columns.
- `SuperCents_X.mq5` entry-mode behavior, inputs, weights.
- No commit, no push, no TT01 run for this assessment (already honored — no files changed).

---

## 20. Explicit Authorization Request

This assessment makes NO code changes and requests NO implementation authorization. It requests, when the senior review is ready:

1. **B25-03a (execution truth capture — P-01/P-03/P-04/P-05):** durable run-scoped decision identity + full `MqlTradeResult` capture + separate execution ledger + durable dedup. Classification: execution-observability + duplicate-prevention only.
2. **B25-03b (reconciliation — P-02):** unknown-outcome reconciliation against broker history. Classification: execution-observability.
3. **Explicit denial of any strategy-sensitive change** (retry, requote, slippage, type_filling, entry/enablement/risk/settlement changes) under the B25-03 umbrella.

If authorized, the implementation will be TDD-pinned first (section 18), TT01-tested additively, and delivered with the same commit/push discipline as B25-01/02.

---

B25-03 STATUS:
**ASSESSMENT COMPLETE / IMPLEMENTATION NOT AUTHORIZED**

P0:
- P-01 Durable dedup/idempotency key replacing in-memory `m_submittedIds[]` (crash/restart duplicate-order risk)
- P-02 Reconciliation of unknown outcomes (TIMEOUT/CONNECTION sends checked against broker history)

P1:
- P-03 Canonical run-scoped decision identity in the order comment + telemetry linkage (R4/R5)
- P-04 Full `MqlTradeResult` capture — fill price/volume/deal, requested vs actual (currently `request.price` is stored as "filled"; `tradeResult.price/volume/deal` discarded)
- P-05 Separate durable execution ledger (telemetry schema v6 stays frozen)
- P-06 Entry partial-fill recording (DONE_PARTIAL + per-deal rows)

P2:
- P-07 `OnTradeTransaction` record-only handler (broker-side SL/TP changes, deal events)
- P-08 Execution state machine formalization (INTENT→SUBMITTED→ACCEPTED→FILLED→PARTIALLY_FILLED→REJECTED→CANCELLED→CLOSED→SETTLED)
- P-09 Settlement recovery from broker history on restart
- P-10 Reconnect reconciliation pass

P3:
- P-11 Unify/remove dead `CExecutionManager` order path (never wired; captures deal ticket correctly but unused)
- P-12 Retry/requote/type_filling policy — strategy-sensitive, separate authorization

RECOMMENDED ARCHITECTURE:
Run-scoped canonical decision id (`RUN-<buildTag>-<tick>:<candidateId>`) in the order comment + telemetry in-buffer map; send-site full `MqlTradeResult` capture; durable ledger-backed dedup + broker-history idempotency check; unknown-outcome reconciliation; separate append-only execution ledger (`execution_v1_<runId>.csv`, B25-02 flush pattern). No telemetry/TT01/strategy changes. OTT later, record-only.

REQUIRED VALIDATION:
TDD unit pins (ledger, dedup, comment identity, result mapping, state machine); new additive TT01-style LEGACY-mode gate (ledger↔deal-history equality, no-duplicate decisionId, telemetry v6 unchanged); crash/restart checkpoint tests; full TT01 17/17 + frozen-hash verification; offline ledger↔telemetry join coverage.

RESEARCH-BOUNDARY IMPACT:
None on existing evidence: all validated runs (TT01 17/17, T1–T9, ED01, Sprint 22, B8, frozen CONTROL) were collected in NEW mode with execution disabled — no order has ever been sent in any validated artifact. Execution observability touches decision rows, telemetry schema, or settlement simulation not at all; the only behavioral delta is duplicate-prevention (safety-increasing). Strategy-sensitive changes (retry/requote/slippage/enablement/risk/settlement) are explicitly out of scope.

DEMO READINESS:
NOT ready. P0 gaps: no restart-safe duplicate prevention; no reconciliation of unknown broker outcomes. P1 gaps: no fill truth (requested stored as filled), no durable decision identity, no execution ledger, no settlement recovery. Controlled demo should wait for P-01..P-05.

EXPLICIT NEXT-AUTHORIZATION REQUEST:
Authorization to implement B25-03a (P-01, P-03, P-04, P-05) and B25-03b (P-02) as execution-observability + duplicate-prevention only, TDD-pinned and additively TT01-validated; explicit denial of strategy-sensitive changes under B25-03. No demo/live approval requested.

STOP.
