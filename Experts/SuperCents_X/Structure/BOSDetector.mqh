//+------------------------------------------------------------------+
//|                                                BOSDetector.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __BOS_DETECTOR_MQH__
#define __BOS_DETECTOR_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Core/Logger.mqh"
#include "StructuralPivotEngine.mqh"

//--- Sprint 4: Break of Structure Detector
//--- Consumes only StructuralPivotEngine API
//--- Never repaints. Never emits duplicates. Only breaks locked pivots.
class CBOSDetector
{
private:
    //--- Logger
    CLogger m_logger;
    
    //--- State
    bool m_isInitialized;
    
    //--- BOS event storage (using parallel arrays for MQL5 compatibility)
    int m_bosIds[];
    int m_brokenPivotIds[];
    bool m_bosBullish[];
    datetime m_bosTimes[];
    int m_bosBars[];
    double m_bosPivotPrices[];
    double m_bosClosePrices[];
    int m_bosCount;
    
    //--- Debug counters
    int m_lockedHighCount;
    int m_lockedLowCount;
    int m_bullishBOSCount;
    int m_bearishBOSCount;
    int m_brokenHighCount;
    int m_brokenLowCount;
    int m_duplicatePrevented;
    int m_skippedUnlocked;
    
    //--- Locked pivot change tracking (for one-time logging)
    int m_lastLoggedLockedHighId;
    int m_lastLoggedLockedLowId;
    
    //--- Next BOS ID
    int m_nextBOSId;

public:
    CBOSDetector(void);
    ~CBOSDetector(void);

    //--- Lifecycle
    bool Init(void);
    void Update(CStructuralPivotEngine *pivotEngine, const double &close[], const datetime &time[], int rates_total);
    void Shutdown(void);
    void Clear(void);

    //--- Queries
    bool IsInitialized(void) const { return m_isInitialized; }
    int GetBOSCount(void) const { return m_bosCount; }
    bool GetBOS(int index, BOSEvent &out) const;

private:
    //--- Internal helpers
    void CheckBOS(const double &close[], const datetime &time[], int rates_total, CStructuralPivotEngine *pivotEngine);
    bool IsPivotBroken(int pivotId) const;
    void EmitBOS(bool bullish, int pivotId, double pivotPrice, int bar, double barClose, datetime barTime);
};

//--- Inline implementation
CBOSDetector::CBOSDetector(void)
    : m_logger(MODULE_TREND_STATE, "BOS")
    , m_isInitialized(false)
    , m_bosCount(0)
    , m_lockedHighCount(0)
    , m_lockedLowCount(0)
    , m_bullishBOSCount(0)
    , m_bearishBOSCount(0)
    , m_brokenHighCount(0)
    , m_brokenLowCount(0)
    , m_duplicatePrevented(0)
    , m_skippedUnlocked(0)
    , m_lastLoggedLockedHighId(-1)
    , m_lastLoggedLockedLowId(-1)
    , m_nextBOSId(1)
{
    ArrayResize(m_bosIds, 256);
    ArrayResize(m_brokenPivotIds, 256);
    ArrayResize(m_bosBullish, 256);
    ArrayResize(m_bosTimes, 256);
    ArrayResize(m_bosBars, 256);
    ArrayResize(m_bosPivotPrices, 256);
    ArrayResize(m_bosClosePrices, 256);
}

CBOSDetector::~CBOSDetector(void)
{
    Shutdown();
}

bool CBOSDetector::Init(void)
{
    if(m_isInitialized)
    {
        m_logger.LogWarn("BOSDetector already initialized, clearing state");
        Clear();
    }

    m_logger.LogInfo("Initializing BOSDetector...");

    m_isInitialized = true;
    m_logger.LogInfo("BOSDetector initialized");
    return true;
}

void CBOSDetector::Update(CStructuralPivotEngine *pivotEngine, const double &close[], const datetime &time[], int rates_total)
{
    if(!m_isInitialized)
    {
        m_logger.LogWarn("Update called but BOSDetector is not initialized");
        return;
    }

    if(pivotEngine == NULL || rates_total < 2)
        return;

    CheckBOS(close, time, rates_total, pivotEngine);
}

void CBOSDetector::CheckBOS(const double &close[], const datetime &time[], int rates_total, CStructuralPivotEngine *pivotEngine)
{
    int pivotCount = pivotEngine.GetPivotCount();
    if(pivotCount == 0)
    {
        m_logger.LogDebug("CheckBOS: pivotCount=0, no pivots to evaluate");
        return;
    }

    // Find the latest LOCKED pivot for each type (isProtected == true)
    int latestLockedHighId = -1;
    int latestLockedLowId = -1;
    double latestLockedHighPrice = 0.0;
    double latestLockedLowPrice = 0.0;
    int latestLockedHighBar = 0;
    int latestLockedLowBar = 0;
    datetime latestLockedHighTime = 0;
    datetime latestLockedLowTime = 0;

    // Reset debug counters before counting
    m_lockedHighCount = 0;
    m_lockedLowCount = 0;

    // Count locked pivots and find latest
    for(int i = 0; i < pivotCount; i++)
    {
        StructuralPivot pivot;
        if(!pivotEngine.GetPivot(i, pivot))
            continue;

        // Only consider LOCKED (isProtected) pivots
        if(pivot.isHigh && pivot.isProtected)
        {
            m_lockedHighCount++;
            latestLockedHighId = pivot.id;
            latestLockedHighPrice = pivot.price;
            latestLockedHighBar = pivot.barIndex;
            latestLockedHighTime = pivot.time;
        }
        else if(!pivot.isHigh && pivot.isProtected)
        {
            m_lockedLowCount++;
            latestLockedLowId = pivot.id;
            latestLockedLowPrice = pivot.price;
            latestLockedLowBar = pivot.barIndex;
            latestLockedLowTime = pivot.time;
        }
        else
        {
            m_skippedUnlocked++;
        }
    }

    // Log one-time when a new pivot becomes locked
    if(latestLockedHighId >= 0 && latestLockedHighId != m_lastLoggedLockedHighId)
    {
        m_lastLoggedLockedHighId = latestLockedHighId;
        m_logger.LogInfo(StringFormat(
            "Locked HIGH pivot ID:%d Price:%.5f",
            latestLockedHighId, latestLockedHighPrice));
    }
    if(latestLockedLowId >= 0 && latestLockedLowId != m_lastLoggedLockedLowId)
    {
        m_lastLoggedLockedLowId = latestLockedLowId;
        m_logger.LogInfo(StringFormat(
            "Locked LOW pivot ID:%d Price:%.5f",
            latestLockedLowId, latestLockedLowPrice));
    }

    //--- DD02 (AVP BOS C2 / E8): attribute the break to the TRUE first
    //    crossing bar.  The eligible bars are the closed bars AFTER the
    //    pivot bar; the window is enforced by TIME (pivot.time), which is
    //    index-space agnostic — the pivot engine's barIndex is
    //    chronological while close[]/time[] here are series-flipped by
    //    CSymbolContext::Update.  Scanning the array oldest-first and
    //    emitting at the first qualifying close finds the true first
    //    crossing.  The previous newest-first scan misattributed the event
    //    to the newest qualifying bar (on cold start / backfill the
    //    earliest rows could even fire on a pre-pivot bar, since any close
    //    beyond the pivot price qualified).
    int crossHighBar = -1;
    double crossHighClose = 0.0;
    int crossLowBar = -1;
    double crossLowClose = 0.0;

    if(latestLockedHighId >= 0 && !IsPivotBroken(latestLockedHighId))
    {
        int maxBar = rates_total - 1;
        if(maxBar >= ArraySize(close))
            maxBar = ArraySize(close) - 1;
        for(int bar = maxBar; bar >= 1; bar--)
        {
            if(time[bar] < latestLockedHighTime)
                continue;
            if(close[bar] > latestLockedHighPrice)
            {
                crossHighBar = bar;
                crossHighClose = close[bar];
                break;
            }
        }
        if(crossHighBar < 0 && latestLockedHighPrice - close[1] < 50 * _Point)
        {
            m_logger.LogDebug(StringFormat(
                "BOS CHECK Bullish REJECTED Bar:%d Close:%.5f <= Pivot:%.5f (gap:%.1fpips)",
                1, close[1], latestLockedHighPrice,
                (latestLockedHighPrice - close[1]) / _Point));
        }
    }
    else if(latestLockedHighId >= 0 && IsPivotBroken(latestLockedHighId))
    {
        m_duplicatePrevented++;
    }

    if(latestLockedLowId >= 0 && !IsPivotBroken(latestLockedLowId))
    {
        int maxBar = rates_total - 1;
        if(maxBar >= ArraySize(close))
            maxBar = ArraySize(close) - 1;
        for(int bar = maxBar; bar >= 1; bar--)
        {
            if(time[bar] < latestLockedLowTime)
                continue;
            if(close[bar] < latestLockedLowPrice)
            {
                crossLowBar = bar;
                crossLowClose = close[bar];
                break;
            }
        }
        if(crossLowBar < 0 && close[1] - latestLockedLowPrice < 50 * _Point)
        {
            m_logger.LogDebug(StringFormat(
                "BOS CHECK Bearish REJECTED Bar:%d Close:%.5f >= Pivot:%.5f (gap:%.1fpips)",
                1, close[1], latestLockedLowPrice,
                (close[1] - latestLockedLowPrice) / _Point));
        }
    }
    else if(latestLockedLowId >= 0 && IsPivotBroken(latestLockedLowId))
    {
        m_duplicatePrevented++;
    }

    //--- Emit in chronological order (older crossing first) so BOS ids
    //    stay time-ordered and TrendState's final trend reflects the MOST
    //    recent break (the newest crossing is emitted last).
    if(crossHighBar >= 0 || crossLowBar >= 0)
    {
        bool highOlder = (crossHighBar >= 0 && (crossLowBar < 0 || crossHighBar > crossLowBar));
        if(highOlder)
        {
            EmitBOS(true, latestLockedHighId, latestLockedHighPrice, crossHighBar, crossHighClose, time[crossHighBar]);
            if(crossLowBar >= 0)
                EmitBOS(false, latestLockedLowId, latestLockedLowPrice, crossLowBar, crossLowClose, time[crossLowBar]);
        }
        else
        {
            if(crossLowBar >= 0)
                EmitBOS(false, latestLockedLowId, latestLockedLowPrice, crossLowBar, crossLowClose, time[crossLowBar]);
            if(crossHighBar >= 0)
                EmitBOS(true, latestLockedHighId, latestLockedHighPrice, crossHighBar, crossHighClose, time[crossHighBar]);
        }
    }
}

void CBOSDetector::EmitBOS(bool bullish, int pivotId, double pivotPrice, int bar, double barClose, datetime barTime)
{
    int idx = m_bosCount;
    if(idx >= ArraySize(m_bosIds))
    {
        int newSize = ArraySize(m_bosIds) + 256;
        ArrayResize(m_bosIds, newSize);
        ArrayResize(m_brokenPivotIds, newSize);
        ArrayResize(m_bosBullish, newSize);
        ArrayResize(m_bosTimes, newSize);
        ArrayResize(m_bosBars, newSize);
        ArrayResize(m_bosPivotPrices, newSize);
        ArrayResize(m_bosClosePrices, newSize);
    }

    m_bosIds[idx] = m_nextBOSId++;
    m_brokenPivotIds[idx] = pivotId;
    m_bosBullish[idx] = bullish;
    m_bosTimes[idx] = barTime;
    m_bosBars[idx] = bar;
    m_bosPivotPrices[idx] = pivotPrice;
    m_bosClosePrices[idx] = barClose;
    m_bosCount++;

    if(bullish)
    {
        m_bullishBOSCount++;
        m_brokenHighCount++;
    }
    else
    {
        m_bearishBOSCount++;
        m_brokenLowCount++;
    }

    m_logger.LogInfo(StringFormat(
        bullish ? "BOS CONFIRMED #%d Bullish Bar:%d Time:%s Close:%.5f > Pivot:%.5f"
                : "BOS CONFIRMED #%d Bearish Bar:%d Time:%s Close:%.5f < Pivot:%.5f",
        m_bosIds[idx], bar, TimeToString(barTime, TIME_DATE|TIME_MINUTES),
        barClose, pivotPrice));
}

void CBOSDetector::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down BOSDetector...");
    
    // Print summary
    m_logger.LogInfo("========== BOS SUMMARY ==========");
    m_logger.LogInfo(StringFormat("Locked High Pivots      : %d", m_lockedHighCount));
    m_logger.LogInfo(StringFormat("Locked Low Pivots         : %d", m_lockedLowCount));
    m_logger.LogInfo(StringFormat("Bullish BOS             : %d", m_bullishBOSCount));
    m_logger.LogInfo(StringFormat("Bearish BOS             : %d", m_bearishBOSCount));
    m_logger.LogInfo(StringFormat("Broken High Pivots        : %d", m_brokenHighCount));
    m_logger.LogInfo(StringFormat("Broken Low Pivots         : %d", m_brokenLowCount));
    m_logger.LogInfo(StringFormat("Duplicate BOS Prevented   : %d", m_duplicatePrevented));
    m_logger.LogInfo(StringFormat("Skipped Unlocked Pivots   : %d", m_skippedUnlocked));
    m_logger.LogInfo("===============================");
    
    Clear();
    m_isInitialized = false;
    m_logger.LogInfo("BOSDetector shutdown complete");
}

void CBOSDetector::Clear(void)
{
    m_bosCount = 0;
    m_nextBOSId = 1;
    m_lockedHighCount = 0;
    m_lockedLowCount = 0;
    m_bullishBOSCount = 0;
    m_bearishBOSCount = 0;
    m_brokenHighCount = 0;
    m_brokenLowCount = 0;
    m_duplicatePrevented = 0;
    m_skippedUnlocked = 0;
    m_lastLoggedLockedHighId = -1;
    m_lastLoggedLockedLowId = -1;
}

bool CBOSDetector::GetBOS(int index, BOSEvent &out) const
{
    if(index < 0 || index >= m_bosCount)
        return false;

    out.id = m_bosIds[index];
    out.brokenPivotID = m_brokenPivotIds[index];
    out.bullish = m_bosBullish[index];
    out.breakTime = m_bosTimes[index];
    out.breakBar = m_bosBars[index];
    out.pivotPrice = m_bosPivotPrices[index];
    out.closePrice = m_bosClosePrices[index];

    return true;
}

bool CBOSDetector::IsPivotBroken(int pivotId) const
{
    for(int i = 0; i < m_bosCount; i++)
        if(m_brokenPivotIds[i] == pivotId)
            return true;
    return false;
}

#endif // __BOS_DETECTOR_MQH__