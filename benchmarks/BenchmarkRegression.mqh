#include "../Validation/RegressionDetector.mqh"
#include "../Validation/RegressionTypes.mqh"
#include "BenchmarkTypes.mqh"

int RunRegressionBenchmarks(string &lines[], int &lineIdx)
{
    int totalBenchmarks = 0;

    SUITE_BENCH("Regression Benchmarks");

    int warmup = BENCH_WARMUP;
    int measured = BENCH_MEASURED;
    int metricCounts[4] = {1, 5, 11, 25};

    ValidationResult base, curr;
    base.strategyReport.profitFactor = 2.0;
    base.strategyReport.sharpeRatio = 1.5;
    base.strategyReport.totalNetProfit = 5000.0;
    base.strategyReport.maxDrawdownPercent = 15.0;
    base.strategyReport.winRate = 60.0;
    base.strategyReport.expectancy = 50.0;
    base.strategyReport.totalTrades = 200;
    base.strategyReport.avgRRAchieved = 2.5;
    base.strategyReport.recoveryFactor = 3.0;
    base.strategyReport.sortinoRatio = 2.0;
    base.strategyReport.calmarRatio = 1.0;

    curr = base;
    curr.strategyReport.profitFactor = 1.4;
    curr.strategyReport.totalNetProfit = 3500.0;

    for(int mi = 0; mi < 4; mi++)
    {
        int metricCount = metricCounts[mi];

        RegressionConfig cfg;
        cfg.configVersion = 1;
        cfg.thresholdCount = metricCount;
        ArrayResize(cfg.thresholds, metricCount);
        for(int i = 0; i < metricCount; i++)
        {
            cfg.thresholds[i].dimension = (ENUM_REGRESSION_DIMENSION)(i % 11);
            cfg.thresholds[i].warnPercent = 10.0;
            cfg.thresholds[i].failPercent = 25.0;
            cfg.thresholds[i].higherIsBetter = (i != (int)REG_DIM_MAX_DRAWDOWN);
        }

        string label = StringFormat("Regression.%dMetrics", metricCount);
        BenchmarkResult br;
        br.Init(label, warmup, measured, metricCount, "comparisons");

        for(int run = 0; run < warmup + measured; run++)
        {
            CRegressionDetector det;
            det.Init(cfg);
            RegressionSummary summary;
            ulong t0 = GetMicrosecondCount();
            det.Execute(base, curr, summary);
            ulong t1 = GetMicrosecondCount();
            br.AddMeasurement(t1 - t0);
        }

        if(br.Compute())
        {
            br.PrintResult();
            lines[lineIdx] = br.ToBaselineLine();
            lineIdx++;
            totalBenchmarks++;
        }
    }

    SUITE_BENCH_END("Regression Benchmarks");
    return totalBenchmarks;
}
