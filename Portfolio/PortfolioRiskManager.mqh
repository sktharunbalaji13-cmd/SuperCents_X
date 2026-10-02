//+------------------------------------------------------------------+
//|                                      PortfolioRiskManager.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __PORTFOLIO_PORTFOLIO_RISK_MANAGER_MQH__
#define __PORTFOLIO_PORTFOLIO_RISK_MANAGER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "PortfolioRiskTypes.mqh"
#include "PortfolioExposureTracker.mqh"
#include "AllocationEngine.mqh"
#include "CorrelationManager.mqh"

class CPortfolioRiskManager
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    CPortfolioExposureTracker *m_exposureTracker;
    CAllocationEngine         *m_allocationEngine;
    CCorrelationManager       *m_correlationManager;
    PortfolioLimits            m_limits;

    int m_totalEvaluated;
    int m_totalApproved;
    int m_totalRejected;

public:
    CPortfolioRiskManager(void);
    ~CPortfolioRiskManager(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    void SetExposureTracker(CPortfolioExposureTracker *tracker) { m_exposureTracker = tracker; }
    void SetAllocationEngine(CAllocationEngine *engine) { m_allocationEngine = engine; }
    void SetCorrelationManager(CCorrelationManager *cm) { m_correlationManager = cm; }
    void SetLimits(const PortfolioLimits &limits) { m_limits = limits; }
    PortfolioLimits GetLimits(void) const { return m_limits; }

    PortfolioRiskDecision Evaluate(const ExecutionPlan &plan, const string symbol);
    int GetEvaluatedCount(void) const { return m_totalEvaluated; }
    int GetApprovedCount(void) const { return m_totalApproved; }
    int GetRejectedCount(void) const { return m_totalRejected; }
};

CPortfolioRiskManager::CPortfolioRiskManager(void)
    : m_logger(MODULE_PORTFOLIO_RISK_MANAGER, "PortfolioRiskManager")
    , m_isInitialized(false)
    , m_exposureTracker(NULL)
    , m_allocationEngine(NULL)
    , m_correlationManager(NULL)
    , m_totalEvaluated(0)
    , m_totalApproved(0)
    , m_totalRejected(0)
{
}

CPortfolioRiskManager::~CPortfolioRiskManager(void)
{
    Shutdown();
}

bool CPortfolioRiskManager::Init(void)
{
    m_logger.LogInfo("Initializing PortfolioRiskManager...");

    if(m_exposureTracker == NULL || m_allocationEngine == NULL)
    {
        m_logger.LogError("PortfolioRiskManager requires ExposureTracker and AllocationEngine");
        return false;
    }

    m_totalEvaluated = 0;
    m_totalApproved = 0;
    m_totalRejected = 0;

    m_isInitialized = true;
    m_logger.LogInfo("PortfolioRiskManager initialized");
    return true;
}

void CPortfolioRiskManager::Update(void)
{
}

void CPortfolioRiskManager::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("==================== PORTFOLIO RISK SUMMARY ====================");
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Evaluated", m_totalEvaluated));
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Approved", m_totalApproved));
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Rejected", m_totalRejected));
    double apr = (m_totalEvaluated > 0) ? (100.0 * m_totalApproved / m_totalEvaluated) : 0.0;
    m_logger.LogInfo(StringFormat("  %-30s %5.1f%%", "Approval Rate", apr));
    m_logger.LogInfo("================================================================");

    m_exposureTracker = NULL;
    m_allocationEngine = NULL;
    m_correlationManager = NULL;
    m_isInitialized = false;
}

PortfolioRiskDecision CPortfolioRiskManager::Evaluate(const ExecutionPlan &plan, const string symbol)
{
    PortfolioRiskDecision decision;
    m_totalEvaluated++;

    if(!m_isInitialized)
    {
        decision.decision = ALLOC_REJECTED;
        decision.rejectionReason = "PortfolioRiskManager not initialized";
        m_totalRejected++;
        return decision;
    }

    if(m_exposureTracker == NULL || m_allocationEngine == NULL)
    {
        decision.decision = ALLOC_REJECTED;
        decision.rejectionReason = "Risk dependencies not set";
        m_totalRejected++;
        return decision;
    }

    PortfolioExposure exposure = m_exposureTracker.GetSnapshot();

    // 1. Max portfolio risk
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double maxRiskCapital = equity * (m_limits.maxPortfolioRiskPercent / 100.0);
    double currentPortfolioAtRisk = exposure.grossExposure * 0.02;
    double projectedRisk = currentPortfolioAtRisk + (plan.stopDistance > 0.0
        ? plan.stopDistance * _Point * equity * 0.001
        : 0.0);

    if(projectedRisk > maxRiskCapital)
    {
        decision.decision = ALLOC_REJECTED;
        decision.rejectionReason = StringFormat("Portfolio risk $%.2f exceeds max $%.2f",
            projectedRisk, maxRiskCapital);
        m_totalRejected++;
        m_logger.LogWarn(StringFormat("PORTFOLIO-RISK-REJECTED [%s]", decision.rejectionReason));
        return decision;
    }

    // 2. Max concurrent positions
    if(exposure.totalPositions >= m_limits.maxConcurrentPositions)
    {
        decision.decision = ALLOC_REJECTED;
        decision.rejectionReason = StringFormat("Max positions reached: %d >= %d",
            exposure.totalPositions, m_limits.maxConcurrentPositions);
        m_totalRejected++;
        m_logger.LogWarn(StringFormat("PORTFOLIO-RISK-REJECTED [%s]", decision.rejectionReason));
        return decision;
    }

    // 3. Correlation threshold
    if(m_correlationManager != NULL && symbol != "")
    {
        for(int i = 0; i < PositionsTotal(); i++)
        {
            if(PositionSelectByTicket(PositionGetTicket(i)))
            {
                string posSymbol = PositionGetString(POSITION_SYMBOL);
                if(posSymbol != symbol)
                {
                    double corr = m_correlationManager.GetCorrelation(symbol, posSymbol);
                    if(MathAbs(corr) >= m_limits.maxCorrelationThreshold)
                    {
                        decision.decision = ALLOC_REJECTED;
                        decision.rejectionReason = StringFormat(
                            "Correlation %.2f between %s and %s exceeds threshold %.2f",
                            corr, symbol, posSymbol, m_limits.maxCorrelationThreshold);
                        m_totalRejected++;
                        m_logger.LogWarn(StringFormat("PORTFOLIO-RISK-REJECTED [%s]", decision.rejectionReason));
                        return decision;
                    }
                }
            }
        }
    }

    // 4. Symbol concentration (P37 integrity, Fix 6: instrument-aware
    //    notional). vol*price is FX-shaped fiction on XAU/indices and the
    //    old addedExposure (stopDist*_Point*100000) hardcoded a 100k FX
    //    contract while ignoring lots. Notional = vol*price*contractSize.
    //    Unknown contract size falls back to legacy vol*price (never zero).
    //    BEHAVIOR NOTE: caps now bind at true notional; previously inert on
    //    FX. Cap percentages intentionally untouched (no new parameters).
    double symbolExposure = 0.0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetString(POSITION_SYMBOL) == symbol)
            {
                double vol = PositionGetDouble(POSITION_VOLUME);
                double price = PositionGetDouble(POSITION_PRICE_OPEN);
                double cs = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
                symbolExposure += (cs > 0.0) ? vol * price * cs : vol * price;
            }
        }
    }

    double addedExposure = 0.0;
    if(plan.entryPrice > 0.0 && plan.stopDistance > 0.0)
    {
        double csPlan = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
        //--- Risk-$ proxy per 1.0 lot (lots unknown pre-allocator).
        addedExposure = (csPlan > 0.0) ? plan.stopDistance * csPlan
                                       : plan.stopDistance * 100000.0;
    }
    double totalSymbolExposure = symbolExposure + addedExposure;
    double maxSymbolExposure = equity * (m_limits.maxSymbolConcentrationPercent / 100.0);
    //--- P41 (measurement-only, no behavior change): structured concentration
    //    gate observation for every candidate reaching §4. Logging only;
    //    decision logic below untouched. Cap value unchanged (30% default).
    bool concPass = (totalSymbolExposure <= maxSymbolExposure);
    m_logger.LogInfo(StringFormat(
        "CONC-MEASURE time=%s symbol=%s dir=%d concDecision=%s equity=%.2f openExp=%.2f addedExp=%.2f combined=%.2f concPct=%.4f capPct=%.2f positions=%d stopDist=%.5f",
        TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), symbol, (int)plan.direction,
        (concPass ? "PASS" : "REJECT"), equity, symbolExposure, addedExposure, totalSymbolExposure,
        ((equity > 0.0) ? (100.0 * totalSymbolExposure / equity) : 0.0),
        m_limits.maxSymbolConcentrationPercent, exposure.totalPositions, plan.stopDistance));
    if(totalSymbolExposure > maxSymbolExposure)
    {
        decision.decision = ALLOC_REJECTED;
        decision.rejectionReason = StringFormat(
            "Symbol concentration $%.2f exceeds max $%.2f",
            totalSymbolExposure, maxSymbolExposure);
        m_totalRejected++;
        m_logger.LogWarn(StringFormat("PORTFOLIO-RISK-REJECTED [%s]", decision.rejectionReason));
        return decision;
    }

    // 5. Capital utilization
    if(exposure.marginUtilizationPercent > m_limits.maxCapitalUtilizationPercent)
    {
        decision.decision = ALLOC_REJECTED;
        decision.rejectionReason = StringFormat(
            "Capital utilization %.1f%% exceeds max %.1f%%",
            exposure.marginUtilizationPercent, m_limits.maxCapitalUtilizationPercent);
        m_totalRejected++;
        m_logger.LogWarn(StringFormat("PORTFOLIO-RISK-REJECTED [%s]", decision.rejectionReason));
        return decision;
    }

    // 6. Daily loss limit
    if(exposure.dailyPL < 0 && MathAbs(exposure.dailyPL) > MathAbs(m_limits.maxDailyLossPercent * equity / 100.0))
    {
        decision.decision = ALLOC_REJECTED;
        decision.rejectionReason = StringFormat(
            "Daily loss $%.2f exceeds limit $%.2f",
            exposure.dailyPL, m_limits.maxDailyLossPercent * equity / 100.0);
        m_totalRejected++;
        m_logger.LogWarn(StringFormat("PORTFOLIO-RISK-REJECTED [%s]", decision.rejectionReason));
        return decision;
    }

    // All portfolio checks passed — delegate to allocation engine
    AllocationDecision allocDecision = m_allocationEngine.Evaluate(plan, exposure, m_limits, symbol, m_correlationManager);

    if(allocDecision.IsApproved())
    {
        decision.decision = allocDecision.decision;
        decision.allowedLots = allocDecision.allocatedLots;
        decision.allowedRiskCapital = allocDecision.allocatedRiskAmount;
        decision.rejectionReason = "";
        m_totalApproved++;
        m_logger.LogInfo(StringFormat("PORTFOLIO-RISK-APPROVED lots=%.2f cap=$%.2f",
            allocDecision.allocatedLots, allocDecision.allocatedRiskAmount));
    }
    else
    {
        decision.decision = ALLOC_REJECTED;
        decision.rejectionReason = allocDecision.reason;
        m_totalRejected++;
        m_logger.LogWarn(StringFormat("PORTFOLIO-RISK-REJECTED [%s]", allocDecision.reason));
    }

    return decision;
}

#endif
