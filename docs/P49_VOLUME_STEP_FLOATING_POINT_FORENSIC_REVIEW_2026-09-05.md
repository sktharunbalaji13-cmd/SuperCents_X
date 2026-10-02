# P49 — VOLUME-STEP FLOATING-POINT FORENSIC REVIEW

Date: 2026-09-05
Mode: READ-ONLY forensic review. No code/test/parameter/baseline/holdout modification; no runs, no instrumentation implemented, no fix selected.
Authority: senior-advisor P49 prompt on P44/P45 anomaly (`0.30` rejected vs `0.28` passes).
HEAD: `36c7a73fd8ba22ebd1f20e5ff332da1e4cafc7b3`, Branch: `main`.

## Disposition

### `P49 DEFECT CONFIRMED — MEASUREMENT REQUIRED BEFORE FIX`

## Required output table

| Location | Current Logic | Numerical Risk | Reproducible? | Mechanical Defect? | Measurement Needed | Candidate Fixes | Human Decision Required |
|---|---|---|---|---|---|---|---|
| `Trading/TradeValidation.mqh::IsVolumeValid` :91-96 (LIVE sole gate) | `MathMod(volume-volMin, volStep) > 1e-10` → reject; no normalization anywhere (zero `NormalizeDouble` repo-wide in trade dirs) | Dust-complement remainders (≈ full step, e.g. 0.009999999999999974) exceed fixed 1e-10 → valid grid volumes rejected | YES — exact live signature reproduced (0.30→REJ mod≈0.01; 0.28→PASS mod≈1e-17) | YES — producer/validator contract inconsistent | Attempt/fail rate + remainder distribution (spec §5) | Step-scaled epsilon / int-domain check / quotient check (NOT selected; §6) | YES — convention + tolerance + site |
| `Risk/PositionSizer.mqh` floor (LIVE producer, C2) | `MathFloor(lots/step)*step` in doubles | Emits dusty grid doubles (e.g. floor path to 0.30-form) that §1 gate rejects | YES (same grid) | YES (as producer half) | Same | Normalize at producer OR gate (decision) | YES (same) |
| `Portfolio/CapitalAllocator.mqh` round/clamp (LIVE producer, gate path) | `MathRound(lots/step)*step`, round-then-clamp (P37) | Same dust emission; rounding predates P37 (clamp-then-round identical exposure) — NOT P37-introduced | YES | YES (as producer half) | Same | Same | YES (same) |
| `Entry/ExecutionManager.mqh::ValidateVolume` :313-314 (DEAD duplicate) | Identical `MathMod>1e-10` | Same defect, zero live effect (`Execute` unwired per Sprint25B reports) | By code identity | Dormant (would bite if ever wired) | None (dead) | Align with chosen convention if ever revived | Only if revived |
| `Entry/RiskManager.mqh::Calculate` floor (DEAD producer) | `MathFloor(...)*step` | Same emission, zero consumers | By code identity | Dormant | None | Align if ever revived | Only if revived |
| `Trading/TradeManager.mqh:178` `SetLotSize` clamp | `fmax(lotSize, volMin)` | Exact broker constant, no arithmetic — safe | N/A | No | No | None | No |

Validator/validator agreement: the two MathMod gates agree with each other (identically defective). The inconsistency is producer-vs-validator.

## 1. Root cause

Binary64 grid doubles (`k*step`) are inexact for most k (e.g. `0.3` = 0.29999999999999998898). `MathMod(g−vmin, step)` then yields dust complements (≈step, not ≈0) for affected k, and the fixed `1e-10` tolerance with no normalization rejects them. Producers (`MathFloor`/`MathRound` × step) emit exactly such doubles by construction. Assumption note: IEEE754 + fmod-equivalence per MQL docs; live pair (0.30 REJ / 0.28 PASS) matches the model bit-plausibly, and the defect conclusion (0.30 rejected) holds under ANY exact-comparison semantics — only the population rate depends on the model.

## 2. Scope

All symbols with non-power-of-2-friendly steps (0.01, 0.1 non-aligned vmin, …). Grid measurement (exact, distribution-free): step 0.01/vmin 0.01 → **58.25% of cent-grid points fail** (e.g. k=3,4,6,12,15,16,18,19,30; even 0.50 fails); step 0.1/vmin 0.01 valid grid (vmin+k·step) → 48% fail; step 1.0 → 0% (integers exact). Pass/fail is a per-value coin flip (0.17/0.28 pass; 0.18/0.30 fail).

## 3. Frequency (honest bounds)

- Structural: §2 rates (assumption-light).
- Live: 2 verbatim failures observed (P44 run-B, rotated off disk but in transcript record); deal counts (4 deals P41-run2, 1 position P44-runB) compatible with heavy intermittent rejection but confounded by C3/inspection/margin blocks — NOT solely attributable.
- Direct attempt/fail telemetry ABSENT (agent-log rotation; validator remainder never logged). Sizing-attempt lines (`POSITION-SIZING lots=`) exist in principle for future harvest.
- Net: defect confirmed, live rate unmeasured → measurement before fix (spec §5).

## 4. False-reject / false-accept

- **False rejection: CONFIRMED live** (0.30, 0.18 — mathematically valid broker-grid volumes rejected; silently per-plan, retryable next tick → intermittent fill lottery, plausibly contributing to run-to-run fill divergence in P44).
- **False acceptance: none observed** — all off-grid probes (0.015, 0.105, 0.033, 2.5) correctly rejected; mechanism cannot yield ≤1e-10 remainders for genuinely off-grid values except pathological dust (none found).
- **Harmless artifact: NO** — rejections block real sends (material), though mitigated by per-tick retry with fresh fills.

## 5. Measurement spec (logging-only, future authorization — NOT implemented)

Per sizing/validation event: raw requested volume · post-round/floor volume · volMin/step · computed remainder (full precision) · decision · symbol · tester-time · producing path (sizer vs allocator vs fixed). Harvest `ORDER-FAILED` rate + remainder histogram over a standard window; compare against §2 grid rates.

## 6. Normalization boundary (options presented, none selected)

1. `NormalizeDouble(v, stepDigits)` — INSUFFICIENT ALONE (nearest-2-dec double of 0.3 is the same dusty value); must pair with epsilon → two decisions, not one.
2. Step-scaled epsilon (`rem < tol || step−rem < tol`, tol ≪ step/2, e.g. order 1e-8): catches complements; tol value + site (producer vs gate) are design decisions; too-loose tol admits off-grid.
3. Integer-domain (`k=round((v−vmin)/step)`; accept iff `|v−(vmin+k·step)| ≤ tol`): equivalent to 2 with explicit k; residual risk — broker-side acceptance of normalized dusty doubles is unproven live (broker accepted 0.28-dust; 0.30-normalized unknown until observed).
4. Project convention: NONE exists (zero uses) — any fix introduces one → design decision by definition.
Blast radius of any fix: currently-failing volumes start sending (fill-rate increase on identical signals/sizing — quantitative behavior change, same intent); passing volumes unaffected iff tolerance sane. Fix NEVER touches signal/sizing values, only admissibility.

## 7. Standing state + firewall

P48 guard, P31/C4, P37/P39, P41 cap, B8/B9, PromotionGate/TT01/holdout, BE-OFF, research BLOCKED, deployment unauthorized — all untouched/reaffirmed. No profitability claim. STOP after P49. Next executable step (if authorized): §5 logging-only instrumentation → rate measurement → separate fix authorization with convention selection.
