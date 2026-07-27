#ifndef __RESEARCH_BENCHMARK_FRAMEWORK_MQH__
#define __RESEARCH_BENCHMARK_FRAMEWORK_MQH__

#include "../Core/Logger.mqh"
#include "../Optimization/StrategyAnalytics.mqh"
#include "../Trading/TradingEvidence.mqh"
#include "ResearchEvidence.mqh"

#define MAX_BENCHMARK_RESULTS 128

class CBenchmarkFramework
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    BenchmarkResult m_results[MAX_BENCHMARK_RESULTS];
    int             m_resultCount;

public:
    CBenchmarkFramework(void);
    ~CBenchmarkFramework(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool CompareBaseline(const StrategyReport &strategy,
                         const StrategyReport &baseline);

    bool ComparePreviousVersion(const StrategyReport &current,
                                const StrategyReport &previous);

    bool CompareParameterVariant(const StrategyReport &variant,
                                 const StrategyReport &reference);

    bool CompareMarketRegime(const StrategyReport &strategy,
                             const string regimeLabel,
                             double regimeMetric,
                             double overallMetric);

    bool GetResult(int index, BenchmarkResult &out) const;
    int  GetResultCount(void) const { return m_resultCount; }

    void Clear(void);
};

CBenchmarkFramework::CBenchmarkFramework(void)
    : m_logger(MODULE_LABORATORY, "BenchmarkFramework")
    , m_isInitialized(false)
    , m_resultCount(0)
{
}

CBenchmarkFramework::~CBenchmarkFramework(void)
{
    Shutdown();
}

bool CBenchmarkFramework::Init(void)
{
    m_logger.LogInfo("Initializing BenchmarkFramework...");
    m_resultCount = 0;
    m_isInitialized = true;
    return true;
}

void CBenchmarkFramework::Shutdown(void)
{
    m_isInitialized = false;
}

bool CBenchmarkFramework::CompareBaseline(const StrategyReport &strategy,
                                           const StrategyReport &baseline)
{
    if(!m_isInitialized || m_resultCount >= MAX_BENCHMARK_RESULTS)
        return false;

    BenchmarkResult r;
    r.strategyId = strategy.experimentId;
    r.benchmarkType = BENCHMARK_BASELINE;
    r.strategyScore = strategy.sharpeRatio;
    r.referenceScore = baseline.sharpeRatio;
    r.delta = r.strategyScore - r.referenceScore;
    r.deltaPercent = (baseline.sharpeRatio != 0.0)
        ? (r.delta / baseline.sharpeRatio) * 100.0 : 0.0;

    int e = 0;
    r.evidence[e].source = "BenchmarkFramework";
    r.evidence[e].dimension = "sharpeRatio";
    r.evidence[e].value = r.delta;
    r.evidence[e].rationale = "Sharpe ratio delta vs baseline";
    r.evidence[e].methodRef = "baseline comparison";
    e++;
    r.evidenceCount = e;

    m_results[m_resultCount] = r;
    m_resultCount++;
    return true;
}

bool CBenchmarkFramework::ComparePreviousVersion(const StrategyReport &current,
                                                   const StrategyReport &previous)
{
    if(!m_isInitialized || m_resultCount >= MAX_BENCHMARK_RESULTS)
        return false;

    BenchmarkResult r;
    r.strategyId = current.experimentId;
    r.benchmarkType = BENCHMARK_PREVIOUS_VERSION;
    r.strategyScore = current.sharpeRatio;
    r.referenceScore = previous.sharpeRatio;
    r.delta = r.strategyScore - r.referenceScore;
    r.deltaPercent = (previous.sharpeRatio != 0.0)
        ? (r.delta / previous.sharpeRatio) * 100.0 : 0.0;

    int e = 0;
    r.evidence[e].source = "BenchmarkFramework";
    r.evidence[e].dimension = "sharpeRatio";
    r.evidence[e].value = r.delta;
    r.evidence[e].rationale = "Sharpe ratio delta vs previous version";
    r.evidence[e].methodRef = "version-to-version comparison";
    e++;
    r.evidenceCount = e;

    m_results[m_resultCount] = r;
    m_resultCount++;
    return true;
}

bool CBenchmarkFramework::CompareParameterVariant(const StrategyReport &variant,
                                                    const StrategyReport &reference)
{
    if(!m_isInitialized || m_resultCount >= MAX_BENCHMARK_RESULTS)
        return false;

    BenchmarkResult r;
    r.strategyId = variant.experimentId;
    r.benchmarkType = BENCHMARK_PARAMETER_VARIANT;
    r.strategyScore = variant.profitFactor;
    r.referenceScore = reference.profitFactor;
    r.delta = r.strategyScore - r.referenceScore;
    r.deltaPercent = (reference.profitFactor != 0.0)
        ? (r.delta / reference.profitFactor) * 100.0 : 0.0;

    int e = 0;
    r.evidence[e].source = "BenchmarkFramework";
    r.evidence[e].dimension = "profitFactor";
    r.evidence[e].value = r.delta;
    r.evidence[e].rationale = "Profit factor delta vs reference parameter set";
    r.evidence[e].methodRef = "parameter variant comparison";
    e++;
    r.evidenceCount = e;

    m_results[m_resultCount] = r;
    m_resultCount++;
    return true;
}

bool CBenchmarkFramework::CompareMarketRegime(const StrategyReport &strategy,
                                                const string regimeLabel,
                                                double regimeMetric,
                                                double overallMetric)
{
    if(!m_isInitialized || m_resultCount >= MAX_BENCHMARK_RESULTS)
        return false;

    BenchmarkResult r;
    r.strategyId = strategy.experimentId + "|" + regimeLabel;
    r.benchmarkType = BENCHMARK_MARKET_REGIME;
    r.strategyScore = regimeMetric;
    r.referenceScore = overallMetric;
    r.delta = r.strategyScore - r.referenceScore;
    r.deltaPercent = (overallMetric != 0.0)
        ? (r.delta / overallMetric) * 100.0 : 0.0;

    int e = 0;
    r.evidence[e].source = "BenchmarkFramework";
    r.evidence[e].dimension = "regime_" + regimeLabel;
    r.evidence[e].value = r.delta;
    r.evidence[e].rationale = "Performance in " + regimeLabel + " regime vs overall";
    r.evidence[e].methodRef = "market regime comparison";
    e++;
    r.evidenceCount = e;

    m_results[m_resultCount] = r;
    m_resultCount++;
    return true;
}

bool CBenchmarkFramework::GetResult(int index, BenchmarkResult &out) const
{
    if(index < 0 || index >= m_resultCount) return false;
    out = m_results[index];
    return true;
}

void CBenchmarkFramework::Clear(void)
{
    m_resultCount = 0;
}

#endif
