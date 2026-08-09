# Visual QA Checklist — SuperCents_X v2.0

**Instructions:** For each item, observe the chart and mark **PASS**, **FAIL**, or **NOT OBSERVED** (if the structure has not appeared yet). Attach a screenshot or describe the exact bar/time for any FAIL.

---

## 1. SWING HIGH

| # | Check | Expected | Result |
|---|---|---|---|
| 1.1 | Arrow type | Downward-pointing arrow (`OBJ_ARROW_DOWN`) | |
| 1.2 | Price position | Arrow tip is **above** the pivot candle high by 50 points | |
| 1.3 | Horizontal alignment | Arrow is centered on the pivot candle (sp.time), **not** on a neighboring bar | |
| 1.4 | Colour | `#E53935` (red) — matches COLOR_SWING_HIGH | |
| 1.5 | No overlap | Arrow does not overlap the candle body — visible gap between candle high and arrow tip | |
| 1.6 | Static | Arrow **never moves** across bars — position is locked | |
| 1.7 | Deletion | Swings older than 50th newest eventually disappear. Check after 60+ bars | |
| 1.8 | Instant identification | A trader seeing the chart for the first time can immediately pick out the swing high | |

**PASS / FAIL / NOT OBSERVED**

---

## 2. SWING LOW

| # | Check | Expected | Result |
|---|---|---|---|
| 2.1 | Arrow type | Upward-pointing arrow (`OBJ_ARROW_UP`) | |
| 2.2 | Price position | Arrow tip is **below** the pivot candle low by 50 points | |
| 2.3 | Horizontal alignment | Arrow centered on the pivot candle (sp.time) | |
| 2.4 | Colour | `#43A047` (green) — matches COLOR_SWING_LOW | |
| 2.5 | No overlap | Visible gap between candle low and arrow tip | |
| 2.6 | Static | Never moves | |
| 2.7 | Deletion | Same as swing high — oldest beyond 50 disappear | |
| 2.8 | Instant identification | Contrasts clearly with swing highs | |

**PASS / FAIL / NOT OBSERVED**

---

## 3. PIVOT

| # | Check | Expected | Result |
|---|---|---|---|
| 3.1 | Marker type | Small white circle (arrow code 159, `OBJ_ARROW`) | |
| 3.2 | Price position | 50 points **above** candle top for high pivot, **below** candle bottom for low pivot | |
| 3.3 | Alignment | Centered on the pivot candle time (p.time) | |
| 3.4 | Colour (unprotected) | `#9E9E9E` (gray) | |
| 3.5 | Colour (protected high) | `#42A5F5` (blue) — pivot marker changes colour when promoted | |
| 3.6 | Colour (protected low) | `#FB8C00` (orange) — pivot marker changes colour when promoted | |
| 3.7 | No overlapping | Pivot markers do not overlap swing arrows — they should sit above/below them | |
| 3.8 | Deletion | Pivots beyond 50th newest disappear | |

**PASS / FAIL / NOT OBSERVED**

---

## 4. BULLISH BOS

| # | Check | Expected | Result |
|---|---|---|---|
| 4.1 | Object type | Horizontal trend line (`OBJ_TREND`) — **not** a ray, not a segment | |
| 4.2 | Left edge (time) | Starts at the **broken pivot's formation time** — NOT the break candle | |
| 4.3 | Left edge (price) | Horizontal at the **broken pivot's price level** | |
| 4.4 | Right edge (active) | Extends to the **current bar** (rightmost visible bar) | |
| 4.5 | Colour | `#00C853` (vivid green) — COLOR_BOS_BULLISH | |
| 4.6 | Line style (active) | `STYLE_SOLID`, width 2 | |
| 4.7 | No ray | The line does NOT extend into the future (RAY_RIGHT = false) | |
| 4.8 | Label text | `"BOS"` | |
| 4.9 | Label position (time) | At the **break candle** (e.breakTime + period/2), **not** at the pivot | |
| 4.10 | Label position (price) | 20 points **above** the line | |
| 4.11 | Label colour | `#00C853` (matches line) | |
| 4.12 | Label readable | Font size 8, no overlap with other labels, no clipping at chart edge | |
| 4.13 | Freeze transition | When a new BOS is detected, the previous BOS **locks** at the new break time. Line changes to `STYLE_DASH`, width 1, colour dims to `#007832` | |
| 4.14 | Historical transition | When a third BOS exists, the oldest frozen BOS changes to `STYLE_DASHDOT`, colour `#00461D` | |
| 4.15 | Deletion | Oldest BOS deleted when count exceeds 30 | |
| 4.16 | Visual semantics | The line visually says "THIS LEVEL was broken" — line starts at the level origin, not the break event | |

**PASS / FAIL / NOT OBSERVED**

---

## 5. BEARISH BOS

| # | Check | Expected | Result |
|---|---|---|---|
| 5.1 | Colour | `#D32F2F` (vivid red) — COLOR_BOS_BEARISH | |
| 5.2 | Label position | 20 points **below** the line | |
| 5.3 | Freeze colour | `#7E1C1C` | |
| 5.4 | Historical colour | `#4A1010` | |
| 5.5 | All other checks | Same as Bullish BOS (4.1–4.16) | |

**PASS / FAIL / NOT OBSERVED**

---

## 6. BULLISH CHOCH

| # | Check | Expected | Result |
|---|---|---|---|
| 6.1 | Object type | Diagonal trend line (`OBJ_TREND`) — **not** horizontal | |
| 6.2 | Start (time) | At the **protected point's pivot time** (e.ppTime) | |
| 6.3 | Start (price) | At the **protected point's price** (e.ppPrice) | |
| 6.4 | End (time) | Exactly at the **break candle time** (e.time) — does NOT extend past it | |
| 6.5 | End (price) | At the **break close price** (e.breakPrice) | |
| 6.6 | Finite segment | Line has a clear start and end. It does NOT extend to current bar | |
| 6.7 | No extension | Check again after 10+ bars: the line still ends at the same break candle, never moves forward | |
| 6.8 | Colour | `#FFB300` (amber) — COLOR_CHOCH | |
| 6.9 | Line style (drawn) | `STYLE_SOLID`, width 2 (briefly — then immediately frozen) | |
| 6.10 | Freeze | Immediately after drawing, line becomes `STYLE_DASH`, width 1, colour `#996B00` | |
| 6.11 | Historical | When a new CHOCH appears, the previous frozen CHOCH becomes `STYLE_DASHDOT`, colour `#593E00` | |
| 6.12 | Label text | `"CHOCH"` | |
| 6.13 | Label position (time) | At break candle (e.time + period/2) | |
| 6.14 | Label position (price) | 10 points above the break price for bullish | |
| 6.15 | Label colour | `#FFB300` (matches line) | |
| 6.16 | Deletion | Oldest CHOCH deleted when count exceeds 30 | |
| 6.17 | Visual semantics | The line shows "where structure was respected until it failed" — a finite captured moment | |

**PASS / FAIL / NOT OBSERVED**

---

## 7. BEARISH CHOCH

| # | Check | Expected | Result |
|---|---|---|---|
| 7.1 | Label position | 10 points **below** break price | |
| 7.2 | All other checks | Same as Bullish CHOCH (6.1–6.17) | |

**PASS / FAIL / NOT OBSERVED**

---

## 8. PROTECTED HIGH

| # | Check | Expected | Result |
|---|---|---|---|
| 8.1 | Object type | Horizontal trend line (`OBJ_TREND`) — **not** a ray | |
| 8.2 | Start (time) | At **pivot formation time** (p.time) — NOT activationTime | |
| 8.3 | Start (price) | At pivot's price level | |
| 8.4 | End (active) | Extends to **current bar** (rightmost visible bar) | |
| 8.5 | Colour | `#42A5F5` (blue) — COLOR_PROTECTED_HIGH | |
| 8.6 | Line style (active) | `STYLE_SOLID`, width 1 | |
| 8.7 | Label text | `"PH"` | |
| 8.8 | Label position (time) | At pivot time + period/2 | |
| 8.9 | Label position (price) | 20 points above the line | |
| 8.10 | Freeze transition | When a new PH is activated, old PH locks at current bar. `STYLE_DASH`, width 1, colour `#276393` | |
| 8.11 | Historical transition | When a third PH exists, the oldest frozen one becomes `STYLE_DASHDOT`, colour `#173A56` | |
| 8.12 | Deletion | Oldest PP deleted when count exceeds 20 | |
| 8.13 | ShowInactive=false | If `ShowInactiveProtectedPoints = false`, frozen lines are **deleted immediately**, not frozen | |

**PASS / FAIL / NOT OBSERVED**

---

## 9. PROTECTED LOW

| # | Check | Expected | Result |
|---|---|---|---|
| 9.1 | Colour | `#FB8C00` (orange) — COLOR_PROTECTED_LOW | |
| 9.2 | Label text | `"PL"` | |
| 9.3 | Label position | 20 points **below** the line | |
| 9.4 | Freeze colour | `#965400` | |
| 9.5 | Historical colour | `#573100` | |
| 9.6 | All other checks | Same as Protected High (8.1–8.13) | |

**PASS / FAIL / NOT OBSERVED**

---

## 10. ORDER BLOCK

| # | Check | Expected | Result |
|---|---|---|---|
| 10.1 | Object type | Rectangle (`OBJ_RECTANGLE`) | |
| 10.2 | Left edge | At the OB candle time (ob.time) | |
| 10.3 | Right edge (active) | Extends to **current bar** — NOT a fixed 30-day rectangle | |
| 10.4 | Top edge | At OB candle high (ob.high) | |
| 10.5 | Bottom edge | At OB candle low (ob.low) | |
| 10.6 | Rectangle encloses candle | The rectangle bounds match the originating candle exactly | |
| 10.7 | Colour | `#1976D2` (deep blue) — COLOR_OB | |
| 10.8 | Style (active) | `OBJPROP_FILL = true` (filled), border width 1, `STYLE_SOLID` | |
| 10.9 | Z-order | Rectangle is **above** candles (visible), **below** trend lines | |
| 10.10 | Label text | `"OB"` | |
| 10.11 | Label position | Centered vertically `(high+low)/2`, horizontally at OB time + period/2 | |
| 10.12 | Freeze (mitigated) | When price enters the zone: `OBJPROP_FILL = false` (unfilled), border `STYLE_DASH`, colour `#0F467E` | |
| 10.13 | No historical tier | FROZEN goes directly to DELETE — no STYLE_DASHDOT phase | |
| 10.14 | Delete (invalidated) | OB disappears immediately when engine marks invalidated | |
| 10.15 | Delete (count) | Oldest OB deleted when count exceeds 20 | |
| 10.16 | Visible without zooming | The rectangle border is clearly visible at default chart zoom | |

**PASS / FAIL / NOT OBSERVED**

---

## 11. FAIR VALUE GAP

| # | Check | Expected | Result |
|---|---|---|---|
| 11.1 | Object type | Rectangle (`OBJ_RECTANGLE`) | |
| 11.2 | Left edge | At the displacement (middle) candle time (fvg.time) | |
| 11.3 | Right edge (active) | Extends to **current bar** | |
| 11.4 | Top edge | At fvg.upper (gap upper bound) | |
| 11.5 | Bottom edge | At fvg.lower (gap lower bound) | |
| 11.6 | Gap accuracy | Rectangle covers ONLY the imbalance between candle A and candle C — not the whole candle range | |
| 11.7 | Colour | `#FFD54F` (gold) — COLOR_FVG | |
| 11.8 | Style (active) | `OBJPROP_FILL = true`, border width 1, `STYLE_SOLID` | |
| 11.9 | Z-order | Above candles, below trend lines | |
| 11.10 | Label text | `"FVG"` | |
| 11.11 | Label position | Centered vertically `(upper+lower)/2`, horizontally at displacement time + period/2 | |
| 11.12 | Freeze (filled) | When price fills the gap: `OBJPROP_FILL = false`, border `STYLE_DASH`, colour `#99802F` | |
| 11.13 | Historical | After ≥20 frozen bars: `STYLE_DASHDOT`, colour `#594A1C` | |
| 11.14 | Deletion | Oldest FVG deleted when count exceeds 30 | |
| 11.15 | Visible without zooming | Rectangle border clearly visible at default zoom | |

**PASS / FAIL / NOT OBSERVED**

---

## 12. LABELS (Cross-cutting)

| # | Check | Expected | Result |
|---|---|---|---|
| 12.1 | No overlap | No two labels occupy the same screen space | |
| 12.2 | Readable | Font size 8, clear colour contrast against chart background | |
| 12.3 | Correct colour | Label colour matches its parent structure's colour tier (active/frozen/historical) | |
| 12.4 | Correct alignment | BOS/CHOCH labels sit at the break event, PP labels at the pivot time, OB/FVG labels at the structure origin | |
| 12.5 | No clipping | Labels near chart edges are fully visible, not cut off | |
| 12.6 | Frozen/historical labels | Labels dim to match their parent's tier colour | |
| 12.7 | Deletion | Label is removed when its parent structure is deleted | |

**PASS / FAIL / NOT OBSERVED**

---

## 13. LAYER ORDER

| # | Check | Expected | Result |
|---|---|---|---|
| 13.1 | FVG rectangles | Lowest visible layer — behind everything except candles | |
| 13.2 | OB rectangles | Above FVG, below all lines | |
| 13.3 | PP lines | Above OB/FVG rectangles | |
| 13.4 | BOS lines | Above PP lines | |
| 13.5 | CHOCH lines | Above BOS lines | |
| 13.6 | Swing arrows | Above all lines | |
| 13.7 | Pivot markers | Above swing arrows | |
| 13.8 | Labels (`OBJ_TEXT`) | Topmost — above all chart objects | |
| 13.9 | No OBJPROP_BACK | No object has `OBJPROP_BACK = true` — all are in front of candles | |
| 13.10 | No hidden lines | Trend lines (PP, BOS, CHOCH) are never hidden behind rectangle fills | |

**PASS / FAIL / NOT OBSERVED**

---

## 14. COLOUR TABLE VERIFICATION

| Constant | Expected Hex | Visible on chart? | Match? |
|---|---|---|---|
| COLOR_SWING_HIGH | `#E53935` | | |
| COLOR_SWING_LOW | `#43A047` | | |
| COLOR_PIVOT | `#9E9E9E` | | |
| COLOR_PIVOT_PROTECTED_HIGH | `#42A5F5` | | |
| COLOR_PIVOT_PROTECTED_LOW | `#FB8C00` | | |
| COLOR_BOS_BULLISH | `#00C853` | | |
| COLOR_BOS_BEARISH | `#D32F2F` | | |
| COLOR_CHOCH | `#FFB300` | | |
| COLOR_OB | `#1976D2` | | |
| COLOR_FVG | `#FFD54F` | | |
| COLOR_PROTECTED_HIGH | `#42A5F5` | | |
| COLOR_PROTECTED_LOW | `#FB8C00` | | |

All frozen (60%) and historical (35%) dimmed variants also match the hex values in §12.

**PASS / FAIL / NOT OBSERVED**

---

## 15. LIFECYCLE TRANSITION VERIFICATION

For each structure type that transitions, verify on chart:

| Type | Active → Frozen | Frozen → Historical | Active → Deleted (invalidated) |
|---|---|---|---|
| BOS | | | N/A |
| CHOCH | | | N/A |
| PP | | | N/A |
| OB | | N/A | |
| FVG | | | N/A |

Check:
- **Frozen**: Line style changes from SOLID to DASH. Colour dims.
- **Historical**: Line style changes from DASH to DASHDOT. Colour dims further.
- **Deleted**: Object and its label disappear from chart.

**PASS / FAIL / NOT OBSERVED**

---

## 16. EDGE CASE TESTS

| # | Scenario | Expected visual | Result |
|---|---|---|---|
| 16.1 | Rapid BOS detection (10+ in 5 bars) | Only 30 BOS lines visible. Oldest are deleted. Frozen/historical tiers visible | |
| 16.2 | Gap chart | FVG rectangles cover only the gap region, not the whole candle | |
| 16.3 | Protected point flip (bull→bear) | Old PH freezes (or disappears if ShowInactive=false), new PL appears immediately | |
| 16.4 | OB mitigation | Rectangle fill disappears on the bar where price enters zone | |
| 16.5 | FVG fill then new FVG | Filled FVG freezes (dash), new FVG extends independently | |
| 16.6 | CHOCH in fast market | CHOCH drawn, frozen immediately, never extends past break candle | |
| 16.7 | CompactLabels = false | Labels appear at their base price (no collision avoidance offset) | |
| 16.8 | CompactLabels = true | Labels offset to avoid overlap within 20-point radius | |
| 16.9 | ShowProtectedPoints = false | All PP lines and labels hidden. Pivot markers still visible | |
| 16.10 | Chart refresh (F5) | Objects persist. No visual change after refresh | |
| 16.11 | Timeframe switch | All objects cleared. New objects appear for new timeframe | |

**PASS / FAIL / NOT OBSERVED**

---

## SUMMARY

| Section | PASS | FAIL | NOT OBSERVED |
|---|---|---|---|
| 1. Swing High | | | |
| 2. Swing Low | | | |
| 3. Pivot | | | |
| 4. Bullish BOS | | | |
| 5. Bearish BOS | | | |
| 6. Bullish CHOCH | | | |
| 7. Bearish CHOCH | | | |
| 8. Protected High | | | |
| 9. Protected Low | | | |
| 10. Order Block | | | |
| 11. FVG | | | |
| 12. Labels | | | |
| 13. Layer Order | | | |
| 14. Colour Table | | | |
| 15. Lifecycle | | | |
| 16. Edge Cases | | | |

**VERDICT:**

- ALL PASS → **Visualization subsystem is frozen. No more code changes.**
- ANY FAIL → Open a defect with the screenshot, expected vs actual, and the runtime object dump for the failing object.
- ALL NOT OBSERVED → Insufficient test data. Continue running until structures appear.

---

*End of QA Checklist v2.0*
