//+------------------------------------------------------------------+
//|                                          OrderBlockDetector.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __ORDER_BLOCK_DETECTOR_MQH__
#define __ORDER_BLOCK_DETECTOR_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Core/HistoryEpoch.mqh"
#include "CHOCHDetector.mqh"
#include "TrendState.mqh"
#include "ProtectedPointManager.mqh"

struct OBStats
{
    int chochReceived;
    int searchAttempted;
    int searchSucceeded;
    int searchFailed;
    int storeAttempted;
    int storeSucceeded;
    int rejectedDuplicate;
    int rejectedCapacity;
    int rejectedInvalid;
    void Reset(void) { chochReceived=0; searchAttempted=0; searchSucceeded=0; searchFailed=0;
                       storeAttempted=0; storeSucceeded=0; rejectedDuplicate=0; rejectedCapacity=0; rejectedInvalid=0; }
};

class COrderBlockDetector : public IHistoryResetConsumer
{
private:
    CLogger m_logger;
    bool m_isInitialized;

    OrderBlock m_orderBlocks[];
    int m_orderBlockCount;
    int m_nextId;
    int m_lastProcessedCHOCHIndex;
    OBStats m_stats;

public:
    COrderBlockDetector(void);
    ~COrderBlockDetector(void);

    bool Init(void);
    void Update(CCHOCHDetector *chochDetector, CTrendState *trendState,
                CProtectedPointManager *protectedMgr,
                const double &open[], const double &high[], const double &low[],
                const double &close[], const datetime &time[], int rates_total);
    void Shutdown(void);
    void Clear(void);

    //--- LC02: canonical history reset (HistoryEpoch broadcast). The latent
    //--- CHOCH-count watermark (m_lastProcessedCHOCHIndex) is reset so the
    //--- rebuilt CHOCH stream is re-examined.
    void OnHistoryReset(void) { Clear(); }

    bool IsInitialized(void) const { return m_isInitialized; }
    int GetOrderBlockCount(void) const { return m_orderBlockCount; }
    bool GetOrderBlock(int index, OrderBlock &out) const;

private:
    void ProcessNewCHOCH(const CHOCHEvent &choch,
                        const double &open[], const double &high[], const double &low[],
                        const double &close[], const datetime &time[], int rates_total);
    bool FindOrderBlock(bool bullishCHOCH,
                        const double &open[], const double &high[], const double &low[],
                        const double &close[], const datetime &time[], int rates_total,
                        OrderBlock &out, int displacementBarIndex = 1);
    void UpdateLifecycle(CTrendState *trendState, const double &close[]);
};

COrderBlockDetector::COrderBlockDetector(void)
    : m_logger(MODULE_ORDER_BLOCK_DETECTOR, "OrderBlock")
    , m_isInitialized(false)
    , m_orderBlockCount(0)
    , m_nextId(1)
    , m_lastProcessedCHOCHIndex(0)
{
    ArrayResize(m_orderBlocks, 256);
    m_stats.Reset();
}

COrderBlockDetector::~COrderBlockDetector(void)
{
    Shutdown();
}

bool COrderBlockDetector::Init(void)
{
    if(m_isInitialized)
    {
        m_logger.LogWarn("OrderBlockDetector already initialized");
    }

    m_logger.LogInfo("Initializing OrderBlockDetector...");
    m_isInitialized = true;
    m_logger.LogInfo("OrderBlockDetector initialized");
    return true;
}

void COrderBlockDetector::Clear(void)
{
    m_orderBlockCount = 0;
    m_nextId = 1;
    m_lastProcessedCHOCHIndex = 0;
    m_stats.Reset();
}

void COrderBlockDetector::Update(CCHOCHDetector *chochDetector, CTrendState *trendState,
                                 CProtectedPointManager *protectedMgr,
                                 const double &open[], const double &high[], const double &low[],
                                 const double &close[], const datetime &time[], int rates_total)
{
    if(!m_isInitialized)
    {
        m_logger.LogWarn("Update called but OrderBlockDetector is not initialized");
        return;
    }

    if(chochDetector == NULL)
        return;

    int chochCount = chochDetector.GetCHOCHCount();
    if(chochCount <= m_lastProcessedCHOCHIndex)
        return;

    int newCHOCHs = chochCount - m_lastProcessedCHOCHIndex;
    m_logger.LogInfo(StringFormat("OB-STATS Update: totalCHOCHs=%d lastProcessed=%d new=%d",
        chochCount, m_lastProcessedCHOCHIndex, newCHOCHs));

    for(int i = m_lastProcessedCHOCHIndex; i < chochCount; i++)
    {
        CHOCHEvent choch;
        if(!chochDetector.GetCHOCH(i, choch))
            continue;

        m_stats.chochReceived++;
        ProcessNewCHOCH(choch, open, high, low, close, time, rates_total);
    }

    m_lastProcessedCHOCHIndex = chochCount;

    //--- Update lifecycle on existing OBs (mitigation, invalidation)
    UpdateLifecycle(trendState, close);
}

void COrderBlockDetector::ProcessNewCHOCH(const CHOCHEvent &choch,
                                          const double &open[], const double &high[], const double &low[],
                                          const double &close[], const datetime &time[], int rates_total)
{
    OrderBlock ob;
    m_stats.searchAttempted++;
    if(!FindOrderBlock(choch.bullish, open, high, low, close, time, rates_total, ob, choch.barIndex))
    {
        m_stats.searchFailed++;
        m_logger.LogInfo(StringFormat("OB-STATS CHOCH #%d (%s) -> FindOrderBlock FAILED",
            choch.id, choch.bullish ? "BULLISH" : "BEARISH"));
        return;
    }
    m_stats.searchSucceeded++;

    ob.id = m_nextId++;
    ob.chochID = choch.id;
    ob.bullish = choch.bullish;
    ob.mitigated = false;
    ob.invalidated = false;
    ob.qualityScore = 1.0;

    if(m_orderBlockCount >= ArraySize(m_orderBlocks))
    {
        int newSize = ArraySize(m_orderBlocks) + 256;
        ArrayResize(m_orderBlocks, newSize);
    }

    m_stats.storeAttempted++;
    m_orderBlocks[m_orderBlockCount] = ob;
    m_orderBlockCount++;
    m_stats.storeSucceeded++;

    string directionStr = ob.bullish ? "Bullish" : "Bearish";
    m_logger.LogInfo(StringFormat("Order Block Created\nID: %d\nCHOCH: %d\nDirection: %s\nTime: %s\nOpen: %.5f\nHigh: %.5f\nLow: %.5f\nClose: %.5f\nCandle Index: %d",
        ob.id, ob.chochID, directionStr,
        TimeToString(ob.time, TIME_DATE | TIME_MINUTES),
        ob.open, ob.high, ob.low, ob.close, ob.candleIndex));
}

void COrderBlockDetector::UpdateLifecycle(CTrendState *trendState, const double &close[])
{
    if(trendState == NULL || m_orderBlockCount == 0)
        return;

    Trend currentTrend = trendState.GetCurrentTrend();

    for(int i = 0; i < m_orderBlockCount; i++)
    {
        if(m_orderBlocks[i].invalidated)
            continue;

        //--- Check mitigation: last completed bar close entered the OB zone
        if(!m_orderBlocks[i].mitigated)
        {
            double lastClose = close[1];  // 0=newest (current), 1=last completed
            double obLow  = m_orderBlocks[i].low;
            double obHigh = m_orderBlocks[i].high;

            if(lastClose >= obLow && lastClose <= obHigh)
            {
                m_orderBlocks[i].mitigated = true;
                m_logger.LogInfo(StringFormat(
                    "OB #%d MITIGATED close=%.5f entered zone [%.5f, %.5f]",
                    m_orderBlocks[i].id, lastClose, obLow, obHigh));
            }
        }

        //--- Check invalidation: trend opposes OB direction
        if(!m_orderBlocks[i].mitigated)
        {
            bool trendOpposes = (m_orderBlocks[i].bullish && currentTrend == TREND_BEARISH) ||
                                (!m_orderBlocks[i].bullish && currentTrend == TREND_BULLISH);

            if(trendOpposes)
            {
                m_orderBlocks[i].invalidated = true;
                m_logger.LogInfo(StringFormat(
                    "OB #%d INVALIDATED (trend flip: OB=%s trend=%s)",
                    m_orderBlocks[i].id,
                    m_orderBlocks[i].bullish ? "BULLISH" : "BEARISH",
                    currentTrend == TREND_BULLISH ? "BULLISH" : "BEARISH"));
            }
        }
    }
}

bool COrderBlockDetector::FindOrderBlock(bool bullishCHOCH,
                                         const double &open[], const double &high[], const double &low[],
                                         const double &close[], const datetime &time[], int rates_total,
                                         OrderBlock &out, int displacementBarIndex)
{
    // ──── DIAGNOSTIC: Array Shape ────
    m_logger.LogInfo(StringFormat(
        "OB-SEARCH BEGIN\n"
        "displacementBarIndex=%d\n"
        "rates_total=%d\n"
        "Bars()=%d\n"
        "time[0]=%s\n"
        "time[1]=%s\n"
        "time[2]=%s\n"
        "time[3]=%s\n"
        "time[rates_total-4]=%s\n"
        "time[rates_total-3]=%s\n"
        "time[rates_total-2]=%s\n"
        "time[rates_total-1]=%s",
        displacementBarIndex,
        rates_total,
        Bars(_Symbol, _Period),
        TimeToString(time[0], TIME_DATE|TIME_MINUTES),
        TimeToString(time[1], TIME_DATE|TIME_MINUTES),
        TimeToString(time[2], TIME_DATE|TIME_MINUTES),
        TimeToString(time[3], TIME_DATE|TIME_MINUTES),
        TimeToString(time[rates_total-4], TIME_DATE|TIME_MINUTES),
        TimeToString(time[rates_total-3], TIME_DATE|TIME_MINUTES),
        TimeToString(time[rates_total-2], TIME_DATE|TIME_MINUTES),
        TimeToString(time[rates_total-1], TIME_DATE|TIME_MINUTES)));

    // ──── Search Bounds ────
    int rawMaxSearch = rates_total;
    int maxSearch = rates_total;
    if(maxSearch > displacementBarIndex + 500)
        maxSearch = displacementBarIndex + 500;

    int startIndex = displacementBarIndex + 1;

    m_logger.LogInfo(StringFormat(
        "OB-SEARCH BOUNDS\n"
        "rawMaxSearch=%d\n"
        "maxSearch=%d\n"
        "startIndex=%d\n"
        "500-bar limit applied: %s\n"
        "Candidate range: indices [%d..%d)\n"
        "Range time[%d]=%s  to  time[%d]=%s",
        rawMaxSearch,
        maxSearch,
        startIndex,
        (maxSearch < rawMaxSearch) ? "YES" : "NO",
        startIndex, maxSearch,
        startIndex, TimeToString(time[startIndex], TIME_DATE|TIME_MINUTES),
        maxSearch-1, TimeToString(time[maxSearch-1], TIME_DATE|TIME_MINUTES)));

    // ──── Search Loop ────
    for(int i = startIndex; i < maxSearch; i++)
    {
        // Validation: candle must have a valid body
        if(open[i] == close[i])
        {
            m_logger.LogInfo(StringFormat(
                "OB-CANDIDATE i=%d time=%s  SKIP (doji)",
                i, TimeToString(time[i], TIME_DATE|TIME_MINUTES)));
            continue;
        }

        bool isBullish = close[i] > open[i];
        bool isBearish = close[i] < open[i];
        bool accepted = false;
        string matchType = "";

        if(bullishCHOCH && isBearish)
        {
            accepted = true;
            matchType = "bullishCHOCH + bearish_candle";
        }
        else if(!bullishCHOCH && isBullish)
        {
            accepted = true;
            matchType = "bearishCHOCH + bullish_candle";
        }

        m_logger.LogInfo(StringFormat(
            "OB-CANDIDATE i=%d time=%s open=%.5f close=%.5f high=%.5f low=%.5f "
            "target=%s match=%s %s",
            i, TimeToString(time[i], TIME_DATE|TIME_MINUTES),
            open[i], close[i], high[i], low[i],
            bullishCHOCH ? "bearish" : "bullish",
            isBearish ? "bearish" : (isBullish ? "bullish" : "doji"),
            accepted ? "← ACCEPTED" : "rejected"));

        if(accepted)
        {
            out.time = time[i];
            out.open = open[i];
            out.high = high[i];
            out.low = low[i];
            out.close = close[i];
            out.candleIndex = i;

            m_logger.LogInfo(StringFormat(
                "OB-SEARCH RESULT\n"
                "SelectedIndex=%d\n"
                "SelectedTime=%s\n"
                "YearCheck: %s\n"
                "Index-is-in-series-array=%s\n"
                "Index-is-relative-to-history-start=%s",
                i,
                TimeToString(time[i], TIME_DATE|TIME_MINUTES),
                (time[i] < D'2026.01.01') ? "2025 (or earlier) ← CHECK" : "2026+ (OK)",
                "yes (0=newest bar)",
                "no (series: 0=newest, N=oldest)"));

            return true;
        }
    }

    m_logger.LogInfo("OB-SEARCH FAILED  no suitable candle found in range");
    return false;
}

void COrderBlockDetector::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down OrderBlockDetector...");

    m_logger.LogInfo("===================================");
    m_logger.LogInfo("ORDER BLOCK SUMMARY");
    m_logger.LogInfo("===================================");
    m_logger.LogInfo(StringFormat("CHOCH Received        : %d", m_stats.chochReceived));
    m_logger.LogInfo(StringFormat("Search Attempted      : %d", m_stats.searchAttempted));
    m_logger.LogInfo(StringFormat("Search Succeeded      : %d", m_stats.searchSucceeded));
    m_logger.LogInfo(StringFormat("Search Failed         : %d", m_stats.searchFailed));
    m_logger.LogInfo("-----------------------------------");
    m_logger.LogInfo(StringFormat("Store Attempted       : %d", m_stats.storeAttempted));
    m_logger.LogInfo(StringFormat("Store Success         : %d", m_stats.storeSucceeded));
    m_logger.LogInfo(StringFormat("Rejected Duplicate    : %d", m_stats.rejectedDuplicate));
    m_logger.LogInfo(StringFormat("Rejected Invalid      : %d", m_stats.rejectedInvalid));
    m_logger.LogInfo(StringFormat("Rejected Capacity     : %d", m_stats.rejectedCapacity));
    m_logger.LogInfo("===================================");
    m_logger.LogInfo(StringFormat("Order Blocks Total    : %d", m_orderBlockCount));
    m_logger.LogInfo("===================================");

    Clear();
    m_isInitialized = false;
    m_logger.LogInfo("OrderBlockDetector shutdown complete");
}

bool COrderBlockDetector::GetOrderBlock(int index, OrderBlock &out) const
{
    if(index < 0 || index >= m_orderBlockCount)
        return false;

    out = m_orderBlocks[index];
    return true;
}

#endif // __ORDER_BLOCK_DETECTOR_MQH__
