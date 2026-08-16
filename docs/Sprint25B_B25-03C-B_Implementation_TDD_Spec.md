# Sprint 25B — B25-03C-B Implementation TDD / Status Specification

- Type: IMPLEMENTATION TDD SPEC. Pins the three non-blocking design clarifications and the concrete state machine + interfaces. No implementation artifacts in this document; the implementation is in the three new modules + three wire-ins.
- Authoritative baseline: `157e3a4c02d927569e94eafaec584b043dd5e715`.
- Frozen (consumed, never modified): `ExecutionLedger.mqh` (B25-03C-A), `ExecutionTruth.mqh` (B25-03B), `ExecutionIdentity.mqh` (B25-03A), `TradeManagerRetryPolicy.mqh` (H6).

---

## 1. Pinned clarifications

### C1 — Durable dedup guards (two distinct protections)

- **A) `AlreadySent(executionId)` — durable broker-visible-submission guard, keyed by `executionId` (the durable execution-attempt identity).** It answers: *has this executionId reached a broker-visible state (SUBMITTED/ACCEPTED/PARTIALLY_FILLED/FILLED)?* `candidateId`/`decisionId` is run-local (accepted design Phase 7) and therefore is NOT a durable dedup authority; within-run dedup stays RAM-side (`IsAlreadySubmitted`, H6). Cross-run duplicate prevention is broker reconciliation (R9/R12), never candidateId equivalence.
- **B) `executionId` never reused — a separate invariant (Invariant 6).** Each send attempt allocates a fresh `executionId` (reserve-before-use, `AllocateSeq` + `BuildExecutionId`); the writer rejects a second INTENT for an already-seen executionId. A retry-eligible re-attempt is a NEW executionId under the SAME decisionId.
- These are NOT the same protection and must not be described as one. (Design §6 pseudocode `writer.AlreadySent(plan)` is hereby pinned to mean A, keyed by executionId.)

### C2 — executionSeq vs eventSeq

- `executionSeq` = execution-attempt identity sequence (embedded in `executionId = EX-<runId>-<executionSeq>`; reserve-before-use; gaps legal).
- `eventSeq` = ledger event ordering sequence (contiguous, tail-derived).
- Never use one as the other's identity/order authority. Reconstruction folds by `eventSeq`; identity is `executionId`.

### C3 — Non-atomicity principle

- `INTENT`-before-send + `FileFlush` does **NOT** make `OrderSend` and post-send ledger persistence atomic. The window between `OrderSend` and the post-send event append is inherent; R3 (broker inspection) is the mandatory recovery for that window. No test may claim atomicity.

---

## 2. State machine (accepted design Phase 4 whitelist)

States (strings in ledger `stateFrom`/`stateTo`): `INTENT`, `SUBMITTED`, `ACCEPTED`, `PARTIALLY_FILLED`, `FILLED`, `REJECTED`, `UNKNOWN`, `RECONCILING`, `RESOLVED`, `BLOCKED`.

Legal transitions (`IsLegalTransition`):

| From | To |
|---|---|
| INTENT | SUBMITTED, REJECTED, UNKNOWN, BLOCKED |
| SUBMITTED | ACCEPTED, PARTIALLY_FILLED, FILLED, UNKNOWN, RECONCILING, BLOCKED |
| ACCEPTED | PARTIALLY_FILLED, FILLED, REJECTED, RECONCILING, BLOCKED |
| PARTIALLY_FILLED | PARTIALLY_FILLED (self, additional unique DEAL_IN), FILLED, RECONCILING, BLOCKED |
| FILLED | (terminal) |
| REJECTED | (terminal) |
| UNKNOWN | SUBMITTED, ACCEPTED, PARTIALLY_FILLED, FILLED, RECONCILING, BLOCKED |
| RECONCILING | RESOLVED, BLOCKED |
| RESOLVED | (terminal) |
| BLOCKED | (terminal) |

`UNKNOWN → FILLED`/`PARTIALLY_FILLED`/`ACCEPTED`/`SUBMITTED` is legal **only with broker evidence** (a DEAL_IN or reconciled deal) — never by requested values or time.

---

## 3. H6 → event mapping (Phase 4)

| `H6ClassifyPolicy` | Ledger event | stateFrom → stateTo | Notes |
|---|---|---|---|
| `H6_POLICY_RECORD` | `SENT` | INTENT → SUBMITTED | broker-visible submission; DEAL_IN may attach later |
| `H6_POLICY_REJECT_PERMANENT` | `REJECTED` | INTENT → REJECTED | terminal for this executionId |
| `H6_POLICY_RETRY_ELIGIBLE` | `REJECTED` | INTENT → REJECTED | this attempt refused; retry = NEW executionId + NEW INTENT |
| `H6_POLICY_RETRY_HOLD` | `UNKNOWN` | INTENT → UNKNOWN | pending; resolved only by B25-03C reconciliation |

---

## 4. Module interfaces

- `Trading/CExecutionRecovery.mqh` — pure state machine (`IsLegalTransition`), `RebuildStates(events, states[])` fold (enforces Invariants 6/7/8/9/11/13), `CExecutionRecovery` class: `Init(path, identity)`, `IsExecutionBlocked()`, `GetPendingExecutions()`, `Verdict(executionId)`, `AlreadySent(decisionId)`.
- `Trading/CExecutionLedgerWriter.mqh` — `CExecutionLedgerWriter`: `Init(path, identity)`, `BeginExecution(...)`, `RecordResult(executionId, truth, policy)`, `RecordDeal(...)`, `RecordReconciled(...)`, `RecordBlocked(...)`, `RecordRunEnd()`. Enforces the state machine before every append.
- `Trading/CExecutionReconciler.mqh` — `CExecutionReconciler`: broker evidence queries + `Reconcile(...)` → verdict (RESOLVED / NOT_FOUND / AMBIGUOUS / BROKER_UNAVAILABLE / CORRUPT_LOCAL_STATE). With D1 (`#<seq>`) unwired, NOT_FOUND is unreachable (legacy correlation → AMBIGUOUS).

---

## 5. TDD phase mapping

1. Writer state machine + transitions + Invariants 6/7/8/9/10/11 — `IsLegalTransition` + `RebuildStates` unit tests (event-list keyed).
2. Recovery fold determinism — same events → same state.
3. Evidence ladder verdicts — all five verdicts; AMBIGUOUS never auto-resolves.
4. H6 mapping — `H6ClassifyPolicy` → event type (consume, never modify H6).
5. Crash-window simulation — R2/R3/R4/R18a-d/R13; no crash permits automatic duplicate submission.
6. Corruption — MID_FILE_CORRUPT → BLOCKED; TORN_TAIL → recoverable.
7. Idempotence — duplicate DEAL_IN/OTT/E2 replay → identical state.
8. Dormancy — NEW/SHADOW → zero events.
9. Boundary — zero diff on frozen modules.
10. Full suite GREEN.

---

## 6. Stop conditions (re-checked per phase)

Stop if: any invariant fails; any ambiguity permits unsafe resend; any frozen module changes; any ledger schema change becomes necessary; any design assumption is contradicted by source code.
