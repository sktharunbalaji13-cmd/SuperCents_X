#ifndef __WALK_FORWARD_PIPELINE_MQH__
#define __WALK_FORWARD_PIPELINE_MQH__

#include "../Core/Logger.mqh"
#include "ValidationLab.mqh"
#include "WalkForwardSchedule.mqh"

class CWalkForwardPipeline
{
private:
    CLogger         m_logger;
    bool            m_isInitialized;
    CValidationLab  *m_lab;

    bool BuildRequest(const WfExecutionWindow &window, ValidationRequest &req) const
    {
        req = ValidationRequest();
        req.experimentLabel = window.windowId;
        req.symbols[0] = window.symbol;
        req.symbolCount = 1;
        req.timeframes[0] = window.timeframe;
        req.timeframeCount = 1;
        req.testStart = window.testStart;
        req.testEnd = window.testEnd;
        req.parameterSetId = window.parameterSetId;
        req.initialDeposit = 10000.0;
        req.enableBehavioralMetrics = true;

        if(req.symbols[0] == "" || req.testStart <= 0 || req.testEnd <= 0)
            return false;
        return true;
    }

public:
    CWalkForwardPipeline(void)
        : m_logger(MODULE_LABORATORY, "WalkForwardPipeline")
        , m_isInitialized(false)
        , m_lab(NULL)
    {}

    ~CWalkForwardPipeline(void)
    {
        Shutdown();
    }

    bool Init(CValidationLab *lab)
    {
        if(lab == NULL || !lab.IsInitialized())
        {
            m_logger.LogError("WalkForwardPipeline requires an initialized ValidationLab");
            return false;
        }

        m_lab = lab;
        m_isInitialized = true;
        m_logger.LogInfo("WalkForwardPipeline initialized");
        return true;
    }

    void Shutdown(void)
    {
        m_lab = NULL;
        m_isInitialized = false;
    }

    bool IsInitialized(void) const { return m_isInitialized; }

    bool Execute(const WalkForwardSchedule &schedule, WalkForwardSummary &summary)
    {
        if(!m_isInitialized || m_lab == NULL)
        {
            m_logger.LogError("WalkForwardPipeline not initialized");
            return false;
        }

        summary = WalkForwardSummary();
        summary.experimentLabel = StringFormat("WF-%s-%s-%s",
            ModeToString(schedule.config.mode),
            TimeToString(schedule.config.overallStart, TIME_DATE),
            TimeToString(schedule.config.overallEnd, TIME_DATE));
        summary.started = TimeCurrent();

        int maxWindows = schedule.windowCount;
        ArrayResize(summary.results, maxWindows);

        for(int i = 0; i < maxWindows; i++)
        {
            WfExecutionWindow w = schedule.windows[i];
            WalkForwardWindowResult r;
            r.window = w;
            r.failReason = "";

            if(w.trainStart <= 0 || w.trainEnd <= 0 || w.testStart <= 0 || w.testEnd <= 0)
            {
                r.status = WINDOW_FAIL_SCHEDULE;
                r.failReason = "Window has zero dates: schedule generation error";
                summary.scheduleFailures++;
                summary.results[i] = r;
                continue;
            }

            if(w.testEnd <= w.testStart)
            {
                r.status = WINDOW_FAIL_SCHEDULE;
                r.failReason = "testEnd must be after testStart";
                summary.scheduleFailures++;
                summary.results[i] = r;
                continue;
            }

            ValidationRequest req;
            if(!BuildRequest(w, req))
            {
                r.status = WINDOW_FAIL_SCHEDULE;
                r.failReason = "Failed to build ValidationRequest from window";
                summary.scheduleFailures++;
                summary.results[i] = r;
                continue;
            }

            r.execStart = GetTickCount();

            if(!m_lab.StartRun(req))
            {
                r.status = WINDOW_FAIL_EXECUTION;
                r.failReason = "ValidationLab.StartRun failed";
                r.execEnd = GetTickCount();
                r.execDurationMs = r.execEnd - r.execStart;
                summary.executionFailures++;
                summary.results[i] = r;
                continue;
            }

            if(!m_lab.EndRun(r.result))
            {
                r.status = WINDOW_FAIL_EXECUTION;
                r.failReason = "ValidationLab.EndRun failed";
                r.execEnd = GetTickCount();
                r.execDurationMs = r.execEnd - r.execStart;
                summary.executionFailures++;
                summary.results[i] = r;
                continue;
            }

            r.status = WINDOW_PASS;
            r.execEnd = GetTickCount();
            r.execDurationMs = r.execEnd - r.execStart;
            summary.validWindows++;
            summary.results[i] = r;

            m_logger.LogInfo(StringFormat(
                "Window %s: PASS (%d trades, P/L=%.2f, %lldms)",
                w.windowId, r.result.strategyReport.totalTrades,
                r.result.strategyReport.totalNetProfit, r.execDurationMs));
        }

        summary.totalWindows = maxWindows;
        summary.completed = TimeCurrent();
        summary.completedSuccessfully = true;

        m_logger.LogInfo(StringFormat(
            "Walk-forward complete: %d windows, %d pass, %d schedule fail, %d exec fail",
            summary.totalWindows, summary.validWindows,
            summary.scheduleFailures, summary.executionFailures));

        return true;
    }

    string ModeToString(ENUM_WALK_FORWARD_MODE mode) const
    {
        if(mode == WF_ROLLING)   return "ROL";
        if(mode == WF_EXPANDING) return "EXP";
        if(mode == WF_ANCHORED)  return "ANC";
        return "UNK";
    }
};

#endif
