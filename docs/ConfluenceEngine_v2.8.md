# Confluence Engine v2.8 — Evaluator Architecture

## Overview

The Confluence Engine at `Confluence/ConfluenceEngine.mqh` has been refactored to support a **modular evaluator pattern** while preserving full backward compatibility with the legacy rule-based scoring.

### Key Design Goal

Move from monolithic rule methods (`evaluateStructure`, `evaluateTrend`, etc.) inside the engine to **pluggable, testable evaluator classes** that implement a common `IConfluenceEvaluator` interface. The engine dispatches to registered evaluators; if none are registered, it falls back to the original rule logic unchanged.

---

## Architecture

```
┌──────────────────────────────────────────────┐
│            CConfluenceEngine                 │
│  (lifecycle, signal management, expiry)      │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │  Rule Path (no evaluators)            │  │
│  │  → evaluateStructure / evaluateTrend   │  │
│  │  → legacy score logic                 │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │  Evaluator Path (registrations exist) │  │
│  │  → IConfluenceEvaluator[] array       │  │
│  │  → EvaluateViaEvaluators()            │  │
│  │  → ConfluenceScoreCalculator          │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

### Components

| Component | File | Purpose |
|-----------|------|---------|
| `IConfluenceEvaluator` | `Confluence/Evaluators/IConfluenceEvaluator.mqh` | Pure virtual interface |
| `StructureEvaluator` | `Confluence/Evaluators/StructureEvaluator.mqh` | Evaluates structure confluence |
| `TrendEvaluator` | `Confluence/Evaluators/TrendEvaluator.mqh` | Evaluates trend confluence |
| `OrderBlockEvaluator` | `Confluence/Evaluators/OrderBlockEvaluator.mqh` | Evaluates order-block confluence |
| `FVGEvaluator` | `Confluence/Evaluators/FVGEvaluator.mqh` | Evaluates FVG confluence |
| `LiquidityEvaluator` | `Confluence/Evaluators/LiquidityEvaluator.mqh` | Evaluates liquidity confluence |
| `PremiumDiscountEvaluator` | `Confluence/Evaluators/PremiumDiscountEvaluator.mqh` | Evaluates premium/discount zone |
| `ConfluenceScoreCalculator` | `Confluence/ConfluenceScoreCalculator.mqh` | Weighted aggregation of component scores |
| `ConfluenceLogger` | `Confluence/ConfluenceLogger.mqh` | Structured logging for diagnostics |
| `ConfluenceWeights` | `Confluence/ConfluenceWeights.mqh` | Configurable weight struct |
| `ConfluenceTypes` | `Confluence/ConfluenceTypes.mqh` | Shared type definitions |

---

## Interface: `IConfluenceEvaluator`

Defined in `Confluence/Evaluators/IConfluenceEvaluator.mqh`:

```cpp
class IConfluenceEvaluator
{
public:
    virtual ~IConfluenceEvaluator() {}
    virtual void   Evaluate(DetectionContext &context, ConfluenceComponentResult &result) = 0;
    virtual ENUM_CONFLUENCE_COMPONENT GetComponentType() = 0;
    virtual string GetName() = 0;
    virtual string GetVersion() = 0;
    virtual string GetDescription() = 0;
};
```

---

## Weight Configuration

Weights are set via the `ConfluenceWeights` struct (`Confluence/ConfluenceWeights.mqh`). Defaults:

| Component | Weight |
|-----------|--------|
| Structure | 25 |
| Trend | 20 |
| OrderBlock | 15 |
| FVG | 15 |
| Liquidity | 15 |
| PremiumDiscount | 10 |

**Total = 100**

`ConfluenceWeights::IsValid()` returns `false` if weights sum to 0 or any single weight is negative.

---

## Usage

### With Evaluators (new path)

```cpp
CConfluenceEngine engine;
engine.Init();

CPremiumDiscountEvaluator pd;
engine.RegisterEvaluator(&pd);
engine.SetWeights(ConfluenceWeights());

engine.Update();  // uses evaluator path
```

### Without Evaluators (legacy path — identical to v2.7)

```cpp
CConfluenceEngine engine;
engine.Init();

engine.Update();  // uses legacy rule path, scores = 50/70/70/30
```

### Querying State

```cpp
if (engine.IsUsingEvaluators()) { ... }
ConfluenceResult latest = engine.GetLatestConfluence();
string signal = engine.BridgeConfluenceToSignal(0.6, 0.3, latest);
```

---

## Backward Compatibility

- All existing `ConfluenceSignal`, `RuleResult`, `TradeCandidate`, `EntrySetup` types are unchanged.
- Legacy rule logic inside the engine is untouched.
- `CConfluenceEngine::Init()` and `CConfluenceEngine::Update()` signatures are the same.
- All prior tests (WalkForward, MonteCarlo, Regression, ReportComposer, Integration) pass without modification.

---

## Testing

26 unit tests in `Tests/unit/TestConfluenceEngine.mqh` covering:

- Null/empty detector handling
- `ConfluenceWeights` validation
- `ConfluenceScoreCalculator` aggregation
- `PremiumDiscountEvaluator` zone logic
- Engine evaluator registration path
- Backward compatibility (no evaluators → legacy)
- Mixed evaluator integration

---

## Benchmarks

10 benchmarks in `benchmarks/BenchmarkConfluence.mqh`:

1. StructureEvaluator (individual)
2. TrendEvaluator (individual)
3. OrderBlockEvaluator (individual)
4. FVGEvaluator (individual)
5. LiquidityEvaluator (individual)
6. PremiumDiscountEvaluator (individual)
7. ScoreCalculator (aggregation)
8. Engine evaluator path (full Update)
9. Engine rule path (legacy Update)
10. Evaluator registration cost

---

## Changelog Summary (v2.8)

- New: `IConfluenceEvaluator` pure virtual interface
- New: 6 modular evaluator classes
- New: `ConfluenceScoreCalculator` for weighted aggregation
- New: `ConfluenceLogger` for structured logging
- New: `ConfluenceWeights` configurable weight struct
- New: `ConfluenceTypes` shared definitions
- Refactor: `CConfluenceEngine` supports evaluator registration + dispatch
- Compat: Legacy rule path fully preserved
