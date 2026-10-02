# P35 — CONTROLLED RE-FREEZE EXECUTION B8 → B9

Status: **P35 COMPLETE — CONTROLLED RE-FREEZE EXECUTED B8→B9 — B8 PRESERVED IMMUTABLY — B9 PROVENANCE RECORDED — NO CERTIFICATION**
Date: 2026-09-04
Type: Controlled re-freeze execution per P34 `REFREEZE AUTHORIZATION RECOMMENDED`. B8 preserved as immutable rollback, B9 created only from P34-authorized P32 state (`TT01_20260904_135657`, `467/211/6061`, `8`/`76`/`32769`, `AUTHORIZED_P31` survivor). No `.mq5/.mqh` production logic, parameter, PromotionGate, gate-definition, validator, holdout/research, or optimization change; no B8 overwrite beyond versioned preservation; no prior TT01/P-series artifact overwrite; no 2026-H2 access.
Authorization: Human voice `I authorize P35 — Controlled Re-Freeze Execution.` per P34. HEAD 36c7a73. Branch main. P34 `REFREEZE AUTHORIZATION RECOMMENDED` with contract.

## 1. Objective

Controlled re-freeze `B8 → B9` preserving B8 as immutable rollback/reference baseline, with complete provenance per P34 contract.

**Authorized B9 expected state (P34):**
- BEHAVIOR: 467 expected rows (`500→467` = 33 P31 row-presence)
- ACTIVE-TIER: 211 unique admitted rows (`220→211`), 8 remaining accepted attributable diffs (`timestamp`/`barsHeld`/`entryPrice`/`exitPrice` at `13:00`/`01:00`)
- SETTLEMENT: 76 accepted authorized outcome-path diffs (`94→37` horizon `barsHeld=51`, `64` vs `41` files)
- INTEGRITY: 6,061 expected rows (`6239→6061` = 178 P31 row-presence), 32,769 C4-attributable column diffs (`confidence/structureRaw` etc.) + 178 P31 row-presence
- Environmental: `6118→6140` / tick-cache `UNKNOWN=FAIL` retained, not waived

## 2. Mandatory controls — verified

| Control | Required | Verified |
|---------|----------|----------|
| 1. Preserve B8 immutably | B8 `telemetry_v4_20260130.csv` 693,386 B + `baseline.manifest.json` + `funnel_B8` preserved before overwrite | **PASS** — `Tools/TT01/baseline/B8_rollback_982a9cc_20260807/` 4 files + `preservation.json` (SHA `B5AB5F...` preserved, rollback dir `B8_rollback_982a9cc_20260807`) |
| 2. Create B9 only from P34-authorized state | `467` from `TT01_20260904_135657/telemetry_v6_default.csv`, `211` from `telemetry_v6_k1.csv`, `6061` from `isolation_control` (64 files), `76`/`32769` from same run | **PASS** — B9 `telemetry_v4_20260130.csv` 376,933 B `41F68E...` is byte-identical to P32 default (`41F68E...`), `6061` control byte-identical to P32 `isolation_control` |
| 3. Record complete provenance | baseline SHA, git HEAD, prod/test SHA, run ID, artifact hashes, timestamps | **PASS** — see §4 |
| 4. Record P30 survivor verbatim | global per `signalTime`, highest `confidence`, `1e-9` epsilon, smallest `decisionId` | **PASS** — B9 `baseline.manifest.json` `authorizedState.survivorPolicy` verbatim |
| 5. Preserve rollback B9→B8 | `B8_rollback` + integrity `CONTROL_RLHYP01_INTEGRITY_B8_rollback_982a9cc` (6239 rows) preserved | **PASS** — both rollbacks exist, `B8` 500/6239 vs `B9` 467/6061, rollback restore is `Copy-Item B8_rollback/* baseline/` + `Copy-Item integrity_B8_rollback/* CONTROL_RLHYP01_INTEGRITY/` |
| 6. No unauthorized source/param/PromotionGate/gate/holdout/research/optimization | `git diff --stat` = 26 files (24 P31 carryover + 2 B9 baseline), no `.mq5` beyond P31, no parameter/PromotionGate/validator change | **PASS** — `git diff` 24 + 2 B9, `M` only P31 files + baseline, `P31 dirty 115 lines` unchanged, no holdout `Tools/*holdout*` |
| 7. Preserve P21–P34 evidence | All `TT01_20260829_220830`, `135145`, `135657`, `P16-P34` docs, `P25 11M`, `isolation` arms preserved | **PASS** — `ls` verified intact before and after |
| 8. Do not overwrite B8 or prior TT01/P-series | B8 preserved as `B8_rollback`, prior artifacts not overwritten, new B9 is `baseline.manifest.json` B9 + `telemetry_v4` B9 (versioned) | **PASS** — `B8_rollback` immutable, `TT01_20260904_135657` artifacts untouched |
| 9. Do not access 2026-H2 | `holdout` not accessed (`ls Tools/*holdout*` none) | **PASS** |
| 10. Do not begin optimization | No WFO/parameter/opt, `research_optimization_allowed false` | **PASS** |

## 3. B9 provenance (P34 contract)

| Item | Value |
|------|-------|
| **Baseline ID/version** | `B9` (`freezeId B9`, `previousBaseline B8 982a9cc`) |
| **Baseline SHA** | `B8  B5AB5FEEAD758A814E903F00A0C62A8DF20AE87B7B63E630CF00408EFA0B2735` (693,386 B, 500 rows, 75 cols) → `B9  41F68E8FA5B15CB2AC2F2DADBB878B24CDBF76772748D634C890D21B9B248A44` (376,933 B, 467 rows, 81 cols `v6 = v5+3 provenance`) |
| **New baseline SHA after update** | `41F68E8F...` (467 rows, `firstSignalTime 2026.01.02 04:00`, `lastSignalTime 2026.01.30 23:00`, `headerColumns 81`) |
| **Git HEAD** | `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3` (main, dirty 115 lines P31, no commit) |
| **Production binary SHA** | `SuperCents_X.ex5` `13317094E0BB10C705F2A97273087462761F62AE935627AFBE2486D4CD4C61FB` (548,042 B, 2026-09-04 13:57:18, `buildTag 2026.09.04 13:56:59`, `runId RUN-2026.09.04 13:56:59-233086203`) |
| **TestRunner binary SHA** | `TestRunnerEA.ex5` `E69E51E691383B1A835BF9FEBD14AD2C0C77010B6BB9B2D44B1CAA0BFC92703D` (2,716,064 B, `buildTag 2026.09.04 14:02:20`) |
| **Expected row counts** | `BEHAVIOR 467` (`500→467` -33), `ACTIVE 211` (`220→211` -9, `211/211` unique, `8` residual), `INTEGRITY control 6061` (`6239→6061` -178) |
| **Expected accepted differences** | `ACTIVE 8` (`13:00` 4 cols + `01:00` 1 col, `timestamp`/`barsHeld`/`entryPrice`/`exitPrice`), `SETTLEMENT 76 RED` (`94→37` horizon `51`, `64` vs `41` files), `INTEGRITY 32769` cols (`structureRaw` etc.) + `178` rows |
| **ACTIVE-TIER survivor policy identity** | P30 verbatim: `global per signalTime, highest totalConfidence (ConfluenceResult), 1e-9 tie epsilon, smallest decisionId tie-break, one survivor per signalTime, upstream C4 preserved, discarded traceable as DISCARDED/SUPERSEDED, deterministic/order-independent, no new parameter` (`Entry/ActiveTierSurvivorPolicy.mqh` `ACTIVE_TIER_CONF_TIE_EPS 1e-9`) |
| **C4 attribution identity** | `4 ROOT + 26 SECONDARY_ROOT + 403 PROPAGATED = 433` (`7d4eecb` Swing `maxCenter rates_total-4`, FVG `(3,2,1)`, Liquidity closed-bar, `WeightStructure 25.0`/`20.0`/`15.0`/`15.0`/`10.0`) |
| **Settlement/outcome-path identity** | Design A `SettleDue` hoist to `GATE-OUT` boundary bars, `barsHeld=51` max-hold, fingerprint `13548296177162108249` constant |
| **Environmental disposition** | `6118→6140` / tick-cache `UNKNOWN=FAIL` retained (no waiver, no controlled experiment) — explicitly in `baseline.manifest.json` `authorizedState.environmental` |
| **Provenance** | `P32 runId TT01_20260904_135657`, `run_identity.txt` gitHead `36c7a73`, `buildTag 2026.09.04 13:56:59`, `terminal 6140`, `manifest.json` 30,687 chars, `suite_journal_slice.log` `3344/3344`, `telemetry_v6_default.csv` 7 files merged |
| **Timestamp** | `2026-09-04T14:46:11` (`frozenAt` in `baseline.manifest.json`) |
| **Operator/human authorization** | Human voice `I authorize P35 — Controlled Re-Freeze Execution.` per P34 `REFREEZE AUTHORIZATION RECOMMENDED` (P30 human decision lineage) — not inferred from `UNEXPLAINED=0` |
| **Rollback reference** | `Tools/TT01/baseline/B8_rollback_982a9cc_20260807/` (4 files + `preservation.json`) + `Tools/ED01/artifacts/EURUSD_M15/CONTROL_RLHYP01_INTEGRITY_B8_rollback_982a9cc/` (6,239 rows, 64 files) — immutable, `B9→B8` is `Copy-Item B8_rollback/* baseline/` + `Copy-Item integrity_B8_rollback/* CONTROL.../` |
| **Immutable pre-re-freeze artifact references** | `TT01_20260829_220830` 35,753 B, `TT01_20260831_135145` 64+42, `P16 285k`, `P18 286k`, `P20 346,808 B`, `P23 24k/182k/1,414`, `P24 30,181 B`, `P25 11,283,219 B`, `TT01_20260904_135657` (467/211/6061, 30,687-char manifest, 16 gates) — all retained |

## 4. B8 preservation / rollback verification

- **B8 preserved:** `Tools/TT01/baseline/B8_rollback_982a9cc_20260807/telemetry_v4_20260130.csv` 693,386 B SHA `B5AB5F...` byte-identical to pre-freeze `Tools/TT01/baseline/telemetry_v4_20260130.csv` before copy (verified `Get-FileHash` both `B5AB5F...` before overwrite); `baseline.manifest.json` B8 `freezeId B8` `rows 500` preserved; `funnel_B8.csv/json` preserved; `preservation.json` records `preservedAt 2026-09-04T14:46:00`, `originalSha B5AB5F...`, `reason P35 B8→B9`.
- **B8 integrity preserved:** `Tools/ED01/artifacts/EURUSD_M15/CONTROL_RLHYP01_INTEGRITY_B8_rollback_982a9cc/` 6,239 rows (64 files) — byte-identical to frozen `CONTROL_RLHYP01_INTEGRITY` before update (6239 rows).
- **B9 created:** `Tools/TT01/baseline/telemetry_v4_20260130.csv` 376,933 B SHA `41F68E...` byte-identical to `Tools/TT01/artifacts/TT01_20260904_135657/telemetry_v6_default.csv` 376,933 B `41F68E...` (verified `Get-FileHash` both `41F68E...`); `baseline.manifest.json` B9 `freezeId B9` `rows 467` `previousSha B5AB5F...` `commit 36c7a73` `p32RunId TT01_20260904_135657`; `Tools/ED01/artifacts/EURUSD_M15/CONTROL_RLHYP01_INTEGRITY/` now 6,061 rows (64 files) byte-identical to P32 `isolation_control` (6061 rows).
- **Rollback path B9→B8:** `Copy-Item Tools/TT01/baseline/B8_rollback_982a9cc_20260807/telemetry_v4_20260130.csv Tools/TT01/baseline/telemetry_v4_20260130.csv -Force` + `Copy-Item .../baseline.manifest.json ...` + `Copy-Item .../CONTROL_RLHYP01_INTEGRITY_B8_rollback_982a9cc/* .../CONTROL_RLHYP01_INTEGRITY/ -Force` restores B8 byte-identically (verified hashes). No existing artifact overwritten beyond versioned B9 baseline (B8 rollback is separate dir).

## 5. Repository state

```text
HEAD: 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 (main, no commit in P35)
Branch: main
Dirty: 26 files (24 P31 + 2 B9 baseline: telemetry_v4_20260130.csv 693386→376933, baseline.manifest.json B8→B9)
B8 baseline: preserved as B8_rollback_982a9cc_20260807 (4 files, SHA B5AB5F...), not modified beyond preservation
B9 baseline: telemetry_v4_20260130.csv 376,933 B SHA 41F68E..., baseline.manifest.json B9 467 rows, provenance TT01_20260904_135657
Integrity: B8 rollback 6239 rows preserved, frozen now 6061 rows (B9)
No staging/commit/merge/rebase in P35 (dirty remains, no git add)
P21–P34 artifacts: all preserved, no overwrite (verified ls TT01/artifacts)
No .mq5/.mqh beyond P31 (Portfolio/SymbolContext.mqh survivor remains P31, no new source)
No parameter/PromotionGate/validator/holdout/research/optimization: verified git diff --name-only = 24 P31 + 2 B9, no holdout Tools/*holdout*
```

## 6. Gate / certification status

- **B9 created:** **Yes** — `Tools/TT01/baseline/telemetry_v4_20260130.csv` B9 `467` rows `41F68E...`, `baseline.manifest.json` B9 `freezeId B9`, `Tools/ED01/artifacts/EURUSD_M15/CONTROL_RLHYP01_INTEGRITY` 6061 rows.
- **B9 provenance:** `B9 36c7a73 467/211/6061 41F68E...` with `P32 TT01_20260904_135657` + `13317094...`/`E69E51E6...` + `RUN-2026.09.04...` — recorded in `baseline.manifest.json` `provenance` + `authorizedState`.
- **B8 preservation/rollback:** **Verified** — `B8_rollback` + `integrity_B8_rollback` byte-identical to pre-freeze B8, `B9→B8` is copy-back.
- **Repository state:** `26` files dirty (P31 + B9), HEAD unchanged, no commit.
- **Gate/certification:** **No certification** — `RE-FREEZE EXECUTION ≠ CERTIFICATION`. P32 `overall FAIL` pre-freeze; post-re-freeze certification requires fresh TT01 run at same HEAD `36c7a73` against new B9 baseline to achieve `OVERALL PASS` (`BEHAVIOR 467==467`, `ACTIVE-TIER 211/211 0 diffs`, `SETTLEMENT` `76` accepted as `RED` or `0` `GREEN`, `INTEGRITY 6061==6061`). Do **not** claim EA certified, profitable, or ready for real-time deployment merely because B9 was created.

**Stop after P35** — wait for separate authorization for post-re-freeze certification TT01. No optimization/research until certified.

## 7. Safety attestation

```text
Before P35: HEAD 36c7a73, branch main, dirty 24 P31, baseline B8 500 B5AB5F..., P32 TT01_20260904_135657 intact (467/211/6061), P33/P34 docs present, no B9
During P35: no .mq5/.mqh production logic, no parameter/PromotionGate/gate-definition/validator, no holdout/research, no optimization, no 2026-H2, no artifact overwrite beyond versioned B9 baseline (B8 preserved as rollback)
After P35:  HEAD 36c7a73 — unchanged (no commit), branch main — unchanged, dirty 26 files (P31 + B9 baseline), B8 preserved immutably (4 files + integrity 6239), B9 created (467/211/6061, 41F68E..., B9 manifest), P21–P35 artifacts preserved, no staging/commit/merge/rebase, B9→B8 rollback verified, no holdout/research
P35 = CONTROLLED RE-FREEZE EXECUTION B8→B9 ONLY.
```

---
*P35 controlled re-freeze B8 (500/6239 B5AB5F...) → B9 (467/6061 41F68E..., 211 unique, 8/76/32769 accepted, survivor P30 verbatim) with B8 rollback preserved, provenance recorded, no certification. Stop and await post-re-freeze certification authorization.*
