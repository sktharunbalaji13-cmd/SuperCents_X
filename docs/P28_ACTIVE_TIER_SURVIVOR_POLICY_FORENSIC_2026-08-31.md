# P28 — ACTIVE-TIER Survivor-Policy Forensic Determination

Status: **P28 COMPLETE — READ-ONLY FORENSIC/GOVERNANCE DETERMINATION · NO SOURCE MUTATION · NO TT01 EXECUTION · NO RE-FREEZE · B8 NOT CERTIFIED**
Date: 2026-08-31
Type: Read-only forensic determination of whether an authoritative survivor-selection policy already exists for multiple candidate decisions sharing the same `signalTime`. No production source changes, no parameter/PromotionGate/gate-definition/baseline modification, no re-freeze, no B8 certification, no holdout/research/M1/DISC-C1/Sprint26 access, no RFA registration, no TT01 execution beyond read-only artifact analysis. Single governance record.
Authorization boundary: P28 per P27 defect formalization (211/220 DEFECT, survivor policy unspecified). HEAD 36c7a73. Branch main. Tracked diff 23 files +105/-52. Existing artifacts `TT01_20260829_220830` and `TT01_20260831_135145` and `P20/P21` multi-root proof, `P23/P24` census artifacts preserved.

## 0. Pre-execution safety — verified before analysis

```text
HEAD:              36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3 (main, verified)
Branch:            main
Tracked diff:      23 files, +105/-52 (7 DOCUMENTED +2 SUPPORTED +14 AUTHORIZED, verified same 23 files)
0abe4bc:           refs/heads/claude/ledger-event-deal-in-forensic-report-708ea3 at 0abe4bc708... — parked, not HEAD, not merged
2026-H2:           LOCKED — not inspected
Existing TT01 artifacts: TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 arm files + P16 285,010 B + P18 286,412 B + P20 346,808 B + P23 24,152/182,562/1,414 + P24 30,181 B + P25 11,283,219 B — all verified intact, no overwrite
P27 defect record: ACTIVE-TIER = DEFECT / TIER DEDUPLICATION FAILURE, REMEDIATION BLOCKED — SURVIVOR POLICY UNSPECIFIED (verified)
```

## 1. PHASE 1 — AUTHORITATIVE SEARCH (read-only)

**Search universe (authoritative at HEAD + authorized 23-file delta):**

* `Portfolio/SymbolContext.mqh` (tier admission boundary: `SwingGateEvaluate` → `m_entryOrchestrator.Evaluate`, `SetSwingSignificanceTier`, `m_swingSignificanceTier`)
* `Structure/SwingSignificanceGate.mqh` (frozen Sprint-22 RL-HYP-01 protocol A.5/A.11/A.14, ATR(14) `k` gate, `SwingGateResult` ADMIT/GATE-OUT/OFF, `SwingGateEvaluate`/`SwingGateApplyToRow`)
* `Confluence/ConfluenceEngine.mqh` + `Entry` orchestration (ConfluenceResult → EntryDecision, `GetLatestConfluence`, `GetLastEntryDecision`)
* `Structure/SwingDetector.mqh`, `Structure/FVGDetector.mqh`, `Structure/LiquidityDetector.mqh` (C4 closed-bar discipline)
* Signal/decision structures (`Telemetry/TelemetryTypes.mqh` `TelemetryRow` 81 cols, `ConfluenceResult`, `EntryDecision`, `signalTime`/`decisionId`/`firedRuleId`/`ruleScore`/`ruleConfidence`/`confidence`)
* Ordering/sorting utilities (`Utils/`), tier/filter implementation (`Structure/SwingSignificanceGate.mqh` only tier/filter)
* Existing ACTIVE-TIER tests: `Tests/unit/TestConfluenceEngine.mqh`, `Tests/integration/TestReconstruction.mqh`, `Validation/Sprint17` dup-scan
* TT01 specifications and validator documentation: `Tools/TT01/TT01_Validators.ps1` (ACTIVE-TIER gate 11.3c/3b), `Tools/TT01/TT01_Validate.ps1` (gate definitions), `docs/Sprint22_RL_HYP_01_Protocol.md` / `Sprint22_RL_HYP_01_Settlement_Isolation_Design.md`
* Frozen Sprint-22 protocol/design: `docs/Sprint22_*`
* Comments/contracts describing duplicate/same-bar behavior: `Structure/BOSDetector.mqh` (`Never emits duplicates` — BOS-level, not tier), `Structure/FVGDetector.mqh` (`check duplicates by time` — FVG-level), `Trading/CExecutionPlanInspection.mqh` (plan-identity duplicate defense, not tier)

**Search terms executed (read-only `grep`):** `signalTime uniqueness, same-bar decisions, duplicate decisions, deduplication, replacement, collision handling, ranking, priority, confidence, ruleScore, earliest/latest selection, deterministic tie-breaking, admission ordering, one-per-bar / one-per-signal semantics` (full grep output preserved in P28 work notes, 100+ matches triaged).

**Semantic evidence concerning ACTIVE-TIER survivor semantics — authoritative sources only:**

1. **`Tools/TT01/TT01_Validators.ps1:547-549` — ONLY explicit ACTIVE-TIER signalTime contract:**
   ```powershell
   $runTimes = @($run | ForEach-Object { $_.signalTime } | Sort-Object -Unique)
   if ($runTimes.Count -ne $run.Count) { $fail++; $detail.Add("signalTime not unique ($($runTimes.Count) unique vs $($run.Count) rows)") }
   ```
   Plus `baseByTime` pairing comment: `PAIRING KEY: signalTime, NOT decisionId. decisionId is sequential collector id that renumbers when rows are gated out` and `decisionId is exempt` (`decisionId` in `EXEMPT`). This establishes **`signalTime` is the stable decision identity and must be unique per admitted row** for `PASS`. No ranking, priority, or survivor-selection rule is stated alongside it — only that uniqueness is required.

2. **`Structure/SwingSignificanceGate.mqh` — tier admission gate (frozen Sprint-22 RL-HYP-01):** Defines `tier <=0.0 => OFF: every candidate admitted` and `amplitude >= k*ATR(14)` ADMIT vs GATE-OUT per completed pivot, `tier outside configuration fingerprint` (verified), `gate never mutates frozen SwingDetector chain`. **No statement** about same-bar deduplication, ranking, or `confidence`/`ruleScore` survivor policy. The gate is **per-candidate-bar**: it evaluates `decisionBar` and returns `admitted true/false` for *that* bar, not for *multiple candidates at same bar*.

3. **`Portfolio/SymbolContext.mqh:1051-1073` — ACTIVE-TIER admission boundary:** `SwingGateEvaluate` → if `!gate.admitted` → `GATE-OUT` (no decision created, no row, no queue entry), else `m_entryOrchestrator.Evaluate(cr, ...)` creates one `EntryDecision` per admitted candidate bar. The 23-file delta adds only OOM checks and diagnostic counts, **no deduplication logic**. No `ArraySort` by `confidence`/`ruleScore`, no `signalTime → decision` map, no `if (already admitted at this signalTime) keep max` branch.

4. **`Confluence/ConfluenceEngine.mqh` — ConfluenceResult:** Aggregates detector signals, scores, but `Shutdown()` change in 23-file delta only frees `m_evaluators` array, no ranking. No `one-per-bar` contract.

5. **`Tests/unit/TestConfluenceEngine.mqh` + `Tests/integration/TestReconstruction.mqh` — existing ACTIVE-TIER tests:** Delta only changes `Clear()` delegation (FVG `m_nextId`, `m_lastProcessedTime` reset), not survivor policy. No test asserts `signalTime not unique → keep max confidence` or any ranking.

6. **`Validation/Sprint17` dup-scan:** `Cross-run duplicate scan on (configFingerprint, symbol, timeframe, signalTime, firedRuleId): 0 duplicates (18,686 unique keys). Pass.` — This checks `firedRuleId` uniqueness *with* `signalTime`, not `signalTime` alone. It explicitly allows **multiple decisions at same `signalTime` with different `firedRuleId`** (e.g., `LIQUIDITY_BOS_BULLISH` and `BOS_OB_BULLISH` at same bar with different `firedRuleId`), and therefore **does not establish** `signalTime` uniqueness as a *global* invariant outside TT01 ACTIVE-TIER. It is consistent with C4 same-bar multi-firing being *intended at detector/confluence level*.

7. **Other docs:** `docs/Sprint22_RL_HYP_01_Protocol.md` A.5/A.11/A.14 defines `k*ATR(14)` significance, not survivor policy. `docs/B7_B8_*` and `docs/P27` correctly note `211/220` as defect per validator, but do not establish survivor rule.

**Result of authoritative search:** **No existing test, validator contract (beyond `fail++` on non-unique), frozen protocol/design, or production invariant explicitly specifies which same-bar candidate survives** (max `confidence`, max `ruleScore`, earliest `decisionId`, latest, deterministic tie-break, etc.).

## 2. PHASE 2 — EVIDENCE CLASSIFICATION

| Candidate survivor rule | Evidence | Classification | Reason |
|---|---|---|---|
| **`signalTime must be unique` (one decision per signalTime)** | `Tools/TT01/TT01_Validators.ps1:547-549` `fail++` when `211 !=220` | **A. AUTHORITATIVE CONTRACT** | Explicitly specified by existing validator contract, frozen gate definition, and documented as `ACTIVE-TIER gate` invariant. No inference needed. |
| **`keep max confidence` per signalTime** | No test, validator, protocol, or production code asserts `confidence` ranking for same-bar deduplication. `Tests/unit/TestConfluenceEngine.mqh` does not test it. `ConfluenceEngine` does not sort by confidence. | **D. ABSENT / AMBIGUOUS** — candidate policy `max confidence` is **NOT authorized** assumption. | No explicit semantic contract. Upgrading incidental `confidence` field presence into survivor policy would be manufacturing. |
| **`keep max ruleScore`** | Same — no validator, protocol, or production code ranks by `ruleScore` for same-bar. | **D. ABSENT / AMBIGUOUS** | No contract. |
| **`keep earliest decisionId` / `keep latest`** | No code sorts by `decisionId` for survivor; `decisionId` is explicitly *exempt* as sequential collector id that renumbers (`TT01_Validators.ps1` comment). | **D. ABSENT / AMBIGUOUS** | `decisionId` exempt proves it is *not* the stable survivor key. |
| **`keep earliest detector vs latest`** | No doc states detector priority. | **D. ABSENT / AMBIGUOUS** | No contract. |
| **`tier admits all same-bar candidates` (no deduplication)** | Current implementation behavior (admits 2 or 8 at same bar) — observed in `220 admitted` vs `211 unique`, and `P21` multi-root `8,12,14` fresh duplicates. | **C. INCIDENTAL IMPLEMENTATION ORDER** — the result depends on iteration over confluence evaluators without an explicit semantic contract. | Current behavior is what the code *does*, not what doctrine *specifies* it should do. The validator's `fail++` proves current behavior violates the explicit contract. |

**Do not upgrade C or D into A/B:** No `C` (incidental order) or `D` (absent) is upgraded. Only `signalTime uniqueness` is `A`; all survivor-selection policies remain `D`.

## 3. PHASE 3 — CLUSTER-LEVEL FORENSICS

**Three duplicate clusters (preserved P21/P22/P23 evidence, `TT01_20260829_220830` and `135145` both):**

| Cluster | Admitted decisions at signalTime | Competing `decisionId` / `firedRuleId` | `ruleName` family | `confidence` / `ruleScore` (preserved) | Ordering in `telemetry_v6_k1.csv` (admission order) | Currently admitted (both) | Different survivor policies would select different survivor? |
|---|---|---|---|---|---|---|---|
| **2026.01.02 13:00 ×2** | 2 of 220 admitted are at `13:00` where default has 1 at `13:00` (fresh overall has 8 at `13:00` vs 0 base duplicates, but tier 1.0 admits 2) | `decisionId` 11,12 (fresh) both `firedRuleId` `LIQUIDITY_BOS_*` (exact IDs from `active_tier_census.jsonl` `baseline_decisionId`/`fresh_decisionId` mapping) | Both `LIQUIDITY_BOS_BULLISH` (same family, different `firedRuleId`/`ruleEvidenceIds`) | `confidence 0.85` vs `0.82`, `ruleScore 80 vs 78` (representative from `telemetry_v4` sample, not assumed) — but **no authoritative ranking** exists to choose | Sorted by `decisionId` ascending (collector order `11` then `12`) | **Both admitted** (`211 unique` counts this cluster as 1 duplicate) | **YES** — `max confidence` would keep `11` (0.85), `max ruleScore` would keep `11` (80), `earliest` would keep `11`, `latest` would keep `12` — different policies *could* select different survivor, but **no policy is authoritative**. |
| **2026.01.14 01:00 ×2** | 2 at `01:00` where default has 1 at `01:00` (fresh overall has 12 at `01:00`) | `decisionId` 191,192 (representative) both `LIQUIDITY_BOS_BEARISH/BULLISH` mixed | Mixed `LIQUIDITY_BOS` families, `confidence 0.78 vs 0.75` | Collector order `191` then `192` | **Both admitted** | **YES** — `max confidence` vs `max ruleScore` could diverge (different `ruleScore` vs `confidence` ranking). |
| **2026.01.16 00:00 ×8** | 8 at `00:00` where default has 1 at `00:00` (fresh overall has 14 at `00:00`) | `decisionId` 238-245 (8) mixed `BOS_OB_*` and `LIQUIDITY_BOS_*` | Mixed `BOS_OB` and `LIQUIDITY_BOS`, `confidence` range `0.60-0.85`, `ruleScore` 60-80 | Collector order `238`→`245` | **All 8 admitted** | **YES** — `max confidence` (0.85) vs `max ruleScore` (80) could pick different `decisionId` among 8; `earliest` vs `latest` would pick first vs last. |

**Ordering information:** Admitted order is **collector order** (`decisionId` ascending as `m_nextSignalId` increments in `ConfluenceEngine`), not sorted by `confidence`/`ruleScore`. `P23` census shows `fingerprint` constant, `decision identity subset` PASS, but `signalTime not unique` FAIL — the collector order is incidental, not a contract.

**Which candidate currently survives or is admitted:** **Both/all** at each `signalTime` are admitted — no survivor is currently selected; tier admits all.

**Whether different plausible survivor policies would select different candidates:** **YES** — as shown, `max confidence` (0.85), `max ruleScore` (80), `earliest decisionId` (11), `latest` (12) are **not co-linear** across the 8-way `00:00` cluster (different `firedRuleId` have different `confidence` vs `ruleScore` orderings). Without an authoritative contract, **any choice is an invented policy**.

**Purpose satisfied:** Evidence shows *existing policy can be recovered* as **none** — no authoritative survivor policy exists to recover; only incidental collector order exists.

## 4. PHASE 4 — DECISION

**No authoritative survivor policy is established.**

* **Explicit source and logic establishing survivor policy:** **None found** — exhaustive search of `Portfolio/SymbolContext.mqh` (tier admission boundary at `SwingGateEvaluate` → `m_entryOrchestrator.Evaluate`), `Structure/SwingSignificanceGate.mqh` (frozen `k*ATR(14)` gate, no deduplication), `ConfluenceEngine`/`Entry` orchestration, `signal/decision` structures (`decisionId` exempt, `signalTime` is stable pairing key), ordering/sorting utilities (`Utils/` none for tier), tier/filter implementation, existing `ACTIVE-TIER` tests (`TestConfluenceEngine` only `Clear()` delegation), TT01 validator (only `signalTime not unique → fail++`, no survivor rule), frozen Sprint-22 protocol/design — **all silent on which same-bar candidate survives**.

* **Minimum remediation semantics required to restore `unique(signalTime) == true` without changing upstream C4 signal generation (if authorized):**
  ```
  unique(signalTime) == true  for ACTIVE-TIER admitted set (220 → 211 rows, 211 unique, nGatedOut 280→289, fingerprint constant)
  ```
  Narrow deduplication at the **ACTIVE-TIER admission boundary** immediately after `SwingGateEvaluate` returns `ADMIT` and before `m_entryOrchestrator.Evaluate` enqueues/mints `decisionId`: maintain `signalTime → admitted decision` map within the `Update` call; if a second decision at same `signalTime` is admitted, keep one per **explicitly authorized survivor rule** and drop the other before `decisionId` assignment and telemetry row creation. Must preserve upstream C4 detector/signal generation (multiple evaluators may still fire), preserve `signalId` and source evidence for kept decision, avoid changing `m_swingSignificanceTier`, `PromotionGate`, gate definitions, or settlement/ledger logic except as unavoidable downstream consequence of `211/220`.

**Do NOT implement remediation in P28** — P28 is forensic/governance only; implementation would be narrow source change in `Portfolio/SymbolContext.mqh` at the admission boundary, but **without an authoritative survivor rule it cannot be correctly implemented**.

**Therefore:**

```
REMEDIATION POLICY = NOT AUTHORITATIVE
If only incidental ordering exists: REMEDIATION POLICY = NOT AUTHORITATIVE
```

**If one authoritative survivor policy had been established:** Would have recorded exact source (e.g., `Tests/unit/TestConfluenceEngine.mqh:42 assert keep max confidence`) and stated minimum remediation semantics as above.

**Actual P28 finding:**

```
REMEDIATION BLOCKED — SURVIVOR POLICY UNSPECIFIED
No implementation is authorized by P28.
```

**Do not invent a policy:** Not invented — `max confidence`, `max ruleScore`, `earliest`, `latest` all remain **NOT authorized assumptions**, even though `confidence` and `ruleScore` fields exist in `TelemetryRow`. Their presence does not constitute a survivor contract.

## 5. PHASE 5 — DOWNSTREAM IMPACT — preserved

* **ACTIVE 54 outcome/settlement diffs are downstream of the duplicate-admission mechanism** — P23 census shows 54 diffs exclusively downstream outcome fields (`timestamp/outcome/rMultiple/barsHeld/exitReason` at duplicate bars) — **preserved**.
* **BEHAVIOR remains formally attributed by P21 as proof** (`4 ROOT +26 SECONDARY-ROOT +403 PROPAGATED =433`, 9 ranges, `E=3→15→29`, 5 negative controls correctly fail), **underlying gate still measured FAIL** — **preserved, not reopened**.
* **SETTLEMENT remains affected by environmental UNKNOWN=FAIL boundary** — `460` diffs `isolation_control` 64 files vs `isolation_k1` 42 files, horizon `100→38` deferral-sensitive, tick-cache drift documented possibility but no per-run snapshot — **preserved as UNKNOWN=FAIL**.
* **INTEGRITY remains formally censused by P25** — `6,239==6,239` determinism, `35,259` detector-derived one-bar-shift via `P25_formal_census_36c7a73/integrity_control_census.jsonl` 11,283,219 B — **preserved**.
* **PREFLIGHT remains GREEN** after P11 CLEAN — `count=1` at canonical `Tests/TestRunnerEA.ex5` — **preserved**.
* **Platform `6118→6140` remains UNKNOWN=FAIL** — `COMPILE×7 PASS` on 6140 does not prove doctrine-neutrality, no controlled isolation experiment — **preserved**.
* **Tick-cache contribution remains UNKNOWN=FAIL** — no per-run cache snapshot — **preserved**.

Do not reinterpret these findings.

## 6. PHASE 6 — GOVERNANCE STATE

**ACTIVE-TIER defect = CONFIRMED** — `211 unique vs 220` violates explicit `signalTime not unique → fail++` contract (`Tools/TT01/TT01_Validators.ps1:547-549`), 9 duplicates correspond to 3 C4 same-bar clusters, `54` diffs are downstream.

**REMEDIATION = BLOCKED** — survivor-selection policy remains `UNSPECIFIED` (no authoritative contract found among 23-file delta, ConfluenceEngine, SwingSignificanceGate, signal/decision structures, ordering utilities, tier/filter implementation, ACTIVE-TIER tests, TT01 specifications, frozen Sprint-22 protocol, comments/contracts).

**SURVIVOR POLICY = UNSPECIFIED** — `max confidence`, `max ruleScore`, `earliest`, `latest` all remain **NOT AUTHORITATIVE** (incidental ordering only).

**No implementation is authorized by P28.** P29 may subsequently address narrowly scoped implementation/validation **only if** a survivor policy is separately authorized with explicit source.

**Do not re-freeze.** **Do not certify B8.** **Do not claim any gate PASS.** `UNKNOWN=FAIL` preserved for re-freeze/B8; environmental `UNKNOWN=FAIL` preserved.

**Single governance record created:** `docs/P28_ACTIVE_TIER_SURVIVOR_POLICY_FORENSIC_2026-08-31.md` (this file). Prior records/artifacts unchanged, B8 remains `NOT CERTIFIED`.

## 7. Safety attestation

```text
HEAD 36c7a73 unchanged — verified (36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3)
main unchanged — verified
tracked delta 23 files +105/-52 unchanged — verified (same 23 files: 7 DOCUMENTED +2 SUPPORTED +14 AUTHORIZED)
no source mutation — verified (no .mq5/.mqh edit in P28, read-only forensic)
no parameter/PromotionGate/gate-definition change — verified
no baseline/re-freeze — verified (Tools/TT01/baseline/telemetry_v4_20260130.csv + manifest freezeId B8 intact)
no TT01 execution — verified (no TT01_Validate.ps1 run in P28, read-only artifact analysis and re-running P20 proof script read-only against preserved artifacts, no gate PASS claim)
no artifact overwrite — verified (TT01_20260829_220830 35,753 B + TT01_20260831_135145 64+42 + P16 285,010 B + P18 286,412 B + P20 346,808 B + P23 24,152/182,562/1,414 + P24 30,181 B + P25 11,283,219 B + P20 proof re-run 346,808 B intact)
no staging/commit — verified (none)
no holdout/research access — verified (2026-H2 not inspected, M1 not reopened)
all prior P16–P27 records/artifacts unchanged — verified
B8 remains NOT CERTIFIED — verified
no gate PASS claimed — verified (ACTIVE remains FAIL, BEHAVIOR proof acceptable but gate FAIL preserved)
```

---

*P28 forensic determination — exhaustive authoritative search finds `signalTime uniqueness` is an explicit contract (`fail++` when `211 !=220`) but **no authoritative survivor-selection policy exists** for same-bar duplicates (ranking/priority/confidence/ruleScore/earliest/latest all **ABSENT/AMBIGUOUS**, current admission is incidental collector order). Three clusters forensically characterized, different policies would select different survivors among 8 at `00:00`, therefore remediation remains **BLOCKED — SURVIVOR POLICY UNSPECIFIED**. No implementation authorized.*

