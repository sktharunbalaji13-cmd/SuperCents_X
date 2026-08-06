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
#include "PPTelemetry.mqh"

//--- Sprint 7: CHOCH Detector
//--- Detects Change of Character when protected levels are broken

struct CHOCHRejectStats
{
    int trendUnknown;
    int bullishNoActivePP;
    int bearishNoActivePP;
    int bullishGuardTime;
    int bearishGuardTime;
    int bullishPriceNotBroken;
    int bearishPriceNotBroken;
    int bullishDuplicate;
    int bearishDuplicate;
    int bullishSuccess;
    int bearishSuccess;
    
    void Reset(void)
    {
        trendUnknown=0;
        bullishNoActivePP=0; bearishNoActivePP=0;
        bullishGuardTime=0; bearishGuardTime=0;
        bullishPriceNotBroken=0; bearishPriceNotBroken=0;
        bullishDuplicate=0; bearishDuplicate=0;
        bullishSuccess=0; bearishSuccess=0;
    }
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

    CPPTelemetryCollector m_telemetry;
    int m_lastActiveHighId;
    int m_lastActiveLowId;
    int m_highActivationRatesTotal;
    int m_lowActivationRatesTotal;

public:
    CCHOCHDetector(void);
    ~CCHOCHDetector(void);

    bool Init(void);
    void Update(CTrendState *trendState, CProtectedPointManager *protectedMgr, 
                const double &close[], const datetime &time[], int rates_total,
                double pointSize);
    void Shutdown(void);
    
    bool IsInitialized(void) const { return m_isInitialized; }
    int GetCHOCHCount(void) const { return m_chochCount; }
    bool GetCHOCH(int index, CHOCHEvent &out) const;

private:
    bool CheckProtectedLevel(const ProtectedPoint &point, Trend currentTrend, 
                            double close, datetime time, int barIndex);
    void LogPPSample(bool isBullishCheck, bool accepted, const string &reason,
                     const ProtectedPoint &pp, double close, int ratesTotal, double pointSize,
                     datetime barTime);
};

//--- Inline implementation
CCHOCHDetector::CCHOCHDetector(void)
    : m_logger(MODULE_CHOCH_DETECTOR, "CHOCHDetector")
    , m_isInitialized(false)
    , m_chochCount(0)
    , m_nextId(1)
    , m_lastProcessedBar(-1)
    , m_lastActiveHighId(-1)
    , m_lastActiveLowId(-1)
    , m_highActivationRatesTotal(0)
    , m_lowActivationRatesTotal(0)
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
                            const double &close[], const datetime &time[], int rates_total,
                            double pointSize)
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
        if(!protectedMgr.GetActiveLow(activePoint))
        {
            m_stats.bearishNoActivePP++;
            m_logger.LogInfo("--- PP Sample ---\nDirection: BEARISH  Check Type: REJECTED  Reason: no_active_pp");
        }
        else
        {
            // Track PP activation for age computation
            bool firstExam = false;
            if(activePoint.id != m_lastActiveLowId)
            {
                m_lastActiveLowId = activePoint.id;
                m_lowActivationRatesTotal = rates_total;
                firstExam = true;
            }

            if(currentBarTime < activePoint.activationTime)
            {
                m_stats.bearishGuardTime++;
                LogPPSample(false, false, "guard_time", activePoint, currentClose, rates_total, pointSize, currentBarTime);
            }
            else if(firstExam)
            {
                //--- DD02 (AVP CHOCH C6 / CH-F7): on cold start / backfill the
                //    PP activates at the current bar while the level was
                //    actually crossed earlier.  Scan the closed bars back from
                //    the oldest bar at/after activation and attribute the event
                //    to the TRUE first crossing bar.  Under normal cadence the
                //    activation is the current bar, so the window degrades to
                //    bar 1 and behaviour is unchanged.
                int crossBar = -1;
                double crossClose = 0.0;
                datetime crossTime = 0;
                int maxBar = rates_total - 1;
                if(maxBar >= ArraySize(close))
                    maxBar = ArraySize(close) - 1;
                for(int bar = maxBar; bar >= 1; bar--)
                {
                    if(time[bar] < activePoint.activationTime)
                        continue;
                    if(close[bar] < activePoint.price)
                    {
                        crossBar = bar;
                        crossClose = close[bar];
                        crossTime = time[bar];
                        break;
                    }
                }
                if(crossBar >= 0)
                {
                    if(CheckProtectedLevel(activePoint, currentTrend, crossClose, crossTime, crossBar))
                        LogPPSample(false, true, "accepted", activePoint, crossClose, rates_total, pointSize, crossTime);
                }
                else
                {
                    m_stats.bearishPriceNotBroken++;
                    LogPPSample(false, false, "price_not_broken", activePoint, currentClose, rates_total, pointSize, currentBarTime);
                }
            }
            else if(currentClose >= activePoint.price)
            {
                m_stats.bearishPriceNotBroken++;
                LogPPSample(false, false, "price_not_broken", activePoint, currentClose, rates_total, pointSize, currentBarTime);
            }
            else
            {
                if(CheckProtectedLevel(activePoint, currentTrend, currentClose, currentBarTime, 1))
                    LogPPSample(false, true, "accepted", activePoint, currentClose, rates_total, pointSize, currentBarTime);
            }
        }
    }
    else if(currentTrend == TREND_BEARISH)
    {
        if(!protectedMgr.GetActiveHigh(activePoint))
        {
            m_stats.bullishNoActivePP++;
            m_logger.LogInfo("--- PP Sample ---\nDirection: BULLISH  Check Type: REJECTED  Reason: no_active_pp");
        }
        else
        {
            // Track PP activation for age computation
            bool firstExam = false;
            if(activePoint.id != m_lastActiveHighId)
            {
                m_lastActiveHighId = activePoint.id;
                m_highActivationRatesTotal = rates_total;
                firstExam = true;
            }

            if(currentBarTime < activePoint.activationTime)
            {
                m_stats.bullishGuardTime++;
                LogPPSample(true, false, "guard_time", activePoint, currentClose, rates_total, pointSize, currentBarTime);
            }
            else if(firstExam)
            {
                //--- DD02: cold-start first-crossing scan (see bullish branch)
                int crossBar = -1;
                double crossClose = 0.0;
                datetime crossTime = 0;
                int maxBar = rates_total - 1;
                if(maxBar >= ArraySize(close))
                    maxBar = ArraySize(close) - 1;
                for(int bar = maxBar; bar >= 1; bar--)
                {
                    if(time[bar] < activePoint.activationTime)
                        continue;
                    if(close[bar] > activePoint.price)
                    {
                        crossBar = bar;
                        crossClose = close[bar];
                        crossTime = time[bar];
                        break;
                    }
                }
                if(crossBar >= 0)
                {
                    if(CheckProtectedLevel(activePoint, currentTrend, crossClose, crossTime, crossBar))
                        LogPPSample(true, true, "accepted", activePoint, crossClose, rates_total, pointSize, crossTime);
                }
                else
                {
                    m_stats.bullishPriceNotBroken++;
                    LogPPSample(true, false, "price_not_broken", activePoint, currentClose, rates_total, pointSize, currentBarTime);
                }
            }
            else if(currentClose <= activePoint.price)
            {
                m_stats.bullishPriceNotBroken++;
                LogPPSample(true, false, "price_not_broken", activePoint, currentClose, rates_total, pointSize, currentBarTime);
            }
            else
            {
                if(CheckProtectedLevel(activePoint, currentTrend, currentClose, currentBarTime, 1))
                    LogPPSample(true, true, "accepted", activePoint, currentClose, rates_total, pointSize, currentBarTime);
            }
        }
    }

    m_lastProcessedBar = rates_total;
}

void CCHOCHDetector::LogPPSample(bool isBullishCheck, bool accepted, const string &reason,
                                 const ProtectedPoint &pp, double close, int ratesTotal, double pointSize,
                                 datetime barTime)
{
    double distPoints = MathAbs(close - pp.price) / pointSize;
    int activationRatesTotal = isBullishCheck ? m_highActivationRatesTotal : m_lowActivationRatesTotal;
    int ageBars = (activationRatesTotal > 0) ? MathMax(0, ratesTotal - activationRatesTotal) : 0;

    m_logger.LogInfo(
        "--- PP Sample ---\n"
        "Time               : " + TimeToString(barTime, TIME_DATE | TIME_MINUTES) + "\n"
        "Bar Index          : " + IntegerToString(ratesTotal) + "\n"
        "Trend              : " + (isBullishCheck ? "BEARISH" : "BULLISH") + "\n"
        "Close              : " + DoubleToString(close, 5) + "\n"
        "Active PP          : " + (pp.isHigh ? "HIGH" : "LOW") + "\n"
        "PP ID              : " + IntegerToString(pp.id) + "\n"
        "PP Pivot ID        : " + IntegerToString(pp.pivotID) + "\n"
        "PP Price           : " + DoubleToString(pp.price, 5) + "\n"
        "Distance           : " + DoubleToString(distPoints, 1) + " points\n"
        "PP Age             : " + IntegerToString(ageBars) + " bars\n"
        "PP Formed          : " + TimeToString(pp.time, TIME_DATE | TIME_MINUTES) + "\n"
        "PP Activated       : " + TimeToString(pp.activationTime, TIME_DATE | TIME_MINUTES) + "\n"
        "Result             : " + (accepted ? "ACCEPTED" : "REJECTED") + "\n"
        "Reason             : " + reason
    );

    PPTelemetryRecord rec;
    rec.time = barTime;
    rec.ratesTotal = ratesTotal;
    rec.isBullishCheck = isBullishCheck;
    rec.accepted = accepted;
    rec.close = close;
    rec.ppPrice = pp.price;
    rec.ppID = pp.id;
    rec.ppPivotID = pp.pivotID;
    rec.ppTime = pp.time;
    rec.ppActivationTime = pp.activationTime;
    rec.ppActivationRatesTotal = activationRatesTotal;
    rec.distancePoints = distPoints;
    rec.ageBars = ageBars;
    rec.rejectReason = reason;
    m_telemetry.Record(rec);
}

bool CCHOCHDetector::CheckProtectedLevel(const ProtectedPoint &point, Trend currentTrend, 
                                        double close, datetime time, int barIndex)
{
    bool bullishCHOCH = (currentTrend == TREND_BEARISH);

    // Check if we already recorded a CHOCH for this protected point
    for(int i = 0; i < m_chochCount; i++)
    {
        if(m_chochEvents[i].protectedPointID == point.id)
        {
            if(bullishCHOCH)
                m_stats.bullishDuplicate++;
            else
                m_stats.bearishDuplicate++;
            m_logger.LogInfo(StringFormat("CHOCH Candidate REJECTED (%s): duplicate — PP #%d already used",
                bullishCHOCH ? "BULLISH" : "BEARISH", point.id));
            return false;
        }
    }

    // Add new CHOCH event
    if(m_chochCount >= ArraySize(m_chochEvents))
    {
        int newSize = ArraySize(m_chochEvents) + 256;
        ArrayResize(m_chochEvents, newSize);
    }
    
    if(bullishCHOCH)
        m_stats.bullishSuccess++;
    else
        m_stats.bearishSuccess++;

    m_chochEvents[m_chochCount].id = m_nextId++;
    m_chochEvents[m_chochCount].protectedPointID = point.id;
    m_chochEvents[m_chochCount].bullish = bullishCHOCH;
    m_chochEvents[m_chochCount].time = time;
    m_chochEvents[m_chochCount].breakPrice = close;
    m_chochEvents[m_chochCount].barIndex = barIndex;
    m_chochCount++;

    m_logger.LogInfo(StringFormat("CHOCH Confirmed\nID: %d\nDirection: %s\nProtected Point: %d\nBar: %d\nTime: %s\nProtected Price: %.5f\nClose Price: %.5f",
        m_chochEvents[m_chochCount-1].id,
        bullishCHOCH ? "Bullish" : "Bearish",
        point.id,
        barIndex,
        TimeToString(time, TIME_DATE | TIME_MINUTES),
        point.price,
        close));

    return true;
}

void CCHOCHDetector::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down CHOCHDetector...");
    
    m_logger.LogInfo("===================================");
    m_logger.LogInfo("CHOCH DIRECTIONAL SUMMARY");
    m_logger.LogInfo("===================================");
    m_logger.LogInfo(StringFormat("Trend Unknown Rejects     : %d", m_stats.trendUnknown));
    m_logger.LogInfo("-----------------------------------");
    m_logger.LogInfo("BULLISH (trend was BEARISH):");
    m_logger.LogInfo(StringFormat("  No Active High PP      : %d", m_stats.bullishNoActivePP));
    m_logger.LogInfo(StringFormat("  Guard Time Rejects     : %d", m_stats.bullishGuardTime));
    m_logger.LogInfo(StringFormat("  Price Not Broken       : %d", m_stats.bullishPriceNotBroken));
    m_logger.LogInfo(StringFormat("  Duplicate Rejects      : %d", m_stats.bullishDuplicate));
    m_logger.LogInfo(StringFormat("  ACCEPTED               : %d", m_stats.bullishSuccess));
    m_logger.LogInfo("-----------------------------------");
    m_logger.LogInfo("BEARISH (trend was BULLISH):");
    m_logger.LogInfo(StringFormat("  No Active Low PP       : %d", m_stats.bearishNoActivePP));
    m_logger.LogInfo(StringFormat("  Guard Time Rejects     : %d", m_stats.bearishGuardTime));
    m_logger.LogInfo(StringFormat("  Price Not Broken       : %d", m_stats.bearishPriceNotBroken));
    m_logger.LogInfo(StringFormat("  Duplicate Rejects      : %d", m_stats.bearishDuplicate));
    m_logger.LogInfo(StringFormat("  ACCEPTED               : %d", m_stats.bearishSuccess));
    m_logger.LogInfo("===================================");
    m_logger.LogInfo(StringFormat("CHOCH Events Total    : %d", m_chochCount));
    m_logger.LogInfo("===================================");
    
    m_telemetry.Shutdown();
    
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