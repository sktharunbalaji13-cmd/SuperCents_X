#ifndef __PRODUCTION_OPERATIONAL_REPORT_MQH__
#define __PRODUCTION_OPERATIONAL_REPORT_MQH__

#include "../Core/Logger.mqh"
#include "OperationalEvidence.mqh"
#include "HealthAnalyzer.mqh"
#include "PerformanceAnalyzer.mqh"
#include "ConfigurationAuditor.mqh"
#include "DeploymentAnalyzer.mqh"

#define MAX_REPORT_LINES 4096

class COperationalReport
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    string m_lines[MAX_REPORT_LINES];
    int    m_lineCount;

    bool Write(const string line);

public:
    COperationalReport(void);
    ~COperationalReport(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool AddHealthSection(const HealthSnapshot &health);
    bool AddPerformanceSection(const PerformanceProfile &profile);
    bool AddConfigurationSection(const ConfigurationAudit &audit);
    bool AddDeploymentSection(const DeploymentEvidence &de);

    bool Save(const string filepath);
    bool GetContent(string &out) const;

    void Clear(void);
};

COperationalReport::COperationalReport(void)
    : m_logger(MODULE_UNKNOWN, "OperationalReport")
    , m_isInitialized(false)
    , m_lineCount(0)
{
}

COperationalReport::~COperationalReport(void)
{
    Shutdown();
}

bool COperationalReport::Init(void)
{
    m_logger.LogInfo("Initializing OperationalReport...");
    m_lineCount = 0;
    m_isInitialized = true;

    Write("========================================");
    Write("OPERATIONAL REPORT");
    Write("Capability Release 2.5 — Production Platform");
    Write("========================================");
    Write("");

    return true;
}

void COperationalReport::Shutdown(void)
{
    m_isInitialized = false;
}

bool COperationalReport::Write(const string line)
{
    if(m_lineCount >= MAX_REPORT_LINES) return false;
    m_lines[m_lineCount] = line;
    m_lineCount++;
    return true;
}

bool COperationalReport::AddHealthSection(const HealthSnapshot &health)
{
    Write("----------------------------------------");
    Write("HEALTH SNAPSHOT");
    Write("----------------------------------------");
    Write(StringFormat("  Overall Health      : %.2f / 100", health.overallHealthScore));
    Write(StringFormat("  Config Integrity    : %.2f", health.configIntegrity));
    Write(StringFormat("  Component Avail.    : %.2f", health.componentAvailability));
    Write(StringFormat("  Init Timing         : %.2f", health.initTiming));
    Write(StringFormat("  Resource Util.      : %.2f", health.resourceUtilization));
    Write(StringFormat("  Execution Latency   : %.2f", health.executionLatency));
    Write(StringFormat("  Artifact Integrity  : %.2f", health.artifactIntegrity));

    for(int i = 0; i < health.evidenceCount; i++)
        Write(StringFormat("  Evidence: %s = %.4f (%s)",
                           health.evidence[i].dimension,
                           health.evidence[i].value,
                           health.evidence[i].rationale));
    Write("");
    return true;
}

bool COperationalReport::AddPerformanceSection(const PerformanceProfile &profile)
{
    Write("----------------------------------------");
    Write("PERFORMANCE PROFILE");
    Write("----------------------------------------");
    Write(StringFormat("  Modules             : %d", profile.moduleCount));
    Write(StringFormat("  Total Exec Time     : %llu us", profile.totalExecutionTime));
    Write(StringFormat("  Avg Module Time     : %llu us", profile.avgModuleTime));
    Write(StringFormat("  Max Module Time     : %llu us", profile.maxModuleTime));
    Write(StringFormat("  Init Duration       : %llu us", profile.initDuration));
    Write(StringFormat("  Artifact Latency    : %llu us", profile.artifactLatency));
    Write(StringFormat("  Throughput          : %.2f/s", profile.throughputPerSecond));

    for(int i = 0; i < profile.evidenceCount; i++)
        Write(StringFormat("  Evidence: %s = %.4f (%s)",
                           profile.evidence[i].dimension,
                           profile.evidence[i].value,
                           profile.evidence[i].rationale));
    Write("");
    return true;
}

bool COperationalReport::AddConfigurationSection(const ConfigurationAudit &audit)
{
    Write("----------------------------------------");
    Write("CONFIGURATION AUDIT");
    Write("----------------------------------------");
    Write(StringFormat("  Schema Version      : %d (expected %d)",
                       audit.currentSchemaVersion, audit.expectedSchemaVersion));
    Write(StringFormat("  Migrations Applied  : %d", audit.migrationsApplied));
    Write(StringFormat("  Validations Passed  : %d", audit.validationPassed));
    Write(StringFormat("  Validations Failed  : %d", audit.validationFailed));
    Write(StringFormat("  Deprecated Settings : %d", audit.deprecatedSettings));
    Write(StringFormat("  Compat. Warnings    : %d", audit.compatibilityWarnings));

    for(int i = 0; i < audit.evidenceCount; i++)
        Write(StringFormat("  Evidence: %s = %.4f (%s)",
                           audit.evidence[i].dimension,
                           audit.evidence[i].value,
                           audit.evidence[i].rationale));
    Write("");
    return true;
}

bool COperationalReport::AddDeploymentSection(const DeploymentEvidence &de)
{
    Write("----------------------------------------");
    Write("DEPLOYMENT READINESS");
    Write("----------------------------------------");

    string tierStr = "";
    switch(de.readinessTier)
    {
        case READINESS_NOT_READY: tierStr = "NOT READY"; break;
        case READINESS_PARTIAL: tierStr = "PARTIAL"; break;
        case READINESS_READY: tierStr = "READY"; break;
        case READINESS_VERIFIED: tierStr = "VERIFIED"; break;
    }
    Write(StringFormat("  Readiness Tier      : %s", tierStr));
    Write(StringFormat("  Checks Passed       : %d / %d", de.checksPassed, de.totalChecks));
    Write(StringFormat("  Checks Failed       : %d", de.checksFailed));

    for(int i = 0; i < de.evidenceCount; i++)
        Write(StringFormat("  Check: %s = %.0f (%s)",
                           de.evidence[i].dimension,
                           de.evidence[i].value,
                           de.evidence[i].rationale));
    Write("");
    return true;
}

bool COperationalReport::Save(const string filepath)
{
    int handle = FileOpen(filepath, FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(handle == INVALID_HANDLE) return false;

    for(int i = 0; i < m_lineCount; i++)
        FileWrite(handle, m_lines[i]);

    FileClose(handle);
    Write(StringFormat("Report saved: %s (%d lines)", filepath, m_lineCount));
    return true;
}

bool COperationalReport::GetContent(string &out) const
{
    out = "";
    for(int i = 0; i < m_lineCount; i++)
        out += m_lines[i] + "\n";
    return true;
}

void COperationalReport::Clear(void)
{
    m_lineCount = 0;
}

#endif
