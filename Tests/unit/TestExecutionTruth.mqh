//+------------------------------------------------------------------+
//|                          TestExecutionTruth.mqh                  |
//|                                      Copyright 2026, SuperCents_X|
//|                                                  Sprint 25B B25-03B |
//+------------------------------------------------------------------+
//  B25-03B - Execution Result Truth acceptance tests (T1-T13 plus
//  critical-difference anchors for defects D1-D6 of the assessment).
//
//  Pure unit tests of Trading/ExecutionTruth.mqh: outcome
//  classification from broker retcode/deal/volume semantics and
//  write-once capture of every MqlTradeResult field. NO OrderSend,
//  no broker connection, no files, no timers, no callbacks.
//
//  TDD contract: this file is written ONCE and stays byte-identical
//  across the RED (defect-mirror) and GREEN (truthful) phases. The
//  RED phase must fail exactly where the current TradeManager truth
//  model is wrong:
//    D1 - requested price labeled as filled (filledPrice = request.price)
//    D2 - requested volume labeled as filled (filledVolume = request.volume)
//    D3 - deal ticket discarded
//    D5 - OrderSend boolean treated as execution success
//    D6 - request_id / retcode_external / bid / ask / comment dropped
//+------------------------------------------------------------------+
#ifndef __TEST_EXECUTION_TRUTH_MQH__
#define __TEST_EXECUTION_TRUTH_MQH__

#include "../TestAssert.mqh"
#include "../../Trading/ExecutionTruth.mqh"

TestCounters RunExecutionTruthTests(void)
{
    TestCounters counters;
    SUITE_BEGIN("ExecutionTruth");

    //================================================================
    // T1. Full market fill: DONE + deal. Broker-confirmed price differs
    //     from the requested price (slippage) - the D1/D3/D6 anchors.
    //================================================================
    {
        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.action  = TRADE_ACTION_DEAL;
        req.symbol  = "EURUSD";
        req.volume  = 0.10;
        req.price   = 1.10500;
        req.deviation = 10;
        req.magic   = 42;

        res.retcode = TRADE_RETCODE_DONE;
        res.deal    = 1000001;
        res.order   = 2000001;
        res.volume  = 0.10;
        res.price   = 1.10520;
        res.bid     = 1.10515;
        res.ask     = 1.10525;
        res.comment = "Request completed";
        res.request_id      = 77;
        res.retcode_external = 0;

        ExecutionTruthRecord r = CaptureExecutionTruth(req, res, 501);

        TEST_TRUE(r.outcome == EXEC_OUTCOME_FILLED, "T1a: DONE + deal -> FILLED");
        TEST_DBL_EQ(1.10500, r.requestedPrice, "T1b: requested price preserved separately");
        TEST_DBL_EQ(1.10520, r.filledPrice, "T1c: filled price = broker result price (never request.price)");
        TEST_TRUE(r.filledPrice != r.requestedPrice, "T1d: CRITICAL: requested price != broker filled price");
        TEST_DBL_EQ(0.10, r.filledVolume, "T1e: filled volume = broker result volume");
        TEST_INT_EQ(1000001, (int)r.dealTicket, "T1f: deal ticket captured (D3 fix)");
        TEST_INT_EQ(2000001, (int)r.orderTicket, "T1g: order ticket captured");
        TEST_INT_EQ(77, (int)r.requestId, "T1h: request_id captured (D6 fix)");
        TEST_STR_EQ("Request completed", r.brokerComment, "T1i: broker comment captured (D6 fix)");
        TEST_DBL_NEAR(1.10515, r.bidAtResult, 1e-9, "T1j: bid captured (D6 fix)");
        TEST_DBL_NEAR(1.10525, r.askAtResult, 1e-9, "T1k: ask captured (D6 fix)");
        TEST_INT_EQ(501, (int)r.executionPlanId, "T1l: executionPlanId carried into the record");
    }

    //================================================================
    // T2. Partial fill: DONE_PARTIAL + deal, broker volume < requested
    //     volume - the D2 anchor and the requested!=filled volume proof.
    //================================================================
    {
        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.action = TRADE_ACTION_DEAL;
        req.volume = 0.10;
        req.price  = 1.10500;

        res.retcode = TRADE_RETCODE_DONE_PARTIAL;
        res.deal    = 1000002;
        res.order   = 2000002;
        res.volume  = 0.04;
        res.price   = 1.10610;

        ExecutionTruthRecord r = CaptureExecutionTruth(req, res, 502);

        TEST_TRUE(r.outcome == EXEC_OUTCOME_PARTIALLY_FILLED, "T2a: DONE_PARTIAL + deal -> PARTIALLY_FILLED");
        TEST_DBL_EQ(0.04, r.filledVolume, "T2b: filled volume = broker-confirmed partial volume");
        TEST_DBL_EQ(0.10, r.requestedVolume, "T2c: requested volume preserved separately");
        TEST_TRUE(r.filledVolume != r.requestedVolume, "T2d: CRITICAL: requested volume != broker filled volume");
        TEST_DBL_EQ(1.10610, r.filledPrice, "T2e: filled price = broker result price");
        TEST_INT_EQ(1000002, (int)r.dealTicket, "T2f: partial-fill deal ticket captured");
    }

    //================================================================
    // T3. REJECT with OrderSend boolean true - the D5 regression anchor.
    //     The classifier has NO boolean input: outcome derives from the
    //     broker retcode alone, so a REJECT can never be success.
    //================================================================
    {
        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.volume = 0.10;
        req.price  = 1.10500;

        res.retcode = TRADE_RETCODE_REJECT;
        res.deal    = 0;
        res.order   = 0;

        ExecutionOutcome o = ClassifyOutcome(res.retcode, res.deal, res.volume, req.volume);
        TEST_TRUE(o == EXEC_OUTCOME_REJECTED, "T3a: ClassifyOutcome(REJECT) -> REJECTED (boolean can never override)");

        ExecutionTruthRecord r = CaptureExecutionTruth(req, res, 503);
        TEST_TRUE(r.outcome == EXEC_OUTCOME_REJECTED, "T3b: REJECT + sent=true -> REJECTED (D5 fix)");
        TEST_DBL_EQ(0.0, r.filledPrice, "T3c: REJECT -> no fabricated fill price");
        TEST_DBL_EQ(0.0, r.filledVolume, "T3d: REJECT -> no fabricated fill volume");
        TEST_INT_EQ((int)TRADE_RETCODE_REJECT, (int)r.retcode, "T3e: retcode preserved");
        TEST_INT_EQ(0, (int)r.dealTicket, "T3f: no deal on rejection");
        TEST_INT_EQ(0, (int)r.orderTicket, "T3g: no order on rejection");
    }

    //================================================================
    // T4. Invalid volume (pre-broker validation class).
    //================================================================
    {
        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.volume = 0.10;
        req.price  = 1.10500;

        res.retcode = TRADE_RETCODE_INVALID_VOLUME;

        ExecutionTruthRecord r = CaptureExecutionTruth(req, res, 504);

        TEST_TRUE(r.outcome == EXEC_OUTCOME_REJECTED, "T4a: INVALID_VOLUME -> REJECTED");
        TEST_INT_EQ((int)TRADE_RETCODE_INVALID_VOLUME, (int)r.retcode, "T4b: retcode preserved");
        TEST_DBL_EQ(0.0, r.filledPrice, "T4c: no fill on rejection");
        TEST_DBL_EQ(0.0, r.filledVolume, "T4d: no fill on rejection");
        TEST_INT_EQ(0, (int)r.dealTicket, "T4e: no deal ticket on rejection");
    }

    //================================================================
    // T5. Requote - rejection class with requote context preserved.
    //================================================================
    {
        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.volume = 0.10;
        req.price  = 1.10500;

        res.retcode = TRADE_RETCODE_REQUOTE;
        res.bid     = 1.10513;
        res.ask     = 1.10523;

        ExecutionTruthRecord r = CaptureExecutionTruth(req, res, 505);

        TEST_TRUE(r.outcome == EXEC_OUTCOME_REJECTED, "T5a: REQUOTE -> REJECTED");
        TEST_DBL_NEAR(1.10513, r.bidAtResult, 1e-9, "T5b: requote bid preserved");
        TEST_DBL_NEAR(1.10523, r.askAtResult, 1e-9, "T5c: requote ask preserved");
        TEST_DBL_EQ(0.0, r.filledPrice, "T5d: no fill on requote");
    }

    //================================================================
    // T6. No money - rejection class with broker comment preserved.
    //================================================================
    {
        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.volume = 0.10;
        req.price  = 1.10500;

        res.retcode = TRADE_RETCODE_NO_MONEY;
        res.comment = "Not enough money";

        ExecutionTruthRecord r = CaptureExecutionTruth(req, res, 506);

        TEST_TRUE(r.outcome == EXEC_OUTCOME_REJECTED, "T6a: NO_MONEY -> REJECTED");
        TEST_STR_EQ("Not enough money", r.brokerComment, "T6b: broker comment preserved");
        TEST_DBL_EQ(0.0, r.filledPrice, "T6c: no fill on rejection");
    }

    //================================================================
    // T7. Timeout - must remain UNCERTAIN (TIMEOUT), never a fill.
    //================================================================
    {
        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.volume = 0.10;
        req.price  = 1.10500;

        res.retcode = TRADE_RETCODE_TIMEOUT;
        res.deal    = 0;

        ExecutionTruthRecord r = CaptureExecutionTruth(req, res, 507);

        TEST_TRUE(r.outcome == EXEC_OUTCOME_TIMEOUT, "T7a: TIMEOUT -> TIMEOUT (uncertain, not a fill)");
        TEST_DBL_EQ(0.0, r.filledPrice, "T7b: timeout -> no fabricated fill");
        TEST_DBL_EQ(0.0, r.filledVolume, "T7c: timeout -> no fabricated fill");
        TEST_INT_EQ(0, (int)r.dealTicket, "T7d: timeout -> no deal ticket");
    }

    //================================================================
    // T8. Connection failure (OrderSend boolean false context) - must
    //     NOT become a fabricated rejection or fill.
    //================================================================
    {
        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.volume = 0.10;
        req.price  = 1.10500;

        res.retcode = TRADE_RETCODE_CONNECTION;

        ExecutionTruthRecord r = CaptureExecutionTruth(req, res, 508);

        TEST_TRUE(r.outcome == EXEC_OUTCOME_CONNECTION_ERROR, "T8a: CONNECTION -> CONNECTION_ERROR");
        TEST_DBL_EQ(0.0, r.filledPrice, "T8b: connection failure -> no fabricated fill");
        TEST_DBL_EQ(0.0, r.filledVolume, "T8c: connection failure -> no fabricated fill");
    }

    //================================================================
    // T9. Placed / no deal - accepted but NOT filled; nothing fabricated.
    //================================================================
    {
        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.volume = 0.10;
        req.price  = 1.10500;

        res.retcode = TRADE_RETCODE_PLACED;
        res.order   = 2000009;
        res.deal    = 0;
        res.volume  = 0.10;
        res.price   = 1.10520;

        ExecutionTruthRecord r = CaptureExecutionTruth(req, res, 509);

        TEST_TRUE(r.outcome == EXEC_OUTCOME_ACCEPTED_NO_DEAL, "T9a: PLACED + deal=0 -> ACCEPTED_NO_DEAL");
        TEST_INT_EQ(2000009, (int)r.orderTicket, "T9b: order ticket preserved");
        TEST_DBL_EQ(0.0, r.filledPrice, "T9c: no fabricated fill when deal == 0");
        TEST_DBL_EQ(0.0, r.filledVolume, "T9d: no fabricated fill when deal == 0");
        TEST_INT_EQ(0, (int)r.dealTicket, "T9e: no deal ticket");
    }

    //================================================================
    // T10. Unknown retcode + external code - BROKER_ERROR, raw values
    //      preserved (D6 anchor for retcode_external).
    //================================================================
    {
        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.volume = 0.10;
        req.price  = 1.10500;

        res.retcode          = 99999;
        res.retcode_external = -7;

        ExecutionTruthRecord r = CaptureExecutionTruth(req, res, 510);

        TEST_TRUE(r.outcome == EXEC_OUTCOME_BROKER_ERROR, "T10a: unknown retcode -> BROKER_ERROR");
        TEST_INT_EQ(99999, (int)r.retcode, "T10b: raw retcode preserved");
        TEST_INT_EQ(-7, r.retcodeExternal, "T10c: retcode_external preserved (D6 fix)");
        TEST_DBL_EQ(0.0, r.filledPrice, "T10d: no fabricated fill");
    }

    //================================================================
    // T11. DONE with deal == 0 (defensive broker mode) - still no fill.
    //================================================================
    {
        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.volume = 0.10;
        req.price  = 1.10500;

        res.retcode = TRADE_RETCODE_DONE;
        res.deal    = 0;
        res.volume  = 0.10;
        res.price   = 1.10700;

        ExecutionTruthRecord r = CaptureExecutionTruth(req, res, 511);

        TEST_TRUE(r.outcome == EXEC_OUTCOME_ACCEPTED_NO_DEAL, "T11a: DONE + deal=0 -> ACCEPTED_NO_DEAL");
        TEST_DBL_EQ(0.0, r.filledPrice, "T11b: deal==0 -> no fabricated fill even with DONE");
        TEST_DBL_EQ(0.0, r.filledVolume, "T11c: deal==0 -> no fabricated fill volume");
    }

    //================================================================
    // T12. Classifier purity: no boolean input, deterministic output.
    //      The signature takes ONLY broker signals (retcode, deal,
    //      volume, requestedVolume) - the OrderSend boolean can never
    //      influence the outcome (D5 fix by construction).
    //================================================================
    {
        ExecutionOutcome o1 = ClassifyOutcome(TRADE_RETCODE_DONE, 1, 0.10, 0.10);
        ExecutionOutcome o2 = ClassifyOutcome(TRADE_RETCODE_DONE, 1, 0.10, 0.10);
        TEST_TRUE(o1 == EXEC_OUTCOME_FILLED, "T12a: deterministic FILLED classification");
        TEST_TRUE(o1 == o2, "T12b: pure function - same inputs, same outcome");
    }

    //================================================================
    // T13. Requested values preserved separately even when the broker
    //      fills at the same price (round-trip fidelity of the record).
    //================================================================
    {
        MqlTradeRequest req = {};
        MqlTradeResult  res = {};
        req.volume = 0.10;
        req.price  = 1.10500;

        res.retcode = TRADE_RETCODE_DONE;
        res.deal    = 1000013;
        res.volume  = 0.10;
        res.price   = 1.10500;

        ExecutionTruthRecord r = CaptureExecutionTruth(req, res, 513);

        TEST_DBL_EQ(1.10500, r.requestedPrice, "T13a: requested price preserved");
        TEST_DBL_EQ(1.10500, r.filledPrice, "T13b: filled price = broker result price");
        TEST_DBL_EQ(0.10, r.requestedVolume, "T13c: requested volume preserved");
        TEST_DBL_EQ(0.10, r.filledVolume, "T13d: filled volume = broker result volume");
    }

    SUITE_END("ExecutionTruth");
    return counters;
}

#endif
