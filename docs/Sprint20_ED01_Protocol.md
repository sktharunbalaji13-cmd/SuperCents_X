# Sprint 20 — ED01 Entry-Decision Research: Protocol

Status: FROZEN 2026-08-08 (execution amendments recorded in section 13)
Scope owner: entry-decision research, first measurement milestone (ED01-A)

## 1. Purpose and scope

ED01 begins the entry-decision research phase (M2 Platform Stable → Measurement
Ready). The discipline is **measure first; change only when the evidence earns
the change**. ED01 defines how entry-component hypotheses are tested; ED01-A is
the first experiment (admission-floor sensitivity).

Scope boundaries:

- **In scope:** entry admission (per-family floors), measured via the existing
  telemetry replay pipeline. No algorithm redesign.
- **Out of scope:** detector logic, rendering, risk/position sizing, order
  execution, telemetry schema, visualization. All unchanged.
- **Outcome caveat (declared):** the replay outcome simulation uses the legacy
  `CEntrySetupBuilder` fixed-RR builder (DD04 note). `rMultiple` therefore
  reflects fixed-RR outcomes; the DD04 opposing-liquidity TP path is not yet in
  the outcome sim. ED01-A measures **admission changes under fixed-RR
  outcomes** — this limits claims to admission effects, not TP effects.

## 2. Guardrails (non-negotiable)

1. **B8 remains the canonical Sprint-20 baseline.** Every experiment must be
   reproducible as: B8 grid + one declared variable change.
2. **No production behavior change.** Experiment runs use test-only input
   exposure; defaults equal the current compiled values, so the default run is
   byte-identical to B8 (verified by TT01 BEHAVIOR-REGRESSION).
3. **One variable per experiment.** ED01-A varies exactly one floor per run.
4. **Pre-registration.** Metrics, split, and pass/fail thresholds are fixed in
   this document before any experiment run; results do not move the goalposts.
5. **No baseline transition without a decision.** A change enters production
   only through KEEP/REJECT/DEFER verdict + TT01 gate + explicit freeze.

## 3. Mechanism (engineering prerequisite)

Floors currently live in `Entry/Validators/ValidatorConfig.mqh:28-42`
(`ConfluenceConfig` defaults 0.60/0.35/0.35/0.35/0.35/0.35), consumed by
`CConfluenceValidator::ResolveFloor()` (`ConfluenceValidator.mqh:29-40`), and
are stamped into the config fingerprint (`Telemetry/ConfigFingerprint.mqh:100-105`).
`SymbolContext.mqh:138` default-constructs the validator — floors are compiled
constants today, not tester-controllable.

ED01 engineering step (TDD-covered, defaults preserved):

- Expose six `input double` floors (`ED01_FloorLiquidity` … `ED01_FloorUnknown`)
  in the EA, defaulting to the current values; when set, they feed the
  `ConfluenceConfig` used by `CConfluenceValidator`. Defaults path is bit-for-bit
  the current code path (no default-run delta).
- Verify fingerprint policy-recording: changed-floor runs produce a different
  `configFingerprint` (expected policy recording, constancy enforced per-run by
  the CONTRACT gate), default runs produce the B8 fingerprint.
- TDD: floor-to-`ResolveFloor` mapping, default-equality, fingerprint deltas.

## 4. ED01-A experiment grid — admission-floor sensitivity

Hypothesis (pre-registered): the GR01 floors are evidence-calibrated on the
frozen Sprint 17 set; varying one floor should **not** improve out-of-sample
expectancy beyond noise, or would improve it only at the cost of trade count.

Grid: for each family floor f in {LIQUIDITY 0.60, FVG 0.35, BOS 0.35,
CHOCH 0.35, UNKNOWN 0.35}, vary ONLY f over {f − 0.10, f − 0.05, f + 0.05,
f + 0.10} (clamped to [0.20, 0.80]); all other floors fixed at B8 values.
Total: 5 families × 4 deltas = 20 experiment runs + 1 B8 control run per grid
(symbol/timeframe). UNKNOWN floor is included with its dedicated input.

Each run = headless tester replay on the same grids as collection, producing
telemetry CSVs (same 75-column v3.1 schema).

## 5. Data split (strict out-of-sample)

- **Calibration context (used for context only):** frozen Sprint 17 set
  (18,536 decided rows) and the TT01 replay grid (EURUSD H1, 2026-01, 500 rows).
- **In-sample (modeling/tuning):** none — ED01-A has no fitting step. Floor
  deltas are fixed by the grid before results are seen.
- **Out-of-sample (measurement):** collection grids, all untouched by GR01:
  - EURUSD H1 (`Sprint17_Collection_EURUSD_H1.ini`)
  - EURUSD M15 (`Sprint17_Collection_EURUSD_M15.ini`)
  - GBPJPY H1 (`Sprint17_Collection_GBPJPY_H1.ini`)
  - (GBPJPY M15 was never collected in Sprint 17 — no preset exists; the
    "4-file" stability references below therefore resolve to the **2 H1 files**)
- **ED01-A screening window (amended, see section 13):** 2026.04.05–2026.07.05.
- **Per-file stability:** every metric is reported per file; a finding must
  agree in direction in both H1 files (2/2), not only in the aggregate.

## 6. Metrics

Primary (pre-registered):

- **Mean R** (mean of `rMultiple`) per rule family, per run — the decision
  metric. Reported with delta vs the same-family B8 control run.
- **Trade count** (rows per family) — guards against "improvement by
  loosening" (more trades must not be the source of the gain).

Secondary (reported, not decision-gating):

- Win rate, median R, R distribution (quantiles), per-family admission rate
  (admitted / decided), drawdown proxy (max drawdown of the cumulative R
  sequence), funnel conversion deltas via `Tools/GR02/gr02_funnel.py`.

## 7. Statistical method

- **Bootstrap 95% CI** on per-family mean R (10,000 resamples, stratified by
  day to respect bar dependence).
- Verdict criterion is on the **delta** (experiment − B8 control per family):
  the CI must exclude 0 AND the effect size must exceed a pre-registered
  minimum meaningful delta of **+0.05 mean R** (matching the GR01 noise
  discipline where gains within noise were rejected).
- Minimum sample: family runs with n < 50 decisions per file are reported but
  not decision-gated (noise floor, consistent with GR01's n thresholds).
- Multiple-comparison control: 20 runs × 5 families; a family floor is only
  revisited if the signal is consistent across **both H1 files** (2/2 per-file
  stability gate, sections 5 and 12.1).

## 8. Pre-registered decision rules (frozen before runs)

- **KEEP floor (no change):** OOS mean-R delta CI includes 0, or effect < 0.05,
  or improvement requires > 25% trade-count inflation with no mean-R gain.
- **REJECT/CHANGE floor:** CI excludes 0, effect ≥ +0.05 mean R on the primary
  file (EURUSD H1), direction agrees in **both H1 files (2/2: EURUSD H1 and
  GBPJPY H1)**, and trade-count
  inflation does not account for the gain (per-family R unchanged or better on
  the admitted subset).
- **DEFER:** signal present but violates stability/sample constraints; record
  for ED01-B/C with a follow-up experiment design.
- The B8 default floor is the null hypothesis; no change is the default outcome
  when evidence is weak.

## 9. Engineering gates (every experiment run)

1. **TDD:** floor-input exposure tests RED → GREEN (suite increment).
2. **Compile:** 6 TT01 targets clean.
3. **Suite:** full headless suite green (current 2239/2239, grows with new tests).
4. **TT01 on default inputs:** OVERALL PASS with **BEHAVIOR-REGRESSION
   byte-identical vs B8** (75/75 columns) — proves the experiment mechanism did
   not perturb production.
5. **TT01 on experiment inputs:** CONTRACT gate (schema, fingerprint constancy
   within run) + EVIDENCE gate hold; BEHAVIOR gate is not applicable to
   changed-floor runs (expected policy recording).

## 10. Deliverables

- `docs/Sprint20_ED01_Decision.md` — per-family verdict table with evidence,
  after runs (mirrors GR01/GR02 decision docs).
- `Tools/ED01/` artifacts: run CSVs, bootstrap summaries, per-file tables,
  allow-decision lists if any, manifest per experiment.
- Ledger update (cross-document issue ledger) for any KEEP/REJECT/DEFER.

## 11. ED01 sequence after protocol freeze

ED01-A (floor sensitivity) → ED01-B (liquidity-rule vs non-liquidity-rule
conditional expectancy) → ED01-C (TP target logic, once the outcome sim
reflects the DD04 opposing-liquidity path). Each ED follows this protocol;
no production change until a decision earns it.

## 12. Frozen decisions (protocol freeze, 2026-08-08)

| §12 item | Decision | Rationale |
|---|---|---|
| 1. Delta spacing | **Keep ±0.05 / ±0.10** (decision-gated) | Meaningful local sensitivity range without exploding the 21-run grid; tests both modest and material floor changes |
| 2. UNKNOWN floor | **Evidence-only** | Small sample; fallback path; a noisy small-n result must not drive a production floor decision |
| 3. M15 files | **Evidence-only** | H1 is the primary decision population; M15 provides robustness/context, not authority for KEEP/REJECT |
| 4. Drawdown proxy | **Informational** | Useful danger flag only; the replay outcome model is not a full live execution/drawdown model |

### 12.1 Decision hierarchy (frozen)

```
                    B8 CONTROL
                        │
                        ▼
              H1 primary population
                        │
              ┌─────────┴─────────┐
              │                   │
       Mean-R delta          Bootstrap 95% CI
              │                   │
              └─────────┬─────────┘
                        ▼
              +0.05 meaningful effect
                        │
                        ▼
              2/2 H1 files stable
                        │
                        ▼
                 KEEP / REJECT
                        │
             ┌──────────┴──────────┐
             │                     │
          M15 evidence       UNKNOWN evidence
          only               only
```

### 12.2 Guardrail (frozen)

- A strong M15 or UNKNOWN result **cannot rescue a failed H1 decision**.
- A promising H1 floor is **not rejected** because UNKNOWN or M15 is noisy.
- Conclusion always follows the H1 primary population per 12.1; M15 and
  UNKNOWN are reported as robustness/context only.

### 12.3 ED01 engineering order (frozen)

1. Expose the six floors as inputs with the exact current defaults.
2. TDD the floor-to-`ResolveFloor` mapping, default equality, fingerprint deltas.
3. **Prove the default configuration is byte-identical to B8 (TT01
   BEHAVIOR-REGRESSION on default inputs) before any experimental grid run.**
4. Only then run the ED01-A grid (21 runs per file = 1 B8 control + 20 floor
   deltas) per section 4.

## 13. Execution amendments (recorded, not silent)

### 13.1 ED01-A screening window: 3 months (2026-08-08, user decision)

> ED01-A execution amendment: initial grid reduced to a 3-month screening
> window to reduce computational cost. The 3-month run is exploratory
> screening; final floor decisions require subsequent longer-horizon
> validation.

- **Window:** 2026.04.05 → 2026.07.05 (3 months; replaced the original
  2026.01.05 → 2026.07.05). Same tick data source as collection.
- **Unchanged:** 21 configs (1 B8 control + 20 single-floor deltas) × 3 files
  (EURUSD H1, GBPJPY H1 decision files; EURUSD M15 evidence-only);
  `newDecision=1` population; mean-R primary metric; bootstrap 95% CI (10,000,
  day-stratified); +0.05 meaningful-effect threshold; 2/2 H1 stability;
  UNKNOWN/M15 evidence-only rules.
- **Cost:** 63 runs total; H1 ≈ 1–2 min/run, EURUSD M15 ≈ 26 min/run
  (≈ 1 h + 9 h wall).
- **Flow (user-approved):** 3-month ED01-A → if a floor shows a promising /
  stable signal → deeper 1-year / 2-year validation later. Absence of a
  signal in 3 months is not evidence of no edge; it only avoids further
  compute on an unpromising grid.
- **Run record (2026-08-08 18:27 → 22:03):** the original 6-month batch ran
  46 configs before the terminal wedged on the 6th M15 run (partial
  capture, `rows=-1`, subsequent launches exited instantly; batch process
  died). Completed runs archived at
  `Tools/ED01/artifacts_6mo_2026-01-05_07-05/` (EURUSD H1 20/21, GBPJPY H1
  21/21, EURUSD M15 5/21) and `Tools/ED01/run_6mo.log` — retained as
  candidate long-horizon validation material for the ED01-A follow-up, NOT
  used for the 3-month screening verdicts. The runner was hardened
  (retry-on-empty, streaming journal read) before the 3-month batch.
