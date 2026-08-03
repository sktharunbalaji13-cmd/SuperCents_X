# 09 — AVP Verification Baseline v1.0 (FROZEN)

| Field | Value |
|---|---|
| Document | `09_Verification_Baseline_v1.0.md` |
| Status | **FROZEN — immutable** (per user directive, 2026-08-03) |
| Version | 1.0 (AVP Sprint 19 close) |
| Supersedes | nothing |
| Superseded by | future baseline v2.0 (created only by a new verification program) |
| Freeze authority | User review of AVP series 19.1–19.7; AVP framework rated 92–95/100 |

---

## 1. Freeze covenant

The entire AVP corpus (docs 00–09) is frozen as the **AVP Verification Baseline v1.0**:

- Sprint 20 engineering **references** these documents; it never rewrites them.
- No in-place edits after this commit. Corrections, if ever required, are recorded as **errata entries appended to this doc** (section 7) — the frozen text stays untouched.
- A new verification program (e.g., post-Sprint 20 retro with fresh evidence) creates **baseline v2.0** in its own docs; v1.0 remains as the permanent record of *why* each Sprint 20 change was made.

## 2. Frozen corpus

| Doc | Scope |
|---|---|
| 00 | AVP methodology v1.0 (frozen earlier; unchanged) |
| 01 | BOS deep research — **72/100 IMPROVE** |
| 02 | CHOCH/MSS deep research — **74/100 IMPROVE** |
| 03 | Swing deep research — **67/100 IMPROVE** |
| 04 | Liquidity deep research — **64/100 IMPROVE** |
| 05 | Order Block deep research — **66/100 IMPROVE** |
| 06 | FVG deep research — **70/100 IMPROVE** |
| 07 | Cross-document issue ledger — **39 rows** in 5 epics |
| 08 | Cross-system synthesis + traceability matrix (S9) |
| 09 | This baseline |

## 3. Verified context (frozen evidence)

| Item | Value |
|---|---|
| Evidence | Sprint 17 frozen set, `Evidence/Sprint17/merged/*.csv` |
| Rows / fingerprint | 18,686 rows, UTF-16, fingerprint `2e74bbae…` |
| Universe | decided+signal n=17,073; base wr **0.3321** |
| Methods | read-only Python probes on the frozen set; verbatim code checks; no production changes |
| Timeframe coverage | M15 + H1 (EURUSD, GBPJPY), months spanning Sprint 17 |

## 4. Six verified subsystems

| Subsystem | Doc | Passport | Verdict rollup |
|---|---|---|---|
| BOS | 01 | 72 | close-break core sound; cold-start misattribution (C02) |
| CHOCH | 02 | 74 | close-break semantics sound; bearish rule missing (C03) |
| Swing | 03 | 67 | 5-bar fractal core untouched; PD evaluator dead (C01) |
| Liquidity | 04 | 64 | weakest-possible sweep (C09); classification never written (C10) |
| Order Block | 05 | 66 | no displacement gate (C12); worst T01 case (C13) |
| FVG | 06 | 70 | wick-to-wick core correct; classifier dead end (C16); **reload = reference (S7)** |

**Baseline conclusion (frozen wording, doc 08 S6):** *"Algorithm column healthy (5/6 doctrinal cores correct); telemetry is the single system failure (T01); pipeline shows funnel inversion (R13)."*

## 5. Engineering priorities (Sprint 20, frozen order)

1. **TC — Telemetry completeness** (schema v3.1: `layerOrderBlock`, `layerFVG`, classification, gap timestamps, `fillTime`; raw wiring; `hasProtectedPoint`)
2. **T02 — Test scaffold** (regression per P0 fix)
3. **DD — Dead logic wiring** (C01, C02, C09, C10, C16, C08)
4. **LC — Lifecycle consistency** (E11 audit; FVG reload = reference pattern)
5. **Gate/routing** (R11/R13 per-family thresholds, M15 — **only after TC**)
6. **VF — Visualization parity** (C11 renderer; palette C07)
7. **ED / research M-cards** (R15, R17, R03, R16, C12, C18, R14 — gated on TC)

Do-not list (frozen, doc 08 S5): no detector redesign; no new rules; **no gate changes before telemetry**; no displacement gating until classification serialized.

## 6. Traceability (single index)

Cross-document traceability matrix lives in **doc 08 S9** — every Sprint 20 task references the finding cells that justify it. Errata and new task pointers go here:

| Sprint 20 task | AVP justification (doc § / ledger ID) |
|---|---|
| TC schema v3.1 | 08 S9 row T01; ledger T01, C13, C16 |
| Test scaffold | 08 S9 row T02; ledger T02 |
| DD wiring | 08 S9 row "Dead logic"; ledger C01, C02, C09, C10, C16, C08 |
| LC audit | 08 S9 row E11 + row "Reload"; ledger E11; doc 06 S7 |
| Gating M15 | 08 S9 row "Funnel/gate"; ledger R11, R13 |
| VF epic | 08 S9 row "Visualization"; ledger C07, C11 |
| ED M-cards | 08 S4 #7; ledger R03, R14–R17, C12, C18 |

## 7. Errata

| Date | Entry | Status |
|---|---|---|
| — | none yet | — |

---
