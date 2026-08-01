#property strict
#property script_show_inputs

#include "Benchmarks.mqh"

void OnStart(void)
{
    RunAllBenchmarks("baseline_v2.9.txt");
}
