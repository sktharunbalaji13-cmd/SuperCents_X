# Sprint 2 Validation — Swing Detection Engine

## Acceptance Criteria

| Requirement | Pass Criteria | Status |
|-------------|---------------|--------|
| Clean compilation | 0 errors, 0 warnings | ✅ |
| Runtime stability | No crashes, no array errors | ⬜ |
| Swing High detection | Correct on historical data | ⬜ |
| Swing Low detection | Correct on historical data | ⬜ |
| Non-repainting | Confirmed swings never change | ⬜ |
| Unique IDs | No duplicates | ⬜ |
| Deterministic output | Identical results across repeated runs | ⬜ |
| Separation of concerns | No rendering or trading logic | ✅ Code audit |

## Test Procedure

### 1. Compilation Check
- Compile `SuperCents_X.mq5`
- Expected: `0 errors, 0 warnings`

### 2. Strategy Tester Replay (Manual)
- Run a 1-month historical test on EURUSD,M15
- Verify in the log:
  - `[SwingDetector][INFO] Initializing SwingDetector...`
  - `[SwingDetector][INFO] SwingDetector initialized`
  - `[SwingDetector][INFO] Swing Confirmed` entries for both highs and lows
  - `[SwingDetector][INFO] Shutting down SwingDetector...`
  - `[SwingDetector][INFO] SwingDetector shutdown complete`

### 3. Swing Count Stability
- After replay, verify the swing counts are non-zero and stable
- No duplicate IDs (IDs are monotonically increasing, no gaps)

### 4. Determinism
- Run the same test twice
- Verify identical swing counts and IDs in both runs

### 5. No Side Effects
- Verify no chart objects, no visualization, no trading operations in the log
- Verify no global variables are used (code audit)

## Public API Verification (via Engine)
```
CSwingDetector *detector = g_engine.GetSwingDetector();
int highCount = detector.GetSwingHighCount();
int lowCount  = detector.GetSwingLowCount();
SwingPoint sp;
detector.GetSwingHigh(0, sp);   // oldest swing high
detector.GetSwingLow(1, sp);    // second swing low
```

## Current File Structure
```
Structure/
  SwingDetector.mqh  -- Detection logic + storage
Core/
  Engine.mqh          -- Wires SwingDetector into lifecycle
Utils/
  Types.mqh           -- SwingPoint struct
  Constants.mqh       -- SWING_STRENGTH = 2