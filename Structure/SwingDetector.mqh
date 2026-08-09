//+------------------------------------------------------------------+
//|                                              SwingDetector.mqh    |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __SWING_DETECTOR_MQH__
#define __SWING_DETECTOR_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Core/HistoryEpoch.mqh"

class CSwingDetector : public IHistoryResetConsumer
{
private:
    CLogger     m_logger;
    bool        m_isInitialized;

    //--- Swing storage (chronological order: oldest -> newest)
    SwingPoint  m_highSwings[];
    SwingPoint  m_lowSwings[];
    int         m_highCount;
    int         m_lowCount;

    //--- State tracking
    int         m_nextId;
    int         m_lastCheckedCenter;   // last bar center index fully evaluated

    //--- Instrumentation counters
    int         m_totalBarsSeen;
    int         m_totalCentersScanned;
    int         m_lastLoggedRatesTotal;
    int         m_updateCount;

    //--- Internal helpers
    bool IsValidBarIndex(int center, int rates_total) const;
    bool IsSwingHigh(const double &high[], int center) const;
    bool IsSwingLow(const double &low[], int center) const;
    void AddSwingHigh(double price, datetime time, int barIndex);
    void AddSwingLow(double price, datetime time, int barIndex);
    void LogSwingConfirmed(const SwingPoint &sp);

public:
    CSwingDetector(void);
    ~CSwingDetector(void);

    //--- Lifecycle
    bool Init(void);
    void Update(const double &high[], const double &low[], const datetime &time[], int rates_total);
    void Shutdown(void);
    void Clear(void);

    //--- LC02: canonical history reset (HistoryEpoch broadcast). Drop
    //--- incremental state and rebuild from the current history.
    void OnHistoryReset(void) { Clear(); }

    //--- Queries
    bool IsInitialized(void) const { return m_isInitialized; }
    int  GetSwingHighCount(void) const { return m_highCount; }
    int  GetSwingLowCount(void) const { return m_lowCount; }
    bool GetSwingHigh(int index, SwingPoint &out) const;
    bool GetSwingLow(int index, SwingPoint &out) const;
};

//--- Inline implementation
CSwingDetector::CSwingDetector(void)
    : m_logger(MODULE_SWING_DETECTOR, "SwingDetector")
    , m_isInitialized(false)
    , m_highCount(0)
    , m_lowCount(0)
    , m_nextId(1)
    , m_lastCheckedCenter(-1)
    , m_totalBarsSeen(0)
    , m_totalCentersScanned(0)
    , m_lastLoggedRatesTotal(0)
    , m_updateCount(0)
{
    // Reserve initial capacity
    ArrayResize(m_highSwings, 256);
    ArrayResize(m_lowSwings, 256);
}

CSwingDetector::~CSwingDetector(void)
{
    Shutdown();
}

bool CSwingDetector::Init(void)
{
    if(m_isInitialized)
    {
        m_logger.LogWarn("SwingDetector already initialized, clearing state");
        Clear();
    }

    m_logger.LogInfo("Initializing SwingDetector...");

    Clear();

    m_isInitialized = true;
    m_logger.LogInfo("SwingDetector initialized");
    return true;
}

void CSwingDetector::Update(const double &high[], const double &low[], const datetime &time[], int rates_total)
{
    if(!m_isInitialized)
    {
        m_logger.LogWarn("Update called but SwingDetector is not initialized");
        return;
    }

    // Need at least 5 bars for a 5-bar fractal
    if(rates_total < 5)
        return;

    //--- Handle chart reload / reset: if rates_total shrunk, rescan
    int maxCenter = rates_total - 3;
    if(maxCenter < m_lastCheckedCenter)
    {
        m_logger.LogInfo("Chart data reset detected, rescanning");
        Clear();
    }

    //--- Instrumentation: track when new bars arrive
    m_updateCount++;
    if(rates_total != m_lastLoggedRatesTotal)
    {
        int barsDelta = (m_lastLoggedRatesTotal == 0) ? rates_total : rates_total - m_lastLoggedRatesTotal;
        m_totalBarsSeen += (barsDelta > 0) ? barsDelta : 0;
        m_lastLoggedRatesTotal = rates_total;
    }

    //--- Determine the range of centers to evaluate this update
    int startCenter = m_lastCheckedCenter + 1;
    if(startCenter < 4)
        startCenter = 4;   // first valid center for a 5-bar fractal (needs i-2 through i+2)

    if(startCenter > maxCenter)
    {
        // Periodic heartbeat: log every 500 updates when idle
        if(m_updateCount % 500 == 0)
            m_logger.LogInfo(StringFormat("Heartbeat rates_total=%d lastCenter=%d barsSeen=%d centersScanned=%d",
                rates_total, m_lastCheckedCenter, m_totalBarsSeen, m_totalCentersScanned));
        return;  // nothing new to evaluate
    }

    int centersToScan = maxCenter - startCenter + 1;
    m_logger.LogInfo(StringFormat("SCANNING rates_total=%d centers=[%d,%d] count=%d barsSeen=%d scan#=%d",
        rates_total, startCenter, maxCenter, centersToScan, m_totalBarsSeen, m_updateCount));

    //--- Evaluate each bar center in chronological order
    for(int center = startCenter; center <= maxCenter; center++)
    {
        //--- Check Swing High
        if(IsSwingHigh(high, center))
        {
            AddSwingHigh(high[center], time[center], center);
        }

        //--- Check Swing Low
        if(IsSwingLow(low, center))
        {
            AddSwingLow(low[center], time[center], center);
        }
    }

    m_totalCentersScanned += (maxCenter - startCenter + 1);
    m_lastCheckedCenter = maxCenter;
    m_logger.LogInfo(StringFormat("SCAN DONE centersScanned=%d (total=%d) lastCenter=%d highSwings=%d lowSwings=%d",
        maxCenter - startCenter + 1, m_totalCentersScanned, m_lastCheckedCenter, m_highCount, m_lowCount));
}

void CSwingDetector::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down SwingDetector...");
    Clear();
    m_isInitialized = false;
    m_logger.LogInfo("SwingDetector shutdown complete");
}

void CSwingDetector::Clear(void)
{
    m_highCount = 0;
    m_lowCount = 0;
    m_nextId = 1;
    m_lastCheckedCenter = -1;
    m_totalBarsSeen = 0;
    m_totalCentersScanned = 0;
    m_lastLoggedRatesTotal = 0;
    m_updateCount = 0;
}

bool CSwingDetector::IsValidBarIndex(int center, int rates_total) const
{
    // For a 5-bar fractal with center at 'center', we need bars at
    // center-2, center-1, center, center+1, center+2
    if(center < 2)
        return false;
    if(center + 2 >= rates_total)
        return false;
    return true;
}

bool CSwingDetector::IsSwingHigh(const double &high[], int center) const
{
    // 5-bar fractal: H[center] > H[center-1] && H[center] > H[center-2]
    //              && H[center] > H[center+1] && H[center] > H[center+2]
    double c = high[center];

    if(c <= high[center - 1]) return false;
    if(c <= high[center - 2]) return false;
    if(c <= high[center + 1]) return false;
    if(c <= high[center + 2]) return false;

    return true;
}

bool CSwingDetector::IsSwingLow(const double &low[], int center) const
{
    // 5-bar fractal: L[center] < L[center-1] && L[center] < L[center-2]
    //              && L[center] < L[center+1] && L[center] < L[center+2]
    double c = low[center];

    if(c >= low[center - 1]) return false;
    if(c >= low[center - 2]) return false;
    if(c >= low[center + 1]) return false;
    if(c >= low[center + 2]) return false;

    return true;
}

void CSwingDetector::AddSwingHigh(double price, datetime time, int barIndex)
{
    //--- Ensure capacity
    if(m_highCount >= ArraySize(m_highSwings))
        ArrayResize(m_highSwings, ArraySize(m_highSwings) + 256);

    //--- Create swing point
    SwingPoint sp;
    sp.id       = m_nextId++;
    sp.time     = time;
    sp.price    = price;
    sp.barIndex = barIndex;
    sp.isHigh   = true;

    //--- Store in chronological order
    m_highSwings[m_highCount] = sp;
    m_highCount++;

    //--- Log the confirmation
    LogSwingConfirmed(sp);
}

void CSwingDetector::AddSwingLow(double price, datetime time, int barIndex)
{
    //--- Ensure capacity
    if(m_lowCount >= ArraySize(m_lowSwings))
        ArrayResize(m_lowSwings, ArraySize(m_lowSwings) + 256);

    //--- Create swing point
    SwingPoint sp;
    sp.id       = m_nextId++;
    sp.time     = time;
    sp.price    = price;
    sp.barIndex = barIndex;
    sp.isHigh   = false;

    //--- Store in chronological order
    m_lowSwings[m_lowCount] = sp;
    m_lowCount++;

    //--- Log the confirmation
    LogSwingConfirmed(sp);
}

void CSwingDetector::LogSwingConfirmed(const SwingPoint &sp)
{
    string typeStr = sp.isHigh ? "HIGH" : "LOW";

    string msg = StringFormat("Swing Confirmed\nID: %d\nType: %s\nBar: %d\nTime: %s\nPrice: %.5f",
                              sp.id, typeStr, sp.barIndex,
                              TimeToString(sp.time, TIME_DATE | TIME_MINUTES), sp.price);

    m_logger.LogInfo(msg);
}

bool CSwingDetector::GetSwingHigh(int index, SwingPoint &out) const
{
    if(index < 0 || index >= m_highCount)
        return false;

    out = m_highSwings[index];
    return true;
}

bool CSwingDetector::GetSwingLow(int index, SwingPoint &out) const
{
    if(index < 0 || index >= m_lowCount)
        return false;

    out = m_lowSwings[index];
    return true;
}

#endif // __SWING_DETECTOR_MQH__