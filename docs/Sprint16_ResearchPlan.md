# Sprint 16 — Strategy Research & Calibration (hypothesis-driven)

Status: **planned** (Sprint 15 closed: `v3.0-production-providers`, gate NOT PROMOTED)

Sprint 16 is not "build more infrastructure." It is **hypothesis-driven
research** on the settled telemetry the platform now produces. Every
experiment answers one question that can move the Promotion Gate. The sprint
ends only when we can answer, with evidence, the four acceptance questions in
§6.

## 0. Why this sprint exists

The Sprint 15 gate verdict was correct and actionable:

- Best threshold 0.40: expectancy −0.0369 vs baseline −0.0919, **p = 0.16**
  (not significant); PF 0.9453; win rate 32.35%; max DD 567.6 R vs 207.7 R →
  **NOT PROMOTED**.
- The strategy sits ~1 point of win rate below the 1R/2R breakeven (33.3%).
- Replay confidence tops out at ~0.64 — thresholds 0.65–0.80 qualify zero
  signals, so the optimizer's effective range is 0.40–0.60.

Three workstreams follow directly: the score is miscalibrated (A), the 0.40
drawdown increase is unexplained (B), and exit efficiency is the most
tractable path to breakeven+ (C).

**Explicitly out of scope**: LIVE execution (gate must pass first), and
weight optimization *before* confidence calibration (optimizing on a
distorted score is wasted work).

## 1. Canonical experiment sequence

```
Confidence calibration (A)
        ↓
Exit policy research (C)
        ↓
Validator attribution (B-analytics, A-blame)
        ↓
Weight optimization (only after A+C results are locked)
        ↓
Promotion Gate (rerun, expectation: evidence, not promotion)
```

Weights are moved last, only against calibrated scores and the winning exit
policy.

## 2. Workstream A — Confidence calibration (highest priority)

**Hypothesis H-A1**: replay confidence is not proportional to empirical win
probability (distribution compressed to ≤ 0.64; therefore the 0.40–0.60 cut
carries little information).

**Objective** (note: *not* "increase confidence"): make confidence
proportional to actual probability of success.

**Ground truth**: settled outcomes (WIN/LOSS, rMultiple) — available for
18,117+ rows from Sprint 15. All calibration work is offline in
`CalibrationRunner`; no EA changes required.

**Experiments**:

| # | Experiment | Question | Deliverable |
|---|-----------|----------|-------------|
| A1 | Reliability curve on settled rows | Is binned win rate ≈ predicted confidence? | Reliability diagram + ECE |
| A2 | Confidence histogram | What does the score distribution look like? | Histogram (expect mass ≤ 0.64) |
| A3 | Calibration table | Per 0.05 bin: n, win rate, expectancy, PF | Calibration table CSV |
| A4 | Isotonic / Platt / temperature transform | Does a monotone transform reduce ECE/Brier? | Transformed scores + transformed reliability diagram |

> **A4 result (Sprint 16.2, in-sample)**: isotonic/Platt reduce ECE to
> 0.005/0.014 but only by collapsing to the base rate — PAV finds no monotone
> structure (per-bin win rates non-monotone) and Platt fits a negative slope.
> Temperature diverged (t=721, e^t overflow → constant 0.5, ECE worse than
> raw). Every calibrated model yields **0 trades at the 0.60 gate** (calibrated
> scores sit at ≈ 0.33–0.5). Details: `docs/Sprint16_2_CalibrationModels.md`.

**Decision rule**: adopt a transform iff ECE decreases AND thresholds
0.40–0.90 each yield ≥ 500 settled trades (vs 0 today above 0.65). If no
transform helps, record the finding — the score may be structurally capped
(e.g., components rarely fire together), which is itself a Report Card entry.

**Success metrics**: confidence spans most of 0–1; reliability curve near
diagonal; ECE/Brier decreases; every 0.40–0.90 threshold produces meaningful
sample sizes.

### 2.1 Sprint 16.1B — Structural diagnostics (the primary research sprint)

**Status**: ELEVATED to primary sprint after 16.2 falsified calibration:
isotonic collapses to the constant base rate 0.3301 (no monotone structure),
Platt fits a negative slope (higher confidence ⇒ lower win rate), temperature
diverges. The research question changed from "how do we calibrate confidence?"
to **"why is confidence anti-correlated with outcomes?"**

**Hypothesis H-16.1B**: the score rewards *amount of confluence* (how many
evaluators fired) rather than *quality of confluence*; combinations mostly
occur in volatile continuation phases → compressed scores, flat/negative
reliability, no bugs required.

**Deliverable**: a five-part structural report (`CALIB_MODE_STRUCTURAL`,
mode 7, all offline from stored telemetry rows — per-component raw scores,
weights and contributions are already persisted):

1. **Component activation** — per evaluator (structure, OB, FVG, liquidity,
   trend, premium/discount): activation % of settled rows, mean raw score.
2. **Marginal predictive power** — per component, absent vs present:
   trades, WR, PF, expectancy, meanConf, meanR. Does any evaluator predict?
3. **Confidence decomposition** — rows grouped by number of active
   components (0..6): trades, WR, meanConf, meanR. Is confidence just a
   counting variable?
4. **Rank correlation** (primary evidence) — Spearman ρ and Kendall τ-b
   between confidence and rMultiple, and confidence and win/loss; plus
   per-component Spearman (raw score vs rMultiple). ρ ≈ 0 or < 0 proves the
   ordering itself is weak — stronger evidence than any calibration metric.
5. **Information contribution** — ablation replay at the 0.60 gate per
   component: weight zeroed (leave-one-out) vs weight alone vs full score,
   reporting Δexpectancy, ΔPF, Δtrades, infoContrib.

**Explicitly NOT done**: retuning rule constants (0.72 → 0.81 etc.). The
evidence says the *ordering* is poor, not the thresholds; retuning constants
does not fix "higher confidence → lower win rate".

**Decision rule**: whichever of (4) rank correlations / (2) marginal power /
(3) counting behavior identifies the failing link becomes the Sprint 17
scoring-architecture experiment (e.g., quality-weighted confluence, evaluator
gating, per-component calibration). No gate decision is implied by the report
itself.

## 3. Workstream B — Drawdown attribution (the 0.40–0.60 slice)

The gate answered *what* (drawdown 567.6 R vs 207.7 R). Sprint 16 answers
*why*: is the extra ~7,000 trades genuine signal degradation or volume?

**Hypothesis H-B1**: the marginal 0.40–0.60 slice has materially worse
expectancy than the ≥ 0.60 slice (degradation).
**Hypothesis H-B2**: the slice is statistically indistinguishable; the
drawdown gap is a trade-count effect (per-trade risk identical).

**Experiments** — slice reports, all on existing telemetry columns
(timestamp → session/weekday/month, symbol, direction, confidence,
components, validator filters, exitReason, outcome):

| Slice | n (M15 settled) | win rate | expectancy | PF | max DD |
|-------|-----------------|----------|------------|-----|--------|
| 0.40–0.45 | ~3,600 | ? | ? | ? | ? |
| 0.45–0.50 | ~2,900 | ? | ? | ? | ? |
| 0.50–0.55 | ~1,600 | ? | ? | ? | ? |
| 0.55–0.60 | ~1,400 | ? | ? | ? | ? |
| ≥ 0.60 | 1,419 | 0.3080 | −0.0919 | 0.8669 | 207.7 |

Then cross-tabulate the lowest-expectancy slices by: month, weekday, session,
direction, exit reason (TP/SL/horizon), trend regime, and validator filter
pattern (reuse `CValidatorAttribution` machinery). Also run per-symbol
(EURUSD H1 / GBPJPY H1, small n — descriptive only).

**Decision rule**: if a slice's losses concentrate in a named factor
(e.g., "SL exits in March", "short side on Fridays"), that factor becomes the
Sprint 17 validator/filter experiment. If losses are uniform → H-B2 holds;
drawdown is volume, and the 0.40 threshold remains viable *if* calibration
(A) or exits (C) improve per-trade expectancy.

## 4. Workstream C — Exit policy research

**Motivation**: entry quality +2 win-rate points is hard; exit efficiency +2
points is usually achievable. Breakeven at 1R/2R is 33.3%; we are at 32.35%
(best slice). Small wins matter.

**Key architectural fact**: Sprint 15 made the exit policy pluggable
(`IOutcomePolicy` + `CForwardOutcomeSimulator`). Exit experiments re-simulate
outcomes **offline from stored entries** (entry time, direction, price, ATR
context) — no EA reruns, identical entries across all policy variants.

**Hypothesis H-C1**: under identical entries, at least one exit policy
produces expectancy significantly above the FixedRR 1R/2R baseline (p < 0.05,
Welch on rMultiples).

**Policy candidates (each = one experiment)**:

| # | Policy | Mechanism |
|---|--------|-----------|
| C1 | BE +0.5R | Break-even once +0.5R in play |
| C2 | BE +1.0R | Break-even once +1R in play (lock at least 1R) |
| C3 | Trailing 1R | Trail stop 1R behind extreme |
| C4 | ATR trailing | Trail by k×ATR(14) |
| C5 | Partial TP | Close 50% at 1R, rest 2R with BE |
| C6 | Time stop | Exit at N bars (scan horizon variants) |
| C7 | Dynamic TP | TP = f(ATR or volatility regime) |

Each evaluated on the **same settled entries** (all 3 datasets), at the
calibrated threshold from A. Report: expectancy, PF, win rate, max DD,
trades, p vs baseline.

**Decision rule**: adopt only policies with p < 0.05 vs baseline AND
drawdown ≤ 1.5× baseline; then re-run A4's transform on the new outcomes if
the policy changes the reliability structure.

## 5. Research Report Cards (new permanent artifact)

Every experiment — calibration sweep, slice table, exit variant, ablation,
weight search — writes a **one-page report card** alongside its CSV:

```
docs/.../report_cards/<experimentId>_<fpHex>_<datasetFp>_<tag>.txt

experiment:     C3_trailing_1R
question:       does trailing 1R beat FixedRR baseline on identical entries?
config fp:      <hex>
dataset fp:     <hex>
trades:         8602
win rate:       0.34xx
expectancy:     +0.02xx
profit factor:  1.0xxx
max drawdown:   xxx.x (R)
p vs baseline:  0.03xx
gate verdict:   NOT PROMOTED — expectancy PASS(p=0.03), drawdown FAIL
conclusion:     trailing wins expectancy but DD > 1.5x baseline; revisit
                after calibration
```

Fields are written by `CExperimentRunner` (same code path as the CSVs +
manifests) so every run is automatically cataloged. The card catalog makes
research **cumulative**: any hypothesis can be re-derived from cards instead
of rerun, and no experiment is repeated unknowingly.

## 6. Acceptance criteria (evidence, not features)

By sprint end, the docs must contain explicit answers to:

1. **Can confidence be calibrated across most of the 0–1 range?** (A)
   — reliability diagram, ECE before/after, per-threshold sample sizes.
2. **What specifically causes the 0.40 drawdown increase?** (B)
   — slice tables + factor attribution; named cause or "volume, H-B2".
3. **Which exit policy performs best under identical entries?** (C)
   — head-to-head table with p-values vs baseline.
4. **Does any calibrated configuration outperform the baseline with
   statistical significance?** — the promotion gate rerun with the best
   (A,C) config: all sample criteria PASS, expectancy p < 0.05, PF/win-rate/
   drawdown/recovery all PASS.

**Only if (4) is "yes"** is promotion on the table; otherwise the sprint is
still successful if (1)–(3) are answered with evidence — that is what the
platform exists to produce.

## 7. Not doing (with reasons)

- **LIVE execution**: gate must pass first (Sprint 15 verdict: not enough
  evidence). Executing now would bypass the architecture.
- **Weight optimization before calibration**: optimizing weights on a
  compressed, miscalibrated score finds local artifacts, not edges.
- **Generic "more research"**: every item above has a named hypothesis, a
  decision rule, and a report card.

## 8. Success criteria for Sprint 16

Contract between this plan and the Sprint 16 completion report — every box
must be resolved (checked or explicitly answered negative) before the
promotion gate is rerun:

- ☐ Confidence calibration produces a usable distribution across most of
  the 0–1 range (0.40–0.90 thresholds all yield ≥ 500 settled trades; ECE
  reduced vs raw score).
- ☐ Root cause of the 0.40 drawdown is identified and supported by
  evidence (named factor, or documented trade-count effect per H-B2).
- ☐ At least one exit policy statistically outperforms the FixedRR
  baseline (p < 0.05 on rMultiples) without exceeding the 1.5× drawdown
  cap.
- ☐ Research Report Cards are generated automatically for every
  experiment (permanent platform artifact, §5).
- ☐ Promotion Gate is rerun only after the above evidence is collected —
  with the expectation of evidence, not promotion.
