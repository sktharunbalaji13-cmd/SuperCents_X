#ifndef __VALIDATION_LAB_MQH__
#define __VALIDATION_LAB_MQH__

#include "../Core/Logger.mqh"
#include "IValidationDataSource.mqh"
#include "TesterDataSource.mqh"
#include "ValidationEventBus.mqh"
#include "BehavioralMetricsCollector.mqh"

class CValidationLab
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;
    bool        m_isRunning;

    CValidationEventBus         *m_eventBus;
    CTesterDataSource           *m_dataSource;
    CBehavioralMetricsCollector *m_behavioralCollector;

    string m_outputDir;

public:
    CValidationLab(void);
    ~CValidationLab(void);

    bool Init(const string outputDir = "ValidationLab/Reports");
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }
    bool IsRunning(void) const { return m_isRunning; }

    bool StartRun(const ValidationRequest &req);
    bool EndRun(ValidationResult &outResult);

    CValidationEventBus         *GetEventBus(void) const { return m_eventBus; }
    CTesterDataSource           *GetDataSource(void) const { return m_dataSource; }
    CBehavioralMetricsCollector *GetBehavioralCollector(void) const { return m_behavioralCollector; }

private:
    void Cleanup(void);
};

CValidationLab::CValidationLab(void)
    : m_logger(MODULE_UNKNOWN, "ValidationLab")
    , m_isInitialized(false)
    , m_isRunning(false)
    , m_eventBus(NULL)
    , m_dataSource(NULL)
    , m_behavioralCollector(NULL)
    , m_outputDir("")
{
}

CValidationLab::~CValidationLab(void)
{
    Shutdown();
}

bool CValidationLab::Init(const string outputDir)
{
    m_logger.LogInfo("Initializing ValidationLab...");

    m_outputDir = outputDir;

    m_eventBus = new CValidationEventBus();
    if(m_eventBus == NULL || !m_eventBus.Init())
    {
        m_logger.LogError("Failed to initialize ValidationEventBus");
        Cleanup();
        return false;
    }

    m_dataSource = new CTesterDataSource();
    if(m_dataSource == NULL || !m_dataSource.Init())
    {
        m_logger.LogError("Failed to initialize TesterDataSource");
        Cleanup();
        return false;
    }

    m_dataSource.SetEventBus(m_eventBus);

    m_behavioralCollector = new CBehavioralMetricsCollector();
    if(m_behavioralCollector == NULL)
    {
        m_logger.LogError("Failed to create BehavioralMetricsCollector");
        Cleanup();
        return false;
    }

    m_behavioralCollector.Init(m_eventBus);
    m_dataSource.SetBehavioralCollector(m_behavioralCollector);

    m_isInitialized = true;
    m_logger.LogInfo("ValidationLab initialized");
    return true;
}

void CValidationLab::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    if(m_isRunning)
    {
        m_logger.LogWarn("Shutdown called while run in progress");
    }

    Cleanup();
    m_isInitialized = false;
    m_logger.LogInfo("ValidationLab shutdown complete");
}

void CValidationLab::Cleanup(void)
{
    if(m_behavioralCollector != NULL)
    {
        m_behavioralCollector.Shutdown();
        delete m_behavioralCollector;
        m_behavioralCollector = NULL;
    }

    if(m_dataSource != NULL)
    {
        m_dataSource.Shutdown();
        delete m_dataSource;
        m_dataSource = NULL;
    }

    if(m_eventBus != NULL)
    {
        m_eventBus.Shutdown();
        delete m_eventBus;
        m_eventBus = NULL;
    }
}

bool CValidationLab::StartRun(const ValidationRequest &req)
{
    if(!m_isInitialized)
    {
        m_logger.LogError("ValidationLab not initialized");
        return false;
    }

    if(m_isRunning)
    {
        m_logger.LogWarn("Run already in progress, resetting");
        m_behavioralCollector.Reset();
    }

    if(!m_dataSource.Prepare(req))
    {
        m_logger.LogError("Failed to prepare data source");
        return false;
    }

    m_isRunning = true;

    m_logger.LogInfo(StringFormat("Validation run started: %s",
        req.experimentLabel != "" ? req.experimentLabel : "untitled"));

    return true;
}

bool CValidationLab::EndRun(ValidationResult &outResult)
{
    if(!m_isInitialized)
    {
        m_logger.LogError("ValidationLab not initialized");
        return false;
    }

    if(!m_isRunning)
    {
        m_logger.LogError("No run in progress");
        return false;
    }

    if(!m_dataSource.Finalize(outResult))
    {
        m_logger.LogError("Failed to finalize data source");
        m_isRunning = false;
        return false;
    }

    m_behavioralCollector.Reset();
    m_isRunning = false;

    m_logger.LogInfo("Validation run ended");
    return true;
}

#endif
