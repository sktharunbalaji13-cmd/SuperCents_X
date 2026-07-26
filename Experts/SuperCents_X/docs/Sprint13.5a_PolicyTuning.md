# Sprint 13.5a — Policy Tuning Interlude

**Date**: 2026-07-26
**Tag**: `v1.4.1-policy-tuning`
**Parent**: `v1.4-execution-planner` (2f465c6)

## Motivation

Sprint 13.5 produced 3,918 plans — all rejected. The execution engine was validated correctly,
but no plans reached the executable stage, making Sprint 13.6 (OrderSend) meaningless.

## What Changed

### New Default Config

```cpp
entryPolicy = ENTRY_OB_RETEST
stopPolicy  = STOP_PROTECTED_POINT          // was STOP_OB_SIDE
targetPolicy = TARGET_OPPOSING_LIQUIDITY     // unchanged
targetRR    = 2.0
stopBufferPips = 3.0
minStopDistancePips = 5.0                   // was 10.0
```

### Why These Values

**Entry: OB Retest** (39% exec, RR 2.0) — FVG midpoint was slightly higher (42%) but OBs are
more structurally reliable. Current price (0%) and liquidity level (10%) were worse.

**Stop: Protected Point** (39% exec) — Best of all stop policies. OB Side (0%), Liquidity Side
(19%, but 332 pip avg stops), Broker Minimum (0%).

**Target: Opposing Liquidity** (37% exec, RR 2.14) — Produces the most realistic target
level. Fixed RR (39%, RR 2.0) is comparable but less market-aware. Previous swing yields
low RR (1.06) with 608 RR rejects.

**Buffer: 3 pips** — 1/3/5 all produce similar results (39-40%). No reason to change.

**MinStop: 5 pips** — Best balance. 10 pips rejects too many (39% exec); 5 pips yields 42%
exec with minStop sweep, or 34% with the full default config.

### Fixed: Shutdown Order Use-After-Free

The matrix evaluation (which runs at shutdown) exposed a shutdown ordering bug:
`Engine::ShutdownModules()` deleted all detectors before calling
`ConfluenceEngine::Shutdown()`, causing the policy matrix to crash with dangling
pointer access. Moved ConfluenceEngine shutdown to the very top.

### Fixed: MQL5 Array Initialization

`double arr[] = {a, b, c};` does not work reliably. Changed to explicit:
```cpp
double arr[3]; arr[0] = a; arr[1] = b; arr[2] = c;
```

## Architecture

### Policy Matrix Evaluator (built during this sprint)

The `EvaluatePolicyCombos()` method in `ExecutionPlanner.mqh` runs 19 policy
combinations across all stored decisions at shutdown, collecting per-combo stats:
executable count, avg RR, avg stop/target distance, and rejection breakdown.

### Matrix Layout

| # | Dimension | Values Tested |
|---|-----------|---------------|
| 1-4 | Entry policy | OB Retest, FVG Midpoint, Liquidity Level, Current Price |
| 5-8 | Stop policy | OB Side, Liquidity Side, Protected Point, Broker Minimum |
| 9-13 | Target policy | Opposing Liq, Opposing OB, Opposing FVG, Fixed RR 2.0, Prev Swing |
| 14-16 | Buffer sensitivity | 1, 3, 5 pips |
| 17-19 | MinStop sensitivity | 5, 10, 20 pips |

## Regression Results

### Pipeline Invariants (unchanged)
- Signals: 3,935 created, 3,517 expired ✅
- Candidates: 3,918 created, 4 expired ✅
- Decisions: 3,918 qualified, 4 expired ✅

### Execution Plans (new defaults)
| Metric | Value |
|--------|-------|
| Plans Created | 3,918 |
| Executable | 1,330 (34%) |
| Rejected | 2,588 |
| Avg RR | 2.83 |
| Avg Stop | 13.8 pips |
| Avg Target | 35.1 pips |

### Rejections (4 distinct reasons)
| Reason | Count |
|--------|-------|
| Broker Min Stop | 2,259 |
| RR Below Minimum | 215 |
| Stop Too Close | 96 |
| Target Too Close | 18 |

## Acceptance Criteria

- [x] Pipeline validation sees both executable and rejected plans
- [x] Executable plans ≥ 20% → 34% ✅
- [x] Avg RR ≥ 1.5 → 2.83 ✅
- [x] Multiple rejection reasons → 4 distinct ✅
- [x] All upstream layers unchanged ✅
- [x] Policy matrix data collected and documented ✅
- [x] Sprint 13.6 readiness: **approved**
