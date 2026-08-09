#ifndef __DIRECTION_VALIDATOR_MQH__
#define __DIRECTION_VALIDATOR_MQH__

#include "IEntryValidator.mqh"

class CDirectionValidator : public IEntryValidator
{
public:
    virtual void Validate(const ConfluenceResult &confluence, const EntryContext &ctx, EntryFilterResult &out)
    {
        out.category = CATEGORY_SETUP;

        if(confluence.direction == CONFLUENCE_NONE)
        {
            out.result = FILTER_FAIL;
            out.reason = REASON_DIRECTION_INVALID;
            out.explanation = "No confluence direction detected";
        }
        else
        {
            string dirStr = (confluence.direction == CONFLUENCE_BULLISH) ? "BULLISH" : "BEARISH";
            out.result = FILTER_PASS;
            out.reason = REASON_NONE;
            out.explanation = "Direction: " + dirStr;
        }
    }

    virtual string GetName() const { return "DirectionValidator"; }
    virtual ENUM_VALIDATOR_CATEGORY GetCategory() const { return CATEGORY_SETUP; }
    virtual string GetVersion() const { return "1.0.0"; }
    virtual string GetDescription() const { return "Rejects entries with no clear confluence direction"; }
};

#endif