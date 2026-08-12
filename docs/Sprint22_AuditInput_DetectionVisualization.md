# Sprint 22 — Audit Input: SMC Detection & Visualization (Cline)

| Field          | Value |
|----------------|-------|
| Date           | 2026-08-11 |
| Source         | Cline automated audit (read-only verification of current source) |
| Status         | **RECORDED — NOT APPLIED** |
| Classification | **Engineering findings only — NOT research evidence** |
| Scope          | SMC detection + visualization + runtime wiring (no entry/TP/exit behavior) |
| Blocking       | **NON-BLOCKING for Sprint 22.** Recorded as input for a future dedicated engineering sprint. |

---

## 1. Boundary statement (do-not-touch fence)

While Sprint 22 (RL-HYP-01) is ACTIVE and its experiment boundary is FROZEN, the following are **explicitly out of scope** for this audit and must NOT be changed:

- Entry logic (no changes driven by profitability conjecture).
- TP / exit behavior.
- The frozen Sprint 22 swing-significance gate definition (`Structure/SwingSignificanceGate.mqh`).
- B8 (byte-identity fingerprint frozen).
- Any "cleanup" of dead/duplicate code while the experiment is pending.

This file records findings only. No `.mqh` / `.mq5` file was modified during this audit.

---

## 2. Evidence separation (kept deliberately distinct)

| Layer | Authoritative artifacts | Used for |
|-------|------------------------|----------|
| **Research evidence** | ED01-A … ED01-E decisions, Sprint 21 synthesis (RL-HYP-01), Sprint 22 protocol + 12-run batch | Experiment decisions, promotion gate |
| **Engineering findings** | This document (9 items, §3) | Dedicated engineering/research sprint AFTER Sprint 22 decision |

The audit's code-level conclusions do **not** constitute a new experimental result and do not override ED01 evidence.

---

## 3. Findings

### 3.1 Confirmed bugs (behavioral)

1. **[CRITICAL] HistoryEpoch orientation** — `Portfolio/SymbolContext.mqh:729`
   `m_epoch.Update(rates_total, time[0])` runs **before** `ArraySetAsSeries(time, true)` (`:745`). Arrays arrive from `CEngine::CopyOHLCArrays` in **chronological** order (index 0 = oldest), so `time[0]` is the OLDEST bar, while `CHistoryEpoch::Update` is documented to receive `timeNewest = time[0]` (series). Consequence: the LC5 time-reversal path is dead; a symbol reload / deep history revision where the newest bar regresses (same or growing `rates_total`) never fires a reset → all 9 epoch consumers keep stale state. The in-code comment "time[] is series-order here" is wrong at that point.
   Fix (future): move the epoch call after the flip, or pass `time[rates_total-1]` pre-flip.

2. **[HIGH] Visualization is not history-reset aware** — `Portfolio/SymbolContext.mqh:733-740, 823`; renderers hold `m_lastRendered*Count` + VSE records.
   `CVisualizationManager` is **not** registered as an epoch reset consumer. After a history reset the detectors rebuild (ids restart at 0/1) but renderers keep old counts, records, and chart objects → charts freeze on stale objects, new events never drawn. NOTE: the manager IS wired and updated (`:823`) in the current source; the earlier "dead VisualizationManager" note is stale.
   Fix (future): implement `IHistoryResetConsumer` on `CVisualizationManager`; on reset clear renderer counts + VSE records + delete objects.

3. **[MEDIUM] Legacy trend-flip gate** — `Portfolio/SymbolContext.mqh:789-795`
   Every new CHOCH unconditionally `ForceTrend()`s the opposite trend. `TREND_UNKNOWN → TREND_BEARISH` (bug: unknown defaults to bearish). Double-flip hazard vs `TrendState::Update` one line earlier; 1-bar lag for the OB created from that CHOCH (flip lands after `OrderBlockDetector.Update`).
   Fix (future): only flip when the CHOCH opposes current trend; when UNKNOWN, set from CHOCH direction; consider moving flip before OB update.

4. **[MEDIUM] Magic number per-init** — `Core/Config.mqh:61`
   `m_magicNumber = (int)TimeCurrent();` regenerates on every `OnInit` (param change, terminal restart, optimizer pass) → previously opened positions become orphans (position filters by magic) → SL/TP unmanaged, dedup guard bypassed (possible duplicates after reload). `(int)` truncation breaks after 2038. Nuance: per-run magic is deliberate for backtest/experiment isolation; but production/live hazard is real.
   Fix (future): stable derivation (EA-version + symbol) or `input int MagicNumber`.

5. **[LOW/MEDIUM] BOSRenderer lifecycle cascade** — `Visualization/BOSRenderer.mqh:120-176`
   `FreezePreviousActive` runs once per Update batch (not per new event, unlike CHOCHRenderer). On an initial history dump, all but the last BOS stay `VISUAL_STATE_ACTIVE` in VSE forever; freeze anchor uses `iTime(...,0)` (now) instead of the new BOS break time. Geometry correct; freeze/promote state wrong.
   Fix (future): freeze per new event at `breakTime`.

6. **[LOW] TradeManager fill reporting** — `Trading/TradeManager.mqh` execution block
   `filledPrice = request.price` (pre-trade quote) instead of `tradeResult.price`; `ticket = tradeResult.order` (no `tradeResult.deal` capture). Slippage/actual fill misreported in telemetry.
   Fix (future): report actual fill price + deal id.

7. **[LOW] Performance & logging** — `Core/Engine.mqh` (CopyOHLCArrays), `Portfolio/SymbolContext.mqh:~830`, `VisualizationManager`
   O(history) OHLC copy every new bar (O(N²) over backtest); PERF `Print` every bar from three modules; pivot-engine timing mislabeled as `MODULE_SWING_DETECTOR`.
   Fix (future): bounded bar window + metric-driven logging + label fix.

### 3.2 Dead / never-driven code (architectural risk only — DO NOT clean up during Sprint 22)

- `CEntryEngine m_entryEngine` — constructed (`SymbolContext.mqh:522`) but never updated/evaluated; "legacy decision" actually comes from `ConfluenceEngine`'s internal `m_entryDecisionEngine`.
- `CExecutionManager::Update()` — empty body and never called (real execution is `CTradeManager`).
- `CRiskManager::Update()` / `CPositionManager::Update()` — no runtime-loop calls (query/validator-only).
- `CScheduler::Update()` — empty.
- `SuperCents_X.mq5` `OnChartEvent` / `OnTimer` — empty (per-new-bar refresh only).

### 3.3 Verified correct (do not "fix")

- OHLC orientation split (swing pre-flip chronological; all others post-flip series) is deliberate and consistent; BOS crossing scan is index-space agnostic (by time); liquidity/PP rendering resolves by time/id.
- FVG gap math, EQH/EQL clustering, OB search bounds, CHOCH/PP level check, VSE draw/extend/freeze/finalize/delete — correct.
- Scheduler + Engine new-bar double-gating — consistent, not conflicting.
- Entry-mode execution contract (LEGACY executes; SHADOW/NEW reserved) — coherent.

---

## 4. Handling decision

- **Now (Sprint 22):** record only. Continue 12-run batch → pre-analysis gate → statistics → decision. Do NOT apply any item above until after the Sprint 22 decision.
- **Later:** open a dedicated engineering/research sprint with items §3.1.1 → §3.1.7 as the backlog. Fix order: (1) HistoryEpoch, (2) visualization reset, (3) magic number, (4) trend flip, (5) BOS cascade, (6) fill reporting, (7) perf/logging.

---

*No production code was modified to produce or record this audit.*
