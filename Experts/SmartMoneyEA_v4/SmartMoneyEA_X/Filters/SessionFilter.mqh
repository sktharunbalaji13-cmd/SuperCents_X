//+------------------------------------------------------------------+
//|                                                SmartMoneyEA_X    |
//|                                               SessionFilter.mqh  |
//|                                       Trading Session Filter     |
//+------------------------------------------------------------------+
#property copyright "SmartMoneyEA_X"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include "..\Utils\Logger.mqh"
#include "..\Utils\Constants.mqh"

//+------------------------------------------------------------------+
//| CLASS: SessionFilter                                             |
//| Purpose: Validates whether the current time falls within an       |
//|          enabled trading session (Asia, London, New York).       |
//+------------------------------------------------------------------+
class SessionFilter
{
private:
   Logger            m_logger;           // Module logger
   bool              m_initialized;      // Initialization flag

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   SessionFilter()
   {
      m_logger = Logger("SessionFilter");
      m_initialized = false;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                      |
   //+------------------------------------------------------------------+
   ~SessionFilter()
   {
   }

   //+------------------------------------------------------------------+
   //| Initialize the session filter                                    |
   //| Returns true on success                                          |
   //+------------------------------------------------------------------+
    bool Init()
    {
       m_logger.Debug("SessionFilter initialized");
       m_initialized = true;
       return true;
    }

   //+------------------------------------------------------------------+
   //| Returns whether the filter is initialized                        |
   //+------------------------------------------------------------------+
   bool IsInitialized()
   {
      return m_initialized;
   }
};
//+------------------------------------------------------------------+
