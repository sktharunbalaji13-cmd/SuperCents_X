# Testing Strategy

## Overview

The Entry Engine verification suite covers four layers:

| Layer | File | Assertions | Scope |
|-------|------|-----------|-------|
| Unit | `TestValidators.mqh` | ~32 tests | Each validator's PASS/WARNING/FAIL logic + threshold boundaries |
| Registry | `TestValidatorRegistry.mqh` | ~8 tests | Registration, dedup, enable/disable, order, category count |
| Pipeline | `TestOrchestratorPipeline.mqh` | ~10 tests | Orchestrator short-circuit, warning accumulation, determinism, no-mutation |
| Benchmarks | `EntryBenchmarks.mqh` | 12 series | Per-validator microbenchmarks + orchestrator scenarios |

## Unit Tests

Every numeric-validator tests three outcome paths:

- **PASS** — well within limits
- **WARNING** — approaching but not exceeding threshold
- **FAIL** — exceeding threshold

Plus boundary vectors at exact thresholds (e.g., 59.9 vs 60.0 for confidence).

## Registry Tests

Covers the `CValidatorRegistry` contract:

- Register returns true for new names, false for duplicates
- Disabled validators are skipped during iteration
- Unregister removes only the named validator
- CountByCategory reflects current registrations
- Execution order matches registration order

## Pipeline Tests

Integration tests with mock validators:

- Stop on first FAIL (short-circuit)
- WARNINGs do not stop the pipeline
- Disabled validators are skipped
- Filter ordering matches registration order
- **Determinism**: 1000 identical runs must produce identical decisions
- **No-mutation**: validators must not modify ConfluenceResult or EntryContext

## Benchmarks

Each benchmark series follows the warmup / measure pattern:

1. Warm-up N iterations (discarded)
2. Measure M iterations
3. Record min/avg/max/stddev

Results are appended to the performance baseline file.

## Regression Detection

Baseline values are stored in `benchmarks/results/` and compared against
previous runs to detect performance regressions before they reach production.

## Exit Criteria

- ~50 tests passing
- Registry verified
- Determinism verified (1000 iterations)
- No-mutation invariants verified
- Benchmarks recorded
- All three targets compile with 0 errors
