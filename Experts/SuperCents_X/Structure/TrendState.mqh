//+------------------------------------------------------------------+
//|                                                TrendState.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __TREND_STATE_MQH__
#define __TREND_STATE_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Core/Logger.mqh"
#include "BOSDetector.mqh"

//--- Trend State Machine
enum Trend
{
    TREND_UNKNOWN  = 0,
    TREND_BULLISH  = 1,
    TREND_BEARISH  = -1
};

class CTrendState
{
private:
    CLogger m_logger;
    bool m_isInitialized;
    
    Trend m_currentTrend;
    
    int m_lastProcessedBOSId;
    int m_bullishBOSCount;
    int m_bearishBOSCount;
    int m_trendFlipCount;

public:
    CTrendState(void);
    ~CTrendState(void);

    bool Init(void);
    void Update(CBOSDetector *bosDetector);
    void Shutdown(void);
    
    bool IsInitialized(void) const { return m_isInitialized; }
    Trend GetCurrentTrend(void) const { return m_currentTrend; }
    int GetBullishBOSCount(void) const { return m_bullishBOSCount; }
    int GetBearishBOSCount(void) const { return m_bearishBOSCount; }
    void ForceTrend(Trend newTrend);
};

//--- Inline implementation
CTrendState::CTrendState(void)
    : m_logger(MODULE_TREND_STATE, "TrendState")
    , m_isInitialized(false)
    , m_currentTrend(TREND_UNKNOWN)
    , m_lastProcessedBOSId(0)
    , m_bullishBOSCount(0)
    , m_bearishBOSCount(0)
    , m_trendFlipCount(0)
{
}

CTrendState::~CTrendState(void)
{
    Shutdown();
}

bool CTrendState::Init(void)
{
    if(m_isInitialized)
    {
        m_logger.LogWarn("TrendState already initialized, clearing state");
        m_currentTrend = TREND_UNKNOWN;
        m_lastProcessedBOSId = 0;
        m_bullishBOSCount = 0;
        m_bearishBOSCount = 0;
        m_trendFlipCount = 0;
    }

    m_logger.LogInfo("Initializing TrendState...");
    m_isInitialized = true;
    m_logger.LogInfo("TrendState initialized");
    return true;
}

void CTrendState::Update(CBOSDetector *bosDetector)
{
    if(!m_isInitialized)
    {
        m_logger.LogWarn("Update called but TrendState is not initialized");
        return;
    }

    if(bosDetector == NULL)
        return;

    int bosCount = bosDetector.GetBOSCount();
    if(bosCount == 0)
        return;

    // Process only new BOS events (deterministic, no reprocessing)
    for(int i = m_lastProcessedBOSId; i < bosCount; i++)
    {
        BOSEvent bos;
        if(!bosDetector.GetBOS(i, bos))
            continue;

        if(bos.bullish)
        {
            m_bullishBOSCount++;
            
            if(m_currentTrend == TREND_UNKNOWN)
            {
                m_currentTrend = TREND_BULLISH;
                m_logger.LogInfo(StringFormat("Trend set to BULLISH (first BOS ID: %d)", bos.id));
            }
            else if(m_currentTrend == TREND_BEARISH)
            {
                m_currentTrend = TREND_BULLISH;
                m_trendFlipCount++;
                m_logger.LogInfo(StringFormat("Trend flipped to BULLISH (BOS ID: %d)", bos.id));
            }
            // If already bullish, trend strengthens (no change)
        }
        else
        {
            m_bearishBOSCount++;
            
            if(m_currentTrend == TREND_UNKNOWN)
            {
                m_currentTrend = TREND_BEARISH;
                m_logger.LogInfo(StringFormat("Trend set to BEARISH (first BOS ID: %d)", bos.id));
            }
            else if(m_currentTrend == TREND_BULLISH)
            {
                m_currentTrend = TREND_BEARISH;
                m_trendFlipCount++;
                m_logger.LogInfo(StringFormat("Trend flipped to BEARISH (BOS ID: %d)", bos.id));
            }
            // If already bearish, trend strengthens (no change)
        }
    }

    m_lastProcessedBOSId = bosCount;
}

void CTrendState::ForceTrend(Trend newTrend)
{
    if(newTrend == m_currentTrend || newTrend == TREND_UNKNOWN)
        return;
    m_logger.LogInfo(StringFormat("Force-trend: %s -> %s",
        m_currentTrend == TREND_BULLISH ? "BULLISH" : (m_currentTrend == TREND_BEARISH ? "BEARISH" : "UNKNOWN"),
        newTrend == TREND_BULLISH ? "BULLISH" : "BEARISH"));
    m_currentTrend = newTrend;
    m_trendFlipCount++;
}

void CTrendState::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down TrendState...");
    
    // Print summary
    m_logger.LogInfo("========== TREND STATE SUMMARY ==========");
    m_logger.LogInfo(StringFormat("Current Trend         : %s", 
        m_currentTrend == TREND_BULLISH ? "BULLISH" : 
        (m_currentTrend == TREND_BEARISH ? "BEARISH" : "UNKNOWN")));
    m_logger.LogInfo(StringFormat("Total Bullish BOS     : %d", m_bullishBOSCount));
    m_logger.LogInfo(StringFormat("Total Bearish BOS     : %d", m_bearishBOSCount));
    m_logger.LogInfo(StringFormat("Trend Flips           : %d", m_trendFlipCount));
    m_logger.LogInfo("==========================================");
    
    m_isInitialized = false;
    m_logger.LogInfo("TrendState shutdown complete");
}

#endif // __TREND_STATE_MQH__