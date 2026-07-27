//+------------------------------------------------------------------+
//|                                  PortfolioExposureTracker.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __PORTFOLIO_PORTFOLIO_EXPOSURE_TRACKER_MQH__
#define __PORTFOLIO_PORTFOLIO_EXPOSURE_TRACKER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "PortfolioRiskTypes.mqh"

class CPortfolioExposureTracker
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

public:
    CPortfolioExposureTracker(void);
    ~CPortfolioExposureTracker(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    PortfolioExposure GetSnapshot(void) const;
};

CPortfolioExposureTracker::CPortfolioExposureTracker(void)
    : m_logger(MODULE_EXPOSURE_TRACKER, "PortfolioExposureTracker")
    , m_isInitialized(false)
{
}

CPortfolioExposureTracker::~CPortfolioExposureTracker(void)
{
    Shutdown();
}

bool CPortfolioExposureTracker::Init(void)
{
    m_logger.LogInfo("Initializing PortfolioExposureTracker...");
    m_isInitialized = true;
    m_logger.LogInfo("PortfolioExposureTracker initialized");
    return true;
}

void CPortfolioExposureTracker::Update(void)
{
}

void CPortfolioExposureTracker::Shutdown(void)
{
    if(!m_isInitialized)
        return;
    m_isInitialized = false;
}

PortfolioExposure CPortfolioExposureTracker::GetSnapshot(void) const
{
    PortfolioExposure exp;

    if(!m_isInitialized)
        return exp;

    double totalLong = 0.0;
    double totalShort = 0.0;
    int posCount = 0;

    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            double vol = PositionGetDouble(POSITION_VOLUME);
            double price = PositionGetDouble(POSITION_PRICE_OPEN);
            double exposure = vol * price;

            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                totalLong += exposure;
            }
            else
            {
                totalShort += exposure;
            }

            posCount++;
        }
    }

    exp.netLongExposure = totalLong;
    exp.netShortExposure = totalShort;
    exp.grossExposure = totalLong + totalShort;
    exp.totalPositions = posCount;

    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    exp.marginUsed = AccountInfoDouble(ACCOUNT_MARGIN);
    exp.marginFree = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    exp.marginUtilizationPercent = (equity > 0.0)
        ? (exp.marginUsed / equity) * 100.0 : 0.0;

    exp.totalOpenRiskPercent = (balance > 0.0)
        ? (exp.grossExposure / balance) * 100.0 : 0.0;

    exp.dailyPL = (balance - equity);

    static double peakEquity = 0.0;
    if(equity > peakEquity)
        peakEquity = equity;
    exp.currentDrawdownPercent = (peakEquity > 0.0)
        ? ((peakEquity - equity) / peakEquity) * 100.0 : 0.0;

    return exp;
}

#endif
