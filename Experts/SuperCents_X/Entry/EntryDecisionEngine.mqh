#ifndef __ENTRY_DECISION_ENGINE_MQH__
#define __ENTRY_DECISION_ENGINE_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "../Structure/TrendState.mqh"
#include "../Confluence/SignalTypes.mqh"
#include "../Confluence/TradeCandidateBuilder.mqh"
#include "EntryDecisionTypes.mqh"
#include "EntryDecisionRules.mqh"

class CEntryDecisionEngine
{
private:
    bool                m_isInitialized;
    CLogger             m_logger;

    EntryDecisionConfig m_config;
    EntryDecision       m_decisions[];
    int                 m_decisionCount;

    EntryDecision       m_lastDecision;
    bool                m_hasLastDecision;

    CTrendState         *m_trendState;

    int     m_totalEvaluated;
    int     m_totalQualified;
    int     m_totalRejected;
    int     m_totalExpired;
    int     m_totalDecisionScore;
    double  m_totalConfidence;
    int     m_totalEvidence;
    int     m_totalRules;

    void    EvaluateCandidate(const TradeCandidate &candidate);
    void    CheckDecisionLifecycles(CTradeCandidateBuilder &candidateBuilder);

public:
    CEntryDecisionEngine(void);
    ~CEntryDecisionEngine(void);

    bool Init(void);
    void Update(CTradeCandidateBuilder &candidateBuilder);
    void Shutdown(void);

    bool IsInitialized(void) const { return m_isInitialized; }
    void SetConfig(const EntryDecisionConfig &cfg);
    void SetTrendState(CTrendState *ts);

    int  GetDecisionCount(void) const { return m_decisionCount; }
    bool GetDecision(int index, EntryDecision &out) const;
    bool GetLastDecision(EntryDecision &out) const;
};

CEntryDecisionEngine::CEntryDecisionEngine(void)
    : m_isInitialized(false)
    , m_logger(MODULE_ENTRY_DECISION, "EntryDecision")
    , m_decisionCount(0)
    , m_hasLastDecision(false)
    , m_trendState(NULL)
    , m_totalEvaluated(0)
    , m_totalQualified(0)
    , m_totalRejected(0)
    , m_totalExpired(0)
    , m_totalDecisionScore(0)
    , m_totalConfidence(0.0)
    , m_totalEvidence(0)
    , m_totalRules(0)
{
}

CEntryDecisionEngine::~CEntryDecisionEngine(void)
{
    Shutdown();
}

bool CEntryDecisionEngine::Init(void)
{
    if(m_isInitialized)
    {
        m_logger.LogWarn("EntryDecisionEngine already initialized");
        return true;
    }

    m_decisionCount = 0;
    m_hasLastDecision = false;
    m_totalEvaluated = 0;
    m_totalQualified = 0;
    m_totalRejected = 0;
    m_totalExpired = 0;
    m_totalDecisionScore = 0;
    m_totalConfidence = 0.0;
    m_totalEvidence = 0;
    m_totalRules = 0;

    m_isInitialized = true;
    m_logger.LogInfo("EntryDecisionEngine initialized");
    return true;
}

void CEntryDecisionEngine::SetConfig(const EntryDecisionConfig &cfg)
{
    m_config = cfg;
}

void CEntryDecisionEngine::SetTrendState(CTrendState *ts)
{
    m_trendState = ts;
}

void CEntryDecisionEngine::Update(CTradeCandidateBuilder &candidateBuilder)
{
    if(!m_isInitialized)
    {
        m_logger.LogWarn("Update called but EntryDecisionEngine is not initialized");
        return;
    }

    CheckDecisionLifecycles(candidateBuilder);

    int candidateCount = candidateBuilder.GetCandidateCount();

    for(int i = 0; i < candidateCount; i++)
    {
        TradeCandidate candidate;
        if(!candidateBuilder.GetCandidate(i, candidate))
            continue;

        bool alreadyEvaluated = false;
        for(int d = 0; d < m_decisionCount; d++)
        {
            if(m_decisions[d].candidateId == candidate.id)
            {
                alreadyEvaluated = true;
                break;
            }
        }
        if(alreadyEvaluated)
            continue;

        EvaluateCandidate(candidate);
    }
}

void CEntryDecisionEngine::EvaluateCandidate(const TradeCandidate &candidate)
{
    DecisionGates gates;

    CheckScoreGate(candidate, m_config.minDecisionScore, gates.scoreGate);
    CheckConfidenceGate(candidate, m_config.minConfidence, gates.confidenceGate);
    CheckEvidenceGate(candidate, m_config.minEvidenceSources, gates.evidenceGate);
    CheckRuleGate(candidate, m_config.minRuleMatches, gates.ruleGate);

    bool trendPassed = true;
    if(m_config.requireTrendAlignment && m_trendState != NULL)
    {
        Trend currentTrend = m_trendState.GetCurrentTrend();
        if(candidate.direction == CONFLUENCE_BULLISH)
        {
            trendPassed = (currentTrend == TREND_BULLISH);
        }
        else if(candidate.direction == CONFLUENCE_BEARISH)
        {
            trendPassed = (currentTrend == TREND_BEARISH);
        }
    }
    gates.trendGate.passed = trendPassed;
    gates.trendGate.applicable = m_config.requireTrendAlignment;
    if(!trendPassed && m_config.requireTrendAlignment)
    {
        gates.trendGate.explanation = "Candidate direction does not align with current trend";
    }
    else if(m_config.requireTrendAlignment)
    {
        gates.trendGate.explanation = "Trend aligned with candidate direction";
    }

    bool qualified = gates.scoreGate.passed
                  && gates.confidenceGate.passed
                  && gates.evidenceGate.passed
                  && gates.ruleGate.passed
                  && gates.trendGate.passed;

    EntryDecision decision;
    decision.candidateId = candidate.id;
    decision.direction = candidate.direction;
    decision.decisionScore = candidate.score;
    decision.confidence = candidate.confidence;
    decision.evidenceCount = candidate.evidenceCount;
    decision.ruleCount = candidate.ruleCount;
    decision.createdTime = TimeCurrent();
    decision.rejectionCount = 0;

    if(qualified)
    {
        decision.status = DECISION_QUALIFIED;

        string reasonStr = "";
        if(gates.scoreGate.applicable)
            reasonStr += StringFormat("Score %d >= %d", candidate.score, m_config.minDecisionScore);
        if(gates.confidenceGate.applicable)
            reasonStr += StringFormat("%sConfidence %.2f >= %.2f",
                                      (reasonStr != "" ? " | " : ""),
                                      candidate.confidence, m_config.minConfidence);
        if(gates.evidenceGate.applicable)
            reasonStr += StringFormat("%s%d evidence sources >= %d",
                                      (reasonStr != "" ? " | " : ""),
                                      candidate.evidenceCount, m_config.minEvidenceSources);
        if(gates.ruleGate.applicable)
            reasonStr += StringFormat("%s%d matching rules >= %d",
                                      (reasonStr != "" ? " | " : ""),
                                      candidate.ruleCount, m_config.minRuleMatches);
        if(gates.trendGate.applicable)
            reasonStr += StringFormat("%sTrend aligned", (reasonStr != "" ? " | " : ""));

        decision.rationale = reasonStr;

        m_logger.LogInfo(StringFormat("ENTRY-QUALIFIED Candidate=%d Score=%d Confidence=%.2f Reasons: %s",
                                       candidate.id, candidate.score, candidate.confidence, reasonStr));

        m_totalQualified++;
    }
    else
    {
        decision.status = DECISION_REJECTED;

        string allReasons = "";
        if(!gates.scoreGate.passed && gates.scoreGate.applicable)
        {
            decision.rejectionReasons[decision.rejectionCount++] = gates.scoreGate.explanation;
            allReasons += (allReasons != "" ? " | " : "") + gates.scoreGate.explanation;
        }
        if(!gates.confidenceGate.passed && gates.confidenceGate.applicable)
        {
            decision.rejectionReasons[decision.rejectionCount++] = gates.confidenceGate.explanation;
            allReasons += (allReasons != "" ? " | " : "") + gates.confidenceGate.explanation;
        }
        if(!gates.evidenceGate.passed && gates.evidenceGate.applicable)
        {
            decision.rejectionReasons[decision.rejectionCount++] = gates.evidenceGate.explanation;
            allReasons += (allReasons != "" ? " | " : "") + gates.evidenceGate.explanation;
        }
        if(!gates.ruleGate.passed && gates.ruleGate.applicable)
        {
            decision.rejectionReasons[decision.rejectionCount++] = gates.ruleGate.explanation;
            allReasons += (allReasons != "" ? " | " : "") + gates.ruleGate.explanation;
        }
        if(!gates.trendGate.passed && gates.trendGate.applicable)
        {
            decision.rejectionReasons[decision.rejectionCount++] = gates.trendGate.explanation;
            allReasons += (allReasons != "" ? " | " : "") + gates.trendGate.explanation;
        }

        decision.rationale = allReasons;

        m_logger.LogInfo(StringFormat("ENTRY-REJECTED Candidate=%d Reasons: %s",
                                       candidate.id, allReasons));

        m_totalRejected++;
    }

    int idx = m_decisionCount;
    ArrayResize(m_decisions, idx + 1);
    m_decisions[idx] = decision;
    m_decisionCount++;

    m_lastDecision = decision;
    m_hasLastDecision = true;

    m_totalEvaluated++;
    m_totalDecisionScore += decision.decisionScore;
    m_totalConfidence += decision.confidence;
    m_totalEvidence += decision.evidenceCount;
    m_totalRules += decision.ruleCount;
}

void CEntryDecisionEngine::CheckDecisionLifecycles(CTradeCandidateBuilder &candidateBuilder)
{
    int activeIds[];
    int activeCount = 0;
    {
        int candidateCount = candidateBuilder.GetCandidateCount();
        ArrayResize(activeIds, candidateCount);
        for(int c = 0; c < candidateCount; c++)
        {
            TradeCandidate tc;
            if(candidateBuilder.GetCandidate(c, tc) && tc.status == CANDIDATE_ACTIVE)
            {
                activeIds[activeCount] = tc.id;
                activeCount++;
            }
        }
    }

    for(int i = 0; i < m_decisionCount; i++)
    {
        if(m_decisions[i].status != DECISION_QUALIFIED)
            continue;

        bool found = false;
        for(int c = 0; c < activeCount; c++)
        {
            if(activeIds[c] == m_decisions[i].candidateId)
            {
                found = true;
                break;
            }
        }

        if(!found)
        {
            m_decisions[i].status = DECISION_REJECTED;
            m_totalExpired++;
            m_logger.LogInfo(StringFormat("ENTRY-EXPIRED Candidate=%d reason=CandidateExpired",
                                           m_decisions[i].candidateId));
        }
    }
}

void CEntryDecisionEngine::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("========================== ENTRY DECISION SUMMARY ==========================");
    m_logger.LogInfo(StringFormat("  %-35s %5d", "Candidates Evaluated",     m_totalEvaluated));
    m_logger.LogInfo(StringFormat("  %-35s %5d", "Qualified",                m_totalQualified));
    m_logger.LogInfo(StringFormat("  %-35s %5d", "Rejected",                 m_totalRejected));
    m_logger.LogInfo(StringFormat("  %-35s %5d", "Expired",                  m_totalExpired));
    if(m_totalEvaluated > 0)
    {
        m_logger.LogInfo(StringFormat("  %-35s %.2f",  "Avg Decision Score",     (double)m_totalDecisionScore / m_totalEvaluated));
        m_logger.LogInfo(StringFormat("  %-35s %.2f",  "Avg Confidence",         m_totalConfidence / m_totalEvaluated));
        m_logger.LogInfo(StringFormat("  %-35s %.2f",  "Avg Evidence Count",     (double)m_totalEvidence / m_totalEvaluated));
        m_logger.LogInfo(StringFormat("  %-35s %.2f",  "Avg Rule Count",         (double)m_totalRules / m_totalEvaluated));
    }
    m_logger.LogInfo("========================================================================");

    ArrayFree(m_decisions);
    m_decisionCount = 0;
    m_trendState = NULL;

    m_isInitialized = false;
    m_logger.LogInfo("EntryDecisionEngine shutdown complete");
}

bool CEntryDecisionEngine::GetDecision(int index, EntryDecision &out) const
{
    if(index < 0 || index >= m_decisionCount)
        return false;
    out = m_decisions[index];
    return true;
}

//--- Most recently evaluated decision (shadow comparison: decision-level
//    like-for-like with the new engine). Decisions persist until superseded
//    or expired, mirroring the plan lifecycle the legacy side used before.
bool CEntryDecisionEngine::GetLastDecision(EntryDecision &out) const
{
    if(!m_hasLastDecision)
        return false;
    out = m_lastDecision;
    return true;
}

#endif
