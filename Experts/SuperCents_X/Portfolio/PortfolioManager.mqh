//+------------------------------------------------------------------+
//|                                        PortfolioManager.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __PORTFOLIO_PORTFOLIO_MANAGER_MQH__
#define __PORTFOLIO_PORTFOLIO_MANAGER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "../Monitoring/EventBusAdapter.mqh"
#include "PortfolioTypes.mqh"
#include "SymbolContext.mqh"
#include "Scheduler.mqh"
#include "CorrelationManager.mqh"
#include "PortfolioStatistics.mqh"
#include "PortfolioRiskTypes.mqh"
#include "PortfolioExposureTracker.mqh"
#include "CapitalAllocator.mqh"
#include "AllocationEngine.mqh"
#include "PortfolioRiskManager.mqh"
#include "../Confluence/ConfluenceWeights.mqh"

class CPortfolioManager
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    CSymbolContext      *m_contexts[MAX_PORTFOLIO_SYMBOLS];
    int                  m_contextCount;
    string               m_contextSymbols[MAX_PORTFOLIO_SYMBOLS];
    int                  m_primaryIndex;

    CScheduler              m_scheduler;
    CCorrelationManager     m_correlationManager;
    CPortfolioStatistics    m_statistics;

    CPortfolioExposureTracker  m_exposureTracker;
    CAllocationEngine          m_allocationEngine;
    CPortfolioRiskManager      m_portfolioRiskManager;

    ConfluenceWeights          m_weights;

    CTelemetryCollector       *m_telemetryCollector;

    CEventBusAdapter    *m_eventBus;

    int FindSymbolIndex(const string symbol) const
    {
        for(int i = 0; i < m_contextCount; i++)
        {
            if(m_contextSymbols[i] == symbol)
                return i;
        }
        return -1;
    }

public:
    CPortfolioManager(void);
    ~CPortfolioManager(void);

    bool Init(CEventBusAdapter *eventBus = NULL);
    void Update(double &open[], double &high[], double &low[], double &close[], datetime &time[], int rates_total);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool RegisterSymbol(const string symbol, int magicNumber = 0, ENUM_ENTRY_MODE entryMode = ENTRY_MODE_LEGACY);
    bool RemoveSymbol(const string symbol);
    int  GetSymbolCount(void) const { return m_contextCount; }

    void SetWeights(const ConfluenceWeights &weights) { m_weights = weights; }
    ConfluenceWeights GetWeights(void) const { return m_weights; }

    void SetTelemetryCollector(CTelemetryCollector *collector) { m_telemetryCollector = collector; }

    CSymbolContext *GetContext(const string symbol);
    CSymbolContext *GetPrimaryContext(void);
    int GetPrimaryIndex(void) const { return m_primaryIndex; }

    CPortfolioStatistics     *GetStatistics(void) { return &m_statistics; }
    CScheduler               *GetScheduler(void) { return &m_scheduler; }
    CCorrelationManager      *GetCorrelationManager(void) { return &m_correlationManager; }
    CPortfolioRiskManager    *GetPortfolioRiskManager(void) { return &m_portfolioRiskManager; }
    CPortfolioExposureTracker *GetExposureTracker(void) { return &m_exposureTracker; }

    PortfolioSnapshot GetSnapshot(void) const;
};

CPortfolioManager::CPortfolioManager(void)
    : m_logger(MODULE_PORTFOLIO_MANAGER, "PortfolioManager")
    , m_isInitialized(false)
    , m_contextCount(0)
    , m_primaryIndex(-1)
    , m_eventBus(NULL)
{
    for(int i = 0; i < MAX_PORTFOLIO_SYMBOLS; i++)
    {
        m_contexts[i] = NULL;
        m_contextSymbols[i] = "";
    }
}

CPortfolioManager::~CPortfolioManager(void)
{
    Shutdown();
}

bool CPortfolioManager::Init(CEventBusAdapter *eventBus)
{
    m_logger.LogInfo("Initializing PortfolioManager...");

    m_eventBus = eventBus;

    if(!m_scheduler.Init())
    {
        m_logger.LogError("Failed to initialize Scheduler");
        return false;
    }

    if(!m_correlationManager.Init())
    {
        m_logger.LogError("Failed to initialize CorrelationManager");
        m_scheduler.Shutdown();
        return false;
    }

    if(!m_statistics.Init())
    {
        m_logger.LogError("Failed to initialize PortfolioStatistics");
        m_correlationManager.Shutdown();
        m_scheduler.Shutdown();
        return false;
    }

    if(!m_exposureTracker.Init())
    {
        m_logger.LogError("Failed to initialize ExposureTracker");
        m_statistics.Shutdown();
        m_correlationManager.Shutdown();
        m_scheduler.Shutdown();
        return false;
    }

    if(!m_allocationEngine.Init())
    {
        m_logger.LogError("Failed to initialize AllocationEngine");
        m_exposureTracker.Shutdown();
        m_statistics.Shutdown();
        m_correlationManager.Shutdown();
        m_scheduler.Shutdown();
        return false;
    }

    m_portfolioRiskManager.SetExposureTracker(&m_exposureTracker);
    m_portfolioRiskManager.SetAllocationEngine(&m_allocationEngine);
    m_portfolioRiskManager.SetCorrelationManager(&m_correlationManager);
    if(!m_portfolioRiskManager.Init())
    {
        m_logger.LogError("Failed to initialize PortfolioRiskManager");
        m_allocationEngine.Shutdown();
        m_exposureTracker.Shutdown();
        m_statistics.Shutdown();
        m_correlationManager.Shutdown();
        m_scheduler.Shutdown();
        return false;
    }

    m_isInitialized = true;
    m_logger.LogInfo("PortfolioManager initialized");
    return true;
}

void CPortfolioManager::Update(double &open[], double &high[], double &low[], double &close[], datetime &time[], int rates_total)
{
    if(!m_isInitialized)
        return;

    ulong t0 = GetMicrosecondCount();

    for(int i = 0; i < m_contextCount; i++)
    {
        if(m_contexts[i] != NULL && m_contexts[i].IsInitialized())
        {
            string symbol = m_contextSymbols[i];
            if(m_scheduler.ShouldUpdate(symbol, PERIOD_CURRENT))
            {
                m_contexts[i].Update(open, high, low, close, time, rates_total);
            }
        }
    }

    m_exposureTracker.Update();

    PortfolioSnapshot snap = GetSnapshot();
    m_statistics.UpdateFrom(snap);

    ulong t1 = GetMicrosecondCount();
    m_logger.LogDebug(StringFormat("PortfolioManager update: %d contexts, %llu us",
        m_contextCount, t1 - t0));
}

void CPortfolioManager::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down PortfolioManager...");

    m_portfolioRiskManager.Shutdown();
    m_allocationEngine.Shutdown();
    m_exposureTracker.Shutdown();
    m_statistics.Shutdown();
    m_correlationManager.Shutdown();
    m_scheduler.Shutdown();

    for(int i = m_contextCount - 1; i >= 0; i--)
    {
        if(m_contexts[i] != NULL)
        {
            m_contexts[i].Shutdown();
            delete m_contexts[i];
            m_contexts[i] = NULL;
            m_contextSymbols[i] = "";
        }
    }

    m_contextCount = 0;
    m_primaryIndex = -1;
    m_eventBus = NULL;
    m_isInitialized = false;

    m_logger.LogInfo("PortfolioManager shutdown complete");
}

bool CPortfolioManager::RegisterSymbol(const string symbol, int magicNumber, ENUM_ENTRY_MODE entryMode)
{
    if(!m_isInitialized)
    {
        m_logger.LogWarn("Cannot register symbol: PortfolioManager not initialized");
        return false;
    }

    if(m_contextCount >= MAX_PORTFOLIO_SYMBOLS)
    {
        m_logger.LogWarn(StringFormat("Max symbols (%d) reached, cannot register %s",
            MAX_PORTFOLIO_SYMBOLS, symbol));
        return false;
    }

    if(FindSymbolIndex(symbol) >= 0)
    {
        m_logger.LogWarn(StringFormat("Symbol %s already registered", symbol));
        return true;
    }

    CSymbolContext *ctx = new CSymbolContext(symbol, magicNumber);
    if(ctx == NULL)
        return false;

    ctx.SetEntryMode(entryMode);
    ctx.SetWeights(m_weights);
    ctx.SetTelemetryCollector(m_telemetryCollector);

    if(!ctx.Init(m_eventBus))
    {
        m_logger.LogError(StringFormat("Failed to initialize context for %s", symbol));
        delete ctx;
        return false;
    }

    int idx = m_contextCount;
    m_contexts[idx] = ctx;
    m_contextSymbols[idx] = symbol;
    m_contextCount++;

    ctx.SetPortfolioRiskManager(&m_portfolioRiskManager);

    if(m_primaryIndex < 0)
    {
        m_primaryIndex = idx;
        m_logger.LogInfo(StringFormat("Symbol %s registered as primary", symbol));
    }
    else
    {
        m_logger.LogInfo(StringFormat("Symbol %s registered (index %d)", symbol, idx));
    }

    return true;
}

bool CPortfolioManager::RemoveSymbol(const string symbol)
{
    int idx = FindSymbolIndex(symbol);
    if(idx < 0)
        return false;

    if(m_contexts[idx] != NULL)
    {
        m_contexts[idx].Shutdown();
        delete m_contexts[idx];
        m_contexts[idx] = NULL;
    }

    for(int i = idx; i < m_contextCount - 1; i++)
    {
        m_contexts[i] = m_contexts[i + 1];
        m_contextSymbols[i] = m_contextSymbols[i + 1];
    }

    m_contextCount--;
    m_contexts[m_contextCount] = NULL;
    m_contextSymbols[m_contextCount] = "";

    if(m_primaryIndex == idx)
    {
        m_primaryIndex = (m_contextCount > 0) ? 0 : -1;
    }
    else if(m_primaryIndex > idx)
    {
        m_primaryIndex--;
    }

    return true;
}

CSymbolContext *CPortfolioManager::GetContext(const string symbol)
{
    int idx = FindSymbolIndex(symbol);
    if(idx < 0)
        return NULL;
    return m_contexts[idx];
}

CSymbolContext *CPortfolioManager::GetPrimaryContext(void)
{
    if(m_primaryIndex < 0 || m_primaryIndex >= m_contextCount)
        return NULL;
    return m_contexts[m_primaryIndex];
}

PortfolioSnapshot CPortfolioManager::GetSnapshot(void) const
{
    PortfolioSnapshot snap;
    snap.activeSymbolCount = 0;
    snap.totalPositions = 0;
    snap.totalExposure = 0.0;
    snap.totalPL = 0.0;

    for(int i = 0; i < m_contextCount; i++)
    {
        if(m_contexts[i] != NULL && m_contexts[i].IsInitialized())
        {
            PerSymbolMetrics symSnap = m_contexts[i].GetSnapshot();
            snap.symbols[snap.activeSymbolCount] = symSnap;
            snap.activeSymbolCount++;
            snap.totalPositions += symSnap.positionCount;
            snap.totalExposure += symSnap.totalExposure;
            snap.totalPL += symSnap.unrealizedPL;
        }
    }

    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    snap.netExposurePercent = (equity > 0.0)
        ? (snap.totalExposure / equity) * 100.0
        : 0.0;

    return snap;
}

#endif
