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

    int     m_totalCreated;
    int     m_totalExecutable;
    int     m_totalRejected;
    double  m_totalRR;
    double  m_totalStopDist;
    double  m_totalTargetDist;
    int     m_rejectionCounts[8];
    string  m_rejectionLabels[8];

    int     m_lastDecisionCount;
    double  m_point;

    void    BuildPlan(const TradeCandidate &candidate, const EntryDecision &decision);

public:
    CExecutionPlanner(void);
    ~CExecutionPlanner(void);

    bool Init(void);
    void Update(CEntryDecisionEngine &decisionEngine, CTradeCandidateBuilder &candidateBuilder);
    void Shutdown(void);

    void SetConfig(const ExecutionPlanConfig &cfg);
    void SetOBDetector(COrderBlockDetector *ob);
    void SetFVGDetector(CFVGDetector *fvg);
    void SetLiquidityDetector(CLiquidityDetector *liq);
    void SetProtectedPointManager(CProtectedPointManager *pp);
    void SetBOSDetector(CBOSDetector *bos);

    int  GetPlanCount(void) const { return m_planCount; }
    bool GetPlan(int index, ExecutionPlan &out) const;
};

CExecutionPlanner::CExecutionPlanner(void)
    : m_isInitialized(false)
    , m_logger(MODULE_CONFLUENCE_ENGINE, "ExecutionPlanner")
    , m_planCount(0)
    , m_obDetector(NULL)
    , m_fvgDetector(NULL)
    , m_liqDetector(NULL)
    , m_ppManager(NULL)
    , m_bosDetector(NULL)
    , m_totalCreated(0)
    , m_totalExecutable(0)
    , m_totalRejected(0)
    , m_totalRR(0.0)
    , m_totalStopDist(0.0)
    , m_totalTargetDist(0.0)
    , m_lastDecisionCount(0)
    , m_point(0.0)
{
    for(int i = 0; i < 8; i++)
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

void CExecutionPlanner::Update(CEntryDecisionEngine &decisionEngine, CTradeCandidateBuilder &candidateBuilder)
{
    if(!m_isInitialized)
    {
        m_logger.LogWarn("Update called but ExecutionPlanner is not initialized");
        return;
    }

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
        plan.entryPolicyUsed = ""; plan.stopPolicyUsed = ""; plan.targetPolicyUsed = "";
        m_totalCreated++;
        int idx = m_planCount;
        ArrayResize(m_plans, idx + 1);
        m_plans[idx] = plan;
        m_planCount++;
        m_logger.LogInfo(StringFormat("EXECUTION-PLAN Decision=%d Status=REJECTED Reason=Unknown direction", decision.candidateId));
        return;
    }

    {
        double price = 0;
        string policyName = "";
        ResolveEntryPrice(candidate, m_config.entryPolicy, m_obDetector, m_fvgDetector, m_liqDetector, price, policyName);
        plan.entryPrice = price;
        plan.entryPolicyUsed = policyName;
    }

    {
        double sl = 0;
        string policyName = "";
        ResolveStopLoss(candidate, m_config.stopPolicy, plan.entryPrice,
                        m_config.stopBufferPips, m_config.minStopDistancePips,
                        m_obDetector, m_liqDetector, m_ppManager,
                        sl, policyName);
        plan.stopLoss = sl;
        plan.stopPolicyUsed = policyName;
    }

    {
        double tp = 0;
        string policyName = "";
        ResolveTakeProfit(candidate, m_config.targetPolicy, plan.entryPrice, plan.stopLoss,
                          m_config.targetRR, m_obDetector, m_fvgDetector,
                          m_liqDetector, m_bosDetector,
                          tp, policyName);
        plan.takeProfit = tp;
        plan.targetPolicyUsed = policyName;
    }

    plan.stopDistance = MathAbs(plan.entryPrice - plan.stopLoss);
    plan.targetDistance = MathAbs(plan.takeProfit - plan.entryPrice);

    if(plan.stopDistance > 0)
        plan.riskReward = plan.targetDistance / plan.stopDistance;
    else
        plan.riskReward = 0;

    {
        double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * m_point;
        double minStopDist = m_config.minStopDistancePips * 10.0 * m_point;
        bool valid = true;
        string rejectReason = "";

        if(plan.entryPrice <= 0 || plan.stopLoss <= 0 || plan.takeProfit <= 0)
        {
            valid = false;
            rejectReason = "Invalid Prices";
            m_rejectionCounts[4]++;
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
        m_logger.LogInfo(StringFormat("EXECUTION-PLAN Decision=%d Status=%s Entry=%.5f SL=%.5f TP=%.5f RR=%.2f StopPolicy=%s TargetPolicy=%s%s",
                                       decision.candidateId, statusStr,
                                       plan.entryPrice, plan.stopLoss, plan.takeProfit, plan.riskReward,
                                       plan.stopPolicyUsed, plan.targetPolicyUsed,
                                       (plan.status == PLAN_REJECTED ? StringFormat(" Reason=%s", plan.rejectionReason) : "")));
    }
}

void CExecutionPlanner::Shutdown(void)
{
    if(!m_isInitialized)
        return;

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
    for(int i = 0; i < 8; i++)
    {
        if(m_rejectionCounts[i] > 0)
            m_logger.LogInfo(StringFormat("  %-25s %5d", m_rejectionLabels[i], m_rejectionCounts[i]));
    }
    m_logger.LogInfo("========================================================================");

    ArrayFree(m_plans);
    m_planCount = 0;
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

#endif
