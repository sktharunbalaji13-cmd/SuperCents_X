#ifndef __TRADING_CONFLUENCE_ENGINE_MQH__
#define __TRADING_CONFLUENCE_ENGINE_MQH__

#include "../Core/Logger.mqh"
#include "../Structure/TrendState.mqh"
#include "../Confluence/SignalTypes.mqh"
#include "TradingEvidence.mqh"
#include "StructureConfidence.mqh"
#include "OrderBlockQualifier.mqh"
#include "FVGQualifier.mqh"

class CConfluenceEngine
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    CStructureConfidence   m_structureConf;
    COrderBlockQualifier   m_obQualifier;
    CFVGQualifier          m_fvgQualifier;

public:
    CConfluenceEngine(void);
    ~CConfluenceEngine(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    ConfluenceScore Evaluate(void) const;

    void SetWeights(double structure, double ob, double fvg,
                    double liquidity, double trend);
};

CConfluenceEngine::CConfluenceEngine(void)
    : m_logger(MODULE_ENGINE, "ConfluenceEngine")
    , m_isInitialized(false)
{
}

CConfluenceEngine::~CConfluenceEngine(void)
{
    Shutdown();
}

bool CConfluenceEngine::Init(void)
{
    m_logger.LogInfo("Initializing ConfluenceEngine...");
    if(!m_structureConf.Init()) return false;
    if(!m_obQualifier.Init()) return false;
    if(!m_fvgQualifier.Init()) return false;
    m_isInitialized = true;
    return true;
}

void CConfluenceEngine::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_structureConf.Shutdown();
    m_obQualifier.Shutdown();
    m_fvgQualifier.Shutdown();
    m_isInitialized = false;
}

void CConfluenceEngine::SetWeights(double structure, double ob, double fvg,
                                    double liquidity, double trend)
{
}

ConfluenceScore CConfluenceEngine::Evaluate(void) const
{
    ConfluenceScore result;
    int e = 0;

    StructureConfidence sc = m_structureConf.Evaluate();
    result.structureWeight = sc.overallScore;
    result.evidence[e].source = "ConfluenceEngine";
    result.evidence[e].dimension = "structure";
    result.evidence[e].value = result.structureWeight;
    result.evidence[e].rationale = "Structure confidence aggregation";
    e++;

    OrderBlockQuality obq = m_obQualifier.Evaluate();
    result.orderBlockWeight = obq.overallScore;
    result.evidence[e].source = "ConfluenceEngine";
    result.evidence[e].dimension = "orderBlock";
    result.evidence[e].value = result.orderBlockWeight;
    result.evidence[e].rationale = "Order block quality aggregation";
    e++;

    FVGQuality fvg = m_fvgQualifier.Evaluate();
    result.fvgWeight = fvg.overallScore;
    result.evidence[e].source = "ConfluenceEngine";
    result.evidence[e].dimension = "fvg";
    result.evidence[e].value = result.fvgWeight;
    result.evidence[e].rationale = "FVG quality aggregation";
    e++;

    result.evidenceCount = e;

    result.overallScore = (result.structureWeight * 0.25
                         + result.orderBlockWeight * 0.25
                         + result.fvgWeight * 0.20
                         + result.liquidityWeight * 0.15
                         + result.trendWeight * 0.15);

    if(result.overallScore > 100.0) result.overallScore = 100.0;
    if(result.overallScore < 0.0) result.overallScore = 0.0;

    return result;
}

#endif
