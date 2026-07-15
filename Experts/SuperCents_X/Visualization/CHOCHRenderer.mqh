//+------------------------------------------------------------------+
//|                                            CHOCHRenderer.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __CHOCH_RENDERER_MQH__
#define __CHOCH_RENDERER_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"

class CCHOCHRenderer
{
private:
    CLogger m_logger;
    bool m_isInitialized;

public:
    CCHOCHRenderer(void);
    ~CCHOCHRenderer(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }
};

//--- Inline implementation
CCHOCHRenderer::CCHOCHRenderer(void)
    : m_logger(MODULE_CHOCH_RENDERER, "CHOCHRenderer"), m_isInitialized(false) {}

CCHOCHRenderer::~CCHOCHRenderer(void)
{
    Shutdown();
}

bool CCHOCHRenderer::Init(void)
{
    m_logger.LogInfo("Initializing CHOCHRenderer...");
    m_isInitialized = true;
    m_logger.LogInfo("CHOCHRenderer initialized");
    return true;
}

void CCHOCHRenderer::Update(void)
{
    // Sprint 1: Visualization logic will be implemented in later sprints
}

void CCHOCHRenderer::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down CHOCHRenderer...");
    m_isInitialized = false;
    m_logger.LogInfo("CHOCHRenderer shutdown complete");
}

#endif // __CHOCH_RENDERER_MQH__