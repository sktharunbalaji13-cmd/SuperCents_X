//+------------------------------------------------------------------+
//|                                             HistoryEpoch.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                                                  |
//| Sprint 20 - LC02: canonical history shrink/reset mechanism       |
//| (AVP L E11). One mechanism, multiple consumers.                  |
//|                                                                  |
//| Spec: docs/Sprint20_History_Reset_Mechanism.md                   |
//|                                                                  |
//| The mechanism answers exactly four questions:                    |
//|   1. rates_total decreased -> how is that detected?              |
//|      CHistoryEpoch::Update() compares against the last observed  |
//|      rates_total; newest-bar time reversal is detected against   |
//|      the last observed time[0].                                  |
//|   2. What state is invalidated? -> the epoch of every registered |
//|      consumer (consumer decides its own state to drop).          |
//|   3. Who receives the reset? -> every registered consumer, in    |
//|      registration order (registry broadcast).                    |
//|   4. How is rebuild triggered? -> IHistoryResetConsumer::         |
//|      OnHistoryReset() per consumer; rebuild = the consumer's     |
//|      existing initial-scan path.                                 |
//|                                                                  |
//| Detection rules (canonical, tested in TestHistoryEpoch.mqh):     |
//|   - First update after construction / Reset() = baseline only.   |
//|   - rates_total < last seen          -> HISTORY_EVENT_SHRINK.    |
//|   - time[0] (newest bar) moved back  -> HISTORY_EVENT_TIME_RESET.|
//|   - Both                             -> SHRINK (priority); still |
//|     exactly one epoch bump + one broadcast.                      |
//|   - Grow or identical data           -> HISTORY_EVENT_NONE.      |
//|   - Consecutive shrinks are consecutive events.                  |
//+------------------------------------------------------------------+
#ifndef __HISTORY_EPOCH_MQH__
#define __HISTORY_EPOCH_MQH__

enum EHistoryEvent
{
    HISTORY_EVENT_NONE       = 0,  // normal update (baseline / extension / identical re-feed)
    HISTORY_EVENT_SHRINK     = 1,  // rates_total decreased
    HISTORY_EVENT_TIME_RESET = 2   // newest-bar time moved backwards (reload / purge)
};

//+------------------------------------------------------------------+
//| Reset consumer contract (LC02 clause C5):                        |
//|   - Consumers register with CHistoryEpoch::AddConsumer().        |
//|   - OnHistoryReset() means: drop the consumer's incremental      |
//|     state, then rebuild from the current history via its         |
//|     initial-scan path. Cursors must not be advanced past the     |
//|     new history size.                                            |
//+------------------------------------------------------------------+
class IHistoryResetConsumer
{
public:
    virtual ~IHistoryResetConsumer() {}

    virtual void OnHistoryReset() = 0;
};

class CHistoryEpoch
{
private:
    int         m_epoch;
    int         m_lastRatesTotal;
    datetime    m_lastTimeNewest;
    bool        m_hasBaseline;
    EHistoryEvent m_lastEvent;
    IHistoryResetConsumer *m_consumers[];
    int         m_consumerCount;

public:
    CHistoryEpoch(void);
    ~CHistoryEpoch(void);

    //--- Canonical detection + broadcast. Call ONCE per data update,
    //--- BEFORE driving any consumer's Update(), with the series
    //--- order arrays (timeNewest = time[0], the current/newest bar).
    EHistoryEvent Update(int rates_total, datetime timeNewest);

    //--- Context re-init (symbol/timeframe change, EA restart):
    //--- clears the baseline, epoch returns to 0. Next Update() is
    //--- treated as a fresh first observation.
    void Reset(void);

    //--- Registry
    void AddConsumer(IHistoryResetConsumer *consumer);

    //--- Queries
    int GetEpoch(void) const { return m_epoch; }
    EHistoryEvent GetLastEvent(void) const { return m_lastEvent; }
};

//--- Inline implementation
CHistoryEpoch::CHistoryEpoch(void)
    : m_epoch(0)
    , m_lastRatesTotal(0)
    , m_lastTimeNewest(0)
    , m_hasBaseline(false)
    , m_lastEvent(HISTORY_EVENT_NONE)
    , m_consumerCount(0)
{
    ArrayResize(m_consumers, 8);
}

CHistoryEpoch::~CHistoryEpoch(void)
{
    //--- Consumers are owned by the context, not by the epoch.
    m_consumerCount = 0;
    ArrayResize(m_consumers, 0);
}

EHistoryEvent CHistoryEpoch::Update(int rates_total, datetime timeNewest)
{
    EHistoryEvent ev = HISTORY_EVENT_NONE;

    if(m_hasBaseline)
    {
        //--- LC4: rates_total shrink
        bool shrink = (rates_total < m_lastRatesTotal);
        //--- LC5: time reversal of the newest bar
        bool timeReset = (m_lastTimeNewest != 0) && (timeNewest < m_lastTimeNewest);

        if(shrink)
            ev = HISTORY_EVENT_SHRINK;
        else if(timeReset)
            ev = HISTORY_EVENT_TIME_RESET;
    }

    //--- Record baseline first (a shrink becomes the new baseline)
    m_hasBaseline = true;
    m_lastRatesTotal = rates_total;
    m_lastTimeNewest = timeNewest;
    m_lastEvent = ev;

    if(ev != HISTORY_EVENT_NONE)
    {
        m_epoch++;
        for(int i = 0; i < m_consumerCount; i++)
            m_consumers[i].OnHistoryReset();
    }

    return ev;
}

void CHistoryEpoch::Reset(void)
{
    m_epoch = 0;
    m_lastRatesTotal = 0;
    m_lastTimeNewest = 0;
    m_hasBaseline = false;
    m_lastEvent = HISTORY_EVENT_NONE;
}

void CHistoryEpoch::AddConsumer(IHistoryResetConsumer *consumer)
{
    if(consumer == NULL)
        return;

    if(m_consumerCount >= ArraySize(m_consumers))
        ArrayResize(m_consumers, ArraySize(m_consumers) + 8);

    m_consumers[m_consumerCount] = consumer;
    m_consumerCount++;
}

#endif // __HISTORY_EPOCH_MQH__
