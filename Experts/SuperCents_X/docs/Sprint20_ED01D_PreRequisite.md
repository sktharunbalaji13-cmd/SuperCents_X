# Sprint 20 — ED01-D Pre-requisite: TP Resolution in the Replay Outcome Simulator

Status: **FROZEN** — 2026-08-09 (freeze record: section 7; analysis/
documentation only; nothing beyond this document is authorized by it)
Scope owner: exit-side research, fourth ED measurement milestone (ED01-D),
re-scoped from legacy ED01-C per `docs/Sprint20_ED01C_Protocol.md` §14
Related: `docs/Sprint20_ED01_Protocol.md` (ED sequence), DD04 row
(`docs/Sprint20_Engineering_Plan.md`), `Tools/TT01/TT01_Validate.ps1`

## 1. Purpose of this document

This document defines, before any code is touched:

1. the exact **blocker** that prevents ED01-D from running today,
2. what **ED01-D is supposed to measure**,
3. the **engineering boundary** between the prerequisite and the experiment,
4. the **gate** that must pass before any ED01-D analysis is authorized.

It is deliberately analysis-only. It changes no production code, no
telemetry, no config, and no baseline.

## 2. Blocker (verified against the code)

- The replay outcome simulator resolves entries through
  `CEntryResolverPolicy` (`Telemetry/OutcomePolicies.mqh:180`).
- That policy wraps the legacy fixed-RR builder `CEntrySetupBuilder`
  (`Entry/EntrySetupBuilder.mqh:89` — per-family `BuildFVG`, `BuildBOS`,
  `BuildOB`, `BuildCHOCH`).
- The replay path therefore **never invokes**
  `TargetResolver::ResolveTakeProfit` (`Entry/TargetResolver.mqh:20`), which
  is the DD04 `TARGET_OPPOSING_LIQUIDITY` resolution introduced in DD04.
- The live planning path does use `ResolveTakeProfit`
  (`Entry/ExecutionPlanner.mqh:262,402`), but that path sits outside the
  replay telemetry chain (DD04 row, plan register).
- **Consequence:** in the current replay outcomes,
  `TARGET_OPPOSING_LIQUIDITY` produces the same results as the legacy
  fixed-RR builder. The variable ED01-D is meant to test is invisible to the
  current simulator. Any ED01-D run on this simulator would be meaningless —
  it would measure the absence of a difference by construction.

This is exactly the failure mode that originally blocked ED01-D (legacy
ED01-C, protocol §14: "measuring TP expectancy without the sim is
meaningless").

## 3. ED01-D measurement (definition for the future protocol)

On the **same frozen B8 population** used by ED01-A/B/C (CONTROL artifacts,
2026.04.05 → 2026.07.05, per-file fingerprints per ED01-B amendment 13.2):

| Comparison | TP resolution |
|---|---|
| Arm 1 | **Opposing-liquidity TP** — `TARGET_OPPOSING_LIQUIDITY` via `TargetResolver::ResolveTakeProfit` (DD04 semantics: opposite-side ACTIVE level, newest-first, Fixed-RR fallback) |
| Arm 2 | **Legacy fixed-RR TP** — `CEntrySetupBuilder` fixed-RR target |

Metrics (closed rows, outcome 1/2/3; censored reported as nOpen):

- **Mean R** (primary)
- **Win rate** (BE-excluded)
- Closed-row outcome distributions / R distributions

Stratification:

- **Per family** (LIQUIDITY, FVG, BOS, CHOCH, UNKNOWN — subject to
  per-family n feasibility, pre-registered)
- **Per file** — EURUSD_H1, GBPJPY_H1, EURUSD_M15, with the same hierarchy
  discipline as ED01-C (H1 primary; M15 stability partner; GBPJPY
  evidence-only where n-constrained)

Pre-registered discipline (inherited from ED01-B/C, to be frozen in the
ED01-D protocol):

- audit hard gates (fingerprints, qualified/closed counts, per-family
  counts)
- paired day-stratified bootstrap (10k, fixed new seed), ≥ 10 paired days
- materiality threshold on Δ Mean R
- decision ladder (EVIDENCE / REJECT / DEFER) with pre-registered
  estimator-agreement and 2/2 direction rules
- **no production change from the analysis verdict** — the experiment
  measures; it never tunes

## 4. Engineering boundary

**Prerequisite engineering ≠ ED01-D experiment.**

The prerequisite is an engineering task: modify the replay outcome-
simulation path so that it **can** invoke `TargetResolver::ResolveTakeProfit`.

Chain:

```
CEntryResolverPolicy
        ↓
TP-resolution policy (new/adapted, selectable per run)
        ↓
TargetResolver::ResolveTakeProfit()
```

Requirements on that engineering task:

- **TDD** — resolution-policy tests (opposing-pool present → DD04 target;
  no opposing pool → Fixed-RR fallback; DD04 same-level/consumed-pool
  guards, per DD04 unit tests 46–52 semantics)
- **TT01 behavior regression** — full harness
  (`Tools/TT01/TT01_Validate.ps1`) must pass
- **Byte-identical where nothing changed** — opposing-pool-absent runs keep
  the legacy fixed-RR outcomes byte-identical vs B8 (the fallback must be
  exactly the current behavior)
- **No ED01-D analysis until this prerequisite passes** — the analysis
  authorizes itself only after the simulator can distinguish the two arms

The prerequisite may also define **how** the two arms are produced for
analysis (e.g., paired simulation runs over the same decisions, one arm per
run, or a policy switch keyed by config), and must record that choice in the
simulator manifest before ED01-D runs.

## 5. Gate (must read and be enforced)

> **ED01-D analysis MUST NOT RUN until the outcome simulator can
> distinguish `TARGET_OPPOSING_LIQUIDITY` from the legacy fixed-RR path.**

Verifiable definition of "can distinguish": a simulator manifest / run that,
for the same input decisions, produces **different outcomes** for the two
arms on at least one known opposing-pool fixture, and **identical**
fixed-RR fallback outcomes where no opposing pool exists. Until such a run
exists and is recorded, ED01-D stays blocked — no analyzer, no results, no
decision document.

This prevents repeating the exact problem that blocked ED01-D originally:
running an experiment whose simulator cannot actually observe the variable
being tested.

## 6. Status and next actions

- [x] **Review + freeze this document** (freeze record: section 7)
- [x] **Prerequisite engineering** (commit 8954332 — TDD + TT01, no ED01-D
      scope)
- [x] **Prerequisite gate run** — two-part verification, PASS 2026-08-09:
      simulator distinguishes the arms on an opposing-pool fixture, and is
      byte-identical (75/75 telemetry columns, BEHAVIOR-REGRESSION) to the
      B8 baseline under the default fixed-RR mode. Unit proof: Outcome TP
      Policy Tests 56/56 (fixed arm +2R vs opposing arm −1R on the same
      series). Recorded in the commit 8954332 message; TT01 artifacts
      `Tools/TT01/artifacts/TT01_20260809_131658/`.
- [ ] ED01-D protocol freeze (measurement definition, thresholds, ladder)
- [ ] ED01-D analysis (only after the gate above)
- [ ] ED01-D decision document

ED01-D is now **UNBLOCKED** in the plan register. The next authorized step
is the ED01-D protocol freeze against the capable simulator — **not** the
experiment itself. No ED01-D analyzer, runs, or results are authorized
until the protocol is frozen.

## 7. Freeze record (2026-08-09, user approval)

Frozen as written, with the following confirmations recorded:

1. **Scope confirmed:** document is narrow and preserves the ED01-D
   boundary — prerequisite engineering and the ED01-D experiment stay
   separate, never combined in one task.
2. **Gate confirmed, two-part verification:**
   - Opposing-pool fixture: the two TP policies produce **different**
     outcomes when an opposing liquidity pool exists.
   - Fallback fixture: when no opposing pool exists, the new path produces
     outcomes **byte-identical** to the existing fixed-RR behavior.
3. **Execution order frozen:** prerequisite PASS → freeze ED01-D protocol →
   build analyzer → run ED01-D.
4. **Rationale recorded:** without the gate, thousands of replay rows could
   be run believing DD04 is being measured while the simulator produces the
   same fixed-RR result in both arms — a false experiment. The gate prevents
   exactly that.
5. **Boundary on this document:** freezing authorizes the prerequisite
   engineering only. It does not authorize the ED01-D analyzer, any ED01-D
   runs, or any production behavior change outside the replay outcome-sim
   path.
6. **Gate PASSED 2026-08-09** (commit 8954332): both fixtures verified —
   opposing-pool fixture yields different outcomes per arm (unit suite,
   56/56), fallback fixture byte-identical vs B8 baseline (TT01
   BEHAVIOR-REGRESSION, all 75 columns, 500/500 rows). ED01-D analysis
   transitions from BLOCKED to UNBLOCKED per section 6, subject to the
   frozen execution order.
