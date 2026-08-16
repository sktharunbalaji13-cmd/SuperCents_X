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
#include "../Monitoring/EventBusAdapter.mqh"
#include "../Portfolio/PortfolioManager.mqh"
#include "../Portfolio/PortfolioTypes.mqh"
#include "../Confluence/ConfluenceWeights.mqh"
#include "../Telemetry/TelemetryCollector.mqh"

class CEngine
{
private:
    bool m_isInitialized;
    bool m_isRunning;
    CLogger m_logger;
    CConfig m_config;
    ConfluenceWeights m_weights;

    CPortfolioManager  *m_portfolioManager;
    CEventBusAdapter   *m_eventBus;
    CTelemetryCollector m_telemetry;

    bool CopyOHLCArrays(double &open[], double &high[], double &low[], double &close[], datetime &time[]);
    bool IsNewBar(void);

public:
    CEngine(void);
    ~CEngine(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsRunning(void) const { return m_isRunning; }
    bool IsInitialized(void) const { return m_isInitialized; }

    void SetEntryMode(ENUM_ENTRY_MODE mode) { m_config.SetEntryMode(mode); }
    //--- C1 (integrity): stable order magic from the EA input, applied
    //    before Init so every symbol context and the TradeManager use it.
    void SetMagicNumber(int magic) { m_config.SetMagicNumber(magic); }
    //--- C2 (integrity): risk-per-trade percent and per-symbol position
    //    cap, applied to the primary context after registration.
    void SetRiskPercent(double pct) { m_config.SetRiskPercent(pct); }
    void SetMaxPositionsPerSymbol(int max) { m_config.SetMaxPositionsPerSymbol(max); }
    //--- ED01-D prerequisite: outcome TP arm for the replay outcome
    //    simulator (applied to the primary context during Init).
    void SetOutcomeTpMode(ENUM_OUTCOME_TP_MODE mode) { m_config.SetOutcomeTpMode(mode); }
    //--- ED01-E prerequisite: fixed-RR TP tier (R-multiple) for the tier
    //    sweep; applied to the primary context during Init. Default 2.0R.
    void SetFixedRrTier(double tier) { m_config.SetFixedRrTier(tier); }
    //--- Sprint 22 (RL-HYP-01) prerequisite: swing-significance admission
    //    gate tier (k in k x ATR(14), protocol §5/§14); applied to the
    //    primary context during Init. Default 0.0 = OFF (B8 behavior).
    void SetSwingSignificanceTier(double tier) { m_config.SetSwingSignificanceTier(tier); }
    double GetSwingSignificanceTier(void) const { return m_config.GetSwingSignificanceTier(); }
    void SetWeights(const ConfluenceWeights &weights) { m_weights = weights; }
    ConfluenceWeights GetWeights(void) const { return m_weights; }

    CSwingDetector             *GetSwingDetector(void) const;
    CStructuralPivotEngine     *GetStructuralPivotEngine(void) const;
    CBOSDetector               *GetBOSDetector(void) const;
    CProtectedPointManager     *GetProtectedPointManager(void) const;
    COrderBlockDetector        *GetOrderBlockDetector(void) const;
    CFVGDetector               *GetFVGDetector(void) const;
    CLiquidityDetector         *GetLiquidityDetector(void) const;
    CTrendState                *GetTrendState(void) const;
    CCHOCHDetector             *GetCHOCHDetector(void) const;
    CConfluenceEngine          *GetConfluenceEngine(void) const;
    CEntryEngine               *GetEntryEngine(void) const;
    CRiskManager               *GetRiskManager(void) const;
    CExecutionManager          *GetExecutionManager(void) const;
    CPositionManager           *GetPositionManager(void) const;
    CPositionLifecycleManager  *GetPositionLifecycleManager(void) const;
    CTradeManager              *GetTradeExecutionManager(void) const;
    CMetricsCollector          *GetMetricsCollector(void) const;
    CHealthMonitor             *GetHealthMonitor(void) const;
    CStatisticsReporter        *GetStatisticsReporter(void) const;
    CEventBusAdapter           *GetEventBus(void) const { return m_eventBus; }
    CPortfolioManager          *GetPortfolioManager(void) const { return m_portfolioManager; }
};

CEngine::CEngine(void)
    : m_isInitialized(false), m_isRunning(false), m_logger(MODULE_ENGINE, "Engine")
    , m_portfolioManager(NULL)
    , m_eventBus(NULL)
{
}

CEngine::~CEngine(void)
{
    Shutdown();
}

bool CEngine::Init(void)
{
    m_logger.LogInfo("Initializing Engine...");

    if(!m_config.Init())
    {
        m_logger.LogError("Failed to initialize configuration");
        return false;
    }

    m_logger.LogInfo("Configuration initialized");

    m_eventBus = new CEventBusAdapter();
    if(m_eventBus != NULL)
    {
        if(!m_eventBus.Init())
        {
            m_logger.LogError("Failed to initialize EventBus");
            delete m_eventBus;
            m_eventBus = NULL;
        }
    }

    m_portfolioManager = new CPortfolioManager();
    if(m_portfolioManager == NULL)
    {
        m_logger.LogError("Failed to create PortfolioManager");
        if(m_eventBus != NULL)
        {
            m_eventBus.Shutdown();
            delete m_eventBus;
            m_eventBus = NULL;
        }
        return false;
    }

    if(!m_portfolioManager.Init(m_eventBus))
    {
        m_logger.LogError("Failed to initialize PortfolioManager");
        delete m_portfolioManager;
        m_portfolioManager = NULL;
        if(m_eventBus != NULL)
        {
            m_eventBus.Shutdown();
            delete m_eventBus;
            m_eventBus = NULL;
        }
        return false;
    }

    m_portfolioManager.SetWeights(m_weights);
    m_portfolioManager.SetTelemetryCollector(&m_telemetry);

    if(!m_portfolioManager.RegisterSymbol(_Symbol, m_config.GetMagicNumber(), m_config.GetEntryMode()))
    {
        m_logger.LogError("Failed to register primary symbol " + _Symbol);
        m_portfolioManager.Shutdown();
        delete m_portfolioManager;
        m_portfolioManager = NULL;
        if(m_eventBus != NULL)
        {
            m_eventBus.Shutdown();
            delete m_eventBus;
            m_eventBus = NULL;
        }
        return false;
    }

    //--- ED01-D prerequisite: apply the outcome TP mode to the primary
    //    context so the replay outcome simulator can run the opposing-
    //    liquidity arm for the experiment (default = FixedRR, B8 behavior).
    CSymbolContext *primary = m_portfolioManager.GetPrimaryContext();
    if(primary != NULL)
        primary.SetOutcomeTpMode(m_config.GetOutcomeTpMode());

    //--- ED01-E prerequisite: apply the fixed-RR TP tier to the primary
    //    context (default 2.0R = B8; the tier sweep overrides it per run).
    if(primary != NULL)
        primary.SetFixedRrTier(m_config.GetFixedRrTier());

    //--- Sprint 22 (RL-HYP-01) prerequisite: apply the swing-significance
    //    gate tier to the primary context (default 0.0 = OFF keeps B8;
    //    the experiment tiers override it per run).
    if(primary != NULL)
        primary.SetSwingSignificanceTier(m_config.GetSwingSignificanceTier());

    //--- C2/C3 (integrity): forward the risk % and per-symbol position cap
    //    to the primary context so the TradeManager uses them at execution.
    if(primary != NULL)
    {
        primary.SetRiskPercent(m_config.GetRiskPercent());
        primary.SetMaxPositionsPerSymbol(m_config.GetMaxPositionsPerSymbol());
    }

    m_logger.LogInfo("Engine initialization complete");
    m_telemetry.Init();
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

    if(!IsNewBar())
        return;

    ulong t0 = GetMicrosecondCount();

    double open[];
    double high[];
    double low[];
    double close[];
    datetime time[];

    if(!CopyOHLCArrays(open, high, low, close, time))
        return;
    ulong t1 = GetMicrosecondCount();

    int rates_total = ArraySize(high);

    m_portfolioManager.Update(open, high, low, close, time, rates_total);
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

    if(m_portfolioManager != NULL)
    {
        m_portfolioManager.Shutdown();
        delete m_portfolioManager;
        m_portfolioManager = NULL;
    }

    m_telemetry.Shutdown();

    if(m_eventBus != NULL)
    {
        m_eventBus.Shutdown();
        delete m_eventBus;
        m_eventBus = NULL;
    }

    m_isInitialized = false;
    m_logger.LogInfo("Engine shutdown complete");
}

CSwingDetector *CEngine::GetSwingDetector(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetSwingDetector() : NULL;
}

CStructuralPivotEngine *CEngine::GetStructuralPivotEngine(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetStructuralPivotEngine() : NULL;
}

CBOSDetector *CEngine::GetBOSDetector(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetBOSDetector() : NULL;
}

CProtectedPointManager *CEngine::GetProtectedPointManager(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetProtectedPointManager() : NULL;
}

COrderBlockDetector *CEngine::GetOrderBlockDetector(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetOrderBlockDetector() : NULL;
}

CFVGDetector *CEngine::GetFVGDetector(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetFVGDetector() : NULL;
}

CLiquidityDetector *CEngine::GetLiquidityDetector(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetLiquidityDetector() : NULL;
}

CTrendState *CEngine::GetTrendState(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetTrendState() : NULL;
}

CCHOCHDetector *CEngine::GetCHOCHDetector(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetCHOCHDetector() : NULL;
}

CConfluenceEngine *CEngine::GetConfluenceEngine(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetConfluenceEngine() : NULL;
}

CEntryEngine *CEngine::GetEntryEngine(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetEntryEngine() : NULL;
}

CRiskManager *CEngine::GetRiskManager(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetRiskManager() : NULL;
}

CExecutionManager *CEngine::GetExecutionManager(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetExecutionManager() : NULL;
}

CPositionManager *CEngine::GetPositionManager(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetPositionManager() : NULL;
}

CPositionLifecycleManager *CEngine::GetPositionLifecycleManager(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetPositionLifecycleManager() : NULL;
}

CTradeManager *CEngine::GetTradeExecutionManager(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetTradeExecutionManager() : NULL;
}

CMetricsCollector *CEngine::GetMetricsCollector(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetMetricsCollector() : NULL;
}

CHealthMonitor *CEngine::GetHealthMonitor(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetHealthMonitor() : NULL;
}

CStatisticsReporter *CEngine::GetStatisticsReporter(void) const
{
    if(m_portfolioManager == NULL) return NULL;
    CSymbolContext *ctx = m_portfolioManager.GetPrimaryContext();
    return (ctx != NULL) ? ctx.GetStatisticsReporter() : NULL;
}

bool CEngine::CopyOHLCArrays(double &open[], double &high[], double &low[], double &close[], datetime &time[])
{
    int bars = Bars(_Symbol, _Period);

    if(bars < 5)
        return false;

    if(CopyOpen(_Symbol, _Period, 0, bars, open) <= 0)
    {
        m_logger.LogError("Failed to copy Open array");
        return false;
    }

    if(CopyHigh(_Symbol, _Period, 0, bars, high) <= 0)
    {
        m_logger.LogError("Failed to copy High array");
        return false;
    }

    if(CopyLow(_Symbol, _Period, 0, bars, low) <= 0)
    {
        m_logger.LogError("Failed to copy Low array");
        return false;
    }

    if(CopyClose(_Symbol, _Period, 0, bars, close) <= 0)
    {
        m_logger.LogError("Failed to copy Close array");
        return false;
    }

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

#endif
