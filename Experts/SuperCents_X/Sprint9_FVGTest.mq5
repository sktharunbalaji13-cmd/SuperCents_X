//+------------------------------------------------------------------+
//|                                   Sprint9_FVGTest_EA.mq5          |
//|       Sprint 9.1 - EA Runner for FVG Synthetic Test Harness       |
//+------------------------------------------------------------------+
#property strict

#define RUNNING_AS_EA

#include "../../Scripts/SuperCents_X/Sprint9_FVGTest.mq5"

int OnInit(void)
{
    RunAllTests();
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    Print("Sprint 9.1 EA runner deinitialized (reason=" + IntegerToString(reason) + ")");
}
