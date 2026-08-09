#ifndef __MOCK_VALIDATOR_MQH__
#define __MOCK_VALIDATOR_MQH__

#include "../../Entry/Validators/IEntryValidator.mqh"

class CMockValidator : public IEntryValidator
{
private:
    string                  m_name;
    ENUM_FILTER_RESULT      m_result;
    ENUM_ENTRY_REJECTION_REASON m_reason;
    ENUM_VALIDATOR_CATEGORY m_category;
    int                     m_invokeCount;
    string                  m_explanationOverride;

public:
    CMockValidator(string name, ENUM_FILTER_RESULT result = FILTER_PASS)
        : m_name(name)
        , m_result(result)
        , m_reason(REASON_NONE)
        , m_category(CATEGORY_SETUP)
        , m_invokeCount(0)
        , m_explanationOverride("")
    {
        if(result == FILTER_FAIL)
            m_reason = REASON_UNKNOWN;
    }

    void SetResult(ENUM_FILTER_RESULT r)
    {
        m_result = r;
    }

    void SetReason(ENUM_ENTRY_REJECTION_REASON r)
    {
        m_reason = r;
    }

    void SetCategory(ENUM_VALIDATOR_CATEGORY c)
    {
        m_category = c;
    }

    void SetExplanation(string ex)
    {
        m_explanationOverride = ex;
    }

    int GetInvokeCount() const
    {
        return m_invokeCount;
    }

    void ResetInvokeCount()
    {
        m_invokeCount = 0;
    }

    virtual void Validate(const ConfluenceResult &confluence, const EntryContext &ctx, EntryFilterResult &out)
    {
        m_invokeCount++;
        out.category = m_category;
        out.result = m_result;
        out.reason = m_reason;
        if(m_explanationOverride != "")
            out.explanation = m_explanationOverride;
        else
            out.explanation = "Mock[" + m_name + "]=" + ResultToStr(m_result);
    }

    virtual string GetName() const { return m_name; }
    virtual ENUM_VALIDATOR_CATEGORY GetCategory() const { return m_category; }
    virtual string GetVersion() const { return "0.0.0"; }
    virtual string GetDescription() const { return "Mock validator for testing"; }

    static string ResultToStr(ENUM_FILTER_RESULT r)
    {
        if(r == FILTER_PASS) return "PASS";
        if(r == FILTER_WARNING) return "WARNING";
        return "FAIL";
    }
};

#endif