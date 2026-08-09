# Sprint 20 — ED01-D Protocol: TP Resolution — Opposing-Liquidity vs Fixed-RR Expectancy

Status: **FROZEN** 2026-08-09 (freeze record: section 16; analysis/
documentation only — the 6-run batch and the analyzer are NOT authorized
by this document alone; see deliverables, section 15)
Scope owner: exit-side research, fourth ED measurement milestone (ED01-D),
re-scoped from legacy ED01-C per `docs/Sprint20_ED01C_Protocol.md` §14
Predecessors: ED01-A (KEEP, B8 floors retained), ED01-B (REJECT /
NO DISTINCT LIQUIDITY EDGE), ED01-C (DEFER / confidence levels unresolved),
ED01-D prerequisite engineering (DONE, commit 8954332 — outcome simulator
now selects the TP arm per run)
Related: `docs/Sprint20_ED01D_PreRequisite.md` (frozen; gate PASSED),
DD04 row (`docs/Sprint20_Engineering_Plan.md`), `Tools/TT01/TT01_Validate.ps1`

## 1. Purpose and scope

ED01-D asks the one exit-side question the sequence left unmeasured:

> **For decisions whose signal carries liquidity context (a sweep), does
> resolving the take-profit to the DD04 opposing-liquidity pool carry a
> materially different conditional expectancy than the legacy fixed-RR
> target?**

- The replay outcome simulator previously produced fixed-RR outcomes only;
  the DD04 `TARGET_OPPOSING_LIQUIDITY` path was unreachable in replay
  (frozen prerequisite, section 2). The prerequisite engineering (commit
  8954332) added the selectable `OUTCOME_TP_OPPOSING_LIQUIDITY` arm with a
  byte-identical fallback, and the frozen two-part gate PASSED (unit
  fixture distinguishes the arms; TT01 BEHAVIOR-REGRESSION byte-identical
  under the default mode). ED01-D is the first analysis that can actually
  observe the variable being tested.
- **This is the first ED01 experiment that requires NEW terminal runs.**
  The opposing arm never existed when the CONTROL artifacts were collected.
  The fixed arm is the frozen CONTROL population; the opposing arm is a
  paired rerun of the identical profile with `OutcomeTpMode=1`. Pairing is
  by decision identity (decisionId / signalTime / configFingerprint /
  symbol / timeframe — the TT01 decision-identity invariant). This is
  sound because the decision pipeline is deterministic and the default
  mode is byte-identical to the frozen artifacts (verified below in
  section 11 as a hard gate, and already proven at engine level by TT01
  run TT01_20260809_131658).
- **In scope:** opposing-liquidity vs fixed-RR TP expectancy on the frozen
  B8 population; statistical evidence; verdict.
- **Out of scope:** floor tuning (all floors stay B8), detector logic,
  rendering, execution, telemetry schema, entry-decision logic (closed by
  ED01-A/B/C), any production change under any verdict (the experiment
  measures; it never tunes — frozen prerequisite §3).
- **Data:** frozen ED01-A CONTROL artifacts (arm 2) + new opposing-arm
  runs (arm 1) + integrity reruns (audit only) — exact run spec in
  section 14.

## 2. Guardrails (non-negotiable)

1. **B8 remains canonical.** No floor, weight, validator, detector, or
   production change of any kind. No baseline re-freeze: the new runs are
   research-mode telemetry (like the ED01-A grid runs); TT01 regression
   targets are untouched.
2. **Analysis-only verdict.** The verdict guides the ED01 sequence; any
   engineering change it motivates goes through its own protocol + TDD +
   TT01 + decision.
3. **One hypothesis per experiment.** The primary comparison is fixed:
   opposing-liquidity TP vs fixed-RR TP on the sweep-eligible stratum.
   No fishing across populations, families, or estimators.
4. **Pre-registration.** Population, estimator, effect-size threshold, and
   decision rules are fixed in this document before analysis; results do
   not move the goalposts. Thresholds are re-derived here, not inherited
   (section 7).
5. **Composition discipline (frozen constraint, ED01-B §9 verbatim).**
   The primary pooled view passes the composition gates (section 9);
   family strata are reported with their own CIs.
6. **Paired comparison.** Arms are compared on the same decisions
   (decisionId-paired). No cross-population pooling between arms.

## 3. Population (frozen B8, exact definition)

- **Source (arm 2, fixed-RR):** `Tools/ED01/artifacts/<FILE>/CONTROL/
  telemetry_v4_*.csv` (frozen ED01-A CONTROL runs). Files: `EURUSD_H1`,
  `GBPJPY_H1`, `EURUSD_M15`. Per-file default-config fingerprints
  (ED01-B amendment 13.2): EURUSD_H1 `3005138848403243456`
  (= TT01 B8 baseline), GBPJPY_H1 `14617585492269479818`,
  EURUSD_M15 `13548296177162108249`.
- **Window:** 2026.04.05 → 2026.07.05 (ED01-A amendment 13.1).
- **Row filter (exact):**
  - `newDecision == "1"` only (NEW-mode qualified decisions).
  - **Eligibility:** the row's recorded signal carries a liquidity sweep
    (`hasLiquiditySweep == "1"`) — this is the queue-time flag that arms
    the opposing-TP resolution (prerequisite engineering). Measured in
    the frozen CONTROL artifacts, this set is exactly the closed rows of
    deciding families FVG, BOS, CHOCH, UNKNOWN: **LIQUIDITY-family rows
    never carry the flag** (pre-registered structural fact, exact
    complement: H1 813 = 1420 − 607; GBPJPY 121 = 217 − 96; M15 4,237 =
    5,931 − 1,694).
  - Family via the frozen GR01 `RULE_FAMILY` map (`family_of`).
  - Realized metrics on settled `rMultiple` with `outcome in ("1","2","3")`;
    censored (`outcome == "0"`) excluded and reported as `nOpen`.
- **Measured size expectations (frozen constants for the audit, measured
  from the frozen CONTROL artifacts on 2026-08-09):**

| File | Closed | Sweep-eligible closed | Days | FVG | BOS | UNKNOWN | CHOCH |
|---|---|---|---|---|---|---|---|
| EURUSD_H1 | 1,420 | **813** | 63 | 318 | 378 | 117 | 0 |
| GBPJPY_H1 | 217 | **121** | 30 | 39 | 59 | 23 | 0 |
| EURUSD_M15 | 5,931 | **4,237** | 65 | 2,092 | 2,095 | 49 | 1 |

- **LIQUIDITY-family rows (607 / 96 / 1,694 closed) are structurally
  ineligible** — their signals carry no sweep, so the opposing arm falls
  back byte-identically. They are the at-scale fallback proof set
  (section 11 gate 3b), never part of the treatment population.

## 4. Hypothesis (pre-registered)

- **H1 (research):** on the sweep-eligible stratum, opposing-liquidity TP
  resolution carries materially different conditional expectancy than
  fixed-RR: |Δ Mean R| ≥ 0.10 (section 7), where
  Δ Mean R = Mean R(OPPOSING) − Mean R(FIXED).
- **H0 (null):** |Δ Mean R| < 0.10 — the TP resolution is an exit
  mechanic with no distinct expectancy on this population.
- The hypothesis is **two-sided**: direction is reported and determines
  the engineering implication (which TP resolution to prefer), not the
  verdict. This is pre-registered because there is **no prior evidence**
  for either direction: the opposing arm has never been measured (the
  DD04 doctrinal claim is untested, and fixed-RR is an arbitrary 2R
  constant, not an optimum).

## 5. Primary metric and estimator

- **Primary metric:** Δ Mean R = Mean R(OPPOSING) − Mean R(FIXED) on the
  sweep-eligible closed rows, per file. The arms are paired by the
  cross-run decision identity key (section 14 — decisionId only if the
  integrity audit proves it invariant, otherwise the canonical stable
  key), so this equals the mean of per-row paired differences
  d_r = rMultiple_opposing − rMultiple_fixed.
- **Bootstrap 95% CI on Δ (pre-registered):** paired day-stratified
  bootstrap, 10,000 resamples, fixed seed **20260811** (new seed for
  ED01-D), same estimator family as ED01-A/B/C:
  - Resample days with replacement from the union of days holding any
    eligible row; each sampled day contributes its paired OPPOSING and
    FIXED rows; the pooled mean-R difference over the sampled rows is one
    draw.
  - CI = 2.5/97.5 percentiles.
  - **Auxiliary estimator (reported, not gating):** mean of per-day mean-R
    differences over sampled days. Sign disagreement with a CI excluding 0
    in one estimator and not the other → DEFER (estimator conflict,
    section 8).
  - Require ≥ 10 paired days with eligible rows in BOTH arms, else DEFER
    (measured: 63 / 30 / 65 days — satisfied, held as a gate).

## 6. Secondary metrics (reported, not decision-gating)

Per arm, per file, on the eligible stratum:

- Sample sizes (qualified, eligible closed, nOpen)
- Win rate (WIN / (WIN + LOSS), BE excluded — GR02 convention)
- Mean R, median R, R quantiles (25/75), R distribution
- Outcome distribution (WIN/LOSS/BREAKEVEN/censored)
- **Treatment rate (informational, with declared lower bound):** share of
  eligible rows whose `rMultiple` differs between arms. Rows where the
  opposing TP moved but the realized outcome is unchanged (e.g., both
  arms LOSS at −1R, or both WIN with different R) are structurally
  invisible in the CSV — the true override rate is higher than the
  measured one. Declared limitation; the mean-R metric is unaffected
  (it measures the actual expectancy difference).
- **Outcome transition matrix** (fixed→opposing WIN/LOSS/BE transitions).
- **Family strata** (FVG, BOS; UNKNOWN evidence-only): identical
  statistics with per-family CIs — decision-support for the direction
  2/2 rule (section 8), never standalone verdicts.
- **GBPJPY_H1:** identical statistics, evidence-only (121 eligible rows;
  hierarchy section 12).

## 7. Effect-size criterion (pre-registered, re-derived — not inherited)

| Threshold | Value | Rationale |
|---|---|---|
| Minimum meaningful \|Δ Mean R\| | **0.10** | 0.10 R is a pre-registered practical-effect threshold informed by the observed standard-error scale (SE(Δ) ≈ 0.050 on EURUSD_H1, ≈ 0.022 on EURUSD_M15, ≈ 0.129 on GBPJPY_H1 — computed from the measured eligible sizes, section 10) and the economic interpretation of 0.10 R as 10% of one unit of risk. Independently specified for ED01-D, not inherited from ED01-A/B/C. |
| CI requirement | 95% bootstrap CI excludes 0 | Same discipline as ED01-A/B/C. |
| Stability | Direction agrees in **2/2 resolvable populations (EURUSD_H1 + EURUSD_M15)** | Same hierarchy adaptation as ED01-C §12 (registered pre-analysis). |
| Minimum n | ≥ 50 eligible closed rows per population | Same noise floor as ED01-A §7 (measured: 813 / 4,237 — satisfied, held as a gate). |
| Estimator agreement | Pooled and daily-mean estimators must not conflict | Guards against count-asymmetry artifacts (ED01-A §7 discipline). |

## 8. Pre-registered decision rules

- **EVIDENCE FOR DISTINCT TP EXPECTANCY:** on the primary file
  (EURUSD_H1): |Δ| ≥ 0.10 AND 95% CI excludes 0 AND n ≥ 50 AND
  estimators agree AND direction agrees with EURUSD_M15 (2/2) AND the
  composition gates (section 9) pass AND the run-integrity gates
  (section 11) passed. Direction is recorded (OPPOSING-better or
  FIXED-better). Verdict consequence: TP resolution is a real lever — a
  follow-up experiment (e.g., policy-selectable exit research or a
  candidate design with the opposing arm) may be designed; still **no
  production change from ED01-D itself**.
- **REJECT / NO DISTINCT TP EXPECTANCY:** |Δ| < 0.10 on EURUSD_H1, OR CI
  includes 0. When EURUSD_H1 is null, EURUSD_M15 direction is moot (the
  null already decides). Direction disagreement between the resolvable
  populations when EURUSD_H1 IS meaningful is instability → DEFER
  (same resolution as ED01-C amendment 16.1 item 4). Verdict
  consequence: under the current evidence universe and model
  formulation, DD04 TP targeting shows no distinct expectancy; the
  hypothesis is **closed** (section 13) — no engineering change.
- **DEFER:** n < 50 on EURUSD_H1, OR < 10 paired days, OR pooled/daily-mean
  estimator conflict, OR a meaningful EURUSD_H1 result (|Δ| ≥ 0.10, CI
  excluding 0) with opposite sign on EURUSD_M15 (instability). Verdict
  consequence: hypothesis stays open; the 6-month archive is the
  designated follow-up (section 13).
- **Run-set rejection (no verdict):** any integrity-gate failure
  (section 11) or a zero-treatment finding at scale (gate 3c) → the run
  set is invalid; no verdict is emitted; the analysis is re-run after
  audit. This is a gate, not a result — the prerequisite's "can
  distinguish" requirement must hold at scale, not only in the unit
  fixture.
- **No production change occurs under ANY verdict.**

## 9. Composition controls (frozen constraint compliance)

The primary comparison pools families **within the eligibility stratum**
(sweep-eligible rows). The ED01-B gates apply verbatim:

1. **UNKNOWN-exclusion:** the pooled view is recomputed with UNKNOWN rows
   removed; if the verdict changes sign or falls below 0.10 → that view is
   reported as UNKNOWN-driven, never gating.
2. **Single-subfamily concentration:** removing any one family (FVG, BOS)
   must not flip the pooled view's sign or drop |Δ| below 0.10, else the
   view is reported as composition-confined (the ED01-B lesson: pooled
   gaps can be carried by one sub-family).
3. **Eligibility integrity check (audit):** the eligible set equals
   closed − LIQUIDITY-family closed exactly (section 3 table), verified
   on both arms.

## 10. Power / feasibility (pre-registered, measured constants)

With σ(rMultiple) ≈ 1.42 (fixed-RR, ED01-C §10):

- EURUSD_H1 eligible n = 813 → SE(Δ) ≈ **0.050** — H1 can resolve a
  0.10 effect (power ≈ 0.8 under |Δ| = 0.10).
- EURUSD_M15 eligible n = 4,237 → SE(Δ) ≈ **0.022** — M15 is highly
  powered.
- GBPJPY_H1 eligible n = 121 → SE(Δ) ≈ **0.129** — evidence-only.
- Consequence, pre-declared: EVIDENCE requires H1 and M15 to agree;
  a null (REJECT) can be reached from EURUSD_H1 alone when the CI
  includes 0.

## 11. Engineering gates (analysis milestones)

1. **Compile/fingerprint (hard):** the 6 new runs compile from HEAD
   (post-8954332); every new CSV reproduces the frozen per-file
   configFingerprint (section 3) — the TP mode is NOT part of the
   fingerprint, so both arms must carry the identical per-file
   fingerprint (this is what makes decisionId pairing valid).
2. **Row-count integrity (hard):** each new run's total/qualified/closed
   row counts reproduce the frozen audit constants (EURUSD_H1 1,558 /
   1,468 / 1,420; GBPJPY_H1 1,560 / 236 / 217; EURUSD_M15 6,239 / 5,981 /
   5,931) on both arms.
3. **At-scale distinguishability + fallback (hard, the prerequisite §5
   real-run gate):**
   a. **Integrity reruns** (default mode, new code, same profile): each
      file's rerun is **row-for-row byte-identical** to the frozen
      CONTROL artifacts (decisionId + all 75 columns). This proves both
      the code-equivalence of the artifacts and the determinism of the
      run set. ANY divergence → run set rejected (section 8).
      **Pairing-key proof (freeze clarification §16.1 item 4):** this
      gate ALSO proves whether `decisionId` is invariant across arms:
      if the integrity reruns reproduce CONTROL `decisionId`s
      row-for-row, `decisionId` is certified as the pairing key; if not,
      pairing falls back to the canonical stable identity key
      `{signalTime, configFingerprint, symbol, timeframe}` (uniqueness
      within each run verified by audit — no duplicate rows per key).
      The key actually used is recorded in the analyzer output and the
      two-arm manifest before any statistic is computed.
   b. **Ineligible fallback at scale:** in the opposing-arm runs, the
      LIQUIDITY-family rows (no sweep flag) are byte-identical to the
      frozen CONTROL rows — the fallback holds on the real population,
      not only in the unit fixture.
   c. **Distinguishability at scale:** in the opposing-arm runs, at
      least one eligible row differs from CONTROL, AND the eligible rows
      that differ have strictly non-identical rMultiple. Zero treated
      rows → run set rejected (the opposing arm never resolved a pool —
      indistinguishable at scale).
4. **Determinism (hard):** analyzer seed fixed (20260811); rerun
   reproduces identical CIs and JSON.
5. **Audit:** per-family eligible counts reproduce section 3 exactly.

## 12. OOS files and H1/M15 hierarchy (registered, pre-analysis)

- **EURUSD_H1 — primary decision file** (eligible 813, resolvable).
- **EURUSD_M15 — stability partner** (eligible 4,237, resolvable).
  Hierarchy adaptation registered here, before analysis (same as
  ED01-C §12): ED01-A/B used 2/2 H1 because two resolvable H1 files
  existed; ED01-D has one (GBPJPY_H1 eligible = 121 — n-constrained,
  evidence-only per the established hierarchy). Registered rules:
  1. **H1 remains the primary decision dataset.**
  2. **M15 becomes a stability partner.**
  3. **M15 cannot independently establish a positive exit edge.**
  4. **Direction must agree across both resolvable populations (2/2)
     for an affirmative result.**
- **GBPJPY_H1 — evidence-only** (n-constrained).
- M15 and GBPJPY_H1 cannot rescue a failed EURUSD_H1 verdict; the 2/2
  gate is the sole stability requirement.

## 13. What closes the hypothesis, what reopens it

- **Permanently closed under the current evidence universe and model
  formulation:** REJECT where BOTH resolvable populations show |Δ| < 0.10
  with CIs including 0 and no estimator supports an effect. The opposing-
  liquidity TP resolution is then an exit mechanic with no distinct
  expectancy on this population. Reopening requires genuinely new
  evidence — the reserved six-month archive
  (`Tools/ED01/artifacts_6mo_2026-01-05_07-05/`, 46 runs) or a future
  data/model change — not another re-analysis of the same population.
- **Engineering change is justified only by EVIDENCE FOR**, and even then
  the change proceeds as a separate protocol with TDD + TT01 + explicit
  decision — ED01-D itself changes nothing.

## 14. Run production and two-arm manifest (prerequisite §4 requirement)

- **How the two arms are produced (frozen choice):** paired simulation
  runs over the same decisions — one run per arm per file. Arm 2 (fixed)
  = the frozen CONTROL artifacts (already collected, no rerun needed for
  analysis; integrity reruns below are audit-only). Arm 1 (opposing) =
  new runs with `OutcomeTpMode=1` (EA input `ENUM_OUTCOME_TP_MODE`,
  commit 8954332).
- **Profile (frozen, identical to CONTROL):** `Tools/ED01/ini/
  <FILE>_CONTROL.ini` — Expert SuperCents_X.ex5, Symbol/Period per file
  (EURUSD/H1, GBPJPY/H1, EURUSD/M15), FromDate 2026.04.05, ToDate
  2026.07.05, Model=4, Deposit 10000 GBP, Leverage 200, ExecutionMode
  1000, EntryMode=2 (ENTRY_MODE_NEW), B8 weights 25/20/15/15/15/10.
- **Run set (6 new runs):**
  | Run | Config | Mode |
  |---|---|---|
  | EURUSD_H1 integrity | CONTROL profile, default mode | FIXED_RR (audit) |
  | GBPJPY_H1 integrity | CONTROL profile, default mode | FIXED_RR (audit) |
  | EURUSD_M15 integrity | CONTROL profile, default mode | FIXED_RR (audit) |
  | EURUSD_H1 opposing | CONTROL profile + `OutcomeTpMode=1` | OPPOSING |
  | GBPJPY_H1 opposing | CONTROL profile + `OutcomeTpMode=1` | OPPOSING |
  | EURUSD_M15 opposing | CONTROL profile + `OutcomeTpMode=1` | OPPOSING |
- **Artifacts:** `Tools/ED01/artifacts/<FILE>/CONTROL_ED01D_OPPOSING/` and
  `Tools/ED01/artifacts/<FILE>/CONTROL_ED01D_INTEGRITY/` (`.done` markers
  like the ED01-A runner). The runner (extend `ED01_RunBatch.ps1` or a
  dedicated `ED01_D_RunBatch.ps1`) records per-run: mode, file, start/
  end, rows, faults — the **two-arm manifest** (prerequisite §4).
- **Pairing (freeze clarification, §16.1 item 4):** treatment/control
  pairing MUST use a **deterministic cross-run decision identity** that is
  invariant between the FIXED_RR and OPPOSING_LIQUIDITY runs.
  `decisionId` may serve as the pairing key ONLY if the integrity audit
  (section 11, gate 3a) proves it invariant across arms; otherwise the
  **canonical stable decision identity key** must be used:
  `{signalTime, configFingerprint, symbol, timeframe}` (row attributes
  invariant by construction under the TT01 decision-identity invariant),
  with uniqueness within each run verified by audit. The choice of key
  and its proof are recorded in the analyzer output and the two-arm
  manifest before any statistic is computed — a silently invalid pairing
  would corrupt the paired bootstrap.

## 15. Deliverables (execution order — frozen prerequisite §7 item 3)

1. **Protocol freeze** (this document → FROZEN on user approval;
   committed; pushed to origin).
2. **Analyzer + runner** — `Tools/ED01/ED01_D_Analyze.py` + the batch
   runner, written after freeze only; reuses the ED01-C loader/audit/
   bootstrap patterns; outputs `Tools/ED01/results_ED01D.json`.
3. **Analyzer self-check** — audit constants + determinism on the frozen
   CONTROL artifacts (no new runs needed for this step).
4. **Run batch** — the 6 runs (section 14); artifacts + manifest.
5. **Pre-analysis gate** — section 11 gates (a)–(c) verified.
6. **Analysis run** — paired analysis per section 5.
7. **Decision report** — `docs/Sprint20_ED01D_Decision.md`: verdict +
   evidence (primary, secondary, composition checks, treatment rate,
   determinism, gate results).
8. **Plan register** — ED01-D row DONE with evidence.
9. **Commit + push** — dedicated ED01-D commit(s) to origin/main; TT01
   full gate after any production code change (none expected under any
   verdict).

## 16. Amendments

### 16.1 Freeze record (2026-08-09, user approval)

Frozen with the following user-approved decisions and wording safeguards:

1. **Population approved:** the sweep-eligibility structural finding stays
   pre-registered — sweep-eligible rows are exactly the non-LIQUIDITY
   family in the frozen population. LIQUIDITY rows (no sweep flag) are
   the at-scale byte-identical fallback proof set; sweep-eligible rows
   test the actual DD04 opposing-liquidity behavior.
2. **Six-run design approved:** 3 × FIXED_RR integrity reruns (must
   reproduce the frozen CONTROL row-for-row, not merely similar aggregate
   statistics) + 3 × OPPOSING_LIQUIDITY treatment runs. The opposing runs
   must pass the at-scale distinguishability gate (section 11 gate 3c)
   before any statistical result is interpreted. This is the first ED
   experiment requiring new Strategy Tester runs — gate discipline is
   mandatory.
3. **Threshold approved:** |Δ Mean R| ≥ 0.10, two-sided,
   Δ = MeanR(opposing) − MeanR(fixed); independently justified by the
   observed SE scale and the practical 0.10R criterion. A sufficiently
   negative result is also meaningful evidence.
4. **Cross-run pairing identity — REQUIRED CLARIFICATION (approved as
   amended):** pairing MUST use a deterministic cross-run decision
   identity invariant between FIXED_RR and OPPOSING_LIQUIDITY runs.
   `decisionId` may serve as the pairing key ONLY if the integrity audit
   (section 11 gate 3a) proves it invariant; otherwise the canonical
   stable identity key `{signalTime, configFingerprint, symbol,
   timeframe}` must be used, with uniqueness verified by audit. This is
   now explicit in sections 5, 11 and 14 — a silently invalid pairing
   would corrupt the paired bootstrap.
5. **Statistical ladder approved:** integrity failure → RUN-SET REJECTION
   (no trading conclusion); integrity passes → EVIDENCE / REJECT / DEFER.
   H1 primary / M15 stability partner (2/2 direction) / GBPJPY evidence-
   only, consistent with the ED01-C hierarchy discipline.
6. **Treatment-rate limitation approved as a prominent disclosure:** the
   observed treatment rate is a lower bound — a moved TP target with an
   unchanged classified outcome/R multiple is invisible in the CSV.
7. **Composition gates approved:** ED01-B gates verbatim — UNKNOWN
   exclusion and single-subfamily concentration — so pooled/composition
   effects cannot manufacture an opposing-liquidity conclusion.
8. **Boundaries confirmed:** no production change under any verdict;
   B8 untouched; no baseline re-freeze; analyzer and the 6-run batch are
   authorized only after this freeze (section 15 execution order), and
   only as separate subsequent steps — never combined.
9. **Execution order frozen:** protocol freeze (this document) → analyzer
   + runner (`Tools/ED01/ED01_D_Analyze.py`) → analyzer self-check
   (audit + determinism on the frozen CONTROL artifacts) → 6-run batch +
   two-arm manifest → pre-analysis gate (section 11 a–c) → analysis →
   decision doc → plan register → dedicated commit(s) + push to
   origin/main.

### 16.2 Amendment record — population correction (2026-08-09, user approval)

**Supersedes** the population interpretation in section 3 and the wording
of §16.1 item 1 (both preserved verbatim above as historical record).
Approved after an analysis-only review
(`docs/Sprint20_ED01D_Amendment_Review.md`) that preserved the original
failed gate as immutable evidence. No other section is amended; the
effect-size threshold (0.10), estimator, decision rules, hierarchy,
composition discipline and boundaries are unchanged.

**Why the original interpretation was incorrect.** The frozen eligibility
read `hasLiquiditySweep == "1"` as "carries the liquidity sweep". The
engine stores the flag in EV-tri-state — `EV_UNKNOWN = 0`, `EV_FALSE = 1`,
`EV_TRUE = 2` (`Telemetry/TelemetryTypes.mqh:71-73`) — and
`TelemetryEvidenceState(true)` returns `EV_TRUE` (`:490`), so the sweep
flag is recorded as `"2"` (`TelemetryRowBuilder.mqh:198`).
`hasLiquiditySweep` is true exactly for `RULE_LIQUIDITY_BOS_BULLISH/BEARISH`
(`Confluence/ConfluenceEngine.mqh:352`, unchanged since Sprint 13.2
commit 83c078a). The opposing-TP arm can fire only on sweep-bearing rows
(`Portfolio/SymbolContext.mqh:922-925` arms the policy,
`:1286-1290` applies it; `Telemetry/OutcomePolicies.mqh:236-251` requires
`m_liquidityId >= 0`, which only LIQUIDITY rules provide,
`Confluence/ConfluenceEngine.mqh:367`; `Entry/TargetResolver.mqh:32`).
Therefore the frozen `== "1"` definition selected exactly the rows the arm
CANNOT treat (EV_FALSE — non-LIQUIDITY families), and excluded exactly
the rows it treats (EV_TRUE — LIQUIDITY family): the eligibility predicate
was inverted.

**Corrected operative definition (amendments to section 3).**

- Eligibility: `hasLiquiditySweep == EV_TRUE ("2")` — the row's recorded
  signal carries the sweep flag that arms opposing-TP resolution.
  Measured in the frozen CONTROL artifacts, this set is exactly the closed
  rows of the LIQUIDITY family.
- The non-LIQUIDITY closed rows (FVG, BOS, UNKNOWN, CHOCH; flag `"1"`)
  are the byte-identical at-scale fallback proof set (section 11 gate 3b),
  never part of the treatment population.
- Corrected measured constants (same provenance as Appendix A):

| File | Closed | Sweep-bearing closed (eligible) | Days | FVG | BOS | UNKNOWN | CHOCH |
|---|---|---|---|---|---|---|---|
| EURUSD_H1 | 1,420 | **607** | 55 | 318 | 378 | 117 | 0 |
| GBPJPY_H1 | 217 | **96** | 23 | 39 | 59 | 23 | 0 |
| EURUSD_M15 | 5,931 | **1,694** | 65 | 2,092 | 2,095 | 49 | 1 |

Exact complement holds in the corrected direction (eligible = closed −
non-LIQUIDITY closed): 607 = 1,420 − 813; 96 = 217 − 121;
1,694 = 5,931 − 4,237.

**Dependent operative readings (amended population only; all other
wording stands):**

- Section 4 hypothesis stratum: sweep-bearing (eligible) closed rows.
- Section 5: paired-day requirement ≥ 10 satisfied (55 / 23 / 65).
- Section 6: LIQUIDITY is the treatment family; FVG/BOS/UNKNOWN/CHOCH are
  reported as the fallback proof set (byte-identical), never treatment
  strata.
- Section 7 SE inputs: 0.058 (EURUSD_H1), 0.145 (GBPJPY_H1),
  0.035 (EURUSD_M15) — σ(rMultiple) ≈ 1.42, SE(Δ) = σ/√n. Minimum n ≥ 50
  satisfied (607 / 96 / 1,694).
- Section 9: treatment population is a single family (LIQUIDITY);
  UNKNOWN-exclusion and single-subfamily concentration gates are
  structurally satisfied — recorded, not skipped.
- Section 10: power/feasibility uses the corrected n (607 / 96 / 1,694).
- Section 11 gate 3b: non-sweep-bearing rows (flag `"1"`) byte-identical;
  gate 3c: at least one eligible (sweep-bearing) row differs with strictly
  non-identical rMultiple.
- Section 12: eligible sizes 607 (H1 primary) / 1,694 (M15 stability) /
  96 (GBPJPY evidence-only).
- Section 14: pairing key unchanged — `decisionId` certified by gate 3a.
- §16.1 item 1 wording ("non-LIQUIDITY eligible", "LIQUIDITY never carry
  the flag") is superseded by this record.

**Evidence preserved (immutable):** the original pre-analysis gate
(gates 3a PASS, 3b FAIL, 3c FAIL, RUN-SET REJECTED under the frozen
definition — no verdict, no statistics emitted), the six-run artifacts,
`Tools/ED01/ED01_D_manifest.json`, and the frozen section 3 text above.

**Next steps (per approval, §16.2 only):** update analyzer constants to
the corrected population, regenerate the deterministic self-check, re-run
the pre-analysis gates against the existing six artifacts, and report.
No statistics, no verdict, no re-run of the six experiments, no commit/push
until separate approval.

## Appendix A — Population measurement provenance

Measured 2026-08-09 from the frozen CONTROL artifacts with a read-only
sizing script (not part of the analysis): per-file totals, per-family
closed counts, sweep-eligible counts and day coverage as shown in
section 3. The LIQUIDITY-family exact complement (eligible == closed −
LIQUIDITY closed) was verified on all three files.
