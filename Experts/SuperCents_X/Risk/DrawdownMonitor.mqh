//+------------------------------------------------------------------+
//|                                         DrawdownMonitor.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __RISK_DRAWDOWN_MONITOR_MQH__
#define __RISK_DRAWDOWN_MONITOR_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "RiskTypes.mqh"

class CDrawdownMonitor
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

    double  m_peakEquity;
    double  m_startingEquity;
    double  m_dayStartEquity;
    double  m_weekStartEquity;
    double  m_currentDrawdown;
    double  m_maxDrawdown;

    datetime m_lastDayCheck;
    datetime m_lastWeekCheck;

    bool    m_tradingPaused;
    string  m_pauseReason;

    int     m_pauseCount;

    void CheckDailyReset(void)
    {
        MqlDateTime dt;
        TimeCurrent(dt);

        datetime currentDay = StructToTime(dt);
        dt.hour = 0;
        dt.min = 0;
        dt.sec = 0;
        datetime dayStart = StructToTime(dt);

        if(dayStart != m_lastDayCheck)
        {
            m_lastDayCheck = dayStart;
            m_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
            m_logger.LogInfo(StringFormat("DRAWDOWN-UPDATE Daily reset: equity=%.2f", m_dayStartEquity));
        }
    }

    void CheckWeeklyReset(void)
    {
        MqlDateTime dt;
        TimeCurrent(dt);

        int currentWeek = dt.year * 100 + dt.mon * 4 + dt.day / 7;

        MqlDateTime lastDt;
        TimeToStruct(m_lastWeekCheck, lastDt);
        int lastWeek = lastDt.year * 100 + lastDt.mon * 4 + lastDt.day / 7;

        if(currentWeek != lastWeek)
        {
            m_lastWeekCheck = TimeCurrent();
            m_weekStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
            m_logger.LogInfo(StringFormat("DRAWDOWN-UPDATE Weekly reset: equity=%.2f", m_weekStartEquity));
        }
    }

public:
    CDrawdownMonitor(void);
    ~CDrawdownMonitor(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    DrawdownSnapshot GetSnapshot(void) const;

    bool IsTradingPaused(void) const { return m_tradingPaused; }
    string GetPauseReason(void) const { return m_pauseReason; }
    int GetPauseCount(void) const { return m_pauseCount; }

    void ResumeTrading(void);
    bool CheckLimits(const RiskConfig &config, string &outReason);
};

CDrawdownMonitor::CDrawdownMonitor(void)
    : m_logger(MODULE_DRAWDOWN_MONITOR, "DrawdownMonitor")
    , m_isInitialized(false)
    , m_peakEquity(0.0)
    , m_startingEquity(0.0)
    , m_dayStartEquity(0.0)
    , m_weekStartEquity(0.0)
    , m_currentDrawdown(0.0)
    , m_maxDrawdown(0.0)
    , m_lastDayCheck(0)
    , m_lastWeekCheck(0)
    , m_tradingPaused(false)
    , m_pauseReason("")
    , m_pauseCount(0)
{
}

CDrawdownMonitor::~CDrawdownMonitor(void)
{
    Shutdown();
}

bool CDrawdownMonitor::Init(void)
{
    m_logger.LogInfo("Initializing DrawdownMonitor...");

    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    m_peakEquity = equity;
    m_startingEquity = equity;
    m_dayStartEquity = equity;
    m_weekStartEquity = equity;
    m_currentDrawdown = 0.0;
    m_maxDrawdown = 0.0;
    m_tradingPaused = false;
    m_pauseReason = "";
    m_pauseCount = 0;

    MqlDateTime dt;
    TimeCurrent(dt);
    dt.hour = 0;
    dt.min = 0;
    dt.sec = 0;
    m_lastDayCheck = StructToTime(dt);
    m_lastWeekCheck = TimeCurrent();

    m_isInitialized = true;
    m_logger.LogInfo(StringFormat("DrawdownMonitor initialized: equity=%.2f", equity));
    return true;
}

void CDrawdownMonitor::Update(void)
{
    if(!m_isInitialized)
        return;

    double equity = AccountInfoDouble(ACCOUNT_EQUITY);

    CheckDailyReset();
    CheckWeeklyReset();

    if(equity > m_peakEquity)
    {
        m_peakEquity = equity;
        m_currentDrawdown = 0.0;
    }
    else
    {
        m_currentDrawdown = (m_peakEquity > 0.0)
            ? ((m_peakEquity - equity) / m_peakEquity) * 100.0
            : 0.0;
    }

    if(m_currentDrawdown > m_maxDrawdown)
        m_maxDrawdown = m_currentDrawdown;

    m_logger.LogDebug(StringFormat("DRAWDOWN-UPDATE equity=%.2f peak=%.2f dd=%.2f%% maxDD=%.2f%%",
        equity, m_peakEquity, m_currentDrawdown, m_maxDrawdown));
}

void CDrawdownMonitor::Shutdown(void)
{
    m_logger.LogInfo("Shutting down DrawdownMonitor...");

    DrawdownSnapshot snap = GetSnapshot();

    m_logger.LogInfo("==================== DRAWDOWN SUMMARY ====================");
    m_logger.LogInfo(StringFormat("  %-30s %10.2f", "Peak Equity", snap.peakEquity));
    m_logger.LogInfo(StringFormat("  %-30s %10.2f", "Current Equity", snap.currentEquity));
    m_logger.LogInfo(StringFormat("  %-30s %10.2f%%", "Current Drawdown", snap.currentDrawdownPercent));
    m_logger.LogInfo(StringFormat("  %-30s %10.2f%%", "Maximum Drawdown", snap.maxDrawdownPercent));
    m_logger.LogInfo(StringFormat("  %-30s %10.2f", "Today P/L", snap.dailyPL));
    m_logger.LogInfo(StringFormat("  %-30s %10.2f", "Weekly P/L", snap.weeklyPL));
    m_logger.LogInfo(StringFormat("  %-30s %10d", "Trading Pauses", m_pauseCount));
    m_logger.LogInfo("==========================================================");

    m_tradingPaused = false;
    m_pauseReason = "";
    m_isInitialized = false;
    m_logger.LogInfo("DrawdownMonitor shutdown complete");
}

DrawdownSnapshot CDrawdownMonitor::GetSnapshot(void) const
{
    DrawdownSnapshot snap;
    snap.peakEquity   = m_peakEquity;
    snap.currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    snap.currentDrawdownPercent = m_currentDrawdown;
    snap.maxDrawdownPercent = m_maxDrawdown;
    snap.dailyPL  = snap.currentEquity - m_dayStartEquity;
    snap.weeklyPL = snap.currentEquity - m_weekStartEquity;
    return snap;
}

void CDrawdownMonitor::ResumeTrading(void)
{
    if(m_tradingPaused)
    {
        m_logger.LogInfo("Trading resumed by manual override");
        m_tradingPaused = false;
        m_pauseReason = "";
    }
}

bool CDrawdownMonitor::CheckLimits(const RiskConfig &config, string &outReason)
{
    if(m_tradingPaused)
    {
        outReason = m_pauseReason;
        return false;
    }

    DrawdownSnapshot snap = GetSnapshot();

    if(snap.dailyPL <= config.dailyLossLimitPercent * m_dayStartEquity / 100.0
        && config.dailyLossLimitPercent < 0.0)
    {
        m_tradingPaused = true;
        m_pauseCount++;
        m_pauseReason = StringFormat("Daily loss limit reached: P/L=%.2f limit=%.2f%%",
            snap.dailyPL, config.dailyLossLimitPercent);
        outReason = m_pauseReason;
        m_logger.LogWarn(StringFormat("DRAWDOWN-UPDATE %s", outReason));
        return false;
    }

    if(snap.weeklyPL <= config.weeklyLossLimitPercent * m_weekStartEquity / 100.0
        && config.weeklyLossLimitPercent < 0.0)
    {
        m_tradingPaused = true;
        m_pauseCount++;
        m_pauseReason = StringFormat("Weekly loss limit reached: P/L=%.2f limit=%.2f%%",
            snap.weeklyPL, config.weeklyLossLimitPercent);
        outReason = m_pauseReason;
        m_logger.LogWarn(StringFormat("DRAWDOWN-UPDATE %s", outReason));
        return false;
    }

    if(snap.currentDrawdownPercent >= MathAbs(config.equityStopPercent)
        && config.equityStopPercent < 0.0)
    {
        m_tradingPaused = true;
        m_pauseCount++;
        m_pauseReason = StringFormat("Equity stop triggered: drawdown=%.2f%% limit=%.2f%%",
            snap.currentDrawdownPercent, MathAbs(config.equityStopPercent));
        outReason = m_pauseReason;
        m_logger.LogWarn(StringFormat("DRAWDOWN-UPDATE %s", outReason));
        return false;
    }

    return true;
}

#endif
