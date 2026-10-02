#ifndef __EXECUTION_PLANNER_MQH__
#define __EXECUTION_PLANNER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "../Confluence/SignalTypes.mqh"
#include "../Confluence/TradeCandidateBuilder.mqh"
#include "../Structure/OrderBlockDetector.mqh"
#include "../Structure/FVGDetector.mqh"
#include "../Structure/LiquidityDetector.mqh"
#include "../Structure/ProtectedPointManager.mqh"
#include "../Structure/BOSDetector.mqh"
#include "EntryDecisionEngine.mqh"
#include "ExecutionPlanTypes.mqh"
#include "EntryPriceResolver.mqh"
#include "StopLossResolver.mqh"
#include "TargetResolver.mqh"

struct PolicyComboResult
{
    ExecutionPlanConfig config;
    string              label;
    int                 total;
    int                 executable;
    int                 rejected;
    double              avgRR;
    double              avgStopPips;
    double              avgTargetPips;
    int                 rejectionDetails[9];
};

class CExecutionPlanner
{
private:
    bool                m_isInitialized;
    CLogger             m_logger;

    ExecutionPlanConfig m_config;
    ExecutionPlan       m_plans[];
    int                 m_planCount;

    COrderBlockDetector      *m_obDetector;
    CFVGDetector             *m_fvgDetector;
    CLiquidityDetector       *m_liqDetector;
    CProtectedPointManager   *m_ppManager;
    CBOSDetector             *m_bosDetector;

    CTradeCandidateBuilder   *m_candidateBuilder;
    CEntryDecisionEngine     *m_decisionEngine;

    int     m_totalCreated;
    int     m_totalExecutable;
    int     m_totalRejected;
    double  m_totalRR;
    double  m_totalStopDist;
    double  m_totalTargetDist;
    int     m_rejectionCounts[9];
    string  m_rejectionLabels[9];

    int     m_lastDecisionCount;
    double  m_point;

    void    BuildPlan(const TradeCandidate &candidate, const EntryDecision &decision);
    void    EvaluateSingleCombo(int idx, const ExecutionPlanConfig &cfg, const string &label,
                               CEntryDecisionEngine &decisionEngine, PolicyComboResult &result);
    void    EvaluatePolicyCombos(CEntryDecisionEngine &decisionEngine);

public:
    CExecutionPlanner(void);
    ~CExecutionPlanner(void);

    bool Init(void);
    void Update(CEntryDecisionEngine &decisionEngine, CTradeCandidateBuilder &candidateBuilder);
    void Shutdown(void);

    void SetConfig(const ExecutionPlanConfig &cfg);
    void SetCandidateBuilder(CTradeCandidateBuilder *cb);
    void SetOBDetector(COrderBlockDetector *ob);
    void SetFVGDetector(CFVGDetector *fvg);
    void SetLiquidityDetector(CLiquidityDetector *liq);
    void SetProtectedPointManager(CProtectedPointManager *pp);
    void SetBOSDetector(CBOSDetector *bos);

    int  GetPlanCount(void) const { return m_planCount; }
    bool GetPlan(int index, ExecutionPlan &out) const;
    bool SetPlanStatus(int index, ExecutionPlanStatus status);
};

CExecutionPlanner::CExecutionPlanner(void)
    : m_isInitialized(false)
    , m_logger(MODULE_EXECUTION_PLANNER, "ExecutionPlanner")
    , m_planCount(0)
    , m_obDetector(NULL)
    , m_fvgDetector(NULL)
    , m_liqDetector(NULL)
    , m_ppManager(NULL)
    , m_bosDetector(NULL)
    , m_candidateBuilder(NULL)
    , m_decisionEngine(NULL)
    , m_totalCreated(0)
    , m_totalExecutable(0)
    , m_totalRejected(0)
    , m_totalRR(0.0)
    , m_totalStopDist(0.0)
    , m_totalTargetDist(0.0)
    , m_lastDecisionCount(0)
    , m_point(0.0)
{
    for(int i = 0; i < 9; i++)
    {
        m_rejectionCounts[i] = 0;
        m_rejectionLabels[i] = "";
    }
    m_rejectionLabels[0] = "Stop Distance";
    m_rejectionLabels[1] = "Target Distance";
    m_rejectionLabels[2] = "Broker Min Stop";
    m_rejectionLabels[3] = "Spread";
    m_rejectionLabels[4] = "Invalid Prices";
    m_rejectionLabels[5] = "RR Below Minimum";
    m_rejectionLabels[6] = "Stop Too Close";
    m_rejectionLabels[7] = "Target Too Close";
    m_rejectionLabels[8] = "Unresolved Entry";
}

CExecutionPlanner::~CExecutionPlanner(void)
{
    Shutdown();
}

bool CExecutionPlanner::Init(void)
{
    if(m_isInitialized)
    {
        m_logger.LogWarn("ExecutionPlanner already initialized");
        return true;
    }

    m_planCount = 0;
    m_totalCreated = 0;
    m_totalExecutable = 0;
    m_totalRejected = 0;
    m_totalRR = 0.0;
    m_totalStopDist = 0.0;
    m_totalTargetDist = 0.0;
    m_lastDecisionCount = 0;

    m_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(m_point <= 0)
        m_point = 0.00001;

    m_isInitialized = true;
    m_logger.LogInfo("ExecutionPlanner initialized");
    return true;
}

void CExecutionPlanner::SetConfig(const ExecutionPlanConfig &cfg)
{
    m_config = cfg;
}

void CExecutionPlanner::SetOBDetector(COrderBlockDetector *ob) { m_obDetector = ob; }
void CExecutionPlanner::SetFVGDetector(CFVGDetector *fvg) { m_fvgDetector = fvg; }
void CExecutionPlanner::SetLiquidityDetector(CLiquidityDetector *liq) { m_liqDetector = liq; }
void CExecutionPlanner::SetProtectedPointManager(CProtectedPointManager *pp) { m_ppManager = pp; }
void CExecutionPlanner::SetBOSDetector(CBOSDetector *bos) { m_bosDetector = bos; }
void CExecutionPlanner::SetCandidateBuilder(CTradeCandidateBuilder *cb) { m_candidateBuilder = cb; }

void CExecutionPlanner::Update(CEntryDecisionEngine &decisionEngine, CTradeCandidateBuilder &candidateBuilder)
{
    if(!m_isInitialized)
    {
        m_logger.LogWarn("Update called but ExecutionPlanner is not initialized");
        return;
    }

    m_candidateBuilder = &candidateBuilder;
    m_decisionEngine = &decisionEngine;

    int decisionCount = decisionEngine.GetDecisionCount();
    if(decisionCount <= m_lastDecisionCount)
        return;

    for(int d = m_lastDecisionCount; d < decisionCount; d++)
    {
        EntryDecision decision;
        if(!decisionEngine.GetDecision(d, decision))
            continue;

        if(decision.status != DECISION_QUALIFIED)
            continue;

        TradeCandidate candidate;
        bool found = false;
        int candidateCount = candidateBuilder.GetCandidateCount();
        for(int c = 0; c < candidateCount; c++)
        {
            if(candidateBuilder.GetCandidate(c, candidate) && candidate.id == decision.candidateId)
            {
                found = true;
                break;
            }
        }
        if(!found)
            continue;

        BuildPlan(candidate, decision);
    }

    m_lastDecisionCount = decisionCount;
}

void CExecutionPlanner::BuildPlan(const TradeCandidate &candidate, const EntryDecision &decision)
{
    ExecutionPlan plan;
    plan.entryDecisionId = decision.candidateId;
    plan.direction = candidate.direction;
    plan.status = PLAN_CREATED;
    plan.createdTime = TimeCurrent();

    if(candidate.direction == CONFLUENCE_BULLISH)
        plan.orderType = ORDER_TYPE_BUY;
    else if(candidate.direction == CONFLUENCE_BEARISH)
        plan.orderType = ORDER_TYPE_SELL;
    else
    {
        plan.status = PLAN_REJECTED;
        plan.rejectionReason = "Unknown direction";
        m_totalRejected++;
        plan.entryPrice = 0; plan.stopLoss = 0; plan.takeProfit = 0;
        plan.riskReward = 0; plan.stopDistance = 0; plan.targetDistance = 0;
        plan.riskRewardNet = 0; plan.hasNetRiskReward = false;
        plan.belowNetRRThreshold = false;
        m_totalCreated++;
        int idx = m_planCount;
        ArrayResize(m_plans, idx + 1);
        m_plans[idx] = plan;
        m_planCount++;
        m_logger.LogInfo(StringFormat("EXECUTION-PLAN Decision=%d Status=REJECTED Reason=Unknown direction", decision.candidateId));
        return;
    }

    bool entrySR = false, stopSR = false, targetSR = false;

    //--- Rule 5/6 (LIQUIDITY_BOS) candidates carry hasLiquidity with
    //    hasOB=false. The ENTRY_OB_RETEST resolver guard requires hasOB,
    //    so such plans could never resolve structurally (entrySR=false ->
    //    Current Price -> "Unresolved Entry" rejection).
    //    Scope: candidates with no OB at all. RULE_OB_FVG_* is the only
    //    producer of hasFVG and always produces hasOB
    //    (TradeCandidateBuilder.mqh:119-124), so every hasOB family —
    //    including Rule 3/4 OB_FVG — is untouched.
    ENUM_ENTRY_POLICY entryPolicy = m_config.entryPolicy;
    if(!candidate.hasOB && candidate.hasLiquidity && candidate.liquidityId >= 0)
        entryPolicy = ENTRY_LIQUIDITY_LEVEL;

    {
        double price = 0;
        string policyName = "";
        ResolveEntryPrice(candidate, entryPolicy, m_obDetector, m_fvgDetector, m_liqDetector, price, policyName, entrySR);
        plan.entryPrice = price;
        plan.entryPolicyUsed = policyName;
    }

    {
        double sl = 0;
        string policyName = "";
        ResolveStopLoss(candidate, m_config.stopPolicy, plan.entryPrice,
                        m_config.stopBufferPips, m_config.minStopDistancePips,
                        m_obDetector, m_liqDetector, m_ppManager,
                        sl, policyName, stopSR);
        plan.stopLoss = sl;
        plan.stopPolicyUsed = policyName;
    }

    {
        double tp = 0;
        string policyName = "";
        ResolveTakeProfit(candidate, m_config.targetPolicy, plan.entryPrice, plan.stopLoss,
                          m_config.targetRR, m_obDetector, m_fvgDetector,
                          m_liqDetector, m_bosDetector,
                          tp, policyName, targetSR);
        plan.takeProfit = tp;
        plan.targetPolicyUsed = policyName;
    }

    //--- C1 (plan identity): persist the resolution policies (enum) and the
    //    structure-resolved flag for durable cross-run plan identity.
    //--- Provenance: record the policy actually used to resolve the entry,
    //    not the config default — this enum is part of the durable plan
    //    identity persisted in the INTENT payload.
    plan.entryPolicy = entryPolicy;
    plan.stopPolicy = m_config.stopPolicy;
    plan.targetPolicy = m_config.targetPolicy;
    plan.structureResolved = (entrySR && stopSR && targetSR);

    plan.stopDistance = MathAbs(plan.entryPrice - plan.stopLoss);
    plan.targetDistance = MathAbs(plan.takeProfit - plan.entryPrice);
    if(plan.stopDistance > 0)
        plan.riskReward = plan.targetDistance / plan.stopDistance;
    else
        plan.riskReward = 0;
    //--- P44 (evidence, observe-only): spread-only net-RR per P43 §1.
    //    hasNetRiskReward=true signals computed. Gate below STILL uses gross
    //    riskReward — no rejection, no threshold. Symmetric round-trip spread
    //    convention; volume-free R-units; commission/swap excluded (P40).
    plan.hasNetRiskReward = false;
    plan.riskRewardNet = plan.riskReward;
    plan.belowNetRRThreshold = false;
    {
        double spreadDistObs = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * m_point;
        double netDenObs = plan.stopDistance + spreadDistObs;
        if(plan.stopDistance > 0 && netDenObs > 0)
        {
            plan.riskRewardNet = (plan.targetDistance - spreadDistObs) / netDenObs;
            plan.hasNetRiskReward = true;
            //--- P46 decision: observe threshold 1.0R (senior-advisor selection
            //    on P45 evidence; lowest-blast-radius semantic candidate, NOT a
            //    tuned optimum). Strict < : exact comparison needs no epsilon;
            //    inventing one is prohibited. Informational only — gate below
            //    still uses gross riskReward. Rejection NOT authorized.
            const double netRR_ObserveThreshold = 1.0;
            plan.belowNetRRThreshold = (plan.riskRewardNet < netRR_ObserveThreshold);
        }
    }

    {
        double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * m_point;
        double minStopDist = PipToPriceDistance(m_config.minStopDistancePips, m_point);
        bool valid = true;
        string rejectReason = "";

        if(plan.entryPrice <= 0 || plan.stopLoss <= 0 || plan.takeProfit <= 0)
        {
            valid = false;
            rejectReason = "Invalid Prices";
            m_rejectionCounts[4]++;
        }
        //--- C6 (integrity): the stop and target must bracket the entry in
        //    the trade's direction.  Inverted combos (BUY with SL above
        //    entry, SELL with TP above entry, ...) previously passed the
        //    MathAbs distance checks and reached the broker as garbage.
        else if((plan.orderType == ORDER_TYPE_BUY &&
                 (plan.stopLoss >= plan.entryPrice || plan.takeProfit <= plan.entryPrice)) ||
                (plan.orderType == ORDER_TYPE_SELL &&
                 (plan.stopLoss <= plan.entryPrice || plan.takeProfit >= plan.entryPrice)))
        {
            valid = false;
            rejectReason = "Invalid Prices";
            m_rejectionCounts[4]++;
        }
        //--- B25-03C-E (integrity): an unresolved entry has no durable plan
        //    identity.  Reject at plan creation rather than presenting as
        //    EXECUTABLE and blocking at the inspection gate.
        else if(!entrySR)
        {
            valid = false;
            rejectReason = "Unresolved Entry";
            m_rejectionCounts[8]++;
        }
        else if(plan.stopDistance < spread * 2)
        {
            valid = false;
            rejectReason = "Stop Too Close";
            m_rejectionCounts[6]++;
        }
        else if(plan.stopDistance < minStopDist)
        {
            valid = false;
            rejectReason = "Broker Min Stop";
            m_rejectionCounts[2]++;
        }
        else if(plan.targetDistance < spread)
        {
            valid = false;
            rejectReason = "Target Too Close";
            m_rejectionCounts[7]++;
        }
        else if(plan.riskReward < 1.0)
        {
            valid = false;
            rejectReason = "RR Below Minimum";
            m_rejectionCounts[5]++;
        }
        //--- P48 (authorized risk guard): spread-only NetRR < 1.0 rejects AFTER
        //    the retained gross clause above. Bucket 5 reused (RR family; no
        //    schema/label change); per-plan reason distinguishes. Strict <
        //    on numerics, no epsilon. Execution-risk guard, NOT a
        //    profitability filter. BE/TS/caps/params untouched.
        else if(plan.hasNetRiskReward && plan.belowNetRRThreshold)
        {
            valid = false;
            rejectReason = "NetRR Below Minimum";
            m_rejectionCounts[5]++;
        }

        if(valid)
        {
            plan.status = PLAN_EXECUTABLE;
            m_totalExecutable++;
        }
        else
        {
            plan.status = PLAN_REJECTED;
            plan.rejectionReason = rejectReason;
            m_totalRejected++;
        }
    }

    m_totalCreated++;
    if(plan.status == PLAN_EXECUTABLE)
    {
        m_totalRR += plan.riskReward;
        m_totalStopDist += plan.stopDistance;
        m_totalTargetDist += plan.targetDistance;
    }

    {
        int idx = m_planCount;
        ArrayResize(m_plans, idx + 1);
        m_plans[idx] = plan;
        m_planCount++;
    }

    {
        string statusStr = (plan.status == PLAN_EXECUTABLE ? "EXECUTABLE" :
                           plan.status == PLAN_REJECTED ? "REJECTED" : "CREATED");
        //--- P46 precision: NetRR at 4 decimals (P44 %.2f blurred borders);
        //    Below10 logged from the numeric flag, not the formatted string.
        m_logger.LogInfo(StringFormat("EXECUTION-PLAN Decision=%d Status=%s Entry=%.5f SL=%.5f TP=%.5f RR=%.2f NetRR=%.4f Below10=%d StopPolicy=%s TargetPolicy=%s%s",
                                       decision.candidateId, statusStr,
                                       plan.entryPrice, plan.stopLoss, plan.takeProfit, plan.riskReward, plan.riskRewardNet, (plan.belowNetRRThreshold ? 1 : 0),
                                       plan.stopPolicyUsed, plan.targetPolicyUsed,
                                       (plan.status == PLAN_REJECTED ? StringFormat(" Reason=%s", plan.rejectionReason) : "")));

        //--- P54 Stage-1 (MEASUREMENT ONLY - additive, read-only, no behaviour
        //    change).  One structured record per plan at BuildPlan completion,
        //    keyed by planId, so the S1-S8 funnel can be reconstructed from
        //    DISTINCT PLAN IDS rather than from aggregate counters.
        //
        //    Records the ACTUAL resolver out-parameters entrySR / stopSR /
        //    targetSR (ExecutionPlanner.mqh:259/:270/:278).  It deliberately
        //    does NOT use the resolver return values: ResolveEntryPrice and
        //    ResolveStopLoss both return true on their non-structural
        //    fallbacks (EntryPriceResolver.mqh:71-73, StopLossResolver.mqh:105-110),
        //    so keying on the return value would report structural resolution
        //    for fallback-priced plans.  targetSR is recorded as an observed
        //    field rather than assumed, even though TargetResolver.mqh:35
        //    establishes it as currently constant true.
        //
        //    The protected-point getters below are const side-effect-free reads
        //    (ProtectedPointManager.mqh:273/:282) used only to explain stopSR;
        //    NO resolver logic is duplicated and no resolver output is altered.
        int    ppMgrPresent = (m_ppManager != NULL) ? 1 : 0;
        int    ppLowActive  = 0;
        int    ppHighActive = 0;
        double ppPrice      = 0.0;
        ProtectedPoint ppObs;
        if(m_ppManager != NULL)
        {
            ppLowActive  = m_ppManager.GetActiveLow(ppObs)  ? 1 : 0;
            ppHighActive = m_ppManager.GetActiveHigh(ppObs) ? 1 : 0;
            if(candidate.direction == CONFLUENCE_BULLISH && ppLowActive == 1)
                ppPrice = ppObs.price;
            else if(candidate.direction == CONFLUENCE_BEARISH && ppHighActive == 1)
                ppPrice = ppObs.price;
        }

        m_logger.LogInfo(StringFormat(
            "S-PLAN Plan=%d Cand=%d Dir=%d Rules=%d Rule0=%d Sym=%s TF=%s "
            "OB=%d/%d FVG=%d/%d LIQ=%d/%d "
            "EP=%d(%s) SP=%d TP=%d "
            "entrySR=%d stopSR=%d targetSR=%d structureResolved=%d "
            "E=%.8f SL=%.8f TP=%.8f Status=%s "
            "PP=%d PPLow=%d PPHigh=%d PPPrice=%.8f",
            plan.entryDecisionId,
            candidate.id, (int)candidate.direction,
            candidate.ruleCount, (candidate.ruleCount > 0 ? (int)candidate.matchedRules[0] : -1),
            _Symbol, EnumToString(_Period),
            (candidate.hasOB ? 1 : 0), candidate.obId,
            (candidate.hasFVG ? 1 : 0), candidate.fvgId,
            (candidate.hasLiquidity ? 1 : 0), candidate.liquidityId,
            (int)plan.entryPolicy, plan.entryPolicyUsed,
            (int)plan.stopPolicy, (int)plan.targetPolicy,
            (entrySR ? 1 : 0), (stopSR ? 1 : 0), (targetSR ? 1 : 0),
            (plan.structureResolved ? 1 : 0),
            plan.entryPrice, plan.stopLoss, plan.takeProfit, statusStr,
            ppMgrPresent, ppLowActive, ppHighActive, ppPrice));
    }
}

void CExecutionPlanner::EvaluateSingleCombo(int idx, const ExecutionPlanConfig &cfg, const string &label,
                                            CEntryDecisionEngine &decisionEngine, PolicyComboResult &result)
{
    result.config = cfg;
    result.label = label;
    result.total = 0;
    result.executable = 0;
    result.rejected = 0;
    result.avgRR = 0;
    result.avgStopPips = 0;
    result.avgTargetPips = 0;
    for(int i = 0; i < 9; i++)
        result.rejectionDetails[i] = 0;

    if(m_candidateBuilder == NULL)
        return;

    int decisionCount = decisionEngine.GetDecisionCount();
    for(int d = 0; d < decisionCount; d++)
    {
        EntryDecision decision;
        if(!decisionEngine.GetDecision(d, decision))
            continue;
        if(decision.status != DECISION_QUALIFIED)
            continue;

        TradeCandidate candidate;
        bool found = false;
        int candidateCount = m_candidateBuilder.GetCandidateCount();
        for(int c = 0; c < candidateCount; c++)
        {
            if(m_candidateBuilder.GetCandidate(c, candidate) && candidate.id == decision.candidateId)
            {
                found = true;
                break;
            }
        }
        if(!found)
            continue;

        double entryPrice = 0, stopLoss = 0, takeProfit = 0;
        string entryPol = "", stopPol = "", targetPol = "";
        bool eSR = false, sSR = false, tSR = false;

        ResolveEntryPrice(candidate, cfg.entryPolicy, m_obDetector, m_fvgDetector, m_liqDetector, entryPrice, entryPol, eSR);
        ResolveStopLoss(candidate, cfg.stopPolicy, entryPrice,
                        cfg.stopBufferPips, cfg.minStopDistancePips,
                        m_obDetector, m_liqDetector, m_ppManager,
                        stopLoss, stopPol, sSR);
        ResolveTakeProfit(candidate, cfg.targetPolicy, entryPrice, stopLoss,
                          cfg.targetRR, m_obDetector, m_fvgDetector,
                          m_liqDetector, m_bosDetector,
                          takeProfit, targetPol, tSR);

        double stopDist = MathAbs(entryPrice - stopLoss);
        double targetDist = MathAbs(takeProfit - entryPrice);
        double rr = (stopDist > 0) ? (targetDist / stopDist) : 0;

        result.total++;
        double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * m_point;
        double minStopDist = PipToPriceDistance(cfg.minStopDistancePips, m_point);
        bool valid = true;

        //--- C6 (integrity): directional bracket check, mirror of BuildPlan.
        ENUM_ORDER_TYPE ot = (candidate.direction == CONFLUENCE_BULLISH) ?
                             ORDER_TYPE_BUY : ORDER_TYPE_SELL;

        if(entryPrice <= 0 || stopLoss <= 0 || takeProfit <= 0)
        {
            result.rejected++;
            result.rejectionDetails[4]++;
        }
        else if((ot == ORDER_TYPE_BUY && (stopLoss >= entryPrice || takeProfit <= entryPrice)) ||
                (ot == ORDER_TYPE_SELL && (stopLoss <= entryPrice || takeProfit >= entryPrice)))
        {
            result.rejected++;
            result.rejectionDetails[4]++;
        }
        else if(!eSR)
        {
            result.rejected++;
            result.rejectionDetails[8]++;
        }
        else if(stopDist < spread * 2)
        {
            result.rejected++;
            result.rejectionDetails[6]++;
        }
        else if(stopDist < minStopDist)
        {
            result.rejected++;
            result.rejectionDetails[2]++;
        }
        else if(targetDist < spread)
        {
            result.rejected++;
            result.rejectionDetails[7]++;
        }
        else if(rr < 1.0)
        {
            result.rejected++;
            result.rejectionDetails[5]++;
        }
        else
        {
            result.executable++;
            result.avgRR += rr;
            result.avgStopPips += stopDist;
            result.avgTargetPips += targetDist;
        }
    }

    if(result.executable > 0)
    {
        result.avgRR /= result.executable;
        result.avgStopPips = result.avgStopPips / result.executable / m_point / 10.0;
        result.avgTargetPips = result.avgTargetPips / result.executable / m_point / 10.0;
    }
}

void CExecutionPlanner::EvaluatePolicyCombos(CEntryDecisionEngine &decisionEngine)
{
    m_logger.LogInfo("");
    m_logger.LogInfo("==================== POLICY MATRIX EVALUATION ====================");

    PolicyComboResult results[20];
    int comboCount = 0;

    ExecutionPlanConfig base;
    base.entryPolicy = ENTRY_OB_RETEST;
    base.stopPolicy = STOP_PROTECTED_POINT;
    base.targetPolicy = TARGET_FIXED_RR;
    base.targetRR = 2.0;
    base.stopBufferPips = 3.0;
    base.minStopDistancePips = 10.0;

    ExecutionPlanConfig cfg;

    cfg = base; cfg.entryPolicy = ENTRY_OB_RETEST;
    EvaluateSingleCombo(comboCount, cfg, "Entry: OB Retest", decisionEngine, results[comboCount++]);

    cfg = base; cfg.entryPolicy = ENTRY_FVG_MIDPOINT;
    EvaluateSingleCombo(comboCount, cfg, "Entry: FVG Midpoint", decisionEngine, results[comboCount++]);

    cfg = base; cfg.entryPolicy = ENTRY_LIQUIDITY_LEVEL;
    EvaluateSingleCombo(comboCount, cfg, "Entry: Liquidity Level", decisionEngine, results[comboCount++]);

    cfg = base; cfg.entryPolicy = ENTRY_CURRENT_PRICE;
    EvaluateSingleCombo(comboCount, cfg, "Entry: Current Price", decisionEngine, results[comboCount++]);

    cfg = base; cfg.entryPolicy = ENTRY_OB_RETEST; cfg.stopPolicy = STOP_OB_SIDE;
    EvaluateSingleCombo(comboCount, cfg, "Stop: OB Side", decisionEngine, results[comboCount++]);

    cfg = base; cfg.entryPolicy = ENTRY_OB_RETEST; cfg.stopPolicy = STOP_LIQUIDITY_SIDE;
    EvaluateSingleCombo(comboCount, cfg, "Stop: Liquidity Side", decisionEngine, results[comboCount++]);

    cfg = base; cfg.entryPolicy = ENTRY_OB_RETEST; cfg.stopPolicy = STOP_PROTECTED_POINT;
    EvaluateSingleCombo(comboCount, cfg, "Stop: Protected Point", decisionEngine, results[comboCount++]);

    cfg = base; cfg.entryPolicy = ENTRY_OB_RETEST; cfg.stopPolicy = STOP_BROKER_MINIMUM;
    EvaluateSingleCombo(comboCount, cfg, "Stop: Broker Minimum", decisionEngine, results[comboCount++]);

    cfg = base; cfg.entryPolicy = ENTRY_OB_RETEST; cfg.stopPolicy = STOP_PROTECTED_POINT; cfg.targetPolicy = TARGET_OPPOSING_LIQUIDITY;
    EvaluateSingleCombo(comboCount, cfg, "Target: Opposing Liq", decisionEngine, results[comboCount++]);

    cfg = base; cfg.entryPolicy = ENTRY_OB_RETEST; cfg.stopPolicy = STOP_PROTECTED_POINT; cfg.targetPolicy = TARGET_OPPOSING_OB;
    EvaluateSingleCombo(comboCount, cfg, "Target: Opposing OB", decisionEngine, results[comboCount++]);

    cfg = base; cfg.entryPolicy = ENTRY_OB_RETEST; cfg.stopPolicy = STOP_PROTECTED_POINT; cfg.targetPolicy = TARGET_OPPOSING_FVG;
    EvaluateSingleCombo(comboCount, cfg, "Target: Opposing FVG", decisionEngine, results[comboCount++]);

    cfg = base; cfg.entryPolicy = ENTRY_OB_RETEST; cfg.stopPolicy = STOP_PROTECTED_POINT; cfg.targetPolicy = TARGET_FIXED_RR; cfg.targetRR = 2.0;
    EvaluateSingleCombo(comboCount, cfg, "Target: Fixed RR 2.0", decisionEngine, results[comboCount++]);

    cfg = base; cfg.entryPolicy = ENTRY_OB_RETEST; cfg.stopPolicy = STOP_PROTECTED_POINT; cfg.targetPolicy = TARGET_PREVIOUS_SWING;
    EvaluateSingleCombo(comboCount, cfg, "Target: Prev Swing", decisionEngine, results[comboCount++]);

    {   double bufs[3]; bufs[0] = 1.0; bufs[1] = 3.0; bufs[2] = 5.0;
        for(int b = 0; b < 3 && comboCount < 20; b++)
        {
            cfg = base; cfg.entryPolicy = ENTRY_OB_RETEST; cfg.stopPolicy = STOP_PROTECTED_POINT; cfg.targetPolicy = TARGET_FIXED_RR; cfg.targetRR = 2.0;
            cfg.stopBufferPips = bufs[b];
            cfg.minStopDistancePips = 10.0;
            EvaluateSingleCombo(comboCount, cfg, StringFormat("Buf: %.0f pip%s", bufs[b], (bufs[b] == 1.0 ? "" : "s")), decisionEngine, results[comboCount++]);
        }
    }

    {   double mins[3]; mins[0] = 5.0; mins[1] = 10.0; mins[2] = 20.0;
        for(int m = 0; m < 3 && comboCount < 20; m++)
        {
            cfg = base; cfg.entryPolicy = ENTRY_OB_RETEST; cfg.stopPolicy = STOP_PROTECTED_POINT; cfg.targetPolicy = TARGET_FIXED_RR; cfg.targetRR = 2.0;
            cfg.stopBufferPips = 3.0;
            cfg.minStopDistancePips = mins[m];
            EvaluateSingleCombo(comboCount, cfg, StringFormat("MinStop: %.0f pips", mins[m]), decisionEngine, results[comboCount++]);
        }
    }

    m_logger.LogInfo("");  m_logger.LogInfo(StringFormat("%-24s %6s %6s %6s  %8s  %8s  %8s   %s",
        "COMBO", "TOTAL", "EXEC", "REJ", "AvgRR", "StopPip", "TgtPip", "RejDetail"));
    m_logger.LogInfo(StringFormat("%-24s %6s %6s %6s  %8s  %8s  %8s   %s",
        "------", "-----", "----", "---", "-----", "-------", "-------", "---------"));

    for(int i = 0; i < comboCount; i++)
    {
        string detail = "";
        for(int k = 0; k < 9; k++)
        {
            if(results[i].rejectionDetails[k] > 0)
            {
                if(detail != "") detail += " ";
                detail += StringFormat("%s=%d", m_rejectionLabels[k], results[i].rejectionDetails[k]);
            }
        }
        double execPct = (results[i].total > 0) ? (100.0 * results[i].executable / results[i].total) : 0;
        m_logger.LogInfo(StringFormat("%-24s %6d %6d %5d(%4.0f%%)  %6.2f  %6.1f  %6.1f   %s",
            results[i].label, results[i].total, results[i].executable, results[i].rejected, execPct,
            results[i].avgRR, results[i].avgStopPips, results[i].avgTargetPips, detail));
    }

    m_logger.LogInfo("====================================================================");
}

void CExecutionPlanner::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    if(m_decisionEngine != NULL)
        EvaluatePolicyCombos(*m_decisionEngine);

    m_logger.LogInfo("========================== EXECUTION PLAN SUMMARY =========================");
    m_logger.LogInfo(StringFormat("  %-35s %5d", "Plans Created",             m_totalCreated));
    m_logger.LogInfo(StringFormat("  %-35s %5d", "Executable",               m_totalExecutable));
    m_logger.LogInfo(StringFormat("  %-35s %5d", "Rejected",                 m_totalRejected));
    if(m_totalExecutable > 0)
    {
        m_logger.LogInfo(StringFormat("  %-35s %.2f",  "Avg RR",                 m_totalRR / m_totalExecutable));
        m_logger.LogInfo(StringFormat("  %-35s %.1f",  "Avg Stop (pips)",        m_totalStopDist / m_totalExecutable / m_point / 10.0));
        m_logger.LogInfo(StringFormat("  %-35s %.1f",  "Avg Target (pips)",      m_totalTargetDist / m_totalExecutable / m_point / 10.0));
    }
    m_logger.LogInfo("");
    m_logger.LogInfo("--- REJECTION BREAKDOWN ---");
    for(int i = 0; i < 9; i++)
    {
        if(m_rejectionCounts[i] > 0)
            m_logger.LogInfo(StringFormat("  %-25s %5d", m_rejectionLabels[i], m_rejectionCounts[i]));
    }
    m_logger.LogInfo("========================================================================");

    ArrayFree(m_plans);
    m_planCount = 0;
    m_decisionEngine = NULL;
    m_candidateBuilder = NULL;
    m_isInitialized = false;
    m_logger.LogInfo("ExecutionPlanner shutdown complete");
}

bool CExecutionPlanner::GetPlan(int index, ExecutionPlan &out) const
{
    if(index < 0 || index >= m_planCount)
        return false;
    out = m_plans[index];
    return true;
}

bool CExecutionPlanner::SetPlanStatus(int index, ExecutionPlanStatus status)
{
    if(index < 0 || index >= m_planCount)
        return false;
    m_plans[index].status = status;
    return true;
}

#endif
