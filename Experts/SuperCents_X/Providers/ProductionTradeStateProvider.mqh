//+------------------------------------------------------------------+
//|                                ProductionTradeStateProvider.mqh   |
//|                                      Copyright 2026, SuperCents_X|
//|                                             Sprint 14 (v2.9)       |
//+------------------------------------------------------------------+
//  Real-account trade state provider (live + tester).  Answers the
//  cooldown / position checks from the terminal history instead of the
//  permissive shadow values.
//+------------------------------------------------------------------+
#ifndef __PRODUCTION_TRADE_STATE_PROVIDER_MQH__
#define __PRODUCTION_TRADE_STATE_PROVIDER_MQH__

#include "../Entry/Validators/ITradeStateProvider.mqh"

class CProductionTradeStateProvider : public ITradeStateProvider
{
public:
    CProductionTradeStateProvider(const string symbol, long magicNumber)
        : m_symbol(symbol)
        , m_magicNumber(magicNumber)
        , m_name("ProductionTradeState")
    {}

    //--- Bars since the last closed deal on this symbol+magic (0 if none).
    virtual int GetBarsSinceLastTrade()
    {
        datetime last = GetLastTradeTime();
        if(last == 0)
            return INT_MAX;

        int shift = iBarShift(m_symbol, PERIOD_CURRENT, last, false);
        if(shift < 0)
            shift = (int)((TimeCurrent() - last) / PeriodSeconds(PERIOD_CURRENT));
        return shift;
    }

    //--- True when an open position exists for this symbol+magic.
    virtual bool HasOpenPosition()
    {
        for(int i = 0; i < PositionsTotal(); i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0)
                continue;
            if(!PositionSelectByTicket(ticket))
                continue;
            if(PositionGetString(POSITION_SYMBOL) != m_symbol)
                continue;
            if((long)PositionGetInteger(POSITION_MAGIC) != m_magicNumber)
                continue;
            return true;
        }
        return false;
    }

    virtual datetime GetLastTradeTime()
    {
        datetime last = 0;
        HistorySelect(0, TimeCurrent());
        for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket == 0)
                continue;
            if(HistoryDealGetString(ticket, DEAL_SYMBOL) != m_symbol)
                continue;
            if((long)HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magicNumber)
                continue;
            int type = (int)HistoryDealGetInteger(ticket, DEAL_TYPE);
            if(type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL)
            {
                last = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
                break;
            }
        }
        return last;
    }

    virtual string GetName() { return m_name; }

private:
    string m_symbol;
    long   m_magicNumber;
    string m_name;
};

#endif
