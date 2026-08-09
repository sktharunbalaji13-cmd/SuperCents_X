#ifndef __LABORATORY_REPORT_COMPOSER_MQH__
#define __LABORATORY_REPORT_COMPOSER_MQH__

#include "../Core/Logger.mqh"
#include "LaboratoryTypes.mqh"
#include "LaboratoryManifest.mqh"
#include "BenchmarkEngine.mqh"
#include "StatisticalAnalyzer.mqh"
#include "RecommendationEngine.mqh"

#define MAX_REPORT_SECTIONS 32

enum ENUM_REPORT_SECTION
{
    SECTION_MANIFEST = 0,
    SECTION_RANKINGS,
    SECTION_COMPARISONS,
    SECTION_BENCHMARKS,
    SECTION_STATISTICS,
    SECTION_ROBUSTNESS,
    SECTION_RECOMMENDATIONS,
    SECTION_KNOWLEDGE_GRAPH
};

class CReportComposer
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    ENUM_REPORT_SECTION m_sections[MAX_REPORT_SECTIONS];
    int                 m_sectionCount;

public:
    CReportComposer(void);
    ~CReportComposer(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool AddSection(ENUM_REPORT_SECTION section);
    bool RemoveSection(ENUM_REPORT_SECTION section);

    string ComposeManifestSection(const LaboratoryManifest &manifest) const;
    string ComposeRankingSection(const RankingResult &ranking) const;
    string ComposeComparisonSection(const ComparisonResult &comparisons[], int count) const;
    string ComposeBenchmarkSection(const BenchmarkResult &benchmarks[], int count) const;
    string ComposeStatisticsSection(const StatisticalSummary &summaries[], int count) const;
    string ComposeRobustnessSection(double robustnessScore, double stabilityIndex) const;
    string ComposeRecommendationSection(const RecommendationRecord &recs[], int count) const;

    string ComposeFullReport(void) const;
};

CReportComposer::CReportComposer(void)
    : m_logger(MODULE_LABORATORY, "ReportComposer")
    , m_isInitialized(false)
    , m_sectionCount(0)
{
}

CReportComposer::~CReportComposer(void)
{
    Shutdown();
}

bool CReportComposer::Init(void)
{
    m_logger.LogInfo("Initializing ReportComposer...");
    m_sectionCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("ReportComposer initialized");
    return true;
}

void CReportComposer::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_sectionCount = 0;
    m_isInitialized = false;
}

bool CReportComposer::AddSection(ENUM_REPORT_SECTION section)
{
    if(!m_isInitialized || m_sectionCount >= MAX_REPORT_SECTIONS)
        return false;

    for(int i = 0; i < m_sectionCount; i++)
        if(m_sections[i] == section) return true;

    m_sections[m_sectionCount] = section;
    m_sectionCount++;
    return true;
}

bool CReportComposer::RemoveSection(ENUM_REPORT_SECTION section)
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

string CReportComposer::ComposeManifestSection(const LaboratoryManifest &manifest) const
{
    string out = "";
    out += "========================================\n";
    out += "LABORATORY MANIFEST\n";
    out += "========================================\n";
    out += StringFormat("  Run ID          : %s\n", manifest.laboratoryRunId);
    out += StringFormat("  Lab Version     : %s\n", manifest.laboratoryVersion);
    out += StringFormat("  Schema Version  : %d\n", manifest.knowledgeSchemaVersion);
    out += StringFormat("  Artifact Set    : %s\n", manifest.inputArtifactSetId);
    out += StringFormat("  Config ID       : %s\n", manifest.comparisonConfigurationId);
    out += StringFormat("  Timestamp       : %s\n", TimeToString(manifest.analysisTimestamp));
    out += StringFormat("  Report ID       : %s\n", manifest.outputReportId);
    out += "========================================\n";
    return out;
}

string CReportComposer::ComposeRankingSection(const RankingResult &ranking) const
{
    string out = "";
    out += "========================================\n";
    out += "RANKINGS\n";
    out += StringFormat("  Method : %d\n", ranking.method);
    out += StringFormat("  Count  : %d\n", ranking.entryCount);
    out += StringFormat("  Desc   : %s\n", ranking.description);
    out += "----------------------------------------\n";
    out += "  Rank  Strategy                   Score     Confidence\n";
    out += "----------------------------------------\n";

    for(int i = 0; i < ranking.entryCount; i++)
    {
        out += StringFormat("  %-5d %-25s %-9.4f %d\n",
                            ranking.entries[i].rank,
                            ranking.entries[i].strategyId,
                            ranking.entries[i].score,
                            ranking.entries[i].confidence);
    }
    out += "========================================\n";
    return out;
}

string CReportComposer::ComposeComparisonSection(const ComparisonResult &comparisons[],
                                                   int count) const
{
    string out = "";
    out += "========================================\n";
    out += "COMPARISONS\n";
    out += StringFormat("  Count : %d\n", count);
    out += "----------------------------------------\n";

    for(int i = 0; i < count; i++)
    {
        out += StringFormat("  [%d] %s vs %s\n", i + 1,
                            comparisons[i].leftId, comparisons[i].rightId);
        out += StringFormat("       Type : %d\n", comparisons[i].type);
        out += StringFormat("       Metric: %s\n", comparisons[i].metricUsed);
        out += StringFormat("       Score : %.4f\n", comparisons[i].score);
        out += StringFormat("       Result: %s\n", comparisons[i].conclusion);
        out += "\n";
    }
    out += "========================================\n";
    return out;
}

string CReportComposer::ComposeBenchmarkSection(const BenchmarkResult &benchmarks[],
                                                  int count) const
{
    string out = "";
    out += "========================================\n";
    out += "BENCHMARK COMPARISONS\n";
    out += StringFormat("  Count : %d\n", count);
    out += "----------------------------------------\n";
    out += "  Strategy    Score   Benchmark   Alpha    Beta\n";
    out += "----------------------------------------\n";

    for(int i = 0; i < count; i++)
    {
        out += StringFormat("  %-12s %-8.4f %-10.4f %-7.4f %-7.4f\n",
                            benchmarks[i].strategyId,
                            benchmarks[i].strategyScore,
                            benchmarks[i].benchmarkScore,
                            benchmarks[i].alpha,
                            benchmarks[i].beta);
    }
    out += "========================================\n";
    return out;
}

string CReportComposer::ComposeStatisticsSection(const StatisticalSummary &summaries[],
                                                   int count) const
{
    string out = "";
    out += "========================================\n";
    out += "STATISTICAL SUMMARIES\n";
    out += StringFormat("  Count : %d\n", count);
    out += "----------------------------------------\n";

    for(int i = 0; i < count; i++)
    {
        out += StringFormat("  [%d] %s\n", i + 1, summaries[i].metricName);
        out += StringFormat("       Mean   : %.4f\n", summaries[i].mean);
        out += StringFormat("       Median : %.4f\n", summaries[i].median);
        out += StringFormat("       StdDev : %.4f\n", summaries[i].stdDev);
        out += StringFormat("       Min    : %.4f\n", summaries[i].min);
        out += StringFormat("       Max    : %.4f\n", summaries[i].max);
        out += StringFormat("       CI     : [%.4f, %.4f] (%d)\n",
                            summaries[i].confidenceIntervalLower,
                            summaries[i].confidenceIntervalUpper,
                            summaries[i].confidence);
        out += StringFormat("       N      : %d\n", summaries[i].sampleCount);
        out += StringFormat("       Assump : %s\n", summaries[i].assumptions);
        out += "\n";
    }
    out += "========================================\n";
    return out;
}

string CReportComposer::ComposeRobustnessSection(double robustnessScore,
                                                   double stabilityIndex) const
{
    string out = "";
    out += "========================================\n";
    out += "ROBUSTNESS ANALYSIS\n";
    out += "----------------------------------------\n";
    out += StringFormat("  Robustness Score : %.4f\n", robustnessScore);
    out += StringFormat("  Stability Index  : %.4f\n", stabilityIndex);
    out += "========================================\n";
    return out;
}

string CReportComposer::ComposeRecommendationSection(const RecommendationRecord &recs[],
                                                       int count) const
{
    string out = "";
    out += "========================================\n";
    out += "RECOMMENDATIONS\n";
    out += StringFormat("  Count : %d\n", count);
    out += "----------------------------------------\n";

    for(int i = 0; i < count; i++)
    {
        string statusStr = "";
        switch(recs[i].status)
        {
            case RECOMMENDATION_STRONG_BUY: statusStr = "STRONG BUY"; break;
            case RECOMMENDATION_BUY: statusStr = "BUY"; break;
            case RECOMMENDATION_NEUTRAL: statusStr = "NEUTRAL"; break;
            case RECOMMENDATION_AVOID: statusStr = "AVOID"; break;
            case RECOMMENDATION_STRONG_AVOID: statusStr = "STRONG AVOID"; break;
            default: statusStr = "INSUFFICIENT DATA"; break;
        }

        out += StringFormat("  [%d] %s: %s\n", i + 1,
                            recs[i].strategyId, statusStr);
        out += StringFormat("       Rationale : %s\n", recs[i].rationale);
        out += StringFormat("       Confidence: %d\n", recs[i].confidence);
        out += "       Evidence:\n";
        for(int j = 0; j < recs[i].evidenceCount; j++)
            out += StringFormat("         - %s\n", recs[i].evidenceRefs[j]);
        out += "\n";
    }
    out += "========================================\n";
    return out;
}

string CReportComposer::ComposeFullReport(void) const
{
    return "";
}

#endif
