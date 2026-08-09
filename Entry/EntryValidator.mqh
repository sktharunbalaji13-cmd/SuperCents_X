//+------------------------------------------------------------------+
//|                                           EntryValidator.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __ENTRY_VALIDATOR_MQH__
#define __ENTRY_VALIDATOR_MQH__

#include "../Core/Logger.mqh"
#include "EntrySetup.mqh"

#define VALIDATOR_MIN_SCORE 30

class CEntryValidator
{
private:
    CLogger m_logger;
    bool    m_isInitialized;
    double  m_minScore;

public:
    CEntryValidator(void);
    ~CEntryValidator(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool IsValid(const EntrySetup &setup);

    void SetMinScore(double score) { m_minScore = score; }
};

CEntryValidator::CEntryValidator(void)
    : m_logger(MODULE_ENTRY_VALIDATOR, "EntryValidator")
    , m_isInitialized(false)
    , m_minScore(VALIDATOR_MIN_SCORE) {}

CEntryValidator::~CEntryValidator(void) {}

bool CEntryValidator::Init(void)
{
    m_logger.LogInfo("Initializing EntryValidator...");
    m_isInitialized = true;
    m_logger.LogInfo("EntryValidator initialized");
    return true;
}

void CEntryValidator::Shutdown(void)
{
    m_isInitialized = false;
}

bool CEntryValidator::IsValid(const EntrySetup &setup)
{
    if(!setup.valid)
    {
        m_logger.LogDebug("Setup invalid: valid=false");
        return false;
    }

    if(setup.type == SETUP_NONE)
    {
        m_logger.LogDebug("Setup invalid: type=NONE");
        return false;
    }

    if(setup.confluenceScore < m_minScore)
    {
        m_logger.LogDebug(StringFormat("Setup invalid: score %.1f < %.1f", setup.confluenceScore, m_minScore));
        return false;
    }

    if(setup.entryPrice <= 0.0 || setup.stopLoss <= 0.0)
    {
        m_logger.LogDebug("Setup invalid: entry or stop missing");
        return false;
    }

    if(setup.entryPrice == setup.stopLoss)
    {
        m_logger.LogDebug("Setup invalid: zero risk (entry=stop)");
        return false;
    }

    if(setup.direction == TREND_BULLISH && setup.entryPrice <= setup.stopLoss)
    {
        m_logger.LogDebug("Setup invalid: bullish entry must exceed stop");
        return false;
    }

    if(setup.direction == TREND_BEARISH && setup.entryPrice >= setup.stopLoss)
    {
        m_logger.LogDebug("Setup invalid: bearish entry must be below stop");
        return false;
    }

    return true;
}

#endif
