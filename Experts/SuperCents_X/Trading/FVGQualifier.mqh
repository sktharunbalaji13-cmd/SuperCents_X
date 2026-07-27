#ifndef __TRADING_FVG_QUALIFIER_MQH__
#define __TRADING_FVG_QUALIFIER_MQH__

#include "../Core/Logger.mqh"
#include "../Confluence/FVGDetector.mqh"
#include "TradingEvidence.mqh"

class CFVGQualifier
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

public:
    CFVGQualifier(void);
    ~CFVGQualifier(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    FVGQuality Evaluate(void) const;

private:
    double ScoreImbalanceSize(void) const;
    double ScoreAge(void) const;
    double ScoreFillPercentage(void) const;
    double ScoreTrendAlignment(void) const;
    double ScoreStructuralSignificance(void) const;
};

CFVGQualifier::CFVGQualifier(void)
    : m_logger(MODULE_ENGINE, "FVGQualifier")
    , m_isInitialized(false)
{
}

CFVGQualifier::~CFVGQualifier(void)
{
    Shutdown();
}

bool CFVGQualifier::Init(void)
{
    m_logger.LogInfo("Initializing FVGQualifier...");
    m_isInitialized = true;
    return true;
}

void CFVGQualifier::Shutdown(void)
{
    m_isInitialized = false;
}

FVGQuality CFVGQualifier::Evaluate(void) const
{
    FVGQuality result;
    int e = 0;

    result.imbalanceSize = ScoreImbalanceSize();
    result.evidence[e].source = "FVGQualifier";
    result.evidence[e].dimension = "imbalanceSize";
    result.evidence[e].value = result.imbalanceSize;
    result.evidence[e].rationale = "Minimum imbalance size threshold check";
    e++;

    result.age = ScoreAge();
    result.evidence[e].source = "FVGQualifier";
    result.evidence[e].dimension = "age";
    result.evidence[e].value = result.age;
    result.evidence[e].rationale = "Time since gap formation";
    e++;

    result.fillPercentage = ScoreFillPercentage();
    result.evidence[e].source = "FVGQualifier";
    result.evidence[e].dimension = "fillPercentage";
    result.evidence[e].value = result.fillPercentage;
    result.evidence[e].rationale = "Gap retracement percentage";
    e++;

    result.trendAlignment = ScoreTrendAlignment();
    result.evidence[e].source = "FVGQualifier";
    result.evidence[e].dimension = "trendAlignment";
    result.evidence[e].value = result.trendAlignment;
    result.evidence[e].rationale = "Direction alignment with prevailing trend";
    e++;

    result.structuralSignificance = ScoreStructuralSignificance();
    result.evidence[e].source = "FVGQualifier";
    result.evidence[e].dimension = "structuralSignificance";
    result.evidence[e].value = result.structuralSignificance;
    result.evidence[e].rationale = "Gap context within nearby structure";
    e++;

    result.evidenceCount = e;

    result.overallScore = (result.imbalanceSize * 0.25
                         + result.age * 0.15
                         + (100.0 - result.fillPercentage) * 0.20
                         + result.trendAlignment * 0.20
                         + result.structuralSignificance * 0.20);

    if(result.overallScore > 100.0) result.overallScore = 100.0;
    if(result.overallScore < 0.0) result.overallScore = 0.0;

    return result;
}

double CFVGQualifier::ScoreImbalanceSize(void) const
{
    return 50.0;
}

double CFVGQualifier::ScoreAge(void) const
{
    return 50.0;
}

double CFVGQualifier::ScoreFillPercentage(void) const
{
    return 0.0;
}

double CFVGQualifier::ScoreTrendAlignment(void) const
{
    return 50.0;
}

double CFVGQualifier::ScoreStructuralSignificance(void) const
{
    return 50.0;
}

#endif
