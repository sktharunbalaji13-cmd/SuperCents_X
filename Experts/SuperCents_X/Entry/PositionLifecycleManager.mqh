#ifndef __POSITION_LIFECYCLE_MANAGER_MQH__
#define __POSITION_LIFECYCLE_MANAGER_MQH__

#include <Trade/Trade.mqh>
#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "PositionManager.mqh"

class CPositionLifecycleManager
{
private:
    CLogger          m_logger;
    CPositionManager *m_positionManager;
    CTrade           m_trade;
    bool             m_isInitialized;
    string           m_symbol;
    int              m_magicNumber;

    bool             m_beEnabled;
    double           m_beTriggerR;

    bool             m_tsEnabled;
    double           m_tsTriggerR;
    double           m_tsDistance;

    ulong            m_trackedTicket;
    double           m_initialSL;
    bool             m_breakEvenApplied;

    void            ResetTracking(void);
    void            TrackPosition(const PositionInfo &pos);
    void            CheckBreakeven(PositionInfo &pos);
    void            CheckTrailingStop(PositionInfo &pos);
    double          CalculateRRatio(const PositionInfo &pos);

public:
    CPositionLifecycleManager(void);
    ~CPositionLifecycleManager(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    void SetPositionManager(CPositionManager *pm) { m_positionManager = pm; }
    void SetMagicNumber(int magic) { m_magicNumber = magic; }
    void SetSymbol(string symbol) { m_symbol = symbol; }

    void EnableBreakeven(bool enable) { m_beEnabled = enable; }
    bool IsBreakevenEnabled(void) const { return m_beEnabled; }
    void SetBreakevenTrigger(double rMultiple) { m_beTriggerR = MathMax(rMultiple, 0.1); }
    double GetBreakevenTrigger(void) const { return m_beTriggerR; }

    void EnableTrailingStop(bool enable) { m_tsEnabled = enable; }
    bool IsTrailingStopEnabled(void) const { return m_tsEnabled; }
    void SetTrailingStopTrigger(double rMultiple) { m_tsTriggerR = MathMax(rMultiple, 0.1); }
    double GetTrailingStopTrigger(void) const { return m_tsTriggerR; }
    void SetTrailingStopDistance(double distance) { m_tsDistance = MathMax(distance, _Point); }
    double GetTrailingStopDistance(void) const { return m_tsDistance; }

    bool ModifyPosition(ulong ticket, double sl, double tp);

    double CalculateRRatioForTest(const PositionInfo &pos) { return CalculateRRatio(pos); }
    bool   IsBreakEvenApplied(void) const { return m_breakEvenApplied; }
    ulong  GetTrackedTicket(void) const { return m_trackedTicket; }
    double GetInitialSLForTest(void) const { return m_initialSL; }
};

CPositionLifecycleManager::CPositionLifecycleManager(void)
    : m_logger(MODULE_TRADE_MANAGER, "PositionLifecycle")
    , m_positionManager(NULL)
    , m_isInitialized(false)
    , m_symbol("")
    , m_magicNumber(0)
    , m_beEnabled(false)
    , m_beTriggerR(1.0)
    , m_tsEnabled(false)
    , m_tsTriggerR(2.0)
    , m_tsDistance(100.0 * _Point)
    , m_trackedTicket(0)
    , m_initialSL(0.0)
    , m_breakEvenApplied(false)
{
}

CPositionLifecycleManager::~CPositionLifecycleManager(void)
{
    Shutdown();
}

bool CPositionLifecycleManager::Init(void)
{
    m_logger.LogInfo("Initializing PositionLifecycleManager...");
    m_isInitialized = true;
    m_symbol = _Symbol;
    m_logger.LogInfo("PositionLifecycleManager initialized");
    return true;
}

void CPositionLifecycleManager::Update(void)
{
    if(!m_isInitialized || m_positionManager == NULL)
        return;

    PositionInfo pos;
    if(!m_positionManager.GetPosition(m_symbol, m_magicNumber, pos))
    {
        ResetTracking();
        return;
    }

    TrackPosition(pos);

    if(m_beEnabled)
        CheckBreakeven(pos);

    if(m_tsEnabled)
    {
        PositionInfo refreshedPos;
        if(m_positionManager.GetPositionByTicket(m_trackedTicket, refreshedPos))
            CheckTrailingStop(refreshedPos);
    }
}

void CPositionLifecycleManager::Shutdown(void)
{
    if(!m_isInitialized)
        return;
    m_logger.LogInfo("Shutting down PositionLifecycleManager...");
    ResetTracking();
    m_isInitialized = false;
    m_logger.LogInfo("PositionLifecycleManager shutdown complete");
}

void CPositionLifecycleManager::ResetTracking(void)
{
    m_trackedTicket = 0;
    m_initialSL = 0.0;
    m_breakEvenApplied = false;
}

void CPositionLifecycleManager::TrackPosition(const PositionInfo &pos)
{
    if(pos.ticket != m_trackedTicket)
    {
        m_trackedTicket = pos.ticket;
        m_initialSL = pos.sl;
        m_breakEvenApplied = false;
    }
}

double CPositionLifecycleManager::CalculateRRatio(const PositionInfo &pos)
{
    if(m_initialSL <= 0.0 || pos.priceOpen <= 0.0)
        return 0.0;

    double risk = MathAbs(pos.priceOpen - m_initialSL);
    if(risk <= _Point)
        return 0.0;

    double currentPrice = (pos.type == POSITION_TYPE_BUY)
        ? SymbolInfoDouble(m_symbol, SYMBOL_BID)
        : SymbolInfoDouble(m_symbol, SYMBOL_ASK);

    double profitInPrice = (pos.type == POSITION_TYPE_BUY)
        ? currentPrice - pos.priceOpen
        : pos.priceOpen - currentPrice;

    return profitInPrice / risk;
}

void CPositionLifecycleManager::CheckBreakeven(PositionInfo &pos)
{
    if(m_breakEvenApplied)
        return;

    if(CalculateRRatio(pos) < m_beTriggerR)
        return;

    double newSL = pos.priceOpen;

    bool isImprovement = (pos.type == POSITION_TYPE_BUY) ? (newSL > pos.sl) : (newSL < pos.sl);
    if(!isImprovement)
        return;

    if(ModifyPosition(pos.ticket, newSL, pos.tp))
    {
        m_logger.LogInfo(StringFormat("Break-even applied: ticket=%lld SL moved from %.5f to %.5f",
            pos.ticket, pos.sl, newSL));
        m_breakEvenApplied = true;
    }
}

void CPositionLifecycleManager::CheckTrailingStop(PositionInfo &pos)
{
    if(CalculateRRatio(pos) < m_tsTriggerR)
        return;

    double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);

    double newSL = (pos.type == POSITION_TYPE_BUY) ? (bid - m_tsDistance) : (ask + m_tsDistance);

    bool isImprovement = (pos.type == POSITION_TYPE_BUY) ? (newSL > pos.sl) : (newSL < pos.sl);
    if(!isImprovement)
        return;

    if(MathAbs(newSL - pos.sl) < _Point / 2.0)
        return;

    double stopLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    if(pos.type == POSITION_TYPE_BUY)
    {
        if(bid - newSL < stopLevel)
            return;
    }
    else
    {
        if(newSL - ask < stopLevel)
            return;
    }

    if(ModifyPosition(pos.ticket, newSL, pos.tp))
    {
        m_logger.LogInfo(StringFormat("Trailing stop updated: ticket=%lld SL moved from %.5f to %.5f (R=%.2f)",
            pos.ticket, pos.sl, newSL, CalculateRRatio(pos)));
    }
}

bool CPositionLifecycleManager::ModifyPosition(ulong ticket, double sl, double tp)
{
    if(!m_isInitialized)
        return false;

    m_trade.SetExpertMagicNumber(m_magicNumber);
    bool result = m_trade.PositionModify(ticket, sl, tp);

    if(!result)
    {
        m_logger.LogWarn(StringFormat("ModifyPosition failed: ticket=%lld sl=%.5f tp=%.5f retcode=%u",
            ticket, sl, tp, m_trade.ResultRetcode()));
    }

    return result;
}

#endif