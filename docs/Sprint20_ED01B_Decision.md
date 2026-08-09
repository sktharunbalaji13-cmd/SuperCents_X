# Sprint 20 — ED01-B Decision: Liquidity vs Non-Liquidity Conditional Expectancy

Status: COMPLETE — 2026-08-09
Scope owner: entry-decision research, second measurement milestone (ED01-B)
Protocol: `docs/Sprint20_ED01B_Protocol.md` (frozen 2026-08-09; execution
amendments 13.1 audit-count precision, 13.2 fingerprint-gate correction)

## 1. Verdict summary

**REJECT / NO DISTINCT LIQUIDITY EDGE under the pre-registered protocol.**

The available B8 evidence does not establish a distinct positive conditional
expectancy for liquidity-family decisions.

| Criterion (protocol §7/§8) | Requirement | Result |
|---|---|---|
| Materiality | \|Δ\| ≥ 0.10 on EURUSD_H1 | 0.1164 — cleared |
| 95% CI excludes 0 | CI not spanning zero | **[−0.2006, +0.0950] — FAILS (includes 0)** |
| 2/2 H1 direction | same sign both H1 files | both negative, but moot — CI gate already fails |
| n ≥ 50/group/file | both decision files | PASS (607/813; 96/121) |
| Paired days | ≥ 10 on primary | PASS (55) |
| Estimator agreement | no sign conflict w/ CI exclusion | PASS (no conflict; both CIs include 0) |

The point estimate crosses the 0.10 materiality bar, but the pre-registered
CI gate fails. The protocol therefore produces REJECT — it does not claim a
liquidity edge, and equally it does **not** convert the negative point
estimate into "liquidity is definitively bad". No production change.

## 2. Population audit

Analyzer self-check (hard gate, protocol §10 + amendments 13.1/13.2):
**PASS** — fingerprints per file reproduce the frozen values (EURUSD_H1
`3005138848403243456` = TT01 B8 baseline; GBPJPY_H1 `14617585492269479818`;
EURUSD_M15 `13548296177162108249`; each also identical in the 6-month archive
CONTROL runs), qualified counts and per-family closed counts reproduce the
frozen ED01-A analysis exactly (EURUSD_H1 1,468/1,420; GBPJPY_H1 236/217;
EURUSD_M15 5,981/5,931), and per-family mean R reproduces ED01-A to 4 dp.
Population: frozen B8 CONTROL artifacts, 2026.04.05 → 2026.07.05,
`newDecision=1`, settled `rMultiple` (outcome 1/2/3), censored (outcome 0)
excluded from R statistics and reported as nOpen.

## 3. EURUSD_H1 primary result

| Group | nClosed (nOpen) | WR (BE-excl.) | Mean R | Median | Q25/Q75 | maxDD |
|---|---|---|---|---|---|---|
| LIQUIDITY | 607 (7) | 0.3031 | −0.0906 | −1.0 | −1.0 / 2.0 | 92.0 |
| NON-LIQUIDITY (pooled) | 813 (41) | 0.3419 | +0.0258 | −1.0 | −1.0 / 2.0 | 95.0 |

**Δ Mean R = −0.1164** — pooled day-stratified 95% CI **[−0.2006, +0.0950]**
(10,000 resamples, seed 20260809, 55 paired days). Auxiliary daily-mean
estimator: point +0.0340, CI [−0.2910, +0.3646] — opposite sign to the pooled
point estimate, but neither CI excludes 0, so no estimator-conflict DEFER
(protocol §5) and no support for a distinct effect in either direction.

## 4. GBPJPY_H1 confirmation file

| Group | nClosed (nOpen) | WR | Mean R | maxDD |
|---|---|---|---|---|
| LIQUIDITY | 96 (4) | 0.3021 | −0.0938 | 22.0 |
| NON-LIQUIDITY (pooled) | 121 (15) | 0.3223 | −0.0331 | 24.0 |

Δ = −0.0607, CI [−0.3520, +0.3293] (12 paired days). Below the 0.10
materiality bar and CI includes 0 — the second H1 file does not establish an
edge either. Direction (negative) agrees with EURUSD_H1 at point level.

## 5. EURUSD_M15 evidence-only result (never gates)

| Group | nClosed (nOpen) | WR | Mean R | maxDD |
|---|---|---|---|---|
| LIQUIDITY | 1,694 (3) | 0.2875 | −0.1464 | 332.0 |
| NON-LIQUIDITY (pooled) | 4,237 (47) | 0.3495 | +0.0408 | 226.4 |

Δ = −0.1872; pooled CI [−0.1566, +0.0153] includes 0; auxiliary daily CI
[−0.4248, −0.0128] is wholly negative. Consistent with the H1 direction but
registered as evidence only — reported, not weighed in the verdict.

## 6. Per-family decomposition (EURUSD_H1)

| Family | nClosed (nOpen) | WR | Mean R | maxDD |
|---|---|---|---|---|
| LIQUIDITY | 607 (7) | 0.3031 | −0.0906 | 92.0 |
| FVG | 318 (33) | 0.3868 | +0.1604 | 44.0 |
| BOS | 378 (8) | 0.3360 | +0.0079 | 67.0 |
| UNKNOWN | 117 (0) | 0.2393 | −0.2821 | 53.0 |
| CHOCH | 0 | — | — | — |
| ORDER_BLOCK | 0 | — | — | — |

The pooled NON-LIQUIDITY +0.0258 is composition-driven: FVG carries it
(+0.1604 on 318 rows), BOS is neutral (+0.0079), UNKNOWN drags (−0.2821).
This is exactly the pooled-group sensitivity the protocol's UNKNOWN-exclusion
and concentration checks were registered to detect (see 7/8). Confidence is
discrete (LIQUIDITY {0.60} constant; FVG {0.35, 0.40}; BOS {0.40, 0.45};
UNKNOWN no fired rule), unchanged from ED01-A.

## 7. UNKNOWN-exclusion robustness (gating check, EURUSD_H1)

Pooled NON-LIQUIDITY minus UNKNOWN: Δ = **−0.1682**, CI [−0.2429, +0.0739]
(36 paired days, nNon = 696). Same sign as the primary, larger magnitude —
the conclusion does not hinge on UNKNOWN's poor expectancy. (The check is
registered to protect an EVIDENCE verdict; the verdict was REJECT at the CI
gate regardless.)

## 8. Sub-family concentration check (gating check, EURUSD_H1)

Removing any single NON-LIQUIDITY family from the pool:

| Pool after removal | Δ Mean R | 95% CI |
|---|---|---|
| minus BOS | −0.1320 | [−0.2432, +0.0903] |
| **minus FVG** | **−0.0300** | [−0.1729, +0.1318] |
| minus CHOCH (0 rows) | −0.1164 | [−0.2014, +0.0913] |
| minus ORDER_BLOCK (0 rows) | −0.1164 | [−0.1966, +0.0922] |
| minus UNKNOWN | −0.1682 | [−0.2390, +0.0764] |

The gap between liquidity and the pool collapses to −0.0300 when FVG is
removed — the pooled non-liquidity difference is substantially carried by one
sub-family. All variants keep CI including 0; none would have supported an
EVIDENCE verdict. This confirms the protocol's design concern: pooled
comparisons of this kind are composition-sensitive and must not be read as a
liquidity-specific statement.

## 9. Informational cross-checks

- TT01 B8 baseline replay (EURUSD H1, 2026-01, 500 rows): Δ = −0.0458
  (LIQ n=191, NON n=247) — below materiality, consistent direction.
- Determinism: two full analyzer runs produced byte-identical
  `results_ED01B.json` (MD5 equal) — fixed seed 20260809.

## 10. Final verdict

**REJECT / NO DISTINCT LIQUIDITY EDGE.**

The B8 evidence does not establish a distinct positive conditional expectancy
for liquidity-family decisions under the frozen protocol's criteria. The
point estimate leans against liquidity on the primary file, but the 95% CI
includes 0 and the decomposition shows the pooled gap is composition-driven
(FVG-dependent) — so neither "liquidity edge" nor "liquidity is definitively
worse" is supported.

## 11. No production change

- Do **not** remove the Liquidity rule family.
- Do **not** lower or raise its floor (0.60 stands, per ED01-A KEEP).
- Do **not** modify the LiquidityDetector.
- Do **not** change entry weights or validator logic.
- Do **not** re-freeze a B9/B10 baseline.
- Do **not** optimize around this result.

Under ANY ED01-B verdict the milestone is analysis-only; this one is no
exception. No algorithm, config, or baseline changes.

## 12. Implications for the next ED experiment

1. Liquidity receives **no special treatment** in future experiment design —
   there is no evidence a liquidity-specific entry experiment is worth
   prioritizing at this point.
2. The ED01 sequence continues with **ED01-C (TP target logic)** once the
   outcome sim reflects the DD04 opposing-liquidity path — unchanged by
   ED01-B.
3. Future family-attribution experiments must pre-register pooled-group
   composition sensitivity (as ED01-B did); the FVG-carried result here is
   the concrete example of why.
4. The negative point estimates on both H1 files and the wholly negative M15
   daily CI are recorded as evidence, not conclusions. A liquidity-specific
   hypothesis would need new, pre-registered evidence before any experiment
   is designed around it.
5. The 6-month archive remains reserved for later long-horizon validation
   (protocol amendment 13.1); ED01-B does not trigger it.
