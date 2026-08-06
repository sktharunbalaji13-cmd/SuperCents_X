#ifndef __CONFLUENCE_VALIDATOR_MQH__
#define __CONFLUENCE_VALIDATOR_MQH__

#include "IEntryValidator.mqh"
#include "ValidatorConfig.mqh"

// TODO(v2.9): Replace BOS-count heuristic with dedicated TrendStrength API
// once the Trend subsystem exposes one.

class CConfluenceValidator : public IEntryValidator
{
private:
    ConfluenceConfig m_cfg;

public:
    CConfluenceValidator() {}

    CConfluenceValidator(const ConfluenceConfig &cfg)
    {
        m_cfg = cfg;
    }

    //--- DD05: resolve the admission floor for the winning rule family.
    //    Unknown/unevaluated families fall back to the global
    //    minConfidence (legacy behavior).
    double ResolveFloor(const ENUM_RULE_FAMILY family) const
    {
        switch(family)
        {
            case RULE_FAMILY_LIQUIDITY:    return m_cfg.familyFloorLiquidity;
            case RULE_FAMILY_FVG:          return m_cfg.familyFloorFVG;
            case RULE_FAMILY_ORDER_BLOCK:  return m_cfg.familyFloorOrderBlock;
            case RULE_FAMILY_BOS:          return m_cfg.familyFloorBOS;
            case RULE_FAMILY_CHOCH:        return m_cfg.familyFloorCHOCH;
        }
        return m_cfg.minConfidence;
    }

    virtual void Validate(const ConfluenceResult &confluence, const EntryContext &ctx, EntryFilterResult &out)
    {
        out.category = CATEGORY_SETUP;

        double normalized = confluence.totalConfidence / 100.0;
        double floor = ResolveFloor(confluence.winningRuleFamily);

        if(normalized < floor)
        {
            out.result = FILTER_FAIL;
            out.reason = REASON_CONFIDENCE_LOW;
            out.explanation = "Confidence " + DoubleToString(normalized, 2) + " < floor " + DoubleToString(floor, 2);
        }
        else if(normalized > floor && normalized < floor * 1.1)
        {
            out.result = FILTER_WARNING;
            out.reason = REASON_NONE;
            out.explanation = "Confidence " + DoubleToString(normalized, 2) + " near threshold " + DoubleToString(floor, 2);
        }
        else
        {
            out.result = FILTER_PASS;
            out.reason = REASON_NONE;
            out.explanation = "Confidence " + DoubleToString(normalized, 2) + " >= " + DoubleToString(floor, 2);
        }
    }

    virtual string GetName() const { return "ConfluenceValidator"; }
    virtual ENUM_VALIDATOR_CATEGORY GetCategory() const { return CATEGORY_SETUP; }
    virtual string GetVersion() const { return "1.0.0"; }
    virtual string GetDescription() const { return "Rejects entries below minimum confluence confidence"; }

    //--- Active threshold (0-1) for telemetry row capture.
    double GetMinConfidence() const { return m_cfg.minConfidence; }
};

#endif