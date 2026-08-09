//+------------------------------------------------------------------+
//|                                       VF01_AuditSelfTest.mq5      |
//|                    Sprint 20 - VF01: headless runner for the      |
//|                    VF01 audit self-tests (tester-friendly EA      |
//|                    wrapper around VF01_AuditSelfTest.mqh).        |
//|                                                                  |
//| Not an EA - runs the self-test once in OnInit and stops.         |
//+------------------------------------------------------------------+
#property strict

#include "../../../Scripts/SuperCents_X/VF01_AuditSelfTest.mqh"

int OnInit(void)
{
    RunSelfTest();
    return INIT_SUCCEEDED;
}

void OnTick(void)
{
    ExpertRemove();
}
