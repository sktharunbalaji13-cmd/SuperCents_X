#ifndef __PRODUCTION_DIAGNOSTIC_ENGINE_MQH__
#define __PRODUCTION_DIAGNOSTIC_ENGINE_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "ProductionTypes.mqh"

#define MAX_DIAGNOSTIC_LINES 512

struct DiagnosticEntry
{
    datetime    timestamp;
    string      source;
    string      category;
    string      message;
    ulong       value;

    DiagnosticEntry(void)
        : timestamp(0), source(""), category(""), message(""), value(0)
    {}
};

class CDiagnosticEngine
{
private:
    CLogger         m_logger;
    bool            m_isInitialized;

    DiagnosticEntry m_entries[MAX_DIAGNOSTIC_LINES];
    int             m_entryCount;

public:
    CDiagnosticEngine(void);
    ~CDiagnosticEngine(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool EmitDiagnostic(const string source,
                        const string category,
                        const string message,
                        ulong value = 0);

    bool DumpState(const string filepath);
    bool GetDiagnosticLog(string &outLog) const;
    void Clear(void);
};

CDiagnosticEngine::CDiagnosticEngine(void)
    : m_logger(MODULE_UNKNOWN, "DiagnosticEngine")
    , m_isInitialized(false)
    , m_entryCount(0)
{
}

CDiagnosticEngine::~CDiagnosticEngine(void)
{
    Shutdown();
}

bool CDiagnosticEngine::Init(void)
{
    m_logger.LogInfo("Initializing DiagnosticEngine...");
    m_entryCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("DiagnosticEngine initialized");
    return true;
}

void CDiagnosticEngine::Shutdown(void)
{
    if(!m_isInitialized) return;
    Clear();
    m_isInitialized = false;
}

bool CDiagnosticEngine::EmitDiagnostic(const string source,
                                        const string category,
                                        const string message,
                                        ulong value)
{
    if(!m_isInitialized || m_entryCount >= MAX_DIAGNOSTIC_LINES)
        return false;

    DiagnosticEntry entry;
    entry.timestamp = TimeCurrent();
    entry.source = source;
    entry.category = category;
    entry.message = message;
    entry.value = value;

    m_entries[m_entryCount] = entry;
    m_entryCount++;

    return true;
}

bool CDiagnosticEngine::DumpState(const string filepath)
{
    int handle = FileOpen(filepath, FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(handle == INVALID_HANDLE)
        return false;

    FileWrite(handle, "# Diagnostic Dump");
    FileWrite(handle, StringFormat("# Time: %s", TimeToString(TimeCurrent())));
    FileWrite(handle, StringFormat("# Entries: %d", m_entryCount));
    FileWrite(handle, "");

    for(int i = 0; i < m_entryCount; i++)
    {
        FileWrite(handle, StringFormat("[%s] [%s] %s: %s (val=%llu)",
                                       TimeToString(m_entries[i].timestamp),
                                       m_entries[i].source,
                                       m_entries[i].category,
                                       m_entries[i].message,
                                       m_entries[i].value));
    }

    FileClose(handle);
    return true;
}

bool CDiagnosticEngine::GetDiagnosticLog(string &outLog) const
{
    outLog = "";
    for(int i = 0; i < m_entryCount; i++)
    {
        outLog += StringFormat("[%s] [%s] %s: %s (val=%llu)\n",
                               TimeToString(m_entries[i].timestamp),
                               m_entries[i].source,
                               m_entries[i].category,
                               m_entries[i].message,
                               m_entries[i].value);
    }
    return true;
}

void CDiagnosticEngine::Clear(void)
{
    m_entryCount = 0;
}

#endif
