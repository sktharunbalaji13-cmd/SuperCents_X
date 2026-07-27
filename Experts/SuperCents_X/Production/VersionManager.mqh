#ifndef __PRODUCTION_VERSION_MANAGER_MQH__
#define __PRODUCTION_VERSION_MANAGER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "ProductionTypes.mqh"

#define MAX_MODULE_VERSIONS 64

class CVersionManager
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    VersionInfo m_platformVersion;
    VersionInfo m_configSchemaVersion;

    string      m_moduleNames[MAX_MODULE_VERSIONS];
    VersionInfo m_moduleVersions[MAX_MODULE_VERSIONS];
    int         m_moduleCount;

public:
    CVersionManager(void);
    ~CVersionManager(void);

    bool Init(const VersionInfo &platformVersion, const VersionInfo &configSchemaVersion);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    VersionInfo GetPlatformVersion(void) const { return m_platformVersion; }
    VersionInfo GetConfigSchemaVersion(void) const { return m_configSchemaVersion; }

    bool IsCompatible(const VersionInfo &other) const;
    bool RegisterModule(const string moduleName, const VersionInfo &version);
    bool GetModuleVersion(const string moduleName, VersionInfo &out) const;
    int  GetModuleCount(void) const { return m_moduleCount; }
};

CVersionManager::CVersionManager(void)
    : m_logger(MODULE_UNKNOWN, "VersionManager")
    , m_isInitialized(false)
    , m_moduleCount(0)
{
}

CVersionManager::~CVersionManager(void)
{
    Shutdown();
}

bool CVersionManager::Init(const VersionInfo &platformVersion, const VersionInfo &configSchemaVersion)
{
    m_logger.LogInfo(StringFormat("Initializing VersionManager: platform=%s configSchema=%s",
                                  platformVersion.ToString(), configSchemaVersion.ToString()));
    m_platformVersion = platformVersion;
    m_configSchemaVersion = configSchemaVersion;
    m_moduleCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("VersionManager initialized");
    return true;
}

void CVersionManager::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_moduleCount = 0;
    m_isInitialized = false;
}

bool CVersionManager::IsCompatible(const VersionInfo &other) const
{
    return (m_platformVersion.major == other.major);
}

bool CVersionManager::RegisterModule(const string moduleName, const VersionInfo &version)
{
    if(!m_isInitialized || m_moduleCount >= MAX_MODULE_VERSIONS)
        return false;

    for(int i = 0; i < m_moduleCount; i++)
    {
        if(m_moduleNames[i] == moduleName)
        {
            m_moduleVersions[i] = version;
            return true;
        }
    }

    m_moduleNames[m_moduleCount] = moduleName;
    m_moduleVersions[m_moduleCount] = version;
    m_moduleCount++;
    return true;
}

bool CVersionManager::GetModuleVersion(const string moduleName, VersionInfo &out) const
{
    for(int i = 0; i < m_moduleCount; i++)
    {
        if(m_moduleNames[i] == moduleName)
        {
            out = m_moduleVersions[i];
            return true;
        }
    }
    return false;
}

#endif
