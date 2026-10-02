# Sprint 25B — H6 Execution-Retry Semantics: Assessment + Minimal Remediation Design

- Document ID: SR-25B-H6-01
- **REVISION 2 (2026-08-16, senior design-correction pass):** Block 3 (broker-evidence pre-send scan) REMOVED; uncertain outcomes redefined as non-retryable until B25-03C durable reconciliation; retcode policy re-scrutinized on an evidence basis; H6↔B25-03C boundary made explicit. Sections affected: §1, §4, §5, §7, §9, §10, §12-§15, §17-§18. Sections unchanged: §2, §3, §6, §8, §11.
- Mission: READ-ONLY assessment + design ONLY. No implementation. No production/test/B25-03C/C1-C7 changes. No commit, no push, no stash manipulation.
- HEAD reviewed: `7d4eecb0ccce329003ceb8363f67de7155570429`
- Prior acceptance: C1-C7 independent review COMPLETE (H6 FAIL, claim-vs-code DISCREPANCY). H6 assessment ACCEPTED by senior; H6 current design NOT ACCEPTED — this revision is the required correction pass.
- Method: `git show 7d4eecb:` source reads + `git diff e881897 7d4eecb`. No runs, no reruns, no experiments.
- Stop-condition evaluation: NONE triggered (§1.1).

---

## 1) Executive verdict

- H6 defect CONFIRMED: `RecordSubmitted` executes unconditionally after every `OrderSend` attempt, contradicting the H6 claim that failed sends stay retryable and unrecorded (§3).
- H6 CAN be defined unambiguously (11-state contract, §4). The intra-session remediation needs NO durable ledger and NO broker scanning.
- The correct H6 contract: **a plan enters submitted/dedup state ONLY when a broker-visible submission exists (deal, order, or accepted request).** Retry eligibility is granted ONLY by a deterministic broker refusal (a refusal retcode); it is NEVER granted by absence of evidence. Uncertain outcomes (TIMEOUT/CONNECTION/UNKNOWN/ERROR-class) are NEVER auto-retried and NEVER marked rejected — they HOLD, and only B25-03C durable reconciliation may resolve them (retry vs executed).
- Architectural boundary (REVISION 2, per senior):
  - **B25-03B (frozen) + H6 = truthful classification + correct intra-session retry semantics.** H6 handles deterministic broker rejection → SAFE TO RETRY / PERMANENT REJECT, and broker-visible submission → RECORDED / never retry.
  - **B25-03C = durable execution state + reconciliation + restart-safe duplicate prevention.** UNCERTAIN outcomes flow HOLD → B25-03C reconciliation → ONLY THEN retry vs executed.
  - **H6 does NOT impersonate B25-03C.** No probabilistic broker scan, no heuristic "no evidence found = safe", no release mechanism of any kind for uncertain outcomes.
- Minimal remediation (corrected): one pure policy-classification seam + outcome-conditional record/hold/reject + a session-scoped hold map, all inside `Trading/TradeManager.mqh`. No retry engine, no ledger, no OnTradeTransaction, no telemetry change, no C1-C7 redesign, no broker scan.
- B25-03C-B dependency: **CONDITIONAL** — B25-03C-B already records the discrepancy (B6/D5/R18) and does not rely on the retryable claim; remediation requires identified wording/state-mapping updates only (list in §10), no ledger-core change.
- C4/C5 population impact: CLASSIFIED (§11) — C4 strategy-population changing; C5 lifecycle/performance/telemetry-content only.

### 1.1 Stop-condition evaluation (mission §MANDATORY STOP CONDITIONS)

| Stop condition | Triggered? | Basis |
|---|---|---|
| H6 cannot be defined unambiguously | NO | 11-state contract from source-verifiable outcome classes (§4) |
| Retry semantics require durable ledger before B25-03C | NO | Intra-session correctness needs no durability: retry is limited to deterministic-refusal retcodes; uncertain outcomes hold without any release path. Durable reconciliation is B25-03C's scope, not H6's requirement |
| A retry can create duplicate broker execution | NO (within design scope) | Retry-eligible set = outcomes with a DETERMINISTIC broker refusal (provable non-execution). Uncertain outcomes are never retried intra-session. Cross-restart re-attempt of an uncertain outcome is a DOCUMENTED RESIDUAL assigned to B25-03C (§9) — the design does not claim it is safe; it claims it is out of H6 scope |
| ExecutionId semantics require changing B25-03A | NO | B25-03A untouched; retry = new sequence under same decisionId (frozen comment format `#<seq>` already supports it) (§8) |
| C1-C7 behavior must be modified to fix H6 | NO | Remediation changes only the H6 post-send block; C1-C7 blocks (pre-send rejections, gate, sizing, fill, validation) unchanged |
| Existing frozen evidence must be rewritten | NO | No baselines, CSV, or frozen docs touched |
| TT01 semantics must change to validate H6 | NO | Validation is unit-level via a pure policy seam (§13) |

---

## 2) Current source behavior (as committed at 7d4eecb)

Execution path in `CTradeManager::Update` (`Trading/TradeManager.mqh`):

1. `:157-165` — gate: initialized, planner present, `m_executionEnabled` (LEGACY only).
2. `:167-182` — per plan: `GetPlan(i)`, `status == PLAN_EXECUTABLE` filter, `planId = plan.entryDecisionId` (`:180`; `entryDecisionId = decision.candidateId`, `Entry/ExecutionPlanner.mqh:214`), `m_totalReceived++`.
3. `:184-188` — `IsAlreadySubmitted(planId)` → `m_totalDuplicates++`, skip.
4. `:194-201` — C3 position gate (live account, exact symbol+magic) → `m_totalBlocked++`, skip. Plan status NOT changed; re-scanned every tick.
5. `:207-217` — C7 fill price; `<= 0` → `PLAN_REJECTED`, `m_totalFailed++`, NOT recorded.
6. `:220-237` — `ValidateAll` fail → `PLAN_REJECTED` (`:234`), `LogOrderFailed`, `m_totalFailed++`, NOT recorded.
7. `:241-266` — C2 sizing at fill; fallback to `m_lotSize` (0.01).
8. `:268-282` — volume invalid → `PLAN_REJECTED`, NOT recorded.
9. `:285-299` — request build fail → `PLAN_REJECTED`, NOT recorded.
10. `:302` — `bool sent = OrderSend(request, tradeResult);`
11. `:304` — `truth = CaptureExecutionTruth(request, tradeResult, planId)` (pure, frozen B25-03B).
12. `:316-334` — outcome branch on `truth.outcome`:
    - `EXEC_OUTCOME_FILLED | PARTIALLY_FILLED` → `m_totalSucceeded++`, `LogOrderSent`.
    - `EXEC_OUTCOME_ACCEPTED_NO_DEAL` → `LogOrderSent` (neither succeeded nor failed tally).
    - everything else (REJECTED, TIMEOUT, CONNECTION_ERROR, UNKNOWN, BROKER_ERROR) → `m_totalFailed++`, `LogOrderFailed`.
13. `:340-341` — **`RecordSubmitted(planId); m_totalSubmitted++;` — UNCONDITIONAL.**

Dedup ledger (`:39-40`, `:371-387`): `ulong m_submittedIds[]` + count; linear scan; append-only; `ArrayFree` on `Shutdown` (`:364-365`), `m_submittedCount = 0` on `Init` (`:121`). **RAM-only; does not survive restart.** Sole consumers: `IsAlreadySubmitted` (`:184`), `RecordSubmitted` (`:340`) — no external consumers (verified by grep across the tree).

Truth model (frozen `Trading/ExecutionTruth.mqh`): `ClassifyOutcome(retcode, dealTicket, dealVolume, requestedVolume)` — retcode-driven; the `OrderSend` boolean is NOT an input. `deal != 0` is the only broker-confirmed execution evidence; filled fields are zero unless a deal exists. Outcomes: UNKNOWN (retcode 0), REJECTED (all rejection retcodes), ACCEPTED_NO_DEAL (DONE/DONE_PARTIAL/PLACED with no deal), FILLED (DONE+deal), PARTIALLY_FILLED (DONE_PARTIAL+deal), TIMEOUT, CONNECTION_ERROR, BROKER_ERROR (retcode outside the known table).

Planner statuses (`Entry/ExecutionPlanTypes.mqh`): `PLAN_CREATED, PLAN_EXECUTABLE, PLAN_REJECTED, PLAN_REJECTED_PORTFOLIO`. **`PLAN_PENDING` (cited in report §11) does not exist.**

---

## 3) H6 defect proof

Claim (`docs/Sprint25B_Integrity_Fixes_Report.md:158-161`): "on `OrderSend` failure the plan is neither marked rejected nor recorded, so the next bar re-attempts it (status stays `PLAN_PENDING`)."

Same claim in code comment (`TradeManager.mqh:336-339`): "Failed sends stay retryable on the next bar; the same-tick dedup ledger is not polluted by failed attempts."

Facts:
1. `RecordSubmitted(planId)` at `:340` and `m_totalSubmitted++` at `:341` execute for EVERY plan that reached `OrderSend`, regardless of `sent` or `truth.outcome` (source: `:302-341`; no condition exists between `:334` and `:340`).
2. Plan status is never touched in the post-send block; a failed send leaves the plan `PLAN_EXECUTABLE`.
3. Next bar: `IsAlreadySubmitted(planId)` (`:184`) → true → `m_totalDuplicates++`, `continue`. **Intra-session retry is blocked for the lifetime of the run.**
4. Restart: `m_submittedIds` is RAM (`:39-40`), freed at `Shutdown` (`:364-365`), zeroed at `Init` (`:121`) — the dedup state is lost, so after restart the plan id set differs anyway (per-run candidateId counter). "Retryable" therefore holds ONLY across a restart, which the report does not claim.
5. The pre-send rejection branches (`:214`, `:234`, `:279`, `:296`) are the mirror image — `PLAN_REJECTED`, NOT recorded — and DO match the report's intent for validation rejections. The report conflates the two classes; only the pre-send half is implemented as claimed.

Conclusion: for send-attempt failures the code implements "attempted → recorded → never retried intra-session", i.e., the OPPOSITE of the claim on both axes (recorded: yes; retryable: no). DISCREPANCY confirmed. (Recorded as B6/D5/R18 in the B25-03C-B assessment/design.)

---

## 4) Correct H6 contract

### 4.1 Principles (REVISION 2)

1. **Broker-visible evidence decides**: dedup state is entered only when a broker-visible submission (deal, order, accepted request) exists.
2. **Retry eligibility is evidence-based, not retcode-class-based**: a retcode grants retry eligibility ONLY when it is a DETERMINISTIC broker refusal — i.e., the retcode itself proves the request was not executed (and cannot have been). Absence of evidence NEVER grants eligibility. Generic or indeterminate retcodes (ERROR, NO_CHANGES) grant nothing.
3. **UNKNOWN ≠ REJECTED**: an indeterminate outcome is never marked `PLAN_REJECTED` (that would lie about the broker) and never silently retried.
4. **TIMEOUT ≠ SAFE TO RETRY; CONNECTION FAILURE ≠ SAFE TO RETRY**: an uncertain outcome is HOLD/BLOCK until B25-03C durable reconciliation determines retry vs executed. H6 provides no release mechanism for uncertain outcomes.
5. **Retry ≠ duplicate**: a retry is a NEW attempt (future: new executionId/seq under the same decisionId); a duplicate is the SAME attempt replayed (blocked by dedup).
6. **The `OrderSend` boolean is never truth**: classification comes from retcode + deal + order + volume (frozen B25-03B model).
7. **No impersonation of B25-03C**: H6 never scans broker artifacts, never infers non-execution from absence of evidence, and never persists anything.

### 4.2 The eleven states

| # | State | Enter dedup? | Retry allowed? | Automatic or eligible? | Consumes executionId (B25-03C era)? | Requires broker reconciliation? | Restart-reconstructable? |
|---|-------|--------------|----------------|------------------------|-------------------------------------|-------------------------------|--------------------------|
| 1 | PRE_SEND_REJECTED (fill≤0 / ValidateAll / volume / build) | NO | NO (permanent) | n/a | YES (INTENT+REJECTED, gap legal — B25-03C-B R17) | NO (broker never saw it) | n/a (no broker artifact; plan state is per-run) |
| 2 | SEND_ATTEMPTED | — | — | — | YES (INTENT reserved before send) | — | — (transitional, never terminal) |
| 3 | SEND_ACCEPTED (broker accepted; retcode DONE/DONE_PARTIAL/PLACED, deal may be 0) | YES | NO | n/a | YES (one per attempt) | Passive only (deals/orders may arrive later) | YES (order/position artifacts carry identity) |
| 4 | SEND_REJECTED-transient (deterministic refusal, transient state: REQUOTE, REJECT, CANCEL, PRICE_CHANGED, PRICE_OFF, MARKET_CLOSED, NO_MONEY, TOO_MANY_REQUESTS, FROZEN, LOCKED, TRADE_DISABLED, SERVER_DISABLES_AT, CLIENT_DISABLES_AT, LIMIT_ORDERS, LIMIT_VOLUME) | NO | YES | Eligible (existing per-tick loop; NO retry engine) | YES (new seq per attempt) | NO (retcode proves refusal) | n/a (no artifact) |
| 5 | SEND_REJECTED-permanent (deterministic refusal, plan/request defect or immutable: INVALID, INVALID_VOLUME, INVALID_PRICE, INVALID_STOPS, INVALID_EXPIRATION, INVALID_ORDER, INVALID_FILL, ONLY_REAL) | NO | NO (permanent → PLAN_REJECTED) | n/a | YES (INTENT+REJECTED, gap legal) | NO | n/a |
| 6 | ACCEPTED_NO_DEAL (PLACED / DONE-no-deal) | YES | NO | n/a | YES | Passive (E2/E3 in B25-03C-B; today: none) | YES (order artifact) |
| 7 | FILLED (DONE + deal) | YES | NO | n/a | YES | NO | YES (deal/position artifact) |
| 8 | PARTIALLY_FILLED (DONE_PARTIAL + deal) | YES | NO (shortfall handling = B25-03C-B R7/R8, out of scope) | n/a | YES | NO | YES |
| 9 | TIMEOUT | NO | NO — until B25-03C durable reconciliation | NEVER automatic | YES (INTENT reserved; outcome undetermined) | **MANDATORY (B25-03C)** | NO (H6 scope is intra-session; restart = B25-03C domain) |
| 10 | CONNECTION_FAILURE | NO | NO — until B25-03C durable reconciliation | NEVER automatic | YES | **MANDATORY (B25-03C)** | NO (same) |
| 11 | UNCERTAIN-INDETERMINATE (retcode 0 / unrecognized retcode / ERROR / NO_CHANGES) | NO | NO — until B25-03C durable reconciliation | NEVER automatic | YES | **MANDATORY (B25-03C)** | NO (same) |

Retcode→class rationale (evidence basis, REVISION 2 — the scrutiny pass):
- **Deterministic refusal (retry-eligible):** REQUOTE/PRICE_CHANGED/PRICE_OFF — broker reports the price moved and did not process the request; REJECT/CANCEL — broker explicitly refused/canceled; MARKET_CLOSED/TRADE_DISABLED/SERVER_DISABLES_AT/CLIENT_DISABLES_AT/FROZEN/LOCKED — broker explicitly refused on a stated, mutable state; NO_MONEY — refused, margin may free; TOO_MANY_REQUESTS/LIMIT_ORDERS/LIMIT_VOLUME — refused on a stated, mutable limit. In every case the retcode itself is the proof of non-execution; no scan is involved.
- **Deterministic refusal (permanent):** INVALID/INVALID_VOLUME/INVALID_PRICE/INVALID_STOPS/INVALID_EXPIRATION/INVALID_ORDER/INVALID_FILL — the request itself is defective; re-sending the same plan will fail identically → `PLAN_REJECTED`. ONLY_REAL — immutable environment (demo refuses); re-sending is provably futile → non-retryable (not a plan defect, but no legitimate retry exists).
- **UNCERTAIN (HOLD/BLOCK, never retried by H6):** TIMEOUT — the request MAY have been processed server-side with the response lost; CONNECTION — the request MAY have been processed before the link failed; **ERROR — generic processing error, does not demonstrably prove refusal (broker-specific semantics; may mask connectivity/processing anomalies)** — demoted from the transient set in REVISION 2; **NO_CHANGES — may indicate an artifact from an earlier attempt already exists (request matched existing state) — ambiguous, demoted to UNCERTAIN**; retcode 0 — no outcome reported; unrecognized retcode — semantics unknown.
- **Broker-visible submission (RECORD, never retry):** PLACED — order placed; DONE — executed; DONE_PARTIAL — partially executed; plus the evidence override `deal != 0` → executed regardless of retcode.

---

## 5) OrderSend truth matrix (Objective 2)

Boolean + retcode + deal + order + volume. Boolean is observability-only; classification is `ClassifyOutcome` (frozen) + the §4.2 policy. All rows apply identically whether `OrderSend` returned true or false.

| Row | OrderSend bool | retcode | deal | order | volume | Classified outcome | Submission state | Retry state | Dedup state | Broker-evidence requirement |
|-----|----------------|---------|------|-------|--------|--------------------|------------------|-------------|-------------|------------------------------|
| A | false | rejection (REJECT/REQUOTE/PRICE_OFF/…) | 0 | 0 | 0 | REJECTED | SEND_REJECTED (class per §4.2) | transient→eligible; permanent→NO | NOT entered | none (retcode proves refusal) |
| B | false | TIMEOUT | 0 | 0 | 0 | TIMEOUT | TIMEOUT | NO — HOLD until B25-03C reconciliation | NOT entered | reconciliation only (B25-03C) |
| C | false | CONNECTION | 0 | 0 | 0 | CONNECTION_ERROR | CONNECTION_FAILURE | NO — HOLD until B25-03C reconciliation | NOT entered | reconciliation only (B25-03C) |
| D | true | DONE | deal≠0 | order | vol | FILLED | FILLED | NO | ENTERED (plan recorded) | deal ticket is the evidence; none further |
| E | true | DONE_PARTIAL | deal≠0 | order | partial vol | PARTIALLY_FILLED | PARTIALLY_FILLED | NO | ENTERED | deal ticket; shortfall tracked later (B25-03C) |
| F | true | PLACED | 0 | order≠0 | 0 | ACCEPTED_NO_DEAL | ACCEPTED_NO_DEAL | NO | ENTERED | order ticket (parked order exists) |
| G | true | NO_MONEY | 0 | 0 | 0 | REJECTED | SEND_REJECTED-transient | YES (eligible) | NOT entered | none |
| H | true | INVALID (or INVALID_*) | 0 | 0 | 0 | REJECTED | SEND_REJECTED-permanent → PLAN_REJECTED | NO | NOT entered | none |
| I | true | TIMEOUT | 0 | 0 | 0 | TIMEOUT | TIMEOUT | NO — HOLD until B25-03C reconciliation | NOT entered | reconciliation only (B25-03C) |
| J | true | UNKNOWN/other (incl. ERROR, NO_CHANGES) | 0 | 0 | 0 | UNKNOWN / BROKER_ERROR / REJECTED | UNCERTAIN-INDETERMINATE | NO — HOLD until B25-03C reconciliation | NOT entered | reconciliation only (B25-03C) |

The `result.submitted = sent` assignment (`TradeManager.mqh:308`) is observability-only and must not drive policy.

---

## 6) RecordSubmitted semantics (Objective 3)

Question: what does `RecordSubmitted` currently represent? Answer, source-proven:
- **A — "OrderSend was attempted."** Proven: unconditional call at `:340` immediately after the outcome branch; no condition on `sent` or `truth.outcome`; the only caller in the tree is `:340`; the sole consumer `IsAlreadySubmitted` treats presence as "do not send again".
- It does NOT represent B ("broker accepted") — accepted and rejected attempts are recorded identically.
- It does NOT represent C ("execution may have occurred") — it records outcomes that provably did not execute (e.g., REJECT/INVALID).
- It partially represents D ("never retried") for the accepted/filled outcomes, but over-applies it to rejected and uncertain outcomes.

The corrected contract: `RecordSubmitted` means D-scoped — **"this strategy decision must not be re-sent because a broker-visible submission exists"** — and is called ONLY for {SEND_ACCEPTED, ACCEPTED_NO_DEAL, FILLED, PARTIALLY_FILLED} (plus the `deal != 0` override). Everything else is never recorded: deterministic refusals become retry-eligible or plan-rejected; uncertain outcomes HOLD.

Identity keys today: dedup key = `planId` = `plan.entryDecisionId` = `decision.candidateId` (`TradeManager.mqh:180`, `ExecutionPlanner.mqh:214`). `executionId` does not exist in the live path (B25-03A frozen, unwired — zero production call sites, verified). candidateId is a per-run counter (RAM); it does not survive restart.

---

## 7) Retry boundary (Objective 4, REVISION 2)

Four classes, exclusive and exhaustive. Release mechanisms: NONE except those stated.

**SAFE TO RETRY** — deterministic broker refusal, transient state (rows A/G-class): REQUOTE, REJECT, CANCEL, PRICE_CHANGED, PRICE_OFF, MARKET_CLOSED, NO_MONEY, TOO_MANY_REQUESTS, FROZEN, LOCKED, TRADE_DISABLED, SERVER_DISABLES_AT, CLIENT_DISABLES_AT, LIMIT_ORDERS, LIMIT_VOLUME. Retry = plan remains `PLAN_EXECUTABLE`, unrecorded; the existing per-tick loop re-attempts (eligible; no retry engine, no throttle state). Pre-send rejections stay `PLAN_REJECTED` (never retried) — unchanged.

**MUST NOT RETRY — PERMANENT REJECT** — deterministic refusal, plan/request defect or immutable (row H-class): INVALID, INVALID_VOLUME, INVALID_PRICE, INVALID_STOPS, INVALID_EXPIRATION, INVALID_ORDER, INVALID_FILL, ONLY_REAL → `PLAN_REJECTED` (mirrors the pre-send pattern).

**MUST NOT RETRY — BROKER-VISIBLE SUBMISSION** — rows D/E/F: SEND_ACCEPTED, ACCEPTED_NO_DEAL, FILLED, PARTIALLY_FILLED, and `deal != 0` override → `RecordSubmitted` (dedup entered; never re-sent).

**UNCERTAIN → HOLD/BLOCK — NEVER AUTO-RETRY** (rows B/C/I/J): TIMEOUT, CONNECTION, ERROR, NO_CHANGES, retcode 0, unrecognized retcode. The plan enters the hold map (RAM, session-scoped). It is neither recorded nor rejected. **There is no intra-session release path and no broker scan of any kind.** Resolution happens ONLY through B25-03C durable reconciliation (ledger UNKNOWN/pending + E2/E3/E4), which decides retry vs executed. Pre-B25-03C, an uncertain outcome is effectively terminal for the session (conservative by design — see §9 for the restart boundary).

Flow (senior's boundary):

```
DETERMINISTIC BROKER REJECTION  →  SAFE TO RETRY / PERMANENT REJECT  →  H6 handles
UNCERTAIN (TIMEOUT/CONNECTION/UNKNOWN)
        → NEVER AUTO-RETRY
        → HOLD/BLOCK
        → B25-03C durable reconciliation
        → ONLY THEN retry vs executed
```

Compatibility with B25-03C: the four classes map 1:1 onto ledger states (SAFE TO RETRY → INTENT+SENT/REJECTED with retry = new INTENT; PERMANENT REJECT → REJECTED; BROKER-VISIBLE → SENT/DEAL_IN; UNCERTAIN → UNKNOWN/pending resolved by E2/E3/E4). The remediation adds no durable behavior and no scan.

---

## 8) ExecutionIdentity interaction (Objective 5)

Frozen B25-03A (`Trading/ExecutionIdentity.mqh`) is NOT modified. Answers under its existing semantics:

- **Does a failed OrderSend consume an executionId?** In the B25-03C era, YES — a sequence is reserved INTENT-before-send for every attempt that reaches OrderSend, including rejected and uncertain ones (B25-03C-B R17/R18: gap legal). Pre-B25-03C: no executionId exists in the live path.
- **Can the same executionId be retried?** NO — one INTENT per executionId (B25-03C-B Invariant 6); an executionId is never re-sent.
- **How is the attempt sequence represented?** Retry = a NEW executionId (new seq) under the SAME decisionId: comment `SCX-<side>-P<decisionId>#<seq1>` → `#<seq2>`… The frozen `BuildComment`/`ParseSeqFromComment` already support this; `ParseDecisionId` stops at the first non-digit, so legacy comments remain parse-compatible.
- **Retry vs duplicate in B25-03C:** duplicate = same (decisionId, seq) replayed → deduped by executionId (INTENT exists → BLOCKED, R11); retry = same decisionId, NEW seq → legitimate new INTENT. Same-run candidateId dedup (`m_submittedIds`, secondary guard) never suppresses a different executionId (B25-03C-B B20).
- **What survives restart:** the durable seq counter (B25-03A file) and — with B25-03C — the ledger; today, only broker artifacts survive. Restart-safe duplicate prevention is B25-03C's job (§9); H6 does not attempt it.

---

## 9) Restart implications (REVISION 2)

Facts: dedup ledger and candidateId counter are RAM-only; plans/signals rebuild per run; the only restart-surviving state today is broker artifacts.

Corrected boundary: **H6 scope is intra-session.** The hold map is RAM and is lost on restart. A plan regenerated after restart is a NEW plan (new candidateId) and may re-enter the pipeline — including plans whose prior attempt ended UNCERTAIN.

- This is a documented residual risk: a restart during the uncertain window can cause a re-attempt of an outcome that may actually have executed. The design does NOT claim to prevent this (no scan, no heuristic, no persistence).
- Prevention is B25-03C's responsibility: INTENT write-ahead before send + durable ledger + reconciliation (E2/E3/E4), which B25-03C-B already specifies for exactly this case (R9 position-from-prior-run, R12 cross-run duplicate intent → AMBIGUOUS/BLOCKED).
- The existing C3 position gate (`TradeManager.mqh:138-153`) is a deterministic per-symbol position CAP. It incidentally bounds the restart exposure when the uncertain attempt actually opened a position (the position exists with matching magic → gate blocks). It is NOT a reconciliation mechanism and is NOT part of the H6 retry boundary; it is cited only to state what it is (and what it is not).
- Nothing in H6 may be added later to "improve" restart safety with probabilistic evidence. That is B25-03C's domain, per senior decision.

---

## 10) B25-03C dependency (Objective 6)

**H6 prerequisite: CONDITIONAL.**

What B25-03C requires from H6: a deterministic, retcode-driven classification of send outcomes into recorded / rejected-permanent / retry-eligible / uncertain — exactly the policy function of §12 — because the ledger writer must emit SENT/REJECTED/UNKNOWN/DEAL_IN per attempt, must never record an attempt that never reached the broker, and must never re-provision a sent executionId.

Required changes to the B25-03C-B design (IDENTIFIED ONLY — the design documents are NOT rewritten in this phase):
1. R18 row: the "never retried (committed behavior records the attempt)" statement describes the CURRENT (unremediated) code and remains valid for it; once H6 is remediated, send-attempt outcomes split into the §7 classes and the writer maps them: BROKER-VISIBLE → SENT/DEAL_IN; PERMANENT → REJECTED; RETRY-ELIGIBLE → SENT + new executionId per re-attempt; UNCERTAIN → UNKNOWN/pending (E2/E3/E4 — already designed).
2. DP-1/B6/B24 wording: the "do not design against the retryable claim" caveats remain valid for the current commit; they become obsolete for retry-eligible/uncertain classes once the remediation lands. The ledger core and Invariants 6/7/20 are unaffected.
3. The writer's `ExecuteAndRecord` seam (B25-03C-B §writer) aligns naturally: remediation policy output feeds `writer.RecordResult`; UNCERTAIN held plans are exactly the ledger's pending/UNKNOWN population.
4. No change to `ExecutionLedger.mqh`, `ExecutionTruth.mqh`, `ExecutionIdentity.mqh`, telemetry schema, or the two B25-03C-B documents' architecture. B25-03C-B remains BLOCKED pending H6 remediation authorization (per mission).

---

## 11) C4/C5 population-impact classification (Objective 7)

Read-only classification; no experiments run; no invariance claimed. Categories: A telemetry-only, B lifecycle-only, C performance-only, D decision-population changing, E strategy-population changing, F unknown pending controlled experiment.

**C4 (closed-bar discipline — FVG/Swing/Liquidity): E (strategy-population changing), mechanism D, remainder F-until-experiment.**
- Detection results change (FVG triples end at bar 3, swing centers capped at `rates_total-4`, mitigations on `high[1]/low[1]`) → structure inputs to confluence scores change → per-tick decisions (qualification, direction, confidence, candidateIds) change (`SymbolContext.mqh:976` evaluator feed; rows per decision `:1011-1074`) → plan feed in LEGACY mode changes → trade population and telemetry rows (counts AND content) shift vs e881897 baseline.
- Not A/B/C alone; not provably invariant without a controlled A/B on frozen history (F).

**C5 (no NONE-bar signals + bounded pool): B (lifecycle-only) + C (performance-only) + A (telemetry evidence content); NOT D/E.**
- Decision generation is tick-driven and does not depend on signal existence (`SymbolContext.mqh:976`, decisions evaluated per Update regardless of signals) → decision/row COUNTS unchanged.
- Pool composition changes (no NONE entries; `m_totalSignalsCreated/Expired/Pruned` tallies; `CheckSignalLifecycles` scan cost bounded by `MAX_SIGNAL_POOL_SIZE` 4096) → B + C.
- Row evidence content changes: on NONE bars `GetLatestSignal` (`SymbolContext.mqh:1040`) now returns the last DIRECTIONAL signal (stale vs. the bar) instead of a fresh NONE signal → `BuildWithEvidence` fields, `hasLiquiditySweep`, `liquidityLevelId` (`:1071-1073`) shift → A.
- No claim of count-invariance beyond the source reasoning above; a controlled comparison is a FUTURE separately authorized task if needed (F).

This classification is independent of the H6 remediation (execution-layer only) and is unaffected by REVISION 2.

---

## 12) Minimal remediation design (Objective 8, REVISION 2)

Scope: the smallest technically correct change. One new pure function + one conditional block + one RAM hold map. **No broker scan, no evidence heuristic, no release path for uncertain outcomes.** No retry engine, no reconciliation module, no ledger, no OTT, no telemetry change, no C1-C7 redesign, no C4/C5/C7/C2/C3/planner/detector changes.

### 12.1 Block 1 — Retry-policy classification (new pure function)

- File: `Trading/TradeManager.mqh` (new file-local enum + static inline function; optionally a new header `Trading/TradeManagerRetryPolicy.mqh` — no other production file touched).
- Logical block: immediately above `Update()`; consumes frozen `ExecutionOutcome` (ExecutionTruth) + raw retcode + dealTicket.
- Current behavior: none — classification is implicit in the `:316-334` if/else chain (succeeded / logged / failed), and `:340` records unconditionally.
- Desired behavior: deterministic mapping `outcome × retcode × deal → {RECORD, REJECT_PERMANENT, RETRY_ELIGIBLE, RETRY_HOLD}` per §4.2/§7, including the `deal != 0` evidence override. Pure (no time, no account state, no broker queries, no OrderSend) → unit-testable, deterministic. The retcode→class table (§4.2) is the single source of truth, locked by tests (§13).
- State transitions:
  - RECORD (BROKER-VISIBLE: FILLED, PARTIALLY_FILLED, ACCEPTED_NO_DEAL, or `deal != 0`) → `RecordSubmitted(planId)` + `m_totalSubmitted++` + existing outcome-branch logging/tallies (`:316-334` UNCHANGED).
  - REJECT_PERMANENT (permanent set, deal==0) → `SetPlanStatus(i, PLAN_REJECTED)` + `LogOrderFailed` + `m_totalFailed++` + NOT recorded (mirrors the pre-send pattern at `:220-237`).
  - RETRY_ELIGIBLE (deterministic-refusal transient set, deal==0) → leave status, NOT recorded, `m_totalFailed++` + `LogOrderFailed` (attempt counted; existing per-tick loop re-attempts — no retry engine).
  - RETRY_HOLD (UNCERTAIN: TIMEOUT/CONNECTION/UNKNOWN/BROKER_ERROR/ERROR/NO_CHANGES, deal==0) → NOT recorded, NOT rejected; `planId` added to the hold map; `LogOrderFailed` (rationale "UNCERTAIN-HOLD"); `m_totalHeld++`.

### 12.2 Block 2 — Hold map + skip

- Same file; members `ulong m_retryHoldIds[]; int m_retryHoldCount; int m_totalHeld;`
- Check point: inside `Update()`, next to the dedup check `:184-188` (held plans `continue` before gate/fill/sizing — silent skip, no tallies beyond the held count).
- **Release: NONE intra-session.** No timers, no expiry, no broker scan, no evidence check. The only exits are (a) `Shutdown` (RAM freed), and (b) B25-03C reconciliation in a later phase (integration point, not implemented here). Held plans are deterministic and terminal for the session.
- Memory bound: `planCount` per symbol context (tiny); freed in `Shutdown` alongside the submitted array.

### 12.3 Explicitly NOT in scope (REVISION 2)

- **No Block 3.** The former pre-send broker-evidence guard is REMOVED: "no evidence found → safe to send" is a false sense of reconciliation and is rejected by senior decision. Absence of evidence proves nothing; only a deterministic refusal retcode grants retry eligibility.
- No restart-safe duplicate prevention (B25-03C domain; residual documented in §9/§15).
- No reconciliation implementation of any kind.

### 12.4 What stays byte-identical

C1 magic chain, C2 sizing block (`:241-266`), C3 gate (`:194-201`), C4/C5 detectors/engine, C6 planner+validation, C7 fill/validation blocks (`:207-299`), pre-send rejections (`:220-237` etc.), `:316-334` outcome branch, `IsAlreadySubmitted`/`RecordSubmitted` bodies, tallies, logs, request builder, planner, all other files.

### 12.5 Test cases (design; not implemented)

T1 pre-send rejection stays `PLAN_REJECTED` + unrecorded (existing behavior — regression).
T2 REJECT-permanent (INVALID etc.) → `PLAN_REJECTED` + unrecorded (new).
T3 REJECT-transient (REQUOTE etc.) → status unchanged + unrecorded (retry-eligible).
T4 FILLED/ACCEPTED_NO_DEAL/PLACED/deal≠0 → recorded (dedup entered).
T5 TIMEOUT/CONNECTION/ERROR/NO_CHANGES/UNKNOWN → held, not rejected, not recorded.
T6 Hold is never released intra-session: repeated `Update()` calls (simulated ticks) keep the plan held; only `Shutdown` clears the map.
T7 Policy table locked: every `TRADE_RETCODE_*` maps to exactly one class (§4.2), including the demotions (ERROR/NO_CHANGES → UNCERTAIN).
T8 Determinism: same (outcome, retcode, deal) → same class across calls (loop 100×).
T9 No-blind-resend property: UNCERTAIN ∉ {RECORD, RETRY_ELIGIBLE} for every retcode in the UNCERTAIN set (policy-level proof via tests).
T10 All C1-C7 suites (incl. TestIntegrityFixes) pass unchanged.

### 12.6 Regression risks

R1 Tally semantics shift: `m_totalSubmitted` becomes "true submissions" (lower than today); `m_totalFailed` includes transient attempts and holds; `m_totalDuplicates` shrinks. Document in Shutdown summary; no external consumers exist (verified).
R2 Post-send REJECT-permanent newly sets `PLAN_REJECTED` (plan leaves the scan) — net effect equals today's dedup-block (no re-send) but via status; portfolio gate (`SymbolContext.mqh:1080-1101`) skips non-EXECUTABLE plans consistently.
R3 Hold starvation is INTENDED: an uncertain outcome never executes again in-session, even when nothing executed (opportunity cost). Conservative, deterministic, aligned with the senior boundary.
R4 Restart re-attempt of an uncertain outcome may duplicate a real execution — accepted residual, B25-03C domain (§9); NOT mitigable pre-B25-03C without heuristics (which are prohibited).
R5 Broker-specific retcode semantics (esp. ERROR) — mitigated by conservative classification (ERROR → UNCERTAIN); a broker that returns ERROR where another returns PRICE_OFF loses retry eligibility (safe direction).
R6 No new durable state → no new corruption surface.

### 12.7 B25-03C interaction

Policy function output feeds the future writer (`ExecuteAndRecord` seam, B25-03C-B §writer) unchanged: RECORD → SENT/DEAL_IN; REJECT_PERMANENT → REJECTED; RETRY_ELIGIBLE → SENT + new executionId per re-attempt; RETRY_HOLD → UNKNOWN/pending, resolved by E2/E3/E4 reconciliation. Dedup remains candidateId-secondary; executionId-primary in the B25-03C era. No ledger-core change.

---

## 13) TDD plan (Objective 9) — RED → GREEN (REVISION 2)

Seam: the pure policy function (§12.1) is the testable surface (same seam pattern as B25-03C-B's writer; no mockable OrderSend exists in MT5, so all policy logic must live outside `Update()`).

RED (write first, against current code — they fail today):
- `TestH6RetryPolicy` (unit, `Tests/unit/TestH6RetryPolicy.mqh`):
  - R1: pre-send rejection → REJECT_PERMANENT-class + not recorded (compile-red until the seam exists).
  - R2: FILLED/ACCEPTED_NO_DEAL/deal≠0 → RECORD.
  - R3: TIMEOUT/CONNECTION/ERROR/NO_CHANGES/UNKNOWN/BROKER_ERROR → RETRY_HOLD (never REJECT, never RECORD).
  - R4: INVALID* / ONLY_REAL → REJECT_PERMANENT; REQUOTE/REJECT/PRICE_OFF/NO_MONEY/MARKET_CLOSED/etc. → RETRY_ELIGIBLE (the enumerated §4.2 table, row by row).
  - R5: deal≠0 overrides any retcode → RECORD.
  - R6: determinism — same inputs, same class (loop 100×).
  - R7: no-blind-resend — UNCERTAIN set never yields RECORD or RETRY_ELIGIBLE (exhaustive over the set).
- `TestH6HoldMap` (unit): add/skip/contains; held plan survives many Update calls (no release path exists); Shutdown clears; bounded growth.
- `TestH6RestartBoundary` (unit): documents that hold state is RAM-only (cleared on Shutdown); asserts no persistence/scan code path is invoked for hold resolution (structural review gate, not a runtime test).

GREEN: implement §12 (Block 1, then Block 2); run the full suite — all H6 tests green AND `TestIntegrityFixes` + C1-C7 suites + grand total unchanged.

Proof obligations (mission list): pre-send rejection remains PLAN_REJECTED (T1); rejected OrderSend not dedup-blocked (T3); genuine success recorded (T4); timeout not classified as rejection (T5); connection failure not classified as rejection (T5); unknown outcome cannot silently become retryable (T5/T7 — held, never released); no blind resend after uncertain broker outcome (T5/T7 — no release path exists at all, not merely gated); deterministic (T6/T8); C1-C7 tests unaffected (T10).

---

## 14) Acceptance gates (Objective 10, REVISION 2)

- G1 Source semantics: `RecordSubmitted` call sites exactly one, conditioned on RECORD-class only; hold/reject/eligible classes never call it.
- G2 Retcode truth table: §5 matrix fully covered by unit tests (rows A-J + deal-override), plus the exhaustive per-retcode class table (§4.2).
- G3 Retry classification: retry-eligible set == the enumerated deterministic-refusal transient set ONLY; UNCERTAIN set never auto-retried and has NO intra-session release path (no timers, no scan, no evidence check — code review + tests).
- G4 Dedup interaction: `IsAlreadySubmitted` skips only recorded plans; held/rejected/eligible plans never enter `m_submittedIds`; candidateId dedup semantics preserved.
- G5 Execution identity interaction: zero diff to `ExecutionIdentity.mqh`; retry = new seq under same decisionId documented; no identity consumption pre-B25-03C.
- G6 B25-03C compatibility: policy output maps to writer states (RECORD/REJECTED/SENT/UNKNOWN); UNCERTAIN held plans == ledger UNKNOWN/pending population; B25-03C-B required-change list (§10) reviewed by senior; ledger core untouched.
- G7 Regression suite: full suite green (grand total unchanged vs 7d4eecb baseline), incl. TestIntegrityFixes; no test file modified except new H6 tests + suite registration.
- G8 Deterministic behavior: policy pure (no time, no account, no broker state in classification); hold map has no release mechanism; no wall-clock anywhere in the H6 path.
- G9 Frozen evidence integrity: `ExecutionLedger/Truth/Identity`, telemetry CSVs, TT01/ED01 baselines, B25-03C docs, C1-C7 review — zero diff (verified by `git diff` at acceptance).
- G10 No unintended C1-C7 changes: `git diff` shows only TradeManager.mqh (+ optional new policy header + new tests + TestSuite registration); C1-C7 files byte-identical; no broker-scan code exists anywhere in the change.

---

## 15) Risk register (REVISION 2)

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| 1 | Restart duplicate after an uncertain outcome that actually executed | Low | Medium (double position) | ACCEPTED RESIDUAL — H6 is intra-session by design; B25-03C (INTENT write-ahead + E2/E3/E4 reconciliation) is the designated fix; C3 position cap bounds the open-position case; NO heuristic mitigation (prohibited) |
| 2 | Tally semantics drift (submitted/failed/duplicates) | Certain | Low | Documented in Shutdown summary + this doc; no external consumers |
| 3 | Opportunity cost: uncertain outcome never re-executes in-session even if nothing happened | Certain (by design) | Low | Intentional conservatism; deterministic; aligns with senior boundary; B25-03C restores resolution |
| 4 | Broker-specific retcode semantics (esp. ERROR/NO_CHANGES) | Medium | Low | Conservative classification (both → UNCERTAIN); errors lose retry eligibility, never gain it |
| 5 | Policy drift between §4.2 table and function | Low | Low | Single source of truth in the pure function; tests lock every retcode |
| 6 | Post-send REJECT-permanent changes plan-status semantics | Medium | Low | Mirrors existing pre-send pattern; portfolio gate skips consistently |
| 7 | Per-tick re-attempts for transient rejects inflate logs/tallies | Medium | Low | Existing loop semantics; documented; throttle out of scope (no retry engine) |
| 8 | False sense of reconciliation (the REVISION 1 flaw) | Eliminated | — | No scan, no evidence heuristic, no release path; only deterministic refusal grants retry |

---

## 16) No-touch list

- Frozen: `Trading/ExecutionLedger.mqh` (B25-03C-A), `Trading/ExecutionTruth.mqh` (B25-03B), `Trading/ExecutionIdentity.mqh` (B25-03A), `Trading/TradeRequestBuilder.mqh`, `Entry/PositionLifecycleManager.mqh`, `Monitoring/ActualOutcomeSettler.mqh`, `Monitoring/TelemetryCollector.mqh`, telemetry CSV schema, `Trading/TradeValidation.mqh`, planner/detectors/ConfluenceEngine, `Core/*`, `Portfolio/*`, `SuperCents_X.mq5`.
- Documents: the two B25-03C-B docs, `docs/Sprint25B_C1-C7_Integrity_Review.md`, `docs/Sprint25B_Integrity_Fixes_Report.md` (audit target, not modified), B25-03C design (accepted), B25-03A/B assessments.
- Baselines: TT01/ED01 baselines, gates.jsonl, TestRunnerEA.ex5.bak, ED01 CONTROL CSV.
- Git: no commit, no push, no stash manipulation, no amend/rebase of `7d4eecb`.
- The only files the remediation MAY touch (when authorized): `Trading/TradeManager.mqh`, `Tests/unit/TestH6RetryPolicy.mqh` (new), `Tests/TestSuite.mqh` (registration), optionally `Trading/TradeManagerRetryPolicy.mqh` (new, pure policy header). NO broker-scan code in any form.

---

## 17) Authorization boundary (REVISION 2)

- THIS PHASE: assessment + design correction only. COMPLETE.
- NOT authorized: implementation, tests, commit, push, B25-03C-B start, B25-03C-C, stash changes, evidence rewriting.
- Block 3 (broker-evidence pre-send scan): REJECTED in its previous form and REMOVED from the design. It will NOT be reintroduced in any form, including as a "pre-send guard" or "evidence gate", before B25-03C durable reconciliation exists.
- The former decision point ("ship Block 3 or defer") is RESOLVED: no scan ships with H6; B25-03C owns all reconciliation.
- Next authorization request (when senior decides): H6 remediation implementation (Blocks 1-2, §12) + TDD suite (§13) under gates G1-G10.

---

## 18) Final recommendation (REVISION 2)

1. Accept the corrected H6 contract (§4) and retry boundary (§7): retry eligibility only from deterministic broker refusal; uncertain outcomes HOLD with no release path; B25-03C owns reconciliation and restart safety.
2. Approve the corrected minimal remediation design (§12): Blocks 1-2 only, no broker scan, no heuristic.
3. Approve the TDD plan (§13) and acceptance gates (§10/§14).
4. Keep B25-03C-B BLOCKED pending H6 implementation; apply the identified wording/state-mapping updates (§10.2) when the remediation is committed.
5. No stop condition was triggered; no workaround was designed; the REVISION 1 contradiction (bounded scan claiming non-execution) is removed.

---

## FINAL STATUS BLOCK (REVISION 2)

```
H6 DEFECT: CONFIRMED
H6 ASSESSMENT: ACCEPTED
H6 DESIGN: CORRECTED (REVISION 2)
BLOCK 3: REMOVED (REJECTED IN PREVIOUS FORM)
UNCERTAIN OUTCOMES: HOLD/BLOCK — NON-RETRYABLE UNTIL B25-03C DURABLE RECONCILIATION
H6 ↔ B25-03C BOUNDARY: EXPLICIT (H6 = truthful classification + intra-session semantics; B25-03C = durable state + reconciliation + restart safety)
IMPLEMENTATION: NOT AUTHORIZED
COMMIT: NOT AUTHORIZED
PUSH: NOT AUTHORIZED
B25-03C-B: BLOCKED
B25-03C-C: NOT AUTHORIZED
NEXT SENIOR DECISION: REVIEW CORRECTED H6 DESIGN (TDD AUTHORIZATION PENDING)
STOP.
```