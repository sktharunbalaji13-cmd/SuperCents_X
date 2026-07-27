#ifndef __KNOWLEDGE_TREND_ANALYZER_MQH__
#define __KNOWLEDGE_TREND_ANALYZER_MQH__

#include "../Core/Logger.mqh"
#include "../Trading/TradingEvidence.mqh"
#include "../Research/ResearchEvidence.mqh"
#include "../Production/OperationalEvidence.mqh"
#include "KnowledgeEvidence.mqh"

#define MAX_TREND_POINTS 128
#define MAX_TREND_RECORDS 32
#define MIN_TREND_OBSERVATIONS 3

class CTrendAnalyzer
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    TrendRecord m_trends[MAX_TREND_RECORDS];
    int         m_trendCount;

    struct TrendPoint
    {
        double   value;
        datetime timestamp;
        string   versionTag;

        TrendPoint(void) : value(0.0), timestamp(0), versionTag("") {}
    };

    TrendPoint m_pendingPoints[MAX_TREND_POINTS];
    int        m_pendingCount;

    int FindTrend(const string metricName) const;
    ENUM_TREND_DIRECTION ComputeDirection(const TrendPoint &points[], int count) const;
    double ComputeSlope(const TrendPoint &points[], int count) const;
    double ComputeMean(const TrendPoint &points[], int count) const;
    double ComputeVolatility(const TrendPoint &points[], int count) const;

public:
    CTrendAnalyzer(void);
    ~CTrendAnalyzer(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool RecordObservation(const string metricName, double value,
                            const string versionTag);
    bool RecordObservation(const string metricName, double value,
                            const string versionTag, const KnowledgeEvidence &evidence);

    bool AnalyzeTrends(void);

    bool GetTrend(int index, TrendRecord &out) const;
    int  GetTrendCount(void) const { return m_trendCount; }
    bool GetTrendByName(const string metricName, TrendRecord &out) const;

    string ComposeTrendReport(void) const;
    string ComposeMetricTrend(const string metricName) const;

    void Clear(void);
};

CTrendAnalyzer::CTrendAnalyzer(void)
    : m_logger(MODULE_LABORATORY, "TrendAnalyzer")
    , m_isInitialized(false)
    , m_trendCount(0)
    , m_pendingCount(0)
{
}

CTrendAnalyzer::~CTrendAnalyzer(void)
{
    Shutdown();
}

bool CTrendAnalyzer::Init(void)
{
    m_logger.LogInfo("Initializing TrendAnalyzer...");
    m_trendCount = 0;
    m_pendingCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("TrendAnalyzer initialized");
    return true;
}

void CTrendAnalyzer::Shutdown(void)
{
    if(!m_isInitialized) return;
    Clear();
    m_isInitialized = false;
}

int CTrendAnalyzer::FindTrend(const string metricName) const
{
    for(int i = 0; i < m_trendCount; i++)
        if(m_trends[i].metricName == metricName)
            return i;
    return -1;
}

bool CTrendAnalyzer::RecordObservation(const string metricName, double value,
                                        const string versionTag)
{
    KnowledgeEvidence empty;
    return RecordObservation(metricName, value, versionTag, empty);
}

bool CTrendAnalyzer::RecordObservation(const string metricName, double value,
                                        const string versionTag,
                                        const KnowledgeEvidence &evidence)
{
    if(!m_isInitialized || m_pendingCount >= MAX_TREND_POINTS)
        return false;

    m_pendingPoints[m_pendingCount].value = value;
    m_pendingPoints[m_pendingCount].timestamp = TimeCurrent();
    m_pendingPoints[m_pendingCount].versionTag = versionTag;

    int trendIdx = FindTrend(metricName);
    if(trendIdx >= 0)
    {
        int ec = m_trends[trendIdx].evidenceCount;
        if(ec < 32)
        {
            m_trends[trendIdx].evidence[ec] = evidence;
            m_trends[trendIdx].evidenceCount++;
        }
    }

    m_pendingCount++;

    m_logger.LogInfo(StringFormat("Trend: recorded %s=%.4f @%s",
                                  metricName, value, versionTag));
    return true;
}

ENUM_TREND_DIRECTION CTrendAnalyzer::ComputeDirection(const TrendPoint &points[],
                                                       int count) const
{
    if(count < MIN_TREND_OBSERVATIONS)
        return TREND_INSUFFICIENT_DATA;

    double slope = ComputeSlope(points, count);
    double volatility = ComputeVolatility(points, count);

    if(volatility > MathAbs(slope) * 3.0)
        return TREND_VOLATILE;

    if(slope > 0.05)
        return TREND_IMPROVING;
    if(slope < -0.05)
        return TREND_DECLINING;

    return TREND_STABLE;
}

double CTrendAnalyzer::ComputeSlope(const TrendPoint &points[], int count) const
{
    if(count < 2) return 0.0;

    double sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0;

    for(int i = 0; i < count; i++)
    {
        double x = (double)i;
        double y = points[i].value;
        sumX += x;
        sumY += y;
        sumXY += x * y;
        sumX2 += x * x;
    }

    double n = (double)count;
    double slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);

    if(isnan(slope) || isinf(slope))
        return 0.0;

    return slope;
}

double CTrendAnalyzer::ComputeMean(const TrendPoint &points[], int count) const
{
    if(count <= 0) return 0.0;

    double sum = 0.0;
    for(int i = 0; i < count; i++)
        sum += points[i].value;

    return sum / (double)count;
}

double CTrendAnalyzer::ComputeVolatility(const TrendPoint &points[], int count) const
{
    if(count < 2) return 0.0;

    double mean = ComputeMean(points, count);
    double sumSq = 0.0;

    for(int i = 0; i < count; i++)
    {
        double diff = points[i].value - mean;
        sumSq += diff * diff;
    }

    double variance = sumSq / (double)(count - 1);
    double stdDev = MathSqrt(variance);

    if(isnan(stdDev) || isinf(stdDev))
        return 0.0;

    return stdDev;
}

bool CTrendAnalyzer::AnalyzeTrends(void)
{
    if(!m_isInitialized || m_pendingCount < MIN_TREND_OBSERVATIONS)
        return false;

    for(int i = 0; i < m_pendingCount; i++)
    {
        string mn = m_pendingPoints[i].metricName;
        int idx = FindTrend(mn);

        if(idx < 0)
        {
            if(m_trendCount >= MAX_TREND_RECORDS)
                continue;

            TrendRecord tr;
            tr.trendId = StringFormat("TREND_%s_%d", mn, m_trendCount);
            tr.metricName = mn;
            tr.observationCount = 1;
            tr.meanValue = m_pendingPoints[i].value;

            m_trends[m_trendCount] = tr;
            m_trendCount++;
        }
    }

    for(int t = 0; t < m_trendCount; t++)
    {
        TrendPoint points[128];
        int ptCount = 0;

        for(int i = 0; i < m_pendingCount && ptCount < 128; i++)
        {
            if(m_pendingPoints[i].metricName == m_trends[t].metricName)
            {
                points[ptCount] = m_pendingPoints[i];
                ptCount++;
            }
        }

        if(ptCount >= MIN_TREND_OBSERVATIONS)
        {
            m_trends[t].observationCount = ptCount;
            m_trends[t].direction = ComputeDirection(points, ptCount);
            m_trends[t].slope = ComputeSlope(points, ptCount);
            m_trends[t].meanValue = ComputeMean(points, ptCount);
            m_trends[t].volatility = ComputeVolatility(points, ptCount);
        }
    }

    m_logger.LogInfo(StringFormat("TrendAnalyzer: analyzed %d trends from %d observations",
                                  m_trendCount, m_pendingCount));

    m_pendingCount = 0;
    return true;
}

bool CTrendAnalyzer::GetTrend(int index, TrendRecord &out) const
{
    if(index < 0 || index >= m_trendCount) return false;
    out = m_trends[index];
    return true;
}

bool CTrendAnalyzer::GetTrendByName(const string metricName, TrendRecord &out) const
{
    int idx = FindTrend(metricName);
    if(idx < 0) return false;
    out = m_trends[idx];
    return true;
}

string CTrendAnalyzer::ComposeTrendReport(void) const
{
    string out = "";
    out += "========================================\n";
    out += "TREND ANALYSIS REPORT\n";
    out += StringFormat("  Trends: %d\n", m_trendCount);
    out += "========================================\n";

    for(int t = 0; t < m_trendCount; t++)
    {
        string dirStr = "";
        switch(m_trends[t].direction)
        {
            case TREND_IMPROVING: dirStr = "IMPROVING"; break;
            case TREND_STABLE: dirStr = "STABLE"; break;
            case TREND_DECLINING: dirStr = "DECLINING"; break;
            case TREND_VOLATILE: dirStr = "VOLATILE"; break;
            default: dirStr = "INSUFFICIENT DATA"; break;
        }

        out += StringFormat("  [%d] %s\n", t + 1, m_trends[t].metricName);
        out += StringFormat("       Direction : %s\n", dirStr);
        out += StringFormat("       Slope     : %.4f\n", m_trends[t].slope);
        out += StringFormat("       Mean      : %.4f\n", m_trends[t].meanValue);
        out += StringFormat("       Volatility: %.4f\n", m_trends[t].volatility);
        out += StringFormat("       Obs Count : %d\n", m_trends[t].observationCount);
        out += "\n";
    }

    out += "========================================\n";
    return out;
}

string CTrendAnalyzer::ComposeMetricTrend(const string metricName) const
{
    TrendRecord tr;
    if(!GetTrendByName(metricName, tr))
        return StringFormat("No trend data for '%s'", metricName);

    string dirStr = "";
    switch(tr.direction)
    {
        case TREND_IMPROVING: dirStr = "IMPROVING"; break;
        case TREND_STABLE: dirStr = "STABLE"; break;
        case TREND_DECLINING: dirStr = "DECLINING"; break;
        case TREND_VOLATILE: dirStr = "VOLATILE"; break;
        default: dirStr = "INSUFFICIENT DATA"; break;
    }

    string out = "";
    out += StringFormat("Trend: %s (%s)\n", metricName, dirStr);
    out += StringFormat("  Slope     : %.4f\n", tr.slope);
    out += StringFormat("  Mean      : %.4f\n", tr.meanValue);
    out += StringFormat("  Volatility: %.4f\n", tr.volatility);
    out += StringFormat("  Obs Count : %d\n", tr.observationCount);

    if(tr.evidenceCount > 0)
    {
        out += "  Evidence:\n";
        for(int i = 0; i < tr.evidenceCount; i++)
        {
            out += StringFormat("    [%d] %s: %s=%.4f (%s)\n",
                                i + 1,
                                tr.evidence[i].source,
                                tr.evidence[i].dimension,
                                tr.evidence[i].value,
                                tr.evidence[i].rationale);
        }
    }

    return out;
}

void CTrendAnalyzer::Clear(void)
{
    m_trendCount = 0;
    m_pendingCount = 0;
}

#endif
