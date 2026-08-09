# Sprint 18 — Deep Research Program

Status: **COMPLETE** (2026-08-02). 15/15 sub-sprints delivered, one
commit each (`docs: sprint18.0` … `docs: sprint18.15`). The program's
headline findings, measured evidence and the consolidated Master
Experiment Backlog for Sprint 19 are in `15_Synthesis_Backlog.md`
(F1-F6 findings; M01-M53 cards; M01-M04 protocol gates all others).
(Sprint 17 closed: `v3.0-research-baseline`, dataset frozen)

This is not a feature sprint. Sprint 18 is a **research program** that produces the
scientific foundation for every future architectural decision. It converts a six-month
empirical baseline (`Evidence/Sprint17/`, fingerprint `2e74bbae…`) into an evidence-backed
experiment portfolio for Sprint 19.

Sequencing (locked):

```
Research → Evidence → Experiment → Implementation
```

not

```
Idea → Code → Backtest
```

## 0. Charter and constraints

- **No production code changes. No implementation. No tuning. No test changes.**
  No harness INI changes. No calibration runs. No telemetry writes.
  No new evidence collection (the Sprint 17 dataset is frozen; nothing new is collected).
- Allowed: web research, read-only code analysis (with `file:line` citations),
  read-only Python analysis over the frozen dataset, and Markdown documents
  under `docs/Sprint18_Research/`.
- Every Sprint 19 change must pass the four-evidence filter:
  **Literature → Implementation Survey → SuperCents_X → Sprint 17 Evidence.**
- Each document (18.1–18.14) is a standalone domain reference: a mini survey paper
  on its topic with the EA reviewed only at the end.
- 18.15 merges the program into the official **Experiment Backlog** for Sprint 19.

## 1. Sprint map (locked)

| Sprint | Topic | Subsystem | Doc file |
|--------|-------|-----------|----------|
| 18.1 | Swing Detection & Market Structure | `Structure/SwingDetector.mqh`, `StructuralPivotEngine.mqh`, `ProtectedPointManager.mqh`, `TrendState.mqh`, `PPTelemetry.mqh` | `01_Swing_Detection.md` |
| 18.2 | Break of Structure (BOS) | `Structure/BOSDetector.mqh` | `02_BOS_Research.md` |
| 18.3 | Change of Character (CHOCH / MSS) | `Structure/CHOCHDetector.mqh` | `03_CHOCH_MSS.md` |
| 18.4 | Liquidity | `Structure/LiquidityDetector.mqh` | `04_Liquidity.md` |
| 18.5 | Order Blocks | `Structure/OrderBlockDetector.mqh` | `05_Order_Blocks.md` |
| 18.6 | Fair Value Gaps | `Structure/FVGDetector.mqh` | `06_Fair_Value_Gaps.md` |
| 18.7 | Confluence | `Confluence/` (Engine, ScoreCalculator, 6 evaluators) | `07_Confluence.md` |
| 18.8 | Confidence Architecture Review | `Research/ConfidenceCalibrator.mqh`, Calibration modes, v3 schema | `08_Confidence_Architecture.md` |
| 18.9 | Entry Logic | `Entry/` (DecisionEngine, Orchestrator, ExecutionPlanner, Validators, EntryConfig) | `09_Entry.md` |
| 18.10 | Exit Strategy | `Entry/PositionLifecycleManager.mqh` | `10_Exit.md` |
| 18.11 | Risk & Portfolio Management | `Risk/PositionSizer.mqh`, `Portfolio/` | `11_Risk_Portfolio.md` |
| 18.12 | Market Regimes & News Filtering | `Structure/TrendState.mqh`, `Research/RobustnessProfiler.mqh`, BenchmarkFramework, `Entry/Validators/SessionValidator.mqh` | `12_Regimes_News.md` |
| 18.13 | Statistical Validation | `Validation/` (WalkForwardScheduler, MonteCarloSimulator), `Optimization/RobustnessTester.mqh` | `13_Statistical_Validation.md` |
| 18.14 | AI / Machine Learning Readiness | (greenfield; adjacent `Knowledge/`, `Laboratory/`, `Calibration/`) | `14_AI_ML.md` |
| 18.15 | Research Synthesis & Experiment Backlog | — | `15_Synthesis_Backlog.md` |

## 2. Mandatory 8-phase methodology (every 18.1–18.14)

Phase weights reflect effort, not page counts. Phase 1 dominates (~80%).

| Phase | Name | Contents |
|-------|------|----------|
| 1 | Foundation | What the concept *is*: origin, definition, historical evolution, mathematical interpretation, why it exists. No EA discussion. |
| 2 | Academic Literature | Peer-reviewed work on the *underlying phenomenon*, not only the trading vocabulary: market microstructure, trend continuation, breakout validation, structural breaks, swing identification, pattern reliability, change point detection, regime shift, structural break tests, volatility-adjusted pivots, Bayesian trend change. |
| 3 | Professional Trading Literature | Books/authors giving operational definitions: Al Brooks, Tom Williams, Wyckoff, ICT, Linda Raschke, Adam Grimes, trading journals. |
| 4 | Institutional / Quantitative Methods | How professional firms solve the same problem mathematically, possibly under different terminology. |
| 5 | Open-source Implementations | TradingView scripts, MT5, Python, QuantConnect, Backtrader, vectorbt. Compare algorithms, not only outputs. |
| 6 | Current SuperCents_X | Read-only code review: current algorithm, strengths, weaknesses, missing concepts, simplifications, possible improvements. Facts only, `file:line` citations. |
| 7 | Sprint 17 Evidence Review | Measured only. Read-only Python over the frozen dataset. Explicitly state when the dataset **cannot** measure a claim. |
| 8 | Experiment Backlog | Experiments only, no implementation. Every card traceable across the evidence sources (format in §4) with Evidence Strength (I–V) and Implementation Confidence (A–F). |

Sources for Phases 1–5: peer-reviewed papers, quantitative finance research, market
microstructure research, ICT concepts, Smart Money Concepts literature, Wyckoff
methodology, Al Brooks price action, professional trading articles, bank/prop-firm
whitepapers (where public), and modern open-source implementations.

## 3. Scoring scales (locked)

### 3.1 Evidence Strength (research quality — separates quality from priority)

| Level | Meaning |
|-------|---------|
| I | Meta-analysis or multiple peer-reviewed studies **+** Sprint 17 evidence agree |
| II | Multiple independent studies |
| III | One strong paper or strong practitioner consensus |
| IV | Practitioner observations only |
| V | Speculative hypothesis |

### 3.2 Implementation Confidence (Sprint 19 priority)

| Grade | Meaning |
|-------|---------|
| A | Strong literature support + industry practice + Sprint 17 evidence agree |
| B | Good literature support + partial empirical support |
| C | Promising hypothesis but insufficient evidence |
| D | Speculative; collect more evidence first |
| F | Reject |

### 3.3 Sprint 19 rule (locked)

- Implement **A and B** experiments first.
- **C** stays in the backlog pending more evidence.
- **D / F** are not implemented.

## 4. Recommendation traceability format (Phase 8 cards)

Every experiment card states all four evidence sources explicitly, e.g.:

- **Literature:** multi-candle BOS confirmation reduces false breaks
- **Implementation Survey:** mature open-source implementations require close confirmation
- **SuperCents_X:** `BOS_LOOKBACK_BARS=2`, single-bar confirmation
- **Sprint 17 Evidence:** [measured %, or "the current dataset cannot measure this"]
- **Experiment:** optional multi-candle confirmation, evaluated against the frozen baseline
- **Evidence Strength:** II · **Confidence:** B · **Priority:** P1

## 5. Frozen baseline (cite from this table, never re-measure)

Source of truth: `Evidence/Sprint17/README.md` (immutable).

- Dataset fingerprint: `2e74bbae642afda5cfe073d3fa8cdd49fdfb4c7b24c40f9b223e34f7b0db8b90`
- 19 canonical CSVs, 18,686 rows, schema v3 (68 columns: 45 frozen v2 + 23 evidence),
  quoted packed `ruleEvidenceIds`, tristate evidence states.

| Run | Symbol | TF | Files | Rows | Decided | Win | Loss | BE | Unknown | Evidence combos |
|-----|--------|----|------:|------:|--------:|----:|-----:|---:|--------:|----------------:|
| 1 | EURUSD | M15 | 13 | 12,467 | 12,417 | 4,089 | 8,323 | 5 | 50 | 1,406 |
| 2 | EURUSD | H1 | 3 | 3,103 | 3,053 | 1,004 | 2,049 | 0 | 50 | 374 |
| 3 | GBPJPY | H1 | 3 | 3,116 | 3,066 | 1,037 | 2,029 | 0 | 50 | 388 |

- Gates: Schema Health 100/100 (all scopes); Structural PASS (gaps 0.0000%, all sections);
  conservation PASS; 0 duplicates on `(configFingerprint, symbol, timeframe, signalTime, firedRuleId)`.
- Spearman confidence–outcome: M15 0.2081, H1 0.2181, GBPJPY 0.2358 (50 unresolved rows per run excluded).
- Config fingerprints (decimal / hex): M15 `2098382509486611519 / 1D1EF3C650D79C3F`;
  H1 `17300017028236539594 / F01601D3E83F76CA`; GBPJPY `8838775532884979052 / 7AA9A3846F05ED6C`.
- Environment freeze: Win11 Home SL Build 26200, Ryzen 7 7840HS (8 cores), MT5 5.0.0.6090
  (agent 6090), MetaQuotes-Demo login 5051328028, Tick Model 4, deposit 10,000 GBP, leverage 200,
  EA SuperCents_X v3.0, `EntryMode=2` (ENTRY_MODE_NEW, execution gated off).

## 6. Data-measurement constraints (Phase 7)

- CSVs are **UTF-16**; parse with `encoding='utf-16'` and the `csv` module
  (`ruleEvidenceIds` is quoted).
- Analysis scripts are read-only; baseline helper: `Temp/baseline_query.py` (or per-topic scripts);
  outputs quoted into docs with the dataset fingerprint.
- The dataset is **signal-level telemetry** (0 orders placed): it can measure evidence
  frequency, rule mixes, layer activations, confidence distributions, and signal–outcome
  relations, but **cannot** measure order-level behaviors (slippage, partial fills, exit
  timing). When a claim is not measurable, the doc must say so (that itself becomes a
  telemetry gap → potential schema v4 need, recorded in 18.15).

## 7. Deliverables and commit conventions

- All docs: `docs/Sprint18_Research/` (16 files: `00_Program_Overview.md` +
  `01`…`15`).
- One commit per sub-sprint: `docs: sprint18.0` … `docs: sprint18.15`.
  Stage only `docs/Sprint18_Research/` (the repo working tree carries unrelated
  artifacts — never `git add -A`).
- Document length: **minimum depth, not a target**. 30–60 pages is the floor for the
  Phase 1 knowledge document; a topic may legitimately require more.
- 18.15 additionally fixes `Evidence/Sprint17/README.md` line 4: "Future collections
  go to `Sprint18/`" must point to a non-research name (e.g., `Sprint19/`), since
  Sprint 18 is research-only and `Evidence/Sprint18/` must not be created.

## 8. Review inputs to build on

- Frozen specs: `docs/Sprint11_FVG_Completion.md` (FROZEN), `docs/Sprint12_Liquidity_Plan.md`
- Calibration history: `docs/Sprint14_Calibration.md`, `docs/Sprint15_3_CalibrationResults.md`
  (replay confidence caps ≈ 0.64; 0.40–0.60 usable range), `docs/Sprint16_1_Measurement.md`
  (ECE 0.1265, Brier 0.2425), `docs/Sprint16_1B_StructuralDiagnostics.md`,
  `docs/Sprint16_2_CalibrationModels.md` (all transforms failed in-sample)
- v3 schema + gate commitments: `docs/Sprint17_SchemaV3_Design.md` (§6 protocol, §8 evidence
  columns — the official **Confidence Architecture Review** is 18.8, closing that commitment),
  `docs/SchemaHealthGate.md`, `docs/Sprint17_Closeout.md`
- Validation infrastructure: `docs/ValidationLab.md`, `docs/ValidationLabVersioning.md`
- Historical forensics (SmartMoneyEA_X lineage): SPRINT_4.4 (SPH-zero bug), 4.9 (BOS audit),
  5.1.7 (Model A chronology), 5.1.10–5.1.12 (333-event forensics), 5.2 (OB plan)
- Test suites: 872/872 (17.7A), 755/755 (17)
- Known gaps verified in planning (each gets a dedicated review): no news filter (18.12),
  no Kelly sizing (18.11), no volatility-adjusted sizing (18.11), no ranging/volatility
  regime detection (18.12), no AI/ML (18.14)
