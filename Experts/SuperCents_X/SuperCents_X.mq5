//+------------------------------------------------------------------+
//|                                                SuperCents_X.mq5   |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#property copyright "2026, SuperCents_X"
#property link      "https://github.com/"
#property version   "1.00"

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

//--- Global engine instance
CEngine g_engine;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("========================================");
    Print("SuperCents_X EA - Sprint 2 Swing Detection");
    Print("========================================");

    // Initialize the engine
    if(!g_engine.Init())
    {
        Print("ERROR: Failed to initialize engine");
        return INIT_FAILED;
    }

    Print("Engine initialized successfully");
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