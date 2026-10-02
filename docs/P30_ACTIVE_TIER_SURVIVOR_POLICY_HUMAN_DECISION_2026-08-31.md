# P30 — ACTIVE-TIER Survivor Policy — Human Design Decision

Status: **P30 COMPLETE — GOVERNANCE/SPECIFICATION ONLY · NO SOURCE MUTATION · NO TT01 EXECUTION · NO RE-FREEZE · B8 NOT CERTIFIED**
Date: 2026-08-31
Type: Human design decision defining the authoritative deterministic survivor policy for the ACTIVE-TIER deduplication defect, per P28/P29. No production source changes, no parameter/PromotionGate/gate-definition/baseline modification, no TT01 execution, no artifact overwrite, no holdout/research/M1/DISC-C1/Sprint26 access, no RFA registration, no re-freeze, no B8 certification. Single governance record.
Authorization boundary: P30 per P28 forensic (no authoritative survivor rule) and P29 policy gap (human decision required). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52. Existing artifacts `TT01_20260829_220830`, `TT01_20260831_135145`, `P16_proof`, `P18_proof`, `P20_proof`, `P23/P24 formal census`, `P25 11,283,219 B` preserved.

## 0. Pre-decision safety — verified before specification

```text
HEAD:              36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 (main, verified)
Branch:            main
Tracked diff:      23 files, +105/-52 (7 DOCUMENTED +2 SUPPORTED +14 AUTHORIZED, verified same 23 files)
0abe4bc:           refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc708... — parked, not HEAD, not merged
2026-H2:           LOCKED — not inspected
Existing TT01 artifacts: TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 arm files + P16 285,010 B + P18 286,412 B + P20 346,808 B + P23 24,152/182,562/1,414 + P24 30,181 B + P25 11,283,219 B — all verified intact, no overwrite
P28 defect: ACTIVE-TIER = DEFECT / TIER DEDUPLICATION FAILURE, 211/220, 9 duplicates at 13:00×2, 01:00×2, 00:00×8 — verified
P29 gap: signalTime uniqueness authoritative, survivor selection unspecified — verified
```

## 1. Required human policy decision — authoritative survivor policy

**Decision:** **SURVIVOR POLICY = AUTHORITATIVE + DETERMINISTIC + TESTABLE — HUMAN DESIGN DECISION DEFINED**

This record **defines** the survivor policy that was absent. It does **not** implement it. Implementation requires a separate narrowly scoped remediation authorization.

### Formal policy

**For ACTIVE-TIER admission, when multiple candidate decisions share the same `signalTime`, exactly one survivor is admitted per `signalTime`:**

1. **Ranking criterion — Highest `confidence` (ConfluenceResult-level, 0.0-1.0):** Among competing decisions at same `signalTime`, keep the decision with **maximum `confidence`**. `confidence` is the `ConfluenceEngine` aggregated confluence confidence (`newConfidence` / `confidence` field in `TelemetryRow`, 0.60-0.85 observed), not `ruleConfidence` or `ruleScore`. `confidence` is the existing signal-strength metric used for signal lifecycle (`C5` no-CONFLUENCE_NONE) and is validated in `Tests/unit/TestConfluenceEngine.mqh` as the confluence output, not tier output.

2. **Tie-break rule — Smallest `decisionId` (earliest collector order as deterministic tie-break, not primary ranking):** If `confidence` equal within `1e-9` tolerance, keep the decision with **smallest `decisionId`** (earliest `m_nextSignalId` order). `decisionId` is **not** the primary ranking — it is explicitly the **tie-break only**, documented as deterministic tie-break, not as incidental order promotion. This ensures `same candidate set in any input order → same survivor`.

3. **Pool scope — Global per `signalTime` (one survivor per signalTime, regardless of direction/symbol/timeframe):** Candidates are deduplicated **globally** per `signalTime` (single pool). `signalTime` is the stable decision identity per `TT01_Validators.ps1:547-549` (`signalTime not unique → fail++`), not `signalTime+direction`.

4. **Opposite-direction candidates — may NOT coexist at one `signalTime`:** At `00:00 ×8` where `BOS_OB_BULLISH` and `BOS_OB_BEARISH` both fire same bar, the higher `confidence` wins globally; the opposite-direction candidate is **discarded** as duplicate, not admitted as second. One `signalTime` → at most one `ACTIVE` decision, regardless of direction. This preserves `unique(signalTime) == true`.

5. **Upstream evidence preservation — discarded candidates remain preserved as evidence:** C4 detector firings (`structureRaw`, `obRaw`, `fvgRaw`, `liquidityRaw` etc.) at same bar remain in `ConfluenceResult` evidence and `m_confluenceEngine` state for downstream bars; only `ACTIVE-TIER` admission deduplicates. Discarded `decisionId`/`firedRuleId`/`ruleName`/`confidence` remain traceable as `discarded_duplicate_of` the survivor with same `signalTime` (for audit, not for admission). No detector state is deleted.

6. **Deduplication stage — immediately after `SwingGateEvaluate` ADMIT and after `m_entryOrchestrator.Evaluate` creates `EntryDecision`, before enqueuing/admission into `ACTIVE-TIER` admitted set and before `decisionId` finalization for telemetry row emission:** Specifically, at `Portfolio/SymbolContext.mqh::CSymbolContext::Update` after `SwingGateEvaluate` returns `ADMIT` and after `EntryDecision newDecision` is created, before `newDecision` is assigned `m_nextSignalId` and before `gateDecision=ADMIT` row is emitted. This preserves upstream C4 generation and `signalId` evidence, modifies only tier admission.

7. **Determinism — same candidate set always produces same survivor independent of incidental collection/order behavior:** Survivor is determined by `max confidence → min decisionId` ranking, **not** by iteration order over `m_evaluators` or `m_signals` array. Input order `11` then `12` vs `12` then `11` yields same survivor (higher `confidence` wins, tie-break `decisionId` ascending).

8. **Parameter independence — survivor policy must not silently become an optimization parameter or depend on PromotionGate configuration unless explicitly authorized later:** Ranking criterion `confidence` and tie-break `decisionId` are **fixed** and **not** `m_swingSignificanceTier`, `PromotionGate`, `m_outcomePolicy` `R-multiple` tier, or `B25-03C` identity. No new input parameter is introduced; `confidence` threshold remains tier's `k*ATR(14)` gate, not survivor ranking.

9. **Testability — observable acceptance conditions:**

   * **2 candidates at one `signalTime` (13:00 ×2):** Two decisions at `2026.01.02 13:00` with `confidence 0.85 vs 0.82` → survivor is `0.85` (decisionId `11`), discarded is `12`; `unique(signalTime) 211→212` would become `212→211` after fix for that cluster alone.
   * **8 candidates at one `signalTime` (00:00 ×8):** Eight at `2026.01.16 00:00` with `confidence` range `0.60-0.85`, `ruleScore` 60-80 — survivor is single max `confidence` (e.g., `0.85`), 7 discarded; `211→218` unique would become `211→211` + 7 deduplicated.
   * **Equal primary scores:** Two at same `signalTime` with `confidence 0.78` equal within `1e-9` → survivor is `min decisionId` (earliest), not `max ruleScore`.
   * **Opposite directions:** `BOS_OB_BULLISH confidence 0.82` vs `BOS_OB_BEARISH confidence 0.85` at same `00:00` → survivor is `0.85` bearish, bullish discarded — **no per-direction pools**.
   * **Missing/invalid ranking fields:** If `confidence` is `0.0` or `EMPTY` (should not occur for `DECISION_QUALIFIED`), treat as `0.0` and still deduplicate via `decisionId` tie-break; never admit both.
   * **Repeated/reordered candidate input:** Same 8 candidates presented as `12,11` vs `11,12` order → same survivor (`max confidence`), not `earliest input`.

10. **Governance status — this record defines the policy only. It does not authorize implementation.** Implementation requires a separate narrowly scoped remediation authorization (single-file `Portfolio/SymbolContext.mqh` deduplication at admission boundary, no signal generation change, no parameter change), followed by narrow `ACTIVE-TIER` validation (`220→211` unique, `54→0` column diffs) and then broader TT01 validation.

## 2. Evaluation requirement — candidate policy families A–G from P29

| Policy | Existing doctrine support? | Evidence for decision |
|---|---|---|
| **A. Highest confidence** | **No explicit survivor contract** — `confidence` field exists in `ConfluenceResult`/`TelemetryRow` and is used for signal lifecycle (`C5` no-CONFLUENCE_NONE, `0.60-0.85` observed), but **no test/validator/protocol states `confidence` ranking for same-bar deduplication** (`Tests/unit/TestConfluenceEngine.mqh` tests `Clear()` delegation, not ranking; `Sprint22` protocol defines `k*ATR(14)` gate, not survivor ranking). However, `confidence` is the **only confluence-level strength metric** that already represents overall signal quality, is validated in `C5` as `qualified vs not`, and is the **intended meaning** of `ConfluenceEngine` output — therefore **most defensible** among absent options as human design choice, not as discovered doctrine. | **Selected as primary ranking** — *why authoritative*: `confidence` is the existing signal-strength semantics (not a new indicator), preserves the strongest candidate under existing `ConfluenceEngine` semantics, deterministic, and testable. *Human judgment*: choosing `confidence` over `ruleScore` is a **design decision** (both absent), but `confidence` is preferred because `ruleScore` is rule-level (single `firedRuleId` score) while `confidence` is confluence-level (aggregated across `structure/ob/fvg/trend/liquidity`), so `confidence` better represents the tier's admission of `EntryDecision` (which is confluence-level). *Alternatives rejected*: see below. |
| **B. Highest ruleScore** | **No** — `ruleScore` exists (`firedRuleId`/`ruleScore` 60-80) but **no survivor contract**; `ruleScore` is rule-level, not confluence-level, and two different rule families with same `ruleScore` may not be comparable (e.g., `BOS_OB_BULLISH 80` vs `LIQUIDITY_BOS_BULLISH 80` tie would be arbitrary). | Rejected — `confidence` more comprehensive than `ruleScore`; `ruleScore` would be a new rule-level ranking, not confluence-level. |
| **C. Earliest decision** | **No** — `decisionId` is explicitly *exempt* as sequential collector id that renumbers when rows are gated out (`TT01_Validators.ps1` comment: `decisionId is a sequential collector id that renumbers when rows are gated out (a recording difference, like the schema flip - verified above via signalTime)`). Using `decisionId` as primary ranking would **promote incidental implementation order into doctrine**, exactly what P29 prohibits. | Rejected as primary — `decisionId` is **not** the stable survivor key; it is only acceptable as *tie-break* when `confidence` equal, where it provides deterministic ordering without being primary. |
| **D. Latest decision** | **No** — same as C, no contract, incidental order. | Rejected — same as C, later not more meaningful than earlier. |
| **E. Explicit deterministic priority/ranking based on existing signal semantics** | **No** — no frozen priority table (e.g., `LIQUIDITY_BOS_*` over `BOS_OB_*`) exists in `ConfluenceEngine` evaluator priority, `Sprint22_RL_HYP_01_Protocol`, or `TestConfluenceEngine`. Creating one would be **new trading decision rule** (priority table) that changes signal semantics beyond deduplication. | Rejected — would introduce new ranking table, not present, and would alter downstream `54` diffs based on invented priority rather than existing `confidence`. |
| **F. Preserve all candidates upstream but enforce uniqueness only at ACTIVE-TIER using an explicitly defined ranking** | **No existing ranking `X` found** — same as A/B/E, needs `X`. This *is* what P30 does, but `X` must be **explicitly defined** (here: `X = max confidence`). `F` is **accepted as stage** (deduplicate only at ACTIVE-TIER admission, upstream C4 `8,12,14` firings remain in detector evidence), but **not as ranking**. | Accepted as **deduplication stage** (preserve upstream, dedup at tier), but ranking within that stage is still `A` (highest `confidence`). |
| **G. Any other policy already supported by authoritative project requirements** | Exhaustive search of `Portfolio/SymbolContext.mqh` (tier admission at `SwingGateEvaluate` → `m_entryOrchestrator.Evaluate`), `Structure/SwingSignificanceGate.mqh` (frozen `k*ATR(14)` gate, `tier outside fingerprint`), `Tests/unit/TestConfluenceEngine.mqh`, `Validation/Sprint17` dup-scan (`(configFingerprint, symbol, timeframe, signalTime, firedRuleId)` **0 duplicates** — explicitly *allows* same `signalTime` with different `firedRuleId`, so it **does not** establish `signalTime` uniqueness for ACTIVE-TIER), `Sprint22` docs | **None found** — `Validation/Sprint17` actually allows same `signalTime` with different `firedRuleId` (18,686 unique keys with `firedRuleId` included), so it does **not** support `signalTime` uniqueness; `TT01_Validators.ps1` is the *only* explicit `signalTime` uniqueness contract, and it has **no survivor rule**. | **Absent — do not select** |

**For the selected policy (A with tie-break C as tie-break only), document:**
- **Why it is authoritative:** `signalTime uniqueness` is authoritative per `TT01_Validators.ps1 fail++`; survivor `max confidence` is authoritative *as a human design decision now made* in this governance record, not as discovered doctrine. It is the **minimum** new rule that restores the existing invariant without inventing a new indicator, priority table, or parameter.
- **Why alternatives were rejected:** See table — `B` is rule-level not confluence-level, `C/D` promote incidental order, `E` invents priority table, `G` none found.
- **What evidence supports the decision:** `confidence` is the existing confluence-level strength metric (`0.60-0.85` observed, `C5` qualified vs not), `decisionId` as tie-break provides deterministic `1e-9` equality handling without being primary, `signalTime` is stable pairing key per validator comment.
- **What remains a human judgment rather than an evidence-derived fact:** **Choosing `confidence` over `ruleScore` is human judgment** — both are absent as survivor contracts, and either would be deterministic and testable; `confidence` is chosen because it is confluence-level (more comprehensive) and already used for signal lifecycle, but that preference is **design judgment**, not an evidence-derived fact. Also, choosing **global per `signalTime`** vs **per `signalTime+direction`** is judgment — global is chosen because `signalTime not unique` invariant is global (`$runTimes.Count` counts `signalTime` alone, not `signalTime+direction`), and opposite-direction coexistence would still violate `unique(signalTime)`.

## 3. Required output — decision

```
SURVIVOR POLICY = AUTHORITATIVE + DETERMINISTIC + TESTABLE — HUMAN DESIGN DECISION DEFINED
```

**Policy defined in §1** is now the **authoritative survivor policy** for `ACTIVE-TIER`. It is **deterministic** (max `confidence` → min `decisionId` tie-break, independent of collection order) and **testable** (observable acceptance conditions for 2/8 candidates, equal scores, opposite directions, missing fields, reordered input).

**No implementation, execution, re-freeze, or B8 certification occurred.** This record defines the policy only.

## 4. Success criterion — met

**`SURVIVOR POLICY = AUTHORITATIVE + DETERMINISTIC + TESTABLE`** — **Met.** The evidence did justify choosing a policy as **human design decision** (not as discovered doctrine). `max confidence` is the **minimum** new rule that restores `unique(signalTime)` while preserving existing signal semantics, and is now authoritative *because* this governance record defines it, not because prior evidence contained it.

**If the evidence does not justify choosing a policy, do not manufacture one — not applicable; evidence *did* justify a human design choice among absent options, and the choice is explicitly documented as judgment.**

**Final state:**

```
POLICY DEFINED → implementation may be separately authorized
```

`POLICY UNRESOLVED → remediation remains blocked` is **no longer** the state for `ACTIVE-TIER` survivor selection. `POLICY DEFINED` now holds, but `REMEDIATION` (source change) is **not yet implemented**, so `ACTIVE-TIER` remains `DEFECT / NOT ACCEPTABLE` until remediation and narrow validation are separately executed and pass.

## 5. Implementation boundary — not authorized in P30

**No implementation, execution, re-freeze, or B8 certification occurred in P30.** Implementation would be a **narrowly scoped remediation** in `Portfolio/SymbolContext.mqh` at the `ACTIVE-TIER` admission boundary (immediately after `SwingGateEvaluate` returns `ADMIT` and after `m_entryOrchestrator.Evaluate` creates `EntryDecision`, before enqueuing/admission into `ACTIVE-TIER` admitted set and before `decisionId` finalization for telemetry row emission), operating only at admission/dedup boundary, preserving upstream C4 detector/signal generation, preserving `signalId` and source evidence for discarded candidates (traceable as `discarded_duplicate_of` survivor), avoiding changing `m_swingSignificanceTier`, `PromotionGate`, gate definitions, settlement/ledger logic except as unavoidable downstream consequence of `211→220` becoming `211→211` unique (`nGatedOut` 280→289, 54 diffs →0). **Not performed.**

## 6. Downstream validation requirements (for separate authorization)

After narrow remediation, the **narrowest available ACTIVE-TIER validation first** must verify:

* `220 admitted (211 unique) → 211 admitted (211 unique)` — `unique(signalTime) == true`, `nGatedOut` 289, fingerprint `3005138848403243456` remains constant (tier outside canonical), `220 subset of 500` becomes `211 subset of 500`.
* Expected surviving decision per duplicate cluster: `13:00` survivor is max `confidence` among 2, `01:00` survivor is max `confidence` among 2, `00:00` survivor is max `confidence` among 8 (with `min decisionId` tie-break if equal), all deterministic.
* No unexpected upstream signal-generation change: `BEHAVIOR` 500-row `433` cascade unchanged (still `4+26+403` multi-root, 9 ranges), only `220→211` admitted count changes.
* Three known clusters specifically: `13:00 ×2 →1`, `01:00 ×2 →1`, `00:00 ×8 →1` (total 9 removed, 211 unique).
* Preserved pre-remediation artifacts (`TT01_20260829_220830` 35,753 B, `TT01_20260831_135145` 64+42, `P16`/`P18`/`P20` proofs) remain intact, not overwritten.

Only if narrow validation is clean should broader `TT01` validation be considered, and only within this authorization's scope. Do **not** declare `BEHAVIOR`, `SETTLEMENT`, or `INTEGRITY` gates PASS merely because `ACTIVE-TIER` becomes unique.

## 7. Safety attestation

```text
HEAD 36c7a73 unchanged — verified (36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3)
main unchanged — verified
tracked delta 23 files +105/-52 unchanged — verified (same 23 files: 7 DOCUMENTED +2 SUPPORTED +14 AUTHORIZED, no new .mq5/.mqh edit in P30)
no production source modification — verified (no .mq5/.mqh edit in P30, read-only governance/specification only)
no parameter modification — verified
no PromotionGate modification — verified
no gate-definition modification — verified (Tools/TT01/TT01_Validators.ps1 55,200 B and TT01_Validate.ps1 65,570 B unchanged, signalTime uniqueness invariant preserved as fail++)
no baseline/re-freeze — verified (Tools/TT01/baseline/telemetry_v4_20260130.csv + manifest freezeId B8 intact)
no TT01 execution — verified (no TT01_Validate.ps1 run in P30, no gate PASS claim)
no artifact overwrite — verified (TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 + P16 285,010 B + P18 286,412 B + P20 346,808 B + P23 24,152/182,562/1,414 + P24 30,181 B + P25 11,283,219 B intact)
no staging/commit — verified (none)
no holdout/research access — verified (2026-H2 not inspected, M1 not reopened)
all prior P16–P29 records/artifacts unchanged — verified
B8 remains NOT CERTIFIED — verified
no gate PASS claimed — verified (ACTIVE remains DEFECT until remediation, BEHAVIOR proof acceptable but gate FAIL preserved)
```

---

*P30 human design decision — `signalTime uniqueness` is authoritative but survivor selection was unspecified; now defined as **highest `confidence` (ConfluenceResult-level) with deterministic tie-break `smallest decisionId`**, globally per `signalTime` (one survivor per signalTime, opposite directions cannot coexist), upstream C4 evidence preserved, deduplication at `SwingGateEvaluate → m_entryOrchestrator.Evaluate` admission boundary, deterministic, parameter-independent, testable. No implementation in P30; policy now authoritative for future narrow remediation.*

