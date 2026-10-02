# P40 — REMAINING PROFITABILITY-MECHANICS DESIGN REVIEW

Date: 2026-09-05
Mode: READ-ONLY design review. No production/test/parameter/baseline/holdout/PromotionGate/governance-record modification; no runs executed.
Basis: P38 boundaries, P39 validated state (`docs/P39_SYMBOLCONTEXT_SETSYMBOL_WIRING_CORRECTION_2026-09-05.md`: EA 0/0, runner 0/0, 3344/3344, C2 16/16, C6 38/38).
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`. Tracked modifications: 37 files, same set as P39 close (verified read-only).

## Disposition

### `P40 FURTHER EVIDENCE REQUIRED`

No remaining item is sufficiently specified for implementation authorization. Two items require explicit human design decisions (no measurement can pick them); one requires measurement evidence from an authorized run. Detail per item below; summary table in §5.

## 1. Net-RR evidence matrix (per-component availability at the planner gate)

| Component | Status | Basis |
|---|---|---|
| Entry / stop / target price | AVAILABLE PRE-TRADE | Plan fields from resolvers (`ExecutionPlanner.mqh::BuildPlan`). |
| Direction | AVAILABLE PRE-TRADE | `candidate.direction` → order type. |
| Tick size / tick value / point / digits / contract size / stops-level | AVAILABLE PRE-TRADE | `SymbolInfoDouble/Integer` at gate (`ExecutionPlanner.mqh:293-294,440-441`; P37 `PipToPriceDistance`). |
| Spread (points) | AVAILABLE PRE-TRADE | `SYMBOL_SPREAD` already read (distance floors only). |
| Volume (lots) | UNAVAILABLE at gate | Sizing occurs downstream (`TradeManager` C2 at fill price; portfolio allocator). Planner has no lots field. Any volume-scaled cost is uncomputable at admission. |
| Commission | UNAVAILABLE pre-trade | No pre-trade commission API consumed anywhere; only post-trade `HistoryDealGetDouble(DEAL_COMMISSION)` (`PositionLifecycleManager.mqh:648`, `Monitoring/StatisticsReporter.mqh:53`). Deprecated `POSITION_COMMISSION` reads were removed (Sprint25B). Broker-specific, often per-lot per-side — needs volume too. |
| Swap | UNAVAILABLE as a cost | `SYMBOL_SWAP_*` zero references repo-wide (grep-verified); only post-trade `DEAL_SWAP`. Rates are platform-knowable but holding duration is unknowable pre-trade. |
| Realized slippage | UNAVAILABLE | Configured tolerance (`CConfig::m_slippage=3` → request deviation) is an execution bound, never a realized value; never a planner input. |

### Approach evaluation (each rejected as self-authorizing; assumptions named)

- **Spread-only**: assumes commission ≡ swap ≡ slippage ≡ 0. False on most accounts; would bless still-negative trades as "net-positive". Strategy assumption.
- **Spread + commission**: needs per-lot commission rate (no API — invented constant) + volume (unavailable at gate). Assumption-heavy; unimplementable without fabrication.
- **Spread + commission + modeled slippage**: adds distributional assumption with no ledger to calibrate against (P36: no cost ledger exists). Unsupported hypothesis.
- **Conservative cost bound**: still requires a chosen bound constant + a threshold; the bound is a risk preference, not a derivation. Human design decision.
- **Expected-cost model**: requires a calibrated per-symbol cost distribution that does not exist. Requires additional evidence (ledger first).

No RR-threshold evidence exists: gate `1.0` is a legacy hardcoded literal; confidence thresholds (0.40/0.60) are an unrelated scale. Any `minRR` value (including 1.5) is a human risk-preference choice, not a derivation.

**Item disposition: requires explicit human design choice** (formula terms + threshold), with expected-cost variant additionally requiring a cost ledger. Not design-ready.

## 2. BE buffer design analysis

- **Current behavior** (post-P37/P39, BE default-OFF, zero enabler callsites): trigger 1.0R on live price; SL = `priceOpen ± m_beBufferDist` (0.0 ⇒ legacy exact); improvement-check vs live bid/ask; once-only latch; modify-only. Enabling/trailing/partials remain prohibited and untouched.
- **Plumbing**: member + accessors + directional use confined to `PositionLifecycleManager.mqh` (`:29,:83-84,:106,:502-504`); setter unwired.
- **SetSymbol propagation** (post-P39, verified read-only): owning symbol now flows into discovery filter (`:302` `POSITION_SYMBOL != m_symbol`), BE/TS pricing (`:507-508`, `:538-539`), stops-level guard (`:554`), R-ratio (`:598-599`), close-event attribution (`:348`). Routing correction complete; no further wiring exists to specify.
- **Mechanical vs strategy**: plumbing + routing are mechanical (complete). A nonzero buffer **materially changes expected trade outcomes** (scratch↔stop conversions shift the P&L distribution; interacts with the 1.0R trigger timing) — it is a strategy/performance decision. No documented execution invariant defines a "required buffer" (P37's phrase has no antecedent spec); candidates (1 spread? 2? +commission estimate?) are unconstrained by evidence.
- **Needed before authorization**: buffer definition (units/source/magnitude) + trigger/enabling policy + success metric (e.g., scratch-rate vs tail capture on settled non-holdout data) + validation gate. Note sequencing: the value is moot while BE stays disabled, and enabling BE is itself the larger strategy decision — authorize enabling policy first or together, never the value alone.

**Item disposition: requires explicit human design decision** (value + enabling policy + metric). Not design-ready.

## 3. Concentration-cap measurement analysis (evidence-gathering only; cap untouched)

- **Formula/value/contract**: `maxSymbolConcentrationPercent = 30.0` (% of equity; companions: positions 10, utilization 80%, daily −5%, DD −20%) — `Portfolio/PortfolioRiskTypes.mqh:26,35`. Numerator now true notional (`vol*price*contractSize` open + per-1-lot risk proxy for the candidate); denominator `ACCOUNT_EQUITY`. Binds live pre-allocator (`PortfolioRiskManager.mqh` §4 via `SymbolContext.mqh:1290-1300`).
- **Documented-intent check**: the cap now matches "% of equity" BETTER than the fiction it replaced. **Not demonstrably inconsistent** — no recalibration is indicated by correctness alone.
- **Expected mechanical consequence** (code analysis, not measurement): gate transitions inert→binding — e.g., ~0.03+ lot EURUSD open notional trips 30% of a $10k account where the old `$1`-scale sums never could. Single-symbol runs usually hit the C3 one-position cap first; the concentration gate matters chiefly multi-symbol. Observed frequency is unknown.
- **Measurement from existing artifacts: NOT POSSIBLE.** Telemetry schemas v3–v6 record decisions/validators/settled outcomes — no portfolio-gate rejection fields (only the unrelated swing-gate `gateDecision`). No persisted tester/journal logs contain `PORTFOLIO-RISK-REJECTED` lines (only P37/P39 unit-test run logs exist on disk; P32-era logs rotated away). Analytical reconstruction is refused: the gate needs concurrent-position state + equity + `plan.stopDistance`, none recoverable from settled telemetry. No numbers are fabricated in this record.
- **Needed before any value discussion**: an authorized validation run (non-holdout window) harvesting `PORTFOLIO-RISK-REJECTED [Symbol concentration...]` rate and exposure-before/after — explicitly NOT executed under P40 read-only.

**Item disposition: insufficiently evidenced, requiring measurement; value change (if ever proposed) is a risk-policy decision requiring explicit human authorization.** Current state is mechanically correct — category (1): correct and more meaningful after P37.

## 4. Cross-gate compatibility

Net-RR plumbing (additive fields, gross gate unchanged), BE plumbing (default 0.0, unwired), cap math (caps untouched), and P39 wiring (disjoint region) are all compatible with P31 survivor policy, C4 discipline, B8, B9 (uncertified, unregenerated), P37 corrections, PromotionGate, TT01 definitions, holdout, and the research-BLOCKED / no-deployment state. Completed integrity decisions are not reopened; profitability is not certified.

## 5. Future-action classification

| Item | Evidence Status | Mechanical Integrity | Strategy/Risk Decision | Additional Evidence Needed | Human Design Decision Needed | Future Authorization Status |
|---|---|---|---|---|---|---|
| Net-RR formula + threshold | Partial (prices/spread/ticks available; volume/commission/swap-realized unavailable) | Plumbing complete | Formula + threshold are strategy/risk choices | Cost ledger (for expected-cost variant) | YES — terms + threshold | BLOCKED |
| BE buffer value + enabling | Plumbing + routing complete; no value basis exists | Complete | Value + enabling policy are strategy choices | Success metric + validation gate design | YES — value + enabling policy | BLOCKED |
| Concentration-cap value | Correctness established; binding frequency unmeasured | Complete (no inconsistency shown) | Any value change is risk-policy optimization | Authorized validation run with rejection harvest | YES, if a change is ever proposed (after measurement) | BLOCKED |
| SymbolContext wiring | Executed + validated (P39) | Done | — | — | — | COMPLETE |

## 6. No-change attestation

P40 changed no code, tests, parameters, baselines, holdout, PromotionGate, or prior records (this record excepted as the required decision output); executed no runs, optimization, WFO, research, or deployment actions. STOP after P40.
