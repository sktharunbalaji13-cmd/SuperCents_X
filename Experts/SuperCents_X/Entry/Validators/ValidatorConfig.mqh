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

struct ConfluenceConfig
{
    double minConfidence;

    ConfluenceConfig(void)
        : minConfidence(0.6)
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