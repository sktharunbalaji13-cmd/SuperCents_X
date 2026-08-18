//+------------------------------------------------------------------+
//|                                         LiquidityDetector.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//+------------------------------------------------------------------+
#ifndef __LIQUIDITY_DETECTOR_MQH__
#define __LIQUIDITY_DETECTOR_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Core/Logger.mqh"
#include "../Core/HistoryEpoch.mqh"

class CSwingDetector;
class CBOSDetector;

class CLiquidityDetector : public IHistoryResetConsumer
{
private:
    bool m_initialized;
    int m_nextId;
    LiquidityLevel m_levels[];
    int m_levelCount;

    CSwingDetector  *m_swingDetector;
    CBOSDetector    *m_bosDetector;

    int m_lastSwingHighId;
    int m_lastSwingLowId;
    int m_lastBOSId;
    int m_lastInvalidationBOSId;
    bool m_invalidationSeeded;

    CLogger m_logger;

    // Sweep stats
    int m_eqhSwept;
    int m_eqlSwept;
    int m_extHhSwept;
    int m_extLlSwept;
    int m_sweepDelayTotal;
    int m_sweepDelayMax;

    // Mitigation stats
    int m_eqhMitigated;
    int m_eqlMitigated;
    int m_extHhMitigated;
    int m_extLlMitigated;

    int FindLevelById(int id) const;
    int FindMatchingEQH(double price) const;
    int FindMatchingEQL(double price) const;
    void DetectEQH(void);
    void DetectEQL(void);
    void DetectExternal(void);
    void DetectSweeps(const double &high[], const double &low[], const double &close[],
                      const datetime &time[], int rates_total);
    void DetectMitigations(const double &high[], const double &low[],
                           const datetime &time[], int rates_total);
    void DetectInvalidations(const datetime &time[], int rates_total);

public:
    CLiquidityDetector(void);
    ~CLiquidityDetector(void);

    bool Init(void);
    void Update(const double &high[], const double &low[], const double &close[],
                const datetime &time[], int rates_total);
    void Shutdown(void);
    void Clear(void);

    //--- LC02: canonical history reset (HistoryEpoch broadcast). E11 fix:
    //--- the monotonic swing/BOS count cursors are reset so levels are
    //--- re-derived from the rebuilt swing/BOS state.
    void OnHistoryReset(void) { Clear(); }

    bool IsInitialized(void) const { return m_initialized; }
    int GetLevelCount(void) const { return m_levelCount; }
    bool GetLevel(int index, LiquidityLevel &out) const;

    void SetSwingDetector(CSwingDetector *sd) { m_swingDetector = sd; }
    void SetBOSDetector(CBOSDetector *bd) { m_bosDetector = bd; }

    int CreateLevel(LiquidityType type, double price, LiquidityOrigin origin,
                    int leftSwing, int rightSwing, int barIndex = -1,
                    datetime leftTime = 0, datetime rightTime = 0);
    bool SweepLevel(int id, int bar = -1, datetime sweepTime = 0);
    bool MitigateLevel(int id, int bar = -1, double price = 0.0, datetime mitigateTime = 0);
    bool InvalidateLevel(int id, string reason = "", int bar = -1, double price = 0.0, datetime invalidateTime = 0);
};

CLiquidityDetector::CLiquidityDetector(void)
    : m_initialized(false), m_nextId(0), m_levelCount(0),
      m_swingDetector(NULL), m_bosDetector(NULL),
      m_lastSwingHighId(0), m_lastSwingLowId(0), m_lastBOSId(0), m_lastInvalidationBOSId(0), m_invalidationSeeded(false),
      m_eqhSwept(0), m_eqlSwept(0), m_extHhSwept(0), m_extLlSwept(0),
      m_sweepDelayTotal(0), m_sweepDelayMax(0),
      m_eqhMitigated(0), m_eqlMitigated(0), m_extHhMitigated(0), m_extLlMitigated(0),
      m_logger(MODULE_LIQUIDITY_DETECTOR, "Liquidity")
{
}

CLiquidityDetector::~CLiquidityDetector(void)
{
    Shutdown();
}

bool CLiquidityDetector::Init(void)
{
    m_logger.LogInfo("Initializing Liquidity Detector...");
    Clear();
    m_initialized = true;
    m_logger.LogInfo("Liquidity Detector initialized");
    return true;
}

void CLiquidityDetector::Clear(void)
{
    m_nextId = 0;
    m_levelCount = 0;
    m_lastSwingHighId = 0;
    m_lastSwingLowId = 0;
    m_lastBOSId = 0;
    m_lastInvalidationBOSId = 0;
    m_invalidationSeeded = false;
    m_eqhSwept = 0;
    m_eqlSwept = 0;
    m_extHhSwept = 0;
    m_extLlSwept = 0;
    m_sweepDelayTotal = 0;
    m_sweepDelayMax = 0;
    m_eqhMitigated = 0;
    m_eqlMitigated = 0;
    m_extHhMitigated = 0;
    m_extLlMitigated = 0;
    ArrayResize(m_levels, 0);
}

void CLiquidityDetector::Update(const double &high[], const double &low[], const double &close[],
                                 const datetime &time[], int rates_total)
{
    if(!m_initialized)
        return;

    DetectEQH();
    DetectEQL();
    DetectExternal();

    //--- Sprint 12.3: Sweep detection
    DetectSweeps(high, low, close, time, rates_total);

    //--- Sprint 12.4: Mitigation detection (revisit of swept levels)
    DetectMitigations(high, low, time, rates_total);

    //--- Sprint 12.4: Invalidation detection (opposing BOS after sweep)
    DetectInvalidations(time, rates_total);
}

void CLiquidityDetector::DetectEQH(void)
{
    if(m_swingDetector == NULL)
        return;

    int highCount = m_swingDetector.GetSwingHighCount();
    if(highCount <= m_lastSwingHighId)
        return;

    const double eps = _Point * 0.5;
    const double tolerance = LIQUIDITY_EQH_TOLERANCE_PIPS * _Point * 10 + eps;

    for(int i = m_lastSwingHighId; i < highCount; i++)
    {
        SwingPoint sp;
        if(!m_swingDetector.GetSwingHigh(i, sp))
            continue;

        double diff = 0.0;

        // 1. Try to extend an existing ACTIVE EQH cluster
        int existingIdx = FindMatchingEQH(sp.price);
        if(existingIdx >= 0)
        {
            diff = MathAbs(sp.price - m_levels[existingIdx].averagePrice);

            double total = m_levels[existingIdx].averagePrice * m_levels[existingIdx].memberCount + sp.price;
            m_levels[existingIdx].memberCount++;
            m_levels[existingIdx].averagePrice = total / m_levels[existingIdx].memberCount;
            m_levels[existingIdx].rightSwingId = sp.id;
            m_levels[existingIdx].rightTime = sp.time;
            m_levels[existingIdx].memberIdStr += "," + IntegerToString(sp.id);

            m_logger.LogInfo(StringFormat(
                "LIQUIDITY-DETECT CANDIDATE=EQH ACCEPTED=TRUE MERGE=TRUE "
                "SWING=%d PRICE=%.5f CLUSTER=%d MEMBERS=%d AVG=%.5f DIFF=%.1f TOLERANCE=%d",
                sp.id, sp.price, m_levels[existingIdx].id, m_levels[existingIdx].memberCount,
                m_levels[existingIdx].averagePrice, diff / (_Point * 10), LIQUIDITY_EQH_TOLERANCE_PIPS));
            continue;
        }

        // 2. Search for a matching swing high to form a NEW EQH
        bool foundPartner = false;
        for(int j = i - 1; j >= MathMax(0, i - 100); j--)
        {
            SwingPoint partner;
            if(!m_swingDetector.GetSwingHigh(j, partner))
                continue;

            diff = MathAbs(sp.price - partner.price);
            if(diff <= tolerance)
            {
                int newId = CreateLevel(LIQUIDITY_EQH, (sp.price + partner.price) / 2.0,
                                        LIQUIDITY_ORIGIN_EQH, partner.id, sp.id,
                                        partner.barIndex, partner.time, sp.time);

                if(newId >= 0)
                {
                    int idx = FindLevelById(newId);
                    if(idx >= 0)
                    {
                        m_levels[idx].memberCount = 2;
                        m_levels[idx].memberIdStr = IntegerToString(partner.id) + "," + IntegerToString(sp.id);
                    }
                }

                m_logger.LogInfo(StringFormat(
                    "LIQUIDITY-DETECT CANDIDATE=EQH ACCEPTED=TRUE MERGE=FALSE "
                    "SWING_A=%d PRICE_A=%.5f SWING_B=%d PRICE_B=%.5f DIFF=%.1f TOLERANCE=%d",
                    partner.id, partner.price, sp.id, sp.price,
                    diff / (_Point * 10), LIQUIDITY_EQH_TOLERANCE_PIPS));

                foundPartner = true;
                break;
            }
        }

        if(!foundPartner)
        {
            // Find closest swing for rejection detail
            double closestDiff = 1e10;
            int closestId = -1;
            double closestPrice = 0;
            for(int j = i - 1; j >= MathMax(0, i - 100); j--)
            {
                SwingPoint partner;
                if(!m_swingDetector.GetSwingHigh(j, partner))
                    continue;
                double d = MathAbs(sp.price - partner.price);
                if(d < closestDiff)
                {
                    closestDiff = d;
                    closestId = partner.id;
                    closestPrice = partner.price;
                }
            }

            m_logger.LogInfo(StringFormat(
                "LIQUIDITY-REJECT CANDIDATE=EQH SWING=%d PRICE=%.5f "
                "CLOSEST=%d CLOSEST_PRICE=%.5f CLOSEST_DIFF=%.1f TOLERANCE=%d REASON=NoMatchingSwing",
                sp.id, sp.price, closestId, closestPrice,
                closestDiff / (_Point * 10), LIQUIDITY_EQH_TOLERANCE_PIPS));
        }
    }

    m_lastSwingHighId = highCount;
}

void CLiquidityDetector::DetectEQL(void)
{
    if(m_swingDetector == NULL)
        return;

    int lowCount = m_swingDetector.GetSwingLowCount();
    if(lowCount <= m_lastSwingLowId)
        return;

    const double eps = _Point * 0.5;
    const double tolerance = LIQUIDITY_EQL_TOLERANCE_PIPS * _Point * 10 + eps;

    for(int i = m_lastSwingLowId; i < lowCount; i++)
    {
        SwingPoint sp;
        if(!m_swingDetector.GetSwingLow(i, sp))
            continue;

        double diff = 0.0;

        int existingIdx = FindMatchingEQL(sp.price);
        if(existingIdx >= 0)
        {
            diff = MathAbs(sp.price - m_levels[existingIdx].averagePrice);

            double total = m_levels[existingIdx].averagePrice * m_levels[existingIdx].memberCount + sp.price;
            m_levels[existingIdx].memberCount++;
            m_levels[existingIdx].averagePrice = total / m_levels[existingIdx].memberCount;
            m_levels[existingIdx].rightSwingId = sp.id;
            m_levels[existingIdx].rightTime = sp.time;
            m_levels[existingIdx].memberIdStr += "," + IntegerToString(sp.id);

            m_logger.LogInfo(StringFormat(
                "LIQUIDITY-DETECT CANDIDATE=EQL ACCEPTED=TRUE MERGE=TRUE "
                "SWING=%d PRICE=%.5f CLUSTER=%d MEMBERS=%d AVG=%.5f DIFF=%.1f TOLERANCE=%d",
                sp.id, sp.price, m_levels[existingIdx].id, m_levels[existingIdx].memberCount,
                m_levels[existingIdx].averagePrice, diff / (_Point * 10), LIQUIDITY_EQL_TOLERANCE_PIPS));
            continue;
        }

        bool foundPartner = false;
        for(int j = i - 1; j >= MathMax(0, i - 100); j--)
        {
            SwingPoint partner;
            if(!m_swingDetector.GetSwingLow(j, partner))
                continue;

            diff = MathAbs(sp.price - partner.price);
            if(diff <= tolerance)
            {
                int newId = CreateLevel(LIQUIDITY_EQL, (sp.price + partner.price) / 2.0,
                                        LIQUIDITY_ORIGIN_EQL, partner.id, sp.id,
                                        partner.barIndex, partner.time, sp.time);

                if(newId >= 0)
                {
                    int idx = FindLevelById(newId);
                    if(idx >= 0)
                    {
                        m_levels[idx].memberCount = 2;
                        m_levels[idx].memberIdStr = IntegerToString(partner.id) + "," + IntegerToString(sp.id);
                    }
                }

                m_logger.LogInfo(StringFormat(
                    "LIQUIDITY-DETECT CANDIDATE=EQL ACCEPTED=TRUE MERGE=FALSE "
                    "SWING_A=%d PRICE_A=%.5f SWING_B=%d PRICE_B=%.5f DIFF=%.1f TOLERANCE=%d",
                    partner.id, partner.price, sp.id, sp.price,
                    diff / (_Point * 10), LIQUIDITY_EQL_TOLERANCE_PIPS));

                foundPartner = true;
                break;
            }
        }

        if(!foundPartner)
        {
            double closestDiff = 1e10;
            int closestId = -1;
            double closestPrice = 0;
            for(int j = i - 1; j >= MathMax(0, i - 100); j--)
            {
                SwingPoint partner;
                if(!m_swingDetector.GetSwingLow(j, partner))
                    continue;
                double d = MathAbs(sp.price - partner.price);
                if(d < closestDiff)
                {
                    closestDiff = d;
                    closestId = partner.id;
                    closestPrice = partner.price;
                }
            }

            m_logger.LogInfo(StringFormat(
                "LIQUIDITY-REJECT CANDIDATE=EQL SWING=%d PRICE=%.5f "
                "CLOSEST=%d CLOSEST_PRICE=%.5f CLOSEST_DIFF=%.1f TOLERANCE=%d REASON=NoMatchingSwing",
                sp.id, sp.price, closestId, closestPrice,
                closestDiff / (_Point * 10), LIQUIDITY_EQL_TOLERANCE_PIPS));
        }
    }

    m_lastSwingLowId = lowCount;
}

void CLiquidityDetector::DetectExternal(void)
{
    if(m_bosDetector == NULL)
        return;

    int bosCount = m_bosDetector.GetBOSCount();
    if(bosCount <= m_lastBOSId)
        return;

    for(int i = m_lastBOSId; i < bosCount; i++)
    {
        BOSEvent bos;
        if(!m_bosDetector.GetBOS(i, bos))
            continue;

        if(bos.bullish)
        {
            double price = bos.pivotPrice;
            int id = CreateLevel(LIQUIDITY_EXTERNAL_HH, price,
                                 LIQUIDITY_ORIGIN_EXTERNAL_HIGH, -1, -1,
                                 bos.breakBar);
            if(id >= 0)
            {
                m_logger.LogInfo(StringFormat(
                    "LIQUIDITY-DETECT CANDIDATE=EXTERNAL_HH ACCEPTED=TRUE "
                    "BOS=%d PIVOT_PRICE=%.5f LEVEL=%d",
                    bos.id, price, id));
            }
        }
        else
        {
            double price = bos.pivotPrice;
            int id = CreateLevel(LIQUIDITY_EXTERNAL_LL, price,
                                 LIQUIDITY_ORIGIN_EXTERNAL_LOW, -1, -1,
                                 bos.breakBar);
            if(id >= 0)
            {
                m_logger.LogInfo(StringFormat(
                    "LIQUIDITY-DETECT CANDIDATE=EXTERNAL_LL ACCEPTED=TRUE "
                    "BOS=%d PIVOT_PRICE=%.5f LEVEL=%d",
                    bos.id, price, id));
            }
        }
    }

    m_lastBOSId = bosCount;
}

void CLiquidityDetector::DetectSweeps(const double &high[], const double &low[], const double &close[],
                                       const datetime &time[], int rates_total)
{
    //--- DD03 (AVP L C9 / doc 04 E1): evaluate only the last CLOSED bar
    //--- (series index 1) and require close-back confirmation: a buy-side
    //--- level is swept when the closed bar pierces above it (high >= level)
    //--- AND closes back below (close < level); sell-side mirrors.  Forming-
    //--- bar touches are no longer sweeps.
    if(rates_total < 2)
        return;

    int curBar = rates_total - 1;
    double curHigh = high[1];
    double curLow  = low[1];
    double curClose = close[1];

    for(int i = 0; i < m_levelCount; i++)
    {
        if(m_levels[i].status != LIQUIDITY_STATUS_ACTIVE)
            continue;

        bool swept = false;
        double distance = 0.0;
        bool isBuySide = (m_levels[i].type == LIQUIDITY_EQH ||
                          m_levels[i].type == LIQUIDITY_EXTERNAL_HH ||
                          m_levels[i].type == LIQUIDITY_INTERNAL_HH);
        bool isSellSide = (m_levels[i].type == LIQUIDITY_EQL ||
                           m_levels[i].type == LIQUIDITY_EXTERNAL_LL ||
                           m_levels[i].type == LIQUIDITY_INTERNAL_LL);

        if(isBuySide && curHigh >= m_levels[i].averagePrice && curClose < m_levels[i].averagePrice)
        {
            swept = true;
            distance = (curHigh - m_levels[i].averagePrice) / (_Point * 10);
        }
        else if(isSellSide && curLow <= m_levels[i].averagePrice && curClose > m_levels[i].averagePrice)
        {
            swept = true;
            distance = (m_levels[i].averagePrice - curLow) / (_Point * 10);
        }

        if(swept)
        {
            int delay = (m_levels[i].detectedBar >= 0) ?
                        (curBar - m_levels[i].detectedBar) : 0;
            if(SweepLevel(m_levels[i].id, curBar, time[1]))
            {
                m_sweepDelayTotal += delay;
                if(delay > m_sweepDelayMax)
                    m_sweepDelayMax = delay;

                switch(m_levels[i].type)
                {
                    case LIQUIDITY_EQH:          m_eqhSwept++;     break;
                    case LIQUIDITY_EQL:          m_eqlSwept++;     break;
                    case LIQUIDITY_EXTERNAL_HH:  m_extHhSwept++;   break;
                    case LIQUIDITY_EXTERNAL_LL:  m_extLlSwept++;   break;
                }

                m_logger.LogInfo(StringFormat(
                    "LIQUIDITY-SWEEP ID=%d TYPE=%d PRICE=%.5f "
                    "HIGH=%.5f LOW=%.5f RESULT=SWEEP DISTANCE=%.1f DELAY=%d",
                    m_levels[i].id, m_levels[i].type, m_levels[i].averagePrice,
                    curHigh, curLow, distance, delay));
            }
        }
        else
        {
            //--- Log near-misses (within 5 pips) for debugging
            double dist = 0.0;
            if(isBuySide)
                dist = (curHigh - m_levels[i].averagePrice) / (_Point * 10);
            else if(isSellSide)
                dist = (m_levels[i].averagePrice - curLow) / (_Point * 10);

            if(dist > -5.0 && dist < 0.0)
            {
                m_logger.LogInfo(StringFormat(
                    "LIQUIDITY-SWEEP-CHECK ID=%d TYPE=%d LEVEL=%.5f "
                    "HIGH=%.5f LOW=%.5f RESULT=NO_SWEEP DISTANCE=%.1f",
                    m_levels[i].id, m_levels[i].type, m_levels[i].averagePrice,
                    curHigh, curLow, dist));
            }
        }
    }
}

void CLiquidityDetector::DetectMitigations(const double &high[], const double &low[],
                                             const datetime &time[], int rates_total)
{
    //--- C4 (integrity): evaluate only the last CLOSED bar (series index
    //    1), mirroring the closed-bar discipline of DetectSweeps (DD03).
    //    The previous high[0]/low[0]/time[0] reads resolved the still-
    //    forming candle, letting a retrace into a swept level be seen
    //    before the bar closed.
    if(rates_total < 2)
        return;

    int curBar = rates_total - 1;
    double curHigh = high[1];
    double curLow  = low[1];

    for(int i = 0; i < m_levelCount; i++)
    {
        if(m_levels[i].status != LIQUIDITY_STATUS_SWEPT)
            continue;

        bool mitigated = false;
        bool isBuySide = (m_levels[i].type == LIQUIDITY_EQH ||
                          m_levels[i].type == LIQUIDITY_EXTERNAL_HH ||
                          m_levels[i].type == LIQUIDITY_INTERNAL_HH);
        bool isSellSide = (m_levels[i].type == LIQUIDITY_EQL ||
                           m_levels[i].type == LIQUIDITY_EXTERNAL_LL ||
                           m_levels[i].type == LIQUIDITY_INTERNAL_LL);

        //--- Buy-side swept level: price swept above, mitigation occurs when price retraces back into the level
        if(isBuySide && curLow <= m_levels[i].averagePrice)
        {
            mitigated = true;
        }
        //--- Sell-side swept level: price swept below, mitigation occurs when price retraces back into the level
        else if(isSellSide && curHigh >= m_levels[i].averagePrice)
        {
            mitigated = true;
        }

        if(mitigated)
        {
            if(MitigateLevel(m_levels[i].id, curBar, (curHigh + curLow) / 2.0, time[1]))
            {
                switch(m_levels[i].type)
                {
                    case LIQUIDITY_EQH:          m_eqhMitigated++;     break;
                    case LIQUIDITY_EQL:          m_eqlMitigated++;     break;
                    case LIQUIDITY_EXTERNAL_HH:  m_extHhMitigated++;   break;
                    case LIQUIDITY_EXTERNAL_LL:  m_extLlMitigated++;   break;
                }

                m_logger.LogInfo(StringFormat(
                    "LIQUIDITY-MITIGATION ID=%d TYPE=%d PRICE=%.5f "
                    "HIGH=%.5f LOW=%.5f BAR=%d",
                    m_levels[i].id, m_levels[i].type, m_levels[i].averagePrice,
                    curHigh, curLow, curBar));
            }
        }
    }
}

void CLiquidityDetector::DetectInvalidations(const datetime &time[], int rates_total)
{
    if(m_bosDetector == NULL)
        return;

    if(rates_total < 1)
        return;

    int newInvalidationBOSCount = m_bosDetector.GetBOSCount();
    int curBar = rates_total - 1;

    //--- First call: seed the counter without processing to avoid invalidating
    //--- levels with BOS events that existed before any sweeps occurred
    if(!m_invalidationSeeded)
    {
        m_lastInvalidationBOSId = newInvalidationBOSCount;
        m_invalidationSeeded = true;
        return;
    }

    //--- Process each new BOS event since last check (incremental)
    for(int b = m_lastInvalidationBOSId; b < newInvalidationBOSCount; b++)
    {
        BOSEvent bos;
        if(!m_bosDetector.GetBOS(b, bos))
            continue;

        for(int i = 0; i < m_levelCount; i++)
        {
            if(m_levels[i].status != LIQUIDITY_STATUS_SWEPT)
                continue;

            bool isBuySide = (m_levels[i].type == LIQUIDITY_EQH ||
                              m_levels[i].type == LIQUIDITY_EXTERNAL_HH);
            bool isSellSide = (m_levels[i].type == LIQUIDITY_EQL ||
                               m_levels[i].type == LIQUIDITY_EXTERNAL_LL);

            if(!isBuySide && !isSellSide)
                continue;

            //--- Bearish BOS invalidates buy-side levels
            //--- Bullish BOS invalidates sell-side levels
            if((isBuySide && !bos.bullish) || (isSellSide && bos.bullish))
            {
                InvalidateLevel(m_levels[i].id, "OpposingBOS",
                                curBar, bos.pivotPrice, time[0]);
            }
        }
    }

    m_lastInvalidationBOSId = newInvalidationBOSCount;
}

void CLiquidityDetector::Shutdown(void)
{
    if(!m_initialized)
        return;

    m_logger.LogInfo("Shutting down Liquidity Detector...");

    int eqh = 0, eql = 0, extHh = 0, extLl = 0, intHh = 0, intLl = 0;
    int active = 0, swept = 0, mitigated = 0, invalidated = 0;
    int buySide = 0, sellSide = 0;
    int totalMembers = 0;
    int clusterCount = 0;
    int largestCluster = 0, totalClusterMembers = 0;

    for(int i = 0; i < m_levelCount; i++)
    {
        switch(m_levels[i].type)
        {
            case LIQUIDITY_EQH:          eqh++;    break;
            case LIQUIDITY_EQL:          eql++;    break;
            case LIQUIDITY_EXTERNAL_HH:  extHh++;  break;
            case LIQUIDITY_EXTERNAL_LL:  extLl++;  break;
            case LIQUIDITY_INTERNAL_HH:  intHh++;  break;
            case LIQUIDITY_INTERNAL_LL:  intLl++;  break;
        }
        switch(m_levels[i].status)
        {
            case LIQUIDITY_STATUS_ACTIVE:      active++;      break;
            case LIQUIDITY_STATUS_SWEPT:       swept++;       break;
            case LIQUIDITY_STATUS_MITIGATED:   mitigated++;   break;
            case LIQUIDITY_STATUS_INVALIDATED: invalidated++; break;
        }
        if(m_levels[i].classification == LIQUIDITY_CLASS_BUY_SIDE)  buySide++;
        if(m_levels[i].classification == LIQUIDITY_CLASS_SELL_SIDE) sellSide++;
        totalMembers += m_levels[i].memberCount;
        if(m_levels[i].type == LIQUIDITY_EQH || m_levels[i].type == LIQUIDITY_EQL)
        {
            clusterCount++;
            totalClusterMembers += m_levels[i].memberCount;
            if(m_levels[i].memberCount > largestCluster)
                largestCluster = m_levels[i].memberCount;
        }
    }

    double avgMembers = (clusterCount > 0) ? (double)totalClusterMembers / clusterCount : 0.0;
    int totalSwept = m_eqhSwept + m_eqlSwept + m_extHhSwept + m_extLlSwept;
    int totalMitigated = m_eqhMitigated + m_eqlMitigated + m_extHhMitigated + m_extLlMitigated;
    double avgDelay = (totalSwept > 0) ? (double)m_sweepDelayTotal / totalSwept : 0.0;

    m_logger.LogInfo("======================= LIQUIDITY SUMMARY =======================");
    m_logger.LogInfo(StringFormat("Total Created          %3d", m_levelCount));
    m_logger.LogInfo(StringFormat("Total Swing Members    %3d", totalMembers));
    m_logger.LogInfo("");
    m_logger.LogInfo(StringFormat("EQH                    %3d", eqh));
    m_logger.LogInfo(StringFormat("EQL                    %3d", eql));
    m_logger.LogInfo(StringFormat("External HH            %3d", extHh));
    m_logger.LogInfo(StringFormat("External LL            %3d", extLl));
    m_logger.LogInfo(StringFormat("Internal HH            %3d", intHh));
    m_logger.LogInfo(StringFormat("Internal LL            %3d", intLl));
    m_logger.LogInfo("");
    m_logger.LogInfo(StringFormat("Clusters               %3d", clusterCount));
    m_logger.LogInfo(StringFormat("Largest Cluster        %3d", largestCluster));
    m_logger.LogInfo(StringFormat("Avg Members            %5.1f", avgMembers));
    m_logger.LogInfo("");
    m_logger.LogInfo("======================= LIQUIDITY LIFECYCLE SUMMARY =======================");
    m_logger.LogInfo(StringFormat("Active                 %3d", active));
    m_logger.LogInfo(StringFormat("Swept                  %3d", swept));
    m_logger.LogInfo(StringFormat("Mitigated              %3d", mitigated));
    m_logger.LogInfo(StringFormat("Invalidated            %3d", invalidated));
    m_logger.LogInfo(StringFormat("Conservation Check: %d + %d + %d + %d = %d  %s",
        active, swept, mitigated, invalidated,
        active + swept + mitigated + invalidated,
        (active + swept + mitigated + invalidated == m_levelCount) ? "OK" : "MISMATCH"));
    m_logger.LogInfo("");
    m_logger.LogInfo("======================= LIQUIDITY SWEEP SUMMARY =======================");
    m_logger.LogInfo(StringFormat("Total Swept            %3d", totalSwept));
    m_logger.LogInfo(StringFormat("  EQH Swept            %3d", m_eqhSwept));
    m_logger.LogInfo(StringFormat("  EQL Swept            %3d", m_eqlSwept));
    m_logger.LogInfo(StringFormat("  External HH Swept    %3d", m_extHhSwept));
    m_logger.LogInfo(StringFormat("  External LL Swept    %3d", m_extLlSwept));
    m_logger.LogInfo(StringFormat("Avg Sweep Delay       %5.1f bars", avgDelay));
    m_logger.LogInfo(StringFormat("Max Sweep Delay       %3d bars", m_sweepDelayMax));
    m_logger.LogInfo("");
    m_logger.LogInfo("======================= LIQUIDITY MITIGATION SUMMARY =======================");
    m_logger.LogInfo(StringFormat("Total Mitigated        %3d", totalMitigated));
    m_logger.LogInfo(StringFormat("  EQH Mitigated        %3d", m_eqhMitigated));
    m_logger.LogInfo(StringFormat("  EQL Mitigated        %3d", m_eqlMitigated));
    m_logger.LogInfo(StringFormat("  External HH Mitigated %3d", m_extHhMitigated));
    m_logger.LogInfo(StringFormat("  External LL Mitigated %3d", m_extLlMitigated));
    m_logger.LogInfo("=================================================================");

    ArrayResize(m_levels, 0);
    m_levelCount = 0;
    m_initialized = false;
}

bool CLiquidityDetector::GetLevel(int index, LiquidityLevel &out) const
{
    if(index < 0 || index >= m_levelCount)
        return false;
    out = m_levels[index];
    return true;
}

int CLiquidityDetector::FindLevelById(int id) const
{
    for(int i = 0; i < m_levelCount; i++)
        if(m_levels[i].id == id)
            return i;
    return -1;
}

int CLiquidityDetector::FindMatchingEQH(double price) const
{
    const double eps = _Point * 0.5;
    double tolerance = LIQUIDITY_EQH_TOLERANCE_PIPS * _Point * 10 + eps;
    for(int i = 0; i < m_levelCount; i++)
    {
        if(m_levels[i].type != LIQUIDITY_EQH)
            continue;
        if(m_levels[i].status != LIQUIDITY_STATUS_ACTIVE)
            continue;
        if(MathAbs(m_levels[i].averagePrice - price) <= tolerance)
            return i;
    }
    return -1;
}

int CLiquidityDetector::FindMatchingEQL(double price) const
{
    const double eps = _Point * 0.5;
    double tolerance = LIQUIDITY_EQL_TOLERANCE_PIPS * _Point * 10 + eps;
    for(int i = 0; i < m_levelCount; i++)
    {
        if(m_levels[i].type != LIQUIDITY_EQL)
            continue;
        if(m_levels[i].status != LIQUIDITY_STATUS_ACTIVE)
            continue;
        if(MathAbs(m_levels[i].averagePrice - price) <= tolerance)
            return i;
    }
    return -1;
}

int CLiquidityDetector::CreateLevel(LiquidityType type, double price,
                                     LiquidityOrigin origin,
                                     int leftSwing, int rightSwing,
                                     int barIndex, datetime leftTime, datetime rightTime)
{
    if(!m_initialized)
        return -1;

    LiquidityLevel level;
    level.id = m_nextId++;
    level.time = 0;
    level.price = price;
    level.averagePrice = price;
    level.memberCount = 1;
    level.type = type;
    //--- DD04 (ledger C10): the side classification is intrinsic to the level
    //--- type and is written here; it was previously hardcoded UNKNOWN and
    //--- never reassigned, which forced TARGET_OPPOSING_LIQUIDITY to resolve
    //--- the candidate's own swept level via the swept-flag fallback.
    level.classification = (type == LIQUIDITY_EQH ||
                            type == LIQUIDITY_EXTERNAL_HH ||
                            type == LIQUIDITY_INTERNAL_HH) ?
                           LIQUIDITY_CLASS_BUY_SIDE : LIQUIDITY_CLASS_SELL_SIDE;
    level.status = LIQUIDITY_STATUS_ACTIVE;
    level.origin = origin;
    level.leftSwingId = leftSwing;
    level.rightSwingId = rightSwing;
    level.leftTime = leftTime;
    level.rightTime = rightTime;
    level.memberIdStr = (leftSwing >= 0) ? IntegerToString(leftSwing) : "";
    level.swept = false;
    level.mitigated = false;
    level.invalidated = false;
    level.detectedTime = 0;
    level.detectedBar = barIndex;
    level.sweptTime = 0;
    level.sweptBar = -1;
    level.mitigatedTime = 0;
    level.mitigatedBar = -1;
    level.mitigatedPrice = 0.0;
    level.invalidatedTime = 0;
    level.invalidatedBar = -1;
    level.invalidatedPrice = 0.0;
    level.invalidatedReason = "";

    m_levelCount = ArrayResize(m_levels, m_levelCount + 1);
    m_levels[m_levelCount - 1] = level;

    return level.id;
}

bool CLiquidityDetector::SweepLevel(int id, int bar, datetime sweepTime)
{
    int idx = FindLevelById(id);
    if(idx < 0)
        return false;

    if(m_levels[idx].status != LIQUIDITY_STATUS_ACTIVE)
    {
        string reason = (m_levels[idx].swept) ? "AlreadySwept" :
                        (m_levels[idx].mitigated) ? "AlreadyMitigated" :
                        (m_levels[idx].invalidated) ? "AlreadyInvalidated" : "Unknown";
        m_logger.LogInfo(StringFormat(
            "LIQUIDITY-TRANSITION-REJECT ID=%d FROM=%s TO=SWEPT REASON=%s",
            id, EnumToString(m_levels[idx].status), reason));
        return false;
    }

    m_levels[idx].swept = true;
    m_levels[idx].status = LIQUIDITY_STATUS_SWEPT;
    m_levels[idx].sweptTime = sweepTime;
    m_levels[idx].sweptBar = bar;

    m_logger.LogInfo(StringFormat("LIQUIDITY-SWEPT ID=%d TYPE=%s PRICE=%.5f",
        id, EnumToString(m_levels[idx].type), m_levels[idx].averagePrice));
    return true;
}

bool CLiquidityDetector::MitigateLevel(int id, int bar, double price, datetime mitigateTime)
{
    int idx = FindLevelById(id);
    if(idx < 0)
        return false;

    if(m_levels[idx].status != LIQUIDITY_STATUS_SWEPT)
    {
        string reason = (!m_levels[idx].swept) ? "NotSwept" :
                        (m_levels[idx].mitigated) ? "AlreadyMitigated" :
                        (m_levels[idx].invalidated) ? "AlreadyInvalidated" : "Unknown";
        m_logger.LogInfo(StringFormat(
            "LIQUIDITY-TRANSITION-REJECT ID=%d FROM=%s TO=MITIGATED REASON=%s",
            id, EnumToString(m_levels[idx].status), reason));
        return false;
    }

    m_levels[idx].mitigated = true;
    m_levels[idx].status = LIQUIDITY_STATUS_MITIGATED;
    m_levels[idx].mitigatedTime = mitigateTime;
    m_levels[idx].mitigatedBar = bar;
    m_levels[idx].mitigatedPrice = price;

    m_logger.LogInfo(StringFormat(
        "LIQUIDITY-MITIGATED ID=%d TYPE=%s PRICE=%.5f BAR=%d MITIGATION_PRICE=%.5f",
        id, EnumToString(m_levels[idx].type), m_levels[idx].averagePrice, bar, price));
    return true;
}

bool CLiquidityDetector::InvalidateLevel(int id, string reason, int bar, double price, datetime invalidateTime)
{
    int idx = FindLevelById(id);
    if(idx < 0)
        return false;

    if(m_levels[idx].status != LIQUIDITY_STATUS_SWEPT)
    {
        string rejectReason = (!m_levels[idx].swept) ? "NotSwept" :
                               (m_levels[idx].mitigated) ? "AlreadyMitigated" :
                               (m_levels[idx].invalidated) ? "AlreadyInvalidated" : "Unknown";
        m_logger.LogInfo(StringFormat(
            "LIQUIDITY-TRANSITION-REJECT ID=%d FROM=%s TO=INVALIDATED REASON=%s",
            id, EnumToString(m_levels[idx].status), rejectReason));
        return false;
    }

    m_levels[idx].invalidated = true;
    m_levels[idx].status = LIQUIDITY_STATUS_INVALIDATED;
    m_levels[idx].invalidatedTime = invalidateTime;
    m_levels[idx].invalidatedBar = bar;
    m_levels[idx].invalidatedPrice = price;
    m_levels[idx].invalidatedReason = reason;

    m_logger.LogInfo(StringFormat(
        "LIQUIDITY-INVALIDATED ID=%d TYPE=%s PRICE=%.5f REASON=%s BAR=%d",
        id, EnumToString(m_levels[idx].type), m_levels[idx].averagePrice, reason, bar));
    return true;
}

#endif
