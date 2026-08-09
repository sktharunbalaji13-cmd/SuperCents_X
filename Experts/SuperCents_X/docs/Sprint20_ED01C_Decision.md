# Sprint 20 — ED01-C Decision: Within-Family Discrete Confidence-Level Expectancy

Status: DEFER — 2026-08-09
Scope owner: entry-decision research, third measurement milestone (ED01-C)
Protocol: `docs/Sprint20_ED01C_Protocol.md` (frozen 2026-08-09; execution
amendment 16.1 freeze record — hierarchy adaptation, 0.10 threshold,
qualified closing rule, REJECT direction clarification, frozen execution
order)

## 1. Verdict summary

**DEFER — the pre-registered paired-day gate fails on the primary file.**

| Criterion (protocol §5/§8) | Requirement | Result |
|---|---|---|
| Materiality | \|Δ\| ≥ 0.10 on EURUSD_H1 | +0.0262 — below bar (point estimate) |
| Paired days (closed rows) | ≥ 10 on EURUSD_H1 | **7 — FAILS (gate, §5 line 133 / §8 line 182)** |
| 95% CI excludes 0 | CI spanning zero | **CI unavailable — no inference (gate)** |
| n ≥ 50 per level, EURUSD_H1 | HIGH and LOW | PASS (143 / 175) |
| M15 stability (2/2) | resolvable, no conflict | M15 resolvable but moot — H1 gated first |

The primary comparison cannot produce its pre-registered confidence interval:
the FVG-HIGH (0.40) and FVG-LOW (0.35) closed-row day sets overlap on only
7 days in the frozen EURUSD_H1 CONTROL run. The protocol's rule is explicit —
"Require ≥ 10 paired days with rows in BOTH levels, else DEFER" — and the
gate is applied exactly as written. No post-hoc rule change after seeing the
result: the protocol was frozen, the audit passed, the ladder executed.

## 2. Population audit

Analyzer self-check (hard gate, protocol §11 + amendments 13.1/13.2/16.1):
**PASS** — per-file fingerprints reproduce the frozen values (EURUSD_H1
`3005138848403243456`, GBPJPY_H1 `14617585492269479818`, EURUSD_M15
`13548296177162108249`, each also identical in the 6-month archive CONTROL
runs), qualified counts and per-family closed counts reproduce the frozen
ED01-A analysis exactly (EURUSD_H1 1,468/1,420; GBPJPY_H1 236/217;
EURUSD_M15 5,981/5,931), and the FVG level-split integrity gate reproduces
the frozen ED01-A FVG_0.40 grid admitted counts exactly (EURUSD_H1 HIGH 143 /
LOW 175; EURUSD_M15 HIGH 1,159 / LOW 933). Determinism: two full runs
produced byte-identical `results_ED01C.json` (MD5
`8865EEA6136AB34AE9B16DC1C2BEB8F8`), seed 20260810.

Population: frozen B8 CONTROL artifacts, 2026.04.05 → 2026.07.05,
`newDecision=1`, settled `rMultiple` (outcome 1/2/3), censored (outcome 0)
excluded from R statistics and reported as nOpen. Level groups per §3:
FVG-HIGH = confidence 0.40, FVG-LOW = 0.35.

## 3. EURUSD_H1 primary result (FVG HIGH 0.40 vs LOW 0.35)

| Group | nClosed (nOpen) | WR (BE-excl.) | Mean R | Median | Q25/Q75 | maxDD |
|---|---|---|---|---|---|---|
| FVG-HIGH | 143 (3) | 0.3916 | +0.1748 | −1.0 | −1.0 / 2.0 | 26.0 |
| FVG-LOW | 175 (30) | 0.3829 | +0.1486 | −1.0 | −1.0 / 2.0 | 37.0 |

**Δ Mean R = +0.0262.** Closed-row paired days: **7 < 10** → bootstrap CI
unavailable → **DEFER** per the pre-registered ladder. The point estimate
itself is 0.0262 R — far below the 0.10 R materiality threshold — so even
without the gate the primary file holds no evidence of a distinct level
expectancy. Both levels show the same -1.0 median / 2.0 upside skew shape;
the HIGH/LOW gap is driven by level sizes, not distribution shape.

## 4. EURUSD_M15 stability partner (informative, never gating alone)

| Group | nClosed (nOpen) | WR | Mean R | maxDD |
|---|---|---|---|---|
| FVG-HIGH | 1,159 (21) | 0.3874 | +0.1596 | 86.0 |
| FVG-LOW | 933 (2) | 0.3226 | −0.0469 | 134.1 |

Δ = **+0.2065**, pooled CI [−0.0117, +0.2276] (58 paired days) — **includes 0**.
Auxiliary daily-mean estimator: −0.0175, CI [−0.2966, +0.2650] — **opposite
sign to the pooled point estimate**. The stability partner is therefore
itself unstable: pooled- and daily-mean estimators disagree in direction, and
the pooled CI does not exclude 0. M15 cannot independently establish an edge
(protocol §12 rule 3), and it cannot rescue a gated EURUSD_H1 verdict (§12).
The M15 result is recorded as evidence, not promoted into any entry-decision
change.

## 5. GBPJPY_H1 evidence + BOS limitations

- **GBPJPY_H1 FVG** (evidence-only, n-constrained per §12): HIGH 25 closed
  (wr 0.04, Mean R −0.88), LOW 14 closed (wr 0.50, Mean R +0.50), Δ −1.38,
  3 paired days. n-constrained by pre-registered design; no weight in the
  verdict.
- **BOS level split** (evidence-only): EURUSD_H1 HIGH 364 / LOW **14**;
  EURUSD_M15 HIGH 2,056 / LOW **39**; GBPJPY_H1 HIGH 58 / LOW 1. The 0.45
  floor admits almost the entire BOS population, leaving the LOW side
  unresolvable — the BOS level question is structurally undecidable in this
  data (≤ 14 closed LOW rows H1), exactly the n-constraint the protocol
  registered in §3/§12.

## 6. Exploratory pooled-level view (never gates)

Pooled FVG+BOS HIGH vs LOW on EURUSD_H1: Δ = **−0.0896**, CI [−0.2050,
+0.2000] (nHigh 507, nLow 189). Composition gate (§9): the view is
**composition-confined on both FVG and BOS** — removing either family flips
sign or drops below the 0.10 bar. Report-only; not interpretable as a
level statement and not weighed in the verdict.

## 7. Informational cross-checks

- TT01 B8 baseline replay (EURUSD H1, 2026-01): FVG-HIGH 36 / LOW 43 closed —
  per-level n < 50, informational only (protocol §6).
- Determinism: byte-identical output across runs (see §2).

## 8. Final verdict

**DEFER — paired days < 10 on EURUSD_H1 (primary).**

The hypothesis "higher discrete FVG confidence carries a materially different
conditional expectancy" is **not established and not rejected** under the
frozen protocol: the primary file cannot produce its pre-registered
confidence interval (7 < 10 paired days), and its point estimate (+0.0262)
is far below the 0.10 R materiality bar. The stability partner is
directionally suggestive (M15 pooled +0.2065) but its CI includes 0, its
daily-mean estimator opposes, and M15 can neither rescue the H1 gate nor
stand alone. DEFER is a pre-registered verdict, not a failure: the question
remains open **only** under the §13 reopen conditions.

## 9. No production change

- Do **not** promote the M15 Δ into an entry-decision change.
- Do **not** introduce level-aware admission policy or score-continuity work —
  those are justified only by EVIDENCE FOR, and would proceed as a separate
  protocol with TDD + TT01 + explicit decision (§13).
- Do **not** modify the ConfluenceValidator, floors, weights, or any
  configuration.
- Do **not** amend the protocol or the paired-day requirement post-hoc, and
  do **not** re-analyze the same B8 population to recover a CI.
- No algorithm, config, or baseline changes. ED01-C is analysis-only.

## 10. Hypothesis status and reopen conditions (§13)

- **Status: OPEN, deferred** — not permanently closed (that requires REJECT
  with both resolvable populations null, which the primary gate prevents us
  from reaching).
- **Reopen only via genuinely new evidence:** the reserved six-month archive
  (`Tools/ED01/artifacts_6mo_2026-01-05_07-05/`, 46 runs) or a future
  data/model change — not another re-analysis of the same B8 population.
  The archive materially increases the H1 paired-day set and is the
  registered path to a resolute ED01-C rerun.
- Any reopened run must re-freeze the protocol (or a new one), re-audit the
  new population, and re-apply the identical ladder.

## 11. Implications for the ED sequence

1. **ED01-C = DEFER, not failure.** No entry logic changes, and no level-
   based variant enters the design queue on this evidence.
2. **ED01-D (TP target logic)** remains registered and blocked on the
   outcome-sim engineering prerequisite (DD04 opposing-liquidity path outside
   the legacy fixed-RR builder) — unchanged by this result.
3. **The 6-month archive now has a concrete consumer:** the pre-registered
   ED01-C reopen path. Its 46 runs were collected for exactly this
   long-horizon validation purpose (ED01-A amendment 13.1).
4. **Learned and recorded:** the FVG confidence levels rarely co-occur on
   the same H1 day in the B8 window (7 closed-row paired days) — a structural
   property of the population that any future level-split experiment must
   pre-register against.
