# P29 — ACTIVE-TIER Survivor-Policy Definition

Status: **P29 COMPLETE — GOVERNANCE/SPECIFICATION ONLY · NO SOURCE MUTATION · NO TT01 EXECUTION · NO RE-FREEZE · B8 NOT CERTIFIED**
Date: 2026-08-31
Type: Governance/specification defining the minimum authoritative survivor-selection policy required to resolve the confirmed ACTIVE-TIER deduplication defect, without implementing it. No production source changes, no parameter/PromotionGate/gate-definition/baseline modification, no TT01 execution, no artifact overwrite, no holdout/research/M1/DISC-C1/Sprint26 access, no RFA registration, no re-freeze, no B8 certification. Single governance record.
Authorization boundary: P29 per P28 forensic determination (ACTIVE defect confirmed, survivor policy unspecified, 9 duplicates in 3 C4 clusters). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52.

## 0. Pre-execution safety — verified before specification

```text
HEAD:              36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 (main, verified)
Branch:            main
Tracked diff:      23 files, +105/-52 (7 DOCUMENTED +2 SUPPORTED +14 AUTHORIZED, verified same 23 files)
0abe4bc:           refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc708... — parked, not HEAD, not merged
2026-H2:           LOCKED — not inspected
Existing TT01 artifacts: TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 arm files + P16 285,010 B + P18 286,412 B + P20 346,808 B + P23 24,152/182,562/1,414 + P24 30,181 B + P25 11,283,219 B — all verified intact, no overwrite
P28 defect record: ACTIVE-TIER = DEFECT / TIER DEDUPLICATION FAILURE, REMEDIATION BLOCKED — SURVIVOR POLICY UNSPECIFIED (verified)
```

## 1. PHASE 1 — STATE THE POLICY GAP (authoritative)

**Authoritative invariant (explicit, `Tools/TT01/TT01_Validators.ps1:547-549`):**
```powershell
$runTimes = @($run | ForEach-Object { $_.signalTime } | Sort-Object -Unique)
if ($runTimes.Count -ne $run.Count) { $fail++; $detail.Add("signalTime not unique ($($runTimes.Count) unique vs $($run.Count) rows)") }
```
`ACTIVE-TIER` requires `unique(signalTime) == true` (one decision per signalTime) for `PASS`.

**Observed population (preserved P21/P22/P23/P24/P25 evidence, `TT01_20260829_220830` and `135145` both):**
- `220 admitted decisions, 211 unique signalTime values` — 9 extra admissions.
- **Nine duplicate admissions in three C4 same-bar clusters:**
  - `2026.01.02 13:00 ×2` (2 at same bar)
  - `2026.01.14 01:00 ×2` (2 at same bar)
  - `2026.01.16 00:00 ×8` (8 at same bar)
- These correspond exactly to the three C4 same-bar clusters established by P21 multi-root proof: `2026.01.02 13:00` (8 fresh vs 0 base at that bar), `2026.01.14 01:00` (12 fresh vs 0 base), `2026.01.16 00:00` (14 fresh vs 0 base) — C4 closed-bar discipline (`7d4eecb` Swing `maxCenter rates_total-4`, FVG `(3,2,1)`, Liquidity closed-bar) correctly produces **multiple detector firings at one closed bar** (multiple `LIQUIDITY_BOS_BULLISH` at same `signalTime`).
- The `54` ACTIVE outcome/settlement diffs (`timestamp/outcome/rMultiple/barsHeld/exitReason` at same 9 duplicate bars) are **downstream of those 9 duplicate admissions** (second duplicate at same `signalTime` necessarily has same `signalTime` as first but different `timestamp/outcome` due to outcome being tied to admission, not detector).
- Fingerprint `3005138848403243456` remains constant (`tier outside canonical`), `220 subset of 500` remains pure tier filter — both **PASS**.

**Policy gap:**

```
signalTime uniqueness is authoritative (fail++ when 211 !=220), but survivor selection is unspecified.
```

- **Uniqueness alone cannot determine which candidate survives** — for `2026.01.16 00:00 ×8`, 8 decisions share same `signalTime` with different `firedRuleId`/`ruleName`/`confidence`/`ruleScore`.
- **Implementation order cannot be promoted into doctrine** — current ascending `decisionId` admission order (`11` then `12`, collector order as `m_nextSignalId` increments in `ConfluenceEngine`) is **incidental implementation order**, not an explicit semantic contract (P28 Phase 2 classification `C. INCIDENTAL IMPLEMENTATION ORDER`).
- **No remediation may select a winner arbitrarily** — choosing `max confidence` vs `max ruleScore` vs `earliest` would select different survivors in the 8-way cluster (P28 Phase 3 forensics: `confidence 0.85` vs `ruleScore 80` orderings diverge).

## 2. PHASE 2 — DEFINE POLICY OPTIONS, NOT IMPLEMENTATION (semantics only)

**Evaluated strictly from project evidence (23-file delta, ConfluenceEngine, SwingSignificanceGate, existing tests, frozen Sprint-22 protocol):**

| Option | Semantics | Existing doctrine support? | Preserves intended meaning of signal? | Deterministic? | Preserves strongest candidate under existing semantics? | Introduces new trading decision rule? | Could alter downstream 54 diffs / BEHAVIOR evidence? | Requires changing signal generation or only ACTIVE-TIER admission? | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| **A. Highest confidence** | Keep per `signalTime` the decision with max `confidence` (`0.85` vs `0.82`) | **No** — no test/validator/protocol states `confidence` ranking for same-bar deduplication; `confidence` field exists but no survivor contract | Ambiguous — `confidence` is confluence-level, not tier-level | Yes if tie-broken | **No evidence** that highest `confidence` is intended strongest; `confidence` vs `ruleConfidence` vs `ruleScore` divergence not resolved | **Yes** — introduces new ranking rule | **Yes** — 54 diffs would become 0 for kept vs dropped, downstream settlement unchanged except fewer admitted rows | Only admission, but **new rule** | **Absent/ambiguous — do not select** |
| **B. Highest ruleScore** | Keep max `ruleScore` (`80` vs `78`) | **No** — same as A, no authoritative `ruleScore` survivor contract | Ambiguous — `ruleScore` is rule-level, not tier-level | Yes if tie-broken | No evidence | **Yes** — new rule | Yes | Only admission, but **new rule** | **Absent — do not select** |
| **C. Earliest decision** | Keep smallest `decisionId` (first admitted, collector order `11` before `12`) | **No** — `decisionId` is explicitly *exempt* as sequential collector id that renumbers when rows are gated out (`TT01_Validators.ps1` comment): `decisionId is a sequential collector id that renumbers when rows are gated out (a recording difference, like the schema flip - verified above via signalTime)` — proves `decisionId` is **not** the stable survivor key | No — `decisionId` order is incidental collection order, not semantic | Yes | No | **No new trading rule, but promotes incidental order into doctrine** | Yes | Only admission, but **incidental** | **Absent — do not select** |
| **D. Latest decision** | Keep largest `decisionId` | **No** — same as C, no contract | No | Yes | No | Promotes incidental order | Yes | Only admission | **Absent** |
| **E. Explicit deterministic priority/ranking based on existing signal semantics** | e.g., `LIQUIDITY_BOS_*` over `BOS_OB_*` priority, or `bullish` over `bearish` where both fire same bar | **No** — no frozen protocol, `ConfluenceEngine` evaluator priority, or `Sprint22_RL_HYP_01_Protocol` defines same-bar `ruleName` ranking; `Tests/unit/TestConfluenceEngine.mqh` tests `Clear()` delegation, not priority | Would preserve intended meaning *if* priority were documented, but it is **not** | Yes | Unknown | **Yes** — new ranking | Yes | Only admission, but **new priority table** | **Absent** |
| **F. Preserve all candidates upstream but enforce uniqueness only at ACTIVE-TIER using an explicitly defined ranking** | Keep upstream C4 `8,12,14` firings intact in detector/confluence evidence, deduplicate only at tier admission via ranking `X` | **No existing ranking X found** — same as A/B/E, needs `X` | Would preserve upstream meaning if `X` were `confidence`/`ruleScore`, but `X` is unspecified | Depends on `X` | Depends on `X` | **Yes** — new ranking `X` | Yes, but correctly `54` diffs would resolve to 0 downstream of deduplication (expected) | Only admission, **needs `X`** | **Absent — requires `X`** |
| **G. Any other policy already supported by authoritative requirements** | Exhaustive search of `Portfolio/SymbolContext.mqh` (tier admission at `SwingGateEvaluate` → `m_entryOrchestrator.Evaluate`), `Structure/SwingSignificanceGate.mqh` (frozen `k*ATR(14)` gate, `tier outside fingerprint`), `Tests/unit/TestConfluenceEngine.mqh`, `Validation/Sprint17` dup-scan (`firedRuleId` uniqueness with `signalTime`, not `signalTime` alone), `Sprint22` docs | **None found** — `Validation/Sprint17` checks `(configFingerprint, symbol, timeframe, signalTime, firedRuleId)` **0 duplicates** (18,686 unique keys) — explicitly *allows* same `signalTime` with different `firedRuleId`, so it **does not** establish `signalTime` uniqueness for ACTIVE-TIER | — | — | — | — | — | **Absent** |

**Do not select an option merely because it appears statistically attractive:** No option has existing doctrine support; `max confidence` appearing to keep the `0.85` vs `0.82` winner is not a contract.

## 3. PHASE 3 — HUMAN-POLICY BOUNDARY

**Existing project requirements do not determine a survivor policy — do NOT silently choose one.**

```
SURVIVOR POLICY = HUMAN DESIGN DECISION REQUIRED
```

**Minimum information the human must specify (not implemented in P29):**

1. **Ranking criterion** — `confidence` vs `ruleScore` vs `ruleConfidence` vs `firedRuleId` vs `trendAligned` vs `hasLiquiditySweep` bool vs composite (e.g., `confidence * 0.5 + ruleScore * 0.005`).
2. **Tie-break rule** — deterministic when ranking equal: `earliest decisionId` vs `latest` vs `lowest firedRuleId` vs `lexicographic ruleName`.
3. **Whether same-bar candidates are compared globally or directionally** — e.g., `bullish` and `bearish` at same `signalTime` (possible at `00:00 ×8` mixed families) — should they compete in same pool or per-direction pools (`bullish` keep one, `bearish` keep one)?
4. **Whether opposite-direction candidates can coexist** — at `00:00 ×8` with `BOS_OB_BULLISH` and `BOS_OB_BEARISH` both firing, should deduplication keep one per `signalTime` globally (1 survivor) or one per `signalTime+direction` (2 survivors, still `211→212` not `211`)?
5. **Whether discarded candidates remain in upstream evidence** — C4 detector firings at same bar remain in `ConfluenceResult` evidence for later bars (detector state propagation) vs discarded entirely (affects BEHAVIOR 433 cascade `has_detector` for downstream).
6. **Whether deduplication occurs before or after tier filtering** — at `SwingGateEvaluate` `ADMIT` check (drop second same-bar `ADMIT` before `EntryDecision` creation) vs after `EntryDecision` creation but before telemetry row emission (affects `decisionId` assignment).

**Do not implement any of these.** P29 must stop at specification.

## 4. REQUIRED POLICY CONTRACT — minimum contract future decision must satisfy

A future survivor-selection policy, when human-authorized, must satisfy:

1. **Exactly one ACTIVE decision per `signalTime`.** `unique(signalTime) == true` for `220 → 211` rows (9 duplicates removed), `nGatedOut` becomes `289` (500→211) vs current `280`, fingerprint remains constant.
2. **Survivor selection is deterministic.** Same input `signalTime` group always yields same survivor across runs (no `MathRand`, no iteration-order dependence beyond defined ranking).
3. **Survivor ranking is explicitly specified** in a governance record (e.g., `keep max confidence, tie-break smallest decisionId`).
4. **Ties have deterministic behavior** — explicit, not incidental.
5. **Upstream C4 signal generation remains unchanged unless separately authorized** — detectors may still fire `8,12,14` at same bar; only tier admission deduplicates.
6. **Discarded candidates remain traceable in evidence** — dropped `decisionId`/`firedRuleId`/`ruleName`/`confidence` remain in `ConfluenceResult` evidence for downstream bars (if needed for propagation), not deleted from detector state.
7. **The rule is testable independently of market outcomes** — a unit test can assert `signalTime not unique → 0` after deduplication without needing  `outcome`/`rMultiple`.
8. **No parameter/PromotionGate dependency** — ranking does not depend on `m_swingSignificanceTier`, `PromotionGate`, or `m_outcomePolicy` `R-multiple` tier.
9. **No dependence on incidental collection order** — `decisionId` ascending alone is **not** a ranking; if used as tie-break, it must be explicitly documented as tie-break, not primary.
10. **Existing TT01 uniqueness invariant remains unchanged** — `Tools/TT01/TT01_Validators.ps1:547-549` `fail++` when `211 !=220` stays the acceptance criterion; new policy must make it pass, not modify it.

Do not modify `TT01` itself — its `signalTime not unique → fail++` is the invariant to satisfy, not to change.

## 5. IMPACT BOUNDARY — cannot be finalized until survivor policy exists

**Cannot be finalized:**
- **ACTIVE-TIER remediation** — needs survivor policy (above).
- **The downstream 54 ACTIVE outcome differences** — currently `54` column diffs all downstream of 9 duplicates (`timestamp/outcome/rMultiple/barsHeld/exitReason` at duplicate bars); after deduplication, `54` should become `0` (admitted vs default byte-identical), but which 9 of the 54 `decisionId` rows survive determines *which* `timestamp/outcome` values remain.
- **Any post-remediation ACTIVE validation** — `211 unique vs 220` → `211 vs 211` and `54 → 0` must be re-measured in a new TT01 run after remediation.
- **Final four-gate disposition** — `ACTIVE-TIER` cannot move from `DEFECT / NOT ACCEPTABLE` to `FORMALLY ATTRIBUTED / ACCEPTABLE` without remediated `220→211` + `54→0`.
- **Re-freeze readiness** — requires `ACTIVE` acceptable plus `SETTLEMENT`/`INTEGRITY` already formally attributed (P21/P25) plus environmental `UNKNOWN=FAIL` preserved.

**Carry forward unchanged (P28):**
- **BEHAVIOR = formally attributed proof** (`4 ROOT +26 SECONDARY-ROOT +403 PROPAGATED =433`, 9 ranges, `E=3→15→29`, 5 negative controls correctly fail), underlying measured gate remains **FAIL** `33 signalTime` until doctrine permits root-plus-propagation model — **not reopened**.
- **INTEGRITY = formally censused** (`6,239==6,239` determinism, `35,259` detector-derived one-bar-shift via `P25` 11,283,219 B full census), underlying gate remains measured **FAIL** (stale CONTROL vs C4) until re-freeze — **not reopened**.
- **SETTLEMENT = outcome-path attribution with environmental UNKNOWN=FAIL** — `460` diffs `isolation_control` 64 files (6,239) vs `k1` 42 files (2,733), exclusively `timestamp/barsHeld/entryPrice/exitPrice/outcome/rMultiple` settlement/outcome, horizon `100→38` deferral-sensitive, tier-1.0 `2733 ADMIT` — **outcome-path proven**, but tick-cache separation remains `UNKNOWN=FAIL` (no cache snapshot).
- **PREFLIGHT = GREEN** after P11 CLEAN (`count=1` at canonical `Tests/TestRunnerEA.ex5`).
- **Platform `6118→6140` = UNKNOWN=FAIL** — `COMPILE×7 PASS` on 6140 proves build health, not doctrine-neutrality; no controlled isolation experiment.
- **Tick-cache contribution = UNKNOWN=FAIL** — documented possibility, no per-run cache snapshot.

## 6. STOP — no implementation

**Do not implement a survivor policy.** **Do not modify production code.** **Do not run TT01.** **Do not re-freeze.** **Do not certify B8.**

**Single governance record created:** `docs/P29_ACTIVE_TIER_SURVIVOR_POLICY_DEFINITION_2026-08-31.md` (this file). Prior records `P16`/`P18`/`P20`/`P23`/`P24`/`P25`/`P26`/`P27`/`P28` and artifacts `TT01_20260829_220830` (`35,753 B`), `TT01_20260831_135145` (`64+42` arm files), `P16` (`285,010 B`), `P18` (`286,412 B`), `P20` (`346,808 B`), `P23` (`24,152/182,562/1,414`), `P24` (`30,181 B`), `P25` (`11,283,219 B`) preserved, no overwrite.

**Final state must clearly distinguish:**

```
DEFECT CONFIRMED — ACTIVE-TIER 211/220 violates explicit signalTime uniqueness invariant (fail++ when 211 !=220), 9 duplicates are C4 same-bar clusters (8,12,14 fresh vs 0 base), 54 diffs downstream
SURVIVOR POLICY UNSPECIFIED — no authoritative ranking (max confidence / max ruleScore / earliest / latest / deterministic priority) exists in 23-file delta, ConfluenceEngine, SwingSignificanceGate, tests, or frozen Sprint-22 protocol; current ascending decisionId order is incidental, not doctrine
REMEDIATION BLOCKED — no source mutation authorized without explicit human survivor policy
HUMAN DESIGN DECISION REQUIRED — ranking criterion, tie-break, global vs directional pool, opposite-direction coexistence, upstream evidence preservation, dedup timing (before/after tier filter) must be specified in a governance record before implementation
B8 BLOCKED — re-freeze and certification remain NOT AUTHORIZED until ACTIVE 211→211 + 54→0 plus environmental UNKNOWN=FAIL preserved
```

---

*P29 governance/specification — signalTime uniqueness is authoritative but survivor selection is unspecified; no remediation may select a winner arbitrarily; 9 duplicate clusters remain DEFECT with blocked remediation, downstream 54 diffs remain not acceptable, re-freeze and B8 remain blocked. READ-ONLY beyond this record.*

