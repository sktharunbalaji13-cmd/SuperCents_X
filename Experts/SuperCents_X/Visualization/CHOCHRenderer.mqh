//+------------------------------------------------------------------+
//|                                            CHOCHRenderer.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//+------------------------------------------------------------------+
#ifndef __CHOCH_RENDERER_MQH__
#define __CHOCH_RENDERER_MQH__

#include "BaseRenderer.mqh"
#include "ChartObjectNames.mqh"
#include "ChartStyle.mqh"
#include "ChartUtils.mqh"
#include "VisualStateEngine.mqh"
#include "../Structure/CHOCHDetector.mqh"
#include "../Structure/ProtectedPointManager.mqh"

struct CHOCHVisualState
{
    int      id;
    datetime startTime;
    datetime endTime;
    double   price;
    bool     active;
};

class CCHOCHRenderer : public CBaseRenderer
{
private:
    CCHOCHDetector          *m_detector;
    CProtectedPointManager  *m_ppManager;
    int                      m_lastRenderedCHOCHCount;
    CHOCHVisualState         m_visualStates[];
    int                      m_visualStateCount;
    CVisualStateEngine      *m_vse;

    int  FindVisualState(int id);
    void DrawCHOCH(const CHOCHEvent &e);
    void FreezePreviousActive(void);
    void FinalizeActiveLine(void);

public:
    CCHOCHRenderer(void);
    ~CCHOCHRenderer(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    void Clear(void);

    void SetDetector(CCHOCHDetector *detector);
    void SetProtectedPointManager(CProtectedPointManager *manager);
    void SetVSE(CVisualStateEngine *vse);
};

CCHOCHRenderer::CCHOCHRenderer(void)
    : CBaseRenderer(MODULE_CHOCH_RENDERER, "CHOCHRenderer")
    , m_detector(NULL)
    , m_ppManager(NULL)
    , m_lastRenderedCHOCHCount(0)
    , m_visualStateCount(0)
    , m_vse(NULL) {}

CCHOCHRenderer::~CCHOCHRenderer(void) {}

bool CCHOCHRenderer::Init(void)
{
    m_logger.LogInfo("Initializing CHOCHRenderer...");
    m_isInitialized = true;
    m_lastRenderedCHOCHCount = 0;
    m_visualStateCount = 0;
    m_logger.LogInfo("CHOCHRenderer initialized");
    return true;
}

void CCHOCHRenderer::Update(void)
{
    if(!m_isInitialized || m_detector == NULL || m_vse == NULL)
        return;

    int count = m_detector.GetCHOCHCount();

    for(int i = m_lastRenderedCHOCHCount; i < count; i++)
    {
        CHOCHEvent e;
        if(m_detector.GetCHOCH(i, e))
        {
            FreezePreviousActive();
            DrawCHOCH(e);
            FinalizeActiveLine();
        }
    }
    m_lastRenderedCHOCHCount = count;

    while(m_visualStateCount > MaxHistoricalCHOCH)
    {
        int id = m_visualStates[0].id;
        VisualCommand delCmd;
        delCmd.type     = CMD_DELETE;
        delCmd.objName  = CHOCHLineName(id);
        delCmd.textName = CHOCHTextName(id);
        m_vse.Execute(delCmd);
        for(int i = 0; i < m_visualStateCount - 1; i++)
            m_visualStates[i] = m_visualStates[i + 1];
        m_visualStateCount--;
        ArrayResize(m_visualStates, m_visualStateCount);
    }
}

void CCHOCHRenderer::FreezePreviousActive(void)
{
    for(int i = 0; i < m_visualStateCount; i++)
    {
        if(m_visualStates[i].active)
        {
            m_visualStates[i].active = false;

            string lineName = CHOCHLineName(m_visualStates[i].id);
            string textName = CHOCHTextName(m_visualStates[i].id);

            VisualCommand cmd;
            cmd.type      = CMD_FREEZE;
            cmd.objName   = lineName;
            cmd.textName  = textName;
            cmd.time2     = m_visualStates[i].endTime;
            cmd.price2    = m_visualStates[i].price;
            cmd.lineColor = COLOR_CHOCH_FROZEN;
            cmd.textColor = COLOR_CHOCH_FROZEN;
            cmd.objType   = OBJ_TREND;
            cmd.lineStyle = STYLE_DASH;
            cmd.freezeLockLabel = true;
            m_vse.Execute(cmd);

            if(i > 0)
            {
                int prevIdx = i - 1;
                string prevLine = CHOCHLineName(m_visualStates[prevIdx].id);
                string prevText = CHOCHTextName(m_visualStates[prevIdx].id);

                VisualCommand histCmd;
                histCmd.type      = CMD_PROMOTE_HISTORICAL;
                histCmd.objName   = prevLine;
                histCmd.textName  = prevText;
                histCmd.lineColor = COLOR_CHOCH_HIST;
                histCmd.textColor = COLOR_CHOCH_HIST;
                histCmd.objType   = OBJ_TREND;
                m_vse.Execute(histCmd);
            }

            m_logger.LogDebug(StringFormat("Froze CHOCH #%d line at %s",
                              m_visualStates[i].id, TimeToString(m_visualStates[i].endTime)));
            break;
        }
    }
}

void CCHOCHRenderer::FinalizeActiveLine(void)
{
    if(m_visualStateCount == 0)
        return;

    int idx = m_visualStateCount - 1;
    if(!m_visualStates[idx].active)
        return;

    VisualCommand cmd;
    cmd.type    = CMD_FINALIZE;
    cmd.objName = CHOCHLineName(m_visualStates[idx].id);
    cmd.time2   = m_visualStates[idx].endTime;
    cmd.price2  = m_visualStates[idx].price;
    m_vse.Execute(cmd);
}

void CCHOCHRenderer::Shutdown(void)
{
    if(!m_isInitialized)
        return;
    m_logger.LogInfo("Shutting down CHOCHRenderer...");
    Clear();
    CBaseRenderer::Shutdown();
    m_lastRenderedCHOCHCount = 0;
    m_visualStateCount = 0;
    m_logger.LogInfo("CHOCHRenderer shutdown complete");
}

void CCHOCHRenderer::Clear(void)
{
    m_logger.LogInfo("Clearing CHOCHRenderer chart objects...");
    DeleteObjectsByPrefix("SCX_CHOCH_");
    m_lastRenderedCHOCHCount = 0;
    m_visualStateCount = 0;
    m_logger.LogInfo("CHOCHRenderer chart objects cleared");
}

void CCHOCHRenderer::SetDetector(CCHOCHDetector *detector)
{
    m_detector = detector;
}

void CCHOCHRenderer::SetProtectedPointManager(CProtectedPointManager *manager)
{
    m_ppManager = manager;
}

void CCHOCHRenderer::SetVSE(CVisualStateEngine *vse)
{
    m_vse = vse;
}

int CCHOCHRenderer::FindVisualState(int id)
{
    for(int i = 0; i < m_visualStateCount; i++)
        if(m_visualStates[i].id == id)
            return i;
    return -1;
}

void CCHOCHRenderer::DrawCHOCH(const CHOCHEvent &e)
{
    datetime ppTime = e.time;
    double ppPrice = e.breakPrice;
    if(m_ppManager != NULL)
    {
        ProtectedPoint pp;
        if(m_ppManager.GetProtectedPointByID(e.protectedPointID, pp))
        {
            ppTime = pp.time;
            ppPrice = pp.price;
        }
    }

    string lineName = CHOCHLineName(e.id);
    string textName = CHOCHTextName(e.id);
    datetime endTime = (e.time > ppTime) ? e.time : ppTime + PeriodSeconds(_Period);

    double deltaPrice = e.breakPrice - ppPrice;
    m_logger.LogInfo(StringFormat(
        "CHOCH #%d %s  PP=(%s, %.5f)  BREAK=(%s, %.5f)  delta=%.5f %s",
        e.id,
        e.bullish ? "BULLISH" : "BEARISH",
        TimeToString(ppTime, TIME_DATE | TIME_MINUTES),
        ppPrice,
        TimeToString(endTime, TIME_DATE | TIME_MINUTES),
        e.breakPrice,
        deltaPrice,
        (e.bullish && deltaPrice > 0) ? "OK" :
        (!e.bullish && deltaPrice < 0) ? "OK" :
        "⚠ SLOPE MISMATCH"
    ));

    // Resolve label text from mode
    string labelText = "CHOCH";
    switch(CHOCHLabelMode)
    {
        case CHOCH_LABEL_NONE:
            labelText = "";
            textName = "";
            break;
        case CHOCH_LABEL_SIMPLE:
            labelText = "CHOCH";
            break;
        case CHOCH_LABEL_DIRECTION:
            labelText = e.bullish ? "BULL CHOCH" : "BEAR CHOCH";
            break;
        case CHOCH_LABEL_DEBUG:
            labelText = e.bullish ? StringFormat("BULL #%d", e.id) : StringFormat("BEAR #%d", e.id);
            break;
    }

    m_logger.LogInfo(StringFormat("CHOCH Label: Mode=%s  Text=\"%s\"",
        (CHOCHLabelMode == CHOCH_LABEL_NONE)      ? "NONE" :
        (CHOCHLabelMode == CHOCH_LABEL_SIMPLE)    ? "SIMPLE" :
        (CHOCHLabelMode == CHOCH_LABEL_DIRECTION) ? "DIRECTION" : "DEBUG",
        labelText));

    // Resolve label position
    datetime midTime = ppTime + (endTime - ppTime) / 2;
    double midPrice = (ppPrice + e.breakPrice) / 2;
    datetime labelTime = 0;
    double labelPrice = 0;
    double labelOffset = 15 * _Point;
    int labelDir = 0;

    switch(CHOCHLabelPosition)
    {
        case CHOCH_LABEL_AT_START:
            labelTime = ppTime;
            labelPrice = e.bullish ? ppPrice - labelOffset : ppPrice + labelOffset;
            labelDir = e.bullish ? -1 : 1;
            break;
        case CHOCH_LABEL_AT_MIDPOINT:
            labelTime = midTime;
            labelPrice = e.bullish ? midPrice + labelOffset : midPrice - labelOffset;
            labelDir = e.bullish ? 1 : -1;
            break;
        case CHOCH_LABEL_AT_END:
            labelTime = endTime;
            labelPrice = e.bullish ? e.breakPrice + labelOffset : e.breakPrice - labelOffset;
            labelDir = e.bullish ? 1 : -1;
            break;
    }

    if(CompactLabels)
        labelPrice = ResolveLabelPrice(labelTime, labelPrice, 20 * _Point, labelDir);

    m_logger.LogInfo(StringFormat(
        "CHOCH LABEL: pos=%s PP=(%s, %.5f) BREAK=(%s, %.5f) MID=(%s, %.5f) LABEL=(%s, %.5f) offset=%.5f",
        (CHOCHLabelPosition == CHOCH_LABEL_AT_START)    ? "START" :
        (CHOCHLabelPosition == CHOCH_LABEL_AT_MIDPOINT) ? "MIDPOINT" : "END",
        TimeToString(ppTime, TIME_DATE | TIME_MINUTES), ppPrice,
        TimeToString(endTime, TIME_DATE | TIME_MINUTES), e.breakPrice,
        TimeToString(midTime, TIME_DATE | TIME_MINUTES), midPrice,
        TimeToString(labelTime, TIME_DATE | TIME_MINUTES), labelPrice,
        (CHOCHLabelPosition == CHOCH_LABEL_AT_START)    ? (labelPrice - ppPrice) :
        (CHOCHLabelPosition == CHOCH_LABEL_AT_MIDPOINT) ? (labelPrice - midPrice) :
        (labelPrice - e.breakPrice)));

    VisualCommand cmd;
    cmd.type       = CMD_DRAW;
    cmd.objName    = lineName;
    cmd.textName   = textName;
    cmd.objType    = OBJ_TREND;
    cmd.time1      = ppTime;
    cmd.price1     = ppPrice;
    cmd.time2      = endTime;
    cmd.price2     = e.breakPrice;
    cmd.lineColor  = COLOR_CHOCH;
    cmd.textColor  = COLOR_CHOCH;
    cmd.labelText  = labelText;
    cmd.fontSize   = 8;
    cmd.width      = 2;
    cmd.isFill     = false;
    cmd.lineStyle  = STYLE_SOLID;
    cmd.labelTime  = labelTime;
    cmd.labelPrice = labelPrice;
    m_vse.Execute(cmd);

    // Override default ANCHOR_LEFT_UPPER → ANCHOR_CENTER so midpoint
    // anchors at text center, not upper-left.  Without this, the text
    // extends downward from the midpoint, appearing below the line.
    if(textName != "" && ObjectFind(0, textName) >= 0)
        ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_CENTER);

    // Verify stored coordinates match what we sent
    if(ObjectFind(0, lineName) >= 0)
    {
        datetime t1 = (datetime)ObjectGetInteger(0, lineName, OBJPROP_TIME, 0);
        double    p1 = ObjectGetDouble(0, lineName, OBJPROP_PRICE, 0);
        datetime t2 = (datetime)ObjectGetInteger(0, lineName, OBJPROP_TIME, 1);
        double    p2 = ObjectGetDouble(0, lineName, OBJPROP_PRICE, 1);
        m_logger.LogInfo(StringFormat(
            "CHOCH COORD VERIFY #%d  LINE: sent t1=%s p1=%.5f t2=%s p2=%.5f  |  stored t1=%s p1=%.5f t2=%s p2=%.5f",
            e.id,
            TimeToString(ppTime, TIME_DATE | TIME_MINUTES), ppPrice,
            TimeToString(endTime, TIME_DATE | TIME_MINUTES), e.breakPrice,
            TimeToString(t1, TIME_DATE | TIME_MINUTES), p1,
            TimeToString(t2, TIME_DATE | TIME_MINUTES), p2));
    }
    if(textName != "" && ObjectFind(0, textName) >= 0)
    {
        datetime tt = (datetime)ObjectGetInteger(0, textName, OBJPROP_TIME);
        double    tp = ObjectGetDouble(0, textName, OBJPROP_PRICE);
        m_logger.LogInfo(StringFormat(
            "CHOCH COORD VERIFY #%d  TEXT: sent t=%s p=%.5f  |  stored t=%s p=%.5f",
            e.id,
            TimeToString(labelTime, TIME_DATE | TIME_MINUTES), labelPrice,
            TimeToString(tt, TIME_DATE | TIME_MINUTES), tp));
    }

    int idx = m_visualStateCount;
    ArrayResize(m_visualStates, idx + 1);
    m_visualStates[idx].id        = e.id;
    m_visualStates[idx].startTime = ppTime;
    m_visualStates[idx].endTime   = endTime;
    m_visualStates[idx].price     = e.breakPrice;
    m_visualStates[idx].active    = true;
    m_visualStateCount++;

    m_logger.LogDebug(StringFormat("Rendered CHOCH #%d from %s->%s %.5f",
                      e.id, TimeToString(ppTime), TimeToString(endTime), e.breakPrice));
}

#endif // __CHOCH_RENDERER_MQH__
