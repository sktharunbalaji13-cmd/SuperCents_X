#ifndef __COOLDOWN_VALIDATOR_MQH__
#define __COOLDOWN_VALIDATOR_MQH__

#include "IEntryValidator.mqh"
#include "ValidatorConfig.mqh"
#include "ITradeStateProvider.mqh"

class CCooldownValidator : public IEntryValidator
{
private:
    ITradeStateProvider *m_provider;
    CooldownConfig       m_cfg;

public:
    CCooldownValidator(ITradeStateProvider *provider)
        : m_provider(provider)
    {}

    CCooldownValidator(ITradeStateProvider *provider, const CooldownConfig &cfg)
        : m_provider(provider)
    {
        m_cfg = cfg;
    }

    virtual void Validate(const ConfluenceResult &confluence, const EntryContext &ctx, EntryFilterResult &out)
    {
        out.category = CATEGORY_ACCOUNT;

        if(m_provider == NULL)
        {
            out.result = FILTER_FAIL;
            out.reason = REASON_COOLDOWN_ACTIVE;
            out.explanation = "No trade state provider — cooldown cannot be verified";
            return;
        }

        int barsSince = m_provider.GetBarsSinceLastTrade();

        if(barsSince < m_cfg.minBarsSinceLastTrade)
        {
            out.result = FILTER_FAIL;
            out.reason = REASON_COOLDOWN_ACTIVE;
            out.explanation = "Cooldown " + IntegerToString(barsSince) + " bars < min " + IntegerToString(m_cfg.minBarsSinceLastTrade);
        }
        else
        {
            out.result = FILTER_PASS;
            out.reason = REASON_NONE;
            out.explanation = "Cooldown " + IntegerToString(barsSince) + " bars >= " + IntegerToString(m_cfg.minBarsSinceLastTrade);
        }
    }

    virtual string GetName() const { return "CooldownValidator"; }
    virtual ENUM_VALIDATOR_CATEGORY GetCategory() const { return CATEGORY_ACCOUNT; }
    virtual string GetVersion() const { return "1.0.0"; }
    virtual string GetDescription() const { return "Enforces minimum time between consecutive trades"; }
};

#endif