# Sprint 15.3/15.4 — Calibration Results (v3.0 production providers gate)

Date: 2026-08-01 · EA v3.00 · MQL5 Build 6090 · Machine: AMD Ryzen 7 7840HS

Status: **telemetry pipeline fixed and verified end-to-end; promotion gate
produces real verdicts on settled outcomes — candidate v3.0 NOT PROMOTED.**

## 1. Blockers cleared

| # | Blocker | Root cause | Fix |
|---|---------|-----------|-----|
| 1 | Settlement never wired | Queue existed; `SettleDue`/`SettleRow`/`SettleRemaining` not called from the EA flow | Wired into `CSymbolContext` decision tick + `OnDeinit` |
| 2 | `ParseUnsigned` overflow | Direct `StringToInteger` on 17-digit fingerprints | Chunked public static parser (`CalibrationDataset.mqh`) |

## 2. Simulated-settlement bug (root-caused & fixed)

MQL5 time-range `Copy*` overloads return the window in **ascending
chronological order** (oldest first); the outcome simulator and policies
expect **as-series (index 0 = newest)**. Until fixed, "settled" outcomes were
computed from bars *before* the entry (win rate 19% corrupt vs 38% verified).

Fix (`CSymbolContext::SettleRow`): `ArrayReverse()` on open/high/low/close/
times after the time-range copy; entry bar located by exact timestamp; guards
`entryBarIndex >= 50` and `entryBarIndex + 20 < n`; window
`[entry − 3d − 20 bars, entry + (51 + 2d of bars + 50 bars)]`.

## 3. Dataset regeneration (NEW mode, EntryMode=2)

| Run | Dataset | Rows | Settled | Rate | WIN | LOSS | BE | UNK |
|-----|---------|------|---------|------|-----|------|----|-----|
| r19 | EURUSD M15 2026-01-05→06-30 | 12,180 | 12,130 | 99.59% | 4,002 | 8,123 | 5 | 50 |
| r20 | EURUSD H1 2026-01-05→06-30 | 3,042 | 2,992 | 98.36% | 985 | 2,007 | 0 | 50 |
| r21 | GBPJPY H1 2026-01-05→06-30 | 3,045 | 2,995 | 98.36% | 1,002 | 1,993 | 0 | 50 |

UNKNOWN = exactly 50 per symbol/timeframe (expected run-tail horizon rows).
Probe verification (r18, Jan 5–30 M15): 1,773/1,823 settled (97.3%); TP rows
rMultiple exactly 2.00000000, SL exactly −1.00000000, horizon rows
barsHeld=51 → BREAKEVEN. Corrupt pre-fix runs (r13–r15, r16–r17) archived —
never used.

## 4. Threshold sweep (calibrated threshold, EURUSD M15, fp 1D1EF3C650D79C3F)

| Threshold | Expectancy | PF | Win rate | Trades | p vs 0.60 | Significant |
|-----------|-----------|-----|----------|--------|-----------|-------------|
| 0.40 | −0.0369 | 0.9453 | 0.3235 | 8,602 | 0.1613 | no |
| 0.45 | −0.1013 | 0.8542 | 0.3029 | 2,324 | 0.8380 | no |
| 0.50 | −0.1170 | 0.8327 | 0.2986 | 1,765 | 0.6046 | no |
| 0.55 | −0.1230 | 0.8246 | 0.2967 | 1,712 | 0.5243 | no |
| **0.60 (baseline)** | −0.0919 | 0.8669 | 0.3080 | 1,419 | 1.0000 | — |
| 0.65–0.80 | — | — | — | 0 | — | no (no rows ≥ 0.65) |

No threshold is significantly better than the 0.60 baseline (all p ≥ 0.16).
Best expectancy at 0.40 (looser threshold, 8,602 trades).

## 5. Promotion gate verdicts

### EURUSD M15 @ calibrated 0.40 (r24) — NOT PROMOTED (INCONCLUSIVE)

| Criterion | Candidate | Baseline | Verdict |
|-----------|-----------|----------|---------|
| Sample: shadow comparisons | 13,140 | 10,000 | PASS |
| Sample: qualified signals | 9,378 | 500 | PASS |
| Sample: settled trades | 8,602 | 300 | PASS |
| Expectancy improvement | −0.0369 | −0.0919 | INCONCLUSIVE (p = 0.16) |
| Profit factor | 0.9453 | 0.8669 | PASS |
| Win rate | 0.3235 | 0.3080 | PASS |
| Max drawdown (R) | 567.6 | 207.7 | FAIL |
| Recovery factor | −0.5587 | −0.6278 | PASS |

The 0.40 candidate lifts expectancy/PF/win rate over the 0.60 baseline but
not significantly, and only by taking far more trades (8,602 vs 1,419) with a
much deeper drawdown. Decision: **do not promote; stay on the 0.60 baseline**.

### EURUSD M15 @ 0.60 (r22) — NOT PROMOTED (ties by construction)

Candidate == baseline on every statistical criterion (identical threshold) →
expectancy/PF/recovery FAIL, win rate/drawdown PASS. Included to document why
the sweep step is mandatory.

### EURUSD H1 (fp F01601D3E83F76CA) & GBPJPY H1 (fp 7AA9A3846F05ED6C) — INCONCLUSIVE

| fp | Rows | Signals | Settled trades | Blocking criterion |
|----|------|---------|----------------|--------------------|
| EURUSD H1 | 3,042 | 410 | 402 | signals < 500, shadow < 10,000 |
| GBPJPY H1 | 3,045 | 21 | 16 | signals < 500, shadow < 10,000 |

The 6-month H1 windows do not provide enough qualified signals for a gate
decision; extend the collection window before re-gating.

### Legacy fp (C05E7E08118D5953, 2,400 rows) — INCONCLUSIVE

0 settled trades (v2.9-era rows predate the settlement schema).

## 6. Evidence

- Run logs: `Temp/opencode/sprint15/r19…r24 .log.txt`
- Settled telemetry (canonical, kept in store): `Common/Files/Telemetry/telemetry_v2_2026*.csv` (14 files, 18,267 rows + legacy 20251107)
- Copy of the definitive datasets: `Temp/opencode/sprint15/telemetry_r19_r21_final/`
- Reports: `Common/Files/Calibration/calib_threshold_1D1EF3C650D79C3F_20260105_000000.csv`, `calib_promotion_1D1EF3C650D79C3F_20260105_000000.csv` (+ H1/legacy promotion CSVs)
- Tainted artifacts (do not use): `Temp/opencode/sprint15/telemetry_r13_r15/`, `telemetry_tainted_ascending_bug/`

## 7. Follow-ups

- Re-gate H1 symbols after a longer (≥ 12-month) collection window.
- Re-run the threshold sweep on the next settled dataset before any promotion run.
- Promotion of LIVE execution (Sprint 16) requires a PASSED gate — not reached in this sprint.
