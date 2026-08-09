//+------------------------------------------------------------------+
//|                                              RenderConfig.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __RENDER_CONFIG_MQH__
#define __RENDER_CONFIG_MQH__

input bool ShowSwings          = true;
input bool ShowPivots          = true;
input bool ShowBOS             = true;
input bool ShowCHOCH           = true;
input bool ShowProtectedPoints = true;
input bool ShowOrderBlocks     = true;
input bool ShowFVG             = true;
input bool ShowLiquidity       = true;

// Historical limits (delete oldest beyond this count)
input int  MaxHistoricalSwings = 50;
input int  MaxHistoricalPivots = 50;
input int  MaxHistoricalBOS    = 30;
input int  MaxHistoricalCHOCH  = 30;
input int  MaxHistoricalPP     = 20;
input int  MaxHistoricalOB     = 20;
input int  MaxHistoricalFVG    = 30;
input int  MaxHistoricalLiquidity = 30;

// Protected Point behavior
input bool ShowInactiveProtectedPoints = false;

// Label collision avoidance
input bool CompactLabels                = true;

// CHOCH label mode (NONE = no label, SIMPLE = "CHOCH", DIRECTION = "BULL/BEAR CHOCH", DEBUG = "BULL/BEAR #ID")
enum ENUM_CHOCH_LABEL_MODE
{
    CHOCH_LABEL_NONE      = 0,
    CHOCH_LABEL_SIMPLE    = 1,
    CHOCH_LABEL_DIRECTION = 2,
    CHOCH_LABEL_DEBUG     = 3
};
input ENUM_CHOCH_LABEL_MODE CHOCHLabelMode = CHOCH_LABEL_DIRECTION;

// CHOCH label position (START = near Protected Point, MIDPOINT = center of diagonal, END = near Break Candle)
enum ENUM_CHOCH_LABEL_POSITION
{
    CHOCH_LABEL_AT_START     = 0,
    CHOCH_LABEL_AT_MIDPOINT  = 1,
    CHOCH_LABEL_AT_END       = 2
};
input ENUM_CHOCH_LABEL_POSITION CHOCHLabelPosition = CHOCH_LABEL_AT_START;

// BOS label mode (NONE = no label, SIMPLE = "BOS", DIRECTION = "BULL/BEAR BOS", DEBUG = "BULL/BEAR BOS #ID")
enum ENUM_BOS_LABEL_MODE
{
    BOS_LABEL_NONE      = 0,
    BOS_LABEL_SIMPLE    = 1,
    BOS_LABEL_DIRECTION = 2,
    BOS_LABEL_DEBUG     = 3
};
input ENUM_BOS_LABEL_MODE BOSLabelMode = BOS_LABEL_DIRECTION;

// BOS label position (START = near broken pivot, MIDPOINT = center of line, END = near break candle)
enum ENUM_BOS_LABEL_POSITION
{
    BOS_LABEL_AT_START     = 0,
    BOS_LABEL_AT_MIDPOINT  = 1,
    BOS_LABEL_AT_END       = 2
};
input ENUM_BOS_LABEL_POSITION BOSLabelPosition = BOS_LABEL_AT_START;

// EQH/EQL label mode (NONE = no label, SIMPLE = "EQH"/"EQL", DIRECTION = "BUY EQH"/"SELL EQL", DEBUG = side + "#ID")
enum ENUM_LIQUIDITY_LABEL_MODE
{
    LIQUIDITY_LABEL_NONE      = 0,
    LIQUIDITY_LABEL_SIMPLE    = 1,
    LIQUIDITY_LABEL_DIRECTION = 2,
    LIQUIDITY_LABEL_DEBUG     = 3
};
input ENUM_LIQUIDITY_LABEL_MODE LiquidityLabelMode = LIQUIDITY_LABEL_DIRECTION;

// Render Window (bars) — only render swings within this many bars from current
input int SwingRenderHistoryBars = 300;

// Render Window (bars) — only render EQH/EQL levels formed within this many bars from current
input int LiquidityRenderHistoryBars = 300;

#endif // __RENDER_CONFIG_MQH__
