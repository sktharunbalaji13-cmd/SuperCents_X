//+------------------------------------------------------------------+
//|                                                SuperCents_X.mqh |
//|                                      Copyright 2026, SuperCents_X |
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __TYPES_MQH__
#define __TYPES_MQH__

//--- Sprint 2: Swing Point data structure
struct SwingPoint
{
    int         id;
    datetime    time;
    double      price;
    int         barIndex;
    bool        isHigh;
};

//--- Sprint 3: Structural Pivot data structure
struct StructuralPivot
{
    int         id;
    int         swingID;
    datetime    time;
    double      price;
    int         barIndex;
    bool        isHigh;
    bool        isProtected;
    bool        isBroken;
};

//--- Sprint 4: BOS Event struct (immutable)
struct BOSEvent
{
    int         id;
    int         brokenPivotID;
    bool        bullish;
    datetime    breakTime;
    int         breakBar;
    double      pivotPrice;
    double      closePrice;
};

//--- Sprint 6: Protected Point struct
struct ProtectedPoint
{
    int         id;
    int         pivotID;
    bool        isHigh;
    datetime    time;          // Pivot formation time
    double      price;
    int         barIndex;
    bool        active;
    datetime    activationTime;  // When this point became active (trend change)
};

//--- Sprint 7: CHOCH Event struct
struct CHOCHEvent
{
    int         id;
    int         protectedPointID;
    bool        bullish;
    datetime    time;
    double      breakPrice;
    int         barIndex;
};

//--- Sprint 8: Order Block struct
struct OrderBlock
{
    int         id;
    int         chochID;
    bool        bullish;
    datetime    time;
    double      open;
    double      high;
    double      low;
    double      close;
    int         candleIndex;
    bool        mitigated;
    bool        invalidated;
    double      qualityScore;
};

//--- FVG classification enums
enum FVGClass
{
    FVG_CLASS_UNKNOWN      = 0,
    FVG_CLASS_BREAKAWAY    = 1,
    FVG_CLASS_CONTINUATION = 2,
    FVG_CLASS_REVERSAL     = 3
};

enum FVGSizeCategory
{
    FVG_SIZE_UNKNOWN = 0,
    FVG_SIZE_SMALL,
    FVG_SIZE_MEDIUM,
    FVG_SIZE_LARGE
};

enum FVGStrength
{
    FVG_STRENGTH_UNKNOWN = 0,
    FVG_STRENGTH_WEAK,
    FVG_STRENGTH_NORMAL,
    FVG_STRENGTH_STRONG
};

//--- Sprint 9: Fair Value Gap struct
struct FairValueGap
{
    int         id;
    bool        bullish;
    datetime    time;
    int         candleIndex;
    double      upper;
    double      lower;
    bool        filled;
    datetime    fillTime;
    bool        invalidated;
    int         chochId;
    double      qualityScore;

    // Phase 1 classification (populated by ClassifyFVG)
    int         fvgClass;            // FVGClass enum
    int         classEventId;        // BOS or CHOCH ID that triggered classification
    int         classEventType;      // 1=BOS, 2=CHOCH
    double      gapSizePips;         // gap size in pips
    int         sizeCategory;        // FVGSizeCategory enum
    int         strength;            // FVGStrength enum
    double      displacementBodyPips;// displacement candle body in pips
};

//--- Sprint 12: Liquidity enums
enum LiquidityType
{
    LIQUIDITY_UNKNOWN     = 0,
    LIQUIDITY_EQH,            // Equal Highs
    LIQUIDITY_EQL,            // Equal Lows
    LIQUIDITY_EXTERNAL_HH,    // External buy-side (beyond swing high)
    LIQUIDITY_EXTERNAL_LL,    // External sell-side (beyond swing low)
    LIQUIDITY_INTERNAL_HH,    // Internal buy-side
    LIQUIDITY_INTERNAL_LL     // Internal sell-side
};

enum LiquidityClass
{
    LIQUIDITY_CLASS_UNKNOWN  = 0,
    LIQUIDITY_CLASS_BUY_SIDE,
    LIQUIDITY_CLASS_SELL_SIDE
};

enum LiquidityStatus
{
    LIQUIDITY_STATUS_UNKNOWN = 0,
    LIQUIDITY_STATUS_ACTIVE,
    LIQUIDITY_STATUS_SWEPT,
    LIQUIDITY_STATUS_MITIGATED,
    LIQUIDITY_STATUS_INVALIDATED
};

enum LiquidityOrigin
{
    LIQUIDITY_ORIGIN_UNKNOWN      = 0,
    LIQUIDITY_ORIGIN_EQH,
    LIQUIDITY_ORIGIN_EQL,
    LIQUIDITY_ORIGIN_SWING_HIGH,
    LIQUIDITY_ORIGIN_SWING_LOW,
    LIQUIDITY_ORIGIN_EXTERNAL_HIGH,
    LIQUIDITY_ORIGIN_EXTERNAL_LOW,
    LIQUIDITY_ORIGIN_INTERNAL_HIGH,
    LIQUIDITY_ORIGIN_INTERNAL_LOW
};

//--- Sprint 12: Liquidity Level struct
struct LiquidityLevel
{
    int      id;
    datetime time;
    double   price;
    double   averagePrice;
    int      memberCount;

    LiquidityType   type;
    LiquidityClass  classification;
    LiquidityStatus status;
    LiquidityOrigin origin;

    int      leftSwingId;
    int      rightSwingId;
    string   memberIdStr;

    bool     swept;
    bool     mitigated;
    bool     invalidated;

    datetime detectedTime;
    int      detectedBar;
    datetime sweptTime;
    int      sweptBar;
    datetime mitigatedTime;
    int      mitigatedBar;
    double   mitigatedPrice;
    datetime invalidatedTime;
    int      invalidatedBar;
    double   invalidatedPrice;
    string   invalidatedReason;
};

//--- Legacy Swing struct (for future SMC components)
struct Swing
{
    int id;
    datetime time;
    double price;
    bool isHigh;
    bool isProtected;
    bool isBroken;
    bool isStructural;
};

struct BOS
{
    int id;
    int swingID;
    datetime breakTime;
    double breakPrice;
    bool bullish;
};

struct CHOCH
{
    int id;
    int bosID;
    datetime time;
    bool bullish;
};

#endif // __TYPES_MQH__