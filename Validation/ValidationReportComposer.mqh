#ifndef __VALIDATION_REPORT_COMPOSER_MQH__
#define __VALIDATION_REPORT_COMPOSER_MQH__

#include "../Core/Logger.mqh"
#include "ReportTypes.mqh"

class CValidationReportComposer
{
private:
    CLogger  m_logger;
    bool     m_isInitialized;

    void AppendLine(string &text, const string line) const
    {
        text += line + "\n";
    }

    void AppendHeader(string &text, const string title) const
    {
        AppendLine(text, "");
        AppendLine(text, "========================================");
        AppendLine(text, "  " + title);
        AppendLine(text, "========================================");
    }

    void AppendSubHeader(string &text, const string title) const
    {
        AppendLine(text, "");
        AppendLine(text, "--- " + title + " ---");
    }

    void AppendKeyValue(string &text, const string key, const string value) const
    {
        string padded = key;
        while(StringLen(padded) < 30)
            padded += " ";
        AppendLine(text, padded + " : " + value);
    }

    void AppendKeyValue(string &text, const string key, double value, int decimals = 2) const
    {
        AppendKeyValue(text, key, StringFormat("%.*f", decimals, value));
    }

    void AppendKeyValue(string &text, const string key, int value) const
    {
        AppendKeyValue(text, key, IntegerToString(value));
    }

    void AppendKeyValue(string &text, const string key, bool value) const
    {
        AppendKeyValue(text, key, value ? "YES" : "NO");
    }

    void FormatValidationResult(string &text, const ValidationResult &vr) const
    {
        AppendSubHeader(text, "Validation Result");
        StrategyReport r = vr.strategyReport;
        AppendKeyValue(text, "Experiment", r.experimentId);
        AppendKeyValue(text, "Parameter Set", r.parameterSetId);
        AppendKeyValue(text, "Symbol", vr.manifest.symbolTested);
        AppendKeyValue(text, "Timeframe", vr.manifest.timeframeTested);
        AppendKeyValue(text, "Total Trades", r.totalTrades);
        AppendKeyValue(text, "Winning Trades", r.winningTrades);
        AppendKeyValue(text, "Losing Trades", r.losingTrades);
        AppendKeyValue(text, "Win Rate", r.winRate, 1);
        AppendKeyValue(text, "Total Net Profit", r.totalNetProfit);
        AppendKeyValue(text, "Profit Factor", r.profitFactor, 2);
        AppendKeyValue(text, "Expectancy", r.expectancy, 2);
        AppendKeyValue(text, "Sharpe Ratio", r.sharpeRatio, 2);
        AppendKeyValue(text, "Sortino Ratio", r.sortinoRatio, 2);
        AppendKeyValue(text, "Calmar Ratio", r.calmarRatio, 2);
        AppendKeyValue(text, "Recovery Factor", r.recoveryFactor, 2);
        AppendKeyValue(text, "Max Drawdown %", r.maxDrawdownPercent, 1);
        AppendKeyValue(text, "Avg RR", r.avgRRAchieved, 2);
    }

    void FormatWalkForward(string &text, const WalkForwardSummary &wf) const
    {
        AppendSubHeader(text, "Walk-Forward Analysis");
        AppendKeyValue(text, "Total Windows", wf.totalWindows);
        AppendKeyValue(text, "Valid Windows", wf.validWindows);
        AppendKeyValue(text, "Schedule Failures", wf.scheduleFailures);
        AppendKeyValue(text, "Execution Failures", wf.executionFailures);
        AppendKeyValue(text, "Pipeline Completed", wf.completedSuccessfully);

        if(wf.validWindows > 0)
        {
            int passCount = 0;
            for(int i = 0; i < wf.totalWindows; i++)
                if(wf.results[i].status == WINDOW_PASS)
                    passCount++;
            if(passCount > 0)
            {
                double sumPF = 0.0;
                int validPF = 0;
                for(int i = 0; i < wf.totalWindows; i++)
                    if(wf.results[i].status == WINDOW_PASS)
                    {
                        sumPF += wf.results[i].result.strategyReport.profitFactor;
                        validPF++;
                    }
                AppendKeyValue(text, "Avg Window PF", validPF > 0 ? sumPF / validPF : 0.0, 2);
            }
            AppendKeyValue(text, "Windows Passed", passCount);
            AppendLine(text, "");
            AppendLine(text, "Window details:");
            for(int i = 0; i < wf.totalWindows; i++)
            {
                WalkForwardWindowResult wr = wf.results[i];
                string statusStr = "???";
                if(wr.status == WINDOW_PASS) statusStr = "PASS";
                else if(wr.status == WINDOW_FAIL_SCHEDULE) statusStr = "SCHED_FAIL";
                else if(wr.status == WINDOW_FAIL_EXECUTION) statusStr = "EXEC_FAIL";
                AppendLine(text, StringFormat("  [%s] %s  trades=%d  P/L=%.2f  %lldms",
                    statusStr, wr.window.windowId,
                    wr.result.strategyReport.totalTrades,
                    wr.result.strategyReport.totalNetProfit,
                    wr.execDurationMs));
            }
        }
    }

    void FormatMonteCarlo(string &text, const MonteCarloSummary &mc) const
    {
        AppendSubHeader(text, "Monte Carlo Analysis");
        AppendKeyValue(text, "Total Runs", mc.totalRuns);
        AppendKeyValue(text, "Completed Runs", mc.completedRuns);
        AppendKeyValue(text, "Original Profit", mc.originalProfit, 2);
        AppendKeyValue(text, "Mean Profit", mc.statistics.meanProfit, 2);
        AppendKeyValue(text, "Median Profit", mc.statistics.medianProfit, 2);
        AppendKeyValue(text, "Std Deviation", mc.statistics.stdDevProfit, 2);
        AppendKeyValue(text, "P95 Profit", mc.statistics.p95Profit, 2);
        AppendKeyValue(text, "P99 Profit", mc.statistics.p99Profit, 2);
        AppendKeyValue(text, "Probability of Loss", mc.statistics.probabilityOfLoss * 100.0, 1);
        AppendKeyValue(text, "Significant", mc.statistics.isSignificant);
        AppendKeyValue(text, "Sufficient Iterations", mc.statistics.sufficientIterations);
    }

    void FormatRegression(string &text, const RegressionSummary &reg) const
    {
        AppendSubHeader(text, "Regression Analysis");
        AppendKeyValue(text, "Baseline Validation", reg.baselineValidationId);
        AppendKeyValue(text, "Current Validation", reg.currentValidationId);
        AppendKeyValue(text, "Total Checks", reg.totalChecks);
        AppendKeyValue(text, "Passed", reg.passedChecks);
        AppendKeyValue(text, "Warnings", reg.warnedChecks);
        AppendKeyValue(text, "Failures", reg.failedChecks);
        AppendKeyValue(text, "Insufficient Data", reg.insufficientChecks);

        if(reg.totalChecks > 0)
        {
            AppendLine(text, "");
            AppendLine(text, "Per-dimension results:");
            for(int i = 0; i < reg.totalChecks; i++)
            {
                RegressionFinding f = reg.findings[i];
                string statusStr = "???";
                if(f.status == REGRESSION_PASS) statusStr = "PASS";
                else if(f.status == REGRESSION_WARN) statusStr = "WARN";
                else if(f.status == REGRESSION_FAIL) statusStr = "FAIL";
                else if(f.status == REGRESSION_INSUFFICIENT_DATA) statusStr = "NO_DATA";
                AppendLine(text, StringFormat(
                    "  [%s] %s  %.2f -> %.2f  (%.1f%%) %s",
                    statusStr, f.dimensionLabel,
                    f.baselineValue, f.currentValue,
                    f.pctChangeDefined ? f.deltaPercent : 0.0,
                    f.message));
            }
        }
    }

public:
    CValidationReportComposer(void)
        : m_logger(MODULE_LABORATORY, "ReportComposer")
        , m_isInitialized(false)
    {}

    ~CValidationReportComposer(void)
    {
        Shutdown();
    }

    bool Init(void)
    {
        m_isInitialized = true;
        m_logger.LogInfo("ValidationReportComposer initialized");
        return true;
    }

    void Shutdown(void)
    {
        m_isInitialized = false;
    }

    bool IsInitialized(void) const { return m_isInitialized; }

    bool Compose(const ValidationResult &vr,
                 ValidationReport &report)
    {
        return Compose(vr, WalkForwardSummary(), MonteCarloSummary(),
                       RegressionSummary(), report);
    }

    bool Compose(const ValidationResult &vr,
                 const WalkForwardSummary &wf,
                 ValidationReport &report)
    {
        return Compose(vr, wf, MonteCarloSummary(),
                       RegressionSummary(), report);
    }

    bool Compose(const ValidationResult &vr,
                 const WalkForwardSummary &wf,
                 const MonteCarloSummary &mc,
                 ValidationReport &report)
    {
        return Compose(vr, wf, mc, RegressionSummary(), report);
    }

    bool Compose(const ValidationResult &vr,
                 const WalkForwardSummary &wf,
                 const MonteCarloSummary &mc,
                 const RegressionSummary &reg,
                 ValidationReport &report)
    {
        if(!m_isInitialized)
        {
            m_logger.LogError("ValidationReportComposer not initialized");
            return false;
        }

        report = ValidationReport();
        report.validation = vr;
        report.generatedAt = TimeCurrent();
        report.eaVersion = vr.manifest.eaVersion;
        report.gitCommit = vr.manifest.gitCommit;
        report.title = StringFormat("Validation Report | %s | %s | %s",
            vr.manifest.symbolTested,
            vr.manifest.timeframeTested,
            TimeToString(report.generatedAt, TIME_DATE));

        bool hasWF = (wf.totalWindows > 0);
        bool hasMC = (mc.totalRuns > 0);
        bool hasReg = (reg.totalChecks > 0);

        report.hasWalkForward = hasWF;
        report.hasMonteCarlo = hasMC;
        report.hasRegression = hasReg;

        if(hasWF) report.walkForward = wf;
        if(hasMC) report.monteCarlo = mc;
        if(hasReg) report.regression = reg;

        string text = "";
        AppendHeader(text, report.title);
        AppendLine(text, StringFormat("  Generated: %s", TimeToString(report.generatedAt)));
        AppendLine(text, StringFormat("  EA Version: %s", report.eaVersion));
        if(report.gitCommit != "")
            AppendLine(text, StringFormat("  Git Commit: %s", report.gitCommit));
        AppendLine(text, StringFormat("  Validation ID: %s", vr.manifest.validationId));

        FormatValidationResult(text, vr);

        if(hasWF)
            FormatWalkForward(text, wf);

        if(hasMC)
            FormatMonteCarlo(text, mc);

        if(hasReg)
            FormatRegression(text, reg);

        AppendLine(text, "");
        AppendLine(text, "========================================");
        AppendLine(text, "  End of Report");
        AppendLine(text, "========================================");

        report.formattedText = text;

        m_logger.LogInfo(StringFormat(
            "Report composed: WF=%s MC=%s REG=%s",
            hasWF ? "YES" : "NO", hasMC ? "YES" : "NO", hasReg ? "YES" : "NO"));

        return true;
    }
};

#endif
