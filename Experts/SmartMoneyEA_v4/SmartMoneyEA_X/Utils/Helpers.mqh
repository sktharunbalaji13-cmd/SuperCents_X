//+------------------------------------------------------------------+
//|                                                SmartMoneyEA_X    |
//|                                                    Helpers.mqh   |
//|                                        Reusable Utility Functions|
//+------------------------------------------------------------------+
#property copyright "SmartMoneyEA_X"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include "Constants.mqh"
#include "Enums.mqh"
#include "Structures.mqh"

//+------------------------------------------------------------------+
//| CLASS: Helpers                                                   |
//| Purpose: Provides reusable utility functions for all modules.    |
//|          Object naming, formatting, and safe deletion helpers.   |
//+------------------------------------------------------------------+
class Helpers
{
public:

   //+------------------------------------------------------------------+
   //| Generate a unique chart object name for a given prefix           |
   //+------------------------------------------------------------------+
   static string GenerateObjectName(string prefix)
   {
      return StringFormat("%s_%d_%d", prefix, GetTickCount(), MathRand());
   }

   //+------------------------------------------------------------------+
   //| Format a price value with the correct number of digits           |
   //+------------------------------------------------------------------+
   static string FormatPrice(double price)
   {
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      return DoubleToString(price, digits);
   }

   //+------------------------------------------------------------------+
   //| Format a time value to a readable string                         |
   //+------------------------------------------------------------------+
   static string FormatTime(datetime time)
   {
      return TimeToString(time, TIME_DATE | TIME_MINUTES);
   }

   //+------------------------------------------------------------------+
   //| Safely delete a chart object by name                             |
   //+------------------------------------------------------------------+
   static bool SafeObjectDelete(string objectName)
   {
      if(ObjectFind(0, objectName) >= 0)
      {
         return ObjectDelete(0, objectName);
      }
      return true; // Object already doesn't exist
   }

   //+------------------------------------------------------------------+
   //| Delete all objects with a given prefix                           |
   //+------------------------------------------------------------------+
   static int DeleteObjectsByPrefix(string prefix)
   {
      int count = 0;
      for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, prefix) == 0)
         {
            if(ObjectDelete(0, name))
               count++;
         }
      }
      return count;
   }

   //+------------------------------------------------------------------+
   //| Check if an object name is within the valid length limit         |
   //+------------------------------------------------------------------+
   static bool IsValidObjectName(string name)
   {
      return StringLen(name) <= SMA_OBJ_NAME_MAX_LEN;
   }

   //+------------------------------------------------------------------+
   //| Format a volume/ lot size correctly                              |
   //+------------------------------------------------------------------+
   static string FormatVolume(double volume)
   {
      return StringFormat("%.2f", volume);
   }

   //+------------------------------------------------------------------+
   //| Convert trade direction to string                                |
   //+------------------------------------------------------------------+
   static string DirectionToString(ENUM_TRADE_DIRECTION dir)
   {
      switch(dir)
      {
         case TRADE_BUY:  return "BUY";
         case TRADE_SELL: return "SELL";
         default:         return "NONE";
      }
   }

   //+------------------------------------------------------------------+
   //| Convert trend state to string                                    |
   //+------------------------------------------------------------------+
   static string TrendToString(ENUM_TREND_STATE trend)
   {
      switch(trend)
      {
         case TREND_BULLISH: return "BULLISH";
         case TREND_BEARISH: return "BEARISH";
         default:            return "UNKNOWN";
      }
   }
};
//+------------------------------------------------------------------+
