//+------------------------------------------------------------------+
//|                                          ChartObjectNames.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __CHART_OBJECT_NAMES_MQH__
#define __CHART_OBJECT_NAMES_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"

string SwingHighName(int swingID)
{
    return StringFormat("SCX_SWING_HIGH_%d", swingID);
}

string SwingLowName(int swingID)
{
    return StringFormat("SCX_SWING_LOW_%d", swingID);
}

string PivotName(int pivotID)
{
    return StringFormat("SCX_PIVOT_%d", pivotID);
}

string BOSLineName(int bosID)
{
    return StringFormat("SCX_BOS_LINE_%d", bosID);
}

string BOSTextName(int bosID)
{
    return StringFormat("SCX_BOS_TEXT_%d", bosID);
}

string CHOCHLineName(int chochID)
{
    return StringFormat("SCX_CHOCH_LINE_%d", chochID);
}

string CHOCHTextName(int chochID)
{
    return StringFormat("SCX_CHOCH_TEXT_%d", chochID);
}

string PPLineName(int ppID)
{
    return StringFormat("SCX_PP_LINE_%d", ppID);
}

string PPTextName(int ppID)
{
    return StringFormat("SCX_PP_TEXT_%d", ppID);
}

string OBRectName(int obID)
{
    return StringFormat("SCX_OB_RECT_%d", obID);
}

string OBTextName(int obID)
{
    return StringFormat("SCX_OB_TEXT_%d", obID);
}

string FVGRectName(int fvgID)
{
    return StringFormat("SCX_FVG_RECT_%d", fvgID);
}

string FVGTextName(int fvgID)
{
    return StringFormat("SCX_FVG_TEXT_%d", fvgID);
}

#endif // __CHART_OBJECT_NAMES_MQH__
