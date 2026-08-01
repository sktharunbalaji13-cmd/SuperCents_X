#ifndef __FVG_EVALUATOR_MQH__
#define __FVG_EVALUATOR_MQH__

#include "IConfluenceEvaluator.mqh"
#include "../../Structure/FVGDetector.mqh"

#define FVG_RECENT_BARS 20

class CFVGEvaluator : public IConfluenceEvaluator
{
private:
    bool FindBestFVG(const CFVGDetector *detector, double currentPrice, bool bullish,
                     FairValueGap &outFVG, int &outIdx) const
    {
        if(detector == NULL) return false;
        int count = detector.GetFVGCount();
        if(count == 0) return false;

        int bestIdx = -1;
        double bestScore = -1.0;
        for(int i = count - 1; i >= 0; i--)
        {
            FairValueGap fvg;
            if(!detector.GetFVG(i, fvg)) continue;
            if(fvg.bullish != bullish) continue;
            if(fvg.filled) continue;

            double s = 1.0;
            if(fvg.strength == FVG_STRENGTH_STRONG) s = 1.0;
            else if(fvg.strength == FVG_STRENGTH_NORMAL) s = 0.7;

            double gapSize = MathAbs(fvg.upper - fvg.lower);
            if(gapSize > 0.0 && currentPrice > 0.0)
            {
                double dist = MathAbs(currentPrice - (fvg.upper + fvg.lower) * 0.5);
                if(dist < gapSize * 3.0)
                    s *= (1.0 - dist / (gapSize * 3.0) * 0.3);
            }

            if(s > bestScore)
            {
                bestScore = s;
                bestIdx = i;
                outFVG = fvg;
            }
        }

        if(bestIdx < 0) return false;
        outIdx = bestIdx;
        return true;
    }

public:
    bool Evaluate(const DetectionContext &context, ConfluenceComponentResult &result)
    {
        result.type = COMPONENT_FVG;

        FairValueGap bestBullish, bestBearish;
        int bullishIdx = -1, bearishIdx = -1;
        double curPrice = context.currentPrice;
        bool hasBullish = FindBestFVG(context.fvgDetector, curPrice, true, bestBullish, bullishIdx);
        bool hasBearish = FindBestFVG(context.fvgDetector, curPrice, false, bestBearish, bearishIdx);

        if(!hasBullish && !hasBearish)
        {
            result.score = 0.0;
            result.explanation = "NoUntouchedFVG";
            return false;
        }

        bool useBullish = hasBullish;
        FairValueGap fvg;
        if(useBullish)
            fvg = bestBullish;
        else
            fvg = bestBearish;

        double score = 50.0;
        string expl = useBullish ? "BullishFVG" : "BearishFVG";

        if(fvg.strength == FVG_STRENGTH_STRONG)
        {
            score += 20.0;
            expl += "(strong)";
        }
        else if(fvg.strength == FVG_STRENGTH_NORMAL)
        {
            score += 10.0;
            expl += "(normal)";
        }

        double gapSize = MathAbs(fvg.upper - fvg.lower);
        if(gapSize > 0.0)
        {
            double gapPct = gapSize / (fvg.upper + fvg.lower) * 0.5 * 100.0;
            if(gapPct > 0.3)
                score += 15.0;
            else if(gapPct > 0.1)
                score += 7.0;
        }

        if(context.trendState != NULL)
        {
            Trend t = context.trendState.GetCurrentTrend();
            bool aligned = (useBullish && t == TREND_BULLISH) || (!useBullish && t == TREND_BEARISH);
            if(aligned)
            {
                score += 15.0;
                expl += "+TrendAlign";
            }
        }

        result.score = fmin(100.0, score);
        result.explanation = expl;
        return true;
    }

    ENUM_CONFLUENCE_COMPONENT GetComponentType(void) const
    {
        return COMPONENT_FVG;
    }

    string GetName(void) const
    {
        return "FVGEvaluator";
    }

    string GetVersion(void) const
    {
        return "1.0.0";
    }

    string GetDescription(void) const
    {
        return "Scores Fair Value Gap quality from strength, gap size and trend alignment";
    }
};

#endif
