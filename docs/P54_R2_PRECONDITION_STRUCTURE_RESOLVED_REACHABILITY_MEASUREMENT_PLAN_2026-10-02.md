# P54 — R2′ PRECONDITION: STRUCTURE-RESOLVED REACHABILITY MEASUREMENT PLAN

Date: 2026-10-02
Mode: DOCS-ONLY forensic plan. **Plan only — no implementation, no instrumentation, no execution authorized by this document.**
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`. Not committed (tree already dirty by prior governance; this record adds one untracked docs file and nothing else).

Evidence hashes (SHA-256, 16), recorded to permit later re-verification that the plan was written against this exact source:

| File | SHA-256 (16) |
|---|---|
| `Trading/TradeManager.mqh` | `E0DB921A6EC25E2A` |
| `Trading/CExecutionLedgerWriter.mqh` | `4F8CC8F622332E90` |
| `Trading/CExecutionRecovery.mqh` | `CDE9CC66C4CE8CF8` |
| `Trading/CExecutionPlanInspection.mqh` | `A4B0B659A0993D35` |
| `Entry/ExecutionPlanner.mqh` | `457757CB1A2A6EF5` |
| `Entry/EntryPriceResolver.mqh` | `C406266DBD6E03A4` |
| `Entry/StopLossResolver.mqh` | `DE04446DCC6B7FB9` |
| `Entry/TargetResolver.mqh` | `32C61E62B05FDF16` |
| `Tests/unit/TestP1A1DealAdmissionObservability.mqh` | `6133BFA528362C10` |

## Disposition

### `P54 MEASUREMENT PLAN ONLY — INSTRUMENTATION NOT AUTHORIZED; EXECUTION NOT AUTHORIZED; R2′ STATUS UNCHANGED`

## 0. Purpose and standing constraints

The R2′ forensic trace (see `P53_TRACK_A_FINAL_DESIGN_CLARIFICATION_AUDIT_2026-10-02.md` and the R2′ lifecycle trace) established the R2′ mechanism as source-proven while its live reachability remained unmeasured. This document does **not** investigate R2′. It defines the **upstream precondition** that must be demonstrated first.

**Precondition under test:**

> Can the current intended live configuration produce a `structureResolved=true` execution plan that reaches `Inspect() == NOT_FOUND` and subsequently `OrderSend()`?

**Causal chain that makes this prior:**

```
structureResolved=true
  -> Inspect() == NOT_FOUND
    -> BeginExecution()
      -> OrderSend()
        -> H6 RETRY_HOLD
          -> UNKNOWN
            -> R2' lifecycle becomes reachable
```

Every R2′ conclusion is gated behind `OrderSend()`. This document measures only the first gate.

**Standing constraints for this plan.** No production code change. No test modification. No settings or configuration change. No compile. No MT5 execution. No commit. No P37 work. No mitigation, no implementation proposal, and no design decision is made or implied. R1, R3, Q8, and Q10–Q14 are **not altered** by this document. The gate stated in §7 remains in force.

## 1. The exact precondition — decomposed

`structureResolved` is **not** an independent resolver result. It is the composite assigned in `Entry/ExecutionPlanner.mqh:294`:

```
plan.structureResolved = (entrySR && stopSR && targetSR);
```

| Term | Assigned at | Can it be false? |
|---|---|---|
| `targetSR` | `Entry/TargetResolver.mqh:35` | **NO — effectively constant `true`** |
| `entrySR` | `Entry/ExecutionPlanner.mqh:259` (out-param) | **YES** |
| `stopSR` | `Entry/ExecutionPlanner.mqh:270` (out-param) | **YES** |

`TargetResolver.mqh:35` assigns `structureResolved = true` before any branch and never resets it — not even on the FixedRR fallback at `:139`. The in-source rationale is explicit (`TargetResolver.mqh:33-34`): *"every target path is deterministic (structure or fixed-RR with a stable RR tier). There is no live/broker fallback in this resolver."*

**Therefore `structureResolved == entrySR && stopSR`, and the two live terms are governed by different subsystems.**

- **`entrySR`** depends on the configured entry policy and on the candidate's structural reference being findable, by id, in the corresponding detector's **current** list.
- **`stopSR`** under the default `STOP_PROTECTED_POINT` depends on the **`CProtectedPointManager` holding an active protected low/high**, which is **independent of the candidate's own OB / FVG / liquidity reference** (`StopLossResolver.mqh:79-96`).

**Consequence for instrumentation.** `entrySR`, `stopSR`, and `targetSR` must be observed as **three separate booleans**. The composite alone cannot attribute a failure: a plan blocked on `entrySR` and a plan blocked on `stopSR` are different investigations with different candidate families and different remediations. This separation is the accepted instrumentation basis of this plan.

## 2. Source-proven resolution conditions

### 2.1 `entrySR = true` — requires **all** conditions of the active policy

| `entryPolicy` | Required conditions | Source |
|---|---|---|
| `ENTRY_OB_RETEST` *(config default — `Entry/ExecutionPlanTypes.mqh:49`)* | `candidate.hasOB && candidate.obId >= 0 && obDetector != NULL` **and** a live order block with `ob.id == candidate.obId` returned by `obDetector.GetOrderBlock` | `EntryPriceResolver.mqh:20-37` |
| `ENTRY_FVG_MIDPOINT` | `candidate.hasFVG && candidate.fvgId >= 0 && fvgDetector != NULL` **and** a live FVG with matching `fvg.id` | `EntryPriceResolver.mqh:39-53` |
| `ENTRY_LIQUIDITY_LEVEL` | `candidate.hasLiquidity && candidate.liquidityId >= 0 && liqDetector != NULL` **and** a live level with matching `ll.id` | `EntryPriceResolver.mqh:55-69` |

**Entry-policy override.** `ExecutionPlanner.mqh:252-254` forces `entryPolicy = ENTRY_LIQUIDITY_LEVEL` when `!candidate.hasOB && candidate.hasLiquidity && candidate.liquidityId >= 0`, without which the `ENTRY_OB_RETEST` resolver guard would never be satisfied for Rule 5/6 `LIQUIDITY_BOS` candidates.

**Explicitly not source-proven, and not to be assumed.** That any candidate family *guarantees* a hit. The predicate is a **live list scan by id**: the detector must hold that id **at plan-build time**. A candidate referencing a stale, mitigated, invalidated, or swept id does not resolve and falls through to the `Current Price` path. Family-level resolution rates are a **measurement output of this plan**, not a planning assumption.

### 2.2 `stopSR = true`

| `stopPolicy` | Required conditions | Source |
|---|---|---|
| `STOP_PROTECTED_POINT` *(config default — `ExecutionPlanTypes.mqh:50`)* | `ppManager != NULL` **and** `GetActiveLow(pp)` for `CONFLUENCE_BULLISH` / `GetActiveHigh(pp)` for `CONFLUENCE_BEARISH` | `StopLossResolver.mqh:79-96` |
| `STOP_OB_SIDE` | `candidate.hasOB && obId >= 0 && obDetector != NULL` **and** a live OB with matching id | `StopLossResolver.mqh:41-58` |
| `STOP_LIQUIDITY_SIDE` | `candidate.hasLiquidity && liquidityId >= 0 && liqDetector != NULL` **and** a live level with matching id | `StopLossResolver.mqh:60-77` |
| any policy, fallback path | `Broker Minimum` — **always `stopSR = false`** | `StopLossResolver.mqh:97-110` |

### 2.3 Live wiring — verified, and favourably ordered

| Item | Evidence |
|---|---|
| `CProtectedPointManager` allocated and `Init`-ed | `Portfolio/SymbolContext.mqh:434-436` |
| Updated per bar pass | `SymbolContext.mqh:965` |
| Wired to `CExecutionPlanner` | `SymbolContext.mqh:548` → `Confluence/ConfluenceEngine.mqh:846` |
| OB detector wired | `ConfluenceEngine.mqh:833` |
| Liquidity detector wired | `ConfluenceEngine.mqh:853` |
| **Update ordering** | `m_protectedPointManager.Update()` (`:965`) and `m_orderBlockDetector.Update()` (`:1006`) both precede `m_tradeExecutionManager->Update()` (`:1321`) in the same bar pass |

The ordering fact is favourable: detectors are current when plans are built and executed. Execution is bar-paced, not tick-paced: `OnTick` (`SuperCents_X.mq5:166-169`) → `CEngine::Update()` → `IsNewBar()` (`Core/Engine.mqh:215-216`, impl `:441-454`) → `CPortfolioManager::Update()` (`:186`) → `CSymbolContext::Update()` → `m_tradeExecutionManager->Update()` (`:1321`).

### 2.4 Correction to a prior historical claim

`Tools/Demo_Readiness/Demo_Blocker_Forensic_Resolution.md:523` asserts that `SetConfig()` is never called on the `ExecutionPlanner`. **That claim is stale against the current tree.** The wiring exists: `SymbolContext.mqh:567-572` → `CConfluenceEngine::SetPlanConfig` (`ConfluenceEngine.mqh:856-861`) → `m_executionPlanner.SetConfig(cfg)`, with a live `ExecutionPlan target: policy=%s RR=%.2f` log line. Recorded here so the stale claim is not carried forward as a current-tree blocker.

## 3. Minimum observable evidence

Read-only observation. One record per plan reaching the end of `CExecutionPlanner::BuildPlan` (the existing log at `ExecutionPlanner.mqh:424-434` is the natural host; `:429-433` already emits `Decision`, `Status`, `Entry`, `SL`, `TP`, `StopPolicy`, `TargetPolicy`).

| Field | Source |
|---|---|
| `planId` (= `decision.candidateId`) | `ExecutionPlanner.mqh:215` |
| symbol, `_Period` | runtime |
| `candidate.hasOB` / `hasFVG` / `hasLiquidity` | `TradeCandidate` |
| `candidate.obId` / `fvgId` / `liquidityId` | `TradeCandidate` |
| `entryPolicy` (config value **and** any `:252-254` override) | `ExecutionPlanner.mqh:252-254`, `:291` |
| `stopPolicy`, `targetPolicy` | `ExecutionPlanner.mqh:292-293` |
| **`entrySR`** | `ResolveEntryPrice` out-param, `:259` |
| **`stopSR`** | `ResolveStopLoss` out-param, `:270` |
| **`targetSR`** | `ResolveTakeProfit` out-param, `:278` |
| **`structureResolved`** (composite) | `ExecutionPlanner.mqh:294` |
| `entryPolicyUsed` / `stopPolicyUsed` / `targetPolicyUsed` | already logged `:429-433` |
| entry / SL / TP | `:429-431` |
| `GetActiveLow` / `GetActiveHigh` outcome at build time | for `stopSR` attribution |

Second read-only probe, one record per plan entering the `CTradeManager::Update()` gate chain, keyed by `planId`, recording:

| Field | Source |
|---|---|
| `structureResolved` as passed to inspection | `TradeManager.mqh:403` |
| **inspection verdict** (`MATCHED` / `AMBIGUOUS` / `NOT_FOUND` / `CORRUPT` / `UNAVAILABLE`) | `:399-410` |
| `BeginExecution` reached, and its boolean result | `:419-430` |
| `OrderSend` reached | `:444` |
| `truth.retcode` | `:466` |

### 3.1 Instrumentation trap 1 — the return value is **not** the signal

`ResolveEntryPrice` returns `true` on the `Current Price` fallback (`EntryPriceResolver.mqh:71-73`). `ResolveStopLoss` returns `true` on the `Broker Minimum` fallback (`StopLossResolver.mqh:105-110`). In both cases the `bool &structureResolved` out-param remains **`false`**.

**Any probe keying on the resolver return value would report structural resolution for non-structural plans.** That conflation is precisely what made the historical Demo attribution unprovable (§6). The probe must read the out-params.

### 3.2 Instrumentation trap 2 — `targetSR` must still be observed

`targetSR` is source-proven as effectively constant `true` (§1), but it is to be **recorded as an observed field rather than assumed**, so that the composite in `:294` remains verifiable against observation instead of resting on a source reading alone.

## 4. Measurement population — the S1–S8 funnel

Each stage is a **set of distinct plan IDs**. Cardinalities are reported per stage **with the planId lists retained**.

| Stage | Definition | Source |
|---|---|---|
| **S1** plans created | `m_totalCreated` | `ExecutionPlanner.mqh:409` |
| **S2** `PLAN_EXECUTABLE` | valid path | `ExecutionPlanner.mqh:398-399` |
| **S3** `entrySR = true` | resolver out-param | `:259` |
| **S4** `stopSR = true` | resolver out-param | `:270` |
| **S5** `structureResolved = true` | composite, S3 ∧ S4 | `:294` |
| **S6** `Inspect() == NOT_FOUND` | recorded verdict | `TradeManager.mqh:399-410` |
| **S7** `BeginExecution` succeeded | boolean result | `TradeManager.mqh:419-430` |
| **S8** `OrderSend` attempted | reached | `TradeManager.mqh:444` |

S3 and S4 are reported **separately and before** S5. The composite is never reported alone.

### 4.1 Hard rule — aggregate counters are not populations

**No aggregate counter may be reported as a population.** Every stage is a distinct plan set with retained planIds.

This rule is carried directly from the demonstrated historical defect: `m_totalInspectionBlocked` (`TradeManager.mqh:406`) is incremented once per plan per **bar** inside the `Update()` loop, is never reset except at `Shutdown`, and therefore counts repeated emissions rather than distinct plans. The Demo log proves the multiplicity directly — `Demo_Blocker_Forensic_Resolution.md:614, 618, 619` shows three emissions spanning **two** distinct plans, with Plan 2 appearing twice, and `:622` states *"Plan 2 is re-inspected every time."* Reading that counter as a plan population produced an unprovable attribution. S1–S8 must not repeat the error.

## 5. Success / failure conditions

| Outcome | Criterion |
|---|---|
| **REACHABLE** (gate 1 demonstrated) | ≥1 genuine M15 plan observed at **S5**, with `entrySR` and `stopSR` **individually attributed**. Preferred: continue to **S6**. |
| **SEND REACHABLE** (gate 2 demonstrated) | ≥1 plan observed at **S8**. Only this makes R2′ live reachability measurable. |
| **STILL UNPROVEN** | Zero plans at S5 within the authorized observation window. **This is absence of evidence and must be reported as exactly that.** |
| **UNREACHABLE** | Requires **positive** demonstration that every candidate path resolves `entrySR = false` (id-scan miss across all three entry policies) **or** `stopSR = false` (`GetActiveLow` / `GetActiveHigh` never satisfied), evidenced by per-term counts. |

**Zero sends alone does not qualify as UNREACHABLE.** The Demo run reached zero sends for an environmental reason while both live terms were untested, and its zero-send result is confounded on two independent grounds (§6). `UNREACHABLE` is a positive finding about the resolver predicates, not an observation of absence.

## 6. Historical evidence treatment

`Tools/Demo_Readiness/Demo_Blocker_Forensic_Resolution.md` is **historical context only**. It is **not** evidence about the current tree, for two independently sufficient reasons:

1. **Its primary blocker is an environment artifact.** `:521` and `:525` attribute `structureResolved=false` to the M1 order-block detector failing to locate the candidate's OB due to an **M1-vs-M15 chart deployment mismatch**. That is a deployment condition, not a code property.
2. **Its second blocker is stale.** `:523` (the `SetConfig()` claim) is contradicted by current source — see §2.4.

Consequently the historical zero-send result is equally consistent with *"no plan in that run had `structureResolved=true` because the EA ran on the wrong timeframe"* and *"no plan ever has."* The precondition is therefore **unproven in both directions**, which is why it must be measured rather than inherited.

The intended live timeframe for this measurement is **M15**, not the historical M1 demo configuration.

## 7. Scope of inference and the S8 gate

**This plan measures only the S1–S8 funnel. It yields no `RETRY_HOLD` frequency, no `UNKNOWN` observation, and no R2′ conclusion.**

**GATE — retained and binding:** every R2′ reachability measurement, including any `RETRY_HOLD` frequency measurement, is **blocked until S8 is demonstrated**. A demonstrated S5 or S6 is a necessary but **not** sufficient precondition for R2′ investigation; only S8 places an execution inside the H6 classification that can produce `UNKNOWN`.

The `UNKNOWN` lifecycle itself is already source-closed by the R2′ trace and is **not re-opened** by this plan:

- Exactly one production producer: `H6_POLICY_RETRY_HOLD`, including the `default:` catch-all (`TradeManagerRetryPolicy.mqh:86-91`, `:94-95`).
- Live self-heal `UNKNOWN → DEAL_IN → FILLED` is legal and restores `brokerVisible` (`CExecutionLedgerWriter.mqh:457-471`; `CExecutionRecovery.mqh:103-106`).
- The restart/reconciliation cliff terminalizes lineage to `RESOLVED` / `BLOCKED`, both terminal and both non-broker-visible, after which late `DEAL_IN` attribution is impossible through the `!terminal` selection predicate at `CExecutionLedgerWriter.mqh:464`.

What remains unmeasured is the **live occurrence** of any of it, which is what S8 gates.

## 8. Explicit exclusions

No `RETRY_HOLD` conclusions · no `UNKNOWN` conclusions · no R2′ reachability conclusion · no P37 work · no PlanIdentity change · no stop-policy change · no production patch · no test modification absent separate authorization · no settings or configuration change · no compile · no MT5 execution · no commit.

## 9. Governance

No production file, test, setting, or configuration touched. No compile, no run, no measurement performed. **This document adds one untracked docs file and nothing else.** No commit (the tree was already dirty by prior governance). No behavior claim of any kind is made or implied. No mitigation, implementation proposal, or design decision is made — selecting a remediation for the R2′ mechanism, or answering Q10–Q14, remains outside this document and outside any authorization it conveys.

**Governing gate state, unchanged by P54:**

| Item | Status |
|---|---|
| R2′ — `UNKNOWN` invisibility | **PARTIALLY PROVEN / TRACE GAP REMAINS** (candidate, not finding) |
| Q8 / historical 44-block population | **Unanswerable from current instrumentation** — unaltered by P54 |
| Q10–Q14 | Design questions only — unaltered by P54 |
| R1, R3 | Unaltered by P54 |
| S5 / S6 / S7 / S8 instrumentation | **NOT AUTHORIZED** by this document |
| Implementation | **NOT AUTHORIZED** |
| P37 | **UNCHANGED / BLOCKED** |

**STOP after P54.** The next executable step requires a separate human authorization naming the specific stage to instrument and the observation window. P54 authorizes the plan's existence, not its execution.
