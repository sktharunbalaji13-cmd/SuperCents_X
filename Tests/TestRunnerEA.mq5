#property strict

#include "TestSuite.mqh"

int OnInit(void)
{
    RunAllSuperCentsTests();
    ExpertRemove();
    return INIT_SUCCEEDED;
}

void OnTick(void)
{
}

void OnDeinit(const int reason)
{
}
