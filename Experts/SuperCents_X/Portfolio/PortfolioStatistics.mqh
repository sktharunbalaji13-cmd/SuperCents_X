//+------------------------------------------------------------------+
//|                                      PortfolioStatistics.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __PORTFOLIO_PORTFOLIO_STATISTICS_MQH__
#define __PORTFOLIO_PORTFOLIO_STATISTICS_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "PortfolioTypes.mqh"
#include "../Monitoring/MonitoringTypes.mqh"

struct PortfolioTradeSummary
{
    int     totalTrades;
    int     wins;
    int     losses;
    double  winRate;
    double  totalProfit;
    double  avgRR;
    double  expectancy;

    PortfolioTradeSummary(void)
        : totalTrades(0)
        , wins(0)
        , losses(0)
        , winRate(0.0)
        , totalProfit(0.0)
        , avgRR(0.0)
        , expectancy(0.0)
    {
    }
};

class CPortfolioStatistics
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    PortfolioSnapshot m_lastSnapshot;
    int               m_updateCount;

public:
    CPortfolioStatistics(void);
    ~CPortfolioStatistics(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    void UpdateFrom(const PortfolioSnapshot &snapshot);
    PortfolioSnapshot GetLastSnapshot(void) const { return m_lastSnapshot; }
    PortfolioTradeSummary ComputeTradeSummary(void) const;

    double GetNetExposure(void) const;
    double GetTotalPL(void) const;
    int    GetActiveSymbolCount(void) const;
};

CPortfolioStatistics::CPortfolioStatistics(void)
    : m_logger(MODULE_PORTFOLIO_STATISTICS, "PortfolioStatistics")
    , m_isInitialized(false)
    , m_updateCount(0)
{
}

CPortfolioStatistics::~CPortfolioStatistics(void)
{
    Shutdown();
}

bool CPortfolioStatistics::Init(void)
{
    m_logger.LogInfo("Initializing PortfolioStatistics...");
    m_updateCount = 0;
    m_isInitialized = true;
    m_logger.LogInfo("PortfolioStatistics initialized");
    return true;
}

void CPortfolioStatistics::Update(void)
{
}

void CPortfolioStatistics::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("==================== PORTFOLIO SUMMARY ====================");
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Updates Processed", m_updateCount));
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Active Symbols", m_lastSnapshot.activeSymbolCount));
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Total Positions", m_lastSnapshot.totalPositions));
    m_logger.LogInfo(StringFormat("  %-30s %10.2f", "Total P&L", m_lastSnapshot.totalPL));
    m_logger.LogInfo(StringFormat("  %-30s %10.2f", "Total Exposure", m_lastSnapshot.totalExposure));
    m_logger.LogInfo(StringFormat("  %-30s %10.2f%%", "Net Exposure %", m_lastSnapshot.netExposurePercent));

    PortfolioTradeSummary ts = ComputeTradeSummary();
    m_logger.LogInfo(StringFormat("  %-30s %5d / %d / %d", "Trades W/L/T", ts.wins, ts.losses, ts.totalTrades));
    m_logger.LogInfo(StringFormat("  %-30s %5.1f%%", "Win Rate", ts.winRate * 100.0));
    m_logger.LogInfo(StringFormat("  %-30s %5.2f", "Avg R:R", ts.avgRR));
    m_logger.LogInfo(StringFormat("  %-30s %5.2f", "Expectancy", ts.expectancy));
    m_logger.LogInfo("===========================================================");

    m_isInitialized = false;
}

void CPortfolioStatistics::UpdateFrom(const PortfolioSnapshot &snapshot)
{
    if(!m_isInitialized)
        return;

    m_lastSnapshot = snapshot;
    m_updateCount++;
}

PortfolioTradeSummary CPortfolioStatistics::ComputeTradeSummary(void) const
{
    PortfolioTradeSummary summary;
    return summary;
}

double CPortfolioStatistics::GetNetExposure(void) const
{
    return m_lastSnapshot.netExposurePercent;
}

double CPortfolioStatistics::GetTotalPL(void) const
{
    return m_lastSnapshot.totalPL;
}

int CPortfolioStatistics::GetActiveSymbolCount(void) const
{
    return m_lastSnapshot.activeSymbolCount;
}

#endif
