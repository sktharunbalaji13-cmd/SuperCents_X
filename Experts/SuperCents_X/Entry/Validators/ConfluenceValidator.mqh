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

    //--- ED01: apply the floor config built from the ED01_* inputs.
    void SetConfig(const ConfluenceConfig &cfg) { m_cfg = cfg; }

    //--- ED01: expose the applied config so telemetry fingerprints the
    //    same config the validator gates on (policy recording).
    ConfluenceConfig GetConfig(void) const { return m_cfg; }

    //--- GR01: resolve the admission floor for the winning rule family.
    //    Per-family floors are evidence-calibrated (frozen Sprint 17 funnel,
    //    docs/Sprint20_GR01_Decision.md).  The UNKNOWN family (evaluator
    //    path / rules without a family) uses its own floor; the global
    //    minConfidence is no longer the fallback — it stays the legacy
    //    replay/telemetry gate only.
    double ResolveFloor(const ENUM_RULE_FAMILY family) const
    {
        switch(family)
        {
            case RULE_FAMILY_LIQUIDITY:    return m_cfg.familyFloorLiquidity;
            case RULE_FAMILY_FVG:          return m_cfg.familyFloorFVG;
            case RULE_FAMILY_ORDER_BLOCK:  return m_cfg.familyFloorOrderBlock;
            case RULE_FAMILY_BOS:          return m_cfg.familyFloorBOS;
            case RULE_FAMILY_CHOCH:        return m_cfg.familyFloorCHOCH;
            case RULE_FAMILY_UNKNOWN:      return m_cfg.familyFloorUnknown;
        }
        return m_cfg.familyFloorUnknown;
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