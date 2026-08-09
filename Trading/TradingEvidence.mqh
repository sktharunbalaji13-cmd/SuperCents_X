#ifndef __TRADING_TRADING_EVIDENCE_MQH__
#define __TRADING_TRADING_EVIDENCE_MQH__

#include "../Utils/Constants.mqh"

enum ENUM_QUALITY_TIER
{
    QUALITY_VERY_WEAK = 0,
    QUALITY_WEAK,
    QUALITY_MODERATE,
    QUALITY_STRONG,
    QUALITY_EXCEPTIONAL
};

enum ENUM_MITIGATION_STATE
{
    MITIGATION_UNTOUCHED = 0,
    MITIGATION_PARTIAL,
    MITIGATION_FULL
};

struct DetectionEvidence
{
    string   source;
    string   dimension;
    double   value;
    string   rationale;

    DetectionEvidence(void)
        : source(""), dimension(""), value(0.0), rationale("")
    {}
};

struct StructureConfidence
{
    double   overallScore;
    double   swingStrength;
    double   bosConfirmation;
    double   chochQuality;
    double   protectedPointValidity;
    double   noiseFilterRatio;
    DetectionEvidence evidence[16];
    int      evidenceCount;

    StructureConfidence(void)
        : overallScore(0.0), swingStrength(0.0),
          bosConfirmation(0.0), chochQuality(0.0),
          protectedPointValidity(0.0), noiseFilterRatio(1.0),
          evidenceCount(0)
    {}

    ENUM_QUALITY_TIER Tier(void) const
    {
        if(overallScore >= 81) return QUALITY_EXCEPTIONAL;
        if(overallScore >= 61) return QUALITY_STRONG;
        if(overallScore >= 41) return QUALITY_MODERATE;
        if(overallScore >= 21) return QUALITY_WEAK;
        return QUALITY_VERY_WEAK;
    }
};

struct OrderBlockQuality
{
    double   overallScore;
    double   displacementStrength;
    ENUM_MITIGATION_STATE mitigationState;
    double   freshness;
    double   liquidityProximity;
    double   structuralAlignment;
    DetectionEvidence evidence[16];
    int      evidenceCount;

    OrderBlockQuality(void)
        : overallScore(0.0), displacementStrength(0.0),
          mitigationState(MITIGATION_UNTOUCHED), freshness(1.0),
          liquidityProximity(0.0), structuralAlignment(0.0),
          evidenceCount(0)
    {}

    ENUM_QUALITY_TIER Tier(void) const
    {
        if(overallScore >= 81) return QUALITY_EXCEPTIONAL;
        if(overallScore >= 61) return QUALITY_STRONG;
        if(overallScore >= 41) return QUALITY_MODERATE;
        if(overallScore >= 21) return QUALITY_WEAK;
        return QUALITY_VERY_WEAK;
    }
};

struct FVGQuality
{
    double   overallScore;
    double   imbalanceSize;
    double   age;
    double   fillPercentage;
    double   trendAlignment;
    double   structuralSignificance;
    DetectionEvidence evidence[16];
    int      evidenceCount;

    FVGQuality(void)
        : overallScore(0.0), imbalanceSize(0.0), age(1.0),
          fillPercentage(0.0), trendAlignment(0.0),
          structuralSignificance(0.0), evidenceCount(0)
    {}

    ENUM_QUALITY_TIER Tier(void) const
    {
        if(overallScore >= 81) return QUALITY_EXCEPTIONAL;
        if(overallScore >= 61) return QUALITY_STRONG;
        if(overallScore >= 41) return QUALITY_MODERATE;
        if(overallScore >= 21) return QUALITY_WEAK;
        return QUALITY_VERY_WEAK;
    }
};

struct ConfluenceScore
{
    double   overallScore;
    double   structureWeight;
    double   orderBlockWeight;
    double   fvgWeight;
    double   liquidityWeight;
    double   trendWeight;
    DetectionEvidence evidence[32];
    int      evidenceCount;

    ConfluenceScore(void)
        : overallScore(0.0), structureWeight(0.0),
          orderBlockWeight(0.0), fvgWeight(0.0),
          liquidityWeight(0.0), trendWeight(0.0),
          evidenceCount(0)
    {}

    ENUM_QUALITY_TIER Tier(void) const
    {
        if(overallScore >= 81) return QUALITY_EXCEPTIONAL;
        if(overallScore >= 61) return QUALITY_STRONG;
        if(overallScore >= 41) return QUALITY_MODERATE;
        if(overallScore >= 21) return QUALITY_WEAK;
        return QUALITY_VERY_WEAK;
    }
};

struct EntryConfidence
{
    double   overallScore;
    ConfluenceScore confluence;
    StructureConfidence structure;
    double   trendAlignment;
    double   marketContextScore;
    DetectionEvidence evidence[32];
    int      evidenceCount;

    EntryConfidence(void)
        : overallScore(0.0), trendAlignment(0.0),
          marketContextScore(0.0), evidenceCount(0)
    {}

    ENUM_QUALITY_TIER Tier(void) const
    {
        if(overallScore >= 81) return QUALITY_EXCEPTIONAL;
        if(overallScore >= 61) return QUALITY_STRONG;
        if(overallScore >= 41) return QUALITY_MODERATE;
        if(overallScore >= 21) return QUALITY_WEAK;
        return QUALITY_VERY_WEAK;
    }
};

#endif
