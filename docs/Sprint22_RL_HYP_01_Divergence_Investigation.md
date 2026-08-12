# Sprint 22 — Gate 3b Settlement-Divergence Investigation Report

- **Date:** 2026-08-12
- **Status:** INVESTIGATION COMPLETE — AWAITING INDEPENDENT REVIEW + HUMAN REVIEW
- **Scope:** read-only root-cause investigation only. **No** fixes, **no**
  production / B8 / frozen-protocol changes, **no** Strategy Tester re-runs,
  **no** statistics or verdicts were produced or authorized.

---

## 1. Executive Summary

Activating the **swing-significance admission gate (Gate 3b)** changes
settlement / exit results for a small set of otherwise-admitted Sprint 22
opportunities — **58 rows across the 9 symbol/tier arms** (GBPJPY_H1: 1 per
tier; EURUSD_M15: 17 / 17 / 21; EURUSD_H1: 0). The change is confined to the
exit-side outcome fields (`exitPrice`, `rMultiple`, and occasionally `outcome`
or `exitReason`). Every shared entry-side field — `signalTime`, `direction`,
`entryPrice`, `barsHeld`, `outcomeSource` — is byte-identical between arms.

**Root cause (deterministic gate → settlement coupling):** a row diverges only
when its CONTROL settlement bar — the 50th bar after entry, where the forward
outcome is first settled — is **GATE-OUT** in the treatment arm *and* the
CONTROL exit is a **50-bar boundary/horizon exit** (`barsHeld = 51`,
`exitReason = 4`). Because `SettleDue()` runs only inside the gate-admitted
decision path (`Portfolio/SymbolContext.mqh:975`), a GATE-OUT settlement bar
defers the queued row's settlement to a later bar. The deferred settlement
re-runs the **same 50-bar forward scan**, but the boundary bar is now **closed**
and is read with its **final OHLC** instead of its **forming-bar / first-tick
OHLC**. The horizon exit (`Telemetry/ForwardOutcomeSimulator.mqh:172`,
`out.exitPrice = close[minBar]`) therefore reads a different price.

**Price-level proof:** the MT5 tester `.tst` tick cache for the 6-month runs
confirms both sides on concrete rows. E.g. GBPJPY_H1 row `2026.04.30 21:00`
(boundary bar `2026-05-04 23:00`): CONTROL exit **212.652** equals the boundary
bar's first tick `23:00:01 → 212.653` (±1 pip); treatment exit **212.748**
equals the following boundary tick `2026-05-05 00:01:01 → 212.748` exactly.
EURUSD_M15 row `2026.04.28 18:45` (boundary bar `2026-04-29 07:15`): CONTROL
exit **1.17064** = tick `07:15:01 → 1.17064` exactly; treatment exit **1.17056**
= tick `07:30:01 → 1.17056` exactly (the closed bar's final close).

This is **not** build nondeterminism, **not** shared-state contamination, and
**not** a telemetry artifact. The divergences are deterministic and
reproducible (identical rows across tiers; integrity reruns byte-identical).

---

## 2. Scope and Constraints

**Investigating.** Why activating Gate 3b changes settlement/exit results for a
small number of otherwise-admitted rows. Deliverable: this 11-section report
plus read-only evidence scripts under `Temp/`.

**Authorized methods only.** Source review, telemetry CSV diffing, and
reverse-engineering of the read-only tester `.tst` cache. Everything here was
computed from existing frozen artifacts; nothing was regenerated.

**Explicitly not done.** No production code, B8, or frozen-protocol changes. No
Strategy Tester runs. No statistics, effect estimates, or verdicts. The Sprint
22 hypothesis remains **inadmissible** pending independent review (§11).

**Evidence files read.**
- `Portfolio/SymbolContext.mqh` — decision path (`:860–979`), `SettleRow`
  (`:1333–1420`), `SettleDue` (`:1422–1455`).
- `Telemetry/ForwardOutcomeSimulator.mqh` — horizon exit (`:98–177`).
- `Telemetry/TelemetryTypes.mqh` — schema v5 gate columns.
- Tester caches (read-only): `Tester/cache/SuperCents_X.{GBPJPY.H1,
  EURUSD.M15, EURUSD.H1}.20260101_20260630.4.BC49990DA82BB15EE6C70B5A955C1ACF.tst`.
- Telemetry artifacts: `Tools/ED01/artifacts/{symbol}/{CONTROL,
  CONTROL_RLHYP01_*}` `telemetry_v4_*` / `telemetry_v5_*` CSVs.
- Supporting scripts in `Temp/` (see §6, §7).

---

## 3. Background and Terminology

- **Gate 3b (swing-significance admission gate).** Sprint 22 treatment
  mechanism. A per-bar gate that admits only entry candidates whose swing
  amplitude ≥ k×ATR(14) at the chosen tier (k ∈ {1.0, 1.5, 2.0}). Recorded in
  schema-v5 columns `swingQualifyingId`, `swingAmplitude`, `gateDecision`
  (`TelemetryTypes.mqh:45–53`). `GATE-OUT` means no decision row is created at
  that bar.
- **Settlement.** A queued decision row is settled by `CSymbolContext::
  SettleDue()` (`SymbolContext.mqh:1422`), which settles any pending row whose
  entry bar is ≥ 50 bars ago (`iBarShift(..., false) >=
  TELEMETRY_SETTLE_MAX_HOLD_BARS`, `:1432–1433`; constant = 50 per
  `docs/CalibrationGuide.md:115`).
- **`SettleRow()`.** Copies an as-series window
  `[warmStart, stopTime]` (`SymbolContext.mqh:1350–1379`), locates the entry bar
  **by time** (`:1392–1400`), and runs `CForwardOutcomeSimulator::Simulate`
  (`:1406–1409`).
- **Horizon (boundary) exit.** If neither SL nor TP is touched within 50 bars,
  the simulator exits at the close of the 50th bar after entry
  (`ForwardOutcomeSimulator.mqh:170–176`): `out.exitPrice = close[minBar]`
  with `minBar = entryBarIndex − m_maxHoldBars` (`:100`, `m_maxHoldBars = 50`,
  `:56`), giving `barsHeld = 51` in all cases.
- **Diverging row.** A treatment-admitted row (`gateDecision = ADMIT`) whose
  CONTROL twin differs in at least one shared column outside
  `decisionId`, `schemaVersion`, and the three gate columns.
- **Boundary bar.** The 50th bar after the entry bar — the bar whose close the
  horizon exit reads.

---

## 4. Observations (the Anomaly)

### 4.1 Divergence counts by arm

Computed by `Temp/gate3b_completeness.py` from the frozen artifacts:

| Symbol / TF | Tier | admitted | GATE-OUT settlement bars | diverged | diverged without GATE-OUT settlement bar |
|---|---|---|---|---|---|
| EURUSD_H1  | K1P0 | 820  | 376  | 0 | 0 |
| EURUSD_H1  | K1P5 | 691  | 360  | 0 | 0 |
| EURUSD_H1  | K2P0 | 521  | 318  | 0 | 0 |
| GBPJPY_H1  | K1P0 | 840  | 389  | **1** | 0 |
| GBPJPY_H1  | K1P5 | 695  | 382  | **1** | 0 |
| GBPJPY_H1  | K2P0 | 512  | 329  | **1** | 0 |
| EURUSD_M15 | K1P0 | 3327 | 1559 | **17** | 0 |
| EURUSD_M15 | K1P5 | 2827 | 1568 | **17** | 0 |
| EURUSD_M15 | K2P0 | 2096 | 1389 | **21** | 0 |

**Completeness:** every diverging row has a GATE-OUT settlement bar in
treatment; **zero** diverging rows lack one, across all 9 arms. The converse
(GATE-OUT settlement bar without divergence) is common — such rows exited
before the boundary bar or had an SL/TP exit whose price is determined by
policy levels rather than the bar's close.

### 4.2 Which columns differ

For every diverging row the differing columns are a subset of
`exitPrice`, `rMultiple`, `outcome`, `exitReason`. Never differing:
`signalTime`, `direction`, `entryPrice`, `barsHeld` (always 51 in both arms),
`outcomeSource` (always 1 = simulated). The treatment side is settled, not
dropped — it produces a real simulated outcome with a different price.

### 4.3 Representative rows

| symbol/tier | signalTime | entryPrice | CONTROL exit | TREAT exit | Δ | CONTROL exitReason | TREAT exitReason |
|---|---|---|---|---|---|---|---|
| GBPJPY_H1 K1P0 | 2026.04.30 21:00 | 212.520 | 212.652 | 212.748 | +0.096 | 4 (HORIZON) | 4 |
| EURUSD_M15 K1P0 | 2026.04.28 18:45 | 1.17105 | 1.17064 | 1.17056 | −0.00008 | 4 (HORIZON) | 4 |
| EURUSD_M15 K1P0 | 2026.04.28 18:30 | 1.17106 | 1.17050 | 1.17064 | +0.00014 | 4 (HORIZON) | 4 |
| EURUSD_M15 K1P0 | 2026.04.28 19:45 | 1.17089 | 1.17026 | 1.17011643 | — | 4 (HORIZON) | 2 (SL, −1.0R) |
| EURUSD_M15 K1P0 | 2026.04.30 19:00 | 1.17276 | 1.17264 | 1.17270 | — | 4 (HORIZON) | 4 |

The last two rows illustrate secondary consequences: when the deferred scan
reveals an intrabar SL touch the exit reason flips to SL; when the price shift
crosses the ±0.05R breakeven band the outcome classification flips
(LOSS ↔ BREAKEVEN).

---

## 5. Root-Cause Chain (Mechanism)

### 5.1 Where settlement lives in the decision path

In `CSymbolContext`'s tick handler, a new entry candidate is evaluated per bar.
After the swing gate runs (`SymbolContext.mqh:860–861`):

- **GATE-OUT** branch (`:862–867`): logs only. **No decision row, no
  `SettleDue()`, no `QueueForSettlement()`.**
- **ADMIT** branch (`:868+`): builds the telemetry row (`:938–962`), stamps the
  gate columns (`:974`), then — critically —
  ```mql5
  975   SettleDue();
  976   QueueForSettlement(row, newDecision.candidateId, ...);
  ```

`SettleDue()` (the **only** call site; confirmed by search) therefore runs
**only on bars that produce an admitted decision**. This is the coupling.

### 5.2 CONTROL settlement at the boundary bar

A row queued at its entry bar becomes due when the entry bar is ≥ 50 bars ago
(`:1432–1433`). On the first tick of the **50th bar after entry** the CONTROL
arm (gate off) creates a decision at that bar, so `SettleDue()` runs.
`SettleRow` copies the window, finds the entry bar **by time** at
`entryBarIndex = 50` (`:1392–1400`), and the simulator scans
`entryBarIndex−1 … minBar = entryBarIndex−50 = 0`
(`ForwardOutcomeSimulator.mqh:99–106`). If no SL/TP is touched, the horizon
exit reads `close[0]` — the close of the **forming** boundary bar, whose
open = high = low = close = the **first-tick price** at settlement.

### 5.3 Treatment deferral and re-read of the closed bar

In treatment, when the boundary bar is **GATE-OUT**, no decision is created and
`SettleDue()` **does not run** at that tick. The row stays pending. It settles
at the first later bar that produces an admitted decision (when `SettleDue()`
next runs). At that later time the window still locates the entry bar by time,
but now `entryBarIndex > 50`, so `minBar = entryBarIndex − 50` points to the
**same physical boundary bar** — now **closed**. The horizon exit reads
`close[minBar]` = the boundary bar's **final close** (last-tick OHLC).

### 5.4 Why only exit-side fields change

- **`entryPrice`** = `open[entryBarIndex]` (`:83`); the entry bar is fully
  formed in both arms → identical.
- **`barsHeld`** = `(entryBarIndex − minBar) + 1 = 51` by construction
  (`:173`) → identical even when settlement is deferred.
- **`exitReason`** = HORIZON in both arms **unless** the deferred scan now
  reaches an SL/TP that the extra bars (or the closed boundary bar's intrabar
  high/low) reveal — then it flips to SL/TP (observed once, §4.3 row 4).
- **`exitPrice`** = `close[minBar]`: first-tick price (CONTROL) vs final close
  (treatment) → differs by the boundary bar's move.
- **`rMultiple`/`outcome`** follow from the exit price through the identical
  policy `riskDistance` (same ATR(14) history — the warm-start window is
  unchanged) — verified arithmetically on the proof rows (§7.4).

### 5.5 Why divergences concentrate at session-end entries

The diverging condition requires the CONTROL exit to be a **50-bar boundary
exit**. A 50-bar horizon from a session-end entry (e.g., 18:00–23:00 on M15,
21:00 on GBPJPY_H1) lands at the next session's open, where the boundary bar
moves; entries earlier in the day exit mid-session where SL/TP is usually hit
first. `Temp/boundary_by_hour.py` (§6.2) confirms the concentration; the
boundary exit is the **necessary trigger**.

---

## 6. Empirical Evidence (supporting scripts)

All scripts are read-only; outputs reproduced on 2026-08-12.

### 6.1 `Temp/gate3b_completeness.py`

- 9/9 arms: **0** diverging rows without a GATE-OUT settlement bar.
- Exact admitted / GATE-OUT-settle / diverged counts as in §4.1.

### 6.2 `Temp/boundary_by_hour.py` — boundary-exit rate by entry hour

CONTROL rows with `barsHeld = 51` (boundary/horizon exit) by entry hour:

- **EURUSD_M15:** 0 boundary exits for hours 00–15, then rising through the
  session end: 16:00 → 0.77%, 17:00 → 2.31%, **18:00 → 6.92%,
  19:00 → 10.77%, 20:00 → 10.38%**, 21:00 → 1.92%, 22:00 → 1.54%,
  23:00 → 2.69%. (Hours 01:00 and 03:00 each have 1 boundary exit.)
- **GBPJPY_H1:** exactly **one** boundary exit in the whole CONTROL file, at
  entry hour 21:00 (1.54%) — this is the single diverging row per tier.
- **EURUSD_H1:** **zero** boundary exits at any hour → zero divergences
  despite 376/360/318 GATE-OUT settlements.

### 6.3 `Temp/gateout_by_hour.py` — gate-out rate is uniform by hour

For EURUSD_M15 K1P0 the gate-out rate of CONTROL decision bars ranges only
38.85%–56.15% across hours (max spread 17 p.p., no session-end spike), so the
17:00–23:00 concentration of divergences cannot come from the gate's hourly
behavior — it comes from the boundary-exit geometry of §5.5.

### 6.4 Determinism

- The identical diverging row appears at each tier for GBPJPY_H1 and the
  M15 divergence set is largely shared across tiers (17/17/21), with the same
  CONTROL exit prices — the mechanism is row-deterministic, not random.
- Integrity reruns (`CONTROL_RLHYP01_INTEGRITY`, ungated new code) are
  byte-identical to CONTROL across all 75 columns per the frozen §11.3a gate —
  ruling out build nondeterminism.

---

## 7. Price-Level Proof from the Tester `.tst` Cache

The strongest evidence is a direct reconstruction of the prices the two arms
actually read, from the read-only tester cache that all 6-month runs share
(`Tester/cache/*.20260101_20260630.4.BC49990DA82BB15EE6C70B5A955C1ACF.tst`).
The same hash for all three symbols and the absence of any other 6-month cache
show the CONTROL and treatment runs used the same tick source.

### 7.1 Cache record layout (reverse-engineered, read-only)

The cache is a sequence of 256-byte records beginning at file offset 4376.
For each record:

| offset | size | meaning |
|---|---|---|
| 0  | 8 | unix timestamp (UTC; bar-boundary synthetic ticks stamped at `barTime + 1 s`) |
| 64 | 8 | double — 0.0 on boundary records |
| 72 | 8 | double — **price at this record** |
| 80 | 8 | double — previous record's price (carry-over / history field) |
| 96 | 8 | u64/double — session group id |

The cache is a **sparse subsample** of the tick stream (≈10–70 records per
trading day), so not every boundary bar's first tick is stored. All stored
boundary ticks that correspond to a diverging row are reproduced below.

### 7.2 Proof row A — GBPJPY_H1, `signalTime 2026.04.30 21:00` (all 3 tiers)

Boundary bar (50th H1 bar after entry): **2026-05-04 23:00** (Monday).

| source | value |
|---|---|
| CONTROL `exitPrice` | **212.65200** |
| cache tick `2026-05-04 23:00:01` (first tick of boundary bar) | **212.65300** → matches CONTROL to 1 pip |
| treatment `exitPrice` | **212.74800** |
| cache tick `2026-05-05 00:01:01` (following boundary tick = close of 23:00 bar) | **212.74800** → matches treatment **exactly** |

The cache's history field also preserves both values in one snapshot:
`2026-05-05 12:00:11` carries `p80 = 212.65300` (first tick) and
`p80 = 212.74800` (close) side by side. The 1-pip CONTROL delta is
consistent with the tick's bid/ask field rather than the close series; the
EURUSD proofs below are exact to all stored digits.

### 7.3 Proof rows B — EURUSD_M15, entries 2026-04-28 18:30 / 18:45 (K1P0; 18:30 also K1P5)

Boundary bars land at **2026-04-29 07:00** and **07:15** respectively. Cache
ticks on 2026-04-29:

- `07:15:01 → 1.17064`, `07:30:01 → 1.17056`, plus a later snapshot at
  `16:19:58` carrying `p80 = 1.17064` and `p80 = 1.17056`.

| row | boundary bar | CONTROL exit | cache first tick | treatment exit | cache next tick |
|---|---|---|---|---|---|
| 18:45 | 07:15 | **1.17064000** | `07:15:01 = 1.17064` **exact** | **1.17056000** | `07:30:01 = 1.17056` **exact** |
| 18:30 | 07:00 | 1.17050000 | (first tick not stored) | **1.17064000** | `07:15:01 = 1.17064` **exact** (= close of 07:00 bar) |

Row 18:45 is the complete double proof: CONTROL read the forming bar's
first-tick price; treatment read the closed bar's final close — both recovered
independently from the cache.

### 7.4 Arithmetical consistency

The risk distance implied by CONTROL is reused by treatment (same policy /
ATR history), confirming only `exitPrice` changed:

- GBPJPY row: `riskDistance = (212.652 − 212.520) / 0.14898420 = 0.8860`;
  treatment `(212.748 − 212.520) / 0.8860 = 0.2573` = stored `rMultiple` ✓
- M15 18:45 row: `riskDistance = (1.17064 − 1.17105) / −0.48685327 =
  0.000842`; treatment `(1.17056 − 1.17105) / 0.000842 = −0.5818` = stored
  `rMultiple` ✓

### 7.5 Systematic sweep

`Temp/tst_price_proof.py` runs the same match over **all 58 diverging rows**
(settlement bar from the CONTROL bar list; first tick = earliest stored tick
within 90 s of the bar start; close = first stored tick within 300 s after the
next bar start). Results: every boundary bar whose first tick is stored matches
the CONTROL exit (EURUSD exact; GBPJPY within 1 pip); the treatment exit
matches the stored following-boundary tick exactly wherever it exists —
EURUSD_M15 2026-04-28 18:45 and 18:30 (K1P0), 18:30 (K1P5), 2026-05-06 16:45
(all three tiers), and the GBPJPY row (all three tiers). Where the cache is too
sparse to store the boundary ticks, no match is claimed (reported as `no`).

**Caveat.** The cache does not store every tick; the treatment close for most
M15 rows cannot be independently recovered. Every recoverable datapoint agrees
with the mechanism; none contradicts it.

---

## 8. Classification under Permitted Categories

The divergence classifies as **deterministic gate → settlement coupling**
(decision-time scheduling changing the settlement bar's read state), expressed
through **session-boundary settlement** geometry.

Mechanism restated in one sentence: *the gate, by skipping the decision row on
a GATE-OUT bar, also skips `SettleDue()` on that bar, which defers the queued
row's settlement until a later admitted bar; the re-run then evaluates the
same 50-bar forward window with the boundary bar closed (final OHLC) instead
of forming (first-tick OHLC), changing the horizon-exit price.*

- **Not** build nondeterminism — deterministic, reproducible across tiers and
  integrity reruns.
- **Not** shared-state contamination — only exit-side fields of the affected
  row change; no cross-row bleed; entry-side fields byte-identical.
- **Not** a telemetry artifact — treatment prices are independently reproduced
  from the tester cache.
- **Not** gate-out-rate-by-hour — gate-out is uniform by hour (§6.3).

---

## 9. Alternative Hypotheses Ruled Out

| Hypothesis | Ruled out by |
|---|---|
| Build / run nondeterminism | Integrity reruns (ungated, new code) are byte-identical to CONTROL (75/75 columns, frozen §11.3a). The same diverging rows appear across tiers with identical CONTROL exits. |
| Gate-out rate varies by hour (gate behaves differently at session end) | `gateout_by_hour.py`: gate-out rate is flat across hours (38.85%–56.15%, no session-end spike). |
| Telemetry serialization / format bug | The treatment exit prices are reproduced byte-for-byte from the tester `.tst` cache; the diffs are real price differences, not encoding noise. |
| Shared-state contamination / row bleed | Only exit-side columns of the affected rows change. Entry-side columns (`entryPrice`, `direction`, `signalTime`, `barsHeld`, `outcomeSource`) are byte-identical; no cross-row effect. |
| Boundary exits alone explain it (no gate needed) | EURUSD_H1 has **zero** boundary exits but hundreds of GATE-OUT settlements — and zero divergences. The GATE-OUT settlement bar and the boundary exit are *jointly* necessary. |
| CONTROL settling bar ≠ GATE-OUT (wrong bar identification) | `gate3b_completeness.py`: 0/58 diverging rows lack a GATE-OUT settlement bar; the settlement bar is taken from the CONTROL bar list exactly as `SettleDue` would compute it. |

---

## 10. Impact Assessment

- **Scope of impact.** Exactly 58 rows (0.47% of 12,329 admitted rows across
  the 9 arms) have changed exit-side outcome fields. All other admitted rows
  are byte-identical to CONTROL in every shared column, so the gate's
  admission identity and all entry-side statistics are unaffected.
- **What the divergence is not.** It is not a failure of the gate's admission
  decision; it is a settlement-timing consequence of the gate skipping
  `SettleDue()` on GATE-OUT bars. It does not change which rows are admitted
  or which bars form decisions.
- **Effect on any future analysis.** If per-opportunity expectancy were ever
  computed on these arms, the 58 rows would contribute their treatment-side
  exit price instead of the CONTROL price. This report makes **no** claim
  about the sign, size, or significance of that effect — that is an analysis
  decision outside this investigation's mandate.
- **Protocol posture.** Sprint 22 remains **inadmissible** (no statistics, no
  verdicts produced here). No production code, B8 behavior, or frozen protocol
  text was changed. The frozen §11 gates that *fail* under this divergence
  (admission-only invariance, §11.3b) are the reason the run set is blocked;
  this report documents the cause so a remediation decision can be made
  separately.

---

## 11. Independent Review and Next Steps

### 11.1 Independent adversarial review

Per the investigation plan, the initial investigation is complete; an
independent reviewer (Claude) must now re-derive the findings **from the raw
evidence only**, adversarially:

1. Recompute the diverging-row sets from the CSVs (assert 0 / 1 / 17 / 17 / 21
   and the completeness property).
2. Re-derive each diverging row's boundary bar from the CONTROL bar list.
3. Independently decode the `.tst` records (offset 4376, 256-byte stride,
   time @0, price @72) and re-verify §7.2/§7.3 matches, including the
   `212.748` close and `1.17064/1.17056` pair.
4. Re-verify the `SettleDue()` call-site claim (`SymbolContext.mqh:975`, sole
   call site) and the `minBar`/`barsHeld` algebra
   (`ForwardOutcomeSimulator.mqh:100, 170–176`).
5. Check for any diverging row the mechanism does *not* explain (exitReason
   flips, breakeven flips are sub-cases, not counter-examples).

Evidence available to the reviewer: this report, `Temp/*.py` scripts (all
read-only), `Tools/ED01/artifacts/**`, the three `.tst` caches, and the source
files listed in §2.

### 11.2 Known limitations (disclosed)

- The `.tst` cache is a sparse subsample; most boundary-bar first ticks are
  not stored, so the price-level proof is conclusive on the subset where the
  cache has data (all agree) rather than on all 58 rows.
- The GBPJPY CONTROL match is exact to 1 pip (212.652 vs 212.653) — consistent
  with the cache's bid/ask field vs the close series; the EURUSD matches are
  exact to all stored digits.
- The treatment deferral's exact settlement bar (first later ADMIT bar) is
  inferred from the mechanism and the `exitReason/barsHeld` invariants; it was
  not logged independently.

### 11.3 Next steps (stop for human review)

1. **Stop.** No fixes, no commits, no Strategy Tester re-runs, no protocol or
   production changes.
2. Human review of this report and the independent review results.
3. Any remediation (e.g., calling `SettleDue()` outside the gate path, or
   re-defining settlement eligibility) is a **separate decision** requiring its
   own protocol discipline — explicitly out of scope here.




