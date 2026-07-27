//+------------------------------------------------------------------+
//|                                      CorrelationManager.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __PORTFOLIO_CORRELATION_MANAGER_MQH__
#define __PORTFOLIO_CORRELATION_MANAGER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "PortfolioTypes.mqh"

#define MAX_CORRELATION_PAIRS 64

struct CorrelationEntry
{
    string  symbolA;
    string  symbolB;
    double  correlationValue;

    CorrelationEntry(void)
        : symbolA("")
        , symbolB("")
        , correlationValue(0.0)
    {
    }
};

class CCorrelationManager
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    CorrelationEntry m_entries[MAX_CORRELATION_PAIRS];
    int              m_entryCount;

public:
    CCorrelationManager(void);
    ~CCorrelationManager(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool SetCorrelation(const string symbolA, const string symbolB, double value);
    double GetCorrelation(const string symbolA, const string symbolB) const;
    bool IsHighlyCorrelated(const string symbolA, const string symbolB, double threshold = 0.7) const;
    int GetEntryCount(void) const { return m_entryCount; }
};

CCorrelationManager::CCorrelationManager(void)
    : m_logger(MODULE_CORRELATION_MANAGER, "CorrelationManager")
    , m_isInitialized(false)
    , m_entryCount(0)
{
}

CCorrelationManager::~CCorrelationManager(void)
{
    Shutdown();
}

bool CCorrelationManager::Init(void)
{
    m_logger.LogInfo("Initializing CorrelationManager...");
    m_entryCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("CorrelationManager initialized");
    return true;
}

void CCorrelationManager::Update(void)
{
}

void CCorrelationManager::Shutdown(void)
{
    if(!m_isInitialized)
        return;
    m_isInitialized = false;
}

bool CCorrelationManager::SetCorrelation(const string symbolA, const string symbolB, double value)
{
    if(!m_isInitialized)
        return false;

    value = MathMax(-1.0, MathMin(1.0, value));

    for(int i = 0; i < m_entryCount; i++)
    {
        if((m_entries[i].symbolA == symbolA && m_entries[i].symbolB == symbolB) ||
           (m_entries[i].symbolA == symbolB && m_entries[i].symbolB == symbolA))
        {
            m_entries[i].correlationValue = value;
            return true;
        }
    }

    if(m_entryCount >= MAX_CORRELATION_PAIRS)
    {
        m_logger.LogWarn("Max correlation entries reached");
        return false;
    }

    m_entries[m_entryCount].symbolA = symbolA;
    m_entries[m_entryCount].symbolB = symbolB;
    m_entries[m_entryCount].correlationValue = value;
    m_entryCount++;
    return true;
}

double CCorrelationManager::GetCorrelation(const string symbolA, const string symbolB) const
{
    if(symbolA == symbolB)
        return 1.0;

    for(int i = 0; i < m_entryCount; i++)
    {
        if((m_entries[i].symbolA == symbolA && m_entries[i].symbolB == symbolB) ||
           (m_entries[i].symbolA == symbolB && m_entries[i].symbolB == symbolA))
        {
            return m_entries[i].correlationValue;
        }
    }
    return 0.0;
}

bool CCorrelationManager::IsHighlyCorrelated(const string symbolA, const string symbolB, double threshold) const
{
    double corr = GetCorrelation(symbolA, symbolB);
    return MathAbs(corr) >= threshold;
}

#endif
