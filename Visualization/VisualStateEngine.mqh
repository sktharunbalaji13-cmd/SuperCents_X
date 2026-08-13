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

class CVisualStateEngine
{
private:
    VisualStateRecord m_records[];
    int               m_recordCount;

    int FindRecord(const string &name)
    {
        for(int i = 0; i < m_recordCount; i++)
            if(m_records[i].objName == name)
                return i;
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

    void HandleDraw(VisualCommand &cmd)
    {
        if(ObjectFind(0, cmd.objName) >= 0)
            return;

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
        int idx = FindRecord(cmd.objName);
        if(idx < 0 || m_records[idx].state != VISUAL_STATE_ACTIVE)
            return;
        if(ObjectFind(0, cmd.objName) < 0)
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
        if(ObjectFind(0, cmd.objName) >= 0)
            ObjectDelete(0, cmd.objName);
        if(cmd.textName != "" && ObjectFind(0, cmd.textName) >= 0)
            ObjectDelete(0, cmd.textName);
        RemoveRecord(FindRecord(cmd.objName));
    }

public:
    void Init()
    {
        m_recordCount = 0;
        ArrayResize(m_records, 0);
    }

    void Shutdown()
    {
        m_recordCount = 0;
        ArrayResize(m_records, 0);
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
    }

    void ExecuteBatch(VisualCommand &cmds[], int count)
    {
        for(int i = 0; i < count; i++)
        {
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
