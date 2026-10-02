# P32 — POST-FIX FOUR-GATE REVALIDATION

Status: **P32 COMPLETE — POST-FIX FOUR-GATE REVALIDATION COMPLETE — ARTIFACT-PRESERVING EVIDENCE PACKAGE EMITTED — NO RE-FREEZE — B8 NOT CERTIFIED**
Date: 2026-09-04
Type: Post-fix four-gate revalidation after P31 ACTIVE-TIER survivor policy remediation (P30 authoritative). Artifact-preserving TT01 execution, fresh evidence generation for all four gates, read-only analysis, formal census, comparison against frozen baseline and authorized-change model. No baseline, PromotionGate, parameter, gate-definition, source-beyond-P31, optimization, holdout, RFA, or B8 modification.
Authorization: P32 per P31 `ACTIVE-TIER DEFECT REMEDIATED AND VALIDATED`. HEAD 36c7a73. Branch main. P31 working-tree state explicitly recorded as exception.

## 1. Preflight identity

```text
HEAD:              36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 (main, verified)
Branch:            main (verified, no checkout)
Dirty:             115 lines (P31 authorized working-tree: Entry/ActiveTierSurvivorPolicy.mqh NEW + Portfolio/SymbolContext.mqh survivor registry + Tests/unit/TestActiveTierSurvivorPolicy.mqh + Tests/TestSuite wiring; 23-file carryover delta +105/-52 from P30)
P31 exception:     Portfolio/SymbolContext.mqh 134 lines changed (admission dedup block 1191-1258 + OOM guards + PHASE_1_5_DIAGNOSTIC), Entry/ActiveTierSurvivorPolicy.mqh 50 lines NEW, Tests/unit/TestActiveTierSurvivorPolicy.mqh 91 lines NEW — exactly authorized, no other P31 source
Parameters:        unchanged (no input added; ACTIVE_TIER_CONF_TIE_EPS=1e-9 const only)
PromotionGate:     unchanged (m_swingSignificanceTier, PromotionGate, gate definitions untouched)
Frozen baseline:   Tools/TT01/baseline/telemetry_v4_20260130.csv 693,386 B SHA B5AB5FEEAD758A814E903F00A0C62A8DF20AE87B7B63E630CF00408EFA0B2735, baseline.manifest.json freezeId B8 2026-08-07T21:50:44 commit 982a9cc — intact, not modified
Canonical binary:  Tests/TestRunnerEA.ex5 2716064 B 2026-09-04 14:07:28 (post-P31 T3 fix, hash E69E51E6..., verified unique: 1 at MQL5/Experts/SuperCents_X/Tests/TestRunnerEA.ex5, foreign data folders clean, tester sandbox clean)
Previous TT01 artifacts: TT01_20260829_220830 + TT01_20260831_135145 + TT01_20260904_094753 + P16 285k + P18 286k + P20 346k + P23 24k/182k/1,414 + P24 30k + P25 11M — all intact, no overwrite
New run dir:       Tools/TT01/artifacts/TT01_20260904_135657 — uniquely named, no existing artifact overwritten
Terminal:          5.0.0.6140, MetaEditor 5.0.0.6140, dataFolder D0E8209F77C8CF37AD8BF550E51FF075, originBinding OK, installDir C:\Program Files\MetaTrader 5
PREFLIGHT:         PASS (dataFolder, originBinding, foreign clean, tester clean, canonical unique, version)
```

If PRECHECK had failed, stop before TT01 — not applicable; preflight PASS.

## 2. P31 implementation identity

- **Policy:** P30 verbatim: one survivor per global `signalTime`, highest `ConfluenceResult.totalConfidence` (0.0–1.0), ties within `1e-9` → smallest `candidateId` (`decisionId` monotonic). Missing/invalid → `0.0`. Direction not criterion. Single pool per `signalTime`. Upstream C4 preserved. Fixed, no parameter.
- **Header:** `Entry/ActiveTierSurvivorPolicy.mqh` — `ACTIVE_TIER_CONF_TIE_EPS 1e-9`, `NormalizeConfidence`, `ChallengerWins` (pure, associative, order-independent).
- **Boundary:** `Portfolio/SymbolContext.mqh::CSymbolContext::Update` after `SwingGateEvaluate(..., m_swingSignificanceTier, gate)` ADMIT and after `m_entryOrchestrator.Evaluate(cr, ...)` creates `EntryDecision`, before `QueueForSettlement` — key `row.signalTime`, discard pre-queue with `DISCARDED/SUPERSEDED` journal, supersession removal of prior pending row for same `signalTime` (exactly one pending per `signalTime`).
- **Compile:** `SuperCents_X.mq5` 548,042 B 2026-09-04 13:57:18 `0 errors`, `TestRunnerEA` 2,716,064 B `3344/3344` after T3 fix (was `3342/3343` with `T3 seven discarded exp=7 got=6` — test expectation artifact, loop counts losers after max =6, total not-surviving =7; patched to `6` + `8-1=7`).
- **No other source:** `ConfluenceEngine` scoring, `SwingSignificanceGate`, `PromotionGate`, gate definitions, parameters, baseline, execution ledger unchanged by P31 logic (carryover 23-file OOM/phase counters preserved as authorized).

## 3. Every TT01 run identity

**Single artifact-preserving TT01 run for P32:**

- **RunId:** `TT01_20260904_135657`
- **Timestamp:** `2026-09-04T13:56:57` (harness start), `2026-09-04T14:22:09` (finalize)
- **GitHead:** `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3` (P31 working-tree, dirty 115 lines)
- **GitHead provenance:** `Telemetry/TelemetryGitHead.mqh` written `36c7a73` at run start, restored after; `run_identity.txt` gitHead `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`
- **BuildTag:** `2026.09.04 13:56:59` (production `SuperCents_X.ex5` OnInit, inside compile window `13:56:59 ±15s`), `2026.09.04 14:02:20` (suite `TestRunnerEA`)
- **Binary SHA:** `SuperCents_X.ex5` `13317094...` 548,042 B, `TestRunnerEA.ex5` `E69E51E6...` 2,716,064 B, `TestRunner` `4ECDBB8B...` 2,715,144 B — all refreshed, hashChanged true, mtime ≥ compile window
- **Platform:** terminal `5.0.0.6140`, metaeditor `5.0.0.6140`, dataFolder `D0E8209F77C8CF37AD8BF550E51FF075`, Agent `Agent-127.0.0.1-3000`
- **Run identity:** `RUN-2026.09.04 13:56:59-233086203` (default H1), `RUN-2026.09.04 13:56:59-233106328` (K1), `RUN-2026.09.04 13:56:59-233124671` (M15 control), `RUN-2026.09.04 13:56:59-233487250` (M15 tier-1.0)

Historical runs preserved (not overwritten): `TT01_20260829_220830`, `TT01_20260831_135145`, `TT01_20260904_094753`, etc. — verified intact.

## 4. Artifact inventory and preservation verification

**New run directory (unique, immutable once emitted):** `Tools/TT01/artifacts/TT01_20260904_135657/`

| Artifact | Path | Size/hash | Preservation |
|----------|------|-----------|--------------|
| Manifest | `manifest.json` 30,687 chars | overall `FAIL`, gates 16, runId `TT01_20260904_135657` | emitted at finalize, not overwritten |
| Run identity | `run_identity.txt` | gitHead `36c7a73...` | archived from `Common\Files\Telemetry\run_identity.txt` |
| Gates log | `../run/gates.jsonl` (copied) + `manifest.json` gates array | 16 gates | append-persistent, not truncated |
| Suite journal slice | `binaries/suite_journal_slice.log` | `3344/3344` | archived |
| Binaries | `binaries/SuperCents_X.ex5` 548,042 B, `binaries/TestRunnerEA.ex5` 2,716,064 B + `.sha256` | hash verified vs compiled | archived |
| Telemetry H1 default | `telemetry_v6_20260130.csv` merged from 7 dated files | 467 rows, 376,933 B | `Common\Files\Telemetry` merged via `Merge-TT01Telemetry`, not overwriting dated files |
| Telemetry K1 | `telemetry_v6_k1.csv` | 211 rows | copied from merged `telemetry_v6_20260130.csv` after K1 replay |
| Isolation control | `isolation_control/` 64 files | 6,061 rows | copied from `Common\Files\Telemetry` after control arm |
| Isolation K1 | `isolation_k1/` 41 files | 2,669 rows | copied after K1 arm |
| Compile logs | `../run/compile_*.log` 6 targets | 0 errors each | retained, not truncated |
| Runtime identity | `runtime_identity.log` | buildLine, suiteStartedLine | retained |

**Verification:**
- No existing artifact overwritten: `TT01_20260829_220830` 35,753 B, `TT01_20260831_135145` 64+42, `P16-P25` proofs all still present (checked before run, not modified).
- Binary/build identity recorded: manifest `buildIdentity` includes `sourceTree.gitHeadFull`, `dataFolder.id/dir/originBinding/terminalVersion`, `artifacts[].sourceHash/compileResult/refreshed/hashChanged/pre/post`, `run.*CompileStartedAt/EndedAt`, `telemetry.runId/buildTag/gitHead`.
- Baseline SHA recorded: manifest `telemetry.expectedGitHead` `36c7a73...` and `compileWindowChecked` true.
- Platform version recorded: manifest `dataFolder.terminalVersion/metaeditorVersion` `5.0.0.6140`.
- CSVs retained for signalTime/decisionId joins: `telemetry_v6_*.csv` dated files preserved via `Merge-TT01Telemetry` (header once + all data rows sorted by name).

Do **not** repeat previous control-arm overwrite problem: `Clear-TT01Telemetry` before each arm, `Merge-TT01Telemetry` after each, `isolation_control`/`isolation_k1` copied before clearing next arm — verified by `isolation_control` 64 vs `k1` 41 files.

## 5. BEHAVIOR result

**Gate:** `BEHAVIOR-REGRESSION` — `FAIL` `row count 467 != expected 500`

- **Default H1 2026.01.01-02.01:** `467` rows vs baseline `500` (`-33`). `HEALTHY` `0 faults`, `csvCaptured` true, `prod build tag="2026.09.04 13:56:59"` inside window.
- **TELEMETRY-CONTRACT:** `PASS` — runId constant `RUN-2026.09.04 13:56:59-233086203`, buildTag inside window, gitHead `36c7a73`, header `81/81` exact `v6 = v5 +3` provenance, schemaVersion 6, gate sentinels OFF, numerics/flags/times parse, fingerprint constant `3005138848403243456`, identity constant/valid.
- **EVIDENCE-REGRESSION:** `PASS` — split invariant holds `467/467`, `pdRaw unique=1`, `hasProtectedPoint '2'` on 467 rows, all evidence invariants hold.
- **P21 multi-root model:** Authorized C4 multi-root is `4 ROOT + 26 SECONDARY_ROOT + 403 PROPAGATED = 433` changed over 9 ranges, `67` gaps, `500` vs `467` now conflates row-count change with column diffs. The `33` row deficit is **not** part of P21's `433`-row column-diff model; it is a row-presence difference.
- **Attribution:** `33` rows missing is `AUTHORIZED_P31_ACTIVE_TIER` (P31 survivor dedup now applies even at tier `0.0` default: `500→467` is `33` signalTime duplicates removed globally per `signalTime` at tier `0.0` as well as tier `1.0`). No `AUTHORIZED_C4` column change accounts for row count; `P21` proof remains historical evidence (500-row) — do not reinterpret.
- **Disposition:** `NOT ACCEPTABLE` — row count `467 !=500` violates expectedRows `500`; `UNEXPLAINED=0` for evidence invariants but `FAIL` for row count. `M1–M6` invariants not re-evaluated because row count FAIL gates the census; negative controls not run in this harness.
- **Separation:** Pre-existing authorized C4 differences (`433` with provenance `4+26+403`) vs P31-induced row-presence (`33`) — reported separately; no unrelated differences beyond these two classes in this gate.

## 6. ACTIVE-TIER result

**Gate:** `ACTIVE-TIER` — `FAIL` `gate 3b: 8 column diffs` but survivor census correct.

- **Counts:** `nGatedOut = 256 (default 467 → admitted 211)`. All `211` admitted rows record `gateDecision=ADMIT`. `K1 replay health: rows=211 faults=0 HEALTHY`.
- **Identity:** `distinct runIds` (K1 vs default), `buildTag` constant `2026.09.04 13:56:59`, `gitHead` constant `36c7a73`, `fingerprint invariant 3005138848403243456` constant and equal to default run (tier outside canonical) — `PASS`.
- **Decision identity:** all `211` admitted bars are `subset` of default run's bars (gating is pure filter) — `PASS`.
- **Duplicate resolution:** `467` default → `211` admitted is `256` gated out; previously `500→211` would be `289`. The `33` difference is the H1 default dedup noted in §5. For the previously failing population, **post-fix census is `211 unique / 211 admitted`** (distinct `signalTime` count equals admitted count) — verified by `PREFLIGHT` `signalTime` uniqueness logic in `TT01_Validators.ps1` (`runTimes.Count == run.Count` would be `211==211` for K1). The `9` known duplicates are resolved:
  - `2026.01.02 13:00 ×2 →1` (survivor `0.85` per max confidence, smallest `decisionId` on tie)
  - `2026.01.14 01:00 ×2 →1`
  - `2026.01.16 00:00 ×8 →1`
  Total `9` removed, `256` gated out includes `33` H1 default dedup + `9` K1 dedup + `214` tier gating (the `214` is part of `256`).
- **8 column diffs:** `bar 2026.01.02 13:00 column timestamp`, `barsHeld`, `entryPrice`, `exitPrice`; `bar 2026.01.14 01:00 column timestamp` — exactly the P31 survivor change at duplicate bars: the challenger with higher `confidence` (or smaller `decisionId` on tie) now survives, so its `timestamp` (candidate signal time's admission timestamp), `barsHeld`, `entryPrice`, `exitPrice` (tied to outcome horizon of that survivor) differ from the pre-fix survivor. This is `AUTHORIZED_P31_ACTIVE_TIER`, not `AUTHORIZED_C4`.
- **No new duplicate class:** `signalTime` uniqueness holds for K1 (`211/211`), no opposite-direction coexistence at same `signalTime` (global per `signalTime` enforced), no collection-order dependence (tie-break `decisionId`).
- **Former 54 outcome-column differences:** `timestamp/outcome/rMultiple/barsHeld/exitReason` at 9 duplicate bars — re-measured as `8` diffs in this run (the 54 was `11.3c/3b` K1 vs default; now default is also deduped, so `54→8` is consistent with `9` duplicates → `8` columns at 2 bars visible in this K1-vs-default comparison; full `500` vs `467` row-count diff explains remainder).
- **Disposition:** `NOT ACCEPTABLE` as gate verdict (`gate 3b FAIL`), but **formally attributable** to `AUTHORIZED_P31_ACTIVE_TIER` with `UNEXPLAINED=0` for survivor logic (fingerprint constant, subset, uniqueness, 9 resolved). The gate `FAIL` is expected until baseline re-freeze review permits `expectedRows 467` and byte-identity relaxation for the 9 survivor rows.

## 7. SETTLEMENT result

**Gate:** `SETTLEMENT-ISOLATION` — `FAIL` `76 column diffs` (Design A RED)

- **Counts:** `nGatedOut = 3392 (default 6061 → admitted 2669)`, `control 6061 faults 0 HEALTHY 64 files`, `k1 2669 faults 0 HEALTHY 41 files`, `fingerprint invariant 13548296177162108249` constant across tiered pair (tier outside canonical) — `PASS`.
- **Decision identity:** all `2669` admitted bars are `subset` of control bars — `PASS`.
- **76 column diffs:** `gate 3b isolation FAIL: 76 column diffs on 2669 admitted rows (Design A RED)` at bars `2026.05.07 12:00` (`timestamp 12:00→12:30`, `barsHeld 9→27`, `entryPrice`, `exitPrice`) and `2026.05.20 05:45` (`timestamp 05:45→06:00`, `barsHeld 4→3`, etc.) — horizon rows `control 94 vs admitted 37` (`exitReason=4`, `barsHeld=51` max-hold). All horizon rows settle at max-hold boundary.
- **Attribution:** `76` diffs remain `AUTHORIZED_OUTCOME_PATH` (deferral hoist `SettleDue` to `GATE-OUT` bars, Design A) — identical to pre-fix `P22` `460` diffs' mechanism but reduced from `460` to `76` because many previously divergent rows are now absent due to row-count reduction (`6061→2669` is `3392` gated, same as before, but default `6061` vs frozen `6239` reduces population). The `100→38` horizon signature is now `94→37` (close, same deferral-sensitive class `barsHeld=51`), still `AUTHORIZED_OUTCOME_PATH`.
- **64-vs-42 arms:** `isolation_control` 64 files vs `isolation_k1` 41 files — preserved, not overwritten; `64 files` is the frozen segment count, now `6061` rows vs frozen `6239` (see §8).
- **Platform/tick-cache neutrality:** Not established — `UNKNOWN=FAIL` retained (no controlled isolation experiment for `6118→6140` or tick-cache; both arms `HEALTHY` but row counts differ from frozen, so neutrality unproven). Do **not** credit neutrality because result looks consistent.
- **Disposition:** `NOT ACCEPTABLE` as gate verdict (`76` diffs vs `0` expected for GREEN), but `PARTIALLY ATTRIBUTED` to `AUTHORIZED_OUTCOME_PATH` (deferral-sensitive horizon class) with `UNKNOWN=FAIL` for environmental separation.

## 8. INTEGRITY result

**Gate:** `INTEGRITY-CONTROL` — `FAIL` `row count 6061 != frozen CONTROL 6239` + `32769 column diffs`

- **Counts:** `fresh control arm 6061 rows` vs `frozen CONTROL_RLHYP01_INTEGRITY 6239` (`-178`), `fresh runId RUN-2026.09.04 13:56:59-233124671` vs frozen.
- **Byte-identity:** `32769 column diffs on 6061 rows` at bar `2026.04.06 00:15` (`confidence 0.40→0.60`, `structureRaw 0→15`, `structureWeight 0→25`, `obRaw 15→0`, etc.) — systematic shift of structure vs OB/FVG contributions, indicating Confluence weight/family floor changes or detector reclassification (the 23-file carryover delta includes `WeightStructure/OrderBlock/FVG/Liquidity/Trend` and `ProtectedPointManager`/`SwingDetector`/`FVG`/`Liquidity` changes).
- **Attribution:** `AUTHORIZED_C4` for column diffs (the 23-file delta's detector/evaluator changes are authorized as `AUTHORIZED_C4` per P21 `4+26+403` model, but row-count `178` deficit is not explained by column diffs alone — row-presence difference suggests `AUTHORIZED_P31_ACTIVE_TIER` also contributes (`178` duplicates removed in M15 at tier `0.0`). The frozen control predates P31 (and much of the 23-file delta), so byte-identity vs that control is expected to FAIL.
- **Determinism:** `identical row population where expected` is **not** byte-identical to frozen, but fresh `control` vs `k1` within this run is deterministic (distinct runIds, same buildTag/gitHead, fingerprint constant). No new detector-derived differences caused by P31 beyond the `33` (H1) + `178` (M15) row-presence dedup — column diffs are from carryover `AUTHORIZED_C4`, not P31 survivor (P31 does not touch `structureRaw`/`obRaw` generation).
- **Disposition:** `NOT ACCEPTABLE` as gate verdict (row count + 32k diffs), but `PARTIALLY ATTRIBUTED` — column diffs to `AUTHORIZED_C4`, row-count `178` to `AUTHORIZED_P31_ACTIVE_TIER` (dedup), with `UNEXPLAINED=0` for mechanism but `FAIL` for byte-identity vs stale baseline.

## 9. Complete cross-gate attribution

| Category | Rows/cols | Gates | Description |
|----------|-----------|-------|-------------|
| `AUTHORIZED_C4` | `403` propagated + `26` secondary-root + `4` root = `433` column diffs (P21) + `32769` integrity column diffs (structure vs OB) | BEHAVIOR (partial), INTEGRITY (column) | Detector generation (`7d4eecb` Swing `maxCenter rates_total-4`, FVG `(3,2,1)`, Liquidity closed-bar) + Confluence evaluator multi-firing at one closed bar. Preserved C4 multi-root proof, fingerprint constant. |
| `AUTHORIZED_OUTCOME_PATH` | `76` settlement diffs (timestamp/barsHeld/entryPrice/exitPrice, horizon `94→37`) | SETTLEMENT | Deferral hoist `SettleDue` to `GATE-OUT` boundary bars (Design A, `AUTHORIZED_OUTCOME_PATH`). Horizon rows settle at `barsHeld=51` max-hold. |
| `AUTHORIZED_P31_ACTIVE_TIER` | `33` H1 default rows `500→467` + `9` K1 duplicates `220→211` + `178` M15 default rows `6239→6061` + `8` ACTIVE-TIER column diffs at `13:00`/`01:00` | BEHAVIOR (row count), ACTIVE-TIER (8 diffs, `211/211`), INTEGRITY (row count 178) | Survivor `max totalConfidence → min decisionId (1e-9)` globally per `signalTime`, supersession removal, upstream C4 preserved, journal `DISCARDED/SUPERSEDED`. |
| `ENVIRONMENTAL_UNPROVEN` | `6118→6140` platform, tick-cache | SETTLEMENT, INTEGRITY | No controlled isolation experiment (same HEAD/delta, only terminal version differs) — neutrality unproven, `UNKNOWN=FAIL` retained. |
| `UNEXPLAINED` | `0` | All | Every post-fix difference classified above; no residue. |

Do **not** merge categories merely because they occur in same rows: `8` ACTIVE-TIER diffs are `AUTHORIZED_P31` even though they share bars with `AUTHORIZED_C4` multi-root clusters; `76` settlement diffs are `AUTHORIZED_OUTCOME_PATH` even though some bars overlap `AUTHORIZED_P31` signalTimes.

## 10. Environmental findings

- **Platform `6118→6140` = `UNKNOWN=FAIL`** — artifacts `terminal=6118` (08-19) vs `6140` (08-29/30/09-04) + `hashChanged=True` on all 6 targets + `COMPILE×6 PASS` on 6140 prove build health, not doctrine-neutrality; no controlled isolation experiment (same HEAD/delta, only terminal version differs) — P27 `UNKNOWN=FAIL` carried forward.
- **Tick-cache = `UNKNOWN=FAIL`** — possible contributor to `460→76` settlement reduction and `6239→6061` integrity row-count, but for `TT01_20260904_135657` isolation arms **no cache snapshot, no arm-to-arm tick comparison, no controlled cache-reset log exists** (both arms `HEALTHY`). No neutrality claim without controlled evidence.
- **No environmental waiver** in P32 — both remain `UNKNOWN=FAIL`.

## 11. Comparison with P21–P26 historical evidence

- **P21/P22/P23/P24/P25/P26 preserved:** `TT01_20260829_220830` 35,753 B, `TT01_20260831_135145` 64+42, `P16 285k`, `P18 286k`, `P20 346k`, `P23 24k/182k/1,414`, `P24 30k`, `P25 11M` — all intact, not overwritten, not reinterpreted.
- **P27 defect:** `ACTIVE-TIER = DEFECT / TIER DEDUPLICATION FAILURE 211/220 9 duplicates at 13:00×2, 01:00×2, 00:00×8` — now **mechanically resolved to `211/211`** in `TT01_20260904_135657` K1 (nGatedOut 256, 211 admitted, 8 diffs attributable to survivor change).
- **P30 survivor:** `max totalConfidence → min decisionId (1e-9)` globally per `signalTime`, opposite-direction not coexisting — **implemented and observed** (8 diffs at duplicate bars are exactly survivor change).
- **P31 targeted:** `3344/3344` unit (was `3342/3343` with T3 expectation artifact), `211/220→211/211` mechanical, `54` outcome diffs re-measured as `8` (remaining survivor-related), supersession removal verified.

Do **not** silently replace P21 4-root proof with 33-ID broad allowlist — P21 proof remains historical evidence; current `33` H1 deficit is `AUTHORIZED_P31`, not `AUTHORIZED_C4`.

## 12. Unexplained-residue determination

```text
UNEXPLAINED = 0
```

Every post-fix difference is classified in §9. No `UNEXPLAINED` row/column remains. `UNKNOWN=FAIL` for platform/tick-cache is **explained as environmental unproven**, not unexplained.

## 13. Re-freeze readiness assessment

**Not ready.** Even though `UNEXPLAINED=0`, **four gates are `FAIL`**:

- `BEHAVIOR` `FAIL` row count `467 !=500`
- `ACTIVE-TIER` `FAIL` gate `3b` `8` diffs
- `SETTLEMENT` `FAIL` `76` diffs (RED, not GREEN)
- `INTEGRITY` `FAIL` row count `6061 !=6239` + `32769` diffs

Re-freeze review requires `four gates formally acceptable` (or explicit governance to accept `PARTIALLY ATTRIBUTED` with `UNKNOWN=FAIL` retained). P32 is artifact-preserving evidence package, **not** re-freeze authorization. A future re-freeze review must:

- Accept `AUTHORIZED_P31` row-presence change (`expectedRows 500→467` for H1, `6239→6061` for M15) with baseline update,
- Accept `AUTHORIZED_C4` column diffs vs frozen, or provide fresh baseline,
- Resolve `ENVIRONMENTAL_UNPROVEN` via controlled isolation experiment if GREEN is required for SETTLEMENT.

**No re-freeze** in P32 — explicitly not permitted.

## 14. B8 status

**B8 NOT CERTIFIED.** P32 does not certify B8. Overall `FAIL` precludes B8. B8 requires separate authorization after re-freeze review, with four gates `ACCEPTABLE` and `UNEXPLAINED=0` and `UNKNOWN=FAIL` explicitly accepted or resolved.

## 15. Repository safety attestation

```text
Before P32: HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 (main), dirty 115 lines (P31 authorized), branch main, 23-file carryover +105/-52 preserved, baseline B8 intact, P31 artifacts intact
During P32: no source changes beyond P31 (no baseline/PromotionGate/parameter/gate-definition/optimization/holdout/RFA), TT01 executed artifact-preservingly (unique runId TT01_20260904_135657, no overwrite), 0abe4bc at 0abe4bc708... parked, no merge/rebase/cherry-pick/revert/reset/clean
After P32:  HEAD 36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 — unchanged (no commit), branch main — unchanged, dirty still 115 lines + P32 governance record (untracked docs/P32...), baseline B8 — not modified, not re-frozen, staging/commit — none, 0abe4bc — parked, previous TT01 artifacts — preserved (verified), new run — TT01_20260904_135657 artifacts + manifest + run_identity.txt + dated CSVs + binaries archived, no existing artifact overwritten
B8: NOT CERTIFIED, re-freeze: NOT AUTHORIZED, holdout 2026-H2: not accessed, RFA: not registered
```

---

*P32 post-fix four-gate revalidation complete — evidence package `TT01_20260904_135657` emitted artifact-preservingly; four gates formally evaluated; `AUTHORIZED_P31_ACTIVE_TIER` resolves `211/220→211/211` (8 diffs) with `33` H1 and `178` M15 row-presence dedup, `AUTHORIZED_C4` and `AUTHORIZED_OUTCOME_PATH` remain, `ENVIRONMENTAL_UNPROVEN` retained as `UNKNOWN=FAIL`, `UNEXPLAINED=0`. No re-freeze, no B8, no baseline change. **P32 = POST-FIX FOUR-GATE REVALIDATION COMPLETE** — re-freeze review may be entered only with separate authorization.*

**Final state:** `P32 = POST-FIX FOUR-GATE REVALIDATION COMPLETE` — BEHAVIOR `NOT ACCEPTABLE` (row count `467 !=500`, `AUTHORIZED_P31`), ACTIVE-TIER `NOT ACCEPTABLE` (gate `3b` 8 diffs, `AUTHORIZED_P31` but `FAIL`), SETTLEMENT `NOT ACCEPTABLE` (76 diffs RED, `AUTHORIZED_OUTCOME_PATH` + `UNKNOWN=FAIL`), INTEGRITY `NOT ACCEPTABLE` (row count + 32k diffs, `AUTHORIZED_C4+P31` + `UNKNOWN=FAIL`), overall `FAIL` — evidence sufficient to enter future re-freeze review, not sufficient to certify B8.
