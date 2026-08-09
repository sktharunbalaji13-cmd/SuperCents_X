# Sprint 17 Closeout — Schema v3 Evidence Baseline

**Status:** COMPLETE — baseline frozen as tag `v3.0-research-baseline`
**Date:** 2026-08-02
**Companion docs:** `Sprint17_SchemaV3_Design.md` (contract), `SchemaHealthGate.md` (gate spec)

---

## 1. Overview

Sprint 17 collected a six-month simulated evidence dataset in telemetry schema v3 from three
configurations (EURUSD M15, EURUSD H1, GBPJPY H1), validated every artifact through per-run
Schema Health and Structural Diagnostics gates, and froze the result as the
`v3.0-research-baseline` for the calibration pipeline.

## 2. Deliverables

- `Evidence/Sprint17/` — frozen archive: per-run datasets + manifests, merged dataset,
  gate artifacts, reports, journal excerpts, archived config, collection manifest
- `Evidence/Sprint17/README.md` — cover page (tables, fingerprint, env freeze)
- `Evidence/Sprint17/manifest/sprint17_collection_v1.manifest` — machine-readable record
- `Presets/Sprint17_Collection_{EURUSD_M15,EURUSD_H1,GBPJPY_H1}.ini` — harnesses (archived
  copies; working copies in `Profiles/Tester/`)
- `Presets/Sprint17_SchemaHealth_*.ini` / `Presets/Sprint17_Structural_*.ini` +
  `CalibrationRunner_*.set` — gate harnesses (per-run + merged)
- `docs/Sprint17_Closeout.md` — this report

## 3. Collection Runs

| Run | Symbol | TF | Wall clock | Tester time | Files | Rows | Win | Loss | BE | Unknown | Combos |
|-----|--------|----|-----------|-------------|------:|-----:|----:|-----:|---:|--------:|-------:|
| 1 | EURUSD | M15 | 17:08:44–18:00:45 (52.0 min) | 0:51:54.9 | 13 | 12,467 | 4,089 | 8,323 | 5 | 50 | 1,406 |
| 2 | EURUSD | H1 | 18:06:26–18:08:10 (1.7 min) | 0:01:39.0 | 3 | 3,103 | 1,004 | 2,049 | 0 | 50 | 374 |
| 3 | GBPJPY | H1 | 18:10:25–18:12:15 (1.8 min) | 0:01:43.8 | 3 | 3,116 | 1,037 | 2,029 | 0 | 50 | 388 |
| **Total** | - | - | - | - | **19** | **18,686** | 6,130 | 12,401 | 5 | 150 | - |

- Simulated window 2026.01.05–2026.07.05; data ends 2026.07.03 23:xx (final partial flush).
- Per-run evidence gates: exit code 0; `ENTRY_MODE_NEW` banner; collector initialized
  (schema v3); `TELEMETRY SUMMARY` with rows>0 and I/O faults 0; **0 orders placed**;
  **0 errors**; settlement pass complete (50 pending rows per run left unsettled,
  outcome UNKNOWN, by design — the final bars have no forward window to settle).
- 50 rows/run are outcome UNKNOWN and excluded from outcome-correlation analyses.

## 4. Gates & Verdicts

| Gate | Scope | Verdict | Detail |
|------|-------|---------|--------|
| Schema Health (mode 8) | EURUSD M15 | **PASS** 100/100 | 12,467 rows, parsed 100% |
| Schema Health (mode 8) | EURUSD H1 | **PASS** 100/100 | 3,103 rows, parsed 100% |
| Schema Health (mode 8) | GBPJPY H1 | **PASS** 100/100 | 3,116 rows, parsed 100% |
| Schema Health (mode 8) | Merged | **PASS** 100/100 | 18,686 rows, parsed 100% |
| Structural (mode 7) | EURUSD M15 | **PASS** | gaps 0.0000% (A/B/D), correlations present (n=12,417) |
| Structural (mode 7) | EURUSD H1 | **PASS** | gaps 0.0000% (A/B/D), correlations present (n=3,053) |
| Structural (mode 7) | GBPJPY H1 | **PASS** | gaps 0.0000% (A/B/D), correlations present (n=3,066) |
| Structural (mode 7) | Merged (per fp) | **PASS** | gaps 0.0000% across all fingerprints |
| Duplicate scan | all runs | **PASS** | 0 duplicates across 18,686 keys |
| Conservation | merged | **PASS** | 12,467+3,103+3,116 = 18,686 = merged rows |
| Schema shape | all files | **PASS** | 68 columns, fingerprint column consistent per run |

Correlations (spearman confidence→outcome): M15 0.2081, H1 0.2181, GBPJPY 0.2358 —
positive and materially above zero; kendall conf-r near zero negative (−0.02..−0.04),
consistent with the sanity-week baseline.

## 5. Dataset Fingerprint & Immutability

```
SHA256(sorted "<runDir>/<filename>|<fileSHA256>" over 19 canonical CSVs)
= 2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90
```

`Evidence/Sprint17/` is immutable. Any re-run, correction, or extension creates a new
collection dir (Sprint18/…) with its own manifest. The fingerprint detects drift.

## 6. Environment Freeze

- OS: Windows 11 Home SL Build 26200; CPU AMD Ryzen 7 7840HS (8 cores)
- MetaTrader 5.0.0.6090, tester agent build 6090, MetaQuotes-Demo login 5051328028
- Tick Model 4; deposit 10,000 GBP; leverage 200
- EA SuperCents_X v3.0 (schema v3, 68 cols), `EntryMode=2` (ENTRY_MODE_NEW)
- Config fingerprints: M15 `1D1EF3C650D79C3F`, H1 `F01601D3E83F76CA`,
  GBPJPY `7AA9A3846F05ED6C` (decimal values in CSV column `configFingerprint`)
- Harnesses: `Sprint17_Collection_*.ini` (window 2026.01.05–2026.07.05, `ShutdownTerminal=0`)

## 7. Reproducibility

1. Compile with the 17.7A execution-gating fix (§9) — required for order-free collection.
2. Run the three `Sprint17_Collection_*.ini` harnesses in the Strategy Tester (Model=4).
3. Collect `Common\Files\Telemetry\telemetry_v3_*.csv` per run into per-run dirs.
4. Verify with per-run `Sprint17_SchemaHealth_*.ini` (mode 8) and `Sprint17_Structural_*.ini`
   (mode 7) harnesses; rebuild the merged dir; re-run merged gates.
5. Recompute stats + fingerprint (`Temp/sprint17_collect_stats.py`, archived in
   `Evidence/Sprint17/reports/`), archive, and re-tag.

## 8. Deviations & Known Limitations

- **Simulated window shorter than nominal:** tick data ends ~2026.06.26 for M15 (last bars
  2026.07.03); the 2026.07.04–07.05 range is not covered.
- **150 unresolved rows** (50/run) — final-window rows with outcome UNKNOWN by design.
- **Entry-mode gating fix required:** Run 1 of the collection (2026-08-02 15:03) placed
  7,224 orders via the legacy TradeManager path before the fix (§9); that run's CSVs were
  quarantined to `Telemetry/DiscardedRun1_Orders/` and are excluded from the baseline.
- **Daily flush cadence is row-count driven** (1,024 rows/file), so file dates differ per
  run/timeframe; merged copies are run-prefixed to avoid name collisions
  (`telemetry_v3_20260703.csv` exists in all three runs).
- **Terminal window interplay:** collection harnesses set `ShutdownTerminal=0`; an idle
  terminal keeps the data dir open, and a second launch joins it instead of starting a new
  test — close the idle terminal before launching the next run.
- **Journal volume:** the tester journal for the collection day reached ~7.6 GB (per-tick
  logging); evidence excerpts are archived in `Evidence/Sprint17/logs/`.
- **Schema health gate fingerprint filter must be hexadecimal** (parse is hex-based;
  decimal values bail with "fingerprint not in store").

## 9. Lessons Learned

1. **Shadow-gating is not the same as execution-gating.** ENTRY_MODE_NEW suppressed the new
   orchestrator only; the legacy planner→TradeManager→OrderSend path executed unfiltered
   (7,224 orders in Run 1). Fix 17.7A adds `CTradeManager::SetExecutionEnabled()` with a
   hard early-return in `Update()` — verified 0 orders over the full 52-minute M15 run.
2. **`ShutdownTerminal=1` loses the tail flush.** Run 1's terminal closed before `OnDeinit`,
   discarding ~10 days of rows. `ShutdownTerminal=0` + the deinit flush captured the final
   partial day (`telemetry_v3_20260703.csv`).
3. **v2/v3 fingerprint mismatch:** v2-era artifacts reference `1D1EF3C650D79C3F` in hex;
   v3 CSVs carry the same ulong in decimal. Always normalize before comparison.
4. **Rule-0 zero-layer rows are legitimate** (no structural layer at decision time); the
   health gate exempts them from missing-layer scoring (score 100/100 requires this).
5. **Quoted CSV evidence IDs break naive parsing.** Any split-on-comma analysis must merge
   quoted fields; the gate's round-trip and the Python `csv` module handle it.
6. **The health gate pays for itself:** it caught nothing this time, but its cost is
   seconds; the 17.7A fix was only trusted after the smoke gate proved 0 orders.
7. **Structural diagnostics depend on capture quality** (unsettled rows excluded from
   correlations) — do not run them before the deinit flush.
8. **Calibration cannot compensate for bad evidence:** gating (not fitting) is the
   corrective instrument; the baseline is order-free by construction.

## 10. Next Steps

- Promote the frozen baseline through the calibration pipeline (mode 1–6 experiments) using
  the v3 fingerprints.
- Consider a Sprint 18 collection to extend coverage past 2026.07.03 and/or add instruments.
- Monitor dataset fingerprint before any downstream experiment; re-freeze on drift.
