#ifndef __TRADING_TRADE_MANAGER_MQH__
#define __TRADING_TRADE_MANAGER_MQH__

#include <Trade/Trade.mqh>
#include "../Core/Logger.mqh"
#include "../Utils/Constants.mqh"
#include "../Entry/ExecutionPlanTypes.mqh"
#include "../Entry/ExecutionPlanner.mqh"
#include "../Risk/PositionSizer.mqh"
#include "TradeExecutionResult.mqh"
#include "ExecutionTruth.mqh"
#include "TradeRequestBuilder.mqh"
#include "TradeValidation.mqh"

class CTradeManager
{
private:
    CLogger                 m_logger;
    CTrade                  m_trade;
    CTradeRequestBuilder    m_requestBuilder;
    CTradeValidation        m_validation;
    CExecutionPlanner       *m_planner;

    bool                    m_isInitialized;
    bool                    m_executionEnabled;
    string                  m_symbol;
    double                  m_lotSize;
    int                     m_maxSlippage;
    int                     m_magicNumber;

    //--- C2 (integrity): live position sizing.  When a sizer and a
    //    positive risk % are configured, the volume is derived from the
    //    stop distance at the FILL price; otherwise m_lotSize is a fallback.
    CPositionSizer          *m_positionSizer;
    double                  m_riskPercent;
    //--- C3 (integrity): max open positions for this symbol + magic.
    int                     m_maxPositionsPerSymbol;

    ulong                   m_submittedIds[];
    int                     m_submittedCount;

    int     m_totalReceived;
    int     m_totalSubmitted;
    int     m_totalSucceeded;
    int     m_totalFailed;
    int     m_totalDuplicates;
    int     m_totalBlocked;
    double  m_totalFilledPrice;

    bool    IsAlreadySubmitted(ulong planId);
    void    RecordSubmitted(ulong planId);
    void    LogOrderSent(const TradeExecutionResult &result);
    void    LogOrderFailed(const TradeExecutionResult &result);
    string  RetcodeToString(uint retcode);
    //--- C3 (integrity): count of open positions owned by this EA
    //    (symbol + magic match) used by the position gate.
    int     CountOpenPositions(void) const;

public:
    CTradeManager(void);
    ~CTradeManager(void);

    bool Init(void);
    void Update(void);
    void Shutdown(void);

    void SetPlanner(CExecutionPlanner *planner);
    void SetLotSize(double lotSize);
    void SetMagicNumber(int magic);
    void SetSymbol(string symbol);
    void SetDeviation(int deviation);
    void SetExecutionEnabled(bool enabled) { m_executionEnabled = enabled; }
    //--- C2/C3 (integrity) configuration entry points.
    void SetPositionSizer(CPositionSizer *sizer) { m_positionSizer = sizer; }
    void SetRiskPercent(double pct) { m_riskPercent = fmax(pct, 0.0); }
    void SetMaxPositionsPerSymbol(int max) { m_maxPositionsPerSymbol = MathMax(max, 1); }
    int  GetOpenPositionCount(void) const { return CountOpenPositions(); }
    double GetRiskPercent(void) const { return m_riskPercent; }
    int  GetMaxPositionsPerSymbol(void) const { return m_maxPositionsPerSymbol; }
};

CTradeManager::CTradeManager(void)
    : m_logger(MODULE_TRADING, "TradeManager")
    , m_planner(NULL)
    , m_isInitialized(false)
    , m_executionEnabled(true)
    , m_symbol(_Symbol)
    , m_lotSize(0.01)
    , m_maxSlippage(3)
    , m_magicNumber(0)
    , m_positionSizer(NULL)
    , m_riskPercent(0.0)
    , m_maxPositionsPerSymbol(1)
    , m_submittedCount(0)
    , m_totalReceived(0)
    , m_totalSubmitted(0)
    , m_totalSucceeded(0)
    , m_totalFailed(0)
    , m_totalDuplicates(0)
    , m_totalBlocked(0)
    , m_totalFilledPrice(0.0)
{
}

CTradeManager::~CTradeManager(void)
{
    Shutdown();
}

bool CTradeManager::Init(void)
{
    if(m_isInitialized)
    {
        m_logger.LogWarn("TradeManager already initialized");
        return true;
    }

    m_logger.LogInfo("Initializing TradeManager...");

    m_symbol = _Symbol;
    m_submittedCount = 0;

    m_requestBuilder.SetSymbol(m_symbol);
    m_requestBuilder.SetDeviation(m_maxSlippage);
    m_validation.SetSymbol(m_symbol);

    m_isInitialized = true;
    m_logger.LogInfo("TradeManager initialized");
    return true;
}

void CTradeManager::SetPlanner(CExecutionPlanner *planner) { m_planner = planner; }
void CTradeManager::SetLotSize(double lotSize) { m_lotSize = fmax(lotSize, SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN)); }
void CTradeManager::SetMagicNumber(int magic) { m_magicNumber = magic; m_requestBuilder.SetMagicNumber(magic); m_trade.SetExpertMagicNumber(magic); }
void CTradeManager::SetSymbol(string symbol) { m_symbol = symbol; m_requestBuilder.SetSymbol(symbol); m_validation.SetSymbol(symbol); }
void CTradeManager::SetDeviation(int deviation) { m_maxSlippage = deviation; m_requestBuilder.SetDeviation(deviation); }

int CTradeManager::CountOpenPositions(void) const
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        string sym = PositionGetSymbol(i);
        if(sym == "" || sym != m_symbol)
            continue;
        if(!PositionSelect(sym))
            continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != m_magicNumber)
            continue;
        count++;
    }
    return count;
}

void CTradeManager::Update(void)
{
    if(!m_isInitialized || m_planner == NULL)
        return;

    //--- Execution gating (Sprint 17.7A): the legacy execution pipeline
    //    (ExecutionPlanner -> CTradeManager) must match the documented
    //    entry-mode contract.  Only ENTRY_MODE_LEGACY may send orders;
    //    SHADOW/NEW collection runs are shadow-only ("execution reserved").
    if(!m_executionEnabled)
        return;

    int planCount = m_planner.GetPlanCount();
    if(planCount == 0)
        return;

    for(int i = 0; i < planCount; i++)
    {
        ExecutionPlan plan;
        if(!m_planner.GetPlan(i, plan))
            continue;

        if(plan.status != PLAN_EXECUTABLE)
            continue;

        ulong planId = plan.entryDecisionId;

        m_totalReceived++;

        if(IsAlreadySubmitted(planId))
        {
            m_totalDuplicates++;
            continue;
        }

        //--- C3 (integrity): position gate.  Once the per-symbol cap is
        //    reached (live positions with this magic+symbol), no further
        //    plans are executed.  The cap is checked against the live
        //    account so a plan is only skipped while a position is open.
        if(CountOpenPositions() >= m_maxPositionsPerSymbol)
        {
            m_totalBlocked++;
            m_logger.LogInfo(StringFormat(
                "ORDER-BLOCKED-POSITION-GATE Plan=%lld Symbol=%s Open=%d Max=%d",
                planId, m_symbol, CountOpenPositions(), m_maxPositionsPerSymbol));
            continue;
        }

        //--- C7 (integrity): resolve the execution (fill) price first.
        //    All downstream risk math (stop distance, sizing, margin,
        //    directional stop checks) uses this price, not the plan's
        //    resolved entry price (which can lag the market at deal time).
        double fillPrice = m_validation.GetFillPrice(plan.orderType);
        if(fillPrice <= 0.0)
        {
            m_logger.LogInfo(StringFormat(
                "ORDER-REJECTED-FILL Plan=%lld Symbol=%s orderType=%d",
                planId, m_symbol, (int)plan.orderType));
            if(m_planner != NULL)
                m_planner.SetPlanStatus(i, PLAN_REJECTED);
            m_totalFailed++;
            continue;
        }

        string validationReason = "";
        if(!m_validation.ValidateAll(plan, m_lotSize, validationReason))
        {
            //--- H6 (integrity): a permanent validation failure rejects the
            //    plan itself (it is not recorded as submitted, so no dedup
            //    pollution; the rejected status makes it non-retryable).
            TradeExecutionResult failResult;
            failResult.executionPlanId = planId;
            failResult.submitted = false;
            failResult.retcode = 0;
            failResult.retcodeDescription = validationReason;
            failResult.rationale = validationReason;
            failResult.executionTime = TimeCurrent();
            LogOrderFailed(failResult);
            if(m_planner != NULL)
                m_planner.SetPlanStatus(i, PLAN_REJECTED);
            m_totalFailed++;
            continue;
        }

        //--- C2 (integrity): position sizing from the stop distance at the
        //    FILL price and the configured risk % of account equity.
        double volume = m_lotSize;
        double stopDistancePoints = 0.0;
        {
            double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
            if(point > 0.0)
                stopDistancePoints = MathAbs(fillPrice - plan.stopLoss) / point;
        }
        if(m_positionSizer != NULL && m_riskPercent > 0.0 && stopDistancePoints > 0.0)
        {
            PositionSizingResult sizing = m_positionSizer.CalculateCached(
                m_riskPercent, stopDistancePoints, AccountInfoDouble(ACCOUNT_EQUITY));
            if(sizing.valid && sizing.lots > 0.0)
            {
                volume = sizing.lots;
                m_logger.LogInfo(StringFormat(
                    "POSITION-SIZING Plan=%lld risk=%.2f%% stop=%.0fpts equity=%.2f lots=%.2f risk$=%.2f",
                    planId, m_riskPercent, stopDistancePoints,
                    AccountInfoDouble(ACCOUNT_EQUITY), sizing.lots, sizing.dollarRisk));
            }
            else
            {
                m_logger.LogInfo(StringFormat(
                    "POSITION-SIZING-FALLBACK Plan=%lld reason=%s lots=%.2f",
                    planId, sizing.validationMessage, m_lotSize));
            }
        }

        if(!m_validation.IsVolumeValid(volume, validationReason))
        {
            TradeExecutionResult failResult;
            failResult.executionPlanId = planId;
            failResult.submitted = false;
            failResult.retcode = 0;
            failResult.retcodeDescription = validationReason;
            failResult.rationale = validationReason;
            failResult.executionTime = TimeCurrent();
            LogOrderFailed(failResult);
            if(m_planner != NULL)
                m_planner.SetPlanStatus(i, PLAN_REJECTED);
            m_totalFailed++;
            continue;
        }

        MqlTradeRequest request;
        if(!m_requestBuilder.Build(plan, volume, request))
        {
            TradeExecutionResult failResult;
            failResult.executionPlanId = planId;
            failResult.submitted = false;
            failResult.retcode = 0;
            failResult.retcodeDescription = "Failed to build trade request";
            failResult.rationale = "RequestBuilder rejected plan";
            failResult.executionTime = TimeCurrent();
            LogOrderFailed(failResult);
            if(m_planner != NULL)
                m_planner.SetPlanStatus(i, PLAN_REJECTED);
            m_totalFailed++;
            continue;
        }

        MqlTradeResult tradeResult;
        bool sent = OrderSend(request, tradeResult);

        ExecutionTruthRecord truth = CaptureExecutionTruth(request, tradeResult, planId);

        TradeExecutionResult result;
        result.executionPlanId = planId;
        result.submitted = sent;
        result.ticket = truth.orderTicket;
        result.retcode = truth.retcode;
        result.retcodeDescription = RetcodeToString(truth.retcode);
        result.filledPrice = truth.filledPrice;
        result.filledVolume = truth.filledVolume;
        result.executionTime = TimeCurrent();

        if(truth.outcome == EXEC_OUTCOME_FILLED || truth.outcome == EXEC_OUTCOME_PARTIALLY_FILLED)
        {
            m_totalFilledPrice += truth.filledPrice;
            result.rationale = "Order submitted successfully";
            m_totalSucceeded++;
            LogOrderSent(result);
        }
        else if(truth.outcome == EXEC_OUTCOME_ACCEPTED_NO_DEAL)
        {
            result.rationale = "Order accepted, no deal confirmed";
            LogOrderSent(result);
        }
        else
        {
            result.rationale = StringFormat("OrderSend failed: retcode=%u %s",
                truth.retcode, RetcodeToString(truth.retcode));
            m_totalFailed++;
            LogOrderFailed(result);
        }

        //--- H6 (integrity): an order is recorded as submitted ONLY after
        //    OrderSend was actually attempted.  Failed sends stay
        //    retryable on the next bar; the same-tick dedup ledger is not
        //    polluted by failed attempts.
        RecordSubmitted(planId);
        m_totalSubmitted++;
    }
}

void CTradeManager::Shutdown(void)
{
    if(!m_isInitialized)
        return;

    m_logger.LogInfo("");
    m_logger.LogInfo("==================== TRADE MANAGER SUMMARY ====================");
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Execution Plans Received",  m_totalReceived));
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Submitted",                 m_totalSubmitted));
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Succeeded",                 m_totalSucceeded));
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Failed",                    m_totalFailed));
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Duplicate Prevented",       m_totalDuplicates));
    m_logger.LogInfo(StringFormat("  %-30s %5d", "Blocked by Position Gate",  m_totalBlocked));
    if(m_totalSucceeded > 0)
    {
        m_logger.LogInfo(StringFormat("  %-30s %.5f", "Avg Fill Price",       m_totalFilledPrice / m_totalSucceeded));
    }
    m_logger.LogInfo("==============================================================");

    ArrayFree(m_submittedIds);
    m_submittedCount = 0;
    m_planner = NULL;
    m_isInitialized = false;
    m_logger.LogInfo("TradeManager shutdown complete");
}

bool CTradeManager::IsAlreadySubmitted(ulong planId)
{
    for(int i = 0; i < m_submittedCount; i++)
    {
        if(m_submittedIds[i] == planId)
            return true;
    }
    return false;
}

void CTradeManager::RecordSubmitted(ulong planId)
{
    int idx = m_submittedCount;
    ArrayResize(m_submittedIds, idx + 1);
    m_submittedIds[idx] = planId;
    m_submittedCount++;
}

void CTradeManager::LogOrderSent(const TradeExecutionResult &result)
{
    m_logger.LogInfo(StringFormat("ORDER-SENT Plan=%lld Ticket=%lld Price=%.5f Volume=%.2f Retcode=%s(%u)",
                                   result.executionPlanId,
                                   result.ticket,
                                   result.filledPrice,
                                   result.filledVolume,
                                   result.retcodeDescription,
                                   result.retcode));
}

void CTradeManager::LogOrderFailed(const TradeExecutionResult &result)
{
    m_logger.LogInfo(StringFormat("ORDER-FAILED Plan=%lld Retcode=%s(%u) Reason=%s",
                                   result.executionPlanId,
                                   result.retcodeDescription,
                                   result.retcode,
                                   result.rationale));
}

string CTradeManager::RetcodeToString(uint retcode)
{
    switch(retcode)
    {
        case TRADE_RETCODE_REQUOTE:              return "REQUOTE";
        case TRADE_RETCODE_REJECT:               return "REJECT";
        case TRADE_RETCODE_CANCEL:               return "CANCEL";
        case TRADE_RETCODE_PLACED:               return "PLACED";
        case TRADE_RETCODE_DONE:                 return "DONE";
        case TRADE_RETCODE_DONE_PARTIAL:         return "DONE_PARTIAL";
        case TRADE_RETCODE_ERROR:                return "ERROR";
        case TRADE_RETCODE_TIMEOUT:              return "TIMEOUT";
        case TRADE_RETCODE_INVALID:              return "INVALID";
        case TRADE_RETCODE_INVALID_VOLUME:       return "INVALID_VOLUME";
        case TRADE_RETCODE_INVALID_PRICE:        return "INVALID_PRICE";
        case TRADE_RETCODE_INVALID_STOPS:        return "INVALID_STOPS";
        case TRADE_RETCODE_TRADE_DISABLED:       return "TRADE_DISABLED";
        case TRADE_RETCODE_MARKET_CLOSED:        return "MARKET_CLOSED";
        case TRADE_RETCODE_NO_MONEY:             return "NO_MONEY";
        case TRADE_RETCODE_PRICE_CHANGED:        return "PRICE_CHANGED";
        case TRADE_RETCODE_PRICE_OFF:            return "PRICE_OFF";
        case TRADE_RETCODE_INVALID_EXPIRATION:   return "INVALID_EXPIRATION";
        case TRADE_RETCODE_ORDER_CHANGED:        return "ORDER_CHANGED";
        case TRADE_RETCODE_TOO_MANY_REQUESTS:    return "TOO_MANY_REQUESTS";
        case TRADE_RETCODE_NO_CHANGES:           return "NO_CHANGES";
        case TRADE_RETCODE_SERVER_DISABLES_AT:   return "SERVER_DISABLES_AT";
        case TRADE_RETCODE_CLIENT_DISABLES_AT:   return "CLIENT_DISABLES_AT";
        case TRADE_RETCODE_LOCKED:               return "LOCKED";
        case TRADE_RETCODE_FROZEN:               return "FROZEN";
        case TRADE_RETCODE_INVALID_FILL:         return "INVALID_FILL";
        case TRADE_RETCODE_CONNECTION:           return "CONNECTION";
        case TRADE_RETCODE_ONLY_REAL:            return "ONLY_REAL";
        case TRADE_RETCODE_LIMIT_ORDERS:         return "LIMIT_ORDERS";
        case TRADE_RETCODE_LIMIT_VOLUME:         return "LIMIT_VOLUME";
        case TRADE_RETCODE_INVALID_ORDER:        return "INVALID_ORDER";
        default:                                 return StringFormat("UNKNOWN(%u)", retcode);
    }
}

#endif