#ifndef __KNOWLEDGE_KNOWLEDGE_REPORT_MQH__
#define __KNOWLEDGE_KNOWLEDGE_REPORT_MQH__

#include "../Core/Logger.mqh"
#include "KnowledgeEvidence.mqh"
#include "StrategyLineage.mqh"
#include "TrendAnalyzer.mqh"
#include "RecommendationScorer.mqh"
#include "ExplainabilityEngine.mqh"

#define MAX_REPORT_SECTIONS 16

enum ENUM_KNOWLEDGE_REPORT_SECTION
{
    KREPORT_HEADER = 0,
    KREPORT_LINEAGE,
    KREPORT_TRENDS,
    KREPORT_RECOMMENDATIONS,
    KREPORT_EXPLAINABILITY,
    KREPORT_EVIDENCE_INDEX
};

class CKnowledgeReport
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    string m_reportVersion;
    string m_reportTimestamp;

    ENUM_KNOWLEDGE_REPORT_SECTION m_sections[MAX_REPORT_SECTIONS];
    int                            m_sectionCount;

    KnowledgeEvidence m_evidenceIndex[64];
    int               m_evidenceCount;

    const CStrategyLineage       *m_lineage;
    const CTrendAnalyzer         *m_trends;
    const CRecommendationScorer  *m_scorer;
    const CExplainabilityEngine  *m_explain;

    bool HasSection(ENUM_KNOWLEDGE_REPORT_SECTION section) const;

public:
    CKnowledgeReport(void);
    ~CKnowledgeReport(void);

    bool Init(const string reportVersion);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    void AttachLineage(const CStrategyLineage *lineage) { m_lineage = lineage; }
    void AttachTrends(const CTrendAnalyzer *trends) { m_trends = trends; }
    void AttachScorer(const CRecommendationScorer *scorer) { m_scorer = scorer; }
    void AttachExplainability(const CExplainabilityEngine *explain) { m_explain = explain; }

    bool AddSection(ENUM_KNOWLEDGE_REPORT_SECTION section);
    bool RemoveSection(ENUM_KNOWLEDGE_REPORT_SECTION section);

    bool AddEvidence(const KnowledgeEvidence &ev);

    string ComposeHeader(void) const;
    string ComposeLineageSection(void) const;
    string ComposeTrendsSection(void) const;
    string ComposeRecommendationsSection(void) const;
    string ComposeExplainabilitySection(void) const;
    string ComposeEvidenceIndex(void) const;

    string ComposeFullReport(void) const;

    void Clear(void);
};

CKnowledgeReport::CKnowledgeReport(void)
    : m_logger(MODULE_LABORATORY, "KnowledgeReport")
    , m_isInitialized(false)
    , m_sectionCount(0)
    , m_evidenceCount(0)
    , m_lineage(NULL)
    , m_trends(NULL)
    , m_scorer(NULL)
    , m_explain(NULL)
{
}

CKnowledgeReport::~CKnowledgeReport(void)
{
    Shutdown();
}

bool CKnowledgeReport::Init(const string reportVersion)
{
    m_logger.LogInfo("Initializing KnowledgeReport...");
    m_reportVersion = reportVersion;
    m_reportTimestamp = TimeToString(TimeCurrent());
    m_sectionCount = 0;
    m_evidenceCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo(StringFormat("KnowledgeReport initialized: v%s at %s",
                                  reportVersion, m_reportTimestamp));
    return true;
}

void CKnowledgeReport::Shutdown(void)
{
    if(!m_isInitialized) return;
    Clear();
    m_isInitialized = false;
}

bool CKnowledgeReport::HasSection(ENUM_KNOWLEDGE_REPORT_SECTION section) const
{
    for(int i = 0; i < m_sectionCount; i++)
        if(m_sections[i] == section) return true;
    return false;
}

bool CKnowledgeReport::AddSection(ENUM_KNOWLEDGE_REPORT_SECTION section)
{
    if(!m_isInitialized || m_sectionCount >= MAX_REPORT_SECTIONS)
        return false;

    if(HasSection(section))
        return true;

    m_sections[m_sectionCount] = section;
    m_sectionCount++;
    return true;
}

bool CKnowledgeReport::RemoveSection(ENUM_KNOWLEDGE_REPORT_SECTION section)
{
    for(int i = 0; i < m_sectionCount; i++)
    {
        if(m_sections[i] == section)
        {
            for(int j = i; j < m_sectionCount - 1; j++)
                m_sections[j] = m_sections[j + 1];
            m_sectionCount--;
            return true;
        }
    }
    return false;
}

bool CKnowledgeReport::AddEvidence(const KnowledgeEvidence &ev)
{
    if(m_evidenceCount >= 64) return false;
    m_evidenceIndex[m_evidenceCount] = ev;
    m_evidenceCount++;
    return true;
}

string CKnowledgeReport::ComposeHeader(void) const
{
    string out = "";
    out += "========================================\n";
    out += "KNOWLEDGE REPORT\n";
    out += StringFormat("  Version    : %s\n", m_reportVersion);
    out += StringFormat("  Timestamp  : %s\n", m_reportTimestamp);
    out += "========================================\n";
    return out;
}

string CKnowledgeReport::ComposeLineageSection(void) const
{
    string out = "";
    out += "========================================\n";
    out += "STRATEGY LINEAGE\n";
    out += "========================================\n";

    if(m_lineage == NULL || !m_lineage.IsInitialized())
    {
        out += "  (StrategyLineage not available)\n";
        return out;
    }

    out += StringFormat("  Total versions : %d\n", m_lineage.GetNodeCount());
    out += StringFormat("  Total edges    : %d\n", m_lineage.GetEdgeCount());

    StrategyVersionNode node;
    for(int i = 0; i < m_lineage.GetNodeCount(); i++)
    {
        if(m_lineage.GetNode(i, node))
        {
            out += StringFormat("  [%s] %s@%s score=%.4f\n",
                                node.versionTag, node.strategyId,
                                node.version, node.performanceScore);
        }
    }

    out += "========================================\n";
    return out;
}

string CKnowledgeReport::ComposeTrendsSection(void) const
{
    string out = "";
    out += "========================================\n";
    out += "TREND ANALYSIS\n";
    out += "========================================\n";

    if(m_trends == NULL || !m_trends.IsInitialized())
    {
        out += "  (TrendAnalyzer not available)\n";
        return out;
    }

    TrendRecord tr;
    for(int t = 0; t < m_trends.GetTrendCount(); t++)
    {
        if(m_trends.GetTrend(t, tr))
        {
            string dirStr = "";
            switch(tr.direction)
            {
                case TREND_IMPROVING: dirStr = "IMPROVING"; break;
                case TREND_STABLE: dirStr = "STABLE"; break;
                case TREND_DECLINING: dirStr = "DECLINING"; break;
                case TREND_VOLATILE: dirStr = "VOLATILE"; break;
                default: dirStr = "INSUFFICIENT DATA"; break;
            }

            out += StringFormat("  [%d] %s\n", t + 1, tr.metricName);
            out += StringFormat("       Direction : %s\n", dirStr);
            out += StringFormat("       Slope     : %.4f\n", tr.slope);
            out += StringFormat("       Mean      : %.4f\n", tr.meanValue);
            out += StringFormat("       Obs Count : %d\n", tr.observationCount);
            out += "\n";
        }
    }

    out += "========================================\n";
    return out;
}

string CKnowledgeReport::ComposeRecommendationsSection(void) const
{
    string out = "";
    out += "========================================\n";
    out += "RECOMMENDATIONS\n";
    out += "========================================\n";

    if(m_scorer == NULL || !m_scorer.IsInitialized())
    {
        out += "  (RecommendationScorer not available)\n";
        return out;
    }

    out += StringFormat("  Total recommendations: %d\n",
                        m_scorer.GetRecommendationCount());

    KnowledgeRecommendation rec;
    for(int i = 0; i < m_scorer.GetRecommendationCount(); i++)
    {
        if(m_scorer.GetRecommendation(i, rec))
        {
            string confStr = "";
            switch(rec.confidence)
            {
                case REC_CONFIDENCE_NONE: confStr = "NONE"; break;
                case REC_CONFIDENCE_LOW: confStr = "LOW"; break;
                case REC_CONFIDENCE_MODERATE: confStr = "MODERATE"; break;
                case REC_CONFIDENCE_HIGH: confStr = "HIGH"; break;
                case REC_CONFIDENCE_VERY_HIGH: confStr = "VERY HIGH"; break;
            }

            out += StringFormat("  [%d] %s\n", i + 1, rec.strategyId);
            out += StringFormat("       Status    : %s\n", rec.recommendationStatus);
            out += StringFormat("       Score     : %.2f/100\n", rec.overallScore);
            out += StringFormat("       Confidence: %s\n", confStr);
            out += StringFormat("       Rationale : %s\n", rec.rationale);

            if(rec.dimensionCount > 0)
            {
                out += "       Dimensions:\n";
                for(int d = 0; d < rec.dimensionCount; d++)
                    out += StringFormat("         - %s: %.2f\n",
                                        rec.dimensionNames[d],
                                        rec.dimensionScores[d]);
            }

            if(rec.evidenceCount > 0)
            {
                out += "       Evidence:\n";
                for(int e = 0; e < rec.evidenceCount; e++)
                    out += StringFormat("         [%d] %s/%s: %.4f\n",
                                        e + 1,
                                        rec.evidence[e].source,
                                        rec.evidence[e].dimension,
                                        rec.evidence[e].value);
            }

            out += "\n";
        }
    }

    out += "========================================\n";
    return out;
}

string CKnowledgeReport::ComposeExplainabilitySection(void) const
{
    string out = "";
    out += "========================================\n";
    out += "EXPLAINABILITY\n";
    out += "========================================\n";

    if(m_explain == NULL || !m_explain.IsInitialized())
    {
        out += "  (ExplainabilityEngine not available)\n";
        return out;
    }

    out += m_explain.ComposeFullExplainabilityReport();
    return out;
}

string CKnowledgeReport::ComposeEvidenceIndex(void) const
{
    string out = "";
    out += "========================================\n";
    out += "EVIDENCE INDEX\n";
    out += "========================================\n";

    if(m_evidenceCount <= 0)
    {
        out += "  (No evidence indexed)\n";
        return out;
    }

    out += StringFormat("  Total evidence records: %d\n\n", m_evidenceCount);

    for(int i = 0; i < m_evidenceCount; i++)
    {
        out += StringFormat("  [%d] %s/%s\n", i + 1,
                            m_evidenceIndex[i].source,
                            m_evidenceIndex[i].dimension);
        out += StringFormat("       Value    : %.4f\n", m_evidenceIndex[i].value);
        out += StringFormat("       Rationale: %s\n", m_evidenceIndex[i].rationale);
        out += StringFormat("       Artifact : %s\n", m_evidenceIndex[i].artifactRef);
        out += StringFormat("       Version  : %s\n", m_evidenceIndex[i].versionContext);
        out += "\n";
    }

    out += "========================================\n";
    return out;
}

string CKnowledgeReport::ComposeFullReport(void) const
{
    string out = "";

    for(int i = 0; i < m_sectionCount; i++)
    {
        switch(m_sections[i])
        {
            case KREPORT_HEADER:
                out += ComposeHeader();
                break;
            case KREPORT_LINEAGE:
                out += ComposeLineageSection();
                break;
            case KREPORT_TRENDS:
                out += ComposeTrendsSection();
                break;
            case KREPORT_RECOMMENDATIONS:
                out += ComposeRecommendationsSection();
                break;
            case KREPORT_EXPLAINABILITY:
                out += ComposeExplainabilitySection();
                break;
            case KREPORT_EVIDENCE_INDEX:
                out += ComposeEvidenceIndex();
                break;
        }
    }

    return out;
}

void CKnowledgeReport::Clear(void)
{
    m_sectionCount = 0;
    m_evidenceCount = 0;
}

#endif
