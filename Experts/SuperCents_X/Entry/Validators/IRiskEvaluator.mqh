#ifndef __I_RISK_EVALUATOR_MQH__
#define __I_RISK_EVALUATOR_MQH__

//+------------------------------------------------------------------+
//| Risk evaluator contract                                          |
//|                                                                  |
//| @frozen v3.0-provider-contract                                   |
//|                                                                  |
//| Contract rules (providers):                                      |
//|   - Providers SHALL retrieve account/market state only.          |
//|   - Providers SHALL NOT contain business rules (thresholds,      |
//|     position sizing policy, cooldown logic).                     |
//|   - Validators SHALL NOT reach into MT5 APIs; they consume       |
//|     providers via the EntryContext / provider interfaces.        |
//|   - Evaluate() returns one atomic value describing a single      |
//|     risk evaluation: allowed, sizing, reason, margin context.    |
//+------------------------------------------------------------------+

enum ENUM_RISK_REJECTION_REASON
{
    RR_NONE = 0,              // evaluation approved (or no reason set)
    RR_TRADING_DISABLED,      // symbol trade mode < FULL
    RR_INVALID_VOLUME,        // broker volume limits invalid
    RR_NO_PRICE,              // no market price available
    RR_MARGIN_CALC_FAILED,    // OrderCalcMargin failed
    RR_INSUFFICIENT_MARGIN,   // margin buffer cannot absorb the trade
    RR_UNKNOWN                // uncategorized rejection
};

//+------------------------------------------------------------------+
//| @frozen v3.0-provider-contract: atomic risk evaluation result.   |
//| Future changes MUST be additive (new fields with defaults).      |
//+------------------------------------------------------------------+
struct RiskEvaluation
{
    bool   allowed;              // may the position open?
    double recommendedLots;      // max affordable lot size (0 when rejected)
    string reason;               // human-readable rejection/approval text
    double riskPercent;          // reserved (Sprint 16+ risk policy)
    double marginRequired;       // margin for recommendedLots (0 if unknown)
    double freeMarginAfterTrade; // free margin minus required margin (0 if unknown)
    ENUM_RISK_REJECTION_REASON rejectionReason;

    RiskEvaluation(void)
        : allowed(false)
        , recommendedLots(0.0)
        , reason("")
        , riskPercent(0.0)
        , marginRequired(0.0)
        , freeMarginAfterTrade(0.0)
        , rejectionReason(RR_NONE)
    {}
};

//+------------------------------------------------------------------+
//| @frozen v3.0-provider-contract: risk evaluation provider.        |
//| Providers SHALL retrieve state only; no business rules inside.   |
//| Future changes MUST be additive (new virtuals with defaults).    |
//+------------------------------------------------------------------+
class IRiskEvaluator
{
public:
    virtual ~IRiskEvaluator() {}

    virtual RiskEvaluation Evaluate(double confidence) = 0;

    virtual string GetName() = 0;
};

#endif
