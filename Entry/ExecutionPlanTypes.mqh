#ifndef __EXECUTION_PLAN_TYPES_MQH__
#define __EXECUTION_PLAN_TYPES_MQH__

#include "../Confluence/SignalTypes.mqh"

enum ExecutionPlanStatus
{
    PLAN_CREATED = 0,
    PLAN_EXECUTABLE,
    PLAN_REJECTED,
    PLAN_REJECTED_PORTFOLIO
};

enum ENUM_ENTRY_POLICY
{
    ENTRY_OB_RETEST = 0,
    ENTRY_FVG_MIDPOINT,
    ENTRY_LIQUIDITY_LEVEL,
    ENTRY_CURRENT_PRICE
};

enum ENUM_STOP_POLICY
{
    STOP_OB_SIDE = 0,
    STOP_LIQUIDITY_SIDE,
    STOP_PROTECTED_POINT,
    STOP_BROKER_MINIMUM
};

enum ENUM_TARGET_POLICY
{
    TARGET_OPPOSING_LIQUIDITY = 0,
    TARGET_OPPOSING_OB,
    TARGET_OPPOSING_FVG,
    TARGET_FIXED_RR,
    TARGET_PREVIOUS_SWING
};

struct ExecutionPlanConfig
{
    ENUM_ENTRY_POLICY   entryPolicy;
    ENUM_STOP_POLICY    stopPolicy;
    ENUM_TARGET_POLICY  targetPolicy;
    double              targetRR;
    double              stopBufferPips;
    double              minStopDistancePips;

    ExecutionPlanConfig(void)
        : entryPolicy(ENTRY_OB_RETEST)
        , stopPolicy(STOP_PROTECTED_POINT)
        , targetPolicy(TARGET_OPPOSING_LIQUIDITY)
        , targetRR(2.0)
        , stopBufferPips(3.0)
        , minStopDistancePips(5.0)
    {}
};

struct ExecutionPlan
{
    int                 entryDecisionId;
    ConfluenceDirection direction;
    ENUM_ORDER_TYPE     orderType;
    ExecutionPlanStatus status;

    double              entryPrice;
    double              stopLoss;
    double              takeProfit;
    double              riskReward;
    double              stopDistance;
    double              targetDistance;

    string              entryPolicyUsed;
    string              stopPolicyUsed;
    string              targetPolicyUsed;
    string              rationale;
    string              rejectionReason;

    //--- C1 (plan identity): the resolution policies (enum) and the
    //    structure-resolved flag, so the plan identity is durably
    //    reconstructible independent of live market price.
    ENUM_ENTRY_POLICY   entryPolicy;
    ENUM_STOP_POLICY    stopPolicy;
    ENUM_TARGET_POLICY  targetPolicy;
    bool                structureResolved;

    datetime            createdTime;
};

#endif
