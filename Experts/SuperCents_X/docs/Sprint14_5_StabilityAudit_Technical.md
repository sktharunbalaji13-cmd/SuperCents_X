# Sprint 14.5 — Long-Run Stability Audit: Technical Report (Report B)

**Build identity**
- Git Tag: `v2.9.1-calibration-stable` | Commit: `ae100ba`
- EA Version: `2.90` | Telemetry Schema: `v1` | Benchmark Format: `2`
- MQL5 Build: `6070` | Platform: MetaTrader 5, MetaQuotes-Demo (Hedge)

## 1. Methodology & artifacts

- Zero code changes. Config-only artifacts: `MQL5\Presets\Sprint14_5_Audit.set` (EntryMode=1, weights 25/20/15/15/15/10), ini files in `Experts\SuperCents_X\Presets\Sprint14_5_*.ini`.
- Runs executed headless: `terminal64.exe /config:"<ini>"`, 4 local agents, Model=4 (every tick), Deposit 10,000 GBP, Leverage 200, Visual=0, ShutdownTerminal=1.
- Single evidence source: agent day-log `...\Agent-127.0.0.1-3000\logs\20260801.log` (UTF-16 LE, ~356 MB). Run windows pinned from `started with inputs` lines:
  - EURUSD: `09:29:40.930` → `09:46:59.200` (17:18 wall)
  - GBPJPY: `10:01:43.319` → `10:02:19.300` (00:36 wall; excludes 10:01:02 USDJPY and 10:01:12 GBPJPY smoke tests)
- Analysis scripts (read-only, gitignored `Temp\audit_14_5\`): `analyze_logs.py`, `summarize_shadow.py`, `parse_telemetry.py`, `parse_benchmarks.ps1`, `weekly.py`.
- Deviation: XAUUSD H1 does not exist on MetaQuotes-Demo (silent 0-byte tester exit). **GBPJPY H1 substituted** — closest volatility/spread proxy. All GBPJPY findings are proxy-labeled.

## 2. Run manifests

| | EURUSD M15 | GBPJPY H1 (proxy) |
|---|---|---|
| Range | 2025.11.01–2026.01.31 | 2025.11.01–2026.01.31 |
| Bars | 6,046 | 1,512 |
| Ticks | 5,395,218 | 7,116,332 |
| Test time (wall) | 17:18 (1,052 s) | 0:36 (36 s) |
| Log segment | 794,566 lines / 98.5 MB | 437,447 lines / 57.5 MB |
| Agent day-log after runs | 308 MB | 356 MB (after benchmarks) |
| `[ERROR]` | 0 | 0 |
| `[WARNING]` | 7 | 26 |
| Tester result | rc=0, "Test passed" | rc=0, "Test passed" |
| Init events | 1 | 1 |
| Shadow decisions | 6,046 (6,046/6,046 bars) | 1,509 (1,512 bars, 99.8%) |
| Shadow agreements | 2,310 (38.2%) | 37 (2.5%) |
| Direction match | 6,046 (100%) | 1,509 (100%) |

## 3. Runtime health (per subsystem)

- ✔ **Trading engine** — no crashes, no assertions, no errors; clean single deinit in both runs.
- ✔ **Entry validators** — 33 total warnings over 7,558 bars × 3 months (~0.4%); all "approaching max" style, **none exceeded**; rejections are data-driven (see §6), no infrastructure failures.
- ✔ **PortfolioManager** — no anomalies; per-bar DEBUG line volume noted in A-08.
- ✔ **Confluence engine** — no anomalies; direction consistency 100%; confidence values internally consistent (threshold comparisons use the same scale as their source). Scale mismatch is a **telemetry/schema-layer** issue (A-02), not a logic bug.
- ✔ **ExecutionPlanner** — SHADOW mode: no plan executions attempted; plan-existence only feeds the shadow comparison input (A-01).
- ❌ **Telemetry** — A-02 (scale), A-03 (not wired).
- ❌ **Shadow** — A-01 (construction), A-02 (scale).
- ✔ **Calibration** — file I/O and parsing healthy; consumed datasets are the A-01/A-02-afflicted artifacts (finding, not crash).
- ✔ **Memory/Resources** — agent memory stable 409–434 MB across runs (tick-data dominated); no handles/leak warnings; log growth bounded per-run (A-08).
- ❌ **Performance** — A-04 monotonic per-bar degradation.

## 4. Weekly timelines

### 4.1 EURUSD M15 (Monday-start weeks)

| Week | Decisions | Agr% | Warnings | Lat avg (ms) | Lat p95 (ms) |
|---|---|---|---|---|---|
| 2025.11.03 | 480 | 34.4 | 0 | 38.8 | 44.0 |
| 2025.11.10 | 480 | 31.7 | 0 | 53.9 | 66.8 |
| 2025.11.17 | 480 | 37.1 | 0 | 74.2 | 86.8 |
| 2025.11.24 | 480 | 51.0 | 0 | 93.0 | 106.3 |
| 2025.12.01 | 480 | 42.5 | 0 | 112.8 | 144.3 |
| 2025.12.08 | 480 | 31.2 | 0 | 128.6 | 144.8 |
| 2025.12.15 | 478 | 27.2 | 1 (12.18) | 150.0 | 167.6 |
| 2025.12.22 | 384 | 24.2 | 0 | 169.4 | 186.0 |
| 2025.12.29 | 384 | 66.1 | 0 | 186.0 | 203.8 |
| 2026.01.05 | 480 | 24.6 | 1 (01.07) | 206.2 | 226.8 |
| 2026.01.12 | 480 | 60.2 | 3 (01.14 ×2, 01.16) | 285.2 | 369.7 |
| 2026.01.19 | 480 | 43.5 | 0 | 375.6 | 405.4 |
| 2026.01.26 | 480 | 25.6 | 2 (01.29 ×2) | 314.8 | 410.1 |

Trends: agreement oscillates 24–66% with **no monotonic trend**; warnings sporadic (7 total, all spread-related, 12–15 pt); **latency grows monotonically +10×** (avg 38.8 → 375.6 ms; p95 44 → 410 ms).

### 4.2 GBPJPY H1 (proxy, Monday-start weeks)

| Week | Decisions | Agr% | Warnings | Lat avg (ms) | Lat p95 (ms) |
|---|---|---|---|---|---|
| 2025.11.03 | 117 | 13.7 | 10 | 19.2 | 10.7 |
| 2025.11.10 | 120 | 2.5 | 4 | 11.1 | 14.6 |
| 2025.11.17 | 120 | 5.0 | 7 | 13.2 | 16.2 |
| 2025.11.24 | 120 | 5.0 | 5 | 15.5 | 20.0 |
| 2025.12.01 | 120 | 1.7 | 0 | 15.2 | 19.7 |
| 2025.12.08 | 120 | 1.7 | 0 | 16.6 | 19.7 |
| 2025.12.15 | 120 | 0.8 | 0 | 18.7 | 22.2 |
| 2025.12.22 | 96 | 0.0 | 0 | 20.6 | 24.4 |
| 2025.12.29 | 96 | 0.0 | 0 | 22.5 | 26.1 |
| 2026.01.05 | 120 | 0.0 | 0 | 24.2 | 28.5 |
| 2026.01.12 | 120 | 0.0 | 0 | 26.6 | 31.0 |
| 2026.01.19 | 120 | 0.0 | 0 | 29.7 | 33.9 |
| 2026.01.26 | 120 | 0.8 | 0 | 30.5 | 35.7 |

Trends: agreement collapses from 13.7% to ~0–5% from week 2 (A-06); all 26 warnings cluster in the first 4 weeks (21 DistanceValidator + 5 SpreadValidator); latency grows +1.6× (19.2 → 30.5 ms avg) — same direction as EURUSD, milder (H1, fewer bars, cheaper state).

## 5. Statistical health

- **Confidence distribution (EURUSD, 6,046 rows)** — legacyConf: 30–39: 1,231 | 40–49: 3,351 | 50–59: 203 | 60–69: 1,261. Median 40.0 (of 100). **newConf histogram: all 6,046 rows ≤ 0.9** (0.3–0.4: 1,231, 0.4–0.5: 3,351, 0.5–0.6: 203, 0.6–0.7: 1,261).
- **Confidence distribution (GBPJPY, 1,509 rows)** — median legacyConf 61.0; newConf all ≤ 0.9 (0.6–0.7: 1,334, 0.7–0.8: 175).
- **Validator rejection distribution (EURUSD)** — 4,880 rejection blocks: **4,785 ConfluenceValidator** (98.1%) + 95 SpreadValidator (1.9%). `CConfluenceValidator::normalized = totalConfidence/100` vs `minConfidence = 0.6` ⇒ rejects every bar with totalConfidence < 60 — **exactly** matches the observed 4,785 (rows < 60 = 1,231+3,351+203 = 4,785). Behavior is internally consistent with the calibration intent (high-selectivity gate); the observation is the extreme concentration (A-05).
- **Direction agreement**: 100% both runs — confluence direction never contradicts itself across the two comparison sides (trivial under A-01, but confirms no per-run flips).
- **Shadow overhead**: ~28–33 µs per comparison (from `timeUs`), negligible.

## 6. Anomaly register

| ID | Sev | Module | Finding | Evidence | Root cause | Conf. |
|---|---|---|---|---|---|---|
| A-01 | ANOMALY (high) | Shadow / SymbolContext | Shadow "agreement" is plan-existence vs validator status of the **same** confluence score, not legacy-vs-modern; directionMatch trivially 100% | Agreement 38.2% / 2.5% with dir 100% both runs; `SymbolContext.mqh:703` `TODO(v2.9)` (candPrice=bid, barsSince=0, plan-existence check at :676-712) | Comparison construction predates the v2.9 confidence path; intentionally deferred | High |
| A-02 | ANOMALY (high) | Telemetry / Schema | `legacyConfidence` (0–100) and `newConfidence` (0–1) recorded on different scales in the same frozen record; all 7,555 rows have newConf ≤ 0.9 | Histograms §5; `TelemetryRow`/`ShadowComparison` fields; `CalibrationDataset.mqh:60-61` reads both into same-typed doubles | Field semantic mismatch introduced when new confidence path landed; `@frozen v2.9` locks it in place | High |
| A-03 | ANOMALY (medium) | Telemetry | Zero `telemetry_v1_*.csv` produced at runtime — collector never instantiated | `parse_telemetry.py`: no files in any of 4 candidate locations; code: no `CTelemetryCollector` usage sites outside its definition (only unit tests); `CalibrationRunner` store empty | Collector defined but never wired into Engine/PortfolioManager lifecycle | High |
| A-04 | ANOMALY (medium) | Performance | Per-bar Update latency degrades monotonically +10× (EURUSD avg 38.8→375.6 ms, p95 44→410 ms) and +1.6× (GBPJPY) | §4 weekly tables; PERF lines (`Engine.mqh:185`); module breakdown: BOS_DETECTOR avg 112.2 ms/bar (678 s / 6,046 bars), VISUALIZATION_MANAGER avg 32.7 ms/bar — dominant growth contributors; Copy flat ~570 µs | Detector/visualization state accumulation per bar (growth also visible in call counts: BOS ×22, VISUALIZATION 480→2,100) | High |
| A-05 | WARNING (medium) | Entry validators | ConfluenceValidator rejects 98.1% of decisions (4,785/4,880); confidence mass at 40–49 (55%) | Rejection blocks count; §5 histogram; gate `minConfidence=0.6` vs median 0.40 | Calibrated selectivity against a narrow confidence distribution; consistent with 0.55–0.60 winning threshold from calibration | High |
| A-06 | WARNING (low) | Shadow | GBPJPY agreement collapses 13.7% → ~0–5% after week 1 | §4.2; 37/1,509 agreements | Plan-existence frequency differs per symbol (A-01 construction amplifies symbol sensitivity); not engine divergence | Medium |
| A-07 | WARNING (low) | Validators | Price-scale-sensitive thresholds: DistanceValidator (0.005) 21× GBPJPY / 0× EURUSD (clustered 11.03–11.24); SpreadValidator 7× EURUSD (12.18, 01.07, 01.14 ×2, 01.16, 01.29 ×2) + 3× GBPJPY | Warning lines; weekly warn counts §4 | Absolute-threshold config not normalized to symbol ATR/point scale; all "approaching max" (0.00500) | Medium |
| A-08 | INFO | Logging | ~130 lines/bar debug logging (PortfolioManager update DEBUG 6,046 + PERF 6,046 + shadow 6,046 per run); 794k lines / 98.5 MB per M15 run | Line counts, segment sizes | DEBUG-level per-bar prints retained since v2.9 | High |
| A-09 | INFO | Engine | `Engine shutdown complete` printed 5× within 4 ms (09:46:59.006–.010); single deinit event | Log excerpt | Multiple subsystems print the same shutdown line on the same deinit | High |
| A-10 | INFO | Tooling | `EntryMode` defaults LEGACY; presets load only via UTF-16 `.set` in `Profiles\Tester` (auto-saved); ini `ExpertParameters=` silently ignored | Pilots 1–2 ran LEGACY (0 shadow lines, no banner) until Profiles\Tester overwrite (pilot 3: SHADOW banner, 480 rows) | MT5 preset-loading behavior + UTF-16 .set requirement | High |

**No anomalies detected** in: Confluence consistency (direction), ExecutionPlanner, PortfolioManager logic, Calibration file I/O, Memory/Resources (stable 409–434 MB), Tester lifecycle (rc=0, single init), or Benchmarks (61/61).

## 7. Benchmark variance (rerun 10:07:04 vs frozen baseline 08:53:56)

- 61/61 matched; 0 real regressions; headers identical except `Date` (format v2 identical).
- Flags (both sub-100 µs = noise per frozen rule): `Confluence.RegisterEvaluators` 0.42× (30.6 → 12.7 µs), `Entry.SessionValidator` 0.00× (0.1 → 0.0 µs).
- Observed-but-in-bounds variance: `MonteCarlo.100Trades/500Trades` ~0.55–0.70× (rerun faster); `WalkForward.Rolling/Anchored` ~1.3–1.6× (rerun slower).

## 8. Positive findings

- 0 crashes / 0 asserts / 0 errors across 7,558 bars + 3 months + 61 benchmarks.
- Shadow coverage complete (6,046/6,046; 1,509/1,512), overhead negligible (~28–33 µs).
- Direction agreement 100% — confluence scoring internally consistent throughout.
- Latency Copy flat ~570 µs; no unexplained spikes (max first-bar warmup 2.05 s; bounds stable).
- Memory stable 409–434 MB; no leak warnings.
- Shutdown summaries deterministic (MetricsCollector + Shadow block consistent per run).

## 9. Acceptance criteria — evidence

| # | Criterion | Result | Evidence |
|---|---|---|---|
| 1 | No crashes/assertions | ✅ PASS | 0 `[ERROR]`, rc=0 both runs, "Test passed" |
| 2 | No memory/resource anomalies | ⚠ PASS w/ note | Stable 409–434 MB; log volume high (A-08) |
| 3 | No unexpected init/shutdown | ⚠ PASS w/ note | 1 init/run; shutdown ×5 prints (A-09) |
| 4 | No unexplained latency spikes | ⚠ FAIL w/ note | No spikes, but monotonic +10× (A-04) |
| 5 | No telemetry corruption/missing | ❌ FAIL | 0 records (A-03); scale mismatch (A-02) |
| 6 | Shadow comparison stable over run | ❌ FAIL | Structural artifact (A-01); GBPJPY collapse (A-06) |
| 7 | No recurring validator infra failures | ✅ PASS | 33 warnings, 0 exceeded; rejections data-driven |
| 8 | Benchmark variance within bounds | ✅ PASS | 61/61, 0 regressions, 2 noise flags |
| 9 | No CRITICAL findings | ✅ PASS | Max severity = ANOMALY |

## 10. Deviations & config discovery log

- XAUUSD H1 → GBPJPY H1 (unavailable on MetaQuotes-Demo; silent exit). **Proxy-labeled throughout.**
- USDJPY H1 also unavailable (silent exit) — discarded.
- Preset mechanism discovered: MT5 tester loads `MQL5\Profiles\Tester\SuperCents_X.set` (auto-saved last-used inputs), not ini `ExpertParameters=` (silently ignored, EntryMode defaulted to LEGACY). Fix: overwrite Profiles\Tester `.set` with UTF-16 LE content, remove `ExpertParameters=` from ini.
- Pilot evidence: pilots 1–2 (09:22:34, 09:24:58) LEGACY; pilot 3 (09:27:13) SHADOW — banner + 480 rows, summary {480, 121, 25.2%}, 12.1 s wall, 0 ERR/0 WARN.
- Smoke tests: 10:01:02 USDJPY (no-op), 10:01:12 GBPJPY 1-week (141 shadow rows, excluded from counts).

## 11. Conclusion

Stable, auditable platform; **no CRITICAL findings**. The four anomalies (A-01..A-04) all have identified root causes and affect the Sprint 15 input path (telemetry + shadow + long-run performance), not the core trading path. Recommend **Case B — v2.9.2 MAINTENANCE** (scope in Report A §Recommendation) before Sprint 15.

Reported without any code changes, per audit discipline.
