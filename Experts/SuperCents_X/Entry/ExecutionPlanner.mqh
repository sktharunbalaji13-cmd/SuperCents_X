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
    int                 rejectionDetails[8];
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
    int     m_rejectionCounts[8];
    string  m_rejectionLabels[8];

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
    for(int i = 0; i < 8; i++)
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

        ResolveEntryPrice(candidate, cfg.entryPolicy, m_obDetector, m_fvgDetector, m_liqDetector, entryPrice, entryPol);
        ResolveStopLoss(candidate, cfg.stopPolicy, entryPrice,
                        cfg.stopBufferPips, cfg.minStopDistancePips,
                        m_obDetector, m_liqDetector, m_ppManager,
                        stopLoss, stopPol);
        ResolveTakeProfit(candidate, cfg.targetPolicy, entryPrice, stopLoss,
                          cfg.targetRR, m_obDetector, m_fvgDetector,
                          m_liqDetector, m_bosDetector,
                          takeProfit, targetPol);

        double stopDist = MathAbs(entryPrice - stopLoss);
        double targetDist = MathAbs(takeProfit - entryPrice);
        double rr = (stopDist > 0) ? (targetDist / stopDist) : 0;

        result.total++;

        double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * m_point;
        double minStopDist = cfg.minStopDistancePips * 10.0 * m_point;
        bool valid = true;

        if(entryPrice <= 0 || stopLoss <= 0 || takeProfit <= 0)
        {
            result.rejected++;
            result.rejectionDetails[4]++;
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
        for(int k = 0; k < 8; k++)
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
    for(int i = 0; i < 8; i++)
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

#endif
