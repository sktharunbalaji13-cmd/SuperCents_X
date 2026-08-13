# Sprint 24 — EN-02 Closure: Visualization Reset-Awareness (DEFECT CLOSED)

Status: **CLOSED** (2026-08-13)
Defect: EN-02 Visualization reset-awareness (#2) — Sprint 24 engineering-audit Phase 4 backlog, class B, disposition FIX NOW (conditional)
Origin: `docs/Sprint24_EngineeringAudit.md` §5 (EN-02: Visualization reset-awareness)
Scope owner: engineering correctness (visualization reset-path contract)

---

## 1. Defect summary

`CVisualizationManager` was not an `IHistoryResetConsumer` and was never registered
with the `CHistoryEpoch` broadcast, so on a canonical history reset (reload / history
revision / SHRINK) the renderers kept their incremental draw cursors
(`m_lastRendered*Count`, `m_visualStateCount`) and their chart objects. After the
detectors cleared and rebuilt the (smaller) history population, every renderer's
`count > m_lastRendered*Count` gate stayed false — the rebuilt history was **never
re-rendered** and stale chart objects with stale geometry persisted. The
`CVisualStateEngine` record table was not reset either, so stale records could win
`FindRecord()` in `HandleExtend`/`HandleFreeze`/`HandleDelete` and silently kill the
active-line extension of the rebuilt stream.

## 2. Root cause — CONFIRMED (three arms, audit §2.3 #2)

| # | Gap | Location |
|---|---|---|
| 1 | Manager not a reset consumer (no `IHistoryResetConsumer`, no `OnHistoryReset`) | `Visualization/VisualizationManager.mqh` class decl |
| 2 | Manager never registered with the epoch — created **after** the registration block, which covers all 9 detectors + the context | `Portfolio/SymbolContext.mqh:431-440` vs `:442+` |
| 3 | Stale-state mechanism: incremental draw cursors + stale VSE records | all 8 renderers (e.g. `BOSRenderer.mqh:84` `count > m_lastRenderedBOSCount`); `VisualStateEngine.mqh` `FindRecord()` |

## 3. Remediation — ACCEPTED (three arms)

| Arm | Change | File |
|---|---|---|
| Production | `CVisualizationManager : public IHistoryResetConsumer`; `OnHistoryReset()` = `Clear()` on all renderers (deletes chart objects by prefix + zeroes draw cursors) + `m_vse.Reset()` + reset counter | `Visualization/VisualizationManager.mqh` |
| Production | Manager registered with the epoch in `CSymbolContext::Init()` (right after its construction block); accessor `GetVisualizationManager()` added | `Portfolio/SymbolContext.mqh` |
| Production | `CVisualStateEngine::Reset()` (drop records without shutdown) added; `CBOSRenderer::GetRenderedCount()` test surface added | `Visualization/VisualStateEngine.mqh`, `Visualization/BOSRenderer.mqh` |
| Test hardening | Call-site contract fixture (`TestEN02_CallSiteResetReachesVisualization`, +6) and new `TestVisualizationReset.mqh` (+21: manager registration semantics against the real manager, and renderer-reset fixture over the pinned REC 24-bar chain reusing `TestReconstruction.mqh`) | `Tests/unit/TestHistoryEpoch.mqh`, `Tests/unit/TestVisualizationReset.mqh`, `Tests/TestSuite.mqh` |

The fixtures are RED on pre-fix semantics by construction (the pre-fix manager has no
reset counter and no registration — the broadcast could never reach it; the audit §2.3
row already records the defect as **Confirmed** with the stale-state call sites).

## 4. Validation evidence

| Gate | Result | Evidence |
|---|---|---|
| EN-02 runtime, run 1 | GREEN | `GRAND TOTAL: 2628/2628 passed, 0 failed` (18:37:11) |
| EN-02 runtime, run 2 | GREEN | `GRAND TOTAL: 2628/2628 passed, 0 failed` (18:50:49) |
| History Epoch suite | 50/50 both runs | 44 pre-existing + 6 EN-02 call-site contract |
| Visualization Reset suite | 21/21 both runs | manager registration semantics + renderer reset fixture |

Full TT01 regression `TT01_20260813_185122` (git `459bdb3`, no `-AllowDelta`, no
`-Skip`, `-ExpectedRows 500`), exit code 0:

| Gate | Result |
|---|---|
| COMPILE (6 targets) | PASS — 0 errors each |
| SUITE | PASS — 2628/2628 |
| REPLAY | PASS — 500/500 rows, 0 faults, HEALTHY |
| TELEMETRY-CONTRACT | PASS — header 78/78, schema v5, gate OFF sentinels |
| EVIDENCE-REGRESSION | PASS — split invariant 500/500 |
| BEHAVIOR-REGRESSION | PASS — all 71 behavior columns byte-identical to frozen baseline |
| ACTIVE-TIER | PASS — nGatedOut=227, 273 admitted, fingerprint constant |
| SETTLEMENT-ISOLATION | PASS — 3327 admitted rows byte-identical (Design A, 58→0) |
| INTEGRITY-CONTROL | PASS — 6239/6239 rows identical to frozen CONTROL |
| PERFORMANCE | PASS — replay 16.1 s, suite 9.1 s, peak 765 MB |

Artifacts (authoritative evidence, retained): `Tools/TT01/artifacts/TT01_20260813_185122/`
(manifest.json + CSVs + isolation arm dirs).

## 5. Final disposition

- EN-02: **GREEN ×2**
- Full TT01: **GREEN** — zero functional regressions; 71/71 behavior columns and
  6239/6239 integrity rows byte-identical ⇒ the reset-path wiring is **dormant on the
  default replay path** (no reset events fire there), satisfying the conditional
  FIX NOW gate (`TT01 default-path byte-identity`)
- Attribution: clean — the only source delta is the reset-awareness wiring +
  `CVisualStateEngine::Reset()` + fixture hardening (6 files modified, 1 new)
- Commit: **NOT YET MADE** — freeze point recorded, commit pending explicit
  authorization

## 6. Guardrails held

- No source changes during the TT01 validation run
- No auto-fix of failures; no test modification to satisfy validators
- No production behavior change on the default replay path (reset path only); no
  telemetry/decision impact (audit §4.1: EN-02 research-boundary impact = NONE)
- Defect closure is a separate decision from the next architectural/research phase —
  no automatic progression; EN-03+ backlog items remain untouched

---

*Sprint 24 EN-02 closure record, 2026-08-13. Companion evidence:
`docs/Sprint24_EngineeringAudit.md` (EN-02 row), `Tools/TT01/artifacts/TT01_20260813_185122/`.*
