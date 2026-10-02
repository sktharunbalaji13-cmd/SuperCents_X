# P44 — CONTROLLED DECISION EVIDENCE PHASE

Date: 2026-09-05
Mode: Evidence-capture only. Logging-only instrumentation; no rejection, activation, threshold/value selection, optimization, or deployment actions.
Authority: senior-advisor P44 direction on P43 packages (observe-only net-RR; BE shadow protocol; firewall restated below).
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`. No reset/stash/commit.

## Disposition

### `P44 EVIDENCE COMPLETE — THRESHOLD/BUFFER DECISIONS STILL HUMAN-OPEN, NO POLICY CHANGE`

## Firewall (honored)

No net-RR rejection (gate still gross `< 1.0`) · no BE activation (enablers grep-verified zero) · no threshold/value selection (counts below are descriptive distributions, not choices) · no profitability optimization or claims.

## 1. Instrumentation (logging-only; decision logic untouched)

- `Entry/ExecutionPlanner.mqh::BuildPlan`: spread-only netRR per P43 §1 (`(target−spread)/(stop+spread)`, guarded; `hasNetRiskReward=true`); gate unchanged; `EXECUTION-PLAN` lines extended with `NetRR=%.2f` AFTER `RR=` (existing `RR=` harvest regexes still hit gross first — verified in analysis).
- `Entry/PositionLifecycleTypes.mqh` + `PositionLifecycleManager.mqh`: `beShadowLogged` latch (decl/ctor/`AddContext`) + first-touch `BE-SHADOW` log in OPEN/PARTIAL states gated on `!m_beEnabled` (BE disabled → branch is the ONLY new code that can execute; no SL modified, no state besides the latch).
- Validation: EA 0/0 (`compile_p44_ea.log`), runner 0/0 (`compile_p44_tests.log`), unit suite on instrumented build 3344/3344 0 FAIL (tag 12:15:20, `Tests/p44_artifacts/p44_unittests_hits.log`). One editing error self-caught (eaten brace + dropped `break` in OPEN branch — restored, verified, compiled clean).

## 2. Runs (EURUSD H1 2026.01.01→04.01, Model=1, £10k/lev200/build6140, non-holdout)

- **Run A — NEW observe** (wall 12:21, tester-cache NEW mode, no orders): 1827 plans / 384 executable (deterministic set, identical IDs to P41).
- **Run B — LEGACY shadow** (wall 12:22, `EntryMode=0` = code default): same 384 executable IDs (384/384 overlap — signal path proven unaffected by instrumentation); live fills; BE never enabled.

## 3. Net-RR observe evidence (Run A, 384 executable)

- netRR range 0.74–14.39 vs gross 1.00–14.50; median identical 2.00 (spread negligible on wide plans).
- Would-reject counts (DESCRIPTIVE, not selection): net<0.8: 1 · net<1.0: **3/384 (0.8%)** · net<1.2: 38 (9.9%) · net<1.5: 71 (18.5%).
- Comparison to P43 worst-case bounds (35 @1.0 / 71 @1.5): actual spreads kinder than bound; @1.5 bound exact (71), @1.0 actual (3) far below bound (35).
- Precision caveat: `NetRR=%.2f` logging limits borderline classification; 128 plans round-equal to gross (wide-stop/spread≈0 ticks). A future audit may use %.4f under separate authorization.

## 4. BE shadow evidence (Run B)

- **1 first-touch event** all quarter: `Ticket=2 FirstTouch R=1.60 Entry=1.15714 SL=1.16191 TP=1.13919 Volume=0.28` (SELL, 477pt stop, 2026.03.23). Position exited normally thereafter (deal #3) — exits unchanged.
- Only 2 deals all quarter (1 position). Trigger-reach sample (n=1) is INSUFFICIENT for any buffer/trigger choice — BE decision basis still thin; P43 §8 measurement prerequisite stands (longer window and/or R-trajectory logging under future authorization).

## 5. Execution-divergence analysis (honest anomaly, does not touch P44 evidence)

Identical executable sets (384/384 IDs) but different fills vs P41-run2 (Jan fills there; first fill here Plan=1618 in March). Root causes found in log, both pre-existing live-path behaviors, neither signal/gate-related:
1. **Volume-step float dust**: `ORDER-FAILED ... Volume 0.30 not aligned to step 0.01` — `MathRound(lots/step)*step` dust vs `MathMod(...) > 1e-10` with no normalization (`TradeValidation.mqh:91-96`). Value-dependent lottery (0.28 passes, 0.30 fails). Rounding predates P37 (same exposure); tick-lottery-visible, not P37-introduced. RECORDED as a new integrity-review candidate — explicitly NOT fixed in P44 (NormalizeDouble policy needs authorization).
2. **Inspection blocks**: `ORDER-BLOCKED-INSPECTION verdict=MATCHED` (B25-03C duplicate defense) on first attempts — pre-existing, out of scope.
Net-RR plans deterministic across all runs; BE-shadow passive. Neither finding invalidates §§3–4.

## 6. Updated decision basis (for the human)

- Net-RR threshold choice now has measured would-reject counts (3/38/71 of 384) replacing bounds — selection remains human-open with P43 package requirements (basis, validation, rollback) still applying.
- BE buffer/trigger/enabling still lack outcome evidence (n=1 touch, zero BE exits anywhere) — shadow-evidence requirement stands.
- New candidate for a future integrity phase: volume-step dust normalization (observation only).

## 7. Artifacts

`Tests/p44_artifacts/p44_unittests_hits.log` (suite) · run-A/B lines in agent day-log 20260905 (wall 12:21/12:22) · `Tests/p41_artifacts/` preserved · `compile_p44_*.log` (0/0) · inis `%TEMP%\p44_probe\p44_observe.ini`, `%TEMP%\p41_probe\p41_conc.ini` (EntryMode=0 rationale inline) · scripts `Temp/p44_unittests.ps1`, `Temp/p41_launch.ps1`.
Validation checklist: P31/C4/P37/P39 intact · B9/PromotionGate/holdout/params untouched · BE/TS enablers zero · cap unchanged · gross gate unchanged. STOP after P44.
