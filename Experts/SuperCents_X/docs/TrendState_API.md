# TrendState API — v0.8.0 (Frozen)

**File:** `Structure/TrendState.mqh`
**Class:** `CTrendState`

## Purpose

Maintains the current market trend direction based on BOS activity. Trend is determined by the most recent BOS direction: a bullish BOS sets `TREND_BULLISH`, a bearish BOS sets `TREND_BEARISH`.

## Public API

```
bool Init(void)
```
Allocates internal state. Call once before first `Update()`.

```
void Update(CBOSDetector *bosDetector)
```
Reads BOS events from `bosDetector` and updates trend direction.

```
void Shutdown(void)
```
Releases allocated memory.

```
bool IsInitialized(void) const
```
Returns true after `Init()` succeeds.

```
Trend GetCurrentTrend(void) const
```
Returns the current trend. One of `TREND_BULLISH`, `TREND_BEARISH`, or `TREND_UNKNOWN`.

```
int GetBullishBOSCount(void) const
```
Returns the count of bullish BOS events seen since init.

```
int GetBearishBOSCount(void) const
```
Returns the count of bearish BOS events seen since init.

## Enum

```
enum Trend {
    TREND_UNKNOWN  = 0,
    TREND_BULLISH  = 1,
    TREND_BEARISH  = -1
};
```

## Invariants

- Trend starts as `TREND_UNKNOWN` after `Init()`.
- A bullish BOS changes trend to `TREND_BULLISH`.
- A bearish BOS changes trend to `TREND_BEARISH`.
- Trend changes immediately on detecting a new BOS in the opposite direction.

## Guarantees

- `GetCurrentTrend()` always returns a valid `Trend` value.
- Multiple consecutive BOS events in the same direction keep the trend unchanged.
- No lookback or hysteresis — trend reflects the most recent BOS.

## Callers

- `CProtectedPointManager`
- `CCHOCHDetector`
- `COrderBlockDetector`

## Callers Must Not Assume

- That `TREND_BULLISH` means price is rising. It means the most recent BOS was bullish.
- That trend persists for any minimum duration. It can flip on every bar.
