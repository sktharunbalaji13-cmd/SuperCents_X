#ifndef __SESSION_VALIDATOR_MQH__
#define __SESSION_VALIDATOR_MQH__

#include "IEntryValidator.mqh"
#include "ValidatorConfig.mqh"

class CSessionValidator : public IEntryValidator
{
private:
    SessionConfig m_cfg;

public:
    CSessionValidator() {}

    CSessionValidator(const SessionConfig &cfg)
    {
        m_cfg = cfg;
    }

    virtual void Validate(const ConfluenceResult &confluence, const EntryContext &ctx, EntryFilterResult &out)
    {
        out.category = CATEGORY_MARKET;

        if(m_cfg.count == 0)
        {
            out.result = FILTER_PASS;
            out.reason = REASON_NONE;
            out.explanation = "No session restrictions configured";
            return;
        }

        MqlDateTime dt;
        TimeToStruct(ctx.now, dt);
        int currentHour = dt.hour;

        bool inSession = false;
        bool inLastHour = false;

        for(int i = 0; i < m_cfg.count; i++)
        {
            int start = m_cfg.ranges[i].startHour;
            int end   = m_cfg.ranges[i].endHour;

            if(currentHour >= start && currentHour < end)
            {
                inSession = true;
                if(currentHour == end - 1)
                    inLastHour = true;
                break;
            }
        }

        if(!inSession)
        {
            out.result = FILTER_FAIL;
            out.reason = REASON_SESSION_CLOSED;
            out.explanation = "Current hour " + IntegerToString(currentHour) + " not in any configured session";
        }
        else if(inLastHour)
        {
            out.result = FILTER_WARNING;
            out.reason = REASON_NONE;
            out.explanation = "Last hour of session (hour " + IntegerToString(currentHour) + ")";
        }
        else
        {
            out.result = FILTER_PASS;
            out.reason = REASON_NONE;
            out.explanation = "Session hour " + IntegerToString(currentHour);
        }
    }

    virtual string GetName() const { return "SessionValidator"; }
    virtual ENUM_VALIDATOR_CATEGORY GetCategory() const { return CATEGORY_MARKET; }
    virtual string GetVersion() const { return "1.0.0"; }
    virtual string GetDescription() const { return "Restricts entries to configured trading sessions"; }
};

#endif