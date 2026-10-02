//+------------------------------------------------------------------+
//|                            TestIntegrityFixes.mqh                |
//|                                      Copyright 2026, SuperCents_X|
//|                                              Sprint 25B integrity|
//+------------------------------------------------------------------+
//  Integrity-fix acceptance tests (C1..C7, H7).
//
//    C1: stable magic number (no TimeCurrent derivation; survives Init)
//    C2: position sizing monotonicity + clamps
//    C3: position gate helper (no magic-matched open positions)
//    C4: closed-bar discipline (FVG triple never uses the forming bar)
//    C5: bare ConfluenceEngine -> no signals, pool does not grow
//    C6: directional SL/TP validation vs fill price
//    C7: fill price resolution + sizing-at-fill (wider stop -> smaller lots)
//    H7: risk-per-lot formula sanity within the C2 sizing path
//+------------------------------------------------------------------+
#ifndef __TEST_INTEGRITY_FIXES_MQH__
#define __TEST_INTEGRITY_FIXES_MQH__

#include "../TestAssert.mqh"
#include "../../Core/Config.mqh"
#include "../../Risk/PositionSizer.mqh"
#include "../../Trading/TradeValidation.mqh"
#include "../../Structure/FVGDetector.mqh"
#include "../../Confluence/ConfluenceEngine.mqh"
#include "../../Trading/TradeManager.mqh"

//--- C4 local helper: maps an oldest->newest table of n bars into series
//    arrays (index 0 = newest), matching the detector's expectations.
void IntegFillSeries(double &sOpen[], double &sHigh[], double &sLow[],
                            double &sClose[], datetime &sTime[],
                            const double &o[], const double &h[], const double &l[],
                            const double &c[], const datetime &t[], int n)
{
    ArrayResize(sOpen, n); ArrayResize(sHigh, n); ArrayResize(sLow, n);
    ArrayResize(sClose, n); ArrayResize(sTime, n);
    ArraySetAsSeries(sOpen, true); ArraySetAsSeries(sHigh, true);
    ArraySetAsSeries(sLow, true); ArraySetAsSeries(sClose, true); ArraySetAsSeries(sTime, true);
    for(int i = 0; i < n; i++)
    {
        int src = n - 1 - i;
        sOpen[i]  = o[src];
        sHigh[i]  = h[src];
        sLow[i]   = l[src];
        sClose[i] = c[src];
        sTime[i]  = t[src];
    }
}

//--- C1: stable, deterministic magic number ---------------------------------
void TestC1StableMagic(TestCounters &counters)
{
    SUITE_BEGIN("C1 - stable magic number");

    CConfig cfg;
    TEST_TRUE(cfg.Init(), "C1a: config init succeeds");
    TEST_INT_EQ(0, cfg.GetMagicNumber(), "C1b: default magic is 0 (TimeCurrent derivation removed)");

    // An explicitly set magic must survive Init() (Init no longer overwrites
    // with (int)TimeCurrent()).
    cfg.SetMagicNumber(27182819);
    TEST_TRUE(cfg.Init(), "C1c: config re-init does not reset magic");
    TEST_INT_EQ(27182819, cfg.GetMagicNumber(), "C1d: explicit magic preserved through Init");

    CConfig cfg2;
    cfg2.SetMagicNumber(999);
    TEST_INT_EQ(999, cfg2.GetMagicNumber(), "C1e: SetMagicNumber before Init sticks");

    SUITE_END("C1 - stable magic number");
}

//--- C2 + H7: position sizing monotonicity / clamps / formula ----------------
void TestC2RiskMonotonicAndClamp(TestCounters &counters)
{
    SUITE_BEGIN("C2 - risk sizing monotonicity and clamps (H7 formula)");

    CPositionSizer sizer;

    // idempotent params: tickValue=1, tickSize=point=1e-5, vol [0.01..100],
    // step 0.01, equity 10000 -> riskPerLot = 500 pts * 1 / (1e-5/1e-5) = 500.
    PositionSizingResult r05 = sizer.Calculate(0.5, 500.0, 10000.0, 1.0, 0.00001, 0.00001, 0.01, 100.0, 0.01);
    PositionSizingResult r10 = sizer.Calculate(1.0, 500.0, 10000.0, 1.0, 0.00001, 0.00001, 0.01, 100.0, 0.01);
    PositionSizingResult r20 = sizer.Calculate(2.0, 500.0, 10000.0, 1.0, 0.00001, 0.00001, 0.01, 100.0, 0.01);

    TEST_TRUE(r05.valid && r10.valid && r20.valid, "C2a: sizing valid for 0.5/1.0/2.0%");
    TEST_TRUE(r05.lots > 0.0 && r10.lots > 0.0 && r20.lots > 0.0, "C2b: non-zero lots produced");

    // Monotonicity: more risk percent -> more lots.
    TEST_TRUE(r05.lots < r10.lots, "C2c: 0.5% < 1.0% lots");
    TEST_TRUE(r10.lots < r20.lots, "C2d: 1.0% < 2.0% lots");
    TEST_TRUE(r10.lots > r05.lots * 1.5, "C2e: 1.0% meaningfully > 0.5%");
    TEST_TRUE(r20.lots > r10.lots * 1.5, "C2f: 2.0% meaningfully > 1.0%");

    // H7 sanity: riskPerLot = stopDistPoints * tickValue / (tickSize / point).
    // 500 * 1 / (1e-5/1e-5) = 500; 1% of 10000 = 100 -> 100/500 = 0.20 lots.
    TEST_TRUE(r10.lots > 0.15 && r10.lots < 0.25, "H7a/C2g: 1%@500pts yields ~0.20 lots (formula check)");

    // Stop distance at fill: wider stop -> SMALLER lots for the same risk.
    PositionSizingResult rWide = sizer.Calculate(1.0, 1000.0, 10000.0, 1.0, 0.00001, 0.00001, 0.01, 100.0, 0.01);
    TEST_TRUE(rWide.valid, "C7a-bi: wide-stop sizing valid");
    TEST_TRUE(rWide.lots < r10.lots, "C7b-bi: wider stop at fill -> smaller lots");

    // P37: sub-minimum volume REJECTS (no silent floor-clamp to volumeMin,
    // which would over-risk). 0.01% of 10000 = $1 vs $500/lot -> 0.002 lots.
    PositionSizingResult rTiny = sizer.Calculate(0.01, 500.0, 10000.0, 1.0, 0.00001, 0.00001, 0.01, 100.0, 0.01);
    TEST_FALSE(rTiny.valid, "C2h-P37: sub-minimum lots rejected, not floored");

    // Volume ceiling.
    PositionSizingResult rHuge = sizer.Calculate(100.0, 5.0, 10000.0, 1.0, 0.00001, 0.00001, 0.01, 100.0, 0.01);
    if(rHuge.valid)
        TEST_TRUE(rHuge.lots <= 100.0, "C2i: lots capped at volume max (100)");

    SUITE_END("C2 - risk sizing monotonicity and clamps (H7 formula)");
}

//--- C3: position gate helper -------------------------------------------------
void TestC3PositionGate(TestCounters &counters)
{
    SUITE_BEGIN("C3 - position gate helper");

    CTradeManager manager;
    manager.SetSymbol(_Symbol);
    manager.SetMagicNumber(27182819);
    TEST_TRUE(manager.Init(), "C3a: TradeManager init");

    // No positions may exist under this fresh magic yet.
    int openCount = manager.GetOpenPositionCount();
    TEST_TRUE(openCount == 0, "C3b: zero open positions for fresh magic (" + IntegerToString(openCount) + ")");

    // Input clamping: cap >= 1, risk >= 0.
    manager.SetMaxPositionsPerSymbol(0);
    TEST_INT_EQ(1, manager.GetMaxPositionsPerSymbol(), "C3c: max positions clamped to >= 1");

    manager.SetRiskPercent(-5.0);
    TEST_TRUE(manager.GetRiskPercent() >= 0.0, "C3d: risk percent clamped to >= 0");

    manager.SetRiskPercent(2.5);
    TEST_TRUE(MathAbs(manager.GetRiskPercent() - 2.5) < 1e-12, "C3e: risk percent accepted 2.5");
    manager.Shutdown();

    SUITE_END("C3 - position gate helper");
}

//--- C4: FVG closed-bar discipline -------------------------------------------
//  Synthetic series arrays (index 0 = forming/newest bar).
//  Scan rules (verified against FVGDetector): fresh scan i = rates_total-1
//  down to end_i = 3; cursor = time[1] (last CLOSED bar); duplicates are
//  rejected by fvgTime (the middle/displacement bar's time).
void TestC4FVGClosedBarOnly(TestCounters &counters)
{
    SUITE_BEGIN("C4 - FVG closed-bar discipline");

    //--- Test A: a bearish gap exists ONLY in the forming triple (2,1,0).
    //    With the C4 fix the scan stops at (3,2,1), so 0 FVGs are produced.
    //    Old code (end_i = 2) evaluated (2,1,0) and produced 1 FVG.
    //    Table (oldest -> newest; forming bar = last element):
    double oA[6] = {1.0960, 1.0965, 1.0960, 1.0990, 1.0975, 1.0965};
    double hA[6] = {1.0985, 1.0985, 1.0955, 1.1020, 1.0995, 1.0970};
    double lA[6] = {1.0925, 1.0940, 1.0900, 1.0980, 1.0955, 1.0940};
    double cA[6] = {1.0950, 1.0955, 1.0930, 1.1010, 1.0985, 1.0945};
    datetime baseTime = D'2026.03.01 00:00';
    datetime tA[6] = {baseTime, baseTime + 900, baseTime + 1800, baseTime + 2700, baseTime + 3600, baseTime + 4500};

    double sOpen[], sHigh[], sLow[], sClose[];
    datetime sTime[];
    IntegFillSeries(sOpen, sHigh, sLow, sClose, sTime, oA, hA, lA, cA, tA, 6);

    CFVGDetector fvgA;
    TEST_TRUE(fvgA.Init(), "C4a-0: FVG detector init (A)");
    fvgA.Update(sOpen, sHigh, sLow, sClose, sTime, 6, NULL);
    TEST_INT_EQ(0, fvgA.GetFVGCount(), "C4a: forming-bar gap never scanned (closed bars only)");
    fvgA.Shutdown();

    //--- Test B: a bearish gap inside the newest CLOSED triple (3,2,1) IS
    //    detected; fvg.time must be the middle bar of that triple (table idx 2).
    //    Table B (oldest -> newest):
    //      idx0 bear (filler)   idx1 bull (A)   idx2 bear (B/middle)
    //      idx3 bear (C)        idx4 bull (forming, excluded)
    double oB[5] = {1.0960, 1.0990, 1.0980, 1.0965, 1.1000};
    double hB[5] = {1.0965, 1.1020, 1.0985, 1.0970, 1.1025};
    double lB[5] = {1.0925, 1.0980, 1.0950, 1.0930, 1.0990};
    double cB[5] = {1.0940, 1.1010, 1.0970, 1.0945, 1.1020};
    datetime tB[5] = {baseTime, baseTime + 900, baseTime + 1800, baseTime + 2700, baseTime + 3600};

    IntegFillSeries(sOpen, sHigh, sLow, sClose, sTime, oB, hB, lB, cB, tB, 5);

    CFVGDetector fvgB;
    TEST_TRUE(fvgB.Init(), "C4b-0: FVG detector init (B)");
    fvgB.Update(sOpen, sHigh, sLow, sClose, sTime, 5, NULL);
    TEST_INT_EQ(1, fvgB.GetFVGCount(), "C4b: exactly one FVG in newest closed triple");

    FairValueGap gap;
    if(fvgB.GetFVG(0, gap))
    {
        TEST_DATETIME_EQ(tB[2], gap.time, "C4b-t: fvg.time == middle bar of the closed triple");
        TEST_FALSE(gap.bullish, "C4b-d: detected FVG is bearish");
    }
    else
        TEST_TRUE(false, "C4b-g: failed to retrieve FVG(0)");

    //--- Test C: cursor advance on a NEW forming bar (bars only ever append
    //    at the newest end). Frame 2 = original 5 bars + 1 new forming bar.
    //    scan i=3 evaluates the just-closed former-forming triple (B2,B3,B4):
    //    A=B2 bear, C=B4 bull -> gap = low[B4] vs high[B2]; with low[B4]
    //    equal to high[B2]=1.0985 no new FVG is created => count stays 1
    //    (the first FVG's fvgTime is unchanged and is not re-added).
    double oC[6] = {1.0960, 1.0990, 1.0980, 1.0965, 1.1000, 1.1015};
    double hC[6] = {1.0965, 1.1020, 1.0985, 1.0970, 1.1025, 1.1035};
    double lC[6] = {1.0925, 1.0980, 1.0950, 1.0930, 1.0985, 1.1002};
    double cC[6] = {1.0940, 1.1010, 1.0970, 1.0945, 1.1020, 1.1025};
    datetime tC[6] = {baseTime, baseTime + 900, baseTime + 1800, baseTime + 2700,
                      baseTime + 3600, baseTime + 4500};

    IntegFillSeries(sOpen, sHigh, sLow, sClose, sTime, oC, hC, lC, cC, tC, 6);

    fvgB.Update(sOpen, sHigh, sLow, sClose, sTime, 6, NULL);
    TEST_INT_EQ(1, fvgB.GetFVGCount(), "C4c: count stable after cursor advance (no duplicate)");
    fvgB.Shutdown();

    SUITE_END("C4 - FVG closed-bar discipline");
}

//--- C5: no CONFLUENCE_NONE signals ------------------------------------------
void TestC5NoNoneSignals(TestCounters &counters)
{
    SUITE_BEGIN("C5 - signal lifecycle (directional only, bounded pool)");

    CConfluenceEngine engine;
    TEST_TRUE(engine.Init(), "C5a: ConfluenceEngine init (bare, no detectors)");

    for(int i = 0; i < 20; i++)
        engine.Update();

    TEST_INT_EQ(0, engine.GetSignalCount(), "C5b: no signals created for direction-less bars");

    ConfluenceResult latest;
    TEST_FALSE(engine.GetLatestConfluence(latest), "C5c: no latest confluence without signals");

    engine.Shutdown();
    SUITE_END("C5 - signal lifecycle (no CONFLUENCE_NONE signals, bounded pool)");
}

//--- C6: directional SL/TP validation vs fill price --------------------------
void TestC6DirectionalStops(TestCounters &counters)
{
    SUITE_BEGIN("C6 - directional SL/TP validation vs fill price");

    CTradeValidation validation;
    validation.SetSymbol(_Symbol);

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    string reason = "";

    ExecutionPlan plan;
    plan.orderType   = ORDER_TYPE_BUY;
    plan.entryPrice  = ask;               // entry itself is irrelevant now
    plan.stopLoss    = ask + 0.0040;      // stop ABOVE fill -> must reject
    plan.takeProfit  = ask + 0.0080;
    TEST_FALSE(validation.AreStopsValid(plan, reason), "C6a: BUY stop above fill rejected");

    plan.stopLoss   = ask - 0.0080;
    plan.takeProfit = ask - 0.0040;       // target BELOW fill -> must reject
    TEST_FALSE(validation.AreStopsValid(plan, reason), "C6b: BUY take-profit below fill rejected");

    plan.stopLoss   = ask - 0.0040;       // valid BUY bracket
    plan.takeProfit = ask + 0.0080;
    TEST_TRUE(validation.AreStopsValid(plan, reason), "C6c: valid BUY bracket accepted");

    plan.orderType  = ORDER_TYPE_SELL;
    plan.entryPrice = bid;
    plan.stopLoss   = bid - 0.0040;       // stop BELOW fill -> must reject
    plan.takeProfit = bid - 0.0080;
    TEST_FALSE(validation.AreStopsValid(plan, reason), "C6d: SELL stop below fill rejected");

    plan.stopLoss   = bid + 0.0080;
    plan.takeProfit = bid + 0.0040;       // target ABOVE fill -> must reject
    TEST_FALSE(validation.AreStopsValid(plan, reason), "C6e: SELL take-profit above fill rejected");

    plan.stopLoss   = bid + 0.0040;       // valid SELL bracket
    plan.takeProfit = bid - 0.0080;
    TEST_TRUE(validation.AreStopsValid(plan, reason), "C6f: valid SELL bracket accepted");

    // Unsupported order type: no fill price -> rejected.
    plan.orderType = (ENUM_ORDER_TYPE)999;
    TEST_FALSE(validation.AreStopsValid(plan, reason), "C6g: unsupported order type rejected");

    SUITE_END("C6 - directional SL/TP validation vs fill price");
}

//--- C7: execution price consistency ------------------------------------------
void TestC7FillPrice(TestCounters &counters)
{
    SUITE_BEGIN("C7 - execution price consistency");

    CTradeValidation validation;
    validation.SetSymbol(_Symbol);

    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    double fillBuy  = validation.GetFillPrice(ORDER_TYPE_BUY);
    double fillSell = validation.GetFillPrice(ORDER_TYPE_SELL);
    TEST_DBL_EQ(ask, fillBuy, "C7a: BUY fill price == ASK");
    TEST_DBL_EQ(bid, fillSell, "C7b: SELL fill price == BID");
    TEST_TRUE(fillBuy >= bid, "C7c: ASK >= BID");
    TEST_DBL_EQ(0.0, validation.GetFillPrice((ENUM_ORDER_TYPE)999), "C7d: unknown order type -> no fill price");

    SUITE_END("C7 - execution price consistency");
}

//--- Runner -------------------------------------------------------------------
TestCounters RunIntegrityFixTests(void)
{
    TestCounters counters;
    TestC1StableMagic(counters);
    TestC2RiskMonotonicAndClamp(counters);
    TestC3PositionGate(counters);
    TestC4FVGClosedBarOnly(counters);
    TestC5NoNoneSignals(counters);
    TestC6DirectionalStops(counters);
    TestC7FillPrice(counters);
    return counters;
}

#endif // __TEST_INTEGRITY_FIXES_MQH__