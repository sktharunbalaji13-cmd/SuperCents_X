#ifndef __WALK_FORWARD_SCHEDULE_MQH__
#define __WALK_FORWARD_SCHEDULE_MQH__

#include "WalkForwardTypes.mqh"

struct WalkForwardSchedule
{
    WalkForwardScheduleConfig   config;
    WfExecutionWindow           windows[];
    int                         windowCount;
    datetime                    generatedAt;
    ScheduleWarning             warnings[];
    int                         warningCount;

    WalkForwardSchedule(void)
        : windowCount(0)
        , generatedAt(0)
        , warningCount(0)
    {}
};

#endif
