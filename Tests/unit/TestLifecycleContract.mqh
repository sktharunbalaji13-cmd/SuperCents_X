//+------------------------------------------------------------------+
//|                                        TestLifecycleContract.mqh |
//|                    Sprint 20 - LC01: lifecycle contract (AVP E11)|
//|                                                                  |
//| These tests pin the CURRENT lifecycle contract of every detector |
//| that drives E11 (StructuralPivotEngine freeze on history shrink).|
//| The contract is specified in docs/Sprint20_State_Lifecycle_      |
//| Contract.md; violations become RED->GREEN in LC02 (rates_total   |
//| shrink handler) / LC03 (downstream cursor re-sync).              |
//|                                                                  |
//| Conventions: FVG fixtures use MT5 order (index 0 = NEWEST bar,   |
//| time[] descending) as the detector expects; swing fixtures are   |
//| chronological (index 0 = oldest) as SwingDetector only does      |
//| neighbour comparisons.                                           |
//+------------------------------------------------------------------+
#ifndef __TEST_LIFECYCLE_CONTRACT_MQH__
#define __TEST_LIFECYCLE_CONTRACT_MQH__

#include "../../Structure/FVGDetector.mqh"
#include "../../Structure/SwingDetector.mqh"
#include "../TestAssert.mqh"

//--- Shared FVG fixture builders (MT5 order: index 0 = newest bar).
//--- FVGDetector.mqh:138-168 lifecycle clauses:
//---   m_lastProcessedTime==0  -> full scan from newest (start_i=rates_total-1)
//---   time[0] < cursor        -> time discontinuity -> rescan full history
//---   time[0] == cursor       -> no-op
//---   time[0] > cursor        -> delta: count new bars, start_i=min(newBars+2, rates_total-1)

//--- History A: 6 bars ending 2024.01.01 05:00, newest first.
//--- Produces exactly ONE bearish FVG at bar 02:00 (displacement bar 01:00):
//--- triplet A=bar4 (bull) B=bar3 C=bar2 (bear), gap low[4]=1.0920 > high[2]=1.0900.
void LCBuildFVGHistoryA(double &open[], double &high[], double &low[],
                        double &close[], datetime &time[], int &rates)
{
    rates = 6;
    ArrayResize(open, rates);
    ArrayResize(high, rates);
    ArrayResize(low, rates);
    ArrayResize(close, rates);
    ArrayResize(time, rates);

    //--- newest (index 0) -> oldest (index 5)
    //    05:00 bear
    open[0] = 1.0860; high[0] = 1.0860; low[0] = 1.0840; close[0] = 1.0840; time[0] = D'2024.01.01 05:00';
    //    04:00 bear
    open[1] = 1.0880; high[1] = 1.0880; low[1] = 1.0860; close[1] = 1.0860; time[1] = D'2024.01.01 04:00';
    //    03:00 bear
    open[2] = 1.0900; high[2] = 1.0900; low[2] = 1.0880; close[2] = 1.0880; time[2] = D'2024.01.01 03:00';
    //    02:00 bear
    open[3] = 1.0920; high[3] = 1.0920; low[3] = 1.0900; close[3] = 1.0900; time[3] = D'2024.01.01 02:00';
    //    01:00 bull (displacement)
    open[4] = 1.0900; high[4] = 1.0940; low[4] = 1.0920; close[4] = 1.0920; time[4] = D'2024.01.01 01:00';
    //    00:00 flat
    open[5] = 1.0900; high[5] = 1.0910; low[5] = 1.0900; close[5] = 1.0900; time[5] = D'2024.01.01 00:00';
}

//--- History B: 3 bars of an OLDER epoch (2023.12.01), newest first.
//--- time[0] is older than A's newest bar -> forces the rescan path.
//--- Produces ONE bearish FVG at 04:00: triplet A=bar2 (bull) C=bar0 (bear),
//--- gap low[2]=1.1020 > high[0]=1.1000.
void LCBuildFVGHistoryB(double &open[], double &high[], double &low[],
                        double &close[], datetime &time[], int &rates)
{
    rates = 3;
    ArrayResize(open, rates);
    ArrayResize(high, rates);
    ArrayResize(low, rates);
    ArrayResize(close, rates);
    ArrayResize(time, rates);

    open[0] = 1.1000; high[0] = 1.1000; low[0] = 1.0980; close[0] = 1.0980; time[0] = D'2023.12.01 05:00';
    open[1] = 1.1020; high[1] = 1.1020; low[1] = 1.1000; close[1] = 1.1000; time[1] = D'2023.12.01 04:00';
    open[2] = 1.1020; high[2] = 1.1040; low[2] = 1.1020; close[2] = 1.1040; time[2] = D'2023.12.01 03:00';
}

//--- History C: 8 bars = A shifted by +2 plus 2 newer bars (07:00, 06:00),
//--- newest first. time[0] (07:00) > A cursor (05:00) -> delta path.
//--- Produces ONE new bullish FVG at 06:00: triplet A=bar2 (bear) C=bar0 (bull),
//--- gap low[0]=1.0880 > high[2]=1.0860. Old bearish FVG (02:00) must survive.
void LCBuildFVGHistoryC(double &open[], double &high[], double &low[],
                        double &close[], datetime &time[], int &rates)
{
    rates = 8;
    ArrayResize(open, rates);
    ArrayResize(high, rates);
    ArrayResize(low, rates);
    ArrayResize(close, rates);
    ArrayResize(time, rates);

    //    07:00 bull (new)
    open[0] = 1.0880; high[0] = 1.0940; low[0] = 1.0880; close[0] = 1.0940; time[0] = D'2024.01.01 07:00';
    //    06:00 flat (new, displacement)
    open[1] = 1.0870; high[1] = 1.0880; low[1] = 1.0860; close[1] = 1.0870; time[1] = D'2024.01.01 06:00';
    //    05:00 bear (A[0])
    open[2] = 1.0860; high[2] = 1.0860; low[2] = 1.0840; close[2] = 1.0840; time[2] = D'2024.01.01 05:00';
    //    04:00 bear (A[1])
    open[3] = 1.0880; high[3] = 1.0880; low[3] = 1.0860; close[3] = 1.0860; time[3] = D'2024.01.01 04:00';
    //    03:00 bear (A[2])
    open[4] = 1.0900; high[4] = 1.0900; low[4] = 1.0880; close[4] = 1.0880; time[4] = D'2024.01.01 03:00';
    //    02:00 bear (A[3])
    open[5] = 1.0920; high[5] = 1.0920; low[5] = 1.0900; close[5] = 1.0900; time[5] = D'2024.01.01 02:00';
    //    01:00 bull (A[4])
    open[6] = 1.0900; high[6] = 1.0940; low[6] = 1.0920; close[6] = 1.0920; time[6] = D'2024.01.01 01:00';
    //    00:00 flat (A[5])
    open[7] = 1.0900; high[7] = 1.0910; low[7] = 1.0900; close[7] = 1.0900; time[7] = D'2024.01.01 00:00';
}

//--- Shared swing series builder (chronological, index 0 = oldest).
//--- Swing highs every 4th bar from center 4 (4,8,12,16); swing lows at
//--- centers 6,10,14 (troughs at i%4==2, first scanned center is 4).
void LCBuildSwingSeries(int n, double &high[], double &low[], datetime &time[], int &rates)
{
    rates = n;
    ArrayResize(high, rates);
    ArrayResize(low, rates);
    ArrayResize(time, rates);

    const double base = 1.0900;
    for(int i = 0; i < n; i++)
    {
        if(i % 4 == 0)
            high[i] = base + 0.004;
        else if(i % 2 == 0)
            high[i] = base + 0.002;
        else
            high[i] = base + 0.001;

        if(i % 4 == 2)
            low[i] = base - 0.004;
        else
            low[i] = base - 0.002;

        time[i] = D'2024.01.01 00:00' + i * 3600;
    }
}

//--- LC01.1 - LC1/LC2/LC3 (FVG side): rescan on time discontinuity,
//--- pool rebuilt from the new history only, ids strictly monotonic.
void TestLC01_FVG_RescanRebuildsAndIdsMonotonic(TestCounters &counters)
{
    CFVGDetector detector;
    TEST_TRUE(detector.Init(), "LC01.1: FVG init");

    double open[], high[], low[], close[];
    datetime time[];
    int rates;

    LCBuildFVGHistoryA(open, high, low, close, time, rates);

    //--- Full initial scan: exactly one bearish FVG at 02:00
    detector.Update(open, high, low, close, time, rates);
    TEST_INT_EQ(detector.GetFVGCount(), 1, "LC01.1: history A -> 1 FVG");

    FairValueGap fvg0;
    TEST_TRUE(detector.GetFVG(0, fvg0), "LC01.1: fvg0 readable");
    TEST_INT_EQ(fvg0.id, 0, "LC01.1: first FVG id = 0 (0-based, monotonic up)");
    TEST_TRUE(!fvg0.bullish, "LC01.1: first FVG is bearish");
    TEST_DATETIME_EQ(fvg0.time, D'2024.01.01 02:00', "LC01.1: FVG time = 02:00 (displacement bar)");
    TEST_INT_EQ(fvg0.candleIndex, 3, "LC01.1: FVG candleIndex = 3");
    TEST_DBL_NEAR(fvg0.upper, 1.0920, 1e-9, "LC01.1: FVG upper = 1.0920 (gapLow)");
    TEST_DBL_NEAR(fvg0.lower, 1.0900, 1e-9, "LC01.1: FVG lower = 1.0900 (gapHigh)");

    //--- Same-bar re-feed: time[0] == cursor -> no-op (idempotent)
    detector.Update(open, high, low, close, time, rates);
    TEST_INT_EQ(detector.GetFVGCount(), 1, "LC01.1: same-bar re-feed is a no-op");
    TEST_TRUE(detector.GetFVG(0, fvg0), "LC01.1: fvg0 still readable after re-feed");
    TEST_INT_EQ(fvg0.id, 0, "LC01.1: re-feed keeps id 0");

    //--- History B (older epoch): time[0] < cursor -> rescan from scratch
    LCBuildFVGHistoryB(open, high, low, close, time, rates);
    detector.Update(open, high, low, close, time, rates);
    TEST_INT_EQ(detector.GetFVGCount(), 1, "LC01.1: rescan rebuilds from B only (no A leftovers)");

    FairValueGap fvgB;
    TEST_TRUE(detector.GetFVG(0, fvgB), "LC01.1: B fvg readable");
    TEST_INT_EQ(fvgB.id, 1, "LC01.1: id monotonic across rescan (no reuse - LC3)");
    TEST_DATETIME_EQ(fvgB.time, D'2023.12.01 04:00', "LC01.1: B fvg time = 2023.12.01 04:00");
    TEST_DBL_NEAR(fvgB.upper, 1.1020, 1e-9, "LC01.1: B fvg upper = 1.1020");
    TEST_DBL_NEAR(fvgB.lower, 1.1000, 1e-9, "LC01.1: B fvg lower = 1.1000");

    //--- Re-feed B: no-op
    detector.Update(open, high, low, close, time, rates);
    TEST_INT_EQ(detector.GetFVGCount(), 1, "LC01.1: B re-feed is a no-op");

    detector.Shutdown();
}

//--- LC01.2 - LC4 (FVG side): incremental delta keeps existing FVGs
//--- untouched and detects only the new bar's FVG.
void TestLC01_FVG_IncrementalDeltaOnly(TestCounters &counters)
{
    CFVGDetector detector;
    TEST_TRUE(detector.Init(), "LC01.2: FVG init");

    double open[], high[], low[], close[];
    datetime time[];
    int rates;

    LCBuildFVGHistoryA(open, high, low, close, time, rates);
    detector.Update(open, high, low, close, time, rates);
    TEST_INT_EQ(detector.GetFVGCount(), 1, "LC01.2: history A -> 1 FVG");

    //--- History C = A + 2 newer bars: delta scan only
    LCBuildFVGHistoryC(open, high, low, close, time, rates);
    detector.Update(open, high, low, close, time, rates);
    TEST_INT_EQ(detector.GetFVGCount(), 2, "LC01.2: delta adds exactly 1 FVG");

    //--- Old FVG untouched (id, geometry, position in pool)
    FairValueGap fvgOld;
    TEST_TRUE(detector.GetFVG(0, fvgOld), "LC01.2: old FVG readable");
    TEST_INT_EQ(fvgOld.id, 0, "LC01.2: old FVG keeps id 0 (0-based)");
    TEST_DATETIME_EQ(fvgOld.time, D'2024.01.01 02:00', "LC01.2: old FVG keeps time 02:00");
    TEST_DBL_NEAR(fvgOld.upper, 1.0920, 1e-9, "LC01.2: old FVG keeps upper 1.0920");
    TEST_DBL_NEAR(fvgOld.lower, 1.0900, 1e-9, "LC01.2: old FVG keeps lower 1.0900");

    //--- New FVG detected in the delta window only
    FairValueGap fvgNew;
    TEST_TRUE(detector.GetFVG(1, fvgNew), "LC01.2: new FVG readable");
    TEST_INT_EQ(fvgNew.id, 1, "LC01.2: new FVG id = 1 (monotonic)");
    TEST_TRUE(fvgNew.bullish, "LC01.2: new FVG is bullish");
    TEST_DATETIME_EQ(fvgNew.time, D'2024.01.01 06:00', "LC01.2: new FVG time = 06:00");
    TEST_DBL_NEAR(fvgNew.upper, 1.0880, 1e-9, "LC01.2: new FVG upper = 1.0880");
    TEST_DBL_NEAR(fvgNew.lower, 1.0860, 1e-9, "LC01.2: new FVG lower = 1.0860");

    //--- Overlap triplets (old bars inside the delta window) must dedup by time
    detector.Update(open, high, low, close, time, rates);
    TEST_INT_EQ(detector.GetFVGCount(), 2, "LC01.2: overlap re-feed deduped by time");

    detector.Shutdown();
}

//--- LC01.3 - LC2 (swing side): SwingDetector detects `rates_total`
//--- shrink and FULLY resets (SwingDetector.mqh:113-119 -> Clear):
//--- after the shrink the pool is rebuilt from the NEW history only
//--- (no stale swings from removed bars), and re-growing history
//--- rebuilds the identical swing set (recovery, no stall).
void TestLC01_Swing_ShrinkDetectResetRecover(TestCounters &counters)
{
    CSwingDetector detector;
    TEST_TRUE(detector.Init(), "LC01.3: swing init");

    double high[], low[];
    datetime time[];
    int rates;

    //--- 20-bar series: 4 highs (centers 4,8,12,16), 3 lows (6,10,14)
    LCBuildSwingSeries(20, high, low, time, rates);
    detector.Update(high, low, time, rates);
    TEST_INT_EQ(detector.GetSwingHighCount(), 4, "LC01.3: 20 bars -> 4 swing highs");
    TEST_INT_EQ(detector.GetSwingLowCount(), 3, "LC01.3: 20 bars -> 3 swing lows");

    SwingPoint savedHighs[];
    ArrayResize(savedHighs, 4);
    SwingPoint savedLows[];
    ArrayResize(savedLows, 3);
    for(int i = 0; i < 4; i++)
        detector.GetSwingHigh(i, savedHighs[i]);
    for(int i = 0; i < 3; i++)
        detector.GetSwingLow(i, savedLows[i]);

    //--- Shrink 20 -> 10: reset detected (maxCenter 7 < lastChecked 17)
    LCBuildSwingSeries(10, high, low, time, rates);
    detector.Update(high, low, time, rates);
    TEST_INT_EQ(detector.GetSwingHighCount(), 1, "LC01.3: shrink rebuilds highs from new history");
    TEST_INT_EQ(detector.GetSwingLowCount(), 1, "LC01.3: shrink rebuilds lows from new history");

    SwingPoint sh;
    SwingPoint sl;
    TEST_TRUE(detector.GetSwingHigh(0, sh), "LC01.3: rebuilt high readable");
    TEST_INT_EQ(sh.barIndex, 4, "LC01.3: rebuilt high at bar 4 (new history)");
    TEST_TRUE(detector.GetSwingLow(0, sl), "LC01.3: rebuilt low readable");
    TEST_INT_EQ(sl.barIndex, 6, "LC01.3: rebuilt low at bar 6 (new history)");

    //--- Regrow 20: scan continues from bar 8 -> full set recovered
    LCBuildSwingSeries(20, high, low, time, rates);
    detector.Update(high, low, time, rates);
    TEST_INT_EQ(detector.GetSwingHighCount(), 4, "LC01.3: regrow recovers 4 highs (no stall)");
    TEST_INT_EQ(detector.GetSwingLowCount(), 3, "LC01.3: regrow recovers 3 lows (no stall)");

    bool identical = true;
    SwingPoint cur;
    for(int i = 0; i < 4 && identical; i++)
    {
        detector.GetSwingHigh(i, cur);
        if(cur.time != savedHighs[i].time || cur.price != savedHighs[i].price || cur.barIndex != savedHighs[i].barIndex)
            identical = false;
    }
    for(int i = 0; i < 3 && identical; i++)
    {
        detector.GetSwingLow(i, cur);
        if(cur.time != savedLows[i].time || cur.price != savedLows[i].price || cur.barIndex != savedLows[i].barIndex)
            identical = false;
    }
    TEST_TRUE(identical, "LC01.3: recovered set identical (time/price/barIndex) to pre-shrink set");

    detector.Shutdown();
}

//--- LC01.4 - LC2 (reload): a fresh init + full rescan reconstructs the
//--- same swing set as the original scan (deterministic rebuild).
void TestLC01_Swing_ReloadReconstructsIdenticalState(TestCounters &counters)
{
    double high[], low[];
    datetime time[];
    int rates;

    //--- Original scan
    CSwingDetector detector1;
    TEST_TRUE(detector1.Init(), "LC01.4: init detector 1");
    LCBuildSwingSeries(20, high, low, time, rates);
    detector1.Update(high, low, time, rates);
    TEST_INT_EQ(detector1.GetSwingHighCount(), 4, "LC01.4: original 4 highs");
    TEST_INT_EQ(detector1.GetSwingLowCount(), 3, "LC01.4: original 3 lows");

    SwingPoint savedHighs[];
    ArrayResize(savedHighs, 4);
    SwingPoint savedLows[];
    ArrayResize(savedLows, 3);
    for(int i = 0; i < 4; i++)
        detector1.GetSwingHigh(i, savedHighs[i]);
    for(int i = 0; i < 3; i++)
        detector1.GetSwingLow(i, savedLows[i]);
    detector1.Shutdown();

    //--- Reload: fresh instance, full rescan of the same series
    CSwingDetector detector2;
    TEST_TRUE(detector2.Init(), "LC01.4: init detector 2");
    detector2.Update(high, low, time, rates);
    TEST_INT_EQ(detector2.GetSwingHighCount(), 4, "LC01.4: reload 4 highs");
    TEST_INT_EQ(detector2.GetSwingLowCount(), 3, "LC01.4: reload 3 lows");

    bool identical = true;
    SwingPoint cur;
    for(int i = 0; i < 4 && identical; i++)
    {
        detector2.GetSwingHigh(i, cur);
        if(cur.time != savedHighs[i].time || cur.price != savedHighs[i].price || cur.barIndex != savedHighs[i].barIndex)
            identical = false;
    }
    for(int i = 0; i < 3 && identical; i++)
    {
        detector2.GetSwingLow(i, cur);
        if(cur.time != savedLows[i].time || cur.price != savedLows[i].price || cur.barIndex != savedLows[i].barIndex)
            identical = false;
    }
    TEST_TRUE(identical, "LC01.4: reloaded swings identical (time/price/barIndex) to original");

    detector2.Shutdown();
}

TestCounters RunLifecycleContractTests(void)
{
    TestCounters counters;

    SUITE_BEGIN("Lifecycle Contract Tests");

    TestLC01_FVG_RescanRebuildsAndIdsMonotonic(counters);
    TestLC01_FVG_IncrementalDeltaOnly(counters);
    TestLC01_Swing_ShrinkDetectResetRecover(counters);
    TestLC01_Swing_ReloadReconstructsIdenticalState(counters);

    SUITE_END("Lifecycle Contract Tests");

    return counters;
}

#endif // __TEST_LIFECYCLE_CONTRACT_MQH__
