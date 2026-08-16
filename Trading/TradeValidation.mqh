#ifndef __TRADE_VALIDATION_MQH__
#define __TRADE_VALIDATION_MQH__

#include "../Entry/ExecutionPlanTypes.mqh"
#include "TradeExecutionResult.mqh"

class CTradeValidation
{
private:
    string  m_symbol;
    double  m_point;

public:
    CTradeValidation(void);
    ~CTradeValidation(void);

    void SetSymbol(string symbol);

    //--- C7 (integrity): the price a market deal will actually execute at
    //    (Ask for BUY, Bid for SELL).  All stop/margin/risk checks use
    //    this price instead of the plan's resolved entry price, which can
    //    lag the market at deal time.
    double GetFillPrice(ENUM_ORDER_TYPE orderType) const;

    bool IsTradingAllowed(string &outReason);
    bool IsVolumeValid(double volume, string &outReason);
    bool AreStopsValid(const ExecutionPlan &plan, string &outReason);
    bool IsMarginSufficient(const ExecutionPlan &plan, double volume, string &outReason);
    bool ValidateAll(const ExecutionPlan &plan, double volume, string &outReason);
};

CTradeValidation::CTradeValidation(void)
    : m_symbol(_Symbol)
    , m_point(SymbolInfoDouble(_Symbol, SYMBOL_POINT))
{
    if(m_point <= 0)
        m_point = 0.00001;
}

CTradeValidation::~CTradeValidation(void)
{
}

void CTradeValidation::SetSymbol(string symbol) { m_symbol = symbol; }

double CTradeValidation::GetFillPrice(ENUM_ORDER_TYPE orderType) const
{
    if(orderType == ORDER_TYPE_BUY)
        return SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    if(orderType == ORDER_TYPE_SELL)
        return SymbolInfoDouble(m_symbol, SYMBOL_BID);
    return 0.0;
}

bool CTradeValidation::IsTradingAllowed(string &outReason)
{
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    {
        outReason = "Terminal trading is disabled";
        return false;
    }

    if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
    {
        outReason = "Expert trading is disabled";
        return false;
    }

    ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE);
    if(tradeMode == SYMBOL_TRADE_MODE_DISABLED || tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
    {
        outReason = StringFormat("Symbol %s trading mode restricts execution", m_symbol);
        return false;
    }

    return true;
}

bool CTradeValidation::IsVolumeValid(double volume, string &outReason)
{
    double volMin  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double volMax  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    double volStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);

    if(volume < volMin || volume > volMax)
    {
        outReason = StringFormat("Volume %.2f outside range [%.2f, %.2f]", volume, volMin, volMax);
        return false;
    }

    double remainder = MathMod(volume - volMin, volStep);
    if(remainder > 1e-10)
    {
        outReason = StringFormat("Volume %.2f not aligned to step %.2f", volume, volStep);
        return false;
    }

    return true;
}

bool CTradeValidation::AreStopsValid(const ExecutionPlan &plan, string &outReason)
{
    double fillPrice = GetFillPrice(plan.orderType);
    if(fillPrice <= 0.0)
    {
        outReason = "Cannot resolve fill price for order type";
        return false;
    }

    if(!MathIsValidNumber(plan.stopLoss) || !MathIsValidNumber(plan.takeProfit) ||
       !MathIsValidNumber(plan.entryPrice) || !MathIsValidNumber(fillPrice))
    {
        outReason = "Non-finite price in plan";
        return false;
    }

    //--- C6 (integrity): directional stop validation vs the FILL price.
    //    A BUY must stop below the fill and target above it; a SELL the
    //    mirror.  Inverted combos (e.g. a stop above entry) were
    //    previously accepted because only MathAbs distances were checked.
    if(plan.orderType == ORDER_TYPE_BUY)
    {
        if(plan.stopLoss >= fillPrice)
        {
            outReason = StringFormat("BUY stop loss %.5f not below fill price %.5f", plan.stopLoss, fillPrice);
            return false;
        }
        if(plan.takeProfit <= fillPrice)
        {
            outReason = StringFormat("BUY take profit %.5f not above fill price %.5f", plan.takeProfit, fillPrice);
            return false;
        }
    }
    else if(plan.orderType == ORDER_TYPE_SELL)
    {
        if(plan.stopLoss <= fillPrice)
        {
            outReason = StringFormat("SELL stop loss %.5f not above fill price %.5f", plan.stopLoss, fillPrice);
            return false;
        }
        if(plan.takeProfit >= fillPrice)
        {
            outReason = StringFormat("SELL take profit %.5f not below fill price %.5f", plan.takeProfit, fillPrice);
            return false;
        }
    }
    else
    {
        outReason = "Unsupported order type";
        return false;
    }

    double stopLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * m_point;
    double slDist    = MathAbs(fillPrice - plan.stopLoss);
    double tpDist    = MathAbs(plan.takeProfit - fillPrice);

    if(slDist < stopLevel)
    {
        outReason = StringFormat("Stop loss %.0f pts below min stop level %.0f pts", slDist / m_point, stopLevel / m_point);
        return false;
    }

    if(tpDist < stopLevel)
    {
        outReason = StringFormat("Take profit %.0f pts below min stop level %.0f pts", tpDist / m_point, stopLevel / m_point);
        return false;
    }

    return true;
}

bool CTradeValidation::IsMarginSufficient(const ExecutionPlan &plan, double volume, string &outReason)
{
    ENUM_ORDER_TYPE orderType = plan.orderType;

    //--- C7 (integrity): margin is calculated at the price the deal will
    //    actually fill at, not the plan's resolved entry price.
    double fillPrice = GetFillPrice(orderType);
    if(fillPrice <= 0.0)
    {
        outReason = "Cannot resolve fill price for margin calculation";
        return false;
    }

    double margin = 0.0;
    if(!OrderCalcMargin(orderType, m_symbol, volume, fillPrice, margin))
    {
        outReason = "Failed to calculate margin requirement";
        return false;
    }

    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    if(margin > freeMargin)
    {
        outReason = StringFormat("Insufficient margin: required %.2f, free %.2f", margin, freeMargin);
        return false;
    }

    return true;
}

bool CTradeValidation::ValidateAll(const ExecutionPlan &plan, double volume, string &outReason)
{
    if(!IsTradingAllowed(outReason))
        return false;

    if(!IsVolumeValid(volume, outReason))
        return false;

    if(!AreStopsValid(plan, outReason))
        return false;

    if(!IsMarginSufficient(plan, volume, outReason))
        return false;

    return true;
}

#endif