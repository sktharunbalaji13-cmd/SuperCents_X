#include "../../Validation/WalkForwardScheduler.mqh"
#include "../TestAssert.mqh"

TestCounters RunWalkForwardTests(void)
{
    TestCounters counters;

    SUITE_BEGIN("WalkForward Unit Tests");

    // Test 1: Rolling generates windows
    {
        WalkForwardScheduleConfig cfg;
        cfg.overallStart = D'2020.01.01';
        cfg.overallEnd = D'2022.01.01';
        cfg.mode = WF_ROLLING;
        cfg.windowDays = 180;
        cfg.stepDays = 60;
        cfg.trainRatio = 0.70;
        cfg.minTrainDays = 30;
        cfg.minTestDays = 10;

        CWalkForwardScheduler sched;
        sched.Init();
        WalkForwardSchedule schedule;
        bool ok = sched.Generate(cfg, schedule);

        TEST_TRUE(ok, "Rolling schedule should be generated");
        TEST_TRUE(schedule.windowCount > 0, "Rolling schedule should have windows");
        TEST_INT_EQ(0, schedule.warningCount, "Standard config should have no warnings");
        if(schedule.windowCount > 0)
        {
            WfExecutionWindow w = schedule.windows[0];
            TEST_TRUE(StringFind(w.windowId, "WF-ROL-") == 0, "Window 0 ID starts with WF-ROL-");
            TEST_INT_EQ(0, w.windowIndex, "Window 0 index");
            TEST_DATETIME_EQ(D'2020.01.01', w.trainStart, "Window 0 train start");
            TEST_TRUE(w.trainEnd > w.trainStart, "Window 0 train end > start");
            TEST_TRUE(w.testStart >= w.trainEnd, "Window 0 test start >= train end");
            TEST_TRUE(w.testEnd > w.testStart, "Window 0 test end > start");
        }
    }

    // Test 2: Expanding mode keeps trainStart fixed
    {
        WalkForwardScheduleConfig cfg;
        cfg.overallStart = D'2020.01.01';
        cfg.overallEnd = D'2022.01.01';
        cfg.mode = WF_EXPANDING;
        cfg.windowDays = 180;
        cfg.stepDays = 60;
        cfg.trainRatio = 0.70;
        cfg.minTrainDays = 30;
        cfg.minTestDays = 10;

        CWalkForwardScheduler sched;
        sched.Init();
        WalkForwardSchedule schedule;
        bool ok = sched.Generate(cfg, schedule);

        TEST_TRUE(ok, "Expanding schedule should be generated");
        TEST_TRUE(schedule.windowCount > 0, "Expanding schedule should have windows");
        if(schedule.windowCount > 0)
        {
            TEST_DATETIME_EQ(D'2020.01.01', schedule.windows[0].trainStart, "Expanding window 0 train start = overallStart");
            if(schedule.windowCount > 1)
                TEST_DATETIME_EQ(D'2020.01.01', schedule.windows[1].trainStart, "Expanding window 1 train start = overallStart");
        }
    }

    // Test 3: Anchored mode keeps train end fixed
    {
        WalkForwardScheduleConfig cfg;
        cfg.overallStart = D'2020.01.01';
        cfg.overallEnd = D'2022.01.01';
        cfg.mode = WF_ANCHORED;
        cfg.windowDays = 180;
        cfg.stepDays = 60;
        cfg.trainRatio = 0.70;
        cfg.minTrainDays = 30;
        cfg.minTestDays = 10;

        CWalkForwardScheduler sched;
        sched.Init();
        WalkForwardSchedule schedule;
        bool ok = sched.Generate(cfg, schedule);

        TEST_TRUE(ok, "Anchored schedule should be generated");
        TEST_TRUE(schedule.windowCount > 0, "Anchored schedule should have windows");
        if(schedule.windowCount > 0)
        {
            datetime firstTrainEnd = schedule.windows[0].trainEnd;
            TEST_DATETIME_EQ(D'2020.01.01', schedule.windows[0].trainStart, "Anchored window 0 train start = overallStart");
            for(int i = 1; i < schedule.windowCount; i++)
            {
                TEST_DATETIME_EQ(firstTrainEnd, schedule.windows[i].trainEnd,
                    "Anchored window train end unchanged");
            }
        }
    }

    // Test 4: Same config → deterministic schedule
    {
        WalkForwardScheduleConfig cfg;
        cfg.overallStart = D'2020.06.01';
        cfg.overallEnd = D'2021.06.01';
        cfg.mode = WF_ROLLING;
        cfg.windowDays = 90;
        cfg.stepDays = 30;
        cfg.trainRatio = 0.70;
        cfg.minTrainDays = 20;
        cfg.minTestDays = 10;

        CWalkForwardScheduler sched;
        sched.Init();
        WalkForwardSchedule s1, s2;
        sched.Generate(cfg, s1);
        sched.Generate(cfg, s2);

        TEST_INT_EQ(s1.windowCount, s2.windowCount, "Deterministic: window count matches");
        int n = MathMin(s1.windowCount, s2.windowCount);
        for(int i = 0; i < n; i++)
        {
            TEST_STR_EQ(s1.windows[i].windowId, s2.windows[i].windowId, "Deterministic: window ID matches");
            TEST_DATETIME_EQ(s1.windows[i].trainStart, s2.windows[i].trainStart, "Deterministic: trainStart matches");
            TEST_DATETIME_EQ(s1.windows[i].testEnd, s2.windows[i].testEnd, "Deterministic: testEnd matches");
        }
    }

    // Test 5: Invalid dates → empty schedule
    {
        WalkForwardScheduleConfig cfg;
        cfg.overallStart = D'2022.01.01';
        cfg.overallEnd = D'2020.01.01';
        cfg.mode = WF_ROLLING;

        CWalkForwardScheduler sched;
        sched.Init();
        WalkForwardSchedule schedule;
        bool ok = sched.Generate(cfg, schedule);

        TEST_FALSE(ok, "End before start should fail");
        TEST_INT_EQ(0, schedule.windowCount, "End before start → no windows");
    }

    // Test 6: Below-min windows → warning emitted
    {
        WalkForwardScheduleConfig cfg;
        cfg.overallStart = D'2020.01.01';
        cfg.overallEnd = D'2020.03.01';
        cfg.mode = WF_ROLLING;
        cfg.windowDays = 30;
        cfg.stepDays = 15;
        cfg.trainRatio = 0.50;
        cfg.minTrainDays = 100;
        cfg.minTestDays = 50;

        CWalkForwardScheduler sched;
        sched.Init();
        WalkForwardSchedule schedule;
        bool ok = sched.Generate(cfg, schedule);

        TEST_FALSE(ok, "Schedule with insufficient data should return false");
        TEST_INT_EQ(0, schedule.windowCount, "Insufficient data → zero windows");
    }

    // Test 7: Window ID format
    {
        WalkForwardScheduleConfig cfg;
        cfg.overallStart = D'2020.01.01';
        cfg.overallEnd = D'2020.06.01';
        cfg.mode = WF_ROLLING;
        cfg.windowDays = 60;
        cfg.stepDays = 30;
        cfg.trainRatio = 0.70;
        cfg.minTrainDays = 10;
        cfg.minTestDays = 10;

        CWalkForwardScheduler sched;
        sched.Init();
        WalkForwardSchedule schedule;
        sched.Generate(cfg, schedule);

        for(int i = 0; i < schedule.windowCount; i++)
        {
            const string wid = schedule.windows[i].windowId;
            TEST_TRUE(StringLen(wid) > 0, "Window ID should not be empty");
            TEST_TRUE(StringFind(wid, "WF-") == 0, "Window ID should start with WF-");
        }
    }

    SUITE_END("WalkForward Unit Tests");
    return counters;
}
