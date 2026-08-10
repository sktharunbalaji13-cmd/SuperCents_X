# Sprint 21 — Evidence Ledger (RL01)

Status: **POPULATED + VERIFIED — Phase 2 complete 2026-08-10** (protocol §7–§9).
Template: `docs/Sprint21_EvidenceLedger_Template.md` (FROZEN 2026-08-10, §18.1).
Append-only: revisions are annotations, never edits. Raw PDFs stay untracked.
36 files accounted for (28 papers + 8 documentation files). All anchors verbatim from extracted PDF text; NOT-REPORTED where absent.
2026-08-10 correction pass (annotation): the initial draft anchors were compiled from explore-agent outputs and 28 claim rows were found paraphrased/fabricated; all claim rows were re-verified against pypdf-extracted text of the actual PDFs and rewritten where needed (BOS-01/02/03, SWING-01/02/03/04, CHOCH-02/03/04/05). Paper records for those files were corrected to the real titles. FVG/OB/LIQ/SMC rows were already direct-read verified.
2026-08-10 final consistency pass (annotation): §5 direction counts corrected (CHOCH pos 8→9, not-stated 3→2; Total pos 36→37, not-stated 17→16) to match the 64 claim rows; §7 Swing row completed with RL-BOS-02-C01/C02 and E-levels corrected to E1:3, E2:11, E3:4 (18 claims). RL-OB-01-C02 anchor carries "[R2]" as an editorial normalization of a corrupted glyph (U+0B36) in the pypdf-extracted text of 2112.02947; the raw extraction reads "the average [U+0B36] out of sample", so [R2] is an annotation for "r2", not verbatim PDF content.

---

## 1. Ledger conventions

- Append-only: revisions are annotations, never edits.
- Every row: exactly one evidence tag (§8 of the protocol), all mandatory fields, Gap = explicit value (never empty).
- Verbatim anchors required on every claim row (quote or §/page).
- Raw PDFs stay untracked; the ledger is plain markdown rows.
- Paper IDs follow RL-<topic>-<nn>; documentation files (READMEs) use RL-DOC-<nn> and carry Status NO-CLAIM.
- E-levels: E1 = directly tested on liquid FX (EURUSD/GBPJPY); E2 = adjacent market/regime; E3 = theory/simulation; E4 = anecdotal; E5 = unsupported (protocol §6).
- P-levels: P1 peer-reviewed empirical; P2 preprint empirical; P3 peer-reviewed theoretical; P4 practitioner; P5 unsupported (protocol §5).
- ED01 results count as E1 for the SuperCents_X population; UNKNOWN-family observations stay in the Appendix (RL-OBS-01), reported-not-weighed.

## 2. Paper-level records (28 papers)

### BOS — Break of Structure (3 papers)

| Field | Value |
|---|---|
| Paper ID | RL-BOS-01 |
| File | research paper/bos/2103.02331_Support_Resistance_Optimal_Stopping.pdf |
| Title | The Support and Resistance Line Method: An Analysis via Optimal Stopping (Henderson, Jacka, Liu, Maeda) |
| Topic | BOS |
| Year | 2021 (rev. 2025) |
| P-level | P2 |
| Venue/type | preprint (theoretical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent + direct verification |
| Claim rows | 2 |

| Field | Value |
|---|---|
| Paper ID | RL-BOS-02 |
| File | research paper/bos/1401.1888_Technical_Trading_Fuzzy_Models.pdf |
| Title | Technical Trading and Fuzzy Systems (Wang) |
| Topic | BOS |
| Year | 2015 |
| P-level | P3 |
| Venue/type | peer-reviewed (IEEE Trans. on Fuzzy Systems 23(4):1127-1141) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent + direct verification |
| Claim rows | 2 |

| Field | Value |
|---|---|
| Paper ID | RL-BOS-03 |
| File | research paper/bos/1110.5197_Memory_Effects_Technical_Trading.pdf |
| Title | Memory effects in stock price dynamics: evidences of technical trading (Garzarelli, Cristelli, Zaccaria, Pietronero) |
| Topic | BOS |
| Year | 2011 |
| P-level | P2 |
| Venue/type | preprint (empirical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent + direct verification |
| Claim rows | 2 |

### SWING — swing points (4 papers)

| Field | Value |
|---|---|
| Paper ID | RL-SWING-01 |
| File | research paper/swing/2605.01300_Visibility_Graphs_Technical_Analysis.pdf |
| Title | Visibility graphs can make money in financial markets (Rak) |
| Topic | SWING |
| Year | 2026 |
| P-level | P2 |
| Venue/type | preprint (empirical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent + direct verification |
| Claim rows | 3 |

| Field | Value |
|---|---|
| Paper ID | RL-SWING-02 |
| File | research paper/swing/2607.01550_Trend_Following_Microstructure.pdf |
| Title | Is Trend Still Your Friend? A Microstructural Account of the Demise of Short-Term Trend-Following (Kurth, Eisler, Rej, Bouchaud) |
| Topic | SWING |
| Year | 2026 |
| P-level | P2 |
| Venue/type | preprint (empirical); commercial affiliation (CFM) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent + direct verification |
| Claim rows | 3 |

| Field | Value |
|---|---|
| Paper ID | RL-SWING-03 |
| File | research paper/swing/2507.15876_Short_Long_Term_Trend_CTA_Replication.pdf |
| Title | Re-evaluating Short- and Long-Term Trend Factors in CTA Replication: A Bayesian Graphical Approach (Benhamou, Ohana, Etienne, Guez, Setrouk, Jacquot) |
| Topic | SWING |
| Year | 2025 |
| P-level | P2 |
| Venue/type | preprint (empirical); commercial affiliation (Ai For Alpha) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent + direct verification |
| Claim rows | 3 |

| Field | Value |
|---|---|
| Paper ID | RL-SWING-04 |
| File | research paper/swing/2605.04004_Structural_Limits_OHLCV_Intraday_MNQ.pdf |
| Title | Structural Limits of OHLCV-Based Intraday Signals in MNQ Futures: A Systematic Falsification Study (Mesfin) |
| Topic | SWING |
| Year | 2026 |
| P-level | P2 |
| Venue/type | preprint (empirical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent + direct verification |
| Claim rows | 3 |

### CHOCH — change-point / regime detection (5 papers)

| Field | Value |
|---|---|
| Paper ID | RL-CHOCH-01 |
| File | research paper/choch/1001.2549_Segmentation_Change_Point.pdf |
| Title | Segmentation algorithm for non-stationary compound Poisson processes, with an application to inventory time series of market members in a financial market (Tóth, Lillo, Farmer) |
| Topic | CHOCH |
| Year | 2010 |
| P-level | P1 |
| Venue/type | peer-reviewed (Eur. Phys. J. B) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent + direct verification |
| Claim rows | 2 |

| Field | Value |
|---|---|
| Paper ID | RL-CHOCH-02 |
| File | research paper/choch/2511.00190_DeepRL_Regime_Switching_Trading.pdf |
| Title | Deep reinforcement learning for optimal trading with partial information (Macrì, Jaimungal, Lillo) |
| Topic | CHOCH |
| Year | 2025 |
| P-level | P2 |
| Venue/type | preprint (empirical/simulation) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent + direct verification |
| Claim rows | 3 |

| Field | Value |
|---|---|
| Paper ID | RL-CHOCH-03 |
| File | research paper/choch/0705.0503_Change_Point_Telegraph_Process.pdf |
| Title | Change point estimation for the telegraph process observed at discrete times (De Gregorio, Iacus) |
| Topic | CHOCH |
| Year | 2007 |
| P-level | P2 |
| Venue/type | preprint (theoretical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent + direct verification |
| Claim rows | 2 |

| Field | Value |
|---|---|
| Paper ID | RL-CHOCH-04 |
| File | research paper/choch/2605.29541_Change_Point_Weibull_Copula.pdf |
| Title | Change-point estimation for Weibull time series with copula-based Markov models (Sun, Huang, Huang, Chiu, Ning) |
| Topic | CHOCH |
| Year | 2026 |
| P-level | P2 |
| Venue/type | preprint (empirical/theoretical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent + direct verification |
| Claim rows | 2 |

| Field | Value |
|---|---|
| Paper ID | RL-CHOCH-05 |
| File | research paper/choch/2204.00872_Change_Point_Calibration_Window.pdf |
| Title | Calibration window selection based on change-point detection for forecasting electricity prices (Nasiadka, Nitka, Weron) |
| Topic | CHOCH |
| Year | 2022 |
| P-level | P2 |
| Venue/type | preprint (empirical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent + direct verification |
| Claim rows | 2 |

### OB — order block / order flow (5 papers)

| Field | Value |
|---|---|
| Paper ID | RL-OB-01 |
| File | research paper/ob/2112.02947_Order_Flow_Imbalance.pdf |
| Title | The Price Impact of Generalized Order Flow Imbalance |
| Topic | OB |
| Year | 2021 |
| P-level | P2 |
| Venue/type | preprint (empirical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, direct read (pypdf extraction) |
| Claim rows | 3 |

| Field | Value |
|---|---|
| Paper ID | RL-OB-02 |
| File | research paper/ob/2510.08085_Limit_Order_Book_Hawkes_Simulator.pdf |
| Title | A Deterministic Limit Order Book Simulator with Hawkes-Driven Order Flow |
| Topic | OB |
| Year | 2025 |
| P-level | P2 |
| Venue/type | preprint (empirical/simulation) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent + direct verification |
| Claim rows | 2 |

| Field | Value |
|---|---|
| Paper ID | RL-OB-03 |
| File | research paper/ob/2601.23172_Order_Flow_Market_Impact_Volatility.pdf |
| Title | A unified theory of order flow, market impact, and volatility |
| Topic | OB |
| Year | 2026 |
| P-level | P2 |
| Venue/type | preprint (theoretical/empirical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent + direct verification |
| Claim rows | 2 |

| Field | Value |
|---|---|
| Paper ID | RL-OB-04 |
| File | research paper/ob/2607.04280_Order_Splitting_Square_Root_Law.pdf |
| Title | Order Splitting and the Square-Root Law of Market Impact |
| Topic | OB |
| Year | 2026 |
| P-level | P2 |
| Venue/type | preprint (empirical/simulation) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent + direct verification |
| Claim rows | 2 |

| Field | Value |
|---|---|
| Paper ID | RL-OB-05 |
| File | research paper/ob/2608.00885_Optimal_Trading_Microstructure_MeanReversion.pdf |
| Title | Optimal Trading of Microstructure Mean Reversion |
| Topic | OB |
| Year | 2026 |
| P-level | P2 |
| Venue/type | preprint (theoretical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent + direct verification |
| Claim rows | 2 |

### FVG — fair value gap / imbalance (3 papers)

| Field | Value |
|---|---|
| Paper ID | RL-FVG-01 |
| File | research paper/fvg/1405.1247_Price_Gaps_Limit_Order_Books.pdf |
| Title | Stylized facts of price gaps in limit order books: Evidence from Chinese stocks |
| Topic | FVG |
| Year | 2014 |
| P-level | P2 |
| Venue/type | preprint (empirical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, direct read (pypdf extraction) |
| Claim rows | 3 |

| Field | Value |
|---|---|
| Paper ID | RL-FVG-02 |
| File | research paper/fvg/1201.5448_Immediate_Price_Impacts.pdf |
| Title | Determinants of immediate price impacts at the trade level in an emerging order-driven market |
| Topic | FVG |
| Year | 2012 |
| P-level | P2 |
| Venue/type | preprint (empirical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, direct read (pypdf extraction) |
| Claim rows | 3 |

| Field | Value |
|---|---|
| Paper ID | RL-FVG-03 |
| File | research paper/fvg/2605.11423_Volatility_Volume_Gap_Regime_MNQ.pdf |
| Title | A Validated Volatility-Volume-Gap Classifier for Regime Identification in MNQ Intraday Data |
| Topic | FVG |
| Year | 2026 |
| P-level | P2 |
| Venue/type | preprint (empirical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, direct read (pypdf extraction) |
| Claim rows | 2 |

### LIQUIDITY — market liquidity (4 papers)

| Field | Value |
|---|---|
| Paper ID | RL-LIQ-01 |
| File | research paper/liquidity/1112.6169_Measuring_Market_Liquidity_Survey.pdf |
| Title | Measuring market liquidity: An introductory survey |
| Topic | LIQUIDITY |
| Year | 2011 (rev. 2024) |
| P-level | P4 |
| Venue/type | survey (practitioner-oriented) |
| Status | INCLUDED |
| Read pass | 2026-08-10, direct read (pypdf extraction) |
| Claim rows | 2 |

| Field | Value |
|---|---|
| Paper ID | RL-LIQ-02 |
| File | research paper/liquidity/1309.5235_Optimal_Liquidity_Provision.pdf |
| Title | Optimal Liquidity Provision (Kühn, Muhle-Karbe) |
| Topic | LIQUIDITY |
| Year | 2013 (rev. 2018) |
| P-level | P2 |
| Venue/type | preprint (theoretical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, direct read (pypdf extraction) |
| Claim rows | 2 |

| Field | Value |
|---|---|
| Paper ID | RL-LIQ-03 |
| File | research paper/liquidity/2010.13038_HFT_Artificial_Market_Liquidity.pdf |
| Title | Analysis of the Impact of High-Frequency Trading on Artificial Market Liquidity |
| Topic | LIQUIDITY |
| Year | 2020 |
| P-level | P1 |
| Venue/type | peer-reviewed (IEEE Trans. Computational Social Systems) |
| Status | INCLUDED |
| Read pass | 2026-08-10, direct read (pypdf extraction) |
| Claim rows | 2 |

| Field | Value |
|---|---|
| Paper ID | RL-LIQ-04 |
| File | research paper/liquidity/2310.09273_Liquidity_Trends_Detection.pdf |
| Title | Uncovering Market Disorder and Liquidity Trends Detection |
| Topic | LIQUIDITY |
| Year | 2023 |
| P-level | P2 |
| Venue/type | preprint (empirical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, direct read (pypdf extraction) |
| Claim rows | 2 |

### SMC — umbrella microstructure (4 papers)

| Field | Value |
|---|---|
| Paper ID | RL-SMC-01 |
| File | research paper/smc/1108.1632_Why_Is_Order_Flow_Persistent.pdf |
| Title | Why is equity order flow so persistent? (Tóth, Palit, Lillo, Farmer) |
| Topic | SMC |
| Year | 2011 |
| P-level | P1 |
| Venue/type | peer-reviewed (J. Financ. Econ.) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent |
| Claim rows | 2 |

| Field | Value |
|---|---|
| Paper ID | RL-SMC-02 |
| File | research paper/smc/1610.00261_Adverse_Selection_Limit_Order_Latency.pdf |
| Title | Limit Order Strategic Placement with Adverse Selection Risk and the Role of Latency (Lehalle, Mounjid) |
| Topic | SMC |
| Year | 2016 |
| P-level | P2 |
| Venue/type | preprint (theoretical/empirical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent |
| Claim rows | 2 |

| Field | Value |
|---|---|
| Paper ID | RL-SMC-03 |
| File | research paper/smc/2107.12094_Liquidity_Provision_Adverse_Selection.pdf |
| Title | Liquidity Provision with Adverse Selection and Inventory Costs (Herdegen, Muhle-Karbe, Stebegg) |
| Topic | SMC |
| Year | 2021 |
| P-level | P2 |
| Venue/type | preprint (theoretical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent |
| Claim rows | 2 |

| Field | Value |
|---|---|
| Paper ID | RL-SMC-04 |
| File | research paper/smc/2608.04373_Public_Trader_Identity_Adverse_Selection.pdf |
| Title | Public Trader Identity: Adverse Selection and Return Predictability (Zhai) |
| Topic | SMC |
| Year | 2026 |
| P-level | P2 |
| Venue/type | preprint (empirical) |
| Status | INCLUDED |
| Read pass | 2026-08-10, explore-agent |
| Claim rows | 2 |

## 2b. Documentation-file records (READMEs — 8 files, Status NO-CLAIM)

| Field | Value |
|---|---|
| Paper ID | RL-DOC-01 |
| File | research paper/README.md |
| Title | Folder map — retail structure to academic equivalent |
| Topic | — (root) |
| Status | NO-CLAIM — documentation file; states 28 papers, folder map, open-access sourcing; no empirical claim |
| Claim rows | 0 |

| Field | Value |
|---|---|
| Paper ID | RL-DOC-02 |
| File | research paper/bos/README.md |
| Title | BOS folder documentation |
| Topic | BOS |
| Status | NO-CLAIM — documentation file; no empirical claim |
| Claim rows | 0 |

| Field | Value |
|---|---|
| Paper ID | RL-DOC-03 |
| File | research paper/swing/README.md |
| Title | SWING folder documentation |
| Topic | SWING |
| Status | NO-CLAIM — documentation file; no empirical claim |
| Claim rows | 0 |

| Field | Value |
|---|---|
| Paper ID | RL-DOC-04 |
| File | research paper/choch/README.md |
| Title | CHOCH folder documentation |
| Topic | CHOCH |
| Status | NO-CLAIM — documentation file; no empirical claim |
| Claim rows | 0 |

| Field | Value |
|---|---|
| Paper ID | RL-DOC-05 |
| File | research paper/ob/README.md |
| Title | OB folder documentation |
| Topic | OB |
| Status | NO-CLAIM — documentation file; no empirical claim |
| Claim rows | 0 |

| Field | Value |
|---|---|
| Paper ID | RL-DOC-06 |
| File | research paper/fvg/README.md |
| Title | FVG folder documentation |
| Topic | FVG |
| Status | NO-CLAIM — documentation file; no empirical claim |
| Claim rows | 0 |

| Field | Value |
|---|---|
| Paper ID | RL-DOC-07 |
| File | research paper/liquidity/README.md |
| Title | LIQUIDITY folder documentation |
| Topic | LIQUIDITY |
| Status | NO-CLAIM — documentation file; no empirical claim |
| Claim rows | 0 |

| Field | Value |
|---|---|
| Paper ID | RL-DOC-08 |
| File | research paper/smc/README.md |
| Title | SMC folder documentation |
| Topic | SMC |
| Status | NO-CLAIM — documentation file; no empirical claim |
| Claim rows | 0 |

## 3. Claim-level records

### RL-BOS-01 (2103.02331) — The Support and Resistance Line Method (Optimal Stopping)

| Field | Value |
|---|---|
| Claim ID | RL-BOS-01-C01 |
| Paper ID | RL-BOS-01 |
| Verbatim anchor | "We study a mathematical model motivated by the support/resistance line method in technical analysis where the underlying stock price transitions between three states of nature in a path-dependent manner." (§ Abstract) |
| Claim (falsifiable) | If the S/R line method is modeled as price transitions between three states in a path-dependent manner, then support/resistance structure is a state-transition phenomenon, not a random artifact. |
| Evidence tag | THEORETICAL |
| E-level | E3 |
| Population tested | NOT-REPORTED (theoretical model) |
| Direction | not-stated |
| SuperCents_X assumption | StructuralPivotEngine swing detection; BOS continuation detector |
| Gap | Model state-space (three states, path-dependent) vs engine's binary structure states (S/R break yes/no) — transfer of the existence mechanism, not of state definitions |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | S/R is modeled as path-dependent transitions between three price states. |
| Reviewer interpretation | Theoretical grounding that S/R structure can be formalized as state transitions; provides no parameters or FX evidence. |

| Field | Value |
|---|---|
| Claim ID | RL-BOS-01-C02 |
| Paper ID | RL-BOS-01 |
| Verbatim anchor | "for a range of utilities, we prove that the best time to buy and sell the stock are obtained by solving free boundary problems corresponding to two linked optimal stopping problems." (§ Abstract) |
| Claim (falsifiable) | If optimal buy/sell times are free-boundary problems at linked S/R boundaries, then S/R boundaries are decision-relevant for entry/exit timing. |
| Evidence tag | THEORETICAL |
| E-level | E3 |
| Population tested | NOT-REPORTED (theoretical model) |
| Direction | positive (boundaries are decision-relevant) |
| SuperCents_X assumption | S/R levels as entry/exit decision points; 2R exits |
| Gap | The model's linked buy/sell boundaries presume path-dependent state knowledge the engine derives from OHLC pivots — construct transfer, no FX evidence |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Optimal buy/sell times are free-boundary problems at two linked S/R boundaries. |
| Reviewer interpretation | S/R boundaries as decision-relevant structure is theoretically grounded; no parameters or FX population evidence provided. |

### RL-BOS-02 (1401.1888) — Technical Trading and Fuzzy Systems (IEEE 2015)

| Field | Value |
|---|---|
| Claim ID | RL-BOS-02-C01 |
| Paper ID | RL-BOS-02 |
| Verbatim anchor | "we use fuzzy systems theory to convert the technical trading rules commonly used by stock practitioners into excess demand functions which are then used to drive the price dynamics" (§ Abstract) |
| Claim (falsifiable) | If technical trading rules (incl. support/resistance, trend-line, band/stop, volume rules) are representable as excess demand functions, then rule content is formally expressible as a deterministic price-driving mechanism. |
| Evidence tag | THEORETICAL |
| E-level | E3 |
| Population tested | NOT-REPORTED (model construction; no market data) |
| Direction | not-stated |
| SuperCents_X assumption | Detector rules (BOS/FVG/OB/LIQ) are well-defined functionals of price/volume |
| Gap | Representation theory only; no tradability claim, no market data, no transaction costs |
| Hypothesis | NONE |
| Flags | WARNING-simulation-only |
| Reviewer paraphrase | Fuzzy systems convert technical trading rules into excess demand functions driving price dynamics. |
| Reviewer interpretation | Shows technical rules can be formalized as price-driving mechanisms; no evidence of predictive edge. |

| Field | Value |
|---|---|
| Claim ID | RL-BOS-02-C02 |
| Paper ID | RL-BOS-02 |
| Verbatim anchor | "Simulation results show that the price dynamics driven by these technical trading rules are complex and chaotic, and some common phenomena in real stock prices such as jumps, trending and self-fulfilling appear naturally." (§ Abstract) |
| Claim (falsifiable) | If rule-driven simulated price dynamics reproduce jumps, trending and self-fulfilling phenomena, then real-market phenomena assumed by the engine (breakouts, self-reinforcing levels) can arise from rule-following behavior alone. |
| Evidence tag | EMPIRICAL |
| E-level | E3 |
| Population tested | simulated market (fuzzy-system price dynamics; period NOT-REPORTED) |
| Direction | positive (mechanism realism) |
| SuperCents_X assumption | Structure states (S/R, zones) are emergent from price action, not imposed |
| Gap | Simulation-only; no FX test, no tradability claim, no costs; confirms mechanism existence, not edge |
| Hypothesis | NONE |
| Flags | WARNING-simulation-only |
| Reviewer paraphrase | Rule-driven price dynamics are complex/chaotic; jumps, trending and self-fulfilling behavior appear naturally. |
| Reviewer interpretation | Mechanism-level support that structure phenomena can emerge from rules; does not establish any predictive edge on FX. |

### RL-BOS-03 (1110.5197) — Memory Effects in Stock Price Dynamics (S/R as Self-Fulfilling)

| Field | Value |
|---|---|
| Claim ID | RL-BOS-03-C01 |
| Paper ID | RL-BOS-03 |
| Verbatim anchor | "we show that memory effects in the price dynamics are associated to these selected values. In fact we show that prices more likely re-bounce than cross these values." (§ Abstract) |
| Claim (falsifiable) | If prices more likely re-bounce than cross detected support/resistance values, then BOS-style breakout continuation is the rarer event — S/R acts as a barrier, not a launch point. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | stock price time series (equities; market/period NOT-REPORTED) |
| Direction | negative (for BOS continuation premise) |
| SuperCents_X assumption | BOS continuation detector: break of structure → trend continuation; floor BOS 0.35 |
| Gap | Re-bounce > cross directly challenges break-continuation; consistent with ED01-B (E1, no distinct BOS-family edge in SCX population); stock data, not FX |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Prices more likely re-bounce than cross detected S/R values. |
| Reviewer interpretation | Empirical basis for expecting S/R to repel rather than launch — favors reversal over BOS-continuation at S/R levels. |

| Field | Value |
|---|---|
| Claim ID | RL-BOS-03-C02 |
| Paper ID | RL-BOS-03 |
| Verbatim anchor | "the more the number of bounces on these values increases, the more the probability of bouncing on them is high" (§ 1, Introduction) |
| Claim (falsifiable) | If previously-held S/R levels become more likely to hold again (self-reinforcement), then S/R strength is endogenous and self-fulfilling. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | stock price time series (equities; market/period NOT-REPORTED) |
| Direction | positive (level persistence / self-fulfilling prophecy) |
| SuperCents_X assumption | BOS requires breaking previously-validated structure levels; floor 0.35 |
| Gap | Self-reinforcing levels imply breaks of validated S/R are rare and get rarer — tension with BOS-continuation premise; ED01-B null on FX; not FX data |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | More bounces on a value → higher probability of bouncing on it again. |
| Reviewer interpretation | Quantitative evidence for the self-fulfilling prophecy; supports treating validated levels as repellers — consistent with CHOCH-reversal, not BOS-continuation. |

### RL-SWING-01 (2605.01300) — Visibility Graphs Can Make Money (VGRSI, Rak)

| Field | Value |
|---|---|
| Claim ID | RL-SWING-01-C01 |
| Paper ID | RL-SWING-01 |
| Verbatim anchor | "The strategy based on VGRSI signals generated a profit of USD 146,000 for DJI30, USD 69,000 for EUR/USD, and USD 125,000 for XAU/USD." (§ Abstract) |
| Claim (falsifiable) | If visibility-graph-derived swing signals (VGRSI) are profitable on EUR/USD over 2024–2025, then swing-level geometric structure carries predictive content on liquid FX. |
| Evidence tag | EMPIRICAL |
| E-level | E1 |
| Population tested | EUR/USD, DJI30, XAU/USD, 2024–2025 (503 trading days), fixed USD 1,000 investment per trade |
| Direction | positive (profitability on EUR/USD) |
| SuperCents_X assumption | StructuralPivotEngine swing hierarchy; swing significance for admission |
| Gap | Engine uses OHLC swing pivots, not visibility-graph features; single paper, short window (503 days), 30-day rolling optimization → reproduction required |
| Hypothesis | If swing-significant pivots on EURUSD H1 carry forward information, then swing-gated entries beat non-gated entries vs 2.0R (pre-registration candidate) |
| Flags | WARNING-REPRO-PENDING |
| Reviewer paraphrase | VGRSI signals generated USD 146k (DJI30), 69k (EUR/USD), 125k (XAU/USD). |
| Reviewer interpretation | Rare E1 literature touch-point for swing structure; profit figures are per-trade-USD fixed sizing, 2024–2025 only — directional, not a quantified edge. |

| Field | Value |
|---|---|
| Claim ID | RL-SWING-01-C02 |
| Paper ID | RL-SWING-01 |
| Verbatim anchor | "the strategy generated substantial profits while maintaining a moderate drawdown (10–18% relative to a portfolio value of USD 10,000), a relatively low trading intensity (3.3–4.8 trades per day) and high Sharpe ratio values (2.55–3.6)." (§ Abstract) |
| Claim (falsifiable) | If a swing-signal strategy achieves Sharpe 2.55–3.6 at 3.3–4.8 trades/day with 10–18% drawdown, then moderate-frequency swing strategies can be risk-efficient. |
| Evidence tag | EMPIRICAL |
| E-level | E1 |
| Population tested | EUR/USD, DJI30, XAU/USD, 2024–2025 (503 days) |
| Direction | positive (risk-adjusted performance) |
| SuperCents_X assumption | Risk sizing by fixed R multiples; moderate trade frequency |
| Gap | Sharpe computed on USD 10k portfolio basis with USD 1k/trade; no spread/slippage detail reported; rolling 30-day optimization window inflates OOS fit risk |
| Hypothesis | NONE |
| Flags | WARNING-REPRO-PENDING |
| Reviewer paraphrase | Moderate drawdown (10–18%), low intensity (3.3–4.8 trades/day), Sharpe 2.55–3.6. |
| Reviewer interpretation | Suggests swing strategies can be risk-efficient in principle; must be reproduced on SCX data before any weight. |

| Field | Value |
|---|---|
| Claim ID | RL-SWING-01-C03 |
| Paper ID | RL-SWING-01 |
| Verbatim anchor | "The performance of the indicator was evaluated using an automated trading strategy based on a 30-day optimisation window and a 7-day test window" (§ Abstract) |
| Claim (falsifiable) | If VGRSI profitability depends on a rolling 30-day optimization window, then fixed-parameter swing strategies are unlikely to match its reported performance. |
| Evidence tag | EMPIRICAL |
| E-level | E1 |
| Population tested | EUR/USD, DJI30, XAU/USD, 2024–2025 (503 days), walk-forward design |
| Direction | not-stated (design dependency) |
| SuperCents_X assumption | Fixed parameter sets (floors, B8 weights, 2.0R) frozen per sprint |
| Gap | Engine has no rolling re-optimization loop; paper's edge may be optimization-window-dependent, not structural |
| Hypothesis | NONE |
| Flags | WARNING-REPRO-PENDING |
| Reviewer paraphrase | VGRSI was evaluated with a 30-day optimization / 7-day test walk-forward. |
| Reviewer interpretation | The design itself is a caveat: reported edge could stem from frequent re-optimization; conflicts with the fixed-policy engineering approach. |

### RL-SWING-02 (2607.01550) — Is Trend Still Your Friend? (Demise of Short-Term Trend-Following)

| Field | Value |
|---|---|
| Claim ID | RL-SWING-02-C01 |
| Paper ID | RL-SWING-02 |
| Verbatim anchor | "Systematic trend following has, on average, been profitable for at least two centuries; yet since approximately 2009, short-term trends have ceased to deliver reliable returns." (§ Abstract) |
| Claim (falsifiable) | If short-term trend profitability broke down after ~2009 while long-term survived, then short-horizon trend edge is era-dependent. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | cross-section of ~100 liquid futures contracts 1995–2025 + industry CTA proxy |
| Direction | negative (short-term trend decay) |
| SuperCents_X assumption | M15/H1 short-horizon trend-continuation signals (swing/BOS) maintain edge |
| Gap | Futures universe, not FX; M15/H1 FX horizon untested; post-2009 era includes the SCX live window (2024–2026) |
| Hypothesis | NONE |
| Flags | REGIME-AGE, COMMERCIAL (CFM affiliation) |
| Reviewer paraphrase | Short-term trends ceased to deliver reliable returns since ~2009; long-term trend following stayed profitable. |
| Reviewer interpretation | Directly relevant caveat: the live SCX era (2024–2026) is post-break for short-term trend edge. |

| Field | Value |
|---|---|
| Claim ID | RL-SWING-02-C02 |
| Paper ID | RL-SWING-02 |
| Verbatim anchor | "the cross-sectional variable distinguishing degraded from surviving trends is the volatility-normalised tick size: post-2008 trend PnL has collapsed on small-tick contracts across all signal horizons, while remaining essentially intact on large-tick contracts." (§ Abstract) |
| Claim (falsifiable) | If volatility-normalized tick size — not asset class or liquidity — separates degraded from surviving trends, then trend edge depends on execution granularity. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | ~100 liquid futures contracts 1995–2025 (cross-section) |
| Direction | not-stated (mechanism attribution) |
| SuperCents_X assumption | Trend detection identical across pairs; spread modeled in telemetry |
| Gap | FX tick-size regimes differ from futures; the paper's four candidate explanations (capacity, electronification, CTA-order-flow interaction, microstructure) were tested — first three fail |
| Hypothesis | NONE |
| Flags | COMMERCIAL (CFM affiliation) |
| Reviewer paraphrase | Tick size (vol-normalized) distinguishes degraded from surviving trends; small-tick contracts collapsed post-2008. |
| Reviewer interpretation | Explains decay mechanistically (impact/execution granularity), which the engine cannot observe from OHLCV; caution for cost-heavy instruments. |

| Field | Value |
|---|---|
| Claim ID | RL-SWING-02-C03 |
| Paper ID | RL-SWING-02 |
| Verbatim anchor | "Trend signals trigger directional trades, whose market impact reinforces the very price moves that generated the signal. The profitability and the persistence of trend are therefore both sustained by the same impact channel." (§ Abstract) |
| Claim (falsifiable) | If trend profitability is sustained by a self-fulfilling impact loop, then trend edge is fragile to changes in that channel (crowding, electronification). |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | ~100 liquid futures contracts 1995–2025 |
| Direction | negative (fragility of the sustaining channel) |
| SuperCents_X assumption | Trend-continuation signals keep working across regimes |
| Gap | Loop is market-wide (crowding channel); engine has no flow/impact observation; implies era-conditioning matters |
| Hypothesis | NONE |
| Flags | REGIME-AGE, COMMERCIAL |
| Reviewer paraphrase | Trend profitability and persistence are sustained by a self-reinforcing market-impact loop. |
| Reviewer interpretation | Supports the earlier ED01-C/E interpretation that trend edge can disappear when its sustaining channel changes. |

### RL-SWING-03 (2507.15876) — Short- and Long-Term Trend Factors in CTA Replication (Bayesian)

| Field | Value |
|---|---|
| Claim ID | RL-SWING-03-C01 |
| Paper ID | RL-SWING-03 |
| Verbatim anchor | "This paper adds to the debate by (i) dynamically decomposing CTA returns into short-term trend, long-term trend and market beta factors using a Bayesian graphical model, and (ii) showing how the blend of horizons shapes the strategy's risk-adjusted performance." (§ Abstract) |
| Claim (falsifiable) | If CTA returns decompose into short-term trend, long-term trend and market beta, and the horizon blend shapes risk-adjusted performance, then the horizon mix itself is a performance determinant. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | CTA/futures universe (period NOT-REPORTED) |
| Direction | positive (horizon blend matters) |
| SuperCents_X assumption | Single swing horizon per detector; H1 and M15 treated independently |
| Gap | Engine has no dual-horizon combination of swing/momentum; paper implies multi-horizon blending may be a feature |
| Hypothesis | NONE |
| Flags | COMMERCIAL (Ai For Alpha affiliation) |
| Reviewer paraphrase | CTA returns are dynamically decomposed into short-term trend, long-term trend and market beta; the horizon blend shapes risk-adjusted performance. |
| Reviewer interpretation | Supports considering H1+M15 as a blended structure rather than independent detectors; no FX evidence. |

| Field | Value |
|---|---|
| Claim ID | RL-SWING-03-C02 |
| Paper ID | RL-SWING-03 |
| Verbatim anchor | "Despite a large body of work on trend following, the relative merits and interactions of short- versus long-term trend systems remain controversial." (§ Abstract) |
| Claim (falsifiable) | If the relative merits of short- vs long-term trend systems are unresolved in the literature, then no horizon choice is settled science. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | literature synthesis (CTA/futures) |
| Direction | null (controversy) |
| SuperCents_X assumption | Fixed horizon choices (M15/H1) for trend detection |
| Gap | Literature split means horizon choice is not evidence-backed; ED01-E tests only fixed-R tiers, not horizons |
| Hypothesis | NONE |
| Flags | COMMERCIAL |
| Reviewer paraphrase | Relative merits and interactions of short- vs long-term trend systems remain controversial. |
| Reviewer interpretation | Horizon choice is unresolved in the literature; any H1/M15 claim needs SCX-specific evidence. |

| Field | Value |
|---|---|
| Claim ID | RL-SWING-03-C03 |
| Paper ID | RL-SWING-03 |
| Verbatim anchor | "Whereas (Jegadeesh et al., 2022) highlight the fragility of ultra-short signals, and Clenow (2023) advocates for very short term trends." (§ 1, Introduction) |
| Claim (falsifiable) | If ultra-short signals are fragile per one line of evidence and advocated by another, then ultra-short (M15) trend signals are an open question with conflicting evidence. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | literature review (academic + practitioner) |
| Direction | null (conflicting) |
| SuperCents_X assumption | M15 trend-continuation signals carry edge |
| Gap | Direct conflict between sources cited by the paper itself; no resolution offered; engine has no M15-specific evidence |
| Hypothesis | NONE |
| Flags | COMMERCIAL |
| Reviewer paraphrase | Jegadeesh et al. (2022) flag ultra-short signal fragility; Clenow (2023) advocates very short-term trends. |
| Reviewer interpretation | M15-horizon trend claims are contested; consistent with the split-positive/split-negative picture in RL-CONFLICT-01. |

### RL-SWING-04 (2605.04004) — Structural Limits of OHLCV-Based Intraday Signals (MNQ)

| Field | Value |
|---|---|
| Claim ID | RL-SWING-04-C01 |
| Paper ID | RL-SWING-04 |
| Verbatim anchor | "Every signal was held to the same standard: a T-statistic of at least 2.0 on out-of-sample walk-forward results, a minimum of 30 trades, a positive net return after a fixed two-point round-trip friction cost, and consistent performance across all tested years. Nothing passed." (§ Abstract) |
| Claim (falsifiable) | If no OHLCV intraday momentum signal family passes cost-aware statistical gates on MNQ, then OHLCV-only engines on similar markets face structural signal limits. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | Micro E-Mini Nasdaq 100 (MNQ), 947 days of 5-minute bars, 2021–2025, 14 signal families |
| Direction | null (nothing passed) |
| SuperCents_X assumption | OHLCV-only data pipeline for all detectors |
| Gap | MNQ futures, not FX; gates mirror ED01 gates (t ≥ 2.0, min trades, net of friction, year stability) |
| Hypothesis | NONE |
| Flags | WARNING-data-limit |
| Reviewer paraphrase | Fourteen signal families tested on MNQ 5-min bars 2021–2025; nothing passed the cost-aware gates. |
| Reviewer interpretation | Strong methodological corroboration that OHLCV signal discovery requires the same gate discipline the project already applies (ED01). |

| Field | Value |
|---|---|
| Claim ID | RL-SWING-04-C02 |
| Paper ID | RL-SWING-04 |
| Verbatim anchor | "The main finding is a gross edge ceiling. Across all fourteen signal families, the maximum achievable gross return before friction costs is roughly 0.07 to 1.50 points per trade. The friction costs alone are 2.0 points." (§ Abstract) |
| Claim (falsifiable) | If OHLCV intraday gross edges (0.07–1.50 pts) are below friction costs (2.0 pts), then cost-adjusted evaluation is the binding constraint on signal utility. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | MNQ 5-minute bars, 947 days, 2021–2025 |
| Direction | null (edge ceiling below costs) |
| SuperCents_X assumption | Backtest includes spread/slippage telemetry |
| Gap | FX friction is lower than 2-pt MNQ friction but the ceiling/cost ratio logic transfers; not FX data |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Gross edges cap at 0.07–1.50 pts/trade while friction is 2.0 pts — every family fails on cost grounds. |
| Reviewer interpretation | Edge must exceed realistic costs; consistent with ED01-E finding that no tier beat 2.0R net of costs. |

| Field | Value |
|---|---|
| Claim ID | RL-SWING-04-C03 |
| Paper ID | RL-SWING-04 |
| Verbatim anchor | "One result almost made it: gap continuation short produced a T-statistic of 3.23 and a mean net return of 14.52 points. But it fired only 22 times over three years. That is not enough data to know if it is a real edge or just a run of good luck." (§ Abstract) |
| Claim (falsifiable) | If the strongest OHLCV signal fails only on sample size (22 trades/3y), then minimum-sample constraints — not signal discovery — are the binding gate. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | MNQ 5-minute bars, 947 days, 2021–2025 |
| Direction | null (sample-size gate) |
| SuperCents_X assumption | ED01 gating (gates 1–5 incl. n constraints) on all decisions |
| Gap | None — mirrors the project's n-constraint discipline (e.g. ED01-D n=607; GBPJPY n=23 n-constrained) |
| Hypothesis | NONE |
| Flags | WARNING-sample-size |
| Reviewer paraphrase | Gap continuation short (T=3.23, +14.52 pts) fired only 22 times in three years — insufficient data. |
| Reviewer interpretation | Strong methodological corroboration: a high-t edge with tiny n is treated as unproven — exactly the ED01 rule. |

### RL-CHOCH-01 (1001.2549) — Segmentation / Change-Point (EPJ B)

| Field | Value |
|---|---|
| Claim ID | RL-CHOCH-01-C01 |
| Paper ID | RL-CHOCH-01 |
| Verbatim anchor | "The segmentation algorithm is a non parametric statistical method able to identify the regimes (patches) of a time series." (§ Abstract) |
| Claim (falsifiable) | If a non-parametric segmentation method can identify regimes in a time series, then regime switching is detectable from series structure alone (no model parameters assumed). |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | inventory time series of market members, London Stock Exchange (period NOT-REPORTED); synthetic compound-Poisson regimes |
| Direction | positive (regime detection feasible) |
| SuperCents_X assumption | CHOCH detector = reversal on structural change; no parametric regime model |
| Gap | Paper segments inventory series, not price series; CHOCH is a price-pattern reversal — population and construct transfer |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Non-parametric segmentation identifies regime patches in a time series. |
| Reviewer interpretation | Feasibility evidence that regime structure is detectable without model parameters; applied to inventory, not prices; no FX tradability claim. |

| Field | Value |
|---|---|
| Claim ID | RL-CHOCH-01-C02 |
| Paper ID | RL-CHOCH-01 |
| Verbatim anchor | "we observe that our method finds almost three times more patches than the original one." (§ Abstract) |
| Claim (falsifiable) | If algorithm choice changes segmentation granularity by ~3x on real data, then the number of detected regimes is method-dependent, not data-intrinsic. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | inventory time series of market members, LSE (period NOT-REPORTED) |
| Direction | not-stated (methodological) |
| SuperCents_X assumption | CHOCH fires on structural pivots; detector parameterization fixed |
| Gap | Engine's CHOCH granularity is set by swing thresholds; paper shows granularity is a method artifact — supports fixed, validated thresholds |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | The new method finds almost three times more patches than the original algorithm. |
| Reviewer interpretation | Regime-count is method-dependent; justifies the project's fixed-parameter discipline rather than ad-hoc re-detection. |

### RL-CHOCH-02 (2511.00190) — Deep RL for Optimal Trading with Partial Information

| Field | Value |
|---|---|
| Claim ID | RL-CHOCH-02-C01 |
| Paper ID | RL-CHOCH-02 |
| Verbatim anchor | "The latent parameters driving mean reversion, speed, and volatility are filtered from observations of the signal, and trading strategies are derived via RL." (§ Abstract) |
| Claim (falsifiable) | If latent regime parameters (mean reversion, speed, volatility) can be filtered from the signal alone and traded via RL, then regime-aware adaptive policies are feasible without order-flow state. |
| Evidence tag | EMPIRICAL |
| E-level | E3 |
| Population tested | simulated OU regime-switching signal + empirical application to equity pair trading |
| Direction | positive (latent-regime trading feasible) |
| SuperCents_X assumption | CHOCH = reversal on structural change; fixed floors/weights/2.0R |
| Gap | Simulation + equity pairs, not FX; DDPG/GRU policies are far beyond the engine's rule-based planner; contradicts the prior assumption that order flow is required |
| Hypothesis | NONE |
| Flags | WARNING-simulation-only |
| Reviewer paraphrase | Latent parameters driving mean reversion, speed and volatility are filtered from the signal; RL strategies are derived from them. |
| Reviewer interpretation | Regime-aware trading from a price signal alone is feasible in principle — the mechanism does NOT require order-flow state; FX evidence still absent. |

| Field | Value |
|---|---|
| Claim ID | RL-CHOCH-02-C02 |
| Paper ID | RL-CHOCH-02 |
| Verbatim anchor | "we find that prob-DDPG achieves superior cumulative rewards and exhibits more interpretable strategies. By contrast, reg-DDPG provides limited benefits, while hid-DDPG offers intermediate performance with less interpretable strategies." (§ Abstract) |
| Claim (falsifiable) | If how regime information is encoded into the policy (probabilistic vs forecast vs hidden-state) determines performance, then information structure — not RL per se — drives the gain. |
| Evidence tag | EMPIRICAL |
| E-level | E3 |
| Population tested | extensive simulations with increasingly complex Markovian regime dynamics |
| Direction | positive (probabilistic encoding best) |
| SuperCents_X assumption | Fixed-policy design; no adaptive layer |
| Gap | Simulation-only; result suggests probabilistic regime estimates (posterior probability) carry the edge — implementable only if a regime-probability layer is ever added |
| Hypothesis | NONE |
| Flags | WARNING-simulation-only |
| Reviewer paraphrase | prob-DDPG (posterior regime probabilities) achieves superior rewards and interpretability; reg-DDPG and hid-DDPG underperform. |
| Reviewer interpretation | The quality and structure of regime information supplied to a policy is the key lever; supports conditional/adaptive exits only if a regime-probability estimator is built. |

| Field | Value |
|---|---|
| Claim ID | RL-CHOCH-02-C03 |
| Paper ID | RL-CHOCH-02 |
| Verbatim anchor | "Our results show that the quality and structure of the information supplied to the agent are crucial: embedding probabilistic insights into latent regimes substantially improves both profitability and robustness of reinforcement learning–based trading strategies." (§ Abstract) |
| Claim (falsifiable) | If embedding probabilistic regime insight improves both profitability and robustness of RL trading, then regime-aware policies are more robust, not just more profitable. |
| Evidence tag | EMPIRICAL |
| E-level | E3 |
| Population tested | simulations + empirical application to equity pair trading |
| Direction | positive (robustness via regime information) |
| SuperCents_X assumption | Fixed exits (2.0R) regardless of regime |
| Gap | Robustness claim is simulation/equity-pair based; no FX evidence; would require a regime-probability estimator on OHLCV (construct transfer) |
| Hypothesis | NONE |
| Flags | WARNING-simulation-only |
| Reviewer paraphrase | Embedding probabilistic insights into latent regimes improves both profitability and robustness of RL trading. |
| Reviewer interpretation | Conditional/adaptive policies motivated IF regime probability can be estimated from OHLCV; ED01-E (E1) already showed fixed 2.0R is robust — tension unresolved. |

### RL-CHOCH-03 (0705.0503) — Change Point Estimation for the Telegraph Process

| Field | Value |
|---|---|
| Claim ID | RL-CHOCH-03-C01 |
| Paper ID | RL-CHOCH-03 |
| Verbatim anchor | "we consider a change point estimation problem for the rate of the underlying Poisson process by means of least squares method. The consistency and the rate of convergence for the change point estimator are obtained and its asymptotic distribution is derived." (§ Abstract) |
| Claim (falsifiable) | If a least-squares change-point estimator for the regime-switching rate parameter is consistent with known convergence rate, then regime-change points are statistically identifiable in principle. |
| Evidence tag | THEORETICAL |
| E-level | E3 |
| Population tested | NOT-REPORTED (methodological; applications to real data presented) |
| Direction | positive (identifiability) |
| SuperCents_X assumption | CHOCH = reversal on structural change; no probabilistic change-point model behind it |
| Gap | Telegraph/volatility-regime-switch construct differs from OHLC price-pattern reversal; no FX test |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | A least-squares change-point estimator for the Poisson rate is consistent with derived rate of convergence and asymptotic distribution. |
| Reviewer interpretation | Establishes statistical identifiability of regime changes in a stylized model; methodology only, no market/tradability content. |

| Field | Value |
|---|---|
| Claim ID | RL-CHOCH-03-C02 |
| Paper ID | RL-CHOCH-03 |
| Verbatim anchor | "The telegraph process models a random motion with finite velocity and it is usually proposed as an alternative to diffusion models." (§ Abstract) |
| Claim (falsifiable) | If the telegraph process (finite-velocity regime-flip motion) is a viable alternative to diffusion models, then regime-flip models are a legitimate class for volatility-regime dynamics. |
| Evidence tag | THEORETICAL |
| E-level | E3 |
| Population tested | NOT-REPORTED (model class) |
| Direction | not-stated |
| SuperCents_X assumption | CHOCH regime switching (structure states) as a binary state model |
| Gap | Engine has no probabilistic regime model behind CHOCH; the telegraph is a stylized continuous-time model |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | The telegraph process models random motion with finite velocity, an alternative to diffusion models. |
| Reviewer interpretation | Regime-flip modeling is a recognized class; no engine mapping, no action. |

### RL-CHOCH-04 (2605.29541) — Change-Point Estimation for Weibull Time Series (Copula-Based Markov)

| Field | Value |
|---|---|
| Claim ID | RL-CHOCH-04-C01 |
| Paper ID | RL-CHOCH-04 |
| Verbatim anchor | "We study offline change-point estimation for time series data exhibiting nonlinear serial dependence." (§ Abstract) |
| Claim (falsifiable) | If offline change-point estimation works under nonlinear serial dependence (copula-based Markov model, Weibull margins), then regime detection need not assume linear/independent dynamics. |
| Evidence tag | EMPIRICAL |
| E-level | E3 |
| Population tested | numerical studies (finite-sample performance under dependence structures and copula misspecification) |
| Direction | positive (estimation under nonlinear dependence) |
| SuperCents_X assumption | CHOCH pattern rules; no distributional model |
| Gap | Model targets nonnegative data (event times, volatility measures), not FX prices; simulation-based |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Offline change-point estimation is studied for time series with nonlinear serial dependence. |
| Reviewer interpretation | Regime detection robust to dependence structure exists in principle; no market or FX content. |

| Field | Value |
|---|---|
| Claim ID | RL-CHOCH-04-C02 |
| Paper ID | RL-CHOCH-04 |
| Verbatim anchor | "An empirical application to the VIX index during the COVID-19 pandemic further illustrates the practical usefulness of the proposed approach in detecting structural changes in both the marginal distributions and serial dependence structure." (§ Abstract) |
| Claim (falsifiable) | If change-point detection flags structural changes in the VIX during a crisis, then structural breaks occur in both marginal distributions and serial dependence. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | VIX index during COVID-19 pandemic (daily-type series) |
| Direction | positive (structural break detection on real data) |
| SuperCents_X assumption | CHOCH detects structural breaks on market series |
| Gap | VIX is an index, not FX; volatility measure, not price; crisis-period detection ≠ general trading relevance |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | VIX application during COVID-19 shows the approach detects structural changes in margins and dependence. |
| Reviewer interpretation | Real-data feasibility for volatility-regime breaks; not FX, not tradeable signal per se. |

### RL-CHOCH-05 (2204.00872) — Calibration Window Selection via Change-Point Detection

| Field | Value |
|---|---|
| Claim ID | RL-CHOCH-05-C01 |
| Paper ID | RL-CHOCH-05 |
| Verbatim anchor | "We employ a recently proposed change-point detection algorithm, the Narrowest-Over-Threshold (NOT) method, to select subperiods of past observations that are similar to the currently recorded values." (§ Abstract) |
| Claim (falsifiable) | If change-point segmentation can select regime-consistent calibration samples, then conditioning estimation windows on detected regimes beats naive trailing windows. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | German EPEX SPOT day-ahead electricity prices (period NOT-REPORTED) |
| Direction | positive (methodological) |
| SuperCents_X assumption | Fixed swing/CHOCH window parameters |
| Gap | Electricity prices, not FX; forecasting context, not trading; supports the principle of regime-conditioned windows |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | The NOT method selects past subperiods similar to currently recorded values for calibration. |
| Reviewer interpretation | Change-point-based window selection is a working principle; would apply to any future regime-conditioned re-estimation, not to the current fixed windows. |

| Field | Value |
|---|---|
| Claim ID | RL-CHOCH-05-C02 |
| Paper ID | RL-CHOCH-05 |
| Verbatim anchor | "we estimate autoregressive models only for data in these subperiods. ... and observe a significant improvement in forecasting accuracy compared to commonly used approaches, including the Autoregressive Hybrid Nearest Neighbors (ARHNN) method." (§ Abstract) |
| Claim (falsifiable) | If regime-selected calibration windows improve forecast accuracy vs standard baselines (incl. ARHNN), then regime-aware window choice is a first-order accuracy lever. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | German EPEX SPOT day-ahead electricity prices |
| Direction | positive (improvement vs baselines) |
| SuperCents_X assumption | One fixed window set for EURUSD and GBPJPY |
| Gap | Electricity, not FX; forecast accuracy ≠ trading PnL; no ED01-style gate applied |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Estimating models only on change-point-selected subperiods significantly improves forecasting vs ARHNN and others. |
| Reviewer interpretation | Supports regime-conditioned calibration in principle; ED01-E already showed fixed-parameter tiers are robust on FX — tension unresolved without an experiment. |

### RL-OB-01 (2112.02947) — The Price Impact of Generalized Order Flow Imbalance

| Field | Value |
|---|---|
| Claim ID | RL-OB-01-C01 |
| Paper ID | RL-OB-01 |
| Verbatim anchor | "Order flow imbalance can explain short-term changes in stock price." (§ Abstract) |
| Claim (falsifiable) | If order flow imbalance explains short-term stock price changes, then imbalance measures carry short-horizon predictive content for price. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | CSI 500 constituent stocks, high-frequency order book snapshot data (period NOT-REPORTED) |
| Direction | positive (OFI → price changes) |
| SuperCents_X assumption | OB detector = displacement + break + unmitigated zone as imbalance proxy |
| Gap | Engine infers imbalance from OHLC displacement; paper uses book-level OFI (order-level flow) — construct transfer, weaker proxy |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Order flow imbalance explains short-term changes in stock price. |
| Reviewer interpretation | Mechanism-level support for imbalance as a signal; E2 market, OHLC proxy weaker than book OFI. |

| Field | Value |
|---|---|
| Claim ID | RL-OB-01-C02 |
| Paper ID | RL-OB-01 |
| Verbatim anchor | "on the time scales of 30 seconds, 1 minute, and 5 minutes, the average [R2] out of sample compared with Order Flow Imbalance (OFI) 32.89%, 38.13% and 42.57%, respectively increased to 83.57%, 85.37% and 86.01%" (§ Abstract) |
| Claim (falsifiable) | If generalized/stationarized OFI raises out-of-sample explanatory power from ~33–43% to ~84–86% at 30s/1m/5m, then OFI construction quality materially determines explanatory power. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | CSI 500 constituent stocks (10 selected for comparison), 30s/1m/5m horizons |
| Direction | positive (improved construction → higher explanatory power) |
| SuperCents_X assumption | OB detector zone structure as imbalance proxy |
| Gap | Engine's OHLC displacement proxy has no equivalent construction/stationarization; unexplained variance (~14% at best) remains dominant |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Generalized/stationarized OFI raises out-of-sample R2 from ~33–43% to ~84–86% at 30s–5m scales. |
| Reviewer interpretation | Even the best imbalance construction leaves the majority of variance unexplained at coarser scales; E2 only. |

| Field | Value |
|---|---|
| Claim ID | RL-OB-01-C03 |
| Paper ID | RL-OB-01 |
| Verbatim anchor | "the interpretability of Generalized Stationarized Order Flow Imbalance (log-GOFI) showed stronger stability on all three time scales" (§ Abstract) |
| Claim (falsifiable) | If log-GOFI explanatory power is stable across 30s/1m/5m scales, then stationarization improves scale-robustness of imbalance signals. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | CSI 500 constituent stocks, 30s/1m/5m horizons |
| Direction | positive (scale-stability) |
| SuperCents_X assumption | H1/M15 bar resolution for OB detection |
| Gap | Engine has no stationarization of imbalance proxies across timeframes |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | log-GOFI shows stronger stability on all three time scales. |
| Reviewer interpretation | Scale-robust imbalance construction is possible in principle; not implementable from OHLCV alone. |

### RL-OB-02 (2510.08085) — A Deterministic LOB Simulator with Hawkes-Driven Order Flow

| Field | Value |
|---|---|
| Claim ID | RL-OB-02-C01 |
| Paper ID | RL-OB-02 |
| Verbatim anchor | "we calibrate and compare exponential vs. power-law kernels on Binance BTCUSDT trades and LOBSTER AAPL Level-3 books" (§ Abstract) |
| Claim (falsifiable) | If Hawkes kernels can be calibrated to real crypto and equity LOB data, then order-arrival processes are fit by self-exciting models. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | Binance BTCUSDT trades; LOBSTER AAPL Level-3 books (period NOT-REPORTED) |
| Direction | positive (kernel fit) |
| SuperCents_X assumption | No LOB state in engine |
| Gap | Engine is OHLCV-only; LOB order-arrival modeling not applicable |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Hawkes kernels are calibrated to real crypto and equity LOB data. |
| Reviewer interpretation | Methodological background; no tradability claim for OHLCV engines. |

| Field | Value |
|---|---|
| Claim ID | RL-OB-02-C02 |
| Paper ID | RL-OB-02 |
| Verbatim anchor | "where Hawkes-based simulators match or miss LOB stylized facts relative to queue-reactive baselines" (§ Abstract) |
| Claim (falsifiable) | If Hawkes simulators only partially match LOB stylized facts, then self-exciting models are an imperfect LOB representation. |
| Evidence tag | EMPIRICAL |
| E-level | E3 |
| Population tested | simulated LOB calibrated to BTCUSDT/AAPL data |
| Direction | not-stated (partial fidelity) |
| SuperCents_X assumption | None |
| Gap | None — no claim about trading performance; LOB dynamics not observable in engine |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Hawkes simulators both match and miss LOB stylized facts. |
| Reviewer interpretation | No tradability content; methodological background only. |

### RL-OB-03 (2601.23172) — A unified theory of order flow, market impact, and volatility

| Field | Value |
|---|---|
| Claim ID | RL-OB-03-C01 |
| Paper ID | RL-OB-03 |
| Verbatim anchor | "the signed flow converges to the sum of a fractional process with Hurst index H0 and a martingale, while the limiting traded volume is a rough process with Hurst index H0−1/2" (§ Abstract) |
| Claim (falsifiable) | If signed order flow converges to a fractional process with Hurst index H0, then order-flow persistence is a structural, persistent market feature. |
| Evidence tag | THEORETICAL |
| E-level | E3 |
| Population tested | NOT-REPORTED (model with no-arbitrage constraints) |
| Direction | positive (persistence of signed flow) |
| SuperCents_X assumption | OB/flow persistence as background mechanism |
| Gap | Engine cannot observe signed flow; persistence claims not testable from OHLCV |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Signed flow is persistent with Hurst index H0; volume is rough with Hurst H0−1/2. |
| Reviewer interpretation | Theoretical microstructure result; not testable from OHLCV. |

| Field | Value |
|---|---|
| Claim ID | RL-OB-03-C02 |
| Paper ID | RL-OB-03 |
| Verbatim anchor | "The analysis of signed order flow data yields an estimate H0 ≈ 3/4. This is not only consistent with the square-root law of market impact" (§ Abstract) |
| Claim (falsifiable) | If empirical signed-flow data yields H0 ≈ 3/4, then persistent flow and power-law impact coexist in real markets. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | signed order flow data (market NOT-REPORTED in abstract; BMLL historical data acknowledged) |
| Direction | positive (empirical H0 ≈ 3/4) |
| SuperCents_X assumption | None (no flow data) |
| Gap | Engine has no flow observation; result informs market-impact scaling only |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Empirical H0 ≈ 3/4 is consistent with the square-root law of impact. |
| Reviewer interpretation | Confirms persistence/impact coexistence at the macro scale; not usable for OHLCV-only decisions. |

### RL-OB-04 (2607.04280) — Order Splitting and the Square-Root Law

| Field | Value |
|---|---|
| Claim ID | RL-OB-04-C01 |
| Paper ID | RL-OB-04 |
| Verbatim anchor | "Order splitting is the dominant factor: its removal collapses δ from 0.549 to 0.324, well below both 1/2 and 1" (§ 5 Discussion) |
| Claim (falsifiable) | If order splitting is the dominant mechanism behind the square-root law, then impact scaling arises from execution fragmentation, not size per se. |
| Evidence tag | EMPIRICAL |
| E-level | E3 |
| Population tested | model-internal simulation (agent-based; real-market confirmation explicitly NOT tested) |
| Direction | positive (splitting drives SRL) |
| SuperCents_X assumption | Fixed lot sizing; 2R targets |
| Gap | Engine trades retail-sized lots; impact scaling immaterial; paper explicitly notes real-market confirmation requires empirical measurement |
| Hypothesis | NONE |
| Flags | WARNING-model-internal |
| Reviewer paraphrase | Removing order splitting collapses the impact exponent from 0.549 to 0.324. |
| Reviewer interpretation | Simulation-internal result; the paper itself cautions that real-market confirmation is untested. |

| Field | Value |
|---|---|
| Claim ID | RL-OB-04-C02 |
| Paper ID | RL-OB-04 |
| Verbatim anchor | "whether the same conclusion holds in real markets would require analogous empirical measurement" (§ 5 Discussion) |
| Claim (falsifiable) | If real-market confirmation of the SRL mechanism is pending, then the square-root law's practical impact is unestablished at the tested market scale. |
| Evidence tag | UNSUPPORTED |
| E-level | E3 |
| Population tested | NOT-REPORTED (no empirical test) |
| Direction | not-stated |
| SuperCents_X assumption | None |
| Gap | None — no tradability claim |
| Hypothesis | NONE |
| Flags | WARNING-model-internal |
| Reviewer paraphrase | Real-market confirmation of the SRL mechanism would require further measurement. |
| Reviewer interpretation | The paper itself disclaims empirical support; no weight for SCX. |

### RL-OB-05 (2608.00885) — Optimal Trading of Microstructure Mean Reversion

| Field | Value |
|---|---|
| Claim ID | RL-OB-05-C01 |
| Paper ID | RL-OB-05 |
| Verbatim anchor | "At the scale of seconds the observed mid carries a stationary, mean-reverting error around a latent efficient price." (§ Abstract) |
| Claim (falsifiable) | If the observed mid carries a stationary mean-reverting error around a latent efficient price at the seconds scale, then microstructure prices mean-revert at that scale. |
| Evidence tag | THEORETICAL |
| E-level | E3 |
| Population tested | NOT-REPORTED (theoretical model; "the paper is theoretical, uses no proprietary or confidential information") |
| Direction | positive (mean reversion at seconds scale) |
| SuperCents_X assumption | Fixed entry/exit rules (2R) |
| Gap | Engine's bar scale (M15/H1) is far coarser than the seconds scale of the model; no intra-bar mid observation |
| Hypothesis | NONE |
| Flags | WARNING-theoretical-only |
| Reviewer paraphrase | At the seconds scale the mid carries a stationary mean-reverting error. |
| Reviewer interpretation | Framework-level; seconds-scale microstructure is outside the engine's observable range. |

| Field | Value |
|---|---|
| Claim ID | RL-OB-05-C02 |
| Paper ID | RL-OB-05 |
| Verbatim anchor | "we build an order book whose own flow produces that error, and solve for the trading rule that maximises the long-run average profit rate, net of the bid–ask spread" (§ Abstract) |
| Claim (falsifiable) | If an optimal band rule maximizes long-run profit net of spread, then execution timing (band width) is a first-order profit determinant. |
| Evidence tag | THEORETICAL |
| E-level | E3 |
| Population tested | NOT-REPORTED (theoretical) |
| Direction | positive (band optimization) |
| SuperCents_X assumption | Fixed 2R exits; market-order execution |
| Gap | Engine has no band/execution-timing optimization; model assumes an observable efficient-price gap, unobservable to the engine |
| Hypothesis | NONE |
| Flags | WARNING-theoretical-only |
| Reviewer paraphrase | The optimal rule maximizes long-run profit net of the bid–ask spread. |
| Reviewer interpretation | Suggests execution timing matters in principle; not implementable from OHLCV. |

### RL-FVG-01 (1405.1247) — Price Gaps in LOBs (Chinese stocks)

| Field | Value |
|---|---|
| Claim ID | RL-FVG-01-C01 |
| Paper ID | RL-FVG-01 |
| Verbatim anchor | "the distribution of price gaps has a power-law tail for all stocks with an average tail exponent close to 3.2" (§ Abstract) |
| Claim (falsifiable) | If LOB price-gap sizes are power-law distributed (tail ~3.2), then gap/imbalance sizes are heavy-tailed, not Gaussian. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | 26 A-share stocks, Shenzhen Stock Exchange, 2003 order-flow data |
| Direction | not-stated (descriptive) |
| SuperCents_X assumption | FVG detector uses 3-candle imbalance (low1 > high3) with no size distribution assumption |
| Gap | FVG is a 3-bar OHLC imbalance; paper studies LOB price gaps (distance between first two occupied price levels) — different construct; heavy-tailed sizes imply occasional extreme imbalances |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Price gap sizes follow a power-law with tail exponent ~3.2. |
| Reviewer interpretation | Descriptive microstructure; concept of "gap" differs from the FVG pattern; no tradability claim. |

| Field | Value |
|---|---|
| Claim ID | RL-FVG-01-C02 |
| Paper ID | RL-FVG-01 |
| Verbatim anchor | "the gap time series are long-range correlated and possess multifractal nature" (§ Abstract) |
| Claim (falsifiable) | If gap series are long-range correlated, then gap persistence carries predictive memory. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | 26 A-share stocks, SZSE 2003 |
| Direction | positive (long memory) |
| SuperCents_X assumption | FVG as entry zone; no memory modeling |
| Gap | Engine ignores gap-time-series memory; OHLCV cannot observe LOB gaps |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Gap series are long-range correlated and multifractal. |
| Reviewer interpretation | Suggests persistence phenomena exist around gaps; not testable from OHLCV. |

| Field | Value |
|---|---|
| Claim ID | RL-FVG-01-C03 |
| Paper ID | RL-FVG-01 |
| Verbatim anchor | "these three features vary from stock to stock and are not universal" (§ Abstract) |
| Claim (falsifiable) | If gap properties are not universal across stocks, then gap/imbalance properties are instrument-dependent. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | 26 A-share stocks, SZSE 2003 |
| Direction | null (non-universality) |
| SuperCents_X assumption | FVG detector applied uniformly to EURUSD and GBPJPY |
| Gap | None — non-universality warns against cross-pair parameter transfer |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Gap features are not universal across stocks. |
| Reviewer interpretation | Caution for shared FVG parameters across pairs; ED01-B already found no distinct FVG edge on FX. |

### RL-FVG-02 (1201.5448) — Determinants of Immediate Price Impacts

| Field | Value |
|---|---|
| Claim ID | RL-FVG-02-C01 |
| Paper ID | RL-FVG-02 |
| Verbatim anchor | "the trade size, the bid-ask spread, the price gaps and the outstanding volumes at the bid and ask sides of the limit order book have impacts on the changes of prices" (§ Abstract) |
| Claim (falsifiable) | If price gaps and book depth determine immediate price impact, then imbalance/liquidity voids influence short-horizon price moves. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | Shenzhen Stock Exchange stocks (emerging order-driven market, period NOT-REPORTED) |
| Direction | positive (gaps/depth → price impact) |
| SuperCents_X assumption | FVG imbalance zones attract price (fill) |
| Gap | Paper measures trade-level LOB effects; engine infers imbalance from OHLC candles — level-of-observation transfer |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Gaps and book depth impact immediate price changes. |
| Reviewer interpretation | Mechanism-level support that price voids matter for short-horizon moves; E2 evidence, OHLC proxy weaker. |

| Field | Value |
|---|---|
| Claim ID | RL-FVG-02-C02 |
| Paper ID | RL-FVG-02 |
| Verbatim anchor | "these factors can account for up to 44% of the price impacts" (§ Abstract) |
| Claim (falsifiable) | If these microstructure factors explain up to 44% of price impact, then the remainder is unexplained — price impact is only partly structural. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | Shenzhen Stock Exchange stocks (NOT-REPORTED period) |
| Direction | not-stated (explanatory share) |
| SuperCents_X assumption | Structure-based entry zones carry the majority of signal |
| Gap | None — informational; 44% is an upper bound for structural explanation |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Factors account for up to 44% of price impacts. |
| Reviewer interpretation | Structural factors are a minority of price impact variance — caps the theoretical edge from structure alone. |

| Field | Value |
|---|---|
| Claim ID | RL-FVG-02-C03 |
| Paper ID | RL-FVG-02 |
| Verbatim anchor | "the liquidity at the opposite side has a more influencing impact than the liquidity at the same side" (§ Abstract) |
| Claim (falsifiable) | If opposite-side liquidity is the more influential factor, then positions held against liquidity voids (opposing zones) face larger adverse impact. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | Shenzhen Stock Exchange stocks (NOT-REPORTED period) |
| Direction | positive (opposite-side dominance) |
| SuperCents_X assumption | TP placed at opposing liquidity (ED01-D config) |
| Gap | None — directionally consistent with ED01-D (opposing-liquidity TP worse, Δ −0.7210 R, n=607) |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Opposite-side liquidity influences impact more than same-side. |
| Reviewer interpretation | Literature direction agrees with ED01-D's E1 finding that TP into opposing liquidity underperforms. |

### RL-FVG-03 (2605.11423) — VVG Classifier (MNQ)

| Field | Value |
|---|---|
| Claim ID | RL-FVG-03-C01 |
| Paper ID | RL-FVG-03 |
| Verbatim anchor | "classifier-positive days behave differently from the rest of the sample in measurable ways" (§ Abstract) |
| Claim (falsifiable) | If a gap+volume+volatility day classifier identifies distinct behavior, then gap-identified days carry regime information. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | MNQ 5-minute bars, 947 trading days, 2021–2025, expanding-window thresholds |
| Direction | positive (classifier distinguishes days) |
| SuperCents_X assumption | FVG/gap structure as regime-identifying feature |
| Gap | Paper classifies days by overnight gap + first-30-min return + first-bar volume; engine's FVG is an intra-bar imbalance — different time scale and construct |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | A VVG day classifier finds measurable behavioral differences. |
| Reviewer interpretation | Gap-identified days differ; but the concept is day-level, not the 3-bar FVG. |

| Field | Value |
|---|---|
| Claim ID | RL-FVG-03-C02 |
| Paper ID | RL-FVG-03 |
| Verbatim anchor | "none of it translates into a deployable trading strategy under the constraints I tested; eight configurations, all failing on T-statistic, year stability, or sample size" (§ 7 Conclusion) |
| Claim (falsifiable) | If a validated gap-based classifier fails all trading configurations, then pattern existence does not imply tradability. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | MNQ 5-minute bars, 947 days, 2021–2025 |
| Direction | null (no tradeable configuration) |
| SuperCents_X assumption | FVG zone entries with 2.0R benchmark |
| Gap | None — paper's null directly parallels ED01-B (FVG no distinct edge) and ED01-E (no tier beats 2.0R) |
| Hypothesis | NONE |
| Flags | WARNING-sample-size |
| Reviewer paraphrase | The validated classifier translates into no deployable strategy; all eight configurations failed statistical gates. |
| Reviewer interpretation | Strongly corroborates ED01-B/ED01-E nulls: detectable structure ≠ tradeable edge. |

### RL-LIQ-01 (1112.6169) — Measuring Market Liquidity: An Introductory Survey

| Field | Value |
|---|---|
| Claim ID | RL-LIQ-01-C01 |
| Paper ID | RL-LIQ-01 |
| Verbatim anchor | "A market is often said to be liquid when the prevailing structure of transactions provides a prompt and secure link between the demand and supply of assets, thus delivering low costs of transaction." (§ Abstract) |
| Claim (falsifiable) | If liquidity is defined by low transaction costs and prompt execution, then liquidity is measurable from transaction/quote data, not from OHLC volume alone. |
| Evidence tag | INTERPRETATION |
| E-level | E4 |
| Population tested | NOT-REPORTED (survey of definitions and estimation frameworks) |
| Direction | not-stated (definitional) |
| SuperCents_X assumption | LIQUIDITY detector uses EQH/EQL + sweep from OHLCV; floor 0.60 |
| Gap | Survey measures liquidity via spread and its components; engine infers liquidity from OHLC price action — proxy only, no spread observation |
| Hypothesis | NONE |
| Flags | REGIME-AGE (2011 survey, rev. 2024) |
| Reviewer paraphrase | Liquidity means prompt, secure execution at low transaction cost. |
| Reviewer interpretation | Definitional survey; no tradability claim; confirms the engine's liquidity notion is an OHLC proxy of a spread-based construct. |

| Field | Value |
|---|---|
| Claim ID | RL-LIQ-01-C02 |
| Paper ID | RL-LIQ-01 |
| Verbatim anchor | "intra-daily measures of liquidity appear relevant for capturing the core features of a market, and for their ability to describe the arrival of new information to market participants" (§ Abstract) |
| Claim (falsifiable) | If intra-daily liquidity measures capture market features and information arrival, then liquidity is time-of-day and news-dependent. |
| Evidence tag | INTERPRETATION |
| E-level | E4 |
| Population tested | NOT-REPORTED (survey) |
| Direction | not-stated |
| SuperCents_X assumption | Liquidity floor applied uniformly across sessions |
| Gap | Engine has no intraday/time-of-day liquidity conditioning |
| Hypothesis | NONE |
| Flags | REGIME-AGE |
| Reviewer paraphrase | Intra-daily liquidity measures capture market features and information arrival. |
| Reviewer interpretation | Suggests intraday liquidity dynamics exist; engine treats liquidity as uniform — unaddressed dimension. |

### RL-LIQ-02 (1309.5235) — Optimal Liquidity Provision

| Field | Value |
|---|---|
| Claim ID | RL-LIQ-02-C01 |
| Paper ID | RL-LIQ-02 |
| Verbatim anchor | "A small investor provides liquidity at the best bid and ask prices of a limit order market. For small spreads and frequent orders of other market participants, we explicitly determine the investor's optimal policy and welfare." (§ Abstract) |
| Claim (falsifiable) | If an optimal liquidity-provision policy exists for small spreads and frequent flow, then passive quote placement has a solvable optimum. |
| Evidence tag | THEORETICAL |
| E-level | E3 |
| Population tested | NOT-REPORTED (theoretical model) |
| Direction | positive (optimal policy exists) |
| SuperCents_X assumption | Engine is a taker (market orders), not a provider |
| Gap | Engine provides no liquidity; theory addresses passive quoting — opposite role |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | An optimal liquidity-provision policy exists for small spreads and frequent orders. |
| Reviewer interpretation | Relevant only if the engine ever quotes passively; not applicable to the current taker design. |

| Field | Value |
|---|---|
| Claim ID | RL-LIQ-02-C02 |
| Paper ID | RL-LIQ-02 |
| Verbatim anchor | "we allow for general dynamics of the mid price, the spread, and the order flow, as well as for arbitrary preferences of the liquidity provider" (§ Abstract) |
| Claim (falsifiable) | If optimal provision depends on mid/spread/flow dynamics, then provision decisions need more state than OHLCV. |
| Evidence tag | THEORETICAL |
| E-level | E3 |
| Population tested | NOT-REPORTED (theoretical) |
| Direction | not-stated |
| SuperCents_X assumption | OHLCV-only state |
| Gap | None — reinforces data boundary; provision state unobservable in engine |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | The model admits general mid/spread/flow dynamics and arbitrary preferences. |
| Reviewer interpretation | Framework-level; reinforces that liquidity-provision decisions are outside the engine's observable range. |

### RL-LIQ-03 (2010.13038) — HFT Impact on Artificial Market Liquidity (IEEE TCSS)

| Field | Value |
|---|---|
| Claim ID | RL-LIQ-03-C01 |
| Paper ID | RL-LIQ-03 |
| Verbatim anchor | "The results showed that all liquidity indicators in the market where an HFT participated improved more than those in the market where no HFT participated." (§ Abstract) |
| Claim (falsifiable) | If HFT participation improves all liquidity indicators in an artificial market, then HFT activity is liquidity-improving (in simulation). |
| Evidence tag | EMPIRICAL |
| E-level | E3 |
| Population tested | agent-based artificial market, simulated HFT vs no-HFT (period NOT-REPORTED) |
| Direction | positive (HFT improves liquidity) |
| SuperCents_X assumption | LIQUIDITY family assumes observable sweeps of resting liquidity |
| Gap | Simulation-only; artificial market; no FX data; HFT participation is exogenous |
| Hypothesis | NONE |
| Flags | WARNING-simulation-only |
| Reviewer paraphrase | All liquidity indicators improved when an HFT participated. |
| Reviewer interpretation | Simulation evidence that HFT presence changes liquidity; not directly applicable to OHLCV FX engine. |

| Field | Value |
|---|---|
| Claim ID | RL-LIQ-03-C02 |
| Paper ID | RL-LIQ-03 |
| Verbatim anchor | "it is suggested that it could be appropriate to employ execution rate as a novel liquidity indicator in future studies" (§ Abstract) |
| Claim (falsifiable) | If execution rate is a valid liquidity indicator, then fill-rate telemetry measures liquidity. |
| Evidence tag | EMPIRICAL |
| E-level | E3 |
| Population tested | artificial market simulation |
| Direction | not-stated (indicator proposal) |
| SuperCents_X assumption | Telemetry includes fill rate but not as a liquidity measure |
| Gap | Engine does not use execution rate as a liquidity signal |
| Hypothesis | NONE |
| Flags | WARNING-simulation-only |
| Reviewer paraphrase | Execution rate is suggested as a novel liquidity indicator. |
| Reviewer interpretation | Proposal from simulation; no direct adoption basis. |

### RL-LIQ-04 (2310.09273) — Uncovering Market Disorder and Liquidity Trends Detection

| Field | Value |
|---|---|
| Claim ID | RL-LIQ-04-C01 |
| Paper ID | RL-LIQ-04 |
| Verbatim anchor | "The primary objective of this paper is to conceive and develop a new methodology to detect notable changes in liquidity within an order-driven market." (§ Abstract) |
| Claim (falsifiable) | If notable liquidity changes are detectable in order-driven markets, then liquidity is a dynamic, regime-switching quantity. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | order-driven market, limit order book data (market/period NOT-REPORTED; "empirically validated by means of real market data analyses") |
| Direction | positive (liquidity changes detectable) |
| SuperCents_X assumption | LIQUIDITY detector treats sweeps as discrete events; floor 0.60 static |
| Gap | Engine detects liquidity events, not liquidity-level regimes; no continuous liquidity state |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | A methodology to detect notable liquidity changes in an order-driven market is developed and validated. |
| Reviewer interpretation | Supports the notion of liquidity regime shifts; engine lacks the LOB data to detect them directly. |

| Field | Value |
|---|---|
| Claim ID | RL-LIQ-04-C02 |
| Paper ID | RL-LIQ-04 |
| Verbatim anchor | "We prove our procedure's optimality in the case of a Cox process with simultaneous jumps, while considering a finite time horizon." (§ Abstract) |
| Claim (falsifiable) | If the quickest-change detection procedure is provably optimal for Cox processes, then optimal liquidity-change detection is theoretically founded. |
| Evidence tag | THEORETICAL |
| E-level | E3 |
| Population tested | NOT-REPORTED (theoretical proof + empirical validation) |
| Direction | not-stated |
| SuperCents_X assumption | None |
| Gap | Engine has no point-process intensity model of liquidity |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | The detection procedure is proven optimal for Cox processes on a finite horizon. |
| Reviewer interpretation | Methodology for future use; no current engine mapping. |

### RL-SMC-01 (1108.1632) — Why Is Equity Order Flow So Persistent?

| Field | Value |
|---|---|
| Claim ID | RL-SMC-01-C01 |
| Paper ID | RL-SMC-01 |
| Verbatim anchor | "Order flow in equity markets is remarkably persistent in the sense that order signs (to buy or sell) are positively autocorrelated out to time lags of tens of thousands of orders, corresponding to many days." (§ Abstract) |
| Claim (falsifiable) | If order signs are positively autocorrelated over many days, then trade direction is persistent, not random. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | London Stock Exchange order flow with membership identifiers (period NOT-REPORTED) |
| Direction | positive (persistence) |
| SuperCents_X assumption | SMC/informed-flow concepts assume directional persistence of order flow |
| Gap | Engine cannot observe order signs; persistence untestable from OHLCV |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Equity order signs are positively autocorrelated out to many days. |
| Reviewer interpretation | Confirms persistence as a real microstructure phenomenon; not observable in the engine's data. |

| Field | Value |
|---|---|
| Claim ID | RL-SMC-01-C02 |
| Paper ID | RL-SMC-01 |
| Verbatim anchor | "On timescales of less than a few hours the persistence of order flow is overwhelmingly due to splitting rather than herding." (§ Abstract, continuation) |
| Claim (falsifiable) | If short-horizon persistence is due to order splitting, then persistence is an execution artifact of single investors, not crowd herding. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | LSE order flow with membership identifiers |
| Direction | positive (splitting explanation) |
| SuperCents_X assumption | None (no order-level data) |
| Gap | None — reinforces OHLCV data boundary |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Sub-hour persistence is mostly order splitting, not herding. |
| Reviewer interpretation | Mechanism attribution; untestable from OHLCV; no strategy implication for the engine. |

### RL-SMC-02 (1610.00261) — Limit Order Strategic Placement with Adverse Selection Risk and Latency

| Field | Value |
|---|---|
| Claim ID | RL-SMC-02-C01 |
| Paper ID | RL-SMC-02 |
| Verbatim anchor | "we use labelled trade data to exhibit how market participants decisions depend on liquidity imbalance" (§ Abstract) |
| Claim (falsifiable) | If participant decisions depend on liquidity imbalance, then imbalance is a decision-relevant state variable. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | labelled trade data (market/period NOT-REPORTED) |
| Direction | positive (imbalance matters) |
| SuperCents_X assumption | OB/FVG detectors proxy imbalance from OHLC |
| Gap | Engine lacks liquidity-imbalance observation; paper uses labelled trade data |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Participants' decisions depend on liquidity imbalance. |
| Reviewer interpretation | Confirms imbalance relevance; engine's proxy is OHLC-only. |

| Field | Value |
|---|---|
| Claim ID | RL-SMC-02-C02 |
| Paper ID | RL-SMC-02 |
| Verbatim anchor | "the added value of exploiting liquidity imbalance is eroded by latency: being able to predict future liquidity consuming flows is of less use if you do not have enough time to cancel and reinsert your limit orders" (§ Abstract) |
| Claim (falsifiable) | If latency erodes the value of imbalance prediction, then speed advantage is required to exploit imbalance signals. |
| Evidence tag | THEORETICAL |
| E-level | E3 |
| Population tested | stochastic control framework + numerical latency costs |
| Direction | negative (latency erodes edge) |
| SuperCents_X assumption | H1/M15 decision cadence; no sub-second execution |
| Gap | None — engine's slow cadence already accepts the latency penalty; no fast path exists |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Latency erodes the added value of exploiting liquidity imbalance. |
| Reviewer interpretation | The engine's bar-cadence design is consistent with this limitation; imbalance exploitation at HFT speeds is out of scope. |

### RL-SMC-03 (2107.12094) — Liquidity Provision with Adverse Selection and Inventory Costs

| Field | Value |
|---|---|
| Claim ID | RL-SMC-03-C01 |
| Paper ID | RL-SMC-03 |
| Verbatim anchor | "When quoting their price schedules, the dealers do not know the client's type but only its distribution, and in turn choose their price quotes to mitigate between adverse selection and inventory costs." (§ Abstract) |
| Claim (falsifiable) | If dealers optimize quotes against adverse selection, then informed flow is priced into quotes — an information asymmetry mechanism. |
| Evidence tag | THEORETICAL |
| E-level | E3 |
| Population tested | NOT-REPORTED (Nash competition model) |
| Direction | positive (asymmetry mechanism) |
| SuperCents_X assumption | SMC "smart money" premise: informed flow leaves detectable footprints |
| Gap | Engine cannot identify dealer-vs-client or informed-vs-uninformed flow from OHLCV |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Dealers quote to mitigate between adverse selection and inventory costs. |
| Reviewer interpretation | Theoretical grounding for adverse-selection mechanisms; unobservable to the engine. |

| Field | Value |
|---|---|
| Claim ID | RL-SMC-03-C02 |
| Paper ID | RL-SMC-03 |
| Verbatim anchor | "we show that a unique symmetric Nash equilibrium exists and can be characterized by the solution of a nonlinear ODE" (§ Abstract) |
| Claim (falsifiable) | If a unique symmetric Nash equilibrium exists, then quote competition has a well-defined outcome. |
| Evidence tag | THEORETICAL |
| E-level | E3 |
| Population tested | NOT-REPORTED (theoretical) |
| Direction | not-stated |
| SuperCents_X assumption | None |
| Gap | None — equilibrium existence does not inform OHLCV trading decisions |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | A unique symmetric Nash equilibrium exists, characterized by a nonlinear ODE. |
| Reviewer interpretation | Theory-only; no engine mapping. |

### RL-SMC-04 (2608.04373) — Public Trader Identity: Adverse Selection and Return Predictability

| Field | Value |
|---|---|
| Claim ID | RL-SMC-04-C01 |
| Paper ID | RL-SMC-04 |
| Verbatim anchor | "Informativeness is a persistent wallet attribute. Wallets ranked by the price movement following their aggressive orders retain that ordering across adjacent ten-day windows, with a rank correlation of 0.52." (§ Abstract) |
| Claim (falsifiable) | If trader informativeness is persistent across ten-day windows, then trader identity carries stable predictive information. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | decentralized exchange, 17.1B messages, 14.3M aggressive orders, 147,113 wallets, $84.3B taker notional (period NOT-REPORTED) |
| Direction | positive (persistent informativeness) |
| SuperCents_X assumption | SMC premise: informed traders exist and leave footprints |
| Gap | Engine has no trader identity data; wallet-level signals unobservable from OHLCV |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Wallet informativeness persists across adjacent ten-day windows (rank corr 0.52). |
| Reviewer interpretation | Strong evidence that informed-identity is real and persistent — but requires order-level data the engine cannot access. |

| Field | Value |
|---|---|
| Claim ID | RL-SMC-04-C02 |
| Paper ID | RL-SMC-04 |
| Verbatim anchor | "Adding the live activity of the highest-ranked wallets to a standard anonymous benchmark of prices, quotes, and order flow raises the out-of-sample R2 for one-second returns to 12.31%, a 13.2% gain (t = 9.2)" (§ Abstract) |
| Claim (falsifiable) | If wallet activity raises OOS R2 for one-second returns, then trader-identity data has short-horizon predictive value beyond anonymous book data. |
| Evidence tag | EMPIRICAL |
| E-level | E2 |
| Population tested | decentralized exchange record (17.1B messages; one-second returns) |
| Direction | positive (identity → predictability) |
| SuperCents_X assumption | None (identity data unavailable) |
| Gap | Engine has no identity layer; one-second horizon is far below engine cadence |
| Hypothesis | NONE |
| Flags | — |
| Reviewer paraphrase | Live activity of top-ranked wallets adds 13.2% OOS R2 for one-second returns (t = 9.2). |
| Reviewer interpretation | Confirms identity-driven predictability exists at high frequency; completely outside the engine's data class and horizon. |

## 4. Conflict rows

| Field | Value |
|---|---|
| Conflict ID | RL-CONFLICT-01 |
| Claims | RL-SWING-01-C01/C02 (E1, positive: VGRSI swing signals profitable on EUR/USD 2024–2025) vs RL-SWING-02-C01/C03 (E2, negative: short-term trend broke post-2009; self-fulfilling impact loop) + RL-SWING-03-C03 (E2, null: ultra-short signals contested) |
| SuperCents_X assumption | Swing/BOS trend-continuation signals carry persistent edge |
| Directions | positive vs negative/null |
| Evidence asymmetry | Asymmetric — E1 (single paper, 503 days 2024–2025, walk-forward with 30-day optimization) vs E2 (multi-asset futures 1995–2025, CTA evidence) |
| ED-sequence relation | ED01-B: no distinct BOS edge (E1, FX) — supports the negative side |
| Resolution | UNRESOLVED — experiment needed: swing-gated trend entries vs 2.0R on EURUSD H1 |

| Field | Value |
|---|---|
| Conflict ID | RL-CONFLICT-02 |
| Claims | RL-CHOCH-02-C01/C02/C03 (E3, positive: regime-probability-embedded adaptive policies improve profitability and robustness in simulation) vs fixed-policy design assumptions (frozen floors/weights/2.0R; RL-SWING-02-C01 era-decay, RL-SWING-04-C02 cost ceiling) |
| SuperCents_X assumption | Fixed floors, weights, 2.0R across regimes |
| Directions | adaptive-positive vs fixed-null |
| Evidence asymmetry | Symmetric weakness — E3 (simulation) vs E2 (era/cost evidence) |
| ED-sequence relation | ED01-E: no alternative tier beats fixed 2.0R (E1) — supports fixed policy |
| Resolution | UNRESOLVED — experiment needed only if literature independently justifies adaptive exits (not yet) |

| Field | Value |
|---|---|
| Conflict ID | RL-CONFLICT-03 |
| Claims | RL-FVG-02-C01/C02 (E2, positive: gaps/depth drive price impact) vs RL-FVG-03-C02 (E2, null: gap classifier not tradeable) |
| SuperCents_X assumption | FVG zones attract price and carry tradable edge |
| Directions | positive vs null |
| Evidence asymmetry | Symmetric — both E2, different markets (equities vs MNQ) |
| ED-sequence relation | ED01-B: FVG no distinct edge (E1, FX) — supports the null side |
| Resolution | UNRESOLVED — experiment needed if any FVG-specific mechanism is pre-registered |

| Field | Value |
|---|---|
| Conflict ID | RL-CONFLICT-04 |
| Claims | RL-OB-01-C01/C02 (E2, positive: imbalance construction explains price changes; R² 83.57–86.01% at 30s/1m/5m) vs RL-SWING-04-C01/C02 (E2, null: OHLCV signals fail cost-aware gates) |
| SuperCents_X assumption | OB detector (OHLC displacement proxy) carries short-horizon edge at H1/M15 |
| Directions | positive (mechanism) vs null (data class, cost ceiling) |
| Evidence asymmetry | Symmetric — all E2 |
| ED-sequence relation | ED01-B: ORDER_BLOCK nClosed = 0 in decomposition (E1) — supports the null side |
| Resolution | UNRESOLVED — experiment needed only if a tradable OB mechanism is pre-registered |

## 5. Topic summary

| Topic | papers | P-level counts | E-level counts | claims | directions (pos/neg/null/not-stated) | intra-topic conflicts |
|---|---|---|---|---|---|---|
| BOS | 3 | P2:2, P3:1 | E2:2, E3:4 | 6 | pos 3 / neg 1 / null 0 / not-stated 2 | none (S/R re-bounce vs BOS-continuation — RL-CONFLICT-01 cross-topic) |
| SWING | 4 | P2:4 | E1:3, E2:9 | 12 | pos 3 / neg 2 / null 5 / not-stated 2 | RL-CONFLICT-01 (swing profitability vs trend decay) |
| CHOCH | 5 | P1:1, P2:4 | E2:5, E3:6 | 11 | pos 9 / neg 0 / null 0 / not-stated 2 | none |
| OB | 5 | P2:5 | E2:5, E3:6 | 11 | pos 9 / neg 0 / null 0 / not-stated 2 | RL-CONFLICT-04 (mechanism vs data class) |
| FVG | 3 | P2:3 | E2:8 | 8 | pos 4 / neg 0 / null 2 / not-stated 2 | RL-CONFLICT-03 (structure vs tradability) |
| LIQUIDITY | 4 | P1:1, P2:2, P4:1 | E2:1, E3:5, E4:2 | 8 | pos 3 / neg 0 / null 0 / not-stated 5 | none |
| SMC | 4 | P1:1, P2:3 | E2:5, E3:3 | 8 | pos 6 / neg 1 / null 0 / not-stated 1 | none |
| README (docs) | 8 | — | — | 0 | — | none |
| **Total** | **36** | **P1:3, P2:23, P3:1, P4:1 (28 papers)** | **E1:3, E2:35, E3:24, E4:2, E5:0** | **64** | **pos 37 / neg 4 / null 7 / not-stated 16** | **4 rows** |

Note: RL-OB-04-C02 carries the only UNSUPPORTED evidence tag (the paper itself disclaims real-market confirmation of the square-root-law mechanism) — counted in E3 column above; tag column tallies in §6. Counts reflect the 2026-08-10 verification pass (claims re-derived from verified abstracts).

## 6. Phase 2 self-check

| Check | Result |
|---|---|
| All 36 files have entries (included / out-of-scope / no-claim) | PASS — 28 papers INCLUDED + 8 READMEs NO-CLAIM |
| Every claim row has all mandatory fields | PASS — 64 claim rows, all 12 fields populated |
| Every row carries exactly one evidence tag | PASS — 64/64 rows: EMPIRICAL 47, THEORETICAL 14, INTERPRETATION 2, UNSUPPORTED 1 (RL-OB-04-C02) |
| No mapping row has an empty Gap cell (NONE is explicit) | PASS — 64/64 explicit |
| Verbatim anchors present on all claim rows | PASS — 64/64 quoted from verified extraction text (see annotation; initial draft anchors for 28 rows were paraphrased/fabricated and have been replaced) |

## 7. Phase 3 synthesis input table (auto-aggregated)

| Mechanism area | claims (IDs) | E-levels | direction agreement | tier |
|---|---|---|---|---|
| Swing/trend continuation | RL-SWING-01-C01/C02/C03, RL-SWING-02-C01/C02/C03, RL-SWING-03-C01/C02/C03, RL-SWING-04-C01/C02/C03, RL-BOS-01-C01/C02, RL-BOS-02-C01/C02, RL-BOS-03-C01/C02 | E1:3, E2:11, E3:4 | split — E1 positive (VGRSI EUR/USD) vs E2 era-decay + OHLCV limits + S/R re-bounce | Phase 3 |
| Change detection (CHOCH) | RL-CHOCH-01-C01/C02, RL-CHOCH-02-C01/C02/C03, RL-CHOCH-03-C01/C02, RL-CHOCH-04-C01/C02, RL-CHOCH-05-C01/C02 | E2:5, E3:6 | predominantly positive feasibility/identifiability; no negative; adaptive-policy evidence only E3 | Phase 3 |
| Imbalance/order flow (OB) | RL-OB-01-C01/C02/C03, RL-OB-02-C01/C02, RL-OB-03-C01/C02, RL-OB-04-C01/C02, RL-OB-05-C01/C02 | E2:5, E3:6 | mechanism-positive, data-boundary (OHLCV cannot observe flow) | Phase 3 |
| Gap/imbalance zones (FVG) | RL-FVG-01-C01/C02/C03, RL-FVG-02-C01/C02/C03, RL-FVG-03-C01/C02 | E2:8 | structure-positive vs tradability-null | Phase 3 |
| Liquidity | RL-LIQ-01-C01/C02, RL-LIQ-02-C01/C02, RL-LIQ-03-C01/C02, RL-LIQ-04-C01/C02 | E2:1, E3:5, E4:2 | mixed descriptive | Phase 3 |
| Smart Money / informed flow (SMC) | RL-SMC-01-C01/C02, RL-SMC-02-C01/C02, RL-SMC-03-C01/C02, RL-SMC-04-C01/C02 | E2:5, E3:3 | not testable from OHLCV (data boundary) | Phase 3 |

Tier assignment deferred to Phase 3 synthesis (protocol §15). This table is the aggregation input only.

## 8. Phase 4 shortlist candidate (pre-registration seed — protocol §16)

| Field | Value |
|---|---|
| Candidate ID | RL-HYP-01 |
| Hypothesis | Swing-gated trend entries on EURUSD H1 outperform the fixed 2.0R benchmark (from RL-SWING-01-C01/C02, E1 positive; tested against RL-SWING-02-C01/C03 and RL-BOS-03-C01, E2 negative) |
| Null hypothesis | Δ = 0 between swing-gated entry policy and the 2.0R benchmark on EURUSD H1 |
| Independent variable | Swing-significance gate on entries (on/off) |
| Dependent variable | meanR / win rate / PF (ED01 metrics) |
| Population | EURUSD H1, ED01-E window & strata |
| Required telemetry | NOT-IMPLEMENTED (swing-gate telemetry absent) |
| Control | frozen B8 CONTROL — fixed 2.0R benchmark |
| Treatment | swing-gated entries + fixed 2.0R exits |
| OOS requirement | M15 (EURUSD) + GBPJPY H1/M15 |
| Materiality threshold | |Δ| ≥ 0.10 R (ED01 scale) |
| Statistical test | paired bootstrap mean difference + CI (ED01-E method) |
| Failure condition | CI includes 0 or |Δ| < 0.10 R → REJECT |
| Expected engineering scope | MODERATE (entry-planner gate + TDD+TT01) |
| Conflict flags | RL-CONFLICT-01 (decay vs predictiveness) carried |
| Selection status | NOT-SELECTED (user decides, Sprint 22+) |

---

## Appendix — Registered observations (not hypotheses)

Existing empirical observations entered here, explicitly NOT promoted (protocol §16):

| Observation ID | Source | Finding | n / days | Reproduction | Status |
|---|---|---|---|---|---|
| RL-OBS-01 | ED01-E (2026-08-09) | H1 UNKNOWN-family: 2.5R Δ +0.1197 CI [0.0478, 0.1935]; 3.0R Δ +0.1967 CI [0.0285, 0.3517] | 117 / 20 | NOT reproduced on M15 (n=49); GBPJPY n=23 n-constrained | REPORTED-NOT-WEIGHED — hypothesis only if the literature independently justifies a UNKNOWN-family mechanism, then pre-registered (§16) |

RL-OBS-01 stays reported-not-weighed: the Phase 2 literature review produced NO independent justification of a UNKNOWN-family mechanism (no paper in this ledger supports a family-agnostic imbalance mechanism distinct from BOS/CHOCH/FVG/OB/LIQ). Per protocol §16, RL-OBS-01 is NOT promoted to a hypothesis.

---

*Ledger populated 2026-08-10 (Phase 2). Append-only. Next: Phase 3 synthesis (separate step, not yet started).*
