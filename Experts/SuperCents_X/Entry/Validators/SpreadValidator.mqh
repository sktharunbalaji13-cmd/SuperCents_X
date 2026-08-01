#ifndef __SPREAD_VALIDATOR_MQH__
#define __SPREAD_VALIDATOR_MQH__

#include "IEntryValidator.mqh"
#include "ValidatorConfig.mqh"

class CSpreadValidator : public IEntryValidator
{
private:
    SpreadConfig m_cfg;

public:
    CSpreadValidator() {}

    CSpreadValidator(const SpreadConfig &cfg)
    {
        m_cfg = cfg;
    }

    virtual void Validate(const ConfluenceResult &confluence, const EntryContext &ctx, EntryFilterResult &out)
    {
        out.category = CATEGORY_MARKET;

        if(ctx.spread > m_cfg.maxSpreadPips)
        {
            out.result = FILTER_FAIL;
            out.reason = REASON_SPREAD_TOO_HIGH;
            out.explanation = "Spread " + DoubleToString(ctx.spread, 1) + " > max " + DoubleToString(m_cfg.maxSpreadPips, 1);
        }
        else if(ctx.spread < m_cfg.maxSpreadPips && ctx.spread > m_cfg.maxSpreadPips * 0.75)
        {
            out.result = FILTER_WARNING;
            out.reason = REASON_NONE;
            out.explanation = "Spread " + DoubleToString(ctx.spread, 1) + " approaching max " + DoubleToString(m_cfg.maxSpreadPips, 1);
        }
        else
        {
            out.result = FILTER_PASS;
            out.reason = REASON_NONE;
            out.explanation = "Spread " + DoubleToString(ctx.spread, 1) + " pips";
        }
    }

    virtual string GetName() const { return "SpreadValidator"; }
    virtual ENUM_VALIDATOR_CATEGORY GetCategory() const { return CATEGORY_MARKET; }
    virtual string GetVersion() const { return "1.0.0"; }
    virtual string GetDescription() const { return "Rejects entries during high spread conditions"; }
};

#endif