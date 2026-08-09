#ifndef __PRODUCTION_OPERATIONAL_EVIDENCE_MQH__
#define __PRODUCTION_OPERATIONAL_EVIDENCE_MQH__

#include "../Utils/Constants.mqh"
#include "ProductionTypes.mqh"

enum ENUM_HEALTH_DIMENSION
{
    HEALTH_CONFIG_INTEGRITY = 0,
    HEALTH_COMPONENT_AVAILABILITY,
    HEALTH_INIT_TIMING,
    HEALTH_RESOURCE_UTILIZATION,
    HEALTH_EXECUTION_LATENCY,
    HEALTH_ARTIFACT_INTEGRITY
};

enum ENUM_READINESS_TIER
{
    READINESS_NOT_READY = 0,
    READINESS_PARTIAL,
    READINESS_READY,
    READINESS_VERIFIED
};

struct OperationalEvidence
{
    string   source;
    string   dimension;
    double   value;
    string   rationale;
    string   timestamp;

    OperationalEvidence(void)
        : source(""), dimension(""), value(0.0), rationale(""), timestamp("")
    {}
};

struct HealthSnapshot
{
    double   configIntegrity;
    double   componentAvailability;
    double   initTiming;
    double   resourceUtilization;
    double   executionLatency;
    double   artifactIntegrity;
    double   overallHealthScore;
    OperationalEvidence evidence[32];
    int      evidenceCount;

    HealthSnapshot(void)
        : configIntegrity(100.0), componentAvailability(100.0),
          initTiming(100.0), resourceUtilization(100.0),
          executionLatency(100.0), artifactIntegrity(100.0),
          overallHealthScore(100.0), evidenceCount(0)
    {}
};

struct DiagnosticRecord
{
    datetime timestamp;
    string   sourceModule;
    string   diagnosticType;
    string   description;
    double   severity;
    OperationalEvidence evidence[8];
    int      evidenceCount;

    DiagnosticRecord(void)
        : timestamp(0), sourceModule(""), diagnosticType(""),
          description(""), severity(0.0), evidenceCount(0)
    {}
};

struct PerformanceProfile
{
    ulong    totalExecutionTime;
    ulong    avgModuleTime;
    ulong    maxModuleTime;
    ulong    initDuration;
    ulong    artifactLatency;
    double   throughputPerSecond;
    int      moduleCount;
    OperationalEvidence evidence[32];
    int      evidenceCount;

    PerformanceProfile(void)
        : totalExecutionTime(0), avgModuleTime(0), maxModuleTime(0),
          initDuration(0), artifactLatency(0),
          throughputPerSecond(0.0), moduleCount(0), evidenceCount(0)
    {}
};

struct ConfigurationAudit
{
    int      currentSchemaVersion;
    int      expectedSchemaVersion;
    int      migrationsApplied;
    int      validationPassed;
    int      validationFailed;
    int      deprecatedSettings;
    int      compatibilityWarnings;
    OperationalEvidence evidence[32];
    int      evidenceCount;

    ConfigurationAudit(void)
        : currentSchemaVersion(0), expectedSchemaVersion(0),
          migrationsApplied(0), validationPassed(0), validationFailed(0),
          deprecatedSettings(0), compatibilityWarnings(0), evidenceCount(0)
    {}
};

struct DeploymentEvidence
{
    int      checksPassed;
    int      checksFailed;
    int      totalChecks;
    ENUM_READINESS_TIER readinessTier;
    OperationalEvidence evidence[32];
    int      evidenceCount;

    DeploymentEvidence(void)
        : checksPassed(0), checksFailed(0), totalChecks(0),
          readinessTier(READINESS_NOT_READY), evidenceCount(0)
    {}
};

#endif
