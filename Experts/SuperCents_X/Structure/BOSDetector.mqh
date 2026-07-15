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
        return;

    // Find the latest LOCKED pivot for each type (isProtected == true)
    int latestLockedHighId = -1;
    int latestLockedLowId = -1;
    double latestLockedHighPrice = 0.0;
    double latestLockedLowPrice = 0.0;

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
        }
        else if(!pivot.isHigh && pivot.isProtected)
        {
            m_lockedLowCount++;
            latestLockedLowId = pivot.id;
            latestLockedLowPrice = pivot.price;
        }
    }

    // Check each closed bar (skip bar 0 - Rule 1)
    for(int bar = 1; bar < rates_total && bar < ArraySize(close); bar++)
    {
        double barClose = close[bar];

        // Bullish BOS: Close > latest locked Structural HIGH
        if(latestLockedHighId >= 0 && !IsPivotBroken(latestLockedHighId))
        {
            if(barClose > latestLockedHighPrice)
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
                m_brokenPivotIds[idx] = latestLockedHighId;
                m_bosBullish[idx] = true;
                m_bosTimes[idx] = time[bar];
                m_bosBars[idx] = bar;
                m_bosPivotPrices[idx] = latestLockedHighPrice;
                m_bosClosePrices[idx] = barClose;
                m_bosCount++;

                m_bullishBOSCount++;
                m_brokenHighCount++;

                string msg = StringFormat("BOS Confirmed\nID: %d\nDirection: Bullish\nBroken Pivot: %d\nBar: %d\nTime: %s\nPivot Price: %.5f\nClose Price: %.5f",
                    m_bosIds[idx], m_brokenPivotIds[idx], m_bosBars[idx], 
                    TimeToString(m_bosTimes[idx], TIME_DATE | TIME_MINUTES),
                    m_bosPivotPrices[idx], m_bosClosePrices[idx]);
                m_logger.LogInfo(msg);
            }
        }
        else if(latestLockedHighId >= 0 && IsPivotBroken(latestLockedHighId))
        {
            m_duplicatePrevented++;
        }

        // Bearish BOS: Close < latest locked Structural LOW
        if(latestLockedLowId >= 0 && !IsPivotBroken(latestLockedLowId))
        {
            if(barClose < latestLockedLowPrice)
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
                m_brokenPivotIds[idx] = latestLockedLowId;
                m_bosBullish[idx] = false;
                m_bosTimes[idx] = time[bar];
                m_bosBars[idx] = bar;
                m_bosPivotPrices[idx] = latestLockedLowPrice;
                m_bosClosePrices[idx] = barClose;
                m_bosCount++;

                m_bearishBOSCount++;
                m_brokenLowCount++;

                string msg = StringFormat("BOS Confirmed\nID: %d\nDirection: Bearish\nBroken Pivot: %d\nBar: %d\nTime: %s\nPivot Price: %.5f\nClose Price: %.5f",
                    m_bosIds[idx], m_brokenPivotIds[idx], m_bosBars[idx], 
                    TimeToString(m_bosTimes[idx], TIME_DATE | TIME_MINUTES),
                    m_bosPivotPrices[idx], m_bosClosePrices[idx]);
                m_logger.LogInfo(msg);
            }
        }
        else if(latestLockedLowId >= 0 && IsPivotBroken(latestLockedLowId))
        {
            m_duplicatePrevented++;
        }
    }
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