//+------------------------------------------------------------------+
//|                                         ExposureTracker.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __RISK_EXPOSURE_TRACKER_MQH__
#define __RISK_EXPOSURE_TRACKER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "RiskTypes.mqh"

struct SymbolExposureEntry
{
    string  symbol;
    double  longVolume;
    double  shortVolume;
    double  longExposure;
    double  shortExposure;
    double  marginUsed;
};

#define MAX_EXPOSURE_ENTRIES 128

class CExposureTracker
{
private:
    CLogger m_logger;
    bool    m_isInitialized;
    string  m_symbol;

    double  m_totalOpenRisk;
    double  m_netLongExposure;
    double  m_netShortExposure;
    double  m_totalPortfolioExposure;
    double  m_marginUsed;
    double  m_marginFree;
    int     m_positionCount;

    SymbolExposureEntry m_entries[MAX_EXPOSURE_ENTRIES];
    int     m_entryCount;

public:
    CExposureTracker(void);
    ~CExposureTracker(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    ExposureSnapshot GetSnapshot(void) const;
    bool GetSymbolExposure(string symbol, SymbolExposureEntry &out) const;
    int GetEntryCount(void) const { return m_entryCount; }

private:
    void ClearExposure(void);
    void AddPosition(const SymbolExposureEntry &entry);
    int  FindOrAddSymbol(string symbol);
};

CExposureTracker::CExposureTracker(void)
    : m_logger(MODULE_EXPOSURE_TRACKER, "ExposureTracker")
    , m_isInitialized(false)
    , m_symbol(_Symbol)
    , m_totalOpenRisk(0.0)
    , m_netLongExposure(0.0)
    , m_netShortExposure(0.0)
    , m_totalPortfolioExposure(0.0)
    , m_marginUsed(0.0)
    , m_marginFree(0.0)
    , m_positionCount(0)
    , m_entryCount(0)
{
}

CExposureTracker::~CExposureTracker(void)
{
    Shutdown();
}

bool CExposureTracker::Init(void)
{
    m_logger.LogInfo("Initializing ExposureTracker...");
    m_isInitialized = true;
    Update();
    m_logger.LogInfo("ExposureTracker initialized");
    return true;
}

void CExposureTracker::Update(void)
{
    if(!m_isInitialized)
        return;

    ClearExposure();

    m_marginFree = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    m_positionCount = PositionsTotal();

    for(int i = 0; i < m_positionCount; i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0)
            continue;

        if(!PositionSelectByTicket(ticket))
            continue;

        SymbolExposureEntry entry;
        entry.symbol       = PositionGetString(POSITION_SYMBOL);
        double volume      = PositionGetDouble(POSITION_VOLUME);
        double priceOpen   = PositionGetDouble(POSITION_PRICE_OPEN);
        long type          = PositionGetInteger(POSITION_TYPE);
        double sl          = PositionGetDouble(POSITION_SL);
        double margin      = 0.0;

        if(entry.symbol == "")
            continue;

        //--- P37 (integrity, Fix 6): instrument-aware notional.
        //    vol*priceOpen is FX-shaped fiction on XAU/indices (and the risk
        //    leg ignored contract size). Unknown contract size falls back to
        //    legacy vol*price (never zero). Live sizing consumer is the dead
        //    CRiskManager path (P36 §4.10); this corrects display/snapshot
        //    values and any future live consumer. Caps untouched.
        double csPos = SymbolInfoDouble(entry.symbol, SYMBOL_TRADE_CONTRACT_SIZE);
        double notion = (csPos > 0.0) ? volume * priceOpen * csPos : volume * priceOpen;
        if(type == POSITION_TYPE_BUY)
        {
            entry.longVolume   = volume;
            entry.longExposure = notion;
        }
        else
        {
            entry.shortVolume   = volume;
            entry.shortExposure = notion;
        }

        if(sl > 0.0)
        {
            double riskPerUnit = MathAbs(priceOpen - sl) * volume;
            m_totalOpenRisk += (csPos > 0.0) ? riskPerUnit * csPos : riskPerUnit;
        }

        if(OrderCalcMargin((ENUM_ORDER_TYPE)type, entry.symbol, volume, priceOpen, margin))
            entry.marginUsed = margin;

        AddPosition(entry);
    }

    m_logger.LogInfo(StringFormat("EXPOSURE-UPDATE positions=%d long=$%.2f short=$%.2f total=$%.2f risk=$%.2f margin=$%.2f",
        m_positionCount, m_netLongExposure, m_netShortExposure, m_totalPortfolioExposure,
        m_totalOpenRisk, m_marginUsed));
}

void CExposureTracker::Shutdown(void)
{
    m_logger.LogInfo("Shutting down ExposureTracker...");
    ClearExposure();
    m_isInitialized = false;
    m_logger.LogInfo("ExposureTracker shutdown complete");
}

ExposureSnapshot CExposureTracker::GetSnapshot(void) const
{
    ExposureSnapshot snap;
    snap.totalOpenRisk        = m_totalOpenRisk;
    snap.netLongExposure      = m_netLongExposure;
    snap.netShortExposure     = m_netShortExposure;
    snap.totalPortfolioExposure = m_totalPortfolioExposure;
    snap.marginUsed           = m_marginUsed;
    snap.marginFree           = m_marginFree;
    snap.positionCount        = m_positionCount;
    return snap;
}

bool CExposureTracker::GetSymbolExposure(string symbol, SymbolExposureEntry &out) const
{
    for(int i = 0; i < m_entryCount; i++)
    {
        if(m_entries[i].symbol == symbol)
        {
            out = m_entries[i];
            return true;
        }
    }
    return false;
}

void CExposureTracker::ClearExposure(void)
{
    m_totalOpenRisk = 0.0;
    m_netLongExposure = 0.0;
    m_netShortExposure = 0.0;
    m_totalPortfolioExposure = 0.0;
    m_marginUsed = 0.0;
    m_positionCount = 0;
    m_entryCount = 0;
}

int CExposureTracker::FindOrAddSymbol(string symbol)
{
    for(int i = 0; i < m_entryCount; i++)
    {
        if(m_entries[i].symbol == symbol)
            return i;
    }

    if(m_entryCount >= MAX_EXPOSURE_ENTRIES)
        return -1;

    int index = m_entryCount;
    m_entryCount++;
    m_entries[index].symbol        = symbol;
    m_entries[index].longVolume    = 0.0;
    m_entries[index].shortVolume   = 0.0;
    m_entries[index].longExposure  = 0.0;
    m_entries[index].shortExposure = 0.0;
    m_entries[index].marginUsed    = 0.0;

    return index;
}

void CExposureTracker::AddPosition(const SymbolExposureEntry &entry)
{
    m_netLongExposure  += entry.longExposure;
    m_netShortExposure += entry.shortExposure;
    m_marginUsed       += entry.marginUsed;

    double positionExposure = entry.longExposure + entry.shortExposure;
    m_totalPortfolioExposure += positionExposure;

    int idx = FindOrAddSymbol(entry.symbol);
    if(idx >= 0)
    {
        m_entries[idx].longVolume    += entry.longVolume;
        m_entries[idx].shortVolume   += entry.shortVolume;
        m_entries[idx].longExposure  += entry.longExposure;
        m_entries[idx].shortExposure += entry.shortExposure;
        m_entries[idx].marginUsed    += entry.marginUsed;
    }
}

#endif
