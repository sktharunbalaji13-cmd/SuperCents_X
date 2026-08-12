# Sprint 22 — RL-HYP-01 Decision: Swing-Significance Entry Gate (Admission-Only)

Status: **REJECT — RL-HYP-01 NOT SUPPORTED** — 2026-08-12
Scope owner: entry-admission research, first RL01 hypothesis execution
(RL-HYP-01; seed RL-SWING-01-C01)
Protocol: `docs/Sprint22_RL_HYP_01_Protocol.md` (frozen 2026-08-11,
Amendment A1: opportunity-level primary estimand; Amendment A2: canonical
pairing key, accepted 2026-08-11 at `docs/Sprint22_Pairing_Identity_Review.md`)
Predecessor: Sprint 21 Phase 4 shortlist (`docs/Sprint21_Experiment_Shortlist.md`,
commit `c792d25`) — RL-HYP-01 ranked 1; ED01-E (`docs/Sprint20_ED01E_Decision.md`)
established 2.0R as the empirical fixed-RR benchmark.
Evidence: admissible fixed-build 12-run set (`Tools/ED01/artifacts_FIX/`,
manifest `Tools/ED01/ED01_RLHYP01_manifest_FIX.json`), analysis
`Tools/ED01/results_RLHYP01_FIX.json`, gate transcript
`Tools/ED01/gate_FIX_transcript.txt`.

---

## 1. Executive verdict

**REJECT — the pre-registered swing-significance admission gate does not
demonstrate a material improvement in per-opportunity expectancy over the
ungated 2.0R B8 benchmark on the tested population.**

None of the three pre-registered tiers (1.0 / 1.5 / 2.0 × ATR(14)) clears
the frozen decision ladder on the primary decision file EURUSD_H1:

- largest primary |Δ Mean R| = **+0.0261R (K2P0)**, far below the frozen
  0.10R materiality threshold;
- every primary 95% bootstrap CI **includes 0**;
- every primary Bonferroni-corrected (98.33%) sensitivity CI includes 0;
- the EURUSD_M15 stability partner does not provide contrary evidence
  (all M15 CIs include 0; direction agrees with the primary on all tiers);
- GBPJPY_H1 is evidence-only and remains statistically weak (n ≈ 217,
  41 paired days; widest CIs; sign flips across tiers).

Admissibility is fully established first: 12/12 runs DONE with 0 faults,
all pre-analysis gates pass (fingerprint, row-count, decision-identity
invariance with 0 admitted-row divergences on all nine treatment arms,
distinguishability), A1 opportunity-level identity reproduced on all 9
arms with 0 violations, A2 canonical pairing audits pass, and the analyzer
self-check passes.

**Production impact: NONE.** No production code change occurs under any
verdict (guardrail 1); the gate remains research-only.

## 2. Frozen hypothesis and null

- **Hypothesis (RL-HYP-01):** entries gated to bars where a qualifying
  swing exists — a completed structural pivot whose swing amplitude is
  ≥ k × ATR(14), measured at the pivot bar with the current bar as the
  confirmation close — beat the ungated 2.0R benchmark, per opportunity.
  Exit rules stay fixed 2.0R on both arms (admission-only boundary).
- **Pre-registered tier set (complete, no post-hoc search):** k = 1.0, 1.5,
  2.0 × ATR(14) — exactly 3 pre-registered comparisons vs ungated CONTROL.
- **Null (frozen wording):** "The pre-registered swing-significance
  admission gate does not demonstrate a material improvement in
  per-opportunity expectancy over the ungated 2.0R B8 benchmark on the
  tested population."
- **Primary estimand (Amendment A1):** Δ Mean R = Mean(Treatment_R −
  Control_R) over the complete eligible decision population; for every
  CONTROL decision, Treatment_R = actual rMultiple if the gate ADMITS,
  else **0R if GATED-OUT** (the economic cost/benefit of rejected
  opportunities is part of the measured effect).
- **Secondary estimand (conditional, reported not decision-gating):**
  matched-row Δ Mean R on admitted rows only, plus admission rate and
  gated-out rate per file per tier.
- **Pairing key (Amendment A2):** `{signalTime, configFingerprint, symbol,
  timeframe}` — canonical opportunity identity; `decisionId` is run-local
  telemetry metadata only (certifies the ungated integrity rerun at gate 3a).

## 3. Experimental population and controls

Frozen B8 CONTROL populations (window 2026.04.05 → 2026.07.05), rows
`newDecision == "1"` with settled outcome 1/2/3 (censored excluded and
reported as nOpen); CONTROL arm = frozen B8 artifacts (no new CONTROL runs;
integrity reruns audit-only):

| File | Total | Qualified | Closed | Days | Role |
|---|---|---|---|---|---|
| EURUSD_H1 | 1,558 | 1,468 | **1,420** | 63 | **primary decision file** |
| EURUSD_M15 | 6,239 | 5,981 | **5,931** | 65 | stability partner (2/2 direction required for affirmative) |
| GBPJPY_H1 | 1,560 | 236 | **217** | 41 | evidence-only (n-constrained) |
| GBPJPY_M15 | — | — | — | — | deferred (§15.2.3 Option B) — not in run set |

Frozen fingerprints: EURUSD_H1 `3005138848403243456`, EURUSD_M15
`13548296177162108249`, GBPJPY_H1 `14617585492269479818`. Baseline
(ungated 2.0R) closed-row statistics (frozen, informational): meanR
−0.0239 / −0.0126 / −0.0599; win rate 0.3254 / 0.3315 / 0.3134.

Run set: **12/12 runs DONE, 0 faults** — 3 integrity reruns + 9 tier runs
(3 tiers × 3 files). CONTROL profile identical to the frozen B8 runs;
`SwingSignificanceTier` added (0.0 = OFF for integrity reruns; 1.0 / 1.5 /
2.0 for treatment tiers). All runs on the fixed settlement-isolation
build (Design A, commit `bdac73d`), frozen configuration (2026-08-11),
deterministic seed 20260811 in the analyzer.

## 4. Gate / admissibility evidence

All pre-analysis gates pass on the admissible run set.

| Gate (protocol §11) | Requirement | Result |
|---|---|---|
| Gate 1 fingerprint | every CSV reproduces the frozen per-file fingerprint | **PASS** — includes the ungated integrity reruns (code-equivalence to B8 CONTROL) |
| Gate 2 row-count integrity | CONTROL audit constants reproduced; treatment admitted rows + nGatedOut reported | **PASS** — totals reproduce 1,558/6,239/1,560 exactly; nGatedOut per arm explicit and nonzero (see §5/§6) |
| Gate 3a integrity rerun (decision-identity) | ungated rerun byte-identical to CONTROL on decisionId + all shared columns | **PASS** on all 3 files (only frozen schemaVersion 4→5 flip; gate columns at OFF defaults) — decisionId certified for the integrity certificate |
| Gate 3b admission-only invariance | every admitted row byte-identical to CONTROL in all columns | **PASS — 0 diverging rows / 0 column diffs on all 9 treatment arms** (820/691/521 · 840/695/512 · 3327/2827/2096 admitted rows) |
| Gate 3c distinguishability | nGatedOut ≥ 1 on EURUSD_H1 per tier | **PASS** — EURUSD_H1 nGatedOut 660/781/937; M15 2774/3238/3931; GBPJPY 93/114/147 |
| Gate 4 determinism | analyzer seed 20260811 fixed; rerun byte-identical | **PASS** — self-check (CONTROL vs CONTROL, Ci machinery probe) reproducible |
| Gate 5 audit | closed counts, days, gated-out counts reproduce §4 | **PASS** |
| A2 hard audits | canonical-key uniqueness; every treatment key maps to byte-identical CONTROL row on all non-gate columns; §6 identity (admitted rows contribute d = 0) | **PASS — 0 violations** |
| §6 A1 identity check | Δ Mean R = −(nGatedOut/nTotal) × Mean R(gated-out subset) exactly | **PASS on all 9 arms** — predicted Δ reproduces the observed Δ to the last digit |

Analyzer self-check: **PASS** — the analyzer is deterministic and the
CONTROL population reproduces the frozen audit constants (self-check JSON
`Tools/ED01/results_RLHYP01_selfcheck.json`, analysis JSON
`Tools/ED01/results_RLHYP01_FIX.json`).

Preservation: the original 58-divergence 2026-08-11 artifacts remain
byte-unchanged (per-file SHA-256 re-verified, 0 mismatches) and remain
inadmissible historical evidence; this decision rests exclusively on the
fixed-build run set.

## 5. Primary results — EURUSD_H1 (decision population)

Paired Δ Mean R = opportunity-level per-opportunity expectancy difference
vs ungated 2.0R CONTROL, paired by canonical key, n = 1,420 per arm,
63 paired days, 10,000 day-stratified paired bootstrap resamples, fixed
seed 20260811, gated-out rows = 0R.

| Tier | nAdmitted / nGatedOut | Admission rate | Gated-out rate | Δ Mean R | 95% CI | Daily-mean Δ (CI) | 98.33% sens. CI |
|---|---|---|---|---|---|---|---|
| K1P0 (1.0×ATR) | 760 / 660 | 0.5352 | 0.4648 | **+0.0063** | [−0.0675, +0.0790] | +0.0068 [−0.0664, +0.0790] | [−0.0828, +0.0956] |
| K1P5 (1.5×ATR) | 639 / 781 | 0.4500 | 0.5500 | **+0.0007** | [−0.0884, +0.0885] | +0.0019 [−0.0871, +0.0893] | [−0.1075, +0.1042] |
| K2P0 (2.0×ATR) | 483 / 937 | 0.3401 | 0.6599 | **+0.0261** | [−0.0746, +0.1267] | +0.0278 [−0.0729, +0.1279] | [−0.0973, +0.1475] |

Decision-ladder inputs (primary, all tiers):

| Criterion (protocol §7/§8) | Requirement | Result |
|---|---|---|
| Materiality | \|Δ\| ≥ 0.10R on EURUSD_H1 | **FAIL on all 3 tiers** — max \|Δ\| = **0.0261R** (K2P0) |
| CI requirement | 95% CI excludes 0 | **FAIL on all 3 tiers** — every CI includes 0 |
| Sensitivity | Bonferroni 98.33% CI excludes 0 (disclosed robustness, not a second ladder) | **FAIL on all 3 tiers** — all include 0 |
| Minimum n | ≥ 50 (satisfied by construction) | 1,420 — PASS |
| Paired days | ≥ 10 | 63 — PASS |
| Estimator agreement | pooled + daily-mean must not conflict | PASS — no conflict on any primary tier |
| Structural reachability | gated-out share ≥ 10% (else SAMPLE-CONSTRAINED, cannot reach EVIDENCE) | PASS — 46.5% / 55.0% / 66.0% (all > 10%); no sample-constrained flags |
| A1 identity | §6 identity exact, 0 admitted-row violations | PASS — reproduced on all 3 tiers (predicted = observed Δ) |
| Composition (§9) | UNKNOWN-exclusion + family concentration; no re-selection at REJECT | not invoked — no tier cleared materiality/CI first |

**Key facts (primary):**

- K1P0 Δ +0.0063R; K1P5 Δ +0.0007R; K2P0 Δ +0.0261R.
- **Every primary CI includes zero.**
- **Maximum primary |Δ| = 0.0261R** — below the 0.10R materiality gate.
- **No tier clears the 0.10R materiality gate.** REJECT is a fully valid
  pre-registered conclusion (§2.6): "No tier clears" requires no
  explanation beyond the recorded evidence.

## 6. Stability and evidence populations (reported, not rescuing)

### EURUSD_M15 — stability partner (cannot rescue a failed primary verdict; reported for completeness)

| Tier | nAdmitted / nGatedOut | Gated-out rate | Δ Mean R | 95% CI | 98.33% sens. CI |
|---|---|---|---|---|---|
| K1P0 | 3,157 / 2,774 | 0.4677 | +0.0278 | [−0.0142, +0.0677] | [−0.0217, +0.0771] |
| K1P5 | 2,693 / 3,238 | 0.5459 | +0.0197 | [−0.0284, +0.0697] | [−0.0401, +0.0779] |
| K2P0 | 2,000 / 3,931 | 0.6628 | +0.0175 | [−0.0363, +0.0719] | [−0.0489, +0.0833] |

M15 point estimates are positive-signed on all three tiers but every CI
includes 0 and every |Δ| < 0.10. **M15 does not provide contrary
evidence** — and nothing on M15 is evidence of benefit, either. The 2/2
direction gate is moot because no primary tier reached materiality.

### GBPJPY_H1 — evidence-only (n-constrained; statistically weak by pre-registration)

| Tier | nAdmitted / nGatedOut | Gated-out rate | Δ Mean R | 95% CI | 98.33% sens. CI |
|---|---|---|---|---|---|
| K1P0 | 124 / 93 | 0.4286 | +0.0553 | [−0.0590, +0.1657] | [−0.0816, +0.1961] |
| K1P5 | 103 / 114 | 0.5253 | −0.0138 | [−0.1883, +0.1475] | [−0.2269, +0.1795] |
| K2P0 | 70 / 147 | 0.6774 | −0.0138 | [−0.2279, +0.1912] | [−0.2747, +0.2204] |

Population 217 closed rows, 41 paired days, daily-mean CIs
up to ±0.33R wide, and sign flip (+0.0553 → −0.0138 → −0.0138) across
tiers. All CIs include 0. Global reachability bounds hold (gated-out
shares 42.9%–67.7% > 10%), but the small absolute population leaves the
GBPJPY evidence **statistically weak**, exactly as frozen — it can inform
nothing affirmative and does not contradict the primary REJECT.

## 7. Decision-ladder evaluation (protocol §8)

1. **EVIDENCE — GATE-BETTER?** NO. No tier on EURUSD_H1 reaches
   |Δ| ≥ 0.10R AND 95% CI excluding 0 (materiality is the earliest
   failing rung on all tiers; CI follows on all tiers). Estimator
   agreement and structural reachability hold, but they are downstream
   of a failed materiality/CI combination. No tier is eligible for the
   selection rule; the stability 2/2 requirement is never reached.
2. **REJECT — GATE NOT BETTER?** YES — frozen verdict applies: *"The
   pre-registered swing-significance admission gate does not demonstrate
   a material improvement in per-opportunity expectancy over the ungated
   2.0R B8 benchmark on the tested population."* This is deliberately
   per-opportunity: the secondary matched-row estimates (§6 of the
   protocol) are reported beside it.
3. **DEFER?** NO — n ≥ 50, ≥ 10 paired days, no estimator conflict, no
   clearing-tier M15 disagreement. None of the DEFER triggers fired.
4. **Run-set rejection?** NO — all integrity gates pass.

**Secondary (conditional) result — reported, decision-gated nothing:**
admission rates 34%–57% (H1), 34%–53% (M15), 32%–57% (GBPJPY) — all
≥ 10%, no SAMPLE-CONSTRAINED flags on any arm. Win-rate of admitted rows
is flat vs CONTROL within noise on every file (H1 0.322–0.335 vs 0.3254;
M15 0.341–0.346 vs 0.3315; GBPJPY 0.257–0.331 vs 0.3134). The gate does
not select better trades on the conditional metric either; and even a
positive conditional result would have read as "improves admitted trades
but rejects too much value" — a REJECT, not EVIDENCE.

**Composition (§9):** not reachable — composition gates bind only an
affirmative selection, and no tier cleared the earlier rungs. No
selection is made; no family-confined conclusion is claimed.

## 8. Interpretation and limitations

- **What was tested:** exactly one pre-registered mechanism (swing-significance admission gate, k×ATR(14) amplitude on completed pivots), three pre-registered tiers, three frozen populations, one 3-month window, opportunity-level estimand, canonical pairing, deterministic analysis (seed 20260811). The swing-significance definition and tier set were frozen BEFORE any data examination (§2.5/§2.6 anti-optimization boundary); no threshold was chosen from results.
- **What the verdict means:** this mechanism, tier set, population, and window did not clear the pre-registered evidence standard. It does **not** claim swing significance is useless in all markets or all regimes; those questions remain outside this hypothesis.
- **Limitations carried (frozen, protocol §3):** E1 single-source (Rak 2026) with no independent reproduction — this experiment is, in part, that reproduction attempt on the SCX population and it did not transfer; RL-CONFLICT-01 UNRESOLVED (E2 negative counter-evidence) stays on record with one more pre-registered data point; B8 = all-session including quiet/regime-contaminated hours; one 3-month window; ED01-E measured benchmark (2.0R) not a fitted optimum.
- **Statistical reading of the primary:** measured power bound (SE ≤ 0.037 for H1) is small enough to resolve |Δ| = 0.10 cleanly; observed point estimates (+0.006/+0.001/+0.026R) are an order of magnitude below materiality with CIs that exclude no economically meaningful improvement (e.g., the +0.10R m>argin generally sits at or beyond the 98.33% CI edge on the widest tier). The REJECT reads as a clean null for this population — not a power failure (DEFER would have been the honest label if power were the issue).
- **Known non-issues (frozen, not reopened):** decisionId prevalence vs canonical pairing is settled by Amendment A1/A2; the settlement-isolation defect of the original 2026-08-11 artifacts is settled by the Design-A fix and gate 3a/3b (the original artifacts remain inadmissible historical evidence); telemetry schema v5 gate sentinels verified at OFF defaults across the run set.
- **One-trade-per-bar period artifacts and other 58-divergence files** were investigated (Sprint 22 divergence investigation, adversarial reviews) and do not alter this conclusion.

## 9. Research conclusion

**RL-HYP-01: REJECT — NOT SUPPORTED.**

The swing-significance admission gate provides no evidence of a material
per-opportunity expectancy improvement over the ungated 2.0R B8 benchmark
on the primary EURUSD H1 population; the stability population (EURUSD
M15) provides no contrary evidence; the evidence-only population
(GBPJPY H1) remains statistically weak. The hypothesis as defined is not
supported, and — per §13 of the protocol — is **closed under the current
evidence universe**. RL-CONFLICT-01 remains unresolved with one more
pre-registered data point. Reopening requires genuinely new evidence
(the reserved 6-month archive *`Tools/ED01/artifacts_6mo_2026-01-05_07-05/`*
is the designated follow-up venue) or a §16 amendment proposing a new
definition/tier set — **never re-analysis of this population with
different thresholds**.

## 10. Production impact — NONE

- No production code change occurs under any verdict (guardrail 1; §13).
- The gate stays research-only: `SwingSignificanceGate.mqh` input remains
  default-OFF in production configuration; no new trading parameter is
  recommended from point estimates; no new baseline is established (2.0R
  remains the empirical fixed-RR benchmark per ED01-E).
- No telemetry production behavior change (schema v5 gate columns at OFF
  defaults carry no production semantics).

## 11. Next research / engineering boundary

- **Follow-up venue (designated):** the reserved 6-month archive
  `Tools/ED01/artifacts_6mo_2026-01-05_07-05/` (46 runs) under the same
  frozen protocol discipline — never a second pass on this population.
  Note the reachability bound: any future swing-gate protocol must
  register tiers with structural gated-out share ≥ 10% for the primary
  estimand, and EURUSD_M15 remains the stability partner only.
- **New definition/tier proposals** (e.g., prominence-based significance,
  alternative ATR periods, adaptive thresholds) go through a §16
  amendment record — a NEW pre-registered protocol, explicitly not an
  ad-hoc second pass.
- **RL-observation queue:** RL-OBS-01 stays REPORTED-NOT-WEIGHED (no
  promotion); no hypotheses are invented from these results.
- **Adoption (if ever) would be a separate protocol** with TDD + TT01 +
  explicit decision — this experiment changes nothing.

---

**Evidence files:** `Tools/ED01/results_RLHYP01_FIX.json` (analysis,
seed 20260811, 10,000 iters, canonical pairing, 98.33% Bonferroni
sensitivity), `Tools/ED01/gate_FIX_transcript.txt` (gate pass),
`Tools/ED01/ED01_RLHYP01_manifest_FIX.json` (12/12 DONE, 0 faults),
`Tools/ED01/results_RLHYP01_selfcheck.json` (self-check PASS).
Analyzer: `Tools/ED01/ED01_RLHYP01_Analyze.py`; runner:
`Tools/ED01/ED01_RLHYP01_RunBatch.ps1`.