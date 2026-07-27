#ifndef __PRODUCTION_HEALTH_SUPERVISOR_MQH__
#define __PRODUCTION_HEALTH_SUPERVISOR_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "ProductionTypes.mqh"

#define MAX_HEALTH_MODULES 64

class CHealthSupervisor
{
private:
    CLogger         m_logger;
    bool            m_isInitialized;
    ulong           m_startTime;

    HealthStatus    m_statuses[MAX_HEALTH_MODULES];
    int             m_moduleCount;

    int FindModule(const string moduleName) const;

public:
    CHealthSupervisor(void);
    ~CHealthSupervisor(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool RegisterModule(const string moduleName);
    bool UpdateStatus(const string moduleName, bool isOperational);
    bool ReportFault(const string moduleName, ENUM_FAULT_SEVERITY severity);

    HealthStatus GetModuleStatus(const string moduleName) const;
    bool GetAllStatuses(HealthStatus &outStatuses[]) const;

    int  GetOperationalCount(void) const;
    int  GetDegradedCount(void) const;
    int  GetFailedCount(void) const;
};

CHealthSupervisor::CHealthSupervisor(void)
    : m_logger(MODULE_UNKNOWN, "HealthSupervisor")
    , m_isInitialized(false)
    , m_startTime(0)
    , m_moduleCount(0)
{
}

CHealthSupervisor::~CHealthSupervisor(void)
{
    Shutdown();
}

bool CHealthSupervisor::Init(void)
{
    m_logger.LogInfo("Initializing HealthSupervisor...");
    m_moduleCount = 0;
    m_startTime = GetTickCount();
    m_isInitialized = true;
    m_logger.LogInfo("HealthSupervisor initialized");
    return true;
}

void CHealthSupervisor::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_moduleCount = 0;
    m_isInitialized = false;
}

int CHealthSupervisor::FindModule(const string moduleName) const
{
    for(int i = 0; i < m_moduleCount; i++)
    {
        if(m_statuses[i].moduleName == moduleName)
            return i;
    }
    return -1;
}

bool CHealthSupervisor::RegisterModule(const string moduleName)
{
    if(!m_isInitialized || m_moduleCount >= MAX_HEALTH_MODULES)
        return false;

    if(FindModule(moduleName) >= 0)
        return true;

    m_statuses[m_moduleCount].moduleName = moduleName;
    m_statuses[m_moduleCount].isOperational = true;
    m_statuses[m_moduleCount].uptimeUs = 0;
    m_statuses[m_moduleCount].warningCount = 0;
    m_statuses[m_moduleCount].faultCount = 0;
    m_statuses[m_moduleCount].worstFault = FAULT_MINOR;
    m_moduleCount++;

    m_logger.LogInfo(StringFormat("Health: module '%s' registered", moduleName));
    return true;
}

bool CHealthSupervisor::UpdateStatus(const string moduleName, bool isOperational)
{
    int idx = FindModule(moduleName);
    if(idx < 0)
        return RegisterModule(moduleName);

    m_statuses[idx].isOperational = isOperational;
    if(isOperational)
        m_statuses[idx].uptimeUs = GetTickCount() - m_startTime;

    return true;
}

bool CHealthSupervisor::ReportFault(const string moduleName, ENUM_FAULT_SEVERITY severity)
{
    int idx = FindModule(moduleName);
    if(idx < 0)
        return false;

    m_statuses[idx].faultCount++;
    if((int)severity > (int)m_statuses[idx].worstFault)
        m_statuses[idx].worstFault = severity;

    if(severity >= FAULT_MAJOR)
        m_statuses[idx].isOperational = false;

    return true;
}

HealthStatus CHealthSupervisor::GetModuleStatus(const string moduleName) const
{
    HealthStatus empty;
    int idx = FindModule(moduleName);
    if(idx < 0) return empty;
    return m_statuses[idx];
}

bool CHealthSupervisor::GetAllStatuses(HealthStatus &outStatuses[]) const
{
    ArrayResize(outStatuses, m_moduleCount);
    for(int i = 0; i < m_moduleCount; i++)
        outStatuses[i] = m_statuses[i];
    return true;
}

int CHealthSupervisor::GetOperationalCount(void) const
{
    int count = 0;
    for(int i = 0; i < m_moduleCount; i++)
        if(m_statuses[i].isOperational) count++;
    return count;
}

int CHealthSupervisor::GetDegradedCount(void) const
{
    int count = 0;
    for(int i = 0; i < m_moduleCount; i++)
        if(m_statuses[i].worstFault == FAULT_MAJOR) count++;
    return count;
}

int CHealthSupervisor::GetFailedCount(void) const
{
    int count = 0;
    for(int i = 0; i < m_moduleCount; i++)
        if(!m_statuses[i].isOperational) count++;
    return count;
}

#endif
