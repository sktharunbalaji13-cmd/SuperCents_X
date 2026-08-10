# Sprint 21 — Phase 4: Experiment Shortlist (RL01)

Status: **DRAFT FOR REVIEW — not committed, not frozen.** Phase 4 output per protocol §16.
Foundation: frozen protocol (`docs/Sprint21_ResearchReview_Protocol.md`, commit `0ce1291`), committed Phase-2 ledger (commit `2dc37a5`), user-approved Phase-3 synthesis (commit `bc67a3d`).

Shortlist rows are **ranked but not selected** in Sprint 21; selection is a user decision that opens Sprint 22+ (protocol §16).

---

## 1. Selection boundary (what qualifies for this shortlist)

Per protocol §16 and the Phase-3 synthesis, a candidate may appear only if:

1. It is a ledger row that already carries a Hypothesis field (the ledger is the sole classification foundation — no new hypotheses are invented in Sprint 21).
2. Its evidence survives the Phase-3 tier analysis (strongly-supported requirement relaxed only for seeds; conflicts carried, not resolved).
3. It has a defined falsifiable statement with explicit null, IV/DV, population, and materiality (the pre-registration seed, protocol §16).

**Exactly one row satisfies all three: RL-HYP-01 (seed = RL-SWING-01-C01).**

RL-OBS-01 (UNKNOWN-family 2.5R/3R, ED01-E) does NOT qualify: Phase 2 found no independent literature justification of a UNKNOWN-family mechanism, and Phase 3 confirmed this (§8 of synthesis). It remains REPORTED-NOT-WEIGHED and is NOT carried to this shortlist.

All other ledger rows carry Hypothesis = NONE and are excluded with recorded reasons (synthesis §8; ledger §9 discipline — never silently dropped).

---

## 2. Ranked shortlist

### Rank 1 — RL-HYP-01: Swing-gated entries on EURUSD H1 (pre-registration seed, complete schema)

| Field | Value |
|---|---|
| Candidate ID | RL-HYP-01 |
| Hypothesis | Swing-gated trend entries on EURUSD H1 outperform the fixed 2.0R benchmark (from RL-SWING-01-C01/C02, E1 positive; tested against RL-SWING-02-C01/C03 and RL-BOS-03-C01, E2 negative) |
| Null hypothesis | Δ = 0 between swing-gated entry policy and the 2.0R benchmark on EURUSD H1 |
| Independent variable | Exactly one lever: swing-significance gate on entries (ON vs OFF), named with its range |
| Dependent variable | Mean R (primary); win rate / profit factor (auxiliary, ED01 metrics) |
| Population | EURUSD H1, ED01-E window & strata — frozen B8 CONTROL artifacts 2026.04.05 → 2026.07.05, `newDecision=1`, settled `rMultiple` (outcome 1/2/3); censored (outcome 0) excluded and reported as nOpen |
| Required telemetry | NOT-IMPLEMENTED — swing-gate telemetry absent; must exist to measure the gate (entry-planner signal recording) |
| Control | Frozen B8 CONTROL — fixed 2.0R benchmark (ED01-E: 2.0R is the empirically supported fixed-RR benchmark; ED01-E decision, §9) |
| Treatment | Swing-gated entries + fixed 2.0R exits (exact alternative configuration — gate admission criterion to be named at pre-registration, from the frozen swing detector parameter set) |
| OOS requirement | M15 (EURUSD) + GBPJPY H1/M15 — not used in any fitting |
| Materiality threshold | \|Δ\| ≥ 0.10 R (ED01 scale, pre-registered) |
| Statistical test | Paired day-stratified bootstrap mean difference + 95% CI, 10,000 resamples, fixed seed (ED01-E method, seed set at pre-registration); paired by `decisionId` |
| Failure condition | CI includes 0 OR \|Δ\| < 0.10 R → REJECT; n < 50 or < 10 paired days → DEFER (ED01 ladder) |
| Expected engineering scope | MODERATE (entry-planner gate + required telemetry; TDD RED→GREEN + TT01 full gate mandatory before any run, protocol §13.3 / ED01-D/E precedent) |
| Evidence basis | E1 positive: RL-SWING-01-C01/C02 (single paper, 503 days 2024–2025, walk-forward with 30-day optimization window; WARNING-REPRO-PENDING). E2 negative counter-evidence: RL-SWING-02-C01/C03 (era-decay, impact-loop fragility), RL-BOS-03-C01 (re-bounce > cross). |
| Conflict flags | RL-CONFLICT-01 (carried, UNRESOLVED — swing profitability vs trend decay) |
| Explicit retained limitations | (a) E1 single-source: the only E1 literature source is RL-SWING-01 (REPRO-PENDING — no independent reproduction exists); (b) optimization-window dependency recorded in RL-SWING-01-C03 (edge may be design-dependent, not structural); (c) ED01-B BOS +0.0079 (E1, FX) leans against continuation edge; (d) no production change under any outcome |
| Selection status | **NOT-SELECTED** — user decides, Sprint 22+ |

**Ranking rationale (evidence strength × gap size × engineering cost estimate):** the only candidate with (a) E1 literature evidence, (b) an explicit gap (telemetry NOT-IMPLEMENTED), (c) a complete falsifiable seed in the ledger §8 schema, and (d) a defined engineering scope (MODERATE, TDD+TT01). No other row satisfies all four; no second rank exists.

---

## 3. Candidates explicitly NOT shortlisted (recorded, not dropped — protocol §13.4)

| Would-be candidate | Reason for exclusion (recorded) |
|---|---|
| RL-OBS-01 (UNKNOWN-family 2.5R/3R wider tiers) | REPORTED-NOT-WEIGHED per ED01-E protocol §6; Phase 2/3 produced NO independent literature justification of a UNKNOWN-family mechanism (protocol §16); n-constrained (117/20 days; M15 not reproduced); not a ledger Hypothesis row |
| Any FVG level/parameter hypothesis | ED01-C DEFER (7 < 10 paired days) + ED01-B composition sensitivity (FVG-carried pooled gap); no Hypothesis field in ledger; RL-CONFLICT-03 carried |
| Any OB/order-flow hypothesis | Data-class boundary: RL-OB-01 is E2 book-level (equities), OHLCV proxy weaker (RL-OB-01-C02); ORDER_BLOCK nClosed = 0 in ED01-B; RL-CONFLICT-04 carried |
| Any SMC/informed-flow hypothesis | Unobservable from OHLCV (order/wallet/identity data required, RL-SMC-04); below engine cadence (1-second horizon); no Hypothesis field |
| Any adaptive-exit hypothesis | RL-CONFLICT-02: E3 simulation-only (RL-CHOCH-02) vs E1 ED01-E (fixed 2.0R robust) — no independent justification; ED01-D/E already established the fixed-RR comparator |
| Any liquidity hypothesis | ED01-B REJECT (no distinct liquidity edge); ED01-D: liquidity-conditional TP materially worse (Δ −0.7210); no Hypothesis field |

Each of the above returns to the ledger as a gap row with its reason — none is promoted.

---

## 4. Pre-registration boundary for Sprint 22+ (protocol §13, §16)

1. This shortlist is the **seed only**. If the user selects RL-HYP-01, a full pre-registration protocol follows (protocol document, freeze approval, gates, decision ladder, analysis plan, dedicated commits — the ED01-A→E pattern).
2. The shortlist fields (null, IV, DV, population, control/treatment, materiality, test, failure condition) carry into the protocol verbatim or with a §16-style amendment record.
3. Any engineering (entry-planner gate + telemetry) requires TDD RED→GREEN + TT01 full gate before any run (protocol §13.3).
4. No production change occurs under any outcome; the experiment's job is evidence, not architecture change (protocol §13.2).
5. RL-OBS-01 remains REPORTED-NOT-WEIGHED regardless of any Sprint 22+ outcome — a second promotion attempt would require new, independent literature justification.

---

## 5. Deliverable status

- Phase 3 synthesis: COMPLETE, user-approved, committed (`bc67a3d`).
- Phase 4 shortlist: DRAFT — this document, awaiting user review and selection.
- Nothing executes until the user selects a hypothesis; selection opens Sprint 22+ pre-registration.

---

*Phase 4 shortlist, DRAFT 2026-08-11. Foundation: protocol `0ce1291`, ledger `2dc37a5`, synthesis `bc67a3d`. One candidate (RL-HYP-01), NOT-SELECTED. Next gate: user review and selection.*
