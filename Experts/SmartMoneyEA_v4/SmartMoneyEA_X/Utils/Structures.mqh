//+------------------------------------------------------------------+
//|                                                SmartMoneyEA_X    |
//|                                                  Structures.mqh  |
//|                                           Project Data Structures|
//+------------------------------------------------------------------+
#property copyright "SmartMoneyEA_X"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include "Enums.mqh"
#include "Constants.mqh"

//+------------------------------------------------------------------+
//| SwingPoint structure                                             |
//| Represents a detected swing high or swing low point              |
//+------------------------------------------------------------------+
struct SwingPoint
{
   datetime          time;                // Bar time of the swing point
   double            price;               // Price of the swing point
   ENUM_TREND_STATE  type;                // TREND_BULLISH for high, TREND_BEARISH for low
   int               barIndex;            // Bar index where the swing was detected
   int               strength;            // Swing confirmation strength (SwingStrength)
   bool              confirmed;           // Whether the swing is fully confirmed
   int               qualityScore;        // Swing quality score (0-100)
   long              volume;              // Volume at the point
   string            objectName;          // Associated chart object name

   //--- Structural Pivot extensions (Sprint 2.75) ---
   bool              isStructuralPivot;   // True when promoted to structural pivot
   double            impulsePoints;       // Measured impulse (price units) â€“ immutable after set
   int               pivotID;             // Unique pivot identifier (0 = not assigned)
};

//+------------------------------------------------------------------+
//| StructureEvent structure                                         |
//| Represents a market structure event (BOS, CHOCH, MSS)           |
//+------------------------------------------------------------------+
struct StructureEvent
{
   datetime               time;            // Event occurrence time
   double                 price;           // Price at the event
   ENUM_OBJECT_TYPE_SMX   type;            // BOS, CHOCH, or MSS
   ENUM_TREND_STATE       direction;       // Bullish or Bearish
   string                 objectName;      // Associated chart object name
   int                    significance;    // Significance level (1-3)
};

//+------------------------------------------------------------------+
//| LiquidityEvent structure                                         |
//| Represents a detected liquidity level (sweep or pool)            |
//+------------------------------------------------------------------+
struct LiquidityEvent
{
   datetime          time;            // Detection time
   double            price;           // Liquidity price level
   double            volume;          // Estimated liquidity volume
   ENUM_TREND_STATE  side;            // Buy-side or sell-side liquidity
   bool              swept;           // Whether liquidity was already swept
   string            objectName;      // Associated chart object name
};

//+------------------------------------------------------------------+
//| OrderBlock structure                                             |
//| Represents an institutional order block zone                     |
//+------------------------------------------------------------------+
struct OrderBlock
{
   datetime           formationTime;    // Time of the OB formation
   double             high;             // Order block high price
   double             low;              // Order block low price
   ENUM_TREND_STATE   type;             // Bullish or Bearish OB
   bool               mitigated;        // Whether the OB was used
   int                strength;         // Strength rating (1-3)
   string             objectName;       // Associated chart object name
};

//+------------------------------------------------------------------+
//| FairValueGap structure                                           |
//| Represents a Fair Value Gap (imbalance) between three candles    |
//+------------------------------------------------------------------+
struct FairValueGap
{
   datetime   formationTime;    // Time of FVG formation
   double     upperPrice;       // Upper boundary of the gap
   double     lowerPrice;       // Lower boundary of the gap
   ENUM_TREND_STATE direction;  // Bullish or Bearish gap
   bool       filled;           // Whether the gap was filled
   double     fillPercent;      // Percentage filled
   string     objectName;       // Associated chart object name
};

//+------------------------------------------------------------------+
//| TradeSignal structure                                            |
//| Represents a validated trade entry signal                        |
//+------------------------------------------------------------------+
struct TradeSignal
{
   datetime               time;            // Signal generation time
   ENUM_TRADE_DIRECTION   direction;       // Buy or Sell
   double                 entryPrice;      // Suggested entry price
   double                 stopLoss;        // Suggested stop loss
   double                 takeProfit1;     // First take profit target
   double                 takeProfit2;     // Second take profit target
   ENUM_SIGNAL_STRENGTH   strength;        // Signal confidence
   bool                   verified;        // Whether signal is verified
   string                 reason;          // Signal rationale description
};

//+------------------------------------------------------------------+
//| TradeRecord structure                                            |
//| Represents a tracked trade for monitoring and management         |
//+------------------------------------------------------------------+
struct TradeRecord
{
   ulong                ticket;           // Order ticket number
   datetime             openTime;         // Order open time
   ENUM_TRADE_DIRECTION direction;        // Trade direction
   double               openPrice;        // Entry price
   double               volume;           // Trade volume
   double               stopLoss;         // Current stop loss
   double               takeProfit;       // Current take profit
   double               profit;           // Current profit/loss
   int                  magicNumber;      // EA magic number
   string               comment;          // Order comment
};

//+------------------------------------------------------------------+
//| BOSEvent structure                                               |
//| Represents a Break of Structure (BOS) event                      |
//+------------------------------------------------------------------+
struct BOSEvent
{
   int         bosID;             // Unique BOS identifier
   int         relatedPivotID;    // Pivot ID that was broken
   ENUM_TREND_STATE direction;    // TREND_BULLISH or TREND_BEARISH
   double      breakPrice;        // Close price that caused the break
   double      pivotPrice;        // Price of the broken pivot
   int         breakBarIndex;     // Bar index where break occurred
   int         pivotBarIndex;     // Bar index of the pivot candle
   datetime    breakTime;         // Time of the break bar
   datetime    pivotTime;         // Time of the pivot bar
   bool        confirmed;         // Always true once stored
   string      objectName;        // Associated chart object name

   //--- Sprint 3.2 BOS Visualization fields ---
   double      breakDistance;     // Break distance in points
   int         barsSincePivot;    // Bars between pivot and break
   double      bufferUsed;        // Buffer threshold in points
   double      closePrice;        // Close price at break
};

//+------------------------------------------------------------------+
//| BOSHistoryRecord structure                                       |
//| Represents a historical BOS event record for the history engine  |
//+------------------------------------------------------------------+
struct BOSHistoryRecord
{
   int                      sequenceNumber;      // Sequential BOS number
   ENUM_TREND_STATE         direction;           // BOS direction
   int                      pivotID;              // Pivot ID that was broken
   double                   pivotPrice;           // Price of broken pivot
   double                   breakPrice;           // Price at break
   datetime                 breakTime;            // Time of break
   ENUM_MARKET_STRUCTURE_STATE previousState;     // Market state before BOS
   ENUM_MARKET_STRUCTURE_STATE newState;           // Market state after BOS
};

//+------------------------------------------------------------------+
//| CHOCHEvent structure                                             |
//| Represents a Change of Character (CHOCH) event                   |
//+------------------------------------------------------------------+
struct CHOCHEvent
{
   bool               valid;              // Event validity flag
   ENUM_TREND_STATE   direction;          // TREND_BULLISH or TREND_BEARISH
   datetime           breakTime;          // Time when CHOCH occurred
   double             breakPrice;         // Price at CHOCH
   int                relatedPivotID;     // Related pivot ID
   ENUM_MARKET_STRUCTURE_STATE previousState; // State before CHOCH
   ENUM_MARKET_STRUCTURE_STATE newState;       // State after CHOCH
   int                sourceBOSEvent;     // BOS sequence that triggered CHOCH
};
//+------------------------------------------------------------------+
