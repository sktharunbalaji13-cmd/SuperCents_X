#ifndef __TARGET_RESOLVER_MQH__
#define __TARGET_RESOLVER_MQH__

#include "../Structure/OrderBlockDetector.mqh"
#include "../Structure/FVGDetector.mqh"
#include "../Structure/LiquidityDetector.mqh"
#include "../Structure/BOSDetector.mqh"
#include "ExecutionPlanTypes.mqh"

double ResolveTargetByFixedRR(double entryPrice, double stopLoss, double targetRR, ConfluenceDirection dir)
{
    double stopDist = MathAbs(entryPrice - stopLoss);
    if(stopDist <= 0) return 0;
    if(dir == CONFLUENCE_BULLISH)
        return entryPrice + stopDist * targetRR;
    else
        return entryPrice - stopDist * targetRR;
}

bool ResolveTakeProfit(const TradeCandidate &candidate,
                       ENUM_TARGET_POLICY policy,
                       double entryPrice,
                       double stopLoss,
                       double targetRR,
                       COrderBlockDetector *obDetector,
                       CFVGDetector *fvgDetector,
                       CLiquidityDetector *liqDetector,
                       CBOSDetector *bosDetector,
                       double &takeProfit,
                       string &policyName,
                       bool &structureResolved)
{
    // C1: every target path is deterministic (structure or fixed-RR with a
    // stable RR tier).  There is no live/broker fallback in this resolver.
    structureResolved = true;

    if(policy == TARGET_OPPOSING_LIQUIDITY && candidate.hasLiquidity && candidate.liquidityId >= 0 && liqDetector != NULL)
    {
        //--- DD04 (ledger C10): the opposing target is a DIFFERENT pool of the
        //--- run-side class.  The candidate's own (source) level is never the
        //--- target, consumed pools (swept/mitigated/invalidated) are never
        //--- targets, and the classification is authoritative (no swept-flag
        //--- fallback: classification is written at CreateLevel).
        int count = liqDetector.GetLevelCount();
        for(int i = count - 1; i >= 0; i--)
        {
            LiquidityLevel ll;
            if(!liqDetector.GetLevel(i, ll))
                continue;
            if(ll.id == candidate.liquidityId || ll.status != LIQUIDITY_STATUS_ACTIVE)
                continue;
            if(candidate.direction == CONFLUENCE_BULLISH && ll.classification == LIQUIDITY_CLASS_BUY_SIDE && ll.price > entryPrice)
            {
                takeProfit = ll.price;
                policyName = "Opposing Liquidity";
                return true;
            }
            else if(candidate.direction == CONFLUENCE_BEARISH && ll.classification == LIQUIDITY_CLASS_SELL_SIDE && ll.price < entryPrice)
            {
                takeProfit = ll.price;
                policyName = "Opposing Liquidity";
                return true;
            }
        }
    }

    if(policy == TARGET_OPPOSING_OB && obDetector != NULL)
    {
        int count = obDetector.GetOrderBlockCount();
        for(int i = count - 1; i >= 0; i--)
        {
            OrderBlock ob;
            if(obDetector.GetOrderBlock(i, ob) && ob.id != candidate.obId && !ob.mitigated && !ob.invalidated)
            {
                if(candidate.direction == CONFLUENCE_BULLISH && !ob.bullish && ob.low > entryPrice)
                {
                    takeProfit = ob.low;
                    policyName = "Opposing OB";
                    return true;
                }
                else if(candidate.direction == CONFLUENCE_BEARISH && ob.bullish && ob.high < entryPrice)
                {
                    takeProfit = ob.high;
                    policyName = "Opposing OB";
                    return true;
                }
            }
        }
    }

    if(policy == TARGET_OPPOSING_FVG && fvgDetector != NULL)
    {
        int count = fvgDetector.GetFVGCount();
        for(int i = count - 1; i >= 0; i--)
        {
            FairValueGap fvg;
            if(fvgDetector.GetFVG(i, fvg) && !fvg.filled && !fvg.invalidated)
            {
                if(candidate.direction == CONFLUENCE_BULLISH && !fvg.bullish && fvg.lower > entryPrice)
                {
                    takeProfit = fvg.lower;
                    policyName = "Opposing FVG";
                    return true;
                }
                else if(candidate.direction == CONFLUENCE_BEARISH && fvg.bullish && fvg.upper < entryPrice)
                {
                    takeProfit = fvg.upper;
                    policyName = "Opposing FVG";
                    return true;
                }
            }
        }
    }

    if(policy == TARGET_PREVIOUS_SWING && bosDetector != NULL)
    {
        int count = bosDetector.GetBOSCount();
        for(int i = count - 1; i >= 0; i--)
        {
            BOSEvent bos;
            if(bosDetector.GetBOS(i, bos))
            {
                if(candidate.direction == CONFLUENCE_BULLISH && !bos.bullish && bos.pivotPrice > entryPrice)
                {
                    takeProfit = bos.pivotPrice;
                    policyName = "Previous Swing (BOS pivot)";
                    return true;
                }
                else if(candidate.direction == CONFLUENCE_BEARISH && bos.bullish && bos.pivotPrice < entryPrice)
                {
                    takeProfit = bos.pivotPrice;
                    policyName = "Previous Swing (BOS pivot)";
                    return true;
                }
            }
        }
    }

    takeProfit = ResolveTargetByFixedRR(entryPrice, stopLoss, targetRR, candidate.direction);
    policyName = StringFormat("Fixed RR %.1f", targetRR);
    return true;
}

#endif
