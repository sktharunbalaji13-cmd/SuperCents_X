#ifndef __C_SHADOW_RISK_EVALUATOR_MQH__
#define __C_SHADOW_RISK_EVALUATOR_MQH__

#include "Validators/IRiskEvaluator.mqh"

class CShadowRiskEvaluator : public IRiskEvaluator
{
public:
    virtual bool   CanOpenPosition(double confidence, double &maxLots)
    {
        maxLots = 1.0;
        return true;
    }
    virtual string GetRejectionReason() { return ""; }
    virtual string GetName()            { return "ShadowRisk"; }
};

#endif