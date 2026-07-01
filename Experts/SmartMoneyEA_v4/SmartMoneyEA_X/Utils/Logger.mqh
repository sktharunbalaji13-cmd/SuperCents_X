//+------------------------------------------------------------------+
//|                                                SmartMoneyEA_X    |
//|                                                    Logger.mqh    |
//|                                       Centralized Logging System|
//+------------------------------------------------------------------+
#property copyright "SmartMoneyEA_X"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include "Constants.mqh"
#include "Enums.mqh"

//+------------------------------------------------------------------+
//| CLASS: Logger                                                    |
//| Purpose: Centralized logging for all project modules.           |
//|          Writes to Experts journal and optional log files.      |
//+------------------------------------------------------------------+
class Logger
{
private:
   string            m_moduleName;     // Module name for log ID
   ENUM_LOG_LEVEL    m_minLevel;       // Minimum log level to record
   int               m_logHandle;      // File handle for log file
   string            m_logFileName;    // Current log file name
   bool              m_fileLogging;    // Whether file logging is enabled

    //+------------------------------------------------------------------+
    //| Get string for log level                                         |
    //+------------------------------------------------------------------+
    string LevelToString(ENUM_LOG_LEVEL level)
    {
       switch(level)
       {
          case LOG_NONE:     return "NONE";
          case LOG_ERROR:    return "ERROR";
          case LOG_WARNING:  return "WARN";
          case LOG_INFO:     return "INFO";
          case LOG_DEBUG:    return "DEBUG";
          case LOG_VERBOSE:  return "VERBOSE";
          default:           return "UNKNOWN";
       }
    }

   //+------------------------------------------------------------------+
   //| Format message with timestamp and level                          |
   //+------------------------------------------------------------------+
   string FormatMessage(ENUM_LOG_LEVEL level, string message)
   {
      string ts = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
      return StringFormat("[%s] [%s] [%s] %s", ts, m_moduleName, LevelToString(level), message);
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                     |
   //+------------------------------------------------------------------+
   Logger(string moduleName = "Core")
   {
      m_moduleName = moduleName;
      m_minLevel = InpLogLevel;  // Use global input parameter
      m_logHandle = INVALID_HANDLE;
      m_fileLogging = false;
      m_logFileName = "";
   }

   //+------------------------------------------------------------------+
   //| Destructor - closes log file if open                             |
   //+------------------------------------------------------------------+
   ~Logger()
   {
      if(m_logHandle != INVALID_HANDLE)
      {
         FileClose(m_logHandle);
         m_logHandle = INVALID_HANDLE;
      }
   }

   //+------------------------------------------------------------------+
   //| Enable file logging                                              |
   //+------------------------------------------------------------------+
   void EnableFileLogging(bool enable)
   {
      m_fileLogging = enable;
      if(enable && m_logHandle == INVALID_HANDLE)
      {
         m_logFileName = SMA_LOG_DIR + m_moduleName + "_" +
                         IntegerToString(TimeCurrent()) + SMA_LOG_EXT;
         m_logHandle = FileOpen(m_logFileName, FILE_WRITE | FILE_TXT | FILE_COMMON);
      }
      else if(!enable && m_logHandle != INVALID_HANDLE)
      {
         FileClose(m_logHandle);
         m_logHandle = INVALID_HANDLE;
      }
   }

   //+------------------------------------------------------------------+
   //| Set minimum log level                                            |
   //+------------------------------------------------------------------+
   void SetMinimumLevel(ENUM_LOG_LEVEL level)
   {
      m_minLevel = level;
   }

   //+------------------------------------------------------------------+
   //| Log an info message                                              |
   //+------------------------------------------------------------------+
   void Info(string message)
   {
      Log(LOG_INFO, message);
   }

   //+------------------------------------------------------------------+
   //| Log a warning message                                            |
   //+------------------------------------------------------------------+
   void Warning(string message)
   {
      Log(LOG_WARNING, message);
   }

   //+------------------------------------------------------------------+
   //| Log an error message                                             |
   //+------------------------------------------------------------------+
   void Error(string message)
   {
      Log(LOG_ERROR, message);
   }

    //+------------------------------------------------------------------+
    //| Log a debug message                                              |
    //+------------------------------------------------------------------+
    void Debug(string message)
    {
       Log(LOG_DEBUG, message);
    }

    //+------------------------------------------------------------------+
    //| Log a verbose message                                            |
    //+------------------------------------------------------------------+
    void Verbose(string message)
    {
       Log(LOG_VERBOSE, message);
    }

    //+------------------------------------------------------------------+
    //| Core log method - writes to journal and optional file            |
    //+------------------------------------------------------------------+
   void Log(ENUM_LOG_LEVEL level, string message)
   {
      // Level filtering: only log if level <= minimum level
      // LOG_NONE (0) = log nothing
      // LOG_ERROR (1) = log only errors
      // LOG_WARNING (2) = log errors + warnings
      // LOG_INFO (3) = log errors + warnings + info
      // etc.
      if(level > m_minLevel)
         return;

      string formatted = FormatMessage(level, message);

      // Always print to Experts journal
      Print(formatted);

      // Optionally write to log file
      if(m_fileLogging && m_logHandle != INVALID_HANDLE)
      {
         FileWrite(m_logHandle, formatted);
         FileFlush(m_logHandle);
      }
   }
};
//+------------------------------------------------------------------+