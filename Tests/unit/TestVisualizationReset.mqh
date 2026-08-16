//+------------------------------------------------------------------+
//|                                     TestVisualizationReset.mqh    |
//|                    Sprint 24 - EN-02: visualization reset fixtures|
//|                                                                  |
//| EN-02 (Sprint 24 audit #2, class B, FIX NOW): CVisualizationManager|
//| was NOT history-reset aware - renderers kept stale incremental    |
//| draw cursors (m_lastRendered*Count) and stale chart objects after |
//| a canonical CHistoryEpoch reset, so a rebuilt (smaller) history   |
//| population was never re-rendered.                                 |
//|                                                                  |
//| Fixture 1 (registration semantics): the manager is a live         |
//| broadcast consumer - a shrink fires, consecutive shrinks fire     |
//| again, growth does NOT (LC02.7/LC02.8 semantics against the real  |
//| manager).                                                         |
//|                                                                  |
//| Fixture 2 (renderer reset): the canonical reset drops the BOS     |
//| renderer's incremental draw cursor to 0 and the rebuilt           |
//| population is re-rendered from scratch on the next Update.        |
//| RED pre-fix: the manager is never registered (reset count 0) and  |
//| the cursor stays at the pre-reset population size. Deterministic  |
//| state probes only - no chart-object dependency.                   |
//|                                                                  |
//| Detector chain: the pinned REC fixture (TestReconstruction.mqh),  |
//| 24 hourly bars -> full scan = 5 swings (3H/2L), 5 pivots, 2 BOS   |
//| (bearish @B13 first, bullish @B17 second).                        |
//+------------------------------------------------------------------+
#ifndef __TEST_VISUALIZATION_RESET_MQH__
#define __TEST_VISUALIZATION_RESET_MQH__

#include "../../Core/HistoryEpoch.mqh"
#include "../../Structure/SwingDetector.mqh"
#include "../../Structure/StructuralPivotEngine.mqh"
#include "../../Structure/BOSDetector.mqh"
#include "../../Visualization/VisualizationManager.mqh"
#include "../../Tests/integration/TestReconstruction.mqh"
#include "../TestAssert.mqh"

//--- EN-02.1: manager registration semantics against the real manager
//    (epoch + manager only, no detectors wired).
void TestEN02_ManagerRegistrationSemantics(TestCounters &counters)
{
    CHistoryEpoch epoch;
    CVisualizationManager mgr;
    TEST_TRUE(mgr.Init(), "EN-02.1: manager init");
    epoch.AddConsumer(GetPointer(mgr));

    //--- baseline: first observation, no event, no notification.
    EHistoryEvent ev0 = epoch.Update(500, D'2026.01.01 05:00');
    TEST_INT_EQ((int)ev0, (int)HISTORY_EVENT_NONE, "EN-02.1: baseline = no event");
    TEST_INT_EQ(0, (int)mgr.GetHistoryResetCount(), "EN-02.1: baseline notifies nobody");

    //--- shrink 500 -> 300: broadcast reaches the manager once.
    EHistoryEvent ev1 = epoch.Update(300, D'2026.01.01 05:00');
    TEST_INT_EQ((int)ev1, (int)HISTORY_EVENT_SHRINK, "EN-02.1: 500->300 = SHRINK");
    TEST_INT_EQ(1, (int)mgr.GetHistoryResetCount(), "EN-02.1: shrink notified the manager");

    //--- consecutive shrink 300 -> 200: consecutive events, consecutive
    //    notifications (LC02.7 semantics through the real manager).
    EHistoryEvent ev2 = epoch.Update(200, D'2026.01.01 05:00');
    TEST_INT_EQ((int)ev2, (int)HISTORY_EVENT_SHRINK, "EN-02.1: second shrink detected again");
    TEST_INT_EQ(2, (int)mgr.GetHistoryResetCount(), "EN-02.1: second shrink notified again");

    //--- growth from the rebuilt baseline: normal update, no broadcast.
    EHistoryEvent ev3 = epoch.Update(250, D'2026.01.01 06:00');
    TEST_INT_EQ((int)ev3, (int)HISTORY_EVENT_NONE, "EN-02.1: growth = normal update");
    TEST_INT_EQ(2, (int)mgr.GetHistoryResetCount(), "EN-02.1: growth notifies nobody");

    mgr.Shutdown();
}

//--- EN-02.2: renderer reset - the canonical broadcast must clear the
//    BOS renderer's incremental draw cursor and the rebuilt population
//    must be re-rendered from scratch (RED pre-fix: cursor stays at the
//    pre-reset population size and the rebuilt history never draws).
void TestEN02_RendererResetDropsDrawCursor(TestCounters &counters)
{
    double open[], high[], low[], close[];
    datetime time[];
    RECBuildSeries(0, REC_BARS, open, high, low, close, time);

    CSwingDetector swing;
    CStructuralPivotEngine pivot;
    CBOSDetector bos;
    TEST_TRUE(swing.Init(), "EN-02.2: swing init");
    TEST_TRUE(pivot.Init(), "EN-02.2: pivot init");
    TEST_TRUE(bos.Init(), "EN-02.2: BOS init");

    CVisualizationManager mgr;
    TEST_TRUE(mgr.Init(), "EN-02.2: manager init");
    mgr.SetSwingDetector(GetPointer(swing));
    mgr.SetPivotEngine(GetPointer(pivot));
    mgr.SetBOSDetector(GetPointer(bos));

    CHistoryEpoch epoch;
    epoch.AddConsumer(GetPointer(swing));
    epoch.AddConsumer(GetPointer(pivot));
    epoch.AddConsumer(GetPointer(bos));
    epoch.AddConsumer(GetPointer(mgr));

    //--- tick 1: baseline + full scan + draw. Pins the fixture: the REC
    //    chain emits exactly 2 BOS and the renderer draws both.
    epoch.Update(REC_BARS, time[0]);
    swing.Update(high, low, time, REC_BARS);
    pivot.Update(GetPointer(swing));
    bos.Update(GetPointer(pivot), close, time, REC_BARS);
    mgr.Update();
    TEST_INT_EQ(1, bos.GetBOSCount(), "EN-02.2: full scan emits 1 BOS (C4 fixture pin)");
    TEST_INT_EQ(1, mgr.GetBOSRenderedCount(), "EN-02.2: renderer drew the single BOS events");
    TEST_INT_EQ(0, (int)mgr.GetHistoryResetCount(), "EN-02.2: baseline fires no reset");

    //--- tick 2: shrink (24 -> 10). The broadcast clears the detectors
    //    AND the manager. THE fix discriminator: the renderer cursor
    //    must drop to 0 (RED pre-fix: stays 2 - stale draw state).
    epoch.Update(10, time[0]);
    TEST_INT_EQ(1, (int)mgr.GetHistoryResetCount(), "EN-02.2: shrink notified the manager");
    TEST_INT_EQ(0, bos.GetBOSCount(), "EN-02.2: detectors cleared by the broadcast");
    TEST_INT_EQ(0, mgr.GetBOSRenderedCount(),
        "EN-02.2: renderer draw cursor cleared by the broadcast");

    //--- tick 3: rebuild from the current history (fresh-scan path) and
    //    re-render. The zeroed cursor re-draws the full rebuilt
    //    population (2 BOS again).
    swing.Update(high, low, time, REC_BARS);
    pivot.Update(GetPointer(swing));
    bos.Update(GetPointer(pivot), close, time, REC_BARS);
    TEST_INT_EQ(1, bos.GetBOSCount(), "EN-02.2: rebuilt scan reproduces the BOS");
    mgr.Update();
    TEST_INT_EQ(1, mgr.GetBOSRenderedCount(),
        "EN-02.2: rebuilt population re-rendered from a zeroed cursor");

    mgr.Shutdown();
}

//+------------------------------------------------------------------+
//| Suite entry                                                      |
//+------------------------------------------------------------------+
TestCounters RunVisualizationResetTests(void)
{
    TestCounters counters;

    SUITE_BEGIN("Visualization Reset Tests (EN-02)");

    TestEN02_ManagerRegistrationSemantics(counters);
    TestEN02_RendererResetDropsDrawCursor(counters);

    SUITE_END("Visualization Reset Tests (EN-02)");

    return counters;
}

#endif // __TEST_VISUALIZATION_RESET_MQH__
