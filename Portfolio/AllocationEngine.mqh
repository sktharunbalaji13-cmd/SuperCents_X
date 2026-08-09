//+------------------------------------------------------------------+
//|                                        AllocationEngine.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __PORTFOLIO_ALLOCATION_ENGINE_MQH__
#define __PORTFOLIO_ALLOCATION_ENGINE_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "PortfolioRiskTypes.mqh"
#include "CapitalAllocator.mqh"
#include "CorrelationManager.mqh"

class CAllocationEngine
{
private:
    CLogger           m_logger;
    bool              m_isInitialized;

    CCapitalAllocator m_capitalAllocator;
    double            m_defaultRiskPercent;

public:
    CAllocationEngine(void);
    ~CAllocationEngine(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    CCapitalAllocator *GetCapitalAllocator(void) { return &m_capitalAllocator; }
    void SetDefaultRiskPercent(double pct) { m_defaultRiskPercent = pct; }

    AllocationDecision Evaluate(const ExecutionPlan &plan,
                                 const PortfolioExposure &exposure,
                                 const PortfolioLimits &limits,
                                 const string symbol,
                                 const CCorrelationManager *correlation = NULL);
};

CAllocationEngine::CAllocationEngine(void)
    : m_logger(MODULE_ALLOCATION_ENGINE, "AllocationEngine")
    , m_isInitialized(false)
    , m_defaultRiskPercent(2.0)
{
}

CAllocationEngine::~CAllocationEngine(void)
{
    Shutdown();
}

bool CAllocationEngine::Init(void)
{
    m_logger.LogInfo("Initializing AllocationEngine...");

    if(!m_capitalAllocator.Init())
    {
        m_logger.LogError("Failed to initialize CapitalAllocator");
        return false;
    }

    m_isInitialized = true;
    m_logger.LogInfo("AllocationEngine initialized");
    return true;
}

void CAllocationEngine::Update(void)
{
}

void CAllocationEngine::Shutdown(void)
{
    if(!m_isInitialized)
        return;
    m_capitalAllocator.Shutdown();
    m_isInitialized = false;
}

AllocationDecision CAllocationEngine::Evaluate(const ExecutionPlan &plan,
                                                const PortfolioExposure &exposure,
                                                const PortfolioLimits &limits,
                                                const string symbol,
                                                const CCorrelationManager *correlation)
{
    AllocationDecision decision;

    if(!m_isInitialized)
    {
        decision.decision = ALLOC_REJECTED;
        decision.reason = "AllocationEngine not initialized";
        return decision;
    }

    AllocationRequest request;
    request.symbol = symbol;
    request.direction = plan.direction;
    request.entryPrice = plan.entryPrice;
    request.stopLoss = plan.stopLoss;
    request.riskAmount = 0.0;
    request.riskPercent = m_defaultRiskPercent;

    double stopDistPoints = MathAbs(plan.entryPrice - plan.stopLoss) / _Point;
    if(stopDistPoints <= 0.0)
    {
        decision.decision = ALLOC_REJECTED;
        decision.reason = "Invalid stop distance in plan";
        return decision;
    }

    double tickValue = 0.0;
    if(request.symbol != "")
        tickValue = SymbolInfoDouble(request.symbol, SYMBOL_TRADE_TICK_VALUE);

    double riskPerLot = stopDistPoints * tickValue;
    if(riskPerLot > 0.0)
    {
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        request.riskAmount = equity * (m_defaultRiskPercent / 100.0);
        request.requestedLots = request.riskAmount / riskPerLot;
    }

    double allocatedLots = m_capitalAllocator.CalculateSize(request, exposure);

    if(allocatedLots <= 0.0)
    {
        decision.decision = ALLOC_REJECTED;
        decision.reason = "Allocator returned zero or invalid size";
        return decision;
    }

    decision.decision = ALLOC_APPROVED;
    decision.allocatedLots = allocatedLots;
    decision.allocatedRiskAmount = allocatedLots * riskPerLot;
    decision.reason = StringFormat("Allocated %.2f lots via %s",
        allocatedLots, m_capitalAllocator.PolicyName());

    return decision;
}

#endif
