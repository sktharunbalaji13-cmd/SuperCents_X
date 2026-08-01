//+------------------------------------------------------------------+
//|                                  ProductionRiskEvaluator.mqh      |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 14 (v2.9)       |
//+------------------------------------------------------------------+
//  Real-account risk evaluator (live + tester).  Rejects positions when
//  the account cannot absorb the trade: insufficient free margin, no
//  margin room for the minimum lot, or trading disabled on the symbol.
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
        , m_rejectionReason("")
        , m_name("ProductionRisk")
        , m_logger(MODULE_UNKNOWN, "ProductionRisk")
    {}

    virtual bool CanOpenPosition(double confidence, double &maxLots)
    {
        m_rejectionReason = "";

        int tradeMode = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE);
        if(tradeMode < (int)SYMBOL_TRADE_MODE_FULL)
        {
            m_rejectionReason = "trading disabled for " + m_symbol;
            return false;
        }

        double volumeMin = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
        double volumeMax = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
        if(volumeMin <= 0.0 || volumeMax <= 0.0)
        {
            m_rejectionReason = "invalid volume limits for " + m_symbol;
            return false;
        }

        double price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        if(price <= 0.0)
            price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        if(price <= 0.0)
        {
            m_rejectionReason = "no market price for " + m_symbol;
            return false;
        }

        //--- Can we even afford the minimum lot?
        double marginMin = 0.0;
        if(!OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, volumeMin, price, marginMin))
        {
            m_rejectionReason = "OrderCalcMargin failed for " + m_symbol;
            return false;
        }

        double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        if(marginMin * m_marginBufferFactor > freeMargin)
        {
            m_rejectionReason = StringFormat("insufficient margin (need %.2f, free %.2f)",
                                             marginMin, freeMargin);
            return false;
        }

        //--- Max affordable lots by margin, clamped to the broker limits.
        double maxByMargin = (freeMargin / m_marginBufferFactor) * volumeMin / marginMin;
        maxLots = maxByMargin;
        if(maxLots > volumeMax)
            maxLots = volumeMax;

        m_logger.LogInfo(StringFormat("ProductionRisk: allowed (maxLots %.2f)", maxLots));
        return true;
    }

    virtual string GetRejectionReason() { return m_rejectionReason; }
    virtual string GetName()            { return m_name; }

private:
    string m_symbol;
    double m_marginBufferFactor;
    string m_rejectionReason;
    string m_name;
    CLogger m_logger;
};

#endif


