#ifndef __DISTANCE_VALIDATOR_MQH__
#define __DISTANCE_VALIDATOR_MQH__

#include "IEntryValidator.mqh"
#include "ValidatorConfig.mqh"

class CDistanceValidator : public IEntryValidator
{
private:
    DistanceConfig m_cfg;

public:
    CDistanceValidator() {}

    CDistanceValidator(const DistanceConfig &cfg)
    {
        m_cfg = cfg;
    }

    virtual void Validate(const ConfluenceResult &confluence, const EntryContext &ctx, EntryFilterResult &out)
    {
        out.category = CATEGORY_MARKET;

        double midPrice = (ctx.currentBid + ctx.currentAsk) / 2.0;
        double distance = MathAbs(midPrice - ctx.candidateEntryPrice);

        if(distance > m_cfg.maxDistance)
        {
            out.result = FILTER_FAIL;
            out.reason = REASON_DISTANCE_TOO_LARGE;
            out.explanation = "Distance " + DoubleToString(distance, 5) + " > max " + DoubleToString(m_cfg.maxDistance, 5);
        }
        else if(distance > m_cfg.maxDistance * 0.75)
        {
            out.result = FILTER_WARNING;
            out.reason = REASON_NONE;
            out.explanation = "Distance " + DoubleToString(distance, 5) + " approaching max " + DoubleToString(m_cfg.maxDistance, 5);
        }
        else
        {
            out.result = FILTER_PASS;
            out.reason = REASON_NONE;
            out.explanation = "Distance " + DoubleToString(distance, 5);
        }
    }

    virtual string GetName() const { return "DistanceValidator"; }
    virtual ENUM_VALIDATOR_CATEGORY GetCategory() const { return CATEGORY_MARKET; }
    virtual string GetVersion() const { return "1.0.0"; }
    virtual string GetDescription() const { return "Prevents entries too far from the candidate price"; }
};

#endif