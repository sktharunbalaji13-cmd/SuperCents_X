# v1.0 Structural Engine — Architecture

## System Pipeline

```
Price Data
    │
    ▼
SwingDetector           — Identifies swing highs/lows
    │
    ▼
StructuralPivotEngine   — Selects structural pivots from swings
    │
    ▼
BOSDetector             — Detects Break of Structure
    │
    ▼
TrendState              — Maintains bullish/bearish/unknown trend
    │
    ▼
ProtectedPointManager   — Tracks protected (unbroken) pivot points
    │
    ▼
CHOCHDetector           — Detects Change of Character
    │
    ▼
OrderBlockDetector      — Identifies order blocks from CHOCH events
    │
    ▼
FVGDetector             — Identifies Fair Value Gaps
    │
    ▼
LiquidityDetector       — Clusters swing members, detects sweeps, manages lifecycle
```

## Data Ownership

Each detector owns its own objects and lifecycle. No shared mutable state between detectors.

| Object | Owner | Lifecycle |
|--------|-------|-----------|
| Swing | `SwingDetector` | Created on bar close, immutable |
| Structural Pivot | `StructuralPivotEngine` | Selected from swings, locked on BOS |
| BOS | `BOSDetector` | Emitted when locked pivot is broken |
| Trend | `TrendState` | Updated on each BOS event |
| Protected Point | `ProtectedPointManager` | Active until used or superseded |
| CHOCH | `CHOCHDetector` | Emitted when protected point is breached in opposite trend |
| Order Block | `OrderBlockDetector` | Created from CHOCH, immutable |
| FVG | `FVGDetector` | Created from swing gaps, classified |
| Liquidity Level | `LiquidityDetector` | ACTIVE → SWEPT → MITIGATED / INVALIDATED |

## Detector Interfaces (Frozen)

The following public APIs are frozen as of `v1.0-structural-engine`:

- `SwingDetector` — `Update()`, swing array access
- `StructuralPivotEngine` — `Update()`, pivot array access
- `BOSDetector` — `Update()`, BOS event array
- `TrendState` — `Update()`, trend query
- `ProtectedPointManager` — `Update()`, protected point access
- `CHOCHDetector` — `Update()`, CHOCH event array
- `OrderBlockDetector` — `Update()`, order block array
- `FVGDetector` — `Update()`, FVG array
- `LiquidityDetector` — `Update()`, liquidity level array, lifecycle management

## Invariants

1. **Conservation:** Every created liquidity level exists in exactly one lifecycle state at shutdown.
2. **Transitions:** ACTIVE → SWEPT → {MITIGATED, INVALIDATED}. No other paths.
3. **Irreversibility:** MITIGATED and INVALIDATED are terminal. No transitions out.
4. **Sweep → Invalidation:** An invalidated level must have been swept first, and a BOS in the opposite direction must have occurred after the sweep.
5. **Sweep → Mitigation:** A mitigated level must have been swept first, and price must have returned to the level's zone.

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Invalidation trigger | Opposite BOS after sweep | Market context, not time-based expiry |
| Mitigation vs Invalidation | Distinct terminal states | Mitigation = sweep failed (price returned), Invalidation = sweep succeeded (BOS confirmed) |
| Level membership | Swing-based clustering | Levels are groups of swing points at similar price, not individual lines |
| Incremental processing | Bar-by-bar update | No full re-scan, O(1) per bar for each detector |
