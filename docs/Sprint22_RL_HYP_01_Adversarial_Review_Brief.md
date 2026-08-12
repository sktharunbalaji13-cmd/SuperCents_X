# Sprint 22 RL-HYP-01 -- Independent Adversarial Review Brief (blinded)

| | |
|---|---|
| Experiment | RL-HYP-01 -- swing-significance admission gate (protocol §1) |
| Run set | 9 treatment arms (K1P0/K1P5/K2P0 x EURUSD_H1, EURUSD_M15, GBPJPY_H1) + 3 ungated integrity reruns |
| Reviewer role | **Independent adversarial reviewer** -- not the author of the primary investigation |
| Status | Sprint 22 run set is currently NOT accepted (protocol §11.3b: "Any divergence on an admitted row -> run set rejected"). Your review decides whether that rejection stands, is explained, or requires remediation. |
| Date | 2026-08-12 |
| Constraint | **Read-only.** No Strategy Tester reruns. No code edits. No protocol amendment. No new statistics beyond reproduction of counts and the structural checks in §5. |

---

## 0. Purpose

This brief hands you the frozen raw evidence and the exact question. It is
written so that you can derive your own conclusion from the artifacts and
source **before** reading the primary investigation report, which is included
in the corpus (§4, item 8) but must be treated as a **hypothesis under test**,
not as ground truth.

Your job is to determine whether the observed admitted-row divergence is
actually caused by **gate-dependent settlement deferral** -- and if it is
not, what else explains it. You must attempt to falsify that explanation.
The decision tree in §9 shows what your verdict triggers downstream.

---

## 1. The question

> Independently determine whether the 58 divergences observed on admitted
> rows are actually caused by gate-dependent settlement deferral. Do not
> assume any existing investigation is correct. Attempt to falsify that
> explanation using the artifacts and source code. Identify any alternative
> mechanism that could explain the same observations. Conclude (a) whether
> the experiment remains inadmissible and (b) whether a code-level isolation
> fix is required.

The phrase "gate-dependent settlement deferral" names the claim in the
report under test (§3.8 below). It is the thing you are testing, not
something you are asked to believe.

---

## 2. The observation to be explained (facts only)

These facts are directly measurable from the frozen CSVs; you must reproduce
them yourself (§5 step 1). They are stated here so you know what a complete
explanation must cover.

1. **Two arm types.**
   - **CONTROL** arms (`CONTROL/`): the frozen B8 baseline run, schema v4
     (`telemetry_v4_*.csv`), gate disabled (no gate columns present).
   - **Treatment** arms (`CONTROL_RLHYP01_{K1P0,K1P5,K2P0}/`): same profile,
     `SwingSignificanceTier` = 1.0 / 1.5 / 2.0, schema v5 (appends
     `swingQualifyingId`, `swingAmplitude`, `gateDecision`).
   - **INTEGRITY** arms (`CONTROL_RLHYP01_INTEGRITY/`): ungated rerun of the
     new code (tier 0.0).
2. **Pairing key** (protocol amendment A2): `{signalTime,
   configFingerprint, symbol, timeframe}`. `decisionId` is NOT a cross-arm
   key when gating is active (it renumbers). Verify `signalTime` is unique
   within each file.
3. **Admitted-row counts** (treatment rows with `gateDecision = ADMIT`):

   | Symbol | K1P0 | K1P5 | K2P0 |
   |---|---|---|---|
   | EURUSD_H1 | 820 | 691 | 521 |
   | EURUSD_M15 | 3327 | 2827 | 2096 |
   | GBPJPY_H1 | 840 | 695 | 512 |
   | **Total** | | | **12,329** |

4. **Divergences** (admitted treatment row differs from its CONTROL twin on
   at least 1 shared column outside `decisionId`, `schemaVersion`, and the
   3 gate columns):

   | Symbol | K1P0 | K1P5 | K2P0 |
   |---|---|---|---|
   | EURUSD_H1 | 0 | 0 | 0 |
   | EURUSD_M15 | 17 | 17 | 21 |
   | GBPJPY_H1 | 1 | 1 | 1 |
   | **Total** | | | **58** |

5. **Shape of every divergence.** For all 58 rows: `barsHeld` = 51 in both
   arms; CONTROL `exitReason` = 4 (HORIZON); `exitPrice` differs; `rMultiple`
   differs; a subset also differs in `outcome` and `exitReason`. Every
   entry-side shared column (`direction`, `entryPrice`, `signalTime`,
   `confidence`, all structure/rule/layer columns, `outcomeSource`) is
   byte-identical.
6. **Negative control.** EURUSD_H1 has zero divergences while having many
   bars where the gate did not admit. A complete explanation must explain
   why EURUSD_H1 diverges zero times.
7. **Integrity reruns** are claimed byte-identical to CONTROL (all shared
   columns, same row counts, same `decisionId` sequence). Verify.
8. **Tick-source identity.** The three symbols' tester tick caches share the
   same source hash `BC49990DA82BB15EE6C70B5A955C1ACF` (same broker tick
   stream for all three). The files are frozen and unmodified.
---

## 3. Evidence inventory (exact paths)

All paths are absolute. The workspace root is:

`C:\Users\k.tharun balaji\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\SuperCents_X`

### 3.1 Frozen protocol and amendments
- `docs\Sprint22_RL_HYP_01_Protocol.md` -- the frozen protocol. Read in
  particular: §4 (populations), §6 (estimand; d == 0 on admitted rows),
  §10 (power; the d == 0 identity), **§11 (engineering gates; §11.3b is the
  gate that fails)**, §14 (run production spec), §15.1 (freeze record /
  Amendment A1), §16.2 (Amendment A2 -- pairing key).
- `docs\Sprint22_Pairing_Identity_Review.md` -- the prior review that
  established the canonical pairing key (A2). Background on why `decisionId`
  renumbers under gating.
- `docs\CalibrationGuide.md` lines 112-117 -- the settlement pipeline
  contract.

### 3.2 Telemetry CSVs (primary ground truth)
- `Tools\ED01\artifacts\{EURUSD_H1,EURUSD_M15,GBPJPY_H1}\CONTROL\telemetry_v4_*.csv`
- `Tools\ED01\artifacts\{symbol}\CONTROL_RLHYP01_INTEGRITY\telemetry_v5_*.csv`
- `Tools\ED01\artifacts\{symbol}\CONTROL_RLHYP01_{K1P0,K1P5,K2P0}\telemetry_v5_*.csv`
- Each arm directory also has a `.done` marker (run completed).
- v5 column layout (78 columns) ends with the 3 gate columns
  `swingQualifyingId,swingAmplitude,gateDecision`. v4 is the same minus
  those 3 (75 columns). `timestamp` is a 1-bar lag duplicate of `signalTime`.

### 3.3 Tester tick caches (the shared tick stream)
Terminal root (NOT under the Experts folder):
`C:\Users\k.tharun balaji\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Tester\cache\`
- `SuperCents_X.EURUSD.H1.20260101_20260630.4.BC49990DA82BB15EE6C70B5A955C1ACF.tst`
- `SuperCents_X.EURUSD.M15.20260101_20260630.4.BC49990DA82BB15EE6C70B5A955C1ACF.tst`
- `SuperCents_X.GBPJPY.H1.20260101_20260630.4.BC49990DA82BB15EE6C70B5A955C1ACF.tst`

**Decode spec (a claim under test -- verify it yourself):** 256-byte records
beginning at file offset 4376; unix time @ byte 0, price @ byte 72, history
flags @ byte 80, session flags @ byte 96; each new bar begins with a
"boundary" tick whose time = barTime + 1 s. If your independent decode
disagrees, record that as a falsification of the methodology.

### 3.4 Source code (line references verified 2026-08-12)
- `Portfolio\SymbolContext.mqh`
  - lines 960-980 -- decision-row creation path: gate stamp
    (`SwingGateApplyToRow` @ 974), **`SettleDue()` @ 975**, queue @ 976-978.
    `SettleDue()` is invoked ONLY inside the gate-ADMIT branch. Verify no
    other call site exists in the codebase (search `SettleDue`).
  - lines 1422-1455 -- `SettleDue()`: `shift = iBarShift(..., false)` @ 1432;
    due iff `shift >= TELEMETRY_SETTLE_MAX_HOLD_BARS` @ 1433; settles via
    `SettleRow` + `Record` @ 1435-1443; otherwise defers (keeps pending) @
    1444-1453.
  - lines 1457+ -- `SettleRemaining()` (run-tail UNKNOWN rows at deinit).
- `Telemetry\ForwardOutcomeSimulator.mqh`
  - lines 90-177 -- `Simulate`: scans bars `entryBarIndex-1 ... minBar` where
    `minBar = entryBarIndex - m_maxHoldBars` (line 100, `m_maxHoldBars = 50`
    @ line 56); horizon exit at `close[minBar]`, `barsHeld =
    (entryBarIndex - minBar) + 1 = 51` @ 170-176; SL/TP are fixed-price
    exits @ 129-162.
- `Telemetry\TelemetryTypes.mqh` lines 45-53 -- v5 schema semantics; gate
  column defaults are neutral (0 / 0.0 / "OFF") so ungated rows stay
  byte-identical in shared columns.
- `Telemetry\TelemetryCollector.mqh` lines 257-258 -- `decisionId` is
  assigned at `Record()` time and counts only recorded rows.
- `Utils\Constants.mqh` -- `TELEMETRY_SETTLE_MAX_HOLD_BARS` (verify = 50).
### 3.5 Run state
- `Tools\ED01\ED01_RLHYP01_manifest.json` -- 12-run manifest (tiers,
  fingerprints, expected counts, window [2026.04.05, 2026.07.05]).
- `Tools\ED01\results_RLHYP01_selfcheck.json` -- analyzer self-check
  (machinery probe, all zero delta; audit pass). Note: this is PRE-analysis;
  there is no post-run `results_RLHYP01.json` -- the analysis never ran,
  because §11.3b blocked it.
- `Tools\ED01\run_RLHYP01.log` -- the run batch log.
- `Tools\ED01\ED01_RLHYP01_Analyze.py` -- the frozen analyzer (reference for
  what the analysis WOULD have computed).

### 3.6 "Gate 3b failure report"
There is no standalone document by that name. The "failure" is the
**violation of protocol §11.3b** (admission-only invariance) observed on the
frozen artifacts: 58 admitted rows differ from CONTROL. The operative record
is §11.3b of the protocol + the divergence observation (§2 above). The run
set is therefore in a rejected/pending state.

### 3.7 Investigation scripts (UNTRUSTED -- methodology under scrutiny)
`Temp\` contains scripts the primary investigation used. **Do not trust
them.** Read them only to find claims to falsify:
- `show_divergences.py`, `ticks_for_day.py`, `tst_price_proof.py`,
  `gate3b_completeness.py`, `boundary_by_hour.py`, `gateout_by_hour.py`,
  `verify_gate3b_hypothesis.py`, `investigate_gate3b.py`, `decode_tst.py`,
  `reproduce_divergences.py`, `verify_necessity_sufficiency.py`,
  `check_exit_reasons.py`.
- Re-derive every number yourself from the CSVs and caches; flag any script
  logic you believe is wrong.

### 3.8 The claim under test (read LAST)
`docs\Sprint22_RL_HYP_01_Divergence_Investigation.md` -- the primary
investigation report. Its central claim:

> A row diverges IFF its CONTROL settlement bar (the first bar >= 50 bars
> after entry where `SettleDue()` runs) is GATE-OUT in the treatment arm AND
> its CONTROL exit is a 50-bar horizon exit. GATE-OUT defers settlement to a
> later admitted bar; the deferred `SettleRow` re-runs the same 50-bar
> forward scan but reads the boundary bar's **closed** OHLC instead of the
> forming bar's first-tick price.

---

## 4. Reading order (anti-anchoring rule)

Do **not** read `Sprint22_RL_HYP_01_Divergence_Investigation.md` first.

1. This brief.
2. Protocol §4/§6/§10/§11/§15/§16 + `CalibrationGuide.md` settlement section.
3. The CSVs and the source code (§3.2, §3.4). Form your own hypothesis about
   the mechanism **before** looking at any investigation script or report.
4. The tick caches (§3.3) if you want price-level verification.
5. Write your draft conclusion.
6. Only then read the investigation report (§3.8) and the scripts (§3.7).
   Go claim-by-claim. Where the report states a mechanism or a number,
   independently confirm or refute it.
7. Produce the deliverable (§8).
---

## 5. Falsification protocol (mandatory steps)

For each step, record what you tested, how, and the result (pass / fail /
inconclusive).

1. **Reproduce the numbers.** Recompute admitted counts and the 58-row
   divergence sets from the CSVs (§2.3-2.4) using the A2 pairing key.
   Confirm the counts. Confirm that every diverging row has `barsHeld` = 51
   and CONTROL `exitReason` = 4 in both arms.
2. **Necessity and sufficiency.** Independently compute each admitted row's
   CONTROL settlement bar (the 50th CONTROL decision bar after entry, using
   the CONTROL decision-time series -- the analogue of `iBarShift(...,false)
   >= 50`). Test the exact bijection:
   - diverging <=> (settlement bar GATE-OUT in treatment) AND (CONTROL
     exitReason = 4).
   - Rows with a GATE-OUT settlement bar but a CONTROL SL/TP exit must NOT
     diverge (deferral changes nothing for a fixed-price exit). Any row that
     violates either direction falsifies the mechanism.
3. **Integrity rerun.** Verify INTEGRITY vs CONTROL: same row counts, same
   `decisionId` sequence, byte-identical on all shared columns. This is the
   code-equivalence control that rules out nondeterminism and v4/v5
   serialization drift.
4. **Price-level proof (headline rows).** Decode the `.tst` cache (§3.3) and
   verify, for at least these rows, that the CONTROL exitPrice equals the
   boundary bar's forming close (first-tick price) and the treatment
   exitPrice equals the closed boundary bar's close:
   - `EURUSD_M15` `2026.04.28 18:45` -- CONTROL 1.17064 (tick `07:15:01` of
     the next day) vs treatment 1.17056 (tick `07:30:01`).
   - `GBPJPY_H1` `2026.04.30 21:00` -- CONTROL 212.652 ~ boundary tick
     212.653 (1 pip) vs treatment 212.748 (tick `2026-05-05 00:01:01`).
   If the decoded ticks do not reproduce these prices, the mechanism is
   falsified or the decode spec is wrong (record which).
5. **Negative control.** EURUSD_H1: confirm zero CONTROL horizon exits
   (exitReason = 4) and confirm it does have GATE-OUT settlement bars.
   Explain why the mechanism predicts zero divergences there. If you find a
   diverging EURUSD_H1 row, the mechanism is falsified.
6. **Counterexample search.** Search all 12,329 admitted rows for:
   - a diverging row whose CONTROL exitReason != 4, or whose settlement bar
     is not GATE-OUT;
   - a row with GATE-OUT settlement bar + horizon exit that does NOT diverge;
   - any diverging row with a differing entry-side column.
   Each found case is a falsification.
7. **Cross-tier consistency.** Rows like `2026.04.16 20:00`, `2026.04.28
   19:45`, `2026.05.04 20:45`, `2026.06.11 23:15` diverge at multiple tiers.
   Check that every tier's diverging set is a subset of the GATE-OUT-settle
   + horizon rows for that tier.
8. **Source audit.** Independently trace `SettleDue()` call sites and the
   settlement algebra. Confirm the ONLY call site is the gate-ADMIT branch
   (SymbolContext.mqh:975) and confirm there is no other path (OnDeinit,
   per-tick, OnTrade) that could settle a pending row on a GATE-OUT bar.
---

## 6. Alternative mechanisms to consider

For each, either rule it out with a specific artifact/source test or state
that you could not rule it out. These are deliberately NOT the report's
mechanism; treat them as competing explanations.

1. **Nondeterminism / tick-replay drift between runs.** Test: INTEGRITY
   byte-identity; frozen caches; identical cache hash across symbols.
2. **Telemetry serialization error (v4 vs v5 column misalignment).** Test:
   header alignment; INTEGRITY byte-identity; divergence limited to exit
   columns only.
3. **Shared-state contamination (pending-queue bleed across rows).** Test:
   entry-side columns identical; divergence pattern row-local; no cross-row
   correlation beyond the settlement bar.
4. **The gate is not admission-only (it perturbs upstream state -- swing
   chain, candidate pool, ATR, confidence).** Test: entry-side byte-identity
   on ALL shared columns; `swingQualifyingId/swingAmplitude/gateDecision`
   are the only differing non-exit columns.
5. **Warm-start / run-window differences.** Test: diverging rows are
   interior (not at window edges); fingerprints identical; the same
   `signalTime` population is paired.
6. **Entry-bar index / `iBarShift` off-by-one between runs** (e.g., bars
   loaded differ). Test: `barsHeld` = 51 and `entryPrice` identical on all
   diverging rows; same CONTROL settlement bar computed two ways.
7. **Outcome-policy inputs differing at settle time** (SL/TP/riskDistance
   recomputed from a shifted window). Test: diverging exitPrice is exactly a
   bar-close value; SL/TP (fixed-price) exits never diverge; the horizon
   exitPrice matches a cache tick rather than a policy-computed price.
8. **The report's "settlement bar" computation is wrong** (wrong bar
   identification in CONTROL). Test: recompute the settlement bar
   independently (§5 step 2) and check the completeness/sufficiency
   bijection holds with YOUR computation, not theirs.
9. **Data-stream difference** (broker tick mismatch between runs). Test:
   cache hash identity; `configFingerprint` identity; INTEGRITY byte-
   identity.

---

## 7. What "explained" and "not explained" look like

The report's mechanism is **confirmed** only if, independently of the report:

- the two-direction bijection of §5 step 2 holds with zero exceptions across
  all 12,329 admitted rows, AND
- the price-level proofs of §5 step 4 reproduce the stored exit prices, AND
- no alternative mechanism in §6 survives scrutiny, AND
- the `SettleDue()` single-call-site source claim is verified.

If any of these fails, the mechanism is **challenged** and you must say
exactly which step failed and what alternative you found or suspect.

---

## 8. Deliverable format

Return a structured review with these sections:

1. **Executive verdict** -- one of: `ROOT CAUSE CONFIRMED` /
   `ROOT CAUSE CHALLENGED` / `ROOT CAUSE UNCONFIRMED - ALTERNATIVE(S)
   PROPOSED`.
2. **Independently derived mechanism** -- stated in your own words with
   source citations (file:line) and artifact evidence.
3. **Falsification attempts** -- table: step (§5), test, result, notes.
4. **Alternative mechanisms** -- table: mechanism (§6), ruled out?
   (evidence) or not ruled out (why).
5. **Claim-by-claim audit of the primary report** -- for each major claim in
   `Sprint22_RL_HYP_01_Divergence_Investigation.md`: agree / disagree /
   unverifiable, with your evidence. Quote the report's own claim numbers
   and check them.
6. **Conclusions** --
   (a) Does the experiment remain inadmissible under protocol §11.3b?
   (b) Is a code-level isolation fix required (e.g., relocating settlement
       out of the gate path), or is this an analysis-level artifact?
   (c) Recommended next action per §9.

---

## 9. Decision-tree mapping

```
Adversarial review
   |-- Root cause confirmed
   |       |
   |       v
   |   Design isolation fix
   |       |
   |       v
   |   TDD RED -> GREEN
   |       |
   |       v
   |   TT01
   |       |
   |       v
   |   Decide whether rerun is required
   |
   `-- Root cause challenged
           |
           v
      Further investigation
```

Your verdict selects the branch. Do not prescribe the fix itself; state
whether a fix is required and what its acceptance criteria should be.

---

## 10. Constraints

- Read-only investigation. No Strategy Tester runs, no code edits, no
  protocol amendment, no analyzer changes.
- No statistics beyond: reproduction of counts, the structural bijection of
  §5 step 2, and the price reproductions of §5 step 4. No CIs, no Delta
  Mean R, no verdicts about the hypothesis (RL-HYP-01) itself.
- If an artifact appears missing or inconsistent with the manifest, record
  it rather than repairing it.
- Cite every conclusion to a specific artifact or source line.
