# Sprint 20 — ED01-A Decision: Admission-Floor Sensitivity (3-month screening)

Status: COMPLETE — 2026-08-09
Scope owner: entry-decision research, first measurement milestone (ED01-A)
Protocol: `docs/Sprint20_ED01_Protocol.md` (frozen 2026-08-08; execution
amendment 13.1: 3-month screening window, user-approved)

## 1. Verdict summary

**All 12 gated grid points: KEEP (no change). B8 floors remain.**

| Family (B8 floor) | Config | nΔ EURUSD H1 | Δ Mean R (CI, 10k day-stratified) | Verdict |
|---|---|---|---|---|
| LIQUIDITY (0.60) | 0.50 / 0.55 | 0 / 0 | +0.0000 | KEEP |
| LIQUIDITY (0.60) | 0.65 / 0.70 | family switched off (n=0) | n/a — report only | KEEP |
| FVG (0.35) | 0.25 / 0.30 | 0 / 0 | +0.0000 | KEEP |
| FVG (0.35) | 0.40 | 318 → 143 (−55%) | +0.0144 [−0.0893, +0.0609] | KEEP |
| FVG (0.35) | 0.45 | family switched off (n=0) | n/a — report only | KEEP |
| BOS (0.35) | 0.25 / 0.30 / 0.40 | 0 / 0 / 0 | +0.0000 | KEEP |
| BOS (0.35) | 0.45 | 378 → 364 (−4%) | −0.0024 [−0.0287, +0.0214] | KEEP |
| CHOCH (0.35) | all | never fires (n=1 M15) | n/a — evidence only | KEEP |
| ORDER_BLOCK (0.35) | all 4 | 0 rows changed | n/a — structurally inert | KEEP |

No REJECT, no DEFER. The null hypothesis (B8 default floors) survives every
grid point. Per amendment 13.1 this closes the 3-month screening: no floor
shows a promising/stable signal, so no deeper grid validation is triggered by
this run.

## 2. Execution record

- Window: **2026.04.05 → 2026.07.05** (amendment 13.1), Model=4 every tick,
  `EntryMode=2`, weights 25/20/15/15/15/10 (archived Sprint 17 set).
- Grid: 21 configs × 3 files = 63 runs (1 B8 CONTROL + 20 single-floor deltas
  per file); files EURUSD_H1, GBPJPY_H1 (decision), EURUSD_M15 (evidence-only).
- Run: `Tools/ED01/ED01_RunBatch.ps1`, 2026-08-09 08:35 → 11:18 (2 h 43 m
  wall); 0 retries, 0 empty captures; H1 ≈ 1–2 min/run, M15 ≈ 6.7 min/run
  (6,239 rows/window).
- Artifacts: `Tools/ED01/artifacts/<FILE>/<CONFIG>/telemetry_v4_*.csv` +
  `.done` markers (rows/faults per run); log `Tools/ED01/run.log`;
  analysis JSON `Tools/ED01/results_3mo.json`.
- Prior 6-month batch (2026-08-08, 46 runs before terminal wedge) archived at
  `Tools/ED01/artifacts_6mo_2026-01-05_07-05/` — reserved as long-horizon
  validation material per amendment 13.1, NOT used for these verdicts.

## 3. Verification gates (pre-analysis)

- All 63 runs: `rows` captured, 0 I/O faults; 21 **distinct** fingerprints per
  file (policy recording); CONTROL fingerprint `3005138848403243456` equals
  the frozen B8 baseline (TT01 `Tools/TT01/baseline/`).
- Inert checks (row-level, EURUSD_H1): BOS_0.25/0.30/0.40, FVG_0.25/0.30,
  LIQUIDITY_0.50/0.55, and all OB_* configs change **0 of 1,558 rows**
  (newDecision/validatorResults identical) — deltas of exactly +0.0000 with
  CI [0, 0] are therefore exact, not noise.

## 4. Structural finding: floors are switches, not filters

Confluence confidence is **discrete**, not continuous. In CONTROL (EURUSD_H1,
qualified rows) the deciding-family confidence takes exactly:

| Rule family | Distinct newConfidence values | n (closed) |
|---|---|---|
| LIQUIDITY | {0.60000000} (constant) | 607 |
| FVG | {0.35, 0.40} | 318 |
| BOS | {0.40, 0.45} | 378 |
| CHOCH | never fires (1 row on M15) | — |
| UNKNOWN | (no ruleName) | 117 |

Consequence: a floor only matters where it lands between two discrete score
values. The grid's ±0.05/±0.10 deltas produce membership changes only at
FVG 0.40 (crosses the 0.35/0.40 boundary; −55% count on H1) and BOS 0.45
(crosses 0.40/0.45; −4%). All other points sit in score gaps → zero effect.
This does not invalidate the grid; it means the pre-registered grid resolves
to at most two informative comparisons per family, and those show no
meaningful mean-R gain.

## 5. Per-family results (decision files + evidence)

### LIQUIDITY (B8 0.60)
| Config | EURUSD_H1 n/meanR | GBPJPY_H1 n/meanR | EURUSD_M15 n/meanR | Verdict |
|---|---|---|---|---|
| CONTROL | 607 / −0.0906 | 96 / −0.0938 | 1694 / −0.1464 | — |
| 0.50 | 607 / −0.0906 (Δ 0) | 100 / −0.1000 (Δ −0.0062) | 1702 / −0.1474 (Δ −0.0010) | KEEP |
| 0.55 | 607 / −0.0906 (Δ 0) | 100 / −0.1000 (Δ −0.0062) | 1702 / −0.1474 (Δ −0.0010) | KEEP |
| 0.65 / 0.70 | 0 closed (all LIQUIDITY rows rejected) | 0 | 0 | KEEP (n/a) |

### FVG (B8 0.35)
| Config | EURUSD_H1 n/meanR | GBPJPY_H1 n/meanR | EURUSD_M15 n/meanR | Verdict |
|---|---|---|---|---|
| CONTROL | 318 / +0.1604 | 39 / −0.3846 | 2092 / +0.0675 | — |
| 0.25 / 0.30 | 318 / +0.1604 (Δ 0) | 39 / −0.3846 (Δ 0) | 2092 / +0.0675 (Δ 0) | KEEP |
| 0.40 | 143 / +0.1748 (Δ +0.0144, CI [−0.0893, +0.0609]) | 25 / −0.8800 (n<10 days) | 1159 / +0.1596 (Δ +0.0921, CI [−0.0492, +0.0641]) | KEEP |
| 0.45 | 0 closed | 0 | 0 | KEEP (n/a) |

FVG_0.40 is the only grid point that moved membership materially. The pooled
day-stratified CI includes 0 on both decision files; the auxiliary daily-mean
CI is wholly negative on EURUSD_H1 ([−0.2530, −0.0308]), i.e. no estimator
supports a gain. The removed rows are the low-R subset (kept meanR rises),
which is the expected mechanical direction — not evidence of a better floor.

### BOS (B8 0.35)
| Config | EURUSD_H1 n/meanR | GBPJPY_H1 n/meanR | EURUSD_M15 n/meanR | Verdict |
|---|---|---|---|---|
| CONTROL | 378 / +0.0079 | 59 / +0.1186 | 2095 / +0.0150 | — |
| 0.25 / 0.30 / 0.40 | identical to CONTROL (Δ 0) | identical | identical | KEEP |
| 0.45 | 364 / +0.0055 (Δ −0.0024, CI [−0.0287, +0.0214]) | 58 / +0.0862 (Δ −0.0324, CI [−0.0619, +0.0000]) | 2056 / +0.0182 (Δ +0.0032, CI [−0.0040, +0.0075]) | KEEP |

## 6. Evidence-only rows (not decision-gating)

- **UNKNOWN** (no fired rule): H1 117 closed, meanR −0.2821, wr 0.2393
  (identical rows to the GR02 B8 UNKNOWN funnel); M15 49 closed, meanR
  −0.0320; GBPJPY_H1 23 closed, meanR +0.1739. Consistent with prior
  evidence — poor family, but small n; no action (protocol 12.2).
- **CHOCH**: never fires in the 3-month window (1 closed row on M15 across all
  configs). Grid non-informative for CHOCH — as expected from GR02 (0 fires).
- **ORDER_BLOCK grid (OB_0.25/0.30/0.40/0.45)**: structurally inert — no rule
  maps to the ORDER_BLOCK family (OB_FVG rules resolve to FVG; the OB floor is
  never the deciding floor), so all four configs are row-for-row identical to
  CONTROL (0/1,558 rows changed) while still recording distinct fingerprints.
  The OB grid points answer "does the OB floor gate anything?" with **no**.

## 7. Interpretation and limits

1. The 3-month screening found **no floor change that improves out-of-sample
   mean R** beyond the pre-registered +0.05 threshold with CI excluding 0 and
   2/2 H1 stability. B8 floors stand.
2. The dominant driver is the discrete-score architecture: at the current
   score granularity the floor space has only a few decision boundaries;
   ±0.05 deltas resolve to at most 2 informative points per family. Any
   future floor experiment should either span multiple score boundaries or
   first make scores continuous (out of scope for ED01).
3. All mean-R point values are low in absolute terms (H1 CONTROL: LIQUIDITY
   −0.0906, FVG +0.1604, BOS +0.0079) under the fixed-RR outcome sim; the
   DD04 TP path is still outside the sim (protocol §1 caveat). ED01-A
   measures admission effects only.
4. Three months is a screening horizon (amendment 13.1): absence of signal
   here is not evidence of no edge. The archived 6-month batch (46 runs) and
   the 12-month horizons remain available for the long-horizon validation
   step, to be triggered by a future decision (e.g., a candidate floor from
   ED01-B or a score-continuity change).

## 8. Next steps

1. ED01-B (protocol §11): liquidity-rule vs non-liquidity-rule conditional
   expectancy — the grid's only near-informative dimension (FVG) suggests
   conditional analysis, not floor tuning.
2. Keep B8 floors frozen; no production input change from ED01-A.
3. Ledger: ED01-A verdicts (all KEEP) — no issue entries required.
