#ifndef __TREND_EVALUATOR_MQH__
#define __TREND_EVALUATOR_MQH__

#include "IConfluenceEvaluator.mqh"
#include "../../Structure/TrendState.mqh"

class CTrendEvaluator : public IConfluenceEvaluator
{
public:
    bool Evaluate(const DetectionContext &context, ConfluenceComponentResult &result)
    {
        result.type = COMPONENT_TREND;

        if(context.trendState == NULL)
        {
            result.score = 0.0;
            result.explanation = "NoTrendData";
            return false;
        }

        Trend current = context.trendState.GetCurrentTrend();

        if(current == TREND_UNKNOWN)
        {
            result.score = 10.0;
            result.explanation = "TrendUnknown(limited)";
            return true;
        }

        bool isBullish = (current == TREND_BULLISH);
        double score = 0.0;
        string expl;

        if(isBullish)
        {
            score = 80.0;
            expl = "BullishTrend";
        }
        else
        {
            score = 80.0;
            expl = "BearishTrend";
        }

        double strength = 0.0;
        int bullishBOS = context.trendState.GetBullishBOSCount();
        int bearishBOS = context.trendState.GetBearishBOSCount();
        int totalBOS = bullishBOS + bearishBOS;
        if(totalBOS > 0)
        {
            if(current == TREND_BULLISH)
                strength = (double)bullishBOS / totalBOS;
            else
                strength = (double)bearishBOS / totalBOS;
        }
        if(strength > 0.0)
        {
            score += fmin(20.0, strength * 20.0);
            expl += StringFormat("(strength=%.2f)", strength);
        }

        result.score = fmin(100.0, score);
        result.explanation = expl;
        return true;
    }

    ENUM_CONFLUENCE_COMPONENT GetComponentType(void) const
    {
        return COMPONENT_TREND;
    }

    string GetName(void) const
    {
        return "TrendEvaluator";
    }

    string GetVersion(void) const
    {
        return "1.0.0";
    }

    string GetDescription(void) const
    {
        return "Scores trend alignment and strength from TrendState";
    }
};

#endif
