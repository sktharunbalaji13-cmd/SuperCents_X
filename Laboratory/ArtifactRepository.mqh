#ifndef __LABORATORY_ARTIFACT_REPOSITORY_MQH__
#define __LABORATORY_ARTIFACT_REPOSITORY_MQH__

#include "../Core/Logger.mqh"
#include "../Optimization/OptimizationTypes.mqh"
#include "../Production/ProductionTypes.mqh"
#include "LaboratoryTypes.mqh"

#define MAX_ARTIFACT_CACHE 256

class CArtifactRepository
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    ExperimentReference m_experiments[MAX_ARTIFACT_CACHE];
    int                 m_experimentCount;

    StrategyReport      m_reports[MAX_ARTIFACT_CACHE];
    int                 m_reportCount;

public:
    CArtifactRepository(void);
    ~CArtifactRepository(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool DiscoverExperiments(const string searchPath);
    bool LoadReport(const ExperimentReference &ref, StrategyReport &out) const;
    bool CacheReport(const ExperimentReference &ref, const StrategyReport &report);
    bool CacheExperiment(const ExperimentReference &ref);

    bool GetExperiment(int index, ExperimentReference &out) const;
    bool GetReport(int index, StrategyReport &out) const;

    int  GetExperimentCount(void) const { return m_experimentCount; }
    int  GetReportCount(void) const { return m_reportCount; }
    void Clear(void);
};

CArtifactRepository::CArtifactRepository(void)
    : m_logger(MODULE_LABORATORY, "ArtifactRepository")
    , m_isInitialized(false)
    , m_experimentCount(0)
    , m_reportCount(0)
{
}

CArtifactRepository::~CArtifactRepository(void)
{
    Shutdown();
}

bool CArtifactRepository::Init(void)
{
    m_logger.LogInfo("Initializing ArtifactRepository...");
    m_experimentCount = 0;
    m_reportCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("ArtifactRepository initialized");
    return true;
}

void CArtifactRepository::Shutdown(void)
{
    if(!m_isInitialized) return;
    Clear();
    m_isInitialized = false;
}

bool CArtifactRepository::DiscoverExperiments(const string searchPath)
{
    m_logger.LogInfo(StringFormat("Discovering experiments in %s (PLACEHOLDER)", searchPath));
    return true;
}

bool CArtifactRepository::LoadReport(const ExperimentReference &ref, StrategyReport &out) const
{
    out.experimentId = ref.experimentId;
    return true;
}

bool CArtifactRepository::CacheReport(const ExperimentReference &ref, const StrategyReport &report)
{
    if(!m_isInitialized || m_reportCount >= MAX_ARTIFACT_CACHE)
        return false;
    m_reports[m_reportCount] = report;
    m_reportCount++;
    return true;
}

bool CArtifactRepository::CacheExperiment(const ExperimentReference &ref)
{
    if(!m_isInitialized || m_experimentCount >= MAX_ARTIFACT_CACHE)
        return false;
    m_experiments[m_experimentCount] = ref;
    m_experimentCount++;
    return true;
}

bool CArtifactRepository::GetExperiment(int index, ExperimentReference &out) const
{
    if(index < 0 || index >= m_experimentCount) return false;
    out = m_experiments[index];
    return true;
}

bool CArtifactRepository::GetReport(int index, StrategyReport &out) const
{
    if(index < 0 || index >= m_reportCount) return false;
    out = m_reports[index];
    return true;
}

void CArtifactRepository::Clear(void)
{
    m_experimentCount = 0;
    m_reportCount = 0;
}

#endif
