#ifndef __PRODUCTION_DEPLOYMENT_VERIFIER_MQH__
#define __PRODUCTION_DEPLOYMENT_VERIFIER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "ProductionTypes.mqh"
#include "VersionManager.mqh"
#include "VersionManager.mqh"
#include "StartupValidator.mqh"
#include "EnvironmentValidator.mqh"

class CDeploymentVerifier
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    DeploymentReport m_report;

public:
    CDeploymentVerifier(void);
    ~CDeploymentVerifier(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool VerifyEnvironment(void);
    bool VerifyConfiguration(CVersionManager &versionManager);
    bool VerifyDependencies(CStartupValidator &startupValidator);
    bool VerifyStartup(void);

    DeploymentReport GenerateReport(void) const { return m_report; }
    ENUM_DEPLOYMENT_STATUS GetStatus(void) const { return m_report.status; }
};

CDeploymentVerifier::CDeploymentVerifier(void)
    : m_logger(MODULE_UNKNOWN, "DeploymentVerifier")
    , m_isInitialized(false)
{
}

CDeploymentVerifier::~CDeploymentVerifier(void)
{
    Shutdown();
}

bool CDeploymentVerifier::Init(void)
{
    m_logger.LogInfo("Initializing DeploymentVerifier...");
    m_report.status = DEPLOYMENT_BLOCKED;
    m_report.checksPassed = 0;
    m_report.checksFailed = 0;
    m_report.failureCount = 0;
    m_report.validatedAt = 0;
    m_isInitialized = true;
    m_logger.LogInfo("DeploymentVerifier initialized");
    return true;
}

void CDeploymentVerifier::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_isInitialized = false;
}

bool CDeploymentVerifier::VerifyEnvironment(void)
{
    m_logger.LogInfo("Deployment check: ENVIRONMENT");

    CEnvironmentValidator validator;
    if(!validator.Init())
    {
        m_report.checksFailed++;
        if(m_report.failureCount < 64)
            m_report.failures[m_report.failureCount++] = "EnvironmentValidator init failed";
        m_report.status = DEPLOYMENT_BLOCKED;
        return false;
    }

    bool ok = validator.ValidateAll();
    validator.Shutdown();

    if(ok)
        m_report.checksPassed++;
    else
    {
        m_report.checksFailed++;
        if(m_report.failureCount < 64)
            m_report.failures[m_report.failureCount++] = "Environment validation failed";
    }

    m_logger.LogInfo(StringFormat("  Environment: %s", ok ? "PASS" : "FAIL"));
    return ok;
}

bool CDeploymentVerifier::VerifyConfiguration(CVersionManager &versionManager)
{
    m_logger.LogInfo("Deployment check: CONFIGURATION");

    m_report.platformVersion = versionManager.GetPlatformVersion();

    bool ok = versionManager.CheckCompatibility();
    if(!ok)
    {
        m_report.checksFailed++;
        if(m_report.failureCount < 64)
            m_report.failures[m_report.failureCount++] = "Version compatibility check failed";
    }
    else
    {
        m_report.checksPassed++;
    }

    m_logger.LogInfo(StringFormat("  Configuration: %s", ok ? "PASS" : "FAIL"));
    return ok;
}

bool CDeploymentVerifier::VerifyDependencies(CStartupValidator &startupValidator)
{
    m_logger.LogInfo("Deployment check: DEPENDENCIES");

    bool ok = startupValidator.ValidateAll();
    StartupReport report = startupValidator.GetReport();

    if(!ok)
    {
        m_report.checksFailed++;
        if(m_report.failureCount < 64)
        {
            string msg = StringFormat("Startup validation failed: phase=%d, failed=%d",
                                      report.phase, report.failedModules);
            m_report.failures[m_report.failureCount++] = msg;
            for(int i = 0; i < report.failureCount && m_report.failureCount < 64; i++)
                m_report.failures[m_report.failureCount++] = report.failures[i];
        }
    }
    else
    {
        m_report.checksPassed++;
    }

    m_logger.LogInfo(StringFormat("  Dependencies: %s", ok ? "PASS" : "FAIL"));
    return ok;
}

bool CDeploymentVerifier::VerifyStartup(void)
{
    m_logger.LogInfo("Deployment check: STARTUP");

    bool ok = true;

    m_report.status = (m_report.checksFailed == 0) ? DEPLOYMENT_READY :
                      (m_report.checksFailed <= 2) ? DEPLOYMENT_WARNING :
                      DEPLOYMENT_BLOCKED;
    m_report.validatedAt = TimeCurrent();

    m_logger.LogInfo(StringFormat("  Startup: %s", ok ? "PASS" : "FAIL"));
    m_logger.LogInfo(StringFormat("Deployment status: %s",
                                  m_report.status == DEPLOYMENT_READY ? "READY" :
                                  m_report.status == DEPLOYMENT_WARNING ? "WARNING" :
                                  "BLOCKED"));
    return ok;
}

#endif
