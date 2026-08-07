//+------------------------------------------------------------------+
//|                                          SymbolContext.mqh        |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __PORTFOLIO_SYMBOL_CONTEXT_MQH__
#define __PORTFOLIO_SYMBOL_CONTEXT_MQH__

#include "../Core/Logger.mqh"
#include "../Core/HistoryEpoch.mqh"
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
#include "../Entry/EntryOrchestrator.mqh"
#include "../Entry/EntryConfig.mqh"
#include "../Entry/CShadowTradeStateProvider.mqh"
#include "../Entry/CShadowRiskEvaluator.mqh"
#include "../Providers/ProductionTradeStateProvider.mqh"
#include "../Providers/ProductionRiskEvaluator.mqh"
#include "../Entry/Validators/DirectionValidator.mqh"
#include "../Entry/Validators/ConfluenceValidator.mqh"
#include "../Entry/Validators/FreshnessValidator.mqh"
#include "../Entry/Validators/SpreadValidator.mqh"
#include "../Entry/Validators/SessionValidator.mqh"
#include "../Entry/Validators/DistanceValidator.mqh"
#include "../Entry/Validators/CooldownValidator.mqh"
#include "../Entry/Validators/RiskValidator.mqh"
#include "../Telemetry/TelemetryCollector.mqh"
#include "../Telemetry/TelemetryRowBuilder.mqh"
#include "../Telemetry/ForwardOutcomeSimulator.mqh"

#define TELEMETRY_SETTLE_MAX_HOLD_BARS 50

class CSymbolContext : public IHistoryResetConsumer
{
private:
    CLogger      m_logger;
    bool         m_isInitialized;
    string       m_symbol;
    int          m_magicNumber;
    ConfluenceWeights m_weights;

    CEventBusAdapter     *m_eventBus;

    CHistoryEpoch         m_epoch;

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

    CEntryOrchestrator       *m_entryOrchestrator;
    ENUM_ENTRY_MODE           m_entryMode;
    CTelemetryCollector      *m_telemetry;

    //--- Sprint 15.3: deferred outcome settlement. Rows are queued here and
    //    settled (simulated forward outcome) once TELEMETRY_SETTLE_MAX_HOLD_BARS
    //    bars have elapsed, so the promotion gate sees real settled trades.
    CForwardOutcomeSimulator  m_outcomeSim;
    CFixedRRPolicy            m_outcomePolicy;
    TelemetryRow              m_pendingRows[];
    datetime                  m_pendingEntryTime[];
    int                       m_pendingCount;
    CShadowTradeStateProvider m_shadowProvider;
    CShadowRiskEvaluator      m_shadowRisk;
    CProductionTradeStateProvider m_productionProvider;
    CProductionRiskEvaluator      m_productionRisk;
    ITradeStateProvider       *m_stateProvider;
    IRiskEvaluator            *m_riskEvaluator;
    CDirectionValidator       m_dirVal;
    CConfluenceValidator      m_confVal;
    CFreshnessValidator       m_freshVal;
    CSpreadValidator          m_spreadVal;
    CSessionValidator         m_sessVal;
    CDistanceValidator        m_distVal;
    CCooldownValidator        m_cooldownVal;
    CRiskValidator            m_riskVal;

    int m_lastCHOCHCount;

    long m_updateCount;

    //--- LC02/LC03: canonical history reset (HistoryEpoch broadcast).
    //    Context state is re-derived by the detectors themselves; this
    //    consumer only clears the CHOCH-count watermark used by the
    //    legacy trend-flip gate so the rebuilt stream is re-examined.
    void OnHistoryReset(void) { m_lastCHOCHCount = 0; }

    //--- Sprint 15.3: deferred outcome settlement.
    void QueueForSettlement(const TelemetryRow &row);
    bool SettleRow(TelemetryRow &row, datetime entryBarTime);
    void SettleDue(void);
    void SettleRemaining(void);

public:
    CSymbolContext(const string symbol, int magicNumber = 0, ENUM_ENTRY_MODE entryMode = ENTRY_MODE_LEGACY);
    ~CSymbolContext(void);

    bool Init(CEventBusAdapter *eventBus = NULL);
    void Update(double &open[], double &high[], double &low[], double &close[], datetime &time[], int rates_total);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }
    string GetSymbol(void) const { return m_symbol; }

    void SetEventBus(CEventBusAdapter *bus) { m_eventBus = bus; }
    void SetMagicNumber(int magic) { m_magicNumber = magic; }
    void SetPortfolioRiskManager(CPortfolioRiskManager *prm) { m_portfolioRiskManager = prm; }
    //--- Sprint 15 (v3.0): mode must be set at construction - providers are
    //    bound in the ctor and the validators capture them there. Changing
    //    the mode afterwards without re-binding providers desyncs the DI.
    void SetEntryMode(ENUM_ENTRY_MODE mode)
    {
        if(mode != m_entryMode)
            m_logger.LogWarn("SetEntryMode called after construction - provider binding unchanged; mode desync");
        m_entryMode = mode;
    }
    void SetTelemetryCollector(CTelemetryCollector *collector) { m_telemetry = collector; }
    void SetWeights(const ConfluenceWeights &weights) { m_weights = weights; }

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

CSymbolContext::CSymbolContext(const string symbol, int magicNumber, ENUM_ENTRY_MODE entryMode)
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
    , m_entryOrchestrator(NULL)
    , m_entryMode(entryMode)
    , m_telemetry(NULL)
    , m_outcomePolicy()
    , m_pendingCount(0)
    , m_shadowProvider()
    , m_shadowRisk()
    , m_productionProvider(m_symbol, (long)m_magicNumber)
    , m_productionRisk(m_symbol)
    , m_stateProvider(&m_shadowProvider)
    , m_riskEvaluator(&m_shadowRisk)
    , m_cooldownVal(m_stateProvider)
    , m_riskVal(m_riskEvaluator)
    , m_lastCHOCHCount(0)
    , m_updateCount(0)
{
    //--- Sprint 15 (v3.0): providers are bound in the ctor because the
    //    validators capture their provider pointers at construction.
    //    MQL5 has no ternary operator, so NEW-mode binding is done here
    //    (init list defaults to shadow providers).
    if(entryMode == ENTRY_MODE_NEW)
    {
        m_stateProvider = &m_productionProvider;
        m_riskEvaluator = &m_productionRisk;
        m_cooldownVal.SetProvider(&m_productionProvider);
        m_riskVal.SetRiskEvaluator(&m_productionRisk);
        m_logger.LogInfo(StringFormat(
            "Production providers active - TradeState(symbol=%s magic=%d tf=%s) Risk(name=ProductionRisk)",
            m_symbol, m_magicNumber, EnumToString(Period())));
    }
    else if(entryMode == ENTRY_MODE_SHADOW)
        m_logger.LogInfo("Providers: ShadowTradeState/ShadowRisk (mode SHADOW)");

    //--- Sprint 15.3: outcome settlement policy. FixedRR (SL 1R / TP 2R on
    //    entry-bar ATR) matches the frozen "FixedRR"/"1" telemetry config tag.
    m_outcomeSim.SetPolicy(&m_outcomePolicy);
    m_outcomeSim.SetMaxHoldBars(TELEMETRY_SETTLE_MAX_HOLD_BARS);
}

CSymbolContext::~CSymbolContext(void)
{
    Shutdown();
}

bool CSymbolContext::Init(CEventBusAdapter *eventBus)
{
    m_logger.LogInfo("Initializing context for " + m_symbol + "...");

    m_eventBus = eventBus;

    //--- LC02: re-init rebaselines the epoch (fresh context = fresh history).
    m_epoch.Reset();

    //--- Sprint 15 (v3.0): provider selection (DI) happens at construction
    //    (see ctor); the validators capture their providers there. If the
    //    entry mode is changed later, provider binding must be re-done.

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

    //--- LC03: register every stateful detector with the canonical
    //    reset mechanism (epoch broadcast -> OnHistoryReset -> Clear()).
    //    Registration order = broadcast order (dependency order).
    if(m_swingDetector != NULL)         m_epoch.AddConsumer(m_swingDetector);
    if(m_structuralPivotEngine != NULL) m_epoch.AddConsumer(m_structuralPivotEngine);
    if(m_bosDetector != NULL)           m_epoch.AddConsumer(m_bosDetector);
    if(m_trendState != NULL)            m_epoch.AddConsumer(m_trendState);
    if(m_protectedPointManager != NULL) m_epoch.AddConsumer(m_protectedPointManager);
    if(m_chochDetector != NULL)         m_epoch.AddConsumer(m_chochDetector);
    if(m_orderBlockDetector != NULL)    m_epoch.AddConsumer(m_orderBlockDetector);
    if(m_fvgDetector != NULL)           m_epoch.AddConsumer(m_fvgDetector);
    if(m_liquidityDetector != NULL)     m_epoch.AddConsumer(m_liquidityDetector);
    m_epoch.AddConsumer(GetPointer(this));

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

        //--- v2.9: apply calibrated weights (Sprint 14); default if invalid.
        if(!m_weights.IsValid())
        {
            m_logger.LogWarn("Confluence weights invalid (sum != 100), using defaults: " + m_weights.ToString());
            m_weights.ResetToDefaults();
        }
        m_confluenceEngine.SetWeights(m_weights);
        m_logger.LogInfo("Confluence weights: " + m_weights.ToString());
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
    if(m_tradeExecutionManager != NULL)
    {
        //--- Sprint 17.7A: order execution follows the entry-mode contract.
        //    Only ENTRY_MODE_LEGACY may send orders; SHADOW/NEW runs are
        //    shadow-only ("execution reserved until promotion gate passes").
        m_tradeExecutionManager.SetExecutionEnabled(m_entryMode == ENTRY_MODE_LEGACY);
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

    if(m_entryMode != ENTRY_MODE_LEGACY)
    {
        m_entryOrchestrator = new CEntryOrchestrator();
        if(m_entryOrchestrator != NULL)
        {
            m_entryOrchestrator.Init();
            m_entryOrchestrator.RegisterValidator(&m_dirVal);
            m_entryOrchestrator.RegisterValidator(&m_confVal);
            m_entryOrchestrator.RegisterValidator(&m_freshVal);
            m_entryOrchestrator.RegisterValidator(&m_spreadVal);
            m_entryOrchestrator.RegisterValidator(&m_sessVal);
            m_entryOrchestrator.RegisterValidator(&m_distVal);
            m_entryOrchestrator.RegisterValidator(&m_cooldownVal);
            m_entryOrchestrator.RegisterValidator(&m_riskVal);

            if(m_entryMode == ENTRY_MODE_SHADOW)
                m_entryOrchestrator.SetShadowMode(true);

            if(m_entryMode == ENTRY_MODE_NEW)
            {
                Print("[SymbolContext] ENTRY_MODE_NEW: production providers active — execution reserved until promotion gate passes");
                m_entryOrchestrator.SetShadowMode(true);
            }

            m_logger.LogInfo("EntryOrchestrator initialized with 8 validators");
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

    //--- LC02: detect history shrink / time reversal BEFORE driving any
    //    consumer. time[] is series-order (index 0 = newest bar) here,
    //    so timeNewest = time[0]. A detected reset broadcasts to all
    //    registered consumers (incl. this context).
    m_epoch.Update(rates_total, time[0]);

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
        m_liquidityDetector.Update(high, low, close, time, rates_total);
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

    if(m_entryOrchestrator != NULL && m_confluenceEngine != NULL && m_entryMode != ENTRY_MODE_LEGACY)
    {
        ConfluenceResult cr;
        if(m_confluenceEngine.GetLatestConfluence(cr) && cr.valid)
        {
            double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            double spreadPips = (ask - bid) / _Point;

            // TODO(v2.9): Replace with EntrySetup price once ExecutionPlanner integration exists
            double candPrice = bid;

            // TODO(v2.9): Replace with signal lifecycle age once tracked
            int barsSince = 0;

            ulong t0 = GetMicrosecondCount();
            EntryDecision newDecision = m_entryOrchestrator.Evaluate(
                cr, spreadPips, TimeCurrent(), bid, ask, barsSince, candPrice);
            ulong t1 = GetMicrosecondCount();

            if(m_entryMode == ENTRY_MODE_SHADOW || m_entryMode == ENTRY_MODE_NEW)
            {
                //--- A-01 (v2.9.2): decision-level comparison. The legacy
                //    side is the most recent CEntryDecisionEngine decision
                //    (persists until superseded or expired — same lifecycle
                //    semantics the planner plans had). The old plan-existence
                //    proxy is gone: status vs status, direction vs direction.
                EntryDecision legacyDecision;
                bool hasLegacy = m_confluenceEngine.GetLastEntryDecision(legacyDecision);
                bool legacyQualified = hasLegacy && (legacyDecision.status == DECISION_QUALIFIED);
                bool newQualified = (newDecision.status == DECISION_QUALIFIED);

                ShadowComparison cmp;
                cmp.formatVersion    = 2;
                cmp.timestamp        = TimeCurrent();
                cmp.symbol           = m_symbol;
                cmp.timeframe        = (ENUM_TIMEFRAMES)Period();
                cmp.eaVersion        = TELEMETRY_EA_VERSION;
                cmp.validationTimeUs = (uint)(t1 - t0);
                cmp.legacyConfidence = hasLegacy ? legacyDecision.confidence : 0.0;
                cmp.newConfidence    = newDecision.confidence;

                cmp.decisionMatch = (legacyQualified == newQualified);
                cmp.directionMatch = hasLegacy && (legacyDecision.direction == newDecision.direction);

                cmp.legacyFirstReason = REASON_NONE;
                cmp.newFirstReason = (newDecision.rejectionCount > 0)
                    ? REASON_UNKNOWN : REASON_NONE;

                m_entryOrchestrator.RecordShadowComparison(cmp);

                //--- A-03 (v2.9.2): persist one schema-v2 row per decision.
                if(m_telemetry != NULL)
                {
                    string disabled = "";
                    CValidatorRegistry *reg = m_entryOrchestrator.GetRegistry();
                    if(reg != NULL)
                    {
                        for(int v = 0; v < reg.Count(); v++)
                        {
                            if(!reg.IsEnabledAt(v))
                            {
                                IEntryValidator *val = reg.GetValidator(v);
                                if(val != NULL)
                                {
                                    if(disabled != "")
                                        disabled += ",";
                                    disabled += val.GetName();
                                }
                            }
                        }
                    }

                    TelemetryRow row;
                    //--- Sprint 17: schema v3 evidence capture. The runtime
                    //    ConfluenceSignal carries the rule/layer/evidence
                    //    observations the v2 columns never recorded; when it
                    //    is unavailable the row falls back to schema v3 with
                    //    componentData = 0 (refused by structural analysis).
                    ConfluenceSignal sig;
                    bool hasSig = m_confluenceEngine.GetLatestSignal(sig);
                    if(hasSig)
                        CTelemetryRowBuilder::BuildWithEvidence(row, cr, newDecision, hasLegacy,
                                                                legacyDecision,
                                                                m_confVal.GetMinConfidence(),
                                                                m_weights, m_symbol, (int)Period(),
                                                                disabled, "tick",
                                                                (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS),
                                                                ConfluenceConfig(),
                                                                sig);
                    else
                        CTelemetryRowBuilder::Build(row, cr, newDecision, hasLegacy,
                                                    legacyDecision,
                                                    m_confVal.GetMinConfidence(),
                                                    m_weights, m_symbol, (int)Period(),
                                                    disabled, "tick",
                                                    (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS),
                                                    ConfluenceConfig());
                    //--- Sprint 15.3: settle previously queued rows first so
                    //    the collector receives rows in decision order, then
                    //    queue the new row for forward-outcome settlement.
                    SettleDue();
                    QueueForSettlement(row);
                }
            }
        }
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

    //--- Sprint 15.3: settle whatever the run horizon still allows; the
    //    remaining rows are recorded unsettled (outcome UNKNOWN) so no
    //    decision is lost from the dataset.
    SettleRemaining();

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

    if(m_entryOrchestrator != NULL)
    {
        m_entryOrchestrator.Shutdown();
        delete m_entryOrchestrator;
        m_entryOrchestrator = NULL;
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

//+------------------------------------------------------------------+
//|  Sprint 15.3: deferred outcome settlement                         |
//+------------------------------------------------------------------+

void CSymbolContext::QueueForSettlement(const TelemetryRow &row)
{
    if(m_telemetry == NULL)
        return;

    int idx = m_pendingCount;
    if(idx >= ArraySize(m_pendingRows))
    {
        ArrayResize(m_pendingRows, idx + 256);
        ArrayResize(m_pendingEntryTime, idx + 256);
    }
    m_pendingRows[idx] = row;
    m_pendingEntryTime[idx] = iTime(m_symbol, (ENUM_TIMEFRAMES)Period(), 0);
    m_pendingCount++;
}

bool CSymbolContext::SettleRow(TelemetryRow &row, datetime entryBarTime)
{
    //--- Window: [warmStart, stopTime] in as-series (index 0 = newest).
    //    - warmStart = entry - (3 days + warmup) so the FixedRR policy has
    //      ATR(14) history even for Monday entries, whose back-window would
    //      otherwise fall inside the Fri-close to Mon-open session gap
    //    - stopTime  = entry + (hold + 2 days + hold-slack) so the forward
    //      scan always finds its 50 bars even across a session break
    //    The entry bar is located by time so session gaps never misplace it.
    int tfSeconds = PeriodSeconds((ENUM_TIMEFRAMES)Period());
    int needBars = TELEMETRY_SETTLE_MAX_HOLD_BARS + 1;
    int warmupBars = 20;
    int weekendBars = 2 * 24 * 60 * 60 / tfSeconds;      // 2 days of bars
    datetime warmStart = entryBarTime - (datetime)(3 * 24 * 60 * 60 + (long)warmupBars * tfSeconds);
    datetime stopTime  = entryBarTime + (datetime)((needBars + weekendBars + 50) * (long)tfSeconds);

    double open[];
    double high[];
    double low[];
    double close[];
    datetime times[];
    int n = CopyOpen(m_symbol, (ENUM_TIMEFRAMES)Period(), warmStart, stopTime, open);
    if(n < needBars + 1)
        return false;
    if(CopyHigh(m_symbol, (ENUM_TIMEFRAMES)Period(), warmStart, stopTime, high) != n)
        return false;
    if(CopyLow(m_symbol, (ENUM_TIMEFRAMES)Period(), warmStart, stopTime, low) != n)
        return false;
    if(CopyClose(m_symbol, (ENUM_TIMEFRAMES)Period(), warmStart, stopTime, close) != n)
        return false;
    if(CopyTime(m_symbol, (ENUM_TIMEFRAMES)Period(), warmStart, stopTime, times) != n)
        return false;

    //--- IMPORTANT: the time-range Copy* overloads return the window in
    //    ascending chronological order (oldest first), while the outcome
    //    simulator and its policies expect as-series arrays (index 0 =
    //    newest bar). Reverse the window so the entry bar sits at index
    //    (bars after entry) and older history is at higher indexes.
    ArrayReverse(open);
    ArrayReverse(high);
    ArrayReverse(low);
    ArrayReverse(close);
    ArrayReverse(times);

    int entryBarIndex = -1;
    for(int i = 0; i < n; i++)
    {
        if(times[i] == entryBarTime)
        {
            entryBarIndex = i;
            break;
        }
    }
    if(entryBarIndex < TELEMETRY_SETTLE_MAX_HOLD_BARS)
        return false;                       // not enough forward bars yet
    if(entryBarIndex + warmupBars >= n)
        return false;                       // not enough ATR warmup history

    SimulatedOutcome out;
    if(!m_outcomeSim.Simulate(m_symbol, (ENUM_TIMEFRAMES)Period(),
                              (ConfluenceDirection)row.direction,
                              entryBarIndex, open, high, low, close, out))
        return false;

    row.outcomeSource = (int)OUTCOME_SOURCE_SIMULATED;
    row.outcome = (int)out.outcome;
    row.rMultiple = out.rMultiple;
    row.barsHeld = out.barsHeld;
    row.exitReason = (int)out.exitReason;
    row.entryPrice = out.entryPrice;
    row.exitPrice = out.exitPrice;
    return true;
}

void CSymbolContext::SettleDue(void)
{
    if(m_pendingCount == 0)
        return;

    int keep = 0;
    for(int i = 0; i < m_pendingCount; i++)
    {
        TelemetryRow row = m_pendingRows[i];
        datetime entryBarTime = m_pendingEntryTime[i];
        int shift = iBarShift(m_symbol, (ENUM_TIMEFRAMES)Period(), entryBarTime, false);
        bool due = (shift >= TELEMETRY_SETTLE_MAX_HOLD_BARS);
        bool settled = false;
        if(due && SettleRow(row, entryBarTime))
        {
            m_telemetry.Record(row);
            settled = true;
        }
        if(!settled)
        {
            m_pendingRows[keep] = row;
            m_pendingEntryTime[keep] = entryBarTime;
            keep++;
        }
    }
    m_pendingCount = keep;
}

void CSymbolContext::SettleRemaining(void)
{
    if(m_telemetry == NULL)
        return;

    int total = m_pendingCount;
    int unsettled = 0;
    for(int i = 0; i < m_pendingCount; i++)
    {
        TelemetryRow row = m_pendingRows[i];
        datetime entryBarTime = m_pendingEntryTime[i];
        if(!SettleRow(row, entryBarTime))
            unsettled++;
        m_telemetry.Record(row);
    }
    m_pendingCount = 0;
    if(unsettled > 0)
        m_logger.LogInfo(StringFormat("Telemetry: %d of %d pending rows left unsettled (outcome UNKNOWN)",
                                      unsettled, total));
    m_logger.LogInfo("Telemetry: settlement pass complete");
}

#endif
