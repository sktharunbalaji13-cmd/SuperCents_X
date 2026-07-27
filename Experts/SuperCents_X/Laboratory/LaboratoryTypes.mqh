#ifndef __LABORATORY_LABORATORY_TYPES_MQH__
#define __LABORATORY_LABORATORY_TYPES_MQH__

#include "../Utils/Constants.mqh"

enum ENUM_COMPARISON_TYPE
{
    COMPARISON_PAIRWISE = 0,
    COMPARISON_GROUP,
    COMPARISON_VS_BENCHMARK
};

enum ENUM_RANKING_METHOD
{
    RANKING_SHARPE = 0,
    RANKING_SORTINO,
    RANKING_CALMAR,
    RANKING_PROFIT_FACTOR,
    RANKING_RECOVERY_FACTOR,
    RANKING_ROBUSTNESS_SCORE,
    RANKING_COMPOSITE
};

enum ENUM_CONFIDENCE_LEVEL
{
    CONFIDENCE_NONE = 0,
    CONFIDENCE_LOW,
    CONFIDENCE_MODERATE,
    CONFIDENCE_HIGH,
    CONFIDENCE_VERY_HIGH
};

enum ENUM_BENCHMARK_CLASS
{
    BENCHMARK_BUY_AND_HOLD = 0,
    BENCHMARK_MARKET_INDEX,
    BENCHMARK_RISK_FREE_RATE,
    BENCHMARK_STRATEGY_AVERAGE,
    BENCHMARK_CUSTOM
};

enum ENUM_RECOMMENDATION_STATUS
{
    RECOMMENDATION_STRONG_BUY = 0,
    RECOMMENDATION_BUY,
    RECOMMENDATION_NEUTRAL,
    RECOMMENDATION_AVOID,
    RECOMMENDATION_STRONG_AVOID,
    RECOMMENDATION_INSUFFICIENT_DATA
};

struct LaboratoryManifest
{
    string   laboratoryRunId;
    string   laboratoryVersion;
    int      knowledgeSchemaVersion;
    string   inputArtifactSetId;
    string   comparisonConfigurationId;
    datetime analysisTimestamp;
    string   outputReportId;

    LaboratoryManifest(void)
        : laboratoryRunId(""), laboratoryVersion(""),
          knowledgeSchemaVersion(1), inputArtifactSetId(""),
          comparisonConfigurationId(""), analysisTimestamp(0),
          outputReportId("")
    {}
};

struct StrategyDescriptor
{
    string                strategyId;
    string                strategyName;
    string                version;
    string                description;
    ENUM_BENCHMARK_CLASS  benchmarkClass;

    StrategyDescriptor(void)
        : strategyId(""), strategyName(""), version(""),
          description(""), benchmarkClass(BENCHMARK_BUY_AND_HOLD)
    {}
};

struct ExperimentReference
{
    string   experimentId;
    string   manifestPath;
    string   reportPath;
    string   parameterBundleId;
    datetime experimentDate;

    ExperimentReference(void)
        : experimentId(""), manifestPath(""), reportPath(""),
          parameterBundleId(""), experimentDate(0)
    {}
};

struct ComparisonResult
{
    string               leftId;
    string               rightId;
    ENUM_COMPARISON_TYPE type;
    double               score;
    string               metricUsed;
    string               conclusion;

    ComparisonResult(void)
        : leftId(""), rightId(""), type(COMPARISON_PAIRWISE),
          score(0.0), metricUsed(""), conclusion("")
    {}
};

struct RankingEntry
{
    int                  rank;
    string               strategyId;
    double               score;
    ENUM_RANKING_METHOD  method;
    ENUM_CONFIDENCE_LEVEL confidence;

    RankingEntry(void)
        : rank(0), strategyId(""), score(0.0),
          method(RANKING_COMPOSITE), confidence(CONFIDENCE_NONE)
    {}
};

struct RankingResult
{
    RankingEntry         entries[256];
    int                  entryCount;
    ENUM_RANKING_METHOD  method;
    string               description;

    RankingResult(void)
        : entryCount(0), method(RANKING_COMPOSITE), description("")
    {}
};

struct BenchmarkResult
{
    string               strategyId;
    ENUM_BENCHMARK_CLASS benchmarkClass;
    double               strategyScore;
    double               benchmarkScore;
    double               alpha;
    double               beta;
    ENUM_CONFIDENCE_LEVEL confidence;

    BenchmarkResult(void)
        : strategyId(""), benchmarkClass(BENCHMARK_BUY_AND_HOLD),
          strategyScore(0.0), benchmarkScore(0.0),
          alpha(0.0), beta(0.0), confidence(CONFIDENCE_NONE)
    {}
};

struct StatisticalSummary
{
    string               analysisId;
    string               metricName;
    double               mean;
    double               median;
    double               stdDev;
    double               min;
    double               max;
    int                  sampleCount;
    double               confidenceIntervalLower;
    double               confidenceIntervalUpper;
    ENUM_CONFIDENCE_LEVEL confidence;
    string               assumptions;

    StatisticalSummary(void)
        : analysisId(""), metricName(""),
          mean(0.0), median(0.0), stdDev(0.0),
          min(0.0), max(0.0), sampleCount(0),
          confidenceIntervalLower(0.0), confidenceIntervalUpper(0.0),
          confidence(CONFIDENCE_NONE), assumptions("")
    {}
};

struct KnowledgeEdge
{
    string   fromId;
    string   toId;
    string   relationship;
    double   weight;

    KnowledgeEdge(void)
        : fromId(""), toId(""), relationship(""), weight(0.0)
    {}
};

struct RecommendationRecord
{
    string                     strategyId;
    ENUM_RECOMMENDATION_STATUS status;
    string                     rationale;
    string                     evidenceRefs[64];
    int                        evidenceCount;
    ENUM_CONFIDENCE_LEVEL      confidence;

    RecommendationRecord(void)
        : strategyId(""), status(RECOMMENDATION_INSUFFICIENT_DATA),
          rationale(""), evidenceCount(0), confidence(CONFIDENCE_NONE)
    {}
};

#endif
