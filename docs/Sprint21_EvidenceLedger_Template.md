# Sprint 21 — Evidence Ledger Template (RL01)

Status: **FROZEN on user approval 2026-08-10** (protocol §18.1) — the
template is exactly as drafted; no changes at freeze. Per-paper rows are
populated only in Phase 2, after this freeze.
Purpose: one ledger entry per paper (all 36 files accounted for —
included / out-of-scope / no-claim), one claim row per distinct claim,
mapped through Paper → Claim → Evidence → SuperCents_X assumption →
Gap → Hypothesis.

---

## 1. Ledger conventions

- Append-only: revisions are annotations, never edits.
- Every row: exactly one evidence tag (§8 of the protocol), all
  mandatory fields, Gap = explicit value (never empty).
- Verbatim anchors required on every claim row (quote or §/page).
- Raw PDFs stay untracked; the ledger is plain markdown rows.

## 2. Paper-level record (one per paper)

```
| Field | Value |
|---|---|
| Paper ID | RL-<topic>-<nn> (e.g., RL-LIQ-01) |
| File | research paper/<topic>/<filename> |
| Title | <title> |
| Topic | FVG / BOS / CHOCH / LIQUIDITY / OB / SMC / SWING |
| Year | <year> |
| P-level | P1 / P2 / P3 / P4 / P5 (protocol §5) |
| Venue/type | peer-reviewed / preprint / practitioner / other |
| Status | INCLUDED / OUT-OF-SCOPE / NO-CLAIM (+ one-line reason) |
| Read pass | <date>, <reviewer> |
| Claim rows | <count> |
```

## 3. Claim-level record (one row per claim)

```
| Field | Value |
|---|---|
| Claim ID | RL-<topic>-<nn>-C<mm> |
| Paper ID | RL-<topic>-<nn> |
| Verbatim anchor | "<quote>" / §<section> p.<page> |
| Claim (falsifiable) | <X causes Y under conditions Z> |
| Evidence tag | EMPIRICAL / THEORETICAL / INTERPRETATION / UNSUPPORTED |
| E-level | E1 / E2 / E3 / E4 / E5 (protocol §6) |
| Population tested | <market, timeframe, period, sample n — NOT-REPORTED if absent> |
| Direction | positive / negative / null / not-stated |
| SuperCents_X assumption | <named component: detector/floor/weight/validator/planner/exit/telemetry — or NONE> |
| Gap | <what the engine does vs what evidence implies — explicit NONE if none> |
| Hypothesis | <falsifiable candidate — NONE if no gap> |
| Flags | REGIME-AGE / REPRO-FAIL / COMMERCIAL / WARNING-<risk> / — |
| Reviewer paraphrase | <reviewer's restatement, marked as such> |
| Reviewer interpretation | <reviewer's reading, marked as such> |
```

## 4. Conflict rows

```
| Field | Value |
|---|---|
| Conflict ID | RL-CONFLICT-<nn> |
| Claims | RL-<topic>-<nn>-C<mm> vs RL-<topic>-<nn>-C<mm> |
| SuperCents_X assumption | <shared assumption being contradicted> |
| Directions | <claim A direction> vs <claim B direction> |
| Evidence asymmetry | <E-levels; asymmetric if one dominates> |
| ED-sequence relation | <ED01-A..E result if this conflicts with it — ED01 results count as E1 for the SuperCents_X population> |
| Resolution | UNRESOLVED — experiment needed (ledger never resolves) |
```

## 5. Topic summary (per folder, end of Phase 2)

```
| Topic | papers | P-level counts | E-level counts | claims | directions (pos/neg/null) | intra-topic conflicts |
```

## 6. Phase 2 self-check (recorded before synthesis)

| Check | Result |
|---|---|
| All 36 files have entries (included / out-of-scope / no-claim) | PASS / FAIL — <n> |
| Every claim row has all mandatory fields | PASS / FAIL — <n> |
| Every row carries exactly one evidence tag | PASS / FAIL — <n> |
| No mapping row has an empty Gap cell (NONE is explicit) | PASS / FAIL — <n> |
| Verbatim anchors present on all claim rows | PASS / FAIL — <n> |

## 7. Phase 3 synthesis input table (auto-aggregated)

```
| Mechanism area | claims (IDs) | E-levels | direction agreement | tier |
```

Tier: STRONG / MODERATE / WEAK / CONTRADICTORY / UNSUPPORTED (protocol §15).

## 8. Phase 4 shortlist candidate (pre-registration seed — protocol §16)

```
| Field | Value |
|---|---|
| Candidate ID | RL-HYP-<nn> |
| Hypothesis | <from ledger row> |
| Null hypothesis | <explicit null> |
| Independent variable | <one lever + range> |
| Dependent variable | <metric> |
| Population | <rows/file/window/stratum> |
| Required telemetry | <needed; NOT-IMPLEMENTED if absent> |
| Control | <frozen B8 CONTROL / explicit benchmark — 2.0R where exit-side> |
| Treatment | <exact alternative> |
| OOS requirement | <files/windows out-of-sample> |
| Materiality threshold | <|Δ|, ED01 scale: 0.10 R> |
| Statistical test | <estimator + CI + seed> |
| Failure condition | <reject/defer rule> |
| Expected engineering scope | NONE / SMALL / MODERATE (+ TDD+TT01 if any) |
| Conflict flags | <unresolved conflicts carried from §4> |
| Selection status | NOT-SELECTED (user decides, Sprint 22+) |
```

---

## Appendix — Registered observations (not hypotheses)

Existing empirical observations entered here, explicitly NOT promoted
(protocol §16):

| Observation ID | Source | Finding | n / days | Reproduction | Status |
|---|---|---|---|---|---|
| RL-OBS-01 | ED01-E (2026-08-09) | H1 UNKNOWN-family: 2.5R Δ +0.1197 CI [0.0478, 0.1935]; 3.0R Δ +0.1967 CI [0.0285, 0.3517] | 117 / 20 | NOT reproduced on M15 (n=49); GBPJPY n=23 n-constrained | REPORTED-NOT-WEIGHED — hypothesis only if the literature independently justifies a UNKNOWN-family mechanism, then pre-registered (§16) |
