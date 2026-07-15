# SwingDetector API — v0.8.0 (Frozen)

**File:** `Structure/SwingDetector.mqh`
**Class:** `CSwingDetector`

## Purpose

Identifies swing highs and swing lows from raw OHLC data. A swing high is a bar whose high is higher than both neighbors; a swing low is a bar whose low is lower than both neighbors.

## Public API

```
bool Init(void)
```
Allocates internal buffers. Call once before first `Update()`.

```
void Update(const double &high[], const double &low[],
            const datetime &time[], int rates_total)
```
Processes the bar window. Detects swings using `SWING_STRENGTH` bars of lookback/lookahead on each side.

```
void Shutdown(void)
```
Releases allocated memory.

```
void Clear(void)
```
Resets all detected swings without releasing memory. Reuse without re-init.

```
bool IsInitialized(void) const
```
Returns true after `Init()` succeeds.

```
int GetSwingHighCount(void) const
```
Returns the number of detected swing highs.

```
int GetSwingLowCount(void) const
```
Returns the number of detected swing lows.

```
bool GetSwingHigh(int index, SwingPoint &out) const
```
Copies the swing high at `index` into `out`. Returns false if index is out of range.

```
bool GetSwingLow(int index, SwingPoint &out) const
```
Copies the swing low at `index` into `out`. Returns false if index is out of range.

## Output Struct

```
struct SwingPoint {
    int      id;          // sequential ID
    datetime time;        // bar timestamp
    double   price;       // high (for swing high) or low (for swing low)
    int      barIndex;    // index in bar array
    bool     isHigh;      // true = swing high, false = swing low
};
```

## Invariants

- Swings are detected at `SWING_STRENGTH` bars (defined in `Constants.mqh`, default 2).
- IDs are sequential and start at 0.
- `GetSwingHigh()` and `GetSwingLow()` each have their own independent index space.

## Guarantees

- `Init()` is idempotent when called multiple times.
- `Update()` never throws or allocates after `Init()`.
- Multiple instances do not share state.

## Callers

- `CStructuralPivotEngine`

## Callers Must Not Assume

- Swing order in the output list (newest-first vs oldest-first). Use `time` for chronology.
- That swings are detected on the first bar after `Init()`. Minimum `SWING_STRENGTH * 2 + 1` bars are required.
