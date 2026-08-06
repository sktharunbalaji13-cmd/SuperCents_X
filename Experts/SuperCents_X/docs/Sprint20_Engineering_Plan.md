# Sprint 20 — Platform Engineering Plan

| Field | Value |
|---|---|
| Document | `docs/Sprint20_Engineering_Plan.md` |
| Sprint | 20 — **Platform Engineering** (not strategy engineering) |
| Frozen reference | AVP Verification Baseline v1.0 (commit `7792ac0`, docs 00–09) |
| Philosophy | Every task must (1) improve measurement, (2) fix correctness, or (3) expose previously hidden information. **Nothing tries to improve profitability directly.** |
| Status | Approved (user review 2026-08-03); execution begins at TC01 |

## 0. Trace-chain covenant

Nothing in Sprint 20 exists without a trace back through:

```
Engineering Task → AVP Finding (doc 08 S9 cell / ledger ID) → Sprint 17 Evidence → Sprint 18 Research
```

Verified in the frozen corpus: `09_Verification_Baseline_v1.0.md` §6 (traceability index) and `08_CrossSystem_Synthesis.md` S9 (matrix).

## 1. Scope lock

| Category | Sprint | Content |
|---|---|---|
| **Platform Engineering** | 20 | TC, TT, DD, LC, GR, VF epics + ED M-cards already listed in doc 08 S4 #7 |
| **Strategy Research** | 21 | R01 swing significance, R02 MSS/displacement confirmation, R04 GBPJPY H1 replication, new detector variants, displacement experiments, new statistical hypotheses |

Research and engineering stay separated; engineering stays separated from optimization (Sprint 22).

## 2. Engineering principles

Every Sprint 20 task must satisfy **at least one** of:

| Principle | Description |
|---|---|
| **Measure** | Makes the EA observable (telemetry, metrics, serialization) |
| **Correct** | Fixes incorrect or incomplete logic verified by AVP |
| **Stabilize** | Improves lifecycle / reset / state consistency |
| **Trace** | Improves reproducibility or traceability |
| **Validate** | Adds tests or verification |
| **Never Guess** | No tuning without evidence |

Reviewer's test: if a task satisfies none of these, it does not belong in Sprint 20.

## 3. Definition of Done

A Sprint 20 task is complete **only if** all apply:

- [ ] Implementation completed
- [ ] Unit tests added / updated
- [ ] Existing test suite passes
- [ ] Telemetry verified (if applicable)
- [ ] AVP finding resolved (ledger row annotated `RESOLVED — <task id>`)
- [ ] Changelog updated
- [ ] Traceability preserved (commit message: task ID + AVP ref)
- [ ] No regression introduced

## 4. Sprint 20 roadmap with milestones

```
TC Epic (TC01→TC04)
   ↓
M1 — Telemetry Complete          ← gates TT and everything after
   ↓
TT Epic (TT01)
   ↓
DD Epic (DD01→DD05)
   ↓
LC Epic (LC01→LC03)
   ↓
M2 — Platform Stable             ← gates GR01
   ↓
GR Epic (GR01, GR02)
   ↓
VF Epic (VF01, VF02)
   ↓
M3 — Measurement Ready           ← gates ED
   ↓
ED Epic (ED01→ED06)
```

### M1 — Telemetry Complete (after TC01–TC04)

| Requirement | Check |
|---|---|
| All raw fields populated (`*Raw/Weight/Contribution` non-const, unique > 1 over a backtest) | TC02 |
| All layer fields populated (incl. new `layerOrderBlock`, `layerFVG`) | TC01 |
| All classifiers serialized (FVG class, liquidity classification, gap timestamps) | TC03/TC04 |
| Round-trip parser verified (CSV → struct → CSV) | TC01 |
| Schema Health PASS (`TelemetryHealthReport` clean) | TC01/TC02 |
| Structural diagnostics rerun (hasProtectedPoint TRUE appears; family splits reproduce AVP numbers) | TC03 |
| **New telemetry freeze created** (schema v3.1 dataset = evidence baseline for all later comparisons) | TC01 |

**Only after M1 may DD01 begin.** Engineering must not build on partially instrumented data.

**M1 achieved 2026-08-05 (TC04):** all 75 schema v3.1 columns populated from live detection; 1053/1053 suite; real-run behavioral deltas across TC02→TC03→TC04 each limited to the newly instrumented columns (nil / 1 / 4 of 75). **TT01 shipped 2026-08-05** (Platform Validation Harness — one command validates compile/suite/replay/telemetry/evidence/behavior/perf against the frozen B4 baseline; first run PASS). Next: DD01–DD05 (each finishes with `Run TT01 → PASS → Commit`).

### M2 — Platform Stable (after LC01–LC03)

| Requirement | Check |
|---|---|
| Lifecycle resets verified (per-detector reset tests) | LC01 |
| Reload verified (time-discontinuity / history reload) | LC01 |
| Shrink verified (`rates_total` shrink without time reversal) | LC02 |
| No cursor desync (downstream consumers re-sync) | LC03 |
| Regression suite green (TT01) | TT01 |

**Only after M2 may GR01 begin** — routing must not be measured on an unstable platform.

### M3 — Measurement Ready (before ED01)

| Requirement | Check |
|---|---|
| Funnel metrics working (firedRuleId → admitted → entered → filled) | GR02 |
| Every family observable (layers + flags per family) | M1 held |
| Every family measurable (admission rates per family) | GR01 |
| Confidence measurable (per-family confidence distributions) | TC02 |
| Telemetry complete (M1 still holds) | — |

**Only after M3 may ED01–ED06 execute.**

## 5. Task register

| ID | Task | AVP Ref | Priority | Depends | Success Test |
|---|---|---|---|---|---|
| TC01 | Schema v3.1: add `layerOrderBlock`, `layerFVG`, FVG classification, gap timestamps, `fillTime` — mirrored in `TelemetryTypes.mqh:105,247-256`, `TelemetryCollector.mqh:119-127`, `TelemetryRowBuilder.mqh:155-165`, `CalibrationDataset.mqh:130-138` | Doc08 S9 T01 · L T01/C13/C16 | P0 | — | CSV columns populated; round-trip parse green — **DONE 2026-08-03: schema v4/75 implemented, contract `docs/TelemetrySchema_v3.1.md`, 993/993 tests pass (sprint20 TC01 commit)** |
| TC02 | Raw wiring: `ConfluenceEngine.mqh:299` `componentCount=0` → compute real `*Raw/Weight/Contribution` at decision time | Doc08 S9 T01 · L T01 | P0 | TC01 | raws unique > 1; `TelemetryHealthReport.mqh:346` asserts updated — **DONE 2026-08-03: `BuildRuleComponents` (rule path) + evaluator path preserved; engine-unsettled rows (`score.total == 0`) keep all-zero split (`TelemetryRowBuilder.mqh`); verified on real EURUSD H1 2026-01 run: 500/500 split-consistent, health PASS, behavioral delta nil, 1037/1037 suite (sprint20 TC02 commit)** |
| TC03 | `hasProtectedPoint` trace & wire (SwingDetector:113-119 vs RowBuilder:165) | L T01 · doc 03 S3 | P0 | TC01 | `'2'` appears where a protected point exists — **DONE 2026-08-04: traced from the manager's active high/low at decision time (`ConfluenceEngine.mqh` signal bridge; pure trace, scoring untouched); unit Test 31 (no-manager contract stays false); real EURUSD H1 2026-01 run: 500 rows / 0 I/O faults, `'2'` on all rows, every row aligned with journal-verified active protected points (ProcessCurrentTrend activations precede each bar), B2→B3 behavioral delta = only the `hasProtectedPoint` column (1 of 75), suite 1039/1039 (sprint20 TC03 commit)** |
| TC04 | FVG classifier serialization (`FVGDetector.mqh:306-401` outputs → TC01 columns) | L C16 | P0 | TC01 | Classification reachable in CSV (unblocks doc 06 E1/E2) — **DONE 2026-08-05: signal snapshot in the engine bridge resolves the FVG by exact id match against `bestRule.evidenceIds` (position-independent; `sig.fvgId` untouched — entry pricing keys off it); row builder serializes via `TelemetryFVGClass/Size/Strength` mappers + both gap timestamps; fixture contract test added; real EURUSD H1 2026-01 run: 500 rows / 0 I/O faults, classifier columns populated (CONTINUATION 225, sizes SMALL/MEDIUM/LARGE, strengths NORMAL/STRONG, `fvgCreatedTime` on all 291 FVG rows, `fvgFillTime`=0 — gap never filled), values byte-consistent with journal `FVG-CREATED` lines, 0 non-FVG rows claim a class, B3→B4 behavioral delta = only the 4 classifier columns (71 others byte-identical), suite 1053/1053 (sprint20 TC04 commit)** |
| TT01 | Regression harness (Swing/Pivot/BOS/Trend/PP/CHOCH/Liquidity/FVG); test per P0 fix | Doc08 S9 T02 · L T02 | P0 | M1 | Headless suite green — **DONE 2026-08-05: `Tools\TT01\TT01_Validate.ps1` — Platform Validation Harness, one command (`powershell -File TT01_Validate.ps1`), exit 0 = safe to commit. Gates: COMPILE (6 targets: SuperCents_X, CalibrationRunner, TestRunner, TestRunnerEA, BenchmarkRunner, BenchmarkRunnerEA) → SUITE (headless 1053/1053 with per-category summary) → REPLAY (real EURUSD H1 2026-01, 500 rows / 0 I/O faults / HealthMonitor HEALTHY) → TELEMETRY-CONTRACT (75-column v3.1 header exact, schemaVersion=4, numeric/flag/time domains, fingerprint constant) → EVIDENCE-REGRESSION (split invariant rule|eval per row, raws non-constant, classifier invariants, hasProtectedPoint reachable, firedRuleId/ruleName/ruleEvidenceCount consistency; pdRaw exempt — DD02/DD05 target) → BEHAVIOR-REGRESSION (byte-identical 75 columns vs frozen baseline + decision/rule/outcome counters; `-AllowDelta` for declared instrumentation) → PERFORMANCE (replay/suite ms, peak mem, csv bytes, rows/s vs frozen baseline; warn-only) → artifact manifest per run. **Baseline history: B4** (2026-08-05, commit aea90c6, original code) — superseded on 2026-08-06 (DD02 commit 3de40b3) because the B4 replay environment proved non-deterministic: the terminal's tick cache drifted (5062 vs 1533 replay updates; pivot re-promotions 20000 vs ~3500; locked-pivot sighting 1602 vs 267) while the OHLC data was byte-identical (first-scan swing counts h=803/804, l=857/856) and no code touched the swing/pivot/PP paths — i.e. the drift was **environmental, not an algorithm change**. **B5** (2026-08-06, commit 3de40b3, DD02 code, freezeId=B5 in the manifest) is the **canonical TT01 regression baseline** going forward; it is reproducible (deterministic byte-identical reruns) and frozen only from verified green code. Baseline CSV + manifest live in `Tools\TT01\baseline\`.** |
| DD01 | PD evaluator: populate `DetectionContext.swingHigh/swingLow` | L C01 | P0 | M1 | PremiumDiscount evaluator active in test - **DONE 2026-08-05: `BuildDetectionContext` (ConfluenceEngine.mqh) wires the PP manager's active swing refs into `context.swingHigh/swingLow` (NULL-guard, 0.0 when no active ref -> evaluator stays inert/InvalidRange); method made public for test verification; unit Tests 32-33 (NULL contract + full production detector chain swing->pivot->BOS->trend->PP manager over real EURUSD H1 history: active ref present and prices copied verbatim); TT01 full gate run PASS - suite 1053 -> 1063/1063 (Confluence Engine 100 -> 114), replay 500 rows/0 faults, telemetry contract exact, evidence invariants hold, production behavior byte-identical (rule path untouched by design), perf within tolerance (sprint20 DD01 commit)** |
| DD02 | Cold-start: record first-crossing bar (BOS C2 / CHOCH C6) | L C02 | P0 | M1 | Correct attribution on cold start — **DONE 2026-08-06: `CheckBOS` (BOSDetector.mqh) rewrote the break scan to attribute the event to the TRUE first-crossing bar — window enforced by TIME (`pivot.time`), not the pivot's index (the pivot engine's `barIndex` is chronological while the BOS arrays are series-flipped by `CSymbolContext::Update`; the initial index-window draft emitted pre-pivot 2025 crossings on the real run, collapsing the recent-BOS evidence window). Oldest-first scan + first qualifying close = first crossing; emission keeps ids time-ordered so TrendState's final trend = the most recent break. `CHOCHDetector.Update` — on first examination of a PP id, scan back from the oldest bar, skip bars before `activationTime`, first close beyond the PP level emits with the true crossing bar/time; normal cadence (activation at current bar) degrades to bar-1-only, behavior unchanged. Unit Tests 34-39 (BOS first-crossing/window-guard/bar-1 equivalence/chronology; CHOCH cold-start + bar-1 equivalence) — RED 8 failures first (defect demonstrated), GREEN 1116/1116 (Confluence Engine 167/167). Debug-log noise dropped (bar-1-only gap messages) — replay 4h -> 19s. Real-run verification caught the index-space bug (2025 crossings at `Bar:6679`), fixed, replay 500/0 HEALTHY, contract + evidence gates PASS. Baseline B4 unreproducible (terminal tick-cache changed: 5062 vs 1533 replay updates -> pivot re-promotions 20000 vs ~3500, locks 1602 vs 267, same OHLC/swings) — **baseline re-frozen B5 from the DD02 code** (same 500-row grid, deterministic byte-identical); TT01 full gate run PASS with B5 (sprint20 DD02 commit)** |
| DD03 | Sweep confirmation + closed-bar evaluation (weakest-sweep C09) | L C09 | P0 | M1 | **DONE 2026-08-06: first intentional algorithm correction** (doctrinal, per doc 04 E1): `DetectSweeps` (LiquidityDetector.mqh) now evaluates the last CLOSED bar (series index 1, `rates_total >= 2`) with same-bar close-back confirmation — buy-side `high[1] >= avg AND close[1] < avg`; sell-side `low[1] <= avg AND close[1] > avg`; forming-bar touches no longer sweep; `sweptTime = time[1]`; signature gains `close[]` (call site SymbolContext.mqh). Unit Tests 40-45 (confirmed sweep buy/sell, pierce-without-close-back both sides, forming-bar-only touch stays ACTIVE, closed-bar cadence with sweep at close time) — RED 7 first (defect demonstrated), GREEN 1140/1140 (Confluence Engine 191/191). TT01 evolved for row-rooted localization: `-ExpectedRows` + `-AllowDecisionIds` with three invariants — decision identity (decisionId/signalTime/configFingerprint/symbol/timeframe identical on all 500 rows), completeness (changed 339 == allowlist 339), attribution (every allowed decision traces to the liquidity cascade: sweep flag / liquidity rule / level evidence / legacy-confidence echo). Stage A/B evidence: sweep count 314→207, LIQUIDITY_BOS 314→207 (BULLISH 170→146, BEARISH 144→61), rule redistribution to BOS_OB_BEARISH 72→165 / OB_FVG_BEARISH 73→89 with level-id evidence shift on 230 rows (sweep-timing → level lifecycle cascade), 161/500 rows byte-identical, 0 unexplained rows, no env drift (unlike B4). **Baseline transition documented: B4 (env drift) → B5 (platform stable) → DD03 (intentional correction) → B6 (first doctrinal baseline, frozen 2026-08-06T19:22, replayMs 18914→16116)**; full TT01 gate run PASS (sprint20 DD03 commit). In-family re-measurement (M15 gate experiment, per-family thresholds) remains the Sprint 21 measurement task — not part of this fix |
| DD04 | `classification` write (`LQD:753`) + kill same-level `TARGET_OPPOSING_LIQUIDITY` | L C10 | P0 | M1 | **DONE 2026-08-06: side-class written at `CreateLevel` (LiquidityDetector.mqh) from the level type — EQH/INTERNAL_HH/EXTERNAL_HH → BUY_SIDE, EQL/INTERNAL_LL/EXTERNAL_LL → SELL_SIDE (same sets as `DetectSweeps`); `ResolveTakeProfit` (TargetResolver.mqh) never targets the candidate's own level (`ll.id != candidate.liquidityId`), ACTIVE pools only, classification authoritative (the `\|\| ll.swept` escape is gone), newest-first scan like the OB/FVG branches, Fixed-RR fallback when no opposing pool exists. Unit Tests 46–52 (classification for all six types; E3 falsifications both directions: swept sell-side → buy-side pool ≠ source, swept buy-side → sell-side pool ≠ source; Fixed-RR fallback; same-level degeneracy guard; consumed-pool exclusion) — RED 13 first (defect demonstrated: classification 0 everywhere, target = swept source price), GREEN 1183/1183 (Confluence Engine 234/234). TT01 full gate run PASS: 6 compile targets clean, suite 1183/1183, replay 500 rows/0 faults HEALTHY, contract + evidence gates PASS, BEHAVIOR-REGRESSION byte-identical vs B6 (all 75 columns, 500/500 rows) — the plan path (CExecutionPlanner → plan.takeProfit → live/shadow orders) is outside the replay telemetry chain (the outcome sim uses the legacy CEntrySetupBuilder fixed-RR builder, which has no liquidity setup), so DD04 is a unit-test-verified contract with zero research-telemetry perturbation and NO baseline re-freeze; classification summary counters (LiquidityDetector) now report real side counts (sprint20 DD04 commit)** |
| DD05 | **C08 decision executed: admit all families to the entry pipeline** (`ConfluenceValidator.mqh:29-46` — remove family-agnostic-only admission); GR01 becomes the evidence-based routing layer | L C08 | P0 | M1 | **DONE 2026-08-07: per-family admission floors in `ConfluenceValidator.ResolveFloor()` — Liquidity 0.60, FVG 0.40, OrderBlock/BOS/CHOCH 0.35, UNKNOWN (evaluator path) → global 0.60 fallback (research-derived temporary defaults; GR01/M15 calibrates); winning rule identity (`winningRuleId/Name/Family`) stamped at `ConfluenceEngine.Update()` from `bestRule.type` (both paths; evaluator path stays RULE_NONE/UNKNOWN); fingerprint canonical extended with the 5 floors (after brokerDigits) — hex changes on all 500 rows (expected policy recording); `RuleTypeToName/Family` in SignalTypes.mqh, `ENUM_RULE_FAMILY` in ConfluenceTypes; TDD tests 53–65 (RED 90 errors → GREEN 1237/1237, Confluence Engine 252/252, Validator 89/89, Telemetry 264/264); TT01 evolved: row-rooted localization now exempts configFingerprint from sequence identity (policy recording; constancy via CONTRACT gate) and adds the admission attribution class (shared validator components identical except ConfluenceValidator, new components = short-circuit pack growth with verdict consistency, echo columns only); Stage A/B evidence vs B6: 208 changed rows == allowlist 208, 292/500 byte-identical, qualified 240→442 (BOS_OB_BEARISH 0→160, OB_FVG_BEARISH 0→42, Liquidity 144/57 preserved, evaluator 39 unchanged), 0 unexplained; **baseline transition B6 → B7 (doctrinal: per-family admission opens the funnel for GR01)**; full TT01 gate run PASS at freeze |
| LC01 | E11 audit: per-detector lifecycle contract (init/reset/reload/chart refresh/TF change/restart); FVG time-discontinuity rescan (`FVGDetector.mqh:144-151`) = reference pattern | Doc08 S9 E11 + Reload · L E11 | P0 | M1 | Audit table all 6 detectors; reset tests pass |
| LC02 | `rates_total`-shrink handler (shrink without time reversal) | L E11 | P0 | LC01 | Shrink-simulation test green |
| LC03 | Downstream cursor re-sync (CHOCH cursor → OB latent) | L E11 | P0 | LC02 | No stale-cursor stall on reload |
| GR01 | Per-family gate thresholds (M15): replace conf-only min 0.60 in `ConfluenceValidator.mqh:29-46`; re-measure admission-adjusted wr per family | Doc08 S9 Funnel/gate · L R11/R13 | P1 | M2 | No family 0% admitted; funnel report reproducible |
| GR02 | Funnel metrics: firedRuleId → admitted → entered → filled | L T01 · doc 05 P5 | P1 | M1 | Metrics columns populated per row |
| VF01 | Liquidity renderer (EQH/EQL drawn) | Doc08 S9 Visualization · L C11 | P1 | M1 | Renderer parity check passes |
| VF02 | Palette parity (C07 + OB drift) | L C07 · doc 05 F3 | P2 | — | Colors match frozen spec |
| ED01 | R15 trend-bonus removal experiment (doc 06 E3) | doc 08 S4 #7 | P2 | M3 | Falsifiable per doc 06 P7 |
| ED02 | R17 h22-23 BULL exclusion experiment (doc 06 E4) | doc 08 S4 #7 | P2 | M3 | Falsifiable per doc 06 P7 |
| ED03 | R03 session-gate experiment (M06) | doc 08 S4 #7 | P2 | M3 | Falsifiable |
| ED04 | R16 direction×cell month-split (doc 06 E5) | doc 08 S4 #7 | P2 | M3 | Falsifiable |
| ED05 | C12/C18 displacement gates — paper-first (OB + FVG) | doc 08 S4 #7 | P2 | M3 | Paper re-measure only |
| ED06 | R14 rule decomposition (OB_FVG vs BOS_OB) | doc 08 S4 #7 | P2 | M3 | Decomposition table |

## 6. Do-not list (frozen, doc 08 S5)

- No detector redesign (Algorithm column of S1 matrix is healthy).
- No new rules, no new indicators.
- **No gate changes before telemetry** (GR01 is the first gate change and sits after M2).
- No OB/FVG displacement gating until classification is serialized (ED05 is paper-first).
- No tuning without evidence (Never Guess principle).

## 7. Commit & ledger conventions

- One commit per task: `sprint20: <ID> – <summary> (AVP ref: Doc08 S9 <cell> / L <ledger id>)`.
- After each task: mark ledger row `RESOLVED — <ID>` (appended annotation, no deletions — ledger row rule).
- After M1: freeze schema v3.1 telemetry (new evidence baseline; future AVP v2.0 will compare against it).
