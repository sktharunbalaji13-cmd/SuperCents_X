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
    double stopLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * m_point;
    double slDist    = MathAbs(plan.entryPrice - plan.stopLoss);
    double tpDist    = MathAbs(plan.takeProfit - plan.entryPrice);

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

    double margin = 0.0;
    if(!OrderCalcMargin(orderType, m_symbol, volume, plan.entryPrice, margin))
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