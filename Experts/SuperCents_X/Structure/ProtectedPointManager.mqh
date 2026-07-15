//+------------------------------------------------------------------+
//|                                         ProtectedPointManager.mqh |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __PROTECTED_POINT_MANAGER_MQH__
#define __PROTECTED_POINT_MANAGER_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Core/Logger.mqh"
#include "StructuralPivotEngine.mqh"
#include "BOSDetector.mqh"
#include "TrendState.mqh"

//--- Sprint 6: Protected Point Manager
//--- Tracks protected highs/lows for CHOCH detection

class CProtectedPointManager
{
private:
    CLogger m_logger;
    bool m_isInitialized;
    
    // Protected point storage
    ProtectedPoint m_protectedPoints[];
    int m_pointCount;
    int m_nextPointId;
    
    // Active points
    int m_activeHighId;
    int m_activeLowId;
    
    // Previous state
    Trend m_lastTrend;
    int m_lastProcessedBOSId;

public:
    CProtectedPointManager(void);
    ~CProtectedPointManager(void);

    bool Init(void);
    void Update(CStructuralPivotEngine *pivotEngine, CBOSDetector *bosDetector, CTrendState *trendState, const datetime &time[]);
    void Shutdown(void);
    
    bool IsInitialized(void) const { return m_isInitialized; }
    int GetProtectedPointCount(void) const { return m_pointCount; }
    bool GetProtectedPoint(int index, ProtectedPoint &out) const;

    // Query active points
    bool GetActiveHigh(ProtectedPoint &out) const;
    bool GetActiveLow(ProtectedPoint &out) const;

private:
    void ProcessCurrentTrend(CStructuralPivotEngine *pivotEngine, Trend trend, datetime currentBarTime);
    void FindLatestLockedPivot(CStructuralPivotEngine *pivotEngine, bool isHigh, int &pivotId, ProtectedPoint &buffer);
};

//--- Inline implementation
CProtectedPointManager::CProtectedPointManager(void)
    : m_logger(MODULE_TREND_STATE, "ProtectedPoint")
    , m_isInitialized(false)
    , m_pointCount(0)
    , m_nextPointId(1)
    , m_activeHighId(-1)
    , m_activeLowId(-1)
    , m_lastTrend(TREND_UNKNOWN)
    , m_lastProcessedBOSId(0)
{
    ArrayResize(m_protectedPoints, 256);
}

CProtectedPointManager::~CProtectedPointManager(void)
{
    Shutdown();
}

bool CProtectedPointManager::Init(void)
{
    if(m_isInitialized)
    {
        m_logger.LogWarn("ProtectedPointManager already initialized");
    }

    m_logger.LogInfo("Initializing ProtectedPointManager...");
    m_isInitialized = true;
    m_logger.LogInfo("ProtectedPointManager initialized");
    return true;
}

void CProtectedPointManager::Update(CStructuralPivotEngine *pivotEngine, CBOSDetector *bosDetector, CTrendState *trendState, const datetime &time[])
{
    if(!m_isInitialized)
    {
        m_logger.LogWarn("Update called but ProtectedPointManager is not initialized");
        return;
    }

    if(pivotEngine == NULL || trendState == NULL)
        return;

    Trend currentTrend = trendState.GetCurrentTrend();

    // Process new trend
    if(currentTrend != m_lastTrend)
    {
        ProcessCurrentTrend(pivotEngine, currentTrend, time[0]);
        m_lastTrend = currentTrend;
    }
}

void CProtectedPointManager::ProcessCurrentTrend(CStructuralPivotEngine *pivotEngine, Trend trend, datetime currentBarTime)
{
    ProtectedPoint buffer;
    int pivotId = -1;

    if(trend == TREND_BULLISH)
    {
        // Find latest locked LOW for protected low
        FindLatestLockedPivot(pivotEngine, false, pivotId, buffer);
        
        if(pivotId >= 0)
        {
            // Deactivate old protected high
            if(m_activeHighId >= 0 && m_activeHighId < m_pointCount)
            {
                m_protectedPoints[m_activeHighId].active = false;
            }
            
            // Check if this is a new protected low
            if(m_activeLowId < 0 || m_protectedPoints[m_activeLowId].pivotID != pivotId)
            {
                // Deactivate old protected low
                if(m_activeLowId >= 0 && m_activeLowId < m_pointCount)
                {
                    m_protectedPoints[m_activeLowId].active = false;
                }
                
                // Add or activate the protected low
                if(m_pointCount >= ArraySize(m_protectedPoints))
                {
                    int newSize = ArraySize(m_protectedPoints) + 256;
                    ArrayResize(m_protectedPoints, newSize);
                }
                
                m_protectedPoints[m_pointCount].id = m_nextPointId++;
                m_protectedPoints[m_pointCount].pivotID = pivotId;
                m_protectedPoints[m_pointCount].isHigh = false;
                m_protectedPoints[m_pointCount].time = buffer.time;
                m_protectedPoints[m_pointCount].price = buffer.price;
                m_protectedPoints[m_pointCount].barIndex = buffer.barIndex;
                m_protectedPoints[m_pointCount].activationTime = currentBarTime;  // Set activation time
                m_protectedPoints[m_pointCount].active = true;
                m_activeLowId = m_pointCount;
                m_pointCount++;

                m_logger.LogInfo(StringFormat("Protected Low Activated\nID: %d\nPivot: %d\nPrice: %.5f\nTime: %s\nActivation: %s",
                    m_protectedPoints[m_activeLowId].id, 
                    m_protectedPoints[m_activeLowId].pivotID,
                    m_protectedPoints[m_activeLowId].price,
                    TimeToString(m_protectedPoints[m_activeLowId].time, TIME_DATE | TIME_MINUTES),
                    TimeToString(m_protectedPoints[m_activeLowId].activationTime, TIME_DATE | TIME_MINUTES)));
            }
        }
    }
    else if(trend == TREND_BEARISH)
    {
        // Find latest locked HIGH for protected high
        FindLatestLockedPivot(pivotEngine, true, pivotId, buffer);
        
        if(pivotId >= 0)
        {
            // Deactivate old protected low
            if(m_activeLowId >= 0 && m_activeLowId < m_pointCount)
            {
                m_protectedPoints[m_activeLowId].active = false;
            }
            
            // Check if this is a new protected high
            if(m_activeHighId < 0 || m_protectedPoints[m_activeHighId].pivotID != pivotId)
            {
                // Deactivate old protected high
                if(m_activeHighId >= 0 && m_activeHighId < m_pointCount)
                {
                    m_protectedPoints[m_activeHighId].active = false;
                }
                
                // Add or activate the protected high
                if(m_pointCount >= ArraySize(m_protectedPoints))
                {
                    int newSize = ArraySize(m_protectedPoints) + 256;
                    ArrayResize(m_protectedPoints, newSize);
                }
                
                m_protectedPoints[m_pointCount].id = m_nextPointId++;
                m_protectedPoints[m_pointCount].pivotID = pivotId;
                m_protectedPoints[m_pointCount].isHigh = true;
                m_protectedPoints[m_pointCount].time = buffer.time;
                m_protectedPoints[m_pointCount].price = buffer.price;
                m_protectedPoints[m_pointCount].barIndex = buffer.barIndex;
                m_protectedPoints[m_pointCount].activationTime = currentBarTime;  // Set activation time
                m_protectedPoints[m_pointCount].active = true;
                m_activeHighId = m_pointCount;
                m_pointCount++;

                m_logger.LogInfo(StringFormat("Protected High Activated\nID: %d\nPivot: %d\nPrice: %.5f\nTime: %s\nActivation: %s",
                    m_protectedPoints[m_activeHighId].id, 
                    m_protectedPoints[m_activeHighId].pivotID,
                    m_protectedPoints[m_activeHighId].price,
                    TimeToString(m_protectedPoints[m_activeHighId].time, TIME_DATE | TIME_MINUTES),
                    TimeToString(m_protectedPoints[m_activeHighId].activationTime, TIME_DATE | TIME_MINUTES)));
            }
        }
    }
}

void CProtectedPointManager::FindLatestLockedPivot(CStructuralPivotEngine *pivotEngine, bool isHigh, int &pivotId, ProtectedPoint &buffer)
{
    pivotId = -1;
    buffer.id = -1;
    
    int pivotCount = pivotEngine.GetPivotCount();
    StructuralPivot p;
    
    // Find latest locked pivot of specified type
    for(int i = pivotCount - 1; i >= 0; i--)
    {
        if(!pivotEngine.GetPivot(i, p))
            continue;
            
        if(p.isHigh == isHigh && p.isProtected)
        {
            pivotId = p.id;
            buffer.time = p.time;
            buffer.price = p.price;
            buffer.barIndex = p.barIndex;
            break;
        }
    }
}

void CProtectedPointManager::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down ProtectedPointManager...");
    
    m_logger.LogInfo(StringFormat("Protected Points Total: %d", m_pointCount));
    m_logger.LogInfo(StringFormat("Active High: %d", m_activeHighId >= 0 ? m_protectedPoints[m_activeHighId].pivotID : -1));
    m_logger.LogInfo(StringFormat("Active Low: %d", m_activeLowId >= 0 ? m_protectedPoints[m_activeLowId].pivotID : -1));
    
    m_pointCount = 0;
    m_isInitialized = false;
    m_logger.LogInfo("ProtectedPointManager shutdown complete");
}

bool CProtectedPointManager::GetProtectedPoint(int index, ProtectedPoint &out) const
{
    if(index < 0 || index >= m_pointCount)
        return false;
        
    out = m_protectedPoints[index];
    return true;
}

bool CProtectedPointManager::GetActiveHigh(ProtectedPoint &out) const
{
    if(m_activeHighId < 0 || m_activeHighId >= m_pointCount)
        return false;
        
    out = m_protectedPoints[m_activeHighId];
    return true;
}

bool CProtectedPointManager::GetActiveLow(ProtectedPoint &out) const
{
    if(m_activeLowId < 0 || m_activeLowId >= m_pointCount)
        return false;
        
    out = m_protectedPoints[m_activeLowId];
    return true;
}

#endif // __PROTECTED_POINT_MANAGER_MQH__