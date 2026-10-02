# P39 — SYMBOLCONTEXT SETSYMBOL WIRING CORRECTION

Date: 2026-09-05
Mode: Narrow mechanical correction under P38 item 2b authorization. No reset/stash/commit/checkout/restore; no clean-tree manufacturing.
Basis: P38 (`docs/P38_POST_P37_AUTHORIZATION_BOUNDARY_REVIEW_2026-09-05.md` item 2b: READY conditional on committable tree → human explicitly authorized P39 direct edit preserving dirty state).
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`.

## Disposition

### `P39 COMPLETE — SETSYMBOL WIRING CORRECTED AND VALIDATED`

## 1. Initial tree state

Pre-edit `git diff HEAD -- Portfolio/SymbolContext.mqh`: 125 insertions, 9 deletions — P31 survivor policy (`ActiveTierSurvivorPolicy.mqh` include, `m_activeTierSeen*` arrays, admission-boundary logic ~`:1190+`) plus P31-era OOM hardening. Attributable P31/B9 state, not unrelated work. Full tree: 37 modified files (26 pre-existing + 11 P37).

## 2. Exact file and region changed

`Portfolio/SymbolContext.mqh`, `CSymbolContext::Init`, lines :647-655 (post-edit numbering). Verified pre-edit text matched P38 evidence verbatim (fresh read tag `#E4BB`); `m_symbol` member confirmed in scope (decl `:76`, ctor-init `:299`).

## 3. Nature of the correction (1 code line + 3 comment lines, pure insertion)

```mql5
m_positionLifecycleManager.SetPositionManager(m_positionManager);
m_positionLifecycleManager.SetMagicNumber(m_magicNumber);
//--- P39 (mechanical, P38-2b): route the owning context symbol into the
//    lifecycle manager (was chart-_Symbol via Init). Order-safe with
//    the P37 Init guard. Disjoint from P31 survivor region (~1190+).
m_positionLifecycleManager.SetSymbol(m_symbol);
```

Effect: each per-symbol context's lifecycle manager now filters `DiscoverPositions` by its own symbol instead of the chart symbol. Order-safe: P37 `Init` guard (`if(m_symbol=="")`) covers pre-Init assignment; the unconditional setter covers this post-`Init` call. Default single-symbol behavior identical in outcome (same symbol value), multi-symbol routing corrected.

## 4. P31/B9 preservation

Post-edit diff: 129 insertions, 9 deletions (+4 = exactly the P39 hunk; deletions unchanged). Survivor-region diff lines unaltered (pre-existing P31 hunks only; P39 op was pure insertion with no range overlap). No reset/stash/commit performed. B8/B9/manifest/CSV, PromotionGate, TT01 definitions, holdout untouched (file list §7 confirms none added).

## 5. Compile/test results

- `SuperCents_X.mq5` (MetaEditor64): `Result: 0 errors, 0 warnings` (`compile_p39_ea.log`).
- `Tests/TestRunnerEA.mq5`: `Result: 0 errors, 0 warnings` (`compile_p39_tests.log`).
- Tester run (Model=4, EURUSD H1 2026.01.01→02, fresh build tag `2026.09.05 11:17:01`, `Tests/p39_artifacts/p39_suite_hits.log`): `>>> BUILD` identity confirmed, FAIL lines none, C2 16/16, C6 38/38, **GRAND TOTAL 3344/3344 passed, 0 failed**. P37 evidence (`Tests/p37_artifacts/`) preserved via separate P39-scoped run script (`Temp/p39_run_tests.ps1`, sed-derived).

## 6. Compatibility verification

- P31 survivor: region untouched + survivor suite inside green grand total.
- P37 corrections intact: `P37` markers present in all 10 files; C2 reject-contract suite green.
- BE/TS/partial enablers: grep `EnableBreakeven(true|EnableTrailingStop(true` over `Entry Trading Portfolio Risk Core` = empty (still unwired).
- Strategy parameters: none changed (no `input`/config/default-threshold edits; BE buffer still 0.0 unset).
- Scope prohibitions honored: no survivor/dedup/ranking/ID/C4/B9/PromotionGate/risk-limit/buffer-value/net-RR/cap/`CRiskManager`/research changes.

## 7. Complete list of files changed (P39 delta)

`Portfolio/SymbolContext.mqh` only (+4/−0). Tracked tree remains 37 modified files (26 pre-existing + 11 P37 + 0 new entries — P39 folds into SymbolContext's existing dirty entry). New untracked evidence: `docs/P39_*` (this record), `compile_p39_ea.log`, `compile_p39_tests.log`, `Tests/p39_artifacts/p39_suite_hits.log`, `Temp/p39_run_tests.ps1`.

## 8. Remaining P38-blocked items (explicitly NOT done)

Net-RR formula/value (design authorization), nonzero BE buffer value (design authorization), concentration-cap recalibration (measurement evidence first). No profitability optimization, research, deployment, or B9 recertification follows. STOP after P39.
