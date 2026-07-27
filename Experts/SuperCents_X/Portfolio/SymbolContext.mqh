//+------------------------------------------------------------------+
//|                                          SymbolContext.mqh        |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __PORTFOLIO_SYMBOL_CONTEXT_MQH__
#define __PORTFOLIO_SYMBOL_CONTEXT_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Core/Config.mqh"
#include "../Structure/SwingDetector.mqh"
#include "../Structure/StructuralPivotEngine.mqh"
#include "../Structure/BOSDetector.mqh"
#include "../Structure/TrendState.mqh"
#include "../Structure/ProtectedPointManager.mqh"
#include "../Structure/CHOCHDetector.mqh"
#include "../Structure/OrderBlockDetector.mqh"
#include "../Structure/FVGDetector.mqh"
#include "../Structure/LiquidityDetector.mqh"
#include "../Visualization/VisualizationManager.mqh"
#include "../Confluence/ConfluenceEngine.mqh"
#include "../Entry/EntrySetup.mqh"
#include "../Entry/EntrySetupBuilder.mqh"
#include "../Entry/EntryValidator.mqh"
#include "../Entry/EntryEngine.mqh"
#include "../Entry/RiskManager.mqh"
#include "../Entry/ExecutionManager.mqh"
#include "../Entry/PositionManager.mqh"
#include "../Entry/PositionLifecycleManager.mqh"
#include "../Trading/TradeExecutionResult.mqh"
#include "../Trading/TradeRequestBuilder.mqh"
#include "../Trading/TradeValidation.mqh"
#include "../Trading/TradeManager.mqh"
#include "../Monitoring/MonitoringTypes.mqh"
#include "../Monitoring/EventBusAdapter.mqh"
#include "../Monitoring/MetricsCollector.mqh"
#include "../Monitoring/HealthMonitor.mqh"
#include "../Monitoring/StatisticsReporter.mqh"
#include "../Risk/PositionSizer.mqh"
#include "../Risk/ExposureTracker.mqh"
#include "../Risk/DrawdownMonitor.mqh"
#include "PortfolioTypes.mqh"
#include "PortfolioRiskManager.mqh"

class CSymbolContext
{
private:
    CLogger      m_logger;
    bool         m_isInitialized;
    string       m_symbol;
    int          m_magicNumber;

    CEventBusAdapter     *m_eventBus;

    CSwingDetector             *m_swingDetector;
    CStructuralPivotEngine     *m_structuralPivotEngine;
    CBOSDetector               *m_bosDetector;
    CTrendState                *m_trendState;
    CProtectedPointManager     *m_protectedPointManager;
    CCHOCHDetector             *m_chochDetector;
    COrderBlockDetector        *m_orderBlockDetector;
    CFVGDetector               *m_fvgDetector;
    CLiquidityDetector         *m_liquidityDetector;
    CVisualizationManager      *m_visualizationManager;
    CConfluenceEngine          *m_confluenceEngine;
    CEntryEngine               *m_entryEngine;
    CEntrySetupBuilder         *m_entrySetupBuilder;
    CEntryValidator            *m_entryValidator;
    CRiskManager               *m_riskManager;
    CExecutionManager          *m_executionManager;
    CPositionManager           *m_positionManager;
    CPositionLifecycleManager  *m_positionLifecycleManager;
    CTradeManager              *m_tradeExecutionManager;

    CMetricsCollector          *m_metricsCollector;
    CHealthMonitor             *m_healthMonitor;
    CStatisticsReporter        *m_statisticsReporter;

    CPortfolioRiskManager      *m_portfolioRiskManager;

    CPositionSizer             *m_positionSizer;
    CExposureTracker           *m_exposureTracker;
    CDrawdownMonitor           *m_drawdownMonitor;

    int m_lastCHOCHCount;

    long m_updateCount;

public:
    CSymbolContext(const string symbol, int magicNumber = 0);
    ~CSymbolContext(void);

    bool Init(CEventBusAdapter *eventBus = NULL);
    void Update(double &open[], double &high[], double &low[], double &close[], datetime &time[], int rates_total);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }
    string GetSymbol(void) const { return m_symbol; }

    void SetEventBus(CEventBusAdapter *bus) { m_eventBus = bus; }
    void SetMagicNumber(int magic) { m_magicNumber = magic; }
    void SetPortfolioRiskManager(CPortfolioRiskManager *prm) { m_portfolioRiskManager = prm; }

    CSwingDetector             *GetSwingDetector(void) const { return m_swingDetector; }
    CStructuralPivotEngine     *GetStructuralPivotEngine(void) const { return m_structuralPivotEngine; }
    CBOSDetector               *GetBOSDetector(void) const { return m_bosDetector; }
    CProtectedPointManager     *GetProtectedPointManager(void) const { return m_protectedPointManager; }
    COrderBlockDetector        *GetOrderBlockDetector(void) const { return m_orderBlockDetector; }
    CFVGDetector               *GetFVGDetector(void) const { return m_fvgDetector; }
    CLiquidityDetector         *GetLiquidityDetector(void) const { return m_liquidityDetector; }
    CTrendState                *GetTrendState(void) const { return m_trendState; }
    CCHOCHDetector             *GetCHOCHDetector(void) const { return m_chochDetector; }
    CConfluenceEngine          *GetConfluenceEngine(void) const { return m_confluenceEngine; }
    CEntryEngine               *GetEntryEngine(void) const { return m_entryEngine; }
    CRiskManager               *GetRiskManager(void) const { return m_riskManager; }
    CExecutionManager          *GetExecutionManager(void) const { return m_executionManager; }
    CPositionManager           *GetPositionManager(void) const { return m_positionManager; }
    CPositionLifecycleManager  *GetPositionLifecycleManager(void) const { return m_positionLifecycleManager; }
    CTradeManager              *GetTradeExecutionManager(void) const { return m_tradeExecutionManager; }
    CMetricsCollector          *GetMetricsCollector(void) const { return m_metricsCollector; }
    CHealthMonitor             *GetHealthMonitor(void) const { return m_healthMonitor; }
    CStatisticsReporter        *GetStatisticsReporter(void) const { return m_statisticsReporter; }

    PerSymbolMetrics GetSnapshot(void) const;
};

CSymbolContext::CSymbolContext(const string symbol, int magicNumber)
    : m_logger(MODULE_ENGINE, "SymbolContext[" + symbol + "]")
    , m_isInitialized(false)
    , m_symbol(symbol)
    , m_magicNumber(magicNumber)
    , m_eventBus(NULL)
    , m_swingDetector(NULL)
    , m_structuralPivotEngine(NULL)
    , m_bosDetector(NULL)
    , m_trendState(NULL)
    , m_protectedPointManager(NULL)
    , m_chochDetector(NULL)
    , m_orderBlockDetector(NULL)
    , m_fvgDetector(NULL)
    , m_liquidityDetector(NULL)
    , m_visualizationManager(NULL)
    , m_confluenceEngine(NULL)
    , m_entryEngine(NULL)
    , m_entrySetupBuilder(NULL)
    , m_entryValidator(NULL)
    , m_riskManager(NULL)
    , m_executionManager(NULL)
    , m_positionManager(NULL)
    , m_positionLifecycleManager(NULL)
    , m_tradeExecutionManager(NULL)
    , m_metricsCollector(NULL)
    , m_healthMonitor(NULL)
    , m_statisticsReporter(NULL)
    , m_portfolioRiskManager(NULL)
    , m_positionSizer(NULL)
    , m_exposureTracker(NULL)
    , m_drawdownMonitor(NULL)
    , m_lastCHOCHCount(0)
    , m_updateCount(0)
{
}

CSymbolContext::~CSymbolContext(void)
{
    Shutdown();
}

bool CSymbolContext::Init(CEventBusAdapter *eventBus)
{
    m_logger.LogInfo("Initializing context for " + m_symbol + "...");

    m_eventBus = eventBus;

    m_swingDetector = new CSwingDetector();
    if(!m_swingDetector.Init())
    {
        m_logger.LogError("Failed to initialize SwingDetector");
        delete m_swingDetector;
        m_swingDetector = NULL;
    }

    m_structuralPivotEngine = new CStructuralPivotEngine();
    if(!m_structuralPivotEngine.Init())
    {
        m_logger.LogError("Failed to initialize StructuralPivotEngine");
        delete m_structuralPivotEngine;
        m_structuralPivotEngine = NULL;
    }

    m_bosDetector = new CBOSDetector();
    if(!m_bosDetector.Init())
    {
        m_logger.LogError("Failed to initialize BOSDetector");
        delete m_bosDetector;
        m_bosDetector = NULL;
    }

    m_trendState = new CTrendState();
    if(!m_trendState.Init())
    {
        m_logger.LogError("Failed to initialize TrendState");
        delete m_trendState;
        m_trendState = NULL;
    }

    m_protectedPointManager = new CProtectedPointManager();
    if(!m_protectedPointManager.Init())
    {
        m_logger.LogError("Failed to initialize ProtectedPointManager");
        delete m_protectedPointManager;
        m_protectedPointManager = NULL;
    }

    m_chochDetector = new CCHOCHDetector();
    if(!m_chochDetector.Init())
    {
        m_logger.LogError("Failed to initialize CHOCHDetector");
        delete m_chochDetector;
        m_chochDetector = NULL;
    }

    m_orderBlockDetector = new COrderBlockDetector();
    if(!m_orderBlockDetector.Init())
    {
        m_logger.LogError("Failed to initialize OrderBlockDetector");
        delete m_orderBlockDetector;
        m_orderBlockDetector = NULL;
    }

    m_fvgDetector = new CFVGDetector();
    if(!m_fvgDetector.Init())
    {
        m_logger.LogError("Failed to initialize FVGDetector");
        delete m_fvgDetector;
        m_fvgDetector = NULL;
    }
    if(m_fvgDetector != NULL)
    {
        m_fvgDetector.SetBOSDetector(m_bosDetector);
        m_fvgDetector.SetCHOCHDetector(m_chochDetector);
    }

    m_liquidityDetector = new CLiquidityDetector();
    if(!m_liquidityDetector.Init())
    {
        m_logger.LogError("Failed to initialize LiquidityDetector");
        delete m_liquidityDetector;
        m_liquidityDetector = NULL;
    }
    if(m_liquidityDetector != NULL)
    {
        m_liquidityDetector.SetSwingDetector(m_swingDetector);
        m_liquidityDetector.SetBOSDetector(m_bosDetector);
    }

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
        m_confluenceEngine.SetLiquidityDetector(m_liquidityDetector);
    }

    m_entrySetupBuilder = new CEntrySetupBuilder();
    if(m_entrySetupBuilder != NULL)
    {
        if(!m_entrySetupBuilder.Init())
        {
            m_logger.LogError("Failed to initialize EntrySetupBuilder");
            delete m_entrySetupBuilder;
            m_entrySetupBuilder = NULL;
        }
        else
        {
            m_entrySetupBuilder.SetBOSDetector(m_bosDetector);
            m_entrySetupBuilder.SetCHOCHDetector(m_chochDetector);
            m_entrySetupBuilder.SetOBDetector(m_orderBlockDetector);
            m_entrySetupBuilder.SetFVGDetector(m_fvgDetector);
            m_entrySetupBuilder.SetPPManager(m_protectedPointManager);
        }
    }

    m_entryValidator = new CEntryValidator();
    if(m_entryValidator != NULL)
    {
        if(!m_entryValidator.Init())
        {
            m_logger.LogError("Failed to initialize EntryValidator");
            delete m_entryValidator;
            m_entryValidator = NULL;
        }
    }

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
        m_executionManager.SetMagicNumber(m_magicNumber);
    }

    m_positionManager = new CPositionManager();
    if(!m_positionManager.Init())
    {
        m_logger.LogError("Failed to initialize PositionManager");
        delete m_positionManager;
        m_positionManager = NULL;
    }
    if(m_executionManager != NULL && m_positionManager != NULL)
    {
        m_executionManager.SetPositionManager(m_positionManager);
    }

    m_positionLifecycleManager = new CPositionLifecycleManager();
    if(!m_positionLifecycleManager.Init())
    {
        m_logger.LogError("Failed to initialize PositionLifecycleManager");
        delete m_positionLifecycleManager;
        m_positionLifecycleManager = NULL;
    }
    if(m_positionLifecycleManager != NULL && m_positionManager != NULL)
    {
        m_positionLifecycleManager.SetPositionManager(m_positionManager);
        m_positionLifecycleManager.SetMagicNumber(m_magicNumber);
    }

    m_tradeExecutionManager = new CTradeManager();
    if(!m_tradeExecutionManager.Init())
    {
        m_logger.LogError("Failed to initialize TradeExecutionManager");
        delete m_tradeExecutionManager;
        m_tradeExecutionManager = NULL;
    }
    if(m_tradeExecutionManager != NULL && m_confluenceEngine != NULL)
    {
        m_tradeExecutionManager.SetPlanner(m_confluenceEngine.GetExecutionPlanner());
        m_tradeExecutionManager.SetMagicNumber(m_magicNumber);
    }

    m_metricsCollector = new CMetricsCollector();
    if(m_metricsCollector != NULL)
    {
        if(!m_metricsCollector.Init())
        {
            m_logger.LogError("Failed to initialize MetricsCollector");
            delete m_metricsCollector;
            m_metricsCollector = NULL;
        }
    }

    m_healthMonitor = new CHealthMonitor();
    if(m_healthMonitor != NULL)
    {
        if(!m_healthMonitor.Init())
        {
            m_logger.LogError("Failed to initialize HealthMonitor");
            delete m_healthMonitor;
            m_healthMonitor = NULL;
        }
    }

    m_statisticsReporter = new CStatisticsReporter();
    if(m_statisticsReporter != NULL)
    {
        if(!m_statisticsReporter.Init())
        {
            m_logger.LogError("Failed to initialize StatisticsReporter");
            delete m_statisticsReporter;
            m_statisticsReporter = NULL;
        }
        else if(m_eventBus != NULL)
        {
            m_eventBus.Subscribe(EVENT_POSITION_CLOSED, m_statisticsReporter);
        }
    }

    if(m_positionLifecycleManager != NULL && m_eventBus != NULL)
        m_positionLifecycleManager.SetEventBus(m_eventBus);

    m_positionSizer = new CPositionSizer();
    if(m_positionSizer != NULL)
    {
        m_positionSizer.SetSymbol(m_symbol);
        if(!m_positionSizer.Init())
        {
            m_logger.LogError("Failed to initialize PositionSizer");
            delete m_positionSizer;
            m_positionSizer = NULL;
        }
    }

    m_exposureTracker = new CExposureTracker();
    if(m_exposureTracker != NULL)
    {
        if(!m_exposureTracker.Init())
        {
            m_logger.LogError("Failed to initialize ExposureTracker");
            delete m_exposureTracker;
            m_exposureTracker = NULL;
        }
    }

    m_drawdownMonitor = new CDrawdownMonitor();
    if(m_drawdownMonitor != NULL)
    {
        if(!m_drawdownMonitor.Init())
        {
            m_logger.LogError("Failed to initialize DrawdownMonitor");
            delete m_drawdownMonitor;
            m_drawdownMonitor = NULL;
        }
    }

    m_lastCHOCHCount = 0;
    m_updateCount = 0;

    m_isInitialized = true;
    m_logger.LogInfo("Context for " + m_symbol + " initialized");
    return true;
}

void CSymbolContext::Update(double &open[], double &high[], double &low[], double &close[], datetime &time[], int rates_total)
{
    if(!m_isInitialized)
        return;

    ulong s, e;
    string perf = "";

    s = GetMicrosecondCount();
    if(m_swingDetector != NULL)
        m_swingDetector.Update(high, low, time, rates_total);
    e = GetMicrosecondCount();
    if(m_metricsCollector != NULL) m_metricsCollector.RecordTiming(MODULE_SWING_DETECTOR, e - s);
    perf += StringFormat(" Swing:%llu", e - s);

    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(time, true);

    s = GetMicrosecondCount();
    if(m_structuralPivotEngine != NULL && m_swingDetector != NULL)
        m_structuralPivotEngine.Update(m_swingDetector);
    e = GetMicrosecondCount();
    if(m_metricsCollector != NULL) m_metricsCollector.RecordTiming(MODULE_SWING_DETECTOR, e - s);
    perf += StringFormat(" Pivot:%llu", e - s);

    s = GetMicrosecondCount();
    if(m_bosDetector != NULL && m_structuralPivotEngine != NULL)
        m_bosDetector.Update(m_structuralPivotEngine, close, time, rates_total);
    e = GetMicrosecondCount();
    if(m_metricsCollector != NULL) m_metricsCollector.RecordTiming(MODULE_BOS_DETECTOR, e - s);
    perf += StringFormat(" BOS:%llu", e - s);

    s = GetMicrosecondCount();
    if(m_trendState != NULL && m_bosDetector != NULL)
        m_trendState.Update(m_bosDetector);
    e = GetMicrosecondCount();
    if(m_metricsCollector != NULL) m_metricsCollector.RecordTiming(MODULE_TREND_STATE, e - s);
    perf += StringFormat(" Trend:%llu", e - s);

    s = GetMicrosecondCount();
    if(m_protectedPointManager != NULL && m_structuralPivotEngine != NULL)
    {
        datetime currentBarTime[];
        ArrayResize(currentBarTime, 1);
        currentBarTime[0] = (rates_total >= 2) ? time[1] : time[0];
        m_protectedPointManager.Update(m_structuralPivotEngine, m_bosDetector, m_trendState, currentBarTime);
    }
    e = GetMicrosecondCount();
    if(m_metricsCollector != NULL) m_metricsCollector.RecordTiming(MODULE_PROTECTED_POINT_MANAGER, e - s);
    perf += StringFormat(" PP:%llu", e - s);

    s = GetMicrosecondCount();
    if(m_chochDetector != NULL && m_trendState != NULL && m_protectedPointManager != NULL)
        m_chochDetector.Update(m_trendState, m_protectedPointManager, close, time, rates_total, _Point);
    e = GetMicrosecondCount();
    if(m_metricsCollector != NULL) m_metricsCollector.RecordTiming(MODULE_CHOCH_DETECTOR, e - s);
    perf += StringFormat(" CHOCH:%llu", e - s);

    if(m_chochDetector != NULL && m_trendState != NULL)
    {
        int currentCHOCHCount = m_chochDetector.GetCHOCHCount();
        if(currentCHOCHCount > m_lastCHOCHCount)
        {
            m_lastCHOCHCount = currentCHOCHCount;
            Trend currentTrend = m_trendState.GetCurrentTrend();
            Trend newTrend = (currentTrend == TREND_BULLISH) ? TREND_BEARISH : TREND_BULLISH;
            m_trendState.ForceTrend(newTrend);
        }
    }

    s = GetMicrosecondCount();
    if(m_orderBlockDetector != NULL && m_chochDetector != NULL)
        m_orderBlockDetector.Update(m_chochDetector, m_trendState, m_protectedPointManager,
                                    open, high, low, close, time, rates_total);
    e = GetMicrosecondCount();
    if(m_metricsCollector != NULL) m_metricsCollector.RecordTiming(MODULE_ORDER_BLOCK_DETECTOR, e - s);
    perf += StringFormat(" OB:%llu", e - s);

    s = GetMicrosecondCount();
    if(m_fvgDetector != NULL)
        m_fvgDetector.Update(open, high, low, close, time, rates_total, m_trendState);
    e = GetMicrosecondCount();
    if(m_metricsCollector != NULL) m_metricsCollector.RecordTiming(MODULE_FVG_DETECTOR, e - s);
    perf += StringFormat(" FVG:%llu", e - s);

    s = GetMicrosecondCount();
    if(m_liquidityDetector != NULL)
        m_liquidityDetector.Update(high, low, time, rates_total);
    e = GetMicrosecondCount();
    if(m_metricsCollector != NULL) m_metricsCollector.RecordTiming(MODULE_LIQUIDITY_DETECTOR, e - s);
    perf += StringFormat(" Liq:%llu", e - s);

    s = GetMicrosecondCount();
    if(m_visualizationManager != NULL)
        m_visualizationManager.Update();
    e = GetMicrosecondCount();
    if(m_metricsCollector != NULL) m_metricsCollector.RecordTiming(MODULE_VISUALIZATION_MANAGER, e - s);
    perf += StringFormat(" Viz:%llu", e - s);

    if(m_metricsCollector != NULL)
        Print("PERF" + perf);

    if(m_confluenceEngine != NULL)
    {
        ulong s_ce = GetMicrosecondCount();
        m_confluenceEngine.Update();
        ulong e_ce = GetMicrosecondCount();
        if(m_metricsCollector != NULL) m_metricsCollector.RecordTiming(MODULE_CONFLUENCE_ENGINE, e_ce - s_ce);
    }

    if(m_portfolioRiskManager != NULL && m_portfolioRiskManager.IsInitialized() && m_confluenceEngine != NULL)
    {
        CExecutionPlanner *planner = m_confluenceEngine.GetExecutionPlanner();
        if(planner != NULL)
        {
            int planCount = planner.GetPlanCount();
            for(int p = 0; p < planCount; p++)
            {
                ExecutionPlan ep;
                if(!planner.GetPlan(p, ep))
                    continue;
                if(ep.status != PLAN_EXECUTABLE)
                    continue;

                PortfolioRiskDecision riskDecision = m_portfolioRiskManager.Evaluate(ep, m_symbol);
                if(!riskDecision.IsApproved())
                {
                    planner.SetPlanStatus(p, PLAN_REJECTED_PORTFOLIO);
                }
            }
        }
    }

    if(m_tradeExecutionManager != NULL)
    {
        ulong s_tm = GetMicrosecondCount();
        m_tradeExecutionManager.Update();
        ulong e_tm = GetMicrosecondCount();
        if(m_metricsCollector != NULL) m_metricsCollector.RecordTiming(MODULE_TRADE_MANAGER, e_tm - s_tm);
    }

    if(m_positionLifecycleManager != NULL)
    {
        ulong s_pl = GetMicrosecondCount();
        m_positionLifecycleManager.Update();
        ulong e_pl = GetMicrosecondCount();
        if(m_metricsCollector != NULL) m_metricsCollector.RecordTiming(MODULE_TRADE_MANAGER, e_pl - s_pl);
    }

    if(m_healthMonitor != NULL)
    {
        m_healthMonitor.SetModuleStatus(MODULE_SWING_DETECTOR, "SwingDetector",
            (m_swingDetector != NULL && m_swingDetector.IsInitialized()), 0,
            (m_swingDetector != NULL) ? HEALTH_HEALTHY : HEALTH_CRITICAL, "");

        m_healthMonitor.SetModuleStatus(MODULE_BOS_DETECTOR, "BOSDetector",
            (m_bosDetector != NULL && m_bosDetector.IsInitialized()), 0,
            (m_bosDetector != NULL) ? HEALTH_HEALTHY : HEALTH_CRITICAL, "");

        m_healthMonitor.SetModuleStatus(MODULE_TREND_STATE, "TrendState",
            (m_trendState != NULL && m_trendState.IsInitialized()), 0,
            (m_trendState != NULL) ? HEALTH_HEALTHY : HEALTH_CRITICAL, "");

        m_healthMonitor.SetModuleStatus(MODULE_PROTECTED_POINT_MANAGER, "ProtectedPointManager",
            (m_protectedPointManager != NULL && m_protectedPointManager.IsInitialized()), 0,
            (m_protectedPointManager != NULL) ? HEALTH_HEALTHY : HEALTH_CRITICAL, "");

        m_healthMonitor.SetModuleStatus(MODULE_CHOCH_DETECTOR, "CHOCHDetector",
            (m_chochDetector != NULL && m_chochDetector.IsInitialized()), 0,
            (m_chochDetector != NULL) ? HEALTH_HEALTHY : HEALTH_CRITICAL, "");

        m_healthMonitor.SetModuleStatus(MODULE_ORDER_BLOCK_DETECTOR, "OrderBlockDetector",
            (m_orderBlockDetector != NULL && m_orderBlockDetector.IsInitialized()), 0,
            (m_orderBlockDetector != NULL) ? HEALTH_HEALTHY : HEALTH_CRITICAL, "");

        m_healthMonitor.SetModuleStatus(MODULE_FVG_DETECTOR, "FVGDetector",
            (m_fvgDetector != NULL && m_fvgDetector.IsInitialized()), 0,
            (m_fvgDetector != NULL) ? HEALTH_HEALTHY : HEALTH_CRITICAL, "");

        m_healthMonitor.SetModuleStatus(MODULE_LIQUIDITY_DETECTOR, "LiquidityDetector",
            (m_liquidityDetector != NULL && m_liquidityDetector.IsInitialized()), 0,
            (m_liquidityDetector != NULL) ? HEALTH_HEALTHY : HEALTH_CRITICAL, "");

        m_healthMonitor.SetModuleStatus(MODULE_VISUALIZATION_MANAGER, "VisualizationManager",
            (m_visualizationManager != NULL && m_visualizationManager.IsInitialized()), 0,
            (m_visualizationManager != NULL) ? HEALTH_HEALTHY : HEALTH_CRITICAL, "");

        m_healthMonitor.SetModuleStatus(MODULE_CONFLUENCE_ENGINE, "ConfluenceEngine",
            (m_confluenceEngine != NULL && m_confluenceEngine.IsInitialized()), 0,
            (m_confluenceEngine != NULL) ? HEALTH_HEALTHY : HEALTH_CRITICAL, "");

        m_healthMonitor.SetModuleStatus(MODULE_TRADE_MANAGER, "TradeManager",
            (m_tradeExecutionManager != NULL), 0,
            (m_tradeExecutionManager != NULL) ? HEALTH_HEALTHY : HEALTH_CRITICAL, "");

        m_healthMonitor.SetModuleStatus(MODULE_POSITION_MANAGER, "PositionLifecycleManager",
            (m_positionLifecycleManager != NULL && m_positionLifecycleManager.IsInitialized()),
            (m_positionLifecycleManager != NULL) ? m_positionLifecycleManager.GetContextCount() : 0,
            (m_positionLifecycleManager != NULL) ? HEALTH_HEALTHY : HEALTH_CRITICAL, "");
    }

    m_updateCount++;
}

void CSymbolContext::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down context for " + m_symbol + "...");

    if(m_tradeExecutionManager != NULL)
    {
        m_tradeExecutionManager.Shutdown();
        delete m_tradeExecutionManager;
        m_tradeExecutionManager = NULL;
    }

    if(m_confluenceEngine != NULL)
    {
        m_confluenceEngine.Shutdown();
        delete m_confluenceEngine;
        m_confluenceEngine = NULL;
    }

    if(m_swingDetector != NULL)
    {
        m_swingDetector.Shutdown();
        delete m_swingDetector;
        m_swingDetector = NULL;
    }

    if(m_structuralPivotEngine != NULL)
    {
        m_structuralPivotEngine.Shutdown();
        delete m_structuralPivotEngine;
        m_structuralPivotEngine = NULL;
    }

    if(m_bosDetector != NULL)
    {
        m_bosDetector.Shutdown();
        delete m_bosDetector;
        m_bosDetector = NULL;
    }

    if(m_trendState != NULL)
    {
        m_trendState.Shutdown();
        delete m_trendState;
        m_trendState = NULL;
    }

    if(m_protectedPointManager != NULL)
    {
        m_protectedPointManager.Shutdown();
        delete m_protectedPointManager;
        m_protectedPointManager = NULL;
    }

    if(m_chochDetector != NULL)
    {
        m_chochDetector.Shutdown();
        delete m_chochDetector;
        m_chochDetector = NULL;
    }

    if(m_orderBlockDetector != NULL)
    {
        m_orderBlockDetector.Shutdown();
        delete m_orderBlockDetector;
        m_orderBlockDetector = NULL;
    }

    if(m_fvgDetector != NULL)
    {
        m_fvgDetector.Shutdown();
        delete m_fvgDetector;
        m_fvgDetector = NULL;
    }

    if(m_liquidityDetector != NULL)
    {
        m_liquidityDetector.Shutdown();
        delete m_liquidityDetector;
        m_liquidityDetector = NULL;
    }

    if(m_visualizationManager != NULL)
    {
        m_visualizationManager.Shutdown();
        delete m_visualizationManager;
        m_visualizationManager = NULL;
    }

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

    if(m_positionManager != NULL)
    {
        m_positionManager.Shutdown();
        delete m_positionManager;
        m_positionManager = NULL;
    }

    if(m_positionLifecycleManager != NULL)
    {
        m_positionLifecycleManager.Shutdown();
        delete m_positionLifecycleManager;
        m_positionLifecycleManager = NULL;
    }

    if(m_statisticsReporter != NULL)
    {
        if(m_eventBus != NULL)
            m_eventBus.Unsubscribe(EVENT_POSITION_CLOSED, m_statisticsReporter);
        m_statisticsReporter.Shutdown();
        delete m_statisticsReporter;
        m_statisticsReporter = NULL;
    }

    if(m_healthMonitor != NULL)
    {
        m_healthMonitor.Shutdown();
        delete m_healthMonitor;
        m_healthMonitor = NULL;
    }

    if(m_metricsCollector != NULL)
    {
        m_metricsCollector.Shutdown();
        delete m_metricsCollector;
        m_metricsCollector = NULL;
    }

    if(m_positionSizer != NULL)
    {
        m_positionSizer.Shutdown();
        delete m_positionSizer;
        m_positionSizer = NULL;
    }

    if(m_exposureTracker != NULL)
    {
        m_exposureTracker.Shutdown();
        delete m_exposureTracker;
        m_exposureTracker = NULL;
    }

    if(m_drawdownMonitor != NULL)
    {
        m_drawdownMonitor.Shutdown();
        delete m_drawdownMonitor;
        m_drawdownMonitor = NULL;
    }

    m_portfolioRiskManager = NULL;
    m_eventBus = NULL;
    m_isInitialized = false;
    m_logger.LogInfo("Context for " + m_symbol + " shutdown complete");
}

PerSymbolMetrics CSymbolContext::GetSnapshot(void) const
{
    PerSymbolMetrics snap;
    snap.symbol = m_symbol;
    snap.updateCount = m_updateCount;
    snap.healthStatus = (m_healthMonitor != NULL) ? m_healthMonitor.GetOverallStatus() : HEALTH_CRITICAL;
    snap.positionCount = (m_positionLifecycleManager != NULL) ? m_positionLifecycleManager.GetContextCount() : 0;

    if(m_exposureTracker != NULL)
    {
        ExposureSnapshot exp = m_exposureTracker.GetSnapshot();
        snap.totalExposure = exp.totalPortfolioExposure;
    }

    return snap;
}

#endif
