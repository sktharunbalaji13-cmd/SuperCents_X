//+------------------------------------------------------------------+
//|                                          PortfolioTypes.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __PORTFOLIO_PORTFOLIO_TYPES_MQH__
#define __PORTFOLIO_PORTFOLIO_TYPES_MQH__

#include "../Monitoring/MonitoringTypes.mqh"
#include "../Risk/RiskTypes.mqh"

#define MAX_PORTFOLIO_SYMBOLS 5

struct SymbolRegistration
{
    string          symbol;
    ENUM_TIMEFRAMES timeframe;
    bool            enabled;
    RiskConfig      riskConfig;

    SymbolRegistration(void)
        : symbol("")
        , timeframe(PERIOD_CURRENT)
        , enabled(true)
    {
    }
};

struct PortfolioConfiguration
{
    SymbolRegistration  symbols[MAX_PORTFOLIO_SYMBOLS];
    int                 symbolCount;

    PortfolioConfiguration(void)
        : symbolCount(0)
    {
    }
};

struct PerSymbolMetrics
{
    string          symbol;
    long            updateCount;
    ulong           lastUpdateLatency;
    ENUM_HEALTH_STATUS healthStatus;
    int             positionCount;
    double          totalExposure;
    double          unrealizedPL;

    PerSymbolMetrics(void)
        : symbol("")
        , updateCount(0)
        , lastUpdateLatency(0)
        , healthStatus(HEALTH_HEALTHY)
        , positionCount(0)
        , totalExposure(0.0)
        , unrealizedPL(0.0)
    {
    }
};

struct PortfolioSnapshot
{
    PerSymbolMetrics    symbols[MAX_PORTFOLIO_SYMBOLS];
    int                 activeSymbolCount;
    int                 totalPositions;
    double              totalExposure;
    double              totalPL;
    double              netExposurePercent;

    PortfolioSnapshot(void)
        : activeSymbolCount(0)
        , totalPositions(0)
        , totalExposure(0.0)
        , totalPL(0.0)
        , netExposurePercent(0.0)
    {
    }
};

#endif
