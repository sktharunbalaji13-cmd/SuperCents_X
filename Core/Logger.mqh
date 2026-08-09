//+------------------------------------------------------------------+
//|                                                   Logger.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __LOGGER_MQH__
#define __LOGGER_MQH__

#include "../Utils/Constants.mqh"

class CLogger
{
private:
    ENUM_MODULE_ID m_moduleId;
    string m_moduleName;
    bool m_enabled;

public:
    //--- Constructor
    CLogger(void);
    CLogger(ENUM_MODULE_ID moduleId, string moduleName);

    //--- Initialization
    void Init(ENUM_MODULE_ID moduleId, string moduleName);
    void SetEnabled(bool enabled);

    //--- Logging methods
    void LogDebug(string message);
    void LogInfo(string message);
    void LogWarn(string message);
    void LogError(string message);

private:
    string FormatMessage(ENUM_LOG_LEVEL level, string message) const;
    string LevelToString(ENUM_LOG_LEVEL level) const;
    void PrintMessage(string formattedMessage);
};

//--- Inline implementation
CLogger::CLogger(void) : m_moduleId(MODULE_UNKNOWN), m_moduleName("UNKNOWN"), m_enabled(true) {}

CLogger::CLogger(ENUM_MODULE_ID moduleId, string moduleName)
{
    Init(moduleId, moduleName);
}

void CLogger::Init(ENUM_MODULE_ID moduleId, string moduleName)
{
    m_moduleId = moduleId;
    m_moduleName = moduleName;
    m_enabled = true;
}

void CLogger::SetEnabled(bool enabled)
{
    m_enabled = enabled;
}

void CLogger::LogDebug(string message)
{
    if(m_enabled)
    {
        string formatted = FormatMessage(LOG_LEVEL_DEBUG, message);
        PrintMessage(formatted);
    }
}

void CLogger::LogInfo(string message)
{
    if(m_enabled)
    {
        string formatted = FormatMessage(LOG_LEVEL_INFO, message);
        PrintMessage(formatted);
    }
}

void CLogger::LogWarn(string message)
{
    if(m_enabled)
    {
        string formatted = FormatMessage(LOG_LEVEL_WARN, message);
        PrintMessage(formatted);
    }
}

void CLogger::LogError(string message)
{
    if(m_enabled)
    {
        string formatted = FormatMessage(LOG_LEVEL_ERROR, message);
        PrintMessage(formatted);
    }
}

string CLogger::FormatMessage(ENUM_LOG_LEVEL level, string message) const
{
    return StringFormat("[%s][%s] %s", m_moduleName, LevelToString(level), message);
}

string CLogger::LevelToString(ENUM_LOG_LEVEL level) const
{
    switch(level)
    {
        case LOG_LEVEL_DEBUG: return "DEBUG";
        case LOG_LEVEL_INFO:  return "INFO";
        case LOG_LEVEL_WARN:  return "WARN";
        case LOG_LEVEL_ERROR: return "ERROR";
        default:              return "UNKNOWN";
    }
}

void CLogger::PrintMessage(string formattedMessage)
{
    Print(formattedMessage);
}

#endif // __LOGGER_MQH__