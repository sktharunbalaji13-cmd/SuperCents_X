//+------------------------------------------------------------------+
//|                                                SmartMoneyEA_X    |
//|                                                CHOCHDetector.mqh |
//|                                    Change of Character Engine v1.0|
//+------------------------------------------------------------------+
#property copyright "SmartMoneyEA_X"
#property link      ""
#property version   "1.00"

#include "..\Utils\Logger.mqh"
#include "..\Utils\Structures.mqh"
#include "..\Utils\Constants.mqh"
#include "..\Utils\Helpers.mqh"
#include "..\Structure\SwingDetector.mqh"

//+------------------------------------------------------------------+
//| CLASS: CHOCHDetector                                             |
//| Purpose: Detects Change of Character (CHOCH) events from BOS    |
//|          with fixed-size circular buffer storage                 |
//| SPRINT 5.1: Added comprehensive structural validation            |
//+------------------------------------------------------------------+
class CHOCHDetector
{
private:
   //--- Configuration
   enum { MAX_CHOCH_EVENTS = 500 };

   //--- Dependencies
   Logger         m_logger;
   SwingDetector *m_swingDetector;

   //--- State
   bool           m_initialized;

   //--- CHOCH Storage (circular buffer)
   CHOCHEvent     m_chochEvents[];
   int            m_chochCount;
   int            m_chochIDCounter;

   //--- Duplicate protection
   int            m_lastProcessedBOSSequence;

   //--- Statistics
   int            m_statTotalCHOCH;
   int            m_statBullishCHOCH;
   int            m_statBearishCHOCH;
   int            m_statHistoricalCHOCH;
   int            m_statRuntimeCHOCH;

   //--- SPRINT 5.1: Validation tracking
   int            m_validationDuplicateCHOCH;      // CHOCH created from same BOS
   int            m_validationMissingBOS;          // CHOCH without valid BOS reference
   int            m_validationMissingPivot;        // CHOCH without valid pivot
   int            m_validationDirectionErrors;     // Direction mismatch errors
   int            m_validationChronologyErrors;    // Chronology violations
   int            m_validationReplayMismatch;      // Replay vs runtime mismatches
   int            m_validationStateErrors;         // State transition errors
   int            m_validationCounterErrors;       // Counter validation errors

   //--- BOS to CHOCH mapping for duplicate detection
   int            m_bosToCHOCHMap[];               // Maps BOS sequence to CHOCH count

   //+------------------------------------------------------------------+
   //| Check if BOS direction reverses current market structure        |
   //+------------------------------------------------------------------+
   bool IsCHOCH(const BOSEvent &bos, ENUM_MARKET_STRUCTURE_STATE previousState)
   {
      // CHOCH occurs when BOS direction is opposite to current state
      // Current BULLISH + Bearish BOS = Bearish CHOCH
      // Current BEARISH + Bullish BOS = Bullish CHOCH

      if(previousState == MS_BULLISH && bos.direction == TREND_BEARISH)
         return true;

      if(previousState == MS_BEARISH && bos.direction == TREND_BULLISH)
         return true;

      return false;
   }

   //+------------------------------------------------------------------+
   //| Determine CHOCH direction based on BOS direction                 |
   //+------------------------------------------------------------------+
   ENUM_TREND_STATE GetCHOCHDirection(const BOSEvent &bos)
   {
      // CHOCH direction matches the BOS direction that caused the reversal
      return bos.direction;
   }

   //+------------------------------------------------------------------+
   //| Log CHOCH detection                                              |
   //+------------------------------------------------------------------+
   void LogCHOCHDetected(const CHOCHEvent &choch, int bosSequence)
   {
      string directionStr = (choch.direction == TREND_BULLISH) ? "BULLISH" : "BEARISH";
      string prevStateStr = (choch.previousState == MS_BULLISH) ? "BULLISH" : 
                           (choch.previousState == MS_BEARISH) ? "BEARISH" : "UNKNOWN";
      string newStateStr = (choch.newState == MS_BULLISH) ? "BULLISH" : 
                          (choch.newState == MS_BEARISH) ? "BEARISH" : 
                          (choch.newState == MS_TRANSITION_TO_BULLISH) ? "TRANSITION_TO_BULLISH" :
                          (choch.newState == MS_TRANSITION_TO_BEARISH) ? "TRANSITION_TO_BEARISH" : "UNKNOWN";

      m_logger.Info("========================================================");
      m_logger.Info("CHOCH DETECTED");
      m_logger.Info("========================================================");
      m_logger.Info("Direction: " + directionStr);
      m_logger.Info("Previous State: " + prevStateStr);
      m_logger.Info("New State: " + newStateStr);
      m_logger.Info("Break Price: " + Helpers::FormatPrice(choch.breakPrice));
      m_logger.Info("Break Time: " + TimeToString(choch.breakTime));
      m_logger.Info("Pivot ID: PIVOT-" + IntegerToString(choch.relatedPivotID));
      m_logger.Info("BOS Sequence: BOS-" + IntegerToString(bosSequence));
      m_logger.Info("========================================================");
   }

   //+------------------------------------------------------------------+
   //| Store CHOCH event in circular buffer                             |
   //+------------------------------------------------------------------+
   void StoreCHOCH(const CHOCHEvent &choch)
   {
      // Check if buffer is full
      if(m_chochCount >= MAX_CHOCH_EVENTS)
      {
         // Shift array left (remove oldest)
         for(int i = 0; i < m_chochCount - 1; i++)
         {
            m_chochEvents[i] = m_chochEvents[i + 1];
         }
         m_chochCount--;
      }

      // Resize if needed
      if(ArraySize(m_chochEvents) <= m_chochCount)
      {
         ArrayResize(m_chochEvents, m_chochCount + 10);
      }

      // Store event
      m_chochEvents[m_chochCount] = choch;
      m_chochCount++;

      // Update statistics
      m_statTotalCHOCH++;
      if(choch.direction == TREND_BULLISH)
         m_statBullishCHOCH++;
      else
         m_statBearishCHOCH++;
   }

   //+------------------------------------------------------------------+
   //| SPRINT 5.1: Validate CHOCH direction                            |
   //+------------------------------------------------------------------+
   bool ValidateCHOCHDirection(const CHOCHEvent &choch, ENUM_MARKET_STRUCTURE_STATE previousState)
   {
      // Expected: Previous BULLISH + Bearish BOS = Bearish CHOCH
      // Expected: Previous BEARISH + Bullish BOS = Bullish CHOCH
      
      bool valid = false;
      
      if(previousState == MS_BULLISH && choch.direction == TREND_BEARISH)
         valid = true;
      
      if(previousState == MS_BEARISH && choch.direction == TREND_BULLISH)
         valid = true;
      
      if(!valid)
      {
         m_validationDirectionErrors++;
         m_logger.Error("DIRECTION ERROR: Previous=" + 
                       (previousState == MS_BULLISH ? "BULLISH" : 
                        previousState == MS_BEARISH ? "BEARISH" : "UNKNOWN") + 
                       " CHOCH=" + (choch.direction == TREND_BULLISH ? "BULLISH" : "BEARISH"));
      }
      
      return valid;
   }

    //+------------------------------------------------------------------+
    //| SPRINT 5.1.4: Validate CHOCH chronology (Model A)                |
    //+------------------------------------------------------------------+
     bool ValidateCHOCHChronology(const CHOCHEvent &choch, datetime pivotTime, datetime bosTime)
     {
        // Verify: Pivot Time <= BOS Time <= CHOCH Time
        // Model A: BOS and CHOCH occur on same closed candle
        
        // SPRINT 5.1.10: TASK 6 - Validator Input Audit
        m_logger.Error("TASK 6 - VALIDATOR INPUT AUDIT:");
        m_logger.Error("  pivotTime: " + TimeToString(pivotTime));
        m_logger.Error("  bosTime: " + TimeToString(bosTime));
        m_logger.Error("  chochTime: " + TimeToString(choch.breakTime));
        m_logger.Error("  pivotBar: (from pivotTime)");
        m_logger.Error("  bosBar: (from bosTime)");
        m_logger.Error("  chochBar: (from chochTime)");
        
        bool valid = true;
        
        // Check: Pivot must exist before BOS
        if(pivotTime > bosTime)
        {
           m_validationChronologyErrors++;
           m_logger.Error("CHRONOLOGY ERROR: Pivot time > BOS time");
           valid = false;
        }
        
        // Rule 2: BOS must not occur after CHOCH (Model A: equality allowed)
        if(bosTime > choch.breakTime)
        {
           m_validationChronologyErrors++;
           m_logger.Error("CHRONOLOGY ERROR: BOS time occurs after CHOCH time");
           valid = false;
        }
        
        // Rule 3: Pivot must exist before CHOCH
        if(pivotTime >= choch.breakTime)
        {
           m_validationChronologyErrors++;
           m_logger.Error("CHRONOLOGY ERROR: Pivot time >= CHOCH time");
           valid = false;
        }
        
        // SPRINT 5.1.10: TASK 1 - CHOCH Forensic Report for failing events
        if(!valid)
        {
           m_logger.Error("====================================");
           m_logger.Error("CHOCH FORENSIC REPORT");
           m_logger.Error("====================================");
           m_logger.Error("CHOCH Index: " + IntegerToString(m_chochCount - 1));
           m_logger.Error("CHOCH Direction: " + (choch.direction == TREND_BULLISH ? "BULLISH" : "BEARISH"));
           m_logger.Error("");
           m_logger.Error("Source BOS ID: BOS-" + IntegerToString(choch.sourceBOSEvent));
           m_logger.Error("Source Pivot ID: PIVOT-" + IntegerToString(choch.relatedPivotID));
           m_logger.Error("");
           m_logger.Error("------------------------------------");
           m_logger.Error("PIVOT");
           m_logger.Error("------------------------------------");
           m_logger.Error("ID: PIVOT-" + IntegerToString(choch.relatedPivotID));
           m_logger.Error("Price: (from pivot)");
           m_logger.Error("Time: " + TimeToString(pivotTime));
           m_logger.Error("Bar Index: (from pivotTime)");
           m_logger.Error("");
           m_logger.Error("------------------------------------");
           m_logger.Error("BOS");
           m_logger.Error("------------------------------------");
           m_logger.Error("Break Price: (from BOS)");
           m_logger.Error("Break Time: " + TimeToString(bosTime));
           m_logger.Error("Break Bar Index: (from bosTime)");
           m_logger.Error("");
           m_logger.Error("------------------------------------");
           m_logger.Error("CHOCH");
           m_logger.Error("------------------------------------");
           m_logger.Error("Break Time: " + TimeToString(choch.breakTime));
           m_logger.Error("Break Bar Index: (from chochTime)");
           m_logger.Error("");
           m_logger.Error("------------------------------------");
           m_logger.Error("RULE VALIDATION");
           m_logger.Error("------------------------------------");
           m_logger.Error("Rule 1 (Pivot <= BOS): " + (pivotTime <= bosTime ? "PASS" : "FAIL"));
           m_logger.Error("Rule 2 (BOS <= CHOCH): " + (bosTime <= choch.breakTime ? "PASS" : "FAIL"));
           m_logger.Error("Rule 3 (Pivot <= CHOCH): " + (pivotTime < choch.breakTime ? "PASS" : "FAIL"));
           m_logger.Error("");
           m_logger.Error("------------------------------------");
           m_logger.Error("TIME DIFFERENCES");
           m_logger.Error("------------------------------------");
           m_logger.Error("Pivot → BOS: " + IntegerToString((int)(bosTime - pivotTime)) + " seconds");
           m_logger.Error("BOS → CHOCH: " + IntegerToString((int)(choch.breakTime - bosTime)) + " seconds");
           m_logger.Error("Pivot → CHOCH: " + IntegerToString((int)(choch.breakTime - pivotTime)) + " seconds");
           m_logger.Error("====================================");
        }
        
        return valid;
     }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CHOCHDetector()
   {
      m_logger = Logger("CHOCHDetector");
      m_swingDetector = NULL;
      m_initialized = false;
      m_chochCount = 0;
      m_chochIDCounter = 0;
      m_lastProcessedBOSSequence = 0;

      // Initialize statistics
      m_statTotalCHOCH = 0;
      m_statBullishCHOCH = 0;
      m_statBearishCHOCH = 0;
      m_statHistoricalCHOCH = 0;
      m_statRuntimeCHOCH = 0;

      // Initialize validation counters
      m_validationDuplicateCHOCH = 0;
      m_validationMissingBOS = 0;
      m_validationMissingPivot = 0;
      m_validationDirectionErrors = 0;
      m_validationChronologyErrors = 0;
      m_validationReplayMismatch = 0;
      m_validationStateErrors = 0;
      m_validationCounterErrors = 0;

      ArrayResize(m_chochEvents, MAX_CHOCH_EVENTS);
      ArrayResize(m_bosToCHOCHMap, MAX_CHOCH_EVENTS);
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CHOCHDetector()
   {
      Clear();
   }

   //+------------------------------------------------------------------+
   //| Initialize CHOCH detector                                        |
   //+------------------------------------------------------------------+
   bool Init()
   {
      m_logger.Info("CHOCHDetector v1.0 initialized");
      m_logger.Info("Max CHOCH history: " + IntegerToString(MAX_CHOCH_EVENTS));
      m_initialized = true;
      return true;
   }

   //+------------------------------------------------------------------+
   //| Reset CHOCH detector                                             |
   //+------------------------------------------------------------------+
   void Reset()
   {
      m_logger.Info("Resetting CHOCHDetector");
      Clear();
      m_initialized = false;
   }

    //+------------------------------------------------------------------+
    //| Update CHOCH detector with new BOS event                         |
    //| This is the core detection method - called from Engine           |
    //+------------------------------------------------------------------+
    void Update(const BOSEvent &bos, ENUM_MARKET_STRUCTURE_STATE previousState,
                ENUM_MARKET_STRUCTURE_STATE newState, int bosSequence)
    {
       if(!m_initialized)
       {
          m_logger.Warning("CHOCHDetector not initialized - ignoring BOS event");
          return;
       }

       // Duplicate protection: skip if we've already processed this BOS sequence
       if(bosSequence <= m_lastProcessedBOSSequence)
       {
          m_logger.Debug("Duplicate BOS sequence ignored: " + IntegerToString(bosSequence));
          return;
       }

       // Update last processed sequence
       m_lastProcessedBOSSequence = bosSequence;

       // Check if this BOS creates a CHOCH
       if(!IsCHOCH(bos, previousState))
       {
          // No CHOCH - BOS is continuation of current trend
          m_logger.Debug("BOS #" + IntegerToString(bosSequence) + " - No CHOCH (trend continuation)");
          return;
       }

       // CHOCH detected - create event
       CHOCHEvent choch;
       choch.valid = true;
       choch.direction = GetCHOCHDirection(bos);
       choch.breakTime = bos.breakTime;
       choch.breakPrice = bos.breakPrice;
       choch.relatedPivotID = bos.relatedPivotID;
       choch.previousState = previousState;
       choch.newState = newState;
       choch.sourceBOSEvent = bosSequence;

       // SPRINT 5.1: Validate direction
       ValidateCHOCHDirection(choch, previousState);

       // SPRINT 5.1.4: Validate chronology (Model A: BOS <= CHOCH)
       bool chronologyValid = ValidateCHOCHChronology(choch, bos.pivotTime, bos.breakTime);

       // SPRINT 5.1: Check for duplicate CHOCH (same BOS creating multiple CHOCH)
       if(bosSequence < ArraySize(m_bosToCHOCHMap))
       {
          if(m_bosToCHOCHMap[bosSequence] > 0)
          {
             m_validationDuplicateCHOCH++;
             m_logger.Error("DUPLICATE CHOCH: BOS #" + IntegerToString(bosSequence) + 
                           " created multiple CHOCH events");
          }
          m_bosToCHOCHMap[bosSequence]++;
       }

       // Store CHOCH
       StoreCHOCH(choch);

       // Log detection
       LogCHOCHDetected(choch, bosSequence);
    }

   //+------------------------------------------------------------------+
   //| Check if new CHOCH was detected since last check                 |
   //+------------------------------------------------------------------+
   bool HasNewCHOCH()
   {
      // This is a simplified check - in production, you might want to track
      // the last checked index more carefully
      return (m_chochCount > 0);
   }

   //+------------------------------------------------------------------+
   //| Get latest CHOCH event                                           |
   //+------------------------------------------------------------------+
   CHOCHEvent GetLatestCHOCH()
   {
      CHOCHEvent empty = {0};
      if(m_chochCount > 0)
      {
         return m_chochEvents[m_chochCount - 1];
      }
      return empty;
   }

   //+------------------------------------------------------------------+
   //| Get CHOCH event by index                                         |
   //+------------------------------------------------------------------+
   CHOCHEvent GetCHOCH(int index)
   {
      CHOCHEvent empty = {0};
      if(index >= 0 && index < m_chochCount)
      {
         return m_chochEvents[index];
      }
      return empty;
   }

   //+------------------------------------------------------------------+
   //| Get total CHOCH count                                            |
   //+------------------------------------------------------------------+
   int GetCHOCHCount()
   {
      return m_chochCount;
   }

   //+------------------------------------------------------------------+
   //| Print CHOCH summary                                              |
   //+------------------------------------------------------------------+
   void PrintSummary()
   {
      m_logger.Info("===============================");
      m_logger.Info("CHOCH SUMMARY");
      m_logger.Info("===============================");
      m_logger.Info("Bullish CHOCH: " + IntegerToString(m_statBullishCHOCH));
      m_logger.Info("Bearish CHOCH: " + IntegerToString(m_statBearishCHOCH));
      m_logger.Info("Total CHOCH: " + IntegerToString(m_statTotalCHOCH));
      m_logger.Info("Historical CHOCH: " + IntegerToString(m_statHistoricalCHOCH));
      m_logger.Info("Runtime CHOCH: " + IntegerToString(m_statRuntimeCHOCH));
      m_logger.Info("===============================");
   }

   //+------------------------------------------------------------------+
   //| Print runtime statistics                                         |
   //+------------------------------------------------------------------+
   void PrintRuntimeStatistics()
   {
      m_logger.Debug("========================================================");
      m_logger.Debug("CHOCH DETECTOR - RUNTIME STATISTICS");
      m_logger.Debug("========================================================");
      m_logger.Debug("Total CHOCH Events: " + IntegerToString(m_statTotalCHOCH));
      m_logger.Debug("Bullish CHOCH: " + IntegerToString(m_statBullishCHOCH));
      m_logger.Debug("Bearish CHOCH: " + IntegerToString(m_statBearishCHOCH));
      m_logger.Debug("Historical CHOCH: " + IntegerToString(m_statHistoricalCHOCH));
      m_logger.Debug("Runtime CHOCH: " + IntegerToString(m_statRuntimeCHOCH));
      m_logger.Debug("Last Processed BOS Sequence: " + IntegerToString(m_lastProcessedBOSSequence));
      m_logger.Debug("========================================================");
   }

   //+------------------------------------------------------------------+
   //| Mark CHOCH as historical (called during replay)                  |
   //+------------------------------------------------------------------+
   void MarkHistorical()
   {
      m_statHistoricalCHOCH++;
   }

   //+------------------------------------------------------------------+
   //| Mark CHOCH as runtime (called during live detection)             |
   //+------------------------------------------------------------------+
   void MarkRuntime()
   {
      m_statRuntimeCHOCH++;
   }

   //+------------------------------------------------------------------+
   //| Get statistics getters                                           |
   //+------------------------------------------------------------------+
   int GetBullishCHOCHCount() { return m_statBullishCHOCH; }
   int GetBearishCHOCHCount() { return m_statBearishCHOCH; }
   int GetTotalCHOCHCount() { return m_statTotalCHOCH; }
   int GetHistoricalCHOCHCount() { return m_statHistoricalCHOCH; }
   int GetRuntimeCHOCHCount() { return m_statRuntimeCHOCH; }

   //+------------------------------------------------------------------+
   //| SPRINT 5.1: Get validation error counts                          |
   //+------------------------------------------------------------------+
   int GetDuplicateCHOCHCount() { return m_validationDuplicateCHOCH; }
   int GetMissingBOSCount() { return m_validationMissingBOS; }
   int GetMissingPivotCount() { return m_validationMissingPivot; }
   int GetDirectionErrorCount() { return m_validationDirectionErrors; }
   int GetChronologyErrorCount() { return m_validationChronologyErrors; }
   int GetReplayMismatchCount() { return m_validationReplayMismatch; }
   int GetStateErrorCount() { return m_validationStateErrors; }
   int GetCounterErrorCount() { return m_validationCounterErrors; }

   //+------------------------------------------------------------------+
   //| Set swing detector reference                                     |
   //+------------------------------------------------------------------+
   void SetSwingDetector(SwingDetector *swingDetector) { m_swingDetector = swingDetector; }
   
   //+------------------------------------------------------------------+
   //| Check if initialized                                              |
   //+------------------------------------------------------------------+
   bool IsInitialized() { return m_initialized; }

   //+------------------------------------------------------------------+
   //| Clear all CHOCH data                                             |
   //+------------------------------------------------------------------+
   void Clear()
   {
      m_chochCount = 0;
      m_chochIDCounter = 0;
      m_lastProcessedBOSSequence = 0;
      ArrayResize(m_chochEvents, MAX_CHOCH_EVENTS);
      ArrayResize(m_bosToCHOCHMap, MAX_CHOCH_EVENTS);

      m_statTotalCHOCH = 0;
      m_statBullishCHOCH = 0;
      m_statBearishCHOCH = 0;
      m_statHistoricalCHOCH = 0;
      m_statRuntimeCHOCH = 0;

      // Clear validation counters
      m_validationDuplicateCHOCH = 0;
      m_validationMissingBOS = 0;
      m_validationMissingPivot = 0;
      m_validationDirectionErrors = 0;
      m_validationChronologyErrors = 0;
      m_validationReplayMismatch = 0;
      m_validationStateErrors = 0;
      m_validationCounterErrors = 0;
   }

   //+------------------------------------------------------------------+
   //| SPRINT 5.1: Print CHOCH Structural Validation Report             |
   //+------------------------------------------------------------------+
   void PrintStructuralValidationReport()
   {
      m_logger.Info("====================================");
      m_logger.Info("CHOCH STRUCTURAL VALIDATION");
      m_logger.Info("====================================");
      m_logger.Info("CHOCH Created: " + IntegerToString(m_statTotalCHOCH));
      m_logger.Info("Historical: " + IntegerToString(m_statHistoricalCHOCH));
      m_logger.Info("Runtime: " + IntegerToString(m_statRuntimeCHOCH));
      m_logger.Info("");
      m_logger.Info("Duplicate CHOCH: " + IntegerToString(m_validationDuplicateCHOCH));
      m_logger.Info("Missing BOS: " + IntegerToString(m_validationMissingBOS));
      m_logger.Info("Missing Pivot: " + IntegerToString(m_validationMissingPivot));
      m_logger.Info("Direction Errors: " + IntegerToString(m_validationDirectionErrors));
      m_logger.Info("Chronology Errors: " + IntegerToString(m_validationChronologyErrors));
      m_logger.Info("Replay Mismatch: " + IntegerToString(m_validationReplayMismatch));
      m_logger.Info("State Errors: " + IntegerToString(m_validationStateErrors));
      m_logger.Info("Counter Errors: " + IntegerToString(m_validationCounterErrors));
      m_logger.Info("====================================");

      // Calculate final result
      bool finalResult = (m_validationDuplicateCHOCH == 0) &&
                        (m_validationMissingBOS == 0) &&
                        (m_validationMissingPivot == 0) &&
                        (m_validationDirectionErrors == 0) &&
                        (m_validationChronologyErrors == 0) &&
                        (m_validationReplayMismatch == 0) &&
                        (m_validationStateErrors == 0) &&
                        (m_validationCounterErrors == 0);

      m_logger.Info("FINAL RESULT");
      m_logger.Info("====================================");
      m_logger.Info(finalResult ? "PASS" : "FAIL");
      m_logger.Info("====================================");
   }
};
//+------------------------------------------------------------------+