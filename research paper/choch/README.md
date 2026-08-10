# CHoCH / MSS — Change of Character (Market Structure Shift)

## What it is (retail / Smart Money Concepts terminology)
A **Change of Character (CHoCH)**, a.k.a. **Market Structure Shift (MSS)**, is the FIRST counter-trend break of a swing extreme inside an established trend. In a bearish trend, price making a close *above* the latest protected swing-high triggers a **bullish CHoCH** — an early warning the downtrend *may* be reversing. Unlike a BOS (continuation), CHoCH is a **reversal** signal, and is the trigger used to enter against the prior trend (often into an order block). It corresponds to Wyckoff's original "change of character" (a behavioural shift in accumulation/distribution).

## Academic analog
There is no peer-reviewed paper defining "CHoCH". The formal academic cousins are **change-point / regime-switching detection** and **trend-reversal (state transition) modelling** — algorithms that detect when the statistical regime driving price has shifted.

## Papers in this folder
1. **1001.2549 — Segmentation algorithm for non-stationary compound Poisson processes (Toth, Lillo, Farmer)**
   A non-parametric algorithm that segments a time series into distinct regimes ("patches") and detects the change points between them — a rigorous stand-in for identifying where market "character" shifts.
2. **2511.00190 — Deep reinforcement learning for optimal trading with partial information (Macrì, Jaimungal, Lillo)**
   Models the trading signal as an Ornstein-Uhlenbeck process with **hidden regime-switching dynamics** and shows how embedding regime-probability estimates improves trading — the quantitative framework behind "the market has changed character".

## Additional papers (batch 2)
3. **0705.0503 — Change point estimation for the telegraph process observed at discrete times (De Gregorio, Iacus)**
   Consistent change-point estimation for direction-switching random motion — a rigorous 'when did the state flip' problem, the statistical essence of a CHoCH/MSS.
4. **2605.29541 — Change-point estimation for Weibull time series with copula-based Markov models**
   Offline change-point detection for nonlinear, dependent time series — general methodology for spotting structural breaks in financial/volatility series.
5. **2204.00872 — Calibration window selection based on change-point detection for forecasting electricity prices (Nasiadka, Nitka, Weron)**
   Uses the NOT change-point algorithm to select the relevant data regime — practical regime/character-switch identification shown on real price series.
