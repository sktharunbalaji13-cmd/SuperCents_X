#ifndef __LABORATORY_STATISTICAL_ANALYZER_MQH__
#define __LABORATORY_STATISTICAL_ANALYZER_MQH__

#include "../Core/Logger.mqh"
#include "../Optimization/OptimizationTypes.mqh"
#include "LaboratoryTypes.mqh"

#define MAX_STATISTICAL_RESULTS 128

class CStatisticalAnalyzer
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    StatisticalSummary m_results[MAX_STATISTICAL_RESULTS];
    int                m_resultCount;

public:
    CStatisticalAnalyzer(void);
    ~CStatisticalAnalyzer(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool ComputeSummary(const double data[], int dataCount,
                        const string metricName,
                        ENUM_CONFIDENCE_LEVEL confidenceLevel,
                        StatisticalSummary &out) const;

    bool SignificanceTest(const double groupA[], int countA,
                          const double groupB[], int countB,
                          double &outPValue) const;

    bool ComputeConfidenceInterval(const double data[], int dataCount,
                                   double confidenceLevel,
                                   double &outLower, double &outUpper) const;

    bool CacheSummary(const StatisticalSummary &summary);
    bool GetSummary(int index, StatisticalSummary &out) const;
    int  GetCount(void) const { return m_resultCount; }

    void ClearResults(void);
};

CStatisticalAnalyzer::CStatisticalAnalyzer(void)
    : m_logger(MODULE_LABORATORY, "StatisticalAnalyzer")
    , m_isInitialized(false)
    , m_resultCount(0)
{
}

CStatisticalAnalyzer::~CStatisticalAnalyzer(void)
{
    Shutdown();
}

bool CStatisticalAnalyzer::Init(void)
{
    m_logger.LogInfo("Initializing StatisticalAnalyzer...");
    m_resultCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("StatisticalAnalyzer initialized");
    return true;
}

void CStatisticalAnalyzer::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_resultCount = 0;
    m_isInitialized = false;
}

bool CStatisticalAnalyzer::ComputeSummary(const double data[], int dataCount,
                                           const string metricName,
                                           ENUM_CONFIDENCE_LEVEL confidenceLevel,
                                           StatisticalSummary &out) const
{
    if(dataCount <= 0) return false;

    double sum = 0.0;
    for(int i = 0; i < dataCount; i++) sum += data[i];
    out.mean = sum / dataCount;

    double sorted[256];
    int sortCount = (dataCount > 256) ? 256 : dataCount;
    for(int i = 0; i < sortCount; i++) sorted[i] = data[i];

    for(int i = 0; i < sortCount - 1; i++)
        for(int j = 0; j < sortCount - 1 - i; j++)
            if(sorted[j] > sorted[j + 1])
            {
                double t = sorted[j];
                sorted[j] = sorted[j + 1];
                sorted[j + 1] = t;
            }

    out.median = (sortCount % 2 == 0)
        ? (sorted[sortCount / 2 - 1] + sorted[sortCount / 2]) / 2.0
        : sorted[sortCount / 2];

    out.min = sorted[0];
    out.max = sorted[sortCount - 1];

    double sumSq = 0.0;
    for(int i = 0; i < sortCount; i++)
        sumSq += (data[i] - out.mean) * (data[i] - out.mean);
    out.stdDev = (sortCount > 1)
        ? MathSqrt(sumSq / (sortCount - 1))
        : 0.0;

    out.sampleCount = sortCount;
    out.metricName = metricName;
    out.analysisId = metricName + "_" + IntegerToString(TimeCurrent());
    out.assumptions = "Normal distribution assumed; samples treated as independent";
    out.confidence = confidenceLevel;

    double zScore = 1.96;
    if(confidenceLevel == CONFIDENCE_LOW) zScore = 1.28;
    else if(confidenceLevel == CONFIDENCE_MODERATE) zScore = 1.645;
    else if(confidenceLevel == CONFIDENCE_HIGH) zScore = 1.96;
    else if(confidenceLevel == CONFIDENCE_VERY_HIGH) zScore = 2.576;

    double margin = zScore * out.stdDev / MathSqrt(sortCount);
    out.confidenceIntervalLower = out.mean - margin;
    out.confidenceIntervalUpper = out.mean + margin;

    return true;
}

bool CStatisticalAnalyzer::SignificanceTest(const double groupA[], int countA,
                                              const double groupB[], int countB,
                                              double &outPValue) const
{
    if(countA <= 1 || countB <= 1) return false;

    double meanA = 0.0, meanB = 0.0;
    for(int i = 0; i < countA; i++) meanA += groupA[i];
    for(int i = 0; i < countB; i++) meanB += groupB[i];
    meanA /= countA;
    meanB /= countB;

    double varA = 0.0, varB = 0.0;
    for(int i = 0; i < countA; i++) varA += (groupA[i] - meanA) * (groupA[i] - meanA);
    for(int i = 0; i < countB; i++) varB += (groupB[i] - meanB) * (groupB[i] - meanB);
    varA /= (countA - 1);
    varB /= (countB - 1);

    double pooledSE = MathSqrt(varA / countA + varB / countB);
    if(pooledSE == 0.0) { outPValue = 0.5; return true; }

    double tStat = (meanA - meanB) / pooledSE;
    double df = countA + countB - 2;
    outPValue = 2.0 * (1.0 - MathAbs(tStat) / MathSqrt(df + tStat * tStat));
    if(outPValue < 0.0) outPValue = 0.0;
    if(outPValue > 1.0) outPValue = 1.0;

    return true;
}

bool CStatisticalAnalyzer::ComputeConfidenceInterval(const double data[], int dataCount,
                                                       double confidenceLevel,
                                                       double &outLower, double &outUpper) const
{
    if(dataCount <= 1) return false;

    double sum = 0.0;
    for(int i = 0; i < dataCount; i++) sum += data[i];
    double mean = sum / dataCount;

    double sumSq = 0.0;
    for(int i = 0; i < dataCount; i++)
        sumSq += (data[i] - mean) * (data[i] - mean);
    double stdDev = MathSqrt(sumSq / (dataCount - 1));
    double sem = stdDev / MathSqrt(dataCount);

    double z = 1.96;
    if(confidenceLevel < 0.90) z = 1.28;
    else if(confidenceLevel < 0.95) z = 1.645;
    else if(confidenceLevel < 0.99) z = 1.96;
    else z = 2.576;

    outLower = mean - z * sem;
    outUpper = mean + z * sem;
    return true;
}

bool CStatisticalAnalyzer::CacheSummary(const StatisticalSummary &summary)
{
    if(!m_isInitialized || m_resultCount >= MAX_STATISTICAL_RESULTS)
        return false;
    m_results[m_resultCount] = summary;
    m_resultCount++;
    return true;
}

bool CStatisticalAnalyzer::GetSummary(int index, StatisticalSummary &out) const
{
    if(index < 0 || index >= m_resultCount) return false;
    out = m_results[index];
    return true;
}

void CStatisticalAnalyzer::ClearResults(void)
{
    m_resultCount = 0;
}

#endif
