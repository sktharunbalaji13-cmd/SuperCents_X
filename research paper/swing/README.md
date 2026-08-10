# Swing — Swing Points / Swing Trading

## What it is (retail / Smart Money Concepts terminology)
**Swings** are the local turning points (higher/lower highs and lows) that define market structure. In trading systems a **swing high/low** is typically a bar whose high/low is higher/lower than a set number of bars on both sides (a fractal / local extremum with a look-back window). Swing trading means taking positions to capture the medium-term move *between* swing points, rather than intraday noise. Accurate swing detection is the foundation for BOS, CHoCH and order-block structures — everything downstream depends on where the swings are drawn.

## Academic analog
The academic equivalent is **local-extrema / turning-point detection**, **short-term technical analysis**, and **trend-following / momentum** on swing-to-swing horizons.

## Papers in this folder
1. **2605.01300 — Visibility graphs can make money in financial markets (R. Rak)**
   Uses the geometric "visibility" structure between price bars (a rigorous formalisation of swing relationships) to build a short-term relative-strength indicator that generates profitable, low-drawdown signals — direct academic handling of swing structure.
2. **2607.01550 — Is Trend Still Your Friend?: A Microstructural Account of the Demise of Short-Term Trend-Following (Kurth, Eisler, Rej, Bouchaud)**
   Analyses two centuries of trend-following/swing-horizon profitability and why short-term swing-capture decayed post-2009 (tick-size microstructure) — essential context for swing trading edge and its limits.

## Additional papers (batch 2)
3. **2507.15876 — Re-evaluating Short- and Long-Term Trend Factors in CTA Replication: A Bayesian Graphical Approach (Benhamou et al.)**
   Dynamically decomposes trend/CTA returns into short-term vs long-term breakout horizons with a Bayesian graphical model — how the *horizon blend* (swing length) shapes performance.
4. **2605.04004 — Structural Limits of OHLCV-Based Intraday Signals in MNQ Futures: A Systematic Falsification Study (M. Mesfin)**
   Rigorously tests 14 intraday momentum/swing signal families (incl. gap continuation) under realistic costs and shows where they fail — a valuable reality-check on swing-signal edges.
