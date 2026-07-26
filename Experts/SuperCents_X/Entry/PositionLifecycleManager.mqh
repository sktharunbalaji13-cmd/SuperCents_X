#ifndef __POSITION_LIFECYCLE_MANAGER_MQH__
#define __POSITION_LIFECYCLE_MANAGER_MQH__

#include <Trade/Trade.mqh>
#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "PositionManager.mqh"
#include "PositionLifecycleTypes.mqh"

#define MAX_POSITION_CONTEXTS 2048

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

    PositionContext  m_contexts[MAX_POSITION_CONTEXTS];
    int              m_contextCount;

    int     m_statDiscovered;
    int     m_statRecovered;
    int     m_statBreakEvenApplied;
    int     m_statTrailingUpdates;
    int     m_statPartialCloses;
    int     m_statClosed;
    ulong   m_statTotalLifetime;
    ulong   m_statMaxLifetime;

    int     FindContext(ulong ticket);
    int     AddContext(const PositionInfo &pos);
    bool    RemoveContext(int index);
    void    DiscoverPositions(void);
    void    ProcessContext(int index);
    bool    RefreshPositionData(int index, PositionInfo &pos);
    bool    ParseEntryDecisionId(const string comment, int &outId);

    void    DetectPartialClose(int index, PositionInfo &pos);
    void    PurgeClosedContexts(void);
    void    StringFromState(PositionState state, string &out);

    double  CalculateRRatio(const PositionContext &ctx, const PositionInfo &pos);

    bool    ApplyBreakeven(int index, const PositionInfo &pos);
    bool    ApplyTrailingStop(int index, const PositionInfo &pos);

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

    int  GetContextCount(void) const { return m_contextCount; }
    bool GetContext(int index, PositionContext &out) const;
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
    , m_contextCount(0)
    , m_statDiscovered(0)
    , m_statRecovered(0)
    , m_statBreakEvenApplied(0)
    , m_statTrailingUpdates(0)
    , m_statPartialCloses(0)
    , m_statClosed(0)
    , m_statTotalLifetime(0)
    , m_statMaxLifetime(0)
{
    ZeroMemory(m_contexts);
}

CPositionLifecycleManager::~CPositionLifecycleManager(void)
{
    Shutdown();
}

bool CPositionLifecycleManager::Init(void)
{
    m_logger.LogInfo("Initializing PositionLifecycleManager...");
    m_symbol = _Symbol;
    m_isInitialized = true;

    DiscoverPositions();

    m_logger.LogInfo(StringFormat("PositionLifecycleManager initialized: %d context(s) from broker",
        m_statRecovered));
    return true;
}

void CPositionLifecycleManager::Update(void)
{
    if(!m_isInitialized || m_positionManager == NULL)
        return;

    DiscoverPositions();
    PurgeClosedContexts();

    for(int i = 0; i < m_contextCount; i++)
    {
        if(m_contexts[i].ticket == 0)
            continue;
        ProcessContext(i);
    }
}

void CPositionLifecycleManager::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("=== POSITION LIFECYCLE SUMMARY ===");
    m_logger.LogInfo(StringFormat("Discovered: %d", m_statDiscovered));
    m_logger.LogInfo(StringFormat("Recovered: %d", m_statRecovered));
    m_logger.LogInfo(StringFormat("Break-even Applied: %d", m_statBreakEvenApplied));
    m_logger.LogInfo(StringFormat("Trailing Updates: %d", m_statTrailingUpdates));
    m_logger.LogInfo(StringFormat("Partial Closes: %d", m_statPartialCloses));
    m_logger.LogInfo(StringFormat("Closed: %d", m_statClosed));

    int activeCount = 0;
    for(int i = 0; i < m_contextCount; i++)
    {
        if(m_contexts[i].ticket != 0 && m_contexts[i].state < POS_STATE_CLOSED)
            activeCount++;
    }
    m_logger.LogInfo(StringFormat("Active: %d", activeCount));

    if(m_statClosed > 0)
    {
        double avgLifetime = (double)m_statTotalLifetime / (double)m_statClosed;
        m_logger.LogInfo(StringFormat("Average Lifetime: %.0f sec", avgLifetime));
    }
    m_logger.LogInfo(StringFormat("Longest Lifetime: %llu sec", m_statMaxLifetime));

    m_isInitialized = false;
    m_contextCount = 0;
    m_logger.LogInfo("PositionLifecycleManager shutdown complete");
}

bool CPositionLifecycleManager::GetContext(int index, PositionContext &out) const
{
    if(index < 0 || index >= m_contextCount)
        return false;
    if(m_contexts[index].ticket == 0)
        return false;
    out = m_contexts[index];
    return true;
}

//------------------------------------------------------------------
// Context storage
//------------------------------------------------------------------

int CPositionLifecycleManager::FindContext(ulong ticket)
{
    for(int i = 0; i < m_contextCount; i++)
    {
        if(m_contexts[i].ticket == ticket)
            return i;
    }
    return -1;
}

int CPositionLifecycleManager::AddContext(const PositionInfo &pos)
{
    if(m_contextCount >= MAX_POSITION_CONTEXTS)
    {
        m_logger.LogWarn("Max position contexts reached");
        return -1;
    }

    int idx = m_contextCount;
    m_contexts[idx].ticket = pos.ticket;
    m_contexts[idx].executionPlanId = 0;
    m_contexts[idx].candidateId = 0;
    m_contexts[idx].state = POS_STATE_DISCOVERED;

    m_contexts[idx].entryPrice = pos.priceOpen;
    m_contexts[idx].initialStop = pos.sl;
    m_contexts[idx].currentStop = pos.sl;
    m_contexts[idx].currentTarget = pos.tp;
    m_contexts[idx].lastVolume = pos.volume;

    m_contexts[idx].breakEvenApplied = false;
    m_contexts[idx].trailingActive = false;

    m_contexts[idx].openedTime = pos.time;
    m_contexts[idx].lastUpdateTime = pos.time;
    m_contexts[idx].closedTime = 0;

    int decId = 0;
    if(ParseEntryDecisionId(pos.comment, decId))
        m_contexts[idx].entryDecisionId = decId;

    m_contextCount++;
    return idx;
}

bool CPositionLifecycleManager::RemoveContext(int index)
{
    if(index < 0 || index >= m_contextCount)
        return false;
    if(m_contexts[index].ticket == 0)
        return false;

    for(int i = index; i < m_contextCount - 1; i++)
        m_contexts[i] = m_contexts[i + 1];

    m_contextCount--;
    m_contexts[m_contextCount].ticket = 0;
    return true;
}

void CPositionLifecycleManager::PurgeClosedContexts(void)
{
    for(int i = m_contextCount - 1; i >= 0; i--)
    {
        if(m_contexts[i].ticket != 0 && m_contexts[i].state == POS_STATE_CLOSED)
            RemoveContext(i);
    }
}

//------------------------------------------------------------------
// Position discovery (runs on Init and every Update)
//------------------------------------------------------------------

void CPositionLifecycleManager::DiscoverPositions(void)
{
    if(m_positionManager == NULL)
        return;

    int total = PositionsTotal();
    ulong currentTickets[];
    ArrayResize(currentTickets, total);

    for(int i = 0; i < total; i++)
    {
        string sym = PositionGetSymbol(i);
        if(sym == "")
            continue;

        if(!PositionSelect(sym))
            continue;

        if((int)PositionGetInteger(POSITION_MAGIC) != m_magicNumber)
            continue;
        if(PositionGetString(POSITION_SYMBOL) != m_symbol)
            continue;

        ulong ticket = PositionGetInteger(POSITION_TICKET);
        currentTickets[i] = ticket;

        if(FindContext(ticket) >= 0)
            continue;

        PositionInfo pos;
        if(m_positionManager.GetPositionByTicket(ticket, pos))
        {
            int idx = AddContext(pos);
            if(idx >= 0)
            {
                m_statRecovered++;
                m_statDiscovered++;
                m_logger.LogInfo(StringFormat(
                    "POSITION-DISCOVERED Ticket=%llu Entry=%.5f SL=%.5f TP=%.5f Volume=%.2f",
                    ticket, pos.priceOpen, pos.sl, pos.tp, pos.volume));
            }
        }
    }
}

//------------------------------------------------------------------
// State machine
//------------------------------------------------------------------

void CPositionLifecycleManager::ProcessContext(int index)
{
    PositionInfo pos;
    if(!RefreshPositionData(index, pos))
    {
        if(m_contexts[index].state < POS_STATE_EXIT_PENDING)
        {
            string stateStr;
            StringFromState(m_contexts[index].state, stateStr);
            m_contexts[index].state = POS_STATE_CLOSED;
            m_contexts[index].closedTime = TimeCurrent();

            ulong lifetime = (m_contexts[index].closedTime - m_contexts[index].openedTime);
            m_statTotalLifetime += lifetime;
            if(lifetime > m_statMaxLifetime)
                m_statMaxLifetime = lifetime;
            m_statClosed++;

            m_logger.LogInfo(StringFormat(
                "POSITION-STATE Ticket=%llu %s->CLOSED Reason=PositionGone Volume=%.2f Lifetime=%llus",
                m_contexts[index].ticket, stateStr,
                m_contexts[index].lastVolume, lifetime));
        }
        return;
    }

    m_contexts[index].lastUpdateTime = pos.time;
    m_contexts[index].currentStop = pos.sl;
    m_contexts[index].currentTarget = pos.tp;

    DetectPartialClose(index, pos);

    PositionState prevState = m_contexts[index].state;

    switch(m_contexts[index].state)
    {
        case POS_STATE_DISCOVERED:
        {
            m_contexts[index].state = POS_STATE_OPEN;
            m_logger.LogInfo(StringFormat(
                "POSITION-STATE Ticket=%llu DISCOVERED->OPEN Entry=%.5f SL=%.5f TP=%.5f Volume=%.2f",
                m_contexts[index].ticket, pos.priceOpen, pos.sl, pos.tp, pos.volume));
            break;
        }

        case POS_STATE_OPEN:
        {
            if(m_beEnabled && !m_contexts[index].breakEvenApplied)
            {
                if(ApplyBreakeven(index, pos))
                    break;
            }
            if(m_tsEnabled)
            {
                if(ApplyTrailingStop(index, pos))
                    break;
            }
            break;
        }

        case POS_STATE_BREAK_EVEN:
        {
            if(m_tsEnabled)
            {
                if(ApplyTrailingStop(index, pos))
                    break;
            }
            break;
        }

        case POS_STATE_TRAILING:
        {
            if(m_tsEnabled)
            {
                ApplyTrailingStop(index, pos);
            }
            break;
        }

        case POS_STATE_PARTIAL:
        {
            if(m_beEnabled && !m_contexts[index].breakEvenApplied)
            {
                if(ApplyBreakeven(index, pos))
                    break;
            }
            if(m_tsEnabled)
            {
                if(ApplyTrailingStop(index, pos))
                    break;
            }
            break;
        }

        case POS_STATE_EXIT_PENDING:
        case POS_STATE_CLOSED:
            break;
    }
}

bool CPositionLifecycleManager::RefreshPositionData(int index, PositionInfo &pos)
{
    if(index < 0 || index >= m_contextCount)
        return false;
    if(m_contexts[index].ticket == 0)
        return false;

    return m_positionManager.GetPositionByTicket(m_contexts[index].ticket, pos);
}

//------------------------------------------------------------------
// Partial close detection
//------------------------------------------------------------------

void CPositionLifecycleManager::DetectPartialClose(int index, PositionInfo &pos)
{
    if(pos.volume < m_contexts[index].lastVolume - 0.001)
    {
        double closedVol = m_contexts[index].lastVolume - pos.volume;
        m_contexts[index].lastVolume = pos.volume;
        m_statPartialCloses++;

        string stateStr;
        StringFromState(m_contexts[index].state, stateStr);

        m_logger.LogInfo(StringFormat(
            "POSITION-STATE Ticket=%llu %s->PARTIAL Reason=PartialClose ClosedVolume=%.2f RemainingVolume=%.2f",
            m_contexts[index].ticket, stateStr, closedVol, pos.volume));

        m_contexts[index].state = POS_STATE_PARTIAL;
    }
}

//------------------------------------------------------------------
// Break-even
//------------------------------------------------------------------

bool CPositionLifecycleManager::ApplyBreakeven(int index, const PositionInfo &pos)
{
    if(m_contexts[index].breakEvenApplied)
        return false;

    double rr = CalculateRRatio(m_contexts[index], pos);
    if(rr < m_beTriggerR)
        return false;

    double newSL = pos.priceOpen;

    bool isImprovement = (pos.type == POSITION_TYPE_BUY)
        ? (newSL > pos.sl && newSL < SymbolInfoDouble(m_symbol, SYMBOL_BID))
        : (newSL < pos.sl && newSL > SymbolInfoDouble(m_symbol, SYMBOL_ASK));

    if(!isImprovement)
        return false;

    if(!ModifyPosition(pos.ticket, newSL, pos.tp))
        return false;

    m_contexts[index].breakEvenApplied = true;
    m_contexts[index].currentStop = newSL;
    m_statBreakEvenApplied++;

    m_contexts[index].state = POS_STATE_BREAK_EVEN;
    m_logger.LogInfo(StringFormat(
        "POSITION-STATE Ticket=%llu OPEN->BREAK_EVEN Reason=ProfitThresholdReached R=%.2f SL=%.5f",
        pos.ticket, rr, newSL));

    return true;
}

//------------------------------------------------------------------
// Trailing stop
//------------------------------------------------------------------

bool CPositionLifecycleManager::ApplyTrailingStop(int index, const PositionInfo &pos)
{
    double rr = CalculateRRatio(m_contexts[index], pos);
    if(rr < m_tsTriggerR)
        return false;

    double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);

    double newSL = (pos.type == POSITION_TYPE_BUY)
        ? (bid - m_tsDistance)
        : (ask + m_tsDistance);

    bool isImprovement = (pos.type == POSITION_TYPE_BUY)
        ? (newSL > pos.sl)
        : (newSL < pos.sl);
    if(!isImprovement)
        return false;

    if(MathAbs(newSL - pos.sl) < _Point)
        return false;

    double stopLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    if(pos.type == POSITION_TYPE_BUY)
    {
        if(bid - newSL < stopLevel)
            return false;
    }
    else
    {
        if(newSL - ask < stopLevel)
            return false;
    }

    if(!ModifyPosition(pos.ticket, newSL, pos.tp))
        return false;

    m_contexts[index].currentStop = newSL;
    m_contexts[index].trailingActive = true;
    m_statTrailingUpdates++;

    string prevStateStr;
    StringFromState(m_contexts[index].state, prevStateStr);

    m_contexts[index].state = POS_STATE_TRAILING;
    m_logger.LogInfo(StringFormat(
        "POSITION-STATE Ticket=%llu %s->TRAILING Reason=TrailingTriggered R=%.2f SL=%.5f Distance=%.1f",
        pos.ticket, prevStateStr, rr, newSL, m_tsDistance / _Point));

    return true;
}

//------------------------------------------------------------------
// R-ratio calculation
//------------------------------------------------------------------

double CPositionLifecycleManager::CalculateRRatio(const PositionContext &ctx, const PositionInfo &pos)
{
    if(ctx.initialStop <= 0.0 || ctx.entryPrice <= 0.0)
        return 0.0;

    double risk = MathAbs(ctx.entryPrice - ctx.initialStop);
    if(risk <= _Point)
        return 0.0;

    double currentPrice = (pos.type == POSITION_TYPE_BUY)
        ? SymbolInfoDouble(m_symbol, SYMBOL_BID)
        : SymbolInfoDouble(m_symbol, SYMBOL_ASK);

    double profitInPrice = (pos.type == POSITION_TYPE_BUY)
        ? currentPrice - ctx.entryPrice
        : ctx.entryPrice - currentPrice;

    return profitInPrice / risk;
}

//------------------------------------------------------------------
// Comment parsing for restart recovery
//------------------------------------------------------------------

bool CPositionLifecycleManager::ParseEntryDecisionId(const string comment, int &outId)
{
    int ppos = StringFind(comment, "-P");
    if(ppos < 0)
        return false;

    string numStr = StringSubstr(comment, ppos + 2);
    if(numStr == "")
        return false;

    outId = (int)StringToInteger(numStr);
    return true;
}

//------------------------------------------------------------------
// Logging helpers
//------------------------------------------------------------------

void CPositionLifecycleManager::StringFromState(PositionState state, string &out)
{
    switch(state)
    {
        case POS_STATE_DISCOVERED:   out = "DISCOVERED";   break;
        case POS_STATE_OPEN:         out = "OPEN";         break;
        case POS_STATE_BREAK_EVEN:   out = "BREAK_EVEN";   break;
        case POS_STATE_TRAILING:     out = "TRAILING";     break;
        case POS_STATE_PARTIAL:      out = "PARTIAL";      break;
        case POS_STATE_EXIT_PENDING: out = "EXIT_PENDING"; break;
        case POS_STATE_CLOSED:       out = "CLOSED";       break;
        default:                     out = "UNKNOWN";      break;
    }
}

//------------------------------------------------------------------
// Position modification
//------------------------------------------------------------------

bool CPositionLifecycleManager::ModifyPosition(ulong ticket, double sl, double tp)
{
    if(!m_isInitialized)
        return false;

    m_trade.SetExpertMagicNumber(m_magicNumber);
    bool result = m_trade.PositionModify(ticket, sl, tp);

    if(!result)
    {
        m_logger.LogWarn(StringFormat(
            "ModifyPosition failed: ticket=%lld sl=%.5f tp=%.5f retcode=%u",
            ticket, sl, tp, m_trade.ResultRetcode()));
    }

    return result;
}

#endif
