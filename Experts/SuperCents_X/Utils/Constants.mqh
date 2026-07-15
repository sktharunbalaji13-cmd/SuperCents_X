//+------------------------------------------------------------------+
//|                                               Constants.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __CONSTANTS_MQH__
#define __CONSTANTS_MQH__

// Module identifiers for logging
enum ENUM_MODULE_ID
{
    MODULE_ENGINE = 0,
    MODULE_SWING_DETECTOR,
    MODULE_BOS_DETECTOR,
    MODULE_CHOCH_DETECTOR,
    MODULE_TREND_STATE,
    MODULE_ENTRY_ENGINE,
    MODULE_RISK_MANAGER,
    MODULE_SWING_RENDERER,
    MODULE_BOS_RENDERER,
    MODULE_CHOCH_RENDERER,
    MODULE_PROTECTED_RENDERER,
    MODULE_PROTECTED_POINT_MANAGER,
    MODULE_ORDER_BLOCK_DETECTOR,
    MODULE_FVG_DETECTOR,
    MODULE_UNKNOWN
};

// Log levels
enum ENUM_LOG_LEVEL
{
    LOG_LEVEL_DEBUG = 0,
    LOG_LEVEL_INFO,
    LOG_LEVEL_WARN,
    LOG_LEVEL_ERROR
};

// Swing detection parameters
#define SWING_STRENGTH 2
#define SWING_LOOKBACK_BARS SWING_STRENGTH

// BOS detection constants
#define BOS_LOOKBACK_BARS 2

// CHOCH detection constants
#define CHOCH_LOOKBACK_BARS 1

// FVG detection constants
#define FVG_MIN_BODY_SIZE_PIPS 5

#endif // __CONSTANTS_MQH__