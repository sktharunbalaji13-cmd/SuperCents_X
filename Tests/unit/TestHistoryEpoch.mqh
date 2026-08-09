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

    SUITE_END("History Epoch Tests");

    return counters;
}

#endif // __TEST_HISTORY_EPOCH_MQH__
