# Sprint 25B - B25-03A Canonical Execution Identity - Implementation Status

**Phase:** B25-03A (SENIOR-AUTHORIZED) - implementation + validation COMPLETE
**Repository HEAD:** `3c2f02a200da1eaf57e5b689068782997d9dbc0c` (unchanged throughout)
**Method:** TDD (RED stub -> real implementation -> repeated GREEN), dedicated harness `Tools/25B/execsim/`
**Date:** 2026-08-15

---

## 1. Exact files changed

Tracked modifications (the ONLY tracked diff):

| File | Change |
|------|--------|
| `Tests/TestSuite.mqh` | +4 lines: include `unit/TestExecutionIdentity.mqh` and call `RunExecutionIdentityTests()` between the SettlementIsolation and OutcomeTpPolicy suites (unit-test wiring only) |

New untracked files created by this phase (no commit authorized):

| File | Role |
|------|------|
| `Trading/ExecutionIdentity.mqh` | B25-03A deliverable: `CExecutionIdentity` (durable sequence counter, identity/comment build+parse) |
| `Tests/unit/TestExecutionIdentity.mqh` | B25-03A acceptance tests (57 assertions, suites A-F) |
| `Tools/25B/execsim/execsim_identity.ps1` | Validation harness (compile, tester run, journal parse, gates) |
| `Tools/25B/execsim/execsim_validators.ps1` | Validation helpers (frozen-hash, scope, comment-compat static proofs) |
| `Tools/25B/execsim/profiles/identity.ini` | Frozen tester profile (byte-identical to the TT01 suite profile) |
| `Tools/25B/execsim/artifacts/` | Run evidence: `EXSIM_A_20260815134321_Red1`, `..._Green1` (13:57), `..._Green2` (14:05) - each with `gates.jsonl`, `manifest.json`, `suite_journal_slice.log`, `compile.log` |
| `docs/Sprint25B_B25-03A_Identity_Status.md` | This report |

## 2. Exact files untouched

- Production EA (`SuperCents_X.mq5`), all trading logic: `Trading/TradeManager.mqh`, `Trading/PositionManager.mqh`, `Trading/TradeRequestBuilder.mqh`, `Trading/PositionInfo.mqh`, `Trading/PendingOrderInfo.mqh`, `Entry/*`, `Execution/*` (ExecutionRecorder/Ledger not touched), `telemetry/*`, settlement, risk, `OnTradeTransaction`, `MqlTradeResult` capture, deduplication, restart recovery
- Test infrastructure other than the wiring line: `Tests/TestRunnerEA.mq5`, `Tests/TestAssert.mqh`, all pre-existing suites
- TT01 suite: profile, `Tools/TT01/*`, `Tools/TT01/run/gates.jsonl`, artifacts
- ED01, EN03, `Tools/25A/*`, `Tools/SprintRoadmap/`, all docs
- Git HEAD; no commits, nothing staged

## 3. Implementation summary

`Trading/ExecutionIdentity.mqh` exposes the pure identity primitives (no trade execution, no deal recording, no reconciliation):

- `Init(runId, buildTag, counterPath)` - loads the durable counter; missing file = legal fresh start (OK); unreadable/invalid/checksum-mismatched file = `COUNTER_CORRUPT` (refused, never auto-recovers)
- `AllocateSeq(ulong &outSeq)` - reserve-before-use: advances + flushes the counter file, verifies by read-back, and only then returns the sequence
- `SetMonotonicFloor(ulong)` - allocations never go below floor+1 (hook for the B25-03C ledger high-water mark)
- `BuildExecutionId(seq)` -> `EX-<runId>-<seq>`
- `BuildComment(side, decisionId, seq)` -> `SCX-<BUY|SELL>-P<decisionId>#<seq>` (<= 31 chars, side-validated, legacy-compatible)
- `ParseDecisionId(comment)` / `ParseSeqFromComment(comment)` - parse decision id and sequence tail
- `LastSeq()`, `State()`, `StateName()`, `IsUsable()`

Comment tail wiring into `TradeRequestBuilder.mqh` is NOT part of this phase (later-phase boundary, see Section 14).

## 4. Identity invariants

1. Same (runId, seq) -> same executionId (deterministic build).
2. Different seq or different runId -> different executionId.
3. Within a run, allocation never returns the same sequence twice; across runs, a durably-reserved sequence is never re-issued.
4. The sequence never rolls backward: `next = max(lastAllocated, floor) + 1`.
5. `SCX-BUY-P123#456` -> decision id 123; legacy `SCX-BUY-P123` unchanged; broker-appended suffixes tolerated; `#456` -> 456.
6. No sequence is handed out unless its reservation is verifiably durable (read-back).
7. Corrupt/missing-checksum/torn counter -> `COUNTER_CORRUPT`, allocations refused (fail-safe; no guessing, no auto-recovery).
8. Sequences above `EXEC_ID_MAX_SEQ` (99,999,999) -> `BLOCKED_WIDTH`, allocations refused.

## 5. Counter protocol

- Format: two ANSI text lines `seq` / `checksum` where `checksum = IntegerToString((long)(seq ^ 0xA5A5A5A5A5A5A5A5))`, `\r\n`-terminated, under `Common\Files\Execution\execution_seq.dat` (default path).
- Reserve-before-use (design Section 23.2): write seq+checksum, `FileFlush`, `FileClose`, then reopen and verify by read-back; only a verified reservation is returned. A crash after reservation can never re-issue the value.
- Init: `FileIsExist` distinguishes "missing (fresh, OK)" from "exists but unparseable (CORRUPT)". Checksum is always verified; the value is never trusted alone.
- Monotonic floor (`SetMonotonicFloor`) blocks rolled-back/replayed counter files (design Invariant 14 mechanism; B25-03C ledger feeds the high-water mark).
- Counter directory is created if absent (`FolderCreate`, `FILE_COMMON`) - `FileOpen` does not create directories.
- All tests operate on private per-test files under `Common\Files\ExecutionTest\`, never on the production counter path.

## 6. Crash-window results

Design Section 23.2, points 1-10, verified by suites B (persistence), C (fail-safes) and F (crash windows), plus a two-instance restart simulation (B2/B3/F2):

- Crash before allocation: no intent, counter untouched -> state OK, nothing to recover (F1).
- Crash after durable allocation, before use: sequence gap; next run never re-issues the durable value (B2b, B3b, F2b - restart instances continue at durable+1).
- Crash during counter write (torn file): detected as corruption -> `COUNTER_CORRUPT`, allocation refused, never a silently advanced counter (C3, F3).
- Corrupt content (non-numeric) and checksum mismatch: refused (C1, C2).
- External rollback of the counter file: blocked when the floor is set (C5, "next is 6, never 3"); the hazard without a floor is documented by the boundary test C6.

## 7. Comment compatibility results

- `SCX-BUY-P123#456` -> 123, `SCX-SELL-P123#456` -> 123 (D1/D2); legacy `SCX-BUY-P123` -> 123 (D3, D5); broker-appended suffix tolerated (D4); no `-P` token / empty id -> false (D6).
- `ParseDecisionId` mirrors the frozen production parser `CPositionLifecycleManager::ParseEntryDecisionId` (`Entry/PositionLifecycleManager.mqh:597-609`) operation-for-operation: `StringFind("-P")` + `StringSubstr(ppos+2)` + `StringToInteger` (stops at first non-digit). The production parser was NOT modified.
- Round-trip build->parse identical (D9); exact build format `SCX-BUY-P123#456` / `SCX-SELL-P123#456` (D10).
- Worst-case comment `SCX-SELL-P2147483647#99999999` = 29 chars <= 31 (D11; harness static proof re-checks 29 <= 31 and the format regexes).
- Over-long comment refused (D12); unknown side refused (D13).
- Comment consumers were inventoried (producer `TradeRequestBuilder.mqh:59,65`; parser `PositionLifecycleManager.mqh:237,597-609`; raw carriers only; telemetry has no comment columns) - none required modification.

## 8. TDD RED evidence

Artifact: `Tools/25B/execsim/artifacts/EXSIM_A_20260815134321_Red1/` (gates.jsonl, manifest.json, suite_journal_slice.log)

- Built with the deliberately degenerate stub (seq always 0, comment without `#<seq>` tail, parse constant 999) wired into the suite.
- `>>> ExecutionIdentity: 12/57 passed, 45 failed` - the acceptance tests fail exactly where the stub is wrong.
- `GRAND TOTAL: 2872/2917 passed, 45 failed` - grandFailed (45) == categoryFailed (45): the ONLY failures are the ExecutionIdentity category's; no collateral regression in any other suite.
- Harness gates: PREFLIGHT, COMPILE (0 errors), SUITE-EXECUTION-IDENTITY, TDD-RED, GRAND-SUITE, COMMENT-COMPAT-STATIC, FROZEN-EVIDENCE, SCOPE-PROOF - all PASS.

## 9. GREEN run #1

Artifact: `Tools/25B/execsim/artifacts/EXSIM_A_20260815135735_Green1/`

- Built with the real `CExecutionIdentity` implementation.
- `>>> ExecutionIdentity: 57/57 passed, 0 failed`
- `GRAND TOTAL: 2917/2917 passed, 0 failed`
- Harness gates: ALL PASS (compile 0 errors; frozen evidence hashes byte-identical; HEAD unchanged; tracked diff = `Tests/TestSuite.mqh` only).

## 10. GREEN run #2

Artifact: `Tools/25B/execsim/artifacts/EXSIM_A_20260815140505_Green2/`

- Same sources, rebuilt and re-run (counter files from run 1 persist on disk - run 2 exercises the restart path for real).
- `>>> ExecutionIdentity: 57/57 passed, 0 failed`
- `GRAND TOTAL: 2917/2917 passed, 0 failed`
- Harness gates: ALL PASS.

## 11. Determinism result

- Category summary run1 vs run2: `>>> ExecutionIdentity: 57/57 passed, 0 failed` == `... 57/57 passed, 0 failed` (journal timestamp prefixes normalized).
- GRAND TOTAL run1 vs run2: `2917/2917 passed, 0 failed` identical.
- FAIL lines: 0 in both runs; content-normalized FAIL line sets match.
- Harness gate DETERMINISM: PASS.
- The 12/57 RED result was also reproduced identically across two independent RED runs (13:39, 13:43), including the 45/45 collateral-free failure pattern.

## 12. Regression / baseline integrity

- Frozen evidence byte-identical (full SHA256, verified by the FROZEN-EVIDENCE gate in every run):
  - `Tests\TestRunnerEA.ex5.bak20260812_194614` = `BB6392F49DE0C7EC3E83BF515FC730A1D4A4DA40076B73B7D207E8C59252370F`
  - `Tools\TT01\baseline\telemetry_v4_20260130.csv` = `B5AB5FEEAD758A814E903F00A0C62A8DF20AE87B7B63E630CF00408EFA0B2735`
  - `Tools\TT01\baseline\baseline.manifest.json` = `82924B28339526B00B5F25161CB78A3B56B8D3909E4833E35B15EE99D726E3A9`
  - `Tools\ED01\artifacts\EURUSD_M15\CONTROL_RLHYP01_INTEGRITY\telemetry_v5_20260421.csv` = `2E3941EAD446C79197624977000ECCF08041B50C66918C59EB0B5B99745DB27B`
- `Tools/TT01/run/gates.jsonl`: intact, 17 lines.
- Full suite regression: previous GREEN baseline `2860/2860` (TT01 manifest `TT01_20260815_112350`, older gitHead) -> current `2917/2917` = baseline + the 57 new B25-03A assertions. No existing suite failed in any run (RED run: the only 45 failures were the category's own).
- HEAD `3c2f02a200da1eaf57e5b689068782997d9dbc0c` unchanged; tracked diff exactly `Tests/TestSuite.mqh`; untracked set = authorized-new + pre-existing only.

## 13. Known limitations

- `ParseDecisionId` inherits the production parser's exact behavior: a comment like `SCX-BUY-Pabc` yields id 0 with `true` (StringToInteger semantics) - byte-compatible with the frozen production parser; changing it is out of scope.
- The counter is a single file; concurrent allocators (multi-instance EA) are not in scope - a later phase must serialize allocations (the floor hook is the integration point).
- The crash-during-write window degrades to `COUNTER_CORRUPT` (fail-safe refusal), not to auto-recovery; recovery/reset policy is a later-phase concern (B25-03C ledger).
- The harness compile log reports 8 warnings (2 new benign "possible use of uninitialized variable" notes in the test loops where the loop always assigns); 0 errors. Warning count was 8 before and after the implementation swap.
- The diagnostic EA used to locate the read-back bug (`Tests/DiagIdentityEA.mq5`) was deleted; it is not part of the deliverable.

## 14. Next-phase boundary

- B25-03C (execution recording / reconciliation / restart recovery / TradeManager wiring) is NOT authorized by this phase and was NOT started.
- This phase provides the primitives B25-03C needs: durable sequence allocation, `SetMonotonicFloor` (ledger high-water feed), `ParseSeqFromComment` (reconciler input), `EX-<runId>-<seq>` identity.
- The comment tail wiring (`TradeRequestBuilder.mqh`) and `OnTradeTransaction`/settlement integration are explicitly NOT performed here.
- No commit, no push, no merge. Next action: SENIOR REVIEW.

---

## Final Status Block

```
B25-03A:
PASS

IMPLEMENTATION:
COMPLETE

VALIDATION:
PASS

COMMIT:
NOT AUTHORIZED

PUSH:
NOT AUTHORIZED

B25-03C:
NOT AUTHORIZED

NEXT ACTION:
SENIOR REVIEW

STOP.
```
