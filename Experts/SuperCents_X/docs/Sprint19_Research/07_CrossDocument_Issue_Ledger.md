# Cross-Document Issue Ledger — Sprint 19 AVP

Living register of every finding across the AVP series (docs 01-06).
Purpose (per user direction, 2026-08-03): prevent duplicate
engineering work across subsystems and hand Sprint 20 a **single
consolidated engineering backlog** instead of isolated findings.

Maintenance rule: updated after **every** AVP doc (appended rows, no
deletions except for a "RESOLVED/DEFERRED" status annotation).
Classification type follows AVP v1.0 §4.13(c): Implementation Defect /
Missing Feature / Architectural Limitation / Measurement Gap /
Research Hypothesis.

Priority scale:
- **P0** — blocking: decision-quality defect, dead path, or
  evidence-impossible gap; must land in Sprint 20.
- **P1** — important engineering/research token; Sprint 20 if cheap,
  else M-card.
- **P2** — experiment or cleanup; backlog.
- **P3** — cosmetic / documentation.

---

## Legend: finding codes used by the docs

| Family | Meaning |
|---|---|
| E11 | Reset / state-lifecycle defect family (chart reset, history reload, EA restart) |
| T0x | Telemetry / instrumentation gaps (evidence cannot be produced) |
| C0x | Production code paths that are dead, redundant or contradictory |
| R0x | Research gaps (features industry/evidence says we lack; open experiments) |

---

## Sprint 20 Epic Groups (added 19.4)

Cross-cutting groupings so Sprint 20 plans epics, not dozens of isolated fixes.

| Epic | Includes | Work item shape |
|---|---|---|
| **LC — Lifecycle & Reset** | E11 family (BOS, CHOCH, Swing, Liquidity) | Define a common lifecycle contract (init / reset / history reload / chart refresh / TF change / EA restart); one audit that every detector must satisfy |
| **TC — Telemetry Completeness** | T01 (raw raws 0.00), T02 (no unit tests), has* flag redundancy, M41 schema appends | Make every detection persist raw evidence; establish baseline + CI for "evidence reachable" per component |
| **DD — Dead / Disconnected Logic** | C01 (PD evaluator dead), C10 (classification never written), C09 (sweep confirmation absent), C02 (cold start), C03 (bullish-only CHoCH), C08 (entry unreachability) | Re-verify each dead path as a wiring fix; add unit test per fix |
| **ED — Event Definition Refinement** | Liquidity E1 sweep confirmation, planned OB/FVG confirmation tightening | Paper-first experiments that re-define the *event* without touching entry machinery, on the frozen set |
| **VF — Visualization Framework** | S5 (no liquidity renderer), visual consistency checks, palette drift C07 | Renderer for every detector + parity check against detector state (like swingForensic) |

---

## Registered issues

| ID | Issue | Type | Found in | Priority | Destination |
|---|---|---|---|---|---|
| E11 | **Reset / state-lifecycle defect family** — on `rates_total` shrink, detectors clear/restart identity (IDs back to 1) but downstream consumers keep stale cursors → structure pipeline stalls silently | Implementation Defect | BOS C3; CHOCH C2; Swing S2; Liquidity S2; **OrderBlocks S2 (LATENT — downstream of CHOCH cursor)**; **FVG S7 (PARTIAL — only detector with a time-discontinuity reload path; `rates_total` shrink without time reversal still unhandled)** | **P0** | Sprint 20 **State Lifecycle Consistency** initiative: audit init, reset, history reload, chart refresh, timeframe change, EA restart across every detector |
| T01 | **Structural raw-evidence telemetry inert** — `structureRaw`/`structureContribution`/`structureWeight` + all layer raws (incl. `liquidityRaw`, `obRaw`, **`fvgRaw`**) = 0.00 in 100% of 17,073 rows; `hasProtectedPoint` never TRUE in 18,536 rows; **OB has no `layerOrderBlock` column; FVG has no `layerFVG` column (only `hasFVG` bit)**; FVG size/strength/class computed but never serialized (4th family, worst case) | Measurement Gap | Swing S3; Liquidity S3; OrderBlocks S2; **FVG S1** (affects BOS/CHOCH evidence too) | **P0** | Sprint 20/21 telemetry (Swing E5, M41 schema v3.1) — **RESOLVED — TC01 (schema v3.1, v4/75 columns) + TC02 (2026-08-03: raw evidence wired at decision time — rule path `BuildRuleComponents`, evaluator path preserved, engine-unsettled rows keep all-zero split; real-run verification 500/500 split-consistent, health PASS, behavioral delta nil, suite 1037/1037)** |
| T02 | **No unit tests on any structure subsystem** — Swing/Pivot/BOS/Trend/PP/CHOCH logic uncovered; correctness rests on forensic-only evidence | Measurement Gap | BOS C6; CHOCH C1; Swing F6 | **P0** | Sprint 20 test scaffold (regression for every P0 fix) |
| C01 | **Dead production code path** — Premium/Discount evaluator: `DetectionContext.swingHigh/swingLow` never populated at runtime → always InvalidRange=0 | Implementation Defect | Swing S1 | **P0** | Sprint 20 wiring fix + unit test (Swing E3) |
| C02 | **Cold-start misattribution** — first-crossing bar not recorded; on backfill/cold start the event is attributed to the current bar | Implementation Defect | BOS C2; CHOCH C6 | **P0** | Sprint 20 (BOS E8); shared with E11 audit |
| C03 | **Missing bearish CHoCH rule** — `RuleCHOCH_OB_Reversal` is bullish-only; all 342 rows bullish; bearish branch never exercised | Missing Feature | CHOCH C3 | P1 | Sprint 20 (CHOCH E2) or explicit scope decision |
| C04 | **Array-orientation contract** — swing stage consumes chronological arrays while docs declare series convention (index 0 = newest) | Architectural Limitation | BOS C1; Swing F7 | P1 | Sprint 20: define orientation contract once; doc fix |
| C05 | **Dead fields / redundant telemetry** — `StructuralPivot.isBroken` never read; `hasCHOCH` ≡ ruleName; `hasLiquiditySweep` ≡ `firedRuleId∈{5,6}`; `SWING_STRENGTH`/`SWING_LOOKBACK_BARS` never read; `LIQUIDITY_MAX_LEVELS` never read; pivot timing logged under MODULE_SWING_DETECTOR | Implementation Defect | BOS C5; CHOCH C5; Swing F4+F8; **Liquidity F3** | P2 | Sprint 20 cleanup |
| C06 | **O(B) per-bar history rescan** in BOSDuplier; O(E) duplicate scan in CHOCH — minor perf | Architectural Limitation | BOS C4 | P3 | Sprint 20 refactor (low impact) |
| R01 | **Swing significance filter** — any 5-bar wiggle is a swing; industry norm is ATR/prominence/persistence gating | Missing Feature | Swing F3 | P1 | M37 (18.1 E1) |
| R02 | **Displacement / MSS confirmation layer** — no sweep/displacement/FVG check before calling a break "confirmed"; ICT MSS delta not implemented | Missing Feature | BOS E1; CHOCH C4 | P1 | M30 (18.1 E1); label discipline in Sprint 20 |
| R03 | **Session structure** — h22-23 drain (BOS 0.2156, CHOCH 0.1667); h08-12 holds (CHOCH 0.5417); GMT hour optimal | Research Hypothesis | BOS P6; CHOCH P6 | P1 | M06 session gate experiment |
| R04 | **GBPJPY H1 replication** — only exact 18.11 cell (n=63, wr 0.5397, meanR +0.579) re-run on the frozen set | Research Hypothesis | BOS P6 | P1 | M02/M04 walk-forward replication (CHOCH E5) |
| R05 | **Retest/acceptance requirement** — no retest telemetry; retest-and-hold lifts hit rate per practitioners | Research Hypothesis | BOS E2; Swing SL-F5 | P2 | E2 telemetry-first experiment |
| R06 | **Volume confirmation** — no volume column; Wyckoff/ATAS doctrine says mandatory | Research | BOS P6 (Low conf) | P2 | Research backlog; gated on schema v3.1 |
| R07 | **Equal-high/low policy** — strict exclusion vs collapse-to-extreme (smtlab) vs ATR-tolerance (Lux); EQ-levels invisible to structure | Research | BOS E9; Swap SL-F2 | P2 | M37 experiment |
| R08 | **Monday effect drift** — Monday wr 0.539 vs Wed/Thu 0.26 (CHOCH) | Research Hypothesis | CHOCH P6 | P2 | M06 replication first |
| R089 | **MTF swing alignment (STH/ITH/LTH)** — no multi-TF tier geometry | Missing Feature | Swing E7 | P2 | 18.1 E3 |
| C07 | **Palette drift** — spec frozen #996B00 / hist #593E00 vs code #808080/#606060 (CHOCH renderer) | Implementation | CHOCH P4b | P3 | Sprint 20 cosmetic |
| C08 | **Entry unreachability** — ConfluenceValidator admits only LIQUIDITY_BOS; CHOCH_OB & others never reach the entry path (paper-only rows) | Implementation Defect | CHOCH P5 | P0 | Sprint 20 scope decision before any context experiment ships |
| C09 | **Sweep confirmation absent** — any forming-bar touch = sweep (`high[0]` ≥ avg); no close-back, no displacement, no closed-bar eval; verified verbatim vs 18.4 "weakest possible definition"; family is worst (−3.5pp) | Implementation Defect | Liquidity S1 (18.4 §1.3) | **P0** | Sprint 20 E1: confirmation + closed-bar evaluation, re-measure in-family |
| C10 | **`classification` never written** — `LiquidityLevel.classification` ≡ UNKNOWN (`LQD:753`); `TARGET_OPPOSING_LIQUIDITY` resolves to the same swept level via `\|\| ll.swept` fallback | Implementation Defect | Liquidity L4 | P0 | Sprint 20 E3: write side-class on sweep; telemetry target-side; unit test |
| C11 | **No liquidity renderer** — VisualizationManager wires 7 renderers, none for EQH/EQL; levels/sweeps never drawn | Missing Feature | Liquidity S5 | P1 | Sprint 20 E6 (post-E1) |
| R11 | **Per-family gate threshold** — gate (conf-only, min 0.60) admits 89.4% of the worst family; admitted subset = 0.3027 EXACT 18.8 replication; per-family min would nearly kill LIQUIDITY_BOS | Research Hypothesis | Liquidity P6.3; 18.9 E1 | P1 | M15 gate experiment (E5) |
| R12 | **ATR-scaled EQH/EQL tolerance** — 3 pips static (≈0.3 pip on JPY) vs ATR-adaptive industry norm; under-forms clusters | Research Hypothesis | Liquidity L1 | P2 | M37 experiment (E4) |
| C12 | **No displacement/BOS gate on OB creation** — any CHOCH spawns an OB scan; no body/wick/ATR filters (only doji skip); doctrine: "without displacement the candle is just a swing" | Implementation Defect | OrderBlocks S1 | **P0** | Sprint 20 E1: displacement gate (body ≥1.5×avg, wick <0.2, BOS), paper-first |
| C13 | **OB raw evidence structurally unmeasurable** — `obRaw` const 0.00 AND **`layerOrderBlock` column does not exist in schema** (worst T01 case; OB has neither raw nor layer column, only the `hasOrderBlock` bit) | Measurement Gap | OrderBlocks S2 | **P0** | Sprint 20/21 E2/schema v3.1: add `layerOrderBlock`; TC epic — **RESOLVED — TC01 (schema v3.1, v4/75 columns: `layerOrderBlock` + `layerFVG` serialized from the score split; M1 gate passed)** |
| C14 | **Stale zones** — 500-bar scan window + no rule-path recency filter (`ActiveOB` unlimited); freshness only in dead evaluator path | Implementation Defect | OrderBlocks S3 | P1 | Sprint 20 E3: rule-path recency gate |
| C15 | **Wick-touch mitigation** — `close[1]` touching zone = mitigated; doctrine: wick ≠ mitigation, body close only | Implementation Defect | OrderBlocks S4 | P1 | Sprint 20 E4: body-close mitigation |
| R13 | **Gate reversal (entry funnel runs the worst family)** — 0/13,178 OB rows (wr 0.3410) admitted by conf≥0.60 gate; Liquidity 89.4% admitted (0.3027); **FVG 0/12,320 admitted (max conf 0.40 — structurally un-enterable, 3rd family)**; live funnel = weakest family. Config change flips everything | Research | OrderBlocks S5; **FVG S2** (18.9 E1) | **P0** | Sprint 20 E5 / M15: per-family gate thresholds |
| R14 | **OB_FVG_BULLISH largest-and-worst rule** — n=6,412 (37.6% of ALL signals) wr 0.3036 vs bearish mirror 0.3769 (+7.3pp, same machinery); BOS_OB 0.3730 (+3.4pp over OB_FVG) | Research Hypothesis | OrderBlocks F1/F2; FVG P6.5 (corrected: asymmetry is cell-dependent, flips at GBPJPY +6.8pp) | P1 | M-card E6/E7 decomposition |
| C16 | **FVG classifier dead end** — size/strength/class computed (SMALL/MEDIUM/LARGE, WEAK/NORMAL/STRONG, REVERSAL/BREAKAWAY/CONTINUATION) but never serialized nor consumed by decision layer; `qualityScore` forced 1.0; `chochId` forced −1 | Implementation Defect | FVG S1 (F14/F15) | **P0** | Sprint 20 TC epic: serialize classification + gap timestamps (also unblocks E1/E2 tests) — **PARTIALLY RESOLVED — TC01 (schema v3.1 serializes `fvgClass/fvgSize/fvgStrength/fvgCreatedTime/fvgFillTime` with defined defaults UNKNOWN/0; classifier population intentionally deferred to TC04)** |
| C17 | **UntouchedFVG rule path unguarded** — no recency filter AND no `isFilled`/`isInvalidated` guard (RULES:125-147); filled, invalidated and 500-bar-old gaps still match; invalidation exists only as trend-opposition, no time expiry | Implementation Defect | FVG S4 (F16/F17/F13) | P1 | Sprint 20: recency + unmitigated guard (same family as C14) |
| C18 | **Gap-size filter on the wrong candle** — 5-pip body min applied to candles A and C (`FVG:179,193-200`); displacement candle B never checked (doctrine: B is the imbalance); gap itself needs only 0.1 point | Implementation Defect | FVG S6 (F3/F2) | P2 | Sprint 20/21: move min-body gate to candle B (E2) |
| R15 | **Trend-alignment bonus value-negative** — bonus rows (lc=15) 0.3339 vs non-bonus (lc=10) 0.3517 (−1.8pp); harm concentrated in BEARISH 0.3643 vs 0.4103 (−4.6pp) — the exact rule carrying the family edge; bonus has zero admission effect (conf never ≥0.60) | Research Hypothesis | FVG S3 (P6.4) | P2 | Sprint 20 M-card: remove/adjust OB_FVG trend bonus, re-measure (E3) |
| R16 | **Direction asymmetry is cell-dependent, not global** — EURUSD BULL weak (M15 0.2942, H1 0.2674) vs BEAR strong (0.3896, 0.3858); GBPJPY flips (BULL 0.3653 vs BEAR 0.2974); doc 05 "bullish weak" was a EURUSD artifact | Research Hypothesis | FVG S5 (P6.5) | P2 | Sprint 21 experiment (E5), month-split for stability |
| R17 | **BULL h22-23 drain 0.2000** — exact match to Liquidity family value; 4th family replication of the h22-23 drain (BOS, CHOCH, Liquidity, FVG); bullish-specific in FVG (BEAR h22-23 0.3512 unaffected) | Research Hypothesis | FVG F1 (P6.6) | P2 | M06 session-gate experiment (extends R03) |