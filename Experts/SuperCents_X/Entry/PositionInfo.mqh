//+------------------------------------------------------------------+
//|                                              PositionInfo.mqh      |
//|                                      Copyright 2026, SuperCents_X |
//+------------------------------------------------------------------+
#ifndef __POSITION_INFO_MQH__
#define __POSITION_INFO_MQH__

struct PositionInfo
{
    ulong    ticket;
    string   symbol;
    int      magic;
    ENUM_POSITION_TYPE type;
    double   volume;
    double   priceOpen;
    double   sl;
    double   tp;
    double   profit;
    double   swap;
    double   commission;
    datetime time;
    string   comment;

    PositionInfo(void)
        : ticket(0), symbol(""), magic(0), type(POSITION_TYPE_BUY)
        , volume(0.0), priceOpen(0.0), sl(0.0), tp(0.0)
        , profit(0.0), swap(0.0), commission(0.0)
        , time(0), comment("") {}

    bool Refresh(void)
    {
        if(ticket == 0)
            return false;
        if(!PositionSelectByTicket(ticket))
            return false;

        symbol   = PositionGetString(POSITION_SYMBOL);
        magic    = (int)PositionGetInteger(POSITION_MAGIC);
        type     = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        volume   = PositionGetDouble(POSITION_VOLUME);
        priceOpen= PositionGetDouble(POSITION_PRICE_OPEN);
        sl       = PositionGetDouble(POSITION_SL);
        tp       = PositionGetDouble(POSITION_TP);
        profit   = PositionGetDouble(POSITION_PROFIT);
        swap     = PositionGetDouble(POSITION_SWAP);
        commission=PositionGetDouble(POSITION_COMMISSION);
        time     = (datetime)PositionGetInteger(POSITION_TIME);
        comment  = PositionGetString(POSITION_COMMENT);
        return true;
    }
};

#endif