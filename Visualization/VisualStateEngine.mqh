//+------------------------------------------------------------------+
//|                                         VisualStateEngine.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//+------------------------------------------------------------------+
#ifndef __VISUAL_STATE_ENGINE_MQH__
#define __VISUAL_STATE_ENGINE_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"

enum EVisualCommandType
{
    CMD_DRAW,
    CMD_EXTEND,
    CMD_FINALIZE,
    CMD_FREEZE,
    CMD_PROMOTE_HISTORICAL,
    CMD_DELETE
};

struct VisualCommand
{
    EVisualCommandType   type;
    string               objName;
    string               textName;
    ENUM_OBJECT          objType;
    datetime             time1;
    double               price1;
    datetime             time2;
    double               price2;
    color                lineColor;
    color                textColor;
    string               labelText;
    int                  fontSize;
    int                  width;
    bool                 isFill;
    int                  lineStyle;      // STYLE_SOLID, STYLE_DASH, STYLE_DASHDOT
    datetime             labelTime;      // 0 = auto-calculate from time1 + period/2
    double               labelPrice;     // 0 = use price1
    bool                 freezeLockLabel; // if true, freeze preserves label position
};

enum EVisualState
{
    VISUAL_STATE_ACTIVE,
    VISUAL_STATE_FROZEN,
    VISUAL_STATE_HISTORICAL
};

struct VisualStateRecord
{
    string        objName;
    string        textName;
    EVisualState  state;
    datetime      freezeTime;
    double        freezePrice;
    color         baseColor;
    ENUM_OBJECT   objType;
};

//--- Track 3 (Phase 2A): in-memory label registry. Every OBJ_TEXT label
//    is created/moved/deleted exclusively through the VSE, so the
//    registry mirrors the chart's label set exactly and label placement
//    (ResolveLabelPlacement) can run against memory instead of a
//    full-chart ObjectsTotal() scan (~170 API calls per iteration, up
//    to 10 iterations = 95-128 ms on live draw bars). The resolution
//    algorithm is byte-identical to the removed ChartUtils
//    ResolveLabelPrice (same 2-hour window, step, direction and
//    10-iteration cap), only the collision domain is the registry.
struct LabelPlacementRecord
{
    string   textName;
    datetime time;
    double   price;
};

class CVisualStateEngine
{
private:
    VisualStateRecord m_records[];
    int               m_recordCount;

    LabelPlacementRecord m_labelPlacements[];
    int                  m_labelPlacementCount;

    //--- PHASE_1_5_DIAGNOSTIC (temporary instrumentation; remove after verification)
    long              m_diagFindIterations;
    long              m_diagObjectFind;
    long              m_diagObjectCreate;
    long              m_diagObjectDelete;
    long              m_diagCmdExecuted;

    int FindRecord(const string &name)
    {
        for(int i = 0; i < m_recordCount; i++)
        {
            m_diagFindIterations++;   // PHASE_1_5_DIAGNOSTIC
            if(m_records[i].objName == name)
                return i;
        }
        return -1;
    }

    void RemoveRecord(int index)
    {
        if(index < 0 || index >= m_recordCount)
            return;
        for(int i = index; i < m_recordCount - 1; i++)
            m_records[i] = m_records[i + 1];
        m_recordCount--;
        ArrayResize(m_records, m_recordCount);
    }

    //--- Track 3: label-registry bookkeeping (must mirror chart label
    //    state exactly; all label mutations flow through Handle* below).
    void AddLabelPlacement(const string &textName, datetime time, double price)
    {
        int idx = m_labelPlacementCount;
        ArrayResize(m_labelPlacements, idx + 1);
        m_labelPlacements[idx].textName = textName;
        m_labelPlacements[idx].time     = time;
        m_labelPlacements[idx].price    = price;
        m_labelPlacementCount++;
    }

    void RemoveLabelPlacement(const string &textName)
    {
        for(int i = 0; i < m_labelPlacementCount; i++)
        {
            if(m_labelPlacements[i].textName != textName)
                continue;
            for(int j = i; j < m_labelPlacementCount - 1; j++)
                m_labelPlacements[j] = m_labelPlacements[j + 1];
            m_labelPlacementCount--;
            ArrayResize(m_labelPlacements, m_labelPlacementCount);
            return;
        }
    }

    void UpdateLabelPlacement(const string &textName, datetime time, double price)
    {
        for(int i = 0; i < m_labelPlacementCount; i++)
        {
            if(m_labelPlacements[i].textName == textName)
            {
                m_labelPlacements[i].time  = time;
                m_labelPlacements[i].price = price;
                return;
            }
        }
    }

    void HandleDraw(VisualCommand &cmd)
    {
        m_diagObjectFind++;   // PHASE_1_5_DIAGNOSTIC
        if(ObjectFind(0, cmd.objName) >= 0)
            return;

        m_diagObjectCreate++;   // PHASE_1_5_DIAGNOSTIC
        bool created;
        if(cmd.objType == OBJ_ARROW || cmd.objType == OBJ_ARROW_DOWN || cmd.objType == OBJ_ARROW_UP || cmd.objType == OBJ_TEXT)
            created = ObjectCreate(0, cmd.objName, cmd.objType, 0, cmd.time1, cmd.price1);
        else
            created = ObjectCreate(0, cmd.objName, cmd.objType, 0, cmd.time1, cmd.price1, cmd.time2, cmd.price2);

        if(!created)
            return;

        if(cmd.objType == OBJ_TREND)
        {
            ObjectSetInteger(0, cmd.objName, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, cmd.objName, OBJPROP_COLOR, cmd.lineColor);
            ObjectSetInteger(0, cmd.objName, OBJPROP_WIDTH, cmd.width > 0 ? cmd.width : 2);
            ObjectSetInteger(0, cmd.objName, OBJPROP_STYLE, cmd.lineStyle > 0 ? cmd.lineStyle : STYLE_SOLID);
        }
        else if(cmd.objType == OBJ_RECTANGLE)
        {
            ObjectSetInteger(0, cmd.objName, OBJPROP_COLOR, cmd.lineColor);
            ObjectSetInteger(0, cmd.objName, OBJPROP_FILL, cmd.isFill ? 1 : 0);
            ObjectSetInteger(0, cmd.objName, OBJPROP_WIDTH, cmd.width > 0 ? cmd.width : 1);
            ObjectSetInteger(0, cmd.objName, OBJPROP_BACK, false);
            ObjectSetInteger(0, cmd.objName, OBJPROP_STYLE, cmd.lineStyle > 0 ? cmd.lineStyle : STYLE_SOLID);
        }
        else if(cmd.objType == OBJ_ARROW)
        {
            ObjectSetInteger(0, cmd.objName, OBJPROP_ARROWCODE, 159);
            ObjectSetInteger(0, cmd.objName, OBJPROP_COLOR, cmd.lineColor);
        }
        else if(cmd.objType == OBJ_ARROW_DOWN || cmd.objType == OBJ_ARROW_UP)
        {
            ObjectSetInteger(0, cmd.objName, OBJPROP_COLOR, cmd.lineColor);
        }

        // Create label if textName provided
        if(cmd.textName != "" && ObjectFind(0, cmd.textName) < 0)
        {
            datetime lblTime = (cmd.labelTime > 0) ? cmd.labelTime : (cmd.time1 + PeriodSeconds(_Period) / 2);
            double lblPrice = (cmd.labelPrice != 0.0) ? cmd.labelPrice : cmd.price1;
            if(ObjectCreate(0, cmd.textName, OBJ_TEXT, 0, lblTime, lblPrice))
            {
                ObjectSetString(0, cmd.textName, OBJPROP_TEXT, cmd.labelText);
                ObjectSetInteger(0, cmd.textName, OBJPROP_COLOR, cmd.textColor);
                ObjectSetInteger(0, cmd.textName, OBJPROP_FONTSIZE, cmd.fontSize > 0 ? cmd.fontSize : 8);
                AddLabelPlacement(cmd.textName, lblTime, lblPrice);   // Track 3: registry sync
            }
        }

        int idx = m_recordCount;
        ArrayResize(m_records, idx + 1);
        m_records[idx].objName     = cmd.objName;
        m_records[idx].textName    = cmd.textName;
        m_records[idx].state       = VISUAL_STATE_ACTIVE;
        m_records[idx].freezeTime  = 0;
        m_records[idx].freezePrice = 0.0;
        m_records[idx].baseColor   = cmd.lineColor;
        m_records[idx].objType     = cmd.objType;
        m_recordCount++;
    }

    void HandleExtend(VisualCommand &cmd)
    {
        //--- Track 3: VSE records are authoritative for engine-owned
        //    objects (Clear/Reset now route through the engine), so the
        //    per-bar ObjectFind guard is dropped: 19 FVG extends/bar was
        //    issuing ~38 terminal object-list lookups/bar. A manually
        //    deleted object merely makes ObjectMove return false.
        int idx = FindRecord(cmd.objName);
        if(idx < 0 || m_records[idx].state != VISUAL_STATE_ACTIVE)
            return;
        ObjectMove(0, cmd.objName, 1, cmd.time2, cmd.price2);
    }

    void HandleFinalize(VisualCommand &cmd)
    {
        if(ObjectFind(0, cmd.objName) < 0)
            return;
        ObjectMove(0, cmd.objName, 1, cmd.time2, cmd.price2);
    }

    void HandleFreeze(VisualCommand &cmd)
    {
        int idx = FindRecord(cmd.objName);
        if(idx < 0)
            return;

        m_records[idx].state       = VISUAL_STATE_FROZEN;
        m_records[idx].freezeTime  = cmd.time2;
        m_records[idx].freezePrice = cmd.price2;

        if(ObjectFind(0, cmd.objName) < 0)
            return;

        ObjectMove(0, cmd.objName, 1, cmd.time2, cmd.price2);
        if(cmd.lineStyle > 0)
            ObjectSetInteger(0, cmd.objName, OBJPROP_STYLE, cmd.lineStyle);
        else
            ObjectSetInteger(0, cmd.objName, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, cmd.objName, OBJPROP_WIDTH, 1);
        if(cmd.lineColor != 0)
            ObjectSetInteger(0, cmd.objName, OBJPROP_COLOR, cmd.lineColor);
        if(cmd.objType == OBJ_RECTANGLE)
            ObjectSetInteger(0, cmd.objName, OBJPROP_FILL, false);

        if(cmd.textName != "" && ObjectFind(0, cmd.textName) >= 0)
        {
            if(cmd.textColor != 0)
                ObjectSetInteger(0, cmd.textName, OBJPROP_COLOR, cmd.textColor);
            if(!cmd.freezeLockLabel)
            {
                ObjectSetInteger(0, cmd.textName, OBJPROP_TIME, cmd.time2);
                ObjectSetDouble(0, cmd.textName, OBJPROP_PRICE, cmd.price2);
                UpdateLabelPlacement(cmd.textName, cmd.time2, cmd.price2);   // Track 3: registry sync
            }
        }
    }

    void HandlePromoteHistorical(VisualCommand &cmd)
    {
        int idx = FindRecord(cmd.objName);
        if(idx < 0)
            return;

        m_records[idx].state = VISUAL_STATE_HISTORICAL;

        if(ObjectFind(0, cmd.objName) < 0)
            return;

        ObjectSetInteger(0, cmd.objName, OBJPROP_STYLE, STYLE_DASHDOT);
        ObjectSetInteger(0, cmd.objName, OBJPROP_WIDTH, 1);
        if(cmd.lineColor != 0)
            ObjectSetInteger(0, cmd.objName, OBJPROP_COLOR, cmd.lineColor);
        if(cmd.objType == OBJ_RECTANGLE)
            ObjectSetInteger(0, cmd.objName, OBJPROP_FILL, false);

        if(cmd.textName != "" && ObjectFind(0, cmd.textName) >= 0)
        {
            if(cmd.textColor != 0)
                ObjectSetInteger(0, cmd.textName, OBJPROP_COLOR, cmd.textColor);
        }
    }

    void HandleDelete(VisualCommand &cmd)
    {
        m_diagObjectFind++;   // PHASE_1_5_DIAGNOSTIC
        if(ObjectFind(0, cmd.objName) >= 0)
        {
            m_diagObjectDelete++;   // PHASE_1_5_DIAGNOSTIC
            ObjectDelete(0, cmd.objName);
        }
        m_diagObjectFind++;   // PHASE_1_5_DIAGNOSTIC
        if(cmd.textName != "")
        {
            if(ObjectFind(0, cmd.textName) >= 0)
            {
                m_diagObjectDelete++;   // PHASE_1_5_DIAGNOSTIC
                ObjectDelete(0, cmd.textName);
            }
            RemoveLabelPlacement(cmd.textName);   // Track 3: registry sync (idempotent)
        }
        RemoveRecord(FindRecord(cmd.objName));
    }

public:
    void Init()
    {
        m_recordCount = 0;
        ArrayResize(m_records, 0);
        m_labelPlacementCount = 0;
        ArrayResize(m_labelPlacements, 0);
        m_diagFindIterations = 0;   // PHASE_1_5_DIAGNOSTIC
        m_diagObjectFind = 0;
        m_diagObjectCreate = 0;
        m_diagObjectDelete = 0;
        m_diagCmdExecuted = 0;
    }

    void Shutdown()
    {
        m_recordCount = 0;
        ArrayResize(m_records, 0);
        m_labelPlacementCount = 0;
        ArrayResize(m_labelPlacements, 0);
    }

    //--- EN-02 (Sprint 24 audit #2): drop every tracked record WITHOUT
    //    shutting the engine down (canonical history reset). Renderers
    //    keep their VSE pointer and keep executing commands afterwards.
    //    Without this, stale pre-reset records win FindRecord() in
    //    HandleExtend/HandleFreeze/HandleDelete after a reset and the
    //    rebuilt active line silently stops extending.
    void Reset()
    {
        m_recordCount = 0;
        ArrayResize(m_records, 0);
        m_labelPlacementCount = 0;
        ArrayResize(m_labelPlacements, 0);
    }

    void ExecuteBatch(VisualCommand &cmds[], int count)
    {
        for(int i = 0; i < count; i++)
        {
            m_diagCmdExecuted++;   // PHASE_1_5_DIAGNOSTIC
            VisualCommand cmd = cmds[i];
            switch(cmd.type)
            {
                case CMD_DRAW:               HandleDraw(cmd);               break;
                case CMD_EXTEND:             HandleExtend(cmd);             break;
                case CMD_FINALIZE:           HandleFinalize(cmd);           break;
                case CMD_FREEZE:             HandleFreeze(cmd);             break;
                case CMD_PROMOTE_HISTORICAL: HandlePromoteHistorical(cmd);  break;
                case CMD_DELETE:             HandleDelete(cmd);             break;
            }
        }
    }

    void Execute(VisualCommand &cmd)
    {
        VisualCommand cmds[1];
        cmds[0] = cmd;
        ExecuteBatch(cmds, 1);
    }

    //--- Track 3: in-memory label placement. Algorithm-identical to the
    //    removed ChartUtils::ResolveLabelPrice (2-hour window, step,
    //    direction, 10-iteration cap) but the collision domain is the
    //    VSE label registry instead of a full ObjectsTotal() chart scan.
    double ResolveLabelPlacement(datetime time, double basePrice, double step, int direction = 1)
    {
        double candidate = basePrice;
        for(int iteration = 0; iteration < 10; iteration++)
        {
            bool collision = false;
            for(int i = 0; i < m_labelPlacementCount; i++)
            {
                if(MathAbs(m_labelPlacements[i].time - time) > 7200)
                    continue;
                if(MathAbs(m_labelPlacements[i].price - candidate) < step)
                {
                    collision = true;
                    if(direction == 0)
                    {
                        if(iteration < 5)
                            candidate += step * (iteration + 1);
                        else
                            candidate = basePrice - step * (iteration - 4);
                    }
                    else
                        candidate += direction * step * (iteration + 1);
                    break;
                }
            }
            if(!collision)
                return candidate;
        }
        return candidate;
    }

    //--- Track 3: prefix clear routed through the VSE so chart objects,
    //    VSE records and the label registry stay in sync. Keeps the
    //    legacy chart-level sweep (stray untracked objects with the
    //    prefix are removed too — Clear() is event-only, never per-bar)
    //    and additionally drops the matching engine records/registry
    //    entries that the old ChartUtils free function orphaned.
    void DeleteObjectsByPrefix(const string &prefix)
    {
        int total = ObjectsTotal(0);
        for(int i = total - 1; i >= 0; i--)
        {
            string objName = ObjectName(0, i);
            if(StringFind(objName, prefix) == 0)
                ObjectDelete(0, objName);
        }
        for(int i = m_recordCount - 1; i >= 0; i--)
        {
            bool matchObj  = StringFind(m_records[i].objName, prefix) == 0;
            bool matchText = m_records[i].textName != "" && StringFind(m_records[i].textName, prefix) == 0;
            if(!matchObj && !matchText)
                continue;
            if(m_records[i].textName != "")
                RemoveLabelPlacement(m_records[i].textName);
            RemoveRecord(i);
        }
    }

    //--- PHASE_1_5_DIAGNOSTIC: one-shot aggregate report (self-resetting)
    string GetDiagAndReset(void)
    {
        string s = StringFormat("VSE records=%d cmds=%d findCalls=%d findIter=%d objCreate=%d objDelete=%d",
                                m_recordCount, (long)m_diagCmdExecuted,
                                (long)m_diagObjectFind, (long)m_diagFindIterations,
                                (long)m_diagObjectCreate, (long)m_diagObjectDelete);
        m_diagFindIterations = 0;
        m_diagObjectFind = 0;
        m_diagObjectCreate = 0;
        m_diagObjectDelete = 0;
        m_diagCmdExecuted = 0;
        return s;
    }

    EVisualState GetState(const string &name)
    {
        int idx = FindRecord(name);
        if(idx < 0)
            return VISUAL_STATE_ACTIVE;
        return m_records[idx].state;
    }

    bool IsActive(const string &name)
    {
        return GetState(name) == VISUAL_STATE_ACTIVE;
    }

    bool IsFrozen(const string &name)
    {
        return GetState(name) == VISUAL_STATE_FROZEN;
    }

    bool IsHistorical(const string &name)
    {
        return GetState(name) == VISUAL_STATE_HISTORICAL;
    }
};

#endif // __VISUAL_STATE_ENGINE_MQH__
