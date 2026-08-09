#ifndef __WALK_FORWARD_SCHEDULER_MQH__
#define __WALK_FORWARD_SCHEDULER_MQH__

#include "WalkForwardSchedule.mqh"

#define MAX_SCHEDULE_WINDOWS 200
#define MAX_SCHEDULE_WARNINGS 50

class CWalkForwardScheduler
{
private:
    bool m_isInitialized;

    string ModeToString(ENUM_WALK_FORWARD_MODE mode) const
    {
        if(mode == WF_ROLLING)  return "ROL";
        if(mode == WF_EXPANDING) return "EXP";
        if(mode == WF_ANCHORED) return "ANC";
        return "UNK";
    }

    string BuildWindowId(ENUM_WALK_FORWARD_MODE mode, datetime testStart,
                         datetime testEnd, int index) const
    {
        return StringFormat("WF-%s-%s-%s-%04d",
            ModeToString(mode),
            TimeToString(testStart, TIME_DATE),
            TimeToString(testEnd, TIME_DATE),
            index);
    }

    void AddWarning(WalkForwardSchedule &schedule, const string code,
                    const string message, int windowIndex) const
    {
        if(schedule.warningCount >= MAX_SCHEDULE_WARNINGS)
            return;
        ScheduleWarning w;
        w.code = code;
        w.message = message;
        w.windowIndex = windowIndex;
        schedule.warnings[schedule.warningCount] = w;
        schedule.warningCount++;
    }

    bool ConfigIsValid(const WalkForwardScheduleConfig &cfg) const
    {
        if(cfg.overallStart <= 0 || cfg.overallEnd <= 0)
            return false;
        if(cfg.overallEnd <= cfg.overallStart)
            return false;
        if(cfg.windowDays <= 0 || cfg.stepDays <= 0)
            return false;
        if(cfg.trainRatio <= 0.0 || cfg.trainRatio >= 1.0)
            return false;
        if(cfg.minTrainDays <= 0 || cfg.minTestDays <= 0)
            return false;
        return true;
    }

    bool GenerateRolling(const WalkForwardScheduleConfig &cfg,
                          WalkForwardSchedule &schedule) const
    {
        long windowSec = (long)cfg.windowDays * 86400;
        long stepSec = (long)cfg.stepDays * 86400;
        long trainSec = (long)(windowSec * cfg.trainRatio);
        long testSec = windowSec - trainSec;
        long minTrainSec = (long)cfg.minTrainDays * 86400;
        long minTestSec = (long)cfg.minTestDays * 86400;

        if(trainSec < minTrainSec)
        {
            trainSec = minTrainSec;
            windowSec = trainSec + testSec;
        }
        if(testSec < minTestSec)
        {
            testSec = minTestSec;
            windowSec = trainSec + testSec;
        }

        int idx = 0;
        for(int step = 0; step < MAX_SCHEDULE_WINDOWS; step++)
        {
            long winStart = (long)cfg.overallStart + step * stepSec;
            long tStart = winStart;
            long tEnd = winStart + trainSec;
            long tsStart = tEnd;
            long tsEnd = winStart + windowSec;

            if(tsEnd > (long)cfg.overallEnd)
                break;

            if(tsEnd - tsStart < minTestSec || tEnd - tStart < minTrainSec)
            {
                AddWarning(schedule, "INSUFFICIENT_DATA",
                    StringFormat("Window %d: train=%lldd test=%lldd below minimum", step,
                        (tEnd - tStart) / 86400, (tsEnd - tsStart) / 86400), idx);
            }

            WfExecutionWindow w;
            w.windowIndex = idx;
            w.windowId = BuildWindowId(cfg.mode, (datetime)tsStart, (datetime)tsEnd, idx);
            w.trainStart = (datetime)tStart;
            w.trainEnd = (datetime)tEnd;
            w.testStart = (datetime)tsStart;
            w.testEnd = (datetime)tsEnd;
            schedule.windows[idx] = w;
            idx++;
        }
        schedule.windowCount = idx;
        return idx > 0;
    }

    bool GenerateExpanding(const WalkForwardScheduleConfig &cfg,
                            WalkForwardSchedule &schedule) const
    {
        long windowSec = (long)cfg.windowDays * 86400;
        long stepSec = (long)cfg.stepDays * 86400;
        long trainSec = (long)(windowSec * cfg.trainRatio);
        long testSec = windowSec - trainSec;
        long minTrainSec = (long)cfg.minTrainDays * 86400;
        long minTestSec = (long)cfg.minTestDays * 86400;

        if(testSec < minTestSec)
        {
            testSec = minTestSec;
            windowSec = testSec;
        }

        int idx = 0;
        for(int step = 0; step < MAX_SCHEDULE_WINDOWS; step++)
        {
            long trainEnd = (long)cfg.overallStart + minTrainSec + step * stepSec;
            long tsStart = trainEnd;
            long tsEnd = tsStart + testSec;

            if(tsEnd > (long)cfg.overallEnd)
                break;

            long trainDuration = trainEnd - (long)cfg.overallStart;
            if(trainDuration < minTrainSec)
            {
                AddWarning(schedule, "INSUFFICIENT_TRAIN",
                    StringFormat("Window %d: train duration %lldd below minimum %lldd",
                        step, trainDuration / 86400, minTrainSec / 86400), idx);
            }

            WfExecutionWindow w;
            w.windowIndex = idx;
            w.windowId = BuildWindowId(cfg.mode, (datetime)tsStart, (datetime)tsEnd, idx);
            w.trainStart = cfg.overallStart;
            w.trainEnd = (datetime)trainEnd;
            w.testStart = (datetime)tsStart;
            w.testEnd = (datetime)tsEnd;
            schedule.windows[idx] = w;
            idx++;
        }
        schedule.windowCount = idx;
        return idx > 0;
    }

    bool GenerateAnchored(const WalkForwardScheduleConfig &cfg,
                           WalkForwardSchedule &schedule) const
    {
        long windowSec = (long)cfg.windowDays * 86400;
        long stepSec = (long)cfg.stepDays * 86400;
        long trainSec = (long)(windowSec * cfg.trainRatio);
        long testSec = windowSec - trainSec;
        long minTrainSec = (long)cfg.minTrainDays * 86400;
        long minTestSec = (long)cfg.minTestDays * 86400;

        if(testSec < minTestSec)
        {
            testSec = minTestSec;
        }

        long anchorTrainEnd = (long)cfg.overallStart + trainSec;
        if(anchorTrainEnd - (long)cfg.overallStart < minTrainSec)
        {
            anchorTrainEnd = (long)cfg.overallStart + minTrainSec;
        }

        int idx = 0;
        for(int step = 0; step < MAX_SCHEDULE_WINDOWS; step++)
        {
            long tsStart = anchorTrainEnd + step * stepSec;
            long tsEnd = tsStart + testSec;

            if(tsEnd > (long)cfg.overallEnd)
                break;

            WfExecutionWindow w;
            w.windowIndex = idx;
            w.windowId = BuildWindowId(cfg.mode, (datetime)tsStart, (datetime)tsEnd, idx);
            w.trainStart = cfg.overallStart;
            w.trainEnd = (datetime)anchorTrainEnd;
            w.testStart = (datetime)tsStart;
            w.testEnd = (datetime)tsEnd;
            schedule.windows[idx] = w;
            idx++;
        }
        schedule.windowCount = idx;
        return idx > 0;
    }

public:
    CWalkForwardScheduler(void)
        : m_isInitialized(false)
    {}

    bool Init(void)
    {
        m_isInitialized = true;
        return true;
    }

    void Shutdown(void)
    {
        m_isInitialized = false;
    }

    bool IsInitialized(void) const { return m_isInitialized; }

    bool Generate(const WalkForwardScheduleConfig &cfg,
                  WalkForwardSchedule &schedule) const
    {
        schedule = WalkForwardSchedule();
        schedule.config = cfg;
        schedule.generatedAt = 0;

        if(!m_isInitialized)
            return false;

        if(!ConfigIsValid(cfg))
            return false;

        ArrayResize(schedule.windows, MAX_SCHEDULE_WINDOWS);
        ArrayResize(schedule.warnings, MAX_SCHEDULE_WARNINGS);

        if(cfg.mode == WF_ROLLING)
            return GenerateRolling(cfg, schedule);
        if(cfg.mode == WF_EXPANDING)
            return GenerateExpanding(cfg, schedule);
        if(cfg.mode == WF_ANCHORED)
            return GenerateAnchored(cfg, schedule);

        return false;
    }
};

#endif
