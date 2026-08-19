//+------------------------------------------------------------------+
//|                                         ProtectedRenderer.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//+------------------------------------------------------------------+
#ifndef __PROTECTED_RENDERER_MQH__
#define __PROTECTED_RENDERER_MQH__

#include "BaseRenderer.mqh"
#include "ChartObjectNames.mqh"
#include "ChartStyle.mqh"
#include "VisualStateEngine.mqh"
#include "../Structure/ProtectedPointManager.mqh"

struct ProtectedVisualState
{
    int      id;
    datetime startTime;
    datetime endTime;
    double   price;
    bool     isHigh;
    bool     active;
};

class CProtectedRenderer : public CBaseRenderer
{
private:
    CProtectedPointManager *m_detector;
    ProtectedVisualState    m_visualStates[];
    int                     m_visualStateCount;
    int                     m_lastRenderedPPCount;
    int                     m_lastActiveHighId;
    int                     m_lastActiveLowId;
    CVisualStateEngine     *m_vse;

    int  FindVisualState(int id);
    void RemoveVisualState(int index);
    void DrawProtectedPoint(const ProtectedPoint &p);
    void FreezeLine(int vsIdx);
    void ExtendActiveLines(void);

public:
    CProtectedRenderer(void);
    ~CProtectedRenderer(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    void Clear(void);

    void SetDetector(CProtectedPointManager *detector);
    void SetVSE(CVisualStateEngine *vse);
};

CProtectedRenderer::CProtectedRenderer(void)
    : CBaseRenderer(MODULE_PROTECTED_RENDERER, "ProtectedRenderer")
    , m_detector(NULL)
    , m_visualStateCount(0)
    , m_lastRenderedPPCount(0)
    , m_lastActiveHighId(-1)
    , m_lastActiveLowId(-1)
    , m_vse(NULL) {}

CProtectedRenderer::~CProtectedRenderer(void) {}

bool CProtectedRenderer::Init(void)
{
    m_logger.LogInfo("Initializing ProtectedRenderer...");
    m_isInitialized = true;
    m_visualStateCount = 0;
    m_lastRenderedPPCount = 0;
    m_lastActiveHighId = -1;
    m_lastActiveLowId = -1;
    m_logger.LogInfo("ProtectedRenderer initialized");
    return true;
}

void CProtectedRenderer::Update(void)
{
    if(!m_isInitialized || m_detector == NULL || m_vse == NULL)
        return;

    int count = m_detector.GetProtectedPointCount();

    for(int i = m_lastRenderedPPCount; i < count; i++)
    {
        ProtectedPoint p;
        if(!m_detector.GetProtectedPoint(i, p))
            continue;
        DrawProtectedPoint(p);
    }
    m_lastRenderedPPCount = count;

    ProtectedPoint activeHigh, activeLow;
    int currentActiveHighId = m_detector.GetActiveHigh(activeHigh) ? activeHigh.id : -1;
    int currentActiveLowId  = m_detector.GetActiveLow(activeLow)   ? activeLow.id  : -1;

    if(m_lastActiveHighId > 0 && m_lastActiveHighId != currentActiveHighId)
    {
        int vsIdx = FindVisualState(m_lastActiveHighId);
        if(vsIdx >= 0 && m_visualStates[vsIdx].active)
            FreezeLine(vsIdx);
    }
    if(m_lastActiveLowId > 0 && m_lastActiveLowId != currentActiveLowId)
    {
        int vsIdx = FindVisualState(m_lastActiveLowId);
        if(vsIdx >= 0 && m_visualStates[vsIdx].active)
            FreezeLine(vsIdx);
    }
    m_lastActiveHighId = currentActiveHighId;
    m_lastActiveLowId  = currentActiveLowId;

    ExtendActiveLines();

    while(m_visualStateCount > MaxHistoricalPP)
    {
        VisualCommand delCmd;
        delCmd.type     = CMD_DELETE;
        delCmd.objName  = PPLineName(m_visualStates[0].id);
        delCmd.textName = PPTextName(m_visualStates[0].id);
        m_vse.Execute(delCmd);
        RemoveVisualState(0);
    }
}

void CProtectedRenderer::FreezeLine(int vsIdx)
{
    m_visualStates[vsIdx].active = false;
    datetime freezeTime = iTime(_Symbol, _Period, 0);
    if(freezeTime <= m_visualStates[vsIdx].endTime)
        freezeTime = m_visualStates[vsIdx].endTime + 1;
    m_visualStates[vsIdx].endTime = freezeTime;

    string lineName = PPLineName(m_visualStates[vsIdx].id);
    string textName = PPTextName(m_visualStates[vsIdx].id);
    color frozenColor = m_visualStates[vsIdx].isHigh
        ? COLOR_PROTECTED_HIGH_FROZEN
        : COLOR_PROTECTED_LOW_FROZEN;

    if(!ShowInactiveProtectedPoints)
    {
        VisualCommand delCmd;
        delCmd.type     = CMD_DELETE;
        delCmd.objName  = lineName;
        delCmd.textName = textName;
        m_vse.Execute(delCmd);
        RemoveVisualState(vsIdx);
        return;
    }

    VisualCommand cmds[2];
    int cmdCount = 0;

    cmds[cmdCount].type      = CMD_FREEZE;
    cmds[cmdCount].objName   = lineName;
    cmds[cmdCount].textName  = textName;
    cmds[cmdCount].time2     = freezeTime;
    cmds[cmdCount].price2    = m_visualStates[vsIdx].price;
    cmds[cmdCount].lineColor = frozenColor;
    cmds[cmdCount].textColor = frozenColor;
    cmds[cmdCount].objType   = OBJ_TREND;
    cmds[cmdCount].lineStyle = STYLE_DASH;
    cmdCount++;

    // Promote previous frozen to historical
    for(int i = 0; i < m_visualStateCount; i++)
    {
        if(i != vsIdx && !m_visualStates[i].active)
        {
            string prevLine = PPLineName(m_visualStates[i].id);
            string prevText = PPTextName(m_visualStates[i].id);
            color histColor = m_visualStates[i].isHigh
                ? COLOR_PROTECTED_HIGH_HIST
                : COLOR_PROTECTED_LOW_HIST;

            cmds[cmdCount].type      = CMD_PROMOTE_HISTORICAL;
            cmds[cmdCount].objName   = prevLine;
            cmds[cmdCount].textName  = prevText;
            cmds[cmdCount].lineColor = histColor;
            cmds[cmdCount].textColor = histColor;
            cmds[cmdCount].objType   = OBJ_TREND;
            cmdCount++;
            break;
        }
    }

    if(cmdCount > 0)
        m_vse.ExecuteBatch(cmds, cmdCount);
}

void CProtectedRenderer::ExtendActiveLines(void)
{
    datetime currentTime = iTime(_Symbol, _Period, 0);
    int activeIds[2] = {m_lastActiveHighId, m_lastActiveLowId};

    for(int i = 0; i < 2; i++)
    {
        if(activeIds[i] <= 0) continue;
        int vsIdx = FindVisualState(activeIds[i]);
        if(vsIdx < 0 || !m_visualStates[vsIdx].active) continue;
        if(currentTime <= m_visualStates[vsIdx].endTime) continue;

        m_visualStates[vsIdx].endTime = currentTime;

        VisualCommand cmd;
        cmd.type    = CMD_EXTEND;
        cmd.objName = PPLineName(m_visualStates[vsIdx].id);
        cmd.time2   = currentTime;
        cmd.price2  = m_visualStates[vsIdx].price;
        m_vse.Execute(cmd);
    }
}

void CProtectedRenderer::Shutdown(void)
{
    if(!m_isInitialized)
        return;
    m_logger.LogInfo("Shutting down ProtectedRenderer...");
    Clear();
    CBaseRenderer::Shutdown();
    m_visualStateCount = 0;
    m_lastRenderedPPCount = 0;
    m_lastActiveHighId = -1;
    m_lastActiveLowId = -1;
    m_logger.LogInfo("ProtectedRenderer shutdown complete");
}

void CProtectedRenderer::Clear(void)
{
    m_logger.LogInfo("Clearing ProtectedRenderer chart objects...");
    //--- Track 3: prefix clear routed through the VSE (registry sync)
    if(m_vse != NULL)
        m_vse.DeleteObjectsByPrefix("SCX_PP_");
    m_visualStateCount = 0;
    m_lastRenderedPPCount = 0;
    m_lastActiveHighId = -1;
    m_lastActiveLowId = -1;
    m_logger.LogInfo("ProtectedRenderer chart objects cleared");
}

void CProtectedRenderer::SetDetector(CProtectedPointManager *detector)
{
    m_detector = detector;
}

void CProtectedRenderer::SetVSE(CVisualStateEngine *vse)
{
    m_vse = vse;
}

int CProtectedRenderer::FindVisualState(int id)
{
    for(int i = 0; i < m_visualStateCount; i++)
        if(m_visualStates[i].id == id)
            return i;
    return -1;
}

void CProtectedRenderer::RemoveVisualState(int index)
{
    if(index < 0 || index >= m_visualStateCount)
        return;
    for(int i = index; i < m_visualStateCount - 1; i++)
        m_visualStates[i] = m_visualStates[i + 1];
    m_visualStateCount--;
    ArrayResize(m_visualStates, m_visualStateCount);
}

void CProtectedRenderer::DrawProtectedPoint(const ProtectedPoint &p)
{
    // Use pivot formation time (p.time) per spec, NOT activationTime
    datetime startTime = p.time;
    datetime initEnd = startTime + 1;
    color lineColor = p.isHigh ? COLOR_PROTECTED_HIGH : COLOR_PROTECTED_LOW;

    string lineName = PPLineName(p.id);
    string textName = PPTextName(p.id);
    string label = p.isHigh ? "PH" : "PL";
    double labelBase = p.isHigh
        ? p.price + 20 * _Point
        : p.price - 20 * _Point;
    double labelPrice = CompactLabels
        ? m_vse.ResolveLabelPlacement(startTime, labelBase, 20 * _Point, p.isHigh ? 1 : -1)
        : labelBase;
    datetime labelTime = startTime + PeriodSeconds(_Period) / 2;

    VisualCommand cmd;
    cmd.type       = CMD_DRAW;
    cmd.objName    = lineName;
    cmd.textName   = textName;
    cmd.objType    = OBJ_TREND;
    cmd.time1      = startTime;
    cmd.price1     = p.price;
    cmd.time2      = initEnd;
    cmd.price2     = p.price;
    cmd.lineColor  = lineColor;
    cmd.textColor  = lineColor;
    cmd.labelText  = label;
    cmd.fontSize   = 8;
    cmd.width      = 1;
    cmd.isFill     = false;
    cmd.lineStyle  = STYLE_SOLID;
    cmd.labelTime  = labelTime;
    cmd.labelPrice = labelPrice;
    m_vse.Execute(cmd);

    int idx = m_visualStateCount;
    ArrayResize(m_visualStates, idx + 1);
    m_visualStates[idx].id        = p.id;
    m_visualStates[idx].startTime = startTime;
    m_visualStates[idx].endTime   = initEnd;
    m_visualStates[idx].price     = p.price;
    m_visualStates[idx].isHigh    = p.isHigh;
    m_visualStates[idx].active    = p.active;
    m_visualStateCount++;

    m_logger.LogDebug(StringFormat("Rendered protected point #%d at %s %.5f %s",
                      p.id, TimeToString(startTime), p.price,
                      p.active ? "ACTIVE" : "INACTIVE"));
}

#endif // __PROTECTED_RENDERER_MQH__
