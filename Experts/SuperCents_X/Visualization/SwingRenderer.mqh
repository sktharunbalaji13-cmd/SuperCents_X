//+------------------------------------------------------------------+
//|                                             SwingRenderer.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __SWING_RENDERER_MQH__
#define __SWING_RENDERER_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"

class CSwingRenderer
{
private:
    CLogger m_logger;
    bool m_isInitialized;

public:
    CSwingRenderer(void);
    ~CSwingRenderer(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }
};

//--- Inline implementation
CSwingRenderer::CSwingRenderer(void)
    : m_logger(MODULE_SWING_RENDERER, "SwingRenderer"), m_isInitialized(false) {}

CSwingRenderer::~CSwingRenderer(void)
{
    Shutdown();
}

bool CSwingRenderer::Init(void)
{
    m_logger.LogInfo("Initializing SwingRenderer...");
    m_isInitialized = true;
    m_logger.LogInfo("SwingRenderer initialized");
    return true;
}

void CSwingRenderer::Update(void)
{
    // Sprint 1: Visualization logic will be implemented in later sprints
}

void CSwingRenderer::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down SwingRenderer...");
    m_isInitialized = false;
    m_logger.LogInfo("SwingRenderer shutdown complete");
}

#endif // __SWING_RENDERER_MQH__