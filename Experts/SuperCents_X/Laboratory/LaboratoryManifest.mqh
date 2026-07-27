#ifndef __LABORATORY_LABORATORY_MANIFEST_MQH__
#define __LABORATORY_LABORATORY_MANIFEST_MQH__

#include "../Core/Logger.mqh"
#include "LaboratoryTypes.mqh"

class CLaboratoryManifest
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    LaboratoryManifest m_manifest;

public:
    CLaboratoryManifest(void);
    ~CLaboratoryManifest(void);

    bool Init(const string runId, const string labVersion, int schemaVersion);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool SetInputArtifactSetId(const string id);
    bool SetComparisonConfigurationId(const string id);
    bool SetOutputReportId(const string id);

    LaboratoryManifest GetManifest(void) const { return m_manifest; }
    string ToString(void) const;
};

CLaboratoryManifest::CLaboratoryManifest(void)
    : m_logger(MODULE_LABORATORY, "LaboratoryManifest")
    , m_isInitialized(false)
{
}

CLaboratoryManifest::~CLaboratoryManifest(void)
{
    Shutdown();
}

bool CLaboratoryManifest::Init(const string runId, const string labVersion, int schemaVersion)
{
    m_manifest.laboratoryRunId = runId;
    m_manifest.laboratoryVersion = labVersion;
    m_manifest.knowledgeSchemaVersion = schemaVersion;
    m_manifest.analysisTimestamp = TimeCurrent();
    m_isInitialized = true;
    m_logger.LogInfo(StringFormat("Manifest initialized: run=%s, lab=%s, schema=%d",
                                  runId, labVersion, schemaVersion));
    return true;
}

void CLaboratoryManifest::Shutdown(void)
{
    m_isInitialized = false;
}

bool CLaboratoryManifest::SetInputArtifactSetId(const string id)
{
    m_manifest.inputArtifactSetId = id;
    return true;
}

bool CLaboratoryManifest::SetComparisonConfigurationId(const string id)
{
    m_manifest.comparisonConfigurationId = id;
    return true;
}

bool CLaboratoryManifest::SetOutputReportId(const string id)
{
    m_manifest.outputReportId = id;
    return true;
}

string CLaboratoryManifest::ToString(void) const
{
    return StringFormat("LaboratoryRun[%s] v%s (schema=%d) artifacts=%s config=%s at %s report=%s",
                        m_manifest.laboratoryRunId,
                        m_manifest.laboratoryVersion,
                        m_manifest.knowledgeSchemaVersion,
                        m_manifest.inputArtifactSetId,
                        m_manifest.comparisonConfigurationId,
                        TimeToString(m_manifest.analysisTimestamp),
                        m_manifest.outputReportId);
}

#endif
