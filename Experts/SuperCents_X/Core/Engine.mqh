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
#include "../Visualization/VisualizationManager.mqh"
#include "../Confluence/ConfluenceEngine.mqh"
#include "../Entry/EntrySetup.mqh"
#include "../Entry/EntrySetupBuilder.mqh"
#include "../Entry/EntryValidator.mqh"
#include "../Entry/EntryEngine.mqh"
#include "../Entry/RiskManager.mqh"
#include "../Entry/ExecutionManager.mqh"

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
    CVisualizationManager *m_visualizationManager;
    CConfluenceEngine *m_confluenceEngine;
    CEntryEngine *m_entryEngine;

    //--- Sprint 12: Entry Pipeline
    CEntrySetupBuilder *m_entrySetupBuilder;
    CEntryValidator    *m_entryValidator;
    CRiskManager       *m_riskManager;
    CExecutionManager  *m_executionManager;

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
    CProtectedPointManager *GetProtectedPointManager(void) const { return m_protectedPointManager; }
    COrderBlockDetector *GetOrderBlockDetector(void) const { return m_orderBlockDetector; }
    CFVGDetector *GetFVGDetector(void) const { return m_fvgDetector; }
    CTrendState *GetTrendState(void) const { return m_trendState; }
    CCHOCHDetector *GetCHOCHDetector(void) const { return m_chochDetector; }
    CConfluenceEngine *GetConfluenceEngine(void) const { return m_confluenceEngine; }
    CEntryEngine *GetEntryEngine(void) const { return m_entryEngine; }
    CRiskManager *GetRiskManager(void) const { return m_riskManager; }
    CExecutionManager *GetExecutionManager(void) const { return m_executionManager; }

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
    m_visualizationManager = NULL;
    m_confluenceEngine = NULL;
    m_entryEngine = NULL;
    m_entrySetupBuilder = NULL;
    m_entryValidator = NULL;
    m_riskManager = NULL;
    m_executionManager = NULL;
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

    ulong t0 = GetMicrosecondCount();

    //--- Copy OHLC data from MT5
    double open[];
    double high[];
    double low[];
    double close[];
    datetime time[];

    if(!CopyOHLCArrays(open, high, low, close, time))
        return;
    ulong t1 = GetMicrosecondCount();

    int rates_total = ArraySize(high);

    //--- Update all modules
    UpdateModules(open, high, low, close, time, rates_total);
    ulong t2 = GetMicrosecondCount();

    PrintFormat("PERF Copy(%d bars)=%llu us  Update=%llu us  Total=%llu us",
        rates_total, t1 - t0, t2 - t1, t2 - t0);
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

    //--- Sprint 10: Initialize Visualization Manager
    m_visualizationManager = new CVisualizationManager();
    if(!m_visualizationManager.Init())
    {
        m_logger.LogError("Failed to initialize VisualizationManager");
        delete m_visualizationManager;
        m_visualizationManager = NULL;
    }
    if(m_visualizationManager != NULL)
    {
        m_visualizationManager.SetSwingDetector(m_swingDetector);
        m_visualizationManager.SetPivotEngine(m_structuralPivotEngine);
        m_visualizationManager.SetBOSDetector(m_bosDetector);
        m_visualizationManager.SetCHOCHDetector(m_chochDetector);
        m_visualizationManager.SetProtectedPointManager(m_protectedPointManager);
        m_visualizationManager.SetOrderBlockDetector(m_orderBlockDetector);
        m_visualizationManager.SetFVGDetector(m_fvgDetector);
    }

    //--- Sprint 11: Initialize Confluence Engine
    m_confluenceEngine = new CConfluenceEngine();
    if(!m_confluenceEngine.Init())
    {
        m_logger.LogError("Failed to initialize ConfluenceEngine");
        delete m_confluenceEngine;
        m_confluenceEngine = NULL;
    }
    if(m_confluenceEngine != NULL)
    {
        m_confluenceEngine.SetTrendState(m_trendState);
        m_confluenceEngine.SetBOSDetector(m_bosDetector);
        m_confluenceEngine.SetCHOCHDetector(m_chochDetector);
        m_confluenceEngine.SetOrderBlockDetector(m_orderBlockDetector);
        m_confluenceEngine.SetFVGDetector(m_fvgDetector);
        m_confluenceEngine.SetProtectedPointManager(m_protectedPointManager);
    }

    //--- Sprint 12: Initialize Entry components
    m_entrySetupBuilder = new CEntrySetupBuilder();
    if(m_entrySetupBuilder != NULL)
    {
        m_entrySetupBuilder.Init();
        m_entrySetupBuilder.SetBOSDetector(m_bosDetector);
        m_entrySetupBuilder.SetCHOCHDetector(m_chochDetector);
        m_entrySetupBuilder.SetOBDetector(m_orderBlockDetector);
        m_entrySetupBuilder.SetFVGDetector(m_fvgDetector);
        m_entrySetupBuilder.SetPPManager(m_protectedPointManager);
    }

    m_entryValidator = new CEntryValidator();
    if(m_entryValidator != NULL)
        m_entryValidator.Init();

    m_entryEngine = new CEntryEngine();
    if(!m_entryEngine.Init())
    {
        m_logger.LogError("Failed to initialize EntryEngine");
        delete m_entryEngine;
        m_entryEngine = NULL;
    }

    m_riskManager = new CRiskManager();
    if(!m_riskManager.Init())
    {
        m_logger.LogError("Failed to initialize RiskManager");
        delete m_riskManager;
        m_riskManager = NULL;
    }

    m_executionManager = new CExecutionManager();
    if(!m_executionManager.Init())
    {
        m_logger.LogError("Failed to initialize ExecutionManager");
        delete m_executionManager;
        m_executionManager = NULL;
    }
    if(m_executionManager != NULL)
    {
        m_executionManager.SetMagicNumber(m_config.GetMagicNumber());
    }
}

void CEngine::UpdateModules(const double &open[], const double &high[], const double &low[], const double &close[], const datetime &time[], int rates_total)
{
    ulong s, e;
    string perf = "";

    //--- Sprint 2: Update Swing Detector
    s = GetMicrosecondCount();
    if(m_swingDetector != NULL)
        m_swingDetector.Update(high, low, time, rates_total);
    e = GetMicrosecondCount();
    perf += StringFormat(" Swing:%llu", e - s);

    //--- Sprint 3: Update Structural Pivot Engine
    s = GetMicrosecondCount();
    if(m_structuralPivotEngine != NULL && m_swingDetector != NULL)
        m_structuralPivotEngine.Update(m_swingDetector);
    e = GetMicrosecondCount();
    perf += StringFormat(" Pivot:%llu", e - s);

    //--- Sprint 4: Update BOS Detector
    s = GetMicrosecondCount();
    if(m_bosDetector != NULL && m_structuralPivotEngine != NULL)
        m_bosDetector.Update(m_structuralPivotEngine, close, time, rates_total);
    e = GetMicrosecondCount();
    perf += StringFormat(" BOS:%llu", e - s);

    //--- Sprint 5: Update Trend State Machine
    s = GetMicrosecondCount();
    if(m_trendState != NULL && m_bosDetector != NULL)
        m_trendState.Update(m_bosDetector);
    e = GetMicrosecondCount();
    perf += StringFormat(" Trend:%llu", e - s);

    //--- Sprint 6: Update Protected Point Manager
    s = GetMicrosecondCount();
    if(m_protectedPointManager != NULL && m_structuralPivotEngine != NULL)
    {
        datetime currentBarTime[];
        ArrayResize(currentBarTime, 1);
        currentBarTime[0] = iTime(_Symbol, _Period, 0);
        m_protectedPointManager.Update(m_structuralPivotEngine, m_bosDetector, m_trendState, currentBarTime);
    }
    e = GetMicrosecondCount();
    perf += StringFormat(" PP:%llu", e - s);

    //--- Sprint 7: Update CHOCH Detector
    s = GetMicrosecondCount();
    if(m_chochDetector != NULL && m_trendState != NULL && m_protectedPointManager != NULL)
        m_chochDetector.Update(m_trendState, m_protectedPointManager, close, time, rates_total);
    e = GetMicrosecondCount();
    perf += StringFormat(" CHOCH:%llu", e - s);

    //--- Sprint 8: Update Order Block Detector
    s = GetMicrosecondCount();
    if(m_orderBlockDetector != NULL && m_chochDetector != NULL)
        m_orderBlockDetector.Update(m_chochDetector, m_trendState, m_protectedPointManager,
                                    open, high, low, close, time, rates_total);
    e = GetMicrosecondCount();
    perf += StringFormat(" OB:%llu", e - s);

    //--- Sprint 9: Update FVG Detector
    s = GetMicrosecondCount();
    if(m_fvgDetector != NULL)
        m_fvgDetector.Update(open, high, low, close, time, rates_total);
    e = GetMicrosecondCount();
    perf += StringFormat(" FVG:%llu", e - s);

    //--- Sprint 10: Update Visualization Manager
    s = GetMicrosecondCount();
    if(m_visualizationManager != NULL)
        m_visualizationManager.Update();
    e = GetMicrosecondCount();
    perf += StringFormat(" Viz:%llu", e - s);

    Print("PERF" + perf);
    if(m_confluenceEngine != NULL)
    {
        m_confluenceEngine.Update();
    }

    //--- Sprint 12: Build, validate, and arm entry setups
    if(m_confluenceEngine != NULL && m_entrySetupBuilder != NULL &&
       m_entryValidator != NULL && m_entryEngine != NULL)
    {
        ConfluenceSignal latestSignal;
        if(m_confluenceEngine.GetLatestSignal(latestSignal))
        {
            EntrySetup setup;
            if(m_entrySetupBuilder.Build(latestSignal, setup) &&
               m_entryValidator.IsValid(setup))
            {
                m_entryEngine.Arm(setup);

                if(m_riskManager != NULL && m_executionManager != NULL)
                {
                    PositionSizing sizing = m_riskManager.Calculate(setup);
                    ExecutionResult execResult = m_executionManager.Execute(setup, sizing.lots);
                    if(!execResult.success)
                    {
                        m_logger.LogWarn(StringFormat("Execution failed: %s (retcode=%u)",
                            execResult.description, execResult.retcode));
                    }
                }
            }
        }
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

    //--- Sprint 10: Shutdown Visualization Manager
    if(m_visualizationManager != NULL)
    {
        m_visualizationManager.Shutdown();
        delete m_visualizationManager;
        m_visualizationManager = NULL;
    }

    //--- Sprint 11: Shutdown Confluence Engine
    if(m_confluenceEngine != NULL)
    {
        m_confluenceEngine.Shutdown();
        delete m_confluenceEngine;
        m_confluenceEngine = NULL;
    }

    //--- Sprint 12: Shutdown Entry Pipeline
    if(m_entryEngine != NULL)
    {
        m_entryEngine.Shutdown();
        delete m_entryEngine;
        m_entryEngine = NULL;
    }

    if(m_riskManager != NULL)
    {
        m_riskManager.Shutdown();
        delete m_riskManager;
        m_riskManager = NULL;
    }

    if(m_entryValidator != NULL)
    {
        m_entryValidator.Shutdown();
        delete m_entryValidator;
        m_entryValidator = NULL;
    }

    if(m_entrySetupBuilder != NULL)
    {
        m_entrySetupBuilder.Shutdown();
        delete m_entrySetupBuilder;
        m_entrySetupBuilder = NULL;
    }

    if(m_executionManager != NULL)
    {
        m_executionManager.Shutdown();
        delete m_executionManager;
        m_executionManager = NULL;
    }
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