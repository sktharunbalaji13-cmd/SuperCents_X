# P50 — VOLUME-STEP MEASUREMENT INSTRUMENTATION & RATE MEASUREMENT

Date: 2026-09-05
Mode: Logging-only evidence phase. No numerical correction, behavior change, or policy action.
Authority: senior-advisor P50 prompt on P49 (`docs/P49_VOLUME_STEP_FLOATING_POINT_FORENSIC_REVIEW_2026-09-05.md`: DEFECT CONFIRMED — MEASUREMENT REQUIRED BEFORE FIX).
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`. No reset/stash/commit.

## Disposition

### `P50 COMPLETE — DEFECT FREQUENCY MEASURED, FIX DESIGN READY`

## 1. Instrumentation (logging-only; decision logic byte-identical)

`Trading/TradeValidation.mqh::IsVolumeValid`: three `Print` `VOL-MEASURE` lines (range-fail / step-fail / pass) carrying time, symbol, vol@10dp, min/max, step, remainder@16dp, result, shadow int-domain k + dev@16dp. Shadow values computed, never branched on. No `NormalizeDouble`, no epsilon, no rounding change. Callers untouched (live: `TradeManager` C2-check only).

## 2. Behavior neutrality proof

EA 0/0 (`compile_p50_ea.log`), runner 0/0, suite on fresh tag 13:14:08: **3344/3344, 0 FAIL** (`Tests/p50_artifacts/p50_unittests_hits.log`). Same run also confirms P48 intact (380 executable, 4 NetRR rejects — §4).

## 3. Measurement (LEGACY, EURUSD H1 2026.01.01→04.01 Model=1, wall 13:19, non-holdout)

- **3,717 validation events**, all EURUSD step 0.01: **3,400 PASS / 317 REJECT-STEP (8.53%)** / 0 REJECT-RANGE. Raw: `Tests/p50_artifacts/p50_vol_raw.log` (3,717 lines).
- **All 317 rejects are on-grid false rejects**: shadow dev max 2e-16, min 0.0 — every rejected volume sits on the broker grid within dust. Zero genuine off-grid rejects observed.
- Reject remainders all >1e-10 with ~step magnitude (dust complements) — the exact P49 mechanism, live.
- Distinct failing volumes span the grid (0.06–1.92; top: 0.12×62, 0.16×22, 0.15×17, 0.30×14, 0.36×13); known signatures 0.30/0.18 recur (14/8).
- **NO FALSE ACCEPTANCE OBSERVED**: 0 PASS lines with dev>1e-6 (3,400 checked).

## 4. Validity classification

- Exactly on-grid: 3,400 + 317 = all events (dev ≤ 2e-16 throughout). Off-grid: 0 events observed. Indeterminate: 0 (no dust-band ambiguity at 1e-9 vs 1e-6 separation — six orders of magnitude).
- Verdict: every rejection in the window was a false reject; no correct rejection missed observation because none occurred.

## 5. Normalization comparison (offline estimates on the 3,717 logged pairs — NOT applied)

- Step-scaled epsilon (tol=1e-8, symmetric step−rem): rescues 317/317, flips 0 correct decisions.
- Integer-domain (|dev|≤1e-8): rescues 317/317, flips 0.
- `NormalizeDouble`-alone: still insufficient per P49 (nearest-decimal double stays dusty) — must pair with tolerance.
- Broker compatibility: rescued volumes are exact grid intents (k·step); broker accepted same-dust forms before (0.28/0.17 live sends) — residual acceptance risk noted, unproven either way, observable post-fix via ORDER-FAILED rate (now measurable with this instrumentation retained).
- Blast radius of a future fix: currently-failing intents start sending (fill-rate recovery on identical signals/sizing); passing set unaffected under sane tolerance. No selection recommended here.

## 6. Standing state + firewall honored

P48 guard intact (§2) · P31/C4/P37/P39/P41-cap untouched · B8/B9/PromotionGate/TT01/holdout/params untouched · BE/TS still OFF (0 shadows in NEW windows; LEGACY shadows out of scope here) · research BLOCKED · no profitability/deployment claims. No numerical correction applied — validator still rejects dust exactly as before. STOP after P50. Next (if authorized): narrow fix phase selecting the numerical convention.
