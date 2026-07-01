//+------------------------------------------------------------------+
//|                                                SmartMoneyEA_X    |
//|                                              EntryValidator.mqh  |
//|                                        Trade Entry Validation    |
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
//| CLASS: EntryValidator                                            |
//| Purpose: Validates trade entry signals against all active         |
//|          filters (spread, session, structure confluence).         |
//+------------------------------------------------------------------+
class EntryValidator
{
private:
   Logger            m_logger;           // Module logger
   bool              m_initialized;      // Initialization flag

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   EntryValidator()
   {
      m_logger = Logger("EntryValidator");
      m_initialized = false;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                      |
   //+------------------------------------------------------------------+
   ~EntryValidator()
   {
   }

   //+------------------------------------------------------------------+
   //| Initialize the entry validator                                   |
   //| Returns true on success                                          |
   //+------------------------------------------------------------------+
    bool Init()
    {
       m_logger.Debug("EntryValidator initialized");
       m_initialized = true;
       return true;
    }

   //+------------------------------------------------------------------+
   //| Returns whether the validator is initialized                     |
   //+------------------------------------------------------------------+
   bool IsInitialized()
   {
      return m_initialized;
   }
};
//+------------------------------------------------------------------+
