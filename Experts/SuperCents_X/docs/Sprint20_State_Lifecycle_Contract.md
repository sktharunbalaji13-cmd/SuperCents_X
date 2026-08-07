# Sprint 20 — LC01: State Lifecycle Contract (AVP E11)

- **Status:** DONE (2026-08-07)
- **Plan:** `docs/Sprint20_Engineering_Plan.md` (LC01 row)
- **Tests:** `Tests/unit/TestLifecycleContract.mqh` — 53 assertions, GREEN (`Tests/TestSuite.mqh`)
- **AVP:** C01-09 (E11 = StructuralPivotEngine freeze on history shrink)
- **Scope decision:** LC01 extracts and documents the lifecycle contract every detector must satisfy. It does NOT patch detectors — violations get RED->GREEN in LC02 (`rates_total` shrink handler) / LC03 (downstream cursor re-sync).

---

## 1. Purpose

E11 cannot be fixed per-detector in isolation because every layer of the structure pipeline keeps its own incremental cursor and there is no shared "data epoch" concept. LC01 defines:

1. the **lifecycle phases** a detector must survive;
2. the **cursor contract** (what state may be advanced only, never rewound silently);
3. an **audit table** of all six structure detectors against those phases;
4. **reference behavior** (FVGDetector) and the RED->GREEN mapping for LC02/LC03.

All claims below are backed by tests (`Tests/unit/TestLifecycleContract.mqh`) or by line-level code references, not assumptions.

---

## 2. Lifecycle phases

| Phase | Trigger in production | Contractual requirement |
|---|---|---|
| LC1. Initial scan | First `Update()` after `Init()` | Detector produces the complete set for the full history. No dependence on any previous state. |
| LC2. Incremental update | New bar(s) appended | Only new bars are evaluated; existing state is untouched (geometry, ids, ordering). Re-feeding the same bar is a no-op (idempotence). |
| LC3. History extension | `rates_total` grows beyond prior max | Detector continues from its cursor; previously built state remains valid. |
| LC4. `rates_total` shrink | Server/chart truncates history (no time reversal of the *oldest* bar) | Detector must NOT silently keep stale state, and must NOT stall: it either (a) detects the shrink and rebuilds from the new history, or (b) re-derives everything statelessly. |
| LC5. Time discontinuity (reload) | `time[0]` jumps backwards (new server session, history purge) | Detector resets and rebuilds from the new history; ids remain monotonic across the rebuild (no id reuse). |
| LC6. Symbol/timeframe change | `CSymbolContext` re-inits with a different symbol/TF | Equivalent to LC5: full state reset; ids must not collide with prior symbol's ids. |
| LC7. Parameter change | EA inputs changed at runtime | Detector re-initializes cleanly (`Init()` is re-entrant). |
| LC8. EA restart | Terminal/EA restart | State is fully re-derivable from the new history (no persisted partial state that contradicts it). |

---

## 3. Cursor contract

- A **cursor** is any member that encodes "how much history has already been processed" (bar index, bar time, event id, or event count).
- Contract rules:
  - C1. A cursor may only move **forward** in its own domain (monotonic).
  - C2. If the input history violates monotonicity (shrink, time reversal), the detector must **detect it explicitly** — never advance silently, never rewind silently.
  - C3. On detected discontinuity the detector must reset **all** internal state, including the cursor, and rebuild — or restart processing with state derived strictly from the new input.
  - C4. If a detector resets, its downstream consumers must be able to detect the reset (see LC03). Id reuse breaks downstream consumers that key on ids.

---

## 4. Audit table

Legend: GREEN = compliant, RED = violates a clause, WARN = compliant by design but fragile, REF = reference implementation.

| Detector | Cursor (file:line) | LC1 init | LC2 incremental | LC3 history ext | LC4 shrink | LC5 time disc. | LC6 TF/sym change | LC7 param change | LC8 EA restart | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|
| **FVGDetector** | `m_lastProcessedTime` (`Structure/FVGDetector.mqh:25`) | full scan from newest (`:138-141`) | delta window `min(newBars+2, rates_total-1)` (`:156-167`), time-keyed dedup (`:274-293`) | continues from time cursor | **GAP:** shrink without time reversal is invisible (cursor stays newer than history start) | rescan on `time[0] < cursor` (`:144-151`), ids monotonic (`m_nextId` untouched) | N/A (context re-inits) | `Init()` re-entrant (`:73-86`) | full rescan | **REF / RED-LC4** |
| **SwingDetector** | `m_lastCheckedCenter` (`Structure/SwingDetector.mqh:27`) | full scan centers 4..max (`:131-142`) | next-center scan (`:131`) | continues | **detects** shrink `maxCenter < m_lastCheckedCenter` -> `Clear()` + rebuild (`:113-119`) — ONLY detector that does | **GAP:** time reversal without shrink not detected | N/A | `Init()` re-entrant (`:84-99`) | full rescan | **WARN** — but `Clear()` resets `m_nextId=1` (`:185`): id reuse breaks StructuralPivotEngine (E11) |
| **StructuralPivotEngine** | `m_lastProcessedSwingId` (`Structure/StructuralPivotEngine.mqh:147`) | full scan | new swing ids only | continues | **STALLS:** swing-id gate rejects ids that SwingDetector restarts at 1 -> permanent freeze | same stall | N/A | re-entrant | full rescan | **RED** (E11 epicenter) |
| **BOSDetector** | stateless + `m_brokenPivotIds` dedup, per-pivot time windows | full rescan each update | full rescan (implicitly safe) | full rescan | implicitly safe (repopulates lock windows from history) | implicitly safe | N/A | re-entrant | full rescan | **GREEN** (stateless by design) |
| **CHOCHDetector** | `m_lastProcessedBar` rates_total gate (`Structure/CHOCHDetector.mqh:142-143`) | full scan | `rates_total` monotonic gate | continues | **STALLS:** after shrink, `rates_total` never reaches old value -> never processes again | stall | N/A | re-entrant | full rescan | **RED** |
| **LiquidityDetector** | 4 count cursors (`Structure/LiquidityDetector.mqh:151,258,362,568`) | full scan | count-gated | continues | **STALLS** per gate | per gate | N/A | re-entrant | full rescan | **RED** |
| **OrderBlockDetector** | latent: CHOCH-count watermark (`Structure/OrderBlockDetector.mqh:113`) | full scan | CHOCH-gated | continues | breaks when CHOCH resets (but CHOCH stalls first) | breaks | N/A | re-entrant | full rescan | **RED (latent)** |
| **TrendState / ProtectedPointManager** | consumers of the above | - | - | - | inherit upstream failure | inherit | N/A | re-entrant | - | **WARN (inherit)** |

Production drive order (`Portfolio/SymbolContext.mqh:618-718`): SwingDetector -> StructuralPivotEngine -> BOSDetector -> TrendState -> ProtectedPointManager -> CHOCHDetector -> OrderBlockDetector -> FVG -> Liquidity. `rates_total = ArraySize(high)` (`Core/Engine.mqh:184`); there is **no** `prev_calculated`/OnCalculate anywhere — shrink is invisible to every layer (confirmed by code search).

---

## 5. RED -> GREEN mapping

| # | Violation | Fix task | Design note |
|---|---|---|---|
| 1 | LC4 invisible to all layers | **LC02** — shared shrink handler | A shared "history epoch" (compare `rates_total`/first-bar time vs per-layer cursors) at `CSymbolContext::Update`; broadcast reset. FVG keeps its own rescan; Swing's shrink path becomes the shared primitive instead of per-detector logic. |
| 2 | Swing id reuse on reset | **LC03** — downstream re-sync | StructuralPivotEngine must detect swing-reset (epoch marker) and re-key: rebuild pivot state from the new swing set instead of rejecting restarted ids. |
| 3 | CHOCH / Liquidity / OrderBlock stalls | **LC02/LC03** — cursor re-sync | Replace monotonic count/bar gates with epoch-aware cursors; on epoch bump, reset gates and re-scan. |
| 4 | FVG LC4 gap (shrink without time reversal) | **LC02** — FVG shrink clause | FVG currently relies on `time[0] < cursor`; add shrink-aware clause so truncated history triggers rebuild, matching Swing. |
| 5 | TF/symbol change | LC03 hardening | Guarantee per-symbol state namespaces / id namespaces, or full context re-init (already N/A-safe by design). |

---

## 6. Evidence

- `Tests/unit/TestLifecycleContract.mqh` (53 assertions, GREEN):
  - LC01.1 — FVG rescan rebuilds pool from new history only; ids monotonic (`id 0 -> 1`, no reuse); same-bar re-feed no-op.
  - LC01.2 — FVG incremental delta adds exactly the new bar's FVG; old FVG untouched; overlap re-feed deduped.
  - LC01.3 — Swing shrink: pool rebuilt from new history (no stale bars, no stall); regrow recovers the identical set.
  - LC01.4 — Swing reload: fresh init + rescan reconstructs byte-identical swing set.
- Suite: `GRAND TOTAL: 1290/1290 passed, 0 failed` (category `Lifecycle Contract Tests: 53/53`).
- Code references per audit table above.

---

## 7. Follow-up (LC02 / LC03)

- LC02: implement the shared shrink/epoch handler per section 5 (rows 1, 3, 4); extend tests with `rates_total` shrink fixtures for CHOCH/Liquidity/OrderBlock/FVG.
- LC03: StructuralPivotEngine re-sync on swing reset (row 2); test: swing reset -> pivot rebuild, no permanent rejection; OrderBlock watermark re-sync (row 3).
