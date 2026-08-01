#ifndef __ORDER_BLOCK_EVALUATOR_MQH__
#define __ORDER_BLOCK_EVALUATOR_MQH__

#include "IConfluenceEvaluator.mqh"
#include "../../Structure/OrderBlockDetector.mqh"

#define OB_FRESHNESS_BARS 10
#define OB_RECENT_BARS 50

class COrderBlockEvaluator : public IConfluenceEvaluator
{
private:
    bool FindBestOB(const COrderBlockDetector *detector, double currentPrice, bool bullish,
                    OrderBlock &outOB, int &outIdx) const
    {
        if(detector == NULL) return false;
        int count = detector.GetOrderBlockCount();
        if(count == 0) return false;

        int bestIdx = -1;
        double bestScore = -1.0;
        for(int i = count - 1; i >= 0; i--)
        {
            OrderBlock ob;
            if(!detector.GetOrderBlock(i, ob)) continue;
            if(ob.bullish != bullish) continue;
            if(ob.mitigated || ob.invalidated) continue;

            double freshness = 1.0;
            int age = count - 1 - i;
            if(age < OB_FRESHNESS_BARS)       freshness = 1.0;
            else if(age < OB_FRESHNESS_BARS*2) freshness = 0.8;
            else                                freshness = 0.5;

            double proxScore = 1.0;
            if(currentPrice > 0.0 && ob.high > ob.low)
            {
                double mid = (ob.high + ob.low) / 2.0;
                double dist = MathAbs(currentPrice - mid);
                double range = ob.high - ob.low;
                if(range > 0.0 && dist < range * 5.0)
                    proxScore = fmax(0.0, 1.0 - dist / (range * 5.0));
            }

            double s = freshness * 0.6 + proxScore * 0.4;
            if(s > bestScore)
            {
                bestScore = s;
                bestIdx = i;
                outOB = ob;
            }
        }

        if(bestIdx < 0) return false;
        outIdx = bestIdx;
        return true;
    }

public:
    bool Evaluate(const DetectionContext &context, ConfluenceComponentResult &result)
    {
        result.type = COMPONENT_ORDER_BLOCK;

        OrderBlock bestBullish, bestBearish;
        int bullishIdx = -1, bearishIdx = -1;
        double curPrice = context.currentPrice;
        bool hasBullish = FindBestOB(context.orderBlockDetector, curPrice, true, bestBullish, bullishIdx);
        bool hasBearish = FindBestOB(context.orderBlockDetector, curPrice, false, bestBearish, bearishIdx);

        if(!hasBullish && !hasBearish)
        {
            result.score = 0.0;
            result.explanation = "NoActiveOB";
            return false;
        }

        bool useBullish = hasBullish;
        OrderBlock ob;
        if(useBullish)
            ob = bestBullish;
        else
            ob = bestBearish;

        double score = 50.0;
        string expl = useBullish ? "BullishOB" : "BearishOB";

        int age = (useBullish ? bullishIdx : bearishIdx);
        age = (context.orderBlockDetector.GetOrderBlockCount() - 1) - age;
        if(age < OB_FRESHNESS_BARS)
        {
            score += 20.0;
            expl += "(fresh)";
        }
        else if(age < OB_FRESHNESS_BARS * 2)
        {
            score += 10.0;
            expl += "(aging)";
        }

        double range = ob.high - ob.low;
        if(range > 0.0)
        {
            double displacementPct = (ob.high - ob.low) / ob.low * 100.0;
            if(displacementPct > 0.5)
                score += 15.0;
            else if(displacementPct > 0.2)
                score += 8.0;
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
        return COMPONENT_ORDER_BLOCK;
    }

    string GetName(void) const
    {
        return "OrderBlockEvaluator";
    }

    string GetVersion(void) const
    {
        return "1.0.0";
    }

    string GetDescription(void) const
    {
        return "Scores Order Block quality from freshness, proximity, displacement and trend alignment";
    }
};

#endif
