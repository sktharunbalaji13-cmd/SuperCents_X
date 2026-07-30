#ifndef __WALK_FORWARD_TYPES_MQH__
#define __WALK_FORWARD_TYPES_MQH__

#include "../Optimization/OptimizationTypes.mqh"
#include "ValidationTypes.mqh"

// @frozen v2.7 -- Public API. Append values only; no reordering.
enum ENUM_WALK_FORWARD_MODE
{
    WF_ROLLING,
    WF_EXPANDING,
    WF_ANCHORED
};

// @frozen v2.7 -- Public API. Append values only.
enum ENUM_WINDOW_STATUS
{
    WINDOW_PENDING,
    WINDOW_PASS,
    WINDOW_FAIL_SCHEDULE,
    WINDOW_FAIL_EXECUTION
};

struct WfExecutionWindow
{
    int             windowIndex;
    string          windowId;
    datetime        trainStart;
    datetime        trainEnd;
    datetime        testStart;
    datetime        testEnd;
    string          symbol;
    ENUM_TIMEFRAMES timeframe;
    string          parameterSetId;
};

struct WalkForwardScheduleConfig
{
    datetime            overallStart;
    datetime            overallEnd;
    ENUM_WALK_FORWARD_MODE  mode;
    int                 windowDays;
    int                 stepDays;
    double              trainRatio;
    int                 minTrainDays;
    int                 minTestDays;

    WalkForwardScheduleConfig(void)
        : overallStart(0)
        , overallEnd(0)
        , mode(WF_ROLLING)
        , windowDays(365)
        , stepDays(90)
        , trainRatio(0.70)
        , minTrainDays(100)
        , minTestDays(50)
    {}
};

struct ScheduleWarning
{
    string   code;
    string   message;
    int      windowIndex;

    ScheduleWarning(void)
        : code(""), message(""), windowIndex(-1)
    {}
};

struct WalkForwardWindowResult
{
    WfExecutionWindow   window;
    ENUM_WINDOW_STATUS  status;
    string              failReason;
    ValidationResult    result;

    datetime            execStart;
    datetime            execEnd;
    long                execDurationMs;

    WalkForwardWindowResult(void)
        : status(WINDOW_PENDING)
        , failReason("")
        , execStart(0)
        , execEnd(0)
        , execDurationMs(0)
    {}
};

// @frozen v2.7 -- Public API contract. Append fields only.
struct WalkForwardSummary
{
    string                     experimentLabel;
    bool                       completedSuccessfully;
    WalkForwardWindowResult    results[];
    int                        totalWindows;
    int                        validWindows;
    int                        scheduleFailures;
    int                        executionFailures;
    datetime                   started;
    datetime                   completed;

    WalkForwardSummary(void)
        : experimentLabel("")
        , completedSuccessfully(false)
        , totalWindows(0)
        , validWindows(0)
        , scheduleFailures(0)
        , executionFailures(0)
        , started(0)
        , completed(0)
    {}
};

#endif
