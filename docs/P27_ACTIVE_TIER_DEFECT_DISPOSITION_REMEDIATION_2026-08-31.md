# P27 — ACTIVE-TIER Deduplication Defect Disposition & Remediation Specification

Status: **P27 COMPLETE — READ-ONLY DISPOSITION & SPECIFICATION · NO SOURCE MUTATION · NO TT01 EXECUTION · NO RE-FREEZE · B8 NOT CERTIFIED**
Date: 2026-08-31
Type: Governance/evidence disposition for ACTIVE-TIER 211/220 duplicate admissions, with minimum remediation specification. No production source changes in P27 (specification only); no parameter/PromotionGate/gate-definition/baseline modification; no TT01/test execution beyond read-only artifact analysis; no holdout/research/M1/DISC-C1/Sprint26 access; no merge/rebase/cherry-pick/revert/reset/clean; no RFA registration; no re-freeze/B8 certification. Single governance record.
Authorization boundary: P27 per P26 defect establishment (ACTIVE 211/220 = DEFECT per explicit `signalTime not unique → fail++` invariant). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52. Existing artifacts `TT01_20260829_220830` and `TT01_20260831_135145` and `P20/P21` multi-root proof preserved.

## 0. Pre-execution safety — verified before analysis

```text
HEAD:              36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 (main, verified)
Branch:            main
Tracked diff:      23 files, +105/-52 (7 DOCUMENTED +2 SUPPORTED +14 AUTHORIZED, verified same 23 files)
0abe4bc:           refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc708... — parked, not HEAD, not merged
2026-H2:           LOCKED — not inspected
Existing TT01 artifacts: TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 arm files + P16 285,010 B + P18 286,412 B + P20 346,808 B + P23 24,152/182,562/1,414 + P24 30,181 B + P25 11,283,219 B — all verified intact, no overwrite
```

## 1. PHASE 1 — DEFECT FORMALIZATION (authoritative basis)

**Authoritative invariant established by P26 (verified read-only in `Tools/TT01/TT01_Validators.ps1:547-549`):**
```powershell
$runTimes = @($run | ForEach-Object { $_.signalTime } | Sort-Object -Unique)
if ($runTimes.Count -ne $run.Count) { $fail++; $detail.Add("signalTime not unique ($($runTimes.Count) unique vs $($run.Count) rows)") }
```
This is **not a diagnostic** — it increments `$fail` and makes `ACTIVE-TIER` **FAIL** when `211 != 220`. The gate explicitly establishes **signalTime uniqueness / one decision per signalTime** as a **required invariant** for `PASS`.

**Observed ACTIVE population (preserved P21/P22/P23 evidence, `TT01_20260829_220830` and `135145` both):**
- `220 admitted decisions, 211 unique signalTime values` — 9 extra admissions.
- **Nine duplicate admissions:**
  - `2026.01.02 13:00 ×2` (2 at same bar)
  - `2026.01.14 01:00 ×2` (2 at same bar)
  - `2026.01.16 00:00 ×8` (8 at same bar)
- These correspond **exactly** to the three C4 same-bar clusters established by P21 multi-root proof: `2026.01.02 13:00` (8 fresh vs 0 base at that bar, 7 extra), `2026.01.14 01:00` (12 fresh vs 0 base), `2026.01.16 00:00` (14 fresh vs 0 base) — C4 closed-bar discipline (`7d4eecb` Swing `maxCenter rates_total-4`, FVG `(3,2,1)`, Liquidity closed-bar) correctly produces **multiple detector firings at one closed bar** (multiple `LIQUIDITY_BOS_BULLISH` at same `signalTime`).
- The `54` ACTIVE outcome/settlement diffs (`timestamp/outcome/rMultiple/barsHeld/exitReason` at same 9 duplicate bars, e.g., `2026.01.02 13:00 timestamp/outcome/rMultiple/barsHeld/exitReason`) are **downstream of those 9 duplicate admissions** (second duplicate at same `signalTime` necessarily has same `signalTime` as first but different `timestamp/outcome` due to outcome being tied to admission, not detector).
- Fingerprint `3005138848403243456` remains constant (`tier outside canonical` per validator), `220 subset of 500` remains pure tier filter — both **PASS**, proving tier did not invent candidates, it only admitted multiple per bar.

**Disposition (formal):**
```
ACTIVE-TIER = DEFECT / TIER DEDUPLICATION FAILURE
```
Do **not** reinterpret this as an intended C4 behavior. C4 detector multi-firing is **intended** (multiple evaluators may fire at one bar), but **tier admission of all of them violates the explicit `signalTime unique` invariant** — the defect is at the **tier admission/dedup boundary**, not in detector logic. Do **not** alter the uniqueness doctrine to make current behavior pass — the `fail++` *is* the doctrine.

## 2. PHASE 2 — MINIMUM REMEDIATION SPECIFICATION (read-only inspection, no edit)

**Inspection of the authorized 23-file delta and existing ACTIVE/Tier implementation:**

* **Where are same-bar decisions admitted into ACTIVE-TIER?** `Portfolio/SymbolContext.mqh:1051-1073` — `CSymbolContext::Update` calls `SwingGateEvaluate` (frozen `Structure/SwingSignificanceGate.mqh`) and, if `gate.admitted`, immediately creates an `EntryDecision` via `m_entryOrchestrator.Evaluate` and enqueues it (no per-bar deduplication). The 23-file delta does **not** contain a per-`signalTime` deduplication gate; it only adds OOM checks and diagnostic `PHASE_1_5_DIAGNOSTIC` counts, not tier logic. The delta is therefore **not the defect location** — the defect is the **absence** of deduplication in the existing tier admission path.
* **What existing ordering/ranking information determines which decision should survive?** **None established.** No file in the 23-file delta, no frozen `ConfluenceEngine.mqh`, `EntryOrchestrator`, `SwingSignificanceGate.mqh`, `Sprint22_RL_HYP_01_Protocol.md`, or `Tests/unit/TestConfluenceEngine.mqh` specifies `keep max confidence` / `keep earliest` / `keep highest `ruleScore`` / `keep first detector` per `signalTime`. `ConfluenceEngine` produces `ConfluenceResult` with `confidence` and `ruleName`, but no tier deduplication policy is documented. `Tests/unit/TestConfluenceEngine.mqh` delta only changes `Clear()` delegation, not ranking.
* **Can the existing implementation enforce `unique(signalTime)==true` without changing signal generation, detector logic, risk parameters, PromotionGate, or unrelated execution behavior?** **Structurally yes** — a narrow deduplication filter at the **ACTIVE-TIER admission boundary** (immediately after `SwingGateEvaluate` returns `ADMIT` and before `m_entryOrchestrator.Evaluate` creates the decision) could keep one decision per `signalTime` and drop the second duplicate at same `signalTime` within the same `Update` call. This would preserve upstream C4 detector/signal generation (multiple evaluators may still fire), preserve `signalId` and source evidence (dropped decision never enqueued, never gets `decisionId`), avoid changing `m_swingSignificanceTier`, `PromotionGate`, or settlement/ledger logic except as unavoidable downstream consequence (fewer admitted rows → fewer `54` diffs, fewer `9` duplicates, `211→220` becomes `220→211` unique).

**Exact invariant that should hold after remediation:**
```
unique(signalTime) == true   for ACTIVE-TIER admitted set (220 → 211 rows, 211 unique)
```
i.e., `211 admitted decisions, 211 unique signalTime values`, `nGatedOut` becomes `289` (500→211) vs current `280` (500→220), fingerprint remains constant, `220 subset of 500` becomes `211 subset of 500`.

**Survivor-selection rule — authoritative determination:**

**Do NOT assume `keep max confidence` unless authoritative code/docs already establish that rule.**

Search performed across: `Portfolio/SymbolContext.mqh` (tier admission), `Confluence/ConfluenceEngine.mqh` (signal ranking), `Structure/SwingSignificanceGate.mqh` (gate), `Sprint22_RL_HYP_01_Protocol.md`, `Sprint22_RL_HYP_01_Settlement_Isolation_Design.md`, `Tests/unit/TestConfluenceEngine.mqh`, `Tests/integration/TestReconstruction.mqh`, and the 23-file delta diffs. **No authoritative survivor-selection rule was found** — no `ArraySort by confidence`, no `keep highest ruleScore`, no `keep earliest detector`, no `keep max `firedRuleId``.

**Therefore:**

```
REMEDIATION BLOCKED — SURVIVOR POLICY UNSPECIFIED
```

Do **not** invent a survivor policy (e.g., `keep max confidence` would be an invented policy, not a documented one, and would require choosing among `confidence`, `ruleConfidence`, `ruleScore`, `firedRuleId` without basis). The 9 duplicate groups each contain 2 or 8 decisions at same `signalTime` with different `firedRuleId`/`ruleName`/`confidence` (e.g., at `2026.01.16 00:00 ×8`, which 1 of 8 to keep is undocumented).

**What must be done before editing:** A separate governance decision must explicitly authorize a survivor-selection rule (e.g., `keep max m_confluenceEngine confidence` or `keep first admitted` or `keep max ruleScore`) and document it as the **new tier deduplication doctrine**. Until then, **no source mutation** is authorized.

## 3. PHASE 3 — IF AND ONLY IF SURVIVOR POLICY IS AUTHORITATIVELY DETERMINED

**Not executed in P27** — survivor policy is **not** authoritatively determined (see Phase 2). Therefore **no source change** was made.

**If it had been determined, the minimum change would have been:**
- **Location:** `Portfolio/SymbolContext.mqh::CSymbolContext::Update` at the ACTIVE-TIER admission boundary (around `SwingGateEvaluate` + `m_entryOrchestrator.Evaluate` block, `2026.01.02` cluster handling), operating only at admission/dedup boundary.
- **Logic:** Maintain a `signalTime → admitted decision` map within the `Update` call (or within the tier filter) and if a second decision at same `signalTime` is admitted, keep one per the authorized ranking and drop the other before `decisionId` assignment and telemetry row creation.
- **Preservation:** Upstream C4 detector/signal generation untouched, `signalId` and source evidence preserved for kept decision, `signalTime` duplication eliminated, `PromotionGate`/`m_swingSignificanceTier` unchanged, gate definitions unchanged, settlement/ledger logic unchanged except as unavoidable downstream consequence of fewer admitted rows (54 diffs would reduce to 0, 211/220 becomes 211/211).

**Not performed — blocked as above.**

## 4. PHASE 4 — VALIDATION

**Not performed beyond read-only artifact analysis** — no remediation was made, so no post-remediation narrow validation to run. Pre-remediation validation remains as in P22/P23: `220 admitted, 211 unique, 54 column diffs exclusively outcome/settlement downstream of 9 duplicates, fingerprint constant, subset pure filter` — all verified read-only from `TT01_20260829_220830` and `TT01_20260831_135145` preserved artifacts (no new TT01 run in P27).

**Preserved pre-remediation artifacts:** `TT01_20260829_220830` 35,753 B, `TT01_20260831_135145` 64+42 arm files, `P16 285,010 B`, `P18 286,412 B`, `P20 346,808 B`, `P23 24,152/182,562/1,414`, `P24 30,181 B`, `P25 11,283,219 B` — all intact, not overwritten.

**Do NOT declare BEHAVIOR, SETTLEMENT, or INTEGRITY gates PASS merely because ACTIVE-TIER would become unique after a hypothetical fix** — each gate's PASS requires its own complete census and invariants, not inferred from ACTIVE.

## 5. PHASE 5 — ENVIRONMENTAL BOUNDARY — carry forward unchanged

- **Platform `6118→6140` = UNKNOWN=FAIL** — existing artifacts `terminal=6118` (08-19) vs `6140` (08-29/30) + `hashChanged=True` on all 6 targets + `COMPILE×7 PASS` on 6140 prove build health, not doctrine-neutrality; no controlled isolation experiment (same HEAD/delta, only terminal version differs) exists, none authorized in P27 to manufacture.

- **Tick-cache contribution to SETTLEMENT 460 = UNKNOWN=FAIL** — documented *possibility* in harness baseline history (B4 note) and P5/P7 as possible contributor to `460` diffs, but for `220830`/`135145` isolation arms **no cache snapshot, no arm-to-arm tick comparison, no controlled cache-reset log exists** (both arms `HEALTHY`). No environmental neutrality or causality claim without controlled evidence.

**No environmental neutrality or causality claim without controlled evidence** — both remain `UNKNOWN=FAIL`.

## 6. GOVERNANCE DISPOSITION — per gate, separate

| Gate | P27 disposition | Census | Provenance | Causal attribution | Required invariants | Formal disposition |
|---|---|---|---|---|---|---|
| **BEHAVIOR-REGRESSION** | **FORMALLY ATTRIBUTED / ACCEPTABLE as proof** (P21 multi-root, 4+26+403=433, 9 ranges, cumulative `E=3→15→29`, 5 negative controls correctly fail) — underlying measured gate remains **FAIL** `33 signalTime` until doctrine explicitly permits root-plus-propagation model (P14 O2) | `500` vs baseline 500, `433` changed (9 ranges) + `67` gaps, `P20` proof 346,808 B | `4 ROOT at 13:00` + `26 SECONDARY-ROOT at 01:00/00:00` + `403 PROPAGATED` deterministic, no unrelated row | `M1-M6 PASS` after same-bar correction | **FORMALLY ATTRIBUTED / ACCEPTABLE as proof** (not gate PASS) |
| **ACTIVE-TIER** | **DEFECT established by P26** (`211 !=220` fails explicit `signalTime unique` invariant `fail++`) | **Complete 54 column diffs** on 220 admitted, signalTime-paired, all `54` exclusively `timestamp/outcome/rMultiple/barsHeld/exitReason` downstream of 9 duplicates | **9 duplicates are same C4 clusters** (8,12,14) **but tier deduplication failure**, not intended C4 behavior | **54 census PASS**, duplicate `9` charaterized as `DEFECT`, **survivor policy not established → REMEDIATION BLOCKED** | **DEFECT / NOT ACCEPTABLE — TIER DEDUPLICATION FAILURE, REMEDIATION BLOCKED** |
| **SETTLEMENT-ISOLATION** | **PARTIALLY ATTRIBUTED / NOT ACCEPTABLE** while tick-cache remains `UNKNOWN=FAIL` | Complete `460` column diffs on 2733 admitted Design A, signalTime-paired, all `timestamp/barsHeld/entryPrice/exitPrice/outcome/rMultiple` settlement/outcome, horizon `100→38` | **All 460 exclusively AUTHORIZED_OUTCOME_PATH** (deferral hoist `SettleDue` to `GATE-OUT` bars, Design A) | Full census **PASS**, but **tick-cache separation remains UNKNOWN** | **PARTIALLY ATTRIBUTED / NOT ACCEPTABLE** |
| **INTEGRITY-CONTROL** | **FORMALLY ATTRIBUTED census** (`6,239==6,239` determinism, `35,259` one-bar-shift) | Preserved `isolation_control` 64 files aggregated 6,239 vs frozen `CONTROL_RLHYP01` 6,239, `6,239==6,239`, `P25` 11,283,219 B full census | **All 35,259 exclusively AUTHORIZED_C4** (stale CONTROL predates C4 `7d4eecb`), **zero** non-C4 | Determinism holds, byte-identity still fails as expected for stale baseline — **complete census now emitted** | **FORMALLY ATTRIBUTED as census artifact** — gate remains measured **FAIL** until re-freeze |
| **PREFLIGHT** | **GREEN** | `TT01_20260831_135145` `count=1` after P11 CLEAN | Stray `.claude/worktrees/.../TestRunnerEA.ex5` removed | — | **GREEN** |
| **Re-freeze** | **NOT AUTHORIZED by this prompt** | — | — | — | **NOT AUTHORIZED** |
| **B8** | **NOT CERTIFIED by this prompt** | — | — | — | **NOT CERTIFIED** |

**STOP after remediation and its authorized validation — P27 stops after specification/disposition, no re-freeze, no B8.**

**If survivor-selection rule cannot be established, perform no source mutation and stop after producing the specification/disposition record — exactly what P27 does: no source mutation performed, specification/disposition record produced, `REMEDIATION BLOCKED — SURVIVOR POLICY UNSPECIFIED`.**

## 7. Safety attestation

```text
Before P27: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P27 record existed; 0abe4bc at 0abe4bc708... parked; PREFLIGHT contaminant already removed; TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 arm files + P16 285,010 B + P18 286,412 B + P20 346,808 B + P23 24,152/182,562/1,414 + P24 30,181 B + P25 11,283,219 B intact
After P27:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — parked and untouched (verified)
         PREFLIGHT contaminant .claude/worktrees/.../TestRunnerEA.ex5 — remains absent (verified)
         Tests/TestRunnerEA.ex5 canonical — preserved (2,714,782 B)
         TT01_20260829_220830/manifest.json 35,753 B — intact
         P13 artifact dir 135145 64+42 files — intact
         P16/P18/P20/P23/P24/P25 proof/census artifacts — preserved (not overwritten, P27 creates no new proof artifact beyond read-only analysis)
         baseline telemetry_v4_20260130.csv + manifest freezeId B8 — not modified, not re-frozen
         staging/commit — none
         merge/rebase/cherry-pick/revert/reset/clean — none
         TT01/test/gate/harness executed — none in P27 (read-only disposition + specification, no TT01_Validate.ps1 run, no gate PASS claim)
         RFA harness/suites — not registered/removed
         2026-H2 — not inspected
         Prior governance records P5/P6/P7/P8/P9/P10/P11/P12/P13/P14/P15/P16/P17/P18/P19/P20/P21/P22/P23/P24/P25 — unmodified
         New record — exactly one: docs/P27_ACTIVE_TIER_DEFECT_DISPOSITION_REMEDIATION_2026-08-31.md
         Equivalent P27 existed before? NO — verified Test-Path False
```

---

*P27 read-only disposition & specification — ACTIVE-TIER 211/220 duplicate formally dispositioned as **DEFECT / TIER DEDUPLICATION FAILURE** per explicit `signalTime not unique → fail++` invariant (P26), 9 duplicates are C4 same-bar clusters but tier admission of all violates uniqueness; minimum remediation location is ACTIVE-TIER admission/dedup boundary in `Portfolio/SymbolContext.mqh` at `SwingGateEvaluate` + `m_entryOrchestrator.Evaluate`, but **survivor-selection rule (keep max confidence / keep earliest / keep max ruleScore) is not established in any authoritative code/docs**, therefore **REMEDIATION BLOCKED — SURVIVOR POLICY UNSPECIFIED**, no source mutation performed, 54 outcome diffs remain downstream of defect, re-freeze and B8 remain NOT AUTHORIZED, environmental UNKNOWN=FAIL preserved.*

