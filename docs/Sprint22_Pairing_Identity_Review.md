# Sprint 22 — Pairing Identity Review (analysis-only)

Date: 2026-08-11 · Status: REVIEW (no code, no protocol, no analyzer, no artifacts touched;
no Strategy Tester run) · Scope: fix the frozen pairing assumption before analyzer build (§15.3 step 4).

## 1. Current identity lifecycle

- `decisionId` is assigned at **Record() time** by the telemetry collector when the row first
  enters the collector: `if(row.decisionId == 0) row.decisionId = ++m_runId;`
  (`Telemetry/TelemetryCollector.mqh:257-258`). It is a **run-local, admission-counted
  sequence**: only rows actually recorded consume a number.
- Rows are recorded at settlement (≈50 bars after the decision), FIFO; `decisionId` order is
  strictly chronological in both arms (verified on both CSVs).
- `signalTime` is the **decision-bar time** (signal creation time), set at row build from the
  confluence signal: `out.signalTime = signal.time;` (`Telemetry/TelemetryRowBuilder.mqh:200`;
  `Telemetry/TelemetryTypes.mqh:298` — "decision capture time stays in `timestamp`"). It exists
  in v4 and v5 schemas and predates the gate.
- `timestamp` equals `signalTime` on 499/500 (272/273 in K1); the single exception
  (2026.01.15 15:00 vs 15:14; CONTROL id 228 / K1 id 127) is the **same row in both arms** —
  14-min capture lag, no collision risk.
- `configFingerprint` is a schema+config constant (1 value per run); `symbol`/`timeframe` are
  constants per file.

## 2. Failure mechanism (decisionId renumbering under GATE-OUT)

Gated-out decisions are **never recorded**, so they never consume a `decisionId`. Measured on
the TT01 replay pair (`Tools/TT01/artifacts/TT01_20260811_195509/telemetry_v5_default.csv`
[gate OFF, 500 rows] vs `telemetry_v5_k1.csv` [K1, 273 rows]):

- CONTROL: `decisionId` = 1..500; K1: `decisionId` = 1..273 — both chronological over the
  **same sequence of bars**, so after the first gated-out row the ids diverge permanently.
- K1 rows whose `decisionId` equals the CONTROL row's `decisionId` at the same `signalTime`:
  **0 of 273**. Even row 1 differs (CONTROL id 1 = 2026.01.02 04:00 is gated out; K1 id 1 =
  2026.01.02 08:00). **273 of 273 pairs are wrong** under `decisionId` pairing.
- The frozen contract is affected: §6 "the analyzer reconstructs Treatment_R = 0R for CONTROL
  decisionIds absent from the treatment CSV" (protocol §6, line 194) and gate 3b
  (line 346-352) would pair rows incorrectly. The §6 internal check (admitted rows must
  contribute d ≡ 0) would fail loudly — the estimator is unrecoverable via `decisionId`.

## 3. Candidate keys

| Key | Verdict |
|---|---|
| `decisionId` | run-local, admission-counted, renumbers under GATE-OUT → rejected |
| `timestamp` | duplicate of `signalTime` (1 lag row); fine but redundant |
| `signalTime` | unique per file; the discriminating member; sufficient per file |
| `{signalTime, configFingerprint, symbol, timeframe}` | **the ED01 "protocol 14" canonical stable key** — already defined and audited in the analyzer family (`Tools/ED01/ED01_D_Analyze.py:127-131`, `ED01_E_Analyze.py:131`) and already the sanctioned fallback: "decisionId if integrity gate 3a proves it invariant, else canonical {signalTime, configFingerprint, symbol, timeframe} (uniqueness verified by audit)" (`ED01_D_Analyze.py:404-407`, key chosen at 537-539) |

No new identity field is needed; existing columns are sufficient.

## 4. Uniqueness and cross-arm mapping (measured)

Frozen B8 CONTROL artifacts (`Tools/ED01/artifacts/<file>/CONTROL/telemetry_v4_*.csv`):

| File | Rows | decisionId unique | signalTime unique | canonical 4-tuple unique |
|---|---|---|---|---|
| EURUSD_H1 | 1,558 | 1,558/1,558 | 1,558/1,558 | 1,558/1,558 |
| GBPJPY_H1 | 1,560 | 1,560/1,560 | 1,560/1,560 | 1,560/1,560 |
| EURUSD_M15 | 6,239 | 6,239/6,239 | 6,239/6,239 | 6,239/6,239 |

(Unique per segment and across merged segments; matches ED01-D/E audit.)

TT01 replay pair (gate OFF vs K1):

| Property | CONTROL (500) | K1 (273) |
|---|---|---|
| `decisionId` unique | 500/500 (1..500) | 273/273 (1..273, renumbered) |
| `signalTime` unique | 500/500 | 273/273 |
| canonical 4-tuple unique | 500/500 | 273/273 |
| K1 `signalTime` present in CONTROL | — | **273/273 (0 missing → total pairing)** |
| Rows byte-identical on all 74 shared non-gate columns (paired by `signalTime`, excluding `decisionId` + 3 gate columns) | — | **273/273** |
| Only differing columns | — | `swingQualifyingId`, `swingAmplitude`, `gateDecision` (gate telemetry; `gateDecision` = OFF×500 vs ADMIT×273; `swingQualifyingId` 118 distinct in K1) |

§6 identity check on the pair: nGatedOut = 227; mean R(gated-out subset) = +0.145374;
Δ Mean R observed = −0.066 = −(227/500)·0.145374 exactly; admitted rows contribute d = 0
(zero violations). The pairing by `signalTime` maps every K1 opportunity to its CONTROL
counterpart without using `decisionId` at all.

## 5. Recommended canonical key

- **Primary: `{signalTime, configFingerprint, symbol, timeframe}`** — the ED01 canonical
  stable key; zero new machinery; already implemented in the analyzer family.
- Per-file practical simplification: `signalTime` alone (all other members constant per CSV);
  keep the 4-tuple in the analyzer for merged-run safety.

## 6. Validity across K1 / K1.5 / K2.0

No K1.5/K2.0 artifacts exist (no Strategy Tester run — per review scope). Validity follows
from engineering facts: the gate is admission-only (never mutates admitted rows — gate 3b);
evaluation is deterministic per decision bar; the admission rule (swing amplitude ≥ k·ATR) is
monotone in k, so every tier's admitted set is a subset of the B8 population. For any tier T:
admitted(T) ⊆ CONTROL, rows byte-identical on the 74 decision columns, T's `signalTime` ⊆
CONTROL's `signalTime` — the canonical key pairs every tier opportunity to its CONTROL row;
the tier changes only nGatedOut and the 3 gate columns.

## 7. Does the frozen protocol require a §16 amendment? — YES

- §6 hard-codes "Pairing key = `decisionId`" (line 192-194) and gate 3a certifies `decisionId`
  as the pairing proof (line 343-345). The pairing key is part of the metric/estimator
  machinery; changing it to the canonical key is a change "to … metric" as defined by
  guardrail 7 (§2, lines 62-64) and §15.2 (line 458): "Post-freeze changes to any of these
  require a §16 amendment record."
- The frozen doc references §16 (lines 60, 63, 104, 458) but contains no §16 section (it ends
  at §15 + Appendix A) — the amendment is filed as the **first §16 amendment record
  (Amendment A2)**, preserving original text per the ED01-D §16.2 precedent, changing only the
  pairing key from `decisionId` to the canonical key (with the ED01-style fallback logic:
  "decisionId if gate 3a proves it invariant, else canonical").
- The amendment is decidable **before any new run**: the uniqueness + cross-arm byte-identity
  proof above is pre-computed from frozen artifacts.
- **Filed:** proposed as **§16.2 Amendment A2** in `docs/Sprint22_RL_HYP_01_Protocol.md` on
  2026-08-11 (pending user review/freeze); accepted status recorded in the protocol §16.

## 8. Provenance / guardrails

- Nothing modified: protocol working copy verified byte-identical to the frozen blob
  (`git hash-object` = HEAD = `a238dacb…`; `git status` clean); no production code, analyzer,
  runner, or artifact touched; no Strategy Tester run; no commit, no push.
- Filed as **§16.2 Amendment A2 (proposed)** on 2026-08-11; after user review/freeze, at §15.3
  step 4, build the Sprint 22 analyzer with the canonical-key pairing plus the ED01-D/E
  fallback audit.
