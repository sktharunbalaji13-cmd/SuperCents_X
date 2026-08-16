#ifndef __STOP_LOSS_RESOLVER_MQH__
#define __STOP_LOSS_RESOLVER_MQH__

#include "../Structure/OrderBlockDetector.mqh"
#include "../Structure/FVGDetector.mqh"
#include "../Structure/LiquidityDetector.mqh"
#include "../Structure/ProtectedPointManager.mqh"
#include "ExecutionPlanTypes.mqh"

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
    double stopBuffer = stopBufferPips * 10.0 * point;

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

    double minDist = minStopDistancePips * 10.0 * point;
    if(candidate.direction == CONFLUENCE_BULLISH)
        stopLoss = entryPrice - minDist;
    else
        stopLoss = entryPrice + minDist;
    policyName = "Broker Minimum";
    return true;
}

#endif
