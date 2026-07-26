# SuperCents_X — Visual Acceptance Criteria v2.0

**Document:** VisualAcceptanceCriteria.md  
**Version:** 2.0  
**Status:** Draft  
**Authority:** Lead QA Architect  
**Single Source of Truth:** VisualSpecification_v2.0.md  

---

## 1. PURPOSE

This document defines the exact conditions under which the SuperCents_X Visualization Engine is officially considered **complete**, **accepted**, and **frozen**. It is the final gate between development and production use.

No renderer modification may be performed after acceptance unless a new version of VisualSpecification is created (v2.1+). This document exists to prevent:

- Unlimited development cycles without objective completion criteria
- Subjective "looks good enough" sign-offs
- Regression-prone late-stage changes
- Disagreement between developers, QA, and stakeholders about what "done" means

---

## 2. SCOPE

### 2.1 In Scope

| Component | Included |
|---|---|
| VisualStateEngine | Yes |
| VisualizationManager | Yes |
| SwingRenderer | Yes |
| PivotRenderer | Yes |
| ProtectedRenderer | Yes |
| BOSRenderer | Yes |
| CHOCHRenderer | Yes |
| OrderBlockRenderer | Yes |
| FVGRenderer | Yes |
| ChartStyle (color palette) | Yes |
| ChartUtils (label collision) | Yes |
| RenderConfig (inputs) | Yes |
| ChartObjectNames (naming) | Yes |
| VisualDiagnostic (runtime dump) | Yes |

### 2.2 Out of Scope

| Component | Excluded | Reason |
|---|---|---|
| SwingDetector | Immutable per charter | Detector logic is not part of visualization |
| BOSDetector | Immutable per charter | Same |
| CHOCHDetector | Immutable per charter | Same |
| OrderBlockDetector | Immutable per charter | Same |
| FVGDetector | Immutable per charter | Same |
| StructuralPivotEngine | Immutable per charter | Same (except GetPivotByID added for renderer) |
| ProtectedPointManager | Immutable per charter | Same (except GetProtectedPointByID added for renderer) |
| Entry Engine | Immutable per charter | Separate subsystem |
| Trade Engine | Immutable per charter | Separate subsystem |
| Performance optimization | Not a requirement | Must be acceptable, not optimal |

---

## 3. DEFINITION OF DONE

The Visualization Engine is **DONE** when all five of the following conditions are met:

```
DONE = Architecture PASS
     AND Runtime PASS
     AND Visual PASS
     AND Regression PASS
     AND Performance PASS
```

If any condition is FAIL, the engine is **NOT DONE**. No partial acceptances. No conditional approvals.

Each condition is defined in Sections 4–8.

---

## 4. MANDATORY ACCEPTANCE TESTS

Before any visual or runtime testing begins, the following mandatory conditions must be verified:

| # | Test | Criterion | Method |
|---|---|---|---|
| M1 | Compilation | 0 errors, 0 hard warnings | MetaEditor compile log |
| M2 | Include graph | No circular includes, no missing headers | grep #include + manual trace |
| M3 | Naming convention | All objects follow `SCX_<STRUCTURE>_<TYPE>_<ID>` | Object dump from VisualDiagnostic |
| M4 | No hardcoded colors | All colors reference constants from ChartStyle.mqh | grep for RGB hex values in renderer .mqh files |
| M5 | No hardcoded object names | All names use accessor functions from ChartObjectNames.mqh | grep for string literals starting with "SCX_" in renderer .mqh files |
| M6 | No direct MT5 calls | No renderer calls ObjectCreate/ObjectMove/ObjectSetInteger/ObjectSetDouble/ObjectDelete directly — all go through VSE | grep in each renderer .mqh |

**PASS / FAIL**

---

## 5. VISUAL ACCEPTANCE TESTS

### 5.1 Methodology

A human QA engineer must observe the chart and verify each item against VisualSpecification_v2.0.md.

**Test environment:**
- Symbol: EURUSD (primary), GBPUSD (secondary)
- Timeframe: H1 (primary), M15 (secondary)
- Data range: Minimum 5000 bars of history
- Test duration: Minimum 1 hour of observation per symbol
- Chart theme: Dark background (default)

**Tooling:**
- VisualDiagnostic runtime dumper (Experts log) for object property verification
- VisualSpecification_v2.0.md for expected values
- QA_Checklist_v2.0.md for step-by-step human verification

### 5.2 Swing High

| ID | Visual Criterion | Spec Reference |
|---|---|---|
| V-SH-01 | Downward arrow (`OBJ_ARROW_DOWN`) centered above pivot candle | §3 |
| V-SH-02 | Arrow price = pivot price + 50 points | §3 |
| V-SH-03 | Colour = #E53935 | §3, §12 |
| V-SH-04 | Arrow never moves — static position | §3 |
| V-SH-05 | Arrow never repaints — identical on chart refresh (F5) | §3 |
| V-SH-06 | Arrows beyond 50th newest are deleted | §3, §16 |

**PASS / FAIL**

### 5.3 Swing Low

| ID | Visual Criterion | Spec Reference |
|---|---|---|
| V-SL-01 | Upward arrow (`OBJ_ARROW_UP`) centered below pivot candle | §4 |
| V-SL-02 | Arrow price = pivot price - 50 points | §4 |
| V-SL-03 | Colour = #43A047 | §4, §12 |
| V-SL-04 | Static — never moves | §4 |
| V-SL-05 | No repaint | §4 |
| V-SL-06 | Deleted beyond 50th newest | §4, §16 |

**PASS / FAIL**

### 5.4 Pivot

| ID | Visual Criterion | Spec Reference |
|---|---|---|
| V-PV-01 | White circle marker (arrow code 159) above high / below low | §5 |
| V-PV-02 | Marker offset = pivot price ± 50 points | §5 |
| V-PV-03 | Colour = #9E9E9E (unprotected) | §5, §12 |
| V-PV-04 | Colour = #42A5F5 when promoted to protected high | §5, §12 |
| V-PV-05 | Colour = #FB8C00 when promoted to protected low | §5, §12 |
| V-PV-06 | Deleted beyond 50th newest | §5, §16 |

**PASS / FAIL**

### 5.5 Protected High

| ID | Visual Criterion | Spec Reference |
|---|---|---|
| V-PH-01 | Horizontal `OBJ_TREND` line | §8 |
| V-PH-02 | Start time = pivot formation time (p.time) — NOT activationTime | §8 |
| V-PH-03 | Start price = pivot price level | §8 |
| V-PH-04 | End extends to current bar | §8 |
| V-PH-05 | Colour = #42A5F5 (active) | §8, §12 |
| V-PH-06 | Line style = STYLE_SOLID, width 1 (active) | §8, §15 |
| V-PH-07 | Label "PH" at pivot time + period/2, 20 points above line | §8 |
| V-PH-08 | Label colour = line colour | §8 |
| V-PH-09 | Freeze: STYLE_DASH, width 1, colour #276393 when new PH activated | §8, §15 |
| V-PH-10 | Historical: STYLE_DASHDOT, colour #173A56 when third PH exists | §8, §15 |
| V-PH-11 | Delete when count > 20 | §8, §16 |
| V-PH-12 | If ShowInactiveProtectedPoints=false: frozen line is deleted immediately | §8 |

**PASS / FAIL**

### 5.6 Protected Low

| ID | Visual Criterion | Spec Reference |
|---|---|---|
| V-PL-01 | Start time = pivot formation time (p.time) | §8 |
| V-PL-02 | Colour = #FB8C00 (active) | §8, §12 |
| V-PL-03 | Label "PL" 20 points below line | §8 |
| V-PL-04 | Freeze colour = #965400 | §8, §15 |
| V-PL-05 | Historical colour = #573100 | §8, §15 |
| V-PL-06 | All other checks identical to Protected High | §8 |

**PASS / FAIL**

### 5.7 Bullish BOS

| ID | Visual Criterion | Spec Reference |
|---|---|---|
| V-BB-01 | Horizontal `OBJ_TREND` line — no ray, no segment | §6 |
| V-BB-02 | Start time = broken pivot's formation time (pivotTime) — NOT breakTime | §6 |
| V-BB-03 | Start price = broken pivot's price level | §6 |
| V-BB-04 | End extends to current bar | §6 |
| V-BB-05 | Colour = #00C853 (active) | §6, §12 |
| V-BB-06 | Line style = STYLE_SOLID, width 2 (active) | §6, §15 |
| V-BB-07 | Label "BOS" at break candle + period/2 | §6 |
| V-BB-08 | Label price = line price + 20 points | §6 |
| V-BB-09 | Label colour = #00C853 | §6 |
| V-BB-10 | Freeze: STYLE_DASH, width 1, colour #007832 at new BOS breakTime | §6, §15 |
| V-BB-11 | Historical: STYLE_DASHDOT, colour #00461D when third BOS exists | §6, §15 |
| V-BB-12 | Delete when count > 30 | §6, §16 |
| V-BB-13 | Visual message: "THIS LEVEL was broken" — line at the level, not the candle | §6 |

**PASS / FAIL**

### 5.8 Bearish BOS

| ID | Visual Criterion | Spec Reference |
|---|---|---|
| V-BS-01 | Colour = #D32F2F (active) | §6, §12 |
| V-BS-02 | Label price = line price - 20 points | §6 |
| V-BS-03 | Freeze colour = #7E1C1C | §6, §15 |
| V-BS-04 | Historical colour = #4A1010 | §6, §15 |
| V-BS-05 | All other checks identical to Bullish BOS | §6 |

**PASS / FAIL**

### 5.9 Bullish CHOCH

| ID | Visual Criterion | Spec Reference |
|---|---|---|
| V-CB-01 | Diagonal `OBJ_TREND` line — finite segment, not horizontal | §7 |
| V-CB-02 | Start time = protected point's pivot time (ppTime) | §7 |
| V-CB-03 | Start price = protected point's price | §7 |
| V-CB-04 | End time = break candle time (e.time) — FIXED, does not extend | §7 |
| V-CB-05 | End price = break close price (e.breakPrice) | §7 |
| V-CB-06 | After 10+ bars, end remains at break candle — no delta | §7 |
| V-CB-07 | Colour = #FFB300 | §7, §12 |
| V-CB-08 | STYLE_SOLID, width 2 (briefly at creation, then frozen) | §7, §15 |
| V-CB-09 | Freeze: STYLE_DASH, width 1, colour #996B00 immediately after creation | §7, §15 |
| V-CB-10 | Historical: STYLE_DASHDOT, colour #593E00 when new CHOCH detected | §7, §15 |
| V-CB-11 | Label "CHOCH" at break candle + period/2 | §7 |
| V-CB-12 | Label price = break price + 10 points (bullish) | §7 |
| V-CB-13 | Label colour = #FFB300 | §7 |
| V-CB-14 | Delete when count > 30 | §7, §16 |
| V-CB-15 | Visual message: "Where structure was respected until failure" — finite captured segment | §7 |

**PASS / FAIL**

### 5.10 Bearish CHOCH

| ID | Visual Criterion | Spec Reference |
|---|---|---|
| V-CS-01 | Label price = break price - 10 points | §7 |
| V-CS-02 | All other checks identical to Bullish CHOCH | §7 |

**PASS / FAIL**

### 5.11 Order Block

| ID | Visual Criterion | Spec Reference |
|---|---|---|
| V-OB-01 | Rectangle (`OBJ_RECTANGLE`) enclosing the OB candle | §9 |
| V-OB-02 | Left edge = OB candle open time (ob.time) | §9 |
| V-OB-03 | Right edge = current bar — extends each bar | §9 |
| V-OB-04 | Top = ob.high, Bottom = ob.low | §9 |
| V-OB-05 | Colour = #1976D2 | §9, §12 |
| V-OB-06 | FILL = true, border STYLE_SOLID, width 1 (active) | §9, §15 |
| V-OB-07 | OBJPROP_BACK = false — visible above candles | §9 |
| V-OB-08 | Label "OB" centered at (high+low)/2, at ob.time + period/2 | §9 |
| V-OB-09 | Freeze on mitigation: FILL = false, STYLE_DASH, colour #0F467E | §9, §15 |
| V-OB-10 | No historical tier — frozen goes directly to delete | §9 |
| V-OB-11 | Delete on invalidation: rectangle disappears immediately | §9 |
| V-OB-12 | Delete when count > 20 | §9, §16 |
| V-OB-13 | Rectangle border visible at default zoom | §9 |

**PASS / FAIL**

### 5.12 Fair Value Gap

| ID | Visual Criterion | Spec Reference |
|---|---|---|
| V-FG-01 | Rectangle (`OBJ_RECTANGLE`) covering the gap region only | §10 |
| V-FG-02 | Left edge = displacement (middle) candle time (fvg.time) | §10 |
| V-FG-03 | Right edge = current bar — extends each bar | §10 |
| V-FG-04 | Top = fvg.upper, Bottom = fvg.lower | §10 |
| V-FG-05 | Rectangle covers ONLY the imbalance, not the whole candle range | §10 |
| V-FG-06 | Colour = #FFD54F | §10, §12 |
| V-FG-07 | FILL = true, border STYLE_SOLID, width 1 (active) | §10, §15 |
| V-FG-08 | OBJPROP_BACK = false | §10 |
| V-FG-09 | Label "FVG" centered at (upper+lower)/2, at fvg.time + period/2 | §10 |
| V-FG-10 | Freeze on fill: FILL = false, STYLE_DASH, colour #99802F | §10, §15 |
| V-FG-11 | Historical: STYLE_DASHDOT, colour #594A1C after ≥20 frozen bars | §10, §15 |
| V-FG-12 | Delete when count > 30 | §10, §16 |
| V-FG-13 | Rectangle border visible at default zoom | §10 |

**PASS / FAIL**

### 5.13 Layer Order

| ID | Visual Criterion | Spec Reference |
|---|---|---|
| V-LO-01 | FVG rectangles are the lowest visible layer | §11 |
| V-LO-02 | OB rectangles sit above FVG | §11 |
| V-LO-03 | PP lines sit above all rectangles | §11 |
| V-LO-04 | BOS lines sit above PP | §11 |
| V-LO-05 | CHOCH lines sit above BOS | §11 |
| V-LO-06 | Swing arrows sit above all lines | §11 |
| V-LO-07 | Pivot markers sit above swings | §11 |
| V-LO-08 | Labels (OBJ_TEXT) are topmost | §11 |
| V-LO-09 | No line is hidden behind a rectangle fill | §11 |
| V-LO-10 | No object has OBJPROP_BACK = true | §11 |

**PASS / FAIL**

### 5.14 Labels

| ID | Visual Criterion | Spec Reference |
|---|---|---|
| V-LB-01 | No two labels overlap on screen | §19 |
| V-LB-02 | Font size 8, readable at default zoom | §19 |
| V-LB-03 | Label colour matches parent structure's tier colour | §19 |
| V-LB-04 | Labels do not clip at chart edges | §19 |
| V-LB-05 | BOS/CHOCH labels sit at the break event, not the origin | §19 |
| V-LB-06 | PP labels sit at the pivot time | §19 |
| V-LB-07 | OB/FVG labels sit at the structure origin | §19 |
| V-LB-08 | Frozen/historical labels are dimmed to match their tier | §19 |
| V-LB-09 | Label is deleted when its parent structure is deleted | §19 |

**PASS / FAIL**

### 5.15 Tiers (Active / Frozen / Historical)

| ID | Visual Criterion | Spec Reference |
|---|---|---|
| V-TR-01 | Active: STYLE_SOLID, full colour, width 2 (lines) or 1 (rect borders) | §0, §15 |
| V-TR-02 | Frozen: STYLE_DASH, dimmed colour, width 1 | §0, §15 |
| V-TR-03 | Historical: STYLE_DASHDOT, further dimmed colour, width 1 | §0, §15 |
| V-TR-04 | Rectangles: FILL = true when active, FILL = false when frozen/historical | §15 |
| V-TR-05 | Transition is obvious — a trader can instantly distinguish active from frozen from historical | §15 |

**PASS / FAIL**

---

## 6. RUNTIME ACCEPTANCE TESTS

### 6.1 Methodology

Run the VisualDiagnostic runtime dumper (included in the EA) and verify its output against expected values.

**Configuration:**
- `VisualDiagnosticMode = DIAG_DUMP_ALL`
- `VisualDiagnosticFreq = 1` (dump every bar)
- Run for minimum 100 bars

### 6.2 Object Creation Verification

For every `SCX_` object on the chart:

| ID | Runtime Criterion | Verification |
|---|---|---|
| R-OC-01 | Object exists on chart | ObjectFind(0, name) >= 0 in dump |
| R-OC-02 | Object type matches spec | TYPE matches expected per structure |
| R-OC-03 | TIME1 matches expected origin time | Compare with spec for each type |
| R-OC-04 | PRICE1 matches expected origin price | Compare with spec for each type |
| R-OC-05 | TIME2 matches expected end time | For trend/rect: dump shows TIME2 |
| R-OC-06 | PRICE2 matches expected end price | For trend/rect: dump shows PRICE2 |
| R-OC-07 | RAY_RIGHT = false (OBJ_TREND only) | Dump shows RAY_RIGHT=0 |
| R-OC-08 | BACK = false (all objects) | Dump shows BACK=0 |
| R-OC-09 | No duplicate names | No two objects share the same name in the dump |
| R-OC-10 | Object count is bounded | Count never exceeds expected limits per type |

**PASS / FAIL**

### 6.3 Lifecycle Verification

| ID | Runtime Criterion | Verification |
|---|---|---|
| R-LC-01 | New objects appear in VISUAL_STATE_ACTIVE | VSE_STATE=ACTIVE in dump |
| R-LC-02 | Active objects extend TIME2 each bar | TIME2 advances monotonically |
| R-LC-03 | Frozen objects have locked TIME2 | TIME2 unchanged across consecutive dumps |
| R-LC-04 | Frozen objects have STYLE_DASH | STYLE=DASH, WIDTH=1 |
| R-LC-05 | Historical objects have STYLE_DASHDOT | STYLE=DASHDOT, WIDTH=1 |
| R-LC-06 | Deleted objects disappear from dump | Name no longer appears |
| R-LC-07 | FIFO deletion respects MAX limits | Count per type never exceeds spec max |
| R-LC-08 | No Active object is deleted | VSE_STATE=ACTIVE never transitions to deleted without FROZEN first |

**PASS / FAIL**

### 6.4 Rendering Consistency

| ID | Runtime Criterion | Verification |
|---|---|---|
| R-RC-01 | Objects persist across chart refresh (F5) | Same objects with same coordinates after refresh |
| R-RC-02 | No phantom objects | Every SCX object has a matching VSE state record |
| R-RC-03 | No orphaned labels | Every OBJ_TEXT with SCX prefix has a matching parent object |
| R-RC-04 | All objects have unique IDs | No two objects share the same numeric ID within a type |

**PASS / FAIL**

---

## 7. PERFORMANCE ACCEPTANCE TESTS

### 7.1 Methodology

Run the EA on a single chart (EURUSD, H1) for one week of historical data in backtester/visual mode. Measure the following metrics.

**Test configuration:**
- Symbol: EURUSD
- Timeframe: H1
- Test period: One week (168 bars minimum)
- Visual mode: ON (full rendering)
- Terminal: No other EAs running

### 7.2 Performance Criteria

| ID | Metric | Maximum Acceptable | Measurement Method |
|---|---|---|---|
| P-01 | VisualizationManager::Update() execution time | 50 ms per tick | Perf log in VizManager (printed to Experts) |
| P-02 | Total rendering time per bar | 100 ms | Sum of all renderer times from VizManager perf log |
| P-03 | Total SCX objects on chart at steady state | 250 (50 swings + 50 pivots + 30 BOS + 30 CHOCH + 20 PP + 20 OB + 30 FVG) | VisualDiagnostic count |
| P-04 | Object leak after 1000 bars | 0 leaked objects | Count after 1000 bars = count at steady state |
| P-05 | Chart freeze events | 0 | No terminal unresponsiveness during test |
| P-06 | MT5 frame rate | ≥ 30 FPS while EA is running | Visual observation of chart responsiveness |
| P-07 | Memory growth over test period | < 50 MB | Task Manager / MT5 memory usage delta |

**PASS / FAIL**

### 7.3 Failure Conditions

- If VizManager::Update() ever exceeds 50 ms: **FAIL**
- If total rendering exceeds 100 ms: **FAIL**
- If total SCX objects exceed 300: **FAIL**
- If any object names appear as duplicates: **FAIL**
- If terminal becomes unresponsive: **FAIL**

---

## 8. REGRESSION ACCEPTANCE TESTS

### 8.1 Methodology

Run the existing regression test suites. All tests must pass with the new visualization engine. Any failure is a regression.

### 8.2 Regression Suites

| ID | Test Suite | Expected Result | Actual Result |
|---|---|---|---|
| RGR-01 | Sprint10_VisualRegression | PASS | |
| RGR-02 | Sprint12_ExecutionRegression | PASS | |
| RGR-03 | Sprint13_TradeRegression | PASS | |

**PASS / FAIL**

### 8.3 Regression Scope

The following behaviours must be preserved from prior sprints:

- Detector output must be unchanged (visualization reads only, never writes)
- Entry signals must be generated at the same bars as before
- Trade execution must match pre-visualization behaviour
- No new MT5 errors in the Experts log
- No change to the number or timing of trades in a fixed backtest period

---

## 9. FAILURE CRITERIA

The Visualization Engine is **automatically rejected** if any of the following conditions is observed:

### 9.1 Visual Failures (Hard)

| # | Condition | Severity |
|---|---|---|
| F1 | Any renderer's visual output differs from VisualSpecification_v2.0 | **BLOCKER** |
| F2 | Any structure repaints (position changes after initial draw) | **BLOCKER** |
| F3 | Any structure jumps (non-monotonic position change) | **BLOCKER** |
| F4 | Any object is invisible when it should be visible | **BLOCKER** |
| F5 | Layer order is incorrect (line hidden behind rectangle) | **BLOCKER** |
| F6 | Historical tier transition is incorrect | **MAJOR** |

### 9.2 Runtime Failures (Hard)

| # | Condition | Severity |
|---|---|---|
| F7 | Any object leaks (not deleted when it should be) | **BLOCKER** |
| F8 | Any duplicate object name | **BLOCKER** |
| F9 | Chart freezes or becomes unresponsive | **BLOCKER** |
| F10 | Object coordinates do not match spec (TIME1/PRICE1/TIME2/PRICE2) | **BLOCKER** |
| F11 | VSE lifecycle state does not match object appearance | **MAJOR** |

### 9.3 Performance Failures (Soft)

| # | Condition | Severity |
|---|---|---|
| F12 | VizManager::Update() exceeds 50 ms | **MAJOR** |
| F13 | Total SCX objects exceed calculated maximum for test duration | **MAJOR** |
| F14 | Memory grows by more than 50 MB over test period | **MAJOR** |

### 9.4 Regression Failures (Hard)

| # | Condition | Severity |
|---|---|---|
| F15 | Any regression test fails | **BLOCKER** |
| F16 | Any detector behaviour changes due to visualization code | **BLOCKER** |
| F17 | Entry or trade behaviour changes | **BLOCKER** |

### 9.5 Resolution Path

| Severity | Required Action |
|---|---|
| **BLOCKER** | Engine is rejected. Fix must be made, then all 5 acceptance sections must re-pass before re-acceptance. |
| **MAJOR** | Engine may be conditionally accepted with a documented plan and timeline for fix. Fix must not modify architecture or spec. |

---

## 10. SIGN-OFF CRITERIA

### 10.1 Sign-off Table

| Section | Status | Signed By | Date |
|---|---|---|---|
| Architecture Acceptance (§4: Mandatory Tests) | PASS / FAIL | | |
| Visual Acceptance (§5) | PASS / FAIL | | |
| Runtime Acceptance (§6) | PASS / FAIL | | |
| Performance Acceptance (§7) | PASS / FAIL | | |
| Regression Acceptance (§8) | PASS / FAIL | | |
| No Blocker Failures (§9.1–9.4) | CONFIRMED | | |

### 10.2 Final Declaration

> **I, the undersigned Lead QA Architect, confirm that the SuperCents_X Visualization Engine has passed all five sections of acceptance criteria. I confirm that every renderer matches VisualSpecification_v2.0 as observed on the runtime chart, that no blocker or major failures remain, and that the engine is suitable for production use.**
>
> **Effective immediately, the Visualization Engine is FROZEN. No modifications to renderers, the VisualStateEngine, ChartStyle, ChartUtils, or the VisualizationManager are permitted without creating VisualSpecification_v2.1 and a new acceptance cycle.**

| Role | Name | Signature | Date |
|---|---|---|---|
| Lead QA Architect | | | |
| Lead SMC Architect | | | |
| Project Owner | | | |

---

## 11. VERSION HISTORY

| Version | Date | Author | Change |
|---|---|---|---|
| 2.0 | 2026-07-16 | Lead QA Architect | Initial acceptance criteria for visualization engine freeze |

---

*End of Visual Acceptance Criteria v2.0*
