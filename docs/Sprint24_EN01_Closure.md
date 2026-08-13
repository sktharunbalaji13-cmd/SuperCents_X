# Sprint 24 — EN-01 Closure: HistoryEpoch / Caller-Array Orientation Mutation (DEFECT CLOSED)

Status: **CLOSED** (2026-08-13)
Defect: EN-01 HistoryEpoch orientation (#1) — Sprint 24 engineering-audit Phase 4 backlog, class B, disposition FIX NOW (conditional)
Origin: `docs/Sprint24_EngineeringAudit.md` §5 (EN-01: HistoryEpoch orientation)
Scope owner: engineering correctness (reset-path contract)

---

## 1. Defect summary

`CSymbolContext::Update()` applied `ArraySetAsSeries(..., true)` to the caller's OHLC/time
arrays **by reference**, permanently re-indexing arrays the caller still owns. In the
EN-01 fixture, a fresh chronological feed was silently mutated to series order between
ticks; tick 2's reversal write (`time[R-1]`) then addressed the OLDEST bar, the epoch's
newest-bar timestamp never changed, `TIME_RESET` never fired, and the swing consumers
stayed stale (exp=99 got=0). Masked in production only because `CEngine::Update()`
recreates its arrays per tick — a latent mutation landmine for any reusing consumer.

## 2. Root cause — CONFIRMED

Causal chain (proven by runtime log evidence, agent journal `20260813.log`):
`ArraySetAsSeries(true)` leakage → caller orientation mutation → `time[R-1]` writes
oldest bar → newest epoch timestamp unchanged → `TIME_RESET` absent → stale swing state.
The pre-fix tick-3 scan counter (`scan#=3`, not `scan#=1`) proved `Clear()` never ran:
no broadcast, no reset, in every run — including a freshly compiled binary from the
fixed source, which **disproved the stale-binary/cache hypothesis**.

## 3. Remediation — ACCEPTED (both arms)

| Arm | Change | File |
|---|---|---|
| Production | `Update()` saves all five arrays' original series flags at entry and restores them before returning; functional semantics unchanged | `Portfolio/SymbolContext.mqh` |
| Test hardening | Fixture re-asserts chronological orientation before every `ctx.Update()` call; 5 new no-leak assertions (`ArrayIsSeries == false`) | `Tests/unit/TestHistoryEpoch.mqh` |
| Documentation | Contract comment updated (timeNewest = time[0] NEWEST after ArraySetAsSeries) | `Core/HistoryEpoch.mqh` |

## 4. Validation evidence

| Gate | Result | Evidence |
|---|---|---|
| EN-01 runtime, run 1 | GREEN | `GRAND TOTAL: 2601/2601 passed, 0 failed` (17:39:19) |
| EN-01 runtime, run 2 | GREEN | `GRAND TOTAL: 2601/2601 passed, 0 failed` (17:40:25) |
| History Epoch suite | 44/44 both runs | `History Epoch Tests: 44/44 passed, 0 failed` |
| Post-fix reset behavior | TIME_RESET fires | tick-3 scan `scan#=1` + full rescan `centers=[4,498]` ⇒ `Clear()` executed after reversal |
| Binary provenance | VERIFIED | fresh compile `7D20DC01...` (17:39:03) executed; identical RED on pre-fix `564C548C...` (17:27:58) ⇒ not cache |

Full TT01 regression `TT01_20260813_174243` (git `0b28d04`, no `-AllowDelta`, no
`-Skip`, `-ExpectedRows 500`), exit code 0:

| Gate | Result |
|---|---|
| COMPILE (6 targets) | PASS — 0 errors each |
| SUITE | PASS — 2601/2601 |
| REPLAY | PASS — 500/500 rows, 0 faults, HEALTHY |
| TELEMETRY-CONTRACT | PASS — header 78/78, schema v5, gate OFF sentinels |
| EVIDENCE-REGRESSION | PASS — split invariant 500/500 |
| BEHAVIOR-REGRESSION | PASS — all 71 behavior columns byte-identical to frozen baseline |
| ACTIVE-TIER | PASS — nGatedOut=227, 273 admitted, fingerprint constant |
| SETTLEMENT-ISOLATION | PASS — 3327 admitted rows byte-identical (Design A, 58→0) |
| INTEGRITY-CONTROL | PASS — 6239/6239 rows identical to frozen CONTROL |
| PERFORMANCE | PASS — replay 22.7 s, suite 12.2 s, peak 768 MB |

Artifacts (authoritative evidence, retained): `Tools/TT01/artifacts/TT01_20260813_174243/`
(manifest.json + CSVs + isolation arm dirs).

## 5. Final disposition

- EN-01: **GREEN ×2**
- Full TT01: **GREEN** — zero functional regressions; 71/71 behavior columns and
  6239/6239 integrity rows byte-identical ⇒ Phase 6 remediation introduced no
  collateral behavioral change
- Stale-binary hypothesis: **DISPROVEN**
- Attribution: clean — the only source delta validated was the orientation
  save/restore + fixture hardening
- Commit: **NOT YET MADE** — freeze point recorded, commit pending explicit
  authorization

## 6. Guardrails held

- No source changes during the TT01 validation run
- No auto-fix of failures; no test modification to satisfy validators
- Defect closure is a separate decision from the next architectural/research phase —
  no automatic progression

---

*Sprint 24 EN-01 closure record, 2026-08-13. Companion evidence:
`docs/Sprint24_EngineeringAudit.md` (EN-01 row), `Tools/TT01/artifacts/TT01_20260813_174243/`.*
