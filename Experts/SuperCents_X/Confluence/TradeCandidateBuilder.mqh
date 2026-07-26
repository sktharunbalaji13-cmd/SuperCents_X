#ifndef __TRADE_CANDIDATE_BUILDER_MQH__
#define __TRADE_CANDIDATE_BUILDER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "../Structure/TrendState.mqh"
#include "../Structure/BOSDetector.mqh"
#include "../Structure/CHOCHDetector.mqh"
#include "../Structure/OrderBlockDetector.mqh"
#include "../Structure/FVGDetector.mqh"
#include "../Structure/LiquidityDetector.mqh"
#include "SignalTypes.mqh"

class CTradeCandidateBuilder
{
private:
    CLogger         m_logger;
    TradeCandidate  m_candidates[];
    int             m_candidateCount;
    int             m_nextId;

    CTrendState            *m_trendState;
    CBOSDetector           *m_bosDetector;
    CCHOCHDetector         *m_chochDetector;
    COrderBlockDetector    *m_orderBlockDetector;
    CFVGDetector           *m_fvgDetector;
    CLiquidityDetector     *m_liquidityDetector;

    int     m_totalCreated;
    int     m_totalExpired;
    int     m_bullishCount;
    int     m_bearishCount;
    int     m_totalScore;
    double  m_totalConfidence;
    int     m_maxEvidence;
    int     m_maxRules;

    bool    HasId(const int &ids[], int count, int id);
    void    PopulateEvidenceFlags(TradeCandidate &c);
    bool    CheckBOStillValid(int id);
    bool    CheckCHOCHStillValid(int id);
    bool    CheckOBStillValid(int id);
    bool    CheckFVGStillValid(int id);
    bool    CheckLiquidityStillValid(int id);

public:
    CTradeCandidateBuilder(void);
    ~CTradeCandidateBuilder(void);

    void SetTrendState(CTrendState *ts);
    void SetBOSDetector(CBOSDetector *bos);
    void SetCHOCHDetector(CCHOCHDetector *choch);
    void SetOrderBlockDetector(COrderBlockDetector *ob);
    void SetFVGDetector(CFVGDetector *fvg);
    void SetLiquidityDetector(CLiquidityDetector *liq);

    void    Update(RuleResult &results[], int resultCount);
    void    Shutdown(void);

    int     GetCandidateCount(void) const { return m_candidateCount; }
    bool    GetCandidate(int index, TradeCandidate &out) const;
};

CTradeCandidateBuilder::CTradeCandidateBuilder(void)
    : m_logger(MODULE_CONFLUENCE_ENGINE, "TradeCandidates")
    , m_candidateCount(0)
    , m_nextId(1)
    , m_totalCreated(0)
    , m_totalExpired(0)
    , m_bullishCount(0)
    , m_bearishCount(0)
    , m_totalScore(0)
    , m_totalConfidence(0.0)
    , m_maxEvidence(0)
    , m_maxRules(0)
{
    m_trendState            = NULL;
    m_bosDetector           = NULL;
    m_chochDetector         = NULL;
    m_orderBlockDetector    = NULL;
    m_fvgDetector           = NULL;
    m_liquidityDetector     = NULL;
}

CTradeCandidateBuilder::~CTradeCandidateBuilder(void)
{
    Shutdown();
}

void CTradeCandidateBuilder::SetTrendState(CTrendState *ts) { m_trendState = ts; }
void CTradeCandidateBuilder::SetBOSDetector(CBOSDetector *bos) { m_bosDetector = bos; }
void CTradeCandidateBuilder::SetCHOCHDetector(CCHOCHDetector *choch) { m_chochDetector = choch; }
void CTradeCandidateBuilder::SetOrderBlockDetector(COrderBlockDetector *ob) { m_orderBlockDetector = ob; }
void CTradeCandidateBuilder::SetFVGDetector(CFVGDetector *fvg) { m_fvgDetector = fvg; }
void CTradeCandidateBuilder::SetLiquidityDetector(CLiquidityDetector *liq) { m_liquidityDetector = liq; }

bool CTradeCandidateBuilder::HasId(const int &ids[], int count, int id)
{
    for(int i = 0; i < count; i++)
        if(ids[i] == id)
            return true;
    return false;
}

void CTradeCandidateBuilder::PopulateEvidenceFlags(TradeCandidate &c)
{
    c.hasBOS = false; c.hasCHOCH = false; c.hasOB = false;
    c.hasFVG = false; c.hasLiquidity = false;
    c.bosId = -1; c.chochId = -1; c.obId = -1; c.fvgId = -1; c.liquidityId = -1;

    for(int r = 0; r < c.ruleCount; r++)
    {
        RuleType rt = c.matchedRules[r];
        if(rt == RULE_BOS_OB_BULLISH || rt == RULE_BOS_OB_BEARISH ||
           rt == RULE_LIQUIDITY_BOS_BULLISH || rt == RULE_LIQUIDITY_BOS_BEARISH)
            c.hasBOS = true;
        if(rt == RULE_CHOCH_OB_REVERSAL)
            c.hasCHOCH = true;
        if(rt == RULE_BOS_OB_BULLISH || rt == RULE_BOS_OB_BEARISH ||
           rt == RULE_OB_FVG_BULLISH || rt == RULE_OB_FVG_BEARISH ||
           rt == RULE_CHOCH_OB_REVERSAL)
            c.hasOB = true;
        if(rt == RULE_OB_FVG_BULLISH || rt == RULE_OB_FVG_BEARISH)
            c.hasFVG = true;
        if(rt == RULE_LIQUIDITY_BOS_BULLISH || rt == RULE_LIQUIDITY_BOS_BEARISH)
            c.hasLiquidity = true;
    }

    for(int i = 0; i < c.evidenceCount; i++)
    {
        int eid = c.evidenceIds[i];
        if(c.hasBOS && c.bosId < 0 && CheckBOStillValid(eid))
            c.bosId = eid;
        if(c.hasCHOCH && c.chochId < 0 && CheckCHOCHStillValid(eid))
            c.chochId = eid;
        if(c.hasOB && c.obId < 0 && CheckOBStillValid(eid))
            c.obId = eid;
        if(c.hasFVG && c.fvgId < 0 && CheckFVGStillValid(eid))
            c.fvgId = eid;
        if(c.hasLiquidity && c.liquidityId < 0 && CheckLiquidityStillValid(eid))
            c.liquidityId = eid;
    }
}

void CTradeCandidateBuilder::Update(RuleResult &results[], int resultCount)
{
    RuleResult bullishRules[7];
    int bullishCount = 0;
    RuleResult bearishRules[7];
    int bearishCount = 0;

    for(int i = 0; i < resultCount; i++)
    {
        if(!results[i].matched)
            continue;

        if(results[i].direction == CONFLUENCE_BULLISH)
        {
            bullishRules[bullishCount] = results[i];
            bullishCount++;
        }
        else if(results[i].direction == CONFLUENCE_BEARISH)
        {
            bearishRules[bearishCount] = results[i];
            bearishCount++;
        }
    }

    TradeCandidate newCandidates[2];
    int newCount = 0;

    if(bullishCount > 0)
    {
        TradeCandidate c;
        c.id = m_nextId++;
        c.direction = CONFLUENCE_BULLISH;
        c.createdTime = TimeCurrent();
        c.status = CANDIDATE_ACTIVE;
        c.ruleCount = 0;
        c.evidenceCount = 0;
        c.score = 0;
        c.confidence = 0.0;

        int bestScore = 0;
        double bestConf = 0.0;

        for(int i = 0; i < bullishCount; i++)
        {
            c.matchedRules[c.ruleCount] = bullishRules[i].type;
            c.ruleCount++;

            if(bullishRules[i].score > bestScore)
                bestScore = bullishRules[i].score;
            if(bullishRules[i].confidence > bestConf)
                bestConf = bullishRules[i].confidence;

            for(int j = 0; j < bullishRules[i].evidenceCount; j++)
            {
                int eid = bullishRules[i].evidenceIds[j];
                if(eid > 0 && !HasId(c.evidenceIds, c.evidenceCount, eid) && c.evidenceCount < MAX_CANDIDATE_EVIDENCE)
                {
                    c.evidenceIds[c.evidenceCount] = eid;
                    c.evidenceCount++;
                }
            }
        }

        c.score = fmin(bestScore + (c.evidenceCount - 1) * 5, 100);
        c.confidence = fmin(bestConf + (bullishCount > 1 ? 0.05 : 0.0), 0.99);

        PopulateEvidenceFlags(c);

        string rationale = "Bullish: ";
        for(int i = 0; i < c.ruleCount; i++)
        {
            if(i > 0) rationale += " + ";
            rationale += (c.matchedRules[i] == RULE_BOS_OB_BULLISH ? "BOS+OB" :
                          c.matchedRules[i] == RULE_OB_FVG_BULLISH ? "OB+FVG" :
                          c.matchedRules[i] == RULE_LIQUIDITY_BOS_BULLISH ? "LIQ+BOS" :
                          c.matchedRules[i] == RULE_CHOCH_OB_REVERSAL ? "CHOCH+OB" : "?");
        }
        c.rationale = rationale;

        newCandidates[newCount] = c;
        newCount++;
    }

    if(bearishCount > 0)
    {
        TradeCandidate c;
        c.id = m_nextId++;
        c.direction = CONFLUENCE_BEARISH;
        c.createdTime = TimeCurrent();
        c.status = CANDIDATE_ACTIVE;
        c.ruleCount = 0;
        c.evidenceCount = 0;
        c.score = 0;
        c.confidence = 0.0;

        int bestScore = 0;
        double bestConf = 0.0;

        for(int i = 0; i < bearishCount; i++)
        {
            c.matchedRules[c.ruleCount] = bearishRules[i].type;
            c.ruleCount++;

            if(bearishRules[i].score > bestScore)
                bestScore = bearishRules[i].score;
            if(bearishRules[i].confidence > bestConf)
                bestConf = bearishRules[i].confidence;

            for(int j = 0; j < bearishRules[i].evidenceCount; j++)
            {
                int eid = bearishRules[i].evidenceIds[j];
                if(eid > 0 && !HasId(c.evidenceIds, c.evidenceCount, eid) && c.evidenceCount < MAX_CANDIDATE_EVIDENCE)
                {
                    c.evidenceIds[c.evidenceCount] = eid;
                    c.evidenceCount++;
                }
            }
        }

        c.score = fmin(bestScore + (c.evidenceCount - 1) * 5, 100);
        c.confidence = fmin(bestConf + (bearishCount > 1 ? 0.05 : 0.0), 0.99);

        PopulateEvidenceFlags(c);

        string rationale = "Bearish: ";
        for(int i = 0; i < c.ruleCount; i++)
        {
            if(i > 0) rationale += " + ";
            rationale += (c.matchedRules[i] == RULE_BOS_OB_BEARISH ? "BOS+OB" :
                          c.matchedRules[i] == RULE_OB_FVG_BEARISH ? "OB+FVG" :
                          c.matchedRules[i] == RULE_LIQUIDITY_BOS_BEARISH ? "LIQ+BOS" :
                          c.matchedRules[i] == RULE_CHOCH_OB_REVERSAL ? "CHOCH+OB" : "?");
        }
        c.rationale = rationale;

        newCandidates[newCount] = c;
        newCount++;
    }

    for(int i = 0; i < newCount; i++)
    {
        m_totalCreated++;
        if(newCandidates[i].direction == CONFLUENCE_BULLISH) m_bullishCount++;
        if(newCandidates[i].direction == CONFLUENCE_BEARISH) m_bearishCount++;
        m_totalScore += newCandidates[i].score;
        m_totalConfidence += newCandidates[i].confidence;
        if(newCandidates[i].evidenceCount > m_maxEvidence)
            m_maxEvidence = newCandidates[i].evidenceCount;
        if(newCandidates[i].ruleCount > m_maxRules)
            m_maxRules = newCandidates[i].ruleCount;

        int idx = m_candidateCount;
        ArrayResize(m_candidates, idx + 1);
        m_candidates[idx] = newCandidates[i];
        m_candidateCount++;

        m_logger.LogInfo(StringFormat("CANDIDATE-CREATED ID=%d dir=%s score=%d conf=%.2f rules=%d ev=%d",
                                       newCandidates[i].id,
                                       (newCandidates[i].direction == CONFLUENCE_BULLISH ? "BULL" :
                                        newCandidates[i].direction == CONFLUENCE_BEARISH ? "BEAR" : "NONE"),
                                       newCandidates[i].score, newCandidates[i].confidence,
                                       newCandidates[i].ruleCount, newCandidates[i].evidenceCount));
    }

    for(int i = 0; i < m_candidateCount; i++)
    {
        if(m_candidates[i].status != CANDIDATE_ACTIVE)
            continue;

        bool anyValid = false;

        if(m_candidates[i].hasBOS)
        {
            if(CheckBOStillValid(m_candidates[i].bosId))
                anyValid = true;
        }
        if(!anyValid && m_candidates[i].hasCHOCH)
        {
            if(CheckCHOCHStillValid(m_candidates[i].chochId))
                anyValid = true;
        }
        if(!anyValid && m_candidates[i].hasOB)
        {
            if(CheckOBStillValid(m_candidates[i].obId))
                anyValid = true;
        }
        if(!anyValid && m_candidates[i].hasFVG)
        {
            if(CheckFVGStillValid(m_candidates[i].fvgId))
                anyValid = true;
        }
        if(!anyValid && m_candidates[i].hasLiquidity)
        {
            if(CheckLiquidityStillValid(m_candidates[i].liquidityId))
                anyValid = true;
        }

        if(!anyValid)
        {
            m_candidates[i].status = CANDIDATE_EXPIRED;
            m_totalExpired++;
            m_logger.LogInfo(StringFormat("CANDIDATE-EXPIRED ID=%d reason=SupportingEvidenceExpired",
                                           m_candidates[i].id));
        }
    }
}

bool CTradeCandidateBuilder::CheckBOStillValid(int id)
{
    if(m_bosDetector == NULL || id < 0) return false;
    int count = m_bosDetector.GetBOSCount();
    for(int i = 0; i < count; i++)
    {
        BOSEvent bos;
        if(m_bosDetector.GetBOS(i, bos) && bos.id == id)
            return true;
    }
    return false;
}

bool CTradeCandidateBuilder::CheckCHOCHStillValid(int id)
{
    if(m_chochDetector == NULL || id < 0) return false;
    int count = m_chochDetector.GetCHOCHCount();
    for(int i = 0; i < count; i++)
    {
        CHOCHEvent choch;
        if(m_chochDetector.GetCHOCH(i, choch) && choch.id == id)
            return true;
    }
    return false;
}

bool CTradeCandidateBuilder::CheckOBStillValid(int id)
{
    if(m_orderBlockDetector == NULL || id < 0) return false;
    int count = m_orderBlockDetector.GetOrderBlockCount();
    for(int i = 0; i < count; i++)
    {
        OrderBlock ob;
        if(m_orderBlockDetector.GetOrderBlock(i, ob) && ob.id == id)
            return !ob.mitigated && !ob.invalidated;
    }
    return false;
}

bool CTradeCandidateBuilder::CheckFVGStillValid(int id)
{
    if(m_fvgDetector == NULL || id < 0) return false;
    int count = m_fvgDetector.GetFVGCount();
    for(int i = 0; i < count; i++)
    {
        FairValueGap fvg;
        if(m_fvgDetector.GetFVG(i, fvg) && fvg.id == id)
            return !fvg.filled;
    }
    return false;
}

bool CTradeCandidateBuilder::CheckLiquidityStillValid(int id)
{
    if(m_liquidityDetector == NULL || id < 0) return false;
    int count = m_liquidityDetector.GetLevelCount();
    for(int i = 0; i < count; i++)
    {
        LiquidityLevel ll;
        if(m_liquidityDetector.GetLevel(i, ll) && ll.id == id)
            return !ll.invalidated;
    }
    return false;
}

void CTradeCandidateBuilder::Shutdown(void)
{
    m_logger.LogInfo("--- TRADE CANDIDATE SUMMARY ---");
    m_logger.LogInfo(StringFormat("  %-28s %5d", "Total Created",     m_totalCreated));
    m_logger.LogInfo(StringFormat("  %-28s %5d", "Total Expired",     m_totalExpired));
    m_logger.LogInfo(StringFormat("  %-28s %5d", "Active Remaining",  m_totalCreated - m_totalExpired));
    m_logger.LogInfo(StringFormat("  %-28s %5d", "Bullish",           m_bullishCount));
    m_logger.LogInfo(StringFormat("  %-28s %5d", "Bearish",           m_bearishCount));
    if(m_totalCreated > 0)
    {
        m_logger.LogInfo(StringFormat("  %-28s %5d", "Avg Score",        m_totalScore / m_totalCreated));
        m_logger.LogInfo(StringFormat("  %-28s %.2f",  "Avg Confidence",   m_totalConfidence / m_totalCreated));
    }
    m_logger.LogInfo(StringFormat("  %-28s %5d", "Max Evidence Set",  m_maxEvidence));
    m_logger.LogInfo(StringFormat("  %-28s %5d", "Max Rule Set",      m_maxRules));

    ArrayFree(m_candidates);
    m_candidateCount = 0;
    m_nextId = 1;

    m_trendState            = NULL;
    m_bosDetector           = NULL;
    m_chochDetector         = NULL;
    m_orderBlockDetector    = NULL;
    m_fvgDetector           = NULL;
    m_liquidityDetector     = NULL;
}

bool CTradeCandidateBuilder::GetCandidate(int index, TradeCandidate &out) const
{
    if(index < 0 || index >= m_candidateCount)
        return false;
    out = m_candidates[index];
    return true;
}

#endif
