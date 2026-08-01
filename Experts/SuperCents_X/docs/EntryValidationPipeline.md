# Entry Validation Pipeline

## Overview

After the Confluence Engine produces a `ConfluenceResult`, the Entry Engine
runs it through a pipeline of independent validators. Each validator checks
one specific entry condition and returns PASS, WARNING, or FAIL.

## Validator Order

Validators execute in registration order, grouped by category:

| Order | Category  | Validator            | Purpose                              |
|-------|-----------|----------------------|--------------------------------------|
| 1     | SETUP     | DirectionValidator   | Confluence direction must be clear   |
| 2     | SETUP     | ConfluenceValidator  | Confidence must meet minimum         |
| 3     | SETUP     | FreshnessValidator   | Signal must not be too old           |
| 4     | MARKET    | SpreadValidator      | Spread must be within limits         |
| 5     | MARKET    | SessionValidator     | Current time must be in a session    |
| 6     | MARKET    | DistanceValidator    | Price must be near candidate entry   |
| 7     | ACCOUNT   | CooldownValidator    | Minimum time since last trade        |
| 8     | ACCOUNT   | RiskValidator        | Risk manager must approve            |

Why this order:
- SETUP validators fail fast on fundamental signal issues.
- MARKET validators check current trading conditions.
- ACCOUNT validators run last (most expensive checks).

## Result Semantics

- **PASS**: Condition met. Continue to next validator.
- **WARNING**: Condition met but approaching limits. Continue.
- **FAIL**: Condition not met. Stop immediately. Decision = REJECTED.

## Short-Circuit Rule

As soon as a validator returns FAIL:
1. The result is recorded.
2. Processing stops.
3. `EntryDecision.status` is set to `DECISION_REJECTED`.

WARNINGs accumulate across validators but do NOT stop the pipeline.

## EntryContext

Each validator receives `EntryContext` containing transient market data:

```
currentBid, currentAsk    — current market prices
spread                    — current spread in pips
now                       — current server time
barsSinceSignal           — how many bars since the signal was generated
candidateEntryPrice       — the price at which the entry is being evaluated
```

The `ConfluenceResult` is passed as a separate parameter so validators
access confluence data directly (e.g., `confluence.totalConfidence`,
`confluence.direction`, `confluence.componentCount`).

## Adding a New Validator

1. Create a class implementing `IEntryValidator` in `Entry/Validators/`.
2. Define its configuration in `ValidatorConfig.mqh`.
3. Register it in `EntryOrchestrator` (or the main EA) via `RegisterValidator()`.
4. Add the rejection reason to `ENUM_ENTRY_REJECTION_REASON` in `EntryTypes.mqh`.
5. Add a matching entry to this table.

### Placement Rules
- SETUP: signal-level checks (direction, confidence, freshness).
- MARKET: market-condition checks (spread, session, distance).
- ACCOUNT: account-state checks (cooldown, risk).
