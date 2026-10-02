#ifndef __KNOWLEDGE_RECOMMENDATION_SCORER_MQH__
#define __KNOWLEDGE_RECOMMENDATION_SCORER_MQH__

#include "../Core/Logger.mqh"
#include "../Laboratory/LaboratoryTypes.mqh"
#include "../Laboratory/RankingEngine.mqh"
#include "KnowledgeEvidence.mqh"

#define MAX_KNOWLEDGE_RECOMMENDATIONS 64
#define MAX_SCORE_DIMENSIONS 8

class CRecommendationScorer
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    KnowledgeRecommendation m_recommendations[MAX_KNOWLEDGE_RECOMMENDATIONS];
    int                     m_recommendationCount;

    ENUM_RECOMMENDATION_CONFIDENCE ScoreToConfidence(double score, int evidenceCount) const;
    string ScoreToStatus(double score) const;
    void AddEvidence(KnowledgeRecommendation &rec, const KnowledgeEvidence &ev);
    double NormalizeScore(double raw, double minVal, double maxVal) const;

public:
    CRecommendationScorer(void);
    ~CRecommendationScorer(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool ScoreFromRanking(const RankingResult &ranking,
                           const RankingResult &previousRanking,
                           const string versionContext);
    bool ScoreFromBenchmark(const BenchmarkResult &benchmark,
                             const string versionContext);
    bool ScoreFromRobustness(const RobustnessProfile &robustness,
                              const string versionContext);
    bool ScoreFromCalibration(const ConfidenceCalibrationReport &calibration,
                               const string versionContext);
    bool ScoreComposite(const string strategyId,
                         const KnowledgeObservation &observations[], int obsCount,
                         const string versionContext);

    bool GetRecommendation(int index, KnowledgeRecommendation &out) const;
    int  GetRecommendationCount(void) const { return m_recommendationCount; }
    bool GetRecommendationForStrategy(const string strategyId,
                                       KnowledgeRecommendation &out) const;

    string ComposeScoringReport(void) const;
    string ComposeStrategyScoring(const string strategyId) const;

    void Clear(void);
};

CRecommendationScorer::CRecommendationScorer(void)
    : m_logger(MODULE_LABORATORY, "RecommendationScorer")
    , m_isInitialized(false)
    , m_recommendationCount(0)
{
}

CRecommendationScorer::~CRecommendationScorer(void)
{
    Shutdown();
}

bool CRecommendationScorer::Init(void)
{
    m_logger.LogInfo("Initializing RecommendationScorer...");
    m_recommendationCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("RecommendationScorer initialized");
    return true;
}

void CRecommendationScorer::Shutdown(void)
{
    if(!m_isInitialized) return;
    Clear();
    m_isInitialized = false;
}

ENUM_RECOMMENDATION_CONFIDENCE CRecommendationScorer::ScoreToConfidence(
    double score, int evidenceCount) const
{
    if(score >= 81.0 && evidenceCount >= 8)
        return REC_CONFIDENCE_VERY_HIGH;
    if(score >= 61.0 && evidenceCount >= 4)
        return REC_CONFIDENCE_HIGH;
    if(score >= 41.0 && evidenceCount >= 2)
        return REC_CONFIDENCE_MODERATE;
    if(score >= 21.0)
        return REC_CONFIDENCE_LOW;

    return REC_CONFIDENCE_NONE;
}

string CRecommendationScorer::ScoreToStatus(double score) const
{
    if(score >= 81.0) return "STRONG BUY";
    if(score >= 61.0) return "BUY";
    if(score >= 41.0) return "NEUTRAL";
    if(score >= 21.0) return "AVOID";
    return "STRONG AVOID";
}

void CRecommendationScorer::AddEvidence(KnowledgeRecommendation &rec,
                                         const KnowledgeEvidence &ev)
{
    if(rec.evidenceCount < 32)
    {
        rec.evidence[rec.evidenceCount] = ev;
        rec.evidenceCount++;
    }
}

double CRecommendationScorer::NormalizeScore(double raw, double minVal, double maxVal) const
{
    if(maxVal <= minVal) return 50.0;
    double normalized = (raw - minVal) / (maxVal - minVal) * 100.0;
    return MathMax(0.0, MathMin(100.0, normalized));
}

bool CRecommendationScorer::ScoreFromRanking(const RankingResult &ranking,
                                              const RankingResult &previousRanking,
                                              const string versionContext)
{
    if(!m_isInitialized) return false;

    for(int i = 0; i < ranking.entryCount && m_recommendationCount < MAX_KNOWLEDGE_RECOMMENDATIONS; i++)
    {
        KnowledgeRecommendation rec;
        rec.strategyId = ranking.entries[i].strategyId;
        rec.rankPosition = ranking.entries[i].rank;

        double rankScore = NormalizeScore((double)(ranking.entryCount - ranking.entries[i].rank),
                                           0.0, (double)ranking.entryCount);

        double previousScore = 0.0;
        for(int j = 0; j < previousRanking.entryCount; j++)
        {
            if(previousRanking.entries[j].strategyId == ranking.entries[i].strategyId)
            {
                previousScore = (double)(previousRanking.entryCount - previousRanking.entries[j].rank);
                break;
            }
        }

        double rankDelta = 0.0;
        if(previousScore > 0.0)
            rankDelta = ((double)(ranking.entryCount - ranking.entries[i].rank) - previousScore) / previousScore * 100.0;

        rec.dimensionNames[0] = "Rank Score";
        rec.dimensionScores[0] = rankScore;
        rec.dimensionNames[1] = "Rank Delta";
        rec.dimensionScores[1] = NormalizeScore(rankDelta, -100.0, 100.0);
        rec.dimensionCount = 2;

        rec.overallScore = (rankScore * 0.7 + rec.dimensionScores[1] * 0.3);
        rec.recommendationStatus = ScoreToStatus(rec.overallScore);
        rec.confidence = ScoreToConfidence(rec.overallScore, 2);
        rec.rationale = StringFormat("Ranked #%d/%d by %s (score=%.4f, delta=%.2f%%)",
                                     ranking.entries[i].rank,
                                     ranking.entryCount,
                                     EnumToString(ranking.method),
                                     ranking.entries[i].score,
                                     rankDelta);

        KnowledgeEvidence ev;
        ev.source = "RankingEngine";
        ev.dimension = "rank";
        ev.value = (double)ranking.entries[i].rank;
        ev.rationale = StringFormat("Method=%s, Score=%.4f, Confidence=%d",
                                     EnumToString(ranking.method),
                                     ranking.entries[i].score,
                                     ranking.entries[i].confidence);
        ev.artifactRef = StringFormat("RankingResult#%d", i);
        ev.versionContext = versionContext;
        AddEvidence(rec, ev);

        m_recommendations[m_recommendationCount] = rec;
        m_recommendationCount++;
    }

    return true;
}

bool CRecommendationScorer::ScoreFromBenchmark(const BenchmarkResult &benchmark,
                                                const string versionContext)
{
    if(!m_isInitialized || m_recommendationCount >= MAX_KNOWLEDGE_RECOMMENDATIONS)
        return false;

    KnowledgeRecommendation rec;
    rec.strategyId = benchmark.strategyId;
    rec.rankPosition = 0;

    double alphaScore = NormalizeScore(benchmark.alpha, -1.0, 1.0);
    double betaScore = NormalizeScore(1.0 - MathAbs(benchmark.beta - 1.0), 0.0, 1.0);

    rec.dimensionNames[0] = "Alpha Score";
    rec.dimensionScores[0] = alphaScore;
    rec.dimensionNames[1] = "Beta Alignment";
    rec.dimensionScores[1] = betaScore;
    rec.dimensionCount = 2;

    rec.overallScore = (alphaScore * 0.6 + betaScore * 0.4);
    rec.recommendationStatus = ScoreToStatus(rec.overallScore);

    ENUM_CONFIDENCE_LEVEL labConfidence = benchmark.confidence;
    if(labConfidence >= CONFIDENCE_HIGH)
        rec.confidence = REC_CONFIDENCE_HIGH;
    else if(labConfidence >= CONFIDENCE_MODERATE)
        rec.confidence = REC_CONFIDENCE_MODERATE;
    else
        rec.confidence = REC_CONFIDENCE_LOW;

    rec.rationale = StringFormat("Alpha=%.4f, Beta=%.4f (strategy=%.4f vs benchmark=%.4f)",
                                 benchmark.alpha, benchmark.beta,
                                 benchmark.strategyScore, benchmark.benchmarkScore);

    KnowledgeEvidence ev;
    ev.source = "BenchmarkEngine";
    ev.dimension = "alpha";
    ev.value = benchmark.alpha;
    ev.rationale = StringFormat("Strategy=%.4f, Benchmark=%.4f, Beta=%.4f",
                                 benchmark.strategyScore, benchmark.benchmarkScore,
                                 benchmark.beta);
    ev.artifactRef = StringFormat("BenchmarkResult[%s]", benchmark.strategyId);
    ev.versionContext = versionContext;
    AddEvidence(rec, ev);

    m_recommendations[m_recommendationCount] = rec;
    m_recommendationCount++;

    m_logger.LogInfo(StringFormat("RecommendationScorer: scored %s from benchmark (%.4f)",
                                  benchmark.strategyId, rec.overallScore));
    return true;
}

bool CRecommendationScorer::ScoreFromRobustness(const RobustnessProfile &robustness,
                                                 const string versionContext)
{
    if(!m_isInitialized || m_recommendationCount >= MAX_KNOWLEDGE_RECOMMENDATIONS)
        return false;

    KnowledgeRecommendation rec;
    rec.strategyId = robustness.strategyId;
    rec.rankPosition = 0;

    rec.dimensionNames[0] = "Regime Stability";
    rec.dimensionScores[0] = robustness.regimeStability * 100.0;
    rec.dimensionNames[1] = "Parameter Sensitivity";
    rec.dimensionScores[1] = (1.0 - robustness.parameterSensitivity) * 100.0;
    rec.dimensionNames[2] = "Temporal Consistency";
    rec.dimensionScores[2] = robustness.temporalConsistency * 100.0;
    rec.dimensionCount = 3;

    rec.overallScore = robustness.overallRobustnessScore * 100.0;
    rec.recommendationStatus = ScoreToStatus(rec.overallScore);

    if(robustness.overallRobustnessScore >= 0.7)
        rec.confidence = REC_CONFIDENCE_HIGH;
    else if(robustness.overallRobustnessScore >= 0.4)
        rec.confidence = REC_CONFIDENCE_MODERATE;
    else
        rec.confidence = REC_CONFIDENCE_LOW;

    rec.rationale = StringFormat("Overall Robustness=%.4f, RegimeStability=%.4f, TemporalConsistency=%.4f",
                                 robustness.overallRobustnessScore,
                                 robustness.regimeStability,
                                 robustness.temporalConsistency);

    KnowledgeEvidence ev;
    ev.source = "RobustnessProfiler";
    ev.dimension = "overallRobustness";
    ev.value = robustness.overallRobustnessScore;
    ev.rationale = StringFormat("Regime=%.4f, VolSensitivity=%.4f, ParamSensitivity=%.4f",
                                 robustness.regimeStability,
                                 robustness.volatilitySensitivity,
                                 robustness.parameterSensitivity);
    ev.artifactRef = StringFormat("RobustnessProfile[%s]", robustness.strategyId);
    ev.versionContext = versionContext;
    AddEvidence(rec, ev);

    m_recommendations[m_recommendationCount] = rec;
    m_recommendationCount++;

    m_logger.LogInfo(StringFormat("RecommendationScorer: scored %s from robustness (%.4f)",
                                  robustness.strategyId, rec.overallScore));
    return true;
}

bool CRecommendationScorer::ScoreFromCalibration(const ConfidenceCalibrationReport &calibration,
                                                  const string versionContext)
{
    if(!m_isInitialized || m_recommendationCount >= MAX_KNOWLEDGE_RECOMMENDATIONS)
        return false;

    KnowledgeRecommendation rec;
    rec.strategyId = calibration.strategyId;
    rec.rankPosition = 0;

    double calibrationScore = 0.0;
    if(calibration.status == CALIBRATION_ACCURATE)
        calibrationScore = 80.0;
    else if(calibration.status == CALIBRATION_UNDERCONFIDENT)
        calibrationScore = 60.0;
    else if(calibration.status == CALIBRATION_OVERCONFIDENT)
        calibrationScore = 30.0;
    else
        calibrationScore = 10.0;

    rec.dimensionNames[0] = "Calibration Score";
    rec.dimensionScores[0] = calibrationScore;
    rec.dimensionNames[1] = "Correlation";
    rec.dimensionScores[1] = NormalizeScore(calibration.correlation, -1.0, 1.0);
    rec.dimensionCount = 2;

    rec.overallScore = calibrationScore;
    rec.recommendationStatus = ScoreToStatus(rec.overallScore);
    rec.confidence = (calibration.status == CALIBRATION_ACCURATE)
        ? REC_CONFIDENCE_HIGH
        : REC_CONFIDENCE_MODERATE;

    rec.rationale = StringFormat("Calibration status=%d, correlation=%.4f, mse=%.4f",
                                 calibration.status,
                                 calibration.correlation,
                                 calibration.mse);

    KnowledgeEvidence ev;
    ev.source = "ConfidenceCalibrator";
    ev.dimension = "calibration";
    ev.value = (double)calibration.status;
    ev.rationale = StringFormat("Correlation=%.4f, Slope=%.4f, MSE=%.4f",
                                 calibration.correlation,
                                 calibration.calibrationSlope,
                                 calibration.mse);
    ev.artifactRef = StringFormat("ConfidenceCalibration[%s]", calibration.strategyId);
    ev.versionContext = versionContext;
    AddEvidence(rec, ev);

    m_recommendations[m_recommendationCount] = rec;
    m_recommendationCount++;

    m_logger.LogInfo(StringFormat("RecommendationScorer: scored %s from calibration (%.4f)",
                                  calibration.strategyId, rec.overallScore));
    return true;
}

bool CRecommendationScorer::ScoreComposite(const string strategyId,
                                            const KnowledgeObservation &observations[],
                                            int obsCount,
                                            const string versionContext)
{
    if(!m_isInitialized || m_recommendationCount >= MAX_KNOWLEDGE_RECOMMENDATIONS)
        return false;

    if(obsCount <= 0) return false;

    KnowledgeRecommendation rec;
    rec.strategyId = strategyId;
    rec.rankPosition = 0;

    double weightedSum = 0.0;
    double totalWeight = 0.0;
    int dimCount = 0;

    for(int i = 0; i < obsCount && dimCount < 8; i++)
    {
        rec.dimensionNames[dimCount] = observations[i].metricName;
        rec.dimensionScores[dimCount] = NormalizeScore(observations[i].value, 0.0, 100.0);
        weightedSum += rec.dimensionScores[dimCount] * observations[i].confidence;
        totalWeight += observations[i].confidence;
        dimCount++;

        KnowledgeEvidence ev;
        ev.source = observations[i].observationId;
        ev.dimension = observations[i].metricName;
        ev.value = observations[i].value;
        ev.rationale = observations[i].evidenceCount > 0
            ? observations[i].evidence[0].rationale
            : "";
        ev.artifactRef = StringFormat("Observation[%s]", observations[i].observationId);
        ev.versionContext = versionContext;
        AddEvidence(rec, ev);
    }

    rec.dimensionCount = dimCount;
    rec.overallScore = (totalWeight > 0.0)
        ? (weightedSum / totalWeight)
        : 50.0;

    rec.recommendationStatus = ScoreToStatus(rec.overallScore);
    rec.confidence = ScoreToConfidence(rec.overallScore, rec.evidenceCount);
    rec.rationale = StringFormat("Composite score from %d observations (%.2f weighted)",
                                 obsCount, rec.overallScore);

    m_recommendations[m_recommendationCount] = rec;
    m_recommendationCount++;

    return true;
}

bool CRecommendationScorer::GetRecommendation(int index, KnowledgeRecommendation &out) const
{
    if(index < 0 || index >= m_recommendationCount) return false;
    out = m_recommendations[index];
    return true;
}

bool CRecommendationScorer::GetRecommendationForStrategy(const string strategyId,
                                                          KnowledgeRecommendation &out) const
{
    for(int i = 0; i < m_recommendationCount; i++)
    {
        if(m_recommendations[i].strategyId == strategyId)
        {
            out = m_recommendations[i];
            return true;
        }
    }
    return false;
}

string CRecommendationScorer::ComposeScoringReport(void) const
{
    string out = "";
    out += "========================================\n";
    out += "KNOWLEDGE RECOMMENDATIONS\n";
    out += StringFormat("  Count: %d\n", m_recommendationCount);
    out += "========================================\n";

    for(int i = 0; i < m_recommendationCount; i++)
    {
        string confStr = "";
        switch(m_recommendations[i].confidence)
        {
            case REC_CONFIDENCE_NONE: confStr = "NONE"; break;
            case REC_CONFIDENCE_LOW: confStr = "LOW"; break;
            case REC_CONFIDENCE_MODERATE: confStr = "MODERATE"; break;
            case REC_CONFIDENCE_HIGH: confStr = "HIGH"; break;
            case REC_CONFIDENCE_VERY_HIGH: confStr = "VERY HIGH"; break;
        }

        out += StringFormat("  [%d] %s\n", i + 1, m_recommendations[i].strategyId);
        out += StringFormat("       Status    : %s\n", m_recommendations[i].recommendationStatus);
        out += StringFormat("       Score     : %.2f/100\n", m_recommendations[i].overallScore);
        out += StringFormat("       Rank      : #%d\n", m_recommendations[i].rankPosition);
        out += StringFormat("       Confidence: %s\n", confStr);
        out += StringFormat("       Rationale : %s\n", m_recommendations[i].rationale);

        if(m_recommendations[i].dimensionCount > 0)
        {
            out += "       Dimensions:\n";
            for(int d = 0; d < m_recommendations[i].dimensionCount; d++)
                out += StringFormat("         - %s: %.2f\n",
                                    m_recommendations[i].dimensionNames[d],
                                    m_recommendations[i].dimensionScores[d]);
        }

        if(m_recommendations[i].evidenceCount > 0)
        {
            out += "       Evidence:\n";
            for(int e = 0; e < m_recommendations[i].evidenceCount; e++)
                out += StringFormat("         [%d] %s/%s: %.4f (%s)\n",
                                    e + 1,
                                    m_recommendations[i].evidence[e].source,
                                    m_recommendations[i].evidence[e].dimension,
                                    m_recommendations[i].evidence[e].value,
                                    m_recommendations[i].evidence[e].rationale);
        }

        out += "\n";
    }

    out += "========================================\n";
    return out;
}

string CRecommendationScorer::ComposeStrategyScoring(const string strategyId) const
{
    KnowledgeRecommendation rec;
    if(!GetRecommendationForStrategy(strategyId))
        return StringFormat("No recommendation for '%s'", strategyId);

    string confStr = "";
    switch(rec.confidence)
    {
        case REC_CONFIDENCE_NONE: confStr = "NONE"; break;
        case REC_CONFIDENCE_LOW: confStr = "LOW"; break;
        case REC_CONFIDENCE_MODERATE: confStr = "MODERATE"; break;
        case REC_CONFIDENCE_HIGH: confStr = "HIGH"; break;
        case REC_CONFIDENCE_VERY_HIGH: confStr = "VERY HIGH"; break;
    }

    string out = "";
    out += StringFormat("Recommendation for '%s'\n", rec.strategyId);
    out += StringFormat("  Status    : %s\n", rec.recommendationStatus);
    out += StringFormat("  Score     : %.2f/100\n", rec.overallScore);
    out += StringFormat("  Confidence: %s\n", confStr);
    out += StringFormat("  Rationale : %s\n", rec.rationale);
    return out;
}

void CRecommendationScorer::Clear(void)
{
    m_recommendationCount = 0;
}

#endif
