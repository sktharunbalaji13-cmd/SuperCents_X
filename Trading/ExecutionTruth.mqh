//+------------------------------------------------------------------+
//|                          ExecutionTruth.mqh                      |
//|                                      Copyright 2026, SuperCents_X|
//|                                                  Sprint 25B B25-03B |
//+------------------------------------------------------------------+
//  B25-03B - Execution Result Truth: pure capture + classification of
//  the broker-returned MqlTradeResult.
//
//  Truth model (official MQL5 semantics, verified 2026-08-15):
//    - MqlTradeResult.retcode is THE outcome indicator; the OrderSend
//      boolean only means "request accepted into the processing queue".
//    - deal/price/volume are broker-confirmed ONLY when a deal exists;
//      deal==0 means no fill, and no fill is ever fabricated.
//    - requested (MqlTradeRequest) and broker-confirmed (MqlTradeResult)
//      values are kept in separate fields; filled fields never derive
//      from the request.
//
//  The module is PURE infrastructure: no OrderSend, no timers, no
//  file persistence, no callbacks, no retry/reconciliation/ledger
//  logic, no strategy or risk policy.
//+------------------------------------------------------------------+
#ifndef __TRADING_EXECUTION_TRUTH_MQH__
#define __TRADING_EXECUTION_TRUTH_MQH__

enum ExecutionOutcome
{
    EXEC_OUTCOME_UNKNOWN,           // no determination possible (e.g. retcode == 0)
    EXEC_OUTCOME_REJECTED,          // broker or pre-broker rejection
    EXEC_OUTCOME_ACCEPTED_NO_DEAL,  // accepted, no deal confirmed synchronously
    EXEC_OUTCOME_FILLED,            // DONE + deal -> broker-confirmed full fill
    EXEC_OUTCOME_PARTIALLY_FILLED,  // DONE_PARTIAL + deal -> broker-confirmed partial fill
    EXEC_OUTCOME_TIMEOUT,           // TRADE_RETCODE_TIMEOUT (outcome uncertain)
    EXEC_OUTCOME_CONNECTION_ERROR,  // TRADE_RETCODE_CONNECTION (outcome unknown)
    EXEC_OUTCOME_BROKER_ERROR       // retcode outside the known table (raw values preserved)
};

struct ExecutionTruthRecord
{
    ulong            executionPlanId;
    uint             requestId;        // tradeResult.request_id (terminal-assigned)
    uint             retcode;          // tradeResult.retcode
    int              retcodeExternal;  // tradeResult.retcode_external (broker-specific)
    ExecutionOutcome outcome;          // derived classification

    double           requestedPrice;   // request.price  (what we asked)
    double           requestedVolume;  // request.volume (what we asked)
    double           filledPrice;      // tradeResult.price  (broker-confirmed) or 0
    double           filledVolume;     // tradeResult.volume (broker-confirmed) or 0
    ulong            dealTicket;       // tradeResult.deal  or 0
    ulong            orderTicket;      // tradeResult.order or 0
    double           bidAtResult;      // tradeResult.bid   (requote context)
    double           askAtResult;      // tradeResult.ask   (requote context)
    string           brokerComment;    // tradeResult.comment
    datetime         capturedTime;     // capture timestamp
};

//--- Classify the broker outcome from retcode/deal/volume semantics ONLY.
//    The OrderSend boolean is NOT an input and can never influence the
//    outcome. dealVolume/requestedVolume are carried for callers that
//    need partial-fill shortfall context.
ExecutionOutcome ClassifyOutcome(const uint retcode, const ulong dealTicket,
                                 const double dealVolume, const double requestedVolume)
{
    switch(retcode)
    {
        case TRADE_RETCODE_DONE:
            return (dealTicket != 0 ? EXEC_OUTCOME_FILLED : EXEC_OUTCOME_ACCEPTED_NO_DEAL);
        case TRADE_RETCODE_DONE_PARTIAL:
            return (dealTicket != 0 ? EXEC_OUTCOME_PARTIALLY_FILLED : EXEC_OUTCOME_ACCEPTED_NO_DEAL);
        case TRADE_RETCODE_PLACED:
            return EXEC_OUTCOME_ACCEPTED_NO_DEAL;
        case TRADE_RETCODE_REQUOTE:
        case TRADE_RETCODE_REJECT:
        case TRADE_RETCODE_CANCEL:
        case TRADE_RETCODE_ERROR:
        case TRADE_RETCODE_INVALID:
        case TRADE_RETCODE_INVALID_VOLUME:
        case TRADE_RETCODE_INVALID_PRICE:
        case TRADE_RETCODE_INVALID_STOPS:
        case TRADE_RETCODE_TRADE_DISABLED:
        case TRADE_RETCODE_MARKET_CLOSED:
        case TRADE_RETCODE_NO_MONEY:
        case TRADE_RETCODE_PRICE_CHANGED:
        case TRADE_RETCODE_PRICE_OFF:
        case TRADE_RETCODE_INVALID_EXPIRATION:
        case TRADE_RETCODE_ORDER_CHANGED:
        case TRADE_RETCODE_TOO_MANY_REQUESTS:
        case TRADE_RETCODE_NO_CHANGES:
        case TRADE_RETCODE_SERVER_DISABLES_AT:
        case TRADE_RETCODE_CLIENT_DISABLES_AT:
        case TRADE_RETCODE_LOCKED:
        case TRADE_RETCODE_FROZEN:
        case TRADE_RETCODE_INVALID_FILL:
        case TRADE_RETCODE_ONLY_REAL:
        case TRADE_RETCODE_LIMIT_ORDERS:
        case TRADE_RETCODE_LIMIT_VOLUME:
        case TRADE_RETCODE_INVALID_ORDER:
            return EXEC_OUTCOME_REJECTED;
        case TRADE_RETCODE_TIMEOUT:
            return EXEC_OUTCOME_TIMEOUT;
        case TRADE_RETCODE_CONNECTION:
            return EXEC_OUTCOME_CONNECTION_ERROR;
        default:
            return (retcode == 0 ? EXEC_OUTCOME_UNKNOWN : EXEC_OUTCOME_BROKER_ERROR);
    }
}

//--- Write-once capture: every MqlTradeResult field is preserved in the
//    record; filled fields come ONLY from the broker-confirmed result
//    and are zero when no deal is confirmed.
ExecutionTruthRecord CaptureExecutionTruth(const MqlTradeRequest &request,
                                           const MqlTradeResult &result,
                                           const ulong executionPlanId)
{
    ExecutionTruthRecord rec;

    rec.executionPlanId   = executionPlanId;
    rec.requestId         = result.request_id;
    rec.retcode           = result.retcode;
    rec.retcodeExternal   = result.retcode_external;
    rec.outcome           = ClassifyOutcome(result.retcode, result.deal, result.volume, request.volume);

    rec.requestedPrice    = request.price;
    rec.requestedVolume   = request.volume;

    rec.dealTicket        = result.deal;
    rec.orderTicket       = result.order;
    rec.bidAtResult       = result.bid;
    rec.askAtResult       = result.ask;
    rec.brokerComment     = result.comment;
    rec.capturedTime      = TimeCurrent();

    switch(rec.outcome)
    {
        case EXEC_OUTCOME_FILLED:
        case EXEC_OUTCOME_PARTIALLY_FILLED:
            rec.filledPrice  = result.price;
            rec.filledVolume = result.volume;
            break;
        default:
            rec.filledPrice  = 0.0;
            rec.filledVolume = 0.0;
            break;
    }

    return rec;
}

#endif
