#ifndef __C_SHADOW_RISK_EVALUATOR_MQH__
#define __C_SHADOW_RISK_EVALUATOR_MQH__

#include "Validators/IRiskEvaluator.mqh"

//--- @frozen v3.0-provider-contract: permissive shadow implementation.
//    Shadow mode must never block on account state, so all evaluations
//    are approved with a fixed lot cap.
class CShadowRiskEvaluator : public IRiskEvaluator
{
public:
    virtual RiskEvaluation Evaluate(double confidence)
    {
        RiskEvaluation ev;
        ev.allowed = true;
        ev.recommendedLots = 1.0;
        ev.rejectionReason = RR_NONE;
        return ev;
    }
    virtual string GetName() { return "ShadowRisk"; }
};

#endif
