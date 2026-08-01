# Tests Directory

This directory contains the regression test suite and performance benchmarks for the Validation Lab and Confluence Engine subsystems.

## Regression Suite

**Entry point:** `TestRunner.mq5` (MQL5 Script)

**Test files (Validation Lab — v2.7):**
- `unit/TestAssert.mqh` — Custom assertion macros
- `unit/TestWalkForward.mqh` — WalkForward scheduler tests
- `unit/TestMonteCarlo.mqh` — Monte Carlo simulation tests
- `unit/TestRegression.mqh` — Regression detection tests
- `unit/TestReportComposer.mqh` — Report composer tests

**Test files (Confluence Engine — v2.8):**
- `unit/TestConfluenceEngine.mqh` — 26 evaluator, engine, and integration tests

**How to run:** Compile and execute `TestRunner.mq5` as a Script in the MetaTrader 5 Strategy Tester or on a chart. All 178 tests execute and report results to the Experts log.

**Expected output (v2.8):**
```
=== Validation Lab Test Suite ===
[TestAssert] All 5 assertion tests passed
[WalkForward] All 16 scheduler tests passed
[MonteCarlo] All 89 simulation tests passed
[Regression] All 28 regression tests passed
[ReportComposer] All 14 composer tests passed
[ConfluenceEngine] All 26 engine tests passed
>>> Validation Lab Test Suite complete — 178/178 passed
```

## Benchmark Suite

**Entry point:** `BenchmarkRunner.mq5` (MQL5 Script)

**Benchmark files (Validation Lab — v2.7):**
- `BenchmarkWalkForward.mqh` — 12 scheduler benchmarks (3 modes × 4 window sizes)
- `BenchmarkMonteCarlo.mqh` — 20 simulation benchmarks (5 iterations × 4 trade counts)
- `BenchmarkRegression.mqh` — 4 regression benchmarks (metric counts)
- `BenchmarkReportComposer.mqh` — 3 composer benchmarks (text sizes)

**Benchmark files (Confluence Engine — v2.8):**
- `BenchmarkConfluence.mqh` — 10 benchmarks (6 individual evaluators, ScoreCalculator, engine evaluator path, engine rule path, registration cost)

**How to run:** Compile and execute `BenchmarkRunner.mq5` as a Script in the MetaTrader 5 Strategy Tester or on a chart. All 49 benchmarks execute and output timing results to the Experts log.

**Output:** Each benchmark reports:
- Min/Avg/Max microseconds
- Standard deviation and RSD%
- Throughput (operations/sec)

A machine-readable baseline is written to the MT5 `Files/` directory:
```
Files/baseline_v2.8.txt
```

## Performance Baseline (`baseline_v2.8.txt`)

This is the canonical baseline for the v2.8 release. It contains timing data for all 49 benchmarks with the following format per line:

```
Benchmark.Label AvgUs=123.4 MinUs=100.0 MaxUs=150.0 StdDevUs=12.3 RSD=0.0997 Input=10 Unit=windows
```

**How to compare future runs against the baseline:**

1. Run `BenchmarkRunner.mq5` to generate a new baseline (`Files/baseline_current.txt`).
2. Compare per-benchmark `AvgUs` values against the canonical baseline.
3. A deviation > 2× the baseline RSD% indicates a significant performance change.
4. Investigate if any benchmark shows > 20% regression in `AvgUs`.

## Adding Tests

1. Create a new test file in `unit/` following the naming convention `Test*.mqh`.
2. Use `AssertTrue`, `AssertFalse`, `AssertEqual`, `AssertClose` from `TestAssert.mqh`.
3. Register your test functions in `TestRunner.mq5` by adding a call in `RunAllTests()`.
4. Run `TestRunner.mq5` to verify all tests pass.

## Adding Benchmarks

1. Create a new benchmark file in `benchmarks/` following the naming convention `Benchmark*.mqh`.
2. Use `BenchmarkResult` from `BenchmarkTypes.mqh` for measurement and output.
3. Register your benchmark function in `BenchmarkRunner.mq5` in `RunAllBenchmarks()`.
4. Run `BenchmarkRunner.mq5` to verify output and record a baseline.
