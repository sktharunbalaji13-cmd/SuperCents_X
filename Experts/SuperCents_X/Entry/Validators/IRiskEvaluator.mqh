#ifndef __I_RISK_EVALUATOR_MQH__
#define __I_RISK_EVALUATOR_MQH__

// TODO(v2.9): Consider returning a RiskEvaluation struct
// { bool allowed; double recommendedLots; string reason; }
// instead of the current out-parameter pattern.

class IRiskEvaluator
{
public:
    virtual ~IRiskEvaluator() {}

    virtual bool CanOpenPosition(double confidence, double &maxLots) = 0;

    virtual string GetRejectionReason() = 0;

    virtual string GetName() = 0;
};

#endif
