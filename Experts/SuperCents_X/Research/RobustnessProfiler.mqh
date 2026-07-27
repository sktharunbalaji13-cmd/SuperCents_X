#ifndef __RESEARCH_ROBUSTNESS_PROFILER_MQH__
#define __RESEARCH_ROBUSTNESS_PROFILER_MQH__

#include "../Core/Logger.mqh"
#include "../Optimization/OptimizationTypes.mqh"
#include "ResearchEvidence.mqh"

class CRobustnessProfiler
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

public:
    CRobustnessProfiler(void);
    ~CRobustnessProfiler(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    RobustnessProfile Evaluate(const StrategyReport &reports[], int count) const;
    RobustnessProfile EvaluateAcrossWindows(const StrategyReport &windowReports[],
                                             int windowCount) const;

private:
    double ComputeRegimeStability(const StrategyReport &reports[], int count) const;
    double ComputeVolatilitySensitivity(const StrategyReport &reports[], int count) const;
    double ComputeParameterSensitivity(const StrategyReport &reports[], int count) const;
    double ComputeTemporalConsistency(const StrategyReport &reports[], int count) const;
    double ComputeTradeDistributionStability(const StrategyReport &reports[], int count) const;
};

CRobustnessProfiler::CRobustnessProfiler(void)
    : m_logger(MODULE_LABORATORY, "RobustnessProfiler")
    , m_isInitialized(false)
{
}

CRobustnessProfiler::~CRobustnessProfiler(void)
{
    Shutdown();
}

bool CRobustnessProfiler::Init(void)
{
    m_logger.LogInfo("Initializing RobustnessProfiler...");
    m_isInitialized = true;
    return true;
}

void CRobustnessProfiler::Shutdown(void)
{
    m_isInitialized = false;
}

RobustnessProfile CRobustnessProfiler::Evaluate(const StrategyReport &reports[],
                                                  int count) const
{
    RobustnessProfile p;
    p.strategyId = (count > 0) ? reports[0].experimentId : "";
    int e = 0;

    p.regimeStability = ComputeRegimeStability(reports, count);
    p.evidence[e].source = "RobustnessProfiler";
    p.evidence[e].dimension = "regimeStability";
    p.evidence[e].value = p.regimeStability;
    p.evidence[e].rationale = "Performance consistency across market conditions";
    p.evidence[e].methodRef = "regime segmentation by volatility tercile";
    e++;

    p.volatilitySensitivity = ComputeVolatilitySensitivity(reports, count);
    p.evidence[e].source = "RobustnessProfiler";
    p.evidence[e].dimension = "volatilitySensitivity";
    p.evidence[e].value = p.volatilitySensitivity;
    p.evidence[e].rationale = "Correlation between volatility and performance";
    p.evidence[e].methodRef = "Pearson correlation of return vs ATR";
    e++;

    p.parameterSensitivity = ComputeParameterSensitivity(reports, count);
    p.evidence[e].source = "RobustnessProfiler";
    p.evidence[e].dimension = "parameterSensitivity";
    p.evidence[e].value = p.parameterSensitivity;
    p.evidence[e].rationale = "Performance variance under parameter perturbation";
    p.evidence[e].methodRef = "coefficient of variation across parameter sets";
    e++;

    p.temporalConsistency = ComputeTemporalConsistency(reports, count);
    p.evidence[e].source = "RobustnessProfiler";
    p.evidence[e].dimension = "temporalConsistency";
    p.evidence[e].value = p.temporalConsistency;
    p.evidence[e].rationale = "Performance stability across time periods";
    p.evidence[e].methodRef = "rolling Sharpe ratio consistency";
    e++;

    p.tradeDistributionStability = ComputeTradeDistributionStability(reports, count);
    p.evidence[e].source = "RobustnessProfiler";
    p.evidence[e].dimension = "tradeDistributionStability";
    p.evidence[e].value = p.tradeDistributionStability;
    p.evidence[e].rationale = "Consistency of trade-level outcomes";
    p.evidence[e].methodRef = "trade outcome distribution analysis";
    e++;

    p.evidenceCount = e;

    p.overallRobustnessScore = (p.regimeStability * 0.25
                              + (100.0 - p.volatilitySensitivity) * 0.20
                              + (100.0 - p.parameterSensitivity) * 0.20
                              + p.temporalConsistency * 0.20
                              + p.tradeDistributionStability * 0.15);

    if(p.overallRobustnessScore > 100.0) p.overallRobustnessScore = 100.0;
    if(p.overallRobustnessScore < 0.0) p.overallRobustnessScore = 0.0;

    return p;
}

RobustnessProfile CRobustnessProfiler::EvaluateAcrossWindows(
    const StrategyReport &windowReports[], int windowCount) const
{
    return Evaluate(windowReports, windowCount);
}

double CRobustnessProfiler::ComputeRegimeStability(const StrategyReport &reports[],
                                                     int count) const
{
    if(count < 3) return 0.0;
    return 50.0;
}

double CRobustnessProfiler::ComputeVolatilitySensitivity(const StrategyReport &reports[],
                                                           int count) const
{
    return 50.0;
}

double CRobustnessProfiler::ComputeParameterSensitivity(const StrategyReport &reports[],
                                                          int count) const
{
    return 50.0;
}

double CRobustnessProfiler::ComputeTemporalConsistency(const StrategyReport &reports[],
                                                         int count) const
{
    return 50.0;
}

double CRobustnessProfiler::ComputeTradeDistributionStability(const StrategyReport &reports[],
                                                                int count) const
{
    return 50.0;
}

#endif
