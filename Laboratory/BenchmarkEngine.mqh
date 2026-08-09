#ifndef __LABORATORY_BENCHMARK_ENGINE_MQH__
#define __LABORATORY_BENCHMARK_ENGINE_MQH__

#include "../Core/Logger.mqh"
#include "../Optimization/OptimizationTypes.mqh"
#include "LaboratoryTypes.mqh"

#define MAX_BENCHMARK_RESULTS 128

class CBenchmarkEngine
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    BenchmarkResult m_results[MAX_BENCHMARK_RESULTS];
    int             m_resultCount;

    double GetStrategyMetric(const StrategyReport &report,
                             ENUM_BENCHMARK_CLASS benchmarkClass) const;

public:
    CBenchmarkEngine(void);
    ~CBenchmarkEngine(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool CompareAgainstBenchmark(const StrategyReport &strategy,
                                  ENUM_BENCHMARK_CLASS benchmarkClass,
                                  double benchmarkValue,
                                  ENUM_CONFIDENCE_LEVEL confidence);

    bool CompareAllAgainstBenchmark(const StrategyReport strategies[], int count,
                                     ENUM_BENCHMARK_CLASS benchmarkClass,
                                     double benchmarkValue,
                                     ENUM_CONFIDENCE_LEVEL confidence);

    bool GetResult(int index, BenchmarkResult &out) const;
    int  GetResultCount(void) const { return m_resultCount; }

    void ClearResults(void);
};

CBenchmarkEngine::CBenchmarkEngine(void)
    : m_logger(MODULE_LABORATORY, "BenchmarkEngine")
    , m_isInitialized(false)
    , m_resultCount(0)
{
}

CBenchmarkEngine::~CBenchmarkEngine(void)
{
    Shutdown();
}

bool CBenchmarkEngine::Init(void)
{
    m_logger.LogInfo("Initializing BenchmarkEngine...");
    m_resultCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("BenchmarkEngine initialized");
    return true;
}

void CBenchmarkEngine::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_resultCount = 0;
    m_isInitialized = false;
}

double CBenchmarkEngine::GetStrategyMetric(const StrategyReport &report,
                                             ENUM_BENCHMARK_CLASS benchmarkClass) const
{
    switch(benchmarkClass)
    {
        case BENCHMARK_BUY_AND_HOLD:
        case BENCHMARK_MARKET_INDEX:
            return report.sharpeRatio;
        case BENCHMARK_RISK_FREE_RATE:
            return report.totalNetProfit;
        case BENCHMARK_STRATEGY_AVERAGE:
        case BENCHMARK_CUSTOM:
            return report.profitFactor;
        default:
            return report.sharpeRatio;
    }
}

bool CBenchmarkEngine::CompareAgainstBenchmark(const StrategyReport &strategy,
                                                 ENUM_BENCHMARK_CLASS benchmarkClass,
                                                 double benchmarkValue,
                                                 ENUM_CONFIDENCE_LEVEL confidence)
{
    if(!m_isInitialized || m_resultCount >= MAX_BENCHMARK_RESULTS)
        return false;

    double strategyValue = GetStrategyMetric(strategy, benchmarkClass);

    BenchmarkResult result;
    result.strategyId = strategy.experimentId;
    result.benchmarkClass = benchmarkClass;
    result.strategyScore = strategyValue;
    result.benchmarkScore = benchmarkValue;
    result.alpha = strategyValue - benchmarkValue;
    result.beta = (benchmarkValue != 0.0) ? strategyValue / benchmarkValue : 0.0;
    result.confidence = confidence;

    m_results[m_resultCount] = result;
    m_resultCount++;
    return true;
}

bool CBenchmarkEngine::CompareAllAgainstBenchmark(const StrategyReport strategies[], int count,
                                                    ENUM_BENCHMARK_CLASS benchmarkClass,
                                                    double benchmarkValue,
                                                    ENUM_CONFIDENCE_LEVEL confidence)
{
    if(!m_isInitialized) return false;

    for(int i = 0; i < count && m_resultCount < MAX_BENCHMARK_RESULTS; i++)
        CompareAgainstBenchmark(strategies[i], benchmarkClass, benchmarkValue, confidence);

    return true;
}

bool CBenchmarkEngine::GetResult(int index, BenchmarkResult &out) const
{
    if(index < 0 || index >= m_resultCount) return false;
    out = m_results[index];
    return true;
}

void CBenchmarkEngine::ClearResults(void)
{
    m_resultCount = 0;
}

#endif
