//+------------------------------------------------------------------+
//|                                        OrderBlockRenderer.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//+------------------------------------------------------------------+
#ifndef __ORDER_BLOCK_RENDERER_MQH__
#define __ORDER_BLOCK_RENDERER_MQH__

#include "BaseRenderer.mqh"
#include "ChartObjectNames.mqh"
#include "ChartStyle.mqh"
#include "ChartUtils.mqh"
#include "VisualStateEngine.mqh"
#include "../Structure/OrderBlockDetector.mqh"

struct OBVisualState
{
    int      id;
    datetime time;       // OB candle time (left edge)
    datetime rightTime;  // right edge
    double   high;
    double   low;
    bool     active;     // true = extending, false = frozen/deleted
    bool     mitigated;
    bool     invalidated;
};

class COrderBlockRenderer : public CBaseRenderer
{
private:
    COrderBlockDetector *m_detector;
    int                  m_lastRenderedOBCount;
    OBVisualState        m_visualStates[];
    int                  m_visualStateCount;
    CVisualStateEngine  *m_vse;

    int  FindVisualState(int id);
    void DrawOrderBlock(const OrderBlock &ob);
    void ExtendActiveRects(void);
    void CheckMitigation(void);

public:
    COrderBlockRenderer(void);
    ~COrderBlockRenderer(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    void Clear(void);

    void SetDetector(COrderBlockDetector *detector);
    void SetVSE(CVisualStateEngine *vse);
};

COrderBlockRenderer::COrderBlockRenderer(void)
    : CBaseRenderer(MODULE_ORDER_BLOCK_RENDERER, "OrderBlockRenderer")
    , m_detector(NULL)
    , m_lastRenderedOBCount(0)
    , m_visualStateCount(0)
    , m_vse(NULL) {}

COrderBlockRenderer::~COrderBlockRenderer(void) {}

bool COrderBlockRenderer::Init(void)
{
    m_logger.LogInfo("Initializing OrderBlockRenderer...");
    m_isInitialized = true;
    m_lastRenderedOBCount = 0;
    m_visualStateCount = 0;
    m_logger.LogInfo("OrderBlockRenderer initialized");
    return true;
}

void COrderBlockRenderer::Update(void)
{
    if(!m_isInitialized || m_detector == NULL || m_vse == NULL)
        return;

    int count = m_detector.GetOrderBlockCount();

    for(int i = m_lastRenderedOBCount; i < count; i++)
    {
        OrderBlock ob;
        if(m_detector.GetOrderBlock(i, ob))
        {
            DrawOrderBlock(ob);
        }
    }
    m_lastRenderedOBCount = count;

    // Check for mitigation on active OBs
    CheckMitigation();

    // Extend active rectangles to current bar
    ExtendActiveRects();

    // Delete oldest if exceeding limit
    while(m_visualStateCount > MaxHistoricalOB)
    {
        VisualCommand delCmd;
        delCmd.type     = CMD_DELETE;
        delCmd.objName  = OBRectName(m_visualStates[0].id);
        delCmd.textName = OBTextName(m_visualStates[0].id);
        m_vse.Execute(delCmd);
        for(int i = 0; i < m_visualStateCount - 1; i++)
            m_visualStates[i] = m_visualStates[i + 1];
        m_visualStateCount--;
        ArrayResize(m_visualStates, m_visualStateCount);
    }
}

void COrderBlockRenderer::CheckMitigation(void)
{
    datetime currentTime = iTime(_Symbol, _Period, 0);

    //--- Sync mitigation/invalidation flags from detector
    int detCount = m_detector.GetOrderBlockCount();
    for(int j = 0; j < detCount; j++)
    {
        OrderBlock ob;
        if(m_detector.GetOrderBlock(j, ob))
        {
            int idx = FindVisualState(ob.id);
            if(idx >= 0)
            {
                m_visualStates[idx].mitigated   = ob.mitigated;
                m_visualStates[idx].invalidated = ob.invalidated;
            }
        }
    }

    //--- Process state changes
    for(int i = 0; i < m_visualStateCount; i++)
    {
        if(!m_visualStates[i].active)
            continue;

        if(m_visualStates[i].invalidated)
        {
            VisualCommand delCmd;
            delCmd.type     = CMD_DELETE;
            delCmd.objName  = OBRectName(m_visualStates[i].id);
            delCmd.textName = OBTextName(m_visualStates[i].id);
            m_vse.Execute(delCmd);
            m_logger.LogInfo(StringFormat("DELETED OB #%d (invalidated)", m_visualStates[i].id));

            for(int j = i; j < m_visualStateCount - 1; j++)
                m_visualStates[j] = m_visualStates[j + 1];
            m_visualStateCount--;
            ArrayResize(m_visualStates, m_visualStateCount);
            i--;
            continue;
        }

        if(m_visualStates[i].mitigated)
        {
            m_visualStates[i].active = false;
            m_visualStates[i].rightTime = currentTime;

            VisualCommand cmd;
            cmd.type      = CMD_FREEZE;
            cmd.objName   = OBRectName(m_visualStates[i].id);
            cmd.textName  = OBTextName(m_visualStates[i].id);
            cmd.time2     = currentTime;
            cmd.price2    = m_visualStates[i].low;
            cmd.lineColor = COLOR_OB_FROZEN;
            cmd.textColor = COLOR_OB_FROZEN;
            cmd.objType   = OBJ_RECTANGLE;
            cmd.lineStyle = STYLE_DASH;
            cmd.isFill    = false;
            m_vse.Execute(cmd);

            m_logger.LogInfo(StringFormat("FROZE OB #%d (mitigated)", m_visualStates[i].id));
        }
    }
}

void COrderBlockRenderer::ExtendActiveRects(void)
{
    datetime currentTime = iTime(_Symbol, _Period, 0);

    for(int i = 0; i < m_visualStateCount; i++)
    {
        if(!m_visualStates[i].active)
            continue;
        if(currentTime <= m_visualStates[i].rightTime)
            continue;

        m_visualStates[i].rightTime = currentTime;

        VisualCommand cmd;
        cmd.type    = CMD_EXTEND;
        cmd.objName = OBRectName(m_visualStates[i].id);
        cmd.time2   = currentTime;
        cmd.price2  = m_visualStates[i].low;
        m_vse.Execute(cmd);
    }
}

void COrderBlockRenderer::Shutdown(void)
{
    if(!m_isInitialized)
        return;
    m_logger.LogInfo("Shutting down OrderBlockRenderer...");
    Clear();
    CBaseRenderer::Shutdown();
    m_lastRenderedOBCount = 0;
    m_visualStateCount = 0;
    m_logger.LogInfo("OrderBlockRenderer shutdown complete");
}

void COrderBlockRenderer::Clear(void)
{
    m_logger.LogInfo("Clearing OrderBlockRenderer chart objects...");
    DeleteObjectsByPrefix("SCX_OB_");
    m_lastRenderedOBCount = 0;
    m_visualStateCount = 0;
    m_logger.LogInfo("OrderBlockRenderer chart objects cleared");
}

void COrderBlockRenderer::SetDetector(COrderBlockDetector *detector)
{
    m_detector = detector;
}

void COrderBlockRenderer::SetVSE(CVisualStateEngine *vse)
{
    m_vse = vse;
}

int COrderBlockRenderer::FindVisualState(int id)
{
    for(int i = 0; i < m_visualStateCount; i++)
        if(m_visualStates[i].id == id)
            return i;
    return -1;
}

void COrderBlockRenderer::DrawOrderBlock(const OrderBlock &ob)
{
    string rectName = OBRectName(ob.id);
    string textName = OBTextName(ob.id);
    datetime rightTime = iTime(_Symbol, _Period, 0);  // extends to current bar

    double midPrice = (ob.high + ob.low) / 2.0;
    double labelPrice = CompactLabels ? ResolveLabelPrice(ob.time, midPrice, 20 * _Point, 0) : midPrice;
    datetime labelTime = ob.time + PeriodSeconds(_Period) / 2;

    VisualCommand cmd;
    cmd.type       = CMD_DRAW;
    cmd.objName    = rectName;
    cmd.textName   = textName;
    cmd.objType    = OBJ_RECTANGLE;
    cmd.time1      = ob.time;
    cmd.price1     = ob.high;
    cmd.time2      = rightTime;
    cmd.price2     = ob.low;
    cmd.lineColor  = COLOR_OB;
    cmd.textColor  = COLOR_OB;
    cmd.labelText  = "OB";
    cmd.fontSize   = 8;
    cmd.width      = 1;
    cmd.isFill     = true;
    cmd.lineStyle  = STYLE_SOLID;
    cmd.labelTime  = labelTime;
    cmd.labelPrice = labelPrice;
    m_vse.Execute(cmd);

    int idx = m_visualStateCount;
    ArrayResize(m_visualStates, idx + 1);
    m_visualStates[idx].id          = ob.id;
    m_visualStates[idx].time        = ob.time;
    m_visualStates[idx].rightTime   = rightTime;
    m_visualStates[idx].high        = ob.high;
    m_visualStates[idx].low         = ob.low;
    m_visualStates[idx].active      = !ob.mitigated && !ob.invalidated;
    m_visualStates[idx].mitigated   = ob.mitigated;
    m_visualStates[idx].invalidated = ob.invalidated;
    m_visualStateCount++;

    m_logger.LogInfo(StringFormat("DRAW OB #%d\nLeft Time : %s\nRight Time: %s\nCurrent   : %s\nTop: %.5f  Bottom: %.5f\nLabel Time: %s",
                      ob.id,
                      TimeToString(ob.time, TIME_DATE | TIME_MINUTES),
                      TimeToString(rightTime, TIME_DATE | TIME_MINUTES),
                      TimeToString(iTime(_Symbol, _Period, 0), TIME_DATE | TIME_MINUTES),
                      ob.high, ob.low,
                      TimeToString(labelTime, TIME_DATE | TIME_MINUTES)));
}

#endif // __ORDER_BLOCK_RENDERER_MQH__
