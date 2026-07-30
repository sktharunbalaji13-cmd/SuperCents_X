//+------------------------------------------------------------------+
//|                                        StatisticsReporter.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __MONITORING_STATISTICS_REPORTER_MQH__
#define __MONITORING_STATISTICS_REPORTER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "MonitoringTypes.mqh"
#include "EventBusAdapter.mqh"
#include "../Validation/ValidationTypes.mqh"
#include "../Validation/ValidationEventBus.mqh"

class CStatisticsReporter : public CEventHandler
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    CValidationEventBus *m_validationBus;

    int     m_totalTrades;
    int     m_wins;
    int     m_losses;
    double  m_totalRR;
    double  m_totalProfit;
    double  m_largestWin;
    double  m_largestLoss;
    ulong   m_totalDuration;
    int     m_tradesWithRR;

    bool GetCloseDealData(ulong positionTicket, double &exitPrice, double &profit,
                          double &commission, double &swap, long &dealType)
    {
        HistorySelect(0, TimeCurrent());
        int deals = HistoryDealsTotal();

        for(int i = deals - 1; i >= 0; i--)
        {
            ulong dealTicket = HistoryDealGetTicket(i);
            if(dealTicket == 0)
                continue;

            if(HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == (long)positionTicket)
            {
                long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
                if(entry == DEAL_ENTRY_OUT)
                {
                    exitPrice  = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
                    profit     = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                    commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
                    swap       = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
                    dealType   = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
                    return true;
                }
            }
        }
        return false;
    }

public:
    CStatisticsReporter(void);
    ~CStatisticsReporter(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    virtual void HandleEvent(const EventData &data);

    void SetValidationEventBus(CValidationEventBus *bus) { m_validationBus = bus; }

    TradeStatistics GetStatistics(void) const;
};

CStatisticsReporter::CStatisticsReporter(void)
    : m_logger(MODULE_STATISTICS_REPORTER, "StatisticsReporter")
    , m_isInitialized(false)
    , m_validationBus(NULL)
    , m_totalTrades(0)
    , m_wins(0)
    , m_losses(0)
    , m_totalRR(0.0)
    , m_totalProfit(0.0)
    , m_largestWin(0.0)
    , m_largestLoss(0.0)
    , m_totalDuration(0)
    , m_tradesWithRR(0)
{
}

CStatisticsReporter::~CStatisticsReporter(void)
{
    Shutdown();
}

bool CStatisticsReporter::Init(void)
{
    m_logger.LogInfo("Initializing StatisticsReporter...");

    m_totalTrades = 0;
    m_wins = 0;
    m_losses = 0;
    m_totalRR = 0.0;
    m_totalProfit = 0.0;
    m_largestWin = 0.0;
    m_largestLoss = 0.0;
    m_totalDuration = 0;
    m_tradesWithRR = 0;

    m_isInitialized = true;
    m_logger.LogInfo("StatisticsReporter initialized");
    return true;
}

void CStatisticsReporter::Update(void)
{
}

void CStatisticsReporter::Shutdown(void)
{
    m_logger.LogInfo("Shutting down StatisticsReporter...");

    TradeStatistics stats = GetStatistics();

    m_logger.LogInfo("==================== TRADE STATISTICS ====================");
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Total Trades", stats.totalTrades));
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Wins", stats.wins));
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Losses", stats.losses));
    m_logger.LogInfo(StringFormat("  %-30s %5.2f%%", "Win Rate", stats.winRate * 100.0));
    m_logger.LogInfo(StringFormat("  %-30s %5.2f", "Average RR", stats.avgRR));
    m_logger.LogInfo(StringFormat("  %-30s %5.2f sec", "Average Duration", stats.avgDurationSec));
    m_logger.LogInfo(StringFormat("  %-30s %10.2f", "Largest Win", stats.largestWin));
    m_logger.LogInfo(StringFormat("  %-30s %10.2f", "Largest Loss", stats.largestLoss));
    m_logger.LogInfo(StringFormat("  %-30s %10.2f", "Total Profit", stats.totalProfit));
    m_logger.LogInfo(StringFormat("  %-30s %5.2f", "Expectancy", stats.expectancy));
    m_logger.LogInfo("==========================================================");

    m_isInitialized = false;
    m_logger.LogInfo("StatisticsReporter shutdown complete");
}

void CStatisticsReporter::HandleEvent(const EventData &data)
{
    if(!m_isInitialized)
        return;

    if(data.eventType != EVENT_POSITION_CLOSED)
        return;

    double exitPrice = data.exitPrice;
    double profit = data.profit;
    double commission = 0.0;
    double swap = 0.0;
    long dealType = -1;

    if(exitPrice <= 0.0)
    {
        if(!GetCloseDealData(data.ticket, exitPrice, profit, commission, swap, dealType))
        {
            exitPrice = data.entryPrice;
            profit = 0.0;
        }
    }

    double netProfit = profit + commission + swap;
    m_totalTrades++;
    m_totalProfit += netProfit;
    m_totalDuration += (data.closedTime - data.openedTime);

    // Calculate R:R from entry and stop
    double rr = 0.0;
    if(data.stopLoss > 0.0 && data.entryPrice > 0.0)
    {
        double risk = MathAbs(data.entryPrice - data.stopLoss);
        if(risk > 0.0 && exitPrice > 0.0)
        {
            double move = (data.positionType == POSITION_TYPE_BUY)
                ? (exitPrice - data.entryPrice)
                : (data.entryPrice - exitPrice);
            rr = move / risk;
        }
    }

    if(netProfit > 0.0)
    {
        m_wins++;
        m_totalRR += rr;
        m_tradesWithRR++;
        if(netProfit > m_largestWin)
            m_largestWin = netProfit;
    }
    else
    {
        m_losses++;
        if(netProfit < m_largestLoss)
            m_largestLoss = netProfit;
    }

    m_logger.LogInfo(StringFormat("POSITION-CLOSED Ticket=%llu P/L=%.2f RR=%.2f Duration=%llds",
        data.ticket, netProfit, rr, (data.closedTime - data.openedTime)));

    if(m_validationBus != NULL)
    {
        ValidationEventData vd;
        vd.eventType = VALIDATION_EVENT_TRADE_CLOSED;
        vd.timestamp = TimeCurrent();
        vd.ticket = data.ticket;
        vd.symbol = data.symbol;
        vd.positionType = data.positionType;
        vd.volume = data.volume;
        vd.openedTime = data.openedTime;
        vd.closedTime = data.closedTime;
        vd.grossProfit = profit;
        vd.netProfit = netProfit;
        vd.commission = commission;
        vd.swap = swap;
        vd.entryPrice = data.entryPrice;
        vd.exitPrice = exitPrice;
        vd.stopLoss = data.stopLoss;
        vd.takeProfit = data.takeProfit;
        vd.rrAchieved = rr;
        m_validationBus.Publish(VALIDATION_EVENT_TRADE_CLOSED, vd);
    }
}

TradeStatistics CStatisticsReporter::GetStatistics(void) const
{
    TradeStatistics stats;
    stats.totalTrades  = m_totalTrades;
    stats.wins         = m_wins;
    stats.losses       = m_losses;
    stats.winRate      = (m_totalTrades > 0) ? ((double)m_wins / (double)m_totalTrades) : 0.0;
    stats.avgRR        = (m_tradesWithRR > 0) ? (m_totalRR / (double)m_tradesWithRR) : 0.0;
    stats.avgDurationSec = (m_totalTrades > 0) ? ((double)m_totalDuration / (double)m_totalTrades) : 0.0;
    stats.largestWin   = m_largestWin;
    stats.largestLoss  = m_largestLoss;
    stats.totalProfit  = m_totalProfit;
    stats.expectancy   = (m_totalTrades > 0) ? (m_totalProfit / (double)m_totalTrades) : 0.0;

    return stats;
}

#endif
