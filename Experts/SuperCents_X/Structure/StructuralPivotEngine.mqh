//+------------------------------------------------------------------+
//|                                    StructuralPivotEngine.mqh       |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __STRUCTURAL_PIVOT_ENGINE_MQH__
#define __STRUCTURAL_PIVOT_ENGINE_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Core/HistoryEpoch.mqh"
#include "SwingDetector.mqh"

//--- Sprint 3.5: Institutional Replacement Structural Pivot Engine
//--- Behaves like institutional market structure: the latest valid
//--- liquidity level (higher high / lower low) always replaces the
//--- previous same-type pivot until an opposite type locks it.
class CStructuralPivotEngine : public IHistoryResetConsumer
{
private:
    CLogger             m_logger;
    bool                m_isInitialized;

    //--- Structural pivot storage (chronological order: oldest -> newest)
    StructuralPivot     m_pivots[];
    int                 m_pivotCount;

    //--- State tracking
    int                 m_nextPivotId;
    int                 m_lastProcessedSwingId;   // highest swing ID consumed
    bool                m_lastPivotLocked;        // is the latest pivot locked?
    bool                m_lastPivotIsHigh;        // type of the latest pivot

public:
    CStructuralPivotEngine(void);
    ~CStructuralPivotEngine(void);

    //--- Lifecycle
    bool Init(void);
    void Update(CSwingDetector *swingDetector);
    void Shutdown(void);
    void Clear(void);

    //--- LC02: canonical history reset (HistoryEpoch broadcast). E11 fix:
    //--- the swing-id gate (m_lastProcessedSwingId) is reset together with
    //--- SwingDetector, so restarted swing ids are processed, not rejected.
    void OnHistoryReset(void) { Clear(); }

    //--- Queries
    bool IsInitialized(void) const { return m_isInitialized; }
    int  GetPivotCount(void) const { return m_pivotCount; }
    bool GetPivot(int index, StructuralPivot &out) const;
    bool GetPivotByID(int id, StructuralPivot &out) const;

private:
    //--- Internal processing
    void ProcessSwing(const SwingPoint &swing);
    void Promote(const SwingPoint &swing);
    void ReplaceLastPivot(const SwingPoint &swing);
    void LockLastPivot(void);

    //--- Replacement helpers (Sprint 3.5 API)
    bool CanReplace(bool isHigh) const;
    bool IsBetterHigh(double newPrice, double oldPrice) const;
    bool IsBetterLow(double newPrice, double oldPrice) const;
    bool IsBetter(const SwingPoint &swing, const StructuralPivot &pivot) const;
};

//--- Inline implementation
CStructuralPivotEngine::CStructuralPivotEngine(void)
    : m_logger(MODULE_TREND_STATE, "StructuralPivot")
    , m_isInitialized(false)
    , m_pivotCount(0)
    , m_nextPivotId(1)
    , m_lastProcessedSwingId(-1)
    , m_lastPivotLocked(false)
    , m_lastPivotIsHigh(false)
{
    ArrayResize(m_pivots, 256);
}

CStructuralPivotEngine::~CStructuralPivotEngine(void)
{
    Shutdown();
}

bool CStructuralPivotEngine::Init(void)
{
    if(m_isInitialized)
    {
        m_logger.LogWarn("StructuralPivotEngine already initialized, clearing state");
        Clear();
    }

    m_logger.LogInfo("Initializing StructuralPivotEngine...");
    Clear();

    m_isInitialized = true;
    m_logger.LogInfo("StructuralPivotEngine initialized");
    return true;
}

void CStructuralPivotEngine::Update(CSwingDetector *swingDetector)
{
    if(!m_isInitialized)
    {
        m_logger.LogWarn("Update called but StructuralPivotEngine is not initialized");
        return;
    }

    if(swingDetector == NULL)
        return;

    int highCount = swingDetector.GetSwingHighCount();
    int lowCount  = swingDetector.GetSwingLowCount();
    if(highCount == 0 && lowCount == 0)
        return;

    //--- Merge highs and lows in strict Swing ID (chronological) order.
    //--- IDs are globally unique and monotonically increasing, so a
    //--- two-pointer merge yields the exact detection sequence.
    SwingPoint h, l, s;
    int hi = 0, li = 0;

    while(hi < highCount || li < lowCount)
    {
        bool takeHigh;

        if(hi >= highCount)
            takeHigh = false;
        else if(li >= lowCount)
            takeHigh = true;
        else
        {
            swingDetector.GetSwingHigh(hi, h);
            swingDetector.GetSwingLow(li, l);
            takeHigh = (h.id < l.id);
        }

        if(takeHigh)
        {
            swingDetector.GetSwingHigh(hi, s);
            hi++;
        }
        else
        {
            swingDetector.GetSwingLow(li, s);
            li++;
        }

        //--- Only process new swings (deterministic, no reprocessing)
        if(s.id > m_lastProcessedSwingId)
            ProcessSwing(s);
    }
}

void CStructuralPivotEngine::ProcessSwing(const SwingPoint &swing)
{
    if(m_pivotCount == 0)
    {
        //--- Rule 1: First valid swing becomes a Structural Pivot
        Promote(swing);
        return;
    }

    int lastIdx = m_pivotCount - 1;

    if(swing.isHigh != m_pivots[lastIdx].isHigh)
    {
        //--- Rule 2 / State machine: opposite type promotes normally,
        //--- and locks the previous pivot (which becomes immutable).
        LockLastPivot();
        Promote(swing);
    }
    else
    {
        //--- Rule 3 & 4: Same type before an opposite pivot arrives.
        //--- Replace only if newer swing is stronger (higher high / lower low)
        //--- and the current pivot is still unlocked.
        if(CanReplace(swing.isHigh) && IsBetter(swing, m_pivots[lastIdx]))
        {
            ReplaceLastPivot(swing);
        }
        //--- Otherwise ignore (no promotion, no replacement).
    }
}

void CStructuralPivotEngine::Promote(const SwingPoint &swing)
{
    if(m_pivotCount >= ArraySize(m_pivots))
        ArrayResize(m_pivots, ArraySize(m_pivots) + 256);

    StructuralPivot pivot;
    pivot.id        = m_nextPivotId++;
    pivot.swingID   = swing.id;
    pivot.time      = swing.time;
    pivot.price     = swing.price;
    pivot.barIndex  = swing.barIndex;
    pivot.isHigh    = swing.isHigh;
    pivot.isProtected = false;  // Sprint 4+
    pivot.isBroken  = false;    // Sprint 4+

    m_pivots[m_pivotCount] = pivot;
    m_pivotCount++;

    m_lastProcessedSwingId = swing.id;
    m_lastPivotLocked      = false;
    m_lastPivotIsHigh      = swing.isHigh;

    string typeStr = swing.isHigh ? "HIGH" : "LOW";
    string msg = StringFormat("Pivot Promoted\nPivot ID : %d\nSwing ID : %d\nType : %s\nBar : %d\nTime : %s\nPrice : %.5f",
                              pivot.id, pivot.swingID, typeStr, pivot.barIndex,
                              TimeToString(pivot.time, TIME_DATE | TIME_MINUTES), pivot.price);
    m_logger.LogInfo(msg);
}

void CStructuralPivotEngine::ReplaceLastPivot(const SwingPoint &swing)
{
    int idx = m_pivotCount - 1;
    StructuralPivot p = m_pivots[idx];

    int    oldSwing = p.swingID;
    double oldPrice = p.price;

    //--- Rule 5: ID never changes. Only latest unlocked pivot mutates.
    p.swingID   = swing.id;
    p.time      = swing.time;
    p.price     = swing.price;
    p.barIndex  = swing.barIndex;
    // isHigh, isProtected, isBroken remain unchanged

    m_pivots[idx] = p;

    m_lastProcessedSwingId = swing.id;
    // still unlocked, still same type

    string typeStr = swing.isHigh ? "HIGH" : "LOW";
    string msg = StringFormat("Pivot Replaced\nPivot ID : %d\nOld Swing : %d\nNew Swing : %d\nOld Price : %.5f\nNew Price : %.5f",
                              p.id, oldSwing, p.swingID, oldPrice, p.price);
    m_logger.LogInfo(msg);
}

void CStructuralPivotEngine::LockLastPivot(void)
{
    if(m_pivotCount == 0)
        return;

    m_lastPivotLocked = true;

    int idx = m_pivotCount - 1;
    StructuralPivot p = m_pivots[idx];
    p.isProtected = true;  // Mark pivot as locked
    m_pivots[idx] = p;

    string typeStr = p.isHigh ? "HIGH" : "LOW";
    string msg = StringFormat("Pivot Locked\nPivot ID : %d\nSwing ID : %d\nType : %s\nBar : %d\nTime : %s\nPrice : %.5f",
                            p.id, p.swingID, typeStr, p.barIndex,
                            TimeToString(p.time, TIME_DATE | TIME_MINUTES), p.price);
    m_logger.LogInfo(msg);
}

void CStructuralPivotEngine::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down StructuralPivotEngine...");
    Clear();
    m_isInitialized = false;
    m_logger.LogInfo("StructuralPivotEngine shutdown complete");
}

void CStructuralPivotEngine::Clear(void)
{
    m_pivotCount = 0;
    m_nextPivotId = 1;
    m_lastProcessedSwingId = -1;
    m_lastPivotLocked = false;
    m_lastPivotIsHigh = false;
}

//--- Sprint 3.5 API helpers
bool CStructuralPivotEngine::CanReplace(bool isHigh) const
{
    //--- Can only replace the latest unlocked pivot of the SAME type.
    if(m_pivotCount == 0)
        return false;
    if(m_lastPivotLocked)
        return false;
    return isHigh == m_lastPivotIsHigh;
}

bool CStructuralPivotEngine::IsBetterHigh(double newPrice, double oldPrice) const
{
    return newPrice > oldPrice;
}

bool CStructuralPivotEngine::IsBetterLow(double newPrice, double oldPrice) const
{
    return newPrice < oldPrice;
}

bool CStructuralPivotEngine::IsBetter(const SwingPoint &swing, const StructuralPivot &pivot) const
{
    if(swing.isHigh)
        return IsBetterHigh(swing.price, pivot.price);
    return IsBetterLow(swing.price, pivot.price);
}

bool CStructuralPivotEngine::GetPivot(int index, StructuralPivot &out) const
{
    if(index < 0 || index >= m_pivotCount)
        return false;

    out = m_pivots[index];
    return true;
}

bool CStructuralPivotEngine::GetPivotByID(int id, StructuralPivot &out) const
{
    for(int i = 0; i < m_pivotCount; i++)
    {
        if(m_pivots[i].id == id)
        {
            out = m_pivots[i];
            return true;
        }
    }
    return false;
}

#endif // __STRUCTURAL_PIVOT_ENGINE_MQH__