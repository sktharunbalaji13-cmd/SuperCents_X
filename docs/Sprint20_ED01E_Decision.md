# Sprint 20 — ED01-E Decision: Fixed-RR TP Tier Sweep — 2.0R Remains the Benchmark

Status: **REJECT — 2.0R REMAINS BEST** — 2026-08-09
Scope owner: exit/TP research, fifth measurement milestone (ED01-E)
Protocol: `docs/Sprint20_ED01E_Protocol.md` (frozen 2026-08-09, amendment
§16.1 freeze record)
Predecessor: ED01-D (`docs/Sprint20_ED01D_Decision.md`) — EVIDENCE FIXED-2R
better vs the opposing-liquidity TP; ED01-E tested whether any fixed-RR
tier beats the legacy 2.0R constant as the benchmark for the next exit
experiment.

## 1. Verdict summary

**REJECT — 2.0R REMAINS BEST. NO TIER CLEARS THE PRE-REGISTERED GATE.**

None of the four pre-registered fixed-RR tiers (1.0 / 1.5 / 2.5 / 3.0R)
achieved a material, statistically supported conditional-expectancy
difference versus the 2.0R baseline on the primary file (EURUSD_H1):
all |Δ Mean R| < 0.10, all 95% CIs include 0, all Bonferroni-corrected
(98.75%) CIs include 0, and the 2/2 stability gate is irrelevant because
no tier cleared materiality. The TP-distance dimension is **expectancy-flat
in [1.0, 3.0]R** on this population; **2.0R remains the empirical fixed-RR
benchmark** for the next exit-policy experiment.

| Criterion (protocol §7/§8/§11) | Requirement | Result |
|---|---|---|
| Run-integrity gates 1/2/3a/3b/3c + manifest + fingerprints | PASS | PASS (15/15 runs, pairing key `decisionId`) |
| Materiality | \|Δ\| ≥ 0.10 on EURUSD_H1 | max \|Δ\| = 0.0309 (2.5R) — **FAIL on all 4 tiers** |
| CI requirement | 95% CI excludes 0 on EURUSD_H1 | **FAIL on all 4 tiers** (all include 0) |
| Minimum n | ≥ 50 on EURUSD_H1 | 1,420 — PASS (all arms) |
| Paired days | ≥ 10 on EURUSD_H1 | 63 — PASS (all arms) |
| Estimator agreement | pooled + daily-mean must not conflict | agree on all 4 tiers (both include 0, same sign) — PASS |
| Stability 2/2 | direction agrees H1 + M15 | 3/4 agree (1.5R disagrees: H1 −0.025 / M15 +0.019); not reached — materiality failed first |
| Composition gates | §9 (UNKNOWN-exclusion + family concentration) | PASS — no exclusion changes the conclusion (see §6) |
| MC sensitivity | Bonferroni 98.75% CI excludes 0 | **FAIL on all 4 tiers** (disclosed robustness check, not a second ladder) |
| Selection rule (§8) | largest-|Δ| tier clears full gate + M15 agreement | **no tier cleared → "2.0R REMAINS BEST", not "pick the closest tier"** |

## 2. Population, run set and integrity gates (protocol §3, §11)

Population: **all closed rows of all families** per file (the ED01-D
LIQUIDITY-only stratum was not reused), window 2026.04.05 → 2026.07.05,
rows `newDecision == "1"` with settled outcome 1/2/3 (censored excluded
and reported as nOpen). Frozen audit constants measured 2026-08-09:

| File | Total | Qualified | Closed | Days | FVG | BOS | LIQUIDITY | UNKNOWN | CHOCH |
|---|---|---|---|---|---|---|---|---|---|
| EURUSD_H1 | 1,558 | 1,468 | **1,420** | 63 | 318 | 378 | 607 | 117 | 0 |
| GBPJPY_H1 | 1,560 | 236 | **217** | 41 | 39 | 59 | 96 | 23 | 0 |
| EURUSD_M15 | 6,239 | 5,981 | **5,931** | 65 | 2,092 | 2,095 | 1,694 | 49 | 1 |

Baseline (2.0R) closed-row statistics (frozen, informational): meanR
−0.0239 / −0.0599 / −0.0126; win rate 0.3254 / 0.3134 / 0.3315.

Run set: **15/15 runs DONE** (3 integrity reruns + 12 tier runs = 4 tiers
× 3 files), CONTROL profile + `FixedRRTier` input only, faults 0 on all
runs (tier manifest `Tools/ED01/ED01_E_manifest.json`).

| Gate (protocol §11) | Result |
|---|---|
| Gate 1 compile/fingerprint | PASS — all 15 CSVs reproduce the frozen per-file fingerprints (H1 `3005138848403243456`, GBPJPY `14617585492269479818`, M15 `13548296177162108249`); tier is a settle-time input only (`TelemetryRowBuilder.mqh:61` hardcoded token, verified by unit test) |
| Gate 2 row-count integrity | PASS — total/qualified/closed reproduce the audit constants exactly on every arm (1,558/1,468/1,420; 1,560/236/217; 6,239/5,981/5,931) |
| Gate 3a integrity reruns | PASS — each file's 2.0R rerun row-for-row byte-identical to CONTROL (decisionId + all 75 columns, 0 diverged); **decisionId certified as the pairing key** |
| Gate 3b decision-identity invariance | PASS — tier runs differ from CONTROL in the outcome columns only (outcome, rMultiple, barsHeld, exitPrice, exitReason, outcomeSource); the tier never perturbs decisions |
| Gate 3c distinguishability | PASS — treated closed rows per tier (H1: 733/572/488/488; M15: 3,053/2,470/1,990/1,990; GBPJPY: 765/627/529/529 for 1.0/1.5/2.5/3.0R); TP-hit rate monotonically decreasing in tier on all three files (mechanism sanity, warning-level — PASS) |
| Gate 4 determinism | PASS — analyzer seed 20260813 fixed, rerun byte-identical |
| Gate 5 audit | PASS — closed counts and day counts reproduce §3 exactly |
| Pairing | `decisionId`; unmatched 0 twoR / 0 tier on every arm |

**Data-quality note (recorded, non-gating):** the manifest journal `rows`
field reads `2/0` on all runs (stale agent-log parse); the authoritative
CSV row counts are exact (1,558/1,560/6,239) and reproduce the frozen
audit constants. Faults = 0 on all 15 runs.

Analyzer self-check (`results_ED01E_selfcheck.json`): PASS (audit +
pairing audits empty; machinery probe clean).

## 3. EURUSD_H1 primary result (decision population)

Paired Δ Mean R = Mean R(tier) − Mean R(2.0R), paired by `decisionId`,
n = 1,420 per arm, 63 paired days, 10,000 day-stratified bootstrap
resamples, seed 20260813.

| Tier | Mean R (2.0R) | Mean R (tier) | Δ | 95% CI (pooled) | 95% CI (daily) | Material \|Δ\|≥0.10 | CI excl. 0 |
|---|---|---|---|---|---|---|---|
| 1.0 | −0.0239 | −0.0211 | **+0.0028** | [−0.0881, +0.0966] | [−0.0858, +0.0974] | NO | NO |
| 1.5 | −0.0239 | −0.0493 | **−0.0254** | [−0.0732, +0.0226] | [−0.0724, +0.0236] | NO | NO |
| 2.5 | −0.0239 | −0.0548 | **−0.0309** | [−0.0921, +0.0281] | [−0.0930, +0.0269] | NO | NO |
| 3.0 | −0.0239 | −0.0251 | **−0.0011** | [−0.0879, +0.0838] | [−0.0882, +0.0826] | NO | NO |

All four 95% CIs include 0; the largest point estimate (−0.0309 at 2.5R)
is one third of the 0.10 materiality bar and within noise of the SE
scale (SE(Δ) ≈ 0.053). Pooled and daily-mean estimators agree on every
comparison (both include 0, observed daily deltas +0.0046 / −0.0245 /
−0.0319 / −0.0018) — no estimator conflict.

**Mechanism (transition matrices, 1,420 paired rows per comparison):**
lower tiers convert losses into wins (win rate 0.3254 → 0.4894 at 1.0R)
but cap the winner at the smaller distance, so expectancy does not
improve (Δ ≈ 0); wider tiers raise the target but convert wins into
losses (win rate 0.3254 → 0.2465 at 3.0R) with no expectancy gain
(Δ ≈ 0). The mean-R metric is flat across the entire tier range while
the win-rate / TP-hit-rate tradeoff is clearly visible and monotonic —
a coherent mechanism, not a data artifact.

## 4. EURUSD_M15 stability partner (direction agreement only, never gating alone)

| Tier | Δ | 95% CI (pooled) | Direction vs H1 |
|---|---|---|---|
| 1.0 | +0.0003 | [−0.0453, +0.0461] | agree (both ≈ 0) |
| 1.5 | +0.0192 | [−0.0114, +0.0503] | **disagree** (H1 −0.0254, M15 +0.0192) |
| 2.5 | −0.0121 | [−0.0420, +0.0180] | agree (both negative) |
| 3.0 | −0.0234 | [−0.0727, +0.0268] | agree (both negative) |

All M15 CIs include 0. The 1.5R sign disagreement is recorded (per §8,
a clearing tier with M15 disagreement would have forced DEFER) but was
never reached: no tier cleared materiality on H1. M15 neither rescues
nor overrides; per the registered hierarchy (§12) H1 is the primary
decision file.

## 5. GBPJPY_H1 evidence-only (cannot affect the verdict)

| Tier | Δ | 95% CI (pooled) |
|---|---|---|
| 1.0 | −0.0184 | [−0.1875, +0.1727] |
| 1.5 | +0.0161 | [−0.0932, +0.1361] |
| 2.5 | −0.0046 | [−0.1348, +0.1055] |
| 3.0 | −0.0355 | [−0.2299, +0.1329] |

n = 217, 41 paired days, SE(Δ) ≈ 0.134 — n-constrained by pre-registered
design; all CIs include 0; evidence-only per protocol §12.

## 6. Composition controls (protocol §9, ED01-B discipline)

Primary pooled comparison recomputed on EURUSD_H1 with (a) UNKNOWN rows
excluded and (b) each single family removed (FVG / BOS / LIQUIDITY), for
all four tiers:

| Check | 1.0R Δ | 1.5R Δ | 2.5R Δ | 3.0R Δ |
|---|---|---|---|---|
| Full pooled | +0.0028 | −0.0254 | −0.0309 | −0.0011 |
| Excl. UNKNOWN | +0.0077 | −0.0246 | −0.0444 | −0.0189 |
| minus FVG | +0.0318 | −0.0200 | −0.0067 | +0.0150 |
| minus BOS | −0.0240 | −0.0336 | −0.0527 | −0.0191 |
| minus LIQUIDITY | −0.0098 | −0.0234 | −0.0141 | +0.0286 |

Every recomputed Δ stays below the 0.10 materiality bar with a CI
including 0. **No family exclusion flips a sign or crosses materiality —
the flat-TP conclusion is NOT composition-confined and NOT
UNKNOWN-driven.** (The UNKNOWN-family stratum does show exploratory
effects of its own — §9, recorded, never weighed in the verdict.)

## 7. Multiple-comparison sensitivity (protocol §7, disclosed, never a second ladder)

Bonferroni-corrected CIs (α = 0.05/4 → 98.75%) on EURUSD_H1:

| Tier | Δ | 98.75% CI |
|---|---|---|
| 1.0 | +0.0028 | [−0.1084, +0.1211] — includes 0 |
| 1.5 | −0.0254 | [−0.0865, +0.0350] — includes 0 |
| 2.5 | −0.0309 | [−0.1097, +0.0420] — includes 0 |
| 3.0 | −0.0011 | [−0.1143, +0.1046] — includes 0 |

No comparison survives the corrected CI — consistent with the primary
gate's conclusion; flagged and disclosed per the registered rule.

## 8. Decision ladder execution (protocol §8, exact)

1. Run-set rejection: integrity gates 1/2/3a/3b/3c all PASS, manifest
   15/15 DONE, faults 0 → **no rejection**.
2. EVIDENCE / TIER SELECTED prerequisites on EURUSD_H1: |Δ| ≥ 0.10 AND
   95% CI excludes 0 AND n ≥ 50 AND estimators agree AND M15 2/2 AND
   composition PASS — **not met on any of the 4 tiers** (max |Δ| 0.0309;
   all CIs include 0).
3. REJECT / "2.0R REMAINS BEST": no tier clears the full gate on
   EURUSD_H1 (|Δ| < 0.10 AND CI includes 0 on every tier) → **met**.
4. DEFER triggers: n < 50, < 10 paired days, estimator conflict, or
   clearing-tier M15 disagreement → **not met** (n 1,420, days 63,
   estimators agree; the 1.5R M15 disagreement is moot — no tier
   cleared).
5. Selection rule: **no tier cleared → "2.0R REMAINS BEST", NOT "pick
   the closest tier"** (the anti-tuning guard in §16.1.6 is explicitly
   applied).
6. Direction recorded: **no material direction exists** — all deltas
   within noise (two slightly positive, two slightly negative at H1).

## 9. Final verdict

**REJECT — 2.0R REMAINS BEST. NO TIER CLEARS THE PRE-REGISTERED GATE.**

On the pre-registered EURUSD_H1 closed population (n = 1,420, 63 paired
days), none of the fixed-RR tiers 1.0 / 1.5 / 2.5 / 3.0R differs
materially from the 2.0R baseline: the largest |Δ| is 0.0309 (2.5R,
95% CI [−0.0921, +0.0281]), well below the 0.10 materiality bar, and
all 95% and 98.75% CIs include 0 on all comparisons. The stability
partner (M15, n = 5,931) confirms flatness; GBPJPY_H1 (n = 217) is
evidence-only.

**The TP-distance dimension is expectancy-flat in [1.0, 3.0]R on this
population. The legacy 2.0R constant, previously recorded as "not an
optimum," is now the empirically supported fixed-RR benchmark — the
comparator for the next exit-policy experiment (opposing/adaptive
variants).** 2R being "best" here means "statistically indistinguishable
from every tested alternative" — the flatness, not a tuned optimum, is
the finding.

## 10. No production change from ED01-E

Per protocol §2/§8/§13/§16.1.10 (and the frozen boundary), **no
production code change, no TP-distance change, no TargetResolver change,
and no B8 change occurs under ANY verdict — including this one.**
ED01-E was a benchmark measurement: the `FixedRRTier` input remains at
its default 2.0 (behavior byte-identical to B8, TT01-verified), and no
tier is adopted. Adoption of any tier would require a separate protocol
with TDD + TT01 + explicit decision — none is proposed, because the
evidence shows no tier is better.

## 11. Hypothesis status and reopen conditions (protocol §13)

- **Status:** REJECT closes the tier question **permanently under the
  current evidence universe**: the TP-distance dimension is flat in
  [1.0, 3.0]R, 2.0R stays the benchmark, and the fixed-RR tier sweep is
  **not reopened** by re-analysis of this population.
- **Reopen venues (designated, not immediate):**
  1. The reserved six-month archive (`Tools/ED01/artifacts_6mo_2026-01-05_07-05/`,
     46 runs) as long-horizon confirmation — the same discipline as
     ED01-A/B/C/D. Edge expansion beyond [1.0, 3.0]R is permitted ONLY
     as a pre-registered second stage via a §16 amendment record, never
     ad-hoc.
  2. A future data/model change producing genuinely new evidence.
- **Consequence for the ED sequence:** the fixed-RR benchmark question
  is settled; the **next exit-policy experiment** (opposing/adaptive
  exit variants vs the empirically selected fixed-RR benchmark = 2.0R,
  per protocol §13/§16.1.10) can now proceed with a non-arbitrary
  comparator.

## 12. Exploratory UNKNOWN-family findings (registered caveat — reported, never weighed)

Per protocol §6, family strata are decision-support only and never
standalone verdicts. Recorded for the research record (n-constrained,
not pre-registered as primary comparisons, not reproducible across
files):

| File / stratum | n (days) | 2.5R Δ | 95% CI | 3.0R Δ | 95% CI |
|---|---|---|---|---|---|
| EURUSD_H1 UNKNOWN | 117 (20) | +0.1197 | [0.0478, 0.1935] — excludes 0 | +0.1967 | [0.0285, 0.3517] — excludes 0 |
| GBPJPY_H1 UNKNOWN | 23 (12) | +0.1957 | [0.0690, 0.3529] — excludes 0 | +0.2174 | [−0.2381, +0.6000] — includes 0 |
| EURUSD_M15 UNKNOWN | 49 (4) | +0.0714 | [−0.0283, +0.1446] — includes 0 | −0.0408 | includes 0 |

- **What it says:** on EURUSD_H1's UNKNOWN-family rows (n = 117 — the
  worst-expectancy family, meanR −0.2821 at 2R), wider tiers (2.5R/3.0R)
  are associated with partially recovered expectancy (meanR −0.1624 /
  −0.0854) with CIs excluding 0. GBPJPY_H1 UNKNOWN (n = 23) shows a
  similar 2.5R point estimate; M15 UNKNOWN (n = 49, 4 days) does not
  reproduce it.
- **Why it is not a verdict input:** (a) family-stratum statistics are
  pre-registered as decision-support only (§6); (b) UNKNOWN-exclusion
  (§9) shows the pooled conclusion is not UNKNOWN-driven; (c) the
  signal does not reproduce across files (M15 fails), and the stratified
  n's (23–117) sit at or below the pre-registered noise floor for
  independent inference; (d) selection of any tier for UNKNOWN rows
  would be a post-hoc stratum carve-out, forbidden by §2.4/§16.1.6.
- **Designated venue:** any follow-up on the UNKNOWN-family tier
  response belongs in a pre-registered second-stage protocol (or the
  reserved six-month archive) — never derived from this decision doc.

## 13. Implications for the ED sequence

- ED01-E is the second completed exit-side measurement (after ED01-D)
  and the first **null with an informative benchmark**: the sequence
  now has an empirically supported fixed-RR comparator for all future
  exit-policy experiments.
- Combined reading with ED01-D: exit resolution policy is expectancy-
  relevant (opposing-liquidity loses to fixed-2R), but within fixed-RR
  the distance dimension is flat in [1.0, 3.0]R. The exit lever is the
  **resolution policy**, not the distance.
- Discipline preserved: the anti-tuning guard (§16.1.6: "2.0R REMAINS
  BEST, not pick the closest tier") was applied; no production change,
  no tier adoption, no B8 change.
- Artifacts, tier manifest, analyzer outputs (primary + supplement +
  self-check), and the frozen protocol remain preserved on disk and in
  protocol history. Analysis artifacts are gitignored; protocol,
  analyzer, manifest and results are committed.
