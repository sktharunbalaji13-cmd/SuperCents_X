//+------------------------------------------------------------------+
//|                                        MonitoringTypes.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __MONITORING_MONITORING_TYPES_MQH__
#define __MONITORING_MONITORING_TYPES_MQH__

#include "../Utils/Constants.mqh"

enum ENUM_HEALTH_STATUS
{
    HEALTH_HEALTHY = 0,
    HEALTH_WARNING,
    HEALTH_CRITICAL
};

enum ENUM_EVENT_TYPE
{
    EVENT_POSITION_OPENED = 0,
    EVENT_POSITION_MODIFIED,
    EVENT_POSITION_CLOSED,
    EVENT_TRADE_REJECTED,
    EVENT_RISK_REJECTED
};

struct ModuleMetrics
{
    ENUM_MODULE_ID  moduleId;
    long            executionCount;
    ulong           totalRuntime;
    ulong           averageRuntime;
    ulong           maxRuntime;
    ulong           lastRuntime;

    ModuleMetrics(void)
        : moduleId(MODULE_UNKNOWN)
        , executionCount(0)
        , totalRuntime(0)
        , averageRuntime(0)
        , maxRuntime(0)
        , lastRuntime(0)
    {}
};

struct PerformanceSnapshot
{
    ModuleMetrics   metrics[MODULE_UNKNOWN + 1];
    int             moduleCount;

    PerformanceSnapshot(void)
        : moduleCount(0)
    {}
};

struct PipelineCounters
{
    long    decisionsMade;
    long    candidatesEvaluated;
    long    riskEvaluations;
    long    ordersSent;
    long    ordersFilled;
    long    ordersRejected;
    long    positionsOpened;
    long    positionsClosed;

    PipelineCounters(void)
        : decisionsMade(0)
        , candidatesEvaluated(0)
        , riskEvaluations(0)
        , ordersSent(0)
        , ordersFilled(0)
        , ordersRejected(0)
        , positionsOpened(0)
        , positionsClosed(0)
    {}
};

struct TradeStatistics
{
    int     totalTrades;
    int     wins;
    int     losses;
    double  winRate;
    double  avgRR;
    double  avgDurationSec;
    double  largestWin;
    double  largestLoss;
    double  totalProfit;
    double  expectancy;

    TradeStatistics(void)
        : totalTrades(0)
        , wins(0)
        , losses(0)
        , winRate(0.0)
        , avgRR(0.0)
        , avgDurationSec(0.0)
        , largestWin(0.0)
        , largestLoss(0.0)
        , totalProfit(0.0)
        , expectancy(0.0)
    {}
};

struct ModuleHealthEntry
{
    ENUM_MODULE_ID      moduleId;
    string              moduleName;
    bool                isInitialized;
    int                 contextCount;
    ENUM_HEALTH_STATUS  status;
    string              lastError;

    ModuleHealthEntry(void)
        : moduleId(MODULE_UNKNOWN)
        , moduleName("")
        , isInitialized(false)
        , contextCount(0)
        , status(HEALTH_CRITICAL)
        , lastError("")
    {}
};

#define MAX_HEALTH_ENTRIES 64

struct HealthSnapshot
{
    ENUM_HEALTH_STATUS  overallStatus;
    ModuleHealthEntry   entries[MAX_HEALTH_ENTRIES];
    int                 entryCount;
    int                 warningCount;
    int                 criticalCount;

    HealthSnapshot(void)
        : overallStatus(HEALTH_HEALTHY)
        , entryCount(0)
        , warningCount(0)
        , criticalCount(0)
    {}
};

struct EventData
{
    ENUM_EVENT_TYPE     eventType;
    ulong               ticket;
    string              symbol;
    long                positionType;
    double              volume;
    double              entryPrice;
    double              exitPrice;
    double              stopLoss;
    double              takeProfit;
    double              profit;
    double              commission;
    double              swap;
    datetime            openedTime;
    datetime            closedTime;
    int                 entryDecisionId;
    string              reason;

    EventData(void)
        : eventType(EVENT_POSITION_OPENED)
        , ticket(0)
        , symbol("")
        , positionType(-1)
        , volume(0.0)
        , entryPrice(0.0)
        , exitPrice(0.0)
        , stopLoss(0.0)
        , takeProfit(0.0)
        , profit(0.0)
        , commission(0.0)
        , swap(0.0)
        , openedTime(0)
        , closedTime(0)
        , entryDecisionId(0)
        , reason("")
    {}
};

#endif
