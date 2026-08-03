# 05 — Order Block Detection — Deep Research (AVP Sprint 19.5)

| Field | Value |
|---|---|
| Document | `05_OrderBlocks_Deep_Research.md` |
| Series | AVP Sprint 19 (docs 01–06), frozen methodology v1.0 |
| Component | Order Block detection: last-opposing-candle zone, lifecycle, retest entry |
| Primary file | `Structure/OrderBlockDetector.mqh` |
| Consumers | Rules BOS_OB, OB_FVG, CHOCH_OB; ENTRY_OB_RETEST; STOP_OB_SIDE; OrderBlockRenderer |
| Prior work | Sprint 18.5 (research), 18.7 (confluence) |
| Verification status | **66/100 — IMPROVE** |
| Main findings | S1 no displacement/BOS gate on OB creation (any CHOCH suffices); S2 `obRaw` const 0 + **no `layerOrderBlock` column exists at all** (T01, worst case); S3 500-bar stale scan + unlimited rule-path recency; S4 touch-mitigation (weakest definition, same family as liquidity S1); S5 **gate reversal — the live gate admits the worst family and rejects this (the best) family**; F9 dead stats/Trading layer |
| Evidence | Sprint 17 frozen set — 18,686 rows; decided+signal n=17,073; base wr 0.3321 |

---

## P1. Research context — what "order block" means across schools

### P1.1 Canonical doctrine

| Concept | Canonical definition (industry corpus 2026) | Source cluster |
|---|---|---|
| Order block | **Last opposing candle immediately before a significant displacement** that breaks structure (BOS/MSS); institutional accumulation zone | tradingwyckoff.com, tradexis.ai, ictkillzone.com, quantum-algo.com, nqbacktest.online |
| Opposing candle | Bullish OB = last bearish candle before bullish impulse; bearish OB = mirror | all sources (unanimous) |
| Mandatory conditions | (1) last opposing candle, (2) genuine displacement (large body, minimal wicks), (3) structural break (BOS/MSS), (4) FVG confirmation optional, (5) unmitigated zone | tradingwyckoff.com (three conditions), ictkillzone.com (four criteria), quantum-algo displacement guide |
| Displacement definition | Body ≥ 1.5–3× the average of preceding candles; wick-to-body ratio < 0.2 per side; decisively breaks recent swing extreme | quantum-algo.com (five criteria) |
| No displacement = no OB | "Without displacement (no FVG, no BoS), the candle is just a swing — not an order block." | nqbacktest.online |
| Mitigation | **Only a candle BODY closing beyond the zone = full mitigation**; a wick 70% into the zone does not mitigate | ictkillzone.com, tradexis.ai |
| Entry | Retest entry at 50–100% of OB body; stop beyond full wick; target draw on opposite liquidity | tradexis.ai, capitalminds.io |
| Recency/freshness | First return to an unmitigated OB has highest concentration of remaining orders; twice-tested zones lose meaning | ictkillzone.com, tradexis.ai |

### P1.2 Academic anchors

- No peer-reviewed literature validates "order blocks" specifically; the construct descends from Wyckoff (accumulation → markup) via ICT (Huddleston). The adjacent academic support is:
  - **Osler (2002/2005)** — stop clustering at technical levels (the *retest* premise: stops sit beyond OB zones).
  - **Kavajecz & Odders-White (2004)** — limit-order depth concentrates at technical levels (the *zone defense* premise).
  - **Bouchaud/Farmer/Lillo (order-flow literature)** — impact and "resting orders" mechanics (the accumulation premise is a microstructural storytelling device; unverified as such).

**P1 verdict:** OB is the most *discipline-dependent* concept in the EA: its validity rests entirely on the displacement + structural-break conditions. The doctrine is unanimous that a bare opposing candle is NOT an OB. This is the sharpest falsifiable test for the implementation.

---

## P1.5. Component specification (as designed / as documented)

Per `docs/OrderBlock_API.md` and Sprint 18.5:

- **Definition (API doc):** OB = last opposite-direction candle before the displacement that caused the CHOCH; doji skipped; one OB per CHOCH; id sequential from 1; OB candle always before the displacement candle and opposite to it.
- **Lifecycle:** detection → active → mitigated (touch) / invalidated; FROZEN render state on mitigation, DELETE on invalidation.
- **Entry:** ENTRY_OB_RETEST (bullish → ob.low, bearish → ob.high); stop beyond OB side + buffer.
- **Rules:** BOS_OB (+15/+0.10 with trend bonus), OB_FVG (+15/+0.10 no trend bonus), CHOCH_OB (+20/+0.15).

State machine:

```
CHOCH detector ──▶ OrderBlockDetector.Update (incremental on new CHOCH)
                       │
                       ▼
               scan back ≤500 bars (OrderBlockDetector.mqh:257-258)
               first candle with close<open (bullish OB) / close>open (bearish OB), doji skipped
                       │
                       ▼
               ACTIVE (id, price = candle extremes)
                       │
                       ├─ touch of low/high on last closed bar ──▶ MITIGATED (FROZEN render)
                       └─ (invalidation path: none in detector; signal expiry via ConfluenceEngine)
```

---

## P2. Tooling survey — what production tools require before marking an OB

| Tool | Last opposing candle | Displacement check | Structural break | Mitigation rule |
|---|---|---|---|---|
| tradingwyckoff.com | YES (or set of candles) | "strong impulse, large-bodied" mandatory | BOS mandatory | body close beyond |
| tradexis.ai (Drill Mode) | YES | displacement broke structure | BOS mandatory | "traded completely through the body and closed beyond" |
| ictkillzone.com | YES | 4 criteria: sweep, displacement, unmitigated, HTF align | MSS | wick ≠ mitigation; body close only |
| quantum-algo.com | YES | 5 criteria: body 1.5–3×avg, wick <0.2×body, BOS break | swing break mandatory | n/a |
| nqbacktest.online | YES | FVG or BOS required | BOS/MSS required | "clear break of structure" |

**P2 verdict:** Every surveyed source requires (a) displacement quality and (b) structural break before a candle qualifies as an OB. The current implementation checks neither at OB creation (P3, S1).

---

## P3. Code facts (harvest, verified against source)

Path abbreviations: `OBD` = `Structure/OrderBlockDetector.mqh`; `RULES` = `Confluence/ConfluenceRules.mqh`; `CE` = `Confluence/ConfluenceEngine.mqh`; `SYM` = `Portfolio/SymbolContext.mqh`; `TREQ` = `Telemetry/TelemetryRowBuilder.mqh`; `THR` = `Telemetry/TelemetryHealthReport.mqh`; `TYPES_T` = `Telemetry/TelemetryTypes.mqh`; `OBEVAL` = `Confluence/Evaluators/OrderBlockEvaluator.mqh`; `CONST` = `Utils/Constants.mqh`.

### P3.1 Algorithm

- **OB = last opposite candle before the CHOCH bar** (`OBD:132–178`): bullish CHOCH → scan backward for first `close < open` (`OBD:139–152`); bearish → first `close > open` (`OBD:163–176`); doji (`open == close`) skipped (`OBD:148,171`).
- **CHOCH-driven only** — no independent displacement trigger: `Update` gates on `chochCount <= m_lastProcessedCHOCHIndex` (`OBD:113`), processes only new CHOCHs (`OBD:120`), advances cursor (`OBD:130`). If the CHOCH detector never fires, no OB is ever created.
- **Scan window up to 500 bars** older than the CHOCH bar (`OBD:257–258`). With zero displacement/body/wick filters (only doji skip), the "last opposing candle" can be 500 bars old — a completely stale zone, not the candle immediately before an impulse (S3).
- **No filters exist:** grep for `MIN_WICK`/`MIN_BODY`/body%/ATR in the OB path → nothing. The only body constant in the repo is `FVG_MIN_BODY_SIZE_PIPS 5` (`CONST:81`), FVG-only. No displacement magnitude, no wick ratio, no BOS requirement at creation.
- One OB per CHOCH, id `m_nextId++` from 1 (`OBD:151`, `:73`); capacity grows +256 (`OBD:158–162`).
- OB-SEARCH FAILED logged when no opposite candle in window (`OBD:341–342`).

### P3.2 Lifecycle

- **Mitigation = touch** of the OB candle's low (bullish) / high (bearish) by the **last closed bar** `close[1]` (`OBD:180–196`). No body-close requirement — a wick into the zone mitigates (S4; doctrine says wick ≠ mitigation).
- **No invalidation path inside the detector** — lifecycle fields exist (`OrderBlock_API.md:60–62`) and are consumed only by the renderer (`OrderBlockRenderer.mqh:100–143`); detector-internal state drives FROZEN (mitigated) / DELETE.
- Signal-level expiry (EXPIRY_OB_MITIGATED / EXPIRY_OB_INVALIDATED) handled in `CE:398–420`.

### P3.3 State / reset hygiene (E11 assessment — LATENT, 5th member)

- `OBD` has **no Clear() and no shrink handler**; `m_lastProcessedCHOCHIndex` is only ever advanced (`OBD:130`) and never reset outside the constructor; `m_nextId` never reset; Shutdown (`OBD:352–365`) frees the array but preserves cursor/id/stats.
- Consumers hold independent references: renderer `m_lastRenderedOBCount` (`OrderBlockRenderer.mqh:31`), candidate by-id (`TradeCandidateBuilder.mqh:378–389`), entry by-id (`EntrySetupBuilder.mqh:301–313`).
- **Latent, not yet live**: current wiring never mid-run-resets (`SYM:999–1004` deletes on shutdown). BUT the OB cursor is *downstream* of the CHOCH cursor — if the CHOCH reset fix (E11) is shipped, an unchanged OB detector inherits the same desync class. Register in the LC epic audit.

### P3.4 Recency (S3-cont.)

- **Rule path `ActiveOB` has NO recency cutoff** (`RULES:101–123`, no iTime filter) — an OB found 500 bars ago can still fire signals. Freshness exists only in the **dead** evaluator path (`OBEVAL:31–33`: <10 bars = 1.0, <20 = 0.8, else 0.5). Sprint 18.7 flagged this; code confirms (`07_Confluence.md:176–177`).
- `OB_RECENT_BARS 50` dead; `OB_FRESHNESS_BARS 10` live in evaluator only.

### P3.5 Telemetry (S2, T01 family — worst case)

- `obRaw/obWeight/obContribution` exist (`TYPES_T:192,255`), but in production the component loop never runs: `CE:299` forces `componentCount = 0` in the rule path → obRaw stays 0.0; `THR:345` **asserts obRaw == 0 for v3 rows** (contractually dead).
- **`layerOrderBlock` does not exist in the schema** (grep = 0 matches). v3 layer columns are `layerStructural/layerLiquidity/layerConfirmation/layerTotal` only. Liquidity has a live layer column; OB has **nothing** — OB quality is structurally unmeasurable in the current schema, even after the general T01 fix.
- `hasOrderBlock` is live (`CE:317–322`; `TREQ:125`).

### P3.6 Consumers / rules / entry

- Rules: `BOS_OB_*` +15/+0.10 with trend bonus (`RULES:257–298`); `OB_FVG_*` +15/+0.10, **no trend bonus** (`RULES:311–351`); `CHOCH_OB` +20/+0.15 (`RULES:437–456`).
- Entry: ENTRY_OB_RETEST → ob.low / ob.high (`EntryPriceResolver.mqh:17–33`); STOP_OB_SIDE ± buffer (`StopLossResolver.mqh:24–40`).
- Weights: orderBlock 20.0 of 100 (`ConfluenceWeights.mqh:20`).
- Context bridge: `BuildDetectionContext` — OB pointer is **not** part of the DetectionContext; OB reaches rules via the detector pointer wired to ConfluenceEngine (`SYM:390`).

### P3.7 Rendering (P4)

- Active #1976D2 (`ChartStyle.mqh:17`), frozen #0F467E (`:29`) — match spec v2.1 palette. **`COLOR_OB_HIST` (#09294A) specified but the constant does not exist** (`ChartStyle.mqh`), and OB skips the historical tier entirely (no CMD_HIST for OB) — palette drift + unreachable tier (C07 family).
- FROZEN on mitigation (rect kept, dashed, fill off), DELETE on invalidation (`OrderBlockRenderer.mqh:100–143`); names `SCX_OB_RECT_%d`/`SCX_OB_TEXT_%d` (`ChartObjectNames.mqh:57–65`).

### P3.8 Dead code / hygiene

- OBStats counters (`OBD:24–28`) never incremented — printed as zeros at Shutdown (`OBD:362–364`).
- `protectedMgr` parameter of `Update` unused (`OBD:49,99`).
- **`Trading/` layer is a dead stub**: `Trading/OrderBlockQualifier.mqh:5` includes `"./Confluence/OrderBlockDetector.mqh"` (wrong path; real file is `Structure/...`), and the whole `Trading/` engine is not wired into `SymbolContext` (which uses `Confluence/ConfluenceEngine.mqh`).

---

## P3.9 Verification checklist

| # | Claim (from spec/doctrine) | Status | Evidence |
|---|---|---|---|
| V1 | OB = last opposing candle before the CHOCH bar | YES | `OBD:132–178` |
| V2 | Doji skipped | YES | `OBD:148,171` |
| V3 | One OB per CHOCH, stable sequential ids | YES | `OBD:151` |
| V4 | Displacement required before OB qualifies | **FAIL** | no displacement/BOS check at creation (P3.1) |
| V5 | Body/wick filters (doctrine: 1.5–3× body, wick <0.2) | **FAIL** | none exist anywhere |
| V6 | Scan window reasonable (near the impulse) | **FAIL** | up to 500 bars (`OBD:257–258`) |
| V7 | Rule-path recency for OBs | **FAIL** | unlimited (`RULES:101–123`) |
| V8 | Mitigation = body close beyond zone (doctrine) | **FAIL** | touch of `close[1]` wick/body (`OBD:180–196`) |
| V9 | Reset/reload lifecycle safe | WARN (latent) | no shrink handler; downstream of CHOCH cursor |
| V10 | Raw evidence exported | **FAIL** | obRaw const 0.0; **layerOrderBlock column missing** |
| V11 | Renderer faithful (colors, freeze/delete) | YES (minor drift) | P3.7 |
| V12 | Unit tests | **FAIL** | none for OB detector |

---

## Findings

### S1 — No displacement / structural-break gate on OB creation — Very High

Any CHOCH (itself unvalidated — Sprint 19.2 C3/C4) creates an OB by scanning backward for the first opposite-sign candle, with only a doji skip. No displacement magnitude, no body/wick ratio, no BOS requirement. Doctrine is unanimous: *"without displacement (no FVG, no BoS), the candle is just a swing — not an order block"* (nqbacktest.online); displacement body ≥1.5–3× average, wick <0.2× body (quantum-algo). **This is the same defect shape as liquidity S1 (weakest-possible event definition) applied to a different concept.**

**Classification:** Implementation Defect. **Confidence:** Very High. **Destination:** Sprint 20 (E1: displacement gate on OB creation, paper-first on frozen set).

### S2 — OB raw evidence structurally unmeasurable — Very High (T01 worst case)

`obRaw/obWeight/obContribution` const 0.00 (P6, unique=1 across 17,073 rows; `CE:299` forces componentCount=0; `THR:345` asserts it). **And no `layerOrderBlock` column exists** — OB is the only major component with neither raw columns nor a layer column. Even after a generic T01 fix, OB quality would remain invisible without a schema addition. The family's *only* telemetry is the binary `hasOrderBlock` flag.

**Classification:** Measurement Gap. **Confidence:** Very High. **Destination:** Sprint 20/21 (E2: schema v3.1 add `layerOrderBlock` + populate obRaw; T01 epic).

### S3 — 500-bar scan + unlimited rule-path recency = stale zones — High

The backward scan window (`OBD:257–258`) plus no rule-path recency filter (`RULES:101–123`) means a 500-bar-old candle can fire signals indefinitely. Sprint 18.5 already flagged the window (`05_OrderBlocks.md:318`); this verification confirms both halves. Freshness logic exists only in the dead evaluator path (`OBEVAL:31–33`).

**Classification:** Implementation Defect. **Confidence:** High. **Destination:** Sprint 20 (E3: recency gate in rule path, aligned with `OB_FRESHNESS_BARS`).

### S4 — Touch-mitigation (weakest definition) — Medium

`close[1]` touching the OB candle low/high mitigates (`OBD:180–196`). Doctrine: wick into zone ≠ mitigation; only body close beyond fully mitigates (ictkillzone, tradexis). A wick-touch kills a zone that doctrine would keep valid — over-invalidation, opposite of liquidity S1's under-invalidation.

**Classification:** Implementation Defect. **Confidence:** Medium. **Destination:** Sprint 20 (E4: body-close mitigation, measure in-family delta).

### S5 — Gate reversal: the live gate admits the worst family and rejects the best — Very High (evidence-driven)

OB family: n=13,178, 77.2% of all signals, wr 0.3410 (+0.9pp vs base) — but **0 rows reach confidence ≥ 0.60** (conf states 0.35/0.40/0.45 only, P6.4) → **100% rejected by the live ConfluenceValidator gate**. Meanwhile the worst family (Liquidity, 0.2967 / admitted subset 0.3027) sits exactly at 0.60 and is 89.4% admitted. **The live funnel is effectively 100% the weakest family, and the strongest family cannot reach it.** 18.9's E1 (per-family gate thresholds) is validated with maximal force; this is the single most decision-relevant AVP result so far.

**Classification:** Architectural Limitation (config/gate design). **Confidence:** Very High (P6.4). **Destination:** Sprint 20 (E5: per-family gate simulation, M15).

### F1 — OB_FVG_BULLISH is the single worst rule in the EA — High

n=6,412 (37.6% of ALL signals), wr 0.3036, meanR −0.095 — against its mirror OB_FVG_BEARISH (n=5,908, wr 0.3769, +7.3pp). Same rule machinery, direction-symmetric logic, wildly asymmetric performance. This is the largest, worst, and most-ignored population in the dataset.

**Classification:** Research Hypothesis (direction asymmetry unexplained; candidates: session skew, JP flow, entry/TP geometry). **Confidence:** High (measured), Low (cause). **Destination:** M-card (E6: decompose by session/symbol; check R05 asymmetry; E7 direction gate).

### F2 — BOS_OB outperforms OB_FVG — High

BOS_OB combos 0.3730 (n=858) vs OB_FVG 0.3388 (n=12,320): +3.4pp for the structural-break-confirmed half. The BOS requirement (absent in OB_FVG rule) appears to carry the edge — consistent with S1's direction (displacement/break gates matter).

**Classification:** Research Hypothesis. **Confidence:** Medium. **Destination:** E1/E6 family (measure displacement-gated OB_FVG).

### F3 — Palette drift + unreachable historical tier — Low

`COLOR_OB_HIST` #09294A specified (spec v2.1:782) but constant absent; OB skips CMD_HIST tier. Frozen #0F467E vs #09294A mismatch is cosmetic.

**Classification:** Implementation Defect. **Confidence:** High. **Destination:** Sprint 20 cleanup (C07 family).

### F4 — Dead code — Low

OBStats counters never incremented; `protectedMgr` unused; `Trading/` layer dead stub with wrong include path (`Trading/OrderBlockQualifier.mqh:5`).

**Classification:** Implementation Defect. **Confidence:** High. **Destination:** Sprint 20 cleanup.

---

## P4a. Algorithm correctness score — 60/100

| Capability | Score | Basis |
|---|---|---|
| Last-opposing-candle selection | 85 | correct search semantics, doji skip, deterministic ids (P3.1) |
| OB qualification (displacement/BOS/body) | 20 | none exist (S1) |
| Lifecycle state machine | 60 | gates present; touch-mitigation too weak (S4) |
| Recency discipline | 30 | 500-bar window + unlimited rule-path recency (S3) |
| Consumer wiring | 70 | rules/entry wired; gate reversal (S5) |

## P4b. Visualization — 85/100

Renderer exists and is faithful: freeze-on-mitigation, delete-on-invalidation, spec colors for active/frozen. Deductions: `COLOR_OB_HIST` missing constant + unreachable historical tier (F3).

---

## P5. Pipeline questions

1. **What fraction of the signal universe is OB?** 77.2% (n=13,178 of 17,073) — the family *is* the pipeline.
2. **Does any OB row reach the live gate?** No — 0 of 13,178 have conf ≥ 0.60 (P6.4). The live funnel is LIQUIDITY-only (doc 04 P6.3).
3. **Which rule is the biggest population?** OB_FVG_BULLISH, n=6,412, 37.6% of everything, wr 0.3036 — the single largest *and* single worst rule (F1).
4. **Can OB quality be measured?** No — obRaw const 0 and no `layerOrderBlock` column (S2). Only presence (hasOrderBlock) exists.
5. **What breaks first downstream?** The gate design itself (S5): per-family thresholds are the one-change-would-flip-everything item.

---

## P6. Evidence — Sprint 17 frozen set (read-only analysis)

Universe: 18,686 rows (68 cols, UTF-16, v3), decided+signal n=17,073, base wr 0.3321.

```
=== ORDER BLOCK family (firedRuleId 1|2|3|4); universe n=17073, base wr=0.3321 ===
family n=13178 (77.19% of signals)  wr=0.3410  meanR=0.0170  medianR=-1.0000  medBars=4.0

rule split:
BOS_OB_BULLISH (1): n=440 wr=0.3705 meanR=0.1153
BOS_OB_BEARISH (2): n=418 wr=0.3756 meanR=0.1305
OB_FVG_BULLISH (3): n=6412 wr=0.3036 meanR=-0.0946   <-- largest AND worst rule
OB_FVG_BEARISH (4): n=5908 wr=0.3769 meanR=0.1229
CHOCH_OB_REVERSAL (7): n=342 wr=0.3567 meanR=0.0505
BOS_OB combos: n=858 wr=0.3730 | OB_FVG combos: n=12320 wr=0.3388

hasOrderBlock='2': n=13520 (79.2% of universe) == OB-family (rules 1,2,3,4,7); mismatches=0

raw evidence: obRaw/obWeight/obContribution unique=1 (const 0.00)
layerStructural unique=4 {15,25,30,35}: 15->Liquidity(3553), 25->OB_FVG(12320), 30->BOS_OB(858), 35->CHOCH_OB(342)
layerConfirmation unique {10,15}; layerTotal {35,40,45}

confidence gate: conf 0.35 n=3386 wr=0.3517 | conf 0.40 n=9202 wr=0.3349 | conf 0.45 n=590 wr=0.3746
ADMITTED conf>=0.60: n=0 (0.0%)   <-- whole family rejected by live gate
GATED  conf<0.60 : n=13178 (100%)

cells: EURUSD M15 n=9034 wr=0.3403 | EURUSD H1 n=2029 wr=0.3406 | GBPJPY H1 n=2115 wr=0.3447
OB_FVG cells: EURUSD M15 n=8464 wr=0.3404 | EURUSD H1 n=1906 wr=0.3321 | GBPJPY H1 n=1950 wr=0.3385

hours (family): h00-07 0.3358 | h08-12 0.3484 | h13-17 0.3555 | h18-21 0.3598 (best) | h22-23 n=1124 wr=0.2722 (drain)
hours (OB_FVG): h00-07 0.3323 | h08-12 0.3433 | h13-17 0.3469 | h18-21 0.3714 (best) | h22-23 0.2720 (drain)

dow: Mon 0.3384 | Tue 0.3342 | Wed 0.3377 | Thu 0.3420 | Fri 0.3530 (best, flat profile)

co-occurrence: BOS=TRUE n=858 wr=0.3730 (=BOS_OB) | FVG=TRUE n=12320 wr=0.3388 (=OB_FVG)
  OB=TRUE 13178/13178; CHOCH=0; PP=0 (never TRUE anywhere: decided 18536 rows, '2' count = 0)

outcomeSource '1' (paper) 13178; exitReason: '2' n=8644, '1' n=4405, '4' n=129
trendAligned: '2' (TRUE) n=9524 wr=0.3364 | '1' (FALSE) n=3654 wr=0.3530   <-- inversion vs intuition
conf<->ruleConfidence pairs: (0.35,0.80),(0.40,0.80),(0.40,0.85),(0.45,0.95)
```

### P6.1 The family is the pipeline

77.2% of all signals. wr 0.3410 (+0.9pp vs base 0.3321), meanR +0.017 — slightly positive overall, entirely carried by BOS_OB (0.3730) and OB_FVG_BEARISH (0.3769); OB_FVG_BULLISH drags it down.

### P6.2 Direction asymmetry inside OB_FVG (F1)

Bullish 0.3036 vs bearish 0.3769 — **+7.3pp with identical rule machinery**. The bearish half of the largest rule is the single best population (n=5,908); the bullish half is the single worst (n=6,412). Any aggregate OB conclusion would be a lie about both halves.

### P6.3 Gate reversal (S5)

0 of 13,178 OB rows have conf ≥ 0.60; 3,178 of 3,553 liquidity rows do (89.4%). The ConfluenceValidator (confidence-only, min 0.60) thus admits **only** the worst family and rejects the best. The 18.9 "gate admits the worst family" statement is now *quantitatively complete* across all five families: admitted set = Liquidity only.

### P6.4 Layer decomposition is exact

`layerStructural` unique values map 1:1 onto families: 15 → Liquidity (n=3,553), 25 → OB_FVG (n=12,320), 30 → BOS_OB (n=858), 35 → CHOCH_OB (n=342). The layer columns are reliable family fingerprints — useful for any future row-level analysis.

### P6.5 Session structure — h22–23 drain across four families

OB h22-23 0.2722; OB_FVG subfamily 0.2720. Combined with BOS 0.2156, CHOCH 0.1667, Liquidity 0.2000 — **the 22:00–23:59 GMT window is negative across every family** (four independent detectors). This is the strongest cross-doc session signal in the program.

### P6.6 trendAligned inversion

Trend-aligned OB rows wr 0.3364 vs unaligned 0.3530 (+1.7pp *for* the unaligned). Counter-intuitive; the OB_FVG rule does not award a trend bonus (P3.6), so the flag's meaning in this family is unclear. Flag for E6/E7 analysis; do not treat as actionable.

---

## P7. Experiments (falsifiable, frozen-set first)

| ID | Question | Rationale | Primary test | Easiest falsification |
|---|---|---|---|---|
| E1 | Does a displacement gate on OB creation lift in-family wr? | S1: doctrine requires displacement+BOS; currently any CHOCH qualifies | Paper: re-run with body ≥1.5× avg + wick <0.2×body + BOS required (on frozen OHLC), compare OB family wr | Gated OB wr ≤ 0.3410 |
| E2 | Can OB quality be measured? | S2: obRaw 0 + no layer column | Schema v3.1: add `layerOrderBlock`, populate obRaw, re-run | Quality columns show no wr relationship in-sample |
| E3 | Does rule-path recency gate kill stale-zone signals? | S3: unlimited recency + 500-bar scan | Paper: reject OBs older than N bars (10/50/100) at rule evaluation | In-family wr unchanged vs unlimited |
| E4 | Body-close mitigation vs touch mitigation | S4: doctrine says wick ≠ mitigation | Paper: mitigate only on body close beyond zone; measure signal survival + wr | No wr change from mitigation definition |
| E5 | Per-family gate thresholds — what does the funnel become? | S5: gate admits only the worst family | Simulate minConfidence per family on frozen set: admitted n/wr per family | No threshold admits a set with wr ≥ base 0.3321 across families |
| E6 | OB_FVG direction asymmetry decomposition | F1: 0.3036 vs 0.3769 | Decompose by session, symbol, hour, TP geometry; compare bullish vs bearish drivers | Asymmetry vanishes under any single factor |
| E7 | BOS-requirement edge for OB_FVG | F2: BOS_OB +3.4pp over OB_FVG | Paper: OB_FVG rule variant requiring recent BOS; compare | No lift from added BOS requirement |

## Proof Matrix (verification of verification)

| Statement | Doctrine | Code | Data | Status |
|---|---|---|---|---|
| "OB = last opposing candle before displacement" | YES (unanimous) | YES (candle only; displacement = any CHOCH) | n/a | **Partially true — displacement never checked** |
| "Displacement + BOS required" | YES (all surveyed) | NO | OB family wr 0.3410, near base | **Falsified for this implementation** |
| "OB family is the pipeline" | n/a | n/a | 77.2% of signals | **Proven** |
| "Gate admits worst, rejects best" | 18.9 E1 | confidence-only gate | 0/13,178 admitted; 89.4% of Liquidity admitted | **Proven — strongest cross-doc result** |
| "OB_FVG bullish is worst rule" | n/a | n/a | 0.3036, n=6,412 | **Proven** |
| "OB quality measurable" | telemetry spec | obRaw const 0; no layer column | unique=1 | **Falsified — measurement gap** |
| "Renderer faithful" | visual spec | yes, minor drift | n/a | **Mostly proven** |

## Traceability

| Claim | Section |
|---|---|
| No displacement gate → S1 | P1.1, P2, P3.1, P3.9 (V4–V5) |
| Raw evidence + missing layer column → S2 (T01) | P3.5, P6 |
| Stale scan + recency → S3 | P3.1, P3.4, P3.9 (V6–V7) |
| Touch mitigation → S4 | P3.2, P3.9 (V8) |
| Gate reversal → S5 | P6.3, doc 04 P6.3, 18.9 |
| Direction asymmetry → F1 | P6.2 |
| BOS edge → F2 | P6.1, P6.2 |
| Palette → F3 (C07) | P3.7 |
| Dead code → F4 | P3.8 |

## Findings Summary (consolidated — Confidence × Destination × Classification)

| Finding | Confidence | Destination | Classification |
|---|---|---|---|
| S1 No displacement/BOS gate on OB creation | Very High | Sprint 20 (E1) | Implementation Defect |
| S2 OB quality unmeasurable (obRaw 0 + no layer column) | Very High | Sprint 20/21 (E2, T01/TC epic) | Measurement Gap |
| S3 500-bar scan + unlimited recency | High | Sprint 20 (E3) | Implementation Defect |
| S4 Touch-mitigation (wick ≠ mitigation doctrine) | Medium | Sprint 20 (E4) | Implementation Defect |
| S5 **Gate reversal — worst family admitted, best rejected** | Very High | Sprint 20 (E5, M15) | Architectural Limitation |
| F1 OB_FVG_BULLISH largest-and-worst rule (0.3036) | High (measured) / Low (cause) | M-card (E6) | Research Hypothesis |
| F2 BOS-requirement edge (+3.4pp) | Medium | E1/E7 family | Research Hypothesis |
| F3 Palette drift / unreachable hist tier | High | Sprint 20 cleanup (C07) | Implementation Defect |
| F4 Dead code (stats, Trading layer, param) | High | Sprint 20 cleanup | Implementation Defect |
| P6.5 h22-23 drain across all four families | High | M06 session gate (R03) | Research Hypothesis |

## Scorecard

| Dimension | Score | Basis |
|---|---|---|
| Research alignment | 78/100 | doctrine unanimous on displacement; implementation silent |
| Algorithm correctness | 60/100 | correct candle semantics; no qualification gates |
| Visualization | 85/100 | faithful renderer; minor palette/hist-tier drift |
| Pipeline integrity | 65/100 | gate reversal; dead evaluator path; hasOrderBlock live |
| Evidence quality | 60/100 | family stats strong; direction asymmetry clear; raw unmeasurable |
| Maintainability | 55/100 | dead counters, dead Trading layer, unused param |
| **Overall** | **66/100 — IMPROVE** | |

## Final Verdict — Improve

**The strongest family is invisible to the live gate.** 77% of all signals (wr 0.3410, +0.9pp) cannot reach entry because the confidence-only gate (min 0.60) rejects 100% of them, while admitting the worst family at 89.4%. This is the single most consequential AVP finding so far: **the entry funnel is operating on the weakest population in the dataset, by configuration, not by market reality.**

**What is solid:** the last-opposing-candle search semantics, deterministic ids, the renderer, and the exact family→layer decomposition.

**What must change before anything else:** E5 (per-family gate thresholds — a config experiment that costs nothing and flips the funnel), E1 (displacement gate on OB creation), E2 (schema addition `layerOrderBlock`). Do NOT tune OB_FVG entry parameters while OB_FVG_BULLISH (37.6% of all signals, 0.3036) and OB_FVG_BEARISH (0.3769) coexist under the same rule machinery — the asymmetry must be explained (E6) before any uniform tuning.


