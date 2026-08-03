# 04 — Liquidity Detection — Deep Research (AVP Sprint 19.4)

| Field | Value |
|---|---|
| Document | `04_Liquidity_Deep_Research.md` |
| Series | AVP Sprint 19 (docs 01–06), frozen methodology v1.0 |
| Component | Liquidity detection: EQH/EQL levels, external HH/LL, sweeps, mitigations, invalidations |
| Primary file | `Structure/LiquidityDetector.mqh` (866 lines) |
| Consumers | Confluence rules (LIQUIDITY_BOS), ExecutionPlanner resolvers (entry/stop/target), Telemetry v3 columns |
| Prior work | Sprint 18.4 (research review), 18.8 (rule families), 18.9 (entry gate) |
| Verification status | **64/100 — IMPROVE** |
| Main findings | S1 weakest-possible sweep definition; S2 reset-lifecycle defect (E11, 4th occurrence); S3 raw-evidence telemetry dead; S4 `classification` field never written (target degeneracy); S5 no liquidity renderer exists |
| Evidence | Sprint 17 frozen set — 18,686 rows; decided+signal n=17,073; base wr 0.3321 |

---

## P1. Research context — what "liquidity sweep" means across schools

### P1.1 Canonical doctrine

| Concept | Canonical definition (industry corpus 2026) | Source cluster |
|---|---|---|
| Equal highs/lows (EQH/EQL) | Two+ swing points topping/bottoming at "obvious" equal prices; resting stop clusters stacked just beyond | liquidityscan.io, arongroups.co, LuxAlgo |
| Liquidity sweep (stop run / grab) | Price briefly pushes **through** a key level to trigger pending orders, then **reverses back** — the reversal is the event, not the touch | capitalminds.io, mycalcu.com, eliteforextrading |
| Sweep vs breakout | A **wick** that reclaims the level = trap/sweep; a **close beyond** that holds = genuine breakout. "The sweep is the trigger, not the break." | liquidityscan.io, backtrex.com |
| Sweep vs grab | A grab is a minor probe with no follow-through; a sweep is a *confirmed* reversal event (no displacement/MSS) | liquidityscan.io taxonomy |
| Tolerance for "equal" | "They don't need to match to the tick... closely enough that the level looks obvious"; tools use **adaptive ATR-based tolerance** or fixed ticks | liquidityscan.io, TradingView (GaboAlgoLab), LuxAlgo |
| Confirmation | Sweep confirmed **on bar close**: high trades above EQH but the bar **closes back below** it | TradingView GaboAlgoLab (open-source spec) |
| Entry logic | Wait for sweep → watch LTF for shift in structure → enter on pullback; stop beyond sweep wick; **target opposite liquidity** | capitalminds.io (textbook ICT sequence) |
| Significance of equal levels | Levels = larger external targets beyond inducement traps; often "fuel" rather than barriers | liquidityscan.io, mycalcu.com |

### P1.2 Academic anchors (as compiled in Sprint 18.4 §2)

| Study | Finding | Bearing on this component |
|---|---|---|
| **Osler (2002/2005)** — 9,655 FX customer orders, ~$55B, RBS desk Aug 1999–Apr 2000 | ~43% of customer order volume is stop-loss; stops cluster at technical levels (≈10% at round "00" prices, also recent extremes); stop clusters **produce price cascades**; response at stop clusters larger/longer-lived than at take-profit clusters | Premise confirmed on real dealer flow: stops DO rest at technical levels. The doctrine's reversal-vs-continuation branch is exactly what a *confirmed* sweep definition must distinguish — the untouched variant cannot |
| **Kavajecz & Odders-White (2004)** — limit-order depth at technical levels (NYSE) | Technical levels coincide with concentrations of limit-order depth | Provides the *continuation* mechanism (book is deep at the level) — again the branch the current detector never separates |
| **Kaminski & Lo (2014)** — stop-loss rule regimes | Stop rules help in momentum regimes, hurt in mean-reverting ones | Sweep-first families implicitly bet on regime; confirmation-free sweeps are regime-ambiguous |

**P1 verdict:** the *premise* of the liquidity family is the best-academically-anchored idea in the EA (Osler is direct evidence of stop clustering). But the entire edge story depends on the **reversal** branch — "price sweeps, then comes back." Every practitioner source insists the sweep event is defined by the *close-back* (reclaim), never by the touch. That is the single most important check for this component.

---

## P1.5. Component specification (as designed / as documented)

Per Sprint 18.4 Phase 6 and this harvest:

- **Level formation** — EQH/EQL clusters from swing highs/lows within a fixed tolerance; external HH/LL seeded from BOS pivots; internal HH/LL exist in the type enum.
- **Level lifecycle** — ACTIVE → SWEPT → MITIGATED / INVALIDATED, with per-level timestamps and bar indices.
- **Sweep semantics (designed)** — "price trades beyond an active level" (Sprint 18.4 documented this exact semantics and flagged it as the *weakest possible* definition).
- **Consumption** — `RULE_LIQUIDITY_BOS_*` (recent opposite sweep + recent BOS, trend-alignment bonus), layer score 0–30, entry resolvers for level-based entry/stop/target.
- **Telemetry (designed)** — `liquidityRaw/Weight/Contribution` + `layerLiquidity` + `hasLiquiditySweep` in schema v3.

State machine:

```
Swing/BOS feeds
      │
      ▼
 DetectEQH / DetectEQL ──▶ ACTIVE level (avg of matching swings, tolerance 3 pips)
 DetectExternal (BOS) ────▶ EXTERNAL_HH/LL level
      │
      ▼
 DetectSweeps (forming bar: high[0] ≥ avg or low[0] ≤ avg) ──▶ SWEPT
      │
      ├─ DetectMitigations (touch back inside zone) ──▶ MITIGATED
      └─ DetectInvalidations (opposing BOS vs swept level) ──▶ INVALIDATED
```

---

## P2. Tooling survey — how production tools implement sweep confirmation

| Tool | Sweep rule | Tolerance for equality | Reversal condition |
|---|---|---|---|
| TradingView "Liquidity Sweeps EQH/EQL" (GaboAlgoLab, open-source) | Confirmed **on bar close**: high above EQH **and close back below** | Adaptive ATR-based or fixed ticks | Close-back inside after piercing |
| LuxAlgo EQH/EQL Liquidity Zones | Zone detection + "tracks whether level was taken" | Zone-based, "obvious" equality | Level-taken flag, no auto-signal |
| liquidityscan.io (ICT practitioner) | Sweep = confirmed reversal event; a probe without reversal is a **grab** (noise) | "Obvious on the chart", relative equal levels accepted | Reversal required; displacement/MSS distinction |
| arongroups.co (SMC guide) | Trap: price spikes through, triggers orders, "then the price drops fast" | Multi-test at the level | Sharp reversal after trigger |
| backtrex.com / capitalminds.io | "Sweep then form order block in opposite direction = highest-probability setup" | n/a | Structural confirmation on LTF |

**P2 verdict:** Every surveyed tool separates the *touch* from the *sweep event*. The current implementation equates them (P3, S1). No surveyed tool scores a forming-bar touch as a sweep.

---

## P3. Code facts (harvest, verified against source)

Path abbreviations: `LQD` = `Structure/LiquidityDetector.mqh`; `CONST` = `Utils/Constants.mqh`; `TYPES` = `Utils/Types.mqh`; `CE` = `Confluence/ConfluenceEngine.mqh`; `RULES` = `Confluence/ConfluenceRules.mqh`; `SCORES` = `Confluence/ScoreCalculator.mqh`; `TCB` = `Confluence/TradeCandidateBuilder.mqh`; `TYPES_T` = `Telemetry/TelemetryTypes.mqh`; `TREQ` = `Telemetry/TelemetryRowBuilder.mqh`; `SYM` = `Portfolio/SymbolContext.mqh`.

### P3.1 Algorithm

- **File:** `LQD`, 866 lines; class `CLiquidityDetector` declared `LQD:15`; per-bar update pipeline `LQD:125–143`: `DetectEQH(); DetectEQL(); DetectExternal(); DetectSweeps(...); DetectMitigations(...); DetectInvalidations(...)`.
- **EQH detection** (`LQD:145–250`, EQL mirror `LQD:252–354`):
  - Incremental cursor `m_lastSwingHighId`; early-return `if(highCount <= m_lastSwingHighId)` (`LQD:151–152`); cursor advance `m_lastSwingHighId = highCount` (`LQD:249`).
  - Tolerance `LIQUIDITY_EQH_TOLERANCE_PIPS * _Point * 10 + eps`, eps = half-point (`LQD:154–155`); constant **3 pips** (`CONST:91–92`).
  - Partner search: lookback **100 swings** (`LQD:187`, `LQD:292`).
  - Cluster anchor: existing ACTIVE levels only (`FindMatchingEQH` `LQD:706–720`); cluster price = rolling arithmetic mean (`LQD:171–173`); new level price = midpoint `(sp.price + partner.price)/2.0` (`LQD:196–198`), memberCount forced 2.
- **External levels** (`LQD:356–402`): bullish BOS → `EXTERNAL_HH` at `bos.pivotPrice`; bearish BOS → `EXTERNAL_LL`; seeded at `bos.breakBar`; cursor `m_lastBOSId` (`LQD:401`).
- **Sweep detection** (`LQD:404–483`) — the critical block:
  - `curHigh = high[0]; curLow = low[0]` with series arrays (`SYM:633–637`) → **the forming bar** is the sweep evaluator.
  - Swept when `curHigh >= level.averagePrice` (buy-side) / `curLow <= averagePrice` (sell-side) — **any touch, no close-back, no displacement, no time window** (`LQD:428–437`).
  - Mitigation (`LQD:485–539`): swept level mitigated when price *touches back inside* the zone (`LQD:509,514`), no close requirement; mitigatedPrice = bar mid-price.
  - Invalidation (`LQD:541–592`): opposing BOS vs a SWEPT level, **only EQH/EXTERNAL_HH and EQL/EXTERNAL_LL** — internal HH/LL never invalidated (`LQD:573–576`).
- **Lifecycle gates:** `SweepLevel` rejects any non-ACTIVE level (`LQD:780–805`); `MitigateLevel` requires SWEPT (`LQD:807–834`); `InvalidateLevel` requires SWEPT (`LQD:836–864`).
- **No confirmation/prevalence/window rigor:** no ATR anywhere in the subsystem (0 hits across detector + rules + evaluator + scores); no STH/ITH/LTH tiers (0 hits); no min-bars gate; the only windows are the 100-swing search and consumers' 10-bar "recent" filters (`RULES:15,168`; `LiquidityEvaluator.mqh:8,26`).

### P3.2 Constants and config

| Constant | Value | Live? |
|---|---|---|
| `LIQUIDITY_EQH_TOLERANCE_PIPS` | 3 | used `LQD:155,709` |
| `LIQUIDITY_EQL_TOLERANCE_PIPS` | 3 | used `LQD:262,725` |
| `LIQUIDITY_MAX_LEVELS` | 256 | **DEAD** — never referenced (levels are a dynamic array, `LQD:774`) |
| `SWING_STRENGTH` / `SWING_LOOKBACK_BARS` | 2 / 2 | DEAD (shared with Swing F4) |
| `WeightLiquidity` | 15.0 | live (EA input + ConfluenceWeights) |
| `SCORE_LIQUIDITY_SWEPT` | 30 | live (`SCORES:14,110`) |

### P3.3 State / reset hygiene — S2 (E11 family, 4th occurrence)

- `Init()` (`LQD:99–123`) resets everything; `Shutdown()` (`LQD:594–688`) clears levels but **not** `m_nextId`, cursors, or `m_invalidationSeeded`.
- **No `RatesTotalShrink` handler anywhere in the codebase**; the only reload guard is in `SwingDetector` (`SWING:113–119`, `Clear()` at `SWING:181–191` restarts swing ids at 1).
- Liquidity cursors advance monotonically (`LQD:249, 353, 401, 591`). After a chart reload, SwingDetector re-scans (ids restart at 1) while liquidity cursors stay stale → `DetectEQH/EQL/External/Invalidations` early-return forever on the re-scan; stored `leftSwingId/rightSwingId` references collide with reused ids.
- Same family as BOS C3, CHOCH C2, Swing S2; consumers additionally keep by-id references (`TCB:404–415` `CheckLiquidityStillValid`; `CE:422–443` signal lifecycle) that can silently resolve against recycled ids.

### P3.4 Consumers / wiring

- **Rules** (`RULES:149–184, 353–434`): `RecentLiquiditySweep` scans levels newest→oldest for `swept && sweptTime >= iTime(...,10)`; `RuleLiquidity_BOS_*` requires recent **opposite** sweep + recent BOS + trend bonus (+10 conf), mitigated deduction; confidence capped 0.99.
- **Context bridge:** `BuildDetectionContext` sets `context.liquidityDetector` (`CE:523`) — unlike swings, the liquidity pointer IS wired — but `swingHigh/swingLow` remain 0.0 (re-confirms Swing S1).
- **Evaluator path:** `CLiquidityEvaluator` (sweep=60, +20 fresh, +20 PP, cap 100) registered **only** in `Tests/unit/TestConfluenceEngine.mqh:289–324` and `benchmarks/BenchmarkConfluence.mqh:221,290–295` — dead in production; the rule path is live (`CE:240–291`).
- **Entry resolvers** (`ExecutionPlanner.mqh:243,251–254,397–402`):
  - Entry `ENTRY_LIQUIDITY_LEVEL` → `ll.price` (`EntryPriceResolver.mqh:50–63`) — note **`ll.price`, not `averagePrice`** (two different "level price" fields in play).
  - Stop `STOP_LIQUIDITY_SIDE` → `ll.price ± buffer`.
  - Target `TARGET_OPPOSING_LIQUIDITY` → direction-dependent, **relies on `ll.classification` OR `ll.swept`** (`TargetResolver.mqh:32–52`) — see S4: `classification` is never written, so the fallback `|| ll.swept` always fires → the "opposing" target is actually **the same swept level's price**.
- **Validator gate:** production chain Direction → ConfluenceValidator → Freshness → Spread → Session → Distance → Cooldown → Risk (`SYM:588–595`). `CConfluenceValidator` is **confidence-only** (`ConfluenceValidator.mqh:23–47`, no ruleName allow-list; `minConfidence` default 0.60). The 18.9 "admits only LIQUIDITY_BOS" statement is therefore an *empirical* outcome: only the liquidity family presents confidence ≥ 0.60 often enough to pass (verified in P6: 89.4% of the family sits exactly at 0.60).

### P3.5 Telemetry (S3, T01 family)

- `liquidityRaw/liquidityWeight/liquidityContribution` exist in the v3 header (`TYPES_T:75,92,105–106`) and are written via `SetComponent(COMPONENT_LIQUIDITY, ...)` (`TYPES_T:329`), driven by `cr.componentCount` (`TREQ:77–83`).
- **In the production rule path `m_latestConfluence.componentCount` is forced to 0** (`CE:299`) → the loop never runs → `liquidityRaw` stays 0.0 for **every** rule-path row (default `TYPES_T:276`). The evaluator path (only place that produces `COMPONENT_LIQUIDITY`) is test/benchmark-only.
- `TelemetryHealthReport::LegacyRowConsistent` (`THR:339–352`) *asserts* `liquidityRaw == 0` for v3 rows — the column is contractually dead.
- `layerLiquidity` (live): `signal.score.liquidity` → `TREQ:156` → `TCOLL:120`; values 0 or 30 (P6).
- `hasLiquiditySweep` (live): `CE:324` → `TREQ:166`; encoded `'1'`=FALSE, `'2'`=TRUE; **≡ `firedRuleId ∈ {5,6}` with zero mismatches** (P6) — redundant column, same pattern as `hasCHOCH` (CHOCH C5).
- `hasProtectedPoint` never TRUE in the dataset (P6) — re-confirms Swing S3 / T01.

### P3.6 Visualization (S5) — **no liquidity renderer exists**

- `VisualizationManager.mqh:35–52` wires Swing, Pivot, BOS, CHOCH, Protected, OB, FVG renderers. **No liquidity renderer** exists in `Visualization/` (no `LiquidityRenderer` file, no EQH/EQL drawing code anywhere). EQH/EQL levels, sweeps, mitigations are never drawn on chart.

---

## P3.7 Verification checklist

| # | Claim (from spec/doctrine) | Status | Evidence |
|---|---|---|---|
| V1 | EQH/EQL formed on swing points within tolerance | YES | `LQD:145–354`; tolerance 3 pips (`CONST:91–92`) |
| V2 | Cluster price is stable & deterministic | YES | rolling mean / midpoint; incremental, no repair |
| V3 | Sweep = any touch of the level (as specified) | YES | `LQD:428–437` — but that *is* the defect (S1) |
| V4 | Sweep requires close-back / reclaim | **FAIL** | no close-back anywhere in `LQD:404–483` or consumers |
| V5 | Sweep evaluated on **closed** bars | **FAIL** | `high[0]/low[0]` = forming bar (`LQD:428–437`) |
| V6 | Sweep requires displacement / MSS confirmation | **FAIL** | no displacement logic in subsystem (P3.1) |
| V7 | External HH/LL tracked | `%` | `LQD:356–402`; EXTERNAL_HH/LL only |
| V8 | Internal HH/LL invalidated | **FAIL** | invalidation covers EQH/EXTERNAL only (`LQD:573–576`) |
| V9 | Reset / reload lifecycle safe | **FAIL** | no shrink handler; E11 family (S2) |
| V10 | Raw quality evidence exported | **FAIL** | `liquidityRaw` const 0.0 (S3) |
| V11 | Unit tests exist | **FAIL** | none for detector (only evaluator tests in bench) |
| V12 | Levels rendered on chart | **FAIL** | no renderer exists (S5) |
| V13 | `classification` drives opposite-target selection | **FAIL** | never written (S4) |

---

## Findings

### S1 — Sweep confirmation absent (weakest-possible definition) — Very High

The detector equates *any forming-bar touch* with a *sweep*: `curHigh >= averagePrice` or `curLow <= averagePrice` on `high[0]/low[0]` (the still-forming candle) marks ACTIVE → SWEPT (`LQD:428–437`). No close-back-inside, no displacement, no time window, no confirmation on bar close.

- **Why it matters:** every surveyed tool (P2) and the academic branch (P1.2) define the *sweep event* as the reversal — somehow back inside after piercing. This implementation counts genuine breakouts and accidental touches as sweeps, so the "swept" population is diluted by non-events. Sprint 18.4 documented this exact weakness verbatim: *"the detector implements the weakest possible sweep definition (any touch beyond a level, evaluated on the forming bar, with no reclaim, no displacement, no time window)"* (`04_Liquidity.md:59–64`).
- **Evidence:** P6.1–P6.8: the family is the **worst of the five**; and its gate-admitted subset (0.3027) exactly replicates 18.8's 0.3027 family figure — both consistent with "sweep rows are mostly non-events".
- **Classification:** Implementation Defect. **Confidence:** Very High. **Destination:** Sprint 20 (E1): add close-back confirmation + closed-bar evaluation, measure in-family deltas on the frozen set.

### S2 — Reset / state-lifecycle defect (E11, 4th occurrence) — High

The liquidity detector has **no** `RatesTotalShrink` handler and advances four cursors monotonically; its feed (SwingDetector) is the only component that resets+rescans on chart reload (restarting swing ids at 1). After a reload, liquidity levels for the rescan are never rebuilt, and stored swing-id references collide with recycled ids. Consumers (`TCB:404–415`, `CE:422–443`) keep by-id references resolved against recycled ids.

- **Classification:** Implementation Defect. **Confidence:** High. **Destination:** Sprint 20 — the E11 **State Lifecycle Consistency** initiative already in the ledger; add liquidity to the audit list.

### S3 — Raw-evidence telemetry dead — Very High

`liquidityRaw/liquidityWeight/liquidityContribution` are constant 0.0 across all 17,073 decided+signal rows (P6). The only liquidity telemetry that survives to CSV is the `layerLiquidity` 0/30 flag and the redundant `hasLiquiditySweep` bit. **Sweep *quality* (level member count, sweep delay, distance beyond level, classification) is unmeasurable on the frozen set** — same pattern as Swing S3 / T01.

**Classification:** Measurement Gap. **Confidence:** Very High. **Destination:** Sprint 20/21 (E2; schema/M41 family, T01).

### L4 — `classification` never written → target degenerates — High

`LiquidityLevel.classification` is set `LIQUIDITY_CLASS_UNKNOWN` at create (`LQD:753`) and **never reassigned anywhere** (only reads at `LQD:627–628` and `TargetResolver.mqh:40,46`). Default target policy `TARGET_OPPOSING_LIQUIDITY` (`ExecutionPlan\Types.mqh:49–51`) relies on `classification OR swept`; since class is always UNKNOWN the `|| ll.swept` fallback always fires — the "opposite" target resolves to **the same swept level's price**, defeating the opposing-liquidity design (falls back to Fixed-RR when far).

**Classification:** Implementation Defect. **Confidence:** High. **Destination:** Sprint 20 (E3) — write classification on sweep (buy-side vs sell-side), telemetry the chosen target's side, verify it diverges from the swept level.

### L5 — No liquidity renderer — Medium

No `LiquidityRenderer` and no EQH/EQL drawing anywhere. Levels/sweeps/mitigations invisible on chart.

**Classification:** Missing Feature. **Confidence:** High (code absence verified). **Destination:** Sprint 20 (E6) — render EQH/EQL zones + sweep dots only after S1 fix (don't visualize unverified levels as signals).

### L1 — Fixed 3-pip tolerance vs ATR-adaptive norm — Medium

`LIQUIDITY_EQH_TOLERANCE_PIPS` = 3 (`CONST:91–92`) static; industry surveys use adaptive ATR tolerance or "obvious to the eye" equality (P2). No ATR anywhere in the subsystem (P3.1). On M15/H1, 3 pips is also essentially nothing for JPY pairs (≈0.3 pips at 100:1 scale vs pip = Point*10) → EQH/EQL cluster counts are probably under-formed.

**Classification:** Research Hypothesis. **Confidence:** Medium. **Destination:** M37 experiment (E4: ATR-scaled tolerance).

### F2 — `ll.price` vs `averagePrice` duality — Medium

Entry/stop resolve on `ll.price` (`EntryPriceResolver.mqh:50–63`), while sweep detection and telemetry operate on `averagePrice` (`LQD:428–437`). A level formed by midpoints of two swings carries a different price in each path; which field is canonical is undocumented.

**Classification:** Implementation Defect. **Confidence:** Medium. **Destination:** Sprint 20 cleanup (E5).

### F3 — `LIQUIDITY_MAX_LEVELS` (256) dead — Low

Never referenced; levels array is dynamic (`LQD:774`).

**Classification:** Implementation Defect. **Confidence:** High. **Destination:** Sprint 20 cleanup.

### F4 — Internal HH/LL never invalidated; Internal types possibly unused — Medium

Invalidation only EQH/EXTERNAL_HH and EQL/EXTERNAL_LL (`LQD:573–576`); INTERNAL_HH/LL neither created by the detector itself nor serviced by the invalidation path. Where decides between INT/EXT? Unverified origin.

**Classification:** Missing Feature / spec gap. **Confidence:** Medium. **Destination:** research backlog (E7).

<!-- PART3 -->

---

## P4a. Algorithm correctness score — 62/100

| Capability | Score | Basis |
|---|---|---|
| Level formation (EQH/EQL, external) | 85 | deterministic, incremental, tolerance-based (P3.1) |
| Sweep event correctness | 35 | weakest-possible definition; forming-bar touch; no reclaim (S1) |
| Lifecycle state machine | 70 | gates correct; reset unsafe (S2) |
| Consumer wiring (rules, entry, target) | 55 | rule path live; target degenerates (L4) |
| Config hygiene | 60 | dead constants (F3); dead input `LIQUIDITY_MAX_LEVELS` |

## P4b. Visualization — 0/100

No renderer exists (S5). Nothing to verify.

---

## P5. Pipeline questions (wiring is real, quality is not)

1. **Does the liquidity pointer reach production context?** YES — `context.liquidityDetector` set at `CE:523`.
2. **Do liquidity rules reach the entry gate?** YES — confidence-only validator (`ConfluenceValidator.mqh:23–47`); no ruleName gate; AND the family's confidence sits exactly at 0.60 (P6.3) → 89.4% of the family is admitted. This is the *empirical* meaning of 18.9's "gate admits the worst family".
3. **Which rule family dominates the live-decision funnel?** LIQUIDITY_BOS: n=3,553 (20.8% of signals) — second-largest after BOS+OB (25.8%), and the worst (P6.1).
4. **Can sweep quality be measured at all on the frozen set?** NO for per-level attributes (S3). Only presence (`layerLiquidity` 0/30) and the family split are measurable.
5. **What breaks first downstream?** L4-target degeneracy (opposing liquidity points at the swept level) and S2-id recycling (stale candidates) are the two live-path risks.

---

## P6. Evidence — Sprint 17 frozen set (read-only analysis)

Universe: 18,686 rows (68 cols, UTF-16, v3), decided+signal n=17,073, base wr 0.3321.

```
=== LIQUIDITY BOS family (firedRuleId 5|6); decided+signal universe n=17073, base wr=0.3321 ===
family n=3553 (20.8% of signals)  wr=0.2967  meanR=-0.1179  medianR=-1.0000  medBars=4.0

hasLiquiditySweep='2' rows: n=3553 (ratio vs family = 1.000; mismatches = 0)

direction split:  BULLISH n=1853 wr=0.2822 meanR=-0.1579 | BEARISH n=1700 wr=0.3124 meanR=-0.0742
rule 5 LIQUIDITY_BOS_BULLISH: n=1853 wr=0.2822 | rule 6 LIQUIDITY_BOS_BEARISH: n=1700 wr=0.3124

raw evidence columns: liquidityRaw/liquidityWeight/liquidityContribution unique=1 (const 0.00)
layerLiquidity : unique=2 {0,30}, mean=6.243 ; share==0 : 79.19%, share>0 : 20.81%
ALL rows: ll>0 n=3553 wr=0.2967 | ll=0 n=13520 wr=0.3414  (ll>0 == family exactly)

confidence gate: conf 0.55 n=375 wr=0.2453 ; conf 0.60 n=3178 wr=0.3027
ADMITTED (conf>=0.60): n=3178 (89.4%) wr=0.3027  <-- EXACT match to 18.8 family figure (0.3027)
GATED (conf<0.60):     n= 375 (10.6%) wr=0.2453

cells: EURUSD M15 n=2256 wr=0.2912 | EURUSD H1 n=693 wr=0.2929 | GBPJPY H1 n=604 wr=0.3212
  admitted-only cells: EURUSD M15 n=2041 wr=0.2950 | EURUSD H1 n=608 wr=0.3059 | GBPJPY H1 n=529 wr=0.3289

hours: h00-07 0.3010 | h08-12 0.2923 | h13-17 0.3175 (best) | h18-21 0.3076 | h22-23 n=255 wr=0.2000 (drain)
dow: Mon 0.2712 | Tue 0.3194 | Wed 0.3314 (best) | Thu 0.2793 | Fri 0.2812

co-occurrence within family: hasBOS=TRUE 3553/3553; hasOB=TRUE 0; hasFVG=TRUE 0; hasCHOCH 0; hasProtectedPoint=TRUE 0
across ALL decided rows (n=18536): hasProtectedPoint='2' count = 0  ('1' = 18536)
outcomeSource: '1' (paper) 3553; exitReason: '2' n=2481, '1' n=1021, '4' n=51
trendAligned: '2' (TRUE) n=3178 conf=0.60 wr=0.3027 | '1' (FALSE) n=375 conf=0.55 wr=0.2453
confidence↔ruleConfidence pairs: (0.55,0.80),(0.55,0.90),(0.60,0.85),(0.60,0.95)
layerTotal: 60 n=3178 | 55 n=375
```

### P6.1 Family size and headline

LIQUIDITY_BOS n=3,553 (20.8% of signals), **wr 0.2967 vs base 0.3321** (−3.5pp), meanR −0.118, medianR −1.0, median bars 4. **Worst of the five rule families; second-largest by share.** The bearish half (0.3124) beats the bullish half (0.2822) by +3pp.

### P6.2 18.8 replication — EXACT

The 18.8 family figure 0.3027 matches the **gate-admitted subset** (conf ≥ 0.60, n=3,178) exactly — 0.3027. The overall family is slightly worse (0.2967). Interpretation: 18.8 measured the effectively-live subset (the confidence gate), not the raw family.

### P6.3 The confidence gate empirically admits the worst family

89.4% of the family sits exactly at conf 0.60 (trendAligned TRUE) and is admitted; 10.6% at conf 0.55 (trend not aligned) is gated. The gated tail is *worse* (0.2453) — so within the family the gate filters correctly — but the *entire* family is the worst family, so the gate admits mass low-quality rows. The 18.9 "per-family gate thresholds" recommendation (E1) is exactly on target; a tighter per-family min (e.g., 0.75) would nearly kill the whole family.

### P6.4 Session & day structure

- **h22–23 drain replicates across all three documented families**: BOS 0.2156 (doc 01), CHOCH 0.1667 (doc 02), Liquidity 0.2000 — consistent session effect (three families, independent detectors).
- **Best session** h13–17 0.3175; h00–07 0.3010 (London keep). Monday worst (0.2712), Wednesday best (0.3314) — **opposite** of CHOCH-family Monday spike (0.5385) — day-of-week effect is family-dependent.

### P6.5 Structure of the family

- Exclusively BOS+Liquidity (hasBOS TRUE, hasOB/FVG/CHOCH/PP all FALSE) — mutually exclusive best-rule encoding, same as other families.
- **`layerLiquidity` uniquely 0 or 30**: the layer score does not discriminate within the family (all swept rows = 30) — no quality gradation.
- **All rows are paper** (`outcomeSource='1'`); exits RT 2 (TP) 2,481, SL 1,021, time 51 — about 70% of decided exits used TP.

### P6.6 Co-occurrence / confounds

- `hasLiquiditySweep` ≡ `firedRuleId ∈ {5,6}` with zero mismatches — column is redundant (same pattern as `hasCHOCH`).
- 0 rows anywhere where `hasProtectedPoint='2'` (n=18,536 decided) — re-confirms T01 blind spot (PP never reaches the dataset).
- No per-row sweep-distance/delay evidence exists (S3).

<!-- PART4 -->

---

## P7. Experiments (falsifiable, frozen-set first)

| ID | Question | Rationale | Primary test | Easiest falsification |
|---|---|---|---|---|
| E1 | Does close-back confirmation + closed-bar evaluation separate winning sweeps from noise? | S1: the touch-based population is diluted; P2/P1.2 say reclaim defines the event | Recompute sweep rows: keep only rows where a closed bar pierced AND the next bar closed back inside (on the frozen OHLC timeline, paper) — then compare wr | In-family wr with confirmation ≤ 0.2967 (no lift from confirmation) |
| E2 | Can sweep quality be measured after instrumenting raw columns? | S3: `liquidityRaw` const 0; level attributes (delay, distance, member count) unavailable | Ship telemetry (schema v3.1/M41 family), re-run E1 on fresh data; report delay/distance distributions vs outcome | Distributions show no relationship with outcome in-sample |
| E3 | Does writing `classification` fix the opposing-target degeneracy? | L4: target always resolves to the swept level | Unit test: swept sell-side level must map to a buy-side target different from the level | Target side == swept level side in ≥95% of cases after fix |
| E4 | Is 3-pip tolerance materially under-forming EQH/EQL? | L1: ATR-adaptive norm; 3 pips ~ nothing on JPY | ATR-scaled tolerance (0.5×ATR) paper experiment on frozen OHLC | Level count and family wr unchanged vs 3-pip baseline |
| E5 | Does per-family gate threshold protect the live funnel? | P6.3: gate admits 89.4% of the worst family; 18.9 E1 | Simulate minConfidence ∈ {0.60, 0.70, 0.75, 0.80} for LIQUIDITY_BOS on frozen set; report admitted n/wr each | No config admits a LIQUIDITY subset with wr ≥ base 0.3321 |
| E6 | Does a liquidity renderer change nothing but understanding? | S5: levels invisible | Implement renderer post-E1; verify chart parity with detector state | n/a (visual) — success = no logic change |
| E7 | Are INTERNAL HH/LL ever formed/invalidated? | F4: spec gap | Code audit + telemetry probe for level types in fresh run | No INTERNAL_* level in 1 month of paper data |

---

## Proof Matrix (verification of verification)

| Statement | Doctrine | Code | Data | Status |
|---|---|---|---|---|
| "Sweep = any touch, forming bar" | n/a (anti-norm) | YES (`LQD:428–437`) | family wr 0.2967 — worst family | **True — and it is the defect** |
| "Confirmation/reclaim needed" | YES (P2 corpus) | NO | n/a | **Falsified for this implementation** |
| "Liquidity family is worst" | 18.8 0.3027 | n/a | family 0.2967; gate subset 0.3027 EXACT | **Proven** (18.8 replication) |
| "Gate admits the liquidity family" | 18.9 | confidence-only validator | 89.4% at conf 0.60 admitted | **Proven** |
| "Sweep quality measurable" | telemetry spec | raw const 0 (`CE:299`) | unique=1 across 17,073 rows | **Falsified — measurement gap** |
| "Levels visible on chart" | visualization spec | no renderer | n/a | **Falsified — missing feature** |
| "Opposing-liquidity target" | doctrine + `TARGET_OPPOSING_LIQUIDITY` | classification never written | n/a | **Likely degenerate** (code-verified) |

## Traceability

| Claim | Section |
|---|---|
| Sweep definition weakness → S1 | P1.1, P2, P3.1, P3.7 (V3–V6) |
| Reset lifecycle → S2 (E11) | P3.3, ledger E11 |
| Telemetry dead → S3 (T01) | P3.5, P6.5 |
| Classification dead → L4 | P3.4, P3.7 (V13) |
| No renderer → S5 | P3.6 |
| Family performance & gate → P6.1–P6.6 | 18.8, 18.9, ledger R03/C08 |

## Findings Summary (consolidated — Confidence × Destination × Classification)

| Finding | Confidence | Destination | Classification |
|---|---|---|---|
| S1 Sweep confirmation absent (touch-only, forming bar) | Very High | Sprint 20 (E1) | Implementation Defect |
| S2 Reset/lifecycle unsafe — E11 4th occurrence | High | Sprint 20 (E11 initiative) | Implementation Defect |
| S3 Raw-evidence telemetry dead (liquidityRaw const 0) | Very High | Sprint 20/21 (E2, T01) | Measurement Gap |
| L4 `classification` never written → target degenerates | High | Sprint 20 (E3) | Implementation Defect |
| S5 No liquidity renderer | High | Sprint 20 (E6) | Missing Feature |
| L1 Fixed 3-pip tolerance vs ATR norm | Medium | M37 (E4) | Research Hypothesis |
| F2 `ll.price` vs `averagePrice` duality | Medium | Sprint 20 (E5) | Implementation Defect |
| F4 INTERNAL HH/LL lifecycle open | Medium | Research backlog (E7) | Missing Feature |
| F3 `LIQUIDITY_MAX_LEVELS` dead | High | Sprint 20 cleanup | Implementation Defect |
| P6.3 Gate admits worst family (0.3027) | High | M15 gate experiment (E5) | Research Hypothesis |

## Scorecard

| Dimension | Score | Basis |
|---|---|---|
| Research alignment | 80/100 | Osler/Kavajecz/Kaminski anchor the premise; doctrine unanimity on confirmation |
| Algorithm correctness | 62/100 | deterministic levels; weakest sweep event; forming-bar |
| Visualization | 0/100 | no renderer exists |
| Pipeline integrity | 72/100 | wiring real; target degeneracy; gate admits worst family |
| Evidence quality | 55/100 | family stats solid; exact 18.8 replication; raw quality unmeasurable |
| Maintainability | 60/100 | dead constants; F2 duality; E11 family |
| **Overall** | **64/100 — IMPROVE** | |

## Final Verdict — Improve

**What is solid:** the level *formation* machinery (deterministic, incremental, tolerance-based), the life-cycle gates, and the fact that the family's gate-admitted population reproduces 18.8's 0.3027 *exactly* — the verification pipeline itself is trustworthy.

**What must change before any liquidity experiment ships:** S1 (confirmation + closed-bar evaluation — the single highest-leverage fix, aligned with universal doctrine), S2 (E11 lifecycle), L4 (classification → target), S3 (telemetry raw columns so quality becomes measurable).

**What the evidence says about the family:** LIQUIDITY_BOS is the worst family (−3.5pp vs base) *and* the one the live gate actually admits (89.4%). Without confirmation, "sweep" rows are mostly non-events; without telemetry, we cannot tell the good sweep from the noise. Do not tune entry parameters for this family — fix the event definition first, then re-measure.
