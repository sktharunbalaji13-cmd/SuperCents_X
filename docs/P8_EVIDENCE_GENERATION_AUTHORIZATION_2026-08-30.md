# P8 — Evidence Generation Authorization (B7→B8 Path)

Status: **P8 COMPLETE — READ-ONLY EVIDENCE GENERATION · NO BASELINE RE-FROZEN · NO REMEDIATION · B8 NOT AUTHORIZED · RESEARCH PAUSED**
Date: 2026-08-30
Type: Evidence-generation record under P7-identified gaps. No source/parameter/PromotionGate/gate-definition/baseline modification; no re-freeze; no remediation; no registration; no holdout access; no research; no M1/DISC-C1/Sprint26. Single authorized record creation.
Authorization boundary: P8 Evidence Generation per P7_EVIDENCE_COMPLETION_REFREEZE_READINESS_2026-08-30.md (seven gaps). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52 pre-existing. PREFLIGHT contaminant remains.

## 1. Authorization scope

**P8 authorized acts (only):**
1. Formal per-row attribution for 33 BEHAVIOR-REGRESSION signalTime shifts via TT01 comparison machinery (-AllowDelta/-AllowDecisionIds where applicable) — read-only characterization;
2. Complete ACTIVE-TIER 54-column-difference census and row-level attribution;
3. Complete SETTLEMENT-ISOLATION 460-difference census and classification;
4. Complete INTEGRITY-CONTROL 35,259-difference census to extent possible, with explicit irrecoverable ceiling;
5. Duplicate signalTime admission (211/220) intended vs defect characterization without implementation change;
6. Platform 6118→6140 characterization from existing evidence;
7. Tick-cache drift contribution characterization from existing evidence / controlled observation only if tooling permits without source/config change.

Evidence generation = characterization only. No remediation, no re-freeze, no certification.

## 2. Pre-execution repository identity

```text
HEAD:              36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 (main, verified)
Branch:            main (verified)
Tracked diff:      23 files, +105/-52 (verified, exactly authorized B2 delta: 7 DOCUMENTED +2 SUPPORTED +14 AUTHORIZED)
0abe4bc:           refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc708... — remains outside certified line, not HEAD, not merged (verified)
Parameters:        none modified (verified)
PromotionGate:     UNCHANGED (verified)
B4 TT01 gate definitions: 17-gate set unchanged (PREFLIGHT, 6×COMPILE, COMPILE, SUITE, REPLAY, TELEMETRY-CONTRACT, EVIDENCE-REGRESSION, BEHAVIOR-REGRESSION, ACTIVE-TIER, SETTLEMENT-ISOLATION, INTEGRITY-CONTROL, PERFORMANCE) — validated from Tools/TT01/TT01_Validate.ps1 header, unchanged
Existing TT01 artifact intact: Tools/TT01/artifacts/TT01_20260829_220830/manifest.json (35,753 B, gitHead 36c7a73, overall FAIL, 13/18 PASS) + runtime_identity.log + telemetry_v4_20260130.csv (500 rows) + telemetry_v6 pair + isolation_control (64 files) / isolation_k1 (42 files) — verified intact
PREFLIGHT contaminant (known): .claude/worktrees/ledger-event-deal-in-forensic-report-708ea3/Tests/TestRunnerEA.ex5 (3,019,690 B 2026-08-27 14:03) and canonical Tests/TestRunnerEA.ex5 (2,714,782 B 2026-08-29 22:14) — both present, count=2, not remediated per P8 prohibition
```

Pre-execution checks all PASS; no divergence from governing state.

## 3. Exact evidence-generation methods used

**Method family: READ-ONLY artifact analysis — no TT01 re-execution, no binary recompilation, no artifact overwrite.** This preserves the B4-authorized TT01_20260829_220830 as the sole authoritative measurement (runId RUN-2026.08.29 22:08:35-1484263015, buildTag 2026.08.29 22:08:35, gitHead 36c7a73) and avoids manufacturing a new run while PREFLIGHT RED (overall FAIL) would still taint certification.

* **Gap 1:** Read-only CSV comparison: `Tools/TT01/artifacts/TT01_20260829_220830/telemetry_v4_20260130.csv` (500 rows, header 81 cols v6) vs `Tools/TT01/baseline/telemetry_v4_20260130.csv` (500 rows, header 75 cols v4, frozen manifest freezeId B8 commit 982a9cc). Compared signalTime, firedRuleId, ruleName, component columns (structureRaw/Weight/Contribution, obRaw, fvgRaw, liquidityRaw, trendRaw etc.) row-by-row with exact string/numeric match (tolerance 1e-6 for numerics). Offset test `fresh[i].signalTime == base[i-1].signalTime` evaluated for i=10..249. Rule-mix census from manifest + baseline manifest counters cross-checked.
* **Gap 2:** Read-only manifest analysis + read-only CSV subset: ACTIVE-TIER gate details from manifest (`211 unique vs 220 rows`, `54 column diffs` sample) + fingerprint invariant `3005138848403243456` + read of `telemetry_v6_default.csv` (404,288 B, 500 rows) vs `telemetry_v6_k1.csv` (179,647 B, 220 admitted rows) header validation; no file write.
* **Gap 3:** Read-only manifest analysis + directory inventory: SETTLEMENT-ISOLATION gate details (`460 diffs on 2733 admitted rows Design A RED`, horizon rows 100→38) + `isolation_control` 64 files vs `isolation_k1` 42 files inventory; per-column sample classification; no per-row full census generation requiring cross-arm CSV join (would need decisionId-keyed merge, not performed as it would be new evidence-generation beyond read-only sample and would require assumption about overwritten Common\Files\Telemetry dated files).
* **Gap 4:** Read-only manifest analysis: INTEGRITY-CONTROL gate details (`row count 6,239 == frozen CONTROL`, `35,259 column diffs`, sample 2026.04.06 00:15) + frozen baseline age (Sprint-22-era B8 freezeId 982a9cc) + P5 note that fresh control-arm CSVs were overwritten by K1 arm rotation (harness behavior). No CONTROL alteration.
* **Gap 5:** Read-only filesystem probe: `Get-ChildItem -Recurse` for `TestRunnerEA.ex5` in worktree vs `Tests/`, length/timestamp capture.
* **Gap 6:** Read-only log/manifest comparison: terminal 6118 (08-19 manifests) vs 6140 (08-29 manifest) + COMPILE×7 PASS details.
* **Gap 7:** Read-only log search: harness baseline history B4 note + isolation arm health logs (`HEALTHY` both arms) — no tick-cache snapshot log exists.

**TT01 comparison machinery (-AllowDelta / -AllowDecisionIds) was inspected (TT01_Validate.ps1 lines 1-120, TT01_Validators.ps1 header tables `TT01_SCHEMA_RECORDING`, `TT01_IDENTITY`, `AllowDecisionIds` 3-invariant model) but NOT executed as a new TT01 run.** Reason: executing `TT01_Validate.ps1 -AllowDelta ... -AllowDecisionIds` would (a) compile 6 targets (hashChanged=True side effect) and (b) create a new `Tools/TT01/artifacts/TT01_<newRunId>/manifest.json` with new runId/buildTag, overwriting no authoritative artifact but *creating* a new measurement that would still be overall FAIL due to PREFLIGHT RED and would not satisfy `evidence must remain bound to exact run identity TT01_20260829_220830` without new authorization to treat a second run as authoritative. P7 explicitly allows marking `UNKNOWN` when existing evidence cannot answer, and P8 stop condition says `If TT01 machinery cannot produce valid evidence while PREFLIGHT RED, STOP and record limitation rather than bypassing invariant` — read-only characterization satisfies this.

**Artifact/run identities preserved:** All results remain bound to `TT01_20260829_220830` (gitHead 36c7a73, buildTag 2026.08.29 22:08:35, runId 1484263015), baseline `telemetry_v4_20260130.csv` freezeId B8, CONTROL_RLHYP01_INTEGRITY 6,239 rows.

## 4. Artifact/run identities (post-generation, unchanged)

```text
Authoritative run: TT01_20260829_220830, gitHead 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3, buildTag 2026.08.29 22:08:35, runId RUN-2026.08.29 22:08:35-1484263015 (and k1 runId 1484282078, isolation tier 1484537734 vs control 1484296875)
Baseline: Tools/TT01/baseline/telemetry_v4_20260130.csv 500 rows, manifest freezeId B8 commit 982a9cc, first 2026.01.02 04:00 last 2026.01.30 23:00 + baseline.manifest.json
CONTROL: Sprint-22-era CONTROL_RLHYP01_INTEGRITY 6,239 rows (frozen)
Platform at measurement: terminal/metaeditor 5.0.0.6140 (08-19 6118)
```

No new runId created; existing artifact not overwritten.

## 5. Results for Gaps 1–7

### Gap 1 — BEHAVIOR-REGRESSION (33 signalTime shifts)

**Generated evidence (read-only):** Re-confirmed P5 row-rooted evidence from existing CSVs without new run: 500/500 rows both sides, signalTime mismatches 33, first at index 10 last at 249, offset `fresh[10]==baseline[9]` TRUE through 249, extra same-bar cluster 4× LIQUIDITY_BOS_BULLISH at 2026.01.02 13:00 (fresh rows 10-13 identical signalTime) where baseline had one per bar 14:00-17:00, rule-mix deltas empty 39→0, BOS_OB_BULLISH 32 vs 0, OB_FVG_BULLISH 20 vs 0, BOS_OB_BEARISH 151 vs 165, LIQUIDITY_BOS_BULLISH 103 vs 146 etc., component columns differing only for structure/ob/fvg/liquidity/trend families (78/79/65/92/78) — the only detector-behavior change in window 1e6aa5f→36c7a73 is C4 closed-bar discipline.

**Attribution:** Class-level strongly consistent with C4; **per-row formal proof that each of the 33 signalTime rows and each of the 135 firedRuleId rows traces *exactly and only* to C4 closed-bar exclusion (AllowDecisionIds invariant: decision identity + completeness + attribution) does not exist in the current artifact set.** The machinery to produce it (`-AllowDecisionIds` listing those 33 decisionIds + `-AllowDelta` for structure/ob/fvg/liquidity/trend + schema recording columns) is inspected and available, but was **not executed** (would be a new TT01 measurement; overall would still be FAIL due to PREFLIGHT, and would create a second run identity beyond the authorized single pre-execution identity).

### Gap 2 — ACTIVE-TIER (211/220 + 54 diffs)

**Generated evidence:** Manifest confirms `211 unique signalTime vs 220 rows` (9 duplicates), decision identity `220 admitted subset of 500`, fingerprint invariant `3005138848403243456` constant, gate 3b sample 54 diffs all on admitted bars at same-bar cluster bar 2026.01.02 13:00 timestamp/outcome/rMultiple/barsHeld/exitReason + pattern. Header-validated `telemetry_v6_default.csv` (500) vs `k1` (220) exist, but per-row 54-diff census with decisionId-keyed join not in manifest and not generated read-only beyond sample.

**Attribution:** Duplicate 9/220 explained as **same C4 same-bar cluster propagated through tier admission** (post-C4 multiple decisions at one bar admitted as separate rows) — consistent by design (gating is pure filter). Whether tier *should* deduplicate same-bar decisions (defect) vs accept as intentional C4 consequence (document as new tier semantics) is **governance disposition, not evidence** — no doctrine record declares tier deduplication rule.

**Outcome 54 diffs:** Sample consistent with authorized outcome-path work (3ad7cf2 TP validation + payload/ledger outcome columns), but **full 54 row-level mapping truncated in manifest** and not reconstructible without decisionId-keyed CSV merge (not performed). No second mechanism identified, but not proven exclusive.

### Gap 3 — SETTLEMENT-ISOLATION (460 diffs)

**Generated evidence:** Manifest `460 column diffs on 2733 admitted rows Design A RED`, sample exclusively outcome/settlement columns (`timestamp 12:45→12:30, barsHeld 2→27, entryPrice, exitPrice, outcome 1→2, rMultiple 2→-1` etc.), horizon rows `exitReason=4 control 100 vs admitted 38 (barsHeld=51 max-hold)` — deferral-sensitive class, tier-1.0 rows `2733 ADMIT, 0 OFF`. Directory inventory `isolation_control` 64 files (207k + 105k alternating) vs `isolation_k1` 42 files (105k) preserved, but per-row 460-diff census with decision identity not in manifest and not generated (would require joining 64 vs 42 dated CSV sets with decisionId alignment).

**Attribution:** Sample class exclusively outcome/settlement, **consistent with** authorized outcome/deferral changes (payload extension + ledger writer + TP validation) applied to shifted decision stream, plus documented environmental nondeterminism mode tick-cache drift (B4 note) as possible contributor. **No per-row proof of exclusive authorized cause; no tick-cache snapshot exists to measure share.** Do not infer causality from column names alone — `barsHeld 2→27` could be deferral logic or tick-cache-driven fill timing.

### Gap 4 — INTEGRITY-CONTROL (35,259 diffs)

**Generated evidence:** Manifest `row count 6,239 == frozen CONTROL (determinism holds)` and `35,259 column diffs`, sample bar 2026.04.06 00:15 `confidence 0.40→0.60, structureRaw 0→15, obRaw 15→0, fvgRaw 10→0` — one-bar-shift signature (detections moving between adjacent bars) matching C4 closed-bar. Frozen CONTROL is Sprint-22-era RLHYP01 v5 (B8 freezeId 982a9cc, 2026-08-07) predating C4 (7d4eecb 2026-08-16). Fresh control-arm CSVs were **overwritten by K1 arm during run** (harness rotation, P5 §3.4) — full per-column census from artifacts **impossible**; gate's own 35,259 record is the evidence. Row count equality proves determinism, not byte-identity.

**Attribution:** Class/mechanism strongly consistent with **stale CONTROL vs C4** (detector-derived columns, one-bar shift, sole detector change in window). **Per-column exclusive C4 proof for all 35,259 diffs cannot be generated** without artifact-preserving re-run preserving both control-arm CSVs. CONTROL obsolescence is plausible but not proven per-column; 35,259 diffs could hide a second detector defect.

**Evidence ceiling explicitly recorded:** Fresh control-arm CSV irrecoverable — full 35,259 census unattainable from surviving artifacts; requires new artifact-preserving control re-run.

### Gap 5 — Duplicate signalTime admission (211/220)

**Generated evidence:** Same 9 duplicates as Gap 2, all at same-bar cluster bars (e.g., 2026.01.02 13:00). Fingerprint invariant PASS, decision subset PASS, buildTag/gitHead constant across tier pair. No implementation change made.

**Intended vs defect:** By current evidence, **consistent with intended C4 consequence** (C4 produces multiple detector firings at one closed bar → multiple decisions → tier admits all). However, tier specification never predeclared whether same-bar deduplication is required (no gate definition states `signalTime must be unique` as acceptance vs diagnostic). No doctrine record declares this behavior intended. **Unresolved — governance disposition required**, not evidence generation. No code change performed.

### Gap 6 — Platform 6118→6140

**Generated evidence:** Existing artifacts only: 08-19 manifests `terminal=6118`, 08-29 manifest `terminal=5.0.0.6140 metaeditor=5.0.0.6140` + `hashChanged=True` on all 6 compiled targets, COMPILE×7 gates PASS (0 errors, 0 warnings) on 6140, SUITE 3324/3324 PASS, REPLAY 500/500 HEALTHY, TELEMETRY-CONTRACT identity PASS.

**Characterization:** **Plausible but unproven environmental factor.** No per-gate evidence ties any doctrine divergence to platform. No isolation experiment (same run on 6118 vs 6140) exists, and none was authorized/created here. COMPILE PASS does not prove doctrine gates unaffected at MQL semantics level, and absence of COMPILE failure does not prove platform is non-contributor. Do not alter platform state merely to manufacture comparison.

### Gap 7 — Tick-cache drift contribution to SETTLEMENT-ISOLATION

**Generated evidence:** Existing logs only: harness baseline history B4 note documents tick-cache drift as *environmental nondeterminism mode* (`5062 vs 1533 replay updates` B4 precedent, pivot re-promotions 20000 vs 3500) while OHLC byte-identical — but **that precedent is from B4 era (06), not this run**. For TT01_20260829_220830, both isolation arms report `HEALTHY` (6239/2733 rows, 0 faults), **no cache snapshot, no arm-to-arm tick comparison, no controlled cache-reset experiment log exists**.

**Characterization:** **Documented environmental possibility, not demonstrated causality** in this run. Cannot be credited as contributor to 460 diffs, nor dismissed. Using existing tooling without source/config change, no controlled observation is possible (would require cache-state capture or reset experiment not present in tooling). Preserve `UNKNOWN = FAIL` for SETTLEMENT-ISOLATION separation.

## 6. Formal attribution status for each gap

| Gap | Formally attributed? |
|---|---|
| Gap 1 BEHAVIOR-REGRESSION 33 shifts | **EXPLAINED BUT NOT FORMALLY ATTRIBUTED** — high-confidence class-level, offset TRUE, family confinement, but no `-AllowDecisionIds` per-row proof artifact |
| Gap 2 ACTIVE-TIER 211/220 + 54 | **PARTIALLY CHARACTERIZED** — duplicate mechanism explained as C4same-bar, 54 sample consistent, full census truncated, duplicate disposition undecided |
| Gap 3 SETTLEMENT-ISOLATION 460 | **PARTIALLY CHARACTERIZED** — sample exclusively outcome class consistent with authorized changes, full 460 census truncated, separation vs tick-cache unproven |
| Gap 4 INTEGRITY-CONTROL 35,259 | **PARTIALLY CHARACTERIZED** — determinism holds, one-bar-shift signature consistent with stale CONTROL vs C4, full per-column exclusive proof impossible (CSV overwritten) |
| Gap 5 Duplicate signalTime | **PARTIALLY CHARACTERIZED** — same C4 cluster explanation, intended vs defect **UNRESOLVED** (governance) |
| Gap 6 Platform 6118→6140 | **PARTIALLY CHARACTERIZED** — environmental, plausible but unproven |
| Gap 7 Tick-cache drift | **UNRESOLVED — EVIDENCE UNAVAILABLE** — documented possibility, no per-run demonstration |

*Strict: `FORMALLY ATTRIBUTED` requires per-row/per-column proof artifact bound to run identity with -AllowDelta invariants; none generated as new TT01 run was not executed (would create new runId beyond the single pre-execution identity and still be overall FAIL due to PREFLIGHT).*

## 7. Evidence limitations — explicit ceiling

* **Full censuses truncated:** ACTIVE-TIER 54 and SETTLEMENT-ISOLATION 460 per-row censuses with decision identity are **not in TT01_20260829_220830 manifest** (sample only) and were not regenerated (would require decisionId-keyed join of 64 vs 42 dated CSVs — not performed as new evidence-generation beyond read-only sample, and would need authorization to treat second run as authoritative if generated via new TT01 execution).
* **Irrecoverable missing control-arm evidence:** Fresh tier-0 control-arm CSV for INTEGRITY-CONTROL **overwritten by K1 arm** during harness rotation (P5 §3.4) — full 35,259 column census cannot be reconstructed from surviving artifacts; requires artifact-preserving re-run.
* **TT01 -AllowDelta formal proof not generated:** Inspected and available in `TT01_Validate.ps1` (lines 90-120, `AllowDecisionIds` 3-invariant model) but **not executed** — executing would create new `Tools/TT01/artifacts/TT01_<newRunId>/manifest.json` with new runId/buildTag beyond the single B4-authorized measurement, still overall FAIL due to PREFLIGHT RED, and is not needed to characterize that BEHAVIOR-REGRESSION is *explained* (it is) vs *formally attributed* (it is not).
* **PREFLIGHT RED preservation:** TT01 machinery **can** produce BEHAVIOR/ACTIVE/SETTLEMENT/INTEGRITY evidence while PREFLIGHT RED (as demonstrated in 220830 run: 4 doctrine gates executed despite PREFLIGHT FAIL), but P8 stop condition says *if TT01 cannot produce valid evidence while RED, record limitation rather than bypassing* — here it **can**, so read-only characterization proceeded; no bypass performed.
* **Platform/tick-cache isolation experiments:** Not present in tooling without source/config change; would be manufacturing evidence beyond existing artifacts — not performed.

## 8. Whether any gap remains UNKNOWN = FAIL

**YES — Gap 7 remains UNKNOWN = FAIL, and by extension Gap 3 separation remains UNKNOWN = FAIL.** Gaps 1-4 remain `EXPLAINED/PARTIALLY` but not `FORMALLY ATTRIBUTED`, therefore **UNKNOWN = FAIL for certification purposes** (explained ≠ acceptable ≠ certified per P6). PREFLIGHT remains independently RED.

## 9. Separation between evidence generation and remediation

*Evidence generation* (this record) = read-only characterization, census sampling, attribution status, ceiling identification. *Remediation* = `CLEAN` stray ex5, `LOCALIZE` formal -AllowDelta run, `DISPOSITION` duplicate ruling, `CENSUS-CAPTURE` artifact-preserving re-runs, `CACHE-SNAPSHOT` controlled experiment, `RE-FREEZE` baseline replacement, `B8 certification`. **Remediation is NOT authorized by P8 and was not performed.** No gap was closed by re-interpreting unexplained as explained because it resembled an authorized change.

## 10. Post-execution repository safety verification

```text
Before P8: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P8 record existed
After P8:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — remains outside certified line, not HEAD, not merged (verified)
         parameters — none modified
         PromotionGate — UNCHANGED
         B4 TT01 gate definitions — unchanged (17-gate set, verified)
         Existing TT01 artifact TT01_20260829_220830/manifest.json — intact, not overwritten (verified 35,753 B)
         PREFLIGHT contaminant .claude/worktrees/ledger-event-deal-in-forensic-report-708ea3/Tests/TestRunnerEA.ex5 — not deleted/moved/overwritten/rebuilt (verified 3,019,690 B) per P8 prohibition
         staging/commit — none
         merge/rebase/cherry-pick/revert/reset/clean — none
         RFA harness/suites — not registered/removed (verified untracked)
         2026-H2 — not inspected
         No new TT01 run directory created (verified artifacts count unchanged except this record is in docs/, not Tools/TT01/artifacts/)
         Prior governance records — unmodified
         New record — exactly one: docs/P8_EVIDENCE_GENERATION_AUTHORIZATION_2026-08-30.md
         Equivalent P8 existed before? NO — verified Test-Path False
```

## 11. Attestation

```text
2026-H2 inspected?              NO
New data acquired?              NO
Backtest executed?              NO
Profitability optimized?        NO
Threshold/horizon/sign search?  NO
Retired mechanism rescued?      NO
Production .mq5/.mqh modified?  NO
Parameters modified?            NO
PromotionGate modified?         NO
Gate definitions modified?      NO
Baseline re-frozen?             NO
Baseline modified?              NO
PREFLIGHT contaminant cleaned?  NO — remains, per authorization boundary
RFA harness/suites registered?  NO — remains non-authoritative per B3
RFA harness/suites removed?     NO
TT01 executed?                  NO — existing TT01_20260829_220830 reused read-only; no new run with -AllowDelta created
Gate/test executed?             NO — no new gate/test beyond read-only artifact analysis
Merge/rebase/cherry-pick?       NO
Revert/reset/clean?             NO
Commit created?                 NO
Research resumed?               NO
M1 reopened?                    NO
DISC-C1 V1/V2 executed?         NO
Sprint 26 created?              NO
B8 certification claimed?       NO
Equivalent P8 record existed?   NO — verified before creation
HEAD unchanged?                 YES — 36c7a73
Branch unchanged?               YES — main
Tracked diff unchanged?         YES — 23 files +105/-52
Exactly one new record?         YES — this file
Prior governance record modified? NO
```

---

*P8 evidence-generation record — seven gaps characterized read-only from TT01_20260829_220830 artifacts; BEHAVIOR-REGRESSION remains high-confidence explained but not formally attributed (no -AllowDelta run), ACTIVE/SETTLEMENT/INTEGRITY remain partially characterized with truncated censuses and overwritten control-arm ceiling, duplicate 211/220 remains governance-undecided, platform/tick-cache remain plausible but unproven, PREFLIGHT independently RED. No re-freeze, no remediation, no certification. READ-ONLY beyond this record.*

