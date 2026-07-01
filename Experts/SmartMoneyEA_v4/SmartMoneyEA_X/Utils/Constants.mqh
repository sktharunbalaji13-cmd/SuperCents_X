//+------------------------------------------------------------------+
//|                                                SmartMoneyEA_X    |
//|                                                  Constants.mqh   |
//|                                              Project Constants   |
//+------------------------------------------------------------------+
#property copyright "SmartMoneyEA_X"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Include guard                                                    |
//+------------------------------------------------------------------+
#include "Enums.mqh"

//+------------------------------------------------------------------+
//| Project Identification                                           |
//+------------------------------------------------------------------+
#define SMA_PROJECT_NAME        "SmartMoneyEA_X"
#define SMA_VERSION              "1.0.0"
#define SMA_AUTHOR              "SmartMoneyEA_X Team"

//+------------------------------------------------------------------+
//| Magic Numbers & Identifiers                                      |
//+------------------------------------------------------------------+
#define SMA_MAGIC_NUMBER        20240101
#define SMA_MAX_OBJECTS         500

//+------------------------------------------------------------------+
//| Pivot / Swing Configuration                                      |
//+------------------------------------------------------------------+
#define SMA_SWING_STRENGTH      4          // Fractal strength for swing detection
#define SMA_MIN_SWING_DISTANCE  5.0        // Minimum same-type swing distance (points)
#define SMA_MIN_STRUCT_DISTANCE 50.0       // Minimum structural distance (points)
#define SMA_MIN_IMPULSE_POINTS  10.0       // Minimum impulse to promote to structural pivot (points)

//+------------------------------------------------------------------+
//| BOS Configuration                                                |
//+------------------------------------------------------------------+
#define SMA_BOS_BUFFER_POINTS   10.0       // Minimum buffer beyond pivot to confirm BOS (points)
#define SMA_MAX_BOS_EVENTS      500        // Maximum stored BOS events

//+------------------------------------------------------------------+
//| Logging Constants                                                |
//+------------------------------------------------------------------+
#define SMA_LOG_DIR             "Logs\\"
#define SMA_LOG_EXT             ".log"
#define SMA_LOG_MAX_LINES       10000
#define SMA_LOG_LEVEL           LOG_INFO

//+------------------------------------------------------------------+
//| Object Name Prefixes                                             |
//+------------------------------------------------------------------+
#define SMA_OBJ_PREFIX          "SMX_"
#define SMA_OBJ_SWING           "SMX_SW_"
#define SMA_OBJ_BOS             "SMX_BOS_"
#define SMA_OBJ_CHOCH           "SMX_CH_"
#define SMA_OBJ_MSS             "SMX_MSS_"
#define SMA_OBJ_OB              "SMX_OB_"
#define SMA_OBJ_FVG             "SMX_FVG_"
#define SMA_OBJ_LIQ             "SMX_LIQ_"
#define SMA_OBJ_DB              "SMX_DB_"

//+------------------------------------------------------------------+
//| Colors                                                           |
//+------------------------------------------------------------------+
#define SMA_COL_BULLISH         clrGreen
#define SMA_COL_BEARISH         clrRed
#define SMA_COL_NEUTRAL         clrGray
#define SMA_COL_BG              clrBlack
#define SMA_COL_TEXT            clrWhite
#define SMA_COL_SWING           clrBlue
#define SMA_COL_BOS             clrOrange
#define SMA_COL_CHOCH           clrMagenta
#define SMA_COL_MSS             clrYellow
#define SMA_COL_OB_BULLISH      clrDodgerBlue
#define SMA_COL_OB_BEARISH      clrCrimson
#define SMA_COL_FVG             clrLime
#define SMA_COL_LIQ             clrGold
#define SMA_COL_DB_BG           clrDarkSlateGray

//+------------------------------------------------------------------+
//| Drawing Defaults                                                 |
//+------------------------------------------------------------------+
#define SMA_LINE_WIDTH          2
#define SMA_LINE_STYLE          STYLE_SOLID
#define SMA_ARROW_SIZE          1
#define SMA_LABEL_FONT          "Arial"
#define SMA_LABEL_SIZE          10

//+------------------------------------------------------------------+
//| Session Time Constants (UTC Hours)                               |
//+------------------------------------------------------------------+
#define SMA_SESSION_ASIA_START    0
#define SMA_SESSION_ASIA_END      9
#define SMA_SESSION_LONDON_START  8
#define SMA_SESSION_LONDON_END    17
#define SMA_SESSION_NY_START      13
#define SMA_SESSION_NY_END        22

//+------------------------------------------------------------------+
//| Spread & Slippage Defaults                                       |
//+------------------------------------------------------------------+
#define SMA_SPREAD_MAX_DEFAULT  30
#define SMA_SLIPPAGE_DEFAULT    10

//+------------------------------------------------------------------+
//| Object Name Length Limit                                         |
//+------------------------------------------------------------------+
#define SMA_OBJ_NAME_MAX_LEN    63

//+------------------------------------------------------------------+
//| DEBUG Configuration                                               |
//+------------------------------------------------------------------+
#define SMA_DEBUG                false        // Enable BOS debug labels on chart

