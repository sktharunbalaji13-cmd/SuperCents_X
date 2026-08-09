//+------------------------------------------------------------------+
//|                                          PositionManager.mqh       |
//|                                      Copyright 2026, SuperCents_X |
//+------------------------------------------------------------------+
#ifndef __POSITION_MANAGER_MQH__
#define __POSITION_MANAGER_MQH__

#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "PositionInfo.mqh"
#include "PendingOrderInfo.mqh"

class CPositionManager
{
private:
    CLogger m_logger;
    bool    m_isInitialized;

public:
    CPositionManager(void);
    ~CPositionManager(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    bool      HasPosition(string symbol, int magic);
    int       PositionCount(void) const;
    bool      GetPosition(string symbol, int magic, PositionInfo &out);
    bool      GetPositionByTicket(ulong ticket, PositionInfo &out);
    bool      SelectPosition(int index, PositionInfo &out);

    bool      HasPendingOrder(string symbol, int magic);
    int       PendingOrderCount(void) const;
    bool      GetPendingOrder(string symbol, int magic, PendingOrderInfo &out);
    bool      GetPendingOrderByTicket(ulong ticket, PendingOrderInfo &out);
};

CPositionManager::CPositionManager(void)
    : m_logger(MODULE_POSITION_MANAGER, "PositionManager")
    , m_isInitialized(false) {}

CPositionManager::~CPositionManager(void)
{
    Shutdown();
}

bool CPositionManager::Init(void)
{
    m_logger.LogInfo("Initializing PositionManager...");
    m_isInitialized = true;
    m_logger.LogInfo("PositionManager initialized");
    return true;
}

void CPositionManager::Update(void)
{
}

void CPositionManager::Shutdown(void)
{
    if(!m_isInitialized)
        return;
    m_logger.LogInfo("Shutting down PositionManager...");
    m_isInitialized = false;
    m_logger.LogInfo("PositionManager shutdown complete");
}

int CPositionManager::PositionCount(void) const
{
    return PositionsTotal();
}

int CPositionManager::PendingOrderCount(void) const
{
    return OrdersTotal();
}

bool CPositionManager::HasPosition(string symbol, int magic)
{
    if(!m_isInitialized)
        return false;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelect(PositionGetSymbol(i)))
        {
            if((int)PositionGetInteger(POSITION_MAGIC) == magic
            && PositionGetString(POSITION_SYMBOL) == symbol)
            {
                return true;
            }
        }
    }
    return false;
}

bool CPositionManager::GetPosition(string symbol, int magic, PositionInfo &out)
{
    if(!m_isInitialized)
        return false;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelect(PositionGetSymbol(i)))
        {
            if((int)PositionGetInteger(POSITION_MAGIC) == magic
            && PositionGetString(POSITION_SYMBOL) == symbol)
            {
                out.ticket    = PositionGetInteger(POSITION_TICKET);
                out.symbol    = PositionGetString(POSITION_SYMBOL);
                out.magic     = (int)PositionGetInteger(POSITION_MAGIC);
                out.type      = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                out.volume    = PositionGetDouble(POSITION_VOLUME);
                out.priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
                out.sl        = PositionGetDouble(POSITION_SL);
                out.tp        = PositionGetDouble(POSITION_TP);
                out.profit    = PositionGetDouble(POSITION_PROFIT);
                out.swap      = PositionGetDouble(POSITION_SWAP);
                out.commission= PositionGetDouble(POSITION_COMMISSION);
                out.time      = (datetime)PositionGetInteger(POSITION_TIME);
                out.comment   = PositionGetString(POSITION_COMMENT);
                return true;
            }
        }
    }
    return false;
}

bool CPositionManager::GetPositionByTicket(ulong ticket, PositionInfo &out)
{
    if(!m_isInitialized)
        return false;

    if(!PositionSelectByTicket(ticket))
        return false;

    out.ticket    = ticket;
    out.symbol    = PositionGetString(POSITION_SYMBOL);
    out.magic     = (int)PositionGetInteger(POSITION_MAGIC);
    out.type      = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    out.volume    = PositionGetDouble(POSITION_VOLUME);
    out.priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
    out.sl        = PositionGetDouble(POSITION_SL);
    out.tp        = PositionGetDouble(POSITION_TP);
    out.profit    = PositionGetDouble(POSITION_PROFIT);
    out.swap      = PositionGetDouble(POSITION_SWAP);
    out.commission= PositionGetDouble(POSITION_COMMISSION);
    out.time      = (datetime)PositionGetInteger(POSITION_TIME);
    out.comment   = PositionGetString(POSITION_COMMENT);
    return true;
}

bool CPositionManager::SelectPosition(int index, PositionInfo &out)
{
    if(!m_isInitialized)
        return false;

    string sym = PositionGetSymbol(index);
    if(sym == "")
        return false;

    if(!PositionSelect(sym))
        return false;

    out.ticket    = PositionGetInteger(POSITION_TICKET);
    out.symbol    = PositionGetString(POSITION_SYMBOL);
    out.magic     = (int)PositionGetInteger(POSITION_MAGIC);
    out.type      = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    out.volume    = PositionGetDouble(POSITION_VOLUME);
    out.priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
    out.sl        = PositionGetDouble(POSITION_SL);
    out.tp        = PositionGetDouble(POSITION_TP);
    out.profit    = PositionGetDouble(POSITION_PROFIT);
    out.swap      = PositionGetDouble(POSITION_SWAP);
    out.commission= PositionGetDouble(POSITION_COMMISSION);
    out.time      = (datetime)PositionGetInteger(POSITION_TIME);
    out.comment   = PositionGetString(POSITION_COMMENT);
    return true;
}

bool CPositionManager::HasPendingOrder(string symbol, int magic)
{
    if(!m_isInitialized)
        return false;

    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0)
            continue;

        if(!OrderSelect(ticket))
            continue;

        if((int)OrderGetInteger(ORDER_MAGIC) == magic
        && OrderGetString(ORDER_SYMBOL) == symbol)
        {
            ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(type == ORDER_TYPE_BUY_LIMIT  || type == ORDER_TYPE_BUY_STOP
            || type == ORDER_TYPE_SELL_LIMIT || type == ORDER_TYPE_SELL_STOP)
            {
                return true;
            }
        }
    }
    return false;
}

bool CPositionManager::GetPendingOrder(string symbol, int magic, PendingOrderInfo &out)
{
    if(!m_isInitialized)
        return false;

    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0)
            continue;

        if(!OrderSelect(ticket))
            continue;

        if((int)OrderGetInteger(ORDER_MAGIC) == magic
        && OrderGetString(ORDER_SYMBOL) == symbol)
        {
            out.ticket    = ticket;
            out.symbol    = OrderGetString(ORDER_SYMBOL);
            out.magic     = (int)OrderGetInteger(ORDER_MAGIC);
            out.type      = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            out.volume    = OrderGetDouble(ORDER_VOLUME_INITIAL);
            out.priceOpen = OrderGetDouble(ORDER_PRICE_OPEN);
            out.sl        = OrderGetDouble(ORDER_SL);
            out.tp        = OrderGetDouble(ORDER_TP);
            out.time      = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
            out.expiration= (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
            out.comment   = OrderGetString(ORDER_COMMENT);
            return true;
        }
    }
    return false;
}

bool CPositionManager::GetPendingOrderByTicket(ulong ticket, PendingOrderInfo &out)
{
    if(!m_isInitialized)
        return false;

    if(!OrderSelect(ticket))
        return false;

    out.ticket    = ticket;
    out.symbol    = OrderGetString(ORDER_SYMBOL);
    out.magic     = (int)OrderGetInteger(ORDER_MAGIC);
    out.type      = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
    out.volume    = OrderGetDouble(ORDER_VOLUME_INITIAL);
    out.priceOpen = OrderGetDouble(ORDER_PRICE_OPEN);
    out.sl        = OrderGetDouble(ORDER_SL);
    out.tp        = OrderGetDouble(ORDER_TP);
    out.time      = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
    out.expiration= (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
    out.comment   = OrderGetString(ORDER_COMMENT);
    return true;
}

#endif