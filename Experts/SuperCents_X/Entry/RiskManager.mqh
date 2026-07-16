//+------------------------------------------------------------------+
//|                                               RiskManager.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __RISK_MANAGER_MQH__
#define __RISK_MANAGER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Structure/TrendState.mqh"
#include "EntrySetup.mqh"

#define RISK_DEFAULT_PERCENT   1.0
#define RISK_DEFAULT_LOT_SIZE  0.01

struct PositionSizing
{
    double lots;
    double riskMoney;
    double stopDistance;
};

class CRiskManager
{
private:
    CLogger m_logger;
    bool    m_isInitialized;
    double  m_riskPercent;

public:
    CRiskManager(void);
    ~CRiskManager(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    PositionSizing Calculate(const EntrySetup &setup);

    void SetRiskPercent(double percent) { m_riskPercent = percent; }
    double GetRiskPercent(void) const { return m_riskPercent; }
};

CRiskManager::CRiskManager(void)
    : m_logger(MODULE_RISK_MANAGER, "RiskManager")
    , m_isInitialized(false)
    , m_riskPercent(RISK_DEFAULT_PERCENT) {}

CRiskManager::~CRiskManager(void)
{
    Shutdown();
}

bool CRiskManager::Init(void)
{
    m_logger.LogInfo("Initializing RiskManager...");
    m_isInitialized = true;
    m_riskPercent = RISK_DEFAULT_PERCENT;
    m_logger.LogInfo("RiskManager initialized");
    return true;
}

void CRiskManager::Update(void)
{
}

void CRiskManager::Shutdown(void)
{
    m_logger.LogInfo("Shutting down RiskManager...");
    m_isInitialized = false;
    m_logger.LogInfo("RiskManager shutdown complete");
}

PositionSizing CRiskManager::Calculate(const EntrySetup &setup)
{
    PositionSizing result;
    result.lots = RISK_DEFAULT_LOT_SIZE;
    result.riskMoney = 0.0;
    result.stopDistance = 0.0;

    if(!m_isInitialized || !setup.valid)
    {
        m_logger.LogWarn("Calculate: invalid state or setup, returning minimum lot");
        return result;
    }

    if(setup.entryPrice <= 0.0 || setup.stopLoss <= 0.0 || setup.entryPrice == setup.stopLoss)
    {
        m_logger.LogWarn("Calculate: invalid prices, returning minimum lot");
        return result;
    }

    result.stopDistance = MathAbs(setup.entryPrice - setup.stopLoss) / _Point;

    m_logger.LogDebug(StringFormat("Calculate: entry=%.5f SL=%.5f dist=%.0f pts lots=%s risk=%.1f%%",
        setup.entryPrice, setup.stopLoss, result.stopDistance,
        DoubleToString(result.lots, 2), m_riskPercent));

    return result;
}

#endif
