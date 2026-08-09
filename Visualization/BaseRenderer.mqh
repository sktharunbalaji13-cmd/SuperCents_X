//+------------------------------------------------------------------+
//|                                             BaseRenderer.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __BASE_RENDERER_MQH__
#define __BASE_RENDERER_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Core/Logger.mqh"

class CBaseRenderer
{
protected:
    CLogger m_logger;
    bool    m_isInitialized;

    bool CreateObjectIfMissing(const string &name, ENUM_OBJECT type, datetime time1, double price1, datetime time2 = 0, double price2 = 0);

public:
    CBaseRenderer(ENUM_MODULE_ID moduleType, string name);
    virtual ~CBaseRenderer(void);

    virtual bool     Init(void);
    virtual void     Update(void);
    virtual void     Shutdown(void);
    virtual void     Clear(void);
    bool             IsInitialized(void) const { return m_isInitialized; }
};

CBaseRenderer::CBaseRenderer(ENUM_MODULE_ID moduleType, string name)
    : m_logger(moduleType, name)
    , m_isInitialized(false) {}

CBaseRenderer::~CBaseRenderer(void)
{
    Shutdown();
}

bool CBaseRenderer::Init(void)
{
    m_isInitialized = true;
    return true;
}

void CBaseRenderer::Update(void)
{
}

void CBaseRenderer::Shutdown(void)
{
    m_isInitialized = false;
}

void CBaseRenderer::Clear(void)
{
}

bool CBaseRenderer::CreateObjectIfMissing(const string &name, ENUM_OBJECT type, datetime time1, double price1, datetime time2, double price2)
{
    if(ObjectFind(0, name) >= 0)
        return true;

    bool created = (time2 == 0 && price2 == 0.0)
        ? ObjectCreate(0, name, type, 0, time1, price1)
        : ObjectCreate(0, name, type, 0, time1, price1, time2, price2);

    return created;
}

#endif // __BASE_RENDERER_MQH__
