#ifndef __PRODUCTION_FAULT_MANAGER_MQH__
#define __PRODUCTION_FAULT_MANAGER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "ProductionTypes.mqh"

#define MAX_FAULT_HISTORY 256

class CFaultManager
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    FaultEvent  m_history[MAX_FAULT_HISTORY];
    int         m_faultCount;

public:
    CFaultManager(void);
    ~CFaultManager(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool ReportFault(const string sourceModule,
                     const string description,
                     ENUM_FAULT_SEVERITY severity,
                     FaultEvent &outEvent);

    ENUM_RECOVERY_ACTION GetRecommendedAction(const FaultEvent &event) const;

    int GetFaultCount(void) const { return m_faultCount; }
    int GetFaultCountBySeverity(ENUM_FAULT_SEVERITY severity) const;
    bool GetFaultHistory(FaultEvent &outHistory[]) const;
};

CFaultManager::CFaultManager(void)
    : m_logger(MODULE_UNKNOWN, "FaultManager")
    , m_isInitialized(false)
    , m_faultCount(0)
{
}

CFaultManager::~CFaultManager(void)
{
    Shutdown();
}

bool CFaultManager::Init(void)
{
    m_logger.LogInfo("Initializing FaultManager...");
    m_faultCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("FaultManager initialized");
    return true;
}

void CFaultManager::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_faultCount = 0;
    m_isInitialized = false;
}

bool CFaultManager::ReportFault(const string sourceModule,
                                 const string description,
                                 ENUM_FAULT_SEVERITY severity,
                                 FaultEvent &outEvent)
{
    if(!m_isInitialized)
        return false;

    FaultEvent evt;
    evt.timestamp = TimeCurrent();
    evt.sourceModule = sourceModule;
    evt.description = description;
    evt.severity = severity;
    evt.recoveryAction = GetRecommendedAction(evt);
    evt.recovered = false;

    outEvent = evt;

    if(m_faultCount < MAX_FAULT_HISTORY)
    {
        m_history[m_faultCount] = evt;
        m_faultCount++;
    }

    string sevStr = (severity == FAULT_MINOR ? "MINOR" :
                     severity == FAULT_MAJOR ? "MAJOR" : "CRITICAL");
    m_logger.LogInfo(StringFormat("FAULT [%s] %s: %s", sevStr, sourceModule, description));

    return true;
}

ENUM_RECOVERY_ACTION CFaultManager::GetRecommendedAction(const FaultEvent &event) const
{
    switch(event.severity)
    {
        case FAULT_MINOR:
            return RECOVERY_NONE;
        case FAULT_MAJOR:
            return RECOVERY_RESTART_MODULE;
        case FAULT_CRITICAL:
            return RECOVERY_FULL_RESTART;
        default:
            return RECOVERY_NONE;
    }
}

int CFaultManager::GetFaultCountBySeverity(ENUM_FAULT_SEVERITY severity) const
{
    int count = 0;
    for(int i = 0; i < m_faultCount; i++)
    {
        if(m_history[i].severity == severity)
            count++;
    }
    return count;
}

bool CFaultManager::GetFaultHistory(FaultEvent &outHistory[]) const
{
    ArrayResize(outHistory, m_faultCount);
    for(int i = 0; i < m_faultCount; i++)
        outHistory[i] = m_history[i];
    return true;
}

#endif
