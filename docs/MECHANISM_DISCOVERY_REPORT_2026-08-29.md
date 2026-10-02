# Mechanism Discovery Report — Next Economic Mechanism Search (Governance-First)

Status: **RESEARCH REMAINS PAUSED — NO SURVIVOR (Option B candidate recorded with named verifications)**
Date: 2026-08-29
Scope: Literature/mechanism discovery ONLY. No market data acquired, no backtest, no holdout inspection, no parameter work, no production change, no PromotionGate change.
Predecessor state: Sprint 23 closure ("NO SPRINT 23 EXPERIMENT IS JUSTIFIED", 2026-08-12). This record is a decision record in the same style; it freezes nothing and authorizes nothing.
Production state: `.mq5/.mqh` FROZEN, parameters FROZEN, PromotionGate UNCHANGED, 2026-H2 (2026-07-04→2026-12-31) LOCKED and NOT INSPECTED.

---

## 1. Executive conclusion

**No genuine survivor exists.** Ten genuinely distinct candidate mechanisms were searched across the permitted domains (scheduled institutional flows, benchmark/index mechanics, scheduled commodity reports, auction mechanics, dealer/balance-sheet constraints, settlement/mandated flows, policy announcement mechanics). Nine fail hard gates outright (literature class, N, single-sign, DOF, provenance, or retail cost). One candidate — **C1: S&P 500 index-addition forced benchmark flows** — clears every structural gate (causal chain, predeclared direction, literature-pinned horizon, DOF, provenance anatomy, distinctness) but has **two gates that are UNKNOWN**, not PASS:

- post-2015 effect-size literature (verification not completed this session);
- exact independent-observation count from a complete public announcement archive.

Under the governance rule UNKNOWN = FAIL, C1 is **not** a survivor. Correct outcome: **research remains PAUSED.** C1 is recorded as an Option-B candidate: promising, structurally sound, and returned to this gate only if governance explicitly authorizes the two named document-only verifications in §11. Nothing here approves acquisition, backtest, coding, or production change.

---

## 2. Candidate table

| Candidate | Causal | Direction | Horizon | Post-2015 | N | Sign | DOF | Cost | Data | Provenance | Distinct | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C1 S&P 500 additions — forced benchmark flow | PASS | PASS | PASS | UNKNOWN | UNKNOWN | PASS | PASS | UNKNOWN | UNKNOWN | PASS | PASS | **FAIL** (2×UNKNOWN) |
| C2 Treasury auction concession / post-auction drift | PASS | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | FAIL | UNKNOWN | UNKNOWN | PASS | FAIL |
| C3 EIA crude inventory surprise → WTI | PASS | UNKNOWN | PASS | UNKNOWN | PASS | UNKNOWN | UNKNOWN | FAIL | UNKNOWN | UNKNOWN | UNKNOWN | FAIL |
| C4 EIA natural-gas storage surprise → NG | PASS | UNKNOWN | PASS | UNKNOWN | PASS | UNKNOWN | FAIL | UNKNOWN | UNKNOWN | FAIL | PASS | FAIL |
| C5 USDA WASDE surprise → corn/soy | PASS | UNKNOWN | PASS | UNKNOWN | PASS | UNKNOWN | FAIL | UNKNOWN | UNKNOWN | FAIL | PASS | FAIL |
| C6 PBOC CNY fixing surprise → CNH | PASS | UNKNOWN | PASS | PASS | PASS | PASS | FAIL | FAIL | UNKNOWN | UNKNOWN | FAIL | FAIL |
| C7 MOF Japan FX interventions → JPY | PASS | PASS | UNKNOWN | PASS | FAIL | FAIL | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | PASS | FAIL |
| C8 OPEC / OPEC+ announcements → crude | PASS | FAIL | UNKNOWN | UNKNOWN | FAIL | FAIL | FAIL | UNKNOWN | UNKNOWN | UNKNOWN | PASS | FAIL |
| C9 Treasury supply / refunding announcements → rates | PASS | FAIL | UNKNOWN | UNKNOWN | PASS | FAIL | FAIL | UNKNOWN | UNKNOWN | FAIL | PASS | FAIL |
| C10 Central-bank gold reserve flows → gold | PASS | UNKNOWN | UNKNOWN | PASS | UNKNOWN | UNKNOWN | UNKNOWN | PASS | UNKNOWN | UNKNOWN | PASS | FAIL |

Early exclusions (pre-gate, one line each — retired-family collisions or prohibited conversions):
quarter-end bank balance-sheet FX flows (= retired CIP/basis family); GLD-flow chasing (correlation→expectancy); OPEX dealer-gamma hedging (conditional; gamma data proprietary); Russell reconstitution and MSCI SAIR (same mechanism as C1 — folded to avoid pool-splitting); WMR/4pm fix (retired); CME margin hikes (no directional evidence); Comex first-notice squeezes (no literature); NBIM/GPIF scheduled FX flows (provenance UNKNOWN=FAIL).

## 3. Mechanism explanations

**C1 — S&P 500 index-addition forced benchmark flow.** Economic actor: passive funds and benchmarked managers mandated to hold S&P 500 constituents (trillions USD). Causal chain: S&P DJI announces an addition → mandated buyers *must* hold by the effective date → concentrated buying into a fixed float → because money-like substitutes for a specific firm are imperfect (downward-sloping demand), price rises and does not fully revert. Direction (predeclared): LONG additions only. Horizon (literature-pinned): announcement → effective-date close (days to ~2 weeks). Persistence: the mandated holding is permanent while the name stays in the index; arbitrage capital is capacity-constrained, so pressure is not instantly eliminated.

**C2 — Treasury auction concession / post-auction drift.** Actor: primary dealers constrained to bid at auctions. Chain: inventory risk → short/derisk before auction (yield concession) → unwind after → post-auction price drift. Direction/horizon: never pinned from verified literature → gates UNKNOWN.

**C3 — EIA crude inventory surprise → WTI.** Actor: physical/futures traders repricing supply. Chain: unexpected build/draw → immediate futures repricing within minutes. Direction: −surprise → +price (conditional on magnitude; literature documents asymmetric responses).

**C4 — EIA natural-gas storage surprise → NG.** Same transmission as C3 on a weekly schedule; reaction scales with surprise magnitude (threshold DOF).

**C5 — USDA WASDE surprise → corn/soy.** Actor: grain traders repricing S&D balance sheets. Chain: report surprise vs private consensus → intraday repricing. Direction conditional on proprietary-consensus surprise.

**C6 — PBOC CNY fixing surprise → CNH.** Actor: onshore policy rate-set vs market; offshore CNH reprices at 09:15 CST. Literature verified this session is cross-correlation/price-discovery class, not directional tradability.

**C7 — MOF Japan FX interventions → JPY.** Actor: Ministry of Finance/BoJ executing discretionary intervention. Chain: official USD/JPY flows move the rate. Direction = intervention direction per episode (regime-dependent: pre-2004 buy-USD vs 2022+ sell-USD/buy-JPY → not a single sign).

**C8 — OPEC/OPEC+ announcements → crude.** Actor: producer cartel coordinating supply. Chain: announcement content → expected-balance repricing. Verified literature documents announcement-type-dependent (heterogeneous) effects → no single unconditional sign.

**C9 — Treasury supply/refunding announcements.** Actor: Treasury issuance; dealers/investors demand term premium. Chain: larger supply → higher expected excess returns on long bonds (Greenwood–Vayanos). This is a *premium*, not an announcement-day directional rule; tradable construction requires a surprise vs proprietary consensus.

**C10 — Central-bank gold reserve flows → gold.** Actor: reserve managers diversifying. Chain: documented official-sector demand supports gold. But reserve data arrive monthly with lags/vintages; no verified literature establishes announcement→forward-return direction.

## 4. Literature evidence

Legend: [V] = verified this session (OpenAlex/Semantic Scholar/Wikipedia metadata, DOI + citation count); [C] = canonical, not verified this session — verify at any future gate.

- **C1:** Chang, Hong & Liskovich, *Regression Discontinuity and the Price Effects of Stock Market Indexing*, **RFS**, DOI 10.1093/rfs/hhu041, 362 cites [V] — Russell additions/deletions show directional price effects tied to mandated flows. Greenwood & Vayanos, *Bond Supply and Excess Bond Returns*, NBER w13806, 226 cites [V] (supply→premia lineage). Barberis–Shleifer–Wurgler comovement lineage [C]. Shleifer (1986, JF) [C]; Wurgler & Zhuravskaya (2002, JFE) [C]; Greenwood (2005, JFE) [C] — S&P 500 addition price pressure, partially permanent. **Post-2015:** Greenwood & Sammon working-paper and S&P DJI research on a declining-but-persistent index effect exist per project knowledge but were **NOT verified this session → gate UNKNOWN**.
- **C2:** no peer-reviewed directional auction-cycle anchor verified this session → UNKNOWN (cost anatomy independently marginal: bps-scale yield effects).
- **C3:** Bu, *Futures Markets Reaction to Crude Oil Inventory News Announcements: Asymmetric Return Response Patterns*, SSRN 3996860 (2021) [V] — working-paper class; "asymmetric" in title itself signals sign heterogeneity. Peer-reviewed anchor: UNKNOWN.
- **C4:** no verified anchor this session → literature UNKNOWN; provenance of consensus survey UNKNOWN=FAIL.
- **C5:** Isengildina-Massa et al., *The Impact of Situation and Outlook Information in Corn and Soybean Futures Markets: Evidence from WASDE Reports*, **J. Agr. & Applied Economics** (2008), 83 cites [V] — informational content documented; tradable surprise rule requires proprietary consensus.
- **C6:** RMB-fixing literature verified is correlation/price-discovery class (e.g., Ruan et al. 2019, *Physica A*, DOI 10.1016/j.physa.2019.01.110) [V] — prohibited conversion class.
- **C7:** Ito, *Is Foreign Exchange Intervention Effective? The Japanese Experiences in the 1990s*, NBER w8914, 102 cites [V]; Fatum & Hutchison [V existence] — mechanism real; N and single-sign fail regardless.
- **C8:** Loutia, Mellios & Andriosopoulos, *Do OPEC announcements influence oil prices?*, **Energy Policy** (2016), DOI 10.1016/j.enpol.2015.11.025, 79 cites [V] — effects heterogeneous by announcement type → no single sign.
- **C9:** Greenwood & Vayanos [V] — supply→premium documented; premium ≠ directional expectancy; surprise construction needs proprietary consensus → provenance FAIL.
- **C10:** IMF/WGC reserve-diversification documentation [C]; no verified announcement→forward-return directional study → UNKNOWN=FAIL.
## 5. Frequency / independence audit

| C | Genuine event unit | Raw N (indicative) | Independent N | Independence basis |
|---|---|---|---|---|
| C1 | One announced S&P 500 addition | ≳300 additions post-2000 (public per-component date-added records; e.g., ABNB 2023-09-18, SMCI 2024-03-18, TPL 2024-11-26, TKO 2025-03-24) | UNKNOWN — grouped quarterly/annual rebalances must be counted under a fixed rule before enumeration; no market data inspected | Distinct firm + distinct announcement; no horizon/bar splitting; deletions excluded |
| C2 | One auction (per tenor) | ~240/tenor/25y | UNKNOWN | Auction-cycle overlap within cycles |
| C3 | One weekly EIA report | ~1,500 | PASS-class | Non-overlapping weekly releases |
| C4 | One weekly EIA NG report | ~1,500 | PASS-class | Non-overlapping weekly releases |
| C5 | One monthly WASDE | ~300 | PASS-class | Non-overlapping monthly releases |
| C6 | One daily fixing | ~2,500 | PASS-class | Daily, non-overlapping |
| C7 | One intervention episode | ≈20–30 (1991–2024) | FAIL vs N_eff≥100 | Episodic, clustered |
| C8 | One ministerial announcement | ≈70–90 | FAIL vs 100/300 | 2–3 meetings/yr |
| C9 | One refunding statement | ~180 (quarterly, 25y) | PASS-class | Quarterly |
| C10 | One monthly reserve print | ~300 | UNKNOWN (vintage revisions) | Monthly, lagged |

No N was manufactured: UNKNOWN cells require document enumeration (C1) or vintage audit (C10) before any count is trusted.

## 6. Retail cost audit

| C | Expected gross effect | Retail cost estimate | Gross/cost | Verdict |
|---|---|---|---|---|
| C1 | Historical addition effect ~1–8% announcement→effective (per canonical papers; post-2015 magnitude UNVERIFIED) | US large-cap CFD: spread 1–4 bps + commission ~1–2 bps/side + slippage ~1–2 bps ⇒ ~4–10 bps RT | ≥10× if pre-2015 magnitudes; UNVERIFIED post-2015 → UNKNOWN | UNKNOWN |
| C2 | ~2–6 bps on 10Y yield around auction | CFD/futures RT ~1–3 bps | ~1–2× | FAIL |
| C3 | Median release-window move ~0.3–0.8% | WTI CFD spread ~0.05–0.10% + release slippage ~0.1–0.3% | ~1–2× | FAIL |
| C4 | ~1–2.5% on large surprises only (threshold needed) | NG CFD ~0.2–0.35% RT | ~2–4× on large subset | UNKNOWN (DOF-tainted) |
| C5 | ~0.5–2% on surprise releases | Corn/soy CFD ~0.1–0.2% RT | ~2–8× on subset | UNKNOWN |
| C6 | Median fixing-surprise moves small; large ones rare | CNH CFD spread wide (~0.03–0.06%) | <2× | FAIL |
| C7 | Per-episode moves large (~1–4%) | JPY CFD ~0.01–0.02% RT | ≫4× | PASS-anatomy only (N/sign FAIL) |
| C8 | 0–3% depending on announcement type | WTI CFD ~0.1–0.3% RT | Heterogeneous | UNKNOWN |
| C9 | Term-premium drift, slow | Futures/CFD RT small | Unknown | UNKNOWN |
| C10 | Monthly drift, small | Gold CFD ~0.03% RT | ≥4× plausible | UNKNOWN |

No candidate failed *solely* on cost except where marked; C2 and C3 fail cost explicitly (gross ≈ cost).

## 7. Provenance audit

- **C1 — PASS (anatomy).** Public, dated announcement/effective records verified (Wikipedia per-component "Date added" + "Historical components of the S&P 500"; S&P DJI press releases; day-level timestamps sufficient for a days-to-weeks horizon). Fields: ticker, announcement date, effective date. SHA256-able archive: feasible. Licensing: public facts; complete-coverage verification is a named verification item (V2).
- **C2 — UNKNOWN.** Auction dates public (TreasuryDirect), but effect/horizon literature unverified.
- **C3/C4/C5 — FAIL/UNKNOWN.** Surprise construction requires proprietary broker/Reuters/Bloomberg consensus surveys; historical vintages not publicly immutable → per governance: FAIL / UNKNOWN, not reconstructible-by-assumption.
- **C6 — UNKNOWN.** Fixings are public daily and archivable, but the tradable rule needs a magnitude threshold (DOF) and retail CNH economics fail.
- **C7 — UNKNOWN.** MOF intervention data published with multi-year lags; episode-level timestamps public post-hoc.
- **C8 — UNKNOWN.** Meeting dates public; announcement-type classification is researcher-imposed.
- **C9 — FAIL.** Consensus surprise proprietary.
- **C10 — UNKNOWN.** IMF IFS revisions/vintage policy; archiveability unproven.

## 8. DOF audit

| C | Discretionary choices | Classification |
|---|---|---|
| C1 | Family representative (S&P 500 vs Russell/MSCI): 1; construction (buy at post-announcement close, exit effective-date close): 1; exclusion of deletions (declared reduction): declared | 2 researcher-selected; sign, horizon, event definition literature-pinned → minimal |
| C2 | Tenor, horizon, sign | researcher-selected ×3 |
| C3 | Sign convention, magnitude filter | researcher-selected |
| C4 | Magnitude threshold | researcher-selected (fatal) |
| C5 | Crop choice, magnitude filter | researcher-selected |
| C6 | Magnitude threshold | researcher-selected (fatal) |
| C7 | Episode window (1991–2024 vs 2022+), sign regime | researcher-selected (fatal) |
| C8 | Announcement-type taxonomy | researcher-selected (fatal) |
| C9 | Surprise definition | researcher-selected (fatal) |
| C10 | Horizon/lag definition | researcher-selected |
## 9. Distinctness audit (C1 — the only candidate needing proof)

```text
New mechanism:        Mandated benchmark-flow price pressure at S&P 500
                      additions (announcement → effective date).
Underlying actor:     Passive index funds / benchmarked managers contractually
                      required to hold constituents.
New transmission:     Index-mandate → mechanical, scheduled, concentrated
                      buying of a specific name → price impact from
                      downward-sloping demand (imperfect substitutes),
                      partially permanent because the mandate persists.
Why not a retired family:
  - Not generic momentum: trade is event-anchored (announcements), not
    return autocorrelation; direction precedes any return pattern.
  - Not month/session mining: driven by irregular, firm-specific S&P
    announcements, not calendar cells.
  - Not bundled macro: no macro release; micro-structural flow.
  - Not DXY lead / tick-volume / VWAP-fix / carry / CIP / COT /
    risk-regime / real-yield / PPP: none involve mandated portfolio flows.
  - Not a renamed M1/EIA family: different asset class, actor, and
    transmission ("institutional benchmark flows" is an explicitly
    permitted discovery domain in the phase charter §5).
```

C3–C6, C10 are inventory/supply-signal or price-discovery conversions on instruments adjacent to retired families (M1 EIA inventory; price-discovery) — marked UNKNOWN/FAIL on distinctness or eliminated on other gates, so no retired mechanism is being rescued through any candidate.

## 10. Hard-gate matrix

Consolidated verdict (PASS/FAIL/UNKNOWN only; UNKNOWN = FAIL):

```text
C1  Causal PASS | Direction PASS | Horizon PASS | Post-2015 UNKNOWN |
    N UNKNOWN | Sign PASS | DOF PASS | Cost UNKNOWN | Data UNKNOWN |
    Provenance PASS | Distinct PASS            → FAIL (not a survivor)
C2  → FAIL          C3  → FAIL          C4  → FAIL          C5  → FAIL
C6  → FAIL          C7  → FAIL          C8  → FAIL          C9  → FAIL
C10 → FAIL
```

## 11. Recommended next action

**No acquisition review is recommended. Research remains PAUSED.**

If, and only if, governance explicitly authorizes a document-only verification pass (still: no market data, no backtest, no holdout), the two named items that could return C1 to this gate are:

- **V1 — Post-2015 effect-size literature verification:** obtain and record Greenwood & Sammon working paper(s) and S&P DJI index-effect research (2021–2025), with sample periods, post-2015 addition effect sizes, and horizon definitions; record citation fields per the §6 template.
- **V2 — Independent-observation enumeration:** from public archives only (S&P DJI press releases, historical-components records), enumerate S&P 500 addition announcements 2000–2025 with announced vs effective dates; fix the grouped-rebalance counting rule *before* counting; report Raw / Independent / N_eff.

Both are literature/document tasks. Until governance approves and completes them, C1 is NOT a survivor and nothing downstream (acquisition, preregistration, development, backtest, holdout, promotion) is authorized.

## 12. Governance attestation

```text
2026-H2 inspected?          NO
New data acquired?          NO
Backtest executed?          NO
Holdout inspected?          NO
Threshold search?           NO
Horizon search?             NO
Parameter optimization?     NO
Production changed?         NO
PromotionGate changed?      NO
Retired mechanism rescued?  NO
N manufactured?             NO
```

This phase consumed only public literature metadata (OpenAlex / Semantic Scholar / Wikipedia) and the repository's own docs. Repository deltas: this decision record only (`docs/MECHANISM_DISCOVERY_REPORT_2026-08-29.md`).

---

*Decision record only. No production change; nothing committed beyond this record.*
