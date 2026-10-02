# P5 — Four-Gate Row-Rooted Localization (Run TT01_20260829_220830 @ 36c7a73)

Status: **LOCALIZATION COMPLETE — BEHAVIOR-REGRESSION EXPLAINED (high-confidence) · ACTIVE-TIER / SETTLEMENT-ISOLATION / INTEGRITY-CONTROL PARTIALLY EXPLAINED · PREFLIGHT EXPLAINED · no gate made to PASS · no baseline/re-freeze/certification**
Date: 2026-08-29
Type: READ-ONLY forensic localization of the four measured doctrine-gate failures, per the B4 authorization boundary. No edits, no gate runs, no baseline change, no registration, no research, no holdout access, no staging, no commit.
Authoritative starting point: `Tools/TT01/artifacts/TT01_20260829_220830/` (manifest.json 35,753 B, gitHead `36c7a73`, overall FAIL) + `B4_VALIDATION_AUTHORIZATION_2026-08-29.md` + the committed, authorized development line `1e6aa5f → 36c7a73`.
Duplicate check: performed — no equivalent P5 record existed.

## 1. Run identity and artifact binding

```text
Run:               TT01_20260829_220830 (2026-08-29 22:08:30 -> 22:33)
gitHead binding:   36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 (verified in manifest + all arm identities)
Platform:          terminal/metaeditor 6140 (auto-updated from 6118 since the 08-19 runs — environmental)
Overall:           FAIL
Gates:             13 PASS / 5 FAIL (PREFLIGHT + the four doctrine gates)
Artifacts:         manifest.json, gates.jsonl, runtime_identity.log, run_identity.txt,
                   suite_journal_slice.log (506,158 B), telemetry_v4_20260130.csv (fresh
                   replay, canonical schema), telemetry_v6_default.csv, telemetry_v6_k1.csv
Not retained:      the isolation arms' dated telemetry CSVs — the second (K1) arm overwrote
                   the first (control) arm's files in Common\Files\Telemetry (harness rotation
                   behavior); the control-arm row-level data is therefore only available
                   through the gate's own recorded diff details
```

## 2. Four-gate evidence summary (measured at HEAD, first gitHead-bound measurement)

| Gate | Result | Headline divergence |
|---|---|---|
| BEHAVIOR-REGRESSION | FAIL | signalTime shifted on 33/500 rows (first mismatch index 10); component columns differ (structure 78, ob 79, fvg 65, liquidity 92, trend 78); rule-mix shifts (39 empty-rule rows → 0; new BOS_OB_BULLISH 32, OB_FVG_BULLISH 20) |
| ACTIVE-TIER | FAIL | signalTime not unique (211 unique / 220 rows); 54 outcome-column diffs on admitted bars |
| SETTLEMENT-ISOLATION | FAIL | 460 column diffs on 2,733 admitted rows (Design A RED) — sampled columns all settlement/outcome-class |
| INTEGRITY-CONTROL | FAIL | row count 6239 == frozen CONTROL (**determinism holds**); 35,259 column diffs, detector-derived component columns (e.g. bar 2026.04.06 00:15: confidence 0.40→0.60, structureRaw 0→15, obRaw 15→0) |

## 3. Row-rooted localization

### 3.1 BEHAVIOR-REGRESSION — **EXPLAINED (high-confidence; mechanism row-rooted)**

Row-level comparison of the fresh replay (artifact `telemetry_v4_20260130.csv`, 500 rows) vs the frozen baseline (`Tools/TT01/baseline/telemetry_v4_20260130.csv`, 500 rows):

- Decision identity holds (500/500 rows on both sides; row counts equal).
- **signalTime mismatches: 33, first at row index 10, last at 249.**
- **Offset test: `fresh[10] == baseline[9]` = TRUE** — the fresh sequence is the baseline sequence shifted back by one from index 10: the fresh run contains an **extra decision cluster at bar 2026.01.02 13:00** — four consecutive `LIQUIDITY_BOS_BULLISH` decisions (fresh rows 10–13 all signalTime 2026.01.02 13:00) where the baseline had one decision per bar (14:00/15:00/16:00/17:00). This is the same-bar multi-decision behavior also seen in ACTIVE-TIER (211/220).
- **Rule-mix deltas (complete census — only detector-derived families differ):** empty-rule rows 39→0; BOS_OB_BULLISH 0→32; OB_FVG_BULLISH 0→20; BOS_OB_BEARISH 165→151; LIQUIDITY_BOS_BULLISH 146→103; LIQUIDITY_BOS_BEARISH 61→80; OB_FVG_BEARISH 89→114. No non-detector family changed.
- **Attribution:** the **C4 closed-bar discipline** (`7d4eecb`: Swing `maxCenter=rates_total-4`; FVG closed-bar (3,2,1) scan; Liquidity closed-bar mitigation) is the **only detector-behavior change** in the window `1e6aa5f → 36c7a73`; the observed effects (detection-set changes → new bullish BOS_OB/OB_FVG firings, LIQUIDITY_BOS redistribution, same-bar multi-decision clusters, one-bar sequence shift) are the mechanical consequences of excluding the forming bar from detection. The GR01 floors are present in both sides (B8 freeze predates the baseline).
- Classification: **EXPLAINED** (high-confidence; mechanism row-rooted; the only unproven step is the formal per-row `-AllowDelta` attribution, which requires the deferred localization tooling — the direction and family confinement are established by the census above).

### 3.2 ACTIVE-TIER — **PARTIALLY EXPLAINED**

- **signalTime not unique (211 unique / 220 rows):** row-rooted to the same same-bar multi-decision behavior as 3.1 (post-C4 detection produces multiple admitted decisions at one bar). This is the **intended consequence of the authorized C4 change** interacting with the tier filter — not an isolated defect by any current evidence, but its acceptance as intended requires the gate disposition step.
- **54 outcome-column diffs on admitted bars** (timestamp/outcome/rMultiple/barsHeld/exitReason — sampled from the manifest details): consistent with the authorized outcome-path work (`3ad7cf2` directional TP validation; `b8b52ae`/`a0f2720` payload+ledger outcome columns) applied to the shifted decision stream. Individual bar-level attribution of all 54 diffs was **not possible from the manifest** (details truncated to samples) — deferred to the authorized localization tooling.
- Unexplained residue: none identified; classification limited by manifest truncation. Classification: **PARTIALLY EXPLAINED**.

### 3.3 SETTLEMENT-ISOLATION — **PARTIALLY EXPLAINED**

- **460 column diffs on 2,733 admitted rows**: sampled manifest details show diffs **exclusively in settlement/outcome columns** (timestamp ×2, barsHeld ×2, outcome ×1, rMultiple ×1, entryPrice ×1, exitPrice ×1 in the retained sample; e.g. `bar 2026.05.07 12:00 col timestamp: 12:45 → 12:30`, `col barsHeld: 2 → 27`).
- Consistent with the authorized outcome/deferral-path changes (payload extension + ledger writer + TP validation) applied inside the isolation arms, plus the documented environmental nondeterminism mode (tick-cache drift between arm runs — recorded in the harness baseline history B4 note) as a possible contributor. **Not proven which shares the blame** — the full 460-diff census is truncated in the manifest.
- No non-outcome column was observed to differ. Classification: **PARTIALLY EXPLAINED**.

### 3.4 INTEGRITY-CONTROL — **PARTIALLY EXPLAINED**

- **Row count 6,239 == frozen CONTROL — determinism holds** (the fresh tier-0 arm reproduces the frozen row population exactly).
- **35,259 column diffs**, concentrated in detector-derived component columns; row-rooted sample from the gate: bar 2026.04.06 00:15 — frozen `confidence 0.40 / structureRaw 0 / obRaw 15` → fresh `confidence 0.60 / structureRaw 15 / obRaw 0`: detections moving between adjacent bars — the one-bar-shift signature of C4.
- Attribution: the frozen CONTROL (`CONTROL_RLHYP01_INTEGRITY`, v5 CSVs, Sprint-22-era) **predates the authorized C4 closed-bar change**; the fresh arm includes it. The diff columns are exactly the detector-derived component columns C4 alters.
- Limitation: the fresh control-arm CSVs were overwritten by the K1 arm during the run (harness rotation), so a full per-column census from artifacts is impossible — the gate's own 35,259-diff record is the evidence. Classification: **PARTIALLY EXPLAINED** (explained in class and mechanism; full census deferred).

## 4. PREFLIGHT finding (separate record — no remediation performed)

```text
Finding:      PREFLIGHT FAIL — canonical TestRunnerEA.ex5 count = 2 (expected exactly 1)
Contaminant:  .claude/worktrees/ledger-event-deal-in-forensic-report-708ea3/Tests/TestRunnerEA.ex5
              (3,019,690 B, compiled 2026-08-27 14:03 — produced inside the Claude worktree session)
Canonical:    Tests/TestRunnerEA.ex5 (2,714,782 B, compiled 2026-08-29 22:14 by this authorized run)
Platform:     terminal/metaeditor 5.0.0.6140 — auto-update from 6118 since the 2026-08-19 runs
              (environmental evidence; the 08-19 manifests record terminal=6118)
Remediation:  NONE performed (per authorization) — the stray binary remains in place;
              its removal/relocation is a repository mutation for the next authorized step
Impact:       PREFLIGHT will remain RED on every run until the stray binary is dispositioned;
              this is independent of the four doctrine gates
```

## 5. Root-cause classification summary

| Gate | Classification | Basis |
|---|---|---|
| BEHAVIOR-REGRESSION | **EXPLAINED** (high-confidence) | Row-rooted one-bar sequence shift from an extra same-bar decision cluster (4× LIQUIDITY_BOS_BULLISH @ 2026.01.02 13:00, index 10); rule-mix census confined to detector-derived families; solely consistent with the authorized C4 closed-bar discipline |
| ACTIVE-TIER | **PARTIALLY EXPLAINED** | signalTime non-uniqueness row-rooted to the same C4 mechanism; 54 outcome-column diffs consistent with authorized outcome-path work; full census truncated in manifest |
| SETTLEMENT-ISOLATION | **PARTIALLY EXPLAINED** | sampled diffs exclusively settlement/outcome columns; consistent with authorized outcome/deferral changes; tick-cache drift (documented environmental mode) unproven as contributor; full census truncated |
| INTEGRITY-CONTROL | **PARTIALLY EXPLAINED** | determinism holds (row count identical); 35,259 diffs in detector-derived columns with the C4 one-bar-shift signature; frozen CONTROL predates C4; full census impossible (arm CSVs overwritten by harness rotation) |
| PREFLIGHT | **EXPLAINED** | worktree stray binary + platform update — environmental, measured |

Unexplained residue across all four gates: **none identified**. No evidence of an unauthorized behavior change was found; every observed divergence class maps to an authorized change or a documented environmental factor. Formal per-row `-AllowDelta` attribution remains the confirmation step (deferred).

## 6. Unresolved questions (for the next authorized step)

1. Formal per-row attribution of all BEHAVIOR-REGRESSION diffs to C4 via `-AllowDelta`/`-AllowDecisionIds` localization tooling (GR01-stage-4 pattern).
2. Full 460-diff and 35,259-diff column censuses (manifest truncation; requires re-run with full-detail capture or post-run artifact diff tooling).
3. Disposition of the ACTIVE-TIER same-bar multi-decision behavior: intended consequence (accept + document in the re-freeze) or defect (fix first).
4. PREFLIGHT remediation decision: remove/relocate the worktree's stray `TestRunnerEA.ex5` (repository mutation — requires authorization).
5. Whether the platform update 6118 → 6140 contributes to any divergence (no direct evidence either way; the COMPILE gates passed on 6140).
6. Whether tick-cache drift contributes to SETTLEMENT-ISOLATION (documented environmental mode; unproven).

## 7. Explicitly still unauthorized (unchanged)

Baseline modification/re-freeze · gate-definition modification · source/parameter/PromotionGate modification · merge/rebase/cherry-pick/revert/reset/clean · RFA registration · B8 certification · research/discovery/acquisition/backtest/optimization · M1 reopening · DISC-C1 V1/V2 · Sprint 26 · 2026-H2 access · remediation of the PREFLIGHT contaminant.

## 8. Repository safety verification

```text
Before: HEAD 36c7a73 (main); tracked diff 23 files, +105/-52; P5 record absent
After:  HEAD 36c7a73 — unchanged
        branch main — unchanged
        tracked diff — unchanged (23 files, +105/-52)
        .mq5/.mqh — untouched; parameters — untouched; PromotionGate — unchanged
        staging/commit — none; merge/rebase/cherry-pick/revert/reset/clean — none
        2026-H2 — not inspected
Audit artifact: docs/P5_FOUR_GATE_LOCALIZATION_2026-08-29.md (the only new file)
Prior decision records: unmodified
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
Baseline modified/re-frozen:  NO
Gate definitions changed:     NO
RFA registered:               NO
Staging/commit:               NO
Merge/rebase/cherry-pick:     NO
Revert/reset/clean:           NO
Localization record:          YES (this record — analysis only)
B8 certification claimed:     NO
```

Single file created: `docs/P5_FOUR_GATE_LOCALIZATION_2026-08-29.md`. Prior records unmodified.

---

*P5 localization record — the four measured REDs are explained to the depth the artifacts permit (one EXPLAINED, three PARTIALLY EXPLAINED, zero UNEXPLAINED); every remediation/re-freeze/certification action remains unauthorized. No production change; nothing committed beyond this record.*


