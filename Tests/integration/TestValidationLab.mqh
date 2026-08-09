#include "../../Validation/ValidationLab.mqh"
#include "../../Validation/WalkForwardPipeline.mqh"
#include "../../Validation/MonteCarloPipeline.mqh"
#include "../../Validation/RegressionDetector.mqh"
#include "../../Validation/ValidationReportComposer.mqh"
#include "../TestAssert.mqh"

TestCounters RunIntegrationTests(void)
{
    TestCounters counters;

    SUITE_BEGIN("Integration Tests");

    // Test 1: ValidationLab init/shutdown cycle
    {
        CValidationLab lab;
        bool ok = lab.Init("test_output");
        TEST_TRUE(ok, "ValidationLab.Init() should succeed");
        TEST_TRUE(lab.IsInitialized(), "ValidationLab should report initialized");

        lab.Shutdown();
        TEST_FALSE(lab.IsInitialized(), "ValidationLab should report shutdown");
    }

    // Test 2: All components init together
    {
        CValidationLab lab;
        TEST_TRUE(lab.Init("test_output"), "Init lab");

        CWalkForwardPipeline wfPipe;
        TEST_TRUE(wfPipe.Init(&lab), "Init WF pipeline with lab");

        CMonteCarloPipeline mcPipe;
        TEST_TRUE(mcPipe.Init(), "Init MC pipeline");

        RegressionConfig regCfg;
        regCfg.thresholdCount = 1;
        ArrayResize(regCfg.thresholds, 1);
        regCfg.thresholds[0].dimension = REG_DIM_PROFIT_FACTOR;
        regCfg.thresholds[0].warnPercent = 10.0;
        regCfg.thresholds[0].failPercent = 25.0;
        regCfg.thresholds[0].higherIsBetter = true;
        CRegressionDetector regDet;
        TEST_TRUE(regDet.Init(regCfg), "Init regression detector");

        CValidationReportComposer composer;
        TEST_TRUE(composer.Init(), "Init report composer");

        lab.Shutdown();
        wfPipe.Shutdown();
        mcPipe.Shutdown();
        regDet.Shutdown();
        composer.Shutdown();
    }

    // Test 3: WalkForward scheduler → pipeline roundtrip
    {
        CWalkForwardScheduler sched;
        sched.Init();

        WalkForwardScheduleConfig cfg;
        cfg.overallStart = D'2020.01.01';
        cfg.overallEnd = D'2020.06.01';
        cfg.mode = WF_ROLLING;
        cfg.windowDays = 60;
        cfg.stepDays = 30;
        cfg.trainRatio = 0.70;
        cfg.minTrainDays = 10;
        cfg.minTestDays = 10;

        WalkForwardSchedule schedule;
        bool genOk = sched.Generate(cfg, schedule);
        TEST_TRUE(genOk, "Scheduler generates windows");
        TEST_TRUE(schedule.windowCount > 0, "Schedule has windows");
        for(int i = 0; i < schedule.windowCount; i++)
        {
            WfExecutionWindow w = schedule.windows[i];
            TEST_TRUE(w.trainStart > 0, "Window has trainStart");
            TEST_TRUE(w.testEnd > w.testStart, "Window has valid test range");
            TEST_TRUE(StringLen(w.windowId) > 0, "Window has non-empty ID");
        }
    }

    // Test 4: RegressionDetector produces valid summary with real config
    {
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

        RegressionConfig cfg;
        cfg.thresholdCount = 11;
        ArrayResize(cfg.thresholds, 11);
        for(int i = 0; i < 11; i++)
        {
            cfg.thresholds[i].dimension = (ENUM_REGRESSION_DIMENSION)i;
            cfg.thresholds[i].warnPercent = 10.0;
            cfg.thresholds[i].failPercent = 25.0;
            cfg.thresholds[i].higherIsBetter = (i != REG_DIM_MAX_DRAWDOWN);
        }

        CRegressionDetector det;
        det.Init(cfg);
        RegressionSummary summary;
        bool ok = det.Execute(base, curr, summary);

        TEST_TRUE(ok, "Regression executes with 11 metrics");
        TEST_INT_EQ(11, summary.totalChecks, "11 checks performed");
        TEST_TRUE(summary.failedChecks > 0, "PF dropped 30% → at least 1 failure");
    }

    // Test 5: ReportComposer produces well-formed output from partial data
    {
        ValidationResult vr;
        vr.manifest.validationId = "integration-test";
        vr.manifest.symbolTested = "EURUSD";
        vr.manifest.timeframeTested = "PERIOD_M15";
        vr.manifest.eaVersion = "v2.7-test";
        vr.strategyReport.totalTrades = 75;
        vr.strategyReport.profitFactor = 1.6;

        WalkForwardSummary wf;
        wf.totalWindows = 3;
        wf.validWindows = 2;
        wf.completedSuccessfully = true;
        ArrayResize(wf.results, 3);
        for(int i = 0; i < 3; i++)
        {
            wf.results[i].window.windowId = "WF-INT-" + StringFormat("%04d", i);
            wf.results[i].status = (i < 2) ? WINDOW_PASS : WINDOW_FAIL_EXECUTION;
            wf.results[i].result.strategyReport.totalTrades = 20 + i * 5;
        }

        CValidationReportComposer composer;
        composer.Init();
        ValidationReport report;
        bool ok = composer.Compose(vr, wf, report);

        TEST_TRUE(ok, "Integration report composes with VR + WF");
        TEST_TRUE(report.hasWalkForward, "Report has WF section");
        TEST_FALSE(report.hasMonteCarlo, "Report has no MC section");
        TEST_TRUE(StringLen(report.formattedText) > 0, "Report text is non-empty");
        TEST_TRUE(StringFind(report.formattedText, "Walk-Forward Analysis") >= 0, "WF section present in text");
    }

    SUITE_END("Integration Tests");
    return counters;
}
