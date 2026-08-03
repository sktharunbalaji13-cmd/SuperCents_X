# 06 — Fair Value Gap (FVG) — Deep Research (AVP Sprint 19.6)

| Field | Value |
|---|---|
| Document | `06_FVG_Deep_Research.md` |
| Series | AVP Sprint 19 (docs 01–06), frozen methodology v1.0 |
| Component | Fair Value Gap detection: three-candle wick gap, fill (close-based), trend-opposition invalidation |
| Primary file | `Structure/FVGDetector.mqh` |
| Consumers | Rules OB_FVG (rules 3/4); ENTRY_FVG_MIDPOINT; TARGET_OPPOSING_FVG; FVGRenderer |
| Prior work | Sprint 18.6 (research: fill-rate, FVG zones) |
| Verification status | **70/100 — IMPROVE** |
| Main findings | S1 classification/size/strength computed but **never serialized**, `fvgRaw` const 0, **no `layerFVG` column** (T01, 4th family, worst-case telemetry); S2 **gate reversal family-wide — 0/12,320 FVG rows admitted, max conf 0.40**; S3 the rule's trend-alignment bonus is **value-negative** (bonus rows 0.3339 vs non-bonus 0.3517, driven by BEARISH 0.3643 vs 0.4103); S4 UntouchedFVG rule path has **no recency AND no invalidated check** — filled/invalidated/stale gaps still match; S5 direction asymmetry **flips by symbol** (EURUSD bullish weak −9.5pp, GBPJPY bullish strong +6.8pp); S6 gap-size filter on the **wrong candle** (5-pip body min on A and C, displacement candle B unconstrained); S7 (positive) reload handling **best-in-class** — time-discontinuity full rescan, only detector with a reload pathway |
| Evidence | Sprint 17 frozen set — 18,686 rows; decided+signal n=17,073; base wr 0.3321 |

---

## P1. Research context — what a "fair value gap" means across schools

### P1.1 Canonical doctrine

| Concept | Canonical definition (industry corpus 2026) | Source cluster |
|---|---|---|
| FVG / IMBALANCE | **Three-candle gap where the high of candle 1 and the low of candle 3 do not overlap** (wick-to-wick imbalance); zone = gap edges | tradingedges.org, psychologyofatradingcom (unanimous) |
| Gap geometry | Bullish: low of candle 3 must print strictly **above** high of candle 1; bearish is the mirror; middle candle = the displacement/impulse | tradingedges.org (3-candle test) |
| Middle candle role | The displacement is the **imbalance candle**; several tools require a **minimum body on candle 2 (the displacement)**, others count any 3-candle gap | priceactionlover.com |
| Entry convention | **CE = 50% of the gap** (midpoint) is the standard entry; entries only against **unmitigated** gaps | tradingedges.org, ICT corpus (unananimous on mid-retrace) |
| Mitigation | A body **closing through the entire gap** converts it to a FVG *breaker* / IFVG (inversion); wick-through does not invalidate | ICT IFVG conventions |
| Validity criteria | Prior sweep of opposing liquidity, genuine displacement, HTF alignment, PD-zone confluence, unmitigated, kill-zone timing | ICT rebalanced liquidity corpus (multiple) |
| Freshness | **First retrace into a fresh, unmitigated gap carries the edge**; twice-visited gaps lose meaning | fill-rate corpus |

### P1.2 Fill-rate anecdote — caution

- A 60–70% "gap fill rate" is widely repeated in retail corpus. alphaexcapital.com (2026-07-14) specifically flags these fill-rate claims as **unsourced / not backed by published data**. Treat as anecdote, not doctrine. Our P6 below measures fill-implied behaviour from the frozen Sprint 17 set instead (exitReason / wr split), not a fill claim.

### P1.3 Firmest falsifiable test

The doctrine is unanimous that the edge lives in **fresh, unmitigated gaps** and that displacement (candle 2 body) is a validity input. Both are directly checkable against this implementation:
1. Does the detector gate on displacement-candle body? → **No (S6)**.
2. Does the live rule path restrict to unmitigated, recent gaps? → **No (S4)**.
3. Is gap "quality" (size/strength/class) observable in evidence? → **No (S1)**.

**P1 verdict:** FVG is a *weakest-definition* implementation of a doctrine whose value concentrates in the missing qualification gates. Same family as liquidity S1 and OB S1.

---

## P2. Tooling

| Item | Value |
|---|---|
| Methodology | AVP v1.0 (frozen, `00_Research_Methodology.md`); no production code/tests touched |
| Evidence | `Evidence/Sprint17/merged/*.csv`, 18,686 rows, UTF-16, fingerprint `2e74bbae…` |
| Universe | decided+signal n=17,073 (outcome `1`|`2` with firedRuleId ≠ 0); base wr **0.3321**; all splits below on this universe |
| Confidences | tristate `1`=FALSE `2`=TRUE; rules 3/4 both ruleConfidence 0.80, confidence ∈ {0.35,0.40}; layerConfirmation ∈ {10,15} = {no trend bonus, trend bonus} |
| But asked | probe `avp19_6_fvg_evidence.py` (read-only pandas), outputs locked here |
| Verdict currency | gate admits conf ≥ 0.60 only; **FVG max achievable conf 0.40 → structurally un-enterable by the live funnel** |

---

## P3. Implementation facts

| § | Loc | Code fact | Verification | Severity |
|---|---|---|---|---|
| F1 | FVG:133 | `EPS = _Point*0.1`; a gap only needs to exceed **0.1 point** to exist | verbatim | low (any-gap = weakest form) |
| F2 | FVG:179 | `minBody = FVG_MIN_BODY_SIZE_PIPS*_Point*10` → **5-pip** floor | verbatim | see F15 |
| F3 | FVG:193-200 | body check on **A and C only**; displacement candle B is **never size-checked** | verbatim | **high (S6: filter on wrong candles)** |
| F9 | FVG:203-242 | Bearish: A bull & C bear, gap = Low(A)…High(C), need High(C)<Low(A)–EPS; Bullish: A bear & C bull, gap = High(A)…Low(C), need Low(C)>High(A)+EPS — **wick-to-wick** | verbatim | low (matches doctrine) |
| F10 | FVG:144-151 | `time[0] < mlastProcessedTime → rescan full history` — **time-discontinuity reload** pathway | verbatim | **high (positive, unique in EA)** |
| F11 | FVG:258 | debug rejection logging gated to D'2026.01.12–D'2026.02.06 | verbatim | low (leftover) |
| F12 | FVG:368-379 | fill = close of any subsequent bar within gap; `fillTime` **never written** (`:375`) | harvest | low (dead field) |
| F13 | FVG:383-396 | invalidation = trend-opposition **only**, while !filled; **no time-based expiry** | harvest | **high (S4 pairs)** |
| F14 | FVG:306-401 | ClassifyFVG size/strength/class computed, logged, counted at shutdown — **never serialized / never consumed by decision layer** | harvest | **high (S1)** |
| F15 | FVG:401-539 | classification buckets SMALL<3/MEDIUM<10/LARGE≥10, WEAK<5/NORMAL<15/STRONG≥15, REVERSAL>BREAKAWAY>CONTINUATION>UNKNOWN — **dead analysis** | harvest/verbatim ADJACENT | **high (S1)** |
| F16 | RULES:125-147 | Untouched-FVG rule path: build vs FVG arrays with **no `iTime` recency filter and no `isFilled`/`isInvalidated` guard** — invalidated/stale gaps still match | harvest | **high (S4)** |
| F17 | RULES:125-147 | rule can fire off a **500-bar-old** gap (same stale-scan family as OB S3) | harvest | medium (P0-family) |
| F18 | EXPIRY | EXPIRY_FVG_FILLED conflates "filled" and "not found" into one reason | harvest (CE:386-394) | low |
| F19 | CE:299 | `componentCount=0` → `fvgRaw` **const 0.00**; THR asserts | harvest | **highest (S1/T02)** |
| F20 | SC:105 | FVG contributes to layerStructural = OB15+FVG10, `layerConfirmation` 10/15 — **no `layerFVG` column exists** | harvest | **high (S1)** |
| F21 | EPR:35-48 | ENTRY_FVG_MIDPOINT → entry at gap mid; stop has no FVG policy (SLR dead include) | harvest | low |
| F22 | FVGRenderer | palette dimming 0.60/0.35 verified correct; frozen→hist promote at 20 bars; `MaxHistoricalFVG=30` | normal | low (clean) |

---

## P4. Visual quality

Expected 75–85 (independent of documented 85 for the clean renderer)
- Renderer **exists and math is clean** (dimming verified, no drift). Contrast: doc 04 Liquidity had *no* renderer (1st 0/100), doc 05 OB had palette drift — FVG is the only family whose renderer computes the spec exactly.
- Frozen→hist promotion at 20 bars and fulfilment cap=30 are sane.
- No color-scheme divergence from spec. Expected 85 (only family with clean renderer).

---

## P5. Pipeline (evidence flow)

```
FVGDetector (new bars -> detect) 
   -> CFVG/DB class produce gap objects (fill, invalidation, classified but dead) 
   -> ConfluenceEngine CE:322 raw==0 → since componentCount=0 
   -> layerContribution   -> fvgRaw=0.00 (THR asserts fraw==0)
   -> Rules 3/4 (OB_FVG) — UntouchedFVG path: NO recency, NO fill guard
   -> confidence 0.35/0.40 (ruleConfidence 0.80 ± trend bonus)
   -> ENTRY_FVG_MIDPOINT (mid entry, only consumer = TARGET_OP_FVG honors invalidated)
   -> Validator min 0.60 → **0 of 12,320 admitted** (gate reversal, family-wide)
```

### Pipeline findings

| P05 | Claim | Evidence |
|---|---|---|
| P5.1 | FVG cannot be measured in telemetry — no raw, no layer, dead classifier | F19, F20, F14, F15 |
| P5.2 | The live gate admits **nothing** from this family (max conf 0.40 < 0.60) | probe P6.3 |
| P5.3 | Filled / invalidated / 500-bar-old gaps are still matchable in the rule | F16, F17, F13 |
---

## P6. Evidence (read-only, Sprint 17 frozen set)

### P6.1 Family definition and flag exactness

| Fact | Value |
|---|---|
| Family = firedRuleId 3\|4 (OB_FVG). FVG never fires alone in the EA — it is always paired with OB | n=12,320 (72.16% of all 17,073 signals) |
| `hasFVG='2'` ⇔ rules 3\|4 | **0 mismatches both ways** (probe) |
| `layerStructural` for family | **25 exactly** (= OB 15 + FVG 10), unique=1 |
| `layerConfirmation` | 10 → n=3,386 (no trend bonus) · 15 → n=8,934 (trend bonus) |
| `layerTotal` | 35 (n=3,386) · 40 (n=8,934) |
| `fvgRaw` / `fvgWeight` / `fvgContribution` | **unique=1 each → const 0.00** (T01 4th family) |
| `hasProtectedPoint='2'` anywhere | **0 of 18,536 decided rows** (T01 re-confirm) |

### P6.2 Headline

| Split | n | wr | vs base (+0.3321) |
|---|---|---|---|
| **FVG family (rules 3\|4)** | 12,320 | **0.3388** | +0.7pp |
| OB_FVG_BULLISH (rule 3) | 6,412 | **0.3036** | −2.9pp |
| OB_FVG_BEARISH (rule 4) | 5,908 | **0.3769** | +4.5pp |
| meanR family / bullish / bearish | — | — | +0.0097 / −0.0946 / +0.1229 |
| medianR family | — | — | −1.0000 |

### P6.3 Gate reversal (family-wide, worst case)

- All family confidences ∈ {0.35, 0.40}; ruleConfidence **0.80 for both rules**; the only variation is the trend bonus.
- **Admitted by conf ≥ 0.60 gate: 0 of 12,320.** Max achievable conf is 0.40 — the family is *structurally* un-enterable.
- Family admission rates for comparison: Liquidity 89.4% (n=3,178 of 3,553), **OB_FVG 0.0%**. The live funnel runs *only* the family measured worst in doc 04.
- conf 0.35 vs 0.40 is a pure "trend-bonus" split, no other conf variance.

### P6.4 Trend-alignment bonus is value-negative (S3)

| Split | n | wr |
|---|---|---|
| layerConfirmation=15 (trend-aligned, bonus granted) | 8,934 | **0.3339** |
| layerConfirmation=10 (no bonus) | 3,386 | **0.3517** |
| — per rule: BULLISH aligned vs not | 4,654 / 1,758 | 0.3060 / 0.2975 (+0.9pp, bonus *helps* bullish) |
| — per rule: BEARISH aligned vs not | 4,280 / 1,628 | **0.3643 / 0.4103 (−4.6pp, bonus *hurts* bearish)** |

The trend bonus is granted to rows that are worse-performing overall, and the harm is concentrated in the bearish rule — which is exactly the rule carrying the family's edge (0.3769). Since conf never reaches 0.60, the bonus additionally has **zero effect on admission** — it is pure dead weight today.

### P6.5 Direction asymmetry flips by symbol (S5) — corrects doc 05's "bullish weak"

| Cell | BULL n / wr | BEAR n / wr | Δ (BEAR−BULL) |
|---|---|---|---|
| EURUSD M15 | 4,368 / **0.2942** | 4,096 / **0.3896** | +9.5pp |
| EURUSD H1 | 864 / **0.2674** | 1,042 / **0.3858** | +11.8pp |
| GBPJPY H1 | 1,180 / **0.3653** | 770 / **0.2974** | **−6.8pp (flip)** |

The doc 05 "OB_FVG_BULLISH weak" narrative is an artifact of EURUSD dominance (10,370 of 12,320 rows). On GBPJPY the asymmetry inverts. This is a focused hypothesis for Sprint 20+, **not** a code change.

### P6.6 Hours — h22-23 drain 4th replication, bullish-only

| Hour | BULL n / wr | BEAR n / wr | family n / wr |
|---|---|---|---|
| h00-07 | 2,191 / 0.3099 | 1,998 / 0.3569 | 4,189 / 0.3323 |
| h08-12 | 1,315 / 0.3262 | 1,167 / 0.3625 | 2,482 / 0.3433 |
| h13-17 | 1,327 / 0.3512 | 1,233 / 0.3423 | 2,560 / 0.3469 |
| h18-21 | 1,024 / **0.2559** | 1,006 / **0.4891** | 2,030 / **0.3714** |
| h22-23 | 555 / **0.2000** | 504 / 0.3512 | 1,059 / **0.2720** |

- h18-21 is the family's best window (0.3714); the BEAR h18-21 cell (0.4891, n=1,006) is the strongest cell in the entire EA dataset to date.
- **BULL h22-23 = 0.2000** — exact match to the Liquidity family's h22-23 (0.2000) in doc 04. The h22-23 drain is now replicated in 4 families (BOS, CHOCH, Liquidity, FVG) and is **bullish-pattern-specific** in FVG.

### P6.7 Day-of-week — flat

Mon 0.3294 · Tue 0.3344 · Wed 0.3333 · Thu 0.3443 · Fri **0.3523** (best, consistent with doc 05).

### P6.8 Co-occurrence and alternatives

| Comparison | n | wr |
|---|---|---|
| OB_FVG (FVG+OB, no BOS/CHOCH — 0 co-occurrences by construction) | 12,320 | 0.3388 |
| BOS_OB (rules 1\|2, OB+BOS, no FVG) | 858 | **0.3730** |
| CHOCH_OB (rule 7, OB+CHOCH, no FVG) | 342 | 0.3567 |

Swapping the BOS condition for an FVG condition costs 3.4pp (0.3730 → 0.3388) at similar rule-confidence levels — FVG adds the *least* structural value of the three OB-rule variants (doc 05 F2 reprised, now with FVG attribution).

### P6.9 Exit shape (family)

exitReason 2 (SL) n=8,111 · 1 (BE) n=4,085 · 4 (TP) n=124 — same shape as Liquidity (2,481/1,021/51) and OB (8,644/4,405/129); BE dominates over TP in all families (evidence of tight, stop-side exits).

### P6 verdict

The *presence* of an FVG (flag) is measurable and exact, but its *quality* is not (S1). Where quality proxies can be built from the data (trend bonus, direction × cell, hours), the signals are unambiguous and falsifiable: the bonus is value-negative (P6.4), the asymmetry is cell-dependent not global (P6.5), and the h22-23 drain is bullish-specific and now 4× replicated (P6.6).
---

## P7. Targeted experiments (falsifiable; all read-only)

| E# | Hypothesis (null) | Test | Falsifies | Confidence | Destination |
|---|---|---|---|---|---|
| E1 | Recency/invalidation gate on Untouched-FVG path changes wr | wr of ≤20-bar unmitigated gaps vs current unbounded path (simulated from flags — requires gap timestamps, blocked by S1 until telemetry exists) | F16/F17 | High | Sprint 20 E1 (telemetry first) |
| E2 | Displacement-body gate (B ≥ 5 pips) changes wr | wr by candle-B body bucket — **blocked: body size never serialized (S1)** | F3/F14 | Medium | Sprint 20 E1 |
| E3 | Trend bonus removal equalizes BEARISH aligned/unaligned | wr(4, aligned) vs wr(4, unaligned) after bonus removal — currently 0.3643 vs 0.4103 | P6.4 | High | Sprint 20 R14 (priority 2) |
| E4 | h22-23 bullish exclusion is harmless | wr of family excluding BULL h22-23 (0.2000 cell) vs current | P6.6 | High | Sprint 20 R14 (priority 2) |
| E5 | Direction×cell is stable across months | split of EURUSD BEAR vs GBPJPY BULL by month | P6.5 | Medium | Sprint 21 experiment |
| E6 | Significance filter (M37) marks FVG family differences real | HP filter on all P6 splits | P6 | High | Sprint 21 experiment |

---

## Proof matrix

| Doc § | Method | Evidence location | Confidence | Status |
|---|---|---|---|---|
| P3 F1-F22 | verbatim (META-5.3) | FVGDetector.mqh, ConfluenceRules.mqh, ConfluenceEngine.mqh, TelemetryTypes.mqh, EPR, SC | high | verified (F3/F9/F10/F11 verbatim re-read 2026-08-03; F12-F22 harvest-verified adjacent) |
| P6.1 | dataset check (META-5.1) | probe avp19_6_fvg_evidence.py | high | verified |
| P6.2-P6.9 | dataset check (META-5.1) | probe | high | verified |
| P6.4 | dataset check | probe (conf≡lc mapping exact: 0.35≡10, 0.40≡15, 0 mismatch) | high | verified |
| P7 E1-E6 | falsifiable (AVP §4.13) | none yet | — | pending |

## Traceability (claims → code)

| Claim | Code ref |
|---|---|
| wick-to-wick gap definition | FVGDetector.mqh:203-242 (verbatim) |
| gap only needs 0.1 point to exist | FVGDetector.mqh:133 |
| 5-pip body min on A and C, **never B** | FVGDetector.mqh:179,193-200 |
| time-discontinuity reload | FVGDetector.mqh:144-151 |
| classification dead (never serialized) | FVGDetector.mqh:306-401 (qualityScore forced 1.0 :306; chochId forced -1) |
| fill close-based, fillTime never written | FVGDetector.mqh:368-379 (:375) |
| invalidation trend-opposition only, no expiry | FVGDetector.mqh:383-396 |
| UntouchedFVG no recency / no invalidated guard | ConfluenceRules.mqh:125-147 |
| fvgRaw const 0.00 | ConfluenceEngine.mqh:299 (componentCount=0); TelemetryHealthReport.mqh:346 |
| no layerFVG column | TelemetryTypes.mqh (schema v3: layerStructural/layerLiquidity/layerConfirmation/layerTotal) |
| EXPIRY_FVG_FILLED conflation | ConfluenceEngine.mqh:386-394 |
| ENTRY_FVG_MIDPOINT | EntryPolicyResolver.mqh:35-48 |
| FVG structural +10 | StructuralContribution.mqh:105 |
| clean renderer | FVGRenderer.mqh (dimming math 0.60/0.35; 20-bar promote; MaxHistoricalFVG=30) |

---

## Findings summary

| ID | Severity | System | Outcome class | Sprint | Evidence | Decision |
|---|---|---|---|---|---|---|
| S1 | Very High (P0) | Telemetry (T01/TC) | Implementation defect | 20 E1 | F14/F15/F19/F20; fvgRaw const 0 | Serialize classification + gap timestamps + `layerFVG` |
| S2 | Very High (P0) | Pipeline (gate) | Implementation defect (gate reversal, 3rd family) | 20 E1 | P6.3; 0/12,320 | Routing/gate fix (ledger R11/R13) |
| S3 | High (P2) | Rule logic | Value-negative bonus | 20 R14 | P6.4 (−1.8pp; bearish −4.6pp) | Remove/adjust OB_FVG trend bonus; E3 |
| S4 | High (P1) | Rule logic | Missing qualification (freshness/invalidation) | 20 E1 | F16/F17 | Recency + unmitigated guard (same family as OB S3) |
| S5 | High (P2) | Evidence | Oversimplified narrative | 21 exp | P6.5 (flip at GBPJPY) | Cell-level hypothesis, not a change |
| S6 | Medium (P2) | Detection | Wrong-candle filter | 20 E1 | F3/F2 | Move min-body gate to candle B; E2 |
| S7 | — (positive) | Detection | Best-in-class reload | — | F10 | Keep; extend to rates_total-shrink (E11 partial) |
| F1 | High (P2) | Evidence | Cross-family h22-23 drain, bullish-specific | 20 R14 | P6.6 (0.2000 = doc 04 value) | E4 |
| F2 | High (P2) | Evidence | h18-21 BEAR 0.4891 strongest cell in dataset | 21 | P6.6 | — |
| F3 | High (P2) | Evidence | BOS_OB beats OB_FVG by 3.4pp | 21 | P6.8 | — |
| F4 | Medium (P1) | Evidence | OB_FVG_BEARISH 0.3769 above base +4.5pp | — | P6.2 | — |
| F5 | Medium (P2) | Evidence | trend bonus has zero admission effect (conf never ≥0.60) | — | P6.3/P6.4 | — |

---

## Scorecard

| Axis | Score | Note |
|---|---|---|
| Research Quality | 90 | Doctrine mapped; fill-rate claims flagged unsourced; falsifiable tests sharp |
| Implementation Quality | 60 | Dead classifier serialization, wrong-candle filter, no recency/invalidation guard; reload handling only bright spot |
| Architecture Quality | 72 | CE:299 componentCount=0 is family-wide; no layerFVG column; reload pathway shows design can do better |
| Visualization Quality | 85 | Only family with fully spec-correct renderer math |
| Evidence Quality | 58 | Flag-only (raw dead); strong exactness checks; several P7 tests blocked by S1 |
| Confidence | B | Flag/layer proxies exact; quality proxies blocked |
| **Overall** | **70/100 — IMPROVE** | Consistent with series trend (64/66 → 70) |

## Final verdict

The FVG implementation's **core 3-candle wick-to-wick definition is doctrinally correct** and its **reload handling is the best in the EA** — the component itself is not the problem. The problems are the same two platform faults documented since 19.4: measurement is impossible (S1) and the live gate admits nothing from this family (S2), plus the rule's trend bonus actively selects worse rows (S3). None of this can be fixed in the detector; it is resolved by Sprint 20 platform engineering (telemetry → gating/routing → lifecycle). This is the 4th and final component of the Sprint 19 AVP series — see doc 08 (cross-system synthesis) for the integrated matrix and Sprint 20 plan.

---
<!-- PART4 -->
