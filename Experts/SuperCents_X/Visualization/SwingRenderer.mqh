//+------------------------------------------------------------------+
//|                                             SwingRenderer.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//+------------------------------------------------------------------+
#ifndef __SWING_RENDERER_MQH__
#define __SWING_RENDERER_MQH__

#include "BaseRenderer.mqh"
#include "ChartObjectNames.mqh"
#include "ChartStyle.mqh"
#include "ChartUtils.mqh"
#include "VisualStateEngine.mqh"
#include "../Structure/SwingDetector.mqh"

#define SWING_ARROW_OFFSET_POINTS 50

class CSwingRenderer : public CBaseRenderer
{
private:
    CSwingDetector      *m_detector;
    int                  m_lastRenderedHighCount;
    int                  m_lastRenderedLowCount;
    CVisualStateEngine  *m_vse;

    void DrawSwingHigh(const SwingPoint &sp);
    void DrawSwingLow(const SwingPoint &sp);

public:
    CSwingRenderer(void);
    ~CSwingRenderer(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    void Clear(void);

    void SetDetector(CSwingDetector *detector);
    void SetVSE(CVisualStateEngine *vse);
};

CSwingRenderer::CSwingRenderer(void)
    : CBaseRenderer(MODULE_SWING_RENDERER, "SwingRenderer")
    , m_detector(NULL)
    , m_lastRenderedHighCount(0)
    , m_lastRenderedLowCount(0)
    , m_vse(NULL) {}

CSwingRenderer::~CSwingRenderer(void) {}

bool CSwingRenderer::Init(void)
{
    m_logger.LogInfo("Initializing SwingRenderer...");
    m_isInitialized = true;
    m_lastRenderedHighCount = 0;
    m_lastRenderedLowCount = 0;
    m_logger.LogInfo(StringFormat("Render Window: History Bars = %d", SwingRenderHistoryBars));
    m_logger.LogInfo("SwingRenderer initialized");
    return true;
}

void CSwingRenderer::Update(void)
{
    if(!m_isInitialized || m_detector == NULL || m_vse == NULL)
        return;

    int totalRates = Bars(_Symbol, _Period);
    int renderBars = MathMin(SwingRenderHistoryBars, MathMax(totalRates - 1, 0));
    datetime renderStartTime = (totalRates > 1) ? iTime(_Symbol, _Period, renderBars) : 0;

    int renderedCount = 0;
    int skippedCount = 0;
    int deletedCount = 0;

    // ---- High swings: full-scan reconciliation ----
    int highCount = m_detector.GetSwingHighCount();
    for(int i = 0; i < highCount; i++)
    {
        SwingPoint sp;
        if(!m_detector.GetSwingHigh(i, sp))
            continue;

        if(sp.time < renderStartTime)
        {
            string objName = SwingHighName(sp.id);
            if(ObjectFind(0, objName) >= 0)
            {
                VisualCommand delCmd;
                delCmd.type = CMD_DELETE;
                delCmd.objName = objName;
                m_vse.Execute(delCmd);
                deletedCount++;
                m_logger.LogInfo(StringFormat("DELETE SWING HIGH #%d time=%s reason=outside render window",
                                  sp.id, TimeToString(sp.time)));
            }
            skippedCount++;
        }
        else
        {
            if(i >= m_lastRenderedHighCount)
            {
                DrawSwingHigh(sp);
                renderedCount++;
            }
        }
    }
    m_lastRenderedHighCount = highCount;

    // ---- Low swings: full-scan reconciliation ----
    int lowCount = m_detector.GetSwingLowCount();
    for(int i = 0; i < lowCount; i++)
    {
        SwingPoint sp;
        if(!m_detector.GetSwingLow(i, sp))
            continue;

        if(sp.time < renderStartTime)
        {
            string objName = SwingLowName(sp.id);
            if(ObjectFind(0, objName) >= 0)
            {
                VisualCommand delCmd;
                delCmd.type = CMD_DELETE;
                delCmd.objName = objName;
                m_vse.Execute(delCmd);
                deletedCount++;
                m_logger.LogInfo(StringFormat("DELETE SWING LOW #%d time=%s reason=outside render window",
                                  sp.id, TimeToString(sp.time)));
            }
            skippedCount++;
        }
        else
        {
            if(i >= m_lastRenderedLowCount)
            {
                DrawSwingLow(sp);
                renderedCount++;
            }
        }
    }
    m_lastRenderedLowCount = lowCount;

    m_logger.LogInfo(StringFormat("Rendered Swings : %d  Skipped Swings : %d  Deleted Objects : %d",
                      renderedCount, skippedCount, deletedCount));
}

void CSwingRenderer::Shutdown(void)
{
    if(!m_isInitialized)
        return;
    m_logger.LogInfo("Shutting down SwingRenderer...");
    Clear();
    CBaseRenderer::Shutdown();
    m_lastRenderedHighCount = 0;
    m_lastRenderedLowCount = 0;
    m_logger.LogInfo("SwingRenderer shutdown complete");
}

void CSwingRenderer::Clear(void)
{
    m_logger.LogInfo("Clearing SwingRenderer chart objects...");
    DeleteObjectsByPrefix("SCX_SWING_");
    m_lastRenderedHighCount = 0;
    m_lastRenderedLowCount = 0;
    m_logger.LogInfo("SwingRenderer chart objects cleared");
}

void CSwingRenderer::SetDetector(CSwingDetector *detector)
{
    m_detector = detector;
}

void CSwingRenderer::SetVSE(CVisualStateEngine *vse)
{
    m_vse = vse;
}

void CSwingRenderer::DrawSwingHigh(const SwingPoint &sp)
{
    string name = SwingHighName(sp.id);
    double arrowPrice = sp.price + SWING_ARROW_OFFSET_POINTS * _Point;

    VisualCommand cmd;
    cmd.type      = CMD_DRAW;
    cmd.objName   = name;
    cmd.objType   = OBJ_ARROW_DOWN;
    cmd.time1     = sp.time;
    cmd.price1    = arrowPrice;
    cmd.lineColor = COLOR_SWING_HIGH;
    m_vse.Execute(cmd);

    m_logger.LogDebug(StringFormat("Rendered swing high #%d at %s %.5f",
                      sp.id, TimeToString(sp.time), sp.price));
}

void CSwingRenderer::DrawSwingLow(const SwingPoint &sp)
{
    string name = SwingLowName(sp.id);
    double arrowPrice = sp.price - SWING_ARROW_OFFSET_POINTS * _Point;

    VisualCommand cmd;
    cmd.type      = CMD_DRAW;
    cmd.objName   = name;
    cmd.objType   = OBJ_ARROW_UP;
    cmd.time1     = sp.time;
    cmd.price1    = arrowPrice;
    cmd.lineColor = COLOR_SWING_LOW;
    m_vse.Execute(cmd);

    m_logger.LogDebug(StringFormat("Rendered swing low #%d at %s %.5f",
                      sp.id, TimeToString(sp.time), sp.price));
}

#endif // __SWING_RENDERER_MQH__
