# OB — Order Blocks

## What it is (retail / Smart Money Concepts terminology)
An **Order Block (OB)** is the last opposing candle(s) before a strong, displaced move (the "footprint" of a large institutional order resting in the order book). Under a strict SMC definition, an OB must show: (1) displacement (a large body, 1.5–3× the average), (2) a structural break (BOS/MSS) confirming the move, and (3) unmitigated status — price has not yet returned to consume it. Price is expected to **react/retrace to the OB** before continuing, making OBs preferred entry (buy) zones. An OB without displacement or structural break does not qualify.

## Academic analog
Order blocks are retail vocabulary, but they map to **order-flow / order-book imbalance and order placement** research — the empirical reality that concentrated order flow and book imbalances drive and explain short-term price moves (the "institutional footprint").

## Papers in this folder
1. **2112.02947 — The Price Impact of Generalized Order Flow Imbalance (Su, Sun, Li, Yuan)**
   Shows that order-flow imbalance (a metricable proxy for one-sided "smart" flow) explains a large share of short-term price change — the force that carves out order-block reactions.
2. **2510.08085 — A Deterministic Limit Order Book Simulator with Hawkes-Driven Order Flow (El Karmi)**
   A reproducible limit-order-book simulator with Hawkes order flow — how to model and test the resting-order dynamics behind price levels (order-block behaviour).
3. **2601.23172 — Order flow, market impact, and volatility (Muhle-Karbe, Ouazzani Chahdi, Rosenbaum, Szymanski)**
   A microstructural model reconciling persistent signed order flow, rough volume/volatility and power-law market impact with one parameter — theoretical grounding for how concentrated flow moves price.

## Additional papers (batch 2)
4. **2607.04280 — Order Splitting and Liquidity Replenishment Are Jointly Necessary for the Square-Root Law of Market Impact (Zhou, Chen, Wei)**
   Uses a heterogeneous limit-order-book model to identify which mechanisms (order splitting, liquidity replenishment) actually produce market impact — the institutional footprint behind order blocks.
5. **2608.00885 — Optimal Trading of Microstructure Mean Reversion**
   Builds an order book whose own flow creates a stationary mid-price error and derives optimal trading around it — how resting-flow imbalance (order-block dynamics) is traded profitably.
