//+------------------------------------------------------------------+
//|                                              BOSRenderer.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//+------------------------------------------------------------------+
#ifndef __BOS_RENDERER_MQH__
#define __BOS_RENDERER_MQH__

#include "BaseRenderer.mqh"
#include "ChartObjectNames.mqh"
#include "ChartStyle.mqh"
#include "ChartUtils.mqh"
#include "VisualStateEngine.mqh"
#include "../Structure/BOSDetector.mqh"
#include "../Structure/StructuralPivotEngine.mqh"

struct BOSVisualState
{
    int      id;
    datetime startTime;
    datetime endTime;
    double   price;
    bool     active;
    bool     bullish;
};

class CBOSRenderer : public CBaseRenderer
{
private:
    CBOSDetector            *m_detector;
    CStructuralPivotEngine  *m_pivotEngine;
    int                      m_lastRenderedBOSCount;
    BOSVisualState           m_visualStates[];
    int                      m_visualStateCount;
    CVisualStateEngine      *m_vse;

    int  FindVisualState(int id);
    void DrawBOS(const BOSEvent &e);
    void FreezePreviousActive(datetime freezeTime);
    void ExtendActiveLine(void);

public:
    CBOSRenderer(void);
    ~CBOSRenderer(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    void Clear(void);

    void SetDetector(CBOSDetector *detector);
    void SetPivotEngine(CStructuralPivotEngine *engine);
    void SetVSE(CVisualStateEngine *vse);
};

CBOSRenderer::CBOSRenderer(void)
    : CBaseRenderer(MODULE_BOS_RENDERER, "BOSRenderer")
    , m_detector(NULL)
    , m_pivotEngine(NULL)
    , m_lastRenderedBOSCount(0)
    , m_visualStateCount(0)
    , m_vse(NULL) {}

CBOSRenderer::~CBOSRenderer(void) {}

bool CBOSRenderer::Init(void)
{
    m_logger.LogInfo("Initializing BOSRenderer...");
    m_isInitialized = true;
    m_lastRenderedBOSCount = 0;
    m_visualStateCount = 0;
    m_logger.LogInfo("BOSRenderer initialized");
    return true;
}

void CBOSRenderer::Update(void)
{
    if(!m_isInitialized || m_detector == NULL || m_vse == NULL)
        return;

    int count = m_detector.GetBOSCount();
    VisualCommand cmdBuf[256];
    int cmdCount = 0;

    if(count > m_lastRenderedBOSCount)
    {
        BOSEvent firstNew;
        if(m_detector.GetBOS(m_lastRenderedBOSCount, firstNew))
        {
            FreezePreviousActive(iTime(_Symbol, _Period, 0));
        }
    }

    for(int i = m_lastRenderedBOSCount; i < count; i++)
    {
        BOSEvent e;
        if(m_detector.GetBOS(i, e))
        {
            DrawBOS(e);
        }
    }
    m_lastRenderedBOSCount = count;

    ExtendActiveLine();

    while(m_visualStateCount > MaxHistoricalBOS)
    {
        int id = m_visualStates[0].id;
        VisualCommand delCmd;
        delCmd.type     = CMD_DELETE;
        delCmd.objName  = BOSLineName(id);
        delCmd.textName = BOSTextName(id);
        m_vse.Execute(delCmd);
        for(int i = 0; i < m_visualStateCount - 1; i++)
            m_visualStates[i] = m_visualStates[i + 1];
        m_visualStateCount--;
        ArrayResize(m_visualStates, m_visualStateCount);
    }
}

void CBOSRenderer::FreezePreviousActive(datetime freezeTime)
{
    VisualCommand cmds[2];
    int cmdCount = 0;

    // Find previous active and promote it to frozen
    for(int i = 0; i < m_visualStateCount; i++)
    {
        if(m_visualStates[i].active)
        {
            m_visualStates[i].active = false;
            m_visualStates[i].endTime = freezeTime;

            string lineName = BOSLineName(m_visualStates[i].id);
            string textName = BOSTextName(m_visualStates[i].id);

            color frozenColor = m_visualStates[i].bullish
                ? COLOR_BOS_BULLISH_FROZEN
                : COLOR_BOS_BEARISH_FROZEN;

            cmds[cmdCount].type      = CMD_FREEZE;
            cmds[cmdCount].objName   = lineName;
            cmds[cmdCount].textName  = textName;
            cmds[cmdCount].time2     = freezeTime;
            cmds[cmdCount].price2    = m_visualStates[i].price;
            cmds[cmdCount].lineColor = frozenColor;
            cmds[cmdCount].textColor = frozenColor;
            cmds[cmdCount].objType   = OBJ_TREND;
            cmds[cmdCount].lineStyle = STYLE_DASH;
            cmdCount++;

            // Promote previous frozen (2nd oldest) to historical
            if(i > 0)
            {
                int prevIdx = i - 1;
                string prevLine = BOSLineName(m_visualStates[prevIdx].id);
                string prevText = BOSTextName(m_visualStates[prevIdx].id);
                color histColor = m_visualStates[prevIdx].bullish
                    ? COLOR_BOS_BULLISH_HIST
                    : COLOR_BOS_BEARISH_HIST;

                cmds[cmdCount].type      = CMD_PROMOTE_HISTORICAL;
                cmds[cmdCount].objName   = prevLine;
                cmds[cmdCount].textName  = prevText;
                cmds[cmdCount].lineColor = histColor;
                cmds[cmdCount].textColor = histColor;
                cmds[cmdCount].objType   = OBJ_TREND;
                cmdCount++;
            }

            m_logger.LogDebug(StringFormat("Froze BOS #%d line at %s",
                              m_visualStates[i].id, TimeToString(freezeTime)));
            break;
        }
    }

    if(cmdCount > 0)
        m_vse.ExecuteBatch(cmds, cmdCount);
}

void CBOSRenderer::ExtendActiveLine(void)
{
    if(m_visualStateCount == 0)
        return;

    int idx = m_visualStateCount - 1;
    if(!m_visualStates[idx].active)
        return;

    datetime currentTime = iTime(_Symbol, _Period, 0);
    if(currentTime <= m_visualStates[idx].endTime)
        return;

    m_visualStates[idx].endTime = currentTime;

    VisualCommand cmd;
    cmd.type    = CMD_EXTEND;
    cmd.objName = BOSLineName(m_visualStates[idx].id);
    cmd.time2   = currentTime;
    cmd.price2  = m_visualStates[idx].price;
    m_vse.Execute(cmd);
}

void CBOSRenderer::Shutdown(void)
{
    if(!m_isInitialized)
        return;
    m_logger.LogInfo("Shutting down BOSRenderer...");
    Clear();
    CBaseRenderer::Shutdown();
    m_lastRenderedBOSCount = 0;
    m_visualStateCount = 0;
    m_logger.LogInfo("BOSRenderer shutdown complete");
}

void CBOSRenderer::Clear(void)
{
    m_logger.LogInfo("Clearing BOSRenderer chart objects...");
    DeleteObjectsByPrefix("SCX_BOS_");
    m_lastRenderedBOSCount = 0;
    m_visualStateCount = 0;
    m_logger.LogInfo("BOSRenderer chart objects cleared");
}

void CBOSRenderer::SetDetector(CBOSDetector *detector)
{
    m_detector = detector;
}

void CBOSRenderer::SetPivotEngine(CStructuralPivotEngine *engine)
{
    m_pivotEngine = engine;
}

void CBOSRenderer::SetVSE(CVisualStateEngine *vse)
{
    m_vse = vse;
}

int CBOSRenderer::FindVisualState(int id)
{
    for(int i = 0; i < m_visualStateCount; i++)
        if(m_visualStates[i].id == id)
            return i;
    return -1;
}

void CBOSRenderer::DrawBOS(const BOSEvent &e)
{
    // Determine start time from the broken pivot
    datetime pivotTime = e.breakTime;  // fallback
    if(m_pivotEngine != NULL)
    {
        StructuralPivot pivot;
        if(m_pivotEngine.GetPivotByID(e.brokenPivotID, pivot))
            pivotTime = pivot.time;
    }

    string lineName = BOSLineName(e.id);
    string textName = BOSTextName(e.id);
    datetime initEnd = e.breakTime + 1;
    color lineColor = e.bullish ? COLOR_BOS_BULLISH : COLOR_BOS_BEARISH;

    // Resolve label text from mode
    string labelText = "BOS";
    switch(BOSLabelMode)
    {
        case BOS_LABEL_NONE:
            labelText = "";
            textName = "";
            break;
        case BOS_LABEL_SIMPLE:
            labelText = "BOS";
            break;
        case BOS_LABEL_DIRECTION:
            labelText = e.bullish ? "BULL BOS" : "BEAR BOS";
            break;
        case BOS_LABEL_DEBUG:
            labelText = e.bullish ? StringFormat("BULL BOS #%d", e.id) : StringFormat("BEAR BOS #%d", e.id);
            break;
    }

    m_logger.LogInfo(StringFormat("BOS Label: Mode=%s  Text=\"%s\"",
        (BOSLabelMode == BOS_LABEL_NONE)      ? "NONE" :
        (BOSLabelMode == BOS_LABEL_SIMPLE)    ? "SIMPLE" :
        (BOSLabelMode == BOS_LABEL_DIRECTION) ? "DIRECTION" : "DEBUG",
        labelText));

    // Resolve label position
    datetime labelTime = 0;
    double labelPrice = 0;
    double labelOffset = 15 * _Point;
    int labelDir = 0;
    datetime midTime = pivotTime + (initEnd - pivotTime) / 2;

    switch(BOSLabelPosition)
    {
        case BOS_LABEL_AT_START:
            labelTime = pivotTime;
            labelPrice = e.bullish ? e.pivotPrice + labelOffset : e.pivotPrice - labelOffset;
            labelDir = e.bullish ? 1 : -1;
            break;
        case BOS_LABEL_AT_MIDPOINT:
            labelTime = midTime;
            labelPrice = e.bullish ? e.pivotPrice + labelOffset : e.pivotPrice - labelOffset;
            labelDir = e.bullish ? 1 : -1;
            break;
        case BOS_LABEL_AT_END:
            labelTime = initEnd;
            labelPrice = e.bullish ? e.pivotPrice + labelOffset : e.pivotPrice - labelOffset;
            labelDir = e.bullish ? 1 : -1;
            break;
    }

    if(CompactLabels)
        labelPrice = ResolveLabelPrice(labelTime, labelPrice, 20 * _Point, labelDir);

    m_logger.LogInfo(StringFormat(
        "BOS Label: pos=%s PIVOT=(%s, %.5f) BREAK=(%s, %.5f) LABEL=(%s, %.5f) offset=%.5f",
        (BOSLabelPosition == BOS_LABEL_AT_START)    ? "START" :
        (BOSLabelPosition == BOS_LABEL_AT_MIDPOINT) ? "MIDPOINT" : "END",
        TimeToString(pivotTime, TIME_DATE | TIME_MINUTES), e.pivotPrice,
        TimeToString(e.breakTime, TIME_DATE | TIME_MINUTES), e.pivotPrice,
        TimeToString(labelTime, TIME_DATE | TIME_MINUTES), labelPrice,
        labelOffset));

    VisualCommand cmd;
    cmd.type       = CMD_DRAW;
    cmd.objName    = lineName;
    cmd.textName   = textName;
    cmd.objType    = OBJ_TREND;
    cmd.time1      = pivotTime;
    cmd.price1     = e.pivotPrice;
    cmd.time2      = initEnd;
    cmd.price2     = e.pivotPrice;
    cmd.lineColor  = lineColor;
    cmd.textColor  = lineColor;
    cmd.labelText  = labelText;
    cmd.fontSize   = 8;
    cmd.width      = 2;
    cmd.isFill     = false;
    cmd.lineStyle  = STYLE_SOLID;
    cmd.labelTime  = labelTime;
    cmd.labelPrice = labelPrice;
    m_vse.Execute(cmd);

    // Override anchor to CENTER
    if(textName != "" && ObjectFind(0, textName) >= 0)
        ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_CENTER);

    int idx = m_visualStateCount;
    ArrayResize(m_visualStates, idx + 1);
    m_visualStates[idx].id        = e.id;
    m_visualStates[idx].startTime = pivotTime;
    m_visualStates[idx].endTime   = initEnd;
    m_visualStates[idx].price     = e.pivotPrice;
    m_visualStates[idx].active    = true;
    m_visualStates[idx].bullish   = e.bullish;
    m_visualStateCount++;

    m_logger.LogDebug(StringFormat("Rendered BOS #%d at %s %.5f pivotTime=%s",
                      e.id, TimeToString(e.breakTime), e.pivotPrice,
                      TimeToString(pivotTime)));
}

#endif // __BOS_RENDERER_MQH__
