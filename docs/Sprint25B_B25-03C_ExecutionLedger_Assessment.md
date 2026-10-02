# Sprint 25B — B25-03C Execution Ledger / Reconciliation (Assessment)

- Date: 2026-08-15
- Type: READ-ONLY assessment. No implementation. No commit. No push.
- Baselines: B25-03A `67c58d0` (execution identity, frozen), B25-03B `a36ea238` (execution result truth, frozen), GitHub main `a36ea238`.
- Mandate: B25-03C ASSESSMENT + DESIGN authorized; implementation NOT authorized.
- Method: repository audit + threat analysis. No production file was modified. No test was added. No run was executed.
- Updated 2026-08-15 (senior design corrections, docs only): the design's sequence model is corrected to keep `executionSeq` (identity, gaps legal — reserve-before-use) and `eventSeq` (per-event ordering, contiguous by construction) distinct; invariants and acceptance gates updated accordingly. See `docs/Sprint25B_B25-03C_ExecutionLedger_Design.md` Phase 3 / Phase 17 / Phase 20. The assessment findings below are unaffected (they concern current-state RAM-only storage, not the ledger's internal sequence model).

---

## 1. Execution State Trace (verified in code)

```
ExecutionPlanner.mqh:214        plan.entryDecisionId = decision.candidateId   (run-local int, restarts each run)
SymbolContext.mqh:603           m_tradeExecutionManager.SetExecutionEnabled(m_entryMode == ENTRY_MODE_LEGACY)
TradeManager.mqh:128-216        1. m_planner.GetPlanCount()/GetPlan(i, plan)
                                2. plan.status != PLAN_EXECUTABLE -> skip
                                3. IsAlreadySubmitted(planId) -> m_submittedIds[] (RAM) [dedup]
                                4. TradeValidation.ValidateAll(...)             [RAM]
                                5. TradeRequestBuilder.Build(...) -> comment "SCX-BUY-P<id>"/"SCX-SELL-P<id>" (legacy, no #seq)
                                6. OrderSend(request, tradeResult)
                                7. CaptureExecutionTruth(request, tradeResult, planId)  [B25-03B]
                                8. outcome branch -> LogOrderSent / LogOrderFailed (journal only)
                                9. RecordSubmitted(planId); m_totalSubmitted++   (RAM)
TradeRequestBuilder.mqh:59/65   request.comment = "SCX-BUY-P%d" / "SCX-SELL-P%d"
Broker                          position created with comment; deal history on broker side
PositionLifecycleManager.mqh:237/597  ParseEntryDecisionId(position.comment) -> candidateId (RAM context)
PositionLifecycleManager.mqh:336/346  on close -> EVENT_POSITION_CLOSED {entryDecisionId, profit}
ActualOutcomeSettler.mqh        Register(candidateId -> telemetry decisionId) pairs (RAM)
                                HandleEvent -> ApplyActualOutcome(decisionId, WIN/LOSS/BE)
TelemetryCollector.mqh:277      runId = "RUN-<buildTag>-<GetTickCount>" (self-generated, RAM)
TelemetryCollector.mqh:308      decisionId = ++m_runId (run-local, RAM); CSV flush at Shutdown
ExecutionIdentity.mqh (FROZEN)  durable counter file "Execution\execution_seq.dat" (FILE_COMMON), checksummed,
                                reserve-before-use, EX-<runId>-<seq>, BuildComment SCX-<side>-P<id>#<seq>,
                                SetMonotonicFloor hook. NOT wired into the send path (by design, B25-03A).
```

## 2. Inventory: State That Exists ONLY in RAM Today

| State | Owner | Current storage | Survives EA/terminal restart? | Authority |
|---|---|---|---|---|
| Submitted/dedup set | CTradeManager `m_submittedIds[]`, `m_submittedCount` (:29-30) | RAM array | NO | planId (candidateId, run-local) |
| Submitted counter | `m_totalSubmitted` (:34) | RAM | NO | — |
| Succeeded/failed/duplicate tallies | `m_totalSucceeded`/`m_totalFailed`/`m_totalDuplicates` (:35-36) | RAM | NO | — |
| Avg fill price accumulator | `m_totalFilledPrice` (:37) | RAM | NO | — |
| Accepted state / order ticket | only the transient `ORDER-SENT Plan=... Ticket=...` journal line | journal text | NO (journal is not structured state) | broker `tradeResult.order` |
| Deal ticket (synchronous) | `ExecutionTruthRecord.dealTicket` (in-memory, then journal) | RAM | NO | broker `tradeResult.deal` |
| Filled volume (cumulative, multi-deal) | not tracked (only single synchronous `filledVolume`) | — | NO | — |
| Requested volume | plan / `TradeRequestBuilder` request | RAM | NO | plan |
| Remaining volume | not tracked at all | — | NO | — |
| Settlement state (open-position contexts) | `CPositionLifecycleManager m_contexts[]` | RAM | NO | broker position ticket + comment |
| Decision/execution correlation | candidateId -> telemetry decisionId pairs (`ActualOutcomeSettler`), candidateId -> position via comment | RAM + broker comment | NO (RAM) / broker comment partial | comment `SCX-*-P<id>` (no seq) |
| Telemetry runId / decisionId | `TelemetryCollector` (flushed to CSV at Shutdown only) | RAM until flush | NO (until flush; new runId after restart) | self-generated |
| Execution sequence counter | `CExecutionIdentity` counter file (B25-03A) | FILE_COMMON file | YES (durable, checksummed) | reserved-before-use; NOT wired to sends |

**Finding 1 (durability):** every execution-state decision the EA makes is RAM-only. A restart at any point resets dedup, tallies, and correlation.

**Finding 2 (dedup identity):** the current dedup key is `planId == candidateId`, a run-local counter (`ExecutionPlanner.mqh:214`). It is meaningless across restarts: after a restart, a regenerated plan can reuse the same candidateId for a different market moment, or a different candidateId for the same moment. Restart-safe dedup therefore CANNOT be built on candidateId — the durable authority must be `executionId` (EX-`<runId>`-`<seq>`, B25-03A frozen). Equivalence between two executions is NEVER inferred from candidateId alone: a regenerated plan after restart receives a NEW executionId (Run 1 candidate 5 -> EX-RUN1-101; Run 2 candidate 5 -> EX-RUN2-102), and the only cross-restart duplicate defense for that case is broker-side reconciliation before send — with the caveat that while the broker comment carries only legacy `SCX-*-P<id>` (no `#<seq>` tail), a missing executionId match cannot prove non-existence, so insufficient correlation must yield AMBIGUOUS/BLOCKED, never NOT_FOUND (design Phases 6/7).

**Finding 3 (correlation fragility):** the broker-side correlation today is the legacy comment `SCX-*-P<id>` (`TradeRequestBuilder.mqh:59/65`). `id` is a candidateId — not unique across runs, not unique across symbols' sessions. Two runs that both send for candidate 5 produce positions with identical comments; settlement cannot distinguish them. This is exactly the gap the `#<seq>` tail (B25-03A `BuildComment`, not yet wired) closes.

**Finding 4 (crash window exists TODAY):** a crash between `OrderSend` (:180) and `RecordSubmitted` (:214), followed by a restart, yields a re-generated plan, an empty dedup set, and a second `OrderSend` with identical intent. With the synchronous `DONE`+deal path, the first order is already a position on the broker -> the duplicate is a real second position. Today this is BLOCKED-by-design only because nothing about restart safety exists; the risk is unaddressed, not mitigated.

**Finding 5 (truth is available but not durable):** B25-03B's `ExecutionTruthRecord` (all broker-confirmed fields) is the exact payload an execution ledger needs, and its write-once convention (never mutated; new deals attach as new entries) is ledger-shaped. No re-derivation of truth is required — B25-03C only needs to persist the frozen record structure as events.

## 3. Threat Model (current state vs. designed ledger)

Classification: KNOWN (fact known), UNKNOWN (fact unknowable from local state), RECOVERABLE (can be resolved safely), AMBIGUOUS (cannot be resolved without guessing), BLOCKED (no safe action).

| # | Failure | Current state | With designed ledger |
|---|---|---|---|
| 1 | EA restart | All RAM state lost; duplicate-send window (Finding 4) | RECOVERABLE via ledger replay + broker inspection; never blind re-send |
| 2 | Terminal restart | Same as 1; journal not structured state | RECOVERABLE (ledger is a FILE_COMMON file, survives) |
| 3 | MT5 crash | Same as 1 | RECOVERABLE; torn-tail handling required (Phase 10) |
| 4 | OS crash | Same as 1 | RECOVERABLE if per-event flush discipline holds; else torn tail -> RECOVERABLE (truncate) |
| 5 | Power loss | Same as 1 | RECOVERABLE (same as 4); unflushed event may be lost -> the event is either fully written (checksum ok) or truncated (detected) — never partially trusted |
| 6 | Broker disconnect | OrderSend returns CONNECTION (truth: CONNECTION_ERROR, outcome UNKNOWN) | UNKNOWN recorded durably; broker inspection on reconnect |
| 7 | Network timeout | OrderSend returns TIMEOUT (truth: TIMEOUT, outcome UNKNOWN) | UNKNOWN recorded durably; deal may still exist -> OTT/history scan resolves |
| 8 | OrderSend uncertain result | journal line only | UNKNOWN event; reconcile later; no fabricated outcome |
| 9 | Accepted order, no deal | `ORDER-SENT` line, nothing else | ACCEPTED event; OTT/DEAL events attach later; unresolved stays UNKNOWN -> RECONCILING |
| 10 | Partial fill | single synchronous `filledVolume`; cumulative not tracked | per-deal DEAL_IN events; cumulative sum; remainingVolume invariant |
| 11 | Multiple deals | not tracked | one DEAL_IN per unique deal ticket; dedup by dealTicket |
| 12 | Deal arrives after timeout | invisible | DEAL_IN arrives via OTT/history; state ACCEPTED/UNKNOWN -> FILLED only with deal evidence |
| 13 | Duplicate callback/event | not applicable (no event handling) | idempotent: DEAL_IN keyed by dealTicket; transition legality enforced |
| 14 | Ledger write failure | n/a | BLOCK execution (fail-safe: do not send without durably recorded INTENT); log CORRUPT |
| 15 | Torn/truncated ledger tail | n/a | RECOVERABLE: truncate to last checksummed record, record truncation event; mid-file corruption -> BLOCKED |
| 16 | Counter corruption | B25-03A refuses allocation (COUNTER_CORRUPT) | same, plus monotonic floor from ledger high-water (SetMonotonicFloor) prevents rollback reuse |
| 17 | Disk full | n/a | INTENT write fails -> execution BLOCKED before OrderSend (no blind send) |
| 18 | Concurrent writer / re-entry | n/a | single-writer design: ledger writes only from the execution path; FILE_SHARE_READ for readers; re-entry guarded by state machine |

## 4. OnTradeTransaction Assessment (Phase 12 preview)

- **Recommended role: B — secondary event source (record-only observer).** Primary remains the synchronous `MqlTradeResult` truth (B25-03B), which carries `request_id`, `order`, `deal`, price/volume. OTT cannot be primary because (a) it has no `executionId`; correlation must be derived (request_id match or comment match), (b) it fires for every transaction on the symbol, and (c) its ordering is not guaranteed relative to the synchronous result.
- **What OTT genuinely adds:** asynchronous fills (deal after TIMEOUT/CONNECTION), partial-fill continuation, deal lineage over time (DEAL_ADD per deal), and the only way to see deal-arrives-late events inside the process lifetime.
- **What OTT does NOT solve:** restart recovery (a restart before OTT fires loses nothing once the ledger holds INTENT/ACCEPTED — recovery re-scans broker history instead), and correlation to `executionId` (must be introduced via `request_id` in ACCEPTED events or the `#<seq>` comment once wired).
- **Decision:** OTT is wired in B25-03C as a record-only DEAL_IN source (secondary), keyed by dealTicket; it never transitions state except per the legal-transition table (e.g., UNKNOWN -> FILLED only on deal evidence — Invariant 7).

## 5. Ledger ↔ Settlement

- Settlement today (`PositionLifecycleManager`) parses `-P<id>` from the position comment (line 597), tracks RAM contexts, and publishes `EVENT_POSITION_CLOSED` with candidateId + net profit; `ActualOutcomeSettler` maps candidateId -> telemetry decisionId (RAM pairs).
- B25-03C does NOT change settlement. Identified future integration points (recorded as a dependency, not built):
  1. `ParseEntryDecisionId` is comment-version-agnostic (stops at first non-digit) so `SCX-BUY-P5#123` still parses to 5 — B25-03C must not change this function.
  2. A future `#<seq>`-aware parse would add executionId correlation at position open/close; that is a settlement-surface change and is a separate dependency (see Section 7).
  3. The ledger's DEAL_IN events (with DEAL_POSITION_ID) are a candidate source for position-context reconstruction at restart — currently contexts are RAM-only (Finding 1); the design keeps this as a future integration, not a change to `PositionLifecycleManager`.

## 6. Telemetry Boundary

- Telemetry `decisionId` is a run-local counter (`TelemetryCollector.mqh:308`); ledger `executionId` is `EX-<runId>-<seq>`. They are different namespaces with different lifecycles (decisionId restarts per run; seq is globally monotonic per counter file).
- **Conclusion: keep separate.** No evidence requires merging. The only cross-link needed is the existing candidateId -> decisionId mapping (`ActualOutcomeSettler`), which B25-03C does not touch. A future audit mapping (candidateId -> executionId -> telemetry decisionId) can be derived from ledger INTENT events (which carry planId == candidateId) without any telemetry schema change.
- Telemetry schema (CSV v5/v6 header) is FROZEN; B25-03C must not add columns.

## 7. Dependencies / STOP-Condition Findings

| Stop condition (mandate) | Finding | Status |
|---|---|---|
| Requires changing B25-03A | No: `ExecutionIdentity.mqh` is consumed (AllocateSeq/BuildExecutionId/SetMonotonicFloor), not modified | NOT TRIGGERED |
| Requires changing B25-03B | No: `ExecutionTruthRecord` is consumed verbatim as event payload; module untouched | NOT TRIGGERED |
| Execution identity becomes ambiguous | No: `EX-<runId>-<seq>` remains the sole authority; seq monotonicity guarded by counter + ledger floor | NOT TRIGGERED |
| Requested values become execution truth | No: filled fields come only from broker evidence (B25-03B rule carried into events) | NOT TRIGGERED |
| Reconciliation requires guessing | No: verdicts are RESOLVED / NOT_FOUND / AMBIGUOUS / BROKER_UNAVAILABLE / CORRUPT_LOCAL_STATE; AMBIGUOUS never auto-resolves (Phase 6) | NOT TRIGGERED |
| Retry policy becomes entangled | No: retry/resubmission is explicitly out of scope; the design only defines "never re-send an executionId without a terminal record" | NOT TRIGGERED |
| Settlement semantics must change | Not required by B25-03C itself. Future `#<seq>`-aware settlement parse is recorded as a **separate dependency** (would be a later phase with its own authorization) | DEPENDENCY RECORDED |
| Telemetry semantics must change | No | NOT TRIGGERED |
| TT01 behavior changes | No: ledger writes gated by the same `m_executionEnabled` gate (TradeManager:121); NEW/SHADOW runs emit zero ledger events; dormant proof identical to B25-03B | NOT TRIGGERED |
| Durable state cannot be made crash-safe | Crash-safe design is achievable: write-ahead INTENT + per-event flush + checksums + torn-tail truncation + single-writer discipline (Design Phases 3/8/10/18). Caveat: tester file virtualization means restart-safety validation needs a persistence-capable harness (Design Phase 19, B25-03C-F) | NOT TRIGGERED |

**Additional dependencies recorded (not part of B25-03C):**
- Wiring `#<seq>` into the send comment (changes position comments -> touches settlement parse surface). This is the strongest broker-side correlation and the *prerequisite* for cross-run unambiguous reconciliation. It is a separate future phase (tentatively B25-03C-E or later, per evidence).
- A durable `runId` policy: `EX-<runId>-<seq>` uses the runId passed to `CExecutionIdentity.Init`. A self-generated per-process runId (telemetry-style) is sufficient for uniqueness; a persisted runId is only needed if cross-run lineage must be visually obvious. Design keeps runId source configurable; uniqueness does not depend on it.

---

B25-03C: ASSESSMENT COMPLETE — see `docs/Sprint25B_B25-03C_ExecutionLedger_Design.md` for the 20-phase design.
