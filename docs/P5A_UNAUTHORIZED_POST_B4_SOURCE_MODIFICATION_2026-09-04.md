# P5A — Unauthorized Post-B4 Source Modification Detected (SymbolContext "P30")

Status: **GOVERNANCE-INTEGRITY FINDING — UNAUTHORIZED POST-B4 SOURCE MODIFICATION · B8 PATH RESET TO BLOCKED (re-measurement required) · provenance UNKNOWN = FAIL**
Date: 2026-09-04
Type: READ-ONLY governance-integrity finding, raised during the routine post-P5 safety verification. No remediation, no revert, no attribution, no gate run, no research, no holdout access, no staging, no commit.
Predecessors: `B4_VALIDATION_AUTHORIZATION_2026-08-29.md` (run `TT01_20260829_220830` + post-run STOP boundary); `P5_FOUR_GATE_LOCALIZATION_2026-08-29.md`; `P2_B2_HUMAN_DISPOSITION_2026-08-29.md`.

## 1. Detection

During the post-P5 safety verification on 2026-09-04, the tracked working-tree delta measured **23 files, +111/−52** — six insertions more than the +105/−52 state that B2 authorized, B4 measured, and P5 localized. Per-file `git diff --numstat` + mtime analysis isolates the change to **one file**:

```text
File:      Portfolio/SymbolContext.mqh (PRODUCTION PATH — EA decision/init chain)
Modified:  2026-08-31 15:50:46 (mtime) — i.e., ~2 days AFTER the B4 authorized run
           (2026-08-29 22:08) and after the P2/P5 records — detected 2026-09-04
Delta:     +6 insertions vs the B4-measured state (33/6 -> 39/6 insertions/deletions)
All other 22 modified files: mtimes unchanged (08-17/08-27) — content matches P2 state
```

## 2. Characterization (complete diff inspected)

The new content (`+` hunks, all within `SymbolContext.mqh`) comprises four components:

```text
C-a  "P30 ACTIVE-TIER survivor policy" SCAFFOLDING (6 lines):
     member arrays m_activeTierSeenSignalTime[], m_activeTierSeenConfidence[],
     m_activeTierSeenDecisionId[], m_activeTierSeenCount + constructor init.
     Comment states intent: "one decision per global signalTime, max confidence".
     VERIFIED SCAFFOLDING-ONLY: m_activeTierSeen* appears at exactly 5 sites
     (4 declarations + 1 init) — NO consumer logic anywhere in the file.
     Behavior-affecting at runtime: NO (dead state) — but explicitly PREPARATORY
     to a behavior change targeting the ACTIVE-TIER gate finding that P5
     localized (signalTime not unique 211/220) and explicitly did NOT authorize
     fixing (P5 STOP boundary: remediation requires separate authorization).

C-b  17 OOM guards in the init chain (one per component allocation:
     SwingDetector, StructuralPivotEngine, BOSDetector, TrendState,
     ProtectedPointManager, CHOCHDetector, OrderBlockDetector, FVGDetector,
     LiquidityDetector, VisualizationManager, ConfluenceEngine, EntryEngine,
     RiskManager, ExecutionManager, PositionManager, PositionLifecycleManager,
     TradeExecutionManager): allocation failure now fails Init() (return false).
     Same class as the B2-authorized Core/Engine hardening — but unauthorized.

C-c  ProtectedPointManager call-site modernization to the B1 signature
     (time, rates_total instead of the 1-element array workaround) —
     the documented B1 companion, previously SUPPORTED in the P1 record.

C-d  PHASE_1_5_DIAGNOSTIC Print block in Update() — documented Phase-1.5
     session work (session record 2026-08-19).
```

Insertion accounting: C-a (6) + C-b (17) + C-c (1) + C-d (15) = 39/6 — **fully accounted; no other content present.**

## 3. Provenance

- **No authorizing record exists.** The "P30" label does not correspond to any governance record, sprint, session summary, or decision record in the repository. The B4 post-run STOP boundary explicitly prohibited source modification after the run; the P5 boundary explicitly prohibited remediating the ACTIVE-TIER finding. This edit does exactly what those boundaries forbid (C-a) plus unrecorded hardening (C-b).
- Provenance classification: **UNEXPLAINED → UNKNOWN = FAIL** (same standard as B2: no located authorization, no author note, no session record; date 2026-08-31 15:50 outside every recorded session).

## 4. Governance impact

1. **The B4 gate measurement is stale.** `TT01_20260829_220830` measured the tree **before** this edit; the four-gate evidence (and any localization based on it) binds to the pre-P30 tree. The current working tree has never been gate-measured.
2. **Node 2 (provenance closure) REOPENS:** the working tree now contains one unauthorized production-path modification beyond the P2-dispositioned set. The P2 "all 23 files dispositioned" statement is superseded for `SymbolContext.mqh`.
3. **The B8 certification path is reset to BLOCKED** (it never left BLOCKED — but the newly-planned path via P-A..P-F now requires: disposition of this edit FIRST, then a fresh authorized TT01 run, because the P5 localization applies only to the pre-P30 tree).
4. **Boundary violation recorded:** the B4 post-run STOP boundary and the P5 boundary both explicitly prohibited source modification after their records. The edit violates both. This record does not attribute authorship.
5. The Phase-1.5/B1-companion portions (C-c/C-d) remain as previously documented; only C-a/C-b are new unauthorized content.

## 5. Disposition requirement (NOT decided here)

The edit requires a human disposition identical in structure to B2, now enlarged:

- **Option 1 — Authorize + document** the P30 scaffolding (as inert/dead-state, explicitly not wired) **and** the 17 OOM guards (as init hardening), with an author note covering the 2026-08-31 session; the ACTIVE-TIER survivor-policy *wiring* remains a separate future decision requiring its own review + gate re-measurement.
- **Option 2 — Revert** the unauthorized content (restoring the B4-measured tree) — itself a mutation requiring authorization.
- **Option 3 — Complete the P30 wiring** (implement the survivor policy) — that is an implementation requiring the full review + re-measurement cycle; **NOT recommended by this record** because it would modify gate-relevant behavior before the B4-measured state is dispositioned.

Under UNKNOWN = FAIL, the default until disposition is: **the current working tree is uncertifiable.**

## 6. Updated B8 dependency state

| # | Node | Prior (post-P5) | Now |
|---|------|-----------------|-----|
| 1 | Baseline tip decision | RESOLVED (PARKED, B1) | RESOLVED — unchanged |
| 2 | Provenance closure | RESOLVED (B2: 14 authorized) | **REOPENED — FAIL** (unauthorized SymbolContext edit, 08-31 15:50) |
| 3 | Harness/evidence reconciliation | RESOLVED (B3, deferred registration) | RESOLVED — unchanged |
| 4 | Validation authorization | AUTHORIZED + EXECUTED (B4, pre-P30 tree) | **CONSUMED — measurement stale for current tree** |
| 5 | Full TT01 run (current tree) | NOT YET AUTHORIZED | **NEW REQUIREMENT** — after node 2 re-closes |
| 6 | Four-gate localization (current tree) | NOT YET AUTHORIZED | NOT YET AUTHORIZED (requires 5) |
| 7 | Disposition / re-freeze | NOT YET AUTHORIZED | NOT YET AUTHORIZED (requires 6) |
| 8 | B8 certification | FAIL (BLOCKED) | **FAIL (BLOCKED)** — reset |
| 9 | Canonical state-register update | PARTIALLY PERFORMED | PARTIALLY PERFORMED — this finding added |

## 7. What this record does NOT do

No remediation/revert/edit of `SymbolContext.mqh` or any file; no deletion of the worktree stray binary; no gate run; no attribution of authorship; no reinterpretation of the B4/P5 evidence (they remain valid for the pre-P30 tree they measured); no B8 claim; no staging/commit; no research/M1/2026-H2/DISC-C1/Sprint 26 action.

## 8. Research-resumption status

**Research remains PAUSED.** This finding is engineering-governance only and changes nothing about research: resumption requires the canonical state register and its own explicit decision, now additionally gated behind re-disposition (P5A) and a fresh gate measurement.

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
Source/.mq5/.mqh edit:        NO (edit DETECTED, not performed)
Parameter modification:       NO
PromotionGate modification:   NO
Remediation performed:        NO
Staging/commit:               NO
Merge/rebase/cherry-pick:     NO
Revert/reset/clean:           NO
TT01/gate/test/harness run:   NO
B8 certification claimed:     NO
```

## 10. Repository safety verification

```text
Before: HEAD 36c7a73 (main); tracked diff 23 files, +111/-52 (post-P30 state, pre-existing to this record)
After:  HEAD 36c7a73 — unchanged
        branch main — unchanged
        tracked diff — unchanged (23 files, +111/-52; content untouched by this record)
        .mq5/.mqh — untouched; parameters — untouched; PromotionGate — unchanged
        staging/commit — none; merge/rebase/cherry-pick/revert/reset/clean — none
        2026-H2 — not inspected
Audit artifact: docs/P5A_UNAUTHORIZED_POST_B4_SOURCE_MODIFICATION_2026-09-04.md (the only new file)
Prior decision records: unmodified
```

---

*Governance-integrity finding record — an unauthorized post-B4 source modification to the production decision path (P30 ACTIVE-TIER scaffolding + unrecorded OOM hardening) is detected, characterized, and left untouched. Provenance UNKNOWN = FAIL. No production change; nothing committed beyond this record.*

