#ifndef __LABORATORY_STRATEGY_CATALOG_MQH__
#define __LABORATORY_STRATEGY_CATALOG_MQH__

#include "../Core/Logger.mqh"
#include "LaboratoryTypes.mqh"

#define MAX_CATALOG_STRATEGIES 128

class CStrategyCatalog
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    StrategyDescriptor m_strategies[MAX_CATALOG_STRATEGIES];
    int                m_strategyCount;

    int FindById(const string strategyId) const;
    int FindByName(const string strategyName) const;

public:
    CStrategyCatalog(void);
    ~CStrategyCatalog(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool Register(const StrategyDescriptor &descriptor);
    bool Unregister(const string strategyId);
    bool LookupById(const string strategyId, StrategyDescriptor &out) const;
    bool LookupByName(const string strategyName, StrategyDescriptor &out) const;
    bool Enumerate(StrategyDescriptor &out[], int &count) const;

    int GetCount(void) const { return m_strategyCount; }
    void Clear(void);
};

CStrategyCatalog::CStrategyCatalog(void)
    : m_logger(MODULE_LABORATORY, "StrategyCatalog")
    , m_isInitialized(false)
    , m_strategyCount(0)
{
}

CStrategyCatalog::~CStrategyCatalog(void)
{
    Shutdown();
}

bool CStrategyCatalog::Init(void)
{
    m_logger.LogInfo("Initializing StrategyCatalog...");
    m_strategyCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("StrategyCatalog initialized");
    return true;
}

void CStrategyCatalog::Shutdown(void)
{
    if(!m_isInitialized) return;
    Clear();
    m_isInitialized = false;
}

int CStrategyCatalog::FindById(const string strategyId) const
{
    for(int i = 0; i < m_strategyCount; i++)
        if(m_strategies[i].strategyId == strategyId) return i;
    return -1;
}

int CStrategyCatalog::FindByName(const string strategyName) const
{
    for(int i = 0; i < m_strategyCount; i++)
        if(m_strategies[i].strategyName == strategyName) return i;
    return -1;
}

bool CStrategyCatalog::Register(const StrategyDescriptor &descriptor)
{
    if(!m_isInitialized || m_strategyCount >= MAX_CATALOG_STRATEGIES)
        return false;
    if(FindById(descriptor.strategyId) >= 0)
        return false;

    m_strategies[m_strategyCount] = descriptor;
    m_strategyCount++;
    return true;
}

bool CStrategyCatalog::Unregister(const string strategyId)
{
    int idx = FindById(strategyId);
    if(idx < 0) return false;

    for(int i = idx; i < m_strategyCount - 1; i++)
        m_strategies[i] = m_strategies[i + 1];
    m_strategyCount--;
    return true;
}

bool CStrategyCatalog::LookupById(const string strategyId, StrategyDescriptor &out) const
{
    int idx = FindById(strategyId);
    if(idx < 0) return false;
    out = m_strategies[idx];
    return true;
}

bool CStrategyCatalog::LookupByName(const string strategyName, StrategyDescriptor &out) const
{
    int idx = FindByName(strategyName);
    if(idx < 0) return false;
    out = m_strategies[idx];
    return true;
}

bool CStrategyCatalog::Enumerate(StrategyDescriptor &out[], int &count) const
{
    if(!m_isInitialized) { count = 0; return false; }
    count = m_strategyCount;
    for(int i = 0; i < m_strategyCount; i++)
        out[i] = m_strategies[i];
    return true;
}

void CStrategyCatalog::Clear(void)
{
    m_strategyCount = 0;
}

#endif
