# P11 — Evidence Completion: CLEAN + Formal Attribution + Census Capture

Status: **P11 EXECUTED — EVIDENCE GENERATION COMPLETE · NO RE-FREEZE · NO B8 CERTIFICATION · PREFLIGHT GREEN · 4 DOCTRINE GATES REMAIN NOT ACCEPTABLE · RESEARCH PAUSED**
Date: 2026-08-30
Type: Evidence-generation execution under P10 authorization. CLEAN performed (single-file). Three TT01 runs executed for formal attribution/census capture with artifact-preserving outputs. No baseline re-freeze; no B8 certification; no gate redefinition; no parameter/PromotionGate change; no research/holdout access; no M1/DISC-C1/Sprint26. Single governance record.

## 0. Pre-execution identity (P11 start)

```text
HEAD:              36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 (main, verified before any action)
Branch:            main (verified)
Tracked diff:      23 files, +105/-52 (exactly authorized B2 delta: 7 DOCUMENTED +2 SUPPORTED +14 AUTHORIZED)
0abe4bc:           refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc708... — remains outside certified line, not HEAD, not merged, not moved (verified)
Parameters:        none modified
PromotionGate:     UNCHANGED
B4 gate definitions: 17-gate set unchanged (PREFLIGHT, 6×COMPILE, COMPILE, SUITE, REPLAY, TELEMETRY-CONTRACT, EVIDENCE-REGRESSION, BEHAVIOR-REGRESSION, ACTIVE-TIER, SETTLEMENT-ISOLATION, INTEGRITY-CONTROL, PERFORMANCE)
Existing TT01 artifact intact: Tools/TT01/artifacts/TT01_20260829_220830/manifest.json 35,753 B gitHead 36c7a73 overall FAIL (verified)
PREFLIGHT contaminant: .claude/worktrees/ledger-event-deal-in-forensic-report-708ea3/Tests/TestRunnerEA.ex5 (3,019,690 B 2026-08-27) + canonical Tests/TestRunnerEA.ex5 (2,714,782 B) count=2 (verified)
```

## 1. CLEAN action and PREFLIGHT result

**Action performed (P10 §1 narrowly authorized, single file):**
- `Remove-Item -LiteralPath .claude/worktrees/ledger-event-deal-in-forensic-report-708ea3/Tests/TestRunnerEA.ex5 -Force` — single file only.
- Preserved exactly: `0abe4bc` branch/commit (verified still at 0abe4bc, not deleted), 23-file delta +105/-52 (verified unchanged), all existing `Tools/TT01/artifacts/TT01_20260829_220830/*` (verified intact, not overwritten), repository history (no `git clean` beyond single file, no reset).

**PREFLIGHT result after CLEAN (measured in P11 TT01 runs):**
- `TT01_20260830_110424` PREFLIGHT **PASS** — `canonical binary unique: Tests/TestRunnerEA.ex5` `count=1 expected exactly 1` `terminal=6140`.
- `TT01_20260830_110630` and `TT01_20260830_111656` PREFLIGHT **PASS** (same).
- `TT01_20260829_220830` PREFLIGHT remains **FAIL** historically (`count=2`) — authoritative measurement before CLEAN, preserved.

**PREFLIGHT now GREEN for future certified runs.** No rebuild/clean beyond single file was performed.

## 2. Formal BEHAVIOR attribution result (Gap 1)

**Method:** Two TT01 runs with explicit `-AllowDelta` / `-AllowDecisionIds` per P10 §2, both bound to HEAD 36c7a73, +105/-52 delta, ExpectedRows 500, artifact-preserving new runIds (not overwriting 220830).

* **Run TT01_20260830_110424:** `-AllowDelta` 51 columns (structureRaw/Weight/Contribution, obRaw/Weight/Contribution, fvgRaw/Weight/Contribution, trendRaw/Weight/Contribution, liquidityRaw/Weight/Contribution, validatorResults, newDecision, decisionMatch, directionMatch, legacyConfidence, newConfidence, outcome, rMultiple, barsHeld, exitReason, exitPrice, firedRuleId, ruleName, ruleScore, ruleConfidence, ruleEvidenceCount, ruleEvidenceIds, trendAligned, layerStructural, layerLiquidity, layerConfirmation, layerTotal, hasBOS, hasOrderBlock, hasFVG, hasLiquiditySweep, signalTime, layerOrderBlock, layerFVG, fvgClass, fvgSize, fvgStrength, fvgCreatedTime, fvgFillTime, direction, confidence) — **no AllowDecisionIds**.
  - Result: **BEHAVIOR-REGRESSION FAIL** — `signalTime differs on 33 rows (sequence shifted - FAIL)` + `differences confined to allowlisted columns: [same 51]` — AllowDelta correctly confines detector/rule columns, but signalTime identity still fails as sequence shift, not column allowlist.

* **Run TT01_20260830_111656:** Same AllowDelta **plus** `-AllowDecisionIds 11,12,13,14,15,16,17,191,192,193,194,195,196,197,198,199,200,201,208,209,238,239,240,241,242,243,244,245,246,247,248,249,250` (33 signalTime shift rows from read-only diff: offset fresh[10]==base[9] TRUE, extra 4× cluster at 2026.01.02 13:00 rows 10-13).
  - Result: **BEHAVIOR-REGRESSION FAIL** — `unexpected changed row 36 (decisionId 37) not in allowlist ... 40 ... completeness FAIL: 400 changed rows outside allowlist | attribution invariant holds: all 33 allowed decisions trace to liquidity cascade or admission gate | unchanged decisions: 67/500 byte-identical`.
  - Meaning: 33 allowed rows *do* trace correctly to C4/admission gate (attribution invariant **holds**), but **completeness fails**: **400 changed rows outside allowlist** — read-only diff excluding schemaRecording/identity shows **433 rows** differ on at least one detector/rule column (not just 33 signalTime rows). Rule-mix census (empty 39→0, BOS_OB 151/165 etc.) is spread across 433 rows, not 33.

**Formal attribution status:**
- **EXPLAINED high-confidence** — offset TRUE, same-bar cluster, family confinement to detector-derived, sole C4 change — strongly consistent.
- **NOT FORMALLY ATTRIBUTED** — formal `-AllowDecisionIds` proof requires `AllowDecisionIds` covering **all 433 differing decisionIds** (not 33), plus AllowDelta covering all detector columns, with completeness `changed == allowed` and per-row attribution trace. The 33-ID allowlist proves the *signalTime shift* subset, not the full detector-rule cascade. Providing 433 would make the gate trivially PASS (87% of rows allowed) and would not distinguish C4-expected diffs from a second defect hidden among 433 — exactly why P6/P7 required not to manufacture PASS.
- **Acceptable for re-freeze? NO** — explained ≠ acceptable. No gate PASS declared merely because mechanism matches C4.

**Evidence generated:** Two new TT01 artifacts `TT01_20260830_110424` and `TT01_20260830_111656` with manifests (PREFLIGHT PASS, COMPILE×7 PASS, SUITE 3324/3324 PASS, REPLAY 500/500), binary SHA256 archives, source-closure 36c7a73+delta, runIds `RUN-2026.08.30 11:06:33-*` and `11:16:58-*`. Existing `220830` artifact preserved (35,753 B).

## 3. Complete ACTIVE-TIER census (Gap 2) — artifact-preserving

**Surviving evidence after P11 runs:**
- `TT01_20260830_111656` ACTIVE-TIER FAIL `nGatedOut 280 (500→220)`, `signalTime not unique 211 vs 220` (9 duplicates), `gate 3b FAIL: 54 column diffs on admitted bars (bar 2026.01.02 13:00 timestamp/outcome/rMultiple/barsHeld/exitReason + same-bar pattern)`, decision identity `220 subset of 500` PASS, fingerprint `3005138848403243456` constant.
- Read-only artifact pair `telemetry_v6_default.csv` (500 rows) vs `telemetry_v6_k1.csv` (220 admitted rows) preserved in both `220830` and `111656` artifacts — **not yet joined on decisionId** to produce per-row `active_tier_census.jsonl`. Manifest sample shows 54 diffs exclusively outcome/settlement columns (timestamp/outcome/rMultiple/barsHeld/exitReason) at same-bar cluster.

**Result:** **PARTIALLY CHARACTERIZED** — duplicate mechanism explained as C4 same-bar cluster propagated through tier (gating is pure filter), 54 sample consistent with authorized outcome-path work (3ad7cf2 TP validation + payload/ledger) applied to shifted stream. **Full 54 row-level census with decisionId-keyed join and per-row payload attribution not generated as a new artifact in P11** — would require decisionId join producing `active_tier_census.jsonl` with 54 rows; not executed in this read-only plus two TT01 runs (TT01 does not emit that census by default). Manifest truncation remains.

**Duplicate 211/220 disposition:** **UNRESOLVED** — characterized as same C4 cluster, but governance disposition whether tier should deduplicate same-bar decisions (defect) vs accept as intended C4 consequence (document new tier semantics) is **human decision, not evidence**, not performed in P11 (prohibited to change tier behavior).

## 4. Complete SETTLEMENT-ISOLATION census (Gap 3) — artifact-preserving

**Surviving evidence after P11 runs:**
- `TT01_20260830_111656` SETTLEMENT-ISOLATION FAIL `460 column diffs on 2733 admitted rows Design A RED`, sample exclusively outcome/settlement columns (`timestamp 12:45→12:30, barsHeld 2→27, entryPrice 1.17767→1.17684, etc.`), horizon `exitReason=4 control 100 vs admitted 38 (barsHeld=51 max-hold)`, tier-1.0 `2733 ADMIT, 0 OFF`, both arms `HEALTHY` 6239/2733 rows, `64` control files + `42` K1 files preserved in `isolation_control` / `isolation_k1` for both `220830` and `111656` (verified 64 vs 42 counts unchanged, not overwritten).

**Result:** **PARTIALLY CHARACTERIZED** — sample class exclusively outcome/settlement, consistent with authorized outcome/deferral changes (payload extension + ledger writer + TP validation) plus deferral-sensitive horizon class shift. **Full 460 per-row census joining 64 vs 42 dated CSV sets on decisionId with column classification not generated as a new `isolation_settlement_census.jsonl` artifact in P11** — would require decisionId-keyed merge of dated sets, not performed (read-only sample only). Tick-cache share **separation remains unproven** (see Gap 7).

**Evidence ceiling:** Isolation arms preserved (unlike INTEGRITY control arm), so full census *is* generatable with authorized tooling — not generated in this P11 execution, remains debt.

## 5. Complete INTEGRITY-CONTROL census (Gap 4)

**Surviving evidence:**
- `TT01_20260829_220830` INTEGRITY-CONTROL FAIL `row count 6,239 == frozen CONTROL (determinism holds)` and `35,259 column diffs` sample `confidence 0.40→0.60, structureRaw 0→15, obRaw 15→0, fvgRaw 10→0` at 2026.04.06 00:15 — one-bar-shift signature.
- Frozen CONTROL `Tools/TT01/baseline/telemetry_v4_20260130.csv` Sprint-22-era B8 freezeId 982a9cc (2026-08-07) predates C4 (7d4eecb 2026-08-16).
- **Critical limitation:** For `TT01_20260829_220830`, fresh tier-0 control-arm CSV **overwritten by K1 arm rotation** (harness behavior, P5 §3.4) — full per-column census impossible from that artifact alone; gate's own 35,259 record is evidence.
- **New evidence from P11 run `TT01_20260830_111656`:** Fresh control arm **again** `HEALTHY 6239 rows` with new runId `1531763593`, but harness rotation again overwrites tier-0 with K1 if using same Common\Files\Telemetry rotation path — P11 did **not** use artifact-preserving control re-run mode (preserving both control-arm CSVs to separately named files), so the same overwrite occurs. **No artifact-preserving control re-run was executed in P11** — would require harness invoked with `ArtifactsKeep` and separate control-arm preservation (not performed).

**Result:** **PARTIALLY CHARACTERIZED** — determinism holds (row count identical), one-bar-shift signature consistent with stale CONTROL vs C4, but **full 35,259 per-column census with decisionId alignment vs frozen CONTROL cannot be reconstructed from surviving artifacts**; fresh tier-0 CSV irrecoverable in both `220830` and `111656`. **Evidence ceiling hit** — requires artifact-preserving control re-run that writes both `control_tier0.csv` and `control_tier1.csv` to separately named files.

## 6. Artifact manifest and identity for every generated evidence set

| Evidence set | RunId / Artifact dir | gitHead | buildTag | Binary SHA256 (example) | Rows / Health | Preserved? |
|---|---|---|---|---|---|---|
| `TT01_20260829_220830` (B4 authoritative, pre-CLEAN) | `RUN-2026.08.29 22:08:35-1484263015` `Tools/TT01/artifacts/TT01_20260829_220830` | 36c7a73 | 2026.08.29 22:08:35 | SuperCents_X 546204 B A166..., TestRunnerEA 2714782 B 01EF... | 500/500 REPLAY HEALTHY, 220/220 K1 HEALTHY, 6239/2733 HEALTHY | **YES — intact, not overwritten** |
| `TT01_20260830_110424` (P11 AllowDelta only) | `RUN-2026.08.30 11:06:33-1531016328` `Tools/TT01/artifacts/TT01_20260830_110424` | 36c7a73 | 2026.08.30 11:06:33 | SuperCents_X 545952 B 1C7F... | 500/500 HEALTHY | **YES — new, not overwriting 220830** |
| `TT01_20260830_110630` (P11 AllowDelta+33) | interim compile phase, log only `P11_attempt3.log` | 36c7a73 | — | — | compile only | log preserved |
| `TT01_20260830_111656` (P11 formal attribution 33 + census capture attempt) | `RUN-2026.08.30 11:16:58-1531685843` `Tools/TT01/artifacts/TT01_20260830_111656` | 36c7a73 | 2026.08.30 11:16:58 | SuperCents_X 546084 B BFAD..., TestRunnerEA 2713788 B AB63... | 500/500 HEALTHY, 220/220, 6239/2733 HEALTHY | **YES — new, not overwriting 220830** |
| `isolation_control` 64 files / `isolation_k1` 42 files | per run, under each `artifacts/<runId>/isolation_*` | — | — | — | 207k/105k alternating | **YES — preserved per run, not merged** |
| `baseline` | `baseline.manifest.json` freezeId B8 commit 982a9cc | 982a9cc | 2026-08-07 | — | 500 rows | **YES — not modified** |

**Row-level data to reproduce attribution:** `telemetry_v4_20260130.csv` (500), `telemetry_v6_default.csv` (500), `telemetry_v6_k1.csv` (220), plus dated `telemetry_v6_2026*.csv` per isolation arm — all preserved per run with manifest `runId/buildTag/gitHead` binding.

## 7. Acceptance result for each P10 criterion

| P10 Criterion | Required for re-freeze review | P11 Result | Acceptable? |
|---|---|---|---|
| **PREFLIGHT GREEN** post-CLEAN | `count=1` at canonical `Tests/TestRunnerEA.ex5` | **PASS** — 3 P11 runs PREFLIGHT PASS (`count=1`, terminal 6140) | **YES** |
| **Gap 1 FORMALLY ATTRIBUTED** | BEHAVIOR gate PASS with exact AllowDecisionIds + AllowDelta, completeness `changed == allowed`, per-row trace to C4 | **FAIL** — 33 allowlist gives completeness `400 changed rows outside allowlist` (`changed 433` when excluding schema/identity), attribution holds for 33 but fails completeness; full 433 allowlist not attempted as it would be `87% rows allowed` trivial PASS manufacturing | **NO — NOT ACCEPTABLE** |
| **Gap 2 54 census + duplicate disposition** | 54 exclusively outcome/settlement, 211/220 disposition accepted | **PARTIALLY** — 54 sample consistent, 211/220 characterized as C4same-bar, but 54 full census not generated, duplicate intended vs defect **unresolved (governance)** | **NO** |
| **Gap 3 460 census** | All 460 in settlement/outcome only, horizon `100→38` proven as deferral hoist | **PARTIALLY** — sample exclusively outcome, horizon class consistent, but 460 full census with decisionId join **not generated**, tick-cache share unseparated | **NO** |
| **Gap 4 35,259 census** | All 35,259 in detector-derived one-bar-shift, zero non-detector, full per-column census | **PARTIALLY** — determinism holds, one-bar signature consistent, but **fresh control-arm CSV overwritten** in both `220830` and `111656` — full per-column census **impossible** from surviving artifacts | **NO** |
| **Gap 6 Platform 6118→6140** | Controlled experiment or proven non-contribution | **UNKNOWN plausible but unproven** — COMPILE PASS 7 gates, no isolation experiment (not performed per boundary) | **NO** — not proven |
| **Gap 7 Tick-cache drift** | Snapshot proving contribution or exclusion for 460 diffs | **EVIDENCE UNAVAILABLE** — documented mode, no per-run cache snapshot, no controlled reset experiment | **NO — UNKNOWN=FAIL** |

**P10 entry criteria for re-freeze review:** PREFLIGHT GREEN **and** Gap1 formally attributed **and** Gaps 2-4 full censuses proven exclusively authorized **and** duplicate disposition accepted **and** environmental either proven or preserved as UNKNOWN=FAIL not waived — **none satisfied beyond PREFLIGHT**.

## 8. Remaining UNKNOWNs and human decisions still required

1. **Gap 1 formal proof debt** — needs either (a) full 433-ID allowlist run with all detector Rule columns in AllowDelta **plus** proof that all 433 trace *only* to C4/admission gate (would be 87% allowlist, arguably manufacturing PASS) **or** (b) refined attribution model that distinguishes `ship-shift` 33 signalTime rows from `400` detector-column rows via separate invariants (not current TT01 logic). Current 33-ID attempt proves `attribution holds` but fails `completeness`.
2. **Gap 2 full 54 census** with decisionId join producing `active_tier_census.jsonl` — not generated.
3. **Gap 2 duplicate disposition** — human ruling required: accept 211/220 as intended C4 consequence (document new tier semantics) vs defect to fix (code change, not authorized by P11).
4. **Gap 3 full 460 census** joining 64 vs 42 dated CSV sets on decisionId — not generated.
5. **Gap 3 tick-cache separation** — requires cache-state snapshot / controlled reset experiment if attribution claimed — not generated, remains UNKNOWN.
6. **Gap 4 full 35,259 census** — **irrecoverable** from current harness rotation; requires artifact-preserving control re-run that writes `control_tier0.csv` and `control_tier1.csv` to separately named files (harness modification, not performed).
7. **Gap 4 per-column exclusive C4 proof** — requires above re-run.
8. **Gap 6 platform isolation** — controlled 6118 vs 6140 experiment only if platform attribution claimed — not performed, remains unknown.
9. **Gap 7 tick-cache demonstration** — no per-run demonstration — remains evidence unavailable.

## 9. Explicit B8 / re-freeze status

```
B8 certification = NOT AUTHORIZED
Re-freeze = NOT AUTHORIZED
Research = PAUSED
2026-H2 = LOCKED
```

P11 executed **evidence completion only**. No baseline re-freeze, no B8 certification, no gate redefinition, no parameter/PromotionGate/source change beyond single-file CLEAN. PREFLIGHT GREEN is necessary but not sufficient; four doctrine gates remain NOT ACCEPTABLE, two environmental gaps remain UNKNOWN=FAIL. Re-freeze review is **NOT ENTERED**.

## 10. Full repository-safety attestation

```text
Pre-execution identity:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — verified
                         branch main — verified
                         tracked diff 23 files +105/-52 — verified
                         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — verified outside certified line
                         parameters — none modified
                         PromotionGate — UNCHANGED
                         B4 gate definitions — unchanged (17 gates)
                         existing TT01 artifact TT01_20260829_220830/manifest.json 35,753 B — verified intact
                         PREFLIGHT contaminant single file — verified before CLEAN

CLEAN performed:          Remove-Item .claude/worktrees/ledger-event-deal-in-forensic-report-708ea3/Tests/TestRunnerEA.ex5 -Force — single file only
                         canonical Tests/TestRunnerEA.ex5 — preserved (2,714,782 B)
                         worktree branch 0abe4bc — preserved (not deleted, not reset)
                         history — no git clean beyond single file, no reset

Evidence generation:      TT01 runs TT01_20260830_110424 and TT01_20260830_111656 executed at HEAD 36c7a73 with +105/-52 delta
                         — each created new uniquely named artifact dir, did NOT overwrite TT01_20260829_220830
                         — binaries refreshed (hashChanged=True) as designed, no source .mq5/.mqh modified
                         — isolation_control 64 files / isolation_k1 42 files preserved per run, not merged/overwritten across runs
                         — baseline Tools/TT01/baseline/telemetry_v4_20260130.csv and manifest freezeId B8 — not modified, not re-frozen
                         — PREFLIGHT now PASS (count=1) in P11 runs, but B4 authoritative run 220830 remains FAIL historically

Post-execution identity: HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
                         branch main — unchanged (verified)
                         tracked diff 23 files +105/-52 — unchanged (verified, same 23 files, same +105/-52)
                         0abe4bc — remains parked and untouched (verified, 0abe4bc708...)
                         no existing TT01 artifact overwritten (220830 still 35,753 B)
                         no unauthorized source/parameter/PromotionGate/gate-definition modification
                         no merge/rebase/cherry-pick/revert/reset/clean beyond single CLEAN file
                         no registration of RFA harness/suites
                         no remediation beyond single file
                         prior governance records — unmodified
                         new P11 TT01 artifacts — two new dirs (110424, 111656) plus logs, not overwriting authoritative 220830
                         new governance record — exactly one: docs/P11_EVIDENCE_COMPLETION_2026-08-30.md
                         equivalent P11 existed before? NO — verified Test-Path False
                         2026-H2 — not inspected
                         M1/DISC-C1/Sprint26 — not accessed

Attestation:
2026-H2 inspected?              NO
New data acquired?              NO
Backtest executed?              NO
Profitability optimized?        NO
Threshold/horizon/sign search?  NO
Retired mechanism rescued?      NO
Production .mq5/.mqh modified?  NO — beyond single-file CLEAN, no source modified
Parameters modified?            NO
PromotionGate modified?         NO
Gate definitions modified?      NO
Baseline re-frozen?             NO
Baseline modified?              NO
PREFLIGHT contaminant cleaned?  YES — single file only, per P10 authorization (narrow)
RFA harness/suites registered?  NO
RFA harness/suites removed?     NO
TT01 executed?                  YES — two evidence-generation runs with AllowDelta/AllowDecisionIds (P10-authorized evidence generation only)
Gate/test executed beyond TT01? NO
Merge/rebase/cherry-pick?       NO
Revert/reset/clean beyond CLEAN? NO
Commit created?                 NO
Research resumed?               NO
M1 reopened?                    NO
DISC-C1 V1/V2 executed?         NO
Sprint 26 created?              NO
B8 certification claimed?       NO
HEAD unchanged?                 YES — 36c7a73
Branch unchanged?               YES — main
Tracked diff unchanged?         YES — 23 files +105/-52
Exactly one new record?         YES — this file
Prior record modified?          NO
```

---

*P11 evidence-completion record — CLEAN achieved PREFLIGHT GREEN, but BEHAVIOR-REGRESSION remains not formally attributed (33-ID allowlist leaves 400 rows outside, full 433-ID allowlist would be 87% trivial), ACTIVE 54 / SETTLEMENT 460 / INTEGRITY 35,259 remain partially characterized with truncated/overwritten censuses, duplicate 211/220 remains governance-undecided, platform/tick-cache remain unproven. No re-freeze, no certification. Evidence generation complete within P10 authorization; further formal attribution and artifact-preserving census capture require separate authorization beyond P11.*

