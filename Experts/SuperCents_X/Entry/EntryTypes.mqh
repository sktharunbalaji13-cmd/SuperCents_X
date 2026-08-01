#ifndef __ENTRY_TYPES_MQH__
#define __ENTRY_TYPES_MQH__

#define MAX_ENTRY_FILTERS 12

enum ENUM_FILTER_RESULT
{
    FILTER_PASS = 0,
    FILTER_WARNING,
    FILTER_FAIL
};

enum ENUM_VALIDATOR_CATEGORY
{
    CATEGORY_SETUP = 0,
    CATEGORY_MARKET,
    CATEGORY_ACCOUNT
};

enum ENUM_ENTRY_REJECTION_REASON
{
    REASON_NONE               = 0,
    REASON_DIRECTION_INVALID,
    REASON_CONFIDENCE_LOW,
    REASON_SIGNAL_EXPIRED,
    REASON_SPREAD_TOO_HIGH,
    REASON_SESSION_CLOSED,
    REASON_DISTANCE_TOO_LARGE,
    REASON_COOLDOWN_ACTIVE,
    REASON_RISK_REJECTED,
    REASON_UNKNOWN
};

struct EntryFilterResult
{
    string                      validatorName;
    ENUM_FILTER_RESULT          result;
    ENUM_ENTRY_REJECTION_REASON reason;
    string                      explanation;
    ENUM_VALIDATOR_CATEGORY     category;

    EntryFilterResult(void)
        : result(FILTER_PASS)
        , reason(REASON_NONE)
        , category(CATEGORY_SETUP)
        , explanation("")
    {}
};

struct EntryContext
{
    double   spread;
    datetime now;
    double   currentBid;
    double   currentAsk;
    int      barsSinceSignal;
    double   candidateEntryPrice;

    EntryContext(void)
        : spread(0.0)
        , now(0)
        , currentBid(0.0)
        , currentAsk(0.0)
        , barsSinceSignal(0)
        , candidateEntryPrice(0.0)
    {}
};

#endif
