#ifndef __TRADE_EXECUTION_RESULT_MQH__
#define __TRADE_EXECUTION_RESULT_MQH__

struct TradeExecutionResult
{
    ulong       executionPlanId;
    bool        submitted;
    ulong       ticket;
    uint        retcode;
    string      retcodeDescription;
    double      filledPrice;
    double      filledVolume;
    datetime    executionTime;
    string      rationale;

    TradeExecutionResult(void)
        : executionPlanId(0)
        , submitted(false)
        , ticket(0)
        , retcode(0)
        , retcodeDescription("")
        , filledPrice(0.0)
        , filledVolume(0.0)
        , executionTime(0)
        , rationale("")
    {}
};

#endif