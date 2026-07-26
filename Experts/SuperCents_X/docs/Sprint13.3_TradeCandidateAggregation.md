# Sprint 13.3 — Trade Candidate Aggregation

**Frozen**: 2026-07-26
**Tag**: `v1.2-trade-candidate-engine`
**Parent**: `v1.1-rule-evaluation` (83c078a)

## Architecture

```
RuleResults (7 per bar)
        │
        ▼
TradeCandidateBuilder
  ├─ Group by direction
  ├─ Deduplicate evidence IDs
  ├─ Compute aggregate score/confidence
  └─ Manage lifecycle (CREATED → ACTIVE → EXPIRED)
        │
        ▼
TradeCandidate { direction, score, confidence, matchedRules[], evidenceIds[], rationale }
```

## Key Design Decisions

- **One candidate per direction per bar** — bullish and bearish candidates coexist
- **Evidence deduplication** — same OB referenced by 2 rules stored once
- **Score = normalized aggregate** — best rule score + per-evidence bonus, capped at 100
- **Confidence = best rule confidence + multi-rule bonus**, capped at 0.99
- **Lifecycle** — candidate expires when ALL supporting evidence becomes invalid
- **No global ranking** — candidates coexist without selection (reserved for Entry Engine)

## Regression Results (2-month M15)

### Trade Candidate Summary
- Total Created: 3,918
- Total Expired: 4
- Active Remaining: 3,914
- Bullish: 1,951
- Bearish: 1,967
- Avg Score: 80
- Avg Confidence: 0.84
- Max Evidence Set: 4
- Max Rule Set: 3

### Invariants Verified
- 1951 + 1967 = 3918 = Total Created ✅
- 3914 + 4 = 3918 = Total Created ✅
- Structural engine unchanged (BOS 467/471, CHOCH 300, OB 300, FVG 60, Liquidity 2108) ✅

## Files Changed
```
Confluence/TradeCandidateBuilder.mqh  (NEW — builder class)
Confluence/SignalTypes.mqh            (TradeCandidate, CandidateStatus)
Confluence/ConfluenceEngine.mqh       (wired builder into Update/Shutdown)
```

## Structural Engine Contract
All detectors remain read-only. No modifications to any structural component.

## Project Pipeline
```
v1.0  Structural Truth    (Swing, BOS, CHOCH, OB, FVG, Liquidity)
v1.1  Rule Truth          (7 rule evaluators, RuleResult)
v1.2  Trade Intent        (TradeCandidate aggregation)
```
