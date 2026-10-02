# Sprint 25B — B25-03C-B Dependency Re-Audit (H6 Remediation, Rev 2)

- Document ID: SR-25B-B03CB-H6RE-01
- Type: READ-ONLY dependency re-audit. Assessment/design consistency review only. No implementation. No modification of the two B25-03C-B documents. No commit, no push.
- Authoritative baseline reviewed: **HEAD `157e3a4c02d927569e94eafaec584b043dd5e715`** ("fix: correct H6 send-attempt retry semantics (Rev 2) on live legacy execution path"), parent `7d4eecb` (verified on GitHub).
- Scope: re-open the B25-03C-B assessment/design against the NEW execution semantics introduced by H6 (157e3a4): `RecordSubmitted()` is now conditional, retry-eligibility exists for deterministic refusals, and uncertain outcomes are held.
- Method: full read of both B25-03C-B documents + `git show HEAD:` of `Trading/TradeManager.mqh`, `Trading/TradeManagerRetryPolicy.mqh`; no runs, no experiments.
- Audience note: this re-audit is a THIRD document. It does not edit the two B25-03C-B documents (which remain blocked and frozen pending this re-alignment decision).

---

## 1. Executive verdict

- The H6 remediation (157e3a4) changes the exact execution semantics the B25-03C-B design was written against (7d4eecb: unconditional `RecordSubmitted`, "never retried", B6 report-vs-code discrepancy).
- **No stop condition is triggered.** H6 does not contradict the B25-03C-B reconciliation model — it strengthens it:
  - The new hold map (`m_retryHoldIds[]`) is precisely the "pending/UNKNOWN executions" population that `CExecutionRecovery` must seed and resolve.
  - The new retry-eligible class is exactly "broker-verified no-deal" — the only condition under which B25-03C-B already permits provisioning a NEW executionId (Principle 2).
  - The `H6ClassifyPolicy` output maps onto the existing 9-event vocabulary (INTENT/SENT/REJECTED/UNKNOWN/DEAL_IN/…) with **no new event type required**.
- **Verdict: B25-03C-B design semantics remain VALID; its two documents REQUIRE a re-alignment pass** (identified in §5/§6, NOT applied here) to consume the committed H6 4-class policy instead of the superseded unconditional-record/never-retry model.
- B25-03C-B stays BLOCKED pending that re-alignment authorization (a documentation edit, distinct from implementation).

---

## 2. Authoritative baseline change and H6 semantic deltas

Baseline moved `7d4eecb` → `157e3a4` (fast-forward, +4 files). The H6 deltas that affect B25-03C-B (all source-proven at `157e3a4`, `Trading/TradeManager.mqh` unless noted):

| # | Aspect | 7d4eecb (old, cited by B25-03C-B) | 157e3a4 (new) | Citation |
|---|--------|-----------------------------------|---------------|----------|
| 1 | `RecordSubmitted` | unconditional after every attempt (`:340`) | **conditional**, only in `H6_POLICY_RECORD` | `:375` (inside RECORD case) |
| 2 | Send-attempt failures | recorded as submitted, never retried | **not recorded**; split into 3 classes | `:379` (reject-permanent), `:388` (retry-eligible), `:397` (hold) |
| 3 | Retry | none (dedup-blocked) | **retry-eligible** for deterministic transient refusals (plan stays `PLAN_EXECUTABLE`, unrecorded → re-attempt next tick) | `:388-393` |
| 4 | Uncertain outcome | recorded as submitted, left `PLAN_EXECUTABLE` (dedup-blocked) | **HOLD**: unrecorded, not rejected, no release until B25-03C | `:397-403`, `:213` |
| 5 | Policy seam | none | `H6ClassifyPolicy(retcode, dealTicket)` → `ENUM_H6_RETRY_POLICY` | `Trading/TradeManagerRetryPolicy.mqh` |
| 6 | Hold map | none | `m_retryHoldIds[]` + `IsRetryHeld`/`HoldForRetry` (RAM, session-scoped) | `:49-50`, `:458-471` |
| 7 | Tallies/observability | `m_totalSubmitted` per attempt | `m_totalSubmitted` = true submissions only; new `m_totalHeld`, "Held (Uncertain Outcome)" summary | `:422`; test seams `GetHeldCount`/`GetTotalHeld`/`IsPlanRetryHeld`/`HoldPlanForRetry` (`:93-96`) |
| 8 | OrderSend site | `:302` | **`:328`** (single site, unchanged in behavior) | `:328` |
| 9 | B6 discrepancy (report §11 vs code) | OPEN (assessment B6/D5) | **RESOLVED** by the remediation | H6 committed + tested |

Net effect on the execution model the design assumed: "attempted → recorded → never retried" is now "classified → record OR reject OR retry OR hold", with the hold set being RAM-only (session-scoped) and therefore exactly the population that durable reconciliation must resolve across restarts.

---

## 3. Re-audit of the Assessment document (`docs/Sprint25B_B25-03C-B_ExecutionTruth_Reconciliation_Assessment.md`)

### 3.1 Stale / now-incorrect statements

| Loc | Current text (7d4eecb-aligned) | Status at 157e3a4 |
|---|---|---|
| L5 | "Authoritative baseline: HEAD 7d4eecb…" | STALE — baseline is 157e3a4 |
| L43-64 §2 trace | `:316-334` outcome branch; `:336-341` `RecordSubmitted(planId); m_totalSubmitted++` "unconditional after the send attempt" | STALE — now policy switch `:349-403`; `RecordSubmitted` only at `:375` (RECORD); hold skip `:213`; hold map `:49-50`/`:458-471`; OrderSend `:328` |
| L90 | "After every OrderSend attempt — success or failure — `RecordSubmitted(planId)` fires unconditionally (:340)" | **FALSE now** — only RECORD-class records |
| L120-121 §4 | "Every OrderSend attempt — including TIMEOUT, CONNECTION_ERROR, REJECTED — is recorded as submitted (:340)" | **FALSE now** |
| L124 B4 | "crash between OrderSend (:302) and RecordSubmitted (:340)" | STALE — window is `:328 ↔ :375` and only for RECORD; REJECT/HOLD paths never record |
| L128 B6 | "no retry exists — unchanged … RecordSubmitted (:340) unconditional … report-vs-code discrepancy is a C1-C7 review item (B6)" | **RESOLVED/REMOVE** — H6 remediation committed; retry-eligible + hold now exist |
| L171-172 §7 | "TIMEOUT → … recorded 'submitted' (:340); never revisited" | STALE — TIMEOUT → HOLD (unrecorded), reconciled by B25-03C |
| L180 §7 | "Send-attempt failure … recorded as submitted (:340) … retryability claims moot (B6)" | STALE — 4-class split |
| L214 §9 | "Retry policy becomes entangled … no automated re-send of an existing executionId" | NUANCE — H6 now has a plan-level retry (transient refusals); the executionId-level "never re-send" rule still holds; must be re-stated as a clean boundary (retry = new executionId) |
| L219 §9 | "C1-C7 … retryability claim … contradicted by code — B6" | STALE — discrepancy closed |
| L226 D5 | "D5 — independent C1-C7 review (incl. the report-vs-code retryability discrepancy, B6)" | UPDATE — D5 now COMPLETE (C1-C7 review + H6 assessment/design/implementation all done); the H6 remediation itself is the new prerequisite |
| L237 §10 | "Send-attempt failures: still recorded as submitted (:340) — same as e881897 … B25-03C-B does not design against retryable sends" | STALE |
| L244 §10 | "the retryability discrepancy (report §11 vs code :336-341)" | REMOVE — resolved |
| L254 §11 | "safe to design … against committed HEAD 7d4eecb" | STALE — 157e3a4 |
| L260 §11 | "send-attempt failures are recorded as submitted (:340) — design treats as SENT/UNKNOWN, never retryable" | STALE — 4-class |

### 3.2 Still-valid statements (no change required)

Evidence hierarchy (E1–E6), B1/B2/B3/B5/B7/B8/B9/B10/B11/B12 findings, verdict set, boundary rules, D1–D4 dependencies, `ParseEntryDecisionId` version-agnostic property, ledger/identity-unwired facts, "RAM-only dedup by candidateId" — all remain valid. Only the H6-specific statements (B6, the record/dedup/retry descriptions) and baseline/line-number references are stale.

---

## 4. Re-audit of the Design document (`docs/Sprint25B_B25-03C-B_ExecutionTruth_Reconciliation_Design.md`)

### 4.1 Stale / now-incorrect statements

| Loc | Current text | Status at 157e3a4 |
|---|---|---|
| L5 | baseline `7d4eecb…` | STALE → 157e3a4 |
| L7 | "records the independent C1-C7 review as dependency D5" | UPDATE — D5 complete; H6 remediation is the new consumed behavior |
| L17 §0 | "single OrderSend site :302; no retry" | STALE — `:328`; retry-eligible + hold now exist |
| L25 Principle 2 | "only a broker-verified NO-DEAL may provision a NEW executionId" | VALID but must be EXPLICITLY reconciled with H6 retry-eligible (= broker-verified no-deal → new executionId per re-attempt) |
| L114 R18 | "Send-attempt failure (retcode != 0, no deal); committed RecordSubmitted :340 … never retried … do NOT design against the uncommitted 'retryable' claim (B6)" | **OBSOLETE** — split into 4 rows (§5.1 below) |
| L138 §5.2 | "`TradeManager.Update()` (:155-343) … keep `m_submittedIds[]` (:184-188)" | STALE line refs; must add hold-skip `:213` and the policy switch |
| L170 §6 | "…existing outcome logging (:316-334), RecordSubmitted (:340), tallies (UNCHANGED)" | STALE — policy switch; `RecordSubmitted` is now the RECORD branch (`:375`) |
| L181 DP-1 | "send-attempt failures are recorded as submitted (:340) and are never retried" | OBSOLETE (send-attempt half); the pre-send half remains valid |
| L215 case R | "Send-attempt failure (retcode TIMEOUT/CONNECTION/REJECT) … SENT/UNKNOWN … never retried" | STALE — REJECT→retry-eligible (new INTENT); TIMEOUT/CONNECTION→HOLD→UNKNOWN |
| L231 B24 | "no unreviewed C1-C7 claim (e.g., retryable sends) enters the design" | UPDATE — "retryable sends" is now committed, tested behavior (157e3a4); B24 must reference the committed 4-class policy |
| L243 G5 | "`7d4eecb` untouched" | STALE → 157e3a4 baseline |
| L247 G9 | "C1-C7 retryability discrepancy (assessment B6) is not relied upon" | STALE — discrepancy resolved |
| L254-255 §11 | D5 recorded; "7d4eecb not amended" | UPDATE — D5 complete; 157e3a4 baseline |

### 4.2 Still-valid statements (no change required)

Verdict model (§3.2), evidence hierarchy (§2), recovery semantics R1–R16, ledger-core boundary contract (§5), state model (§7), adversarial A–I + J–Q, invariants B16–B23, gates G1–G4/G6–G8, out-of-scope guardrails — all remain valid. The 9-event vocabulary is unchanged and sufficient.

---

## 5. Identified design changes (NOT applied — this is a re-audit, not an edit)

### 5.1 R18 must be split (the core correction)

Replace the single R18 with four rows, mapping the committed `H6ClassifyPolicy` output to the writer:

| New row | H6 policy class | Writer event | candidateId dedup | Recon state |
|---|---|---|---|---|
| R18a | RECORD (PLACED/DONE/DONE_PARTIAL, or `deal != 0`) | `SENT` (then `DEAL_IN`) | `RecordSubmitted` → blocked from re-send | SENT/ACCEPTED/FILLED/PARTIALLY |
| R18b | REJECT_PERMANENT (INVALID*/ONLY_REAL) | `REJECTED` | not recorded; plan `PLAN_REJECTED` | REJECTED (terminal) |
| R18c | RETRY_ELIGIBLE (deterministic transient refusal) | `REJECTED` (this attempt) → **new `INTENT` + new executionId on re-attempt** | not recorded → plan re-enters loop | REJECTED then new SENT per re-attempt |
| R18d | RETRY_HOLD (TIMEOUT/CONNECTION/ERROR/NO_CHANGES/ORDER_CHANGED/0/unknown) | `UNKNOWN` | not recorded; plan held | UNKNOWN/pending — resolved by E2/E3/E4 (R4/R5/R10) |

Key consequences:
- **No new event type** — REJECTED/UNKNOWN/SENT/INTENT already cover all four classes.
- **Retry = new executionId** — R18c makes explicit that a retry-eligible re-attempt provisions a NEW executionId under the SAME decisionId (candidateId). This is compatible with Principle 2 ("only broker-verified NO-DEAL may provision a NEW executionId") because a deterministic refusal retcode IS broker-verified non-execution.
- **The hold map is the reconciliation seed** — `m_retryHoldIds[]` (TradeManager `:49-50`, `:458-471`) and the `HoldPlanForRetry`/`IsPlanRetryHeld` seams are the exact `CExecutionRecovery.GetPendingExecutions()` population; R4/R5/R10 consume them.

### 5.2 Dedup model update

- The same-run secondary guard `IsAlreadySubmitted` (candidateId) now only ever contains RECORD-class plans (because only RECORD calls `RecordSubmitted`). This **naturally** makes retry-eligible plans re-attemptable (not in the set) and is consistent with B20 (candidateId dedup never suppresses a different executionId).
- R11 ("same-run duplicate plan → BLOCKED") must be nuanced: a "duplicate" is a plan with an existing broker-visible submission (RECORD), NOT a plan that received a transient refusal. Clarify the wording so it does not contradict R18c.

### 5.3 New/updated invariants

- **B24 (update):** "B25-03C-B relies on the committed H6 4-class retry policy (`TradeManagerRetryPolicy.mqh`, `H6ClassifyPolicy`) and the committed hold-map semantics at 157e3a4; no superseded unconditional-record/never-retry behavior is assumed."
- **B25 (new):** "Every retry-eligible re-attempt provisions a NEW executionId under the SAME decisionId; an executionId is never re-sent (Principle 2 preserved)."
- **B26 (new):** "The recovery pending set is seeded from the committed hold map (uncertain outcomes) plus ledger UNKNOWN events; the two converge to one pending population (dedup key = executionId, and for pre-ledger held plans, decisionId)."

### 5.4 Wire-in / pseudocode update (§5.2/§6)

- `OrderSend` site citation `:302` → `:328`; `Update()` span `:155-343` → `:155-403`.
- Insert, in the pseudocode, the committed hold-skip (`if IsRetryHeld(planId) continue`) at `:213` (between secondary dedup and C3 gate), and reflect that `RecordSubmitted` now occurs only in the RECORD branch (`:375`).
- `writer.RecordResult(executionId, truth)` should be expressed as `writer.RecordResult(executionId, truth, H6ClassifyPolicy(truth.retcode, truth.dealTicket))` — the policy output drives the event type.

### 5.5 Dependency-table update (§9 assessment / §11 design)

- **D5 → CLOSED:** the independent C1-C7 review and the H6 assessment/design/implementation/verification are complete; the report-vs-code retryability discrepancy is resolved by commit 157e3a4.
- **New dependency note:** H6 remediation (157e3a4) is now a consumed prerequisite of B25-03C-B, exactly the prerequisite the design was blocked on.

---

## 6. Stop-condition re-check (against 157e3a4)

| Condition | Result |
|---|---|
| H6 cannot be defined unambiguously | Not applicable — H6 is implemented and tested |
| Retry semantics require durable ledger before B25-03C | NO — H6 retry is plan-level/intra-session; cross-restart safety remains B25-03C's scope (unchanged) |
| A retry can create duplicate broker execution | NO — retry-eligible = deterministic refusal (broker-verified non-execution); held outcomes never auto-retried |
| ExecutionId semantics require changing B25-03A | NO — retry = new seq under same decisionId (already supported) |
| C1-C7 behavior must change | NO — H6 committed as its own commit |
| Frozen evidence rewritten | NO |
| TT01 semantics change | NO |
| Reconciliation requires guessing | NO — H6 hold map defers to B25-03C reconciliation, never guesses |

No stop condition triggers. The B25-03C-B design's own §9 dependency table (assessment) remains NOT-TRIGGERED except the D5/review status updates noted above.

---

## 7. Verdict

B25-03C-B (assessment + design) is **semantically consistent** with the new authoritative execution semantics of `157e3a4`, but its two documents are **stale against that baseline** and must be re-aligned (the change list in §3/§5) before they can be treated as implementation-ready.

- The H6 remediation is the prerequisite B25-03C-B was blocked on; that prerequisite is now satisfied.
- The re-alignment is a **documentation edit only** (no production/test/frozen changes); it is a separate authorization from B25-03C-C implementation.
- Recommendation: authorize a B25-03C-B re-alignment pass (rewrite the two docs against 157e3a4 per §3/§5), then re-open the implementation gate.

---

## FINAL STATUS BLOCK

```
B25-03C-B RE-AUDIT: COMPLETE
BASELINE: 157e3a4 (H6 remediation) — VERIFIED
H6 SEMANTICS: RECORD / REJECT_PERMANENT / RETRY_ELIGIBLE / RETRY_HOLD — CONSUMED
RECORDSUBMITTED: NOW CONDITIONAL (RECORD-CLASS ONLY)
RETRY: EXISTS (DETERMINISTIC TRANSIENT REFUSALS ONLY)
HOLD: EXISTS (UNCERTAIN OUTCOMES; RAM, NO RELEASE)
B6 DISCREPANCY: RESOLVED
D5: CLOSED
B25-03C-B DOCS: STALE — RE-ALIGNMENT REQUIRED (IDENTIFIED, NOT APPLIED)
STOP CONDITIONS: NONE TRIGGERED
IMPLEMENTATION: NOT AUTHORIZED
B25-03C-B RE-ALIGNMENT: NOT YET AUTHORIZED
B25-03C-C: NOT AUTHORIZED
NEXT SENIOR DECISION: AUTHORIZE B25-03C-B DOCUMENT RE-ALIGNMENT (7d4eecb -> 157e3a4)
STOP.
```