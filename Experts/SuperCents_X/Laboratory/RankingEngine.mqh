#ifndef __LABORATORY_RANKING_ENGINE_MQH__
#define __LABORATORY_RANKING_ENGINE_MQH__

#include "../Core/Logger.mqh"
#include "../Optimization/OptimizationTypes.mqh"
#include "LaboratoryTypes.mqh"

class CRankingEngine
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    RankingResult m_result;

    double ComputeScore(const StrategyReport &report, ENUM_RANKING_METHOD method) const;
    double ComputeComposite(const StrategyReport &report,
                            const double weights[], int weightCount) const;

public:
    CRankingEngine(void);
    ~CRankingEngine(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool Rank(const StrategyReport &reports[], int reportCount,
              ENUM_RANKING_METHOD method);

    bool RankWithWeights(const StrategyReport &reports[], int reportCount,
                         const double weights[], int weightCount);

    RankingResult GetResult(void) const { return m_result; }
    bool GetEntry(int rank, RankingEntry &out) const;
};

CRankingEngine::CRankingEngine(void)
    : m_logger(MODULE_LABORATORY, "RankingEngine")
    , m_isInitialized(false)
{
}

CRankingEngine::~CRankingEngine(void)
{
    Shutdown();
}

bool CRankingEngine::Init(void)
{
    m_logger.LogInfo("Initializing RankingEngine...");
    m_result.entryCount = 0;
    m_result.method = RANKING_COMPOSITE;
    m_result.description = "";
    m_isInitialized = true;
    m_logger.LogInfo("RankingEngine initialized");
    return true;
}

void CRankingEngine::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_result.entryCount = 0;
    m_isInitialized = false;
}

double CRankingEngine::ComputeScore(const StrategyReport &report, ENUM_RANKING_METHOD method) const
{
    switch(method)
    {
        case RANKING_SHARPE:
            return report.sharpeRatio;
        case RANKING_SORTINO:
            return report.sortinoRatio;
        case RANKING_CALMAR:
            return report.calmarRatio;
        case RANKING_PROFIT_FACTOR:
            return report.profitFactor;
        case RANKING_RECOVERY_FACTOR:
            return report.recoveryFactor;
        case RANKING_ROBUSTNESS_SCORE:
            return report.monteCarloConfidence95;
        default:
            return 0.0;
    }
}

double CRankingEngine::ComputeComposite(const StrategyReport &report,
                                         const double weights[], int weightCount) const
{
    if(weightCount < 7) return 0.0;

    return weights[0] * report.sharpeRatio
         + weights[1] * report.sortinoRatio
         + weights[2] * report.calmarRatio
         + weights[3] * report.profitFactor
         + weights[4] * report.recoveryFactor
         + weights[5] * report.winRate
         + weights[6] * (1.0 - report.maxDrawdownPercent / 100.0);
}

bool CRankingEngine::Rank(const StrategyReport &reports[], int reportCount,
                           ENUM_RANKING_METHOD method)
{
    if(!m_isInitialized || reportCount <= 0 || reportCount > 256)
        return false;

    m_result.entryCount = reportCount;
    m_result.method = method;
    m_result.description = StringFormat("Ranking by %d", method);

    for(int i = 0; i < reportCount; i++)
    {
        m_result.entries[i].strategyId = reports[i].experimentId;
        m_result.entries[i].score = ComputeScore(reports[i], method);
        m_result.entries[i].method = method;
        m_result.entries[i].confidence = CONFIDENCE_MODERATE;
    }

    for(int i = 0; i < reportCount - 1; i++)
    {
        for(int j = 0; j < reportCount - 1 - i; j++)
        {
            if(m_result.entries[j].score < m_result.entries[j + 1].score)
            {
                RankingEntry temp = m_result.entries[j];
                m_result.entries[j] = m_result.entries[j + 1];
                m_result.entries[j + 1] = temp;
            }
        }
    }

    for(int i = 0; i < reportCount; i++)
        m_result.entries[i].rank = i + 1;

    return true;
}

bool CRankingEngine::RankWithWeights(const StrategyReport &reports[], int reportCount,
                                      const double weights[], int weightCount)
{
    if(!m_isInitialized || reportCount <= 0 || reportCount > 256 || weightCount < 7)
        return false;

    m_result.entryCount = reportCount;
    m_result.method = RANKING_COMPOSITE;
    m_result.description = "Composite ranking with custom weights";

    for(int i = 0; i < reportCount; i++)
    {
        m_result.entries[i].strategyId = reports[i].experimentId;
        m_result.entries[i].score = ComputeComposite(reports[i], weights, weightCount);
        m_result.entries[i].method = RANKING_COMPOSITE;
        m_result.entries[i].confidence = CONFIDENCE_MODERATE;
    }

    for(int i = 0; i < reportCount - 1; i++)
    {
        for(int j = 0; j < reportCount - 1 - i; j++)
        {
            if(m_result.entries[j].score < m_result.entries[j + 1].score)
            {
                RankingEntry temp = m_result.entries[j];
                m_result.entries[j] = m_result.entries[j + 1];
                m_result.entries[j + 1] = temp;
            }
        }
    }

    for(int i = 0; i < reportCount; i++)
        m_result.entries[i].rank = i + 1;

    return true;
}

bool CRankingEngine::GetEntry(int rank, RankingEntry &out) const
{
    if(rank < 1 || rank > m_result.entryCount) return false;
    out = m_result.entries[rank - 1];
    return true;
}

#endif
