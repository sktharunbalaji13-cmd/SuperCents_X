//+------------------------------------------------------------------+
//|                                                SmartMoneyEA_X    |
//|                                                    Enums.mqh     |
//|                                                 Project Enums    |
//+------------------------------------------------------------------+
#property copyright "SmartMoneyEA_X"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Trend State enumeration                                          |
//| Represents the current detected trend direction                   |
//+------------------------------------------------------------------+
enum ENUM_TREND_STATE
  {
   TREND_UNKNOWN  = 0,  // Trend state not yet determined
   TREND_BULLISH  = 1,  // Upward trend detected
   TREND_BEARISH  = 2   // Downward trend detected
  };

//+------------------------------------------------------------------+
//| Log Level enumeration                                            |
//| Defines severity levels for the project logger                   |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
  {
   LOG_NONE    = 0,  // No logging
   LOG_ERROR   = 1,  // Error messages (critical)
   LOG_WARNING = 2,  // Warning messages (non-critical)
   LOG_INFO    = 3,  // Informational messages
   LOG_DEBUG   = 4,  // Debug-level messages
   LOG_VERBOSE = 5   // Verbose diagnostic messages
  };

//+------------------------------------------------------------------+
//| Market State enumeration                                         |
//| Represents the current market phase                               |
//+------------------------------------------------------------------+
enum ENUM_MARKET_STATE
  {
   MARKET_UNKNOWN    = 0,  // Market state unknown
   MARKET_TRENDING   = 1,  // Market in trending phase
   MARKET_RANGING    = 2,  // Market in ranging/consolidation phase
   MARKET_TRANSITION = 3   // Market transitioning between states
  };

//+------------------------------------------------------------------+
//| Chart Object Types enumeration                                   |
//| Identifies the type of drawn chart objects                        |
//+------------------------------------------------------------------+
enum ENUM_OBJECT_TYPE_SMX
  {
   OBJ_SWING      = 0,  // Swing High/Low point
   OBJ_BOS        = 1,  // Break of Structure
   OBJ_CHOCH      = 2,  // Change of Character
   OBJ_MSS        = 3,  // Market Structure Shift
   OBJ_ORDERBLOCK = 4,  // Order Block
   OBJ_FVG        = 5,  // Fair Value Gap
   OBJ_LIQUIDITY  = 6   // Liquidity Level
  };

//+------------------------------------------------------------------+
//| Trade Direction enumeration                                      |
//| Defines possible trading directions                               |
//+------------------------------------------------------------------+
enum ENUM_TRADE_DIRECTION
  {
   TRADE_BUY  = 0,  // Buy (Long) direction
   TRADE_SELL = 1,  // Sell (Short) direction
   TRADE_NONE = 2   // No trade / neutral
  };

//+------------------------------------------------------------------+
//| Signal Strength enumeration                                      |
//| Defines the strength classification of a generated signal        |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_STRENGTH
  {
   SIGNAL_WEAK      = 0,  // Weak confidence signal
   SIGNAL_MODERATE  = 1,  // Moderate confidence signal
   SIGNAL_STRONG    = 2,  // Strong confidence signal
   SIGNAL_VERIFIED  = 3   // Verified / confirmed signal
  };

//+------------------------------------------------------------------+
//| Market Structure State enumeration                               |
//| Represents the current market structure state based on BOS events|
//+------------------------------------------------------------------+
enum ENUM_MARKET_STRUCTURE_STATE
  {
   MS_UNKNOWN              = 0,  // Initial state - structure not yet determined
   MS_BULLISH              = 1,  // Bullish market structure confirmed
   MS_BEARISH              = 2,  // Bearish market structure confirmed
   MS_TRANSITION_TO_BULLISH = 3, // Transitioning from bearish to bullish
   MS_TRANSITION_TO_BEARISH = 4 // Transitioning from bullish to bearish
  };
//+------------------------------------------------------------------+
