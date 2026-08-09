//+------------------------------------------------------------------+
//|                                              FVGDetector.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __FVG_DETECTOR_MQH__
#define __FVG_DETECTOR_MQH__

#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "../Utils/Helpers.mqh"
#include "../Core/Logger.mqh"
#include "../Core/HistoryEpoch.mqh"
#include "TrendState.mqh"

class CBOSDetector;
class CCHOCHDetector;

class CFVGDetector : public IHistoryResetConsumer
{
private:
    bool m_initialized;
    int m_nextId;
    FairValueGap m_fvgs[];
    int m_fvgCount;
    datetime m_lastProcessedTime;
    CBOSDetector   *m_bosDetector;
    CCHOCHDetector *m_chochDetector;
    int m_classCounts[4];
    int m_sizeCounts[4];
    int m_strengthCounts[4];
    CLogger m_logger;

    void DetectFVG(const double &open[], const double &high[], const double &low[],
                   const double &close[], const datetime &time[], int rates_total,
                   Trend currentTrend);
    void UpdateLifecycle(CTrendState *trendState, const double &close[]);
    void ClassifyFVG(FairValueGap &fvg, double displacementBody, Trend currentTrend);

public:
    CFVGDetector(void);
    ~CFVGDetector(void);

    bool Init(void);
    void Update(const double &open[], const double &high[], const double &low[],
                const double &close[], const datetime &time[], int rates_total,
                CTrendState *trendState = NULL);
    void Shutdown(void);
    void Clear(void);

    //--- LC02: canonical history reset (HistoryEpoch broadcast). Closes the
    //--- LC4 gap: rates_total shrink WITHOUT time reversal now triggers a
    //--- full rebuild (previously only time[0] < cursor did). Rebuild is
    //--- deterministic: ids restart from 0 (fresh-run state, LC03).
    void OnHistoryReset(void) { Clear(); }

    bool IsInitialized(void) const { return m_initialized; }
    int GetFVGCount(void) const { return m_fvgCount; }
    bool GetFVG(int index, FairValueGap &out) const;

    void SetBOSDetector(CBOSDetector *bos) { m_bosDetector = bos; }
    void SetCHOCHDetector(CCHOCHDetector *choch) { m_chochDetector = choch; }
};

CFVGDetector::CFVGDetector(void)
    : m_initialized(false), m_nextId(0), m_fvgCount(0),
      m_lastProcessedTime(0),
      m_bosDetector(NULL), m_chochDetector(NULL),
      m_logger(MODULE_FVG_DETECTOR, "FVG")
{
    ArrayInitialize(m_classCounts, 0);
    ArrayInitialize(m_sizeCounts, 0);
    ArrayInitialize(m_strengthCounts, 0);
}

CFVGDetector::~CFVGDetector(void)
{
    Shutdown();
}

bool CFVGDetector::Init(void)
{
    m_logger.LogInfo("Initializing FVG Detector...");
    m_nextId = 0;
    m_fvgCount = 0;
    m_lastProcessedTime = 0;
    ArrayFill(m_classCounts, 0, 4, 0);
    ArrayFill(m_sizeCounts, 0, 4, 0);
    ArrayFill(m_strengthCounts, 0, 4, 0);
    ArrayResize(m_fvgs, 0);
    m_initialized = true;
    m_logger.LogInfo("FVG Detector initialized");
    return true;
}

void CFVGDetector::Shutdown(void)
{
    if(!m_initialized)
        return;
    m_logger.LogInfo("Shutting down FVG Detector...");

    //--- Classification summary
    m_logger.LogInfo("======================== FVG CLASSIFICATION ========================");
    m_logger.LogInfo(StringFormat("Total Created          %3d", m_fvgCount));
    m_logger.LogInfo("");
    m_logger.LogInfo(StringFormat("Breakaway              %3d", m_classCounts[FVG_CLASS_BREAKAWAY]));
    m_logger.LogInfo(StringFormat("Continuation           %3d", m_classCounts[FVG_CLASS_CONTINUATION]));
    m_logger.LogInfo(StringFormat("Reversal               %3d", m_classCounts[FVG_CLASS_REVERSAL]));
    m_logger.LogInfo(StringFormat("Unknown                %3d", m_classCounts[FVG_CLASS_UNKNOWN]));
    m_logger.LogInfo("");
    m_logger.LogInfo(StringFormat("Small                  %3d", m_sizeCounts[FVG_SIZE_SMALL]));
    m_logger.LogInfo(StringFormat("Medium                 %3d", m_sizeCounts[FVG_SIZE_MEDIUM]));
    m_logger.LogInfo(StringFormat("Large                  %3d", m_sizeCounts[FVG_SIZE_LARGE]));
    m_logger.LogInfo("");
    m_logger.LogInfo(StringFormat("Weak                   %3d", m_strengthCounts[FVG_STRENGTH_WEAK]));
    m_logger.LogInfo(StringFormat("Normal                 %3d", m_strengthCounts[FVG_STRENGTH_NORMAL]));
    m_logger.LogInfo(StringFormat("Strong                 %3d", m_strengthCounts[FVG_STRENGTH_STRONG]));
    m_logger.LogInfo("================================================================");

    ArrayResize(m_fvgs, 0);
    m_fvgCount = 0;
    m_initialized = false;
}

void CFVGDetector::Clear(void)
{
    //--- Drop the pool + time cursor; the next Update() becomes a full
    //--- initial scan. m_nextId resets to the fresh-run value (0) so an
    //--- epoch rebuild reproduces the exact fresh-run state (LC03:
    //--- deterministic reconstruction). The standalone time-reversal
    //--- rescan path keeps ids monotonic (LC01.1, no-reuse contract).
    m_fvgCount = 0;
    m_nextId = 0;
    m_lastProcessedTime = 0;
    ArrayResize(m_fvgs, 0);
}

bool CFVGDetector::GetFVG(int index, FairValueGap &out) const
{
    if(index < 0 || index >= m_fvgCount)
        return false;
    out = m_fvgs[index];
    return true;
}

void CFVGDetector::DetectFVG(const double &open[], const double &high[],
                              const double &low[], const double &close[],
                              const datetime &time[], int rates_total,
                              Trend currentTrend)
{
    if(rates_total < 3)
        return;

    const double EPS = _Point * 0.1;

    int start_i;
    int end_i = 2;

    if(m_lastProcessedTime == 0)
    {
        start_i = rates_total - 1;
    }
    else
    {
        if(time[0] < m_lastProcessedTime)
        {
            m_logger.LogInfo("Time discontinuity detected — rescanning full history");
            m_lastProcessedTime = 0;
            m_fvgCount = 0;
            ArrayResize(m_fvgs, 0);
            start_i = rates_total - 1;
        }
        else if(time[0] == m_lastProcessedTime)
        {
            return;
        }
        else
        {
            int newBars = 0;
            for(int k = 0; k < rates_total; k++)
            {
                if(time[k] > m_lastProcessedTime)
                    newBars++;
                else
                    break;
            }
            start_i = MathMin(newBars + 2, rates_total - 1);
        }
    }

    for(int i = start_i; i >= end_i; i--)
    {
        int idxA = i;        // oldest of the three
        int idxB = i - 1;    // middle (displacement)
        int idxC = i - 2;    // newest

        double bodyA = MathAbs(close[idxA] - open[idxA]);
        double bodyB = MathAbs(close[idxB] - open[idxB]);
        double bodyC = MathAbs(close[idxC] - open[idxC]);
        double minBody = FVG_MIN_BODY_SIZE_PIPS * _Point * 10;

        bool aBullish = close[idxA] > open[idxA];
        bool cBullish = close[idxC] > open[idxC];

        // Candidate info for logging
        bool candidateIsFVG = false;
        bool bullish = false;
        double upper = 0.0;
        double lower = 0.0;
        string rejectReason = "";
        string candType = "NONE";

        // Check body size
        if(bodyA < minBody - EPS)
        {
            rejectReason = StringFormat("bodyA too small: %.5f < %.5f", bodyA, minBody);
        }
        else if(bodyC < minBody - EPS)
        {
            rejectReason = StringFormat("bodyC too small: %.5f < %.5f", bodyC, minBody);
        }
        else
        {
            //--- Bearish FVG candidate: A bullish, C bearish
            if(aBullish && !cBullish)
            {
                candType = "BEARISH";
                double gapLow = low[idxA];
                double gapHigh = high[idxC];
                if(gapHigh + EPS < gapLow)
                {
                    candidateIsFVG = true;
                    bullish = false;
                    upper = gapLow;
                    lower = gapHigh;
                }
                else
                {
                    double overlap = gapLow - gapHigh;
                    rejectReason = StringFormat("bearish no-gap: High(C)=%.5f < Low(A)=%.5f? overlap=%.5f (need >%.5f)",
                        gapHigh, gapLow, overlap, EPS);
                }
            }
            //--- Bullish FVG candidate: A bearish, C bullish
            else if(!aBullish && cBullish)
            {
                candType = "BULLISH";
                double gapLow = high[idxA];
                double gapHigh = low[idxC];
                if(gapHigh > gapLow + EPS)
                {
                    candidateIsFVG = true;
                    bullish = true;
                    upper = gapHigh;
                    lower = gapLow;
                }
                else
                {
                    double overlap = gapHigh - gapLow;
                    rejectReason = StringFormat("bullish no-gap: Low(C)=%.5f > High(A)=%.5f? overlap=%.5f (need >%.5f)",
                        gapHigh, gapLow, overlap, EPS);
                }
            }
            else
            {
                candType = aBullish ? "A-BULL-C-BULL" : "A-BEAR-C-BEAR";
                rejectReason = StringFormat("same direction: A=%s C=%s",
                    aBullish ? "BULL" : "BEAR",
                    cBullish ? "BULL" : "BEAR");
            }
        }

        if(!candidateIsFVG)
        {
            // Log rejection only for the area the user is investigating (around the target candles)
            // In a full backtest this would be too noisy, so we gate by a time window
            datetime tA = time[idxA];
            datetime tC = time[idxC];
            if(tA >= D'2026.01.12 00:00' && tC <= D'2026.02.06 00:00')
            {
                m_logger.LogInfo(StringFormat("FVG-REJECT [%s] A=%s idx=%d O=%.5f H=%.5f L=%.5f C=%.5f body=%.5f | B=%s idx=%d | C=%s idx=%d O=%.5f H=%.5f L=%.5f C=%.5f body=%.5f | reason=%s",
                    candType,
                    TimeToString(tA, TIME_DATE | TIME_MINUTES), idxA, open[idxA], high[idxA], low[idxA], close[idxA], bodyA,
                    TimeToString(time[idxB], TIME_DATE | TIME_MINUTES), idxB,
                    TimeToString(tC, TIME_DATE | TIME_MINUTES), idxC, open[idxC], high[idxC], low[idxC], close[idxC], bodyC,
                    rejectReason));
            }
            continue;
        }

        // candleIndex = idxB (the middle / displacement candle)
        int fvgIdx = idxB;
        datetime fvgTime = time[fvgIdx];

        // check duplicates by time
        bool alreadyDetected = false;
        for(int j = 0; j < m_fvgCount; j++)
        {
            if(m_fvgs[j].time == fvgTime)
            {
                alreadyDetected = true;
                break;
            }
        }
        if(alreadyDetected)
        {
            m_logger.LogInfo(StringFormat("FVG-REJECT [%s] A=%s B=%s C=%s DUPLICATE (fvgTime=%s)",
                candType,
                TimeToString(time[idxA], TIME_DATE | TIME_MINUTES),
                TimeToString(time[idxB], TIME_DATE | TIME_MINUTES),
                TimeToString(time[idxC], TIME_DATE | TIME_MINUTES),
                TimeToString(fvgTime, TIME_DATE | TIME_MINUTES)));
            continue;
        }

        FairValueGap fvg;
        fvg.id = m_nextId++;
        fvg.bullish = bullish;
        fvg.time = time[fvgIdx];
        fvg.candleIndex = fvgIdx;
        fvg.upper = upper;
        fvg.lower = lower;
        fvg.filled = false;
        fvg.fillTime = 0;
        fvg.invalidated = false;
        fvg.chochId = -1;
        fvg.qualityScore = 1.0;
        fvg.fvgClass = FVG_CLASS_UNKNOWN;
        fvg.classEventId = -1;
        fvg.classEventType = 0;
        fvg.gapSizePips = 0.0;
        fvg.sizeCategory = FVG_SIZE_UNKNOWN;
        fvg.strength = FVG_STRENGTH_UNKNOWN;
        fvg.displacementBodyPips = 0.0;

        ClassifyFVG(fvg, bodyB, currentTrend);

        m_fvgCount = ArrayResize(m_fvgs, m_fvgCount + 1);
        m_fvgs[m_fvgCount - 1] = fvg;

        string classStr = fvg.fvgClass == FVG_CLASS_BREAKAWAY ? "BREAKAWAY" :
                          fvg.fvgClass == FVG_CLASS_CONTINUATION ? "CONTINUATION" :
                          fvg.fvgClass == FVG_CLASS_REVERSAL ? "REVERSAL" : "UNKNOWN";
        string sizeStr = fvg.sizeCategory == FVG_SIZE_SMALL ? "SMALL" :
                         fvg.sizeCategory == FVG_SIZE_MEDIUM ? "MEDIUM" : "LARGE";
        string strengthStr = fvg.strength == FVG_STRENGTH_WEAK ? "WEAK" :
                             fvg.strength == FVG_STRENGTH_NORMAL ? "NORMAL" : "STRONG";

        m_logger.LogInfo(StringFormat("FVG-CREATED ID=%d TYPE=%s CLASS=%s SIZE=%.1f(%s) STRENGTH=%s GAP=[%.5f, %.5f] TIME=%s",
            fvg.id, fvg.bullish ? "BULLISH" : "BEARISH", classStr,
            fvg.gapSizePips, sizeStr, strengthStr,
            fvg.lower, fvg.upper,
            TimeToString(fvg.time, TIME_DATE | TIME_MINUTES)));
    }

    m_lastProcessedTime = time[0];
}

void CFVGDetector::Update(const double &open[], const double &high[],
                          const double &low[], const double &close[],
                          const datetime &time[], int rates_total,
                          CTrendState *trendState)
{
    if(!m_initialized)
        return;

    Trend currentTrend = (trendState != NULL) ? trendState.GetCurrentTrend() : TREND_UNKNOWN;
    DetectFVG(open, high, low, close, time, rates_total, currentTrend);

    //--- Update lifecycle on existing FVGs (fill, invalidation)
    UpdateLifecycle(trendState, close);
}

void CFVGDetector::UpdateLifecycle(CTrendState *trendState, const double &close[])
{
    if(trendState == NULL || m_fvgCount == 0)
        return;

    Trend currentTrend = trendState.GetCurrentTrend();

    for(int i = 0; i < m_fvgCount; i++)
    {
        if(m_fvgs[i].invalidated)
            continue;

        //--- Check fill: last completed bar close entered the gap
        if(!m_fvgs[i].filled)
        {
            double lastClose = close[1];  // 0=newest (current), 1=last completed
            double gapLow  = MathMin(m_fvgs[i].lower, m_fvgs[i].upper);
            double gapHigh = MathMax(m_fvgs[i].lower, m_fvgs[i].upper);

            if(lastClose >= gapLow && lastClose <= gapHigh)
            {
                m_fvgs[i].filled = true;
                m_fvgs[i].fillTime = 0;  // filled on this bar
                m_logger.LogInfo(StringFormat(
                    "FVG #%d FILLED close=%.5f entered gap [%.5f, %.5f]",
                    m_fvgs[i].id, lastClose, gapLow, gapHigh));
            }
        }

        //--- Check invalidation: trend opposes FVG direction
        if(!m_fvgs[i].filled)
        {
            bool trendOpposes = (m_fvgs[i].bullish && currentTrend == TREND_BEARISH) ||
                                (!m_fvgs[i].bullish && currentTrend == TREND_BULLISH);

            if(trendOpposes)
            {
                m_fvgs[i].invalidated = true;
                m_logger.LogInfo(StringFormat(
                    "FVG #%d INVALIDATED (trend flip: FVG=%s trend=%s)",
                    m_fvgs[i].id,
                    m_fvgs[i].bullish ? "BULLISH" : "BEARISH",
                    currentTrend == TREND_BULLISH ? "BULLISH" : "BEARISH"));
            }
        }
    }
}

void CFVGDetector::ClassifyFVG(FairValueGap &fvg, double displacementBody, Trend currentTrend)
{
    const int SECS_PER_BAR = 900; // M15

    //--- 1. Gap size
    fvg.gapSizePips = (MathAbs(fvg.upper - fvg.lower)) / _Point / 10.0;
    if(fvg.gapSizePips < FVG_SIZE_SMALL_PIPS)
        fvg.sizeCategory = FVG_SIZE_SMALL;
    else if(fvg.gapSizePips < FVG_SIZE_LARGE_PIPS)
        fvg.sizeCategory = FVG_SIZE_MEDIUM;
    else
        fvg.sizeCategory = FVG_SIZE_LARGE;

    //--- 2. Displacement strength
    fvg.displacementBodyPips = displacementBody / _Point / 10.0;
    if(fvg.displacementBodyPips < FVG_STRENGTH_BODY_SMALL_PIPS)
        fvg.strength = FVG_STRENGTH_WEAK;
    else if(fvg.displacementBodyPips < FVG_STRENGTH_BODY_LARGE_PIPS)
        fvg.strength = FVG_STRENGTH_NORMAL;
    else
        fvg.strength = FVG_STRENGTH_STRONG;

    //--- 3. Collect evidence for classification
    bool hasRecentBOS = false;
    bool hasRecentCHOCH = false;
    int barsSinceBOS = 999;
    int barsSinceCHOCH = 999;
    int matchedBOSId = -1;
    int matchedCHOCHId = -1;
    bool bosDirectionMatch = false;
    bool chochDirectionMatch = false;

    // Search recent CHOCH
    if(m_chochDetector != NULL)
    {
        int chochCount = m_chochDetector.GetCHOCHCount();
        for(int i = chochCount - 1; i >= 0; i--)
        {
            CHOCHEvent choch;
            if(m_chochDetector.GetCHOCH(i, choch))
            {
                int secs = (int)(fvg.time - choch.time);
                if(secs >= 0 && secs <= FVG_CLASS_LOOKBACK_SECONDS)
                {
                    hasRecentCHOCH = true;
                    barsSinceCHOCH = secs / SECS_PER_BAR;
                    matchedCHOCHId = choch.id;
                    chochDirectionMatch = (fvg.bullish == choch.bullish);
                    break;
                }
            }
        }
    }

    // Search recent BOS
    if(m_bosDetector != NULL)
    {
        int bosCount = m_bosDetector.GetBOSCount();
        for(int i = bosCount - 1; i >= 0; i--)
        {
            BOSEvent bos;
            if(m_bosDetector.GetBOS(i, bos))
            {
                int secs = (int)(fvg.time - bos.breakTime);
                if(secs >= 0 && secs <= FVG_CLASS_LOOKBACK_SECONDS)
                {
                    hasRecentBOS = true;
                    barsSinceBOS = secs / SECS_PER_BAR;
                    matchedBOSId = bos.id;
                    bosDirectionMatch = (fvg.bullish == bos.bullish);
                    break;
                }
            }
        }
    }

    //--- 4. Determine class: Reversal > Breakaway > Continuation
    string reasonLine = "";

    if(hasRecentCHOCH && chochDirectionMatch)
    {
        fvg.fvgClass = FVG_CLASS_REVERSAL;
        fvg.classEventId = matchedCHOCHId;
        fvg.classEventType = 2;
        reasonLine = StringFormat(
            "FVG-CLASS ID=%d REVERSAL CHOCH=TRUE(ID=%d) BOS=%s BarsSinceCHOCH=%d Trend=%s",
            fvg.id, matchedCHOCHId,
            hasRecentBOS ? StringFormat("TRUE(ID=%d)", matchedBOSId) : "FALSE",
            barsSinceCHOCH,
            currentTrend == TREND_BULLISH ? "BULLISH" :
            currentTrend == TREND_BEARISH ? "BEARISH" : "UNKNOWN");
    }
    else if(hasRecentBOS && bosDirectionMatch)
    {
        fvg.fvgClass = FVG_CLASS_BREAKAWAY;
        fvg.classEventId = matchedBOSId;
        fvg.classEventType = 1;
        reasonLine = StringFormat(
            "FVG-CLASS ID=%d BREAKAWAY BOS=TRUE(ID=%d) CHOCH=%s BarsSinceBOS=%d Trend=%s",
            fvg.id, matchedBOSId,
            hasRecentCHOCH ? StringFormat("TRUE(ID=%d)", matchedCHOCHId) : "FALSE",
            barsSinceBOS,
            currentTrend == TREND_BULLISH ? "BULLISH" :
            currentTrend == TREND_BEARISH ? "BEARISH" : "UNKNOWN");
    }
    else if((currentTrend == TREND_BULLISH && fvg.bullish) ||
            (currentTrend == TREND_BEARISH && !fvg.bullish))
    {
        fvg.fvgClass = FVG_CLASS_CONTINUATION;
        reasonLine = StringFormat(
            "FVG-CLASS ID=%d CONTINUATION BOS=%s CHOCH=%s Trend=%s",
            fvg.id,
            hasRecentBOS ? StringFormat("TRUE(ID=%d dir=%s)", matchedBOSId,
                bosDirectionMatch ? "MATCH" : "MISMATCH") : "FALSE",
            hasRecentCHOCH ? StringFormat("TRUE(ID=%d dir=%s)", matchedCHOCHId,
                chochDirectionMatch ? "MATCH" : "MISMATCH") : "FALSE",
            currentTrend == TREND_BULLISH ? "BULLISH" :
            currentTrend == TREND_BEARISH ? "BEARISH" : "UNKNOWN");
    }
    else
    {
        fvg.fvgClass = FVG_CLASS_UNKNOWN;
        reasonLine = StringFormat(
            "FVG-CLASS ID=%d UNKNOWN BOS=%s CHOCH=%s Trend=%s FVG=%s",
            fvg.id,
            hasRecentBOS ? "TRUE" : "FALSE",
            hasRecentCHOCH ? "TRUE" : "FALSE",
            currentTrend == TREND_BULLISH ? "BULLISH" :
            currentTrend == TREND_BEARISH ? "BEARISH" : "UNKNOWN",
            fvg.bullish ? "BULLISH" : "BEARISH");
    }

    m_logger.LogInfo(reasonLine);

    //--- 5. Accumulate summary counters
    m_classCounts[fvg.fvgClass]++;
    m_sizeCounts[fvg.sizeCategory]++;
    m_strengthCounts[fvg.strength]++;
}

#endif
