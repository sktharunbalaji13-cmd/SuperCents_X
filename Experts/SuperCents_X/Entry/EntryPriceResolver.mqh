#ifndef __ENTRY_PRICE_RESOLVER_MQH__
#define __ENTRY_PRICE_RESOLVER_MQH__

#include "../Structure/OrderBlockDetector.mqh"
#include "../Structure/FVGDetector.mqh"
#include "../Structure/LiquidityDetector.mqh"
#include "ExecutionPlanTypes.mqh"

bool ResolveEntryPrice(const TradeCandidate &candidate,
                       ENUM_ENTRY_POLICY policy,
                       COrderBlockDetector *obDetector,
                       CFVGDetector *fvgDetector,
                       CLiquidityDetector *liqDetector,
                       double &entryPrice,
                       string &policyName)
{
    if(policy == ENTRY_OB_RETEST && candidate.hasOB && candidate.obId >= 0 && obDetector != NULL)
    {
        int count = obDetector.GetOrderBlockCount();
        for(int i = 0; i < count; i++)
        {
            OrderBlock ob;
            if(obDetector.GetOrderBlock(i, ob) && ob.id == candidate.obId)
            {
                if(candidate.direction == CONFLUENCE_BULLISH)
                    entryPrice = ob.low;
                else
                    entryPrice = ob.high;
                policyName = "OB Retest";
                return true;
            }
        }
    }

    if(policy == ENTRY_FVG_MIDPOINT && candidate.hasFVG && candidate.fvgId >= 0 && fvgDetector != NULL)
    {
        int count = fvgDetector.GetFVGCount();
        for(int i = 0; i < count; i++)
        {
            FairValueGap fvg;
            if(fvgDetector.GetFVG(i, fvg) && fvg.id == candidate.fvgId)
            {
                entryPrice = (fvg.upper + fvg.lower) / 2.0;
                policyName = "FVG Midpoint";
                return true;
            }
        }
    }

    if(policy == ENTRY_LIQUIDITY_LEVEL && candidate.hasLiquidity && candidate.liquidityId >= 0 && liqDetector != NULL)
    {
        int count = liqDetector.GetLevelCount();
        for(int i = 0; i < count; i++)
        {
            LiquidityLevel ll;
            if(liqDetector.GetLevel(i, ll) && ll.id == candidate.liquidityId)
            {
                entryPrice = ll.price;
                policyName = "Liquidity Level";
                return true;
            }
        }
    }

    entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    policyName = "Current Price";
    return true;
}

#endif
