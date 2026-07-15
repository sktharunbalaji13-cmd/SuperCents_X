//+------------------------------------------------------------------+
//|                                                   Config.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __CONFIG_MQH__
#define __CONFIG_MQH__

#include "../Utils/Constants.mqh"

class CConfig
{
private:
    bool m_isInitialized;
    bool m_loggingEnabled;
    string m_eaName;
    int m_magicNumber;
    int m_slippage;

public:
    CConfig(void);
    bool Init(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    //--- Getters
    bool IsLoggingEnabled(void) const { return m_loggingEnabled; }
    string GetEAName(void) const { return m_eaName; }
    int GetMagicNumber(void) const { return m_magicNumber; }
    int GetSlippage(void) const { return m_slippage; }

    //--- Setters
    void SetLoggingEnabled(bool enabled) { m_loggingEnabled = enabled; }
};

//--- Inline implementation
CConfig::CConfig(void) : m_isInitialized(false), m_loggingEnabled(true), m_eaName("SuperCents_X"), m_magicNumber(0), m_slippage(3) {}

bool CConfig::Init(void)
{
    m_isInitialized = true;
    m_magicNumber = (int)TimeCurrent();
    m_slippage = 3;
    return true;
}

#endif // __CONFIG_MQH__