//+------------------------------------------------------------------+
//|                                             PPTelemetry.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __PP_TELEMETRY_MQH__
#define __PP_TELEMETRY_MQH__

#include "../Utils/Constants.mqh"
#include "../Core/Logger.mqh"

struct PPTelemetryRecord
{
    datetime    time;
    int         ratesTotal;
    bool        isBullishCheck;
    bool        accepted;
    double      close;
    double      ppPrice;
    int         ppID;
    int         ppPivotID;
    datetime    ppTime;
    datetime    ppActivationTime;
    int         ppActivationRatesTotal;
    double      distancePoints;
    int         ageBars;
    string      rejectReason;
};

struct PPTelemetryAggregate
{
    int count;
    double sumDistance;
    double sumDistanceSq;
    long sumAge;
    int minAge;
    int maxAge;
    double minDistance;
    double maxDistance;

    void Init(void)
    {
        count=0; sumDistance=0; sumDistanceSq=0; sumAge=0;
        minAge=2147483647; maxAge=0;
        minDistance=1e10; maxDistance=0;
    }

    void Add(double dist, int age)
    {
        count++;
        sumDistance += dist;
        sumDistanceSq += dist * dist;
        sumAge += age;
        if(age < minAge) minAge = age;
        if(age > maxAge) maxAge = age;
        if(dist < minDistance) minDistance = dist;
        if(dist > maxDistance) maxDistance = dist;
    }

    double AvgDist(void) const { return count > 0 ? sumDistance / count : 0; }
    double AvgAge(void) const { return count > 0 ? (double)sumAge / count : 0; }
    double StdDev(void) const
    {
        if(count < 2) return 0;
        double mean = sumDistance / count;
        return MathSqrt((sumDistanceSq - 2 * mean * sumDistance + count * mean * mean) / (count - 1));
    }
};

class CPPTelemetryCollector
{
private:
    PPTelemetryRecord m_records[];
    int m_count;
    CLogger m_logger;

public:
    CPPTelemetryCollector(void);
    void Record(const PPTelemetryRecord &rec);
    void Shutdown(void);
};

CPPTelemetryCollector::CPPTelemetryCollector(void)
    : m_logger(MODULE_CHOCH_DETECTOR, "PPTelemetry")
    , m_count(0)
{
    ArrayResize(m_records, 1024);
}

void CPPTelemetryCollector::Record(const PPTelemetryRecord &rec)
{
    if(m_count >= ArraySize(m_records))
    {
        int newSize = ArraySize(m_records) + 1024;
        ArrayResize(m_records, newSize);
    }
    m_records[m_count] = rec;
    m_count++;
}

void CPPTelemetryCollector::Shutdown(void)
{
    m_logger.LogInfo("=============================================");
    m_logger.LogInfo("PP TELEMETRY DISTRIBUTION SUMMARY");
    m_logger.LogInfo("=============================================");

    PPTelemetryAggregate aggBullRejectPNB;   // bullish CHOCH rejected — price not broken
    PPTelemetryAggregate aggBullRejectGuard; // bullish CHOCH rejected — guard time
    PPTelemetryAggregate aggBullAccept;      // bullish CHOCH accepted
    PPTelemetryAggregate aggBearRejectPNB;   // bearish CHOCH rejected — price not broken
    PPTelemetryAggregate aggBearRejectGuard; // bearish CHOCH rejected — guard time
    PPTelemetryAggregate aggBearAccept;      // bearish CHOCH accepted

    aggBullRejectPNB.Init();
    aggBullRejectGuard.Init();
    aggBullAccept.Init();
    aggBearRejectPNB.Init();
    aggBearRejectGuard.Init();
    aggBearAccept.Init();

    for(int i = 0; i < m_count; i++)
    {
        PPTelemetryRecord r;
        r = m_records[i];
        if(r.isBullishCheck)
        {
            if(r.accepted)
                aggBullAccept.Add(r.distancePoints, r.ageBars);
            else if(r.rejectReason == "guard_time")
                aggBullRejectGuard.Add(r.distancePoints, r.ageBars);
            else
                aggBullRejectPNB.Add(r.distancePoints, r.ageBars);
        }
        else
        {
            if(r.accepted)
                aggBearAccept.Add(r.distancePoints, r.ageBars);
            else if(r.rejectReason == "guard_time")
                aggBearRejectGuard.Add(r.distancePoints, r.ageBars);
            else
                aggBearRejectPNB.Add(r.distancePoints, r.ageBars);
        }
    }

    m_logger.LogInfo("--- BULLISH CHOCH (active high PP — trend was BEARISH) ---");

    m_logger.LogInfo(StringFormat("Rejected — Price Not Broken : %d  avgDist=%.1f  stdDev=%.1f  avgAge=%.0f  minAge=%d  maxAge=%d  minDist=%.1f  maxDist=%.1f",
        aggBullRejectPNB.count, aggBullRejectPNB.AvgDist(), aggBullRejectPNB.StdDev(),
        aggBullRejectPNB.AvgAge(), aggBullRejectPNB.minAge, aggBullRejectPNB.maxAge,
        aggBullRejectPNB.minDistance, aggBullRejectPNB.maxDistance));

    m_logger.LogInfo(StringFormat("Rejected — Guard Time      : %d  avgDist=%.1f  avgAge=%.0f",
        aggBullRejectGuard.count, aggBullRejectGuard.AvgDist(), aggBullRejectGuard.AvgAge()));

    m_logger.LogInfo(StringFormat("Accepted                   : %d  avgDist=%.1f  avgAge=%.0f",
        aggBullAccept.count, aggBullAccept.AvgDist(), aggBullAccept.AvgAge()));

    m_logger.LogInfo("--- BEARISH CHOCH (active low PP — trend was BULLISH) ---");

    m_logger.LogInfo(StringFormat("Rejected — Price Not Broken : %d  avgDist=%.1f  avgAge=%.0f",
        aggBearRejectPNB.count, aggBearRejectPNB.AvgDist(), aggBearRejectPNB.AvgAge()));

    m_logger.LogInfo(StringFormat("Rejected — Guard Time      : %d  avgDist=%.1f  avgAge=%.0f",
        aggBearRejectGuard.count, aggBearRejectGuard.AvgDist(), aggBearRejectGuard.AvgAge()));

    m_logger.LogInfo(StringFormat("Accepted                   : %d  avgDist=%.1f  stdDev=%.1f  avgAge=%.0f  minAge=%d  maxAge=%d  minDist=%.1f  maxDist=%.1f",
        aggBearAccept.count, aggBearAccept.AvgDist(), aggBearAccept.StdDev(),
        aggBearAccept.AvgAge(), aggBearAccept.minAge, aggBearAccept.maxAge,
        aggBearAccept.minDistance, aggBearAccept.maxDistance));

    m_logger.LogInfo("=============================================");
}

#endif
