//+------------------------------------------------------------------+
//|                                            PivotRenderer.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//+------------------------------------------------------------------+
#ifndef __PIVOT_RENDERER_MQH__
#define __PIVOT_RENDERER_MQH__

#include "BaseRenderer.mqh"
#include "ChartObjectNames.mqh"
#include "ChartStyle.mqh"
#include "ChartUtils.mqh"
#include "VisualStateEngine.mqh"
#include "../Structure/StructuralPivotEngine.mqh"

#define PIVOT_ARROW_OFFSET_POINTS 50

class CPivotRenderer : public CBaseRenderer
{
private:
    CStructuralPivotEngine *m_detector;
    int                     m_lastRenderedPivotCount;
    CVisualStateEngine     *m_vse;

    void DrawPivot(const StructuralPivot &p);

public:
    CPivotRenderer(void);
    ~CPivotRenderer(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    void Clear(void);

    void SetDetector(CStructuralPivotEngine *detector);
    void SetVSE(CVisualStateEngine *vse);
};

CPivotRenderer::CPivotRenderer(void)
    : CBaseRenderer(MODULE_PIVOT_RENDERER, "PivotRenderer")
    , m_detector(NULL)
    , m_lastRenderedPivotCount(0)
    , m_vse(NULL) {}

CPivotRenderer::~CPivotRenderer(void) {}

bool CPivotRenderer::Init(void)
{
    m_logger.LogInfo("Initializing PivotRenderer...");
    m_isInitialized = true;
    m_lastRenderedPivotCount = 0;
    m_logger.LogInfo("PivotRenderer initialized");
    return true;
}

void CPivotRenderer::Update(void)
{
    if(!m_isInitialized || m_detector == NULL || m_vse == NULL)
        return;

    int count = m_detector.GetPivotCount();
    for(int i = m_lastRenderedPivotCount; i < count; i++)
    {
        StructuralPivot p;
        if(m_detector.GetPivot(i, p))
        {
            DrawPivot(p);
        }
    }
    m_lastRenderedPivotCount = count;

    // FIFO delete oldest pivots exceeding MaxHistoricalPivots
    while(count > MaxHistoricalPivots)
    {
        VisualCommand delCmd;
        delCmd.type    = CMD_DELETE;
        delCmd.objName = PivotName(count - MaxHistoricalPivots);
        m_vse.Execute(delCmd);
        count--;
    }
}

void CPivotRenderer::Shutdown(void)
{
    if(!m_isInitialized)
        return;
    m_logger.LogInfo("Shutting down PivotRenderer...");
    Clear();
    CBaseRenderer::Shutdown();
    m_lastRenderedPivotCount = 0;
    m_logger.LogInfo("PivotRenderer shutdown complete");
}

void CPivotRenderer::Clear(void)
{
    m_logger.LogInfo("Clearing PivotRenderer chart objects...");
    DeleteObjectsByPrefix("SCX_PIVOT_");
    m_lastRenderedPivotCount = 0;
    m_logger.LogInfo("PivotRenderer chart objects cleared");
}

void CPivotRenderer::SetDetector(CStructuralPivotEngine *detector)
{
    m_detector = detector;
}

void CPivotRenderer::SetVSE(CVisualStateEngine *vse)
{
    m_vse = vse;
}

void CPivotRenderer::DrawPivot(const StructuralPivot &p)
{
    string name = PivotName(p.id);
    double offset = PIVOT_ARROW_OFFSET_POINTS * _Point;
    double price = p.isHigh ? p.price + offset : p.price - offset;
    color pivotColor = p.isProtected
        ? (p.isHigh ? COLOR_PIVOT_PROTECTED_HIGH : COLOR_PIVOT_PROTECTED_LOW)
        : COLOR_PIVOT;

    VisualCommand cmd;
    cmd.type      = CMD_DRAW;
    cmd.objName   = name;
    cmd.objType   = OBJ_ARROW;
    cmd.time1     = p.time;
    cmd.price1    = price;
    cmd.lineColor = pivotColor;
    m_vse.Execute(cmd);

    m_logger.LogDebug(StringFormat("Rendered pivot #%d at %s %.5f %s",
                      p.id, TimeToString(p.time), p.price,
                      p.isProtected ? "PROTECTED" : ""));
}

#endif // __PIVOT_RENDERER_MQH__
