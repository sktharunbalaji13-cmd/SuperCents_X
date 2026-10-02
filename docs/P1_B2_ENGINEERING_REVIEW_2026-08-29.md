# P1 — B2 Engineering Review: 14-File Disposition (Strict Read-Only)

Status: **REVIEW COMPLETE / HUMAN DISPOSITION REQUIRED** (no disposition performed; B8 remains BLOCKED)
Date: 2026-08-29
Type: evidence/disposition review ONLY. No edits, no staging, no commit, no tests, no TT01, no gate/harness execution, no data, no holdout access.
Scope: exactly the 14 class-C files of the B2 matrix (`B8_POST_DECISION_GOVERNANCE_STATE_2026-08-29.md`; origin: `B7_B8_BASELINE_GOVERNANCE_AUDIT_2026-08-29.md`).
Method: complete working-tree diffs (captured this session), last-commit provenance per file (`git log -1`), `Clear()`-body inspection, register/roadmap/session/design-doc/commit-message authorization searches, D2 case-sensitive record search. Duplicate check: no equivalent P1 record existed before creation.

Evidence caveats enforced throughout: `recommended ≠ authorized` · `implemented ≠ reviewed` · `diff-consistent ≠ runtime-verified` · `documented ≠ certified`. Runtime neutrality is claimed **by inspection only**, never as runtime fact.

Safety baseline at review start: HEAD `36c7a73` (main); tracked diff 23 files, +105/−52 (pre-existing).

## 1. Scope

The 14 files (exact, no substitutions): `Confluence/ConfluenceEngine.mqh`, `Structure/FVGDetector.mqh`, `Knowledge/RecommendationScorer.mqh`, `Laboratory/LaboratoryReport.mqh`, `Laboratory/RecommendationEngine.mqh`, `Laboratory/StrategyCatalog.mqh`, `Production/DiagnosticEngine.mqh`, `Production/OperationalReport.mqh`, `Research/BenchmarkFramework.mqh`, `Research/EnhancedResearchReport.mqh`, `Calibration/CalibrationMetrics.mqh`, `Research/StatisticalValidator.mqh`, `Core/Engine.mqh`, `Structure/LiquidityDetector.mqh`.

## 2. Forensic findings (per file)

All 14 changes are **uncommitted** (no commit introduces them; the working tree differs from HEAD exactly by these changes plus the 7 documented/support files). D2-execution authorization search: the only `D2` mentions in all records are the 08-27 register **recommendation** (§D2/§G-5, priority 5) and the 2026-08-29 audit records — **no execution or authorization record exists**.

`Clear()`-body evidence (for the D2 delegation files): `CFVGDetector::Clear()` resets `m_fvgCount`, **`m_nextId=0`**, **`m_lastProcessedTime=0`**, pool array — strictly more than the replaced two lines; comment: epoch rebuild reproduces exact fresh-run state (LC03 deterministic reconstruction). `CLiquidityDetector::Clear()` resets `m_nextId`, `m_levelCount`, `m_lastSwingHighId/LowId`, `m_lastBOSId`, `m_lastInvalidationBOSId`, `m_invalidationSeeded`, sweep counters — likewise strictly more than the replaced lines. The D2 delegation therefore changes **restart/reset semantics** (lifecycle boundaries), not within-run behavior.

## 3. Per-file disposition matrix (1/2)

| # | File | Exact change | Last commit | Existing provenance | Auth found? | Prod path? | Behavior-affecting? | Runtime verified? | Risk | Recommended disposition | Evidence needed |
|---|------|--------------|-------------|---------------------|-------------|------------|---------------------|-------------------|------|--------------------------|-----------------|
| 1 | Confluence/ConfluenceEngine.mqh | `Shutdown()` adds `ArrayFree(m_evaluators); m_evaluatorCount=0` (frees evaluator registry; inline, not Clear-delegation) | `7d4eecb` (08-16, C1–C7) | none located | **NO** | **YES** | lifecycle-only by inspection (post-Shutdown state; no within-run path) | NO | MEDIUM | HUMAN REVIEW REQUIRED | author authorization note; post-decision gate evidence |
| 2 | Structure/FVGDetector.mqh | `Shutdown()` replaces pool+count reset with `Clear()`; `Clear()` additionally resets `m_nextId`, `m_lastProcessedTime` (LC03 deterministic fresh-run reconstruction) | `7d4eecb` | D2 recommended (register §D2/§G-5) | **NO** | **YES** | reset-semantics across Shutdown→Init cycles (by inspection); within-run neutral by inspection | NO | MEDIUM | HUMAN REVIEW REQUIRED | author note; Clear-equivalence statement; runtime evidence |
| 3 | Knowledge/RecommendationScorer.mqh | `Shutdown()`: `m_recommendationCount=0` → `Clear()` | `3ae0797` (08-09 relocate) | D2 recommended | **NO** | no (unwired) | no (unwired library) | NO | LOW | AUTHORIZE + DOCUMENT (recommended) | author note; optional unwired-impact statement |
| 4 | Laboratory/LaboratoryReport.mqh | D2 `Shutdown()`→`Clear()` | `3ae0797` | D2 recommended | **NO** | no (unwired) | no | NO | LOW | AUTHORIZE + DOCUMENT (recommended) | author note |
| 5 | Laboratory/RecommendationEngine.mqh | D2 `Shutdown()`→`Clear()` | `3ae0797` | D2 recommended | **NO** | no (unwired) | no | NO | LOW | AUTHORIZE + DOCUMENT (recommended) | author note |
| 6 | Laboratory/StrategyCatalog.mqh | D2 `Shutdown()`→`Clear()` | `3ae0797` | D2 recommended | **NO** | no (unwired) | no | NO | LOW | AUTHORIZE + DOCUMENT (recommended) | author note |
| 7 | Production/DiagnosticEngine.mqh | D2 `Shutdown()`→`Clear()` | `3ae0797` | D2 recommended | **NO** | partial library (unwired from EA chain per 25B readiness) | no | NO | LOW | AUTHORIZE + DOCUMENT (recommended) | author note |

## 3. Per-file disposition matrix (2/2)

| # | File | Exact change | Last commit | Existing provenance | Auth found? | Prod path? | Behavior-affecting? | Runtime verified? | Risk | Recommended disposition | Evidence needed |
|---|------|--------------|-------------|---------------------|-------------|------------|---------------------|-------------------|------|--------------------------|-----------------|
| 8 | Production/OperationalReport.mqh | D2 `Shutdown()`→`Clear()` | `3ae0797` | D2 recommended | **NO** | partial library | no | NO | LOW | AUTHORIZE + DOCUMENT (recommended) | author note |
| 9 | Research/BenchmarkFramework.mqh | `Shutdown()` adds `Clear()` | `3ae0797` | D2 recommended | **NO** | no (unwired) | no | NO | LOW | AUTHORIZE + DOCUMENT (recommended) | author note |
| 10 | Research/EnhancedResearchReport.mqh | `Shutdown()` adds `Clear()` | `3ae0797` | D2 recommended | **NO** | no (unwired) | no | NO | LOW | AUTHORIZE + DOCUMENT (recommended) | author note |
| 11 | Calibration/CalibrationMetrics.mqh | `IncompleteBeta`: `if(a<=0) return 0.0`; `LnGamma`: `if(x<=0) return 0.0` — invalid-input math guards | `3ae0797` | none located | **NO** | no (standalone calibration path) | outputs change only for non-positive inputs (previously invalid math) — by inspection | NO | LOW | AUTHORIZE + DOCUMENT (recommended) | author note; future invalid-input unit test |
| 12 | Research/StatisticalValidator.mqh | `Summarize()` adds `if(e+6>32) return false;` — 32-entry evidence-budget guard (6 entries/call; prevents out-of-bounds write) | `3ae0797` | none located | **NO** | no (unwired) | returns false instead of OOB write when budget exceeded — by inspection | NO | LOW | AUTHORIZE + DOCUMENT (recommended) | author note; future overflow unit test |
| 13 | Core/Engine.mqh | EventBus `new`-failure now fatal: `if(m_eventBus==NULL){log;return false;}` + `Init()` failure propagates (previously silent continue with NULL bus) | `7d4eecb` | none located | **NO** | **YES** | failure-path only (normal operation unchanged by inspection) | NO | MEDIUM-HIGH | HUMAN REVIEW REQUIRED | author note; failure-injection test; runtime evidence |
| 14 | Structure/LiquidityDetector.mqh | (a) **C2**: `InvalidateLevel(..., time[1])` (was `time[0]`) in the OpposingBOS branch — invalidation timestamp = last closed bar; (b) D2 `Shutdown()`→`Clear()` (Clear resets ids/cursors/seeded-flag/counters) | `5d04bef` (08-18) | C2 identified in register §C as "not investigated" — **contradicts implementation**; D2 recommended | **NO** | **YES** | **YES** — recorded invalidation timestamps change → level state/telemetry content changes | NO | HIGH | HUMAN REVIEW REQUIRED | C2 authorization decision; register-contradiction resolution; localization + runtime evidence |

## 4. Special scrutiny

**A — D2 sweep (11 of the 14 files).** Exact implemented pattern: `Shutdown()` delegates to the class's own `Clear()` (or, in `ConfluenceEngine`, frees the evaluator registry inline). The `Clear()` bodies reset **strictly more state** than the replaced lines (FVG: additionally `m_nextId`, `m_lastProcessedTime`; Liquidity: additionally ids/cursors/seeded-flag/counters), implementing LC03 deterministic fresh-run reconstruction. Runtime behavior: unchanged within a run (Shutdown executes at deinit); **changed across Shutdown→Init cycles** — the next session starts from exact fresh-run state instead of partially-reset state. State persistence/reset semantics: affected (by inspection). Explicit authorization: **NONE** — the register recommendation is `recommended ≠ authorized`; the D2 record search found no execution/authorization record. The implementation matching D2 is recorded as content context only.

**B — LiquidityDetector / C2 (separate treatment).** Exact change: one argument in one call — `InvalidateLevel(m_levels[i].id, "OpposingBOS", curBar, bos.pivotPrice, time[1])` (was `time[0]`) — plus the D2 delegation. Semantics: invalidation events now record the last **closed** bar's time instead of the forming bar's (forming-bar lookahead removed from recorded state). Behavior-affecting: **YES by inspection** — level state and any telemetry consuming invalidation timestamps change content. Register contradiction: §C lists C2 as latent/"not investigated" while the fix is implemented — **recorded, not resolved by this review**. Authorizing evidence: none.

**C — Core/Engine.mqh (separate treatment).** Failure mode addressed: `new CEventBusAdapter()` returning NULL was previously silently ignored (the initialization block was skipped and `Init()` continued without an event bus — downstream NULL-dereference/degradation risk); now creation failure logs and **fails `Init()`** (return false), and `Init()` failure of the bus also propagates. Production impact: YES — `Core/Engine` is the EA init chain. Normal-operation behavior: unchanged when allocation succeeds (by inspection). Authorization: none — defensiveness is not authorization.

**D — CalibrationMetrics / StatisticalValidator.** Not certified behavior-neutral: `LnGamma`/`IncompleteBeta` outputs change for non-positive inputs (invalid → 0.0), and `Summarize()` now returns `false` at the 32-entry evidence budget instead of writing out of bounds. Both alter calculation/validation semantics **on those inputs only, by inspection**. Both libraries sit outside the production EA chain (unwired per the 25B readiness assessment) — no production-path impact identified. Runtime evidence: none.

## 5. Cross-file analysis

**A — Authorization summary:** explicitly authorized: **0/14**; implicitly/indirectly referenced: **0/14** (D2/C2 are register *items* — recommendation/identification, not authorization); recommended only: **11/14** (D2 family ×10; B4-class hygiene framing ×2 — overlapping sets); no provenance found: **3/14** (`Core/Engine`, `CalibrationMetrics`, `StatisticalValidator`).

**B — Production-path summary:** 4 files — `ConfluenceEngine` (evaluator-registry lifecycle), `FVGDetector` (reset semantics), `LiquidityDetector` (behavior-affecting C2 + reset semantics), `Core/Engine` (init failure propagation). Their disposition matters for baseline certification because they make the working tree differ from every commit: any TT01 run binds gate evidence (INTEGRITY-CONTROL / BEHAVIOR-REGRESSION attribution) to an unauthorized delta, which is inadmissible under UNKNOWN = FAIL.

**C — Behavior-risk summary:** clearly behavior-affecting by inspection: `LiquidityDetector` (C2). Failure-path behavior change: `Core/Engine`. Potentially behavior-affecting (lifecycle/reset semantics): `ConfluenceEngine`, `FVGDetector`. Apparently lifecycle/defensive only: the 9 unwired/partial-library files. Impossible to classify without runtime evidence: final within-run neutrality for **all 14**.

**D — Governance contradictions (recorded, not resolved):** (1) C2 "not investigated" vs implemented; (2) D2 recommended ≠ authorized; (3) implementation existing without any authorization trail (three 08-27 waves — 14:29–14:46, 15:07–15:43, 18:36–18:38 — with no completion record); (4) carried: B7/B8 nomenclature conflict, roadmap staleness, "C1" identifier collisions, B25-03C authorization-trail gap.

**E — Certified-baseline impact:** **NO.** Under the current evidence standard (authorization/provenance UNKNOWN → NO), the 14-file working-tree delta **cannot** be treated as part of the B8-certified baseline.

## 6. Human decision packet (P1 output — decisions NOT made here)

| Decision | Current evidence | Human action required |
|---|---|---|
| D2 lifecycle changes (11 files: #1–#10, #14-D2-part) | diff-verified lifecycle-only; `Clear()` resets strictly more state (LC03 semantics); 9 unwired/partial libraries, 2 production-path; recommended in register; **no authorization**; no runtime evidence | **Authorize + document** (per file or as one set, with author note), **or revert** — human choice |
| C2 LiquidityDetector timestamp fix | behavior-affecting by inspection (invalidation timestamps); register contradiction (C2 "not investigated" vs implemented); no authorization | **Authorize + document** (and resolve the register contradiction in the same record) **or revert** |
| EventBus hardening (Core/Engine) | failure-path behavior change on the production init chain; no authorization; normal operation unchanged by inspection | **Authorize + document** **or revert** |
| Calibration/validation guards (CalibrationMetrics, StatisticalValidator) | invalid-input/overflow semantics change; unwired libraries; no authorization; no runtime evidence | **Authorize + document** **or revert** |
| Other files | none — all 14 covered above | — |

The human disposition (per file or per set) is recorded in the next governance record; until then B2 remains UNAUTHORIZED/PENDING.

## 7. Repository safety verification

```text
Before: HEAD 36c7a73 (main); tracked diff 23 files, +105/-52 (pre-existing); no P1 record existed
After:  HEAD 36c7a73 — unchanged
        branch main — unchanged
        tracked diff — unchanged (23 files, +105/-52; same 23 files)
        .mq5/.mqh — no modifications by this review
        parameters — none modified
        PromotionGate — unchanged
        staging — none; commit — none
        merge/rebase/cherry-pick/revert/reset/clean — none
        tests / TT01 / gates / untracked harness — NOT executed
        2026-H2 — not inspected
Audit artifact: docs/P1_B2_ENGINEERING_REVIEW_2026-08-29.md (the only new file)
Prior decision records: unmodified
```

## 8. Resulting state

```text
Research = PAUSED        M1 = RETIRED            B8 = BLOCKED
Production = FROZEN      Execution = BLOCKED     PromotionGate = UNCHANGED
2026-H2 = LOCKED         B1 = RESOLVED/PARKED    B2 = REVIEW COMPLETE / HUMAN DISPOSITION REQUIRED
B3 = PENDING             B4 = NOT AUTHORIZED
```

## 9. Attestation

```text
Data acquisition:             NO
Backtest:                     NO
Optimization:                 NO
Mechanism discovery:          NO
M1 reopening:                 NO
Threshold search:             NO
Horizon search:               NO
Sign search:                  NO
2026-H2 inspection:           NO
Source/.mq5/.mqh edit:        NO
Parameter modification:       NO
PromotionGate modification:   NO
Staging/commit:               NO
Merge/rebase/cherry-pick:     NO
Revert/reset/clean:           NO
Tests executed:               NO
TT01 executed:                NO
Gate run executed:            NO
Untracked harness executed:   NO
DISC-C1 V1/V2 executed:       NO
Sprint 26 created:            NO
Authorization manufactured:   NO (all 14 remain unauthorized pending human disposition)
```

Single file created: `docs/P1_B2_ENGINEERING_REVIEW_2026-08-29.md` (this record). Prior decision records unmodified.

---

*P1 engineering-review record — evidence-complete, disposition NOT performed. The human decides; B2 then transitions to AUTHORIZED+DOCUMENTED or REVERTED. No production change; nothing committed beyond this record.*




