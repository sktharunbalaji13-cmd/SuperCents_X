//+------------------------------------------------------------------+
//|                                      LiquidityRenderer.mqh        |
//|                    Sprint 20 - VF01: EQH/EQL renderer foundation  |
//|                                                                  |
//| Spec: docs/VisualSpecification_v2.2.md section 14A.              |
//| Ownership (§2): the detector decides WHAT exists (EQH/EQL        |
//| clusters); this renderer decides HOW it is visualized (static    |
//| OBJ_TREND lines + labels); the VSE performs every chart          |
//| mutation. The renderer NEVER re-implements detection, sweep or   |
//| invalidation logic — it consumes LiquidityLevel events via       |
//| GetLevelCount()/GetLevel() and resolves swing times by id        |
//| through the injected swing detector.                             |
//|                                                                  |
//| VF01 lifecycle: Detected -> Draw -> Active (static) -> Delete    |
//| (FIFO count limit / render window). No CMD_EXTEND, no            |
//| CMD_FINALIZE, no CMD_FREEZE — the sweep/invalidation decision    |
//| tier is deferred (spec §26, VF02+).                              |
//|                                                                  |
//| Test surface: BuildLevelCommand() is a PURE command builder      |
//| (zero MT5 API calls) — headless unit-tested in                  |
//| Tests/unit/TestLiquidityRenderer.mqh.                            |
//+------------------------------------------------------------------+
#ifndef __LIQUIDITY_RENDERER_MQH__
#define __LIQUIDITY_RENDERER_MQH__

#include "BaseRenderer.mqh"
#include "ChartObjectNames.mqh"
#include "ChartStyle.mqh"
#include "ChartUtils.mqh"
#include "RenderConfig.mqh"
#include "VisualStateEngine.mqh"
#include "../Structure/LiquidityDetector.mqh"
#include "../Structure/SwingDetector.mqh"

#define LIQUIDITY_LABEL_OFFSET_POINTS 15

class CLiquidityRenderer : public CBaseRenderer
{
private:
    CLiquidityDetector  *m_detector;
    CSwingDetector      *m_swingDetector;
    CVisualStateEngine  *m_vse;
    int                  m_drawnIds[];
    int                  m_drawnCount;

    bool ResolveMemberTime(int swingId, bool isHigh, datetime &out) const;
    int  FindDrawn(int id) const;
    void RemoveDrawn(int index);
    void AppendDrawn(int id);
    VisualCommand MakeDeleteCommand(int id) const;

public:
    CLiquidityRenderer(void);
    ~CLiquidityRenderer(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    void Clear(void);

    void SetDetector(CLiquidityDetector *detector);
    void SetSwingDetector(CSwingDetector *detector);
    void SetVSE(CVisualStateEngine *vse);

    //--- Pure command builder (testable headless; no MT5 calls).
    //--- `mode` is the label mode; production passes the LiquidityLabelMode
    //--- input, tests pass each enum value directly (inputs are const in
    //--- script/test context and cannot be reassigned).
    bool BuildLevelCommand(const LiquidityLevel &level, VisualCommand &cmd,
                           ENUM_LIQUIDITY_LABEL_MODE mode);
};

CLiquidityRenderer::CLiquidityRenderer(void)
    : CBaseRenderer(MODULE_LIQUIDITY_RENDERER, "LiquidityRenderer")
    , m_detector(NULL)
    , m_swingDetector(NULL)
    , m_vse(NULL)
    , m_drawnCount(0) {}

CLiquidityRenderer::~CLiquidityRenderer(void) {}

bool CLiquidityRenderer::Init(void)
{
    m_logger.LogInfo("Initializing LiquidityRenderer...");
    m_isInitialized = true;
    m_drawnCount = 0;
    ArrayResize(m_drawnIds, 0);
    m_logger.LogInfo(StringFormat("Render Window: History Bars = %d", LiquidityRenderHistoryBars));
    m_logger.LogInfo("LiquidityRenderer initialized");
    return true;
}

void CLiquidityRenderer::Update(void)
{
    if(!m_isInitialized || m_detector == NULL || m_vse == NULL)
        return;

    int totalRates = Bars(_Symbol, _Period);
    int renderBars = MathMin(LiquidityRenderHistoryBars, MathMax(totalRates - 1, 0));
    datetime renderStartTime = (totalRates > 1) ? iTime(_Symbol, _Period, renderBars) : 0;

    VisualCommand cmds[256];
    int cmdCount = 0;

    int levelCount = m_detector.GetLevelCount();
    for(int i = 0; i < levelCount; i++)
    {
        LiquidityLevel lv;
        if(!m_detector.GetLevel(i, lv))
            continue;
        if(lv.type != LIQUIDITY_EQH && lv.type != LIQUIDITY_EQL)
            continue;
        if(lv.status != LIQUIDITY_STATUS_ACTIVE)
            continue;

        bool isEqh = (lv.type == LIQUIDITY_EQH);
        datetime leftTime = 0, rightTime = 0;
        if(!ResolveMemberTime(lv.leftSwingId, isEqh, leftTime))
            continue;
        if(!ResolveMemberTime(lv.rightSwingId, isEqh, rightTime))
            continue;

        string lineName = LiquidityLineName(lv.id);

        //--- Outside the render window: reconcile any existing object away.
        if(rightTime < renderStartTime)
        {
            if(ObjectFind(0, lineName) >= 0)
            {
                if(cmdCount < 256)
                    cmds[cmdCount++] = MakeDeleteCommand(lv.id);
                int drawn = FindDrawn(lv.id);
                if(drawn >= 0)
                    RemoveDrawn(drawn);
            }
            continue;
        }

        //--- Already drawn: never re-create (spec §0 no-repaint).
        if(ObjectFind(0, lineName) >= 0)
            continue;

        VisualCommand drawCmd;
        if(!BuildLevelCommand(lv, drawCmd, LiquidityLabelMode))
            continue;
        if(CompactLabels)
            drawCmd.labelPrice = ResolveLabelPrice(drawCmd.labelTime, drawCmd.labelPrice,
                                                   20.0 * _Point, isEqh ? 1 : -1);
        if(cmdCount < 256)
        {
            cmds[cmdCount++] = drawCmd;
            if(FindDrawn(lv.id) < 0)
                AppendDrawn(lv.id);
        }
    }

    //--- FIFO historical limit (spec §1 delete trigger).
    while(m_drawnCount > MaxHistoricalLiquidity && m_drawnCount > 0)
    {
        if(cmdCount < 256)
            cmds[cmdCount++] = MakeDeleteCommand(m_drawnIds[0]);
        RemoveDrawn(0);
    }

    if(cmdCount > 0)
        m_vse.ExecuteBatch(cmds, cmdCount);
}

void CLiquidityRenderer::Shutdown(void)
{
    if(!m_isInitialized)
        return;
    m_logger.LogInfo("Shutting down LiquidityRenderer...");
    Clear();
    CBaseRenderer::Shutdown();
    m_drawnCount = 0;
    ArrayResize(m_drawnIds, 0);
    m_logger.LogInfo("LiquidityRenderer shutdown complete");
}

void CLiquidityRenderer::Clear(void)
{
    m_logger.LogInfo("Clearing LiquidityRenderer chart objects...");
    DeleteObjectsByPrefix("SCX_LIQ_");
    m_drawnCount = 0;
    ArrayResize(m_drawnIds, 0);
    m_logger.LogInfo("LiquidityRenderer chart objects cleared");
}

void CLiquidityRenderer::SetDetector(CLiquidityDetector *detector)
{
    m_detector = detector;
}

void CLiquidityRenderer::SetSwingDetector(CSwingDetector *detector)
{
    m_swingDetector = detector;
}

void CLiquidityRenderer::SetVSE(CVisualStateEngine *vse)
{
    m_vse = vse;
}

bool CLiquidityRenderer::ResolveMemberTime(int swingId, bool isHigh, datetime &out) const
{
    if(m_swingDetector == NULL)
        return false;
    int n = isHigh ? m_swingDetector.GetSwingHighCount() : m_swingDetector.GetSwingLowCount();
    for(int i = 0; i < n; i++)
    {
        SwingPoint sp;
        bool ok = isHigh ? m_swingDetector.GetSwingHigh(i, sp) : m_swingDetector.GetSwingLow(i, sp);
        if(ok && sp.id == swingId)
        {
            out = sp.time;
            return true;
        }
    }
    return false;
}

int CLiquidityRenderer::FindDrawn(int id) const
{
    for(int i = 0; i < m_drawnCount; i++)
        if(m_drawnIds[i] == id)
            return i;
    return -1;
}

void CLiquidityRenderer::RemoveDrawn(int index)
{
    if(index < 0 || index >= m_drawnCount)
        return;
    for(int i = index; i < m_drawnCount - 1; i++)
        m_drawnIds[i] = m_drawnIds[i + 1];
    m_drawnCount--;
    ArrayResize(m_drawnIds, m_drawnCount);
}

void CLiquidityRenderer::AppendDrawn(int id)
{
    int idx = m_drawnCount;
    ArrayResize(m_drawnIds, idx + 1);
    m_drawnIds[idx] = id;
    m_drawnCount++;
}

VisualCommand CLiquidityRenderer::MakeDeleteCommand(int id) const
{
    VisualCommand delCmd;
    delCmd.type     = CMD_DELETE;
    delCmd.objName  = LiquidityLineName(id);
    delCmd.textName = LiquidityTextName(id);
    return delCmd;
}

bool CLiquidityRenderer::BuildLevelCommand(const LiquidityLevel &level, VisualCommand &cmd,
                                           ENUM_LIQUIDITY_LABEL_MODE mode)
{
    if(!m_isInitialized)
        return false;
    if(level.type != LIQUIDITY_EQH && level.type != LIQUIDITY_EQL)
        return false;
    if(level.status != LIQUIDITY_STATUS_ACTIVE)
        return false;

    bool isEqh = (level.type == LIQUIDITY_EQH);

    datetime leftTime = 0, rightTime = 0;
    if(!ResolveMemberTime(level.leftSwingId, isEqh, leftTime))
        return false;
    if(!ResolveMemberTime(level.rightSwingId, isEqh, rightTime))
        return false;

    //--- Normalize to chronological display order. The detector stores the
    //--- NEWEST member as leftSwingId and the oldest as rightSwingId (its
    //--- swing accessor scan order is newest-first). The visual contract
    //--- (spec v2.2 section 14A) defines the line's LEFT edge as the older
    //--- member and the RIGHT edge as the newer member (formation time).
    datetime dispLeft  = MathMin(leftTime, rightTime);
    datetime dispRight = MathMax(leftTime, rightTime);

    color levelColor = isEqh ? COLOR_LIQUIDITY_EQH : COLOR_LIQUIDITY_EQL;

    string labelText = "";
    switch(mode)
    {
        case LIQUIDITY_LABEL_SIMPLE:
            labelText = isEqh ? "EQH" : "EQL";
            break;
        case LIQUIDITY_LABEL_DIRECTION:
            labelText = isEqh ? "BUY EQH" : "SELL EQL";
            break;
        case LIQUIDITY_LABEL_DEBUG:
            labelText = isEqh ? StringFormat("BUY EQH #%d", level.id)
                              : StringFormat("SELL EQL #%d", level.id);
            break;
        default:
            break; // LIQUIDITY_LABEL_NONE
    }

    cmd.type       = CMD_DRAW;
    cmd.objName    = LiquidityLineName(level.id);
    cmd.textName   = (mode == LIQUIDITY_LABEL_NONE) ? "" : LiquidityTextName(level.id);
    cmd.objType    = OBJ_TREND;
    cmd.time1      = dispLeft;
    cmd.price1     = level.averagePrice;
    cmd.time2      = dispRight;
    cmd.price2     = level.averagePrice;
    cmd.lineColor  = levelColor;
    cmd.textColor  = levelColor;
    cmd.labelText  = labelText;
    cmd.fontSize   = 8;
    cmd.width      = 2;
    cmd.isFill     = false;
    cmd.lineStyle  = STYLE_SOLID;
    cmd.labelTime  = dispRight;
    cmd.labelPrice = level.averagePrice + (isEqh ? LIQUIDITY_LABEL_OFFSET_POINTS * _Point
                                                  : -LIQUIDITY_LABEL_OFFSET_POINTS * _Point);
    cmd.freezeLockLabel = false;
    return true;
}

#endif // __LIQUIDITY_RENDERER_MQH__
