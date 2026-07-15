//+------------------------------------------------------------------+
//|                                              BOSRenderer.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __BOS_RENDERER_MQH__
#define __BOS_RENDERER_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"

class CBOSRenderer
{
private:
    CLogger m_logger;
    bool m_isInitialized;

public:
    CBOSRenderer(void);
    ~CBOSRenderer(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }
};

//--- Inline implementation
CBOSRenderer::CBOSRenderer(void)
    : m_logger(MODULE_BOS_RENDERER, "BOSRenderer"), m_isInitialized(false) {}

CBOSRenderer::~CBOSRenderer(void)
{
    Shutdown();
}

bool CBOSRenderer::Init(void)
{
    m_logger.LogInfo("Initializing BOSRenderer...");
    m_isInitialized = true;
    m_logger.LogInfo("BOSRenderer initialized");
    return true;
}

void CBOSRenderer::Update(void)
{
    // Sprint 1: Visualization logic will be implemented in later sprints
}

void CBOSRenderer::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down BOSRenderer...");
    m_isInitialized = false;
    m_logger.LogInfo("BOSRenderer shutdown complete");
}

#endif // __BOS_RENDERER_MQH__