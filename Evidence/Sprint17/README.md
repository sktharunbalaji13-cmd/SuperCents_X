# Sprint 17 — Schema v3 Six-Month Evidence Baseline (Research)

**Status: FROZEN — IMMUTABLE.** This archive is the v3 research baseline. Files under this
directory must never be edited, appended, or deleted. Future collections go to `Sprint19/`,
`Sprint20/`, ... and get their own manifests. The dataset fingerprint (below) detects any
drift.

## Objective

Collect a six-month (2026.01.05 - 2026.07.05, simulated) evidence dataset in schema v3 from
three instrument/timeframe configurations, run the per-run and merged Schema Health and
Structural Diagnostics gates, and freeze the result as `v3.0-research-baseline` for the
calibration pipeline.

## Collection Summary

| Run | Symbol | TF | Files | Rows | Decided | Win | Loss | BE | Unknown | Evidence combos | Range (simulated) |
|-----|--------|----|------:|------:|--------:|----:|-----:|---:|--------:|----------------:|-------------------|
| Run 1 | EURUSD | M15 | 13 | 12,467 | 12,417 (99.60%) | 4,089 | 8,323 | 5 | 50 | 1,406 | 2026.01.05 00:15 - 2026.07.03 23:45 |
| Run 2 | EURUSD | H1 | 3 | 3,103 | 3,053 (98.39%) | 1,004 | 2,049 | 0 | 50 | 374 | 2026.01.05 15:00 - 2026.07.03 23:00 |
| Run 3 | GBPJPY | H1 | 3 | 3,116 | 3,066 (98.40%) | 1,037 | 2,029 | 0 | 50 | 388 | 2026.01.05 01:00 - 2026.07.03 23:00 |
| **Merged** | - | - | **19** | **18,686** | - | - | - | - | - | - | - |

- Row-count conservation: 12,467 + 3,103 + 3,116 = 18,686 = merged rows. **Pass.**
- Cross-run duplicate scan on `(configFingerprint, symbol, timeframe, signalTime, firedRuleId)`:
  **0 duplicates** (18,686 unique keys). **Pass.**
- Every run: exit code 0, `ENTRY_MODE_NEW` banner, collector initialized, `TELEMETRY SUMMARY`
  present, **0 orders placed**, **0 errors**, I/O faults 0, settlement pass complete.

## Gate Verdicts

| Gate | Scope | Verdict | Score | Rows |
|------|-------|---------|------:|-----:|
| Schema Health (mode 8) | EURUSD M15 | PASS | 100/100 | 12,467 |
| Schema Health (mode 8) | EURUSD H1 | PASS | 100/100 | 3,103 |
| Schema Health (mode 8) | GBPJPY H1 | PASS | 100/100 | 3,116 |
| Schema Health (mode 8) | Merged | PASS | 100/100 | 18,686 |
| Structural (mode 7) | EURUSD M15 | PASS (gaps 0) | - | 12,417 |
| Structural (mode 7) | EURUSD H1 | PASS (gaps 0) | - | 3,053 |
| Structural (mode 7) | GBPJPY H1 | PASS (gaps 0) | - | 3,066 |
| Structural (mode 7) | Merged (per fp) | PASS (gaps 0) | - | per fp |

Structural diagnostics: sections A (data gaps), B (label leakage), D (distribution) all
`data_gap = 0.0000%`; section C correlations present (spearman confidence-outcome:
M15 0.2081, H1 0.2181, GBPJPY 0.2358). 50 unresolved rows per run (final window pending
outcome UNKNOWN) are excluded from correlation analysis by design.

## Dataset Fingerprint

```
SHA256(sorted "<runDir>/<filename>|<fileSHA256>" lines over the 19 canonical files)
= 2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90
```

## Environment Freeze

- Host: Windows 11 Home SL, Build 26200; AMD Ryzen 7 7840HS (8 cores)
- Platform: MetaTrader 5.0.0.6090 (tester agent build 6090), MetaQuotes-Demo, login 5051328028
- Tester: Tick Model 4 (every tick), deposit 10,000 GBP, leverage 200
- EA: SuperCents_X v3.0, schema v3 (68 columns), `EntryMode=2` (ENTRY_MODE_NEW, execution gated off)
- Config fingerprints (decimal / hex): EURUSD M15 `2098382509486611519 / 1D1EF3C650D79C3F`;
  EURUSD H1 `17300017028236539594 / F01601D3E83F76CA`; GBPJPY H1 `8838775532884979052 / 7AA9A3846F05ED6C`
- Harness inis: `Presets/Sprint17_Collection_{EURUSD_M15,EURUSD_H1,GBPJPY_H1}.ini` (archived
  copies; working copies in `Profiles\Tester\`, window 2026.01.05-2026.07.05,
  `ShutdownTerminal=0`); archived `SuperCents_X.set` in `manifest/`

## Layout

```
README.md                  this cover page
EURUSD_M15/  dataset (13 CSVs) + run.manifest.json + gates/
EURUSD_H1/   dataset (3 CSVs)  + run.manifest.json + gates/
GBPJPY_H1/   dataset (3 CSVs)  + run.manifest.json + gates/
merged/      merged dataset (19 CSVs, prefixed by run) + gates/
manifest/    sprint17_collection_v1.manifest + archived SuperCents_X.set
reports/     sprint17_stats.json
logs/        journal excerpts per run + gates
```

## Reproducibility

1. Compile SuperCents_X with the 17.7A execution-gating fix (see `docs/Sprint17_Closeout.md`).
2. Run the three collection inis (Strategy Tester, Model=4, `ShutdownTerminal=0`).
3. Copy CSVs to `Common\Files\Telemetry\{run}\`, verify gates, compute fingerprint.
4. See `docs\Sprint17_SchemaV3_Design.md` §6 for the full protocol.
