# Sprint 13.4 — Entry Decision Engine

**Frozen**: 2026-07-26
**Tag**: `v1.3-entry-decision`
**Parent**: `v1.2-trade-candidate-engine` (10a8cc7)

## Architecture

```
TradeCandidates (immutable)
        │
        ▼
EntryDecisionEngine (stateless)
  ├─ CheckDecisionLifecycles — expire decisions when candidates expire
  ├─ EvaluateCandidate — apply policy gates
  │     ├─ ScoreGate      (MinDecisionScore)
  │     ├─ ConfidenceGate (MinConfidence)
  │     ├─ EvidenceGate   (MinEvidenceSources)
  │     ├─ RuleGate       (MinRuleMatches)
  │     └─ TrendGate      (requireTrendAlignment)
  │
  ▼
EntryDecision { candidateId, decisionScore, status, rationale }
```

## New Files

```
Entry/
├── EntryDecisionTypes.mqh    (EntryDecisionStatus, EntryDecision, EntryDecisionConfig)
├── EntryDecisionRules.mqh    (GateResult, DecisionGates, CheckScoreGate etc.)
├── EntryDecisionEngine.mqh   (CEntryDecisionEngine — orchestrator)
```

## Modified Files

```
Utils/Constants.mqh           (+MODULE_ENTRY_DECISION)
Confluence/ConfluenceEngine.mqh  (wired m_entryDecisionEngine into Update/Shutdown)
```

## Key Design Decisions

- **Stateless engine** — same candidate always produces same decision
- **Immutable candidates** consumed read-only; no modification to any prior layer
- **Policy gates configurable** via `EntryDecisionConfig` struct (defaults: score≥70, confidence≥0.75, evidence≥2, rules≥1, trendAlignment=off)
- **Explainable** — every qualification/rejection logs gate results
- **Lifecycle** — QUALIFIED decisions expire when backing candidate expires
- **No entry price, SL, TP, or position size** — reserved for later execution sprint

## Regression Results (2-month M15)

### Entry Decision Summary
| Metric | Value |
|--------|-------|
| Candidates Evaluated | 3,918 |
| Qualified | 3,918 |
| Rejected | 0 |
| Expired | 4 |
| Avg Decision Score | 80.50 |
| Avg Confidence | 0.84 |
| Avg Evidence Count | 2.35 |
| Avg Rule Count | 1.34 |

### Invariants (unchanged from v1.2)
- Confluence signals: 3,935 created, 3,517 expired ✅
- Rule match/reject counts identical to v1.1 ✅
- Trade candidates: 3,918 created, 4 expired ✅
- Detectors unchanged (BOS 467/471, CHOCH 300, OB 300, FVG 60, Liquidity 2108) ✅

### Log Samples
```
ENTRY-QUALIFIED Candidate=1 Score=100 Confidence=0.99 Reasons: Score 100 >= 70 | Confidence 0.99 >= 0.75 | 3 evidence sources >= 2 | 3 matching rules >= 1
ENTRY-EXPIRED Candidate=2314 reason=CandidateExpired
```

## Acceptance Criteria

- [x] Entry decisions consume immutable TradeCandidates only
- [x] Decision thresholds are configurable (EntryDecisionConfig)
- [x] Every qualification and rejection is explainable
- [x] Entry setups immutable after creation (status transitions only)
- [x] No mutation in structural, rule, or candidate layers
- [x] Two-month regression produces deterministic decision counts (3918 evaluated, 3918 qualified, 4 expired)
