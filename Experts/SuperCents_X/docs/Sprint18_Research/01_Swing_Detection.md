# Sprint 18.1 — Swing Detection & Market Structure: Deep Research Review

Status: **complete** (research-only; no production changes)

Program: `docs/Sprint18_Research/00_Program_Overview.md`
Dataset: `Evidence/Sprint17/` frozen, fingerprint `2e74bbae…` (18,686 rows)
Method: 8-phase per the locked methodology. Phases 1–5 are literature/industry
survey (no SuperCents_X discussion). Phase 6 is the read-only code review.
Phase 7 is measured evidence only. Phase 8 is the experiment backlog.

---

# Phase 1 — Foundation

## 1.1 What a swing high/low is

A **swing high** is a local maximum in a price series: a bar whose high exceeds the
highs of the bars on both sides. A **swing low** is the mirror image: a bar whose low
is below the lows on both sides. Together, ordered swing points partition the price
path into up-legs and down-legs, and the sequence of higher highs/higher lows
(up) or lower highs/lower lows (down) is the canonical definition of a trend — the
"grammar of charts" (Dow Theory, §3.1).

Because raw tick/candle series are noisy, *useful* swing detection requires two
things the raw definition does not provide:

1. **A confirmation window** — how many bars on each side must verify the extremum
   (the classic is 2 bars each side, i.e. a 5-bar pattern);
2. **A significance filter** — a minimum reversal size, volatility threshold, or
   prominence measure, without which every micro-bounce is a "swing".

These two knobs (window width, significance) are *the* design space of swing
detection, and every school of thought in this document is a different choice
of those two knobs plus a confirmation rule (close-based vs high/low-based).

## 1.2 Origin and historical evolution

- **Dow Theory (1890s–1902, published posthumously by Hamilton 1922, Rhea 1932)**:
  the first codified use of swing peaks/valleys; trends are defined by the sequence
  of "higher highs / higher lows" (bull) or "lower highs / lower lows" (bear), with
  primary/secondary/minor trend hierarchy. Swings are the atomic unit.
- **Wyckoff (1930s)**: swings are the building blocks of accumulation/distribution
  schematics — Selling Climax (SC), Automatic Rally (AR), Secondary Test (ST),
  Spring, Sign of Strength (SOS) — each defined by how price behaves at swing points
  *with volume*.
- **Floor traders / Edwards & Magee (1948)**: swing points as support/resistance
  and as the anchors of trendlines and chart patterns (head-and-shoulders etc.).
- **Merrill (1977)**: the ZigZag formalized as a threshold filter connecting only
  significant peaks/valleys; often credited as the origin of the modern ZigZag.
- **Bill Williams (1995, "Trading Chaos")**: the **5-bar fractal** — five bars with
  the middle bar's high highest (up fractal) or low lowest (down fractal). This is
  the single most widely deployed swing rule in retail platforms (MetaTrader,
  TradingView's `Fractals`, pine `ta.pivothigh/pivotlow` with symmetric lookback).
- **Al Brooks (2009–2012)**: bar-by-bar price action; pivots as the basis of
  High 1/High 2/Low 1/Low 2 pullback entries, breakout/failed-breakout logic, and
  the "trend vs trading range" context question that decides whether a swing level
  matters.
- **ICT / Smart Money Concepts (2000s–)**: "market structure" terminology — swing
  highs/lows as the dealing range boundaries; **internal vs external structure**;
  equal highs/lows as liquidity magnets; MSS/CHOCH/BOS built on swing points.
- **Quantitative era (2000s–)**: swing detection reframed as **change point
  detection** (CUSUM, binary segmentation, PELT, Bayesian online CPD), **local
  extrema prediction** with ML (e.g. XGBoost over multiple timeframes), and
  **topological persistence** (prominence-like robustness from persistent homology).

## 1.3 Mathematical formulation

Given a price series \(p_t\) (typically bar highs/lows), a swing high is an
\(m\)-order local maximum:

\[
H_i = \max(H_{i-m}, \dots, H_i, \dots, H_{i+m}),\quad \text{strictly}
\]

i.e. \(H_i > H_{i-j}\) and \(H_i > H_{i+j}\) for all \(j=1..m\). The Williams
fractal is the case \(m=2\) (5 bars). An \(m\)-order extremum has a minimum lag
of \(m\) bars between the extreme and the earliest confirmation.

Noise filtering families:

| Family | Mechanism | Examples |
|---|---|---|
| Window/pivot rule | fixed bar count each side | Williams 5-bar, `ta.pivothigh(5,5)`, DeMark pivots |
| Threshold (ZigZag) | reversal must exceed δ% or δ points | Merrill ZigZag, MT5 ZigZag (deviation, depth, backstep) |
| Volatility-adaptive | reversal must exceed k·ATR | ATR ZigZag, ATR-trailing pivots |
| Prominence | peak must exceed a baseline saddle by δ | scipy `find_peaks(prominence=δ)`, persistent homology |
| Change point | segmentation by likelihood of regime change | PELT, binary segmentation, BOCPD |
| ML/labeled | learned extremum classifier | LEAP (Mesirow), MTF-XGBoost |

## 1.4 Why swings exist / why it matters

Swing points are where **order flow exhausts** at a local level: buy pressure
exhausted at a high (sellers absorb), sell pressure exhausted at a low. They are
therefore:

- the reference levels for **stop placement and profit targets** (structure-based
  risk: "stop beyond the last swing" is the most universal practitioner rule);
- the atoms of **trend definition** (HH/HL vs LH/LL);
- the anchors for **breakout detection** (a break of a prior swing is a BOS) and
  **reversal detection** (CHOCH/MSS at protected swing points);
- the basis of **supply/demand zoning** (order blocks, FVGs are typically defined
  relative to swing structure).

The dominant cross-school consensus: **swing detection must be objective,
non-repainting, and filtered** — an unfiltered swing detector is worse than none
because it re-labels structure on every new extreme (see 3.5, 5.1).

---

# Phase 2 — Academic literature

## 2.1 Change point detection (the academic formulation)

The academic literature mostly studies the *underlying phenomenon* — abrupt
changes in the statistical properties of a series — under names unrelated to
"swings":

1. **Aminikhanghahi & Cook (2017), "A survey of methods for time series change
   point detection", Knowledge and Information Systems 51(2):339–367.** The
   canonical taxonomy: supervised vs unsupervised; online vs offline; cost
   functions; segmentation/edge/event detection. Key conclusions for swing
   detection: (a) no single method dominates; (b) online (causal) detection with
   bounded delay is the hardest open problem; (c) likelihood-ratio and kernel
   methods dominate for multivariate series. Evidence strength: multiple studies
   (survey of the field) — **Level II**.
2. **Killick, Fearnhead & Eckley (2012), PELT — Pruned Exact Linear Time,
   JASA.** Exact segmentation of a mean/variance-shift series in linear average
   time via pruning. The workhorse offline method; the basis of the `ruptures`
   library. Implication for swings: swing points can be framed as segment
   boundaries of a piecewise-constant (or piecewise-linear) model; the "penalty"
   parameter plays the role of the ZigZag deviation threshold. **Level II**.
3. **FinCPD — Liu, Xiong, Jin, Yi (2023), IEEE BigCom.** Online change point
   detection with a mixture-normal model for fat-tailed (leptokurtic) financial
   series; "Accumulative Advantage" likelihood-ratio statistic. Addresses the
   classic failure of Gaussian CPD on heavy-tailed returns. **Level II–III**.
4. **Zhu (2025), "Adaptive Bayesian online change point detection with
   applications to financial markets", Statistical Research 42(3).** BOCPD with
   run-length posteriors (Adams & MacKay 2007 lineage) adapted to financial
   markets. Online, causal, but parameter-sensitive. **Level III**.
5. **PELT in financial markets (2025 ACM proceedings).** Simulation comparison
   of PELT/Binseg/DynP cost functions on financial series: Normal cost best for
   PELT; PELT outperforms Binseg and DynP overall. Empirics: change points in
   Chinese equity indices align with policy events (2010 index-futures launch,
   2015 circuit-breaker, 2020 COVID liquidity shifts) — volatility-distribution
   shifts, not just mean shifts. **Level II–III**.
6. **Musaev, Grigoriev, Kolosov (2024), AIMS Mathematics 9(12):35238.**
   Adaptive/online CPD for chaotic FX series (EUR/USD): hybrid ML + multivariate
   approaches beat static models; "no universal solution exists for chaotic
   time series". **Level III**.
7. **Wang, Li, Zhou, Cai (2024), "Unsupervised Time Series Segmentation: A
   Survey on Recent Advances", CMC 80(2).** Splits segmentation into CPD,
   boundary detection (BD), and state detection (SD); findings: most methods lack
   online support; most require hand-set parameters (fails adaptivity); boundary
   detection accuracy is a neglected metric. **Level II**.

## 2.2 Local extrema detection/prediction

8. **Chu & Chan (2024), "Prediction of local extrema in financial time series
   with Multiple Timeframe Extreme Gradient Boosting", CFE-CMStatistics 2024.**
   Frames swing points as a *classification* target (is bar i an extremum?) and
   predicts them with multi-timeframe features + XGBoost. Confirms that
   multi-timeframe information improves extremum prediction — a rare direct
   academic test of a practitioner practice (MTF structure). **Level III**.
9. **Mesirow Currency, "Local Extrema Predictor (LEAP)" (2025).** Industry
   whitepaper: FX mean-reversion signals labeled by local extrema (peak/trough/
   neutral) from spot-rate trajectories; SVM with rolling k-fold CV and Bayesian
   hyperparameter search, GA feature selection; deployed live since April 2025 on
   27 USD pairs. Notable: (a) extrema used as *labels* for a supervised model;
   (b) confidence attached to each signal — the same "confidence architecture"
   question SuperCents_X faces. **Level III (single strong institutional doc)**.

## 2.3 Peak detection and persistence (signal-processing view)

10. **scipy `find_peaks` / `peak_prominences` (Virtanen et al. 2020, SciPy 1.0,
    Nature Methods).** The standard engineering toolkit: peaks selected by
    *height*, *prominence* (vertical distance to the highest saddle), *distance*
    (minimum separation), *width*. Prominence is the mathematically robust
    significance filter — it is translation/scale-invariant and drift-robust —
    and is the closest engineering analog to "significant swing". **Level II**.
11. **Topological data analysis / persistent homology for extrema (e.g.
    `findpeaks` library topology method; Erdogan et al.).** Persistence pairs
    (birth/death) of level-set components give a *provably stable* ordering of
    extrema by significance; the "lifespan" of a peak is its prominence
    generalization. Directly relevant to designing noise-robust swing filters.
    **Level III**.

## 2.4 Consensus, disagreements, open questions

**Consensus:**
- Unfiltered local extrema are useless; some significance filter is mandatory
  (CPD penalty, ZigZag deviation, prominence, ATR threshold).
- Confirmation requires a delay; online/causal detection with *bounded* delay is
  the central trade-off; every detector trades lag against false positives.
- No universal parameterization: threshold must adapt to volatility/instrument
  (multiple papers note hand-set parameters as a core weakness).
- Segment boundary quality is a neglected metric — most work validates on
  generated series, not on trade outcomes.

**Disagreements:**
- Fixed-bar window (fractals) vs threshold (ZigZag) vs statistical (CPD):
  practitioners favor fractals (simple, deterministic), academics favor CPD
  (principled); no direct head-to-head on financial trade outcomes.
- Whether highs/lows or closes should confirm breaks (close-confirmation is the
  practitioner majority; several academic formulations use raw levels).

**Open questions:**
- Can swing-point quality be *evaluated* (labeled ground truth) at all? There is
  no standard ground-truth dataset for swing points — LEAP sidesteps this with
  self-labeled trajectories; CPD papers use synthetic series.
- Does multi-timeframe swing alignment actually add predictive value in live
  trading? Only the MTF-XGBoost paper addresses it directly (yes, for prediction
  of extrema), with no published trade-level validation.
- Online adaptivity with no user-set parameters remains unsolved.

---

# Phase 3 — Professional trading literature

## 3.1 Dow Theory (Hamilton 1922; Rhea 1932; modern restatements)

- Three trends nested: primary (months–years), secondary (3 weeks–3 months,
  typically retraces 33–66%), minor (noise). **Know which trend you are
  reacting to.**
- Trend = structure: HH/HL (up), LH/LL (down). **The trend changes when a
  pullback breaks the prior swing low (or high)** — the exact operational rule
  behind BOS/CHOCH.
- Volume must confirm; trends persist until clear reversal evidence.
- A modern quantified restatement (Oxfordstrat research): Dow-style pivot rules
  with DeMark pivot-size parameters perform as a trend filter — beating
  buy-and-hold ≈8% of the time while cutting drawdowns; i.e. Dow structure is a
  *risk-management filter*, not a profit machine. OpenAlgo's 50/200 test agrees.

## 3.2 Wyckoff (1930s; schematics literature)

- Swings are the skeleton of accumulation/distribution: SC/AR/ST define the range;
  Spring = sweep of the SC low then reversal (a *liquidity grab* of the last
  swing low); UTAD = sweep of the last swing high then reversal.
- **Key practice**: swings are read on higher timeframes (weekly/daily), with
  volume confirmation per event (climax volume at SC/BC, declining volume at ST).
  Volume distinguishes "test" from "break".
- Caution from the literature itself: don't force schematics on unclear charts;
  schematic failure is common (false breakout, continuation, compressed event).

## 3.3 Bill Williams (1995)

- 5-bar fractal (middle bar extreme vs 2 bars each side); confirmed only when the
  second right-side bar closes; fractal "disappears" (repaints) if a new extreme
  prints inside the confirmation window. Up-fractal = resistance; break above =
  buy signal; stop beyond the last down-fractal.
- Williams' own filter: trade only fractals *outside the Alligator* (trend
  filter) — i.e. fractal *significance depends on context*, anticipating the
  Brooks trend-vs-range question.

## 3.4 Al Brooks (2009–2012)

- Pivots = any bar with a higher high than the 2 bars each side (his rule of
  thumb); all analysis is bar-by-bar on the pivot sequence.
- High 1 / High 2 / Low 1 / Low 2: successive pullback attempts in a trend; the
  *second* attempt is the high-probability entry (counter-trend traders fail
  once, then the trend resumes). H3/H4 → wedge, trend weakening.
- Breakouts: a large share of breakout bars stall/reverse shortly after trigger;
  failed breakouts are themselves trades. The context question precedes the setup
  question: **"trend or trading range?"** before "H2 or failed breakout?".
- Practical operational details: 20-EMA as trend reference only; two-legged
  pullbacks (ABC) are the norm — second attempt logic exists because of them.

## 3.5 ICT / Smart Money Concepts

- Market structure vocabulary: swing highs/lows define the **dealing range**
  (internal liquidity inside, external liquidity beyond); HH/HL sequence =
  bullish structure; the first **displacement** (strong, wide-range bar(s) after
  a sweep) breaks structure (MSS/BOS) and leaves an FVG.
- Internal vs external structure: external swings (major) set the bias; internal
  swings (minor) refine entries. Time-frame fractility: every timeframe has the
  same IRL↔ERL cycle.
- Equal highs/lows and sweep of prior swing = liquidity magnets (retail stop
  clustering) — the rationale for expectancy research on *sweeps* as a signal.
- Practitioner caution in the SMC literature itself: SMC is a framework for
  reading, not a tested rule set; the literature is largely anecdotal
  (Level IV evidence on its own; measurable components — BOS frequency, sweep
  frequency — can be validated with data).

## 3.6 Common best practices and mistakes (cross-school synthesis)

**Best practices**
1. Non-repainting: lock a swing at confirmation; never move it (Wickra,
   Brooks, ZigZag modern implementations, SMC tools).
2. Filter by significance (threshold/prominence/ATR), not just bar count.
3. Context first: trend vs range decides whether swing levels mean anything
   (Brooks explicitly; Williams via Alligator; Wyckoff via schematics).
4. Confirm with close or displacement, not wick penetration alone (ICT,
   Brooks, most modern open-source implementations).
5. Multi-timeframe: external structure for bias, internal for timing (Dow,
   Wyckoff, ICT, and the MTF-XGBoost paper).

**Common mistakes**
1. Counting every micro-swing (no significance filter) → structure breaks
   constantly (Dow "which swings you count" is the #1 pitfall).
2. Trading on the emission bar (ZigZag confirms *after* the extreme; the last
   leg always repaints).
3. Calling a reversal on the first lower low (needs confirmation: lower low +
   lower high, or CHOCH-style close beyond protected point).
4. Mixing confirmed and internal points in one rule (MQL5 forum consensus:
   separate confirmed swings from unconfirmed internal structure).
5. Ignoring context: same pattern is high-probability in a trend, trash in a
   range.

---

# Phase 4 — Institutional / quantitative methods

How professional systems solve the same problem, in their own vocabulary:

| Institutional framing | Equivalent swing concept | Representative methods |
|---|---|---|
| Change point / structural break | Swing reversal = regime boundary | CUSUM (Page 1954), PELT (Killick 2012), binary segmentation, DynP, FinCPD (2023), BOCPD (Zhu 2025) |
| Regime shift detection | Trend change | Hamilton Markov-switching; online CPD; adaptive PELT (Yao 2023: liquidity change points precede volatility turning points by ~2 trading days) |
| Volatility-adjusted pivots | Significance filter | k·ATR thresholds (ATR ZigZag, ATR trailing pivots); scipy prominence; ATR-based S/R zone qualifiers |
| Topological persistence | Peak significance ordering | persistent homology (findpeaks topology); zigzag persistence for scale selection |
| ML extremum labeling | Swing as classification target | LEAP (SVM, live FX since 2025); MTF-XGBoost (Chu & Chan 2024) |
| Trend/volatility filters as gates | Context (trend vs range) | ADX+ATR regime filters (PyQuantLab), Dow-style 50/200 (OpenAlgo) |

Key institutional lessons transferable to SuperCents_X:
- **Penalty/threshold adaptivity matters**: fixed thresholds fail across
  regimes; the field moves to adaptive (penalty selection by information
  criteria — AIC/BIC for PELT; k·ATR for pivots).
- **Change points precede volatility turning points** (Yao 2023) — structure
  events carry lead information, but only if detected online and causally.
- **Extrema used as labels + confidence attached** (LEAP) is the only published
  institutional approach attaching calibrated confidence to structure events —
  mirroring SuperCents_X's confidence architecture ambition (18.8).

---

# Phase 5 — Open-source implementations

## 5.1 Survey of implementations by family

| Implementation | Family | Key parameters | Repaint | Notes |
|---|---|---|---|---|
| TradingView `ta.pivothigh/pivotlow` | window | leftBars, rightBars (e.g. 5,5) | no | the standard TV primitive; many scripts layer filters on top |
| Williams Fractals (TV/MT) | window | fixed 5-bar | during window | native MT5 indicator; repaints inside window |
| MT5 ZigZag | threshold | deviation (%), depth, backstep | last leg | the classic; percent threshold + min bars + min separation |
| ATR ZigZag (TV, multiple authors) | volatility | ATR(14)×mult | last leg | adaptive threshold; "noise filter by construction" |
| Pivot Points Detector – ATR based (TV, LevenRyan) | volatility+displacement | ATR(12,2.0) trailing | no | pivot + displacement requirement |
| Adaptive S/R Zones (TV, BigBeluga) | window+volatility | pivot length, min ATR strength, merge threshold | no | ATR-qualified pivots + level merging + aging |
| `scipy.signal.find_peaks` (Python) | prominence | height, prominence, distance, width | n/a (offline) | the engineering gold standard for significant extrema |
| `findpeaks` (erdogant, Python) | multiple | topology (persistence) / Caerus (financial) | n/a | Caerus is purpose-built for financial series |
| `jbn/ZigZag` (Python) | threshold | δ | n/a | minimal ZigZag for research |
| `ruptures` (Python) | CPD | model (l2/rbf), penalty | n/a | PELT/Binseg/DynP/window; offline |
| `wickra` ZigZag (Rust/Python) | threshold | threshold ∈ (0,1) | no | clean spec: confirms on reversal bar, emits only confirmed swing |
| Swing-structure-backtest (GitHub) | window+N-bar | N-bar pivot rule | no | HH/HL/LH/LL classification from N-bar pivots |
| MQL5 "Dynamic Swing Architecture" (article 19793) | window | MinSwingBars | no | swing→execution EA; note: check multiple recent bars, not just fixed offset |
| MQL5 forum zigzags (psar zigzag, channel zigzag, price-% zigzag, magzag) | mixed | per-family | some | forum consensus: confirmed vs internal points must be separated (Talal N Z Aljarusha) |

## 5.2 Comparative algorithm findings

- **Confirmed vs internal structure separation** is the strongest open-source
  consensus (MQL5 forum 493707, multiple TV scripts): confirmed swings need
  right-side bars (lag OK); internal points may be early but are
  lower-confidence. SuperCents_X already separates *structural pivots* from
  *protected points* — an unusually disciplined version of this practice.
- **Volatility-adaptive thresholds are the modern default** for "significant"
  (ATR-based) while fixed-percent ZigZag remains the classic default.
- **Prominence/persistence** is the emerging robust alternative, especially
  where drift/regimes exist.
- Non-repainting is treated as mandatory by serious scripts; the standard
  complaint about ZigZag is repainting of the last leg.

---

# Phase 6 — Current SuperCents_X implementation (facts only)

## 6.1 Architecture (structure layer)

```
CSwingDetector ──swings──▶ CStructuralPivotEngine ──pivots──▶ CProtectedPointManager
     (5-bar fractal)      (promote/replace/lock)      (active high/low on trend flip)
        │                                                       │
        └──────────▶ CBOSDetector (18.2) ◀──locked pivots───────┘
                            │ BOS events
                            ▼
                      CTrendState (bullish/bearish machine)
```

Files: `Structure/SwingDetector.mqh` (305 lines), `Structure/StructuralPivotEngine.mqh`
(327), `Structure/ProtectedPointManager.mqh` (283), `Structure/TrendState.mqh` (178),
`Structure/PPTelemetry.mqh` (174). Structs in `Utils/Types.mqh:10-66`.

## 6.2 CSwingDetector

- **Rule**: 5-bar fractal, hardcoded `center±2` (`SwingDetector.mqh:204-230`);
  `SWING_STRENGTH 2` / `SWING_LOOKBACK_BARS` in `Utils/Constants.mqh:71-72` is
  documentation only — the detector logic is hardcoded to 2 (start center `4`,
  `SwingDetector.mqh:132-133`), i.e. the constant is not parameterized.
- **Confirmation**: strict high/low comparison (`>`/`<`); confirmed on the
  second right-side bar; deterministic chronological scan with
  `m_lastCheckedCenter` (`:130-167`); chart-reload rescan handled (`:113-119`).
- **No significance filter**: any 5-bar pattern, any size, any volatility
  qualifies. No deviation, no ATR, no prominence, no volume.
- **No multi-timeframe** input; single series only.
- **Storage**: chronological arrays, growth +256; IDs globally unique and
  monotonic (used as a merge key by the pivot engine).
- **Complexity**: O(bars) scan once per new bar (amortized O(1) per tick
  window), memory O(#swings). No repainting: swings are written once.

## 6.3 CStructuralPivotEngine

- State machine over the swing stream (`StructuralPivotEngine.mqh:152-181`):
  - Rule 1: first swing → pivot (promote).
  - Rule 2: opposite-type swing → **lock** the current pivot
    (`isProtected=true`, `:238-255`) and promote the new one.
  - Rules 3–4: same-type swing while unlocked → **replace** only if strictly
    stronger (higher high / lower low) (`:175-177`, `:288-303`); else ignore.
  - Pivot IDs are immutable across replacement (Rule 5, `:212-236`).
- This is precisely the "institutional" model of a running extremum that only
  locks when the opposite side prints — consistent with practice.
- Two-pointer merge by swing ID guarantees deterministic processing order
  (`:114-149`); `m_lastProcessedSwingId` guards reprocessing.

## 6.4 CProtectedPointManager

- On trend change (BULLISH→BEARISH etc., `:109-116`), deactivates the previous
  active point and activates the **latest locked pivot of the opposite type**
  (`:143-200`): bullish trend → protected low; bearish trend → protected high.
- Active points are the reference levels for CHOCH (close beyond protected
  point; see 18.3).
- Lifecycle audit logging exists (`:118-141`) — a candidate pivot newer than the
  active one is logged, not acted on.

## 6.5 CTrendState

- Binary machine: TREND_UNKNOWN / BULLISH / BEARISH; flips only on BOS events
  (`TrendState.mqh:85-144`); counters for bullish/bearish BOS and flips.
- No ranging state, no strength, no timeframe hierarchy (all noted for 18.12).

## 6.6 PPTelemetry (log-only, not in the v3 dataset)

- `PPTelemetryRecord` captures per-CHOCH-check: accepted/rejected (price-not-
  broken vs guard-time), distance from PP, PP age in bars (`PPTelemetry.mqh:12-28`).
- **Not part of the 68-column v3 schema** — PP lifecycle statistics are printed
  in Shutdown only. Consequence for Phase 7: the frozen dataset cannot measure
  PP age/distance distributions (a telemetry gap; see 18.15).

## 6.7 Strengths (observed, factual)

- Deterministic, non-repainting, chronological; no reprocessing; O(1) amortized.
- Confirmed-vs-internal separation (pivot lock) matches the strongest
  open-source consensus (§5.2).
- Immutable pivot IDs simplify downstream bookkeeping (BOS/CHOCH referencing).

## 6.8 Weaknesses / simplifications (observed, factual)

- `SWING_STRENGTH` is not parameterized — a fixed 2/2 window with no
  significance filter (any 5-bar wiggle becomes structure).
- No volatility adaptation; fixed window behaves differently across
  instruments/regimes (M15 EURUSD vs H1 GBPJPY).
- No multi-timeframe structure input (no external/bias concept).
- No volume/participation filter (Wyckoff/Brooks context absent).
- Protected point selection uses *latest* locked pivot of the type — no
  notion of best/highest-confluence level (BigBeluga-style merging/ranking
  absent).
- Trend state is binary and BOS-driven only; flips are reactive, no
  confirmation of the flip (e.g. no "lower low + lower high" requirement).

---

# Phase 7 — Sprint 17 evidence review (measured only)

Dataset: 19 merged CSVs, 18,686 rows, fingerprint `2e74bbae…`.
Semantics: evidence tristate `1=FALSE, 2=TRUE, 0=UNKNOWN`
(`Telemetry/TelemetryTypes.mqh:60-65`); outcome `1=WIN, 2=LOSS, 3=BE, 0=UNKNOWN`.
Analysis basis: decided rows with a fired rule (n = **17,068**; rule-0 no-signal
rows 1,491 excluded from signal-level statistics).

## 7.1 Fired-rule frequency and win rates (structure-relevant rules)

| firedRuleId | ruleName | n | Win | Loss | Win rate | Avg ruleConfidence | Avg layerStructural |
|---|---|---|---|---|---|---|---|
| 1 | BOS_OB_BULLISH | 440 | 163 | 277 | 0.3705 | 0.9205 | 30.0 |
| 2 | BOS_OB_BEARISH | 417 | 157 | 260 | 0.3765 | 0.9170 | 30.0 |
| 3 | OB_FVG_BULLISH | 6,410 | 1,947 | 4,463 | 0.3037 | 0.8000 | 25.0 |
| 4 | OB_FVG_BEARISH | 5,906 | 2,227 | 3,679 | 0.3771 | 0.8000 | 25.0 |
| 5 | LIQUIDITY_BOS_BULLISH | 1,853 | 523 | 1,330 | 0.2822 | 0.9349 | 15.0 |
| 6 | LIQUIDITY_BOS_BEARISH | 1,700 | 531 | 1,169 | 0.3124 | 0.9352 | 15.0 |
| 7 | CHOCH_OB_REVERSAL | 342 | 122 | 220 | 0.3567 | 0.7500 | 35.0 |
| 0 | (no signal) | 1,491 | 460 | 1,003 | 0.3144 | — | 0.0 |

- BOS-based rules (1,2) show the highest per-rule win rates (0.3705/0.3765);
  LIQUIDITY_BOS rules (5,6) the lowest (0.2822/0.3124).
- `ruleEvidenceCount` is 2 for every fired rule (evidence is always packed in
  pairs — the dataset cannot separate *which* two evidence items matter without
  decoding `ruleEvidenceIds`; pair frequency alone is measurable).

## 7.2 Evidence flag prevalence and outcome deltas (decided + signal rows)

| Flag | TRUE n | TRUE win rate | FALSE n | FALSE win rate | Delta (TRUE−FALSE) |
|---|---|---|---|---|---|
| hasBOS | 4,410 | 0.3116 | 12,658 | 0.3394 | −0.0278 |
| hasCHOCH | 342 | 0.3567 | 16,726 | 0.3317 | +0.0250 |
| hasOrderBlock | 13,515 | 0.3415 | 3,553 | 0.2967 | +0.0448 |
| hasFVG | 12,316 | 0.3389 | 4,752 | 0.3148 | +0.0241 |
| hasLiquiditySweep | 3,553 | 0.2967 | 13,515 | 0.3415 | −0.0448 |
| hasProtectedPoint | **0** | — | 17,068 | 0.3322 | — |

- **hasProtectedPoint is FALSE on all 17,068 signal rows**: the protected-point
  flag never appears as fired evidence in the frozen dataset. The PP layer is
  structurally present (CHOCH rule 7 exists, n=342) but never surfaces as an
  evidence component in v3 telemetry. Measured fact; interpretation belongs to
  Phase 8 (telemetry gap) and 18.3.
- Rows where a liquidity sweep is part of the fired evidence (hasLiquiditySweep
  TRUE, 3,553) have lower win rate (0.2967) than rows without (0.3415). The
  complement holds for hasOrderBlock (TRUE 0.3415 vs FALSE 0.2967) — the two
  flags are near-complements in the evidence mix.

## 7.3 Layer activations

| layerStructural | rows | layerLiquidity | rows | layerConfirmation | rows | layerTotal | rows |
|---|---|---|---|---|---|---|---|
| 0 | 1,491 | 0 | 15,110 | 0 | 1,491 | 0 | 1,491 |
| 15 | 3,576 | 30 | 3,576 | 10 | 4,335 | 35 | 3,418 |
| 25 | 12,415 | | | 15 | 12,860 | 40 | 9,265 |
| 30 | 858 | | | | | 45 | 860 |
| 35 | 346 | | | | | 50 | 76 |
| | | | | | | 55 | 379 |
| | | | | | | 60 | 3,197 |

- Structural layer is the largest contributor: 12,415 rows at 25, plus 858 at 30,
  346 at 35 (the CHOCH rule), 3,576 at 15 (liquidity-BOS rules).
- `layerLiquidity` is binary (0 or 30), `layerConfirmation` binary (0/10/15) —
  consistent with rules always pairing structural evidence with one other
  evidence type.
- 76 rows reach layerTotal 50; 379 at 55; 3,197 at 60 (maximum).

## 7.4 What the dataset cannot measure (explicit)

- PP age and distance-to-PP distributions (PPTelemetry is log-only).
- Swing point quality (number of 5-bar patterns per day, average swing size in
  ATR) — swings are not recorded as events in the dataset; only their
  downstream flags.
- Multi-candle confirmation effects (the detector is single-bar 5-bar fractal;
  no variant was collected).
- Multi-timeframe alignment (single-timeframe runs only).
- Win/loss by swing recency or swing size (not in schema).
These are telemetry gaps recorded for 18.15 (schema v4 candidates).

---

# Phase 8 — Experiment backlog (no implementation)

Only literature-supported experiments. Scoring per `00_Program_Overview.md` §3.

## E1 — Volatility-adaptive swing significance filter (ATR)

- **Literature**: ATR-qualified pivots are the modern standard (Layer 4/5: ATR
  ZigZag, BigBeluga S/R zones, LevenRyan pivot detector); fixed-window-only
  detection is the documented #1 weakness of fractal detectors (prominence/ATR
  fix it).
- **Implementation survey**: ATR(14)×mult pivots in the majority of serious
  open-source swing tools; non-repainting with close confirmation.
- **SuperCents_X**: `SWING_STRENGTH` fixed at 2/2 with no significance filter
  (`SwingDetector.mqh:204-230`).
- **Sprint 17 evidence**: cannot measure directly (no swing-size column); the
  dataset records rule-level deltas (hasLiquiditySweep TRUE −0.0448) that a
  swing-quality variant would need to be compared against.
- **Experiment**: add a configurable minimum swing significance (k·ATR or
  prominence) as a filter upstream of the pivot engine; collect a v3-equivalent
  run with the filter on/off; compare rule win rates and signal counts.
- **Evidence Strength: II · Confidence: B · Priority: P1**
- **Success**: same rule set, fewer but higher-win-rate BOS/OB rules on the
  frozen baseline comparison window; no significant drop in sample coverage.
- **Risk**: overfiltering → too few signals; ATR lag at regime transitions.

## E2 — Prominence / persistence-based swing ranking

- **Literature**: prominence and persistent-homology lifespans are
  provably stable significance measures (2.3: scipy, TDA); robustness to drift.
- **Implementation survey**: `find_peaks(prominence=δ)`, `findpeaks` topology
  and Caerus (financial) variants; no mainstream MT5 EA uses it yet.
- **SuperCents_X**: no significance concept at all today.
- **Sprint 17 evidence**: dataset cannot measure swing ranking (gap).
- **Experiment**: offline study on the frozen M15 series — count 5-bar fractals
  by prominence/ATR quantile and correlate with subsequent bar-direction
  outcomes to test whether "more prominent swing" ⇒ "better structural level".
  Research-grade (Phase 8 card only; requires no EA change to run offline).
- **Evidence Strength: III · Confidence: C · Priority: P2** (backlog pending
  evidence; implement only if the offline study is positive).

## E3 — Multi-timeframe structure alignment (bias layer)

- **Literature**: Dow/Wyckoff/ICT all prescribe higher-timeframe bias;
  MTF-XGBoost (Chu & Chan 2024) shows multi-timeframe features improve extremum
  prediction — the only direct academic support.
- **Implementation survey**: standard practice in SMC tools and Brooks-style
  setups; rare in rule-based EAs because of the extra bar-data plumbing.
- **SuperCents_X**: single-timeframe structure only.
- **Sprint 17 evidence**: cannot measure (single-TF runs); trendAligned is
  available (aligned 12,777 rows wr 0.3283 vs non-aligned 4,291 wr 0.3437 —
  measured, but not multi-TF).
- **Experiment**: add an HTF (H1/H4 for M15 runs) swing sequence feeding a bias
  gate; collect evidence run with trendAligned replaced by HTF-alignment;
  compare vs the frozen baseline.
- **Evidence Strength: II · Confidence: B · Priority: P2**
- **Risk**: HTF lag vs LTF timing; doubling of structure state to maintain.

## E4 — Volume / participation confirmation (Wyckoff-style)

- **Literature**: Wyckoff schematics are volume-defined (SC/AR/ST volume
  signatures); Dow requires volume confirmation; Williams' Alligator is the
  trend-context proxy.
- **Implementation survey**: volume-weighted pivots appear in advanced TV tools
  (Smart ZigZag uses VWAP baseline + z-score thresholds); none in the MT5
  mainstream.
- **SuperCents_X**: no volume anywhere in the structure layer (tick volume is
  available in MQL5 without extra data).
- **Sprint 17 evidence**: cannot measure (volume not in schema v3 — a telemetry
  gap if this experiment is accepted).
- **Experiment**: record tick volume at 5-bar fractal confirmation; test whether
  declining-volume tests (Wyckoff ST signature) precede higher-probability
  structural breaks. Requires a schema v4 volume column or a log-only study
  first.
- **Evidence Strength: IV · Confidence: C · Priority: P3**

## E5 — Telemetry: PP lifecycle into the v3 dataset (schema v4 candidate)

- **Literature**: LEAP attaches confidence to structure events; Yao 2023 shows
  liquidity-structure change points lead volatility turning points — structural
  event telemetry has demonstrated signal value.
- **SuperCents_X**: PP distance/age is collected but log-only
  (`PPTelemetry.mqh`), and `hasProtectedPoint` never fired TRUE in 17,068
  signal rows — the PP layer is currently invisible to the evidence dataset.
- **Sprint 17 evidence**: hasProtectedPoint TRUE n=0 — the measurable fact
  behind this experiment.
- **Experiment**: extend schema v4 with PP distance (points), PP age (bars),
  and sweep-distance-at-break columns; recollect a baseline window; then answer
  "does CHOCH quality depend on PP age/distance?" (currently unanswerable).
- **Evidence Strength: III · Confidence: B · Priority: P1**
- **Risk**: schema change touches the frozen fingerprint lineage — must be a
  new v4 contract with the v3 baseline untouched.

## E6 — Trend-flip confirmation (no single-BOS flips)

- **Literature**: Brooks requires a second-leg confirmation; Dow requires the
  pullback to break the prior swing *and* hold; ICT requires displacement.
  Academic CPD consensus: single-point detection is unreliable (delay/conflict
  trade-off in 2.4).
- **Implementation survey**: mature tools require close-based confirmation or
  multi-bar confirmation (5.2).
- **SuperCents_X**: `CTrendState` flips on any single BOS (`TrendState.mqh:85-144`);
  CHOCH rule 7 (n=342, wr 0.3567) is the only flip-adjacent rule and shows the
  dataset's only positive structure delta among minority rules.
- **Sprint 17 evidence**: 342 CHOCH rows — small sample; trendAligned non-aligned
  rows (4,291) have *higher* win rate (0.3437) than aligned (0.3283), measured;
  interpretation deferred (could be counter-trend mean reversion, not flip
  quality).
- **Experiment**: evaluate a 2-BOS or close+confirm flip rule against the
  frozen baseline in a shadow telemetry run.
- **Evidence Strength: III · Confidence: B · Priority: P2**

## Backlog summary (18.1 contributions)

| ID | Experiment | Strength | Confidence | Priority |
|---|---|---|---|---|
| E1 | ATR/prominence swing significance filter | II | B | P1 |
| E5 | PP lifecycle telemetry (schema v4) | III | B | P1 |
| E3 | Multi-timeframe structure alignment | II | B | P2 |
| E6 | Trend-flip confirmation | III | B | P2 |
| E2 | Prominence/persistence ranking (offline first) | III | C | P2 |
| E4 | Volume confirmation | IV | C | P3 |

Sprint 19 rule: **E1, E5** (P1) and **E3, E6** (P2) are implementable; E2 and E4
remain C-backlog pending offline evidence.

## References (consolidated)

- Aminikhanghahi & Cook (2017), *A survey of methods for time series change point
  detection*, KAIS 51(2):339–367. doi:10.1007/s10115-016-0987-z
- Killick, Fearnhead & Eckley (2012), *Optimal detection of changepoints with a
  linear computational cost*, JASA 107(500):1590–1598.
- Truong, Oudre & Vayatis (2018/2020), *ruptures: change point detection in
  Python*, GitHub/docs (CNRS).
- Liu, Xiong, Jin, Yi (2023), *FinCPD: online change point detection for
  financial time series*, IEEE BigCom 2023. doi:10.1109/BIGCOM61073.2023.00026
- Zhu (2025), *Adaptive Bayesian online change point detection with applications
  to financial markets*, Statistical Research 42(3):450–467.
- Musaev, Grigoriev, Kolosov (2024), *Adaptive algorithms for change point
  detection in financial time series*, AIMS Mathematics 9(12):35238–35263.
- Wang, Li, Zhou, Cai (2024), *Unsupervised time series segmentation: a survey
  on recent advances*, CMC 80(2):2657–2673.
- Chu & Chan (2024), *Prediction of local extrema in financial time series with
  Multiple Timeframe Extreme Gradient Boosting*, CFE-CMStatistics 2024.
- Emambakhsh (2025), *Local Extrema Predictor (LEAP)*, Mesirow Currency.
- Virtanen et al. (2020), *SciPy 1.0*, Nature Methods 17:261–272 (`find_peaks`).
- Merrill (1977), *ZigZag*, as documented in Pring, *Technical Analysis
  Explained* (1991) and Wickra spec.
- Williams (1995), *Trading Chaos*.
- Brooks (2009–2012), *Trading Price Action* trilogy + *Reading Price Charts
  Bar by Bar*.
- Hamilton (1922), *The Stock Market Barometer*; Rhea (1932), *The Dow Theory*.
- Wyckoff (1930s) schematics as systematized in modern sources (SabioTrade,
  ThinkMarkets, Ironclad Research).
- Oxfordstrat (2018), *Dow Theory – Multiple Time Frames*, R&D.
- MetaTrader 5 (2025–2026), *Algorithm to accurately finding swing & internal
  points*, forum 493707; *Dynamic Swing Architecture*, article 19793.
- TradingView open-source scripts: Swing High/Low (Adaptive), ATR ZigZag,
  Pivot Points Detector – ATR based, Adaptive S/R Zones [BigBeluga],
  Power Peaks & Valleys, Swing Points Alert.
- GitHub: `leoi137/Support-and-Resistance-Algorithm`, `jbn/ZigZag`,
  `erdogant/findpeaks`, `fallenpheonix23/swing-structure-backtest`,
  `wickra-lib/wickra`.
