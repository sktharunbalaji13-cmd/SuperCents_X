# Sprint 25B — B25-03C-B Execution Truth Reconciliation (Assessment)

- Date: 2026-08-16 (re-aligned to authoritative HEAD 2026-08-16 — H6 Rev 2)
- Type: READ-ONLY assessment. No implementation. No commit. No push.
- Authoritative baseline: **HEAD `157e3a4c02d927569e94eafaec584b043dd5e715`** ("fix: correct H6 send-attempt retry semantics (Rev 2) on live legacy execution path"). All source citations verified against committed HEAD via `git show HEAD:<file>`.
- B25-03C-A remains frozen at `e881897e6a12626b2cf9f6cf18992a912cbf7c30` (ledger core + tests + status doc; unmodified by C1-C7 and H6 Rev 2; not modified by this session).
- H6 dependency: **CONSUMED.** The C1-C7 report-vs-code retryability discrepancy (B6) is **RESOLVED** by commit `157e3a4`; dependency **D5 is CLOSED** (independent C1-C7 review + H6 assessment/design/implementation/verification complete).
- Mandate: B25-03C-B ASSESSMENT + DESIGN authorized; implementation NOT authorized; B25-03C-C NOT authorized.
- Scrutiny areas (senior): (1) reconciliation semantics, (2) broker evidence hierarchy, (3) exact boundary between the ledger core and recovery/reconciliation orchestration.

---

## 0. Provenance Note (repository history during this work)

1. During the initial B25-03C-B audit, the working tree transiently contained a 14-file modified state (C2/C3/C7/H6 work) that was **not committed**; at 15:44:52 an external git operation stashed it (stash@{0}); this session did not create, restore, apply, drop, or modify it.
2. A parallel session subsequently committed that work (plus further changes: closed-bar discipline C4, signal lifecycle C5, H7 sizing formula, tests, report) as **`7d4eecb` — C1-C7 integrity fixes**. The previously-stashed content is therefore now committed.
3. The C1-C7 independent review found the H6 report-vs-code retryability discrepancy (H6 FAIL). A follow-on remediation was authorized and committed as **`157e3a4` — H6 Rev 2**, now the authoritative HEAD (committed and pushed; verified on GitHub).
4. This session's only file activity is the two B25-03C-B documents (untracked). No production/test/tooling file was touched; no stash was manipulated; no commit/push was made.

---

## 1. What B25-03C-B Is

B25-03C-A delivered the **ledger core** (`Trading/ExecutionLedger.mqh`, frozen): a durable, checksummed, append-only event store with recovery primitives (`LedgerScan`, `LedgerRecoverTornTail`). It is pure infrastructure — **nothing in production reads or writes it** (verified at 157e3a4: zero call sites outside the module itself; C1-C7 and H6 Rev 2 did not touch it).

B25-03C-B is the **execution-truth reconciliation** layer: the design (this sprint: assessment + design only) of how production orchestrates

1. **Recovery** — reconstructing durable truth after EA/terminal/OS crashes and restarts from the ledger + broker evidence;
2. **Reconciliation** — resolving every execution to a verdict (RESOLVED / NOT_FOUND / AMBIGUOUS / BROKER_UNAVAILABLE / CORRUPT_LOCAL_STATE) using the broker evidence hierarchy;
3. **Execution discipline** — INTENT-persisted-before-send, no blind re-send, BLOCK-over-GUESS, single-writer append discipline.

---

## 2. Execution State Trace (verified against committed HEAD `157e3a4`)

```
Confluence/TradeCandidateBuilder.mqh:175,231   candidate.id = m_nextId++  (m_nextId init 1, :67; reset 1, :435)  [run-local, UNCHANGED]
Entry/ExecutionPlanner.mqh:214                 plan.entryDecisionId = decision.candidateId                  [run-local, UNCHANGED]
Portfolio/SymbolContext.mqh:623                m_tradeExecutionManager.SetExecutionEnabled(m_entryMode == ENTRY_MODE_LEGACY)
Portfolio/SymbolContext.mqh:704-706            SetPositionSizer/SetRiskPercent/SetMaxPositionsPerSymbol wiring  [C1-C7 C2/C3]
SuperCents_X.mq5:48-52                         inputs InpMagicNumber(27182819)/InpRiskPercent(1.0)/InpMaxPositionsPerSymbol(1)  [C1-C7 C1/C2/C3]
SuperCents_X.mq5:117,120-121                   g_engine.SetMagicNumber/SetRiskPercent/SetMaxPositionsPerSymbol BEFORE g_engine.Init()  [C1-C7 C1]
Trading/TradeManagerRetryPolicy.mqh (NEW @157e3a4)  H6ClassifyPolicy(retcode, dealTicket) -> ENUM_H6_RETRY_POLICY
                                               (RECORD / REJECT_PERMANENT / RETRY_ELIGIBLE / RETRY_HOLD) — single source of truth
Trading/TradeManager.mqh:155-404               Update() — the ENTIRE execution path at HEAD:
   :164-165                                    if(!m_executionEnabled) return          (entry-mode contract, Sprint 17.7A; TT01 dormancy gate)
   :167-169                                    GetPlanCount(); planCount==0 -> return
   :171-178                                    per-plan loop; plan.status != PLAN_EXECUTABLE -> skip
   :180                                        planId = plan.entryDecisionId
   :182                                        m_totalReceived++
   :204-208                                    IsAlreadySubmitted(planId) -> m_totalDuplicates++, continue   [RAM dedup; RECORD-class only]
   :213                                        IsRetryHeld(planId) -> continue   [H6 Rev 2: uncertain-outcome hold; no intra-session release]
   :220-228                                    C3 position gate: CountOpenPositions() >= m_maxPositionsPerSymbol
                                               -> m_totalBlocked++, ORDER-BLOCKED-POSITION-GATE, continue
   :233-241                                    C7 fill price: GetFillPrice(plan.orderType); <=0 -> ORDER-REJECTED-FILL,
                                               SetPlanStatus(PLAN_REJECTED), m_totalFailed++, continue
   :246-261                                    ValidateAll(plan, m_lotSize, ...) fail -> LogOrderFailed, PLAN_REJECTED,
                                               m_totalFailed++, continue   [H6: NOT recorded as submitted — no dedup pollution]
   :267-291                                    C2 position sizing: m_positionSizer.CalculateCached(m_riskPercent,
                                               stopDistancePoints, ACCOUNT_EQUITY) at fill price; fallback m_lotSize
   :294-306                                    IsVolumeValid fail -> LogOrderFailed, PLAN_REJECTED, m_totalFailed++, continue
   :311-323                                    TradeRequestBuilder.Build(plan, volume, request) fail -> LogOrderFailed,
                                               PLAN_REJECTED, m_totalFailed++, continue
   :327-328                                    MqlTradeResult tradeResult; OrderSend(request, tradeResult)   (single send site)
   :330                                        CaptureExecutionTruth(request, tradeResult, planId)   [B25-03B, verbatim]
   :349-403                                    H6 Rev 2 policy switch on H6ClassifyPolicy(truth.retcode, truth.dealTicket):
                                                 RECORD (:353) -> LogOrderSent + RecordSubmitted (:375) + m_totalSubmitted++
                                                 REJECT_PERMANENT (:379) -> PLAN_REJECTED (:385), m_totalFailed++, NOT recorded
                                                 RETRY_ELIGIBLE (:388) -> m_totalFailed++, NOT recorded (plan stays EXECUTABLE -> re-attempt)
                                                 RETRY_HOLD (:397) -> m_totalFailed++, m_totalHeld++ (:401), HoldForRetry (:403), NOT recorded
Trading/TradeManager.mqh:40                   m_submittedIds[] (RAM dedup)
Trading/TradeManager.mqh:48-50                m_retryHoldIds[] (:48), m_retryHoldCount, m_totalHeld   [H6 Rev 2 hold map]
Trading/TradeManager.mqh:44-57                m_totalReceived/Submitted/Succeeded/Failed/Duplicates/Blocked tallies
Trading/TradeManager.mqh:93-96                H6 test seams: GetHeldCount/GetTotalHeld/IsPlanRetryHeld/HoldPlanForRetry
Trading/TradeManager.mqh:138-153              CountOpenPositions(): broker positions, symbol + magic match   [C1-C7 C3]
Trading/TradeManager.mqh:371-379,381-387      IsAlreadySubmitted / RecordSubmitted implementations (RAM array)
Trading/TradeManager.mqh:455-471              IsRetryHeld / HoldForRetry implementations (RAM array, no release)
Trading/TradeValidation.mqh:46,79,101,172,202 GetFillPrice (:46, ASK for BUY / BID for SELL), IsVolumeValid (:79),
                                               AreStopsValid (:101, directional at fill), IsMarginSufficient (:172),
                                               ValidateAll (:202)   [C1-C7 C6/C7]
Trading/TradeRequestBuilder.mqh:59,65          request.comment = "SCX-BUY-P%d" / "SCX-SELL-P%d"  (legacy, NO #<seq>)  [UNCHANGED]
Entry/PositionLifecycleManager.mqh:272         DiscoverPositions() at Init (:129) and per-tick (:141): broker positions by symbol+magic  [UNCHANGED]
Entry/PositionLifecycleManager.mqh:237-238     ParseEntryDecisionId(pos.comment, decId) -> m_contexts[idx].entryDecisionId  [UNCHANGED]
Entry/PositionLifecycleManager.mqh:336-346     on close -> EVENT_POSITION_CLOSED {ticket, entryDecisionId, profit (GetClosedProfit)}  [UNCHANGED]
Telemetry/ActualOutcomeSettler.mqh (GR02A)     Register(candidateId -> telemetry decisionId) RAM pairs; HandleEvent -> ApplyActualOutcome  [UNCHANGED]
Portfolio/SymbolContext.mqh:1547,1579          m_settler.Register(m_pendingCandidateId[i], decisionId)   (GR02A pairing)
Telemetry/TelemetryCollector.mqh:277           runId = "RUN-<buildTag>-<GetTickCount>"   (self-generated, RAM)  [UNCHANGED]
Telemetry/TelemetryCollector.mqh:308           decisionId = ++m_runId                       (run-local, RAM); CSV flush at Shutdown  [UNCHANGED]
Trading/ExecutionIdentity.mqh (B25-03A, FROZEN)  durable counter "Execution\execution_seq.dat" (FILE_COMMON), checksum+read-back,
                                                  reserve-before-use, SetMonotonicFloor, EX-<runId>-<seq>, BuildComment SCX-<side>-P<id>#<seq>
                                                  ZERO call sites in production (verified). UNWIRED.
Trading/ExecutionLedger.mqh (B25-03C-A, FROZEN)  durable event store; ZERO call sites in production (verified). UNWIRED.
SuperCents_X.mq5                                  OnInit (:78) / OnTick (:157) / OnDeinit (:166) ONLY. No OnTradeTransaction handler exists.
```

**Every execution-state decision the EA makes is RAM-only** (B25-03C Finding 1; re-verified at 157e3a4). The only durable artifacts in the entire execution path remain: (a) the broker's own position/order/deal history, (b) the telemetry CSV (flushed at Shutdown only), (c) `execution_seq.dat` (unwired), (d) the ledger file (unwired).

**Committed dedup semantics at 157e3a4 (verified):** pre-send failures (fill-price, ValidateAll, volume, Build) → `PLAN_REJECTED`, **no** `RecordSubmitted` (H6). After OrderSend, `RecordSubmitted` fires **only for `H6_POLICY_RECORD`** (broker-visible submission: PLACED/DONE/DONE_PARTIAL, or `deal != 0`) — NOT for permanent refusals, transient refusals, or uncertain holds.

---

## 3. Restart Behavior Today (verified at 157e3a4)

| Artifact | On EA restart | On terminal restart | Authority |
|---|---|---|---|
| `m_submittedIds[]` dedup set | cleared (Init :121; RAM) | cleared | none — dedup restarts empty |
| `m_retryHoldIds[]` hold set | cleared (Shutdown :431; RAM) | cleared | none — uncertain outcomes become unresolved on restart |
| `m_totalReceived/Submitted/Succeeded/Failed/Duplicates/Blocked/Held` | 0 (constructor) | 0 | — |
| `m_totalFilledPrice` accumulator | 0 | 0 | — |
| Planner / decisions / candidates | rebuilt from fresh market scan (`m_nextId` reset to 1) | rebuilt | run-local IDs restart |
| Magic number (C1) | stable `InpMagicNumber` (27182819), set before Init | stable | config input — restart-stable (NEW vs pre-C1-C7: was `(int)TimeCurrent()`-derived) |
| Position contexts `m_contexts[]` | ZeroMemory + DiscoverPositions (broker truth) | same | broker positions |
| `entryDecisionId` for open positions | re-parsed from broker comment `SCX-*-P<id>` | re-parsed | broker comment (legacy) |
| Settlement (closed positions) | only positions observed closed **while running** produce `EVENT_POSITION_CLOSED`; positions closed during downtime are **never settled** (no deal-history scan at Init) | same | none |
| Telemetry buffer | lost (flush only at Shutdown) | lost | none |
| Open-position profit tracking | rebuilt from broker | rebuilt | broker |

**Finding B1 (no recovery exists — unchanged):** the EA has restart behavior but no restart *recovery*: forget everything the process knew, rediscover the broker's open positions, continue. There is no reconciliation of "what did I send / what did the broker do with it" across a restart boundary. Neither C1-C7 nor H6 Rev 2 addresses this — H6 hold is session-scoped by design.

**Finding B2 (downtime settlement gap — unchanged):** positions closed while the EA was down are invisible to `ActualOutcomeSettler` (RAM pairs, no deal-history scan at Init). Dependency, not B25-03C-B scope.

**Finding B3 (identity is NOT recovered — unchanged):** `execution_seq.dat` and the ledger file are untouched at Init; `SetMonotonicFloor` is never called; nothing prevents sequence reuse after restart; no event tells recovery what happened before the restart. H6 Rev 2 does not address this.

**Finding B3a (held-outcome restart gap — NEW, from H6 Rev 2):** the H6 hold map (`m_retryHoldIds[]`) is RAM-only and is lost on restart; a held (uncertain) plan is neither resolved nor preserved. On restart, a regenerated plan may re-enter the pipeline. This is exactly the population B25-03C-B's durable reconciliation must resolve (R4/R5/R9/R10/R12/R18d) — H6 explicitly does NOT provide restart-safe reconciliation.

---

## 4. Submitted-Order Tracking Today (verified at 157e3a4)

- Dedup key: `planId == plan.entryDecisionId == candidateId` (run-local counter, `TradeCandidateBuilder`), RAM array (`m_submittedIds[]`).
- Pre-send failures (fill-price :233-241, ValidateAll :246-261, volume :294-306, Build :311-323) → `PLAN_REJECTED`, **no dedup pollution** (H6).
- Post-send, `RecordSubmitted` fires **only for `H6_POLICY_RECORD`** (broker-visible submission). Permanent refusals are `PLAN_REJECTED` (unrecorded); transient refusals stay `PLAN_EXECUTABLE` (unrecorded → re-attempt); uncertain outcomes are held (unrecorded).
- The dedup set is what makes a same-run duplicate impossible for broker-visible submissions; it is exactly what a restart loses.

**Finding B4 (crash window, re-verified at 157e3a4):** the remaining same-run crash windows are (a) between `OrderSend` (:328) and `RecordSubmitted` (:375) — and only for RECORD-class outcomes; (b) the held (uncertain) path, which is never recorded and never released intra-session. A crash then restart → empty dedup + empty hold → regenerated plan → second `OrderSend` is possible for both classes. **Unmitigated duplicate-risk windows today.** The ledger INTENT-before-send + reconciliation design closes them (R2/R3/R18a/R18d).

**Finding B5 (same-run dedup vs cross-run dedup — unchanged):** within a run, candidateId dedup is sound for broker-visible submissions; across runs it is meaningless (B25-03C Finding 2). B25-03C-B must define dedup as a property of **executionId** (durable) with broker-side reconciliation as the cross-run duplicate defense.

**Finding B6 (RESOLVED — H6 Rev 2, commit 157e3a4):** the C1-C7 report's claim that send failures "stay retryable (neither marked rejected nor recorded)" was **contradicted by the 7d4eecb code** (unconditional `RecordSubmitted` :340). This discrepancy was independently confirmed (C1-C7 review: H6 FAIL) and then **remediated** by `157e3a4`: the send-outcome path now implements the H6 4-class policy (`H6ClassifyPolicy`), with `RecordSubmitted` restricted to RECORD, permanent refusals rejected, transient refusals retry-eligible, and uncertain outcomes held. **The report-vs-code discrepancy is closed; B25-03C-B consumes the committed H6 Rev 2 semantics.**

---

## 5. Settlement Behavior Today (verified at 157e3a4)

- `PositionLifecycleManager` is the only settlement surface: discovers open positions (broker), tracks RAM contexts, applies BE/trailing, publishes `EVENT_POSITION_CLOSED` with `entryDecisionId` + net profit. **Unchanged by C1-C7 and H6 Rev 2** (not in either commit's file set).
- `ActualOutcomeSettler` (GR02A) maps `candidateId -> telemetry decisionId` (RAM pairs; SymbolContext:1547/1579) and stamps `actualOutcome`/`actualOutcomeSource` on buffered telemetry rows. **Unchanged.**
- `ParseEntryDecisionId` (:597-614) is comment-version-agnostic (`SCX-BUY-P5` and `SCX-BUY-P5#123` both parse to `5`) and **must not change**.
- **Finding B7 (settlement boundary — unchanged):** B25-03C-B must not touch `PositionLifecycleManager`, `ActualOutcomeSettler`, or `TelemetryCollector`.

---

## 6. Broker Evidence Hierarchy (current state vs. what reconciliation needs)

Ranked by the broker-truth rules established in B25-03B/B25-03C (Invariants 10/15: filled fields derive only from broker-confirmed evidence):

| Rank | Evidence | Available today? | Persisted today? | Reconciliation value |
|---|---|---|---|---|
| 1 | Synchronous `MqlTradeResult`: `retcode`, `order`, `deal`, `price`, `volume` | yes (OrderSend return) | journal text only; `request_id` NOT captured | definitive for the send instant (DONE/DONE_PARTIAL+deal = fill truth) |
| 2 | Deal history (`HistoryDealsSelect/Total/GetClosedProfit`) | yes (used for profit) | no (queried on demand) | deal-level truth: ticket, price, volume, time, position link; survives restarts |
| 3 | Order history (`HistoryOrderSelect` by ticket) | yes (MT5 API) | no | order-level truth: requested volume, SL/TP, comment, time; survives restarts |
| 4 | Open positions list (comment, ticket, volume, price, magic) | yes (`DiscoverPositions`; C3 `CountOpenPositions`) | no | position-level truth; the ONLY live broker view after restart |
| 5 | Position/order comment `SCX-*-P<id>` | yes (written by us) | yes (broker-side) | correlation token — candidateId only, **not unique across runs** (B25-03C Finding 3) |
| 6 | Telemetry CSV (runId, decisionId rows) | yes | only at Shutdown | post-hoc audit; NOT broker evidence |
| 7 | Journal (`ORDER-SENT/FAILED/BLOCKED` lines) | yes | yes (log file) | narrative only; not structured state |

**C1-C7 impact on the hierarchy:** C1 (stable magic) makes rank-4 identification restart-stable — a broker census by symbol+magic is now a reliable cross-restart set. B25-03C-B **can rely on this** (it strengthens E4). It does not change ranks 1-3, 5-7.

**H6 Rev 2 impact on the hierarchy:** H6 adds a RAM-side hold set for uncertain outcomes (`m_retryHoldIds[]`, session-scoped) and a deterministic retry-policy classification. These are LOCAL narrative/short-term state — they do not alter the broker evidence ladder (E1–E6). The hold set is, however, the exact local population that reconciliation must consume (Finding B3a).

**Finding B8 (evidence hierarchy exists but nothing consumes it — unchanged):** no code answers "did the broker act on this intent, and with which deal(s)?" — the single function B25-03C-B orchestrates.

**Finding B9 (`request_id` gap — unchanged):** `MqlTradeResult.request_id` is not persisted (`ExecutionTruthRecord` has no field); no `OnTradeTransaction` handler exists (SuperCents_X.mq5: OnInit :78 / OnTick :157 / OnDeinit :166). OTT is a record-only secondary source (design Phase 12); correlation keys: dealTicket; comment `#<seq>` once wired; request_id only with a future record-field authorization.

**Finding B10 (NOT_FOUND can never be proven with today's comment — unchanged):** with legacy `SCX-*-P<id>`, a broker scan for an executionId's deal cannot return authoritative NOT_FOUND (candidateId collisions across runs/symbols) → AMBIGUOUS/BLOCKED, never NOT_FOUND. Closed only by D1 (`#<seq>` comment wiring).

---

## 7. Reconciliation Semantics Gap Analysis (current state at 157e3a4 vs. required semantics)

| Scenario | Required semantic (accepted design) | Today (157e3a4) | Gap |
|---|---|---|---|
| Crash before OrderSend | INTENT on ledger; verdict NOT_FOUND; seq slot consumed (gap legal) | no INTENT exists; nothing happens; no record | ledger not wired (B25-03C-A scope) |
| Crash after OrderSend, before SENT/truth | ledger holds INTENT (write-ahead); broker scan on recovery | crash window: dedup/hold empty on restart, re-send possible (Findings B4/B3a) | **the duplicate-risk window B25-03C-B closes** |
| OrderSend returns TIMEOUT | UNKNOWN recorded; broker scan later; FILLED only with deal evidence (Invariant 10) | TIMEOUT → `H6_POLICY_RETRY_HOLD`: held (RAM, :213/:397-403), NOT recorded, never auto-retried, no release | no durable UNKNOWN; no later scan |
| OrderSend returns CONNECTION | same as TIMEOUT | same (held) | same |
| Accepted, no deal (PLACED/no-deal retcode) | ACCEPTED_NO_DEAL recorded; pending; later DEAL_IN attaches | `H6_POLICY_RECORD` → RecordSubmitted (:375), journal line | pending-state tracking absent (durable) |
| Partial fill (DONE_PARTIAL) | per-deal DEAL_IN accumulation; remainingVolume invariant (8/9) | RECORD; single synchronous `filledVolume`; cumulative not tracked | no accumulation; no remaining-volume model |
| Multiple deals over time | one DEAL_IN per dealTicket; dedup (Invariant 7) | invisible after the send tick | OTT/deal-history DEAL_IN source absent |
| Deal arrives after timeout | late DEAL_IN resolves UNKNOWN → FILLED (Invariant 10) | invisible (held plan has no durable trace) | OTT absent; no periodic history scan |
| Restart with open position from prior run | ledger replay → known executionId; position correlated; duplicate-send defense active | position re-discovered anonymously (comment only) | no replay; no correlation to executionId |
| Restart with pending/unknown order | reconcile via broker order+deal history; verdict, no blind re-send | nothing | no reconciliation pass |
| Pre-send failure (fill/validation/volume/build) | rejected intent as REJECTED; executionId not consumed by a send | `PLAN_REJECTED`, **no** dedup pollution (H6, :233-241/:246-261/:294-306/:311-323) — already aligned | none for this scenario (H6 closed it) |
| Send-attempt failure | four committed H6 classes (§2 trace): RECORD / REJECT_PERMANENT / RETRY_ELIGIBLE / RETRY_HOLD, mapped to SENT/REJECTED/REJECTED+new-INTENT/UNKNOWN | implemented as `H6ClassifyPolicy` + policy switch (:349-403); NOT durable | durable events absent (ledger not wired); H6 hold/retry are session-scoped |
| Divergence (ledger says INTENT, broker shows nothing) | NOT_FOUND/AMBIGUOUS per evidence strength; BLOCK over GUESS | n/a (no ledger) | design must define the verdict table |
| Ledger corruption mid-file | BLOCKED + CORRUPTION record; operator review (Invariant 14) | n/a | core supports it; orchestration must act on it |

**Finding B11 (the entire reconciliation surface is absent — unchanged):** C1-C7 hardened the send path; H6 Rev 2 corrected the send-outcome semantics (retry/hold). Neither added persistence, recovery, OTT, or ledger wiring. B25-03C-B remains the first sprint where reconciliation *semantics* are designed.

---

## 8. Ledger-Core Boundary (exact, for the design)

Frozen core (B25-03C-A, `ExecutionLedger.mqh`, untouched by C1-C7 and H6 Rev 2): `LedgerOpenOrCreate`/`LedgerAppendEvent` (single-writer, refuses non-CLEAN, eventSeq = last-valid-tail+1), `LedgerScan` (CLEAN/HEADER_CORRUPT/TORN_TAIL/MID_FILE_CORRUPT/SEQ_VIOLATION), `LedgerRecoverTornTail` (TORN_TAIL only; CORRUPTION evidence), `LedgerHighWaterExecutionSeq`, `LedgerChecksumHex/Match`, `LedgerBuildHeader/Record/ParseRecord`, `LedgerExtractExecutionSeq`, `LedgerTailEventSeq`; 9-event vocabulary (`INTENT, SENT, REJECTED, UNKNOWN, DEAL_IN, RECONCILED, BLOCKED, CORRUPTION, RUN_END`).

**Orchestration (B25-03C-B) must add — in NEW code or minimal wire-ins only:**
1. **Writer discipline**: INTENT before OrderSend (TradeManager:328); event-after-send driven by the committed H6 policy (`H6ClassifyPolicy`) — RECORD→SENT, REJECT_PERMANENT→REJECTED, RETRY_ELIGIBLE→REJECTED (+ new INTENT per re-attempt), RETRY_HOLD→UNKNOWN; BLOCKED on violations; RUN_END at Shutdown.
2. **Recovery orchestrator** (new module, at Init): scan → rebuild execution state; `execution_seq.dat` + `SetMonotonicFloor(ledger high-water)`; broker order/deal reconciliation; verdicts. Pending set seeded from the committed H6 hold map + ledger UNKNOWN events.
3. **Reconciliation pass** (new module): E2/E3/E4 queries, verdict computation, pending-state resolution (UNKNOWN → FILLED via DEAL_IN; else AMBIGUOUS per Invariant 13).
4. **ExecutionId provisioning in the send path**: `CExecutionIdentity.AllocateSeq`/`BuildExecutionId` before INTENT; `#<seq>` comment tail NOT wired (D1).
5. **OTT handler** (new, EA-level, record-only DEAL_IN per Phase 12) — implementation gate B25-03C-C.

**Boundary rules:** `ExecutionLedger.mqh`/`ExecutionTruth.mqh`/`ExecutionIdentity.mqh` NOT modified (consumed verbatim); `TradeManager.mqh` receives only the minimal hooks (identity provision + ledger appends + recovery-gated sends; RAM dedup remains the same-run secondary guard; the H6 hold-map skip :213 and the H6 policy switch :349-403 are consumed, not changed); `SymbolContext.mqh` init wiring; settlement/telemetry/TT01/ED01/baselines NOT touched; `#<seq>` NOT wired.

**Finding B12 (boundary clean — unchanged):** zero production call sites for the ledger/identity ⇒ wire-ins are entirely additive; the only existing-code edits are `TradeManager.Update` (:155-404) hooks and `SymbolContext`/`SuperCents_X.mq5` init + OTT.

---

## 9. Dependencies / STOP-Condition Findings (B25-03C-B, against 157e3a4)

| Stop condition (mandate) | Finding | Status |
|---|---|---|
| Requires changing B25-03A (`ExecutionIdentity`) | No: consumed (AllocateSeq/BuildExecutionId/SetMonotonicFloor), not modified | NOT TRIGGERED |
| Requires changing B25-03B (`ExecutionTruth`) | No: `ExecutionTruthRecord` consumed verbatim as event payload; `H6ClassifyPolicy` classifies retry POLICY (not the broker outcome), so no truth re-derivation | NOT TRIGGERED |
| Requires changing B25-03C-A ledger core | No: core is the frozen surface; orchestration is new code + minimal wire-ins | NOT TRIGGERED |
| Execution identity becomes ambiguous | No: executionId remains sole durable authority; counter + ledger high-water floor (SetMonotonicFloor); retry = new executionId under same decisionId (B25) | NOT TRIGGERED |
| Reconciliation requires guessing | No: verdicts are RESOLVED / NOT_FOUND / AMBIGUOUS / BROKER_UNAVAILABLE / CORRUPT_LOCAL_STATE; AMBIGUOUS never auto-resolves (Invariant 13) | NOT TRIGGERED |
| Retry policy becomes entangled | No: H6 Rev 2 already owns plan-level retry/hold (session-scoped); B25-03C-B only maps each class to durable events and defines "when may a NEW executionId be provisioned" (retry-eligible = broker-verified no-deal = new executionId; never a re-send of an existing executionId) | NOT TRIGGERED |
| Settlement semantics must change | Not required: settlement untouched; `#<seq>`-aware settlement is a separate dependency | DEPENDENCY RECORDED (D2) |
| Telemetry semantics must change | No: CSV schema frozen; telemetry row lifecycle untouched | NOT TRIGGERED |
| TT01 behavior changes | No: ledger/recovery writes gated by `m_executionEnabled` (TradeManager:164); NEW/SHADOW runs emit zero ledger events and zero reconciliation actions; H6 Rev 2 changed only live LEGACY-path behavior, same gate | NOT TRIGGERED |
| Durable state cannot be made crash-safe | No: write-ahead INTENT + per-event flush + checksums + torn-tail truncation + single-writer; restart-safety validated on a persistence-capable harness (Phase 19, B25-03C-F) | NOT TRIGGERED |
| C1-C7/H6 correctness is assumed | No: C1-C7 was independently reviewed (H6 FAIL) and the H6 discrepancy was remediated by `157e3a4`; B25-03C-B consumes the committed, tested H6 Rev 2 semantics | CLOSED |

**Dependencies recorded (not in B25-03C-B):**
- **D1 — `#<seq>` comment wiring** (BuildComment → TradeRequestBuilder). Strongest broker-side correlation; prerequisite for authoritative NOT_FOUND; changes position comments → touches settlement parse surface → separate authorization.
- **D2 — `#<seq>`-aware settlement correlation** once D1 lands.
- **D3 — downtime settlement** (deal-history scan at Init) — settlement-surface change, separate phase.
- **D4 — request_id persistence** in execution truth (new frozen-record field authorization) if OTT request_id correlation is wanted.
- **D5 — CLOSED**: independent C1-C7 review + H6 assessment/design/implementation/verification are complete; the report-vs-code retryability discrepancy is resolved by commit `157e3a4`.

---

## 10. Re-Alignment Notes (e881897 → 7d4eecb → 157e3a4)

**What changed with C1-C7 (7d4eecb):**
1. **C1 stable magic**: `InpMagicNumber` set before Init → broker census (E4) restart-stable. **B25-03C-B relies on this**.
2. **C3 position gate**: `CountOpenPositions()` (symbol+magic) + `m_maxPositionsPerSymbol`; `m_totalBlocked` tally. No reconciliation-semantics impact.
3. **C2 sizing / C7 fill-price / C6 directional stops**: pre-send math at live fill price; failures → `PLAN_REJECTED`. No reconciliation-semantics impact.
4. **H6 pre-send dedup behavior**: validation/volume/build/fill failures are NO LONGER recorded as submitted → aligns the baseline with the REJECTED-event model.

**What changed with H6 Rev 2 (157e3a4) — the authoritative execution semantics:**
1. **`RecordSubmitted` is now conditional** — only `H6_POLICY_RECORD` (broker-visible submission). Permanent refusals, transient refusals, and uncertain holds are NOT recorded.
2. **Send-outcome model is the H6 4-class policy** (`H6ClassifyPolicy`, `TradeManagerRetryPolicy.mqh`): RECORD / REJECT_PERMANENT / RETRY_ELIGIBLE / RETRY_HOLD.
3. **Retry now exists** — deterministic transient refusals are retry-eligible (plan stays `PLAN_EXECUTABLE`, re-attempted next tick; no retry engine). This supersedes the "never retried" statement.
4. **HOLD now exists** — uncertain outcomes are held (`m_retryHoldIds[]`, no intra-session release), the seed for B25-03C-B reconciliation.
5. **B6 discrepancy RESOLVED**; D5 CLOSED. Line numbers shifted (OrderSend :328, policy switch :349-403, hold skip :213).

**What B25-03C-B can rely on (from the audited committed code):**
- Broker evidence hierarchy E1–E4 as traced; C1-stable census; H6 pre-send rejection without dedup pollution; H6 Rev 2 4-class policy + hold map; single OrderSend site (:328); RAM-only dedup by candidateId; no OTT; no ledger/identity wiring.

**What is now CLOSED (no longer an open item):**
- The C1-C7 report-vs-code retryability discrepancy (B6) — resolved by `157e3a4`. D5 — CLOSED.

**Conclusions that REMAIN valid against 157e3a4** (re-verified): RAM-only dedup by candidateId; crash windows (Findings B4/B3a); no recovery/reconciliation/OTT; `request_id` not persisted; BLOCK-over-GUESS; ledger core and identity unwired; verdict set; settlement/telemetry boundaries; `ParseEntryDecisionId` version-agnostic behavior; B25-03C-A/B25-03B frozen.

**Conclusions that CHANGED vs 7d4eecb:** `RecordSubmitted` is conditional (RECORD-only); retry-eligible and hold classes now exist; B6 resolved; D5 closed; the H6 hold map is the reconciliation seed; several line citations.

---

## 11. Assessment Verdict

B25-03C-B is **safe to design and later implement** against committed HEAD `157e3a4`: the ledger core provides all persistence primitives; the evidence hierarchy exists on the broker side (strengthened by C1); the wire-in points are additive; no frozen module must change. The H6 Rev 2 remediation **strengthens** the design: the hold map is exactly the pending/UNKNOWN population reconciliation must resolve, and the retry-eligible class is exactly the "broker-verified no-deal" condition under which a NEW executionId may be provisioned. The reconciliation semantics (Section 7), the evidence-strength ladder (Section 6), and the core/orchestration boundary (Section 8) are the exact scrutiny targets and are fully specified in the companion design document.

Key committed-state facts the design must respect:
1. No `OnTradeTransaction` handler exists (must be added for OTT-based DEAL_IN — implementation gate C).
2. `request_id` is not persisted anywhere (B9).
3. Dedup authority must migrate from candidateId (RAM) to executionId (durable); same-run candidateId dedup remains a secondary guard; retry = new executionId (B25).
4. Pre-send failures are `PLAN_REJECTED` without dedup pollution (H6); send-attempt outcomes follow the H6 Rev 2 4-class policy (RECORD/REJECT_PERMANENT/RETRY_ELIGIBLE/RETRY_HOLD).
5. All timestamps/ticks are process-local; ledger event timestamps are narrative only — reconstruction is a function of (ledger, eventSeq) only (Invariant 5/12).
6. `ParseEntryDecisionId` is comment-version-agnostic and must not change.
7. H6 Rev 2 is committed and tested; B25-03C-B consumes it; B6 resolved; D5 closed.

---

B25-03C-B: ASSESSMENT RE-ALIGNED to `157e3a4` (H6 Rev 2 consumed) — see `docs/Sprint25B_B25-03C-B_ExecutionTruth_Reconciliation_Design.md` for the implementation-ready design.
