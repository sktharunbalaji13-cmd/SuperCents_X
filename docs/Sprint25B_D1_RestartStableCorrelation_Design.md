# Sprint 25B — D1 Restart-Stable Broker Correlation (Design)

- Document ID: SR-25B-D1-02
- Type: IMPLEMENTATION-READY DESIGN. No implementation, no commit, no push.
- Authoritative baseline: `a0f2720a838a26873275b4a2eadcdb77eb02cbae`.
- Prerequisite: none (this design UNBLOCKS B25-03C-E; it does not implement E).

---

## 1. Boundary

D1 wires the frozen B25-03A `#<seq>` correlation into the request-building path **only**. It establishes that every submitted execution carries a restart-stable broker correlation token. It does **NOT** implement broker inspection, reconciliation, retry, duplicate prevention, or any E/C behavior.

| Layer | D1 action |
|---|---|
| `ExecutionIdentity.mqh` (B25-03A) | FROZEN — consumed (`BuildComment`/`ParseSeqFromComment`/`AllocateSeq`) |
| `ExecutionTruth.mqh`, `ExecutionLedger.mqh`, H6, telemetry, settlement | FROZEN — zero diff |
| `CExecutionRecovery/Writer/Reconciler` (B25-03C-B) | unchanged (the writer's `BeginExecution` seq allocation is left intact) |
| `TradeRequestBuilder.mqh` | D1 change: comment carries `#<seq>` |
| `TradeManager.mqh` (send path) | D1 change: supply the shared seq to the comment builder |

## 2. The five identities (must not collapse)

| Identity | Meaning | Source | Durable | Cross-run unique |
|---|---|---|---|---|
| candidateId (`P<id>`) | run-local decision identity | `TradeCandidateBuilder.m_nextId++` | no | **no** |
| executionId (`EX-<runId>-<seq>`) | execution-attempt identity | B25-03A | yes (ledger) | yes |
| executionSeq (`#<seq>`) | restart-stable broker correlation component | B25-03A counter | yes (FILE_COMMON) | yes |
| eventSeq | ledger event ordering only | B25-03C-A tail | yes | contiguous (not identity) |
| dealTicket | broker evidence identity | broker | yes (broker) | yes |

## 3. Correlation proof

```
executionSeq (AllocateSeq, reserve-before-use, durable)
      -> BuildComment(side, decisionId, seq)  ==  "SCX-<side>-P<id>#<seq>"
      -> request.comment (broker-visible artifact)
      -> [terminal restart]
      -> ParseSeqFromComment(comment)  ==  seq
      -> matches the ledger INTENT whose executionId == "EX-<runId>-<seq>"  (same seq)
      => exact same-execution correlation
```

The seq is shared between the comment and the executionId because both derive from the **single** `AllocateSeq` call already made in `BeginExecution`. The comment is set after `BeginExecution` returns the executionId, extracting the seq via the frozen `LedgerExtractExecutionSeq(executionId)`.

## 4. The exact change (files / current / desired / transition)

### 4.1 `TradeRequestBuilder.mqh`
- **Current** (`:59,65`): `request.comment = StringFormat("SCX-BUY-P%d", plan.entryDecisionId);` (and SELL) — legacy, no `#<seq>`.
- **Desired**: the comment becomes the frozen `BuildComment` format `SCX-<side>-P<decisionId>#<seq>`. Two sub-options (design chooses the minimal one):
  - (a) `Build` keeps the legacy comment; a NEW method `SetCorrelationSeq(MqlTradeRequest &request, const ulong seq)` appends `#<seq>` (or rebuilds via the frozen format) — called from the send path after `BeginExecution`.
  - (b) `Build` accepts an optional `seq` parameter and emits the full `#<seq>` comment directly.
- **Chosen**: (a) — `SetCorrelationSeq` appends the `#<seq>` tail; `Build` remains byte-compatible when D1 is not wired. No dangling INTENT (Build still runs before `BeginExecution`).
- **State transition**: none (request construction only). Comment length enforced by reusing the frozen 31-char bound.

### 4.2 `TradeManager.mqh` (send path, HEAD `a0f2720`)
- **Current order**: `Build` → `BeginExecution` → `OrderSend`.
- **Desired**: `Build` (legacy comment) → `BeginExecution` (returns `executionId`) → `seq = LedgerExtractExecutionSeq(executionId)` → `request.comment = BuildComment(side, decisionId, seq)` → `OrderSend`.
- **Change**: two lines between `BeginExecution` and `OrderSend` (extract seq, set `#<seq>` comment), gated by `m_ledgerWriter != NULL` (dormancy preserved — no-op under NEW/SHADOW).
- **No change** to `BeginExecution`, `RecordResult`, H6 policy, C3 gate, or any frozen module.

## 5. Safety analysis (mandated cases)

| Case | Analysis | Outcome |
|---|---|---|
| comment collision | `#<seq>` unique (reserve-before-use + monotonic floor) → no collision | safe |
| sequence reuse | `AllocateSeq` durable counter + `SetMonotonicFloor` → never reused | safe |
| restart | counter file durable (FILE_COMMON, checksummed, read-back); floor from ledger high-water → continues, no rollback | safe |
| multiple symbols | seq is global (not per-symbol) → still unique across symbols | safe |
| BUY/SELL | `BuildComment` rejects non-{BUY,SELL}; side is in the comment | safe |
| multiple executions from one decision | same candidateId, different `#<seq>` (retry = new seq, B25-03C-B B25) | distinct, safe |
| partial fills | same `#<seq>` across all DEAL_IN of one execution; dedup by dealTicket | safe |
| legacy comments (pre-D1 orders) | `ParseSeqFromComment` returns false (no `#`) → treated as legacy/AMBIGUOUS by E | safe (never inferred) |
| malformed comments | `ParseSeqFromComment`/`ParseDecisionId` return false → AMBIGUOUS | safe (never inferred) |
| broker mutates comment | the `#<seq>` tail may be lost/broken → parse false → AMBIGUOUS | safe (never inferred) |
| comment truncation | 29-char worst case ≤ 31 bound; `BuildComment` refuses over-long | safe |
| maximum length | 31 (frozen constant) | safe |
| parser backward compatibility | `ParseEntryDecisionId` stops at `#`; all consumers tolerate the tail | safe |

**Rule applied throughout: where exact correlation cannot be proven (missing/broken `#<seq>`, legacy-only, malformed), the outcome is AMBIGUOUS — never inferred, never MATCHED/NOT_FOUND. BLOCK-over-GUESS.**

## 6. TDD RED → GREEN plan

RED (before wiring, against HEAD `a0f2720`):
- R1: `TradeRequestBuilder` emits a comment without `#<seq>` (compile-fail once the new method is referenced).
- R2: `SetCorrelationSeq`/`Build` produces `SCX-<side>-P<id>#<seq>` exactly.
- R3: worst-case `SELL` + `2147483647` + `99999999` → length ≤ 31, no truncation.
- R4: over-long input refused (mirror frozen D12).
- R5: `ParseSeqFromComment(SetCorrelationSeq(...))` round-trips to the same seq.
- R6: `ParseEntryDecisionId` returns the same id for legacy and `#<seq>` forms (version-agnostic).
- R7: legacy comment (no `#`) → `ParseSeqFromComment` returns false.
- R8: malformed (`P` no digits, bare `#`, `no token`) → both parsers return false.
- R9: two executions of one decision produce distinct `#<seq>`.
- R10: BUY and SELL forms both correct.
- R11: sequence continuity across `Init` (restart) — new `AllocateSeq` > prior.
- R12: no consumer test regresses (full suite); frozen modules zero-diff.

GREEN: wire §4.1 + §4.2; run full suite.

## 7. Acceptance gates (machine-checkable)

- G1 exact `#<seq>` appears in `request.comment` (broker request) — source + round-trip test.
- G2 `ParseSeqFromComment` extracts the correct seq.
- G3 `ParseEntryDecisionId` remains version-agnostic (legacy and `#<seq>` both parse the same id).
- G4 no existing consumer breaks (full suite GREEN).
- G5 no sequence reuse (counter + floor; restart continuity test).
- G6 no comment truncation (worst-case length ≤ 31).
- G7 no unrelated mechanism introduced (diff shows only `TradeRequestBuilder` + `TradeManager` send-path lines).
- G8 frozen modules byte-identical (`ExecutionIdentity/Truth/Ledger`, H6, telemetry, settlement).
- G9 B25-03C-B unchanged.
- G10 B25-03C-E remains unimplemented.

## 8. BLOCK-over-GUESS

D1 introduces identity only, never a decision. It produces a correlation token; it never resolves an execution. Any future consumer (E) that fails to recover an exact `#<seq>` must yield AMBIGUOUS — D1 guarantees the token is *present and exact* when a send occurs, and *absent/ambiguous* for legacy/malformed artifacts. This is the exact-evidence-permits-resolution foundation E requires.

## 9. Stop-condition check

- Frozen B25-03A mechanism satisfies D1 **without** modification. ✅
- Identity semantics unchanged (one seq per attempt, shared between comment and INTENT). ✅
- No frozen component modified; no ledger schema change; no H6/B25-03C-B change. ✅
- **No stop condition triggered.**

```
D1: DESIGN COMPLETE (minimal, 2-file wiring; frozen mechanism reused; no blocker)
IMPLEMENTATION: NOT AUTHORIZED
COMMIT: NOT AUTHORIZED
PUSH: NOT AUTHORIZED
B25-03C-E: IMPLEMENTATION BLOCKED PENDING D1
B25-03C-C: NOT AUTHORIZED
NEXT SENIOR DECISION: REVIEW D1 ASSESSMENT + DESIGN (then D1 implementation)
STOP.
```
