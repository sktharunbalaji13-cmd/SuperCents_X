# Sprint 22 — RL-HYP-01 Protocol: Swing-Significance Entry Gate (Admission-Only)

Status: **FROZEN — user-approved 2026-08-11** (freeze record §15.1,
Amendment A1: primary estimand changed to opportunity-level paired
expectancy, gated-out = 0R; matched-row analysis demoted to secondary).
No code, no runs, no analyzer yet. Engineering (TDD) is authorized after
this freeze; run production remains gated at §15.3 step 3.
Date: 2026-08-11
Scope owner: entry-admission research, first RL01 hypothesis execution
(RL-HYP-01; seed RL-SWING-01-C01)
Predecessor: Sprint 21 Phase 4 shortlist (`docs/Sprint21_Experiment_Shortlist.md`,
commit `c792d25`) — RL-HYP-01 ranked 1, NOT-SELECTED; user selection of this
hypothesis is the gate that opens Sprint 22 (this protocol). ED01-E
(`docs/Sprint20_ED01E_Decision.md`, commit `acd2ca4`) established 2.0R as the
empirical fixed-RR benchmark; ED01-D/B/C/A are referenced as frozen E1
population evidence.

---

## 1. Purpose and scope

RL-HYP-01 asks whether swing-significant pivots carry forward information on
EURUSD H1: **do entries gated to bars where a qualifying swing exists beat the
ungated 2.0R benchmark?**

This protocol pre-registers the definition of swing significance BEFORE any
threshold is examined in data — the anti-optimization boundary of §2.6. It
mirrors the ED01-E protocol structure (population, estimator, gates, ladder)
with the admission-gate adaptations required because the treatment changes
**which decisions exist**, not only how existing decisions settle.

Scope boundary: the experiment tests an **entry-admission gate only**. Exits
stay fixed 2.0R on both arms. No confluence weight, floor, validator, TP
resolution, or baseline change is part of this experiment (guardrail 3).

## 2. Guardrails (non-negotiable)

1. **No production change under any verdict** — the gate never enters
   SuperCents_X as a side-effect of this experiment. Adoption (if any) is a
   separate protocol with TDD + TT01 + explicit decision.
2. **Frozen B8 baseline untouched** — the CONTROL arm is the frozen B8
   CONTROL artifacts (EURUSD_H1 / GBPJPY_H1 / EURUSD_M15) with their frozen
   fingerprints; the treatment arm must prove decision-identity on admitted
   rows (gate 3b) and row-count integrity (gate 2).
3. **Admission-only boundary** — the gate may only admit or not-admit an
   entry candidate. It cannot change the entry parameters of an admitted
   decision (no weight, floor, TP, SL, or confluence modification). Any
   divergence beyond admission → run set rejected.
4. **Paper-first:** this protocol freezes before any prerequisite code
   (TDD RED→GREEN, TT01) — mirror of ED01-E §14.
5. **Pre-registered comparisons only:** the swing-significance definition
   and tier set (§5) are fixed at freeze. No post-hoc threshold search, no
   step-down selection, no threshold-tweaking after seeing results.
6. **Anti-optimization boundary (the critical rule):** the swing threshold
   is NOT chosen because it produces the best historical result. Thresholds
   are justified by the literature/engineering record BEFORE the experiment
   (§5 rationale), and every pre-registered tier is tested with the full
   gate stack. **"No tier clears" is a fully valid conclusion.** If the
   evidence suggests an untested threshold region after results, that is a
   NEW pre-registered protocol via a §16-style amendment record — never an
   ad-hoc second pass on this population.
7. **No re-freeze without amendment:** any change to population, definition,
   tiers, metric, seed or ladder goes through a §16 amendment record
   (ED01-D §16.2 precedent) preserving the original text.
8. **Composition discipline (ED01-B lesson):** family strata and
   gated-out-row accounting are pre-registered; a conclusion carried by one
   family or one stratum is reported as composition-confined, never selected.
9. **Deterministic analysis:** fixed seed, reruns byte-identical
   (ED01-A→E discipline).
10. **Raw evidence retained locally:** artifacts gitignored; protocol,
    analyzer, manifest, results, decision committed.

## 3. Literature basis and declared limitations (carried from Phase 3/4)

The hypothesis rests on RL-SWING-01 (Rak 2026, VGRSI visibility-graph
signals, EUR/USD + DJI30 + XAU/USD, 503 trading days 2024–2025). The
following limitations are part of the protocol, not footnotes:

| Limitation | Recorded in | Consequence for interpretation |
|---|---|---|
| E1 single-source | ledger RL-SWING-01-C01/C02; Phase 3 §2; shortlist §2 | Positive evidence has no independent reproduction; a null verdict is not "the literature is wrong", it is "the single source does not transfer to the SCX population" |
| WARNING-REPRO-PENDING | ledger RL-SWING-01-C01/C02/C03 flags | No independent reproduction exists; this experiment is, in part, that reproduction attempt on the SCX population |
| Optimization-window dependency | ledger RL-SWING-01-C03; shortlist §2 | The VGRSI result used a rolling 30-day optimization window. **This protocol introduces NO optimization process of any kind** (§2.5/§2.6) — the gate parameters are frozen constants |
| RL-CONFLICT-01 UNRESOLVED | ledger §4; Phase 3 §4; shortlist §2 | E2 negative counter-evidence (SWING-02 era-decay, BOS-03 re-bounce, SWING-04 OHLCV cost ceiling) stays on record; the verdict does not resolve the conflict — it adds one pre-registered data point |
| E2 negative counter-evidence | ED01-B: BOS +0.0079 (no distinct edge) | The FX-population prior leans against continuation edge; the materiality bar is deliberately symmetric (two-sided, §8) |

## 4. Population (frozen, exact definition)

- **Primary decision file:** EURUSD_H1 — frozen B8 CONTROL artifacts
  `Tools/ED01/artifacts/EURUSD_H1/CONTROL/telemetry_v4_*.csv`, window
  2026.04.05 → 2026.07.05, fingerprint `3005138848403243456`. Closed rows:
  1,420; 63 days (ED01-E §3 constants).
- **Stability partner:** EURUSD_M15 — fingerprint `13548296177162108249`,
  closed 5,931, 65 days. Direction agreement required 2/2 for an
  affirmative verdict; cannot rescue a failed primary verdict (ED01-D/E §12
  hierarchy).
- **OOS (primary decision file unused in any fitting):** GBPJPY_H1 —
  fingerprint `14617585492269479818`, closed 217, 41 days, **evidence-only**
  (n-constrained, ED01-E §12).
- **OOS GBPJPY_M15:** NO frozen B8 CONTROL artifact exists for this file in
  the ED01 sequence (ED01-E ran H1/GBPJPY_H1/M15 only). **RESOLVED at the
  2026-08-11 freeze review — Option B: deferred** (§15.2.3): GBPJPY_M15 is
  NOT in the Sprint 22 run set; OOS set = GBPJPY_H1 (evidence-only) +
  EURUSD_M15 (stability). A future §16 amendment/extension may add
  GBPJPY_M15 as a new OOS venue.
- **Row filter (exact, both arms):** `newDecision == "1"` only; closed rows
  with `outcome in ("1","2","3")`; censored (`outcome == "0"`) excluded and
  reported as `nOpen`. **Family strata** (FVG, BOS, LIQUIDITY, UNKNOWN;
  CHOCH evidence-only) reported for composition gates (§9).
- **Measured size expectations (frozen constants, measured 2026-08-09,
  read-only sizing from frozen CONTROL artifacts — ED01-E Appendix A):**

| File | Total | Qualified | Closed | Days | Role |
|---|---|---|---|---|---|
| EURUSD_H1 | 1,558 | 1,468 | **1,420** | 63 | primary |
| EURUSD_M15 | 6,239 | 5,981 | **5,931** | 65 | stability partner |
| GBPJPY_H1 | 1,560 | 236 | **217** | 41 | evidence-only |
| GBPJPY_M15 | — | — | — | — | deferred (§15.2.3) |

Baseline (2.0R CONTROL) closed-row statistics (frozen, informational):
EURUSD_H1 meanR −0.0239, win rate 0.3254; GBPJPY_H1 −0.0599, 0.3134;
EURUSD_M15 −0.0126, 0.3315; σ(rMultiple) 1.4055 / 1.3916 / 1.3992
(ED01-E §3).

## 5. Swing-significance definition (pre-registered — the open item resolved HERE)

The engine today detects swings with `SWING_STRENGTH = 2` (2 bars
lookback/lookahead, `Utils/Constants.mqh:72`) and has **no significance
filter** (Sprint 18 research `01_Swing_Detection.md` §Phase 8 E1, verbatim:
"`SWING_STRENGTH` fixed at 2/2 with no significance filter
(`SwingDetector.mqh:204-230`)"; §Phase 8 E2, verbatim: "SuperCents_X: no
significance concept at all today"; the engine's `SwingDetector.mqh` /
`StructuralPivotEngine.mqh` API docs are frozen at v0.8.0). The hypothesis
therefore requires a definition of "significant" that is (a) implementable
from OHLCV on the existing pivot engine, (b) justified before any data
examination, and (c) fixed at freeze.

**Definition (frozen at the 2026-08-11 freeze review, §15.2.1):**
a qualifying swing is a completed structural pivot whose swing amplitude —
the price distance from the preceding alternating pivot to the pivot itself
(|high − preceding low| for a high pivot; |low − preceding high| for a low
pivot) — is ≥ k × ATR(14), measured at the pivot bar with the current bar
acting as the confirmation close (no repainting; the gate resolves only on
completed pivots with the full `SWING_STRENGTH × 2 + 1` bar requirement).

**Pre-registered tier set (each tier is a separate pre-registered comparison
vs CONTROL, ED01-E multiplicity discipline):**

| Tier k | Value | Justification (literature/engineering record — NOT data) |
|---|---|---|
| k1 | 1.0 × ATR(14) | Floor of the modern ATR-qualified pivot standard (Sprint 18 §Phase 8 E1 implementation survey: ATR(14)×mult is the majority standard in serious open-source swing tools); minimal filtering |
| k2 | 1.5 × ATR(14) | Mid-range of the same standard; separates moderate from marginal pivots |
| k3 | 2.0 × ATR(14) | Upper range of the standard; strongest filtering, smallest admission share |

- The tier set is the COMPLETE set. No tier may be added, removed, or
  re-scaled after freeze (§2.6).
- **Comparison strategy:** exactly 3 pre-registered comparisons (k1, k2, k3
  vs ungated CONTROL), each through the full gate stack (§8) with
  Bonferroni-corrected sensitivity (α = 0.05/3 → 98.33%, §7) reported.
- **Definition alternatives:** prominence-based significance (scipy
  `find_peaks`-style prominence, Sprint 18 E2) and other ATR periods were
  considered at the freeze review and **NOT adopted** (§15.2.1). Post-freeze
  definition changes require a §16 amendment record.

**No qualifying swing — admission behavior (pre-registered):**
- At decision time, if no completed structural pivot in the trailing
  `SWING_STRENGTH × 2 + 1` bars of the decision bar satisfies the tier's
  amplitude criterion, the entry candidate is **NOT admitted** (gate = OUT).
- Gated-out candidates produce NO decision in the treatment arm; they are
  counted as `nGatedOut` per file and reported (never silently dropped);
  the paired analysis assigns them Treatment_R = 0R (§6).
- The gate NEVER retrofits: it evaluates only pivots completed before the
  decision bar's open. No look-ahead, no repainting (gate 3b proof).

## 6. Primary metric and estimator

- **Primary estimand (opportunity-level, Amendment A1 — §15.1):** Δ Mean R =
  Mean(Treatment_R − Control_R) over the **complete eligible decision
  population** (all closed CONTROL rows per §4), per file. For every CONTROL
  decision:
  - Control_R = the CONTROL row's actual rMultiple;
  - Treatment_R = the CONTROL row's actual rMultiple **if the gate ADMITS**,
    else **0R if GATED-OUT** (the gated strategy experiences no return on a
    rejected opportunity — the economic cost/benefit of rejecting trades is
    part of the measured effect, not removed by matching).
  This answers RL-HYP-01 as posed: does gating entries to bars with a
  qualifying swing improve expectancy per opportunity versus taking every B8
  entry at 2.0R?
- **Pairing (admission-gate adaptation — the shortlist's pairing invariant):
  ** pairing is now **total**: every eligible CONTROL row has exactly one
  treatment outcome (ADMITTED → actual outcome; GATED-OUT → 0R). No
  unmatched rows exist by construction. Pairing key = `decisionId`
  (certified by gate 3a/3b on the run set); the analyzer reconstructs
  Treatment_R = 0R for CONTROL decisionIds absent from the treatment CSV.
- **Decision-identity consequence (pre-registered, from gate 3b):** because
  admitted rows are byte-identical to CONTROL in all columns, d =
  Treatment_R − Control_R ≡ 0 on every admitted row; the entire measured
  effect concentrates on gated-out rows:
  **Δ Mean R = −(nGatedOut / nTotal) × Mean R(gated-out CONTROL subset).**
  The analyzer must verify this identity (admitted rows contribute exactly
  0) as an internal consistency check.
- **Bootstrap 95% CI (pre-registered):** paired day-stratified bootstrap,
  10,000 resamples, fixed seed **20260811** (new seed for RL-HYP-01), same
  estimator family as ED01-A→E:
  - Resample days with replacement from the union of days holding any
    eligible CONTROL row; each sampled day contributes all its paired
    (Treatment_R − Control_R) differences; the pooled mean difference over
    sampled rows is one draw. CI = 2.5/97.5 percentiles.
  - **Auxiliary estimator (reported, not gating):** mean of per-day mean
    paired differences. Sign disagreement with a CI excluding 0 in one
    estimator and not the other → DEFER (estimator conflict, §8).
  - Require ≥ 10 paired days, else DEFER (measured: H1 63, M15 65 — held as
    a gate; GBPJPY evidence-only).
- **Secondary estimand (conditional — reported, NOT decision-gating):**
  matched-row analysis — Δ Mean R on **admitted rows only** (the former
  primary), plus per file per tier: **admission rate** (admitted / CONTROL
  opportunities) and **gated-out rate** (gated-out / CONTROL opportunities).
  Purpose: separates "does the gate improve overall per-opportunity
  expectancy" (primary) from "what happens specifically to the trades that
  survive the gate" (secondary). A tier may show a positive conditional
  effect while failing the primary — that combination reads as "the gate
  improves admitted trades but rejects too much value, netting no material
  gain": a REJECT, not an EVIDENCE (§8).

## 7. Effect-size criterion (pre-registered)

| Threshold | Value | Rationale |
|---|---|---|
| Minimum meaningful \|Δ Mean R\| | **0.10** | Same practical-effect threshold as ED01-B/C/D/E (0.10 R = 10% of one unit of risk) |
| CI requirement | 95% bootstrap CI excludes 0 | Same discipline as ED01-A→E |
| Stability | Direction agrees in 2/2 resolvable populations (EURUSD_H1 + EURUSD_M15) | ED01-C/D/E §12 hierarchy, registered pre-analysis |
| Minimum n (primary) | full eligible population per file (H1 1,420, M15 5,931 — ≥ 50 by construction) | ED01-A §7 noise floor |
| Minimum n (secondary) | ≥ 50 admitted rows to report the conditional estimate, else flagged n-constrained | reporting discipline only; never gates EVIDENCE |
| Estimator agreement | pooled + daily-mean must not conflict | Guards count-asymmetry artifacts |
| Multiple-comparison handling (3 tests: k1/k2/k3 vs ungated) | Primary gate = full combination (CI + materiality + 2/2 + composition); Bonferroni-corrected CIs (α = 0.05/3 → 98.33%) reported as disclosed robustness sensitivity only — never a second ladder | ED01-E §7 verbatim discipline |

**Structural reachability bound (pre-registered):** under fixed 2.0R exits,
every rMultiple ∈ [−1.0, +2.0], so Mean R of any gated-out subset ≥ −1.0.
By the §6 identity, |Δ| = (nGatedOut / nTotal) × |Mean R(gated-out)| ≤
(nGatedOut / nTotal) × 1.0 — **a gated-out share ≥ 10% is structurally
necessary for any tier to reach |Δ| ≥ 0.10**. Tiers below that share are
SAMPLE-CONSTRAINED for the primary estimand (§9.3) and cannot reach
EVIDENCE; this is a pre-registered consequence of the fixed exit rule, not
a threshold chosen from data.

## 8. Pre-registered decision rules

- **EVIDENCE — GATE-BETTER:** on the primary file (EURUSD_H1),
  **opportunity-level** |Δ| ≥ 0.10 AND 95% CI excludes 0 AND n ≥ 50
  (satisfied by construction, §4) AND estimators agree AND direction agrees
  with EURUSD_M15 (2/2) AND composition gates (§9) pass AND run-integrity
  gates (§11) pass. **Selection rule (tiers):** the tier with the largest
  |Δ| among those clearing the full gate on EURUSD_H1; if more than one
  clears, the largest-|Δ| winner with M15 agreement wins; a clearing tier
  with M15 DISAGREEMENT → DEFER (instability). Verdict consequence: the
  tier is a candidate for a separate production adoption protocol — **still
  no production change from this experiment**.
- **REJECT — GATE NOT BETTER:** no tier clears the full gate on EURUSD_H1
  (opportunity-level |Δ| < 0.10 OR CI includes 0 on every tier). Verdict
  wording (frozen): **"The pre-registered swing-significance admission gate
  does not demonstrate a material improvement in per-opportunity expectancy
  over the ungated 2.0R B8 benchmark on the tested population."** This is
  deliberately per-opportunity — it does not claim the gate has no
  conditional information; the secondary matched-row results are reported
  alongside (§6). A positive conditional effect with a failed primary reads
  as "the gate improves admitted trades but rejects too much value, netting
  no material gain". Verdict consequence: the hypothesis as defined is not
  supported; RL-CONFLICT-01 remains unresolved with one more pre-registered
  data point.
- **DEFER:** n < 50 on EURUSD_H1 (not reachable by construction), OR < 10
  paired days, OR pooled/daily-mean estimator conflict, OR a clearing-tier
  M15 direction disagreement. Verdict consequence: hypothesis stays open;
  the reserved 6-month archive
  (`Tools/ED01/artifacts_6mo_2026-01-05_07-05/`, 46 runs) is the designated
  follow-up venue — never another re-analysis of this population.
- **Run-set rejection (no verdict):** any integrity-gate failure (§11) →
  run set invalid; no verdict emitted; re-run after audit.
- **No production change occurs under ANY verdict.**

## 9. Composition controls (ED01-B discipline, pre-registered)

1. **UNKNOWN-exclusion:** opportunity-level pooled view recomputed with
   UNKNOWN rows removed; if the selected tier's verdict changes sign or
   falls below 0.10 → reported as UNKNOWN-driven, never selected.
2. **Single-family concentration:** removing any one family (FVG, BOS,
   LIQUIDITY) must not flip the selected tier's sign or drop |Δ| below
   0.10; if it does, the conclusion is composition-confined — reported,
   never selected.
3. **Admission/gated-out share audit (both directions, pre-registered):**
   per file and per tier, `nGatedOut`, the admission rate (admitted /
   CONTROL opportunities) and the gated-out rate (gated-out / CONTROL
   opportunities) are reported.
   - **Secondary estimand:** a tier whose **admission rate < 10%** of
     CONTROL closed rows is flagged **SAMPLE-CONSTRAINED** for the
     conditional matched-row estimate and cannot reach EVIDENCE on that
     basis (too few admitted rows to condition on).
   - **Primary estimand:** a tier whose **gated-out rate < 10%** is flagged
     **SAMPLE-CONSTRAINED** and cannot reach EVIDENCE — by the structural
     reachability bound (§7), |Δ| ≤ gated-out share × 1.0 < 0.10 is
     mathematically unreachable under fixed 2.0R exits, regardless of the
     rejected rows' quality.
4. **Eligibility integrity check (audit):** closed-family counts reproduce
   §4 exactly on every arm.

## 10. Power / feasibility (pre-registered, measured constants)

Under the opportunity-level estimand (§6) the paired difference d is
nonzero ONLY on gated-out rows (d ≡ 0 on admitted rows, gate 3b), so
Var(d) = (nGatedOut / nTotal) × E[r² | gated-out] ≤ (share) × (σ² + μ²) ≈
share × 1.98 (ED01-E §10: σ ≈ 1.40) and SE(Δ) ≤ sqrt(share × 1.98 / n):

| File | Eligible CONTROL n | SE(Δ) upper bound (share ≤ 1) | Reachability of \|Δ\| = 0.10 | Role |
|---|---|---|---|---|
| EURUSD_H1 | 1,420 | ≤ 0.037 | gated-out share ≥ 10% (structural bound §7) | primary — resolves \|Δ\| = 0.10 |
| EURUSD_M15 | 5,931 | ≤ 0.018 | gated-out share ≥ 10% | stability partner |
| GBPJPY_H1 | 217 | ≤ 0.096 | gated-out share ≥ 10% | evidence-only |
| GBPJPY_M15 | — (Option B: deferred) | — | — | not in run set |

- Pre-declared: EVIDENCE requires H1 + M15 direction agreement; a null
  (gate not better) can be reached from EURUSD_H1 alone when no tier CI
  excludes 0 (ED01-E §10 pattern).
- The actual `nGatedOut`, admission rate and gated-out rate are computed at
  the run gate (§11) from the frozen artifacts and reported in the decision
  doc — a reporting duty, not a decision gate (the share gates of §9.3 are
  the gates).

## 11. Engineering gates (analysis milestones)

1. **Compile/fingerprint (hard):** every new run compiles from HEAD; every
   CSV reproduces the frozen per-file CONTROL fingerprints (§4). The gate
   must be engineered so admitted rows carry byte-identical fingerprints to
   CONTROL (gate parameter OUTSIDE the fingerprint — the ED01-E
   `"FixedRR"/"1"` hardcoded-token precedent, §14 engineering spec).
2. **Row-count integrity (hard):** the CONTROL arm reproduces the frozen
   audit constants (§4) exactly (total/qualified/closed per file);
   each treatment run reproduces the same total/qualified counts on its
   **admitted** rows, with `nGatedOut` (CONTROL closed − treatment closed)
   reported explicitly and matching the gate telemetry (CONTROL:
   nGatedOut = 0 by construction). Any count divergence → run set rejected.
3. **At-scale distinguishability + decision-identity invariance (hard):**
   a. **Integrity rerun (ungated, new code):** a full ungated rerun of each
      file is row-for-row byte-identical to the frozen CONTROL artifacts
      (decisionId + all 75 columns) — proves code-equivalence; ANY
      divergence → run set rejected. Pairing-key proof: decisionId
      certified here.
   b. **Admission-only invariance:** for every tier run, admitted rows are
      byte-identical to CONTROL in ALL columns (the gate must not perturb
      any admitted decision); gated-out rows are absent from the treatment
      CSV (the analyzer reconstructs Treatment_R = 0R for those decisionIds,
      §6). Any divergence on an admitted row → run set rejected. The
      analyzer additionally verifies the §6 identity: every admitted row
      contributes d = 0 exactly.
   c. **Distinguishability per tier:** each tier has at least one gated-out
      row (nGatedOut ≥ 1 on EURUSD_H1); zero gated-out rows → run set
      rejected (the tier must actually gate).
4. **Determinism (hard):** analyzer seed fixed (20260811); rerun reproduces
   identical CIs and JSON.
5. **Audit:** closed counts, days, and gated-out counts reproduce §4/§11.3c
   exactly.

## 12. OOS files and hierarchy (registered, pre-analysis)

- **EURUSD_H1 — primary decision file.**
- **EURUSD_M15 — stability partner** (cannot independently establish an
  effect; direction must agree 2/2 for an affirmative verdict).
- **GBPJPY_H1 — evidence-only** (n = 217, n-constrained, ED01-E §12
  hierarchy).
- **GBPJPY_M15 — not in the run set** (deferred at the 2026-08-11 freeze
  review, §15.2.3; a future OOS extension via §16 amendment).
- M15 and GBPJPY files cannot rescue a failed EURUSD_H1 verdict.

## 13. What closes the hypothesis, what reopens it

- **Closed under the current evidence universe:** REJECT — no tier clears
  the gate — the pre-registered swing-significance admission gate
  demonstrates no material improvement in **per-opportunity expectancy**
  over the ungated 2.0R B8 benchmark on the tested population (§8 verdict
  wording, frozen). Reopening requires genuinely new evidence (the reserved
  6-month archive or a future data/model change) or a §16 amendment
  proposing a new definition/tier set — never re-analysis of this population
  with different thresholds.
- **EVIDENCE consequence:** the tier is a candidate for a separate
  production adoption protocol (TDD + TT01 + explicit decision) — this
  experiment itself changes nothing.
- **DEFER consequence:** hypothesis stays open; designated follow-up =
  6-month archive under the same protocol discipline.

## 14. Run production and engineering prerequisite (post-freeze only)

- **Prerequisite engineering (authorized AFTER freeze):** a swing-gate
  input `SwingSignificanceTier` (double, default 0.0 = OFF/ungated) → gate
  resolves on the frozen `SwingDetector`/`StructuralPivotEngine` pivot
  chain → admission filter upstream of decision creation. TDD: RED (gate
  absent) → GREEN; tests: (a) amplitude = k×ATR(14) criterion on completed
  pivots, (b) no-qualifying-swing → not admitted, (c) admitted rows
  byte-identical to ungated (gate 3b), (d) fingerprint invariance under
  gate (hardcoded token, ED01-E precedent), (e) default 0.0 = byte-identical
  vs B8; TT01 full gate PASS with BEHAVIOR-REGRESSION byte-identical under
  default OFF (no baseline re-freeze).
- **Required telemetry (NOT-IMPLEMENTED today — shortlist §2):** new
  columns: qualifying swing ID + significance amplitude (k×ATR value) at
  decision time, gate decision (ADMIT / GATE-OUT with tier), entry decision
  (existing). These must exist to prove the gate operated (§11.3b). Schema
  change follows the frozen telemetry versioning discipline.
- **Run set:** CONTROL = frozen B8 artifacts (no new runs for the control
  arm; integrity reruns audit-only). Treatment = 3 tiers × files
  (EURUSD_H1, EURUSD_M15, GBPJPY_H1) = **9 new runs** + 3 integrity reruns
  (GBPJPY_M15 deferred, §15.2.3). Profile =
  `Tools/ED01/ini/<FILE>_CONTROL.ini` identical to CONTROL (ED01-E §14),
  `SwingSignificanceTier` added.
- **Artifacts:** `Tools/ED01/artifacts/<FILE>/CONTROL_RLHYP01_K1P0/`,
  `K1P5/`, `K2P0/`, `INTEGRITY/` with `.done` markers; runner + manifest
  (ED01-E pattern); analyzer `Tools/ED01/ED01_RLHYP01_Analyze.py`.
- **Pairing:** decisionId certified at gate 3a; gated-out CONTROL rows
  assigned Treatment_R = 0R and reported as nGatedOut (§6) — no unmatched
  rows exist.

## 15. Amendments

### 15.1 Freeze record (2026-08-11, user approval)

Frozen 2026-08-11 on user review. **One pre-freeze amendment (Amendment A1)
was incorporated before freezing — the primary estimand.** The user review
identified that the as-drafted matched-row estimand measured the conditional
effect of the gate on admitted trades and removed the economic cost/benefit
of rejected opportunities, which does not answer RL-HYP-01 as posed. A1:

- **A1 (accepted, verbatim recommendation):** primary metric changed from
  matched-row Δ Mean R to **opportunity-level paired strategy expectancy**:
  for every CONTROL decision, Treatment_R = actual rMultiple if ADMITTED,
  0R if GATED-OUT; Δ Mean R = Mean(Treatment_R − Control_R) across the
  complete eligible decision population (§6). The matched-row analysis is
  retained as the **secondary** (conditional) estimand with admission rate
  and gated-out rate reported. REJECT verdict wording made per-opportunity
  (§8) to avoid claiming the gate has no conditional information.
- All five §15.2 open decisions resolved as recorded below (no further
  changes at freeze). Protocol is exactly as drafted after A1; no changes
  at freeze beyond the freeze record.

### 15.2 OPEN DECISIONS — resolved at the 2026-08-11 freeze review (recorded, frozen)

1. **Swing-significance definition:** **RESOLVED — k×ATR(14) amplitude**
   (§5 Definition). Chosen over prominence: simple, deterministic,
   OHLCV-compatible, naturally implementable on the existing pivot
   architecture. Prominence-based significance is NOT adopted.
2. **Tier set:** **RESOLVED — {1.0, 1.5, 2.0} × ATR(14)** (3 comparisons).
   Sufficient to span weak/moderate/strong significance without turning the
   experiment into threshold optimization.
3. **GBPJPY_M15:** **RESOLVED — Option B (defer).** OOS set = GBPJPY_H1
   (evidence-only) + EURUSD_M15 (stability). GBPJPY_M15 is not in the
   Sprint 22 run set; no new CONTROL run is produced; it remains a future
   OOS extension (§4, §14).
4. **Random seed:** **RESOLVED — 20260811.** No change.
5. **Multiple-comparison α:** **RESOLVED — Bonferroni α = 0.05/3 → 98.33%**
   sensitivity CIs, disclosed robustness only, never a second decision
   ladder (ED01-E §7 discipline).

Post-freeze changes to any of these require a §16 amendment record.

### 15.3 Execution order (frozen once approved)

1. **Protocol freeze** (this document → FROZEN on user approval; committed;
   pushed to origin).
2. **Prerequisite engineering** — swing gate + telemetry (TDD + TT01;
   default OFF byte-identical vs B8; no baseline re-freeze).
3. **STOP for review before any run** (ED01-E §16.1.11 pattern).
4. **Analyzer + runner** — `ED01_RLHYP01_Analyze.py` + run batch script;
   outputs `results_RLHYP01.json`.
5. **Analyzer self-check** — audit constants + determinism on frozen
   CONTROL artifacts.
6. **Run production** — treatment runs + integrity reruns; artifacts +
   manifest (GBPJPY_M15 deferred per §15.2.3; no new CONTROL runs).
7. **Pre-analysis gate** — §11 gates (a)–(c) verified.
8. **Analysis run** — paired analysis per §6 (seed 20260811).
9. **Decision report** — `docs/Sprint22_RL_HYP_01_Decision.md`: verdict +
   evidence (primary, secondary, composition, MC sensitivity, gated-out
   accounting, determinism, gate results).
10. **Plan register** — RL-HYP-01 row DONE with evidence.
11. **Commit + push** — dedicated Sprint 22 commit(s); TT01 full gate after
    any production code change (none expected under any verdict).

## 16. Amendment records (post-freeze)

### 16.1 Scope and convention

Post-freeze changes to the frozen protocol text are recorded in this
section as numbered amendment records, preserving the original text of
every amended section (guardrail 7, §15.2; ED01-D §16.2 precedent). Each
record states its evidence basis and the operative change it makes to the
frozen text. Acceptance is recorded by user review; a record is operative
only when marked ACCEPTED.

### 16.2 Amendment A2 — cross-arm pairing key: decisionId → canonical opportunity key (ACCEPTED and frozen 2026-08-11, user approval)

**Acceptance:** ACCEPTED by user review on 2026-08-11 and frozen with this record. Wording intent kept exactly: decisionId remains useful for the integrity rerun certificate, but is not the cross-arm opportunity key.

**Evidence basis:** `docs/Sprint22_Pairing_Identity_Review.md`
(analysis-only; no code, protocol, analyzer, runner, or artifact modified;
no Strategy Tester run).

**Defect found (post-freeze):** `decisionId` is assigned at Record() time by
the telemetry collector and counts only recorded rows
(`Telemetry/TelemetryCollector.mqh:257-258`). GATE-OUT opportunities are
never recorded, so treatment CSVs renumber `decisionId` 1..nAdmitted while
the frozen CONTROL CSVs hold 1..nTotal over the same chronological bar
sequence. `decisionId` is therefore **not an invariant cross-arm
opportunity identity** when admission gating is active.

**K1 evidence (frozen artifacts, read-only):**
`Tools/TT01/artifacts/TT01_20260811_195509/telemetry_v5_default.csv`
(gate OFF, 500 rows) vs `telemetry_v5_k1.csv` (K1, 273 rows):

- K1 rows whose `decisionId` matches CONTROL at the same `signalTime`:
  **0 of 273** — **273 of 273 would be mispaired** under the frozen §6
  `decisionId` pairing (even row 1: CONTROL id 1 = 2026.01.02 04:00 is
  gated out; K1 id 1 = 2026.01.02 08:00).
- nGatedOut = 227; Mean R(gated-out subset) = +0.145374.
- **Frozen A1 identity independently reproduced:** Δ Mean R =
  −(227/500) × 0.145374 = −0.066, exactly matching the observed paired
  Δ Mean R; every admitted row contributes d = 0 (zero violations).

**Operative change (A2):** the §6 pairing bullet ("Pairing key =
`decisionId`") and the §11 gate 3a/3b pairing references are **superseded**
by the canonical opportunity key already established in the ED01
methodology (ED01-D/E protocol 14; `Tools/ED01/ED01_D_Analyze.py:127-131`):

- **Pairing key = `{signalTime, configFingerprint, symbol, timeframe}`**
  (the full four-tuple; `signalTime` alone is unique within each frozen
  file, but the four-tuple is retained for robustness and ED01-methodology
  continuity).
- `decisionId` remains telemetry metadata (run-local record sequence) and
  stays the §11.3a row-for-row byte-identity certificate for the **ungated**
  integrity rerun, but is **not a valid cross-arm pairing key** when
  admission gating changes the recorded population.
- The frozen Amendment A1 opportunity-level estimand is **unchanged**:
  every eligible CONTROL decision pairs to exactly one treatment outcome
  (ADMITTED → actual rMultiple; GATED-OUT → 0R); the 0R reconstruction
  keys on canonical identity (CONTROL canonical keys absent from the
  treatment CSV).
- **Hard audits, required before any statistic is computed:** (1) canonical-
  key uniqueness within each arm and across the merged run set, per file;
  (2) cross-arm identity audit — every treatment canonical key must exist
  in CONTROL and map to byte-identical rows on all non-gate columns;
  (3) the §6 identity check (every admitted row contributes d = 0). Any
  violation → run set rejected.
- **No new telemetry identity field is required** — existing columns
  suffice.

**Unchanged by A2:** populations (§4), tier set (§5, §15.2.2), effect-size
criterion (§7), bootstrap settings and seed 20260811 (§6), decision ladder
(§8), OOS hierarchy (§12), and the §15.3 execution order. The original
text of §3, §6, §15.1, §15.2, and §15.3 is preserved verbatim.

**Scope of this amendment:** pairing-key definition only. The analyzer
(`ED01_RLHYP01_Analyze.py`) and the run batch are NOT created under this
amendment; no Strategy Tester run; no production code change.

## Appendix A — Population measurement provenance

Measured 2026-08-09 from the frozen CONTROL artifacts (ED01-E Appendix A,
read-only sizing; no new runs, no code modified). GBPJPY_M15 has no frozen
artifact in the ED01 sequence — **deferred from the Sprint 22 run set**
(§15.2.3), so no size expectation is produced for it.
