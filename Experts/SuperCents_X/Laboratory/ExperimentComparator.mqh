#ifndef __LABORATORY_EXPERIMENT_COMPARATOR_MQH__
#define __LABORATORY_EXPERIMENT_COMPARATOR_MQH__

#include "../Core/Logger.mqh"
#include "../Optimization/OptimizationTypes.mqh"
#include "LaboratoryTypes.mqh"
#include "ArtifactRepository.mqh"

#define MAX_COMPARISON_RESULTS 256

class CExperimentComparator
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    ComparisonResult m_results[MAX_COMPARISON_RESULTS];
    int              m_resultCount;

    double ComputeRatio(double left, double right) const;

public:
    CExperimentComparator(void);
    ~CExperimentComparator(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool ComparePairwise(const StrategyReport &left,
                         const StrategyReport &right,
                         const string metric);

    bool CompareAgainstGroup(const StrategyReport &target,
                             const StrategyReport &group[], int groupSize,
                             const string metric);

    bool GetResult(int index, ComparisonResult &out) const;
    int  GetResultCount(void) const { return m_resultCount; }

    void ClearResults(void);
};

CExperimentComparator::CExperimentComparator(void)
    : m_logger(MODULE_LABORATORY, "ExperimentComparator")
    , m_isInitialized(false)
    , m_resultCount(0)
{
}

CExperimentComparator::~CExperimentComparator(void)
{
    Shutdown();
}

bool CExperimentComparator::Init(void)
{
    m_logger.LogInfo("Initializing ExperimentComparator...");
    m_resultCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("ExperimentComparator initialized");
    return true;
}

void CExperimentComparator::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_resultCount = 0;
    m_isInitialized = false;
}

double CExperimentComparator::ComputeRatio(double left, double right) const
{
    if(right == 0.0) return (left == 0.0) ? 1.0 : 0.0;
    return left / right;
}

bool CExperimentComparator::ComparePairwise(const StrategyReport &left,
                                             const StrategyReport &right,
                                             const string metric)
{
    if(!m_isInitialized || m_resultCount >= MAX_COMPARISON_RESULTS)
        return false;

    double leftVal = 0.0, rightVal = 0.0;

    if(metric == "profitFactor")
    {
        leftVal = left.profitFactor;
        rightVal = right.profitFactor;
    }
    else if(metric == "sharpeRatio")
    {
        leftVal = left.sharpeRatio;
        rightVal = right.sharpeRatio;
    }
    else if(metric == "sortinoRatio")
    {
        leftVal = left.sortinoRatio;
        rightVal = right.sortinoRatio;
    }
    else if(metric == "calmarRatio")
    {
        leftVal = left.calmarRatio;
        rightVal = right.calmarRatio;
    }
    else if(metric == "recoveryFactor")
    {
        leftVal = left.recoveryFactor;
        rightVal = right.recoveryFactor;
    }
    else if(metric == "winRate")
    {
        leftVal = left.winRate;
        rightVal = right.winRate;
    }
    else if(metric == "totalNetProfit")
    {
        leftVal = left.totalNetProfit;
        rightVal = right.totalNetProfit;
    }
    else if(metric == "maxDrawdown")
    {
        leftVal = left.maxDrawdownPercent;
        rightVal = right.maxDrawdownPercent;
    }
    else
    {
        return false;
    }

    ComparisonResult result;
    result.leftId = left.experimentId;
    result.rightId = right.experimentId;
    result.type = COMPARISON_PAIRWISE;
    result.score = ComputeRatio(leftVal, rightVal);
    result.metricUsed = metric;
    result.conclusion = StringFormat("%s=%f vs %s=%f (ratio=%.4f)",
                                     left.experimentId, leftVal,
                                     right.experimentId, rightVal,
                                     result.score);
    m_results[m_resultCount] = result;
    m_resultCount++;
    return true;
}

bool CExperimentComparator::CompareAgainstGroup(const StrategyReport &target,
                                                  const StrategyReport &group[], int groupSize,
                                                  const string metric)
{
    if(!m_isInitialized || groupSize <= 0 || m_resultCount >= MAX_COMPARISON_RESULTS)
        return false;

    double targetVal = 0.0;

    if(metric == "profitFactor") targetVal = target.profitFactor;
    else if(metric == "sharpeRatio") targetVal = target.sharpeRatio;
    else if(metric == "sortinoRatio") targetVal = target.sortinoRatio;
    else if(metric == "calmarRatio") targetVal = target.calmarRatio;
    else if(metric == "recoveryFactor") targetVal = target.recoveryFactor;
    else if(metric == "winRate") targetVal = target.winRate;
    else if(metric == "totalNetProfit") targetVal = target.totalNetProfit;
    else if(metric == "maxDrawdown") targetVal = target.maxDrawdownPercent;
    else return false;

    double sum = 0.0;
    for(int i = 0; i < groupSize; i++)
    {
        if(metric == "profitFactor") sum += group[i].profitFactor;
        else if(metric == "sharpeRatio") sum += group[i].sharpeRatio;
        else if(metric == "sortinoRatio") sum += group[i].sortinoRatio;
        else if(metric == "calmarRatio") sum += group[i].calmarRatio;
        else if(metric == "recoveryFactor") sum += group[i].recoveryFactor;
        else if(metric == "winRate") sum += group[i].winRate;
        else if(metric == "totalNetProfit") sum += group[i].totalNetProfit;
        else if(metric == "maxDrawdown") sum += group[i].maxDrawdownPercent;
    }

    double groupAvg = sum / groupSize;

    ComparisonResult result;
    result.leftId = target.experimentId;
    result.rightId = "GROUP_AVERAGE";
    result.type = COMPARISON_GROUP;
    result.score = ComputeRatio(targetVal, groupAvg);
    result.metricUsed = metric;
    result.conclusion = StringFormat("%s=%f vs groupAvg=%f (ratio=%.4f, n=%d)",
                                     target.experimentId, targetVal,
                                     groupAvg, result.score, groupSize);
    m_results[m_resultCount] = result;
    m_resultCount++;
    return true;
}

bool CExperimentComparator::GetResult(int index, ComparisonResult &out) const
{
    if(index < 0 || index >= m_resultCount) return false;
    out = m_results[index];
    return true;
}

void CExperimentComparator::ClearResults(void)
{
    m_resultCount = 0;
}

#endif
