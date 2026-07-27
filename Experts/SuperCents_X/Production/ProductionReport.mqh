#ifndef __PRODUCTION_PRODUCTION_REPORT_MQH__
#define __PRODUCTION_PRODUCTION_REPORT_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "ProductionTypes.mqh"

class CProductionReport
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

public:
    CProductionReport(void);
    ~CProductionReport(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    static string FormatStartupReport(const StartupReport &report);
    static string FormatHealthSummary(const HealthStatus &statuses[], int count);
    static string FormatDeploymentReport(const DeploymentReport &report);
    static string FormatFaultSummary(const FaultEvent &events[], int count);
};

CProductionReport::CProductionReport(void)
    : m_logger(MODULE_UNKNOWN, "ProductionReport")
    , m_isInitialized(false)
{
}

CProductionReport::~CProductionReport(void)
{
    Shutdown();
}

bool CProductionReport::Init(void)
{
    m_logger.LogInfo("Initializing ProductionReport...");
    m_isInitialized = true;
    return true;
}

void CProductionReport::Shutdown(void)
{
    m_isInitialized = false;
}

string CProductionReport::FormatStartupReport(const StartupReport &report)
{
    string out = "";
    out += "========================================\n";
    out += "STARTUP REPORT\n";
    out += "========================================\n";
    out += StringFormat("  Phase          : %d\n", report.phase);
    out += StringFormat("  Success        : %s\n", report.success ? "YES" : "NO");
    out += StringFormat("  Modules        : %d\n", report.moduleCount);
    out += StringFormat("  Failed         : %d\n", report.failedModules);
    out += StringFormat("  Elapsed        : %llu us\n", report.elapsedUs);
    if(report.failureCount > 0)
    {
        out += "  Failures:\n";
        for(int i = 0; i < report.failureCount; i++)
            out += StringFormat("    - %s\n", report.failures[i]);
    }
    out += "========================================\n";
    return out;
}

string CProductionReport::FormatHealthSummary(const HealthStatus &statuses[], int count)
{
    string out = "";
    out += "========================================\n";
    out += "HEALTH SUMMARY\n";
    out += "========================================\n";

    int operational = 0, degraded = 0, failed = 0;
    for(int i = 0; i < count; i++)
    {
        if(statuses[i].isOperational)
            operational++;
        else if(statuses[i].worstFault >= FAULT_MAJOR)
            failed++;
        else
            degraded++;
    }

    out += StringFormat("  Operational    : %d\n", operational);
    out += StringFormat("  Degraded       : %d\n", degraded);
    out += StringFormat("  Failed         : %d\n", failed);
    out += "----------------------------------------\n";

    for(int i = 0; i < count; i++)
    {
        out += StringFormat("  %-20s %s (faults=%d, worst=%d)\n",
                            statuses[i].moduleName,
                            statuses[i].isOperational ? "OK" : "FAIL",
                            statuses[i].faultCount,
                            statuses[i].worstFault);
    }
    out += "========================================\n";
    return out;
}

string CProductionReport::FormatDeploymentReport(const DeploymentReport &report)
{
    string out = "";
    out += "========================================\n";
    out += "DEPLOYMENT REPORT\n";
    out += "========================================\n";
    out += StringFormat("  Status         : %s\n",
                        report.status == DEPLOYMENT_READY ? "READY" :
                        report.status == DEPLOYMENT_WARNING ? "WARNING" :
                        "BLOCKED");
    out += StringFormat("  Checks Passed  : %d\n", report.checksPassed);
    out += StringFormat("  Checks Failed  : %d\n", report.checksFailed);
    out += StringFormat("  Platform       : %s\n", report.platformVersion.ToString());
    out += StringFormat("  Validated At   : %s\n", TimeToString(report.validatedAt));

    if(report.failureCount > 0)
    {
        out += "  Failures:\n";
        for(int i = 0; i < report.failureCount; i++)
            out += StringFormat("    - %s\n", report.failures[i]);
    }
    out += "========================================\n";
    return out;
}

string CProductionReport::FormatFaultSummary(const FaultEvent &events[], int count)
{
    string out = "";
    out += "========================================\n";
    out += "FAULT SUMMARY\n";
    out += "========================================\n";
    out += StringFormat("  Total Faults   : %d\n", count);

    int minor = 0, major = 0, critical = 0;
    for(int i = 0; i < count; i++)
    {
        if(events[i].severity == FAULT_MINOR) minor++;
        else if(events[i].severity == FAULT_MAJOR) major++;
        else critical++;
    }

    out += StringFormat("    Minor        : %d\n", minor);
    out += StringFormat("    Major        : %d\n", major);
    out += StringFormat("    Critical     : %d\n", critical);
    out += "----------------------------------------\n";

    for(int i = 0; i < count; i++)
    {
        string sev = (events[i].severity == FAULT_MINOR ? "MIN" :
                      events[i].severity == FAULT_MAJOR ? "MAJ" : "CRIT");
        out += StringFormat("  [%s] %s: %s [%s]\n",
                            sev, events[i].sourceModule, events[i].description,
                            events[i].recovered ? "RECOVERED" : "PENDING");
    }
    out += "========================================\n";
    return out;
}

#endif
