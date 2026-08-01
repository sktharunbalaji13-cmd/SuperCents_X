#ifndef __LIQUIDITY_EVALUATOR_MQH__
#define __LIQUIDITY_EVALUATOR_MQH__

#include "IConfluenceEvaluator.mqh"
#include "../../Structure/LiquidityDetector.mqh"
#include "../../Structure/ProtectedPointManager.mqh"

#define LIQ_RECENT_BARS 10

class CLiquidityEvaluator : public IConfluenceEvaluator
{
private:
    bool FindRecentSweep(const CLiquidityDetector *detector, bool bullish,
                         LiquidityLevel &outLevel, int &outIdx) const
    {
        if(detector == NULL) return false;
        int count = detector.GetLevelCount();
        if(count == 0) return false;

        for(int i = count - 1; i >= 0; i--)
        {
            LiquidityLevel ll;
            if(!detector.GetLevel(i, ll)) continue;
            if(!ll.swept) continue;

            datetime cutoff = iTime(_Symbol, _Period, LIQ_RECENT_BARS);
            if(cutoff > 0 && ll.sweptTime < cutoff) continue;

            bool levelBullish = (ll.type == LIQUIDITY_EQH || ll.type == LIQUIDITY_INTERNAL_HH);
            if(levelBullish != bullish) continue;

            outLevel = ll;
            outIdx = i;
            return true;
        }
        return false;
    }

    bool HasActivePP(const CProtectedPointManager *pp, bool bullish) const
    {
        if(pp == NULL) return false;
        ProtectedPoint pt;
        if(bullish)
            return pp.GetActiveHigh(pt);
        else
            return pp.GetActiveLow(pt);
    }

public:
    bool Evaluate(const DetectionContext &context, ConfluenceComponentResult &result)
    {
        result.type = COMPONENT_LIQUIDITY;

        LiquidityLevel bullishLevel, bearishLevel;
        int bullishIdx = -1, bearishIdx = -1;
        bool hasBullish = FindRecentSweep(context.liquidityDetector, true, bullishLevel, bullishIdx);
        bool hasBearish = FindRecentSweep(context.liquidityDetector, false, bearishLevel, bearishIdx);

        if(!hasBullish && !hasBearish)
        {
            result.score = 15.0;
            result.explanation = "NoRecentSweep(baseline)";
            return true;
        }

        bool useBullish = hasBullish;
        LiquidityLevel ll;
        if(useBullish)
            ll = bullishLevel;
        else
            ll = bearishLevel;

        double score = 60.0;
        string expl = useBullish ? "BullishSweep" : "BearishSweep";

        if(!ll.mitigated)
        {
            score += 20.0;
            expl += "(fresh)";
        }
        else
        {
            score += 5.0;
            expl += "(mitigated)";
        }

        bool hasPP = HasActivePP(context.protectedPointManager, useBullish);
        if(hasPP)
        {
            score += 20.0;
            expl += "+PP";
        }

        result.score = fmin(100.0, score);
        result.explanation = expl;
        return true;
    }

    ENUM_CONFLUENCE_COMPONENT GetComponentType(void) const
    {
        return COMPONENT_LIQUIDITY;
    }

    string GetName(void) const
    {
        return "LiquidityEvaluator";
    }

    string GetVersion(void) const
    {
        return "1.0.0";
    }

    string GetDescription(void) const
    {
        return "Scores liquidity sweep confluence from recency, mitigation state and protected point relationship";
    }
};

#endif
