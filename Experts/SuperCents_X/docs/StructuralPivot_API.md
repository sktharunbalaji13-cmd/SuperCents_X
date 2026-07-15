# StructuralPivotEngine API — v0.8.0 (Frozen)

**File:** `Structure/StructuralPivotEngine.mqh`
**Class:** `CStructuralPivotEngine`

## Purpose

Converts swing highs/lows into alternating structural pivots. Enforces the alternating high-low-high-low pattern required for market structure analysis. Replaces pivots when a higher-high or lower-low forms.

## Public API

```
bool Init(void)
```
Allocates internal buffers. Call once before first `Update()`.

```
void Update(CSwingDetector *swingDetector)
```
Reads all swings from `swingDetector` and builds/reconciles the structural pivot chain.

```
void Shutdown(void)
```
Releases allocated memory.

```
void Clear(void)
```
Resets all pivots without releasing memory.

```
bool IsInitialized(void) const
```
Returns true after `Init()` succeeds.

```
int GetPivotCount(void) const
```
Returns the number of structural pivots.

```
bool GetPivot(int index, StructuralPivot &out) const
```
Copies the pivot at `index` into `out`. Returns false if index is out of range.

## Output Struct

```
struct StructuralPivot {
    int      id;           // sequential ID
    int      swingID;      // ID of the source swing point
    datetime time;         // bar timestamp
    double   price;        // high (for high pivot) or low (for low pivot)
    int      barIndex;     // index in bar array
    bool     isHigh;       // true = high pivot, false = low pivot
    bool     isProtected;  // true if locked by a BOS in the opposite direction
    bool     isBroken;     // true if closed beyond by a BOS
};
```

## Invariants

- Pivots alternate: high → low → high → low ...
- A new high pivot replaces the previous high pivot if it has higher price.
- A new low pivot replaces the previous low pivot if it has lower price.
- `isProtected` is set by the ProtectedPointManager, not by this module.
- `isBroken` is set by the BOSDetector, not by this module.

## Guarantees

- Every swing high or low from the SwingDetector is evaluated.
- The pivot chain remains structurally consistent after each `Update()`.
- Multiple instances do not share state.

## Callers

- `CBOSDetector`
- `CProtectedPointManager`

## Callers Must Not Assume

- That `GetPivot(0)` returns the most recent pivot. Check `barIndex` or `time`.
- That the pivot count equals the swing count. Pivots may be replaced, reducing the count.
