# AVP 19.2 — CHOCH / MSS (Market Structure Shift): Deep Research & Verification

Methodology: **AVP v1.0** (frozen — [00]). Sprint 18 docs cited,
never re-derived. Dataset: frozen Sprint 17 (18,686 rows, fingerprint
`2e74bbae…`). Code facts: `file:line`. No production code modified.

---

## Algorithm Passport

| Field | Value |
|---|---|
| Algorithm | CHOCH / MSS — Change of Character, Market Structure Shift |
| Version Reviewed | v3.0-research-baseline (CCHOCHDetector + ProtectedPointManager + Confluence rule) |
| Method applied | AVP v1.0 |
| Sprint | AVP 19.2 |
| Research sources reviewed | 24 (literature/academic + practitioner) |
| Industry implementations compared | 7 TradingView + 6 MT5 + 6 Python |
| Code files reviewed | 14 (Structure, Visualization, Confluence, Portfolio, Telemetry) |
| Dataset rows reviewed | 18,686 (decided+signal 17,073) |
| CHOCH-family rows found | **342 (2.0% of signals)** |
| Verification Score | **74/100** |
| Overall Recommendation | **Improve** (fix reset-stall + rule asymmetry; add MSS delta; no redesign) |

A reader must understand the outcome from this page alone.

---

## P1 — Deep Research (~80% of program effort)

### 1.1 Definition and why CHOCH exists

**Bottom line across schools:** a *Change of Character (CHoCH)* is the
**first counter-trend break of a swing extreme** inside an established
trend — a **warning** that the prevailing trend *may* be reversing. A
*Market Structure Shift (MSS)* is the **confirmed, displacement-driven
version** of the same event. Schools disagree on how much must be
proven before any entry is justified (see 1.4).

- **ICT** — CHoCH is a high-timeframe regime warning, typically the
  first break of an opposing (internal) swing [LT-SmcX2025,
  LT-WritFinance2024]. MSS is a **confirmed** CHoCH that (a) follows a
  **liquidity sweep** of a clean high/low or EQH/EQL zone, and
  (b) breaks the most recent opposing swing with **displacement**
  (long real body, short wicks, optionally leaving an FVG); price then
  drifts toward the next liquidity pool [LT-Huddleston2022,
  LT-Killzone2026, LT-Backtrex2026]. "Every MSS involves a CHoCH; not
  every CHoCH is an MSS — displacement is the discriminator"
  [LT-SmartGoods2026b].
- **SMC (Werlein / LuxAlgo stream)** — vocabulary is **BOS
  (continuation) vs CHoCH (reversal)** with close-beyond confirmation
  and "wick-only = liquidity sweep" [LT-QuantumAlgo2026]; **"MSS" is an
  ICT import** retrofitted into SMC, not core Werlein vocabulary
  [LT-ChartLens, LT-LiteFinance2025, LT-StrikeMoney].
- **Brooks** — no such term; the operating family is **failed
  breakout / breakout-pullback / second-entry reversal** [LT-Brooks].
  A CHoCH read as a confirmed entry is approximately Brooks's
  **first reversal attempt (H2/L2 — low confidence)**; a sweep-then-
  continuation is exactly his **failed breakout**.
- **Wyckoff** — the original "change of character" is the behavioural
  shift inside accumulation/distribution (SOW = Sign of Weakness,
  effort × result absorption). Springs/upthrusts = failed-break
  reversals at support/resistance [LT-WyckoffAnalytics,
  LT-SpringUpThrust]. **Volume is mandatory** — the opposite of the
  price-only ICT/SMC reading.
- **Academic / microstructure** — prior extremes act as SR levels
  that produce trend interruptions and reversals [AcCo-Osler2000,
  AcCo-Chung2021]; stop-loss orders cluster *just beyond* round levels,
  giving the mechanism for **both** a fake-out and a post-break
  continuation jump [AcCo-Osler2003, AcCo-Osler2002]. Structural-change
  (change-point) detection is the formal cousin but no paper
  operationalises "sweep + displacement".
- **Institutional quant** — no shop draws "change of character"; the
  residual core (broken level + confirmation + expected continuation)
  maps to **breakout systems + S/R microstructure**. Retail overlays
  (FVG, liquidity narrative) are untested claims.

### 1.2 Historical evolution

ICT vocabularised CHoCH/MSS across the 2016-2022 Mentorships and
consolidated "MSS = CHoCH + sweep + displacement" in the 2022 course
[LT-Huddleston2022]. SMC tooling (LuxAlgo, mickes) shipped structure
engines with a BOS/CHoCH taxonomy from ~2020 [TV-1, TV-3]. Wyckoff's
"change of character" (1930s) is the genealogical root. Academic SR
literature (2000s, Osler) is contemporaneous but independent.

### 1.3 Schools — per-school matrix

| Dimension | ICT | SMC | Brooks | Wyckoff | Academic | Institutional |
|---|---|---|---|---|---|---|
| Definition | CHoCH = 1st CT break (warning); MSS = CHoCH + sweep + displacement | BOS = continuation; CHoCH = reversal (close-beyond) | failed breakout / H2-L2 second entry | SOW / spring / UT inside accumulation-distribution | SR-level break + stop-cluster reversal | breakout systems (Donchian/Turtle) |
| Why it exists | regime alert on HTF; liquidity targeting on LTF | reversal vs continuation label | trade after pause | institutional accumulation view | statistically-observed level behaviour | trend following |
| Strengths | explicit taxonomy; strict CT confirmation | simple, operational | empirical base | volume-integrated | peer-reviewed level evidence | deployed, tested |
| Weaknesses | sweep/displacement narrative untested; "1:5 ratio" folklore | CHoCH alone = high failure | no displacement/sweep apparatus | range-heavy; needs consolidation first | never operationalises "shift" | no narrative filter |
| Failure cases | range flips; news wick-throughs | range CHoCHs; pullback re-breaks | breakout fails without follow-through | spring without volume = trap | level decays with retests | whipsaw in ranges |
| Volume | no | optional (ATAS delta) | no | **mandatory** | trade volume only | optional |
| Wick vs close | close; wick = sweep | close; wick = grab | close-based (signal bars) | close + volume | close (data-driven) | close |
| BOS vs CHoCH | opposite directions of same break | same | n/a | n/a | n/a | n/a |

### 1.4 What schools disagree on (explicit)

1. **CHoCH vs MSS**: distinct-with-displacement (ICT) vs loose synonym
   (much SMC) vs even inverted in some 2026 glossaries ("MSS short-
   term, CHoCH long-term") — the taxonomy is unstable.
2. **Wick vs close break**: strict SMC/ICT close-beyond only; wick =
   sweep not break. TradingView engines offer close/wick/buffer modes —
   no consensus intraday (close on H4, wick on M15) [LT-ChartMini].
3. **Displacement**: required for MSS, optional for CHoCH
   [LT-Killzone2026]; several SMC works treat any counter-trend
   close-break as CHoCH with no displacement requirement.
4. **Confirmed close vs single candle**: some need the CHoCH candle
   itself to close beyond; others allow wick-then-logic
   [LT-QuantumAlgo2026 vs LT-TradeOlogy].
5. **Retest after shift**: ICT 2022 enters at the FVG/OB, not the
   candle [LT-Huddleston2022]; TradeOlogy notes retest-and-hold lifts
   hit rates; ATAS demands delta surge.
6. **MTF hierarchy**: ICT HTF-CHoCH/regime vs LTF-MSS entry; the
   "1:5 ratio" is folklore — actual ladders are 3-5x per rung
   (D→H4=4, H4→H1=4, H1→M15=4, M15→M5=3) [LT-TFfinder2025].
7. **Volume**: Wyckoff/ATAS mandatory; mainstream ICT price-only.

### 1.5 Conflicting definitions (those that matter for code)

1. **Internal (small) vs structural (large) CT break** — TV-1/TV-2
   engines differ exactly here (internal layer vs swing layer). Our
   code breaks only **locked structural pivots**, never internal
   swings — a conservative reading.
2. **CHoCH vs MSS** — our event is an ICT **CHoCH-warning** (close-only,
   no displacement/sweep), **not** an MSS. The engine's only signal
   rule names itself "CHOCH_OB_REVERSAL" — the label is consistent with
   the detector's semantics (see P4a).
3. **Once-per-PP vs re-break re-entry** — ICT CHoCH re-fires when the
   same level is re-tested; our engine locks each protected point once
   (duplicate scan). Design choice, defensible, documented (P4a).
4. **Wick-then-close** — wick beyond with close pulled back = sweep in
   ICT vocab; our close-only rule discards it (never over-fires).

### 1.6 Which definition has the strongest evidence?

The **close-beyond-an-honest-locked-swing + counter-trend + optional
retest/displacement** core is the only part with independent
peer-reviewed support: stop-cluster placement just beyond SR levels
explains both fake-outs and post-break acceleration [AcCo-Osler2000,
AcCo-Osler2003], and SR-level bounce predictability is statistically
significant, decaying with prior bounces [AcCo-Chung2021]. The
displacement/sweep/FVG overlay is practitioner claim without peer
validation — a hypothesis for experimentation, not a requirement. Our
detector's close-beyond-locked-pivot core is therefore the
**empirically defensible subset** of CHoCH.

### 1.7 Open research problems

1. No canonical swing ground truth — all MSS results are a byproduct
   of the fractal look-back choice.
2. Close-vs-wick break false-positive frequencies on FX are
   effectively unpublished.
3. Whether displacement (body/range ratio, FVG width) predicts
   continuation — no quantitative study exists.
4. The "1:5 HTF/LTF ratio" is an unverified claim.
5. MSS entry rules have not been tested under White's Reality Check /
   SPA-style multiple-testing controls.
6. "Sweep precedes shift" against the microstructure null (stop
   clusters) is untested.
7. Repaint auditing of the P2 ecosystem is inconsistent (many
   commercial tools admit repaint).

---

## P1.5 — Formal Algorithm Specification (written before code)

```
Input            : active protected point (locked swing of opposite polarity to trend);
                   bars (close[], time[]); current Trend (BULLISH/BEARISH/UNKNOWN)
Output           : CHoCH event (bullish / bearish), exactly once per protected point
Preconditions    : initialized; trend != UNKNOWN; active PP of opposite polarity exists;
                   current closed bar strictly later than PP activation bar;
                   new bar not yet processed; close strictly beyond PP price
Postconditions   : event appended (id = seq, protectedPointID, bullish, time = break
                   bar time, breakPrice = close of break bar, barIndex = 1);
                   PP not consumed by emission (reusable until trend flip);
                   stats + PP telemetry updated; lastProcessedBar advanced
State            : event sink is append-only; detector holds no structural state
                   beyond m_lastProcessedBar, PP-id trackers and counters
Invariants       : never repaint (only close[1] used); event list chronological;
                   ids monotonic; one event per PP ever; events immutable
Failure          : TREND_UNKNOWN (no event); no active PP; guard time (activation bar);
                   price not broken (pullback); duplicate PP id; chart reset (see C2)
```

**Complexity analysis**

| Metric | Value |
|---|---|
| Time complexity | O(E) per closed bar (linear duplicate scan over event array, :270-282); O(1) otherwise |
| Memory complexity | O(E) events (256-chunk growth) |
| Streaming suitability | YES (bars only, no window) |
| Incremental update | YES (bar-1 oriented) |
| Repaint risk | NONE (close[1] is finalised) |
| Lookahead bias risk | NONE (bar[1] only; PP locked upstream) |

**State machine (conceptual)**

```
TrendState : UNKNOWN --(first BOS)--> UP/DOWN
PP Lifecycle: [last locked opposite-polarity pivot] --(trend flip)--> active
            --(close beyond)--> consumed by CHOCH event / OB mint
CH event   : trend set + PP active + bar strictly after activation
             + close beyond  ==>  emit CHOCH (bullish if trend==DOWN,
             bearish if trend==UP)  ==>  PP reusable until next flip

Note: CHoCH emits AFTER the trend has already flipped (flip is BOS-driven).
      CHoCH is therefore a post-hoc confirmation of the flip,
      not a flip trigger.
```

---

## P2 — Industry Implementation Survey

### 2.1 TradingView (7 compared)

- [TV-1] LuxAlgo SMC: swing + internal layers, CHoCH/BOS labels,
  close-based, state-memory; **confirmed swing use only — not real-time
  — repaint acknowledged in docs**; trend flip kills prior history.
- [TV-2] LuxAlgo Market Structure + Retest: adds a retest/break
  probability — a confirmation our CHoCH does not require.
- [TV-3] mickes Market Structure (open source): close-valued breaks,
  CHoCH resets all pivots, documented "false CHoCHs in range" artifact.
- [TV-4] TehThomas MSS: MSS = a close beyond the most recent opposing
  swing; **no displacement logic despite the MSS name**.
- [TV-5] FibAlgo ICT Market Structure: close-based real-time break;
  CHoCH on internal degree, MSS on swing degree; excessive signals <1M.
- [TV-6] Xcelerate Trade MSS/BOS/CHoCH: four break-validation modes
  (close / wick / buffer ticks / ±%); Williams-fractal pivots with
  per-TF lookback; explicit lag = pivot confirm window.
- [TV-7] SMC CHoCH Advanced (crossresearch): swing logic + KNN
  probability + volatility expansion — black-box "modern" variant.

### 2.2 MT5 open-source (6 compared)

- [MT5-1] SMC all-in-one (Hammad Dilber): BOS/CHoCH + OB + FVG +
  EQH/EQL, ATR thresholds — closed-compiled, **unauditable**.
- [MT5-2] Market Structure SMC (YeohJooYam): n-bar fractal swings,
  `InpBreakOnClose` flag (close vs wick), Quasimodo retracement on
  CHoCH, redraws all markings each bar — **repaint risk**.
- [MT5-3] VelmoPk SMC (open GitHub): structure engine + BOS/CHoCH,
  claims no-repaint, low adoption.
- [MT5-4] GeneralTradingSarl SMC: ships only .ex5 — blocked audit.
- [MT5-5] TradingBotMaker tutorial: the dominant MT5 pattern —
  configurable lookback, cache swings in an array, **"check CHoCH
  first, then BOS"** so reversal-invalidating signals do not fire as
  continuation; warns built-in ZigZag repaint.
- [MT5-6] mql5 forum consensus: fractals = "weak zigzag"; confirmed-
  swing delay is inherent; split confirmed vs internal layers to cut
  repaint.

### 2.3 Python backtesting (6 compared)

- [PY-1] smtlab/smartmoneyconcepts — canonical `bos_choch(close_break=bool)`,
  returns BOS/CHoCH with levels; the standard bar-only proxy.
- [PY-2] joshyattridge/smart-money-concepts — LuxAlgo port, same
  close_break toggle.
- [PY-3] smc-toolkit, [PY-4] smart-money-concept — BOS/CHoCH with
  swing and internal layers, body-break flag.
- [PY-5] marketcalls tutorial — full state machine (STRUCT_LOOK=10,
  USE_BODY_BREAK=True), FVG three-candle.
- [PY-6] jmlacasa/backtesting_finance — LuxAlgo-inspired OB/CHoCH on
  three timeframes with backtesting harness.
- **Consensus**: MSS is proxied as "close strictly beyond last swing
  extreme after pivot confirmation, with trend direction" — none
  implement the sweep/displacement/FVG narrative in generality.

### 2.4 Survey conclusions

Industry norms: close-break toggle; confirmed-swing (delayed, no
repaint) vs fractal (fast, repaint) trade-off; **check CHoCH before
BOS to prevent a reversal firing as continuation**; and most tools do
**not** enforce displacement despite "MSS" branding. Our conservative
locked-pivot close-break sits within industry practice; the "MSS"
confirmation layer is a differentiation gap, not a defect.

---

## P3 — SuperCents_X Implementation Review (facts only)

### 3.1 Pipeline position

`Swings → Pivots → Replacement → BOS → Trend → Protected → CHOCH →
OB → Confluence` (`Tests/SPRINT7_FORENSIC.md`). Call site:
`m_chochDetector.Update(...)` runs **after** trend and protected-point
updates (`Portfolio/SymbolContext.mqh:674`); timing logged (:676).

### 3.2 CCHOCHDetector (`Structure/CHOCHDetector.mqh`, 361 lines)

- Event struct `CHOCHEvent {int id; int protectedPointID; bool bullish;
  datetime time; double breakPrice; int barIndex;}`
  (`Utils/Types.mqh:58-66`).
- State: `m_chochEvents[]` (cap 256, chunked :96), `m_nextId=1` (:89),
  `m_lastProcessedBar=−1` (:90), PP-id activation trackers (:50-60).
- `Update(CTrendState*, CProtectedPointManager*, close[], time[],
  rates_total, pointSize)` (:118-218).
- Gate order (:122-146): not initialised → warn; null managers →
  return; **TREND_UNKNOWN → return** (:131-136); `rates_total < 2` →
  return; **dedup `rates_total <= m_lastProcessedBar` → return**,
  set `m_lastProcessedBar = rates_total` at end (:142-143, :217);
  last closed candle only (`close[1]`, `time[1]`) (:145-146).
- Trend BEARISH → bullish CHoCH: active **HIGH** PP (:185);
  guard-time reject `currentBarTime < pp.activationTime` (:199-203);
  not-broken reject `close <= pp.price` (:204-208); else
  `CheckProtectedLevel(..., TREND_BEARISH, ...)` (:209-213).
- Trend BULLISH → bearish CHoCH: active **LOW** PP (:152); mirror
  branches (:148-182).
- `CheckProtectedLevel` (:264-314): `bullish = (trend == BEARISH)`
  (:267); **duplicate lock**: linear scan, same `protectedPointID`
  → reject, "one CHoCH per protected point, ever" (:270-282); emit
  `id = m_nextId++`, `breakPrice = close`, `time` = break bar time,
  `barIndex = 1` (:291-302).
- PP telemetry `LogPPSample` on every accept and reject (:220-262).

### 3.3 ProtectedPointManager coupling (`Structure/ProtectedPointManager.mqh`)

- On trend change: both active PPs deactivated, **IDs reset to −1**,
  explicitly "preventing the CHOCH duplicate lock when the same pivot
  is re-selected after a flip-back" (:151-156).
- TREND_BULLISH → activates latest locked **LOW** pivot;
  TREND_BEARISH → latest locked **HIGH** pivot (:158-195), with
  `activationTime = time[0]`.

### 3.4 Downstream consumers

- **OB mint**: OrderBlockDetector creates an OB **only from a CHoCH**
  (`OrderBlockDetector.mqh:120-174`, `ob.chochID = choch.id`).
- **FVG**: FVG classification searches recent CHoCH within
  `FVG_CLASS_LOOKBACK_SECONDS = 3*900` (`FVGDetector.mqh:433-453`).
- **Confluence**: `RuleCHOCH_OB_Reversal` = **bullish CHoCH** *and*
  active **bearish OB** (`ConfluenceRules.mqh:437-456`); rule slot 6
  (`ConfluenceEngine.mqh:248`). **No bearish-CHoCH rule exists.**
- **Scoring**: `SCORE_STRUCTURAL_CHOCH = 20`
  (`ScoreCalculator.mqh:8,25,106`); StructureEvaluator adds a neutral
  structural bonus for recent CHOCH of either direction, window 10
  (`StructureEvaluator.mqh:32-48,68-69`).
- **Signal types**: `RULE_CHOCH_OB_REVERSAL`
  (`SignalTypes.mqh:41,66,71,157,165`); `hasCHOCH/chochId` set from the
  best rule (`ConfluenceEngine.mqh:318,328`).

### 3.5 Existing test artifacts

- **No unit test for CHOCHDetector logic.** Only
  `Tests/unit/TestTelemetry.mqh:65,194,249` (rule-7 name / hasCHOCH
  mapping) and `TestTelemetryHealth.mqh` (flag coverage) touch CHOCH.
- `Tests/CHOCH_Visual_Acceptance.set` — a visual acceptance run
  (934 events; "Detector bug fix validated, Guard 8032→0");
  `CHANGELOG.md:232-237` still marks CHOCHDetector
  **"⚠ Pending (0 events in test window)"** — synthetically validated
  only; no production/walk-forward validation.

---

## P3.5 — Algorithm Correctness Verification

### 3.5.1 Checklist vs P1.5 spec

| Item | Result | Basis |
|---|---|---|
| Trend gate correct | PASS | TREND_UNKNOWN returns (:131-136); consistent with "no CHOCH, no OB" ([18.3] §6) |
| Active-PP gate correct (polarity) | PASS | branches fetch active HIGH (bearish trend) / LOW (bullish trend) |
| Guard time (not activation bar) | PASS | `currentBarTime < activationTime` reject |
| Close-break only (no wick) | PASS | strict `close >` / `close <` PP price |
| Exactly-once per PP | PASS | duplicate linear scan (:270-282) |
| Never repaint / no lookahead | PASS | close[1] only |
| Chronological, id monotonic | PASS | append-only, sequential ids |
| Flip-back PP reuse | PASS | PP ids reset on trend change (:151-156) |
| **Chart-reset / backfill resilience** | **FAIL** | dedup gate stalls forever after `rates_total` shrink (C2) |
| **Unit-test coverage** | **FAIL** | no logic-level tests (C1) |
| **Bearish signal path exercised** | **WARN** | detector branch exists; no rule ever mints a bearish signal (C3) |

### 3.5.2 Findings

**C1 — No automated tests for CHOCHDetector logic (FAIL).** The
forensic guarantees (once-per-PP, monotonic ids, chronological,
no-repaint) rest on code reading only; no unit test exercises them.
Identical shape to BOS pilot C6 ([01] 3.5.C6).

**C2 — Chart-reset / cold-start stall (FAIL).** The dedup guard
`if(rates_total <= m_lastProcessedBar) return;` with
`m_lastProcessedBar = rates_total` at end (`CHOCHDetector.mqh:142-143,
217`) means: if `rates_total` **shrinks** (chart reset, symbol change,
history truncation), every subsequent `Update` returns early —
**permanent CHOCH stall**; no events, no OB mints, no CHOCH telemetry.
`Engine.mqh:184-190` re-invokes Update with the new `rates_total` but
nothing resets `m_lastProcessedBar`. Same defect family as BOS C3
(reset stall); remediation is shared (reset/re-init on shrink).

**C3 — Bearish CHoCH never signals (WARN/design).** The detector has
both branches (:148-215), but the only rule, `RuleCHOCH_OB_Reversal`,
accepts only **bullish** CHoCH (`ConfluenceRules.mqh:442`). Bearish
CHoCH contributes only to the structural score bonus
(`ScoreCalculator.mqh:25`, `StructureEvaluator.mqh:68-69`), never to a
signal. Frozen dataset: all 342 `hasCHOCH=TRUE` rows are `direction=1`
(BULLISH). The bearish signal path is **unexercised and therefore
unverified** — either a deliberate one-sided scope or an asymmetry to
fix; evidence cannot distinguish (P6.3).

**C4 — No MSS confirmation layer (semantic gap).** The detector
requires **no displacement, no liquidity sweep, no FVG** — a
legitimate ICT "CHoCH-warning" reading (P1.1), but the engine's only
signal is presented as a confirmed reversal. The telemetry/labels do
not distinguish CHoCH-warning from MSS; any "MSS" claim in product
language would overstate the algorithm. Label discipline needed (P4a).

**C5 — `hasCHOCH` flag is redundant.** The flag is TRUE iff the fired
rule is `RULE_CHOCH_OB_REVERSAL` (`ConfluenceEngine.mqh:318`), so it
adds no information beyond `ruleName == CHOCH_OB_REVERSAL`
(telemetry-design redundancy; remove or repurpose).

**C6 — Event time = last-closed-bar time, not first-crossing time.**
`time` = break bar, `barIndex = 1` (:291-302). Under normal cadence
this is correct; on cold start / backfill the first available bar may
produce a spurious immediate CHoCH (shared with BOS cold-start
misattribution [01] C2). No telemetry column holds "first-crossing
bar" — cannot be verified from the dataset.

### 3.5.3 Failure Catalog

| # | Failure | Definition | Literature | Industry handling | Our implementation | Sprint 17 evidence | Recommendation |
|---|---|---|---|---|---|---|---|
| CH-F1 | Equal highs/lows | CHoCH vs an EQ-tie extremum | LT: EQ = liquidity target, tie semantics unresolved | TV-6: EQ zones; most ignore | tie excluded by fractal `<=` (SwingDetector.mqh:210-213) | cannot measure (geometry not serialised) | equal-high experiment ([01] E9 family) |
| CH-F2 | Gap open | break by gap then close | Turtle: fine; Brooks: gap bar strong | close-based | close-only; gap-then-close qualifies at close | cannot measure | none (consistent) |
| CH-F3 | Low volume | thin-market CHoCH fakes | Brooks; ATAS delta | volume filter | no volume input | cannot measure (no volume column) | volume confirmation (low) |
| CH-F4 | News spike | break through PP on announcement, revert | Ederington-Lee: spike-then-revert | news gates | no news awareness ([18.12]) | h22-23 drain (P6.4) consistent | news gate M07 |
| CH-F5 | Range fake | CHoCH inside chop | Brooks: most range breaks fail | retest/acceptance filters | close-only; no retest requirement | cannot measure (no retest column) | retest telemetry ([01] E2) |
| CH-F6 | Double CHoCH | second same-side break of same PP | rarely discussed | some re-emit | blocked (once per PP) — PASS | consistent with design | none |
| CH-F7 | Cold-start misattribution | first-bar CHoCH on backfill | backtest warm-up practice | warm-up exclusion | barIndex=1, no first-crossing fix (C6) | cold-start rows present | reset/backfill fix (C2/E11) |
| CH-F8 | Chart reset | rates_total shrink mid-run | — | full reset | **stalls forever** (C2) | n/a | reset fix (C2/E11) |

---

## P4 — Visualization

### P4a — Logical Event Validation

**Question: should the CHOCH event fire at all?**

**Verdict: YES — 78/100.** A close of a closed bar beyond the latest
locked opposite-polarity PP, with trend established and a strict
bar-after-activation guard, is exactly the ICT **CHoCH-warning** / SMC
**close-beyond** definition (P1.6) — the empirically grounded subset.
It does **not** implement MSS checks (sweep, displacement, FVG), so
the event is correctly *named* "CHOCH" and the rule
"CHOCH_OB_REVERSAL" — but any product claim of "confirmed MSS" would
be an overstatement (C4). The once-per-PP lock matches the "no
duplicate CHoCH" forensic rule and prevents double-signal churn; the
cost is that a *second, stronger* re-break of the same PP after a
failed first attempt is never emitted — an accepted, documented
trade-off (deviation from some TV tools that re-emit, [TV-3]).

### P4b — Rendering

`Visualization/CHOCHRenderer.mqh` (381 lines):

- Incremental render via `m_lastRenderedCHOCHCount` (:79-91);
  per new event: `FreezePreviousActive → DrawCHOCH →
  FinalizeActiveLine` (:81-90).
- **Freeze/promote** (:108-170): previous active line frozen via
  `CMD_FREEZE` (STYLE_DASH, `COLOR_CHOCH_FROZEN`, freezeLockLabel);
  the line before it promoted to historical (`COLOR_CHOCH_HIST`);
  `CMD_FINALIZE` pins `time2 = endTime, price2 = breakPrice` — the
  right anchor is the break candle; the line never extends.
- **Deletion**: `MaxHistoricalCHOCH` cap, oldest deleted (:93-105).
- **Geometry** (:216-379): start anchor resolved from the protected
  point (`GetProtectedPointByID`), fallback to break values (:218-228);
  `endTime = max(e.time, ppTime + PeriodSeconds)` (:232); slope
  self-check logs "SLOPE MISMATCH" on direction contradiction
  (:234-247); `CMD_DRAW` OBJ_TREND with colors/labels, width 2,
  STYLE_SOLID (:316-334); mid-anchor text (:336-340); post-draw
  coordinate verification logs (:342-366).
- Colors: active amber `#FFB300`, frozen grey `#808080`, historical
  `#606060` (`ChartStyle.mqh:16,26,35`).
- **Spec-vs-code discrepancy**: `VisualSpecification_v2.1` and the QA
  checklist specify frozen `#996B00` / historical `#593E00`; the
  implementation uses grey `#808080` / `#606060`. Rendering semantics
  are correct; the palette drifted from spec (Sprint 20 fix).

**Verdict: 88/100 — faithful rendering of the logical event.** Start
at the PP (not the break bar) is a defensible "break of the last
protected level" visual; the renderer mirrors the detector's
semantics. Only the palette drift and the cosmetic one-shot freeze
flag need attention.

---

## P5 — Pipeline Validation + Data Contracts

### 5.1 Stage data contracts

```
Stage:      CCHOCHDetector
 Input:         bars (close,time), trend, active protected point
 Output:        CHoCH events (append-only, one per PP)
 Assumptions:   one CHoCH per PP pin; close-beyond of a locked
                opposite-polarity structural level
 Guarantees:    never repaint; monotonic id; immutable after emit
 Consumer:      OBDetector (OB mint), FVGDetector (classification),
                ConfluenceEngine (rule 6)

Stage:      CProtectedPointManager
 Input:      locked pivots, trend
 Output:     active PP (opposite polarity to new trend), activationTime
 Guarantees: deactivates + resets PP ids on flip-back (prevents
             duplicate-lock on re-selection)
 Consumer:   CHOCHDetector, OBDetector

Stage:      Confluence Engine — RuleCHOCH_OB_Reversal
 Input:      CHoCH events, active bearish OB
 Output:     RULE_CHOCH_OB_REVERSAL (bullish only)
 Guarantees: slot 6; folds into TradeCandidate
 Consumer:   EntrySetup / EntryValidator (18.9: admits none),
             Telemetry
```

### 5.2 Pipeline questions (explicit answers)

1. **Is stage ordering correct?** YES — CHoCH runs after BOS→Trend→
   Protected, so it can only fire against an established flipped trend
   with an active PP.
2. **Can CHoCH fire without trend?** NO — TREND_UNKNOWN gate.
3. **Can CHoCH exist without a PP?** NO — active-PP branch required.
4. **Can the signal exist without the CHoCH?** The signal *is* the
   CHoCH+OB conjunction; but StructureEvaluator/ScoreCalculator can
   add CHoCH-derived *score bonus* without a signal.
5. **Are state transitions consistent?** YES — PP-id reset on flip
   (:151-156) deliberately prevents duplicate-lock across flips;
   OB mints consume the same PP.
6. **What is redundant?** `hasCHOCH` flag ≡ `RULE_CHOCH_OB_REVERSAL`
   (C5); PP activation-rate trackers are logged but have no consumer
   beyond stats.
7. **What is missing?** reset/backfill re-init (C2); bearish CHoCH
   rule (C3); MSS confirmation layer (C4); unit tests (C1).
8. **Entry-path reality (18.9):** `ConfluenceValidator` admits only
   `LIQUIDITY_BOS` — "every CHOCH_OB row FAILS"
   (`[09_Entry.md:262]`). The 342 dataset rows are **rule-fire paper
   records, not executed trades**. P6 win rates are rule-fire
   outcomes — the same convention as the 18.x cells. The CHOCH signal
   is currently **unreachable in production entry**.

---

## P6 — Sprint 17 Evidence Review (measured only; frozen dataset)

Reuse of 18.x tables as-is; new measurements marked (new).

### 6.1 Family frequency and overall (new)

```
CHOCH_OB_REVERSAL rows : 342 of 17,073 decided+signal rows (2.0%)
CHOCH-family wr        : 0.3567   vs base wr 0.3321   (+2.5 pp)
CHOCH meanR            : +0.0505  median R −1.0000    (negative skew)
Mean bars held         : 8.9
```

Rare family (2.0%), wr above base but meanR ≈ 0 with median −1R:
a small, negatively skewed distribution whose mass lives in a few
cells (6.2).

### 6.2 By cell (new)

| Cell | n | wr | meanR |
|---|---|---|---|
| EURUSD M15 | 229 | 0.3100 | −0.077 |
| EURUSD H1 | 50 | 0.3400 | −0.030 |
| **GBPJPY H1** | **63** | **0.5397** | **+0.579** |

**Exact replication of the 18.11 cell** (n=63, wr 0.5397, meanR +0.579,
Kelly 0.299) — the frozen dataset reproduces the only Kelly-positive
portfolio cell precisely. Non-GBPJPY cells wash the family to
breakeven.

### 6.3 By direction (new)

**All 342 rows are BULLISH** (`direction=1`). Zero bearish signals.
The detector has both branches; the rule is bullish-only (C3).
Bearish CHoCH performance **cannot be measured from this dataset**.

### 6.4 By hour window (new)

| Window | n | wr | meanR |
|---|---|---|---|
| h00-07 | 108 | 0.3148 | −0.056 |
| h08-12 | 48 | **0.5417** | **+0.611** |
| h13-17 | 115 | 0.3826 | +0.105 |
| h18-21 | 53 | 0.2830 | −0.173 |
| h22-23 | 18 | **0.1667** | −0.500 |

London morning (h08-12) is a positive island; h22-23 is a drain —
the same late-night weakness measured in the BOS family ([01] P6),
consistent with [18.12] session/news findings.

### 6.5 By cell × hour (selected, new)

| Cell window | n | wr | meanR |
|---|---|---|---|
| GBPJPY H1 h00-03 | 6 | 0.833 | +1.500 |
| GBPJPY H1 h08-12 | 15 | **0.733** | **+1.154** |
| GBPJPY H1 h13-17 | 21 | 0.429 | +0.199 |
| EURUSD M15 h13-17 | 80 | 0.375 | +0.103 |
| EURUSD M15 h18-21 | 38 | 0.263 | −0.210 |
| EURUSD M15 h00-03 | 29 | 0.207 | −0.379 |

The GBPJPY H1 product-line midday complex carries the family; EURUSD
M15 h18-21 and h00-03 are negative islands.

### 6.6 By confidence state (new)

| conf | n | wr |
|---|---|---|
| 0.45 | 266 | 0.3496 |
| 0.50 | 76 | 0.3816 |

Only two confidence states (0.45/0.50) occupy the signal space;
ordering is monotonic (0.50 > 0.45), so no *in-family
anti-calibration* is visible at this granularity — but two states
cannot establish calibration. The severe anti-calibration measured in
the BOS family ([01] 6.4) is not reproduced here, only not ruled out.

### 6.7 Context co-occurrence (new)

- `hasCHOCH=TRUE` ⇒ `hasOrderBlock=TRUE` **always** (342/342) — rule
  shape requires the OB conjunction.
- `hasFVG=TRUE`, `hasLiquiditySweep=TRUE`, `hasBOS=TRUE` among CHoCH
  rows: **0 rows** — no FVG/sweep/BOS co-occurrence is ever captured.
- OB-without-CHOCH (all OB signals): wr 0.3410 vs OB+CHOCH 0.3567
  (+1.6 pp) — CHOCH adds a small increment over plain OB.
- **The dataset cannot evaluate "CHOCH + displacement" or
  "sweep-then-CHOCH" (MSS doctrine) at all** — those cells do not
  exist (C4, 6.8).

### 6.8 What the dataset cannot measure (explicit)

1. **Bearish CHoCH** — no rows exist (rule shape, C3).
2. **Displacement** — no body/range or volume column.
3. **Liquidity-sweep precondition** — sweep flag always 0 in CHoCH rows.
4. **FVG co-occurrence** — zero combined rows.
5. **Wick-vs-close semantics** — only close recorded.
6. **Realized PnL** — all CHOCH_OB rows fail the 18.9 validator;
   rows are paper rule-fires, not trades.

---

## P7 — Experiment Backlog (full cards)

| # | Hypothesis | Literature | Industry | SuperCents_X | Evidence | Expected benefit | Expected risks | Complexity | Overfitting risk | Falsification |
|---|---|---|---|---|---|---|---|---|---|---|
| E1 | **MSS delta**: require displacement (real body ≥ threshold or FVG) on the CHoCH bar to separate "confirmed shift" from "warning" | LT-Killzone2026, LT-InnerCircle2023 | TV-2, MT5-2, PY-5 | CHOCHDetector.mqh:204 (break-only) | cannot measure until telemetry (6.8.2) | labels precision; fewer, better CHoCH signals | window/parameter selection; shrinks n | med | med | **Falsified if:** displacement-filtered CHoCH rows show no wr/meanR lift over the base CHoCH set on the holdout, or n collapses below k=100 |
| E2 | **Bearish CHoCH + bullish OB** signal (mirror rule) | SMC close-beyond symmetry | TV-3, TV-4 | ConfluenceRules.mqh:442 (bullish-only) | 6.3 (0 rows) | directional coverage; tests the other branch | doubles family size; validator still blocks (18.9) | low | low | **Falsified if:** bearish CHoCH_OB rows have wr ≤ base (0.3321) or meanR ≤ 0 at k=100 on the frozen set |
| E3 | **Session gate**: hold h08-12, exclude h22-23 (and h18-21 for EURUSD M15) | [18.12] sessions/news | session filters | SessionValidator (inactive) | 6.4, 6.5 | removes the drain; lifts family meanR | hour-cells are small (n=18..48) | low | med | **Falsified if:** session-selected wr does not survive split-half (M06 gate) or family wr after gating ≤ 0.36 |
| E4 | **Monday alpha**: Mon wr 0.539 vs Wed/Thu 0.26 | [18.12] | — | — | 6.4-new | if real, a timing edge | small n; plausible week-boundary artifact | low | med | **Falsified if:** Monday gating fails split-half replication or wr gap closes on the holdout |
| E5 | **GBPJPY H1 h08-12 complex replication** via walk-forward | AcCo-Osler2003 (stop clusters) | PY-1 canonical proxy | signal path 3.4 | 6.2 exact 18.11 | the only replicated winner; priority cell | 15 rows in the strongest window — tiny | low | **high** | **Falsified if:** walk-forward (M02/M04) on GBPJPY H1 does not reproduce wr ≥ 0.50 with positive meanR |

**M-card routes:** E3 → M06 (session gates); CH-F4 → M07 (news);
E1 → M30 (displacement); E5 → M02/M04 (walk-forward replication).

---

## Proof Matrix ("Can we prove it?")

| Claim | Literature | Implementation | Telemetry | Unit tests | Conclusion |
|---|---|---|---|---|---|
| "CHoCH never repaints" | YES (principle) | YES (close[1] only) | NO | NO | Likely by design; not test-proven |
| "CHoCH is counter-trend" | YES | YES (:267) | YES | NO | Proven by implementation + evidence |
| "One CHoCH per PP" | Partial (schools re-fire) | YES (scan :270) | YES | NO | Proven by implementation; design trade-off |
| "CHoCH fires only after trend flip" | YES | YES (order, 3.1) | YES | YES (flags) | Proven |
| "Bearish CHoCH works" | n/a | YES (branch :148) | **NO — 0 rows** | NO | **Cannot currently prove — no data** |
| "No displacement required" | YES (CHoCH) / MSS needs it | YES (absent) | NO | NO | Proven for CHoCH; MSS unverified |
| "Reset is safe" | n/a | **FAIL** (C2) | YES | NO | **Disproven by code reading (C2)** |
| "Rendering = logical event" | n/a | YES (mirror semantics) | YES | NO | Proven by implementation |

---

## Traceability Matrix

| Experiment | Literature | Industry | Code | Evidence | Proof strength |
|---|---|---|---|---|---|
| E1 MSS delta | LT-Killzone2026, LT-InnerCircle2023 | TV-2, MT5-2, PY-5 | CHOCHDetector.mqh:204 | 6.8.2 | Weak (needs telemetry) |
| E2 bearish rule | SMC close-beyond symmetry | TV-3, TV-4 | ConfluenceRules.mqh:442 | 6.3 | Weak (no data) |
| E3 session gate | [18.12] | session filters | SessionValidator (inactive) | 6.4, 6.5 | Partial |
| E4 Monday alpha | [18.12] | — | — | 6.4-new | Weak (small n) |
| E5 GBP H1 replication | AcCo-Osler2003 | PY-1 | signal path 3.4 | 6.2 (exact 18.11) | Strong (frozen replication) |
| C2 reset fix | backtest warm-up practice | MT5-1 | CHOCHDetector.mqh:142-143 | — | Strong (defect) |

---

## Verification Scorecard

| Area | Score | Basis |
|---|---|---|
| Research alignment | 82/100 | close-beyond CHoCH-warning semantics implemented per strongest-evidence definition; MSS delta (sweep/displacement) absent and honestly documented |
| Algorithm correctness | 60/100 | gates sound; C2 reset-stall (real defect), C1 no tests, C3 bearish path unexercised, C6 cold-start misattribution |
| Visualization | 88/100 | faithful line semantics; PP-start anchor correct; palette drift vs spec (P4b) |
| Pipeline | 78/100 | ordering correct; PP flip-design clean; but signal unreachable in entry (18.9) and MSS layer missing (C4) |
| Evidence support | 76/100 | exact 18.11 replication; strong session structure; n=342 small, all-bullish, no displacement/FVG cells, meanR ≈ 0 |
| Maintainability | 62/100 | no tests, redundant hasCHOCH flag, one-sided rule, palette drift |
| **Overall** | **74/100** | verified with material gaps: one real defect (C2), one-sided rule (C3), no MSS confirmation (C4), no tests (C1) |

Banding: 74 ∈ [60-74] — "verified with significant gaps".

---

## Findings Summary — Research Confidence × Destination

Per §4.13 of the locked methodology. Confidence is in the
*conclusion*, not the trade. Each row carries its Outcome
Classification (Implementation Defect / Missing Feature /
Architectural Limitation / Measurement Gap / Research Hypothesis).

| Finding | Confidence | Classification | Destination |
|---|---|---|---|
| C2 — chart-reset dedup stall (m_lastProcessedBar monotonic gate) | **Very High** (deterministic code path) | Implementation Defect | Sprint 20 defect fix (shares E11 remediation family with BOS C3) |
| C1 — no unit tests for CHOCHDetector | High (test artifacts absent) | Measurement Gap | Sprint 20 test scaffold |
| C3 — bearish CHoCH never signals (bullish-only rule) | High (rule inspection + 342/342 bull rows) | **Missing Feature** | Sprint 20: add mirror rule (E2) or document as scope decision |
| C4 — no MSS confirmation layer (displacement/sweep/FVG) | High (P1 consensus + code) | **Architectural Limitation** | Sprint 20 label discipline; E1 experiment → M30 |
| C6 — cold-start misattribution (first-crossing unrecorded) | High (code path) | Implementation Defect | Sprint 20 (shared with BOS C2/E8) |
| C5 — hasCHOCH flag redundant with ruleName | High (telemetry inspection) | Implementation Defect | Sprint 20 cleanup |
| P6 — GBPJPY H1 is the only replicated winner (exact 18.11) | **Very High** (exact frozen replication) | Research Hypothesis | Sprint 20 gating branch E5 → M02/M04 |
| P6 — session effect (h08-12 positive, h22-23 drain) | High (measured, consistent with [18.12]) | Research Hypothesis | M06 session gate (E3) |
| P6 — Monday > Wed/Thu | Medium (small n) | Research Hypothesis | M06 — validate before use (E4) |
| P6 — displacement/FVG/sweep cells unmeasurable (6.8) | High (zero co-occurrence rows) | Measurement Gap | E1 telemetry (schema v3.1) |
| P4b — palette drift (spec #996B00/#593E00 vs #808080/#606060) | High (spec vs code) | Implementation Defect | Sprint 20 cosmetic fix |
| Entry unreachability (18.9: validator admits only LIQUIDITY_BOS) | High (entry doc) | Architectural Limitation | Decision required before any CHOCH experiment ships |

---

## Final Research Verdict

| Field | Value |
|---|---|
| Research Quality | **85** — the CHoCH-warning realisation (close-beyond, once-per-PP, after-flip) implements the empirically grounded subset; MSS overlay documented as absent |
| Implementation Quality | **60** — gates and dedup logic sound; reset-stall defect (C2), no tests (C1), one-sided rule (C3) |
| Architecture Quality | **70** — clean 8-stage chain, clean PP-flip design; signal unreachable in entry path (18.9) |
| Visualization Quality | **88** — renderer faithful to the logical event; palette drift only |
| Evidence Quality | **76** — exact 18.11 replication, clear session structure, but small one-sided sample; four explicit measurement gaps |
| Confidence | **B** — the replicated cell and session structure are trustworthy; family-level estimates are ±0.05 |
| Overall Recommendation | **Improve** — do NOT redesign; fix C2 (reset stall), close C3 (bearish rule or explicit scope), add the MSS delta as an experiment (E1), and gate the surviving sessions (E3) |

Closure: the CHOCH detector implements the *defensible* reading of the
signal family (close beyond a locked opposite-polarity level as a
warning, after the trend has flipped) — a conservative, no-repaint,
exactly-once design with the strongest documented evidence profile in
the portfolio cell (GBPJPY H1, exactly replicated). Its problems are
concrete and fixable: one stall defect, one-sided signal rule, no MSS
confirmation layer, no tests, and an entry path that currently blocks
the family entirely. Consistent with the Golden Rule: the algorithm
was understood before any change is proposed; the AVP verdict is
**Improve, not Redesign**.
