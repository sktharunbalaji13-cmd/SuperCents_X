#ifndef __RESEARCH_STATISTICAL_VALIDATOR_MQH__
#define __RESEARCH_STATISTICAL_VALIDATOR_MQH__

#include "../Core/Logger.mqh"
#include "ResearchEvidence.mqh"

#define MAX_STAT_SAMPLES 1024

class CStatisticalValidator
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

public:
    CStatisticalValidator(void);
    ~CStatisticalValidator(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    double ComputeConfidenceInterval(const double data[], int count,
                                     double confidenceLevel,
                                     double &outLower, double &outUpper) const;

    double ComputeEffectSizeCohenD(const double groupA[], int countA,
                                    const double groupB[], int countB) const;

    double ComputeEffectSizeHedgesG(const double groupA[], int countA,
                                     const double groupB[], int countB) const;

    double ComputeSkewness(const double data[], int count) const;
    double ComputeKurtosis(const double data[], int count) const;
    double ComputeCoefficientOfVariation(const double data[], int count) const;

    double ComputePValue(const double groupA[], int countA,
                         const double groupB[], int countB) const;

    bool   Summarize(const double data[], int count,
                     const string metricName,
                     ResearchEvidence &evidence[], int &evidenceCount) const;
};

CStatisticalValidator::CStatisticalValidator(void)
    : m_logger(MODULE_LABORATORY, "StatisticalValidator")
    , m_isInitialized(false)
{
}

CStatisticalValidator::~CStatisticalValidator(void)
{
    Shutdown();
}

bool CStatisticalValidator::Init(void)
{
    m_logger.LogInfo("Initializing StatisticalValidator...");
    m_isInitialized = true;
    return true;
}

void CStatisticalValidator::Shutdown(void)
{
    m_isInitialized = false;
}

double CStatisticalValidator::ComputeConfidenceInterval(const double data[], int count,
                                                         double confidenceLevel,
                                                         double &outLower,
                                                         double &outUpper) const
{
    if(count <= 1) { outLower = 0; outUpper = 0; return 0; }

    double sum = 0;
    for(int i = 0; i < count; i++) sum += data[i];
    double mean = sum / count;

    double sumSq = 0;
    for(int i = 0; i < count; i++) sumSq += (data[i] - mean) * (data[i] - mean);
    double stdDev = MathSqrt(sumSq / (count - 1));
    double sem = stdDev / MathSqrt(count);

    double z = 1.96;
    if(confidenceLevel < 0.90) z = 1.28;
    else if(confidenceLevel < 0.95) z = 1.645;
    else if(confidenceLevel < 0.99) z = 1.96;
    else z = 2.576;

    outLower = mean - z * sem;
    outUpper = mean + z * sem;
    return mean;
}

double CStatisticalValidator::ComputeEffectSizeCohenD(const double groupA[], int countA,
                                                       const double groupB[],
                                                       int countB) const
{
    if(countA < 2 || countB < 2) return 0;

    double meanA = 0, meanB = 0;
    for(int i = 0; i < countA; i++) meanA += groupA[i];
    for(int i = 0; i < countB; i++) meanB += groupB[i];
    meanA /= countA;
    meanB /= countB;

    double varA = 0, varB = 0;
    for(int i = 0; i < countA; i++) varA += (groupA[i] - meanA) * (groupA[i] - meanA);
    for(int i = 0; i < countB; i++) varB += (groupB[i] - meanB) * (groupB[i] - meanB);
    varA /= (countA - 1);
    varB /= (countB - 1);

    double pooledStdDev = MathSqrt(((countA - 1) * varA + (countB - 1) * varB)
                                    / (countA + countB - 2));

    if(pooledStdDev == 0) return 0;
    return (meanA - meanB) / pooledStdDev;
}

double CStatisticalValidator::ComputeEffectSizeHedgesG(const double groupA[], int countA,
                                                        const double groupB[],
                                                        int countB) const
{
    double d = ComputeEffectSizeCohenD(groupA, countA, groupB, countB);
    double correction = 1.0 - (3.0 / (4.0 * (countA + countB) - 9.0));
    return d * correction;
}

double CStatisticalValidator::ComputeSkewness(const double data[], int count) const
{
    if(count < 3) return 0;

    double sum = 0;
    for(int i = 0; i < count; i++) sum += data[i];
    double mean = sum / count;

    double sumSq = 0, sumCb = 0;
    for(int i = 0; i < count; i++)
    {
        double dev = data[i] - mean;
        sumSq += dev * dev;
        sumCb += dev * dev * dev;
    }

    double variance = sumSq / (count - 1);
    if(variance <= 0) return 0;

    double stdDev = MathSqrt(variance);
    return (sumCb / count) / (stdDev * stdDev * stdDev);
}

double CStatisticalValidator::ComputeKurtosis(const double data[], int count) const
{
    if(count < 4) return 0;

    double sum = 0;
    for(int i = 0; i < count; i++) sum += data[i];
    double mean = sum / count;

    double sumSq = 0, sumQt = 0;
    for(int i = 0; i < count; i++)
    {
        double dev = data[i] - mean;
        sumSq += dev * dev;
        sumQt += dev * dev * dev * dev;
    }

    double variance = sumSq / (count - 1);
    if(variance <= 0) return 0;

    double stdDev = MathSqrt(variance);
    return (sumQt / count) / (stdDev * stdDev * stdDev * stdDev) - 3.0;
}

double CStatisticalValidator::ComputeCoefficientOfVariation(const double data[],
                                                              int count) const
{
    if(count < 2) return 0;

    double sum = 0;
    for(int i = 0; i < count; i++) sum += data[i];
    double mean = sum / count;
    if(mean == 0) return 0;

    double sumSq = 0;
    for(int i = 0; i < count; i++) sumSq += (data[i] - mean) * (data[i] - mean);
    double stdDev = MathSqrt(sumSq / (count - 1));

    return stdDev / mean;
}

double CStatisticalValidator::ComputePValue(const double groupA[], int countA,
                                             const double groupB[], int countB) const
{
    if(countA < 2 || countB < 2) return 0.5;

    double meanA = 0, meanB = 0;
    for(int i = 0; i < countA; i++) meanA += groupA[i];
    for(int i = 0; i < countB; i++) meanB += groupB[i];
    meanA /= countA;
    meanB /= countB;

    double varA = 0, varB = 0;
    for(int i = 0; i < countA; i++) varA += (groupA[i] - meanA) * (groupA[i] - meanA);
    for(int i = 0; i < countB; i++) varB += (groupB[i] - meanB) * (groupB[i] - meanB);
    varA /= (countA - 1);
    varB /= (countB - 1);

    double pooledSE = MathSqrt(varA / countA + varB / countB);
    if(pooledSE == 0) return 0.5;

    double tStat = (meanA - meanB) / pooledSE;
    double df = countA + countB - 2;
    double p = 2.0 * (1.0 - MathAbs(tStat) / MathSqrt(df + tStat * tStat));
    if(p < 0) p = 0;
    if(p > 1) p = 1;
    return p;
}

bool CStatisticalValidator::Summarize(const double data[], int count,
                                       const string metricName,
                                       ResearchEvidence &evidence[],
                                       int &evidenceCount) const
{
    if(count < 1) return false;

    double sum = 0;
    for(int i = 0; i < count; i++) sum += data[i];
    double mean = sum / count;

    double sorted[256];
    int sc = (count > 256) ? 256 : count;
    for(int i = 0; i < sc; i++) sorted[i] = data[i];
    for(int i = 0; i < sc - 1; i++)
        for(int j = 0; j < sc - 1 - i; j++)
            if(sorted[j] > sorted[j + 1])
            {
                double t = sorted[j]; sorted[j] = sorted[j + 1]; sorted[j + 1] = t;
            }

    double median = (sc % 2 == 0)
        ? (sorted[sc / 2 - 1] + sorted[sc / 2]) / 2.0
        : sorted[sc / 2];

    double sumSq = 0;
    for(int i = 0; i < sc; i++) sumSq += (data[i] - mean) * (data[i] - mean);
    double stdDev = (sc > 1) ? MathSqrt(sumSq / (sc - 1)) : 0;

    double ciLower, ciUpper;
    ComputeConfidenceInterval(data, count, 0.95, ciLower, ciUpper);

    int e = evidenceCount;
    if(e + 6 > 32) return false;

    evidence[e].source = "StatisticalValidator";
    evidence[e].dimension = metricName + ".mean";
    evidence[e].value = mean;
    evidence[e].rationale = "Sample mean";
    evidence[e].methodRef = "arithmetic mean";
    e++;

    evidence[e].source = "StatisticalValidator";
    evidence[e].dimension = metricName + ".median";
    evidence[e].value = median;
    evidence[e].rationale = "Sample median";
    evidence[e].methodRef = "sorted middle value";
    e++;

    evidence[e].source = "StatisticalValidator";
    evidence[e].dimension = metricName + ".stdDev";
    evidence[e].value = stdDev;
    evidence[e].rationale = "Sample standard deviation (n-1)";
    evidence[e].methodRef = "Bessel-corrected std dev";
    e++;

    evidence[e].source = "StatisticalValidator";
    evidence[e].dimension = metricName + ".ci95.lower";
    evidence[e].value = ciLower;
    evidence[e].rationale = "95% confidence interval lower bound";
    evidence[e].methodRef = "normal approximation, z=1.96";
    e++;

    evidence[e].source = "StatisticalValidator";
    evidence[e].dimension = metricName + ".ci95.upper";
    evidence[e].value = ciUpper;
    evidence[e].rationale = "95% confidence interval upper bound";
    evidence[e].methodRef = "normal approximation, z=1.96";
    e++;

    evidence[e].source = "StatisticalValidator";
    evidence[e].dimension = metricName + ".cv";
    evidence[e].value = (mean != 0) ? stdDev / mean : 0;
    evidence[e].rationale = "Coefficient of variation";
    evidence[e].methodRef = "stdDev / mean";
    e++;

    evidenceCount = e;
    return true;
}

#endif
