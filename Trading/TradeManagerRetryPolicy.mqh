//+------------------------------------------------------------------+
//|                      TradeManagerRetryPolicy.mqh                 |
//|                                      Copyright 2026, SuperCents_X|
//|                                              Sprint 25B H6 (Rev 2)|
//+------------------------------------------------------------------+
//  H6 retry policy - the single source of truth for the Revision 2
//  retcode -> retry class mapping.
//
//  Pure and deterministic: no broker queries, no time, no account state,
//  no OrderSend.  It is the ONLY place that decides whether a send
//  outcome is recorded (dedup), permanently rejected, retry-eligible, or
//  held pending B25-03C durable reconciliation.
//
//  Boundary (senior decision, Revision 2):
//    - deterministic broker refusal  -> RETRY_ELIGIBLE / REJECT_PERMANENT
//    - uncertain outcome             -> RETRY_HOLD (never auto-retried,
//                                       never rejected, no release until
//                                       B25-03C durable reconciliation)
//    - broker-visible submission     -> RECORD (never retried)
//  Absence of broker evidence NEVER grants retry eligibility.
//+------------------------------------------------------------------+
#ifndef __TRADE_MANAGER_RETRY_POLICY_MQH__
#define __TRADE_MANAGER_RETRY_POLICY_MQH__

enum ENUM_H6_RETRY_POLICY
{
    H6_POLICY_RECORD = 0,         // broker-visible submission -> dedup, never retry
    H6_POLICY_REJECT_PERMANENT,   // deterministic refusal, plan/request defect -> PLAN_REJECTED
    H6_POLICY_RETRY_ELIGIBLE,     // deterministic refusal, transient -> retry on next tick
    H6_POLICY_RETRY_HOLD          // uncertain -> hold, no retry, no reject, B25-03C resolves
};

ENUM_H6_RETRY_POLICY H6ClassifyPolicy(const uint retcode, const ulong dealTicket)
{
    //--- Broker-confirmed execution evidence overrides any retcode.
    if(dealTicket != 0)
        return H6_POLICY_RECORD;

    switch(retcode)
    {
        //--- Broker-visible submission (accepted / executed).
        case TRADE_RETCODE_PLACED:
        case TRADE_RETCODE_DONE:
        case TRADE_RETCODE_DONE_PARTIAL:
            return H6_POLICY_RECORD;

        //--- Deterministic refusal, transient state -> retry eligible.
        //    Each retcode is a proof of non-execution (broker refused for a
        //    stated, mutable condition); no scan is involved.
        case TRADE_RETCODE_REQUOTE:
        case TRADE_RETCODE_REJECT:
        case TRADE_RETCODE_CANCEL:
        case TRADE_RETCODE_PRICE_CHANGED:
        case TRADE_RETCODE_PRICE_OFF:
        case TRADE_RETCODE_MARKET_CLOSED:
        case TRADE_RETCODE_NO_MONEY:
        case TRADE_RETCODE_TOO_MANY_REQUESTS:
        case TRADE_RETCODE_FROZEN:
        case TRADE_RETCODE_LOCKED:
        case TRADE_RETCODE_TRADE_DISABLED:
        case TRADE_RETCODE_SERVER_DISABLES_AT:
        case TRADE_RETCODE_CLIENT_DISABLES_AT:
        case TRADE_RETCODE_LIMIT_ORDERS:
        case TRADE_RETCODE_LIMIT_VOLUME:
            return H6_POLICY_RETRY_ELIGIBLE;

        //--- Deterministic refusal, plan/request defect or immutable
        //    environment -> permanent rejection (never retried).
        case TRADE_RETCODE_INVALID:
        case TRADE_RETCODE_INVALID_VOLUME:
        case TRADE_RETCODE_INVALID_PRICE:
        case TRADE_RETCODE_INVALID_STOPS:
        case TRADE_RETCODE_INVALID_EXPIRATION:
        case TRADE_RETCODE_INVALID_ORDER:
        case TRADE_RETCODE_INVALID_FILL:
        case TRADE_RETCODE_ONLY_REAL:
            return H6_POLICY_REJECT_PERMANENT;

        //--- Uncertain outcomes -> HOLD.  Never auto-retried, never rejected,
        //    no release until B25-03C durable reconciliation.
        //    TIMEOUT        - request may have been processed server-side
        //    CONNECTION     - request may have been processed before link loss
        //    ERROR          - generic; does not demonstrably prove refusal
        //    NO_CHANGES     - may indicate an artifact of an earlier attempt
        //    ORDER_CHANGED  - modification context; ambiguous for a market order
        case TRADE_RETCODE_TIMEOUT:
        case TRADE_RETCODE_CONNECTION:
        case TRADE_RETCODE_ERROR:
        case TRADE_RETCODE_NO_CHANGES:
        case TRADE_RETCODE_ORDER_CHANGED:
            return H6_POLICY_RETRY_HOLD;

        //--- retcode 0 and any retcode outside the known table.
        default:
            return H6_POLICY_RETRY_HOLD;
    }
}

#endif // __TRADE_MANAGER_RETRY_POLICY_MQH__
