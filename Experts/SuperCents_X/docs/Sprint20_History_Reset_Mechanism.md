# Sprint 20 — LC02: Canonical History Reset Mechanism (AVP E11)

- **Status:** DONE (2026-08-07)
- **Plan:** `docs/Sprint20_Engineering_Plan.md` (LC02 row)
- **Tests:** `Tests/unit/TestHistoryEpoch.mqh` — 33 assertions, GREEN (`Tests/TestSuite.mqh`)
- **Predecessor:** `docs/Sprint20_State_Lifecycle_Contract.md` (LC01)
- **Scope decision (frozen):** LC02 ships ONE canonical history-shrink/reset mechanism that every stateful detector can consume. It does NOT wire any detector (per-detector synchronization and the downstream cascade are LC03). LC02 answers exactly four questions.

---

## 1. The four answers

| Question | Answer |
|---|---|
| 1. `rates_total` decreased → how is that detected? | `CHistoryEpoch::Update(rates_total, timeNewest)` compares against the last observed values. `rates_total < last` → `HISTORY_EVENT_SHRINK`. `timeNewest < lastTimeNewest` (the newest-bar time moved backwards — reload/purge) → `HISTORY_EVENT_TIME_RESET`. First update after construction/`Reset()` is baseline only. Both conditions → `SHRINK` (priority), still one epoch bump + one broadcast. |
| 2. What state is invalidated? | The **epoch** of every registered consumer. Each consumer drops its own incremental state (cursor, pools, id counters) in `OnHistoryReset()` — the mechanism does not know what the state is. |
| 3. Who receives the reset? | Every consumer registered via `AddConsumer()`, broadcast in registration order. |
| 4. How is rebuild triggered? | The `IHistoryResetConsumer::OnHistoryReset()` callback per consumer. Rebuild = the consumer's **existing initial-scan path** (LC1 clause of the lifecycle contract) — no new rebuild machinery. |

---

## 2. Components (`Core/HistoryEpoch.mqh`)

- `enum EHistoryEvent` — `NONE` / `SHRINK` / `TIME_RESET`.
- `class IHistoryResetConsumer` — contract: `OnHistoryReset()` drops incremental state and rebuilds from current history via the initial-scan path.
- `class CHistoryEpoch` — canonical detection + epoch counter + consumer registry + broadcast:
  - `EHistoryEvent Update(int rates_total, datetime timeNewest)` — call ONCE per data update, **before** driving any consumer's `Update()`, with series-order arrays (`timeNewest = time[0]`). Returns the event; bumps `m_epoch`; notifies all consumers on non-`NONE`.
  - `void Reset()` — context re-init (symbol/TF change, EA restart, LC6/LC7/LC8): clears baseline, epoch → 0, next update is a fresh baseline.
  - `void AddConsumer(IHistoryResetConsumer*)` — registry.
  - `int GetEpoch()`, `EHistoryEvent GetLastEvent()`.

## 3. Canonical detection rules (tested)

1. First update after (re)init = baseline; no event, no epoch bump, no notifications.
2. Grow or identical re-feed → `NONE`.
3. `rates_total` decrease → `SHRINK`, epoch `+1`, every consumer notified exactly once.
4. Newest-bar time reversal (no shrink) → `TIME_RESET`, epoch `+1`, broadcast.
5. Shrink + time reset together → `SHRINK` priority; exactly one bump + one broadcast.
6. Multiple consumers → all receive the reset (registry semantics).
7. Consecutive shrinks → consecutive events (the new smaller size becomes the baseline).
8. Growth from the rebuilt baseline → normal extension.
9. `Reset()` → baseline cleared; next update is fresh; no spurious notification.

## 4. Usage contract (for LC03)

- The epoch owner (in production: the single driver, `CSymbolContext::Update`) MUST call `Update()` before any consumer's `Update()`, so all consumers observe the same epoch/event on the same tick.
- Consumers MUST NOT advance cursors past the new `rates_total` inside `OnHistoryReset()` (rebuild is a fresh scan).
- Consumers MUST register before the first `Update()` (registration is once at context init).
- Id semantics: the mechanism does NOT guarantee id monotonicity across a reset — LC03 decides per consumer (e.g., Swing's `Clear()` restarts ids at 1; the LC03 cascade must reset downstream id-keyed cursors together so no stale reference survives).
- Cross-consumer cascade ordering (Swing → Pivot → PP → Liquidity → CHOCH → OrderBlock) is an LC03 concern; the mechanism is agnostic.

## 5. Why LC02 is test-only for the production chain

No production detector consumes the mechanism yet (LC03). The broadcast/registry semantics are therefore verified with mock consumers. This keeps LC02 a pure contract layer: reviewers see the mechanism, its rules, and its tests in isolation — exactly the "one mechanism, multiple consumers" property the frozen plan requires.

## 6. Evidence

- `Tests/unit/TestHistoryEpoch.mqh`: 33/33 GREEN (suite 1290 → 1323/1323).
- TDD: RED first (5 compile errors: `HistoryEpoch.mqh` not found, `RunHistoryEpochTests` undeclared) → GREEN after implementation.
- TT01 full 13-gate run PASS; production behavior byte-identical vs B7 (test-only + new-module change, nothing wired).
