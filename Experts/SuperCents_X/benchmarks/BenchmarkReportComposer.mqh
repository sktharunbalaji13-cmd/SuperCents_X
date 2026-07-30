#include "../Validation/ValidationReportComposer.mqh"
#include "../Validation/ReportTypes.mqh"
#include "../Validation/WalkForwardTypes.mqh"
#include "../Validation/MonteCarloTypes.mqh"
#include "../Validation/RegressionTypes.mqh"
#include "BenchmarkTypes.mqh"

void PopulateMCStatistics(MonteCarloStatistics &st, double probLoss)
{
    st.meanProfit = 500.0;
    st.medianProfit = 450.0;
    st.stdDevProfit = 1200.0;
    st.p95Profit = 3000.0;
    st.p99Profit = 5000.0;
    st.probabilityOfLoss = probLoss;
    st.isSignificant = true;
    st.sufficientIterations = true;
    st.usedIterations = 10000;
}

int RunReportComposerBenchmarks(string &lines[], int &lineIdx)
{
    int totalBenchmarks = 0;

    SUITE_BENCH("ReportComposer Benchmarks");

    int warmup = BENCH_WARMUP;
    int measured = BENCH_MEASURED;

    ValidationResult vr;
    vr.manifest.validationId = "BENCHMARK-001";
    vr.manifest.eaVersion = "2.7.0";
    vr.manifest.gitCommit = "abc1234";
    vr.manifest.symbolTested = "EURUSD";
    vr.manifest.timeframeTested = "H1";

    ValidationReport report;

    // Scenario 1: Empty (no optional summaries)
    {
        WalkForwardSummary emptyWF;
        MonteCarloSummary emptyMC;
        RegressionSummary emptyReg;

        string label = "ReportComposer.Empty";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 0, "reports");

        for(int run = 0; run < warmup + measured; run++)
        {
            CValidationReportComposer comp;
            comp.Init();
            ulong t0 = GetMicrosecondCount();
            comp.Compose(vr, emptyWF, emptyMC, emptyReg, report);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute())
        {
            br.throughputUnit = "reports";
            br.PrintResult();
            Print("    Text size: " + IntegerToString(StringLen(report.formattedText)) + " bytes");
            lines[lineIdx] = br.ToBaselineLine();
            lineIdx++;
            totalBenchmarks++;
        }
    }

    // Scenario 2: Typical (all summaries populated)
    {
        WalkForwardSummary wf;
        wf.totalWindows = 10;
        wf.validWindows = 9;
        wf.experimentLabel = "WF-ROL-2020.01.01-2021.01.01";
        wf.completedSuccessfully = true;
        ArrayResize(wf.results, 10);
        for(int i = 0; i < 10; i++)
        {
            wf.results[i].window = WfExecutionWindow();
            wf.results[i].window.windowId = "WF-BENCH-" + StringFormat("%04d", i);
            wf.results[i].window.windowIndex = i;
            wf.results[i].status = (i < 9) ? WINDOW_PASS : WINDOW_FAIL_SCHEDULE;
        }

        MonteCarloSummary mc;
        mc.totalRuns = 100;
        mc.completedRuns = 100;
        mc.originalProfit = 5000.0;
        mc.completedSuccessfully = true;
        PopulateMCStatistics(mc.statistics, 0.35);

        RegressionSummary reg;
        reg.totalChecks = 11;
        reg.passedChecks = 9;
        reg.failedChecks = 1;
        reg.warnedChecks = 1;
        reg.insufficientChecks = 0;
        reg.baselineValidationId = "BASE-001";
        reg.currentValidationId = "CURR-001";
        ArrayResize(reg.findings, 11);
        for(int i = 0; i < 11; i++)
        {
            reg.findings[i].dimension = (ENUM_REGRESSION_DIMENSION)i;
            reg.findings[i].baselineValue = 100.0;
            reg.findings[i].currentValue = (i < 2) ? 80.0 : 95.0;
            reg.findings[i].deltaPercent = (i < 2) ? -20.0 : -5.0;
        }

        string label = "ReportComposer.Typical";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 0, "reports");

        for(int run = 0; run < warmup + measured; run++)
        {
            CValidationReportComposer comp;
            comp.Init();
            ulong t0 = GetMicrosecondCount();
            comp.Compose(vr, wf, mc, reg, report);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute())
        {
            br.throughputUnit = "reports";
            br.PrintResult();
            Print("    Text size: " + IntegerToString(StringLen(report.formattedText)) + " bytes");
            lines[lineIdx] = br.ToBaselineLine();
            lineIdx++;
            totalBenchmarks++;
        }
    }

    // Scenario 3: Large (large text results to stress formatting)
    {
        WalkForwardSummary wf;
        wf.totalWindows = 50;
        wf.validWindows = 45;
        wf.experimentLabel = "WF-ROL-2018.01.01-2022.01.01";
        wf.completedSuccessfully = true;
        ArrayResize(wf.results, 50);
        for(int i = 0; i < 50; i++)
        {
            wf.results[i].window = WfExecutionWindow();
            wf.results[i].window.windowId = "WF-LARGE-" + StringFormat("%04d", i);
            wf.results[i].window.windowIndex = i;
            wf.results[i].status = (i < 45) ? WINDOW_PASS : WINDOW_FAIL_EXECUTION;
        }

        MonteCarloSummary mc;
        mc.totalRuns = 10000;
        mc.completedRuns = 10000;
        mc.originalProfit = 5000.0;
        mc.completedSuccessfully = true;
        PopulateMCStatistics(mc.statistics, 0.40);

        RegressionSummary reg;
        reg.totalChecks = 11;
        reg.passedChecks = 7;
        reg.failedChecks = 2;
        reg.warnedChecks = 2;
        reg.insufficientChecks = 0;
        reg.baselineValidationId = "BASE-LARGE-001";
        reg.currentValidationId = "CURR-LARGE-001";
        ArrayResize(reg.findings, 11);
        for(int i = 0; i < 11; i++)
        {
            reg.findings[i].dimension = (ENUM_REGRESSION_DIMENSION)i;
            reg.findings[i].baselineValue = 100.0;
            reg.findings[i].currentValue = 85.0;
            reg.findings[i].deltaPercent = -15.0;
        }

        string label = "ReportComposer.Large";
        BenchmarkResult br;
        br.Init(label, warmup, measured, 0, "reports");

        for(int run = 0; run < warmup + measured; run++)
        {
            CValidationReportComposer comp;
            comp.Init();
            ulong t0 = GetMicrosecondCount();
            comp.Compose(vr, wf, mc, reg, report);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute())
        {
            br.throughputUnit = "reports";
            br.PrintResult();
            Print("    Text size: " + IntegerToString(StringLen(report.formattedText)) + " bytes");
            lines[lineIdx] = br.ToBaselineLine();
            lineIdx++;
            totalBenchmarks++;
        }
    }

    SUITE_BENCH_END("ReportComposer Benchmarks");
    return totalBenchmarks;
}
