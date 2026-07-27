//+------------------------------------------------------------------+
//|                                           HealthMonitor.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __MONITORING_HEALTH_MONITOR_MQH__
#define __MONITORING_HEALTH_MONITOR_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "MonitoringTypes.mqh"

class CHealthMonitor
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    ModuleHealthEntry m_entries[MAX_HEALTH_ENTRIES];
    int               m_entryCount;
    int               m_warningCount;
    int               m_criticalCount;
    ENUM_HEALTH_STATUS m_overallStatus;

    void RecomputeOverallStatus(void)
    {
        if(m_criticalCount > 0)
            m_overallStatus = HEALTH_CRITICAL;
        else if(m_warningCount > 0)
            m_overallStatus = HEALTH_WARNING;
        else
            m_overallStatus = HEALTH_HEALTHY;
    }

public:
    CHealthMonitor(void);
    ~CHealthMonitor(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    void SetModuleStatus(
        ENUM_MODULE_ID moduleId,
        string moduleName,
        bool isInitialized,
        int contextCount,
        ENUM_HEALTH_STATUS status,
        string lastError
    );

    HealthSnapshot GetSnapshot(void) const;
    ENUM_HEALTH_STATUS GetOverallStatus(void) const { return m_overallStatus; }
    int GetWarningCount(void) const { return m_warningCount; }
    int GetCriticalCount(void) const { return m_criticalCount; }
};

CHealthMonitor::CHealthMonitor(void)
    : m_logger(MODULE_HEALTH_MONITOR, "HealthMonitor")
    , m_isInitialized(false)
    , m_entryCount(0)
    , m_warningCount(0)
    , m_criticalCount(0)
    , m_overallStatus(HEALTH_HEALTHY)
{
}

CHealthMonitor::~CHealthMonitor(void)
{
    Shutdown();
}

bool CHealthMonitor::Init(void)
{
    m_logger.LogInfo("Initializing HealthMonitor...");
    m_entryCount = 0;
    m_warningCount = 0;
    m_criticalCount = 0;
    m_overallStatus = HEALTH_HEALTHY;
    m_isInitialized = true;
    m_logger.LogInfo("HealthMonitor initialized");
    return true;
}

void CHealthMonitor::Update(void)
{
}

void CHealthMonitor::Shutdown(void)
{
    m_logger.LogInfo("Shutting down HealthMonitor...");

    HealthSnapshot snap = GetSnapshot();

    m_logger.LogInfo("==================== SYSTEM HEALTH ====================");
    string statusStr = (snap.overallStatus == HEALTH_HEALTHY) ? "HEALTHY"
        : (snap.overallStatus == HEALTH_WARNING) ? "WARNING" : "CRITICAL";
    m_logger.LogInfo(StringFormat("  %-30s %s", "Overall Status", statusStr));

    for(int i = 0; i < snap.entryCount; i++)
    {
        string s = (snap.entries[i].status == HEALTH_HEALTHY) ? "OK"
            : (snap.entries[i].status == HEALTH_WARNING) ? "WARN" : "CRIT";
        m_logger.LogInfo(StringFormat("  %-30s %s", snap.entries[i].moduleName, s));
    }

    m_logger.LogInfo(StringFormat("  %-30s %d", "Warnings", snap.warningCount));
    m_logger.LogInfo(StringFormat("  %-30s %d", "Critical", snap.criticalCount));
    m_logger.LogInfo("========================================================");

    m_entryCount = 0;
    m_warningCount = 0;
    m_criticalCount = 0;
    m_isInitialized = false;
    m_logger.LogInfo("HealthMonitor shutdown complete");
}

void CHealthMonitor::SetModuleStatus(
    ENUM_MODULE_ID moduleId,
    string moduleName,
    bool isInitialized,
    int contextCount,
    ENUM_HEALTH_STATUS status,
    string lastError)
{
    if(!m_isInitialized)
        return;

    if(m_entryCount >= MAX_HEALTH_ENTRIES)
    {
        m_logger.LogWarn("Max health entries reached");
        return;
    }

    int idx = m_entryCount;
    m_entries[idx].moduleId = moduleId;
    m_entries[idx].moduleName = moduleName;
    m_entries[idx].isInitialized = isInitialized;
    m_entries[idx].contextCount = contextCount;
    m_entries[idx].status = status;
    m_entries[idx].lastError = lastError;

    if(status == HEALTH_CRITICAL)
        m_criticalCount++;
    else if(status == HEALTH_WARNING)
        m_warningCount++;

    m_entryCount++;
    RecomputeOverallStatus();
}

HealthSnapshot CHealthMonitor::GetSnapshot(void) const
{
    HealthSnapshot snap;
    snap.overallStatus = m_overallStatus;
    snap.entryCount = m_entryCount;
    snap.warningCount = m_warningCount;
    snap.criticalCount = m_criticalCount;

    for(int i = 0; i < m_entryCount && i < MAX_HEALTH_ENTRIES; i++)
        snap.entries[i] = m_entries[i];

    return snap;
}

#endif
