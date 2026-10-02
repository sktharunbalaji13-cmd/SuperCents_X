# SuperCents_X

MetaTrader 5 Expert Advisor. Entry point `SuperCents_X.mq5`, plus the standalone
`CalibrationRunner.mq5` calibration tool.

A structural (price-action) EA: it detects market structure on closed bars,
scores confluence, resolves entry/stop/target from structure, and sends orders
through a fail-closed execution-integrity stack backed by an append-only ledger.

---

## 1. Architecture at a glance

```
                            OnTick()                                    SuperCents_X.mq5:166
                               │
                               ▼
                    ┌──────────────────────┐
                    │  CEngine::Update()   │  Core/Engine.mqh:207
                    │  IsNewBar() gate     │  ← runs ONCE PER BAR, not per tick
                    └──────────┬───────────┘    Engine.mqh:441
                               ▼
                    ┌──────────────────────┐
                    │ CPortfolioManager    │  Scheduler per symbol
                    └──────────┬───────────┘
                               ▼
                    ┌──────────────────────────────────────────┐
                    │        CSymbolContext::Update()          │  Portfolio/SymbolContext.mqh:891
                    │  per-symbol detection → decision → exec  │
                    └──────────────────────┬───────────────────┘
                                           ▼
```

### 1.1 Detection layer (per symbol, ordered by dependency)

Each stage consumes the previous one's output. This order is load-bearing — it is
enforced by call position inside `CSymbolContext::Update()`, not by declaration order.

```
 SwingDetector ──────────────────► structural pivots (swing highs/lows)
        │                                        │
        ▼                                        ▼
 StructuralPivotEngine ──────────────► BOSDetector  (breaks of structure)
        │                                        │
        │                    ┌───────────────────┴──────────────┐
        │                    ▼                                  ▼
        │             TrendState                         ProtectedPointManager
        │                    │                          (active protected low/high)
        │                    │                                  │
        │                    └──────────────┬───────────────────┘
        │                                   ▼
        │                             CHOCHDetector  (character shift)
        │                                   │
        │        ┌──────────────────────────┼──────────────────────────┐
        │        ▼                          ▼                          ▼
        │  OrderBlockDetector         FVGDetector              LiquidityDetector
        │   (order blocks)          (fair-value gaps)         (liquidity pools)
        │        └──────────────────────────┼──────────────────────────┘
        │                                   ▼
        │                          VisualizationManager
        └──────────────────────────────►  (chart objects)
```

Source: `SymbolContext.mqh` — `:915` Swing · `:939` Pivot · `:946` BOS ·
`:958` TrendState · `:965` ProtectedPoint · `:972` CHOCH · `:1006` OrderBlock ·
`:1014` FVG · `:1021` Liquidity · `:1028` Visualization.

### 1.2 Decision layer — confluence → candidate → decision → plan

```
              ConfluenceEngine::Update()                      Confluence/ConfluenceEngine.mqh
                               │
   detectors ────────────────►│  weighted structural scoring
                               │  (S / OB / FVG / L / T / PD weights, configurable)
                               ▼
                  ┌────────────────────────┐
                  │ TradeCandidateBuilder  │  :439
                  │  builds TradeCandidate │
                  │  hasOB/FVG/Liquidity   │
                  │  + obId/fvgId/liqId    │
                  └───────────┬────────────┘
                              ▼
                  ┌────────────────────────┐
                  │ EntryDecisionEngine    │  :440
                  │  DECISION_QUALIFIED ?  │
                  └───────────┬────────────┘
                              ▼
                  ┌────────────────────────┐
                  │ ExecutionPlanner       │  :441
                  │   BuildPlan()          │
                  └───────────┬────────────┘
                              ▼
                      ExecutionPlan[]  (append-only)
```

`ExecutionPlanner::Update()` only builds plans for **new** decisions
(`ExecutionPlanner.mqh:180-181`, guarded by `m_lastDecisionCount`), so plan
creation is incremental — one plan per newly qualified decision.

### 1.3 Plan construction — the three resolvers

`BuildPlan()` (`ExecutionPlanner.mqh:212`) resolves each price independently and
records whether it came from **structure** or fell back:

```
  candidate ──┬─► ResolveEntryPrice()  ──► entryPrice  + entrySR
              ├─► ResolveStopLoss()     ──► stopLoss   + stopSR
              └─► ResolveTakeProfit()   ──► takeProfit + targetSR
                                          │
                                          ▼
                          structureResolved = entrySR && stopSR && targetSR
```

| Resolver | Source | Structural condition | Fallback (⇒ SR=false) |
|---|---|---|---|
| `ResolveEntryPrice` | `Entry/EntryPriceResolver.mqh` | `OB_RETEST`: live OB with `ob.id == candidate.obId` · `FVG_MIDPOINT`: matching FVG · `LIQUIDITY_LEVEL`: matching pool | `"Current Price"` (`SYMBOL_BID`) |
| `ResolveStopLoss` | `Entry/StopLossResolver.mqh` | `OB_SIDE` / `LIQUIDITY_SIDE`: matching id · `PROTECTED_POINT`: `GetActiveLow` (bull) / `GetActiveHigh` (bear) | `"Broker Minimum"` |
| `ResolveTakeProfit` | `Entry/TargetResolver.mqh` | opposing liquidity / OB / FVG / previous swing — **or** deterministic Fixed-RR | *(none — always `true`)* |

**Two consequences that matter operationally:**

1. **All three resolvers return `true` even on their non-structural fallback.**
   Only the `structureResolved` out-parameter tells the truth. Never infer
   structural resolution from a resolver's return value.
2. **`targetSR` is effectively constant `true`** (`TargetResolver.mqh:35` assigns it
   before any branch). So `structureResolved` reduces to `entrySR && stopSR`, and
   the three must be observed **separately** to attribute any failure.

Then risk gates run (spread, min-stop-distance, gross RR, NetRR) and the plan is
`PLAN_EXECUTABLE` or `PLAN_REJECTED`.

### 1.4 Execution layer — the gate chain

`CTradeManager::Update()` (`Trading/TradeManager.mqh:200`) walks **every**
executable plan each bar through an ordered chain. Order is the security property:

```
 #   Line     Gate                          On failure
 ─────────────────────────────────────────────────────────────────────────
 1   :226     status == PLAN_EXECUTABLE     skip
 2   :233     IsAlreadySubmitted(planId)    duplicate        (in-memory)
 3   :242     IsRetryHeld(planId)           skip             (in-memory)
 4   :249     C3 position gate              skip             (live account)
 5   :262     GetFillPrice()                PLAN_REJECTED
 6   :275     ValidateAll()                 PLAN_REJECTED
 7   :303     PositionSizer                 PLAN_REJECTED
 8   :359     IsVolumeValid()               PLAN_REJECTED
 9   :376     requestBuilder.Build()        PLAN_REJECTED
10   :396     Inspect()  ← PlanIdentity     BLOCK            (durable ledger)
11   :419     BeginExecution() INTENT       BLOCK            (write-ahead)
12   :444     OrderSend()                   ── send ──
13   :466     H6ClassifyPolicy()            record / reject / retry / hold
```

Gates 1–4 are **cheap identity/exposure** filters; 5–9 are **admissibility**;
10–11 are the **durable integrity boundary**; 12–13 are the **broker outcome**.

### 1.5 Execution-integrity stack

```
        ┌──────────────────────────────────────────────────────────────┐
        │  Execution\\execution_ledger.dat   (append-only, FILE_COMMON)│
        └──────────────────────────────────────────────────────────────┘
             ▲ writes                    ▲ reads              ▲ replay
             │                           │                    │
   ExecutionIdentity      CExecutionLedgerWriter    CExecutionPlanInspection
   (monotonic seq)        (state machine)           (cross-run duplicate
                                                      defense, PlanIdentity)
   ExecutionTruth ─────► RecordResult / RecordDeal / RecordReconciled
   CaptureExecutionTruth      RecordBlocked / BeginExecution

   CExecutionRecovery  ── startup replay, corruption latch, pending set
   CExecutionReconciler ── broker-evidence verdicts for held executions
```

**Durable state machine** (`CExecutionRecovery.mqh`):

```
                    ┌─────────┐
   BeginExecution ─►│ INTENT  │  non-broker-visible
                    └────┬────┘
        ┌────────────────┼────────────────┬───────────────┐
        ▼                ▼                ▼               ▼
  ┌──────────┐   ┌────────────┐   ┌──────────┐   ┌─────────┐
  │ SUBMITTED│   │  REJECTED  │   │ UNKNOWN  │   │ RESOLVED│
  └────┬─────┘   └────────────┘   └────┬─────┘   └─────────┘
       │  ▲        (terminal)          │
       │  └──────── DEAL_IN ───────────┤   ← live self-heal
       ▼                                ▼
  ACCEPTED / PARTIALLY_FILLED / FILLED   BLOCKED
       └────────────── terminal ────────┘

  brokerVisible = SUBMITTED | ACCEPTED | PARTIALLY_FILLED | FILLED
```

`Inspect()` compares a candidate plan's **PlanIdentity** against every replayed
state, but **skips any state where `brokerVisible == false`** (`:126`). Broker
visibility is computed from the *final* replayed state (`:302-303`), not from
history — so a lineage that ends `UNKNOWN`, `RESOLVED` or `BLOCKED` is invisible
to duplicate detection at every point, and permanently so.

**PlanIdentity** (`CExecutionPlanInspection.mqh:39-57`):
`symbol · side · magic · entryPolicy · stopPolicy · targetPolicy` + three price
fields. All three prices within `1e-9` ⇒ `MATCHED` (block); any one within
`eps = 1e-4` ⇒ `AMBIGUOUS` (block); otherwise `NOT_FOUND` (proceed).

### 1.6 H6 outcome policy — four classes

`TradeManagerRetryPolicy.mqh` classifies the broker retcode into exactly one
class. This is the only place send outcomes are decided.

| Class | Meaning | Ledger | Plan |
|---|---|---|---|
| `RECORD` | broker-visible (`PLACED`/`DONE`/`DONE_PARTIAL`, or `deal != 0`) | `SENT` → `SUBMITTED` | stays executable, dedup-recorded |
| `REJECT_PERMANENT` | deterministic defect (`INVALID*`, `ONLY_REAL`) | `REJECTED` | `PLAN_REJECTED` |
| `RETRY_ELIGIBLE` | deterministic refusal (`REQUOTE`, `REJECT`, `NO_MONEY`, `MARKET_CLOSED`, …) | `REJECTED` | stays executable → re-attempted |
| `RETRY_HOLD` | **uncertain** (`TIMEOUT`, `CONNECTION`, `ERROR`, `NO_CHANGES`, `ORDER_CHANGED`, *and any unrecognised retcode*) | `UNKNOWN` | held, never auto-retried |

`RETRY_HOLD` is the conservative default: **absence of broker evidence never
grants retry eligibility.** Its only release path is durable reconciliation.

### 1.7 Fail-closed wiring

Three independent guards refuse to trade rather than trade blind:

| Guard | Condition | Site |
|---|---|---|
| Ledger wiring | any of writer / recovery / inspection is `NULL` → execution disabled | `SymbolContext.mqh:738-750` |
| Recovery latch | `CORRUPT` ledger, torn-tail recovery failure, replay-invariant violation → all sends blocked | `CExecutionRecovery.mqh:367-382`; `TradeManager.mqh:213` |
| Ledger presence | `Inspect()` returns `UNAVAILABLE` when the ledger file is missing → block (never guess "first run") | `CExecutionPlanInspection.mqh:107-108` |

`INIT-only` reconciliation at startup (`SymbolContext.mqh:710-722`) resolves or
blocks every non-terminal execution before the first bar of the session.

---

## 2. Repository layout (EA-rooted)

| Path | Role |
|---|---|
| `Core/` | engine, config, logger, event bus |
| `Structure/` | swing, pivot, BOS, CHOCH, protected point, OB, FVG, liquidity detectors |
| `Confluence/` | weighted confluence scoring, candidate builder, signal types |
| `Entry/` | decisions, plan construction, the three resolvers, plan types |
| `Risk/` | position sizing, exposure tracking |
| `Portfolio/` | per-symbol context, allocation, capital allocation, portfolio risk |
| `Trading/` | trade manager, gate chain, H6 policy, ledger writer/recovery/reconciler, plan inspection, execution identity/truth |
| `Production/` | diagnostics, operational reporting |
| `Visualization/` | chart renderers (BOS, CHOCH, FVG, OB, liquidity, swing, pivot) |
| `Validation/` | validation lab, Monte Carlo, walk-forward, regression detection; `Sprint17/` collection evidence |
| `Calibration/`, `Optimization/`, `Research/`, `Knowledge/`, `Laboratory/` | calibration, optimisation, research, scoring, strategy catalogue |
| `Telemetry/`, `Regression/`, `RegressionLogs/`, `Monitoring/`, `benchmarks/` | telemetry and measurement |
| `Tests/` | unit/integration test suites + test runner EAs |
| `Tools/` | TT01 harness, ED01/EN03 batches, Demo readiness, baseline freeze artifacts |
| `docs/` | governance record and design documents (P1–P54, Sprint25B) |
| `Utils/`, `Providers/`, `Presets/` | shared utilities, data providers, presets |

## 3. Build

Compile `SuperCents_X.mq5` and `CalibrationRunner.mq5` in MetaEditor.
Test runners under `Tests/` compile alongside the EA.

Current build status: production EA, `TestRunnerEA` and `TestRunner` all compile
**0 errors, 0 warnings** (MT5 build 6231).

## 4. Diagnostic instrumentation (measurement only)

Two additive, read-only logging sites exist to measure the structure-resolved
reachability funnel (`docs/P54_…`). They change **no** behaviour.

| Tag | Emitted at | Records |
|---|---|---|
| `S-PLAN` | `ExecutionPlanner.mqh:469` | per plan: `entrySR` / `stopSR` / `targetSR` / `structureResolved`, candidate evidence, policies, entry/SL/TP, protected-point state |
| `S-GATE … Stage=ENTER` | `TradeManager.mqh:239` | every executable plan entering the gate chain |
| `S-GATE … Stage=INSPECT` | `TradeManager.mqh:420` / `:435` | inspection verdict, or explicit `NOT_REACHED` |
| `S-GATE … Stage=BEGIN` | `TradeManager.mqh:465` / `:473` | `NOT_REACHED` / `REACHED_FALSE` / `REACHED_TRUE` |
| `S-GATE … Stage=SEND` | `TradeManager.mqh:499` | `OrderSend` reached, raw retcode, deal ticket |

Funnel stages: **S1** created → **S2** executable → **S3** `entrySR` → **S4** `stopSR`
→ **S5** `structureResolved` → **S6** `Inspect()==NOT_FOUND` → **S7** `BeginExecution`
→ **S8** `OrderSend`.

`S-PLAN` reports the **actual resolver out-parameters**, never a resolver return
value — both `ResolveEntryPrice` and `ResolveStopLoss` return `true` on their
non-structural fallbacks.

## 5. Governance state

The project operates under an evidence-first forensic protocol. Current state:

| Item | Status |
|---|---|
| R2′ — `UNKNOWN` invisibility to duplicate detection | `PARTIALLY PROVEN / TRACE GAP REMAINS` (candidate, not finding) |
| Historical 44-block inspection population | Unanswerable from current instrumentation |
| Q10–Q14 | Design questions only |
| P37 | Unchanged / blocked |

Start with `docs/P53_TRACK_A_FINAL_DESIGN_CLARIFICATION_AUDIT_2026-10-02.md` and
`docs/P54_R2_PRECONDITION_STRUCTURE_RESOLVED_REACHABILITY_MEASUREMENT_PLAN_2026-10-02.md`.

## 6. Workspace-only material

MQL5 workspace artifacts (`Evidence/`, `Files/`, `Scripts/`, `Tests/CI/`) remain
on disk outside the canonical tree by design. Local agent state and `Tools/A_MIRROR/`
are excluded from version control via `.git/info/exclude`.