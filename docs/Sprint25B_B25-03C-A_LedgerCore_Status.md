# Sprint 25B - B25-03C-A Execution Ledger Core - Implementation Status

- **Sprint:** 25B (Execution Reliability, Sub-project C)
- **Phase:** B25-03C-A (LEDGER CORE ONLY)
- **Authorization:** SENIOR directive (B25-03C-A authorized; B25-03C-B..F NOT AUTHORIZED; commit/push NOT AUTHORIZED)
- **Date:** 2026-08-15
- **HEAD:** `a36ea2381de2b5adbec5e3db897e546ade373080` (unchanged, B25-03B commit)
- **Design base:** `docs/Sprint25B_B25-03C_ExecutionLedger_Design.md` (ACCEPTED after two senior correction rounds)
- **Status:** `B25-03C-A: IMPLEMENTED` / `B25-03C-B..F: NOT AUTHORIZED` / `COMMIT: NOT AUTHORIZED` / `PUSH: NOT AUTHORIZED`

---

## 1. Scope delivered

Two new files (both untracked; tracked diff EMPTY):

| File | SHA-256 |
|---|---|
| `Trading/ExecutionLedger.mqh` (475 lines) | `18C561B205BD77E44EB6EF64F45AFFB56EBD67946B6175B6D44D1C55B58FA937` |
| `Tests/unit/TestExecutionLedger.mqh` (428 lines) | `FEFCBDDF49B2F9B986E738FCC3720DE57C54D56C2B1997EF20BC58AAFC6144B6` |

The ledger core implements, per the accepted design:

- Versioned header `LEDGER|<schema>|<createdRunId>|<buildTag>|<gitHead>|<terminalBuild>|<createdTime>|SHA256(body)`; schema/version/magic/checksum validation on every open (`LedgerOpenOrCreate` refuses corrupted headers - BLOCK).
- Append-only `|`-delimited records `EVT|<eventSeq>|<executionId>|<eventType>|<timestamp>|<stateFrom>|<stateTo>|<payload...>|SHA256(body)` with the payload field opaque (may contain `|`; replayed as the join of all fields after `<stateTo>`).
- SHA-256 via built-in `CryptEncode(CRYPT_HASH_SHA256)`; structural + recompute checksum verification on every parse.
- `eventSeq` derived strictly from the last VALID record in the file (tail+1), never from memory - survives restart/reopen without duplicates.
- Full replay reader `LedgerScan` with five-state classification: `CLEAN`, `HEADER_CORRUPT`, `TORN_TAIL`, `MID_FILE_CORRUPT` (BLOCK), `SEQ_VIOLATION` (BLOCK). Replay stops at the first failing record; nothing after a mid-file corruption is trusted.
- Torn-tail recovery `LedgerRecoverTornTail` (truncate to last valid record + append `CORRUPTION` evidence record + resume contiguously); refuses every state other than `TORN_TAIL`.
- `executionSeq` (inside `EX-<runId>-<executionSeq>`) reserve-before-use semantics: gaps are LEGAL; high-water INTENT floor computed without contiguity demands.
- 9-event vocabulary: INTENT, SENT, REJECTED, UNKNOWN, DEAL_IN, RECONCILED, BLOCKED, CORRUPTION, RUN_END. Unknown types rejected.

NOT implemented (out of scope by directive): TradeManager execution wiring, OrderSend behavior, restart recovery integration, reconciliation, durable dedup integration, broker inspection, OnTradeTransaction, `#<seq>` comment wiring, settlement, telemetry, TT01/ED01.

## 2. TDD evidence

Harness: `metaeditor64` compile -> `terminal64 /config` Strategy Tester run (EURUSD H1, 2026.01.01-01.02, Model 4, GBP 10000, Leverage 200, ExecutionMode 1000) -> agent journal slice -> gates. Temporary runner `Tests/TestExecutionLedgerEA.mq5` compiled and ran both phases and was DELETED after GREEN #2 (authorized diff stays two files). Driver (outside repo): `C:\Users\KA757~1.THA\AppData\Local\Temp\opencode\execsim_b03ca.ps1`.

### RED (defect mirror) - `EXSIM_CA_20260815151853_Red1`

Compile: 0 errors, 0 warnings. Suite: **128/157 passed, 29 failed**. TDD-RED gate PASS: all 26 defect anchors present in the FAIL set, mapped to the D-set of the design assessment:

- D1 header validation skipped: T1c (magic), T1d (schema v2), T1e (tampered header), T1f (malformed), T1g (empty), T10o (reopen refused)
- D2 checksums never verified: T2b (distinctness), T2e, T2f (stub never matches), T3j (tampered record)
- D3 eventSeq from resetting counter: T4l, T4o, T4q, T4t (duplicates after reopen)
- D4 torn tail reported CLEAN: T6f
- D5 mid-file corruption reported CLEAN: T7f, T7k, T7l (nothing after corruption trusted)
- D6 seq holes/duplicates accepted: T8e, T8i
- D7 executionSeq gaps rejected: T9h, T9i
- D8 recovery no-op: T6j (no CORRUPTION record), T6k, T6l, T6n (no resume), T7m (mid-file not refused)

RED run 1 (before hardening) exposed an interplay: with D2 leniency, a torn record that was structurally complete (only checksum missing) was *accepted* as a valid event, so T6k/T6l did not fail in RED (24/26 anchors). The torn-tail injection was hardened to a true interrupted-write truncation (mid-payload cut, trailing fields + checksum never landed). Final RED demonstrates all 26 anchors. The test file was byte-identical from the final RED through GREEN #1 and GREEN #2 (no edits after the T6e calibration; final hash `FEFCBDDF...`).

### GREEN #1 - `EXSIM_CA_20260815152222_Green1`

Compile: 0 errors, 0 warnings. Suite: **157/157 passed, 0 failed**. Gates: PREFLIGHT, COMPILE, SUITE-RUN, SUITE-LEDGER, GRAND-TRUTH, FROZEN-EVIDENCE, SCOPE-B25-03CA - ALL PASS.

### GREEN #2 (determinism) - `EXSIM_CA_20260815152320_Green2`

Compile: 0 errors, 0 warnings. Suite: **157/157 passed, 0 failed**. DETERMINISM gate PASS: normalized journal slices byte-identical (13 lines vs 13 lines; BUILD banner excluded, tab-prefix strip normalization as established in B25-03B).

## 3. Evidence coverage (acceptance blocks T1-T10)

- **T1/T2/T3 - header, checksum, record integrity (pure):** schema/version/magic/checksum validation; SHA-256 determinism + distinctness + 64-char hex; round-trip of every field; checksum-mismatch/malformed/unknown-type rejection.
- **T4 - eventSeq from last valid tail (adversarial D):** 3 appends -> tail 3; reopen -> append continues at 4; empty session (crash-before-append) -> no duplicate, next append at 5; scan verifies strict 1..5 contiguity.
- **T5 - adversarial B + C:** one execution -> 5 events with 5 unique contiguous eventSeq; second execution -> distinct executionId; scan CLEAN.
- **T6 - torn tail (adversarial I):** classification TORN_TAIL (never CLEAN), valid records before the tear replayed; recovery truncates, appends exactly one CORRUPTION evidence record (contiguous at tail+1), scan CLEAN after recovery, next append resumes at tail+2 of the original file.
- **T7 - mid-file corruption (adversarial H):** malformed line and checksum-failed record both -> MID_FILE_CORRUPT; replay stops at corruption; recovery refuses (BLOCK) when the ledger is not TORN_TAIL.
- **T8 - seq violations:** eventSeq hole and duplicate both -> SEQ_VIOLATION.
- **T9 - executionSeq gap acceptance (adversarial A):** EX-RUN-101 + EX-RUN-103 (102 reserved-but-unused) -> scan CLEAN, high-water floor 103, gaps legal; sequence parsing of executionId.
- **T10 - fidelity:** all 8 non-CORRUPTION types round-trip byte-identical payloads, eventSeq 1..8; adversarial G deferred to B25-03C-C - duplicate DEAL_IN records are preserved faithfully by the ledger (round-trip only, no dedup); corrupted header blocks reopen.

## 4. Integrity gates

- FROZEN-EVIDENCE: `TestRunnerEA.ex5.bak20260812_194614`, `telemetry_v4_20260130.csv`, `baseline.manifest.json`, ED01 CONTROL `telemetry_v5_20260421.csv`, `gates.jsonl` (17 lines) - all hashes unchanged in all three runs.
- SCOPE-B25-03CA: HEAD unchanged `a36ea238...`; tracked diff EMPTY; index clean - in all three runs.
- Post-run verification: `git status --porcelain` shows no tracked modifications; only untracked entries; the two authorized new files present; temporary runner and its `.ex5` deleted.
- No production execution-path file was touched: TradeManager.mqh, ExecutionTruth.mqh, ExecutionIdentity.mqh, TradeRequestBuilder.mqh, PositionLifecycleManager.mqh, ActualOutcomeSettler.mqh, Telemetry*, SuperCents_X.mq5, TestRunnerEA.mq5, TT01/ED01 baselines remain byte-identical.

## 5. Deferred (by directive)

- Adversarial case G (duplicate DEAL_IN handling policy) -> B25-03C-C (reconciliation/dedup state machine). Ledger preserves both records.
- Adversarial cases E/F (order/execution identity + deal ticket correlation) and event-payload wiring -> B25-03C-C..E.
- Recovery/reconciliation integration, telemetry decisionId mapping, settlement contexts, `#<seq>` comment wiring -> later authorized phases. Ledger API is the fixed integration surface.

## 6. Final status block

```
B25-03C-A:        IMPLEMENTED
B25-03C-B..F:     NOT AUTHORIZED
COMMIT:           NOT AUTHORIZED
PUSH:             NOT AUTHORIZED
NEXT SENIOR DECISION: REVIEW B25-03C-A EVIDENCE (RED 29-failure anchor set,
   GREEN 157/157 x2 deterministic, torn-tail/corruption/checksum/contiguity/
   gap-acceptance coverage, scope EMPTY tracked diff, HEAD a36ea238)
STOP.
```
