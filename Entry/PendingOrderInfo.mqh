//+------------------------------------------------------------------+
//|                                        PendingOrderInfo.mqh        |
//|                                      Copyright 2026, SuperCents_X |
//+------------------------------------------------------------------+
#ifndef __PENDING_ORDER_INFO_MQH__
#define __PENDING_ORDER_INFO_MQH__

struct PendingOrderInfo
{
    ulong    ticket;
    string   symbol;
    int      magic;
    ENUM_ORDER_TYPE type;
    double   volume;
    double   priceOpen;
    double   sl;
    double   tp;
    datetime time;
    datetime expiration;
    string   comment;

    PendingOrderInfo(void)
        : ticket(0), symbol(""), magic(0), type(ORDER_TYPE_BUY_LIMIT)
        , volume(0.0), priceOpen(0.0), sl(0.0), tp(0.0)
        , time(0), expiration(0), comment("") {}

    bool Refresh(void)
    {
        if(ticket == 0)
            return false;
        if(!OrderSelect(ticket))
            return false;

        symbol    = OrderGetString(ORDER_SYMBOL);
        magic     = (int)OrderGetInteger(ORDER_MAGIC);
        type      = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        volume    = OrderGetDouble(ORDER_VOLUME_INITIAL);
        priceOpen = OrderGetDouble(ORDER_PRICE_OPEN);
        sl        = OrderGetDouble(ORDER_SL);
        tp        = OrderGetDouble(ORDER_TP);
        time      = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
        expiration= (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
        comment   = OrderGetString(ORDER_COMMENT);
        return true;
    }
};

#endif