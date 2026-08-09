//+------------------------------------------------------------------+
//|                                            RiskManager.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __RISK_RISK_MANAGER_MQH__
#define __RISK_RISK_MANAGER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "../Entry/ExecutionPlanTypes.mqh"
#include "RiskTypes.mqh"
#include "PositionSizer.mqh"
#include "ExposureTracker.mqh"
#include "DrawdownMonitor.mqh"

class CRiskManager
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    RiskConfig          m_config;
    CPositionSizer     *m_positionSizer;
    CExposureTracker   *m_exposureTracker;
    CDrawdownMonitor   *m_drawdownMonitor;

    int     m_totalEvaluated;
    int     m_totalApproved;
    int     m_totalRejected;
    double  m_sumRiskPercent;
    double  m_sumLotSize;

    double ComputeStopDistance(const ExecutionPlan &plan) const
    {
        if(plan.stopDistance > 0.0)
            return plan.stopDistance;

        if(plan.entryPrice > 0.0 && plan.stopLoss > 0.0)
            return MathAbs(plan.entryPrice - plan.stopLoss) / _Point;

        return 0.0;
    }

public:
    CRiskManager(void);
    ~CRiskManager(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    void SetPositionSizer(CPositionSizer *sizer) { m_positionSizer = sizer; }
    void SetExposureTracker(CExposureTracker *tracker) { m_exposureTracker = tracker; }
    void SetDrawdownMonitor(CDrawdownMonitor *monitor) { m_drawdownMonitor = monitor; }

    RiskConfig GetConfig(void) const { return m_config; }
    void SetConfig(const RiskConfig &config) { m_config = config; }

    RiskDecision Evaluate(const ExecutionPlan &plan);
};

CRiskManager::CRiskManager(void)
    : m_logger(MODULE_RISK_MANAGER, "RiskManager")
    , m_isInitialized(false)
    , m_positionSizer(NULL)
    , m_exposureTracker(NULL)
    , m_drawdownMonitor(NULL)
    , m_totalEvaluated(0)
    , m_totalApproved(0)
    , m_totalRejected(0)
    , m_sumRiskPercent(0.0)
    , m_sumLotSize(0.0)
{
}

CRiskManager::~CRiskManager(void)
{
    Shutdown();
}

bool CRiskManager::Init(void)
{
    m_logger.LogInfo("Initializing RiskManager...");

    if(m_positionSizer == NULL || m_exposureTracker == NULL || m_drawdownMonitor == NULL)
    {
        m_logger.LogError("RiskManager requires PositionSizer, ExposureTracker, and DrawdownMonitor");
        return false;
    }

    m_totalEvaluated = 0;
    m_totalApproved = 0;
    m_totalRejected = 0;
    m_sumRiskPercent = 0.0;
    m_sumLotSize = 0.0;

    m_isInitialized = true;
    m_logger.LogInfo("RiskManager initialized");
    return true;
}

void CRiskManager::Update(void)
{
}

void CRiskManager::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down RiskManager...");

    m_logger.LogInfo("==================== RISK SUMMARY ====================");
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Trades Evaluated", m_totalEvaluated));
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Approved", m_totalApproved));
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Rejected", m_totalRejected));

    double avgRisk = (m_totalApproved > 0.0) ? (m_sumRiskPercent / m_totalApproved) : 0.0;
    double avgLot  = (m_totalApproved > 0.0) ? (m_sumLotSize / m_totalApproved) : 0.0;

    m_logger.LogInfo(StringFormat("  %-30s %5.2f%%", "Average Risk %", avgRisk));
    m_logger.LogInfo(StringFormat("  %-30s %5.2f", "Average Position Size", avgLot));

    if(m_exposureTracker != NULL)
    {
        ExposureSnapshot exp = m_exposureTracker.GetSnapshot();
        m_logger.LogInfo(StringFormat("  %-30s %10.2f", "Current Exposure", exp.totalPortfolioExposure));
        m_logger.LogInfo(StringFormat("  %-30s %10.2f", "Peak Exposure", exp.totalPortfolioExposure));
    }

    if(m_drawdownMonitor != NULL)
    {
        DrawdownSnapshot dd = m_drawdownMonitor.GetSnapshot();
        m_logger.LogInfo(StringFormat("  %-30s %10.2f%%", "Current Drawdown", dd.currentDrawdownPercent));
        m_logger.LogInfo(StringFormat("  %-30s %10.2f%%", "Maximum Drawdown", dd.maxDrawdownPercent));
        m_logger.LogInfo(StringFormat("  %-30s %10d", "Trading Pauses", m_drawdownMonitor.GetPauseCount()));
    }

    m_logger.LogInfo("======================================================");

    m_positionSizer = NULL;
    m_exposureTracker = NULL;
    m_drawdownMonitor = NULL;
    m_isInitialized = false;
    m_logger.LogInfo("RiskManager shutdown complete");
}

RiskDecision CRiskManager::Evaluate(const ExecutionPlan &plan)
{
    RiskDecision decision;
    m_totalEvaluated++;

    if(!m_isInitialized)
    {
        decision.decision = RISK_REJECTED_MARGIN_INSUFFICIENT;
        decision.rejectionReason = "RiskManager not initialized";
        m_totalRejected++;
        m_logger.LogWarn(StringFormat("RISK-REJECTED [%s]", decision.rejectionReason));
        return decision;
    }

    if(m_positionSizer == NULL || m_exposureTracker == NULL || m_drawdownMonitor == NULL)
    {
        decision.decision = RISK_REJECTED_MARGIN_INSUFFICIENT;
        decision.rejectionReason = "RiskManager dependencies not set";
        m_totalRejected++;
        m_logger.LogWarn(StringFormat("RISK-REJECTED [%s]", decision.rejectionReason));
        return decision;
    }

    double stopDistancePoints = ComputeStopDistance(plan);
    if(stopDistancePoints <= 0.0)
    {
        decision.decision = RISK_REJECTED_MARGIN_INSUFFICIENT;
        decision.rejectionReason = "Cannot compute stop distance from plan";
        m_totalRejected++;
        m_logger.LogWarn(StringFormat("RISK-REJECTED [%s]", decision.rejectionReason));
        return decision;
    }

    // 1. Drawdown limits
    string ddReason;
    if(!m_drawdownMonitor.CheckLimits(m_config, ddReason))
    {
        decision.decision = RISK_REJECTED_EQUITY_STOP;
        decision.rejectionReason = ddReason;
        m_totalRejected++;
        m_logger.LogWarn(StringFormat("RISK-REJECTED [%s]", ddReason));
        return decision;
    }

    // 2. Max concurrent positions
    ExposureSnapshot exposure = m_exposureTracker.GetSnapshot();
    if(exposure.positionCount >= m_config.maxConcurrentPositions)
    {
        decision.decision = RISK_REJECTED_MAX_POSITIONS;
        decision.rejectionReason = StringFormat("Max concurrent positions reached: %d >= %d",
            exposure.positionCount, m_config.maxConcurrentPositions);
        m_totalRejected++;
        m_logger.LogWarn(StringFormat("RISK-REJECTED [%s]", decision.rejectionReason));
        return decision;
    }

    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);

    // 3. Position sizing
    PositionSizingResult sizing = m_positionSizer.CalculateCached(
        m_config.maxRiskPerTradePercent,
        stopDistancePoints,
        accountEquity
    );

    if(!sizing.valid)
    {
        decision.decision = RISK_REJECTED_MARGIN_INSUFFICIENT;
        decision.rejectionReason = sizing.validationMessage;
        m_totalRejected++;
        m_logger.LogWarn(StringFormat("RISK-REJECTED [%s]", decision.rejectionReason));
        return decision;
    }

    // 4. Max risk per trade
    double maxRiskCapital = accountEquity * (m_config.maxRiskPerTradePercent / 100.0);
    if(sizing.dollarRisk > maxRiskCapital)
    {
        decision.decision = RISK_REJECTED_MAX_RISK_PER_TRADE;
        decision.rejectionReason = StringFormat("Risk $%.2f exceeds max $%.2f per trade",
            sizing.dollarRisk, maxRiskCapital);
        m_totalRejected++;
        m_logger.LogWarn(StringFormat("RISK-REJECTED [%s]", decision.rejectionReason));
        return decision;
    }

    // 5. Min/max lot size
    if(sizing.lots > m_config.maxLotSize)
    {
        decision.decision = RISK_REJECTED_MAX_LOT_SIZE;
        decision.rejectionReason = StringFormat("Lot size %.2f exceeds max %.2f",
            sizing.lots, m_config.maxLotSize);
        m_totalRejected++;
        m_logger.LogWarn(StringFormat("RISK-REJECTED [%s]", decision.rejectionReason));
        return decision;
    }

    if(sizing.lots < m_config.minLotSize)
    {
        decision.decision = RISK_REJECTED_MIN_LOT_SIZE;
        decision.rejectionReason = StringFormat("Lot size %.2f below min %.2f",
            sizing.lots, m_config.minLotSize);
        m_totalRejected++;
        m_logger.LogWarn(StringFormat("RISK-REJECTED [%s]", decision.rejectionReason));
        return decision;
    }

    // 6. Portfolio exposure
    double addedExposure = sizing.lots * plan.entryPrice;
    double totalExposure = exposure.totalPortfolioExposure + addedExposure;
    double maxExposure = accountEquity * (m_config.maxPortfolioExposurePercent / 100.0);

    if(totalExposure > maxExposure)
    {
        decision.decision = RISK_REJECTED_MAX_EXPOSURE;
        decision.rejectionReason = StringFormat("Portfolio exposure $%.2f would exceed max $%.2f",
            totalExposure, maxExposure);
        m_totalRejected++;
        m_logger.LogWarn(StringFormat("RISK-REJECTED [%s]", decision.rejectionReason));
        return decision;
    }

    // 7. Leverage utilization
    double margin = 0.0;
    if(OrderCalcMargin(plan.orderType, m_positionSizer.GetSymbol(), sizing.lots, plan.entryPrice, margin))
    {
        double leverageUsed = ((exposure.marginUsed + margin) / MathMax(accountEquity, 1.0)) * 100.0;
        if(leverageUsed > m_config.maxLeverageUtilization)
        {
            decision.decision = RISK_REJECTED_LEVERAGE_EXCEEDED;
            decision.rejectionReason = StringFormat("Leverage %.1f%% would exceed max %.1f%%",
                leverageUsed, m_config.maxLeverageUtilization);
            m_totalRejected++;
            m_logger.LogWarn(StringFormat("RISK-REJECTED [%s]", decision.rejectionReason));
            return decision;
        }
    }

    // All checks passed
    decision.decision = RISK_APPROVED;
    decision.allowedRiskCapital = sizing.dollarRisk;
    decision.maxAllowedLotSize = sizing.lots;

    m_totalApproved++;
    m_sumRiskPercent += m_config.maxRiskPerTradePercent;
    m_sumLotSize += sizing.lots;

    m_logger.LogInfo(StringFormat("RISK-APPROVED lots=%.2f risk=$%.2f stop=%.0fpts",
        sizing.lots, sizing.dollarRisk, stopDistancePoints));

    return decision;
}

#endif
