//+------------------------------------------------------------------+
//|                                          VisualDiagnostic.mqh     |
//|                   Runtime chart object validator against v2.0 spec|
//+------------------------------------------------------------------+
#ifndef __VISUAL_DIAGNOSTIC_MQH__
#define __VISUAL_DIAGNOSTIC_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Core/Logger.mqh"
#include "ChartObjectNames.mqh"
#include "ChartStyle.mqh"
#include "VisualStateEngine.mqh"

enum ENUM_DIAG_MODE
{
    DIAG_DUMP_ALL,        // Dump every SCX object with full properties
    DIAG_SPEC_VALIDATE,   // Validate against spec expectations
    DIAG_STATE_ONLY       // Only dump VSE internal state
};

input ENUM_DIAG_MODE VisualDiagnosticMode = DIAG_DUMP_ALL;
input int            VisualDiagnosticFreq = 100;  // Run every N bars

class CVisualDiagnostic
{
private:
    CLogger         m_logger;
    int             m_lastCheckBar;
    CVisualStateEngine *m_vse;

    string SpecTypeName(ENUM_OBJECT type)
    {
        switch(type)
        {
            case OBJ_TREND:     return "OBJ_TREND";
            case OBJ_RECTANGLE: return "OBJ_RECTANGLE";
            case OBJ_ARROW:     return "OBJ_ARROW";
            case OBJ_ARROW_DOWN:return "OBJ_ARROW_DOWN";
            case OBJ_ARROW_UP:  return "OBJ_ARROW_UP";
            case OBJ_TEXT:      return "OBJ_TEXT";
            default:            return "UNKNOWN";
        }
    }

    string SpecColorName(color c)
    {
        if(c == COLOR_SWING_HIGH)            return "COLOR_SWING_HIGH";
        if(c == COLOR_SWING_LOW)             return "COLOR_SWING_LOW";
        if(c == COLOR_PIVOT)                 return "COLOR_PIVOT";
        if(c == COLOR_PIVOT_PROTECTED_HIGH)  return "COLOR_PIVOT_PROTECTED_HIGH";
        if(c == COLOR_PIVOT_PROTECTED_LOW)   return "COLOR_PIVOT_PROTECTED_LOW";
        if(c == COLOR_BOS_BULLISH)           return "COLOR_BOS_BULLISH";
        if(c == COLOR_BOS_BEARISH)           return "COLOR_BOS_BEARISH";
        if(c == COLOR_CHOCH)                 return "COLOR_CHOCH";
        if(c == COLOR_OB)                    return "COLOR_OB";
        if(c == COLOR_FVG)                   return "COLOR_FVG";
        if(c == COLOR_PROTECTED_HIGH)        return "COLOR_PROTECTED_HIGH";
        if(c == COLOR_PROTECTED_LOW)         return "COLOR_PROTECTED_LOW";
        if(c == COLOR_BOS_BULLISH_FROZEN)    return "COLOR_BOS_BULLISH_FROZEN";
        if(c == COLOR_BOS_BEARISH_FROZEN)    return "COLOR_BOS_BEARISH_FROZEN";
        if(c == COLOR_CHOCH_FROZEN)          return "COLOR_CHOCH_FROZEN";
        if(c == COLOR_PROTECTED_HIGH_FROZEN) return "COLOR_PROTECTED_HIGH_FROZEN";
        if(c == COLOR_PROTECTED_LOW_FROZEN)  return "COLOR_PROTECTED_LOW_FROZEN";
        if(c == COLOR_OB_FROZEN)             return "COLOR_OB_FROZEN";
        if(c == COLOR_FVG_FROZEN)            return "COLOR_FVG_FROZEN";
        if(c == COLOR_BOS_BULLISH_HIST)      return "COLOR_BOS_BULLISH_HIST";
        if(c == COLOR_BOS_BEARISH_HIST)      return "COLOR_BOS_BEARISH_HIST";
        if(c == COLOR_CHOCH_HIST)            return "COLOR_CHOCH_HIST";
        if(c == COLOR_PROTECTED_HIGH_HIST)   return "COLOR_PROTECTED_HIGH_HIST";
        if(c == COLOR_PROTECTED_LOW_HIST)    return "COLOR_PROTECTED_LOW_HIST";
        if(c == COLOR_FVG_HIST)              return "COLOR_FVG_HIST";
        return StringFormat("0x%06X", c);
    }

    string StyleName(int style)
    {
        switch(style)
        {
            case STYLE_SOLID:   return "STYLE_SOLID";
            case STYLE_DASH:    return "STYLE_DASH";
            case STYLE_DASHDOT: return "STYLE_DASHDOT";
            case STYLE_DOT:     return "STYLE_DOT";
            default:            return StringFormat("STYLE_%d", style);
        }
    }

    bool IsTrendLine(const string &name)
    {
        return StringFind(name, "_LINE_") >= 0;
    }

    bool IsRect(const string &name)
    {
        return StringFind(name, "_RECT_") >= 0;
    }

    bool IsArrow(const string &name)
    {
        return StringFind(name, "SWING_HIGH") >= 0
            || StringFind(name, "SWING_LOW") >= 0
            || StringFind(name, "_PIVOT_") >= 0;
    }

    bool IsText(const string &name)
    {
        return StringFind(name, "_TEXT_") >= 0;
    }

public:
    CVisualDiagnostic(void)
        : m_logger(MODULE_VISUALIZATION_MANAGER, "VisDiag")
        , m_lastCheckBar(-1)
        , m_vse(NULL) {}

    void SetVSE(CVisualStateEngine *vse)
    {
        m_vse = vse;
    }

    void Check(void)
    {
        if(!m_vse)
        {
            m_logger.LogError("VSE not set");
            return;
        }

        int currentBar = iBars(_Symbol, _Period);
        if(currentBar == m_lastCheckBar)
            return;
        if(VisualDiagnosticFreq > 0 && (currentBar % VisualDiagnosticFreq) != 0)
            return;
        m_lastCheckBar = currentBar;

        m_logger.LogInfo("========== Visual Diagnostic ==========");
        m_logger.LogInfo(StringFormat("Bars=%d  Mode=%d", currentBar, VisualDiagnosticMode));

        int total = ObjectsTotal(0);
        int scxCount = 0;
        for(int i = 0; i < total; i++)
        {
            string name = ObjectName(0, i);
            if(StringFind(name, "SCX_") != 0)
                continue;
            scxCount++;

            ENUM_OBJECT objType = (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE);
            datetime time1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
            double price1  = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
            datetime time2 = 0;
            double price2  = 0.0;
            if(objType == OBJ_TREND || objType == OBJ_RECTANGLE)
            {
                time2  = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
                price2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
            }
            color lineColor = (color)ObjectGetInteger(0, name, OBJPROP_COLOR);
            int lineStyle   = (int)ObjectGetInteger(0, name, OBJPROP_STYLE);
            int lineWidth   = (int)ObjectGetInteger(0, name, OBJPROP_WIDTH);
            int backSetting = (int)ObjectGetInteger(0, name, OBJPROP_BACK);

            string log = StringFormat("[%s] TYPE=%s TIME1=%s PRICE1=%.5f",
                name, SpecTypeName(objType), TimeToString(time1), price1);

            if(time2 > 0)
            {
                log += StringFormat(" TIME2=%s PRICE2=%.5f",
                    TimeToString(time2), price2);
            }

            log += StringFormat(" COLOR=%s STYLE=%s WIDTH=%d BACK=%d",
                SpecColorName(lineColor), StyleName(lineStyle), lineWidth, backSetting);

            if(objType == OBJ_ARROW)
            {
                int arrowCode = (int)ObjectGetInteger(0, name, OBJPROP_ARROWCODE);
                log += StringFormat(" ARROWCODE=%d", arrowCode);
            }
            if(objType == OBJ_RECTANGLE)
            {
                int fill = (int)ObjectGetInteger(0, name, OBJPROP_FILL);
                log += StringFormat(" FILL=%d", fill);
            }
            if(objType == OBJ_TREND)
            {
                int rayRight = (int)ObjectGetInteger(0, name, OBJPROP_RAY_RIGHT);
                log += StringFormat(" RAY_RIGHT=%d", rayRight);
            }

            // Lifecycle state from VSE
            if(m_vse)
            {
                EVisualState vs = m_vse.GetState(name);
                string stateStr = "?";
                if(vs == VISUAL_STATE_ACTIVE)     stateStr = "ACTIVE";
                else if(vs == VISUAL_STATE_FROZEN) stateStr = "FROZEN";
                else if(vs == VISUAL_STATE_HISTORICAL) stateStr = "HISTORICAL";
                log += StringFormat(" VSE_STATE=%s", stateStr);
            }

            // Check for text label companion
            if(IsTrendLine(name) || IsRect(name))
            {
                string textName = name;
                StringReplace(textName, "_LINE_", "_TEXT_");
                StringReplace(textName, "_RECT_", "_TEXT_");
                if(ObjectFind(0, textName) >= 0)
                {
                    string text = ObjectGetString(0, textName, OBJPROP_TEXT);
                    color textColor = (color)ObjectGetInteger(0, textName, OBJPROP_COLOR);
                    datetime textTime = (datetime)ObjectGetInteger(0, textName, OBJPROP_TIME);
                    double textPrice = ObjectGetDouble(0, textName, OBJPROP_PRICE);
                    log += StringFormat(" | TEXT[%s]='%s' T=%s P=%.5f C=%s",
                        textName, text, TimeToString(textTime), textPrice, SpecColorName(textColor));
                }
            }

            m_logger.LogInfo(log);
        }

        if(scxCount == 0)
            m_logger.LogError("NO SCX OBJECTS ON CHART");

        m_logger.LogInfo(StringFormat("Total SCX objects: %d", scxCount));
        m_logger.LogInfo("========== End Diagnostic ==========");
    }
};

#endif // __VISUAL_DIAGNOSTIC_MQH__
