# Sprint 24 — EN-03 Closure Evidence: Coordinated Trend-Flip Gate (Option B)

Status: **IMPLEMENTATION COMPLETE — G1-G5 GATES PASS; CLOSURE/COMMIT PENDING EXPLICIT AUTHORIZATION** (2026-08-14)
Defect: EN-03 Legacy trend-flip gate — every CHOCH unconditionally `ForceTrend()`s opposite;
`TREND_UNKNOWN→TREND_BEARISH` bug; double-flip hazard (`SymbolContext.mqh:789-795` at audit time)
Origin: `docs/Sprint24_EngineeringAudit.md` §5 (EN-03), `docs/Sprint24_EN03_Assessment.md` (FM-1..FM-5, Phase 1 + Phase 2)
Plan: `docs/Sprint24_EN03_OptionB_Plan.md` (approved; Option B selected; Option A rejected — Phase 1: OFF shifts 337/500 rows)

---

## 1. Decision record (reviewer-approved, 2026-08-13)

- **Phase 1** (corpus population invariance, 504-bar corpus): LEGACY ≡ COORDINATED — 0/500 rows differ.
- **Phase 2** (targeted FM-2 adversarial scenario, 4-arm batch): 7/7 checks PASS; COORDINATED2 ≡ COORDINATED
  byte-identical (replay determinism); W=23 same-tick BOS-flip + opposite choch: LEGACY double-flips
  (flipGate=2, PP diverges), COORDINATED suppresses (coordSkip=1).
- **Option A** (remove the gate): **REJECTED** — Phase 1 shows OFF shifts 337/500 rows.
- **Option B** (coordinate): **SELECTED**. Production change authorized for implementation; commit/closure
  NOT authorized at that point (this document is the closure evidence request).

## 2. Implementation (exactly per plan §2; only the approved files changed)

| # | Change | File |
|---|---|---|
| A | New field `Trend m_trendBeforeTrendUpdate;` (next to `m_lastCHOCHCount`, ~:157) | `Portfolio/SymbolContext.mqh` |
| B | Constructor init `, m_trendBeforeTrendUpdate(TREND_UNKNOWN)` (~:300) | `Portfolio/SymbolContext.mqh` |
| C | Reset sites: `OnHistoryReset()` (~:165) and the `Update()` reset path (~:720) — same assignment, mirroring `m_lastCHOCHCount` | `Portfolio/SymbolContext.mqh` |
| D | Same-tick BOS snapshot captured between the BOS update and the trend update (~:796) | `Portfolio/SymbolContext.mqh` |
| E | Gate block replaced (~:823) with the validated coordinated gate: advance `m_lastCHOCHCount` → `currentTrend != TREND_UNKNOWN` guard → event direction `choch.bullish` → `ForceTrend(chochTrend)` only when `chochTrend != currentTrend && currentTrend == m_trendBeforeTrendUpdate`; else `m_logger.LogInfo("EN-03 Option B: gate suppressed ...")` | `Portfolio/SymbolContext.mqh` |
| F | Test surface only: `int GetTrendFlipCount(void) const` accessor; `Update`/`ForceTrend`/`Clear`/`OnHistoryReset` untouched | `Structure/TrendState.mqh` |

No-touch list held (plan §2.3): `BOSDetector`, `CHOCHDetector`, `ProtectedPointManager`, `OrderBlockDetector`,
`FVGDetector`, `LiquidityDetector`, `SwingDetector`, `StructuralPivotEngine`, `TrendState::Update`, all
`Confluence/`, `Entry/`, `Trading/`. Update order inside `CSymbolContext::Update` unchanged
(Swing → Pivot → BOS → Trend → PP → CHOCH → gate → OB → FVG → Liq → Viz → Confluence) — FM-4 no-reorder
disposition per plan §4 (PP for a legit choch flip activates next update, as LEGACY does today).

## 3. TDD fixtures — `Tests/unit/TestTrendFlipGate.mqh` (new, registered in `Tests/TestSuite.mqh`)

| # | Fixture | RED (pre-fix) | GREEN (post-fix) |
|---|---|---|---|
| F1 | FM-2 same-tick: W=23 BOS#2 bullish + opposite bearish choch | trend reverted to BEARISH (double flip); `TrendFlipCount` delta 2; PP diverges W=24/W=31 | trend stays BULLISH; delta 1 (BOS-only); gate suppressed; pp [19,23] |
| F2 | Event direction: legit (non-same-tick) flips take direction from `choch.bullish` (W=25 bearish, W=30 bullish) | n/a (legacy agrees) | flips 3: 1 BOS (W=23) + 2 gate |
| F3 | UNKNOWN defense: no flip while `TREND_UNKNOWN` (dead-branch guard; choch cannot fire under UNKNOWN, `CHOCHDetector.mqh:151-155`) | n/a | no flip, trend UNKNOWN |
| F4 | Reset contract: TIME_RESET clears gate state; deterministic rebuild | n/a | no stale flip; snapshot UNKNOWN |
| F5 | Call-site contract: `GetTrendFlipCount()` deltas — W=23 delta 1 (not 2), W=30 legit delta 1, final 1 | W=23 delta 2, final 4 | final 1 |
| F6 | W=12 table regression guard (bar-4 HIGH fix) | n/a | no BOS, no flip, UNKNOWN |

RED phase evidence (run `TT01_20260813_212908`, pre-fix binary): SUITE **2725/2738 — the only 13 failures
are the EN-03 fixture (97/110)**; all other gates green. 13 = F1 (10) + F5 (3), exactly the designed RED set.

## 4. Regression evidence (G1-G5)

| Gate | Result | Evidence |
|---|---|---|
| G1 RED→GREEN | PASS | GREEN run `TT01_20260814_144247` — SUITE **2738/2738, 0 failed**, EN-03 fixture **110/110** |
| G2 Compile | PASS | metaeditor64 0 errors on all 6 targets; `TestRunnerEA` back to the 6 pre-existing warnings (golden count; the 4 warning-60 "uninitialized" warnings from the fixture's F6 were eliminated — F6 locals initialized) |
| G3 Population invariance | PASS | TT01 full run `TT01_20260814_144247` (no `-AllowDelta`, no `-Skip`, `-ExpectedRows 500`), exit 0 — BEHAVIOR-REGRESSION 71/71 byte-identical; INTEGRITY-CONTROL 6239/6239 identical to frozen `CONTROL_RLHYP01_INTEGRITY`; REPLAY 500/500 HEALTHY; all other gates PASS |
| G4 Behavioral equivalence vs validated fork | PASS | `EN03_G4_manifest.json` overall true — **G4A** PROD2 CSV byte-identical to PROD1 (replay determinism, COORDINATED2≡COORDINATED analog); **G4B** all 29 windows' 7 shared detector/trend columns (trend,bos,choch,pp,ob,fvg,liq) equal the frozen `fm2_artifacts/COORDINATED/en03_fm2_coord.csv` (incl. W=23 suppression `1,2,1,2,1,0,3`, W=30 legit flip no-op, W=31 no-op, W=33 `1,3,1,2,1,0,6`); **G4C** the gate's "EN-03 Option B: gate suppressed" journal line fired at W=23 in both runs and `flipCount@W23=1` (single BOS flip). Harness: `Tools/EN03/EN03_FM2ScenarioProd.mq5` (production context, frozen 33-bar table) + `Tools/EN03/EN03_G4ProdFM2.ps1`; artifacts `Tools/EN03/g4_artifacts/PROD1|PROD2/` |
| G5 Corpus equivalence | PASS | G3's REPLAY (500 rows) + BEHAVIOR-REGRESSION (71/71) + EVIDENCE-REGRESSION (500/500) on the Phase-1 corpus profile are the corpus-equivalence gate: 0/500 rows differ with the production gate (suppression never fires on the corpus; LEGACY ≡ COORDINATED by construction) |

Artifacts (authoritative evidence, retained):
- `Tools/TT01/artifacts/TT01_20260814_144247/` (final GREEN full run, git `0ad75e1`-era source state, manifest + CSVs)
- `Tools/TT01/artifacts/TT01_20260813_212908/` (RED phase full run)
- `Tools/EN03/g4_artifacts/PROD1/`, `Tools/EN03/g4_artifacts/PROD2/` + `Tools/EN03/EN03_G4_manifest.json` (G4)
- Frozen references: `Tools/TT01/artifacts/TT01_20260813_185122/` (golden baseline), `Tools/EN03/fm2_artifacts/COORDINATED/en03_fm2_coord.csv`

## 5. Known deltas / notes (non-gating, recorded)

1. **Suppression log line**: the gate emits an INFO journal line per suppression ("EN-03 Option B: gate
   suppressed ..."). This is a journal-only delta (no telemetry/decision impact); it is the production
   evidence for the fork's `coordSkip` counter and is asserted by G4C. The golden 71/71 behavior columns
   and 6239/6239 integrity rows are unaffected (they are telemetry/decision data, not journal text).
2. **PERFORMANCE WARN**: suite runtime 21.2 s vs 9.1 s frozen baseline (WARN threshold 2x; gate is
   warning-only, run PASS). Cause: the +110-assertion EN-03 fixture drives 6 production contexts through
   29 growing windows each. No production-path cost.
3. **G4B column set**: the frozen COORD CSV carries research-only columns (`flipGate`, `flipCoord`,
   `coordSkip`, `signalCount`) that the production chain does not emit. The diff therefore compares the
   7 production-observable detector/trend columns per window; the research-only semantics are covered by
   G4C (suppression line + flipCount) and by the F1/F2/F5 fixtures at the production call site.

## 6. Guardrails held

- Only `Portfolio/SymbolContext.mqh` (behavioral) + `Structure/TrendState.mqh` (accessor) changed in source;
  no other module touched; no update-order change; no strategy switch ported.
- No source changes during the TT01 validation runs; no auto-fix of failures; no test modification to
  satisfy validators (the only test change after RED was eliminating 4 warning-60 compiler warnings in
  F6 — variable initialization only, re-verified GREEN).
- Attribution: clean — source delta = 2 production files + 1 new fixture file + 1 new scenario/harness pair.
- **Commit: NOT MADE. Closure decision: NOT AUTHORIZED.** Per the approved plan §8 and the reviewer's
  implementation authorization, this document closes the evidence loop; commit and closure status require
  explicit authorization.

---

*Sprint 24 EN-03 closure evidence, 2026-08-14. Companion: `docs/Sprint24_EN03_Assessment.md`,
`docs/Sprint24_EN03_OptionB_Plan.md`, `Tools/TT01/artifacts/TT01_20260814_144247/`,
`Tools/EN03/EN03_G4_manifest.json`.*
