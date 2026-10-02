# Sprint 25B — Architecture Hardening & AI Research Readiness Assessment

**Status: ASSESSMENT COMPLETE / IMPLEMENTATION NOT AUTHORIZED**
Scope: read-only architectural assessment at HEAD `1e6aa5f` (Sprint 25A closed).
No source, test, telemetry, TT01, baseline, or evidence changes were made.
No commits, no push. All recommendations below are BACKLOG ITEMS only.

Date: 2026-08-15

---

## 1. Executive Summary

SuperCents_X is an MQL5 Smart-Money-Concepts EA whose **production path is small and clean** (`SuperCents_X.mq5` 144 lines → `CEngine` → `CPortfolioManager` → `CSymbolContext` per-new-bar pipeline), while the surrounding **hardening/validation/research layers are extensive but largely unwired libraries**. The genuinely running validation machinery lives in the **Python toolchain** (`Tools\ED01\*`, `GR01/GR02`) and the **TT01 harness**, which carry the real statistical discipline (day-stratified bootstrap, Bonferroni sensitivity CIs, frozen fingerprints, pairing keys, byte-identical determinism gates).

The strongest architectural facts:

1. **Execution truth is currently disconnected from research telemetry by design.** Orders are only sent in `ENTRY_MODE_LEGACY` (`Portfolio\SymbolContext.mqh:603`; `Trading\TradeManager.mqh:116-121`), while telemetry rows are only recorded in SHADOW/NEW modes (`SymbolContext.mqh:949`). `CActualOutcomeSettler` is self-documented as provably inert (`SymbolContext.mqh:648-651`). This is deliberate and safe, but it means **no executed-decision-to-outcome record exists today**.
2. **Decision identity is fragmented**: `TradeCandidate.id` (run-local), `EntryDecision.candidateId`, `ExecutionPlan.entryDecisionId`, `PositionContext.entryDecisionId`, broker comment `SCX-*-P<id>`, and telemetry `decisionId` (run-local, `Telemetry\TelemetryCollector.mqh:257-258`). The telemetry row is the de-facto canonical record but **carries no build identity and no run id**.
3. **No runtime event/state ledger exists.** The durable record is the append-only telemetry CSV (buffered, flushed on shutdown only — crash can lose up to 1024 rows), broker deal history, and the terminal journal. `m_submittedIds` duplicate-prevention watermark is **in-memory and lost on restart**.
4. **Sprint 25A fixed the build/provenance chain for the harness**, but the identity is not propagated into research artifacts: telemetry rows carry `configFingerprint` (config inputs) but no git commit, no build tag, no run id.
5. **Statistical tooling in MQL5 is weak (approximate p-value, no multiple-comparison correction) and unwired**; the Python toolchain is strong (bootstrap, Bonferroni, frozen pairing). Multiple-testing discipline exists only in experiment-specific Python scripts, not as an experiment-family registry.

**Verdict on the eight 25B objectives**: (1) safe execution truth — NOT PRESENT (no fill↔decision record); (2) deterministic lifecycle/state — PARTIAL (broker state reconstructible, internal state lost); (3) restart/crash recovery — PARTIAL (positions/telemetry durable, watermark/settlements/rows not); (4) auditable experiments — STRONG via Python+TT01; (5) machine-readable lineage — PARTIAL (manifests exist per experiment, no unified registry, no build identity in rows); (6) robust statistical validation — STRONG in Python, weak/unwired in MQL5; (7) AI-assisted research — foundation present (repo, harness, manifests), no AI-governance layer; (8) controlled AI-agent governance — MISSING (no AGENTS.md, no read-only agent workflow, no experiment registry).

**P0**: no live-trading correctness blocker found within the assessed scope, but two research-population integrity items qualify as P0-class for trustworthy research: telemetry row loss on crash, and the absence of a fill↔decision link (execution truth). **P1**: build identity in telemetry rows; decision↔fill ticket linkage; telemetry durability (flush policy). **P2**: run-scoped decision identity + manifest↔row linkage; restart idempotency; experiment-family registry. **P3**: read-only AI agent workflow + governance boundary.

---

## 2. Repository / Architecture Map

Production tree (included by `SuperCents_X.mq5:11-41`):

| Layer | Files | Role | Wired |
|---|---|---|---|
| Utils | `Utils\{Types,Constants,Helpers,MathUtils}.mqh` | enums/structs | ✅ |
| Core | `Core\{Logger,Config,Engine,HistoryEpoch}.mqh` | `CEngine` orchestrator, per-new-bar update | ✅ |
| Structure | `Structure\*` (Swing, StructuralPivotEngine, BOS, CHOCH, OB, FVG, Liquidity, ProtectedPoint, TrendState) | detection | ✅ |
| Visualization | `Visualization\*` (renderers, VisualStateEngine) | chart objects | ✅ |
| Confluence | `Confluence\*` (Engine, TradeCandidateBuilder, ScoreCalculator, SignalTypes) | candidate aggregation | ✅ |
| Entry | `Entry\*` (EntryDecisionEngine, EntryOrchestrator, ExecutionPlanner, resolvers, validators, PositionLifecycleManager, shadow providers) | decision + lifecycle | ✅ (legacy path) / partially dormant |
| Trading | `Trading\{TradeManager,TradeRequestBuilder,TradeValidation,TradeExecutionResult}.mqh` | order send | ✅ |
| Risk | `Risk\{PositionSizer,ExposureTracker,DrawdownMonitor}.mqh` (components wired at SymbolContext.mqh:666-697); `Risk\RiskManager.mqh` (full engine) | risk | ⚠️ components only; full engine **unwired** |
| Portfolio | `Portfolio\{SymbolContext,PortfolioManager,PortfolioRiskManager,AllocationEngine,...}.mqh` | per-symbol context + portfolio gates | ✅ |
| Telemetry | `Telemetry\*` | per-decision CSV rows + outcome simulation | ✅ |
| Monitoring | `Monitoring\{EventBusAdapter,HealthMonitor,MetricsCollector,StatisticsReporter}.mqh` | events/health/timing | ✅ (StatisticsReporter via Validation types) |
| Providers | `Providers\{ProductionTradeStateProvider,ProductionRiskEvaluator}.mqh` | real terminal state (NEW mode) | ⚠️ conditional |

Supporting / research trees:

| Tree | Role | Wired? |
|---|---|---|
| `Tests\` (TestRunnerEA 2738 tests, unit/integration, VF02) | validation suite | ✅ standalone runners |
| `Tools\TT01\` (TT01_Validate.ps1 + Validators, baseline/) | 10-gate platform harness + frozen baselines + manifest | ✅ standalone (post 25A) |
| `Tools\ED01\` (Python analyzers + manifests + artifacts) | experiment analysis (bootstrap/Bonferroni) | ✅ standalone |
| `Tools\EN03\` (Python + scenario EAs) | coordinated-trend research | ✅ standalone (closed) |
| `Tools\GR01/GR02\` | funnel dashboards | ✅ standalone |
| `Tools\25A\` | G2/G9/G8 tests | ✅ standalone |
| `Calibration\` + `CalibrationRunner` + `Presets\` | calibration experiments | ✅ standalone (uses ExperimentManifest) |
| `benchmarks\` + `BenchmarkRunner(.EA)` | component benchmarks | ✅ standalone |
| `Optimization\*` (WalkForwardRunner, MonteCarloValidator, RobustnessTester, ParameterManager, ReportGenerator, StrategyAnalytics, ExperimentManifest) | research libraries | ⚠️ only `CExperimentManifest` wired (via Calibration) |
| `Validation\*` (WalkForward*, MonteCarlo*, RegressionDetector, ValidationLab, TesterDataSource) | research libraries | ❌ unwired (init-only tests) |
| `Research\*` (StatisticalValidator, ConfidenceCalibrator, RobustnessProfiler, BenchmarkFramework) | research libraries | ❌ unwired |
| `Laboratory\*` (StatisticalAnalyzer, RobustnessAnalyzer, KnowledgeGraph, ArtifactRepository, ExperimentComparator, manifests, RankingEngine, RecommendationEngine, StrategyCatalog) | research libraries | ❌ unwired |
| `Knowledge\*` (TrendAnalyzer, StrategyLineage, ExplainabilityEngine, RecommendationScorer) | research libraries | ❌ orphaned (no include anywhere) |
| `Production\*` (RecoveryManager, StartupValidator, FaultManager, VersionManager, ConfigManager, MigrationManager, HealthSupervisor, DeploymentVerifier, OperationalEvidence, ...) | hardening libraries | ❌ unwired; `DeploymentVerifier.mqh:7-8,103,123-124` would **not compile** (duplicate include; calls nonexistent `CheckCompatibility`/`ValidateAll`/`GetReport`) |
| `Monitoring\` remainder | health/metrics | ⚠️ partial (EventBus/Health/Metrics/StatisticsReporter wired) |
| `Portfolio\` remainder (AllocationEngine, CapitalAllocator, CorrelationManager, Scheduler) | portfolio libraries | ❌ unwired beyond SymbolContext/PortfolioManager/PortfolioRiskManager |
| `Knowledge\`, `Laboratory\` (see above) | — | ❌ |

**Dependencies**: MQL5 standard library `Trade\Trade.mqh` (`Trading\TradeManager.mqh:4`); single-terminal MT5 6104 binding (origin.txt, PREFLIGHT); Python 3.14 + standard library only for ED01/GR tools (no numpy/pandas — hand-rolled bootstrap).

**State ownership**: broker = source of truth for positions/deals; in-memory contexts rebuild from broker on init; telemetry CSV = only durable decision record; no EA-owned disk state file.

---

## 3. Sprint 25A Carry-Forward

What 25A now guarantees (verified, `docs/Sprint25A_RuntimeIdentity_Validation_Report.md`, G8 status):

- ✅ Build self-identification: `>>> BUILD 25A-RUNTIME-01 tag/term/path` from `TestRunnerEA` (`Tests\TestRunnerEA.mq5:7-9`).
- ✅ Compile-window freshness check (mtime + optional hash change), per-target artifact state captured (`TT01_Validate.ps1` COMPILE).
- ✅ Source-closure hash (recursive `#include` resolution) per compile target.
- ✅ PREFLIGHT: data-folder/origin binding, foreign-data-folder EX5 scan, tester-sandbox scan, canonical binary uniqueness (with `\Tools\` exclusion for harness archives).
- ✅ gates.jsonl per-gate append (abort-resilient) + `Write-TT01Manifest` persisted FIRST in finalize (G8: PSObject-wrapped-string `ConvertTo-Json` hang root-caused and fixed via `[string]` coercion + `ConvertTo-TT01JsonSafe`).
- ✅ Binary archive with SHA256 in every run artifact; frozen baselines (bak/baseCsv/baseMan/ctl) hash-verified across all work.
- ✅ Manifest fields: runId, timestamp, gitHead, overall, allowDelta, expectedRows, allowDecisionIds, gates[], buildIdentity, perf.

What remains weak / absent for research lineage:

| Gap | Evidence | Impact |
|---|---|---|
| **No build identity in telemetry rows** | `TelemetryRow` (`Telemetry\TelemetryTypes.mqh:216-319`) has `configFingerprint`, `eaVersion` (`"v3.0"`, `:63`) but no gitHead/build tag/runId | Research CSVs cannot be tied to the exact commit; pairing uses {signalTime, configFingerprint, symbol, timeframe} (RL-HYP-01 Amendment A2) |
| **Run identity absent from rows** | decisionId is run-local (`TelemetryCollector.mqh:257-258`); filename `telemetry_v5_YYYYMMDD.csv` is the only run discriminator | Cross-run uniqueness requires filename+row pairing; no collision detection |
| **configFingerprint excludes tier** | `OutcomePolicies.mqh:45-46` (tier excluded by design; arm recorded in manifest) | Arm identity must be inferred from external manifest |
| **actualOutcome fields reserved/unused** | `TelemetryTypes.mqh:261-263`; settlement inert (see §4/§5) | Execution truth absent |

**25B-01 conclusion**: build identity is sufficient for the *harness* (TT01 run provenance is airtight post-25A) but **not yet propagable into research artifacts**. Minimal propagation = add a buildIdentity (gitHead/buildTag/runId) block to the telemetry header or an identity row — a schemaVersion-bumping change, NOT authorized now; flagged P1 backlog.

---

## 4. Decision Identity Assessment

### 4.1 Structures representing the same logical decision (duplication inventory)

| Struct | File:line | Identity field | Notes |
|---|---|---|---|
| `TradeCandidate` | `Confluence\SignalTypes.mqh:103-136` | `id` (run-local, `TradeCandidateBuilder.mqh:67`) | created/expired lifecycle, `evidenceIds[20]` |
| `EntryDecision` (legacy) | `Entry\EntryDecisionTypes.mqh:33-50` | `candidateId` | carries filters[12], rationale, createdTime |
| `EntryDecision` (new-mode) | `Entry\EntryOrchestrator.mqh:104` | `candidateId = 0` always | **not linked to any candidate** |
| `ExecutionPlan` | `Entry\ExecutionPlanTypes.mqh:58-79` | `entryDecisionId` (no own plan id) | prices, SL/TP policies, rationale |
| `PositionContext` | `Entry\PositionLifecycleTypes.mqh:15-53` | `entryDecisionId` (parsed from broker comment `SCX-*-P<id>`, `PositionLifecycleManager.mqh:597-609`) | state machine DISCOVERED→…→CLOSED |
| `TelemetryRow` | `Telemetry\TelemetryTypes.mqh:216-319` | `decisionId` (run-local) | durable; `signalTime` + `timestamp` |
| Broker order comment | `Trading\TradeRequestBuilder.mqh:59,65` | `P<id>` = plan.entryDecisionId | only durable cross-restart link |

**Key defects**:
1. **Two decision engines coexist**: legacy (`CEntryDecisionEngine` + gates at `EntryDecisionRules.mqh:22-62`) vs new (`CEntryOrchestrator` + 8 validators). The shadow-comparison exists precisely to compare them (`SymbolContext.mqh:949-978`) — evidence of a **non-canonical decision definition** that is institutionally acknowledged.
2. **New-mode decisions are orphaned** (`candidateId=0`): they cannot be linked to a candidate, plan, or broker comment.
3. **Ticket is never written back into the plan**: `TradeExecutionResult.executionPlanId` set (`TradeManager.mqh:182`) but `ExecutionPlan` has no ticket field; linkage is comment-parse-only.
4. **Two "trade plan" structs**: `EntrySetup` (dormant path, `EntrySetupBuilder.mqh:89-153`) vs `ExecutionPlan` (active) — same logical content (`EntrySetup.mqh:31-60` vs `ExecutionPlanTypes.mqh:58-79`).

### 4.2 Future canonical DecisionRecord (evaluation only)

Required fields (proposal for backlog): `decisionId` (run-scoped: `runId:seq`), `signalTime`, `candidateId`, `direction`, `confidence`, `score`, `firedRuleId/ruleName`, `evidenceIds`, `layer decomposition`, `validators[]`, `entryPrice/SL/TP + policies`, `decisionSource` (LEGACY/NEW), `buildIdentity{gitHead,buildTag}`, `configFingerprint`, `orderId`, `ticket`, `fillPrice/Volume/Time`, `state`.

Ownership: SymbolContext (production of the record), PositionLifecycleManager (terminal states), TelemetryCollector (persistence). Lifecycle: created at decision → filled at plan execution → settled at close. Identity: `runId` (new, from engine init, persisted in telemetry header) + monotonic seq. Backward compatibility: **append-only** columns per frozen schema rule (`TelemetryTypes.mqh:12-19`); a new schemaVersion is required; historical populations must remain parseable (reader already handles v2-v5). Telemetry impact: new columns, header block, or sidecar file. Research impact: enables fill↔decision↔outcome analysis and cross-run lineage.

**25B-02 conclusion**: multiple structures DO represent the same decision today, with broken linkage in NEW mode. A canonical record is justified — but NO CHANGE NOW.

---

## 5. Signal / Execution Boundary

Current chain (verified):

```
MARKET → detectors (Structure\) → TradeCandidate (Confluence\) → EntryDecision (EntryDecisionEngine)
  → ExecutionPlan (ExecutionPlanner) → validation (TradeValidation) → OrderSend (TradeManager)
  → ticket (result only) → PositionContext (lifecycle) → deal history → settlement (inert)
```

Conflations found:

| Conflation | Evidence | Consequence |
|---|---|---|
| **Signal ⇄ Decision** | Legacy `CEntryDecisionEngine` decides AND the new `CEntryOrchestrator` decides for the same bar (`SymbolContext.mqh:895-1047`); shadow rows record both (`decisionMatch/directionMatch`, `TelemetryTypes.mqh:246-247`) | Two authorities; agreement is measured, not enforced |
| **Decision ⇄ Order intent** | `ExecutionPlan` is both the decision output and the order request blueprint (single struct, `ExecutionPlanTypes.mqh:58-79`) | No separation between "what was decided" and "what was sent"; plan has no ticket field |
| **Order intent ⇄ Execution** | `m_executionEnabled` gating is the ONLY difference between collection and execution modes; failed orders are marked submitted, never retried (`TradeManager.mqh:140-207`) | Partial fills / retcode TIME-OUT/CONNECTION are logged and dropped — no re-sync path |
| **Fill ⇄ Settlement** | Actual outcome settlement inert (below) | Execution truth never reaches research |

The one clean separation: **telemetry recording vs order sending are provably mutually exclusive** (LEGACY executes, SHADOW/NEW records) — safe but research-disabling.

**25B-03 conclusion**: the *layering* (detector→candidate→decision→plan→request→send) is well separated at the code level; the *conflation* is at the identity/linkage level (ticket, mode exclusivity, dual engines). Minimum separation for trustworthy execution research: (a) a `PlanState` (INTENT → SUBMITTED → FILLED/PARTIAL/REJECTED) persisted with the plan; (b) ticket written into the plan; (c) a single decision authority per mode. All backlog (P1).

---

## 6. Execution Ledger Assessment

Current event/state facts:

- **No runtime event ledger exists** — event bus is in-memory (`Monitoring\EventBusAdapter.mqh`, `MAX_EVENT_SUBSCRIBERS 16`), positions tracked in-memory (`PositionLifecycleManager`, `MAX_POSITION_CONTEXTS 2048`), close events published but not persisted.
- Durable records: telemetry CSV (append-only, `TelemetryCollector.mqh:147-198`), broker deal history (queried via `HistorySelect` on demand: `PositionLifecycleManager.mqh:617-638`, `Monitoring\StatisticsReporter.mqh:34-61`), terminal journal.
- **No FileFlush anywhere** — rows reach disk only at `FileClose` (buffer full or shutdown) (`TelemetryCollector.mqh:172-190`); 1024-row buffer + single `Shutdown` flush → crash loses up to 1024 rows.
- Duplicate prevention: `m_submittedIds[]` in-memory watermark (`TradeManager.mqh:236-252`) — **lost on restart**.
- Broker reconciliation: none beyond PositionSelect-by-magic discovery on init; no deal-event replay, no partial-fill tracking (TRADE_RETCODE_DONE_PARTIAL is mapped to a string only, `TradeManager.mqh:283`).

Event-model evaluation (backlog): required events: DECISION_CREATED, ORDER_REQUESTED, ORDER_REJECTED(retcode), ORDER_SENT(ticket), DEAL_FILLED(volume/price), POSITION_OPENED, POSITION_MODIFIED(BE/trailing), POSITION_CLOSED(netPL), SETTLEMENT_DONE(outcome). Identity: `runId:seq` monotonic per run; ordering: sequence number + broker timestamp; idempotency: dedup key = decisionId + eventType (fixes restart watermark loss); duplicate prevention: persist last-sent-request id (or order comment as natural key); reconciliation: on init, replay deal history since last known ticket (order comment parse). Restart recovery: ledger replay = the canonical restart mechanism.

**25B-04 conclusion**: an event/state ledger is **required** for the 25B objectives (crash recovery, idempotency, execution truth) — but it is a P1/P2 backlog design, NOT current work. The cheapest durable primitive already exists (append-only CSV pattern in TelemetryCollector).

---

## 7. Restart / Reconciliation Assessment

| Scenario | Reconstructible? | Lost? | Evidence |
|---|---|---|---|
| Terminal restart | Positions (broker), deals (history), telemetry CSV (closed file) | In-memory contexts (rebuilt), `lastBarTime` static (benign), telemetry buffer rows **if crash, not clean deinit** | `TelemetryCollector.mqh:315-327` (flush only on Shutdown); `Engine.mqh:424-437` |
| EA restart | Same as above | Candidate/decision/plan state; `m_submittedIds` watermark → **duplicate-order risk in LEGACY** | `TradeManager.mqh:229-230` (ArrayFree on Shutdown) |
| Reconnect | Terminal handles; EA no reconnect hook | — | no OnTesterDeinit/network handling in EA |
| Partial execution | — | **DONE_PARTIAL never tracked** — no partial-fill state machine | `TradeManager.mqh:283` string-only |
| Open position | ✅ broker state; BE/trailing flags NOT (reset false) | break-even/trailing progress | `PositionLifecycleManager.mqh:229-230` |
| Pending order | Broker-side (terminal), not EA-managed | EA-level pending order logic | PendingOrderInfo exists (`Entry\PendingOrderInfo.mqh`) but execution path is market-only (TRADE_ACTION_DEAL) |
| Incomplete settlement | — | `SettleRemaining` at shutdown marks leftovers UNKNOWN or drops (count logged) | `SymbolContext.mqh:1532-1555` |
| Interrupted journal | Terminal journal is append-only | no EA journal exists | — |
| Duplicate broker event | — | no event dedup | no broker-event subscription anywhere |

Required invariants for restart (backlog): (1) every sent order has a durable intent record before OrderSend; (2) every fill is matched to exactly one intent; (3) BE/trailing state derivable from broker SL/TP (it is — `PositionSelect` reads current stops) — flags are optimizations, not truth; (4) telemetry rows flushed at defined checkpoints (e.g., every N rows or per bar), not only at shutdown.

**25B-05 conclusion**: the system is *reconstructible* for positions and closed outcomes (broker = truth) but *not* for in-flight decisions/orders. For a collection-only research pipeline this is tolerable (rows are the product); for LEGACY live execution it is the #1 restart risk (duplicate orders). Backlog P1/P2.

---

## 8. Invariants

Existing machine-checkable invariants (verified):

| ID | Statement | Where enforced | Where tested | Status |
|---|---|---|---|---|
| INV-01 | decisionId/signalTime/configFingerprint/symbol/timeframe identify a row; all other columns byte-identical to baseline (localization aside) | TT01 BEHAVIOR-REGRESSION | `TT01_Validators.ps1:236-237` | ✅ PASS (Run 5) |
| INV-02 | fresh CONTROL arm byte-identical to frozen CONTROL_RLHYP01_INTEGRITY artifact (determinism) | TT01 INTEGRITY-CONTROL | `TT01_Validators.ps1:649-678` | ✅ PASS (6239 rows) |
| INV-03 | admitted-row byte-identity on shared non-gate columns (settlement isolation) | SETTLEMENT-ISOLATION + ACTIVE-TIER | `TT01_Validators.ps1:582-646,452-518` | ✅ PASS |
| INV-04 | CSV header == frozen schema v5 (78 cols), fingerprint constancy, evidence-column semantics | TELEMETRY-CONTRACT | `TT01_Validators.ps1:88-141` | ✅ PASS |
| INV-05 | contribution = raw·weight/100; layer split; rule/fire consistency; FVG 1970 sentinel | EVIDENCE-REGRESSION | `TT01_Validators.ps1:144-206` | ✅ PASS |
| INV-06 | source closure hash + compile refresh + build-tag window | COMPILE/SUITE identity (25A) | `TT01_Validate.ps1` compile/suite | ✅ PASS |
| INV-07 | baseline perf record is frozen on first run | PERFORMANCE/`baseline.manifest.json` | harness | ✅ |
| INV-08 | configFingerprint constancy across experiment arms | ED01 analyzers (frozen fingerprint constants) | Python protocols | ✅ (arm-level) |

Missing invariants (backlog proposals):

| ID | Statement | Risk if violated |
|---|---|---|
| INV-09 | decisionId unique within a run AND runId unique across runs (runId persisted in telemetry header) | Cross-run pairing misattribution (currently mitigated by {signalTime,fingerprint,symbol,tf} pairing) |
| INV-10 | every buffered telemetry row reaches disk at a checkpoint (no crash window) | Research population incompleteness |
| INV-11 | every executed order has a durable intent; every deal ticket maps to ≤1 decision | Duplicate/revenue misattribution in execution research |
| INV-12 | settle completeness: every row settles or is explicitly censored (UNKNOWN recorded, count in manifest) | Selection bias in outcome studies |
| INV-13 | manifest ↔ telemetry linkage: run artifact manifest references its CSV set | Lineage ambiguity |
| INV-14 | order-send idempotency survives restart (persisted last-request watermark) | Duplicate orders in LEGACY live |

---

## 9. Research Contracts

What exists (machine-readable):

- **Per-experiment manifests (Python)**: `ED01_D_manifest.json`, `ED01_E_manifest.json`, `ED01_RLHYP01_manifest.json` (12/15-run arms, fingerprints, seeds, pairing keys), `.done` markers per arm.
- **TT01 manifest + baseline.manifest.json**: runId/gitHead/gates/perf + freezeId B8 (csvSha256, headerColumns, counters, perfFrozen).
- **MQL5 `CExperimentManifest`** (`Optimization\ExperimentManifest.mqh:8-31`): experimentId, platformVersion, parameterSetId, datasetId, walkForwardWindows, randomSeed, timestamps — **only used by CalibrationRunner**.
- **MQL5 `LaboratoryManifest`**: zero consumers.
- **Pairing keys**: ED01_D pairs by `decisionId` (canonical) (`ED01_D_Analyze.py`), RL-HYP-01 pairs by {signalTime, configFingerprint, symbol, timeframe} (Amendment A2), ED01-A/B/C use frozen fingerprint constants.
- **Seeds**: fixed per experiment (20260809…20260811/20260813) → reproducibility.

Conceptual-field coverage (25B-07 list): research_id ✅(manifest), hypothesis ✅(protocol docs), baseline ✅(B8 frozen), population ✅(per-arm CSVs), estimand ✅(ED01 per-experiment definitions), sample ✅(arms), metrics ✅(mean R, CIs), thresholds ✅(protocol floors), seed ✅, OOS window ⚠️(ED01 6mo artifacts are calendar-windowed; no explicit train/test split — walk-forward library exists but unwired), controls ✅(CONTROL arms), decision ladder ✅(ED01_C `decision ladder :28-35`), build identity ⚠️(manifest-level only, not per-row), experiment identity ✅, artifact identity ✅(fingerprint+manifest).

**Missing**: a **unified experiment registry** (family → experiments → artifacts → thresholds → verdicts chain); build identity at row level; OOS discipline enforced by the harness rather than by protocol text.

## 10. Research Lineage

Trace map:

```
Hypothesis (protocol md) → Pre-registration (protocol + manifest, fixed seeds, frozen fingerprints)
  → Code (commit 1e6aa5f; TT01 SUITE 2738 tests + COMPILE gates)
  → Build (25A buildLine tag/term/path + source-closure hash + binary archive)
  → Experiment (ED01/EN03 batch runners; .done markers; arm CSVs)
  → Results (analyzer JSON + reports)
  → Audit (selfcheck modes, TT01 INTEGRITY/CONTRACT, golden-reference GR02)
  → Decision (Decision/Closure md documents, e.g., Sprint22_RL_HYP_01_Decision.md)
```

What already exists: the full manual chain works and is documented; RL-HYP-01 is the flagship example (12-run manifest, pairing review `Sprint22_Pairing_Identity_Review.md`, adversarial reviews, Bonferroni sensitivity).

What is missing: (1) the chain is **document-driven** — the only machine-readable artifacts are manifests and JSONs; there is no machine-checkable lineage graph; (2) **no registry** linking families (GR01 funnel → ED01 experiments → decisions); (3) build identity stops at the harness manifest; (4) `Knowledge\StrategyLineage.mqh`/`Laboratory\KnowledgeGraph.mqh` are unwired in-memory stubs.

**25B-07/08 conclusion**: lineage discipline is strong at the *protocol* level and weak at the *machinery* level. A registry + row-level build identity are the two highest-value P2 backlog items.

## 11. Robustness Infrastructure

| Capability | Status | Evidence |
|---|---|---|
| Walk-forward | PARTIAL (library, unwired) | `Validation\WalkForwardPipeline.mqh`, `Optimization\WalkForwardRunner.mqh` — no tester execution loop; init-only tests (`Tests\integration\TestValidationLab.mqh:15-47`) |
| Parameter perturbation / sensitivity | UNTRUSTWORTHY (heuristic, no re-execution) | `Optimization\RobustnessTester.mqh:37-47` — hardcoded per-name factors, no actual parameter sweep |
| Execution stress (spread/slippage/partials) | MISSING | no spread/slippage injection anywhere; partial fills string-only |
| Population stability | EXISTS (determinism + baseline) | INTEGRITY-CONTROL byte-identity, BEHAVIOR-REGRESSION |
| MAE/MFE | MISSING | not in telemetry schema (only entry/exit prices) |
| Monte Carlo | PARTIAL (order-shuffle only) | `Validation\MonteCarloSimulator.mqh` (PERTURB_TRADE_ORDER, MathRand); `MonteCarloPipeline.ExtractTrades` is a stub (`:25-37`); tests/benchmarks only |
| Sensitivity analysis | UNTRUSTWORTHY | heuristic above; no CI/perturbation machinery |
| Multiple testing / FWER / FDR | PARTIAL (Python only) | Bonferroni sensitivity CIs in `ED01_E_Supplement.py:6-7,42` and `ED01_RLHYP01_Analyze.py` (98.33%); **none in MQL5** (`docs\Sprint18_Research\13_Statistical_Validation.md:139-140` explicitly: "No multiple-comparison correction anywhere"; p-value formula is an approximation `:155`) |
| Experiment-family lineage | PARTIAL (document-driven) | GR01/GR02 funnels; no registry |

Bootstrap: EXISTS in Python (day-stratified paired, 10k iters, seeds). Statistical tests: day-stratified paired bootstrap is the workhorse — statistically sound and consistently applied.

**25B-08 conclusion**: the *used* toolchain (Python) is trustworthy; the *library* toolchain (MQL5) is largely unwired or untrustworthy. Priorities: wire MAE/MFE + row-level build identity (P2); DO NOT build MQL5 multiple-testing machinery — extend the proven Python discipline (P2/P3).

## 12. AI Research Governance

Current AI interaction surface:

- Repository on GitHub (`sktharunbalaji13-cmd/SuperCents_X`), local working copy in the MT5 data folder; agents (DeepSeek via opencode, Cline, OmniRoute) operate on the local tree with full write capability; `.opencode\` config exists; `Tools\SprintRoadmap\` is a local roadmap viewer (Vite app).
- Change control today = human-in-the-loop: explicit authorization prompts, review gates, frozen baselines with hashes, TT01 17-gate validation, commit/push authorization separate from implementation.
- **No AGENTS.md** exists; no read-only agent workflow; no experiment registry that agents could query.

Proposed minimum governance boundary (backlog):

1. **Authority classes**: READ/ANALYZE/PROPOSE (default-allowed for agents); MODIFY-MAIN, DEPLOY, TRADE, OPTIMIZE, CHANGE-FROZEN-BASELINE, COMMIT/PUSH (explicitly gated — as today).
2. **Agent workflow**: read-only clone/sandbox for analysis; proposals as markdown artifacts in `docs\` + PR/branch; no agent may run OrderSend-enabled modes; TT01 must run green before any merge to main; frozen baseline hash set verified pre/post any change.
3. **Interaction points**: repository (read: code/docs/manifests; write: proposals only), research contracts (machine-readable manifests), experiment registry (P2 — read by agents), MT5 tester (sandboxed runs via TT01-style launchers, terminal bound to origin.txt), telemetry (read-only CSV analysis), statistical pipeline (Python tools, read-only), audit layer (TT01 gates + selfcheck modes).
4. **Enforcement mechanics** (proposal, P3): AGENTS.md with the authority matrix; CI-style pre-push checks (hash verification + TT01 skip-run) — today this is a human step.

**25B-09 conclusion**: governance is currently *procedural* (prompt-based) and effective; the minimum future requirement is a **machine-readable authority matrix + registry** so agents can self-verify scope. No code change authorized.

## 13. Risk Register

| # | Risk | Severity | Current mitigation | Gap |
|---|---|---|---|---|
| R1 | Telemetry rows lost on crash (1024-row buffer, no FileFlush) | High (research population) | Shutdown flush; single-run scripts end cleanly | Crash during long runs |
| R2 | Duplicate order on restart (watermark in-memory) | High (LEGACY live) | Execution only in LEGACY; collection-only today | No persisted intent |
| R3 | Execution truth absent (settlement inert; NEW-mode decisions orphaned, candidateId=0) | High (research goal) | Shadow/new collection is honest about simulation | Blocks outcome research |
| R4 | Fill/ticket never linked to decision (comment-parse only) | Medium | `SCX-*-P<id>` comment | No ticket field on plan |
| R5 | Build identity not in research rows | Medium | Filename date + fingerprint + manifest | No commit/build tag per row |
| R6 | MQL5 statistical functions approximate/unwired | Medium | Python toolchain authoritative | Misuse risk if library ever wired naively |
| R7 | Dormant code can rot silently (Production\DeploymentVerifier does not compile; Knowledge\ orphaned) | Low | Unwired, uncompiled | Confusion; compile drift |
| R8 | Dual decision engines diverge | Medium | Shadow comparison + BEHAVIOR-REGRESSION identity gate | No canonical authority |
| R9 | Partial fills / retcode DONE_PARTIAL ignored | Medium (future live) | — | No partial state machine |
| R10 | Pending-order path unused (market-only) | Low | — | Feature gap, not defect |

## 14. Priority Matrix

| ID | Item | Priority | Justification |
|---|---|---|---|
| B25-01 | Telemetry row/header build identity + runId (schema-append) | P1 | Unambiguous research lineage; append-only, backward compatible; **requires schemaVersion bump + migration per frozen rule** |
| B25-02 | Durable telemetry checkpoint flush (FileFlush policy / periodic flush) | P1 | Closes R1 without schema change |
| B25-03 | Decision↔fill linkage: ticket field on ExecutionPlan + persist intent before OrderSend | P1 | Execution truth; closes R2/R4 |
| B25-04 | Run-scoped decision identity (runId:seq) + manifest↔CSV linkage | P2 | Research population integrity (INV-09/13) |
| B25-05 | Restart idempotency: persisted last-request watermark | P2 | R2 (live safety) |
| B25-06 | Settle-completeness census (settled/censored counts in manifest) | P2 | INV-12; selection-bias control |
| B25-07 | Experiment-family registry (machine-readable) | P2 | Lineage + AI-readiness (25B-07) |
| B25-08 | MAE/MFE + execution-quality columns (append-only) | P2 | Robustness gaps (25B-08) |
| B25-09 | No-change catalog (see §16) | — | Discipline |
| B25-10 | AGENTS.md authority matrix + read-only agent workflow | P3 | AI governance (25B-09) |
| B25-11 | Wire/repair Production\DeploymentVerifier or delete (compile-clean tree) | P3 | R7 hygiene |
| B25-12 | Unified OOS/walk-forward enforcement for experiments | P3 | Library exists; protocol enforcement |
| B25-13 | MQL5 statistical upgrades (exact tests, MCP) | P3 | Not justified while Python is authoritative (§16) |

P0: **none found within the assessed scope** that blocks the current collection-only research posture. (If LEGACY live execution were ever activated, B25-03/B25-05 become P0.)

## 15. Recommended 25B Implementation Backlog

Backlog items are proposals requiring explicit senior authorization per item. Suggested order for 25B implementation (NOT authorized yet):

1. **B25-01 build identity in telemetry** (schemaVersion 6, append-only; header block or row columns: gitHeadShort, buildTag, runId; writer + reader + TT01 CONTRACT extension + ED01 analyzers updated to verify).
2. **B25-02 flush checkpoint** (flush every N rows or per bar; no schema change).
3. **B25-04 run-scoped decisionId** (runId persisted in CSV header; decisionId = run-local seq unchanged, runId disambiguates; analyzer pairing keys extended).
4. **B25-06 settle census** (manifest field: settled/censored/unknown counts; analyzer cross-check).
5. **B25-03 intent-before-send + ticket linkage** (ExecutionPlan ticket field; `SCX-*-P<id>` unchanged; TradeExecutionResult → plan write-back).
6. **B25-07 registry** (JSON registry under Tools/ or docs/: family → experiments → artifacts → verdicts; GR01/GR02/ED01 scripts emit/update entries).
7. **B25-05 restart watermark** (persist last-sent request id in a small sidecar file — pattern reuse from gates.jsonl).
8. **B25-10 governance docs** (AGENTS.md authority matrix).

Each item carries its own design doc + protocol + TT01/ED01 validation plan before implementation.

## 16. Explicit No-Change Recommendations

Per the research rule — items with NO evidence justifying change, or where the cost/risk exceeds the benefit:

1. **MQL5 statistical/multiple-testing machinery (StatisticalValidator p-value, Bonferroni in MQL5)** — NO CHANGE JUSTIFIED. The Python toolchain is the authoritative, protocol-frozen statistical layer (bootstrap + Bonferroni, `ED01_*_Analyze.py`); duplicating it in MQL5 adds compile-surface risk (R6) with zero evidence of benefit.
2. **Rewriting/removing the dormant EntrySetup path or Knowledge\ tree** — NO CHANGE JUSTIFIED. Removal risks disturbing the frozen legacy behavior surface; dormancy is documented. (Compile-hygiene only if a gate ever fails.)
3. **Activating `Risk\RiskManager.mqh` full engine or Production\ hardening libraries** — NO CHANGE JUSTIFIED. Live risk is currently governed by PortfolioRiskManager + providers; activating dead code without a live-trading requirement adds risk.
4. **Retry-on-failure for OrderSend** — NO CHANGE JUSTIFIED in collection mode (orders are not sent); if LEGACY live is ever enabled, revisit with the restart-idempotency work (B25-05) FIRST.
5. **Pending orders / partial-fill state machine** — NO CHANGE JUSTIFIED until execution research (B25-03) demonstrates a need; market-only flow matches current research design.
6. **Monte Carlo pipeline completion** — NO CHANGE JUSTIFIED: `ExtractTrades` stub means no real P&L input exists; building it before B25-03 (execution truth) would be speculative.
7. **Any change to frozen baselines, telemetry identity semantics, TT01 gate semantics, Sprint 22/24/25A behavior** — FORBIDDEN by scope and by STOP CONDITIONS. No STOP trigger was hit during this assessment (no baseline/identity/historical-population change was required to produce it).

## 17. Dependencies

- MQL5 compiler (MetaEditor 6104, single install bound by origin.txt) — required for any EA-side backlog item.
- MT5 terminal (6104) — TT01 replay/run validation.
- Python 3.14 (stdlib only) — ED01/GR analyzers; no external packages (deliberate).
- Terminal `Common\Files\Telemetry\` CSV stream — input to all research tooling.
- Frozen artifacts: `Tests\TestRunnerEA.ex5.bak20260812_194614`, `Tools\TT01\baseline\*`, `Tools\ED01\artifacts_*\**` CONTROL sets — MUST remain byte-identical; any backlog item must re-verify hashes pre/post.
- Git/GitHub `main` (1e6aa5f) — baseline for any future branch.
- Backlog item dependencies: B25-01 blocks B25-04 (row identity); B25-03 blocks B25-05 (intent); B25-07 depends on B25-01/04 (registry keys on run identity); B25-10 is independent.

## 18. Validation Strategy (for future implementation, per item)

Every backlog item, when authorized, must follow the 25A discipline:

1. **Protocol doc** (fields, compatibility, thresholds) reviewed before code.
2. **Implementation** with frozen-schema rules honored (append-only; new schemaVersion; old readers keep working).
3. **TT01 full run** (17 gates) — CONTRACT/EVIDENCE/BEHAVIOR gates extended where schema changes; INTEGRITY-CONTROL guards determinism.
4. **ED01-style analysis** on a controlled arm pair (CONTROL vs feature) with fixed seed + fingerprint + bootstrap CI.
5. **Backward-compatibility check**: historical CSV sets (v3/v4/v5, Sprint17/ED01/RL-HYP-01 artifacts) must still parse.
6. **Baseline hash verification** pre/post; artifacts retained in `Tools\25B\`.
7. **G9 discipline**: no-weakening proof (genuine failures stay genuine).
8. **Senior review + explicit authorization + separate commit/push gates** (as Sprint 24/25A).

## 19. No-Touch List

- `Tests\TestRunnerEA.ex5.bak20260812_194614` and all frozen baseline artifacts (hash-protected).
- `Tools\TT01\baseline\*` (telemetry_v4_20260130.csv, baseline.manifest.json, allow-lists, funnel_*).
- `Tools\ED01\artifacts_*\**` (CONTROL/INTEGRITY/K1P*/K1P5/K2P0 evidence populations).
- `Tools\TT01\run\gates.jsonl` (Run-5 17/17 record) and `Tools\TT01\artifacts\TT01_20260814_235134\` (run-5 evidence; manifest stays absent).
- Telemetry schema semantics (frozen columns, header contract), configFingerprint definition, TT01 gate thresholds, ED01 frozen fingerprints/seeds, pairing keys (A1/A2).
- EN-01/EN-02/EN-03 commits, Sprint 25A commit `1e6aa5f`, history (no amend/rewrite).
- Research conclusions (Sprint 22/23/24 decisions) — nothing in this assessment requires reinterpretation.

## 20. Authorization Request

Per senior decision flow, the next step is:

**REQUEST**: Authorization for Sprint 25B implementation of the backlog **starting with B25-01 (build identity in telemetry rows) + B25-02 (flush checkpoint)** — the two P1 items that directly serve "safe execution truth" and "auditable research experiments" with zero behavioral impact on decision generation, execution, or settlement semantics (telemetry-only, append-only, backward compatible), each with its own protocol doc and TT01/ED01 validation as per §18.

All other backlog items (B25-03..B25-10) remain gated behind individual senior authorizations in sequence. No commit/push until separately authorized. Sprint 25C remains unauthorized.

---

SPRINT 25B STATUS: **ASSESSMENT COMPLETE / IMPLEMENTATION NOT AUTHORIZED**

P0 blockers: none within the assessed (collection-only) scope. If LEGACY live execution is ever enabled, decision↔fill linkage and restart order-idempotency become P0 — flagged, not implemented.

P1 priorities: B25-01 build identity + runId in telemetry; B25-02 durable flush checkpoint; B25-03 decision↔fill intent/ticket linkage.

P2 research requirements: B25-04 run-scoped decision identity + manifest↔CSV linkage; B25-05 restart idempotency; B25-06 settle census; B25-07 experiment-family registry; B25-08 MAE/MFE + execution-quality columns.

P3 future AI capabilities: B25-10 AGENTS.md authority matrix + read-only agent workflow; B25-11 compile-clean tree hygiene; B25-12 OOS enforcement; B25-13 MQL5 statistical upgrades (only if Python layer is ever superseded).

RECOMMENDED NEXT PHASE: 25B implementation of B25-01+B25-02 (telemetry identity + durability), then 25B-03 (execution truth linkage), each protocol-first and TT01/ED01-validated.

IMPLEMENTATION SCOPE: telemetry writer/reader append-only extensions; harness CONTRACT extension; analyzer fingerprint verification; flush policy; ExecutionPlan/ExecutionResult linkage fields — all additive, frozen-schema compliant.

REQUIRED VALIDATION: TT01 17-gate run; INTEGRITY-CONTROL determinism; ED01 controlled-pair analysis; historical CSV parse-back test; baseline hash pre/post; G9 no-weakening proof.

RISKS: schema migration risk mitigated by append-only rule + reader versioning; behavior drift prevented by 25A identity gates; population continuity preserved by backward-compatible readers.

EXPLICIT AUTHORIZATION REQUEST: Senior authorization to begin Sprint 25B implementation with B25-01 + B25-02. No commit/push without separate authorization. Sprint 25C: NOT AUTHORIZED.

STOP — assessment complete; no code modified, no commit, no push.
