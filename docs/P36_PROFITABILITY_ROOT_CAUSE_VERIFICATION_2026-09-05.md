# P36 — PROFITABILITY ROOT-CAUSE VERIFICATION & FIX-ORDER AUTHORIZATION

Date: 2026-09-05
Mode: READ-ONLY forensic engineering review. No source-code modification. No parameter modification. No PromotionGate modification. No baseline modification. No re-freeze. No TT01 execution. No commit/stage/merge/rebase/revert/reset/clean. No holdout/research access. No optimization.
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main` (verified `git rev-parse HEAD`, `git branch --show-current`).
Authorization voice: "I authorize P36 as a READ-ONLY forensic engineering review."

## 0. Executive conclusion

### `P36 IMPLEMENTATION SPLIT — SPECIFIC ITEMS AUTHORIZED`

Profitability diagnosis is **substantially verified**: all 35 assigned numbers found verbatim (Section 1, zero UNVERIFIED). EA is correctly diagnosed as negative-expectancy on settled evidence, but the proposed "first batch 1+2+6" mixes **mechanical integrity corrections** (authorized, scoped) with **strategy-design hypotheses** (not authorized as profit fixes).

Authorized as integrity/risk corrections (exact scope in Sections 2–4, 8):

1. **Fix 6 live-path integrity items** — `Risk/PositionSizer.mqh` floor-clamp policy decision, `Portfolio/CapitalAllocator.mqh` + `Portfolio/AllocationEngine.mqh` tickSize divisor, `Portfolio/PortfolioRiskManager.mqh` hardcoded `100000.0` contract-size lookup, `Entry/StopLossResolver.mqh` + `Entry/ExecutionPlanner.mqh` digits-aware pip math, `Trading/TradeManager.mqh` clamp-then-round ordering, stale tick cache refresh. Confined to LIVE paths (`TradeManager` C2/C3 + portfolio gate). Edits inside dead `Risk/RiskManager.mqh` gates and `Risk/ExposureTracker.mqh` risk leg are **not authorized** (change nothing live; see 4.10).
2. **Fix 1 gross-RR hole documented as CODE FACT; gate-only net-RR as separate metric authorized for design, threshold value NOT authorized** — RR is confirmed gross, `RR==1.0` passes, no cost deduction exists, `TradeValidation` has no RR re-check. Adding a separate cost-aware admission metric alongside gross `riskReward` is sound engineering. The specific value `minRR=1.5` and formula `(target-costs)/(stop+costs)` are **DESIGN HYPOTHESIS**, absent from code, with no measured cost ledger. Not authorized as a profitability parameter.
3. **Fix 2 BE mechanics confirmed, but BE/TS are dead code at runtime — enabling them or adding partials is strategy change, not integrity fix** — `newSL=priceOpen` with no buffer (scratch loses spread) CONFIRMED; TS fixed `100*_Point` CONFIRMED; partial passive-only with zero `PositionClosePartial` calls CONFIRMED. But `SymbolContext.mqh:639-651` never enables BE/TS, repo-wide zero enabler callsites. `50%-at-1.5R`, `BE@1.5R+buffer`, ATR trail have **no verbatim repo occurrence** (nearest: untested `Sprint16_ResearchPlan.md:183` C5 "50% at 1R" proposal). Authorized: buffer-if-ever-enabled correction + lifecycle misrouting note (`SetSymbol` gap). Not authorized: enabling BE/TS or introducing partials as a profit fix without controlled validation.

A technically correct EA is not automatically profitable. Chain preserved: ENGINEERING CORRECTNESS → CONTROLLED VALIDATION → OUT-OF-SAMPLE PROFITABILITY → ROBUSTNESS → CERTIFICATION → PAPER/SHADOW → LIMITED LIVE. Sections 6–8 enforce it.

## 1. Profitability evidence verification (all VERIFIED, zero UNVERIFIED)

Source docs: `docs/Sprint15_3_CalibrationResults.md`, `docs/Sprint16_1_Measurement.md`, `docs/Sprint16_1B_StructuralDiagnostics.md`, `docs/Sprint16_2_CalibrationModels.md`, `docs/Sprint17_Closeout.md`, `Validation/Sprint17/reports/sprint17_stats.json`, `Calibration/PromotionGate.mqh`, `CHANGELOG.md`.

| Metric | Claimed | Status + verbatim source |
|---|---|---|
| M15 settled | 12,130 / 12,180 (99.59%), W4002/L8123/BE5/UNK50 | VERIFIED — Sprint15_3 §3: `\| r19 \| EURUSD M15 2026-01-05→06-30 \| 12,180 \| 12,130 \| 99.59% \| 4,002 \| 8,123 \| 5 \| 50 \|`; `UNKNOWN = exactly 50 per symbol/timeframe (expected run-tail horizon rows).`; CHANGELOG: `EURUSD M15 12,130/12,180 settled (99.6%)` |
| 0.40 operating point | exp −0.0369, PF 0.9453, win 0.3235 (32.35%), 8,602 trades, p 0.1613 | VERIFIED — Sprint15_3 §4: `\| 0.40 \| −0.0369 \| 0.9453 \| 0.3235 \| 8,602 \| 0.1613 \| no \|`; §5: `\| Win rate \| 0.3235 \| 0.3080 \| PASS \|` |
| 0.60 baseline | exp −0.0919, PF 0.8669, win 0.3080, 1,419 trades | VERIFIED — Sprint15_3 §4: `\| **0.60 (baseline)** \| −0.0919 \| 0.8669 \| 0.3080 \| 1,419 \| 1.0000 \| — \|` |
| Drawdown | 567.6R vs 207.7R FAIL; recovery −0.5587 vs −0.6278 PASS | VERIFIED — Sprint15_3 §5 r24: `\| Max drawdown (R) \| 567.6 \| 207.7 \| FAIL \|`; `\| Recovery factor \| −0.5587 \| −0.6278 \| PASS \|` |
| Gate verdict | 0.40 NOT PROMOTED (expectancy INCONCLUSIVE p=0.16); 0.60 NOT PROMOTED (ties by construction); H1/GJ INCONCLUSIVE (<500 signals / <10k shadow) | VERIFIED — `### EURUSD M15 @ calibrated 0.40 (r24) — NOT PROMOTED (INCONCLUSIVE)`; `Decision: **do not promote; stay on the 0.60 baseline**.`; `### EURUSD M15 @ 0.60 (r22) — NOT PROMOTED (ties by construction)`; `\| EURUSD H1 \| 3,042 \| 410 \| 402 \| signals < 500, shadow < 10,000 \|`; CHANGELOG: `**Promotion gate: NOT PROMOTED** for EURUSD M15 at calibrated 0.40 (expectancy INCONCLUSIVE p=0.16, max drawdown FAIL 567.6 vs 207.7 R)` |
| Gate minima (code) | 10000 / 500 / 300; all-pass rule | VERIFIED CODE FACT — `Calibration/PromotionGate.mqh`: `#define PROMO_MIN_SHADOW 10000`, `#define PROMO_MIN_SIGNALS 500`, `#define PROMO_MIN_TRADES 300`; `Below the minimums the gate reports INCONCLUSIVE — never promotes.`; `//--- Overall: every criterion must PASS.`; `report.promoted = allPass && !anyInconclusive;` |
| Sprint17 frozen | 18,686 rows = 12467+3103+3116, 0 dups, fp 2e74bbae, schema 100/100 | VERIFIED — Closeout §3: `\| **Total** \| - \| - \| - \| - \| **19** \| **18,686** \| 6,130 \| 12,401 \| 5 \| 150 \| - \|`; `sprint17_stats.json`: `"mergedRows": 18686, "sumRuns": 18686`, `"digest": "2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90"`, rows 12467/3103/3116, win 4089/1004/1037, unknown 50 each; Closeout §4: `Schema Health (mode 8) ... **PASS** 100/100`, `Structural (mode 7) ... **PASS** gaps 0.0000%`, `Duplicate scan ... **PASS** 0 duplicates across 18,686 keys` |
| Score flatness | [0.35,0.60], 6/21 bins, per-bin 24–36%, systematic overconfidence, 2,214-row cap at 0.60 | VERIFIED — Sprint16_1: `\| confMin / confMax \| 0.3500 / 0.6000 \|`; `confidence spans only **[0.35, 0.60]** (P90 = 0.60, max = 0.60). Six of 21 bins are populated.`; `\| [0.35, 0.40) \| 2,733 \| 36.26% \|`, `\| [0.55, 0.60) \| 293 \| 24.23% \|`, `\| [0.60, 0.65) \| 2,214 \| 30.13% \|`; `actual win rate stays ~24–36% while the claimed probability rises 37.5% → 62.5%`; `Error = expected − actual win rate; positive error = **overconfident**.`; `**Systematic overconfidence in every populated bin**`; `**Cap artifact**: 2,214 rows sit at exactly 0.60` |
| Calibration quality | ECE 0.126533, Brier 0.242516, MCE 0.332679 | VERIFIED — Sprint16_1: `\| ECE \| 0.126533 \|`, `\| Brier \| 0.242516 \|`, `\| MCE \| 0.332679 \|`; Sprint16_2: `## Calibration Gain table (raw reference ECE 0.126533, Brier 0.242516)` |
| Ordering | Spearman +0.2069/+0.2118, Kendall −0.0433/−0.0432 | VERIFIED — Sprint16_1B F1: `\| Spearman(conf, R) \| +0.2069 \| 12,130 \|`, `\| Spearman(conf, win/loss) \| +0.2118 \| 12,125 \|`, `\| Kendall(conf, R) \| -0.0433 \| 12,130 \|`, `\| Kendall(conf, win/loss) \| -0.0432 \| 12,125 \|`; `~ 0.21 is a weak positive monotone association; the Kendall values are essentially zero and NEGATIVE in sign.` |
| Transforms | isotonic constant 0.3301 single-knot; Platt a=−1.0704 b=−0.2474; temp b=−117.4 t=721.5 ECE 0.1949/Brier 0.2500 worse than raw; all trades@0.60=0 | VERIFIED — Sprint16_2: `**Isotonic collapses to the constant base rate (0.3301).** The fitted model has a single knot (nodesX 0.35, nodesY 0.33006).`; `**Platt fits a *negative* slope (a = −1.0704, b = −0.2474).**`; `**Temperature scaling diverged (b = −117.4, t = 721.5).**`; `ECE (0.1949) / Brier (0.2500) are **worse than raw**`; `\| isotonic_v1 \| 0.00506 \| +0.1215 \| 0.22112 \| +0.0214 \| 0.00506 \| 0 \| 0 \|`; `\| platt_v1 \| 0.01419 \| +0.1123 \| 0.22071 \| +0.0218 \| 0.02627 \| 0 \| 0 \|`; `**Every calibrated model empties the 0.60 gate (trades@0.60 = 0).**` |

No UNVERIFIED items among assigned numbers. Interpretation (weak ordering, degenerate transforms, 0.40 best-paper/worst-risk) follows from verified rows.

## 2. Fix 1 forensic result — cost-aware minimum RR

### 2.1 Q1 — Is `RR < 1.0` the only rejection? `NOT CONFIRMED` (CODE FACT)

`Entry/ExecutionPlanner.mqh::BuildPlan` (~287–335) is a single if/else-if ladder with SIX reject reasons; RR clause is LAST:

- `entryPrice/stopLoss/takeProfit <= 0` → `Invalid Prices` [4] (:293–297)
- directional bracket C6 (SL/TP on wrong side) → `Invalid Prices` [4] (:303–310)
- `stopDistance < spread*2` → `Stop Too Close` [6] (:312–317)
- `stopDistance < minStopDist` → `Broker Min Stop` [2] (:318–323), with `spread = SYMBOL_SPREAD*m_point` (:288), `minStopDist = minStopDistancePips*10.0*m_point` (:289)
- `targetDistance < spread` → `Target Too Close` [7] (:324–329)
- `riskReward < 1.0` → `RR Below Minimum` [5] (:330–335)

Mirror ladder in `EvaluateSingleCombo` (~436–473, buckets [4]/[4]/[6]/[2]/[7]/[5]). Boundary strict `< 1.0`: `RR==1.0` PASSES. Label `m_rejectionLabels[5]="RR Below Minimum"` (:119) overstates a hardcoded literal — no configurable minimum exists.

### 2.2 Q2 — Gross or net? `CONFIRMED GROSS` (CODE FACT)

- `BuildPlan` (:279–285): `stopDistance=MathAbs(entry-stop)`, `targetDistance=MathAbs(tp-entry)`, `riskReward=target/stop`. Zero cost subtraction. Identical in `EvaluateSingleCombo` (:430–432).
- `Entry/TargetResolver.mqh::ResolveTargetByFixedRR` (:8–16): `entry ± stopDist*targetRR` gross; structure paths return raw levels (`ll.price`, `ob.low/high`, `fvg.lower/upper`, `bos.pivotPrice`, :30–125), no cost adjustment.
- Cost inventory: spread PRESENT only as distance floor (`spread*2` stop, `spread` target); slippage ABSENT from all five target files (exists only as `Core/Config.mqh m_slippage(3)` → `TradeManager m_maxSlippage(3)` → `SetDeviation`, execution tolerance, never RR input); commission/swap ABSENT from gate (only post-trade `HistoryDealGetDouble(DEAL_PROFIT/SWAP/COMMISSION)` in `PositionLifecycleManager.mqh:631–633`).

### 2.3 Q3 — Can RR=1.0 go negative after costs? `CONFIRMED PERMITTED-BY-CODE`, magnitude UNVERIFIED

CODE FACT: nominal 1.0R plan above spread floors is ACCEPTED; no later line deducts costs; `Trading/TradeValidation.mqh::AreStopsValid` has zero `riskReward|RR|SPREAD|commission|swap|slippage|1.0|1.5` matches — no deal-time profitability re-check. Consequence (any positive round-trip cost → net < 1.0R, can go ≤0) is arithmetic DESIGN HYPOTHESIS; SIZE of drag UNVERIFIED (no per-trade cost ledger in repo).

### 2.4 Q4 — Is `minRR=1.5 + (target−costs)/(stop+costs)` supported? `NOT CONFIRMED` — DESIGN HYPOTHESIS

CODE FACT of absence: no `minRR|MinRR` symbol repo-wide; no `netRR|net_rr|costAdjusted|target-costs|stop+costs` formula; planner `1.5` grep empty. Existing `ExecutionPlanTypes.mqh::targetRR=2.0` is a TP-construction tier (`BuildPlan :263–267`), not an acceptance floor — conflating them is a category error. Test tiers {1.0,1.5,2.5,3.0} in `TestFixedRRTier.mqh` are TP-identity fixtures, not gate evidence.

### 2.5 Q5 — Distortion risk? Hypothesis with verified premises

Premises (CODE FACT): resolvers own LEVELS, gate owns ADMISSION; structure TP ignores `targetRR`, so gate-only `minRR` lift disproportionately rejects structure plans (selection bias, not uniform lift); `EvaluateSingleCombo` uses `targetRR=2.0` sweep rows vs live `TARGET_OPPOSING_LIQUIDITY` default — matrix conclusions do not transfer 1:1. Conclusion (HYPOTHESIS): gate-only threshold/filter tuning = low-risk class; baking costs into resolver LEVELS = high-risk class (alters broker TP/SL, C6/C7 validity, fill-price sizing, telemetry R, ledger identity). Any net-R must be a SEPARATE field alongside gross `riskReward`, never an overwrite.

Classification: `PARTIALLY CONFIRMED` overall — hole CONFIRMED, proposed value/formula NOT CONFIRMED.

## 3. Fix 2 forensic result — exit management

Firewall: CODE FACT = quoted logic; EVIDENCE-SUPPORTED CHANGE = code + verbatim doc/CSV; DESIGN HYPOTHESIS = no repo evidence.

### Breakeven — mechanics CONFIRMED, runtime DEAD

- Defaults OFF, trigger 1.0R: `PositionLifecycleManager.mqh` ctor `:100-101` `m_beEnabled(false)`, `m_beTriggerR(1.0)` (CODE FACT).
- Trigger R-multiple on live price: `ApplyBreakeven:485-487` `rr=CalculateRRatio(...); if(rr<m_beTriggerR) return false;` (CODE FACT).
- SL exactly at entry, no buffer: `ApplyBreakeven:489` `double newSL = pos.priceOpen;`, no `SYMBOL_SPREAD`/ask-bid/commission term in :479–508 (CODE FACT).
- Scratch-turns-loss: BUY R uses `SYMBOL_BID` (:582–584); BUY stopped "at entry" fills at bid = entry−spread → net −spread−commission−swap (CODE FACT mechanics).
- Improvement-only + live-price sanity + once-only latch: `:480,491-499,501-507` (CODE FACT). `ModifyPosition:666-669` `PositionModify` only, no `SetDeviationInPoints`/spread/retry (CODE FACT).
- **BE NEVER enabled**: `SymbolContext.mqh:639-651` constructs + `Init/SetPositionManager/SetMagicNumber` only; repo-wide `EnableBreakeven(true)` / `SetBreakevenTrigger` zero callsites (CODE FACT). Dead code by default.

### Trailing — fixed-distance CONFIRMED, runtime DEAD

- Defaults OFF, trigger 2.0R, `100.0*_Point`: ctor `:102-104` (CODE FACT). `ApplyTrailingStop:518-527` trigger R-multiple, `newSL = bid−m_tsDistance / ask+m_tsDistance` (CODE FACT). Stops-level guard `:539-549`, but `iATR|ATR|spread|Slippage|SetDeviation` zero hits in file — NOT ATR/spread-scaled (CODE FACT). Ratchet improvement-only + `_Point` anti-churn `:529-536` (CODE FACT). EVIDENCE-SUPPORTED: `docs/Sprint18_Research/10_Exit.md §6.3`: fixed 10-pip distance "not R- or ATR-scaled". Never enabled repo-wide (CODE FACT, same as BE-7).

### Partial close — passive-only CONFIRMED, proposal UNVERIFIED

- `DetectPartialClose:457-473` observes `pos.volume < lastVolume−0.001`, counts `m_statPartialCloses++`, labels `POS_STATE_PARTIAL`; called every tick `:373` before BE/TS switch; never orders (CODE FACT).
- Zero `PositionClosePartial|PositionClose(|ClosePartial` in `Entry;Trading;Portfolio` — only skill-ref hits (CODE FACT). Lifecycle's sole trade call is `PositionModify` (:669). `PositionContext` (`PositionLifecycleTypes.mqh`) has no partial-intent fields; `TargetResolver` resolves exactly ONE TP (CODE FACT). PARTIAL branch `:420-437` re-applies BE/TS only — no-op while OFF; exits are broker/external-driven (`POS_STATE_CLOSED` + `EVENT_POSITION_CLOSED`, `GetClosedProfit` DEAL_ENTRY_OUT :606–640) (CODE FACT).
- `50%-at-1.5R`: **no verbatim repo occurrence**. Nearest: `docs/Sprint16_ResearchPlan.md:183` C5 `Close 50% at 1R, rest 2R with BE` (candidate proposal, 1R not 1.5R, no measurement); `docs/Sprint18_Research/10_Exit.md §7.1`: dataset "single-policy 2R/1R ... No BREAKEVEN exits exist"; `docs/Sprint20_ED01E_Decision.md`: "no tier cleared → 2.0R REMAINS BEST". Claim "evidence-supported" would be FALSE (DESIGN HYPOTHESIS).

### Lifecycle compatibility (CODE FACT, must scope any future change)

`SymbolContext::Init :639-651` calls lifecycle `Init()` before `SetPositionManager/SetMagicNumber` and never `SetSymbol` — `Init:126` sets `m_symbol=_Symbol` (chart symbol); multi-symbol contexts misroute `DiscoverPositions` filtering. No `SetSymbol` callsite repo-wide. `Update :360-380` runs `DetectPartialClose` before BE/TS with volume-invariant R denominator (correct). `AddContext` restart resets `breakEvenApplied=false` (benign re-apply). `EXIT_PENDING` enum state never assigned. Future partial via `CTrade.PositionClosePartial` has no signature conflict but inherits netting semantics already handled by `DetectPartialClose`.

Classification: mechanics `CONFIRMED`, runtime-impact `NOT CONFIRMED` (dead by default), 1.5R/50%/ATR values `NOT CONFIRMED` (hypothesis).

## 4. Fix 6 forensic result — sizing/exposure integrity (10 claims)

Runtime log grep (`POSITION-SIZ|RISK-APPROVED|RISK-REJECTED|PORTFOLIO-RISK|ORDER-BLOCKED-POSITION|EXPOSURE-UPDATE` over `SuperCents_X.log`) = no matches → runtime evidence N for all rows. Unit: `Tests/unit/TestIntegrityFixes.mqh:77-80` covers sizer formula only; `CapitalAllocator.CalculateSize` zero hits in `Tests/unit` (absence verified).

| # | Claim | Verdict | Location + logic | Live? | Severity |
|---|---|---|---|---|---|
| 1 | volumeMin floor-clamp over-risk | CONFIRMED | `Risk/PositionSizer.mqh::Calculate ~L168-190`: `lots=MathFloor(lots/volumeStep)*volumeStep; if(lots<volumeMin) lots=volumeMin; if(lots>volumeMax) lots=volumeMax; result.dollarRisk=lots*riskPerLot;` | Reachable via `TradeManager` C2 `:303-310` (`sizing.valid && sizing.lots>0`); dead via `CRiskManager` | Medium; alters size YES, expectancy YES; no new param (policy decision reject-vs-clamp) |
| 2 | duplicate re-clamp floor-vs-round, clamp-then-round | CONFIRMED | Sizer `:175` floor vs `CapitalAllocator.mqh ALLOC_FIXED_PERCENT ~L120-135` `MathMax/MathMin` then `MathRound(lots/lotStep)*lotStep` (round can push off-step/over-max); `TradeManager.mqh:313` → `IsVolumeValid` (`TradeValidation.mqh:79-100` range + `MathMod(vol-volMin,volStep)`) rejects approved allocation | Reachable both paths | Low-Medium; size YES; no new param (round-then-clamp ordering) |
| 3 | stale/invalid tick-value | CONFIRMED stale + CONFIRMED handled-invalid | `RefreshSymbolProperties :28-37` caches `SYMBOL_TRADE_TICK_VALUE`; `Update :100-102` empty; `SetSymbol :112-119` refreshes only if initialized; `CalculateCached :195-210` forwards cache; `Calculate` guards `tickValue/tickSize/point<=0` → invalid → `POSITION-SIZING-FALLBACK` keeps `m_lotSize` | Reachable C2 | Medium; size YES; no new param (refresh call) |
| 4 | volume*priceOpen exposure | CONFIRMED | `Risk/ExposureTracker.mqh::Update ~L135-145`: `longExposure/shortExposure=volume*priceOpen`; risk leg `MathAbs(priceOpen-sl)*volume` (no contractSize/FX); consumer `Risk/RiskManager.mqh:260` `addedExposure=sizing.lots*plan.entryPrice` vs `equity*(maxPortfolioExposurePercent/100)` | Updater live, sole sizing consumer DEAD (see 10) | Medium gate-inert/wrong; no new param (notional formula) |
| 5 | hardcoded 100000 | CONFIRMED | `Portfolio/PortfolioRiskManager.mqh ~L200-210`: `addedExposure = stopDistance*_Point*100000.0` (ignores lots/tick value) vs `equity*(maxSymbolConcentrationPercent/100)` | REACHABLE live via `SymbolContext.mqh ~L1290-1300` per-plan gate | Medium; expectancy YES; no new param (`SYMBOL_TRADE_CONTRACT_SIZE`) |
| 6 | missing tickSize/point divisor | CONFIRMED | `CapitalAllocator.mqh ALLOC_EQUAL_RISK ~L168-172`: `riskPerLot=stopDistPoints*tickValue` (no divisor) vs `ALLOC_FIXED_PERCENT ~L110-113` H7 fix `riskPerLot=(stopDistPoints*tickValue)/(tickSize/_Point)`; same omission `AllocationEngine.mqh ~L114-117` | Reachable (EQUAL_RISK selectable; engine misstatement always) | High when EQUAL_RISK / Medium always; size YES; no new param |
| 7 | gate disagreement | CONFIRMED dead-leg / PARTIALLY live-leg | `Risk/RiskManager.mqh ~L208-258`: clamped sizing then gate-4 `dollarRisk>maxRiskCapital`, gate-5 `lots>maxLotSize / <minLotSize` (fires only on config-vs-broker mismatch or #1 over-risk); caps differ `Risk/RiskTypes.mqh` 5/50% vs `Portfolio/PortfolioRiskTypes.mqh` 10/30% | `CRiskManager` gates DEAD; portfolio gates LIVE | Low-Medium; no new param (pre-clamp check + single source) |
| 8 | digit handling *10*point | CONFIRMED | `StopLossResolver.mqh :23-24` `stopBufferPips*10.0*point`, `:83-86` `minStopDistancePips*10.0*point`; mirrored `ExecutionPlanner.mqh :289,:437`; assumes pip=10pt (3/5-digit only) | Reachable every plan (`BuildPlan :253-256`, `EvaluateSingleCombo :421-424`) | Medium; size YES via stop distance; no new param (digits-aware conversion) |
| 9 | broker-minimum lottery | CONFIRMED | `StopLossResolver.mqh :82-90`: `minDist` fallback `stopLoss=entry∓minDist`, `policyName="Broker Minimum"`, `return true` (no stops-level/spread/directional check at layer); defaults inconsistent `ExecutionPlanTypes.mqh:53-54 minStop(5.0)` vs `ExecutionPlanner.mqh:506` matrix base `10.0`; downstream `TradeValidation.mqh AreStopsValid :120-160` catches only send path, not sizing/gate paths | Reachable both planner paths | Medium; size YES; no new param (stops-level-aware fallback + single default) |
| 10 | reachable vs theoretical | CONFIRMED scoping | LIVE: `SymbolContext.mqh :795-816` wires sizer/risk%/cap into `CTradeManager`; `TradeManager.mqh :88-95` defaults `m_lotSize(0.01), m_riskPercent(0.0), m_maxPositionsPerSymbol(1)`; `SetRiskPercent :104`, `SetMaxPositionsPerSymbol :105`; C3 `:249` `CountOpenPositions()>=m_maxPositionsPerSymbol`; C2 `:303-310`; portfolio gate `:1290-1300`. DEAD: `SymbolContext.mqh :604-611` `new CRiskManager()` + `Init()` BEFORE sizer (:795)/tracker (:818)/monitor (:829) exist, zero `SetPositionSizer/SetExposureTracker/SetDrawdownMonitor` callsites → `CRiskManager::Init :87-90` necessarily fails → `Evaluate` zero callers (only `Engine.mqh:349 GetRiskManager()` exposes). | — | High scoping: edits in dead gates change nothing live |

Overall Fix 6: 9× CONFIRMED + 1 split. No new parameters required anywhere.

## 5. Production-path analysis

- Admission: `ConfluenceEngine.mqh:436 Update` → `ExecutionPlanner.mqh:Update :176+` → `BuildPlan :211` → `PLAN_EXECUTABLE/:338-341` or `PLAN_REJECTED` + bucket + `EXECUTION-PLAN RR=%.2f` log `:365-372`.
- Execution: `TradeManager.mqh:216-227` EXECUTABLE-only loop → dedup/position-gate/fill-price → `ValidateAll :274-275` (`IsTradingAllowed+IsVolumeValid+AreStopsValid+IsMarginSufficient`, `TradeValidation.mqh:128-143`, no RR) → fill-price sizing → OrderSend. `SymbolContext.mqh:1291-1295` (+EN03 :1116-1118) confirms EXECUTABLE as cross-module token.
- Diagnostic-only: `EvaluateSingleCombo :376` ← `EvaluatePolicyCombos :510-565` ← `Shutdown :599-600`, `LogInfo`-only matrix; non-production evidence.
- Sizing live: `TradeManager` C2/C3 + `PortfolioRiskManager/AllocationEngine/CapitalAllocator`. `CRiskManager` 7 gates + `ExposureTracker` risk leg dead by NULL-init ordering (4.10).
- Exits live: single TP at entry (`TargetResolver`); lifecycle BE/TS/partial default-OFF/unwired; closes broker/external-driven.

## 6. Risk classification

- Mechanical integrity (alters correctness, not strategy): Fix 6 live items (clamp policy, divisor, contract size, digit math, round-order, tick refresh, stops-level fallback, single min-stop default); Fix 1 separate net-R field; Fix 2 buffer-if-enabled + `SetSymbol` misrouting note. Low-medium blast radius if scoped to live paths with revalidation.
- Risk-management corrections (alters risk posture): clamp→reject decision, pre-clamp gate ordering, single caps source, exposure notional formula. Requires re-gating (not re-optimization) because fill-vs-reject mix changes.
- Strategy-design hypotheses (NOT authorized as profit fixes): `minRR=1.5`, cost formula values, `BE@1.5R+buffer`/enable, ATR trail, `50%-at-1.5R`/any partial schedule, any claim these raise expectancy/PF/win. Zero repo measurement; nearest artifacts are proposals or single-policy datasets (3.P-5).

## 7. P31/P32/P34/P35 compatibility

- P31 survivor (`Entry/ActiveTierSurvivorPolicy.mqh`: max `totalConfidence` → min `decisionId` 1e-9 per signalTime; `SymbolContext.mqh:1190-1236` admission boundary, upstream C4 preserved): Fix 1/2/6 touch planner-gate, lifecycle-modify, sizing math — none touches survivor ranking, tie-eps, per-signalTime dedup, or C4 attribution. Compatible PROVIDED no change reorders candidates pre-survivor or alters `totalConfidence` semantics. Verified zero `survivor` hits in `Entry/ExecutionPlanner;Trading;Risk;Portfolio/PortfolioRiskManager;Calibration` outside `SymbolContext` callsite (grep).
- P32 (`TT01_20260904_135657` overall FAIL package), P33 (`UNEXPLAINED=0`, RE-FREEZE BLOCKED), P34 (`REFREEZE AUTHORIZATION RECOMMENDED`, `research_optimization_allowed=false`, `UNKNOWN=FAIL` retained): compatible — P36 executes no TT01, changes no gate definitions, claims no readiness.
- B8/B9 provenance: B9 verified present — `Tools/TT01/baseline/baseline.manifest.json`: `freezeId B9`, `commit 36c7a73`, `previousSha B5AB5FEE...`, `rows 467`, `csvSha 41F68E8F...`, counters 467/259/158/50. B8→B9 values (467/211/6061, 8/76/32769) match P35. Any future implementation MUST preserve both baselines immutably; must not rewrite manifest, CSVs, or `P31`/`B8_rollback` trees.
- TT01 gates: unchanged by P36. Any post-fix run is a NEW run ID, never an edit of P32 evidence.
- Dirty-tree warning (CODE FACT): `git status` shows modified `Calibration/CalibrationMetrics.mqh`, `Confluence/ConfluenceEngine.mqh`, `Core/Engine.mqh`, `Portfolio/SymbolContext.mqh`, structures, `Tests/*`, `Tools/TT01/baseline/*` (CSV + manifest), plus untracked `.agents/.claude/.opencode/2026-08-27_BUGS_OBSERVED.md`. P36 predicate "verify B9 exists before assuming" is SATISFIED (manifest above), but tree is NOT clean — implementation phase must start from a clean/committed state with revalidation, otherwise provenance is unprovable.

## 8. Evidence gaps (recorded as unavailable, no new experiments per boundary)

1. No `SuperCents_X.log` profit ledger in repo glob (only `compile_*.log` UTF-16); runtime sizing/RISK log evidence N for all Fix 6 rows.
2. No per-trade spread/slippage/commission/swap ledger for production path → net-drag MAGNITUDE unverified (hole verified, size not).
3. No weight-search output on settled v3; optimizer 5000-row cap vs 12,130 rows (subsampling bias risk noted, not re-run).
4. No WFO/MC/regression on settled outcomes (frameworks + unit greens only); no costed R-multiples; H1/GJ sample-starved by construction.
5. No BE/TS/partial measurement: single-policy 2R/1R dataset, no BE/trailing/partial exits simulated.
6. Dirty working tree blocks implementation provenance until cleaned.

## 9. Implementation recommendation (binding split)

**P36 IMPLEMENTATION SPLIT — SPECIFIC ITEMS AUTHORIZED** (mechanical integrity only; strategy hypotheses excluded):

AUTHORIZED (integrity/risk corrections, each revalidated, no optimization):

- (a) Fix 6 live-path: tickSize divisor in `CapitalAllocator:ALLOC_EQUAL_RISK` + `AllocationEngine` pre-computation; `100000.0` → `SYMBOL_TRADE_CONTRACT_SIZE` lookup; digits-aware pip conversion (single helper, single min-stop default); round-then-clamp ordering; tick-cache refresh path; stops-level-aware SL fallback. PROHIBITED: edits inside dead `CRiskManager` gates / `ExposureTracker` risk leg as "fixes" (document-or-delete decision only, separate governance).
- (b) Fix 1: add separate cost-aware admission field alongside gross `riskReward` (levels untouched; resolvers untouched; sizing/telemetry/ledger still consume gross until re-specified). PROHIBITED: setting `minRR=1.5`, overwriting `riskReward`, or cost-adjusting resolver LEVELS.
- (c) Fix 2: buffer-aware BE target + `SetSymbol` misrouting correction as correctness notes with BE/TS remaining default-OFF. PROHIBITED: enabling BE/TS or adding any partial schedule.

NOT AUTHORIZED (require separate validated proposal + OOS evidence, research ban still applies):

- `minRR=1.5`, any cost-formula constant, `BE@1.5R`, any BE offset value, ATR-multiple trail, `50%-at-1.5R` or any partial, per-bin sizing/DD-gating, weight/threshold/WFO/MC/transform re-anchoring, risk% changes, H2 access, deployment claims.

Preconditions for any authorized edit: clean tree, untouched baselines/manifests/PromotionGate, new TT01 run ID on completion, P31 survivor + C4 + B9 byte-identity re-checks.

## 10. Deployment-readiness status

- Research/optimization: BLOCKED (P34 §9, retained).
- Real-time deployment (paper/shadow/live): NOT AUTHORIZED.
- Profitability: NOT established (best M15 0.40 NOT PROMOTED, p=0.16, DD FAIL; transforms unadoptable; H1/GJ INCONCLUSIVE).
- Certification: B8 NOT CERTIFIED; B9 EXECUTED, NO CERTIFICATION (P35 §6).
- P36 changes nothing above. Correctness fixes do not imply edge.

## 11. Repository safety attestation

P36 performed: read-only `read/glob/grep/bash(git rev-parse/branch/status)` + four read-only scout agents; no file writes except this record; no parameter/baseline/gate edits; no TT01 execution; no holdout access; no optimization; no commit/stage/merge/rebase/revert/reset/clean. B8/B9/manifest/preset/JSON paths read, not written. Dirty-tree state reported as found, not modified. STOP after P36: awaiting separate authorization before any implementation batch.

*Verification agents: ProfitEvidence, Fix1RR, Fix2Exit, Fix6Sizing (transcripts `history://<id>`, payloads `agent://<id>`). Line numbers (~) are HEAD-36c7a73 readings; re-confirm exact lines before any future edit.*
