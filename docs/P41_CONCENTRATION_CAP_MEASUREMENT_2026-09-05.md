# P41 — CONTROLLED NON-HOLDOUT CONCENTRATION-CAP MEASUREMENT

Date: 2026-09-05
Mode: Evidence-capture only. No optimization, recalibration, profitability research, or deployment validation.
Authority: P40 (`docs/P40_REMAINING_PROFITABILITY_MECHANICS_DESIGN_REVIEW_2026-09-05.md` §3: measurement required before any cap discussion).
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`. Tracked tree: 37 modified files (26 pre-existing P31/B9 + 11 P37/P39), plus P41 instrumentation hunk below. No reset/stash/commit.

## Disposition

### `P41 COMPLETE — CONCENTRATION CAP MEASURED, NO POLICY CHANGE AUTHORIZED`

Interpretation class **A — MECHANICALLY CORRECT / NO POLICY ISSUE**, with a recorded B-caveat for future multi-position configs (see §5).

## 1. Pre-run state (verified read-only)

- P37 markers present (10 files), P39 `SetSymbol` present, B9 manifest/CSV in pre-existing P35 state (untouched by P41), PromotionGate unmodified, `SuperCents_X.mq5` inputs unmodified.
- Holdout untouched: run window 2026.01.01→04.01 (H1 research-used data, Sprint17-era/TT01-profile); no 2026-H2 data referenced.
- Strategy parameters unchanged: run ini carries NO `[TesterInputs]` overrides except `EntryMode=0` (see §2).
- Binary provenance: `SuperCents_X.ex5` 550,624 bytes, built 2026.09.05 11:35:19 (after instrumentation edit 11:34:53); EA compile 0/0 (`compile_p41_ea.log`); runner compile 0/0; unit suite on instrumented build 3344/3344, 0 FAIL (`Tests/p41_artifacts/p41_unittests_hits.log`, build tag 11:35:24) — logging-only change proven behavior-neutral.

## 2. Instrumentation (sole production change; logging-only)

`Portfolio/PortfolioRiskManager.mqh` §4: one `CONC-MEASURE` LogInfo per candidate reaching the gate — `time symbol dir concDecision equity openExp addedExp combined concPct capPct positions stopDist`. Decision logic untouched; cap untouched (30.00 constant in all 325,433 lines). Justification: telemetry schemas v3–v6 carry no gate-rejection fields (P40); no persisted logs contained them — capture was impossible without this line.

## 3. Run configuration (both runs; identical except mode)

Profile: B9-TT01-like — EURUSD H1, 2026.01.01→04.01, Model=1, $10k... GBP 10000, lev 200, terminal build 6140.
- **Run 1** (wall 12:01:24–12:01:43, 14.5s): no `[TesterInputs]`; tester input cache silently applied EntryMode=2 (NEW, execution-reserved) — disclosed, not intended. Result: gate exercised with zero open positions (mode suppresses order flow). Retained as the no-concurrency baseline.
- **Run 2** (wall 12:05:15–12:05:33, 7.2s): `[TesterInputs] EntryMode=0` — restores the `.mq5` documented default (`ENTRY_MODE_LEGACY=0`; NEW=2 per `Entry/EntryConfig.mqh:24-26`). NOT a parameter change (0 == code default); neutralizes cache pollution. Live orders sent (deals #2–#5: 0.28/0.28/0.17/0.17 lots), positions opened/closed — gate observed in both exposure states.

## 4. Measurement results

### Funnel (both runs identical plan generation — deterministic signal path)
- 1827 plans: 384 EXECUTABLE / 1443 planner-REJECTED (RR/spread/min-stop/C6 gates; unrelated to §4).

### Run 1 — no-concurrency baseline (324,842 evaluations, all PASS, 0 REJECT)
- concPct (added-only, openExp ≡ 0): min 0.70 / max 28.57 / mean 8.17. Buckets: <10%: 225,651; 10–20%: 22,710; 20–30%: 76,481; ≥30%: 0.
- Arithmetic audit: combined/equity×100 vs concPct — 0 mismatches in 324,842.
- Unique (time,dir,stopDist): 5,754. Span 2026.01.02→03.31.

### Run 2 — live positions (591 evaluations: 323 PASS / 268 REJECT = 45.3%)
- PASS (positions=0): concPct 0.70–28.56, mean 2.52; 78 unique tuples; dirs 1:254 / 2:69.
- REJECT (positions=1): concPct 192.57–232.67, mean 208.35; 99 unique tuples; span 2026.01.29→03.31 across 30 distinct days; `PORTFOLIO-RISK-REJECTED [Symbol concentration $20k–23k exceeds max ~$3k]` ×268, matching CONC lines 1:1.
- **Boundary clean**: max PASS 28.56% < 30% < min REJECT 192.57%. No borderline flapping.
- Mechanism check: openExp $20.3k max (0.17–0.28 lots × ~1.04–1.16 × 100000 ✓ true notional); addedExp ≤ $2,857 (per-1-lot risk proxy).

### Distributions
- Run-2 REJECTs cluster in position-open windows (by construction — exposure persists while SL/TP working); 30 affected days Jan-29→Mar-31; symbol EURUSD only (single-symbol run); both directions on PASS side.

## 5. Interpretation — class A (with B-caveat)

1. **Gate math is correct live**: 0 arithmetic mismatches; boundary clean; cap constant; notional magnitudes reconcile to lots×price×contractSize.
2. **Rejections are the documented policy operating as written**: open 0.17–0.28-lot positions ≈ 200% of ~$10k equity vs a 30%-of-equity cap. Blocking is not a defect signal — it is the cap meaning "no single-symbol exposure above 30% of equity" applied to true notional. Pre-P37 fiction ($1-scale sums) could never bind; corrected math binds exactly when it should. → Not C (no inconsistency demonstrated).
3. **Frequency impact is real in count terms but marginal in effect under current config**: 45.3% of evaluations rejected, yet EVERY rejected candidate sat behind an open same-symbol position that `TradeManager` C3 (1 pos/symbol) independently blocks — marginal §4 frequency loss ≈ 0 today. No §4-only reject observed in 325,433 evaluations (max added-only 28.57% < 30%).
4. **B-caveat (recorded, not action)**: if `m_maxPositionsPerSymbol` were ever raised above 1, §4 would become the binding constraint and frequency impact would need fresh measurement. Likewise the addedExposure per-1-lot proxy overstates small-candidate risk (conservative bias, favors fewer rejects).
5. **Limitation/observation (no action)**: account currency is GBP while notional computes in USD terms — raw-number comparison, pre-existing semantics; consistent-unit conversion would only widen the observed breaches. Multi-symbol concurrency unmeasured (single-symbol EA run) — out of scope for this gate's per-symbol contract.

## 6. Validation checklist (all confirmed)

P31 unchanged · C4 unchanged · P37 mechanics unchanged (suite green post-instrumentation) · P39 present · B9 unchanged · PromotionGate unchanged · holdout untouched · strategy parameters unchanged (EntryMode=0 == default) · cap NOT changed (30.00 in every line).

## 7. Artifacts (raw preserved)

- `Tests/p41_artifacts/p41_conc_raw.log` — 651,511 lines (run-1 funnel: conc + plans + gate decisions).
- `Tests/p41_artifacts/p41_conc_run2_raw.log` — 3,011 lines (run-2 conc + plans + gate decisions + ORDER-SENT).
- `Tests/p41_artifacts/p41_unittests_hits.log` — suite proof. `compile_p41_ea.log`, `compile_p41_tests.log` — 0/0 proofs.
- Run ini: `%TEMP%\p41_probe\p41_conc.ini` (§3; EntryMode rationale inline). Provenance: ex5 550,624 B 11:35:19, build tag `2026.09.05 11:35:02`, term 6140, Model=1, window 2026.01.01→04.01.

Cap NOT changed. No optimization, research, deployment, or recertification follows. STOP after P41.
