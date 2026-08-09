//+------------------------------------------------------------------+
//|                                               ChartUtils.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __CHART_UTILS_MQH__
#define __CHART_UTILS_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"

double ResolveLabelPrice(datetime time, double basePrice, double step, int direction = 1)
{
    double candidate = basePrice;
    for(int iteration = 0; iteration < 10; iteration++)
    {
        bool collision = false;
        for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
        {
            string objName = ObjectName(0, i);
            if(ObjectGetInteger(0, objName, OBJPROP_TYPE) != OBJ_TEXT)
                continue;
            if(MathAbs((datetime)ObjectGetInteger(0, objName, OBJPROP_TIME) - time) > 7200)
                continue;
            if(MathAbs(ObjectGetDouble(0, objName, OBJPROP_PRICE) - candidate) < step)
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

void DeleteObjectsByPrefix(const string &prefix)
{
    int total = ObjectsTotal(0);
    for(int i = total - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i);
        if(StringFind(objName, prefix) == 0)
        {
            ObjectDelete(0, objName);
        }
    }
}

#endif // __CHART_UTILS_MQH__
