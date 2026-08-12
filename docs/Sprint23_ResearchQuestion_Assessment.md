# Sprint 23 — Research-Question Venue Assessment (RL01)

Status: **ASSESSMENT COMPLETE 2026-08-12 — NO SPRINT 23 EXPERIMENT IS JUSTIFIED**
Scope owner: research review / hypothesis-selection gate (RL01 track continuation)
Date: 2026-08-12
Predecessor: Sprint 22 RL-HYP-01 decision (`docs/Sprint22_RL_HYP_01_Decision.md`, commit
`9bc8eab`) — **REJECT / NOT SUPPORTED**, closed under the current evidence universe.

---

## 1. Purpose

Sprint 23 re-assesses every candidate research venue that could reasonably open the next
experiment, and records whether any of them justifies one. Under the project's research
discipline — **no evidence → no hypothesis → no experiment** — this document is the
decision record for that assessment.

This is a **research decision, not a hypothesis**: it freezes nothing, analyzes nothing,
and changes nothing in SuperCents_X. Three research venues on the RL01 research track are
in scope: RL-CONFLICT-01, RL-OBS-01, and the RL-HYP-01 six-month archive. Engineering gaps
ED02–06 are out of scope here and are recorded as dormant in the closure record
(`docs/Sprint23_Closure.md`).

## 2. Venue summary

| Venue | Sprint 23 assessment | Status |
|---|---|---|
| RL-CONFLICT-01 | Existing RL-HYP-01 test exhausted the designated route; new sub-gaps are hypothesis-generating only | ❌ No experiment |
| RL-OBS-01 | n=117 / 20 days, M15 not reproduced, no independent mechanism | ❌ Promotion gate unmet |
| RL-HYP-01 archive | Clean null, not a power failure; reopen criteria unmet | ⏸ Parked |

## 3. Venue 1 — RL-CONFLICT-01: route exhausted → no experiment

### 3.1 What the conflict row is
RL-CONFLICT-01 is the ledger conflict row carried **UNRESOLVED** through Sprint 21:
swing-continuation profitability (E1 positive, single source RL-SWING-01, REPRO-PENDING)
vs E2 negative counter-evidence (RL-SWING-02 era-decay, RL-BOS-03 re-bounce,
RL-SWING-04 OHLCV cost ceiling). Per the Sprint 21 research-review protocol (§10),
conflicts are recorded, not resolved; resolution happens only in a pre-registered
experiment.

### 3.2 What the designated route was
Sprint 21 Phase 4 shortlisted exactly one candidate seeded by this conflict row:
RL-HYP-01 (swing-significance admission gate vs the ungated 2.0R benchmark). It was
carried to Sprint 22, frozen as a full pre-registration, and executed. Sprint 22 produced
a clean decision: **REJECT / NOT SUPPORTED** — a clean null, not a power failure
(primary EURUSD_H1 n=1,420 / 63 paired days; max |Δ| = 0.0261R; every 95% and 98.33%
Bonferroni CI includes 0). RL-CONFLICT-01 remains UNRESOLVED with one more pre-registered
data point.

### 3.3 Why no experiment is justified now
The seed carried by the conflict row has been tested and rejected. What remains of the
conflict row — alternative swing-significance definitions, alternative ATR periods,
prominence-based or adaptive thresholds — is **hypothesis-generating only**: those are new
hypotheses, not new evidence. Under the Sprint 22 protocol §13 and decision §11, a new
definition or tier set requires a §16-style amendment record and, per the reopen
discipline, genuinely new evidence — never re-analysis of the tested population with
different thresholds.

**Decision: NO EXPERIMENT.** RL-CONFLICT-01 stays UNRESOLVED on record. No sub-gap raised
by the rejected test is promoted into a new experiment in Sprint 23.

## 4. Venue 2 — RL-OBS-01: promotion gate unmet

### 4.1 What the observation is
RL-OBS-01 is a recorded observation (**not a hypothesis**): the exploration stratum from
ED01-E (Sprint 20) where UNKNOWN-family rows on the fixed wider tiers showed
- EURUSD_H1 UNKNOWN 2.5R: +0.1197R, CI [0.0478, 0.1935]
- EURUSD_H1 UNKNOWN 3.0R: +0.1967R, CI [0.0285, 0.3517]
- **n = 117 closed rows over 20 paired days**
- **not reproduced on the EURUSD_M15 stability population (n = 49)**

Per the ED01-E protocol, this stratum was recorded, reported-not-weighed, and explicitly
non-actionable — no carve-out.

### 4.2 What the promotion gate requires
Per the Sprint 21 research-review protocol (§16) and shortlist (§4.5): a recorded
observation may be promoted to a hypothesis only with an **independent literature
justification of the mechanism** (here: a justification of an UNKNOWN-family mechanism),
followed by its own pre-registered experiment. Sprint 21 Phase 2/3 produced no such
justification; Sprint 22 recorded the observation as remaining REPORTED-NOT-WEIGHED.

### 4.3 Why the promotion gate is unmet
- **Evidence stability:** n = 117 / 20 days is n-constrained; the stability population
  (M15, n = 49) did not reproduce the finding.
- **Independent mechanism:** no literature justification of an UNKNOWN-family mechanism
  exists in the ledger.

Both halves of the gate must pass; neither does.

**Decision: NOT PROMOTED.** RL-OBS-01 remains REPORTED-NOT-WEIGHED. No experiment is
derived from it in Sprint 23.

## 5. Venue 3 — RL-HYP-01 six-month archive: reopen criteria unmet (parked)

### 5.1 What the archive is
The reserved follow-up venue designated by the Sprint 22 decision (§11) and protocol
(§13): the 46-run 6-month archive `Tools/ED01/artifacts_6mo_2026-01-05_07-05/` — the one
place a re-test of the same frozen swing-gate protocol may be run on genuinely new
evidence.

### 5.2 The re-test is not automatic
The archive is a venue, not an authorization. Reopening RL-HYP-01 requires:
1. genuinely new evidence under the frozen discipline (the archive run set is not an
   automatic replacement for the rejected 12-run set), and
2. a §16-style amendment record if the definition/tier set changes, and
3. structural reachability: any future swing-gate protocol must register tiers with
   gated-out share ≥ 10% for the primary estimand (Sprint 22 decision §11).

### 5.3 Assessment
The Sprint 22 null is clean, not a power failure — the measured power resolves the 0.10R
materiality bar, so reopen cannot be claimed on a power argument. Since the REJECT, no new
evidence has appeared, no §16 amendment has been proposed or approved, and no re-test has
been authorized.

**Decision: PARKED.** RL-HYP-01 remains closed under the current evidence universe; the
archive stays reserved and unopened.

## 6. Final conclusion

**NO SPRINT 23 EXPERIMENT IS JUSTIFIED.**

- None of the three research venues yields a hypothesis that clears the project's evidence
  bar.
- No candidate is ranked, no pre-registration seed is produced, no engineering prerequisite
  is authorized.
- The negative outcome of this assessment is itself the Sprint 23 result — preserved as a
  decision, not papered over with an experiment merely because an engineering capability
  exists.

## 7. Boundaries recorded

- Guardrail 1 holds: no production change, no code, no config, no B8 change, no telemetry
  change.
- This assessment is a decision record, not a protocol; it freezes nothing.
- RL-OBS-01 stays REPORTED-NOT-WEIGHED regardless of any future outcome; a second
  promotion attempt would require new, independent literature justification.
- RL-CONFLICT-01 stays UNRESOLVED.
- ED02–06 engineering gaps are out of scope for this assessment and remain dormant
  (closure record).

---

*Sprint 23 research-venue assessment, 2026-08-12. Authoritative Sprint 23 research record.
Companion closure record: `docs/Sprint23_Closure.md`. No production change; nothing
committed beyond this decision record.*