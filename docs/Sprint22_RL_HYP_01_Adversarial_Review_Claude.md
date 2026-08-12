# Sprint 22 RL-HYP-01 — Independent Adversarial Review (Claude)

| | |
|---|---|
| Reviewer | Claude — primary independent adversarial reviewer (Prompt A, `Sprint22_RL_HYP_01_Adversarial_Review_Order.md` §3.1) |
| Brief | `docs/Sprint22_RL_HYP_01_Adversarial_Review_Brief.md` (blinded) |
| Report under test | `docs/Sprint22_RL_HYP_01_Divergence_Investigation.md` (treated as hypothesis, not ground truth) |
| Date | 2026-08-12 |
| Method | Independent re-derivation from frozen artifacts + source, THEN claim-by-claim audit. Read-only. |
| Verdict | **ROOT CAUSE CONFIRMED** |

---

## 1. Executive verdict

**`ROOT CAUSE CONFIRMED`.**

The 58 admitted-row divergences on the frozen Sprint 22 artifacts are caused by
**gate-dependent settlement deferral**: `SettleDue()` is called only inside the
gate-ADMIT branch of the decision path (`Portfolio/SymbolContext.mqh:975`, sole
call site verified by exhaustive source grep), so when the CONTROL settlement bar
(the 50th bar after entry) is GATE-OUT in the treatment arm, the queued row's
settlement is deferred to a later admitted bar. The re-run evaluates the same 50
physical forward bars, but the boundary bar — which the CONTROL settlement read
as a **forming** bar (index 0, `open=high=low=close=first-tick price`) — is now
**closed**, and the horizon exit reads `close[minBar]`
(`Telemetry/ForwardOutcomeSimulator.mqh:172`) — the bar's **final close**. All 58
divergences are exactly the rows for which (a) the CONTROL settlement bar is
GATE-OUT in the treatment arm AND (b) the CONTROL exit is the 50-bar horizon exit
(`barsHeld=51`, `exitReason=4`). The bijection holds in both directions with
**zero exceptions** over all 12,329 admitted rows; the price-level proof
reproduces the actual exit prices from the frozen `.tst` tick cache; no
alternative mechanism survives the falsification protocol.

---

## 2. Independently derived mechanism (derived BEFORE reading the report)

Derivation from the source and artifacts only:

1. **Decision path structure** (`Portfolio/SymbolContext.mqh:853–979`). Each bar,
   after the swing gate evaluates (`SwingGateEvaluate` @ 860):
   - GATE-OUT branch (`:862–867`): logs only — no decision row, no
     `SettleDue()`, no `QueueForSettlement()`.
   - ADMIT branch (`:868–979`): builds the telemetry row, stamps the gate columns
     (`:974`), then `SettleDue()` (`:975`) and `QueueForSettlement(row, …)`
     (`:976–978`).
   `SettleDue()` appears in the source exactly once as a call site (`:975`);
   definition at `:1422–1455`.
2. **Settlement eligibility** (`:1432–1433`). A queued row is due when
   `iBarShift(entryBarTime, false) >= TELEMETRY_SETTLE_MAX_HOLD_BARS` (= 50,
   defined `:67`). So in CONTROL (gate off, one decision per bar) the first
   settlement opportunity is on the first tick of the 50th bar after entry.
3. **SettleRow window** (`:1350–1419`). Copies `[warmStart, stopTime]` by
   time-range `Copy*` (ascending), reverses to as-series (index 0 = newest =
   the bar current at settlement), locates the entry bar **by time**
   (`:1392–1400`), requires `entryBarIndex >= 50` (`:1401`), and runs
   `CForwardOutcomeSimulator::Simulate`.
4. **Simulator algebra** (`Telemetry/ForwardOutcomeSimulator.mqh:63–177`).
   `entryPrice = open[entryBarIndex]` (`:83`); scan `entryBarIndex−1 … minBar`
   with `minBar = entryBarIndex − m_maxHoldBars` (`:100`, `m_maxHoldBars = 50`,
   `:56`); SL/TP are **fixed-price** exits (`:129–162`); horizon exit
   `out.exitPrice = close[minBar]`, `out.barsHeld = (entryBarIndex − minBar) + 1`
   (`:170–176`); outcome classification with `|rMultiple| <= 0.05` → BREAKEVEN
   (`:34–51`).
5. **CONTROL (gate off)**. On the first tick of the 50th bar after entry the bar
   is still forming; in the as-series window index 0 is that forming bar with
   `open=high=low=close=` first-tick price. `entryBarIndex = 50`, `minBar = 0`,
   horizon exit reads `close[0]` = first-tick price, `barsHeld = 51`.
6. **Treatment (gate on)**. If the same bar is GATE-OUT, no decision row is
   created and `SettleDue()` does not run; the row stays pending. When a later
   admitted bar runs `SettleDue()`, `entryBarIndex = 50 + k` (k = deferral), so
   `minBar = k` points at the **same physical boundary bar** — now closed. The
   horizon exit reads `close[k]` = the boundary bar's final close, which in
   general differs from its first-tick price. `barsHeld` remains 51. SL/TP exits
   are unaffected because they are fixed-price and the same physical bars are
   scanned.

**Predicted observable pattern** (derived before reading the report): a row
diverges **iff** (a) its CONTROL settlement bar (50th CONTROL decision bar after
entry) is GATE-OUT in treatment AND (b) its CONTROL exit is `exitReason = 4`.
All diverging rows: `barsHeld = 51` in both arms, entry-side columns
byte-identical, exit-side only (`exitPrice`, `rMultiple`, sometimes
`outcome`/`exitReason`) differ.

---

## 3. Falsification attempts (brief §5, 8 steps)

All recomputed independently from the frozen CSVs / caches / source. Pairing key:
`{signalTime, configFingerprint, symbol, timeframe}` (A2); configFingerprint is a
single constant per symbol across CONTROL, INTEGRITY and all 9 treatment arms
(EURUSD_H1 `3005138848403243456`, EURUSD_M15 `13548296177162108249`, GBPJPY_H1
`14617585492269479818`), so signalTime pairing ≡ canonical pairing.

| # | Test (brief §5) | Result | Notes |
|---|---|---|---|
| 1 | Reproduce counts + divergence sets | **PASS** | 12,329 admitted; 58 diverging; per arm 0/0/0 (H1), 1/1/1 (GBPJPY), 17/17/21 (M15). Every diverging row: `barsHeld=51` both arms, CONTROL `exitReason=4`. |
| 2 | Necessity & sufficiency bijection | **PASS** | `diverging ⇔ (GATE-OUT settlement bar) ∧ (CONTROL exitReason=4)` holds with **0 violations** across all 9 arms (GATE-OUT-settle+horizon = diverging = 0/0/0/1/1/1/17/17/21; GATE-OUT-settle+non-horizon never diverges; non-GATE-OUT never diverges). |
| 3 | Integrity rerun vs CONTROL | **PASS** | Same row counts (1558/6239/1560), same `decisionId` sequence, **0** differing shared columns (excluding `schemaVersion`), 0 missing/extra rows — byte-identical. |
| 4 | Price-level proof (headline rows) | **PASS** | See §6 below: GBPJPY `2026.04.30 21:00` and M15 `2026.04.28 18:45` reproduced from the `.tst` cache. |
| 5 | Negative control (EURUSD_H1) | **PASS** | EURUSD_H1 CONTROL has **zero** `exitReason=4` rows and **zero** `barsHeld=51` rows, yet has 376/360/318 GATE-OUT settlement bars → mechanism predicts zero divergences; zero found. |
| 6 | Counterexample search (all 12,329 rows) | **PASS** | No diverging row with CONTROL `exitReason≠4`; no diverging row with a non-GATE-OUT settlement bar; no GATE-OUT-settle+horizon row that fails to diverge; **zero** diverging rows with any entry-side column differing. |
| 7 | Cross-tier consistency | **PASS** | Every tier's diverging set ⊆ that tier's GATE-OUT-settle+horizon set. Headline rows `2026.04.16 20:00`, `2026.04.28 19:45`, `2026.05.04 20:45`, `2026.06.11 23:15` diverge at all 3 M15 tiers. |
| 8 | Source audit | **PASS** | `SettleDue()` sole call site `SymbolContext.mqh:975` (grep of all `.mqh/.mql5/.mq5`: only declaration `:172`, call `:975`, definition `:1422`). No OnDeinit/per-tick/OnTrade path settles on a GATE-OUT bar (`SettleRemaining` `:1457–1480` runs only at deinit on rows still pending). `minBar`/`barsHeld` algebra verified against `ForwardOutcomeSimulator.mqh:100, 170–176`. |

Also verified as foundational (unlisted in the brief but load-bearing):
- **CONTROL row timeline = bar timeline.** Gap histogram of CONTROL `signalTime`
  series: `{1 bar: all, 49 bars: 12}` — every market-hour bar present; the 12
  weekend gaps exactly explain `span_bars − rows` (EURUSD_H1 2134−1558=576). The
  "50th CONTROL decision bar after entry" computation is therefore a faithful
  analogue of `iBarShift(..., false) >= 50`.
- **No-unmatched pairing.** 0 treatment-ADMIT rows lack a CONTROL twin in any arm.
- **Frozen inputs.** All three 6-month `.tst` caches carry the same source hash
  `BC49990DA82BB15EE6C70B5A955C1ACF`, and their file mtimes are **2026-08-01**
  (before the 2026-08-11 run batch): EURUSD.H1 2026-08-01 18:25:21,
  EURUSD.M15 2026-08-01 18:23:06, GBPJPY.H1 2026-08-01 18:27:24
  (sha256[:16] `80684d11fa5d2d6b` / `9594632e01215b7a` / `79b1979bd5f47b06`).
- **Treatment files contain only ADMIT rows** (0 non-ADMIT rows in all 9 arms),
  consistent with the GATE-OUT branch creating no telemetry row.


---

## 4. Alternative mechanisms (brief §6) — ruled out / not ruled out

| # | Alternative mechanism | Ruled out? | Evidence |
|---|---|---|---|
| 1 | Nondeterminism / tick-replay drift between runs | **Ruled out** | INTEGRITY rerun (new code, ungated) is byte-identical to CONTROL on all shared columns with identical `decisionId` sequence; caches frozen 2026-08-01; same source hash for all three symbols. |
| 2 | Telemetry serialization error (v4/v5 misalignment) | **Ruled out** | v5 = v4's 75 columns + 3 gate columns appended (header verified); INTEGRITY (also v5) is byte-identical to v4 CONTROL; divergences confined to exit-side columns with real price deltas reproduced from the cache. |
| 3 | Shared-state contamination / pending-queue bleed | **Ruled out** | Entry-side columns byte-identical on every diverging row; only 2–4 exit-side columns differ per row; divergence pattern is row-local and exactly predicted by the settlement-bar condition. |
| 4 | Gate perturbs upstream state (swing chain, candidate pool, ATR, confidence) | **Ruled out** | All shared entry-side/decision columns byte-identical; the only differing non-exit columns are the 3 gate columns themselves. |
| 5 | Warm-start / run-window differences | **Ruled out** | Diverging rows are interior (latest diverging entry 2026.06.26 20:30 M15; boundary bar well inside the run); fingerprints identical; pairing total. |
| 6 | Entry-bar index / `iBarShift` off-by-one between runs | **Ruled out** | `barsHeld=51` and `entryPrice` identical on all diverging rows; settlement bar recomputed independently (CONTROL-row count) and cross-checked on the price-proof rows against the actual boundary-bar timestamps recovered from the cache. |
| 7 | Outcome-policy inputs differing at settle time | **Ruled out** | SL/TP (fixed-price) exits never diverge even with a GATE-OUT settlement bar (0 safety violations); the horizon `exitPrice` matches a cache **tick** (1.17064/1.17056/212.748), not a policy-computed level; treatment rMultiple uses the identical `riskDistance` (verified arithmetically, report §7.4). |
| 8 | The report's settlement-bar computation is wrong | **Ruled out** | Independent recomputation (this review) yields the same bijection with 0 exceptions; price proofs land exactly on the bars the independent computation predicts. |
| 9 | Data-stream / broker-tick difference between runs | **Ruled out** | Identical cache source hash across symbols and arms; `configFingerprint` identical; INTEGRITY byte-identity proves the same tick stream + code produce identical outputs. |

No alternative mechanism survives; none is required — the gate→settlement
coupling explains all 58 divergences exactly and predicts the full pattern
including the zero-divergence negative control.


---

## 5. Claim-by-claim audit of the primary report

Verdicts: **AGREE** / **DISAGREE** / **UNVERIFIABLE**, with evidence.
"Unverifiable" is reserved for claims outside the review's permitted methods.

| # | Report claim | Verdict | Independent evidence |
|---|---|---|---|
| C1 | 58 diverging rows: GBPJPY 1/tier, M15 17/17/21, H1 0 (§1, §4.1) | **AGREE** | Reproduced exactly (§3 table). |
| C2 | Divergence confined to exit-side fields (`exitPrice`, `rMultiple`, occasionally `outcome`/`exitReason`); entry-side byte-identical (§1, §4.2) | **AGREE** | 0 entry-side diffs across all 58 rows; differing columns per row ⊆ {exitPrice, rMultiple, outcome, exitReason}. |
| C3 | Root cause: `SettleDue()` only inside gate-ADMIT path (`SymbolContext.mqh:975`); GATE-OUT defers settlement; deferred re-run reads closed boundary bar (§1, §5) | **AGREE** | Sole call site verified by exhaustive grep; algebra verified; bijection holds with 0 exceptions. |
| C4 | Price proof: GBPJPY 212.652 ≈ 212.653 (1 pip), 212.748 = 00:01:01 tick; M15 1.17064 = 07:15:01 tick, 1.17056 = 07:30:01 tick (§1, §7.2–7.3) | **AGREE** | Independently decoded `.tst` records reproduce every one of these values exactly (§6). |
| C5 | `TELEMETRY_SETTLE_MAX_HOLD_BARS` = 50 "per docs/CalibrationGuide.md:115" (§3) | **AGREE** (nit) | Constant defined at `Portfolio/SymbolContext.mqh:67`; CalibrationGuide.md:115 documents it. (The brief's own "Utils/Constants.mqh" location is also wrong — it lives in SymbolContext.mqh.) |
| C6 | Settlement-bar semantics: `iBarShift(..., false) >= 50`; window `[warmStart, stopTime]`; entry bar located by time (§3, §5.2) | **AGREE** | `SymbolContext.mqh:1432–1433, 1350–1400` verified verbatim. |
| C7 | Horizon exit: `close[minBar]`, `minBar = entryBarIndex − 50`, `barsHeld = 51` (§3, §5.2) | **AGREE** | `ForwardOutcomeSimulator.mqh:100, 170–176`; `barsHeld=51` confirmed on all 58 rows. |
| C8 | §4.1 completeness: 0 diverging rows without GATE-OUT settlement bar; GATE-OUT-settle counts 376/360/318, 389/382/329, 1559/1568/1389 | **AGREE** | All nine counts reproduced exactly. |
| C9 | §4.3 representative rows (5 rows incl. 19:45 SL flip, 19:00 breakeven flip) | **AGREE** | All five rows reproduced (values match byte-for-byte). |
| C10 | §5.4 "exitReason flips to SL/TP (observed once, §4.3 row 4)" | **DISAGREE** (minor) | Two exitReason flips occur in each M15 arm (K1P0/K1P5: `2026.04.28 19:45` 4→2 SL and `2026.06.23 17:30` 4→1 TP; K2P0: 19:45 4→2 and `2026.05.28 18:00` 4→2). The report's own §4.2 column-frequency for K1P0 shows `exitReason ×2`. "Observed once" undercounts; the mechanism claim is unaffected. |
| C11 | §5.5 divergences concentrate at session-end entries; boundary exit is the necessary trigger | **AGREE** | `boundary_by_hour` reproduction: EURUSD_M15 boundary-exit rate 0.77% (16:00), 2.31% (17:00), 6.92% (18:00), 10.77% (19:00), 10.38% (20:00), 1.92%/1.54%/2.69% (21/22/23). All diverging-row entry hours are in the boundary-exit-bearing hours. |
| C12 | §6.2 "0 boundary exits for hours 00–15" + parenthetical "(Hours 01:00 and 03:00 each have 1 boundary exit)" | **AGREE** (imprecision) | hours 01 and 03 each have exactly 1 `barsHeld=51` row (260 rows/hour). The sentence "0 for hours 00–15" is strictly false (01, 03 have 1 each) but the parenthetical discloses it; §6.2's percentages are all reproduced exactly. |


| C13 | §6.3 gate-out rate uniform by hour (38.85%–56.15%, no session-end spike) | **AGREE** | Reproduced: hourly GATE-OUT rate ranges 38.85%–56.15%; hour 18 = 43.85%, 19 = 48.85%, 20 = 53.46% — flat, no spike at the divergence concentration hours. |
| C14 | §6.4 determinism: identical row across tiers; INTEGRITY byte-identical | **AGREE** | GBPJPY `2026.04.30 21:00` diverges at all 3 tiers with identical prices; INTEGRITY byte-identical (§3 test 3). |
| C15 | §7.1 cache layout: 256-byte records at offset 4376, time@0, price@72, prev@80, session@96; sparse subsample | **AGREE** | Independently decoded with the same offsets; sparse (≈28–82 records/day by file size); boundary ticks stamped at barTime+1s confirmed (e.g. `1777935601` = 2026-05-04 23:00:01). |
| C16 | §7.2 proof A detail: snapshot `2026-05-05 12:00:11` carries `p80=212.65300` and `p80=212.74800` side by side | **AGREE** | Both values present in the p80 history field at that timestamp. |
| C17 | §7.4 arithmetic: GBPJPY `riskDistance 0.8860`, implied `rMultiple 0.2573`; M15 `0.000842`, implied `−0.5818` | **AGREE** | Recomputed from the CSVs: 0.886 / 0.2573 and 0.000842 / −0.5818 exactly. |
| C18 | §7.5 systematic sweep: "every boundary bar whose first tick is stored matches the CONTROL exit (EURUSD exact; GBPJPY within 1 pip)"; treatment matches where ticks exist; `no` where sparse | **AGREE** (nuance) | Running `tst_price_proof.py`: 9 recoverable datapoints across the 58 rows; 7 exact, 2 within 0.00001–0.00014 (EURUSD 1.172210 vs 1.172200; 1.172060 vs 1.171919) and GBPJPY within 1 pip. "EURUSD exact" is 7/9 with 2 near-matches consistent with sparse subsampling; the report's closing caveat ("every recoverable datapoint agrees; none contradicts") holds. |
| C19 | §8 classification: deterministic gate→settlement coupling via session-boundary geometry | **AGREE** | The full bijection + price proofs + source trace support exactly this classification. |
| C20 | §9 alternatives table (6 rows) | **AGREE** | Each "ruled out by" argument independently verified (§4 table). |
| C21 | §10 impact: 58 rows = 0.47% of 12,329 | **AGREE** | 58/12,329 = 0.4704%. |
| C22 | §11 limitations: sparse cache; GBPJPY 1-pip vs EURUSD exact; deferred settlement bar inferred not logged | **AGREE** | All three limitations reproduced exactly; the third is honest (the exact deferral bar is not logged; it is inferred from the invariants). |
| C23 | Claim that no production/statistical verdict was produced and Sprint 22 remains inadmissible | **AGREE** | Consistent with the manifest/selfcheck/log (no post-run analyzer result file exists; only the selfcheck machinery probe). |

**Unverifiable within this review's mandate:** none of substance. The only
non-reproducible item is the exact deferred settlement bar per row (not logged),
which the report itself discloses; the exit invariants (`barsHeld=51`,
exitReason flips) are consistent with it.


---

## 6. Price-level proof detail (brief §5 step 4 / report §7)

Independent `.tst` decode (offset 4376, 256-byte stride, time@0, price@72,
prev@80):

**GBPJPY_H1, entry `2026.04.30 21:00`, boundary bar `2026-05-04 23:00`:**
- `2026-05-04 23:00:01` → `p72 = 212.65300` (boundary bar first tick). CONTROL
  `exitPrice 212.65200` — within 1 pip (bid/ask field, as the report states).
- `2026-05-05 00:01:01` → `p72 = 212.74800` (close of the 23:00 bar) = treatment
  `exitPrice 212.74800` **exactly**.
- `2026-05-05 12:00:11` carries `p80` values 212.65300 and 212.74800 in one
  snapshot (history field).

**EURUSD_M15, entry `2026.04.28 18:45`, boundary bar `2026-04-29 07:15`:**
- `2026-04-29 07:15:01` → `p72 = 1.17064000` = CONTROL `exitPrice 1.17064000`
  **exactly** (forming bar first-tick price).
- `2026-04-29 07:30:01` → `p72 = 1.17056000` = treatment `exitPrice 1.17056000`
  **exactly** (closed bar final close).

These are the two headline proofs required by the brief; both reproduce
byte-for-byte. The complete sweep (58 rows) shows the same pattern wherever the
cache has ticks (7 exact / 2 within 0.1–1.4 pips / GBPJPY within 1 pip; no
contradiction anywhere).

---

## 7. Conclusions

**(a) Does the experiment remain inadmissible under protocol §11.3b?**
**Yes.** §11.3b (admission-only invariance) is violated by the frozen artifacts:
58 admitted rows differ from their CONTROL twins on shared columns. The
mechanism *explains* the violation; it does not remove it. The run set remains
inadmissible and no statistics may be produced on these arms as frozen.

**(b) Is a code-level isolation fix required?**
**Yes — a settlement-scheduling isolation fix is required.** The root cause is a
coupling: settlement eligibility (`SettleDue()`) is invoked only inside the
gate-ADMIT branch (`SymbolContext.mqh:975`), so the gate's scheduling side
effect (deferring settlement past GATE-OUT bars) changes the exit read state of
an already-admitted row. This is a genuine code-level defect under the
admission-only contract, not merely an analysis-level artifact. Acceptance
criteria for a fix (design decision, not implementation, per brief §9):
1. An admitted row's forward-outcome simulation must be a pure function of the
   entry bar and the tick/bar stream — **independent of whether any later bar
   admits**;
2. Settlement must be attempted on GATE-OUT bars too (or by absolute bar count),
   so the boundary bar is always read in the same state as CONTROL;
3. After the fix, an ungated rerun and a tiered rerun must be byte-identical on
   all shared columns except the 3 gate columns (admission-only invariance
   restored), with the existing INTEGRITY byte-identity as the regression
   control;
4. No change to B8 behavior (gate OFF arms must stay byte-identical to CONTROL).

**(c) Recommended next action per §9.**
The verdict selects the **ROOT CAUSE CONFIRMED** branch:
1. **Stop for human review** — the Order's hold stays in force; no rerun, no
   protocol change, no production change (report §11.3; Order §6).
2. Proceed to **design isolation fix** (settlement out of the gate path), then
   TDD RED→GREEN with TT01, then decide whether a rerun of the affected arms is
   required (Order §5). Whether the 58 rows need re-derivation on a fixed build,
   or whether the effect size is immaterial, is an analysis decision that this
   review does not make.

---

*Review constraints honored: read-only; no Strategy Tester runs; no edits to
code, protocol, or analyzer; only the reviewer's own Temp scripts
(`ar01`–`ar10`) were used, and the reviewer's own `ar10_consolidate.py` cache
path was corrected so it can emit its consolidated output. Every number in this
review was recomputed from the frozen CSVs, caches, and source; citations are
to the frozen artifacts as they exist on 2026-08-12.*

