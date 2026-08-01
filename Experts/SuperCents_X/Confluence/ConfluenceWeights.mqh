#ifndef __CONFLUENCE_WEIGHTS_MQH__
#define __CONFLUENCE_WEIGHTS_MQH__

#include "ConfluenceTypes.mqh"

#define WEIGHT_COUNT 6
#define WEIGHT_TOTAL 100.0

struct ConfluenceWeights
{
    double  structure;
    double  orderBlock;
    double  fvg;
    double  liquidity;
    double  trend;
    double  premiumDiscount;

    ConfluenceWeights(void)
        : structure(25.0)
        , orderBlock(20.0)
        , fvg(15.0)
        , liquidity(15.0)
        , trend(15.0)
        , premiumDiscount(10.0)
    {}

    bool IsValid(void) const
    {
        double sum = structure + orderBlock + fvg + liquidity + trend + premiumDiscount;
        return sum > 99.0 && sum < 101.0;
    }

    void ResetToDefaults(void)
    {
        structure = 25.0;
        orderBlock = 20.0;
        fvg = 15.0;
        liquidity = 15.0;
        trend = 15.0;
        premiumDiscount = 10.0;
    }

    double GetWeight(ENUM_CONFLUENCE_COMPONENT component) const
    {
        switch(component)
        {
            case COMPONENT_STRUCTURE:        return structure;
            case COMPONENT_ORDER_BLOCK:      return orderBlock;
            case COMPONENT_FVG:              return fvg;
            case COMPONENT_LIQUIDITY:        return liquidity;
            case COMPONENT_TREND:            return trend;
            case COMPONENT_PREMIUM_DISCOUNT: return premiumDiscount;
            default: return 0.0;
        }
    }

    string ToString(void) const
    {
        return StringFormat("W{S=%.1f OB=%.1f FVG=%.1f L=%.1f T=%.1f PD=%.1f}",
            structure, orderBlock, fvg, liquidity, trend, premiumDiscount);
    }
};

#endif
