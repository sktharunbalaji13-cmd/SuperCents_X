//+------------------------------------------------------------------+
//|                                      PortfolioRiskTypes.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __PORTFOLIO_PORTFOLIO_RISK_TYPES_MQH__
#define __PORTFOLIO_PORTFOLIO_RISK_TYPES_MQH__

#include "../Utils/Constants.mqh"
#include "../Entry/ExecutionPlanTypes.mqh"
#include "PortfolioTypes.mqh"

enum ENUM_ALLOCATION_DECISION
{
    ALLOC_APPROVED = 0,
    ALLOC_REJECTED,
    ALLOC_REDUCED_SIZE,
    ALLOC_DEFERRED
};

struct PortfolioLimits
{
    double  maxPortfolioRiskPercent;
    int     maxConcurrentPositions;
    double  maxCorrelationThreshold;
    double  maxSymbolConcentrationPercent;
    double  maxCapitalUtilizationPercent;
    double  maxDailyLossPercent;
    double  maxDrawdownPercent;

    PortfolioLimits(void)
        : maxPortfolioRiskPercent(10.0)
        , maxConcurrentPositions(10)
        , maxCorrelationThreshold(0.7)
        , maxSymbolConcentrationPercent(30.0)
        , maxCapitalUtilizationPercent(80.0)
        , maxDailyLossPercent(-5.0)
        , maxDrawdownPercent(-20.0)
    {}
};

struct PortfolioExposure
{
    double  totalOpenRiskPercent;
    double  netLongExposure;
    double  netShortExposure;
    double  grossExposure;
    double  marginUsed;
    double  marginFree;
    double  marginUtilizationPercent;
    int     totalPositions;
    double  dailyPL;
    double  currentDrawdownPercent;

    PortfolioExposure(void)
        : totalOpenRiskPercent(0.0)
        , netLongExposure(0.0)
        , netShortExposure(0.0)
        , grossExposure(0.0)
        , marginUsed(0.0)
        , marginFree(0.0)
        , marginUtilizationPercent(0.0)
        , totalPositions(0)
        , dailyPL(0.0)
        , currentDrawdownPercent(0.0)
    {}
};

struct AllocationRequest
{
    string              symbol;
    ConfluenceDirection direction;
    double              requestedLots;
    double              entryPrice;
    double              stopLoss;
    double              riskAmount;
    double              riskPercent;

    AllocationRequest(void)
        : symbol("")
        , direction(CONFLUENCE_NONE)
        , requestedLots(0.0)
        , entryPrice(0.0)
        , stopLoss(0.0)
        , riskAmount(0.0)
        , riskPercent(0.0)
    {}
};

struct AllocationDecision
{
    ENUM_ALLOCATION_DECISION decision;
    double                   allocatedLots;
    double                   allocatedRiskAmount;
    string                   reason;

    AllocationDecision(void)
        : decision(ALLOC_REJECTED)
        , allocatedLots(0.0)
        , allocatedRiskAmount(0.0)
        , reason("")
    {}

    bool IsApproved(void) const
    {
        return (decision == ALLOC_APPROVED || decision == ALLOC_REDUCED_SIZE);
    }
};

struct PortfolioRiskDecision
{
    ENUM_ALLOCATION_DECISION decision;
    string                   rejectionReason;
    double                   allowedLots;
    double                   allowedRiskCapital;

    PortfolioRiskDecision(void)
        : decision(ALLOC_REJECTED)
        , rejectionReason("")
        , allowedLots(0.0)
        , allowedRiskCapital(0.0)
    {}

    bool IsApproved(void) const
    {
        return (decision == ALLOC_APPROVED || decision == ALLOC_REDUCED_SIZE);
    }
};

#endif
