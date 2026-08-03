# Sprint 19 — Algorithm Verification Program (AVP) — Methodology v1.0

Status: **FROZEN — AVP Methodology v1.0** (2026-08-03, finalized
with §4.13 Research Confidence × Destination × Outcome
Classification annotation baked in).

This document is the constitution for every Sprint 19 (AVP)
verification review. It is locked: every AVP document in this series
is judged under exactly this standard. Do not amend the methodology
mid-series. If a better process is discovered, draft **AVP
Methodology v1.1** for the *next* verification cycle; never silently
change the rules while a published AVP document is being graded.

---

## AVP Golden Rule

> No algorithm may be redesigned, optimized, or replaced until its
> current implementation has been fully verified against research,
> industry practice, formal specification, visualization, pipeline
> contracts, and the frozen Sprint 17 evidence baseline.

Rationale: "fixing" an algorithm before understanding it trades one
bias for another. Verification first; redesign second; promotion last.

---

## 1. Program roadmap

```
Sprint 17  Evidence baseline    (frozen: 18,686 rows, fingerprint 2e74bbae…)
   │
   ▼
Sprint 18  Research knowledge    (frozen: 15 domain reviews + M01–M53 master backlog)
   │
   ▼
Sprint 19  AVP — Verification     (00 = methodology; 01–06 = BOS, CHOCH, Swing,
                                  Liquidity, Order Blocks, FVG)
   │
   ▼
Sprint 20  Engineering            (implement only A/B experiments surviving verification)
   │
   ▼
Sprint 21  Validation             (walk-forward, Monte Carlo, shadow-in)
   │
   ▼
Promotion Gate  →  LIVE
```

Every implementation change must carry the complete traceability
chain: **Research → Industry Practice → Formal Specification →
Algorithm Verification → Visualization Verification → Pipeline
Verification → Evidence → Experiment → Implementation.**

## 2. Charter and constraints

- **No production code changes. No implementation. No test changes.
  No telemetry writes. No new evidence collection.** The Sprint 17
  dataset is frozen; nothing new is collected.
- Allowed: web research, read-only code analysis (with `file:line`
  citations), read-only Python over the frozen dataset, and Markdown
  documents under `docs/Sprint19_Research/`.
- Sprint 18 documents are **frozen history**; AVP docs cite them
  (never re-derive or contradict them without re-measuring).
- Commit convention: one commit per doc — `docs: sprint19.0` …
  `docs: sprint19.6`. Stage only `docs/Sprint19_Research/`. The repo
  working tree carries unrelated artifacts — never `git add -A`.

## 3. AVP document structure (locked for docs 01–06, in order)

| # | Phase | Kind | Mandatory artifacts |
|---|---|---|---|
| — | **Algorithm Passport** | front matter | 1-page outcome card (§4.1) |
| P1 | Deep Research | research (~80% effort) | per-school matrix; disagreements / conflicts / strongest evidence / open problems (§4.2) |
| P1.5 | **Formal Algorithm Specification** | spec — written before reading any code | Inputs / Outputs / Preconditions / Postconditions / State transitions / Invariants / Failure conditions; Complexity Analysis; conceptual State Diagram (§4.3) |
| P2 | Industry Implementation | evidence | TradingView / MT5 / Python patterns, mistakes, trade-offs (§4.2 reuse) |
| P3 | SuperCents_X Implementation Review | facts | current algorithm + data flow, `file:line`, no suggestions |
| P3.5 | **Correctness Verification** | analysis | correctness checklist vs. P1.5; **Failure Catalog** (§4.4) |
| P4a | **Visualization — Logical Event** | analysis | should the event fire at all? separate verdict |
| P4b | **Visualization — Rendering** | analysis | how it is drawn: begin/end, candle ownership, extension and deletion semantics; separate verdict |
| P5 | **Pipeline Validation + Data Contracts** | architecture | per-stage Input / Output / Assumptions / Guarantees / Consumer; pipeline question answers (§4.6) |
| P6 | Sprint 17 Evidence Review | measured only | cite/reuse 18.x tables; add only missing measurements; "cannot be measured" (§4.7) |
| P7 | Experiment Backlog | experiments | full-card format with falsification (§4.8) |
| — | Proof Matrix | research | "Can we prove it?" per claim (§4.9) |
| — | Traceability Matrix | table | every P7 experiment → cited evidence (§4.10) |
| — | Verification Scorecard | numerics 0–100 | per-area scores, comparable across subsystems (§4.11) |
| — | Final Research Verdict | disposition | six quality ratings + confidence + recommendation (§4.12) |
| — | **Findings Summary** | table | every finding → **Research Confidence × Destination** (§4.13) |

Phases P1–P1.5 never mention the subsystem being verified. P3 begins
only after P1, P1.5 and P2 are complete — this ordering prevents
implementation bias. When this section says "the format is locked",
the §4.13 annotation above is part of that lock.

## 4. Artifact formats (locked)

### 4.1 Algorithm Passport (1 page, front of each AVP doc)

| Field | Value |
|---|---|
| Algorithm | Break of Structure (BOS) |
| Version Reviewed | v3.0-research-baseline |
| Method applied | AVP v1.0 |
| Sprint | AVP 19.1 |
| Research sources reviewed | N |
| Industry implementations compared | N |
| Code files reviewed | N |
| Dataset rows reviewed | 18,686 |
| Verification Score | NN/100 |
| Overall Recommendation | Keep / Improve / Redesign |

A reader must understand the outcome from this page alone.

### 4.2 P1 deep research output

**Per-school matrix** — schools, at minimum: ICT, Smart Money
Concepts (SMC), Wyckoff, Al Brooks price action, academic /
structural-change, market microstructure, institutional quant.
Dimensions, at minimum: definition; why it exists; advantages;
weaknesses; failure cases; false-BOS situations; multi-timeframe
handling; confirmation methods; noise filtering; volume confirmation;
wick-break vs close-break; strong vs weak signal; BOS vs fake
breakout; BOS vs MSS; BOS vs CHOCH; relationship with liquidity; with
Order Blocks; with FVG; with premium/discount.

**Mandatory sub-sections**: What professional/different traditions
disagree on; which definitions conflict; which definition has the
strongest evidence; what remains an open research problem. Distinguish
peer-reviewed academic claims from practitioner/bloc claims explicitly
throughout.

Sources: web research across peer-reviewed papers, microstructure
research, SMC/ICT material, Wyckoff, professional trading books,
institutional whitepapers, open-source implementations. Every claim
carries an identifier usable in the Traceability Matrix (§4.10:
`LT-…` for literature/academic, `TV-n` / `MT5-n` / `PY-n` for
industry implementations).

### 4.3 P1.5 formal specification + complexity

Written template (research-first, tech-independent):

```
Input            : locked swing highs / locked swing lows
Output           : BOS event (bullish / bearish), exactly once
Preconditions    : pivot confirmed and locked
Postconditions   : trend state updated; event recorded
State transitions: [every legal transition]
Invariants       : never repaints after pivot lock; never allows duplicate
Failure          : equal highs; gap jump; multiple simultaneous breaks
```

**Complexity Analysis** per algorithm:

| Metric | Value |
|---|---|
| Time complexity | O(…) |
| Memory complexity | O(…) |
| Streaming suitability | YES / NO |
| Incremental update | YES / NO |
| Repaint risk | NONE / LOW / HIGH |
| Lookahead bias risk | NONE / LOW / HIGH |

**State Machine** — conceptual text diagram (not implementation):

```
No Pivot → Locked Pivot → Waiting Break → BOS Triggered → Trend Update → Done
```

### 4.4 P3.5 correctness checklist + Failure Catalog

Correctness checklist items (adapt per algorithm): swing selection
correct; pivot locking correct; break detection correct; exactly-once
emission; repaint-free; duplicate-free; no missed events; equal
highs/lows handled; inside bars handled; gaps handled; edge/array
bounds correct; trend transitions correct. Each labelled PASS /
WARN / FAIL / N-A and cross-checked against existing unit tests.

**Failure Catalog** — one of the most valuable artifacts; reusable
per algorithm:

| # | Failure | Definition | Literature | Industry treatment | Our implementation | Sprint 17 evidence | Recommendation |
|---|---|---|---|---|---|---|---|
| 1 | Equal highs | … | [LT..] | [MT5-n] | File:line | Table.. | … |

Examples to populate: equal highs/lows; gap opens; low liquidity;
news spike; range / fake break; double BOS; pivot ambiguity; late
lock; repaint race. Evidence column honestly says "dataset cannot
measure this" where required.

### 4.5 P4 split artifact

P4a (Logical Event — should the event fire?) and P4b (Rendering —
how is it drawn?) each carry their **own verdict**. Merge them only
in the passport. The algorithm may be correct while the renderer is
wrong, or vice versa. Document **all** valid interpretations (ICT
wick-break vs Brooks close-break etc.); never assume ours is wrong
just because another implementation differs.

### 4.6 P5 data contracts

Per pipeline stage:

```
Stage:      SwingDetector
Input:         bars
Output:        locked swings
Assumptions: …
Guarantees:     never changes a locked swing
Consumer:       pivot engine
```

Also answer the pipeline-questions explicitly: is the stage ordering
correct? Is every dependency justified? Can X occur before Y? Can the
signal exist without the trend? Are state transitions correct? What
is redundant / missing?

### 4.7 P6 evidence rules

- Reuse measured Sprint 18 tables with exact citation, e.g. a table
  from `[18.2 7.1]` is quoted as-is, never re-run to produce a
  different number.
- Add measurements only when the AVP phase list requires a split the
  Sprint 18 table lacks (e.g. BOS-family × hour — new).
- Every claim must be honest: "Current dataset cannot measure this."
  plus why (no column, event-level semantics, order-level behavior).

### 4.8 P7 experiment card (full format)

| Field | Contents |
|---|---|
| Literature evidence | identifier |
| Industry evidence | identifier |
| SuperCents_X comparison | file:line |
| Sprint 17 evidence | [18 .x] table |
| Expected benefit | … |
| Expected risks | … |
| Complexity | low/med/high |
| Overfitting risk | high/med/low + why |
| Required telemetry | columns |
| Schema changes | none / v3.1 / v4 |
| Backtest requirements | … |
| Walk-forward requirements | … |
| Monte Carlo requirements | … |
| Confidence grade | A / B / C / D / F |
| **Falsification** | "Falsified if: …" — concrete evidence that would disprove it |

Only A and B cards may be recommended for Sprint 20 implementation.
Falsification example: "Two-candle BOS confirmation reduces false
breaks" → *Falsified if: win rate does not improve; expectancy
decreases; drawdown increases; the promotion gate rejects on the
holdout.*

### 4.9 Proof Matrix ("Can we prove it?")

For each key claim of the review:

| Claim | Literature | Implementation | Telemetry | Unit tests | Conclusion |
|---|---|---|---|---|---|
| "BOS never repaints" | YES | YES | NO | YES | → likely |

Set columns exactly: Literature / Implementation / Telemetry / Tests /
Conclusion — values YES / NO / PARTIAL / N-A. Include a final
classification: proven by literature / implementation / telemetry /
tests / not proven / cannot currently prove.

### 4.10 Traceability Matrix

For every P7 experiment, route to its exact evidence:

| Experiment | Literature | Industry | Code | Evidence | Proof strength |
|---|---|---|---|---|---|
| M30 | [LT-..] | TV-12 | BOSDetector.mqh:288 | Table 7.2 | Partial |
| M38 | [LT-..] | MT5-07 | TrendState.mqh:188 | Table 8.5 | Strong |

Identifier scheme (locked): Literature `[LT-authorYear]`; academic
`[AcCo-…]`; industry `TV-n` / `MT5-n` / `PY-n`; code `File:line`;
evidence `[18.x §y]`; proof strength Strong / Partial / Weak. Sprint
20 engineers follow this matrix; they never need to re-ask "why are
we implementing this?".

### 4.11 Verification Scorecard

0–100 per area; comparable within the series (BOS vs CHOCH vs FVG):

| Area | Score |
|---|---|
| Research alignment | … |
| Algorithm correctness | … |
| Visualization | … |
| Pipeline | … |
| Evidence support | … |
| **Overall** | **NN/100** |

Banding (locked): 90–100 verified to a high standard; 75–89 verified
with minor gaps; 60–74 verified with significant gaps; <60 not yet
verified, redesign plane requires.

### 4.12 Final Research Verdict

Block with fields:
- Research Quality —
- Implementation Quality —
- Architecture Quality —
- Visualization Quality —
- Evidence Quality —
- Confidence — (A–F per Sprint 18 scale)
- Overall Recommendation — Keep / Improve / Redesign

Plus a 3–5 sentence justification citing the scorecard and the
strongest/weakest artifact.

### 4.13 Every finding carries Confidence + Destination + Outcome Classification (locked)

Finalized into v1.0 before freeze (2026-08-03; Outcome
Classification added as the second and final annotation 2026-08-03).
Three tables are **mandatory in every AVP document** wherever
findings are listed (at minimum: P3.5 Findings, P4a/P4b verdicts, P6
conclusions, and as a consolidated summary):

**(a) Research Confidence** — the reviewer's confidence *in the
conclusion itself*, not the trade. Lets Sprint 20 separate
"almost certain implementation defects" from "hypotheses requiring
experiments":

| Level | Meaning |
|---|---|
| Very High | Deterministic from code paths / direct measurement on frozen data |
| High | Strong code evidence + evidence-table agreement; no counter-evidence |
| Medium | Code-read or single-cell evidence; mechanism plausible, not proven |
| Low | Texture/literature-based; no code or data confirmation |

**(b) Finding Destination** — every finding routes to a concrete home
so nothing is lost (Sprint 20 item, an M-card from the master
backlog, research backlog, or "none / standards only"):

| Finding | Confidence | Destination |
|---|---|---|
| C2 cold-start misattribution | Very High | Sprint 20 (defect fix) |
| BOS family weak overall | High | Sprint 20 gating experiment |

**(c) Verification Outcome Classification** — the type of every
finding, so Sprint 20 can separate *bugs to fix*, *features to add*
and *experiments to run* without re-deriving intent:

| Type | Meaning |
|---|---|
| Implementation Defect | Code bug — deterministic, reproducible, fixable |
| Missing Feature | Research/industry says the feature is absent from the implementation |
| Architectural Limitation | The current design/system shape prevents a behaviour |
| Measurement Gap | Telemetry or dataset cannot prove the claim |
| Research Hypothesis | A claim requiring an experiment on real data |

Typical mappings seen in the series (for consistency):
BOS C2/C3 → Implementation Defect; CHOCH bullish-only rule → Missing
Feature; MSS confirmation absent → Architectural Limitation; session
edge / late-night drain → Research Hypothesis; "cannot measure X" →
Measurement Gap; "no unit tests" → Measurement Gap (verification
cannot prove the claim).

Every AVP doc ends with a consolidated
"**Findings Summary — Confidence × Destination**" table covering all
of its findings, each row carrying its **Outcome Classification**.

---

## 5. Doc schedule (docs/Sprint19_Research/)

| Doc | Topic | Sprint commit |
|---|---|---|
| 00 | AVP Methodology v1.0 | sprint19.0 |
| 01 | BOS Deep Research (pilot) | sprint19.1 |
| 02 | CHOCH / MSS | sprint19.2 |
| 03 | Swing Detection | sprint19.3 |
| 04 | Liquidity | sprint19.4 |
| 05 | Order Blocks | sprint19.5 |
| 06 | FVG | sprint19.6 |

The pilot (01) is executed first and reviewed before 02–06 propagate
the template (risk containment: do not scale a flawed standard).

## 6. Freeze clause

This document is **AVP Methodology v1.0**. It is not amended during
docs 01–06. Any change required by experience becomes **AVP
Methodology v1.1**, applying only to the next verification cycle.
Every AVP doc states its methodology version in its passport so that
future readers know the exact standard under which it was graded.

The §4.13 annotation (Research Confidence + Finding Destination +
**Outcome Classification**) is the **only** set of amendments accepted
into v1.0; both were applied at finalization (2026-08-03) before
docs 01–06 were graded and do not change the phases, artifacts, or
scoring of the standard. From this point the standard is frozen for
the entire series; methodology review happens once after doc 06,
producing v1.1 only for the next verification cycle.