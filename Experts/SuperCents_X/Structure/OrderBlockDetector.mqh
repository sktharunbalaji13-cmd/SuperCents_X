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
#include "CHOCHDetector.mqh"
#include "TrendState.mqh"
#include "ProtectedPointManager.mqh"

class COrderBlockDetector
{
private:
    CLogger m_logger;
    bool m_isInitialized;

    OrderBlock m_orderBlocks[];
    int m_orderBlockCount;
    int m_nextId;
    int m_lastProcessedCHOCHIndex;

public:
    COrderBlockDetector(void);
    ~COrderBlockDetector(void);

    bool Init(void);
    void Update(CCHOCHDetector *chochDetector, CTrendState *trendState,
                CProtectedPointManager *protectedMgr,
                const double &open[], const double &high[], const double &low[],
                const double &close[], const datetime &time[], int rates_total);
    void Shutdown(void);

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
                       OrderBlock &out);
};

COrderBlockDetector::COrderBlockDetector(void)
    : m_logger(MODULE_ORDER_BLOCK_DETECTOR, "OrderBlock")
    , m_isInitialized(false)
    , m_orderBlockCount(0)
    , m_nextId(1)
    , m_lastProcessedCHOCHIndex(0)
{
    ArrayResize(m_orderBlocks, 256);
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

    for(int i = m_lastProcessedCHOCHIndex; i < chochCount; i++)
    {
        CHOCHEvent choch;
        if(!chochDetector.GetCHOCH(i, choch))
            continue;

        ProcessNewCHOCH(choch, open, high, low, close, time, rates_total);
    }

    m_lastProcessedCHOCHIndex = chochCount;
}

void COrderBlockDetector::ProcessNewCHOCH(const CHOCHEvent &choch,
                                          const double &open[], const double &high[], const double &low[],
                                          const double &close[], const datetime &time[], int rates_total)
{
    OrderBlock ob;
    if(!FindOrderBlock(choch.bullish, open, high, low, close, time, rates_total, ob))
        return;

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

    m_orderBlocks[m_orderBlockCount] = ob;
    m_orderBlockCount++;

    string directionStr = ob.bullish ? "Bullish" : "Bearish";
    m_logger.LogInfo(StringFormat("Order Block Created\nID: %d\nCHOCH: %d\nDirection: %s\nTime: %s\nOpen: %.5f\nHigh: %.5f\nLow: %.5f\nClose: %.5f\nCandle Index: %d",
        ob.id, ob.chochID, directionStr,
        TimeToString(ob.time, TIME_DATE | TIME_MINUTES),
        ob.open, ob.high, ob.low, ob.close, ob.candleIndex));
}

bool COrderBlockDetector::FindOrderBlock(bool bullishCHOCH,
                                         const double &open[], const double &high[], const double &low[],
                                         const double &close[], const datetime &time[], int rates_total,
                                         OrderBlock &out)
{
    int maxSearch = rates_total;
    if(maxSearch > 500)
        maxSearch = 500;

    // Start from index 1 (the bar immediately before the displacement at index 0)
    for(int i = 1; i < maxSearch; i++)
    {
        // Validation: candle must have a valid body
        if(open[i] == close[i])
            continue;

        bool isBullish = close[i] > open[i];
        bool isBearish = close[i] < open[i];

        // Bullish CHOCH -> find LAST bearish candle before displacement
        // Bearish CHOCH -> find LAST bullish candle before displacement
        if(bullishCHOCH && isBearish)
        {
            out.time = time[i];
            out.open = open[i];
            out.high = high[i];
            out.low = low[i];
            out.close = close[i];
            out.candleIndex = i;
            return true;
        }

        if(!bullishCHOCH && isBullish)
        {
            out.time = time[i];
            out.open = open[i];
            out.high = high[i];
            out.low = low[i];
            out.close = close[i];
            out.candleIndex = i;
            return true;
        }
    }

    return false;
}

void COrderBlockDetector::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down OrderBlockDetector...");

    m_logger.LogInfo(StringFormat("Order Blocks Total: %d", m_orderBlockCount));

    m_orderBlockCount = 0;
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
