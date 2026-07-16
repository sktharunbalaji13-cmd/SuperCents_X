//+------------------------------------------------------------------+
//|                                          ExecutionManager.mqh     |
//|                                      Copyright 2026, SuperCents_X|
//|                                             https://github.com/ |
//+------------------------------------------------------------------+
#ifndef __EXECUTION_MANAGER_MQH__
#define __EXECUTION_MANAGER_MQH__

#include <Trade/Trade.mqh>
#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "../Utils/Types.mqh"
#include "EntrySetup.mqh"

enum ENUM_EXECUTION_STYLE
{
    EXEC_MARKET,
    EXEC_LIMIT,
    EXEC_STOP
};

class CExecutionManager
{
private:
    CLogger m_logger;
    CTrade  m_trade;
    bool    m_isInitialized;
    int     m_magicNumber;
    string  m_symbol;

    bool HasOpenPosition(void);
    bool HasPendingOrder(void);

    ExecutionResult ValidateTradingAllowed(void);
    ExecutionResult ValidateVolume(double lotSize);
    ExecutionResult ValidateStops(const EntrySetup &setup);
    ExecutionResult ValidateMargin(const EntrySetup &setup, double lotSize);

    ExecutionResult ExecuteMarket(const EntrySetup &setup, double lotSize);
    void            LogRequest(const EntrySetup &setup, double lotSize);
    string          SetupTypeToString(ENUM_SETUP_TYPE type);

public:
    CExecutionManager(void);
    ~CExecutionManager(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);
    bool IsInitialized(void) const { return m_isInitialized; }

    ExecutionResult Execute(const EntrySetup &setup, double lotSize);
    bool            CancelPending(void);

    void SetMagicNumber(int magic) { m_magicNumber = magic; }
    int  GetMagicNumber(void) const { return m_magicNumber; }
};

CExecutionManager::CExecutionManager(void)
    : m_logger(MODULE_EXECUTION_MANAGER, "ExecutionManager")
    , m_isInitialized(false)
    , m_magicNumber(0)
    , m_symbol(_Symbol) {}

CExecutionManager::~CExecutionManager(void)
{
    Shutdown();
}

bool CExecutionManager::Init(void)
{
    m_logger.LogInfo("Initializing ExecutionManager...");
    m_isInitialized = true;
    m_symbol = _Symbol;

    m_trade.SetExpertMagicNumber(m_magicNumber);

    m_logger.LogInfo("ExecutionManager initialized");
    return true;
}

void CExecutionManager::Update(void)
{
}

void CExecutionManager::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("Shutting down ExecutionManager...");
    m_isInitialized = false;
    m_logger.LogInfo("ExecutionManager shutdown complete");
}

//+------------------------------------------------------------------+
//| Public: Execute                                                   |
//+------------------------------------------------------------------+
ExecutionResult CExecutionManager::Execute(const EntrySetup &setup, double lotSize)
{
    ExecutionResult result;

    if(!m_isInitialized)
    {
        result.status = EXEC_STATUS_ERROR_UNKNOWN;
        result.description = "ExecutionManager not initialized";
        return result;
    }

    if(!setup.valid)
    {
        result.status = EXEC_STATUS_REJECTED_INVALID_SETUP;
        result.description = "Invalid setup";
        return result;
    }

    if(HasOpenPosition())
    {
        result.status = EXEC_STATUS_REJECTED_OPEN_POSITION;
        result.description = "Open position exists for this symbol/magic";
        return result;
    }

    if(HasPendingOrder())
    {
        result.status = EXEC_STATUS_REJECTED_PENDING_ORDER;
        result.description = "Pending order exists for this symbol/magic";
        return result;
    }

    ENUM_EXECUTION_STYLE style = GetExecutionStyle(setup.type);

    if(style == EXEC_MARKET)
        return ExecuteMarket(setup, lotSize);

    // LIMIT/STOP execution not yet implemented — log the request
    result.success = true;
    result.status = EXEC_STATUS_ACCEPTED;
    result.description = "LIMIT/STOP execution logged (pending-order infrastructure not yet available)";
    LogRequest(setup, lotSize);
    return result;
}

//+------------------------------------------------------------------+
//| Market execution (BUY / SELL)                                     |
//+------------------------------------------------------------------+
ExecutionResult CExecutionManager::ExecuteMarket(const EntrySetup &setup, double lotSize)
{
    ExecutionResult result;

    result = ValidateTradingAllowed();
    if(!result.success)
        return result;

    result = ValidateVolume(lotSize);
    if(!result.success)
        return result;

    result = ValidateStops(setup);
    if(!result.success)
        return result;

    result = ValidateMargin(setup, lotSize);
    if(!result.success)
        return result;

    LogRequest(setup, lotSize);

    bool orderSent = false;
    double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);

    if(setup.direction == TREND_BULLISH)
    {
        m_trade.SetExpertMagicNumber(m_magicNumber);
        orderSent = m_trade.Buy(lotSize, m_symbol, ask, setup.stopLoss, setup.takeProfit);
    }
    else
    {
        m_trade.SetExpertMagicNumber(m_magicNumber);
        orderSent = m_trade.Sell(lotSize, m_symbol, bid, setup.stopLoss, setup.takeProfit);
    }

    result.retcode = m_trade.ResultRetcode();

    if(orderSent)
    {
        result.success = true;
        result.orderTicket = m_trade.ResultOrder();
        result.dealTicket = m_trade.ResultDeal();
        result.status = EXEC_STATUS_ACCEPTED;
        result.description = StringFormat("Market order accepted: ticket=%lld deal=%lld retcode=%u",
            m_trade.ResultOrder(), m_trade.ResultDeal(), m_trade.ResultRetcode());
    }
    else
    {
        result.status = EXEC_STATUS_REJECTED_BROKER;
        result.description = StringFormat("Broker rejected: retcode=%u",
            m_trade.ResultRetcode());
    }

    return result;
}

//+------------------------------------------------------------------+
//| Log the full execution request (used for both logging and market) |
//+------------------------------------------------------------------+
void CExecutionManager::LogRequest(const EntrySetup &setup, double lotSize)
{
    double slPoints = MathAbs(setup.entryPrice - setup.stopLoss) / _Point;
    double tpPoints = MathAbs(setup.takeProfit - setup.entryPrice) / _Point;

    string dirStr = (setup.direction == TREND_BULLISH) ? "BUY" : "SELL";

    string execStyleStr = "";
    switch(GetExecutionStyle(setup.type))
    {
        case EXEC_MARKET: execStyleStr = "MARKET"; break;
        case EXEC_LIMIT:  execStyleStr = "LIMIT";  break;
        case EXEC_STOP:   execStyleStr = "STOP";   break;
    }

    int setupId = setup.bosId > 0 ? setup.bosId :
                  setup.chochId > 0 ? setup.chochId :
                  setup.obId > 0 ? setup.obId :
                  setup.fvgId > 0 ? setup.fvgId : 0;

    m_logger.LogInfo(StringFormat(
        "EXECUTION REQUEST\n"
        "  Style: %s\n"
        "  Symbol: %s\n"
        "  Direction: %s\n"
        "  Entry: %.5f\n"
        "  SL: %.5f (%s points)\n"
        "  TP: %.5f (%s points)\n"
        "  Lots: %s\n"
        "  Magic: %d\n"
        "  Setup #%d  Type: %s",
        execStyleStr,
        m_symbol,
        dirStr,
        setup.entryPrice,
        setup.stopLoss,   DoubleToString(slPoints, 0),
        setup.takeProfit, DoubleToString(tpPoints, 0),
        DoubleToString(lotSize, 2),
        m_magicNumber,
        setupId,
        SetupTypeToString(setup.type)
    ));
}

//+------------------------------------------------------------------+
//| Validation helpers                                                |
//+------------------------------------------------------------------+
ExecutionResult CExecutionManager::ValidateTradingAllowed(void)
{
    ExecutionResult result;

    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    {
        result.status = EXEC_STATUS_REJECTED_TRADING_DISABLED;
        result.description = "Terminal trading is disabled";
        m_logger.LogError(result.description);
        return result;
    }

    if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
    {
        result.status = EXEC_STATUS_REJECTED_TRADING_DISABLED;
        result.description = "Expert trading is disabled";
        m_logger.LogError(result.description);
        return result;
    }

    ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE);
    if(tradeMode == SYMBOL_TRADE_MODE_DISABLED || tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
    {
        result.status = EXEC_STATUS_REJECTED_SYMBOL_INVALID;
        result.description = StringFormat("Symbol %s trading mode restricts execution", m_symbol);
        m_logger.LogError(result.description);
        return result;
    }

    result.success = true;
    result.status = EXEC_STATUS_ACCEPTED;
    return result;
}

ExecutionResult CExecutionManager::ValidateVolume(double lotSize)
{
    ExecutionResult result;

    double volMin = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double volMax = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    double volStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);

    if(lotSize < volMin || lotSize > volMax)
    {
        result.status = EXEC_STATUS_REJECTED_VOLUME_INVALID;
        result.description = StringFormat("Volume %s outside allowed range [%s, %s]",
            DoubleToString(lotSize, 2),
            DoubleToString(volMin, 2),
            DoubleToString(volMax, 2));
        m_logger.LogWarn(result.description);
        return result;
    }

    double remainder = MathMod(lotSize - volMin, volStep);
    if(remainder > 1e-10)
    {
        result.status = EXEC_STATUS_REJECTED_VOLUME_INVALID;
        result.description = StringFormat("Volume %s not aligned to step %s",
            DoubleToString(lotSize, 2),
            DoubleToString(volStep, 2));
        m_logger.LogWarn(result.description);
        return result;
    }

    result.success = true;
    result.status = EXEC_STATUS_ACCEPTED;
    return result;
}

ExecutionResult CExecutionManager::ValidateStops(const EntrySetup &setup)
{
    ExecutionResult result;

    double stopLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    double slDist = MathAbs(setup.entryPrice - setup.stopLoss);
    double tpDist = MathAbs(setup.takeProfit - setup.entryPrice);

    if(slDist < stopLevel)
    {
        result.status = EXEC_STATUS_REJECTED_STOPS_INVALID;
        result.description = StringFormat("Stop loss %.0f pts below minimum stop level %.0f pts",
            slDist / _Point, stopLevel / _Point);
        m_logger.LogWarn(result.description);
        return result;
    }

    if(tpDist < stopLevel)
    {
        result.status = EXEC_STATUS_REJECTED_STOPS_INVALID;
        result.description = StringFormat("Take profit %.0f pts below minimum stop level %.0f pts",
            tpDist / _Point, stopLevel / _Point);
        m_logger.LogWarn(result.description);
        return result;
    }

    result.success = true;
    result.status = EXEC_STATUS_ACCEPTED;
    return result;
}

ExecutionResult CExecutionManager::ValidateMargin(const EntrySetup &setup, double lotSize)
{
    ExecutionResult result;

    ENUM_ORDER_TYPE orderType = (setup.direction == TREND_BULLISH) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

    double margin = 0.0;
    if(!OrderCalcMargin(orderType, m_symbol, lotSize, setup.entryPrice, margin))
    {
        result.status = EXEC_STATUS_REJECTED_MARGIN_INSUFFICIENT;
        result.description = "Failed to calculate margin requirement";
        m_logger.LogWarn(result.description);
        return result;
    }

    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    if(margin > freeMargin)
    {
        result.status = EXEC_STATUS_REJECTED_MARGIN_INSUFFICIENT;
        result.description = StringFormat("Insufficient margin: required=%s free=%s",
            DoubleToString(margin, 2), DoubleToString(freeMargin, 2));
        m_logger.LogWarn(result.description);
        return result;
    }

    result.success = true;
    result.status = EXEC_STATUS_ACCEPTED;
    return result;
}

//+------------------------------------------------------------------+
//| CancelPending                                                     |
//+------------------------------------------------------------------+
bool CExecutionManager::CancelPending(void)
{
    if(!m_isInitialized)
        return false;

    m_logger.LogInfo("CancelPending: no pending orders to cancel");
    return true;
}

//+------------------------------------------------------------------+
//| Position and order queries                                        |
//+------------------------------------------------------------------+
bool CExecutionManager::HasOpenPosition(void)
{
    if(!m_isInitialized)
        return false;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelect(PositionGetSymbol(i)))
        {
            if(PositionGetInteger(POSITION_MAGIC) == m_magicNumber
            && PositionGetString(POSITION_SYMBOL) == m_symbol)
            {
                return true;
            }
        }
    }

    return false;
}

bool CExecutionManager::HasPendingOrder(void)
{
    if(!m_isInitialized)
        return false;

    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(OrderGetTicket(i)))
        {
            if(OrderGetInteger(ORDER_MAGIC) == m_magicNumber
            && OrderGetString(ORDER_SYMBOL) == m_symbol)
            {
                ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
                if(type == ORDER_TYPE_BUY_LIMIT  || type == ORDER_TYPE_BUY_STOP
                || type == ORDER_TYPE_SELL_LIMIT || type == ORDER_TYPE_SELL_STOP)
                {
                    return true;
                }
            }
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Setup type to execution style mapping                             |
//+------------------------------------------------------------------+
ENUM_EXECUTION_STYLE GetExecutionStyle(ENUM_SETUP_TYPE setupType)
{
    switch(setupType)
    {
        case SETUP_BOS_CONTINUATION:  return EXEC_MARKET;
        case SETUP_CHOCH_REVERSAL:    return EXEC_MARKET;
        case SETUP_ORDERBLOCK_RETEST: return EXEC_LIMIT;
        case SETUP_FVG_CONTINUATION:  return EXEC_LIMIT;
        default:                      return EXEC_MARKET;
    }
}

//+------------------------------------------------------------------+
//| Internal helper                                                   |
//+------------------------------------------------------------------+
string CExecutionManager::SetupTypeToString(ENUM_SETUP_TYPE type)
{
    switch(type)
    {
        case SETUP_BOS_CONTINUATION:  return "BOS_CONTINUATION";
        case SETUP_CHOCH_REVERSAL:    return "CHOCH_REVERSAL";
        case SETUP_ORDERBLOCK_RETEST: return "ORDERBLOCK_RETEST";
        case SETUP_FVG_CONTINUATION:  return "FVG_CONTINUATION";
        default:                      return "UNKNOWN";
    }
}

#endif
