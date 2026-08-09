# CHOCHDetector API — v0.8.0 (Frozen)

**File:** `Structure/CHOCHDetector.mqh`
**Class:** `CCHOCHDetector`

## Purpose

Detects Change of Character (CHOCH) events. A bullish CHOCH occurs when price closes above the active protected high during a bearish trend. A bearish CHOCH occurs when price closes below the active protected low during a bullish trend.

## Public API

```
bool Init(void)
```
Allocates internal state. Call once before first `Update()`.

```
void Update(CTrendState *trendState,
            CProtectedPointManager *protectedMgr,
            const double &close[], const datetime &time[], int rates_total)
```
Checks the current bar's close against the active protected point in the context of the current trend.

```
void Shutdown(void)
```
Releases allocated memory.

```
bool IsInitialized(void) const
```
Returns true after `Init()` succeeds.

```
int GetCHOCHCount(void) const
```
Returns the number of detected CHOCH events.

```
bool GetCHOCH(int index, CHOCHEvent &out) const
```
Copies the CHOCH event at `index` into `out`. Returns false if index is out of range.

## Output Struct

```
struct CHOCHEvent {
    int      id;                // sequential ID
    int      protectedPointID;  // ID of the protected point that was broken
    bool     bullish;           // true = bullish CHOCH (close above protected high)
    datetime time;              // bar timestamp of the CHOCH
    double   breakPrice;        // close price that broke the protected point
    int      barIndex;          // bar index where the break occurred
};
```

## Invariants

- Checks only `close[0]` (the current bar) on each incremental call.
- A bullish CHOCH requires: `GetCurrentTrend() == TREND_BEARISH && close[0] > activeHigh.price`.
- A bearish CHOCH requires: `GetCurrentTrend() == TREND_BULLISH && close[0] < activeLow.price`.
- Each protected point can be broken only once.

## Guarantees

- CHOCH events are detected the instant the close crosses the protected level.
- IDs are sequential and start at 0.
- No false positives: both trend direction and price level must align.

## Callers

- `COrderBlockDetector`

## Callers Must Not Assume

- That a CHOCH guarantees an immediate trend reversal. It signals a potential shift.
- That `GetCHOCH(0)` is the most recent event. Check `time` or `barIndex`.
- That every bar produces a CHOCH. Most bars produce none.
