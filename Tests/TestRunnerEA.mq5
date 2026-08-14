#property strict

#include "TestSuite.mqh"

int OnInit(void)
{
    Print(">>> BUILD 25A-RUNTIME-01 tag=\"" + TimeToString(__DATETIME__, TIME_DATE | TIME_MINUTES | TIME_SECONDS) + "\" term="
        + IntegerToString(TerminalInfoInteger(TERMINAL_BUILD))
        + " path=" + MQLInfoString(MQL_PROGRAM_PATH));
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
