# P38 — POST-P37 AUTHORIZATION BOUNDARY REVIEW

Date: 2026-09-05
Mode: READ-ONLY. No code, test, baseline, parameter, governance-record, or working-tree modification (this record excepted as the formal decision output).
Basis: P37 partial disposition (`docs/P37_SCOPED_PROFITABILITY_INTEGRITY_IMPLEMENTATION_2026-09-05.md`), P36 split authorization.
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`.

## Disposition

### `P38 SPLIT — SPECIFIC ITEMS READY, OTHERS BLOCKED`

One sub-item is implementation-ready conditional on a committable tree; the rest require design authorization or measurement evidence first. No item is authorized for immediate implementation by this record.

## Decision matrix

| Item | Evidence | Mechanical vs Strategy | Authorization Status | Required Next Step |
|---|---|---|---|---|
| 1. Net-RR formula/value | Field confined to type + `BuildPlan` (grep `riskRewardNet\|hasNetRiskReward`: `ExecutionPlanTypes.mqh:76-77`, `ExecutionPlanner.mqh:230,289-290`, P37 doc). No consumers; gross gate unchanged. Cost-data inventory (grep `SYMBOL_SWAP\|COMMISSION\|SYMBOL_SPREAD\|Slippage\|Deviation` over `Entry Trading Core Portfolio Risk Confluence`): spread available at planner (floor-only, `ExecutionPlanner.mqh:293,440`); slippage tolerance exists (`CConfig::m_slippage=3` → `TradeManager::m_maxSlippage` → request deviation, execution-only, never planner input); commission post-trade only (`PositionLifecycleManager.mqh:647-648` `HistoryDealGetDouble DEAL_COMMISSION`); swap post-trade only (same, `DEAL_SWAP`); `SYMBOL_SWAP_*` zero references repo-wide. Planner holds only `m_point` + `_Symbol` + `ExecutionPlanConfig` (no cost fields). No RR-threshold evidence: gate `1.0` is legacy hardcoded literal; confidence thresholds (0.40/0.60) are unrelated scale. | Formula and threshold are STRATEGY ASSUMPTION (commission unknowable pre-trade; swap needs duration assumption; realized slippage unknowable; spread-only partial model would silently bless ignored costs). Plumbing is mechanical (done). | BLOCKED — design authorization required first, not implementation. | Narrow design review with measured cost ledger: define which cost terms, their authoritative sources, and the gate-threshold evidence basis. Do not assume `minRR=1.5`. |
| 2a. BE buffer value | `m_beBufferDist` flows confined to `PositionLifecycleManager.mqh` (decl `:29`, accessors `:83-84`, default `:106`, use `:502-504`); zero callsites of setter (BE unwired, verified P37). No "required buffer" antecedent spec exists anywhere in architecture. P36 BE-4 mechanics: scratch at exact entry fills −spread−commission−swap (semantic argument for nonzero), but amount (1 spread? 2? +commission estimate?) unconstrained by any evidence. BE default-OFF ⇒ any value has zero live effect until enabling (itself prohibited). | VALUE is STRATEGY/PERFORMANCE CHOICE, not mechanical requirement. Plumbing mechanical (done). | BLOCKED — value needs design authorization + validation; safely deferrable (no live effect while BE disabled). | Design authorization: buffer definition (source, units, magnitude) + trigger-timing interaction, validated before any enabling proposal. |
| 2b. SymbolContext `SetSymbol` wiring | Exact site `Portfolio/SymbolContext.mqh:647-651` (construct → `Init()` → `SetPositionManager/SetMagicNumber`, no `SetSymbol`); P37 lifecycle guard (`if(m_symbol=="")`) + unconditional setter make one-line insertion order-safe pre- or post-`Init`. Setter/getter exist, zero callsites (P36). P31 survivor code lives ~`:1190+` (admission boundary) — disjoint region, no shared state (`m_activeTierSeen*` untouched by wiring). | MECHANICAL correction (misrouting latent fact, P36). | READY conditional on committable tree — single line `m_positionLifecycleManager.SetSymbol(m_symbol);` in `:647-651` block. Not executable under current dirty tree without an authorized commit/stash decision. | Tree-state authorization first (commit/stash decision for P31/B9 dirty state), then 1-line implementation + unit/compile validation. No P31/B9 content change involved. |
| 3. Concentration-cap recalibration | Contract `Portfolio/PortfolioRiskTypes.mqh:26,35`: `maxSymbolConcentrationPercent(30.0)` (% of equity; `maxConcurrentPositions(10)`, utilization 80%, daily −5%, DD −20% companions). Applied at live pre-allocator gate (`PortfolioRiskManager.mqh` §4 via `SymbolContext.mqh:1290-1300`). P37 changed measurement to true notional (`vol*price*contractSize`, per-1-lot risk proxy; legacy fallback; caps untouched). Consequence: gate transitions inert→binding on FX by construction. Cap is NOT demonstrably inconsistent with its documented meaning — corrected math matches "% of equity" BETTER than the fiction it replaced. No reject-rate measurement exists (no TT01 since P37). | Value change would be RISK-POLICY/STRATEGY optimization (alters frequency/exposure). Current state is the mechanically correct one. | BLOCKED — measurement evidence required first. No value proposed (none labelled, even as hypothesis, deliberately). | Authorized validation run observing `PORTFOLIO-RISK-REJECTED` concentration rate vs pre-P37 baseline behavior; only then decide whether a cap-value review is warranted. |
| Enabling BE/TS/partials, 1.5R triggers, ATR trailing, scale-out | Prohibited by P36 §8c/P37, reaffirmed in scope. | Strategy (out of scope). | NOT AUTHORIZED (unchanged). | None in this chain. |

## P37 validated-state re-verification (read-only, from recorded evidence — no reruns)

- Tracked modifications: 37 files = 26 pre-existing (P31/B9-attributable, unchanged) + 11 P37 (exact §4 list). `git status` matches P37 close; no stash entries.
- `compile_p37_ea.log`: `Result: 0 errors, 0 warnings`. `compile_p37_tests.log`: `Result: 0 errors, 0 warnings`.
- `Tests/p37_artifacts/p37_suite_hits.log`: `>>> BUILD 25A-RUNTIME-01 tag="2026.09.05 11:01:34" term=6140`; GRAND TOTAL 3344/3344, 0 FAIL; C2 16/16, C6 38/38, C1-resolver 35/35.
- Net-RR grep confirms no new consumers appeared; enabler grep (`EnableBreakeven(true|EnableTrailingStop(true`) still empty.

## Governance compatibility

All three areas handleable without changing P31 survivor policy (wiring region disjoint from `:1190+` survivor code), C4 discipline, B8, B9 (manifest/CSV untouched), PromotionGate, TT01 gate definitions, holdout, strategy parameters, confluence logic, or research/optimization state (remains BLOCKED; deployment NOT AUTHORIZED; profitability NOT established; B9 uncertified). P37 state intact per above.

## Repository safety attestation

P38 performed read-only `read/grep/bash(git status)` plus existing-log inspection. No reruns, no state changes, no prior-record edits, no optimization, no certification, no deployment action. STOP after P38. Next executable step (if authorized elsewhere): tree-state decision → item 2b one-line wiring. Items 1, 2a, 3 must not proceed to implementation without their stated design/measurement prerequisites.
