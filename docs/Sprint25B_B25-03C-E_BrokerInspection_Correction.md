# Sprint 25B — B25-03C-E Broker-Inspection Design Correction (Negative-Evidence Safety)

- Document ID: SR-25B-B03CE-03 (CORRECTION to SR-25B-B03CE-02)
- Type: READ-ONLY design correction/assessment. No implementation, no commit, no push.
- Authoritative baseline: `9fefdd8` (D1 pushed). B25-03C-E implementation (uncommitted) is REJECTED pending this correction.
- Reason: the senior safety review established that the negative case (NOT_FOUND → SEND) is unproven under the decisionId-keyed, bounded-broker-window correlation.

---

## 1. The rejected model and its failure (confirmed)

```
decisionId (candidateId) match found -> AMBIGUOUS -> BLOCK      (safe)
no decisionId match (within 7-day broker window) -> NOT_FOUND -> SEND   (UNSAFE)
```

The unsafe direction has TWO independent flaws:

1. **Recyclable key.** `candidateId`/`decisionId` is run-local (`TradeCandidateBuilder.m_nextId`, reset each run). Run-1 `candidateId=5` and Run-2 `candidateId=5` are different plans in general, so "P5 found" can never prove same-plan, and "P5 not found" can never prove this plan never ran.
2. **Bounded evidence.** `positions + orders + 7-day order history` is exhaustive only within that window. A prior-run artifact older than the window silently drops out, so "not found" is consistent with "executed long ago".

Consequence: a stale prior execution (Run-1 candidateId=5, artifact aged past the window) is invisible to the inspection; Run-2 regenerates the same plan → NOT_FOUND → SEND → **the exact cross-run duplicate E exists to prevent.**

## 2. The two identities that CANNOT be the plan identity

| Identity | Why it cannot be the send-time plan key |
|---|---|
| `candidateId` (`P<id>`) | run-local, resets every run (recyclable) |
| `executionId` / `#<seq>` | per-ATTEMPT identity (reserve-before-use); a regenerated plan gets a NEW `#<seq>`, so it cannot dedup the prior attempt |

D1's `#<seq>` is correct as an **execution-attempt / recovery** identity (parse broker comment → exact executionId). It is NOT, and was never, a durable identity of the *regenerated plan*. The senior's statement is accepted as the governing fact.

## 3. The corrected correlation: plan CONTENT + unbounded ledger

The durable, non-recycled plan identity already exists — it is the plan's **content**, durably recorded in the B25-03C-B ledger's INTENT payload:

```
INTENT payload (B25-03C-B writer, frozen format):
  candidateId | symbol | side | entryPrice | requestedVolume | sl | tp | magic
```

A regenerated plan reproduces this content **exactly** under deterministic regeneration (same bars → same confluence → same entry price, same SL/TP, same symbol/side/magic). A different signal produces different content. Therefore **content is the plan identity** — and it is:

- **non-recycled** (it derives from the signal, not from a per-run counter),
- **durable** (already in the append-only ledger),
- **unbounded** (the ledger has no retention window; a prior INTENT never "ages out").

The evidence source for E's negative case becomes the **ledger (frozen `LedgerScan`)**, not the bounded broker window.

## 4. Proof that content-keyed NOT_FOUND → SEND is safe

Claim: "no ledger INTENT (broker-visible) with content equal to (symbol, side, magic, entryPrice, sl, tp)" ⟺ "this plan was never executed since the ledger went live."

- (⇒) If the plan executed, its INTENT (with exactly that content) is in the ledger, and its state reached SUBMITTED/ACCEPTED/FILLED/PARTIALLY_FILLED. Contradiction. So absence ⇒ never executed.
- (⇐) If it never executed, no such INTENT exists. Trivial.

Unboundedness closes the senior's aging objection: a prior execution is recorded forever, so absence cannot be caused by window expiry. The only absence is "genuinely never executed (post-ledger)".

## 5. Corrected verdict contract

Evidence = ledger fold of broker-visible executions, compared by CONTENT.

| Verdict | Condition | Action |
|---|---|---|
| MATCHED | an INTENT with **exactly equal** (symbol, side, magic, entryPrice, sl, tp) reached broker-visible | BLOCK (duplicate) |
| AMBIGUOUS | a **near** content match (price within ε, or sl/tp within ε but not exact) | BLOCK (conservative; content collision) |
| NOT_FOUND | **no** content match in the ledger | SEND (provably never executed) |
| UNAVAILABLE | ledger unreadable / broker (for positive aid) unreachable | BLOCK |
| CORRUPT | ledger corrupt (`CExecutionRecovery.IsExecutionBlocked`) | BLOCK (reused) |

BLOCK-over-GUESS is preserved: only exact-content-absence (NOT_FOUND) permits; everything else BLOCKs. The positive/ambiguous side remains conservative; the negative side is now proven safe.

## 6. Role of each identity (final, uncollapsed)

- `candidateId` = run-local decision identity — NOT a cross-run key (never used by E's send check).
- `executionId` = execution-attempt identity (B25-03A) — recovery authority.
- `#<seq>` (D1) = restart-stable broker correlation for the **attempt** (parse broker comment → executionId).
- `eventSeq` = ledger ordering only.
- `dealTicket` = broker evidence identity.
- **`(symbol, side, magic, entryPrice, sl, tp)` = the PLAN identity E keys on** (already in the INTENT payload; no new layer).

## 7. Implementation impact (no frozen/B25-03C-B change, no new identity)

- E's `Inspect` reads the **ledger** via the frozen `LedgerScan` and parses INTENT payload content (fields already stored: symbol, side, price, sl, tp, magic). It does NOT scan the broker window for the negative case.
- The existing `CExecutionBrokerInspection` broker-scan primitive is retained but **demoted to a positive-only aid** (find a broker artifact → BLOCK); it never authorizes a send.
- No change to `ExecutionIdentity`, `ExecutionTruth`, `ExecutionLedger`, `CExecutionRecovery`, `CExecutionLedgerWriter`, `CExecutionReconciler`, H6, or D1. No new identity mechanism.

## 8. Residuals (honest)

1. **Pre-ledger executions** (before B25-03C-B went live, or a deleted/corrupt ledger) are not recorded; the content-absence proof is scoped to "since the ledger went live". This is a cold-start boundary, not a retention window.
2. **Content collision** (two different signals with identical entry/SL/TP) → MATCHED/AMBIGUOUS → BLOCK (conservative over-block, never unsafe).

## 9. Fallback (option C) if content-keying is rejected

If the content identity is judged insufficiently precise, the only safe contract is **absence ⇒ no send**: E returns BLOCK/AMBIGUOUS for both match AND absence, and no mechanism in E ever authorizes a send. That is safe but non-viable as a duplicate gate (it blocks all regenerated plans), which is why the content-keyed contract (§3-§5) is the recommended correction.

---

```
B25-03C-E: REJECTED (negative-evidence model) -> DESIGN CORRECTION PROVIDED
CORRECTION: PLAN-CONTENT + UNBOUNDED LEDGER (no new identity, no frozen change)
IMPLEMENTATION: NOT AUTHORIZED (re-implementation required per this correction)
COMMIT: NOT AUTHORIZED
PUSH: NOT AUTHORIZED
B25-03C-C: NOT AUTHORIZED
NEXT SENIOR DECISION: ACCEPT/REJECT THE CORRECTED E CONTRACT
STOP.
```
