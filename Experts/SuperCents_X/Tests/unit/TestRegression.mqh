#include "../../Validation/RegressionDetector.mqh"
#include "../TestAssert.mqh"

TestCounters RunRegressionTests(void)
{
    TestCounters counters;

    SUITE_BEGIN("Regression Unit Tests");

    ValidationResult baseline, current;

    // Test 1: Identical baseline → all PASS
    {
        baseline.strategyReport.profitFactor = 2.0;
        baseline.strategyReport.sharpeRatio = 1.5;
        baseline.strategyReport.totalNetProfit = 5000.0;
        baseline.strategyReport.maxDrawdownPercent = 15.0;
        baseline.strategyReport.winRate = 60.0;
        baseline.strategyReport.expectancy = 50.0;
        baseline.strategyReport.totalTrades = 200;
        baseline.strategyReport.avgRRAchieved = 2.5;
        baseline.strategyReport.recoveryFactor = 3.0;
        baseline.strategyReport.sortinoRatio = 2.0;
        baseline.strategyReport.calmarRatio = 1.0;

        current = baseline;

        RegressionConfig cfg;
        cfg.configVersion = 1;
        cfg.thresholdCount = 11;
        ArrayResize(cfg.thresholds, 11);
        for(int i = 0; i < 11; i++)
        {
            RegressionThreshold t;
            t.dimension = (ENUM_REGRESSION_DIMENSION)i;
            t.warnPercent = 10.0;
            t.failPercent = 25.0;
            t.higherIsBetter = (i != REG_DIM_MAX_DRAWDOWN);
            cfg.thresholds[i] = t;
        }

        CRegressionDetector det;
        det.Init(cfg);
        RegressionSummary summary;
        bool ok = det.Execute(baseline, current, summary);

        TEST_TRUE(ok, "Regression should succeed with identical inputs");
        TEST_INT_EQ(11, summary.totalChecks, "All 11 dimensions checked");
        TEST_INT_EQ(11, summary.passedChecks, "All pass with identical baseline+current");
        TEST_INT_EQ(0, summary.failedChecks, "No failures");
        TEST_INT_EQ(0, summary.warnedChecks, "No warnings");
    }

    // Test 2: Large degradation → FAIL
    {
        baseline.strategyReport.profitFactor = 2.0;
        current.strategyReport.profitFactor = 1.0;

        RegressionConfig cfg;
        cfg.thresholdCount = 1;
        ArrayResize(cfg.thresholds, 1);
        cfg.thresholds[0].dimension = REG_DIM_PROFIT_FACTOR;
        cfg.thresholds[0].warnPercent = 10.0;
        cfg.thresholds[0].failPercent = 25.0;
        cfg.thresholds[0].higherIsBetter = true;

        CRegressionDetector det;
        det.Init(cfg);
        RegressionSummary summary;
        det.Execute(baseline, current, summary);

        TEST_INT_EQ(1, summary.totalChecks, "Single dimension check");
        TEST_INT_EQ(1, summary.failedChecks, "50% drop → FAIL");
        if(summary.totalChecks > 0)
            TEST_INT_EQ(REGRESSION_FAIL, summary.findings[0].status, "Status is FAIL");
    }

    // Test 3: Moderate degradation → WARN
    {
        baseline.strategyReport.profitFactor = 2.0;
        current.strategyReport.profitFactor = 1.7;

        RegressionConfig cfg;
        cfg.thresholdCount = 1;
        ArrayResize(cfg.thresholds, 1);
        cfg.thresholds[0].dimension = REG_DIM_PROFIT_FACTOR;
        cfg.thresholds[0].warnPercent = 10.0;
        cfg.thresholds[0].failPercent = 25.0;
        cfg.thresholds[0].higherIsBetter = true;

        CRegressionDetector det;
        det.Init(cfg);
        RegressionSummary summary;
        det.Execute(baseline, current, summary);

        TEST_INT_EQ(1, summary.warnedChecks, "15% drop → WARN");
        if(summary.totalChecks > 0)
            TEST_INT_EQ(REGRESSION_WARN, summary.findings[0].status, "Status is WARN");
    }

    // Test 4: Baseline=0, current≠0 → INSUFFICIENT_DATA
    {
        baseline.strategyReport.profitFactor = 0.0;
        current.strategyReport.profitFactor = 1.5;

        RegressionConfig cfg;
        cfg.thresholdCount = 1;
        ArrayResize(cfg.thresholds, 1);
        cfg.thresholds[0].dimension = REG_DIM_PROFIT_FACTOR;
        cfg.thresholds[0].warnPercent = 10.0;
        cfg.thresholds[0].failPercent = 25.0;
        cfg.thresholds[0].higherIsBetter = true;

        CRegressionDetector det;
        det.Init(cfg);
        RegressionSummary summary;
        det.Execute(baseline, current, summary);

        TEST_INT_EQ(1, summary.insufficientChecks, "Zero baseline → INSUFFICIENT_DATA");
        if(summary.totalChecks > 0)
        {
            TEST_INT_EQ(REGRESSION_INSUFFICIENT_DATA, summary.findings[0].status, "Status is INSUFFICIENT_DATA");
            TEST_FALSE(summary.findings[0].pctChangeDefined, "pctChangeDefined is false");
        }
    }

    // Test 5: Both zero → PASS
    {
        baseline.strategyReport.profitFactor = 0.0;
        current.strategyReport.profitFactor = 0.0;

        RegressionConfig cfg;
        cfg.thresholdCount = 1;
        ArrayResize(cfg.thresholds, 1);
        cfg.thresholds[0].dimension = REG_DIM_PROFIT_FACTOR;
        cfg.thresholds[0].warnPercent = 10.0;
        cfg.thresholds[0].failPercent = 25.0;
        cfg.thresholds[0].higherIsBetter = true;

        CRegressionDetector det;
        det.Init(cfg);
        RegressionSummary summary;
        det.Execute(baseline, current, summary);

        TEST_INT_EQ(1, summary.passedChecks, "Both zero → PASS");
    }

    // Test 6: higherIsBetter — negative delta is DEGRADED
    {
        baseline.strategyReport.profitFactor = 2.0;
        current.strategyReport.profitFactor = 1.0;

        RegressionConfig cfg;
        cfg.thresholdCount = 1;
        ArrayResize(cfg.thresholds, 1);
        cfg.thresholds[0].dimension = REG_DIM_PROFIT_FACTOR;
        cfg.thresholds[0].warnPercent = 5.0;
        cfg.thresholds[0].failPercent = 10.0;
        cfg.thresholds[0].higherIsBetter = true;

        CRegressionDetector det;
        det.Init(cfg);
        RegressionSummary summary;
        det.Execute(baseline, current, summary);

        if(summary.totalChecks > 0)
            TEST_INT_EQ(CHANGE_DEGRADED, summary.findings[0].direction, "Negative delta → DEGRADED when higherIsBetter");
    }

    // Test 7: lowerIsBetter — positive delta is DEGRADED
    {
        baseline.strategyReport.maxDrawdownPercent = 10.0;
        current.strategyReport.maxDrawdownPercent = 20.0;

        RegressionConfig cfg;
        cfg.thresholdCount = 1;
        ArrayResize(cfg.thresholds, 1);
        cfg.thresholds[0].dimension = REG_DIM_MAX_DRAWDOWN;
        cfg.thresholds[0].warnPercent = 10.0;
        cfg.thresholds[0].failPercent = 25.0;
        cfg.thresholds[0].higherIsBetter = false;

        CRegressionDetector det;
        det.Init(cfg);
        RegressionSummary summary;
        det.Execute(baseline, current, summary);

        if(summary.totalChecks > 0)
            TEST_INT_EQ(CHANGE_DEGRADED, summary.findings[0].direction, "Positive delta → DEGRADED when lowerIsBetter");
    }

    // Test 8: Dimension label matches enum
    {
        baseline.strategyReport.profitFactor = 2.0;
        current.strategyReport.profitFactor = 2.0;

        RegressionConfig cfg;
        cfg.thresholdCount = 1;
        ArrayResize(cfg.thresholds, 1);
        cfg.thresholds[0].dimension = REG_DIM_PROFIT_FACTOR;
        cfg.thresholds[0].warnPercent = 10.0;
        cfg.thresholds[0].failPercent = 25.0;
        cfg.thresholds[0].higherIsBetter = true;

        CRegressionDetector det;
        det.Init(cfg);
        RegressionSummary summary;
        det.Execute(baseline, current, summary);

        if(summary.totalChecks > 0)
            TEST_STR_EQ("profitFactor", summary.findings[0].dimensionLabel, "Dimension label matches enum");
    }

    // Test 9: Config version recorded
    {
        RegressionConfig cfg;
        cfg.configVersion = 1;
        cfg.thresholdCount = 1;
        ArrayResize(cfg.thresholds, 1);
        cfg.thresholds[0].dimension = REG_DIM_PROFIT_FACTOR;
        cfg.thresholds[0].warnPercent = 10.0;
        cfg.thresholds[0].failPercent = 25.0;
        cfg.thresholds[0].higherIsBetter = true;

        CRegressionDetector det;
        det.Init(cfg);
        RegressionSummary summary;
        det.Execute(baseline, current, summary);

        TEST_INT_EQ(1, summary.config.configVersion, "Summary preserves configVersion");
    }

    SUITE_END("Regression Unit Tests");
    return counters;
}
