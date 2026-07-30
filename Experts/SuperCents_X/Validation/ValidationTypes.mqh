#ifndef __VALIDATION_TYPES_MQH__
#define __VALIDATION_TYPES_MQH__

#include "../Optimization/OptimizationTypes.mqh"

struct MetricResult
{
    bool                valid;
    double              value;
    ENUM_METRIC_ORIGIN  origin;

    MetricResult(void)
        : valid(false)
        , value(0.0)
        , origin(ORIGIN_ESTIMATED)
    {}

    MetricResult(double v, ENUM_METRIC_ORIGIN o = ORIGIN_ESTIMATED)
        : valid(true)
        , value(v)
        , origin(o)
    {}
};

// @frozen v2.7 -- Public API. Append values only.
enum ENUM_VALIDATION_EVENT_TYPE
{
    VALIDATION_EVENT_TRADE_CLOSED = 0
};

struct ValidationEventData
{
    int                 eventVersion;
    int                 eventType;
    datetime            timestamp;

    ulong               ticket;
    string              symbol;
    long                positionType;
    double              volume;
    datetime            openedTime;
    datetime            closedTime;

    double              grossProfit;
    double              netProfit;
    double              commission;
    double              swap;
    double              entryPrice;
    double              exitPrice;

    double              stopLoss;
    double              takeProfit;
    double              rrAchieved;
    double              riskPercent;

    bool                hadBOS;
    bool                bosRespected;
    bool                hadOrderBlock;
    bool                obTouched;
    bool                hadFVG;
    bool                fvgFilled;
    double              entryConfidence;
    int                 confluenceScore;

    int                 sessionHour;
    string              sessionName;
    double              atrAtEntry;
    double              spreadAtEntry;

    ValidationEventData(void)
        : eventVersion(1)
        , eventType(VALIDATION_EVENT_TRADE_CLOSED)
        , timestamp(0)
        , ticket(0)
        , symbol("")
        , positionType(-1)
        , volume(0.0)
        , openedTime(0)
        , closedTime(0)
        , grossProfit(0.0)
        , netProfit(0.0)
        , commission(0.0)
        , swap(0.0)
        , entryPrice(0.0)
        , exitPrice(0.0)
        , stopLoss(0.0)
        , takeProfit(0.0)
        , rrAchieved(0.0)
        , riskPercent(0.0)
        , hadBOS(false)
        , bosRespected(false)
        , hadOrderBlock(false)
        , obTouched(false)
        , hadFVG(false)
        , fvgFilled(false)
        , entryConfidence(0.0)
        , confluenceScore(0)
        , sessionHour(0)
        , sessionName("")
        , atrAtEntry(0.0)
        , spreadAtEntry(0.0)
    {}
};

struct TradeOutcome
{
    ulong               ticket;
    string              symbol;
    datetime            closeTime;
    long                direction;
    double              netProfit;
    double              rrAchieved;
    double              riskPercent;
    double              stopPips;
    double              targetPips;

    bool                hadBOS;
    bool                bosRespected;
    bool                hadOrderBlock;
    bool                obTouched;
    bool                hadFVG;
    bool                fvgFilled;
    double              entryConfidence;
    int                 confluenceScore;

    int                 sessionHour;
    string              sessionName;
    double              atrAtEntry;
    double              spreadAtEntry;

    TradeOutcome(void)
        : ticket(0)
        , symbol("")
        , closeTime(0)
        , direction(-1)
        , netProfit(0.0)
        , rrAchieved(0.0)
        , riskPercent(0.0)
        , stopPips(0.0)
        , targetPips(0.0)
        , hadBOS(false)
        , bosRespected(false)
        , hadOrderBlock(false)
        , obTouched(false)
        , hadFVG(false)
        , fvgFilled(false)
        , entryConfidence(0.0)
        , confluenceScore(0)
        , sessionHour(0)
        , sessionName("")
        , atrAtEntry(0.0)
        , spreadAtEntry(0.0)
    {}
};

struct BehavioralMetrics
{
    string              symbol;
    int                 timeframe;
    int                 totalTrades;

    int                 winningTrades;
    int                 losingTrades;
    double              winRate;

    int                 tradesWithBOS;
    int                 bosRespectedCount;
    double              bosAccuracy;

    int                 tradesWithOB;
    int                 obTouchedCount;
    double              obTouchRate;

    int                 tradesWithFVG;
    int                 fvgFilledCount;
    double              fvgFillRate;

    double              avgEntryConfidence;
    double              avgWinConfidence;
    double              avgLossConfidence;

    int                 asianTrades;
    double              asianWinRate;
    int                 londonTrades;
    double              londonWinRate;
    int                 nyTrades;
    double              nyWinRate;

    double              avgDurationSeconds;
    double              avgWinDurationSeconds;
    double              avgLossDurationSeconds;

    BehavioralMetrics(void)
        : symbol("")
        , timeframe(0)
        , totalTrades(0)
        , winningTrades(0)
        , losingTrades(0)
        , winRate(0.0)
        , tradesWithBOS(0)
        , bosRespectedCount(0)
        , bosAccuracy(0.0)
        , tradesWithOB(0)
        , obTouchedCount(0)
        , obTouchRate(0.0)
        , tradesWithFVG(0)
        , fvgFilledCount(0)
        , fvgFillRate(0.0)
        , avgEntryConfidence(0.0)
        , avgWinConfidence(0.0)
        , avgLossConfidence(0.0)
        , asianTrades(0)
        , asianWinRate(0.0)
        , londonTrades(0)
        , londonWinRate(0.0)
        , nyTrades(0)
        , nyWinRate(0.0)
        , avgDurationSeconds(0.0)
        , avgWinDurationSeconds(0.0)
        , avgLossDurationSeconds(0.0)
    {}
};

struct ValidationRequest
{
    string              experimentLabel;
    string              symbols[10];
    int                 symbolCount;
    ENUM_TIMEFRAMES     timeframes[5];
    int                 timeframeCount;
    datetime            testStart;
    datetime            testEnd;
    double              initialDeposit;
    string              parameterSetId;
    int                 randomSeed;
    bool                enableBehavioralMetrics;

    ValidationRequest(void)
        : experimentLabel("")
        , symbolCount(0)
        , timeframeCount(0)
        , testStart(0)
        , testEnd(0)
        , initialDeposit(10000.0)
        , parameterSetId("default")
        , randomSeed(0)
        , enableBehavioralMetrics(true)
    {
        for(int i = 0; i < 10; i++) symbols[i] = "";
        for(int i = 0; i < 5; i++) timeframes[i] = PERIOD_CURRENT;
    }
};

struct ValidationManifest
{
    string              validationId;
    string              eaVersion;
    string              gitCommit;
    datetime            compileTime;
    string              parameterHash;
    string              symbolTested;
    string              timeframeTested;
    double              spreadAvg;
    string              broker;
    string              testerBuild;
    string              mt5Build;

    ValidationManifest(void)
        : validationId("")
        , eaVersion("")
        , gitCommit("")
        , compileTime(0)
        , parameterHash("")
        , symbolTested("")
        , timeframeTested("")
        , spreadAvg(0.0)
        , broker("")
        , testerBuild("")
        , mt5Build("")
    {}
};

// @frozen v2.7 -- Public API contract. Append fields only; no renames or semantic changes.
struct ValidationResult
{
    ValidationManifest  manifest;
    ValidationRequest   request;
    StrategyReport      strategyReport;
    BehavioralMetrics   behavior;
    bool                archived;
    string              archivePath;

    ValidationResult(void)
        : archived(false)
        , archivePath("")
    {}
};

#endif
