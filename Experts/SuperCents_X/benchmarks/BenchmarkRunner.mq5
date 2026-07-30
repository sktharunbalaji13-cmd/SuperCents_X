#property strict
#property script_show_inputs

#include "BenchmarkTypes.mqh"
#include "BenchmarkWalkForward.mqh"
#include "BenchmarkMonteCarlo.mqh"
#include "BenchmarkRegression.mqh"
#include "BenchmarkReportComposer.mqh"

void OnStart(void)
{
    Print("");
    Print("==========================================");
    Print("  Validation Lab — Performance Benchmarks");
    Print("==========================================");
    Print("");

    string baselineLines[];
    ArrayResize(baselineLines, 200);
    int lineIdx = 0;

    int totalBenchmarks = 0;

    totalBenchmarks += RunWalkForwardBenchmarks(baselineLines, lineIdx);
    totalBenchmarks += RunMonteCarloBenchmarks(baselineLines, lineIdx);
    totalBenchmarks += RunRegressionBenchmarks(baselineLines, lineIdx);
    totalBenchmarks += RunReportComposerBenchmarks(baselineLines, lineIdx);

    Print("");
    Print("==========================================");
    Print("  TOTAL: " + IntegerToString(totalBenchmarks) + " benchmarks");
    Print("==========================================");

    string baseline = BuildHeader() + "\n";
    for(int i = 0; i < lineIdx; i++)
        baseline += baselineLines[i] + "\n";

    int handle = FileOpen("baseline_v2.7.txt", FILE_TXT|FILE_WRITE);
    if(handle != INVALID_HANDLE)
    {
        FileWriteString(handle, baseline);
        FileClose(handle);
        Print("Baseline written to: MQL5/Files/baseline_v2.7.txt");
    }
    else
    {
        Print("WARN: Could not write baseline file");
    }

    Print("==========================================");
}
