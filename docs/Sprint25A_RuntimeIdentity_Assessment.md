# Sprint 25A — Runtime/Build Identity Assessment (25A-RUNTIME-01)

Status: **ASSESSMENT COMPLETE** (2026-08-14) — no implementation performed
Scope: investigate why the MT5/TestRunnerEA runtime validation environment can execute a
binary that may not correspond to the intended source/build artifact; reconstruct the
historical `exp=99 got=0` runtime failure; produce the identity/provenance contract,
remediation options, and acceptance gates.
Identifier: 25A-RUNTIME-01
Constraint: `exp=99 got=0` must NOT be bypassed, weakened, suppressed, or converted to an
unconditional pass. Sprint 24 (EN-01/EN-02/EN-03) is CLOSED and frozen.

---

## 1. Executive summary

The validation chain SOURCE → COMPILE → BINARY → TESTER CONFIG → RUNTIME-LOADED BINARY →
TEST OUTPUT → EXPECTED RESULT contains **no identity binding at any hop**:

- The compile gate validates only the MetaEditor **log text** (`Result: 0 errors, N warnings`);
  it never verifies the `.ex5` artifact was refreshed, and the run manifest records **no
  binary identity** (no hash, size, mtime; `gitHead` does not even identify a dirty worktree).
- `TestRunnerEA.mq5` (18 lines) prints **no build identity** at `OnInit`; the only runtime
  reference to the binary is the tester's own line `testing of Experts\...\TestRunnerEA.ex5
  ... started with inputs` — a **path**, not an identity.
- The run→journal binding uses a "last GRAND TOTAL block" heuristic with no run token;
  journals are read by tail, never archived, and the agent's per-day journal is the only
  record of what executed.
- The one controlled provenance experiment ever done (EN-01 closure, 2026-08-13, hashes
  `564C548C` RED vs `7D20DC01` GREEN) is **not verifiable retroactively**: its journal
  (`20260813.log`) no longer exists, its artifact dir was evicted by `-ArtifactsKeep 3`
  rotation, and its hash values match **no** algorithm applied to any retained binary
  (SHA-256/MD5/CRC32 prefixes of the preserved `.bak` and the current `.ex5` all differ).

**Historical `exp=99 got=0` verdict:** NOT a binary-identity failure. All three 08-12
evening runs (19:23:01 / 19:27:16 / 19:40:35) were **byte-identical RED** (2594/2596,
FAIL [36]+[37]) and are fully explained by the (now CLOSED) EN-01 orientation defect running
through a correctly-loaded **pre-fix** binary. The 08-13 controlled experiment proved the
tester executes freshly compiled binaries (fixed build → GREEN 2601/2601 ×2).

**Structural verdict:** the environment is **capable** of silently executing a binary that
does not correspond to the intended source — no incident was observed, but nothing detects
one: the chain is trust-by-path only, and manual binary operations (the preserved
`.bak20260812_194614`) demonstrably occur in this workspace outside git.

## 2. Repository / build state (verified 2026-08-14)

| Item | Value |
|---|---|
| HEAD | `73e5886` "fix: close EN-03 coordinated trend-flip gate" (2026-08-14 15:16) |
| Branch | `main`; `origin/main` = `0b28d04`; 3 local commits ahead (459bdb3, 7809301, 73e5886) |
| Working tree | clean except untracked: `.opencode/`, `Tests\TestRunnerEA.ex5.bak20260812_194614`, `Tools\ED01\*`, `Tools\SprintRoadmap\`, `Tools\EN03\*` |
| TT01 harness | `Tools\TT01\TT01_Validate.ps1` (676 lines) + `TT01_Validators.ps1`; frozen baselines present |
| Sprint 25 docs | none existed before this file |
| Last TT01 evidence | `Tools\TT01\artifacts\TT01_20260814_144247\manifest.json` — overall PASS (SUITE 2738/2738, REPLAY 500/500, BEHAVIOR 71/71, INTEGRITY 6239/6239) |

Key manifest observation: the 08-14 run compiled the EN-03 **dirty** worktree at 14:48 but
records `gitHead: 7809301` (the EN-03 commit landed at 15:16) — `gitHead` does not identify
the compiled source when the worktree is dirty.

## 3. Exact historical failure reconstruction (`exp=99 got=0`)

### 3.1 The assertion

`Tests\TestAssert.mqh:27` — `TEST_INT_EQ(expected, actual, msg)` prints
`(exp=X got=Y)` on mismatch. The failing assertions (current committed form,
`Tests\unit\TestHistoryEpoch.mqh:284-287`):

```
TEST_INT_EQ(ctx.GetSwingDetector().GetSwingHighCount(), 0,
    "EN-01: TIME_RESET broadcast cleared the swing consumer (orientation contract)");
```

The macro's **expected/actual arguments are reversed at these call sites** (count passed
first). The check is correct (`count != 0` → FAIL) but the printed labels are swapped:
`exp=99 got=0` actually means "the consumer **retained 99** swing entries; expected 0".
`99` = the consumer's baseline population from the 500-bar clockwork fixture
(highs at `i%5==0`, 500/5 → 99 confirmed high/low swings under the detector's window
rules) — i.e., the consumer was **stale**, never cleared, because `TIME_RESET` never fired.

### 3.2 The runs (agent journal `20260812.log`, verified)

| Run start (journal) | INI (mtime) | Result | History Epoch | Failures |
|---|---|---|---|---|
| 19:23:01.464 | TT01_Suite_RED.ini 19:22:42 | `GRAND TOTAL: 2594/2596 passed, 2 failed` | 37/39 | FAIL [36]+[37] `exp=99 got=0` |
| 19:27:16.633 | TT01_Suite_GREEN.ini 19:27:03 | `GRAND TOTAL: 2594/2596 passed, 2 failed` | 37/39 | FAIL [36]+[37] `exp=99 got=0` |
| 19:40:35.447 | TT01_Suite_GREEN2.ini 19:40:22 | `GRAND TOTAL: 2594/2596 passed, 2 failed` | 37/39 | FAIL [36]+[37] `exp=99 got=0` |

- All four historical INIs (`TT01_Suite.ini`, `_RED`, `_GREEN`, `_GREEN2`, and
  `suite_ed01d.ini`) are **byte-identical** (294 bytes, same `Expert=SuperCents_X\Tests\TestRunnerEA.ex5`).
- Suite executes in ~1.2–1.6 s (start→"thread finished").
- The binary that ran at 19:40:35 was compiled at **19:39:30** (`.bak` LastWriteTime) and
  backed up at 19:46:14 (name `..._194614`): `Tests\TestRunnerEA.ex5.bak20260812_194614`
  (2,036,394 bytes).
- The 2596-total fixture lacked the 5 orientation-restore assertions added later (the 08-13
  GREEN fixture totals 2601) — consistent with the evening runs being **pre-fix source,
  pre-fix binary**: runtime behavior and fixture totals both match the pre-fix state.

### 3.3 The controlled provenance experiment (EN-01 closure §4, 2026-08-13)

Per `docs\Sprint24_EN01_Closure.md:45`: pre-fix binary `564C548C...` (17:27:58) → RED;
fresh compile from fixed source `7D20DC01...` (17:39:03) → GREEN `2601/2601` (17:39:19,
17:40:25); `scan#=1` + `centers=[4,498]` proved `Clear()` ran. The closure's conclusion
"stale-binary/cache hypothesis DISPROVEN" stands on that experiment.

### 3.4 What is NOT verifiable retroactively (finding I)

- `Agent-127.0.0.1-3000\logs\20260813.log` **does not exist** (only 20260812.log 26.5 MB and
  20260814.log 1.9 GB, whose first line is 15:01:37 on 08-14). The 08-13 journal evidence
  cited by the closure is gone.
- `Tools\TT01\artifacts\TT01_20260813_174243\` is **empty** — evicted by `-ArtifactsKeep 3`.
- Closure hashes `564C548C` / `7D20DC01` match **no** algorithm on any retained binary:
  `.bak` → SHA256 `BB6392F4...`, MD5 `B20608A8`, CRC32 `8B9D8305`; current `TestRunnerEA.ex5`
  → SHA256 `8ADA6CE0...`, MD5 `9D9EB925`, CRC32 `F1967EC5`. The ex5 embeds compile metadata,
  so byte identity is per-build; the original hash source is unrecoverable.

## 4. Root-cause candidates (A–K) and verdicts

| # | Candidate | Verdict |
|---|---|---|
| A | Stale binary on disk (compile skipped/failed silently, or manual swap) | NOT OBSERVED as an incident; STRUCTURAL RISK confirmed (no artifact verification; manual `.bak` operation proves filesystem-level binary churn happens outside git) |
| B | Wrong path in tester config | DISPROVEN — one canonical ex5; all INIs byte-identical; path stable |
| C | Data-folder mismatch (compile and run in different data folders) | NOT OBSERVED; LATENT — two terminal data folders exist (D0E8 live, DA3A inert with zero MQL5 code); binding verified once manually, never at run time |
| D | Tester sandbox copies (agent keeps its own ex5) | DISPROVEN — agent dirs hold `MQL5\Files` only; no ex5 anywhere under `MetaQuotes\Tester\`; local agent loads from the terminal data folder |
| E | Compile-output mismatch (MetaEditor writes elsewhere) | NOT OBSERVED; LATENT — editor and terminal bind the same install (`C:\Program Files\MetaTrader 5`, no `portable.ini`, `origin.txt` = install path), but no check exists |
| F | Tester-config mismatch (parameters) | DISPROVEN — INIs byte-identical across RED/GREEN/GREEN2/Suite; harness regenerates them from an embedded frozen here-string |
| G | Duplicated EX5 in another resolvable location | DISPROVEN — one canonical copy + one `.bak` (not loadable); DA3A folder empty of code; no ex5 in Program Files |
| H | Build caching by MetaTester | DISPROVEN — 08-13 experiment: two distinct binaries (hash-different) → distinct outcomes on the same agent |
| I | Provenance ambiguity (no record of what ran) | CONFIRMED (structural) — no binary identity recorded anywhere (binary, journal, manifest); closure evidence irreproducible and partly destroyed |
| J | Real defect in source | CONFIRMED for `exp=99 got=0` — the EN-01 orientation defect (closed `459bdb3`); runtime faithfully executed the correct (pre-fix) binary |
| K | Other — journal attribution/retention heuristics | CONFIRMED (structural) — "last GRAND TOTAL" with no run token; tail-reads of multi-GB journals; per-day journal naming (midnight-crossing runs split); no journal archiving; `-ArtifactsKeep 3` evicts evidence |

## 5. Evidence per candidate (locations)

| Evidence | Location | Used for |
|---|---|---|
| Historical FAIL lines `exp=99 got=0` | `%APPDATA%\MetaQuotes\Tester\D0E8...\Agent-127.0.0.1-3000\logs\20260812.log` | J, A |
| Run start/finish + GRAND TOTAL blocks | same journal | F, K |
| Historical INIs (byte-identical) | `Tools\TT01\run\TT01_Suite_{RED,GREEN,GREEN2}.ini`, `suite_ed01d.ini` | F, B |
| Preserved pre-fix binary | `Tests\TestRunnerEA.ex5.bak20260812_194614` (SHA256 `BB6392F4...`) | A, I |
| Current binary | `Tests\TestRunnerEA.ex5` (SHA256 `8ADA6CE0...`) | I |
| Closure provenance claims | `docs\Sprint24_EN01_Closure.md:41-45` | H (claim; evidence gone) |
| Compile logs (Result lines only) | `Tools\TT01\run\compile_*.log` (last compile per target overwrites) | E (partial) |
| Run manifest (no binary identity) | `Tools\TT01\artifacts\TT01_20260814_144247\manifest.json` | I |
| Data-folder binding | `origin.txt` = `C:\Program Files\MetaTrader 5`; no `portable.ini` | C, E |
| Second (inert) data folder | `%APPDATA%\MetaQuotes\Terminal\DA3A484A2A93D32667FF5FC04141004D` (no MQL5 code) | C |
| Agent layout (no ex5 copies) | `MetaQuotes\Tester\D0E8...\Agent-127.0.0.1-{3000,3001}\` | D |
| Macro semantics | `Tests\TestAssert.mqh:27-35`; call sites `TestHistoryEpoch.mqh:284-287` | J (99 = retained population; labels swapped) |

## 6. MT5 binary-loading topology (every possible EX5 copy/location)

```
SOURCE  MQL5\Experts\SuperCents_X\Tests\TestRunnerEA.mq5 (+ includes)
  │  metaeditor64.exe /compile:<abs mq5> /log:<log>   [C:\Program Files\MetaTrader 5]
  ▼
BINARY  D0E8...\MQL5\Experts\SuperCents_X\Tests\TestRunnerEA.ex5   (CANONICAL, single)
  │  terminal64.exe /config:<ini>  [Expert=SuperCents_X\Tests\TestRunnerEA.ex5]
  ▼
RUNTIME local agent 127.0.0.1:3000 — NO copy in agent dirs; loads from terminal data folder
  ▼
OUTPUT  journal <Agent-3000>\logs\yyyyMMdd.log  →  telemetry CSV (Common\Files\Telemetry)
```

Enumerated locations (verified 2026-08-14):

1. `D0E8...\MQL5\Experts\SuperCents_X\Tests\TestRunnerEA.ex5` — canonical, what the tester loads.
2. `Tests\TestRunnerEA.ex5.bak20260812_194614` — backup copy (evidence; not loadable).
3. Terminal data folder `DA3A...` — exists, contains **no** `.ex5` at all (inert).
4. `MetaQuotes\Tester\D0E8...\Agent-127.0.0.1-3000{,-3001}\` — logs/temp/MQL5\Files only; no binary.
5. `C:\Program Files\MetaTrader 5\MQL5\Experts\` — does not exist (no portable mode).
6. Terminal-local `Tester\` under the data folder — bases/config only.

Conclusion: a single canonical binary path today; the chain can only break via (E) a
registration/data-folder change, (A) a failed/skipped/manual binary replacement, or (K)
misattribution of run output — none of which are detected or recorded.

## 7. Provenance requirements (contract)

For every TT01 (and G-flag) run, the evidence must answer four questions:

1. **SOURCE ID** — which exact source state compiled? (git HEAD + worktree hash — dirty
   worktree must be distinguishable from committed state).
2. **BUILD ID** — which binary artifact resulted? (ex5 SHA-256, size, mtime, compile log
   identity, MetaEditor build number).
3. **LOAD ID** — which binary did the tester actually execute? (runtime self-report: build
   tag printed at `OnInit` and captured in the journal; canonical-path uniqueness check).
4. **RUN ID** — which journal output belongs to this run? (run token bracketing the suite
   block; run-start/compile-finish timestamp ordering; journal slice retained with the
   artifact).

## 8. Remediation options (A–G)

| Opt | Measure | Reliability | Complexity | Risk | TT01 compat | Behavioral impact |
|---|---|---|---|---|---|---|
| A | Embedded build identity: `TestRunnerEA` prints build tag (compile timestamp + source fingerprint) at `OnInit`; SUITE gate asserts the expected tag for this run's binary | HIGH (self-verifying at runtime) | LOW | LOW | HIGH (journal line addition) | NONE (test-only print) |
| B | Compile-gate artifact verification: pre/post SHA-256 + mtime per ex5; FAIL if unchanged or not newer than the compile log; record hash/size/mtime | HIGH | LOW | LOW | HIGH | NONE |
| C | Manifest identity block: ex5 hashes (all 6 targets), compile Result lines, MetaEditor/terminal versions, `origin.txt` binding, agent journal path, run window, worktree hash | MED-HIGH | LOW | LOW | HIGH | NONE |
| D | Run-token attribution: unique run token printed around the suite; SUITE gate extracts the block by token instead of "last GRAND TOTAL" | MED-HIGH | MED | LOW | MED | NONE |
| E | Data-folder binding preflight: assert `origin.txt` == install, exactly one canonical ex5, zero ex5 under `Tester\` and the inert data folder; fail fast | MED | LOW | LOW | HIGH | NONE |
| F | Evidence retention: copy the run's journal slice (run-start → GRAND TOTAL) + ex5 copies into the artifact dir; archive policy beyond `-ArtifactsKeep 3` | HIGH | LOW | MED (disk) | MED | NONE |
| G | Binary-determinism experiment (implementation phase only): compile twice, byte-compare; if deterministic, ex5 source-identity hashing becomes viable; else rely on A+B | — | MED | LOW | MED | NONE |

## 9. Recommended minimum robust solution

**A + B + C (+ F)** as the core contract; **E** as a cheap preflight; **D** recommended but
phaseable. The identity checks are additive — they must never alter assertion semantics
(guardrail G9). `exp=99 got=0` remains a genuine RED on the pre-fix binary and is used as
the positive-control in gate G2/G9.

## 10. Acceptance gates (G1–G9)

| Gate | Name | Checks |
|---|---|---|
| G1 | RUN-BINARY SELF-ID | After compile, journal contains the build tag of the freshly compiled binary |
| G2 | STALE-DETECTION | Deliberately restore the pre-fix `.bak` ex5 → harness must FAIL (SUITE RED + identity mismatch), never pass |
| G3 | ARTIFACT-IDENTITY | Manifest ex5 hash == on-disk ex5 hash at run start |
| G4 | NO-DUPLICATE | Exactly one `TestRunnerEA.ex5` in the terminal data folder; zero elsewhere in `Terminal\` and `Tester\` |
| G5 | BINDING | `origin.txt` == install path; editor/terminal versions recorded; inert data folder free of code |
| G6 | ATTRIBUTION | Validated GRAND TOTAL block's run-start ≥ compile-finish; run token present |
| G7 | REGRESSION | Full TT01 with identity checks enabled: all existing gates still PASS (zero behavioral delta) |
| G8 | REPRODUCIBILITY | Retained artifact ex5 + journal slice allow re-verification of identity fields |
| G9 | NO-WEAKENING | `exp=99 got=0` still fails on the pre-fix binary; identity mechanism can never convert a real defect into a pass |

## 11. Research-boundary impact (Sprint 25B/25C)

The runtime-identity contract is test-infrastructure (evidence integrity), not architecture:
no strategy/entry/exit semantics change. Sprint 25B (architecture hardening / AI research
readiness) and 25C (deep architecture review) remain **separate and unauthorized**. The
identity chain is a precondition that makes TT01 a trustworthy gate for those phases —
enabling, not replacing, them.

## 12. Risks

1. False confidence: without B/C the compile gate remains log-text-only (a silently skipped
   compile or manual swap is undetected).
2. Evidence destruction continues: `-ArtifactsKeep 3` already evicted the EN-01 closure
   artifacts; journals are never archived (the 08-13 journal is gone).
3. Journal heuristics: "last GRAND TOTAL" misattribution if a terminal is left running or a
   run crashes before "thread finished"; per-day file naming splits midnight-crossing runs.
4. Multi-GB journal tail-reads (1.9 GB on 08-14) — read cost and truncation sensitivity.
5. Manual binary operations outside git (`.bak` pattern) — provenance must not assume the
   filesystem is immutable.
6. Diagnostics defect: reversed `TEST_INT_EQ` args at `TestHistoryEpoch.mqh:284-287` print
   swapped exp/got labels and muddied the original investigation (fixing the label order is
   a diagnostics-only change, gated behind G7/G9, NOT part of this assessment's scope).

## 13. Implementation scope (NOT authorized)

The following would constitute the implementation phase and require explicit authorization
(assessment → authorization → implementation → validation → closure → commit; push is a
separate authorization):

1. Option A: build-tag print in `TestRunnerEA.mq5` + SUITE gate assertion.
2. Option B: pre/post ex5 SHA-256 + mtime in `Invoke-TT01Compile`.
3. Option C: manifest identity block (hashes, versions, binding, worktree hash).
4. Option D: run-token attribution replacing the "last GRAND TOTAL" heuristic.
5. Option E: data-folder binding preflight.
6. Option F: journal-slice + ex5 retention in artifact dirs; archive policy.
7. Gates G1–G9 validation (incl. G2 stale-detection and G9 no-weakening).
8. Optional G: determinism experiment (two compiles, byte-compare).

## 14. No-touch list (frozen / protected)

- Sprint 24 committed state: `459bdb3` (EN-01), `7809301` (EN-02), `73e5886` (EN-03); the
  three closure docs; all EN-01/02/03 sources.
- Production sources (`Portfolio\`, `Structure\`, `Core\`, `Engine\`, `SuperCents_X.mq5`).
- `Tests\TestRunnerEA.mq5`, `Tests\TestSuite.mqh`, `Tests\TestAssert.mqh` (until authorized).
- Frozen baselines: `Tools\TT01\baseline\telemetry_v4_20260130.csv`, `baseline.manifest.json`,
  `Tools\ED01\artifacts\EURUSD_M15\CONTROL_RLHYP01_INTEGRITY`.
- Frozen INIs and embedded run specs in `TT01_Validate.ps1`.
- Evidence: `Tests\TestRunnerEA.ex5.bak20260812_194614`, agent journals, existing artifacts.
- `exp=99 got=0` semantics: must remain a genuine RED on the pre-fix binary.

## 15. Final

- **ROOT CAUSE: NOT CONFIRMED as an observed binary-identity failure.** The historical
  `exp=99 got=0` runs are fully explained by the CLOSED EN-01 orientation defect executing
  through a correctly-loaded pre-fix binary; the 08-13 controlled experiment demonstrated
  the tester executes freshly compiled binaries. **CONFIRMED as a structural capability
  gap:** the validation environment has no source→binary→run identity binding and no
  retained evidence trail, so it *can* silently execute a non-corresponding binary and
  would not detect it.
- **RECOMMENDED REMEDIATION:** Options A (embedded build identity + runtime self-report),
  B (compile-gate artifact verification), C (manifest identity block), F (evidence
  retention); optional E (binding preflight) and D (run-token attribution); determinism
  experiment G deferred to implementation.
- **REQUIRED VALIDATION:** gates G1–G9, including G2 (stale-detection) and G9
  (no-weakening — `exp=99 got=0` must remain RED on the pre-fix binary).
- **SPRINT 25A STATUS: ASSESSMENT COMPLETE.**
- **IMPLEMENTATION AUTHORIZATION REQUEST: AWAITING USER DECISION.** No implementation was
  performed; no source, test, or harness file was modified; no commit; no push.