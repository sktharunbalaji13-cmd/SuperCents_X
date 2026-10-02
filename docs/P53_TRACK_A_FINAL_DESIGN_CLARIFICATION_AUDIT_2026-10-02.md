# P53 — TRACK A FINAL DESIGN CLARIFICATION AUDIT (R1 / R2′ / R3)

Date: 2026-10-02
Mode: READ-ONLY forensic/design review. No production files, no tests, no implementation. This record is the only tree change.
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`. Not committed (attributable dirty tree preserved; no commit authorized).
Evidence hashes (SHA-256, 16): `TradeManager.mqh` `E0DB921A6EC25E2A` · `CExecutionPlanInspection.mqh` `A4B0B659A0993D35` · `CExecutionRecovery.mqh` `CDE9CC66C4CE8CF8` · `CExecutionLedgerWriter.mqh` `4F8CC8F622332E90`.

## Disposition

### `P53 AUDIT COMPLETE — IMPLEMENTATION NOT AUTHORIZED; P37 UNCHANGED AND BLOCKED; R2 SUPERSEDED BY R2′`

## 0. Supersession notice (read before reusing any prior R2 wording)

The Track A audit's original **R2** claimed that registering PlanIdentity before `RecordSubmitted()` can suppress a later twin even when the original plan never reached the broker, and it nominated `RecordSubmitted()` as the registration boundary. **That premise is not supported by the current read path.** R2 is withdrawn and replaced by **R2′** (§2), which is a candidate, not a finding.

Consequence for the human decision packet: **the old R2 wording must not be carried forward.** Q3 is answered differently than posed, and Q4 must be restated against R2′ (§5). The correction stays entirely inside the design/forensic phase — the original audit had already left implementation unauthorized, so nothing was ever gated on the superseded text.

Why the original premise fails:

- `Inspect()` skips every replayed state with `!brokerVisible` (`Trading/CExecutionPlanInspection.mqh:126`).
- `brokerVisible` is true only for `SUBMITTED / ACCEPTED / PARTIALLY_FILLED / FILLED` (`Trading/CExecutionRecovery.mqh:73-77`).
- `EXEC_STATE_INTENT` is not in that set, so an INTENT-only record — the exact "registered, never reached the broker" case — is already excluded from identity comparison and cannot suppress a later twin.

## 1. R1 — `UNAVAILABLE` inspection is unbounded and unlatched, but fail-closed

**Mechanism.** `Inspect()` tests file existence before any scan and returns `EINSPECT_UNAVAILABLE` when the ledger is absent (`CExecutionPlanInspection.mqh:107-108`). `CTradeManager` treats any verdict other than `NOT_FOUND` as a block (`Trading/TradeManager.mqh:404-410`): increments `m_totalInspectionBlocked`, logs `ORDER-BLOCKED-INSPECTION`, `continue` — no send.

**Why it persists indefinitely.** The ledger file is created by the writer at `Init`; a missing file at inspection time therefore means the durable evidence source was lost after creation. Nothing repairs it. Startup replay does not latch it either: `CExecutionRecovery::Init` on a missing path sets `LEDGER_SCAN_CLEAN`, `m_blocked = false`, and returns (`CExecutionRecovery.mqh:345-350`). Contrast `CORRUPT`, which sets `m_blocked = true` on mid-file/header/seq-violation (`CExecutionRecovery.mqh:367-374`) and on replay-invariant violation (`:377-382`).

**Bounding.** None. There is no attempt counter, no latch, no backoff. Every tick, for every executable plan, the verdict is recomputed, the counter incremented, and a log line emitted. The scan itself is cheap (the `UNAVAILABLE` return precedes `LedgerScan`), so the cost is repeated counter/log/CPU activity, not I/O amplification.

**Risk class.** **Fail-closed.** No authorization to trade results from this path. Standing as an open design question (Q1–Q2), not as a defect requiring urgent correction.

## 2. R2′ (candidate) — the `UNKNOWN` lineage is invisible to duplicate detection

This is the inverse failure direction of the withdrawn R2: not over-suppression, but **under-suppression**.

**Mechanism.** `brokerVisible` is a property of an execution's **final** replayed state, not of its history (`CExecutionRecovery.mqh:303`). The only durable lineages that end broker-visible are those that passed through `H6_POLICY_RECORD` → `LEDGER_EVENT_SENT` / `EXEC_STATE_SUBMITTED` (`CExecutionLedgerWriter.mqh:297-301`), plus any later FILLED / PARTIAL / DEAL_IN path.

An execution whose send outcome is uncertain takes `H6_POLICY_RETRY_HOLD` → `LEDGER_EVENT_UNKNOWN` / `EXEC_STATE_UNKNOWN` (`CExecutionLedgerWriter.mqh:307-311`). `UNKNOWN` is non-terminal (`CExecutionRecovery.mqh:67-71`) and is **never** broker-visible (`:73-77`). Durable reconciliation then moves it to `RESOLVED` or `BLOCKED` (`CExecutionLedgerWriter.mqh:401-410`), and `IsBrokerVisibleState` returns false for **both** of those terminal states as well.

Therefore `Inspect()` returns `NOT_FOUND` for an identical twin of such an execution at every point in its lineage — while pending *and* after durable resolution.

**Guards that do and do not apply.**

| Guard | Scope | Covers the `UNKNOWN` lineage? |
|---|---|---|
| `IsAlreadySubmitted(planId)` → `m_submittedIds` (`TradeManager.mqh:233-237, 572-578`) | in-memory, session-only; freed at `Shutdown` (`:553-554`) | No — populated only on `H6_POLICY_RECORD` (`:498`) |
| `IsRetryHeld(planId)` → `m_retryHoldIds` (`:242-243, 590-596`) | in-memory, session-only; freed at `Shutdown` (`:555-556`) | Suppresses re-attempt of the **same planId** within the session only |
| `Inspect()` / durable ledger | cross-run | **No** — lineage is broker-invisible |

An identical twin depends on the same `(symbol, side, magic, entryPolicy, stopPolicy, targetPolicy)` plus all three prices within `1e-9` for `MATCHED`, or any one within `eps = 1e-4` for `AMBIGUOUS` (`CExecutionPlanInspection.mqh:39-57, 122`). Both are strict, and the planner policy table is small and fixed (`§3`), so recurrence is plausible but **unmeasured**.

**Why this is a candidate and not a finding.** Not established: (a) that an identical twin is in fact generated after a `RETRY_HOLD` in the same session or a later run; (b) the observed frequency of `H6_POLICY_RETRY_HOLD` under live flow; (c) whether reconciliation of the original execution suppresses a future twin by some path not traced here. **Required next step is a targeted trace, not a patch.**

**Bounding note.** A `UNKNOWN` lineage is non-terminal, so it surfaces through `GetPendingExecutions` (`Portfolio/SymbolContext.mqh:713`) and is subject to B25-03C durable reconciliation — the designed release path for the uncertain outcome itself. Reconciliation establishes the truth of the *original* execution; it does not by itself suppress a *future* twin.

## 3. R3 — stop-policy identity carries little information under current configuration

**Corroborated by the planner table.** `ExecutionPlanner` sets `base.stopPolicy = STOP_PROTECTED_POINT` (`Entry/ExecutionPlanner.mqh:567`) and six of eight tier configs inherit it (`:593-627`). `STOP_BROKER_MINIMUM` appears exactly once (`:596`). The enum has only two members (`Entry/ExecutionPlanTypes.mqh:26-27`). `STOP_PROTECTED_POINT` is therefore effectively a constant across live configuration and contributes near-zero discriminative power to `ComparePlanIdentity` (`CExecutionPlanInspection.mqh:39-43`).

**Two-dimensional identity under FixedRR.** With `TARGET_FIXED_RR`, TP is derived from entry and SL, so the three price fields `planEntryPrice / stopLoss / takeProfit` carry only **two independent quantities**. The identity is already lower-dimensional than its field list implies; combined with the near-constant `stopPolicy`, the effective discriminative content of PlanIdentity is materially smaller than a field count suggests.

**Unmeasured.** OB-side and liquidity-side stops are not distinguished in the current policy enum and their distribution is unknown. No weight has been assigned to persistent OB / liquidity structure in identity.

**Also confirmed.** `plan.structureResolved = (entrySR && stopSR && targetSR)` (`Entry/ExecutionPlanner.mqh:294`); `!structureResolved` short-circuits to `EINSPECT_AMBIGUOUS` before any ledger access (`CExecutionPlanInspection.mqh:86-87`) — a fail-closed path independent of R1.

## 4. Historical 44-block population — attribution NOT proven

The prior attribution of the 44 historical blocks to `!structureResolved` is **not established**. Three distinct `AMBIGUOUS` mechanisms exist in the current read path:

1. `!structureResolved` on the **current** plan (`CExecutionPlanInspection.mqh:86-87`) — pre-scan, no ledger I/O.
2. `prior.present == false` on a legacy record lacking PI fields (`CExecutionPlanInspection.mqh:36-37`).
3. **Near**-match on one of three price fields within `eps = 1e-4` (`:51-55`), aggregated across all inspected states (`:133-137`).

The historical evidence does not discriminate among these three. **The 44 must not be combined with the current six**, and Q8 stays open: conclusive re-attribution requires instrumentation (a per-mechanism reason code on the `AMBIGUOUS` return) that does not exist today.

## 5. Open design questions — nine, none actionable without human decision

| # | Question | Status after P53 |
|---|---|---|
| Q1 | Should `UNAVAILABLE` use the same permanent `m_blocked` latch as `CORRUPT`, or bounded retry? | Open. Fail-closed either way; cost vs. latch-symmetry trade only. |
| Q2 | If bounded retry, what cap, and where is the counter stored? | Open. Depends on Q1. |
| Q3 | Should `RecordSubmitted()` be the PlanIdentity registration boundary? | **Answered — no.** It is in-memory `m_submittedIds` (`:572-578`), populated only in the `H6_POLICY_RECORD` branch (`:498`), and is **not consulted by `Inspect()`**. The durable identity boundary is `RecordResult()` under `H6_POLICY_RECORD` (`TradeManager.mqh:472`), which is the call that appends the `SENT`/`SUBMITTED` event. The `brokerVisible` filter already implements that boundary implicitly, so **no change is implied by this answer**. |
| Q4 | What happens to a later identical plan after one of the four pre-`RecordSubmitted` failures? | **Restated.** Withdrawn with R2. The four paths (validation, request build, inspection block, INTENT write-ahead failure) all precede any broker-visible state; three earlier `continue` gates (duplicate `:233`, retry-hold `:242`, position cap `:249`) also precede it. The live question is now R2′: what should happen to an identical twin of a durable `UNKNOWN` lineage — suppress fail-closed until resolved, or leave as-is? |
| Q5 | Should `STOP_BROKER_MINIMUM` be treated as strong identity despite being the fallback path? | Open. Low observed incidence (1 of 8 configs). |
| Q6 | How should persistent OB / liquidity structures be weighted? | Open. Unmeasured. |
| Q7 | Does the two-dimensional identity under FixedRR satisfy the intended duplicate-detection guarantee? | Open. Depends on Q5–Q6. |
| Q8 | Should the historical 44-block population be re-attributed before use as design evidence? | **Open — unanswerable from current instrumentation** (§4). |
| Q9 | Should `takeProfit` remain in PlanIdentity when mathematically dependent? | Open. Depends on Q7. |

## 6. Governance

No production file, test, or setting touched; no compile, no run, no measurement. P37 unchanged and **still blocked**; P31 / C4 / B8 / B9 / P39 / P41-cap / P48 / P52 preserved. No promotion, no certification, no profitability, WFO, research, or deployment action. No commit (tree already dirty by prior governance; this record adds one untracked docs file and nothing else). No behavior claim of any kind is made or implied by this document.

**STOP after P53.** The remaining work is design-level. Implementation of anything in §1–§4 requires a separate human authorization naming the specific item; the next executable step for R2′ is the targeted trace described in §2, not a code change.