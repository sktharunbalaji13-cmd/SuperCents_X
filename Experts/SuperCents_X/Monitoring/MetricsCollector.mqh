//+------------------------------------------------------------------+
//|                                        MetricsCollector.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __MONITORING_METRICS_COLLECTOR_MQH__
#define __MONITORING_METRICS_COLLECTOR_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "MonitoringTypes.mqh"

class CMetricsCollector
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    ModuleMetrics m_metrics[MODULE_UNKNOWN + 1];
    int           m_moduleCount;

    ulong BeginModuleTiming(ENUM_MODULE_ID moduleId)
    {
        return GetMicrosecondCount();
    }

    void EndModuleTiming(ENUM_MODULE_ID moduleId, ulong startTime)
    {
        if(moduleId < 0 || moduleId > MODULE_UNKNOWN)
            return;

        ulong elapsed = GetMicrosecondCount() - startTime;
        int idx = (int)moduleId;

        m_metrics[idx].moduleId = moduleId;
        m_metrics[idx].executionCount++;
        m_metrics[idx].totalRuntime += elapsed;
        m_metrics[idx].lastRuntime = elapsed;

        if(elapsed > m_metrics[idx].maxRuntime)
            m_metrics[idx].maxRuntime = elapsed;

        m_metrics[idx].averageRuntime = (m_metrics[idx].executionCount > 0)
            ? (ulong)(m_metrics[idx].totalRuntime / m_metrics[idx].executionCount)
            : 0;
    }

public:
    CMetricsCollector(void);
    ~CMetricsCollector(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    ulong RecordBegin(ENUM_MODULE_ID moduleId);
    void RecordEnd(ENUM_MODULE_ID moduleId, ulong startTime);
    void RecordTiming(ENUM_MODULE_ID moduleId, ulong elapsed);

    bool GetMetrics(ENUM_MODULE_ID moduleId, ModuleMetrics &out) const;
    PerformanceSnapshot GetSnapshot(void) const;
    void LogSummary(void);
};

CMetricsCollector::CMetricsCollector(void)
    : m_logger(MODULE_METRICS_COLLECTOR, "MetricsCollector")
    , m_isInitialized(false)
    , m_moduleCount(0)
{
}

CMetricsCollector::~CMetricsCollector(void)
{
    Shutdown();
}

bool CMetricsCollector::Init(void)
{
    m_logger.LogInfo("Initializing MetricsCollector...");

    for(int i = 0; i <= MODULE_UNKNOWN; i++)
    {
        m_metrics[i] = ModuleMetrics();
    }

    m_moduleCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("MetricsCollector initialized");
    return true;
}

void CMetricsCollector::Update(void)
{
}

void CMetricsCollector::Shutdown(void)
{
    m_logger.LogInfo("Shutting down MetricsCollector...");
    LogSummary();
    m_isInitialized = false;
    m_logger.LogInfo("MetricsCollector shutdown complete");
}

ulong CMetricsCollector::RecordBegin(ENUM_MODULE_ID moduleId)
{
    return GetMicrosecondCount();
}

void CMetricsCollector::RecordEnd(ENUM_MODULE_ID moduleId, ulong startTime)
{
    EndModuleTiming(moduleId, startTime);
}

void CMetricsCollector::RecordTiming(ENUM_MODULE_ID moduleId, ulong elapsed)
{
    if(moduleId < 0 || moduleId > MODULE_UNKNOWN)
        return;

    int idx = (int)moduleId;
    m_metrics[idx].moduleId = moduleId;
    m_metrics[idx].executionCount++;
    m_metrics[idx].totalRuntime += elapsed;
    m_metrics[idx].lastRuntime = elapsed;

    if(elapsed > m_metrics[idx].maxRuntime)
        m_metrics[idx].maxRuntime = elapsed;

    m_metrics[idx].averageRuntime = (m_metrics[idx].executionCount > 0)
        ? (ulong)(m_metrics[idx].totalRuntime / m_metrics[idx].executionCount)
        : 0;
}

bool CMetricsCollector::GetMetrics(ENUM_MODULE_ID moduleId, ModuleMetrics &out) const
{
    if(moduleId < 0 || moduleId > MODULE_UNKNOWN)
        return false;

    out = m_metrics[(int)moduleId];
    return (out.executionCount > 0);
}

PerformanceSnapshot CMetricsCollector::GetSnapshot(void) const
{
    PerformanceSnapshot snap;

    for(int i = 0; i <= MODULE_UNKNOWN; i++)
    {
        if(m_metrics[i].executionCount > 0)
        {
            snap.metrics[snap.moduleCount] = m_metrics[i];
            snap.moduleCount++;
        }
    }

    return snap;
}

void CMetricsCollector::LogSummary(void)
{
    // Count modules with metrics
    int count = 0;
    for(int i = 0; i <= MODULE_UNKNOWN; i++)
    {
        if(m_metrics[i].executionCount > 0)
            count++;
    }

    if(count == 0)
    {
        m_logger.LogInfo("No module metrics recorded");
        return;
    }

    m_logger.LogInfo("==================== MODULE METRICS ====================");

    for(int i = 0; i <= MODULE_UNKNOWN; i++)
    {
        if(m_metrics[i].executionCount > 0)
        {
            m_logger.LogInfo(StringFormat(
                "  %-30s calls=%5lld total=%6llu us avg=%6llu max=%6llu last=%6llu",
                EnumToString((ENUM_MODULE_ID)i), // This is MQL built-in
                m_metrics[i].executionCount,
                m_metrics[i].totalRuntime,
                m_metrics[i].averageRuntime,
                m_metrics[i].maxRuntime,
                m_metrics[i].lastRuntime
            ));
        }
    }

    m_logger.LogInfo("========================================================");
}

#endif
