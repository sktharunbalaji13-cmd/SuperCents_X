//+------------------------------------------------------------------+
//|                                             CHOCHDetector.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __CHOCH_DETECTOR_MQH__
#define __CHOCH_DETECTOR_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Core/Logger.mqh"
#include "TrendState.mqh"
#include "ProtectedPointManager.mqh"

//--- Sprint 7: CHOCH Detector
//--- Detects Change of Character when protected levels are broken

struct CHOCHRejectStats
{
    int trendUnknown;       // trend == TREND_UNKNOWN
    int noActivePP;         // GetActiveLow/GetActiveHigh returned false
    int guardTime;          // currentBarTime <= activationTime
    int priceNotBroken;     // close hasn't crossed PP
    int duplicate;          // already emitted for this PP ID
    int success;            // CHOCH created
    
    void Reset(void) { trendUnknown=0; noActivePP=0; guardTime=0; priceNotBroken=0; duplicate=0; success=0; }
};

class CCHOCHDetector
{
private:
    CLogger m_logger;
    bool m_isInitialized;
    
    CHOCHEvent m_chochEvents[];
    int m_chochCount;
    int m_nextId;
    int m_lastProcessedBar;
    CHOCHRejectStats m_stats;

public:
    CCHOCHDetector(void);
    ~CCHOCHDetector(void);

    bool Init(void);
    void Update(CTrendState *trendState, CProtectedPointManager *protectedMgr, 
                const double &close[], const datetime &time[], int rates_total);
    void Shutdown(void);
    
    bool IsInitialized(void) const { return m_isInitialized; }
    int GetCHOCHCount(void) const { return m_chochCount; }
    bool GetCHOCH(int index, CHOCHEvent &out) const;

private:
    void CheckProtectedLevel(const ProtectedPoint &point, Trend currentTrend, 
                            double close, datetime time, int barIndex);
};

//--- Inline implementation
CCHOCHDetector::CCHOCHDetector(void)
    : m_logger(MODULE_CHOCH_DETECTOR, "CHOCHDetector")
    , m_isInitialized(false)
    , m_chochCount(0)
    , m_nextId(1)
    , m_lastProcessedBar(-1)
{
    ArrayResize(m_chochEvents, 256);
    m_stats.Reset();
}

CCHOCHDetector::~CCHOCHDetector(void)
{
    Shutdown();
}

bool CCHOCHDetector::Init(void)
{
    if(m_isInitialized)
    {
        m_logger.LogWarn("CHOCHDetector already initialized");
    }

    m_logger.LogInfo("Initializing CHOCHDetector...");
    m_isInitialized = true;
    m_logger.LogInfo("CHOCHDetector initialized");
    return true;
}

void CCHOCHDetector::Update(CTrendState *trendState, CProtectedPointManager *protectedMgr, 
                            const double &close[], const datetime &time[], int rates_total)
{
    if(!m_isInitialized)
    {
        m_logger.LogWarn("Update called but CHOCHDetector is not initialized");
        return;
    }

    if(trendState == NULL || protectedMgr == NULL)
        return;

    Trend currentTrend = trendState.GetCurrentTrend();
    if(currentTrend == TREND_UNKNOWN)
    {
        m_stats.trendUnknown++;
        return;
    }

    // Only process closed candles (use bar index 1 - the last fully closed bar)
    if(rates_total < 2)
        return;

    if(rates_total <= m_lastProcessedBar)
        return;

    double currentClose = close[1];  // Last closed candle
    datetime currentBarTime = time[1];

    // Check active protected point based on trend
    ProtectedPoint activePoint;
    if(currentTrend == TREND_BULLISH)
    {
        // Check if protected low is broken
        if(!protectedMgr.GetActiveLow(activePoint))
        {
            m_stats.noActivePP++;
        }
        else
        {
            // Guard: Only check candles AFTER the protected point was activated (>= allows next bar)
            if(currentBarTime < activePoint.activationTime)
            {
                m_stats.guardTime++;
            }
            else if(currentClose >= activePoint.price)
            {
                m_stats.priceNotBroken++;
            }
            else
            {
                m_logger.LogDebug(StringFormat("CHOCH Low OK activation=%s current=%s close=%.5f ppPrice=%.5f",
                    TimeToString(activePoint.activationTime, TIME_DATE | TIME_MINUTES),
                    TimeToString(currentBarTime, TIME_DATE | TIME_MINUTES),
                    currentClose, activePoint.price));
                CheckProtectedLevel(activePoint, currentTrend, currentClose, currentBarTime, 1);
            }
        }
    }
    else if(currentTrend == TREND_BEARISH)
    {
        // Check if protected high is broken
        if(!protectedMgr.GetActiveHigh(activePoint))
        {
            m_stats.noActivePP++;
        }
        else
        {
            // Guard: Only check candles AFTER the protected point was activated (>= allows next bar)
            if(currentBarTime < activePoint.activationTime)
            {
                m_stats.guardTime++;
            }
            else if(currentClose <= activePoint.price)
            {
                m_stats.priceNotBroken++;
            }
            else
            {
                m_logger.LogDebug(StringFormat("CHOCH High OK activation=%s current=%s close=%.5f ppPrice=%.5f",
                    TimeToString(activePoint.activationTime, TIME_DATE | TIME_MINUTES),
                    TimeToString(currentBarTime, TIME_DATE | TIME_MINUTES),
                    currentClose, activePoint.price));
                CheckProtectedLevel(activePoint, currentTrend, currentClose, currentBarTime, 1);
            }
        }
    }

    m_lastProcessedBar = rates_total;
}

void CCHOCHDetector::CheckProtectedLevel(const ProtectedPoint &point, Trend currentTrend, 
                                        double close, datetime time, int barIndex)
{
    // Check if we already recorded a CHOCH for this protected point
    for(int i = 0; i < m_chochCount; i++)
    {
        if(m_chochEvents[i].protectedPointID == point.id)
        {
            m_stats.duplicate++;
            return;  // Already recorded
        }
    }

    // Add new CHOCH event
    if(m_chochCount >= ArraySize(m_chochEvents))
    {
        int newSize = ArraySize(m_chochEvents) + 256;
        ArrayResize(m_chochEvents, newSize);
    }

    bool bullishCHOCH = (currentTrend == TREND_BEARISH);
    
    m_chochEvents[m_chochCount].id = m_nextId++;
    m_chochEvents[m_chochCount].protectedPointID = point.id;
    m_chochEvents[m_chochCount].bullish = bullishCHOCH;
    m_chochEvents[m_chochCount].time = time;
    m_chochEvents[m_chochCount].breakPrice = close;
    m_chochEvents[m_chochCount].barIndex = barIndex;
    m_chochCount++;
    m_stats.success++;

    m_logger.LogInfo(StringFormat("CHOCH Confirmed\nID: %d\nDirection: %s\nProtected Point: %d\nBar: %d\nTime: %s\nProtected Price: %.5f\nClose Price: %.5f",
        m_chochEvents[m_chochCount-1].id,
        bullishCHOCH ? "Bullish" : "Bearish",
        point.id,
        barIndex,
        TimeToString(time, TIME_DATE | TIME_MINUTES),
        point.price,
        close));
}

void CCHOCHDetector::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down CHOCHDetector...");
    
    m_logger.LogInfo("==============================");
    m_logger.LogInfo("CHOCH FORENSIC SUMMARY");
    m_logger.LogInfo("==============================");
    m_logger.LogInfo(StringFormat("Trend Unknown Rejects : %d", m_stats.trendUnknown));
    m_logger.LogInfo(StringFormat("No Active PP Rejects  : %d", m_stats.noActivePP));
    m_logger.LogInfo(StringFormat("Guard Time Rejects    : %d", m_stats.guardTime));
    m_logger.LogInfo(StringFormat("Price Rejects         : %d", m_stats.priceNotBroken));
    m_logger.LogInfo(StringFormat("Duplicate Rejects     : %d", m_stats.duplicate));
    m_logger.LogInfo("------------------------------");
    m_logger.LogInfo(StringFormat("CHOCH Created         : %d", m_stats.success));
    m_logger.LogInfo("==============================");
    m_logger.LogInfo(StringFormat("CHOCH Events Total    : %d", m_chochCount));
    
    m_chochCount = 0;
    m_isInitialized = false;
    m_logger.LogInfo("CHOCHDetector shutdown complete");
}

bool CCHOCHDetector::GetCHOCH(int index, CHOCHEvent &out) const
{
    if(index < 0 || index >= m_chochCount)
        return false;
        
    out = m_chochEvents[index];
    return true;
}

#endif // __CHOCH_DETECTOR_MQH__