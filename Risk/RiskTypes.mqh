//+------------------------------------------------------------------+
//|                                              RiskTypes.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __RISK_RISK_TYPES_MQH__
#define __RISK_RISK_TYPES_MQH__

struct RiskConfig
{
    double  maxRiskPerTradePercent;
    double  maxPortfolioExposurePercent;
    int     maxConcurrentPositions;
    double  dailyLossLimitPercent;
    double  weeklyLossLimitPercent;
    double  equityStopPercent;
    double  minLotSize;
    double  maxLotSize;
    double  maxLeverageUtilization;

    RiskConfig(void)
        : maxRiskPerTradePercent(2.0)
        , maxPortfolioExposurePercent(50.0)
        , maxConcurrentPositions(5)
        , dailyLossLimitPercent(-5.0)
        , weeklyLossLimitPercent(-10.0)
        , equityStopPercent(-20.0)
        , minLotSize(0.01)
        , maxLotSize(100.0)
        , maxLeverageUtilization(80.0)
    {}
};

enum ENUM_RISK_DECISION
{
    RISK_APPROVED = 0,
    RISK_REJECTED_MAX_RISK_PER_TRADE,
    RISK_REJECTED_MAX_EXPOSURE,
    RISK_REJECTED_MAX_POSITIONS,
    RISK_REJECTED_DAILY_LOSS_LIMIT,
    RISK_REJECTED_WEEKLY_LOSS_LIMIT,
    RISK_REJECTED_EQUITY_STOP,
    RISK_REJECTED_MAX_LOT_SIZE,
    RISK_REJECTED_MIN_LOT_SIZE,
    RISK_REJECTED_MARGIN_INSUFFICIENT,
    RISK_REJECTED_LEVERAGE_EXCEEDED
};

struct RiskDecision
{
    ENUM_RISK_DECISION  decision;
    double              allowedRiskCapital;
    double              maxAllowedLotSize;
    string              rejectionReason;

    RiskDecision(void)
        : decision(RISK_REJECTED_MARGIN_INSUFFICIENT)
        , allowedRiskCapital(0.0)
        , maxAllowedLotSize(0.0)
        , rejectionReason("")
    {}

    bool IsApproved(void) const
    {
        return (decision == RISK_APPROVED);
    }
};

struct ExposureSnapshot
{
    double  totalOpenRisk;
    double  netLongExposure;
    double  netShortExposure;
    double  totalPortfolioExposure;
    double  marginUsed;
    double  marginFree;
    int     positionCount;

    ExposureSnapshot(void)
        : totalOpenRisk(0.0)
        , netLongExposure(0.0)
        , netShortExposure(0.0)
        , totalPortfolioExposure(0.0)
        , marginUsed(0.0)
        , marginFree(0.0)
        , positionCount(0)
    {}
};

struct DrawdownSnapshot
{
    double  peakEquity;
    double  currentEquity;
    double  dailyPL;
    double  weeklyPL;
    double  currentDrawdownPercent;
    double  maxDrawdownPercent;

    DrawdownSnapshot(void)
        : peakEquity(0.0)
        , currentEquity(0.0)
        , dailyPL(0.0)
        , weeklyPL(0.0)
        , currentDrawdownPercent(0.0)
        , maxDrawdownPercent(0.0)
    {}
};

struct PositionSizingResult
{
    double  lots;
    double  dollarRisk;
    double  marginEstimate;
    bool    valid;
    string  validationMessage;

    PositionSizingResult(void)
        : lots(0.0)
        , dollarRisk(0.0)
        , marginEstimate(0.0)
        , valid(false)
        , validationMessage("")
    {}
};

#endif
