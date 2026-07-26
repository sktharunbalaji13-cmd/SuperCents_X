# Performance Baseline

## v1.0 Structural Engine

**Date:** 2026-07-26
**Commit:** `601f4c2`
**Binary:** `SuperCents_X.ex5`
**Test:** 2-month EURUSD M15, Every Tick

## v1.2 Trade Candidate Engine (Sprint 13.3)

**Date:** 2026-07-26
**Tag:** `v1.2-trade-candidate-engine`
**Binary:** `SuperCents_X.ex5`
**Test:** 2-month EURUSD M15, Every Tick

| Candidate Metric | Value |
|------------------|-------|
| Total Created | 3,918 |
| Total Expired | 4 |
| Active Remaining | 3,914 |
| Bullish | 1,951 |
| Bearish | 1,967 |
| Avg Score | 80 |
| Avg Confidence | 0.84 |
| Max Evidence Set | 4 |
| Max Rule Set | 3 |

### Invariants
- Direction balance: 1951 + 1967 = 3918 = Total Created ✅
- Active + Expired: 3914 + 4 = 3918 = Total Created ✅

## v1.1 Rule Evaluation Engine (Sprint 13.2)

**Date:** 2026-07-26
**Tag:** `v1.1-rule-evaluation`
**Binary:** `SuperCents_X.ex5`
**Test:** 2-month EURUSD M15, Every Tick

| Signal Metric | Value |
|---------------|-------|
| Total Signals Created | 3,935 |
| Total Signals Expired | 3,517 |
| Active Remaining | 418 |
| Bullish | 1,792 |
| Bearish | 1,726 |
| None | 417 |

| Rule | Matches | Rejects |
|------|---------|---------|
| BOS + OB Bullish | 302 | 3,633 |
| BOS + OB Bearish | 362 | 3,573 |
| OB + FVG Bullish | 1,660 | 2,275 |
| OB + FVG Bearish | 1,711 | 2,224 |
| Liquidity + BOS Bullish | 487 | 3,448 |
| Liquidity + BOS Bearish | 606 | 3,329 |
| CHOCH + OB Reversal | 125 | 3,810 |
| **Total** | **5,253** | **22,292** |

| Expiry Reason | Count |
|---------------|-------|
| FVG Filled | 2,056 |
| OB Mitigated | 47 |
| OB Invalidated | 235 |
| Liquidity Mitigated | 194 |
| Liquidity Invalidated | 625 |
| Trend Reversal | 360 |

---

## Liquidity Detector

| Metric | Value |
|--------|-------|
| Total levels created | 2,108 |
| Total swing members processed | 9,085 |
| Liquidity clusters | 1,170 |
| Largest cluster | 58 members |
| Average cluster size | 7.0 members |
| Sweep rate (swept/created) | 84.4% |
| Average sweep delay | 15,923 bars |
| Maximum sweep delay | 28,666 bars |
| Lifecycle violations | 0 |
| Illegal transitions | 0 |
| Conservation failures | 0 |

## BOS Detector

| Metric | Value |
|--------|-------|
| Locked High Pivots | 3,054 |
| Locked Low Pivots | 3,054 |
| Bullish BOS | 467 |
| Bearish BOS | 471 |
| Duplicate BOS prevented | 208,653,933 |

## CHOCH Detector

| Metric | Value |
|--------|-------|
| Bullish CHOCH accepted | 146 |
| Bearish CHOCH accepted | 154 |
| Total CHOCH events | 300 |
| Duplicate rejects | 34 |

## Order Block Detector

| Metric | Value |
|--------|-------|
| CHOCH received | 300 |
| Search attempted | 300 |
| Search succeeded | 300 |
| Search failed | 0 |
| Store success | 300 |
| Duplicate/invalid rejects | 0 |

## FVG Detector

| Metric | Value |
|--------|-------|
| Total FVGs created | 60 |
| Strong | 22 |
| Normal | 38 |
| Weak | 0 |
| Large | 9 |
| Medium | 22 |
| Small | 29 |
| Continuation | 24 |
| Reversal | 1 |
| Breakaway | 2 |
| Unknown | 33 |

---

## System Configuration

| Parameter | Value |
|-----------|-------|
| Symbol | EURUSD |
| Timeframe | M15 |
| Test range | 2026-01-01 → 2026-03-01 (60 days) |
| Model | Every Tick |
| Deposit | 10,000 GBP |
| Leverage | 1:200 |

---

*Future optimizations should be measured against these baseline values.*
