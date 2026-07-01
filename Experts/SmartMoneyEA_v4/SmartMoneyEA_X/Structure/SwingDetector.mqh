//+------------------------------------------------------------------+
//|                                                SmartMoneyEA_X    |
//|                                               SwingDetector.mqh  |
//|                                    Institutional Pivot Engine v3 |
//+------------------------------------------------------------------+
#property copyright "SmartMoneyEA_X"
#property link      ""
#property version   "1.00"

#include "..\Utils\Logger.mqh"
#include "..\Utils\Structures.mqh"
#include "..\Utils\Constants.mqh"
#include "..\Utils\Helpers.mqh"

class SwingDetector
{
private:
   enum { SWING_STRENGTH = 4, MAX_STORED_SWINGS = 500 };

   double      m_minSwingDistance;
   double      m_minStructuralDistance;
   double      m_minImpulsePoints;
   int         m_pivotCounter;
   Logger      m_logger;
   bool        m_initialized;
   SwingPoint  m_swingHighs[];
   SwingPoint  m_swingLows[];
   int         m_highCount;
   int         m_lowCount;
   int         m_lastBarCount;
   bool        m_initialScanDone;

    //--- SPRINT 4.4: Diagnostic counters ---
    int         m_highsDetected;
    int         m_highsPromoted;
    int         m_highsRejected;
    int         m_lowsDetected;
    int         m_lowsPromoted;
    int         m_lowsRejected;
    string      m_rejectionReasons[];
    int         m_rejectionCounts[];
    int         m_maxRejectionReasons;

    //--- SPRINT 4.5: Structural Pivot Promotion Verification ---
    int         m_sphCreated;
    int         m_splCreated;
    int         m_promotionAttempts;
    int         m_promotionSuccess;
    int         m_promotionFailed;
    int         m_reevaluationSkipped;
    int         m_impulseBelowThreshold;
    int         m_impulseAboveThreshold;
    int         m_firstEvaluations;
    
    //--- SPRINT 4.8: BOS Symmetry Validation ---
    int         m_sphBroken;
    int         m_sphNeverBroken;
    int         m_splBroken;
    int         m_splNeverBroken;

   void TrackRejection(string reason)
   {
      for(int i = 0; i < ArraySize(m_rejectionReasons); i++)
      {
         if(m_rejectionReasons[i] == reason)
         {
            m_rejectionCounts[i]++;
            return;
         }
      }
      int idx = ArraySize(m_rejectionReasons);
      ArrayResize(m_rejectionReasons, idx + 1);
      ArrayResize(m_rejectionCounts, idx + 1);
      m_rejectionReasons[idx] = reason;
      m_rejectionCounts[idx] = 1;
   }

   void PrintRejectionSummary()
   {
      m_logger.Info("===============================");
      m_logger.Info("REJECTION REASONS SUMMARY");
      m_logger.Info("===============================");
      int total = ArraySize(m_rejectionReasons);
      for(int i = 0; i < total; i++)
      {
         m_logger.Info("  " + m_rejectionReasons[i] + ": " + IntegerToString(m_rejectionCounts[i]));
      }
      if(total == 0)
      {
         m_logger.Info("  (no rejections recorded)");
      }
      m_logger.Info("===============================");
   }

   bool IsNewBar()
   {
      int cur = Bars(_Symbol, _Period);
      if(cur != m_lastBarCount) { m_lastBarCount = cur; return true; }
      return false;
   }

   bool IsSwingHigh(int bi)
   {
      double ph = iHigh(_Symbol, _Period, bi);
      for(int i=1; i<=SWING_STRENGTH; i++)
         if(iHigh(_Symbol,_Period,bi+i) >= ph || iHigh(_Symbol,_Period,bi-i) >= ph) return false;
      return true;
   }

   bool IsSwingLow(int bi)
   {
      double pl = iLow(_Symbol, _Period, bi);
      for(int i=1; i<=SWING_STRENGTH; i++)
         if(iLow(_Symbol,_Period,bi+i) <= pl || iLow(_Symbol,_Period,bi-i) <= pl) return false;
      return true;
   }

   bool SwingExistsAtBar(int bi, ENUM_TREND_STATE type)
   {
      if(type == TREND_BULLISH)
         { for(int i=0; i<m_highCount; i++) if(m_swingHighs[i].barIndex==bi && m_swingHighs[i].confirmed) return true; }
      else
         { for(int i=0; i<m_lowCount; i++) if(m_swingLows[i].barIndex==bi && m_swingLows[i].confirmed) return true; }
      return false;
   }

   bool IsFarEnough(double price, ENUM_TREND_STATE type)
   {
      if(type == TREND_BULLISH)
         return (m_highCount==0) ? true : MathAbs(price-m_swingHighs[m_highCount-1].price) >= m_minSwingDistance;
      else
         return (m_lowCount==0) ? true : MathAbs(price-m_swingLows[m_lowCount-1].price) >= m_minSwingDistance;
   }

   string MakeSwingObjectName(datetime bt, ENUM_TREND_STATE type)
   {
      MqlDateTime dt; TimeToStruct(bt, dt);
      string d = StringFormat("%04d%02d%02d%02d%02d",dt.year,dt.mon,dt.day,dt.hour,dt.min);
      return (type==TREND_BULLISH) ? SMA_OBJ_SWING+"HIGH_"+d : SMA_OBJ_SWING+"LOW_"+d;
   }

   SwingPoint GetLastSwing()
   {
      SwingPoint e = {0};
      if(m_highCount==0 && m_lowCount==0) return e;
      if(m_highCount==0) return m_swingLows[m_lowCount-1];
      if(m_lowCount==0) return m_swingHighs[m_highCount-1];
      return (m_swingHighs[m_highCount-1].time > m_swingLows[m_lowCount-1].time)
         ? m_swingHighs[m_highCount-1] : m_swingLows[m_lowCount-1];
   }

   SwingPoint GetLastOppositeSwing(ENUM_TREND_STATE type)
   {
      SwingPoint e = {0};
      if(type == TREND_BULLISH) return (m_lowCount>0) ? m_swingLows[m_lowCount-1] : e;
      else return (m_highCount>0) ? m_swingHighs[m_highCount-1] : e;
   }

   void AppendSwing(SwingPoint &swing)
   {
      if(swing.type == TREND_BULLISH)
      {
         if(m_highCount >= MAX_STORED_SWINGS) { for(int i=0; i<m_highCount-1; i++) m_swingHighs[i]=m_swingHighs[i+1]; m_highCount--; }
         m_swingHighs[m_highCount] = swing; m_highCount++;
      }
      else
      {
         if(m_lowCount >= MAX_STORED_SWINGS) { for(int i=0; i<m_lowCount-1; i++) m_swingLows[i]=m_swingLows[i+1]; m_lowCount--; }
         m_swingLows[m_lowCount] = swing; m_lowCount++;
      }
   }

   void DeleteSwingObjects(const SwingPoint &swing)
   {
      Helpers::SafeObjectDelete(swing.objectName);
      Helpers::SafeObjectDelete(swing.objectName + "_L");
      Helpers::SafeObjectDelete(swing.objectName + "_Q");
      Helpers::SafeObjectDelete(swing.objectName + "_SP");
   }

   int CalculateSwingQuality(double price, ENUM_TREND_STATE type, double prevOppPrice, bool prevExists)
   {
      int score = MathMin(SWING_STRENGTH * 7, 30);
      if(prevExists) { double dist = MathAbs(price - prevOppPrice); int pts = (int)(dist / (10.0 * _Point)); score += MathMin(pts, 50); }
      score += 20;
      return MathMin(score, 100);
   }

   int CalculatePivotQuality(const SwingPoint &swing)
   {
      int score = 0;
      score += MathMin(swing.strength * 4, 25);
      if(swing.impulsePoints > 0.0)
      {
         double pts = swing.impulsePoints / _Point;
         score += MathMin((int)(pts / 2.0), 40);
      }
      score += 15;
      return (int)MathMin(MathMax(score, 0), 100);
   }

    void LogSwingConfirmed(SwingPoint &swing, bool replaced)
    {
       string ts = (swing.type==TREND_BULLISH)?"SWING HIGH":"SWING LOW";
       if(replaced) ts = "UPDATED " + ts;
       m_logger.Verbose("=== " + ts + " ===");
       m_logger.Verbose("Bar: " + IntegerToString(swing.barIndex) + " | Price: " + Helpers::FormatPrice(swing.price) + " | Q: " + IntegerToString(swing.qualityScore));
    }

    void LogStructuralPivotPromoted(const SwingPoint &swing)
    {
       string typeStr = (swing.type == TREND_BULLISH)
          ? "Structural Pivot High (SPH)"
          : "Structural Pivot Low (SPL)";
       m_logger.Info("===============================");
       m_logger.Info("STRUCTURAL PIVOT CONFIRMED");
       m_logger.Info("===============================");
       m_logger.Info("Type: " + typeStr);
       m_logger.Info("Price: " + Helpers::FormatPrice(swing.price));
       m_logger.Info("Impulse: " + Helpers::FormatPrice(swing.impulsePoints));
       m_logger.Info("Quality: " + IntegerToString(swing.qualityScore));
       m_logger.Info("Pivot ID: PIVOT-" + IntegerToString(swing.pivotID));
       m_logger.Info("===============================");
    }
    
    //+------------------------------------------------------------------+
    //| SPRINT 5.1.9: Track pivot creation with timestamp diagnostics    |
    //+------------------------------------------------------------------+
    void TrackPivotCreation(const SwingPoint &swing, bool isPromotion)
    {
       // Log pivot creation
       string action = isPromotion ? "PROMOTED" : "CREATED";
       string typeStr = (swing.type == TREND_BULLISH) ? "SPH" : "SPL";
       
       m_logger.Error("Pivot " + action + " [SwingDetector]:");
       m_logger.Error("  PivotID: PIVOT-" + IntegerToString(swing.pivotID));
       m_logger.Error("  Type: " + typeStr);
       m_logger.Error("  Time: " + TimeToString(swing.time));
       m_logger.Error("  Bar: " + IntegerToString(swing.barIndex));
       m_logger.Error("  Price: " + Helpers::FormatPrice(swing.price));
       m_logger.Error("  Structural: " + (swing.isStructuralPivot ? "TRUE" : "FALSE"));
    }

    void ReplaceSwing(SwingPoint &newSwing, SwingPoint &oldSwing)
    {
       DeleteSwingObjects(oldSwing);
       m_logger.Verbose("=== SWING UPDATED ===");
       m_logger.Verbose("Old Price: " + Helpers::FormatPrice(oldSwing.price));
       m_logger.Verbose("New Price: " + Helpers::FormatPrice(newSwing.price));
       m_logger.Verbose("Reason: " + ((newSwing.type==TREND_BULLISH) ? "Higher High" : "Lower Low"));
       if(newSwing.type == TREND_BULLISH && m_highCount > 0) m_swingHighs[m_highCount-1] = newSwing;
       else if(m_lowCount > 0) m_swingLows[m_lowCount-1] = newSwing;
       DrawSwing(newSwing);
       LogSwingConfirmed(newSwing, true);
    }

    void RejectSwing(SwingPoint &swing, string reason)
    {
       m_logger.Verbose("=== SWING REJECTED ===");
       m_logger.Verbose("Bar: " + IntegerToString(swing.barIndex) + " | Price: " + Helpers::FormatPrice(swing.price) + " | Type: " + ((swing.type==TREND_BULLISH)?"HIGH":"LOW"));
       m_logger.Verbose("Reason: " + reason);

       //--- SPRINT 4.4: Track rejection ---
       if(swing.type == TREND_BULLISH)
          m_highsRejected++;
       else
          m_lowsRejected++;
       TrackRejection(reason);
    }

   void DrawSwing(SwingPoint &swing)
   {
      if(ObjectFind(0, swing.objectName) >= 0) return;
      DeleteSwingObjects(swing);
      double off = 10.0 * _Point;
      if(swing.type == TREND_BULLISH)
      {
         ObjectCreate(0, swing.objectName, OBJ_ARROW_DOWN, 0, swing.time, swing.price + off);
         ObjectSetInteger(0, swing.objectName, OBJPROP_COLOR, SMA_COL_SWING);
         ObjectSetInteger(0, swing.objectName, OBJPROP_WIDTH, SMA_LINE_WIDTH);
         ObjectSetInteger(0, swing.objectName, OBJPROP_BACK, false);
         ObjectSetInteger(0, swing.objectName, OBJPROP_SELECTABLE, false);
         ObjectCreate(0, swing.objectName+"_L", OBJ_TEXT, 0, swing.time, swing.price + off*3);
         ObjectSetString(0, swing.objectName+"_L", OBJPROP_TEXT, "SH");
         ObjectSetInteger(0, swing.objectName+"_L", OBJPROP_FONTSIZE, SMA_LABEL_SIZE);
         ObjectSetInteger(0, swing.objectName+"_L", OBJPROP_COLOR, SMA_COL_SWING);
         ObjectCreate(0, swing.objectName+"_Q", OBJ_TEXT, 0, swing.time, swing.price + off*5);
         ObjectSetString(0, swing.objectName+"_Q", OBJPROP_TEXT, "Q:" + IntegerToString(swing.qualityScore));
         ObjectSetInteger(0, swing.objectName+"_Q", OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, swing.objectName+"_Q", OBJPROP_COLOR, SMA_COL_SWING);
      }
      else
      {
         ObjectCreate(0, swing.objectName, OBJ_ARROW_UP, 0, swing.time, swing.price - off);
         ObjectSetInteger(0, swing.objectName, OBJPROP_COLOR, SMA_COL_SWING);
         ObjectSetInteger(0, swing.objectName, OBJPROP_WIDTH, SMA_LINE_WIDTH);
         ObjectSetInteger(0, swing.objectName, OBJPROP_BACK, false);
         ObjectSetInteger(0, swing.objectName, OBJPROP_SELECTABLE, false);
         ObjectCreate(0, swing.objectName+"_L", OBJ_TEXT, 0, swing.time, swing.price - off*3);
         ObjectSetString(0, swing.objectName+"_L", OBJPROP_TEXT, "SL");
         ObjectSetInteger(0, swing.objectName+"_L", OBJPROP_FONTSIZE, SMA_LABEL_SIZE);
         ObjectSetInteger(0, swing.objectName+"_L", OBJPROP_COLOR, SMA_COL_SWING);
         ObjectCreate(0, swing.objectName+"_Q", OBJ_TEXT, 0, swing.time, swing.price - off*5);
         ObjectSetString(0, swing.objectName+"_Q", OBJPROP_TEXT, "Q:" + IntegerToString(swing.qualityScore));
         ObjectSetInteger(0, swing.objectName+"_Q", OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, swing.objectName+"_Q", OBJPROP_COLOR, SMA_COL_SWING);
      }
   }

   void DrawStructuralPivotLabel(SwingPoint &swing)
   {
      string spName = swing.objectName + "_SP";
      if(ObjectFind(0, spName) >= 0) return;
      double off = 10.0 * _Point;
      string label = (swing.type == TREND_BULLISH) ? "SPH" : "SPL";
      if(swing.type == TREND_BULLISH)
      {
         ObjectCreate(0, spName, OBJ_TEXT, 0, swing.time, swing.price + off * 7.0);
         ObjectSetString(0, spName, OBJPROP_TEXT, label);
         ObjectSetInteger(0, spName, OBJPROP_FONTSIZE, SMA_LABEL_SIZE + 2);
         ObjectSetInteger(0, spName, OBJPROP_COLOR, SMA_COL_BULLISH);
      }
      else
      {
         ObjectCreate(0, spName, OBJ_TEXT, 0, swing.time, swing.price - off * 7.0);
         ObjectSetString(0, spName, OBJPROP_TEXT, label);
         ObjectSetInteger(0, spName, OBJPROP_FONTSIZE, SMA_LABEL_SIZE + 2);
         ObjectSetInteger(0, spName, OBJPROP_COLOR, SMA_COL_BEARISH);
      }
   }

   void CheckForPendingPromotion(SwingPoint &newSwing)
   {
       if(newSwing.type == TREND_BULLISH)
       {
          // New HIGH added - check LAST LOW for promotion to SPL
          if(m_lowCount > 0)
          {
             SwingPoint lastLow = m_swingLows[m_lowCount - 1];
            
            //--- SPRINT 4.5: TASK 1 - Trace Structural Pivot Candidate ---
            m_logger.Info("==================================================");
            m_logger.Info("STRUCTURAL PIVOT CANDIDATE");
            m_logger.Info("==================================================");
            m_logger.Info("Type: Swing Low");
            m_logger.Info("Bar Index: " + IntegerToString(lastLow.barIndex));
            m_logger.Info("Time: " + TimeToString(lastLow.time));
            m_logger.Info("Price: " + Helpers::FormatPrice(lastLow.price));
            m_logger.Info("Confirmed: " + (lastLow.confirmed?"TRUE":"FALSE"));
            m_logger.Info("Quality: " + IntegerToString(lastLow.qualityScore));
            m_logger.Info("Current Pivot ID: " + IntegerToString(lastLow.pivotID));
            m_logger.Info("Already Structural: " + (lastLow.isStructuralPivot?"TRUE":"FALSE"));
            m_logger.Info("Impulse: " + Helpers::FormatPrice(lastLow.impulsePoints));
            m_logger.Info("==================================================");
            
            //--- SPRINT 4.5: TASK 2 - Trace Promotion Decision ---
            m_logger.Info("PROMOTION CHECK");
            m_logger.Info("Candidate Type: Swing Low");
            m_logger.Info("Candidate Time: " + TimeToString(lastLow.time));
            m_logger.Info("Candidate Price: " + Helpers::FormatPrice(lastLow.price));
            m_logger.Info("Current Impulse: " + Helpers::FormatPrice(lastLow.impulsePoints));
            m_logger.Info("Minimum Required Impulse: " + Helpers::FormatPrice(m_minImpulsePoints));
            
            m_promotionAttempts++;
            
            //--- SPRINT 4.7: TASK 6 - Runtime Verification Logs ---
            m_logger.Info("Array Low Impulse BEFORE: " + Helpers::FormatPrice(lastLow.impulsePoints));
            m_logger.Info("Array Low Structural BEFORE: " + (lastLow.isStructuralPivot?"TRUE":"FALSE"));
            m_logger.Info("Array Low PivotID BEFORE: " + IntegerToString(lastLow.pivotID));
            
            if(!lastLow.isStructuralPivot && lastLow.confirmed && lastLow.impulsePoints == 0.0)
            {
               //--- SPRINT 4.5: TASK 3 - First Evaluation ---
               m_firstEvaluations++;
               double previousImpulse = lastLow.impulsePoints;
               lastLow.impulsePoints = CalculateImpulse(lastLow, newSwing);
               m_logger.Info("FIRST IMPULSE ASSIGNED");
               m_logger.Info("Swing Type: Swing Low");
               m_logger.Info("Swing Time: " + TimeToString(lastLow.time));
               m_logger.Info("Impulse: " + Helpers::FormatPrice(lastLow.impulsePoints));
               m_logger.Info("Previous impulse = 0");
               m_logger.Info("New impulse = " + Helpers::FormatPrice(lastLow.impulsePoints));
               m_logger.Info("Evaluation Triggered: YES");
               
               m_logger.Info("Calculated Impulse: " + Helpers::FormatPrice(lastLow.impulsePoints) + " | Min Required: " + Helpers::FormatPrice(m_minImpulsePoints));
               
               if(lastLow.impulsePoints >= m_minImpulsePoints)
               {
                  m_logger.Info("Eligible For Promotion? YES");
                  m_logger.Info("Reason: Impulse meets threshold");
                  m_logger.Info(">>> PROMOTING LOW TO SPL <<<");
                  EvaluateStructuralPivot(lastLow);
                  m_swingLows[m_lowCount - 1] = lastLow;  // Write-back to array
                  
                  //--- SPRINT 4.7: TASK 6 - Runtime Verification Logs ---
                  m_logger.Info("Array Updated Successfully");
                  m_logger.Info("Impulse: " + Helpers::FormatPrice(lastLow.impulsePoints));
                  m_logger.Info("PivotID: " + IntegerToString(lastLow.pivotID));
                  m_logger.Info("Structural: " + (lastLow.isStructuralPivot?"TRUE":"FALSE"));
                  m_logger.Info("Quality: " + IntegerToString(lastLow.qualityScore));
                  
                  m_lowsPromoted++;
                  m_promotionSuccess++;
                  m_splCreated++;
                  m_impulseAboveThreshold++;
               }
               else
               {
                  m_logger.Info("Eligible For Promotion? NO");
                  m_logger.Info("Reason: Impulse below threshold");
                  m_logger.Verbose(">>> SPL PROMOTION FAILED: Impulse below threshold <<<");
                  TrackRejection("SPL: Impulse below threshold");
                  m_promotionFailed++;
                  m_impulseBelowThreshold++;
               }
            }
            else if(lastLow.isStructuralPivot)
            {
               m_logger.Info("Eligible For Promotion? NO");
               m_logger.Info("Reason: Already structural pivot");
               m_logger.Verbose(">>> SPL ALREADY STRUCTURAL PIVOT <<<");
            }
            else if(!lastLow.confirmed)
            {
               m_logger.Info("Eligible For Promotion? NO");
               m_logger.Info("Reason: Not confirmed");
               m_logger.Verbose(">>> SPL NOT CONFIRMED <<<");
            }
            else if(lastLow.impulsePoints != 0.0)
            {
               //--- SPRINT 4.5: TASK 4 - Re-evaluation Attempt ---
               m_reevaluationSkipped++;
               m_logger.Info("Eligible For Promotion? NO");
               m_logger.Info("Reason: Already evaluated once");
               m_logger.Info("RE-EVALUATION SKIPPED");
               m_logger.Info("Swing Type: Swing Low");
               m_logger.Info("Swing Time: " + TimeToString(lastLow.time));
               m_logger.Info("Stored Impulse: " + Helpers::FormatPrice(lastLow.impulsePoints));
               m_logger.Info("Reason: Already evaluated once");
               m_logger.Verbose(">>> SPL IMPULSE ALREADY CALCULATED (insufficient) <<<");
            }
         }
      }
       else
       {
          // New LOW added - check LAST HIGH for promotion to SPH
          if(m_highCount > 0)
          {
             SwingPoint lastHigh = m_swingHighs[m_highCount - 1];
            
            //--- SPRINT 4.5: TASK 1 - Trace Structural Pivot Candidate ---
            m_logger.Info("==================================================");
            m_logger.Info("STRUCTURAL PIVOT CANDIDATE");
            m_logger.Info("==================================================");
            m_logger.Info("Type: Swing High");
            m_logger.Info("Bar Index: " + IntegerToString(lastHigh.barIndex));
            m_logger.Info("Time: " + TimeToString(lastHigh.time));
            m_logger.Info("Price: " + Helpers::FormatPrice(lastHigh.price));
            m_logger.Info("Confirmed: " + (lastHigh.confirmed?"TRUE":"FALSE"));
            m_logger.Info("Quality: " + IntegerToString(lastHigh.qualityScore));
            m_logger.Info("Current Pivot ID: " + IntegerToString(lastHigh.pivotID));
            m_logger.Info("Already Structural: " + (lastHigh.isStructuralPivot?"TRUE":"FALSE"));
            m_logger.Info("Impulse: " + Helpers::FormatPrice(lastHigh.impulsePoints));
            m_logger.Info("==================================================");
            
            //--- SPRINT 4.5: TASK 2 - Trace Promotion Decision ---
            m_logger.Info("PROMOTION CHECK");
            m_logger.Info("Candidate Type: Swing High");
            m_logger.Info("Candidate Time: " + TimeToString(lastHigh.time));
            m_logger.Info("Candidate Price: " + Helpers::FormatPrice(lastHigh.price));
            m_logger.Info("Current Impulse: " + Helpers::FormatPrice(lastHigh.impulsePoints));
            m_logger.Info("Minimum Required Impulse: " + Helpers::FormatPrice(m_minImpulsePoints));
            
            m_promotionAttempts++;
            
            //--- SPRINT 4.7: TASK 6 - Runtime Verification Logs ---
            m_logger.Info("Array High Impulse BEFORE: " + Helpers::FormatPrice(lastHigh.impulsePoints));
            m_logger.Info("Array High Structural BEFORE: " + (lastHigh.isStructuralPivot?"TRUE":"FALSE"));
            m_logger.Info("Array High PivotID BEFORE: " + IntegerToString(lastHigh.pivotID));
            
            if(!lastHigh.isStructuralPivot && lastHigh.confirmed && lastHigh.impulsePoints == 0.0)
            {
               //--- SPRINT 4.5: TASK 3 - First Evaluation ---
               m_firstEvaluations++;
               double previousImpulse = lastHigh.impulsePoints;
               lastHigh.impulsePoints = CalculateImpulse(lastHigh, newSwing);
               m_logger.Info("FIRST IMPULSE ASSIGNED");
               m_logger.Info("Swing Type: Swing High");
               m_logger.Info("Swing Time: " + TimeToString(lastHigh.time));
               m_logger.Info("Impulse: " + Helpers::FormatPrice(lastHigh.impulsePoints));
               m_logger.Info("Previous impulse = 0");
               m_logger.Info("New impulse = " + Helpers::FormatPrice(lastHigh.impulsePoints));
               m_logger.Info("Evaluation Triggered: YES");
               
               m_logger.Info("Calculated Impulse: " + Helpers::FormatPrice(lastHigh.impulsePoints) + " | Min Required: " + Helpers::FormatPrice(m_minImpulsePoints));
               
               if(lastHigh.impulsePoints >= m_minImpulsePoints)
               {
                  m_logger.Info("Eligible For Promotion? YES");
                  m_logger.Info("Reason: Impulse meets threshold");
                  m_logger.Info(">>> PROMOTING HIGH TO SPH <<<");
                  EvaluateStructuralPivot(lastHigh);
                  m_swingHighs[m_highCount - 1] = lastHigh;  // Write-back to array
                  
                  //--- SPRINT 4.7: TASK 6 - Runtime Verification Logs ---
                  m_logger.Info("Array Updated Successfully");
                  m_logger.Info("Impulse: " + Helpers::FormatPrice(lastHigh.impulsePoints));
                  m_logger.Info("PivotID: " + IntegerToString(lastHigh.pivotID));
                  m_logger.Info("Structural: " + (lastHigh.isStructuralPivot?"TRUE":"FALSE"));
                  m_logger.Info("Quality: " + IntegerToString(lastHigh.qualityScore));
                  
                  m_highsPromoted++;
                  m_promotionSuccess++;
                  m_sphCreated++;
                  m_impulseAboveThreshold++;
               }
               else
               {
                  m_logger.Info("Eligible For Promotion? NO");
                  m_logger.Info("Reason: Impulse below threshold");
                  m_logger.Verbose(">>> SPH PROMOTION FAILED: Impulse below threshold <<<");
                  TrackRejection("SPH: Impulse below threshold");
                  m_promotionFailed++;
                  m_impulseBelowThreshold++;
               }
            }
            else if(lastHigh.isStructuralPivot)
            {
               m_logger.Info("Eligible For Promotion? NO");
               m_logger.Info("Reason: Already structural pivot");
               m_logger.Verbose(">>> SPH ALREADY STRUCTURAL PIVOT <<<");
            }
            else if(!lastHigh.confirmed)
            {
               m_logger.Info("Eligible For Promotion? NO");
               m_logger.Info("Reason: Not confirmed");
               m_logger.Verbose(">>> SPH NOT CONFIRMED <<<");
            }
            else if(lastHigh.impulsePoints != 0.0)
            {
               //--- SPRINT 4.5: TASK 4 - Re-evaluation Attempt ---
               m_reevaluationSkipped++;
               m_logger.Info("Eligible For Promotion? NO");
               m_logger.Info("Reason: Already evaluated once");
               m_logger.Info("RE-EVALUATION SKIPPED");
               m_logger.Info("Swing Type: Swing High");
               m_logger.Info("Swing Time: " + TimeToString(lastHigh.time));
               m_logger.Info("Stored Impulse: " + Helpers::FormatPrice(lastHigh.impulsePoints));
               m_logger.Info("Reason: Already evaluated once");
               m_logger.Verbose(">>> SPH IMPULSE ALREADY CALCULATED (insufficient) <<<");
            }
         }
      }
   }

    void DoPromoteToStructuralPivot(SwingPoint &swing)
    {
       m_logger.Verbose("=== DO PROMOTE TO STRUCTURAL PIVOT ===");
       m_logger.Verbose("Bar: " + IntegerToString(swing.barIndex) + " | Price: " + Helpers::FormatPrice(swing.price) + " | Type: " + ((swing.type==TREND_BULLISH)?"HIGH":"LOW"));

       if(swing.isStructuralPivot)
       {
          m_logger.Verbose(">>> ALREADY STRUCTURAL PIVOT - SKIPPING <<<");
          return;
       }
       swing.isStructuralPivot = true;

       // SPRINT 4.3.2: Log promotion details
       int counterBefore = m_pivotCounter;
       swing.pivotID = ++m_pivotCounter;
       int counterAfter = m_pivotCounter;
       
       // SPRINT 5.1.9: Track pivot promotion
       TrackPivotCreation(swing, true);

       m_logger.Info("PROMOTE | PivotID=" + IntegerToString(swing.pivotID) +
                    " | Bar=" + IntegerToString(swing.barIndex) +
                    " | Time=" + TimeToString(swing.time) +
                    " | Price=" + Helpers::FormatPrice(swing.price) +
                    " | Type=" + ((swing.type==TREND_BULLISH)?"SPH":"SPL") +
                    " | CounterBefore=" + IntegerToString(counterBefore) +
                    " | CounterAfter=" + IntegerToString(counterAfter));

       swing.qualityScore = CalculatePivotQuality(swing);

       // SPRINT 4.3: Log pivot creation for validation
       m_logger.Info("PIVOT CREATED | ID=" + IntegerToString(swing.pivotID) +
                    " | Bar=" + IntegerToString(swing.barIndex) +
                    " | Time=" + TimeToString(swing.time) +
                    " | Price=" + Helpers::FormatPrice(swing.price) +
                    " | Type=" + ((swing.type==TREND_BULLISH)?"SPH":"SPL") +
                    " | Impulse=" + Helpers::FormatPrice(swing.impulsePoints) +
                    " | Quality=" + IntegerToString(swing.qualityScore));

       DrawStructuralPivotLabel(swing);
       LogStructuralPivotPromoted(swing);
    }

   double DoCalculateImpulse(const SwingPoint &from, const SwingPoint &to)
   {
      return MathAbs(from.price - to.price);
   }

   void AddSwing(SwingPoint &candidate)
   {
      //--- SPRINT 4.4: Track detection ---
      if(candidate.type == TREND_BULLISH)
         m_highsDetected++;
      else
         m_lowsDetected++;

      SwingPoint last = GetLastSwing();
      if(last.time == 0)
      {
       m_logger.Verbose("=== FIRST SWING ===");
       m_logger.Verbose("Bar: " + IntegerToString(candidate.barIndex) + " | Price: " + Helpers::FormatPrice(candidate.price) + " | Type: " + ((candidate.type==TREND_BULLISH)?"HIGH":"LOW"));
       SwingPoint opp = GetLastOppositeSwing(candidate.type);
       candidate.qualityScore = CalculateSwingQuality(candidate.price, candidate.type, opp.price, opp.time!=0);
       AppendSwing(candidate); DrawSwing(candidate); LogSwingConfirmed(candidate, false);
       
       // SPRINT 5.1.9: Track first swing creation
       TrackPivotCreation(candidate, false);
       return;
      }
       if(candidate.type == last.type)
       {
          if((candidate.type==TREND_BULLISH && candidate.price>last.price) ||
             (candidate.type==TREND_BEARISH && candidate.price<last.price))
          {
             m_logger.Verbose("=== SAME TYPE - REPLACING ===");
             m_logger.Verbose("Bar: " + IntegerToString(candidate.barIndex) + " | Price: " + Helpers::FormatPrice(candidate.price) + " | Type: " + ((candidate.type==TREND_BULLISH)?"HIGH":"LOW"));
             m_logger.Verbose("Old Price: " + Helpers::FormatPrice(last.price) + " | New Price: " + Helpers::FormatPrice(candidate.price));
             candidate.qualityScore = last.qualityScore;
             ReplaceSwing(candidate, last);
             
             // SPRINT 5.1.9: Track swing replacement
             TrackPivotCreation(candidate, false);
          }
         else
         {
            string weakReason = (candidate.type==TREND_BULLISH)?"Weak High":"Weak Low";
            m_logger.Verbose("=== SAME TYPE - REJECTED ===");
            m_logger.Verbose("Bar: " + IntegerToString(candidate.barIndex) + " | Price: " + Helpers::FormatPrice(candidate.price) + " | Type: " + ((candidate.type==TREND_BULLISH)?"HIGH":"LOW"));
            m_logger.Verbose("Last Price: " + Helpers::FormatPrice(last.price) + " | Reason: " + weakReason);
            RejectSwing(candidate, weakReason);
         }
         return;
      }
      if(MathAbs(candidate.price - last.price) < m_minStructuralDistance)
      {
         m_logger.Verbose("=== OPPOSITE TYPE - REJECTED ===");
         m_logger.Verbose("Bar: " + IntegerToString(candidate.barIndex) + " | Price: " + Helpers::FormatPrice(candidate.price) + " | Type: " + ((candidate.type==TREND_BULLISH)?"HIGH":"LOW"));
         m_logger.Verbose("Last Price: " + Helpers::FormatPrice(last.price) + " | Distance: " + Helpers::FormatPrice(MathAbs(candidate.price - last.price)) + " | Min Required: " + Helpers::FormatPrice(m_minStructuralDistance));
         RejectSwing(candidate, "Minimum Structural Distance");
         return;
      }
      if(!IsFarEnough(candidate.price, candidate.type))
      {
         m_logger.Verbose("=== OPPOSITE TYPE - REJECTED ===");
         m_logger.Verbose("Bar: " + IntegerToString(candidate.barIndex) + " | Price: " + Helpers::FormatPrice(candidate.price) + " | Type: " + ((candidate.type==TREND_BULLISH)?"HIGH":"LOW"));
         RejectSwing(candidate, "Minimum Distance");
         return;
      }
       m_logger.Verbose("=== OPPOSITE TYPE - ACCEPTED ===");
       m_logger.Verbose("Bar: " + IntegerToString(candidate.barIndex) + " | Price: " + Helpers::FormatPrice(candidate.price) + " | Type: " + ((candidate.type==TREND_BULLISH)?"HIGH":"LOW"));
       SwingPoint opp = GetLastOppositeSwing(candidate.type);
       candidate.qualityScore = CalculateSwingQuality(candidate.price, candidate.type, opp.price, opp.time!=0);
       AppendSwing(candidate); DrawSwing(candidate); LogSwingConfirmed(candidate, false);
       
       // SPRINT 5.1.9: Track swing creation
       TrackPivotCreation(candidate, false);
       
       CheckForPendingPromotion(candidate);
   }

public:
   SwingDetector()
   {
      m_logger = Logger("SwingDetector");
      m_minSwingDistance = 5.0 * _Point;
      m_minStructuralDistance = 50.0 * _Point;
      m_minImpulsePoints = 10.0 * _Point;
      m_pivotCounter = 0;
      m_initialized = false; m_highCount = 0; m_lowCount = 0;
      m_lastBarCount = 0; m_initialScanDone = false;
      ArrayResize(m_swingHighs, MAX_STORED_SWINGS);
      ArrayResize(m_swingLows, MAX_STORED_SWINGS);

      //--- SPRINT 4.4: Initialize diagnostic counters ---
      m_highsDetected = 0;
      m_highsPromoted = 0;
      m_highsRejected = 0;
      m_lowsDetected = 0;
      m_lowsPromoted = 0;
      m_lowsRejected = 0;
      m_maxRejectionReasons = 20;
      ArrayResize(m_rejectionReasons, 0);
      ArrayResize(m_rejectionCounts, 0);

      //--- SPRINT 4.5: Initialize promotion verification counters ---
      m_sphCreated = 0;
      m_splCreated = 0;
      m_promotionAttempts = 0;
      m_promotionSuccess = 0;
      m_promotionFailed = 0;
      m_reevaluationSkipped = 0;
      m_impulseBelowThreshold = 0;
      m_impulseAboveThreshold = 0;
      m_firstEvaluations = 0;
      
      //--- SPRINT 4.8: Initialize BOS symmetry counters ---
      m_sphBroken = 0;
      m_sphNeverBroken = 0;
      m_splBroken = 0;
      m_splNeverBroken = 0;
   }

   ~SwingDetector() { Clear(); }

   bool Initialize()
   {
       m_logger.Debug("SwingDetector v3 init (Strength=" + IntegerToString(SWING_STRENGTH) + ")");
      int totalBars = Bars(_Symbol, _Period);
      m_lastBarCount = totalBars;
      int minIdx = SWING_STRENGTH + 1;
      int maxIdx = totalBars - SWING_STRENGTH - 2;
      if(maxIdx < minIdx) { m_initialized=true; m_initialScanDone=true; return true; }
      for(int i = maxIdx; i >= minIdx; i--)
      {
         if(GetSwingCount() >= MAX_STORED_SWINGS) break;
         if(IsSwingHigh(i) && !SwingExistsAtBar(i, TREND_BULLISH))
         {
            SwingPoint sh; sh.time=iTime(_Symbol,_Period,i); sh.price=iHigh(_Symbol,_Period,i);
            sh.type=TREND_BULLISH; sh.barIndex=i; sh.strength=SWING_STRENGTH;
            sh.confirmed=true; sh.volume=(long)iVolume(_Symbol,_Period,i);
            sh.objectName=MakeSwingObjectName(sh.time,sh.type); sh.qualityScore=0;
            sh.isStructuralPivot=false; sh.impulsePoints=0.0; sh.pivotID=0;
            AddSwing(sh);
         }
         if(IsSwingLow(i) && !SwingExistsAtBar(i, TREND_BEARISH))
         {
            SwingPoint sl; sl.time=iTime(_Symbol,_Period,i); sl.price=iLow(_Symbol,_Period,i);
            sl.type=TREND_BEARISH; sl.barIndex=i; sl.strength=SWING_STRENGTH;
            sl.confirmed=true; sl.volume=(long)iVolume(_Symbol,_Period,i);
            sl.objectName=MakeSwingObjectName(sl.time,sl.type); sl.qualityScore=0;
            sl.isStructuralPivot=false; sl.impulsePoints=0.0; sl.pivotID=0;
            AddSwing(sl);
         }
      }
      ValidateAlternatingStructure();
       m_logger.Debug("SwingDetector v3 ready - " + IntegerToString(GetSwingCount()) + " swings, " + IntegerToString(GetStructuralPivotCount()) + " pivots");
      m_initialized = true; m_initialScanDone = true;
      return true;
   }

   void Update()
   {
      if(!m_initialized || !m_initialScanDone) return;
      if(!IsNewBar()) return;
      int ci = SWING_STRENGTH + 1;
      if(ci + SWING_STRENGTH >= Bars(_Symbol, _Period)) return;
      if(IsSwingHigh(ci) && !SwingExistsAtBar(ci, TREND_BULLISH))
      {
         SwingPoint sh; sh.time=iTime(_Symbol,_Period,ci); sh.price=iHigh(_Symbol,_Period,ci);
         sh.type=TREND_BULLISH; sh.barIndex=ci; sh.strength=SWING_STRENGTH;
         sh.confirmed=true; sh.volume=(long)iVolume(_Symbol,_Period,ci);
         sh.objectName=MakeSwingObjectName(sh.time,sh.type); sh.qualityScore=0;
         sh.isStructuralPivot=false; sh.impulsePoints=0.0; sh.pivotID=0;
         AddSwing(sh);
      }
      if(IsSwingLow(ci) && !SwingExistsAtBar(ci, TREND_BEARISH))
      {
         SwingPoint sl; sl.time=iTime(_Symbol,_Period,ci); sl.price=iLow(_Symbol,_Period,ci);
         sl.type=TREND_BEARISH; sl.barIndex=ci; sl.strength=SWING_STRENGTH;
         sl.confirmed=true; sl.volume=(long)iVolume(_Symbol,_Period,ci);
         sl.objectName=MakeSwingObjectName(sl.time,sl.type); sl.qualityScore=0;
         sl.isStructuralPivot=false; sl.impulsePoints=0.0; sl.pivotID=0;
         AddSwing(sl);
      }
   }

   SwingPoint DetectSwingHigh(int bi)
   {
      SwingPoint r = {0};
      if(!m_initialized || !IsSwingHigh(bi)) return r;
      r.time=iTime(_Symbol,_Period,bi); r.price=iHigh(_Symbol,_Period,bi);
      r.type=TREND_BULLISH; r.barIndex=bi; r.strength=SWING_STRENGTH;
      r.confirmed=true; r.volume=(long)iVolume(_Symbol,_Period,bi);
      r.objectName=MakeSwingObjectName(r.time,r.type); r.qualityScore=0;
      r.isStructuralPivot=false; r.impulsePoints=0.0; r.pivotID=0;
      return r;
   }

   SwingPoint DetectSwingLow(int bi)
   {
      SwingPoint r = {0};
      if(!m_initialized || !IsSwingLow(bi)) return r;
      r.time=iTime(_Symbol,_Period,bi); r.price=iLow(_Symbol,_Period,bi);
      r.type=TREND_BEARISH; r.barIndex=bi; r.strength=SWING_STRENGTH;
      r.confirmed=true; r.volume=(long)iVolume(_Symbol,_Period,bi);
      r.objectName=MakeSwingObjectName(r.time,r.type); r.qualityScore=0;
      r.isStructuralPivot=false; r.impulsePoints=0.0; r.pivotID=0;
      return r;
   }

   double GetLatestStructuralHigh()
   {
      for(int i = m_highCount - 1; i >= 0; i--)
         if(m_swingHighs[i].isStructuralPivot) return m_swingHighs[i].price;
      return 0.0;
   }

   double GetLatestStructuralLow()
   {
      for(int i = m_lowCount - 1; i >= 0; i--)
         if(m_swingLows[i].isStructuralPivot) return m_swingLows[i].price;
      return 0.0;
   }

   SwingPoint GetLatestStructuralHighPivot();

   SwingPoint GetLatestStructuralLowPivot();

   SwingPoint GetLatestHigh() { SwingPoint e={0}; return (m_highCount>0) ? m_swingHighs[m_highCount-1] : e; }
   SwingPoint GetLatestLow() { SwingPoint e={0}; return (m_lowCount>0) ? m_swingLows[m_lowCount-1] : e; }
   int GetSwingCount() { return m_highCount + m_lowCount; }
   int GetSwingHighCount() { return m_highCount; }
   int GetSwingLowCount() { return m_lowCount; }
   SwingPoint GetSwingHigh(int index) { SwingPoint e={0}; if(index>=0 && index<m_highCount) return m_swingHighs[index]; return e; }
   SwingPoint GetSwingLow(int index) { SwingPoint e={0}; if(index>=0 && index<m_lowCount) return m_swingLows[index]; return e; }
   int GetStructuralPivotCount()
   {
      int c = 0;
      for(int i=0; i<m_highCount; i++) if(m_swingHighs[i].isStructuralPivot) c++;
      for(int i=0; i<m_lowCount; i++) if(m_swingLows[i].isStructuralPivot) c++;
      return c;
   }
   int GetConfirmedSwingCount()
   {
      int c = 0;
      for(int i=0; i<m_highCount; i++) if(m_swingHighs[i].confirmed) c++;
      for(int i=0; i<m_lowCount; i++) if(m_swingLows[i].confirmed) c++;
      return c;
   }
   int GetStructuralHighCount()
   {
      int c = 0;
      for(int i=0; i<m_highCount; i++) if(m_swingHighs[i].isStructuralPivot) c++;
      return c;
   }
   int GetStructuralLowCount()
   {
      int c = 0;
      for(int i=0; i<m_lowCount; i++) if(m_swingLows[i].isStructuralPivot) c++;
      return c;
   }
   bool IsInitialized() { return m_initialized; }

   //--- SPRINT 4.4: Diagnostic getters ---
   int GetHighsDetected() { return m_highsDetected; }
   int GetHighsPromoted() { return m_highsPromoted; }
   int GetHighsRejected() { return m_highsRejected; }
   int GetLowsDetected() { return m_lowsDetected; }
   int GetLowsPromoted() { return m_lowsPromoted; }
   int GetLowsRejected() { return m_lowsRejected; }
   int GetRejectionReasonCount() { return ArraySize(m_rejectionReasons); }
   string GetRejectionReason(int index) { return (index>=0 && index<ArraySize(m_rejectionReasons)) ? m_rejectionReasons[index] : ""; }
   int GetRejectionCount(int index) { return (index>=0 && index<ArraySize(m_rejectionCounts)) ? m_rejectionCounts[index] : 0; }

   //--- SPRINT 4.5: Promotion verification getters ---
   int GetSPHCreated() { return m_sphCreated; }
   int GetSPLCreated() { return m_splCreated; }
   int GetPromotionAttempts() { return m_promotionAttempts; }
   int GetPromotionSuccess() { return m_promotionSuccess; }
   int GetPromotionFailed() { return m_promotionFailed; }
   int GetReevaluationSkipped() { return m_reevaluationSkipped; }
   int GetImpulseBelowThreshold() { return m_impulseBelowThreshold; }
   int GetImpulseAboveThreshold() { return m_impulseAboveThreshold; }
   int GetFirstEvaluations() { return m_firstEvaluations; }
   
   //--- SPRINT 4.8: BOS symmetry getters ---
   int GetSPHBroken() { return m_sphBroken; }
   int GetSPHNeverBroken() { return m_sphNeverBroken; }
   int GetSPLBroken() { return m_splBroken; }
   int GetSPLNeverBroken() { return m_splNeverBroken; }
   
   //--- SPRINT 4.8: BOS symmetry lifecycle methods ---
   void IncrementSPHBroken() { m_sphBroken++; }
   void IncrementSPLBroken() { m_splBroken++; }
   void CalculateNeverBroken()
   {
      m_sphNeverBroken = m_sphCreated - m_sphBroken;
      m_splNeverBroken = m_splCreated - m_splBroken;
   }

   void PrintShutdownReport()
   {
      m_logger.Info("===============================");
      m_logger.Info("SPRINT 4.4 - SPH INVESTIGATION REPORT");
      m_logger.Info("===============================");
      m_logger.Info("Swing Highs Detected: " + IntegerToString(m_highsDetected));
      m_logger.Info("Swing Highs Promoted: " + IntegerToString(m_highsPromoted));
      m_logger.Info("Swing Highs Rejected: " + IntegerToString(m_highsRejected));
      m_logger.Info("Swing Lows Detected: " + IntegerToString(m_lowsDetected));
      m_logger.Info("Swing Lows Promoted: " + IntegerToString(m_lowsPromoted));
      m_logger.Info("Swing Lows Rejected: " + IntegerToString(m_lowsRejected));
      m_logger.Info("===============================");
      m_logger.Info("REJECTION BREAKDOWN");
      m_logger.Info("===============================");
      int total = ArraySize(m_rejectionReasons);
      for(int i = 0; i < total; i++)
      {
         m_logger.Info("  " + IntegerToString(i+1) + ". " + m_rejectionReasons[i] + ": " + IntegerToString(m_rejectionCounts[i]));
      }
      if(total == 0)
      {
         m_logger.Info("  (no rejections recorded)");
      }
      m_logger.Info("===============================");
      m_logger.Info("STRUCTURAL PIVOT SUMMARY");
      m_logger.Info("===============================");
      m_logger.Info("Total Structural Pivots: " + IntegerToString(GetStructuralPivotCount()));
      m_logger.Info("Structural Highs (SPH): " + IntegerToString(GetStructuralHighCount()));
      m_logger.Info("Structural Lows (SPL): " + IntegerToString(GetStructuralLowCount()));
      m_logger.Info("===============================");
      
      //--- SPRINT 4.5: Structural Pivot Promotion Verification Report ---
      m_logger.Info("========================================");
      m_logger.Info("SPRINT 4.5 STRUCTURAL VERIFICATION");
      m_logger.Info("========================================");
      m_logger.Info("Swing Highs: " + IntegerToString(m_highsDetected));
      m_logger.Info("Swing Lows: " + IntegerToString(m_lowsDetected));
      m_logger.Info("Promotion Attempts: " + IntegerToString(m_promotionAttempts));
      m_logger.Info("Promotion Success: " + IntegerToString(m_promotionSuccess));
      m_logger.Info("Promotion Failed: " + IntegerToString(m_promotionFailed));
      m_logger.Info("SPH: " + IntegerToString(m_sphCreated));
      m_logger.Info("SPL: " + IntegerToString(m_splCreated));
      m_logger.Info("First Evaluations: " + IntegerToString(m_firstEvaluations));
      m_logger.Info("Re-evaluations Skipped: " + IntegerToString(m_reevaluationSkipped));
      m_logger.Info("Below Threshold: " + IntegerToString(m_impulseBelowThreshold));
      m_logger.Info("Above Threshold: " + IntegerToString(m_impulseAboveThreshold));
      m_logger.Info("========================================");
      
      //--- SPRINT 4.5: Final Conclusion ---
      m_logger.Info("RESULT:");
      if(m_reevaluationSkipped > 0)
      {
         m_logger.Info("Structural Pivot promotion evaluates each swing only once.");
         m_logger.Info("Later market movement can never promote previously rejected pivots.");
         m_logger.Info("Algorithm limitation confirmed.");
      }
      else
      {
         m_logger.Info("Structural Pivot promotion behaves exactly as designed.");
         m_logger.Info("No further action recommended.");
      }
      m_logger.Info("========================================");
      
      //--- SPRINT 4.8: BOS Symmetry Report ---
      m_logger.Info("==============================");
      m_logger.Info("BOS SYMMETRY REPORT");
      m_logger.Info("==============================");
      m_logger.Info("SPH Created: " + IntegerToString(m_sphCreated));
      m_logger.Info("SPH Broken: " + IntegerToString(m_sphBroken));
      m_logger.Info("SPH Never Broken: " + IntegerToString(m_sphNeverBroken));
      m_logger.Info("");
      m_logger.Info("SPL Created: " + IntegerToString(m_splCreated));
      m_logger.Info("SPL Broken: " + IntegerToString(m_splBroken));
      m_logger.Info("SPL Never Broken: " + IntegerToString(m_splNeverBroken));
      m_logger.Info("==============================");
   }

    void Clear()
    {
       Helpers::DeleteObjectsByPrefix(SMA_OBJ_SWING);
       m_highCount = 0; m_lowCount = 0;
       m_pivotCounter = 0;
       ArrayResize(m_swingHighs, MAX_STORED_SWINGS);
       ArrayResize(m_swingLows, MAX_STORED_SWINGS);
       
       // SPRINT 4.3: Log pivot counter reset
       m_logger.Debug("SwingDetector cleared - pivot counter reset to 0");
    }

   bool EvaluateStructuralPivot(SwingPoint &swing)
   {
      m_logger.Verbose("=== EVALUATE STRUCTURAL PIVOT ===");
      m_logger.Verbose("Bar: " + IntegerToString(swing.barIndex) + " | Price: " + Helpers::FormatPrice(swing.price) + " | Type: " + ((swing.type==TREND_BULLISH)?"HIGH":"LOW"));
      m_logger.Verbose("isStructuralPivot: " + (swing.isStructuralPivot?"true":"false") + " | confirmed: " + (swing.confirmed?"true":"false") + " | impulsePoints: " + Helpers::FormatPrice(swing.impulsePoints) + " | minRequired: " + Helpers::FormatPrice(m_minImpulsePoints));

      if(swing.isStructuralPivot)
      {
         m_logger.Verbose(">>> EVALUATION RESULT: Already structural pivot <<<");
         return true;
      }
      if(!swing.confirmed)
      {
         m_logger.Verbose(">>> EVALUATION RESULT: Not confirmed <<<");
         TrackRejection((swing.type==TREND_BULLISH)?"SPH: Not confirmed":"SPL: Not confirmed");
         return false;
      }
      if(swing.impulsePoints < m_minImpulsePoints)
      {
         m_logger.Verbose(">>> EVALUATION RESULT: Impulse below threshold <<<");
         TrackRejection((swing.type==TREND_BULLISH)?"SPH: Impulse below threshold":"SPL: Impulse below threshold");
         return false;
      }
      m_logger.Info(">>> EVALUATION RESULT: PROMOTING <<<");
      DoPromoteToStructuralPivot(swing);
      return true;
   }

   void PromoteToStructuralPivot(SwingPoint &swing)
   {
      m_logger.Verbose("=== PROMOTE TO STRUCTURAL PIVOT (external call) ===");
      m_logger.Verbose("Bar: " + IntegerToString(swing.barIndex) + " | Price: " + Helpers::FormatPrice(swing.price) + " | Type: " + ((swing.type==TREND_BULLISH)?"HIGH":"LOW"));
      m_logger.Verbose("isStructuralPivot: " + (swing.isStructuralPivot?"true":"false") + " | impulsePoints: " + Helpers::FormatPrice(swing.impulsePoints));

      if(swing.isStructuralPivot)
      {
         m_logger.Verbose(">>> ALREADY STRUCTURAL PIVOT - SKIPPING <<<");
         return;
      }
      if(swing.impulsePoints == 0.0)
      {
         SwingPoint opp = GetLastOppositeSwing(swing.type);
         m_logger.Verbose("Impulse is 0, calculating from opposite swing...");
         if(opp.time != 0)
         {
            swing.impulsePoints = DoCalculateImpulse(swing, opp);
            m_logger.Verbose("Calculated Impulse: " + Helpers::FormatPrice(swing.impulsePoints));
         }
         else
         {
            m_logger.Verbose("No opposite swing found - impulse remains 0");
         }
      }
      DoPromoteToStructuralPivot(swing);
   }

   double CalculateImpulse(const SwingPoint &from, const SwingPoint &to)
   {
      return DoCalculateImpulse(from, to);
   }

   bool ValidateAlternatingStructure()
   {
       m_logger.Debug("Validating structure...");
      int hc=m_highCount, lc=m_lowCount;
      if(MathAbs(hc-lc) > 1) { m_logger.Warning("Imbalanced"); return false; }
      for(int i=0; i<hc-1; i++) for(int j=i+1; j<hc; j++) if(m_swingHighs[i].barIndex==m_swingHighs[j].barIndex) { m_logger.Warning("Duplicate high"); return false; }
      for(int i=0; i<lc-1; i++) for(int j=i+1; j<lc; j++) if(m_swingLows[i].barIndex==m_swingLows[j].barIndex) { m_logger.Warning("Duplicate low"); return false; }
      for(int i=0; i<hc; i++) if(m_swingHighs[i].isStructuralPivot && !m_swingHighs[i].confirmed) { m_logger.Error("Structural pivot not confirmed!"); return false; }
      for(int i=0; i<lc; i++) if(m_swingLows[i].isStructuralPivot && !m_swingLows[i].confirmed) { m_logger.Error("Structural pivot not confirmed!"); return false; }
       int ids[]; ArrayResize(ids, 0);
       for(int i=0; i<hc; i++)
       {
          if(m_swingHighs[i].isStructuralPivot && m_swingHighs[i].pivotID != 0)
          {
             // SPRINT 4.3.2: Check for duplicates with detailed logging
             for(int k=0; k<ArraySize(ids); k++)
             {
                if(ids[k] == m_swingHighs[i].pivotID)
                {
                   // DUPLICATE DETECTED - Log both pivots
                   m_logger.Error("==================================");
                   m_logger.Error("DUPLICATE PIVOT DETECTED");
                   m_logger.Error("==================================");
                   m_logger.Error("Existing Pivot:");
                   m_logger.Error("  ID: " + IntegerToString(m_swingHighs[i].pivotID));
                   m_logger.Error("  Type: SPH");
                   m_logger.Error("  Bar: " + IntegerToString(m_swingHighs[i].barIndex));
                   m_logger.Error("  Time: " + TimeToString(m_swingHighs[i].time));
                   m_logger.Error("  Price: " + Helpers::FormatPrice(m_swingHighs[i].price));
                   m_logger.Error("  Array Index: " + IntegerToString(i));
                   m_logger.Error("----------------------------");
                   m_logger.Error("Incoming Pivot:");
                   m_logger.Error("  ID: " + IntegerToString(ids[k]));
                   m_logger.Error("  Type: SPH");
                   m_logger.Error("  Bar: " + IntegerToString(m_swingHighs[k].barIndex));
                   m_logger.Error("  Time: " + TimeToString(m_swingHighs[k].time));
                   m_logger.Error("  Price: " + Helpers::FormatPrice(m_swingHighs[k].price));
                   m_logger.Error("  Array Index: " + IntegerToString(k));
                   m_logger.Error("==================================");
                   m_logger.Error("Duplicate Pivot ID!");
                   ArrayResize(ids,0);
                   return false;
                }
             }
             ArrayResize(ids, ArraySize(ids)+1); ids[ArraySize(ids)-1] = m_swingHighs[i].pivotID;
          }
       }
       for(int i=0; i<lc; i++)
       {
          if(m_swingLows[i].isStructuralPivot && m_swingLows[i].pivotID != 0)
          {
             // SPRINT 4.3.2: Check for duplicates with detailed logging
             for(int k=0; k<ArraySize(ids); k++)
             {
                if(ids[k] == m_swingLows[i].pivotID)
                {
                   // DUPLICATE DETECTED - Log both pivots
                   m_logger.Error("==================================");
                   m_logger.Error("DUPLICATE PIVOT DETECTED");
                   m_logger.Error("==================================");
                   m_logger.Error("Existing Pivot:");
                   m_logger.Error("  ID: " + IntegerToString(m_swingLows[i].pivotID));
                   m_logger.Error("  Type: SPL");
                   m_logger.Error("  Bar: " + IntegerToString(m_swingLows[i].barIndex));
                   m_logger.Error("  Time: " + TimeToString(m_swingLows[i].time));
                   m_logger.Error("  Price: " + Helpers::FormatPrice(m_swingLows[i].price));
                   m_logger.Error("  Array Index: " + IntegerToString(i));
                   m_logger.Error("----------------------------");
                   m_logger.Error("Incoming Pivot:");
                   m_logger.Error("  ID: " + IntegerToString(ids[k]));
                   m_logger.Error("  Type: SPL");
                   m_logger.Error("  Bar: " + IntegerToString(m_swingLows[k].barIndex));
                   m_logger.Error("  Time: " + TimeToString(m_swingLows[k].time));
                   m_logger.Error("  Price: " + Helpers::FormatPrice(m_swingLows[k].price));
                   m_logger.Error("  Array Index: " + IntegerToString(k));
                   m_logger.Error("==================================");
                   m_logger.Error("Duplicate Pivot ID!");
                   ArrayResize(ids,0);
                   return false;
                }
             }
             ArrayResize(ids, ArraySize(ids)+1); ids[ArraySize(ids)-1] = m_swingLows[i].pivotID;
          }
       }
      ArrayResize(ids, 0);
       m_logger.Debug("Structure valid");
      return true;
   }
};
//+------------------------------------------------------------------+
//| Function definitions for struct-returning methods                |
//+------------------------------------------------------------------+
SwingPoint SwingDetector::GetLatestStructuralHighPivot()
{
   SwingPoint ep = {0};
   for(int i = m_highCount - 1; i >= 0; i--)
      if(m_swingHighs[i].isStructuralPivot) return m_swingHighs[i];
   return ep;
}

SwingPoint SwingDetector::GetLatestStructuralLowPivot()
{
   SwingPoint ep = {0};
   for(int i = m_lowCount - 1; i >= 0; i--)
      if(m_swingLows[i].isStructuralPivot) return m_swingLows[i];
   return ep;
}
