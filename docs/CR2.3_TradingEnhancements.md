# Capability Release 2.3 — Trading Enhancements

A Capability Release within the established four-layer architecture. No architectural changes.

---

## Gateway Review

### 1. Ownership

**Layer:** Trading Platform

**Primary responsibility:** Increase the quality, consistency, and confidence of trade identification and execution decisions.

**Other layers remain consumers:**
- Research measures the new behavior.
- Production supervises it.
- Knowledge compares and explains it.

No ownership changes. No layer boundary modifications.

### 2. Contracts

**New or extended contracts:**

- `ConfluenceScore` — deterministic aggregation of structural evidence
- `OrderBlockQuality` — multi-dimension qualification score
- `FVGQuality` — imbalance qualification score
- `EntryConfidence` — setup strength (separate from risk sizing)
- `StructureConfidence` — market structure reliability score
- `DetectionEvidence` — structured evidence accompanying every score

**Score semantics:**

All quality and confidence scores follow a 0–100 scale with explicit interpretation:

| Range | Label | Meaning |
|-------|-------|---------|
| 0–20 | Very Weak | Minimal supporting evidence; high uncertainty |
| 21–40 | Weak | Below-average supporting evidence |
| 41–60 | Moderate | Average supporting evidence; actionable with caution |
| 61–80 | Strong | Above-average supporting evidence; high confidence |
| 81–100 | Exceptional | Maximum supporting evidence; highest confidence |

The numeric scale is part of the contract rather than implementation detail.

**Backward compatibility:** Existing detection outputs remain unchanged. New modules produce supplementary evidence alongside existing signals.

### 3. Invariant Impact

**None.**

All architectural invariants (I1–I10) from Architecture.md are preserved:
- No dependency changes (Trading still avoids Research/Production/Knowledge)
- No runtime ownership changes
- No artifact ownership changes
- No Research/Production/Knowledge modifications beyond consuming richer outputs

### 4. Operational Impact

**Category:** Execution Behavior

This release intentionally changes live trading behavior by improving decision quality. Research, Production, and Knowledge observe richer information without requiring architectural changes.

---

## Architectural Charter

Capability Release 2.3 improves the quality of trading decisions through enhanced market structure analysis and execution confidence while preserving all architectural boundaries and invariants.

The release validates the premise of the Foundation Release: that capability can evolve independently within its owning layer while the rest of the platform continues to function through stable contracts.

---

## Design Invariants

| # | Invariant | Description |
|---|-----------|-------------|
| D1 | **Deterministic scoring** | All quality and confidence scores are deterministic. Same inputs → same scores. |
| D2 | **No probabilistic runtime** | No stochastic models, ML inference, or random sampling in decision paths. |
| D3 | **Existing detections preserved** | Current detection algorithms remain valid inputs to the new qualifiers. |
| D4 | **Quality never overrides policy directly** | Quality metrics inform decisions but do not bypass execution policy or risk constraints. |
| D5 | **Evidence accompanies every score** | Every confidence or quality score includes structured evidence documenting its derivation. |
| D6 | **Backward-compatible interfaces** | Existing modules continue to function unmodified. New modules are additive. |
| D7 | **Immutable evidence** | `TradingEvidence` is immutable after publication. Execution modules may consume it. Upper layers may archive it. No component mutates evidence after it has been produced. |
| D8 | **Confidence is read-only to policy** | Execution policy consumes `EntryConfidence` but never modifies it. Confidence is an immutable assessment generated before execution policy begins. |

---

## Proposed Modules

```
Trading/
├── StructureConfidence.mqh    # Market structure reliability scoring
├── OrderBlockQualifier.mqh     # Order Block quality evaluation
├── FVGQualifier.mqh            # Fair Value Gap qualification
├── ConfluenceEngine.mqh        # Deterministic evidence aggregation
├── EntryConfidenceEngine.mqh   # Setup strength scoring
└── TradingEvidence.mqh         # Structured evidence types
```

### 1. `TradingEvidence.mqh`

**Responsibility:** Shared types for evidence and confidence scoring.

**Owns:**
- `ConfluenceScore` struct
- `OrderBlockQuality` struct
- `FVGQuality` struct
- `EntryConfidence` struct
- `StructureConfidence` struct
- `DetectionEvidence` struct
- Enums for quality levels and confidence tiers

### 2. `StructureConfidence.mqh`

**Responsibility:** Evaluate the reliability of detected market structure.

**Inputs:** Existing swing points, BOS/CHOCH signals, protected points.

**Evaluation dimensions:**
- Swing strength (depth, duration, volume context)
- BOS confirmation (follow-through, proximity to swing extremes)
- CHOCH transition quality (impulse strength, structural significance)
- Protected point validation
- Structural noise reduction (filter micro-structure from macro-structure)

**Output:** `StructureConfidence` score with supporting evidence.

### 3. `OrderBlockQualifier.mqh`

**Responsibility:** Evaluate detected Order Blocks beyond binary presence.

**Inputs:** Existing Order Block detection signals.

**Evaluation dimensions:**
- Displacement strength (impulse size, velocity)
- Mitigation state (untouched, partially mitigated, fully mitigated)
- Freshness (time since formation, number of touches)
- Liquidity relationship (proximity to known liquidity zones)
- Structural alignment (alignment with broader trend/structure)

**Output:** `OrderBlockQuality` score with dimension-level breakdown.

### 4. `FVGQualifier.mqh`

**Responsibility:** Evaluate detected Fair Value Gaps beyond binary presence.

**Inputs:** Existing FVG detection signals.

**Evaluation dimensions:**
- Minimum imbalance size threshold
- Age (time since formation — older gaps have lower weight)
- Fill percentage (how much of the gap has been retraced)
- Trend alignment (gap direction vs. prevailing trend)
- Structural significance (gap in context of nearby structure)

**Output:** `FVGQuality` score with dimension-level breakdown.

### 5. `ConfluenceEngine.mqh`

**Responsibility:** Aggregate evidence from multiple detectors into a single deterministic confluence score.

**Inputs:** Structure confidence, OB quality, FVG quality, liquidity signals, trend state.

**Scoring model:**
- Each evidence source contributes a weighted sub-score
- Weightings are deterministic and configurable
- Confluence threshold determines minimum score for actionable setups
- Engine outputs both the aggregate score and the per-source breakdown

**Output:** `ConfluenceScore` with evidence breakdown.

### 6. `EntryConfidenceEngine.mqh`

**Responsibility:** Produce a setup-level confidence score separating signal strength from risk sizing.

**Inputs:** Confluence score, structure confidence, trend alignment, market context.

**Scoring:**
- Entry confidence answers "How strong is this setup?"
- Risk sizing answers "How much capital should be exposed?"
- These remain separate responsibilities — EntryConfidenceEngine never computes position size

**Output:** `EntryConfidence` score with evidence chain.

---

## Integration Rules

### Permitted
- Extend detection outputs with quality metadata
- Produce richer evidence structs consumed by existing modules
- Improve execution decisions using confidence scores
- Read current market state and existing detection results

### Ownership Rules
- **`TradingEvidence` is immutable after publication.** Execution modules may consume it. Upper layers may archive it. No component mutates evidence after it has been produced.
- **`EntryConfidence` is read-only to execution policy.** Execution policy consumes `EntryConfidence` but never modifies it. Confidence is an immutable assessment generated before execution policy begins.

### Prohibited
- Invoke Research, Production, or Knowledge modules
- Modify optimization or production artifacts
- Generate analytical reports
- Write to Laboratory artifact paths
- Override execution policy or risk constraints
- Introduce non-deterministic scoring
- Mutate `TradingEvidence` after publication
- Modify `EntryConfidence` in execution policy

---

## Dependency Map

| Module | Depends On |
|--------|-----------|
| `TradingEvidence.mqh` | `Utils/Constants.mqh` |
| `StructureConfidence.mqh` | `TradingEvidence.mqh`, `Structure/*` |
| `OrderBlockQualifier.mqh` | `TradingEvidence.mqh`, `Confluence/OrderBlockDetector.mqh` |
| `FVGQualifier.mqh` | `TradingEvidence.mqh`, `Confluence/FVGDetector.mqh` |
| `ConfluenceEngine.mqh` | `TradingEvidence.mqh`, `StructureConfidence.mqh`, `OrderBlockQualifier.mqh`, `FVGQualifier.mqh`, `Confluence/*` |
| `EntryConfidenceEngine.mqh` | `TradingEvidence.mqh`, `ConfluenceEngine.mqh`, `Entry/*` |

All modules remain within the Trading layer. No new cross-layer dependencies.

---

## Lifecycle Integration

| Phase | Action |
|-------|--------|
| `Engine::Init()` | Initialize qualifiers and confidence engines. Register evidence types if required. |
| `Engine::OnTick()` | New modules run within existing detection pipeline. Scores are computed alongside existing signals. |
| `Engine::Shutdown()` | Cleanup qualifier state. |

No changes to the lifecycle of Research, Production, or Knowledge layers.

---

## Acceptance Criteria

| Criteria | Verification |
|----------|-------------|
| Improved confluence evaluation | ConfluenceEngine produces deterministic aggregate scores from multiple sources |
| Deterministic confidence generation | Same market state → same confidence scores |
| Qualified Order Blocks | OrderBlockQualifier produces dimension-level quality scores |
| Qualified Fair Value Gaps | FVGQualifier produces dimension-level quality scores |
| Backward-compatible integration | Existing modules compile and function without modification |
| No dependency violations | `grep -r "include.*Optimization\|include.*Production\|include.*Laboratory" Trading/` returns empty |
| Existing regression suite passes | All existing regression tests pass |
| New capability tests pass | Dedicated tests for each qualifier engine |
| 0 compilation errors | `≤4` pre-existing warnings only |

---

## Definition of Success

The Trading layer becomes more capable while the Research, Production, and Knowledge layers require **no architectural modification** to consume the richer outputs.

If that holds true, Capability Release 2.3 validates the Foundation Release premise: capability evolves independently within its owning layer while the rest of the platform functions through stable contracts.

---

## Out of Scope

- New architectural layers or layer boundary changes
- Machine learning model training or inference
- Research, Production, or Knowledge module modifications
- Optimization algorithm changes
- Risk model changes (risk sizing remains separate)
- Execution policy changes (quality informs but does not override)
- Non-deterministic or probabilistic decision paths
- Automated strategy selection

---

*End of specification.*
