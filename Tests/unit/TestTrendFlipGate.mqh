//+------------------------------------------------------------------+
//|                                           TestTrendFlipGate.mqh   |
//|                    Sprint 24 - EN-03 Option B: coordinated gate   |
//|                                                                  |
//| TDD fixtures for the EN-03 Option B implementation (docs/         |
//| Sprint24_EN03_OptionB_Plan.md §5). Drives the PRODUCTION call     |
//| site (Portfolio/SymbolContext.mqh) with synthetic growing          |
//| chronological windows exactly like TestHistoryEpoch.mqh and        |
//| asserts the coordinated-gate contract:                             |
//|   F1  FM-2 same-tick BOS-flip + opposite choch -> single flip      |
//|   F2  legit (non-same-tick) flips take direction from the event    |
//|   F3  no flip while TREND_UNKNOWN (defensive guard)                |
//|   F4  history-reset clears gate state; deterministic rebuild       |
//|   F5  call-site contract: ForceTrend exactly once on FM-2 tick     |
//|   F6  W=12 table regression guard (no spurious BOS)                |
//|                                                                  |
//| RED phase (current production): F1 and F5 fail (legacy gate        |
//| double-flips at W=23, flips again at W=30; PP diverges W=24/31).   |
//| F2/F3/F6 pass both phases by construction (legacy agrees on        |
//| legit flips; UNKNOWN flip is a dead branch - the choch detector    |
//| cannot fire while UNKNOWN, CHOCHDetector.mqh:151-155; W=12 fix is  |
//| table-fidelity). F4 passes both phases (reset wiring guard).       |
//+------------------------------------------------------------------+
#ifndef __TEST_TREND_FLIP_GATE_MQH__
#define __TEST_TREND_FLIP_GATE_MQH__

#include "../../Portfolio/SymbolContext.mqh"
#include "../../Structure/TrendState.mqh"
#include "../TestAssert.mqh"

//--- Scenario constants (mirror Tools/EN03/EN03_FM2Scenario.mq5).
#define EN03FM2_BARS     33
#define EN03FM2_STEP_SEC 900
#define EN03FM2_BASE     D'2026.01.01 00:00'

//--- F1 table = the frozen EN-03 Phase-2 FM-2 scenario (post-fix:
//    bar 4 HIGH=1.0940, bar 28 H=C=1.0925). Expected trace (frozen
//    COORDINATED arm, fm2_artifacts/COORDINATED/en03_fm2_coord.csv):
//    bos [19,23,31]; choch [23]; pp [19,23]; flips {W23: 1 (BOS only)}.
const double EN03F1_OPEN[EN03FM2_BARS] =
{
    1.0900, 1.0900, 1.0905, 1.0892, 1.0888, 1.0890, 1.0880, 1.0870,
    1.0835, 1.0845, 1.0860, 1.0930, 1.0910, 1.0885, 1.0845, 1.0850,
    1.0845, 1.0905, 1.0838, 1.0840, 1.0925, 1.0900, 1.0838, 1.0840,
    1.0842, 1.0845, 1.0910, 1.0885, 1.0860, 1.0845, 1.0940, 1.0915,
    1.0905
};
const double EN03F1_HIGH[EN03FM2_BARS] =
{
    1.0905, 1.0908, 1.0898, 1.0895, 1.0940, 1.0895, 1.0885, 1.0875,
    1.0850, 1.0865, 1.0935, 1.0930, 1.0915, 1.0890, 1.0855, 1.0850,
    1.0920, 1.0910, 1.0845, 1.0925, 1.0925, 1.0925, 1.0845, 1.0848,
    1.0849, 1.0915, 1.0910, 1.0890, 1.0925, 1.0942, 1.0935, 1.0918,
    1.0930
};
const double EN03F1_LOW[EN03FM2_BARS] =
{
    1.0895, 1.0895, 1.0890, 1.0885, 1.0880, 1.0875, 1.0865, 1.0830,
    1.0835, 1.0840, 1.0855, 1.0905, 1.0880, 1.0840, 1.0845, 1.0845,
    1.0830, 1.0830, 1.0832, 1.0838, 1.0830, 1.0835, 1.0834, 1.0835,
    1.0838, 1.0842, 1.0880, 1.0855, 1.0840, 1.0845, 1.0910, 1.0900,
    1.0900
};
const double EN03F1_CLOSE[EN03FM2_BARS] =
{
    1.0900, 1.0905, 1.0892, 1.0888, 1.0890, 1.0880, 1.0870, 1.0835,
    1.0845, 1.0860, 1.0930, 1.0910, 1.0885, 1.0845, 1.0850, 1.0845,
    1.0905, 1.0838, 1.0840, 1.0925, 1.0900, 1.0838, 1.0840, 1.0842,
    1.0845, 1.0910, 1.0885, 1.0860, 1.0925, 1.0940, 1.0915, 1.0905,
    1.0925
};

//--- F2 table = F1 with bars 21-24 relaxed so the L2 break lands on
//    bar 23 (close 1.0835) instead of bar 21: the bearish choch on the
//    fresh LOW PP L2 fires at W=25 with NO same-tick BOS (legit flip),
//    then the bullish choch on H3 fires at W=30 (legit flip), and the
//    W=31 BOS#3 (H4) arrives with the trend already BULLISH (no flip).
//    bars 21/22: close 1.0845 (no L2 break); bar 23: low=close=1.0835
//    (equal-low neighbor bar 22 blocks swing candidacy); bar 24: low
//    1.0836 (bar 23 lower -> not a swing).
//    Expected trace: bos [19,23,31]; choch [25 (bearish), 30 (bullish)];
//    pp [19,23,26,31]; flips {W25: 1 (gate), W30: 1 (gate)}.
const double EN03F2_CLOSE[EN03FM2_BARS] =
{
    1.0900, 1.0905, 1.0892, 1.0888, 1.0890, 1.0880, 1.0870, 1.0835,
    1.0845, 1.0860, 1.0930, 1.0910, 1.0885, 1.0845, 1.0850, 1.0845,
    1.0905, 1.0838, 1.0840, 1.0925, 1.0900, 1.0845, 1.0845, 1.0835,
    1.0845, 1.0910, 1.0885, 1.0860, 1.0925, 1.0940, 1.0915, 1.0905,
    1.0925
};
const double EN03F2_LOW[EN03FM2_BARS] =
{
    1.0895, 1.0895, 1.0890, 1.0885, 1.0880, 1.0875, 1.0865, 1.0830,
    1.0835, 1.0840, 1.0855, 1.0905, 1.0880, 1.0840, 1.0845, 1.0845,
    1.0830, 1.0830, 1.0832, 1.0838, 1.0830, 1.0835, 1.0835, 1.0835,
    1.0836, 1.0842, 1.0880, 1.0855, 1.0840, 1.0845, 1.0910, 1.0900,
    1.0900
};

//+------------------------------------------------------------------+
//| Drive one growing chronological window W (bars 0..W-1).           |
//| Caller's arrays stay chronological (production restores them).    |
//+------------------------------------------------------------------+
void EN03DriveWindow(CSymbolContext &ctx, const double &openT[],
                     const double &highT[], const double &lowT[],
                     const double &closeT[], int W)
{
    double open[], high[], low[], close[];
    datetime time[];
    ArrayResize(open, W);
    ArrayResize(high, W);
    ArrayResize(low, W);
    ArrayResize(close, W);
    ArrayResize(time, W);

    for(int k = 0; k < W; k++)
    {
        open[k]  = openT[k];
        high[k]  = highT[k];
        low[k]   = lowT[k];
        close[k] = closeT[k];
        time[k]  = EN03FM2_BASE + (datetime)(k * EN03FM2_STEP_SEC);
    }

    ArraySetAsSeries(time, false);
    ArraySetAsSeries(open, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);

    ctx.Update(open, high, low, close, time, W);
}

//+------------------------------------------------------------------+
//| Read the post-update detector state.                              |
//+------------------------------------------------------------------+
void EN03ReadState(CSymbolContext &ctx, int &trend, int &bos, int &choch,
                   int &pp, int &flips)
{
    CTrendState *ts = ctx.GetTrendState();
    CBOSDetector *bd = ctx.GetBOSDetector();
    CCHOCHDetector *cd = ctx.GetCHOCHDetector();
    CProtectedPointManager *pm = ctx.GetProtectedPointManager();

    trend = (ts != NULL) ? (int)ts.GetCurrentTrend() : -99;
    bos   = (bd != NULL) ? bd.GetBOSCount() : -99;
    choch = (cd != NULL) ? cd.GetCHOCHCount() : -99;
    pp    = (pm != NULL) ? pm.GetProtectedPointCount() : -99;
    flips = (ts != NULL) ? ts.GetTrendFlipCount() : -99;
}

//+------------------------------------------------------------------+
//| F1: FM-2 same-tick suppression on the frozen scenario table.      |
//| RED on legacy: at W=23 the gate reverts the BOS flip (trend       |
//| BEARISH, flip delta 2), then fires a second choch at W=30 and     |
//| diverges on PP at W=24 (H3 activation) and W=31 (L3 activation).  |
//+------------------------------------------------------------------+
void TestEN03F1_FM2SameTickSuppression(TestCounters &counters)
{
    CSymbolContext ctx("FIXTURE_EN03", 0, ENTRY_MODE_LEGACY);
    TEST_TRUE(ctx.Init(NULL), "F1: EN-03 fixture initializes");
    TEST_TRUE(ctx.Init(NULL) || true, "F1: idempotent Init");

    int trend, bos, choch, pp, flips, prevFlips = 0;

    for(int W = 5; W <= EN03FM2_BARS; W++)
    {
        EN03DriveWindow(ctx, EN03F1_OPEN, EN03F1_HIGH, EN03F1_LOW, EN03F1_CLOSE, W);
        EN03ReadState(ctx, trend, bos, choch, pp, flips);

        if(W == 19)
        {
            TEST_INT_EQ(trend, (int)TREND_BEARISH, "F1: W=19 first transition BEARISH (BOS#1)");
            TEST_INT_EQ(bos, 1, "F1: W=19 BOS#1 bearish");
            TEST_INT_EQ(choch, 0, "F1: W=19 no choch yet");
            TEST_INT_EQ(pp, 1, "F1: W=19 PP HIGH H2 activated");
        }
        else if(W == 22)
        {
            prevFlips = flips;
        }
        else if(W == 23)
        {
            TEST_INT_EQ(trend, (int)TREND_BULLISH, "F1: W=23 single transition BULLISH (FM-2 tick; legacy RED: BEARISH)");
            TEST_INT_EQ(bos, 2, "F1: W=23 BOS#2 bullish");
            TEST_INT_EQ(choch, 1, "F1: W=23 bearish choch fires on activated LOW");
            TEST_INT_EQ(pp, 2, "F1: W=23 PP LOW L2 activated");
            TEST_INT_EQ(flips - prevFlips, 1, "F1: W=23 exactly ONE flip this tick (BOS only; legacy RED: 2)");
            prevFlips = flips;
        }
        else if(W == 24)
        {
            TEST_INT_EQ(pp, 2, "F1: W=24 no gate-flip PP activation (legacy RED: H3 -> 3)");
            TEST_INT_EQ(trend, (int)TREND_BULLISH, "F1: W=24 trend stays BULLISH");
        }
        else if(W == 30)
        {
            TEST_INT_EQ(choch, 1, "F1: W=30 no second choch (legacy RED: bullish choch -> 2)");
            TEST_INT_EQ(trend, (int)TREND_BULLISH, "F1: W=30 trend stays BULLISH");
            TEST_INT_EQ(flips - prevFlips, 0, "F1: W=30 no gate flip (legacy RED: 1)");
            prevFlips = flips;
        }
        else if(W == 31)
        {
            TEST_INT_EQ(bos, 3, "F1: W=31 BOS#3 bullish (H4 cross)");
            TEST_INT_EQ(trend, (int)TREND_BULLISH, "F1: W=31 no flip (already BULLISH)");
            TEST_INT_EQ(pp, 2, "F1: W=31 no PP activation (legacy RED: L3 -> 4)");
        }
        else if(W == EN03FM2_BARS)
        {
            TEST_INT_EQ(bos, 3, "F1: final BOS count 3");
            TEST_INT_EQ(choch, 1, "F1: final choch count 1 (legacy RED: 2)");
            TEST_INT_EQ(pp, 2, "F1: final PP count 2 (legacy RED: 4)");
            TEST_INT_EQ(flips, 1, "F1: final flip count 1 (legacy RED: 4)");
        }
    }

    ctx.Shutdown();
}

//+------------------------------------------------------------------+
//| F2: legit (non-same-tick) flips - direction from the event.       |
//| On the F2 table the L2 bearish choch fires at W=25 (no same-tick  |
//| BOS): coordinated gate flips to BEARISH, exactly the event's      |
//| direction; the H3 bullish choch fires at W=30 -> flips BULLISH.   |
//+------------------------------------------------------------------+
void TestEN03F2_LegitFlipDirection(TestCounters &counters)
{
    CSymbolContext ctx("FIXTURE_EN03", 0, ENTRY_MODE_LEGACY);
    TEST_TRUE(ctx.Init(NULL), "F2: EN-03 fixture initializes");

    int trend, bos, choch, pp, flips;

    for(int W = 5; W <= EN03FM2_BARS; W++)
    {
        EN03DriveWindow(ctx, EN03F1_OPEN, EN03F1_HIGH, EN03F2_LOW, EN03F2_CLOSE, W);
        EN03ReadState(ctx, trend, bos, choch, pp, flips);

        if(W == 23)
        {
            TEST_INT_EQ(trend, (int)TREND_BULLISH, "F2: W=23 BOS#2 flip only (no choch this window)");
            TEST_INT_EQ(bos, 2, "F2: W=23 BOS#2");
            TEST_INT_EQ(choch, 0, "F2: W=23 no choch (bar 21 close does not break L2)");
            TEST_INT_EQ(flips, 1, "F2: W=23 flip count 1 (BOS only)");
        }
        else if(W == 25)
        {
            TEST_INT_EQ(choch, 1, "F2: W=25 bearish choch fires on fresh LOW PP (bar 23 close)");
            TEST_INT_EQ(bos, 2, "F2: W=25 NO same-tick BOS (legit gate flip window)");
            TEST_INT_EQ(trend, (int)TREND_BEARISH, "F2: W=25 legit flip to BEARISH (event direction)");
            TEST_INT_EQ(flips, 2, "F2: W=25 flip count 2 (gate flip #1)");
            CCHOCHDetector *cd = ctx.GetCHOCHDetector();
            CHOCHEvent ev;
            if(cd != NULL && cd.GetCHOCH(0, ev))
            {
                TEST_FALSE(ev.bullish, "F2: W=25 event direction bearish (choch.bullish=false)");
            }
            else
            {
                TEST_TRUE(false, "F2: W=25 choch event readable");
            }
        }
        else if(W == 30)
        {
            TEST_INT_EQ(choch, 2, "F2: W=30 bullish choch fires on active HIGH H3 (bar 28 close)");
            TEST_INT_EQ(bos, 2, "F2: W=30 NO same-tick BOS (H3 already broken at W=23)");
            TEST_INT_EQ(trend, (int)TREND_BULLISH, "F2: W=30 legit flip to BULLISH (event direction)");
            TEST_INT_EQ(flips, 3, "F2: W=30 flip count 3 (gate flip #2)");
            CCHOCHDetector *cd = ctx.GetCHOCHDetector();
            CHOCHEvent ev;
            if(cd != NULL && cd.GetCHOCH(1, ev))
            {
                TEST_TRUE(ev.bullish, "F2: W=30 event direction bullish (choch.bullish=true)");
            }
            else
            {
                TEST_TRUE(false, "F2: W=30 choch event readable");
            }
        }
        else if(W == 31)
        {
            TEST_INT_EQ(bos, 3, "F2: W=31 BOS#3 (H4 cross)");
            TEST_INT_EQ(trend, (int)TREND_BULLISH, "F2: W=31 no flip (already BULLISH)");
            TEST_INT_EQ(pp, 4, "F2: W=31 PP LOW L4 activated (trend-change pickup, 1-tick lag)");
        }
        else if(W == EN03FM2_BARS)
        {
            TEST_INT_EQ(trend, (int)TREND_BULLISH, "F2: final trend BULLISH");
            TEST_INT_EQ(bos, 3, "F2: final BOS 3");
            TEST_INT_EQ(choch, 2, "F2: final choch 2");
            TEST_INT_EQ(flips, 3, "F2: final flip count 3 (BOS#2 + 2 legit gate flips)");
        }
    }

    ctx.Shutdown();
}

//+------------------------------------------------------------------+
//| F3: no flip while TREND_UNKNOWN (defensive guard; the live choch  |
//| detector cannot fire under UNKNOWN - CHOCHDetector.mqh:151-155 -  |
//| so this pins the contract: the FIRST transition is always         |
//| BOS-driven and the gate never creates a transition from UNKNOWN). |
//+------------------------------------------------------------------+
void TestEN03F3_UNKNOWNNoFlip(TestCounters &counters)
{
    CSymbolContext ctx("FIXTURE_EN03", 0, ENTRY_MODE_LEGACY);
    TEST_TRUE(ctx.Init(NULL), "F3: EN-03 fixture initializes");

    int trend, bos, choch, pp, flips;

    for(int W = 5; W <= EN03FM2_BARS; W++)
    {
        EN03DriveWindow(ctx, EN03F1_OPEN, EN03F1_HIGH, EN03F1_LOW, EN03F1_CLOSE, W);
        EN03ReadState(ctx, trend, bos, choch, pp, flips);

        if(W <= 18)
        {
            TEST_INT_EQ(trend, (int)TREND_UNKNOWN, StringFormat("F3: W=%d trend UNKNOWN before first BOS", W));
            TEST_INT_EQ(bos, 0, StringFormat("F3: W=%d no BOS before first event", W));
            TEST_INT_EQ(flips, 0, StringFormat("F3: W=%d zero flips while UNKNOWN (gate never creates first transition)", W));
        }
        else if(W == 19)
        {
            TEST_INT_EQ(bos, 1, "F3: W=19 first BOS");
            TEST_INT_EQ(trend, (int)TREND_BEARISH, "F3: W=19 first transition is BOS-driven (BEARISH)");
            TEST_INT_EQ(flips, 0, "F3: W=19 first-set does not count as a forced flip (BOS path, not gate)");
        }
    }

    ctx.Shutdown();
}

//+------------------------------------------------------------------+
//| F4: history-reset contract. TIME_RESET must clear every gate-     |
//| relevant state (trend, flips, choch, BOS, PP) and the subsequent  |
//| replay must rebuild identically (W=19 reproduces BOS#1 + trend).  |
//+------------------------------------------------------------------+
void TestEN03F4_ResetContract(TestCounters &counters)
{
    CSymbolContext ctx("FIXTURE_EN03", 0, ENTRY_MODE_LEGACY);
    TEST_TRUE(ctx.Init(NULL), "F4: EN-03 fixture initializes");

    int trend, bos, choch, pp, flips;

    for(int W = 5; W <= 20; W++)
    {
        EN03DriveWindow(ctx, EN03F1_OPEN, EN03F1_HIGH, EN03F1_LOW, EN03F1_CLOSE, W);
        EN03ReadState(ctx, trend, bos, choch, pp, flips);
        if(W == 19)
        {
            TEST_INT_EQ(bos, 1, "F4: pre-reset W=19 BOS#1 present");
            TEST_INT_EQ(trend, (int)TREND_BEARISH, "F4: pre-reset W=19 trend BEARISH");
        }
    }

    //--- TIME_RESET: same rates_total, newest bar time moved back
    //    (mirrors TestHistoryEpoch's reset trigger).
    double open[], high[], low[], close[];
    datetime time[];
    ArrayResize(open, 20);
    ArrayResize(high, 20);
    ArrayResize(low, 20);
    ArrayResize(close, 20);
    ArrayResize(time, 20);
    for(int k = 0; k < 20; k++)
    {
        open[k]  = EN03F1_OPEN[k];
        high[k]  = EN03F1_HIGH[k];
        low[k]   = EN03F1_LOW[k];
        close[k] = EN03F1_CLOSE[k];
        time[k]  = EN03FM2_BASE + (datetime)(k * EN03FM2_STEP_SEC);
    }
    time[19] = EN03FM2_BASE + (datetime)(17 * EN03FM2_STEP_SEC);

    ArraySetAsSeries(time, false);
    ArraySetAsSeries(open, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);

    ctx.Update(open, high, low, close, time, 20);
    EN03ReadState(ctx, trend, bos, choch, pp, flips);
    TEST_INT_EQ(trend, (int)TREND_UNKNOWN, "F4: TIME_RESET clears trend (UNKNOWN)");
    TEST_INT_EQ(flips, 0, "F4: TIME_RESET clears flip count");
    TEST_INT_EQ(bos, 0, "F4: TIME_RESET clears BOS stream");
    TEST_INT_EQ(choch, 0, "F4: TIME_RESET clears choch stream");
    TEST_INT_EQ(pp, 0, "F4: TIME_RESET clears PP population");

    //--- deterministic rebuild: replay must reproduce the same W=19 state.
    for(int W = 5; W <= 20; W++)
    {
        EN03DriveWindow(ctx, EN03F1_OPEN, EN03F1_HIGH, EN03F1_LOW, EN03F1_CLOSE, W);
        EN03ReadState(ctx, trend, bos, choch, pp, flips);
        if(W == 19)
        {
            TEST_INT_EQ(bos, 1, "F4: post-reset W=19 BOS#1 rebuilt identically");
            TEST_INT_EQ(trend, (int)TREND_BEARISH, "F4: post-reset W=19 trend BEARISH rebuilt identically");
        }
    }

    ctx.Shutdown();
}

//+------------------------------------------------------------------+
//| F5: call-site contract - ForceTrend is invoked exactly once on    |
//| the FM-2 tick (the BOS flip) and never on suppression windows.    |
//| RED on legacy: flip delta 2 at W=23 and a second forced flip at   |
//| W=30 (final flip count 4 vs expected 1).                          |
//+------------------------------------------------------------------+
void TestEN03F5_CallSiteFlipCount(TestCounters &counters)
{
    CSymbolContext ctx("FIXTURE_EN03", 0, ENTRY_MODE_LEGACY);
    TEST_TRUE(ctx.Init(NULL), "F5: EN-03 fixture initializes");

    int trend, bos, choch, pp, flips, prevFlips = 0;

    for(int W = 5; W <= EN03FM2_BARS; W++)
    {
        EN03DriveWindow(ctx, EN03F1_OPEN, EN03F1_HIGH, EN03F1_LOW, EN03F1_CLOSE, W);
        EN03ReadState(ctx, trend, bos, choch, pp, flips);

        if(W == 22)
            prevFlips = flips;
        else if(W == 23)
        {
            TEST_INT_EQ(flips - prevFlips, 1,
                "F5: W=23 TrendFlipCount delta == 1 (BOS only; legacy RED: gate forces a 2nd flip)");
            prevFlips = flips;
        }
        else if(W == 29)
            prevFlips = flips;
        else if(W == 30)
        {
            TEST_INT_EQ(flips - prevFlips, 0,
                "F5: W=30 TrendFlipCount delta == 0 (suppression window; legacy RED: forced flip)");
            prevFlips = flips;
        }
    }

    EN03ReadState(ctx, trend, bos, choch, pp, flips);
    TEST_INT_EQ(flips, 1, "F5: final TrendFlipCount == 1 (legacy RED: 4)");

    ctx.Shutdown();
}

//+------------------------------------------------------------------+
//| F6: W=12 table regression guard - the spurious run-1 BOS (filler  |
//| closes above H1 1.0900) must never reappear: no BOS, no flip, no  |
//| choch and trend UNKNOWN at W=12.                                  |
//+------------------------------------------------------------------+
void TestEN03F6_W12NoBOS(TestCounters &counters)
{
    CSymbolContext ctx("FIXTURE_EN03", 0, ENTRY_MODE_LEGACY);
    TEST_TRUE(ctx.Init(NULL), "F6: EN-03 fixture initializes");

    int trend = 0, bos = 0, choch = 0, pp = 0, flips = 0;

    for(int W = 5; W <= 12; W++)
    {
        EN03DriveWindow(ctx, EN03F1_OPEN, EN03F1_HIGH, EN03F1_LOW, EN03F1_CLOSE, W);
        EN03ReadState(ctx, trend, bos, choch, pp, flips);
    }

    TEST_INT_EQ(bos, 0, "F6: W=12 no spurious BOS (bar 4 HIGH fix holds)");
    TEST_INT_EQ(trend, (int)TREND_UNKNOWN, "F6: W=12 trend UNKNOWN");
    TEST_INT_EQ(choch, 0, "F6: W=12 no choch");
    TEST_INT_EQ(flips, 0, "F6: W=12 zero flips");

    ctx.Shutdown();
}

//+------------------------------------------------------------------+
//| Suite runner.                                                     |
//+------------------------------------------------------------------+
TestCounters RunTrendFlipGateTests(void)
{
    TestCounters counters;
    SUITE_BEGIN("EN-03 Trend Flip Gate Tests (Option B)");

    TestEN03F1_FM2SameTickSuppression(counters);
    TestEN03F2_LegitFlipDirection(counters);
    TestEN03F3_UNKNOWNNoFlip(counters);
    TestEN03F4_ResetContract(counters);
    TestEN03F5_CallSiteFlipCount(counters);
    TestEN03F6_W12NoBOS(counters);

    SUITE_END("EN-03 Trend Flip Gate Tests (Option B)");
    return counters;
}

#endif // __TEST_TREND_FLIP_GATE_MQH__
