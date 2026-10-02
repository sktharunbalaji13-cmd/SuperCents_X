# Sprint 25B — B25-03C-B C1 Payload Extension (Assessment + Design + TDD)

- Document ID: SR-25B-B03CB-C1-01
- Type: READ-ONLY assessment + design + TDD plan. No implementation, no commit, no push, no E reimplementation.
- Baseline: `9fefdd8` (D1). B25-03C-B `a0f2720`. B25-03C-E DESIGN ACCEPTED, blocked on this persistence.
- Scope: append INTENT fields `[8..12]` (plan identity), preserving `[3] requestedPrice` as the live broker-request price.

---

## 1. Audit of the existing payload / writer / parser

### 1.1 Writer (B25-03C-B `CExecutionLedgerWriter.BeginExecution`)

Signature and payload (`Trading/CExecutionLedgerWriter.mqh:157-178`):
```
bool BeginExecution(decisionId, symbol, side, requestedPrice, requestedVolume, sl, tp, magic, &executionId)
payload = [0] decisionId | [1] symbol | [2] side | [3] requestedPrice | [4] requestedVolume | [5] sl | [6] tp | [7] magic
```

Call site (`Trading/TradeManager.mqh:376`):
```
BeginExecution((long)planId, m_symbol, execSide, request.price, volume, request.sl, request.tp, m_magicNumber, ...)
```
where `request.price = SYMBOL_ASK/BID` (live), `request.sl = plan.stopLoss`, `request.tp = plan.takeProfit` (`TradeRequestBuilder.mqh:52-53,58,64`).

### 1.2 Parser (B25-03C-B `CExecutionRecovery.ParseIntentPayload`)

```
n = StringSplit(payload, '|', parts); if(n < 8) return false;
decisionId = [0]; symbol = [1]; side = [2]; requestedVolume = [4]; magic = [7];
```
The parser reads `[0],[1],[2],[4],[7]` only; `[3] price`, `[5] sl`, `[6] tp` are stored but unread. **The `n < 8` guard means appending fields is backward-compatible.**

### 1.3 Price stability (already established in the plan-identity assessment)

- `[3] requestedPrice` = **live** Ask/Bid (execution-truth).
- `[5] sl` = `plan.stopLoss` (structure-resolved, stable).
- `[6] tp` = `plan.takeProfit` (structure-resolved, stable).
- `plan.entryPrice` (stable structure-resolved, with a live-Bid fallback) is **not** currently persisted.

---

## 2. The `[8..12]` extension (Option C1, complete PI)

Append (never redefine):
```
[8]  planEntryPrice     double   structure-resolved plan entry (sentinel 0.0 when structureResolved=false)
[9]  structureResolved  int      0/1  (all of entry/stop/target resolved deterministically)
[10] entryPolicy        int      ENUM_ENTRY_POLICY
[11] stopPolicy         int      ENUM_STOP_POLICY
[12] targetPolicy       int      ENUM_TARGET_POLICY
```
`[3] requestedPrice` remains the live broker-request price — **unchanged**.

Full durable canonical identity:
```
PI = (symbol[1], side[2], magic[7], entryPolicy[10], planEntryPrice[8],
      stopPolicy[11], stopLoss[5], targetPolicy[12], takeProfit[6], structureResolved[9])
```

---

## 3. structureResolved derivation (explicit)

Each resolver currently returns `bool` (resolved) but not *whether it resolved from structure*. The extension requires a `bool &resolvedFromStructure` out-param on the three resolvers (a planner-level change, NOT a frozen/ledger change):

| Resolver | structure=true when | structure=false when |
|---|---|---|
| `ResolveEntryPrice` | OB retest / FVG midpoint / liquidity level | live-Bid fallback (`EntryPriceResolver.mqh:65`) or `ENTRY_CURRENT_PRICE` |
| `ResolveStopLoss` | OB side / liquidity side / protected point | `STOP_BROKER_MINIMUM` (`StopLossResolver.mqh:82`, broker-dependent) |
| `ResolveTakeProfit` | opposing liquidity / OB / FVG / previous swing, or fixed-RR (see §4) | any live/broker dependency |

`structureResolved = entry && stop && target`. When `false`, `planEntryPrice` is stored as sentinel `0.0` and `PI` is **undefined** (E BLOCKs — never a live-price pseudo-identity).

---

## 4. TARGET_FIXED_RR semantics (resolved)

The actual `takeProfit` is persisted in `[6]`. Therefore the canonical identity is based on the **persisted canonical payload and resulting prices**, not historical config reconstruction. The RR tier (`FixedRRTier`) is **NOT identity-bearing**:

- Same signal + same RR ⇒ same `tp` ⇒ same `PI` ⇒ MATCHED (duplicate detected).
- Same signal + different RR ⇒ different `tp` ⇒ different `PI` ⇒ NOT_FOUND ⇒ SEND — which is **correct**: it is a *different order* (different take-profit level), not a duplicate of the prior one.

`TARGET_FIXED_RR` therefore yields `structureResolved=true` whenever entry and stop are structure-resolved (the resulting `tp` is deterministic given the persisted stop/entry and the per-run-stable RR). If a future decision wants the RR tier to be identity-bearing, it must be persisted explicitly; this design does not.

---

## 5. Backward compatibility / version handling

- The ledger treats the INTENT payload as **opaque** (`|`-joined tail; `ExecutionLedger.mqh` does not interpret fields). Appending fields does not affect the ledger core.
- Existing 8-field INTENT records remain parseable by the existing `ParseIntentPayload` (`n < 8` guard still passes).
- A **new** parser `ParseIntentPlanIdentity(payload, &pi)`:
  - `n >= 13` → full `PI` extracted.
  - `n < 13` (legacy/pre-extension record) → `PI` **absent** → E treats it as AMBIGUOUS → BLOCK (no identity ⇒ cannot prove NOT_FOUND). Conservative; no silent reconstruction from current config.
- `requestedPrice` `[3]` continues to parse identically for old and new records.

---

## 6. TDD RED → GREEN plan

RED (against HEAD `9fefdd8` — the new fields/parser do not exist yet):
- R1 payload round-trip: write `[0..12]` → parse → all 13 fields identical.
- R2 `[3] requestedPrice` is the live request price; changing `plan.entryPrice` does **not** change `[3]` (semantic-preservation test).
- R3 `structureResolved=true` for OB/FVG/liquidity entry + protected/liquidity stop + structure target.
- R4 `structureResolved=false` for live-Bid fallback entry, and for `STOP_BROKER_MINIMUM`.
- R5 `structureResolved=false` ⇒ `planEntryPrice` sentinel `0.0` and `PI` undefined ⇒ BLOCK.
- R6 legacy 8-field record: `ParseIntentPayload` still succeeds; `ParseIntentPlanIdentity` returns absent ⇒ BLOCK.
- R7 `TARGET_FIXED_RR`: same entry/stop + same RR ⇒ same `tp`/`PI`; different RR ⇒ different `tp`/`PI` (RR tier not identity-bearing, documented).
- R8 policies persisted as enum ints; round-trip exact.
- R9 frozen boundary: `ExecutionIdentity`/`ExecutionTruth`/`ExecutionLedger`, H6, D1 — zero diff.
- R10 full suite GREEN (no B25-03C-B regression).

GREEN: implement the writer/parser extension + resolver out-params + call-site args (only when authorized).

---

## 7. Frozen boundary proof

| Module | Change |
|---|---|
| `ExecutionIdentity.mqh`, `ExecutionTruth.mqh`, `ExecutionLedger.mqh` | none (frozen) |
| H6 (`TradeManagerRetryPolicy.mqh`), D1 (`TradeRequestBuilder` correlation) | none |
| `CExecutionRecovery.mqh` | **append-only**: new `ParseIntentPlanIdentity` + extend `ParseIntentPayload` field-count tolerance; no existing field re-read/redefine |
| `CExecutionLedgerWriter.mqh` | **append-only**: `BeginExecution` gains 5 params and writes `[8..12]`; `requestedPrice` path unchanged |
| `TradeManager.mqh` (call site) | pass `plan.entryPrice`, `structureResolved`, 3 policy enums as new args; `request.price` still passed unchanged |
| `EntryPriceResolver` / `StopLossResolver` / `TargetResolver` | add `bool &resolvedFromStructure` out-param (planner-level) |

---

```
C1 PAYLOAD EXTENSION: ASSESSMENT + DESIGN COMPLETE
EXTENSION: append [8]=planEntryPrice, [9]=structureResolved, [10]=entryPolicy, [11]=stopPolicy, [12]=targetPolicy
[3] requestedPrice: PRESERVED (live broker-request price)
TARGET_FIXED_RR: resolved (resulting tp is the identity; RR tier not identity-bearing)
BACKWARD COMPAT: legacy records -> PI absent -> BLOCK
IMPLEMENTATION / COMMIT / PUSH: NOT AUTHORIZED
B25-03C-E REIMPLEMENTATION: NOT AUTHORIZED (pending this persistence)
B25-03C-C: NOT AUTHORIZED
NEXT SENIOR DECISION: REVIEW C1 PAYLOAD-EXTENSION DESIGN
STOP.
```
