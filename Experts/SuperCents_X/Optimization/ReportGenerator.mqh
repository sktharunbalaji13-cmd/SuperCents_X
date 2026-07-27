#ifndef __OPTIMIZATION_REPORT_GENERATOR_MQH__
#define __OPTIMIZATION_REPORT_GENERATOR_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "OptimizationTypes.mqh"
#include "ExperimentManifest.mqh"

class CReportGenerator
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

public:
    CReportGenerator(void);
    ~CReportGenerator(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    static string FormatReport(const StrategyReport &report);
    static string ToCSV(const StrategyReport &report);
    static string ToCSVHeader(void);
    static bool   ToJSON(const StrategyReport &report, string &outJson);
    static bool   Aggregate(StrategyReport &windowReports[],
                            int reportCount,
                            StrategyReport &outSummary);
};

CReportGenerator::CReportGenerator(void)
    : m_logger(MODULE_UNKNOWN, "ReportGenerator")
    , m_isInitialized(false)
{
}

CReportGenerator::~CReportGenerator(void)
{
    Shutdown();
}

bool CReportGenerator::Init(void)
{
    m_logger.LogInfo("Initializing ReportGenerator...");
    m_isInitialized = true;
    return true;
}

void CReportGenerator::Shutdown(void)
{
    m_isInitialized = false;
}

string CReportGenerator::FormatReport(const StrategyReport &r)
{
    string out = "";
    out += "========================================\n";
    out += "STRATEGY REPORT\n";
    out += "========================================\n";
    out += StringFormat("  Experiment     : %s\n", r.experimentId);
    out += StringFormat("  Parameter Set  : %s\n", r.parameterSetId);
    out += StringFormat("  Platform       : %s\n", r.platformVersion);
    out += StringFormat("  Window         : %s\n", r.windowLabel);
    out += "----------------------------------------\n";
    out += "  TRADES\n";
    out += StringFormat("    Total        : %d\n", r.totalTrades);
    out += StringFormat("    Wins         : %d\n", r.winningTrades);
    out += StringFormat("    Losses       : %d\n", r.losingTrades);
    out += StringFormat("    Win Rate     : %.1f%%\n", r.winRate);
    out += "----------------------------------------\n";
    out += "  P&L\n";
    out += StringFormat("    Net Profit   : $%.2f\n", r.totalNetProfit);
    out += StringFormat("    Gross Profit : $%.2f\n", r.grossProfit);
    out += StringFormat("    Gross Loss   : $%.2f\n", r.grossLoss);
    out += StringFormat("    Expectancy   : $%.2f\n", r.expectancy);
    out += StringFormat("    Profit Factor: %.2f\n", r.profitFactor);
    out += "----------------------------------------\n";
    out += "  RISK-ADJUSTED\n";
    out += StringFormat("    Sharpe       : %.2f\n", r.sharpeRatio);
    out += StringFormat("    Sortino      : %.2f\n", r.sortinoRatio);
    out += StringFormat("    Calmar       : %.2f\n", r.calmarRatio);
    out += StringFormat("    Recovery     : %.2f\n", r.recoveryFactor);
    out += "----------------------------------------\n";
    out += "  DRAWDOWN\n";
    out += StringFormat("    Max DD %%     : %.2f%%\n", r.maxDrawdownPercent);
    out += StringFormat("    Max DD Value : $%.2f\n", r.maxDrawdownValue);
    out += StringFormat("    Avg DD %%     : %.2f%%\n", r.avgDrawdownPercent);
    out += "----------------------------------------\n";
    out += "  POSITION METRICS\n";
    out += StringFormat("    Avg Hold     : %.0f sec\n", r.avgHoldingTimeSeconds);
    out += StringFormat("    Avg RR       : %.2f\n", r.avgRRAchieved);
    out += StringFormat("    Avg Stop     : %.1f pips\n", r.avgStopPips);
    out += StringFormat("    Avg Target   : %.1f pips\n", r.avgTargetPips);
    out += "----------------------------------------\n";
    out += "  EXPOSURE\n";
    out += StringFormat("    Avg Exposure : %.1f%%\n", r.avgExposurePercent);
    out += StringFormat("    Max Exposure : %.1f%%\n", r.maxExposurePercent);
    out += StringFormat("    Avg Margin   : %.1f%%\n", r.avgMarginUtilization);
    out += "----------------------------------------\n";
    out += "  ROBUSTNESS\n";
    out += StringFormat("    MC 95%%       : $%.2f\n", r.monteCarloConfidence95);
    out += StringFormat("    Spread Slope : %.4f\n", r.spreadSensitivitySlope);
    out += StringFormat("    Slippage Sl  : %.4f\n", r.slippageSensitivitySlope);
    out += "========================================\n";
    return out;
}

string CReportGenerator::ToCSVHeader(void)
{
    return "ExperimentID,ParameterSet,Platform,Window,"
           "TotalTrades,Wins,Losses,WinRate,"
           "NetProfit,GrossProfit,GrossLoss,Expectancy,ProfitFactor,"
           "Sharpe,Sortino,Calmar,Recovery,"
           "MaxDD,MaxDDVal,AvgDD,"
           "AvgHoldSec,AvgRR,AvgStopPips,AvgTargetPips,"
           "AvgExp,MaxExp,AvgMargin,"
           "MC95,SpreadSlope,SlippageSlope";
}

string CReportGenerator::ToCSV(const StrategyReport &r)
{
    return StringFormat("%s,%s,%s,%s,"
                         "%d,%d,%d,%.2f,"
                         "%.2f,%.2f,%.2f,%.2f,%.2f,"
                         "%.2f,%.2f,%.2f,%.2f,"
                         "%.2f,%.2f,%.2f,"
                         "%.0f,%.2f,%.1f,%.1f,"
                         "%.1f,%.1f,%.1f,"
                         "%.2f,%.4f,%.4f",
                         r.experimentId, r.parameterSetId, r.platformVersion, r.windowLabel,
                         r.totalTrades, r.winningTrades, r.losingTrades, r.winRate,
                         r.totalNetProfit, r.grossProfit, r.grossLoss, r.expectancy, r.profitFactor,
                         r.sharpeRatio, r.sortinoRatio, r.calmarRatio, r.recoveryFactor,
                         r.maxDrawdownPercent, r.maxDrawdownValue, r.avgDrawdownPercent,
                         r.avgHoldingTimeSeconds, r.avgRRAchieved, r.avgStopPips, r.avgTargetPips,
                         r.avgExposurePercent, r.maxExposurePercent, r.avgMarginUtilization,
                         r.monteCarloConfidence95, r.spreadSensitivitySlope, r.slippageSensitivitySlope);
}

bool CReportGenerator::ToJSON(const StrategyReport &r, string &outJson)
{
    outJson = "{";
    outJson += StringFormat("\"experimentId\":\"%s\",", r.experimentId);
    outJson += StringFormat("\"parameterSetId\":\"%s\",", r.parameterSetId);
    outJson += StringFormat("\"platformVersion\":\"%s\",", r.platformVersion);
    outJson += StringFormat("\"window\":\"%s\",", r.windowLabel);
    outJson += StringFormat("\"trades\":{\"total\":%d,\"wins\":%d,\"losses\":%d,\"winRate\":%.4f},",
                            r.totalTrades, r.winningTrades, r.losingTrades, r.winRate);
    outJson += StringFormat("\"pnl\":{\"net\":%.2f,\"grossProfit\":%.2f,\"grossLoss\":%.2f,\"expectancy\":%.2f,\"profitFactor\":%.4f},",
                            r.totalNetProfit, r.grossProfit, r.grossLoss, r.expectancy, r.profitFactor);
    outJson += StringFormat("\"riskAdjusted\":{\"sharpe\":%.4f,\"sortino\":%.4f,\"calmar\":%.4f,\"recovery\":%.4f},",
                            r.sharpeRatio, r.sortinoRatio, r.calmarRatio, r.recoveryFactor);
    outJson += StringFormat("\"drawdown\":{\"maxPercent\":%.4f,\"maxValue\":%.2f,\"avgPercent\":%.4f},",
                            r.maxDrawdownPercent, r.maxDrawdownValue, r.avgDrawdownPercent);
    outJson += StringFormat("\"positionMetrics\":{\"avgHoldSec\":%.0f,\"avgRR\":%.4f,\"avgStopPips\":%.2f,\"avgTargetPips\":%.2f},",
                            r.avgHoldingTimeSeconds, r.avgRRAchieved, r.avgStopPips, r.avgTargetPips);
    outJson += StringFormat("\"exposure\":{\"avg\":%.4f,\"max\":%.4f,\"avgMargin\":%.4f},",
                            r.avgExposurePercent, r.maxExposurePercent, r.avgMarginUtilization);
    outJson += StringFormat("\"robustness\":{\"mc95\":%.2f,\"spreadSlope\":%.6f,\"slippageSlope\":%.6f}",
                            r.monteCarloConfidence95, r.spreadSensitivitySlope, r.slippageSensitivitySlope);
    outJson += "}";
    return true;
}

bool CReportGenerator::Aggregate(StrategyReport &windowReports[],
                                  int reportCount,
                                  StrategyReport &outSummary)
{
    if(reportCount <= 0)
        return false;

    outSummary = windowReports[0];
    outSummary.windowLabel = "AGGREGATE";

    for(int i = 1; i < reportCount; i++)
    {
        StrategyReport &w = windowReports[i];

        outSummary.totalTrades += w.totalTrades;
        outSummary.winningTrades += w.winningTrades;
        outSummary.losingTrades += w.losingTrades;
        outSummary.totalNetProfit += w.totalNetProfit;
        outSummary.grossProfit += w.grossProfit;
        outSummary.grossLoss += w.grossLoss;
        outSummary.expectancy += w.expectancy;
        outSummary.profitFactor += w.profitFactor;
        outSummary.sharpeRatio += w.sharpeRatio;
        outSummary.sortinoRatio += w.sortinoRatio;
        outSummary.calmarRatio += w.calmarRatio;
        outSummary.recoveryFactor += w.recoveryFactor;
        outSummary.maxDrawdownPercent += w.maxDrawdownPercent;
        outSummary.avgDrawdownPercent += w.avgDrawdownPercent;
        outSummary.avgHoldingTimeSeconds += w.avgHoldingTimeSeconds;
        outSummary.avgRRAchieved += w.avgRRAchieved;
        outSummary.avgStopPips += w.avgStopPips;
        outSummary.avgTargetPips += w.avgTargetPips;
        outSummary.avgExposurePercent += w.avgExposurePercent;
        outSummary.maxExposurePercent = MathMax(outSummary.maxExposurePercent, w.maxExposurePercent);
        outSummary.avgMarginUtilization += w.avgMarginUtilization;
        if(w.maxDrawdownPercent > outSummary.maxDrawdownPercent)
        {
            outSummary.maxDrawdownPercent = w.maxDrawdownPercent;
            outSummary.maxDrawdownValue = w.maxDrawdownValue;
        }
    }

    outSummary.expectancy /= reportCount;
    outSummary.profitFactor /= reportCount;
    outSummary.sharpeRatio /= reportCount;
    outSummary.sortinoRatio /= reportCount;
    outSummary.calmarRatio /= reportCount;
    outSummary.recoveryFactor /= reportCount;
    outSummary.avgDrawdownPercent /= reportCount;
    outSummary.avgHoldingTimeSeconds /= reportCount;
    outSummary.avgRRAchieved /= reportCount;
    outSummary.avgStopPips /= reportCount;
    outSummary.avgTargetPips /= reportCount;
    outSummary.avgExposurePercent /= reportCount;
    outSummary.avgMarginUtilization /= reportCount;

    return true;
}

#endif
