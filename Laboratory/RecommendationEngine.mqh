#ifndef __LABORATORY_RECOMMENDATION_ENGINE_MQH__
#define __LABORATORY_RECOMMENDATION_ENGINE_MQH__

#include "../Core/Logger.mqh"
#include "LaboratoryTypes.mqh"
#include "RankingEngine.mqh"
#include "StatisticalAnalyzer.mqh"

#define MAX_RECOMMENDATIONS 64

class CRecommendationEngine
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    RecommendationRecord m_recommendations[MAX_RECOMMENDATIONS];
    int                  m_recommendationCount;

    ENUM_RECOMMENDATION_STATUS ScoreToRecommendation(double score,
                                                      ENUM_CONFIDENCE_LEVEL confidence) const;
    void AddEvidenceRef(RecommendationRecord &rec, const string ref);

public:
    CRecommendationEngine(void);
    ~CRecommendationEngine(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool GenerateFromRanking(const RankingResult &ranking,
                              int topCount);
    bool GenerateFromStatisticalSummary(const StatisticalSummary &summary,
                                         const string strategyId,
                                         double threshold);
    bool GenerateFromBenchmark(const BenchmarkResult &benchmark);

    bool GetRecommendation(int index, RecommendationRecord &out) const;
    int  GetRecommendationCount(void) const { return m_recommendationCount; }

    void Clear(void);
};

CRecommendationEngine::CRecommendationEngine(void)
    : m_logger(MODULE_LABORATORY, "RecommendationEngine")
    , m_isInitialized(false)
    , m_recommendationCount(0)
{
}

CRecommendationEngine::~CRecommendationEngine(void)
{
    Shutdown();
}

bool CRecommendationEngine::Init(void)
{
    m_logger.LogInfo("Initializing RecommendationEngine...");
    m_recommendationCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("RecommendationEngine initialized");
    return true;
}

void CRecommendationEngine::Shutdown(void)
{
    if(!m_isInitialized) return;
    Clear();
    m_isInitialized = false;
}

ENUM_RECOMMENDATION_STATUS CRecommendationEngine::ScoreToRecommendation(
    double score, ENUM_CONFIDENCE_LEVEL confidence) const
{
    if(confidence <= CONFIDENCE_LOW)
        return RECOMMENDATION_INSUFFICIENT_DATA;

    if(confidence == CONFIDENCE_VERY_HIGH)
    {
        if(score > 2.0) return RECOMMENDATION_STRONG_BUY;
        if(score > 1.0) return RECOMMENDATION_BUY;
        if(score < -1.0) return RECOMMENDATION_STRONG_AVOID;
        if(score < 0.0) return RECOMMENDATION_AVOID;
        return RECOMMENDATION_NEUTRAL;
    }

    if(score > 1.5) return RECOMMENDATION_BUY;
    if(score > 0.5) return RECOMMENDATION_NEUTRAL;
    if(score < -0.5) return RECOMMENDATION_AVOID;
    return RECOMMENDATION_INSUFFICIENT_DATA;
}

void CRecommendationEngine::AddEvidenceRef(RecommendationRecord &rec, const string ref)
{
    if(rec.evidenceCount < 64)
    {
        rec.evidenceRefs[rec.evidenceCount] = ref;
        rec.evidenceCount++;
    }
}

bool CRecommendationEngine::GenerateFromRanking(const RankingResult &ranking,
                                                  int topCount)
{
    if(!m_isInitialized || ranking.entryCount <= 0 || topCount <= 0)
        return false;

    for(int i = 0; i < topCount && i < ranking.entryCount
            && m_recommendationCount < MAX_RECOMMENDATIONS; i++)
    {
        RecommendationRecord rec;
        rec.strategyId = ranking.entries[i].strategyId;
        rec.status = (i == 0)
            ? RECOMMENDATION_STRONG_BUY
            : RECOMMENDATION_BUY;
        rec.confidence = ranking.entries[i].confidence;
        rec.rationale = StringFormat("Ranked #%d/%d by %s method (score=%.4f)",
                                     ranking.entries[i].rank,
                                     ranking.entryCount,
                                     EnumToString(ranking.method),
                                     ranking.entries[i].score);

        AddEvidenceRef(rec, StringFormat("RankingResult[%d]: method=%d, score=%.4f",
                                          i, ranking.method, ranking.entries[i].score));

        m_recommendations[m_recommendationCount] = rec;
        m_recommendationCount++;
    }

    return true;
}

bool CRecommendationEngine::GenerateFromStatisticalSummary(const StatisticalSummary &summary,
                                                             const string strategyId,
                                                             double threshold)
{
    if(!m_isInitialized || m_recommendationCount >= MAX_RECOMMENDATIONS)
        return false;

    RecommendationRecord rec;
    rec.strategyId = strategyId;
    rec.confidence = summary.confidence;
    rec.rationale = StringFormat("Metric=%s: mean=%.4f, median=%.4f, stdDev=%.4f, CI=[%.4f, %.4f]",
                                 summary.metricName,
                                 summary.mean, summary.median,
                                 summary.stdDev,
                                 summary.confidenceIntervalLower,
                                 summary.confidenceIntervalUpper);

    AddEvidenceRef(rec, StringFormat("StatisticalSummary[%s]: n=%d, CI=[%.4f, %.4f]",
                                      summary.analysisId, summary.sampleCount,
                                      summary.confidenceIntervalLower,
                                      summary.confidenceIntervalUpper));

    rec.status = ScoreToRecommendation(summary.mean, summary.confidence);

    m_recommendations[m_recommendationCount] = rec;
    m_recommendationCount++;
    return true;
}

bool CRecommendationEngine::GenerateFromBenchmark(const BenchmarkResult &benchmark)
{
    if(!m_isInitialized || m_recommendationCount >= MAX_RECOMMENDATIONS)
        return false;

    RecommendationRecord rec;
    rec.strategyId = benchmark.strategyId;
    rec.confidence = benchmark.confidence;

    if(benchmark.alpha > 0.0)
    {
        rec.status = (benchmark.alpha > 0.5)
            ? RECOMMENDATION_STRONG_BUY
            : RECOMMENDATION_BUY;
    }
    else if(benchmark.alpha < 0.0)
    {
        rec.status = (benchmark.alpha < -0.5)
            ? RECOMMENDATION_STRONG_AVOID
            : RECOMMENDATION_AVOID;
    }
    else
    {
        rec.status = RECOMMENDATION_NEUTRAL;
    }

    rec.rationale = StringFormat("Alpha=%.4f (strategy=%.4f vs benchmark=%.4f), beta=%.4f",
                                 benchmark.alpha, benchmark.strategyScore,
                                 benchmark.benchmarkScore, benchmark.beta);

    AddEvidenceRef(rec, StringFormat("BenchmarkResult[%s]: alpha=%.4f, beta=%.4f",
                                      benchmark.strategyId, benchmark.alpha, benchmark.beta));

    m_recommendations[m_recommendationCount] = rec;
    m_recommendationCount++;
    return true;
}

bool CRecommendationEngine::GetRecommendation(int index, RecommendationRecord &out) const
{
    if(index < 0 || index >= m_recommendationCount) return false;
    out = m_recommendations[index];
    return true;
}

void CRecommendationEngine::Clear(void)
{
    m_recommendationCount = 0;
}

#endif
