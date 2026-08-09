# Sprint 20 — GR02: Observability Epic — GR02A/GR02B Decision & Evidence

- **Plan:** `docs/Sprint20_Engineering_Plan.md` (GR02 row)
- **GR02A commit:** `afdd6cb` (live-stage observability wiring)
- **GR02B tools:** `Tools/GR02/gr02_funnel.py` + `Tools/GR02/reports/` + golden `Tools/TT01/baseline/funnel_B8.{csv,json}`
- **User scoping (2026-08-07):** GR02 = observability epic, split into GR02A (instrumentation) + GR02B (funnel analytics); boundaries: no schema bump, no new columns, replay unchanged, no detector/routing/strategy changes.

## 1. GR02A — live-stage observability (DONE)

Deliverable: `actualOutcome` / `actualOutcomeSource` — columns reserved since schema v1, never populated in production — are now stamped from real trade close events.

Architecture (event-driven settlement):

```
EVENT_POSITION_CLOSED          (CPositionLifecycleManager, deal-history net P/L)
        |
        v
candidateId (parsed from order comment "SCX-*-P<id>", EventData.entryDecisionId)
        |
        v
CActualOutcomeSettler.LookupDecisionId  (Register() map built at record time)
        |
        v
TelemetryCollector.ApplyActualOutcome(decisionId, WIN/LOSS/BREAKEVEN by profit sign)
```

Design decisions (user review + implementation):
- **Simulation and reality stay separate.** Simulated columns (`outcome`, `outcomeSource`, `rMultiple`, `barsHeld`, `exitReason`, `entry/exitPrice`) are NEVER overwritten — the schema has a dedicated actual track, preserving the Expected (Simulator) vs Actual (Live) comparison. This is the central architectural win and the reason for the design.
- **Event-driven settlement** keeps the telemetry lifecycle aligned with the trading lifecycle; no post-hoc inference.
- **Inert-by-construction**: telemetry rows exist only in ENTRY_MODE_SHADOW/NEW; orders are sent only in ENTRY_MODE_LEGACY — mutually exclusive today. GR02A wiring therefore cannot fire in replay; TT01 passed byte-identical vs B8 with NO allowlist (75/75 columns) — the correct outcome for a pure observability change.
- No event-schema change: `EventData` already carried `profit` + `entryDecisionId` (+ commission/swap/exitPrice/closedTime); only the close P/L population was added (`CPositionLifecycleManager::GetClosedProfit` = profit + swap + commission on DEAL_ENTRY_OUT deals).
- Documented boundary: rows are settled only while buffered in the collector (single flush at Shutdown); a position closed after run end cannot reach its row (logged, "row flushed").
- TDD: RED (60 compile errors) → GREEN 2056/2056 (Telemetry 265 → 296, 31 new assertions across 4 test functions: Record id assignment/write-back, ApplyActualOutcome + GetBufferedRow semantics, profit-sign classification, event mapping incl. reset/ignore paths).

## 2. GR02B — canonical funnel analytics (DONE)

The funnel layer is the project's canonical dashboard, not "just a report". `Tools/GR02/gr02_funnel.py` consumes a v4 telemetry CSV and produces, per family:

- **Stage table** (Fired → Qualified → Entered → Filled → Closed) with Count / % / WR / Mean R / Median R, Simulation vs Live columns.
- **Reject breakdown** (first failing validator): Spread / Confidence / Session / Risk / Other buckets.
- **Conversion rates**: Qualified/Fired, Entered/Qualified, Filled/Entered, Closed-sim/Qualified, Closed-live/Qualified.
- **Confidence histograms** per family (0.05 bins over 0.30–0.85), Accepted vs Rejected — shows whether a family clusters around its GR01 floor.
- **Simulation vs Live availability table**; live shows "Not yet available" until GR02A-populated rows exist — never invented values.

Data-model boundaries (schema v4, no bump):
- fired = every telemetry row; qualified = `validatorResults` contains no `=2`; entered/filled = NOT in v4 schema (no per-decision order lifecycle) → n/a; closed-sim = `outcomeSource==1` with outcome WIN/LOSS/BE; closed-live = `actualOutcomeSource==2`; wr = WIN/(WIN+LOSS), BE excluded; live mean/median R = n/a (schema stores actualOutcome only).
- Family mapping mirrors `Tools/GR01/gr01_funnel.py` (ruleName → RULE_FAMILY; UNKNOWN = evaluator path); utf-16 CSVs.

**Golden reference (TT01-baseline discipline extended to analytics):**

- `Tools/TT01/baseline/funnel_B8.csv` — stable, diffable per (family, stage, metric, side) value rows
- `Tools/TT01/baseline/funnel_B8.json` — structured golden (stages, rejects, histograms, conversions)
- Frozen from the B8 baseline telemetry CSV (500 rows; deterministic per commit).

**Comparison gate** (`--compare --golden <json> [--expected <json>]`):
- Deltas vs the golden are classified EXPECTED (declared in an expected-deltas JSON: exact value, `{"any": true}`, or `{"band":[lo,hi]}`) vs UNEXPECTED; exit 0 on no unexpected deltas, exit 1 otherwise. Future GR changes declare their funnel impact explicitly, making regressions as easy to spot as TT01 telemetry deltas.
- Verified: self-compare PASS exit 0; one flipped validator row → 2 UNEXPECTED, exit 1; same change declared → EXPECTED, exit 0.

B8 funnel snapshot (500 rows): fired 500 → qualified 487 (97.4%) → closed-sim 450 (wr 0.3689, meanR 0.1067, medianR −1.0); rejects 13 (Spread 11, Confidence 2); families: LIQUIDITY 207/201/197 (wr 0.3604), FVG 89/87/81 (wr 0.4444), BOS 165/160/133 (wr 0.3609), UNKNOWN 39/39/39 (wr 0.2821); CHOCH/ORDER_BLOCK 0 (not fired in the B8 window). Live: 0 rows → Not yet available.

## 3. Status

- GR epic: GR01 ✓ (evidence-calibrated family floors, B8), GR02A ✓, GR02B ✓ — evidence-routing + observability platform complete.
- Remaining Sprint 20: VF (visualization polish) and ED (already-approved evidence-backed experiments).
- Optional future: wire the funnel gate into `TT01_Validate.ps1` as a 14th gate (runs gr02_funnel.py --compare over the replay CSV).
