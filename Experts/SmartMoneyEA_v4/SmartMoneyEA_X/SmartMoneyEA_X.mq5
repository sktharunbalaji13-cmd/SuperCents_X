//+------------------------------------------------------------------+
//|                                                SmartMoneyEA_X    |
//|                                            SmartMoneyEA_X.mq5    |
//|                         Smart Money Concepts Trading Framework   |
//+------------------------------------------------------------------+
#property copyright "SmartMoneyEA_X"
#property link      ""
#property version   "1.00"
#property description "Smart Money Concepts Expert Advisor Framework"
#property description "Project foundation for SMC-based trading strategies"
#property description "No trading logic included in this version"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include "Core\Engine.mqh"

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
input ENUM_LOG_LEVEL InpLogLevel = LOG_INFO;  // Logging level (0=None, 1=Error, 2=Warning, 3=Info, 4=Debug, 5=Verbose)

Engine *g_engine = NULL;           // Main engine instance
Logger g_logger;                  // Global logger for EA entry points

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//| Called once when the EA is loaded onto a chart                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize global logger
   g_logger = Logger("EA_Main");

   // Print startup banner
   g_logger.Info("========================================================");
   g_logger.Info("  " SMA_PROJECT_NAME " v" SMA_VERSION);
   g_logger.Info("  Author: " SMA_AUTHOR);
   g_logger.Info("  Magic Number: " + IntegerToString(SMA_MAGIC_NUMBER));
   g_logger.Info("  Log Level: " + EnumToString(InpLogLevel));
   g_logger.Info("========================================================");

   // Create and initialize the engine
   g_engine = new Engine();

   if(!g_engine.Init())
   {
      g_logger.Error("Engine initialization failed - unloading EA");
      delete g_engine;
      g_engine = NULL;
      return INIT_FAILED;
   }

   g_logger.Info("[OK] " SMA_PROJECT_NAME " loaded successfully");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//| Called when the EA is removed from the chart                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_logger.Info("Shutting down " SMA_PROJECT_NAME " (reason: " + IntegerToString(reason) + ")");

   if(g_engine != NULL)
   {
      g_engine.Shutdown();
      delete g_engine;
      g_engine = NULL;
   }

   g_logger.Info(SMA_PROJECT_NAME " unloaded successfully");
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//| Called on every new tick from the market                         |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_engine != NULL)
   {
      g_engine.OnTick();
   }
}
//+------------------------------------------------------------------+


