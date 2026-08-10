# Liquidity — Market Liquidity

## What it is (retail / Smart Money Concepts terminology)
In SMC/ICT, **liquidity** refers to pools of resting *stop-loss orders* and pending orders clustered just beyond swing highs/lows. Institutions are said to "hunt" or "sweep" this liquidity — spiking price into these clusters to fill large orders — before reversing. The **liquidity sweep / stop hunt** (taking out the highs/lows) is therefore a key event used to anticipate reversals and entries. This is the "why" behind many SMC structures (displacement after a sweep).

## Academic analog
Academic **market liquidity** is the measurable ability to trade an asset without moving its price too much — proxied by depth, tightness (spread), resiliency and volume. While academia doesn't model "stop-hunt manipulation" the way SMC does, the same order-book liquidity mechanics are rigorously studied.

## Papers in this folder
1. **1112.6169 — Measuring market liquidity: An introductory survey**
   The classic survey of how to define and measure liquidity (depth, tightness, resiliency, volume) — the proper quantitative vocabulary behind "where is the liquidity".
2. **2310.09273 — Uncovering Market Disorder and Liquidity Trends Detection (Chevalier, Hafsi, Ly Vath)**
   Dynamically quantifies order-book liquidity and detects significant shifts in it using marked Hawkes processes — a formal method for spotting liquidity "sweeps"/regime changes in real time.
3. **2010.13038 — Analysis of the Impact of High-Frequency Trading on Artificial Market Liquidity (Yagi, Masuda, Mizuta)**
   Agent-based comparison of major liquidity indicators — shows how liquidity provision/depletion (the 'who provides what is available') behaves, including the execution-rate dimension relevant to sweep dynamics.

## Additional papers (batch 2)
4. **1309.5235 — Optimal Liquidity Provision (Kühn, Muhle-Karbe)**
   Classic dynamic model of a liquidity provider posting at best bid/ask with general mid-price, spread and order-flow dynamics — the optimal 'where to stand' behind market liquidity.
