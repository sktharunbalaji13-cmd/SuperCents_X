# P26 — ACTIVE Duplicate Governance & Environmental Boundary

Status: **P26 COMPLETE — READ-ONLY GOVERNANCE/ EVIDENCE BOUNDARY · NO SOURCE/PARAMETER/PROMOTIONGATE/GATE-DEFINITION/BASELINE MODIFICATION · NO TT01 EXECUTION · NO RE-FREEZE · B8 NOT CERTIFIED**
Date: 2026-08-31
Type: Governance/evidence-boundary decision on ACTIVE 211/220 duplicate disposition and environmental uncertainties, using only authoritative repository documentation/specifications/tests at HEAD 36c7a73 + authorized 23-file delta. No production source changes; no parameter/PromotionGate/gate-definition/baseline modification; no commit/staging/merge/rebase/revert/reset/clean; no RFA registration; no holdout/research/M1/DISC-C1/Sprint26 access; no TT01 execution beyond read-only artifact analysis (P20 proof re-run). Single governance record.
Authorization boundary: P26 per P23/P24/P25 evidence debt (duplicate disposition, 6118→6140, tick-cache). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52. Existing artifacts `TT01_20260829_220830`, `TT01_20260831_135145`, `P16_proof`, `P18_proof`, `P20_proof`, `P23_formal_census`, `P24_formal_census`, `P25_integrity` preserved.

## 0. Pre-execution safety — verified before analysis

```text
HEAD:              36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 (main, verified)
Branch:            main
Tracked diff:      23 files, +105/-52 (7 DOCUMENTED +2 SUPPORTED +14 AUTHORIZED, verified same 23 files)
PromotionGate:     UNCHANGED
Parameters:        none modified
Production .mq5/.mqh: 23-file delta unchanged, no new .mq5/.mqh edit in P26
Gate definitions:  17-gate set unchanged (PREFLIGHT, 6×COMPILE, COMPILE, SUITE, REPLAY, TELEMETRY-CONTRACT, EVIDENCE-REGRESSION, BEHAVIOR-REGRESSION, ACTIVE-TIER, SETTLEMENT-ISOLATION, INTEGRITY-CONTROL, PERFORMANCE) — validated from Tools/TT01/TT01_Validators.ps1 header, unchanged
Baseline/freeze:   Tools/TT01/baseline/telemetry_v4_20260130.csv 500 rows, manifest freezeId B8 commit 982a9cc, SHA B5AB5FEE..., not re-frozen
0abe4bc:           refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc708... — parked, not HEAD, not merged
2026-H2:           LOCKED — not inspected
Existing TT01 artifacts: TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 arm files + P16 285,010 B + P18 286,412 B + P20 346,808 B + P23 24,152/182,562/1,414 + P24 30,181 B active census + P25 11,283,219 B integrity census — all verified intact, no overwrite
P20 proof re-run:  read-only `python Tools/TT01/behavior_root_cascade_proof_p20.py` against preserved 220830 fresh vs baseline (cp1252 vs utf-16) — no TT01_Validate.ps1 run, no gate PASS claim
```

## 1. PHASE 1 — ACTIVE duplicate doctrine investigation (read-only)

**Investigated artifacts:** `Tools/TT01/TT01_Validators.ps1` (active-tier gate definition, lines 482-581), `docs/Sprint22_RL_HYP_01_Adversarial_Review_*.md`, `docs/Sprint22_RL_HYP_01_Protocol.md`, `Tests/unit/TestConfluenceEngine.mqh`, `Structure/SwingDetector.mqh`/`FVGDetector.mqh`/`LiquidityDetector.mqh` (C4 closed-bar), `Tests/integration/TestReconstruction.mqh`.

**Exact three observed clusters (preserved P21/P22/P23 evidence):**
- `2026.01.02 13:00 ×2` (admitted 220 has 2 at 13:00 where default 500 has 1 at 13:00 + 7 fresh overall at 13:00)
- `2026.01.14 01:00 ×2` (2 at 01:00)
- `2026.01.16 00:00 ×8` (8 at 00:00)
- Total `9` duplicate signalTime groups, `211 unique vs 220 rows` (9 extra), fingerprint `3005138848403243456` constant and equal to default run (tier outside canonical), decision identity `220 admitted subset of 500` (pure filter, `baseTimes -notcontains` check 0) — both **PASS**.

**Binding to P21 BEHAVIOR multi-root proof:**
- `P20_proof` 4 ROOT at `2026.01.02 13:00` + 26 SECONDARY-ROOT at `2026.01.14 01:00` (12) and `2026.01.16 00:00` (14) + 403 propagated =433, 9 ranges, cumulative `E=3→15→29`.
- The `9` ACTIVE duplicates are **exactly** the `3` same-bar clusters (`8,12,14` fresh duplicates vs `0` base duplicates) propagated through the pure tier filter: `220 admitted` is `2733 admitted` is subset, so tier admits all decisions that pass `SwingSignificanceTier=1.0` at those bars, including duplicates.
- `P24/P25 ACTIVE census` shows `54` outcome-column diffs on admitted bars are downstream of these 9 duplicates, not independent detector divergence.

**Authoritative doctrine on signalTime uniqueness / deduplication / permission:**

* **Explicit requirement found:** `Tools/TT01/TT01_Validators.ps1:547-549` active-tier gate:
  ```powershell
  $runTimes = @($run | ForEach-Object { $_.signalTime } | Sort-Object -Unique)
  if ($runTimes.Count -ne $run.Count) { $fail++; $detail.Add("signalTime not unique ($($runTimes.Count) unique vs $($run.Count) rows)") }
  ```
  This is **not a diagnostic** — it increments `$fail` and makes `ACTIVE-TIER` **FAIL** when `211 != 220`. The gate explicitly establishes **signalTime uniqueness / one decision per signalTime** as a **required invariant** for `PASS`. No comment says `signalTime not unique` is informational; it is `fail++`.

* **No permission found:** No frozen baseline, B1-B3 record, `Sprint22_RL_HYP_01_Settlement_Isolation_Design.md`, `Sprint22_RL_HYP_01_Protocol.md`, `Tests/unit/TestConfluenceEngine.mqh`, or `Structure/*Detector.mqh` states `same-bar multi-decisions are permitted` or `tier may emit multiple decisions per bar`. The `C4` documentation (Swing `maxCenter rates_total-4`, FVG `(3,2,1)`, Liquidity closed-bar) describes *detector* firing per bar, not *decision* multiplicity per bar. The tier definition (`fingerprint invariant`, `decision identity subset`) says tier is a **pure filter** — it drops some bars, it does not deduplicate within a bar, but also does not *authorize* duplicates.

* **No deduplication requirement found:** No doc states `tier must deduplicate per bar (keep max confidence)` — that rule would be a *new* requirement, not pre-existing.

**Decision rule application:**
- **If authoritative doctrine explicitly permits same-bar multi-decision admission → `ACCEPTED`** — **NOT MET** (no such permission found).
- **If authoritative doctrine explicitly requires uniqueness/deduplication → `DEFECT`** — **MET** — validator explicitly requires `signalTime unique` and fails when `211 != 220`. The 9 duplicates therefore **violate an explicit gate invariant**, regardless of whether C4 correctly produced multiple detector firings at that bar.
- **If doctrine silent/ambiguous → `UNRESOLVED`** — **Not applicable** — doctrine is **not silent**: it is explicit via `fail++` on non-unique.

**Disposition:**

```
ACTIVE 9 DUPLICATES = DEFECT — TIER DEDUPLICATION FAILURE
```

**Do not modify doctrine merely to resolve ambiguity:** No modification made; existing validator is the doctrine. The defect is **tier-level, not detector-level**: C4 correctly produces multiple `LIQUIDITY_BOS_BULLISH` at `13:00` (8 fresh vs 0 base), but tier should deduplicate to one per signalTime (e.g., keep highest `confidence` per bar) to satisfy `signalTime unique`. This keeps `AUTHORIZED_C4` intact while isolating the tier defect.

**Implication:** Even though `54` outcome diffs are exclusively downstream of C4 as claimed, the `9` duplicates themselves are **unauthorized tier behavior**, so ACTIVE-TIER cannot be `FORMALLY ATTRIBUTED / ACCEPTABLE` until tier deduplication is fixed and re-measured. The earlier P23/P24 `UNRESOLVED` was correct given *mechanical consistency* alone, but the validator's explicit uniqueness requirement now resolves it to **DEFECT** without inventing intent.

**Preservation:** No doctrine modified to resolve ambiguity — existing `fail++` *is* the doctrine.

## 2. PHASE 2 — Environmental boundary (existing evidence only, no new experiment)

**Platform `6118 → 6140`:**
- Existing artifacts: `08-19` manifests `terminal=6118`, `08-29/30` manifests `terminal=5.0.0.6140` + `hashChanged=True` on all 6 targets, `COMPILE×7 PASS` (0 errors, 0 warnings) on 6140, `SUITE 3324/3324 PASS`, `PREFLIGHT PASS` after CLEAN.
- **What they prove:** Build health on 6140, `hashChanged=True` proves recompilation occurred on new toolchain, but **no per-gate isolation experiment** (same HEAD/delta, only terminal version differs, same TT01 invocation) exists, none authorized in P26 to manufacture.
- **What they do not prove:** That doctrine gates (`BEHAVIOR 33`, `ACTIVE 54`, `SETTLEMENT 460`, `INTEGRITY 35,259`) are unaffected at MQL semantics — `COMPILE PASS` is necessary but not sufficient for doctrine-neutrality.

**Tick-cache drift:**
- Existing artifacts: B4 note documents drift as *environmental nondeterminism mode* (`5062 vs 1533 replay updates` while OHLC identical) — **that precedent is from B4 era (06), not `220830`/`135145` per-run snapshot**. For `220830` and `135145` isolation arms, both `HEALTHY` (`6239/2733` rows, `0 faults`, `64/42` files), **no cache snapshot, no arm-to-arm tick comparison, no controlled cache-reset log exists** in `isolation_control`/`isolation_k1` artifacts. Within `460` diffs, no `entryPrice` without `barsHeld/timestamp` deferral signature was observed, but absence does not prove tick-cache did not affect *magnitude*.

**Bounded inference (what existing artifacts prove and do not prove):**
- **Proven:** `COMPILE` health on 6140, `PREFLIGHT` now GREEN, `433`/`54`/`460`/`35,259` diffs are all within `AUTHORIZED_C4` or `AUTHORIZED_OUTCOME_PATH` column sets, no `Core/Engine` failure-path, no parameter, `211/220` duplicates are C4 same-bar clusters, not invented candidates.
- **Not proven:** That `460` settlement `barsHeld 2→27` magnitude is *only* deferral hoist and not *also* tick-cache-driven fill timing; that `35,259` detector shifts are *only* C4 and not *also* platform MQL semantics.

**Formal status:**

```
Platform 6118→6140:  UNKNOWN = FAIL (plausible but unproven environmental factor, no controlled isolation experiment)
Tick-cache drift:    UNKNOWN = FAIL (documented possibility, no per-run cache snapshot, no separation)
```

Do not claim neutrality from compilation, do not claim causality from settlement columns. Both remain `UNKNOWN=FAIL` unless existing artifacts independently prove neutrality/causation — they do not. No new environmental isolation experiment in P26.

## 3. PHASE 3 — Four-gate final disposition (P26)

| Gate | Provenance | Complete census | Causal attribution | Required invariants | Formal disposition |
|---|---|---|---|---|---|
| **BEHAVIOR-REGRESSION** | `220830` 500 vs baseline 500, `135145` 64+42 preserved, `P20` multi-root proof 346,808 B (`4+26+403=433`, 9 ranges, `E=3→15→29`, `M1-M6 PASS` after same-bar correction, 5 negative controls correctly fail) | `433` = `4 ROOT` at `13:00` + `26 SECONDARY-ROOT` at `01:00`/`00:00` + `403 PROPAGATED` ( `18 shift`/`100 rule-flip`/`286 evidence-renumber`), `67` gaps, no unrelated row | `M1 PASS` (433 expected), `M2 PASS` (cumulative shift `3→15→29` with same-bar tail handling), `M3 PASS`, `M4 PASS` (conditional), `M5 PASS`, `M6 PASS` (provenance `36c7a73`+`23 files`+`B5AB5FEE...`) | **FORMALLY ATTRIBUTED / ACCEPTABLE as proof** (P21) — gate itself remains **measured FAIL** `33 signalTime` until doctrine explicitly permits root-plus-propagation model (P14 O2) | **FORMALLY ATTRIBUTED / ACCEPTABLE as proof** (not gate PASS) |
| **ACTIVE-TIER** | `telemetry_v6_default.csv` 500 + `k1` 220, `3005138848403243456` constant, `220 subset of 500` | **Complete 54 column diffs** on 220 admitted, signalTime-paired, exempt `decisionId/schemaRecording/identity`, all `54` exclusively `timestamp/outcome/rMultiple/barsHeld/exitReason` downstream of 9 duplicates | **9 duplicates are same C4 clusters** (8,12,14) **but validator explicitly requires `signalTime unique` (`fail++` when `211 !=220`)** | 54 census **PASS**, duplicate disposition now **DEFECT** per explicit validator requirement | **UNEXPLAINED / NOT ACCEPTABLE — TIER DEDUPLICATION DEFECT** (gate remains FAIL) |
| **SETTLEMENT-ISOLATION** | `isolation_control` 64 files (6,239) vs `isolation_k1` 42 files (2,733), `nGatedOut 3506`, `fingerprint 13548296177162108249` | **Complete 460 column diffs** on 2733 admitted Design A, all `timestamp/barsHeld/entryPrice/exitPrice/outcome/rMultiple` settlement/outcome, horizon `100→38` deferral-sensitive `barsHeld=51` | **All 460 exclusively AUTHORIZED_OUTCOME_PATH** (deferral hoist `SettleDue` to `GATE-OUT` bars, Design A) | Full census **PASS**, but **tick-cache separation remains UNKNOWN** (no snapshot) | **PARTIALLY ATTRIBUTED / NOT ACCEPTABLE** (census complete, environmental UNKNOWN) |
| **INTEGRITY-CONTROL** | `isolation_control` 64 files aggregated 6,239 vs frozen `CONTROL_RLHYP01` 6,239, `6,239==6,239` determinism holds | **Complete 35,259 column diffs** on 6,239 rows vs frozen `CONTROL_RLHYP01` Sprint-22-era, row-index-paired, `6,239==6,239` determinism holds, all `35,259` detector-derived one-bar-shift (`confidence 0.40→0.60` at `2026.04.06 00:15`) | **All 35,259 exclusively AUTHORIZED_C4** (stale CONTROL predates C4 `7d4eecb`), **zero** non-C4 | Determinism holds, byte-identity still fails as expected for stale baseline — **complete census now emitted at `P25` 11,283,219 B and `P24` active 30,181 B, but per-column `integrity_control_census.jsonl` full 35,259-record immutable file was header+sample in `P23` (1,414 B) and is now complete at `P25` (11,283,219 B) — **formally closed** as census artifact, but gate remains measured FAIL until re-freeze | **FORMALLY ATTRIBUTED / ACCEPTABLE as census artifact** — gate remains **FAIL** until re-freeze (row-count determinism is supporting, not sufficient for byte-identity PASS) |

**No gate is converted to PASS.** `FORMALLY ATTRIBUTED / ACCEPTABLE` here means **proof/census artifact is formally acceptable as evidence that diffs are deterministic C4/outcome/deferral propagation**, not that `BEHAVIOR/ACTIVE/SETTLEMENT/INTEGRITY` gates are **PASS**. All four remain **measured FAIL** until separate human disposition/re-freeze explicitly permits root-plus-propagation model and fixes tier deduplication.

## 4. Re-freeze readiness

```
RE-FREEZE READINESS = INSUFFICIENT EVIDENCE
B8 = BLOCKED
```

**Not `READY FOR RE-FREEZE REVIEW`.** Entry criteria per P10 §10 require `PREFLIGHT GREEN` (now satisfied) **and** `BEHAVIOR formally attributed` (now satisfied as proof) **and** `ACTIVE 54 census complete` (now satisfied) **and** `SETTLEMENT 460` **and** `INTEGRITY 35,259` **and** `duplicate disposition ACCEPTED` **and** `environmental either proven or preserved as UNKNOWN not waived` — **duplicate 9 remains DEFECT (not ACCEPTED) and environmental 6118→6140/tick-cache remain UNKNOWN=FAIL**, so re-freeze review is **not entered**. `B8` remains **BLOCKED** — no certification, no re-freeze, no baseline modification.

## 5. Safety attestation — READ-ONLY

```text
Before P26: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P26 record existed; 0abe4bc at 0abe4bc708... parked; PREFLIGHT contaminant already removed; TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 arm files + P16 285,010 B + P18 286,412 B + P20 346,808 B + P23 24,152/182,562/1,414 + P24 30,181 B active census + P25 11,283,219 B integrity census intact
After P26:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — parked and untouched (verified)
         PREFLIGHT contaminant .claude/worktrees/.../TestRunnerEA.ex5 — remains absent (verified)
         Tests/TestRunnerEA.ex5 canonical — preserved (2,714,782 B)
         TT01_20260829_220830/manifest.json 35,753 B — intact
         P13 artifact dir 135145 64+42 files — intact
         P16/P18/P20/P23/P24/P25 proof/census artifacts — preserved (not overwritten, P26 creates no new proof artifact beyond read-only analysis)
         baseline telemetry_v4_20260130.csv + manifest freezeId B8 — not modified, not re-frozen
         staging/commit — none
         merge/rebase/cherry-pick/revert/reset/clean — none (beyond P11 single-file CLEAN, preserved)
         TT01/test/gate/harness executed — none in P26 (read-only doctrine investigation + re-running P20 proof script read-only against preserved artifacts, no TT01_Validate.ps1 run, no gate PASS claim)
         RFA harness/suites — not registered/removed
         2026-H2 — not inspected
         Prior governance records P5/P6/P7/P8/P9/P10/P11/P12/P13/P14/P15/P16/P17/P18/P19/P20/P21/P22/P23/P24/P25 — unmodified
         New record — exactly one: docs/P26_ACTIVE_DUPLICATE_ENVIRONMENTAL_BOUNDARY_2026-08-31.md
         Equivalent P26 existed before? NO — verified Test-Path False
```

---

*P26 read-only governance — ACTIVE 9 duplicates explicitly violate `signalTime unique` gate invariant (`fail++` when `211 !=220`), therefore classified **DEFECT — TIER DEDUPLICATION FAILURE** (not UNRESOLVED), not silently accepted as intended; environmental 6118→6140 and tick-cache remain **UNKNOWN=FAIL** (no controlled isolation experiment, COMPILE PASS not neutrality); BEHAVIOR remains formally attributed as multi-root proof while gate remains measured FAIL; re-freeze and B8 certification remain **INSUFFICIENT EVIDENCE / BLOCKED**. No production change; READ-ONLY beyond this record.*

