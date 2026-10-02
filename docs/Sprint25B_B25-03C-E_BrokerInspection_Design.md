# Sprint 25B — B25-03C-E Broker-Inspection-Before-Send (Design)

- Document ID: SR-25B-B03CE-02
- Type: IMPLEMENTATION-READY DESIGN. No implementation, no commit, no push.
- Authoritative baseline: `a0f2720a838a26873275b4a2eadcdb77eb02cbae`.
- Prerequisite (proven in the companion assessment): **D1 (`#<seq>` comment wiring).** E is CONDITIONAL on D1. D1 is a separate authorization (it changes the broker comment surface, although the settlement parser is already version-agnostic and must not change).
- Scope: broker-inspection-before-send, the cross-run regenerated-plan duplicate defense (accepted design R9/R12, Phase 7.2/7.3).

---

## 1. Boundary

| Layer | Responsibility | Status |
|---|---|---|
| B25-03C-A | ledger core | FROZEN (`e881897`) |
| B25-03B | execution truth | FROZEN (`a36ea238`) |
| B25-03A | execution identity (`#<seq>` primitives) | FROZEN (`67c58d0`), consumed |
| H6 | retry policy + RAM candidateId dedup | CLOSED (`157e3a4`) |
| B25-03C-B | writer / recovery / reconciler | CLOSED (`a0f2720`) |
| **B25-03C-E** | **broker-inspection-before-send (cross-run)** | THIS DESIGN |
| D1 | `#<seq>` comment wiring | PREREQUISITE, separate authorization |
| B25-03C-C | (deferred/future) | NOT AUTHORIZED |

E does NOT: implement D1, change the ledger schema, change H6, change C3, add a retry engine, or mutate broker state.

---

## 2. Threat model

| # | Threat | Defense |
|---|---|---|
| T1 | Cross-run re-submit of an already-executed plan | broker inspection with exact `#<seq>` correlation → MATCHED → BLOCK |
| T2 | False NOT_FOUND (absence treated as proof) | NOT_FOUND only under exact `#<seq>` + exhaustive verified absence; legacy/weak correlation → AMBIGUOUS |
| T3 | Unsafe retry | H6 unchanged (HOLD for uncertain); E never re-sends |
| T4 | Over-blocking legitimate regenerated plans | `#<seq>` disambiguates recycled candidateIds |
| T5 | TOCTOU (inspect→send race) | §4 |
| T6 | Broker mutation during inspection | E is read-only (B22) |
| T7 | Multiple matching candidates | AMBIGUOUS → BLOCK (never pick "closest") |
| T8 | Stale historical artifacts with recycled ids | `#<seq>` makes each comment unique; stale `#<seq>` = the SAME attempt → BLOCK; different `#<seq>` = unrelated |

---

## 3. Evidence hierarchy (broker-inspection correlation)

Ranked; higher rank wins; equal-rank conflict → AMBIGUOUS.

| Rank | Correlation | Strength | Verdict contribution |
|---|---|---|---|
| R1 | Exact `#<seq>` comment match (`SCX-<side>-P<id>#<seq>`) on a deal/order/position | authoritative (unique cross-run) | MATCHED |
| R2 | Deal ticket / order ticket (exact, broker-issued) | authoritative | MATCHED |
| R3 | Legacy `SCX-<side>-P<id>` comment match | **weak (candidateId recycles)** | AMBIGUOUS only |
| R4 | symbol + magic + side + volume ± ε + time window | weak attributes | AMBIGUOUS only |
| R5 | absence of any match | **never NOT_FOUND without R1+R2** | AMBIGUOUS |

**Rule:** only R1/R2 can produce MATCHED or NOT_FOUND. R3/R4/R5 can only produce AMBIGUOUS → BLOCK. This is the BLOCK-over-GUESS core.

---

## 4. Race-window analysis (Objective 7)

| Window | Risk | Resolution |
|---|---|---|
| W1 inspection immediately before send | the inspected state may change | INTENT-before-send (B25-03C-B) + synchronous MqlTradeResult + OTT DEAL_IN + recovery fold catch any fill that lands after inspection; within-run RAM dedup prevents same-plan re-send |
| W2 broker artifact appears during/after inspection | a fill racing the send | same as W1; the send's synchronous result is authoritative for THIS attempt; the prior attempt (if any) was already resolved by inspection |
| W3 terminal restart mid-inspection/mid-send | partial state | inspection is idempotent and re-run on every restart; INTENT write-ahead means a crashed send is recoverable (R3) |
| W4 delayed broker visibility (TIMEOUT → late fill) | a fill not yet visible at inspection | UNKNOWN state (H6/B25-03C-B) holds; recovery reconciles via history; E's history scan includes the deal window |
| W5 partial fill | remaining volume | MATCHED if ANY prior fill (volume > 0) for the `#<seq>`; no re-send of a partially-filled attempt |
| W6 multiple matching candidates | tie | AMBIGUOUS → BLOCK (never majority/closest) |
| W7 stale historical orders/deals | recycled-id false match | `#<seq>` uniqueness: stale `#<seq>` = same attempt (BLOCK); a different `#<seq>` = unrelated (ignore) |
| W8 same symbol/direction/magic, unrelated execution | attribute-only false match | R4 is AMBIGUOUS-only; never MATCHED; never used to permit send |
| W9 send racing a concurrent EA instance | two EAs same magic | out of scope (single-writer assumption N5; the ledger single-writer + magic census is the existing boundary) |

**The distributed crash window cannot be eliminated (no atomic "inspect+send"); safety comes from never re-sending on insufficient evidence, not from assuming atomicity (accepted design Phase 8, senior correction 4).**

---

## 5. Correlation model (with D1)

`executionId = EX-<runId>-<executionSeq>` (B25-03A). `BuildComment(side, decisionId, seq) → SCX-<side>-P<decisionId>#<seq>`. The `#<seq>` tail is the unique cross-run token; `ParseSeqFromComment` recovers it.

Before ANY `OrderSend`, for the candidate plan (decisionId, side, symbol, magic, volume, price):
1. Compute the prospective `#<seq>` (already reserved via B25-03A before INTENT — the same seq used in the INTENT write-ahead).
2. Scan E2/E3/E4 for a broker artifact whose comment carries the SAME `#<seq>`.
3. If found → MATCHED (this exact attempt already reached the broker).
4. If not found AND the scan was exhaustive (full history window, symbol+magic bounded) → NOT_FOUND (safe to proceed).
5. If the scan is incomplete/unavailable → UNAVAILABLE → BLOCK.
6. If only legacy `P<id>` or attribute matches exist → AMBIGUOUS → BLOCK.

Note: because D1 is wired, the comment is unique, so "same `#<seq>`" is authoritative and "different `#<seq>`" is provably unrelated. CandidateId is never used as a cross-run identity.

---

## 6. Decision vocabulary and safe behavior (Objective 5/8)

| Verdict | Condition | Action |
|---|---|---|
| MATCHED | exact `#<seq>` (R1) or exact ticket (R2) match | **BLOCK this plan** — treat as already-executed; do NOT send; record/link to the prior execution |
| NOT_FOUND | exact `#<seq>` correlation + exhaustive verified absence | **permitted** new execution (INTENT + send proceeds) |
| AMBIGUOUS | legacy/attribute-only match, or multiple candidates, or absence without exhaustive proof | **BLOCK** (no send); operator/senior review |
| UNAVAILABLE | broker history/orders/positions unreachable | **BLOCK** (no send); retry inspection next tick |
| CORRUPT_LOCAL_STATE | ledger/identity unreadable | **BLOCK all sends** (reuse B25-03C-B `IsExecutionBlocked`) |

**BLOCK-over-GUESS proof:** every non-MATCHED, non-proven-NOT_FOUND outcome is BLOCK. Weak absence never reaches NOT_FOUND (R5 rule). Ambiguity never permits OrderSend. Inspection is read-only (no broker mutation). No blind resend.

---

## 7. State-machine interaction (B25-03C-B)

- E runs **before** `BeginExecution` (INTENT). It does not write any ledger event for the *decision* (it may, at most, emit a RECONCILED/BLOCKED event on a *prior* executionId that it finds — see B25-03C-B writer).
- The existing state machine (`CExecutionRecovery::IsLegalTransition`) is unchanged. E introduces NO new event type (the 9-event vocabulary suffices: a MATCHED prior execution is already terminal; AMBIGUOUS → `RecordBlocked`).
- The `AlreadySent(executionId)` guard (B25-03C-B) remains the durable executionId-level guard; E is the *decision/plan*-level cross-run guard, keyed by `#<seq>`.

## 8. H6 interaction

- H6 remains the sole retry-policy authority (`H6ClassifyPolicy`). E does not classify retcodes, does not add retry, and does not alter RETRY_ELIGIBLE/HOLD.
- E's "BLOCK" is distinct from H6's "PLAN_REJECTED" and "HOLD": E blocks a *regenerated plan* before any send attempt, leaving it untouched for the next reconciliation.
- The H6 RAM `m_submittedIds[]` and hold map remain unchanged (within-run).

## 9. C3 interaction

- C3 (`CountOpenPositions`, live position cap by symbol+magic) is unchanged and remains the *concurrency* gate.
- E is the *cross-run duplicate* gate and runs **in addition to** C3, before INTENT. Order of checks in the send path becomes:
  1. execution gate (`m_executionEnabled`)
  2. recovery blocked (`IsExecutionBlocked`)
  3. RAM dedup (`IsAlreadySubmitted`)
  4. H6 hold (`IsRetryHeld`)
  5. **E: broker-inspection-before-send** (MATCHED/AMBIGUOUS/UNAVAILABLE → BLOCK)
  6. C3 position gate
  7. C7 fill / ValidateAll / sizing / volume / build
  8. INTENT-before-send → OrderSend → truth/policy (B25-03C-B)

## 10. B25-03C-B boundary

- E is a NEW, separate module (`CExecutionBrokerInspection`, proposed) that CONSUMES the B25-03C-B writer/recovery/reconciler. It does not modify them (their files remain byte-identical unless the wire-in explicitly adds the inspection call, which is a new-code + minimal-wire-in change gated behind a future authorization).
- The reconciler's init-time `Reconcile` (pending executions) remains; E's inspection is a separate, send-time guard.

## 11. D1 boundary

- D1 = wire `ExecutionIdentity.BuildComment(side, decisionId, seq)` into `TradeRequestBuilder` so the comment becomes `SCX-<side>-P<id>#<seq>`.
- Frozen B25-03A already provides `BuildComment`/`ParseSeqFromComment`; D1 only changes the TWO `StringFormat` lines in `TradeRequestBuilder.mqh:59,65` (plus passing the reserved seq).
- `ParseEntryDecisionId` (`PositionLifecycleManager.mqh:597-599`) already ignores the `#<seq>` tail (stops at first non-digit), so settlement correlation is unaffected.
- **D1 is a SEPARATE authorization** (it changes the broker-visible comment). E's design assumes D1 is landed first.

---

## 12. Implementation decomposition (future, NOT authorized)

1. **D1**: comment wiring (`TradeRequestBuilder` + seq provision plumbing) — prerequisite.
2. **`CExecutionBrokerInspection` (new, `Trading/`)**: `Inspect(decisionId, side, symbol, magic, seq, volume, price)` → one of the §6 verdicts; pure verdict function + broker-scan layer (mirrors `CExecutionReconciler`).
3. **Wire-in** `TradeManager.Update` (one call site, before INTENT), gated by `m_executionEnabled` (dormancy preserved).
4. **TDD** (below) + full-suite + dormancy + boundary gates.

---

## 13. TDD RED → GREEN plan

- RED (compile/behavior): `Inspect` returns AMBIGUOUS for every legacy/attribute-only case; MATCHED only for exact `#<seq>`; NOT_FOUND only for exact `#<seq>` + exhaustive absence; UNAVAILABLE on broker disconnect.
- Unit tests (pure): `InspectVerdictFromEvidence(exactSeqMatch, exactTicketMatch, legacyMatch, attributeMatch, exhaustiveAbsence, brokerAvailable)` — every combination.
- Integration (live account, mirroring C3 test style): a crafted `#<seq>`-tagged position/order → MATCHED; a fresh seq → NOT_FOUND; broker unavailable → UNAVAILABLE.
- Crash-window: W1/W3/W4/W5/W7/W8 scenarios; no crash permits automatic duplicate submission.
- Dormancy: NEW/SHADOW → inspection never runs, zero broker queries.
- Boundary: frozen modules + H6 + C3 byte-identical; `#<seq>`-aware parse unchanged.
- Full suite GREEN ×2.

## 14. Machine-checkable invariants

- **E1** MATCHED requires an exact `#<seq>` (or exact ticket) match; legacy/attribute matches never yield MATCHED.
- **E2** NOT_FOUND requires exact `#<seq>` correlation AND exhaustive verified absence.
- **E3** AMBIGUOUS/UNAVAILABLE/CORRUPT always BLOCK (never permit OrderSend).
- **E4** inspection performs zero broker mutations (read-only; no OrderSend/OrderClose/OrderModify/OrderCancel).
- **E5** candidateId is never used as a cross-run identity; only `#<seq>`/executionId is authoritative.
- **E6** executionId remains the attempt identity; never reused (B25-03A reserve-before-use).
- **E7** H6 policy is not re-derived (consume `H6ClassifyPolicy` output only).
- **E8** C3 gate semantics unchanged.
- **E9** dormancy: inspection is gated by `m_executionEnabled`.
- **E10** deterministic: same evidence → same verdict (pure function).

## 15. Acceptance gates

- G1 correlation: MATCHED/NOT_FOUND reachable ONLY via exact `#<seq>`; AMBIGUOUS otherwise.
- G2 no-duplicate: no W-scenario permits automatic duplicate submission.
- G3 read-only: zero broker mutation from E.
- G4 dormancy: NEW/SHADOW zero inspection activity.
- G5 boundary: frozen + H6 + C3 zero diff.
- G6 determinism: identical evidence → identical verdict ×N.
- G7 full suite GREEN + all prior gates.

---

## 16. Explicit BLOCK-over-GUESS proof

For any input (evidence set), the verdict function maps to:
- MATCHED (exact) → BLOCK (already executed).
- NOT_FOUND (exact + exhaustive) → permit (proven absent).
- everything else → AMBIGUOUS/UNAVAILABLE/CORRUPT → BLOCK.

The only permit path is exact-and-exhaustive NOT_FOUND. The only positive-match path is exact MATCHED. Every weak, incomplete, or absent-without-proof input resolves to BLOCK. Hence no insufficient evidence can produce "safe to send", and no weak evidence can produce "executed". QED.

---

```
B25-03C-B: CLOSED / PUSHED
B25-03C-E: ASSESSMENT + DESIGN ONLY
D1: PREREQUISITE (PROVEN) — NOT AUTHORIZED
IMPLEMENTATION: NOT AUTHORIZED
COMMIT: NOT AUTHORIZED
PUSH: NOT AUTHORIZED
B25-03C-C: NOT AUTHORIZED
NEXT SENIOR DECISION: REVIEW B25-03C-E ASSESSMENT + DESIGN (and D1 authorization decision)
STOP.
```
