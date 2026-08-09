#ifndef __PRODUCTION_PERFORMANCE_PROFILER_MQH__
#define __PRODUCTION_PERFORMANCE_PROFILER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "../Monitoring/MonitoringTypes.mqh"
#include "ProductionTypes.mqh"

#define MAX_PROFILE_LABELS 64

struct ProfileEntry
{
    string  label;
    ulong   totalUs;
    ulong   maxUs;
    int     count;

    ProfileEntry(void)
        : label(""), totalUs(0), maxUs(0), count(0)
    {}
};

class CPerformanceProfiler
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    ProfileEntry m_entries[MAX_PROFILE_LABELS];
    int          m_entryCount;

    int FindLabel(const string label) const;

public:
    CPerformanceProfiler(void);
    ~CPerformanceProfiler(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool RecordTiming(const string label, ulong elapsedUs);
    bool GetAverageTiming(const string label, double &outAvgUs) const;
    bool GetMaxTiming(const string label, ulong &outMaxUs) const;

    bool Snapshot(PerformanceSnapshot &out) const;
    bool ExportProfile(const string filepath) const;
};

CPerformanceProfiler::CPerformanceProfiler(void)
    : m_logger(MODULE_UNKNOWN, "PerformanceProfiler")
    , m_isInitialized(false)
    , m_entryCount(0)
{
}

CPerformanceProfiler::~CPerformanceProfiler(void)
{
    Shutdown();
}

bool CPerformanceProfiler::Init(void)
{
    m_logger.LogInfo("Initializing PerformanceProfiler...");
    m_entryCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("PerformanceProfiler initialized");
    return true;
}

void CPerformanceProfiler::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_entryCount = 0;
    m_isInitialized = false;
}

int CPerformanceProfiler::FindLabel(const string label) const
{
    for(int i = 0; i < m_entryCount; i++)
        if(m_entries[i].label == label) return i;
    return -1;
}

bool CPerformanceProfiler::RecordTiming(const string label, ulong elapsedUs)
{
    if(!m_isInitialized)
        return false;

    int idx = FindLabel(label);
    if(idx < 0)
    {
        if(m_entryCount >= MAX_PROFILE_LABELS)
            return false;
        idx = m_entryCount;
        m_entries[idx].label = label;
        m_entries[idx].totalUs = 0;
        m_entries[idx].maxUs = 0;
        m_entries[idx].count = 0;
        m_entryCount++;
    }

    m_entries[idx].totalUs += elapsedUs;
    m_entries[idx].count++;
    if(elapsedUs > m_entries[idx].maxUs)
        m_entries[idx].maxUs = elapsedUs;

    return true;
}

bool CPerformanceProfiler::GetAverageTiming(const string label, double &outAvgUs) const
{
    int idx = FindLabel(label);
    if(idx < 0) return false;
    outAvgUs = (m_entries[idx].count > 0)
        ? (double)m_entries[idx].totalUs / m_entries[idx].count
        : 0.0;
    return true;
}

bool CPerformanceProfiler::GetMaxTiming(const string label, ulong &outMaxUs) const
{
    int idx = FindLabel(label);
    if(idx < 0) return false;
    outMaxUs = m_entries[idx].maxUs;
    return true;
}

bool CPerformanceProfiler::Snapshot(PerformanceSnapshot &out) const
{
    out.moduleCount = 0;
    for(int i = 0; i < m_entryCount && out.moduleCount < (MODULE_UNKNOWN + 1); i++)
    {
        out.metrics[out.moduleCount].moduleId = MODULE_UNKNOWN;
        out.metrics[out.moduleCount].executionCount = m_entries[i].count;
        out.metrics[out.moduleCount].totalRuntime = m_entries[i].totalUs;
        out.metrics[out.moduleCount].averageRuntime = (m_entries[i].count > 0)
            ? (ulong)((double)m_entries[i].totalUs / m_entries[i].count)
            : 0;
        out.metrics[out.moduleCount].maxRuntime = m_entries[i].maxUs;
        out.moduleCount++;
    }
    return true;
}

bool CPerformanceProfiler::ExportProfile(const string filepath) const
{
    int handle = FileOpen(filepath, FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(handle == INVALID_HANDLE)
        return false;

    FileWrite(handle, "# Performance Profile");
    FileWrite(handle, StringFormat("# Labels: %d", m_entryCount));
    FileWrite(handle, "Label,Count,TotalUs,AvgUs,MaxUs");

    for(int i = 0; i < m_entryCount; i++)
    {
        FileWrite(handle, StringFormat("%s,%d,%llu,%.0f,%llu",
                                       m_entries[i].label,
                                       m_entries[i].count,
                                       m_entries[i].totalUs,
                                       (m_entries[i].count > 0)
                                           ? (double)m_entries[i].totalUs / m_entries[i].count
                                           : 0.0,
                                       m_entries[i].maxUs));
    }

    FileClose(handle);
    return true;
}

#endif
