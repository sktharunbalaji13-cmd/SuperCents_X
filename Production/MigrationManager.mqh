#ifndef __PRODUCTION_MIGRATION_MANAGER_MQH__
#define __PRODUCTION_MIGRATION_MANAGER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "ProductionTypes.mqh"

#define MAX_MIGRATION_STEPS 64

class CMigrationManager
{
private:
    CLogger         m_logger;
    bool            m_isInitialized;

    MigrationStep   m_steps[MAX_MIGRATION_STEPS];
    int             m_stepCount;

public:
    CMigrationManager(void);
    ~CMigrationManager(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool RegisterStep(const MigrationStep &step);
    int  GetStepCount(void) const { return m_stepCount; }

    bool NeedsMigration(int fromSchemaVersion, int toSchemaVersion) const;
    bool Execute(int fromSchemaVersion, int toSchemaVersion);
    bool Rollback(int fromVersion, int toVersion);
};

CMigrationManager::CMigrationManager(void)
    : m_logger(MODULE_UNKNOWN, "MigrationManager")
    , m_isInitialized(false)
    , m_stepCount(0)
{
}

CMigrationManager::~CMigrationManager(void)
{
    Shutdown();
}

bool CMigrationManager::Init(void)
{
    m_logger.LogInfo("Initializing MigrationManager...");
    m_stepCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("MigrationManager initialized");
    return true;
}

void CMigrationManager::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_stepCount = 0;
    m_isInitialized = false;
}

bool CMigrationManager::RegisterStep(const MigrationStep &step)
{
    if(!m_isInitialized || m_stepCount >= MAX_MIGRATION_STEPS)
        return false;

    for(int i = 0; i < m_stepCount; i++)
    {
        if(m_steps[i].fromSchemaVersion == step.fromSchemaVersion &&
           m_steps[i].toSchemaVersion == step.toSchemaVersion)
        {
            m_logger.LogWarn(StringFormat("Duplicate migration: %d -> %d",
                             step.fromSchemaVersion, step.toSchemaVersion));
            return false;
        }
    }

    m_steps[m_stepCount] = step;
    m_stepCount++;
    m_logger.LogInfo(StringFormat("Registered migration: schema %d -> %d [%s]%s",
                                  step.fromSchemaVersion, step.toSchemaVersion,
                                  step.description,
                                  step.isBreaking ? " BREAKING" : ""));
    return true;
}

bool CMigrationManager::NeedsMigration(int fromSchemaVersion, int toSchemaVersion) const
{
    for(int i = 0; i < m_stepCount; i++)
    {
        if(m_steps[i].fromSchemaVersion == fromSchemaVersion &&
           m_steps[i].toSchemaVersion == toSchemaVersion)
            return true;
    }
    return (fromSchemaVersion != toSchemaVersion);
}

bool CMigrationManager::Execute(int fromSchemaVersion, int toSchemaVersion)
{
    if(!m_isInitialized)
        return false;

    m_logger.LogInfo(StringFormat("Executing migration: schema %d -> %d", fromSchemaVersion, toSchemaVersion));

    int executed = 0;
    int current = fromSchemaVersion;

    while(current < toSchemaVersion)
    {
        bool found = false;
        for(int i = 0; i < m_stepCount; i++)
        {
            if(m_steps[i].fromSchemaVersion == current)
            {
                if(m_steps[i].isBreaking)
                {
                    m_logger.LogWarn(StringFormat("Breaking migration %d -> %d: %s",
                                      m_steps[i].fromSchemaVersion,
                                      m_steps[i].toSchemaVersion,
                                      m_steps[i].description));
                }
                current = m_steps[i].toSchemaVersion;
                executed++;
                found = true;
                m_logger.LogInfo(StringFormat("  Step: %s", m_steps[i].description));
                break;
            }
        }
        if(!found)
        {
            m_logger.LogError(StringFormat("No migration path from schema version %d", current));
            return false;
        }
    }

    m_logger.LogInfo(StringFormat("Migration complete: %d steps executed", executed));
    return true;
}

bool CMigrationManager::Rollback(int fromVersion, int toVersion)
{
    if(!m_isInitialized)
        return false;

    m_logger.LogInfo(StringFormat("Rolling back migration: schema %d -> %d (PLACEHOLDER)",
                                  fromVersion, toVersion));
    return true;
}

#endif
