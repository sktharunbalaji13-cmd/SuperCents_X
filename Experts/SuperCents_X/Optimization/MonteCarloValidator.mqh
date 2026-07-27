#ifndef __OPTIMIZATION_MONTE_CARLO_VALIDATOR_MQH__
#define __OPTIMIZATION_MONTE_CARLO_VALIDATOR_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "../Monitoring/MonitoringTypes.mqh"
#include "OptimizationTypes.mqh"

class CMonteCarloValidator
{
private:
    CLogger  m_logger;
    bool     m_isInitialized;
    int      m_seed;

public:
    CMonteCarloValidator(void);
    ~CMonteCarloValidator(void);

    bool Init(int seed = 0);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool Reshuffle(const EventData &trades[],
                   int tradeCount,
                   int iterations,
                   double &outPercentile95,
                   double &outPercentile99,
                   double &outMedian);

    bool IsSignificant(const EventData &trades[],
                       int tradeCount,
                       int iterations,
                       double confidenceLevel,
                       bool &outSignificant);
};

CMonteCarloValidator::CMonteCarloValidator(void)
    : m_logger(MODULE_UNKNOWN, "MonteCarloValidator")
    , m_isInitialized(false)
    , m_seed(0)
{
}

CMonteCarloValidator::~CMonteCarloValidator(void)
{
    Shutdown();
}

bool CMonteCarloValidator::Init(int seed)
{
    m_logger.LogInfo("Initializing MonteCarloValidator...");
    m_seed = seed;
    if(m_seed == 0)
        m_seed = 12345;
    m_isInitialized = true;
    m_logger.LogInfo("MonteCarloValidator initialized");
    return true;
}

void CMonteCarloValidator::Shutdown(void)
{
    m_isInitialized = false;
}

bool CMonteCarloValidator::Reshuffle(const EventData &trades[],
                                      int tradeCount,
                                      int iterations,
                                      double &outPercentile95,
                                      double &outPercentile99,
                                      double &outMedian)
{
    if(!m_isInitialized || trades == NULL || tradeCount < 2 || iterations < 1)
        return false;

    double reshuffledProfits[];
    ArrayResize(reshuffledProfits, iterations);

    int currentSeed = m_seed;

    for(int iter = 0; iter < iterations; iter++)
    {
        double profits[];
        ArrayResize(profits, tradeCount);

        for(int i = 0; i < tradeCount; i++)
            profits[i] = trades[i].profit;

        currentSeed = (currentSeed * 1103515245 + 12345) & 0x7FFFFFFF;
        MathSrand(currentSeed);

        for(int i = tradeCount - 1; i > 0; i--)
        {
            int j = (int)(MathRand() / 32768.0 * (i + 1));
            if(j > i) j = i;
            double tmp = profits[i];
            profits[i] = profits[j];
            profits[j] = tmp;
        }

        double sum = 0.0;
        for(int i = 0; i < tradeCount; i++)
            sum += profits[i];
        reshuffledProfits[iter] = sum;
    }

    ArraySort(reshuffledProfits);

    int idx95 = (int)(iterations * 0.95);
    int idx99 = (int)(iterations * 0.99);
    int idx50 = (int)(iterations * 0.50);

    if(idx95 >= iterations) idx95 = iterations - 1;
    if(idx99 >= iterations) idx99 = iterations - 1;
    if(idx50 >= iterations) idx50 = iterations - 1;

    outPercentile95 = reshuffledProfits[idx95];
    outPercentile99 = reshuffledProfits[idx99];
    outMedian = reshuffledProfits[idx50];

    return true;
}

bool CMonteCarloValidator::IsSignificant(const EventData &trades[],
                                          int tradeCount,
                                          int iterations,
                                          double confidenceLevel,
                                          bool &outSignificant)
{
    if(!m_isInitialized || trades == NULL || tradeCount < 2)
        return false;

    double p95, p99, median;
    if(!Reshuffle(trades, tradeCount, iterations, p95, p99, median))
        return false;

    double originalProfit = 0.0;
    for(int i = 0; i < tradeCount; i++)
        originalProfit += trades[i].profit;

    double threshold = (confidenceLevel >= 0.95) ? p95 : median;
    outSignificant = (originalProfit > threshold);

    m_logger.LogInfo(StringFormat("MonteCarlo: original=%.2f p95=%.2f p99=%.2f median=%.2f significant=%s",
                                  originalProfit, p95, p99, median,
                                  outSignificant ? "YES" : "NO"));
    return true;
}

#endif
