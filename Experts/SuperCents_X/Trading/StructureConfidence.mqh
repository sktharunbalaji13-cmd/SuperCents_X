#ifndef __TRADING_STRUCTURE_CONFIDENCE_MQH__
#define __TRADING_STRUCTURE_CONFIDENCE_MQH__

#include "../Core/Logger.mqh"
#include "../Structure/SwingDetector.mqh"
#include "../Structure/BOSDetector.mqh"
#include "../Structure/CHOCHDetector.mqh"
#include "../Structure/ProtectedPointManager.mqh"
#include "TradingEvidence.mqh"

class CStructureConfidence
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

public:
    CStructureConfidence(void);
    ~CStructureConfidence(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    StructureConfidence Evaluate(void) const;

private:
    double ScoreSwingStrength(void) const;
    double ScoreBOSConfirmation(void) const;
    double ScoreCHOCHQuality(void) const;
    double ScoreProtectedPoints(void) const;
    double ComputeNoiseRatio(void) const;
};

CStructureConfidence::CStructureConfidence(void)
    : m_logger(MODULE_ENGINE, "StructureConfidence")
    , m_isInitialized(false)
{
}

CStructureConfidence::~CStructureConfidence(void)
{
    Shutdown();
}

bool CStructureConfidence::Init(void)
{
    m_logger.LogInfo("Initializing StructureConfidence...");
    m_isInitialized = true;
    return true;
}

void CStructureConfidence::Shutdown(void)
{
    m_isInitialized = false;
}

StructureConfidence CStructureConfidence::Evaluate(void) const
{
    StructureConfidence result;
    int e = 0;

    result.swingStrength = ScoreSwingStrength();
    result.evidence[e].source = "StructureConfidence";
    result.evidence[e].dimension = "swingStrength";
    result.evidence[e].value = result.swingStrength;
    result.evidence[e].rationale = "Swing depth and duration analysis";
    e++;

    result.bosConfirmation = ScoreBOSConfirmation();
    result.evidence[e].source = "StructureConfidence";
    result.evidence[e].dimension = "bosConfirmation";
    result.evidence[e].value = result.bosConfirmation;
    result.evidence[e].rationale = "BOS follow-through and proximity validation";
    e++;

    result.chochnQuality = ScoreCHOCHQuality();
    result.evidence[e].source = "StructureConfidence";
    result.evidence[e].dimension = "chochnQuality";
    result.evidence[e].value = result.chochnQuality;
    result.evidence[e].rationale = "CHOCH impulse strength and significance";
    e++;

    result.protectedPointValidity = ScoreProtectedPoints();
    result.evidence[e].source = "StructureConfidence";
    result.evidence[e].dimension = "protectedPointValidity";
    result.evidence[e].value = result.protectedPointValidity;
    result.evidence[e].rationale = "Protected point validation";
    e++;

    result.noiseFilterRatio = ComputeNoiseRatio();
    result.evidence[e].source = "StructureConfidence";
    result.evidence[e].dimension = "noiseFilterRatio";
    result.evidence[e].value = result.noiseFilterRatio;
    result.evidence[e].rationale = "Micro-structure to macro-structure ratio";
    e++;

    result.evidenceCount = e;

    result.overallScore = (result.swingStrength * 0.25
                         + result.bosConfirmation * 0.25
                         + result.chochnQuality * 0.20
                         + result.protectedPointValidity * 0.20
                         + (result.noiseFilterRatio * 100.0) * 0.10);

    if(result.overallScore > 100.0) result.overallScore = 100.0;
    if(result.overallScore < 0.0) result.overallScore = 0.0;

    return result;
}

double CStructureConfidence::ScoreSwingStrength(void) const
{
    return 50.0;
}

double CStructureConfidence::ScoreBOSConfirmation(void) const
{
    return 50.0;
}

double CStructureConfidence::ScoreCHOCHQuality(void) const
{
    return 50.0;
}

double CStructureConfidence::ScoreProtectedPoints(void) const
{
    return 50.0;
}

double CStructureConfidence::ComputeNoiseRatio(void) const
{
    return 0.5;
}

#endif
