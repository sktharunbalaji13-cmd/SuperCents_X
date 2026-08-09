#ifndef __PREMIUM_DISCOUNT_EVALUATOR_MQH__
#define __PREMIUM_DISCOUNT_EVALUATOR_MQH__

#include "IConfluenceEvaluator.mqh"

class CPremiumDiscountEvaluator : public IConfluenceEvaluator
{
public:
    bool Evaluate(const DetectionContext &context, ConfluenceComponentResult &result)
    {
        result.type = COMPONENT_PREMIUM_DISCOUNT;

        double high = context.swingHigh;
        double low = context.swingLow;
        double price = context.currentPrice;

        if(high <= 0.0 || low <= 0.0 || price <= 0.0 || high <= low)
        {
            result.score = 0.0;
            result.explanation = "InvalidRange";
            return false;
        }

        double mid = (high + low) / 2.0;
        double range = high - low;

        bool isBullish = true;
        if(context.trendState != NULL)
        {
            Trend t = context.trendState.GetCurrentTrend();
            isBullish = (t == TREND_BULLISH);
        }

        double score = 0.0;
        string expl;

        if(isBullish)
        {
            if(price < low)
            {
                score = 100.0;
                expl = "BelowDiscount(belowLow)";
            }
            else if(price <= mid)
            {
                double pct = (mid - price) / range * 2.0;
                score = 50.0 + pct * 50.0;
                expl = StringFormat("Discount(%.0f%%belowMid)", pct * 100.0);
            }
            else
            {
                double pct = (price - mid) / range * 2.0;
                score = 50.0 - pct * 50.0;
                score = fmax(5.0, score);
                expl = StringFormat("Premium(%.0f%%aboveMid)", pct * 100.0);
            }
        }
        else
        {
            if(price > high)
            {
                score = 100.0;
                expl = "AbovePremium(belowHigh)";
            }
            else if(price >= mid)
            {
                double pct = (price - mid) / range * 2.0;
                score = 50.0 + pct * 50.0;
                expl = StringFormat("Premium(%.0f%%aboveMid)", pct * 100.0);
            }
            else
            {
                double pct = (mid - price) / range * 2.0;
                score = 50.0 - pct * 50.0;
                score = fmax(5.0, score);
                expl = StringFormat("Discount(%.0f%%belowMid)", pct * 100.0);
            }
        }

        result.score = fmin(100.0, fmax(0.0, score));
        result.explanation = expl;
        return true;
    }

    ENUM_CONFLUENCE_COMPONENT GetComponentType(void) const
    {
        return COMPONENT_PREMIUM_DISCOUNT;
    }

    string GetName(void) const
    {
        return "PremiumDiscountEvaluator";
    }

    string GetVersion(void) const
    {
        return "1.0.0";
    }

    string GetDescription(void) const
    {
        return "Scores price position in premium/discount dealing range using swing high/low midpoint";
    }
};

#endif
