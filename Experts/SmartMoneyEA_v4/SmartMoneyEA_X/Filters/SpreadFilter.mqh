//+------------------------------------------------------------------+
//|                                                SmartMoneyEA_X    |
//|                                                SpreadFilter.mqh  |
//|                                       Spread Check Filter        |
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
//| CLASS: SpreadFilter                                              |
//| Purpose: Validates that the current spread is within acceptable   |
//|          limits before allowing trade entries.                   |
//+------------------------------------------------------------------+
class SpreadFilter
{
private:
   Logger            m_logger;           // Module logger
   int               m_maxSpread;        // Maximum allowed spread
   bool              m_initialized;      // Initialization flag

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   SpreadFilter()
   {
      m_logger = Logger("SpreadFilter");
      m_maxSpread = SMA_SPREAD_MAX_DEFAULT;
      m_initialized = false;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                      |
   //+------------------------------------------------------------------+
   ~SpreadFilter()
   {
   }

   //+------------------------------------------------------------------+
   //| Initialize the spread filter                                     |
   //| Returns true on success                                          |
   //+------------------------------------------------------------------+
    bool Init()
    {
       m_logger.Debug("SpreadFilter initialized (max: " + IntegerToString(m_maxSpread) + ")");
       m_initialized = true;
       return true;
    }

   //+------------------------------------------------------------------+
   //| Set the maximum allowed spread in points                         |
   //+------------------------------------------------------------------+
   void SetMaxSpread(int maxSpread)
   {
      m_maxSpread = maxSpread;
   }

   //+------------------------------------------------------------------+
   //| Returns the current maximum spread setting                       |
   //+------------------------------------------------------------------+
   int GetMaxSpread()
   {
      return m_maxSpread;
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
