//+------------------------------------------------------------------+
//|                                               EntrySetup.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __ENTRY_SETUP_MQH__
#define __ENTRY_SETUP_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Structure/TrendState.mqh"

enum ENUM_SETUP_TYPE
{
    SETUP_NONE = 0,
    SETUP_BOS_CONTINUATION,
    SETUP_CHOCH_REVERSAL,
    SETUP_ORDERBLOCK_RETEST,
    SETUP_FVG_CONTINUATION
};

enum ENUM_ENTRY_STATE
{
    ENTRY_STATE_IDLE = 0,
    ENTRY_STATE_ARMED,
    ENTRY_STATE_FILLED,
    ENTRY_STATE_CANCELLED,
    ENTRY_STATE_EXPIRED
};

struct EntrySetup
{
    bool            valid;
    ENUM_SETUP_TYPE type;
    Trend           direction;
    double          entryPrice;
    double          stopLoss;
    double          takeProfit;
    double          confluenceScore;
    double          riskRewardRatio;
    datetime        signalTime;

    int bosId;
    int chochId;
    int obId;
    int fvgId;
    int protectedPointId;

    bool Matches(const EntrySetup &other) const
    {
        return type == other.type
            && direction == other.direction
            && signalTime == other.signalTime
            && bosId == other.bosId
            && chochId == other.chochId
            && obId == other.obId
            && fvgId == other.fvgId
            && protectedPointId == other.protectedPointId;
    }
};

//+------------------------------------------------------------------+
//| Execution result and status types                                 |
//+------------------------------------------------------------------+

enum ENUM_EXECUTION_STATUS
{
    EXEC_STATUS_PENDING = 0,
    EXEC_STATUS_ACCEPTED,
    EXEC_STATUS_REJECTED_INVALID_SETUP,
    EXEC_STATUS_REJECTED_OPEN_POSITION,
    EXEC_STATUS_REJECTED_PENDING_ORDER,
    EXEC_STATUS_REJECTED_TRADING_DISABLED,
    EXEC_STATUS_REJECTED_VOLUME_INVALID,
    EXEC_STATUS_REJECTED_STOPS_INVALID,
    EXEC_STATUS_REJECTED_MARGIN_INSUFFICIENT,
    EXEC_STATUS_REJECTED_BROKER,
    EXEC_STATUS_REJECTED_SYMBOL_INVALID,
    EXEC_STATUS_ERROR_UNKNOWN
};

struct ExecutionResult
{
    bool                 success;
    ulong                orderTicket;
    ulong                dealTicket;
    ENUM_EXECUTION_STATUS status;
    uint                 retcode;
    string               description;

    ExecutionResult(void)
        : success(false)
        , orderTicket(0)
        , dealTicket(0)
        , status(EXEC_STATUS_PENDING)
        , retcode(0)
        , description("") {}
};

#endif
