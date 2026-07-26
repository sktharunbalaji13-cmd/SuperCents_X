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
    MODULE_LIQUIDITY_DETECTOR,
    MODULE_VISUALIZATION_MANAGER,
    MODULE_PIVOT_RENDERER,
    MODULE_ORDER_BLOCK_RENDERER,
    MODULE_FVG_RENDERER,
    MODULE_CONFLUENCE_ENGINE,
    MODULE_ENTRY_SETUP_BUILDER,
    MODULE_ENTRY_VALIDATOR,
    MODULE_EXECUTION_MANAGER,
    MODULE_POSITION_MANAGER,
    MODULE_TRADE_MANAGER,
    MODULE_ENTRY_DECISION,
    MODULE_EXECUTION_PLANNER,
    MODULE_TRADING,
    MODULE_TRADE_REQUEST_BUILDER,
    MODULE_TRADE_VALIDATION,
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

// FVG classification constants (Phase 1)
#define FVG_CLASS_LOOKBACK_SECONDS (3 * 900)   // 3 M15 bars for recent event lookback
#define FVG_SIZE_SMALL_PIPS  3.0
#define FVG_SIZE_LARGE_PIPS  10.0
#define FVG_STRENGTH_BODY_SMALL_PIPS  5.0
#define FVG_STRENGTH_BODY_LARGE_PIPS  15.0

// Sprint 12: Liquidity constants
#define LIQUIDITY_EQH_TOLERANCE_PIPS   3
#define LIQUIDITY_EQL_TOLERANCE_PIPS   3
#define LIQUIDITY_MAX_LEVELS          256

#endif // __CONSTANTS_MQH__