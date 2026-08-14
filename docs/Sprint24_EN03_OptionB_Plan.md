# Sprint 24 — EN-03 Option B Implementation Plan

**Status:** DESIGN COMPLETE — AWAITING IMPLEMENTATION AUTHORIZATION (gated protocol)
**Date:** 2026-08-13
**Reference:** `docs/Sprint24_EN03_Assessment.md` (FM-1..FM-5, §6 Option B, §7 test plan), Phase-1 population study (504-bar corpus, LEGACY ≡ COORDINATED, 0/500 rows differ), Phase-2 FM-2 adversarial study (7/7 checks PASS)
**Decision record:** Option A (remove gate) — **REJECTED** (Phase 1: OFF shifts 337/500 rows). **Option B (coordinate) — SELECTED** by reviewer. Production change — **NOT AUTHORIZED**; this document is the authorization request artifact.

---

## 1. Design decision summary

The production gate is replaced by the **exactly-validated coordinated branch** proven in Phase 1 + Phase 2 of the research fork (`Tools/EN03/EN03_ResearchSymbolContext.mqh:897-913`):

1. **Same-tick BOS coordination (FM-2):** capture the trend *before* `TrendState::Update`; if the BOS already changed the trend this tick, the gate must NOT reverse it.
2. **Event direction (FM-1):** flip direction is taken from the latest CHOCH event's own direction (`choch.bullish`, `CHOCHEvent`), never derived from gate-time trend. Note: a choch is *by construction* opposite of the detection-time trend (`CHOCHDetector.mqh:360`), so `choch.bullish` is the structurally-correct flip target.
3. **UNKNOWN defense (FM-1 dead branch):** no forced flip while `TREND_UNKNOWN` (defensive guard, replacing the inverted ternary).
4. **PP coordination (FM-4):** **no reordering** — see §4. The suppression makes the same-tick PP activation (which already ran with the BOS-driven trend) consistent with the final trend; the 1-tick PP activation lag for *legitimately flipped* trends is preserved as the LEGACY-equivalent invariant (Phase-1-proven population equivalence).
5. **BOS idempotency (FM-5):** `ForceTrend` and `TrendState::Update`/`m_lastProcessedBOSId` are untouched; `ForceTrend` becomes unreachable on any tick where the BOS moved the trend, so trend transitions can no longer decouple from the structural event stream.
6. **LEGACY equivalence where it must hold:** on the Phase-1 corpus the suppression path never fires (`coordSkip=0` in the accepted study) → behavior must be byte-identical to the frozen golden run (acceptance gate G3).

**Non-goals (explicitly out of scope):** removing the gate, reordering `Update()` stages, porting research telemetry counters (`m_flipCountGate/Coord/Skip`) to production, touching any detector file.

---

## 2. Exact production changes

### 2.1 `Portfolio/SymbolContext.mqh` — the only behavioral change

**A. New state field** (next to `m_lastCHOCHCount`, line 157):

```mql5
Trend m_trendBeforeTrendUpdate;   // EN-03 Option B: pre-TrendState::Update snapshot
```

**B. Constructor init** (line ~300): `, m_trendBeforeTrendUpdate(TREND_UNKNOWN)`

**C. Reset-aware init** — both existing reset sites, exactly as `m_lastCHOCHCount` is handled:
- `OnHistoryReset()` (line 165): `m_trendBeforeTrendUpdate = TREND_UNKNOWN;`
- reset path in `Update()` (line 720): same assignment.

**D. Same-tick BOS snapshot** — insert between the BOS update (:783) and the trend update (:790):

```mql5
//--- EN-03 Option B: capture pre-BOS-update trend to detect a same-tick
//    BOS flip (FM-2 double-flip suppression).
m_trendBeforeTrendUpdate = (m_trendState != NULL)
    ? m_trendState.GetCurrentTrend() : TREND_UNKNOWN;
```

**E. Replace the gate block (lines 814-824)** with the validated coordinated gate:

```mql5
if(m_chochDetector != NULL && m_trendState != NULL)
{
    int currentCHOCHCount = m_chochDetector.GetCHOCHCount();
    if(currentCHOCHCount > m_lastCHOCHCount)
    {
        m_lastCHOCHCount = currentCHOCHCount;
        Trend currentTrend = m_trendState.GetCurrentTrend();
        //--- EN-03 Option B (FM-1 defensive): never force-flip from UNKNOWN.
        //    Direction comes from the event (choch.bullish), not gate-time
        //    trend. Suppress when the BOS already flipped the trend this
        //    tick (FM-2), so TrendState::Update's deterministic stream is
        //    never reverted by the gate (FM-5).
        if(currentTrend != TREND_UNKNOWN)
        {
            CHOCHEvent choch;
            if(m_chochDetector.GetCHOCH(currentCHOCHCount - 1, choch))
            {
                Trend chochTrend = choch.bullish ? TREND_BULLISH : TREND_BEARISH;
                if(chochTrend != currentTrend && currentTrend == m_trendBeforeTrendUpdate)
                    m_trendState.ForceTrend(chochTrend);
                else
                    m_logger.LogInfo("EN-03 Option B: gate suppressed (same-tick BOS flip or direction already set)");
            }
        }
    }
}
```

**Semantics notes (fork-validated):**
- `m_lastCHOCHCount` is advanced **before** the decision (dedup stays tick-atomic — same order as today).
- The suppression condition `currentTrend == m_trendBeforeTrendUpdate` is exactly the validated fork (`EN03_ResearchSymbolContext.mqh:903`); the `chochTrend != currentTrend` guard additionally no-ops when the event direction already equals the current trend.
- At most one choch can be new per tick (detector dedup via `m_lastProcessedBar`, `CHOCHDetector.mqh:310`), so the gate evaluates at most one event per tick — no multi-event ambiguity.
- No strategy switch is ported to production: Option B is the only gate path (`EN03_GATE_LEGACY/OFF/COORDINATED` remain research-only in the fork).

### 2.2 `Structure/TrendState.mqh` — testability only, no behavior change

Add one accessor (private `m_trendFlipCount` exists, no getter):

```mql5
int GetTrendFlipCount(void) const { return m_trendFlipCount; }
```

Required by fixture F5 (call-site contract: BOS-only flip delta == 1 on the FM-2 tick). No changes to `Update`, `ForceTrend`, `Clear`, `OnHistoryReset`.

### 2.3 Explicit no-touch list

`BOSDetector.mqh`, `CHOCHDetector.mqh`, `ProtectedPointManager.mqh`, `OrderBlockDetector.mqh`, `FVGDetector.mqh`, `LiquidityDetector.mqh`, `SwingDetector.mqh`, `StructuralPivotEngine.mqh`, `TrendState::Update`, all `Confluence/`, all `Entry/`, all `Trading/`. Update order inside `CSymbolContext::Update` unchanged (Swing → Pivot → BOS → Trend → PP → CHOCH → **gate** → OB → FVG → Liq → Viz → Confluence).

---

## 3. State needed to detect a same-tick BOS transition

One snapshot field per context instance: `m_trendBeforeTrendUpdate`, captured between the BOS and trend stages of `Update()`. This is the minimal state proven by Phase 2 (the fork's `coordSkip=1` at W=23 was produced by exactly this comparison).

Rejected alternative: an in-class "flipped this tick" flag inside `CTrendState`. Rationale: adds API surface, requires a per-tick reset discipline, and was never validated; the snapshot is a pure `Update()`-local read of existing public state.

---

## 4. PP coordination (FM-4) — explicit ordering decision: NO reorder

The assessment's original Option B sketch suggested "gate evaluated pre-PP so the PP activation and flip land in the same tick" (`Assessment.md:110`). **This plan explicitly rejects that reordering** on evidence:

1. **Phase 2 proved consistency without reordering.** On the FM-2 tick, PP ran with the BOS-driven trend (BULLISH, LOW activated); the gate then *suppresses* instead of flipping — the final trend equals the trend PP saw. No stranded activation exists because the reversal that caused FM-4's compound (gate flip → PP activation for the reverted trend only next tick) no longer fires on the pathological path.
2. **Phase 1 proved the non-FM-2 path must stay as-is.** LEGACY ≡ COORDINATED on 504 bars with the fork's (unreordered) ordering. Moving the gate before PP would change *when* PP activation happens for every legit choch flip — a population shift that would violate G3 by construction.

Residual accepted behavior: for a *legitimate* choch-driven flip (no same-tick BOS), the PP for the new trend activates on the next update, exactly as LEGACY does today. This is the invariance the golden run pins; it is preserved deliberately, documented here as the FM-4 disposition.

---

## 5. TDD fixtures — `Tests/unit/TestTrendFlipGate.mqh` (new; register in `Tests/TestSuite.mqh`)

Fixture pattern follows `TestHistoryEpoch.mqh` (drive the **production** call site `CSymbolContext ctx("FIXTURE_EN03", 0, ENTRY_MODE_LEGACY); ctx.Init(NULL); ctx.Update(chronological arrays...)`, chronological re-orientation before every call). The FM-2 33-bar table from `Tools/EN03/EN03_FM2Scenario.mq5` is embedded as the fixture's synthetic history (identical O/H/L/C values).

| # | Fixture | RED (current production) | GREEN (after 2.1) |
|---|---|---|---|
| F1 | **FM-2 same-tick** (embedded table): at W=23 BOS#2 bullish + opposite bearish choch | trend flips back to BEARISH (double flip); `TrendFlipCount` delta 2 | trend stays BULLISH; delta 1 (BOS-only); gate suppressed |
| F2 | **Event direction**: no same-tick BOS; bearish-trend table produces bullish choch | flip goes to BULLISH via ternary coincidence only when trend ≠ UNKNOWN (UNKNOWN case: wrong — see F3) | flip == `choch.bullish` exactly |
| F3 | **UNKNOWN defense**: choch event while `TREND_UNKNOWN` | inverted ternary forces BULLISH (RED: flip occurs) | no flip; trend stays UNKNOWN |
| F4 | **Reset contract**: history reset (TIME_RESET) with a pending choch count | stale flip from uncleared `m_lastCHOCHCount`-equivalent path | no flip after reset; snapshot reset to UNKNOWN |
| F5 | **Call-site contract**: assert `ctx.GetTrendState().GetTrendFlipCount()` deltas | W=23 delta 2 | W=23 delta 1; W=30 legit flip still delta 1 (LEGACY-equivalent path fires once) |
| F6 | **W=12 guard regression**: spurious BOS scenario from run-1 defect | n/a (detector-level) | no BOS, no flip (pins the fixed table) |

F3 note: the live path cannot produce a choch under UNKNOWN (`CHOCHDetector.mqh:151-155` early-return) — the fixture asserts the *defensive gate guard* (no flip even if an event were injected) plus the detector-level invariant.

---

## 6. Acceptance gates (execution order)

- **G1 RED→GREEN:** F1-F6 fail on current production, pass after §2 changes. Full suite (2628 + new fixture count) stays green; run via existing runner (`Tests/TestRunnerEA.mq5`).
- **G2 Compile:** metaeditor64, 0 errors; no new warnings beyond the 4 pre-existing POSITION_COMMISSION deprecations.
- **G3 Population invariance (primary gate):** TT01 golden rerun — 71/71 behavior columns byte-identical, 6239/6239 integrity vs `TT01_20260813_185122`. This is the Phase-1-equivalence requirement: the corpus never hits the suppression path, so the golden must match exactly.
- **G4 Behavioral equivalence vs validated fork:** rerun the FM-2 scenario harness against the **production** gate and diff per-window CSV against `Tools/EN03/fm2_artifacts/COORDINATED/en03_fm2_coord.csv` — must be byte-identical (proves production == validated Option B behavior, incl. W=23 suppression, W=30 legit flip, W=31 no-op).
- **G5 Corpus equivalence:** rerun Phase-1 corpus with the production gate; LEGACY-arm-equivalent rows must be identical (0/500 differing is expected by construction; any delta = failure).
- **G6 Closure:** `docs/Sprint24_EN03_Closure.md` following EN-01/EN-02 convention (evidence → decision → implementation → regression → closure), referencing this plan's G1-G5 results. **Commit only on explicit authorization.**

---

## 7. Risk register

| Risk | Mitigation |
|---|---|
| Suppression path mis-triggers on a live legit flip | Suppression requires `currentTrend == m_trendBeforeTrendUpdate` *and* `chochTrend != currentTrend`; identical logic proven on corpus + adversarial scenario |
| Population shift from the change | G3 golden gate is hard-fail; Phase-1 study shows suppression never fires on corpus |
| PP 1-tick lag semantics misunderstood | §4 disposition recorded; invariant preserved and pinned by G3/G5 |
| Gate diverges from validated fork | G4 byte-diff against the frozen COORDINATED trace |
| ForceTrend determinism regression | FM-5: `TrendState` untouched; F5 call-site delta contract |

---

## 8. Authorization request

This plan is complete and self-contained. **No implementation has been performed; no production file has been modified; no commit exists.** Implementation (TDD RED → §2 diff → G1-G6) starts only upon explicit authorization.
