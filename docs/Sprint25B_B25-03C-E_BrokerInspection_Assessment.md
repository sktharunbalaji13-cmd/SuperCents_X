# Sprint 25B — B25-03C-E Broker-Inspection-Before-Send (Assessment)

- Document ID: SR-25B-B03CE-01
- Type: READ-ONLY assessment + design prerequisite analysis. No implementation, no commit, no push.
- Authoritative baseline: HEAD `a0f2720a838a26873275b4a2eadcdb77eb02cbae` (B25-03C-B, pushed). Parent `157e3a4` (H6).
- Frozen inputs: B25-03A `67c58d0` (identity), B25-03B `a36ea238` (truth), B25-03C-A `e881897` (ledger core), H6 `157e3a4`, B25-03C-B `a0f2720` (writer/recovery/reconciler).
- Method: `git show HEAD:` source reads; no runs, no modifications.

---

## 1. Objective 1 — B25-03C-E boundary (re-audited against HEAD a0f2720)

The accepted B25-03C design (`docs/Sprint25B_B25-03C_ExecutionLedger_Design.md`, Phase 19) decomposes the tranche into:
- **B25-03C-A** — ledger core (CLOSED, `e881897`).
- **B25-03C-B** — event wiring + recovery state machine + reconciliation (CLOSED, `a0f2720`; the senior bundling covered design B+C+D).
- **B25-03C-E** — **durable dedup + the `#<seq>` wiring decision; specifically "broker-inspection-before-send"** (design Phase 7.2/7.3, R9/R12). This mission = E, assessment + design only.

E is the *cross-run* duplicate defense. It is distinct from, and layered on top of:
- H6 (RAM candidateId dedup + retry policy) — within-run only.
- B25-03C-B (executionId dedup + INTENT write-ahead + init-time reconciliation) — within-run crash + pending reconciliation.
- C3 (live-position concurrency gate) — unchanged.

The B25-03C-B forensic audit flagged as a residual that **broker-inspection-before-send is NOT implemented**; this document confirms and proves that residual from source.

## 2. Objective 2 — Cross-run failure mode (source-proven)

### 2.1 The identity chain (all run-local, reset on restart)

| Fact | Source |
|---|---|
| `candidate.id = m_nextId++` (m_nextId init 1, reset 1 on `Reset()`) | `Confluence/TradeCandidateBuilder.mqh:67,175,231,435` |
| `plan.entryDecisionId = decision.candidateId` | `Entry/ExecutionPlanner.mqh:214` |
| `planId = plan.entryDecisionId` (RAM dedup key) | `Trading/TradeManager.mqh:180` |
| RAM dedup `m_submittedIds[]` cleared at Init/Shutdown | `Trading/TradeManager.mqh:41,121,364` |
| Broker comment = `SCX-BUY-P%d` / `SCX-SELL-P%d` (candidateId only, NO `#<seq>`) | `Trading/TradeRequestBuilder.mqh:59,65` |

**candidateId is run-local and recycles across runs.** It is NOT a durable cross-run identity (accepted design Phase 7, Finding 2).

### 2.2 The failure trace

```
Run 1:
  candidate 5 -> EX-RUN1-101 -> INTENT -> SENT -> DEAL_IN -> FILLED
  broker position/order/deal carries comment "SCX-BUY-P5"
  position later CLOSED (or order parked)
  CRASH / terminal restart (m_nextId reset to 1, m_submittedIds[] cleared)

Run 2 (regenerated deterministic signal):
  candidate 5 again (counter recycles) -> EX-RUN2-102 (NEW executionId)
  send path checks, IN ORDER (TradeManager.Update, HEAD a0f2720):
    1. IsAlreadySubmitted(5)      -> RAM set EMPTY -> NOT a duplicate
    2. IsRetryHeld(5)             -> hold set EMPTY
    3. C3 gate CountOpenPositions() -> counts LIVE positions by symbol+magic
                                       only; the prior position is CLOSED -> 0
                                       (does NOT scan history/orders/comments)
    4. INTENT-before-send         -> EX-RUN2-102 INTENT appended
    5. OrderSend                  -> SECOND broker submission
```

**Result: duplicate broker execution.** The C3 gate only blocks when a prior position is *still open* with matching magic; it cannot see a *closed* position, a *parked order*, or a *filled deal* from a prior run. `AlreadySent(executionId)` (B25-03C-B) is keyed by the NEW executionId and is not consulted (and cannot correlate — the prior run used a different executionId).

This is the R9/R12 cross-run window of the accepted design; it is currently **open**.

## 3. Objective 3 — Broker-side evidence inventory (what actually exists)

All sources are already present and immutable (none requires new broker telemetry):

| # | Evidence | MQL5 source | Unique cross-run? | Notes |
|---|---|---|---|---|
| E1 | Synchronous `MqlTradeResult` (retcode/order/deal/price/volume) | OrderSend return | n/a (send instant) | B25-03B truth |
| E2 | Deal history | `HistoryDealsTotal/HistoryDealGetTicket/GetString(DEAL_COMMENT)/GetInteger(DEAL_MAGIC)/GetString(DEAL_SYMBOL)/GetDouble(DEAL_VOLUME)/GetDouble(DEAL_PRICE)/GetInteger(DEAL_TIME)/GetInteger(DEAL_ORDER)/GetInteger(DEAL_POSITION_ID)` | NO (comment = candidateId only) | survives restarts |
| E3 | Order history + pending orders | `HistoryOrdersTotal/HistoryOrderGetString(ORDER_COMMENT)/ORDER_MAGIC/ORDER_SYMBOL/ORDER_TIME_SETUP/ORDER_TYPE/ORDER_STATE`; `OrdersTotal/OrderGetTicket/...` | NO | parked orders survive restarts |
| E4 | Live positions | `PositionsTotal/PositionGetSymbol/PositionGetString(POSITION_COMMENT)/PositionGetInteger(POSITION_MAGIC)/POSITION_VOLUME/POSITION_PRICE_OPEN/POSITION_TIME` | NO | already used by C3 (magic+symbol) + DiscoverPositions |
| E5 | **Stable magic (C1)** | `SuperCents_X.mq5:48` input `InpMagicNumber=27182819`, set before Init | **YES** (census scope) | restart-stable |
| E6 | symbol, side, volume, price, time | all sources above | NO (attributes, not identity) | weak correlation |
| E7 | Order/position comment `SCX-<side>-P<id>` | written by us (`TradeRequestBuilder.mqh:59,65`) | **NO** — carries candidateId only | `#<seq>` NOT wired (D1) |
| E8 | Local ledger + identity | `Execution\execution_ledger.dat`, `execution_seq.dat` | executionId EX-runId-seq is unique | NOT on the broker |

**The only restart-stable identity token we control that is visible on the broker is the comment — and it currently carries only the run-local candidateId.**

## 4. Objective 4 — Correlation possible WITHOUT D1 (`#<seq>`)

Without `#<seq>`, broker inspection can correlate a candidate to history by: **comment `SCX-<side>-P<id>` + magic + symbol + side**, with volume/price/time as weak attributes.

The decisive defect: **candidateId recycles.** `m_nextId` resets to 1 every run, so "P5" in run 2 does NOT identify the same logical plan as "P5" in run 1. Therefore:

- **A historical match** (`SCX-BUY-P5` + magic + symbol) is **AMBIGUOUS**: it could be the *same* plan already executed (→ must BLOCK), or a *different* plan that recycled id 5 (→ may send). The system cannot distinguish.
- **Absence of a match** is **also AMBIGUOUS**: the prior run's "same" plan may have received a *different* candidateId (counter ordering shifted with new bars), so "no P5 in history" does not prove "this plan never executed".

Conclusion: **without D1, broker correlation is fundamentally ambiguous in both directions.** The only safe policy is BLOCK-on-any-legacy-match *and* BLOCK-on-absence — which is safe but non-viable (it would block every regenerated plan, halting trading after any restart). It is NOT a working duplicate defense.

## 5. Objective 9 — Is D1 genuinely necessary?

**Yes. D1 (`#<seq>`) is a genuine prerequisite for a *correct* B25-03C-E.**

Rationale (proved in §4):
- The broker carries no unique cross-run identity we control except the comment.
- The comment's only current identity content (`P<id>`) is run-local and recycles.
- A working broker-inspection-before-send must be able to say, authoritatively: "this exact execution attempt already produced a broker artifact" (MATCHED) or "this exact attempt provably produced none" (NOT_FOUND). Both require a unique, restart-stable token in the comment.
- `#<seq>` (the B25-03A `BuildComment` tail, `SCX-<side>-P<id>#<seq>`) is exactly that token, and it is **already implemented in frozen B25-03A** (`ExecutionIdentity.BuildComment/ParseSeqFromComment`), just not wired into `TradeRequestBuilder`.

**Mitigating factor (D1 is LOW-RISK):** `CPositionLifecycleManager::ParseEntryDecisionId` (`:597-599`) uses `StringFind("-P")` + `StringToInteger` which stops at the first non-digit, so `SCX-BUY-P5` and `SCX-BUY-P5#123` both parse to `5`. D1 therefore does **not** break the settlement parse surface (B25-03C-B Finding B7 already confirms it is version-agnostic and must not change). D1 also does not change the ledger schema, the identity counter, or H6.

**Verdict: B25-03C-E must remain CONDITIONAL on D1.** A D1-less E can only express the conservative "legacy comment match → BLOCK" rule, which is safe but non-viable; the correct MATCHED/NOT_FOUND distinction requires the unique `#<seq>` tail.

## 6. Current code state (what exists vs. what E needs)

| Capability | Present? | Where |
|---|---|---|
| Live-position census by symbol+magic | YES | `CTradeManager::CountOpenPositions` (C3) |
| Broker history/order/comment scan | PARTIAL | `CExecutionReconciler::HasLegacyCommentMatch` (init-time only, pending executions only) |
| `AlreadySent(executionId)` durable guard | YES (unused in send path) | `CExecutionRecovery.mqh:384`, `CExecutionLedgerWriter.mqh:147` |
| Broker-inspection-BEFORE-send (cross-run) | **NO** | — |
| `#<seq>` in send comment | **NO (D1 unwired)** | `TradeRequestBuilder.mqh:59,65` uses legacy form only |

## 7. Threat model (summary)

- **T1 duplicate execution** (the R9/R12 cross-run re-submit) — OPEN, this mission's target.
- **T2 false NOT_FOUND** — prevented: legacy-only correlation yields AMBIGUOUS, never NOT_FOUND (B25-03C-B `ReconVerdictFromEvidence`).
- **T3 unsafe retry** — prevented: H6 holds uncertain outcomes; reconciliation never re-sends.
- **T4 over-blocking** — the D1-less naive guard would block legitimate regenerated plans; D1 removes this.
- **T5 TOCTOU race** — inspection→send window; addressed in the design race analysis.

---

## Assessment verdict

B25-03C-E is the *required* next gate for cross-run duplicate defense. It is **conditional on D1 (`#<seq>` comment wiring)**, because the broker carries no other unique, restart-stable identity token we control, and candidateId recycles across runs. D1 is a small, low-risk prerequisite: the frozen B25-03A comment primitives already exist, and the settlement parser is already version-agnostic. The design document specifies the broker-inspection decision, race analysis, and TDD plan on that basis.

```
B25-03C-B: CLOSED / PUSHED
B25-03C-E: ASSESSMENT + DESIGN ONLY
D1: NOT AUTHORIZED (but PROVEN PREREQUISITE for correct E)
IMPLEMENTATION: NOT AUTHORIZED
COMMIT / PUSH: NOT AUTHORIZED
```
