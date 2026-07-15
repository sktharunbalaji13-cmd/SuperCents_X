//+------------------------------------------------------------------+
//|                                                   Engine.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __ENGINE_MQH__
#define __ENGINE_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Utils/Helpers.mqh"
#include "../Core/Logger.mqh"
#include "../Core/Config.mqh"
#include "../Structure/SwingDetector.mqh"
#include "../Structure/StructuralPivotEngine.mqh"
#include "../Structure/BOSDetector.mqh"
#include "../Structure/TrendState.mqh"
#include "../Structure/ProtectedPointManager.mqh"
#include "../Structure/CHOCHDetector.mqh"
#include "../Structure/OrderBlockDetector.mqh"
#include "../Structure/FVGDetector.mqh"

// Forward declarations for modules to be added later
class CEntryEngine;

class CEngine
{
private:
    bool m_isInitialized;
    bool m_isRunning;
    CLogger m_logger;
    CConfig m_config;

    //--- Sprint 2: Swing Detection Engine
    CSwingDetector *m_swingDetector;

    //--- Sprint 3: Structural Pivot Engine
    CStructuralPivotEngine *m_structuralPivotEngine;

    //--- Sprint 4: BOS Detector
    CBOSDetector *m_bosDetector;

    //--- Sprint 5: Trend State
    CTrendState *m_trendState;
    
    //--- Sprint 6: Protected Point Manager
    CProtectedPointManager *m_protectedPointManager;
    
    // Module pointers (will be initialized in later sprints)
    CCHOCHDetector *m_chochDetector;
    COrderBlockDetector *m_orderBlockDetector;
    CFVGDetector *m_fvgDetector;
    CEntryEngine *m_entryEngine;

    //--- Internal helpers
    bool CopyOHLCArrays(double &open[], double &high[], double &low[], double &close[], datetime &time[]);
    bool IsNewBar(void);

public:
    CEngine(void);
    ~CEngine(void);

    //--- Lifecycle
    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsRunning(void) const { return m_isRunning; }
    bool IsInitialized(void) const { return m_isInitialized; }

    //--- Public module access (read-only)
    CSwingDetector *GetSwingDetector(void) const { return m_swingDetector; }
    CStructuralPivotEngine *GetStructuralPivotEngine(void) const { return m_structuralPivotEngine; }
    CBOSDetector *GetBOSDetector(void) const { return m_bosDetector; }

private:
    void InitializeModules(void);
    void UpdateModules(const double &open[], const double &high[], const double &low[], const double &close[], const datetime &time[], int rates_total);
    void ShutdownModules(void);
};

//--- Inline implementation
CEngine::CEngine(void)
    : m_isInitialized(false), m_isRunning(false), m_logger(MODULE_ENGINE, "Engine")
{
// Initialize module pointers to null
    m_swingDetector = NULL;
    m_structuralPivotEngine = NULL;
    m_bosDetector = NULL;
    m_trendState = NULL;
    m_protectedPointManager = NULL;
    m_chochDetector = NULL;
    m_orderBlockDetector = NULL;
    m_fvgDetector = NULL;
    m_entryEngine = NULL;
}

CEngine::~CEngine(void)
{
    Shutdown();
}

bool CEngine::Init(void)
{
    m_logger.LogInfo("Initializing Engine...");

    // Initialize configuration
    if(!m_config.Init())
    {
        m_logger.LogError("Failed to initialize configuration");
        return false;
    }

    m_logger.LogInfo("Configuration initialized");

    // Initialize sub-modules
    InitializeModules();

    m_logger.LogInfo("Engine initialization complete");

    m_isInitialized = true;
    m_isRunning = true;

    return true;
}

void CEngine::Update(void)
{
    if(!m_isRunning)
    {
        m_logger.LogWarn("Update called but engine is not running");
        return;
    }

    //--- Check if we have a new bar to avoid redundant processing
    if(!IsNewBar())
        return;

    //--- Copy OHLC data from MT5
    double open[];
    double high[];
    double low[];
    double close[];
    datetime time[];

    if(!CopyOHLCArrays(open, high, low, close, time))
        return;

    int rates_total = ArraySize(high);

    //--- Update all modules
    UpdateModules(open, high, low, close, time, rates_total);
}

void CEngine::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down Engine...");

    m_isRunning = false;
    ShutdownModules();

    m_isInitialized = false;

    m_logger.LogInfo("Engine shutdown complete");
}

void CEngine::InitializeModules(void)
{
    m_logger.LogInfo("Initializing modules...");

    //--- Sprint 2: Initialize Swing Detector
    m_swingDetector = new CSwingDetector();
    if(!m_swingDetector.Init())
    {
        m_logger.LogError("Failed to initialize SwingDetector");
        delete m_swingDetector;
        m_swingDetector = NULL;
    }

    //--- Sprint 3: Initialize Structural Pivot Engine
    m_structuralPivotEngine = new CStructuralPivotEngine();
    if(!m_structuralPivotEngine.Init())
    {
        m_logger.LogError("Failed to initialize StructuralPivotEngine");
        delete m_structuralPivotEngine;
        m_structuralPivotEngine = NULL;
    }

    //--- Sprint 4: Initialize BOS Detector
    m_bosDetector = new CBOSDetector();
    if(!m_bosDetector.Init())
    {
        m_logger.LogError("Failed to initialize BOSDetector");
        delete m_bosDetector;
        m_bosDetector = NULL;
    }

    //--- Sprint 5: Initialize Trend State Machine
    m_trendState = new CTrendState();
    if(!m_trendState.Init())
    {
        m_logger.LogError("Failed to initialize TrendState");
        delete m_trendState;
        m_trendState = NULL;
    }

    //--- Sprint 6: Initialize Protected Point Manager
    m_protectedPointManager = new CProtectedPointManager();
    if(!m_protectedPointManager.Init())
    {
        m_logger.LogError("Failed to initialize ProtectedPointManager");
        delete m_protectedPointManager;
        m_protectedPointManager = NULL;
    }

    //--- Sprint 7: Initialize CHOCH Detector
    m_chochDetector = new CCHOCHDetector();
    if(!m_chochDetector.Init())
    {
        m_logger.LogError("Failed to initialize CHOCHDetector");
        delete m_chochDetector;
        m_chochDetector = NULL;
    }

    //--- Sprint 8: Initialize Order Block Detector
    m_orderBlockDetector = new COrderBlockDetector();
    if(!m_orderBlockDetector.Init())
    {
        m_logger.LogError("Failed to initialize OrderBlockDetector");
        delete m_orderBlockDetector;
        m_orderBlockDetector = NULL;
    }

    //--- Sprint 9: Initialize FVG Detector
    m_fvgDetector = new CFVGDetector();
    if(!m_fvgDetector.Init())
    {
        m_logger.LogError("Failed to initialize FVGDetector");
        delete m_fvgDetector;
        m_fvgDetector = NULL;
    }

    // Sprint 10+: Additional modules will be initialized here
}

void CEngine::UpdateModules(const double &open[], const double &high[], const double &low[], const double &close[], const datetime &time[], int rates_total)
{
    //--- Sprint 2: Update Swing Detector
    if(m_swingDetector != NULL)
    {
        m_swingDetector.Update(high, low, time, rates_total);
    }

    //--- Sprint 3: Update Structural Pivot Engine
    if(m_structuralPivotEngine != NULL && m_swingDetector != NULL)
    {
        m_structuralPivotEngine.Update(m_swingDetector);
    }

    //--- Sprint 4: Update BOS Detector
    if(m_bosDetector != NULL && m_structuralPivotEngine != NULL)
    {
        m_bosDetector.Update(m_structuralPivotEngine, close, time, rates_total);
    }

    //--- Sprint 5: Update Trend State Machine
    if(m_trendState != NULL && m_bosDetector != NULL)
    {
        m_trendState.Update(m_bosDetector);
    }

    //--- Sprint 6: Update Protected Point Manager
    // Use iTime() to get the current bar time (CopyTime returns non-series array)
    if(m_protectedPointManager != NULL && m_structuralPivotEngine != NULL)
    {
        datetime currentBarTime[];
        int currentBars = 1;
        ArrayResize(currentBarTime, currentBars);
        currentBarTime[0] = iTime(_Symbol, _Period, 0);  // Current bar being processed
        m_protectedPointManager.Update(m_structuralPivotEngine, m_bosDetector, m_trendState, currentBarTime);
    }

    //--- Sprint 7: Update CHOCH Detector
    if(m_chochDetector != NULL && m_trendState != NULL && m_protectedPointManager != NULL)
    {
        m_chochDetector.Update(m_trendState, m_protectedPointManager, close, time, rates_total);
    }

    //--- Sprint 8: Update Order Block Detector
    if(m_orderBlockDetector != NULL && m_chochDetector != NULL)
    {
        m_orderBlockDetector.Update(m_chochDetector, m_trendState, m_protectedPointManager,
                                    open, high, low, close, time, rates_total);
    }

    //--- Sprint 9: Update FVG Detector
    if(m_fvgDetector != NULL)
    {
        m_fvgDetector.Update(open, high, low, close, time, rates_total);
    }
}

void CEngine::ShutdownModules(void)
{
    m_logger.LogInfo("Shutting down modules...");

    //--- Sprint 2: Shutdown Swing Detector
    if(m_swingDetector != NULL)
    {
        m_swingDetector.Shutdown();
        delete m_swingDetector;
        m_swingDetector = NULL;
    }

    //--- Sprint 3: Shutdown Structural Pivot Engine
    if(m_structuralPivotEngine != NULL)
    {
        m_structuralPivotEngine.Shutdown();
        delete m_structuralPivotEngine;
        m_structuralPivotEngine = NULL;
    }

    //--- Sprint 4: Shutdown BOS Detector
    if(m_bosDetector != NULL)
    {
        m_bosDetector.Shutdown();
        delete m_bosDetector;
        m_bosDetector = NULL;
    }

    //--- Sprint 5: Shutdown Trend State Machine
    if(m_trendState != NULL)
    {
        m_trendState.Shutdown();
        delete m_trendState;
        m_trendState = NULL;
    }

    //--- Sprint 6: Shutdown Protected Point Manager
    if(m_protectedPointManager != NULL)
    {
        m_protectedPointManager.Shutdown();
        delete m_protectedPointManager;
        m_protectedPointManager = NULL;
    }

    //--- Sprint 7: Shutdown CHOCH Detector
    if(m_chochDetector != NULL)
    {
        m_chochDetector.Shutdown();
        delete m_chochDetector;
        m_chochDetector = NULL;
    }

    //--- Sprint 8: Shutdown Order Block Detector
    if(m_orderBlockDetector != NULL)
    {
        m_orderBlockDetector.Shutdown();
        delete m_orderBlockDetector;
        m_orderBlockDetector = NULL;
    }

    //--- Sprint 9: Shutdown FVG Detector
    if(m_fvgDetector != NULL)
    {
        m_fvgDetector.Shutdown();
        delete m_fvgDetector;
        m_fvgDetector = NULL;
    }

    // Sprint 10+: Shutdown additional modules here
}

bool CEngine::CopyOHLCArrays(double &open[], double &high[], double &low[], double &close[], datetime &time[])
{
    //--- Get the number of bars available on the current timeframe
    int bars = Bars(_Symbol, _Period);

    if(bars < 5)
        return false;  // not enough data for 5-bar fractal

    //--- Copy open prices
    if(CopyOpen(_Symbol, _Period, 0, bars, open) <= 0)
    {
        m_logger.LogError("Failed to copy Open array");
        return false;
    }

    //--- Copy high prices
    if(CopyHigh(_Symbol, _Period, 0, bars, high) <= 0)
    {
        m_logger.LogError("Failed to copy High array");
        return false;
    }

    //--- Copy low prices
    if(CopyLow(_Symbol, _Period, 0, bars, low) <= 0)
    {
        m_logger.LogError("Failed to copy Low array");
        return false;
    }

    //--- Copy close prices
    if(CopyClose(_Symbol, _Period, 0, bars, close) <= 0)
    {
        m_logger.LogError("Failed to copy Close array");
        return false;
    }

    //--- Copy time
    if(CopyTime(_Symbol, _Period, 0, bars, time) <= 0)
    {
        m_logger.LogError("Failed to copy Time array");
        return false;
    }

    return true;
}

bool CEngine::IsNewBar(void)
{
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, _Period, 0);

    if(currentBarTime == 0)
        return false;

    if(currentBarTime == lastBarTime)
        return false;

    lastBarTime = currentBarTime;
    return true;
}

#endif // __ENGINE_MQH__