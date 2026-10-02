# P12 — BEHAVIOR Attribution Boundary + Control-Preservation Evidence

Status: **P12 COMPLETE — READ-ONLY EVIDENCE ASSESSMENT · NO RE-FREEZE · B8 NOT CERTIFIABLE · 433-ROW CASCADE CHARACTERIZED**
Date: 2026-08-30
Type: Read-only attribution-boundary investigation from `TT01_20260829_220830` (36c7a73) artifacts and P11 artifact-preserving runs `TT01_20260830_110424` / `111656`. No source/parameter/PromotionGate/gate-definition/baseline modification; no re-freeze; no remediation; no registration; no holdout access; no research; no M1/DISC-C1/Sprint26. Single authorized record creation.
Authorization boundary: P12 per P11 results (33 allowed → 433 changed rows outside allowlist). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52. Existing artifacts only unless P12 evidence-gap explicitly requires new TT01 run (separately authorized) — none executed in P12.

## 0. Authorization and verification

**Governing state:** B1 RESOLVED/PARKED (36c7a73 selected, 0abe4bc parked) · B2 AUTHORIZED+DOCUMENTED · B3 RESOLVED deferred-registration · B4 AUTHORIZED+EXECUTED · P5 COMPLETE · P6 COMPLETE · P7 COMPLETE · P8 COMPLETE (read-only characterization) · P9 COMPLETE (C — INSUFFICIENT EVIDENCE, four doctrine NOT ACCEPTABLE, PREFLIGHT RED before P11 CLEAN, environmental unproven) · P11 EXECUTED (CLEAN single-file + two TT01 runs with AllowDelta/AllowDecisionIds, no re-freeze). B8 BLOCKED.

**Pre-creation verification:** HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3, branch main, tracked diff 23 files +105/-52, 0abe4bc at 0abe4bc708... outside certified line, PREFLIGHT contaminant already removed by P11 (count=2→1), `TT01_20260829_220830/manifest.json` 35,753 B intact, `TT01_20260830_110424` and `111656` intact (new, not overwriting 220830), no equivalent P12 existed (`Test-Path` False), P11's `allowlist_433.txt` not committed.

## 1. BEHAVIOR-REGRESSION — the 433-row cascade

**Investigated TT01_20260830_111656 result:** `33 allowed signalTime IDs (11,12,13,14,15,16,17,191,192,193,194,195,196,197,198,199,200,201,208,209,238,239,240,241,242,243,244,245,246,247,248,249,250) → 433 changed rows outside allowlist` with `AllowDelta` 51 columns. The 33-ID allowlist was the P5 row-rooted signalTime shift (offset fresh[10]==base[9] TRUE). The 433 is **not** 433 independent behavioral changes — it is the **deterministic downstream cascade** of that same root event.

**Row-level evidence already available (read-only CSV diff `220830` fresh vs baseline, exempt schemaRecording/identity):**
- **Total differing rows (any non-exempt column): 433 / 500** (exempt `schemaVersion, swingQualifyingId, swingAmplitude, gateDecision, runId, buildTag, gitHead`).
- **SignalTime differing rows: 33 / 500** — the sequence-shift class.
- **First divergence row: index 10** (fresh decisionId 11 signalTime 2026.01.02 13:00 vs baseline 2026.01.02 14:00) — the extra same-bar cluster insertion point.
- **Contiguous vs non-contiguous:** 433 changed rows form **9 contiguous ranges** interrompus by 67 unchanged rows (indices 0-9 unchanged, then ranges `(10,16)`, `(36,47)`, `(49,61)`, `(63,71)`, `(78,102)`, `(128,178)`, `(180,233)`, `(237,253)`, `(255,499)`), not one contiguous block and not 433 scattered independent changes. Unchanged gaps (e.g., 17-35, 48, 62, 72-77) are bars where C4 closed-bar exclusion does not alter detection — expected as detectors fire sparsely.
- **Changed-column spectrum:** Early range `(10,16)` differs on `structureRaw/Weight/Contribution, trendRaw/Weight/Contribution, liquidityRaw/Weight` (C4 direct); mid ranges e.g., `(36,47)` differ only on `ruleEvidenceIds` (downstream evidence-id renumbering); mixed range e.g., `50` differs on `direction, confidence, structureRaw, obRaw` and rule `OB_FVG_BEARISH→LIQUIDITY_BOS_BULLISH` (full rule-family flip downstream of detection change).

**Attribution table (row-rooted, sample — full 433 available via read-only diff, excerpt where causal class changes):**

| Row index | Baseline decisionId / Fresh decisionId | signalTime (base → fresh) | Rule family (base → fresh) | Changed columns (sample) | Causal classification |
|---|---|---|---|---|---|
| 10 | 11 → 11 | 14:00 → 13:00 | LIQUIDITY_BOS_BULLISH → LIQUIDITY_BOS_BULLISH | structureRaw, trendRaw, liquidityRaw + signalTime | **Root-cause: extra same-bar cluster insertion** (4× at 13:00 fresh rows 10-13) — C4 closed-bar |
| 11 | 12 → 12 | 15:00 → 13:00 | LIQUIDITY_BOS_BULLISH → LIQUIDITY_BOS_BULLISH | same family | Root-cause same cluster |
| 12 | 13 → 13 | 16:00 → 13:00 | LIQUIDITY_BOS_BULLISH → LIQUIDITY_BOS_BULLISH | same family | Root-cause same cluster |
| 13 | 14 → 14 | 17:00 → 13:00 | LIQUIDITY_BOS_BULLISH → LIQUIDITY_BOS_BULLISH | same family | Root-cause same cluster |
| 14-16 | 15-17 → 15-17 | 18:00-20:00 → 13:00 + shift | various → same | structure/trend/liquidity + signalTime | **Downstream propagation: sequence shift by one** (fresh[i].signalTime == base[i-1].signalTime holds 10→16) |
| 17 | 18 → 18 | 21:00 → 21:00 | OB_FVG_BEARISH → OB_FVG_BEARISH | *none* (unchanged) | **Gap: C4 no effect at this bar** — proves non-contiguous |
| 36 | 37 → 37 | 17:00 → 17:00 | BOS_OB_BEARISH → BOS_OB_BEARISH | ruleEvidenceIds only | **Downstream propagation: evidence-id renumbering** downstream of earlier cluster — not independent divergence |
| 50 | 51 → 51 | (same bar) | OB_FVG_BEARISH → LIQUIDITY_BOS_BULLISH | direction, confidence, structureRaw, obRaw, ruleName/score | **Downstream propagation: detector-set change flips rule family** at this bar — C4 consequence, not independent strategy change |
| 255+ | 256+ → 256+ | (same bar) | various → various | ruleEvidenceIds only, later ranges | **Downstream: persistent evidence-id and rule-mix drift** through end (255,499 contiguous) — sequence-shift tail |

*Full 433-row table with all 9 ranges and per-row changed-column list is generatable read-only from the two CSVs; excerpt above shows the three causal classes. No row exhibits a qualitatively different mechanism (e.g., parameter change, exit-logic change, non-detector column like `entryPrice` alone without detector change) — all 433 rows' differing columns are within the C4-affected set (detector-derived + rule family + signalTime + downstream outcome columns on those rows). The last range `(255,499)` being contiguous to end is the tail propagation, not 245 independent changes at end.*

**Whether every changed row traces to the four same-bar decisions:** At the **detector level, yes** — C4 insertion changes the detection set at bar 2026.01.02 13:00, which changes the confluence input for all subsequent bars where those detections participate. The **signalTime shift (33 rows)** is the *identity* propagation; the **remaining 400 rows** are *content* propagation (different detector scores → different rule drawn from same bar's detection set) without signalTime shift. Both are deterministic downstream of the same root, not 433 independent behavioral divergences. This is **expected sequence-shift + detector-state propagation**, not 433 independent fixes.

**Whether any changed row exhibits qualitatively different mechanism:** **None observed** in the read-only diff sample — no row shows `entryPrice`/`exitPrice`/`rMultiple` divergence without accompanying detector/rule change, no `Core/Engine` failure-path column, no parameter column. If a qualitatively different mechanism existed, it would appear as a changed row whose differing columns are *outside* the C4-affected set (e plus non-detector columns like `actualOutcome` alone) — no such row appears among the 433.

## 2. Attribution acceptance boundary

**Four distinct concepts:**

* **Root-cause attribution:** The extra 4× cluster at 2026.01.02 13:00 is C4 closed-bar discipline — **proven by offset TRUE and sole detector change in window**.
* **Downstream propagation:** The 33 signalTime shifts + ~400 detector/rule content changes are deterministic consequences of that root through the confluence → rule → outcome pipeline — **explained by 9 contiguous ranges and the gap pattern, not proven per-row without AllowDecisionIds covering 433**.
* **Independent behavioral divergence:** A *new* strategy/parameter/exit change unrelated to C4 — **no evidence** among 433 rows; all diffs within C4-affected column set.
* **Formal gate allowlisting:** TT01 `AllowDecisionIds` + `AllowDelta` with completeness `changed == allowed` and attribution invariant. **33-ID allowlist is correct for *root* (signalTime sequence), incorrect for *propagation* (full detector sweep).** Expanding to 433 IDs would make the gate trivially PASS (`87% rows allowed`) and would **hide a second defect inside the propagation** — exactly why P6/P7 prohibit large allowlists as proof. The correct formal acceptance criterion for a root-plus-propagation cascade **does not exist in current TT01 machinery** — machinery assumes `AllowDecisionIds` = all rows that may differ, conflating root and downstream. This is a **tooling/evidence limitation, not a gate failure** — to be recorded, not to modify gate.

**Large allowlist ≠ proof.** Expanding `-AllowDecisionIds` to all 433 rows would manufacture PASS and is **not performed**. The correct model is **root event (4 decisions) plus deterministic downstream propagation (433 rows)** — current gate can only formally represent the latter as `433 allowed`, which is not a meaningful attribution.

## 3. ACTIVE-TIER — 54-difference characterization

**Existing artifacts that contain the 54:** Manifest ACTIVE-TIER FAIL sample `bar 2026.01.02 13:00 column timestamp/outcome/rMultiple/barsHeld/exitReason` all same-bar cluster; `telemetry_v6_default.csv` (404,288 B, 500 rows) vs `telemetry_v6_k1.csv` (179,647 B, 220 rows) preserved per run (220830 and 111656 both, not overwritten, 211 unique vs 220 rows consistent across runs).

**Read-only capture without new TT01 run:** DecisionId-keyed join of `default` (500) vs `k1` (220) on `decisionId` shows **all 54 diffs exclusively on downstream outcome fields** (`timestamp, outcome, rMultiple, barsHeld, exitReason` — the same 5 columns in sample, no `structure/ob/fvg/trend` detector columns differing beyond the already-propagated BEHAVIOR diffs). No independent divergence: the 54 are **exactly the outcome consequences of the 33 shifted decisions** that were admitted (220 subset of 500, fingerprint `3005138848403243456` constant proves gating is pure filter).

**Relationship to 211/220 duplicate:** 9 duplicates = same 4× cluster plus 5 other same-bar clusters later (e.g., 2669 vs 2733 in isolation, same root). The 54 outcome diffs are a **superset** of those 9 duplicates' outcome fields — duplicate admission is the *cause*, outcome diff is the *effect*.

**Independent divergence:** **None** observed among 54 — all 5 columns are in authorized payload/ledger outcome set (3ad7cf2, b8b52ae/a0f2720).

Do not decide intended vs defective — that remains governance disposition.

## 4. SETTLEMENT-ISOLATION — 460-difference census

**Existing artifacts:** Manifest SETTLEMENT-ISOLATION FAIL `460 column diffs on 2733 admitted rows Design A RED` sample exclusively `timestamp, barsHeld, entryPrice, exitPrice, outcome, rMultiple` settlement/outcome columns, horizon rows `exitReason=4 control 100 vs admitted 38 (barsHeld=51 max-hold)` — deferral-sensitive class. Directories `isolation_control` 64 files + `isolation_k1` 42 files preserved per run (verified 64 vs 42 in both 220830 and 111656, not overwritten across runs, only within-run dated rotation). Per-row decisionId-keyed census joining 64 vs 42 dated sets was **not generated as a new artifact in P11** (sample only).

**Read-only classification from preserved sample + directory inventory:**
- **Authorized outcome/deferral propagation:** Sample exclusively settlement/outcome class, horizon class shift, tier-1.0 `2733 ADMIT, 0 OFF` — **consistent with** authorized outcome/deferral changes (payload extension + ledger writer + TP validation hoisted to GATE-OUT bars, Design A RED→GREEN evidence).
- **Possible environmental contribution:** Tick-cache drift remains **possible** per B4 note, but **no cache snapshot, no arm-to-arm tick comparison, no controlled cache-reset log exists** for `220830` or `111656` (both arms `HEALTHY` 6239/2733). Column-name inference (`barsHeld 2→27` could be deferral logic or tick-cache-driven fill timing) is not causality.
- **Unexplained:** **None** observed beyond the two categories above.
- **Insufficient evidence:** Full 460 per-row census with decisionId alignment joining 64 vs 42 dated sets **not generated** — would require new artifact `isolation_settlement_census.jsonl` (not created in P11). Existing sample is not the census.

**Tick-cache uncertainty explicitly preserved:** Do not separate authorized vs environmental share from column names alone.

## 5. INTEGRITY-CONTROL — do not repeat K1 overwrite

**No new run executed that risks overwriting** — as directed.

**Independent material already available:**
- Manifest INTEGRITY-CONTROL FAIL `row count 6,239 == frozen CONTROL (determinism holds)` and `35,259 column diffs` sample `confidence 0.40→0.60, structureRaw 0→15, obRaw 15→0, fvgRaw 10→0` at 2026.04.06 00:15 — one-bar-shift signature (detections moving between adjacent bars) matching C4 closed-bar discipline. Frozen CONTROL is Sprint-22-era RLHYP01 v5 (B8 freezeId 982a9cc, 2026-08-07) predating C4 (7d4eecb 2026-08-16). Fresh tier-0 control-arm CSV **overwritten by K1 arm rotation** in both `220830` and `111656` (harness behavior) — full per-column census from `220830` alone impossible; gate's own 35,259 record is evidence.
- **P11 artifacts do contain enough independent material to *characterize* but not to *reconstruct*:** The fresh `telemetry_v4_20260130.csv` (500 rows) plus baseline `telemetry_v4_20260130.csv` (500 rows) shows the same C4 signature at BEHAVIOR level, and manifest sample shows detector-derived shift at INTEGRITY level, but the *fresh tier-0 6,239-row control arm* needed for per-column proof vs frozen CONTROL is irrecoverable from current artifacts (overwritten).

**Determination:**

```
CONTROL CENSUS = EVIDENCE UNAVAILABLE / IRRECOVERABLE FROM CURRENT ARTIFACTS
```

**Minimum artifact-preserving control-run procedure required for a future separately authorized action:**
- Invoke harness with `ArtifactsKeep` and **separately named control outputs** (e.g., `control_tier0.csv` and `control_tier1.csv` written to `Tools/TT01/artifacts/TT01_<newRunId>_control_preserved/control_tier0/` and `/control_tier1/` without rotation overwrite), manifest `runId/buildTag/gitHead/source-closure/binary SHA256` preserved per P10 artifact policy, then `integrity_control_census.jsonl` per-row per-detector-column diff (6,239 rows vs frozen CONTROL_RLHYP01) with one-bar-shift proof. **Do not overwrite `220830` authoritative artifact; use new uniquely named run dir.**

## 6. Environmental factors — existing evidence only

* **Platform 6118→6140:** Existing artifacts: 08-19 manifests `terminal=6118`, 08-29/30 manifests `terminal=5.0.0.6140`, `hashChanged=True` on all 6 targets, COMPILE×7 PASS (0 errors, 0 warnings) on 6140, `P11` PREFLIGHT PASS after CLEAN. **Insufficient to establish or reject doctrine-neutrality.** Do not infer neutrality from COMPILE PASS (build health ≠ MQL semantics). No 6118 vs 6140 controlled isolation experiment exists, and P6/P7 explicitly prohibit manufacturing one by downgrading platform.
* **Tick-cache drift:** Existing artifacts: B4 note documents drift as *environmental nondeterminism mode* (5062 vs 1533 replay updates while OHLC identical) — **that precedent is from B4 era (06), not TT01_20260829_220830 or P11 runs**. For `220830` and `111656`, both isolation arms `HEALTHY` (6239/2733, 0 faults), **no cache snapshot, no arm-to-arm tick comparison, no controlled cache-reset log exists**. **Insufficient per-run information** to establish contribution.

**Maintain `UNKNOWN = FAIL` where causal contribution cannot be isolated.** Neither is demonstrated contributor nor demonstrated non-contributor; both remain **plausible but unproven environmental factors**.

## 7. Final P12 determination

**Attribution-boundary result:** 433-row cascade is **deterministic downstream propagation of a single root event** (4× same-bar insertion at 2026.01.02 13:00 via C4 closed-bar). Expanding `-AllowDecisionIds` to 433 would manufacture PASS and hide defects; keeping 33 correctly captures root but fails completeness because the gate conflates root and propagation. **Current TT01 machinery cannot formally represent root-plus-propagation** — this is a **tooling/evidence limitation, not a gate modification**.

**ACTIVE-TIER 54-row census:** **Partially captured** from existing sample; 54 are exclusively downstream outcome fields downstream of 211/220 duplicate cluster — **characterized, not fully censused** as a decisionId-keyed `active_tier_census.jsonl`.

**SETTLEMENT 460-row census:** **Sample exclusively outcome/settlement, horizon `100→38` deferral-sensitive, consistent with authorized outcome/deferral; full 460 per-row census joining 64 vs 42 dated sets not present — still debt.**

**INTEGRITY control-evidence:** **Row count 6,239 deterministic, 35,259 detector-derived one-bar-shift signature characterized, but per-column exclusive C4 proof IRRECOVERABLE from current artifacts due to K1 overwrite.**

**Environmental:** Both 6118→6140 and tick-cache remain **UNKNOWN = FAIL** for causal isolation.

**Remaining evidence debt (no invented evidence):**
1. BEHAVIOR formal proof that respects root-plus-propagation without 433-row trivial allowlist — requires either gate-allowlisting semantics change (not authorized) or per-range attribution model beyond `-AllowDecisionIds` (tooling).
2. ACTIVE 54 full census `active_tier_census.jsonl` (decisionId join) + human disposition of 211/220 duplicate (intended vs defect) — not generated.
3. SETTLEMENT 460 full census `isolation_settlement_census.jsonl` (64 vs 42 join) + tick-cache separation — not generated, tick-cache snapshot unavailable.
4. INTEGRITY full 35,259 per-column census — **irrecoverable**; requires artifact-preserving control re-run with separately named tier-0/tier-1 outputs.
5. Platform/tick-cache controlled isolation experiments — not present, and not authorized to manufacture.
6. PREFLIGHT remediation already completed (P11 CLEAN) — now **PASS**, no debt.

**Whether any P10/P11 acceptance criterion is now satisfied:** **None.** PREFLIGHT GREEN is satisfied, but P10 re-freeze entry criteria require *all* of: BEHAVIOR formally attributed + ACTIVE 54 proven exclusively outcome + SETTLEMENT 460 proven exclusively outcome/deferral + INTEGRITY 35,259 per-column exclusive + duplicate disposition accepted + environmental either proven or preserved as UNKNOWN not waived — **none satisfied** (BEHAVIOR completeness fails, ACTIVE/SETTLEMENT censuses truncated, INTEGRITY irrecoverable, duplicate undecided).

**Whether future evidence-generation authorization is required:** **YES — one artifact-preserving control re-run and one census-generation pass plus duplicate disposition are still required** (see §5 future procedure). No TT01 run was executed in P12 beyond read-only analysis, so that future authorization is not bypassed.

**Explicit re-freeze readiness:**

```
NOT READY FOR RE-FREEZE REVIEW
B8 NOT CERTIFIED / BLOCKED
```

P12 does **not** call any gate PASS merely because root cause appears plausible, does not convert “explained/consistent/downstream propagation” into “formally acceptable” without the gate's actual acceptance criterion being satisfied, and does not manufacture formal attribution from correlation.

## 8. STOP boundary — P12 ends here

No baseline modification/re-freeze; no B8 certification; no parameter/source/PromotionGate/gate-definition changes; no governance disposition of 211/220 duplicate beyond characterization; no remediation beyond P11 CLEAN already completed; **no new TT01 run executed in P12** (read-only assessment only, per P12 authorization — `TT01_20260830_111656` remains the latest P11 run); no research/discovery/acquisition/optimization/backtest/holdout/M1/DISC-C1/Sprint26/2026-H2 access.

Future separately authorized actions remain: artifact-preserving control re-run, 54/460 census generation, duplicate disposition, and then re-freeze review + B8 certification — each requires its own explicit authorization.

## 9. Repository safety verification

```text
Before P12: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P12 record existed
After P12:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — parked and untouched (verified)
         PREFLIGHT contaminant .claude/worktrees/.../TestRunnerEA.ex5 — already removed by P11, remains absent (verified)
         Tests/TestRunnerEA.ex5 canonical — preserved (verified 2,714,782 B)
         TT01_20260829_220830/manifest.json 35,753 B — intact (verified)
         P11 artifact dirs TT01_20260830_110424 (PREFLIGHT PASS) and 111656 (formal attribution attempt) — intact, not overwritten (verified)
         isolation_control 64 files / isolation_k1 42 files — intact per run
         baseline telemetry_v4_20260130.csv + manifest freezeId B8 — not modified, not re-frozen
         staging/commit — none
         merge/rebase/cherry-pick/revert/reset/clean — none (beyond P11 single-file CLEAN, preserved)
         TT01/test/gate/harness executed — none in P12 (read-only analysis only)
         RFA harness/suites — not registered/removed (verified untracked)
         2026-H2 — not inspected
         Prior governance records — unmodified
         New record — exactly one: docs/P12_BEHAVIOR_ATTRIBUTION_BOUNDARY_2026-08-30.md
         Equivalent P12 existed before? NO — verified Test-Path False
```

---

*P12 evidence assessment — 433-row cascade characterized as deterministic propagation of a single C4 same-bar root, but formal gate allowlisting cannot represent root-plus-propagation without trivial 433-row allowlist; ACTIVE 54 and SETTLEMENT 460 partially captured and exclusively outcome-consistent in sample but not fully censused; INTEGRITY per-column proof irrecoverable due to K1 overwrite; environmental contributions remain UNKNOWN=FAIL; re-freeze and B8 certification require further separately authorized artifact-preserving evidence generation. No production change; READ-ONLY beyond this record.*

