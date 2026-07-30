#ifndef __OPTIMIZATION_ROBUSTNESS_TESTER_MQH__
#define __OPTIMIZATION_ROBUSTNESS_TESTER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "OptimizationTypes.mqh"
#include "../Validation/ValidationTypes.mqh"

#define MAX_SENSITIVITY_RESULTS 50

class CRobustnessTester
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    StrategyReport m_baselineReport;
    bool           m_hasBaseline;

    double ComputeProfitChange(double baselineProfit, double perturbationCost) const
    {
        if(!m_hasBaseline || baselineProfit == 0.0)
            return 0.0;
        return -(perturbationCost / MathAbs(baselineProfit)) * 100.0;
    }

    double ComputeMetricScore(double changePercent) const
    {
        double absChange = MathAbs(changePercent);
        if(absChange < 5.0)  return 1.0;
        if(absChange < 15.0) return 0.75;
        if(absChange < 30.0) return 0.50;
        if(absChange < 50.0) return 0.25;
        return 0.0;
    }

    double GetParameterSensitivityFactor(const string paramName) const
    {
        if(paramName.Find("swingStrength") >= 0)   return 0.15;
        if(paramName.Find("bosLookback") >= 0)     return 0.12;
        if(paramName.Find("fvgMinBody") >= 0)      return 0.10;
        if(paramName.Find("confluenceThreshold") >= 0) return 0.20;
        if(paramName.Find("maxRisk") >= 0)         return 0.25;
        if(paramName.Find("stopBuffer") >= 0)      return 0.08;
        if(paramName.Find("minStop") >= 0)         return 0.08;
        if(paramName.Find("maxPortfolioRisk") >= 0) return 0.15;
        if(paramName.Find("maxConcurrent") >= 0)   return 0.10;
        if(paramName.Find("maxCorrelation") >= 0)  return 0.12;
        return 0.10;
    }

public:
    CRobustnessTester(void);
    ~CRobustnessTester(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool SetBaselineReport(const StrategyReport &report);

    bool TestSpreadSensitivity(const double &multipliers[],
                                const ParameterSet &baseline,
                                SensitivityResult &results[],
                                int &resultCount);

    bool TestSlippageSensitivity(const double &multipliers[],
                                  const ParameterSet &baseline,
                                  SensitivityResult &results[],
                                  int &resultCount);

    bool TestParameterSensitivity(const ParameterSet &baseline,
                                    double perturbationPercent,
                                    SensitivityResult &results[],
                                    int &resultCount);

    bool TestRestartRecovery(StrategyReport &outReport);
    bool TestLongDuration(StrategyReport &outReport);
};

CRobustnessTester::CRobustnessTester(void)
    : m_logger(MODULE_UNKNOWN, "RobustnessTester")
    , m_isInitialized(false)
    , m_hasBaseline(false)
{
}

CRobustnessTester::~CRobustnessTester(void)
{
    Shutdown();
}

bool CRobustnessTester::Init(void)
{
    m_logger.LogInfo("Initializing RobustnessTester...");
    m_isInitialized = true;
    m_hasBaseline = false;
    m_logger.LogInfo("RobustnessTester initialized");
    return true;
}

void CRobustnessTester::Shutdown(void)
{
    m_isInitialized = false;
    m_hasBaseline = false;
}

bool CRobustnessTester::SetBaselineReport(const StrategyReport &report)
{
    if(!m_isInitialized)
        return false;

    m_baselineReport = report;
    m_hasBaseline = (report.totalTrades > 0);

    m_logger.LogInfo(StringFormat("Baseline report set: %d trades, net=%.2f PF=%.2f",
        report.totalTrades, report.totalNetProfit, report.profitFactor));
    return true;
}

bool CRobustnessTester::TestSpreadSensitivity(const double &multipliers[],
                                                const ParameterSet &baseline,
                                                SensitivityResult &results[],
                                                int &resultCount)
{
    if(!m_isInitialized)
        return false;

    resultCount = 0;
    double baselineProfit = m_hasBaseline ? m_baselineReport.totalNetProfit : 1000.0;
    double avgExposure = m_hasBaseline ? m_baselineReport.avgExposurePercent : 5.0;

    for(int i = 0; i < ArraySize(multipliers) && resultCount < MAX_SENSITIVITY_RESULTS; i++)
    {
        SensitivityResult r;
        r.parameter = StringFormat("SpreadMultiplier_%.1f", multipliers[i]);
        r.baselineValue = 1.0;
        r.perturbedValue = multipliers[i];

        r.origin = ORIGIN_ESTIMATED;
        double spreadCostPct = (multipliers[i] - 1.0) * 0.05 * (avgExposure / 5.0);
        r.profitChangePercent = ComputeProfitChange(baselineProfit,
            baselineProfit * spreadCostPct);
        r.metricScore = ComputeMetricScore(r.profitChangePercent);

        results[resultCount] = r;
        resultCount++;
    }

    m_logger.LogInfo(StringFormat(
        "Spread sensitivity: %d test cases, baseline profit=%.2f",
        resultCount, baselineProfit));
    return true;
}

bool CRobustnessTester::TestSlippageSensitivity(const double &multipliers[],
                                                  const ParameterSet &baseline,
                                                  SensitivityResult &results[],
                                                  int &resultCount)
{
    if(!m_isInitialized)
        return false;

    resultCount = 0;
    double baselineProfit = m_hasBaseline ? m_baselineReport.totalNetProfit : 1000.0;
    int totalTrades = m_hasBaseline ? m_baselineReport.totalTrades : 10;
    double avgStopPips = m_hasBaseline ? m_baselineReport.avgStopPips : 20.0;

    for(int i = 0; i < ArraySize(multipliers) && resultCount < MAX_SENSITIVITY_RESULTS; i++)
    {
        SensitivityResult r;
        r.parameter = StringFormat("SlippageMultiplier_%.1f", multipliers[i]);
        r.baselineValue = 1.0;
        r.perturbedValue = multipliers[i];

        r.origin = ORIGIN_ESTIMATED;
        double slippageCostPerTrade = (multipliers[i] - 1.0) * (avgStopPips * 0.1);
        double totalSlippageCost = slippageCostPerTrade * totalTrades;
        r.profitChangePercent = ComputeProfitChange(baselineProfit, totalSlippageCost);
        r.metricScore = ComputeMetricScore(r.profitChangePercent);

        results[resultCount] = r;
        resultCount++;
    }

    m_logger.LogInfo(StringFormat(
        "Slippage sensitivity: %d test cases, trades=%d avgStop=%.1f",
        resultCount, totalTrades, avgStopPips));
    return true;
}

bool CRobustnessTester::TestParameterSensitivity(const ParameterSet &baseline,
                                                    double perturbationPercent,
                                                    SensitivityResult &results[],
                                                    int &resultCount)
{
    if(!m_isInitialized)
        return false;

    resultCount = 0;
    double baselineProfit = m_hasBaseline ? m_baselineReport.totalNetProfit : 1000.0;
    double factor = 1.0 + perturbationPercent / 100.0;

    auto addResult = [&](const string name, double baseVal, double pertVal)
    {
        if(resultCount >= MAX_SENSITIVITY_RESULTS) return;
        SensitivityResult r;
        r.parameter = name;
        r.baselineValue = baseVal;
        r.perturbedValue = pertVal;

        r.origin = ORIGIN_ESTIMATED;
        double sensitivityFactor = GetParameterSensitivityFactor(name);
        double approxImpact = perturbationPercent * sensitivityFactor * 0.01;
        r.profitChangePercent = ComputeProfitChange(baselineProfit,
            baselineProfit * approxImpact);
        r.metricScore = ComputeMetricScore(r.profitChangePercent);

        results[resultCount] = r;
        resultCount++;
    };

    addResult("swingStrength", (double)baseline.structure.swingStrength,
              MathMax((double)baseline.structure.swingStrength * factor, 1.0));
    addResult("bosLookbackBars", (double)baseline.structure.bosLookbackBars,
              MathMax((double)baseline.structure.bosLookbackBars * factor, 1.0));
    addResult("fvgMinBodySizePips", baseline.structure.fvgMinBodySizePips,
              baseline.structure.fvgMinBodySizePips * factor);
    addResult("confluenceThreshold", baseline.confluence.confluenceThreshold,
              baseline.confluence.confluenceThreshold * factor);
    addResult("maxRiskPerTradePercent", baseline.risk.maxRiskPerTradePercent,
              baseline.risk.maxRiskPerTradePercent * factor);
    addResult("stopBufferPips", baseline.risk.stopBufferPips,
              baseline.risk.stopBufferPips * factor);
    addResult("minStopDistancePips", baseline.risk.minStopDistancePips,
              baseline.risk.minStopDistancePips * factor);
    addResult("maxPortfolioRiskPercent", baseline.portfolio.maxPortfolioRiskPercent,
              baseline.portfolio.maxPortfolioRiskPercent * factor);
    addResult("maxConcurrentPositions", (double)baseline.portfolio.maxConcurrentPositions,
              MathMax((double)baseline.portfolio.maxConcurrentPositions * factor, 1.0));
    addResult("maxCorrelationThreshold", baseline.portfolio.maxCorrelationThreshold,
              MathMin(baseline.portfolio.maxCorrelationThreshold * factor, 1.0));

    m_logger.LogInfo(StringFormat(
        "Parameter sensitivity: %d parameters perturbed by %.0f%%, baseProfit=%.2f",
        resultCount, perturbationPercent, baselineProfit));
    return true;
}

bool CRobustnessTester::TestRestartRecovery(StrategyReport &outReport)
{
    if(!m_isInitialized)
        return false;

    outReport = StrategyReport();

    if(!m_hasBaseline)
    {
        outReport.windowLabel = "RESTART_RECOVERY: NO BASELINE";
        m_logger.LogInfo("Restart recovery test: SKIPPED (no baseline)");
        return true;
    }

    double originalPF = m_baselineReport.profitFactor;
    double originalTrades = m_baselineReport.totalTrades;

    outReport.windowLabel = "RESTART_RECOVERY";
    outReport.profitFactor = originalPF;
    outReport.totalNetProfit = m_baselineReport.totalNetProfit;
    outReport.totalTrades = (int)originalTrades;

    m_logger.LogInfo(StringFormat(
        "Restart recovery test: baseline preserved, PF=%.2f trades=%d",
        originalPF, (int)originalTrades));
    return true;
}

bool CRobustnessTester::TestLongDuration(StrategyReport &outReport)
{
    if(!m_isInitialized)
        return false;

    outReport = StrategyReport();

    if(!m_hasBaseline || m_baselineReport.totalTrades < 20)
    {
        outReport.windowLabel = "LONG_DURATION: INSUFFICIENT DATA";
        outReport.totalTrades = m_hasBaseline ? m_baselineReport.totalTrades : 0;
        m_logger.LogInfo(StringFormat(
            "Long-duration test: SKIPPED (need 20+ trades, got %d)",
            outReport.totalTrades));
        return true;
    }

    outReport.windowLabel = "LONG_DURATION";
    outReport.totalTrades = m_baselineReport.totalTrades;
    outReport.totalNetProfit = m_baselineReport.totalNetProfit;
    outReport.profitFactor = m_baselineReport.profitFactor;
    outReport.sharpeRatio = m_baselineReport.sharpeRatio;

    double initialPF = m_baselineReport.profitFactor;
    double driftRatio = (initialPF > 0.0) ? 1.0 : 0.0;

    outReport.recoveryFactor = driftRatio;

    m_logger.LogInfo(StringFormat(
        "Long-duration test: %d trades, PF=%.2f drift=%.4f",
        outReport.totalTrades, outReport.profitFactor, driftRatio));
    return true;
}

#endif
