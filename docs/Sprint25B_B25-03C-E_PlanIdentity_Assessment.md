# Sprint 25B — B25-03C-E Plan-Identity Assessment (what the ledger actually stores)

- Document ID: SR-25B-B03CE-04 (follow-up to the rejected correction SR-25B-B03CE-03)
- Type: READ-ONLY identity assessment. No implementation, no commit, no push.
- Baseline: `9fefdd8` (D1 pushed). B25-03C-E is NOT accepted.
- Question: what durable fields actually represent the regenerated plan, independent of the live execution price?

---

## 1. Verdict

**No complete stable plan identity is currently persisted.** The ledger stores a *partial* stable identity — `(symbol, side, magic, stopLoss, takeProfit)` — but the single most discriminating stable field, the plan's structure-resolved **entry price**, is **not** stored: the INTENT records the **live execution-time ASK/BID** instead.

The rejected correction's `(symbol, side, magic, entryPrice, sl, tp)` was therefore doubly wrong: it used `request.price` (live) as if it were `plan.entryPrice` (stable), and `plan.entryPrice` is not even in the ledger.

---

## 2. Trace: from signal to INTENT

### 2.1 Plan construction (stable fields exist here)

`ExecutionPlanner.BuildPlan` (`Entry/ExecutionPlanner.mqh:243-266`):
```
ResolveEntryPrice(candidate, entryPolicy, obDetector, fvgDetector, liqDetector, price, ...)
   -> plan.entryPrice = price        (:244)     // STRUCTURE-resolved
ResolveStopLoss(candidate, stopPolicy, plan.entryPrice, ...)
   -> plan.stopLoss = sl             (:255)     // STRUCTURE-resolved
ResolveTakeProfit(candidate, targetPolicy, plan.entryPrice, plan.stopLoss, ...)
   -> plan.takeProfit = tp           (:266)     // STRUCTURE-resolved
```

`Entry/EntryPriceResolver.mqh:17-59` resolves entry from structure:
- `ENTRY_OB_RETEST` → `ob.low` / `ob.high` (:26,:28)
- `ENTRY_FVG_MIDPOINT` → `(fvg.upper + fvg.lower)/2` (:43)
- `ENTRY_LIQUIDITY_LEVEL` → `ll.price` (:58)
- **fallback** → `SymbolInfoDouble(_Symbol, SYMBOL_BID)` (:65)  ← LIVE market price

So `plan.entryPrice` is **deterministic only when it resolves to structure** (the default `ENTRY_OB_RETEST` and the common case). In the no-structure fallback (or `ENTRY_CURRENT_PRICE`) it degrades to the live Bid.

### 2.2 Request construction (stable entry price is DROPPED here)

`TradeRequestBuilder.Build` (`Trading/TradeRequestBuilder.mqh:55-66`):
```
request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK)   // BUY  (:58)  LIVE
request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID)   // SELL (:64)  LIVE
request.sl    = plan.stopLoss                             // (:52)  STABLE
request.tp    = plan.takeProfit                           // (:53)  STABLE
```

**`plan.entryPrice` (stable) is never copied into the request.** The request price is the live Ask/Bid.

### 2.3 INTENT write (live price is persisted, stable entry is not)

`TradeManager.Update` (`Trading/TradeManager.mqh:376`):
```
m_ledgerWriter.BeginExecution((long)planId, m_symbol, execSide,
                              request.price, volume, request.sl, request.tp,
                              m_magicNumber, execExecutionId)
```
→ the INTENT's `requestedPrice` parameter is `request.price` (**live**).

`CExecutionLedgerWriter.BeginExecution` (`Trading/CExecutionLedgerWriter.mqh:173-178`) payload:
```
[0] decisionId | [1] symbol | [2] side | [3] requestedPrice | [4] requestedVolume | [5] sl | [6] tp | [7] magic
```

---

## 3. Field-by-field stability of the durable INTENT

| INTENT field | Source | Deterministic across regeneration? |
|---|---|---|
| `[1] symbol` | plan symbol | ✅ stable |
| `[2] side` | plan direction | ✅ stable |
| `[7] magic` | EA input (C1) | ✅ stable |
| `[5] sl` | `plan.stopLoss` (structure-resolved) | ✅ stable (when structure-resolved) |
| `[6] tp` | `plan.takeProfit` (structure-resolved) | ✅ stable (when structure-resolved) |
| `[3] requestedPrice` | `request.price` = **live ASK/BID** | ❌ **live, not the plan entry** |
| `[4] requestedVolume` | sized lots (equity × risk% / stop-distance-at-fill) | ❌ equity/fill vary per run |
| `[0] decisionId` | `candidateId` = `m_nextId++` | ❌ run-local, recyclable |

---

## 4. Answers to the specific questions

- **ExecutionPlan fields**: `entryDecisionId, direction, orderType, status, entryPrice, stopLoss, takeProfit, riskReward, stopDistance, targetDistance, entryPolicyUsed, stopPolicyUsed, targetPolicyUsed, rationale, rejectionReason, createdTime` (`Entry/ExecutionPlanTypes.mqh`). The stable ones are `entryPrice/stopLoss/takeProfit/direction/orderType` (when structure-resolved).

- **TradeCandidate / EntryDecision fields**: `id` (run-local counter), `direction`, evidence ids/rules, `score`, `confidence`. **No price/SL/TP** — those are resolved later by the planner. So the candidate layer carries no stable price identity either.

- **Deterministic across restart/regeneration**: `symbol, side, magic, direction`, and `entryPrice/stopLoss/takeProfit` **only when structure-resolved**. Not deterministic: `request.price` (live), `volume` (equity+fill), `candidateId` (counter).

- **Does entryPrice mean signal/plan entry or live execution price?** `plan.entryPrice` = structure-resolved plan entry (OB low/high, FVG midpoint, liquidity level) with a live-Bid fallback. `request.price` (what the INTENT stores) = live Ask/Bid at build time. They are **different quantities**; the ledger keeps the latter.

- **Are SL/TP deterministic?** Yes, when the stop/target policies resolve to structure (default `STOP_LIQUIDITY_SIDE`/`TARGET_OPPOSING_LIQUIDITY`). `TARGET_FIXED_RR` derives `tp = entry + RR×stop`, so it inherits entry-price stability; `STOP_BROKER_MINIMUM` is broker/account-derived (still near-stable). The normal path is deterministic.

- **Should requested volume participate in identity?** No — it is sized from account equity, stop distance at the fill price, and risk %, all of which vary across runs.

- **Is there an existing stable combination usable without changing frozen identity/ledger?** **Partially.** `(symbol, side, magic, sl, tp)` is already in the INTENT and stable. It is SAFE (detects the exact duplicate) but coarser: two different signals sharing the same stop/target structure would be falsely MATCHED → over-block (conservative, never unsafe).

---

## 5. Conclusion and recommendation

1. The **only** durable plan-identity fields today are `(symbol, side, magic, stopLoss, takeProfit)`. The stable entry price is lost (the ledger stores the live Ask/Bid as `requestedPrice`).

2. `plan.entryPrice` is available in the send path but not persisted. Persisting it requires a deliberate change — **one of**:
   - **(a)** a one-line `TradeManager` call-site change to pass `plan.entryPrice` (stable) instead of `request.price` (live) into `BeginExecution`. The writer/recovery do not read the price field (`ParseIntentPayload` reads only `[0],[1],[2],[4],[7]`), so this is behaviorally inert to B25-03C-B — but it changes the *semantic* of the INTENT `requestedPrice` field and should be an explicit, authorized change; or
   - **(b)** adding a new INTENT field for `plan.entryPrice` (a B25-03C-B payload change, currently out of scope); or
   - **(c)** accept the coarse `(symbol, side, magic, sl, tp)` identity, documenting the over-blocking.

3. If none of these is acceptable, then **no stable plan identity exists in the current architecture**, and the honest contract is the fallback already stated: **absence must not authorize a send** (E returns BLOCK/AMBIGUOUS, never NOT_FOUND), or a plan identity must be **introduced deliberately** (not by quietly treating the live price as plan identity).

---

```
B25-03C-E: NOT ACCEPTED (identity assessment complete)
FINDING: no complete stable plan identity persisted; (symbol, side, magic, sl, tp) is the only stable subset
IMPLEMENTATION / COMMIT / PUSH: NOT AUTHORIZED
B25-03C-C: NOT AUTHORIZED
NEXT SENIOR DECISION: choose (a) persist plan.entryPrice, (b) add INTENT field, (c) accept coarse identity, or introduce a plan identity
STOP.
```
