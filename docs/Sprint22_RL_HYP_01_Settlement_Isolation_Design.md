# Sprint 22 RL-HYP-01 — Settlement Isolation Design (DESIGN-ONLY)

| | |
|---|---|
| Phase | DESIGN-ONLY — no implementation, no tester runs, no statistics |
| Root cause | CONFIRMED — independent adversarial review (`docs/Sprint22_RL_HYP_01_Adversarial_Review_Claude.md`, 2026-08-12, verdict ROOT CAUSE CONFIRMED) |
| Defect | `SettleDue()` sole call site inside the gate-ADMIT branch (`Portfolio/SymbolContext.mqh:975`) → gate-dependent settlement deferral |
| Contract violated | Protocol §11.3b admission-only invariance (an admitted decision must be byte-identical in CONTROL and treatment) |
| Status | AWAITING HUMAN DESIGN APPROVAL — no code changed, no commit |

---

## 1. Root-cause model

**Contract (§11.3b).** The gate may only *remove* opportunities (GATE-OUT creates no row). It must never perturb an admitted row. Gate 3b (byte-identity of admitted rows) is the hard gate enforcing this.

**Defect.** `SettleDue()` is invoked only inside the gate-ADMIT branch (`SymbolContext.mqh:975`, exhaustive grep: sole call site; declaration `:172`, definition `:1422`). A GATE-OUT bar therefore never settles the pending queue; every queued row's settlement is **deferred to the next ADMIT bar**.

**Consequence.** `SettleRow` copies `[warmStart, stopTime]` and reverses it (as-series: index 0 = the bar current at settlement). The outcome scan runs `b = entryBarIndex-1 … minBar = entryBarIndex-50` (`ForwardOutcomeSimulator.mqh:99-102`):

- CONTROL (gate off): the ADMIT branch runs on the first tick of the 50th bar after entry (`iBarShift >= 50` first becomes true, `:1433`). Index 0 of the window is that boundary bar **still forming**: `open=high=low=close = first-tick price`. Horizon exit reads `close[minBar] = close[0]` = first-tick price (`:172`).
- Treatment (gate on): if that same bar is GATE-OUT, settlement defers k bars to the next ADMIT bar; `entryBarIndex = 50+k`, `minBar = k`, and the scan reads the **same physical boundary bar, now closed** — horizon exit = final close. Different exit price (1-5 pips), different `rMultiple`, occasionally different `outcome`/`exitReason`. SL/TP exits are unaffected (fixed-price, same physical bars).

**Observed.** 58/12,329 admitted rows diverge (H1 0/0/0, GBPJPY 1/1/1, M15 17/17/21). Bijection with 0 violations: diverging ⇔ (CONTROL 50th bar after entry is GATE-OUT in treatment) ∧ (CONTROL exit is horizon `exitReason=4`, `barsHeld=51`). Entry-side byte-identical on every diverging row; `.tst` price proofs reproduce both read states (GBPJPY 212.652 vs 212.748; M15 1.17064 vs 1.17056). INTEGRITY rerun (same new build, tier 0.0) is byte-identical to CONTROL → not nondeterminism, not serialization, not shared-state bleed.

**Fix objective (verbatim from review §7b/§9).** *An already-admitted opportunity must have settlement semantics independent of whether subsequent bars are admitted or gated out.* The fix must make the settlement trigger admission-independent, **and** must keep tier 0.0 byte-identical to frozen B8 (regression control: INTEGRITY byte-identity).

---

## 2. Current settlement lifecycle (complete trace)

**State.** Per-context pending queue (parallel arrays): `m_pendingRows[]`, `m_pendingEntryTime[]`, `m_pendingCandidateId[]`, `m_pendingLiqHas[]`, `m_pendingLiqId[]`, `m_pendingCount` (`SymbolContext.mqh`, declarations `:160-166`). `TELEMETRY_SETTLE_MAX_HOLD_BARS = 50` (`:67`); simulator `m_maxHoldBars = 50` (`ForwardOutcomeSimulator.mqh:56`, `SetMaxHoldBars` `m_outcomeSim` at `SymbolContext.mqh:322`).

**Callers (exhaustive):**

| Function | Definition | Callers | Trigger |
|---|---|---|---|
| `QueueForSettlement()` | `:1310-1331` | `:976` (ADMIT branch only) | First tick of a candidate bar that admits |
| `SettleDue()` | `:1422-1455` | `:975` (ADMIT branch only) — **sole call site** | Same |
| `SettleRow()` | `:1333-1420` | `SettleDue()` `:1435`; `SettleRemaining()` `:1468` | as-series window + simulate |
| `SettleRemaining()` | `:1457-1480` | `Shutdown()` `:1089` only | EA deinit (run end) |
| `CForwardOutcomeSimulator::Simulate()` | `FwdOutcomeSim.mqh:63-177` | `SettleRow()` `:1407` | — |

**Per-bar state machine (first tick of a new bar, decision path `:839-983`):**

```
candidate bar (GetLatestConfluence valid)
├─ SwingGateEvaluate (:853-861)          [read-only on pivot chain]
├─ GATE-OUT (:862-867): log only
│     └─ NO SettleDue, NO row, NO queue          <<< DEFECT
└─ ADMIT (:868-979):
     ├─ Evaluate entry, build TelemetryRow (:881-962)
     ├─ SwingGateApplyToRow (:974)               [stamp 3 gate cols]
     ├─ SettleDue (:975)                          [settle ALL due pending rows:
     │      due ⇔ iBarShift(entryTime,false) >= 50 (:1433)
     │      → SettleRow (:1435)                    → window [warmStart, stopTime],
     │        reversed (index 0 = bar at settle), entry located by TIME (:1392-1400),
     │        require entryBarIndex >= 50 (:1401)
     │        → Simulate: scan entry-1 … entry-50 (:99-102),
     │          SL before TP (:129-162), horizon exitPrice=close[minBar] (:172),
     │          barsHeld = (entryBarIndex-minBar)+1 = 51 (:173)
     │      → on success: Record (decisionId assigned here, GR02A), 
     │        m_settler.Register(candidateId→decisionId) (:1436-1444),
     │        queue compact (:1445-1454)]
     └─ QueueForSettlement(row, entryBarTime = iTime(0), liq ctx) (:976-978)
```
Bars without a candidate: decision path not entered → NO settle (frozen B8 semantics: deferral to the next candidate bar). Deinit: `SettleRemaining` settles everything the horizon allows, remainder recorded UNKNOWN.

**Key invariants of the current design (must survive the fix):**
1. `SettleDue()` runs BEFORE `QueueForSettlement()` so rows are settled (Recorded) in decision order (`:963-965` comment).
2. Candidate absence defers settlement (B8 behavior — this is what makes tier-0 reruns byte-identical to B8 CONTROL).
3. `SettleRow` is a pure function of (entry bar time, direction, tick/bar stream, policy) — no gate input, no shared mutable state.
4. decisionId is assigned at Record time (settlement order), never at queue time.
5. The gate never creates or destroys candidates (deterministic from prices) — candidate presence is run-invariant. (This is what makes criterion 1 achievable.)

---

## 3. Design alternatives A/B/C/D — evaluation against the 12 criteria

Notation: ✓ = satisfies; ✗ = violates; ⚠ = only if implemented with the trigger semantics of A (i.e., not structurally simpler).

| # | Criterion | A: hoist to candidate path | B: separate settlement scheduler | C: absolute bar-index eligibility | D1: duplicate call in GATE-OUT branch | D2/D3/D4 (rejected) |
|---|---|---|---|---|---|---|
| 1 | 50-bar boundary identical CONTROL vs treatment | ✓ settle attempts on the same bars as CONTROL (candidate presence run-invariant; first tick of boundary bar) | ⚠ same behavior only if trigger == A's | ✗ unconditional trigger settles no-candidate boundary bars → boundary READ STATE differs from frozen CONTROL semantics | ✓ identical to A (same trigger point by construction) | ✗ (D2 reads closed bar by design; D3 wall-clock; D4 candidate-independent) |
| 2 | Horizon exit reads same forming/closed bar state | ✓ boundary bar read forming (first tick) exactly as CONTROL | ⚠ | ✗ unless candidate-gated (then == A) | ✓ | ✗ |
| 3 | GATE-OUT still suppresses new decision row | ✓ GATE-OUT branch untouched: no row, no queue | ✓ | ✓ | ✓ | ✓ (D4: rows still suppressed; D2: same) |
| 4 | Already-admitted row settles while current bar is GATE-OUT | ✓ SettleDue runs before the gate on every candidate bar | ✓ | ✓ | ✓ | D2: settles at close (wrong state); D3: unreliable; D4: settles per tick (wrong for no-candidate) |
| 5 | Preserves frozen A1 opportunity-level estimand | ✓ outcome values for admitted rows become CONTROL-identical; pairing/A1 machinery untouched | ✓ | ✓ | ✓ | ✗ |
| 6 | tier = 0.0 byte-identical to B8 | ✓ at tier 0 the gate always admits; trigger bars identical to today; no-candidate deferral preserved (INTEGRITY regression control) | ⚠ must not settle no-candidate bars (extra machinery to suppress) | ✗ unconditional trigger changes B8 settle timing on no-candidate bars | ✓ | ✗ |
| 7 | Preserves canonical pairing key (A2) | ✓ no identity fields touched; decisionId stays the ungated-integrity certificate | ✓ | ✓ | ✓ | ✓ |
| 8 | No effect on entry/swing/confluence/exits/TP-SL | ✓ pure trigger move; settle is read-only w.r.t. those | ✓ (new subsystem risk) | ✓ | ✓ | ✗ |
| 9 | Regression risks | Low — 1-line move, sole call site kept | Higher — new member/wiring; must replicate A's trigger to avoid B8 drift | Medium-high — manual bar-index must re-derive session-gap handling that `iBarShift` already does | Low — 2-line duplication, retains a second call site | High — wrong read state or nondeterminism |
| 10 | TDD RED→GREEN | New tests (see §7) | Same tests + scheduler-wiring tests | Same + dueBar bookkeeping tests | Same | n/a |
| 11 | TT01 gates | §8 (2 new gates + regression control) | same | same | same | n/a |
| 12 | Acceptance criteria before rerun | §10 | §10 | §10 (but fails 6) | §10 | — |

**Designs:**
- **A — Hoist:** move the `SettleDue()` call from `:975` to immediately before `SwingGateEvaluate` (`:853`), inside the same candidate-valid block.
- **B — Dedicated scheduler:** extract settlement into its own per-bar subsystem invoked independently of the decision path.
- **C — Absolute eligibility:** store a per-row absolute due bar (entry bar + 50) and settle when the current bar index reaches it, independent of `iBarShift`/admission.
- **D1 — Duplicate in GATE-OUT branch:** add `SettleDue()` to the `else` branch (`:862-867`).
- **D2 — Settle at boundary-bar close:** settle when the boundary bar *closes* — ✗ reads the closed bar, which is the treatment-side state CONTROL never had; **D3 — OnTimer:** tester timers are non-deterministic — ✗; **D4 — Per-tick top-level `SettleDue`:** settles no-candidate bars and mid-bar retries — ✗ breaks criterion 6 and wastes cycles.

**Why C fails criterion 6 concretely:** in frozen B8, a row whose 50th bar is a *no-candidate* bar settles on the *next candidate bar* (closed read). An unconditional absolute-index trigger settles it on the boundary bar (forming read) → different horizon price → tier-0 rerun ≠ B8 bytes. Gating C by "candidate present" reduces it to A plus dead bookkeeping. `iBarShift(entry,false) >= 50` is already absolute-time-eligibility; the trigger is the only defect.

---

## 4. Recommended design — A (hoist); D1 recorded as the accepted minimal variant

**Change (design sketch only):**

```mql5
// BEFORE (SymbolContext.mqh :853-978, abridged)
if(m_confluenceEngine.GetLatestConfluence(cr) && cr.valid)
{
    SwingGateResult gate; gate.admitted = true; ...           // :853-858
    SwingGateEvaluate(...);                                    // :859-861
    if(!gate.admitted)
    {
        //--- GATE-OUT: no decision, no row, no queue           // :862-867
        //    BUT also no SettleDue() -> settlement deferral    //    <<< DEFECT
    }
    else
    {
        ... build row ...
        SwingGateApplyToRow(row, gate);                        // :974
        SettleDue();                                           // :975 (moved)
        QueueForSettlement(row, ...);                          // :976
    }
}

// AFTER (same block)
if(m_confluenceEngine.GetLatestConfluence(cr) && cr.valid)
{
    SettleDue();                                               // hoisted: runs on
                                                               // EVERY candidate
                                                               // bar, before the
                                                               // gate -> admission-
                                                               // independent trigger
    SwingGateResult gate; ...                                  // unchanged
    SwingGateEvaluate(...);                                    // unchanged
    if(!gate.admitted)
        { /* GATE-OUT: still no row, no queue */ }             // unchanged
    else
    {
        ... build row ...
        SwingGateApplyToRow(row, gate);                        // unchanged
        QueueForSettlement(row, ...);                          // unchanged
    }
}
```
No other code changes. Comments at `:963-965` reworded to state the new contract ("settlement runs on every candidate bar before the gate; rows are settled before the new row is queued, preserving decision order; GATE-OUT bars still suppress the row itself").

**Behavior proof (why A restores the contract):**
- ADMIT bars (tier 0 or ≥1): `SettleDue()` runs at the same per-bar cadence and before `QueueForSettlement` → rows settle on the same bars, in the same order, reading the boundary bar forming (first tick) — byte-identical to CONTROL.
- GATE-OUT bars: `SettleDue()` now runs (the fix); the boundary bar is read forming, exactly as CONTROL did; the GATE-OUT branch still creates no row (criteria 3, 4 hold).
- No-candidate bars: block not entered → deferral preserved → tier-0 byte-identity to B8 (criterion 6) and CONTROL/treatment symmetry (criterion 1) both hold, because candidate presence is run-invariant.
- Deinit `SettleRemaining`, LEGACY mode (`:839` guard), GR02A link, decisionId assignment order, A2 canonical pairing: untouched.

---

## 5. Why this is minimal

1. **One line moved** — no new state, members, files, or subsystems; the reviewer's "sole call site" audit property is retained (grep: declaration + one call + definition).
2. It removes the defect **at its root**: the settlement trigger becomes the per-bar candidate path (admission-independent) instead of the ADMIT branch (admission-coupled). It does not make divergences disappear cosmetically — it restores the exact CONTROL read state for every admitted row.
3. Every non-defect behavior is untouched: ADMIT-bar cadence, decision order, no-candidate deferral, LEGACY mode, deinit settle, policies, simulator algebra, gate semantics, fingerprint inputs.
4. It is provably equivalent to D1 (the reviewer's literal "settlement must be attempted on GATE-OUT bars too") without a second call site; D1 remains the accepted fallback if a later review prefers branch-local change.

---

## 6. State-machine / data-flow before vs after

**Before (defective):**
```
candidate bar (first tick)
  ├─ gate:
  │    ├─ ADMIT  → [BuildRow] → [StampGateCols] → [SettleDue → Record(decisionId) → Register] → [Queue]
  │    └─ GATE-OUT → [Log]                                    (pending rows DEFERRED)
  └─ (no candidate): nothing                                  (B8: deferral OK)
deinit: SettleRemaining (horizon-limited)
```

**After (isolated):**
```
candidate bar (first tick)
  ├─ [SettleDue → SettleRow (due rows) → Record → Register]        ← unconditional
  ├─ gate:
  │    ├─ ADMIT  → [BuildRow] → [StampGateCols] → [Queue]
  │    └─ GATE-OUT → [Log]                                           (row still suppressed)
  └─ (no candidate): nothing                                        (unchanged)
deinit: SettleRemaining (unchanged)
```
Data flow per pending row: `entryBarTime` → `iBarShift >= 50` due check → window copy → reverse → entry-bar-by-time → `Simulate` → outcome stamp → `Record` (decisionId) → `Register` candidate link. Identical in both columns; **only the trigger moved, so the bar at which the window's index-0 bar is read is no longer admission-dependent.**

---

## 7. TDD plan (RED → GREEN)

New unit tests (add to `Tests/unit/`, wired in `Tests/TestSuite.mqh`; REPO gates only — no production code written before RED):

1. **RED: "settlement runs on a GATE-OUT bar."** Context with a queued row whose boundary bar is GATE-OUT: assert the row settles on that bar (Recorded with decisionId; `barsHeld=51`, horizon `exitPrice = first-tick price of the boundary bar`). Fails today (deferral) → GREEN after A.
2. **RED: "admitted-row byte-identity across gate tiers."** Same synthetic bars, tier 0.0 vs tier 1.0 with the boundary bar GATE-OUT: assert every admitted row byte-identical outside the 3 gate columns (the §11.3b contract). RED today (58-class defect) → GREEN after A.
3. **GREEN-guard: "no-candidate boundary bar still defers."** Queued row whose boundary bar has NO candidate: row stays pending until the next candidate bar (frozen B8 semantics). Must remain GREEN (prevents an over-broad fix from breaking criterion 6).
4. **GREEN-guard: "decision order preserved."** Multiple queued rows + an ADMIT bar: settlement order (Record order) == entry order.
5. **GREEN-guard: "GATE-OUT creates no row."** GATE-OUT bar: zero rows queued/recorded.
6. **GREEN-guard: simulator/policy untouched.** Existing `TestForwardOutcomeSimulator`, `TestOutcomeTpPolicy`, `TestSwingSignificanceGate` (88), `TestSwingGateWiring`, `TestTelemetry`, `TestTelemetryHealth`, `TestCalibrationDataset` — full suite must stay GREEN (current baseline 2555/2555).

---

## 8. TT01 validation plan

Existing gates (kept, unchanged): compile 6/6, replay HEALTHY, contract 78/78, fingerprint constant, evidence invariants.

**New/strengthened gates:**
1. **Admission-only invariance (tiered pair):** replay the same window twice — tier 0.0 and tier 1.0 (plus 2.0), with the fixture engineered so ≥1 boundary bar is GATE-OUT — assert 0 divergences between arm rows and CONTROL outside the 3 gate columns (58 → 0 acceptance).
2. **Settlement scheduling independence:** scenario asserting a queued row settles on a GATE-OUT boundary bar with the forming-bar read (horizon `exitPrice` == boundary-bar first-tick price from the fixture) — direct regression probe for the deferral.
3. **Regression control:** INTEGRITY rerun (fixed build, tier 0.0) vs frozen CONTROL — byte-identical (row-for-row, except `schemaVersion` 4→5, decisionId invariant) — guards criterion 6 and run determinism.

---

## 9. Regression risks

| Risk | Exposure | Mitigation |
|---|---|---|
| Per-bar cadence drift (settle earlier/later than CONTROL) | INTEGRITY byte-identity breaks | TDD test 1 + TT01 gate 3; the hoist inherits the existing block cadence |
| decisionId ordering / GR02A link regression | collector order, live-close linkage | TDD test 4 + existing telemetry suite |
| B8 semantics changed on no-candidate bars | tier-0 ≠ frozen bytes | TDD test 3 (GREEN-guard) + TT01 INTEGRITY control |
| CPU cost on GATE-OUT bars | tester speed | settle loop is bounded by pending queue; identical O(n) work as ADMIT bars |
| LEGACY entry mode | unchanged (block not entered) | existing legacy tests |
| Second call site appearing (D1 drift) | reviewer audit property | A keeps exactly one call site; TDD asserts trigger semantics, not implementation |
| Analyzer assumptions | gate 3a/3b on OLD artifacts already FAIL by design | no analyzer change needed; new artifacts must pass the existing gates |

---

## 10. Acceptance criteria (MUST all pass before ANY rerun or statistics)

1. TDD tests 1-2 RED→GREEN; tests 3-6 + full suite GREEN (baseline 2555/2555 + new tests).
2. TT01: all existing gates PLUS the two new gates (§8) PASS.
3. INTEGRITY rerun on the fixed build byte-identical to frozen CONTROL (except `schemaVersion`); = tier-0.0 byte-identity to B8 (review acceptance 4; criterion 6).
4. **A tiered arm (K1P0) on the fixed build vs CONTROL: 0 divergences on all shared columns except the 3 gate columns** — the 58 → 0 acceptance (admission-only invariance restored, §11.3b; review acceptance 3).
5. Fingerprints unchanged (EURUSD_H1 3005138848403243456, GBPJPY_H1 14617585492269479818, EURUSD_M15 13548296177162108249); `SwingSignificanceTier` remains outside the fingerprint.
6. No protocol change and no A3 (the fix restores the frozen contract; root cause ≠ admissibility amendment).
7. This design document approved by the user; a separate explicit run authorization (§15.3 step 7) before any rerun.

---

## 11. Explicit non-goals

- NO change to entry logic, swing detection, confluence, exits, TP/SL policy, `ForwardOutcomeSimulator`, any `IOutcomePolicy`.
- NO change to gate semantics (`SwingSignificanceGate.mqh`), tier values, INI profiles, run window, deposit/model/execution config, B8.
- NO statistics or verdict of any kind on the frozen 12-run artifacts; they remain inadmissible and are never deleted or overwritten (reruns go to new §14 artifact dirs).
- NO A3 amendment; NO protocol edits; NO commits/pushes.
- NO cosmetically removing the 58-divergence evidence: the fix must produce 0 divergences on a fresh rerun, and the frozen divergence set stays documented as the defect fingerprint.

---

## 12. Rerun implications

1. After design approval: TDD RED→GREEN → full suite → TT01 (§7-8) → acceptance (§10).
2. On acceptance + explicit run authorization: rerun the frozen 12-run batch on the fixed build (3 INTEGRITY + 9 treatment, same INIs/tiers/window, NEW artifact dirs `CONTROL_RLHYP01_*_FIX` or per §14 convention), telemetry v5.
3. Post-run gate on the new artifacts: expect gate 3a PASS (INTEGRITY), gate 3b PASS (0 divergences), canonical uniqueness, A1 reconstruction. If any gate fails → STOP, report, no statistics.
4. Only then: `--analyze` per the frozen protocol (A1 paired opportunity-level estimand, A2 canonical pairing, §6/§8/§15.3 step 9), day-stratified bootstrap (seed 20260811), 98.33% Bonferroni sensitivity.
5. The 58 frozen divergences are superseded by the fixed-build rerun; no statistics are ever computed on the frozen inadmissible set.

---

*Design-only document. No code, artifacts, protocol, or run state was modified in producing it beyond the already-reported analyzer gate-fix repairs from the pre-analysis gate run (which touch only `Tools/ED01/ED01_RLHYP01_Analyze.py` and were needed for the gate itself to execute).*