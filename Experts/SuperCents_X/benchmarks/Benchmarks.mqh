#ifndef __BENCHMARKS_MQH__
#define __BENCHMARKS_MQH__

#include "BenchmarkTypes.mqh"
#include "BenchmarkWalkForward.mqh"
#include "BenchmarkMonteCarlo.mqh"
#include "BenchmarkRegression.mqh"
#include "BenchmarkReportComposer.mqh"
#include "BenchmarkConfluence.mqh"
#include "EntryBenchmarks.mqh"

//--- Run every benchmark suite once and write the results file.
//    Returns the total number of benchmarks executed.
int RunAllBenchmarks(const string fileName)
{
    Print("");
    Print("==========================================");
    Print("  Validation Lab — Performance Benchmarks");
    Print("==========================================");
    Print("");

    string baselineLines[];
    ArrayResize(baselineLines, 400);
    int lineIdx = 0;

    int totalBenchmarks = 0;

    totalBenchmarks += RunWalkForwardBenchmarks(baselineLines, lineIdx);
    totalBenchmarks += RunMonteCarloBenchmarks(baselineLines, lineIdx);
    totalBenchmarks += RunRegressionBenchmarks(baselineLines, lineIdx);
    totalBenchmarks += RunReportComposerBenchmarks(baselineLines, lineIdx);
    totalBenchmarks += RunConfluenceBenchmarks(baselineLines, lineIdx);
    totalBenchmarks += RunEntryBenchmarks(baselineLines, lineIdx);

    Print("");
    Print("==========================================");
    Print("  TOTAL: " + IntegerToString(totalBenchmarks) + " benchmarks");
    Print("==========================================");

    string baseline = BuildHeader() + "\n";
    for(int i = 0; i < lineIdx; i++)
        baseline += baselineLines[i] + "\n";

    int handle = FileOpen(fileName, FILE_TXT|FILE_WRITE);
    if(handle != INVALID_HANDLE)
    {
        FileWriteString(handle, baseline);
        FileClose(handle);
        Print("Baseline written to: MQL5/Files/" + fileName);
    }
    else
    {
        Print("WARN: Could not write baseline file " + fileName);
    }

    Print("==========================================");
    return totalBenchmarks;
}

#endif
