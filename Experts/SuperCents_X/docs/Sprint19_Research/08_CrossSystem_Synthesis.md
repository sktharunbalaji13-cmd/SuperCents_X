# 08 — Cross-System Synthesis & Sprint 20 Plan (AVP Sprint 19 close)

| Field | Value |
|---|---|
| Document | `08_CrossSystem_Synthesis.md` |
| Series | AVP Sprint 19 (docs 00–08), methodology v1.0 (frozen) |
| Passports | 01 BOS **72** · 02 CHOCH **74** · 03 Swing **67** · 04 Liquidity **64** · 05 OrderBlocks **66** · 06 FVG **70** |
| Ledger | `07` — **39 rows**: E11 + T01/T02, C01–C18, R01–R17 + R089, grouped in 5 epics (LC/TC/DD/ED/VF) |
| Purpose | User direction (2026-08-03): produce **one** synthesis before Sprint 20; Sprint 20 opens with **platform engineering**, not detector redesign |
| Evidence | Frozen Sprint 17 set, n=17,073 decided+signal, base wr 0.3321 (all docs) |

---

## S1. Matrix — Subsystem × Algorithm × Implementation × Telemetry × Pipeline × Priority

| Subsystem | Doc (passport) | Algorithm (doctrine conformance) | Implementation | Telemetry (measurable) | Pipeline (reaches live entry) | Sprint 20 priority |
|---|---|---|---|---|---|---|
| **BOS** | 01 (72) | ✅ close-based break, 5-fractal standard | ⚠ C02 cold-start misattribution (P0); C06 O(B) perf (P3) | ⚠ raw const 0.00 (T01); hasProtectedPoint never | ⚠ BOS_OB paper-only — entry unreachable (C08) | P1 |
| **CHOCH** | 02 (74) | ✅ close-break semantics | ⚠ C03 bearish rule missing (P1); C02; C07 palette (P3) | ⚠ raw const 0.00 (T01) | ⚠ CHOCH_OB never entered (C08) | P1 |
| **Swing** | 03 (67) | ✅ 5-bar fractal core untouched, deterministic, no repaint | ⚠ C01 PD evaluator dead (P0); S2 reset desync (E11, 3rd member) | ❌ all raws 0.00; `hasProtectedPoint` never TRUE in 18,536 rows (T01 worst) | ⚠ S2 — pipeline stalls silently after reset | **P0** (C01/E11) |
| **Liquidity** | 04 (64) | ⚠ weakest-possible sweep definition (C09 P0) | ⚠ C10 `classification` never written (P0) | ❌ `liquidityRaw` const 0.00, unique=1 (T01) | ⚠ **ONLY family admitted (89.4%) — the worst family is the live funnel** | **P0** |
| **Order Block** | 05 (66) | ⚠ no displacement/BOS gate (C12 P0); C15 wick mitigation | ⚠ C14 stale zones (P1); C15 (P1) | ❌ `obRaw` const 0.00 **and no `layerOrderBlock` column** (C13, worst T01) | ❌ gate reversal — **0/13,178 admitted** (R13) | **P0** |
| **FVG** | 06 (70) | ✅ wick-to-wick core correct; ⚠ C18 wrong-candle filter; ✅ best-in-class reload (S7) | ⚠ C16 classifier dead end (P0); C17 unguarded rule path (P1) | ❌ `fvgRaw` const 0.00, no `layerFVG`, classifier never serialized (T01, 4th family) | ❌ gate reversal — **0/12,320 admitted** (R13) | **P0** |

### Reading the matrix

- **Algorithm column is healthy.** 5/6 components implement the doctrinal core correctly (close-breaks, fractal, wick-to-wick). The series found **zero core-detector P0s** except Liquidity's weakest-sweep (C09), which is a definition/wiring fix, not a rewrite.
- **Telemetry column is the single system failure.** Every raw is 0.00; 4 of 6 layer columns exist (structural/liquidity/confirmation/total) but **2 are missing entirely** (order block, FVG); the only ever-TRUE `has*` flag is `hasOrderBlock` (≡ rule 1|2|3|4). AVP Evidence scores (52–58) are capped by this, not by the evidence work itself.
- **Pipeline column shows funnel inversion (R13).** The gate admits 89.4% of the *worst* family and 0% of two *better* families. A config-level change flips everything — the highest-leverage item in the whole series.

## S2. Cross-cutting evidence facts (now replicated across families)

| Fact | Where | Values | Ledger |
|---|---|---|---|
| h22-23 drain | 4 families | BOS 0.2156 · CHOCH 0.1667 · Liquidity 0.2000 · **FVG BULL 0.2000** (bullish-specific in FVG; BEAR unaffected) | R03/R17 |
| Best window | FVG + OB | h18-21 FVG 0.3714; **BEAR h18-21 0.4891 — strongest cell in dataset** | F2 (doc 06) |
| Gate admission | all | Liquidity **89.4%** · OB **0%** · FVG **0%** · CHOCH_OB never entered (C08) | R13 |
| Direction asymmetry | OB_FVG | EURUSD BULL weak (−9.5pp M15, −11.8pp H1) vs BEAR strong; **GBPJPY flips** (BULL +6.8pp) — cell-dependent, not global | R14/R16 |
| Trend bonus | OB_FVG | bonus rows 0.3339 vs 0.3517 (−1.8pp); harm in BEARISH 0.3643 vs 0.4103 (−4.6pp); zero admission effect | R15 |
| Rule rank | OB family | BOS_OB 0.3730 > CHOCH_OB 0.3567 > OB_FVG 0.3388 (FVG adds least structural value) | R14 |
| Trend-aligned inversion | OB + FVG | aligned TRUE rows worse than FALSE in both families (0.3364/0.3530 and 0.3339/0.3517) | R15 (family-level) |
| Renderers | all | Liquidity **none** (C11) · CHOCH palette drift (C07) · OB drift · **FVG clean** — only fully spec-correct renderer | VF epic |
| Reload | all | FVG time-discontinuity rescan = **only reload pathway** in EA (reference for LC epic) | E11 (FVG partial) |

## S3. The three system-level facts

1. **Telemetry blind (T01).** No subsystem's raw evidence is observable in the frozen set; two layer columns do not exist; `hasProtectedPoint` never TRUE. Every E-card in P7 of docs 03–06 is blocked until schema v3.1 + wiring ships.
2. **Funnel inversion (R13).** The live funnel trades only the family measured worst (Liquidity, admitted subset 0.3027); the two best families are un-enterable (0%). Gate design (conf-only, min 0.60, `ConfluenceValidator.mqh:23-47`) is a config-level defect, not an algorithm one.
3. **Dead-wiring family (DD epic).** C01, C02, C09, C10, C16 share one pattern: *computed, never consumed*. The codebase computes far more than it uses; each is a small wiring fix + unit test, behavior-neutral until telemetry confirms.

## S4. Sprint 20 plan — platform first (per user direction)

Order of work is deliberate: **measurement precedes selection changes; wiring precedes behavior changes.**

| # | Epic | Work | Unblocks | Depends on |
|---|---|---|---|---|
| 1 | **TC — Telemetry** | Schema v3.1: add `layerOrderBlock`, `layerFVG`, `classification`, gap timestamps, `fillTime`; wire raws via CE `componentCount`; `hasProtectedPoint`; classifier serialization (C13, C16, T01) | **Every E-card in docs 03–06** | — |
| 2 | **T02 — Tests** | Regression scaffold; one test per P0 fix | — | 1 (assertion targets) |
| 3 | **DD — Dead logic** | C01 (PD evaluator), C02 (cold-start), C09 (sweep confirmation), C10 (classification write), C16 (classifier), C08 (entry reachability decision) — each a wiring fix + unit test | Correctness of what is measured | 2 |
| 4 | **LC — Lifecycle** | E11 audit across detectors; FVG reload = reference implementation; add `rates_total`-shrink handler | Pipeline stability under reload | 3 |
| 5 | **Gate/routing** | R11/R13 per-family thresholds (M15) — **after TC, so the effect is measurable**; re-measure admission-adjusted wr per family | Selection correctness | 1 |
| 6 | **VF — Visualization** | C11 liquidity renderer; palette parity (C07 + OB drift) | Operator verification | 1 |
| 7 | **ED / research M-cards** (gated on 1) | R15 trend bonus (E3), R17 h22-23 (E4), R03 session gate, R16 direction×cell (E5), C12/C18 displacement gates (paper-first), R14 decomposition | Hypothesis testing | 1 |

## S5. What NOT to do in Sprint 20

- **No detector redesign.** Algorithm column of S1 is healthy; the series found zero core-detector P0s. C12/C18 (displacement gates) are ED-paper work gated on telemetry, **not** immediate code changes.
- **No new rules, no new indicators.**
- **No gate changes before TC ships** — selection must be measured against the family it admits, and today it cannot be.
- **No OB/FVG displacement gating until classification/gap quality is serialized** (C12, C18, E1/E2 of doc 06).

## S6. Series verdict

**AVP Sprint 19 closed — overall IMPROVE.** Core algorithm design is sound across 5/6 components; the constraint on every Evidence score (52–58) is the telemetry gap, not the evidence work. Sprint 20's value is unlocked by **TC first**, then gating (R13), lifecycle (E11), wiring (DD). Research hypotheses (R03, R14–R17) are M-cards gated on schema v3.1. Evidence-based edge claims remain impossible until then; the only family-level claim with direct replication is Liquidity's gate-admitted 0.3027 (exact 18.8 replication).

## S7. Traceability

| Section | Sources |
|---|---|
| S1 matrix | docs 01–06 passports; ledger T01, C08, C09, C10, C12, C13, C16, R13 |
| S2 facts | doc 04 P6, doc 05 F1/F2, doc 06 P6.4–P6.8; ledger R03, R14–R17, C07, C11 |
| S3 facts | `ConfluenceValidator.mqh:23-47`; `ConfluenceEngine.mqh:299`; `TelemetryHealthReport.mqh:339-352,346`; probes avp19_4/5/6 |
| S4 plan | ledger epics table (07, lines 35-45); user direction 2026-08-03 |
| S5 constraints | docs 05 S1/S5, 06 S1/S4 verdicts |

## S8. Series scorecard

| Axis | Series range | Note |
|---|---|---|
| Research Quality | 90 | strongest across series (doc 06 best) |
| Implementation Quality | 60–74 (≈66 avg) | dead-wiring family caps this |
| Architecture Quality | 68–85 (≈72 avg) | CE componentCount=0 + missing layer columns |
| Visualization Quality | 0–90 (≈70 avg; 0 = Liquidity no renderer) | FVG clean, Liquidity none |
| Evidence Quality | 52–58 | capped by T01, not by evidence work |
| Evidence | 52–58 | capped by T01, not by evidence work |
| Confidence | **B** | flag/layer proxies exact; raw evidence impossible |
| **Overall** | **IMPROVE** | 64–74 across passports; platform-first Sprint 20 |

---

## S9. Cross-document traceability matrix

Every Sprint-20 engineering task must point back to the exact AVP findings that justify it. This matrix is the single index: each cell carries the doc-coded finding behind the task.

Legend: ● root finding this doc · ○ secondary / affected (reported in another doc, implicated here) · ✓ correct / verified · △ present-but-defective (drift/minor) · ✗ absent (defect) · — not evaluatable.

| Finding family (ledger) | 01 BOS | 02 CHOCH | 03 Swing | 04 Liquidity | 05 OB | 06 FVG | Sprint 20 link |
|---|---|---|---|---|---|---|---|
| T01 — structural evidence inert (raws 0, missing layer cols) | ○ (structureRaw 0) | ○ (raw 0) | ● (hasProtectedPoint never TRUE) | ● | ● (no `layerOrderBlock` col) | ● (no `layerFVG` col, classifier dead) | TC — schema v3.1 + raw wiring |
| T02 — no subsystem unit tests | ● | ● | ● | ● | ● | ● | test scaffold |
| E11 — lifecycle/reset | ● | ● | ● | ● | ● | ○ (reload reference; shrink still unhandled) | LC lifecycle audit |
| Funnel/gate — worst admitted, better rejected (C08/R13) | ○ (BOS_OB paper-only) | ● (CHOCH_OB never entered) | — | ● (89.4% admitted = worst family) | ● (0/13,178) | ● (0/12,320) | gating M15 (after TC) |
| Dead logic — computed but never consumed | ○ | ● (C05) | ● (C01) | ● (C10) | ● | ● (C16) | DD wiring |
| Visualization | ✓ | △ (C07 drift) | ✓ (90, forensic) | ✗ (no renderer) | △ (drift) | ✓ (clean, reference) | VF epic |
| Reload handling — time-discontinuity rescan | — | — | — | — | — | ✓ (**reference impl**) | LC epic adoption pattern |

Example per-task justification template (used by Sprint 20): *TC #1 draws evidence ① from rows 1–2; gating #4 from row 4; VF #6 from row 6.*

---

