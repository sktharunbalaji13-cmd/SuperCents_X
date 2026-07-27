#ifndef __OPTIMIZATION_STRATEGY_ANALYTICS_MQH__
#define __OPTIMIZATION_STRATEGY_ANALYTICS_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "../Monitoring/MonitoringTypes.mqh"
#include "../Portfolio/PortfolioRiskTypes.mqh"
#include "OptimizationTypes.mqh"
#include "ExperimentManifest.mqh"

#define MAX_RECORDED_TRADES 10000
#define MAX_RECORDED_SNAPSHOTS 100000
#define MAX_SYMBOL_CONTRIBUTORS 50

struct RecordedTrade
{
    double  profit;
    double  rr;
    double  holdingTimeSec;
    string  symbol;
    double  stopPips;
    double  targetPips;

    RecordedTrade(void)
        : profit(0.0), rr(0.0), holdingTimeSec(0.0), symbol(""), stopPips(0.0), targetPips(0.0)
    {}
};

struct SymbolContributor
{
    string  symbol;
    int     count;
    double  totalProfit;
    double  totalRR;

    SymbolContributor(void)
        : symbol(""), count(0), totalProfit(0.0), totalRR(0.0)
    {}
};

class CStrategyAnalytics
{
private:
    CLogger          m_logger;
    bool             m_isInitialized;

    RecordedTrade    m_trades[MAX_RECORDED_TRADES];
    int              m_tradeCount;

    PortfolioExposure m_snapshots[MAX_RECORDED_SNAPSHOTS];
    int               m_snapshotCount;

    double           m_peakEquity;

    SymbolContributor m_symbols[MAX_SYMBOL_CONTRIBUTORS];
    int               m_symbolCount;

    int FindSymbolIndex(const string symbol);
    double ComputeSharpe(const double returns[], int count) const;
    double ComputeSortino(const double returns[], int count) const;
    double ComputeMaxDrawdown(double &equityCurve[], int count, double &outMaxValue) const;

public:
    CStrategyAnalytics(void);
    ~CStrategyAnalytics(void);

    bool Init(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool RecordTrade(const EventData &event);
    bool RecordPortfolioSnapshot(const PortfolioExposure &snapshot);

    bool GenerateReport(const ExperimentManifest &manifest,
                        const string windowLabel,
                        StrategyReport &outReport);

    void Reset(void);
};

CStrategyAnalytics::CStrategyAnalytics(void)
    : m_logger(MODULE_UNKNOWN, "StrategyAnalytics")
    , m_isInitialized(false)
    , m_tradeCount(0)
    , m_snapshotCount(0)
    , m_peakEquity(0.0)
    , m_symbolCount(0)
{
}

CStrategyAnalytics::~CStrategyAnalytics(void)
{
    Shutdown();
}

bool CStrategyAnalytics::Init(void)
{
    m_logger.LogInfo("Initializing StrategyAnalytics...");
    m_tradeCount = 0;
    m_snapshotCount = 0;
    m_peakEquity = 0.0;
    m_symbolCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("StrategyAnalytics initialized");
    return true;
}

void CStrategyAnalytics::Shutdown(void)
{
    if(!m_isInitialized) return;
    m_tradeCount = 0;
    m_snapshotCount = 0;
    m_symbolCount = 0;
    m_isInitialized = false;
}

void CStrategyAnalytics::Reset(void)
{
    m_tradeCount = 0;
    m_snapshotCount = 0;
    m_peakEquity = 0.0;
    m_symbolCount = 0;
}

int CStrategyAnalytics::FindSymbolIndex(const string symbol)
{
    for(int i = 0; i < m_symbolCount; i++)
    {
        if(m_symbols[i].symbol == symbol)
            return i;
    }
    return -1;
}

bool CStrategyAnalytics::RecordTrade(const EventData &event)
{
    if(!m_isInitialized || m_tradeCount >= MAX_RECORDED_TRADES)
        return false;

    if(event.eventType != EVENT_POSITION_CLOSED)
        return false;

    RecordedTrade t;
    t.profit = event.profit;
    t.symbol = event.symbol;

    double slDist = MathAbs(event.entryPrice - event.stopLoss);
    double tpDist = MathAbs(event.takeProfit - event.entryPrice);
    if(slDist > 0.0)
        t.rr = tpDist / slDist;
    t.holdingTimeSec = (event.closedTime - event.openedTime);

    double point = SymbolInfoDouble(event.symbol, SYMBOL_POINT);
    if(point > 0.0)
    {
        t.stopPips = slDist / point / 10.0;
        t.targetPips = tpDist / point / 10.0;
    }

    m_trades[m_tradeCount] = t;
    m_tradeCount++;

    int si = FindSymbolIndex(event.symbol);
    if(si < 0 && m_symbolCount < MAX_SYMBOL_CONTRIBUTORS)
    {
        si = m_symbolCount;
        m_symbols[si].symbol = event.symbol;
        m_symbols[si].count = 0;
        m_symbols[si].totalProfit = 0.0;
        m_symbols[si].totalRR = 0.0;
        m_symbolCount++;
    }
    if(si >= 0)
    {
        m_symbols[si].count++;
        m_symbols[si].totalProfit += event.profit;
        m_symbols[si].totalRR += t.rr;
    }

    return true;
}

bool CStrategyAnalytics::RecordPortfolioSnapshot(const PortfolioExposure &snapshot)
{
    if(!m_isInitialized || m_snapshotCount >= MAX_RECORDED_SNAPSHOTS)
        return false;

    m_snapshots[m_snapshotCount] = snapshot;
    m_snapshotCount++;

    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(equity > m_peakEquity)
        m_peakEquity = equity;

    return true;
}

double CStrategyAnalytics::ComputeSharpe(const double returns[], int count) const
{
    if(count < 2)
        return 0.0;

    double sum = 0.0;
    for(int i = 0; i < count; i++)
        sum += returns[i];
    double mean = sum / count;

    double variance = 0.0;
    for(int i = 0; i < count; i++)
        variance += (returns[i] - mean) * (returns[i] - mean);
    variance /= (count - 1);

    if(variance <= 0.0)
        return (mean > 0.0) ? 999.0 : 0.0;

    double stddev = MathSqrt(variance);
    return (stddev > 0.0) ? (mean / stddev) : 0.0;
}

double CStrategyAnalytics::ComputeSortino(const double returns[], int count) const
{
    if(count < 2)
        return 0.0;

    double sum = 0.0;
    for(int i = 0; i < count; i++)
        sum += returns[i];
    double mean = sum / count;

    double downsideVariance = 0.0;
    int downsideCount = 0;
    for(int i = 0; i < count; i++)
    {
        if(returns[i] < 0.0)
        {
            downsideVariance += returns[i] * returns[i];
            downsideCount++;
        }
    }
    if(downsideCount > 0)
        downsideVariance /= downsideCount;

    double downsideStd = MathSqrt(downsideVariance);
    return (downsideStd > 0.0) ? (mean / downsideStd) : 0.0;
}

double CStrategyAnalytics::ComputeMaxDrawdown(double &equityCurve[], int count, double &outMaxValue) const
{
    if(count < 2)
    {
        outMaxValue = 0.0;
        return 0.0;
    }

    double peak = equityCurve[0];
    double maxDD = 0.0;
    double maxDDVal = 0.0;

    for(int i = 1; i < count; i++)
    {
        if(equityCurve[i] > peak)
            peak = equityCurve[i];
        double dd = (peak > 0.0) ? ((peak - equityCurve[i]) / peak) * 100.0 : 0.0;
        if(dd > maxDD)
        {
            maxDD = dd;
            maxDDVal = peak - equityCurve[i];
        }
    }

    outMaxValue = maxDDVal;
    return maxDD;
}

bool CStrategyAnalytics::GenerateReport(const ExperimentManifest &manifest,
                                         const string windowLabel,
                                         StrategyReport &outReport)
{
    if(!m_isInitialized)
        return false;

    outReport.experimentId = manifest.experimentId;
    outReport.parameterSetId = manifest.parameterSetId;
    outReport.platformVersion = manifest.platformVersion;
    outReport.windowLabel = windowLabel;

    outReport.totalTrades = m_tradeCount;

    for(int i = 0; i < m_tradeCount; i++)
    {
        if(m_trades[i].profit > 0.0)
        {
            outReport.winningTrades++;
            outReport.grossProfit += m_trades[i].profit;
        }
        else
        {
            outReport.losingTrades++;
            outReport.grossLoss += m_trades[i].profit;
        }
        outReport.totalNetProfit += m_trades[i].profit;
        outReport.avgRRAchieved += m_trades[i].rr;
        outReport.avgHoldingTimeSeconds += m_trades[i].holdingTimeSec;
        outReport.avgStopPips += m_trades[i].stopPips;
        outReport.avgTargetPips += m_trades[i].targetPips;
    }

    if(outReport.totalTrades > 0)
    {
        outReport.winRate = (double)outReport.winningTrades / outReport.totalTrades * 100.0;
        outReport.avgRRAchieved /= outReport.totalTrades;
        outReport.avgHoldingTimeSeconds /= outReport.totalTrades;
        outReport.avgStopPips /= outReport.totalTrades;
        outReport.avgTargetPips /= outReport.totalTrades;
    }

    outReport.expectancy = (outReport.totalTrades > 0)
        ? outReport.totalNetProfit / outReport.totalTrades
        : 0.0;

    outReport.profitFactor = (outReport.grossLoss < 0.0)
        ? outReport.grossProfit / MathAbs(outReport.grossLoss)
        : (outReport.grossProfit > 0.0) ? 999.0 : 0.0;

    if(m_tradeCount > 1)
    {
        double returns[];
        ArrayResize(returns, m_tradeCount);
        for(int i = 0; i < m_tradeCount; i++)
            returns[i] = m_trades[i].profit;

        outReport.sharpeRatio = ComputeSharpe(returns, m_tradeCount);
        outReport.sortinoRatio = ComputeSortino(returns, m_tradeCount);
    }

    if(m_snapshotCount > 1 && AccountInfoDouble(ACCOUNT_BALANCE) > 0.0)
    {
        double equityCurve[];
        ArrayResize(equityCurve, m_snapshotCount);
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double base = (equity > 0.0) ? equity : 10000.0;

        for(int i = 0; i < m_snapshotCount; i++)
        {
            double ex = m_snapshots[i].grossExposure;
            equityCurve[i] = base - (m_snapshots[i].dailyPL) + (ex * 0.01);
            if(i > 0)
                equityCurve[i] += equityCurve[i - 1];
            else
                equityCurve[i] = base;
        }

        outReport.maxDrawdownPercent = ComputeMaxDrawdown(equityCurve, m_snapshotCount, outReport.maxDrawdownValue);

        double ddSum = 0.0;
        double peak = equityCurve[0];
        int ddCount = 0;
        for(int i = 1; i < m_snapshotCount; i++)
        {
            if(equityCurve[i] > peak)
                peak = equityCurve[i];
            double dd = (peak > 0.0) ? ((peak - equityCurve[i]) / peak) * 100.0 : 0.0;
            if(dd > 0.0)
            {
                ddSum += dd;
                ddCount++;
            }
        }
        outReport.avgDrawdownPercent = (ddCount > 0) ? ddSum / ddCount : 0.0;
    }

    outReport.calmarRatio = (outReport.maxDrawdownPercent > 0.0)
        ? (outReport.totalNetProfit / 100.0) / (outReport.maxDrawdownPercent / 100.0)
        : 0.0;

    outReport.recoveryFactor = (outReport.maxDrawdownValue > 0.0)
        ? outReport.totalNetProfit / outReport.maxDrawdownValue
        : 0.0;

    {
        double expSum = 0.0, maxExp = 0.0, marginSum = 0.0;
        for(int i = 0; i < m_snapshotCount; i++)
        {
            double exPct = m_snapshots[i].totalOpenRiskPercent;
            expSum += exPct;
            if(exPct > maxExp) maxExp = exPct;
            marginSum += m_snapshots[i].marginUtilizationPercent;
        }
        outReport.avgExposurePercent = (m_snapshotCount > 0) ? expSum / m_snapshotCount : 0.0;
        outReport.maxExposurePercent = maxExp;
        outReport.avgMarginUtilization = (m_snapshotCount > 0) ? marginSum / m_snapshotCount : 0.0;
    }

    {
        string contribStr = "";
        for(int i = 0; i < m_symbolCount; i++)
        {
            double pf = (m_symbols[i].totalProfit < 0.0 && m_symbols[i].count > 0)
                ? 0.0
                : (m_symbols[i].count > 0)
                    ? (m_symbols[i].totalProfit > 0.0 ? 999.0 : 0.0)
                    : 0.0;
            double wr = (m_symbols[i].count > 0)
                ? (double)(m_symbols[i].count > 0 ? 50.0 : 0.0)
                : 0.0;

            if(contribStr != "") contribStr += ";";
            contribStr += StringFormat("%s:%.2f:%.1f:%d",
                m_symbols[i].symbol, pf, wr, m_symbols[i].count);
        }
        outReport.symbolContributions = contribStr;
    }

    return true;
}

#endif
