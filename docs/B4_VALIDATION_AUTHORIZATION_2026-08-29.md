# B4 — Validation Authorization Record (First Full TT01 Run at HEAD)

Status: **B4 = AUTHORIZED (human ruling, 2026-08-29) — single full TT01 run authorized and executed per this record · B8 certification NOT claimed · post-run STOP boundary in force**
Date: 2026-08-29
Type: governance authorization + authorized engineering validation run. Research remains PAUSED; M1 remains RETIRED; no discovery/acquisition/backtest/optimization/threshold/horizon/sign search; DISC-C1 V1/V2 not executed; Sprint 26 not created; 2026-H2 not accessed.
Decision basis: `P3_B3_HARNESS_DISPOSITION_2026-08-29.md` (B3 resolved — authoritative suite identity specified), `P2_B2_HUMAN_DISPOSITION_2026-08-29.md` (B2 closed — 14/14 authorized + documented), `B8_POST_DECISION_GOVERNANCE_STATE_2026-08-29.md`, `P1_B2_ENGINEERING_REVIEW_2026-08-29.md`.
Duplicate check: performed — no equivalent B4 authorization record existed.

## 1. Authorization

The human authorizes **exactly one** full TT01 validation run to establish current HEAD evidence and begin the B8 re-certification path. This is the first HEAD measurement; it replaces no prior evidence and pre-declares no outcome.

## 2. Exact run-tree identity (recorded before execution)

```text
Repository tip:       36c7a73 (main) — HEAD at authorization time
Run-tree:             HEAD 36c7a73 + the authorized 23-file working-tree delta
                      (7 DOCUMENTED, 2 SUPPORTED, 14 AUTHORIZED + DOCUMENTED —
                      per P2_B2_HUMAN_DISPOSITION_2026-08-29.md)
Excluded:             0abe4bc (PARKED outside baseline — not merged, not included)
Excluded:             RFA harness/suites (Tests/rfa_build_and_run.ps1,
                      TestRendererFreezeAnchors/TestLiquidityLifecycle/
                      TestPortfolioConcurrency) — untracked, NOT registered,
                      NOT executed, NOT part of gate evidence
Branch:               main
```

## 3. Harness / suite / acceptance criteria (unchanged)

- Harness: **TT01** — `Tools/TT01/TT01_Validate.ps1` + `TT01_Validators.ps1`, tracked at the tip, invoked with **no parameters** (defaults: ExpectedRows 500, no AllowDelta, no AllowDecisionIds, **`-FreezeBaseline` NOT passed** — no baseline re-freeze occurs in this run).
- Gate definitions: **unchanged 17-gate set** (PREFLIGHT, COMPILE×6, COMPILE, SUITE, REPLAY, TELEMETRY-CONTRACT, EVIDENCE-REGRESSION, BEHAVIOR-REGRESSION, ACTIVE-TIER, SETTLEMENT-ISOLATION, INTEGRITY-CONTROL, PERFORMANCE).
- Acceptance criteria: unchanged. Suite total **measured from this run** — 3218/3324/3856 are not assumed (3218 remains historical TT01 evidence at `5d04bef`; 3324/3856 remain inadmissible).
- Required artifacts (produced by design): `manifest.json` (runId/timestamp/gitHead binding/overall/gates[]), `gates.jsonl`, `runtime_identity.log`, binary SHA256 archives, source-closure hash — under `Tools/TT01/artifacts/<runId>/`.

## 4. Four RED gates — to be measured, not assumed

BEHAVIOR-REGRESSION, ACTIVE-TIER, SETTLEMENT-ISOLATION, INTEGRITY-CONTROL: prior status UNKNOWN = FAIL at HEAD (last measured RED at `5d04bef`, 2026-08-19). This run provides the first HEAD measurement. **No PASS is assumed.** Post-run, each gate is either measured-RED, measured-green, or failed-to-measure — outcomes feed the subsequent localization/disposition step, which is **NOT authorized by this record**.

## 5. Known side effects of the authorized procedure (recorded before execution)

- The TT01 machinery **compiles** production/test binaries (refreshing `.ex5` artifacts — untracked binaries; no `.mq5/.mqh` source is modified) and **stops/restarts the running terminal64** for the tester phases (script lines 372/379/620/625 — documented, previously exercised in the four authorized-context runs of 08-18/19).
- Artifacts are written under `Tools/TT01/artifacts/<runId>/` by design.
- Run duration precedent: ~18–20 minutes.
- These side effects are **covered by this authorization**; they mutate no tracked source, no parameter, no PromotionGate, no branch, no HEAD.

## 6. Post-run STOP boundary (this authorization ends here)

After the run produces and the evidence is validated/recorded, this authorization **ends**. The following require separate explicit authorization and are **NOT performed**: four-gate localization; baseline modification/re-freeze; B8 certification; source/parameter/PromotionGate edits; merge/revert/reset/clean/commit; RFA registration; 2026-H2 access; research resumption; DISC-C1 V1/V2; Sprint 26.

## 7. UNKNOWN = FAIL preserved

Until this run's manifest exists and is read, HEAD gate status remains UNKNOWN = FAIL. If the run aborts, the status remains UNKNOWN = FAIL and the blocker is reported.

## 8. RUN OUTCOME (addendum — measured 2026-08-29 22:08–22:33)

Run executed per this authorization: **`TT01_20260829_220830`**, gitHead **`36c7a73`**, terminal/metaeditor **6140** (platform auto-updated from 6118 since the 08-19 runs), overall **FAIL**.

```text
PREFLIGHT=False (canonical TestRunnerEA.ex5 count=2, expected 1 — duplicate compiled
                 tester binary in scan scope, consistent with the .claude worktree copy;
                 platform 6140 noted)
COMPILE x7      =PASS (SuperCents_X/CalibrationRunner/TestRunner/TestRunnerEA/
                 BenchmarkRunner/BenchmarkRunnerEA/COMPILE — 0 errors, 0 warnings)
SUITE           =PASS  REPLAY=PASS  TELEMETRY-CONTRACT=PASS  EVIDENCE-REGRESSION=PASS
BEHAVIOR-REGRESSION =FAIL (signalTime shifted ×33; component/rule-mix diffs —
                 BOS_OB_BULLISH 32 vs baseline 0; OB_FVG_BULLISH 20 vs 0;
                 BOS_OB_BEARISH 151 vs 165; LIQUIDITY_BOS_BULLISH 103 vs 146)
ACTIVE-TIER         =FAIL (signalTime not unique 211/220; 54 outcome-column diffs;
                 gitHead-bound 36c7a73 — first HEAD measurement of this gate)
SETTLEMENT-ISOLATION=FAIL (460 column diffs / 2,733 admitted rows, Design A RED)
INTEGRITY-CONTROL   =FAIL (35,259 column diffs / 6,239 rows vs frozen CONTROL;
                 row count identical — determinism holds)
PERFORMANCE     =PASS (suite 45,510 ms — WARN > 2× baseline 9,123 ms)
OVERALL         =FAIL
```

Reading (diagnosis only, no disposition): the four REDs reproduce the 08-19 signature at HEAD — consistent with the P1/P2-authorized delta and the earlier C4/payload analysis (rule-mix shifts match closed-bar discipline; outcome-column diffs match the payload/ledger work). New measured findings for the next governance step: **PREFLIGHT RED from the worktree's stray `TestRunnerEA.ex5`** and the **platform 6118→6140 update**. Per §6, this authorization ENDS here: no localization, no re-freeze, no certification, no RFA registration, no source/parameter/PromotionGate change. The manifest is the authoritative artifact: `Tools/TT01/artifacts/TT01_20260829_220830/manifest.json`.

## 9. Post-run repository safety verification

```text
HEAD 36c7a73 — unchanged; branch main — unchanged
tracked diff — unchanged (23 files, +105/-52; the run modified no tracked source)
parameters — none modified; PromotionGate — unchanged; no staging; no commit
0abe4bc — untouched; RFA harness/suites — untracked, unregistered, untouched
2026-H2 — not inspected; no research action
New artifacts (authorized): Tools/TT01/artifacts/TT01_20260829_220830/* + refreshed binaries
```

---

*B4 authorization + run-outcome record. The first HEAD measurement is complete; localization/re-freeze/certification require separate authorization. No production change; nothing committed beyond this record.*

