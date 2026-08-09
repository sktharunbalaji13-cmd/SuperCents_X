#ifndef __TRADING_ENTRY_CONFIDENCE_ENGINE_MQH__
#define __TRADING_ENTRY_CONFIDENCE_ENGINE_MQH__

#include "../Core/Logger.mqh"
#include "../Structure/TrendState.mqh"
#include "../Confluence/SignalTypes.mqh"
#include "TradingEvidence.mqh"
#include "ConfluenceEngine.mqh"

class CEntryConfidenceEngine
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    CConfluenceEngine m_confluence;

public:
    CEntryConfidenceEngine(void);
    ~CEntryConfidenceEngine(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    EntryConfidence Evaluate(void) const;

private:
    double ScoreTrendAlignment(void) const;
    double ScoreMarketContext(void) const;
};

CEntryConfidenceEngine::CEntryConfidenceEngine(void)
    : m_logger(MODULE_ENGINE, "EntryConfidenceEngine")
    , m_isInitialized(false)
{
}

CEntryConfidenceEngine::~CEntryConfidenceEngine(void)
{
    Shutdown();
}

bool CEntryConfidenceEngine::Init(void)
{
    m_logger.LogInfo("Initializing EntryConfidenceEngine...");
    if(!m_confluence.Init()) return false;
    m_isInitialized = true;
    return true;
}

void CEntryConfidenceEngine::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_confluence.Shutdown();
    m_isInitialized = false;
}

EntryConfidence CEntryConfidenceEngine::Evaluate(void) const
{
    EntryConfidence result;
    int e = 0;

    result.confluence = m_confluence.Evaluate();

    result.structure = result.confluence.Evaluate();

    result.trendAlignment = ScoreTrendAlignment();
    result.evidence[e].source = "EntryConfidenceEngine";
    result.evidence[e].dimension = "trendAlignment";
    result.evidence[e].value = result.trendAlignment;
    result.evidence[e].rationale = "Trend alignment assessment";
    e++;

    result.marketContextScore = ScoreMarketContext();
    result.evidence[e].source = "EntryConfidenceEngine";
    result.evidence[e].dimension = "marketContext";
    result.evidence[e].value = result.marketContextScore;
    result.evidence[e].rationale = "Market context evaluation";
    e++;

    result.evidenceCount = e;

    result.overallScore = (result.confluence.overallScore * 0.50
                         + result.trendAlignment * 0.25
                         + result.marketContextScore * 0.25);

    if(result.overallScore > 100.0) result.overallScore = 100.0;
    if(result.overallScore < 0.0) result.overallScore = 0.0;

    return result;
}

double CEntryConfidenceEngine::ScoreTrendAlignment(void) const
{
    return 50.0;
}

double CEntryConfidenceEngine::ScoreMarketContext(void) const
{
    return 50.0;
}

#endif
