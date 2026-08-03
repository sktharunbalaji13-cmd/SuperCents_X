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

## Registered issues

| ID | Issue | Type | Found in | Priority | Destination |
|---|---|---|---|---|---|
| E11 | **Reset / state-lifecycle defect family** — on `rates_total` shrink, detectors clear/restart identity (IDs back to 1) but downstream consumers keep stale cursors → structure pipeline stalls silently | Implementation Defect | BOS C3; CHOCH C2; Swing S2 | **P0** | Sprint 20 **State Lifecycle Consistency** initiative: audit init, reset, history reload, chart refresh, timeframe change, EA restart across every detector |
| T01 | **Structural raw-evidence telemetry inert** — `structureRaw`/`structureContribution`/`structureWeight` + all layer raws = 0.00 in 100% of 17,073 rows; `hasProtectedPoint` never TRUE in 18,536 rows | Measurement Gap | Swing S3 (affects BOS/CHOCH evidence too) | **P0** | Sprint 20/21 telemetry (Swing E5, M41 schema v3.1) |
| T02 | **No unit tests on any structure subsystem** — Swing/Pivot/BOS/Trend/PP/CHOCH logic uncovered; correctness rests on forensic-only evidence | Measurement Gap | BOS C6; CHOCH C1; Swing F6 | **P0** | Sprint 20 test scaffold (regression for every P0 fix) |
| C01 | **Dead production code path** — Premium/Discount evaluator: `DetectionContext.swingHigh/swingLow` never populated at runtime → always InvalidRange=0 | Implementation Defect | Swing S1 | **P0** | Sprint 20 wiring fix + unit test (Swing E3) |
| C02 | **Cold-start misattribution** — first-crossing bar not recorded; on backfill/cold start the event is attributed to the current bar | Implementation Defect | BOS C2; CHOCH C6 | **P0** | Sprint 20 (BOS E8); shared with E11 audit |
| C03 | **Missing bearish CHoCH rule** — `RuleCHOCH_OB_Reversal` is bullish-only; all 342 rows bullish; bearish branch never exercised | Missing Feature | CHOCH C3 | P1 | Sprint 20 (CHOCH E2) or explicit scope decision |
| C04 | **Array-orientation contract** — swing stage consumes chronological arrays while docs declare series convention (index 0 = newest) | Architectural Limitation | BOS C1; Swing F7 | P1 | Sprint 20: define orientation contract once; doc fix |
| C05 | **Dead fields / redundant telemetry** — `StructuralPivot.isBroken` never read; `hasCHOCH` ≡ ruleName; `SWING_STRENGTH`/`SWING_LOOKBACK_BARS` never read; pivot timing logged under MODULE_SWING_DETECTOR | Implementation Defect | BOS C5; CHOCH C5; Swing F4+F8 | P2 | Sprint 20 cleanup |
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