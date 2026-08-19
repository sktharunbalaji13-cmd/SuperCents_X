//+------------------------------------------------------------------+
//|                                             FVGRenderer.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//+------------------------------------------------------------------+
#ifndef __FVG_RENDERER_MQH__
#define __FVG_RENDERER_MQH__

#include "BaseRenderer.mqh"
#include "ChartObjectNames.mqh"
#include "ChartStyle.mqh"
#include "VisualStateEngine.mqh"
#include "../Structure/FVGDetector.mqh"

struct FVGVisualState
{
    int      id;
    datetime time;       // displacement candle time (left edge)
    datetime rightTime;  // right edge
    double   upper;
    double   lower;
    bool     active;     // true = extending, false = frozen
    bool     filled;
    bool     invalidated;
};

class CFVGRenderer : public CBaseRenderer
{
private:
    CFVGDetector     *m_detector;
    int               m_lastRenderedFVGCount;
    FVGVisualState    m_visualStates[];
    int               m_visualStateCount;
    CVisualStateEngine *m_vse;

    int  FindVisualState(int id);
    void DrawFVG(const FairValueGap &fvg);
    void ExtendActiveRects(void);
    void CheckFilled(void);

public:
    CFVGRenderer(void);
    ~CFVGRenderer(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    void Clear(void);

    void SetDetector(CFVGDetector *detector);
    void SetVSE(CVisualStateEngine *vse);
};

CFVGRenderer::CFVGRenderer(void)
    : CBaseRenderer(MODULE_FVG_RENDERER, "FVGRenderer")
    , m_detector(NULL)
    , m_lastRenderedFVGCount(0)
    , m_visualStateCount(0)
    , m_vse(NULL) {}

CFVGRenderer::~CFVGRenderer(void) {}

bool CFVGRenderer::Init(void)
{
    m_logger.LogInfo("Initializing FVGRenderer...");
    m_isInitialized = true;
    m_lastRenderedFVGCount = 0;
    m_visualStateCount = 0;
    m_logger.LogInfo("FVGRenderer initialized");
    return true;
}

void CFVGRenderer::Update(void)
{
    if(!m_isInitialized || m_detector == NULL || m_vse == NULL)
        return;

    int count = m_detector.GetFVGCount();

    for(int i = m_lastRenderedFVGCount; i < count; i++)
    {
        FairValueGap fvg;
        if(m_detector.GetFVG(i, fvg))
        {
            DrawFVG(fvg);
        }
    }
    m_lastRenderedFVGCount = count;

    // Check for filled gaps
    CheckFilled();

    // Extend active rectangles to current bar
    ExtendActiveRects();

    // Delete oldest if exceeding limit
    while(m_visualStateCount > MaxHistoricalFVG)
    {
        VisualCommand delCmd;
        delCmd.type     = CMD_DELETE;
        delCmd.objName  = FVGRectName(m_visualStates[0].id);
        delCmd.textName = FVGTextName(m_visualStates[0].id);
        m_vse.Execute(delCmd);
        for(int i = 0; i < m_visualStateCount - 1; i++)
            m_visualStates[i] = m_visualStates[i + 1];
        m_visualStateCount--;
        ArrayResize(m_visualStates, m_visualStateCount);
    }
}

void CFVGRenderer::CheckFilled(void)
{
    datetime currentTime = iTime(_Symbol, _Period, 0);

    //--- Sync fill/invalidation flags from detector
    int detCount = m_detector.GetFVGCount();
    for(int j = 0; j < detCount; j++)
    {
        FairValueGap fvg;
        if(m_detector.GetFVG(j, fvg))
        {
            int idx = FindVisualState(fvg.id);
            if(idx >= 0)
            {
                m_visualStates[idx].filled       = fvg.filled;
                m_visualStates[idx].invalidated  = fvg.invalidated;
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
            delCmd.objName  = FVGRectName(m_visualStates[i].id);
            delCmd.textName = FVGTextName(m_visualStates[i].id);
            m_vse.Execute(delCmd);
            m_logger.LogInfo(StringFormat("DELETED FVG #%d (invalidated)", m_visualStates[i].id));

            for(int j = i; j < m_visualStateCount - 1; j++)
                m_visualStates[j] = m_visualStates[j + 1];
            m_visualStateCount--;
            ArrayResize(m_visualStates, m_visualStateCount);
            i--;
            continue;
        }

        if(m_visualStates[i].filled)
        {
            m_visualStates[i].active = false;
            m_visualStates[i].rightTime = currentTime;

            VisualCommand cmd;
            cmd.type      = CMD_FREEZE;
            cmd.objName   = FVGRectName(m_visualStates[i].id);
            cmd.textName  = FVGTextName(m_visualStates[i].id);
            cmd.time2     = currentTime;
            cmd.price2    = m_visualStates[i].lower;
            cmd.lineColor = COLOR_FVG_FROZEN;
            cmd.textColor = COLOR_FVG_FROZEN;
            cmd.objType   = OBJ_RECTANGLE;
            cmd.lineStyle = STYLE_DASH;
            cmd.isFill    = false;
            m_vse.Execute(cmd);

            // Promote oldest frozen to historical when frozen >= 20 bars
            for(int j = 0; j < m_visualStateCount; j++)
            {
                if(j != i && !m_visualStates[j].active && m_visualStates[j].rightTime > 0)
                {
                    if(currentTime - m_visualStates[j].rightTime >= 20 * PeriodSeconds(_Period))
                    {
                        VisualCommand histCmd;
                        histCmd.type      = CMD_PROMOTE_HISTORICAL;
                        histCmd.objName   = FVGRectName(m_visualStates[j].id);
                        histCmd.textName  = FVGTextName(m_visualStates[j].id);
                        histCmd.lineColor = COLOR_FVG_HIST;
                        histCmd.textColor = COLOR_FVG_HIST;
                        histCmd.objType   = OBJ_RECTANGLE;
                        m_vse.Execute(histCmd);
                    }
                    break;
                }
            }

            m_logger.LogInfo(StringFormat("FROZE FVG #%d (filled)", m_visualStates[i].id));
        }
    }
}

void CFVGRenderer::ExtendActiveRects(void)
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
        cmd.objName = FVGRectName(m_visualStates[i].id);
        cmd.time2   = currentTime;
        cmd.price2  = m_visualStates[i].lower;
        m_vse.Execute(cmd);
    }
}

void CFVGRenderer::Shutdown(void)
{
    if(!m_isInitialized)
        return;
    m_logger.LogInfo("Shutting down FVGRenderer...");
    Clear();
    CBaseRenderer::Shutdown();
    m_lastRenderedFVGCount = 0;
    m_visualStateCount = 0;
    m_logger.LogInfo("FVGRenderer shutdown complete");
}

void CFVGRenderer::Clear(void)
{
    m_logger.LogInfo("Clearing FVGRenderer chart objects...");
    //--- Track 3: prefix clear routed through the VSE (registry sync)
    if(m_vse != NULL)
        m_vse.DeleteObjectsByPrefix("SCX_FVG_");
    m_lastRenderedFVGCount = 0;
    m_visualStateCount = 0;
    m_logger.LogInfo("FVGRenderer chart objects cleared");
}

void CFVGRenderer::SetDetector(CFVGDetector *detector)
{
    m_detector = detector;
}

void CFVGRenderer::SetVSE(CVisualStateEngine *vse)
{
    m_vse = vse;
}

int CFVGRenderer::FindVisualState(int id)
{
    for(int i = 0; i < m_visualStateCount; i++)
        if(m_visualStates[i].id == id)
            return i;
    return -1;
}

void CFVGRenderer::DrawFVG(const FairValueGap &fvg)
{
    string rectName = FVGRectName(fvg.id);
    string textName = FVGTextName(fvg.id);
    datetime rightTime = iTime(_Symbol, _Period, 0);  // extends to current bar

    double midPrice = (fvg.upper + fvg.lower) / 2.0;
    double labelPrice = CompactLabels ? m_vse.ResolveLabelPlacement(fvg.time, midPrice, 20 * _Point, 0) : midPrice;
    datetime labelTime = fvg.time + PeriodSeconds(_Period) / 2;

    VisualCommand cmd;
    cmd.type       = CMD_DRAW;
    cmd.objName    = rectName;
    cmd.textName   = textName;
    cmd.objType    = OBJ_RECTANGLE;
    cmd.time1      = fvg.time;
    cmd.price1     = fvg.upper;
    cmd.time2      = rightTime;
    cmd.price2     = fvg.lower;
    cmd.lineColor  = COLOR_FVG;
    cmd.textColor  = COLOR_FVG;
    cmd.labelText  = "FVG";
    cmd.fontSize   = 8;
    cmd.width      = 1;
    cmd.isFill     = true;
    cmd.lineStyle  = STYLE_SOLID;
    cmd.labelTime  = labelTime;
    cmd.labelPrice = labelPrice;
    m_vse.Execute(cmd);

    int idx = m_visualStateCount;
    ArrayResize(m_visualStates, idx + 1);
    m_visualStates[idx].id          = fvg.id;
    m_visualStates[idx].time        = fvg.time;
    m_visualStates[idx].rightTime   = rightTime;
    m_visualStates[idx].upper       = fvg.upper;
    m_visualStates[idx].lower       = fvg.lower;
    m_visualStates[idx].active      = !fvg.filled;
    m_visualStates[idx].filled      = fvg.filled;
    m_visualStates[idx].invalidated = fvg.invalidated;
    m_visualStateCount++;

    string dirStr = fvg.bullish ? "Bullish" : "Bearish";
    m_logger.LogInfo(StringFormat("FVG #%d CREATED %s at %s gap=[%.5f, %.5f]",
                      fvg.id, dirStr,
                      TimeToString(fvg.time, TIME_DATE | TIME_MINUTES),
                      fvg.lower, fvg.upper));
}

#endif // __FVG_RENDERER_MQH__
