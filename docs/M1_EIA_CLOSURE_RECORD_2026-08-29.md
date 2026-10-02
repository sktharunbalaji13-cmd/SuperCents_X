# M1 — EIA WTI Inventory Surprise — Governance Closure & Ratification Audit

Status: **DECISION B — M1 RETIRED (ratified)**
Date: 2026-08-29
Scope: closure/rationality audit ONLY. No new discovery, no literature search, no data acquisition, no backtest, no optimization, no 2026-H2 access.
Predecessors: `docs/MECHANISM_DISCOVERY_REPORT_2026-08-29.md` (discovery phase; its C3 independently failed cost/sign/provenance for the EIA-crude family — consistent, no conflict); Sprint 23 closure precedent (decision-record style).

## 1. Audit basis (frozen inputs)

- M1 frozen definition: WTI/CL; EIA Weekly Petroleum Status Report; `S = (Actual − Consensus)/σ`; `S > 0 → SHORT`; Wed release → Thu close, `H = 1D`; development `2021-01-01 → 2023-12-31`; independent events ≈154; validation = 2026-H2 (LOCKED).
- Ratified Class-B rare-event framework: **conjunctive** — `N_eff ≥ 100`, independent calendar events, predeclared direction, predeclared horizon, minimal DOF, same-horizon directional literature with `t ≥ 2.8`, literature effect ≥ 4× retail cost, development CI lower bound > 2× cost, reproducible historical provenance, no pooling, no splitting, no threshold/horizon scanning, no post-hoc exclusions, untouched holdout.
- Findings under ratification: Gate A (literature) FAIL; Gate B (historical provenance) FAIL.

## 2. Contradiction check — default B stands

Search for a direct logical contradiction in the existing evidence: **none found.**

- Gate A fails on two independent grounds: at the frozen `H = 1D` horizon the literature statistic is `t ≈ 0.9` (< 2.8); the only strong response is at 30 minutes (`t ≈ 2.4`), which is (i) the wrong horizon and (ii) itself below 2.8. No admissible reading of Gate A passes.
- Gate B is orthogonal to literature: even a hypothetical perfect same-horizon paper could not reconstruct the 2021–2023 consensus vintages. The closure is therefore **overdetermined** — two individually sufficient, mutually independent failures.
- No contradiction between the universal `N ≥ 300` rule and Class-B `N_eff ≥ 100`: they are alternative class requirements; within a class the gates are conjunctive and N is necessary-never-sufficient.

## 3. Question verdicts

- **Q1 — YES.** The same-horizon literature requirement is a ratified conjunctive gate; horizon is part of the mechanism definition. `t ≈ 0.9` at 1D is a precise null, not a power failure; more events would not rescue a non-existent 1-day effect.
- **Q2 — YES.** `S` is unreconstructible by an independent researcher without licensed, overwritten, non-versioned consensus history. Public EIA actuals alone cannot reproduce `S`; the development dataset fails independent reproducibility.
- **Q3 — YES.** Accepting 30-minute evidence for a frozen 1-day mechanism is horizon substitution. It is prohibited and empirically falsified here: the decay `t 2.4 (30min) → 0.9 (1D)` demonstrates horizon non-invariance.
- **Q4 — YES.** Prospective archiving creates only future vintages; it cannot retroactively supply 2021–2023 consensus. Treating it as sufficient would force estimation/substitution of missing historical consensus — altering the preregistered signal = retroactive repair.
- **Q5 — YES.** Any post-failure change to threshold, horizon, direction, instrument, or event family is selection conditioned on failure — mechanism rescue / data mining of the governance process itself. "Any threshold/horizon/sign variation of M1" is already retired by charter.
- **Q6 — YES.** Retirement is strictly preferable: Gate B alone caps the success probability of further M1 work at **zero** under current rules, because provenance cannot be cured by any paper, search, or scan. Continued effort has no admissible success state.

## 4. Closure record

1. **M1 status:** RETIRED — EIA WTI Inventory Surprise (`S = (Actual−Consensus)/σ`, `S>0 → SHORT`, `H=1D`, dev 2021-01-01→2023-12-31, N≈154). Failed before acquisition; does not advance.
2. **Gate A result:** FAIL — no independent literature demonstrates the mechanism, direction, and 1-day horizon post-2015 with `t ≥ 2.8`. Best available: Halova, Kurov & Kucher — same event/mechanism/direction, `t≈2.4` at 30 min (wrong horizon, sub-threshold) and `t≈0.9` at 1 day (frozen horizon, decisive fail).
3. **Gate B result:** FAIL — historical consensus vintages are licensed, historically overwritten, not publicly versioned, not independently hashable; `Consensus` (hence `S`) is unreconstructible for the frozen development period by an independent researcher.
4. **N result:** ≈154 independent weekly events — numerically satisfies Class-B `N_eff ≥ 100`; below the universal `N ≥ 300` for the continuous class; Class-B qualification therefore depended entirely on the other Class-B gates.
5. **Why N does not override the failed gates:** gates are conjunctive; N is necessary, never sufficient. A well-counted event family lacking same-horizon literature and reproducible inputs is still two hard failures. Frequency was never the binding constraint.
6. **Why prospective archiving is not a retroactive cure:** provenance is assessed on the frozen development window (2021–2023), whose consensus vintages no longer exist in public immutable form. Substituting today's revised consensus, estimating missing values, or setting `σ = 1` each changes the preregistered statistic. At most, prospective archiving supports a *future, separately preregistered* mechanism with a new development window — not M1, whose parameterized variations are retired.
7. **Why no further M1 search is authorized:** Gate B is literature-independent — no favorable paper, threshold, horizon, sign, or instrument change can repair unrecoverable vintages, and every such change is prohibited (Q3–Q5). Further M1 effort has zero probability of altering the closure and only spends research capacity.
8. **Holdout protection:** 2026-H2 (`2026-07-04 → 2026-12-31`) remains LOCKED — not inspected, retrieved, summarized, or inferred from in this audit; it was never needed for closure and remains untouched for future mechanisms.
9. **Production freeze:** confirmed — no `.mq5`/`.mqh` file created, modified, or compiled in this audit; parameters unchanged.
10. **PromotionGate:** UNCHANGED.
11. **Final research-state transition:** `M1 = RETIRED`; `Research = PAUSED`; `Production = FROZEN`; `Execution = BLOCKED`; `PromotionGate = UNCHANGED`; `2026-H2 = LOCKED`. M1 exits the active research queue; the retired-families registry now carries this ratification.

## 5. Attestation

```text
Data acquisition:           NO
Backtest:                   NO
Optimization:               NO
Threshold search:           NO
Horizon search:             NO
Sign search:                NO
Instrument pooling:         NO
Event pooling:              NO
2026-H2 inspection:         NO
Production modification:    NO
Parameter modification:     NO
PromotionGate modification: NO
M1 rescue attempt:          NO
```

## 6. Consistency with prior records

- Discovery phase (2026-08-29): candidate C3 (EIA crude inventory → WTI) independently FAILED on cost, sign asymmetry, and provenance; no discovery-phase candidate reopens M1 (C1 is a different family and itself not a survivor). No conflict.
- The discovery charter's retired registry already listed "M1 EIA inventory surprise" and "any threshold/horizon/sign variation of M1"; this record supplies the formal acquisition-gate ratification of that retirement.

---

*Decision record only. No production change; nothing committed beyond this record.*

