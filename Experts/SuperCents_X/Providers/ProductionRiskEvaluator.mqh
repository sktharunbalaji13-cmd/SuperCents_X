//+------------------------------------------------------------------+
//|                                  ProductionRiskEvaluator.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 15 (v3.0)       |
//+------------------------------------------------------------------+
//  Real-account risk evaluator (live + tester).  Rejects positions when
//  the account cannot absorb the trade: insufficient free margin, no
//  margin room for the minimum lot, or trading disabled on the symbol.
//  Contract: @frozen v3.0-provider-contract (IRiskEvaluator).
//+------------------------------------------------------------------+
#ifndef __PRODUCTION_RISK_EVALUATOR_MQH__
#define __PRODUCTION_RISK_EVALUATOR_MQH__

#include "../Entry/Validators/IRiskEvaluator.mqh"
#include "../Core/Logger.mqh"

class CProductionRiskEvaluator : public IRiskEvaluator
{
public:
    CProductionRiskEvaluator(const string symbol, double marginBufferFactor = 1.25)
        : m_symbol(symbol)
        , m_marginBufferFactor(marginBufferFactor)
        , m_name("ProductionRisk")
        , m_logger(MODULE_UNKNOWN, "ProductionRisk")
    {}

    virtual RiskEvaluation Evaluate(double confidence)
    {
        RiskEvaluation ev;
        ev.allowed = false;
        ev.recommendedLots = 0.0;
        ev.rejectionReason = RR_UNKNOWN;

        int tradeMode = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE);
        if(tradeMode < (int)SYMBOL_TRADE_MODE_FULL)
        {
            ev.rejectionReason = RR_TRADING_DISABLED;
            ev.reason = "trading disabled for " + m_symbol;
            return ev;
        }

        double volumeMin = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
        double volumeMax = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
        if(volumeMin <= 0.0 || volumeMax <= 0.0)
        {
            ev.rejectionReason = RR_INVALID_VOLUME;
            ev.reason = "invalid volume limits for " + m_symbol;
            return ev;
        }

        double price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        if(price <= 0.0)
            price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        if(price <= 0.0)
        {
            ev.rejectionReason = RR_NO_PRICE;
            ev.reason = "no market price for " + m_symbol;
            return ev;
        }

        //--- Can we even afford the minimum lot?
        double marginMin = 0.0;
        if(!OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, volumeMin, price, marginMin))
        {
            ev.rejectionReason = RR_MARGIN_CALC_FAILED;
            ev.reason = "OrderCalcMargin failed for " + m_symbol;
            return ev;
        }

        double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        if(marginMin * m_marginBufferFactor > freeMargin)
        {
            ev.rejectionReason = RR_INSUFFICIENT_MARGIN;
            ev.reason = StringFormat("insufficient margin (need %.2f, free %.2f)",
                                     marginMin, freeMargin);
            return ev;
        }

        //--- Max affordable lots by margin, clamped to the broker limits.
        double maxByMargin = (freeMargin / m_marginBufferFactor) * volumeMin / marginMin;
        double maxLots = maxByMargin;
        if(maxLots > volumeMax)
            maxLots = volumeMax;

        //--- Margin floors / tiered leverage can break linear scaling, so
        //    the linear estimate may exceed what the account can absorb.
        //    Verify affordability at the estimated size and step down to
        //    the largest affordable volume when needed.
        double marginReq = 0.0;
        bool affordable = OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, maxLots, price, marginReq)
                          && (marginReq * m_marginBufferFactor <= freeMargin);
        if(!affordable)
        {
            double lo = volumeMin;
            double hi = maxLots;
            for(int i = 0; i < 40; i++)
            {
                double mid = (lo + hi) * 0.5;
                double m = 0.0;
                if(OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, mid, price, m)
                   && (m * m_marginBufferFactor <= freeMargin))
                    lo = mid;
                else
                    hi = mid;
            }
            maxLots = lo;
            marginReq = 0.0;
            if(!OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, maxLots, price, marginReq))
                marginReq = 0.0;
        }

        ev.allowed = true;
        ev.recommendedLots = maxLots;
        ev.rejectionReason = RR_NONE;

        //--- Margin context for the recommended size (best effort).
        ev.marginRequired = marginReq;
        ev.freeMarginAfterTrade = freeMargin - marginReq;

        m_logger.LogInfo(StringFormat("ProductionRisk: allowed (maxLots %.2f)", maxLots));
        return ev;
    }

    virtual string GetName() { return m_name; }

private:
    string m_symbol;
    double m_marginBufferFactor;
    string m_name;
    CLogger m_logger;
};

#endif
