#ifndef __VALIDATOR_CONFIG_MQH__
#define __VALIDATOR_CONFIG_MQH__

#define MAX_SESSION_RANGES 8

struct SessionRange
{
    int startHour;
    int endHour;

    SessionRange(void)
        : startHour(0)
        , endHour(0)
    {}
};

//--- GR01: per-family admission floors.  Evidence-calibrated defaults
//    (frozen Sprint 17 funnel analysis, docs/Sprint20_GR01_Decision.md):
//    LIQUIDITY 0.60 (worst family; E5 falsification - no floor beats base,
//    rejects the 0.2453 tail), BOS/CHOCH 0.35 (above-base families; higher
//    floors discard samples for noise-level gains), FVG 0.35 (0.40 excluded
//    the better tail at wr 0.3521), UNKNOWN 0.35 (0.60 rejected the better
//    evaluator cluster).  ORDER_BLOCK reserved (no rule maps to it).
//    Global minConfidence stays the legacy evaluator/replay gate.
struct ConfluenceConfig
{
    double minConfidence;               // global legacy gate (ReplayDecision); NOT the UNKNOWN floor
    double familyFloorLiquidity;        // RULE_FAMILY_LIQUIDITY
    double familyFloorFVG;              // RULE_FAMILY_FVG
    double familyFloorOrderBlock;       // RULE_FAMILY_ORDER_BLOCK (reserved)
    double familyFloorBOS;              // RULE_FAMILY_BOS
    double familyFloorCHOCH;            // RULE_FAMILY_CHOCH
    double familyFloorUnknown;          // RULE_FAMILY_UNKNOWN / evaluator path

    ConfluenceConfig(void)
        : minConfidence(0.60)
        , familyFloorLiquidity(0.60)
        , familyFloorFVG(0.35)
        , familyFloorOrderBlock(0.35)
        , familyFloorBOS(0.35)
        , familyFloorCHOCH(0.35)
        , familyFloorUnknown(0.35)
    {}
};

struct FreshnessConfig
{
    int maxAgeBars;

    FreshnessConfig(void)
        : maxAgeBars(3)
    {}
};

struct SpreadConfig
{
    double maxSpreadPips;

    SpreadConfig(void)
        : maxSpreadPips(15.0)
    {}
};

struct SessionConfig
{
    SessionRange ranges[MAX_SESSION_RANGES];
    int          count;

    SessionConfig(void)
        : count(0)
    {}

    void Add(int start, int end)
    {
        if(count < MAX_SESSION_RANGES)
        {
            ranges[count].startHour = start;
            ranges[count].endHour   = end;
            count++;
        }
    }
};

struct DistanceConfig
{
    double maxDistance;

    DistanceConfig(void)
        : maxDistance(0.0050)
    {}
};

struct CooldownConfig
{
    int minBarsSinceLastTrade;

    CooldownConfig(void)
        : minBarsSinceLastTrade(5)
    {}
};

struct RiskValidatorConfig
{
    double minLots;
    double maxLots;

    RiskValidatorConfig(void)
        : minLots(0.01)
        , maxLots(10.0)
    {}
};

struct ValidatorConfig
{
    ConfluenceConfig confluence;
    FreshnessConfig  freshness;
    SpreadConfig     spread;
    SessionConfig    session;
    DistanceConfig   distance;
    CooldownConfig   cooldown;
    RiskValidatorConfig risk;
};

#endif