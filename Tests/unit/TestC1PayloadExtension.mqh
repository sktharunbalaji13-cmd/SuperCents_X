//+------------------------------------------------------------------+
//|                        TestC1PayloadExtension.mqh                |
//|                                      Copyright 2026, SuperCents_X|
//|                                                  Sprint 25B C1   |
//+------------------------------------------------------------------+
//  C1 payload-extension acceptance tests (plan identity persistence).
//
//  Covers: ParseIntentPlanIdentity round-trip, legacy 8-field absence,
//  writer [8..12] write-through, [3] requestedPrice preservation, and the
//  resolver structureResolved flag derivation.
//+------------------------------------------------------------------+
#ifndef __TEST_C1_PAYLOAD_EXTENSION_MQH__
#define __TEST_C1_PAYLOAD_EXTENSION_MQH__

#include "../TestAssert.mqh"
#include "../../Trading/CExecutionRecovery.mqh"
#include "../../Trading/CExecutionLedgerWriter.mqh"
#include "../../Entry/EntryPriceResolver.mqh"
#include "../../Entry/StopLossResolver.mqh"
#include "../../Entry/TargetResolver.mqh"

//--- pure parser round-trip ---------------------------------------------------
void TestC1ParsePlanIdentity(TestCounters &counters)
{
    SUITE_BEGIN("C1 - ParseIntentPlanIdentity");

    // 13-field payload (current writer format)
    string payload = "42|EURUSD|BUY|1.08521|1.0|1.08200|1.09100|27182819|1.08500|1|0|2|0";
    PlanIdentity pi;
    TEST_TRUE(ParseIntentPlanIdentity(payload, pi), "C1a 13-field payload parses");
    if(pi.present)
    {
        TEST_STR_EQ("EURUSD", pi.symbol, "C1b symbol");
        TEST_STR_EQ("BUY", pi.side, "C1c side");
        TEST_TRUE(pi.magic == 27182819, "C1d magic");
        TEST_DBL_NEAR(1.08500, pi.planEntryPrice, 1e-9, "C1e planEntryPrice");
        TEST_TRUE(pi.structureResolved, "C1f structureResolved true");
        TEST_INT_EQ(0, pi.entryPolicy, "C1g entryPolicy");
        TEST_INT_EQ(2, pi.stopPolicy, "C1h stopPolicy");
        TEST_INT_EQ(0, pi.targetPolicy, "C1i targetPolicy");
        TEST_DBL_NEAR(1.08200, pi.stopLoss, 1e-9, "C1j stopLoss (field [5])");
        TEST_DBL_NEAR(1.09100, pi.takeProfit, 1e-9, "C1k takeProfit (field [6])");
    }

    // legacy 8-field record -> identity absent
    string legacy = "42|EURUSD|BUY|1.08521|1.0|1.08200|1.09100|27182819";
    PlanIdentity pi2;
    TEST_FALSE(ParseIntentPlanIdentity(legacy, pi2), "C1l legacy 8-field -> absent");
    TEST_FALSE(pi2.present, "C1m present false on legacy");

    // structureResolved false case
    string payload2 = "42|EURUSD|SELL|1.08000|0.5|1.08500|1.07500|27182819|0.0|0|3|3|3";
    PlanIdentity pi3;
    TEST_TRUE(ParseIntentPlanIdentity(payload2, pi3), "C1n 13-field (structureResolved=false) parses");
    if(pi3.present)
    {
        TEST_FALSE(pi3.structureResolved, "C1o structureResolved false");
        TEST_DBL_NEAR(0.0, pi3.planEntryPrice, 1e-9, "C1p planEntryPrice sentinel 0.0");
        TEST_INT_EQ(3, pi3.entryPolicy, "C1q entryPolicy 3 (current-price)");
    }

    SUITE_END("C1 - ParseIntentPlanIdentity");
}

//--- writer writes [8..12]; [3] requestedPrice stays live ---------------------
void TestC1WriterPayload(TestCounters &counters)
{
    SUITE_BEGIN("C1 - writer payload extension");

    string ledgerPath = "Execution\\TestC1_Writer.dat";
    string counterPath = "Execution\\TestC1_Writer_seq.dat";
    FileDelete(ledgerPath, FILE_COMMON);
    FileDelete(counterPath, FILE_COMMON);

    CExecutionIdentity identity;
    TEST_TRUE(identity.Init("RUN-TESTC1", "test", counterPath), "C1r identity init");
    CExecutionLedgerWriter writer;
    TEST_TRUE(writer.Init(ledgerPath, &identity, "RUN-TESTC1", "test"), "C1s writer init");

    string eid = "";
    // requestedPrice (live) = 1.08521; planEntryPrice (stable) = 1.08500
    TEST_TRUE(writer.BeginExecution(42, "EURUSD", "BUY", 1.08521, 1.0, 1.08200, 1.09100, 27182819,
                                    1.08500, 1, 0, 2, 0, eid), "C1t BeginExecution with PI");

    ExecutionLedgerEvent evs[];
    string info = "";
    TEST_TRUE(LedgerScan(ledgerPath, evs, info) == LEDGER_SCAN_CLEAN, "C1u ledger CLEAN");
    TEST_INT_EQ(1, ArraySize(evs), "C1v one INTENT event");

    if(ArraySize(evs) == 1)
    {
        PlanIdentity pi;
        TEST_TRUE(ParseIntentPlanIdentity(evs[0].payload, pi), "C1w INTENT payload has 13 fields");
        if(pi.present)
        {
            TEST_DBL_NEAR(1.08500, pi.planEntryPrice, 1e-9, "C1x planEntryPrice persisted (stable)");
            TEST_TRUE(pi.structureResolved, "C1y structureResolved persisted");
            TEST_INT_EQ(0, pi.entryPolicy, "C1z entryPolicy persisted");
            TEST_INT_EQ(2, pi.stopPolicy, "C1za stopPolicy persisted");
            TEST_INT_EQ(0, pi.targetPolicy, "C1zb targetPolicy persisted");
        }
        // [3] requestedPrice must be the LIVE request price (1.08521), distinct
        // from planEntryPrice (1.08500) -> field semantics preserved.
        long did = 0; string sym = "", sd = ""; double vol = 0; long mg = 0;
        TEST_TRUE(ParseIntentPayload(evs[0].payload, did, sym, sd, vol, mg), "C1zc legacy parser still works on 13-field");
        string parts[];
        int n = StringSplit(evs[0].payload, '|', parts);
        TEST_INT_EQ(13, n, "C1zd exactly 13 fields");
        if(n >= 13)
            TEST_DBL_NEAR(1.08521, StringToDouble(parts[3]), 1e-9, "C1ze [3] requestedPrice is the live price");
    }

    writer.RecordRunEnd();
    FileDelete(ledgerPath, FILE_COMMON);
    FileDelete(counterPath, FILE_COMMON);

    SUITE_END("C1 - writer payload extension");
}

//--- resolver structureResolved flag derivation ---------------------------------
void TestC1ResolverFlags(TestCounters &counters)
{
    SUITE_BEGIN("C1 - resolver structureResolved flags");

    TradeCandidate cand;
    cand.direction = CONFLUENCE_BULLISH;
    cand.hasOB = false;
    cand.hasFVG = false;
    cand.hasLiquidity = false;
    cand.obId = -1; cand.fvgId = -1; cand.liquidityId = -1;

    double p = 0; string nm = ""; bool sr = true;

    // entry: no structure -> live-Bid fallback -> structureResolved=false
    ResolveEntryPrice(cand, ENTRY_CURRENT_PRICE, NULL, NULL, NULL, p, nm, sr);
    TEST_FALSE(sr, "C1zf entry current-price -> structureResolved false");

    // stop: broker-minimum fallback -> structureResolved=false
    double sl = 0;
    ResolveStopLoss(cand, STOP_BROKER_MINIMUM, 1.0850, 0.0, 5.0, NULL, NULL, NULL, sl, nm, sr);
    TEST_FALSE(sr, "C1zg stop broker-minimum -> structureResolved false");

    // target: fixed-RR fallback is deterministic -> structureResolved=true
    double tp = 0;
    ResolveTakeProfit(cand, TARGET_FIXED_RR, 1.0850, 1.0820, 2.0, NULL, NULL, NULL, NULL, tp, nm, sr);
    TEST_TRUE(sr, "C1zh target fixed-RR -> structureResolved true");
    TEST_DBL_NEAR(1.0850 + 2.0 * (1.0850 - 1.0820), tp, 1e-9, "C1zi fixed-RR target = entry + RR*stop");

    SUITE_END("C1 - resolver structureResolved flags");
}

TestCounters RunC1PayloadExtensionTests(void)
{
    TestCounters counters;
    TestC1ParsePlanIdentity(counters);
    TestC1WriterPayload(counters);
    TestC1ResolverFlags(counters);
    return counters;
}

#endif // __TEST_C1_PAYLOAD_EXTENSION_MQH__
