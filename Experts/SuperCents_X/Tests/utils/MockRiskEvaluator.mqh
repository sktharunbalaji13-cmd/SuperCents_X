#ifndef __MOCK_RISK_EVALUATOR_MQH__
#define __MOCK_RISK_EVALUATOR_MQH__

#include "../../Entry/Validators/IRiskEvaluator.mqh"

class CMockRiskEvaluator : public IRiskEvaluator
{
private:
    bool   m_allowed;
    double m_maxLots;
    string m_rejectionReason;
    string m_name;

public:
    CMockRiskEvaluator(string name = "MockRisk")
        : m_allowed(true)
        , m_maxLots(1.0)
        , m_rejectionReason("")
        , m_name(name)
    {}

    void SetAllowed(bool v)           { m_allowed = v; }
    void SetMaxLots(double v)         { m_maxLots = v; }
    void SetRejectionReason(string v) { m_rejectionReason = v; }

    virtual bool   CanOpenPosition(double confidence, double &maxLots)
    {
        maxLots = m_maxLots;
        return m_allowed;
    }

    virtual string GetRejectionReason() { return m_rejectionReason; }
    virtual string GetName()            { return m_name; }
};

#endif