#ifndef __CONFLUENCE_ENGINE_MQH__
#define __CONFLUENCE_ENGINE_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "../Structure/TrendState.mqh"
#include "../Structure/BOSDetector.mqh"
#include "../Structure/CHOCHDetector.mqh"
#include "../Structure/OrderBlockDetector.mqh"
#include "../Structure/FVGDetector.mqh"
#include "../Structure/ProtectedPointManager.mqh"
#include "../Structure/LiquidityDetector.mqh"
#include "SignalTypes.mqh"
#include "ScoreCalculator.mqh"
#include "ConfluenceRules.mqh"
#include "TradeCandidateBuilder.mqh"
#include "../Entry/EntryDecisionEngine.mqh"
#include "../Entry/ExecutionPlanner.mqh"

#include "ConfluenceTypes.mqh"
#include "ConfluenceWeights.mqh"
#include "ConfluenceScoreCalculator.mqh"
#include "ConfluenceLogger.mqh"
#include "Evaluators/IConfluenceEvaluator.mqh"

#define EXPIRY_REASON_COUNT 7

class CConfluenceEngine
{
private:
    bool                m_isInitialized;
    CLogger             m_logger;
    int                 m_nextSignalId;

    CTrendState              *m_trendState;
    CBOSDetector             *m_bosDetector;
    CCHOCHDetector           *m_chochDetector;
    COrderBlockDetector      *m_orderBlockDetector;
    CFVGDetector             *m_fvgDetector;
    CProtectedPointManager   *m_protectedPointManager;
    CLiquidityDetector       *m_liquidityDetector;

    CTradeCandidateBuilder  m_candidateBuilder;
    CEntryDecisionEngine    m_entryDecisionEngine;
    CExecutionPlanner       m_executionPlanner;

    ConfluenceSignal    m_signals[];
    int                 m_signalCount;
    ConfluenceSignal    m_latestSignal;
    bool                m_hasLatest;

    int     m_totalSignalsCreated;
    int     m_totalSignalsExpired;
    int     m_bullishCount;
    int     m_bearishCount;
    int     m_expiryCounts[EXPIRY_REASON_COUNT];
    int     m_ruleMatchCounts[8];
    int     m_ruleRejectCounts[8];

    IConfluenceEvaluator    *m_evaluators[];
    int                      m_evaluatorCount;
    CConfluenceScoreCalculator  m_scoreCalc;
    CConfluenceLogger           m_confluenceLogger;
    ConfluenceWeights           m_weights;
    ConfluenceResult            m_latestConfluence;
    bool                        m_hasConfluence;

    void    CheckSignalLifecycles(void);
    void    ExpireSignal(int index, ExpiryReason reason);
    void    BuildDetectionContext(DetectionContext &context);
    bool    EvaluateViaEvaluators(ConfluenceDirection dir, ConfluenceResult &result);
    void    BridgeConfluenceToSignal(const ConfluenceResult &cr, RuleResult &bestRule, ScoreLayer &score);

public:
    CConfluenceEngine(void);
    ~CConfluenceEngine(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);

    bool IsInitialized(void) const { return m_isInitialized; }

    void SetTrendState(CTrendState *trendState);
    void SetBOSDetector(CBOSDetector *bosDetector);
    void SetCHOCHDetector(CCHOCHDetector *chochDetector);
    void SetOrderBlockDetector(COrderBlockDetector *orderBlockDetector);
    void SetFVGDetector(CFVGDetector *fvgDetector);
    void SetProtectedPointManager(CProtectedPointManager *protectedPointManager);
    void SetLiquidityDetector(CLiquidityDetector *liquidityDetector);

    int GetSignalCount(void) const { return m_signalCount; }
    bool GetSignal(int index, ConfluenceSignal &out) const;
    bool GetLatestSignal(ConfluenceSignal &out) const;

    CExecutionPlanner *GetExecutionPlanner(void) { return &m_executionPlanner; }
    bool GetLastEntryDecision(EntryDecision &out) const { return m_entryDecisionEngine.GetLastDecision(out); }

    bool RegisterEvaluator(IConfluenceEvaluator *evaluator);
    void SetWeights(const ConfluenceWeights &weights);
    bool GetLatestConfluence(ConfluenceResult &out) const;
    bool IsUsingEvaluators(void) const { return m_evaluatorCount > 0; }
};

CConfluenceEngine::CConfluenceEngine(void)
    : m_isInitialized(false)
    , m_logger(MODULE_CONFLUENCE_ENGINE, "ConfluenceEngine")
    , m_nextSignalId(1)
    , m_signalCount(0)
    , m_hasLatest(false)
    , m_totalSignalsCreated(0)
    , m_totalSignalsExpired(0)
    , m_bullishCount(0)
    , m_bearishCount(0)
    , m_evaluatorCount(0)
    , m_hasConfluence(false)
{
    m_trendState            = NULL;
    m_bosDetector           = NULL;
    m_chochDetector         = NULL;
    m_orderBlockDetector    = NULL;
    m_fvgDetector           = NULL;
    m_protectedPointManager = NULL;
    m_liquidityDetector     = NULL;

    for(int i = 0; i < EXPIRY_REASON_COUNT; i++)
        m_expiryCounts[i] = 0;
    for(int i = 0; i < 8; i++)
    {
        m_ruleMatchCounts[i] = 0;
        m_ruleRejectCounts[i] = 0;
    }
}

CConfluenceEngine::~CConfluenceEngine(void)
{
    Shutdown();
}

bool CConfluenceEngine::Init(void)
{
    if(m_isInitialized)
    {
        m_logger.LogWarn("ConfluenceEngine already initialized");
        return true;
    }

    m_logger.LogInfo("Initializing ConfluenceEngine...");

    m_nextSignalId = 1;
    m_signalCount = 0;
    m_hasLatest = false;
    m_totalSignalsCreated = 0;
    m_totalSignalsExpired = 0;
    m_bullishCount = 0;
    m_bearishCount = 0;

    for(int i = 0; i < EXPIRY_REASON_COUNT; i++)
        m_expiryCounts[i] = 0;
    for(int i = 0; i < 8; i++)
    {
        m_ruleMatchCounts[i] = 0;
        m_ruleRejectCounts[i] = 0;
    }

    m_entryDecisionEngine.Init();
    m_executionPlanner.Init();
    m_executionPlanner.SetCandidateBuilder(&m_candidateBuilder);

    m_isInitialized = true;

    m_logger.LogInfo("ConfluenceEngine initialized");
    return true;
}

void CConfluenceEngine::Update(void)
{
    if(!m_isInitialized)
    {
        m_logger.LogWarn("Update called but ConfluenceEngine is not initialized");
        return;
    }

    CheckSignalLifecycles();

    ConfluenceDirection dir = CONFLUENCE_NONE;
    ScoreLayer score;
    score.structural = 0;
    score.liquidity = 0;
    score.confirmation = 0;
    score.total = 0;
    score.trendAligned = false;

    RuleResult bestRule;
    bestRule.matched = false;
    bestRule.type = RULE_NONE;
    bestRule.score = 0;
    bestRule.confidence = 0.0;
    bestRule.direction = CONFLUENCE_NONE;
    bestRule.evidenceCount = 0;
    bestRule.explanation = "";
    bestRule.timestamp = 0;

    RuleResult results[7];
    int matchCount = 0;

    if(m_evaluatorCount > 0)
    {
        DetectionContext context;
        BuildDetectionContext(context);

        ConfluenceResult crBull, crBear;
        bool hasBull = EvaluateViaEvaluators(CONFLUENCE_BULLISH, crBull);
        bool hasBear = EvaluateViaEvaluators(CONFLUENCE_BEARISH, crBear);

        bool useBullish = (hasBull && (!hasBear || crBull.totalConfidence >= crBear.totalConfidence));
        bool useBearish = (hasBear && (!hasBull || crBear.totalConfidence > crBull.totalConfidence));

        ConfluenceResult cr;
        if(useBullish)
        {
            cr = crBull;
            dir = CONFLUENCE_BULLISH;
        }
        else if(useBearish)
        {
            cr = crBear;
            dir = CONFLUENCE_BEARISH;
        }

        m_hasConfluence = cr.valid;
        m_latestConfluence = cr;

        if(cr.valid)
        {
            m_confluenceLogger.LogEvaluation(cr);
            BridgeConfluenceToSignal(cr, bestRule, score);
        }
    }
    else
    {
        results[0] = RuleBOS_OB_Bullish(m_trendState, m_bosDetector, m_orderBlockDetector);
        results[1] = RuleBOS_OB_Bearish(m_trendState, m_bosDetector, m_orderBlockDetector);
        results[2] = RuleOB_FVG_Bullish(m_orderBlockDetector, m_fvgDetector);
        results[3] = RuleOB_FVG_Bearish(m_orderBlockDetector, m_fvgDetector);
        results[4] = RuleLiquidity_BOS_Bullish(m_trendState, m_liquidityDetector, m_bosDetector);
        results[5] = RuleLiquidity_BOS_Bearish(m_trendState, m_liquidityDetector, m_bosDetector);
        results[6] = RuleCHOCH_OB_Reversal(m_chochDetector, m_orderBlockDetector);

        int bestIdx = -1;
        int bestScoreVal = 0;

        for(int i = 0; i < 7; i++)
        {
            if(results[i].matched)
            {
                matchCount++;
                m_ruleMatchCounts[results[i].type]++;
                m_logger.LogInfo(results[i].ToString());
                if(results[i].score > bestScoreVal)
                {
                    bestScoreVal = results[i].score;
                    bestIdx = i;
                }
            }
            else
            {
                m_ruleRejectCounts[results[i].type]++;
                m_logger.LogDebug(StringFormat("RULE-REJECT type=%d reason=%s",
                                               results[i].type, results[i].explanation));
            }
        }

        if(bestIdx >= 0)
        {
            bestRule = results[bestIdx];
            dir = bestRule.direction;

            LayerResult layers = CalculateRuleLayers(bestRule,
                                                      m_trendState,
                                                      m_bosDetector,
                                                      m_orderBlockDetector,
                                                      m_fvgDetector,
                                                      m_liquidityDetector);
            score.structural = layers.structural;
            score.liquidity = layers.liquidity;
            score.confirmation = layers.confirmation;
            score.total = layers.total;
            score.trendAligned = layers.trendAligned;
            score.layerOrderBlock = layers.layerOrderBlock;
            score.layerFVG = layers.layerFVG;
        }
    }

    if(dir == CONFLUENCE_BULLISH || dir == CONFLUENCE_BEARISH)
    {
        m_hasConfluence = true;
        m_latestConfluence.valid = true;
        m_latestConfluence.direction = dir;
        m_latestConfluence.totalConfidence = (double)score.total;
        //--- TC02: component raw/weight/contribution wiring at decision
        //    time.  The evaluator path copies cr (components already
        //    populated by CConfluenceScoreCalculator); the rule path
        //    derives them from the layer slices already computed.
        if(m_evaluatorCount <= 0)
            BuildRulePathComponents(score, m_weights,
                                    m_latestConfluence.components,
                                    m_latestConfluence.componentCount);
        m_latestConfluence.summaryExplanation = bestRule.explanation;
    }

    if(dir == CONFLUENCE_BULLISH) m_bullishCount++;
    if(dir == CONFLUENCE_BEARISH) m_bearishCount++;

    ConfluenceSignal sig;
    sig.id               = m_nextSignalId++;
    sig.time             = iTime(_Symbol, _Period, 0);
    sig.price            = iClose(_Symbol, _Period, 0);
    sig.direction        = dir;
    sig.lifecycle        = SIGNAL_ACTIVE;
    sig.expiryReason     = EXPIRY_NONE;
    sig.score            = score;
    sig.currentRule      = bestRule;

    sig.hasBOS           = (bestRule.type == RULE_BOS_OB_BULLISH || bestRule.type == RULE_BOS_OB_BEARISH ||
                             bestRule.type == RULE_LIQUIDITY_BOS_BULLISH || bestRule.type == RULE_LIQUIDITY_BOS_BEARISH);
    sig.hasCHOCH         = (bestRule.type == RULE_CHOCH_OB_REVERSAL);
    sig.hasOrderBlock    = (bestRule.type == RULE_BOS_OB_BULLISH || bestRule.type == RULE_BOS_OB_BEARISH ||
                             bestRule.type == RULE_OB_FVG_BULLISH || bestRule.type == RULE_OB_FVG_BEARISH ||
                             bestRule.type == RULE_CHOCH_OB_REVERSAL);
    sig.hasFVG           = (bestRule.type == RULE_OB_FVG_BULLISH || bestRule.type == RULE_OB_FVG_BEARISH);
    sig.hasProtectedPoint = false;
    sig.hasLiquiditySweep = (bestRule.type == RULE_LIQUIDITY_BOS_BULLISH || bestRule.type == RULE_LIQUIDITY_BOS_BEARISH);
    sig.trendAligned     = score.trendAligned;

    sig.bosId            = (bestRule.evidenceCount > 0 ? bestRule.evidenceIds[0] : -1);
    sig.chochId          = (sig.hasCHOCH && bestRule.evidenceCount > 0 ? bestRule.evidenceIds[0] : -1);
    sig.orderBlockId     = -1;
    sig.fvgId            = -1;
    sig.protectedPointId = -1;
    sig.liquidityLevelId = -1;

    for(int i = 0; i < bestRule.evidenceCount; i++)
    {
        int eid = bestRule.evidenceIds[i];
        if(sig.hasOrderBlock && sig.orderBlockId < 0) sig.orderBlockId = eid;
        if(sig.hasFVG && sig.fvgId < 0)             sig.fvgId = eid;
        if(sig.hasLiquiditySweep && sig.liquidityLevelId < 0) sig.liquidityLevelId = eid;
    }

    int idx = m_signalCount;
    ArrayResize(m_signals, idx + 1);
    m_signals[idx] = sig;
    m_signalCount++;
    m_latestSignal = sig;
    m_hasLatest = true;
    m_totalSignalsCreated++;

    m_logger.LogDebug(StringFormat("SIGNAL #%d: %s score=[%s] rule=%d conf=%.2f ev=[%s]",
                                    sig.id,
                                    (sig.direction == CONFLUENCE_BULLISH ? "BULL" :
                                     sig.direction == CONFLUENCE_BEARISH ? "BEAR" : "NONE"),
                                    sig.score.ToString(),
                                    sig.currentRule.type,
                                    sig.currentRule.confidence,
                                    sig.currentRule.EvidenceIdsToString()));

    m_candidateBuilder.Update(results, 7);
    m_entryDecisionEngine.Update(m_candidateBuilder);
    m_executionPlanner.Update(m_entryDecisionEngine, m_candidateBuilder);
}

void CConfluenceEngine::CheckSignalLifecycles(void)
{
    for(int i = 0; i < m_signalCount; i++)
    {
        if(m_signals[i].lifecycle != SIGNAL_ACTIVE)
            continue;

        int sigIdx = i;
        ExpiryReason reason = EXPIRY_NONE;

        if(m_signals[sigIdx].hasFVG && m_signals[sigIdx].fvgId >= 0)
        {
            FairValueGap fvg;
            if(m_fvgDetector != NULL)
            {
                int fvgCount = m_fvgDetector.GetFVGCount();
                bool found = false;
                for(int j = 0; j < fvgCount; j++)
                {
                    if(m_fvgDetector.GetFVG(j, fvg) && fvg.id == m_signals[sigIdx].fvgId)
                    {
                        found = true;
                        if(fvg.filled)
                        {
                            reason = EXPIRY_FVG_FILLED;
                        }
                        break;
                    }
                }
                if(!found)
                    reason = EXPIRY_FVG_FILLED;
            }
        }

        if(reason == EXPIRY_NONE && m_signals[sigIdx].hasOrderBlock && m_signals[sigIdx].orderBlockId >= 0)
        {
            OrderBlock ob;
            if(m_orderBlockDetector != NULL)
            {
                int obCount = m_orderBlockDetector.GetOrderBlockCount();
                bool found = false;
                for(int j = 0; j < obCount; j++)
                {
                    if(m_orderBlockDetector.GetOrderBlock(j, ob) && ob.id == m_signals[sigIdx].orderBlockId)
                    {
                        found = true;
                        if(ob.mitigated)
                            reason = EXPIRY_OB_MITIGATED;
                        else if(ob.invalidated)
                            reason = EXPIRY_OB_INVALIDATED;
                        break;
                    }
                }
                if(!found)
                    reason = EXPIRY_OB_INVALIDATED;
            }
        }

        if(reason == EXPIRY_NONE && m_signals[sigIdx].hasLiquiditySweep && m_signals[sigIdx].liquidityLevelId >= 0)
        {
            if(m_liquidityDetector != NULL)
            {
                int levelCount = m_liquidityDetector.GetLevelCount();
                bool found = false;
                for(int j = 0; j < levelCount; j++)
                {
                    LiquidityLevel ll;
                    if(m_liquidityDetector.GetLevel(j, ll) && ll.id == m_signals[sigIdx].liquidityLevelId)
                    {
                        found = true;
                        if(ll.mitigated)
                            reason = EXPIRY_LIQUIDITY_MITIGATED;
                        else if(ll.invalidated)
                            reason = EXPIRY_LIQUIDITY_INVALIDATED;
                        break;
                    }
                }
                if(!found)
                    reason = EXPIRY_LIQUIDITY_INVALIDATED;
            }
        }

        if(reason == EXPIRY_NONE && m_trendState != NULL)
        {
            Trend current = m_trendState.GetCurrentTrend();
            if(m_signals[sigIdx].direction == CONFLUENCE_BULLISH && current == TREND_BEARISH)
                reason = EXPIRY_TREND_REVERSAL;
            else if(m_signals[sigIdx].direction == CONFLUENCE_BEARISH && current == TREND_BULLISH)
                reason = EXPIRY_TREND_REVERSAL;
        }

        if(reason != EXPIRY_NONE)
        {
            ExpireSignal(i, reason);
            m_totalSignalsExpired++;
        }
    }
}

void CConfluenceEngine::ExpireSignal(int index, ExpiryReason reason)
{
    if(index < 0 || index >= m_signalCount)
        return;

    m_signals[index].lifecycle = SIGNAL_EXPIRED;
    m_signals[index].expiryReason = reason;

    if(m_hasLatest && m_latestSignal.id == m_signals[index].id)
    {
        m_latestSignal.lifecycle = SIGNAL_EXPIRED;
        m_latestSignal.expiryReason = reason;
    }

    if(reason >= 0 && reason < EXPIRY_REASON_COUNT)
        m_expiryCounts[reason]++;

    m_logger.LogDebug(StringFormat("SIGNAL-EXPIRE #%d reason=%s",
                                    m_signals[index].id,
                                    reason == EXPIRY_FVG_FILLED ? "FVG_FILLED" :
                                    reason == EXPIRY_OB_MITIGATED ? "OB_MITIGATED" :
                                    reason == EXPIRY_OB_INVALIDATED ? "OB_INVALIDATED" :
                                    reason == EXPIRY_LIQUIDITY_MITIGATED ? "LIQUIDITY_MITIGATED" :
                                    reason == EXPIRY_LIQUIDITY_INVALIDATED ? "LIQUIDITY_INVALIDATED" :
                                    reason == EXPIRY_TREND_REVERSAL ? "TREND_REVERSAL" : "UNKNOWN"));
}

bool CConfluenceEngine::RegisterEvaluator(IConfluenceEvaluator *evaluator)
{
    if(evaluator == NULL) return false;
    int idx = m_evaluatorCount;
    ArrayResize(m_evaluators, idx + 1);
    m_evaluators[idx] = evaluator;
    m_evaluatorCount++;
    m_logger.LogDebug(StringFormat("Evaluator registered: %s", evaluator.GetName()));
    return true;
}

void CConfluenceEngine::SetWeights(const ConfluenceWeights &weights)
{
    m_weights = weights;
    m_scoreCalc.SetWeights(weights);
    m_logger.LogDebug(StringFormat("Confluence weights updated: %s", weights.ToString()));
}

bool CConfluenceEngine::GetLatestConfluence(ConfluenceResult &out) const
{
    if(!m_hasConfluence) return false;
    out = m_latestConfluence;
    return true;
}

void CConfluenceEngine::BuildDetectionContext(DetectionContext &context)
{
    context.trendState = m_trendState;
    context.bosDetector = m_bosDetector;
    context.chochDetector = m_chochDetector;
    context.orderBlockDetector = m_orderBlockDetector;
    context.fvgDetector = m_fvgDetector;
    context.protectedPointManager = m_protectedPointManager;
    context.liquidityDetector = m_liquidityDetector;
    context.currentPrice = iClose(_Symbol, _Period, 0);
    context.currentTime = iTime(_Symbol, _Period, 0);
}

bool CConfluenceEngine::EvaluateViaEvaluators(ConfluenceDirection dir, ConfluenceResult &result)
{
    if(m_evaluatorCount <= 0) return false;

    DetectionContext context;
    BuildDetectionContext(context);

    ConfluenceComponentResult components[MAX_CONFLUENCE_COMPONENTS];
    int compCount = 0;

    result.direction = dir;
    result.valid = false;

    for(int i = 0; i < m_evaluatorCount && compCount < MAX_CONFLUENCE_COMPONENTS; i++)
    {
        ConfluenceComponentResult cr;
        m_evaluators[i].Evaluate(context, cr);

        if(cr.score > 0.0)
        {
            components[compCount] = cr;
            compCount++;
        }
    }

    if(compCount > 0)
    {
        m_scoreCalc.Calculate(components, compCount, result);
    }

    return result.valid;
}

void CConfluenceEngine::BridgeConfluenceToSignal(const ConfluenceResult &cr,
                                                   RuleResult &bestRule,
                                                   ScoreLayer &score)
{
    bestRule.matched = cr.valid;
    bestRule.type = RULE_NONE;
    bestRule.score = (int)cr.totalConfidence;
    bestRule.confidence = cr.totalConfidence / 100.0;
    bestRule.direction = cr.direction;
    bestRule.evidenceCount = 0;
    bestRule.explanation = cr.summaryExplanation;
    bestRule.timestamp = TimeCurrent();

    for(int i = 0; i < cr.componentCount && i < MAX_EVIDENCE_IDS; i++)
    {
        bestRule.evidenceIds[i] = cr.components[i].type;
        bestRule.evidenceCount++;
    }

    score.structural = 0;
    score.liquidity = 0;
    score.confirmation = 0;
    score.total = (int)cr.totalConfidence;
    score.trendAligned = false;
    score.layerOrderBlock = 0;
    score.layerFVG = 0;

    for(int i = 0; i < cr.componentCount; i++)
    {
        ENUM_CONFLUENCE_COMPONENT t = cr.components[i].type;
        if(t == COMPONENT_STRUCTURE || t == COMPONENT_ORDER_BLOCK || t == COMPONENT_FVG)
            score.structural += (int)cr.components[i].contribution;
        else if(t == COMPONENT_LIQUIDITY)
            score.liquidity += (int)cr.components[i].contribution;
        else
            score.confirmation += (int)cr.components[i].contribution;
    }

    //--- Schema v3.1 (TC01): structural split by component (additive).
    for(int i = 0; i < cr.componentCount; i++)
    {
        ENUM_CONFLUENCE_COMPONENT t = cr.components[i].type;
        if(t == COMPONENT_ORDER_BLOCK)
            score.layerOrderBlock += (int)cr.components[i].contribution;
        else if(t == COMPONENT_FVG)
            score.layerFVG += (int)cr.components[i].contribution;
    }

    score.structural = fmin(score.structural, 50);
    score.liquidity = fmin(score.liquidity, 30);
    score.confirmation = fmin(score.confirmation, 20);
}

void CConfluenceEngine::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_executionPlanner.Shutdown();
    m_entryDecisionEngine.Shutdown();
    m_candidateBuilder.Shutdown();

    m_logger.LogInfo("========================= CONFLUENCE SUMMARY =========================");
    m_logger.LogInfo(StringFormat("Total Signals Created    : %d", m_totalSignalsCreated));
    m_logger.LogInfo(StringFormat("Total Signals Expired    : %d", m_totalSignalsExpired));
    m_logger.LogInfo(StringFormat("Active Signals Remaining : %d", m_signalCount - m_totalSignalsExpired));
    m_logger.LogInfo(StringFormat("Bullish Signals          : %d", m_bullishCount));
    m_logger.LogInfo(StringFormat("Bearish Signals          : %d", m_bearishCount));
    m_logger.LogInfo("");

    int ruleTypes[7] = {RULE_BOS_OB_BULLISH, RULE_BOS_OB_BEARISH,
                        RULE_OB_FVG_BULLISH, RULE_OB_FVG_BEARISH,
                        RULE_LIQUIDITY_BOS_BULLISH, RULE_LIQUIDITY_BOS_BEARISH,
                        RULE_CHOCH_OB_REVERSAL};
    string ruleNames[7] = {"BOS_OB_BULLISH", "BOS_OB_BEARISH",
                            "OB_FVG_BULLISH", "OB_FVG_BEARISH",
                            "LIQUIDITY_BOS_BULLISH", "LIQUIDITY_BOS_BEARISH",
                            "CHOCH_OB_REVERSAL"};

    m_logger.LogInfo("--- RULE MATCH / REJECT ---");
    for(int i = 0; i < 7; i++)
    {
        if(m_ruleMatchCounts[ruleTypes[i]] > 0 || m_ruleRejectCounts[ruleTypes[i]] > 0)
        {
            m_logger.LogInfo(StringFormat("  %-24s  Match=%5d  Reject=%5d",
                                           ruleNames[i],
                                           m_ruleMatchCounts[ruleTypes[i]],
                                           m_ruleRejectCounts[ruleTypes[i]]));
        }
    }
    m_logger.LogInfo("");

    m_logger.LogInfo("--- SIGNAL EXPIRY SUMMARY ---");
    m_logger.LogInfo(StringFormat("  %-24s %5d", "FVG Filled",           m_expiryCounts[EXPIRY_FVG_FILLED]));
    m_logger.LogInfo(StringFormat("  %-24s %5d", "OB Mitigated",         m_expiryCounts[EXPIRY_OB_MITIGATED]));
    m_logger.LogInfo(StringFormat("  %-24s %5d", "OB Invalidated",       m_expiryCounts[EXPIRY_OB_INVALIDATED]));
    m_logger.LogInfo(StringFormat("  %-24s %5d", "Liquidity Mitigated",  m_expiryCounts[EXPIRY_LIQUIDITY_MITIGATED]));
    m_logger.LogInfo(StringFormat("  %-24s %5d", "Liquidity Invalidated",m_expiryCounts[EXPIRY_LIQUIDITY_INVALIDATED]));
    m_logger.LogInfo(StringFormat("  %-24s %5d", "Trend Reversal",      m_expiryCounts[EXPIRY_TREND_REVERSAL]));
    m_logger.LogInfo("========================================================================");

    ArrayFree(m_signals);
    m_signalCount = 0;
    m_hasLatest = false;
    m_nextSignalId = 1;

    m_trendState            = NULL;
    m_bosDetector           = NULL;
    m_chochDetector         = NULL;
    m_orderBlockDetector    = NULL;
    m_fvgDetector           = NULL;
    m_protectedPointManager = NULL;
    m_liquidityDetector     = NULL;

    m_isInitialized = false;

    m_logger.LogInfo("ConfluenceEngine shutdown complete");
}

void CConfluenceEngine::SetTrendState(CTrendState *trendState)
{
    m_trendState = trendState;
    m_candidateBuilder.SetTrendState(trendState);
    m_entryDecisionEngine.SetTrendState(trendState);
}

void CConfluenceEngine::SetBOSDetector(CBOSDetector *bosDetector)
{
    m_bosDetector = bosDetector;
    m_candidateBuilder.SetBOSDetector(bosDetector);
    m_executionPlanner.SetBOSDetector(bosDetector);
}

void CConfluenceEngine::SetCHOCHDetector(CCHOCHDetector *chochDetector)
{
    m_chochDetector = chochDetector;
    m_candidateBuilder.SetCHOCHDetector(chochDetector);
}

void CConfluenceEngine::SetOrderBlockDetector(COrderBlockDetector *orderBlockDetector)
{
    m_orderBlockDetector = orderBlockDetector;
    m_candidateBuilder.SetOrderBlockDetector(orderBlockDetector);
    m_executionPlanner.SetOBDetector(orderBlockDetector);
}

void CConfluenceEngine::SetFVGDetector(CFVGDetector *fvgDetector)
{
    m_fvgDetector = fvgDetector;
    m_candidateBuilder.SetFVGDetector(fvgDetector);
    m_executionPlanner.SetFVGDetector(fvgDetector);
}

void CConfluenceEngine::SetProtectedPointManager(CProtectedPointManager *protectedPointManager)
{
    m_protectedPointManager = protectedPointManager;
    m_executionPlanner.SetProtectedPointManager(protectedPointManager);
}

void CConfluenceEngine::SetLiquidityDetector(CLiquidityDetector *liquidityDetector)
{
    m_liquidityDetector = liquidityDetector;
    m_candidateBuilder.SetLiquidityDetector(liquidityDetector);
    m_executionPlanner.SetLiquidityDetector(liquidityDetector);
}

bool CConfluenceEngine::GetSignal(int index, ConfluenceSignal &out) const
{
    if(index < 0 || index >= m_signalCount)
        return false;

    out = m_signals[index];
    return true;
}

bool CConfluenceEngine::GetLatestSignal(ConfluenceSignal &out) const
{
    if(!m_hasLatest)
        return false;

    out = m_latestSignal;
    return true;
}

#endif
