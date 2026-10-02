# P15 — Root-Cascade Proof Capability Specification

Status: **P15 COMPLETE — SPECIFICATION ONLY · NO IMPLEMENTATION · NO TT01 EXECUTION · NO RE-FREEZE · B8 NOT CERTIFIED**
Date: 2026-08-30
Type: Governance specification for the minimum read-only evidence capability required to formally prove the 33-root → 433-row deterministic BEHAVIOR cascade without manufacturing an 87% allowlist. No source/parameter/PromotionGate/gate-definition/baseline/artifact/harness modification; no re-freeze; no certification; no holdout/research/M1/DISC-C1/Sprint26 access. Single governance record.
Authorization boundary: P15 per P14 O2 (AUTHORIZE ATTRIBUTION TOOLING ENHANCEMENT — specification only). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52. Existing artifacts `TT01_20260829_220830` (overall FAIL) and `TT01_20260831_135145` (artifact-preserving, PREFLIGHT PASS) remain authoritative baselines for specification.

## 0. Governing context

**P14 determination (governing):** BEHAVIOR 33 signalTime IDs `11,12,13,14,15,16,17,191,192,193,194,195,196,197,198,199,200,201,208,209,238,239,240,241,242,243,244,245,246,247,248,249,250` with first divergence index 10, **4× LIQUIDITY_BOS_BULLISH same-bar cluster at 2026.01.02 13:00** (fresh rows 10-13) produce **deterministic 433-row cascade** in 9 contiguous ranges `(10,16)`, `(36,47)`, `(49,61)`, `(63,71)`, `(78,102)`, `(128,178)`, `(180,233)`, `(237,253)`, `(255,499)` interrupted by 67 unchanged rows, no qualitatively different mechanism, **current `-AllowDecisionIds` cannot represent root-plus-propagation without 433-row (87%) exemption** — tooling limitation, not gate failure. P14 selected **O2** (specify enhancement, do not implement).

**P15 scope:** Specify the *minimum* read-only capability that would prove root-cause + deterministic downstream propagation *without* 433-row exemption, without changing gate definitions, without modifying source, without re-freezing.

## 1. Root identification — exact representation of the 33 root decision IDs and their insertion points

**Root set (frozen):** The 33 decisionIds that differ on `signalTime` between fresh (`Tools/TT01/artifacts/TT01_20260829_220830/telemetry_v4_20260130.csv` or `135145` fresh) and baseline (`Tools/TT01/baseline/telemetry_v4_20260130.csv`), i.e., `11,12,13,14,15,16,17,191,192,193,194,195,196,197,198,199,200,201,208,209,238,239,240,241,242,243,244,245,246,247,248,249,250`. These are exactly the rows where `signalTime` sequence is shifted.

**Insertion points (frozen):**
- **Primary root cluster:** Fresh row indices **10,11,12,13** share single `signalTime 2026.01.02 13:00` all `LIQUIDITY_BOS_BULLISH` (4 decisions at one closed bar) where baseline has `14:00,15:00,16:00,17:00` singletons — the C4 closed-bar insertion (Swing `maxCenter rates_total-4` + FVG `(3,2,1)` + Liquidity closed-bar mitigation, 7d4eecb).
- **Secondary root points:** Indices `14,15,16` (remaining shift tail of same bar) and `191-201,208-209,238-250` (later bars where signalTime shift re-appears due to downstream bar-boundary propagation, same 33 IDs).

**Specification requirement:** Capability must represent root as **two-tier**: `root_core = {11,12,13,14}` (the 4 same-bar insertions) and `root_shift = {11-17,191-201,208-209,238-250}` (the 33 signalTime-shifted IDs). `root_core` proves C4 insertion; `root_shift` proves identity propagation. Representation must be decisionId-keyed, not row-index-keyed (decisionId is stable across runs).

## 2. Sequence-shift invariant — fresh[i].signalTime == baseline[i-1].signalTime for every claimed propagated row

**Invariant S1 (shift):** For every *propagated* row `i` in the 9 changed ranges **excluding** the 4 root insertion rows themselves, `fresh[i].signalTime == baseline[i-1].signalTime` **and** `fresh[i].decisionId == baseline[i-1].decisionId +1` (decisionId shift, where decisionId is monotonic).

**Boundary handling (explicit):**
- **Range start `i=10` (first divergence):** `fresh[10].signalTime (13:00) != baseline[10].signalTime (14:00)` but `fresh[10].signalTime == baseline[9].signalTime (13:00)` — **offset TRUE** proves insertion, not shift.
- **Within shifted ranges:** e.g., `10≤i≤16` continuous, `fresh[i].signalTime == base[i-1].signalTime` must hold for `i=11..16`.
- **Unchanged gaps:** Indices `17, 18-35, 48, 62, 72-77` etc. are **outside** shifted ranges; invariant requires `fresh[i].signalTime == baseline[i].signalTime` (identity) — proves non-contiguous propagation, not broad percentage allowlist.
- **Later ranges:** Each range start (36, 49, 63, 78, 128, 180, 237, 255) must satisfy `fresh[range_start].signalTime == baseline[range_start-1].signalTime` if that range is propagation, or `fresh[range_start].signalTime != baseline[range_start].signalTime` with independent detector change if new root — specification must classify per range.

**Proof artifact:** For each of the 433 changed rows, record `baseline decisionId/signalTime vs fresh decisionId/signalTime` and `S1 pass/fail` per row.

## 3. Propagation invariant — direct root changes vs deterministic downstream row displacement

**Invariant P1 (propagation):** A row `i` is **direct root** if `i ∈ {10,11,12,13}` (the 4 same-bar insertions). A row is **deterministic downstream** if `i` is in the 433 set **and** `S1 holds` (`fresh[i].signalTime == base[i-1].signalTime`) **and** its changed columns are exactly the downstream consequences of the root's detector-state shift.

**Distinction:**
- **Direct root changes:** `structureRaw/Weight/Contribution, liquidityRaw/Weight, trendRaw/Weight` at bar 2026.01.02 13:00 — C4 direct detector exclusion of forming bar.
- **Downstream displacement:** `signalTime` shift by one + `ruleName/firedRuleId/layer*` flips at bars where detection set now differs because earlier bar's detection moved — **not** new strategy logic. Example: row `50` `OB_FVG_BEARISH → LIQUIDITY_BOS_BULLISH` with `direction, confidence` diff is downstream of earlier structure shift, not independent.

**Requirement:** Capability must label every of the 433 rows as `ROOT` (4) or `PROPAGATED` (429) with evidence: for PROPAGATED, show `fresh[i]` equals `base[i-1]` on `signalTime` and on at least one detector column that was ROOT-affected, proving displacement, not independent divergence.

## 4. Column-confinement invariant — propagated differences remain within authorized C4 detector/rule columns plus already-authorized outcome/payload columns where applicable

**Authorized C4 detector/rule set (frozen):** `structureRaw, structureWeight, structureContribution, obRaw, obWeight, obContribution, fvgRaw, fvgWeight, fvgContribution, trendRaw, trendWeight, trendContribution, liquidityRaw, liquidityWeight, liquidityContribution, hasBOS, hasOrderBlock, hasFVG, hasLiquiditySweep, hasCHOCH, hasProtectedPoint, trendAligned, layerStructural, layerLiquidity, layerConfirmation, layerTotal, layerOrderBlock, layerFVG, fvgClass, fvgSize, fvgStrength, fvgCreatedTime, validatorResults, newDecision, decisionMatch, directionMatch, firedRuleId, ruleName, ruleScore, ruleConfidence, ruleEvidenceCount, ruleEvidenceIds, confidence, direction, legacyConfidence, newConfidence`.

**Authorized outcome/payload set where applicable (downstream rows that also have outcome):** `outcome, rMultiple, barsHeld, exitReason, exitPrice, entryPrice, timestamp` — **only** on rows where outcome is downstream of detector change (BEHAVIOR outcome columns on those 433 rows), not as blanket allowlist.

**Invariant C1:** For every propagated row, `diff_cols ⊆ (C4 set ∪ outcome/payload set on that row)` and **no** `Core/Engine` failure-path, parameter, or non-C4 column (e.g., `actualOutcome` alone without detector change) appears.

**Proof:** Per-row `changed columns` list from `telemetry_v4` diff, checked against frozen allowlist above.

## 5. Range-contiguity invariant — prove the nine observed changed-row ranges and unchanged gaps rather than accepting a broad percentage allowlist

**Invariant R1:** The 433 changed rows must decompose exactly into the **9 observed contiguous ranges** `(10,16)`, `(36,47)`, `(49,61)`, `(63,71)`, `(78,102)`, `(128,178)`, `(180,233)`, `(237,253)`, `(255,499)` with **67 unchanged rows** as gaps (`0-9`, `17-35`, `48`, `62`, `72-77`, `103-127`, `179`, `234-236`, `254`). Proof must list each range's first/last `signalTime` and show that **within each range every row is changed, and between ranges every row is unchanged** (byte-identical on all non-exempt columns).

**Why not percentage allowlist:** `433/500 = 87%` would also allow a scattered 433 with unrelated mechanism hidden; contiguity proves **deterministic propagation from a single insertion**, not independent behavioral changes.

## 6. Root-plus-propagation artifact — exact schema for behavior_root_cascade_proof.jsonl

**File:** `Tools/TT01/artifacts/TT01_<runId>_root_cascade/behavior_root_cascade_proof.jsonl` — one JSON per row (433 + 67 unchanged sentinel rows for completeness), immutably named per run, not overwriting `220830` or `135145`.

**Required fields per record:**

```json
{
  "row_index": 10,
  "baseline_decisionId": "11",
  "fresh_decisionId": "11",
  "baseline_signalTime": "2026.01.02 14:00",
  "fresh_signalTime": "2026.01.02 13:00",
  "baseline_ruleName": "LIQUIDITY_BOS_BULLISH",
  "fresh_ruleName": "LIQUIDITY_BOS_BULLISH",
  "changed_columns": ["structureRaw","trendRaw","liquidityRaw","signalTime"],
  "causal_class": "ROOT", // ROOT | PROPAGATED_SHIFT | PROPAGATED_RULE_FLIP | PROPAGATED_EVIDENCE_RENUMBER | UNCHANGED
  "S1_shift_invariant": "PASS",
  "P1_propagation_invariant": "PASS",
  "C1_column_confinement": "PASS",
  "R1_range_membership": "10,16"
}
```

**Header metadata (first line, not per-row):**

```json
{
  "runId": "RUN-2026.08.31 13:51:50-1627422328",
  "gitHead": "36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3",
  "buildTag": "2026.08.31 13:51:50",
  "root_core_ids": ["11","12","13","14"],
  "root_shift_ids": ["11","12","13","14","15","16","17","191","192","193","194","195","196","197","198","199","200","201","208","209","238","239","240","241","242","243","244","245","246","247","248","249","250"],
  "propagated_row_count": 429,
  "total_changed_rows": 433,
  "unchanged_rows": 67,
  "ranges": [[10,16],[36,47],[49,61],[63,71],[78,102],[128,178],[180,233],[237,253],[255,499]],
  "allowDelta": ["structureRaw","structureWeight","structureContribution","obRaw","obWeight","obContribution","fvgRaw","fvgWeight","fvgContribution","trendRaw","trendWeight","trendContribution","liquidityRaw","liquidityWeight","liquidityContribution","hasBOS","hasOrderBlock","hasFVG","hasLiquiditySweep","trendAligned","layerStructural","layerLiquidity","layerConfirmation","layerTotal","layerOrderBlock","layerFVG","fvgClass","fvgSize","fvgStrength","fvgCreatedTime","firedRuleId","ruleName","ruleScore","ruleConfidence","ruleEvidenceCount","ruleEvidenceIds","confidence","direction","validatorResults","newDecision","decisionMatch","directionMatch","legacyConfidence","newConfidence"],
  "outcome_allowance": ["outcome","rMultiple","barsHeld","exitReason","exitPrice","entryPrice","timestamp"],
  "hashes": {
    "baseline_csv_sha256": "B5AB5FEE...",
    "fresh_csv_sha256": "9A1E8A2E...",
    "binary_SuperCents_X_sha256": "9A1E8A2E...",
    "binary_TestRunnerEA_sha256": "1AA4EC79..."
  },
  "provenance": {
    "HEAD": "36c7a73",
    "branch": "main",
    "tracked_diff": "23 files +105/-52",
    "baseline_manifest": "Tools/TT01/baseline/baseline.manifest.json freezeId B8 commit 982a9cc rows 500",
    "platform": "terminal 6140 metaeditor 6140"
  }
}
```

**Provenance requirements:** `runId/buildTag/gitHead` from `manifest.json`, `baseline_csv_sha256` from `baseline.manifest.json` (`B5AB5FEE...`), `fresh_csv_sha256` from `Tools/TT01/artifacts/<runId>/telemetry_v4_20260130.csv`, binary SHA256 from `binaries/` in same run, `HEAD`/`branch`/`tracked diff` at generation time.

## 7. Negative control — test that would fail if an unrelated behavioral change were introduced outside the root cascade

**Control:** Inject a single synthetic unrelated change outside the 9 ranges — e.g., flip `firedRuleId` at an *unchanged* row `i=20` (in gap `17-35` where `fresh[i]==baseline[i]`) from `BOS_OB_BEARISH` to `LIQUIDITY_BOS_BULLISH` without signalTime shift, or change `entryPrice` without detector change.

**Expected result:** All five invariants must **FAIL** for that row:
- `S1` fails (no shift, signalTime unchanged but rule changed),
- `P1` fails (not ROOT, not downstream shift),
- `C1` fails (rule change without C4 detector column change),
- `R1` fails (changed row outside 9 ranges).

If the cascade proof still passes with unrelated change, the capability is insufficient (would hide defects). This control proves the 433-row allowlist is **not** a broad exemption.

## 8. Acceptance rule — when BEHAVIOR can move from EXPLAINED / NOT FORMALLY ATTRIBUTED to FORMALLY ATTRIBUTED / ACCEPTABLE

**BEHAVIOR moves to FORMALLY ATTRIBUTED / ACCEPTABLE iff *all* invariants pass on the artifact above, without automatically making the gate PASS:**

1. **Root identification PASS** — 4 root_core and 33 root_shift IDs exactly match P12/P13 census, first divergence index 10 proven.
2. **Sequence-shift invariant S1 PASS** — every propagated row satisfies `fresh[i].signalTime == baseline[i-1].signalTime` with boundary handling, and every unchanged gap satisfies `fresh[i].signalTime == baseline[i].signalTime`.
3. **Propagation invariant P1 PASS** — 429 propagated rows classified as `PROPAGATED_*` with deterministic displacement proof, 4 as `ROOT`.
4. **Column-confinement C1 PASS** — all 433 rows' diffs subset of C4 set (+ outcome/payload only where outcome downstream), zero unrelated mechanism column.
5. **Range-contiguity R1 PASS** — 9 ranges and 67 gaps proven, not percentage allowlist.
6. **Negative control FAILs as expected** — synthetic unrelated change correctly rejected.
7. **Provenance complete** — runId/gitHead/binary hashes/baseline SHA match.

**Gate PASS is *not* automatic:** Even when FORMALLY ATTRIBUTED / ACCEPTABLE, **BEHAVIOR-REGRESSION gate remains FAIL until doctrine explicitly permits root-plus-propagation attribution model** (P14 O2). The artifact proves *attribution*, not *acceptance* — re-freeze and B8 certification still require separate human disposition per P10 §10 entry criteria (PREFLIGHT GREEN + formal attribution + full ACTIVE/SETTLEMENT/INTEGRITY censuses + duplicate disposition).

**Explicitly preserve:**

```
UNKNOWN = FAIL;
no 433-row exemption (87% allowlist prohibited);
no gate-definition change;
no source/parameter/PromotionGate modification;
no re-freeze;
no B8 certification;
no TT01 execution (specification only);
no artifact overwrite (new runId dir, preserve 220830/135145);
no 2026-H2 access;
BEHAVIOR remains NOT ACCEPTABLE until doctrine permits root-plus-propagation model.
```

## 9. Authorization boundary

**P15 is specification only.** Implementation, execution, and any resulting gate disposition require separate authorization. No TT01 run with the new invariants, no artifact generation, no baseline re-freeze, no B8 certification is authorized by this specification. No existing artifact overwritten; no `docs/` record beyond this one; no commit/staging/merge/rebase/revert/reset/clean.

## 10. Repository safety verification

```text
Before P15: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P15 record existed; PREFLIGHT contaminant already removed; TT01_20260829_220830 (35,753 B) + TT01_20260831_135145 (64+42 arm files) intact
After P15:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — parked and untouched (verified)
         PREFLIGHT contaminant .claude/worktrees/.../TestRunnerEA.ex5 — remains absent (verified)
         Tests/TestRunnerEA.ex5 canonical — preserved
         TT01_20260829_220830/manifest.json 35,753 B — intact
         P13 artifact dir 135145 64+42 files — intact
         baseline telemetry_v4_20260130.csv + manifest freezeId B8 — not modified, not re-frozen
         staging/commit — none
         merge/rebase/cherry-pick/revert/reset/clean — none
         TT01/test/gate/harness executed — none in P15
         RFA harness/suites — not registered/removed
         2026-H2 — not inspected
         Prior governance records P5/P6/P7/P8/P9/P10/P11/P12 — unmodified
         New record — exactly one: docs/P15_ROOT_CASCADE_PROOF_CAPABILITY_SPEC_2026-08-30.md
         Equivalent P15 existed before? NO — verified Test-Path False
```

---

*P15 specification — minimum read-only capability to prove 33-root → 433-row deterministic BEHAVIOR cascade without 87% allowlist, with five invariants, narrow artifact schema, negative control, and explicit acceptance rule that preserves UNKNOWN=FAIL and does not make the gate PASS. Implementation requires separate authorization.*

