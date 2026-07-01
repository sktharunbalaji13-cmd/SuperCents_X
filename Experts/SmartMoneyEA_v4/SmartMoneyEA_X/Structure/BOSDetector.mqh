//+------------------------------------------------------------------+
//|                                                SmartMoneyEA_X    |
//|                                                  BOSDetector.mqh |
//|                                    Break of Structure Engine v3.2 |
//+------------------------------------------------------------------+
#property copyright "SmartMoneyEA_X"
#property link      ""
#property version   "1.00"

#include "..\Utils\Logger.mqh"
#include "..\Utils\Structures.mqh"
#include "..\Utils\Constants.mqh"
#include "..\Utils\Helpers.mqh"

//+------------------------------------------------------------------+
//| CLASS: BOSDetector                                               |
//| Purpose: Detects and validates Break of Structure (BOS) events  |
//|          with full visualization and debug capabilities          |
//+------------------------------------------------------------------+
class BOSDetector
{
private:
   //--- Configuration
   enum { MAX_BOS_EVENTS = 500, MAX_PIVOT_MAP = 1000 };
   
   //--- Dependencies
   SwingDetector *m_swingDetector;
   Logger         m_logger;
   
   //--- State
   bool           m_initialized;
   int            m_lastBarCount;
   bool           m_initialScanDone;
   
   //--- BOS Storage (bounded arrays)
   BOSEvent       m_bosEvents[];
   int            m_bosCount;
   int            m_bosIDCounter;
   
   //--- Runtime Statistics
   int            m_statTotalStructuralHighs;
   int            m_statTotalStructuralLows;
   int            m_statBullishBOS;
   int            m_statBearishBOS;
   int            m_statRejectedBOS;
   int            m_statDuplicatePrevention;
   int            m_statBufferFailures;
   int            m_statConsumedPivots;
   
   //--- Pivot consumption tracking (O(1) lookup)
   bool           m_pivotConsumedMap[];
   int            m_pivotMapSize;
   
   //+------------------------------------------------------------------+
   //| Check if this is a new bar                                       |
   //+------------------------------------------------------------------+
   bool IsNewBar()
   {
      int cur = Bars(_Symbol, _Period);
      if(cur != m_lastBarCount)
      {
         m_lastBarCount = cur;
         return true;
      }
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize pivot consumption map                                 |
   //+------------------------------------------------------------------+
   void InitPivotMap()
   {
      ArrayResize(m_pivotConsumedMap, MAX_PIVOT_MAP);
      ArrayInitialize(m_pivotConsumedMap, false);
      m_pivotMapSize = MAX_PIVOT_MAP;
   }
   
   //+------------------------------------------------------------------+
   //| Mark pivot as consumed (O(1) operation)                          |
   //+------------------------------------------------------------------+
    void MarkPivotConsumed(int pivotID)
    {
       if(pivotID > 0 && pivotID < m_pivotMapSize)
       {
          // SPRINT 4.3: Check for duplicate consumption
          if(m_pivotConsumedMap[pivotID])
          {
             m_logger.Error("ERROR: Pivot already consumed | ID=" + IntegerToString(pivotID));
          }
          
          m_pivotConsumedMap[pivotID] = true;
          m_logger.Debug("Pivot consumed | ID=" + IntegerToString(pivotID));
       }
    }
   
   //+------------------------------------------------------------------+
   //| Check if pivot is already consumed (O(1) lookup)                 |
   //+------------------------------------------------------------------+
   bool IsPivotConsumed(int pivotID)
   {
      if(pivotID > 0 && pivotID < m_pivotMapSize)
      {
         return m_pivotConsumedMap[pivotID];
      }
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check for duplicate BOS on same pivot                            |
   //+------------------------------------------------------------------+
   bool IsDuplicateBOS(int pivotID, ENUM_TREND_STATE direction)
   {
      for(int i = 0; i < m_bosCount; i++)
      {
         if(m_bosEvents[i].relatedPivotID == pivotID && 
            m_bosEvents[i].direction == direction)
         {
            return true;
         }
      }
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Validate all BOS rules - returns rejection reason or empty       |
   //+------------------------------------------------------------------+
   string ValidateBOSRules(const SwingPoint &pivot, int breakBarIndex, double breakPrice, double bufferPoints)
   {
      // Rule 1: Structural Pivot exists
      if(!pivot.isStructuralPivot)
      {
         return "Structural pivot does not exist";
      }
      
      // Rule 2: Pivot confirmed
      if(!pivot.confirmed)
      {
         return "Pivot not confirmed";
      }
      
      // Rule 3: Pivot not consumed
      if(IsPivotConsumed(pivot.pivotID))
      {
         m_statConsumedPivots++;
         return "Pivot already consumed";
      }
      
      // Rule 4: Close breaks pivot
      bool breaksPivot = false;
      if(pivot.type == TREND_BULLISH && breakPrice > pivot.price)
         breaksPivot = true;
      else if(pivot.type == TREND_BEARISH && breakPrice < pivot.price)
         breaksPivot = true;
      
      if(!breaksPivot)
      {
         return "Close does not break pivot";
      }
      
      // Rule 5: Buffer satisfied
      double breakDistance = MathAbs(breakPrice - pivot.price);
      double breakDistancePoints = breakDistance / _Point;
      
      if(breakDistancePoints < bufferPoints)
      {
         m_statBufferFailures++;
         return StringFormat("Buffer not satisfied (%.1f < %.1f points)", 
                            breakDistancePoints, bufferPoints);
      }
      
      // Rule 6: Body close only (use close price, not wick)
      // This is implicitly satisfied by using breakPrice parameter
      
      // Rule 7: Candle closed
      int currentBar = Bars(_Symbol, _Period);
      if(breakBarIndex != currentBar - 1)
      {
         return "Candle not yet closed";
      }
      
      // Rule 8: BOS not duplicated
      if(IsDuplicateBOS(pivot.pivotID, pivot.type))
      {
         m_statDuplicatePrevention++;
         return "Duplicate BOS detected";
      }
      
      // All rules passed
      return "";
   }
   
   //+------------------------------------------------------------------+
   //| Generate BOS object name                                         |
   //+------------------------------------------------------------------+
   string MakeBOSObjectName(int bosID, int pivotID)
   {
      return StringFormat("%sBOS%d_PIVOT%d", SMA_OBJ_BOS, bosID, pivotID);
   }
   
   //+------------------------------------------------------------------+
   //| Draw BOS horizontal line from pivot to break candle              |
   //+------------------------------------------------------------------+
   void DrawBOSLine(const BOSEvent &bos)
   {
      string lineName = bos.objectName + "_LINE";
      string labelName = bos.objectName + "_LABEL";
      string debugName = bos.objectName + "_DEBUG";
      
      // Delete existing objects
      Helpers::SafeObjectDelete(lineName);
      Helpers::SafeObjectDelete(labelName);
      Helpers::SafeObjectDelete(debugName);
      
      datetime pivotTime = iTime(_Symbol, _Period, bos.pivotBarIndex);
      datetime breakTime = iTime(_Symbol, _Period, bos.breakBarIndex);
      
      // Draw horizontal line from pivot candle to break candle
      ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, bos.pivotPrice);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, 
                      (bos.direction == TREND_BULLISH) ? SMA_COL_BULLISH : SMA_COL_BEARISH);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, SMA_LINE_WIDTH);
       ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      
      // Set time range for the line (from pivot to break)
      ObjectSetInteger(0, lineName, OBJPROP_TIME, pivotTime);
      
      // Draw main BOS label
      string directionStr = (bos.direction == TREND_BULLISH) ? "BULLISH BOS" : "BEARISH BOS";
      string labelText = StringFormat("%s\nBOS#%d | PIVOT#%d", 
                                     directionStr, bos.bosID, bos.relatedPivotID);
      
      double labelOffset = (bos.direction == TREND_BULLISH) ? 15.0 * _Point : -15.0 * _Point;
      ObjectCreate(0, labelName, OBJ_TEXT, 0, breakTime, bos.breakPrice + labelOffset);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, SMA_LABEL_SIZE);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, 
                      (bos.direction == TREND_BULLISH) ? SMA_COL_BULLISH : SMA_COL_BEARISH);
      ObjectSetInteger(0, labelName, OBJPROP_BACK, true);
      
       // Draw debug labels if DEBUG mode enabled
       if(SMA_DEBUG)
          DrawDebugLabels(bos, debugName);
   }
   
   //+------------------------------------------------------------------+
   //| Draw debug labels showing detailed BOS information               |
   //+------------------------------------------------------------------+
   void DrawDebugLabels(const BOSEvent &bos, string debugName)
   {
      string debugText = StringFormat(
         "PivotID: %d\n"
         "Pivot Price: %s\n"
         "Break Price: %s\n"
         "Break Distance: %.1f pts\n"
         "Bars Since Pivot: %d\n"
         "Close Price: %s\n"
         "Buffer: %.1f pts",
         bos.relatedPivotID,
         Helpers::FormatPrice(bos.pivotPrice),
         Helpers::FormatPrice(bos.breakPrice),
         bos.breakDistance,
         bos.barsSincePivot,
         Helpers::FormatPrice(bos.closePrice),
         bos.bufferUsed
      );
      
      double debugOffset = (bos.direction == TREND_BULLISH) ? 35.0 * _Point : -35.0 * _Point;
      ObjectCreate(0, debugName, OBJ_TEXT, 0, bos.breakTime, bos.breakPrice + debugOffset);
      ObjectSetString(0, debugName, OBJPROP_TEXT, debugText);
      ObjectSetInteger(0, debugName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, debugName, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, debugName, OBJPROP_BACK, true);
   }
   
    //+------------------------------------------------------------------+
    //| Log BOS detection                                                 |
    //+------------------------------------------------------------------+
     void LogBOSDetected(const BOSEvent &bos)
     {
        string directionStr = (bos.direction == TREND_BULLISH) ? "BULLISH" : "BEARISH";
        m_logger.Info("========================================================");
        m_logger.Info("BOS DETECTED: " + directionStr);
        m_logger.Info("========================================================");
        m_logger.Info("BOS ID: BOS-" + IntegerToString(bos.bosID));
        m_logger.Info("Pivot ID: PIVOT-" + IntegerToString(bos.relatedPivotID));
        m_logger.Info("Break Price: " + Helpers::FormatPrice(bos.breakPrice));
        m_logger.Info("Pivot Price: " + Helpers::FormatPrice(bos.pivotPrice));
        m_logger.Info("Break Distance: " + DoubleToString(bos.breakDistance / _Point, 1) + " points");
        m_logger.Info("Break Time: " + TimeToString(bos.breakTime));
        m_logger.Info("Bars Since Pivot: " + IntegerToString(bos.barsSincePivot));
        m_logger.Info("Buffer Used: " + DoubleToString(bos.bufferUsed / _Point, 1) + " points");
        m_logger.Info("========================================================");
        
        // SPRINT 4.3: Log BOS lifecycle for validation
        m_logger.Info("BOS LIFECYCLE | BOS#" + IntegerToString(bos.bosID) + 
                     " | PivotID=" + IntegerToString(bos.relatedPivotID) +
                     " | Direction=" + directionStr +
                     " | BreakTime=" + TimeToString(bos.breakTime) +
                     " | StateMachine=NOTIFIED");
        
        //--- SPRINT 4.8: TASK 2 - Log BOS pivot consumption ---
        m_logger.Info("BOS CONSUMED PIVOT");
        m_logger.Info("Pivot ID: PIVOT-" + IntegerToString(bos.relatedPivotID));
        m_logger.Info("Pivot Type: " + directionStr);
        m_logger.Info("Pivot Price: " + Helpers::FormatPrice(bos.pivotPrice));
        m_logger.Info("Break Price: " + Helpers::FormatPrice(bos.breakPrice));
        m_logger.Info("Break Time: " + TimeToString(bos.breakTime));
        m_logger.Info("Consumed Successfully: YES");
     }
   
   //+------------------------------------------------------------------+
   //| Log BOS rejection                                                 |
   //+------------------------------------------------------------------+
    void LogBOSRejected(const SwingPoint &pivot, int breakBarIndex, string reason)
    {
       m_statRejectedBOS++;
       m_logger.Debug(StringFormat("BOS REJECTED | PivotID: %d | Bar: %d | Reason: %s",
                                  pivot.pivotID, breakBarIndex, reason));
       
       // SPRINT 4.3: Log pivot rejection for audit
       m_logger.Info("PIVOT LIFECYCLE | PivotID=" + IntegerToString(pivot.pivotID) + 
                    " | Bar=" + IntegerToString(pivot.barIndex) +
                    " | Status=REJECTED" +
                    " | Reason=" + reason);
    }
   
    //+------------------------------------------------------------------+
    //| SPRINT 5.1.9: Track BOS creation with timestamp diagnostics      |
    //+------------------------------------------------------------------+
    void TrackBOSCreation(const BOSEvent &bos, const SwingPoint &selectedPivot, bool isHistorical)
    {
       // Log BOS creation details
       string source = isHistorical ? "Historical" : "Runtime";
       m_logger.Error("BOS Created [" + source + "]:");
       m_logger.Error("  BOS#: " + IntegerToString(bos.bosID));
       m_logger.Error("  PivotID: PIVOT-" + IntegerToString(bos.relatedPivotID));
       m_logger.Error("  Pivot Time: " + TimeToString(bos.pivotTime));
       m_logger.Error("  Pivot Bar: " + IntegerToString(bos.pivotBarIndex));
       m_logger.Error("  Pivot Price: " + Helpers::FormatPrice(bos.pivotPrice));
       m_logger.Error("  Break Time: " + TimeToString(bos.breakTime));
       m_logger.Error("  Break Bar: " + IntegerToString(bos.breakBarIndex));
       m_logger.Error("  Direction: " + ((bos.direction == TREND_BULLISH) ? "BULLISH" : "BEARISH"));
       
       // SPRINT 5.1.10: TASK 3 - Timestamp Verification at BOSEvent creation
       datetime pivotTimeFromBar = iTime(_Symbol, _Period, bos.pivotBarIndex);
       bool timestampMatch = (bos.pivotTime == pivotTimeFromBar);
       m_logger.Error("TASK 3 - TIMESTAMP VERIFICATION:");
       m_logger.Error("  Pivot Time (stored): " + TimeToString(bos.pivotTime));
       m_logger.Error("  iTime(Symbol(), Period(), pivotBarIndex): " + TimeToString(pivotTimeFromBar));
       m_logger.Error("  Match: " + (timestampMatch ? "PASS" : "FAIL"));
       
       if(!timestampMatch)
       {
          m_logger.Error("  ERROR: Pivot timestamp mismatch detected!");
          m_logger.Error("  Difference (seconds): " + IntegerToString((int)(bos.pivotTime - pivotTimeFromBar)));
       }
    }
   
    //+------------------------------------------------------------------+
    //| Store BOS event in bounded array                                 |
    //+------------------------------------------------------------------+
    void StoreBOSEvent(const BOSEvent &bos)
    {
       // Check if array is full
       if(m_bosCount >= MAX_BOS_EVENTS)
       {
          // Shift array left (remove oldest)
          for(int i = 0; i < m_bosCount - 1; i++)
          {
             m_bosEvents[i] = m_bosEvents[i + 1];
          }
          m_bosCount--;
       }
       
       // Resize if needed
       if(ArraySize(m_bosEvents) <= m_bosCount)
       {
          ArrayResize(m_bosEvents, m_bosCount + 10);
       }
       
        // SPRINT 5.1.10: TASK 4 - Stored BOS Verification
        m_logger.Error("TASK 4 - STORED BOS VERIFICATION (BOS#" + IntegerToString(bos.bosID) + "):");
        
        // Store event
        m_bosEvents[m_bosCount] = bos;
        
        // Verify stored values match (use copy, MQL5 doesn't support references)
        BOSEvent stored = m_bosEvents[m_bosCount];
        bool pivotTimeMatch = (stored.pivotTime == bos.pivotTime);
        bool pivotBarMatch = (stored.pivotBarIndex == bos.pivotBarIndex);
        bool pivotIDMatch = (stored.relatedPivotID == bos.relatedPivotID);
        
        m_logger.Error("  stored.pivotTime == bos.pivotTime: " + (pivotTimeMatch ? "PASS" : "FAIL"));
        m_logger.Error("  stored.pivotBar == bos.pivotBar: " + (pivotBarMatch ? "PASS" : "FAIL"));
        m_logger.Error("  stored.relatedPivotID == bos.relatedPivotID: " + (pivotIDMatch ? "PASS" : "FAIL"));
        
        if(!pivotTimeMatch || !pivotBarMatch || !pivotIDMatch)
        {
           m_logger.Error("  ERROR: Storage corruption detected!");
           if(!pivotTimeMatch)
           {
              m_logger.Error("    pivotTime: stored=" + TimeToString(stored.pivotTime) + 
                            " expected=" + TimeToString(bos.pivotTime));
           }
           if(!pivotBarMatch)
           {
              m_logger.Error("    pivotBar: stored=" + IntegerToString(stored.pivotBarIndex) + 
                            " expected=" + IntegerToString(bos.pivotBarIndex));
           }
           if(!pivotIDMatch)
           {
              m_logger.Error("    pivotID: stored=" + IntegerToString(stored.relatedPivotID) + 
                            " expected=" + IntegerToString(bos.relatedPivotID));
           }
        }
       
       m_bosCount++;
       
       // Update statistics
       if(bos.direction == TREND_BULLISH)
          m_statBullishBOS++;
       else
          m_statBearishBOS++;
    }
   
   //+------------------------------------------------------------------+
   //| Find latest structural pivot of given type                       |
   //+------------------------------------------------------------------+
   SwingPoint FindLatestStructuralPivot(ENUM_TREND_STATE type)
   {
      SwingPoint empty = {0};
      
      if(type == TREND_BULLISH)
      {
         // Search from most recent swing high backwards
         for(int i = m_swingDetector.GetSwingHighCount() - 1; i >= 0; i--)
         {
            SwingPoint sp = m_swingDetector.GetSwingHigh(i);
            if(sp.isStructuralPivot && !IsPivotConsumed(sp.pivotID))
            {
               return sp;
            }
         }
      }
      else
      {
         // Search from most recent swing low backwards
         for(int i = m_swingDetector.GetSwingLowCount() - 1; i >= 0; i--)
         {
            SwingPoint sp = m_swingDetector.GetSwingLow(i);
            if(sp.isStructuralPivot && !IsPivotConsumed(sp.pivotID))
            {
               return sp;
            }
         }
      }
      
      return empty;
   }
   
   //+------------------------------------------------------------------+
   //| Scan for BOS on new bar                                          |
   //+------------------------------------------------------------------+
   void ScanForBOS()
   {
      if(!m_initialized || !m_initialScanDone) return;
      
      int currentBar = Bars(_Symbol, _Period);
      int breakBarIndex = currentBar - 1; // Most recent closed bar
      
      if(breakBarIndex < 0) return;
      
      double closePrice = iClose(_Symbol, _Period, breakBarIndex);
      double bufferPoints = SMA_BOS_BUFFER_POINTS * _Point;
      
      // Check for bullish BOS (break above structural high)
      SwingPoint latestHigh = FindLatestStructuralPivot(TREND_BULLISH);
      if(latestHigh.time != 0)
      {
         // Validate all rules
         string rejectionReason = ValidateBOSRules(latestHigh, breakBarIndex, closePrice, bufferPoints);
         
         if(rejectionReason == "")
         {
            // BOS confirmed - create event
            BOSEvent bos;
            bos.bosID = ++m_bosIDCounter;
            bos.relatedPivotID = latestHigh.pivotID;
            bos.direction = TREND_BULLISH;
            bos.breakPrice = closePrice;
            bos.pivotPrice = latestHigh.price;
            bos.breakBarIndex = breakBarIndex;
            bos.pivotBarIndex = latestHigh.barIndex;
            bos.breakTime = iTime(_Symbol, _Period, breakBarIndex);
            bos.pivotTime = latestHigh.time;
            bos.confirmed = true;
            bos.objectName = MakeBOSObjectName(bos.bosID, bos.relatedPivotID);
            bos.breakDistance = MathAbs(closePrice - latestHigh.price);
            bos.barsSincePivot = breakBarIndex - latestHigh.barIndex;
            bos.bufferUsed = bufferPoints;
            bos.closePrice = closePrice;
            
            // SPRINT 5.1.9: Track BOS creation
            TrackBOSCreation(bos, latestHigh, false);
            
             // SPRINT 5.1.10: TASK 2 - Assignment Audit
             m_logger.Error("TASK 2 - ASSIGNMENT AUDIT (BOS#" + IntegerToString(bos.bosID) + "):");
             m_logger.Error("  File: BOSDetector.mqh");
             m_logger.Error("  Function: ScanForBOS()");
             m_logger.Error("  Line: ~449");
             m_logger.Error("  Statement: bos.pivotTime = latestHigh.time;");
             m_logger.Error("  Value: " + TimeToString(bos.pivotTime));
             m_logger.Error("  Source: latestHigh.time = " + TimeToString(latestHigh.time));
             m_logger.Error("  Match: " + ((bos.pivotTime == latestHigh.time) ? "PASS" : "FAIL"));
             
             // Store and visualize
             StoreBOSEvent(bos);
             DrawBOSLine(bos);
             LogBOSDetected(bos);
             
             // Mark pivot as consumed
             MarkPivotConsumed(latestHigh.pivotID);
            
            //--- SPRINT 4.8: Track pivot lifecycle ---
            if(m_swingDetector != NULL)
            {
               m_swingDetector.IncrementSPHBroken();
            }
         }
         else
         {
            LogBOSRejected(latestHigh, breakBarIndex, rejectionReason);
         }
      }
      
      // Check for bearish BOS (break below structural low)
      SwingPoint latestLow = FindLatestStructuralPivot(TREND_BEARISH);
      if(latestLow.time != 0)
      {
         // Validate all rules
         string rejectionReason = ValidateBOSRules(latestLow, breakBarIndex, closePrice, bufferPoints);
         
         if(rejectionReason == "")
         {
            // BOS confirmed - create event
            BOSEvent bos;
            bos.bosID = ++m_bosIDCounter;
            bos.relatedPivotID = latestLow.pivotID;
            bos.direction = TREND_BEARISH;
            bos.breakPrice = closePrice;
            bos.pivotPrice = latestLow.price;
            bos.breakBarIndex = breakBarIndex;
            bos.pivotBarIndex = latestLow.barIndex;
            bos.breakTime = iTime(_Symbol, _Period, breakBarIndex);
            bos.pivotTime = latestLow.time;
            bos.confirmed = true;
            bos.objectName = MakeBOSObjectName(bos.bosID, bos.relatedPivotID);
            bos.breakDistance = MathAbs(closePrice - latestLow.price);
            bos.barsSincePivot = breakBarIndex - latestLow.barIndex;
            bos.bufferUsed = bufferPoints;
            bos.closePrice = closePrice;
            
            // SPRINT 5.1.9: Track BOS creation
            TrackBOSCreation(bos, latestLow, false);
            
             // SPRINT 5.1.10: TASK 2 - Assignment Audit
             m_logger.Error("TASK 2 - ASSIGNMENT AUDIT (BOS#" + IntegerToString(bos.bosID) + "):");
             m_logger.Error("  File: BOSDetector.mqh");
             m_logger.Error("  Function: ScanForBOS()");
             m_logger.Error("  Line: ~499");
             m_logger.Error("  Statement: bos.pivotTime = latestLow.time;");
             m_logger.Error("  Value: " + TimeToString(bos.pivotTime));
             m_logger.Error("  Source: latestLow.time = " + TimeToString(latestLow.time));
             m_logger.Error("  Match: " + ((bos.pivotTime == latestLow.time) ? "PASS" : "FAIL"));
             
             // Store and visualize
             StoreBOSEvent(bos);
             DrawBOSLine(bos);
             LogBOSDetected(bos);
             
             // Mark pivot as consumed
             MarkPivotConsumed(latestLow.pivotID);
            
            //--- SPRINT 4.8: Track pivot lifecycle ---
            if(m_swingDetector != NULL)
            {
               m_swingDetector.IncrementSPLBroken();
            }
         }
         else
         {
            LogBOSRejected(latestLow, breakBarIndex, rejectionReason);
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Initial historical scan                                          |
   //+------------------------------------------------------------------+
   void InitialScan()
   {
      if(!m_initialized) return;
      
       int totalBars = Bars(_Symbol, _Period);
       int scanStart = 4 + 2;  // SWING_STRENGTH = 4
       int scanEnd = totalBars - 4 - 2;  // SWING_STRENGTH = 4
      
      if(scanEnd < scanStart) return;
      
       m_logger.Debug("Starting BOS initial scan...");
      
       // Scan each closed bar from OLDEST to NEWEST (decrementing MQL5 index)
       // MQL5: bar 0 = newest, bar N-1 = oldest
       // Decrementing loop: oldest bars first, moving forward in time
       for(int barIndex = scanEnd; barIndex >= scanStart; barIndex--)
      {
         double closePrice = iClose(_Symbol, _Period, barIndex);
         double bufferPoints = SMA_BOS_BUFFER_POINTS * _Point;
         
         // Check bullish BOS
         SwingPoint latestHigh = FindLatestStructuralPivotAtBar(TREND_BULLISH, barIndex);
         if(latestHigh.time != 0 && !IsPivotConsumed(latestHigh.pivotID))
         {
            string rejectionReason = ValidateBOSRulesHistorical(latestHigh, barIndex, closePrice, bufferPoints);
            
            if(rejectionReason == "")
            {
               BOSEvent bos;
               bos.bosID = ++m_bosIDCounter;
               bos.relatedPivotID = latestHigh.pivotID;
               bos.direction = TREND_BULLISH;
               bos.breakPrice = closePrice;
               bos.pivotPrice = latestHigh.price;
               bos.breakBarIndex = barIndex;
               bos.pivotBarIndex = latestHigh.barIndex;
               bos.breakTime = iTime(_Symbol, _Period, barIndex);
               bos.pivotTime = latestHigh.time;
               bos.confirmed = true;
               bos.objectName = MakeBOSObjectName(bos.bosID, bos.relatedPivotID);
               bos.breakDistance = MathAbs(closePrice - latestHigh.price);
               bos.barsSincePivot = latestHigh.barIndex - barIndex;
               bos.bufferUsed = bufferPoints;
               bos.closePrice = closePrice;
               
                // SPRINT 5.1.10: TASK 2 - Assignment Audit
                m_logger.Error("TASK 2 - ASSIGNMENT AUDIT (BOS#" + IntegerToString(bos.bosID) + "):");
                m_logger.Error("  File: BOSDetector.mqh");
                m_logger.Error("  Function: InitialScan()");
                m_logger.Error("  Line: ~569");
                m_logger.Error("  Statement: bos.pivotTime = latestHigh.time;");
                m_logger.Error("  Value: " + TimeToString(bos.pivotTime));
                m_logger.Error("  Source: latestHigh.time = " + TimeToString(latestHigh.time));
                m_logger.Error("  Match: " + ((bos.pivotTime == latestHigh.time) ? "PASS" : "FAIL"));
                
                // SPRINT 5.1.9: Track BOS creation
                TrackBOSCreation(bos, latestHigh, true);
                
                // SPRINT 5.1.12: Temporary chronology verification
                if(bos.pivotTime > bos.breakTime)
                {
                   m_logger.Error("------------------------------------");
                   m_logger.Error("INVALID HISTORICAL BOS");
                   m_logger.Error("Pivot ID: PIVOT-" + IntegerToString(bos.relatedPivotID));
                   m_logger.Error("Pivot Time: " + TimeToString(bos.pivotTime));
                   m_logger.Error("Break Time: " + TimeToString(bos.breakTime));
                   m_logger.Error("Pivot Bar: " + IntegerToString(bos.pivotBarIndex));
                   m_logger.Error("Break Bar: " + IntegerToString(bos.breakBarIndex));
                   m_logger.Error("------------------------------------");
                }
                
                StoreBOSEvent(bos);
                MarkPivotConsumed(latestHigh.pivotID);
            }
         }
         
         // Check bearish BOS
         SwingPoint latestLow = FindLatestStructuralPivotAtBar(TREND_BEARISH, barIndex);
         if(latestLow.time != 0 && !IsPivotConsumed(latestLow.pivotID))
         {
            string rejectionReason = ValidateBOSRulesHistorical(latestLow, barIndex, closePrice, bufferPoints);
            
            if(rejectionReason == "")
            {
               BOSEvent bos;
               bos.bosID = ++m_bosIDCounter;
               bos.relatedPivotID = latestLow.pivotID;
               bos.direction = TREND_BEARISH;
               bos.breakPrice = closePrice;
               bos.pivotPrice = latestLow.price;
               bos.breakBarIndex = barIndex;
               bos.pivotBarIndex = latestLow.barIndex;
               bos.breakTime = iTime(_Symbol, _Period, barIndex);
               bos.pivotTime = latestLow.time;
               bos.confirmed = true;
               bos.objectName = MakeBOSObjectName(bos.bosID, bos.relatedPivotID);
               bos.breakDistance = MathAbs(closePrice - latestLow.price);
               bos.barsSincePivot = latestLow.barIndex - barIndex;
               bos.bufferUsed = bufferPoints;
               bos.closePrice = closePrice;
               
                // SPRINT 5.1.10: TASK 2 - Assignment Audit
                m_logger.Error("TASK 2 - ASSIGNMENT AUDIT (BOS#" + IntegerToString(bos.bosID) + "):");
                m_logger.Error("  File: BOSDetector.mqh");
                m_logger.Error("  Function: InitialScan()");
                m_logger.Error("  Line: ~602");
                m_logger.Error("  Statement: bos.pivotTime = latestLow.time;");
                m_logger.Error("  Value: " + TimeToString(bos.pivotTime));
                m_logger.Error("  Source: latestLow.time = " + TimeToString(latestLow.time));
                m_logger.Error("  Match: " + ((bos.pivotTime == latestLow.time) ? "PASS" : "FAIL"));
                
                // SPRINT 5.1.9: Track BOS creation
                TrackBOSCreation(bos, latestLow, true);
                
                // SPRINT 5.1.12: Temporary chronology verification
                if(bos.pivotTime > bos.breakTime)
                {
                   m_logger.Error("------------------------------------");
                   m_logger.Error("INVALID HISTORICAL BOS");
                   m_logger.Error("Pivot ID: PIVOT-" + IntegerToString(bos.relatedPivotID));
                   m_logger.Error("Pivot Time: " + TimeToString(bos.pivotTime));
                   m_logger.Error("Break Time: " + TimeToString(bos.breakTime));
                   m_logger.Error("Pivot Bar: " + IntegerToString(bos.pivotBarIndex));
                   m_logger.Error("Break Bar: " + IntegerToString(bos.breakBarIndex));
                   m_logger.Error("------------------------------------");
                }
                
                StoreBOSEvent(bos);
                MarkPivotConsumed(latestLow.pivotID);
            }
         }
      }
      
       m_logger.Debug("BOS initial scan complete - found " + IntegerToString(m_bosCount) + " BOS events");
   }
   
   //+------------------------------------------------------------------+
   //| Find latest structural pivot at specific bar (for historical)    |
   //+------------------------------------------------------------------+
   //+------------------------------------------------------------------+
   //| Find structural pivot OLDER than the given bar (for historical)  |
   //+------------------------------------------------------------------+
   // MQL5: bar 0 = newest, bar N-1 = oldest
   // sp.barIndex > upToBar means the pivot is at an older bar (larger index)
   // than the current scanning position, guaranteeing pivot existed BEFORE
   // the break bar in chronological time.
   SwingPoint FindLatestStructuralPivotAtBar(ENUM_TREND_STATE type, int upToBar)
   {
      SwingPoint empty = {0};
      
      if(type == TREND_BULLISH)
      {
         for(int i = m_swingDetector.GetSwingHighCount() - 1; i >= 0; i--)
         {
            SwingPoint sp = m_swingDetector.GetSwingHigh(i);
            if(sp.isStructuralPivot && sp.barIndex > upToBar && !IsPivotConsumed(sp.pivotID))
            {
               return sp;
            }
         }
      }
      else
      {
         for(int i = m_swingDetector.GetSwingLowCount() - 1; i >= 0; i--)
         {
            SwingPoint sp = m_swingDetector.GetSwingLow(i);
            if(sp.isStructuralPivot && sp.barIndex > upToBar && !IsPivotConsumed(sp.pivotID))
            {
               return sp;
            }
         }
      }
      
      return empty;
   }
   
   //+------------------------------------------------------------------+
   //| Validate BOS rules for historical scan (allows any closed bar)   |
   //+------------------------------------------------------------------+
   string ValidateBOSRulesHistorical(const SwingPoint &pivot, int breakBarIndex, double breakPrice, double bufferPoints)
   {
      // Rule 1: Structural Pivot exists
      if(!pivot.isStructuralPivot)
         return "Structural pivot does not exist";
      
      // Rule 2: Pivot confirmed
      if(!pivot.confirmed)
         return "Pivot not confirmed";
      
      // Rule 3: Pivot not consumed
      if(IsPivotConsumed(pivot.pivotID))
      {
         m_statConsumedPivots++;
         return "Pivot already consumed";
      }
      
      // Rule 4: Close breaks pivot
      bool breaksPivot = false;
      if(pivot.type == TREND_BULLISH && breakPrice > pivot.price)
         breaksPivot = true;
      else if(pivot.type == TREND_BEARISH && breakPrice < pivot.price)
         breaksPivot = true;
      
      if(!breaksPivot)
         return "Close does not break pivot";
      
      // Rule 5: Buffer satisfied
      double breakDistance = MathAbs(breakPrice - pivot.price);
      double breakDistancePoints = breakDistance / _Point;
      
      if(breakDistancePoints < bufferPoints)
      {
         m_statBufferFailures++;
         return StringFormat("Buffer not satisfied (%.1f < %.1f points)", 
                            breakDistancePoints, bufferPoints);
      }
      
      // Rule 6: Body close only (implicitly satisfied)
      
      // Rule 7: Candle closed (all historical bars are closed)
      
      // Rule 8: BOS not duplicated
      if(IsDuplicateBOS(pivot.pivotID, pivot.type))
      {
         m_statDuplicatePrevention++;
         return "Duplicate BOS detected";
      }
      
      return "";
   }
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   BOSDetector()
   {
      m_swingDetector = NULL;
      m_logger = Logger("BOSDetector");
      m_initialized = false;
      m_lastBarCount = 0;
      m_initialScanDone = false;
      m_bosCount = 0;
      m_bosIDCounter = 0;
      
      // Initialize statistics
      m_statTotalStructuralHighs = 0;
      m_statTotalStructuralLows = 0;
      m_statBullishBOS = 0;
      m_statBearishBOS = 0;
      m_statRejectedBOS = 0;
      m_statDuplicatePrevention = 0;
      m_statBufferFailures = 0;
      m_statConsumedPivots = 0;
      
       ArrayResize(m_bosEvents, MAX_BOS_EVENTS);
      InitPivotMap();
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~BOSDetector()
   {
      Clear();
   }
   
   //+------------------------------------------------------------------+
   //| Initialize BOS detector                                          |
   //+------------------------------------------------------------------+
   bool Initialize(SwingDetector *swingDetector)
   {
       m_logger.Debug("BOSDetector v3.2 init");
      
      if(swingDetector == NULL)
      {
         m_logger.Error("SwingDetector is NULL");
         return false;
      }
      
      m_swingDetector = swingDetector;
      m_lastBarCount = Bars(_Symbol, _Period);
      m_initialized = true;
      
      // Update structural pivot statistics
      m_statTotalStructuralHighs = m_swingDetector.GetStructuralHighCount();
      m_statTotalStructuralLows = m_swingDetector.GetStructuralLowCount();
      
      // Perform initial historical scan
      InitialScan();
      
      m_initialScanDone = true;
       m_logger.Debug("BOSDetector ready - " + IntegerToString(m_bosCount) + " BOS events detected");
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update - called on each new bar                                  |
   //+------------------------------------------------------------------+
   void Update()
   {
      if(!m_initialized || !m_initialScanDone) return;
      if(!IsNewBar()) return;
      
      ScanForBOS();
   }
   
   //+------------------------------------------------------------------+
   //| Print runtime statistics                                         |
   //+------------------------------------------------------------------+
    void PrintRuntimeStatistics()
    {
       m_logger.Debug("========================================================");
       m_logger.Debug("BOS DETECTOR - RUNTIME STATISTICS");
       m_logger.Debug("========================================================");
       m_logger.Debug("Total Structural Highs: " + IntegerToString(m_statTotalStructuralHighs));
       m_logger.Debug("Total Structural Lows: " + IntegerToString(m_statTotalStructuralLows));
       m_logger.Debug("Bullish BOS Detected: " + IntegerToString(m_statBullishBOS));
       m_logger.Debug("Bearish BOS Detected: " + IntegerToString(m_statBearishBOS));
       m_logger.Debug("Total BOS Events: " + IntegerToString(m_bosCount));
       m_logger.Debug("Rejected BOS: " + IntegerToString(m_statRejectedBOS));
       m_logger.Debug("Duplicate Prevention Events: " + IntegerToString(m_statDuplicatePrevention));
       m_logger.Debug("Buffer Failures: " + IntegerToString(m_statBufferFailures));
       m_logger.Debug("Already Consumed Pivots: " + IntegerToString(m_statConsumedPivots));
       m_logger.Debug("========================================================");
    }
   
   //+------------------------------------------------------------------+
   //| Get BOS event by index                                           |
   //+------------------------------------------------------------------+
   BOSEvent GetBOSEvent(int index)
   {
      BOSEvent empty = {0};
      if(index >= 0 && index < m_bosCount)
      {
         return m_bosEvents[index];
      }
      return empty;
   }
   
   //+------------------------------------------------------------------+
   //| Get total BOS count                                              |
   //+------------------------------------------------------------------+
   int GetBOSCount() { return m_bosCount; }
   
   //+------------------------------------------------------------------+
   //| Get latest BOS event                                             |
   //+------------------------------------------------------------------+
   BOSEvent GetLatestBOS()
   {
      BOSEvent empty = {0};
      if(m_bosCount > 0)
      {
         return m_bosEvents[m_bosCount - 1];
      }
      return empty;
   }
   
   //+------------------------------------------------------------------+
   //| Get latest bullish BOS                                           |
   //+------------------------------------------------------------------+
   BOSEvent GetLatestBullishBOS()
   {
      BOSEvent empty = {0};
      for(int i = m_bosCount - 1; i >= 0; i--)
      {
         if(m_bosEvents[i].direction == TREND_BULLISH)
            return m_bosEvents[i];
      }
      return empty;
   }
   
   //+------------------------------------------------------------------+
   //| Get latest bearish BOS                                           |
   //+------------------------------------------------------------------+
   BOSEvent GetLatestBearishBOS()
   {
      BOSEvent empty = {0};
      for(int i = m_bosCount - 1; i >= 0; i--)
      {
         if(m_bosEvents[i].direction == TREND_BEARISH)
            return m_bosEvents[i];
      }
      return empty;
   }
   
   //+------------------------------------------------------------------+
   //| Check if initialized                                              |
   //+------------------------------------------------------------------+
   bool IsInitialized() { return m_initialized; }
   
   //+------------------------------------------------------------------+
   //| Clear all BOS data and chart objects                             |
   //+------------------------------------------------------------------+
   void Clear()
   {
      // Delete all BOS chart objects
      Helpers::DeleteObjectsByPrefix(SMA_OBJ_BOS);
      
      // Reset arrays
      m_bosCount = 0;
      m_bosIDCounter = 0;
       ArrayResize(m_bosEvents, MAX_BOS_EVENTS);
       
       // Reset pivot map
      InitPivotMap();
      
      // Reset statistics
      m_statTotalStructuralHighs = 0;
      m_statTotalStructuralLows = 0;
      m_statBullishBOS = 0;
      m_statBearishBOS = 0;
      m_statRejectedBOS = 0;
      m_statDuplicatePrevention = 0;
      m_statBufferFailures = 0;
      m_statConsumedPivots = 0;
      
      m_initialized = false;
      m_initialScanDone = false;
   }
   
    //+------------------------------------------------------------------+
    //| Get swing detector reference                                     |
    //+------------------------------------------------------------------+
    SwingDetector* GetSwingDetector() { return m_swingDetector; }
    
    //+------------------------------------------------------------------+
    //| SPRINT 4.3: Getter methods for validation report                |
    //+------------------------------------------------------------------+
    int GetBullishBOSCount() { return m_statBullishBOS; }
    int GetBearishBOSCount() { return m_statBearishBOS; }
    int GetDuplicatePreventionCount() { return m_statDuplicatePrevention; }
    int GetConsumedPivotCount() { return m_statConsumedPivots; }
    int GetStructuralHighCount() { return m_statTotalStructuralHighs; }
    int GetStructuralLowCount() { return m_statTotalStructuralLows; }
};
//+------------------------------------------------------------------+
