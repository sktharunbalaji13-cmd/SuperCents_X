#ifndef __VALIDATION_BEHAVIORAL_METRICS_COLLECTOR_MQH__
#define __VALIDATION_BEHAVIORAL_METRICS_COLLECTOR_MQH__

#include "../Core/Logger.mqh"
#include "ValidationTypes.mqh"
#include "ValidationEventBus.mqh"

#define MAX_BEHAVIORAL_OBSERVATIONS 10000

class CBehavioralMetricsCollector : public CValidationEventHandler
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;
    CValidationEventBus *m_bus;

    TradeOutcome m_observations[MAX_BEHAVIORAL_OBSERVATIONS];
    int          m_observationCount;

    string GetSessionName(int hour) const
    {
        if(hour >= 0 && hour < 7)
            return "Asian";
        if(hour >= 7 && hour < 16)
            return "London";
        return "NewYork";
    }

public:
    CBehavioralMetricsCollector(void);
    ~CBehavioralMetricsCollector(void);

    bool Init(CValidationEventBus *bus);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    virtual void OnEvent(const ValidationEventData &data);

    void Finalize(BehavioralMetrics &out);
    void Reset(void);

    int GetObservationCount(void) const { return m_observationCount; }
};

CBehavioralMetricsCollector::CBehavioralMetricsCollector(void)
    : m_logger(MODULE_UNKNOWN, "BehavioralMetricsCollector")
    , m_isInitialized(false)
    , m_bus(NULL)
    , m_observationCount(0)
{
}

CBehavioralMetricsCollector::~CBehavioralMetricsCollector(void)
{
    Shutdown();
}

bool CBehavioralMetricsCollector::Init(CValidationEventBus *bus)
{
    m_logger.LogInfo("Initializing BehavioralMetricsCollector...");

    m_bus = bus;
    m_observationCount = 0;

    if(m_bus != NULL)
    {
        m_bus.Subscribe(VALIDATION_EVENT_TRADE_CLOSED, GetPointer(this));
    }

    m_isInitialized = true;
    m_logger.LogInfo("BehavioralMetricsCollector initialized");
    return true;
}

void CBehavioralMetricsCollector::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    if(m_bus != NULL)
    {
        m_bus.Unsubscribe(VALIDATION_EVENT_TRADE_CLOSED, GetPointer(this));
        m_bus = NULL;
    }

    m_observationCount = 0;
    m_isInitialized = false;
    m_logger.LogInfo("BehavioralMetricsCollector shutdown complete");
}

void CBehavioralMetricsCollector::OnEvent(const ValidationEventData &data)
{
    if(!m_isInitialized)
        return;

    if(data.eventType != VALIDATION_EVENT_TRADE_CLOSED)
        return;

    if(m_observationCount >= MAX_BEHAVIORAL_OBSERVATIONS)
    {
        m_logger.LogWarn("Max observations reached, skipping trade");
        return;
    }

    TradeOutcome t;
    t.ticket = data.ticket;
    t.symbol = data.symbol;
    t.closeTime = data.closedTime;
    t.direction = data.positionType;
    t.netProfit = data.netProfit;
    t.rrAchieved = data.rrAchieved;
    t.riskPercent = data.riskPercent;

    double point = SymbolInfoDouble(data.symbol, SYMBOL_POINT);
    if(point > 0.0 && data.entryPrice > 0.0)
    {
        double slDist = MathAbs(data.entryPrice - data.stopLoss);
        double tpDist = MathAbs(data.takeProfit - data.entryPrice);
        t.stopPips = (slDist > 0.0) ? slDist / point / 10.0 : 0.0;
        t.targetPips = (tpDist > 0.0) ? tpDist / point / 10.0 : 0.0;
    }

    t.hadBOS = data.hadBOS;
    t.bosRespected = data.bosRespected;
    t.hadOrderBlock = data.hadOrderBlock;
    t.obTouched = data.obTouched;
    t.hadFVG = data.hadFVG;
    t.fvgFilled = data.fvgFilled;
    t.entryConfidence = data.entryConfidence;
    t.confluenceScore = data.confluenceScore;

    t.sessionHour = data.sessionHour;
    t.sessionName = (data.sessionName != "") ? data.sessionName : GetSessionName(data.sessionHour);
    t.atrAtEntry = data.atrAtEntry;
    t.spreadAtEntry = data.spreadAtEntry;

    m_observations[m_observationCount] = t;
    m_observationCount++;
}

void CBehavioralMetricsCollector::Finalize(BehavioralMetrics &out)
{
    out = BehavioralMetrics();

    if(m_observationCount == 0)
        return;

    out.symbol = m_observations[0].symbol;
    out.timeframe = _Period;
    out.totalTrades = m_observationCount;

    double totalConfidence = 0.0;
    double totalWinConfidence = 0.0;
    double totalLossConfidence = 0.0;
    int confidenceCount = 0;
    int winConfidenceCount = 0;
    int lossConfidenceCount = 0;

    double totalDuration = 0.0;
    double totalWinDuration = 0.0;
    double totalLossDuration = 0.0;

    for(int i = 0; i < m_observationCount; i++)
    {
        TradeOutcome t = m_observations[i];
        bool isWin = (t.netProfit > 0.0);

        if(isWin)
        {
            out.winningTrades++;
            totalWinDuration += (double)t.closeTime;
        }
        else
        {
            out.losingTrades++;
            totalLossDuration += (double)t.closeTime;
        }
        totalDuration += (double)t.closeTime;

        if(t.hadBOS)
        {
            out.tradesWithBOS++;
            if(t.bosRespected)
                out.bosRespectedCount++;
        }

        if(t.hadOrderBlock)
        {
            out.tradesWithOB++;
            if(t.obTouched)
                out.obTouchedCount++;
        }

        if(t.hadFVG)
        {
            out.tradesWithFVG++;
            if(t.fvgFilled)
                out.fvgFilledCount++;
        }

        if(t.entryConfidence > 0.0)
        {
            totalConfidence += t.entryConfidence;
            confidenceCount++;
            if(isWin)
            {
                totalWinConfidence += t.entryConfidence;
                winConfidenceCount++;
            }
            else
            {
                totalLossConfidence += t.entryConfidence;
                lossConfidenceCount++;
            }
        }

        string sn = t.sessionName;
        if(sn == "Asian")
        {
            out.asianTrades++;
            if(isWin)
                out.asianWinRate++;
        }
        else if(sn == "London")
        {
            out.londonTrades++;
            if(isWin)
                out.londonWinRate++;
        }
        else if(sn == "NewYork")
        {
            out.nyTrades++;
            if(isWin)
                out.nyWinRate++;
        }
    }

    out.winRate = (out.totalTrades > 0)
        ? (double)out.winningTrades / out.totalTrades * 100.0
        : 0.0;

    out.bosAccuracy = (out.tradesWithBOS > 0)
        ? (double)out.bosRespectedCount / out.tradesWithBOS * 100.0
        : 0.0;

    out.obTouchRate = (out.tradesWithOB > 0)
        ? (double)out.obTouchedCount / out.tradesWithOB * 100.0
        : 0.0;

    out.fvgFillRate = (out.tradesWithFVG > 0)
        ? (double)out.fvgFilledCount / out.tradesWithFVG * 100.0
        : 0.0;

    out.avgEntryConfidence = (confidenceCount > 0)
        ? totalConfidence / confidenceCount
        : 0.0;

    out.avgWinConfidence = (winConfidenceCount > 0)
        ? totalWinConfidence / winConfidenceCount
        : 0.0;

    out.avgLossConfidence = (lossConfidenceCount > 0)
        ? totalLossConfidence / lossConfidenceCount
        : 0.0;

    out.asianWinRate = (out.asianTrades > 0)
        ? out.asianWinRate / out.asianTrades * 100.0
        : 0.0;

    out.londonWinRate = (out.londonTrades > 0)
        ? out.londonWinRate / out.londonTrades * 100.0
        : 0.0;

    out.nyWinRate = (out.nyTrades > 0)
        ? out.nyWinRate / out.nyTrades * 100.0
        : 0.0;

    out.avgDurationSeconds = (out.totalTrades > 0)
        ? totalDuration / out.totalTrades
        : 0.0;

    out.avgWinDurationSeconds = (out.winningTrades > 0)
        ? totalWinDuration / out.winningTrades
        : 0.0;

    out.avgLossDurationSeconds = (out.losingTrades > 0)
        ? totalLossDuration / out.losingTrades
        : 0.0;
}

void CBehavioralMetricsCollector::Reset(void)
{
    m_observationCount = 0;
}

#endif
