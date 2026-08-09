# Sprint 20 — ED01-D Decision: TP Resolution — Opposing-Liquidity vs Fixed-RR Expectancy

Status: **EVIDENCE FOR DISTINCT TP EXPECTANCY — FIXED-RR BETTER** — 2026-08-09
Scope owner: exit/TP research, fourth measurement milestone (ED01-D)
Protocol: `docs/Sprint20_ED01D_Protocol.md` (frozen 2026-08-09; amendment
§16.2 population correction — sweep-bearing `hasLiquiditySweep == EV_TRUE
("2")` LIQUIDITY-family closed rows — approved 2026-08-09)
Review: `docs/Sprint20_ED01D_Amendment_Review.md` (analysis-only proposal,
original failed gate preserved as immutable evidence)

## 1. Verdict summary

**EVIDENCE FOR DISTINCT TP EXPECTANCY — FIXED-RR BETTER.**

On the pre-registered EURUSD_H1 sweep-bearing LIQUIDITY population, the
implemented opposing-liquidity TP resolution has **materially lower
conditional expectancy** than the legacy fixed-2R fallback. The result
**does not support the DD04 hypothesis** that opposing-liquidity targeting
improves expectancy on this population.

| Criterion (protocol §7/§8/§11) | Requirement | Result |
|---|---|---|
| Run-integrity gates 1/2/3a/3b/3c + manifest + fingerprints | PASS | PASS (all six runs, pairing key `decisionId`) |
| Materiality | \|Δ\| ≥ 0.10 on EURUSD_H1 | **0.7210 — PASS** |
| CI requirement | 95% CI excludes 0 on EURUSD_H1 | **[−1.192, −0.262] — PASS** |
| Minimum n | ≥ 50 on EURUSD_H1 | 607 — PASS |
| Paired days | ≥ 10 on EURUSD_H1 | 55 — PASS |
| Estimator agreement | pooled + daily-mean must not conflict | both exclude 0, same sign (daily CI [−1.447, −0.330]) — PASS |
| Stability 2/2 | direction agrees H1 + M15 | H1 −0.721 / M15 −0.202 (both negative) — PASS |
| Composition gates | §9 (amended §16.2) | PASS (single-family LIQUIDITY stratum; structurally satisfied) |

## 2. Population audit (amended §16.2) and gate history

**Amendment history (preserved verbatim in the protocol):** the frozen §3
definition `hasLiquiditySweep == "1"` was semantically inverted relative
to the engine: the telemetry flag is EV-tri-state (`EV_FALSE = "1"`,
`EV_TRUE = "2"`, `TelemetryTypes.mqh:71-73,490`) and the sweep flag that
arms the opposing TP is recorded as `"2"`, exactly on LIQUIDITY-family
rows (`ConfluenceEngine.mqh:352`; `SymbolContext.mqh:922-925,1286-1290`;
`OutcomePolicies.mqh:236-251`; `TargetResolver.mqh:32`). Under the frozen
definition the pre-analysis gate **rejected** the six-run set (gate 3b
FAIL: 373/607, 49/96, 929/1694 LIQUIDITY rows diverged; gate 3c FAIL:
0 eligible treated). That rejection is preserved as historical evidence —
**no verdict was emitted from it**. Protocol amendment §16.2 corrected
the population; the corrected gates then passed on the **same six
artifacts** (no new Strategy Tester runs).

Corrected population (measured from the frozen CONTROL artifacts, both
arms identical): eligible = closed rows with `hasLiquiditySweep == "2"` =
LIQUIDITY-family closed rows exactly.

| File | Closed | Eligible | Days | FVG | BOS | UNKNOWN | CHOCH | LIQUIDITY |
|---|---|---|---|---|---|---|---|---|
| EURUSD_H1 | 1,420 | **607** | 55 | 318 | 378 | 117 | 0 | 607 |
| GBPJPY_H1 | 217 | **96** | 23 | 39 | 59 | 23 | 0 | 96 |
| EURUSD_M15 | 5,931 | **1,694** | 65 | 2,092 | 2,095 | 49 | 1 | 1,694 |

Flag distribution on closed rows: `{"2": 607, "1": 813}` /
`{"2": 96, "1": 121}` / `{"2": 1694, "1": 4237}` — no EV_UNKNOWN rows.

**Corrected gate results (2026-08-09, existing six artifacts, read-only):**

| Gate | Result |
|---|---|
| Gate 1 fingerprints (all 9 runs: 3 arms × 3 files) | PASS |
| Gate 2 row counts (1558 / 1560 / 6239, both arms) | PASS |
| Gate 3a integrity row-for-row (decisionId + 75 columns) | PASS — 0 diverged; **decisionId certified as pairing key** |
| Gate 3b fallback (non-LIQUIDITY rows byte-identical) | PASS — 0/813, 0/4,237, 0/121 diverged |
| Gate 3c distinguishability (eligible treated) | PASS — 373/607, 929/1,694, 49/96 changed, 100% with strictly non-identical rMultiple |
| Gate 4 determinism | PASS — analysis rerun byte-identical (SHA-256 `96F2A9EA70E4AB16888BA2CA80AEA18627A80A4F57C2A644494B9AB094E38BF7`) |
| Gate 5 per-family audit | PASS (eligible == LIQUIDITY closed, both arms) |
| Pairing | decisionId certified; unmatched 0 ctrl / 0 opp per file |
| Manifest | 6/6 DONE, `.done` markers present, faults 0 |

Analyzer self-check (post-amendment): PASS, deterministic (SHA-256
`9FFC7D23E2927BC5422D82D1D2D41161EDDB3536D7EDBF547CB3795D5CD96019`, seed
20260811). Pre-amendment self-check preserved as
`results_ED01D_selfcheck_pre_amendment.json`.

Window: 2026.04.05 → 2026.07.05. Rows: `newDecision=1`, settled
`rMultiple` (outcome 1/2/3); censored (outcome 0) excluded and reported
as nOpen (H1 48/48; M15 50/50; GBPJPY 19/19 — identical between arms).

## 3. EURUSD_H1 primary result (decision population)

| Arm | n (nOpen) | WR (BE-excl.) | Mean R | Median | Q25 | Q75 |
|---|---|---|---|---|---|---|
| FIXED-RR (CONTROL) | 607 (48) | 0.303 | **−0.0906** | −1.000 | −1.000 | +2.000 |
| OPPOSING-LIQUIDITY | 607 (48) | 0.221 | **−0.8116** | −1.000 | −1.2668 | −0.2437 |

**Δ Mean R = −0.7210** (paired, by `decisionId`; unmatched 0).
Pooled 95% CI (10,000 iters, seed 20260811): **[−1.1915, −0.2621]** —
excludes 0. Auxiliary daily-mean estimator: observed −0.8471, CI
[−1.4466, −0.3300] — excludes 0, same sign → estimators agree.

**Mechanism (outcome transition matrix, 607 paired rows):**

| Fixed \ Opposing | WIN | LOSS | BREAKEVEN |
|---|---|---|---|
| **WIN** | 112 | **70** | 2 |
| **LOSS** | 22 | 396 | 5 |

The opposing TP both converts wins into losses (70 WIN→LOSS vs 22
LOSS→WIN) and deepens the lower tail (Q25 −1.27 vs −1.00): the fixed-2R
upside cap (+2.000 at Q75) is destroyed under opposing resolution
(Q75 −0.24). The effect is a coherent mechanism shift, not a mean
artifact — the transition asymmetry and the tail deepening are visible
in the raw paired data.

## 4. EURUSD_M15 stability partner (direction agreement only, never gating alone)

| Arm | n (nOpen) | WR | Mean R |
|---|---|---|---|
| FIXED-RR | 1,694 (50) | 0.287 | −0.1464 |
| OPPOSING-LIQUIDITY | 1,694 (50) | 0.249 | −0.3487 |

**Δ = −0.2023**, pooled CI [−0.6066, +0.2422] — includes 0; daily CI
[−0.7381, +0.1229] — includes 0. Transition asymmetry consistent with H1
(130 WIN→LOSS vs 66 LOSS→WIN; Q75 +2.000 → +0.0421). M15's point
estimate agrees in direction with H1 (both negative), which is all the
registered hierarchy requires of the stability partner; its CI including
0 means M15 alone does not establish the effect — it neither rescues nor
overrides the H1 decision.

## 5. GBPJPY_H1 evidence-only (cannot override; sign difference recorded)

| Arm | n (nOpen) | WR | Mean R |
|---|---|---|---|
| FIXED-RR | 96 (19) | 0.302 | −0.0938 |
| OPPOSING-LIQUIDITY | 96 (19) | 0.229 | +0.0169 |

**Δ = +0.1106**, pooled CI [−1.7660, +2.9527] — enormous uncertainty at
n = 96; daily CI [−0.5405, +2.3702]. Per the registered hierarchy
(protocol §12), GBPJPY_H1 is n-constrained and evidence-only and cannot
affect the verdict. **Recorded as a limitation/follow-up observation:
GBPJPY shows the opposite sign (+0.11) — a JPY-pair-specific quirk or
small-sample noise is not distinguishable at this n.** The reserved
6-month archive (`Tools/ED01/artifacts_6mo_2026-01-05_07-05/`, 46 runs)
is the designated venue to investigate this split.

## 6. Composition gates (protocol §9, amended §16.2)

- **Eligibility integrity:** eligible == LIQUIDITY closed exactly on both
  arms, all files (607/96/1,694 == LIQUIDITY closed; non-LIQUIDITY closed
  813/121/4,237 carry EV_FALSE and are the byte-identical fallback proof
  set, gate 3b PASS).
- **UNKNOWN-exclusion / single-subfamily concentration:** the treatment
  stratum contains ONLY the LIQUIDITY family — both gates are
  **structurally satisfied** (removing any other family changes the
  pooled view not at all; there is no non-LIQUIDITY treatment row to
  exclude). Recorded, not skipped; the pooled view is the LIQUIDITY view
  by construction.

## 7. Treatment rate and declared limitations

- **Treatment rate (lower bound, protocol §6):** H1 61.4% (373/607),
  M15 54.8% (929/1,694), GBPJPY 51.0% (49/96) — share of eligible rows
  with differing `rMultiple` between arms. The true override rate is
  higher: rows where the opposing TP moved but the classified outcome/R
  is unchanged (e.g., LOSS→LOSS with a moved target) are structurally
  invisible in the CSV. The mean-R metric is unaffected (it measures the
  actual expectancy difference).
- **Scope of the claim:** this experiment evaluates the **implemented
  opposing-liquidity TP resolution policy** (outcome simulation with
  `TARGET_OPPOSING_LIQUIDITY` on sweep-bearing rows) against the
  **legacy fixed-2R fallback**, on the pre-registered H1 sweep-bearing
  LIQUIDITY population. It does not claim that every possible
  opposing-liquidity exit strategy is inferior, and it does not evaluate
  opposing resolution on non-LIQUIDITY rows (structurally impossible:
  the arm cannot fire there).
- **Stability caveat:** M15's CI includes 0; the magnitude is smaller at
  M15 (−0.20 vs −0.72) — the H1 effect is the decision basis; M15
  provides direction agreement only.
- **GBPJPY direction split** recorded in section 5.

## 8. Decision ladder execution (protocol §8, exact)

1. Run-set rejection: integrity gates 1/2/3a/3b/3c all PASS → **no
   rejection**.
2. EVIDENCE prerequisites on EURUSD_H1: |Δ| 0.7210 ≥ 0.10; pooled CI
   excludes 0; n 607 ≥ 50; estimators agree; composition gates pass;
   2/2 direction agreement (H1 −0.721, M15 −0.202) → **EVIDENCE**.
3. REJECT triggers: |Δ| < 0.10 or CI includes 0 on H1 → **not met**.
4. DEFER triggers: n < 50, < 10 paired days, estimator conflict, or
   opposite-sign M15 → **not met**.
5. Direction recorded: **FIXED-better** (Δ negative — the opposing arm
   is the worse resolution).

## 9. Final verdict

**EVIDENCE FOR DISTINCT TP EXPECTANCY — FIXED-RR BETTER.**

The implemented opposing-liquidity TP resolution has **materially lower
conditional expectancy than the legacy fixed-2R fallback on the
pre-registered EURUSD_H1 sweep-bearing LIQUIDITY population**: Δ Mean R
= −0.7210 (95% CI [−1.1915, −0.2621]), n = 607, 55 paired days, with a
coherent mechanism (70 WIN→LOSS vs 22 LOSS→WIN; lower tail deepened from
Q25 −1.00 to −1.27).

The result **does not support the DD04 hypothesis** that opposing-
liquidity targeting improves expectancy on this population.

## 10. No production change from ED01-D

Per protocol §2/§8/§13 (and the frozen boundary), **no production code
change, no B8 change, and no protocol change occurs under ANY verdict —
including this one.** The experiment's job was to establish evidence, not
to modify the exit engine. The opposing-TP policy remains implemented as
researched until a separate, TDD + TT01 + explicit-decision protocol
proposes otherwise.

## 11. Hypothesis status and reopen conditions (protocol §13)

- **Status:** EVIDENCE is not REJECT — the hypothesis is **not**
  permanently closed. The finding is: TP resolution is a **real lever**
  on this population (the strongest, statistically supported effect in
  the ED sequence to date), and the implemented opposing resolution is
  inferior to fixed-2R at H1 scale.
- **Reopen/follow-up venues (designated, not immediate):**
  1. A policy-selectable exit research protocol (e.g., alternative
     opposing-TP designs — including the sign-split GBPJPY observation
     and the invisible-override caveat) as the next ED experiment.
  2. The reserved six-month archive (46 runs) for any follow-up
     confirmation — **not** another re-analysis of this same population.

## 12. Implications for the ED sequence

- Unlike ED01-A/B/C (null/defer outcomes), ED01-D is the first ED
  experiment with a strong, statistically supported
  entry/exit-related effect: the exit-TP resolution policy is
  expectancy-relevant on the LIQUIDITY population.
- Discipline preserved: evidence first, architecture change afterward.
  Any engineering consequence proceeds as a separate protocol with TDD +
  TT01 + explicit decision — never as a consequence of this verdict
  itself.
- Artifacts, manifest, analyzer/self-check outputs, the original failed
  gate evidence and the §16.2 amendment record all remain preserved on
  disk and in the protocol history.
