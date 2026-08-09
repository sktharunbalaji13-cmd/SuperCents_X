#ifndef __OPTIMIZATION_EXPERIMENT_MANIFEST_MQH__
#define __OPTIMIZATION_EXPERIMENT_MANIFEST_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "OptimizationTypes.mqh"

struct ExperimentManifest
{
    string          experimentId;
    string          platformVersion;
    string          parameterSetId;
    string          datasetId;
    int             walkForwardWindows;
    int             randomSeed;
    datetime        startTimestamp;
    datetime        endTimestamp;
    string          notes;

    ExperimentManifest(void)
        : experimentId("")
        , platformVersion("")
        , parameterSetId("")
        , datasetId("")
        , walkForwardWindows(0)
        , randomSeed(0)
        , startTimestamp(0)
        , endTimestamp(0)
        , notes("")
    {}
};

class CExperimentManifest
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

public:
    CExperimentManifest(void);
    ~CExperimentManifest(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    static ExperimentManifest Create(const string platformVersion,
                                      const string parameterSetId,
                                      const string datasetId,
                                      int walkForwardWindows,
                                      int randomSeed,
                                      const string notes = "");

    static bool ToFile(const ExperimentManifest &manifest, const string filepath);
    static bool FromFile(const string filepath, ExperimentManifest &out);
    static string ToString(const ExperimentManifest &manifest);
};

CExperimentManifest::CExperimentManifest(void)
    : m_logger(MODULE_UNKNOWN, "ExperimentManifest")
    , m_isInitialized(false)
{
}

CExperimentManifest::~CExperimentManifest(void)
{
    Shutdown();
}

bool CExperimentManifest::Init(void)
{
    m_isInitialized = true;
    return true;
}

void CExperimentManifest::Shutdown(void)
{
    m_isInitialized = false;
}

ExperimentManifest CExperimentManifest::Create(const string platformVersion,
                                                const string parameterSetId,
                                                const string datasetId,
                                                int walkForwardWindows,
                                                int randomSeed,
                                                const string notes)
{
    ExperimentManifest manifest;
    manifest.platformVersion = platformVersion;
    manifest.parameterSetId = parameterSetId;
    manifest.datasetId = datasetId;
    manifest.walkForwardWindows = walkForwardWindows;
    manifest.randomSeed = randomSeed;
    manifest.startTimestamp = TimeCurrent();
    manifest.endTimestamp = 0;
    manifest.notes = notes;

    string raw = platformVersion + "|" + parameterSetId + "|" + datasetId
        + "|" + IntegerToString(walkForwardWindows)
        + "|" + IntegerToString(randomSeed);
    int hash = 0;
    for(int i = 0; i < StringLen(raw); i++)
    {
        int c = StringGetCharacter(raw, i);
        hash = ((hash << 5) - hash) + c;
    }
    manifest.experimentId = StringFormat("EXP-%08X", hash);

    return manifest;
}

bool CExperimentManifest::ToFile(const ExperimentManifest &manifest, const string filepath)
{
    int handle = FileOpen(filepath, FILE_WRITE | FILE_TXT);
    if(handle == INVALID_HANDLE)
        return false;
    FileWrite(handle, manifest.experimentId);
    FileWrite(handle, manifest.platformVersion);
    FileWrite(handle, manifest.parameterSetId);
    FileWrite(handle, manifest.datasetId);
    FileWrite(handle, IntegerToString(manifest.walkForwardWindows));
    FileWrite(handle, IntegerToString(manifest.randomSeed));
    FileWrite(handle, TimeToString(manifest.startTimestamp));
    FileWrite(handle, TimeToString(manifest.endTimestamp));
    FileWrite(handle, manifest.notes);
    FileClose(handle);
    return true;
}

bool CExperimentManifest::FromFile(const string filepath, ExperimentManifest &out)
{
    int handle = FileOpen(filepath, FILE_READ | FILE_TXT);
    if(handle == INVALID_HANDLE)
        return false;
    out.experimentId = FileReadString(handle);
    out.platformVersion = FileReadString(handle);
    out.parameterSetId = FileReadString(handle);
    out.datasetId = FileReadString(handle);
    out.walkForwardWindows = (int)StringToInteger(FileReadString(handle));
    out.randomSeed = (int)StringToInteger(FileReadString(handle));
    out.startTimestamp = StringToTime(FileReadString(handle));
    out.endTimestamp = StringToTime(FileReadString(handle));
    out.notes = FileReadString(handle);
    FileClose(handle);
    return true;
}

string CExperimentManifest::ToString(const ExperimentManifest &manifest)
{
    return StringFormat("Experiment[%s] Platform=%s Params=%s Dataset=%s Windows=%d Seed=%d",
                        manifest.experimentId,
                        manifest.platformVersion,
                        manifest.parameterSetId,
                        manifest.datasetId,
                        manifest.walkForwardWindows,
                        manifest.randomSeed);
}

#endif
