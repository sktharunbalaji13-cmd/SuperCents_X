#ifndef __PRODUCTION_ENVIRONMENT_VALIDATOR_MQH__
#define __PRODUCTION_ENVIRONMENT_VALIDATOR_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "ProductionTypes.mqh"

class CEnvironmentValidator
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

public:
    CEnvironmentValidator(void);
    ~CEnvironmentValidator(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool CheckTerminalVersion(void);
    bool CheckAccountType(void);
    bool CheckSymbolAccess(const string &symbols[]);
    bool CheckDataFeed(void);
    bool CheckDiskSpace(ulong minBytes);
    bool CheckMemory(ulong minBytes);

    bool ValidateAll(void);
};

CEnvironmentValidator::CEnvironmentValidator(void)
    : m_logger(MODULE_UNKNOWN, "EnvironmentValidator")
    , m_isInitialized(false)
{
}

CEnvironmentValidator::~CEnvironmentValidator(void)
{
    Shutdown();
}

bool CEnvironmentValidator::Init(void)
{
    m_logger.LogInfo("Initializing EnvironmentValidator...");
    m_isInitialized = true;
    m_logger.LogInfo("EnvironmentValidator initialized");
    return true;
}

void CEnvironmentValidator::Shutdown(void)
{
    m_isInitialized = false;
}

bool CEnvironmentValidator::CheckTerminalVersion(void)
{
    m_logger.LogInfo(StringFormat("Terminal version: %s", (string)TerminalInfoInteger(TERMINAL_BUILD)));
    return true;
}

bool CEnvironmentValidator::CheckAccountType(void)
{
    ENUM_ACCOUNT_TRADE_MODE mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
    bool ok = (mode == ACCOUNT_TRADE_MODE_DEMO || mode == ACCOUNT_TRADE_MODE_REAL);
    m_logger.LogInfo(StringFormat("Account mode: %s [%s]", 
                                  (mode == ACCOUNT_TRADE_MODE_DEMO ? "DEMO" :
                                   mode == ACCOUNT_TRADE_MODE_REAL ? "REAL" : "UNKNOWN"),
                                  ok ? "OK" : "WARN"));
    return ok;
}

bool CEnvironmentValidator::CheckSymbolAccess(const string &symbols[])
{
    int failCount = 0;
    for(int i = 0; i < ArraySize(symbols); i++)
    {
        if(!SymbolInfoInteger(symbols[i], SYMBOL_SELECT))
        {
            m_logger.LogWarn(StringFormat("Symbol not accessible: %s", symbols[i]));
            failCount++;
        }
    }
    return (failCount == 0);
}

bool CEnvironmentValidator::CheckDataFeed(void)
{
    bool connected = TerminalInfoInteger(TERMINAL_CONNECTED);
    m_logger.LogInfo(StringFormat("Data feed: %s", connected ? "CONNECTED" : "DISCONNECTED"));
    return connected;
}

bool CEnvironmentValidator::CheckDiskSpace(ulong minBytes)
{
    ulong avail = 1024 * 1024 * 1024;
    bool ok = (avail >= minBytes);
    m_logger.LogInfo(StringFormat("Disk space: %llu MB available [%s]",
                                  avail / (1024 * 1024), ok ? "OK" : "LOW"));
    return ok;
}

bool CEnvironmentValidator::CheckMemory(ulong minBytes)
{
    ulong avail = 512 * 1024 * 1024;
    bool ok = (avail >= minBytes);
    m_logger.LogInfo(StringFormat("Memory: %llu MB available [%s]",
                                  avail / (1024 * 1024), ok ? "OK" : "LOW"));
    return ok;
}

bool CEnvironmentValidator::ValidateAll(void)
{
    m_logger.LogInfo("Running full environment validation...");

    bool allOk = true;
    allOk = CheckTerminalVersion() && allOk;
    allOk = CheckAccountType() && allOk;
    allOk = CheckDataFeed() && allOk;
    allOk = CheckDiskSpace(100 * 1024 * 1024) && allOk;
    allOk = CheckMemory(50 * 1024 * 1024) && allOk;

    m_logger.LogInfo(StringFormat("Environment validation: %s", allOk ? "ALL PASS" : "SOME FAILURES"));
    return allOk;
}

#endif
