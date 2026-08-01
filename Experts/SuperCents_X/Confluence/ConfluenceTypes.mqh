#ifndef __CONFLUENCE_TYPES_MQH__
#define __CONFLUENCE_TYPES_MQH__

#include "SignalTypes.mqh"

#define MAX_CONFLUENCE_COMPONENTS 8
#define MAX_EXPLANATION_LENGTH 512

class CTrendState;
class CBOSDetector;
class CCHOCHDetector;
class COrderBlockDetector;
class CFVGDetector;
class CProtectedPointManager;
class CLiquidityDetector;

enum ENUM_CONFLUENCE_COMPONENT
{
    COMPONENT_STRUCTURE = 0,
    COMPONENT_TREND,
    COMPONENT_ORDER_BLOCK,
    COMPONENT_FVG,
    COMPONENT_LIQUIDITY,
    COMPONENT_PREMIUM_DISCOUNT,
    COMPONENT_COUNT
};

struct ConfluenceComponentResult
{
    ENUM_CONFLUENCE_COMPONENT   type;
    double                      score;
    double                      weight;
    double                      contribution;
    string                      explanation;

    ConfluenceComponentResult(void)
        : type(COMPONENT_STRUCTURE)
        , score(0.0)
        , weight(0.0)
        , contribution(0.0)
        , explanation("")
    {}
};

struct ConfluenceResult
{
    bool                        valid;
    ConfluenceDirection         direction;
    double                      totalConfidence;
    ConfluenceComponentResult   components[MAX_CONFLUENCE_COMPONENTS];
    int                         componentCount;
    string                      summaryExplanation;

    ConfluenceResult(void)
        : valid(false)
        , direction(CONFLUENCE_NONE)
        , totalConfidence(0.0)
        , componentCount(0)
        , summaryExplanation("")
    {}
};

struct DetectionContext
{
    CTrendState            *trendState;
    CBOSDetector           *bosDetector;
    CCHOCHDetector         *chochDetector;
    COrderBlockDetector    *orderBlockDetector;
    CFVGDetector           *fvgDetector;
    CProtectedPointManager *protectedPointManager;
    CLiquidityDetector     *liquidityDetector;

    double                  swingHigh;
    double                  swingLow;
    double                  currentPrice;
    datetime                currentTime;

    DetectionContext(void)
        : trendState(NULL)
        , bosDetector(NULL)
        , chochDetector(NULL)
        , orderBlockDetector(NULL)
        , fvgDetector(NULL)
        , protectedPointManager(NULL)
        , liquidityDetector(NULL)
        , swingHigh(0.0)
        , swingLow(0.0)
        , currentPrice(0.0)
        , currentTime(0)
    {}
};

#endif
