# Sprint 24 — EN-03 Assessment: Legacy Trend-Flip Gate

**Status:** ASSESSMENT COMPLETE — AWAITING AUTHORIZATION (gated protocol)
**Date:** 2026-08-13
**Reference:** `Sprint24_EngineeringAudit.md` #3 (MEDIUM), `Sprint22_AuditInput_DetectionVisualization.md` §3.1.4
**Classification:** B→C per register (`Sprint24_EngineeringAudit.md:194`) — **RESEARCH FIRST: population invariance required before any engineering fix**

---

## 1. Defect contract (confirmed in code)

**Audit claim:** "Legacy trend-flip gate — every CHOCH unconditionally `ForceTrend()`s opposite; `TREND_UNKNOWN→TREND_BEARISH` bug; double-flip hazard; OB 1-bar lag — `SymbolContext.mqh:789-795`"

**Current code** (`Portfolio/SymbolContext.mqh:814-824`, shifted from the audit's stale line ref; behavior unchanged):

```mql5
if(m_chochDetector != NULL && m_trendState != NULL)
{
    int currentCHOCHCount = m_chochDetector.GetCHOCHCount();
    if(currentCHOCHCount > m_lastCHOCHCount)
    {
        m_lastCHOCHCount = currentCHOCHCount;
        Trend currentTrend = m_trendState.GetCurrentTrend();
        Trend newTrend = (currentTrend == TREND_BULLISH) ? TREND_BEARISH : TREND_BULLISH;
        m_trendState.ForceTrend(newTrend);
    }
}
```

`ForceTrend` has exactly **one call site**: the gate (`SymbolContext.mqh:822`). The gate is the only path that mutates trend state outside the BOS-driven `CTrendState::Update`.

---

## 2. Failure modes — confirmed, with audit corrections

### FM-1: Unconditional opposite flip; direction not taken from the event — CONFIRMED (audit correction on direction claim)

The flip direction is derived from the **gate-time current trend**, not from the CHOCH event's own direction (`choch.bullish`, `Types.mqh:62`). The CHOCH detector sets `bullishCHOCH = (currentTrend == TREND_BEARISH)` at detection (`CHOCHDetector.mqh:360`) — i.e., a choch is *by construction* opposite of the trend at detection. Deriving the flip from the *gate-time* trend is equivalent **only if** the trend did not change between detection (`:808-809`) and the gate (`:814-824`).

**AUDIT CORRECTION 1 — `TREND_UNKNOWN` branch is inverted AND dead:**
- Ternary: `(currentTrend == TREND_BULLISH) ? TREND_BEARISH : TREND_BULLISH`. For `TREND_UNKNOWN` (0) the condition is false → `newTrend = TREND_BULLISH`, i.e. **UNKNOWN→BULLISH**, not `→BEARISH` as the audit claims.
- Reachability: `CHOCHDetector::Update` early-returns on `TREND_UNKNOWN` (`CHOCHDetector.mqh:151-155`), so the choch count cannot increase while UNKNOWN. The unknown branch is **dead code in the live path** (only reachable if a producer injected events during UNKNOWN, which the detector prevents).
- Practical impact: low; the ternary should still be rewritten defensively (no flip on UNKNOWN). The audit's direction claim is inverted vs. the code; disposition documented here.

### FM-2: Double-flip hazard — CONFIRMED (same-tick BOS↔gate reversal)

Same-tick ordering in `SymbolContext::Update`:
`TrendState.Update(BOS-driven)` `:790` → `ProtectedPointManager.Update` `:796-801` → `CHOCHDetector.Update` `:808-809` → **gate flip** `:814-824` → `OrderBlockDetector.Update` `:826-829` → `FVGDetector.Update` `:834-836`.

The gate does **not** check whether the BOS already flipped the trend this tick. Concrete mechanism:
1. Tick N: bullish BOS fires → `TrendState.Update` flips **BULLISH** (`TrendState.mqh:127-132`).
2. PP manager activates the protected **LOW** for the new bullish trend, same tick (`ProtectedPointManager.mqh:127`).
3. CHOCH runs with trend=BULLISH; a volatile bar closing **below** the just-activated low emits a **bearish** choch (`choch.bullish=false`).
4. Gate: current=BULLISH → `ForceTrend(BEARISH)` — **reverting the BOS flip made one statement earlier.**

Consequences: the trend can oscillate BULLISH↔BEARISH across consecutive choch events; `m_trendFlipCount` is incremented by both paths (`TrendState.mqh:130/147/165`) with no coordination; `ForceTrend` bypasses the `m_lastProcessedBOSId` idempotency counter, so trend transitions decouple from the structural event stream that justified them.

### FM-3: OB 1-bar lag — AUDIT-STALE ORDERING, re-verified residual

The audit claims "flip lands after `OrderBlockDetector.Update`". In the **current** code the gate (`:814-824`) runs **before** `OrderBlockDetector.Update` (`:826-829`), so the OB detector sees the post-flip trend the same tick. The audit's ordering observation is stale.

Residual (re-verified) mechanism: a new OB takes its direction from `choch.bullish` (`OrderBlockDetector.mqh:157,168`) and its lifecycle invalidation from the post-gate trend (`:222-232`). When FM-2 causes the gate to flip for a choch that does **not** represent a structural flip, OBs of the opposing direction are invalidated 1 bar after the BOS flip that should have justified it — i.e., the "1-bar lag" survives as a *symptom of FM-2*, not as a literal ordering inversion.

### FM-4: Gate flip lags PP activation — CONFIRMED

`ProtectedPointManager.Update` runs **before** the gate (`:796-801` vs `:814-824`). When the gate flips the trend, the PP activation for the *new* trend only happens on the **next** tick; the same-tick choch was evaluated against the *old* protected point. Compounds FM-2.

### FM-5: Force-flip bypasses BOS determinism — CONFIRMED

`TrendState::Update` consumes BOS events idempotently via `m_lastProcessedBOSId` (replay determinism). The gate mutates `m_currentTrend`/`m_trendFlipCount` outside that mechanism — replaying identical history no longer guarantees an identical flip history. Directly conflicts with the documented binary-trend machine contract (`Sprint18_Research/01_Swing_Detection.md:433`, `Sprint19_Research/02_CHOCH_MSS_Deep_Research.md:649`: "trend flips on opposite BOS").

---

## 3. Impact surface (confirmed — 12+ consumers of the mutated trend)

| Layer | Consumer | Effect of a spurious flip |
|---|---|---|
| Structure | `ProtectedPointManager.mqh:127` | wrong PP activation (FM-4) |
| Structure | `CHOCHDetector.mqh:150` | next detection evaluated in wrong branch |
| Structure | `OrderBlockDetector.mqh:196` | wrong-way OB invalidation (FM-3) |
| Structure | `FVGDetector.mqh:367,379` | FVG trend classification / expiry |
| Confluence | `ConfluenceEngine.mqh:509-513` | `EXPIRY_TREND_REVERSAL` kills live signals |
| Confluence | `ConfluenceRules.mqh:24`, `ScoreCalculator.mqh:137` | score computation |
| Confluence | `FVGEvaluator:104`, `OrderBlockEvaluator:112`, `TrendEvaluator:21`, `PremiumDiscountEvaluator:30` | per-evaluator gating |
| Entry | `EntryDecisionEngine.mqh:158` | entry gating |

→ Every spurious/oscillating flip can alter which signals fire. This is precisely the **population-shift risk** the register flags as HIGH (`Sprint24_EngineeringAudit.md:162`) and the reason EN-03 is B→C with **RESEARCH FIRST** (`:194`).

---

## 4. Verification surface

- **No direct unit test exists for the gate.** `ForceTrend`'s single call site (`SymbolContext.mqh:822`) is exercised only indirectly via `ctx.Update` in `TestHistoryEpoch.mqh` (`:259,283,307,358,369,390`).
- **Reset-aware:** `m_lastCHOCHCount` reset in `SymbolContext::OnHistoryReset` (`:165`); `TrendState::OnHistoryReset → Clear` (`TrendState.mqh:47`). No reset defect here.
- **Population-invariance instruments already frozen:** TT01 golden run `TT01_20260813_185122` (6239/6239 integrity; 71/71 behavior columns byte-identical) + full unit suite (2628/2628 ×2).

---

## 5. Classification decision

Any fix that changes **which** flips fire changes detection → ED01/Sprint-22 population risk is **real and HIGH**. Per the register, EN-03 is reclassified **C (research protocol required)** unless a candidate fix is proven population-invariant against the TT01 golden run.

---

## 6. Fix design options (NOT authorized — assessment only)

| Option | Description | Population-shift probability |
|---|---|---|
| **A** | Remove the gate entirely; trend = BOS-driven only (matches the documented contract in §2 FM-5 references; the gate duplicates `TrendState::Update`'s job and predates it) | High |
| **B** | Coordinate: no-op if `TrendState::Update` flipped this tick; direction taken from `choch.bullish`, not gate-time trend; no flip on `TREND_UNKNOWN`; gate evaluated pre-PP so the PP activation and flip land in the same tick | Medium-High |
| **C (recommended)** | No production change; research protocol: A/B study of gate-on vs. gate-off vs. baseline on the frozen corpus (ED01-style harness), report population deltas, then route outcome through research | n/a (research) |

---

## 7. Test plan (executed only if a fix is authorized)

1. **Baseline freeze (already held):** current suite 2628/2628 ×2 + TT01 golden `TT01_20260813_185122`.
2. **New fixture `Tests/unit/TestTrendFlipGate.mqh` (TDD RED first):**
   - Same-tick BOS-flip + opposite choch → assert single flip per tick (FM-2).
   - CHOCH count reset via history reset → no stale flip (reset contract).
   - No flip while `TREND_UNKNOWN` (FM-1 defensive branch).
   - Direction must equal `choch.bullish` (not gate-time trend).
   - Call-site contract: `ForceTrend` call count == 1.
3. **Suite + TT01 rerun:** behavior columns must be **byte-identical** (71/71) and integrity 6239/6239 vs. golden.
4. **Invariance verdict:** identical → engineering path; shifted → C-class research protocol, no merge.

---

## 8. Acceptance criteria

- **A1:** New gate fixtures pass (TDD RED→GREEN) and full suite stays 2628+ green.
- **A2:** Population invariance — TT01 behavior columns byte-identical, 6239/6239 integrity vs. golden `TT01_20260813_185122`.
- **A3:** FM-2 same-tick double-flip eliminated (fixture-proven).
- **A4:** FM-1 ternary rewritten defensively (no flip on UNKNOWN); audit direction discrepancy documented (done, §2 FM-1).
- **A5:** Closure doc `docs/Sprint24_EN03_Closure.md` following EN-01/EN-02 convention; commit only on explicit authorization.

---

## 9. Open questions — authorization required to proceed

- **Q1:** Authorize the Phase-1 population-invariance study (no production change; A/B harness design + measurement against TT01 golden)?
- **Q2:** If a fix is pursued and proves invariant: **Option A** (remove gate) or **Option B** (coordinate)? (C recommended by the register unless research shows otherwise.)
- **Q3:** Accept the two audit corrections (FM-1 ternary direction inverted + dead-code; FM-3 ordering stale) as documented disposition for the register?
