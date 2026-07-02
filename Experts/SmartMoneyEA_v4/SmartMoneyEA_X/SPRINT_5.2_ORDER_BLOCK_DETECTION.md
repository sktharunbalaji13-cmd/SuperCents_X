# SPRINT 5.2 — Order Block Detection

## Sprint Overview

**Sprint:** 5.2  
**Duration:** TBD  
**Objective:** Implement institutional Order Block (OB) detection and visualization  
**Prerequisite:** Market Structure Engine v1.0.1 (COMPLETE)

---

## Objectives

1. Detect and classify Bullish and Bearish Order Blocks
2. Track OB mitigation status (tested / untested / partially tested)
3. Integrate OB detection with existing BOS/CHOCH market structure
4. Provide FVG (Fair Value Gap) integration points for future sprint
5. Visualize OBs on chart with clear labeling

---

## Architecture Impact

### New Components
- `OrderFlow/OrderBlockDetector.mqh` — Core OB detection engine

### Modified Components
- `Core/Engine.mqh` — Initialize and update OrderBlockDetector
- `Utils/Structures.mqh` — Add OrderBlock struct (already exists, may need extensions)

### Integration Points
- **SwingDetector:** OBs form at swing points (already detected)
- **BOSDetector:** OBs are invalidated when broken by BOS
- **CHOCHDetector:** OBs provide context for CHOCH significance
- **StateMachine:** OB zones influence state machine confidence

---

## Required Files

### New Files
- `OrderFlow/OrderBlockDetector.mqh` — Main OB detection logic
- `OrderFlow/OrderBlockDetector.mqh` — OB visualization

### Modified Files
- `Core/Engine.mqh` — Add OrderBlockDetector initialization and update calls
- `Utils/Structures.mqh` — Extend OrderBlock struct if needed
- `Utils/Constants.mqh` — Add OB visualization constants

### No Changes Required
- `Structure/BOSDetector.mqh` — Read-only integration via BOS events
- `Structure/CHOCHDetector.mqh` — Read-only integration via CHOCH events
- `Structure/SwingDetector.mqh` — No changes (OBs use existing swings)

---

## New Data Structures

### OrderBlock (Already Exists in Structures.mqh)

```cpp
struct OrderBlock
{
   datetime           formationTime;    // Time of the OB formation
   double             high;             // Order block high price
   double             low;              // Order block low price
   ENUM_TREND_STATE   type;             // Bullish or Bearish OB
   bool               mitigated;        // Whether the OB was used
   int                strength;         // Strength rating (1-3)
   string             objectName;       // Associated chart object name
};
```

### Proposed Extensions (If Needed)

```cpp
// Additional fields for Sprint 5.2
struct OrderBlock
{
   // ... existing fields ...
   
   int                relatedPivotID;   // Swing point that formed this OB
   int                bosID;            // BOS that confirmed this OB
   datetime           mitigationTime;   // When price first entered the OB
   double             mitigationPercent; // How much of OB was filled (0-100)
   int                testCount;        // Number of times price tested the OB
   bool               isFresh;          // OB formed in last N bars
   double             volume;           // Volume at OB formation (if available)
};
```

---

## Detection Algorithm Overview

### Phase 1: OB Identification

**Bullish Order Block:**
- Last bearish candle before a bullish BOS
- Must be a structural swing low (or within swing low zone)
- Body of the candle defines the OB range [open, close] or [close, open]
- Wick extensions define high/low boundaries

**Bearish Order Block:**
- Last bullish candle before a bearish BOS
- Must be a structural swing high (or within swing high zone)
- Body of the candle defines the OB range [open, close] or [close, open]
- Wick extensions define high/low boundaries

### Phase 2: OB Validation

1. **Structural Pivot Requirement:** OB must form at a confirmed swing point
2. **BOS Confirmation:** OB is only "active" after a BOS breaks the opposing structure
3. **Buffer Check:** OB must have minimum height (configurable, e.g., 5 points)
4. **Freshness:** OBs older than N bars are marked as "stale" (not discarded, just flagged)

### Phase 3: OB Tracking

- **Mitigation Detection:** Price entering OB zone = mitigation
- **Mitigation Complete:** Price closing on opposite side of OB = fully mitigated
- **Test Counting:** Each touch of OB zone increments test counter
- **Invalidation:** BOS breaking through OB invalidates it

### Phase 4: OB Scoring

**Strength Rating (1-3):**
- **3 (Strong):** OB at major swing, high volume, untested, recent
- **2 (Medium):** OB at minor swing, moderate volume, lightly tested
- **1 (Weak):** OB at micro swing, low volume, heavily tested or stale

---

## Validation Strategy

### Unit Tests
1. OB detection at known swing points
2. OB mitigation detection accuracy
3. OB invalidation on BOS
4. Strength rating logic

### Integration Tests
1. OB + BOS interaction (OB invalidated by BOS)
2. OB + CHOCH context (OB provides structure for CHOCH)
3. OB + FVG alignment (future sprint)

### Regression Tests
1. Existing BOS/CHOCH counts unchanged
2. Counter validation passes
3. No chronology errors introduced
4. Performance impact < 5% execution time increase

---

## Regression Plan

### Pre-Sprint Baseline
- BOS Events: 999 (498 bullish, 501 bearish)
- CHOCH Events: 131 (64 bullish, 67 bearish)
- Chronology Errors: 0
- Execution Time: ~17.5s (one-year EURUSD M15)

### Post-Sprint Validation
- Re-run one-year backtest (EURUSD M15, 2024-01-01 to 2024-12-31)
- Verify BOS/CHOCH counts unchanged
- Verify zero chronology errors
- Verify execution time increase < 5%
- Verify OB detection logs show expected counts

---

## Deliverables

1. **OrderBlockDetector.mqh** — Core detection engine
   - `Initialize()` — Set up OB detector
   - `Update()` — Scan for new OBs on each bar
   - `GetOrderBlock(int index)` — Retrieve OB by index
   - `GetOrderBlockCount()` — Total OB count
   - `GetBullishOrderBlocks()` — Bullish OB array
   - `GetBearishOrderBlocks()` — Bearish OB array
   - `GetOrderBlockByID(int pivotID)` — Find OB by related pivot

2. **Visualization**
   - `DrawOrderBlock(const OrderBlock &ob)` — Draw OB zone on chart
   - `DrawOBLabel(const OrderBlock &ob)` — Draw OB label with strength
   - `DrawOBMitigation(const OrderBlock &ob)` — Show mitigation status

3. **Integration**
   - Engine.mqh initialization and update calls
   - BOS invalidation callback
   - SwingDetector integration for OB formation

4. **Logging**
   - OB detection logs
   - OB mitigation logs
   - OB invalidation logs
   - OB statistics summary

5. **Documentation**
   - SPRINT_5.2_IMPLEMENTATION_REPORT.md
   - Updated PROJECT_STRUCTURE.md
   - Updated SPRINT_3.2_DELIVERABLES.md

---

## Definition of Done

- [ ] OrderBlockDetector compiles with 0 errors, 0 warnings
- [ ] One-year backtest passes without crashes
- [ ] BOS/CHOCH counts unchanged from baseline (999 BOS, 131 CHOCH)
- [ ] Zero chronology errors
- [ ] Zero invalid historical BOS
- [ ] Counter validation passes
- [ ] OB detection logs show reasonable counts (50-200 OBs per year)
- [ ] OB visualization renders correctly on chart
- [ ] OB mitigation detection works (manual verification on sample charts)
- [ ] OB invalidation on BOS works (manual verification)
- [ ] Performance impact < 5% execution time increase
- [ ] Code review completed
- [ ] Documentation updated
- [ ] Sprint report created

---

## Out of Scope (Future Sprints)

- FVG detection and integration (Sprint 5.3+)
- Liquidity sweep detection (Sprint 5.4+)
- OB volume profile analysis (Sprint 5.5+)
- Multi-timeframe OB confluence (Sprint 5.6+)
- OB-based trade signal generation (Sprint 6.0+)

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| OB detection false positives | Medium | Medium | Strict validation rules, buffer requirements |
| Performance degradation | Low | Medium | Efficient data structures, O(1) lookups |
| Integration issues with BOS | Low | High | Clear interface contracts, unit tests |
| Visualization clutter | Medium | Low | Configurable display options, aging |

---

## Dependencies

- **Market Structure Engine v1.0.1** (COMPLETE)
  - BOSDetector — Provides BOS events for OB invalidation
  - CHOCHDetector — Provides market structure context
  - SwingDetector — Provides swing points for OB formation
  - StateMachine — Provides market state for OB significance

---

## Success Metrics

| Metric | Target |
|---|---|
| OB Detection Accuracy | > 90% (manual verification) |
| False Positive Rate | < 10% |
| Mitigation Detection Accuracy | > 95% |
| Performance Impact | < 5% execution time increase |
| Code Coverage | > 80% (core logic) |
| Regression Failures | 0 |

---

## Timeline

| Week | Task |
|---|---|
| 1 | OrderBlockDetector core logic (detection + validation) |
| 2 | OB tracking (mitigation + invalidation + scoring) |
| 3 | Visualization and Engine integration |
| 4 | Testing, validation, and documentation |

---

## Notes

- OBs are **zones**, not single price levels
- OB mitigation is a **process**, not an event
- OB strength is **dynamic** and can change over time
- OBs remain valid until **mitigated** or **invalidated by BOS**
- Multiple OBs can exist at the same swing point (different timeframes)

---

**Status:** PLANNING COMPLETE — Ready for implementation