# SuperCents_X Architecture Reference

A Reference Guide to the Platform Architecture, Engineering Principles, and Governance

**Version:** 2.2 (Foundation Release)
**Status:** Stable — evergreen document
**Last Updated:** 2026-07-27

---

## 1. Purpose

This document defines the enduring architectural principles of SuperCents_X. Individual sprint specifications describe implementation details; this reference defines the architectural rules that remain stable across releases.

**Audience:** Developers, maintainers, reviewers, and technical stakeholders evaluating whether new work aligns with the established architecture.

**Relationship to Sprint Specifications:** Sprint specs are time-bound implementation plans. This reference is the canonical source for layer responsibilities, dependency rules, invariants, and governance — it changes only when the platform's governing principles genuinely evolve.

---

## 2. Architecture Evolution

```
v1.0  Structural Engine
v1.1  Rule Evaluation
v1.2  Trade Candidate Engine
v1.3  Entry Decision
v1.4  Execution Planning
v1.5  Trade Execution
v1.6  Position Lifecycle
v1.7  Risk & Money Management
v1.7.5 Observability
v1.8  Portfolio Engine
v1.9  Portfolio Risk & Allocation
 │
 │  Trading Platform (v1.x)
 │  Structure → Decision → Execution → Risk → Portfolio
 ▼
v2.0  Optimization & Validation Framework
 │
 │  Research Platform (v2.0)
 │  Optimize → Validate → Measure
 ▼
v2.1  Production Hardening
 │
 │  Production Platform (v2.1)
 │  Configure → Validate → Recover → Diagnose
 ▼
v2.2  Strategy Laboratory
 │
 │  Knowledge Platform (v2.2)
 │  Compare → Rank → Explain
 ▼
    Future: Feature evolution within the four-layer model
```

Each platform layer was added in sequence, building on the stable foundation below it. No layer was introduced before its dependencies were frozen.

---

## 3. Core Principles

These principles guide every architectural decision. They are stable across releases.

| # | Principle | Description |
|---|-----------|-------------|
| 1 | **Single Responsibility** | Every module has exactly one well-defined responsibility. |
| 2 | **Deterministic Behavior** | Given identical inputs, every analysis and decision produces identical outputs. |
| 3 | **Explicit Ownership** | Every capability has a designated owning layer and module. |
| 4 | **Immutable Evidence** | Historical data is never modified. Revisions produce new artifacts. |
| 5 | **One-Way Dependencies** | Dependencies flow downward through published contracts. Never upward. |
| 6 | **Removability** | Any layer can be removed without affecting lower layers — only dependent capabilities disappear. |
| 7 | **Traceability** | Every derived conclusion must reference its source evidence. |
| 8 | **Reproducibility** | Every analysis can be repeated with identical results given the same inputs. |
| 9 | **Separation of Concerns** | Deciding, measuring, supervising, and synthesizing are distinct concerns owned by distinct layers. |
| 10 | **No Runtime Mutation by Upper Layers** | Analytical layers observe and report. They never modify runtime state. |

---

## 4. Layer Contracts

### 4.1 Trading Platform (v1.x)

**Directories:** `Structure/`, `Confluence/`, `Entry/`, `Risk/`, `Trading/`, `Portfolio/`, `Monitoring/`

| Property | Definition |
|----------|-----------|
| **Purpose** | Execute deterministic trading decisions based on market structure analysis. |
| **Positive Responsibilities** | Detect market structure (swings, BOS, CHOCH, FVG, OB, liquidity). Evaluate confluence. Build entry setups. Validate and execute trades. Manage positions and risk. Allocate across portfolio. |
| **Negative Responsibilities** | Must never analyze historical performance. Must never modify optimization or production configuration. Must never supervise its own reliability. |
| **Inputs** | Market data (ticks, rates, history). Configuration parameters. |
| **Outputs** | Trade execution signals. Position state. Risk metrics. Portfolio exposure. Event notifications. |
| **Allowed Dependencies** | `Utils/`, `Core/` (Logger). |
| **Forbidden Dependencies** | `Optimization/`, `Production/`, `Laboratory/`. |

### 4.2 Research Platform (v2.0)

**Directory:** `Optimization/`

| Property | Definition |
|----------|-----------|
| **Purpose** | Measure and validate strategy behavior through reproducible experiments. |
| **Positive Responsibilities** | Parameter optimization. Walk-forward analysis. Monte Carlo validation. Robustness testing. Strategy analytics. Report generation. |
| **Negative Responsibilities** | Must never influence live execution. Must never modify trading parameters at runtime. Must never execute trades. |
| **Inputs** | Experiment manifests. Parameter bundles. Historical market data. |
| **Outputs** | Experiment reports. Strategy analytics. Validation results. Performance metrics. |
| **Allowed Dependencies** | `Utils/`, `Core/`, `Monitoring/` (types only). |
| **Forbidden Dependencies** | `Trading/`, `Portfolio/` (runtime), `Production/`, `Laboratory/`. |

### 4.3 Production Platform (v2.1)

**Directory:** `Production/`

| Property | Definition |
|----------|-----------|
| **Purpose** | Configure, validate, monitor, and recover platform operation. |
| **Positive Responsibilities** | Configuration management. Version and schema management. Startup validation. Environment validation. Fault classification. Recovery execution. Health supervision. Diagnostics. |
| **Negative Responsibilities** | Must never make trading decisions. Must never optimize parameters. Must never analyze strategy performance. |
| **Inputs** | Configuration files. Environment state. Module health reports. Fault events. |
| **Outputs** | Startup reports. Health summaries. Deployment reports. Diagnostic logs. Fault events. Recovery actions. |
| **Allowed Dependencies** | `Utils/`, `Core/`, `Monitoring/` (types). |
| **Forbidden Dependencies** | `Trading/`, `Portfolio/` (runtime), `Optimization/` (execution), `Laboratory/`. |

### 4.4 Knowledge Platform (v2.2)

**Directory:** `Laboratory/`

| Property | Definition |
|----------|-----------|
| **Purpose** | Compare, rank, and explain strategy performance using immutable evidence. |
| **Positive Responsibilities** | Strategy registration. Artifact discovery and caching. Experiment comparison. Deterministic ranking. Robustness analysis. Statistical analysis. Benchmark comparison. Knowledge graph construction. Evidence-backed recommendations. Report composition. |
| **Negative Responsibilities** | Must never execute trades. Must never modify optimization results. Must never change production state. Must never influence runtime decisions. Must never automatically select or activate a strategy. Must never acquire locks that can block execution. |
| **Inputs** | Persisted artifacts only: experiment manifests, strategy reports, production reports, parameter bundles. |
| **Outputs** | Comparison results. Rankings. Benchmark results. Statistical summaries. Recommendations. Knowledge reports. |
| **Allowed Dependencies** | `Utils/`, `Core/`, `Optimization/` (types only), `Production/` (types only). |
| **Forbidden Dependencies** | `Trading/`, `Portfolio/`, runtime modules. |

---

## 5. Dependency Model

```
                    ┌─────────────────────────────┐
                    │      Knowledge Platform      │
                    │    Laboratory/ (v2.2)         │
                    │  Compare • Rank • Explain     │
                    └────────────▲─────────────────┘
                                 │  types only
                    ┌────────────┴─────────────────┐
                    │      Production Platform      │
                    │    Production/ (v2.1)          │
                    │  Configure • Validate • Recover│
                    └────────────▲─────────────────┘
                                 │  types only
                    ┌────────────┴─────────────────┐
                    │      Research Platform        │
                    │    Optimization/ (v2.0)        │
                    │  Optimize • Validate • Measure │
                    └────────────▲─────────────────┘
                                 │  types only
                    ┌────────────┴─────────────────┐
                    │      Trading Platform         │
                    │  Structure/ Confluence/ Entry/ │
                    │  Risk/ Trading/ Portfolio/     │
                    │  Monitoring/ (v1.x)            │
                    └───────────────────────────────┘
```

### Dependency Rules

1. **Dependencies flow upward only through shared types.** A layer may include type definitions from the layer below it. It may not include implementation modules.
2. **No circular dependencies.** If A depends on B, B must never depend on A, directly or transitively.
3. **Lower layers never depend on higher layers.** Trading never includes Optimization. Production never includes Laboratory.
4. **Runtime dependency is one-way.** Trading produces events. Monitoring consumes them. The direction is never reversed.
5. **Cross-layer data flows through artifacts, not function calls.** Analysis layers read persisted files. They do not call into runtime modules.

---

## 6. Module Ownership Map

```
Trading Platform
├── Structure/           Swing detection, BOS, CHOCH, trend state
├── Confluence/          Confluence scoring, zone evaluation
├── Entry/               Setup builder, validator, decision engine
├── Risk/                Position sizer, exposure tracker, drawdown monitor
├── Trading/             Execution planner, trade manager, position manager, request builder, validation
├── Portfolio/           Portfolio manager, scheduler, correlation manager, statistics, symbol context,
│                        portfolio risk manager, allocation engine, capital allocator
└── Monitoring/          Metrics collector, health monitor, statistics reporter, event bus,
                         visualization manager, renderers

Research Platform
└── Optimization/        Experiment manifest, parameter manager, strategy analytics,
                         walk-forward runner, Monte Carlo validator, robustness tester,
                         report generator, optimization types

Production Platform
└── Production/          Config manager, version manager, migration manager,
                         startup validator, environment validator, fault manager,
                         recovery manager, health supervisor, diagnostic engine,
                         log exporter, performance profiler, deployment verifier,
                         production report, production types

Knowledge Platform
└── Laboratory/          Laboratory types, laboratory manifest, strategy catalog,
                         artifact repository, experiment comparator, ranking engine,
                         robustness analyzer, statistical analyzer, benchmark engine,
                         knowledge graph, recommendation engine, report composer,
                         laboratory report

Shared Foundation
├── Core/                Logger
└── Utils/               Constants, enums, helpers, structures
```

---

## 7. Architectural Invariants

The following invariants hold across the entire platform. Violation of any invariant constitutes an architectural defect.

### I1 — Frozen Lower Layers
Upper layers must never modify the behavior of lower layers. Trading logic is never altered by Research, Production, or Knowledge modules.

### I2 — Deterministic Execution
Given identical inputs, every decision and analysis must produce identical outputs. No randomness in core decision paths.

### I3 — Append-Only Evidence
Historical artifacts are never modified. Revisions produce new versioned artifacts. This applies to experiment reports, production reports, and knowledge reports.

### I4 — Artifact-Based Analysis
Knowledge and Research layers consume only persisted artifacts. No direct access to runtime-owned state.

### I5 — One-Way Dependencies
Dependencies flow downward. No upward dependencies from any layer.

### I6 — Removability
Any directory can be deleted without affecting lower layers. Removing `Laboratory/` removes only analytical capabilities. Removing `Production/` removes only operational capabilities.

### I7 — Traceability
Every derived conclusion must reference its source evidence. Recommendations must maintain a complete provenance chain back to immutable artifacts.

### I8 — Non-Interference
Analytical layers must never acquire locks, register runtime callbacks, or modify state that can block or alter execution behavior.

### I9 — Explicit Ownership
Every capability has exactly one owning layer and one owning module. No shared ownership.

### I10 — No Autonomous Selection
The Knowledge layer may recommend but must never automatically select or activate a strategy. The decision remains with the operator.

---

## 8. Versioning Philosophy

### Platform Version

The platform version (`v2.2`) follows semantic versioning at the release level. It increments when new capabilities are added to any layer.

### Schema Versions

Independent of the platform version, the following schemas are versioned separately:

| Schema | Location | Owner | Description |
|--------|----------|-------|-------------|
| Configuration Schema | `Production/ConfigManager.mqh` | Production | Format and validation of configuration files. Independent of platform version. |
| Knowledge Schema | `Laboratory/LaboratoryManifest.mqh` | Knowledge | Structure of laboratory manifests and reports. Independent of laboratory code version. |
| Experiment Manifest | `Optimization/` | Research | Structure of experiment definitions and parameter bundles. |

**Rule:** Schema versions evolve independently. A configuration schema change does not imply a platform version change, and vice versa.

---

## 9. Engineering Lifecycle

Every capability follows this workflow:

```
Specification
    │
    ▼
Architecture Review (4 passes: Architecture, Contracts, Integration, Knowledge Integrity)
    │
    ▼
Spec Freeze
    │
    ▼
Implementation
    │
    ▼
Compilation (0 errors, ≤ known pre-existing warnings)
    │
    ▼
Regression Testing
    │
    ▼
Implementation Freeze
    │
    ▼
Commit + Tag
```

This sequence guarantees that design decisions are evaluated independently from implementation quality, and that architectural drift is caught before code is committed.

---

## 10. Governance

### Three Rules

1. **Every feature has an owner.** Every proposal must clearly belong to exactly one existing layer. If ownership is ambiguous, the proposal requires architectural review before implementation.

2. **Architecture changes require evidence.** A new foundational layer should only be introduced if there is a responsibility that cannot be expressed within the existing four-layer model without violating current invariants.

3. **Cross-layer dependencies are justified.** Every dependency between modules in different layers must be documented and justified. No implicit dependencies.

### Decision Flow

```
New Capability Proposal
    │
    ▼
Does it fit an existing layer? ─── No ──► Architectural Review
    │                                            │
    Yes                                           ▼
    │                                      Evidence sufficient?
    ▼                                            │
Implement                                   No ──► Redesign
                                              │
                                              Yes
                                              ▼
                                     Architecture Revision
```

### When to Trigger Architectural Review

- A feature cannot be placed cleanly into one of the four layers.
- A feature requires a new dependency direction (e.g., Production depending on Trading).
- A feature would violate one of the ten invariants.
- A feature requires introducing a fifth foundational layer.

---

## 11. Design Review Checklist

Every proposal should satisfy the following before implementation:

- [ ] Does it have a clear owning layer and module?
- [ ] Does it preserve layer responsibilities (positive and negative)?
- [ ] Does it maintain one-way dependency direction?
- [ ] Is it deterministic where required?
- [ ] Is evidence traceable (where applicable)?
- [ ] Does it avoid introducing runtime coupling?
- [ ] Can it be removed without affecting lower layers?
- [ ] Does it preserve append-only semantics for historical data?
- [ ] Does it avoid introducing locks or synchronization that can block execution?
- [ ] Does the proposal fit within the existing four-layer model?

If any answer is "no" or uncertain, the proposal requires architectural review.

---

## 12. Glossary

| Term | Definition |
|------|-----------|
| **Artifact** | A persisted file produced by one layer and consumed by another. Immutable after creation. |
| **Contract** | The interface boundary between layers: types, manifests, and data schemas. |
| **Determinism** | The property that identical inputs always produce identical outputs. |
| **Evidence** | An immutable artifact that supports a conclusion or recommendation. |
| **Invariant** | A property that must hold across the entire platform. Violation constitutes an architectural defect. |
| **Layer** | A horizontal architectural division with a single responsibility. |
| **Manifest** | A structured file describing the identity, version, and inputs of an execution run. |
| **Platform** | The entire codebase comprising all four layers. |
| **Recommendation** | An evidence-backed suggestion produced by the Knowledge layer. Must never be automatically acted upon. |
| **Responsibility (Positive)** | What a layer must do. |
| **Responsibility (Negative)** | What a layer must never do. |
| **Traceability** | The ability to walk from any conclusion back to its source artifacts. |

---

## 13. Architectural Decision Record

The following decisions shaped the platform's architecture. They are recorded here to provide rationale for future maintainers.

| Decision | Rationale |
|----------|-----------|
| **Four-layer architecture adopted.** | Trading (decides), Research (measures), Production (supervises), Knowledge (synthesizes). Each concern maps to exactly one layer. |
| **One-way dependency model established.** | Prevents circular reasoning and ensures lower layers remain stable when upper layers change. |
| **Artifact-based analysis chosen over runtime observation.** | Decouples analysis from execution. Makes analysis reproducible. Eliminates runtime coupling. |
| **Append-only knowledge model adopted.** | Preserves historical conclusions. Prevents silent revision of evidence. |
| **Independent schema versioning introduced.** | Decouples schema evolution from platform version changes. Configuration schemas, knowledge schemas, and experiment manifests evolve independently. |
| **Analytical never mutates runtime.** | Upper layers observe and report. They never modify trading, portfolio, or configuration state. |
| **Laboratory never automatically activates strategies.** | The Knowledge layer recommends. The operator decides. Prevents autonomous trading from analytical code. |
| **Architecture revisions require explicit justification.** | Prevents architectural drift. New layers are only added when existing layers cannot express a new responsibility without violating invariants. |

---

*End of Architecture Reference.*

*This document is stable. It should change only when the platform's governing principles genuinely evolve.*
