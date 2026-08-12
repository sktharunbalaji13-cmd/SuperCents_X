# Sprint 24 — Engineering Gap Audit & Architecture Reconciliation

Status: **DRAFT FOR REVIEW — NOT CLOSED, NOT COMMITTED** (2026-08-12)
Type: **Engineering audit / reconciliation — NOT research evidence**
Scope owner: engineering-health track (RL01 research track is closed at Sprint 23)
Predecessor: Sprint 23 closure (`docs/Sprint23_Closure.md`, commit `14dd64a`) —
**NO SPRINT 23 EXPERIMENT IS JUSTIFIED**; research chain at a terminal boundary.
Audit source: `docs/Sprint22_AuditInput_DetectionVisualization.md` (engineering findings).

---

## 1. Mandate and boundary

Sprint 24 is an **audit / reconciliation sprint, not an implementation sprint**. Its
objective is to determine which existing engineering issues can be safely addressed
**without** accidentally reopening the frozen research/evidence chain (B8, ED01-A→E,
Sprint 21 literature conclusions, Sprint 22 protocol/results, telemetry contracts, future
experiment populations).

Guardrail 1 holds throughout: **no production modification, no B8 change, no frozen
protocol change, no telemetry-schema change, no research result/artifact change.** No
TT01, no Strategy Tester, no statistics, no experiment. No Sprint 25 work begins.

The audit records findings and dispositions only. Where a disposition says **FIX NOW**, it
means *approved for a future execution sprint* — never implementation during Sprint 24.

### 1.1 Evidence separation (kept deliberately distinct)

| Layer | Authoritative artifacts | Used for |
|-------|------------------------|----------|
| **Research evidence** | ED01-A…E decisions, Sprint 21 ledger/synthesis/shortlist, Sprint 22 protocol + decision, Sprint 23 closure | Experiment decisions, promotion gate |
| **Engineering findings** | `docs/Sprint22_AuditInput_DetectionVisualization.md`, this audit | Dedicated future engineering sprint (Sprint 25+) |

The audit's code-level conclusions **do not** constitute a new experimental result and do
not override or reinterpret any ED01 / Sprint 21 / Sprint 22 / Sprint 23 conclusion.

---

## 2. Phase 1 — Reconcile: Sprint 17–23 roadmap vs actual repository

### 2.1 Roadmap state (as of HEAD `14dd64a`)

| Sprint | Track | Actual repo state |
|---|---|---|
| 17 | Schema v3 evidence baseline | CLOSED (`Sprint17_Closeout.md`, tag `v3.0-research-baseline`) |
| 18 | Optimization / research | CLOSED (research artifacts in `Sprint18_Research/`) |
| 19 | Production hardening | CLOSED (`Sprint19_ProductionHardening.md`) |
| 20 | Platform engineering | ED01-A→E **DONE** (2.0R benchmark retained); TC/TT/DD/LC/GR/VF closed; **RH01 deferred** |
| 21 | Literature review (RL01) | CLOSED (ledger, synthesis, shortlist) |
| 22 | RL-HYP-01 experiment | CLOSED — **REJECT / NOT SUPPORTED** (commit `9bc8eab`) |
| 23 | Research-venue gate | CLOSED — **NO EXPERIMENT JUSTIFIED** (commit `14dd64a`) |

### 2.2 Dormant plan-register meanings (preserved — do NOT reuse the IDs)

| ID | Recorded meaning (Sprint 20 plan register) | State |
|---|---|---|
| ED02 | R17 h22–23 BULL exclusion experiment (doc 06 E4) | Dormant — research experiment, not started |
| ED03 | R03 session-gate experiment (M06) | Dormant — research experiment, not started |
| ED04 | R16 direction×cell month-split (doc 06 E5) | Dormant — research experiment, not started |
| ED05 | C12/C18 displacement gates (paper-first) | Dormant — research experiment, not started |
| ED06 | R14 rule decomposition (OB_FVG vs BOS_OB) | Dormant — research experiment, not started |
| RH01 | Repository hygiene / working-tree cleanup | Deferred by design (research commits stay isolated) |

**Decision:** the `ED02–06` IDs are research-experiment rows and are **preserved as-is**.
Sprint 24 introduces **`EN-01…EN-07`** as new engineering-backlog IDs (Phase 4) where the
audit justifies them. No ID is overloaded with a new meaning.

### 2.3 Sprint 22 engineering-audit findings (source, confirmed)

Source `docs/Sprint22_AuditInput_DetectionVisualization.md` (recorded 2026-08-11,
classified **engineering findings — NOT research evidence**). It is still untracked and is
committed as a dedicated record by this sprint.

**Confirmed behavioral bugs (§3.1):**

| # | Finding | Severity | Reference |
|---|---|---|---|
| 1 | HistoryEpoch orientation — `Update(rates_total, time[0])` before `ArraySetAsSeries` → time-reversal/LC5 path dead; all 9 epoch consumers keep stale state on reload/history revision | CRITICAL | `Portfolio/SymbolContext.mqh:729` |
| 2 | Visualization not history-reset aware — `CVisualizationManager` not an `IHistoryResetConsumer`; renderers keep stale counts/objects after reset | HIGH | `SymbolContext.mqh:733-740, 823` |
| 3 | Legacy trend-flip gate — every CHOCH unconditionally `ForceTrend()`s opposite; `TREND_UNKNOWN→TREND_BEARISH` bug; double-flip hazard; OB 1-bar lag | MEDIUM | `SymbolContext.mqh:789-795` |
| 4 | Magic number per-init — `(int)TimeCurrent()` regenerates each `OnInit` → orphaned positions, unmanaged SL/TP, dedup bypass; `(int)` breaks >2038 | MEDIUM | `Core/Config.mqh:61` |
| 5 | BOSRenderer lifecycle cascade — freeze runs once per batch, not per event; anchor `iTime(...,0)` (now) not break time | LOW/MED | `Visualization/BOSRenderer.mqh:120-176` |
| 6 | TradeManager fill reporting — `filledPrice=request.price` not `tradeResult.price`; no `tradeResult.deal` capture | LOW | `Trading/TradeManager.mqh` |
| 7 | Performance & logging — O(history) OHLC copy new bar (O(N²) backtest), `PERF Print` per bar from 3 modules, pivot timing mislabeled | LOW | `Core/Engine.mqh`, `SymbolContext.mqh:~830` |

**Dead / never-driven code (§3.2):** `CEntryEngine` (constructed `SymbolContext.mqh:522`,
never updated/evaluated); `CExecutionManager::Update()` empty + never called (real
execution = `CTradeManager`); `CRiskManager::Update()` / `CPositionManager::Update()` no
runtime-loop calls; `CScheduler::Update()` empty; `SuperCents_X.mq5` `OnChartEvent` /
`OnTimer` empty.

**Verified correct (§3.3) — do NOT fix:** OHLC orientation split (deliberate); FVG gap
math / EQH·EQL clustering / OB search bounds / CHOCH·PP level checks / VSE draw-extend-
freeze-finalize-delete; Scheduler + Engine new-bar double-gating; entry-mode execution
contract (LEGACY executes; SHADOW/NEW reserved).

### 2.4 Confirmed vs unverified (Phase 1 reconciliation)

| Finding | Status | Basis |
|---|---|---|
| HistoryEpoch orientation (#1) | **Confirmed** | audit §3.1, `SymbolContext.mqh:729` |
| Visualization reset-awareness (#2) | **Confirmed** | audit §3.1; audit **retracts** the older "dead VisualizationManager" note — it IS wired (`:823`) |
| Trend-flip gate (#3) | **Confirmed** | audit §3.1, `SymbolContext.mqh:789-795` |
| Magic number per-init (#4) | **Confirmed** | audit §3.1, `Config.mqh:61` |
| BOSRenderer cascade (#5) | **Confirmed** | audit §3.1, `BOSRenderer.mqh:120-176` |
| Fill reporting (#6) | **Confirmed** | audit §3.1, `Trading/TradeManager.mqh` |
| Perf/logging (#7) | **Confirmed** | audit §3.1, `Core/Engine.mqh` |
| `OnTradeTransaction` absent | **Confirmed** | source-wide search — no `OnTradeTransaction`/`OnTrade()` implementation (only `docs/ValidationLab.md` future mention) |
| 0.01 fixed lot (legacy live path) | **Confirmed (documented)** | `docs/Sprint13.6_TradeManager.md`, `ARCHITECTURE_v0.8.0.md:131` (legacy `RiskManager` default) |
| `ENTRY_MODE_LEGACY` executing default | **Confirmed** | `EntryConfig.mqh` mode matrix (LEGACY executes; SHADOW/NEW reserved) |
| Unbounded OHLC copy / excessive logging | **Confirmed** | audit #7 |
| BE/trailing "not actually wired" | **UNVERIFIED — Phase 1 target** | `CPositionLifecycleManager` exists + documented pipeline (`performance_baseline.md:83`); audit §3.2 does not cover it; call sites of its `Update()` must be traced |

---

## 3. Phase 2 — Risk classification

### 3.1 Classification scheme

| Class | Meaning | Treatment |
|---|---|---|
| **A** | Safe engineering defect; behavior-preserving (output byte-identical) | Candidate for a future engineering sprint, subject to TDD + TT01 |
| **B** | Behavior-affecting on some path | Requires regression evidence (TT01, reconstruction) before any fix; may need its own narrowly scoped engineering protocol |
| **C** | Trading-strategy change | Requires a separate research protocol — out of engineering scope |
| **D** | Dead / unreachable code | Quarantine (document, leave in place); do not delete yet |

The provisional mapping from the audit input is the starting point; this section finalizes
it. Classification is per-item and reconsidered item-by-item in the future execution
sprint — no blanket "Class-A/B implementation" is assumed.

### 3.2 Finalized classification

| Item | Class | Rationale |
|---|---|---|
| #1 HistoryEpoch orientation | **B** | Fix activates the reset broadcast on a currently-dead path; behavior changes on reload/history-revision → regression evidence required (normal replay is unaffected, but TT01 must stay byte-identical on the default path) |
| #2 Visualization reset-awareness | **B** | Visual-only, but adds reset-driven deletion/render behavior on the reset path → regression evidence required |
| #3 Trend-flip gate | **B (borderline C)** | Correctness fix, but it changes which CHOCH→trend flips fire → detection/decision signals change → must be verified not to shift any experimental population; if it does, it moves to C and needs a research protocol |
| #4 Magic-number stability | **B** | Production-safety fix; changes position-matching identity on reload. Backtest per-run isolation must be preserved separately |
| #5 BOSRenderer freeze | **A** | Visual state only; no trading/telemetry effect; behavior-preserving |
| #6 TradeManager fill reporting | **A** | Telemetry reporting correction (actual fill price + deal id); no trading behavior change. Must verify no ED01 dependence (ED01 uses simulated fixed-RR outcomes → expected nil, to be confirmed) |
| #7 Performance & logging | **A** | Bounded copy window + metric-driven logging; must remain byte-identical on the default replay path (TT01) |
| Dead code (`CEntryEngine`, `CExecutionManager::Update`, `CRiskManager::Update`, `CPositionManager::Update`, `CScheduler::Update`, empty `OnChartEvent`/`OnTimer`) | **D** | Quarantine — document, do not delete immediately (includes/compile risk, and the execution architecture may be consolidated later) |
| `ENTRY_MODE_NEW` activation / provider promotion | **C** | Trading-strategy change; requires its own research protocol + promotion gate (Sprint 21 protocol discipline) |
| BE/trailing wiring (if confirmed dead) | **C** | Changes position management behavior → trading-strategy change; requires research protocol. **Phase 1 target: verify first** |
| 0.01 fixed lot / risk sizing integration | **C** | Trading-strategy change (money management); requires research protocol |
| `OnTradeTransaction` addition | **B/C** | Needed only if a live position-recovery requirement is adopted; otherwise DEFER. Classification depends on whether it changes behavior (B) or policy (C) |

---

## 4. Phase 3 — Protect the research boundary

The audit must explicitly identify anything that could affect **B8, ED01-A→E, Sprint 21
literature conclusions, Sprint 22 protocol/results, telemetry contracts, or future
experiment populations**. In particular, **no "cleanup" may accidentally become a strategy
modification.**

### 4.1 Boundary-impact register

| Item | Research-boundary impact | Mitigation if ever touched |
|---|---|---|
| #7 perf/logging (`Core/Engine.mqh CopyOHLCArrays`) | **HIGH** — any change to the OHLC copy path can change telemetry rows → B8 / ED01 invalidation | Must be byte-identical on the default replay path (TT01 BEHAVIOR-REGRESSION); no output change |
| #3 trend-flip gate | **HIGH** — changes detection → can shift which signals fire → could move experimental populations | Verify population invariance before any fix; if it shifts, reclassify C and require a research protocol |
| #6 fill reporting | **LOW–MED** — changes telemetry columns (fill price / deal id) | ED01 uses simulated fixed-RR outcomes (no actual-fill dependence) → expected nil impact; confirm no telemetry-contract consumer depends on the current (wrong) value |
| #1 HistoryEpoch orientation | **LOW** — operates only on the reset path (dormant in normal replay) | Fix must not alter the default replay output; TT01 must remain green |
| #2 visualization reset-awareness | **NONE on research** — visual-only; does not touch telemetry/decisions | No research impact; still TT01-validated for code hygiene |
| #4 magic-number stability | **LOW** — backtest per-run magic is deliberate isolation | Keep per-run isolation in backtest context; apply stable derivation only where it is safe (production) |
| #5 BOSRenderer freeze | **NONE** — visual state only | No research impact |
| Dead code (D) | **NONE** — unreachable; no runtime effect | Quarantine only; do not delete (avoid include/compile churn) |
| `ENTRY_MODE_NEW` activation / BE-trailing / lot sizing / `OnTradeTransaction` | **FULL** — trading-strategy changes | Out of engineering scope; each requires its own research protocol + promotion gate |

### 4.2 Standing rule

- **No cleanup under any class becomes a strategy modification.** Any fix that changes
  what signals fire, how positions are managed, or how money is sized is Class C and is
  routed to a research protocol — never to an engineering sprint.
- Every Class-A/B fix, before it may be implemented in a future sprint, must pass the
  frozen TT01 gate (byte-identical on the default replay path) and, for B-items, its own
  narrowly scoped regression protocol.
- The frozen telemetry schema (v5) and the B8 baseline are **immutable**; no engineering
  item may change column semantics or the config fingerprint.

---

## 5. Phase 4 — Prioritized engineering backlog (EN-01…EN-07)

Every finding gets **exactly one disposition**: **FIX NOW / RESEARCH FIRST / DEFER /
REJECT**. Here **FIX NOW = approved for a future execution sprint**, never implementation
in Sprint 24.

| ID | Item | Class | Disposition | Notes for the future execution sprint |
|---|---|---|---|---|
| EN-01 | HistoryEpoch orientation (#1) | B | **FIX NOW** (conditional) | Highest priority correctness item. Requires its own narrowly scoped regression protocol (reset-path fixtures) + TT01 default-path byte-identity before/after |
| EN-02 | Visualization reset-awareness (#2) | B | **FIX NOW** (conditional) | Wire `IHistoryResetConsumer`; renderer reset fixtures; TT01 default-path byte-identity |
| EN-03 | Trend-flip gate (#3) | B→C | **RESEARCH FIRST** | Verify population invariance first. If the fix shifts any ED01/Sprint-22 population → reclassify C and route to a research protocol, not engineering |
| EN-04 | Magic-number stability (#4) | B | **DEFER** | Production-safety; not relevant to any backtest/replay path. Requires a production (live) requirement decision first |
| EN-05 | BOSRenderer freeze (#5) | A | **FIX NOW** | Visual-only correctness; low risk; TDD + TT01 |
| EN-06 | TradeManager fill reporting (#6) | A | **FIX NOW** | Telemetry correction; verify no telemetry-contract consumer depends on the current value |
| EN-07 | Performance & logging (#7) | A | **DEFER** | O(N²) is acceptable at current dataset scale; fix is optional and must stay byte-identical (TT01). Lower priority than correctness items |
| EN-08 (quarantine) | Dead code (§3.2 list) | D | **DEFER (quarantine)** | Document, leave in place. Deletion only as part of a future execution-architecture consolidation, never standalone |
| — | `ENTRY_MODE_NEW` activation / provider promotion | C | **RESEARCH FIRST** | Requires its own research protocol + promotion gate (Sprint 21 discipline) |
| — | BE/trailing wiring (if confirmed dead) | C | **RESEARCH FIRST** | **Phase 1 target first** — trace `CPositionLifecycleManager::Update()` call sites to confirm. If dead, requires a research protocol, not engineering |
| — | 0.01 fixed lot / risk sizing integration | C | **RESEARCH FIRST** | Money-management change; requires a research protocol |
| — | `OnTradeTransaction` addition | B/C | **DEFER** | Only if a live position-recovery requirement is adopted |

**Execution-order principle for the future sprint:** correctness first (EN-01, EN-02,
EN-03-pending), then telemetry/visual corrections (EN-05, EN-06), then optimization
(EN-07). Class-B items each carry their own regression protocol; there is **no** blanket
"Class-A/B implementation" label.

---

## 6. Phase 5 — Deliverables and governance

### 6.1 Sprint 24 deliverables

1. **This audit document** — `docs/Sprint24_EngineeringAudit.md` (Phases 1–5).
2. **Dedicated record commit** for the pre-existing untracked
   `docs/Sprint22_AuditInput_DetectionVisualization.md` — committed as an engineering
   finding record, explicitly **not research evidence** (its own header keeps that
   classification).
3. **Sprint 24 plan-register row** — added only at closure (after human review), recording
   "Sprint 24 — ENGINEERING AUDIT COMPLETE — no implementation authorized."

### 6.2 What Sprint 24 does NOT do

- ❌ No production code modification, no B8 change, no frozen protocol change, no
  telemetry-schema change, no research result/artifact change.
- ❌ No TT01, no Strategy Tester, no statistics, no experiment.
- ❌ No `ED02–06` ID reuse; no overloading of existing plan-register meanings.
- ❌ No Sprint 25 work begins (not even planning of a named execution sprint).
- ❌ No deletion of "dead" architecture now (quarantine only).

### 6.3 Classification of the Sprint 22 audit source

`docs/Sprint22_AuditInput_DetectionVisualization.md` remains an **engineering finding
record — NOT research evidence**. This distinction survives into Sprint 24 and into any
future engineering sprint; it never enters the ED01 / Sprint 21 / Sprint 22 / Sprint 23
evidence chain.

---

*Sprint 24 engineering-gap audit, DRAFT 2026-08-12. Read-only; nothing implemented.
Stop for human review. On approval: dedicated commit for the Sprint 22 audit source and a
Sprint 24 plan-register row at closure.*