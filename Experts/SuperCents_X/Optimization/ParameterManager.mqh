#ifndef __OPTIMIZATION_PARAMETER_MANAGER_MQH__
#define __OPTIMIZATION_PARAMETER_MANAGER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "OptimizationTypes.mqh"

#define MAX_PARAMETER_SETS 64

class CParameterManager
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    ParameterSet m_sets[MAX_PARAMETER_SETS];
    int          m_setCount;
    bool         m_frozen;

public:
    CParameterManager(void);
    ~CParameterManager(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool RegisterSet(const ParameterSet &set);
    bool GetSet(const string id, ParameterSet &out) const;
    bool GetSetByLabel(const string label, ParameterSet &out) const;
    int  GetSetCount(void) const { return m_setCount; }
    bool GetSetByIndex(int index, ParameterSet &out) const;

    ParameterSet GetDefaults(void) const;

    bool SaveToFile(const string filepath) const;
    bool LoadFromFile(const string filepath);
};

CParameterManager::CParameterManager(void)
    : m_logger(MODULE_UNKNOWN, "ParameterManager")
    , m_isInitialized(false)
    , m_setCount(0)
    , m_frozen(false)
{
}

CParameterManager::~CParameterManager(void)
{
    Shutdown();
}

bool CParameterManager::Init(void)
{
    m_logger.LogInfo("Initializing ParameterManager...");
    m_setCount = 0;
    m_frozen = false;

    RegisterSet(GetDefaults());

    m_isInitialized = true;
    m_logger.LogInfo("ParameterManager initialized with 1 default set");
    return true;
}

void CParameterManager::Shutdown(void)
{
    if(!m_isInitialized)
        return;
    m_setCount = 0;
    m_frozen = false;
    m_isInitialized = false;
}

bool CParameterManager::RegisterSet(const ParameterSet &set)
{
    if(m_frozen)
    {
        m_logger.LogWarn("Cannot register set: ParameterManager is frozen");
        return false;
    }

    if(m_setCount >= MAX_PARAMETER_SETS)
    {
        m_logger.LogWarn("Max parameter sets reached");
        return false;
    }

    for(int i = 0; i < m_setCount; i++)
    {
        if(m_sets[i].id == set.id)
        {
            m_logger.LogWarn(StringFormat("Duplicate parameter set ID: %s", set.id));
            return false;
        }
    }

    m_sets[m_setCount] = set;
    m_setCount++;
    return true;
}

bool CParameterManager::GetSet(const string id, ParameterSet &out) const
{
    for(int i = 0; i < m_setCount; i++)
    {
        if(m_sets[i].id == id)
        {
            out = m_sets[i];
            return true;
        }
    }
    return false;
}

bool CParameterManager::GetSetByLabel(const string label, ParameterSet &out) const
{
    for(int i = 0; i < m_setCount; i++)
    {
        if(m_sets[i].label == label)
        {
            out = m_sets[i];
            return true;
        }
    }
    return false;
}

bool CParameterManager::GetSetByIndex(int index, ParameterSet &out) const
{
    if(index < 0 || index >= m_setCount)
        return false;
    out = m_sets[index];
    return true;
}

ParameterSet CParameterManager::GetDefaults(void) const
{
    ParameterSet def;
    def.id = "default";
    def.label = "v1.9 Defaults";
    return def;
}

bool CParameterManager::SaveToFile(const string filepath) const
{
    int handle = FileOpen(filepath, FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(handle == INVALID_HANDLE)
        return false;

    FileWrite(handle, IntegerToString(m_setCount));

    for(int i = 0; i < m_setCount; i++)
    {
        const ParameterSet &s = m_sets[i];
        FileWrite(handle, s.id);
        FileWrite(handle, s.label);

        FileWrite(handle, IntegerToString(s.structure.swingStrength));
        FileWrite(handle, IntegerToString(s.structure.swingLookbackBars));
        FileWrite(handle, IntegerToString(s.structure.bosLookbackBars));
        FileWrite(handle, IntegerToString(s.structure.chochLookbackBars));
        FileWrite(handle, DoubleToString(s.structure.fvgMinBodySizePips, 1));
        FileWrite(handle, DoubleToString(s.structure.liquidityEqhTolerancePips, 1));
        FileWrite(handle, DoubleToString(s.structure.liquidityEqlTolerancePips, 1));

        FileWrite(handle, DoubleToString(s.confluence.confluenceThreshold, 1));
        FileWrite(handle, DoubleToString(s.confluence.weightTrend, 1));
        FileWrite(handle, DoubleToString(s.confluence.weightStructure, 1));
        FileWrite(handle, DoubleToString(s.confluence.weightMomentum, 1));
        FileWrite(handle, DoubleToString(s.confluence.weightLiquidity, 1));

        FileWrite(handle, DoubleToString(s.risk.maxRiskPerTradePercent, 1));
        FileWrite(handle, DoubleToString(s.risk.maxDailyRiskPercent, 1));
        FileWrite(handle, DoubleToString(s.risk.maxPositionSizePercent, 1));
        FileWrite(handle, DoubleToString(s.risk.stopBufferPips, 1));
        FileWrite(handle, DoubleToString(s.risk.minStopDistancePips, 1));

        FileWrite(handle, DoubleToString(s.portfolio.maxPortfolioRiskPercent, 1));
        FileWrite(handle, IntegerToString(s.portfolio.maxConcurrentPositions));
        FileWrite(handle, DoubleToString(s.portfolio.maxCorrelationThreshold, 2));
        FileWrite(handle, DoubleToString(s.portfolio.maxSymbolConcentrationPercent, 1));
        FileWrite(handle, DoubleToString(s.portfolio.maxCapitalUtilizationPercent, 1));
        FileWrite(handle, DoubleToString(s.portfolio.maxDailyLossPercent, 1));

        FileWrite(handle, IntegerToString(s.optimization.walkForwardMinTrainBars));
        FileWrite(handle, IntegerToString(s.optimization.walkForwardMinTestBars));
        FileWrite(handle, DoubleToString(s.optimization.walkForwardTrainPercent, 2));
        FileWrite(handle, IntegerToString(s.optimization.monteCarloIterations));
        FileWrite(handle, DoubleToString(s.optimization.monteCarloConfidenceLevel, 2));
        FileWrite(handle, DoubleToString(s.optimization.robustnessPerturbationPercent, 1));
    }

    FileClose(handle);
    return true;
}

bool CParameterManager::LoadFromFile(const string filepath)
{
    int handle = FileOpen(filepath, FILE_READ | FILE_TXT | FILE_COMMON);
    if(handle == INVALID_HANDLE)
        return false;

    int count = (int)StringToInteger(FileReadString(handle));
    m_setCount = 0;

    for(int i = 0; i < count && i < MAX_PARAMETER_SETS; i++)
    {
        ParameterSet s;
        s.id = FileReadString(handle);
        s.label = FileReadString(handle);

        s.structure.swingStrength = (int)StringToInteger(FileReadString(handle));
        s.structure.swingLookbackBars = (int)StringToInteger(FileReadString(handle));
        s.structure.bosLookbackBars = (int)StringToInteger(FileReadString(handle));
        s.structure.chochLookbackBars = (int)StringToInteger(FileReadString(handle));
        s.structure.fvgMinBodySizePips = StringToDouble(FileReadString(handle));
        s.structure.liquidityEqhTolerancePips = StringToDouble(FileReadString(handle));
        s.structure.liquidityEqlTolerancePips = StringToDouble(FileReadString(handle));

        s.confluence.confluenceThreshold = StringToDouble(FileReadString(handle));
        s.confluence.weightTrend = StringToDouble(FileReadString(handle));
        s.confluence.weightStructure = StringToDouble(FileReadString(handle));
        s.confluence.weightMomentum = StringToDouble(FileReadString(handle));
        s.confluence.weightLiquidity = StringToDouble(FileReadString(handle));

        s.risk.maxRiskPerTradePercent = StringToDouble(FileReadString(handle));
        s.risk.maxDailyRiskPercent = StringToDouble(FileReadString(handle));
        s.risk.maxPositionSizePercent = StringToDouble(FileReadString(handle));
        s.risk.stopBufferPips = StringToDouble(FileReadString(handle));
        s.risk.minStopDistancePips = StringToDouble(FileReadString(handle));

        s.portfolio.maxPortfolioRiskPercent = StringToDouble(FileReadString(handle));
        s.portfolio.maxConcurrentPositions = (int)StringToInteger(FileReadString(handle));
        s.portfolio.maxCorrelationThreshold = StringToDouble(FileReadString(handle));
        s.portfolio.maxSymbolConcentrationPercent = StringToDouble(FileReadString(handle));
        s.portfolio.maxCapitalUtilizationPercent = StringToDouble(FileReadString(handle));
        s.portfolio.maxDailyLossPercent = StringToDouble(FileReadString(handle));

        s.optimization.walkForwardMinTrainBars = (int)StringToInteger(FileReadString(handle));
        s.optimization.walkForwardMinTestBars = (int)StringToInteger(FileReadString(handle));
        s.optimization.walkForwardTrainPercent = StringToDouble(FileReadString(handle));
        s.optimization.monteCarloIterations = (int)StringToInteger(FileReadString(handle));
        s.optimization.monteCarloConfidenceLevel = StringToDouble(FileReadString(handle));
        s.optimization.robustnessPerturbationPercent = StringToDouble(FileReadString(handle));

        m_sets[m_setCount] = s;
        m_setCount++;
    }

    FileClose(handle);
    return true;
}

#endif
