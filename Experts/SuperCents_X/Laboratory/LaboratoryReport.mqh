#ifndef __LABORATORY_LABORATORY_REPORT_MQH__
#define __LABORATORY_LABORATORY_REPORT_MQH__

#include "../Core/Logger.mqh"
#include "LaboratoryTypes.mqh"
#include "LaboratoryManifest.mqh"

#define MAX_REPORT_BODY_LINES 4096

class CLaboratoryReport
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    LaboratoryManifest m_manifest;
    string             m_body[MAX_REPORT_BODY_LINES];
    int                m_bodyLineCount;
    string             m_filePath;

public:
    CLaboratoryReport(void);
    ~CLaboratoryReport(void);

    bool Init(const LaboratoryManifest &manifest, const string filePath);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool WriteLine(const string line);
    bool WriteSection(const string section);
    bool WriteBlankLine(void);

    bool Save(void);
    bool Load(const string filePath, LaboratoryManifest &outManifest,
              string &outBody[], int &outLineCount) const;

    int  GetLineCount(void) const { return m_bodyLineCount; }
    bool GetLine(int index, string &out) const;
    void Clear(void);

    string GetFilePath(void) const { return m_filePath; }
};

CLaboratoryReport::CLaboratoryReport(void)
    : m_logger(MODULE_LABORATORY, "LaboratoryReport")
    , m_isInitialized(false)
    , m_bodyLineCount(0)
    , m_filePath("")
{
}

CLaboratoryReport::~CLaboratoryReport(void)
{
    Shutdown();
}

bool CLaboratoryReport::Init(const LaboratoryManifest &manifest, const string filePath)
{
    m_logger.LogInfo(StringFormat("Initializing LaboratoryReport: %s", filePath));
    m_manifest = manifest;
    m_filePath = filePath;
    m_bodyLineCount = 0;
    m_isInitialized = true;

    WriteLine("========================================");
    WriteLine("STRATEGY LABORATORY REPORT");
    WriteLine(StringFormat("Run: %s", manifest.laboratoryRunId));
    WriteLine(StringFormat("Lab: %s (schema v%d)", manifest.laboratoryVersion,
              manifest.knowledgeSchemaVersion));
    WriteLine(StringFormat("Date: %s", TimeToString(manifest.analysisTimestamp)));
    WriteLine("========================================");
    WriteBlankLine();

    return true;
}

void CLaboratoryReport::Shutdown(void)
{
    if(!m_isInitialized) return;

    if(m_bodyLineCount > 0)
        Save();

    m_bodyLineCount = 0;
    m_isInitialized = false;
}

bool CLaboratoryReport::WriteLine(const string line)
{
    if(!m_isInitialized || m_bodyLineCount >= MAX_REPORT_BODY_LINES)
        return false;
    m_body[m_bodyLineCount] = line;
    m_bodyLineCount++;
    return true;
}

bool CLaboratoryReport::WriteSection(const string section)
{
    return WriteLine("--- " + section + " ---");
}

bool CLaboratoryReport::WriteBlankLine(void)
{
    return WriteLine("");
}

bool CLaboratoryReport::Save(void)
{
    if(!m_isInitialized || m_filePath == "")
        return false;

    int handle = FileOpen(m_filePath, FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(handle == INVALID_HANDLE)
        return false;

    for(int i = 0; i < m_bodyLineCount; i++)
        FileWrite(handle, m_body[i]);

    FileClose(handle);
    m_logger.LogInfo(StringFormat("Report saved: %s (%d lines)", m_filePath, m_bodyLineCount));
    return true;
}

bool CLaboratoryReport::Load(const string filePath, LaboratoryManifest &outManifest,
                              string &outBody[], int &outLineCount) const
{
    int handle = FileOpen(filePath, FILE_READ | FILE_TXT | FILE_COMMON);
    if(handle == INVALID_HANDLE)
        return false;

    outLineCount = 0;
    while(!FileIsEnding(handle) && outLineCount < MAX_REPORT_BODY_LINES)
        outBody[outLineCount++] = FileReadString(handle);

    FileClose(handle);
    return true;
}

bool CLaboratoryReport::GetLine(int index, string &out) const
{
    if(index < 0 || index >= m_bodyLineCount) return false;
    out = m_body[index];
    return true;
}

void CLaboratoryReport::Clear(void)
{
    m_bodyLineCount = 0;
}

#endif
