# P22 — ACTIVE / SETTLEMENT / INTEGRITY Formal Census & Disposition

Status: **P22 COMPLETE — READ-ONLY CENSUS & DISPOSITION · NO TT01 EXECUTION · NO RE-FREEZE · B8 NOT CERTIFIED**
Date: 2026-08-31
Type: Read-only formal census and disposition for three doctrine gates using preserved artifacts `TT01_20260829_220830` (36c7a73, overall FAIL, PREFLIGHT RED before CLEAN) and `TT01_20260831_135145` (36c7a73, PREFLIGHT PASS after CLEAN, 500/500 REPLAY, 220/220 K1, 6239/2733 HEALTHY, 64+42 arm files), plus P13/P21 evidence. No TT01/test/harness/backtest execution; no source/parameter/PromotionGate/gate-definition/baseline modification; no re-freeze; no holdout/research/M1/DISC-C1/Sprint26 access; no RFA registration. Single governance record.

## 0. Provenance and run identities

```text
HEAD:              36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 (main, verified)
Branch:            main
Tracked diff:      23 files, +105/-52 (exactly authorized B2 delta)
0abe4bc:           refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc708... — parked, not HEAD
B4 authoritative measurement: TT01_20260829_220830, gitHead 36c7a73, runId 1484263015, buildTag 2026.08.29 22:08:35, terminal 6140, overall FAIL (13/18 PASS, 4 doctrine RED + PREFLIGHT RED)
P11/P13 artifact-preserving measurement: TT01_20260831_135145, gitHead 36c7a73, runId 1627422328/1627443203/1627459843/1627760937, buildTag 2026.08.31 13:51:50, terminal 6140, overall FAIL (same 4 doctrine RED, PREFLIGHT PASS, COMPILE×7 PASS, SUITE 3324/3324 PASS)
Baseline:          Tools/TT01/baseline/telemetry_v4_20260130.csv 500 rows, manifest freezeId B8 commit 982a9cc rows 500, SHA B5AB5FEE..., first 2026.01.02 04:00 last 2026.01.30 23:00
CONTROL:           CONTROL_RLHYP01_INTEGRITY Sprint-22-era v5 6,239 rows (frozen, predates C4)
Artifacts preserved: TT01_20260829_220830 (35,753 B manifest, 500+220+6239+2733 HEALTHY, isolation_control 64 files, isolation_k1 42 files) and TT01_20260831_135145 (same 64+42, not overwriting 220830) — verified intact, not overwritten
P20/P21 multi-root proof: Tools/TT01/artifacts/P20_proof_36c7a73_root_cascade_multi/behavior_root_cascade_proof.jsonl 346,808 B (500 rows, 433 changed, 67 unchanged, 9 ranges) with corrected E(i)=3→15→29, M1-M6 PASS (read-only)
```

## 1. ACTIVE-TIER — complete 54-row census (gate 3b signalTime-paired)

**Gate definition (TT01_Validators.ps1:561-581):** `fingerprint invariant` constant `3005138848403243456` (tier outside canonical) **and** `signalTime not unique` diagnostic **and** decision identity `220 admitted subset of 500` (pure filter) **and** gate 3b: same-bar rows byte-identical on every **non-schema-recording (`schemaVersion, swingQualifyingId, swingAmplitude, gateDecision`)**, non-identity (`runId, buildTag, gitHead`) and non-`decisionId` shared column, **signalTime-paired** (`baseByTime[signalTime] = base row`).

**Complete census from preserved artifacts (read-only, signalTime-paired):**
- **Fingerprint:** `3005138848403243456` constant and equal to default run (tier outside canonical) — **PASS** in both `220830` and `135145`.
- **SignalTime uniqueness:** `211 unique vs 220 rows` (9 duplicates) — **measured** in both runs, consistent. Duplicate groups: `2026.01.02 13:00 ×2`, `2026.01.14 01:00 ×2`, `2026.01.16 00:00 ×8` plus one other — exactly the **same 3 same-bar clusters** as BEHAVIOR multi-root (2026.01.02 13:00 8, 2026.01.14 01:00 12, 2026.01.16 00:00 14 in fresh overall; admitted subset retains 9 of those duplicates).
- **Decision identity:** All `220` admitted bars are subset of default `500` bars (signalTime-paired `baseTimes -notcontains` check 0) — **PASS**, gating is pure filter.
- **Gate 3b shared-column diffs:** `54 column diffs on admitted bars` (manifest `220830` and `135145` identical sample: `bar 2026.01.02 13:00 column timestamp ; outcome ; rMultiple ; barsHeld ; exitReason` same-bar cluster). Read-only re-join of `telemetry_v6_default.csv` (500) vs `telemetry_v6_k1.csv` (220) on `signalTime` with exempt set confirms **54 distinct `(bar, column)` pairs** where admitted vs default differ, **all** in outcome/settlement columns `timestamp, outcome, rMultiple, barsHeld, exitReason` (and `entryPrice/exitPrice` where outcome downstream) — **zero** `structure/ob/fvg/trend/liquidity` detector columns differing (those diffs are in BEHAVIOR 433, not here; here admitted vs default share same detector state because admitted is subset of default at same signalTime, except the 9 duplicates where baseByTime maps duplicate signalTime to *one* base row, so second duplicate necessarily differs on `timestamp` outcome).
- **Causal classification:** `211/220` duplicates **and** `54` outcome diffs are **downstream of C4 same-bar cluster** (original `13:00` cluster plus two secondary clusters). No independent detector divergence: admitted vs default at same `signalTime` with same detector set should be byte-identical, and is except for the 9 duplicates where base has one row at that signalTime but admitted has 2-8 — the **second** duplicate has no base counterpart to pair to except the same single base row, so `timestamp/outcome` necessarily differs due to outcome being tied to admission, not detector.

**211/220 duplicate disposition — explicit reconciliation:**
- **Not assumed intended or defect.** Evidence shows 9 duplicates are **same C4 same-bar cluster** propagated through tier admission (tier is pure filter, so it admits all decisions at a bar, including duplicates). Whether tier *should* deduplicate same-bar decisions (keep highest confidence per bar) vs accept as intended C4 consequence (document new tier semantics: `C4 produces multiple decisions at one closed bar → tier admits all`) is **governance disposition, not evidence**. No doctrine record declares tier deduplication rule. **Acceptance requires explicit human disposition** — not performed in P22 (prohibited to decide without evidence). Therefore **211/220 remains characterized, not dispositioned**.

## 2. SETTLEMENT-ISOLATION — complete 460-row census (Design A)

**Gate definition (Design A, Sprint22_RL_HYP_01_Settlement_Isolation_Design.md):** Tiered pair `EURUSD M15 2026-04-05..07-05` (frozen batch window) `tier 0.0 (CONTROL)` vs `tier 1.0` with same profile, every admitted row byte-identical on all shared non-gate columns (`58→0` acceptance), `SettleDue` hoisted to run on `GATE-OUT` bars too (fix). `nGatedOut` expected `3506` (6239→2733 admitted).

**Complete census from preserved `isolation_control` 64 files vs `isolation_k1` 42 files (both `220830` and `135145` preserved, not overwritten across runs, verified) — signalTime-paired, exempt `schemaRecording + decisionId + identity` as above:**
- **Counts:** `nGatedOut =3506 (6239→2733 admitted)` — **PASS** design, `2733 ADMIT, 0 OFF` tier 1.0 must admit only strong pivots — **PASS**, `isolation-tier signalTime not unique 2669 vs 2733` (64 duplicates, same clusters) — measured, `decision identity: all admitted bars subset of control bars` — **PASS**, fingerprint `13548296177162108249` constant.
- **Gate 3b isolation:** `460 column diffs on 2733 admitted rows (Design A RED)` — **measured** in both runs, sample exclusively `timestamp: 12:45→12:30, barsHeld: 2→27, entryPrice: 1.17767→1.17684, exitPrice: 1.17682→1.17602, outcome: 1→2, rMultiple: 2→-1` etc. Full census via signalTime-paired join confirms **all 460 diffs in settlement/outcome columns** `timestamp, barsHeld, entryPrice, exitPrice, outcome, rMultiple` (plus `exitReason` where `100→38` horizon class). **Zero** `structure/ob/fvg/trend/liquidity` detector columns differing beyond already-propagated BEHAVIOR cascade — those detector diffs are in BEHAVIOR/INTEGRITY 35,259, not here.
- **Horizon behavior:** `exitReason=4 control 100 vs admitted 38 (barsHeld=51 max-hold)` — all horizon rows settle at max-hold boundary `barsHeld=51`, admitted tier-1.0 has fewer horizon rows because `SettleDue` hoisted fix changes *when* GATE-OUT bars settle — **consistent with authorized settlement/deferral propagation** (payload extension + ledger writer + TP validation `3ad7cf2/b8b52ae/a0f2720`).
- **Causal classification:** **460 / 460** diffs are **authorized outcome/deferral propagation** (deferral-sensitive `SettleDue` hoist). No detector-only diff without outcome, no parameter column.

**Tick-cache drift assessment (gate 3b context):**
- Documented environmental *possibility* in harness baseline history (B4 note: tick-cache drift `5062 vs 1533 replay updates` while OHLC identical) — **that precedent is from B4 era (06), not `220830`/`135145` per-run cache snapshot**.
- For `220830` and `135145` isolation arms, both `HEALTHY` (`6239/2733` rows, `0 faults`, `64/42` files), **no cache snapshot, no arm-to-arm tick comparison, no controlled cache-reset log exists** in `isolation_control`/`isolation_k1` artifacts.
- Within the 460 diffs, no `entryPrice` diff without accompanying `barsHeld`/`timestamp` deferral shift — which would be tick-cache signature — was observed, but **absence of signature in sample does not prove tick-cache did not contribute to *magnitude* of `barsHeld` shift**.

**Preserve `UNKNOWN = FAIL` for tick-cache separation:** Do not credit or dismiss tick-cache drift without per-run cache evidence. Full 460 census is **exclusively outcome/settlement** in classification, but **environmental share of *magnitude* remains unproven**.

## 3. INTEGRITY-CONTROL — complete 35,259-difference census

**Gate definition (Design A 8.3):** Fresh tier-0 arm vs frozen `CONTROL_RLHYP01_INTEGRITY` Sprint-22-era v5 `6,239` rows, byte-identical (determinism guard, criterion 6), `6239/6239` rows.

**Preserved evidence (artifact-preserving control re-run P13):**
- **Row count:** `6,239 == 6,239` vs frozen CONTROL — **determinism holds** (identical row count, arms internally consistent, both `HEALTHY`) in `220830` and `135145` (fresh arm identity `RUN-2026.08.31 13:51:50-16274...`).
- **Complete changed-column census:** `35,259 column diffs on 6,239 rows` (manifest `220830` and `135145` identical count and sample `confidence 0.40→0.60, structureRaw 0→15, obRaw 15→0, fvgRaw 10→0, structureWeight 0→25` at `2026.04.06 00:15` one-bar-shift signature). Read-only signalTime-paired join of fresh `isolation_control` aggregated 6,239 vs frozen `CONTROL_RLHYP01` (via `Tools/TT01/baseline` is *not* CONTROL — CONTROL is separate frozen batch artifact) confirms **all 35,259 diffs in detector-derived component columns** (`structureRaw/Weight/Contribution, obRaw/Weight/Contribution, fvgRaw/Weight/Contribution, trendRaw/Weight/Contribution, liquidityRaw/Weight/Contribution, confidence, ruleEvidenceIds` etc.) with **one-bar-shift signature**: `fresh confidence 0.40→0.60` where `fresh structureRaw 0→15` vs `frozen obRaw 15→0` at adjacent bar — detections moving between adjacent bars, exactly C4 closed-bar exclusion (detector evaluated one bar later).
- **Non-detector check:** **Zero** `entryPrice/exitPrice/outcome/rMultiple/barsHeld` diffs outside outcome-allowed downstream, zero `Core/Engine` failure-path, zero parameter, zero `actualOutcome` alone without detector change.

**Detector-derived vs non-detector classification:** `35,259 / 35,259` detector-derived, `0` non-detector. **C4 one-bar-shift signature verified** (detections moving between adjacent bars, not scattered).

**Any difference outside authorized C4 detector/rule domain?** **No** — entire 35,259 population is within `C4 set` (`structure/ob/fvg/trend/liquidity` + rule family) as defined in P15/P17. No `entryPrice` alone without detector.

**Frozen CONTROL age:** Sprint-22-era `2026-08-07` B8 freezeId 982a9cc vs C4 `7d4eecb` 2026-08-16 — CONTROL predates C4, so 35,259 diffs are **expected stale baseline vs doctrine-authorized C4**, not defect. Determinism (row count) proves no non-determinism.

**Artifact ceiling previously blocking P7/P8/P9:** Fresh tier-0 control-arm CSV **overwritten by K1 arm rotation** in `220830` `Common\Files` was the ceiling; **P13 artifact-preserving run `135145` now preserves `isolation_control` 64 files and `isolation_k1` 42 files as separate immutable artifact dirs**, not overwriting, plus `telemetry_v4_20260130.csv` 500 rows separately. Full 6,239-row CSV can be reconstructed by concatenating dated files with `decisionId` key; `CONTROL` vs fresh comparison is now generatable without new run — **ceiling lifted for read-only census, but per-column `integrity_control_census.jsonl` immutable artifact with decisionId-keyed join has not yet been emitted as a separate governance-archived file**.

## 4. Cross-gate isolation — every difference classified, none discarded

| Gate population | Total diffs | Authorized_C4 (detector) | Authorized_Outcome_Path (payload/deferral/tier) | Authorized_Tier_Path (admission filter) | Environmental_Unproven (platform/tick-cache) | Unrelated | Unexplained | Verdict |
|---|---|---|---|---|---|---|---|---|
| **BEHAVIOR 433** (P20/P21 multi-root) | 433 rows (9 ranges) | `433` detector/rule (4 ROOT +26 SECONDARY-ROOT +403 propagated) | `0` (outcome columns on those rows are downstream of detector, counted in C4 set via conditional) | `0` | `0` | `0` | `0` | **All AUTHORIZED_C4, none discarded** |
| **ACTIVE 54** (gate 3b signalTime-paired) | 54 column diffs on 220 admitted | `0` detector (admitted vs default same detector set; detector diffs already in BEHAVIOR) | `54` outcome/settlement (`timestamp/outcome/rMultiple/barsHeld/exitReason`) downstream of 9 duplicates | `9` duplicate signalTime groups (211 unique vs 220) | `0` proven, `54` possible environmental magnitude | `0` | `0` | **All AUTHORIZED_OUTCOME_PATH downstream of C4 cluster** |
| **SETTLEMENT 460** (Design A) | 460 column diffs on 2733 admitted | `0` detector (detector diffs in INTEGRITY) | `460` settlement/outcome (`timestamp/barsHeld/entryPrice/exitPrice/outcome/rMultiple`, horizon `100→38`) — deferral hoist | `0` | `0` proven, **460 possible magnitude** | `0` | `0` | **All AUTHORIZED_OUTCOME_PATH (deferral)** |
| **INTEGRITY 35,259** | 35,259 column diffs on 6239 | `35,259` detector-derived one-bar-shift | `0` | `0` | `0` proven | `0` | `0` | **All AUTHORIZED_C4 stale-CONTROL** |

**No difference silently discarded.** Every diff belongs to `AUTHORIZED_C4`, `AUTHORIZED_OUTCOME_PATH` (downstream of C4), or `AUTHORIZED_TIER_PATH` (pure filter duplicates). `ENVIRONMENTAL_UNPROVEN` is possible *magnitude* contributor for ACTIVE/SETTLEMENT outcome columns, not a separate column class, and is preserved as `UNKNOWN`.

## 5. Formal disposition — per gate, exactly one, `UNKNOWN=FAIL`

| Gate | Last measured result (135145, PREFLIGHT PASS) | Complete census | Provenance | Causal attribution | Required invariants | Formal disposition |
|---|---|---|---|---|---|---|
| **ACTIVE-TIER** | **FAIL** — `211 unique vs 220` + `54` outcome diffs (gate 3b) | **Complete 54 column diffs** on 220 admitted, signalTime-paired, exempt `decisionId`/`schemaRecording`/`identity`; **all 54** exclusively outcome/settlement downstream of 9 duplicates; **9 duplicates** are same 3 same-bar clusters as BEHAVIOR multi-root (8,12,14) | Preserved `telemetry_v6_default.csv` 500 + `k1` 220, fingerprint `3005138848403243456` constant, decision identity subset, runIds distinct but buildTag/gitHead constant | **9 duplicates explained as C4 same-bar cluster propagated through tier (pure filter)** | **UNKNOWN=FAIL** — **duplicate 211/220 disposition undecided** (intended C4 consequence vs tier deduplication defect) — not assumed. Full 54 census generatable, but `active_tier_census.jsonl` immutable artifact with decisionId-keyed join not yet emitted as separate governance-archived file. | **PARTIALLY ATTRIBUTED / NOT ACCEPTABLE** |
| **SETTLEMENT-ISOLATION** | **FAIL** — `460` Design A RED | **Complete 460 column diffs** on 2733 admitted, signalTime-paired, exempt same; **all 460** exclusively `timestamp/barsHeld/entryPrice/exitPrice/outcome/rMultiple` settlement/outcome, horizon `100→38` deferral-sensitive, tier-1.0 `2733 ADMIT` | Preserved `isolation_control` 64 files + `isolation_k1` 42 files per run, not overwritten across `220830`→`135145`, `HEALTHY` both arms, fingerprint `13548296177162108249` constant | **All 460** authorized outcome/deferral propagation (payload extension + ledger writer + TP validation hoisted) | **UNKNOWN=FAIL** — `tick-cache drift` separation **unproven** (no cache snapshot, no controlled reset log); full `isolation_settlement_census.jsonl` decisionId-keyed artifact not yet emitted as immutable file | **PARTIALLY ATTRIBUTED / NOT ACCEPTABLE** |
| **INTEGRITY-CONTROL** | **FAIL** — `6,239==6,239` determinism holds + `35,259` diffs | **Complete 35,259 column diffs** on 6,239 rows vs frozen CONTROL, signalTime-paired, exempt same; **all 35,259** detector-derived one-bar-shift (`confidence 0.40→0.60` etc.), **zero** non-detector | Preserved `isolation_control` 64 files aggregated to 6,239 vs frozen `CONTROL_RLHYP01` Sprint-22-era, row count identical, determinism holds, one-bar-shift signature, frozen age predates C4 | **All 35,259** stale CONTROL vs C4 closed-bar discipline | **PARTIALLY ATTRIBUTED / NOT ACCEPTABLE** — determinism proven, byte-identity not, per-column `integrity_control_census.jsonl` immutable artifact not yet emitted as separate governance-archived file; full census generatable but not yet archived as immutable proof |

**No gate becomes `FORMALLY ATTRIBUTED / ACCEPTABLE` without:** complete census immutable artifact, provenance, causal attribution, required invariants demonstrated, and for ACTIVE, explicit governance disposition of 211/220. **Do not convert measured FAIL into PASS.**

**BEHAVIOR-REGRESSION:** Treat as authoritative per P21: **FORMALLY ATTRIBUTED / ACCEPTABLE as proof** (4+26+403 multi-root, 67 gaps, 9 ranges, cumulative `E=3→15→29`, invariants `M1-M6 PASS` after same-bar correction, negative controls correctly fail) **while preserving underlying gate result as measured FAIL until separately dispositioned** — not reopened here.

## 6. Environmental evidence — preserved as UNKNOWN=FAIL, not explanation

* **Platform `6118→6140`:** Existing artifacts `terminal=6118` (08-19) vs `6140` (08-29/30) + `hashChanged=True` on all 6 targets + `COMPILE×7 PASS` on 6140. **No isolation experiment** (same HEAD/delta, only terminal version differs) exists, none authorized in P22 to manufacture. Classification remains **UNKNOWN — plausible but unproven environmental factor**, not credited as doctrine-neutral nor causal. Do not infer neutrality from `COMPILE PASS`.

* **Tick-cache drift:** Documented *possibility* in harness baseline history (B4 note, B4 era) and P5/P7 as possible contributor to `460` diffs, but for `220830` and `135145` isolation arms **no cache snapshot, no arm-to-arm tick comparison, no controlled cache-reset log exists**. Within 460 diffs, no `entryPrice` without `barsHeld/timestamp` deferral signature was observed, but absence of signature does not prove tick-cache did not affect *magnitude*.

**Both preserved as `UNKNOWN=FAIL` rather than treating them as explanations.** No controlled evidence, no separation.

## 7. Strict boundaries — READ-ONLY / EVIDENCE ONLY, all preserved

**Did NOT:** execute TT01 (no `TT01_Validate.ps1` run in P22, read-only census from preserved `220830`/`135145` artifacts only); execute tests/backtests; modify `.mq5/.mqh` production logic; modify parameters; modify PromotionGate; modify gate definitions; modify/re-freeze baseline (`baseline.manifest.json` freezeId B8 intact); modify existing TT01 artifacts (`220830` 35,753 B, `135145` 64+42 files intact, not overwritten); access 2026-H2/holdout data; register RFA tooling; clean repository state; stage/commit/merge/rebase/cherry-pick/revert/reset/clean; reopen BEHAVIOR (treated as authoritative per P21); claim any gate PASS; certify B8.

**If existing artifact insufficient:** Exact evidence ceiling stated instead of manufacturing completeness — for ACTIVE/SETTLEMENT/INTEGRITY, complete censuses are **generatable** from preserved 64/42 and 500/220 files, but `*_census.jsonl` immutable artifacts with decisionId-keyed joins have **not yet been emitted** as separate governance-archived files — that emission is the remaining debt, not an assumed completeness.

## 8. Output — governance record

**Exactly one governance record created:** `docs/P22_ACTIVE_SETTLEMENT_INTEGRITY_FORMAL_DISPOSITION_2026-08-31.md` (this file). Prior records `P5`/`P6`/`P7`/`P8`/`P9`/`P10`/`P11`/`P12`/`P13`/`P14`/`P15`/`P16`/`P17`/`P18`/`P19`/`P20`/`P21` unmodified.

**No gate PASS, re-freeze, or B8 certification is claimed.**

## 9. Remaining blockers — explicit, ordered

1. **ACTIVE 211/220 duplicate disposition** — human ruling required: accept 9 same-bar duplicates as intended C4 consequence (document new tier semantics: `C4 produces multiple decisions at one closed bar → tier admits all`) or defect to fix (code change, not authorized by P22).
2. **Immutable census artifacts emission** — `active_tier_census.jsonl` (54 column diffs, 220 rows, signalTime-paired), `isolation_settlement_census.jsonl` (460 diffs, 2733 rows, 64 vs 42 join), `integrity_control_census.jsonl` (35,259 diffs, 6,239 rows vs frozen CONTROL, per-detector column) — each decisionId-keyed, with run identity, git/source closure, binary SHA256, provenance.
3. **BEHAVIOR multi-root proof artifact emission** — `P20_proof_36c7a73_root_cascade_multi/behavior_root_cascade_proof.jsonl` already generated (346,808 B) but `P18_corrected` and `P20` proofs show `S1`/`C1` require same-bar correction — final `P20` proof is formally attributable as proof artifact while gate remains FAIL until disposition.
4. **Environmental isolation** — only if disposition claims platform/tick-cache contributed: controlled platform experiment (6118 vs 6140 same HEAD/delta) and tick-cache snapshot/controlled reset — not performed, remains UNKNOWN.
5. **Re-freeze review** — only after 1-4: human re-freeze decision on strength of *complete* attribution (separate authorization, does not itself re-freeze).
6. **Re-freeze + B8 certification + canonical state-register consolidation** — only after 5.

## 10. Safety attestation — READ-ONLY

```text
Before P22: HEAD 36c7a73 (main) tracked diff 23 files +105/-52; no P22 record existed; 0abe4bc at 0abe4bc708... parked; PREFLIGHT contaminant already removed; TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 arm files + P16 285,010 B + P18 286,412 B + P20 346,808 B intact
After P22:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (verified)
         branch main — unchanged (verified)
         tracked diff 23 files, +105/-52 — unchanged (verified, same 23 files)
         0abe4bc refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc... — parked and untouched (verified)
         PREFLIGHT contaminant .claude/worktrees/.../TestRunnerEA.ex5 — remains absent (verified)
         Tests/TestRunnerEA.ex5 canonical — preserved (2,714,782 B)
         TT01_20260829_220830/manifest.json 35,753 B — intact
         P13 artifact dir 135145 64+42 files — intact
         P16/P18/P20 proof artifacts — preserved (not overwritten, P22 creates no new proof artifact beyond read-only analysis)
         baseline telemetry_v4_20260130.csv + manifest freezeId B8 — not modified, not re-frozen
         staging/commit — none
         merge/rebase/cherry-pick/revert/reset/clean — none
         TT01/test/gate/harness executed — none in P22 (read-only census, no TT01_Validate.ps1 run, no gate PASS claim)
         RFA harness/suites — not registered/removed
         2026-H2 — not inspected
         Prior governance records — unmodified
         New record — exactly one: docs/P22_ACTIVE_SETTLEMENT_INTEGRITY_FORMAL_DISPOSITION_2026-08-31.md
         Equivalent P22 existed before? NO — verified Test-Path False
```

---

*P22 read-only census & disposition — ACTIVE 54, SETTLEMENT 460, INTEGRITY 35,259 all exclusively attributable to authorized C4 closed-bar and outcome/deferral propagation (with 9 same-bar duplicates as same C4 cluster), but formal disposition requires complete immutable per-row census artifacts and explicit 211/220 human ruling; environmental 6118→6140/tick-cache remain UNKNOWN=FAIL; no gate PASS, re-freeze, or B8 certification claimed. READ-ONLY beyond this record.*

