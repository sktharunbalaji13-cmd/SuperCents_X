# Architecture — SuperCents_X v0.8.0

## Design Philosophy

Pure market-structure detectors. No rendering, no entries, no trading decisions.
Each module is a deterministic state machine with a single responsibility.

## Pipeline

Each module consumes the output of the previous layer and exposes a read-only API.

```
SwingDetector                    (high[], low[], time[])
    ↓
StructuralPivotEngine            (CSwingDetector*)
    ↓
BOSDetector                      (CStructuralPivotEngine*, close[], time[])
    ↓
TrendState                       (CBOSDetector*)
    ↓
ProtectedPointManager            (CStructuralPivotEngine*, CBOSDetector*, CTrendState*)
    ↓
CHOCHDetector                    (CTrendState*, CProtectedPointManager*, close[], time[])
    ↓
OrderBlockDetector               (CCHOCHDetector*, CTrendState*, CProtectedPointManager*,
                                   open[], high[], low[], close[], time[])
```

## Module Lifecycle

Every module follows the same contract:

1. `Init()` — allocate internal state
2. `Update(...)` — process new bar data
3. `Shutdown()` — release resources

All modules are reusable across test and production contexts. Any module can be instantiated multiple times without shared state.

## Data Flow

Bar data flows upward: price arrays → SwingDetector → PivotEngine → BOS → Trend → ProtectedPoint → CHOCH → OrderBlock.

No module modifies a downstream module's state. All communication is through read-only accessor methods.

## Versioning

v0.8.0 — Market Structure Engine (current, frozen)
v0.9.0 — Fair Value Gap Engine (next)
