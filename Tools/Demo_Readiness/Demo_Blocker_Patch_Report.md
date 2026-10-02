# Demo Blocker Patch Report — B25-03C-E

- Date: 2026-09-22 (UTC)
- Baseline: git HEAD `36c7a73` (tag `v3.0-research-baseline-116-g36c7a73`)
- Forensic basis: `Demo_Blocker_Forensic_Resolution.md` (Parts E–G)
- Constraints observed: no changes to SMC detection, ConfluenceRules, rule weights,
  tie-break logic, A-MIRROR, rule-8 promotion, simulator, risk %, position limits,
  strategy thresholds, ledger contents, or inspection-gate semantics.
  No broker orders placed; AutoTrading never enabled.

## 1. Patch inventory (production)

### Patch A — Reject unresolved entries at plan creation
- File: `Entry/ExecutionPlanner.mqh`
- `PolicyComboResult.rejectionDetails[8]` → `[9]`
- `m_rejectionCounts[8]` → `[9]`, `m_rejectionLabels[8]` → `[9]`,
  all bound loops `8` → `9` (ctor, combo eval, shutdown summary)
- New label: `m_rejectionLabels[8] = "Unresolved Entry"`
- New check in `BuildPlan()` validation block, after the C6 directional-bracket
  check, before the spread check:
  `else if(!entrySR) { valid=false; rejectReason="Unresolved Entry"; m_rejectionCounts[8]++; }`
- Mirrored check in `EvaluateSingleCombo()` for combo-statistics consistency.
- Effect: plans whose entry fell back to "Current Price" (`entrySR=false`,
  `structureResolved=false`) are REJECTED at creation and never reach the
  inspection gate as EXECUTABLE. Resolved-entry plans are unaffected.

### Patch B — Wire live target policy/RR into the ExecutionPlanner
- File: `Confluence/ConfluenceEngine.mqh`
  - New method declaration + implementation:
    `void SetPlanConfig(ENUM_TARGET_POLICY targetPolicy, double targetRR)`
    (builds a default `ExecutionPlanConfig`, overrides `targetPolicy`/`targetRR`,
    calls `m_executionPlanner.SetConfig(cfg)`).
- File: `Portfolio/SymbolContext.mqh` (after ConfluenceEngine init)
  - Maps `m_outcomeTpMode == OUTCOME_TP_FIXED_RR ? TARGET_FIXED_RR
    : TARGET_OPPOSING_LIQUIDITY`, reads `m_outcomePolicy.GetTpR()`,
    calls `m_confluenceEngine.SetPlanConfig(planTarget, planRR)`,
    plus one diagnostic `LogInfo("ExecutionPlan target: policy=%s RR=%.2f")`.
- Effect: with `OutcomeTpMode=OUTCOME_TP_FIXED_RR`, live TP resolves from
  FixedRR math (T4 fixture: 1.14772, RR 2.0) instead of the opposing-liquidity
  pool (1.16707, 31.32R). Opposing-liquidity mode behavior is unchanged
  (it was already the planner default).
- Regression audit: exactly one `SetConfig` caller on the planner
  (`SymbolContext.mqh` via `SetPlanConfig`); no duplicate/late overwrite.
  `ExecutionPlanConfig` defaults untouched.

### Patch C — Ledger
- No functional change required (forensic Part F: init chain already correct).
- Covered by existing ledger tests (see §3, T1/T8/T9).

## 2. Compile verification

| Target | Result | Artifact |
|---|---|---|
| `SuperCents_X.mq5` | **0 errors, 0 warnings** (2026-09-22 19:13:40, 17128 ms) | `SuperCents_X.ex5`, 553,732 bytes (pre-patch: 552,550; +1,182) |
| `Tests/TestRunnerEA.mq5` | **0 errors, 0 warnings** (187 s) | `Tests/TestRunnerEA.ex5`, 2,755,864 bytes |

Compile incident (resolved, test-harness side only): two intermediate compiles
reported 102 errors / 30 warnings with `CTrade`/`CExecutionManager` "type missing".
Root cause was the compile invocation, not the patches: `/include:` was pointed
at the project folder, so `<Trade/Trade.mqh>` resolved to the nonexistent
`Experts\SuperCents_X\Include\Trade\Trade.mqh` (error 106 in `SuperCents_X.log`)
instead of `MQL5\Include\Trade\Trade.mqh`, cascading through the whole tree.
Recompiling with `/compile:"<file>" /log` (no `/include`) yields 0/0.
Lesson: never override `/include` for this project; standard-library resolution
must stay on `MQL5\Include`.

## 3. Test matrix (forensic Part E) — verdicts

| Test | Description | Verdict | Evidence |
|---|---|---|---|
| T1 | Fresh env + ledger init (header valid, 0 events, NOT_FOUND) | PASS (existing) | `B25-03C-E - ledger inspection: 15/15` (E2d2 empty-ledger → NOT_FOUND) |
| T2 | Valid OB_RETEST structural entry → EXECUTABLE | NOT-RUN | Needs live M15 structure; deferred to demo run (§5) |
| T3 | Current-price fallback rejected at BuildPlan | **PASS (new, 11 asserts)** | `Patch A - unresolved entry rejected: 26/26` file-total; asserts P-A1…P-A11 (REJECTED, reason `Unresolved Entry`, `structureResolved=false`, entry `Current Price`) through real candidate→decision→plan classes |
| T4 | FixedRR BUY → TP 1.14772, RR 2.0 | **PASS (new)** | In `planner FixedRR fixtures: 74/74` file-total; TP NEAR 1e-9, RR NEAR 1e-6, name `Fixed RR 2.0` |
| T5 | FixedRR SELL → TP 1.14508, RR 2.0 | **PASS (new)** | Same suite as T4 |
| T6 | Opposing-liquidity unchanged when selected | **PASS (new)** | Default config pinned (`TARGET_OPPOSING_LIQUIDITY`, RR 2.0, OB-Retest, Protected-Point) + no-pool fallthrough == FixedRR TP |
| T7 | Existing target policies (OB/FVG/swing) | PASS (existing) | Full suite green; resolver/inspection suites (`C1 - resolver structureResolved flags: 35/35`) |
| T8 | Restart/recovery with existing INTENT | PASS (existing) | `B25-03C-B Phase 4/5/6/7` writer/recovery/corruption/idempotence suites green |
| T9 | Duplicate-plan inspection dedup | PASS (existing) | `B25-03C-E - PI comparison: 5/5` + MATCHED→BLOCK (`E2g`) |
| T10 | EURUSD M15 end-to-end fixture | NOT-RUN | Needs EURUSD M15 demo run; deployment Blocker 3 (attach EA to M15) |

New tests live in existing homes (no new files):
`Tests/unit/TestFixedRRTier.mqh::TestFixedRrTier_PlannerFixedRRFixtures` (14 asserts),
`Tests/unit/TestEPlanInspection.mqh::TestEPlanUnresolvedEntryRejected` (11 asserts)
+ `::TestEPlanConfigWiring` (7 asserts, proves `SetPlanConfig` reaches built
plans: `plan.targetPolicy == TARGET_FIXED_RR`, `targetPolicyUsed == "Fixed RR 2.0"`,
`riskReward ≈ 2.0`).

Full-suite result (headless Strategy Tester, EURUSD H1, 2026-01-01→02):
**GRAND TOTAL: 3391/3391 passed, 0 failed** (baseline 2026-09-05: 3359/3359;
+32 new assertions, zero regressions, zero `FAIL [` lines).

## 4. Test incident (resolved, test-fixture lifetime — no production impact)

First full run stopped after the wiring suite with `Tester / OnInit critical error`
(no GRAND TOTAL). Root cause: `CExecutionPlanner::Shutdown()` unconditionally
dereferences its last `Update()` decision engine (`EvaluatePolicyCombos`).
The wiring test declared `CConfluenceEngine ce` before its local decision engine,
so at function exit the engine was destroyed before `ce` → dangling pointer.
Fix (test-only): declare builder/engine before `ce` so `ce` destructs first.
Production is safe by construction: `CConfluenceEngine::Shutdown()` runs while
all members are alive, and `CExecutionPlanner::Shutdown()` early-returns once
`m_isInitialized=false`. No production change was needed or made.

## 5. Remaining work before demo

1. Blocker 3 (deployment, no code): attach the EA to **EURUSD M15**, not M1.
2. Demo run: executes T2/T10 live (OB found on M15, `entrySR=true`,
   `structureResolved=true`, EXECUTABLE, RR correct under configured policy).
3. Optional Patch C observability log line (1 line, `CExecutionIdentity.Init`).

## 6. Rollback

- Patch A: remove the `else if(!entrySR)` block in `BuildPlan()` (and its
  `EvaluateSingleCombo` mirror); restore array bounds/labels 9 → 8.
- Patch B: remove the `SetPlanConfig` call in `SymbolContext.mqh`; the planner
  reverts to default config (`TARGET_OPPOSING_LIQUIDITY`).
- Tests: revert the two test-file hunks; suite returns to 3359 baseline.
