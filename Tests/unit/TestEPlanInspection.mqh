//+------------------------------------------------------------------+
//|                        TestEPlanInspection.mqh                   |
//|                                      Copyright 2026, SuperCents_X|
//|                                                  Sprint 25B B25-03C-E |
//+------------------------------------------------------------------+
//  B25-03C-E plan-identity ledger-inspection acceptance tests.
//
//  Corrected contract: MATCHED/AMBIGUOUS/CORRUPT -> BLOCK; only
//  NOT_FOUND (exhaustive ledger fold, exact canonical PI) -> SEND;
//  structureResolved=false -> BLOCK.
//+------------------------------------------------------------------+
#ifndef __TEST_E_PLAN_INSPECTION_MQH__
#define __TEST_E_PLAN_INSPECTION_MQH__

#include "../TestAssert.mqh"
#include "../../Trading/CExecutionPlanInspection.mqh"
#include "../../Trading/CExecutionLedgerWriter.mqh"
#include "../../Entry/ExecutionPlanner.mqh"
#include "../../Confluence/ConfluenceEngine.mqh"

PlanIdentity MakePI(const string symbol, const string side, const long magic,
                    const int entryPolicy, const double planEntryPrice,
                    const int stopPolicy, const double stopLoss,
                    const int targetPolicy, const double takeProfit,
                    const bool present)
{
    PlanIdentity pi;
    pi.symbol = symbol; pi.side = side; pi.magic = magic;
    pi.entryPolicy = entryPolicy; pi.planEntryPrice = planEntryPrice;
    pi.stopPolicy = stopPolicy; pi.stopLoss = stopLoss;
    pi.targetPolicy = targetPolicy; pi.takeProfit = takeProfit;
    pi.structureResolved = true; pi.present = present;
    return pi;
}

void TestEComparePlanIdentity(TestCounters &counters)
{
    SUITE_BEGIN("B25-03C-E - PI comparison");

    PlanIdentity cur = MakePI("EURUSD", "BUY", 27182819, 0, 1.08500, 2, 1.08200, 0, 1.09100, true);

    // exact match -> MATCHED
    PlanIdentity p1 = MakePI("EURUSD", "BUY", 27182819, 0, 1.08500, 2, 1.08200, 0, 1.09100, true);
    TEST_STR_EQ(EINSPECT_MATCHED, ComparePlanIdentity(cur, p1, 0.0001), "E1a exact -> MATCHED");

    // near match (entry price off by 5e-5 < eps 1e-4) -> AMBIGUOUS
    PlanIdentity p2 = MakePI("EURUSD", "BUY", 27182819, 0, 1.08505, 2, 1.08200, 0, 1.09100, true);
    TEST_STR_EQ(EINSPECT_AMBIGUOUS, ComparePlanIdentity(cur, p2, 0.0001), "E1b near -> AMBIGUOUS");

    // different side -> NOT_FOUND
    PlanIdentity p3 = MakePI("EURUSD", "SELL", 27182819, 0, 1.08500, 2, 1.08200, 0, 1.09100, true);
    TEST_STR_EQ(EINSPECT_NOT_FOUND, ComparePlanIdentity(cur, p3, 0.0001), "E1c different side -> NOT_FOUND");

    // different magic -> NOT_FOUND
    PlanIdentity p4 = MakePI("EURUSD", "BUY", 999, 0, 1.08500, 2, 1.08200, 0, 1.09100, true);
    TEST_STR_EQ(EINSPECT_NOT_FOUND, ComparePlanIdentity(cur, p4, 0.0001), "E1d different magic -> NOT_FOUND");

    // legacy prior (present=false) -> AMBIGUOUS (cannot prove non-duplicate)
    PlanIdentity p5 = MakePI("EURUSD", "BUY", 27182819, 0, 1.08500, 2, 1.08200, 0, 1.09100, false);
    TEST_STR_EQ(EINSPECT_AMBIGUOUS, ComparePlanIdentity(cur, p5, 0.0001), "E1e legacy prior -> AMBIGUOUS");

    SUITE_END("B25-03C-E - PI comparison");
}

void TestEInspectLedger(TestCounters &counters)
{
    SUITE_BEGIN("B25-03C-E - ledger inspection");

    string ledgerPath = "Execution\\TestEPlanIns.dat";
    string counterPath = "Execution\\TestEPlanIns_seq.dat";
    FileDelete(ledgerPath, FILE_COMMON);
    FileDelete(counterPath, FILE_COMMON);

    CExecutionPlanInspection insp;
    insp.Init(ledgerPath);

    // missing ledger (deleted after creation) -> UNAVAILABLE -> BLOCK (never guess)
    TEST_STR_EQ(EINSPECT_UNAVAILABLE, insp.Inspect("EURUSD", "BUY", 27182819, 0, 1.08500, 2, 1.08200, 0, 1.09100, true),
                "E2a missing ledger -> UNAVAILABLE");

    // structureResolved=false -> AMBIGUOUS (no identity -> BLOCK)
    TEST_STR_EQ(EINSPECT_AMBIGUOUS, insp.Inspect("EURUSD", "BUY", 27182819, 3, 0.0, 2, 1.08200, 0, 1.09100, false),
                "E2b structureResolved=false -> AMBIGUOUS");

    // write a prior broker-visible execution with a specific PI
    CExecutionIdentity identity;
    TEST_TRUE(identity.Init("RUN-TESTE", "test", counterPath), "E2c identity init");
    CExecutionLedgerWriter writer;
    TEST_TRUE(writer.Init(ledgerPath, &identity, "RUN-TESTE", "test"), "E2d writer init");

    // genuine first run: existing EMPTY ledger -> NOT_FOUND -> SEND
    TEST_STR_EQ(EINSPECT_NOT_FOUND, insp.Inspect("EURUSD", "BUY", 27182819, 0, 1.08500, 2, 1.08200, 0, 1.09100, true),
                "E2d2 empty existing ledger (first run) -> NOT_FOUND");

    string eid = "";
    TEST_TRUE(writer.BeginExecution(42, "EURUSD", "BUY", 1.08521, 1.0, 1.08200, 1.09100, 27182819,
                                    1.08500, 1, 0, 2, 0, eid), "E2e BeginExecution (PI)");
    ExecutionTruthRecord t;
    t.retcode = TRADE_RETCODE_DONE; t.outcome = EXEC_OUTCOME_FILLED;
    t.dealTicket = 0; t.orderTicket = 0; t.requestId = 0; t.retcodeExternal = 0;
    t.bidAtResult = 0; t.askAtResult = 0; t.brokerComment = "";
    TEST_TRUE(writer.RecordResult(eid, t, H6_POLICY_RECORD), "E2f SENT (broker-visible)");

    // exact PI match -> MATCHED
    TEST_STR_EQ(EINSPECT_MATCHED, insp.Inspect("EURUSD", "BUY", 27182819, 0, 1.08500, 2, 1.08200, 0, 1.09100, true),
                "E2g exact PI -> MATCHED (BLOCK)");

    // near PI -> AMBIGUOUS
    TEST_STR_EQ(EINSPECT_AMBIGUOUS, insp.Inspect("EURUSD", "BUY", 27182819, 0, 1.08505, 2, 1.08200, 0, 1.09100, true),
                "E2h near PI -> AMBIGUOUS (BLOCK)");

    // different plan (different stop/target) -> NOT_FOUND (SEND)
    TEST_STR_EQ(EINSPECT_NOT_FOUND, insp.Inspect("EURUSD", "BUY", 27182819, 0, 1.09000, 2, 1.08700, 0, 1.09600, true),
                "E2i different PI -> NOT_FOUND (SEND)");

    writer.RecordRunEnd();
    FileDelete(ledgerPath, FILE_COMMON);
    FileDelete(counterPath, FILE_COMMON);

    SUITE_END("B25-03C-E - ledger inspection");
}

TestCounters RunEPlanInspectionTests(void)
{
    TestCounters counters;
    TestEComparePlanIdentity(counters);
    TestEInspectLedger(counters);
    TestEPlanUnresolvedEntryRejected(counters);
    TestEPlanConfigWiring(counters);
    return counters;
}

//+------------------------------------------------------------------+
//| B25-03C-E patch acceptance (T3 + wiring).                        |
//|  A synthetic bullish RuleResult (no structure evidence, no       |
//|  detectors attached anywhere) drives candidate -> qualified      |
//|  decision -> plan through the REAL production classes. The entry |
//|  must fall back to "Current Price" (entrySR=false) and Patch A   |
//|  must reject the plan at creation with "Unresolved Entry", so it |
//|  never reaches the inspection gate as EXECUTABLE.                |
//+------------------------------------------------------------------+
void PatchTest_BuildUnresolvedSetup(CTradeCandidateBuilder &builder, CEntryDecisionEngine &engine)
{
    EntryDecisionConfig ecfg;
    ecfg.minDecisionScore = 0;
    ecfg.minConfidence = 0.0;
    ecfg.minEvidenceSources = 0;
    ecfg.minRuleMatches = 0;
    ecfg.requireTrendAlignment = false;
    engine.Init();
    engine.SetConfig(ecfg);

    RuleResult rr[];
    ArrayResize(rr, 1);
    rr[0].matched = true;
    rr[0].type = RULE_BOS_OB_BULLISH;
    rr[0].score = 80;
    rr[0].confidence = 0.8;
    rr[0].direction = CONFLUENCE_BULLISH;
    rr[0].evidenceCount = 0;
    rr[0].explanation = "synthetic unresolved-entry fixture";
    rr[0].timestamp = TimeCurrent();
    builder.Update(rr, 1);
    engine.Update(builder);
}

void TestEPlanUnresolvedEntryRejected(TestCounters &counters)
{
    SUITE_BEGIN("B25-03C-E Patch A - unresolved entry rejected at plan creation");

    CTradeCandidateBuilder builder;
    CEntryDecisionEngine engine;
    PatchTest_BuildUnresolvedSetup(builder, engine);
    TEST_INT_EQ(1, builder.GetCandidateCount(), "P-A1 one synthetic candidate");
    TEST_INT_EQ(1, engine.GetDecisionCount(), "P-A2 one decision evaluated");
    EntryDecision dec;
    TEST_TRUE(engine.GetDecision(0, dec), "P-A3 decision readable");
    TEST_INT_EQ(DECISION_QUALIFIED, dec.status, "P-A4 decision qualified (permissive gates)");

    CExecutionPlanner planner;
    TEST_TRUE(planner.Init(), "P-A5 planner init");
    planner.Update(engine, builder);
    TEST_INT_EQ(1, planner.GetPlanCount(), "P-A6 one plan built");
    ExecutionPlan plan;
    TEST_TRUE(planner.GetPlan(0, plan), "P-A7 plan readable");
    TEST_INT_EQ(PLAN_REJECTED, plan.status, "P-A8 unresolved plan REJECTED (never EXECUTABLE)");
    TEST_STR_EQ("Unresolved Entry", plan.rejectionReason, "P-A9 rejection reason");
    TEST_FALSE(plan.structureResolved, "P-A10 structureResolved=false");
    TEST_STR_EQ("Current Price", plan.entryPolicyUsed, "P-A11 entry fell back to Current Price");

    SUITE_END("B25-03C-E Patch A - unresolved entry rejected at plan creation");
}

void TestEPlanConfigWiring(TestCounters &counters)
{
    SUITE_BEGIN("B25-03C-E Patch B - plan config wiring");

    //--- NOTE: builder/engine are declared BEFORE ce on purpose.
    //    CExecutionPlanner::Shutdown() dereferences its last Update()
    //    decision engine, so the engine must still be alive when ce
    //    (and its embedded planner) destructs at function exit.
    CTradeCandidateBuilder builder;
    CEntryDecisionEngine engine;
    PatchTest_BuildUnresolvedSetup(builder, engine);

    CConfluenceEngine ce;
    TEST_TRUE(ce.Init(), "P-B1 confluence engine init");
    ce.SetPlanConfig(TARGET_FIXED_RR, 2.0);
    CExecutionPlanner *planner = ce.GetExecutionPlanner();
    TEST_NOT_NULL(planner, "P-B2 planner reachable");

    planner.Update(engine, builder);
    TEST_INT_EQ(1, planner.GetPlanCount(), "P-B3 one plan built");
    ExecutionPlan plan;
    TEST_TRUE(planner.GetPlan(0, plan), "P-B4 plan readable");
    TEST_INT_EQ(TARGET_FIXED_RR, plan.targetPolicy, "P-B5 wired target policy reaches plan");
    TEST_STR_EQ("Fixed RR 2.0", plan.targetPolicyUsed, "P-B6 target resolved by FixedRR");
    TEST_DBL_NEAR(2.0, plan.riskReward, 0.000001, "P-B7 plan RR=2.0 under FixedRR");

    SUITE_END("B25-03C-E Patch B - plan config wiring");
}

//+------------------------------------------------------------------+
//| Rule 5/6 entry-policy selection (BuildPlan candidate-dependent    |
//| entry policy).  Production correction: a candidate with no OB    |
//| but a valid liquidity level could never resolve an entry under   |
//| the ENTRY_OB_RETEST guard (requires hasOB), so entrySR stayed    |
//| false and the plan was rejected as "Unresolved Entry".           |
//|                                                                   |
//| hasFVG implies hasOB (RULE_OB_FVG_* is the only hasFVG producer  |
//| and always sets hasOB), so every hasOB family - Rule 3/4         |
//| included - must keep the configured policy.  These tests lock     |
//| that in.                                                         |
//+------------------------------------------------------------------+
void EPTest_PermissiveEngine(CEntryDecisionEngine &engine)
{
    EntryDecisionConfig ecfg;
    ecfg.minDecisionScore = 0;
    ecfg.minConfidence = 0.0;
    ecfg.minEvidenceSources = 0;
    ecfg.minRuleMatches = 0;
    ecfg.requireTrendAlignment = false;
    engine.Init();
    engine.SetConfig(ecfg);
}

//--- CTradeCandidateBuilder only binds evidence ids > 0
//    (TradeCandidateBuilder.mqh:200), but the first level a detector
//    creates is id 0 (LiquidityDetector.mqh:772, m_nextId starts at 0).
//    Burn id 0 so the level under test gets a bindable id.
int EPTest_MakeLevel(CLiquidityDetector &liq, const double price)
{
    liq.CreateLevel(LIQUIDITY_EQH, price + 0.0500, LIQUIDITY_ORIGIN_EQH, -1, -1);
    return liq.CreateLevel(LIQUIDITY_EQL, price, LIQUIDITY_ORIGIN_EQL, -1, -1);
}

void EPTest_MakeRule(RuleResult &rr, const RuleType type, const int evidenceId)
{
    rr.matched = true;
    rr.type = type;
    rr.score = 80;
    rr.confidence = 0.8;
    rr.direction = CONFLUENCE_BULLISH;
    rr.evidenceCount = (evidenceId > 0) ? 1 : 0;
    if(evidenceId > 0) rr.evidenceIds[0] = evidenceId;
    rr.explanation = "synthetic entry-policy fixture";
    rr.timestamp = TimeCurrent();
}

//--- Plan config that lets a liquidity-resolved entry also resolve its
//    stop and target, so the plan reaches EXECUTABLE in a synthetic run.
ExecutionPlanConfig EPTest_PlanConfig(void)
{
    ExecutionPlanConfig pc;
    pc.entryPolicy = ENTRY_OB_RETEST;   // global default left untouched
    pc.stopPolicy = STOP_LIQUIDITY_SIDE;
    pc.targetPolicy = TARGET_FIXED_RR;
    pc.targetRR = 2.0;
    pc.stopBufferPips = 30.0;
    pc.minStopDistancePips = 5.0;
    return pc;
}

void TestEntryPolicyLiquidityResolved(TestCounters &counters)
{
    SUITE_BEGIN("Entry policy - Rule 5/6 resolves at liquidity level");

    const double LEVEL = 1.10000;

    CLiquidityDetector liq;
    TEST_TRUE(liq.Init(), "EP-1 liquidity detector init");
    int levelId = EPTest_MakeLevel(liq, LEVEL);
    TEST_TRUE(levelId > 0, "EP-2 liquidity level created with bindable id");

    CTradeCandidateBuilder builder;
    CEntryDecisionEngine engine;
    builder.SetLiquidityDetector(GetPointer(liq));
    EPTest_PermissiveEngine(engine);

    RuleResult rr[];
    ArrayResize(rr, 1);
    EPTest_MakeRule(rr[0], RULE_LIQUIDITY_BOS_BULLISH, levelId);
    builder.Update(rr, 1);

    TradeCandidate cand;
    TEST_TRUE(builder.GetCandidate(0, cand), "EP-3 candidate readable");
    TEST_TRUE(cand.hasLiquidity, "EP-4 Rule 5/6 candidate hasLiquidity=true");
    TEST_FALSE(cand.hasOB, "EP-5 Rule 5/6 candidate hasOB=false");
    TEST_FALSE(cand.hasFVG, "EP-6 Rule 5/6 candidate hasFVG=false");
    TEST_INT_EQ(levelId, cand.liquidityId, "EP-7 liquidity id bound to candidate");

    engine.Update(builder);
    EntryDecision dec;
    TEST_TRUE(engine.GetDecision(0, dec), "EP-8 decision readable");
    TEST_INT_EQ(DECISION_QUALIFIED, dec.status, "EP-9 decision qualified");

    CExecutionPlanner planner;
    TEST_TRUE(planner.Init(), "EP-10 planner init");
    planner.SetConfig(EPTest_PlanConfig());
    planner.SetLiquidityDetector(GetPointer(liq));
    planner.Update(engine, builder);

    TEST_INT_EQ(1, planner.GetPlanCount(), "EP-11 one plan built");
    ExecutionPlan plan;
    TEST_TRUE(planner.GetPlan(0, plan), "EP-12 plan readable");
    TEST_INT_EQ(ENTRY_LIQUIDITY_LEVEL, plan.entryPolicy,
                "EP-13 policy recorded in plan identity = Liquidity Level");
    TEST_STR_EQ("Liquidity Level", plan.entryPolicyUsed, "EP-14 entry resolved by Liquidity Level");
    TEST_DBL_NEAR(LEVEL, plan.entryPrice, 1e-9, "EP-15 entry price = liquidity level price");
    TEST_TRUE(plan.structureResolved, "EP-16 structureResolved=true");
    TEST_INT_EQ(PLAN_EXECUTABLE, plan.status, "EP-17 plan EXECUTABLE (was REJECTED before fix)");

    SUITE_END("Entry policy - Rule 5/6 resolves at liquidity level");
}

void TestEntryPolicyLiquidityIdInvalid(TestCounters &counters)
{
    SUITE_BEGIN("Entry policy - Rule 5/6 invalid liquidity id stays unresolved");

    const double LEVEL = 1.10000;

    CLiquidityDetector liq;
    TEST_TRUE(liq.Init(), "EPI-1 liquidity detector init");
    int levelId = EPTest_MakeLevel(liq, LEVEL);
    TEST_TRUE(levelId > 0, "EPI-2 liquidity level created with bindable id");

    CTradeCandidateBuilder builder;
    CEntryDecisionEngine engine;
    //--- Detector deliberately NOT attached to the builder: the evidence id
    //    cannot validate, so liquidityId stays -1 while hasLiquidity=true.
    EPTest_PermissiveEngine(engine);

    RuleResult rr[];
    ArrayResize(rr, 1);
    EPTest_MakeRule(rr[0], RULE_LIQUIDITY_BOS_BULLISH, levelId);
    builder.Update(rr, 1);

    TradeCandidate cand;
    TEST_TRUE(builder.GetCandidate(0, cand), "EPI-3 candidate readable");
    TEST_TRUE(cand.hasLiquidity, "EPI-4 hasLiquidity=true");
    TEST_INT_EQ(-1, cand.liquidityId, "EPI-5 liquidityId unresolved (-1)");

    engine.Update(builder);
    CExecutionPlanner planner;
    TEST_TRUE(planner.Init(), "EPI-6 planner init");
    planner.SetConfig(EPTest_PlanConfig());
    planner.SetLiquidityDetector(GetPointer(liq));
    planner.Update(engine, builder);

    TEST_INT_EQ(1, planner.GetPlanCount(), "EPI-7 one plan built");
    ExecutionPlan plan;
    TEST_TRUE(planner.GetPlan(0, plan), "EPI-8 plan readable");
    TEST_INT_EQ(ENTRY_OB_RETEST, plan.entryPolicy, "EPI-9 configured policy retained (no override)");
    TEST_STR_EQ("Current Price", plan.entryPolicyUsed, "EPI-10 entry fell back to Current Price");
    TEST_FALSE(plan.structureResolved, "EPI-11 structureResolved=false");
    TEST_INT_EQ(PLAN_REJECTED, plan.status, "EPI-12 plan REJECTED");
    TEST_STR_EQ("Unresolved Entry", plan.rejectionReason, "EPI-13 rejection reason unchanged");

    SUITE_END("Entry policy - Rule 5/6 invalid liquidity id stays unresolved");
}

void TestEntryPolicyHasOBFamiliesPreserved(TestCounters &counters)
{
    SUITE_BEGIN("Entry policy - hasOB families keep configured policy");

    const double LEVEL = 1.10000;

    CLiquidityDetector liq;
    TEST_TRUE(liq.Init(), "EPO-1 liquidity detector init");
    int levelId = EPTest_MakeLevel(liq, LEVEL);
    TEST_TRUE(levelId > 0, "EPO-2 liquidity level created with bindable id");

    //--- Genuine multi-evidence candidate: Rule 3/4 (OB_FVG) AND Rule 5/6
    //    (LIQUIDITY_BOS) both matched bullish in one Update, so the builder
    //    aggregates them into a single candidate with
    //    hasOB && hasFVG && hasLiquidity.  This is the exact case where a
    //    naive hasFVG/hasLiquidity-first ordering would have flipped Rule
    //    3/4 from OB Retest to Liquidity Level.  No order block exists in
    //    the OB detector (none attachable synthetically), so the OB path
    //    must fall through to Current Price - never to Liquidity Level.
    CTradeCandidateBuilder builder;
    CEntryDecisionEngine engine;
    builder.SetLiquidityDetector(GetPointer(liq));
    EPTest_PermissiveEngine(engine);

    RuleResult rr[];
    ArrayResize(rr, 2);
    EPTest_MakeRule(rr[0], RULE_OB_FVG_BULLISH, levelId);
    EPTest_MakeRule(rr[1], RULE_LIQUIDITY_BOS_BULLISH, levelId);
    builder.Update(rr, 2);

    TEST_INT_EQ(1, builder.GetCandidateCount(), "EPO-3 matched rules aggregate to one candidate");
    TradeCandidate cand;
    TEST_TRUE(builder.GetCandidate(0, cand), "EPO-4 candidate readable");
    TEST_TRUE(cand.hasOB, "EPO-5 multi-evidence candidate hasOB=true");
    TEST_TRUE(cand.hasFVG, "EPO-6 multi-evidence candidate hasFVG=true");
    TEST_TRUE(cand.hasLiquidity, "EPO-7 multi-evidence candidate hasLiquidity=true");
    TEST_INT_EQ(levelId, cand.liquidityId, "EPO-8 liquidity id bound to candidate");

    engine.Update(builder);
    CExecutionPlanner planner;
    TEST_TRUE(planner.Init(), "EPO-9 planner init");
    planner.SetConfig(EPTest_PlanConfig());
    planner.SetLiquidityDetector(GetPointer(liq));
    planner.Update(engine, builder);

    TEST_INT_EQ(1, planner.GetPlanCount(), "EPO-10 one plan built");
    ExecutionPlan plan;
    TEST_TRUE(planner.GetPlan(0, plan), "EPO-11 plan readable");
    TEST_INT_EQ(ENTRY_OB_RETEST, plan.entryPolicy,
                "EPO-12 hasOB candidate keeps configured ENTRY_OB_RETEST (no override)");
    TEST_TRUE(plan.entryPolicyUsed != "Liquidity Level",
              "EPO-13 hasOB candidate did NOT resolve at the liquidity level");

    SUITE_END("Entry policy - hasOB families keep configured policy");
}

TestCounters RunEntryPolicySelectionTests(void)
{
    TestCounters counters;
    TestEntryPolicyLiquidityResolved(counters);
    TestEntryPolicyLiquidityIdInvalid(counters);
    TestEntryPolicyHasOBFamiliesPreserved(counters);
    return counters;
}

#endif // __TEST_E_PLAN_INSPECTION_MQH__
