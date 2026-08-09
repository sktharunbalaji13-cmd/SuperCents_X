# Sprint 13.2 — Rule Evaluation Engine

**Frozen**: 2026-07-26  
**Tag**: `v1.1-rule-evaluation`  
**Parent**: `v1.0-structural-engine` (ead8765)

## Architecture

```
Structural Engine (Frozen)
        │
        ▼
Evidence Providers (read-only)
(BOS, CHOCH, OB, FVG, Liquidity, Trend)
        │
        ▼
Rule Evaluators (7 deterministic rules)
        │
        ▼
RuleResult { matched, type, score, confidence, direction, evidenceIds, explanation }
        │
        ▼
ConfluenceEngine (signal lifecycle, expiry tracking, shutdown summary)
```

## Rule Set

| # | Rule | Type | Direction |
|---|------|------|-----------|
| 1 | Bullish BOS + Bullish OB | Continuation | BULLISH |
| 2 | Bearish BOS + Bearish OB | Continuation | BEARISH |
| 3 | Bullish OB + Untouched Bullish FVG | Continuation | BULLISH |
| 4 | Bearish OB + Untouched Bearish FVG | Continuation | BEARISH |
| 5 | Bullish Liquidity Sweep + Bullish BOS | Continuation | BULLISH |
| 6 | Bearish Liquidity Sweep + Bearish BOS | Continuation | BEARISH |
| 7 | Bullish CHOCH + Bearish OB | Reversal | BULLISH |

## Key Design Decisions

- **Every rule returns RuleResult** — uniform interface for match/reject
- **Evidence providers are read-only** — rules never mutate detector state
- **Layered scoring** — structural / liquidity / confirmation decomposed per match
- **Expiry analytics** — each expired signal tracks exactly one reason (FVG filled, OB mitigated, OB invalidated, liquidity mitigated, liquidity invalidated, trend reversal)
- **Deterministic explanations** — every match and reject has a structured log line

## Regression Results (2-month M15)

### Signal Accounting
- Total Created: 3935
- Total Expired: 3517
- Active Remaining: 418
- Bullish: 1792, Bearish: 1726, None: 417

### Rule Match / Reject
- BOS_OB_BULLISH:       302 / 3633
- BOS_OB_BEARISH:       362 / 3573
- OB_FVG_BULLISH:      1660 / 2275
- OB_FVG_BEARISH:      1711 / 2224
- LIQUIDITY_BOS_BULLISH: 487 / 3448
- LIQUIDITY_BOS_BEARISH: 606 / 3329
- CHOCH_OB_REVERSAL:    125 / 3810

### Expiry Breakdown
- FVG Filled:          2056
- OB Mitigated:          47
- OB Invalidated:       235
- Liquidity Mitigated:  194
- Liquidity Invalidated:625
- Trend Reversal:       360

### Invariants Verified
- Expiry sum: 2056+47+235+194+625+360 = 3517 = Total Expired ✅
- Direction sum: 1792+1726+417 = 3935 = Total Created ✅
- Rule evaluations: 5253 matches + 22292 rejects = 27545 = 3935×7 ✅
- Structural engine: unchanged (BOS 467/471, CHOCH 300, FVG 60, Liquidity 2108 OK) ✅

## Files Changed
```
Confluence/SignalTypes.mqh      (RuleResult, RuleType, ExpiryReason)
Confluence/ConfluenceRules.mqh  (7 rule evaluators)
Confluence/ScoreCalculator.mqh  (CalculateRuleLayers)
Confluence/ConfluenceEngine.mqh (rule evaluation loop, expiry analytics)
Core/Engine.mqh                 (SetLiquidityDetector wiring)
Entry/EntrySetupBuilder.mqh     (field reference updates)
```

## Structural Engine Contract
All detectors are read-only. The Confluence Engine is a pure consumer.
No modifications to any detector or structural component.
