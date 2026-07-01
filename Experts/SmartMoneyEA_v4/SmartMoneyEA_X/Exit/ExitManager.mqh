//+------------------------------------------------------------------+
//|                                                SmartMoneyEA_X    |
//|                                                 ExitManager.mqh  |
//|                                      Trade Exit Management       |
//+------------------------------------------------------------------+
#property copyright "SmartMoneyEA_X"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include "..\Utils\Logger.mqh"
#include "..\Utils\Structures.mqh"
#include "..\Utils\Enums.mqh"

//+------------------------------------------------------------------+
//| CLASS: ExitManager                                               |
//| Purpose: Manages trade exit strategies including take profit     |
//|          targets, trailing stops, and breakeven management.      |
//+------------------------------------------------------------------+
class ExitManager
{
private:
   Logger            m_logger;           // Module logger
   bool              m_initialized;      // Initialization flag

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   ExitManager()
   {
      m_logger = Logger("ExitManager");
      m_initialized = false;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                      |
   //+------------------------------------------------------------------+
   ~ExitManager()
   {
   }

   //+------------------------------------------------------------------+
   //| Initialize the exit manager                                      |
   //| Returns true on success                                          |
   //+------------------------------------------------------------------+
    bool Init()
    {
       m_logger.Debug("ExitManager initialized");
       m_initialized = true;
       return true;
    }

   //+------------------------------------------------------------------+
   //| Returns whether the manager is initialized                       |
   //+------------------------------------------------------------------+
   bool IsInitialized()
   {
      return m_initialized;
   }
};
//+------------------------------------------------------------------+
