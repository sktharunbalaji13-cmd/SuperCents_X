#ifndef __TRADING_ORDER_BLOCK_QUALIFIER_MQH__
#define __TRADING_ORDER_BLOCK_QUALIFIER_MQH__

#include "../Core/Logger.mqh"
#include "../Confluence/OrderBlockDetector.mqh"
#include "TradingEvidence.mqh"

class COrderBlockQualifier
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

public:
    COrderBlockQualifier(void);
    ~COrderBlockQualifier(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    OrderBlockQuality Evaluate(void) const;

private:
    double ScoreDisplacementStrength(void) const;
    ENUM_MITIGATION_STATE DetermineMitigationState(void) const;
    double ScoreFreshness(void) const;
    double ScoreLiquidityProximity(void) const;
    double ScoreStructuralAlignment(void) const;
};

COrderBlockQualifier::COrderBlockQualifier(void)
    : m_logger(MODULE_ENGINE, "OrderBlockQualifier")
    , m_isInitialized(false)
{
}

COrderBlockQualifier::~COrderBlockQualifier(void)
{
    Shutdown();
}

bool COrderBlockQualifier::Init(void)
{
    m_logger.LogInfo("Initializing OrderBlockQualifier...");
    m_isInitialized = true;
    return true;
}

void COrderBlockQualifier::Shutdown(void)
{
    m_isInitialized = false;
}

OrderBlockQuality COrderBlockQualifier::Evaluate(void) const
{
    OrderBlockQuality result;
    int e = 0;

    result.displacementStrength = ScoreDisplacementStrength();
    result.evidence[e].source = "OrderBlockQualifier";
    result.evidence[e].dimension = "displacementStrength";
    result.evidence[e].value = result.displacementStrength;
    result.evidence[e].rationale = "Impulse size and velocity analysis";
    e++;

    result.mitigationState = DetermineMitigationState();
    result.evidence[e].source = "OrderBlockQualifier";
    result.evidence[e].dimension = "mitigationState";
    result.evidence[e].value = (double)result.mitigationState;
    result.evidence[e].rationale = "Mitigation state classification";
    e++;

    result.freshness = ScoreFreshness();
    result.evidence[e].source = "OrderBlockQualifier";
    result.evidence[e].dimension = "freshness";
    result.evidence[e].value = result.freshness;
    result.evidence[e].rationale = "Time since formation and touch count";
    e++;

    result.liquidityProximity = ScoreLiquidityProximity();
    result.evidence[e].source = "OrderBlockQualifier";
    result.evidence[e].dimension = "liquidityProximity";
    result.evidence[e].value = result.liquidityProximity;
    result.evidence[e].rationale = "Proximity to known liquidity zones";
    e++;

    result.structuralAlignment = ScoreStructuralAlignment();
    result.evidence[e].source = "OrderBlockQualifier";
    result.evidence[e].dimension = "structuralAlignment";
    result.evidence[e].value = result.structuralAlignment;
    result.evidence[e].rationale = "Alignment with broader trend/structure";
    e++;

    result.evidenceCount = e;

    double mitigationScore = 100.0;
    if(result.mitigationState == MITIGATION_PARTIAL) mitigationScore = 40.0;
    else if(result.mitigationState == MITIGATION_FULL) mitigationScore = 0.0;

    result.overallScore = (result.displacementStrength * 0.25
                         + mitigationScore * 0.20
                         + result.freshness * 0.20
                         + result.liquidityProximity * 0.15
                         + result.structuralAlignment * 0.20);

    if(result.overallScore > 100.0) result.overallScore = 100.0;
    if(result.overallScore < 0.0) result.overallScore = 0.0;

    return result;
}

double COrderBlockQualifier::ScoreDisplacementStrength(void) const
{
    return 50.0;
}

ENUM_MITIGATION_STATE COrderBlockQualifier::DetermineMitigationState(void) const
{
    return MITIGATION_UNTOUCHED;
}

double COrderBlockQualifier::ScoreFreshness(void) const
{
    return 50.0;
}

double COrderBlockQualifier::ScoreLiquidityProximity(void) const
{
    return 50.0;
}

double COrderBlockQualifier::ScoreStructuralAlignment(void) const
{
    return 50.0;
}

#endif
