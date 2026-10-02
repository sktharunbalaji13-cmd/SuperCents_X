# Sprint 25B — B25-03C Execution Ledger / Reconciliation (Design)

- Date: 2026-08-15
- Type: Assessment + Design ONLY. No implementation. No commit. No push.
- Baselines: B25-03A `67c58d0` (identity, frozen), B25-03B `a36ea238` (result truth, frozen), GitHub main `a36ea238`.
- Companion: `docs/Sprint25B_B25-03C_ExecutionLedger_Assessment.md` (current-state audit, threat model, findings).
- Objective: EXECUTION TRUTH + DURABILITY + RESTART SAFETY + RECONCILIATION. Not aggressiveness.
- Frozen inputs (never redesigned): `executionId = EX-<runId>-<seq>` (B25-03A), `ExecutionTruthRecord` with broker-confirmed retcode/order/deal/filled price/filled volume/request_id/retcode_external/bid/ask/comment (B25-03B).

### Senior design corrections (applied 2026-08-15, docs only)

The sequence model is clarified and corrected per senior review. Three distinct identities are kept separate and never collapsed:

- **executionId = EX-<runId>-<executionSeq>** — execution-attempt identity (B25-03A, FROZEN).
- **eventSeq** — ledger-event ordering identity; belongs to an individual ledger event, NOT an identity authority.
- **dealTicket** — broker execution evidence identity (broker-issued).

`executionSeq` (identity sequence) and `eventSeq` (event ordering sequence) are different concepts: one execution produces multiple events, each with its own `eventSeq`, all sharing the same `executionId` (which embeds the single `executionSeq`). Reconstruction folds by `eventSeq`. `executionSeq` gaps are legal (reserve-before-use); `eventSeq` is contiguous by construction (tail-derived). Details in Phase 3; invariants in Phase 17; adversarial gate cases in Phase 20.

---

## Phase 1 — Current State Audit

Audited in the companion Assessment doc (Sections 1-2). Summary: every execution-state decision (dedup set, tallies, correlation pairs, settlement contexts) is RAM-only; the only durable artifacts are (a) the B25-03A sequence counter file and (b) broker-side positions/deals with legacy comments `SCX-*-P<id>`. Identified RAM-only items: submitted state, accepted state, order ticket, deal ticket, filled volume, requested volume, remaining volume (untracked), settlement state, dedup state, decision/execution correlation. No production change is authorized; this phase is input only.

## Phase 2 — Durability Threat Model

Full table in the Assessment (Section 3). Every failure mode is classified KNOWN / UNKNOWN / RECOVERABLE / AMBIGUOUS / BLOCKED in both the current and designed states. Non-negotiables derived here:

- **N1 — No blind re-send.** An executionId without a terminal record is never re-sent after restart.
- **N2 — INTENT-before-send.** The intent record is durably written (flushed) BEFORE `OrderSend`.
- **N3 — Evidence-only truth.** No state transition to FILLED/PARTIALLY_FILLED except with broker-confirmed deal evidence.
- **N4 — Block over guess.** AMBIGUOUS/BROKER_UNAVAILABLE/CORRUPT states block execution for that executionId; nothing auto-resolves ambiguity.
- **N5 — Single writer.** Ledger appends happen only from the execution path; readers use shared-read.

## Phase 3 — Ledger Design

### Format decision: line-oriented UTF-8 text (CSV-family, `|`-delimited records)

Rationale against the mandated criteria:

| Criterion | CSV-family text | Structured binary |
|---|---|---|
| Crash tolerance | Append-only lines; torn tail = incomplete last line; checksums per record | Torn mid-record frames; harder to bound |
| Append safety | Open WRITE|READ, seek end, write line, flush per event | Same, but record framing errors more likely |
| Human auditability | Directly readable (mandated) | Requires tooling |
| Deterministic replay | Line order = event order; seq field enforces order | Possible but opaque |
| Corruption detection | Per-record SHA-256 (via `CryptoEncode(CRYPT_HASH_SHA256)`) + structural validation | Possible |
| Recovery speed | Single pass, O(lines), line-length capped | Bounded records but parsing complexity |

The repo precedent (telemetry CSV; B25-03A checksummed counter file) is text-based; the format below extends that pattern with a versioned header and per-record hash.

### File layout (design; not implemented)

```
<MQL5_COMMON>\Execution\execution_ledger.dat        (FILE_COMMON, single file, append-only)

Header (written once at creation, checksummed):
  LEDGER v1 | <createdRunId> | <buildTag> | <gitHead> | <terminalBuild> | <createdTime> | HDR_SHA256

Record (one line per event, fields | -delimited, values never contain '|' or newline by construction;
  escape rule defined for future robustness):
  EVT | <eventSeq> | <executionId> | <eventType> | <timestamp> | <stateFrom> | <stateTo> | <payload fields...> | SHA256(payload)
```

### Sequence model (corrected)

**executionSeq** — the B25-03A identity sequence embedded in `executionId = EX-<runId>-<executionSeq>`. Allocated by reserve-before-use; therefore:
- monotonically non-decreasing across allocations,
- never reused (reuse is BLOCKED),
- **gaps are legal and expected** after reserved-but-unused identities (e.g., allocate 101, crash before INTENT, next allocation 102).

**eventSeq** — the durable ordering sequence of an individual ledger event. It is NOT an identity authority; identity comes from `executionId` (events) and `dealTicket` (broker evidence). The design chooses **option B: contiguous**, with a proof:

1. Single-writer rule (N5): appends only from the execution path; no concurrent writers.
2. `eventSeq` is derived at append time as `lastValidRecord.eventSeq + 1` (never pre-allocated from a counter — there is no reservation step that could create a gap).
3. A crash before append commits nothing; the next append recomputes from the file tail, so no hole appears.
4. A torn/truncated final record is removed by Phase 10 truncation (with a CORRUPTION record); the tail is the last valid record, and the next event continues from `tail + 1`. A truncated record's `eventSeq` was never a valid committed record, so its reuse is not a duplicate.
5. Therefore the visible ledger is always contiguous `eventSeq 1..N`.

Caveat (documented, not a violation): an event whose write+flush both failed is absent from the ledger and, being contiguous, is undetectable by sequence alone. This is acceptable because (a) the safety-critical INTENT cannot be lost — `OrderSend` is gated on INTENT flush success (N2), and (b) other events are reconstructible from broker evidence via reconciliation. Detection relies on evidence, not on sequence holes.

Relationship example (one execution, five events):

```
executionId: EX-RUN-101            (executionSeq = 101)

eventSeq 501 -> INTENT             \  all events carry the same
eventSeq 502 -> SENT               |  executionId; executionSeq is
eventSeq 503 -> DEAL_IN            |  never used as an eventSeq
eventSeq 504 -> DEAL_IN            |  and never repeated within
eventSeq 505 -> RECONCILED         /  the execution's event list
```

### Record schema (event types)

| Event type | Payload fields |
|---|---|
| `INTENT` | executionPlanId (candidateId), symbol, side, requestedPrice, requestedVolume, sl, tp, magic, runId |
| `SENT` | request_id, retcode, retcodeExternal, orderTicket, comment(legacy form), outcome |
| `REJECTED` | retcode, retcodeExternal, reason (from `ExecutionTruthRecord` retcode/comment) |
| `UNKNOWN` | retcode, retcodeExternal, bid, ask, comment (from truth record; outcome TIMEOUT/CONNECTION/BROKER_ERROR/UNKNOWN) |
| `DEAL_IN` | dealTicket, orderTicket, positionId (DEAL_POSITION_ID), filledPrice, filledVolume, dealTime, dealDirection |
| `RECONCILED` | verdict (RESOLVED / NOT_FOUND / AMBIGUOUS / BROKER_UNAVAILABLE / CORRUPT_LOCAL_STATE), evidenceRefs (tickets/comments used), detail |
| `BLOCKED` | reason, detail |
| `CORRUPTION` | truncationOrTornTail detail, first/last valid seq (never silently discards evidence) |
| `RUN_END` | final per-executionId state snapshot summary (audit aid) |

- **Versioning:** header carries schema version; each record is self-describing via eventType; a record with an unknown version/type -> CORRUPTION/BLOCKED (never skip silently).
- **Event ordering:** append order = wall-clock order; `eventSeq` is contiguous and strictly increasing (proof above); replay folds events in eventSeq order. `executionSeq` is carried implicitly by `executionId` and is NEVER used as an ordering key.
- **Schema version policy:** v1 frozen at first B25-03C-A implementation; migration = new file + explicit migration record, never in-place edits.
- **ExecutionId:** every record carries the canonical `EX-<runId>-<executionSeq>` (B25-03A).
- **Timestamp:** `TimeCurrent()` plus `TimeTradeServer()` divergence is not assumed; `timestamp` is informational, `seq` is authoritative for ordering.
- **Checksum/integrity:** SHA-256 over the payload; the header is checksummed; per-record hash enables torn-tail and mid-file corruption detection.

## Phase 4 — State Model

```
INTENT (persisted, never sent yet)
  -> SUBMITTED (broker accepted; orderTicket known, no deal yet)
  -> ACCEPTED (PLACED / DONE with deal==0 / SENT with no deal evidence)
  -> PARTIALLY_FILLED (sum(DEAL_IN.volume) < requestedVolume)
  -> FILLED (sum(DEAL_IN.volume) == requestedVolume, or DONE full-deal evidence)
  -> REJECTED (broker/pre-broker rejection evidence)
  -> UNKNOWN (timeout/connection/broker-error/unresolved — uncertainty recorded, not resolved)
  -> RECONCILING (recovery/reconciliation in progress — never guessed)
  -> RESOLVED (terminal: reconciled to a verified truth; includes NOT_FOUND after broker inspection)
  -> BLOCKED (terminal: no safe action; requires operator/senior review)
```

Legal transitions (whitelist; anything else is an invariant violation -> BLOCKED):

| From | To | Condition |
|---|---|---|
| INTENT | SUBMITTED | broker SENT evidence (truth record, order ticket) |
| INTENT | REJECTED | broker rejection evidence (truth record) |
| INTENT | UNKNOWN | truth outcome TIMEOUT/CONNECTION/UNKNOWN/BROKER_ERROR |
| SUBMITTED | ACCEPTED | accepted without deal evidence (PLACED / DONE deal==0) |
| SUBMITTED | PARTIALLY_FILLED | DEAL_IN evidence |
| SUBMITTED | FILLED | DEAL_IN full volume or DONE-with-deal truth |
| SUBMITTED | UNKNOWN | no deal evidence within wait horizon; uncertainty recorded |
| ACCEPTED | PARTIALLY_FILLED / FILLED | DEAL_IN evidence (**only** after broker evidence — never by request values) |
| ACCEPTED | REJECTED | later broker rejection (order cancelled) |
| PARTIALLY_FILLED | PARTIALLY_FILLED | additional unique DEAL_IN |
| PARTIALLY_FILLED | FILLED | cumulative volume reaches requested |
| UNKNOWN / SUBMITTED / ACCEPTED / PARTIALLY_FILLED | RECONCILING | reconciliation session starts |
| RECONCILING | RESOLVED | verdict with evidence |
| RECONCILING | BLOCKED | verdict AMBIGUOUS / BROKER_UNAVAILABLE / CORRUPT_LOCAL_STATE |
| any non-terminal | BLOCKED | ledger write failure / corruption / impossible transition |

**UNKNOWN -> FILLED is legal ONLY after broker evidence** (a verified DEAL_IN or history deal for the execution). Never by requested values or time alone.

**Partial-fill evolution:** `requestedVolume` (from INTENT) -> `filledVolume = Σ(DEAL_IN.volume for unique dealTickets)` -> `remainingVolume = requestedVolume - filledVolume` (invariant >= 0; no strategy policy for remaining volume — policy is explicitly out of scope).

## Phase 5 — Restart Recovery

Startup sequence (design):

1. **Read ledger**: load header, validate schema version and header checksum.
2. **Validate integrity**: per-record SHA-256; detect torn tail / mid-file corruption (Phase 10).
3. **Rebuild in-memory state**: fold events in eventSeq order (contiguous); reconstruct per-executionId state map + per-deal dedup set (dealTickets) + monotonic floor = max executionSeq observed across all INTENT records (gaps ignored — floor is a high-water mark, not a continuity requirement).
4. **Feed `SetMonotonicFloor(floor)`** to B25-03A identity (frozen hook — read-only use).
5. **Identify unresolved executions**: any executionId in {INTENT, SUBMITTED, ACCEPTED, PARTIALLY_FILLED, UNKNOWN, RECONCILING}.
6. **Inspect broker state**: for each unresolved executionId, query broker orders/positions/history using available evidence (order ticket, request_id, comment, position id). Never assume missing local state = missing broker state.
7. **Reconcile** per Phase 6 verdicts.
8. **Resolve or BLOCK**: RESOLVED/NOT_FOUND -> terminal record; AMBIGUOUS/BROKER_UNAVAILABLE/CORRUPT -> BLOCKED record; execution for that executionId stops.

No blind retry, no re-send, no guessing.

## Phase 6 — Reconciliation

Evidence hierarchy (highest first):

1. **Deal ticket** (unique, broker-issued) — strongest.
2. **Order ticket** (broker-issued, may map to multiple deals).
3. **executionId / comment correlation** — `SCX-*-P<id>#<seq>` (once wired) or legacy `SCX-*-P<id>` (weaker: candidateId repeats across runs).
4. **Broker history** (orders + deals + positions filtered by symbol/magic/time).
5. **Symbol + direction**.
6. **Volume** (requested vs position volume).
7. **Price/time window** (fill price vs request price within deviation; time proximity).

Verdict rules (never "closest wins"):

| Verdict | Condition |
|---|---|
| RESOLVED | exactly one deal/order/position matches a high-rank evidence item (deal ticket or exact executionId/comment) |
| NOT_FOUND | broker history inspected with **sufficiently strong evidence** that the execution never reached the broker (see rule below) |
| AMBIGUOUS | >= 2 candidates tie at the highest available rank; or only low-rank (volume/time-window) evidence exists and is inconclusive; or no executionId-level correlation exists at all |
| BROKER_UNAVAILABLE | cannot inspect broker state (disconnect, history unavailable) |
| CORRUPT_LOCAL_STATE | local ledger/evidence unreadable beyond the torn tail |

**NOT_FOUND evidence-strength rule (senior correction 1).** NOT_FOUND may be issued ONLY when the broker scan establishes non-existence with evidence strong enough to prove the execution never reached the broker — e.g., verified absence of the exact order ticket / deal ticket / exact `executionId`/`#<seq>` comment under an exhaustive symbol + magic + time-window scan. Because `#<seq>` wiring is a future dependency, the broker today carries only the legacy comment `SCX-*-P<id>`: after INTENT-persisted / OrderSend / crash-before-SENT, the ledger knows `executionId`, `candidateId`, symbol, side, requested price/volume, but the broker may hold only `SCX-BUY-P5`. **Absence of an executionId match is therefore NOT sufficient for NOT_FOUND.** When the only available correlation is legacy `P<id>` plus weak attributes (symbol, direction, volume, time), the verdict MUST be **AMBIGUOUS** — never NOT_FOUND. This follows the governing principle BLOCK over GUESS.

AMBIGUOUS remains AMBIGUOUS. It is recorded as such and blocks that executionId until a human/senior decision or a higher-rank evidence source appears. Reconciliation never fabricates a candidate, never picks "closest", and never downgrades a legacy-correlation miss to NOT_FOUND.

## Phase 7 — Durable Deduplication

- **Identity authority remains `executionId`** (B25-03A). No second identity namespace is created.
- **Prevention of accidental second submission:**
  1. **INTENT-before-send** (N2): `OrderSend` is only reached after the INTENT record is durably flushed; the ledger is checked for an existing non-terminal INTENT/SUBMITTED/ACCEPTED for that executionId.
  2. **Durable dedup set**: `m_submittedIds` becomes "ledger-backed" — the in-RAM array is rebuilt from the ledger at startup (Phase 5 step 3), and `RecordSubmitted` corresponds to the durable SENT/ACCEPTED record.
  3. **Broker inspection before send** (recovery rule): if the broker shows a position/order matching the decision (comment `P<id>`; `#<seq>` when wired) the plan is treated as already-executed and not re-sent.
- **Allowed continuations (not duplicates):** partial-fill continuation (new unique DEAL_IN, same executionId), broker-side lifecycle events (order cancelled -> REJECTED record), reconciliation events (RECONCILED/UNKNOWN resolution) — all are new event types on the same executionId, never a second INTENT.

**Identity boundary across restarts (senior correction 2).** The durable dedup authority (same executionId) and the *regenerated intent* case are distinct and must not be conflated:

```
Run 1:  candidate 5 -> EX-RUN1-101 -> broker execution
                         CRASH
Run 2:  candidate 5 -> EX-RUN2-102   (NEW executionId, same candidateId)
```

- **Same executionId** -> durable ledger dedup (invariants 1/2/6): an executionId is never sent twice, and never receives a second INTENT.
- **New executionId representing a regenerated plan after restart** -> NOT covered by executionId dedup (the two executionIds are intentionally different). The ONLY cross-restart duplicate defense for this case is broker-side reconciliation: recovery's broker inspection before any send (Phase 5 step 6, Phase 7.3) must establish whether the regenerated decision already executed on the broker.
- **If broker correlation is insufficient** (e.g., only legacy `P<id>` plus weak attributes) -> the regenerated intent is NOT sent; the plan is BLOCKED (verdict AMBIGUOUS / BROKER_UNAVAILABLE per Phase 6) until higher-rank evidence appears or a human/senior decision is made.
- **Equivalence is NEVER inferred from candidateId alone** — candidateId is run-local (Assessment Finding 2) and cannot be the durable dedup authority; a same-candidateId, different-executionId pair is a reconciliation question, not a dedup hit.
- **Retry policy is NOT defined here** (mandate). The only rule is negative: no second INTENT for the same executionId, ever; AMBIGUOUS blocks.

## Phase 8 — Crash-Window Proof

| Window | Duplicate execution possible? | Proof / rule |
|---|---|---|
| A. before INTENT persisted | **Possible if the system re-sends the regenerated plan after restart.** | Closed by N2 + N1: no send without a durable INTENT; a crashed decision is only re-sent after restart if the plan is regenerated AND recovery's broker inspection (Phase 7.3) finds no matching broker artifact. With legacy comments, cross-run matching is AMBIGUOUS -> BLOCK (no send). With `#<seq>` (future wiring) it is exact. |
| B. after INTENT persisted | Not possible (no re-send). | INTENT exists -> recovery inspects broker; indeterminate INTENT (no SENT) is resolved via broker evidence or NOT_FOUND; never re-sent. |
| C. after SUBMITTED persisted | Not possible (no re-send). | SUBMITTED -> broker inspection with orderTicket/comment. |
| D. before broker send | Not possible. | The request never reached the broker; local state cannot distinguish D from E, so recovery issues NOT_FOUND **only** when the broker scan meets the Phase 6 evidence-strength rule; otherwise AMBIGUOUS -> BLOCK. No order exists to duplicate; nothing is re-sent. |
| E. after broker send, before local persistence | **Possible only if the system re-sends instead of inspecting.** | Closed by N1/N2 discipline: recovery must inspect broker (positions/orders/history by comment/ticket) before any action; a found artifact -> RESOLVED; inconclusive -> AMBIGUOUS -> BLOCK. The window itself cannot be eliminated (it is inherent to distributed execution); the design eliminates the *action* that would duplicate. |
| F. after broker response, before local persistence | Same as E. | Same rule; the truth record may be lost, so the response evidence is reconstructed from broker inspection. |
| G. after ACCEPTED persisted | Not possible. | Record exists; deal events attach later (Phase 9). |
| H. after DEAL persisted | Not possible. | Filled; duplicate DEAL_IN detection by dealTicket. |
| I. during partial-fill update | Not possible. | Idempotent per-deal-ticket accumulation; transition legality enforced. |
| J. during settlement | Not possible. | Settlement is a read-only observer (positions/history); ledger writes are independent; settlement never sends. |

Every window where duplication could occur (A, E, F) is closed by the *absence of a re-send action* plus broker inspection, not by assuming the impossible (atomic send+persist). A/E/F are marked **safe-by-discipline**; if a future phase weakens N1/N2, these windows revert to BLOCKED.

**Explicit crash-safety claim (senior correction 4).** `FileFlush` provides durable persistence of the terminal's buffered file data, but it does **NOT** make `OrderSend` + ledger persistence atomic. The distributed crash window cannot be eliminated — there is no atomic "send and persist" primitive. Safety comes exclusively from: **INTENT-before-send + no blind resend + broker inspection + evidence-based reconciliation + BLOCK over ambiguity**. Acceptance tests must prove *"no crash window permits automatic duplicate submission"*; they must NOT claim *"ledger persistence and broker execution are atomic"*.

## Phase 9 — Partial Fills

- **Cumulative truth:** `filledVolume = Σ(DEAL_IN.volume)` over valid, unique DEAL_IN events (unique = dealTicket not previously seen; Invariant 4). `remainingVolume = requestedVolume - filledVolume`.
- **Duplicate deal detection:** dedup set of dealTickets per executionId, loaded from ledger at recovery; a repeated dealTicket produces no volume and no state change (logged at debug; invariant-4 guard).
- **Terminal partial state:** PARTIALLY_FILLED is terminal when (a) the position is closed (settlement evidence), or (b) reconciliation resolves the remainder per Phase 6 verdicts — NOT_FOUND only under the evidence-strength rule (existing deal/order tickets give strong correlation for the remainder scan), otherwise AMBIGUOUS / BROKER_UNAVAILABLE — or (c) an explicit BLOCKED record is written. No strategy policy for remaining volume is defined (out of scope).

## Phase 10 — Torn Tail / Corruption Recovery

| Condition | Classification | Recovery |
|---|---|---|
| Truncated last record (EOF mid-line) | RECOVERABLE | Truncate to the last full, checksum-valid record; append a CORRUPTION record documenting the truncation (evidence is not silently discarded). |
| Partial write of last record (bad SHA-256) | RECOVERABLE | Same as above. |
| Checksum mismatch on a mid-file record | **BLOCKED** | Stop replay at the first bad record; do not skip; do not guess; record CORRUPTION; execution disabled for affected executionIds; operator review required. |
| Malformed row (wrong field count / bad type) | BLOCKED (mid-file) / RECOVERABLE (last line only) | Last line -> truncate+document; otherwise BLOCKED. |
| Duplicate executionSeq (same executionSeq in two executionIds / INTENTs) | BLOCKED | executionSeq is never reused (Invariant 2); reuse indicates replay or writer violation. |
| Gapped or repeated eventSeq | BLOCKED | eventSeq is contiguous by construction (Phase 3 proof); a hole or repeat indicates a writer violation. A truncated record's eventSeq is not a valid committed record — its reuse after truncation is legal and not a violation. |
| Missing sequence (eventSeq hole) | BLOCKED | Contiguity violated; do not auto-fill holes. |
| Impossible state transition (e.g., FILLED -> INTENT) | BLOCKED | Enforce whitelist (Phase 4); record CORRUPTION. |
| Header missing/version unknown | BLOCKED | Refuse to interpret; fresh start requires explicit new file. |

Rule: **RECOVERABLE = provably-last-record damage only; everything else = BLOCKED.** No evidence is discarded without a CORRUPTION record.

## Phase 11 — Broker/Local Divergence

| LOCAL | BROKER | Safe outcome |
|---|---|---|
| UNKNOWN (timeout/connection) | FILLED (deal found) | RESOLVED as FILLED with deal evidence (Invariant 7 honored — evidence exists). |
| FILLED (synchronous deal) | no matching deal in history | Deal may be unflushed broker-side or history window issue: re-inspect (deferred scan); if confirmed absent after a verified full scan -> AMBIGUOUS (do not downgrade to NOT_FOUND based on a possibly-stale view); BLOCK pending review. |
| PARTIALLY_FILLED | additional deal exists | Attach the new deal as DEAL_IN; cumulative volume updates; legal transition PARTIALLY_FILLED -> PARTIALLY_FILLED/FILLED. |
| record exists | broker history unavailable | BROKER_UNAVAILABLE; keep state, retry inspection later (reconciliation session, not re-send); BLOCK execution for that executionId until evidence appears. |

Never conclude "broker has no deal" from a single snapshot — verification requires a completed history scan (deferred-scan discipline).

## Phase 12 — OnTradeTransaction

Role: **B — secondary event source (record-only observer).** Primary truth remains the synchronous `MqlTradeResult` (B25-03B). OTT supplements (does not replace):
- asynchronous fills (deal arriving after TIMEOUT/CONNECTION),
- partial-fill continuation (DEAL_IN events per deal),
- deal lineage (deal ticket -> position id -> position close for settlement correlation),
- restart recovery does NOT depend on OTT (broker history scan is the recovery source; OTT is an in-process accelerant).

Wiring rule: OTT events produce DEAL_IN records keyed by dealTicket only when the executionId is in {SUBMITTED, ACCEPTED, PARTIALLY_FILLED, UNKNOWN, RECONCILING}; all other cases are ignored as not-ours (no state invention). `request_id` correlation from the SENT record is the preferred match; comment match is the fallback.

## Phase 13 — Ledger ↔ B25-03B

`ExecutionTruthRecord` is consumed verbatim as the payload of SENT/REJECTED/UNKNOWN events:

| Truth field | Ledger usage |
|---|---|
| executionPlanId | INTENT/SENT payload (candidateId) |
| requestId | SENT payload (broker correlation key) |
| retcode / retcodeExternal | SENT/REJECTED/UNKNOWN payload |
| outcome | selects the event type; never re-classified by the ledger |
| requestedPrice / requestedVolume | INTENT + SENT (requested track; never truth) |
| filledPrice / filledVolume | DEAL_IN payload (broker-confirmed only) |
| dealTicket / orderTicket | DEAL_IN / SENT payload; dedup keys |
| bid / ask / brokerComment | UNKNOWN/SENT payload (context preserved) |
| capturedTime | event timestamp reference |

Rules: B25-03B is NOT modified; truth semantics are NOT duplicated (the ledger stores, it does not classify); write-once is inherited (new evidence = new events, never mutation of a prior record).

## Phase 14 — Ledger ↔ Settlement

- Settlement (`PositionLifecycleManager`, `ActualOutcomeSettler`) is unchanged by B25-03C.
- Required future integration points (dependencies, recorded):
  1. Position-close correlation via executionId: requires `#<seq>` in the comment (separate future phase; touches settlement parse surface).
  2. Restart reconstruction of open-position contexts from ledger DEAL_IN records (positionId present in DEAL_IN) — future; contexts remain RAM-only in B25-03C.
- If a later phase must change settlement (e.g., seq-aware parse), it is a **separate dependency with its own authorization** — it is NOT part of B25-03C.

## Phase 15 — Telemetry Boundary

- `executionId` and telemetry `decisionId` stay separate namespaces (Assessment Section 6). No telemetry schema change.
- The only allowed cross-reference: ledger INTENT events carry `executionPlanId` (candidateId), which the existing candidateId -> decisionId mapping (`ActualOutcomeSettler`) can join to telemetry rows externally. B25-03C does not modify telemetry.
- Evidence basis: no current telemetry consumer needs executionId; provenance columns (runId/buildTag/gitHead) are telemetry's own, unchanged.

## Phase 16 — TT01 / ED01 Impact

- Ledger writes are gated by the same execution gate (`TradeManager.mqh:121`, `m_executionEnabled`, set from `ENTRY_MODE_LEGACY` at `SymbolContext.mqh:603`): NEW/SHADOW collection runs emit **zero** ledger events.
- Dormancy acceptance: a NEW-mode run must produce no new journal lines, no ledger file, and byte-identical TT01 baselines (same proof shape as B25-03B).
- TT01 and ED01 tooling/baselines are NOT modified. Any B25-03C validation run uses the isolated execsim harness (gitignored artifacts), never TT01/ED01.

## Phase 17 — Invariants (machine-checkable)

1. **executionId uniqueness** — no two executions share an `executionId`; `executionId = EX-<runId>-<executionSeq>` derives from the B25-03A counter.
2. **executionSeq never reused** — an `executionSeq` appears in at most one execution's INTENT; reuse is BLOCKED.
3. **executionSeq gaps allowed** — reserve-before-use makes gaps legal and expected; a gap is never a violation and never auto-filled.
4. **eventSeq unique** — every committed event has a distinct `eventSeq`; no repeats among valid records.
5. **eventSeq ordering deterministic** — replay order = eventSeq order; reconstruction is a function of (ledger, eventSeq order) only.
6. **One INTENT per executionId** — at most one INTENT event per executionId (duplicate INTENT -> BLOCKED).
7. **Deal counted once per executionId** — a dealTicket accumulates volume exactly once per executionId (dedup set).
8. **filledVolume <= requestedVolume** (with epsilon for broker precision).
9. **remainingVolume >= 0**.
10. **UNKNOWN -> FILLED requires broker evidence** — no transition to FILLED/PARTIALLY_FILLED without a verified deal.
11. **Valid state transitions only** — whitelist (Phase 4); violation -> BLOCKED + CORRUPTION record.
12. **Restart reconstruction deterministic** — same ledger, same rebuilt state (fold by eventSeq; no wall-clock dependence).
13. **Ambiguity never auto-resolves** — AMBIGUOUS stays AMBIGUOUS until higher-rank evidence or human decision.
14. **Corruption never silently disappears** — every RECOVERABLE handling writes a CORRUPTION record; BLOCKED requires operator review.
15. **Broker evidence outranks requested values** — filled fields derive only from broker-confirmed events.

Every invariant is unit-testable at the pure-function level (B25-03C-A test suite) and enforced at the writer (rejecting violating appends) and at replay (BLOCKED).

## Phase 18 — Security / Failure Safety

| Failure | Fail-safe behavior |
|---|---|
| Disk failure / write error | INTENT write fails -> execution for that plan is BLOCKED before OrderSend; existing records intact; state recorded as BLOCKED (log + journal). |
| Permission failure | Same as disk failure; directory creation failure -> BLOCKED (mirror B25-03A FolderCreate pattern). |
| Corrupted ledger | Phase 10 rules; mid-file corruption -> BLOCKED, operator review; no auto-repair. |
| Counter corruption | B25-03A refuses allocation (COUNTER_CORRUPT); plus ledger floor prevents rollback reuse; execution stops for allocations (no sends with unverifiable identity). |
| Broker unavailable | BROKER_UNAVAILABLE verdict; unresolved executionIds stay RECONCILING; no re-send, no guess, no downgrade. |
| Reconciliation ambiguity | AMBIGUOUS -> BLOCKED for that executionId; recorded; senior/operator decision required. |

System preference is uniformly **BLOCK over GUESS**.

## Phase 19 — Implementation Plan (future, per-gate)

Decomposition chosen on evidence (dependency order; each sub-phase has its own authorization gate and STOP-if-violation rule):

- **B25-03C-A — Ledger core.** Header/versioning, record schema, SHA-256 checksums, append+flush writer, replay reader, torn-tail truncation, corruption classification. Unit tests (pure functions). Zero production wiring. Gate: G1, G8 (subset).
- **B25-03C-B — Event wiring (dormant).** INTENT-before-send + SENT/REJECTED/UNKNOWN records at the B25-03B capture point, gated by `m_executionEnabled`; NEW/SHADOW dormancy proof. Gate: G2, G10, plus dormancy evidence (zero events in NEW mode; TT01 byte-identical).
- **B25-03C-C — State machine + restart recovery.** In-memory state reconstruction, legal-transition enforcement, startup bootstrap, monotonic floor feed to B25-03A. Gate: G3, G4, G11 (deterministic rebuild).
- **B25-03C-D — Reconciliation.** Broker inspection (orders/positions/history), evidence hierarchy, verdicts, deferred-scan discipline, divergence model. Gate: G6, G9.
- **B25-03C-E — Durable dedup + `#<seq>` wiring decision.** Ledger-backed dedup set; broker-inspection-before-send; the `#<seq>` comment wiring is evaluated here as an *optional separate dependency* (it changes the settlement parse surface — must be authorized on its own and is NOT a default part of B25-03C).
- **B25-03C-F — Adversarial crash testing.** Fault injection (kill mid-write, torn tail, disk-full simulation, duplicate events, impossible transitions), restart loops, determinism soak. Note (Assessment): tester file virtualization must be validated — restart-safety evidence requires a persistence-capable harness (dedicated agent runs, gitignored artifacts). Gate: G5, G7, G8 (full), G4 (soak).

## Phase 20 — Design Acceptance Gates (future implementation)

- **G1 Schema correctness** — all event types round-trip (write -> read -> fields identical); header/version validated; unknown version refused.
- **G2 Append durability** — after every event, a fresh reader sees the event with valid checksum; flush-on-write verified; crash-during-write leaves at most a detectable torn tail; committed `eventSeq` values are unique and contiguous from the tail.
- **G3 Crash recovery** — simulated crashes at Phase 8 windows A-J: rebuilt state equals pre-crash state for all terminal records; unresolved executions enumerated. Explicit claim tested: **no crash window permits automatic duplicate submission** (never "persistence and execution are atomic").
- **G4 Restart determinism** — same ledger -> same rebuilt state across N restarts (byte-identical reconstruction, fold by eventSeq).
- **G5 Duplicate prevention** — no second INTENT per executionId; duplicate DEAL_IN contributes zero volume; broker-inspection-before-send prevents regenerated-plan duplicates (A/E/F windows exercised); every executionId maps to exactly one executionSeq.

**Adversarial gate cases (senior correction 6) — required in G3/G4/G5 and the B25-03C-A unit suite:**

| # | Case | Expected |
|---|---|---|
| A | executionSeq reserved, then crash before INTENT; next allocation proceeds | Gap accepted (executionSeq 101 reserved, 102 allocated; no violation, no auto-fill) |
| B | two executions with different executionSeq | Distinct executionIds (`EX-RUN-101`, `EX-RUN-102`; invariant 1) |
| C | one execution with 5 events (INTENT, SENT, DEAL_IN, DEAL_IN, RECONCILED) | 5 unique eventSeq values, all carrying the same executionId (invariant 4/6) |
| D | restart after eventSeq tail-read but before append | No duplicate eventSeq: nothing committed, next append continues from tail+1 (contiguity proof) |
| E | crash after INTENT but before OrderSend | No automatic resend; broker inspection; with only legacy `P<id>` correlation the verdict is AMBIGUOUS -> BLOCKED (never re-send; NOT_FOUND only with strong evidence) |
| F | crash after OrderSend but before SENT persistence | Broker inspection required; no blind resend; absence of an executionId match is NOT sufficient for NOT_FOUND while `#<seq>` is unwired -> legacy-only correlation yields AMBIGUOUS -> BLOCKED |
| G | duplicate DEAL_IN with same dealTicket | Zero additional volume; dealTicket counted once (invariant 7) |
| H | mid-file corruption | BLOCK (invariant 14; no silent skip) |
| I | torn final record | RECOVERABLE per Phase 10 rule: truncate to last valid record + CORRUPTION record |
- **G6 Reconciliation correctness** — each Phase 6 verdict produced exactly as specified; AMBIGUOUS never auto-resolves; NOT_FOUND only after a broker scan with sufficiently strong evidence (verified absence of exact order/deal ticket or executionId/`#<seq>` correlation under an exhaustive symbol/magic/time scan); legacy-`P<id>`-only correlation must yield AMBIGUOUS, never NOT_FOUND. Regenerated-plan case: a new executionId for the same candidateId after restart is reconciled via broker inspection (never inferred from candidateId); insufficient correlation -> BLOCKED (Phase 7 identity boundary).
- **G7 Partial-fill correctness** — cumulative volume, remaining volume, invariants 5/6 hold across multi-deal and duplicate-deal sequences.
- **G8 Corruption handling** — torn tail RECOVERABLE with CORRUPTION record; mid-file corruption BLOCKED; no silent discard.
- **G9 Broker/local divergence** — Phase 11 table outcomes enforced; BROKER_UNAVAILABLE never downgrades to NOT_FOUND.
- **G10 No TT01 behavior change** — NEW/SHADOW runs: zero ledger events, zero journal changes, TT01 baselines byte-identical (frozen-hash evidence).

---

B25-03C:
ASSESSMENT COMPLETE

DESIGN:
COMPLETE

IMPLEMENTATION:
NOT AUTHORIZED

COMMIT:
NOT AUTHORIZED

PUSH:
NOT AUTHORIZED

NEXT SENIOR DECISION:
REVIEW B25-03C DESIGN AND AUTHORIZE / REJECT IMPLEMENTATION PLAN

STOP.
