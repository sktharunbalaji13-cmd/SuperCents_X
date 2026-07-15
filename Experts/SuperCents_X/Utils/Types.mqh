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
    int         chochId;
    double      qualityScore;
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