//+------------------------------------------------------------------+
//|                                               EntryEngine.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __ENTRY_ENGINE_MQH__
#define __ENTRY_ENGINE_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"

class CEntryEngine
{
private:
    CLogger m_logger;
    bool m_isInitialized;

public:
    CEntryEngine(void);
    ~CEntryEngine(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }
};

//--- Inline implementation
CEntryEngine::CEntryEngine(void)
    : m_logger(MODULE_ENTRY_ENGINE, "EntryEngine"), m_isInitialized(false) {}

CEntryEngine::~CEntryEngine(void)
{
    Shutdown();
}

bool CEntryEngine::Init(void)
{
    m_logger.LogInfo("Initializing EntryEngine...");
    m_isInitialized = true;
    m_logger.LogInfo("EntryEngine initialized");
    return true;
}

void CEntryEngine::Update(void)
{
    // Sprint 1: Entry logic will be implemented in later sprints
}

void CEntryEngine::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down EntryEngine...");
    m_isInitialized = false;
    m_logger.LogInfo("EntryEngine shutdown complete");
}

#endif // __ENTRY_ENGINE_MQH__