//+------------------------------------------------------------------+
//|                                            Scheduler.mqh          |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __PORTFOLIO_SCHEDULER_MQH__
#define __PORTFOLIO_SCHEDULER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "PortfolioTypes.mqh"

enum ENUM_SCHEDULE_MODE
{
    SCHEDULE_PRIMARY_ONLY = 0,
    SCHEDULE_ROUND_ROBIN,
    SCHEDULE_ALL
};

class CScheduler
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    ENUM_SCHEDULE_MODE m_mode;
    int           m_symbolCount;
    string        m_symbols[MAX_PORTFOLIO_SYMBOLS];
    datetime      m_lastBarTime[MAX_PORTFOLIO_SYMBOLS];
    int           m_currentIndex;

    datetime LastBarTimeForSymbol(const string symbol, ENUM_TIMEFRAMES tf) const
    {
        return iTime(symbol, tf, 0);
    }

    bool IsNewBarForSymbol(const string symbol, ENUM_TIMEFRAMES tf, int idx)
    {
        datetime currentBarTime = LastBarTimeForSymbol(symbol, tf);
        if(currentBarTime == 0)
            return false;
        if(currentBarTime == m_lastBarTime[idx])
            return false;
        m_lastBarTime[idx] = currentBarTime;
        return true;
    }

public:
    CScheduler(void);
    ~CScheduler(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    void SetMode(ENUM_SCHEDULE_MODE mode) { m_mode = mode; }
    void SetSymbols(const PortfolioConfiguration &config);
    bool ShouldUpdate(const string symbol, ENUM_TIMEFRAMES tf);
    int  GetNextSymbolIndex(void);
    int  GetSymbolCount(void) const { return m_symbolCount; }
};

CScheduler::CScheduler(void)
    : m_logger(MODULE_SCHEDULER, "Scheduler")
    , m_isInitialized(false)
    , m_mode(SCHEDULE_PRIMARY_ONLY)
    , m_symbolCount(0)
    , m_currentIndex(0)
{
    for(int i = 0; i < MAX_PORTFOLIO_SYMBOLS; i++)
    {
        m_symbols[i] = "";
        m_lastBarTime[i] = 0;
    }
}

CScheduler::~CScheduler(void)
{
    Shutdown();
}

bool CScheduler::Init(void)
{
    m_logger.LogInfo("Initializing Scheduler...");
    m_currentIndex = 0;
    m_isInitialized = true;
    m_logger.LogInfo("Scheduler initialized");
    return true;
}

void CScheduler::Update(void)
{
}

void CScheduler::Shutdown(void)
{
    if(!m_isInitialized)
        return;
    m_isInitialized = false;
}

void CScheduler::SetSymbols(const PortfolioConfiguration &config)
{
    m_symbolCount = (config.symbolCount > MAX_PORTFOLIO_SYMBOLS)
        ? MAX_PORTFOLIO_SYMBOLS : config.symbolCount;

    for(int i = 0; i < m_symbolCount; i++)
    {
        m_symbols[i] = config.symbols[i].symbol;
        m_lastBarTime[i] = 0;
    }
}

bool CScheduler::ShouldUpdate(const string symbol, ENUM_TIMEFRAMES tf)
{
    if(!m_isInitialized)
        return false;

    if(m_mode == SCHEDULE_PRIMARY_ONLY)
    {
        return IsNewBarForSymbol(symbol, tf, 0);
    }

    if(m_mode == SCHEDULE_ALL)
    {
        for(int i = 0; i < m_symbolCount; i++)
        {
            if(m_symbols[i] == symbol)
                return IsNewBarForSymbol(symbol, tf, i);
        }
        return false;
    }

    if(m_mode == SCHEDULE_ROUND_ROBIN)
    {
        if(m_symbolCount <= 1)
            return IsNewBarForSymbol(symbol, tf, 0);

        for(int i = 0; i < m_symbolCount; i++)
        {
            if(m_symbols[i] == symbol && i == m_currentIndex)
            {
                if(IsNewBarForSymbol(symbol, tf, i))
                {
                    m_currentIndex = (m_currentIndex + 1) % m_symbolCount;
                    return true;
                }
            }
        }
        return false;
    }

    return false;
}

int CScheduler::GetNextSymbolIndex(void)
{
    if(m_symbolCount == 0)
        return -1;

    int start = m_currentIndex;
    for(int i = 0; i < m_symbolCount; i++)
    {
        int idx = (start + i) % m_symbolCount;
        string sym = m_symbols[idx];
        if(sym != "")
        {
            m_currentIndex = (idx + 1) % m_symbolCount;
            return idx;
        }
    }
    return -1;
}

#endif
