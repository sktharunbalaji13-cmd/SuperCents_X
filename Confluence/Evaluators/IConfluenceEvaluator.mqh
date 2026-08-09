#ifndef __I_CONFLUENCE_EVALUATOR_MQH__
#define __I_CONFLUENCE_EVALUATOR_MQH__

#include "../ConfluenceTypes.mqh"

class IConfluenceEvaluator
{
public:
    virtual ~IConfluenceEvaluator() {}

    virtual bool Evaluate(const DetectionContext &context, ConfluenceComponentResult &result) = 0;

    virtual ENUM_CONFLUENCE_COMPONENT GetComponentType(void) const = 0;

    virtual string GetName(void) const = 0;

    virtual string GetVersion(void) const = 0;

    virtual string GetDescription(void) const = 0;
};

#endif
