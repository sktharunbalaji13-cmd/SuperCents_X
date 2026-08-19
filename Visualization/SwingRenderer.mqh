//+------------------------------------------------------------------+
//|                                             SwingRenderer.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//+------------------------------------------------------------------+
#ifndef __SWING_RENDERER_MQH__
#define __SWING_RENDERER_MQH__

#include "BaseRenderer.mqh"
#include "ChartObjectNames.mqh"
#include "ChartStyle.mqh"
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

    //--- Phase 2A: rendered-population bookkeeping (time-window FIFO).
    //    The pre-fix Update full-scanned the detector population and
    //    issued a guaranteed-miss StringFormat+ObjectFind for EVERY
    //    outside-window swing (25,568 calls/bar on the live
    //    25,646-swing population; 0.70-1.31 s/bar). The FIFO records
    //    exactly what was drawn (id + time); when the render window
    //    advances it head-deletes in draw order - the same objects
    //    the ObjectFind scan deleted, with zero scanning.
    int         m_drawnHighIds[];
    datetime    m_drawnHighTimes[];
    int         m_drawnHighCount;
    int         m_drawnLowIds[];
    datetime    m_drawnLowTimes[];
    int         m_drawnLowCount;

    //--- PHASE_2A_DIAGNOSTIC (temporary; remove after verification)
    int         m_diagDetectorHighs;
    int         m_diagDetectorLows;
    int         m_diagRenderedSwings;
    int         m_diagDrawCommands;
    int         m_diagDeleteCommands;
    int         m_diagSkippedDeletes;
    int         m_diagSkippedSwings;

    void DrawSwingHigh(const SwingPoint &sp);
    void DrawSwingLow(const SwingPoint &sp);

    //--- First detector index whose swing time >= renderStartTime
    //    (binary search; the detector appends chronologically).
    int WindowStartIndex(bool isHigh, int count, datetime renderStartTime);

public:
    CSwingRenderer(void);
    ~CSwingRenderer(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    void Clear(void);

    void SetDetector(CSwingDetector *detector);
    void SetVSE(CVisualStateEngine *vse);

    //--- Phase-2A deterministic probes (EN-02 style, no chart dependency)
    int GetRenderedSwingHighCount(void) const { return m_drawnHighCount; }
    int GetRenderedSwingLowCount(void) const { return m_drawnLowCount; }
    int GetDrawnHighId(int index) const
    {
        return (index >= 0 && index < m_drawnHighCount) ? m_drawnHighIds[index] : 0;
    }
    datetime GetDrawnHighTime(int index) const
    {
        return (index >= 0 && index < m_drawnHighCount) ? m_drawnHighTimes[index] : 0;
    }
    int GetDrawnLowId(int index) const
    {
        return (index >= 0 && index < m_drawnLowCount) ? m_drawnLowIds[index] : 0;
    }
    datetime GetDrawnLowTime(int index) const
    {
        return (index >= 0 && index < m_drawnLowCount) ? m_drawnLowTimes[index] : 0;
    }
    int GetSwingHighDrawCursor(void) const { return m_lastRenderedHighCount; }
    int GetSwingLowDrawCursor(void) const { return m_lastRenderedLowCount; }
};

CSwingRenderer::CSwingRenderer(void)
    : CBaseRenderer(MODULE_SWING_RENDERER, "SwingRenderer")
    , m_detector(NULL)
    , m_lastRenderedHighCount(0)
    , m_lastRenderedLowCount(0)
    , m_vse(NULL)
    , m_drawnHighCount(0)
    , m_drawnLowCount(0)
    , m_diagDetectorHighs(0)
    , m_diagDetectorLows(0)
    , m_diagRenderedSwings(0)
    , m_diagDrawCommands(0)
    , m_diagDeleteCommands(0)
    , m_diagSkippedDeletes(0)
    , m_diagSkippedSwings(0) {}

CSwingRenderer::~CSwingRenderer(void) {}

bool CSwingRenderer::Init(void)
{
    m_logger.LogInfo("Initializing SwingRenderer...");
    m_isInitialized = true;
    m_lastRenderedHighCount = 0;
    m_lastRenderedLowCount = 0;
    m_drawnHighCount = 0;
    m_drawnLowCount = 0;
    ArrayResize(m_drawnHighIds, SwingRenderHistoryBars + 16);
    ArrayResize(m_drawnHighTimes, SwingRenderHistoryBars + 16);
    ArrayResize(m_drawnLowIds, SwingRenderHistoryBars + 16);
    ArrayResize(m_drawnLowTimes, SwingRenderHistoryBars + 16);
    m_logger.LogInfo(StringFormat("Render Window: History Bars = %d", SwingRenderHistoryBars));
    m_logger.LogInfo("SwingRenderer initialized");
    return true;
}

void CSwingRenderer::Update(void)
{
    if(!m_isInitialized || m_detector == NULL || m_vse == NULL)
        return;

    //--- PHASE_2A_DIAGNOSTIC: per-update counters (aggregate, one line)
    m_diagDetectorHighs = 0;
    m_diagDetectorLows = 0;
    m_diagRenderedSwings = 0;
    m_diagDrawCommands = 0;
    m_diagDeleteCommands = 0;
    m_diagSkippedDeletes = 0;
    m_diagSkippedSwings = 0;

    int totalRates = Bars(_Symbol, _Period);
    int renderBars = MathMin(SwingRenderHistoryBars, MathMax(totalRates - 1, 0));
    datetime renderStartTime = (totalRates > 1) ? iTime(_Symbol, _Period, renderBars) : 0;

    // ---- High swings: incremental draw + time-window FIFO ----
    int highCount = m_detector.GetSwingHighCount();
    int windowStartHigh = WindowStartIndex(true, highCount, renderStartTime);
    m_diagDetectorHighs = highCount;
    m_diagSkippedSwings += windowStartHigh;
    if(windowStartHigh > m_lastRenderedHighCount)
        m_diagSkippedDeletes += windowStartHigh - m_lastRenderedHighCount;

    while(m_drawnHighCount > 0 && m_drawnHighTimes[0] < renderStartTime)
    {
        VisualCommand delCmd;
        delCmd.type    = CMD_DELETE;
        delCmd.objName = SwingHighName(m_drawnHighIds[0]);
        m_vse.Execute(delCmd);
        m_diagDeleteCommands++;

        m_drawnHighCount--;
        for(int k = 0; k < m_drawnHighCount; k++)
        {
            m_drawnHighIds[k]   = m_drawnHighIds[k + 1];
            m_drawnHighTimes[k] = m_drawnHighTimes[k + 1];
        }
    }

    int drawFrom = (m_lastRenderedHighCount > windowStartHigh) ? m_lastRenderedHighCount : windowStartHigh;
    for(int i = drawFrom; i < highCount; i++)
    {
        SwingPoint sp;
        if(m_detector.GetSwingHigh(i, sp))
            DrawSwingHigh(sp);
    }
    m_lastRenderedHighCount = highCount;

    // ---- Low swings: incremental draw + time-window FIFO ----
    int lowCount = m_detector.GetSwingLowCount();
    int windowStartLow = WindowStartIndex(false, lowCount, renderStartTime);
    m_diagDetectorLows = lowCount;
    m_diagSkippedSwings += windowStartLow;
    if(windowStartLow > m_lastRenderedLowCount)
        m_diagSkippedDeletes += windowStartLow - m_lastRenderedLowCount;

    while(m_drawnLowCount > 0 && m_drawnLowTimes[0] < renderStartTime)
    {
        VisualCommand delCmd;
        delCmd.type    = CMD_DELETE;
        delCmd.objName = SwingLowName(m_drawnLowIds[0]);
        m_vse.Execute(delCmd);
        m_diagDeleteCommands++;

        m_drawnLowCount--;
        for(int k = 0; k < m_drawnLowCount; k++)
        {
            m_drawnLowIds[k]   = m_drawnLowIds[k + 1];
            m_drawnLowTimes[k] = m_drawnLowTimes[k + 1];
        }
    }

    int drawFromLow = (m_lastRenderedLowCount > windowStartLow) ? m_lastRenderedLowCount : windowStartLow;
    for(int i = drawFromLow; i < lowCount; i++)
    {
        SwingPoint sp;
        if(m_detector.GetSwingLow(i, sp))
            DrawSwingLow(sp);
    }
    m_lastRenderedLowCount = lowCount;

    //--- PHASE_2A_DIAGNOSTIC: one aggregate line when anything happened
    //    this update (steady state prints nothing).
    if(m_diagDrawCommands > 0 || m_diagDeleteCommands > 0 || m_diagSkippedDeletes > 0)
    {
        Print(StringFormat("PHASE_2A_DIAGNOSTIC SWING_RENDER_DIAG DetectorHighs=%d DetectorLows=%d RenderedSwings=%d DrawCommands=%d DeleteCommands=%d SkippedDeletes=%d SkippedSwings=%d",
                           m_diagDetectorHighs, m_diagDetectorLows,
                           m_diagRenderedSwings, m_diagDrawCommands,
                           m_diagDeleteCommands, m_diagSkippedDeletes,
                           m_diagSkippedSwings));
    }
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
    m_drawnHighCount = 0;
    m_drawnLowCount = 0;
    m_logger.LogInfo("SwingRenderer shutdown complete");
}

void CSwingRenderer::Clear(void)
{
    m_logger.LogInfo("Clearing SwingRenderer chart objects...");
    //--- Track 3: prefix clear routed through the VSE (registry sync)
    if(m_vse != NULL)
        m_vse.DeleteObjectsByPrefix("SCX_SWING_");
    m_lastRenderedHighCount = 0;
    m_lastRenderedLowCount = 0;
    m_drawnHighCount = 0;
    m_drawnLowCount = 0;
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

int CSwingRenderer::WindowStartIndex(bool isHigh, int count, datetime renderStartTime)
{
    int lo = 0;
    int hi = count;
    while(lo < hi)
    {
        int mid = (lo + hi) / 2;
        SwingPoint sp;
        bool ok = isHigh ? m_detector.GetSwingHigh(mid, sp) : m_detector.GetSwingLow(mid, sp);
        if(!ok || sp.time >= renderStartTime)
            hi = mid;
        else
            lo = mid + 1;
    }
    return lo;
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

    //--- Phase 2A: record what was actually drawn (the FIFO basis).
    if(m_drawnHighCount >= ArraySize(m_drawnHighIds))
        ArrayResize(m_drawnHighIds, ArraySize(m_drawnHighIds) + SwingRenderHistoryBars + 16);
    if(m_drawnHighCount >= ArraySize(m_drawnHighTimes))
        ArrayResize(m_drawnHighTimes, ArraySize(m_drawnHighTimes) + SwingRenderHistoryBars + 16);
    m_drawnHighIds[m_drawnHighCount] = sp.id;
    m_drawnHighTimes[m_drawnHighCount] = sp.time;
    m_drawnHighCount++;
    m_diagRenderedSwings++;   // PHASE_2A_DIAGNOSTIC
    m_diagDrawCommands++;     // PHASE_2A_DIAGNOSTIC

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

    //--- Phase 2A: record what was actually drawn (the FIFO basis).
    if(m_drawnLowCount >= ArraySize(m_drawnLowIds))
        ArrayResize(m_drawnLowIds, ArraySize(m_drawnLowIds) + SwingRenderHistoryBars + 16);
    if(m_drawnLowCount >= ArraySize(m_drawnLowTimes))
        ArrayResize(m_drawnLowTimes, ArraySize(m_drawnLowTimes) + SwingRenderHistoryBars + 16);
    m_drawnLowIds[m_drawnLowCount] = sp.id;
    m_drawnLowTimes[m_drawnLowCount] = sp.time;
    m_drawnLowCount++;
    m_diagRenderedSwings++;   // PHASE_2A_DIAGNOSTIC
    m_diagDrawCommands++;     // PHASE_2A_DIAGNOSTIC

    m_logger.LogDebug(StringFormat("Rendered swing low #%d at %s %.5f",
                      sp.id, TimeToString(sp.time), sp.price));
}

#endif // __SWING_RENDERER_MQH__