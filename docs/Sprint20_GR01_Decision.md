# Sprint 20 — GR01: Per-Family Admission Floor Decision (Evidence-Calibrated)

- **Status:** DONE (2026-08-07)
- **Plan:** `docs/Sprint20_Engineering_Plan.md` (GR01 row)
- **Evidence:** `Tools/GR01/gr01_funnel.py` + `Tools/GR01/reports/gr01_funnel_report.md` + `gr01_funnel_data.json` (read-only over the frozen Sprint 17 dataset, 19 merged v3 files, 18,536 decided rows)
- **Baseline transition:** B7 → B8 (doctrinal: evidence-calibrated family thresholds)
- **Predecessors:** DD05 (family-aware admission, temporary research-derived floors), M2 (Platform Stable)

## 1. Purpose

GR01 replaces the DD05 temporary per-family floors (`ValidatorConfig.mqh`) with thresholds derived from the frozen Sprint 17 evidence. Every floor below is traceable to measured win rates / expectancies on the frozen dataset — no intuition.

Universe: 18,536 decided rows (WIN/LOSS/BE) across 19 runs (EURUSD M15 ×13, EURUSD H1 ×3, GBPJPY H1 ×3); base win rate 0.3321 (Sprint 17 frozen). `wr = WIN/(WIN+LOSS)`; family counts reproduce the frozen research tables exactly (LIQUIDITY 3,553; FVG 12,320; BOS 858; CHOCH 342; UNKNOWN 1,463).

## 2. Decision table

| Family | Old floor | New floor | Qualified n | Qualified wr | Qualified meanR | Evidence | Reason |
|---|---|---|---|---|---|---|---|
| LIQUIDITY | 0.60 | **0.60** | 3,178 | 0.3027 | -0.100 | 0.60 is the only discriminating threshold (no row >= 0.65); it rejects the 375-row tail at wr 0.2453; E5 falsification reproduced: no config admits a LIQUIDITY subset with wr >= base 0.3321 | KEEP — worst family; gate can only trim the worst tail, never beat base |
| BOS | 0.35 | **0.35** | 858 | 0.3734 | +0.123 | Bootstrap CI 0.340-0.406 (above base); floor 0.45 gain (0.3746 vs 0.3734, meanR +0.0025) is within noise; 0.50 = 0 rows | KEEP — raising discards 268 samples for a noise-level gain |
| CHOCH | 0.35 | **0.35** | 342 | 0.3567 | +0.051 | CI 0.307-0.406; floor 0.50 admits n=76 (wr 0.3816) — sample too small to promote | KEEP — full-family admission; higher floors under-powered |
| FVG | 0.40 | **0.35** | 12,320 | 0.3389 | +0.010 | Floor 0.40 rejects the better tail: <0.40 subset = 3,386 rows at wr 0.3521 / meanR +0.051 vs admitted 0.3339 / -0.006; family CI 0.331-0.347 (above base) | LOWER — 0.40 excludes the best-performing region; 0.35 admits the whole family |
| UNKNOWN (evaluator path) | 0.60 | **0.35** | 1,463 | 0.3144 | -0.058 | Floor 0.60 admits 293 rows at wr 0.2935 / meanR -0.125 but rejects the <0.40 cluster (760 rows at wr 0.3461); full admission is strictly better | LOWER — 0.60 rejects the better half of the evaluator rows |
| ORDER_BLOCK | 0.35 | 0.35 | 0 | - | - | No rule maps to ORDER_BLOCK (RuleTypeToFamily single-valued: OB content lives in BOS_OB → BOS and OB_FVG → FVG) | KEEP — reserved; unreachable by current rule set |

## 3. Validation stages

1. **Backtest / frozen-dataset sweep** — `Tools/GR01/gr01_funnel.py` over the frozen Sprint 17 set: per-family floor sweeps 0.30-0.80 (report section 3). Counts reproduce frozen research exactly (3,553/12,320/858/342, gate 0.3027@3,178, tail 0.2453, FVG 0.35-state 0.3521).
2. **Walk-forward** — per-file (19 runs) win-rate stability by family (report section 5): FVG stable 0.28-0.47 across all runs; LIQUIDITY volatile 0.16-0.43; BOS noisy at n=30-70; CHOCH n-limited (2 runs n>=30).
3. **Monte Carlo** — 10,000-resample bootstrap 95% CI on family wr (report section 4): BOS/CHOCH/FVG CIs entirely above base 0.3321; LIQUIDITY/UNKNOWN at-or-below (consistent with KEEP/LOWER-as-full-admission decisions).
4. **Promotion gate** — TT01 13-gate run with row-rooted localization (-AllowDecisionIds / -ExpectedRows): changed decision ids == allowlist; every changed row traces to an admission flip caused by a floor change; production behavior unchanged in every other column; baseline re-frozen B8 only after localization proves the delta is exactly the floor adjustment.

## 4. Implementation notes

- `Entry/Validators/ValidatorConfig.mqh`: familyFloorFVG 0.40 -> 0.35; new `familyFloorUnknown` 0.35 (UNKNOWN/evaluator path now has a dedicated input; global `minConfidence` 0.60 untouched — it remains the legacy evaluator confidence gate used by `TelemetryRow::ReplayDecision`).
- `Telemetry/TelemetryTypes.mqh` (CalibrationConfig mirror, :509-533): same five floors + the new unknown floor, copied at row-build time.
- `Telemetry/ConfigFingerprint.mqh` (:100-104): canonical string extended with the unknown floor (6 floor values after brokerDigits) — fingerprint changes on all rows by design (policy recording; constancy via CONTRACT gate).
- 3 order-dependence findings and all architecture decisions remain untouched (no detector or engine logic changed).

## 5. Traceability

- AVP ref: L R11/R13 (per-family thresholds; FVG 0/12,320 admission); Doc08 S9 funnel/gate cell; doc 18.9 E1 card (per-family threshold proposal); 19.4 E5 falsification card (LIQUIDITY).
- Frozen sources: Sprint 17 dataset fingerprint `2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90` (19 inputs).
- Decision review: user 2026-08-07 (Option 1 — apply all five).
