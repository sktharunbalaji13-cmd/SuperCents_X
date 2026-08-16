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
    return counters;
}

#endif // __TEST_E_PLAN_INSPECTION_MQH__
