# BOSDetector API — v0.8.0 (Frozen)

**File:** `Structure/BOSDetector.mqh`
**Class:** `CBOSDetector`

## Purpose

Detects Break of Structure (BOS) events. A bullish BOS occurs when price closes above a prior high pivot. A bearish BOS occurs when price closes below a prior low pivot.

## Public API

```
bool Init(void)
```
Allocates internal buffers. Call once before first `Update()`.

```
void Update(CStructuralPivotEngine *pivotEngine,
            const double &close[], const datetime &time[], int rates_total)
```
Scans pivots from `pivotEngine` and detects breaks against close prices.

```
void Shutdown(void)
```
Releases allocated memory.

```
void Clear(void)
```
Resets all BOS events without releasing memory.

```
bool IsInitialized(void) const
```
Returns true after `Init()` succeeds.

```
int GetBOSCount(void) const
```
Returns the number of detected BOS events.

```
bool GetBOS(int index, BOSEvent &out) const
```
Copies the BOS event at `index` into `out`. Returns false if index is out of range.

## Output Struct

```
struct BOSEvent {
    int      id;              // sequential ID
    int      brokenPivotID;   // ID of the pivot that was broken
    bool     bullish;         // true = bullish BOS (close above high pivot)
    datetime breakTime;       // timestamp of the breaking bar
    int      breakBar;        // bar index of the breaking bar
    double   pivotPrice;      // price of the broken pivot
    double   closePrice;      // close price that broke the pivot
};
```

## Invariants

- A pivot is broken when `close[breakBar]` is beyond the pivot's price.
- Bullish BOS breaks above a high pivot; bearish BOS breaks below a low pivot.
- The first BOS on a new pivot marks the break; subsequent reps are not re-reported.
- IDs are sequential.

## Guarantees

- A broken pivot is marked `isBroken = true`.
- `Update()` processes only new bars since the last call (incremental).
- All pivot IDs referenced by `brokenPivotID` exist in the source pivot engine.

## Callers

- `CTrendState`
- `CProtectedPointManager`

## Callers Must Not Assume

- That BOS events arrive in chronological order. Check `breakTime` for sequencing.
- That a bullish BOS guarantees an uptrend. TrendState determines trend duration.
