#ifndef __RISK_VALIDATOR_MQH__
#define __RISK_VALIDATOR_MQH__

#include "IEntryValidator.mqh"
#include "ValidatorConfig.mqh"
#include "IRiskEvaluator.mqh"

class CRiskValidator : public IEntryValidator
{
private:
    IRiskEvaluator      *m_risk;
    RiskValidatorConfig  m_cfg;

public:
    CRiskValidator(IRiskEvaluator *risk)
        : m_risk(risk)
    {}

    CRiskValidator(IRiskEvaluator *risk, const RiskValidatorConfig &cfg)
        : m_risk(risk)
    {
        m_cfg = cfg;
    }

    void SetRiskEvaluator(IRiskEvaluator *risk) { m_risk = risk; }

    virtual void Validate(const ConfluenceResult &confluence, const EntryContext &ctx, EntryFilterResult &out)
    {
        out.category = CATEGORY_ACCOUNT;

        if(m_risk == NULL)
        {
            out.result = FILTER_FAIL;
            out.reason = REASON_RISK_REJECTED;
            out.explanation = "No risk evaluator — risk check cannot be performed";
            return;
        }

        RiskEvaluation evaluation = m_risk.Evaluate(confluence.totalConfidence);

        if(!evaluation.allowed)
        {
            out.result = FILTER_FAIL;
            out.reason = REASON_RISK_REJECTED;
            out.explanation = evaluation.reason;
        }
        else
        {
            out.result = FILTER_PASS;
            out.reason = REASON_NONE;
            out.explanation = "Risk approved, max lots: " + DoubleToString(evaluation.recommendedLots, 2);
        }
    }

    virtual string GetName() const { return "RiskValidator"; }
    virtual ENUM_VALIDATOR_CATEGORY GetCategory() const { return CATEGORY_ACCOUNT; }
    virtual string GetVersion() const { return "1.0.0"; }
    virtual string GetDescription() const { return "Validates risk limits before allowing entry"; }
};

#endif
