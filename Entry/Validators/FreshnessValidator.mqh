#ifndef __FRESHNESS_VALIDATOR_MQH__
#define __FRESHNESS_VALIDATOR_MQH__

#include "IEntryValidator.mqh"
#include "ValidatorConfig.mqh"

class CFreshnessValidator : public IEntryValidator
{
private:
    FreshnessConfig m_cfg;

public:
    CFreshnessValidator() {}

    CFreshnessValidator(const FreshnessConfig &cfg)
    {
        m_cfg = cfg;
    }

    virtual void Validate(const ConfluenceResult &confluence, const EntryContext &ctx, EntryFilterResult &out)
    {
        out.category = CATEGORY_SETUP;

        if(ctx.barsSinceSignal > m_cfg.maxAgeBars)
        {
            out.result = FILTER_FAIL;
            out.reason = REASON_SIGNAL_EXPIRED;
            out.explanation = "Signal age " + IntegerToString(ctx.barsSinceSignal) + " bars > max " + IntegerToString(m_cfg.maxAgeBars);
        }
        else if(ctx.barsSinceSignal > (int)(m_cfg.maxAgeBars * 0.75))
        {
            out.result = FILTER_WARNING;
            out.reason = REASON_NONE;
            out.explanation = "Signal age " + IntegerToString(ctx.barsSinceSignal) + " bars approaching limit";
        }
        else
        {
            out.result = FILTER_PASS;
            out.reason = REASON_NONE;
            out.explanation = "Signal age " + IntegerToString(ctx.barsSinceSignal) + " bars";
        }
    }

    virtual string GetName() const { return "FreshnessValidator"; }
    virtual ENUM_VALIDATOR_CATEGORY GetCategory() const { return CATEGORY_SETUP; }
    virtual string GetVersion() const { return "1.0.0"; }
    virtual string GetDescription() const { return "Rejects entries where the signal is too old"; }
};

#endif