//+------------------------------------------------------------------+
//|                                       BenchmarkRunnerEA.mq5       |
//|                                      Copyright 2026, SuperCents_X|
//|                   Headless EA entry for the Validation Lab       |
//|                   performance benchmarks (Sprint 14 / v2.9).     |
//+------------------------------------------------------------------+
#property strict

#include "Benchmarks.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    RunAllBenchmarks("baseline_v2.9.txt");
    ExpertRemove();
    return INIT_SUCCEEDED;
}
