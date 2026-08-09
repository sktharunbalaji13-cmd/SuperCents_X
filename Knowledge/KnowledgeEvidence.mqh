#ifndef __KNOWLEDGE_EVIDENCE_MQH__
#define __KNOWLEDGE_EVIDENCE_MQH__

#include "../Utils/Constants.mqh"

enum ENUM_EVIDENCE_SOURCE
{
    EVIDENCE_SOURCE_TRADING = 0,
    EVIDENCE_SOURCE_RESEARCH,
    EVIDENCE_SOURCE_PRODUCTION,
    EVIDENCE_SOURCE_LABORATORY,
    EVIDENCE_SOURCE_KNOWLEDGE
};

enum ENUM_LINEAGE_RELATIONSHIP
{
    LINEAGE_VERSION_BUMP = 0,
    LINEAGE_OB_ADDED,
    LINEAGE_FVG_ADDED,
    LINEAGE_CONFLUENCE_ADDED,
    LINEAGE_CONFIDENCE_ADDED,
    LINEAGE_RESEARCH_ADDED,
    LINEAGE_PRODUCTION_ADDED,
    LINEAGE_PARAMETER_CHANGE,
    LINEAGE_STRATEGY_FORK
};

enum ENUM_TREND_DIRECTION
{
    TREND_IMPROVING = 0,
    TREND_STABLE,
    TREND_DECLINING,
    TREND_VOLATILE,
    TREND_INSUFFICIENT_DATA
};

enum ENUM_RECOMMENDATION_CONFIDENCE
{
    REC_CONFIDENCE_NONE = 0,
    REC_CONFIDENCE_LOW,
    REC_CONFIDENCE_MODERATE,
    REC_CONFIDENCE_HIGH,
    REC_CONFIDENCE_VERY_HIGH
};

struct KnowledgeEvidence
{
    string   source;
    string   dimension;
    double   value;
    string   rationale;
    string   artifactRef;
    string   versionContext;

    KnowledgeEvidence(void)
        : source(""), dimension(""), value(0.0),
          rationale(""), artifactRef(""), versionContext("")
    {}
};

struct KnowledgeObservation
{
    string   observationId;
    string   metricName;
    double   value;
    double   confidence;
    ENUM_RECOMMENDATION_CONFIDENCE confidenceLevel;
    KnowledgeEvidence evidence[16];
    int      evidenceCount;
    datetime timestamp;

    KnowledgeObservation(void)
        : observationId(""), metricName(""), value(0.0),
          confidence(0.0), confidenceLevel(REC_CONFIDENCE_NONE),
          evidenceCount(0), timestamp(0)
    {}
};

struct StrategyVersionNode
{
    string   strategyId;
    string   version;
    string   versionTag;
    string   description;
    double   performanceScore;
    datetime timestamp;
    KnowledgeEvidence evidence[8];
    int      evidenceCount;

    StrategyVersionNode(void)
        : strategyId(""), version(""), versionTag(""),
          description(""), performanceScore(0.0),
          timestamp(0), evidenceCount(0)
    {}
};

struct LineageEdge
{
    string   parentStrategyId;
    string   parentVersion;
    string   childStrategyId;
    string   childVersion;
    ENUM_LINEAGE_RELATIONSHIP relationship;
    double   performanceDelta;
    string   changeDescription;
    KnowledgeEvidence evidence[8];
    int      evidenceCount;

    LineageEdge(void)
        : parentStrategyId(""), parentVersion(""),
          childStrategyId(""), childVersion(""),
          relationship(LINEAGE_VERSION_BUMP), performanceDelta(0.0),
          changeDescription(""), evidenceCount(0)
    {}
};

struct TrendRecord
{
    string   trendId;
    string   metricName;
    ENUM_TREND_DIRECTION direction;
    double   slope;
    double   meanValue;
    double   volatility;
    int      observationCount;
    KnowledgeEvidence evidence[32];
    int      evidenceCount;

    TrendRecord(void)
        : trendId(""), metricName(""),
          direction(TREND_INSUFFICIENT_DATA), slope(0.0),
          meanValue(0.0), volatility(0.0),
          observationCount(0), evidenceCount(0)
    {}
};

struct KnowledgeRecommendation
{
    string   strategyId;
    double   overallScore;
    int      rankPosition;
    string   recommendationStatus;
    ENUM_RECOMMENDATION_CONFIDENCE confidence;
    string   rationale;
    KnowledgeEvidence evidence[32];
    int      evidenceCount;
    double   dimensionScores[8];
    string   dimensionNames[8];
    int      dimensionCount;

    KnowledgeRecommendation(void)
        : strategyId(""), overallScore(0.0),
          rankPosition(0), recommendationStatus("NEUTRAL"),
          confidence(REC_CONFIDENCE_NONE), rationale(""),
          evidenceCount(0), dimensionCount(0)
    {
        for(int i = 0; i < 8; i++)
        {
            dimensionScores[i] = 0.0;
            dimensionNames[i] = "";
        }
    }
};

struct KnowledgeReportSection
{
    string   sectionName;
    string   sectionContent;
    KnowledgeEvidence evidence[16];
    int      evidenceCount;

    KnowledgeReportSection(void)
        : sectionName(""), sectionContent(""), evidenceCount(0)
    {}
};

#endif
