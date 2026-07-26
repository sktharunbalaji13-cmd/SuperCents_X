# Performance Baseline

## v1.0 Structural Engine

**Date:** 2026-07-26
**Commit:** `601f4c2`
**Binary:** `SuperCents_X.ex5`
**Test:** 2-month EURUSD M15, Every Tick

## v1.4.1 Policy Tuning (Sprint 13.5a)

**Date:** 2026-07-26
**Tag:** `v1.4.1-policy-tuning`
**Binary:** `SuperCents_X.ex5`
**Test:** 2-month EURUSD M15, Every Tick

### Default Config Change

| Parameter | Old | New |
|-----------|-----|-----|
| `stopPolicy` | `STOP_OB_SIDE` | `STOP_PROTECTED_POINT` |
| `targetPolicy` | `TARGET_OPPOSING_LIQUIDITY` | `TARGET_OPPOSING_LIQUIDITY` |
| `minStopDistancePips` | 10.0 | 5.0 |

### Execution Plan Summary (new defaults)

| Metric | Value |
|--------|-------|
| Plans Created | 3,918 |
| Executable | 1,330 (34%) |
| Rejected | 2,588 |
| Avg RR | 2.83 |
| Avg Stop | 13.8 pips |
| Avg Target | 35.1 pips |

### Rejection Breakdown

| Reason | Count |
|--------|-------|
| Broker Min Stop | 2,259 |
| RR Below Minimum | 215 |
| Stop Too Close | 96 |
| Target Too Close | 18 |

### Policy Matrix (top findings)

| Combo | Exec | RR | Notes |
|-------|------|-----|-------|
| OB Retest + PP + Opp Liq | 37% | 2.14 | Original target sweep |
| FVG Midpoint + PP + FixedRR | 42% | 2.00 | Best entry |
| OB Retest + Liq Side + FixedRR | 19% | 2.00 | Wide stops (332 pips) |
| OB Retest + PP + Prev Swing | 24% | 1.06 | Low RR, many RR rejects |

### Success Criterion for Sprint 13.6
- **Executable ≥ 20%**: 1,330 (34%) ✅
- **Avg RR ≥ 1.5**: 2.83 ✅
- **Multiple rejection reasons exercised**: 4 distinct reasons ✅
- **All upstream layers unchanged**: 3,935 signals, 3,918 candidates, 3,918 decisions ✅
- **Idempotency**: Plan IDs tracked in `m_submittedIds[]` — no duplicate submissions ✅
- **Return codes captured**: All MT5 `TRADE_RETCODE_*` mapped to human-readable names ✅
- **Every submission produces TradeExecutionResult**: deterministic struct ✅

## v1.5 TradeManager / Order Execution (Sprint 13.6)

**Date:** 2026-07-26
**Tag:** `v1.5-trade-manager`
**Binary:** `SuperCents_X.ex5`
**Test:** 2-month EURUSD M15, Every Tick

### New Modules
- `Trading/TradeExecutionResult.mqh` — submission result struct
- `Trading/TradeRequestBuilder.mqh` — ExecutionPlan → MqlTradeRequest
- `Trading/TradeValidation.mqh` — broker-side pre-checks
- `Trading/TradeManager.mqh` — submission orchestrator with idempotency

### Renamed
- `Entry/TradeManager.mqh` → `Entry/PositionLifecycleManager.mqh` (class: `CTradeManager` → `CPositionLifecycleManager`)

### Pipeline (final)
```
ConfluenceEngine.Update() → signals + internal Candidate→Decision→Plan pipeline
TradeManager.Update()     → submits executable plans via OrderSend()
PositionLifecycleManager  → break-even / trailing stop on existing positions
```

### TradeManager Results (live against demo broker on tester)

| Metric | Value |
|--------|-------|
| Execution Plans Received | 2,605,321 (across all ticks) |
| Submitted (unique) | 1,330 |
| Succeeded (OrderSend=true) | 892 |
| Failed (OrderSend=false) | 438 |
| Duplicate Prevented | 2,603,991 |
| Avg Fill Price | 1.17869 |

### Invariants Preserved (unchanged from v1.4.1)
| Layer | Metric | Baseline | Current | Status |
|-------|--------|----------|---------|--------|
| Confluence | Total Signals | 3,935 | 3,935 | ✅ |
| Confluence | Signals Expired | 3,517 | 3,517 | ✅ |
| Confluence | Active Remaining | 418 | 418 | ✅ |
| Confluence | Bullish | 1,792 | 1,792 | ✅ |
| Confluence | Bearish | 1,726 | 1,726 | ✅ |
| Candidates | Total Created | 3,918 | 3,918 | ✅ |
| Candidates | Total Expired | 4 | 4 | ✅ |
| Candidates | Active Remaining | 3,914 | 3,914 | ✅ |
| Candidates | Bullish | 1,951 | 1,951 | ✅ |
| Candidates | Bearish | 1,967 | 1,967 | ✅ |
| Plans | Plans Created | 3,918 | 3,918 | ✅ |
| Plans | Plans Executable | 1,330 | 1,330 | ✅ |

### Shutdown Order (safe)
1. TradeManager (reads from planner, must shut down first)
2. ConfluenceEngine (owns planner internally → planner summary logged)
3. PositionLifecycleManager
4. All detectors (Swing → Pivot → BOS → Trend → PP → CHOCH → OB → FVG → Liq → Viz)

## v1.4 Execution Planner (Sprint 13.5)

**Date:** 2026-07-26
**Tag:** `v1.4-execution-planner`
**Binary:** `SuperCents_X.ex5`
**Test:** 2-month EURUSD M15, Every Tick

| Plan Metric | Value |
|-------------|-------|
| Plans Created | 3,918 |
| Executable | 0 |
| Rejected | 3,918 |

All rejected due to policy interaction (OB retest entry + OB side stop = 3 pip stop < 10 pip min).
Validation logic is correct; policy tuning deferred.

### Invariants (unchanged from v1.3)
- Confluence: 3,935 signals, 3,517 expired ✅
- Candidate: 3,918 created, 4 expired ✅
- Decision: 3,918 qualified, 4 expired ✅

## v1.3 Entry Decision Engine (Sprint 13.4)

**Date:** 2026-07-26
**Tag:** `v1.3-entry-decision`
**Binary:** `SuperCents_X.ex5`
**Test:** 2-month EURUSD M15, Every Tick

| Decision Metric | Value |
|-----------------|-------|
| Candidates Evaluated | 3,918 |
| Qualified | 3,918 |
| Rejected | 0 |
| Expired | 4 |
| Avg Score | 80.50 |
| Avg Confidence | 0.84 |
| Avg Evidence Count | 2.35 |
| Avg Rule Count | 1.34 |

### Invariants (unchanged from v1.2)
- Confluence: 3,935 signals, 3,517 expired, 418 active ✅
- Candidate: 3,918 created, 4 expired, 3,914 active ✅
- Detectors: BOS 467/471, CHOCH 300, OB 300, FVG 60, Liquidity 2108 ✅

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
