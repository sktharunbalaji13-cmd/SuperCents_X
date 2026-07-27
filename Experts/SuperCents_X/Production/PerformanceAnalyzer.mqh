#ifndef __PRODUCTION_PERFORMANCE_ANALYZER_MQH__
#define __PRODUCTION_PERFORMANCE_ANALYZER_MQH__

#include "../Core/Logger.mqh"
#include "../Monitoring/MonitoringTypes.mqh"
#include "OperationalEvidence.mqh"

class CPerformanceAnalyzer
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

public:
    CPerformanceAnalyzer(void);
    ~CPerformanceAnalyzer(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    PerformanceProfile Profile(const PerformanceSnapshot &snap,
                                ulong initDuration,
                                ulong artifactLatency) const;
};

CPerformanceAnalyzer::CPerformanceAnalyzer(void)
    : m_logger(MODULE_UNKNOWN, "PerformanceAnalyzer")
    , m_isInitialized(false)
{
}

CPerformanceAnalyzer::~CPerformanceAnalyzer(void)
{
    Shutdown();
}

bool CPerformanceAnalyzer::Init(void)
{
    m_logger.LogInfo("Initializing PerformanceAnalyzer...");
    m_isInitialized = true;
    return true;
}

void CPerformanceAnalyzer::Shutdown(void)
{
    m_isInitialized = false;
}

PerformanceProfile CPerformanceAnalyzer::Profile(const PerformanceSnapshot &snap,
                                                   ulong initDuration,
                                                   ulong artifactLatency) const
{
    PerformanceProfile profile;
    int e = 0;

    profile.moduleCount = snap.moduleCount;
    profile.initDuration = initDuration;
    profile.artifactLatency = artifactLatency;

    ulong sumTime = 0;
    ulong maxTime = 0;
    for(int i = 0; i < snap.moduleCount; i++)
    {
        sumTime += snap.metrics[i].totalRuntime;
        if(snap.metrics[i].maxRuntime > maxTime)
            maxTime = snap.metrics[i].maxRuntime;
    }

    profile.totalExecutionTime = sumTime;
    profile.maxModuleTime = maxTime;
    profile.avgModuleTime = (snap.moduleCount > 0) ? sumTime / snap.moduleCount : 0;

    if(sumTime > 0)
        profile.throughputPerSecond = 1000000.0 / sumTime;

    profile.evidence[e].source = "PerformanceAnalyzer";
    profile.evidence[e].dimension = "totalExecutionTime";
    profile.evidence[e].value = (double)profile.totalExecutionTime;
    profile.evidence[e].rationale = "Aggregate module execution time";
    e++;

    profile.evidence[e].source = "PerformanceAnalyzer";
    profile.evidence[e].dimension = "avgModuleTime";
    profile.evidence[e].value = (double)profile.avgModuleTime;
    profile.evidence[e].rationale = "Average time per module";
    e++;

    profile.evidence[e].source = "PerformanceAnalyzer";
    profile.evidence[e].dimension = "maxModuleTime";
    profile.evidence[e].value = (double)profile.maxModuleTime;
    profile.evidence[e].rationale = "Maximum module execution time";
    e++;

    profile.evidence[e].source = "PerformanceAnalyzer";
    profile.evidence[e].dimension = "initDuration";
    profile.evidence[e].value = (double)profile.initDuration;
    profile.evidence[e].rationale = "Time to first ready state";
    e++;

    profile.evidence[e].source = "PerformanceAnalyzer";
    profile.evidence[e].dimension = "artifactLatency";
    profile.evidence[e].value = (double)profile.artifactLatency;
    profile.evidence[e].rationale = "Artifact generation latency";
    e++;

    profile.evidence[e].source = "PerformanceAnalyzer";
    profile.evidence[e].dimension = "throughputPerSecond";
    profile.evidence[e].value = profile.throughputPerSecond;
    profile.evidence[e].rationale = "Analysis cycles per second";
    e++;

    profile.evidenceCount = e;

    return profile;
}

#endif
