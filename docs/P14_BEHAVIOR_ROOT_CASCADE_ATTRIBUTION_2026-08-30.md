# P14 — BEHAVIOR Root-Cascade Attribution Governance Decision

Status: **P14 COMPLETE — READ-ONLY GOVERNANCE DECISION · NO SOURCE/PARAMETER/PROMOTIONGATE/GATE-DEFINITION/BASELINE/ARTIFACT MODIFICATION · NO TT01 EXECUTION · B8 NOT CERTIFIED · RE-FREEZE NOT AUTHORIZED**
Date: 2026-08-30
Type: Governance decision on BEHAVIOR-REGRESSION root-plus-propagation attribution boundary, based exclusively on P12/P13 and preserved TT01 artifacts `TT01_20260829_220830` (36c7a73, PREFLIGHT FAIL before CLEAN) and `TT01_20260831_135145` (36c7a73, PREFLIGHT PASS after CLEAN, 500/500 REPLAY, 220/220 K1, 6239/2733 HEALTHY). No TT01/test/harness/backtest execution; no holdout/research/M1/DISC-C1/Sprint26 access; no remediation beyond P11 CLEAN already completed. Single governance record.

## 0. Authorization and verification

**Governing state:** B1 RESOLVED/PARKED (36c7a73 selected, 0abe4bc parked) · B2 AUTHORIZED+DOCUMENTED · B3 RESOLVED deferred-registration · B4 AUTHORIZED+EXECUTED · P5 COMPLETE · P6 COMPLETE (C — INSUFFICIENT EVIDENCE) · P7 COMPLETE (C — INSUFFICIENT EVIDENCE) · P8 COMPLETE (read-only) · P9 COMPLETE (C — INSUFFICIENT EVIDENCE) · P10 AUTHORIZATION/PLAN (no execution) · P11 EXECUTED (CLEAN + two TT01 runs, no re-freeze) · P12 COMPLETE (433-row deterministic cascade characterized) · P13 EXECUTED (artifact-preserving control re-run 135145, 64+42 arm files preserved, censuses generatable). B8 BLOCKED.

**Pre-creation verification:** HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3, branch main, tracked diff 23 files +105/-52 (same 23 files), 0abe4bc at 0abe4bc708... outside certified line, PREFLIGHT contaminant already removed by P11 (count=2→1) and remains absent, `TT01_20260829_220830/manifest.json` 35,753 B intact, `TT01_20260830_110424`/`111656`/`135145` intact (new, not overwriting 220830), baseline `Tools/TT01/baseline/telemetry_v4_20260130.csv` + manifest freezeId B8 intact, no equivalent P14 existed (`Test-Path` False).

## 1. BEHAVIOR blocker as established by P12/P13

* **33 root signalTime IDs:** `11,12,13,14,15,16,17,191,192,193,194,195,196,197,198,199,200,201,208,209,238,239,240,241,242,243,244,245,246,247,248,249,250` — all with `signalTime` shift (offset `fresh[10]==baseline[9]` TRUE) and rule-mix confined to detector-derived families.
* **First divergence index 10:** Fresh rows 10-13 share single signalTime `2026.01.02 13:00` all `LIQUIDITY_BOS_BULLISH` where baseline had one per bar `14:00/15:00/16:00/17:00` — the extra same-bar decision cluster insertion.
* **433 changed rows:** Any non-exempt column differs (exempt `schemaVersion, swingQualifyingId, swingAmplitude, gateDecision, runId, buildTag, gitHead`) — 433/500 rows differ, forming 9 contiguous downstream propagation ranges `(10,16)`, `(36,47)`, `(49,61)`, `(63,71)`, `(78,102)`, `(128,178)`, `(180,233)`, `(237,253)`, `(255,499)` interrupted by 67 unchanged rows (0-9, 17-35, etc.) where C4 has no effect.
* **Deterministic row-shift relationship:** `fresh[i].signalTime == base[i-1].signalTime` holds for the shifted segment, and for the 433 changed rows the differing columns are exclusively within C4-affected set (detector-derived `structure/ob/fvg/liquidity/trend` + rule family + signalTime + downstream outcome columns on those rows). No row shows qualitatively different mechanism (e.g., `entryPrice` alone without detector change, `Core/Engine` failure-path, parameter column).
* **No qualitatively different mechanism identified** among 433 rows in read-only diff — all diffs within C4-affected column set.
* **Current -AllowDecisionIds machinery cannot represent root-plus-propagation without excessive 433-row exemption:** P11 `TT01_20260830_111656` with 33-ID allowlist left 400 changed rows outside allowlist (`changed 433` when excluding schema/identity, `completeness FAIL: 400 outside`, attribution invariant **holds** for 33 allowed). Expanding to 433 IDs would be `87% rows allowed`, trivializing the gate and hiding a second defect.

## 2. Evaluation of the three governance options

### O1 — ACCEPT ROOT-CAUSE ATTRIBUTION (without allowing 433 individually, preserve gate FAIL until doctrine permits)

* **What it would do:** Treat 33 root decisions plus demonstrated deterministic downstream cascade (9 ranges, offset TRUE, family confinement, no independent divergence) as sufficient *explanation*, while explicitly preserving BEHAVIOR-REGRESSION as **FAIL** until doctrine explicitly permits root-plus-propagation attribution model. No gate PASS claim, no re-freeze.
* **Evidence sufficiency:** Strong for *explanation* (high-confidence, row-rooted offset, family confinement, sole C4 change, 67 unchanged gaps prove non-uniform effect), but **formal gate acceptance still fails** by definition — doctrine currently requires `changed == allowed` per-row allowlisting, which 33 alone does not satisfy. Accepting O1 as *explanation* is defensible; accepting O1 as *gate PASS* would manufacture PASS from explanation.
* **Risk:** Creates a two-tier status (explained vs acceptable) that must be preserved verbatim to avoid future misreading as certification. Requires doctrine to define new root-plus-propagation acceptance criterion before any PASS.

### O2 — AUTHORIZE ATTRIBUTION TOOLING ENHANCEMENT (read-only capability, not implementation)

* **What it would do:** Define the minimum read-only evidence capability to prove root-plus-propagation causality **without** broad 433-row exemption. **Specify, do not implement.** Example invariants that would be required (to be specified in detail in the authorizing record):
  1. **Root identity:** 4 same-bar decisions at 2026.01.02 13:00 are exactly the C4 closed-bar insertion (detector `maxCenter` and `Liquidity` closed-bar exclusion) — prove via Swing `rates_total-4` and FVG `(3,2,1)` scan diff at that bar.
  2. **Sequence-shift invariant:** For all `i` in shifted segment (10-16 contiguous plus downstream ranges), `fresh[i].signalTime == base[i-1].signalTime` and `fresh[i].decisionId == base[i-1].decisionId +1` (or mapped ID shift) — prove the 33-ID shift is the *identity* propagation, not 33 independent changes.
  3. **Column-confinement invariant:** All differing columns in the 433 rows are subset of C4-affected set (`structure/ob/fvg/liquidity/trend` + rule family + downstream `validatorResults/newDecision/outcome` on those rows), with zero `entryPrice/exitPrice` without detector change, zero `Core/Engine` failure-path, zero parameter.
  4. **Range-contiguity invariant:** 9 contiguous ranges correspond exactly to bars where C4 detection set differs (prove via `hasBOS/hasFVG/hasLiquiditySweep` diff at range starts), and 67 unchanged rows correspond to bars where C4 has no effect.
  5. **Artifact outputs:** Immutable `behavior_root_cascade_proof.jsonl` with `row index | baseline decisionId | fresh decisionId | signalTime base→fresh | rule family base→fresh | changed columns | causal class (root / downstream shift / evidence-id renumbering / rule-family flip)` for all 433 rows, bound to `runId 135145` gitHead 36c7a73, plus `AllowDecisionIds=[4 root IDs]` + `AllowDelta=[detector families]` with new `propagation` invariant (not `changed==allowed`).
* **Evidence sufficiency:** Would provide formal proof without 87% allowlist. **No such tooling exists in current TT01 machinery** — requires new validator logic (root-plus-propagation invariant), which is a **tooling enhancement, not a gate redefinition**. Must be separately authorized as read-only evidence capability, with artifact policy (uniquely named run dir, manifest identity, binary SHA256) as in P10 §6.
* **Risk:** Tooling must not weaken `UNKNOWN=FAIL` or conflate root with independent divergence; must preserve gate as FAIL until tooling is implemented and run.

### O3 — REJECT / INSUFFICIENT (require different attribution method, leave BEHAVIOR unresolved)

* **What it would do:** Declare existing 33-root/433-cascade evidence insufficient even as explanation, require a different attribution method (e.g., per-detector closed-bar proof at bar 13:00 alone, not sequence shift).
* **Assessment:** **Overly pessimistic** — P12/P13 already demonstrate high-confidence explanation (offset TRUE, family confinement, sole C4 change, 9 contiguous ranges, no independent mechanism). Rejecting would ignore the strongest row-rooted evidence in the chain and would demand a *narrower* root-only proof that still leaves 400 downstream rows unexplained, which is exactly the current machinery's limitation. O3 is not warranted.

## 3. Governance determination

**Determination: O2 — AUTHORIZE ATTRIBUTION TOOLING ENHANCEMENT (specification only, no implementation)**

* **Rationale:** P12 already shows the *limitation* is not evidence insufficiency but **tooling model insufficiency**: current `-AllowDecisionIds` conflates root and deterministic downstream propagation, forcing a choice between `33 IDs → completeness FAIL (400 outside)` and `433 IDs → trivial PASS (87% allowed)`. Neither is formally correct. The existing 33-root/433-cascade evidence is **sufficient for explanation** (O1's premise holds) but **insufficient for formal gate acceptance** under current machinery (O1's gate remains FAIL, correctly). The correct governance action is therefore **not to accept root-cause as gate PASS (O1) nor to reject (O3), but to authorize the *specification* of a root-plus-propagation proof capability (O2) that can be implemented later as read-only evidence without modifying gate definitions.**

**What O2 authorizes (specification only, not execution):**
- Draft the exact 5 invariants listed in §2 O2 above as the *minimum* read-only evidence capability to prove root-plus-propagation causality without broad exemption, with artifact outputs `behavior_root_cascade_proof.jsonl` + updated manifest `allowDecisionIds=[4 root]` + `allowDelta=[detector families]` + new propagation invariant.

**What O2 does NOT authorize:**
- No TT01 run with the new invariant, no implementation of the tooling, no gate PASS claim, no re-freeze, no B8 certification, no source/parameter/PromotionGate/gate-definition change, no artifact generation, no repository mutation — specification only.

**O1 status:** O1's premise (33-root/433-cascade is sufficient *explanation*) is **accepted as explanation**, but O1 as *gate disposition* is **not selected** — gate remains **FAIL** until doctrine explicitly permits the new attribution model (which O2 will define). This preserves `Explained ≠ acceptable ≠ certified` per P6.

**O3 rejected:** Rejecting would be manufacturing insufficiency where high-confidence explanation exists.

## 4. Whether P13 evidence is sufficient to close ACTIVE-TIER, SETTLEMENT-ISOLATION, INTEGRITY-CONTROL independently

* **ACTIVE-TIER (54 diffs + 211/220 duplicate):** **Not closed.** Characterization in P13 shows 54 sample exclusively downstream outcome fields (`timestamp/outcome/rMultiple/barsHeld/exitReason`) at same-bar cluster, 211 unique vs 220 (9 duplicates) same C4 cluster, fingerprint invariant PASS — **characterized, not formally acceptable**. Full 54 per-row census with decisionId-keyed `active_tier_census.jsonl` was not emitted as immutable artifact (P13: 813 column diffs on 5 outcome columns across 220 rows when counting rows, manifest sample 54). Duplicate 211/220 remains **governance-undecided** (intended C4 consequence vs defect). Preserve **UNKNOWN=FAIL** for re-freeze.

* **SETTLEMENT-ISOLATION (460 diffs):** **Not closed.** P13 preserved `isolation_control` 64 files + `isolation_k1` 42 files per run (verified not overwritten in `135145`), sample exclusively outcome/settlement (`timestamp, barsHeld, entryPrice, exitPrice, outcome, rMultiple`) with horizon `100→38` deferral-sensitive class consistent with authorized outcome/deferral hoist — **characterized**. Full 460 per-row census joining 64 vs 42 dated sets on decisionId with column classification **not emitted** as `isolation_settlement_census.jsonl`. Tick-cache share remains **unproven**. Preserve **UNKNOWN=FAIL**.

* **INTEGRITY-CONTROL (35,259 diffs / 6,239 rows):** **Not closed.** Determinism holds (`6,239 == 6,239`), one-bar-shift signature consistent with stale Sprint-22 CONTROL vs C4, `isolation_control` now preserved per run so full census is **generatable**, but per-column `integrity_control_census.jsonl` with one-bar-shift proof was **not emitted**. Overwrite limitation is **resolved for future runs** (P13 artifact-preserving run proves 64-file preservation), but **existing artifact `220830` still has truncated control-arm evidence** — per-column exclusive C4 proof still requires new census artifact. Preserve **UNKNOWN=FAIL** until census emitted.

* **Environmental 6118→6140 / tick-cache:** **Remains UNKNOWN=FAIL** — plausible but unproven, no new experiment authorized. COMPILE PASS does not prove doctrine-neutrality; no cache snapshot exists for `135145` arms. Explicitly preserved as `UNKNOWN` per P6/P7.

**No gate moves to ACCEPTABLE on P13 evidence alone.** All three remain `PARTIALLY CHARACTERIZED` but not disposition-ready, exactly as P13 concluded.

## 5. PREFLIGHT assessment (P14)

Contaminant `.claude/worktrees/ledger-event-deal-in-forensic-report-708ea3/Tests/TestRunnerEA.ex5` was **already removed by P11 CLEAN** (single-file `Remove-Item`), verified absent before P12/P13 and still absent before P14, canonical `Tests/TestRunnerEA.ex5` preserved `2,714,782 B`, `TT01_20260830_135145` PREFLIGHT **PASS** (`count=1`). No remediation performed in P14 (read-only). PREFLIGHT remains GREEN for future runs, but does not advance other gates.

## 6. Remaining evidence debt (P14 update — supersedes P13 §8 where unchanged)

1. **BEHAVIOR root-plus-propagation formal proof** — O2 specification → implementation as read-only tooling (root 4 IDs + 9-range propagation invariants, `behavior_root_cascade_proof.jsonl`), then TT01 run with new invariant (does not itself re-freeze).
2. **ACTIVE 54 full census** `active_tier_census.jsonl` (decisionId join) — not emitted.
3. **ACTIVE duplicate disposition** — human ruling 211/220 intended vs defect — not decided.
4. **SETTLEMENT 460 full census** `isolation_settlement_census.jsonl` (64 vs 42 join) — not emitted.
5. **SETTLEMENT tick-cache separation** — cache snapshot / controlled reset experiment if attribution claimed — not generated, remains UNKNOWN.
6. **INTEGRITY full 35,259 per-column census** `integrity_control_census.jsonl` (6,239 rows vs frozen CONTROL, one-bar-shift proof) — now generatable (64-file preservation proven), but **not yet emitted**.
7. **Platform/tick-cache controlled isolation** — only if attribution claimed — not performed.

No debt is closed by reinterpreting `explained` as `proven`.

## 7. Explicit re-freeze readiness

```
NOT READY FOR RE-FREEZE REVIEW
B8 NOT CERTIFIED / BLOCKED
```

P14 does **not** call any gate PASS, does not convert `explained/consistent/downstream propagation` into `formally acceptable`, and does not manufacture formal attribution from correlation. Re-freeze review remains premature; B8 certification requires PREFLIGHT GREEN (now satisfied) **plus** four doctrine gates dispositioned to ACCEPTABLE with formal attribution and full censuses — none satisfied.

## 8. STOP boundary — P14 ends here

No baseline modification/re-freeze; no B8 certification; no parameter/source/PromotionGate/gate-definition changes; no governance disposition of 211/220 duplicate beyond characterization; no remediation beyond P11 CLEAN already completed; **no new TT01 run executed in P14** (read-only governance decision only, per authorization — `TT01_20260831_135145` remains latest P13 run); no research/discovery/acquisition/optimization/backtest/holdout/M1/DISC-C1/Sprint26/2026-H2 access.

Future separately authorized actions remain: O2 tooling specification → implementation → evidence generation (BEHAVIOR 433 cascade proof + ACTIVE/SETTLEMENT/INTEGRITY censuses) → duplicate disposition → re-freeze review → B8 certification — each requires its own explicit authorization.

## 9. Repository safety verification

```text
Before P14: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P14 record existed; PREFLIGHT contaminant already removed
After P14:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — parked and untouched (verified)
         PREFLIGHT contaminant .claude/worktrees/.../TestRunnerEA.ex5 — remains absent (verified)
         Tests/TestRunnerEA.ex5 canonical — preserved (verified 2,714,782 B)
         TT01_20260829_220830/manifest.json 35,753 B — intact (verified)
         P11 artifacts TT01_20260830_110424, 111656, P13 TT01_20260831_135145 — intact, not overwritten (verified 64+42 files per run)
         baseline Tools/TT01/baseline/telemetry_v4_20260130.csv + manifest freezeId B8 — not modified, not re-frozen
         staging/commit — none
         merge/rebase/cherry-pick/revert/reset/clean — none (beyond P11 single-file CLEAN, preserved)
         TT01/test/gate/harness executed — none in P14 (read-only decision only)
         RFA harness/suites — not registered/removed (verified untracked)
         2026-H2 — not inspected
         Prior governance records P5/P6/P7/P8/P9/P10/P11/P12 — unmodified
         New record — exactly one: docs/P14_BEHAVIOR_ROOT_CASCADE_ATTRIBUTION_2026-08-30.md
         Equivalent P14 existed before? NO — verified Test-Path False
```

---

*P14 governance decision — BEHAVIOR 33-root/433-cascade evidence is sufficient as explanation but current gate machinery cannot formally represent root-plus-propagation without 433-row trivial exemption; O2 tooling enhancement is the correct next governance step, not O1 acceptance as PASS nor O3 rejection. ACTIVE/SETTLEMENT/INTEGRITY remain characterized but not formally closed, environmental remains UNKNOWN=FAIL. No production change; READ-ONLY beyond this record.*

