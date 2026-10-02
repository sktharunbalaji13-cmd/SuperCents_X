# 2026-08-27 Bug Register — SuperCents_X

## Section B: Open, Reachable Bugs (Fixed This Session)

### B1: ProtectedPointManager activationTime uses forming bar

**File:** `Structure/ProtectedPointManager.mqh:132`
**Severity:** High — silently defeats the Phase-4 renderer freeze-anchor fix
**Status:** FIXED

**Description:**
`ProtectedPointManager::Update()` called `ProcessCurrentTrend(pivotEngine, currentTrend, time[0])` where `time[0]` was the forming bar. The `activationTime` field was stamped with the forming bar time. The CHOCH detector uses `activationTime` as a guard (`currentBarTime < activePoint.activationTime`), and the visualization freeze-anchor logic references this field. The visualization fix was correct in code but fed wrong data.

**Root Cause:**
The method received `const datetime &time[]` and the callers (SymbolContext.mqh:928-931, EN03_ResearchSymbolContext.mqh:861-864) worked around the issue by creating a 1-element array with `time[1]` (closed bar). This was fragile — the API contract suggested the full array but the implementation relied on caller-side translation.

**Fix:**
1. Added `int rates_total` parameter to `ProtectedPointManager::Update()`
2. Method now computes `activationBar = (rates_total >= 2) ? time[1] : time[0]` internally
3. Callers now pass the full `time[]` array and `rates_total` directly, eliminating the 1-element array workaround

**Files Changed:**
- `Structure/ProtectedPointManager.mqh` — method signature + implementation
- `Portfolio/SymbolContext.mqh` — caller simplified
- `Tools/EN03/EN03_ResearchSymbolContext.mqh` — caller simplified

---

### B2: CHOCHDetector Shutdown() state leak

**File:** `Structure/CHOCHDetector.mqh:409-443`
**Severity:** High — dirty state on restart causes false CHOCH events
**Status:** FIXED

**Description:**
`CCHOCHDetector::Shutdown()` only reset `m_chochCount` and `m_isInitialized`. It did NOT reset `m_nextId`, `m_lastProcessedBar`, `m_lastActiveHighId`, `m_lastActiveLowId`, `m_highActivationRatesTotal`, `m_lowActivationRatesTotal`, or `m_stats`. After Shutdown(), a subsequent Init() would start with stale state from the previous session.

**Root Cause:**
`Shutdown()` was written as a log-and-zero function that didn't delegate to `Clear()`. The `Clear()` method existed and reset all state variables, but Shutdown() reimplemented a subset.

**Fix:**
`Shutdown()` now calls `Clear()` before setting `m_isInitialized = false`, matching the pattern used by BOSDetector, SwingDetector, and StructuralPivotEngine.

**Pattern Note:**
This is the same Shutdown()/Clear() divergence found in three files this sprint. A repo-wide sweep of this pattern was recommended.

---

### B3: OrderBlockDetector Shutdown() state leak

**File:** `Structure/OrderBlockDetector.mqh:360-387`
**Severity:** High — dirty state on restart causes false OB events
**Status:** FIXED

**Description:**
`COrderBlockDetector::Shutdown()` only reset `m_orderBlockCount` and `m_isInitialized`. It did NOT reset `m_nextId`, `m_lastProcessedCHOCHIndex`, or `m_stats`. After Shutdown(), a subsequent Init() would start with stale state.

**Root Cause:**
Same as B2 — Shutdown() reimplemented a subset of Clear() instead of delegating to it.

**Fix:**
`Shutdown()` now calls `Clear()` before setting `m_isInitialized = false`.

---

### B4: SwingDetector unchecked buffer access

**File:** `Structure/SwingDetector.mqh:215-241`
**Severity:** Medium — latent crash risk if API contract is violated
**Status:** FIXED

**Description:**
`IsSwingHigh()` and `IsSwingLow()` accessed `high[center-2]` through `high[center+2]` without validating buffer bounds. The `IsValidBarIndex()` function existed (line 204-213) but was never called. While the current `Update()` logic ensured safe indices (center ranges from 4 to rates_total-4), the functions themselves didn't validate. Any caller passing an undersized array or incorrect center would cause an out-of-bounds read.

**Fix:**
1. Added `int rates_total` parameter to `IsSwingHigh()` and `IsSwingLow()`
2. Both functions now call `IsValidBarIndex(center, rates_total)` at entry and return false if invalid
3. Updated callers in `Update()` to pass `rates_total`

---

## Section C: Latent Items (Not looked at this session)

These items were identified in the original bug register but not investigated:

- C1: FVGDetector lifecycle — forming-bar [0] reads in `UpdateLifecycle()` (close[1] is used, appears correct)
- C2: LiquidityDetector `DetectInvalidations()` uses `time[0]` for BOS invalidation timestamp
- C3: TrendState forming-bar dependency in BOS scan
- C4: ConfluenceEngine evaluation timing relative to detector updates
- C5: VisualizationManager `OnHistoryReset()` clearing order

---

## Section D: Bug Classes Never Swept

These were explicitly marked as "not looked at", not "clean":

- D1: All `time[0]` reads across the codebase (forming-bar lookahead)
- D2: All `Shutdown()`/`Clear()` divergence (repo-wide sweep recommended)
- D3: All array access without bounds validation
- D4: All `close[1]`/`time[1]` assumptions about series ordering

---

## Section E: Pipeline/Process Issues

- E1: Pinned .ex5 predates all fixes — test results describe a different EA version
- E2: No automated regression suite runs against source changes
- E3: Compile logs scattered across root directory (no structured output)
- E4: No CI/CD pipeline for MetaTrader compilation
- E5: Test fixture isolation — negative control passed but positive cases untested
- E6: Environment traps — Strategy Tester can silently pass with wrong presets

---

## Section F: Cosmetic Items

- F1: Diagnostic Print statements left in production code (PHASE_1_5_DIAGNOSTIC)
- F2: Verbose OB-SEARCH logging in OrderBlockDetector
- F3: FVG-REJECT time-window gated logging (hardcoded dates)
- F4: Inconsistent log formatting across detectors

---

## Section G: Priority Order

1. **B1 (completed)** — activationTime regression defeats visualization fix
2. **B2/B3 (completed)** — Shutdown()/Clear() state leaks
3. **B4 (completed)** — SwingDetector unchecked buffers
4. **E1** — Update pinned .ex5 to include all fixes
5. **D2** — Repo-wide Shutdown()/Clear() divergence sweep
6. **D1** — Repo-wide forming-bar [0] audit
