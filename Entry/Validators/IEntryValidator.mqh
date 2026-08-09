#ifndef __I_ENTRY_VALIDATOR_MQH__
#define __I_ENTRY_VALIDATOR_MQH__

#include "../EntryTypes.mqh"
#include "../../Confluence/ConfluenceTypes.mqh"

class IEntryValidator
{
public:
    virtual ~IEntryValidator() {}

    virtual void Validate(const ConfluenceResult &confluence, const EntryContext &ctx, EntryFilterResult &out) = 0;

    virtual string GetName() const = 0;

    virtual ENUM_VALIDATOR_CATEGORY GetCategory() const = 0;

    virtual string GetVersion() const = 0;

    virtual string GetDescription() const = 0;
};

#endif
