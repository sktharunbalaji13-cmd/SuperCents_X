#ifndef __STOP_LOSS_RESOLVER_MQH__
#define __STOP_LOSS_RESOLVER_MQH__

#include "../Structure/OrderBlockDetector.mqh"
#include "../Structure/FVGDetector.mqh"
#include "../Structure/LiquidityDetector.mqh"
#include "../Structure/ProtectedPointManager.mqh"
#include "ExecutionPlanTypes.mqh"

//--- P37 (integrity, Fix 6): digits-aware pip conversion. pip = 10 points
//    only on 3/5-digit symbols; 2/4-digit symbols (XAU, 4-digit FX) use 1
//    point per pip. Unknown digits fall back to legacy 10*point behavior.
double PipToPriceDistance(double pips, double point)
{
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    if(point <= 0.0)
        point = _Point;
    if(digits == 3 || digits == 5)
        return pips * 10.0 * point;
    if(digits == 2 || digits == 4)
        return pips * point;
    return pips * 10.0 * point;
}

bool ResolveStopLoss(const TradeCandidate &candidate,
                     ENUM_STOP_POLICY policy,
                     double entryPrice,
                     double stopBufferPips,
                     double minStopDistancePips,
                     COrderBlockDetector *obDetector,
                     CLiquidityDetector *liqDetector,
                     CProtectedPointManager *ppManager,
                     double &stopLoss,
                     string &policyName,
                     bool &structureResolved)
{
    structureResolved = false;
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double stopBuffer = PipToPriceDistance(stopBufferPips, point);

    if(policy == STOP_OB_SIDE && candidate.hasOB && candidate.obId >= 0 && obDetector != NULL)
    {
        int count = obDetector.GetOrderBlockCount();
        for(int i = 0; i < count; i++)
        {
            OrderBlock ob;
            if(obDetector.GetOrderBlock(i, ob) && ob.id == candidate.obId)
            {
                if(candidate.direction == CONFLUENCE_BULLISH)
                    stopLoss = ob.low - stopBuffer;
                else
                    stopLoss = ob.high + stopBuffer;
                policyName = "Below OB + buffer";
                structureResolved = true;
                return true;
            }
        }
    }

    if(policy == STOP_LIQUIDITY_SIDE && candidate.hasLiquidity && candidate.liquidityId >= 0 && liqDetector != NULL)
    {
        int count = liqDetector.GetLevelCount();
        for(int i = 0; i < count; i++)
        {
            LiquidityLevel ll;
            if(liqDetector.GetLevel(i, ll) && ll.id == candidate.liquidityId)
            {
                if(candidate.direction == CONFLUENCE_BULLISH)
                    stopLoss = ll.price - stopBuffer;
                else
                    stopLoss = ll.price + stopBuffer;
                policyName = "Below Liquidity + buffer";
                structureResolved = true;
                return true;
            }
        }
    }

    if(policy == STOP_PROTECTED_POINT && ppManager != NULL)
    {
        ProtectedPoint pp;
        if(candidate.direction == CONFLUENCE_BULLISH && ppManager.GetActiveLow(pp))
        {
            stopLoss = pp.price - stopBuffer;
            policyName = "Below Protected Low";
            structureResolved = true;
            return true;
        }
        else if(candidate.direction == CONFLUENCE_BEARISH && ppManager.GetActiveHigh(pp))
        {
            stopLoss = pp.price + stopBuffer;
            policyName = "Above Protected High";
            structureResolved = true;
            return true;
        }
    }
    //--- P37 (integrity, Fix 6): unsafe-fallback guard. A bare configured
    //    minimum can sit inside the broker stops-level or spread and produce
    //    a lottery-ticket stop that mis-sizes downstream. Floor at
    //    stops-level + 1 spread using existing market data (no new params).
    double minDist = PipToPriceDistance(minStopDistancePips, point);
    double stopLevelDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
    double spreadDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;
    double safeMinDist = MathMax(minDist, stopLevelDist + spreadDist);
    if(candidate.direction == CONFLUENCE_BULLISH)
        stopLoss = entryPrice - safeMinDist;
    else
        stopLoss = entryPrice + safeMinDist;
    policyName = "Broker Minimum";
    return true;
}

#endif
