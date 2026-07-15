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

class CFVGDetector
{
private:
    bool m_initialized;
    int m_nextId;
    FairValueGap m_fvgs[];
    int m_fvgCount;
    CLogger m_logger;

    void DetectFVG(const double &open[], const double &high[], const double &low[],
                   const double &close[], const datetime &time[], int rates_total);

public:
    CFVGDetector(void);
    ~CFVGDetector(void);

    bool Init(void);
    void Update(const double &open[], const double &high[], const double &low[],
                const double &close[], const datetime &time[], int rates_total);
    void Shutdown(void);

    bool IsInitialized(void) const { return m_initialized; }
    int GetFVGCount(void) const { return m_fvgCount; }
    bool GetFVG(int index, FairValueGap &out) const;
};

CFVGDetector::CFVGDetector(void)
    : m_initialized(false), m_nextId(0), m_fvgCount(0),
      m_logger(MODULE_FVG_DETECTOR, "FVG")
{
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
    ArrayResize(m_fvgs, 0);
    m_fvgCount = 0;
    m_initialized = false;
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
                              const datetime &time[], int rates_total)
{
    if(rates_total < 3)
        return;

    const double EPS = _Point * 0.1;

    for(int i = rates_total - 1; i >= 2; i--)
    {
        int idxA = i;        // oldest of the three
        int idxB = i - 1;    // middle (displacement)
        int idxC = i - 2;    // newest

        double bodyA = MathAbs(close[idxA] - open[idxA]);
        double bodyC = MathAbs(close[idxC] - open[idxC]);
        double minBody = FVG_MIN_BODY_SIZE_PIPS * _Point * 10;

        if(bodyA < minBody - EPS || bodyC < minBody - EPS)
            continue;

        bool aBullish = close[idxA] > open[idxA];
        bool cBullish = close[idxC] > open[idxC];

        bool isFVG = false;
        bool bullish = false;
        double upper = 0.0;
        double lower = 0.0;

        if(aBullish && !cBullish)
        {
            double gapLow = low[idxA];
            double gapHigh = high[idxC];
            if(gapHigh + EPS < gapLow)
            {
                isFVG = true;
                bullish = false;
                upper = gapLow;
                lower = gapHigh;
            }
        }

        if(!aBullish && cBullish)
        {
            double gapLow = high[idxA];
            double gapHigh = low[idxC];
            if(gapHigh > gapLow + EPS)
            {
                isFVG = true;
                bullish = true;
                upper = gapHigh;
                lower = gapLow;
            }
        }

        if(!isFVG)
            continue;

        // candleIndex = idxB (the middle / displacement candle)
        int fvgIdx = idxB;

        // check duplicates
        bool alreadyDetected = false;
        for(int j = 0; j < m_fvgCount; j++)
        {
            if(m_fvgs[j].candleIndex == fvgIdx)
            {
                alreadyDetected = true;
                break;
            }
        }
        if(alreadyDetected)
            continue;

        FairValueGap fvg;
        fvg.id = m_nextId++;
        fvg.bullish = bullish;
        fvg.time = time[fvgIdx];
        fvg.candleIndex = fvgIdx;
        fvg.upper = upper;
        fvg.lower = lower;
        fvg.filled = false;
        fvg.fillTime = 0;
        fvg.chochId = -1;
        fvg.qualityScore = 1.0;

        m_fvgCount = ArrayResize(m_fvgs, m_fvgCount + 1);
        m_fvgs[m_fvgCount - 1] = fvg;

        m_logger.LogInfo(StringFormat("FVG #%d: %s at %s idx=%d gap=[%.5f, %.5f]",
            fvg.id, fvg.bullish ? "Bullish" : "Bearish",
            TimeToString(fvg.time, TIME_DATE | TIME_MINUTES),
            fvg.candleIndex, fvg.lower, fvg.upper));
    }
}

void CFVGDetector::Update(const double &open[], const double &high[],
                          const double &low[], const double &close[],
                          const datetime &time[], int rates_total)
{
    if(!m_initialized)
        return;

    DetectFVG(open, high, low, close, time, rates_total);
}

#endif
