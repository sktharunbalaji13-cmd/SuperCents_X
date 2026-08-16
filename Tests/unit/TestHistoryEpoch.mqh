//+------------------------------------------------------------------+
//|                                              TestHistoryEpoch.mqh |
//|                    Sprint 20 - LC02: canonical history reset      |
//|                                                                  |
//| LC02 delivers ONE history-shrink/reset mechanism every stateful  |
//| detector can consume (spec: docs/Sprint20_History_Reset_         |
//| Mechanism.md). The mechanism answers exactly four questions:     |
//|   rates_total decreased -> how detected?                         |
//|   what state is invalidated? -> all registered consumers         |
//|   who receives the reset?     -> registered consumers            |
//|   how is rebuild triggered?   -> OnHistoryReset() per consumer   |
//|                                                                  |
//| Detection rules (canonical):                                     |
//|   - first update after (re)init = baseline only, no event        |
//|   - rates_total < last seen  -> HISTORY_EVENT_SHRINK             |
//|   - newest-bar time went back -> HISTORY_EVENT_TIME_RESET        |
//|   - both -> SHRINK (priority, still one epoch bump + broadcast)  |
//|   - grow / same data -> HISTORY_EVENT_NONE                       |
//+------------------------------------------------------------------+
#ifndef __TEST_HISTORY_EPOCH_MQH__
#define __TEST_HISTORY_EPOCH_MQH__

#include "../../Core/HistoryEpoch.mqh"
#include "../../Portfolio/SymbolContext.mqh"
#include "../TestAssert.mqh"

//--- Mock consumer: counts OnHistoryReset invocations
class CMockResetConsumer : public IHistoryResetConsumer
{
public:
    int m_resetCount;

    CMockResetConsumer(void) : m_resetCount(0) {}

    void OnHistoryReset(void) { m_resetCount++; }
};

//--- LC02.1: first update establishes the baseline - no event, no
//--- epoch bump, no notifications. Callers may not report a reset
//--- before any history was ever observed.
void TestLC02_FirstUpdateIsBaseline(TestCounters &counters)
{
    CHistoryEpoch epoch;
    CMockResetConsumer mock;
    epoch.AddConsumer(&mock);

    EHistoryEvent ev = epoch.Update(500, D'2026.01.01 05:00');
    TEST_INT_EQ((int)ev, (int)HISTORY_EVENT_NONE, "LC02.1: first update = baseline, no event");
    TEST_INT_EQ(epoch.GetEpoch(), 0, "LC02.1: epoch stays 0 after baseline");
    TEST_INT_EQ(mock.m_resetCount, 0, "LC02.1: no consumer notified on baseline");
}

//--- LC02.2: history extension (grow) or identical re-feed is a
//--- normal update - consumers must not be reset.
void TestLC02_ExtensionIsNotReset(TestCounters &counters)
{
    CHistoryEpoch epoch;
    CMockResetConsumer mock;
    epoch.AddConsumer(&mock);

    epoch.Update(500, D'2026.01.01 05:00');

    EHistoryEvent evGrow = epoch.Update(501, D'2026.01.01 06:00');
    TEST_INT_EQ((int)evGrow, (int)HISTORY_EVENT_NONE, "LC02.2: grow = normal update");
    TEST_INT_EQ(epoch.GetEpoch(), 0, "LC02.2: no epoch bump on grow");

    EHistoryEvent evSame = epoch.Update(501, D'2026.01.01 06:00');
    TEST_INT_EQ((int)evSame, (int)HISTORY_EVENT_NONE, "LC02.2: identical re-feed = normal update");

    TEST_INT_EQ(mock.m_resetCount, 0, "LC02.2: no consumer notified on grow/re-feed");
}

//--- LC02.3: rates_total shrink -> HISTORY_EVENT_SHRINK, epoch bump,
//--- every registered consumer notified exactly once.
void TestLC02_ShrinkDetectedAndBroadcast(TestCounters &counters)
{
    CHistoryEpoch epoch;
    CMockResetConsumer mock;
    epoch.AddConsumer(&mock);

    epoch.Update(500, D'2026.01.01 05:00');

    EHistoryEvent ev = epoch.Update(300, D'2026.01.01 05:00');
    TEST_INT_EQ((int)ev, (int)HISTORY_EVENT_SHRINK, "LC02.3: rates_total 500->300 = SHRINK");
    TEST_INT_EQ(epoch.GetEpoch(), 1, "LC02.3: epoch bumped to 1");
    TEST_INT_EQ(mock.m_resetCount, 1, "LC02.3: consumer notified once");
}

//--- LC02.4: newest-bar time moving backwards (reload/purge) without
//--- any shrink -> HISTORY_EVENT_TIME_RESET, epoch bump, broadcast.
void TestLC02_TimeResetDetectedAndBroadcast(TestCounters &counters)
{
    CHistoryEpoch epoch;
    CMockResetConsumer mock;
    epoch.AddConsumer(&mock);

    epoch.Update(500, D'2026.01.01 05:00');

    EHistoryEvent ev = epoch.Update(500, D'2025.12.30 00:00');
    TEST_INT_EQ((int)ev, (int)HISTORY_EVENT_TIME_RESET, "LC02.4: time went backwards = TIME_RESET");
    TEST_INT_EQ(epoch.GetEpoch(), 1, "LC02.4: epoch bumped to 1");
    TEST_INT_EQ(mock.m_resetCount, 1, "LC02.4: consumer notified once");
}

//--- LC02.5: shrink + time reset together -> SHRINK reported
//--- (priority), exactly one epoch bump, one notification each.
void TestLC02_ShrinkTakesPriorityOverTimeReset(TestCounters &counters)
{
    CHistoryEpoch epoch;
    CMockResetConsumer mock;
    epoch.AddConsumer(&mock);

    epoch.Update(500, D'2026.01.01 05:00');

    EHistoryEvent ev = epoch.Update(100, D'2025.12.01 00:00');
    TEST_INT_EQ((int)ev, (int)HISTORY_EVENT_SHRINK, "LC02.5: shrink+time reset -> SHRINK priority");
    TEST_INT_EQ(epoch.GetEpoch(), 1, "LC02.5: single epoch bump");
    TEST_INT_EQ(mock.m_resetCount, 1, "LC02.5: single notification");
}

//--- LC02.6: multiple consumers - ALL registered consumers receive
//--- the reset (registry broadcast semantics).
void TestLC02_AllConsumersReceiveReset(TestCounters &counters)
{
    CHistoryEpoch epoch;
    CMockResetConsumer mockA;
    CMockResetConsumer mockB;
    CMockResetConsumer mockC;
    epoch.AddConsumer(&mockA);
    epoch.AddConsumer(&mockB);
    epoch.AddConsumer(&mockC);

    epoch.Update(500, D'2026.01.01 05:00');
    epoch.Update(400, D'2026.01.01 05:00');

    TEST_INT_EQ(mockA.m_resetCount, 1, "LC02.6: consumer A notified");
    TEST_INT_EQ(mockB.m_resetCount, 1, "LC02.6: consumer B notified");
    TEST_INT_EQ(mockC.m_resetCount, 1, "LC02.6: consumer C notified");
}

//--- LC02.7: consecutive shrinks are consecutive events (each decrease
//--- invalidates again); baseline tracks the latest observed size.
void TestLC02_ConsecutiveShrinksEachEvent(TestCounters &counters)
{
    CHistoryEpoch epoch;
    CMockResetConsumer mock;
    epoch.AddConsumer(&mock);

    epoch.Update(500, D'2026.01.01 05:00');
    epoch.Update(400, D'2026.01.01 05:00');
    TEST_INT_EQ(epoch.GetEpoch(), 1, "LC02.7: first shrink bumps to 1");
    TEST_INT_EQ(mock.m_resetCount, 1, "LC02.7: notified once");

    EHistoryEvent ev2 = epoch.Update(300, D'2026.01.01 05:00');
    TEST_INT_EQ((int)ev2, (int)HISTORY_EVENT_SHRINK, "LC02.7: second shrink detected again");
    TEST_INT_EQ(epoch.GetEpoch(), 2, "LC02.7: epoch monotonic 1 -> 2");
    TEST_INT_EQ(mock.m_resetCount, 2, "LC02.7: notified again");

    EHistoryEvent ev3 = epoch.Update(300, D'2026.01.01 05:00');
    TEST_INT_EQ((int)ev3, (int)HISTORY_EVENT_NONE, "LC02.7: same size after shrink = normal");
    TEST_INT_EQ(mock.m_resetCount, 2, "LC02.7: no extra notification");
}

//--- LC02.8: after a reset, the new (smaller) history becomes the
//--- new baseline - growth from there is a normal extension.
void TestLC02_PostResetGrowthIsNormal(TestCounters &counters)
{
    CHistoryEpoch epoch;
    CMockResetConsumer mock;
    epoch.AddConsumer(&mock);

    epoch.Update(500, D'2026.01.01 05:00');
    epoch.Update(300, D'2026.01.01 05:00');
    TEST_INT_EQ(epoch.GetEpoch(), 1, "LC02.8: reset happened");

    EHistoryEvent ev = epoch.Update(320, D'2026.01.01 06:00');
    TEST_INT_EQ((int)ev, (int)HISTORY_EVENT_NONE, "LC02.8: growth from rebuilt baseline = normal");
    TEST_INT_EQ(mock.m_resetCount, 1, "LC02.8: no extra notification");
}

//--- LC02.9: Reset() (context re-init, TF/symbol change, EA restart)
//--- clears the baseline - next update is a fresh baseline again.
void TestLC02_ExplicitResetRebaselines(TestCounters &counters)
{
    CHistoryEpoch epoch;
    CMockResetConsumer mock;
    epoch.AddConsumer(&mock);

    epoch.Update(500, D'2026.01.01 05:00');
    epoch.Update(100, D'2026.01.01 05:00');
    TEST_INT_EQ(epoch.GetEpoch(), 1, "LC02.9: reset happened");

    epoch.Reset();
    TEST_INT_EQ(epoch.GetEpoch(), 0, "LC02.9: Reset() zeroes the epoch");

    EHistoryEvent ev = epoch.Update(500, D'2026.01.01 05:00');
    TEST_INT_EQ((int)ev, (int)HISTORY_EVENT_NONE, "LC02.9: post-Reset update = fresh baseline");
    TEST_INT_EQ(mock.m_resetCount, 1, "LC02.9: no extra notification after Reset()");
}

//--- EN-01 (Sprint 24 audit #1, CRITICAL): the production call site fed
//    the epoch with time[0] BEFORE the series orientation was applied
//    (SymbolContext.mqh:729 - ArraySetAsSeries(time,true) ran later in
//    the same method), so timeNewest = time[0] was the OLDEST bar of the
//    chronological Copy* array - violating the HistoryEpoch contract
//    (timeNewest = time[0] in SERIES order = the NEWEST bar). Consequence:
//    the LC5 time-reversal path was dead and all registered consumers
//    kept stale state on reload / history revision.
//
//    This test drives the PRODUCTION call site (CSymbolContext::Update,
//    LEGACY mode) with chronological arrays exactly as Copy* delivers
//    them and pins the orientation contract: a newest-bar time reversal
//    (same rates_total, newest timestamp moved back - history revision)
//    MUST fire the TIME_RESET broadcast and reach the registered
//    consumers (swing cleared to 0). RED on the pre-orientation read;
//    GREEN once the call site moves post-ArraySetAsSeries.
void TestEN01_CallSiteOrientationContract(TestCounters &counters)
{
    const int R = 500;
    datetime time[];
    double open[], high[], low[], close[];
    ArrayResize(time, R);
    ArrayResize(open, R);
    ArrayResize(high, R);
    ArrayResize(low, R);
    ArrayResize(close, R);

    //--- Chronological OHLC (index 0 = OLDEST bar), exactly as CEngine::
    //    CopyOHLCArrays delivers via CopyOpen/CopyHigh/CopyLow/CopyClose/
    //    CopyTime. Clockwork 5-bar fractals: highs at i%5==0, lows at
    //    i%5==2.
    for(int i = 0; i < R; i++)
    {
        time[i]  = D'2026.01.01 00:00' + i * 3600;
        open[i]  = 1.10000;
        close[i] = 1.10000;
        high[i]  = 1.10000 + ((i % 5 == 0) ? 0.00020 : 0.00000);
        low[i]   = 1.09980 - ((i % 5 == 2) ? 0.00020 : 0.00000);
    }

    CSymbolContext ctx("FIXTURE_EN01", 0, ENTRY_MODE_LEGACY);
    TEST_TRUE(ctx.Init(NULL), "EN-01: CSymbolContext fixture initializes");

    //--- EN-01: this fixture drives the production call site with
    //    chronological arrays "exactly as Copy* delivers them". The call
    //    site re-indexes the by-reference arrays to series order for the
    //    duration of its update, so restore the chronological orientation
    //    before EVERY call - the contract this test pins is that the
    //    caller's arrays are consumed (not mutated) by CSymbolContext::
    //    Update().
    ArraySetAsSeries(time, false);
    ArraySetAsSeries(open, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);

    //--- tick 1: baseline - the epoch records its first observation
    //    (no event, no broadcast); the chain builds its initial state.
    ctx.Update(open, high, low, close, time, R);

    //--- EN-01: the production call site must NOT leak series-orientation
    //    mutations onto the caller's arrays.
    TEST_TRUE(!ArrayIsSeries(time), "EN-01: Update() restored chronological orientation of time[]");
    TEST_TRUE(!ArrayIsSeries(open), "EN-01: Update() restored chronological orientation of open[]");
    TEST_TRUE(!ArrayIsSeries(high), "EN-01: Update() restored chronological orientation of high[]");
    TEST_TRUE(!ArrayIsSeries(low), "EN-01: Update() restored chronological orientation of low[]");
    TEST_TRUE(!ArrayIsSeries(close), "EN-01: Update() restored chronological orientation of close[]");
    int baseHigh = ctx.GetSwingDetector().GetSwingHighCount();
    int baseLow  = ctx.GetSwingDetector().GetSwingLowCount();
    TEST_TRUE(baseHigh > 0 && baseLow > 0, "EN-01: baseline scan detects swings (fixture sanity)");

    //--- tick 2: history revision - SAME rates_total, the NEWEST bar's
    //    time moved BACK (reload / re-sync re-feed). The contract
    //    requires TIME_RESET -> broadcast, so the swing consumer must be
    //    cleared (count 0). The pre-orientation call site reads the
    //    unchanged OLDEST time instead and stays silent - RED.
    ArraySetAsSeries(time, false);
    ArraySetAsSeries(open, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);
    time[R - 1] = D'2026.01.01 00:00' + (R - 3) * 3600;
    ctx.Update(open, high, low, close, time, R);
    TEST_INT_EQ(ctx.GetSwingDetector().GetSwingHighCount(), 0,
        "EN-01: TIME_RESET broadcast cleared the swing consumer (orientation contract)");
    TEST_INT_EQ(ctx.GetSwingDetector().GetSwingLowCount(), 0,
        "EN-01: TIME_RESET broadcast cleared the low-swing consumer (orientation contract)");

    //--- tick 3: normal extension - no spurious reset; the consumers
    //    rebuild to their baseline population via the initial-scan path.
    int R3 = R + 1;
    ArraySetAsSeries(time, false);
    ArraySetAsSeries(open, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);
    ArrayResize(time, R3);
    ArrayResize(open, R3);
    ArrayResize(high, R3);
    ArrayResize(low, R3);
    ArrayResize(close, R3);
    time[R3 - 1]  = D'2026.01.01 00:00' + R * 3600;
    open[R3 - 1]  = 1.10000;
    close[R3 - 1] = 1.10000;
    high[R3 - 1]  = 1.10000 + 0.00020;
    low[R3 - 1]   = 1.09980;
    ctx.Update(open, high, low, close, time, R3);
    //--- C4 (closed-bar): with the forming bar excluded, an incrementally
    //    built baseline and a fresh full rescan can differ by one bar at
    //    the newest edge (documented LC03 order-dependence). The contract
    //    that MUST hold is deterministic reconstruction: a fresh scan of
    //    the SAME range reproduces the rebuilt state exactly.
    CSwingDetector fresh;
    TEST_TRUE(fresh.Init(), "EN-01: fresh reference init");
    fresh.Update(high, low, time, R3);
    TEST_INT_EQ(ctx.GetSwingDetector().GetSwingHighCount(), fresh.GetSwingHighCount(),
        "EN-01: post-rebuild swing-high == fresh full scan (deterministic rebuild)");
    TEST_INT_EQ(ctx.GetSwingDetector().GetSwingLowCount(), fresh.GetSwingLowCount(),
        "EN-01: post-rebuild swing-low == fresh full scan (deterministic rebuild)");

    ctx.Shutdown();
}

//--- EN-02 (Sprint 24 audit #2): the visualization manager must be a
//    history-reset consumer. Production registers it with the epoch in
//    CSymbolContext::Init (the detectors and the context itself are
//    registered there already), so the SAME TIME_RESET broadcast that
//    clears the detectors must reach the manager (its renderers drop
//    stale draw state). RED pre-fix: the manager is never registered and
//    its reset counter stays 0. This drives the PRODUCTION call site
//    exactly like TestEN01_CallSiteOrientationContract.
void TestEN02_CallSiteResetReachesVisualization(TestCounters &counters)
{
    const int R = 500;
    datetime time[];
    double open[], high[], low[], close[];
    ArrayResize(time, R);
    ArrayResize(open, R);
    ArrayResize(high, R);
    ArrayResize(low, R);
    ArrayResize(close, R);

    for(int i = 0; i < R; i++)
    {
        time[i]  = D'2026.01.01 00:00' + i * 3600;
        open[i]  = 1.10000;
        close[i] = 1.10000;
        high[i]  = 1.10000 + ((i % 5 == 0) ? 0.00020 : 0.00000);
        low[i]   = 1.09980 - ((i % 5 == 2) ? 0.00020 : 0.00000);
    }

    CSymbolContext ctx("FIXTURE_EN02", 0, ENTRY_MODE_LEGACY);
    TEST_TRUE(ctx.Init(NULL), "EN-02: CSymbolContext fixture initializes");

    CVisualizationManager *mgr = ctx.GetVisualizationManager();
    TEST_TRUE(mgr != NULL, "EN-02: visualization manager constructed by the context");
    TEST_INT_EQ(0, (int)mgr.GetHistoryResetCount(), "EN-02: no reset before any feed");

    //--- tick 1: baseline - the epoch records its first observation
    //    (no event, no broadcast); the manager must not be notified.
    ArraySetAsSeries(time, false);
    ArraySetAsSeries(open, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);
    ctx.Update(open, high, low, close, time, R);
    TEST_INT_EQ(0, (int)mgr.GetHistoryResetCount(), "EN-02: baseline tick fires no reset");

    //--- tick 2: history revision (same rates_total, newest-bar time
    //    moved back) -> TIME_RESET broadcast must reach the manager.
    ArraySetAsSeries(time, false);
    ArraySetAsSeries(open, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);
    time[R - 1] = D'2026.01.01 00:00' + (R - 3) * 3600;
    ctx.Update(open, high, low, close, time, R);
    TEST_INT_EQ(1, (int)mgr.GetHistoryResetCount(),
        "EN-02: TIME_RESET broadcast reached the visualization manager");

    //--- tick 3: normal extension - no spurious reset broadcast.
    int R3 = R + 1;
    ArraySetAsSeries(time, false);
    ArraySetAsSeries(open, false);
    ArraySetAsSeries(high, false);
    ArraySetAsSeries(low, false);
    ArraySetAsSeries(close, false);
    ArrayResize(time, R3);
    ArrayResize(open, R3);
    ArrayResize(high, R3);
    ArrayResize(low, R3);
    ArrayResize(close, R3);
    time[R3 - 1]  = D'2026.01.01 00:00' + R * 3600;
    open[R3 - 1]  = 1.10000;
    close[R3 - 1] = 1.10000;
    high[R3 - 1]  = 1.10000 + 0.00020;
    low[R3 - 1]   = 1.09980;
    ctx.Update(open, high, low, close, time, R3);
    TEST_INT_EQ(1, (int)mgr.GetHistoryResetCount(),
        "EN-02: post-reset extension fires no second reset");

    ctx.Shutdown();
}

TestCounters RunHistoryEpochTests(void)
{
    TestCounters counters;

    SUITE_BEGIN("History Epoch Tests");

    TestLC02_FirstUpdateIsBaseline(counters);
    TestLC02_ExtensionIsNotReset(counters);
    TestLC02_ShrinkDetectedAndBroadcast(counters);
    TestLC02_TimeResetDetectedAndBroadcast(counters);
    TestLC02_ShrinkTakesPriorityOverTimeReset(counters);
    TestLC02_AllConsumersReceiveReset(counters);
    TestLC02_ConsecutiveShrinksEachEvent(counters);
    TestLC02_PostResetGrowthIsNormal(counters);
    TestLC02_ExplicitResetRebaselines(counters);

    //--- EN-01 (Sprint 24 audit #1): call-site orientation contract.
    TestEN01_CallSiteOrientationContract(counters);

    //--- EN-02 (Sprint 24 audit #2): call-site reset reaches the
    //    visualization manager (renderer reset contract).
    TestEN02_CallSiteResetReachesVisualization(counters);

    SUITE_END("History Epoch Tests");

    return counters;
}

#endif // __TEST_HISTORY_EPOCH_MQH__
