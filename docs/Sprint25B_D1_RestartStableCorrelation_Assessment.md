# Sprint 25B — D1 Restart-Stable Broker Correlation (Assessment)

- Document ID: SR-25B-D1-01
- Type: READ-ONLY assessment + design prerequisite analysis. No implementation, no commit, no push.
- Authoritative baseline: HEAD `a0f2720a838a26873275b4a2eadcdb77eb02cbae` (B25-03C-B).
- Frozen inputs audited: B25-03A `67c58d0` (`ExecutionIdentity.mqh`), B25-03C-B `a0f2720`, H6 `157e3a4`.
- Method: `git show HEAD:` source reads; no runs, no modifications.

---

## 1. The frozen B25-03A mechanism (already complete)

`Trading/ExecutionIdentity.mqh` (B25-03A, FROZEN, `67c58d0`) already provides the entire `#<seq>` correlation mechanism:

| Primitive | Signature | Behavior |
|---|---|---|
| `BuildComment` | `(side, decisionId, seq, &comment)` | `StringFormat("SCX-%s-P%lld#%llu", side, decisionId, seq)`; rejects side ∉ {BUY, SELL}; rejects `StringLen > EXEC_ID_COMMENT_MAX_LEN (31)` |
| `ParseSeqFromComment` | `(comment, &seq)` | `StringFind("#")` + substring + `StringToInteger`; `false` when no `#` (legacy form) |
| `ParseDecisionId` | `(comment, &decisionId)` | `StringFind("-P")` + `StringSubstr(+2)` + `StringToInteger` (stops at first non-digit) — identical to the production parser |
| `BuildExecutionId` | `(seq, &executionId)` | `"EX-<runId>-<seq>"` |
| `AllocateSeq` | `(&seq)` | reserve-before-use durable counter (`Execution\execution_seq.dat`, FILE_COMMON, checksummed, read-back verified) |

The `#<seq>` tail is **already fully specified, implemented, and unit-tested** in `Tests/unit/TestExecutionIdentity.mqh` (D1, D3, D8a, D9a, D10a/b, D11a, D12, D13). **Nothing in the frozen mechanism needs to change.**

## 2. Current production comment path (the gap)

`Trading/TradeRequestBuilder.mqh`:
- `:59` `request.comment = StringFormat("SCX-BUY-P%d", plan.entryDecisionId);`
- `:65` `request.comment = StringFormat("SCX-SELL-P%d", plan.entryDecisionId);`

The comment carries **candidateId only** (run-local, recycles). The `#<seq>` tail is **NOT wired**, even though `BuildComment`/`ParseSeqFromComment` exist. This is precisely the D1 gap: the broker never receives a restart-stable correlation token.

## 3. Consumer inventory (every producer/consumer of the order comment)

| # | Component | Role | Handles `#<seq>` tail? | File:line |
|---|---|---|---|---|
| P1 | `TradeRequestBuilder` | producer (legacy only) | NO — writes `SCX-<side>-P<id>` | `TradeRequestBuilder.mqh:59,65` |
| C1 | `PositionLifecycleManager::ParseEntryDecisionId` | consumer (position → decisionId) | **YES** — `StringToInteger` stops at `#` | `PositionLifecycleManager.mqh:597-599` |
| C2 | `PositionLifecycleManager::DiscoverPositions` | consumer (broker position census) | via C1 | `PositionLifecycleManager.mqh:237` |
| C3 | `CExecutionReconciler::HasLegacyCommentMatch` | consumer (init-time reconciliation, AMBIGUOUS-only) | **YES** — substring token `"P<id>"` still matches | `CExecutionReconciler.mqh:48` |
| C4 | `SuperCents_X::OnTradeTransaction` | consumer (DEAL_IN correlation) | **YES** — `StringFind("-P")` + `StringToInteger` | `SuperCents_X.mq5:218` |
| C5 | `ExecutionIdentity::ParseDecisionId` / `ParseSeqFromComment` | consumer (frozen, unwired in prod) | **YES** — designed for both forms | `ExecutionIdentity.mqh:226,240` |
| C6 | `ActualOutcomeSettler` | NOT a comment parser (uses RAM candidateId→decisionId pairs) | n/a — unaffected | `ActualOutcomeSettler.mqh` |

**Conclusion:** every consumer already tolerates the `#<seq>` tail. No consumer asserts the legacy form is exclusive.

## 4. Comment length and format (exact)

- Frozen bound: `EXEC_ID_COMMENT_MAX_LEN = 31` (MT5 order-comment limit).
- Format: `SCX-<side>-P<decisionId>#<seq>`.
- Worst case (`SELL`, decisionId `2147483647` = 10 digits, seq `99999999` = 8 digits): `"SCX-SELL-P2147483647#99999999"` = `4 + 4 + 2 + 10 + 1 + 8 = 29` chars ≤ 31. (BUY = 28.) Verified by `TestExecutionIdentity` D11a/D12.
- The current legacy form `SCX-BUY-P5` = 10 chars; the `#<seq>` form = 10 + 1 + up to 8 = up to 19 chars for typical ids — comfortably within bounds.

## 5. Uniqueness / collision / restart

- `executionSeq` is **reserve-before-use** and **durable** (`AllocateSeq` writes + flushes + read-back-verifies `execution_seq.dat` in FILE_COMMON). `SetMonotonicFloor` (ledger high-water, wired in B25-03C-B) prevents rollback reuse.
- Therefore `#<seq>` is **unique across runs and terminals**; the same `#<seq>` is never re-issued.
- `candidateId` (P<id>) may repeat across runs; `executionSeq` (`#<seq>`) never does. The two are deliberately distinct (§6).

## 6. candidateId vs executionSeq (semantic distinction)

| Token | Meaning | Scope | Recycles? |
|---|---|---|---|
| `candidateId` (`P<id>`) | run-local decision/candidate identity | within one run | **YES** (`m_nextId` resets) |
| `executionId` (`EX-<runId>-<seq>`) | execution-attempt identity | durable, local | NO |
| `executionSeq` (`#<seq>`) | restart-stable broker correlation component (the seq embedded in executionId) | durable, broker-visible | NO |
| `eventSeq` | ledger ordering only | durable, local | contiguous |
| `dealTicket` | broker evidence identity | broker-issued | NO |

These must not be collapsed (accepted design Phase 3 senior correction).

## 7. Can `#<seq>` be appended safely?

**Yes.** Proof by consumer (C1–C5 all tolerate it). Additionally:
- `ParseDecisionId`/`ParseEntryDecisionId` use `StringToInteger` which stops at the first non-digit, so `"SCX-BUY-P5#123"` → `5` (identical to legacy).
- `ParseSeqFromComment` extracts `123` only when `#` is present.
- B25-03C-B's `HasLegacyCommentMatch` uses a substring token `"P5"`, which still matches inside `"P5#123"` (produces AMBIGUOUS, unchanged semantics).

## 8. Compatibility matrix

| Concern | Result |
|---|---|
| B25-03A parser (`BuildComment`/`ParseSeqFromComment`) | ✅ compatible (already implements both forms) |
| H6 | ✅ unaffected (H6 is retry policy; never touches comments) |
| B25-03C-B | ✅ unaffected (reconciler token is a substring; ledger payload is opaque) |
| Existing tests | ✅ none assert legacy-exclusive format; `TestExecutionIdentity` already covers both forms + round-trip |
| Settlement parse surface | ✅ `ParseEntryDecisionId` is version-agnostic and must not change (B25-03C-B Finding B7) |

## 9. The one real design constraint (must be stated)

D1 is **not** a pure `TradeRequestBuilder` change. The `#<seq>` in the comment MUST equal the `executionSeq` embedded in the INTENT's `executionId`, otherwise restart correlation is broken (comment `#<seq>` would not match the ledger's INTENT seq).

Current send order (`TradeManager.Update`, HEAD `a0f2720`):
1. `m_requestBuilder.Build(...)` → comment `SCX-<side>-P<id>` (no seq).
2. `m_ledgerWriter.BeginExecution(...)` → allocates seq, writes INTENT, returns `executionId = EX-<runId>-<seq>`.
3. `OrderSend(request)`.

The seq is allocated in step 2, **after** the comment is built in step 1. Therefore D1 must either (a) reorder `BeginExecution` before `Build`, or (b) set the `#<seq>` comment **after** `BeginExecution` using the seq extracted from the returned `executionId` (`LedgerExtractExecutionSeq`, frozen). **Both require a small change to the send path and to `TradeRequestBuilder`, but do NOT require changing the frozen modules or B25-03C-B's `BeginExecution`.** Option (b) is the minimal, safe choice (no reordering, no dangling-INTENT from a Build failure).

## 10. Verdict

- The frozen B25-03A mechanism is **complete and correct** for D1; nothing frozen needs to change.
- The only missing piece is wiring the `#<seq>` tail into `TradeRequestBuilder` (and supplying the shared seq from the already-allocated executionId).
- Every consumer is compatible; no test depends on the legacy-exclusive format.
- **Stop-condition check: NOT triggered** — D1 can be satisfied without modifying a frozen component and without changing identity semantics.

```
D1: ASSESSMENT COMPLETE (mechanism frozen-ready; wiring gap identified; no blocker)
IMPLEMENTATION: NOT AUTHORIZED
COMMIT / PUSH: NOT AUTHORIZED
B25-03C-E: IMPLEMENTATION BLOCKED PENDING D1
B25-03C-C: NOT AUTHORIZED
```
