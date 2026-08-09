# Sprint 20 ED01-D — Amendment Review (ANALYSIS-ONLY, awaiting approval)

Status: **PROPOSAL ONLY — NOT APPROVED. No protocol text has been changed.
No statistics were computed. No commit/push was made.**
Date: 2026-08-09
Protocol: `docs/Sprint20_ED01D_Protocol.md` (FROZEN 2026-08-09)
Trigger: pre-analysis gate (protocol §11) rejected the authorized six-run set
(gates 3b/3c FAIL under the frozen eligibility definition).

This document is the controlled amendment review requested by the user
(option (a)): it proves that the frozen population definition was
semantically inverted relative to the actual engine, preserves the failed
gate as immutable evidence, and proposes the minimum amendment required —
without applying it.

---

## 1. Original frozen definition (unchanged, preserved)

Protocol §3 (verbatim, still in force until an approved amendment):

> - **Eligibility:** the row's recorded signal carries a liquidity sweep
>   (`hasLiquiditySweep == "1"`) — this is the queue-time flag that arms
>   the opposing-TP resolution (prerequisite engineering). Measured in
>   the frozen CONTROL artifacts, this set is exactly the closed rows of
>   deciding families FVG, BOS, CHOCH, UNKNOWN: **LIQUIDITY-family rows
>   never carry the flag** (pre-registered structural fact, exact
>   complement: H1 813 = 1420 − 607; GBPJPY 121 = 217 − 96; M15 4,237 =
>   5,931 − 1,694).

Frozen population table (§3):

| File | Closed | Sweep-eligible closed | Days | FVG | BOS | UNKNOWN | CHOCH |
|---|---|---|---|---|---|---|---|
| EURUSD_H1 | 1,420 | **813** | 63 | 318 | 378 | 117 | 0 |
| GBPJPY_H1 | 217 | **121** | 30 | 39 | 59 | 23 | 0 |
| EURUSD_M15 | 5,931 | **4,237** | 65 | 2,092 | 2,095 | 49 | 1 |

> **LIQUIDITY-family rows (607 / 96 / 1,694 closed) are structurally
> ineligible** — their signals carry no sweep, so the opposing arm falls
> back byte-identically. They are the at-scale fallback proof set
> (section 11 gate 3b), never part of the treatment population.

This definition is **incorrect**: it reads `hasLiquiditySweep == "1"` as
"carries a liquidity sweep", but the engine encodes the flag in
EV-tri-state where `1` = EV_FALSE and `2` = EV_TRUE. The rows that carry
the sweep flag (EV_TRUE) are exactly the LIQUIDITY-family rows, which the
frozen protocol declared "structurally ineligible" — and the rows it
declared "eligible" (flag == "1") are exactly the rows that do NOT carry
the flag.

## 2. Verified engine semantics (code, unchanged at HEAD 7b7bd72)

`Telemetry/TelemetryTypes.mqh` lines 71-73 and 488-490:

```mql5
enum EVIDENCE_STATE { EV_UNKNOWN = 0, EV_FALSE, EV_TRUE };   // 1 = EV_FALSE, 2 = EV_TRUE
int TelemetryEvidenceState(const bool evaluated)
{ return evaluated ? (int)EV_TRUE : (int)EV_FALSE; }          // true -> 2
```

## 3. Verified signal construction (code)

`Confluence/ConfluenceEngine.mqh` line 352 (unchanged since Sprint 13.2,
commit 83c078a):

```mql5
sig.hasLiquiditySweep = (bestRule.type == RULE_LIQUIDITY_BOS_BULLISH ||
                         bestRule.type == RULE_LIQUIDITY_BOS_BEARISH);
```

`TelemetryRowBuilder.mqh` line 198 serializes it:

```mql5
out.hasLiquiditySweep = TelemetryEvidenceState(signal.hasLiquiditySweep);
```

Therefore: the telemetry flag is **EV_TRUE ("2") exactly for
LIQUIDITY-family rules** (LIQUIDITY_BOS_BULLISH / LIQUIDITY_BOS_BEARISH)
and EV_FALSE ("1") for every other family.

## 4. Verified settlement wiring (code)

`Portfolio/SymbolContext.mqh` lines 922-925 (queue time):

```mql5
QueueForSettlement(row, newDecision.candidateId,
                   hasSig && sig.hasLiquiditySweep,      // arms the opposing TP
                   hasSig ? sig.liquidityLevelId : -1);
```

`Portfolio/SymbolContext.mqh` lines 1286-1290 (settle time):

```mql5
if(m_outcomeTpMode == OUTCOME_TP_OPPOSING_LIQUIDITY)
{
    m_opposingOutcomePolicy.SetSourceLiquidity(hasLiquidity, liquidityId);
    m_outcomeSim.SetPolicy(&m_opposingOutcomePolicy);
}
```

`Telemetry/OutcomePolicies.mqh` lines 236-251:

```mql5
if(m_liqDetector != NULL && m_hasLiquidity && m_liquidityId >= 0)
{ ... ResolveTakeProfit(cand, TARGET_OPPOSING_LIQUIDITY, ...) ... }
```

## 5. Verified TargetResolver requirement (code)

`Entry/TargetResolver.mqh` line 32:

```mql5
if(policy == TARGET_OPPOSING_LIQUIDITY && candidate.hasLiquidity &&
   candidate.liquidityId >= 0 && liqDetector != NULL)
```

`ConfluenceEngine.mqh` line 367 sets `liquidityLevelId` only when
`sig.hasLiquiditySweep` (i.e., only LIQUIDITY-family signals carry a
liquidity level id).

**Chain:** opposing TP fires ⇔ `hasLiquidity && liquidityId >= 0` ⇔
`sig.hasLiquiditySweep == true` ⇔ best rule is LIQUIDITY-family ⇔
telemetry `hasLiquiditySweep == "2"` (EV_TRUE).

## 6. Therefore the ACTUAL ED01-D treatment population is

**`hasLiquiditySweep == EV_TRUE ("2")` — the sweep-bearing LIQUIDITY-family
closed rows.** The opposing-liquidity TP arm can fire only there, by
construction. The frozen `== "1"` rows (FVG/BOS/UNKNOWN/CHOCH) cannot
ever be treated; they are the byte-identical fallback proof set.

## 7. Original failed gates — PRESERVED AS EVIDENCE (no re-run, no rewrite)

From the authorized six-run batch (2026-08-09 15:52-16:06) and the
pre-analysis gate (protocol §11) run at HEAD 7b7bd72 on
`Tools/ED01/ED01_D_Analyze.py --mode gate`:

| Gate | Result (frozen definition) |
|---|---|
| Gate 1 fingerprints (all 6 runs) | PASS |
| Gate 2 row counts (both arms) | PASS (1558/1560/6239; 0 faults) |
| Gate 3a integrity row-for-row (decisionId + all columns) | PASS — pairing key certified: **decisionId** |
| Gate 3b LIQUIDITY fallback byte-identical | **FAIL** (373/607, 49/96, 929/1694 diverged) |
| Gate 3c at-scale distinguishability (eligible rows) | **FAIL** (0/813, 0/121, 0/4237 treated) |
| Conclusion | **RUN-SET REJECTED — NO verdict, NO statistics emitted** |

Evidence artifacts (preserved, unmodified): the six artifact directories
(`Tools/ED01/artifacts/<FILE>/CONTROL_ED01D_{INTEGRITY,OPPOSING}/` with
`.done` markers), the two-arm manifest
(`Tools/ED01/ED01_D_manifest.json`), `Tools/ED01/run_ED01D.log`, and the
gate's console output above.

The rejection was **correct** under the frozen definition: a zero-treatment
finding at scale (gate 3c) must reject the run set. The failure exposed a
**protocol semantic error** (population definition), not a simulator
defect — the run set behaved exactly per engine semantics.

## 8. Empirical confirmation from the existing six runs (measured 2026-08-09)

| File | LIQ rows changed (opposing vs CONTROL) | Original "eligible" (flag=="1") treated |
|---|---|---|
| EURUSD_H1 | 373 / 607 (all with non-identical rMultiple) | 0 / 813 |
| GBPJPY_H1 | 49 / 96 (all with non-identical rMultiple) | 0 / 121 |
| EURUSD_M15 | 929 / 1,694 (all with non-identical rMultiple) | 0 / 4,237 |

All diverged rows differ in outcome columns only (rMultiple, barsHeld,
exitPrice, exitReason); decision-identity columns are identical
(paired by canonical key, and decisionId invariant per gate 3a). The
changed rows are exactly the sweep-bearing LIQUIDITY-family rows — the
arm fired where the engine says it can, and nowhere else.

## 9. Proposed minimum amendment (NOT yet applied)

**Scope:** correct the population definition from `hasLiquiditySweep == "1"`
to `hasLiquiditySweep == EV_TRUE ("2")` and re-express all dependent
population/count language. No change to thresholds, estimator, decision
ladder, gates' structure, hierarchy, or any engineering rule.

### 9.1 Exact sections affected, old wording → proposed new wording

#### §3 Population (table + structural facts)

Old: eligibility `hasLiquiditySweep == "1"`; eligible = FVG/BOS/UNKNOWN/
CHOCH closed; table rows 813/121/4,237; days 63/30/65; "LIQUIDITY-family
rows never carry the flag"; "LIQUIDITY rows are structurally ineligible".

New: eligibility `hasLiquiditySweep == EV_TRUE ("2")`; eligible =
LIQUIDITY-family closed rows; corrected table:

| File | Closed | Sweep-bearing closed (eligible) | Days | FVG | BOS | UNKNOWN | CHOCH |
|---|---|---|---|---|---|---|---|
| EURUSD_H1 | 1,420 | **607** | 55 | 318 | 378 | 117 | 0 |
| GBPJPY_H1 | 217 | **96** | 23 | 39 | 59 | 23 | 0 |
| EURUSD_M15 | 5,931 | **1,694** | 65 | 2,092 | 2,095 | 49 | 1 |

New structural fact: LIQUIDITY-family rows carry the sweep flag
(EV_TRUE/"2") exactly; the non-LIQUIDITY closed rows (813/121/4,237) carry
EV_FALSE ("1") and are the byte-identical fallback proof set — the exact
complement holds in the corrected direction: eligible 607 = 1,420 − 813;
96 = 217 − 121; 1,694 = 5,931 − 4,237. This is the pre-registered
structural fact restated in the engine-verified direction.

#### §5 Primary metric
Old: "on the sweep-eligible closed rows". New: "on the sweep-bearing
(hasLiquiditySweep == EV_TRUE) closed rows". Pairing language unchanged
(decisionId certified invariant by gate 3a; canonical key fallback
retained as the safety net).

#### §6 Secondary metrics
Old: "Per arm, per file, on the eligible stratum" + "Family strata (FVG,
BOS; UNKNOWN evidence-only)". New: same metrics on the sweep-bearing
stratum; family strata re-expressed: LIQUIDITY is the treatment family;
FVG/BOS/UNKNOWN/CHOCH are the fallback proof set (byte-identical,
reported as such, never treatment strata).

#### §7 Effect-size criterion
Old SE scale: 0.050 / 0.022 / 0.129 (n 813 / 4,237 / 121).
New (same method, σ(rMultiple) ≈ 1.42, SE(Δ) = σ/√n): **0.058 / 0.035 /
0.145** (n 607 / 1,694 / 96). Threshold |Δ| ≥ 0.10, CI excludes 0,
n ≥ 50, 2/2 stability, estimator agreement — all unchanged; all three
files still satisfy n ≥ 50 (607 / 1,694 / 96).

#### §8 Decision rules
Unchanged (EVIDENCE / REJECT / DEFER / run-set rejection). Run-set
rejection retains the identical meaning under the corrected population.
No renumbering.

#### §9 Composition controls
Gate 3 (eligibility integrity) re-expressed: eligible == closed −
non-sweep-bearing closed exactly, verified on both arms. Gates 1-2
(UNKNOWN-exclusion, single-subfamily concentration) apply to the pooled
treatment view; the treatment population is a single family (LIQUIDITY),
so those gates are structurally satisfied — recorded, not skipped.

#### §10 Power / feasibility
Recomputed with corrected n (607 / 1,694 / 96) and the same σ ≈ 1.42:
SE(Δ) ≈ 0.058 / 0.035 / 0.145. EURUSD_H1 remains resolvable for |Δ| =
0.10 (power ≈ 0.8 at the old SE; slightly reduced at 0.058, still
adequate — declared, not gated); EURUSD_M15 highly powered; GBPJPY_H1
evidence-only (n-constrained).

#### §11 Engineering gates
Gate 3b re-expressed: in the opposing-arm runs, the **non-sweep-bearing
rows (flag == EV_FALSE/"1") are byte-identical** to the frozen CONTROL
rows — the fallback holds at scale. Gate 3c: at least one sweep-bearing
eligible row differs from CONTROL and the differing rows have strictly
non-identical rMultiple. Gate 5: per-family eligible counts reproduce
§3 (LIQUIDITY counts). Gates 1, 2, 3a, 4 unchanged.

#### §12 OOS files and hierarchy
Old eligible: 813 / 4,237 / 121 → New: **607 / 1,694 / 96**. Hierarchy
rules unchanged (H1 primary; M15 stability partner; 2/2 direction
required; GBPJPY evidence-only).

#### §14 Run production / two-arm manifest
Unchanged — the six runs and profiles are correct as executed (verified:
`OutcomeTpMode=0` integrity, `OutcomeTpMode=1` opposing; frozen CONTROL
profile). Pairing-key language unchanged; key actually used = decisionId
(certified by gate 3a; uniqueness across merged segments verified: no
duplicates, contiguous 1..N per file).

#### §16.1 Freeze record item 1 (population approved)
Old: "sweep-eligible rows are exactly the non-LIQUIDITY family … LIQUIDITY
rows (no sweep flag) are the at-scale byte-identical fallback proof set".
New: sweep-bearing rows (hasLiquiditySweep == EV_TRUE) are exactly the
LIQUIDITY-family closed rows; non-LIQUIDITY closed rows carry EV_FALSE
and are the at-scale byte-identical fallback proof set.

### 9.2 Dependent analyzer/runner constants (apply with the amendment)

`Tools/ED01/ED01_D_Analyze.py`:
- `eligible_rows()`: filter `hasLiquiditySweep == "1"` → `"2"`.
- `AUDIT_ELIGIBLE`: {813, 121, 4,237} → {607, 96, 1,694}.
- `AUDIT_ELIGIBLE_FAM`: LIQUIDITY-only eligible families (607 / 96 /
  1,694); FVG/BOS/UNKNOWN/CHOCH move to the fallback proof set.
- `AUDIT_DAYS`: {63, 30, 65} → {55, 23, 65}.
- Self-check JSON regenerated (deterministic, seed 20260811) after the
  amendment — the earlier `results_ED01D_selfcheck.json` is preserved as
  pre-amendment evidence.
- The `== "1"` audit-message strings (LIQUIDITY-flagged / non-LIQUIDITY
  unflagged checks) are inverted accordingly.

No change to the runner (`ED01_D_RunBatch.ps1`), the manifest format, or
the six artifacts.

### 9.3 Corrected gate evaluation on the EXISTING artifacts (measured, no re-run)

Re-audited 2026-08-09 against the same six artifacts with the corrected
population (audit only; no statistics computed):

| File | 3b-revised (non-LIQUIDITY byte-identical) | 3c-revised (LIQUIDITY treated) | min n ≥ 50 | paired days ≥ 10 | SE(Δ) |
|---|---|---|---|---|---|
| EURUSD_H1 | PASS (0/813 diverged) | PASS (373/607, 373 rMultiple-differing) | PASS (607) | PASS (55) | 0.058 |
| GBPJPY_H1 | PASS (0/121 diverged) | PASS (49/96, 49 rMultiple-differing) | PASS (96) | PASS (23) | 0.145 |
| EURUSD_M15 | PASS (0/4,237 diverged) | PASS (929/1,694, 929 rMultiple-differing) | PASS (1,694) | PASS (65) | 0.035 |

Gate 3a (integrity row-for-row incl. decisionId) already PASSED — the
decisionId pairing key is certified under either population definition.

### 9.4 Why the existing six artifacts become valid under the amendment

- The runs were produced exactly per protocol §14 (frozen CONTROL profile;
  `OutcomeTpMode=0` integrity / `OutcomeTpMode=1` opposing); ini files
  verified on disk.
- The integrity reruns reproduce the frozen CONTROL artifacts
  row-for-row (gate 3a PASS) — decision identity, row counts, and all 75
  columns are deterministic and correct.
- The opposing arm diverged exactly on the sweep-bearing population
  (373/607, 49/96, 929/1,694 — the corrected eligible set), with strictly
  non-identical rMultiple: the at-scale distinguishability requirement
  (prerequisite §5, gate 3c) holds under the corrected population.
- The non-sweep-bearing rows are byte-identical across arms
  (0 diverged): the at-scale fallback requirement (gate 3b) holds.
- All other gates (fingerprints, row counts, per-family counts, days,
  min-n, pairing) pass under the corrected definition.

No additional run is needed; the six runs become the valid two-arm
experiment once the amendment is approved and the analyzer constants are
updated.

### 9.5 Other frozen decision-rule changes

**None.** Thresholds (|Δ| ≥ 0.10, CI excludes 0, n ≥ 50), estimator
(paired day-stratified bootstrap, 10,000 iters, seed 20260811, auxiliary
daily-mean estimator), decision ladder (EVIDENCE/REJECT/DEFER/run-set
rejection), hierarchy (H1 primary, M15 stability partner, GBPJPY
evidence-only, 2/2 direction), composition discipline, and the
no-production-change-under-any-verdict boundary are unchanged. Only
population-definition language and its dependent constants change.

## 10. Amendment record design (how it will be applied, after approval)

Per user instruction: **the historical frozen protocol text is NOT
altered.** The amendment is applied as an explicit amendment record:
- Append **§16.2 (Amendment record — population correction, 2026-08-09,
  user-approved)** to `docs/Sprint20_ED01D_Protocol.md`, preserving
  verbatim the original §3 definition and this document's evidence, and
  declaring the corrected operative definition with the exact old→new
  mapping above.
- Update the analyzer constants (9.2) and regenerate the deterministic
  self-check.
- Re-run the pre-analysis gate (protocol §11) on the existing six
  artifacts under the amended definition.
- Only if the corrected gates PASS: proceed to the paired analysis
  (protocol §5) and the frozen decision ladder.

## 11. Constraints honored in this review

- No protocol text modified. No analyzer/runner code modified during this
  review.
- No statistics computed (no Mean R, no Δ, no CI, no verdict).
- No experiment re-run; no new terminal runs.
- No commit, no push. Git status: only the four new ED01-D files
  (analyzer, runner, manifest, self-check JSON) are untracked; the
  six-run artifacts and `.done` markers are on disk, gitignored.

## 12. Approval checklist

The reviewer approves this proposal when:
- [ ] The corrected population (`hasLiquiditySweep == EV_TRUE/"2"`,
      LIQUIDITY-family closed rows) is accepted.
- [ ] The corrected table/counts (607/96/1,694; days 55/23/65; SE
      0.058/0.035/0.145) are accepted.
- [ ] The existing six artifacts are accepted as the valid two-arm
      experiment (no re-run).
- [ ] The §16.2 amendment record preserves the original failed gates and
      the original population definition verbatim.
- [ ] No decision rule, threshold, estimator, hierarchy, or boundary
      changes.
- [ ] Authorization to apply the amendment (protocol record + analyzer
      constants + gate re-run) is granted as the next step.
