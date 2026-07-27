#ifndef __PRODUCTION_PRODUCTION_TYPES_MQH__
#define __PRODUCTION_PRODUCTION_TYPES_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"

enum ENUM_FAULT_SEVERITY
{
    FAULT_MINOR = 0,
    FAULT_MAJOR,
    FAULT_CRITICAL
};

enum ENUM_CONFIG_STATUS
{
    CONFIG_VALID = 0,
    CONFIG_INCOMPLETE,
    CONFIG_VERSION_MISMATCH,
    CONFIG_CORRUPTED
};

enum ENUM_STARTUP_PHASE
{
    STARTUP_PHASE_CONFIG = 0,
    STARTUP_PHASE_DEPENDENCIES,
    STARTUP_PHASE_MODULES,
    STARTUP_PHASE_COMPLETE
};

enum ENUM_RECOVERY_ACTION
{
    RECOVERY_NONE = 0,
    RECOVERY_RESTART_MODULE,
    RECOVERY_RELOAD_CONFIG,
    RECOVERY_FULL_RESTART
};

enum ENUM_DEPLOYMENT_STATUS
{
    DEPLOYMENT_READY = 0,
    DEPLOYMENT_WARNING,
    DEPLOYMENT_BLOCKED
};

struct VersionInfo
{
    int     major;
    int     minor;
    int     patch;
    string  label;

    VersionInfo(void)
        : major(0), minor(0), patch(0), label("")
    {}

    string ToString(void) const
    {
        return StringFormat("%d.%d.%d%s", major, minor, patch,
                            (label != "") ? ("-" + label) : "");
    }
};

struct ConfigEntry
{
    string  key;
    string  value;
    string  section;
    bool    isRequired;

    ConfigEntry(void)
        : key(""), value(""), section(""), isRequired(false)
    {}
};

struct MigrationStep
{
    int     fromSchemaVersion;
    int     toSchemaVersion;
    string  description;
    bool    isBreaking;

    MigrationStep(void)
        : fromSchemaVersion(0), toSchemaVersion(0), description(""), isBreaking(false)
    {}
};

struct StartupReport
{
    ENUM_STARTUP_PHASE  phase;
    bool                success;
    int                 moduleCount;
    int                 failedModules;
    string              failures[64];
    int                 failureCount;
    ulong               elapsedUs;

    StartupReport(void)
        : phase(STARTUP_PHASE_CONFIG)
        , success(false)
        , moduleCount(0)
        , failedModules(0)
        , failureCount(0)
        , elapsedUs(0)
    {}
};

struct FaultEvent
{
    datetime            timestamp;
    ENUM_FAULT_SEVERITY severity;
    string              sourceModule;
    string              description;
    ENUM_RECOVERY_ACTION recoveryAction;
    bool                recovered;

    FaultEvent(void)
        : timestamp(0)
        , severity(FAULT_MINOR)
        , sourceModule("")
        , description("")
        , recoveryAction(RECOVERY_NONE)
        , recovered(false)
    {}
};

struct HealthStatus
{
    string              moduleName;
    bool                isOperational;
    ulong               uptimeUs;
    int                 warningCount;
    int                 faultCount;
    ENUM_FAULT_SEVERITY worstFault;

    HealthStatus(void)
        : moduleName("")
        , isOperational(false)
        , uptimeUs(0)
        , warningCount(0)
        , faultCount(0)
        , worstFault(FAULT_MINOR)
    {}
};

struct DeploymentReport
{
    ENUM_DEPLOYMENT_STATUS  status;
    int                     checksPassed;
    int                     checksFailed;
    string                  failures[64];
    int                     failureCount;
    VersionInfo             platformVersion;
    datetime                validatedAt;

    DeploymentReport(void)
        : status(DEPLOYMENT_BLOCKED)
        , checksPassed(0)
        , checksFailed(0)
        , failureCount(0)
        , validatedAt(0)
    {}
};

#endif
