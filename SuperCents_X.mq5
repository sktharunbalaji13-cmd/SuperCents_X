//+------------------------------------------------------------------+
//|                                                SuperCents_X.mq5   |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#property copyright "2026, SuperCents_X"
#property link      "https://github.com/"
#property version   "3.00"

//--- Include headers
#include "Utils/Types.mqh"
#include "Utils/Constants.mqh"
#include "Utils/Helpers.mqh"
#include "Utils/MathUtils.mqh"
#include "Core/Logger.mqh"
#include "Core/Config.mqh"
#include "Core/Engine.mqh"
#include "Structure/SwingDetector.mqh"
#include "Structure/StructuralPivotEngine.mqh"
#include "Structure/BOSDetector.mqh"
#include "Structure/CHOCHDetector.mqh"
#include "Structure/OrderBlockDetector.mqh"
#include "Structure/TrendState.mqh"
#include "Structure/ProtectedPointManager.mqh"
#include "Visualization/SwingRenderer.mqh"
#include "Visualization/BOSRenderer.mqh"
#include "Visualization/CHOCHRenderer.mqh"
#include "Visualization/ProtectedRenderer.mqh"
#include "Confluence/ConfluenceEngine.mqh"
#include "Entry/EntrySetup.mqh"
#include "Entry/EntrySetupBuilder.mqh"
#include "Entry/EntryValidator.mqh"
#include "Entry/EntryEngine.mqh"
#include "Entry/RiskManager.mqh"
#include "Entry/ExecutionManager.mqh"
#include "Entry/PositionLifecycleManager.mqh"
#include "Trading/TradeExecutionResult.mqh"
#include "Trading/TradeRequestBuilder.mqh"
#include "Trading/TradeValidation.mqh"
#include "Trading/TradeManager.mqh"
#include "Entry/EntryConfig.mqh"

//--- Input parameters
input ENUM_ENTRY_MODE EntryMode = ENTRY_MODE_LEGACY;
//--- ED01-D prerequisite: replay outcome simulator TP arm (fixed-RR default,
//    opposing-liquidity selectable for the experiment). Inert in LEGACY.
input ENUM_OUTCOME_TP_MODE OutcomeTpMode = OUTCOME_TP_FIXED_RR;
//--- ED01-E prerequisite: fixed-RR TP tier in R-multiples (default 2.0R =
//    B8 legacy; the tier sweep overrides per run). Inert in LEGACY.
input double FixedRRTier = 2.0;
//--- Sprint 22 (RL-HYP-01) prerequisite: swing-significance admission gate
//    tier k in k x ATR(14) (frozen protocol §5/§14). 0.0 = OFF (B8
//    behavior); the experiment tiers override per run. Inert in LEGACY.
input double SwingSignificanceTier = 0.0;

//--- v2.9: calibrated confluence weights (Sprint 14 Calibration).
input double WeightStructure       = 25.0;   // Weight: Structure
input double WeightOrderBlock      = 20.0;   // Weight: Order Block
input double WeightFVG             = 15.0;   // Weight: FVG
input double WeightLiquidity       = 15.0;   // Weight: Liquidity
input double WeightTrend           = 15.0;   // Weight: Trend
input double WeightPremiumDiscount = 10.0;   // Weight: Premium/Discount

//--- Global engine instance
CEngine g_engine;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- B25-01: additive runtime identity line (mirrors the suite's
    //    >>> BUILD pattern; the TT01 harness records it opportunistically).
    Print(">>> BUILD 25B-PROD-01 tag=\"" + TimeToString(__DATETIME__, TIME_DATE | TIME_MINUTES | TIME_SECONDS)
          + "\" term=" + IntegerToString(TerminalInfoInteger(TERMINAL_BUILD))
          + " path=" + MQLInfoString(MQL_PROGRAM_PATH));

    Print("========================================");
    Print("SuperCents_X EA - Sprint 14 (v2.9)");
    Print("========================================");

    //--- v2.9: push calibrated weights into the engine before init so
    //    every symbol context applies them to the ConfluenceEngine.
    ConfluenceWeights w;
    w.structure       = WeightStructure;
    w.orderBlock      = WeightOrderBlock;
    w.fvg             = WeightFVG;
    w.liquidity       = WeightLiquidity;
    w.trend           = WeightTrend;
    w.premiumDiscount = WeightPremiumDiscount;
    if(!w.IsValid())
    {
        Print("ERROR: Confluence weights must sum to 100 (got " +
              DoubleToString(w.structure + w.orderBlock + w.fvg + w.liquidity + w.trend + w.premiumDiscount, 1) + ")");
        return INIT_PARAMETERS_INCORRECT;
    }
    g_engine.SetWeights(w);
    Print("Confluence weights: " + w.ToString());

    // Set entry engine mode
    g_engine.SetEntryMode(EntryMode);

    //--- ED01-D prerequisite: outcome TP mode (applied to the primary
    //    context during engine Init; FixedRR keeps the B8 baseline).
    g_engine.SetOutcomeTpMode(OutcomeTpMode);

    //--- ED01-E prerequisite: fixed-RR TP tier (default 2.0R keeps the
    //    B8 settle-time behavior; the tier sweep overrides per run).
    g_engine.SetFixedRrTier(FixedRRTier);

    //--- Sprint 22 (RL-HYP-01) prerequisite: swing-significance admission
    //    gate tier (default 0.0 = OFF keeps B8; the experiment tiers
    //    override per run).
    g_engine.SetSwingSignificanceTier(SwingSignificanceTier);

    // Initialize the engine
    if(!g_engine.Init())
    {
        Print("ERROR: Failed to initialize engine");
        return INIT_FAILED;
    }

    Print("Engine initialized successfully");

    if(EntryMode != ENTRY_MODE_LEGACY)
        Print("Entry Engine running in " + EnumToString(EntryMode) + " mode");

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Update the engine on each tick
    g_engine.Update();
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Deinitializing SuperCents_X EA...");

    // Shutdown the engine
    g_engine.Shutdown();

    Print("SuperCents_X EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert chart event function                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                 const long &lparam,
                 const double &dparam,
                 const string &sparam)
{
    // Sprint 1: No chart events handled yet
}

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Sprint 1: No timer events handled yet
}