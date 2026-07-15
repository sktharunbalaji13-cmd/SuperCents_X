//+------------------------------------------------------------------+
//|                                               RiskManager.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __RISK_MANAGER_MQH__
#define __RISK_MANAGER_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"

class CRiskManager
{
private:
    CLogger m_logger;
    bool m_isInitialized;

public:
    CRiskManager(void);
    ~CRiskManager(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }
};

//--- Inline implementation
CRiskManager::CRiskManager(void)
    : m_logger(MODULE_RISK_MANAGER, "RiskManager"), m_isInitialized(false) {}

CRiskManager::~CRiskManager(void)
{
    Shutdown();
}

bool CRiskManager::Init(void)
{
    m_logger.LogInfo("Initializing RiskManager...");
    m_isInitialized = true;
    m_logger.LogInfo("RiskManager initialized");
    return true;
}

void CRiskManager::Update(void)
{
    // Sprint 1: Risk logic will be implemented in later sprints
}

void CRiskManager::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down RiskManager...");
    m_isInitialized = false;
    m_logger.LogInfo("RiskManager shutdown complete");
}

#endif // __RISK_MANAGER_MQH__