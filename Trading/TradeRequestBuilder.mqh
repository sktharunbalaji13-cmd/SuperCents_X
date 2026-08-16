#ifndef __TRADE_REQUEST_BUILDER_MQH__
#define __TRADE_REQUEST_BUILDER_MQH__

#include "../Entry/ExecutionPlanTypes.mqh"

class CTradeRequestBuilder
{
private:
    string  m_symbol;
    int     m_magicNumber;
    int     m_deviation;
    double  m_point;

public:
    CTradeRequestBuilder(void);
    ~CTradeRequestBuilder(void);

    void    SetSymbol(string symbol);
    void    SetMagicNumber(int magic);
    void    SetDeviation(int deviation);

    bool    Build(const ExecutionPlan &plan, double volume, MqlTradeRequest &request);
    //--- D1 (restart-stable broker correlation): emit the frozen B25-03A
    //    #<seq> comment form SCX-<side>-P<decisionId>#<seq>.  Domain proof:
    //    decisionId is int (<=10 digits) and seq <= EXEC_ID_MAX_SEQ (8
    //    digits), so the worst case "SCX-SELL-P2147483647#99999999" is 29
    //    chars <= the 31-char order-comment bound; this is INFALLIBLE (a
    //    plain StringFormat, never fails) and can therefore never produce a
    //    dangling INTENT when called after BeginExecution.
    void    SetCorrelationComment(MqlTradeRequest &request, const string side,
                                  const int decisionId, const ulong seq);
};

CTradeRequestBuilder::CTradeRequestBuilder(void)
    : m_symbol(_Symbol)
    , m_magicNumber(0)
    , m_deviation(3)
    , m_point(SymbolInfoDouble(_Symbol, SYMBOL_POINT))
{
    if(m_point <= 0)
        m_point = 0.00001;
}

CTradeRequestBuilder::~CTradeRequestBuilder(void)
{
}

void CTradeRequestBuilder::SetSymbol(string symbol) { m_symbol = symbol; }
void CTradeRequestBuilder::SetMagicNumber(int magic) { m_magicNumber = magic; }
void CTradeRequestBuilder::SetDeviation(int deviation) { m_deviation = deviation; }

bool CTradeRequestBuilder::Build(const ExecutionPlan &plan, double volume, MqlTradeRequest &request)
{
    ZeroMemory(request);

    request.action   = TRADE_ACTION_DEAL;
    request.symbol   = m_symbol;
    request.volume   = volume;
    request.deviation= m_deviation;
    request.magic    = m_magicNumber;
    request.sl       = plan.stopLoss;
    request.tp       = plan.takeProfit;

    if(plan.orderType == ORDER_TYPE_BUY)
    {
        request.type  = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        request.comment = StringFormat("SCX-BUY-P%d", plan.entryDecisionId);
    }
    else if(plan.orderType == ORDER_TYPE_SELL)
    {
        request.type  = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        request.comment = StringFormat("SCX-SELL-P%d", plan.entryDecisionId);
    }
    else
    {
        return false;
    }

    return true;
}

void CTradeRequestBuilder::SetCorrelationComment(MqlTradeRequest &request, const string side,
                                                 const int decisionId, const ulong seq)
{
    request.comment = StringFormat("SCX-%s-P%d#%llu", side, decisionId, seq);
}

#endif