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

    //--- Phase 2A: rendered-population bookkeeping. The FIFO deletes the
    //    oldest DRAWN pivot id, never detector-index arithmetic on the
    //    total population (which phantom-deleted 20,398 pivots per
    //    update on the live 20,448-pivot population).
    int                     m_drawnPivotIds[];
    int                     m_drawnPivotCount;

    //--- PHASE_2A_DIAGNOSTIC (temporary; remove after verification)
    int                     m_diagDetectorPivots;
    int                     m_diagRenderedPivots;
    int                     m_diagDrawCommands;
    int                     m_diagDeleteCommands;
    int                     m_diagSkippedDeletes;

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

    //--- Phase-2A deterministic probes (EN-02 style, no chart dependency)
    int GetRenderedPivotCount(void) const { return m_drawnPivotCount; }
    int GetDrawnPivotId(int index) const
    {
        return (index >= 0 && index < m_drawnPivotCount) ? m_drawnPivotIds[index] : 0;
    }
    int GetPivotDrawCursor(void) const { return m_lastRenderedPivotCount; }
};

CPivotRenderer::CPivotRenderer(void)
    : CBaseRenderer(MODULE_PIVOT_RENDERER, "PivotRenderer")
    , m_detector(NULL)
    , m_lastRenderedPivotCount(0)
    , m_vse(NULL)
    , m_drawnPivotCount(0)
    , m_diagDetectorPivots(0)
    , m_diagRenderedPivots(0)
    , m_diagDrawCommands(0)
    , m_diagDeleteCommands(0)
    , m_diagSkippedDeletes(0) {}

CPivotRenderer::~CPivotRenderer(void) {}

bool CPivotRenderer::Init(void)
{
    m_logger.LogInfo("Initializing PivotRenderer...");
    m_isInitialized = true;
    m_lastRenderedPivotCount = 0;
    m_drawnPivotCount = 0;
    ArrayResize(m_drawnPivotIds, MaxHistoricalPivots * 2 + 2);
    m_logger.LogInfo("PivotRenderer initialized");
    return true;
}

void CPivotRenderer::Update(void)
{
    if(!m_isInitialized || m_detector == NULL || m_vse == NULL)
        return;

    //--- PHASE_2A_DIAGNOSTIC: per-update counters (aggregate, one line)
    m_diagDetectorPivots = 0;
    m_diagRenderedPivots = 0;
    m_diagDrawCommands = 0;
    m_diagDeleteCommands = 0;
    m_diagSkippedDeletes = 0;

    int count = m_detector.GetPivotCount();
    int windowStart = count - MaxHistoricalPivots;
    if(windowStart < 0)
        windowStart = 0;

    //--- Phase 2A: catch-up may skip the stale middle of a huge
    //    population; only the newest MaxHistoricalPivots are ever drawn
    //    (the window slide is handled by the FIFO below).
    int drawFrom = (m_lastRenderedPivotCount > windowStart) ? m_lastRenderedPivotCount : windowStart;
    if(windowStart > m_lastRenderedPivotCount)
        m_diagSkippedDeletes = windowStart - m_lastRenderedPivotCount;

    for(int i = drawFrom; i < count; i++)
    {
        StructuralPivot p;
        if(m_detector.GetPivot(i, p))
        {
            DrawPivot(p);
        }
    }
    m_lastRenderedPivotCount = count;

    //--- Phase 2A: FIFO delete the oldest DRAWN pivots (bookkeeping),
    //    never detector-index arithmetic on the total population.
    while(m_drawnPivotCount > MaxHistoricalPivots)
    {
        VisualCommand delCmd;
        delCmd.type    = CMD_DELETE;
        delCmd.objName = PivotName(m_drawnPivotIds[0]);
        m_vse.Execute(delCmd);
        m_diagDeleteCommands++;

        m_drawnPivotCount--;
        for(int k = 0; k < m_drawnPivotCount; k++)
            m_drawnPivotIds[k] = m_drawnPivotIds[k + 1];
    }

    //--- PHASE_2A_DIAGNOSTIC: one aggregate line when anything happened
    //    this update (steady state prints nothing).
    m_diagDetectorPivots = count;
    m_diagRenderedPivots = m_drawnPivotCount;
    if(m_diagDrawCommands > 0 || m_diagDeleteCommands > 0 || m_diagSkippedDeletes > 0)
    {
        Print(StringFormat("PHASE_2A_DIAGNOSTIC PIVOT_RENDER_DIAG DetectorPivots=%d RenderedPivots=%d DrawCommands=%d DeleteCommands=%d SkippedDeletes=%d",
                           m_diagDetectorPivots, m_diagRenderedPivots,
                           m_diagDrawCommands, m_diagDeleteCommands, m_diagSkippedDeletes));
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
    m_drawnPivotCount = 0;
    m_logger.LogInfo("PivotRenderer shutdown complete");
}

void CPivotRenderer::Clear(void)
{
    m_logger.LogInfo("Clearing PivotRenderer chart objects...");
    DeleteObjectsByPrefix("SCX_PIVOT_");
    m_lastRenderedPivotCount = 0;
    m_drawnPivotCount = 0;
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

    //--- Phase 2A: record what was actually drawn (the FIFO basis).
    if(m_drawnPivotCount >= ArraySize(m_drawnPivotIds))
        ArrayResize(m_drawnPivotIds, ArraySize(m_drawnPivotIds) + MaxHistoricalPivots);
    m_drawnPivotIds[m_drawnPivotCount++] = p.id;
    m_diagDrawCommands++;   // PHASE_2A_DIAGNOSTIC

    m_logger.LogDebug(StringFormat("Rendered pivot #%d at %s %.5f %s",
                      p.id, TimeToString(p.time), p.price,
                      p.isProtected ? "PROTECTED" : ""));
}

#endif // __PIVOT_RENDERER_MQH__
