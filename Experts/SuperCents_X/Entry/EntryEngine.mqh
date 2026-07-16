//+------------------------------------------------------------------+
//|                                               EntryEngine.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __ENTRY_ENGINE_MQH__
#define __ENTRY_ENGINE_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "EntrySetup.mqh"

class CEntryEngine
{
private:
    CLogger          m_logger;
    bool             m_isInitialized;
    ENUM_ENTRY_STATE m_state;
    EntrySetup       m_activeSetup;
    int              m_activeSetupId;
    int              m_nextSetupId;

public:
    CEntryEngine(void);
    ~CEntryEngine(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool Arm(const EntrySetup &setup);
    void Cancel(void);

    ENUM_ENTRY_STATE GetState(void) const { return m_state; }
    bool GetActiveSetup(EntrySetup &out) const;
    int  GetActiveSetupId(void) const { return m_activeSetupId; }
};

CEntryEngine::CEntryEngine(void)
    : m_logger(MODULE_ENTRY_ENGINE, "EntryEngine")
    , m_isInitialized(false)
    , m_state(ENTRY_STATE_IDLE)
    , m_activeSetupId(-1)
    , m_nextSetupId(1) {}

CEntryEngine::~CEntryEngine(void)
{
    Shutdown();
}

bool CEntryEngine::Init(void)
{
    m_logger.LogInfo("Initializing EntryEngine...");
    m_isInitialized = true;
    m_state = ENTRY_STATE_IDLE;
    m_activeSetupId = -1;
    m_nextSetupId = 1;
    m_logger.LogInfo("EntryEngine initialized");
    return true;
}

void CEntryEngine::Update(void)
{
    if(!m_isInitialized)
        return;

    if(m_state == ENTRY_STATE_ARMED)
    {
        m_logger.LogDebug(StringFormat("EntryEngine: ARMED (setup #%d), awaiting execution",
                          m_activeSetupId));
    }
}

void CEntryEngine::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    if(m_state == ENTRY_STATE_ARMED)
    {
        m_logger.LogInfo(StringFormat("Shutdown: cancelling armed setup #%d", m_activeSetupId));
    }

    m_logger.LogInfo("Shutting down EntryEngine...");
    m_isInitialized = false;
    m_state = ENTRY_STATE_IDLE;
    m_activeSetupId = -1;
    m_logger.LogInfo("EntryEngine shutdown complete");
}

bool CEntryEngine::Arm(const EntrySetup &setup)
{
    if(!m_isInitialized)
        return false;

    if(!setup.valid)
    {
        m_logger.LogWarn("Arm rejected: invalid setup");
        return false;
    }

    if(m_state == ENTRY_STATE_ARMED)
    {
        if(m_activeSetup.Matches(setup))
        {
            m_logger.LogDebug(StringFormat("Arm skipped: setup #%d unchanged", m_activeSetupId));
            return false;
        }

        m_logger.LogDebug(StringFormat("Arm: replacing existing armed setup #%d with #%d",
                          m_activeSetupId, m_nextSetupId));
    }

    m_activeSetup  = setup;
    m_activeSetupId = m_nextSetupId++;
    m_state        = ENTRY_STATE_ARMED;

    m_logger.LogInfo(StringFormat("Entry ARMED (#%d): %s %s entry=%.5f SL=%.5f TP=%.5f score=%.0f",
        m_activeSetupId,
        (setup.direction == TREND_BULLISH ? "BUY" : "SELL"),
        SetupTypeToString(setup.type),
        setup.entryPrice, setup.stopLoss, setup.takeProfit,
        setup.confluenceScore));

    return true;
}

void CEntryEngine::Cancel(void)
{
    if(!m_isInitialized || m_state != ENTRY_STATE_ARMED)
        return;

    m_logger.LogInfo(StringFormat("Entry CANCELLED (#%d)", m_activeSetupId));
    m_state = ENTRY_STATE_IDLE;
    m_activeSetupId = -1;
}

bool CEntryEngine::GetActiveSetup(EntrySetup &out) const
{
    if(m_state != ENTRY_STATE_ARMED)
        return false;

    out = m_activeSetup;
    return true;
}

string SetupTypeToString(ENUM_SETUP_TYPE type)
{
    switch(type)
    {
        case SETUP_BOS_CONTINUATION:    return "BOS_CONTINUATION";
        case SETUP_CHOCH_REVERSAL:      return "CHOCH_REVERSAL";
        case SETUP_ORDERBLOCK_RETEST:   return "OB_RETEST";
        case SETUP_FVG_CONTINUATION:    return "FVG_CONTINUATION";
        default:                        return "NONE";
    }
}

#endif
