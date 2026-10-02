# Sprint 25B — B25-03 Execution Truth Design

| Field | Value |
|---|---|
| Document | B25-03 DESIGN PHASE deliverable |
| Status | DESIGN + SENIOR CORRECTION COMPLETE — implementation not authorized |
| Date | 2026-08-15 |
| Source baseline | `docs/Sprint25B_B25-03_ExecutionTruth_Assessment.md` (ACCEPTED) |
| Senior gate | DESIGN ACCEPTED WITH REQUIRED CORRECTIONS (2026-08-15) — see Section 23 |
| Repo HEAD (unchanged) | `3c2f02a200da1eaf57e5b689068782997d9dbc0c` |
| Scope | P0-01 restart-unsafe duplicate prevention; P0-02 unknown execution outcome; fill-truth defect (requested treated as filled) |
| Constraints | No strategy/risk/retry/settlement/telemetry/TT01/ED01/baseline changes. No `OnTradeTransaction`. No live execution. No commit/push. |

---

## 1. Design Objective

Convert the ACCEPTED B25-03 assessment into an implementation-ready architecture
specification for the three demo-blocking defects:

1. **P0-01 — Restart-unsafe duplicate prevention.** Today the only anti-duplicate
   mechanism is the in-memory `m_submittedIds[]` array in `TradeManager.mqh`
   (TradeManager.mqh:28-29, 236-252). It is keyed by `planId` (= `entryDecisionId`,
   a run-local integer) and vanishes on any restart. A crash between `OrderSend`
   and state capture (or an EA restart after submission) can re-send the same
   execution intent, producing a duplicate order.
2. **P0-02 — Unknown execution outcome.** `TradeManager.mqh:206` calls
   `RecordSubmitted(planId)` *regardless of outcome*, so a `TIMEOUT`,
   `REQUOTE`/connection anomaly, or accepted-but-result-lost request is never
   reconciled against the broker. The intent may actually have filled; the EA
   simply stops tracking it.
3. **Fill-truth defect.** `TradeManager.mqh:187-188` copies the *requested* price
   and volume into the position context as `filledPrice` / `filledVolume`, while
   the broker-confirmed `MqlTradeResult` fields (`price`, `volume`, `deal`, `bid`,
   `ask`, `comment`, `request_id`) are discarded (the `MqlTradeResult` struct is
   local to `CTradeManager::Update`). Requested is not filled.

This document specifies the architecture that removes all three defects without
changing any strategy, risk, retry, settlement, telemetry, TT01, ED01, or
baseline behavior. Every proposed implementation change is classified
(SAFE INFRASTRUCTURE vs STRATEGY-SENSITIVE) in Section 14 and gated in Section 21.
**No source file is modified by this document.**

---

## 2. Current Defects (verified, with exact references)

| # | Defect | Evidence |
|---|---|---|
| D1 | No canonical, durable execution identity. `TradeCandidate.id` is an in-memory counter (`TradeCandidateBuilder.mqh:20,67,175,231,435`) that resets to 1 each run. | Assessment §3 |
| D2 | Broker comment `SCX-BUY-P<id>` / `SCX-SELL-P<id>` (TradeRequestBuilder.mqh:59,65) is unique only within a run; collides across restarts. | Assessment §4 |
| D3 | Deduplication is in-memory only (TradeManager.mqh:28-29, 236-252), keyed by run-local `planId`. | Assessment §5 |
| D4 | `filledPrice = request.price`, `filledVolume = request.volume` (TradeManager.mqh:187-188); `MqlTradeResult` broker-confirmed fields discarded; order ticket kept only when `sent == true` (:184). | Assessment §5 |
| D5 | No reconciliation on `TIMEOUT` / uncertain retcodes; `RecordSubmitted` records regardless of outcome (TradeManager.mqh:206). | Assessment §5 |
| D6 | No restart recovery path for execution state. After restart the position is rebuilt from the broker (`PositionLifecycleManager.mqh:219-220`) with `candidateId`/`executionPlanId` = 0. | Assessment §6 |
| D7 | Portfolio position gate evaluated once at plan time (`PortfolioRiskManager.mqh:153-157`, `SymbolContext.mqh:1049-1070`); no send-site guard. | Assessment §5 |
| D8 | Telemetry rows carry no broker identity (no candidateId/order/deal columns; `TelemetryRowBuilder.mqh:65,131`). | Assessment §8 |
| D9 | GR02A actual-outcome stamping applies only while the row is buffered (`TelemetryCollector.mqh:344-361`; buffer 1024 / checkpoint 64, :40,43). | Assessment §8 |
| D10 | The only send-site code that captures broker truth correctly (`CExecutionManager::ExecuteMarket`, ExecutionManager.mqh:152-208) is dead code in the NEW/SHADOW path; the LEGACY path (`EntryMode=0`) is the only active pipeline (TradeManager.mqh:179). | Assessment §4 |

None of the validated research runs (TT01, `EntryMode=2`) has ever sent an order;
execution is enabled only in LEGACY mode (`SymbolContext.mqh:603`). All defects
above are latent in the currently validated paths and become live only when the
LEGACY execution path is exercised.

---

## 3. Canonical Execution Identity

### 3.1 Design

A new durable execution identity, owned by a new execution-recording layer
(proposed `CExecutionRecorder`), created **at the send site** — not in the plan
structs:

```
executionId = "EX-" + runId + "-" + seq
```

- **runId**: the existing B25-01 provenance string `"RUN-<buildTag>-<GetTickCount()>"`
  (TelemetryCollector.mqh:277). The recorder **receives the same value** from
  `SymbolContext` (already computed at init); it never re-generates it, so the
  execution ledger and telemetry share one run identity.
- **seq**: a durable, never-reset monotonic counter maintained in a dedicated
  counter file (Section 7.4). `seq` is globally unique across all runs, crashes,
  and restarts; uniqueness is guaranteed by the file, not by memory. A
  monotonicity assertion guards against counter rollback or a stale copy
  (Section 7.4, Invariant 14).

Allocation happens immediately before the first ledger write of an intent
(Section 8.2), so an intent either has an `executionId` in the ledger or was
never an intent. The full crash-window proof of this lifecycle is in
Section 23.2.

### 3.2 Answers to the mandated questions

| Question | Answer |
|---|---|
| When is it created? | At the send site, when `CTradeManager::Update` is about to send an order for a plan that passes all gates and is not already in the ledger. |
| Who owns it? | `CExecutionRecorder` (new file). No plan/candidate/decision struct is modified; the recorder maps `(runId, entryDecisionId) -> executionId`. |
| Generation | One `executionId` per `(runId, entryDecisionId)`. The same strategy decision regenerated after a restart is a **new** run → new `entryDecisionId` (run-local counters reset) → new `executionId`. This is deliberate: a regenerated decision is a new execution intent by identity. |
| Uniqueness scope | Global across runs and restarts (durable `seq`). |
| Persistence | In the execution ledger (INTENT event) and, in compressed form, in the broker comment (Section 4). |
| Restart behavior | Rebuilt from the ledger at startup (Section 10); never re-derived from memory. |
| Relation to candidateId | `candidateId` stays the strategy-layer per-run id. The ledger INTENT event records `candidateId`, `entryDecisionId`, and `executionId` side by side. Explicit mapping, no merging. |
| Relation to telemetry decisionId | **Unchanged.** Telemetry `decisionId = ++m_runId` (`TelemetryCollector.mqh:307-308`) keeps its semantics and its row schema (frozen v6). The only link is a future *read-only* column-join via the ledger INTENT event (`executionId, decisionId`) when a future telemetry schema is authorized. This design does **not** redefine, rename, or re-map telemetry's decisionId. |
| Relation to order/deal tickets | `executionId` is the durable key; `orderTicket` and `dealTicket` are broker-assigned and recorded as **attributes** of the execution (Section 5), never used as the identity key. |

### 3.3 Comment token (compressed projection)

The broker comment carries a compact, parseable projection of the identity:

```
SCX-BUY-P<decisionId>#<seq>
SCX-SELL-P<decisionId>#<seq>
```

- `P<decisionId>` is **unchanged** (backward compatible — full proof in
  Sections 4.2 and 23.3).
- `#<seq>` is the durable global sequence, giving the comment global uniqueness.
- The full `executionId` is recovered as `"EX-RUN-<buildTag>-<tick>-" + seq`
  through the ledger (which stores runId per seq), or cross-validated directly
  from the comment when the ledger row exists.
- **Tail-strip tolerance**: if a broker strips or replaces the `#<seq>` tail,
  the comment degrades to the legacy format and still parses (Section 23.3);
  recovery then relies on the ticket/time/volume correlation paths
  (Section 9.3), never on comment equality alone.

---

## 4. Broker Correlation

### 4.1 Verified MQL5 constraints (documentation research, 2026-08-15)

Per the official **MetaTrader 5 Help — "Executing Trades"** (metatrader5.com/en/terminal/help/trading/performing_deals):

1. **The maximum comment length is limited to 31 characters.**
2. The comment appears **in the list of open positions and in the history of
   orders and deals** (i.e., it propagates to order, deal, and position records).
3. **A comment to an order can be changed by a broker or server.** (Confirmed by
   multiple practitioner sources: e.g., brokers replace comments on cancelled/
   expired orders and may append SL/TP text or broker codes.)

### 4.2 Consequences for the design

- **Comment budget**: `SCX-SELL-` (9) + `P` (1) + decisionId (≤10) + `#` (1) +
  seq (≤8, guarded, Section 7.4) = **≤ 29 characters ≤ 31**. The existing
  `SCX-BUY-P<decisionId>` / `SCX-SELL-P<decisionId>` format is preserved
  verbatim; only a `#<seq>` tail is appended.
- **GR02A is preserved with zero parser changes**: `ParseEntryDecisionId`
  (PositionLifecycleManager.mqh:597-609) extracts everything after `-P` and
  passes it to `StringToInteger`, which stops at the first non-digit
  (`"123#456" -> 123`). The `#<seq>` tail is invisible to the existing parser.
  `PositionLifecycleManager.mqh` and the `EVENT_POSITION_CLOSED` flow are
  **untouched**. Complete consumer inventory and parse proof: Section 23.3.
- **The comment is a correlation hint, never the source of truth.** Because a
  broker may mutate or replace comments, matching never relies on comment
  equality alone (Section 9.3).
- **Reserved headroom**: keep the token ≤ 26 characters in the design so a
  broker that appends its own text cannot push the terminal/server past the
  31-character field limit (field-level truncation is by the broker/server, not
  the EA).
- **Pre-existing parser exposure (unchanged, documented)**: the parser finds
  the first `-P` substring. If a broker were to *prefix* the comment with text
  containing an earlier `-P`, the legacy parser would also mis-parse — this is
  pre-existing behavior, not a regression of this design; the mitigation is the
  correlation hierarchy (Section 9.3), not the parser (which is frozen).

### 4.3 Correlation hierarchy (most authoritative first)

| Rank | Key | Authoritative? | Used for |
|---|---|---|---|
| 1 | `MqlTradeResult.order` / `result.deal` at send time | Yes (broker-confirmed) | Immediate send truth |
| 2 | History order/deal/position by exact ticket | Yes | Post-hoc verification |
| 3 | (magic, symbol, comment-prefix, time window) | Hint only | Reconstruction when tickets are unknown (e.g., after restart) |
| 4 | (magic, symbol, volume ≤ requested ± lot step, time window) | Hint only | Fallback when comment was mutated/replaced/stripped |
| 5 | Comment-only equality | **Never** | Rejected as sole matcher |

---

## 5. Execution Truth Model

### 5.1 Five canonical states of truth

| State | Definition | Authoritative source | Current handling |
|---|---|---|---|
| REQUESTED | What the EA asked the broker to do. | `MqlTradeRequest` fields (built by TradeRequestBuilder) | Recorded (ledger INTENT event, NEW) |
| ACCEPTED | The broker accepted the request. | `MqlTradeResult.retcode` (`TRADE_RETCODE_DONE` / `TRADE_RETCODE_PLACED`) + `result.order` | Discarded today (D4) |
| EXECUTED | A deal was completed against the order. | `MqlTradeResult.deal`, `result.price`, `result.volume` (broker-confirmed) + history `DEAL_ENTRY_IN` deals | Discarded today (D4) |
| FILLED | Cumulative executed volume equals the requested volume (or order is terminal). | History deals on the order ticket + `ORDER_STATE` | Never computed |
| SETTLED | Settlement layer consumed the terminal execution. | Future settlement handoff (Section 13) | N/A (future) |

**Rule (fill truth)**: the words "fill price" and "fill volume" may only be
derived from broker-confirmed sources — `MqlTradeResult.price/volume/deal`
immediately after `OrderSend`, or history deal records. `request.price` /
`request.volume` are **REQUESTED** values, never filled values. The ledger
records both, in separate columns, and any consumer of the ledger may rely on
the distinction.

### 5.2 Fill decomposition (senior correction, Section 23.1)

The execution lifecycle decomposes into four distinct situations that must not
be conflated:

| Situation | Meaning | Ledger state |
|---|---|---|
| **A** | Order accepted by broker, **no deal yet** (ticket known, zero fills) | `ACCEPTED` (non-terminal) |
| **B** | **One or more partial deals while the order remains active** (cumulative fill < requested) | `PARTIALLY_FILLED` (non-terminal, intermediate) |
| **C** | **Order becomes completely filled** (cumulative fill == requested) | `FILLED` (terminal) |
| **D** | **Order becomes terminal with remaining unfilled volume** (canceled/expired/rejected-after-fills; remainder > 0) | `TERMINAL_PARTIAL` (terminal, remainder recorded) |

`PARTIALLY_FILLED` is an **intermediate** state only; the **terminal** broker
condition with an unfilled remainder is `TERMINAL_PARTIAL`. The two are
never merged. Cumulative execution truth is represented as
`filledVolume = Σ DEAL_IN.volume` and `remainingVolume = requested − filledVolume`,
both derived and recorded on every state event — the ledger represents truth
without deciding what the strategy should do with the remainder (Section 11).

### 5.3 ExecutionRecord (ledger entry — schema, Section 7.5)

Per-intent canonical record carrying: `executionId`, `runId`, `buildTag`,
`decisionId`, `candidateId`, `entryDecisionId`, `seq`, `side`, `symbol`,
`magic`, `requestedVolume`, `requestedPrice`, `sl`, `tp`, `deviation`,
`filling`, `commentToken`, plus the captured result block: `retcode`,
`retcodeExternal`, `orderTicket`, `dealTicket`, `acceptedPrice`,
`acceptedVolume`, `bid`, `ask`, `resultComment`, `requestId`, plus the derived
fill block: `filledVolume` (cumulative), `remainingVolume`, `orderState`,
`terminalReason`, and the state-machine state (Section 6).

**Evaluation note (from the assessment)**: the candidate `ExecutionRecord` in
the assessment is accepted with the following corrections — (a) the identity key
is `executionId` (durable), not the run-local decisionId; (b) `filledPrice`/
`filledVolume` columns are renamed `acceptedPrice`/`acceptedVolume` to prevent
the exact confusion that caused D4; (c) per-deal fill facts live in separate
`DEAL_IN` events, not in the record itself (append-only principle, Section 7);
(d) `filledVolume`/`remainingVolume`/`orderState`/`terminalReason` are added so
partial-fill truth is fully representable without any strategy policy.

---

## 6. Execution State Machine

Formalized, with the mandated `UNKNOWN_SUBMISSION` state and the senior
correction separating intermediate vs terminal fill states (Section 23.1).

```
                        (dedup check / gates)
  INTENT ──send invoked──> SUBMITTED ──result captured──> ACCEPTED ──first deal──> PARTIALLY_FILLED | FILLED
    │                         │  │                            │
    │                         │  │  outcome lost              ├── deal, cumulative == requested ──> FILLED (terminal)
    │                    definitive │                          ├── zero fills, order removed/expired ──> CANCELLED (terminal)
    │                 rejection (zero│                        └── zero fills, rejection retcode ──> REJECTED (terminal)
    │                 fills only)     └──> UNKNOWN_SUBMISSION
    │                         ▼                                   │
    │                    REJECTED                         reconcile (evidence-based):
    │                                                       └──> ACCEPTED | PARTIALLY_FILLED | FILLED | TERMINAL_PARTIAL
    │                                                       └──> RESOLVED_NOT_FOUND (terminal) | RESOLVE_AMBIGUOUS (blocked)
    └── send never reached ──> RESOLVED_NOT_ISSUED (terminal)

  PARTIALLY_FILLED (non-terminal; cumulative < requested; order active)
      ├── more DEAL_IN, cumulative still < requested ──> PARTIALLY_FILLED
      ├── cumulative == requested ──────────────────────> FILLED (terminal)
      └── order terminal, remainder > 0 ────────────────> TERMINAL_PARTIAL (terminal)

  FILLED | TERMINAL_PARTIAL ── position closed ──> CLOSED ── settlement ──> SETTLED (future)
```

| State | Entered by | Terminal? |
|---|---|---|
| `INTENT` | Ledger INTENT event written + flushed, before send | no |
| `SUBMITTED` | Ledger SUBMITTED event written + flushed, immediately before `OrderSend` | no |
| `ACCEPTED` | `result.retcode` in `{DONE, PLACED}`; order ticket known; **zero deals yet** | no |
| `PARTIALLY_FILLED` | ≥1 `DEAL_IN` with cumulative < requested; order still active | no (intermediate) |
| `FILLED` | Cumulative `DEAL_IN` volume == requested volume | yes |
| `TERMINAL_PARTIAL` | Order terminal (canceled/expired/rejected-after-fills) with remainder > 0; `terminalReason` recorded | yes |
| `REJECTED` | Definitive rejection retcode; **zero fills** | yes |
| `CANCELLED` | Order removed/cancelled/expired by broker; **zero fills** | yes |
| `UNKNOWN_SUBMISSION` | Send invoked but outcome unknown (retcode `TIMEOUT`/`REQUOTE`-uncertain/connection anomaly, or result never captured) | no |
| `RESOLVED_NOT_ISSUED` | SUBMITTED flushed but send never reached / crash before send; no broker trace | yes |
| `RESOLVED_NOT_FOUND` | Reconcile found no broker trace | yes |
| `RESOLVE_AMBIGUOUS` | Reconcile matched >1 candidates | no — symbol blocked |
| `CLOSED` | Position fully closed; out-deals complete | yes |
| `SETTLED` | Settlement handoff complete | yes (future) |

**Terminal-consistency rule (Invariant 15)**: `REJECTED` and `CANCELLED` are
zero-fill terminals. Any order that reaches a terminal broker condition with
fills > 0 transits to `TERMINAL_PARTIAL` (with the broker reason as an
attribute), never to `REJECTED`/`CANCELLED`. `PARTIALLY_FILLED` never appears
as a terminal state.

Transition triggers and guard conditions are part of the ledger event schema
(Section 7.5); each transition must be idempotent (re-applying an event is a
no-op).

---

## 7. Execution Ledger

### 7.1 Principle

**Append-only events, never mutable state.** The in-memory execution index is a
derived projection of the ledger, rebuilt at startup and updated by appends.
There is no in-place update, no rewrite, no truncation of the ledger (except
operator-archived rotation defined in 7.6).

### 7.2 Files and location

Under the same `FILE_COMMON` directory family as telemetry:

```
Common\Files\Execution\
  execution_v1_<YYYYMMDD>.csv      (events; daily rotation, telemetry convention)
  execution_seq.dat                (durable sequence counter, never rotated)
```

Daily files match the telemetry pattern (`telemetry_v6_<YYYYMMDD>.csv`,
`TelemetryCollector.mqh:67-75`), keeping harness/archival tooling symmetric.
Per-day files are chosen over per-run files to avoid embedding `runId` in
filenames (runId contains `-` and digits only after sanitization, but day-based
names are simpler and match the proven telemetry layout); `runId` is a column.

### 7.3 Event types

| Event | Payload (minimal) | Written |
|---|---|---|
| `INTENT` | executionId, runId, decisionId, candidateId, seq, side, symbol, magic, requestedVolume, requestedPrice, sl, tp, deviation, filling, commentToken | before send; **flush before send** |
| `SUBMITTED` | executionId, send timestamp | immediately before `OrderSend`; **flush before send** |
| `RESULT` | executionId, full MqlTradeResult block (Section 5.3) | immediately after `OrderSend`; flush |
| `RECONCILED` | executionId, resolution (`FOUND_*`/`NOT_FOUND`/`AMBIGUOUS`), evidence block (matched ticket, orderState, cumulative fill, match key used) | after reconciliation |
| `DEAL_IN` | executionId, dealTicket, price, volume, time, commission, swap, **orderState at observation** | on fill discovery |
| `DEAL_OUT` | executionId, dealTicket, price, volume, time, profit, commission, swap | on position close discovery |
| `CLOSED` | executionId, positionId, close time | when position is gone |
| `BLOCKED` | executionId (or "GLOBAL"), reason code, symbol | on any safety-block |

`DEAL_IN` events are the cumulative-truth carrier: `filledVolume` and
`remainingVolume` are derived from them and stamped on each state event
(Sections 5.2, 11).

### 7.4 Durable sequence counter (`execution_seq.dat`)

- Format: single line, decimal `int64`, plus a checksum line (e.g., `seq ^ 0xA5A5A5A5` for corruption detection).
- Protocol: **reserve-before-use** — read, validate, `seq+1`, write, `FileFlush`, **then** allow the send.
- **Monotonicity assertion (Invariant 14)**: at every allocation the recorder
  asserts `seq > lastSeq` where `lastSeq` is the maximum seq in the ledger
  index. A violation (counter rollback, restored stale copy, file tampering)
  → **`BLOCKED` global**, no new sends. This makes the identity-collision class
  of failures detectable rather than silent.
- On missing/corrupt file at startup: rebuild as `max(ledger seq) + 1` (ledger is authoritative). If the ledger is also missing/corrupt → **`BLOCKED` global; no new sends** (Section 7.7).
- Width guard: if `seq > 99,999,999` → `BLOCKED` (comment budget protection). Practically unreachable.
- In **Strategy Tester**: `FILE_COMMON` is staged per agent run (B25-01 root cause); the counter is seeded from the ledger scan of the current tester session (per-run uniqueness is sufficient inside a tester run; cross-run durability is a demo/live concern, exactly where the file persists across restarts).

### 7.5 Row schema (CSV, quoted strings)

```
event,ts,runId,executionId,decisionId,candidateId,seq,side,symbol,magic,
requestedVolume,requestedPrice,sl,tp,deviation,filling,commentToken,
retcode,retcodeExternal,orderTicket,dealTicket,acceptedPrice,acceptedVolume,
bid,ask,resultComment,requestId,filledVolume,remainingVolume,orderState,
terminalReason,state,resolution,matchedTicket,dealPrice,dealVolume,dealTime,
profit,commission,swap,note
```

Header row carries `schemaVersion=1` and a `buildTag` comment line (mirroring the
telemetry v6 header convention). Empty fields are written as empty strings; no
nulls. `StringFormat`/`FileWrite` per the telemetry writer pattern
(`TelemetryCollector.mqh:82-104`).

### 7.6 Flush, rotation, recovery, corruption

| Concern | Policy |
|---|---|
| Flush | Mandatory `FileFlush` after `INTENT`, `SUBMITTED`, and `RESULT`. Other events batched (checkpoint-style, telemetry's 64-row pattern is the ceiling). |
| Rotation | Daily file per telemetry. Old files are never deleted by the EA. |
| Recovery | Startup scan: validate header; read rows; rebuild index; last event per (executionId) wins for duplicate appends (idempotent). |
| Torn tail | Replay stops at the last **complete** row. A single incomplete final line is discarded **only under the proof that it cannot hide an executed intent**: any broker-executed order requires a successfully flushed `SUBMITTED` row, which requires a successfully flushed `INTENT` row before it (sequential appends). Therefore a torn tail can only belong to an intent whose `INTENT`/`SUBMITTED` flush itself failed — an intent that provably never sent an order (Section 23.2, lemma). The discarded line is logged. |
| Interior corruption | Any malformed row **not** in the final-line position (short field count, bad header, non-numeric key) → mark ledger `DEGRADED`, log, and **block all new sends** for the run. Never silently skip rows. |
| Sizing | Order volume is tiny (≈ 8-10 events per execution). No size-driven rotation needed. |

### 7.7 Safety-block semantics

`BLOCKED` is the fail-safe position: no new `OrderSend` for a symbol (or globally,
per event) while (a) any `UNKNOWN_SUBMISSION` is unresolved for that symbol at
startup, (b) the ledger or counter is corrupt, (c) reconciliation is
`AMBIGUOUS`, or (d) the counter monotonicity assertion fails. Blocking is
surfaced through the existing health-monitor logging and reported in the
run-end report; it is never silently lifted.

---

## 8. Durable Deduplication

### 8.1 Key

The dedup key is the **`executionId`** (durable, ledger-backed). The in-memory
`m_submittedIds[]` array (TradeManager.mqh:28-29, 236-252) is replaced by a
ledger-derived index (proposed change: `TradeManager.mqh` send-site reads the
recorder's `IsTerminalOrPending(executionId)` check instead of the array).

### 8.2 The invariant

> **SAME EXECUTION INTENT MUST NOT RESULT IN UNINTENDED DUPLICATE ORDER SUBMISSION.**

Enforcement (three layers):

1. **Ledger pre-check (durable)**: before any send, the recorder checks whether
   an INTENT for the allocation context already exists. The INTENT event is
   written and flushed **before** the first possible `OrderSend` for that
   `executionId`; a crash cannot erase it. After restart, the ledger replay
   shows the intent in `INTENT`/`SUBMITTED`/`UNKNOWN_SUBMISSION` → reconciliation
   (Section 9) resolves it → the state is terminal → the send path refuses to
   re-issue the same `executionId`.
2. **Startup-scoped broker probe (hint layer)**: during restart recovery, the
   reconciler probes broker history for orders/deals/positions with the EA
   magic and an `SCX-` comment prefix in the recovery window, catching any
   execution the ledger could not account for (e.g., ledger files externally
   deleted — the documented operational-control case, Section 23.2). This probe
   is **startup-only**, not per-send: per-send safety is provided by the ledger
   state check and the existing portfolio position gate (layer 3), and a
   per-send history scan would add unbounded cost for no correctness gain.
3. **Portfolio gate (existing, unchanged)**: `maxConcurrentPositions` evaluated
   at plan time (`PortfolioRiskManager.mqh:153-157`); unchanged, not part of
   this scope.

### 8.3 Legitimate exceptions (documented, not bugs)

- A decision regenerated after its execution resolved to a **terminal**
  non-filled state (`REJECTED`, `RESOLVED_NOT_ISSUED`, `RESOLVED_NOT_FOUND`,
  `CANCELLED`, `TERMINAL_PARTIAL`). The regenerated decision is a **new**
  `executionId` (new run).
- A new decision after the original position fully closed (normal re-entry
  semantics — identical to today's strategy behavior).
- A new decision after manual/human intervention on the account.
- Partial-fill remainder: NOT re-issued by design (continuation is
  strategy-sensitive; Section 11).

### 8.4 What dedup does NOT do

- No automatic retry of rejected/unknown intents (retry policy is
  strategy-sensitive; default OFF, unchanged).
- No re-issue of an unresolved `UNKNOWN_SUBMISSION` — it must be reconciled
  first, at startup or before the symbol is unblocked.

---

## 9. Unknown Outcome Reconciliation (P0-02)

### 9.1 State flow (mandated)

```
SUBMIT ──> UNKNOWN_SUBMISSION ──> RECONCILE BROKER ──> FOUND ──> ACCEPTED | PARTIALLY_FILLED | FILLED | TERMINAL_PARTIAL
                                                            (evidence-based terminal/non-terminal states)
                                                  └─> NOT FOUND ──> RESOLVED_NOT_FOUND (terminal)
                                   (also: AMBIGUOUS ──> RESOLVE_AMBIGUOUS ──> symbol blocked)
```

### 9.2 When reconciliation triggers

- **At startup** (Section 10): every non-terminal ledger record is reconciled
  before any new send.
- **At runtime**: on `TIMEOUT`/uncertain retcodes after `OrderSend` (the exact
  case D5), and on `RESULT` records where `result.order == 0` but retcode
  suggests acceptance.

### 9.3 Matching algorithm (in priority order)

Inputs: `executionId`, `symbol S`, `magic M`, exact comment token `C`,
`requestedVolume V`, send time `T_send` (ledger `SUBMITTED` timestamp),
any captured ticket `T_ord` / `T_deal`.

1. `HistorySelect(T_send - ε, TimeCurrent() + δ)` with ε = 5 s, δ = 60 s
   (configurable constants).
2. **Ticket path**: if `T_ord`/`T_deal` > 0, query that order/deal/position by
   ticket → `FOUND` (broker-comment mutation cannot defeat this).
3. **Order path**: orders with `magic == M`, `symbol == S`,
   `ORDER_COMMENT` prefix-matches the `SCX-<SIDE>-P<d>` token (with or without
   the `#<seq>` tail; mutation-tolerant), order state captured
   (`ORDER_STATE_PLACED/PARTIAL/FILLED/CANCELED/REJECTED/EXPIRED`).
4. **Deal path**: deals with `magic == M`, `symbol == S`, `DEAL_ENTRY_IN`,
   `time ≥ T_send - ε`, **`volume ≤ V + lot step`** — the upper-bound form is
   required because a partial fill's deal volume is a *fraction* of the
   requested volume (senior correction, Section 23.4); comment prefix if still
   present.
5. **Position path**: open positions with `magic == M`, `symbol == S`, and
   `POSITION_COMMENT` prefix-matching the token (or matching the time window +
   volume); an open position with the EA magic is positive evidence of an
   executed intent.
6. None matched → `NOT_FOUND`.

Outcomes: each `FOUND` outcome returns the evidence block — matched ticket,
`orderState`, cumulative fill volume — and transitions to the **evidence-based**
state (`ACCEPTED` / `PARTIALLY_FILLED` / `FILLED` / `TERMINAL_PARTIAL`), never
to a generic "found" placeholder. `NOT_FOUND` → `RESOLVED_NOT_FOUND`
(terminal).

**Ambiguity rule**: if steps 2-5 yield more than one distinct candidate (broker
duplication or counter-file loss), do **not** auto-resolve: `RESOLVE_AMBIGUOUS`
→ `BLOCKED` for the symbol → surfaced in the health monitor. Fail-safe, never
guess.

**No blind retry.** After `RESOLVED_NOT_FOUND`, the intent is terminal; a new
intent requires a new decision (legacy semantics), and any automatic
re-submission policy is strategy-sensitive and out of scope.

---

## 10. Restart Recovery

### 10.1 Startup sequence (mandated, ordered)

```
1. Load execution ledger (all execution_v1_*.csv in scope), rebuild index.
2. Validate counter file; rebuild from ledger max(seq)+1 if needed.
3. Identify non-terminal records (INTENT / SUBMITTED / UNKNOWN_SUBMISSION /
   RESOLVE_AMBIGUOUS).
4. For each: run reconciliation (Section 9.3) against broker history.
   - FOUND        -> transition to the observed broker state (fill truth from
                     history deals: price, volume, tickets; orderState).
   - NOT_FOUND    -> if SUBMITTED was flushed but no broker trace -> RESOLVED_NOT_ISSUED
                     (crash between SUBMITTED-flush and OrderSend).
   - AMBIGUOUS    -> BLOCKED for the symbol; report.
5. Startup broker probe (Section 8.2, layer 2): scan history for the EA magic
   with an SCX- comment prefix; any trace without a ledger counterpart is
   reported and the symbol is blocked (ledger-loss operational control).
6. Rebuild in-memory index from terminal states.
7. Only then permit new execution (per-symbol unblocking).
```

### 10.2 If reconciliation fails

A reconciliation failure (history access error, `HistorySelect` failure,
`AMBIGUOUS`, ledger corruption, monotonicity violation) leaves the affected
symbol (or the run) **blocked**. The default policy is **no
"start → blindly trade → reconcile later"**: new sends for a symbol with an
unresolved non-terminal record are refused until that record is terminal. (A
documented deviation would require explicit authorization; the default is the
safe one.)

### 10.3 Crash windows (summary; full proof in Section 23.2)

| Crash point | Ledger evidence | Recovery result |
|---|---|---|
| Before seq allocation | — | seq gap only; no intent |
| After allocation, before INTENT | counter advanced | seq gap; no intent |
| After INTENT flush, before SUBMITTED | INTENT | RESOLVED_NOT_ISSUED (no broker trace) |
| After SUBMITTED flush, before OrderSend | SUBMITTED | RESOLVED_NOT_ISSUED |
| During OrderSend | SUBMITTED | reconcile → FOUND/NOT_FOUND → terminal |
| After OrderSend, before RESULT capture | SUBMITTED | reconcile via ORDER_COMMENT path (token carries #seq) |
| After RESULT capture, before RESULT flush | SUBMITTED | reconcile (torn tail rule, Section 7.6) |
| After RESULT flush, before DEAL discovery | RESULT | replay; discovery re-runs from history |
| During restart recovery | — | idempotent replay; no sends until gate passes |

---

## 11. Partial Fill Model (senior correction — Section 23.1)

Truth model only; **no execution policy**.

- **The four situations (Section 5.2)**: A `ACCEPTED` (accepted, no deal yet),
  B `PARTIALLY_FILLED` (≥1 partial deals, order active, cumulative < requested —
  **intermediate, never terminal**), C `FILLED` (cumulative == requested),
  D `TERMINAL_PARTIAL` (order terminal with remainder > 0).
- **Cumulative truth representation**: the ledger accumulates one `DEAL_IN`
  event per fill; `filledVolume = Σ DEAL_IN.volume` and
  `remainingVolume = requestedVolume − filledVolume` are derived and stamped on
  each state event. The broker's own `orderState` is captured at every
  observation (`ORDER_STATE_STARTED/PLACED/PARTIAL/FILLED/CANCELED/REJECTED/
  EXPIRED`) so "order active" vs "order terminal" is broker evidence, not EA
  inference.
- **Terminal-consistency (Invariant 15)**: fills > 0 + terminal broker
  condition ⇒ `TERMINAL_PARTIAL` with `terminalReason` (CANCELED/EXPIRED/
  REJECTED-after-fills). Zero fills + terminal ⇒ `REJECTED`/`CANCELLED`.
- **Fill price** for any reporting is the actual `deal.price` (or
  `result.price` at send), never `request.price`.
- **Deduplication across partial fills**: the single `executionId` dedups all
  fill discovery; per-deal idempotency by `dealTicket`.
- **Explicitly NOT decided here** (STRATEGY-SENSITIVE, outside scope; default
  OFF, unchanged legacy behavior): retry of the remainder, remainder
  re-submission, partial-fill continuation, order modifications to chase the
  remainder. The ledger only represents the truth; the strategy decides later,
  if ever.

---

## 12. OnTradeTransaction Decision

Re-evaluation of options A–D (assessment §10 revisited with the ledger in place):

| Option | Freshness | Restart safety | Tester behavior | Determinism | Complexity | Verdict |
|---|---|---|---|---|---|---|
| A. MqlTradeResult only | send-time only | n/a | n/a | full | low | **adopted** (phase B) |
| B. History polling | tick/loop windowed | full | works | full | low-mid | **adopted** (completion truth) |
| C. OnTradeTransaction | event-driven | needs replay anyway | works; async ordering + duplicate events to reconcile | lower | high | defer |
| D. Hybrid | — | — | — | — | mid | **this design (A+B now, C later)** |

Decision: **D-hybrid — A for send truth + B for completion truth now; C is a
future, record-only observability component** (assessment P2-07). Rationale:

- The ledger + startup reconciliation (Sections 9-10) already deliver the
  restart-safe truth the demo requires; `OnTradeTransaction` adds no missing
  *decision* information.
- C introduces asynchronous `DEAL_ADD`/`ORDER_*` events that must be
  de-duplicated against ledger state and ordered relative to `MqlTradeResult` —
  complexity with zero P0/P1 benefit.
- If a future build adopts C, its contract is defined: **record-only** (never
  controls sends), writes `DEAL_IN`/`DEAL_OUT`/`CLOSED` events into the same
  ledger, idempotent by `(executionId, dealTicket)`.

**Explicitly out of scope here: no `OnTradeTransaction` is implemented or wired
in this design.**

---

## 13. Settlement Boundary

Interface-only. No settlement behavior changes.

- **Handoff point**: an execution becomes settlement-eligible when its
  state reaches `CLOSED` (position removed; out-deals complete), carrying
  `acceptedPrice`/`acceptedVolume` (broker-confirmed) and per-deal fill facts.
- **Requested ≠ fill, acceptance ≠ fill**: the settlement layer must never be
  handed `requestedPrice`/`requestedVolume` as fill facts. The ledger's
  accepted/fill columns are the only admissible inputs (future).
- **Contract (future)**: settlement subscribes to terminal ledger events via a
  `ExecutionLedgerReader` interface (read-only); it will consume `CLOSED` events
  and the fill block. The interface is specified here; nothing is implemented.
- **Today, unchanged**: GR02A actual-outcome stamping (in-memory settler map,
  `ActualOutcomeSettler.mqh:45-96`; `EVENT_POSITION_CLOSED`,
  `PositionLifecycleManager.mqh:236-238`; `GetClosedProfit` :617-638) keeps
  working exactly as-is, verified by the backward-compatible comment format
  (Sections 4.2 and 23.3).

---

## 14. Research Boundary

The design is **execution observability infrastructure**, not strategy policy.
Proof: the only observable strategy behavior at the send site is (a) whether a
send happens at all and (b) the requested order parameters. This design changes
neither the order parameters (request build is byte-identical except the comment
tail) nor the decision pipeline; it adds durable recording, verification against
the broker, and fail-safe refusal to re-send unresolved intents. The one
behavioral delta — refusing a send that would duplicate or follow an unresolved
intent — is exactly the P0 invariant and is safe in every scenario the dedup
check exists for.

Every proposed file touched by the implementation (Section 15) is classified:

| Classification | Meaning | Count |
|---|---|---|
| SAFE INFRASTRUCTURE | observability/recording/correlation; no strategy, risk, retry, or settlement semantics | all proposed |
| STRATEGY-SENSITIVE | would require separate authorization | none in this scope |

A change becomes STRATEGY-SENSITIVE if it alters: entry conditions, sizing,
SL/TP values, filling/deviation, retry behavior, requote handling, partial-fill
continuation, position gates, or settlement semantics. **This design includes
none of those.**

---

## 15. Proposed File Changes (for the FUTURE implementation; nothing modified now)

### 15.1 New files (all SAFE INFRASTRUCTURE)

| File | Contents |
|---|---|
| `Trading/ExecutionStateTypes.mqh` | state enum, event enum, `ExecutionRecord`, event structs |
| `Trading/ExecutionIdentity.mqh` | `CExecutionIdentity`: executionId build/parse, comment token build/parse, seq counter (file-backed, reserve-before-use, monotonicity assert) |
| `Trading/ExecutionLedger.mqh` | `CExecutionLedger`: append-only writer, header, flush, replay/index rebuild, torn-tail rule, DEGRADED detection |
| `Trading/ExecutionReconciler.mqh` | `CExecutionReconciler`: Section 9.3 matching, evidence-based resolution, AMBIGUOUS handling |
| `Trading/ExecutionRecorder.mqh` | `CExecutionRecorder` facade: identity+ledger+reconciler, startup gate, per-symbol block state |
| `Tests/unit/TestExecutionLedger.mqh` | unit tests (T1-style, existing harness) |
| `Tests/unit/TestExecutionReconciler.mqh` | unit tests incl. comment parse compatibility |
| `Tools/25B/execsim/` | separate simulation harness + validators (PS/Python) — never touches TT01/ED01 |

### 15.2 Modified files (minimal; SAFE INFRASTRUCTURE)

| File | Change | Why it is safe |
|---|---|---|
| `Trading/TradeRequestBuilder.mqh:59,65` | Append `#<seq>` tail to comment (seq injected by recorder) | Format extension; prefix-compatible with `ParseEntryDecisionId` (Sections 4.2, 23.3); no other behavior change |
| `Trading/TradeManager.mqh` | Replace `m_submittedIds[]` dedup with recorder check+record; capture full `MqlTradeResult` into ledger RESULT; classify uncertain retcodes as `UNKNOWN_SUBMISSION` | Same "one send per intent" semantics, now durable; add-only; no strategy logic touched |
| `Portfolio/SymbolContext.mqh` | Wire recorder init (runId/buildTag pass-through), startup gate call, shutdown settle | Wiring only; mirrors the existing telemetry wiring pattern |
| `SuperCents_X.mq5` (or `Core/Engine.mqh`) | Init/shutdown hook if not expressible via SymbolContext | Wiring only |

### 15.3 Explicitly NOT modified (zero-touch list)

`ExecutionPlan`/`ExecutionPlanner.mqh`, `EntryDecision`/`EntryDecisionEngine.mqh`,
`TradeCandidate`/`TradeCandidateBuilder.mqh`, `PositionLifecycleManager.mqh`,
all Settlement files, all Telemetry files (v6 frozen), TT01 (`TT01_Validate.ps1`,
`TT01_Validators.ps1`, baselines), ED01, Sprint 24 files, B25-01/B25-02
implementation files, frozen evidence artifacts (Section 14 of the assessment).

### 15.4 Scope guard

The comment tail is the only change to any broker-visible artifact. Telemetry
rows, TT01 outputs, ED01 outputs, and all frozen evidence stay byte-identical.

---

## 16. Invariants

1. Same `executionId` never produces more than one unintended `OrderSend`.
2. `requested*` values are never reported as fill values; fills come only from
   broker-confirmed sources.
3. Ledger is append-only; no in-place mutation; no silent truncation; no silent
   row skipping.
4. Counter reserved + flushed before send; ledger `INTENT`/`SUBMITTED` flushed
   before send.
5. No new send while an `UNKNOWN_SUBMISSION`/`RESOLVE_AMBIGUOUS` exists for the
   symbol, and no send while the ledger is `DEGRADED` or the counter corrupt.
6. Broker comment ≤ 31 chars; prefix-compatible with `ParseEntryDecisionId`;
   GR02A behavior byte-identical.
7. Terminal states never re-enter the send path.
8. Telemetry `decisionId` semantics and schema unchanged (v6 frozen); the only
   link is the ledger's `(executionId, decisionId)` columns.
9. `EntryMode=2` REPLAY path, TT01, ED01, and all frozen evidence untouched.
10. No `OnTradeTransaction` in this scope.
11. No retry/requote/partial-fill-continuation policy (strategy-sensitive,
    default OFF) — legacy behavior unchanged.
12. Settlement unchanged; interface-only contract.
13. Reconciliation never guesses: `AMBIGUOUS` blocks rather than resolves.
14. Counter monotonicity asserted at every allocation; rollback/stale-copy
    violation → `BLOCKED` global.
15. `REJECTED`/`CANCELLED` are zero-fill terminals; any terminal condition with
    fills > 0 → `TERMINAL_PARTIAL`; `PARTIALLY_FILLED` is never terminal.
16. Torn-tail discard never hides an executed intent (Section 7.6 proof);
    interior corruption → `DEGRADED` → blocked.
17. Broker comment tail stripping/mutation is tolerated; correlation falls back
    through the hierarchy (Section 9.3), never comment-only.

---

## 17. Test Matrix (validation specification)

Each scenario is executed in the separate execsim harness (never TT01/ED01).
Columns: initial state / broker state / ledger state → expected transition /
invariant exercised / expected final state.

| # | Scenario | Initial state | Broker state | Ledger state | Expected transition | Invariant | Expected final state |
|---|---|---|---|---|---|---|---|
| A | Normal success | INTENT | accepts, fills at ask+2p | INTENT, SUBMITTED | SUBMITTED → ACCEPTED → FILLED | 2, 4 | FILLED with real acceptedPrice/Volume, order+deal tickets |
| B | Rejected order | INTENT | rejects (NO_MONEY) | INTENT, SUBMITTED | → REJECTED (zero fills, terminal) | 7, 15 | REJECTED; no retry; no duplicate |
| C | Timeout | SUBMITTED | actually filled | SUBMITTED | → UNKNOWN_SUBMISSION → RECONCILE → FOUND → FILLED | 1, 5 | FILLED via history; dedup holds |
| D | Connection loss | SUBMITTED | order not received | SUBMITTED | → UNKNOWN_SUBMISSION → NOT_FOUND → RESOLVED_NOT_FOUND | 5, 13 | terminal; no duplicate order |
| E | Accepted but result lost | SUBMITTED | order placed, fills | SUBMITTED | → UNKNOWN → FOUND → FILLED (history) | 2 | FILLED with history truth |
| F | EA restart after submission | SUBMITTED | order exists | SUBMITTED (durable) | startup reconcile → FOUND → FILLED | 1, 5, 7 | index rebuilt; FILLED; send path refuses re-issue |
| G | Terminal restart after submission | SUBMITTED | order exists | SUBMITTED (durable) | same as F; counter intact | 1, 5, 14 | FILLED; counter continuity proven |
| H | Duplicate execution attempt | FILLED (or REJECTED) | — | FILLED | send attempt refused by dedup check | 1 | no second OrderSend; log + block proof |
| I | Multiple deals / partial fill (active) | ACCEPTED | 2 fills (0.5 + 0.3) on 1.0-lot order; order still active | RESULT + DEAL_IN ×2 | → PARTIALLY_FILLED (cumulative 0.8, remaining 0.2) | 2, 15 | PARTIALLY_FILLED (non-terminal); cumulative truth stamped |
| J | Reconciliation (mutated/stripped comment) | UNKNOWN_SUBMISSION | order exists; comment tail stripped/mutated | SUBMITTED | ticket path → FOUND → FILLED (or order/deal fallback) | 13, 17 | FILLED; mutation tolerated |
| K | Broker state mismatch | INTENT | no trace, but ledger says SUBMITTED | SUBMITTED | NOT_FOUND → RESOLVED_NOT_ISSUED | 13 | terminal; symbol unblocked after resolution |
| L | Ledger corruption | — | — | DEGRADED | block all sends; report | 3, 5, 16 | BLOCKED; no sends; corrupt row identified |
| M | Deterministic recovery | SUBMITTED × n | mixed found/not-found | durable | replay → reconcile each → unblock per symbol | 5, 6 | per-symbol unblock only after all terminals resolved |
| N | Terminal partial (remainder) | PARTIALLY_FILLED | order canceled with 0.2-lot remainder | DEAL_IN (cumulative 0.8) | → TERMINAL_PARTIAL (terminalReason=CANCELED, remaining 0.2) | 11, 15 | TERMINAL_PARTIAL; no remainder re-issue |

Additional compatibility tests (Section 23.3 proof, executable):

1. `ParseEntryDecisionId("SCX-BUY-P123#456") == 123`
2. `ParseEntryDecisionId("SCX-SELL-P123#456") == 123`
3. `ParseEntryDecisionId("SCX-BUY-P123") == 123` (legacy, unchanged)
4. `ParseEntryDecisionId("SCX-BUY-P123#456 [broker]") == 123` (appended text)
5. `ParseEntryDecisionId("SCX-BUY-P123") == 123` (tail stripped by broker)
6. Comment length `StringLen("SCX-SELL-P2147483647#99999999") ≤ 31` (worst case = 29)
7. Counter reserve-before-use crash-window tests (Section 23.2) via
   harness-simulated crash points 1-10.
8. Monotonicity violation test: counter restored to an older value → `BLOCKED`
   global, no sends.

---

## 18. Demo Safety Gates (objective acceptance criteria)

A controlled demo of the LEGACY execution path is authorized **only** when all
of the following are objectively demonstrated in the execsim harness (and each
is individually gated in Section 21):

| # | Criterion | Proof artifact |
|---|---|---|
| G1 | Durable dedup proven | Scenarios F, G, H pass: no duplicate order across EA/terminal restart and duplicate attempts |
| G2 | Unknown outcomes reconciled | Scenarios C, D, E, J pass: every UNKNOWN resolves to an evidence-based state with broker evidence |
| G3 | Actual fill captured | Scenario A + I: `acceptedPrice/Volume` and per-deal fills recorded from broker-confirmed sources; requested ≠ filled demonstrated |
| G4 | Restart recovery proven | Scenarios F, G, M pass: startup gate, index rebuild, per-symbol unblock |
| G5 | Partial fills modeled | Scenarios I, N pass: cumulative/remaining recorded; PARTIALLY_FILLED never terminal; TERMINAL_PARTIAL used for terminal remainder; no re-issue |
| G6 | Ledger durable | Scenarios L + counter-loss + monotonicity test: DEGRADED/blocks; counter rebuild; no silent skips; rollback detected |
| G7 | No duplicate orders | All scenarios: invariant 1 holds; broker order count == intent count for terminal intents |
| G8 | Broker mismatch handled | Scenarios K, J + comment-mutation: mismatch resolves or blocks; never guesses |

No real/live account authorization is implied by this gate list; a demo gate
pass authorizes only the controlled demo on the demo account under explicit
supervision.

---

## 19. Risks

| # | Risk | Mitigation |
|---|---|---|
| R1 | Counter file loss/corruption | Rebuild from ledger max(seq)+1; both lost → BLOCKED global (Section 7.4) |
| R2 | Broker mutates/replaces comments | Correlation hierarchy (Section 4.3); comment never sole matcher |
| R3 | History access failure at recovery | BLOCKED per symbol; surfaced in health monitor; no guessing |
| R4 | Broker-side fill delay → false NOT_FOUND | ε/δ windows (5 s / 60 s) + per-symbol block until resolution; false resolution only after window expiry — documented, terminal, safe (no re-issue anyway) |
| R5 | Tester `FILE_COMMON` staging (B25-01 root cause) | Per-run seeding in tester; harness archives ledger like telemetry; cross-run durability is a demo/live concern only |
| R6 | Ledger growth | ≈ 8-10 events/execution; daily rotation; no EA-side deletion |
| R7 | Send-path regression in LEGACY mode | TT01 unaffected (EntryMode=2, no sends); execsim gate per sub-phase; rollback per Section 20 |
| R8 | Position gate interplay | Portfolio gate unchanged; dedup is orthogonal (per-intent), documented in Section 8.2 |
| R9 | Comment truncation by terminal/server | Budget ≤ 26 chars (design) + width guard on seq (Section 4.2, 7.4) |
| R10 | Partial-fill remainder silently lost | Remainder + terminalReason recorded and reported; no re-issue (policy) — visible in run report |
| R11 | Counter rollback / stale copy restored | Monotonicity assert at allocation → BLOCKED global (Section 7.4, Invariant 14) |
| R12 | Torn tail row (crash during append) | Defined discard rule with proof it cannot hide an executed intent (Section 7.6, Invariant 16) |
| R13 | Broker strips `#<seq>` tail | Degrades to legacy comment (still parses); correlation falls back to ticket/order/deal/position paths (Sections 9.3, 17-J) |
| R14 | Broker prefixes comment with earlier `-P` | Pre-existing parser exposure, unchanged; mitigated by correlation hierarchy, not the frozen parser (Section 4.2) |
| R15 | False partial-fill detection (volume matcher) | Deal-path matcher uses `volume ≤ V + lot step` so partial fills match (Section 9.3, correction §23.4) |

---

## 20. Rollback Strategy

| Level | Action | Safety |
|---|---|---|
| Sub-phase (A–F) | Revert the sub-phase's file changes (Section 15 files), delete/quarantine `Common\Files\Execution\*` artifacts | Each sub-phase lands behind its own gate (Section 21); TT01/ED01/telemetry never touched |
| Whole feature | Revert to `3c2f02a` + remove `#<seq>` comment tail (legacy format restores GR02A parse path immediately) | Comment format is the only broker-visible change; reverting it restores the exact pre-design behavior |
| Runtime tripwire | Any BLOCKED/DEGRADED event = halt new sends for affected symbol (or globally); run report flags it | Fail-safe by construction, no rollback needed for the halted path |

Rollback never requires touching TT01, ED01, telemetry, baselines, or frozen
evidence, because this design never modifies them.

---

## 21. Implementation Sequence

### 21.1 Dependency proof

Constraints between sub-phases:

- **A (identity) → C (ledger)**: the ledger's primary key is `executionId`,
  which exists only after A; the counter protocol (A) is also the ledger's
  ordering authority.
- **A → B (capture)**: capture keys RESULT events by `executionId`.
- **C → B**: the captured `MqlTradeResult` must be written to a durable medium
  to become truth (a log-only capture would reintroduce D5); B therefore lands
  after C.
- **C → D (dedup)**: durable dedup is a ledger-state query; no ledger → no
  durable dedup (the in-memory array stays).
- **B, C → E (reconciliation)**: UNKNOWN classification needs B's retcode
  capture; resolution writes RECONCILED events to C.
- **E → F (restart recovery)**: recovery is the startup orchestration of E's
  reconciler over C's replay; without E there is nothing to run at startup.

DAG: `A → C → {B, D} → E → F`, with `B` before `D` preferred (fill truth
delivers P0-2 value earliest; both edit the same send site, so sequencing them
together minimizes rework).

### 21.2 Ordered sub-phases and gates

| # | Sub-phase | Deliverable | Gate (must pass before next) |
|---|---|---|---|
| B25-03A | Canonical execution identity | `ExecutionIdentity.mqh` + comment tail + counter | Unit: generation/parse round-trip, legacy parse compat (`P123#45→123`), length ≤ 31, reserve-before-use crash-window sim, monotonicity assert |
| B25-03C | Execution ledger | `ExecutionLedger.mqh` + `ExecutionStateTypes.mqh` | Unit: append/idempotent replay/rotation/DEGRADED/torn-tail; corruption tests (L) |
| B25-03B | Execution result capture | `ExecutionRecorder.mqh` + TradeManager send-site changes | Harness: scenarios A, B, C, E; requested≠filled asserted |
| B25-03D | Durable deduplication | Dedup check swap + startup broker probe | Harness: scenarios F, G, H; broker order count == intent count |
| B25-03E | Unknown-outcome reconciliation | `ExecutionReconciler.mqh` | Harness: scenarios C, D, E, J, K; no unresolved UNKNOWN at end |
| B25-03F | Restart recovery | Startup gate + per-symbol unblock + probe | Harness: scenarios F, G, M, N; full demo-gate checklist (G1-G8) |

Each gate is an objective, scripted check in `Tools/25B/execsim/` with a
recorded pass report (matching the TT01/ED01 gate discipline). **No sub-phase
starts until the previous gate passes.**

### 21.3 Authorization model

- This document authorizes **nothing executable**.
- Each sub-phase requires its own implementation authorization.
- Commit and push remain separately unauthorized for all sub-phases.
- The controlled demo requires the full G1–G8 gate pass **and** a separate demo
  authorization; no live authorization is implied.

---

## 22. Explicit Authorization Request

For the record — what this design phase requests:

1. **Implementation authorization for B25-03A** (canonical execution identity:
   `ExecutionIdentity.mqh`, comment tail, durable counter), the foundational
   sub-phase on which all others depend (Section 21.2), with its gate executed
   before any further sub-phase is authorized.
2. **No commit, no push, no demo, no live trading** is requested or implied by
   this design. Commit/push/demo authorizations are separate senior decisions.
3. **Scope confirmation**: the design stays within SAFE INFRASTRUCTURE
   (Sections 14-15); any proposed deviation into STRATEGY-SENSITIVE territory
   (retry, requote, partial-fill continuation, settlement, telemetry schema)
   will be reported as a STOP conflict rather than implemented.

---

## 23. Senior Design Corrections

Source: SENIOR GATE review of `docs/Sprint25B_B25-03_ExecutionTruth_Design.md`
(2026-08-15) — DESIGN ACCEPTED WITH REQUIRED CORRECTIONS. This section records
each correction, its proof, and any additional ambiguity discovered during the
review. The 22-section structure above is preserved; Sections 5-11, 16, 17, and
19 carry the corrected text.

### 23.1 Partial-fill correction

**Problem found**: `PARTIALLY_FILLED` was defined as both an intermediate
execution state and a terminal broker state ("PARTIALLY_FILLED ... terminal
(remainder recorded)"), conflating "order still active with partial fills" and
"order terminal with an unfilled remainder".

**Correction applied**:
- `ACCEPTED` = broker-accepted order with zero deals (situation A).
- `PARTIALLY_FILLED` = ≥1 partial deals while the order remains **active**,
  cumulative < requested (situation B) — **intermediate, never terminal**.
- `FILLED` = cumulative == requested (situation C, terminal).
- `TERMINAL_PARTIAL` = order terminal with remaining volume > 0 (situation D,
  terminal), carrying `terminalReason` and `remainingVolume`.
- `REJECTED`/`CANCELLED` are zero-fill terminals only (Invariant 15).

**Truth-without-policy**: the ledger represents cumulative execution truth
(`filledVolume = Σ DEAL_IN.volume`, `remainingVolume = requested − filled`,
`orderState` captured per observation) without deciding what the strategy does
with the remainder. Retry, remainder re-submission, and partial-fill
continuation remain STRATEGY-SENSITIVE and outside scope (Invariant 11).

**Artifacts updated**: §5.2 (new fill-decomposition table), §5.3 (derived
columns), §6 (state machine + `TERMINAL_PARTIAL`), §7.3/§7.5 (DEAL_IN carries
`orderState`; schema columns), §11 (rewritten), §16 (invariants 15, 17),
§17 (scenarios I, N — scenario I was also arithmetically wrong, see §23.4),
§19 (R10, R15).

### 23.2 Execution identity crash-window proof

Identity lifecycle (allocation = reserve-before-use on the durable counter):

```
DECISION → EXECUTION INTENT → executionId allocation → INTENT ledger append (flush)
→ SUBMITTED ledger append (flush) → OrderSend → RESULT (capture + flush)
→ DEAL/FILL discovery
```

**Lemma (broker trace ⇒ complete ledger rows)**: an `OrderSend` is only invoked
after the SUBMITTED append has been flushed, and the SUBMITTED append only
occurs after the INTENT append has been flushed (sequential appends in a single
file). Therefore **any order that reaches the broker has complete, durable
INTENT + SUBMITTED rows** in the ledger. Recovery can always find the intent of
any broker-executed order; a torn tail can never hide an executed intent
(§7.6).

| # | Crash point | executionId reused? | Two intents share the id? | Broker execution without ledger trace? | Accidental resubmit? | Recovered state |
|---|---|---|---|---|---|---|
| 1 | Before seq allocation | n/a — no id exists | no (allocation never entered) | no (nothing sent) | no | nothing to recover; counter untouched |
| 2 | After allocation, before INTENT append | no — id consumed; counter advanced (gap only) | no (single allocation path; the id is never re-issued) | no (send requires INTENT+SUBMITTED flush, not yet done) | no (no ledger row; no send path exists for it) | seq gap only; no intent; index unaffected |
| 3 | After INTENT flush, before SUBMITTED | no | no | no (send requires SUBMITTED flush) | no (ledger shows INTENT; pre-check blocks re-issue) | INTENT → no broker trace → RESOLVED_NOT_ISSUED |
| 4 | After SUBMITTED flush, before OrderSend | no | no | no (send not invoked) | no (ledger SUBMITTED; pre-check blocks) | SUBMITTED → no broker trace → RESOLVED_NOT_ISSUED |
| 5 | Immediately before OrderSend | no | no | no | no | identical to #4 (indistinguishable window; SUBMITTED flush precedes the call) |
| 6 | During OrderSend (EA/terminal crash mid-call; `OrderSend` is synchronous) | no | no | possible — request may or may not have reached the broker | no (SUBMITTED durable; reconcile first; no re-issue) | SUBMITTED → reconcile → FOUND (evidence state) or NOT_FOUND → terminal |
| 7 | After OrderSend returns, before RESULT capture | no | no | possible — broker executed; result lost with the process memory | no (SUBMITTED durable; comment path recovers via `#<seq>` token) | SUBMITTED → reconcile → FOUND via ORDER_COMMENT prefix → evidence state |
| 8 | After RESULT capture, before RESULT flush | no | no | possible — broker executed; RESULT row torn or absent | no (SUBMITTED durable, earlier in file order; torn-tail rule §7.6) | SUBMITTED → reconcile → evidence state |
| 9 | After RESULT flush, before deal discovery | no | no | no (trace durable) | no (dedup check sees the durable state) | RESULT replayed; deal discovery re-runs from broker history (truth) |
| 10 | During restart recovery | no — replay is idempotent; RECONCILED events idempotent by (executionId, resolution) | no | no | no — no sends until the gate passes (all non-terminal resolved) | recovery re-runs from scratch to the same result |

**Identity invariants (preserved)**:

- **SAME EXECUTION INTENT → SAME executionId**: within a run, the recorder's
  allocation map keyed by `(runId, entryDecisionId)` is created at first
  allocation and consulted by the dedup pre-check; a second send attempt for
  the same intent hits the map and the durable INTENT/SUBMITTED row → refused,
  never re-allocated. Across a restart, "the same intent" is redefined by the
  ledger: the prior executionId is terminal (or resolved at startup gate), and
  the regenerated strategy decision is a new intent with a new id. Strategy
  identity semantics (`candidateId`/`entryDecisionId` per-run, telemetry
  `decisionId` per-run) are untouched.
- **DIFFERENT EXECUTION INTENTS → DIFFERENT executionIds**: `seq` is strictly
  increasing and never reused (append-only counter; rebuild-from-max preserves
  monotonicity; the monotonicity assert makes rollback a `BLOCKED` event
  instead of a collision). Within a run the map guarantees one id per
  `(runId, entryDecisionId)`; across runs the `runId` component differs. Two
  different intents cannot share `seq`, hence cannot share `executionId`.

**Residual no-trace case (operational, documented)**: external deletion of
both the ledger and the counter (operator error, not a crash window) is handled
as `BLOCKED` global at startup — no auto-recovery, no guessing; the operator
confirms via the terminal UI that no EA-magic orders/positions exist, then
resets. The startup broker probe (Section 8.2, layer 2) additionally reports
any EA-magic broker trace found without a ledger counterpart.

### 23.3 Broker-comment compatibility proof

**Complete `SCX-*` consumer inventory (verified by source search, 2026-08-15)**:

| Consumer | File:line | Role | Impact of `#<seq>` tail |
|---|---|---|---|
| Comment producer (only) | `Trading/TradeRequestBuilder.mqh:59,65` | Writes `SCX-BUY-P<id>` / `SCX-SELL-P<id>` | Tail appended (the only writer) |
| Comment parser (only) | `Entry/PositionLifecycleManager.mqh:597-609` | `ParseEntryDecisionId` | **No change needed** (proof below) |
| Parser call site (only) | `Entry/PositionLifecycleManager.mqh:237` | EVENT_POSITION_CLOSED: parses `pos.comment` → `EventData.entryDecisionId` | Unchanged behavior |
| Raw carriers (no parsing) | `Entry/PositionInfo.mqh:48`, `Entry/PendingOrderInfo.mqh:43`, `Entry/PositionManager.mqh:123,151,179,238,263` | Pass `POSITION_COMMENT`/`ORDER_COMMENT` through structs | Neutral (pass-through) |
| Actual-outcome settler | `Telemetry/ActualOutcomeSettler.mqh:10-19,45-96` | Consumes the **parsed** `entryDecisionId` from the event, not the comment; maps candidateId→decisionId in memory | Neutral (input unchanged: 123) |
| Telemetry rows | `Telemetry/TelemetryRowBuilder.mqh:65,131` | No comment columns exist (D8) | Unaffected |
| Chart-object names | `Visualization/ChartObjectNames.mqh`, all `*Renderer.mqh`, `VisualDiagnostic.mqh:144` | `SCX_*` underscore namespace for chart objects | Unrelated namespace (`SCX-BUY-P` vs `SCX_...`); no overlap |
| Terminal-side consumers | `SuperCents_X.mq5`, TradeManager, PositionLifecycleManager position rebuild (:219-220) | Read position comment via PositionInfo/PositionManager | Pass-through; parse unchanged |
| TT01 / ED01 validators | PowerShell/Python validators | Consume telemetry CSVs; **never** order comments; EntryMode=2 runs produce no orders/comments | Unaffected |

**Parse proof (no parser modification)**:

```
ParseEntryDecisionId("SCX-BUY-P123#456"):
  1. StringFind(comment, "-P")        -> index of the only "-P" substring ("BUY-P").
                                        "SCX-BUY-P..." contains no earlier "-P".
  2. StringSubstr(comment, ppos + 2)  -> "123#456"
  3. StringToInteger("123#456")       -> MQL5 stops at the first non-digit: 123
=> returns 123

ParseEntryDecisionId("SCX-SELL-P123#456") -> same walk, "SELL-P" -> "123#456" -> 123
ParseEntryDecisionId("SCX-BUY-P123")       -> "123" -> 123        (legacy, unchanged)
ParseEntryDecisionId("SCX-BUY-P123#456 [broker]") -> "123#456 [broker]" -> 123 (appended text)
ParseEntryDecisionId("SCX-BUY-P123")       -> 123                 (tail stripped by broker)
```

**Compatibility statement**: `SCX-BUY-P123` and `SCX-BUY-P123#456` are
indistinguishable to every existing consumer — the parser, the EVENT_POSITION_CLOSED
flow, GR02A, settlement (which reads the parsed id / event data), telemetry
(no comment columns), TT01 and ED01 (no comment consumption). No parser, no
settlement, no telemetry, no TT01 change is required. The `#` and digits after
it are inert for `StringToInteger` and are never re-parsed by any other code.
(One pre-existing, unchanged exposure: a broker prefixing an earlier `-P` would
affect the legacy format identically — §4.2, R14.)

### 23.4 Additional ambiguities discovered and corrected

1. **Scenario I arithmetic error** (§17): "2 × 0.5-lot fills on 1.0-lot order →
   PARTIALLY_FILLED, cumulative=1.0" — 2 × 0.5 = 1.0 is a **complete** fill.
   Corrected to 0.5 + 0.3 = cumulative 0.8 (order active → `PARTIALLY_FILLED`)
   and extended with scenario N (order canceled with 0.2 remainder →
   `TERMINAL_PARTIAL`).
2. **Deal-path volume matcher** (§9.3 step 4): an equality/±-step match against
   the *requested* volume would miss partial fills (deal volume is a fraction
   of the requested). Corrected to `volume ≤ V + lot step`.
3. **Layer-2 broker probe** (§8.2): originally specified per-send; after
   counter loss the old token is unknowable, so a per-send probe cannot work
   and adds unbounded cost. Corrected to a **startup-scoped** probe
   (magic + `SCX-` prefix + recovery window); per-send safety rests on the
   ledger check and the position gate.
4. **Generic `RESOLVED_FOUND` state** (§6/§9.1): masked the evidence-based
   terminal states. Corrected: reconciliation transitions to the concrete
   evidence-based state (`ACCEPTED`/`PARTIALLY_FILLED`/`FILLED`/
   `TERMINAL_PARTIAL`); `RESOLVED_NOT_FOUND`/`RESOLVE_AMBIGUOUS` remain the
   only generic resolutions.
5. **Torn-tail handling** (§7.6): was unspecified. Defined with the proof that
   a torn final line cannot hide an executed intent (§23.2 lemma); interior
   corruption → DEGRADED.
6. **Counter rollback / stale copy** (§7.4, R11): restored counter could reuse
   seq values. Corrected with a monotonicity assert at allocation → BLOCKED.
7. **Tail strip by broker** (§3.3, §9.3, R13): `#<seq>` may be stripped.
   Corrected: degrades to legacy comment (parses identically); correlation
   falls back through ticket/order/deal/position paths; ambiguity still blocks.
8. **Derived fill columns** (§5.3): added `filledVolume`, `remainingVolume`,
   `orderState`, `terminalReason` so cumulative truth is representable without
   embedding strategy policy.

### 23.5 Implementation readiness

The design is **implementation-ready at the design level**: all three required
corrections are applied with proofs, all discovered ambiguities are resolved,
the 22-section structure is preserved, and no STRATEGY-SENSITIVE behavior is
introduced. Readiness does **not** imply authorization: implementation,
commit, push, and the controlled demo each require separate senior
authorization (Section 21.3), starting with B25-03A.

---

## Final Status Block

```
B25-03 DESIGN CORRECTION:
COMPLETE

IMPLEMENTATION READINESS:
READY

IMPLEMENTATION:
NOT AUTHORIZED

COMMIT:
NOT AUTHORIZED

PUSH:
NOT AUTHORIZED

NEXT SENIOR DECISION:
authorize B25-03A OR require further design correction

STOP.
```
