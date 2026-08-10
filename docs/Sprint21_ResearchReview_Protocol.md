# Sprint 21 — Research Review Protocol: Evidence Ledger (Literature Review Track)

Status: **FROZEN on user approval 2026-08-10 (freeze record §18.1)** — the
protocol is exactly as drafted; no changes at freeze. Classification
(Phase 2) is the authorized next step, with STOP for review before the
evidence synthesis (Phase 3). No production code is touched; nothing is
committed beyond the protocol freeze itself.
Date: 2026-08-10
Scope owner: research review / literature evidence track, first milestone
(RL01 — protocol + ledger template)
Predecessor: Sprint 20 ED01 closure (`docs/Sprint20_ED01E_Decision.md`,
`528d3de = origin/main`) — 2.0R established as the empirical fixed-RR
benchmark; UNKNOWN-family 2.5R/3R observation recorded as reported-not-
weighed (§16).

## 1. Purpose and scope

Sprint 21 converts the collected research material (36 papers, organized
by topic: FVG, BOS, CHOCH, Liquidity, Order Block, SMC, Swing) into a
**research map**: which claims the literature supports, which it does not
support, which SuperCents_X assumptions are exposed or unsupported, and
which experiments are worth engineering time.

The output is a **knowledge artifact, not code**. Sprint 21 changes
nothing in SuperCents_X (guardrail 1).

The map is the input for Sprint 22+: a pre-registered experiment
shortlist (Phase 4) whose candidates are then executed under the ED
protocol discipline (TDD + TT01 + explicit decision where engineering is
required).

## 2. Guardrails (non-negotiable)

1. **No production change under any phase** — no code, no config, no B8
   change, no detector/floor/weight/validator change, no TP/exit change.
   Sprint 21 is analysis-only on documents.
2. **Protocol-first, classification-second** — no paper is classified
   before this protocol is frozen. Criteria must not drift based on what
   the papers contain (the reason for protocol-first).
3. **No commit before freeze** — this document and the ledger template
   (`docs/Sprint21_EvidenceLedger_Template.md`) are committed only after
   user approval; the classification phase commits are dedicated
   research-track commits, never mixed with engineering.
4. **Separation of claims** — every extracted claim is tagged exactly one
   of: empirical evidence / theoretical proposal / author's
   interpretation / unsupported assumption (section 8). The ledger keeps
   the paper's statement separate from the reviewer's reading.
5. **Evidence over authority** — a claim's weight comes from the evidence
   scale (section 6), not from the paper's reputation, recency, or
   alignment with SMC terminology.
6. **Conflicts recorded, not resolved** — contradictory findings are
   entered as conflicting rows with both sources; the ledger does not
   pick a winner (section 10). Resolution happens only in a
   pre-registered experiment.
7. **No hypothesis promotion without independent justification** — an
   existing empirical observation (e.g., the UNKNOWN-family 2.5R/3R
   result) is entered as an observation; promotion to a hypothesis
   requires an independent research justification (section 16).
8. **Deterministic, auditable record** — each paper gets one ledger row
   set; revisions are append-only annotations, never edits (ledger rule
   mirrored from the Sprint 20 commit/ledger conventions).
9. **Pre-registration boundary** — any experiment that leaves Phase 4
   must be pre-registered under the ED discipline (protocol, freeze,
   gates, decision ladder) before any run or engineering.

## 3. Phase structure (frozen order)

| Phase | Content | Gate to next |
|---|---|---|
| 1 | Protocol freeze + ledger template | User freeze approval |
| 2 | 36-paper classification (per-topic, per-paper schema) | All papers classified, ledger complete, self-check |
| 3 | Evidence synthesis (strength tiers, conflicts, gaps) | Synthesis review |
| 4 | Experiment shortlist (pre-registration-ready candidates) | User selection of hypotheses for Sprint 22+ |
| 5 | (Sprint 22+) Pre-registered experiment execution | ED discipline |

No phase may start before the previous phase's gate passes.

## 4. Inclusion / exclusion criteria (papers)

**Inclusion (all must hold):**
1. The paper is in the collected set (36 files, `research paper/`, topic
   folders) OR is explicitly added by user decision — no ad-hoc
   additions.
2. The paper has a readable claim relevant to at least one SuperCents_X
   component: entry decision (FVG/BOS/CHOCH/liquidity/order block/
   swing/confidence), exit/TP policy, risk framing, or market
   microstructure as it bears on the entry engine.
3. The paper's topic folder maps to a named hypothesis area in section 1.

**Exclusion:**
1. Papers whose claims are outside the entry/exit decision scope (pure
   portfolio, pure execution routing, non-mechanical trading) are
   classified as OUT-OF-SCOPE with a one-line reason — never silently
   dropped.
2. Papers with no extractable claim after one read pass are classified
   as NO-CLAIM with a note; they are listed but not mapped.
3. Duplicate content (same paper, different file) is one entry; the
   duplicate file is noted on the row.

Every paper gets exactly one ledger entry (section 7), whether included,
out-of-scope, or no-claim — the ledger must account for all 36 files.

## 5. Paper-quality classification (P-levels)

Applied to the paper as a whole before claim extraction:

| Level | Name | Criteria |
|---|---|---|
| P1 | Peer-reviewed empirical | Journal/conference reviewed; reproducible methods section; data described; statistical analysis present |
| P2 | Preprint empirical | arXiv/SSRN-style; empirical method and data described; not yet peer-reviewed (recency noted) |
| P3 | Peer-reviewed theoretical | Formal model/derivation; no (or minimal) empirical test; math/simulation-based claims |
| P4 | Practitioner / expository | Vendor, blog, textbook-style; mechanism descriptions without formal method |
| P5 | Unsupported / no method | Claims without method, data, or derivation; cannot be evaluated |

P-level is recorded per paper and per claim (a P4 paper may contain a
claim supported by a P1 citation; the claim's strength follows its own
evidence, section 6 — guardrail 5).

## 6. Evidence-strength scale (E-levels, per claim)

| Level | Name | Criteria |
|---|---|---|
| E1 | Directly tested on relevant market | Claim directly measured on liquid FX (or the asset class SuperCents_X trades); sample, period, statistic reported; effect survives the paper's own tests |
| E2 | Tested on adjacent market/regime | Direct test but on other markets (equities, crypto), different period, or different microstructure; transfer is an assumption, recorded |
| E3 | Theoretical / model-derived | Formal argument or simulation establishes plausibility; no direct market evidence |
| E4 | Anecdotal / practitioner | Mechanism asserted from experience or case study; no formal evidence |
| E5 | Unsupported assertion | Claim stated with no evidence trail |

An E-level is assigned per claim, not per paper. E1 requires the
specific mechanism (not a cousin mechanism) to have been tested.

## 7. Claim extraction rules

1. **One row per claim** — a paper yields as many claim rows as it has
   distinct claims (target: 1–6 per paper; more is a warning that
   claims are being over-split).
2. **Verbatim anchor** — each claim row stores a short verbatim quote
   (or exact §/page reference) so the row is traceable to the source
   text.
3. **Claim form** — written as a falsifiable statement about the
   mechanism SuperCents_X cares about ("X causes Y under conditions Z"),
   not as a topic summary.
4. **No reviewer translation without marking** — the ledger separates:
   (a) the paper's claim, (b) the reviewer's paraphrase, (c) the
   reviewer's interpretation. All three fields are mandatory (section 8).
5. **One claim, one direction** — a row asserting both "X improves
   entries" and "X worsens exits" is split into two rows.
6. **Sign and population recorded** — each claim row records the
   direction of the finding and the population it was tested on
   (market, timeframe, period, sample size when reported).
7. **Missing information is recorded, not assumed** — absent sample
   size / period / statistic is marked NOT-REPORTED, never inferred.

## 8. Separation of evidence types (per claim row)

Every claim row carries exactly one of four tags (guardrail 4):

| Tag | Meaning |
|---|---|
| EMPIRICAL | The paper reports a measurement the claim rests on |
| THEORETICAL | The paper derives/argues the claim formally or by simulation |
| INTERPRETATION | The claim is the author's reading of their results (author's interpretation) |
| UNSUPPORTED | The claim appears with no supporting evidence in the paper |

A row may carry EMPIRICAL for its evidence AND a second row for the
author's INTERPRETATION of that evidence — the tags must never merge.

## 9. Mapping schema (the core record)

Each claim row is mapped through the chain:

```
Paper → Claim → Evidence → SuperCents_X assumption → Gap → Hypothesis
```

| Field | Content |
|---|---|
| Paper | File id, title, P-level, topic |
| Claim | Falsifiable statement (section 7) |
| Evidence | E-level + what was measured, on what population |
| SuperCents_X assumption | The assumption(s) in the current engine this claim touches (named component: detector, floor, weight, validator, entry planner, TP/exit policy, telemetry) |
| Gap | What the engine does today vs what the evidence implies; marked NONE if the engine already matches |
| Hypothesis | A candidate falsifiable hypothesis for SuperCents_X — only if a gap exists; else NONE |

The Gap column determines whether the row feeds Phase 4. Rows with
NONE-gap are recorded and dropped from the shortlist.

## 10. Conflict / contradiction handling

1. Two claims with the same SuperCents_X assumption but opposing
   directions (or opposing E-levels on the same mechanism) are entered
   as **conflicting pair** rows — both stay, each with its own evidence.
2. The ledger does not resolve conflicts. The conflict summary (Phase 3)
   lists them with their evidence asymmetry, if any.
3. A conflict resolved by evidence asymmetry (E1 vs E3) is noted as
   "asymmetric" — still not resolved by fiat.
4. A conflict between a paper claim and the frozen ED01 empirical
   results (e.g., a paper asserting a liquidity edge vs ED01-B's REJECT)
   is recorded explicitly as an **ED-sequence conflict row** — the ED01
   result is itself evidence (E1-level for the SuperCents_X population,
   per ED01-A→E), and the ledger says so.
5. Any conflict that survives to Phase 4 is flagged on the shortlist
   row as "conflict unresolved — experiment needed".

## 11. Publication / data-quality rules

1. **Version and recency** — publication year recorded; pre-prints
   (P2) marked; claims whose evidence predates a structural market
   change (per reviewer judgment, recorded) are flagged REGIME-AGE.
2. **Data quality flags** — NOT-REPORTED sample/period/statistic is
   recorded (section 7.7); survivorship, in-sample-optimization, and
   look-ahead risks are noted when apparent in the method (WARNING
   flag on the row).
3. **Reproduction** — a paper whose central result could not be
   reproduced from its own described method (per reviewer attempt,
   recorded) is downgraded one E-level on that claim and flagged
   REPRO-FAIL.
4. **Conflict of interest / provenance** — vendor-produced material
   (P4/P5) is flagged COMMERCIAL; claims from such sources cannot
   reach E1/E2 solely on the paper's own evidence.

## 12. No architectural changes during review

1. The review has zero engineering dependency: no telemetry change, no
   detector change, no outcome-sim change, no fingerprint impact, no
   B8 interaction.
2. If the review identifies a telemetry gap needed to test a
   hypothesis (Phase 4 "Required telemetry" field), that gap is
   recorded as a requirement on the shortlist row — implementing it is
   a Sprint 22+ engineering task under the ED discipline, never a
   Sprint 21 action.
3. Existing ED01 evidence is referenced as-is (frozen artifacts); the
   review does not re-analyze ED01 data.

## 13. Pre-registration rules for resulting experiments

1. No hypothesis from the ledger becomes an experiment until it passes
   Phase 4 (full shortlist schema, section 16) and is pre-registered:
   protocol document, freeze approval, gates, decision ladder,
   analysis plan, dedicated commits — the ED01-A→E pattern.
2. The shortlist row IS the pre-registration seed: its fields (null
   hypothesis, IV/DV, population, control/treatment, materiality,
   test, failure condition) carry into the protocol verbatim or with a
   §16-style amendment record.
3. Experiments requiring production-code changes additionally require
   TDD RED→GREEN + TT01 full gate before any run (ED01-D/E precedent).
4. A hypothesis that fails pre-registration review is returned to the
   ledger as a gap row with the rejection reason — not silently
   dropped.

## 14. Phase 2 — 36-paper classification

1. Papers are processed per topic folder (FVG, BOS, CHOCH, Liquidity,
   Order Block, SMC, Swing), one ledger entry per paper, rows per
   claim (section 7).
2. Each topic folder's classification ends with a **topic summary**
   (counts by P-level and E-level, claim directions, conflicts within
   the topic).
3. A classification **self-check** closes Phase 2: (a) all 36 files
   have entries (included / out-of-scope / no-claim — never absent),
   (b) every claim row has all mandatory fields, (c) every row carries
   exactly one evidence tag, (d) no mapping row has an empty Gap cell
   (NONE is an explicit value).
4. The self-check result is recorded with the ledger before synthesis.

Ledger file: `docs/Sprint21_EvidenceLedger.md` (populated from the
template `docs/Sprint21_EvidenceLedger_Template.md`). Raw PDFs remain
untracked (user decision 2026-08-10: keep uncommitted, decide after
review).

## 15. Phase 3 — Evidence synthesis (deliverables)

From the completed ledger, the synthesis report (`docs/Sprint21_Synthesis.md`)
produces, per section:

1. **Strongly supported mechanisms** — ≥ 2 independent E1 claims
   agreeing in direction, no conflicting E1/E2.
2. **Moderately supported mechanisms** — 1–2 E1/E2 claims, or ≥ 2 E2
   agreeing; conflicts absent or asymmetric.
3. **Weak / limited evidence** — single E2/E3 claims; flagged as
   hypothesis-generating only.
4. **Contradictory findings** — all conflicting pairs (section 10)
   with their evidence asymmetry.
5. **Unsupported SMC assumptions** — E5 claims and SMC-mechanism
   assertions that the evidence does not support; each paired with the
   SuperCents_X assumption it touches (section 9).
6. **Current SuperCents_X implementation gaps** — the Gap column
   aggregated by component (detector/floor/validator/planner/exit),
   ranked by (evidence strength × assumption exposure).
7. **Highest-value research hypotheses** — the rows that survive to
   Phase 4, ranked by evidence strength, gap size, and engineering
   cost estimate (rough, for ranking only).

Synthesis is descriptive — it ranks, it does not decide.

## 16. Phase 4 — Experiment shortlist (schema per candidate)

The UNKNOWN-family 2.5R/3R observation is handled explicitly:
- Entered in the ledger as **existing empirical observation** (ED01-E:
  H1 UNKNOWN 2.5R Δ +0.1197 CI [0.0478, 0.1935]; 3.0R Δ +0.1967 CI
  [0.0285, 0.3517]; n=117/20 days; not reproduced on M15; reported-not-
  weighed per ED01-E protocol §6).
- **Not promoted to a hypothesis by virtue of being interesting.** It
  may appear as a shortlist candidate only if the literature review
  independently justifies a mechanism for UNKNOWN-family rows (e.g.,
  evidence that these rows behave differently from labeled families),
  and then it needs its own pre-registered experiment (§13).

Each shortlist candidate records:

| Field | Requirement |
|---|---|
| Hypothesis | Falsifiable statement (from ledger row) |
| Null hypothesis | Explicit null (default: no effect / benchmark holds) |
| Independent variable | Exactly one lever, named with its range |
| Dependent variable | Named metric (Mean R, win rate, etc.) |
| Population | Exact rows/file/window/stratum definition |
| Required telemetry | What must exist to measure it; gaps marked NOT-IMPLEMENTED |
| Control | Frozen B8 CONTROL or explicit benchmark (2.0R where exit-side) |
| Treatment | Exact alternative configuration |
| OOS requirement | Which files/windows are out-of-sample |
| Materiality threshold | Pre-registered |Δ| (ED01 scale: 0.10 R) |
| Statistical test | Estimator + CI method + seed (ED01 family) |
| Failure condition | What makes the experiment reject/defer |
| Expected engineering scope | Code change estimate: NONE / SMALL / MODERATE (TDD+TT01 always if any) |

Shortlist rows are ranked but **not selected** in Sprint 21; selection is
a user decision that opens Sprint 22+.

## 17. Deliverables and execution order (frozen once approved)

1. **Protocol freeze** — this document → FROZEN on user approval;
   committed (dedicated Sprint 21 research-track commit), pushed to
   origin/main.
2. **Ledger template** — `docs/Sprint21_EvidenceLedger_Template.md`
   (committed with the freeze or immediately after).
3. **Phase 2 classification** — `docs/Sprint21_EvidenceLedger.md`
   populated; per-topic summaries; self-check recorded.
4. **Phase 3 synthesis** — `docs/Sprint21_Synthesis.md`.
5. **Phase 4 shortlist** — `docs/Sprint21_Experiment_Shortlist.md`.
6. **Review gate** — user reviews map, selects hypotheses for
   Sprint 22+; nothing executes until then.
7. **Commit discipline** — one dedicated commit per phase; no mixed
   commits; raw PDFs stay untracked until a user decision on
   repository placement.

## 18. Amendments

### 18.1 Freeze record (2026-08-10, user approval)

Frozen with the following user-approved decisions and wording safeguards
(protocol exactly as drafted; no changes at freeze):

1. **Scope approved:** Sprint 21 = research evidence ledger / literature
   review track (RL01 — protocol + ledger template first). Output is a
   research map, not code; Sprint 21 changes nothing in SuperCents_X.
2. **Protocol-first, classification-second approved:** no paper is
   classified before this protocol froze; criteria cannot drift based on
   paper content (the reason for protocol-first).
3. **All 36 papers must be accounted for:** every file in the collected
   set gets exactly one ledger entry — included / out-of-scope /
   no-claim — never silently dropped (protocol §4).
4. **Paper quality ≠ evidence strength approved:** P-levels (§5) apply
   to papers, E-levels (§6) to claims; a P4 paper's claim follows its
   own evidence, never its venue (§5 note, guardrail 5).
5. **Evidence-type separation approved:** EMPIRICAL / THEORETICAL /
   INTERPRETATION / UNSUPPORTED are separate tags, exactly one per
   claim row, never merged (§8).
6. **Conflicts recorded, not reconciled approved:** contradictory
   findings stay as conflicting pair rows with both sources; the ledger
   does not pick a winner; the synthesis reports "the literature is
   conflicting here" rather than "the literature proves X" (§10, §15.4).
7. **ED01 findings stay SuperCents_X-population evidence only:** frozen
   ED01-A→E results count as E1 evidence for the SuperCents_X
   population (ED-sequence conflict rows, §10.4) but do not
   automatically become literature-supported claims; they are not
   re-analyzed in Sprint 21 (§12.3).
8. **No hypothesis promotion without independent justification
   approved:** RL-OBS-01 (UNKNOWN-family 2.5R/3R, ED01-E) remains
   reported-not-weighed; promotion requires independent literature
   justification of a UNKNOWN-family mechanism and then its own
   pre-registered experiment (§16).
9. **No production change during Sprint 21 approved:** no code, no
   config, no B8 change, no telemetry change; telemetry gaps found by
   the review are recorded as requirements for Sprint 22+ (§12).
10. **Sprint 22+ is the execution boundary:** no hypothesis from the
    ledger becomes an experiment until it passes Phase 4 (full
    shortlist schema) and is pre-registered under the ED discipline;
    selection is a user decision (§13, §16).
11. **Execution order frozen:** protocol freeze (this document + ledger
    template, one dedicated commit) → Phase 2 classification (all 36
    papers, per-topic summaries, self-check) → STOP for review → Phase 3
    synthesis → Phase 4 shortlist → user selection → Sprint 22+
    execution. No commit mixes phases; the 36-paper folder stays
    untracked until a user decision on repository placement.

## Appendix A — Ledger template reference

The row schema (fields, tags, and examples) lives in
`docs/Sprint21_EvidenceLedger_Template.md`; the protocol above is the
binding rule set, the template is the record format. Template changes
after freeze require the same amendment discipline as protocol changes.
