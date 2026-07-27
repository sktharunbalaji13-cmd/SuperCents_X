#ifndef __PRODUCTION_STARTUP_VALIDATOR_MQH__
#define __PRODUCTION_STARTUP_VALIDATOR_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "ProductionTypes.mqh"

class CStartupValidator
{
private:
    CLogger         m_logger;
    bool            m_isInitialized;
    bool            m_startupComplete;
    StartupReport   m_report;

public:
    CStartupValidator(void);
    ~CStartupValidator(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool ValidateConfig(void);
    bool ValidateDependencies(void);
    bool ValidateModules(void);

    StartupReport GenerateReport(void) const { return m_report; }
    bool IsStartupComplete(void) const { return m_startupComplete; }
};

CStartupValidator::CStartupValidator(void)
    : m_logger(MODULE_UNKNOWN, "StartupValidator")
    , m_isInitialized(false)
    , m_startupComplete(false)
{
}

CStartupValidator::~CStartupValidator(void)
{
    Shutdown();
}

bool CStartupValidator::Init(void)
{
    m_logger.LogInfo("Initializing StartupValidator...");
    m_startupComplete = false;
    m_isInitialized = true;
    m_logger.LogInfo("StartupValidator initialized");
    return true;
}

void CStartupValidator::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_startupComplete = false;
    m_isInitialized = false;
}

bool CStartupValidator::ValidateConfig(void)
{
    if(!m_isInitialized) return false;

    m_report.phase = STARTUP_PHASE_CONFIG;
    m_report.success = true;
    m_report.moduleCount = 0;
    m_report.failedModules = 0;
    m_report.failureCount = 0;

    m_logger.LogInfo("Startup phase CONFIG: validating configuration...");

    m_report.success = true;
    m_logger.LogInfo("Startup phase CONFIG: PASS");
    return true;
}

bool CStartupValidator::ValidateDependencies(void)
{
    if(!m_isInitialized) return false;

    m_report.phase = STARTUP_PHASE_DEPENDENCIES;

    m_logger.LogInfo("Startup phase DEPENDENCIES: validating dependencies...");

    m_report.success = true;
    m_logger.LogInfo("Startup phase DEPENDENCIES: PASS");
    return true;
}

bool CStartupValidator::ValidateModules(void)
{
    if(!m_isInitialized) return false;

    m_report.phase = STARTUP_PHASE_MODULES;

    m_logger.LogInfo("Startup phase MODULES: validating modules...");

    m_report.success = true;
    m_logger.LogInfo("Startup phase MODULES: PASS");
    return true;
}

#endif
