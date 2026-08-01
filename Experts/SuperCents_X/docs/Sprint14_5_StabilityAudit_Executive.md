# Sprint 14.5 — Long-Run Stability Audit: Executive Summary (Report A)

**Build identity**
- Git Tag: `v2.9.1-calibration-stable` | Commit: `ae100ba`
- EA Version: `2.90` | Telemetry Schema: `v1` | Benchmark Format: `2`
- MQL5 Build: `6070` | Platform: MetaTrader 5, MetaQuotes-Demo (Hedge)

**Audit scope** (zero code changes; read-only observation)

| Run | Symbol/Period | Range | Model | Bars | Ticks | Wall | Decisions |
|---|---|---|---|---|---|---|---|
| EURUSD M15 | EURUSD M15 | 2025.11.01–2026.01.31 | 4 (every tick) | 6,046 | 5,395,218 | 17:18 | 6,046 |
| GBPJPY H1* | GBPJPY H1 | 2025.11.01–2026.01.31 | 4 (every tick) | 1,512 | 7,116,332 | 0:36 | 1,509 |
| Benchmarks | — | — | 4 | — | — | 0:13 | 61/61 |

\* **Documented deviation**: XAUUSD H1 was requested but is not available on MetaQuotes-Demo (tester aborts silently at startup). Substituted with **GBPJPY H1** — the closest behavioral proxy on the server (high volatility, wide spreads, strong trends). All audit results reference the substitution.

Config: `ENTRY_MODE_SHADOW`, weights 25/20/15/15/15/10 (v2.9 baseline, sum=100), Deposit 10,000 GBP, Leverage 200, Visual=0, ShutdownTerminal=1. Shadow mode verified via the `Entry Engine running in ENTRY_MODE_SHADOW mode` banner in every run.

## Overall verdict

**The platform is stable and runnable. No crashes, no errors, no corruption, no resource failures. The audit found no CRITICAL findings — but it did expose data-quality and architecture-level issues that directly feed the Sprint 15 inputs (telemetry + shadow comparison).**

## Finding counts

| Severity | Count | IDs |
|---|---|---|
| CRITICAL | 0 | — |
| ANOMALY | 4 | A-01, A-02, A-03, A-04 |
| WARNING | 3 | A-05, A-06, A-07 |
| INFO | 3 | A-08, A-09, A-10 |

## Top findings (condensed)

1. **A-01 ANOMALY (high) — Shadow comparison is not legacy-vs-modern.** `SymbolContext.mqh:703` (explicit `TODO(v2.9)`) compares *execution-plan existence* against *validator-gated status of the same confluence score*. Direction agreement is trivially 100% on both symbols; the agreement% (EURUSD 38.2%, GBPJPY 2.5%) measures plan-vs-validator coincidence, not engine divergence.
2. **A-02 ANOMALY (high) — Confidence scale mismatch inside the frozen schema.** Same struct/log records `legacyConfidence` on 0–100 (`40.00`) and `newConfidence` on 0–1 (`0.40`). All 7,555 shadow rows land `newConf` in the 0–0.9 bin. Violates the `@frozen v2.9` column contract; `CalibrationDataset` reads both columns into one struct.
3. **A-03 ANOMALY (medium) — Telemetry collector is not wired.** `CTelemetryCollector` is never instantiated by any module. Zero `telemetry_v1_*.csv` rows exist at runtime in any location. The frozen schema and the calibration store are dormant in v2.9.1.
4. **A-04 ANOMALY (medium) — Per-bar latency degrades monotonically.** EURUSD M15 Update: avg 38.8 ms → 375.6 ms, p95 44 → 410 ms across 13 weeks (+10×). GBPJPY H1: 19.2 → 30.5 ms (+1.6×). Driver: `BOS_DETECTOR` (avg 112.2 ms/bar, 678 s total) + `VISUALIZATION_MANAGER` (32.7 ms/bar) state accumulation.
5. **A-05 WARNING (medium) — ConfluenceValidator rejects 98% of decisions** (4,785/4,880 EURUSD) at threshold 0.6, with confidence mass concentrated at 40–49 (55% of rows). Consistent with calibrated selectivity, but an extreme gate concentration to monitor.
6. **A-06 WARNING (low) — GBPJPY shadow agreement collapses to ~0–5%** after week 1 (13.7% → 0%) — symbol sensitivity of the current comparison construction.
7. **A-07 WARNING (low) — Validator threshold price-scale sensitivity.** `DistanceValidator` (0.005) warned 21× on GBPJPY, 0× on EURUSD, clustered in early/late Nov. `SpreadValidator` warned 7× EURUSD (12–15 pt) + 3× GBPJPY, plus 95 spread rejections.
8. **A-08 INFO — Log volume:** ~794k lines / 98.5 MB per 3-month M15 run (~130 lines/bar, DEBUG per-bar prints); agent day-log reached 308 MB.
9. **A-09 INFO — Shutdown duplicates:** `Engine shutdown complete` printed 5× within 4 ms (single deinit event; cosmetic).
10. **A-10 INFO — Config tooling risk:** `EntryMode` defaults to LEGACY; presets only load as UTF-16 `.set` in `Profiles\Tester` (auto-saved). Two early pilots silently ran LEGACY before the mechanism was corrected.

## Shadow summary

| Run | Decisions | Agreements | Agreement % | Direction match |
|---|---|---|---|---|
| EURUSD M15 (3 mo) | 6,046 | 2,310 | 38.2% | 100% |
| GBPJPY H1 (3 mo) | 1,509 | 37 | 2.5% | 100% |
| Pilot (EURUSD M15, 1 wk) | 480 | 121 | 25.2% | 100% |

Shadow comparison executed on **every bar** (6,046/6,046 and 1,512/1,509) with ~28–33 µs per comparison — coverage complete, overhead negligible. **Interpretation caveat**: per A-01/A-02, these percentages are structural artifacts, not a legacy-vs-modern divergence measurement.

## Benchmark summary

Re-run of all 61 benchmarks (10:07 UTC) vs frozen `baseline_v2.9.txt` (08:53): **61/61 matched, 0 regressions**. Two flags are sub-100 µs rows (`RegisterEvaluators` 0.42×, `SessionValidator` 0.00×) — noise per the frozen v2.9.1 rule. Observed but within bounds: `MonteCarlo.100Trades/500Trades` ~0.55–0.70× (rerun faster), `WalkForward.Rolling/Anchored` ~1.3–1.6× (rerun slower). Headers identical except `Date`.

## Acceptance criteria (user-defined)

| # | Criterion | Result |
|---|---|---|
| 1 | No crashes or assertions | ✅ PASS (both runs rc=0, "Test passed", clean deinit) |
| 2 | No memory/resource anomalies | ⚠ Memory stable 409–434 MB; log volume high but bounded |
| 3 | No unexpected init/shutdown | ⚠ 1 init per run; shutdown log duplicated ×5 (cosmetic) |
| 4 | No unexplained latency spikes | ⚠ No spikes, but monotonic +10× trend (A-04) |
| 5 | No telemetry corruption/missing records | ❌ FAIL — zero records produced (A-03); scale mismatch (A-02) |
| 6 | Shadow comparison stable over full run | ❌ FAIL — structurally inconsistent comparison (A-01/A-02) |
| 7 | No recurring validator failures from infrastructure | ✅ PASS (rejections are data-driven) |
| 8 | Benchmark variance within expected bounds | ✅ PASS (61/61, 0 regressions) |
| 9 | No CRITICAL findings | ✅ PASS (max severity = ANOMALY) |

## Recommendation

# B — RECOMMEND v2.9.2 MAINTENANCE

Rationale: the platform is stable (no CRITICAL findings, all acceptance-criteria failures are data-quality/architecture-level, all root causes identified with high confidence — nothing requires open-ended investigation, so **not Case C**). However, A-01/A-02/A-03 sit directly on the Sprint 15 input path (live calibration consumes telemetry + shadow data; production providers replace the current shadow providers). Sprint 15 must not start against those inputs as-is.

**Proposed v2.9.2 scope (recommendations only — no fixes performed in this audit):**
1. Normalize `legacyConfidence`/`newConfidence` to one scale in `ShadowComparison` + CSV columns (A-02).
2. Decide and document shadow comparison semantics for Sprint 15: real legacy engine comparison or explicitly "plan-vs-validator" metric; fix `directionMatch` to not be trivially 100% (A-01).
3. Wire `CTelemetryCollector` into the runtime or consciously defer with the schema marked dormant (A-03).
4. Document `ConfluenceValidator` 98% gate concentration and confidence distribution (A-05); review DistanceValidator price scaling (A-07).
5. Optional perf pass on BOS/VISUALIZATION state growth before M15+ live use (A-04).

**Decision gate: B — RECOMMEND v2.9.2 MAINTENANCE, then Sprint 15.**
