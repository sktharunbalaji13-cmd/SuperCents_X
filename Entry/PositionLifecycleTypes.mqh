#ifndef __POSITION_LIFECYCLE_TYPES_MQH__
#define __POSITION_LIFECYCLE_TYPES_MQH__

enum PositionState
{
    POS_STATE_DISCOVERED = 0,
    POS_STATE_OPEN,
    POS_STATE_BREAK_EVEN,
    POS_STATE_TRAILING,
    POS_STATE_PARTIAL,
    POS_STATE_EXIT_PENDING,
    POS_STATE_CLOSED
};

struct PositionContext
{
    ulong    ticket;
    ulong    executionPlanId;
    ulong    candidateId;
    int      entryDecisionId;
    PositionState state;

    double   entryPrice;
    double   initialStop;
    double   currentStop;
    double   currentTarget;
    double   lastVolume;

    bool     breakEvenApplied;
    bool     trailingActive;
    //--- P44 (evidence, shadow-only): first-touch latch for hypothetical BE
    //    observation. Logging only; exits unchanged; BE stays disabled.
    bool     beShadowLogged;

    datetime openedTime;
    datetime lastUpdateTime;
    datetime closedTime;

    PositionContext(void)
        : ticket(0)
        , executionPlanId(0)
        , candidateId(0)
        , entryDecisionId(0)
        , state(POS_STATE_DISCOVERED)
        , entryPrice(0.0)
        , initialStop(0.0)
        , currentStop(0.0)
        , currentTarget(0.0)
        , lastVolume(0.0)
        , breakEvenApplied(false)
        , trailingActive(false)
        , beShadowLogged(false)
        , openedTime(0)
        , lastUpdateTime(0)
        , closedTime(0)
    {}
};

#endif
