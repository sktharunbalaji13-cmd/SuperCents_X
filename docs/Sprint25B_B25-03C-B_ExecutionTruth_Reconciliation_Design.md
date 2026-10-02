# Sprint 25B — B25-03C-B Execution Truth Reconciliation (Design)

- Date: 2026-08-16 (re-aligned to authoritative HEAD 2026-08-16 — H6 Rev 2)
- Type: IMPLEMENTATION-READY DESIGN. No implementation. No commit. No push. B25-03C-C (implementation) NOT authorized.
- Authoritative baseline: **HEAD `157e3a4c02d927569e94eafaec584b043dd5e715`** (H6 Rev 2 send-attempt retry semantics, committed and pushed). All code references verified against committed HEAD (`git show HEAD:<file>`).
- B25-03C-A remains frozen at `e881897e6a12626b2cf9f6cf18992a912cbf7c30` (`ExecutionLedger.mqh`, `Tests/unit/TestExecutionLedger.mqh` — untouched by C1-C7 and by H6 Rev 2).
- H6 dependency: **CONSUMED.** This design consumes the committed H6 Rev 2 4-class retry policy (`TradeManagerRetryPolicy.mqh`, `H6ClassifyPolicy`) and the committed hold-map semantics. The C1-C7 report-vs-code retryability discrepancy (B6) is RESOLVED; dependency D5 is CLOSED.
- Frozen inputs (never modified): B25-03A `67c58d0` (`ExecutionIdentity.mqh` — consumed), B25-03B `a36ea238` (`ExecutionTruth.mqh` — consumed verbatim), B25-03C-A `e881897` (ledger core + tests — frozen integration surface), accepted design `docs/Sprint25B_B25-03C_ExecutionLedger_Design.md` (Phases 1–20, 15 invariants, adversarial A–I), telemetry CSV schema (frozen), TT01/ED01 baselines (frozen), the B25-03B ExecutionTruth documents (`B25-03_ExecutionTruth_Design/Assessment` — FROZEN, untouched).
- Alignment: every section maps to the accepted design's Phases 1–20.
- Scrutiny areas (senior): reconciliation semantics, broker evidence hierarchy, exact boundary between ledger core and recovery/reconciliation orchestration.

---

## 0. Provenance Note (mandatory)

- The 14-file working-tree state observed transiently during the initial audit (C2/C3/C7/H6 work) was stashed externally at 15:44:52 and subsequently **committed by a parallel session as `7d4eecb` (C1-C7 integrity fixes)**.
- The C1-C7 report-vs-code retryability discrepancy was independently reviewed (C1-C7 review: H6 FAIL) and then **remediated by commit `157e3a4` (H6 Rev 2)**, which is the current authoritative HEAD. The design below consumes the committed H6 Rev 2 semantics; no unreviewed claim is imported.
- This session modified only the two B25-03C-B documents; no stash manipulation; no commits; no pushes; no production/test/tooling changes.

---

## 1. Design Principles (from the accepted design, restated for this layer)

1. **Write-ahead INTENT** — no `OrderSend` without a durably flushed `INTENT` event (crash-window closure; Phase 8).
2. **No blind re-send** — an executionId with a terminal record is never re-sent; a non-terminal executionId is never re-sent either; only a broker-verified NO-DEAL may provision a NEW executionId (Phase 6). **H6 Rev 2 note:** the committed `H6_POLICY_RETRY_ELIGIBLE` class (a deterministic transient refusal) IS broker-verified non-execution; its re-attempt provisions a NEW executionId under the SAME decisionId — never a re-send of an existing executionId.
3. **BLOCK-over-GUESS** — every unrecoverable uncertainty blocks the execution path for that plan (verdicts below); AMBIGUOUS never auto-resolves (Invariant 13).
4. **Broker evidence outranks requested values** (Invariant 15) — filled fields come only from DEAL_IN events keyed by dealTicket.
5. **Deterministic reconstruction** (Invariants 5/12) — state is a pure fold over (ledger, eventSeq); wall-clock timestamps are narrative only.
6. **Single writer** — ledger appends happen only from the execution path thread; recovery/reconciliation never append concurrently (Phase 18).
7. **Dormant under NEW/SHADOW** — every ledger/recovery action is gated by the existing `m_executionEnabled` entry-mode contract (TradeManager:164, SymbolContext:623); TT01 dormancy proof is unchanged from B25-03B.
8. **Zero re-derivation** — truth is persisted, never re-derived; `ExecutionTruthRecord` is the event payload (Finding 5). The committed `H6ClassifyPolicy` classifies the RETRY POLICY (dedup/reject/retry/hold), not the broker outcome; it does not re-derive truth.

---

## 2. Broker Evidence Hierarchy (the reconciliation authority ladder)

Ranked; a higher rank always overrides a lower one for the same fact. Conflicting evidence at equal rank → AMBIGUOUS (never majority-vote).

| Rank | Evidence | Source | Trusted facts |
|---|---|---|---|
| E1 | Synchronous `MqlTradeResult` (retcode, order, deal, price, volume) | OrderSend return, same tick | send-instant truth; definitive for FILLED/PARTIALLY_FILLED/REJECTED/ACCEPTED_NO_DEAL |
| E2 | Deal history (`HistoryDealsSelect/Total/GetInteger/GetDouble`) | broker terminal history | deal tickets, prices, volumes, times, position/deal lineage; survives restarts |
| E3 | Order history (`HistoryOrderSelect` by ticket; `HistoryOrderGetInteger(ORDER_TICKET)`) | broker terminal history | order-level truth: requested volume, comment, SL/TP, times; survives restarts |
| E4 | Open positions (`PositionsTotal/Select` + comment) — census restart-stable via C1 stable magic | broker | live position truth; comment correlation token; magic+symbol census is reliable across restarts (C1, committed) |
| E5 | Our ledger events | local durable store | local truth (INTENT/SENT/REJECTED/UNKNOWN/DEAL_IN); never overrides E1–E4 on broker facts |
| E6 | Journal lines, telemetry CSV, counters | local | narrative/audit only; NEVER a source of truth for reconciliation |

Rules:
- **E1+E2 in agreement → RESOLVED.** (Sync deal == deal-history deal: same ticket, matching volume ≤ requested.)
- **E1 TIMEOUT/CONNECTION, later E2 shows a deal → RESOLVED (filled) via DEAL_IN (Invariant 10).**
- **E5 says INTENT, E2/E3/E4 show nothing → NOT_FOUND only if correlation is authoritative (D1 `#<seq>` comment in place, D2-wired settlement); with today's legacy `SCX-*-P<id>` comment → AMBIGUOUS → BLOCKED (B10).**
- **E2/E3 unreachable (broker disconnected) → BROKER_UNAVAILABLE; local INTENT remains pending; never auto-resolve.**
- **E5 corrupt (MID_FILE_CORRUPT) → CORRUPT_LOCAL_STATE → execution BLOCKED for the run, operator review (Invariant 14).**

C1-C7 reliance statement: rank E4's restart-stability depends on C1 (stable magic). This is an audited committed behavior; B25-03C-B uses it only as a census aid, never as an identity authority (identity remains executionId).

---

## 3. Verdicts and Execution State Machine

### 3.1 Per-executionId state (rebuilt by replay)

```
ENUM_EXEC_RECON_STATE:
  EXREC_UNKNOWN           initial (no INTENT seen) — replay artifact only
  EXREC_INTENT            INTENT appended, send not yet attempted
  EXREC_SENT              SENT appended (or sync outcome pending)
  EXREC_REJECTED          REJECTED appended
  EXREC_ACCEPTED          ACCEPTED_NO_DEAL truth recorded, no deal yet
  EXREC_OPEN              >=1 DEAL_IN, remainingVolume > 0
  EXREC_FILLED            DEAL_IN sum == requestedVolume (epsilon)
  EXREC_PARTIALLY_FILLED  DEAL_IN sum < requestedVolume, terminal or not per broker
  EXREC_AMBIGUOUS         insufficient evidence (Invariant 13, sticky)
  EXREC_BLOCKED           BLOCKED event appended (guard)
```

State transitions follow the accepted Phase 4 whitelist, now as a function over replayed events; any other transition at append time is rejected by the core (SEQ/transition legality), and at replay time yields BLOCKED + CORRUPTION.

### 3.2 Verdicts (reconciliation outcomes)

| Verdict | Meaning | Auto-action |
|---|---|---|
| RESOLVED | local state matches broker evidence | none (record RECONCILED event) |
| NOT_FOUND | authoritative correlation proves no broker action | executionId closed as never-sent; new executionId may be provisioned (only with D1 in place) |
| AMBIGUOUS | evidence insufficient | BLOCK this executionId; operator review (Invariant 13) |
| BROKER_UNAVAILABLE | E2/E3/E4 unreachable | keep pending; retry reconciliation on next tick/TerminalInfo connection state; never guess |
| CORRUPT_LOCAL_STATE | ledger scan non-CLEAN-non-recoverable | BLOCK all sends this run; CORRUPTION evidence; operator review |

---

## 4. Reconciliation Semantics (the complete table — scrutiny area 1)

For every case, the sequence is: **replay ledger → resolve pending executions → gate new sends.**

| # | Scenario | Ledger state before | Recovery action | Verdict path |
|---|---|---|---|---|
| R1 | Crash before INTENT flush | nothing | nothing to reconcile; plan was never registered | not applicable |
| R2 | Crash after INTENT flush, before OrderSend | INTENT (no SENT) | broker scan for this executionId (comment `#<seq>` if D1, else legacy comment + time window + volume match) | no broker trace → NOT_FOUND (D1) / AMBIGUOUS→BLOCKED (legacy); executionId never sent; sequence slot consumed (gap legal, Invariant 3) |
| R3 | Crash after OrderSend, before SENT/truth recorded | INTENT (no SENT) | E2/E3/E4 scan; match order by ticket from E1-less window or comment+volume+time | deal found → DEAL_IN replay → FILLED/OPEN; order found no deal → ACCEPTED (pending); nothing → AMBIGUOUS→BLOCKED (legacy) / NOT_FOUND (D1) |
| R4 | OrderSend returns TIMEOUT | INTENT + UNKNOWN | no blind re-send; periodic E2 scan (tick-gated, throttled); late deal → DEAL_IN → FILLED (Invariant 10) | UNKNOWN persists while BROKER_UNAVAILABLE; late deal resolves; else stays UNKNOWN→AMBIGUOUS after terminal window (config) |
| R5 | OrderSend returns CONNECTION | INTENT + UNKNOWN | same as R4 | same as R4 |
| R6 | ACCEPTED_NO_DEAL (PLACED etc.) | INTENT + ACCEPTED | pending; DEAL_IN may attach later (OTT or E2 scan) | ACCEPTED → FILLED/PARTIALLY only with deal evidence |
| R7 | Partial fill (DONE_PARTIAL) | INTENT + DEAL_IN(v1) | remainingVolume = requested − Σ deal volumes (epsilon); later DEAL_IN(v2) appends; dedup by dealTicket (Invariant 7) | PARTIALLY_FILLED → FILLED when Σ == requested (epsilon) |
| R8 | Multiple deals, one send | INTENT + DEAL_IN×N | one event per unique dealTicket; replay dedups (Invariant 7) | FILLED when Σ == requested |
| R9 | Restart, open position from prior run | INTENT + DEAL_IN (if filled) | replay → executionId known; DiscoverPositions correlates via comment (E4, C1-stable census); dedup authority active — no second send | RESOLVED (position matches DEAL_IN) |
| R10 | Restart, pending/unknown order | INTENT + UNKNOWN/ACCEPTED | reconciliation pass at Init (E2/E3 scan) before first Update() | verdict per table |
| R11 | Same-run duplicate plan (broker-visible submission already exists) | INTENT for executionId already sent | same-run candidateId dedup remains as secondary guard (TradeManager:204); executionId dedup is primary (Invariant 6: one INTENT per executionId; duplicate INTENT → BLOCKED) | BLOCKED |
| R12 | Cross-run duplicate intent | two INTENTs, different executionIds (R2+R2 for same market moment) | broker scan for the FIRST; if first produced a position, second is never provisioned (D1 correlation); without D1 → AMBIGUOUS→BLOCKED | AMBIGUOUS→BLOCKED (legacy comment) |
| R13 | Ledger torn tail | scan = TORN_TAIL | `LedgerRecoverTornTail` (core) → CORRUPTION event; last event may be INTENT with no SENT → R2 path | RECOVERABLE |
| R14 | Ledger mid-file corruption | scan = MID_FILE_CORRUPT | no recovery (core rule); CORRUPT_LOCAL_STATE; sends BLOCKED for run; operator review (Invariant 14) | BLOCKED |
| R15 | Broker order parked but deal never comes | INTENT + ACCEPTED, order in E3 | order persists on broker; no auto-cancel (retry/cancel policy out of scope); stays ACCEPTED/OPEN; verdict per evidence | ACCEPTED (no guess) |
| R16 | Divergence: ledger INTENT but broker shows nothing AND no authoritative correlation | legacy comment only | AMBIGUOUS → BLOCKED (B10); never NOT_FOUND (Invariant 13) | AMBIGUOUS |
| R17 | Pre-send failure (C7 fill :233-241, ValidateAll :246-261, volume :294-306, Build :311-323) | INTENT + REJECTED | committed behavior already rejects the plan (`PLAN_REJECTED`) WITHOUT dedup pollution (H6). The writer records REJECTED; no send; executionId consumed (gap legal) | REJECTED — committed baseline already aligned; no design change required |
| R18a | Broker-visible submission (H6 `H6_POLICY_RECORD`: PLACED/DONE/DONE_PARTIAL, or `deal != 0`) | INTENT + SENT | committed H6 records the plan (`RecordSubmitted`, TradeManager:375) — candidateId dedup blocks re-send; writer records SENT, then DEAL_IN per deal | SENT/ACCEPTED → FILLED/PARTIALLY with deal evidence |
| R18b | Permanent refusal (H6 `H6_POLICY_REJECT_PERMANENT`: INVALID*/ONLY_REAL) | INTENT + REJECTED | committed H6 marks the plan `PLAN_REJECTED` (TradeManager:385), NOT recorded; writer records REJECTED; no re-provision | REJECTED (terminal) |
| R18c | Deterministic transient refusal (H6 `H6_POLICY_RETRY_ELIGIBLE`: REQUOTE/REJECT/PRICE_OFF/NO_MONEY/…) | INTENT + REJECTED → NEW INTENT + new executionId on re-attempt | committed H6 leaves the plan `PLAN_EXECUTABLE` unrecorded (TradeManager:388-393) → re-attempted next tick; each attempt = a NEW executionId under the SAME decisionId | REJECTED per attempt; retry = new executionId (broker-verified no-deal) |
| R18d | Uncertain outcome (H6 `H6_POLICY_RETRY_HOLD`: TIMEOUT/CONNECTION/ERROR/NO_CHANGES/ORDER_CHANGED/retcode 0/unrecognized) | INTENT + UNKNOWN | committed H6 holds the plan (TradeManager:397-403; skip :213), NOT recorded, NOT rejected, no intra-session release; the hold map is the reconciliation seed | UNKNOWN/pending — resolved by E2/E3/E4 (R4/R5/R10) |

**Invariant carried: the reconciliation pass NEVER modifies broker state (no cancels, no closes, no re-sends).**

---

## 5. Ledger-Core Boundary Contract (scrutiny area 3 — verbatim contract)

### 5.1 Core is frozen (B25-03C-A at `e881897`, untouched). Orchestration consumes ONLY:

- `LedgerOpenOrCreate(path, runId, ...)` → handle; on scan != CLEAN at open: route to R13/R14 before any send.
- `LedgerAppendEvent(handle, eventType, executionId, from, to, payload)` — the ONLY append entry point; single-writer; refuses non-CLEAN.
- `LedgerScan(handle, result)` — the ONLY integrity authority; called at Init and before every send batch.
- `LedgerRecoverTornTail(handle)` — the ONLY recovery mutation; called only on TORN_TAIL.
- `LedgerHighWaterExecutionSeq(handle, ...)`, `LedgerTailEventSeq(handle, ...)`, `LedgerExtractExecutionSeq(record)` — replay/sync inputs.
- `LedgerChecksumMatches(record)` — defensive re-verify at replay.
- Event vocabulary (9 types) — orchestration emits only: `INTENT, SENT, REJECTED, UNKNOWN, DEAL_IN, RECONCILED, BLOCKED, CORRUPTION, RUN_END`. **The H6 4-class policy maps onto this vocabulary with no new event type: RECORD→SENT, REJECT_PERMANENT→REJECTED, RETRY_ELIGIBLE→REJECTED (+ new INTENT per re-attempt), RETRY_HOLD→UNKNOWN.**

### 5.2 Orchestration responsibilities (NEW code only):

1. **`CExecutionRecovery` (new, `Trading/`)** — Init-time replay + reconciliation pass + pending-state resolution. Pure fold over ledger events; emits RECONCILED/BLOCKED/CORRUPTION; exposes `IsExecutionBlocked()`, `GetPendingExecutions()`, `Verdict(executionId)`. **Its pending set is seeded from the committed H6 hold map (uncertain outcomes, TradeManager:48/458-471) plus ledger UNKNOWN events.**
2. **`CExecutionLedgerWriter` (new, `Trading/`)** — the ONLY appender: wraps `LedgerAppendEvent` with the state machine (legal-transition checks before append), executionId provisioning via `CExecutionIdentity` (AllocateSeq/BuildExecutionId/SetMonotonicFloor — B25-03A consumed, not modified), INTENT-before-send, event-after-send driven by the committed H6 policy, DEAL_IN from OTT/E2, RUN_END at Shutdown.
3. **`CExecutionReconciler` (new, `Trading/`)** — broker evidence queries (E2/E3/E4) + verdict computation; throttled (tick counter / time gate); never appends by itself.
4. **Wire-ins (the ONLY existing-file edits allowed):**
   - `TradeManager.Update()` (:155-404) — insert, before `OrderSend` (:328): `writer.BeginExecution(plan, executionId, out)` (provision + INTENT); replace the OrderSend call site with `writer.ExecuteAndRecord(...)` that consumes the committed H6 policy (`H6ClassifyPolicy(truth.retcode, truth.dealTicket)`) and preserves the current retcode/truth handling; keep `m_submittedIds[]` as same-run secondary guard (:204) and the H6 hold-map skip (:213); gate entire Update on `!recovery.IsExecutionBlocked()`; the pre-send rejection paths (:233-241/:246-261/:294-306/:311-323) additionally emit REJECTED events via the writer (no behavior change otherwise).
   - `SymbolContext.Init()` / `SuperCents_X.mq5 OnInit` (:78) — create identity (runId policy: `"RUN-<buildTag>-<GetTickCount>"` for uniqueness; persisted runId out of scope), open ledger, run recovery, set `SetMonotonicFloor(ledgerHighWater)`.
   - `SuperCents_X.mq5 OnDeinit` (:166) — RUN_END append before Shutdown of TradeManager.
   - `SuperCents_X.mq5 OnTradeTransaction` — NEW handler, record-only DEAL_IN source (design Phase 12; implementation gate B25-03C-C): fires → `writer.RecordDeal(...)` keyed by dealTicket; never transitions state except via whitelist (UNKNOWN/ACCEPTED → FILLED/PARTIALLY_FILLED only with E1/E2-consistent evidence).

### 5.3 Explicit NON-boundaries (forbidden):

- No modification of `ExecutionLedger.mqh`, `ExecutionTruth.mqh`, `ExecutionIdentity.mqh`, `TradeRequestBuilder.mqh`, `PositionLifecycleManager.mqh`, `ActualOutcomeSettler.mqh`, `TelemetryCollector.mqh`, telemetry CSV schema, `TradeValidation.mqh`.
- No `#<seq>` in send comments (D1, separate authorization).
- No cancel/close/re-send of broker orders.
- No new telemetry columns; no changes to `ParseEntryDecisionId`.
- No changes to TT01 runner logic; ledger writes dormant under NEW/SHADOW via existing gate (TradeManager:164).
- No amendment/revert/rewrite of `7d4eecb` or `157e3a4`; no manipulation of any stash.

---

## 6. Execution Path (post-wire, exact sequence, against committed HEAD `157e3a4`)

```
Update() (:155-404):
  if !m_executionEnabled                    -> return            (:164; entry-mode contract; TT01 dormant)
  if recovery.IsExecutionBlocked()          -> return            (CORRUPT_LOCAL_STATE/BLOCKED verdicts)
  for each plan with status == PLAN_EXECUTABLE (:177):
    if writer.AlreadySent(plan)             -> m_totalDuplicates++; continue   (executionId dedup, primary)
    if IsAlreadySubmitted(planId)           -> m_totalDuplicates++; continue   (candidateId dedup, secondary, RAM :204)
    if IsRetryHeld(planId)                  -> continue         (H6 uncertain-outcome hold, :213; no intra-session release)
    C3 position gate (:220) UNCHANGED; C7 fill (:233) UNCHANGED
    ValidateAll (:246) UNCHANGED; C2 sizing (:276) UNCHANGED; IsVolumeValid (:294) UNCHANGED; Build (:311) UNCHANGED
      (each pre-send rejection additionally emits REJECTED via the writer; committed PLAN_REJECTED behavior preserved)
    executionId = writer.Provision(plan)                 // AllocateSeq + BuildExecutionId; INTENT appended+flushed
    if INTENT append failed                -> fail closed (no OrderSend); verdict CORRUPT_LOCAL_STATE path
    truth = CaptureExecutionTruth(request, tradeResult, planId)   (:330; B25-03B, unchanged)
    writer.RecordResult(executionId, truth, H6ClassifyPolicy(truth.retcode, truth.dealTicket))
                                                         // H6 policy drives the event: RECORD->SENT, REJECT_PERMANENT->REJECTED,
                                                         // RETRY_ELIGIBLE->REJECTED (+ NEW INTENT on re-attempt), RETRY_HOLD->UNKNOWN
    ...committed H6 policy switch (:349-403): RECORD logs + RecordSubmitted (:353-377);
       REJECT_PERMANENT -> PLAN_REJECTED (:379-386); RETRY_ELIGIBLE unrecorded (:388-393);
       RETRY_HOLD -> m_totalHeld++ + HoldForRetry (:397-403)...
Recovery (Init):
  identity.Init(runId); ledger.OpenOrCreate; scan = LedgerScan()
  if scan == TORN_TAIL: LedgerRecoverTornTail(); scan = LedgerScan() again
  if scan == MID_FILE_CORRUPT / HEADER_CORRUPT (after recovery): verdict CORRUPT_LOCAL_STATE; BLOCKED
  if scan == CLEAN: reconcile pending executions (R2-R10, R18d) via E2/E3/E4; SetMonotonicFloor(highWater)
OnTradeTransaction (implementation gate C):
  on TRADE_TRANSACTION_DEAL_ADD: writer.RecordDeal(executionId?, dealTicket, volume, price, positionId)
     correlation: dealTicket → DEAL_IN (primary); executionId resolved via comment/#seq or pending set
```

**DP-1 (re-aligned to committed H6 Rev 2):** the earlier decision point is superseded on both halves. (a) Pre-send failures (fill :233-241 / ValidateAll :246-261 / volume :294-306 / Build :311-323) are rejected `PLAN_REJECTED` with no `RecordSubmitted` — committed since 7d4eecb. (b) Send-attempt outcomes are now the committed H6 4-class policy (`H6ClassifyPolicy`, TradeManagerRetryPolicy.mqh): a deterministic transient refusal MAY be retried (new executionId per attempt); an uncertain outcome remains HOLD and requires durable B25-03C reconciliation before release. The design makes NO dedup-behavior change of its own.

---

## 7. State Model (rebuilt, deterministic)

```
struct ReconExecution { string executionId; ulong planId; int candidateId;
                        ENUM_EXEC_RECON_STATE state; double requestedVolume;
                        double filledVolume; ulong dealTickets[]; int dealCount; }
struct ReconDeal { ulong dealTicket; ulong executionSeq; string executionId;
                   double volume; double price; datetime time; }
CExecutionRecovery holds: ReconExecution[] by executionId; ReconDeal[] by dealTicket;
  eventSeq → state fold; highWaterSeq; scan result; blocked flag; pending set (seeded from H6 hold map + UNKNOWN events).
Invariants enforced at fold: 6 (one INTENT), 7 (deal dedup), 8 (filled ≤ requested, ε),
  9 (remaining ≥ 0), 10 (fill needs deal evidence), 11 (whitelist transitions), 12 (determinism).
```

---

## 8. Adversarial Cases (accepted design A–I, carried) + B25-03C-B additions

Accepted A–I (reflexivity/checksum/seq/torn-tail/partial-fill/double-deal/corruption/recovery-idempotence/dormancy) are inherited unchanged: the core already passes them in B25-03C-A tests; the orchestrator's replay fold is the new test surface.

| New case | Expectation |
|---|---|
| J: INTENT append succeeds, process killed, restart, broker shows nothing (legacy comment) | AMBIGUOUS → BLOCKED; no re-send; CORRUPTION not needed (this is not corruption) |
| K: INTENT append succeeds, OrderSend TIMEOUT, broker actually filled (late deal visible in E2) | UNKNOWN → DEAL_IN → RESOLVED(FILLED); exactly one position on broker |
| L: Two runs, same candidateId, first filled, second starts | second run's broker scan (E4, C1-stable census) finds first's position; dedup by executionId; legacy comment → AMBIGUOUS/BLOCKED rather than double-send |
| M: E2 scan during broker disconnect at Init | BROKER_UNAVAILABLE; pending set kept; recovery retried on connection; no verdict guessed |
| N: Duplicate OTT DEAL_ADD for same dealTicket | dedup by dealTicket (Invariant 7); no volume double-count |
| O: Ledger CLEAN at Init but runId differs from last run | executionIds remain unique (runId in ID); reconciliation proceeds on broker evidence, not runId equality |
| P: Pre-send rejection (fill/validation/volume/build) | committed `PLAN_REJECTED` + REJECTED event on ledger; no dedup pollution; executionId consumed (gap legal) |
| Q: Ledger events exist but identity counter file missing/corrupt | B25-03A refuses allocation (COUNTER_CORRUPT) → CORRUPT_LOCAL_STATE → BLOCKED; no sequence re-provisioning |
| R: Send-attempt failure | per committed H6 class: RECORD→SENT (+DEAL_IN); REJECT_PERMANENT→REJECTED; RETRY_ELIGIBLE→REJECTED + new INTENT (retry = new executionId); RETRY_HOLD→UNKNOWN (pending) |

---

## 9. Invariants (Phase 17 carried + B25-03C-B additions)

1–15 of the accepted design: carried verbatim; enforced at writer (reject append) and at replay (BLOCKED).
Additional B25-03C-B invariants (all machine-checkable):
- **B16** INTENT event exists for every executionId that reaches OrderSend (write-ahead; enforceable by replay: any SENT/REJECTED/UNKNOWN/DEAL_IN without prior INTENT → CORRUPTION).
- **B17** At most one INTENT per executionId per ledger (Invariant 6, restated at writer).
- **B18** No ledger event without a CLEAN scan (scan-checked before every append batch).
- **B19** Recovery produces no verdict changes while the ledger grows — reconciliation is a snapshot over (scan result, eventSeq ≤ highWater).
- **B20** Same-run candidateId dedup never suppresses a different executionId (RAM guard is secondary only). The committed H6 semantics preserve this: `RecordSubmitted` populates the candidateId set only for RECORD-class (broker-visible) outcomes, so a retry-eligible plan (new executionId) is never suppressed.
- **B21** Deals from E2 replay and OTT DEAL_IN for the same dealTicket converge to one ReconDeal (dedup key = dealTicket, not source).
- **B22** No reconciliation path calls OrderSend, OrderClose, OrderModify, OrderCancel (broker read-only discipline).
- **B23** Ledger writer and recovery add NO behavior to the committed pre-send rejection paths (PLAN_REJECTED without dedup pollution) — they only emit REJECTED events.
- **B24** B25-03C-B relies on the committed H6 Rev 2 4-class retry policy (`H6ClassifyPolicy` in `TradeManagerRetryPolicy.mqh`) and the committed hold-map semantics at `157e3a4`; no superseded unconditional-record / never-retry behavior is assumed.
- **B25** Every retry-eligible re-attempt provisions a NEW executionId under the SAME decisionId; an executionId is never re-sent (Principle 2 preserved).
- **B26** The recovery pending set is seeded from the committed hold map (uncertain outcomes) plus ledger UNKNOWN events; the two converge to one pending population (dedup key = executionId; pre-ledger held plans key by decisionId).

---

## 10. Acceptance Gates (design-level; implementation in B25-03C-C, harness per Phase 19)

| Gate | Criterion |
|---|---|
| G1 | Replay determinism: identical ledger → identical state (unit-level; new tests keyed by event list, mirroring B25-03C-A method) |
| G2 | Crash-window proof: R2/R3/R4/R18a-d/R13 simulated on persistence-capable harness (B25-03C-F tester/file-virtualization caveat) — no duplicate broker action in any scenario |
| G3 | Evidence ladder: every verdict in §3.2 reachable via a unit-level evidence script; AMBIGUOUS never auto-resolves |
| G4 | Dormancy: NEW/SHADOW run → zero ledger events, zero reconciliation actions (TT01 dormant proof identical to B25-03B) |
| G5 | Boundary: `ExecutionLedger.mqh`, `ExecutionTruth.mqh`, `ExecutionIdentity.mqh`, settlement, telemetry — zero diff; `#<seq>` still unwired; `157e3a4` (and `7d4eecb`) untouched; no stashed/unreviewed-state features imported |
| G6 | Corruption: MID_FILE_CORRUPT → CORRUPT_LOCAL_STATE → BLOCKED; TORN_TAIL → recover → CORRUPTION event present |
| G7 | Idempotence: OTT replay / E2 replay / double recovery → identical state (B21) |
| G8 | Full-suite compile + all prior gates (B25-03A/B/C-A tests) stay GREEN |
| G9 | H6-Rev-2 separation: B25-03C-B tests reference only the committed H6 Rev 2 semantics (4-class policy + hold map); the resolved C1-C7 retryability discrepancy is not relied upon either way |

---

## 11. Out-of-Scope Guardrails (this sprint)

- No production code changes now (B25-03C-B = assessment + design only; B25-03C-C NOT authorized).
- No commit, no push, no runs; frozen baselines untouched; `157e3a4` (and `7d4eecb`) not amended/reverted/rewritten; no stash manipulation.
- D1 (`#<seq>` comment), D2 (settlement correlation), D3 (downtime settlement), D4 (request_id persistence): recorded dependencies, each with its own future authorization. **D5 (independent C1-C7 + H6 review) is CLOSED — completed.**
- No broker order mutation; no retry/cancel policy; no telemetry schema change; no settlement change.
- H6 Rev 2 is committed and accepted; B25-03C-B consumes it; B25-03C-B conclusions are independent of any further C1-C7 governance.

---

B25-03C-B: DESIGN RE-ALIGNED to `157e3a4` (H6 Rev 2 consumed). STOP for senior review. NEXT SENIOR DECISION: review of this re-aligned design (and the companion assessment) before any B25-03C-C authorization.
