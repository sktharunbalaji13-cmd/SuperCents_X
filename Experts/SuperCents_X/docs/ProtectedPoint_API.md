# ProtectedPointManager API — v0.8.0 (Frozen)

**File:** `Structure/ProtectedPointManager.mqh`
**Class:** `CProtectedPointManager`

## Purpose

Manages protected pivot points. A pivot becomes protected when a BOS in the opposite direction locks it. Protected points serve as the reference levels for Change of Character (CHOCH) detection.

## Public API

```
bool Init(void)
```
Allocates internal state. Call once before first `Update()`.

```
void Update(CStructuralPivotEngine *pivotEngine,
            CBOSDetector *bosDetector,
            CTrendState *trendState,
            const datetime &time[])
```
Processes pivots and BOS events to determine which pivots are now protected. The `time[]` array (1 element) provides the current bar timestamp for activation tracking.

```
void Shutdown(void)
```
Releases allocated memory.

```
bool IsInitialized(void) const
```
Returns true after `Init()` succeeds.

```
int GetProtectedPointCount(void) const
```
Returns the number of protected points.

```
bool GetProtectedPoint(int index, ProtectedPoint &out) const
```
Copies the protected point at `index` into `out`. Returns false if index is out of range.

```
bool GetActiveHigh(ProtectedPoint &out) const
```
Copies the currently active protected high into `out`. Returns false if no active high exists.

```
bool GetActiveLow(ProtectedPoint &out) const
```
Copies the currently active protected low into `out`. Returns false if no active low exists.

## Output Struct

```
struct ProtectedPoint {
    int      id;              // sequential ID
    int      pivotID;         // ID of the source structural pivot
    bool     isHigh;          // true = protected high, false = protected low
    datetime time;            // bar timestamp of the pivot
    double   price;           // pivot price
    int      barIndex;        // bar index
    bool     active;          // true if this point is currently active
    datetime activationTime;  // when this point became protected
};
```

## Invariants

- A high pivot becomes protected when a bearish BOS occurs in downtrend.
- A low pivot becomes protected when a bullish BOS occurs in uptrend.
- Only one active high and one active low exist at any time.
- A new protected point deactivates the previous one of the same type.

## Guarantees

- `GetActiveHigh()` / `GetActiveLow()` always return the most current reference level.
- Protected points persist in the list even after deactivation for historical reference.
- Activation times are monotonic.

## Callers

- `CCHOCHDetector`
- `COrderBlockDetector`

## Callers Must Not Assume

- That `GetActiveHigh()` / `GetActiveLow()` always succeed. Before any BOS, there are no protected points.
- That the protected point price equals the current market price. It is a historical reference level.
