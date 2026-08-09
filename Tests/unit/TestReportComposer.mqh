#include "../../Validation/ValidationReportComposer.mqh"
#include "../TestAssert.mqh"

TestCounters RunReportComposerTests(void)
{
    TestCounters counters;

    SUITE_BEGIN("ReportComposer Unit Tests");

    CValidationReportComposer composer;
    composer.Init();

    // Test 1: Empty validation result still produces report
    {
        ValidationResult vr;
        vr.manifest.validationId = "test-empty";
        vr.manifest.symbolTested = "EURUSD";
        vr.manifest.timeframeTested = "PERIOD_M15";
        vr.manifest.eaVersion = "v2.7-test";

        ValidationReport report;
        bool ok = composer.Compose(vr, report);

        TEST_TRUE(ok, "Compose with empty VR should succeed");
        TEST_TRUE(StringLen(report.formattedText) > 0, "Report text should not be empty");
        TEST_FALSE(report.hasWalkForward, "No WF summary → hasWalkForward false");
        TEST_FALSE(report.hasMonteCarlo, "No MC summary → hasMonteCarlo false");
        TEST_FALSE(report.hasRegression, "No regression → hasRegression false");
    }

    // Test 2: All summaries present
    {
        ValidationResult vr;
        vr.manifest.validationId = "test-all";
        vr.manifest.symbolTested = "GBPUSD";
        vr.manifest.timeframeTested = "PERIOD_H1";
        vr.manifest.eaVersion = "v2.7-test";
        vr.strategyReport.totalTrades = 100;
        vr.strategyReport.profitFactor = 1.8;
        vr.strategyReport.totalNetProfit = 2500.0;

        WalkForwardSummary wf;
        wf.totalWindows = 10;
        wf.validWindows = 8;
        wf.scheduleFailures = 1;
        wf.executionFailures = 1;
        wf.completedSuccessfully = true;
        ArrayResize(wf.results, 10);
        for(int i = 0; i < 10; i++)
        {
            wf.results[i].window = WfExecutionWindow();
            wf.results[i].window.windowId = "WF-TEST-" + StringFormat("%04d", i);
            wf.results[i].window.windowIndex = i;
            wf.results[i].status = (i < 8) ? WINDOW_PASS : WINDOW_FAIL_SCHEDULE;
            wf.results[i].result.strategyReport.totalTrades = 10 + i;
            wf.results[i].result.strategyReport.totalNetProfit = 100.0 * (i + 1);
            wf.results[i].execDurationMs = 50 * (i + 1);
        }

        MonteCarloSummary mc;
        mc.totalRuns = 500;
        mc.completedRuns = 500;
        mc.originalProfit = 2500.0;
        mc.statistics.meanProfit = 2200.0;
        mc.statistics.medianProfit = 2100.0;
        mc.statistics.p95Profit = 3500.0;
        mc.statistics.p99Profit = 4200.0;
        mc.statistics.isSignificant = true;
        mc.statistics.sufficientIterations = true;
        mc.statistics.probabilityOfLoss = 0.15;
        mc.statistics.stdDevProfit = 800.0;
        mc.statistics.usedIterations = 500;

        RegressionSummary reg;
        reg.totalChecks = 11;
        reg.passedChecks = 9;
        reg.warnedChecks = 1;
        reg.failedChecks = 1;
        reg.insufficientChecks = 0;
        reg.baselineValidationId = "baseline-v1";
        reg.currentValidationId = "test-all";
        ArrayResize(reg.findings, 11);
        for(int i = 0; i < 11; i++)
        {
            reg.findings[i].dimension = (ENUM_REGRESSION_DIMENSION)i;
            reg.findings[i].dimensionLabel = "dim" + IntegerToString(i);
            reg.findings[i].status = (i < 9) ? REGRESSION_PASS : (i == 9 ? REGRESSION_WARN : REGRESSION_FAIL);
            reg.findings[i].baselineValue = 2.0;
            reg.findings[i].currentValue = (i < 9) ? 2.0 : (i == 9 ? 1.7 : 1.0);
            reg.findings[i].deltaPercent = (i < 9) ? 0.0 : (i == 9 ? -15.0 : -50.0);
            reg.findings[i].pctChangeDefined = true;
            reg.findings[i].message = "Test message";
        }

        ValidationReport report;
        bool ok = composer.Compose(vr, wf, mc, reg, report);

        TEST_TRUE(ok, "Compose with all summaries should succeed");
        TEST_TRUE(report.hasWalkForward, "hasWalkForward true");
        TEST_TRUE(report.hasMonteCarlo, "hasMonteCarlo true");
        TEST_TRUE(report.hasRegression, "hasRegression true");
        TEST_INT_EQ(10, report.walkForward.totalWindows, "WalkForward totalWindows preserved");
        TEST_INT_EQ(500, report.monteCarlo.totalRuns, "MonteCarlo totalRuns preserved");
        TEST_INT_EQ(11, report.regression.totalChecks, "Regression totalChecks preserved");
        TEST_INT_EQ(1, report.regression.warnedChecks, "Regression warnedChecks preserved");
        TEST_TRUE(StringLen(report.formattedText) > 0, "Report formattedText not empty");
    }

    // Test 3: Formatted text contains key sections
    {
        ValidationResult vr;
        vr.manifest.validationId = "test-sections";
        vr.manifest.symbolTested = "EURUSD";
        vr.manifest.timeframeTested = "PERIOD_M15";
        vr.manifest.eaVersion = "v2.7-test";
        vr.strategyReport.profitFactor = 2.0;
        vr.strategyReport.totalTrades = 50;

        WalkForwardSummary wf;
        wf.totalWindows = 5;
        wf.validWindows = 4;
        wf.completedSuccessfully = true;
        ArrayResize(wf.results, 5);
        for(int i = 0; i < 5; i++)
        {
            wf.results[i].window.windowId = "WF-SECTST-" + StringFormat("%04d", i);
            wf.results[i].status = (i < 4) ? WINDOW_PASS : WINDOW_FAIL_EXECUTION;
        }

        MonteCarloSummary mc;
        mc.totalRuns = 100;
        mc.completedRuns = 100;
        mc.originalProfit = 1000.0;
        mc.statistics.meanProfit = 950.0;
        mc.statistics.isSignificant = true;
        mc.statistics.sufficientIterations = true;

        RegressionSummary reg;
        reg.totalChecks = 1;
        reg.passedChecks = 1;
        reg.baselineValidationId = "base";
        reg.currentValidationId = "curr";
        ArrayResize(reg.findings, 1);
        reg.findings[0].dimensionLabel = "profitFactor";
        reg.findings[0].status = REGRESSION_PASS;
        reg.findings[0].baselineValue = 2.0;
        reg.findings[0].currentValue = 2.0;
        reg.findings[0].pctChangeDefined = false;

        ValidationReport report;
        composer.Compose(vr, wf, mc, reg, report);

        string txt = report.formattedText;
        TEST_TRUE(StringFind(txt, "Validation Report") >= 0, "Report contains title");
        TEST_TRUE(StringFind(txt, "EURUSD") >= 0, "Report contains symbol");
        TEST_TRUE(StringFind(txt, "Walk-Forward Analysis") >= 0, "Report has WF section");
        TEST_TRUE(StringFind(txt, "Monte Carlo Analysis") >= 0, "Report has MC section");
        TEST_TRUE(StringFind(txt, "Regression Analysis") >= 0, "Report has regression section");
        TEST_TRUE(StringFind(txt, "End of Report") >= 0, "Report has end marker");
    }

    SUITE_END("ReportComposer Unit Tests");
    return counters;
}
