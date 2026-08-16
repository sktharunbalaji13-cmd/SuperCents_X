//+------------------------------------------------------------------+
//|                            TestH6RetryPolicy.mqh                 |
//|                                      Copyright 2026, SuperCents_X|
//|                                              Sprint 25B H6 (Rev 2)|
//+------------------------------------------------------------------+
//  H6 retry-policy acceptance tests (Revision 2 table) + hold map.
//
//  The single source of truth for the retcode mapping is
//  Trading/TradeManagerRetryPolicy.mqh (H6ClassifyPolicy).  These tests
//  lock that table exhaustively.
//
//  Policy classes:
//    H6_POLICY_RECORD          broker-visible submission (PLACED/DONE/
//                              DONE_PARTIAL, or deal != 0 override) ->
//                              dedup entered, never retried.
//    H6_POLICY_REJECT_PERMANENT deterministic refusal, plan/request defect
//                              or immutable environment -> PLAN_REJECTED.
//    H6_POLICY_RETRY_ELIGIBLE  deterministic refusal, transient state ->
//                              re-attempted on the next tick (no engine).
//    H6_POLICY_RETRY_HOLD      uncertain outcome (TIMEOUT/CONNECTION/ERROR/
//                              NO_CHANGES/ORDER_CHANGED/retcode 0/
//                              unrecognized) -> never auto-retried, never
//                              rejected, no release until B25-03C durable
//                              reconciliation.
//+------------------------------------------------------------------+
#ifndef __TEST_H6_RETRY_POLICY_MQH__
#define __TEST_H6_RETRY_POLICY_MQH__

#include "../TestAssert.mqh"
#include "../../Trading/TradeManagerRetryPolicy.mqh"
#include "../../Trading/TradeManager.mqh"

//--- Covers the full Revision 2 table, one assertion per retcode.
void TestH6PolicyTable(TestCounters &counters)
{
    SUITE_BEGIN("H6 - retry policy table (Revision 2)");

    //--- RECORD: broker-visible submission.
    TEST_INT_EQ(H6_POLICY_RECORD, H6ClassifyPolicy(TRADE_RETCODE_PLACED, 0), "P01 PLACED -> RECORD");
    TEST_INT_EQ(H6_POLICY_RECORD, H6ClassifyPolicy(TRADE_RETCODE_DONE, 0), "P02 DONE -> RECORD");
    TEST_INT_EQ(H6_POLICY_RECORD, H6ClassifyPolicy(TRADE_RETCODE_DONE_PARTIAL, 0), "P03 DONE_PARTIAL -> RECORD");

    //--- deal != 0 override: broker-confirmed execution beats any retcode.
    TEST_INT_EQ(H6_POLICY_RECORD, H6ClassifyPolicy(TRADE_RETCODE_REJECT, 1), "P04 reject+deal -> RECORD");
    TEST_INT_EQ(H6_POLICY_RECORD, H6ClassifyPolicy(TRADE_RETCODE_TIMEOUT, 2), "P05 timeout+deal -> RECORD");
    TEST_INT_EQ(H6_POLICY_RECORD, H6ClassifyPolicy(TRADE_RETCODE_INVALID, 3), "P06 invalid+deal -> RECORD");

    //--- RETRY_ELIGIBLE: deterministic refusal, transient state.
    TEST_INT_EQ(H6_POLICY_RETRY_ELIGIBLE, H6ClassifyPolicy(TRADE_RETCODE_REQUOTE, 0), "P07 REQUOTE -> ELIGIBLE");
    TEST_INT_EQ(H6_POLICY_RETRY_ELIGIBLE, H6ClassifyPolicy(TRADE_RETCODE_REJECT, 0), "P08 REJECT -> ELIGIBLE");
    TEST_INT_EQ(H6_POLICY_RETRY_ELIGIBLE, H6ClassifyPolicy(TRADE_RETCODE_CANCEL, 0), "P09 CANCEL -> ELIGIBLE");
    TEST_INT_EQ(H6_POLICY_RETRY_ELIGIBLE, H6ClassifyPolicy(TRADE_RETCODE_PRICE_CHANGED, 0), "P10 PRICE_CHANGED -> ELIGIBLE");
    TEST_INT_EQ(H6_POLICY_RETRY_ELIGIBLE, H6ClassifyPolicy(TRADE_RETCODE_PRICE_OFF, 0), "P11 PRICE_OFF -> ELIGIBLE");
    TEST_INT_EQ(H6_POLICY_RETRY_ELIGIBLE, H6ClassifyPolicy(TRADE_RETCODE_MARKET_CLOSED, 0), "P12 MARKET_CLOSED -> ELIGIBLE");
    TEST_INT_EQ(H6_POLICY_RETRY_ELIGIBLE, H6ClassifyPolicy(TRADE_RETCODE_NO_MONEY, 0), "P13 NO_MONEY -> ELIGIBLE");
    TEST_INT_EQ(H6_POLICY_RETRY_ELIGIBLE, H6ClassifyPolicy(TRADE_RETCODE_TOO_MANY_REQUESTS, 0), "P14 TOO_MANY_REQUESTS -> ELIGIBLE");
    TEST_INT_EQ(H6_POLICY_RETRY_ELIGIBLE, H6ClassifyPolicy(TRADE_RETCODE_FROZEN, 0), "P15 FROZEN -> ELIGIBLE");
    TEST_INT_EQ(H6_POLICY_RETRY_ELIGIBLE, H6ClassifyPolicy(TRADE_RETCODE_LOCKED, 0), "P16 LOCKED -> ELIGIBLE");
    TEST_INT_EQ(H6_POLICY_RETRY_ELIGIBLE, H6ClassifyPolicy(TRADE_RETCODE_TRADE_DISABLED, 0), "P17 TRADE_DISABLED -> ELIGIBLE");
    TEST_INT_EQ(H6_POLICY_RETRY_ELIGIBLE, H6ClassifyPolicy(TRADE_RETCODE_SERVER_DISABLES_AT, 0), "P18 SERVER_DISABLES_AT -> ELIGIBLE");
    TEST_INT_EQ(H6_POLICY_RETRY_ELIGIBLE, H6ClassifyPolicy(TRADE_RETCODE_CLIENT_DISABLES_AT, 0), "P19 CLIENT_DISABLES_AT -> ELIGIBLE");
    TEST_INT_EQ(H6_POLICY_RETRY_ELIGIBLE, H6ClassifyPolicy(TRADE_RETCODE_LIMIT_ORDERS, 0), "P20 LIMIT_ORDERS -> ELIGIBLE");
    TEST_INT_EQ(H6_POLICY_RETRY_ELIGIBLE, H6ClassifyPolicy(TRADE_RETCODE_LIMIT_VOLUME, 0), "P21 LIMIT_VOLUME -> ELIGIBLE");

    //--- REJECT_PERMANENT: deterministic refusal, plan/request defect.
    TEST_INT_EQ(H6_POLICY_REJECT_PERMANENT, H6ClassifyPolicy(TRADE_RETCODE_INVALID, 0), "P22 INVALID -> PERMANENT");
    TEST_INT_EQ(H6_POLICY_REJECT_PERMANENT, H6ClassifyPolicy(TRADE_RETCODE_INVALID_VOLUME, 0), "P23 INVALID_VOLUME -> PERMANENT");
    TEST_INT_EQ(H6_POLICY_REJECT_PERMANENT, H6ClassifyPolicy(TRADE_RETCODE_INVALID_PRICE, 0), "P24 INVALID_PRICE -> PERMANENT");
    TEST_INT_EQ(H6_POLICY_REJECT_PERMANENT, H6ClassifyPolicy(TRADE_RETCODE_INVALID_STOPS, 0), "P25 INVALID_STOPS -> PERMANENT");
    TEST_INT_EQ(H6_POLICY_REJECT_PERMANENT, H6ClassifyPolicy(TRADE_RETCODE_INVALID_EXPIRATION, 0), "P26 INVALID_EXPIRATION -> PERMANENT");
    TEST_INT_EQ(H6_POLICY_REJECT_PERMANENT, H6ClassifyPolicy(TRADE_RETCODE_INVALID_ORDER, 0), "P27 INVALID_ORDER -> PERMANENT");
    TEST_INT_EQ(H6_POLICY_REJECT_PERMANENT, H6ClassifyPolicy(TRADE_RETCODE_INVALID_FILL, 0), "P28 INVALID_FILL -> PERMANENT");
    TEST_INT_EQ(H6_POLICY_REJECT_PERMANENT, H6ClassifyPolicy(TRADE_RETCODE_ONLY_REAL, 0), "P29 ONLY_REAL -> PERMANENT");

    //--- RETRY_HOLD: uncertain outcomes - never retried, never rejected.
    TEST_INT_EQ(H6_POLICY_RETRY_HOLD, H6ClassifyPolicy(TRADE_RETCODE_TIMEOUT, 0), "P30 TIMEOUT -> HOLD");
    TEST_INT_EQ(H6_POLICY_RETRY_HOLD, H6ClassifyPolicy(TRADE_RETCODE_CONNECTION, 0), "P31 CONNECTION -> HOLD");
    TEST_INT_EQ(H6_POLICY_RETRY_HOLD, H6ClassifyPolicy(TRADE_RETCODE_ERROR, 0), "P32 ERROR -> HOLD");
    TEST_INT_EQ(H6_POLICY_RETRY_HOLD, H6ClassifyPolicy(TRADE_RETCODE_NO_CHANGES, 0), "P33 NO_CHANGES -> HOLD");
    TEST_INT_EQ(H6_POLICY_RETRY_HOLD, H6ClassifyPolicy(TRADE_RETCODE_ORDER_CHANGED, 0), "P34 ORDER_CHANGED -> HOLD");
    TEST_INT_EQ(H6_POLICY_RETRY_HOLD, H6ClassifyPolicy(0, 0), "P35 retcode 0 -> HOLD");
    TEST_INT_EQ(H6_POLICY_RETRY_HOLD, H6ClassifyPolicy(999999, 0), "P36 unrecognized retcode -> HOLD");

    SUITE_END("H6 - retry policy table (Revision 2)");
}

//--- No-blind-resend property: the uncertain set never becomes RECORD or
//    RETRY_ELIGIBLE (explicit, independent of the exact-equality table).
void TestH6NoBlindResend(TestCounters &counters)
{
    SUITE_BEGIN("H6 - no blind resend after uncertain outcome");

    uint uncertain[] = {
        TRADE_RETCODE_TIMEOUT,
        TRADE_RETCODE_CONNECTION,
        TRADE_RETCODE_ERROR,
        TRADE_RETCODE_NO_CHANGES,
        TRADE_RETCODE_ORDER_CHANGED,
        0,
        999999
    };

    bool ok = true;
    for(int i = 0; i < ArraySize(uncertain); i++)
    {
        ENUM_H6_RETRY_POLICY p = H6ClassifyPolicy(uncertain[i], 0);
        if(p == H6_POLICY_RECORD || p == H6_POLICY_RETRY_ELIGIBLE)
        {
            ok = false;
            Print("  UNCERTAIN retcode " + IntegerToString(uncertain[i]) + " yielded class " + IntegerToString((int)p));
        }
    }
    TEST_TRUE(ok, "N1: no uncertain retcode maps to RECORD or RETRY_ELIGIBLE");

    SUITE_END("H6 - no blind resend after uncertain outcome");
}

//--- Determinism: pure function, same input -> same class, 100 iterations.
void TestH6Determinism(TestCounters &counters)
{
    SUITE_BEGIN("H6 - policy determinism");

    bool ok = true;
    ENUM_H6_RETRY_POLICY r0 = H6ClassifyPolicy(TRADE_RETCODE_TIMEOUT, 0);
    ENUM_H6_RETRY_POLICY r1 = H6ClassifyPolicy(TRADE_RETCODE_REQUOTE, 0);
    ENUM_H6_RETRY_POLICY r2 = H6ClassifyPolicy(TRADE_RETCODE_DONE, 5);
    for(int i = 0; i < 100; i++)
    {
        if(H6ClassifyPolicy(TRADE_RETCODE_TIMEOUT, 0) != r0) ok = false;
        if(H6ClassifyPolicy(TRADE_RETCODE_REQUOTE, 0) != r1) ok = false;
        if(H6ClassifyPolicy(TRADE_RETCODE_DONE, 5) != r2) ok = false;
    }
    TEST_TRUE(ok, "D1: 100 iterations yield identical classes");

    SUITE_END("H6 - policy determinism");
}

//--- Hold map: add / contains / accumulate / clear on Shutdown.  There is
//    no intra-session release path (structural: no removal method exists;
//    Shutdown is the only exit).
void TestH6HoldMap(TestCounters &counters)
{
    SUITE_BEGIN("H6 - hold map lifecycle");

    CTradeManager manager;
    manager.SetSymbol(_Symbol);
    manager.SetMagicNumber(27182819);
    TEST_TRUE(manager.Init(), "H0: TradeManager init");

    TEST_INT_EQ(0, manager.GetHeldCount(), "H1: held count starts at 0");
    TEST_INT_EQ(0, manager.GetTotalHeld(), "H2: total held starts at 0");

    manager.HoldPlanForRetry(12345);
    TEST_TRUE(manager.IsPlanRetryHeld(12345), "H3: held plan detected");
    TEST_INT_EQ(1, manager.GetHeldCount(), "H4: held count == 1");

    manager.HoldPlanForRetry(67890);
    TEST_TRUE(manager.IsPlanRetryHeld(12345), "H5: first hold retained on second add");
    TEST_TRUE(manager.IsPlanRetryHeld(67890), "H6: second hold present");
    TEST_INT_EQ(2, manager.GetHeldCount(), "H7: held count == 2");

    TEST_FALSE(manager.IsPlanRetryHeld(99999), "H8: unheld plan not detected");

    manager.Shutdown();
    TEST_FALSE(manager.IsPlanRetryHeld(12345), "H9: hold cleared on Shutdown");
    TEST_FALSE(manager.IsPlanRetryHeld(67890), "H10: hold cleared on Shutdown (2)");
    TEST_INT_EQ(0, manager.GetHeldCount(), "H11: held count == 0 after Shutdown");

    SUITE_END("H6 - hold map lifecycle");
}

TestCounters RunH6RetryPolicyTests(void)
{
    TestCounters counters;
    TestH6PolicyTable(counters);
    TestH6NoBlindResend(counters);
    TestH6Determinism(counters);
    TestH6HoldMap(counters);
    return counters;
}

#endif // __TEST_H6_RETRY_POLICY_MQH__
