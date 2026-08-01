//+------------------------------------------------------------------+
//|                                                   Config.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __CONFIG_MQH__
#define __CONFIG_MQH__

#include "../Utils/Constants.mqh"
#include "../Entry/EntryConfig.mqh"

class CConfig
{
private:
    bool            m_isInitialized;
    bool            m_loggingEnabled;
    string          m_eaName;
    int             m_magicNumber;
    int             m_slippage;
    ENUM_ENTRY_MODE m_entryMode;

public:
    CConfig(void);
    bool Init(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    //--- Getters
    bool IsLoggingEnabled(void) const { return m_loggingEnabled; }
    string GetEAName(void) const { return m_eaName; }
    int GetMagicNumber(void) const { return m_magicNumber; }
    int GetSlippage(void) const { return m_slippage; }
    ENUM_ENTRY_MODE GetEntryMode(void) const { return m_entryMode; }

    //--- Setters
    void SetLoggingEnabled(bool enabled) { m_loggingEnabled = enabled; }
    void SetEntryMode(ENUM_ENTRY_MODE mode) { m_entryMode = mode; }
};

//--- Inline implementation
CConfig::CConfig(void) : m_isInitialized(false), m_loggingEnabled(true), m_eaName("SuperCents_X"), m_magicNumber(0), m_slippage(3), m_entryMode(ENTRY_MODE_LEGACY) {}

bool CConfig::Init(void)
{
    m_isInitialized = true;
    m_magicNumber = (int)TimeCurrent();
    m_slippage = 3;
    return true;
}

#endif // __CONFIG_MQH__