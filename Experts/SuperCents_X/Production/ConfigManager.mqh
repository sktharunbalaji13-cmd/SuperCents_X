#ifndef __PRODUCTION_CONFIG_MANAGER_MQH__
#define __PRODUCTION_CONFIG_MANAGER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "ProductionTypes.mqh"

#define MAX_CONFIG_ENTRIES 256

class CConfigManager
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;
    bool        m_frozen;

    ConfigEntry m_entries[MAX_CONFIG_ENTRIES];
    int         m_entryCount;
    ENUM_CONFIG_STATUS m_status;
    string      m_configFile;

    int FindEntry(const string key) const;

public:
    CConfigManager(void);
    ~CConfigManager(void);

    bool Init(const string configFile);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    ENUM_CONFIG_STATUS GetStatus(void) const { return m_status; }

    bool GetString(const string key, string &outValue) const;
    bool GetInteger(const string key, int &outValue) const;
    bool GetDouble(const string key, double &outValue) const;
    bool GetBool(const string key, bool &outValue) const;

    bool HasKey(const string key) const;
    int  GetEntryCount(void) const { return m_entryCount; }

    bool Reload(const string configFile);
    bool Validate(void) const;
    bool ExportSnapshot(const string filepath) const;
};

CConfigManager::CConfigManager(void)
    : m_logger(MODULE_UNKNOWN, "ConfigManager")
    , m_isInitialized(false)
    , m_frozen(false)
    , m_entryCount(0)
    , m_status(CONFIG_CORRUPTED)
{
}

CConfigManager::~CConfigManager(void)
{
    Shutdown();
}

bool CConfigManager::Init(const string configFile)
{
    m_logger.LogInfo(StringFormat("Loading configuration from %s...", configFile));
    m_configFile = configFile;
    m_entryCount = 0;
    m_frozen = false;

    int handle = FileOpen(configFile, FILE_READ | FILE_TXT | FILE_COMMON);
    if(handle == INVALID_HANDLE)
    {
        m_logger.LogError(StringFormat("Cannot open config file: %s", configFile));
        m_status = CONFIG_CORRUPTED;
        return false;
    }

    m_entryCount = 0;
    while(!FileIsEnding(handle) && m_entryCount < MAX_CONFIG_ENTRIES)
    {
        string line = FileReadString(handle);
        StringTrimLeft(line);
        StringTrimRight(line);

        if(StringLen(line) == 0 || StringSubstr(line, 0, 1) == "#" || StringSubstr(line, 0, 1) == ";")
            continue;

        int eqPos = StringFind(line, "=");
        if(eqPos < 0)
            continue;

        string key = StringSubstr(line, 0, eqPos);
        string value = StringSubstr(line, eqPos + 1);
        StringTrimLeft(key);
        StringTrimRight(key);
        StringTrimLeft(value);
        StringTrimRight(value);

        m_entries[m_entryCount].key = key;
        m_entries[m_entryCount].value = value;
        m_entries[m_entryCount].isRequired = false;
        m_entryCount++;
    }

    FileClose(handle);

    if(!Validate())
    {
        m_logger.LogError("Configuration validation failed");
        return false;
    }

    m_frozen = true;
    m_isInitialized = true;
    m_logger.LogInfo(StringFormat("Configuration loaded: %d entries", m_entryCount));
    return true;
}

void CConfigManager::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_entryCount = 0;
    m_frozen = false;
    m_status = CONFIG_CORRUPTED;
    m_isInitialized = false;
}

int CConfigManager::FindEntry(const string key) const
{
    for(int i = 0; i < m_entryCount; i++)
    {
        if(m_entries[i].key == key)
            return i;
    }
    return -1;
}

bool CConfigManager::GetString(const string key, string &outValue) const
{
    int idx = FindEntry(key);
    if(idx < 0) return false;
    outValue = m_entries[idx].value;
    return true;
}

bool CConfigManager::GetInteger(const string key, int &outValue) const
{
    string val;
    if(!GetString(key, val)) return false;
    outValue = (int)StringToInteger(val);
    return true;
}

bool CConfigManager::GetDouble(const string key, double &outValue) const
{
    string val;
    if(!GetString(key, val)) return false;
    outValue = StringToDouble(val);
    return true;
}

bool CConfigManager::GetBool(const string key, bool &outValue) const
{
    string val;
    if(!GetString(key, val)) return false;
    val = StringLower(val);
    outValue = (val == "true" || val == "1" || val == "yes");
    return true;
}

bool CConfigManager::HasKey(const string key) const
{
    return FindEntry(key) >= 0;
}

bool CConfigManager::Reload(const string configFile)
{
    m_frozen = false;
    m_entryCount = 0;
    return Init(configFile);
}

bool CConfigManager::Validate(void) const
{
    bool hasVersion = HasKey("configSchemaVersion");
    bool hasPlatform = HasKey("platformVersion");

    if(!hasVersion)
    {
        m_logger.LogWarn("Configuration missing 'configSchemaVersion'");
    }
    if(!hasPlatform)
    {
        m_logger.LogWarn("Configuration missing 'platformVersion'");
    }

    m_status = CONFIG_VALID;
    return true;
}

bool CConfigManager::ExportSnapshot(const string filepath) const
{
    int handle = FileOpen(filepath, FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(handle == INVALID_HANDLE)
        return false;

    FileWrite(handle, "# Configuration Snapshot");
    FileWrite(handle, StringFormat("# Source: %s", m_configFile));
    FileWrite(handle, StringFormat("# Entries: %d", m_entryCount));
    FileWrite(handle, StringFormat("# Status: %d", m_status));

    for(int i = 0; i < m_entryCount; i++)
        FileWrite(handle, StringFormat("%s=%s", m_entries[i].key, m_entries[i].value));

    FileClose(handle);
    return true;
}

#endif
