//+------------------------------------------------------------------+
//|                                                SmartMoneyEA_X    |
//|                                                StateMachine.mqh  |
//|                                      Market Structure State Engine|
//+------------------------------------------------------------------+
#property copyright "SmartMoneyEA_X"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include "..\Utils\Logger.mqh"
#include "..\Utils\Enums.mqh"
#include "..\Utils\Constants.mqh"
#include "..\Utils\Helpers.mqh"
#include "..\Utils\Structures.mqh"

//+------------------------------------------------------------------+
//| Constants                                                        |
//+------------------------------------------------------------------+
#define MAX_BOS_HISTORY 500  // Maximum BOS history records

//+------------------------------------------------------------------+
//| CLASS: StateMachine                                              |
//| Purpose: Maintains market structure state based on confirmed BOS  |
//|          events. Implements finite state machine with 5 states.  |
//|          Sprint 4.1: Added BOS history tracking and statistics.  |
//+------------------------------------------------------------------+
class StateMachine
{
private:
    Logger                    m_logger;           // Module logger
    ENUM_MARKET_STRUCTURE_STATE m_currentState;   // Current market structure state
    ENUM_MARKET_STRUCTURE_STATE m_previousState;  // Previous market structure state
    bool                      m_initialized;      // Initialization flag
    bool                      m_stateChanged;     // State change flag

    //--- BOS History (Sprint 4.1) ---
    BOSHistoryRecord          m_bosHistory[];     // Circular buffer for BOS history
    int                       m_historyCount;      // Current number of records
    int                       m_historyWriteIndex; // Write pointer for circular buffer
    int                       m_sequenceCounter;   // Sequential BOS number

    //--- Statistics (Sprint 4.1) ---
    int                       m_totalBullishBOS;   // Total bullish BOS count
    int                       m_totalBearishBOS;   // Total bearish BOS count
    int                       m_consecutiveBullish; // Current consecutive bullish count
    int                       m_consecutiveBearish; // Current consecutive bearish count
    int                       m_longestBullishSeq;  // Longest bullish sequence
    int                       m_longestBearishSeq;  // Longest bearish sequence
    ENUM_TREND_STATE          m_lastBOSDirection;   // Last BOS direction
    ENUM_TREND_STATE          m_prevBOSDirection;   // Previous BOS direction
    datetime                  m_lastBOSTime;         // Last BOS time
    datetime                  m_prevBOSTime;         // Previous BOS time

    //+------------------------------------------------------------------+
    //| Convert market structure state to string                         |
    //+------------------------------------------------------------------+
    string StateToString(ENUM_MARKET_STRUCTURE_STATE state)
    {
       switch(state)
       {
          case MS_UNKNOWN:              return "UNKNOWN";
          case MS_BULLISH:              return "BULLISH";
          case MS_BEARISH:              return "BEARISH";
          case MS_TRANSITION_TO_BULLISH: return "TRANSITION_TO_BULLISH";
          case MS_TRANSITION_TO_BEARISH: return "TRANSITION_TO_BEARISH";
          default:                      return "UNKNOWN";
       }
    }

    //+------------------------------------------------------------------+
    //| Convert BOS direction to string                                  |
    //+------------------------------------------------------------------+
    string BOSDirectionToString(ENUM_TREND_STATE direction)
    {
       switch(direction)
       {
          case TREND_BULLISH:  return "BULLISH";
          case TREND_BEARISH:  return "BEARISH";
          default:             return "UNKNOWN";
       }
    }

    //+------------------------------------------------------------------+
    //| Log state transition                                             |
    //+------------------------------------------------------------------+
    void LogStateTransition(ENUM_TREND_STATE bosDirection, 
                           ENUM_MARKET_STRUCTURE_STATE prevState,
                           ENUM_MARKET_STRUCTURE_STATE newState,
                           string reason)
    {
       m_logger.Info("========================================================");
       m_logger.Info("STATE TRANSITION");
       m_logger.Info("========================================================");
       m_logger.Info("Current State: " + StateToString(m_currentState));
       m_logger.Info("Incoming BOS Direction: " + BOSDirectionToString(bosDirection));
       m_logger.Info("Previous State: " + StateToString(prevState));
       m_logger.Info("New State: " + StateToString(newState));
       m_logger.Info("Reason: " + reason);
       m_logger.Info("========================================================");
    }

    //+------------------------------------------------------------------+
    //| Log BOS event statistics (Sprint 4.1)                            |
    //+------------------------------------------------------------------+
    void LogBOSStatistics(const BOSEvent &bos)
    {
       m_logger.Debug("========================================================");
       m_logger.Debug("BOS EVENT RECORDED");
       m_logger.Debug("========================================================");
       m_logger.Debug("BOS Sequence Number: #" + IntegerToString(m_sequenceCounter));
       m_logger.Debug("BOS Direction: " + BOSDirectionToString(bos.direction));
       m_logger.Debug("Consecutive Bullish Count: " + IntegerToString(m_consecutiveBullish));
       m_logger.Debug("Consecutive Bearish Count: " + IntegerToString(m_consecutiveBearish));
       m_logger.Debug("Current Market State: " + StateToString(m_currentState));
       m_logger.Debug("Previous Market State: " + StateToString(m_previousState));
       m_logger.Debug("Total Bullish BOS: " + IntegerToString(m_totalBullishBOS));
       m_logger.Debug("Total Bearish BOS: " + IntegerToString(m_totalBearishBOS));
       m_logger.Debug("========================================================");
    }

    //+------------------------------------------------------------------+
    //| Log BOS history summary at shutdown (Sprint 4.1)                 |
    //+------------------------------------------------------------------+
    void LogBOSHistorySummary()
    {
       m_logger.Info("========================================================");
       m_logger.Info("=== BOS HISTORY SUMMARY ===");
       m_logger.Info("========================================================");
       m_logger.Info("Total BOS Events: " + IntegerToString(m_sequenceCounter - 1));
       m_logger.Info("Bullish BOS: " + IntegerToString(m_totalBullishBOS));
       m_logger.Info("Bearish BOS: " + IntegerToString(m_totalBearishBOS));
       m_logger.Info("Longest Bullish Sequence: " + IntegerToString(m_longestBullishSeq));
       m_logger.Info("Longest Bearish Sequence: " + IntegerToString(m_longestBearishSeq));
       m_logger.Info("========================================================");
    }

    //+------------------------------------------------------------------+
    //| Update BOS history and statistics (Sprint 4.1)                   |
    //+------------------------------------------------------------------+
    void UpdateBOSHistory(const BOSEvent &bos)
    {
       // Create history record
       BOSHistoryRecord record;
       record.sequenceNumber = m_sequenceCounter;
       record.direction = bos.direction;
       record.pivotID = bos.relatedPivotID;
       record.pivotPrice = bos.pivotPrice;
       record.breakPrice = bos.breakPrice;
       record.breakTime = bos.breakTime;
       record.previousState = m_previousState;
       record.newState = m_currentState;

       // Store in circular buffer
       if(m_historyCount < MAX_BOS_HISTORY)
       {
          // Buffer not full yet - add new record
          m_bosHistory[m_historyCount] = record;
          m_historyCount++;
       }
       else
       {
          // Buffer full - overwrite oldest record (circular buffer)
          m_bosHistory[m_historyWriteIndex] = record;
       }

       // Update write index (circular)
       m_historyWriteIndex = (m_historyWriteIndex + 1) % MAX_BOS_HISTORY;

       // Update sequence counter
       m_sequenceCounter++;

       // Update statistics
       if(bos.direction == TREND_BULLISH)
       {
          m_totalBullishBOS++;
          m_consecutiveBullish++;
          m_consecutiveBearish = 0; // Reset opposite counter

          // Track longest sequence
          if(m_consecutiveBullish > m_longestBullishSeq)
          {
             m_longestBullishSeq = m_consecutiveBullish;
          }
       }
       else if(bos.direction == TREND_BEARISH)
       {
          m_totalBearishBOS++;
          m_consecutiveBearish++;
          m_consecutiveBullish = 0; // Reset opposite counter

          // Track longest sequence
          if(m_consecutiveBearish > m_longestBearishSeq)
          {
             m_longestBearishSeq = m_consecutiveBearish;
          }
       }

       // Update last/previous BOS tracking
       m_prevBOSDirection = m_lastBOSDirection;
       m_lastBOSDirection = bos.direction;
       m_prevBOSTime = m_lastBOSTime;
       m_lastBOSTime = bos.breakTime;

       // Log statistics
       LogBOSStatistics(bos);
    }

public:
    //+------------------------------------------------------------------+
    //| Constructor                                                      |
    //+------------------------------------------------------------------+
    StateMachine()
    {
       m_logger = Logger("StateMachine");
       m_currentState = MS_UNKNOWN;
       m_previousState = MS_UNKNOWN;
       m_initialized = false;
       m_stateChanged = false;

       // Initialize history (Sprint 4.1)
       m_historyCount = 0;
       m_historyWriteIndex = 0;
       m_sequenceCounter = 1; // Start at 1 for first BOS

       // Initialize statistics (Sprint 4.1)
       m_totalBullishBOS = 0;
       m_totalBearishBOS = 0;
       m_consecutiveBullish = 0;
       m_consecutiveBearish = 0;
       m_longestBullishSeq = 0;
       m_longestBearishSeq = 0;
       m_lastBOSDirection = TREND_UNKNOWN;
       m_prevBOSDirection = TREND_UNKNOWN;
       m_lastBOSTime = 0;
       m_prevBOSTime = 0;

       ArrayResize(m_bosHistory, MAX_BOS_HISTORY);
    }

    //+------------------------------------------------------------------+
    //| Destructor                                                       |
    //+------------------------------------------------------------------+
    ~StateMachine()
    {
    }

    //+------------------------------------------------------------------+
    //| Initialize the state machine                                     |
    //| Returns true on success                                          |
    //+------------------------------------------------------------------+
    bool Init()
    {
       m_logger.Info("Market Structure State Engine initialized");
       m_logger.Info("Initial State: UNKNOWN");
       m_initialized = true;
       return true;
    }

    //+------------------------------------------------------------------+
    //| Update state machine with new BOS event                          |
    //| This is the core state transition logic                          |
    //+------------------------------------------------------------------+
    void Update(const BOSEvent &bos)
    {
       if(!m_initialized)
       {
          m_logger.Warning("StateMachine not initialized - ignoring BOS event");
          return;
       }

       // Store previous state
       m_previousState = m_currentState;
       ENUM_MARKET_STRUCTURE_STATE newState = m_currentState;
       string reason = "";
       bool stateChanged = false;

       // State transition logic based on current state and BOS direction
       switch(m_currentState)
       {
          case MS_UNKNOWN:
             if(bos.direction == TREND_BULLISH)
             {
                newState = MS_BULLISH;
                reason = "First BOS event - Bullish BOS from UNKNOWN state";
                stateChanged = true;
             }
             else if(bos.direction == TREND_BEARISH)
             {
                newState = MS_BEARISH;
                reason = "First BOS event - Bearish BOS from UNKNOWN state";
                stateChanged = true;
             }
             break;

          case MS_BULLISH:
             if(bos.direction == TREND_BULLISH)
             {
                // Remain in BULLISH state
                newState = MS_BULLISH;
                reason = "Bullish BOS confirms existing bullish structure";
                stateChanged = false;
             }
             else if(bos.direction == TREND_BEARISH)
             {
                // Transition to bearish
                newState = MS_TRANSITION_TO_BEARISH;
                reason = "Bearish BOS detected in bullish structure - initiating transition";
                stateChanged = true;
             }
             break;

          case MS_TRANSITION_TO_BEARISH:
             if(bos.direction == TREND_BEARISH)
             {
                // Transition complete - confirm bearish structure
                newState = MS_BEARISH;
                reason = "Second bearish BOS confirms transition to bearish structure";
                stateChanged = true;
             }
             else if(bos.direction == TREND_BULLISH)
             {
                // Bullish BOS during transition - revert to bullish
                newState = MS_BULLISH;
                reason = "Bullish BOS during transition - reverting to bullish structure";
                stateChanged = true;
             }
             break;

          case MS_BEARISH:
             if(bos.direction == TREND_BEARISH)
             {
                // Remain in BEARISH state
                newState = MS_BEARISH;
                reason = "Bearish BOS confirms existing bearish structure";
                stateChanged = false;
             }
             else if(bos.direction == TREND_BULLISH)
             {
                // Transition to bullish
                newState = MS_TRANSITION_TO_BULLISH;
                reason = "Bullish BOS detected in bearish structure - initiating transition";
                stateChanged = true;
             }
             break;

          case MS_TRANSITION_TO_BULLISH:
             if(bos.direction == TREND_BULLISH)
             {
                // Transition complete - confirm bullish structure
                newState = MS_BULLISH;
                reason = "Second bullish BOS confirms transition to bullish structure";
                stateChanged = true;
             }
             else if(bos.direction == TREND_BEARISH)
             {
                // Bearish BOS during transition - revert to bearish
                newState = MS_BEARISH;
                reason = "Bearish BOS during transition - reverting to bearish structure";
                stateChanged = true;
             }
             break;
       }

       // Update state if changed
       if(stateChanged)
       {
          LogStateTransition(bos.direction, m_previousState, newState, reason);
          m_currentState = newState;
          m_stateChanged = true;
       }

       // Update BOS history and statistics (Sprint 4.1)
       UpdateBOSHistory(bos);
    }

    //+------------------------------------------------------------------+
    //| Get the current market structure state                           |
    //+------------------------------------------------------------------+
    ENUM_MARKET_STRUCTURE_STATE GetCurrentState()
    {
       return m_currentState;
    }

    //+------------------------------------------------------------------+
    //| Get the previous market structure state                          |
    //+------------------------------------------------------------------+
    ENUM_MARKET_STRUCTURE_STATE GetPreviousState()
    {
       return m_previousState;
    }

    //+------------------------------------------------------------------+
    //| Reset state machine to initial state                             |
    //+------------------------------------------------------------------+
    void Reset()
    {
       m_logger.Info("Resetting StateMachine to UNKNOWN");
       m_previousState = m_currentState;
       m_currentState = MS_UNKNOWN;
       m_stateChanged = true;
    }

    //+------------------------------------------------------------------+
    //| Check if state has changed since last update                     |
    //+------------------------------------------------------------------+
    bool HasStateChanged()
    {
       return m_stateChanged;
    }

    //+------------------------------------------------------------------+
    //| Clear state change flag (call after checking)                    |
    //+------------------------------------------------------------------+
    void ClearStateChangeFlag()
    {
       m_stateChanged = false;
    }

    //+------------------------------------------------------------------+
    //| Returns whether the machine is initialized                       |
    //+------------------------------------------------------------------+
    bool IsInitialized()
    {
       return m_initialized;
    }

    //+------------------------------------------------------------------+
    //| BOS History Functions (Sprint 4.1)                               |
    //+------------------------------------------------------------------+

    //+------------------------------------------------------------------+
    //| Get BOS history record by index                                  |
    //+------------------------------------------------------------------+
    BOSHistoryRecord GetBOSHistoryRecord(int index)
    {
       BOSHistoryRecord empty = {0};
       
       if(index >= 0 && index < m_historyCount)
       {
          // Calculate actual index in circular buffer
          int actualIndex = (m_historyWriteIndex - m_historyCount + index + MAX_BOS_HISTORY) % MAX_BOS_HISTORY;
          return m_bosHistory[actualIndex];
       }
       
       return empty;
    }

    //+------------------------------------------------------------------+
    //| Get total BOS history count                                      |
    //+------------------------------------------------------------------+
    int GetBOSHistoryCount()
    {
       return m_historyCount;
    }

    //+------------------------------------------------------------------+
    //| Get maximum history capacity                                     |
    //+------------------------------------------------------------------+
    int GetMaxHistorySize()
    {
       return MAX_BOS_HISTORY;
    }

    //+------------------------------------------------------------------+
    //| Statistics Getters (Sprint 4.1)                                  |
    //+------------------------------------------------------------------+

    //+------------------------------------------------------------------+
    //| Get total bullish BOS count                                      |
    //+------------------------------------------------------------------+
    int GetTotalBullishBOS()
    {
       return m_totalBullishBOS;
    }

    //+------------------------------------------------------------------+
    //| Get total bearish BOS count                                      |
    //+------------------------------------------------------------------+
    int GetTotalBearishBOS()
    {
       return m_totalBearishBOS;
    }

    //+------------------------------------------------------------------+
    //| Get current consecutive bullish BOS count                        |
    //+------------------------------------------------------------------+
    int GetConsecutiveBullishBOS()
    {
       return m_consecutiveBullish;
    }

    //+------------------------------------------------------------------+
    //| Get current consecutive bearish BOS count                        |
    //+------------------------------------------------------------------+
    int GetConsecutiveBearishBOS()
    {
       return m_consecutiveBearish;
    }

    //+------------------------------------------------------------------+
    //| Get longest bullish BOS sequence                                 |
    //+------------------------------------------------------------------+
    int GetLongestBullishSequence()
    {
       return m_longestBullishSeq;
    }

    //+------------------------------------------------------------------+
    //| Get longest bearish BOS sequence                                 |
    //+------------------------------------------------------------------+
    int GetLongestBearishSequence()
    {
       return m_longestBearishSeq;
    }

    //+------------------------------------------------------------------+
    //| Get last BOS direction                                           |
    //+------------------------------------------------------------------+
    ENUM_TREND_STATE GetLastBOSDirection()
    {
       return m_lastBOSDirection;
    }

    //+------------------------------------------------------------------+
    //| Get previous BOS direction                                       |
    //+------------------------------------------------------------------+
    ENUM_TREND_STATE GetPreviousBOSDirection()
    {
       return m_prevBOSDirection;
    }

    //+------------------------------------------------------------------+
    //| Get last BOS time                                                |
    //+------------------------------------------------------------------+
    datetime GetLastBOSTime()
    {
       return m_lastBOSTime;
    }

    //+------------------------------------------------------------------+
    //| Get previous BOS time                                            |
    //+------------------------------------------------------------------+
    datetime GetPreviousBOSTime()
    {
       return m_prevBOSTime;
    }

    //+------------------------------------------------------------------+
    //| Get current BOS sequence number                                  |
    //+------------------------------------------------------------------+
    int GetCurrentSequenceNumber()
    {
       return m_sequenceCounter;
    }

    //+------------------------------------------------------------------+
    //| Print BOS history summary (called at shutdown)                   |
    //+------------------------------------------------------------------+
    void PrintBOSHistorySummary()
    {
       LogBOSHistorySummary();
    }
};
//+------------------------------------------------------------------+