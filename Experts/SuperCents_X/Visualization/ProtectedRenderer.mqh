//+------------------------------------------------------------------+
//|                                         ProtectedRenderer.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __PROTECTED_RENDERER_MQH__
#define __PROTECTED_RENDERER_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"

class CProtectedRenderer
{
private:
    CLogger m_logger;
    bool m_isInitialized;

public:
    CProtectedRenderer(void);
    ~CProtectedRenderer(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }
};

//--- Inline implementation
CProtectedRenderer::CProtectedRenderer(void)
    : m_logger(MODULE_PROTECTED_RENDERER, "ProtectedRenderer"), m_isInitialized(false) {}

CProtectedRenderer::~CProtectedRenderer(void)
{
    Shutdown();
}

bool CProtectedRenderer::Init(void)
{
    m_logger.LogInfo("Initializing ProtectedRenderer...");
    m_isInitialized = true;
    m_logger.LogInfo("ProtectedRenderer initialized");
    return true;
}

void CProtectedRenderer::Update(void)
{
    // Sprint 1: Visualization logic will be implemented in later sprints
}

void CProtectedRenderer::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down ProtectedRenderer...");
    m_isInitialized = false;
    m_logger.LogInfo("ProtectedRenderer shutdown complete");
}

#endif // __PROTECTED_RENDERER_MQH__