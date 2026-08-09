#ifndef __LABORATORY_ROBUSTNESS_ANALYZER_MQH__
#define __LABORATORY_ROBUSTNESS_ANALYZER_MQH__

#include "../Core/Logger.mqh"
#include "../Optimization/OptimizationTypes.mqh"
#include "LaboratoryTypes.mqh"

class CRobustnessAnalyzer
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

public:
    CRobustnessAnalyzer(void);
    ~CRobustnessAnalyzer(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    double ComputeRobustnessScore(const StrategyReport &windowReports[], int windowCount) const;
    double ComputeStabilityIndex(const StrategyReport &windowReports[], int windowCount) const;
    bool   RegimePerformance(const StrategyReport &reports[], int count,
                             double &outTrend, double &outRanging, double &outVolatile) const;
};

CRobustnessAnalyzer::CRobustnessAnalyzer(void)
    : m_logger(MODULE_LABORATORY, "RobustnessAnalyzer")
    , m_isInitialized(false)
{
}

CRobustnessAnalyzer::~CRobustnessAnalyzer(void)
{
    Shutdown();
}

bool CRobustnessAnalyzer::Init(void)
{
    m_logger.LogInfo("Initializing RobustnessAnalyzer...");
    m_isInitialized = true;
    m_logger.LogInfo("RobustnessAnalyzer initialized");
    return true;
}

void CRobustnessAnalyzer::Shutdown(void)
{
    m_isInitialized = false;
}

double CRobustnessAnalyzer::ComputeRobustnessScore(const StrategyReport &windowReports[],
                                                     int windowCount) const
{
    if(windowCount <= 0) return 0.0;

    double avgProfitFactor = 0.0;
    double avgSharpe = 0.0;
    double avgRecovery = 0.0;
    double maxDrawdown = 0.0;

    for(int i = 0; i < windowCount; i++)
    {
        avgProfitFactor += windowReports[i].profitFactor;
        avgSharpe += windowReports[i].sharpeRatio;
        avgRecovery += windowReports[i].recoveryFactor;
        if(windowReports[i].maxDrawdownPercent > maxDrawdown)
            maxDrawdown = windowReports[i].maxDrawdownPercent;
    }

    avgProfitFactor /= windowCount;
    avgSharpe /= windowCount;
    avgRecovery /= windowCount;

    double consistencyScore = 0.0;
    if(maxDrawdown > 0.0)
        consistencyScore = (avgSharpe * avgProfitFactor * avgRecovery) / (1.0 + maxDrawdown / 100.0);

    return consistencyScore;
}

double CRobustnessAnalyzer::ComputeStabilityIndex(const StrategyReport &windowReports[],
                                                    int windowCount) const
{
    if(windowCount <= 1) return 1.0;

    double sum = 0.0, sumSq = 0.0;
    for(int i = 0; i < windowCount; i++)
    {
        double val = windowReports[i].sharpeRatio;
        sum += val;
        sumSq += val * val;
    }

    double mean = sum / windowCount;
    double variance = (sumSq / windowCount) - (mean * mean);
    if(variance < 0.0) variance = 0.0;
    double stdDev = MathSqrt(variance);

    if(mean == 0.0) return 0.0;
    return 1.0 - (stdDev / MathAbs(mean));
}

bool CRobustnessAnalyzer::RegimePerformance(const StrategyReport &reports[], int count,
                                              double &outTrend, double &outRanging,
                                              double &outVolatile) const
{
    if(count < 3) return false;

    int each = count / 3;
    outTrend = 0.0;
    outRanging = 0.0;
    outVolatile = 0.0;

    for(int i = 0; i < each && i < count; i++)
        outTrend += reports[i].sharpeRatio;
    outTrend /= each;

    for(int i = each; i < 2 * each && i < count; i++)
        outRanging += reports[i].sharpeRatio;
    outRanging /= each;

    for(int i = 2 * each; i < count; i++)
        outVolatile += reports[i].sharpeRatio;
    outVolatile /= (count - 2 * each);

    return true;
}

#endif
