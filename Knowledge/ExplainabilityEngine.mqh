#ifndef __KNOWLEDGE_EXPLAINABILITY_ENGINE_MQH__
#define __KNOWLEDGE_EXPLAINABILITY_ENGINE_MQH__

#include "../Core/Logger.mqh"
#include "../Trading/TradingEvidence.mqh"
#include "../Research/ResearchEvidence.mqh"
#include "../Production/OperationalEvidence.mqh"
#include "../Laboratory/LaboratoryTypes.mqh"
#include "KnowledgeEvidence.mqh"

#define MAX_EXPLAIN_SECTIONS 32
#define MAX_EXPLAIN_DIMENSIONS 8

class CExplainabilityEngine
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    struct ExplainSection
    {
        string title;
        string content;
        string dimension;
        double contribution;

        ExplainSection(void)
            : title(""), content(""), dimension(""), contribution(0.0)
        {}
    };

    ExplainSection m_sections[MAX_EXPLAIN_SECTIONS];
    int            m_sectionCount;

    void AddSection(const string title, const string content,
                    const string dimension, double contribution);
    string FormatConfidence(ENUM_QUALITY_TIER tier) const;
    string FormatStability(ENUM_STABILITY_TIER tier) const;
    string FormatCalibration(ENUM_CALIBRATION_STATUS status) const;

public:
    CExplainabilityEngine(void);
    ~CExplainabilityEngine(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool ExplainRanking(const string strategyId, int rank, int totalCount,
                         const RankingResult &ranking);
    bool ExplainRecommendation(const KnowledgeRecommendation &rec);
    bool ExplainChange(const StrategyVersionNode &fromNode,
                        const StrategyVersionNode &toNode,
                        const LineageEdge &edge);
    bool ExplainTrend(const TrendRecord &trend);
    bool ExplainStructureConfidence(const string strategyId,
                                     const StructureConfidence &sc);
    bool ExplainCalibration(const string strategyId,
                             const ConfidenceCalibrationReport &calibration);

    string ComposeExplanation(const string strategyId) const;
    string ComposeFullExplainabilityReport(void) const;

    void Clear(void);
};

CExplainabilityEngine::CExplainabilityEngine(void)
    : m_logger(MODULE_LABORATORY, "ExplainabilityEngine")
    , m_isInitialized(false)
    , m_sectionCount(0)
{
}

CExplainabilityEngine::~CExplainabilityEngine(void)
{
    Shutdown();
}

bool CExplainabilityEngine::Init(void)
{
    m_logger.LogInfo("Initializing ExplainabilityEngine...");
    m_sectionCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("ExplainabilityEngine initialized");
    return true;
}

void CExplainabilityEngine::Shutdown(void)
{
    if(!m_isInitialized) return;
    Clear();
    m_isInitialized = false;
}

void CExplainabilityEngine::AddSection(const string title, const string content,
                                        const string dimension, double contribution)
{
    if(m_sectionCount >= MAX_EXPLAIN_SECTIONS) return;

    m_sections[m_sectionCount].title = title;
    m_sections[m_sectionCount].content = content;
    m_sections[m_sectionCount].dimension = dimension;
    m_sections[m_sectionCount].contribution = contribution;
    m_sectionCount++;
}

string CExplainabilityEngine::FormatConfidence(ENUM_QUALITY_TIER tier) const
{
    switch(tier)
    {
        case QUALITY_EXCEPTIONAL: return "EXCEPTIONAL (81-100)";
        case QUALITY_STRONG: return "STRONG (61-80)";
        case QUALITY_MODERATE: return "MODERATE (41-60)";
        case QUALITY_WEAK: return "WEAK (21-40)";
        case QUALITY_VERY_WEAK: return "VERY WEAK (0-20)";
        default: return "UNKNOWN";
    }
}

string CExplainabilityEngine::FormatStability(ENUM_STABILITY_TIER tier) const
{
    switch(tier)
    {
        case STABILITY_EXCEPTIONAL: return "EXCEPTIONAL";
        case STABILITY_STRONG: return "STRONG";
        case STABILITY_MODERATE: return "MODERATE";
        case STABILITY_WEAK: return "WEAK";
        case STABILITY_VERY_WEAK: return "VERY WEAK";
        default: return "UNKNOWN";
    }
}

string CExplainabilityEngine::FormatCalibration(ENUM_CALIBRATION_STATUS status) const
{
    switch(status)
    {
        case CALIBRATION_ACCURATE: return "ACCURATE";
        case CALIBRATION_UNDERCONFIDENT: return "UNDERCONFIDENT";
        case CALIBRATION_OVERCONFIDENT: return "OVERCONFIDENT";
        case CALIBRATION_INSUFFICIENT_DATA: return "INSUFFICIENT DATA";
        default: return "UNKNOWN";
    }
}

bool CExplainabilityEngine::ExplainRanking(const string strategyId, int rank,
                                            int totalCount,
                                            const RankingResult &ranking)
{
    if(!m_isInitialized) return false;

    double rankPercentile = (double)(totalCount - rank) / (double)totalCount * 100.0;

    string content = StringFormat(
        "Strategy '%s' ranked #%d/%d (top %.1f%%). "
        "Ranking method: %s. Score: %.4f. Confidence: %d.",
        strategyId, rank, totalCount, 100.0 - rankPercentile,
        EnumToString(ranking.method),
        ranking.entries[rank - 1].score,
        ranking.entries[rank - 1].confidence);

    AddSection("Ranking Explanation", content, "rank", rankPercentile);

    m_logger.LogInfo(StringFormat("Explainability: ranked %s #%d/%d",
                                  strategyId, rank, totalCount));
    return true;
}

bool CExplainabilityEngine::ExplainRecommendation(const KnowledgeRecommendation &rec)
{
    if(!m_isInitialized) return false;

    string confStr = "";
    switch(rec.confidence)
    {
        case REC_CONFIDENCE_NONE: confStr = "NONE"; break;
        case REC_CONFIDENCE_LOW: confStr = "LOW"; break;
        case REC_CONFIDENCE_MODERATE: confStr = "MODERATE"; break;
        case REC_CONFIDENCE_HIGH: confStr = "HIGH"; break;
        case REC_CONFIDENCE_VERY_HIGH: confStr = "VERY HIGH"; break;
    }

    string dimBreakdown = "";
    for(int i = 0; i < rec.dimensionCount; i++)
    {
        dimBreakdown += StringFormat("\n    - %s: %.2f/100",
                                     rec.dimensionNames[i],
                                     rec.dimensionScores[i]);
    }

    string content = StringFormat(
        "Recommendation for '%s': %s (overall=%.2f/100, confidence=%s).\n"
        "  Dimension breakdown:%s\n"
        "  Rationale: %s",
        rec.strategyId, rec.recommendationStatus, rec.overallScore, confStr,
        dimBreakdown, rec.rationale);

    if(rec.evidenceCount > 0)
    {
        content += "\n  Supporting evidence:";
        for(int i = 0; i < rec.evidenceCount; i++)
        {
            content += StringFormat("\n    [%d] %s/%s: %.4f (from %s)",
                                    i + 1,
                                    rec.evidence[i].source,
                                    rec.evidence[i].dimension,
                                    rec.evidence[i].value,
                                    rec.evidence[i].artifactRef);
        }
    }

    AddSection("Recommendation Explanation", content,
               "recommendation", rec.overallScore);

    return true;
}

bool CExplainabilityEngine::ExplainChange(const StrategyVersionNode &fromNode,
                                           const StrategyVersionNode &toNode,
                                           const LineageEdge &edge)
{
    if(!m_isInitialized) return false;

    string content = StringFormat(
        "Change: %s@%s (%s) -> %s@%s (%s)\n"
        "  Change type: %d\n"
        "  Description: %s\n"
        "  Performance delta: %.2f%%\n"
        "  Before: score=%.4f\n"
        "  After:  score=%.4f",
        fromNode.strategyId, fromNode.version, fromNode.versionTag,
        toNode.strategyId, toNode.version, toNode.versionTag,
        edge.relationship, edge.changeDescription,
        edge.performanceDelta,
        fromNode.performanceScore,
        toNode.performanceScore);

    AddSection("Change Explanation", content,
               "change", edge.performanceDelta);

    m_logger.LogInfo(StringFormat("Explainability: change %s@%s -> %s@%s delta=%.2f%%",
                                  fromNode.strategyId, fromNode.version,
                                  toNode.strategyId, toNode.version,
                                  edge.performanceDelta));
    return true;
}

bool CExplainabilityEngine::ExplainTrend(const TrendRecord &trend)
{
    if(!m_isInitialized) return false;

    string dirStr = "";
    switch(trend.direction)
    {
        case TREND_IMPROVING: dirStr = "IMPROVING"; break;
        case TREND_STABLE: dirStr = "STABLE"; break;
        case TREND_DECLINING: dirStr = "DECLINING"; break;
        case TREND_VOLATILE: dirStr = "VOLATILE"; break;
        default: dirStr = "INSUFFICIENT DATA"; break;
    }

    string content = StringFormat(
        "Trend: '%s' is %s over %d observations.\n"
        "  Slope: %.4f (%.4f per observation)\n"
        "  Mean value: %.4f\n"
        "  Volatility: %.4f\n"
        "  Interpretation: ",
        trend.metricName, dirStr, trend.observationCount,
        trend.slope, trend.observationCount > 1 ? trend.slope / (trend.observationCount - 1) : 0.0,
        trend.meanValue, trend.volatility);

    if(trend.direction == TREND_IMPROVING)
        content += "Metric is consistently improving across observations.";
    else if(trend.direction == TREND_DECLINING)
        content += "Metric is consistently declining across observations.";
    else if(trend.direction == TREND_STABLE)
        content += "Metric remains stable with no significant directional change.";
    else if(trend.direction == TREND_VOLATILE)
        content += "Metric fluctuates significantly; no clear directional signal.";
    else
        content += "Insufficient data to determine direction.";

    if(trend.evidenceCount > 0)
    {
        content += "\n  Supporting observations:";
        for(int i = 0; i < trend.evidenceCount; i++)
        {
            content += StringFormat("\n    [%d] %s: %s=%.4f",
                                    i + 1,
                                    trend.evidence[i].source,
                                    trend.evidence[i].dimension,
                                    trend.evidence[i].value);
        }
    }

    AddSection("Trend Explanation", content, trend.metricName,
               trend.slope * 100.0);

    return true;
}

bool CExplainabilityEngine::ExplainStructureConfidence(const string strategyId,
                                                        const StructureConfidence &sc)
{
    if(!m_isInitialized) return false;

    string content = StringFormat(
        "Structure confidence for '%s': overall=%.4f (%s)\n"
        "  Swing strength: %.4f\n"
        "  BOS confirmation: %.4f\n"
        "  CHOCH quality: %.4f\n"
        "  Protected point validity: %.4f\n"
        "  Noise filter ratio: %.4f",
        strategyId, sc.overallScore, FormatConfidence(sc.Tier()),
        sc.swingStrength, sc.bosConfirmation, sc.chochQuality,
        sc.protectedPointValidity, sc.noiseFilterRatio);

    if(sc.evidenceCount > 0)
    {
        content += "\n  Evidence:";
        for(int i = 0; i < sc.evidenceCount; i++)
        {
            content += StringFormat("\n    [%d] %s/%s: %.4f (%s)",
                                    i + 1,
                                    sc.evidence[i].source,
                                    sc.evidence[i].dimension,
                                    sc.evidence[i].value,
                                    sc.evidence[i].rationale);
        }
    }

    AddSection("Structure Confidence", content,
               "structure", sc.overallScore);

    return true;
}

bool CExplainabilityEngine::ExplainCalibration(const string strategyId,
                                                const ConfidenceCalibrationReport &calibration)
{
    if(!m_isInitialized) return false;

    string content = StringFormat(
        "Confidence calibration for '%s': status=%s\n"
        "  Correlation: %.4f (1.0 = perfect)\n"
        "  Calibration slope: %.4f (1.0 = ideal)\n"
        "  MSE: %.4f (lower = better)\n"
        "  Tier breakdown:",
        strategyId, FormatCalibration(calibration.status),
        calibration.correlation, calibration.calibrationSlope, calibration.mse);

    for(int i = 0; i < 5; i++)
    {
        content += StringFormat("\n    Tier %d: confidence=%.2f%%, winRate=%.2f%%, trades=%d",
                                i + 1,
                                calibration.confidenceByTier[i] * 100.0,
                                calibration.winRateByTier[i] * 100.0,
                                calibration.tradesByTier[i]);
    }

    if(calibration.status == CALIBRATION_ACCURATE)
    {
        content += "\n\n  Assessment: Calibration is accurate. "
                   "Confidence scores align with observed win rates.";
    }
    else if(calibration.status == CALIBRATION_OVERCONFIDENT)
    {
        content += "\n\n  Assessment: Strategy is overconfident. "
                   "Confidence scores exceed observed win rates.";
    }
    else if(calibration.status == CALIBRATION_UNDERCONFIDENT)
    {
        content += "\n\n  Assessment: Strategy is underconfident. "
                   "Observed win rates exceed confidence scores.";
    }
    else
    {
        content += "\n\n  Assessment: Insufficient data for calibration.";
    }

    if(calibration.evidenceCount > 0)
    {
        content += "\n  Evidence:";
        for(int i = 0; i < calibration.evidenceCount; i++)
        {
            content += StringFormat("\n    [%d] %s: %s=%.4f",
                                    i + 1,
                                    calibration.evidence[i].source,
                                    calibration.evidence[i].dimension,
                                    calibration.evidence[i].value);
        }
    }

    AddSection("Calibration Explanation", content,
               "calibration", calibration.correlation * 100.0);

    return true;
}

string CExplainabilityEngine::ComposeExplanation(const string strategyId) const
{
    string out = "";
    out += "========================================\n";
    out += StringFormat("EXPLANATION: %s\n", strategyId);
    out += "========================================\n";

    for(int i = 0; i < m_sectionCount; i++)
    {
        if(m_sections[i].dimension == "rank" ||
           m_sections[i].dimension == "recommendation" ||
           m_sections[i].dimension == "change" ||
           m_sections[i].dimension == "structure" ||
           m_sections[i].dimension == "calibration")
        {
            out += StringFormat("\n--- %s ---\n", m_sections[i].title);
            out += m_sections[i].content;
            out += "\n";
        }
    }

    out += "\n========================================\n";
    return out;
}

string CExplainabilityEngine::ComposeFullExplainabilityReport(void) const
{
    string out = "";
    out += "========================================\n";
    out += "FULL EXPLAINABILITY REPORT\n";
    out += StringFormat("  Sections: %d\n", m_sectionCount);
    out += "========================================\n";

    for(int i = 0; i < m_sectionCount; i++)
    {
        out += StringFormat("\n[%d] %s (contrib: %.2f)\n",
                            i + 1, m_sections[i].title,
                            m_sections[i].contribution);
        out += "----------------------------------------\n";
        out += m_sections[i].content;
        out += "\n";
    }

    out += "\n========================================\n";
    return out;
}

void CExplainabilityEngine::Clear(void)
{
    m_sectionCount = 0;
}

#endif
