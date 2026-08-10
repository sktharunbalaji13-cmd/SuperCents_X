# Sprint 21 — Phase 3: Research Synthesis (RL01)

Status: **DRAFT FOR REVIEW — not committed, not frozen.** Phase 3 output per protocol §15.
Foundation: frozen protocol (`docs/Sprint21_ResearchReview_Protocol.md`, commit `0ce1291`) and committed Phase-2 ledger (`docs/Sprint21_EvidenceLedger.md`, commit `2dc37a5`) as the sole classification foundation. ED01-B/C/D/E decisions referenced as frozen E1-population evidence (protocol §10.4, §12.3), not re-analyzed.

Synthesis is descriptive — it ranks, it does not decide (protocol §15).

---

## 0. Boundaries preserved (protocol §16, guardrails)

| Boundary | Status in this document |
|---|---|
| RL-SWING-01-C01 | NOT-SELECTED pre-registration seed only (ledger §8, RL-HYP-01). Not promoted by this synthesis. |
| RL-OBS-01 (UNKNOWN-family 2.5R/3R) | REPORTED-NOT-WEIGHED. Phase 2 produced NO independent literature justification of a UNKNOWN-family mechanism (ledger Appendix, line 1735). Not promoted. |
| Conflicting literature | Remains conflicting — all 4 conflict rows stay UNRESOLVED; this synthesis reports asymmetry, resolves nothing (protocol §10.2). |
| No hypothesis promotion without independent justification | Applied throughout §7. Only ledger rows that already carry a Hypothesis field qualify for the Phase 4 shortlist. |
| No experiment design disguised as synthesis | This document describes gaps and ranks evidence; it designs no treatment, no IV/DV table beyond the ledger's existing RL-HYP-01 seed. |
| No production change / no commit | None made. This is a document draft for user review. |

---

## 1. Evidence base recap (from the ledger, all counts post-verification)

64 claims across 28 papers (7 topics). E-levels: E1:3, E2:35, E3:24, E4:2, E5:0. Evidence tags: EMPIRICAL 47, THEORETICAL 14, INTERPRETATION 2, UNSUPPORTED 1 (RL-OB-04-C02). Directions: pos 37 / neg 4 / null 7 / not-stated 16.

**Critical structural fact:** the only E1 claims in the entire ledger are RL-SWING-01-C01/C02/C03 — three claims from a single paper (Rak 2026, WARNING-REPRO-PENDING). There is no other E1 literature claim. This single fact drives the entire tier structure below: no mechanism can reach "strongly supported" (§15.1 requires ≥ 2 independent E1 claims agreeing).

ED01 sequence (frozen, E1 for the SuperCents_X population per protocol §10.4): ED01-B REJECT (no distinct liquidity edge; FVG-carried pooled gap), ED01-C DEFER (FVG level split, 7<10 paired days), ED01-D EVIDENCE FIXED-2R better than opposing-liquidity TP (Δ −0.7210, CI [−1.1915, −0.2621]), ED01-E REJECT — 2.0R REMAINS BEST (TP-distance flat in [1.0, 3.0]R).

---

## 2. Tier assignment (protocol §15.1–§15.4)

| Tier | Mechanism area | Basis |
|---|---|---|
| **Strongly supported** (§15.1) | **None** | No ≥2 independent E1 claims agree on any mechanism; the only E1 source is a single paper (RL-SWING-01) with a REPRO-PENDING flag |
| **Moderately supported** (§15.2) | CHOCH (feasibility/identifiability) | 9 positive + 2 not-stated, 0 negative across E2:5/E3:6; no intra-topic conflict. Caveat: construct transfers (inventory/VIX/electricity, not FX) |
| | OB (mechanism existence) | 9 positive + 2 not-stated, 0 negative across E2:5/E3:6; imbalance → short-horizon price move is supported at mechanism level |
| | Swing/trend — positive side | 1 E1 source (RL-SWING-01, 3 claims) vs E2 negatives — asymmetric conflict, so the positive side is at best moderate and is contradicted (see Contradictory) |
| **Weak / limited** (§15.3) | FVG (tradability), Liquidity, SMC | Single E2 nulls / E3-only / E4 survey; data-boundary limits |
| **Contradictory** (§15.4) | Swing/BOS, CHOCH-adaptive, FVG, OB | All 4 ledger conflict rows, analyzed in §5 |

---

## 3. Mechanism-by-mechanism synthesis

For each mechanism: evidence → strength → agreement/conflict → SuperCents_X assumption → ED01 evidence → research gap → candidate hypothesis.

### 3.1 Swing / Trend continuation (12 claims: SWING-01..04)

**Evidence.** E1:3 (SWING-01-C01/C02/C03 — VGRSI visibility-graph signals, EUR/USD + DJI30 + XAU/USD, 503 days 2024–2025, walk-forward with 30-day optimization window; WARNING-REPRO-PENDING). E2:9 — SWING-02-C01/C02/C03 (trend decay post-2009, tick-size mechanism, self-fulfilling impact loop; ~100 futures 1995–2025; COMMERCIAL/CFM), SWING-03-C01/C02/C03 (horizon-blend matters / controversy / ultra-short contested; COMMERCIAL/Ai-For-Alpha), SWING-04-C01/C02/C03 (MNQ 5-min 947 days 2021–2025: nothing passes cost-aware gates; gross edge ceiling 0.07–1.50 pts vs 2.0 pts friction; best signal failed on n=22).

**Strength.** Moderate at best on the positive side (single E1 source, REPRO-PENDING, optimization-window dependency recorded in SWING-01-C03); negative/decay side is multi-source E2 and agrees internally (SWING-02-C01/C03, SWING-04-C01/C02/C03).

**Agreement / conflict.** RL-CONFLICT-01: SWING-01-C01/C02 (E1 positive) vs SWING-02-C01/C03 (E2 negative) + SWING-03-C03 (E2 null). Asymmetry: E1 (single paper, short FX window, walk-forward with re-optimization) vs E2 (multi-asset futures, 30-year span, CTA evidence). The conflict is UNRESOLVED and carried.

**SuperCents_X assumption touched.** StructuralPivotEngine swing hierarchy; swing significance for admission; fixed M15/H1 horizon use; fixed parameter sets (no rolling re-optimization); trend-continuation edge assumed persistent.

**ED01 evidence.** ED01-B: BOS family +0.0079 (neutral, no distinct edge, E1 FX) — supports the negative side. ED01-E: no fixed-RR tier beats 2.0R — the exit side is flat; neither rescues nor kills the swing-entry question. No ED01 experiment tested swing-gating itself.

**Research gap.** (a) Swing-significance gating on EURUSD H1 entries is untested against the 2.0R benchmark — telemetry NOT-IMPLEMENTED. (b) Horizon choice (M15 vs H1 vs blended, SWING-03-C01) is unresolved in the literature and untested on SCX population. (c) The engine's fixed-policy approach is directly challenged by SWING-01-C03's optimization-window dependency and SWING-02-C03's fragility-of-channel claim — but changing to rolling re-optimization would be a design decision beyond the evidence's support (SWING-01 is a single source).

**Candidate hypothesis.** RL-SWING-01-C01 (ledger §8, RL-HYP-01): "If swing-significant pivots on EURUSD H1 carry forward information, then swing-gated entries beat non-gated entries vs 2.0R" — already recorded as NOT-SELECTED pre-registration seed, carried forward unchanged. This is the only ledger row in this mechanism with a Hypothesis field.

### 3.2 BOS — Break of Structure / Support-Resistance (6 claims: BOS-01..03)

**Evidence.** E2:2 (BOS-03-C01/C02: prices more likely re-bounce than cross S/R; self-reinforcement of held levels — equities, memory-effect study). E3:4 (BOS-01-C01/C02 optimal-stopping S/R model, theoretical; BOS-02-C01/C02 fuzzy-system representation, simulation-only WARNING).

**Strength.** Weak-to-moderate. The only empirical claims (BOS-03) are E2 on equities and both point AGAINST the BOS-continuation premise (re-bounce > cross is the finding; the more bounces, the higher the bounce probability). The theoretical papers (BOS-01, BOS-02) establish that S/R structure can be formalized as state transitions / price-driving mechanisms — mechanism existence only, no edge claim, no FX evidence.

**Agreement / conflict.** No intra-topic conflict row; BOS participates in RL-CONFLICT-01 (its re-bounce finding supports the negative side of the swing/BOS continuation question). BOS-03-C01/C02 direction (negative for continuation) is the strongest empirical statement in this topic.

**SuperCents_X assumption touched.** BOS continuation detector (break of structure → trend continuation, floor 0.35); S/R levels as entry/exit decision points; 2R exits.

**ED01 evidence.** ED01-B: BOS family nClosed 378, Mean R +0.0079, CI gates failed — no distinct BOS edge on FX (E1 for SCX population). Consistent with BOS-03's re-bounce-not-cross caution.

**Research gap.** The engine treats a validated S/R break as a continuation signal; the literature's best empirical statement is that held levels repel (BOS-03). No experiment has tested BOS continuation vs reversal framing on the SCX population. This is a genuine gap but with weak literature support (E2 equities only) — hypothesis-generating only per §15.3.

**Candidate hypothesis.** NONE — no ledger row in BOS carries a Hypothesis field. Not shortlisted.

### 3.3 CHOCH — Change-point / Regime detection (11 claims: CHOCH-01..05)

**Evidence.** E2:5 — CHOCH-01-C01/C02 (non-parametric segmentation, LSE inventory series), CHOCH-04-C02 (VIX COVID break detection), CHOCH-05-C01/C02 (NOT change-point calibration windows, electricity forecasting, improvement vs ARHNN). E3:6 — CHOCH-02-C01/C02/C03 (deep-RL regime filtering, simulation + equity pairs, WARNING-simulation-only), CHOCH-03-C01/C02 (telegraph process identifiability, theoretical), CHOCH-04-C01 (offline change-point under nonlinear dependence, numerical studies).

**Strength.** Moderate for feasibility/identifiability: 9 positive + 2 not-stated, zero negatives. Regime/change-point structure IS detectable from series structure alone, without order-flow state (CHOCH-02-C01 explicitly: latent parameters filtered from the signal alone). But every empirical claim is a construct transfer (inventory, VIX, electricity, pairs) — no FX price-pattern evidence. The adaptive-policy cluster (CHOCH-02) is E3 simulation-only.

**Agreement / conflict.** No intra-topic conflict. Cross-topic: RL-CONFLICT-02 — CHOCH-02 (E3 positive, adaptive policies improve profitability+robustness) vs fixed-policy design assumptions (E2 era/cost evidence) — symmetric weakness (E3 simulation vs E2 decay/cost), UNRESOLVED.

**SuperCents_X assumption touched.** CHOCH detector = reversal on structural change (price-pattern based, no probabilistic regime model); fixed floors/weights/2.0R across regimes; fixed windows.

**ED01 evidence.** ED01-C: FVG HIGH vs LOW level split DEFER (7<10 paired days) — not a CHOCH test but records the population's structural pairing scarcity. ED01-E: fixed 2.0R robust across tiers (E1) — the fixed-policy side of RL-CONFLICT-02 has E1 support on the SCX population. CHOCH-family rows: ED01-B decomposition shows CHOCH nClosed = 0 on H1 — the family barely fires on this population (structural absence, not a verdict).

**Research gap.** (a) Regime-conditioned calibration windows (CHOCH-05) are a working principle with E2 forecasting evidence — the engine has fixed windows; untested for SCX trading PnL (forecast accuracy ≠ PnL, recorded in the ledger). (b) Probabilistic regime-probability encoding (CHOCH-02) is E3 and would require a regime-probability estimator on OHLCV — construct transfer, plus ED01-E tension recorded. (c) The engine has no continuous regime state; only discrete CHOCH pattern firing.

**Candidate hypothesis.** NONE — no CHOCH ledger row carries a Hypothesis field. RL-CONFLICT-02's resolution text ("experiment needed only if literature independently justifies adaptive exits — not yet") stands; this synthesis adds no new justification.

### 3.4 Order Blocks / Order-flow imbalance (11 claims: OB-01..05)

**Evidence.** E2:5 — OB-01-C01/C02/C03 (OFI explains short-term price changes; construction raises OOS R² 33–43% → 84–86% at 30s/1m/5m; log-GOFI scale-stable — CSI 500), OB-02-C01 (Hawkes kernels fit real LOB data), OB-03-C02 (empirical H0 ≈ 3/4). E3:6 — OB-02-C02 (simulator fidelity partial), OB-03-C01 (fractional flow theory), OB-04-C01/C02 (square-root law, model-internal simulation; C02 is the ledger's only UNSUPPORTED tag — the paper itself disclaims real-market confirmation), OB-05-C01/C02 (microstructure mean reversion at seconds scale, theoretical-only).

**Strength.** Moderate for mechanism existence: 9 positive + 2 not-stated, 0 negative. Imbalance measures demonstrably carry short-horizon predictive content — at book level, at high frequency, on equities/crypto. Direction agreement is strong within the topic.

**Agreement / conflict.** RL-CONFLICT-04: OB-01-C01/C02 (E2 positive, mechanism) vs SWING-04-C01/C02 (E2 null, OHLCV cost ceiling). Asymmetry: symmetric E-levels; the conflict is between "the mechanism exists (with book data)" and "OHLCV-only signals fail cost gates" — i.e., a **data-class conflict**, not a mechanism conflict. UNRESOLVED, carried.

**SuperCents_X assumption touched.** OB detector = displacement + break + unmitigated zone as an OHLC imbalance proxy (floor 0.35/0.40); the proxy is the whole of the engine's flow observation.

**ED01 evidence.** ED01-B decomposition: ORDER_BLOCK nClosed = 0 on EURUSD_H1 — the family structurally does not fire on this population; there is no E1 evidence for the OB family at all. ED01-D/E are exit-side and neutral for the entry mechanism.

**Research gap.** (a) The OHLC displacement proxy has no equivalent of GOFI's construction/stationarization (OB-01-C02/C03) — the proxy is weaker than the demonstrated book-level construct, and unexplained variance dominates at coarser scales. (b) The engine cannot observe signed flow, order signs, or LOB state (OB-03, SMC-01) — persistence claims untestable from OHLCV (recorded per claim). (c) No E1 (FX) evidence exists for ANY OB mechanism; the gap between E2 equities/crypto and E1 FX is unfilled.

**Candidate hypothesis.** NONE — no OB ledger row carries a Hypothesis field. RL-CONFLICT-04's resolution ("experiment needed only if a tradable OB mechanism is pre-registered") stands; no new justification is produced by this synthesis.

### 3.5 FVG — Fair Value Gap / imbalance zones (8 claims: FVG-01..03)

**Evidence.** E2:8 — FVG-01-C01/C02/C03 (price-gap power-law tails, long-range correlation, non-universality — 26 A-share stocks), FVG-02-C01/C02/C03 (gaps/depth → immediate price impact up to 44%; opposite-side liquidity dominates — SZSE), FVG-03-C01/C02 (VVG day classifier distinguishes days, but NO deployable strategy; 8 configs failed gates — MNQ 947 days).

**Strength.** Weak for tradability, moderate for structure-mechanism. Structure-positive cluster (FVG-01-C02 long memory, FVG-02-C01/C03 gaps/depth drive impact) vs tradability-null cluster (FVG-03-C02 nothing deployable; FVG-01-C03 non-universality).

**Agreement / conflict.** RL-CONFLICT-03: FVG-02-C01/C02 (E2 positive, mechanism) vs FVG-03-C02 (E2 null, tradability). Asymmetric in CONTENT (both E2; different markets — equities vs MNQ futures): the mechanism exists at book level; the tradeable edge does not materialize under cost-aware gates.

**SuperCents_X assumption touched.** FVG detector 3-candle imbalance (low1 > high3); FVG zones as entry zones; uniform parameters across EURUSD/GBPJPY (FVG-01-C03 warns non-universality); TP placed at opposing liquidity.

**ED01 evidence.** ED01-B: FVG family Mean R +0.1604 (best family) BUT the pooled liquidity-vs-non-liquidity gap is FVG-carried (−0.0300 when FVG removed) — composition sensitivity recorded; no EVIDENCE verdict. ED01-C: FVG HIGH/LOW level split DEFER (7 paired days). ED01-E: TP tiers flat. The positive FVG point estimates never cleared a pre-registered gate.

**Research gap.** (a) FVG is the only family with positive conditional-expectancy point estimates on FX (ED01-B), yet no pre-registered gate cleared — the family is the strongest candidate for a *level/parameter* experiment, and ED01-C could not resolve it (paired-day scarcity). (b) Gap-size distribution is heavy-tailed (FVG-01-C01) — engine assumes no size distribution; extreme imbalances possible. (c) FVG-02-C03's opposite-side-liquidity dominance is directionally consistent with ED01-D's opposing-TP finding.

**Candidate hypothesis.** NONE — no FVG ledger row carries a Hypothesis field. RL-CONFLICT-03's resolution ("experiment needed if any FVG-specific mechanism is pre-registered") stands. The ED01-C DEFER + ED01-B composition-sensitivity results are recorded as the empirical facts this area contributes; no promotion.

### 3.6 Liquidity (8 claims: LIQ-01..04)

**Evidence.** E2:1 (LIQ-04-C01 liquidity-change detectability, order-driven market). E3:5 (LIQ-02-C01/C02 optimal provision theory; LIQ-03-C01/C02 HFT-artificial-market simulation, WARNING-simulation-only; LIQ-04-C02 Cox-process optimality). E4:2 (LIQ-01-C01/C02 survey definitions, REGIME-AGE, INTERPRETATION tags).

**Strength.** Weak. The weakest-mechanism cluster in the ledger: only one E2 claim, one E3 with real-data validation (LIQ-04), two E4 survey items. Directions mixed descriptive (pos 3 / not-stated 5, 0 negative, 0 null).

**Agreement / conflict.** No intra-topic conflict. LIQ-03 (HFT improves liquidity, E3 simulation) vs nothing opposing — but simulation-only.

**SuperCents_X assumption touched.** LIQUIDITY detector (EQH/EQL + sweep, floor 0.60); liquidity treated as uniform across sessions (LIQ-01-C02: intra-daily liquidity is time-of-day/news-dependent — unaddressed dimension); engine is a taker, not a provider (LIQ-02 framework is the opposite role — Gap NONE).

**ED01 evidence.** ED01-B: REJECT / NO DISTINCT LIQUIDITY EDGE — LIQUIDITY family Δ −0.1164 (CI [−0.2006, +0.0950] includes 0) on EURUSD_H1; GBPJPY −0.0607; M15 −0.1872 (evidence-only). ED01-D: the opposing-liquidity TP (which fires exactly on LIQUIDITY sweep rows) is materially WORSE than fixed-2R (Δ −0.7210, EVIDENCE). The E1 FX picture for liquidity is: no distinct entry edge, and the liquidity-conditional TP policy is a documented negative.

**Research gap.** (a) Time-of-day/session liquidity conditioning is absent (LIQ-01-C02) — E4-only support, hypothesis-generating per §15.3. (b) Liquidity-level regimes (LIQ-04) are detectable with LOB data; the engine has no continuous liquidity state — data-boundary. (c) Execution-rate as liquidity indicator (LIQ-03-C02) is E3 simulation proposal only.

**Candidate hypothesis.** NONE — no LIQUIDITY ledger row carries a Hypothesis field. ED01-B explicitly records "no evidence a liquidity-specific entry experiment is worth prioritizing" — this synthesis concurs on the current evidence.

### 3.7 SMC — Smart Money / informed flow (8 claims: SMC-01..04)

**Evidence.** E2:5 — SMC-01-C01/C02 (equity order-flow persistence; sub-hour persistence = splitting not herding, LSE P1), SMC-02-C01 (participant decisions depend on liquidity imbalance, labelled trade data), SMC-04-C01/C02 (wallet informativeness persistent, rank corr 0.52; wallet activity +13.2% OOS R² at 1s, t=9.2 — DEX data). E3:3 — SMC-02-C02 (latency erodes imbalance value, theoretical), SMC-03-C01/C02 (adverse-selection quote optimization, Nash equilibrium, theoretical).

**Strength.** Moderate for mechanism existence (informed/persistent flow is real and measurable at order level — SMC-04 is strong E2 evidence), but the mechanism is **not observable from OHLCV**: 6 positive, 1 negative (latency), 1 not-stated.

**Agreement / conflict.** No intra-topic conflict. Cross-topic: none of the 4 conflict rows is SMC-specific; the mechanism sits behind RL-CONFLICT-04's "data class" framing.

**SuperCents_X assumption touched.** SMC/informed-flow concepts (smart money footprints, directional persistence of order flow) as background for entry/regime reasoning.

**ED01 evidence.** No ED01 experiment targets SMC directly (SMC is not a rule family in the decomposition — families are FVG/BOS/LIQUIDITY/UNKNOWN/CHOCH/ORDER_BLOCK). The closest E1 facts: ORDER_BLOCK family never fires (ED01-B); UNKNOWN-family (rows with no fired rule) is the worst-expectancy family (Mean R −0.2821 at 2R) with exploratory wider-tier recovery (RL-OBS-01, reported-not-weighed).

**Research gap.** (a) The "smart money leaves OHLCV-detectable footprints" premise is UNSUPPORTED by the ledger — the evidence supports footprint existence at order/wallet level (E2, equities/DEX) and at 1-second horizon (SMC-04), which is below engine cadence and outside engine data class. (b) Latency (SMC-02-C02) is a structural blocker for any imbalance-exploitation at fast scale; the engine's bar-cadence design already accepts this. (c) No E1 evidence exists for any SMC-observable proxy on FX.

**Candidate hypothesis.** NONE — no SMC ledger row carries a Hypothesis field. Per protocol §15.5, the SMC assumptions that lack support are listed in §6 below, not promoted.

---

## 4. Contradictory findings (protocol §15.4 — all four, unresolved)

All four ledger conflict rows are reported here with their evidence asymmetry; **none is resolved in this document** (guardrail 6).

1. **RL-CONFLICT-01 — Swing/BOS continuation.** Positive side: RL-SWING-01-C01/C02 (E1, single paper, FX, REPRO-PENDING, optimization-window dependency). Negative side: RL-SWING-02-C01/C03 (E2, ~100 futures 30y, era-decay + impact-loop fragility), RL-SWING-03-C03 (E2 null, ultra-short contested), RL-BOS-03-C01 (E2, re-bounce > cross). Asymmetry: E1 single-source short-window vs E2 multi-source long-span. ED01-B BOS +0.0079 (E1 FX) supports the negative side. **Net:** the literature's strongest empirical statements (BOS-03, SWING-02, SWING-04) are negative or null for OHLCV continuation edge; the single positive E1 is contested and unreproduced. Unresolved — carried to Phase 4 as RL-HYP-01's conflict flag.

2. **RL-CONFLICT-02 — Adaptive vs fixed policy.** Positive side: RL-CHOCH-02-C01/C02/C03 (E3, simulation, regime-probability encoding). Negative side: fixed-policy evidence — RL-SWING-02-C01 (E2 era-decay), RL-SWING-04-C02 (E2 cost ceiling), plus ED01-E (E1: no tier beats 2.0R). Symmetric weakness (E3 vs E2); ED01-E E1 favors fixed. **Net:** no independent justification for adaptive exits yet — the ledger's recorded resolution stands.

3. **RL-CONFLICT-03 — FVG mechanism vs tradability.** Positive side: RL-FVG-02-C01/C02 (E2, gaps/depth drive impact). Negative side: RL-FVG-03-C02 (E2, no deployable strategy; 8 configs failed). Both E2, different markets. ED01-B (FVG no distinct edge at E1, composition-sensitive) and ED01-C (DEFER) support the null side. **Net:** structure-positive, tradability-unproven — the ledger's recorded resolution stands.

4. **RL-CONFLICT-04 — OB mechanism vs OHLCV data class.** Positive side: RL-OB-01-C01/C02 (E2, OFI explains price changes). Negative side: RL-SWING-04-C01/C02 (E2, OHLCV signals fail cost gates). Both E2. ED01-B ORDER_BLOCK nClosed=0 (E1, structural absence) supports the null side. **Net:** the mechanism is real at book level; the OHLCV proxy is not demonstrated — data-class boundary, not mechanism contradiction. The ledger's recorded resolution stands.

---

## 5. Unsupported SMC / structure assumptions (protocol §15.5)

Pairs each unsupported assertion with the SuperCents_X assumption it touches. No new claims are added; this lists what the ledger already marks unsupported.

1. **"Smart money leaves OHLCV-detectable footprints"** — UNSUPPORTED. Evidence shows informed flow is real (SMC-04-C01/C02 E2, wallet-level; SMC-01-C01 E2 persistence) but every detection result requires order/wallet/identity data the engine does not have. Touches: SMC/informed-flow background assumptions in the entry engine.
2. **"OB displacement proxy ≈ order-flow imbalance"** — UNSUPPORTED. RL-OB-01-C02 (E2) shows construction quality dominates explanatory power (33–43% → 84–86%); the engine's proxy has no equivalent construction. RL-OB-04-C02 is the ledger's only UNSUPPORTED-tag row (square-root-law mechanism, paper self-disclaims). Touches: OB detector zone structure as imbalance proxy.
3. **"Liquidity is observable from OHLC price action"** — UNSUPPORTED. RL-LIQ-01-C01 (E4) defines liquidity via spread/transaction cost; engine infers from OHLCV. Touches: LIQUIDITY detector EQH/EQL + sweep, floor 0.60.
4. **"Gap properties transfer across instruments"** — UNSUPPORTED. RL-FVG-01-C03 (E2, null) non-universality across stocks. Touches: shared FVG parameters across EURUSD/GBPJPY.
5. **"Fixed parameters survive regime change"** — the ledger's counter-evidence is E2 (SWING-02 era-decay, SWING-04 cost ceiling) and the fixed side has E1 support (ED01-E). Recorded as RL-CONFLICT-02; not an unsupported claim per se, but flagged for Phase 4 discipline.

---

## 6. Current SuperCents_X implementation gaps, ranked (protocol §15.6)

Ranked by (evidence strength × assumption exposure). Gap IDs reference ledger rows. This ranks gaps; it designs nothing.

| Rank | Gap (component) | Evidence | Exposure |
|---|---|---|---|
| 1 | Swing-gate on entries untested — telemetry NOT-IMPLEMENTED (entry planner) — RL-SWING-01-C01, §8 ledger | E1 positive (single source, REPRO-PENDING) vs E2 negative | High — the only E1 literature touch-point on the entry side; directly testable vs the frozen 2.0R benchmark |
| 2 | BOS continuation vs reversal framing untested (BOS detector) — RL-BOS-03-C01/C02 | E2 negative for continuation (equities) + ED01-B BOS +0.0079 | High — core SMC-family assumption (break → continue) |
| 3 | FVG level/parameter edge unresolved (FVG detector) — RL-FVG-03-C02, ED01-C DEFER, ED01-B FVG-carried | E2 null tradability + E1 inconclusive (DEFER) | Medium-High — only family with positive point estimates on FX |
| 4 | Time-of-day/session liquidity conditioning absent (LIQUIDITY detector) — RL-LIQ-01-C02 | E4 survey only | Medium (low evidence strength caps it) |
| 5 | Regime-conditioned windows absent (CHOCH detector / calibration) — RL-CHOCH-05-C01/C02 | E2 forecasting (electricity) — forecast ≠ PnL | Medium (construct transfer) |
| 6 | OHLC imbalance proxy lacks stationarization (OB detector) — RL-OB-01-C02/C03 | E2 (equities, book-level) | Low — engine is OHLCV-bound; not implementable without data-class change |
| 7 | Gap-memory / heavy tails unmodeled (FVG detector) — RL-FVG-01-C01/C02 | E2 descriptive (equities) | Low |
| 8 | Regime-probability layer absent (CHOCH/exit policy) — RL-CHOCH-02-C01/C02/C03 | E3 simulation only; ED01-E E1 opposes | Low — E3 not sufficient per §15.3 |

---

## 7. Highest-value research hypotheses, ranked (protocol §15.7)

Per protocol §16, only rows that already carry a Hypothesis field in the ledger qualify. There is exactly one: **RL-SWING-01-C01** (ledger §8, RL-HYP-01, NOT-SELECTED).

| Rank | Candidate | Hypothesis (verbatim from ledger) | Evidence basis | Conflict carried | Status |
|---|---|---|---|---|---|
| 1 | RL-HYP-01 (RL-SWING-01-C01) | "If swing-significant pivots on EURUSD H1 carry forward information, then swing-gated entries beat non-gated entries vs 2.0R" | E1 positive (RL-SWING-01, single source, REPRO-PENDING) tested against E2 negatives | RL-CONFLICT-01 (carried, unresolved) | **NOT-SELECTED** — user decides, Sprint 22+ |

Ranking rationale (evidence strength × gap size × engineering cost estimate): this is the only ledger row with (a) E1 literature evidence, (b) an explicit gap (telemetry NOT-IMPLEMENTED), (c) a defined falsifiable statement with null/IV/DV/population/OOS/materiality/test/failure-condition already in the ledger §8 schema, and (d) an engineering scope estimate (MODERATE, TDD+TT01). No other row satisfies all four.

---

## 8. What did NOT make the shortlist, and why (protocol §13, §16)

| Candidate (would-be) | Reason it does not qualify |
|---|---|
| RL-OBS-01 (UNKNOWN-family 2.5R/3R wider tiers) | REPORTED-NOT-WEIGHED; Phase 2 found NO independent literature justification of a UNKNOWN-family mechanism; promotion requires independent justification (§16) — not produced |
| Any OB mechanism hypothesis | No Hypothesis field in ledger; RL-CONFLICT-04 requires "a tradable OB mechanism pre-registered" first — not established |
| Any FVG level/parameter hypothesis | ED01-C DEFER + ED01-B composition sensitivity; no Hypothesis field in ledger; RL-CONFLICT-03 resolution unchanged |
| Any adaptive-exit hypothesis | RL-CONFLICT-02: "experiment needed only if literature independently justifies adaptive exits (not yet)" — CHOCH-02 is E3 simulation-only, ED01-E is E1 against |
| Any liquidity hypothesis | ED01-B REJECT: no distinct liquidity edge; ED01-D: liquidity-conditional TP materially worse; no Hypothesis field in ledger |
| Any SMC hypothesis | Mechanism unobservable from OHLCV; no Hypothesis field in ledger; unsupported-assumption list §5 |

---

## 9. Phase 4 readiness statement

The shortlist carries exactly one NOT-SELECTED seed (RL-HYP-01). Phase 4's job is to complete the full shortlist schema for any candidate the user selects and to pre-register under the ED discipline (protocol §13, §16) — none of that happens in Sprint 21. Selection is a user decision that opens Sprint 22+.

No production change, no protocol change, no commit. This document is a draft for review.

---

*Phase 3 synthesis, DRAFT 2026-08-11. Foundation: protocol FROZEN (0ce1291), ledger 2dc37a5. Boundaries preserved per §0. Next gate: user review of this synthesis; then Phase 4 shortlist; then user selection; then Sprint 22+ pre-registered execution.*
