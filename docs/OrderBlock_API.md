# OrderBlockDetector API — v0.8.0 (Frozen)

**File:** `Structure/OrderBlockDetector.mqh`
**Class:** `COrderBlockDetector`

## Purpose

Detects Order Blocks following CHOCH events. An Order Block is the last opposite-direction candle before the displacement move that caused the CHOCH.

## Public API

```
bool Init(void)
```
Allocates internal state. Call once before first `Update()`.

```
void Update(CCHOCHDetector *chochDetector,
            CTrendState *trendState,
            CProtectedPointManager *protectedMgr,
            const double &open[], const double &high[],
            const double &low[], const double &close[],
            const datetime &time[], int rates_total)
```
Processes new CHOCH events from `chochDetector` and locates the corresponding Order Block candle.

```
void Shutdown(void)
```
Releases allocated memory.

```
bool IsInitialized(void) const
```
Returns true after `Init()` succeeds.

```
int GetOrderBlockCount(void) const
```
Returns the number of detected Order Blocks.

```
bool GetOrderBlock(int index, OrderBlock &out) const
```
Copies the Order Block at `index` into `out`. Returns false if index is out of range.

## Output Struct

```
struct OrderBlock {
    int      id;             // sequential ID
    int      chochID;        // ID of the source CHOCH event
    bool     bullish;        // true = bullish Order Block (buy zone)
    datetime time;           // bar timestamp of the Order Block candle
    double   open;           // OHLC of the Order Block candle
    double   high;
    double   low;
    double   close;
    int      candleIndex;    // index in the bar array of the Order Block candle
    bool     mitigated;      // false (reserved for future use)
    bool     invalidated;    // false (reserved for future use)
    double   qualityScore;   // 1.0 (fixed in current version)
};
```

## Candle Selection Algorithm

For a **Bullish CHOCH** (bearish trend breaks up through protected high):
- Scan backward from the displacement candle.
- Find the **last bearish candle** (close < open) before the displacement.
- That candle is the Bullish Order Block.

For a **Bearish CHOCH** (bullish trend breaks down through protected low):
- Scan backward from the displacement candle.
- Find the **last bullish candle** (close > open) before the displacement.
- That candle is the Bearish Order Block.

**Skip rule:** Candles where `open == close` (doji) are skipped. The search continues to the next candle.

## Invariants

- One Order Block per CHOCH event (1:1 relationship).
- `chochID` always references a valid CHOCH from the CHOCHDetector.
- The Order Block candle is always **before** the displacement candle in time.
- The Order Block candle direction is always **opposite** to the CHOCH direction.
- `mitigated` and `invalidated` are reserved and always `false` in v0.8.0.
- `qualityScore` is always `1.0` in v0.8.0.

## Guarantees

- If a valid opposite-direction candle exists, an Order Block is always found.
- IDs are sequential with no gaps.
- No duplicate Order Block references to the same CHOCH.
- The algorithm is deterministic for the same input data.

## Callers

- (none in v0.8.0 — reserved for Entry Engine in future versions)

## Callers Must Not Assume

- That every CHOCH produces an Order Block. If no opposite candle exists before the displacement, no Order Block is returned.
- That `candleIndex == 0`. The displacement candle is not always adjacent to the Order Block.
- That `qualityScore` will remain 1.0 in future versions (reserved for scoring enhancements).
